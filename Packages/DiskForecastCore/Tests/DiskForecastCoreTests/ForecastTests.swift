@testable import DiskForecastCore
import Foundation
import Testing

struct ForecastTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    let gigabyte: Int64 = 1_000_000_000

    private func history(freeGB: [Int64]) -> UsageHistory {
        var history = UsageHistory()
        for (offset, free) in freeGB.enumerated() {
            let date = calendar.date(byAdding: .day, value: offset - freeGB.count + 1, to: now)!
            history.record(freeBytes: free * gigabyte, capacityBytes: 1_000 * gigabyte, at: date, calendar: calendar)
        }
        return history
    }

    @Test func projectsASteadyDecline() throws {
        let days = try #require(Forecast.daysUntilFull(
            history: history(freeGB: [100, 98, 96, 94, 92]),
            currentFreeBytes: 92 * gigabyte, now: now, calendar: calendar
        ))
        #expect(abs(days - 46) < 0.01)
    }

    @Test func needsThreeDays() {
        let result = Forecast.daysUntilFull(
            history: history(freeGB: [100, 90]), currentFreeBytes: 90 * gigabyte, now: now, calendar: calendar
        )
        #expect(result == nil)
    }

    @Test func staysQuietWhenSpaceIsFlatOrGrowing() {
        #expect(Forecast.daysUntilFull(
            history: history(freeGB: [100, 100, 100, 100]),
            currentFreeBytes: 100 * gigabyte, now: now, calendar: calendar
        ) == nil)
        #expect(Forecast.daysUntilFull(
            history: history(freeGB: [90, 95, 100]), currentFreeBytes: 100 * gigabyte, now: now, calendar: calendar
        ) == nil)
    }

    @Test func ignoresSamplesOlderThanTheWindow() {
        // A big drop 60 days ago, flat since.
        var samples = history(freeGB: Array(repeating: 50, count: 20)).samples
        let old = calendar.date(byAdding: .day, value: -60, to: now)!
        samples.append(UsageSample(day: calendar.startOfDay(for: old), freeBytes: 500 * gigabyte, capacityBytes: 0))
        let result = Forecast.daysUntilFull(
            history: UsageHistory(samples: samples), currentFreeBytes: 50 * gigabyte, now: now, calendar: calendar
        )
        #expect(result == nil)
    }

    @Test func oneBigDropDoesNotSetTheTrend() {
        // A real Mac: a 220 GB drop in one day, then space slowly coming back.
        let result = Forecast.daysUntilFull(
            history: history(freeGB: [283, 271, 230, 6, 12, 13, 16, 19]),
            currentFreeBytes: 19 * gigabyte, now: now, calendar: calendar
        )
        #expect(result == nil)
    }

    @Test func keepsTheSteadyPaceAroundOneBigDrop() throws {
        let days = try #require(Forecast.daysUntilFull(
            history: history(freeGB: [100, 98, 96, 40, 38, 36]),
            currentFreeBytes: 36 * gigabyte, now: now, calendar: calendar
        ))
        #expect(abs(days - 18) < 0.01)
    }

    @Test func spreadsAChangeOverMissedDays() throws {
        // Readings two days apart still count as a 2 GB a day pace.
        var history = UsageHistory()
        for (offset, free) in [(-6, Int64(100)), (-4, 96), (-2, 92), (0, 88)] {
            let date = calendar.date(byAdding: .day, value: offset, to: now)!
            history.record(freeBytes: free * gigabyte, capacityBytes: 1_000 * gigabyte, at: date, calendar: calendar)
        }
        let rate = try #require(Forecast.bytesPerDay(history: history, now: now, calendar: calendar))
        #expect(abs(rate + 2 * Double(gigabyte)) < 1)
    }

    @Test func describesTheOutlook() {
        func outlook(_ freeGB: [Int64]) -> Forecast.Outlook {
            Forecast.outlook(
                history: history(freeGB: freeGB), currentFreeBytes: (freeGB.last ?? 0) * gigabyte,
                now: now, calendar: calendar
            )
        }
        #expect(outlook([100]) == .learning(daysToGo: 2))
        #expect(outlook([100, 100, 100]) == .steady)
        #expect(outlook([90, 95, 100]) == .gaining(bytesPerDay: 5 * Double(gigabyte)))
        #expect(outlook([100, 98, 96]) == .filling(daysUntilFull: 48, bytesPerDay: -2 * Double(gigabyte)))
    }

    @Test func callsARiseFromOneCleanupACleanupNotAPace() {
        // A nearly full disk, a gigabyte back here and there, then 70 GB cleared in one day.
        let outlook = Forecast.outlook(
            history: history(freeGB: [20, 18, 19, 20, 21, 91]), currentFreeBytes: 91 * gigabyte,
            now: now, calendar: calendar
        )
        #expect(outlook == .cleared(bytes: 70 * gigabyte))
    }

    @Test func keepsAPaceWhenSpaceComesBackOverSeveralDays() {
        // The rises after the big drop are spread out, so they are a pace, not one cleanup.
        let outlook = Forecast.outlook(
            history: history(freeGB: [283, 271, 230, 6, 12, 13, 16, 19]), currentFreeBytes: 19 * gigabyte,
            now: now, calendar: calendar
        )
        #expect(outlook == .gaining(bytesPerDay: Double(gigabyte)))
    }

    @Test func saysFreeSpaceIsSwingingWhenDaysMoveFarMoreThanTheTrend() {
        // A real two weeks: tens of gigabytes up and down, and about one gigabyte up on the typical day.
        let outlook = Forecast.outlook(
            history: history(freeGB: [92, 85, 115, 109, 51, 57, 58, 47, 12, 3, 14, 56, 57, 11, 19, 76]),
            currentFreeBytes: 76 * gigabyte, now: now, calendar: calendar
        )
        guard case .swinging(let typical) = outlook else {
            Issue.record("expected swinging, got \(outlook)")
            return
        }
        #expect(typical >= 5 * gigabyte)
    }

    @Test func stillWarnsWhenASwingingDiskIsFilling() {
        let outlook = Forecast.outlook(
            history: history(freeGB: [200, 160, 190, 140, 170, 120, 150, 100]), currentFreeBytes: 100 * gigabyte,
            now: now, calendar: calendar
        )
        guard case .filling = outlook else {
            Issue.record("expected filling, got \(outlook)")
            return
        }
    }

    @Test func keepsOrdinaryUseAsATrend() {
        // A gigabyte or two a day is ordinary use, however uneven.
        let outlook = Forecast.outlook(
            history: history(freeGB: [50, 52, 51, 53, 54, 56]), currentFreeBytes: 56 * gigabyte,
            now: now, calendar: calendar
        )
        guard case .gaining = outlook else {
            Issue.record("expected gaining, got \(outlook)")
            return
        }
    }

    @Test func flagsLowSpaceWhateverTheTrend() {
        #expect(Forecast.isLow(freeBytes: 17 * gigabyte, capacityBytes: 995 * gigabyte))
        #expect(Forecast.isLow(freeBytes: 15 * gigabyte, capacityBytes: 128 * gigabyte))
        #expect(!Forecast.isLow(freeBytes: 102 * gigabyte, capacityBytes: 995 * gigabyte))
    }

    @Test func phrasesDays() {
        #expect(Forecast.phrase(days: 0.4) == "Full within a day")
        #expect(Forecast.phrase(days: 41.2) == "Full in ~41 days")
        #expect(Forecast.phrase(days: 95) == "Full in ~3 months")
        #expect(Forecast.phrase(days: 2_000) == "Full in over 2 years")
    }
}

