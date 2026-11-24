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
    /// Reclaimed inside the app itself, which the list offers to open.
    case useApp(name: String, bundleID: String)
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
    /// Separate scans of Claude Code's temp folders and the user's own, which sit outside home.
    public let agentScratch: ScanResult?
    public let userTemp: ScanResult?
    /// What removing a checkout would lose. Swappable for tests.
    let gitState: @Sendable (String) -> GitState?
    /// A worktree's pull request, by path. Nil when it wasn't looked up.
    let pullRequest: @Sendable (String) -> PullRequestState?
    /// Why a build folder isn't simply rebuildable, given the checkouts the scan found in it.
    /// Swappable for tests.
    let buildFolderHold: @Sendable (ArtifactFinding, [String]) -> BuildFolderHold?
    /// When each project was last worked in, by path; a project that's missing isn't known.
    /// Swappable for tests.
    let projectActivity: @Sendable ([String]) -> [String: Date]
    /// When the projects of the scan being listed were last worked in. Worked out once per list.
    var lastWorkedIn: [String: Date] = [:]
    /// The build folders of the scan being listed that are held, by path. Worked out once per
    /// list, since several rules ask.
    var heldBuildFolders: [String: BuildFolderHold] = [:]
    /// What removing each worktree of the scan being listed would lose, by path. Worked out once
    /// per list, since two rules ask.
    var worktreeStates: [String: GitState?] = [:]

    /// Entries smaller than this aren't worth listing.
    static let minimumEntryBytes: Int64 = 1_000_000
    static let minimumDownloadBytes: Int64 = 10_000_000
    /// WhatsApp's media is only worth a mention when it's far past normal, as with its sync bug.
    static let minimumWhatsAppBytes: Int64 = 5_000_000_000
    /// Chat apps' saved media is only worth a mention once it's big enough to matter.
    static let minimumChatMediaBytes: Int64 = 2_000_000_000
    /// A package manager's cache is only worth its own row and button from this size up.
    public static let minimumToolCacheBytes: Int64 = 50_000_000
    /// Folders stored twice are only compared, and listed, from this size up.
    static let minimumDuplicateBytes: Int64 = 1_000_000_000

    public init(
        home: String, staleAfterDays: Int = 30, now: Date = Date(),
        agentScratch: ScanResult? = nil, userTemp: ScanResult? = nil,
        gitState: @escaping @Sendable (String) -> GitState? = GitState.read(at:),
        pullRequest: @escaping @Sendable (String) -> PullRequestState? = { _ in nil },
        buildFolderHold: @escaping @Sendable (ArtifactFinding, [String]) -> BuildFolderHold? = {
            BuildFolderHold.check(folder: $0.path, kind: $0.kind, checkouts: $1)
        },
        projectActivity: @escaping @Sendable ([String]) -> [String: Date] = { projects in
            let conversations = ProjectActivity.conversations(in: NSHomeDirectory() + "/.claude/projects")
            return ProjectActivity.last(for: projects, conversations: conversations)
        }
    ) {
        self.home = home.hasSuffix("/") ? String(home.dropLast()) : home
        self.staleAfterDays = staleAfterDays
        self.now = now
        self.agentScratch = agentScratch
        self.userTemp = userTemp
        self.gitState = gitState
        self.pullRequest = pullRequest
        self.buildFolderHold = buildFolderHold
        self.projectActivity = projectActivity
    }

    var staleCutoff: Date { now.addingTimeInterval(-Double(staleAfterDays) * 86_400) }

    public func items(from scan: ScanResult) -> [CleanupItem] {
        var catalog = self
        catalog.heldBuildFolders = holds(in: scan)
        catalog.lastWorkedIn = projectActivity(scan.artifacts.map(\.projectPath))
        for worktree in scan.worktrees {
            catalog.worktreeStates.updateValue(gitState(worktree.path), forKey: worktree.path)
        }
        return catalog.listing(scan)
    }

    private func listing(_ scan: ScanResult) -> [CleanupItem] {
        // What's already in the Trash is Empty Trash's to offer, not something to move there again.
        var claimed: [String] = [path(".Trash")]
        var items: [CleanupItem] = []
        for rule in rules {
            let entries = rule.candidates(self, scan).compactMap { candidate -> CleanupEntry? in
                guard !claimed.contains(where: { candidate.path == $0 || candidate.path.hasPrefix($0 + "/") }),
                      var bytes = candidate.bytes ?? size(of: candidate.path, in: scan)
                else { return nil }
                for inner in claimed where inner.hasPrefix(candidate.path + "/") {
                    bytes -= size(of: inner, in: scan) ?? 0
                }
                let companions = candidate.companions.filter { size(of: $0, in: scan) != nil }
                bytes += companions.reduce(0) { $0 + (size(of: $1, in: scan) ?? 0) }
                return CleanupEntry(
                    path: candidate.path, bytes: max(0, bytes), detail: candidate.detail, name: candidate.name,
                    companions: companions, pullRequest: candidate.pullRequest, original: candidate.original,
                    rebuildable: candidate.rebuildable, finishedWorktree: candidate.finishedWorktree
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
        scan.allocatedSize(of: path) ?? agentScratch?.allocatedSize(of: path) ?? userTemp?.allocatedSize(of: path)
    }

    // MARK: Sources

    struct Candidate {
        let path: String
        var detail: String?
        var name: String?
        var companions: [String] = []
        var pullRequest: PullRequestState?
        var original: String?
        var rebuildable: ArtifactKind?
        var finishedWorktree = false
        /// What removing it frees, when that isn't its size in the scan.
        var bytes: Int64?
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

    /// Cache folders that apps built on web tech (VS Code, Cursor, Slack, Figma) keep next to their
    /// data in Application Support, including inside the container an App Store app keeps it in.
    /// Only folders beside Local Storage or Session Storage count, so a folder that merely happens
    /// to be named Cache isn't listed.
    func appSupportCaches(_ scan: ScanResult) -> [Candidate] {
        let names: Set<String> = [
            "Cache", "Code Cache", "GPUCache", "DawnCache", "DawnGraphiteCache", "DawnWebGPUCache",
            "GrShaderCache", "ShaderCache", "CachedData", "CachedExtensionVSIXs"
        ]
        let tree = scan.tree
        // Containers are only scanned with Full Disk Access; without it there are none to visit.
        let containers = tree.node(at: path("Library/Containers")).map { tree.children[Int($0)].map(Int.init) } ?? []
        let supports = [path("Library/Application Support")] + containers
            .filter { !tree.names[$0].hasPrefix("com.apple.") }
            .map { tree.path(of: $0) + "/Data/Library/Application Support" }
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
        for support in supports.compactMap({ tree.node(at: $0) }) {
            for app in tree.children[Int(support)].map(Int.init) where !tree.names[app].hasPrefix("com.apple.") {
                visit(app, app: tree.names[app], within: [])
            }
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
