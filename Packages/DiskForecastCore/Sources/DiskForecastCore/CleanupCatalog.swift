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

    public init(path: String, bytes: Int64, detail: String? = nil) {
        self.path = path
        self.bytes = bytes
        self.detail = detail
    }

    public var name: String { (path as NSString).lastPathComponent }
}

public struct CleanupItem: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let explanation: String
    public let group: CleanupGroup
    public let action: CleanupAction
    public let entries: [CleanupEntry]

    public var bytes: Int64 { entries.reduce(0) { $0 + $1.bytes } }
}

/// Turns a scan of the home folder into the cleanup list: known caches, logs, build folders, AI
/// models, and big downloads, each with a plain explanation. No path is counted twice: the
/// specific rules claim their paths first, and broader ones skip or subtract what's claimed.
public struct CleanupCatalog {
    public let home: String
    public let staleAfterDays: Int
    public let now: Date

    /// Entries smaller than this aren't worth listing.
    static let minimumEntryBytes: Int64 = 1_000_000
    static let minimumDownloadBytes: Int64 = 10_000_000

    public init(home: String, staleAfterDays: Int = 30, now: Date = Date()) {
        self.home = home.hasSuffix("/") ? String(home.dropLast()) : home
        self.staleAfterDays = staleAfterDays
        self.now = now
    }

    private var staleCutoff: Date { now.addingTimeInterval(-Double(staleAfterDays) * 86_400) }

    public func items(from scan: ScanResult) -> [CleanupItem] {
        var claimed: [String] = []
        var items: [CleanupItem] = []
        for rule in rules {
            let entries = rule.candidates(self, scan).compactMap { candidate -> CleanupEntry? in
                guard !claimed.contains(where: { candidate.path == $0 || candidate.path.hasPrefix($0 + "/") }),
                      var bytes = scan.allocatedSize(of: candidate.path)
                else { return nil }
                for inner in claimed where inner.hasPrefix(candidate.path + "/") {
                    bytes -= scan.allocatedSize(of: inner) ?? 0
                }
                return CleanupEntry(path: candidate.path, bytes: max(0, bytes), detail: candidate.detail)
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

    // MARK: Sources

    struct Candidate {
        let path: String
        var detail: String?
    }

    func path(_ relative: String) -> String {
        home + "/" + relative
    }

    func fixed(_ relatives: [String]) -> [Candidate] {
        relatives.map { Candidate(path: path($0)) }
    }

    func children(of relative: String, except excluded: (String) -> Bool = { _ in false }) -> [Candidate] {
        let folder = path(relative)
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

    func diskImages(_ scan: ScanResult) -> [Candidate] {
        scan.diskImages.map { Candidate(path: $0.path, detail: "Modified \(Age.phrase(from: $0.modified, to: now))") }
    }

    func downloads() -> [Candidate] {
        children(of: "Downloads").map { candidate in
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
