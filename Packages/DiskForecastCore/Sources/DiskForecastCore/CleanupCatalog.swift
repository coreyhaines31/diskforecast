import Foundation

public enum CleanupGroup: String, Sendable, CaseIterable {
    /// Rebuilt or redownloaded on demand; checked by default.
    case safeToClear
    /// Might matter to you; nothing is checked until you choose.
    case worthALook

    public var title: String {
        switch self {
        case .safeToClear: "Safe to clear"
        case .worthALook: "Worth a look"
        }
    }
}

public enum CleanupAction: Sendable, Equatable {
    /// Move the checked entries to the Trash.
    case trash
    /// Reclaimed with the owning tool's own command, from the System Data window.
    case useTool(String)
}

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

    public init(path: String, bytes: Int64, detail: String? = nil, name: String? = nil, companions: [String] = []) {
        self.path = path
        self.bytes = bytes
        self.detail = detail
        self.name = name ?? (path as NSString).lastPathComponent
        self.companions = companions
    }
}

public struct CleanupItem: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let explanation: String
    public let group: CleanupGroup
    public let action: CleanupAction
    public let entries: [CleanupEntry]

    public init(
        id: String, title: String, explanation: String,
        group: CleanupGroup, action: CleanupAction, entries: [CleanupEntry]
    ) {
        self.id = id
        self.title = title
        self.explanation = explanation
        self.group = group
        self.action = action
        self.entries = entries
    }

    public var bytes: Int64 { entries.reduce(0) { $0 + $1.bytes } }

    /// What's in it, largest first: "shop/node_modules, blog/node_modules and 309 more". A name
    /// several entries share gets its parent folder.
    public func preview(naming limit: Int = 3) -> String {
        let counts = Dictionary(entries.map { ($0.name, 1) }, uniquingKeysWith: +)
        let labels = entries.sorted { $0.bytes > $1.bytes }.prefix(limit).map { entry in
            counts[entry.name, default: 0] > 1 ? Trasher.Report.label(entry.path) : entry.name
        }
        let named = labels.joined(separator: ", ")
        return entries.count > limit ? "\(named) and \(entries.count - limit) more" : named
    }
}

/// Turns a scan of the home folder into the cleanup list: known caches, logs, build folders, AI
/// models, and big downloads, each with a plain explanation. No path is counted twice: the
/// specific rules claim their paths first, and broader ones skip or subtract what's claimed.
public struct CleanupCatalog: Sendable {
    public let home: String
    public let staleAfterDays: Int
    public let now: Date
    /// A separate scan of Claude Code's temp folders, which sit outside the home folder.
    public let agentScratch: ScanResult?
    /// What removing a checkout would lose. Swappable for tests.
    let gitState: @Sendable (String) -> GitState?

    /// Entries smaller than this aren't worth listing.
    static let minimumEntryBytes: Int64 = 1_000_000
    static let minimumDownloadBytes: Int64 = 10_000_000

    public init(
        home: String, staleAfterDays: Int = 30, now: Date = Date(), agentScratch: ScanResult? = nil,
        gitState: @escaping @Sendable (String) -> GitState? = GitState.read(at:)
    ) {
        self.home = home.hasSuffix("/") ? String(home.dropLast()) : home
        self.staleAfterDays = staleAfterDays
        self.now = now
        self.agentScratch = agentScratch
        self.gitState = gitState
    }

    private var staleCutoff: Date { now.addingTimeInterval(-Double(staleAfterDays) * 86_400) }

    public func items(from scan: ScanResult) -> [CleanupItem] {
        var claimed: [String] = []
        var items: [CleanupItem] = []
        for rule in rules {
            let entries = rule.candidates(self, scan).compactMap { candidate -> CleanupEntry? in
                guard !claimed.contains(where: { candidate.path == $0 || candidate.path.hasPrefix($0 + "/") }),
                      var bytes = size(of: candidate.path, in: scan)
                else { return nil }
                for inner in claimed where inner.hasPrefix(candidate.path + "/") {
                    bytes -= size(of: inner, in: scan) ?? 0
                }
                let companions = candidate.companions.filter { size(of: $0, in: scan) != nil }
                bytes += companions.reduce(0) { $0 + (size(of: $1, in: scan) ?? 0) }
                return CleanupEntry(
                    path: candidate.path, bytes: max(0, bytes), detail: candidate.detail, name: candidate.name,
                    companions: companions
                )
            }
            .filter { $0.bytes >= rule.minimumBytes }
            .sorted { $0.bytes > $1.bytes }
            claimed.append(contentsOf: entries.map(\.path))
            guard !entries.isEmpty else { continue }
            items.append(CleanupItem(
                id: rule.id, title: rule.title, explanation: rule.explanation,
                group: rule.group, action: rule.action, entries: entries
            ))
        }
        return items.sorted { $0.bytes > $1.bytes }
    }

    private func size(of path: String, in scan: ScanResult) -> Int64? {
        scan.allocatedSize(of: path) ?? agentScratch?.allocatedSize(of: path)
    }

    // MARK: Sources

    struct Candidate {
        let path: String
        var detail: String?
        var name: String?
        var companions: [String] = []
    }

