import Foundation

/// When the disk will run out of space if it keeps filling at its recent pace.
public enum Forecast {
    public static let windowDays = 14
    public static let minimumDays = 3
    /// Less than 100 MB a day is noise, not a trend.
    static let noiseBytesPerDay = 100_000_000.0

    /// How much free space changes on a typical day lately: the median of the day-to-day changes
    /// over the last two weeks, so one big download or cleanup doesn't set the trend. Negative
    /// means the disk is filling. Nil without enough history.
    public static func bytesPerDay(
        history: UsageHistory,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Double? {
        guard let start = calendar.date(byAdding: .day, value: -windowDays, to: calendar.startOfDay(for: now)) else {
            return nil
        }
        let recent = history.samples.filter { $0.day >= start }
        guard recent.count >= minimumDays else { return nil }
        let rates = zip(recent, recent.dropFirst()).compactMap { earlier, later -> Double? in
            let days = later.day.timeIntervalSince(earlier.day) / 86_400
            guard days > 0 else { return nil }
            return Double(later.freeBytes - earlier.freeBytes) / days
        }.sorted()
        guard !rates.isEmpty else { return nil }
        let middle = rates.count / 2
        return rates.count.isMultiple(of: 2) ? (rates[middle - 1] + rates[middle]) / 2 : rates[middle]
    }

    /// Days until free space reaches zero at the recent pace. Nil without enough history, or
    /// when free space isn't shrinking.
    public static func daysUntilFull(
        history: UsageHistory,
        currentFreeBytes: Int64,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Double? {
        guard let rate = bytesPerDay(history: history, now: now, calendar: calendar),
              rate < -noiseBytesPerDay
        else { return nil }
        return Double(currentFreeBytes) / -rate
    }

    /// Which way free space is heading lately.
    public enum Outlook: Equatable, Sendable {
        /// Not enough readings yet; the forecast is ready after this many more days.
        case learning(daysToGo: Int)
        case filling(daysUntilFull: Double, bytesPerDay: Double)
        /// Changing by less than 100 MB on a typical day.
        case steady
        case gaining(bytesPerDay: Double)
        /// Free space went up, but mostly in one jump of gigabytes. Not a pace to plan on.
        case cleared(bytes: Int64)
        /// Free space goes up and down by gigabytes from day to day, far more than it moves overall,
        /// so the typical day says nothing about where it's heading.
        case swinging(typicalBytes: Int64)
    }

    public static func outlook(
        history: UsageHistory,
        currentFreeBytes: Int64,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Outlook {
        guard let rate = bytesPerDay(history: history, now: now, calendar: calendar) else {
            let start = calendar.date(byAdding: .day, value: -windowDays, to: calendar.startOfDay(for: now)) ?? now
            let days = history.samples.filter { $0.day >= start }.count
            return .learning(daysToGo: max(1, minimumDays - days))
        }
        if rate < -noiseBytesPerDay {
            return .filling(daysUntilFull: Double(currentFreeBytes) / -rate, bytesPerDay: rate)
        }
        // Never instead of a filling forecast: a warning that might be early beats none.
        if let swing = typicalSwing(history: history, now: now, calendar: calendar) {
            return .swinging(typicalBytes: swing)
        }
        guard rate > noiseBytesPerDay else { return .steady }
        if let cleared = oneDayRise(history: history, now: now, calendar: calendar) {
            return .cleared(bytes: cleared)
        }
        return .gaining(bytesPerDay: rate)
    }

    /// A day-to-day change smaller than this is ordinary use, not a swing.
    static let minimumSwingBytes: Int64 = 5_000_000_000
    /// How many big rises, and as many big falls, the window needs before it counts as swinging. One
    /// crash and a slow recovery is a trend; this is back and forth.
    static let minimumSwings = 3

    /// How far free space moves between readings on a typical day, when it keeps going both up and
    /// down by gigabytes: the median size of the changes in the window. Nil otherwise.
    static func typicalSwing(history: UsageHistory, now: Date, calendar: Calendar) -> Int64? {
        guard let start = calendar.date(byAdding: .day, value: -windowDays, to: calendar.startOfDay(for: now)) else {
            return nil
        }
        let recent = history.samples.filter { $0.day >= start }
        let changes = zip(recent, recent.dropFirst()).map { $1.freeBytes - $0.freeBytes }
        guard changes.filter({ $0 >= minimumSwingBytes }).count >= minimumSwings,
              changes.filter({ $0 <= -minimumSwingBytes }).count >= minimumSwings
        else { return nil }
        let sizes = changes.map(abs).sorted()
        return sizes[sizes.count / 2]
    }

    /// A rise smaller than this is ordinary use, not a one-time jump.
    static let minimumJumpBytes: Int64 = 5_000_000_000

    /// The biggest rise between two readings in the window, when it's at least `minimumJumpBytes` and
    /// more than all the other rises put together: free space came back in one go, not day by day.
    static func oneDayRise(history: UsageHistory, now: Date, calendar: Calendar) -> Int64? {
        guard let start = calendar.date(byAdding: .day, value: -windowDays, to: calendar.startOfDay(for: now)) else {
            return nil
        }
        let recent = history.samples.filter { $0.day >= start }
        let rises = zip(recent, recent.dropFirst()).map { $1.freeBytes - $0.freeBytes }.filter { $0 > 0 }
        guard let biggest = rises.max(), biggest >= minimumJumpBytes, biggest > rises.reduce(0, +) - biggest
        else { return nil }
        return biggest
    }

    /// Whether the disk is low on space whatever the trend: under 10% free, or under 20 GB.
    public static func isLow(freeBytes: Int64, capacityBytes: Int64) -> Bool {
        guard capacityBytes > 0 else { return false }
        return Double(freeBytes) < Double(capacityBytes) * 0.1 || freeBytes < 20_000_000_000
    }

    /// "Full in ~41 days", rounded the way people say it.
    public static func phrase(days: Double) -> String {
        switch days {
        case ..<1: "Full within a day"
        case ..<2: "Full in ~1 day"
        case ..<60: "Full in ~\(Int(days.rounded())) days"
        case ..<730: "Full in ~\(Int((days / 30).rounded())) months"
        default: "Full in over 2 years"
        }
    }
}
