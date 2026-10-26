import Foundation

/// Claude Code keeps each session's temp files in /private/tmp/claude-<uid>/<project>/<session>,
/// scratch builds and cloned repos included, and never removes them.
public enum AgentScratch {
    public static var folder: String { "/private/tmp/claude-\(getuid())" }

    /// Sessions untouched this long are probably over.
    static let idleDays = 2.0
}

extension CleanupCatalog {
    /// Claude Code sessions whose temp files haven't changed in a couple of days, from the
    /// separate scan of `AgentScratch.folder`.
    func claudeSessions() -> [Candidate] {
        guard let root = agentScratch?.tree.rootPath else { return [] }
        let cutoff = now.addingTimeInterval(-AgentScratch.idleDays * 86_400)
        return Self.folders(in: root).flatMap { project in
            Self.folders(in: root + "/" + project).compactMap { session -> Candidate? in
                let folder = root + "/" + project + "/" + session
                guard let used = Self.lastChange(of: folder), used < cutoff else { return nil }
                return Candidate(
                    path: folder,
                    detail: "In \(projectLabel(project)) · last used \(Age.phrase(from: used, to: now))",
                    name: "Claude Code session from \(used.formatted(.dateTime.month(.abbreviated).day()))"
                )
            }
        }
    }

    /// The project folder a session ran in. Claude Code names the folder after its path with every
    /// slash turned into a dash, so this guesses the slashes back and keeps the guess only if it exists.
    func projectLabel(_ project: String) -> String {
        let homeName = home.replacingOccurrences(of: "/", with: "-")
        guard project.hasPrefix(homeName) else { return project }
        let rest = String(project.dropFirst(homeName.count))
        guard !rest.isEmpty else { return "~" }
        let guess = rest.replacingOccurrences(of: "-", with: "/")
        return FileManager.default.fileExists(atPath: home + guess) ? "~" + guess : "~/" + rest.dropFirst()
    }

    private static func folders(in path: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []).filter { name in
            var isFolder: ObjCBool = false
            return FileManager.default.fileExists(atPath: path + "/" + name, isDirectory: &isFolder)
                && isFolder.boolValue
        }
    }

    /// The newest change to the session folder or anything directly in it. A running session
    /// keeps writing task output there.
    private static func lastChange(of folder: String) -> Date? {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
        let dates = ([folder] + names.map { folder + "/" + $0 }).compactMap { path -> Date? in
            var info = stat()
            guard lstat(path, &info) == 0 else { return nil }
            return Date(timeIntervalSince1970: TimeInterval(info.st_mtimespec.tv_sec))
        }
        return dates.max()
    }
}
