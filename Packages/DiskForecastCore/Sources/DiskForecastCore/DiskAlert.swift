import Foundation

/// A notification worth sending before the disk fills, since the menu only warns when it's open.
public enum DiskAlert: String, Sendable, Equatable {
    /// The forecast says full within a week.
    case fillingSoon
    /// Under 10% or 20 GB free, whatever the trend.
    case low

    static let fillingSoonDays = 7.0
    static let quietPeriod: TimeInterval = 86_400

    /// The alert to send now, if any. A disk filling within the week comes first, and nothing goes
    /// out within a day of the last alert.
    public static func due(
        outlook: Forecast.Outlook, freeBytes: Int64, capacityBytes: Int64, lastSent: Date?, now: Date = Date()
    ) -> DiskAlert? {
        if let lastSent, now.timeIntervalSince(lastSent) < quietPeriod { return nil }
        if case .filling(let days, _) = outlook, days <= fillingSoonDays { return .fillingSoon }
        return Forecast.isLow(freeBytes: freeBytes, capacityBytes: capacityBytes) ? .low : nil
    }

    /// The notification's title and body: when the disk fills, what's driving it, and the
    /// quickest space to get back.
    public func message(
        outlook: Forecast.Outlook, freeBytes: Int64, grewMost: (name: String, bytes: Int64)?, trashBytes: Int64?
    ) -> (title: String, body: String) {
        var title = "Low on disk space: \(Bytes.format(freeBytes)) free"
        var body: [String] = []
        if case .filling(let days, let bytesPerDay) = outlook {
            if self == .fillingSoon {
                title = days < 1 ? "Your disk will be full within a day" : "Your disk will be full in about "
                    + (days < 1.5 ? "a day" : "\(Int(days.rounded())) days")
            }
            body.append("Using \(Bytes.format(Int64(-bytesPerDay))) a day.")
        }
        if let grewMost {
            body.append("\(grewMost.name) grew \(Bytes.format(grewMost.bytes)) this week.")
        }
        if let trashBytes, trashBytes >= 1_000_000_000 {
            body.append("Emptying the Trash gets back \(Bytes.format(trashBytes)).")
        } else {
            body.append("Open Cleanup to see what you can clear.")
        }
        return (title, body.joined(separator: " "))
    }
}
