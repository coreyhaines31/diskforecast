@testable import DiskForecastCore
import Foundation
import Testing

struct CriticalSpaceTests {
    let gigabyte: Int64 = 1_000_000_000

    func decide(_ gigabytes: Double, last: Int64? = nil) -> CriticalSpace.Decision {
        CriticalSpace.decide(freeBytes: Int64(gigabytes * 1e9), lastFloor: last)
    }

    @Test func saysNothingWithRoomToSpare() {
        #expect(decide(40) == .init(alert: nil, remembered: nil))
    }

    @Test func alertsOnceUnderFiveGigabytes() {
        #expect(decide(4.2) == .init(alert: 5 * gigabyte, remembered: 5 * gigabyte))
        #expect(decide(3.1, last: 5 * gigabyte) == .init(alert: nil, remembered: 5 * gigabyte))
    }

    @Test func alertsAgainUnderOneGigabyte() {
        #expect(decide(0.8, last: 5 * gigabyte) == .init(alert: gigabyte, remembered: gigabyte))
        #expect(decide(0.2, last: gigabyte) == .init(alert: nil, remembered: gigabyte))
    }

    @Test func aDiskThatStartsNearlyFullGetsTheSmallestFloor() {
        #expect(decide(0.5) == .init(alert: gigabyte, remembered: gigabyte))
    }

    @Test func hoveringAtAFloorDoesNotRepeatIt() {
        // Back over 5 GB, but not clear of it: still counted as warned.
        #expect(decide(5.4, last: 5 * gigabyte) == .init(alert: nil, remembered: 5 * gigabyte))
        #expect(decide(4.9, last: 5 * gigabyte) == .init(alert: nil, remembered: 5 * gigabyte))
        // Just over 1 GB after the 1 GB alert: still counted.
        #expect(decide(1.2, last: gigabyte) == .init(alert: nil, remembered: gigabyte))
    }

    @Test func aFloorIsWarnedAboutAgainAfterSpaceComesBack() {
        // Clear of 1 GB but not of 5 GB: the 1 GB alert can fire again, the 5 GB one can't.
        #expect(decide(3, last: gigabyte) == .init(alert: nil, remembered: 5 * gigabyte))
        #expect(decide(0.9, last: 5 * gigabyte).alert == gigabyte)
        // Clear of both: everything is armed again.
        #expect(decide(20, last: gigabyte) == .init(alert: nil, remembered: nil))
        #expect(decide(4, last: nil).alert == 5 * gigabyte)
    }

    @Test func theFloorUnderAReading() {
        #expect(CriticalSpace.floor(under: 6 * gigabyte) == nil)
        #expect(CriticalSpace.floor(under: 4 * gigabyte) == 5 * gigabyte)
        #expect(CriticalSpace.floor(under: 0) == gigabyte)
    }

    @Test func theMessageLeadsWithWhatIsLeftAndTheTrash() {
        let message = CriticalSpace.message(freeBytes: 800_000_000, trashBytes: 45 * gigabyte)
        #expect(message.title.hasPrefix("Almost out of disk space: "))
        #expect(message.body.contains("Emptying the Trash"))
        #expect(CriticalSpace.message(freeBytes: -5, trashBytes: nil).body.contains("Open Cleanup"))
    }
}
