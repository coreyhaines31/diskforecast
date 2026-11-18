import Foundation

/// The System Data values cheap enough to read with every saved scan: no administrator access and
/// no slow command. Each is nil when it couldn't be read.
public struct SystemDataReading: Codable, Sendable, Equatable {
    /// Space macOS is holding for caches, iCloud copies, and snapshots.
    public var purgeableBytes: Int64?
    /// How many local Time Machine snapshots `tmutil listlocalsnapshots /` listed.
    public var localSnapshotCount: Int?
    /// Space the swap files take, from `sysctl vm.swapusage`. Nil in readings saved before swap was.
    public var swapBytes: Int64?

    public init(purgeableBytes: Int64?, localSnapshotCount: Int?, swapBytes: Int64? = nil) {
        self.purgeableBytes = purgeableBytes
        self.localSnapshotCount = localSnapshotCount
        self.swapBytes = swapBytes
    }
}
