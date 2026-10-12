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
