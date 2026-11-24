import Foundation

/// What removing a git checkout would lose: changed files, and commits no remote has.
///
/// Git runs with every program a repository's config can name turned off (fsmonitor, hooks,
/// pager, signature checks, SSH, fetching), so looking at a checkout never runs code from it
/// and never reaches the network. Learned from tobi/disktree.
public struct GitState: Sendable, Equatable {
    /// Changed, staged, or untracked paths. Nil when the repository names its own filter
    /// programs, since `git status` would run them.
    public let changed: Int?
    /// Commits in the checkout that no remote has. Nil when the repository has no remote.
    public let unpushed: Int?
    /// Whether the commit it's at is already in a main branch of a remote, as last fetched. Nil
    /// when the repository has no remote, or git couldn't say.
    public let merged: Bool?

    public init(changed: Int?, unpushed: Int?, merged: Bool? = nil) {
        self.changed = changed
        self.unpushed = unpushed
        self.merged = merged
    }

    /// Nothing would be lost by removing it.
    public var isClean: Bool { changed == 0 && unpushed == 0 }

    /// Clean, and the work in it has already landed: nothing left to look at before removing it.
    public var isFinished: Bool { isClean && merged == true }

    /// "clean and pushed", "clean, pushed and merged", "3 changed files, 2 commits not pushed".
    public var summary: String {
        if isFinished { return "clean, pushed and merged" }
        if isClean { return "clean and pushed" }
        var parts: [String] = []
        switch changed {
        case 0: break
        case 1: parts.append("1 changed file")
        case let count?: parts.append("\(count) changed files")
        case nil: parts.append("changes unknown")
        }
        switch unpushed {
        case 0: break
        case 1: parts.append("1 commit not pushed")
        case let count?: parts.append("\(count) commits not pushed")
        case nil: parts.append("no remote")
        }
        return parts.joined(separator: ", ")
    }

    /// Asks git about the checkout at `path`. Nil when git isn't installed or the folder isn't a
    /// checkout.
    public static func read(at path: String) -> GitState? {
        guard executable != nil, run(["rev-parse", "--is-inside-work-tree"], in: path) != nil else { return nil }
        var changed: Int?
        if !namesItsOwnFilters(path) {
            // Submodules are other checkouts with configs of their own.
            changed = run(["status", "--porcelain=v1", "-z", "--no-renames", "--ignore-submodules=all"], in: path)
                .map { $0.split(separator: "\0").count }
        }
        var unpushed: Int?
        var merged: Bool?
        if let remotes = run(["remote"], in: path), !remotes.isEmpty {
            unpushed = run(["rev-list", "--count", "HEAD", "--not", "--remotes"], in: path).flatMap { Int($0) }
            merged = run(["for-each-ref", "--contains", "HEAD", "--format=%(refname)", "refs/remotes"], in: path)
                .map { $0.split(separator: "\n").contains { isMainBranch(remoteRef: String($0)) } }
        }
        return GitState(changed: changed, unpushed: unpushed, merged: merged)
    }

    /// The branch names work lands on. A squash merge leaves the branch's own commits out of
    /// these, so it reads as not merged, which errs toward keeping it.
    static let mainBranches: Set<String> = ["HEAD", "main", "master", "development", "develop", "trunk"]

    /// Whether `refs/remotes/<remote>/<branch>` is one of a remote's main branches. A team's own
    /// prefix, as in `cf/development`, counts too.
    static func isMainBranch(remoteRef: String) -> Bool {
        let parts = remoteRef.split(separator: "/")
        guard parts.count >= 4, parts[0] == "refs", parts[1] == "remotes", let last = parts.last else { return false }
        return parts.count <= 5 && mainBranches.contains(String(last))
    }

    /// The URL of the checkout's `origin` remote, or its first remote when none is named that.
    public static func remoteURL(at path: String) -> String? {
        guard let remotes = run(["remote"], in: path)?.split(separator: "\n"), let first = remotes.first
        else { return nil }
        let name = remotes.contains("origin") ? "origin" : String(first)
        return run(["remote", "get-url", name], in: path)
    }

    /// The commit a checkout is at.
    static func head(at path: String) -> String? {
        run(["rev-parse", "--verify", "HEAD"], in: path)
    }

