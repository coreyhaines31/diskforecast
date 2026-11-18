import Darwin
import Foundation

/// A large folder whose files are all stored a second time in another folder.
public struct DuplicateFolder: Sendable, Hashable {
    /// The newer copy, the one to consider removing.
    public let path: String
    /// The older copy, which stays.
    public let original: String
    /// What removing `path` would free: its files that share no storage with another file.
    public let bytes: Int64
}

/// Finds folders stored twice, starting from the scan so nothing new is listed or prompted for.
/// Candidates share a name, a size, and a number of subfolders. Each pair is then checked by
/// listing both folders' files and comparing their exact lengths, and by comparing the contents of
/// the largest few files in sampled chunks. That is strong evidence, not proof: smaller files are
/// never read, so the list says what was checked instead of calling the folders identical. Only
/// folders above the size floor are ever read.
enum DuplicateFolders {
    /// How far apart two copies' sizes can be, as a share of the larger.
    static let sizeTolerance = 0.05
    static let sampledFiles = 3
    static let chunksPerFile = 8
    static let chunkBytes = 1 << 20
    /// Folders with more files than this aren't compared.
    static let maximumFiles = 200_000
    /// Pairs compared per cleanup list at most.
    static let maximumComparisons = 20
    /// Apps and other code bundles; copies of these are installs, not the user's files.
    static let bundleExtensions: Set<String> = ["app", "appex", "bundle", "framework", "plugin", "kext", "xpc"]

    typealias Candidate = (node: Int, path: String)

    static func find(in scan: ScanResult, home: String, minimumBytes: Int64) -> [DuplicateFolder] {
        // Reading a file iCloud has evicted would download it. Don't.
        withoutDownloading { pairs(in: scan, home: home, minimumBytes: minimumBytes) }
    }

    private static func pairs(in scan: ScanResult, home: String, minimumBytes: Int64) -> [DuplicateFolder] {
        let tree = scan.tree
        var found: [DuplicateFolder] = []
        var matched: [String] = []
        var comparisons = 0
        for members in candidateGroups(in: scan, home: home, minimumBytes: minimumBytes) {
            var kept: [Candidate] = []
            for member in members.sorted(by: { birth(of: $0.path) < birth(of: $1.path) }) {
                if matched.contains(where: { member.path == $0 || member.path.hasPrefix($0 + "/") }) { continue }
                var isCopy = false
                for original in kept where comparisons < maximumComparisons
                    && isPlausibleCopy(member.node, of: original.node, in: tree) {
                    comparisons += 1
                    guard let freed = freedBytes(removing: member.node, keeping: original.node, in: tree) else {
                        continue
                    }
                    // A copy that shares its storage, like an APFS clone, frees nothing and isn't listed.
                    if freed >= minimumBytes {
                        found.append(DuplicateFolder(path: member.path, original: original.path, bytes: freed))
                    }
                    matched += [member.path, original.path]
                    isCopy = true
                    break
                }
                if !isCopy { kept.append(member) }
            }
        }
        return found
    }

    /// Big folders that share a name with another, biggest first and outer before inner, so a
    /// copied folder is found before its subfolders.
    static func candidateGroups(in scan: ScanResult, home: String, minimumBytes: Int64) -> [[Candidate]] {
        let tree = scan.tree
        guard tree.names.count > 1 else { return [] }
        let excluded = scan.artifacts.map(\.path) + scan.worktrees.map(\.path)
        let candidates = (1..<tree.names.count)
            .filter { tree.totalBytes[$0] >= minimumBytes && isUserContent(tree.path(of: $0), home: home, excluded) }
            .map { Candidate(node: $0, path: tree.path(of: $0)) }
            .sorted { tree.totalBytes[$0.node] != tree.totalBytes[$1.node]
                ? tree.totalBytes[$0.node] > tree.totalBytes[$1.node] : $0.path.count < $1.path.count }
        var groups: [String: [Candidate]] = [:]
        var order: [String] = []
        for candidate in candidates {
            let name = tree.names[candidate.node]
            if groups[name] == nil { order.append(name) }
            groups[name, default: []].append(candidate)
        }
        return order.compactMap { groups[$0] }.filter { $0.count > 1 }
    }

    /// Under the home folder, outside Library, hidden folders, code bundles, build folders, and worktrees.
    static func isUserContent(_ path: String, home: String, _ excluded: [String]) -> Bool {
        guard path.hasPrefix(home + "/") else { return false }
        let components = path.dropFirst(home.count + 1).split(separator: "/")
        guard components.first != "Library",
              !components.contains(where: { $0.hasPrefix(".") }),
              !components.contains(where: { bundleExtensions.contains(($0 as NSString).pathExtension.lowercased()) }),
              !excluded.contains(where: { path == $0 || path.hasPrefix($0 + "/") })
        else { return false }
        return true
    }

    /// Neither inside the other, about the same size, and the same number of subfolders.
    static func isPlausibleCopy(_ copy: Int, of original: Int, in tree: ScanTree) -> Bool {
        let copyPath = tree.path(of: copy), originalPath = tree.path(of: original)
        guard !copyPath.hasPrefix(originalPath + "/"), !originalPath.hasPrefix(copyPath + "/") else { return false }
        let sizes = (tree.totalBytes[copy], tree.totalBytes[original])
        guard Double(abs(sizes.0 - sizes.1)) <= Double(max(sizes.0, sizes.1)) * sizeTolerance else { return false }
        return folderCount(under: copy, in: tree) == folderCount(under: original, in: tree)
    }

    static func folderCount(under node: Int, in tree: ScanTree) -> Int {
        var count = 0
        var stack = [node]
        while let next = stack.popLast() {
            count += 1
            stack += tree.children[next].map(Int.init)
        }
        return count
    }

