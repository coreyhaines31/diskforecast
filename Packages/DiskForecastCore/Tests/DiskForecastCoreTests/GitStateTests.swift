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

struct WorktreeCleanupTests {
    @Test func listsWorktreesWithWhatTheyWouldLose() async throws {
        let fixture = try GitFixture()
        try Data(count: 2_000_000).write(to: URL(filePath: fixture.worktree + "/big.bin"))
        let scan = await DiskScanner(options: .init(root: fixture.base)).scan()
        let items = CleanupCatalog(home: fixture.base.path).items(from: scan)
        let worktrees = try #require(items.first { $0.id == "git-worktrees" })
        #expect(worktrees.group == .worthALook)
        #expect(worktrees.entries.map(\.path) == [fixture.worktree])
        #expect(worktrees.entries.first?.detail == "repo · 1 changed file · last changed today")
        #expect(!items.contains { $0.id == "worktree-leftovers" })

        // Trashing it takes its records in the repository too, as git worktree remove would.
        let records = fixture.main + "/.git/worktrees/repo-agent"
        let entry = try #require(worktrees.entries.first)
        #expect(entry.companions == [records])
        let trasher = Trasher(home: fixture.base.path)
        let report = trasher.trash([entry])
        #expect(Set(report.moved) == [fixture.worktree, records])
        #expect(!FileManager.default.fileExists(atPath: records))
        #expect(trasher.putBack(report).isEmpty)
        #expect(GitState.read(at: fixture.worktree) != nil)
    }

    @Test func listsRecordsOfDeletedWorktreesButNotLockedOnes() async throws {
        let fixture = try GitFixture()
        let records = fixture.main + "/.git/worktrees/"
        for name in ["gone", "away"] {
            try fixture.git(["worktree", "add", "-q", "-b", name, fixture.base.path + "/" + name], in: fixture.main)
            // Stands in for the submodule copies that make these records big.
            try Data(count: 2_000_000).write(to: URL(filePath: records + name + "/modules.bin"))
            try FileManager.default.removeItem(atPath: fixture.base.path + "/" + name)
        }
        try fixture.git(["worktree", "lock", fixture.base.path + "/away"], in: fixture.main)
        let scan = await DiskScanner(options: .init(root: fixture.base)).scan()
        let items = CleanupCatalog(home: fixture.base.path) { _ in nil }.items(from: scan)
        let leftovers = try #require(items.first { $0.id == "worktree-leftovers" })
        #expect(leftovers.group == .safeToClear)
        // The fixture's live worktree keeps its records off the list.
        #expect(leftovers.entries.map(\.path) == [records + "gone"])
        #expect(leftovers.entries.first?.name == "gone")
        #expect(leftovers.entries.first?.detail == "repo · worktree folder deleted")
    }

    @Test func keepsRecordsOfACheckoutMovedByHand() async throws {
        let fixture = try GitFixture()
        let moved = fixture.base.path + "/moved"
        try FileManager.default.moveItem(atPath: fixture.worktree, toPath: moved)
        try Data(count: 2_000_000).write(to: URL(filePath: moved + "/big.bin"))
        try Data(count: 2_000_000).write(to: URL(filePath: fixture.main + "/.git/worktrees/repo-agent/modules.bin"))
        let scan = await DiskScanner(options: .init(root: fixture.base)).scan()
        let items = CleanupCatalog(home: fixture.base.path) { _ in nil }.items(from: scan)
        #expect(!items.contains { $0.id == "worktree-leftovers" })
        // Its records point at where it used to be, so they don't go with it either.
        let worktree = try #require(items.first { $0.id == "git-worktrees" }?.entries.first)
        #expect(worktree.path == moved)
        #expect(worktree.companions.isEmpty)
    }

    @Test func ignoresGitFilesThatArentPlainFiles() async throws {
        let fixture = try GitFixture()
        let decoy = fixture.base.path + "/decoy"
        try FileManager.default.createDirectory(atPath: decoy, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            atPath: decoy + "/.git", withDestinationPath: fixture.worktree + "/.git"
        )
        let pipeHolder = fixture.base.path + "/pipe-holder"
        try FileManager.default.createDirectory(atPath: pipeHolder, withIntermediateDirectories: true)
        #expect(mkfifo(pipeHolder + "/.git", 0o600) == 0)
        let scan = await DiskScanner(options: .init(root: fixture.base)).scan()
        #expect(scan.worktrees.map(\.path) == [fixture.worktree])
    }
}
