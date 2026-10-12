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

    @Test func attributesGrowthOutsideTheHomeFolder() {
        let old = FolderSnapshot(day: day, homeBytes: 500 * gigabyte, freeBytes: 230 * gigabyte, folders: [:])
        let new = FolderSnapshot(day: day, homeBytes: 590 * gigabyte, freeBytes: 6 * gigabyte, folders: [:])
        // 224 GB more used, 90 GB of it in the home folder.
        #expect(FolderChanges.outsideHomeDelta(from: old, to: new) == 134 * gigabyte)
    }
}