    /// When oldest is unknown, a folder sorts last, so it's the one listed as the copy.
    static func birth(of path: String) -> Double {
        var info = stat()
        guard lstat(path, &info) == 0 else { return .infinity }
        return Double(info.st_birthtimespec.tv_sec) + Double(info.st_birthtimespec.tv_nsec) / 1e9
    }

    // MARK: Confirming a pair

    struct File {
        let path: String
        let type: BulkReader.EntryType
        let entry: BulkReader.Entry
    }

    /// What removing `copy` would free, or nil when the two folders don't hold the same files.
    static func freedBytes(removing copy: Int, keeping original: Int, in tree: ScanTree) -> Int64? {
        guard let copyFiles = files(under: copy, in: tree), let originalFiles = files(under: original, in: tree),
              copyFiles.count == originalFiles.count
        else { return nil }
        var pairs: [(copy: File, original: File)] = []
        for (relative, file) in copyFiles {
            // Space on disk is rounded to whole blocks, so an edited small file usually keeps it. The
            // exact length is what tells an edited copy from an untouched one.
            guard let other = originalFiles[relative], other.type == file.type,
                  other.entry.allocatedBytes == file.entry.allocatedBytes,
                  file.type != .file || length(of: file.path) == length(of: other.path)
            else { return nil }
            pairs.append((file, other))
        }
        // Files that are the same storage already match; only separate copies need reading.
        let separate = pairs.filter { pair in
            pair.copy.type == .file && pair.copy.entry.fileID != pair.original.entry.fileID
                && !(pair.copy.entry.cloneReferences > 1 && pair.copy.entry.cloneID == pair.original.entry.cloneID)
        }
        let sample = separate
            .sorted { $0.copy.entry.allocatedBytes > $1.copy.entry.allocatedBytes }
            .prefix(sampledFiles)
        guard sample.allSatisfy({ sameContent($0.copy.path, $0.original.path) }) else { return nil }
        return copyFiles.values.reduce(Int64(0)) { total, file in
            // A hard link frees nothing while another link remains; a clone frees only what it doesn't share.
            if file.entry.linkCount > 1 { return total }
            if file.entry.cloneReferences > 1 { return total + (BulkReader.privateSize(of: file.path) ?? 0) }
            return total + file.entry.allocatedBytes
        }
    }

    /// A file's exact length in bytes, or nil when it can't be read.
    static func length(of path: String) -> Int64? {
        var info = stat()
        return lstat(path, &info) == 0 ? Int64(info.st_size) : nil
    }

    /// Every file under a scanned folder by its path inside it. Only folders the scan reached are
    /// opened. Nil when a folder won't open or there are too many files.
    static func files(under node: Int, in tree: ScanTree) -> [String: File]? {
        let reader = BulkReader()
        defer { reader.deallocate() }
        var found: [String: File] = [:]
        var stack = [(node: node, relative: "")]
        while let (next, relative) = stack.popLast() {
            let path = tree.path(of: next)
            let descriptor = open(path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard descriptor >= 0 else { return nil }
            reader.read(descriptor) { entry in
                guard entry.type != .directory else { return }
                found[relative + entry.name] = File(path: path + "/" + entry.name, type: entry.type, entry: entry)
            }
            close(descriptor)
            guard found.count <= maximumFiles else { return nil }
            for child in tree.children[next].map(Int.init) {
                stack.append((child, relative + tree.names[child] + "/"))
            }
        }
        return found
    }

    /// Compares two files of the same size in evenly spaced chunks, the whole file when it's small.
    static func sameContent(_ first: String, _ second: String) -> Bool {
        let one = open(first, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        let two = open(second, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        defer {
            if one >= 0 { close(one) }
            if two >= 0 { close(two) }
        }
        var infoOne = stat(), infoTwo = stat()
        guard one >= 0, two >= 0, fstat(one, &infoOne) == 0, fstat(two, &infoTwo) == 0,
              infoOne.st_size == infoTwo.st_size
        else { return false }
        // Don't fill the file cache with what's read once.
        _ = fcntl(one, F_NOCACHE, 1)
        _ = fcntl(two, F_NOCACHE, 1)
        let size = Int64(infoOne.st_size)
        let chunk = Int64(chunkBytes)
        let offsets: [Int64] = size <= chunk * Int64(chunksPerFile)
            ? Array(stride(from: 0, to: size, by: Int(chunk)))
            : (0..<chunksPerFile).map { Int64($0) * (size - chunk) / Int64(chunksPerFile - 1) }
        let bufferOne = UnsafeMutableRawPointer.allocate(byteCount: chunkBytes, alignment: 16)
        let bufferTwo = UnsafeMutableRawPointer.allocate(byteCount: chunkBytes, alignment: 16)
        defer {
            bufferOne.deallocate()
            bufferTwo.deallocate()
        }
        for offset in offsets {
            let length = Int(min(chunk, size - offset))
            guard pread(one, bufferOne, length, off_t(offset)) == length,
                  pread(two, bufferTwo, length, off_t(offset)) == length,
                  memcmp(bufferOne, bufferTwo, length) == 0
            else { return false }
        }
        return true
    }
}

extension CleanupCatalog {
    func duplicateFolders(_ scan: ScanResult) -> [Candidate] {
        DuplicateFolders.find(in: scan, home: home, minimumBytes: Self.minimumDuplicateBytes).map { copy in
            let original = "~" + copy.original.dropFirst(home.count)
            return Candidate(
                path: copy.path, detail: "Same file names and sizes as \(original)",
                name: Trasher.Report.label(copy.path), bytes: copy.bytes
            )
        }
    }
}
