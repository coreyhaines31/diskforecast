@testable import DiskForecastCore
import Foundation
import Testing

struct FastFillTests {
    let now = Date()
    let capacity: Int64 = 500_000_000_000

    /// One reading a minute, oldest first, ending now.
    func readings(_ freeGB: [Double]) -> [FastFill.Reading] {
        freeGB.enumerated().map { index, gigabytes in
            FastFill.Reading(
                date: now.addingTimeInterval(Double(index - freeGB.count + 1) * 60), freeBytes: Int64(gigabytes * 1e9)
            )
        }
    }

    /// Readings at the given minutes before now, oldest first.
    func readings(minutesAgo: [Double], freeGB: [Double]) -> [FastFill.Reading] {
        zip(minutesAgo, freeGB).map { minutes, gigabytes in
            FastFill.Reading(date: now.addingTimeInterval(-minutes * 60), freeBytes: Int64(gigabytes * 1e9))
        }
    }

    @Test func watchesEveryMinuteWhileSpaceIsLow() {
        #expect(FastFill.shouldWatch(readings: readings([12]), capacityBytes: capacity, now: now))
        #expect(!FastFill.shouldWatch(readings: readings([200]), capacityBytes: capacity, now: now))
        #expect(!FastFill.shouldWatch(readings: readings([0]), capacityBytes: 0, now: now))
        #expect(!FastFill.shouldWatch(readings: [], capacityBytes: capacity, now: now))
    }

    @Test func watchesEveryMinuteWhileFallingFastFromPlentyOfRoom() {
        // 256 GB disk, 30 GB free: 2.5 GB in five minutes fills it in an hour.
        let small: Int64 = 256_000_000_000
        let fast = readings(minutesAgo: [5, 0], freeGB: [32.5, 30])
        #expect(FastFill.shouldWatch(readings: fast, capacityBytes: small, now: now))
        // 0.9 GB in five minutes is under three hours away.
        let brisk = readings(minutesAgo: [5, 0], freeGB: [30.9, 30])
        #expect(FastFill.shouldWatch(readings: brisk, capacityBytes: small, now: now))
        // 0.5 GB in five minutes is five hours away: the five-minute reading keeps up.
        let slow = readings(minutesAgo: [5, 0], freeGB: [30.5, 30])
        #expect(!FastFill.shouldWatch(readings: slow, capacityBytes: small, now: now))
    }

    @Test func goesBackToFiveMinutesOnceTheFallStops() {
        let small: Int64 = 256_000_000_000
        // Fell fast, then held still for the last ten minutes.
        let stopped = readings(minutesAgo: [15, 10, 9, 5, 1, 0], freeGB: [40, 30, 30, 30, 30, 30])
        #expect(!FastFill.shouldWatch(readings: stopped, capacityBytes: small, now: now))
        let coming = readings(minutesAgo: [5, 0], freeGB: [30, 32])
        #expect(!FastFill.shouldWatch(readings: coming, capacityBytes: small, now: now))
    }

    @Test func keepsTheLastTenMinutes() {
        let kept = FastFill.trimmed(readings(Array(repeating: 12, count: 15)), now: now)
        #expect(kept.count == 11)
        #expect(kept.first?.date == now.addingTimeInterval(-600))
    }

    @Test func warnsWhenTheRecentFallWouldFillTheDiskSoon() throws {
        let falling = readings([20, 19.1, 18.2, 17.3, 16.4, 15.5, 14.6, 13.7, 12.8, 11.9, 11])
        let warning = try #require(FastFill.due(readings: falling, lastSent: nil, now: now))
        #expect(warning.fellBytes == 9_000_000_000)
        #expect(warning.seconds == 600)
        #expect((warning.secondsUntilFull / 60).rounded() == 12)
    }

