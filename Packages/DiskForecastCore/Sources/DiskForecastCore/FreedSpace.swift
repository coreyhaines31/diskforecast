import Foundation

/// What a deletion freed, measured: free space before it and after, beside what the sizes of the
/// removed things promised. The two differ when files share storage with ones that stayed, a
/// snapshot still holds them, or macOS hasn't finished releasing them. Learned from mattt/plonge.
public struct FreedSpace: Sendable, Equatable {
    /// The sizes of what was removed, added up. Nil when they weren't measured.
    public let estimate: Int64?
    public let before: Int64
    public let after: Int64

    /// Below this, whatever else is writing to the disk moves free space more than the deletion did.
    static let smallestComparable: Int64 = 500_000_000

    public init(estimate: Int64?, before: Int64, after: Int64) {
        self.estimate = estimate
        self.before = before
        self.after = after
    }

    /// How much free space grew. Never negative: something else filling the disk isn't a loss here.
    public var gained: Int64 { max(0, after - before) }

    /// Whether noticeably less came back than the sizes promised.
    public var fellShort: Bool {
        guard let estimate, estimate >= Self.smallestComparable else { return false }
        return gained * 10 < estimate * 9
    }

    /// One or two sentences on what came back, for the result of a deletion.
    public var summary: String {
        guard fellShort, let estimate else {
            return gained > 0 ? "\(Bytes.format(gained)) is free again." : "The space is free now."
        }
        let why = "is shared with files that stayed or kept by a snapshot, or macOS is still releasing it."
        if gained == 0 { return "Free space hasn't grown yet. What was removed \(why)" }
        return "\(Bytes.format(gained)) is free again, of the \(Bytes.format(estimate)) removed. The rest \(why)"
    }
}
