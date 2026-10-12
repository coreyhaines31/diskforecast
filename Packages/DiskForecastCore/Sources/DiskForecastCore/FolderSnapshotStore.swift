import Foundation

/// Keeps one folder snapshot a day as its own file (2026-10-12.json), for four months, and finds
/// the ones to compare.
public struct FolderSnapshotStore: Sendable {
    public static let keptDays = 120

    public let folder: URL
    private let calendar: Calendar

    public init(folder: URL, calendar: Calendar = .current) {
        self.folder = folder
        self.calendar = calendar
    }

    /// Saves the snapshot as its day's file, replacing an earlier one from the same day, and drops
    /// files older than four months.
    public func save(_ snapshot: FolderSnapshot) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let data = try JSONEncoder.snapshots.encode(snapshot)
        try data.write(to: folder.appending(path: fileName(for: snapshot.day)), options: .atomic)
        guard let cutoff = calendar.date(byAdding: .day, value: -Self.keptDays, to: snapshot.day) else { return }
        for (day, url) in files() where day < cutoff {
            try? FileManager.default.removeItem(at: url)
        }
    }

    public func latest() -> FolderSnapshot? {
        files().last.flatMap { load($0.url) }
    }

    /// The earliest snapshot from `date` on that's older than the latest one, to compare it with.
    public func baseline(since date: Date) -> FolderSnapshot? {
        let all = files()
        guard let latest = all.last else { return nil }
        let start = calendar.startOfDay(for: date)
        return all.first { $0.day >= start && $0.day < latest.day }.flatMap { load($0.url) }
    }

    private func files() -> [(day: Date, url: URL)] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return urls.compactMap { url -> (Date, URL)? in
            guard url.pathExtension == "json",
                  let day = dayFormatter.date(from: url.deletingPathExtension().lastPathComponent)
            else { return nil }
            return (day, url)
        }
        .sorted { $0.0 < $1.0 }
    }

    private func load(_ url: URL) -> FolderSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.snapshots.decode(FolderSnapshot.self, from: data)
    }

    private func fileName(for day: Date) -> String {
        dayFormatter.string(from: day) + ".json"
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

private extension JSONEncoder {
    static var snapshots: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var snapshots: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
