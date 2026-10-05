import AppKit
import DiskForecastCore
import Observation

/// Scans the home folder and keeps the cleanup list that comes out of it.
@MainActor
@Observable
final class ScanModel {
    enum State: Equatable {
        case idle
        case scanning(files: Int)
        case done
    }

    private(set) var state = State.idle
    private(set) var result: ScanResult?
    private(set) var items: [CleanupItem] = []
    private(set) var scannedWithFullDiskAccess = false
    private(set) var finishedAt: Date?
    var onChange: (() -> Void)?

    private var scanner: DiskScanner?
    private var progressTimer: Timer?
    private var scheduleTimer: Timer?
    let home: String = {
        let path = URL.homeDirectory.path(percentEncoded: false)
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }()

    var isScanning: Bool {
        if case .scanning = state { return true }
        return false
    }

    var safeToClear: [CleanupItem] {
        items.filter { $0.group == .safeToClear && $0.action == .trash }
    }

    var safeToClearBytes: Int64 {
        safeToClear.reduce(0) { $0 + $1.bytes }
    }

    /// Scans now, then twice a day.
    func start() {
        scan()
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 12 * 3_600, repeats: true) { _ in
            MainActor.assumeIsolated { self.scan() }
        }
        scheduleTimer?.tolerance = 600
    }

    func scan() {
        guard !isScanning else { return }
        let fullAccess = FullDiskAccess.isGranted
        let options = DiskScanner.Options(
            root: URL(filePath: home),
            excludedPaths: fullAccess ? [] : FullDiskAccess.protectedFolders(home: home)
        )
        let scanner = DiskScanner(options: options)
        self.scanner = scanner
        state = .scanning(files: 0)
        onChange?()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            MainActor.assumeIsolated {
                guard self.isScanning else { return }
                self.state = .scanning(files: scanner.progress.files)
                self.onChange?()
            }
        }
        let catalog = CleanupCatalog(home: home, staleAfterDays: Preferences.staleAfterDays)
        Task {
            let result = await scanner.scan()
            let items = await Task.detached(priority: .utility) { catalog.items(from: result) }.value
            self.finish(result: result, items: items, fullAccess: fullAccess)
        }
    }

    private func finish(result: ScanResult, items: [CleanupItem], fullAccess: Bool) {
        progressTimer?.invalidate()
        scanner = nil
        self.result = result
        self.items = items
        scannedWithFullDiskAccess = fullAccess
        finishedAt = Date()
        state = .done
        onChange?()
    }

    /// Takes trashed entries off the list without waiting for the next scan.
    func remove(_ paths: Set<String>) {
        items = items.compactMap { item in
            let kept = item.entries.filter { !paths.contains($0.path) }
            guard !kept.isEmpty else { return nil }
            return CleanupItem(
                id: item.id, title: item.title, explanation: item.explanation,
                group: item.group, action: item.action, entries: kept
            )
        }
        onChange?()
    }
}
