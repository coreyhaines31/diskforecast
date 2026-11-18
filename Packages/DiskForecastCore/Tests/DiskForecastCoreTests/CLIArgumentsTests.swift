@testable import DiskForecastCore
import Foundation
import Testing

struct CLIArgumentsTests {
    private func parse(_ line: String) throws(CLIUsageError) -> CLICommand {
        try CLIArguments.parse(line.split(separator: " ").map(String.init))
    }

    @Test func readsEachCommand() throws {
        #expect(try parse("status") == .send(CLIRequest(action: .status), json: false))
        #expect(try parse("cleanup --json") == .send(CLIRequest(action: .cleanup), json: true))
        #expect(try parse("changes") == .send(CLIRequest(action: .changes, days: 7), json: false))
        #expect(try parse("changes --days 30") == .send(CLIRequest(action: .changes, days: 30), json: false))
        #expect(try parse("scan --wait") == .send(CLIRequest(action: .scan), json: false, wait: true))
        #expect(try parse("undo --json") == .send(CLIRequest(action: .undo), json: true))
        #expect(try parse("open system-data") == .send(CLIRequest(action: .open, window: .systemData), json: false))
        #expect(try CLIArguments.parse([]) == .help)
        #expect(try parse("--version") == .version)
    }

    @Test func trashOnlyPreviewsWithoutYes() throws {
        #expect(try parse("trash logs ~/Downloads/big.dmg") == .send(
            CLIRequest(action: .trash, targets: ["logs", "~/Downloads/big.dmg"], confirmed: false), json: false
        ))
        #expect(try parse("trash logs --yes") == .send(
            CLIRequest(action: .trash, targets: ["logs"], confirmed: true), json: false
        ))
    }

    @Test func refusesWhatItDoesNotKnow() {
        #expect(throws: CLIUsageError.self) { try parse("forecast") }
        #expect(throws: CLIUsageError.self) { try parse("status --yes") }
        #expect(throws: CLIUsageError.self) { try parse("status extra") }
        #expect(throws: CLIUsageError.self) { try parse("changes --days") }
        #expect(throws: CLIUsageError.self) { try parse("changes --days 0") }
        #expect(throws: CLIUsageError.self) { try parse("trash") }
        #expect(throws: CLIUsageError.self) { try parse("open") }
        #expect(throws: CLIUsageError.self) { try parse("open finder") }
    }

    @Test func readsTheSpaceStatusShouldCheckFor() throws {
        #expect(try parse("status --need 5GB") == .send(
            CLIRequest(action: .status), json: false, needBytes: 5_000_000_000
        ))
        #expect(try parse("status --json --need 500mb") == .send(
            CLIRequest(action: .status), json: true, needBytes: 500_000_000
        ))
        #expect(throws: CLIUsageError.self) { try parse("status --need") }
        #expect(throws: CLIUsageError.self) { try parse("status --need lots") }
        #expect(throws: CLIUsageError.self) { try parse("cleanup --need 5GB") }
    }
}

struct BytesParseTests {
    @Test func readsSizesTheWayFinderCounts() {
        #expect(Bytes.parse("5GB") == 5_000_000_000)
        #expect(Bytes.parse("500MB") == 500_000_000)
        #expect(Bytes.parse("1.5tb") == 1_500_000_000_000)
        #expect(Bytes.parse("2G") == 2_000_000_000)
        #expect(Bytes.parse("750K") == 750_000)
        #expect(Bytes.parse("100B") == 100)
    }

    @Test func refusesWhatIsNotASize() {
        #expect(Bytes.parse("5") == nil)
        #expect(Bytes.parse("GB") == nil)
        #expect(Bytes.parse("-5GB") == nil)
        #expect(Bytes.parse("0GB") == nil)
        #expect(Bytes.parse("5XB") == nil)
        #expect(Bytes.parse("99999999999999999999TB") == nil)
    }
}

struct CLITrashTargetsTests {
    let home = "/Users/test"

    var items: [CleanupItem] {
        [
            CleanupItem(
                id: "logs", title: "Logs", explanation: "", group: .safeToClear, action: .trash,
                entries: [CleanupEntry(path: home + "/Library/Logs/a", bytes: 10)]
            ),
            CleanupItem(
                id: "downloads", title: "Big downloads", explanation: "", group: .worthALook, action: .trash,
                entries: [
                    CleanupEntry(path: home + "/Downloads/big.dmg", bytes: 20),
                    CleanupEntry(path: home + "/Downloads/movie.mov", bytes: 30)
                ]
            ),
            CleanupItem(
                id: "docker", title: "Docker disk image", explanation: "", group: .worthALook,
                action: .useTool("docker"),
                entries: [CleanupEntry(path: home + "/Library/Containers/docker", bytes: 40)]
            )
        ]
    }