struct UsageHistoryTests {
    @Test func keepsOneSamplePerDay() {
        var history = UsageHistory()
        let morning = Date(timeIntervalSince1970: 1_790_000_000)
        history.record(freeBytes: 10, capacityBytes: 100, at: morning)
        history.record(freeBytes: 8, capacityBytes: 100, at: morning.addingTimeInterval(60))
        #expect(history.samples.count == 1)
        #expect(history.samples.first?.freeBytes == 8)
    }

    @Test func dropsSamplesOlderThanItKeeps() {
        var history = UsageHistory()
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        for day in 0..<200 {
            history.record(freeBytes: 1, capacityBytes: 1, at: start.addingTimeInterval(Double(day) * 86_400))
        }
        #expect(history.samples.count <= UsageHistory.keptDays + 1)
    }

    @Test func roundTripsThroughAFile() throws {
        var history = UsageHistory()
        history.record(freeBytes: 5, capacityBytes: 9, at: Date(timeIntervalSince1970: 1_790_000_000))
        let url = TestFolders.make("history").appendingPathExtension("json")
        try history.save(to: url)
        #expect(UsageHistory.load(from: url) == history)
        #expect(UsageHistory.load(from: url.appending(path: "missing")) == UsageHistory())
    }

    @Test func keepsTheDaysLowestReading() {
        var history = UsageHistory()
        let morning = Date(timeIntervalSince1970: 1_790_000_000)
        history.record(freeBytes: 10, capacityBytes: 100, at: morning)
        history.record(freeBytes: 2, capacityBytes: 100, at: morning.addingTimeInterval(60))
        history.record(freeBytes: 76, capacityBytes: 100, at: morning.addingTimeInterval(120))
        #expect(history.samples.first?.freeBytes == 76)
        #expect(history.samples.first?.lowestFreeBytes == 2)
    }

