import Darwin
import Foundation

/// When someone last worked in a project, judged by what work leaves behind: git's HEAD log,
/// written by every commit, checkout, and pull, and Claude Code's conversations there. File dates
/// say less, since installs and background tools touch projects nobody is working in. Git's
/// `index` is left out for the same reason: editors and agent hosts rewrite it while idle.
/// Learned from mattt/plonge.
public enum ProjectActivity {
    /// The checkout a folder is in: it or the nearest folder above it that holds a `.git`.
    static func repositoryRoot(of path: String) -> String? {
        var current = path
        var info = stat()
        while current.count > 1 {
            if lstat(current + "/.git", &info) == 0 { return current }
            current = (current as NSString).deletingLastPathComponent
        }
        return nil
    }

    /// Where a checkout keeps git's files: its `.git` folder, or for a worktree the folder its
    /// `.git` file points to.
    static func gitDirectory(of root: String) -> String? {
        let git = root + "/.git"
        var info = stat()
        guard lstat(git, &info) == 0 else { return nil }
        if info.st_mode & S_IFMT == S_IFDIR { return git }
        guard info.st_mode & S_IFMT == S_IFREG, let contents = try? String(contentsOfFile: git, encoding: .utf8),
              let line = contents.split(whereSeparator: \.isNewline).first, line.hasPrefix("gitdir: ")
        else { return nil }
        let target = String(line.dropFirst("gitdir: ".count)).trimmingCharacters(in: .whitespaces)
        return ((target.hasPrefix("/") ? target : root + "/" + target) as NSString).standardizingPath
    }

    /// The last commit, checkout, or pull in a checkout: when its HEAD log was written, or HEAD
    /// itself where logs are off.
    static func lastGitActivity(root: String) -> Date? {
        guard let directory = gitDirectory(of: root) else { return nil }
        let files = FileManager.default
        for file in ["/logs/HEAD", "/HEAD"] {
            if let date = (try? files.attributesOfItem(atPath: directory + file))?[.modificationDate] as? Date {
                return date
            }
        }
        return nil
    }

    /// A path the way Claude Code names its folder for a project: every character that isn't a
    /// letter or digit becomes a hyphen.
    static func conversationKey(_ path: String) -> String {
        String(path.map { $0.isLetter || $0.isNumber ? $0 : "-" })
    }

    /// When the newest Claude Code conversation in each project folder was last written, by key.
    public static func conversations(in folder: String) -> [String: Date] {
        let files = FileManager.default
        var newest: [String: Date] = [:]
        for project in (try? files.contentsOfDirectory(atPath: folder)) ?? [] {
            let path = folder + "/" + project
            let dates = ((try? files.contentsOfDirectory(atPath: path)) ?? [])
                .filter { $0.hasSuffix(".jsonl") }
                .compactMap { (try? files.attributesOfItem(atPath: path + "/" + $0))?[.modificationDate] as? Date }
            if let latest = dates.max() { newest[conversationKey(project)] = latest }
        }
        return newest
    }

    /// The newest conversation in a checkout or any folder under it. A sibling whose name starts
    /// the same, like `app-two` beside `app`, can match too, which only makes `app` look busier.
    static func lastConversation(root: String, conversations: [String: Date]) -> Date? {
        let key = conversationKey(root)
        return conversations.filter { $0.key == key || $0.key.hasPrefix(key + "-") }.values.max()
    }

    /// When each project was last worked in. One that isn't in a git checkout is left out: without
    /// git there's nothing to say it's quiet.
    public static func last(
        for projects: [String], conversations: [String: Date]
    ) -> [String: Date] {
        var byRoot: [String: Date?] = [:]
        var result: [String: Date] = [:]
        for project in Set(projects) {
            guard let root = repositoryRoot(of: project) else { continue }
            if byRoot[root] == nil {
                let dates = [lastGitActivity(root: root), lastConversation(root: root, conversations: conversations)]
                // No git date means the checkout couldn't be read, so nothing is known about it.
                byRoot[root] = .some(dates[0] == nil ? nil : dates.compactMap { $0 }.max())
            }
            if let date = byRoot[root] ?? nil { result[project] = date }
        }
        return result
    }
}
