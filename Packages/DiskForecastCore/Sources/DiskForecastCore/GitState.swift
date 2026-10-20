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

    public init(changed: Int?, unpushed: Int?) {
        self.changed = changed
        self.unpushed = unpushed
    }

    /// Nothing would be lost by removing it.
    public var isClean: Bool { changed == 0 && unpushed == 0 }

    /// "clean and pushed", "3 changed files, 2 commits not pushed".
    public var summary: String {
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
            changed = run(["status", "--porcelain=v1", "-z", "--ignore-submodules=all"], in: path)
                .map { $0.split(separator: "\0").count }
        }
        var unpushed: Int?
        if let remotes = run(["remote"], in: path), !remotes.isEmpty {
            unpushed = run(["rev-list", "--count", "HEAD", "--not", "--remotes"], in: path).flatMap { Int($0) }
        }
        return GitState(changed: changed, unpushed: unpushed)
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
        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(bytes: data, encoding: .utf8) ?? "")
    }
}
