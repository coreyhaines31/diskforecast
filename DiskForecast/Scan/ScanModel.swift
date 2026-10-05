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
    /// Folders still being measured on their own, usually because macOS is asking permission.
    private(set) var pendingFolders: [String] = []
    private var generation = 0
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
        guard scheduleTimer == nil else { return }
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 12 * 3_600, repeats: true) { _ in
            MainActor.assumeIsolated { self.scan() }
        }
        scheduleTimer?.tolerance = 600
    }

    func scan() {
        guard !isScanning else { return }
        generation += 1
        let generation = generation
        let fullAccess = FullDiskAccess.isGranted
        let protected = fullAccess ? [] : FullDiskAccess.protectedFolders(home: home)
        let separate = fullAccess ? [] : FullDiskAccess.promptedFolders(home: home)
        let scanner = DiskScanner(options: .init(
            root: URL(filePath: home), excludedPaths: protected.union(separate)
        ))
        self.scanner = scanner
        pendingFolders = separate
        state = .scanning(files: 0)
        onChange?()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            MainActor.assumeIsolated {
                guard self.isScanning else { return }
                self.state = .scanning(files: scanner.progress.files)
                self.onChange?()
            }
        }
        Task {
            let result = await scanner.scan()
            guard generation == self.generation else { return }
            await finish(result: result, fullAccess: fullAccess)
        }
        for folder in separate {
            Task {
                let branch = await DiskScanner(options: .init(
                    root: URL(filePath: folder), excludedPaths: protected
                )).scan()
                await graft(branch, folder: folder, generation: generation)
            }
        }
    }

    private func finish(result: ScanResult, fullAccess: Bool) async {
        progressTimer?.invalidate()
        scanner = nil
        self.result = result
        scannedWithFullDiskAccess = fullAccess
        finishedAt = Date()
        await rebuildItems()
        state = .done
        onChange?()
    }

    /// Adds a separately measured folder once both it and the main scan are done.
    private func graft(_ branch: ScanResult, folder: String, generation: Int) async {
        while generation == self.generation && isScanning {
            try? await Task.sleep(for: .milliseconds(500))
        }
        guard generation == self.generation, let result else { return }
        self.result = result.grafting(branch)
        pendingFolders.removeAll { $0 == folder }
        await rebuildItems()
        onChange?()
    }

    private func rebuildItems() async {
        guard let result else { return }
        let catalog = CleanupCatalog(home: home, staleAfterDays: Preferences.staleAfterDays)
        items = await Task.detached(priority: .utility) { catalog.items(from: result) }.value
    }

    /// Rebuilds the list from the last scan, after a setting that shapes it changes.
    func rebuildCleanupList() {
        guard !isScanning else { return }
        Task {
            await rebuildItems()
            onChange?()
        }
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
