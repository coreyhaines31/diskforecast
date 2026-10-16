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
    }
}
