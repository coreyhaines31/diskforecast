import Foundation

/// How much one folder grew and shrank from scan to scan over a stretch of days, as opposed to
/// where it ended up.
public struct FolderChurn: Sendable, Equatable, Identifiable {
    /// Path relative to the home folder.
    public let path: String
    /// Every change between consecutive scans added up, growth and shrinking alike.
    public let movedBytes: Int64
    /// Those same changes with their signs: how much bigger it ended up.
    public let netBytes: Int64

    public var id: String { path }
    /// The part of the movement that cancelled out: twice the smaller of what it grew and what it shrank.
    public var backAndForthBytes: Int64 { movedBytes - abs(netBytes) }

    public init(path: String, movedBytes: Int64, netBytes: Int64) {
        self.path = path
        self.movedBytes = movedBytes
        self.netBytes = netBytes
    }

    /// "moved 41 GB over 9 days, ended 2.0 GB up". Describes movement, never a cause.
    public func summary(days: Int) -> String {
        let span = "moved \(Bytes.format(movedBytes)) over \(days) day\(days == 1 ? "" : "s")"
        if abs(netBytes) < FolderChurns.stepThreshold { return span + ", ended about where it started" }
        return span + ", ended \(Bytes.format(abs(netBytes))) " + (netBytes > 0 ? "up" : "down")
    }
}

public enum FolderChurns {
    /// A change between two scans smaller than this is noise, as in What changed.
    public static let stepThreshold: Int64 = 500_000_000
    public static let minimumSnapshots = 3

    /// The folders that grew and shrank the most between consecutive snapshots, which must be in
    /// day order, ranked by how much of that movement cancelled out. Each folder is compared with
    /// the last snapshot that measured it, so a scan that couldn't read it adds nothing. A folder
    /// absent from an old snapshot, which can't say what it missed, counts as empty there once it
    /// has been seen, and adds nothing before that, so a folder first read part-way through starts
    /// from its size. A folder that only grew or only shrank isn't listed, which also leaves out one
    /// that just appeared.
    ///
    /// A folder is left out when a folder inside it moved back and forth at least half as much, so
    /// that folder stands for it; and one inside a listed folder is left out, so nothing counts twice.
    public static func churn(in snapshots: [FolderSnapshot]) -> [FolderChurn] {
        // A scan that recorded no folders at all measured nothing, even when an old snapshot can't say so.
        let snapshots = snapshots.filter { !$0.folders.isEmpty }
        guard snapshots.count >= minimumSnapshots else { return [] }
        let paths = Set(snapshots.flatMap(\.folders.keys))
        var last: [String: Int64] = [:]
        var moved: [String: Int64] = [:]
        var net: [String: Int64] = [:]
        for snapshot in snapshots {
            for path in paths where !snapshot.couldNotMeasure(path) {
                if snapshot.unmeasured == nil && snapshot.folders[path] == nil && last[path] == nil { continue }
                let bytes = snapshot.folders[path] ?? 0
                if let previous = last[path], abs(bytes - previous) >= stepThreshold {
                    moved[path, default: 0] += abs(bytes - previous)
                    net[path, default: 0] += bytes - previous
                }
                last[path] = bytes
            }
        }
        let candidates = moved.map { FolderChurn(path: $0.key, movedBytes: $0.value, netBytes: net[$0.key] ?? 0) }
            .filter { $0.backAndForthBytes > 0 }
        let byPath = Dictionary(uniqueKeysWithValues: candidates.map { ($0.path, $0) })
        var standsIn: Set<String> = []
        for folder in candidates {
            for ancestor in ancestors(of: folder.path) {
                if let outer = byPath[ancestor], folder.backAndForthBytes * 2 >= outer.backAndForthBytes {
                    standsIn.insert(ancestor)
                }
            }
        }
        let listed = Set(byPath.keys).subtracting(standsIn)
        return candidates
            .filter { listed.contains($0.path) && !ancestors(of: $0.path).contains(where: listed.contains) }
            .sorted {
                $0.backAndForthBytes != $1.backAndForthBytes
                    ? $0.backAndForthBytes > $1.backAndForthBytes : $0.path < $1.path
            }
    }

    /// "code/app/.next" → ["code/app", "code"].
    static func ancestors(of path: String) -> [String] {
        var result: [String] = []
        var current = path
        while let slash = current.lastIndex(of: "/") {
            current = String(current[..<slash])
            result.append(current)
        }
        return result
    }
}
