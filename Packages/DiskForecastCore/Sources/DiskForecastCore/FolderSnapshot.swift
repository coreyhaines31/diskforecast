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
    /// Folders the scan couldn't read or didn't enter, relative to the home folder, like the ones
    /// macOS guards when Full Disk Access is off. Nil in snapshots saved before this was recorded:
    /// those can't say what they missed, so a folder absent from one still counts as new.
    public var unmeasured: [String]?

    public init(
        day: Date, homeBytes: Int64, freeBytes: Int64, folders: [String: Int64], unmeasured: [String]? = []
    ) {
        self.day = day
        self.homeBytes = homeBytes
        self.freeBytes = freeBytes
        self.folders = folders
        self.unmeasured = unmeasured
    }

    /// `unmeasured` takes absolute paths; the ones outside the scanned folder are dropped.
    public init(
        tree: ScanTree, freeBytes: Int64, at date: Date, calendar: Calendar = .current, unmeasured: [String] = []
    ) {
        var folders: [String: Int64] = [:]
        func record(under node: Int, path: String, depth: Int) {
            guard depth < Self.maxDepth else { return }
            for child in tree.children[node].map(Int.init) where tree.totalBytes[child] >= Self.minimumBytes {
                let childPath = path.isEmpty ? tree.names[child] : path + "/" + tree.names[child]
                folders[childPath] = tree.totalBytes[child]
                record(under: child, path: childPath, depth: depth + 1)
            }
        }
        if !tree.children.isEmpty {
            record(under: 0, path: "", depth: 0)
        }
        let root = tree.rootPath.hasSuffix("/") ? tree.rootPath : tree.rootPath + "/"
        let relative = unmeasured.filter { $0.hasPrefix(root) }.map { String($0.dropFirst(root.count)) }
        self.init(
            day: calendar.startOfDay(for: date), homeBytes: tree.totalSize, freeBytes: freeBytes, folders: folders,
            unmeasured: Set(relative).sorted()
        )
    }

    /// Whether the folder is absent because the scan didn't read it or a folder around it. An
    /// older snapshot can't say, and guessing yes would hide every folder made since as "first
    /// measured" for as long as that snapshot is compared against, so it says no.
    func couldNotMeasure(_ path: String) -> Bool {
        guard folders[path] == nil, let unmeasured else { return false }
        return unmeasured.contains { path == $0 || path.hasPrefix($0 + "/") }
    }
}

/// How much one folder changed between two snapshots.
public struct FolderChange: Sendable, Equatable, Identifiable {
    /// Path relative to the home folder.
    public let path: String
    public let oldBytes: Int64
    public let newBytes: Int64

    public var id: String { path }
    /// How much it grew or shrank. Zero for a folder measured for the first time.
    public var delta: Int64 { isFirstMeasured ? 0 : newBytes - oldBytes - firstMeasuredBytes }
    /// Absent, or too small to record, in the earlier snapshot, which did measure where it is.
    public var isNew: Bool { oldBytes == 0 && !isFirstMeasured && !listedForFirstMeasured }
    /// What was measured for the first time: the folder itself, or the folders inside it.
    public var firstMeasuredSize: Int64 { isFirstMeasured ? newBytes : firstMeasuredBytes }
    public var isGone: Bool { newBytes == 0 }
    public var name: String { (path as NSString).lastPathComponent }
    /// Whether the snapshots recorded anything below this folder.
    public let hasChildren: Bool
    /// The earlier scan couldn't measure this folder, so its size isn't growth.
    public let isFirstMeasured: Bool
    /// Bytes in folders inside this one that the earlier scan couldn't measure, left out of `delta`.
    public let firstMeasuredBytes: Int64
    /// Listed for what was measured for the first time, not for growing or shrinking.
    public let listedForFirstMeasured: Bool
}

public enum FolderChanges {
    /// Folders directly under `parent` ("" for the top level) whose size changed by at least
    /// `threshold`, biggest change first. Then, biggest first, the ones where at least that much
    /// was measured for the first time, in them or as them.
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
            let oldBytes = old.folders[path] ?? 0
            let newBytes = new.folders[path] ?? 0
            let firstMeasured = isFirstMeasured(path, from: old, to: new)
            let inside = firstMeasuredBytes(under: path, from: old, to: new)
            let grew = !firstMeasured && abs(newBytes - oldBytes - inside) >= threshold
            guard grew || (firstMeasured ? newBytes : inside) >= threshold else { return nil }
            return FolderChange(
                path: path, oldBytes: oldBytes, newBytes: newBytes,
                hasChildren: all.contains { $0.hasPrefix(path + "/") },
                isFirstMeasured: firstMeasured, firstMeasuredBytes: inside, listedForFirstMeasured: !grew
            )
        }
        .sorted { first, second in
            if first.listedForFirstMeasured != second.listedForFirstMeasured { return second.listedForFirstMeasured }
            return first.listedForFirstMeasured
                ? first.firstMeasuredSize > second.firstMeasuredSize : abs(first.delta) > abs(second.delta)
        }
    }

    static func isFirstMeasured(_ path: String, from old: FolderSnapshot, to new: FolderSnapshot) -> Bool {
        new.folders[path] != nil && old.couldNotMeasure(path)
    }

    /// What the folders under `parent` that were measured for the first time add up to, counting
    /// each only at its outermost folder.
    static func firstMeasuredBytes(under parent: String, from old: FolderSnapshot, to new: FolderSnapshot) -> Int64 {
        let prefix = parent.isEmpty ? "" : parent + "/"
        return new.folders.reduce(0) { total, folder in
            let (path, bytes) = folder
            guard path.hasPrefix(prefix), isFirstMeasured(path, from: old, to: new) else { return total }
            let enclosing = (path as NSString).deletingLastPathComponent
            let counted = enclosing != parent && isFirstMeasured(enclosing, from: old, to: new)
            return counted ? total : total + bytes
        }
    }

    /// Space the disk lost or gained outside the home folder: the change in used space that the
    /// home folder doesn't account for. System Data, other accounts, and apps live here. Folders
    /// measured for the first time don't count as the home folder's growth.
    public static func outsideHomeDelta(from old: FolderSnapshot, to new: FolderSnapshot) -> Int64 {
        let usedGrowth = old.freeBytes - new.freeBytes
        let homeGrowth = new.homeBytes - old.homeBytes - firstMeasuredBytes(under: "", from: old, to: new)
        return usedGrowth - homeGrowth
    }
}
