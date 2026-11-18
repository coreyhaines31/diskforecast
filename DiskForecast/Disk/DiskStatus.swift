import DiskForecastCore
import Foundation
import Observation

/// Free space on the startup disk, sampled every hour into a daily history for the forecast. Between
/// those it's read every five minutes, and every minute while space is low or falling fast, so a disk
/// filling within minutes can be caught and the day's low is kept.
@MainActor
@Observable
final class DiskStatus {
    private(set) var capacityBytes: Int64 = 0
    /// What Finder calls available: free space plus what macOS can purge on demand.
    private(set) var freeBytes: Int64 = 0
    /// Space macOS is holding for caches and snapshots that it will give back when needed.
    private(set) var purgeableBytes: Int64 = 0
    private(set) var history: UsageHistory
    /// The last ten minutes of readings.
    private(set) var recentReadings: [FastFill.Reading] = []
    var onChange: (() -> Void)?

    private let historyURL: URL
    /// Today's low as last written to the history file, so the minute checks save only when it drops.
    @ObservationIgnored private var savedLow: (day: Date, bytes: Int64)?
    private var timer: Timer?
    private var backgroundTimer: Timer?
    private var minuteTimer: Timer?

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
        case .swinging(let bytes):
            "Free space swings by ~\(Bytes.format(bytes)) a day, with no steady trend"
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
        #if DEBUG
        if DemoMode.isOn { return }
        #endif
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: FastFill.backgroundInterval, repeats: true) { _ in
            MainActor.assumeIsolated {
                // The minute check reads often enough while it runs.
                if self.minuteTimer == nil { self.refreshBetweenHours() }
            }
        }
        backgroundTimer?.tolerance = 30
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
        let now = Date()
        history.record(freeBytes: freeBytes, capacityBytes: capacityBytes, at: now)
        saveHistory(at: now)
        onChange?()
    }

    /// The five-minute and minute checks. They lower the day's low but leave the reading to the hourly
    /// check, and write the file only when the low has dropped enough to matter.
    private func refreshBetweenHours() {
        guard read() else { return }
        let now = Date()
        history.recordLow(freeBytes: freeBytes, capacityBytes: capacityBytes, at: now)
        let day = Calendar.current.startOfDay(for: now)
        if let low = history.lowestFreeBytes(on: now),
           UsageHistory.lowIsWorthSaving(low, saved: savedLow?.day == day ? savedLow?.bytes : nil) {
            saveHistory(at: now)
        }
        onChange?()
    }

    private func saveHistory(at now: Date) {
        guard (try? history.save(to: historyURL)) != nil else { return }
        savedLow = history.lowestFreeBytes(on: now).map { (Calendar.current.startOfDay(for: now), $0) }
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
        watchEveryMinuteIfNeeded()
        return true
    }

    private func watchEveryMinuteIfNeeded() {
        recentReadings = FastFill.trimmed(recentReadings + [FastFill.Reading(date: Date(), freeBytes: freeBytes)])
        guard FastFill.shouldWatch(readings: recentReadings, capacityBytes: capacityBytes) else {
            minuteTimer?.invalidate()
            minuteTimer = nil
            return
        }
        guard minuteTimer == nil else { return }
        minuteTimer = Timer.scheduledTimer(withTimeInterval: FastFill.checkInterval, repeats: true) { _ in
            MainActor.assumeIsolated { self.refreshBetweenHours() }
        }
        minuteTimer?.tolerance = 10
    }
}
