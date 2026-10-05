import Foundation

/// When the disk will run out of space if it keeps filling at its recent pace.
public enum Forecast {
    public static let windowDays = 30
    public static let minimumDays = 3

    /// Days until free space reaches zero, from a straight-line fit of the last 30 days of free
    /// space. Nil without enough history, or when free space isn't shrinking.
    public static func daysUntilFull(
        history: UsageHistory,
        currentFreeBytes: Int64,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Double? {
        guard let start = calendar.date(byAdding: .day, value: -windowDays, to: calendar.startOfDay(for: now)) else {
            return nil
        }
        let recent = history.samples.filter { $0.day >= start }
        guard recent.count >= minimumDays else { return nil }

        let points = recent.map { (x: $0.day.timeIntervalSince(start) / 86_400, y: Double($0.freeBytes)) }
        let count = Double(points.count)
        let meanX = points.map(\.x).reduce(0, +) / count
        let meanY = points.map(\.y).reduce(0, +) / count
        let covariance = points.map { ($0.x - meanX) * ($0.y - meanY) }.reduce(0, +)
        let variance = points.map { ($0.x - meanX) * ($0.x - meanX) }.reduce(0, +)
        guard variance > 0 else { return nil }
        let bytesPerDay = covariance / variance
        // Less than 100 MB a day is noise, not a trend.
        guard bytesPerDay < -100_000_000 else { return nil }
        return Double(currentFreeBytes) / -bytesPerDay
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
