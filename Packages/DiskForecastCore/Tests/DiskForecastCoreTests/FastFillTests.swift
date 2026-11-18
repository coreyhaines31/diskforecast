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

    @Test func watchesOnlyWhileSpaceIsLow() {
        #expect(FastFill.shouldWatch(freeBytes: 12_000_000_000, capacityBytes: capacity))
        #expect(!FastFill.shouldWatch(freeBytes: 200_000_000_000, capacityBytes: capacity))
        #expect(!FastFill.shouldWatch(freeBytes: 0, capacityBytes: 0))
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
