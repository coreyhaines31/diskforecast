@testable import DiskForecastCore
import Foundation
import Testing

struct DiskAlertTests {
    let now = Date()
    let capacity: Int64 = 500_000_000_000

    @Test func warnsAWeekBeforeTheDiskFills() {
        let soon = Forecast.Outlook.filling(daysUntilFull: 5, bytesPerDay: -8e9)
        let later = Forecast.Outlook.filling(daysUntilFull: 30, bytesPerDay: -2e9)
        #expect(DiskAlert.due(outlook: soon, freeBytes: 40e9.int64, capacityBytes: capacity, lastSent: nil)
            == .fillingSoon)
        #expect(DiskAlert.due(outlook: later, freeBytes: 60e9.int64, capacityBytes: capacity, lastSent: nil)
            == nil)
    }

    @Test func warnsWhenLowWhateverTheTrend() {
        #expect(DiskAlert.due(outlook: .steady, freeBytes: 15e9.int64, capacityBytes: capacity, lastSent: nil) == .low)
    }

    @Test func waitsADayBetweenAlerts() {
        let recent = now.addingTimeInterval(-3_600)
        let yesterday = now.addingTimeInterval(-90_000)
        #expect(DiskAlert.due(outlook: .steady, freeBytes: 15e9.int64, capacityBytes: capacity, lastSent: recent)
            == nil)
        #expect(DiskAlert.due(outlook: .steady, freeBytes: 15e9.int64, capacityBytes: capacity, lastSent: yesterday)
            == .low)
    }

    @Test func namesWhatsDrivingItAndTheTrash() {
        let message = DiskAlert.fillingSoon.message(
            outlook: .filling(daysUntilFull: 3.2, bytesPerDay: -9e9), freeBytes: 29e9.int64,
            grewMost: ("~/.screenpipe", 41e9.int64), trashBytes: 12e9.int64
        )
        #expect(message.title == "Your disk will be full in about 3 days")
        #expect(message.body
            == "Using 9.0 GB a day. ~/.screenpipe grew 41 GB this week. Emptying the Trash gets back 12 GB.")
    }

    @Test func pointsToCleanupWithoutMuchInTheTrash() {
        let message = DiskAlert.low.message(outlook: .steady, freeBytes: 8e9.int64, grewMost: nil, trashBytes: 0)
        #expect(message.title == "Low on disk space: 8.0 GB free")
        #expect(message.body == "Open Cleanup to see what you can clear.")
    }
}

private extension Double {
    var int64: Int64 { Int64(self) }
}
