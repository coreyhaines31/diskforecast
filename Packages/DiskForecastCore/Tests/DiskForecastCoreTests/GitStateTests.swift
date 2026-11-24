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
            TestFolders.make("DiskForecastGit").path
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
        // It sits on the commit the remote's main branch has.
        #expect(state.isFinished)
        #expect(state.summary == "clean, pushed and merged")
    }

    @Test func pushedButNotMergedIsNotFinished() throws {
        let fixture = try GitFixture()
        try fixture.commit(in: fixture.worktree)
        try fixture.git(["push", "-q", "origin", "agent"], in: fixture.worktree)
        let state = try #require(GitState.read(at: fixture.worktree))
        #expect(state == GitState(changed: 0, unpushed: 0, merged: false))
        #expect(!state.isFinished)
        #expect(state.summary == "clean and pushed")
    }

    @Test func knowsARemotesMainBranches() {
        #expect(GitState.isMainBranch(remoteRef: "refs/remotes/origin/main"))
        #expect(GitState.isMainBranch(remoteRef: "refs/remotes/origin/HEAD"))
        #expect(GitState.isMainBranch(remoteRef: "refs/remotes/upstream/development"))
        #expect(!GitState.isMainBranch(remoteRef: "refs/remotes/origin/cf/development"))
        #expect(!GitState.isMainBranch(remoteRef: "refs/remotes/origin/feature/main"))
        #expect(!GitState.isMainBranch(remoteRef: "refs/remotes/origin/agent"))
        #expect(!GitState.isMainBranch(remoteRef: "refs/remotes/origin/feature/12/main"))
        #expect(!GitState.isMainBranch(remoteRef: "refs/heads/main"))
    }

    @Test func countsChangesAndCommitsNoRemoteHas() throws {
        let fixture = try GitFixture()
        try fixture.commit(in: fixture.worktree)
        try Data("draft".utf8).write(to: URL(filePath: fixture.worktree + "/draft.txt"))
        let state = try #require(GitState.read(at: fixture.worktree))
        // Whether it's merged isn't asked of a checkout with changes.
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
    /// The fixture's worktree, as the catalog lists it some days after it was made.
    func items(
        daysLater: Double, pullRequest: PullRequestState? = nil, prepare: (GitFixture) throws -> Void = { _ in }
    ) async throws -> [CleanupItem] {
        let fixture = try GitFixture()
        try prepare(fixture)
        try Data(count: 2_000_000).write(to: URL(filePath: fixture.worktree + "/big.bin"))
        try fixture.git(["add", "big.bin"], in: fixture.worktree)
        try fixture.git(["commit", "-q", "-m", "Big"], in: fixture.worktree)
        try fixture.git(["push", "-q", "origin", "agent:main"], in: fixture.worktree)
        try fixture.git(["fetch", "-q", "origin"], in: fixture.worktree)
        let scan = await DiskScanner(options: .init(root: fixture.base)).scan()
        return CleanupCatalog(
            home: fixture.base.path, now: Date().addingTimeInterval(daysLater * 86_400),
            pullRequest: { _ in pullRequest }
        ).items(from: scan)
    }

    @Test func aFinishedWorktreeLeftForDaysIsSafeToClear() async throws {
        let items = try await items(daysLater: 3)
        let finished = try #require(items.first { $0.id == "finished-worktrees" })
        #expect(finished.group == .safeToClear)
        #expect(finished.entries.first?.detail == "repo · clean, pushed and merged · last changed 3 days ago")
        #expect(finished.entries.first?.companions.count == 1)
        #expect(!items.contains { $0.id == "git-worktrees" })
    }

    @Test func aFinishedWorktreeUsedThisWeekStillNeedsALook() async throws {
        let items = try await items(daysLater: 1)
        #expect(!items.contains { $0.id == "finished-worktrees" })
        #expect(items.first { $0.id == "git-worktrees" }?.group == .worthALook)
    }

    @Test func aFileGitIgnoresKeepsAWorktreeOutOfSafeToClear() async throws {
        let items = try await items(daysLater: 3) { fixture in
            try Data("*.local\nnode_modules\n".utf8).write(to: URL(filePath: fixture.worktree + "/.gitignore"))
            try fixture.git(["add", ".gitignore"], in: fixture.worktree)
            try Data("SECRET=1".utf8).write(to: URL(filePath: fixture.worktree + "/.env.local"))
            try FileManager.default.createDirectory(
                atPath: fixture.worktree + "/node_modules/pkg", withIntermediateDirectories: true
            )
        }
        #expect(!items.contains { $0.id == "finished-worktrees" })
        let detail = items.first { $0.id == "git-worktrees" }?.entries.first?.detail
        #expect(detail == "repo · clean, pushed and merged · keeps 1 file git ignores · last changed 3 days ago")
    }

    @Test func buildFoldersGitIgnoresDoNotHoldAWorktreeBack() async throws {
        let items = try await items(daysLater: 3) { fixture in
            try Data("node_modules\n.next\n".utf8).write(to: URL(filePath: fixture.worktree + "/.gitignore"))
            try fixture.git(["add", ".gitignore"], in: fixture.worktree)
            try FileManager.default.createDirectory(
                atPath: fixture.worktree + "/node_modules/pkg", withIntermediateDirectories: true
            )
            try Data("x".utf8).write(to: URL(filePath: fixture.worktree + "/node_modules/pkg/index.js"))
        }
        #expect(items.contains { $0.id == "finished-worktrees" })
    }

    @Test func aWorktreeWithSubmodulesAlwaysNeedsALook() async throws {
        let items = try await items(daysLater: 3) { fixture in
            // Stands in for a submodule: its history lives in the worktree's records.
            try FileManager.default.createDirectory(
                atPath: fixture.main + "/.git/worktrees/repo-agent/modules/lib", withIntermediateDirectories: true
            )
        }
        #expect(!items.contains { $0.id == "finished-worktrees" })
        let detail = items.first { $0.id == "git-worktrees" }?.entries.first?.detail
        #expect(detail?.contains("has submodules") == true)
    }

    @Test func aCommitMadeYesterdayCountsAsUse() async throws {
        // Three days by the files' dates, but git's log of the worktree says otherwise.
        let fixture = try GitFixture()
        let finding = WorktreeFinding(
            path: fixture.worktree, gitDirectory: fixture.main + "/.git/worktrees/repo-agent",
            modified: Date().addingTimeInterval(-3 * 86_400)
        )
        try fixture.commit(in: fixture.worktree)
        #expect(Date().timeIntervalSince(CleanupCatalog.lastUsed(finding)) < 60)
    }

    /// The fixture's worktree as a finished entry, listed three days after its last commit.
    func finishedEntry(_ fixture: GitFixture) async throws -> CleanupEntry {
        try Data(count: 2_000_000).write(to: URL(filePath: fixture.worktree + "/big.bin"))
        try fixture.git(["add", "big.bin"], in: fixture.worktree)
        try fixture.git(["commit", "-q", "-m", "Big"], in: fixture.worktree)
        try fixture.git(["push", "-q", "origin", "agent:main"], in: fixture.worktree)
        try fixture.git(["fetch", "-q", "origin"], in: fixture.worktree)
        let scan = await DiskScanner(options: .init(root: fixture.base)).scan()
        let items = CleanupCatalog(home: fixture.base.path, now: Date().addingTimeInterval(3 * 86_400))
            .items(from: scan)
        let entry = try #require(items.first { $0.id == "finished-worktrees" }?.entries.first)
        #expect(entry.finishedWorktree)
        return entry
    }

    @Test func aFinishedWorktreeIsTrashedWithItsRecords() async throws {
        let fixture = try GitFixture()
        let entry = try await finishedEntry(fixture)
        let report = Trasher(home: fixture.base.path).trash([entry])
        #expect(report.failed.isEmpty)
        #expect(Set(report.moved) == [fixture.worktree, fixture.main + "/.git/worktrees/repo-agent"])
    }

    @Test func aWorktreeWorkedInSinceTheListWasMadeIsLeftAlone() async throws {
        let fixture = try GitFixture()
        let entry = try await finishedEntry(fixture)
        try Data("new idea".utf8).write(to: URL(filePath: fixture.worktree + "/draft.txt"))
        let report = Trasher(home: fixture.base.path).trash([entry])
        #expect(report.moved.isEmpty)
        #expect(report.failed.map(\.path) == [fixture.worktree])
        #expect(report.failed.first?.reason
            == "Left alone: since the list was made, it changed (1 changed file).")
        #expect(FileManager.default.fileExists(atPath: fixture.worktree + "/draft.txt"))
    }

    @Test func aWorktreeListedForALookIsNotAskedAgain() async throws {
        let fixture = try GitFixture()
        try Data(count: 2_000_000).write(to: URL(filePath: fixture.worktree + "/big.bin"))
        let scan = await DiskScanner(options: .init(root: fixture.base)).scan()
        let entry = try #require(
            CleanupCatalog(home: fixture.base.path).items(from: scan).first { $0.id == "git-worktrees" }?.entries.first
        )
        #expect(!entry.finishedWorktree)
        // The person chose it knowing it has a changed file, so it goes.
        #expect(Trasher(home: fixture.base.path).trash([entry]).failed.isEmpty)
    }

    @Test func anOpenPullRequestKeepsAWorktreeOutOfSafeToClear() async throws {
        let items = try await items(daysLater: 3, pullRequest: .open)
        #expect(!items.contains { $0.id == "finished-worktrees" })
        #expect(items.contains { $0.id == "git-worktrees" })
    }

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
