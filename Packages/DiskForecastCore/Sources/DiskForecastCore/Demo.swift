#if DEBUG
import Foundation

/// Made-up but typical data for the README images, so they show the app without anyone's real
/// folders. Debug builds only.
public enum Demo {
    static let gigabyte: Int64 = 1_000_000_000
    public static let capacityBytes: Int64 = 494 * gigabyte
    public static let freeBytes: Int64 = 142 * gigabyte

    /// Folder sizes under the home folder, by relative path. Leaves hold the bytes.
    static let folders: [(String, Double)] = [
        ("Library/Developer/Xcode/DerivedData", 9.6),
        ("Library/Developer/Xcode/iOS DeviceSupport", 7.8),
        ("Library/Developer/CoreSimulator/Devices", 21),
        ("Library/Caches/com.spotify.client", 3.1),
        ("Library/Caches/Google", 2.4),
        ("Library/Logs", 1.2),
        ("Library/Application Support/Slack", 1.6),
        ("Library/Application Support/Slack/Cache", 1.3),
        ("Library/Application Support/Cursor/CachedExtensionVSIXs", 1.1),
        ("Movies/Final Cut Projects", 38),
        ("Pictures/Photos Library.photoslibrary", 64),
        ("code/storefront/node_modules", 1.4),
        ("code/storefront/src", 0.4),
        ("code/api/target", 6.2),
        ("code/api/src", 0.2),
        ("code/website/.next", 0.9),
        ("Downloads/macOS Installer.dmg", 14),
        ("Downloads/Screen Recordings", 2.6),
        (".npm/_cacache", 4.6),
        (".ollama/models", 18),
        ("Documents", 12)
    ]

    public static func scan(home: String) -> ScanResult {
        ScanResult(
            tree: tree(home: home, folders: folders), fileCount: 2_480_000, largestFiles: [], diskImages: [],
            artifacts: [], worktrees: [], deniedCount: 0, deniedSamples: [], skippedPaths: [], stalledPaths: [],
            duration: 31
        )
    }

    static func tree(home: String, folders: [(String, Double)]) -> ScanTree {
        var names = [home]
        var parents: [Int32] = [-1]
        var children: [[Int32]] = [[]]
        var ownBytes: [Int64] = [0]
        var nodes: [String: Int32] = ["": 0]
        for (path, gigabytes) in folders {
            var current: Int32 = 0
            var walked = ""
            for component in path.split(separator: "/").map(String.init) {
                walked = walked.isEmpty ? component : walked + "/" + component
                if let existing = nodes[walked] {
                    current = existing
                    continue
                }
                let node = Int32(names.count)
                names.append(component)
                parents.append(current)
                children.append([])
                ownBytes.append(0)
                children[Int(current)].append(node)
                nodes[walked] = node
                current = node
            }
            ownBytes[Int(current)] += Int64(gigabytes * Double(gigabyte))
        }
        return ScanTree(rootPath: home, names: names, parents: parents, children: children, ownBytes: ownBytes)
    }