    @Test func findsItemsByIDAndEntriesByPath() throws {
        let entries = try CLITrashTargets.entries(for: ["logs", "~/Downloads/big.dmg"], in: items, home: home)
        #expect(entries.map(\.path) == [home + "/Library/Logs/a", home + "/Downloads/big.dmg"])
    }

    @Test func countsAnEntryOnce() throws {
        let entries = try CLITrashTargets.entries(
            for: ["downloads", home + "/Downloads/big.dmg"], in: items, home: home
        )
        #expect(entries.count == 2)
    }

    @Test func refusesAnythingOffTheList() {
        #expect(throws: CLIUsageError.self) {
            try CLITrashTargets.entries(for: ["~/Documents"], in: items, home: home)
        }
        #expect(throws: CLIUsageError.self) {
            try CLITrashTargets.entries(for: ["docker"], in: items, home: home)
        }
    }
}

struct CLIChangesTests {
    @Test func nestsTheFoldersThatChanged() {
        let gigabyte: Int64 = 1_000_000_000
        let day = Date(timeIntervalSince1970: 1_790_000_000)
        let old = FolderSnapshot(
            day: day, homeBytes: 10 * gigabyte, freeBytes: 100 * gigabyte,
            folders: ["code": 4 * gigabyte, "code/api": 2 * gigabyte, "Movies": 6 * gigabyte]
        )
        let new = FolderSnapshot(
            day: day.addingTimeInterval(7 * 86_400), homeBytes: 13 * gigabyte, freeBytes: 95 * gigabyte,
            folders: ["code": 7 * gigabyte, "code/api": 5 * gigabyte, "Movies": 6 * gigabyte]
        )
        let changes = CLIChanges(from: old, to: new)
        #expect(changes.folders.map(\.path) == ["code"])
        #expect(changes.folders[0].children.map(\.path) == ["code/api"])
        #expect(changes.folders[0].delta == 3 * gigabyte)
        #expect(changes.outsideHomeBytes == 2 * gigabyte)
        #expect(changes.freeSpaceGap == nil)  // under 5 GB
    }

    @Test func changesExplainAFreeSpaceJumpTheHomeFolderDoesNotAccountFor() {
        let gigabyte: Int64 = 1_000_000_000
        let day = Date(timeIntervalSince1970: 1_790_000_000)
        let old = FolderSnapshot(day: day, homeBytes: 500 * gigabyte, freeBytes: 12 * gigabyte, folders: [:])
        let new = FolderSnapshot(
            day: day.addingTimeInterval(86_400), homeBytes: 491 * gigabyte, freeBytes: 82 * gigabyte, folders: [:]
        )
        let changes = CLIChanges(from: old, to: new)
        #expect(changes.freeSpaceGap?.hasPrefix("Free space rose 70 GB") == true)
    }

    @Test func marksFoldersMeasuredForTheFirstTime() {
        let gigabyte: Int64 = 1_000_000_000
        let day = Date(timeIntervalSince1970: 1_790_000_000)
        let old = FolderSnapshot(
            day: day, homeBytes: 20 * gigabyte, freeBytes: 100 * gigabyte, folders: ["Library": 20 * gigabyte],
            unmeasured: ["Library/Messages"]
        )
        let new = FolderSnapshot(
            day: day.addingTimeInterval(7 * 86_400), homeBytes: 37 * gigabyte, freeBytes: 99 * gigabyte,
            folders: ["Library": 37 * gigabyte, "Library/Messages": 16 * gigabyte]
        )
        let changes = CLIChanges(from: old, to: new)
        #expect(changes.folders.map(\.delta) == [gigabyte])
        #expect(changes.folders[0].firstMeasuredBytes == 16 * gigabyte)
        #expect(changes.folders[0].children.map(\.firstMeasured) == [true])
        #expect(changes.folders[0].children.map(\.listedForFirstMeasured) == [true])
        #expect(!changes.folders[0].listedForFirstMeasured)
        #expect(changes.outsideHomeBytes == 0)
    }
}

