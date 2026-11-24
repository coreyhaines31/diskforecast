@testable import DiskForecastCore
import Testing

struct FreedSpaceTests {
    private let gigabyte: Int64 = 1_000_000_000

    @Test func saysWhatCameBackWhenItMatchesTheSizes() {
        let freed = FreedSpace(estimate: 30 * gigabyte, before: 80 * gigabyte, after: 109 * gigabyte)
        #expect(!freed.fellShort)
        #expect(freed.summary == "29 GB is free again.")
    }

    @Test func explainsWhenLessCameBackThanTheSizesPromised() {
        let freed = FreedSpace(estimate: 30 * gigabyte, before: 80 * gigabyte, after: 94 * gigabyte)
        #expect(freed.fellShort)
        #expect(freed.summary == "14 GB is free again, of the 30 GB removed. The rest is shared with files "
            + "that stayed or kept by a snapshot, or macOS is still releasing it.")
    }

    @Test func explainsWhenNothingCameBack() {
        // Something else wrote more than the deletion freed.
        let freed = FreedSpace(estimate: 30 * gigabyte, before: 80 * gigabyte, after: 79 * gigabyte)
        #expect(freed.gained == 0)
        #expect(freed.summary == "Free space hasn't grown yet. What was removed is shared with files that "
            + "stayed or kept by a snapshot, or macOS is still releasing it.")
    }

    @Test func doesNotCompareSmallDeletions() {
        let freed = FreedSpace(estimate: 200_000_000, before: 80 * gigabyte, after: 80 * gigabyte)
        #expect(!freed.fellShort)
        #expect(freed.summary == "The space is free now.")
    }

    @Test func reportsTheGainWhenSizesWereNotMeasured() {
        let freed = FreedSpace(estimate: nil, before: 80 * gigabyte, after: 85 * gigabyte)
        #expect(freed.summary == "5.0 GB is free again.")
    }
}
