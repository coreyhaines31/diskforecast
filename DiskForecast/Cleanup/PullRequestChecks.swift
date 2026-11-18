import DiskForecastCore
import Foundation

/// Asks GitHub about worktree branches' pull requests through the person's own `gh` command.
/// Only runs when they've turned it on in Settings › Scanning.
enum PullRequestChecks {
    /// How long one repository's answer may take before it counts as unknown.
    static let timeout: TimeInterval = 20

    static var executable: String? {
        ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Worktree path to pull request state. Empty when gh isn't installed.
    static func states(of worktrees: [WorktreeFinding]) async -> [String: PullRequestState] {
        guard let command = executable else { return [:] }
        let branches = Dictionary(worktrees.map { ($0.path, $0.branch) }) { first, _ in first }
        return await PullRequestLookup.states(
            of: worktrees.map(\.path), branch: { branches[$0] ?? nil }, remoteURL: GitState.remoteURL(at:),
            ask: { await ask(command, about: $0) }
        )
    }

    /// `gh pr list` for one repository, or nil when it fails, isn't signed in, or runs too long.
    private static func ask(_ command: String, about repository: GitHubRepository) async -> Data? {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(filePath: command)
            process.arguments = [
                "pr", "list", "--repo", repository.slug, "--state", "all",
                "--limit", String(PullRequestLookup.limit), "--json", PullRequestList.fields
            ]
            // Outside any checkout, so gh reads nothing from a repository's own config.
            process.currentDirectoryURL = FileManager.default.temporaryDirectory
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = Shell.searchPath
            environment["GH_PROMPT_DISABLED"] = "1"
            environment["GH_NO_UPDATE_NOTIFIER"] = "1"
            environment["NO_COLOR"] = "1"
            process.environment = environment
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            process.standardInput = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return nil }
            let deadline = DispatchWorkItem { [process] in process.terminate() }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: deadline)
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            deadline.cancel()
            guard process.terminationReason == .exit, process.terminationStatus == 0 else { return nil }
            return data
        }.value
    }
}
