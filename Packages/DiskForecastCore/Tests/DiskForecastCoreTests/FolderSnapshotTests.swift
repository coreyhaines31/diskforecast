@testable import DiskForecastCore
import Foundation
import Testing

struct FolderSnapshotTests {
    let gigabyte: Int64 = 1_000_000_000
    let day = Date(timeIntervalSince1970: 1_790_000_000)

    // /home
    //   code -> app (2 GB) -> node_modules (1.5 GB) -> big (1.2 GB)
    //        -> tiny (50 MB)
    //   Movies (30 GB)
    var tree: ScanTree {
        ScanTree(
            rootPath: "/home",
            names: ["/home", "code", "Movies", "app", "tiny", "node_modules", "big"],
            parents: [-1, 0, 0, 1, 1, 3, 5],
            children: [[1, 2], [3, 4], [], [5], [], [6], []],
            ownBytes: [0, 0, 30 * gigabyte, gigabyte / 2, 50_000_000, 300_000_000, 1_200_000_000]
        )
    }

    @Test func recordsFoldersThreeLevelsDownAboveTheMinimum() {
        let snapshot = FolderSnapshot(tree: tree, freeBytes: 10 * gigabyte, at: day)
        #expect(snapshot.folders["code"] == 2_050_000_000)
        #expect(snapshot.folders["code/app"] == 2_000_000_000)
        #expect(snapshot.folders["code/app/node_modules"] == 1_500_000_000)
        #expect(snapshot.folders["code/app/node_modules/big"] == nil)  // four levels down
        #expect(snapshot.folders["code/tiny"] == nil)  // under 100 MB
        #expect(snapshot.folders["Movies"] == 30 * gigabyte)
        #expect(snapshot.homeBytes == tree.totalSize)
    }

    @Test func listsWhatGrewBiggestFirstAndDrillsIn() {
        let old = FolderSnapshot(
            day: day, homeBytes: 100 * gigabyte, freeBytes: 200 * gigabyte,
            folders: ["code": 160 * gigabyte, "code/site": 10 * gigabyte, "Movies": 30 * gigabyte,
                      "Downloads": 5 * gigabyte]
        )
        let new = FolderSnapshot(
            day: day, homeBytes: 180 * gigabyte, freeBytes: 20 * gigabyte,
            folders: ["code": 248 * gigabyte, "code/site": 10 * gigabyte, "code/copy-1": 4 * gigabyte,
                      "code/copy-2": 4 * gigabyte, "Movies": 30 * gigabyte, "Downloads": 3 * gigabyte]
        )
        let top = FolderChanges.changes(from: old, to: new)
        let topPaths = top.map(\.path)
        #expect(topPaths == ["code", "Downloads"])
        #expect(top[0].delta == 88 * gigabyte)
        #expect(top[0].hasChildren)
        #expect(top[1].delta == -2 * gigabyte)

        let inside = FolderChanges.changes(from: old, to: new, under: "code")
        let insidePaths = Set(inside.map(\.path))
        let allNew = inside.allSatisfy { $0.isNew }
        #expect(insidePaths == ["code/copy-1", "code/copy-2"])
        #expect(allNew)
    }

    @Test func storeKeepsOneSnapshotADayAndFindsTheBaseline() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let folder = FileManager.default.temporaryDirectory.appending(path: "DiskForecastTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = FolderSnapshotStore(folder: folder, calendar: calendar)
        let today = calendar.startOfDay(for: day)
        func on(_ offset: Int, free: Int64) -> FolderSnapshot {
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            return FolderSnapshot(day: date, homeBytes: 0, freeBytes: free, folders: [:])
        }
        try store.save(on(-130, free: 1))  // older than four months
        try store.save(on(-10, free: 2))
        try store.save(on(-3, free: 3))
        try store.save(on(0, free: 4))
        try store.save(on(0, free: 5))  // same day replaces

        #expect(store.latest()?.freeBytes == 5)
        let sinceTwoWeeks = calendar.date(byAdding: .day, value: -14, to: today)!
        let sinceFiveDays = calendar.date(byAdding: .day, value: -5, to: today)!
        #expect(store.baseline(since: sinceTwoWeeks)?.freeBytes == 2)
        #expect(store.baseline(since: sinceFiveDays)?.freeBytes == 3)
        #expect(store.baseline(since: today) == nil)
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(files.count == 3)
    }

    @Test func recordsTheFoldersTheScanCouldNotRead() {
        let snapshot = FolderSnapshot(
            tree: tree, freeBytes: 0, at: day,
            unmeasured: ["/home/Library/Messages", "/Volumes/Backup", "/home/Desktop"]
        )
        #expect(snapshot.unmeasured == ["Desktop", "Library/Messages"])
    }

