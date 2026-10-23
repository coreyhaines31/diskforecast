import Foundation

/// The home folder's Trash: what's in it, and emptying it without Finder, which gives up on paths
/// that are too long and asks about each locked or busy item.
public struct TrashBin: Sendable {
    public let folder: String

    public init(home: String) {
        folder = Trasher.resolved(home) + "/.Trash"
    }

    /// Everything at the top of the Trash. Reading it needs Full Disk Access.
    public func contents() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder).map { folder + "/" + $0 }
    }

    /// Deletes everything in the Trash except what a running program still has open, which would
    /// keep using it. Returns what was deleted and what wasn't, and why.
    public func empty(openFiles: OpenFiles = .current()) throws -> Trasher.Report {
        var report = Trasher.Report()
        report.deleted = true
        for path in try contents() {
            if let user = openFiles.user(of: path) {
                report.failed.append((path, "\(user) is still using it. Quit \(user), then empty the Trash again."))
                continue
            }
            do {
                try Deleter.remove(path)
                report.moved.append(path)
            } catch {
                report.failed.append((path, error.localizedDescription))
            }
        }
        return report
    }
}
