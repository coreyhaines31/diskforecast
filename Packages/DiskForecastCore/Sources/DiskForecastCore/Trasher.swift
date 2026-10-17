import Foundation

/// Moves things to the Trash, and only things it's safe to move: inside the home folder, never
/// the home folder or one of its standard folders, and never through a link that leads out.
/// Nothing is ever deleted outright.
public struct Trasher: Sendable {
    public enum Refusal: Error, Equatable, CustomStringConvertible {
        case outsideHome
        case protectedFolder
        case missing

        public var description: String {
            switch self {
            case .outsideHome: "It's outside your home folder."
            case .protectedFolder: "It's one of your Mac's standard folders."
            case .missing: "It's no longer there."
            }
        }
    }

    public struct Report: Sendable {
        public var moved: [String] = []
        public var movedBytes: Int64 = 0
        public var failed: [(path: String, reason: String)] = []
        /// Where each moved path ended up in the Trash, for putting it back.
        public var inTrash: [String: String] = [:]
        /// What each moved path held.
        public var movedSizes: [String: Int64] = [:]
    }

    static let protectedNames: Set<String> = [
        "Library", "Desktop", "Documents", "Downloads", "Movies", "Music", "Pictures", "Public",
        "Applications", ".Trash"
    ]

    public let home: String

    public init(home: String) {
        self.home = Self.resolved(home)
    }

    /// Why a path can't go to the Trash, or nil when it can.
    public func refusal(for path: String) -> Refusal? {
        let parent = Self.resolved((path as NSString).deletingLastPathComponent)
        let name = (path as NSString).lastPathComponent
        guard !name.isEmpty, name != ".", name != ".." else { return .protectedFolder }
        let full = parent + "/" + name
        guard full.hasPrefix(home + "/") else { return .outsideHome }
        if parent == home && Self.protectedNames.contains(name) { return .protectedFolder }
        if full == home + "/Library/Caches" || full == home + "/Library/Logs" { return .protectedFolder }
        var info = stat()
        guard lstat(full, &info) == 0 else { return .missing }
        return nil
    }

    /// Moves each path to the Trash. `sizes` reports what each one held, for the total.
    public func trash(_ paths: [String], sizes: [String: Int64] = [:]) -> Report {
        var report = Report()
        for path in paths {
            if let refusal = refusal(for: path) {
                report.failed.append((path, refusal.description))
                continue
            }
            do {
                var trashed: NSURL?
                try FileManager.default.trashItem(at: URL(filePath: path), resultingItemURL: &trashed)
                report.moved.append(path)
                report.inTrash[path] = trashed?.path
                report.movedBytes += sizes[path] ?? 0
                report.movedSizes[path] = sizes[path]
            } catch {
                report.failed.append((path, error.localizedDescription))
            }
        }
        return report
    }

    /// Moves what a trash run moved back where it was. Returns what couldn't go back, and why.
    public func putBack(_ report: Report) -> [(path: String, reason: String)] {
        var failed: [(path: String, reason: String)] = []
        for path in report.moved {
            guard let trashed = report.inTrash[path] else {
                failed.append((path, "It isn't in the Trash anymore."))
                continue
            }
            var info = stat()
            if lstat(path, &info) == 0 {
                // An app may have made a fresh cache folder in the same place.
                failed.append((path, "Something new is already there. It's still in the Trash."))
                continue
            }
            do {
                let parent = (path as NSString).deletingLastPathComponent
                try FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true)
                try FileManager.default.moveItem(atPath: trashed, toPath: path)
            } catch {
                failed.append((path, error.localizedDescription))
            }
        }
        return failed
    }

    /// The path with its links resolved, so a link can't smuggle something out of home.
    static func resolved(_ path: String) -> String {
        guard let real = realpath(path, nil) else { return path }
        defer { free(real) }
        return String(cString: real)
    }
}
