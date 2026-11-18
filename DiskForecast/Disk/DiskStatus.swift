import DiskForecastCore
import Foundation
import Observation

/// Free space on the startup disk, sampled every hour into a daily history for the forecast, and
/// every minute while space is low so a disk filling within minutes can be caught.
@MainActor
@Observable
final class DiskStatus {
    private(set) var capacityBytes: Int64 = 0
    /// What Finder calls available: free space plus what macOS can purge on demand.
    private(set) var freeBytes: Int64 = 0
    /// Space macOS is holding for caches and snapshots that it will give back when needed.
    private(set) var purgeableBytes: Int64 = 0
    private(set) var history: UsageHistory
    /// The last ten minutes of readings, kept only while space is low.
    private(set) var recentReadings: [FastFill.Reading] = []
    var onChange: (() -> Void)?

    private let historyURL: URL
    private var timer: Timer?
    private var lowSpaceTimer: Timer?

    init(supportFolder: URL) {
        historyURL = supportFolder.appending(path: "history.json")
        history = UsageHistory.load(from: historyURL)
    }

    var percentFree: Double {
        capacityBytes > 0 ? Double(freeBytes) / Double(capacityBytes) : 0
    }

    var outlook: Forecast.Outlook {
        Forecast.outlook(history: history, currentFreeBytes: freeBytes)
    }

    /// Where free space is heading, in words: "Full in ~41 days · using 3.5 GB a day".
    var forecastPhrase: String {
        switch outlook {
        case .learning(let days):
            "Forecast ready in \(days) day\(days == 1 ? "" : "s")"
        case .filling(let days, let bytesPerDay):
            "\(Forecast.phrase(days: days)) · using \(Bytes.format(Int64(-bytesPerDay))) a day"
        case .steady:
            "Steady · about the same free space each day"
        case .gaining(let bytesPerDay):
            "Free space growing ~\(Bytes.format(Int64(bytesPerDay))) a day"
        case .cleared(let bytes):
            "Free space up \(Bytes.format(bytes)) after a one-time jump"
        }
    }

    /// "Low on space: 2% free" when space is tight, whichever way it's heading.
    var lowSpaceWarning: String? {
        guard Forecast.isLow(freeBytes: freeBytes, capacityBytes: capacityBytes) else { return nil }
        return "Low on space: \(max(1, Int((percentFree * 100).rounded())))% free"
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3_600, repeats: true) { _ in
            MainActor.assumeIsolated { self.refresh() }
        }
        timer?.tolerance = 300
    }

    func refresh() {
        #if DEBUG
        if DemoMode.isOn {
            capacityBytes = Demo.capacityBytes
            freeBytes = Demo.freeBytes
            purgeableBytes = 6_000_000_000
            onChange?()
            return
        }
        #endif
        guard read() else { return }
        history.record(freeBytes: freeBytes, capacityBytes: capacityBytes, at: Date())
        try? history.save(to: historyURL)
        onChange?()
    }

    /// The minute check while space is low. Leaves the saved history to the hourly reading.
    private func refreshWhileLow() {
        guard read() else { return }
        onChange?()
    }

    /// Reads free space, a cheap volume query, and starts or stops the minute check to match.
    private func read() -> Bool {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey
        ]
        guard let values = try? URL(filePath: "/").resourceValues(forKeys: keys),
              let capacity = values.volumeTotalCapacity
        else { return false }
        let available = Int64(values.volumeAvailableCapacity ?? 0)
        let important = values.volumeAvailableCapacityForImportantUsage ?? available
        capacityBytes = Int64(capacity)
        freeBytes = important
        purgeableBytes = max(0, important - available)
        watchWhileLow()
        return true
    }

    private func watchWhileLow() {
        guard FastFill.shouldWatch(freeBytes: freeBytes, capacityBytes: capacityBytes) else {
            lowSpaceTimer?.invalidate()
            lowSpaceTimer = nil
            recentReadings = []
            return
        }
        recentReadings = FastFill.trimmed(recentReadings + [FastFill.Reading(date: Date(), freeBytes: freeBytes)])
        guard lowSpaceTimer == nil else { return }
        lowSpaceTimer = Timer.scheduledTimer(withTimeInterval: FastFill.checkInterval, repeats: true) { _ in
            MainActor.assumeIsolated { self.refreshWhileLow() }
        }
        lowSpaceTimer?.tolerance = 10
    }
}
