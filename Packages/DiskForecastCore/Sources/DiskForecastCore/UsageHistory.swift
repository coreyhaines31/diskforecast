import Foundation

/// How full the disk was on one day.
public struct UsageSample: Codable, Sendable, Equatable {
    /// Start of the day the sample belongs to.
    public var day: Date
    public var freeBytes: Int64
    public var capacityBytes: Int64

    public init(day: Date, freeBytes: Int64, capacityBytes: Int64) {
        self.day = day
        self.freeBytes = freeBytes
        self.capacityBytes = capacityBytes
    }
}

/// One sample per day, kept for a few months, so the forecast has a trend to follow.
public struct UsageHistory: Codable, Sendable, Equatable {
    public static let keptDays = 120

    public private(set) var samples: [UsageSample] = []

    public init(samples: [UsageSample] = []) {
        self.samples = samples.sorted { $0.day < $1.day }
    }

    /// Records the latest reading for its day, replacing an earlier one from the same day.
    public mutating func record(freeBytes: Int64, capacityBytes: Int64, at date: Date, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: date)
        let sample = UsageSample(day: day, freeBytes: freeBytes, capacityBytes: capacityBytes)
        if let last = samples.last, last.day == day {
            samples[samples.count - 1] = sample
        } else {
            samples.append(sample)
            samples.sort { $0.day < $1.day }
        }
        if let cutoff = calendar.date(byAdding: .day, value: -Self.keptDays, to: day) {
            samples.removeAll { $0.day < cutoff }
        }
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
