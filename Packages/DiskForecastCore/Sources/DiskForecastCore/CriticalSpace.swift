import Foundation

/// Catches a disk that is nearly out of space, however slowly it got there. The daily alert stays
/// quiet for a day after it fires and the fast-fill warning needs a steep fall, so a disk that is
/// already low and loses its last 40 GB over an afternoon would otherwise say nothing.
public enum CriticalSpace {
    /// The marks worth an alert each, smallest first. Under the first, apps start failing to save
    /// and the Trash can't take more files.
    public static let floors: [Int64] = [1_000_000_000, 5_000_000_000]

    /// What to do after a free-space reading.
    public struct Decision: Sendable, Equatable {
        /// The floor free space just fell under, when it's worth an alert.
        public var alert: Int64?
        /// The floor to remember as already warned about, for the next reading.
        public var remembered: Int64?
    }

    /// One alert each time free space falls under a floor. A floor is warned about again only after
    /// free space has risen half as much again above it, so hovering at the line doesn't repeat it.
    public static func decide(freeBytes: Int64, lastFloor: Int64?) -> Decision {
        let remembered = held(lastFloor, freeBytes: freeBytes)
        guard let current = floors.first(where: { freeBytes < $0 }) else {
            return Decision(alert: nil, remembered: remembered)
        }
        if let remembered, remembered <= current { return Decision(alert: nil, remembered: remembered) }
        return Decision(alert: current, remembered: current)
    }

    /// The floor still counted as warned about: the last one, or a larger one, that free space
    /// hasn't climbed clear of.
    private static func held(_ lastFloor: Int64?, freeBytes: Int64) -> Int64? {
        guard let lastFloor else { return nil }
        return floors.first { $0 >= lastFloor && freeBytes < $0 + $0 / 2 }
    }

    /// The floor free space is under, to remember when another alert has already said space is short.
    public static func floor(under freeBytes: Int64) -> Int64? {
        floors.first { freeBytes < $0 }
    }

    /// The notification's title and body: how little is left, what that breaks, and the quickest space.
    public static func message(freeBytes: Int64, trashBytes: Int64?) -> (title: String, body: String) {
        let body = "Apps can fail to save and downloads can stop when the disk is this full. "
            + DiskAlert.quickestSpace(trashBytes: trashBytes)
        return ("Almost out of disk space: \(Bytes.format(max(0, freeBytes))) free", body)
    }
}
