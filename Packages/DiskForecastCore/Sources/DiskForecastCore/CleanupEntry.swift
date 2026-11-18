import Foundation

public struct CleanupEntry: Sendable, Hashable, Identifiable {
    public var id: String { path }
    public let path: String
    public let bytes: Int64
    public let detail: String?
    /// What the list calls it. Usually the file or folder name.
    public let name: String
    /// Paths that go to the Trash with it, like a worktree's records in its repository. Counted
    /// in `bytes`.
    public let companions: [String]
    /// A worktree branch's pull request, when that's been looked up.
    public let pullRequest: PullRequestState?
    /// For a folder stored twice, the copy it matched. It's compared again, every file, before it goes.
    public let original: String?

    public init(
        path: String, bytes: Int64, detail: String? = nil, name: String? = nil, companions: [String] = [],
        pullRequest: PullRequestState? = nil, original: String? = nil
    ) {
        self.path = path
        self.bytes = bytes
        self.detail = detail
        self.name = name ?? (path as NSString).lastPathComponent
        self.companions = companions
        self.pullRequest = pullRequest
        self.original = original
    }
}
