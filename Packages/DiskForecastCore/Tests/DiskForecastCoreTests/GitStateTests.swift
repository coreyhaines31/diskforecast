@testable import DiskForecastCore
import Foundation
import Testing

/// A repository with a remote and one worktree, built with the real git.
struct GitFixture {
    let base: URL
    var main: String { base.path + "/repo" }
    var worktree: String { base.path + "/repo-agent" }

    init() throws {
        base = URL(filePath: Trasher.resolved(
            FileManager.default.temporaryDirectory.appending(path: "DiskForecastGit-\(UUID().uuidString)").path
        ))
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try git(["init", "-q", "--bare", "origin.git"], in: base.path)
        try git(["init", "-q", "repo"], in: base.path)
        try Data("hello".utf8).write(to: URL(filePath: main + "/README.md"))
        try git(["add", "README.md"], in: main)
        try git(["commit", "-q", "-m", "First"], in: main)
        try git(["remote", "add", "origin", base.path + "/origin.git"], in: main)
        try git(["push", "-q", "origin", "HEAD"], in: main)
        try git(["worktree", "add", "-q", "-b", "agent", worktree], in: main)
    }

    func git(_ arguments: [String], in path: String) throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.arguments = ["git", "-c", "user.name=Test", "-c", "user.email=test@example.com",
                             "-c", "init.defaultBranch=main", "-C", path] + arguments
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 { throw CocoaError(.executableLoad) }
    }

    func commit(in path: String) throws {
        try Data(UUID().uuidString.utf8).write(to: URL(filePath: path + "/notes.txt"))
        try git(["add", "notes.txt"], in: path)
        try git(["commit", "-q", "-m", "Work"], in: path)
    }
}

struct GitStateTests {
    @Test func aFreshWorktreeIsClean() throws {
        let fixture = try GitFixture()
        let state = try #require(GitState.read(at: fixture.worktree))
        #expect(state.isClean)
        #expect(state.summary == "clean and pushed")
    }

    @Test func countsChangesAndCommitsNoRemoteHas() throws {
        let fixture = try GitFixture()
        try fixture.commit(in: fixture.worktree)
        try Data("draft".utf8).write(to: URL(filePath: fixture.worktree + "/draft.txt"))
        let state = try #require(GitState.read(at: fixture.worktree))
        #expect(state == GitState(changed: 1, unpushed: 1))
        #expect(state.summary == "1 changed file, 1 commit not pushed")
    }

    @Test func skipsStatusWhenTheRepositoryNamesItsOwnFilter() throws {
        let fixture = try GitFixture()
        try fixture.git(["config", "filter.evil.clean", "touch pwned"], in: fixture.main)
        let state = try #require(GitState.read(at: fixture.worktree))
        #expect(state.changed == nil)
        #expect(state.summary == "changes unknown")
    }

    @Test func aFolderOutsideAnyCheckoutHasNoState() throws {
        let fixture = try GitFixture()
        #expect(GitState.read(at: fixture.base.path) == nil)
    }
}

struct WorktreeFindingTests {
    @Test func scanFindsWorktreesButNotTheMainCheckout() async throws {
        let fixture = try GitFixture()
        let scan = await DiskScanner(options: .init(root: fixture.base)).scan()
        #expect(scan.worktrees.map(\.path) == [fixture.worktree])
        #expect(scan.worktrees.first?.gitDirectory == fixture.main + "/.git/worktrees/repo-agent")
        #expect(scan.worktrees.first?.repository == "repo")
    }

    @Test func readsOnlyWorktreeGitFiles() {
        let checkout = "/Users/me/code/app/.claude/worktrees/fix"
        #expect(WorktreeFinding.gitDirectory(
            fromGitFile: "gitdir: /Users/me/code/app/.git/worktrees/fix\n", checkout: checkout
        ) == "/Users/me/code/app/.git/worktrees/fix")
        #expect(WorktreeFinding.gitDirectory(
            fromGitFile: "gitdir: ../../../.git/worktrees/fix", checkout: checkout
        ) == "/Users/me/code/app/.git/worktrees/fix")
        // A submodule's .git file points into .git/modules.
        #expect(WorktreeFinding.gitDirectory(fromGitFile: "gitdir: ../.git/modules/lib", checkout: checkout) == nil)
        #expect(WorktreeFinding.gitDirectory(fromGitFile: "not git", checkout: checkout) == nil)
    }

    @Test func namesBareRepositoriesWithoutTheSuffix() {
        let finding = WorktreeFinding(
            path: "/Users/me/w/fix", gitDirectory: "/Users/me/repos/app.git/worktrees/fix", modified: Date()
        )
        #expect(finding.repository == "app")
    }
}
