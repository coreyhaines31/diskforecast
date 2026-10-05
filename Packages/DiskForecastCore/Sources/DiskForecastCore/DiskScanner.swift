import Darwin
import Foundation

/// Measures a folder tree with `getattrlistbulk` on a pool of threads, one directory per job.
///
/// Sizes are allocated bytes (what the disk actually spends), and shared storage is counted
/// once: a hard-linked file counts at its first link, and an APFS clone counts in full the first
/// time its clone family is seen and only its private bytes after that. A clone that has since
/// been edited leaves its family, and APFS doesn't say which file it still shares blocks with,
/// so it counts in full, as Finder counts it.
public final class DiskScanner: @unchecked Sendable {
    public struct Options: Sendable {
        public var root: URL
        /// Absolute paths not to enter, like protected folders when Full Disk Access is off.
        public var excludedPaths: Set<String>
        public var largeFileThreshold: Int64
        public var largestFileLimit: Int
        public var diskImageThreshold: Int64
        public var workerCount: Int
        /// How long a folder can take to open before the scan finishes without it. macOS holds
        /// the first read of a guarded folder until its permission prompt is answered.
        public var stallTimeout: TimeInterval

        public init(
            root: URL,
            excludedPaths: Set<String> = [],
            largeFileThreshold: Int64 = 100_000_000,
            largestFileLimit: Int = 50,
            diskImageThreshold: Int64 = 50_000_000,
            workerCount: Int = ProcessInfo.processInfo.activeProcessorCount,
            stallTimeout: TimeInterval = 10
        ) {
            self.root = root
            self.excludedPaths = excludedPaths
            self.largeFileThreshold = largeFileThreshold
            self.largestFileLimit = largestFileLimit
            self.diskImageThreshold = diskImageThreshold
            self.workerCount = max(1, workerCount)
            self.stallTimeout = stallTimeout
        }
    }

    public struct Progress: Sendable {
        public let files: Int
        public let bytes: Int64
        public let directories: Int
    }

    static let diskImageExtensions: Set<String> = ["dmg", "iso", "pkg", "sparseimage", "sparsebundle", "img"]

    private let options: Options
    private let condition = NSCondition()
    // Everything below is guarded by `condition`.
    private var queue: [Job] = []
    private var active = 0
    private var cancelled = false
    private var finished = false
    private var inFlight: [String: Date] = [:]
    private var names: [String] = []
    private var parents: [Int32] = []
    private var children: [[Int32]] = []
    private var ownBytes: [Int64] = []
    private var fileCount = 0
    private var byteCount: Int64 = 0
    private var largeFiles: [FileFinding] = []
    private var diskImages: [FileFinding] = []
    private var artifacts: [ArtifactFinding] = []
    private var deniedCount = 0
    private var deniedSamples: [String] = []
    private var skippedPaths: [String] = []
    private var rootDevice: Int32 = 0
    // Shared storage seen so far, guarded by `sharedLock`.
    private let sharedLock = NSLock()
    private var seenLinkedFiles: Set<UInt64> = []
    private var seenClones: Set<UInt64> = []

    fileprivate struct Job {
        let node: Int32
        let path: String
        let insideArtifact: Bool
    }

    public init(options: Options) {
        self.options = options
    }

    public var progress: Progress {
        condition.lock()
        defer { condition.unlock() }
        return Progress(files: fileCount, bytes: byteCount, directories: names.count)
    }

    public func cancel() {
        condition.lock()
        cancelled = true
        condition.broadcast()
        condition.unlock()
    }

    /// Scans on background threads; the calling task just waits.
    public func scan() async -> ScanResult {
        await withCheckedContinuation { continuation in
            let thread = Thread { [self] in
                continuation.resume(returning: scanBlocking())
            }
            thread.qualityOfService = .utility
            thread.start()
        }
    }

    public func scanBlocking() -> ScanResult {
        let started = Date()
        let rootPath = options.root.path(percentEncoded: false)
        let root = rootPath.count > 1 && rootPath.hasSuffix("/") ? String(rootPath.dropLast()) : rootPath
        var info = stat()
        rootDevice = lstat(root, &info) == 0 ? info.st_dev : 0
        names = [root]
        parents = [-1]
        children = [[]]
        ownBytes = [0]
        queue = [Job(node: 0, path: root, insideArtifact: false)]

        for _ in 0..<options.workerCount {
            let worker = Thread { [self] in work() }
            worker.qualityOfService = .utility
            worker.stackSize = 1 << 20
            worker.start()
        }

        condition.lock()
        defer { condition.unlock() }
        let stalled = waitUntilDone()
        finished = true
        condition.broadcast()
        // Workers stuck on a prompt may return later; they find `finished` set and change nothing.
        let tree = ScanTree(rootPath: root, names: names, parents: parents, children: children, ownBytes: ownBytes)
        return ScanResult(
            tree: tree,
            fileCount: fileCount,
            largestFiles: Array(largeFiles.sorted { $0.bytes > $1.bytes }.prefix(options.largestFileLimit)),
            diskImages: diskImages.sorted { $0.bytes > $1.bytes },
            artifacts: artifacts.sorted { $0.path < $1.path },
            deniedCount: deniedCount,
            deniedSamples: deniedSamples,
            skippedPaths: skippedPaths.sorted(),
            stalledPaths: stalled.sorted(),
            duration: Date().timeIntervalSince(started)
        )
    }

    /// Waits, holding the lock between checks, until nothing is queued and every folder still
    /// being read has been stuck past the timeout. Returns those stuck folders.
    private func waitUntilDone() -> [String] {
        while !cancelled {
            if queue.isEmpty {
                if active == 0 { return [] }
                let now = Date()
                if inFlight.values.allSatisfy({ now.timeIntervalSince($0) > options.stallTimeout }) {
                    return Array(inFlight.keys)
                }
            }
            condition.wait(until: Date().addingTimeInterval(1))
        }
        return []
    }