    func path(_ relative: String) -> String {
        home + "/" + relative
    }

    func fixed(_ relatives: [String]) -> [Candidate] {
        relatives.map { Candidate(path: path($0)) }
    }

    /// What's directly inside a folder the scan reached. Folders it didn't reach aren't listed, so
    /// building the list never touches a folder macOS would ask permission for.
    func children(
        of relative: String, in scan: ScanResult, except excluded: (String) -> Bool = { _ in false }
    ) -> [Candidate] {
        let folder = path(relative)
        guard scan.tree.node(at: folder) != nil else { return [] }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
        return names.filter { !excluded($0) && $0 != ".DS_Store" }.map { Candidate(path: folder + "/" + $0) }
    }

    func artifacts(_ scan: ScanResult, stale: Bool) -> [Candidate] {
        scan.artifacts
            .filter { ($0.projectModified < staleCutoff) == stale }
            .map { artifact in
                let project = (artifact.projectPath as NSString).lastPathComponent
                let age = Age.phrase(from: artifact.projectModified, to: now)
                return Candidate(path: artifact.path, detail: "\(project) · last changed \(age)")
            }
    }

    /// Cache folders that apps built on web tech (VS Code, Cursor, Slack, Figma) keep next to their
    /// data in Application Support. Only folders beside Local Storage or Session Storage count, so a
    /// folder that merely happens to be named Cache isn't listed.
    func appSupportCaches(_ scan: ScanResult) -> [Candidate] {
        let names: Set<String> = [
            "Cache", "Code Cache", "GPUCache", "DawnCache", "DawnGraphiteCache", "DawnWebGPUCache",
            "GrShaderCache", "ShaderCache", "CachedData", "CachedExtensionVSIXs"
        ]
        let tree = scan.tree
        guard let support = tree.node(at: path("Library/Application Support")) else { return [] }
        var found: [Candidate] = []
        func visit(_ node: Int, app: String, within: [String]) {
            let children = tree.children[node].map(Int.init)
            let isProfile = children.contains { ["Local Storage", "Session Storage"].contains(tree.names[$0]) }
            for child in children {
                let inside = within + [tree.names[child]]
                if isProfile && names.contains(tree.names[child]) {
                    // The path inside the app's folder tells two Cache folders of one app apart.
                    let detail = inside.joined(separator: "/")
                    found.append(Candidate(path: tree.path(of: child), detail: detail, name: app))
                } else if inside.count < 4 {
                    visit(child, app: app, within: inside)
                }
            }
        }
        for app in tree.children[support].map(Int.init) where !tree.names[app].hasPrefix("com.apple.") {
            visit(app, app: tree.names[app], within: [])
        }
        return found
    }

    /// What VS Code and editors built from it saved about each project, for projects that are no
    /// longer on this Mac. Projects on a drive that isn't connected are left out.
    func orphanedWorkspaces(_ scan: ScanResult) -> [Candidate] {
        let tree = scan.tree
        guard let support = tree.node(at: path("Library/Application Support")) else { return [] }
        return tree.children[support].map(Int.init).flatMap { app -> [Candidate] in
            let appName = tree.names[app]
            return children(of: "Library/Application Support/\(appName)/User/workspaceStorage", in: scan)
                .compactMap { candidate in
                    let file = URL(filePath: candidate.path).appending(path: "workspace.json")
                    guard let data = try? Data(contentsOf: file),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let link = (json["folder"] ?? json["workspace"]) as? String,
                          let url = URL(string: link), url.isFileURL,
                          !url.path.hasPrefix("/Volumes/"), Self.isMissing(url.path)
                    else { return nil }
                    return Candidate(
                        path: candidate.path, detail: "\(appName) · project deleted", name: url.lastPathComponent
                    )
                }
        }
    }

    /// Git worktree checkouts, each with what removing it would lose.
    func worktrees(_ scan: ScanResult) -> [Candidate] {
        scan.worktrees.map { worktree in
            var parts = [worktree.repository]
            if let state = gitState(worktree.path) { parts.append(state.summary) }
            parts.append("last changed \(Age.phrase(from: worktree.modified, to: now))")
            // Its records go too, as with git worktree remove; they can hold whole submodule copies.
            // Only when they point back at this checkout, as git's own do, so a stray .git file
            // can't send something else to the Trash.
            let pointsBack = Self.checkoutGitFile(recordedIn: worktree.gitDirectory) == worktree.path + "/.git"
            return Candidate(
                path: worktree.path, detail: parts.joined(separator: " · "),
                companions: pointsBack ? [worktree.gitDirectory] : []
            )
        }
    }

