import Foundation

/// Folder sizes from one scan, kept so a later scan can say what grew. Holds every folder in the
/// home folder down to `maxDepth` levels that's at least `minimumBytes`, keyed by its path
/// relative to the home folder ("code", "code/project/node_modules").
public struct FolderSnapshot: Codable, Sendable, Equatable {
    public static let maxDepth = 3
    public static let minimumBytes: Int64 = 100_000_000

    /// Start of the day the scan finished.
    public var day: Date
    /// Everything the scan measured under the home folder.
    public var homeBytes: Int64
    /// Free space on the disk when the scan finished.
    public var freeBytes: Int64
    public var folders: [String: Int64]

    public init(day: Date, homeBytes: Int64, freeBytes: Int64, folders: [String: Int64]) {
        self.day = day
        self.homeBytes = homeBytes
        self.freeBytes = freeBytes
        self.folders = folders
    }

    public init(tree: ScanTree, freeBytes: Int64, at date: Date, calendar: Calendar = .current) {
        var folders: [String: Int64] = [:]
        var queue: [(node: Int, path: String, depth: Int)] = tree.children.isEmpty ? [] : [(0, "", 0)]
        while let (node, path, depth) = queue.popLast() {
            guard depth < Self.maxDepth else { continue }
            for child in tree.children[node].map(Int.init) where tree.totalBytes[child] >= Self.minimumBytes {
                let childPath = path.isEmpty ? tree.names[child] : path + "/" + tree.names[child]
                folders[childPath] = tree.totalBytes[child]
                queue.append((child, childPath, depth + 1))
            }
        }
        self.init(
            day: calendar.startOfDay(for: date), homeBytes: tree.totalSize, freeBytes: freeBytes, folders: folders
        )
    }
}

/// How much one folder changed between two snapshots.
public struct FolderChange: Sendable, Equatable, Identifiable {
    /// Path relative to the home folder.
    public let path: String
    public let oldBytes: Int64
    public let newBytes: Int64

    public var id: String { path }
    public var delta: Int64 { newBytes - oldBytes }
    /// Absent, or too small to record, in the earlier snapshot.
    public var isNew: Bool { oldBytes == 0 }
    public var isGone: Bool { newBytes == 0 }
    public var name: String { (path as NSString).lastPathComponent }
    /// Whether the snapshots recorded anything below this folder.
    public let hasChildren: Bool
}

public enum FolderChanges {
    /// Folders directly under `parent` ("" for the top level) whose size changed by at least
    /// `threshold`, biggest change first.
    public static func changes(
        from old: FolderSnapshot,
        to new: FolderSnapshot,
        under parent: String = "",
        threshold: Int64 = 500_000_000
    ) -> [FolderChange] {
        let prefix = parent.isEmpty ? "" : parent + "/"
        func isChild(_ path: String) -> Bool {
            path.hasPrefix(prefix) && !path.dropFirst(prefix.count).contains("/")
        }
        let paths = Set(old.folders.keys.filter(isChild)).union(new.folders.keys.filter(isChild))
        let all = Set(old.folders.keys).union(new.folders.keys)
        return paths.compactMap { path -> FolderChange? in
            let change = FolderChange(
                path: path,
                oldBytes: old.folders[path] ?? 0,
                newBytes: new.folders[path] ?? 0,
                hasChildren: all.contains { $0.hasPrefix(path + "/") }
            )
            return abs(change.delta) >= threshold ? change : nil
        }
        .sorted { abs($0.delta) > abs($1.delta) }
    }

    /// Space the disk lost or gained outside the home folder: the change in used space that the
    /// home folder doesn't account for. System Data, other accounts, and apps live here.
    public static func outsideHomeDelta(from old: FolderSnapshot, to new: FolderSnapshot) -> Int64 {
        let usedGrowth = old.freeBytes - new.freeBytes
        let homeGrowth = new.homeBytes - old.homeBytes
        return usedGrowth - homeGrowth
    }
}
