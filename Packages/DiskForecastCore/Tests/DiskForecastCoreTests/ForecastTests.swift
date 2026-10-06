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
        let url = FileManager.default.temporaryDirectory.appending(path: "history-\(UUID()).json")
        try history.save(to: url)
        #expect(UsageHistory.load(from: url) == history)
        #expect(UsageHistory.load(from: url.appending(path: "missing")) == UsageHistory())
    }
}
