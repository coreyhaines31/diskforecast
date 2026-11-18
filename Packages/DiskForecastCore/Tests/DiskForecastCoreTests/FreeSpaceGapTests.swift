@testable import DiskForecastCore
import Foundation
import Testing

struct FreeSpaceGapTests {
    let gigabyte: Int64 = 1_000_000_000
    let day = Date(timeIntervalSince1970: 1_790_000_000)

    func snapshot(home: Int64, free: Int64, systemData: SystemDataReading? = nil) -> FolderSnapshot {
        FolderSnapshot(
            day: day, homeBytes: home * gigabyte, freeBytes: free * gigabyte, folders: [:], systemData: systemData
        )
    }

    @Test func staysQuietWhenTheHomeFolderExplainsTheChange() {
        let old = snapshot(home: 500, free: 12)
        let new = snapshot(home: 491, free: 22)
        #expect(FreeSpaceGap(from: old, to: new) == nil)
    }

    @Test func saysTheCauseIsUnknownWithoutSavedSystemData() throws {
        // Deleting 9 GB took free space from 12 GB to 82 GB.
        let old = snapshot(home: 500, free: 12)
        let new = snapshot(home: 491, free: 82)
        let gap = try #require(FreeSpaceGap(from: old, to: new))
        #expect(gap.outsideHomeBytes == -61 * gigabyte)
        #expect(gap.systemDataChanges.isEmpty)
        #expect(gap.statusNote(days: 7) == "In the last 7 days, 61 GB was freed outside your home folder, "
            + "more than scans explain. See: diskforecast changes --days 7")
        #expect(gap.explanation == "Free space rose 70 GB, while your home folder shrank 9.0 GB. "
            + "That leaves 61 GB freed outside your home folder, where scans don't look. "
            + "Disk Forecast didn't record System Data back then, so it can't say what changed. "
            + "It saves purgeable space and local Time Machine snapshots with each scan from now on.")
    }

    @Test func namesTheSystemDataThatChangedOverTheSamePeriod() throws {
        let old = snapshot(home: 500, free: 12, systemData: .init(purgeableBytes: 30 * gigabyte, localSnapshotCount: 6))
        let new = snapshot(home: 491, free: 82, systemData: .init(purgeableBytes: 12 * gigabyte, localSnapshotCount: 0))
        let gap = try #require(FreeSpaceGap(from: old, to: new))
        #expect(gap.systemDataChanges == [
            "purgeable space went from 30 GB to 12 GB", "local Time Machine snapshots went from 6 to 0"
        ])
        #expect(gap.explanation.hasSuffix(
            "Over the same period, purgeable space went from 30 GB to 12 GB, and local Time Machine snapshots "
                + "went from 6 to 0. That doesn't prove what caused it."
        ))
    }

    @Test func saysSoWhenTheSavedSystemDataDidNotChange() throws {
        let reading = SystemDataReading(purgeableBytes: 3 * gigabyte, localSnapshotCount: nil)
        let old = snapshot(home: 500, free: 80, systemData: reading)
        let new = snapshot(home: 502, free: 20, systemData: reading)
        let gap = try #require(FreeSpaceGap(from: old, to: new))
        #expect(gap.outsideHomeBytes == 58 * gigabyte)
        #expect(gap.explanation == "Free space fell 60 GB, while your home folder grew 2.0 GB. "
            + "That leaves 58 GB used outside your home folder, where scans don't look. "
            + "Purgeable space stayed about the same, so Disk Forecast can't say what changed.")
    }

    @Test func leavesFirstMeasuredFoldersOutOfTheHomeFoldersChange() throws {
        // The home folder's total rose 41 GB, but 21 GB of that is a folder the earlier scan couldn't read.
        let old = FolderSnapshot(
            day: day, homeBytes: 100 * gigabyte, freeBytes: 50 * gigabyte, folders: [:], unmeasured: ["Big"]
        )
        let new = FolderSnapshot(
            day: day, homeBytes: 141 * gigabyte, freeBytes: 100 * gigabyte, folders: ["Big": 21 * gigabyte]
        )
        let gap = try #require(FreeSpaceGap(from: old, to: new))
        #expect(gap.homeDelta == 20 * gigabyte)
        #expect(gap.outsideHomeBytes == -70 * gigabyte)
        #expect(gap.explanation.hasPrefix("Free space rose 50 GB, while your home folder grew 20 GB. "
            + "That leaves 70 GB freed outside your home folder"))
    }

    @Test func staysQuietAgainstASnapshotThatCannotSayWhatItMissed() throws {
        // Saved before unmeasured folders were recorded: Photos and Messages showing up for the first
        // time read as 109 GB of growth, which would be reported as 157 GB freed somewhere else.
        let json = #"{"day":"2026-11-10T08:00:00Z","folders":{},"freeBytes":12000000000,"homeBytes":500000000000}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let old = try decoder.decode(FolderSnapshot.self, from: Data(json.utf8))
        #expect(FreeSpaceGap(from: old, to: snapshot(home: 592, free: 76)) == nil)
    }

    @Test func oldSnapshotsWithoutSystemDataStillDecode() throws {
        let json = #"{"day":"2026-10-12T07:00:00Z","folders":{},"freeBytes":5,"homeBytes":9}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(FolderSnapshot.self, from: Data(json.utf8))
        #expect(snapshot.freeBytes == 5)
        #expect(snapshot.systemData == nil)
    }
}