    // Full Disk Access came on between the scans: Messages and Containers were measured for the
    // first time, Caches really grew, and code/new-app really appeared.
    var accessGranted: (old: FolderSnapshot, new: FolderSnapshot) {
        let old = FolderSnapshot(
            day: day, homeBytes: 40 * gigabyte, freeBytes: 100 * gigabyte,
            folders: ["Library": 20 * gigabyte, "Library/Caches": 5 * gigabyte, "code": 20 * gigabyte],
            unmeasured: ["Library/Containers", "Library/Messages"]
        )
        let new = FolderSnapshot(
            day: day, homeBytes: 99 * gigabyte, freeBytes: 94 * gigabyte,
            folders: ["Library": 75 * gigabyte, "Library/Caches": 7 * gigabyte, "Library/Messages": 16 * gigabyte,
                      "Library/Containers": 37 * gigabyte, "Library/Containers/com.docker.docker": 36 * gigabyte,
                      "code": 24 * gigabyte, "code/new-app": 4 * gigabyte],
            unmeasured: []
        )
        return (old, new)
    }

    @Test func leavesFirstMeasuredFoldersOutOfGrowth() {
        let (old, new) = accessGranted
        let top = FolderChanges.changes(from: old, to: new)
        #expect(top.map(\.path) == ["code", "Library"])
        #expect(top[1].delta == 2 * gigabyte)
        #expect(top[1].firstMeasuredBytes == 53 * gigabyte)

        let library = FolderChanges.changes(from: old, to: new, under: "Library")
        #expect(library.map(\.path) == ["Library/Caches", "Library/Containers", "Library/Messages"])
        #expect(library[0].delta == 2 * gigabyte)
        #expect(library[1].isFirstMeasured && !library[1].isNew && library[1].delta == 0)
        #expect(library[2].isFirstMeasured && library[2].newBytes == 16 * gigabyte)

        let docker = FolderChanges.changes(from: old, to: new, under: "Library/Containers")
        #expect(docker.map(\.isFirstMeasured) == [true])

        let code = FolderChanges.changes(from: old, to: new, under: "code")
        #expect(code.map(\.path) == ["code/new-app"])
        #expect(code[0].isNew && !code[0].isFirstMeasured && code[0].delta == 4 * gigabyte)
    }

    @Test func listsAFolderThatOnlyHoldsFirstMeasuredFoldersWithThem() {
        let old = FolderSnapshot(
            day: day, homeBytes: 30 * gigabyte, freeBytes: 0,
            folders: ["Library": 30 * gigabyte, "Downloads": 9 * gigabyte],
            unmeasured: ["Library/Metadata/CoreSpotlight"]
        )
        let new = FolderSnapshot(
            day: day, homeBytes: 34 * gigabyte, freeBytes: 0,
            folders: ["Library": 34 * gigabyte, "Library/Metadata": 4 * gigabyte,
                      "Library/Metadata/CoreSpotlight": 4 * gigabyte, "Downloads": 6 * gigabyte]
        )
        let top = FolderChanges.changes(from: old, to: new)
        #expect(top.map(\.path) == ["Downloads", "Library"])
        #expect(!top[0].listedForFirstMeasured)
        #expect(top[1].listedForFirstMeasured && top[1].firstMeasuredSize == 4 * gigabyte)
        let library = FolderChanges.changes(from: old, to: new, under: "Library")
        #expect(library.map(\.path) == ["Library/Metadata"])
        #expect(library[0].listedForFirstMeasured && !library[0].isFirstMeasured && !library[0].isNew)
    }

    @Test func leavesFirstMeasuredFoldersOutOfTheHomeFolderTotal() {
        let (old, new) = accessGranted
        // 6 GB more used, all of it the home folder's real growth: Caches and code/new-app.
        #expect(FolderChanges.outsideHomeDelta(from: old, to: new) == 0)
    }

    @Test func treatsFoldersMissingFromAnOlderSnapshotFormatAsFirstMeasured() throws {
        let json = #"{"day":"2026-10-01T07:00:00Z","folders":{"code":2000000000},"freeBytes":0,"homeBytes":0}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let old = try decoder.decode(FolderSnapshot.self, from: Data(json.utf8))
        #expect(old.unmeasured == nil)
        let new = FolderSnapshot(
            day: day, homeBytes: 0, freeBytes: 0,
            folders: ["code": 3 * gigabyte, "Library": 9 * gigabyte, "Library/Messages": 8 * gigabyte]
        )
        let top = FolderChanges.changes(from: old, to: new)
        #expect(top.map(\.path) == ["code", "Library"])
        #expect(top[0].delta == gigabyte)
        #expect(top[1].isFirstMeasured)
        let library = FolderChanges.changes(from: old, to: new, under: "Library")
        #expect(library.map(\.isFirstMeasured) == [true])
    }

    @Test func attributesGrowthOutsideTheHomeFolder() {
        let old = FolderSnapshot(day: day, homeBytes: 500 * gigabyte, freeBytes: 230 * gigabyte, folders: [:])
        let new = FolderSnapshot(day: day, homeBytes: 590 * gigabyte, freeBytes: 6 * gigabyte, folders: [:])
        // 224 GB more used, 90 GB of it in the home folder.
        #expect(FolderChanges.outsideHomeDelta(from: old, to: new) == 134 * gigabyte)
    }
}