    /// Whether a folder is in a git checkout: it or a folder above it holds a `.git`. Doesn't
    /// run git, so it's cheap to ask for every project.
    static func isInsideRepository(_ path: String) -> Bool {
        var current = path
        var info = stat()
        while current.count > 1 {
            if lstat(current + "/.git", &info) == 0 { return true }
            current = (current as NSString).deletingLastPathComponent
        }
        return false
    }

    /// Whether git itself says a folder isn't in a repository, as it does for a `.git` that's
    /// empty or half deleted. Any other failure, like a repository it won't trust, isn't that.
    static func saysNotARepository(_ path: String) -> Bool {
        guard let executable else { return false }
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = ["-C", path, "rev-parse", "--git-dir"]
        var environment = ProcessInfo.processInfo.environment
        // The message is matched, so it has to be in English.
        environment["LC_ALL"] = "C"
        process.environment = environment
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        guard let result = try? TimedProcess.run(process, output: pipe, timeout: timeout), !result.timedOut
        else { return false }
        return result.status != 0 && (String(bytes: result.data, encoding: .utf8) ?? "")
            .contains("not a git repository")
    }

    /// How a checkout's repository treats one of its folders.
    enum Standing: Equatable {
        /// Nothing in it is tracked, and git ignores the rest.
        case ignored
        /// Some of its files are tracked.
        case tracked
        /// Nothing in it is tracked, but git doesn't ignore it.
        case untracked
    }

    /// Asks how git treats the folder `name` directly inside `project`. Nil when git couldn't say.
    static func standing(of name: String, in project: String) -> Standing? {
        // Tracked files come back tagged with a letter and files git doesn't ignore with "?";
        // ignored ones aren't listed. An untracked folder is one line, not one per file, and isn't
        // listed when everything in it is ignored, as in a cache that brings its own .gitignore.
        let arguments = [
            "ls-files", "-z", "-t", "--cached", "--others", "--exclude-standard", "--directory",
            "--no-empty-directory", "--", ":(literal)" + name
        ]
        guard let output = git(arguments, in: project), output.status == 0 else { return nil }
        let entries = output.text.split(separator: "\0")
        if entries.isEmpty { return .ignored }
        return entries.contains { !$0.hasPrefix("?") } ? .tracked : .untracked
    }

    /// Whether the repository's own config (not the user's) names filter programs.
    static func namesItsOwnFilters(_ path: String) -> Bool {
        guard let output = git(["config", "--show-scope", "--includes", "--get-regexp", "^filter\\."], in: path)
        else { return true }
        switch output.status {
        case 1: return false
        case 0:
            return output.text.split(separator: "\n").contains { line in
                let scope = line.split(separator: "\t").first
                return scope == "local" || scope == "worktree"
            }
        default: return true
        }
    }

    /// Git, if it's installed. `/usr/bin/git` is a stub that offers to install the developer
    /// tools when they're missing, so it only counts when they're there.
    static let executable: String? = {
        for candidate in ["/opt/homebrew/bin/git", "/usr/local/bin/git"]
        where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/xcode-select")
        process.arguments = ["-p"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let folder = (String(bytes: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var isDirectory: ObjCBool = false
        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: folder, isDirectory: &isDirectory), isDirectory.boolValue
        else { return nil }
        return "/usr/bin/git"
    }()

    private static let safety = [
        "core.fsmonitor=false", "core.hooksPath=/dev/null", "core.pager=cat", "log.showSignature=false",
        "gpg.program=false", "gpg.ssh.program=false", "gpg.x509.program=false", "core.sshCommand=false",
        "protocol.allow=never"
    ].flatMap { ["-c", $0] }

    private static func run(_ arguments: [String], in path: String) -> String? {
        guard let output = git(arguments, in: path), output.status == 0 else { return nil }
        return output.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func git(_ arguments: [String], in path: String) -> (status: Int32, text: String)? {
        guard let executable else { return nil }
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = ["-C", path] + safety + arguments
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_OPTIONAL_LOCKS"] = "0"
        environment["GIT_NO_LAZY_FETCH"] = "1"
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        // A checkout on a drive that stopped answering would otherwise hold up the whole list.
        guard let result = try? TimedProcess.run(process, output: pipe, timeout: timeout), !result.timedOut
        else { return nil }
        return (result.status, String(bytes: result.data, encoding: .utf8) ?? "")
    }

    /// How long one git call may take.
    static let timeout: TimeInterval = 10
}
