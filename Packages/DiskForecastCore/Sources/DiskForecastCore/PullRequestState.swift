import Foundation

/// Whether a worktree's branch has a pull request on GitHub, and what became of it. Only looked
/// up when the person turns it on, through their own `gh` command.
public enum PullRequestState: String, Sendable, Codable {
    case open
    case merged
    case closed
    case none
    /// gh couldn't be asked, or couldn't say.
    case unknown

    /// "pull request merged". Nil when unknown, so the line doesn't claim anything.
    public var phrase: String? {
        switch self {
        case .open: "pull request open"
        case .merged: "pull request merged"
        case .closed: "pull request closed"
        case .none: "no pull request"
        case .unknown: nil
        }
    }
}

/// A repository on github.com, read from a git remote URL.
public struct GitHubRepository: Sendable, Hashable {
    public let owner: String
    public let name: String

    /// What `gh --repo` takes.
    public var slug: String { "\(owner)/\(name)" }

    /// Reads `https://github.com/owner/name.git`, `git@github.com:owner/name.git`, and
    /// `ssh://git@github.com/owner/name`. Nil for any other host or a local path.
    public init?(remoteURL: String) {
        let url = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        var path: Substring
        if let range = url.range(of: "git@github.com:"), range.lowerBound == url.startIndex {
            path = url[range.upperBound...]
        } else if let components = URLComponents(string: url),
                  ["https", "http", "ssh", "git"].contains(components.scheme ?? ""),
                  components.host?.lowercased() == "github.com", components.port == nil {
            path = Substring(components.path.drop { $0 == "/" })
        } else {
            return nil
        }
        if path.hasSuffix("/") { path = path.dropLast() }
        if path.hasSuffix(".git") { path = path.dropLast(4) }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard parts.count == 2, parts.allSatisfy({ part in
            !part.isEmpty && !part.hasPrefix("-") && !part.hasPrefix(".")
                && part.unicodeScalars.allSatisfy(allowed.contains)
        }) else { return nil }
        owner = String(parts[0])
        name = String(parts[1])
    }
}

/// The pull requests `gh pr list --state all --json headRefName,state,isCrossRepository` printed
/// for one repository, newest first.
public struct PullRequestList: Sendable, Equatable {
    /// The fields to ask gh for.
    public static let fields = "headRefName,state,isCrossRepository"

    private struct Row: Decodable {
        let headRefName: String
        let state: String
        let isCrossRepository: Bool
    }

    let states: [String: [PullRequestState]]
    /// gh printed as many as it was asked for, so an older one could be missing.
    let isFull: Bool

    public init?(ghJSON data: Data, limit: Int) {
        guard let rows = try? JSONDecoder().decode([Row].self, from: data) else { return nil }
        var states: [String: [PullRequestState]] = [:]
        // A fork's branch can share a name with one here.
        for row in rows where !row.isCrossRepository {
            let state: PullRequestState = switch row.state {
            case "OPEN": .open
            case "MERGED": .merged
            case "CLOSED": .closed
            default: .unknown
            }
            states[row.headRefName, default: []].append(state)
        }
        self.states = states
        isFull = rows.count >= limit
    }

    /// An open pull request outranks a merged one, which outranks a closed one.
    public func state(of branch: String) -> PullRequestState {
        guard let found = states[branch] else { return isFull ? .unknown : .none }
        for state in [PullRequestState.open, .merged, .closed] where found.contains(state) {
            return state
        }
        return .unknown
    }
}

/// Looks up the pull request for each worktree's branch, asking once per repository.
public enum PullRequestLookup {
    /// How many pull requests to ask gh for per repository.
    public static let limit = 1000

    /// Worktree path to state. Worktrees with no branch checked out, or whose remote isn't on
    /// github.com, are left out. `ask` returns gh's output, or nil when it failed.
    public static func states(
        of worktrees: [String],
        branch: @Sendable (String) -> String?,
        remoteURL: @Sendable (String) -> String?,
        limit: Int = limit,
        ask: @escaping @Sendable (GitHubRepository) async -> Data?
    ) async -> [String: PullRequestState] {
        var byRepository: [GitHubRepository: [(path: String, branch: String)]] = [:]
        for path in worktrees {
            guard let branch = branch(path), let repository = remoteURL(path).flatMap(GitHubRepository.init)
            else { continue }
            byRepository[repository, default: []].append((path, branch))
        }
        let lists = await withTaskGroup(of: (GitHubRepository, PullRequestList?).self) { group in
            for repository in byRepository.keys {
                group.addTask {
                    (repository, await ask(repository).flatMap { PullRequestList(ghJSON: $0, limit: limit) })
                }
            }
            var lists: [GitHubRepository: PullRequestList?] = [:]
            for await (repository, list) in group { lists[repository] = list }
            return lists
        }
        var states: [String: PullRequestState] = [:]
        for (repository, members) in byRepository {
            for member in members {
                states[member.path] = lists[repository].flatMap { $0 }?.state(of: member.branch) ?? .unknown
            }
        }
        return states
    }
}

extension WorktreeFinding {
    /// The branch checked out in it, read from its records. Nil for a detached checkout.
    public var branch: String? {
        (try? String(contentsOfFile: gitDirectory + "/HEAD", encoding: .utf8)).flatMap(Self.branch(fromHead:))
    }

    static func branch(fromHead contents: String) -> String? {
        let line = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "ref: refs/heads/"
        guard line.hasPrefix(prefix), line.count > prefix.count else { return nil }
        return String(line.dropFirst(prefix.count))
    }
}
