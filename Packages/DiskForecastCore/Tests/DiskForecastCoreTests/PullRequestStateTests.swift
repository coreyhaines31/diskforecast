@testable import DiskForecastCore
import Foundation
import Testing

struct PullRequestStateTests {
    @Test func readsGitHubRepositoriesFromRemoteURLs() {
        for url in [
            "https://github.com/acme/shop.git", "https://github.com/acme/shop", "https://github.com/acme/shop/",
            "git@github.com:acme/shop.git", "ssh://git@github.com/acme/shop.git", "https://me@github.com/acme/shop"
        ] {
            #expect(GitHubRepository(remoteURL: url)?.slug == "acme/shop", "\(url)")
        }
        for url in [
            "/Users/me/origin.git", "https://gitlab.com/acme/shop.git", "git@gitlab.com:acme/shop.git",
            "https://github.com/acme", "https://github.com/acme/shop/extra", "https://github.com/-rf/shop"
        ] {
            #expect(GitHubRepository(remoteURL: url) == nil, "\(url)")
        }
    }

    @Test func readsTheBranchAWorktreeHasCheckedOut() {
        #expect(WorktreeFinding.branch(fromHead: "ref: refs/heads/feature/42-login\n") == "feature/42-login")
        #expect(WorktreeFinding.branch(fromHead: "4b825dc642cb6eb9a060e54bf8d69288fbee4904\n") == nil)
        #expect(WorktreeFinding.branch(fromHead: "ref: refs/remotes/origin/main") == nil)
    }

    @Test func mapsEachBranchToItsPullRequest() throws {
        let json = """
        [{"headRefName":"done","isCrossRepository":false,"state":"MERGED"},
         {"headRefName":"done","isCrossRepository":false,"state":"CLOSED"},
         {"headRefName":"dropped","isCrossRepository":false,"state":"CLOSED"},
         {"headRefName":"retry","isCrossRepository":false,"state":"CLOSED"},
         {"headRefName":"retry","isCrossRepository":false,"state":"OPEN"},
         {"headRefName":"fork","isCrossRepository":true,"state":"OPEN"}]
        """
        let list = try #require(PullRequestList(ghJSON: Data(json.utf8), limit: 100))
        #expect(list.state(of: "done") == .merged)
        #expect(list.state(of: "dropped") == .closed)
        #expect(list.state(of: "retry") == .open)
        // Someone else's fork can use the same branch name.
        #expect(list.state(of: "fork") == PullRequestState.none)
        #expect(list.state(of: "never") == PullRequestState.none)
    }

    @Test func aFullListCantSayABranchHasNone() throws {
        let json = #"[{"headRefName":"recent","isCrossRepository":false,"state":"OPEN"}]"#
        let list = try #require(PullRequestList(ghJSON: Data(json.utf8), limit: 1))
        #expect(list.state(of: "recent") == .open)
        #expect(list.state(of: "older") == .unknown)
    }

    @Test func rejectsWhatIsntGhOutput() {
        #expect(PullRequestList(ghJSON: Data("not json".utf8), limit: 100) == nil)
        #expect(PullRequestList(ghJSON: Data(#"{"message":"Bad credentials"}"#.utf8), limit: 100) == nil)
    }

    @Test func describesEachState() {
        #expect(PullRequestState.merged.phrase == "pull request merged")
        #expect(PullRequestState.closed.phrase == "pull request closed")
        #expect(PullRequestState.open.phrase == "pull request open")
        #expect(PullRequestState.none.phrase == "no pull request")
        #expect(PullRequestState.unknown.phrase == nil)
    }

    @Test func asksOncePerRepositoryAndFailsToUnknown() async {
        let worktrees = ["/w/a", "/w/b", "/w/c", "/w/d", "/w/e"]
        let remotes = [
            "/w/a": "git@github.com:acme/shop.git", "/w/b": "https://github.com/acme/shop",
            "/w/c": "https://github.com/acme/blog", "/w/e": "/Users/me/origin.git"
        ]
        let branches = ["/w/a": "done", "/w/b": "new", "/w/c": "draft", "/w/d": "local", "/w/e": "x"]
        let asked = Asked()
        let states = await PullRequestLookup.states(
            of: worktrees, branch: { branches[$0] }, remoteURL: { remotes[$0] }, limit: 100,
            ask: { repository in
                await asked.add(repository.slug)
                guard repository.slug == "acme/shop" else { return nil }
                return Data(#"[{"headRefName":"done","isCrossRepository":false,"state":"MERGED"}]"#.utf8)
            }
        )
        #expect(await asked.slugs.sorted() == ["acme/blog", "acme/shop"])
        #expect(states == ["/w/a": .merged, "/w/b": PullRequestState.none, "/w/c": .unknown])
    }
}

private actor Asked {
    var slugs: [String] = []
    func add(_ slug: String) { slugs.append(slug) }
}

struct WorktreePullRequestTests {
    @Test func readsTheBranchAndRemoteOfARealWorktree() throws {
        let fixture = try GitFixture()
        let scanFinding = WorktreeFinding(
            path: fixture.worktree, gitDirectory: fixture.main + "/.git/worktrees/repo-agent", modified: Date()
        )
        #expect(scanFinding.branch == "agent")
        #expect(GitState.remoteURL(at: fixture.worktree) == fixture.base.path + "/origin.git")
    }

    @Test func showsThePullRequestBesideTheGitState() async throws {
        let fixture = try GitFixture()
        try Data(count: 2_000_000).write(to: URL(filePath: fixture.worktree + "/big.bin"))
        let scan = await DiskScanner(options: .init(root: fixture.base)).scan()
        let worktree = fixture.worktree
        let catalog = CleanupCatalog(home: fixture.base.path, pullRequest: { path in path == worktree ? .merged : nil })
        let entry = try #require(catalog.items(from: scan).first { $0.id == "git-worktrees" }?.entries.first)
        #expect(entry.detail == "repo · 1 changed file · pull request merged · last changed today")
        #expect(entry.pullRequest == .merged)
        #expect(CLICleanupItem(try #require(catalog.items(from: scan).first { $0.id == "git-worktrees" }))
            .entries.first?.pullRequest == "merged")
    }

    @Test func leavesTheLineAloneWhenNothingIsKnown() async throws {
        let fixture = try GitFixture()
        try Data(count: 2_000_000).write(to: URL(filePath: fixture.worktree + "/big.bin"))
        let scan = await DiskScanner(options: .init(root: fixture.base)).scan()
        for state in [PullRequestState.unknown, nil] {
            let catalog = CleanupCatalog(home: fixture.base.path, pullRequest: { _ in state })
            let entry = try #require(catalog.items(from: scan).first { $0.id == "git-worktrees" }?.entries.first)
            #expect(entry.detail == "repo · 1 changed file · last changed today")
        }
    }
}
