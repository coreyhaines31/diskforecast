import Foundation

/// How full the disk was on one day.
public struct UsageSample: Codable, Sendable, Equatable {
    /// Start of the day the sample belongs to.
    public var day: Date
    /// The day's last reading, which the forecast follows.
    public var freeBytes: Int64
    public var capacityBytes: Int64
    /// The least free space seen that day, from the hourly readings and the minute ones while space
    /// is low. Never more than `freeBytes`.
    public var lowestFreeBytes: Int64

    public init(day: Date, freeBytes: Int64, capacityBytes: Int64, lowestFreeBytes: Int64? = nil) {
        self.day = day
        self.freeBytes = freeBytes
        self.capacityBytes = capacityBytes
        self.lowestFreeBytes = min(lowestFreeBytes ?? freeBytes, freeBytes)
    }

    // History saved before lows were kept has no `lowestFreeBytes`: its low is the reading.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            day: try container.decode(Date.self, forKey: .day),
            freeBytes: try container.decode(Int64.self, forKey: .freeBytes),
            capacityBytes: try container.decode(Int64.self, forKey: .capacityBytes),
            lowestFreeBytes: try container.decodeIfPresent(Int64.self, forKey: .lowestFreeBytes)
        )
    }
}

/// One sample per day, kept for a few months, so the forecast has a trend to follow.
public struct UsageHistory: Codable, Sendable, Equatable {
    public static let keptDays = 120

    public private(set) var samples: [UsageSample] = []

    public init(samples: [UsageSample] = []) {
        self.samples = samples.sorted { $0.day < $1.day }
    }

    /// Records the latest reading for its day, replacing an earlier one from the same day but keeping
    /// the day's low.
    public mutating func record(freeBytes: Int64, capacityBytes: Int64, at date: Date, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: date)
        if let index = samples.lastIndex(where: { $0.day == day }) {
            samples[index] = UsageSample(
                day: day, freeBytes: freeBytes, capacityBytes: capacityBytes,
                lowestFreeBytes: samples[index].lowestFreeBytes
            )
        } else {
            samples.append(UsageSample(day: day, freeBytes: freeBytes, capacityBytes: capacityBytes))
            samples.sort { $0.day < $1.day }
        }
        if let cutoff = calendar.date(byAdding: .day, value: -Self.keptDays, to: day) {
            samples.removeAll { $0.day < cutoff }
        }
    }

    /// Lowers the day's low without changing its reading, for the minute checks while space is low.
    /// A day with no reading yet starts with this one.
    public mutating func recordLow(
        freeBytes: Int64, capacityBytes: Int64, at date: Date, calendar: Calendar = .current
    ) {
        let day = calendar.startOfDay(for: date)
        guard let index = samples.lastIndex(where: { $0.day == day }) else {
            record(freeBytes: freeBytes, capacityBytes: capacityBytes, at: date, calendar: calendar)
            return
        }
        samples[index].lowestFreeBytes = min(samples[index].lowestFreeBytes, freeBytes)
    }

    /// The low for the day `date` falls in, when there's a reading that day.
    public func lowestFreeBytes(on date: Date, calendar: Calendar = .current) -> Int64? {
        let day = calendar.startOfDay(for: date)
        return samples.last { $0.day == day }?.lowestFreeBytes
    }

    /// How far below the day's reading its low has to be before it's worth pointing out.
    public static let notableDip: Int64 = 1_000_000_000

    /// Whether a new low is far enough below the one last saved to write the file again: by a
    /// gigabyte, or by a quarter of the saved low when that's less, so a disk running out of its
    /// last gigabyte still has its low saved.
    public static func lowIsWorthSaving(_ low: Int64, saved: Int64?) -> Bool {
        guard let saved else { return true }
        return saved - low >= min(notableDip, saved / 4)
    }

    /// The saved history, or an empty one when there's none yet.
    public static func load(from url: URL) -> UsageHistory {
        guard let data = try? Data(contentsOf: url),
              let history = try? JSONDecoder.history.decode(UsageHistory.self, from: data)
        else { return UsageHistory() }
        return history
    }

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder.history.encode(self).write(to: url, options: .atomic)
    }
}

private extension JSONEncoder {
    static var history: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var history: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
