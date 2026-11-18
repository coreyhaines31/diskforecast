@testable import DiskForecastCore
import Foundation
import Testing

struct FolderChurnTests {
    let gigabyte: Int64 = 1_000_000_000
    let start = Date(timeIntervalSince1970: 1_790_000_000)

    /// One snapshot a day, each holding the folders given for it and, unless `steady` is false, a
    /// Music folder that never changes, so no snapshot is empty. A nil in `unmeasured` makes that day an old
    /// snapshot, saved before unmeasured folders were recorded.
    func snapshots(_ days: [[String: Int64]], unmeasured: [[String]?]? = nil, steady: Bool = true) -> [FolderSnapshot] {
        days.enumerated().map { index, folders in
            FolderSnapshot(
                day: start.addingTimeInterval(Double(index) * 86_400), homeBytes: 0, freeBytes: 0,
                folders: steady ? folders.merging(["Music": 5 * gigabyte]) { $1 } : folders,
                unmeasured: unmeasured.map { $0[index] } ?? []
            )
        }
    }

    @Test func addsUpMovementBothWaysAndKeepsTheNetChange() {
        let window = snapshots([
            ["code": 10 * gigabyte], ["code": 40 * gigabyte], ["code": 12 * gigabyte], ["code": 30 * gigabyte]
        ])
        let churn = FolderChurns.churn(in: window)
        #expect(churn == [FolderChurn(path: "code", movedBytes: 76 * gigabyte, netBytes: 20 * gigabyte)])
        #expect(churn.first?.backAndForthBytes == 56 * gigabyte)
    }

    @Test func needsThreeSnapshots() {
        let window = snapshots([["code": 10 * gigabyte], ["code": 40 * gigabyte]])
        #expect(FolderChurns.churn(in: window).isEmpty)
        #expect(FolderChurns.churn(in: []).isEmpty)
    }

    @Test func leavesOutFoldersThatOnlyGrewOrOnlyShrank() {
        let window = snapshots([
            ["Movies": 10 * gigabyte, "Downloads": 20 * gigabyte],
            ["Movies": 20 * gigabyte, "Downloads": 15 * gigabyte],
            ["Movies": 30 * gigabyte, "Downloads": 5 * gigabyte]
        ])
        #expect(FolderChurns.churn(in: window).isEmpty)
    }

    @Test func ignoresStepsUnder500MB() {
        let window = snapshots([
            ["code": 10 * gigabyte], ["code": 10 * gigabyte + 400_000_000],
            ["code": 10 * gigabyte], ["code": 10 * gigabyte + 400_000_000]
        ])
        #expect(FolderChurns.churn(in: window).isEmpty)
    }

    @Test func aFolderAScanCouldNotReadAddsNothing() {
        // Day 2 couldn't read Library, so Library/Mail is absent but wasn't emptied.
        let window = snapshots(
            [["Library/Mail": 30 * gigabyte], [:], ["Library/Mail": 30 * gigabyte], ["Library/Mail": 31 * gigabyte]],
            unmeasured: [[], ["Library"], [], []]
        )
        #expect(FolderChurns.churn(in: window).isEmpty)
    }