struct CLIHeadroomTests {
    let gigabyte: Int64 = 1_000_000_000

    private func status(freeGB: Int64, safeToClearGB: Int64 = 0) -> CLIStatus {
        CLIStatus(
            freeBytes: freeGB * gigabyte, capacityBytes: 995 * gigabyte, purgeableBytes: 0, outlook: "steady",
            forecast: "", daysUntilFull: nil, bytesPerDay: nil, lowOnSpace: false, scanning: false, lastScan: nil,
            fullDiskAccess: true, safeToClearBytes: safeToClearGB * gigabyte
        )
    }

    @Test func hasRoomWhenTheMarginIsLeftOver() {
        let headroom = CLIHeadroom(neededBytes: 5 * gigabyte, status: status(freeGB: 91, safeToClearGB: 36))
        #expect(headroom.hasRoom)
        #expect(headroom.shortBytes == 0)
        #expect(headroom.safeToClearBytes == 36 * gigabyte)
    }

    @Test func saysHowMuchToClearWhenTheMarginWouldBeGone() {
        let headroom = CLIHeadroom(neededBytes: 5 * gigabyte, status: status(freeGB: 22))
        #expect(!headroom.hasRoom)
        #expect(headroom.shortBytes == 3 * gigabyte)
        #expect(!CLIHeadroom(neededBytes: 100 * gigabyte, status: status(freeGB: 91)).hasRoom)
        #expect(CLIHeadroom(neededBytes: 5 * gigabyte, status: status(freeGB: 25)).hasRoom)
    }
}

struct CLIStatusLowTests {
    let gigabyte: Int64 = 1_000_000_000

    private func status(freeGB: Int64, lowGB: Int64?) -> CLIStatus {
        CLIStatus(
            freeBytes: freeGB * gigabyte, capacityBytes: 995 * gigabyte, purgeableBytes: 0, outlook: "steady",
            forecast: "", daysUntilFull: nil, bytesPerDay: nil, lowOnSpace: false, scanning: false, lastScan: nil,
            fullDiskAccess: true, safeToClearBytes: 0, lowestFreeBytesToday: lowGB.map { $0 * gigabyte }
        )
    }

    @Test func pointsOutTodaysLowOnlyWhenItWasWellBelowNow() {
        #expect(status(freeGB: 76, lowGB: 2).notableLowToday == 2 * gigabyte)
        #expect(status(freeGB: 76, lowGB: 76).notableLowToday == nil)
        #expect(status(freeGB: 76, lowGB: nil).notableLowToday == nil)
    }

    @Test func leavesOutADipThatIsSmallNextToFreeSpaceNow() {
        // Seen on a real Mac: a low of 80 GB against 82 GB free isn't worth a line.
        #expect(status(freeGB: 82, lowGB: 80).notableLowToday == nil)
        // 6 GB below, but under a tenth of what's free now.
        #expect(status(freeGB: 76, lowGB: 70).notableLowToday == nil)
        #expect(status(freeGB: 76, lowGB: 68).notableLowToday == 68 * gigabyte)
    }

    @Test func pointsOutASmallerDipThatReachedLowSpace() {
        #expect(status(freeGB: 22, lowGB: 18).notableLowToday == 18 * gigabyte)
        #expect(status(freeGB: 25, lowGB: 22).notableLowToday == nil)
        #expect(status(freeGB: 4, lowGB: 3).notableLowToday == 3 * gigabyte)
    }

    @Test func saysHowMuchOfFreeSpaceIsPurgeable() {
        var status = status(freeGB: 76, lowGB: nil)
        #expect(status.freeSpaceLine == "76 GB free of 995 GB (8% free)")
        status.purgeableBytes = 4_200_000_000
        #expect(status.freeSpaceLine == "76 GB free of 995 GB (8% free), 4.2 GB of it purgeable")
        status.purgeableBytes = 300_000_000
        #expect(status.freeSpaceLine == "76 GB free of 995 GB (8% free)")
    }

    @Test func readsAStatusFromAnAppWithoutTheLow() throws {
        let encoded = try JSONEncoder().encode(status(freeGB: 50, lowGB: nil))
        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "lowestFreeBytesToday")
        let decoded = try JSONDecoder().decode(CLIStatus.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.lowestFreeBytesToday == nil)
        #expect(decoded.freeBytes == 50 * gigabyte)
    }
}
