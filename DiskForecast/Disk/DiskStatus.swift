import DiskForecastCore
import Foundation
import Observation

/// Free space on the startup disk, sampled every hour into a daily history for the forecast.
@MainActor
@Observable
final class DiskStatus {
    private(set) var capacityBytes: Int64 = 0
    /// What Finder calls available: free space plus what macOS can purge on demand.
    private(set) var freeBytes: Int64 = 0
    /// Space macOS is holding for caches and snapshots that it will give back when needed.
    private(set) var purgeableBytes: Int64 = 0
    private(set) var history: UsageHistory
    var onChange: (() -> Void)?

    private let historyURL: URL
    private var timer: Timer?

    init(supportFolder: URL) {
        historyURL = supportFolder.appending(path: "history.json")
        history = UsageHistory.load(from: historyURL)
    }

    var percentFree: Double {
        capacityBytes > 0 ? Double(freeBytes) / Double(capacityBytes) : 0
    }

    var daysUntilFull: Double? {
        Forecast.daysUntilFull(history: history, currentFreeBytes: freeBytes)
    }

    var forecastPhrase: String {
        if let days = daysUntilFull { return Forecast.phrase(days: days) }
        let recentDays = history.samples.filter { $0.day > Date().addingTimeInterval(-30 * 86_400) }.count
        if recentDays < Forecast.minimumDays {
            return "Forecast ready after \(Forecast.minimumDays) days of history"
        }
        return "Not filling up"
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3_600, repeats: true) { _ in
            MainActor.assumeIsolated { self.refresh() }
        }
        timer?.tolerance = 300
    }

    func refresh() {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey
        ]
        guard let values = try? URL(filePath: "/").resourceValues(forKeys: keys),
              let capacity = values.volumeTotalCapacity
        else { return }
        let available = Int64(values.volumeAvailableCapacity ?? 0)
        let important = values.volumeAvailableCapacityForImportantUsage ?? available
        capacityBytes = Int64(capacity)
        freeBytes = important
        purgeableBytes = max(0, important - available)
        history.record(freeBytes: freeBytes, capacityBytes: capacityBytes, at: Date())
        try? history.save(to: historyURL)
        onChange?()
    }
}
