import Foundation

/// What the `diskforecast` command asks the running app for. Sent as JSON over a socket that
/// only the signed-in user can open, one request per connection.
public struct CLIRequest: Codable, Equatable, Sendable {
    public enum Action: String, Codable, Sendable {
        case status, changes, cleanup, scan, trash, undo, open
    }

    public enum Window: String, Codable, Sendable, CaseIterable {
        case forecast, cleanup, systemData = "system-data", settings
    }

    public var action: Action
    /// `changes`: how many days back to compare with.
    public var days: Int?
    /// `trash`: cleanup item IDs or paths from the cleanup list.
    public var targets: [String]?
    /// `trash`: actually move them. Without it, trash only says what it would move.
    public var confirmed: Bool?
    /// `open`: which window to show.
    public var window: Window?

    public init(
        action: Action, days: Int? = nil, targets: [String]? = nil, confirmed: Bool? = nil, window: Window? = nil
    ) {
        self.action = action
        self.days = days
        self.targets = targets
        self.confirmed = confirmed
        self.window = window
    }
}

/// The app's answer. Only the part the request asked for is filled in.
public struct CLIResponse: Codable, Equatable, Sendable {
    public var error: String?
    /// Things worth knowing, like a scan still running.
    public var notes: [String]
    public var status: CLIStatus?
    public var changes: CLIChanges?
    public var cleanup: [CLICleanupItem]?
    public var trash: CLITrashReport?
    public var undo: CLIUndoReport?
    /// `status --need`: filled in by the command itself, from `status`.
    public var headroom: CLIHeadroom?

    public init(
        error: String? = nil, notes: [String] = [], status: CLIStatus? = nil, changes: CLIChanges? = nil,
        cleanup: [CLICleanupItem]? = nil, trash: CLITrashReport? = nil, undo: CLIUndoReport? = nil,
        headroom: CLIHeadroom? = nil
    ) {
        self.error = error
        self.notes = notes
        self.status = status
        self.changes = changes
        self.cleanup = cleanup
        self.trash = trash
        self.undo = undo
        self.headroom = headroom
    }
}

/// Whether there's room to write `neededBytes` and still keep `marginBytes` free, for an agent
/// to check before a large download, install, or build.
public struct CLIHeadroom: Codable, Equatable, Sendable {
    /// Where Disk Forecast starts warning about low space on most disks.
    public static let margin: Int64 = 20_000_000_000

    public var neededBytes: Int64
    public var freeBytes: Int64
    public var marginBytes: Int64
    public var hasRoom: Bool
    /// How much to clear first so there's room. Zero when there's room already.
    public var shortBytes: Int64
    public var safeToClearBytes: Int64

    public init(neededBytes: Int64, status: CLIStatus) {
        self.neededBytes = neededBytes
        freeBytes = status.freeBytes
        marginBytes = Self.margin
        shortBytes = max(0, neededBytes + Self.margin - status.freeBytes)
        hasRoom = shortBytes == 0
        safeToClearBytes = status.safeToClearBytes
    }
}

public struct CLIStatus: Codable, Equatable, Sendable {
    public var freeBytes: Int64
    public var capacityBytes: Int64
    /// Space macOS holds for caches and snapshots and gives back when it's needed.
    public var purgeableBytes: Int64
    /// learning, filling, steady, gaining, or cleared (up mostly from one cleanup, so no pace).
    public var outlook: String
    /// Like "Full in ~41 days · using 3.5 GB a day".
    public var forecast: String
    public var daysUntilFull: Double?
    /// The typical daily change in free space lately. Negative when the disk is filling.
    public var bytesPerDay: Double?
    public var lowOnSpace: Bool
    public var scanning: Bool
    public var lastScan: Date?
    public var fullDiskAccess: Bool
    /// What the cleanup list's "Safe to clear" group adds up to.
    public var safeToClearBytes: Int64

    public init(
        freeBytes: Int64, capacityBytes: Int64, purgeableBytes: Int64, outlook: String, forecast: String,
        daysUntilFull: Double?, bytesPerDay: Double?, lowOnSpace: Bool, scanning: Bool, lastScan: Date?,
        fullDiskAccess: Bool, safeToClearBytes: Int64
    ) {
        self.freeBytes = freeBytes
        self.capacityBytes = capacityBytes
        self.purgeableBytes = purgeableBytes
        self.outlook = outlook
        self.forecast = forecast
        self.daysUntilFull = daysUntilFull
        self.bytesPerDay = bytesPerDay
        self.lowOnSpace = lowOnSpace
        self.scanning = scanning
        self.lastScan = lastScan
        self.fullDiskAccess = fullDiskAccess
        self.safeToClearBytes = safeToClearBytes
    }
}

/// Which folders grew or shrank between two scans.
public struct CLIChanges: Codable, Equatable, Sendable {
    public var since: Date
    public var until: Date
    public var folders: [CLIFolderChange]
    /// Change in used space outside the home folder: System Data, other accounts, and apps.
    public var outsideHomeBytes: Int64
    /// Why free space moved much more than the home folder did, when it did. Nil otherwise, and from
    /// apps older than this field.
    public var freeSpaceGap: String?