    @Test func staysQuietWhenFreeSpaceIsSteadyOrSlowlyFalling() {
        #expect(FastFill.due(readings: readings([12, 12, 12, 12]), lastSent: nil, now: now) == nil)
        // 1.5 GB in ten minutes with 12 GB left is over an hour away.
        let slow = readings([13.5, 13.35, 13.2, 13.05, 12.9, 12.75, 12.6, 12.45, 12.3, 12.15, 12])
        #expect(FastFill.due(readings: slow, lastSent: nil, now: now) == nil)
    }

    @Test func ignoresSmallFallsAndTooFewReadings() {
        // 500 MB with 1 GB left is close, but small enough to be a download that comes and goes.
        #expect(FastFill.due(readings: readings([1.5, 1]), lastSent: nil, now: now) == nil)
        #expect(FastFill.due(readings: readings([5]), lastSent: nil, now: now) == nil)
    }

    @Test func warnsFromFiveMinuteReadingsAlone() throws {
        // A five-minute timer firing up to 30 seconds late still leaves two readings in the window.
        let fiveMinute = readings(minutesAgo: [10.5, 5.5, 0], freeGB: [40, 33, 30])
        let warning = try #require(FastFill.due(readings: fiveMinute, lastSent: nil, now: now))
        #expect(warning.fellBytes == 3_000_000_000)
        #expect(warning.seconds == 330)
    }

    @Test func warnsFromFiveMinuteAndMinuteReadingsTogether() throws {
        let mixed = readings(minutesAgo: [10, 5, 4, 3, 2, 1, 0], freeGB: [30, 27.5, 27, 26.5, 26, 25.5, 25])
        let warning = try #require(FastFill.due(readings: mixed, lastSent: nil, now: now))
        #expect(warning.fellBytes == 5_000_000_000)
        #expect(warning.seconds == 600)
        #expect((warning.secondsUntilFull / 60).rounded() == 50)
    }

    @Test func needsTheSameEvidenceWithMixedReadings() {
        // Under a gigabyte over the window, even though the last minute alone looks fast.
        let small = readings(minutesAgo: [5, 1, 0], freeGB: [10.8, 10.6, 10])
        #expect(FastFill.due(readings: small, lastSent: nil, now: now) == nil)
        // Fell 4 GB, but the last minute came back.
        let back = readings(minutesAgo: [5, 1, 0], freeGB: [14, 10, 10.5])
        #expect(FastFill.due(readings: back, lastSent: nil, now: now) == nil)
        // Eleven minutes of 6 GB a minute, but nothing within the window except the latest.
        #expect(FastFill.due(readings: readings(minutesAgo: [11, 0], freeGB: [90, 24]), lastSent: nil, now: now) == nil)
    }

    @Test func staysQuietWhenSpaceIsComingBack() {
        #expect(FastFill.due(readings: readings([20, 10, 15]), lastSent: nil, now: now) == nil)
    }

    @Test func waitsFifteenMinutesBetweenWarnings() {
        let falling = readings([10, 8, 6])
        #expect(FastFill.due(readings: falling, lastSent: now.addingTimeInterval(-600), now: now) == nil)
        #expect(FastFill.due(readings: falling, lastSent: now.addingTimeInterval(-900), now: now) != nil)
    }

    @Test func saysHowFastAndWhenItFills() {
        let warning = FastFill.Warning(fellBytes: 9_000_000_000, seconds: 600, freeBytes: 11_000_000_000)
        let message = warning.message(trashBytes: 3_000_000_000)
        #expect(message.title == "Your disk is filling fast: 11 GB free")
        #expect(message.body == "Free space fell 9.0 GB in the last 10 minutes; at this rate the disk is full in "
            + "about 12 minutes. Emptying the Trash gets back 3.0 GB.")
    }

    @Test func saysItPlainlyAtTheExtremes() {
        let message = FastFill.Warning(fellBytes: 4_000_000_000, seconds: 60, freeBytes: 500_000_000)
            .message(trashBytes: nil)
        #expect(message.body == "Free space fell 4.0 GB in the last minute; at this rate the disk is full "
            + "within a minute. Open Cleanup to see what you can clear.")
    }
}
