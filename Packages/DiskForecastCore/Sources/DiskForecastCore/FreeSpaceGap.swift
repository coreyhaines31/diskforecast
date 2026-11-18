import Foundation

/// Free space that changed by much more than the home folder did between two scans, with the
/// saved System Data that changed over the same period. It names what changed, never a cause.
public struct FreeSpaceGap: Sendable, Equatable {
    /// How far outside-the-home-folder change has to go before it's worth explaining.
    public static let threshold: Int64 = 5_000_000_000
    private static let purgeableThreshold: Int64 = 1_000_000_000
    private static let sameThreshold: Int64 = 500_000_000

    public let freeDelta: Int64
    public let homeDelta: Int64
    /// Used space outside the home folder: positive when it grew, negative when it came back.
    public let outsideHomeBytes: Int64
    /// "purgeable space went from 30 GB to 12 GB", for each saved value that changed.
    public let systemDataChanges: [String]
    /// The saved values that were read on both days, even if they didn't change.
    private let comparedNames: [String]

    public init?(from old: FolderSnapshot, to new: FolderSnapshot, threshold: Int64 = Self.threshold) {
        let outside = FolderChanges.outsideHomeDelta(from: old, to: new)
        guard abs(outside) >= threshold else { return nil }
        freeDelta = new.freeBytes - old.freeBytes
        homeDelta = new.homeBytes - old.homeBytes
        outsideHomeBytes = outside

        var changes: [String] = []
        var compared: [String] = []
        if let before = old.systemData?.purgeableBytes, let after = new.systemData?.purgeableBytes {
            compared.append("purgeable space")
            if abs(after - before) >= Self.purgeableThreshold {
                changes.append("purgeable space went from \(Bytes.format(before)) to \(Bytes.format(after))")
            }
        }
        if let before = old.systemData?.localSnapshotCount, let after = new.systemData?.localSnapshotCount {
            compared.append("local Time Machine snapshots")
            if before != after {
                changes.append("local Time Machine snapshots went from \(before) to \(after)")
            }
        }
        systemDataChanges = changes
        comparedNames = compared
    }

    /// One line for `diskforecast status`, pointing at `diskforecast changes` for the rest.
    public func statusNote(days: Int) -> String {
        "In the last \(days) days, \(Bytes.format(abs(outsideHomeBytes))) was "
            + "\(outsideHomeBytes > 0 ? "used" : "freed") outside your home folder, more than scans explain. "
            + "See: diskforecast changes --days \(days)"
    }

    /// A few plain sentences: how free space and the home folder moved, what's left over, and which
    /// saved System Data changed, or that nothing saved explains it.
    public var explanation: String {
        let free = abs(freeDelta) < Self.sameThreshold
            ? "Free space stayed about the same"
            : "Free space \(freeDelta > 0 ? "rose" : "fell") \(Bytes.format(abs(freeDelta)))"
        let home = abs(homeDelta) < Self.sameThreshold
            ? "your home folder stayed about the same"
            : "your home folder \(homeDelta > 0 ? "grew" : "shrank") \(Bytes.format(abs(homeDelta)))"
        var sentences = [
            "\(free), while \(home).",
            "That leaves \(Bytes.format(abs(outsideHomeBytes))) \(outsideHomeBytes > 0 ? "used" : "freed") "
                + "outside your home folder, where scans don't look."
        ]
        if !systemDataChanges.isEmpty {
            sentences.append("Over the same period, \(systemDataChanges.joined(separator: ", and ")).")
            sentences.append("That doesn't prove what caused it.")
        } else if !comparedNames.isEmpty {
            let names = comparedNames.joined(separator: " and ")
            sentences.append(
                "\(names.prefix(1).uppercased() + names.dropFirst()) stayed about the same, "
                    + "so \(Brand.name) can't say what changed."
            )
        } else {
            sentences.append("\(Brand.name) didn't record System Data back then, so it can't say what changed.")
            sentences.append("It saves purgeable space and local Time Machine snapshots with each scan from now on.")
        }
        return sentences.joined(separator: " ")
    }
}