    public init(
        since: Date, until: Date, folders: [CLIFolderChange], outsideHomeBytes: Int64, freeSpaceGap: String? = nil
    ) {
        self.since = since
        self.until = until
        self.folders = folders
        self.outsideHomeBytes = outsideHomeBytes
        self.freeSpaceGap = freeSpaceGap
    }

    /// Every folder that changed by 500 MB or more, each with the folders inside it that did, and
    /// the ones where that much was measured for the first time.
    public init(from old: FolderSnapshot, to new: FolderSnapshot) {
        func changes(under parent: String) -> [CLIFolderChange] {
            FolderChanges.changes(from: old, to: new, under: parent).map { change in
                CLIFolderChange(
                    path: change.path, oldBytes: change.oldBytes, newBytes: change.newBytes,
                    firstMeasured: change.isFirstMeasured, firstMeasuredBytes: change.firstMeasuredBytes,
                    listedForFirstMeasured: change.listedForFirstMeasured,
                    children: change.hasChildren ? changes(under: change.path) : []
                )
            }
        }
        self.init(
            since: old.day, until: new.day, folders: changes(under: ""),
            outsideHomeBytes: FolderChanges.outsideHomeDelta(from: old, to: new),
            freeSpaceGap: FreeSpaceGap(from: old, to: new)?.explanation
        )
    }
}

public struct CLIFolderChange: Codable, Equatable, Sendable {
    /// Relative to the home folder.
    public var path: String
    public var oldBytes: Int64
    public var newBytes: Int64
    /// The earlier scan couldn't measure this folder, so its size isn't growth.
    public var firstMeasured: Bool
    /// Bytes in folders inside this one that the earlier scan couldn't measure, left out of `delta`.
    public var firstMeasuredBytes: Int64
    /// Listed for what was measured for the first time, not for growing or shrinking.
    public var listedForFirstMeasured: Bool
    public var children: [CLIFolderChange]

    public var delta: Int64 { firstMeasured ? 0 : newBytes - oldBytes - firstMeasuredBytes }

    public init(
        path: String, oldBytes: Int64, newBytes: Int64, firstMeasured: Bool = false, firstMeasuredBytes: Int64 = 0,
        listedForFirstMeasured: Bool = false, children: [CLIFolderChange] = []
    ) {
        self.path = path
        self.oldBytes = oldBytes
        self.newBytes = newBytes
        self.firstMeasured = firstMeasured
        self.firstMeasuredBytes = firstMeasuredBytes
        self.listedForFirstMeasured = listedForFirstMeasured
        self.children = children
    }
}

public struct CLICleanupItem: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var explanation: String
    /// safeToClear or worthALook.
    public var group: String
    /// Nil when `diskforecast trash` can move it; otherwise the tool that reclaims it.
    public var tool: String?
    public var bytes: Int64
    public var entries: [CLICleanupEntry]

    public init(_ item: CleanupItem) {
        id = item.id
        title = item.title
        explanation = item.explanation
        group = item.group.rawValue
        switch item.action {
        case .trash: tool = nil
        case .useTool(let name), .useApp(let name, _): tool = name
        }
        bytes = item.bytes
        entries = item.entries.map {
            CLICleanupEntry(path: $0.path, bytes: $0.bytes, detail: $0.detail, pullRequest: $0.pullRequest?.rawValue)
        }
    }
}

public struct CLICleanupEntry: Codable, Equatable, Sendable {
    public var path: String
    public var bytes: Int64
    public var detail: String?
    /// A worktree branch's pull request: open, merged, closed, none, or unknown. Only present
    /// when pull request checks are on in Settings.
    public var pullRequest: String?
}

public struct CLITrashReport: Codable, Equatable, Sendable {
    /// False for a preview: nothing was moved.
    public var confirmed: Bool
    /// What was moved, or what would be.
    public var paths: [String]
    public var bytes: Int64
    public var failed: [CLITrashFailure]

    public init(confirmed: Bool, paths: [String], bytes: Int64, failed: [CLITrashFailure] = []) {
        self.confirmed = confirmed
        self.paths = paths
        self.bytes = bytes
        self.failed = failed
    }
}

/// What the last trash run put back where it was.
public struct CLIUndoReport: Codable, Equatable, Sendable {
    public var paths: [String]
    public var bytes: Int64
    public var failed: [CLITrashFailure]

    public init(paths: [String], bytes: Int64, failed: [CLITrashFailure] = []) {
        self.paths = paths
        self.bytes = bytes
        self.failed = failed
    }
}

public struct CLITrashFailure: Codable, Equatable, Sendable {
    public var path: String
    public var reason: String

    public init(path: String, reason: String) {
        self.path = path
        self.reason = reason
    }
}

public enum CLIProtocol {
    /// Where the app listens. Kept short enough for a socket path (104 bytes).
    public static var socketURL: URL {
        URL.applicationSupportDirectory.appending(path: Brand.supportFolderName + "/cli.sock")
    }

    public static let bundleIdentifier = "app.diskforecast.DiskForecast"

    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