    @Test func comparesWithTheLastScanThatMeasuredTheFolder() {
        let window = snapshots(
            [["Library/Mail": 30 * gigabyte], [:], ["Library/Mail": 10 * gigabyte], ["Library/Mail": 30 * gigabyte]],
            unmeasured: [[], ["Library"], [], []]
        )
        #expect(FolderChurns.churn(in: window) == [
            FolderChurn(path: "Library/Mail", movedBytes: 40 * gigabyte, netBytes: 0)
        ])
    }

    @Test func skipsAScanThatRecordedNoFolders() {
        // An old snapshot with nothing in it can't say it missed everything, but it did.
        let window = snapshots(
            [["code": 30 * gigabyte], [:], ["code": 30 * gigabyte], ["code": 31 * gigabyte]],
            unmeasured: [nil, nil, nil, nil], steady: false
        )
        #expect(FolderChurns.churn(in: window).isEmpty)
        #expect(FolderChurns.churn(in: Array(window.prefix(3))).isEmpty)
    }

    @Test func aFolderFirstMeasuredPartWayThroughStartsFromItsSize() {
        let window = snapshots(
            [[:], ["Library/Mail": 30 * gigabyte], ["Library/Mail": 30 * gigabyte]],
            unmeasured: [["Library"], [], []]
        )
        #expect(FolderChurns.churn(in: window).isEmpty)
    }

    @Test func inOldSnapshotsAFolderThatAppearsCountsOnlyIfItMovesAgain() {
        let appears = snapshots(
            [[:], ["code/app": 20 * gigabyte], ["code/app": 20 * gigabyte]], unmeasured: [nil, nil, nil]
        )
        #expect(FolderChurns.churn(in: appears).isEmpty)

        // Counting starts at 20 GB on day 2: down 20 to nothing on day 3, then up 18 on day 4.
        let comesAndGoes = snapshots(
            [[:], ["code/app": 20 * gigabyte], [:], ["code/app": 18 * gigabyte]], unmeasured: [nil, nil, nil, nil]
        )
        #expect(FolderChurns.churn(in: comesAndGoes) == [
            FolderChurn(path: "code/app", movedBytes: 38 * gigabyte, netBytes: -2 * gigabyte)
        ])
    }

    @Test func inOldSnapshotsAFolderFirstSeenPartWayThroughStartsFromItsSize() {
        // Seen at 30 GB on day 2, then 10 and 30: only the 40 GB after it was first seen counts.
        let window = snapshots(
            [[:], ["code/app": 30 * gigabyte], ["code/app": 10 * gigabyte], ["code/app": 30 * gigabyte]],
            unmeasured: [nil, nil, nil, nil]
        )
        #expect(FolderChurns.churn(in: window) == [
            FolderChurn(path: "code/app", movedBytes: 40 * gigabyte, netBytes: 0)
        ])
    }

    @Test func inNewSnapshotsAFolderThatAppearsStillCountsFromNothing() {
        // A scan that measured the whole home folder and didn't find code/app means it wasn't there.
        let window = snapshots([[:], ["code/app": 30 * gigabyte], ["code/app": 10 * gigabyte]])
        #expect(FolderChurns.churn(in: window) == [
            FolderChurn(path: "code/app", movedBytes: 50 * gigabyte, netBytes: 10 * gigabyte)
        ])
    }

    @Test func listsTheFolderInsideThatDoesMostOfTheMovingInsteadOfItsParents() {
        let window = snapshots([
            ["code": 50 * gigabyte, "code/app": 30 * gigabyte, "code/app/.next": 20 * gigabyte],
            ["code": 80 * gigabyte, "code/app": 60 * gigabyte, "code/app/.next": 50 * gigabyte],
            ["code": 52 * gigabyte, "code/app": 32 * gigabyte, "code/app/.next": 21 * gigabyte]
        ])
        #expect(FolderChurns.churn(in: window).map(\.path) == ["code/app/.next"])
    }

    @Test func listsTheParentWhenNoFolderInsideItDoesMostOfTheMoving() {
        // Caches and Developer each move a little; together Library moves a lot.
        let window = snapshots([
            ["Library": 100 * gigabyte, "Library/Caches": 10 * gigabyte, "Library/Developer": 10 * gigabyte,
             "Library/Logs": 5 * gigabyte],
            ["Library": 120 * gigabyte, "Library/Caches": 18 * gigabyte, "Library/Developer": 18 * gigabyte,
             "Library/Logs": 9 * gigabyte],
            ["Library": 100 * gigabyte, "Library/Caches": 10 * gigabyte, "Library/Developer": 10 * gigabyte,
             "Library/Logs": 5 * gigabyte]
        ])
        #expect(FolderChurns.churn(in: window).map(\.path) == ["Library"])
    }

    @Test func listsTheFoldersInsideThatMovedMostUnderTheirParent() {
        let window = snapshots([
            ["Library": 100 * gigabyte, "Library/Caches": 10 * gigabyte, "Library/Developer": 10 * gigabyte,
             "Library/Logs": 5 * gigabyte],
            ["Library": 120 * gigabyte, "Library/Caches": 18 * gigabyte, "Library/Developer": 18 * gigabyte,
             "Library/Logs": 9 * gigabyte],
            ["Library": 100 * gigabyte, "Library/Caches": 10 * gigabyte, "Library/Developer": 10 * gigabyte,
             "Library/Logs": 5 * gigabyte]
        ])
        let library = FolderChurns.churn(in: window).first
        #expect(library?.inside == [
            FolderChurn(path: "Library/Caches", movedBytes: 16 * gigabyte, netBytes: 0),
            FolderChurn(path: "Library/Developer", movedBytes: 16 * gigabyte, netBytes: 0),
            FolderChurn(path: "Library/Logs", movedBytes: 8 * gigabyte, netBytes: 0)
        ])
    }

    @Test func listsAtMostThreeFoldersInside() {
        let names = ["a", "b", "c", "d"]
        let low = Dictionary(uniqueKeysWithValues: names.map { ("code/\($0)", 10 * gigabyte) })
        let high = Dictionary(uniqueKeysWithValues: names.map { ("code/\($0)", 15 * gigabyte) })
        let window = snapshots([
            low.merging(["code": 50 * gigabyte]) { $1 }, high.merging(["code": 70 * gigabyte]) { $1 },
            low.merging(["code": 50 * gigabyte]) { $1 }
        ])
        #expect(FolderChurns.churn(in: window).first?.inside.map(\.path) == ["code/a", "code/b", "code/c"])
    }

    @Test func listsADeeperFolderInsideInsteadOfItsParentWhenItDoesMostOfThatMoving() {
        // Neither app nor .next does half of what code does, but .next does most of what app does.
        let window = snapshots([
            ["code": 50 * gigabyte, "code/app": 20 * gigabyte, "code/app/.next": 5 * gigabyte,
             "code/site": 10 * gigabyte],
            ["code": 90 * gigabyte, "code/app": 35 * gigabyte, "code/app/.next": 18 * gigabyte,
             "code/site": 20 * gigabyte],
            ["code": 50 * gigabyte, "code/app": 20 * gigabyte, "code/app/.next": 5 * gigabyte,
             "code/site": 10 * gigabyte]
        ])
        let code = FolderChurns.churn(in: window).first
        #expect(code?.path == "code")
        #expect(code?.inside.map(\.path) == ["code/app/.next", "code/site"])
    }

    @Test func leavesOutFoldersInsideThatMovedLittleOrOnlyOneWay() {
        // Logs moved back and forth under a twentieth of what Library did; Movies only grew.
        let window = snapshots([
            ["Library": 100 * gigabyte, "Library/Caches": 10 * gigabyte, "Library/Logs": 5 * gigabyte,
             "Library/Movies": 10 * gigabyte],
            ["Library": 130 * gigabyte, "Library/Caches": 20 * gigabyte, "Library/Logs": 6 * gigabyte,
             "Library/Movies": 15 * gigabyte],
            ["Library": 105 * gigabyte, "Library/Caches": 10 * gigabyte, "Library/Logs": 5 * gigabyte,
             "Library/Movies": 20 * gigabyte]
        ])
        let library = FolderChurns.churn(in: window).first
        #expect(library?.path == "Library")
        #expect(library?.inside.map(\.path) == ["Library/Caches"])
    }

    @Test func ranksByHowMuchMovedBackAndForth() {
        let window = snapshots([
            ["code": 10 * gigabyte, "Downloads": 10 * gigabyte],
            ["code": 15 * gigabyte, "Downloads": 40 * gigabyte],
            ["code": 10 * gigabyte, "Downloads": 10 * gigabyte]
        ])
        #expect(FolderChurns.churn(in: window).map(\.path) == ["Downloads", "code"])
    }

    @Test func describesTheMovementInPlainWords() {
        let grew = FolderChurn(path: "code/app/.next", movedBytes: 41 * gigabyte, netBytes: 12 * gigabyte)
        #expect(grew.summary(days: 9) == "moved 41 GB over 9 days, ended 12 GB up")
        let down = FolderChurn(path: "code", movedBytes: 41 * gigabyte, netBytes: -30 * gigabyte)
        #expect(down.summary(days: 1) == "moved 41 GB over 1 day, ended 30 GB down")
        let even = FolderChurn(path: "code", movedBytes: 41 * gigabyte, netBytes: 0)
        #expect(even.summary(days: 9) == "moved 41 GB over 9 days, ended about where it started")
    }
}