    /// The cleanup list for the demo home folder, with the real rules' titles and explanations.
    public static func cleanupItems(home: String) -> [CleanupItem] {
        let rules = CleanupCatalog(home: home).rules
        let details = [
            "code/api/target": "api · last changed 3 months ago",
            "code/website/.next": "website · last changed 6 weeks ago",
            "Downloads/macOS Installer.dmg": "Modified 5 weeks ago",
            "code/storefront/node_modules": "storefront · last changed today",
            "code/storefront-checkout-flow": "storefront · 2 commits not pushed · last changed 3 days ago",
            "Library/Application Support/Slack/Cache": "Cache",
            "Library/Application Support/Cursor/CachedExtensionVSIXs": "CachedExtensionVSIXs"
        ]
        let names = [
            "Library/Application Support/Slack/Cache": "Slack",
            "Library/Application Support/Cursor/CachedExtensionVSIXs": "Cursor"
        ]
        func item(_ id: String, _ entries: [(path: String, gigabytes: Double)]) -> CleanupItem? {
            guard let rule = rules.first(where: { $0.id == id }) else { return nil }
            return CleanupItem(
                id: rule.id, title: rule.title, explanation: rule.explanation, group: rule.group, action: rule.action,
                entries: entries.map { entry in
                    CleanupEntry(
                        path: home + "/" + entry.path, bytes: Int64(entry.gigabytes * Double(gigabyte)),
                        detail: details[entry.path], name: names[entry.path]
                    )
                }
            )
        }
        return [
            item("stale-builds", [("code/api/target", 6.2), ("code/website/.next", 0.9)]),
            item("xcode-derived-data", [("Library/Developer/Xcode/DerivedData", 9.6)]),
            item("device-support", [("Library/Developer/Xcode/iOS DeviceSupport", 7.8)]),
            item("package-caches", [(".npm/_cacache", 4.6)]),
            item("app-caches", [("Library/Caches/com.spotify.client", 3.1), ("Library/Caches/Google", 2.4)]),
            item("app-support-caches", [
                ("Library/Application Support/Slack/Cache", 1.3),
                ("Library/Application Support/Cursor/CachedExtensionVSIXs", 1.1)
            ]),
            item("logs", [("Library/Logs", 1.2)]),
            item("ollama", [(".ollama/models", 18)]),
            item("disk-images", [("Downloads/macOS Installer.dmg", 14)]),
            item("active-builds", [("code/storefront/node_modules", 1.4)]),
            item("git-worktrees", [("code/storefront-checkout-flow", 3.4)])
        ]
        .compactMap { $0 }
        .sorted { $0.bytes > $1.bytes }
    }

    /// 45 days of free space, falling about 3.5 GB a day with ordinary ups and downs, ending at
    /// `freeBytes` today.
    public static func history(now: Date = Date(), calendar: Calendar = .current) -> UsageHistory {
        var history = UsageHistory()
        let wobble: [Double] = [0, 1.2, -0.8, 2.1, -1.5, 0.6, 3.4, -0.4, 1.1, -2.2, 0.3, 1.8]
        for daysAgo in stride(from: 44, through: 0, by: -1) {
            let gigabytes = 142 + 3.5 * Double(daysAgo) + wobble[daysAgo % wobble.count] * (daysAgo == 0 ? 0 : 1)
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
            history.record(
                freeBytes: Int64(gigabytes * Double(gigabyte)), capacityBytes: capacityBytes, at: date,
                calendar: calendar
            )
        }
        return history
    }

    /// Two snapshots 30 days apart, so What changed has a story to tell: simulators, an Ollama
    /// model, and Xcode builds grew, a macOS installer arrived, and a video project shrank.
    public static func snapshots(home: String, now: Date = Date(), calendar: Calendar = .current)
        -> (old: FolderSnapshot, new: FolderSnapshot) {
        let earlier: [String: Double] = [
            "Library/Developer/CoreSimulator/Devices": 6, "Library/Developer/Xcode/DerivedData": 3.1,
            ".ollama/models": 4.2, "Downloads/macOS Installer.dmg": 0, "Movies/Final Cut Projects": 44,
            "code/api/target": 2.1
        ]
        let oldFolders = folders.map { ($0.0, earlier[$0.0] ?? $0.1) }.filter { $0.1 > 0 }
        let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let new = FolderSnapshot(tree: scan(home: home).tree, freeBytes: freeBytes, at: now, calendar: calendar)
        let oldTree = tree(home: home, folders: oldFolders)
        // Most of the growth is in the home folder, with a few GB more in System Data.
        let homeGrowth = new.homeBytes - oldTree.totalSize
        let old = FolderSnapshot(
            tree: oldTree, freeBytes: freeBytes + homeGrowth + 4 * gigabyte, at: start, calendar: calendar
        )
        return (old, new)
    }
}
#endif