    /// Git's records for worktrees whose folder is gone, which is what `git worktree prune`
    /// removes. Locked worktrees and ones on a drive that isn't connected are left out.
    func leftoverWorktreeData(_ scan: ScanResult) -> [Candidate] {
        let tree = scan.tree
        let recordFolders = tree.names.indices.filter { node in
            guard node > 0, tree.names[node] == "worktrees" else { return false }
            let parent = tree.names[Int(tree.parents[node])]
            return parent == ".git" || parent.hasSuffix(".git")
        }
        // A checkout moved by hand still points at its records; they aren't left over.
        let inUse = Set(scan.worktrees.map(\.gitDirectory))
        return recordFolders.flatMap { records in
            tree.children[records].map(Int.init).compactMap { node -> Candidate? in
                let folder = tree.path(of: node)
                guard !inUse.contains(folder), !FileManager.default.fileExists(atPath: folder + "/locked"),
                      let checkoutGit = Self.checkoutGitFile(recordedIn: folder),
                      !checkoutGit.hasPrefix("/Volumes/"), Self.isMissing(checkoutGit)
                else { return nil }
                let checkout = (checkoutGit as NSString).deletingLastPathComponent
                return Candidate(
                    path: folder,
                    detail: "\(WorktreeFinding.repository(of: folder)) · worktree folder deleted",
                    name: (checkout as NSString).lastPathComponent
                )
            }
        }
    }

    /// The checkout's `.git` file that a worktree's records say they belong to.
    static func checkoutGitFile(recordedIn records: String) -> String? {
        guard let pointer = try? String(contentsOfFile: records + "/gitdir", encoding: .utf8) else { return nil }
        let target = pointer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return nil }
        return ((target.hasPrefix("/") ? target : records + "/" + target) as NSString).standardizingPath
    }

    /// True only when nothing is there. A folder macOS won't let the app look into isn't missing.
    static func isMissing(_ path: String) -> Bool {
        var info = stat()
        return lstat(path, &info) != 0 && errno == ENOENT
    }

    func agentLeftovers(_ scan: ScanResult) -> [Candidate] {
        var found = [Candidate(path: path(".npm/_npx"), name: "npx packages")] + claudeSessions()
        found += olderVersions(in: ".local/share/claude/versions", scan: scan) { "Claude Code \($0)" }
        found += olderVersions(in: ".agent-browser/browsers", scan: scan) { "agent-browser \($0)" }
        // Playwright keeps one folder per browser build, like chromium-1140 and webkit-2083.
        found += olderVersions(
            in: "Library/Caches/ms-playwright", scan: scan,
            kind: { String($0.prefix { !$0.isNumber }) }, name: { "Playwright \($0)" }
        )
        for browser in children(of: ".cache/puppeteer", in: scan) {
            let kind = (browser.path as NSString).lastPathComponent
            found += olderVersions(in: ".cache/puppeteer/" + kind, scan: scan) { "Puppeteer \(kind) \($0)" }
        }
        return found
    }

    /// Everything in a folder of downloaded versions except the newest of each kind, which is
    /// probably the one in use.
    func olderVersions(
        in relative: String, scan: ScanResult, kind: (String) -> String = { _ in "" }, name: (String) -> String
    ) -> [Candidate] {
        let versions = children(of: relative, in: scan) { $0.hasPrefix(".") }.map { candidate in
            let version = (candidate.path as NSString).lastPathComponent
            var info = stat()
            let modified = lstat(candidate.path, &info) == 0 ? info.st_mtimespec.tv_sec : 0
            return (candidate: candidate, version: version, modified: modified)
        }
        return Dictionary(grouping: versions) { kind($0.version) }.values.flatMap { group in
            group.sorted { $0.modified > $1.modified }.dropFirst().map {
                Candidate(path: $0.candidate.path, name: name($0.version))
            }
        }
    }

    func diskImages(_ scan: ScanResult) -> [Candidate] {
        scan.diskImages.map { Candidate(path: $0.path, detail: "Modified \(Age.phrase(from: $0.modified, to: now))") }
    }

    func downloads(_ scan: ScanResult) -> [Candidate] {
        children(of: "Downloads", in: scan).map { candidate in
            let url = URL(filePath: candidate.path)
            let values = try? url.resourceValues(forKeys: [.addedToDirectoryDateKey, .contentModificationDateKey])
            let date = values?.addedToDirectoryDate ?? values?.contentModificationDate
            return Candidate(path: candidate.path, detail: date.map { "Added \(Age.phrase(from: $0, to: now))" })
        }
    }
}

extension ScanResult {
    /// Bytes under a scanned folder, or the allocated size of a single file.
    public func allocatedSize(of path: String) -> Int64? {
        if let size = tree.size(of: path) { return size }
        // Only look at files in folders the scan reached, so this never sets off a permission prompt.
        guard tree.node(at: (path as NSString).deletingLastPathComponent) != nil else { return nil }
        var info = stat()
        guard lstat(path, &info) == 0, info.st_mode & S_IFMT != S_IFDIR else { return nil }
        return Int64(info.st_blocks) * 512
    }
}

/// "3 days ago", "4 months ago": coarse ages for explaining why something is listed.
public enum Age {
    public static func phrase(from date: Date, to now: Date) -> String {
        let days = Int(now.timeIntervalSince(date) / 86_400)
        switch days {
        case ..<1: return "today"
        case 1: return "yesterday"
        case ..<14: return "\(days) days ago"
        case ..<60: return "\(days / 7) weeks ago"
        case ..<730: return "\(days / 30) months ago"
        default: return "\(days / 365) years ago"
        }
    }
}