    @Test func aNewDayStartsItsOwnLow() {
        var history = UsageHistory()
        let morning = Date(timeIntervalSince1970: 1_790_000_000)
        history.record(freeBytes: 2, capacityBytes: 100, at: morning)
        history.record(freeBytes: 50, capacityBytes: 100, at: morning.addingTimeInterval(86_400))
        #expect(history.samples.map(\.lowestFreeBytes) == [2, 50])
    }

    @Test func aLowReadingLowersTheLowButNotTheReading() {
        var history = UsageHistory()
        let morning = Date(timeIntervalSince1970: 1_790_000_000)
        history.record(freeBytes: 40, capacityBytes: 100, at: morning)
        history.recordLow(freeBytes: 5, capacityBytes: 100, at: morning.addingTimeInterval(60))
        history.recordLow(freeBytes: 30, capacityBytes: 100, at: morning.addingTimeInterval(120))
        #expect(history.samples.count == 1)
        #expect(history.samples.first?.freeBytes == 40)
        #expect(history.samples.first?.lowestFreeBytes == 5)
    }

    @Test func aLowReadingOnADayWithNoReadingStartsOne() {
        var history = UsageHistory()
        let morning = Date(timeIntervalSince1970: 1_790_000_000)
        history.record(freeBytes: 40, capacityBytes: 100, at: morning)
        history.recordLow(freeBytes: 7, capacityBytes: 100, at: morning.addingTimeInterval(86_400))
        #expect(history.samples.count == 2)
        #expect(history.samples.last?.freeBytes == 7)
        #expect(history.samples.last?.lowestFreeBytes == 7)
    }

    @Test func aLowReadingCanLandOnAnEarlierDay() {
        var history = UsageHistory()
        let morning = Date(timeIntervalSince1970: 1_790_000_000)
        history.record(freeBytes: 40, capacityBytes: 100, at: morning)
        history.record(freeBytes: 45, capacityBytes: 100, at: morning.addingTimeInterval(86_400))
        history.recordLow(freeBytes: 3, capacityBytes: 100, at: morning.addingTimeInterval(60))
        #expect(history.samples.map(\.lowestFreeBytes) == [3, 45])
    }

    @Test func findsTheLowForADay() {
        var history = UsageHistory()
        let morning = Date(timeIntervalSince1970: 1_790_000_000)
        history.record(freeBytes: 40, capacityBytes: 100, at: morning)
        history.recordLow(freeBytes: 4, capacityBytes: 100, at: morning.addingTimeInterval(60))
        #expect(history.lowestFreeBytes(on: morning.addingTimeInterval(120)) == 4)
        #expect(history.lowestFreeBytes(on: morning.addingTimeInterval(86_400)) == nil)
    }

    @Test func savesALowOnlyWhenItDropsEnough() {
        let gigabyte: Int64 = 1_000_000_000
        #expect(UsageHistory.lowIsWorthSaving(70 * gigabyte, saved: nil))
        #expect(!UsageHistory.lowIsWorthSaving(70 * gigabyte, saved: 70 * gigabyte))
        #expect(!UsageHistory.lowIsWorthSaving(69 * gigabyte + 500_000_000, saved: 70 * gigabyte))
        #expect(UsageHistory.lowIsWorthSaving(69 * gigabyte, saved: 70 * gigabyte))
        // Near empty, a quarter of what's left counts, so the last gigabyte isn't lost.
        #expect(UsageHistory.lowIsWorthSaving(600_000_000, saved: 800_000_000))
        #expect(!UsageHistory.lowIsWorthSaving(700_000_000, saved: 800_000_000))
    }

    @Test func loadsAHistorySavedBeforeLowsWereKept() throws {
        let url = TestFolders.make("old-history").appendingPathExtension("json")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let json = """
        {"samples": [{"capacityBytes": 100, "day": "2026-09-21T07:00:00Z", "freeBytes": 42}]}
        """
        try Data(json.utf8).write(to: url)
        let history = UsageHistory.load(from: url)
        #expect(history.samples.count == 1)
        #expect(history.samples.first?.freeBytes == 42)
        #expect(history.samples.first?.lowestFreeBytes == 42)
    }

    @Test func savesTheLowAlongsideTheKeysOlderVersionsRead() throws {
        var history = UsageHistory()
        history.record(freeBytes: 2, capacityBytes: 100, at: Date(timeIntervalSince1970: 1_790_000_000))
        history.record(freeBytes: 9, capacityBytes: 100, at: Date(timeIntervalSince1970: 1_790_000_060))
        let url = TestFolders.make("new-history").appendingPathExtension("json")
        try history.save(to: url)
        let saved = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let sample = (saved?["samples"] as? [[String: Any]])?.first
        #expect(Set(sample?.keys.map { $0 } ?? []) == ["day", "freeBytes", "capacityBytes", "lowestFreeBytes"])
        #expect(sample?["freeBytes"] as? Int == 9)
        #expect(sample?["lowestFreeBytes"] as? Int == 2)
    }
}
