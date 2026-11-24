@testable import DiskForecastCore
import Foundation
import Testing

struct ProjectActivityTests {
    let fixture: GitFixture
    let now = Date()

    init() throws {
        fixture = try GitFixture()
    }

    private func touch(_ path: String, daysAgo: Double) throws {
        let url = URL(filePath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: path) { try Data("x".utf8).write(to: url) }
        let date = now.addingTimeInterval(-daysAgo * 86_400)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: path)
    }

    private func daysAgo(_ date: Date?) -> Int? {
        date.map { Int((now.timeIntervalSince($0) / 86_400).rounded()) }
    }

    @Test func readsTheLastCommitOrCheckoutFromTheHeadLog() throws {
        try touch(fixture.main + "/.git/logs/HEAD", daysAgo: 12)
        // The index is rewritten by tools while nobody is working, so it says nothing.
        try touch(fixture.main + "/.git/index", daysAgo: 0)
        #expect(daysAgo(ProjectActivity.lastGitActivity(root: fixture.main)) == 12)
    }

    @Test func aWorktreeHasItsOwnHeadLog() throws {
        let directory = try #require(ProjectActivity.gitDirectory(of: fixture.worktree))
        #expect(directory.hasSuffix("/repo/.git/worktrees/repo-agent"))
        try touch(directory + "/logs/HEAD", daysAgo: 20)
        try touch(fixture.main + "/.git/logs/HEAD", daysAgo: 1)
        #expect(daysAgo(ProjectActivity.lastGitActivity(root: fixture.worktree)) == 20)
    }

    @Test func findsTheCheckoutAFolderIsIn() {
        #expect(ProjectActivity.repositoryRoot(of: fixture.main + "/packages/web") == fixture.main)
        #expect(ProjectActivity.repositoryRoot(of: fixture.base.path + "/loose") == nil)
    }

    @Test func namesProjectsTheWayClaudeCodeDoes() {
        #expect(ProjectActivity.conversationKey("/Users/me/code/my.app") == "-Users-me-code-my-app")
    }

    @Test func aRecentConversationCountsAsWork() throws {
        let claude = fixture.base.path + "/claude-projects"
        let key = ProjectActivity.conversationKey(fixture.main)
        try touch(claude + "/" + key + "/old.jsonl", daysAgo: 30)
        try touch(claude + "/" + key + "-packages-web/new.jsonl", daysAgo: 2)
        try touch(claude + "/" + key + "/notes.txt", daysAgo: 0)
        try touch(fixture.main + "/.git/logs/HEAD", daysAgo: 12)
        let conversations = ProjectActivity.conversations(in: claude)
        let projects = [fixture.main, fixture.main + "/packages/web", fixture.base.path + "/loose"]
        let last = ProjectActivity.last(for: projects, conversations: conversations)
        #expect(daysAgo(last[fixture.main]) == 2)
        #expect(daysAgo(last[fixture.main + "/packages/web"]) == 2)
        #expect(last[fixture.base.path + "/loose"] == nil)
        #expect(daysAgo(ProjectActivity.last(for: [fixture.main], conversations: [:])[fixture.main]) == 12)
    }
}
