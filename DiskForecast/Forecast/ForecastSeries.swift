import DiskForecastCore
import Foundation

/// What a forecast chart draws: free space for each day in a range, and the line from today to
/// where the recent pace leads.
struct ForecastSeries {
    struct Point: Identifiable {
        let date: Date
        let gigabytes: Double
        var id: Date { date }
    }

    /// A day whose low was well below its last reading.
    struct Dip: Identifiable {
        let date: Date
        let low: Double
        let reading: Double
        var id: Date { date }
    }

    let history: [Point]
    let dips: [Dip]
    let projection: [Point]
    let bytesPerDay: Double?
    let fullDate: Date?
    let lowest: Point?
    let start: Date
    let end: Date

    /// - Parameter days: how far back the chart reaches. It looks ahead half as far, at least a
    ///   week, and stops early where the disk would be full.
    @MainActor
    init(disk: DiskStatus, days: Int, now: Date = Date(), calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let first = calendar.date(byAdding: .day, value: -days, to: today) ?? today
        let samples = disk.history.samples.filter { $0.day >= first }
        let points = samples.map { Point(date: $0.day, gigabytes: Self.gigabytes($0.freeBytes)) }
        // Start at the first reading when the history is shorter than the range, so the line
        // fills the chart instead of sitting in one corner.
        start = max(first, points.first?.date ?? first)
        history = points
        dips = samples
            .filter { $0.freeBytes - $0.lowestFreeBytes >= UsageHistory.notableDip }
            .map { Dip(date: $0.day, low: Self.gigabytes($0.lowestFreeBytes), reading: Self.gigabytes($0.freeBytes)) }
        lowest = samples
            .map { Point(date: $0.day, gigabytes: Self.gigabytes($0.lowestFreeBytes)) }
            .min { $0.gigabytes < $1.gigabytes }

        let rate = Forecast.bytesPerDay(history: disk.history, now: now, calendar: calendar)
        bytesPerDay = rate
        let horizon = calendar.date(byAdding: .day, value: max(7, days / 2), to: today) ?? today
        // Project from the last point drawn, so the dashed line starts where the solid one ends.
        if let rate, rate < -100_000_000, let last = points.last {
            let perDay = rate / 1_000_000_000
            let full = last.date.addingTimeInterval(last.gigabytes / -perDay * 86_400)
            fullDate = full
            let stop = max(last.date, min(full, horizon))
            let remaining = last.gigabytes + perDay * stop.timeIntervalSince(last.date) / 86_400
            projection = [last, Point(date: stop, gigabytes: max(0, remaining))]
        } else {
            fullDate = nil
            projection = []
        }
        end = projection.last?.date ?? max(today, points.last?.date ?? today)
    }

    /// "Last 30 days", or "Since Oct 5" while the history is shorter than that.
    func caption(days: Int) -> String {
        guard let first = history.first, let full = Calendar.current.date(byAdding: .day, value: -days, to: end),
              first.date > full
        else { return "Last \(days) days" }
        return "Since \(first.date.formatted(.dateTime.month(.abbreviated).day()))"
    }

    var peakGigabytes: Double {
        (history + projection).map(\.gigabytes).max() ?? 0
    }

    private static func gigabytes(_ bytes: Int64) -> Double {
        Double(bytes) / 1_000_000_000
    }
}
