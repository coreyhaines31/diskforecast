import Foundation

/// A kind of thing taking space on the disk, as the storage meter groups it.
public enum StorageCategory: String, Sendable, CaseIterable, Identifiable {
    case apps
    case developer
    case photos
    case movies
    case documents
    case music
    case caches
    /// Everything used that no other category measured: macOS itself, app data in Library, and
    /// anything the scan can't see.
    case other
    case trash

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .apps: "Apps"
        case .developer: "Developer"
        case .photos: "Photos"
        case .movies: "Movies"
        case .documents: "Documents"
        case .music: "Music"
        case .caches: "Caches"
        case .other: "System and other"
        case .trash: "Trash"
        }
    }

    /// What's counted in it, for tooltips and VoiceOver.
    public var explanation: String {
        switch self {
        case .apps: "Applications, and Applications in your home folder"
        case .developer: "Xcode and simulators, Docker, package caches, and folders with code projects"
        case .photos: "Pictures, including the Photos library"
        case .movies: "Movies, including the TV app's downloads"
        case .documents: "Documents, Desktop, Downloads, and iCloud Drive"
        case .music: "Music, including the Music app's library"
        case .caches: "Library/Caches and the caches web-based apps keep with their data"
        case .other: "macOS, app data in Library, and everything not counted above"
        case .trash: "Files you've deleted that are still in the Trash"
        }
    }
}

/// How much of the disk one category takes.
public struct StorageShare: Sendable, Hashable, Identifiable {
    public let category: StorageCategory
    public let bytes: Int64

    public var id: StorageCategory { category }

    public init(category: StorageCategory, bytes: Int64) {
        self.category = category
        self.bytes = bytes
    }
}

/// Used space split into categories from what the app already measures: the home folder scan,
/// the Cleanup list, the Trash, Applications, and the volume's capacity. What nothing measured is
/// `other`, so the shares always add up to `usedBytes`.
public struct StorageBreakdown: Sendable {
    /// The order the meter lays categories out in, ending with the Trash next to free space.
    public static let meterOrder: [StorageCategory] = [
        .apps, .developer, .photos, .movies, .documents, .music, .caches, .other, .trash
    ]

    /// A folder (or a size measured elsewhere) that counts towards a category.
    public struct Claim: Sendable, Hashable {
        public let category: StorageCategory
        public let path: String
        /// Bytes measured outside the home folder scan; nil reads the path's size from the scan.
        public let bytes: Int64?

        public init(_ category: StorageCategory, _ path: String, bytes: Int64? = nil) {
            self.category = category
            self.path = path
            self.bytes = bytes
        }
    }

    public let capacityBytes: Int64
    /// Used space. Normally what the volume reports; when the categories measure more than that
    /// (APFS clones, space macOS counts as purgeable), it's what they measured.
    public let usedBytes: Int64
    /// Categories with any bytes, in `meterOrder`.
    public let shares: [StorageShare]
    /// Categories that couldn't be measured and came to nothing, such as the Trash without Full
    /// Disk Access. Their space is in `other`.
    public let unmeasured: [StorageCategory]
    /// False without Full Disk Access: some folders couldn't be read, and their space is in `other`.
    public let isComplete: Bool

    /// Shares largest first, ties in meter order.
    public var bySize: [StorageShare] {
        shares.enumerated()
            .sorted { lhs, rhs in
                lhs.element.bytes != rhs.element.bytes ? lhs.element.bytes > rhs.element.bytes : lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    public var freeBytes: Int64 { max(0, capacityBytes - usedBytes) }

    public func bytes(of category: StorageCategory) -> Int64 {
        shares.first { $0.category == category }?.bytes ?? 0
    }

    /// What to call `other`: without Full Disk Access it holds folders that couldn't be read too.
    public var otherTitle: String { isComplete ? StorageCategory.other.title : "Not measured" }

    public func title(of category: StorageCategory) -> String {
        category == .other ? otherTitle : category.title
    }

    /// Splits used space between the claims. A claim inside one already counted adds nothing, and
    /// one around earlier claims adds only what they didn't count, so nothing is counted twice.
    public init(
        capacityBytes: Int64, volumeUsedBytes: Int64, claims: [Claim], size: (String) -> Int64?,
        unmeasured: [StorageCategory] = [], isComplete: Bool = true
    ) {
        var totals: [StorageCategory: Int64] = [:]
        var counted: [String: Int64] = [:]
        for claim in claims {
            let path = Self.normalized(claim.path)
            guard !counted.keys.contains(where: { Self.isInside(path, $0) }),
                  let bytes = claim.bytes ?? size(path), bytes > 0
            else { continue }
            let inner = counted.filter { Self.isInside($0.key, path) }
            for key in inner.keys { counted[key] = nil }
            counted[path] = bytes
            totals[claim.category, default: 0] += max(0, bytes - inner.values.reduce(0, +))
        }
        totals[.other] = nil
        let measured = totals.values.reduce(0, +)
        let used = max(volumeUsedBytes, measured, 0)
        totals[.other] = used - measured
        self.capacityBytes = max(0, capacityBytes)
        self.usedBytes = used
        self.shares = Self.meterOrder.compactMap { category in
            guard let bytes = totals[category], bytes > 0 else { return nil }
            return StorageShare(category: category, bytes: bytes)
        }
        self.unmeasured = Self.meterOrder.filter { unmeasured.contains($0) && $0 != .other && totals[$0] == nil }
        self.isComplete = isComplete
    }

    /// Which category lights each of `count` columns, left to right; nil columns are free space.
    /// Every share gets at least one column, so a small Trash still shows.
    public func columns(_ count: Int) -> [StorageCategory?] {
        guard count >= 1, capacityBytes > 0 else { return Array(repeating: nil, count: max(0, count)) }
        var owners = [StorageCategory?](repeating: nil, count: count)
        var cumulative: Int64 = 0
        var start = 0
        for share in shares where start < count {
            cumulative += share.bytes
            let edge = Int((Double(cumulative) * Double(count) / Double(capacityBytes)).rounded())
            let end = min(count, max(start + 1, edge))
            for index in start..<end { owners[index] = share.category }
            start = end
        }
        return owners
    }

    static func normalized(_ path: String) -> String {
        path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    /// Whether `path` is `ancestor` or somewhere under it.
    static func isInside(_ path: String, _ ancestor: String) -> Bool {
        path == ancestor || path.hasPrefix(ancestor == "/" ? "/" : ancestor + "/")
    }
}
