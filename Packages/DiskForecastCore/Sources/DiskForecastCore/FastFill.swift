import Foundation

/// Catches a disk filling within minutes, which the hourly reading and the two-week trend can't
/// see. While space is low, free space is read every minute and the last ten minutes decide.
public enum FastFill {
    /// Free space at one moment.
    public struct Reading: Sendable, Equatable {
        public var date: Date
        public var freeBytes: Int64

        public init(date: Date, freeBytes: Int64) {
            self.date = date
            self.freeBytes = freeBytes
        }
    }

    public static let checkInterval: TimeInterval = 60
    static let window: TimeInterval = 600
    /// Warn when the disk would be full within the hour at the recent pace.
    static let warnWithin: TimeInterval = 3_600
    /// A fall smaller than this is a download or a build that comes and goes, not a runaway.
    static let minimumFall: Int64 = 1_000_000_000
    static let quietPeriod: TimeInterval = 900

    /// Whether to read free space every minute: only while it's low, since that's when minutes count.
    public static func shouldWatch(freeBytes: Int64, capacityBytes: Int64) -> Bool {
        Forecast.isLow(freeBytes: freeBytes, capacityBytes: capacityBytes)
    }

    /// The readings from the last ten minutes, the only ones the rate looks at.
    public static func trimmed(_ readings: [Reading], now: Date = Date()) -> [Reading] {
        readings.filter { now.timeIntervalSince($0.date) <= window }
    }

    /// How fast free space fell over the readings, and when that pace fills the disk.
    public struct Warning: Sendable, Equatable {
        public var fellBytes: Int64
        public var seconds: TimeInterval
        public var freeBytes: Int64

        public init(fellBytes: Int64, seconds: TimeInterval, freeBytes: Int64) {
            self.fellBytes = fellBytes
            self.seconds = seconds
            self.freeBytes = freeBytes
        }

        public var secondsUntilFull: TimeInterval {
            Double(freeBytes) / (Double(fellBytes) / seconds)
        }

        public func message(trashBytes: Int64?) -> (title: String, body: String) {
            let spanMinutes = Int((seconds / 60).rounded())
            let span = spanMinutes <= 1 ? "the last minute" : "the last \(spanMinutes) minutes"
            let fullMinutes = Int((secondsUntilFull / 60).rounded())
            let full = switch fullMinutes {
            case ..<1: "within a minute"
            case 1: "in about a minute"
            default: "in about \(fullMinutes) minutes"
            }
            let body = "Free space fell \(Bytes.format(fellBytes)) in \(span); at this rate the disk is full \(full). "
                + DiskAlert.quickestSpace(trashBytes: trashBytes)
            return ("Your disk is filling fast: \(Bytes.format(freeBytes)) free", body)
        }
    }

    /// The warning to send now, if any: free space fell at least a gigabyte over the last ten
    /// minutes, is still falling, and at that pace runs out within the hour. Nothing goes out within
    /// fifteen minutes of the last warning.
    public static func due(readings: [Reading], lastSent: Date?, now: Date = Date()) -> Warning? {
        if let lastSent, now.timeIntervalSince(lastSent) < quietPeriod { return nil }
        let recent = trimmed(readings, now: now).sorted { $0.date < $1.date }
        guard recent.count >= 2, let first = recent.first, let last = recent.last else { return nil }
        let previous = recent[recent.count - 2]
        let fell = first.freeBytes - last.freeBytes
        let seconds = last.date.timeIntervalSince(first.date)
        guard last.freeBytes <= previous.freeBytes, fell >= minimumFall, seconds > 0 else { return nil }
        let warning = Warning(fellBytes: fell, seconds: seconds, freeBytes: max(0, last.freeBytes))
        return warning.secondsUntilFull <= warnWithin ? warning : nil
    }
}