    private func work() {
        // Listing an iCloud folder whose contents were evicted would download them. Don't.
        setiopolicy_np(
            IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_THREAD, IOPOL_MATERIALIZE_DATALESS_FILES_OFF
        )
        let reader = BulkReader()
        defer { reader.deallocate() }
        while true {
            condition.lock()
            while queue.isEmpty && !finished && !cancelled {
                condition.wait()
            }
            if finished || cancelled {
                condition.unlock()
                return
            }
            let job = queue.removeLast()
            active += 1
            inFlight[job.path] = Date()
            condition.unlock()

            let listing = list(job, reader: reader)

            condition.lock()
            if finished {
                condition.unlock()
                return
            }
            record(listing, for: job)
            active -= 1
            inFlight[job.path] = nil
            condition.broadcast()
            condition.unlock()
        }
    }

    private func record(_ listing: Listing, for job: Job) {
        let node = Int(job.node)
        if listing.denied {
            deniedCount += 1
            if deniedSamples.count < 50 { deniedSamples.append(job.path) }
            return
        }
        ownBytes[node] = listing.bytes
        fileCount += listing.files
        byteCount += listing.bytes
        largeFiles.append(contentsOf: listing.large)
        diskImages.append(contentsOf: listing.images)
        skippedPaths.append(contentsOf: listing.skipped)
        if cancelled { return }
        var artifactNodes: [String: Int32] = [:]
        for subdirectory in listing.subdirectories {
            let child = Int32(names.count)
            names.append(subdirectory.name)
            parents.append(job.node)
            children.append([])
            ownBytes.append(0)
            children[node].append(child)
            artifactNodes[subdirectory.name] = child
            queue.append(Job(
                node: child,
                path: job.path + "/" + subdirectory.name,
                insideArtifact: subdirectory.insideArtifact
            ))
        }
        for artifact in listing.artifacts {
            guard let child = artifactNodes[artifact.kind.folderName] else { continue }
            artifacts.append(ArtifactFinding(
                kind: artifact.kind,
                path: job.path + "/" + artifact.kind.folderName,
                projectModified: artifact.projectModified,
                node: Int(child)
            ))
        }
    }
}

// Listing one directory runs outside the lock.
extension DiskScanner {
    fileprivate struct Listing {
        var denied = false
        var bytes: Int64 = 0
        var files = 0
        var subdirectories: [(name: String, insideArtifact: Bool)] = []
        var skipped: [String] = []
        var large: [FileFinding] = []
        var images: [FileFinding] = []
        var artifacts: [(kind: ArtifactKind, projectModified: Date)] = []
    }

    fileprivate func list(_ job: Job, reader: BulkReader) -> Listing {
        var listing = Listing()
        let descriptor = open(job.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else {
            listing.denied = errno == EPERM || errno == EACCES
            return listing
        }
        defer { close(descriptor) }

        var directoryNames: Set<String> = []
        var fileNames: Set<String> = []
        var modified: [String: Date] = [:]
        reader.read(descriptor) { entry in
            let date = Date(timeIntervalSince1970: entry.modified)
            modified[entry.name] = date
            switch entry.type {
            case .directory:
                directoryNames.insert(entry.name)
                let childPath = job.path + "/" + entry.name
                if entry.device != rootDevice || options.excludedPaths.contains(childPath) {
                    listing.skipped.append(childPath)
                }
            case .file, .symlink, .other:
                fileNames.insert(entry.name)
                let bytes = countedBytes(entry, path: job.path)
                listing.bytes += bytes
                listing.files += 1
                guard entry.type == .file else { return }
                if bytes >= options.largeFileThreshold {
                    listing.large.append(FileFinding(path: job.path + "/" + entry.name, bytes: bytes, modified: date))
                }
                if bytes >= options.diskImageThreshold,
                   Self.diskImageExtensions.contains((entry.name as NSString).pathExtension.lowercased()) {
                    listing.images.append(FileFinding(path: job.path + "/" + entry.name, bytes: bytes, modified: date))
                }
            }
        }

        let found = job.insideArtifact ? [] : ArtifactKind.detect(directories: directoryNames, files: fileNames)
        let artifactNames = Set(found.map(\.folderName))
        if !found.isEmpty {
            let newest = modified.filter { !artifactNames.contains($0.key) }.values.max() ?? .distantPast
            listing.artifacts = found.map { ($0, newest) }
        }
        let skipped = Set(listing.skipped)
        for name in directoryNames where !skipped.contains(job.path + "/" + name) {
            let inside = job.insideArtifact || artifactNames.contains(name) || name == "node_modules"
            listing.subdirectories.append((name, inside))
        }
        // Bundles that hold one big file inside, like a sparsebundle, are directories.
        if Self.diskImageExtensions.contains((job.path as NSString).pathExtension.lowercased()) {
            listing.images = []
        }
        return listing
    }

    /// The bytes a file adds that haven't been counted already.
    fileprivate func countedBytes(_ entry: BulkReader.Entry, path: String) -> Int64 {
        if entry.linkCount > 1 {
            sharedLock.lock()
            let first = seenLinkedFiles.insert(entry.fileID).inserted
            sharedLock.unlock()
            if !first { return 0 }
        }
        if entry.cloneReferences > 1 {
            sharedLock.lock()
            let first = seenClones.insert(entry.cloneID).inserted
            sharedLock.unlock()
            if !first {
                return BulkReader.privateSize(of: path + "/" + entry.name) ?? 0
            }
        }
        return entry.allocatedBytes
    }
}
