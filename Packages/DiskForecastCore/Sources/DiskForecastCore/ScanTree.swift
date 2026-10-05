import Foundation

/// A finished scan: one node per directory, with each directory's own file bytes rolled up into
/// its ancestors. Files aren't kept as nodes, except the largest ones and the disk images.
public struct ScanTree: Sendable {
    public let rootPath: String
    let names: [String]
    let parents: [Int32]
    let children: [[Int32]]
    /// Bytes of the files directly inside each directory.
    let ownBytes: [Int64]
    /// Bytes of everything under each directory.
    let totalBytes: [Int64]

    public var directoryCount: Int { names.count }
    public var totalSize: Int64 { totalBytes.first ?? 0 }

    init(rootPath: String, names: [String], parents: [Int32], children: [[Int32]], ownBytes: [Int64]) {
        self.rootPath = rootPath
        self.names = names
        self.parents = parents
        self.children = children
        self.ownBytes = ownBytes
        // Children are always added after their parent, so walking backwards rolls sizes up.
        var totals = ownBytes
        for index in stride(from: totals.count - 1, to: 0, by: -1) {
            totals[Int(parents[index])] += totals[index]
        }
        totalBytes = totals
    }

    /// The node for an absolute path at or under the root, if the scan reached it.
    public func node(at path: String) -> Int? {
        let root = rootPath.hasSuffix("/") ? String(rootPath.dropLast()) : rootPath
        guard !names.isEmpty else { return nil }
        if path == root { return 0 }
        guard path.hasPrefix(root + "/") else { return nil }
        var current = 0
        for component in path.dropFirst(root.count + 1).split(separator: "/") {
            guard let next = children[current].first(where: { names[Int($0)] == component }) else { return nil }
            current = Int(next)
        }
        return current
    }

    /// Total bytes under a directory, or nil when it wasn't scanned.
    public func size(of path: String) -> Int64? {
        node(at: path).map { totalBytes[$0] }
    }

    public func path(of node: Int) -> String {
        var components: [String] = []
        var current = node
        while current != 0 {
            components.append(names[current])
            current = Int(parents[current])
        }
        let root = rootPath.hasSuffix("/") ? String(rootPath.dropLast()) : rootPath
        return ([root] + components.reversed()).joined(separator: "/")
    }

    public func size(ofNode node: Int) -> Int64 { totalBytes[node] }

    /// Immediate subdirectories of a directory, largest first.
    public func subdirectories(of node: Int) -> [Int] {
        children[node].map(Int.init).sorted { totalBytes[$0] > totalBytes[$1] }
    }

    /// The folders that take the most space, described at a useful depth: a folder that's
    /// mostly one subfolder (like ~/Library, which is mostly ~/Library/Developer) is replaced by
    /// that subfolder, so the list names what's actually big.
    public func topConsumers(limit: Int, dominantShare: Double = 0.7, maxDepth: Int = 4) -> [Int] {
        guard !names.isEmpty else { return [] }
        let candidates = subdirectories(of: 0).prefix(limit * 2).map { node -> Int in
            var current = node
            for _ in 0..<maxDepth {
                guard let biggest = subdirectories(of: current).first,
                      totalBytes[current] > 0,
                      Double(totalBytes[biggest]) >= Double(totalBytes[current]) * dominantShare
                else { break }
                current = biggest
            }
            return current
        }
        return candidates.sorted { totalBytes[$0] > totalBytes[$1] }.prefix(limit).map { $0 }
    }
}

/// A single file worth reporting on its own: one of the largest, or a disk image.
public struct FileFinding: Sendable, Hashable {
    public let path: String
    public let bytes: Int64
    public let modified: Date

    public init(path: String, bytes: Int64, modified: Date) {
        self.path = path
        self.bytes = bytes
        self.modified = modified
    }
}

/// A rebuildable folder found next to the project file that makes it, like `node_modules`
/// beside `package.json`.
public struct ArtifactFinding: Sendable, Hashable {
    public let kind: ArtifactKind
    public let path: String
    /// The newest modification date among the project's other files.
    public let projectModified: Date
    public let node: Int

    public var projectPath: String { (path as NSString).deletingLastPathComponent }
}

public struct ScanResult: Sendable {
    public let tree: ScanTree
    public let fileCount: Int
    public let largestFiles: [FileFinding]
    public let diskImages: [FileFinding]
    public let artifacts: [ArtifactFinding]
    /// Folders macOS wouldn't let us read, usually because Full Disk Access is off.
    public let deniedCount: Int
    public let deniedSamples: [String]
    /// Folders skipped on purpose: other volumes and protected areas.
    public let skippedPaths: [String]
    /// Folders that never opened, usually because macOS is waiting on a permission prompt.
    public let stalledPaths: [String]
    public let duration: TimeInterval

    public func size(of artifact: ArtifactFinding) -> Int64 { tree.size(ofNode: artifact.node) }
}
