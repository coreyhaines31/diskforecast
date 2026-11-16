@testable import DiskForecastCore
import Foundation
import Testing

struct StorageBreakdownTests {
    private static let gigabyte: Int64 = 1_000_000_000
    private let home = "/Users/demo"

    private func scan(_ folders: [(String, Double)]) -> ScanResult {
        ScanResult(
            tree: Demo.tree(home: home, folders: folders), fileCount: 0, largestFiles: [], diskImages: [],
            artifacts: [], worktrees: [], deniedCount: 0, deniedSamples: [], skippedPaths: [], stalledPaths: [],
            duration: 0
        )
    }

    private func item(_ id: String, _ paths: [String]) -> CleanupItem {
        CleanupItem(
            id: id, title: id, explanation: "", group: .safeToClear, action: .trash,
            entries: paths.map { CleanupEntry(path: home + "/" + $0, bytes: Self.gigabyte) }
        )
    }

    private func breakdown(
        _ folders: [(String, Double)], items: [CleanupItem] = [], used: Double = 300,
        applications: Double? = 40, trash: Double? = 5, fullDiskAccess: Bool = true
    ) -> StorageBreakdown {
        StorageBreakdown(
            home: home, scan: scan(folders), items: items, capacityBytes: 500 * Self.gigabyte,
            volumeUsedBytes: Int64(used * Double(Self.gigabyte)),
            applicationsBytes: applications.map { Int64($0 * Double(Self.gigabyte)) },
            trashBytes: trash.map { Int64($0 * Double(Self.gigabyte)) }, fullDiskAccess: fullDiskAccess
        )
    }

    private func gigabytes(_ breakdown: StorageBreakdown, _ category: StorageCategory) -> Double {
        Double(breakdown.bytes(of: category)) / Double(Self.gigabyte)
    }

    @Test func sharesAddUpToUsedSpace() {
        let result = breakdown([
            ("Pictures/Photos Library.photoslibrary", 60), ("Movies", 20), ("Music", 8), ("Documents", 12),
            ("Desktop", 2), ("Library/Caches/Google", 3), ("Library/Developer/Xcode", 30), (".Trash", 5)
        ])
        #expect(result.usedBytes == 300 * Self.gigabyte)
        #expect(result.shares.reduce(0) { $0 + $1.bytes } == result.usedBytes)
        #expect(gigabytes(result, .apps) == 40)
        #expect(gigabytes(result, .photos) == 60)
        #expect(gigabytes(result, .documents) == 14)
        #expect(gigabytes(result, .developer) == 30)
        #expect(gigabytes(result, .caches) == 3)
        #expect(gigabytes(result, .trash) == 5)
        #expect(gigabytes(result, .other) == 300 - 40 - 60 - 20 - 8 - 14 - 3 - 30 - 5)
    }

    @Test func otherIsNeverNegative() {
        // More measured than the volume says is used, as with APFS clones.
        let result = breakdown([("Movies", 200), ("Documents", 150)], used: 300, applications: nil, trash: 0)
        #expect(result.bytes(of: .other) == 0)
        #expect(result.shares.allSatisfy { $0.bytes > 0 })
        #expect(result.usedBytes == 350 * Self.gigabyte)
        #expect(result.shares.reduce(0) { $0 + $1.bytes } == result.usedBytes)
    }

    @Test func countsNestedClaimsOnce() {
        // A project in Documents is Developer, and Documents keeps the rest.
        let result = breakdown(
            [("Documents/notes", 4), ("Documents/shop/node_modules", 2), ("Documents/shop/src", 1)],
            items: [item("active-builds", ["Documents/shop/node_modules"])], applications: 0, trash: 0
        )
        #expect(gigabytes(result, .developer) == 3)
        #expect(gigabytes(result, .documents) == 4)
    }

    @Test func claimsAFolderOfProjectsWhole() {
        let result = breakdown(
            [("code/api/target", 6), ("code/api/src", 1), ("code/notes.md", 2)],
            items: [item("stale-builds", ["code/api/target"])], applications: 0, trash: 0
        )
        #expect(gigabytes(result, .developer) == 9)
    }

    @Test func cachesIncludeWebAppCachesAndDeveloperIncludesPackageCaches() {
        let result = breakdown(
            [("Library/Caches/x", 2), ("Library/Application Support/Slack/Cache", 1.5), (".npm/_cacache", 4)],
            items: [
                item("app-support-caches", ["Library/Application Support/Slack/Cache"]),
                item("package-caches", [".npm/_cacache"])
            ]
        )
        #expect(gigabytes(result, .caches) == 3.5)
        #expect(gigabytes(result, .developer) == 4)
    }

    @Test func withoutFullDiskAccessTheTrashIsUnmeasured() {
        let result = breakdown([("Movies", 10), (".Trash", 9)], trash: nil, fullDiskAccess: false)
        #expect(result.bytes(of: .trash) == 0)
        #expect(result.unmeasured == [.trash])
        #expect(!result.isComplete)
        #expect(result.otherTitle == "Not measured")
        #expect(result.shares.reduce(0) { $0 + $1.bytes } == result.usedBytes)
    }

    @Test func missingApplicationsIsUnmeasuredUnlessHomeAppsCount() {
        #expect(breakdown([], applications: nil).unmeasured == [.apps])
        let homeApps = breakdown([("Applications/Tool.app", 1)], applications: nil)
        #expect(homeApps.unmeasured.isEmpty)
        #expect(gigabytes(homeApps, .apps) == 1)
    }

    @Test func sharesAreInMeterOrderAndBySizeIsLargestFirst() {
        let result = breakdown([("Music", 30), ("Movies", 10), ("Pictures", 20)])
        let order = result.shares.map(\.category)
        #expect(order == StorageBreakdown.meterOrder.filter(order.contains))
        #expect(order.last == .trash)
        let sizes = result.bySize.map(\.bytes)
        #expect(sizes == sizes.sorted(by: >))
    }

    @Test func emptyCategoriesAreLeftOut() {
        let result = breakdown([], applications: 0, trash: 0)
        #expect(result.shares.map(\.category) == [.other])
    }

    @Test func columnsGiveEveryShareAColumnAndStopAtUsed() {
        let result = breakdown([("Movies", 100), ("Library/Caches/x", 0.2)], used: 250, applications: 0, trash: 1)
        let columns = result.columns(50)
        #expect(columns.count == 50)
        #expect(columns.contains(.caches))
        #expect(columns[49] == nil)
        // Half the disk is 25 columns; the tiny Caches share takes one more.
        #expect(columns.compactMap { $0 }.count == 26)
        // Lit columns run left to right with no gaps.
        #expect(columns.firstIndex(of: nil) == columns.compactMap { $0 }.count)
    }

    @Test func columnsNeverOverflowAFullDisk() {
        let result = breakdown([("Movies", 600)], used: 600, applications: 0, trash: 0)
        let columns = result.columns(50)
        #expect(columns.count == 50)
        #expect(columns.allSatisfy { $0 != nil })
    }
}
