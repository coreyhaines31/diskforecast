import DiskForecastCore
import Foundation

/// Carries out what the `diskforecast` command asks for, from the same data the menu shows.
@MainActor
final class CLICommands {
    private let disk: DiskStatus
    private let scan: ScanModel
    private let snapshots: FolderSnapshotStore
    private let open: (CLIRequest.Window) -> Void

    init(
        disk: DiskStatus, scan: ScanModel, snapshots: FolderSnapshotStore,
        open: @escaping (CLIRequest.Window) -> Void
    ) {
        self.disk = disk
        self.scan = scan
        self.snapshots = snapshots
        self.open = open
    }

    func handle(_ request: CLIRequest) -> CLIResponse {
        switch request.action {
        case .status:
            return statusResponse()
        case .changes:
            return changes(days: request.days ?? 7)
        case .cleanup:
            guard scan.result != nil else { return notScannedYet() }
            var notes: [String] = []
            if scan.isScanning { notes.append("A new scan is running. This list is from the last one.") }
            return CLIResponse(notes: notes, cleanup: scan.items.map(CLICleanupItem.init))
        case .scan:
            scan.scan()
            return CLIResponse(status: status())
        case .trash:
            return trash(request.targets ?? [], confirmed: request.confirmed ?? false)
        case .undo:
            return undo()
        case .open:
            if let window = request.window { open(window) }
            return CLIResponse()
        }
    }

    private func statusResponse() -> CLIResponse {
        disk.refresh()
        var notes: [String] = []
        if !FullDiskAccess.isGranted {
            notes.append("Full Disk Access is off, so some folders aren't measured. "
                + "Turn it on in System Settings › Privacy & Security › Full Disk Access.")
        }
        return CLIResponse(notes: notes, status: status())
    }

    private func status() -> CLIStatus {
        var daysUntilFull: Double?
        var bytesPerDay: Double?
        let outlook: String
        switch disk.outlook {
        case .learning: outlook = "learning"
        case .filling(let days, let rate):
            outlook = "filling"
            daysUntilFull = days
            bytesPerDay = rate
        case .steady: outlook = "steady"
        case .gaining(let rate):
            outlook = "gaining"
            bytesPerDay = rate
        }
        return CLIStatus(
            freeBytes: disk.freeBytes, capacityBytes: disk.capacityBytes, purgeableBytes: disk.purgeableBytes,
            outlook: outlook, forecast: disk.forecastPhrase, daysUntilFull: daysUntilFull, bytesPerDay: bytesPerDay,
            lowOnSpace: disk.lowSpaceWarning != nil, scanning: scan.isScanning, lastScan: scan.finishedAt,
            fullDiskAccess: FullDiskAccess.isGranted, safeToClearBytes: scan.safeToClearBytes
        )
    }

    private func changes(days: Int) -> CLIResponse {
        let since = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        guard let comparison = SnapshotComparison(store: snapshots, since: since) else {
            return CLIResponse(notes: [
                "\(Brand.name) saves folder sizes after each scan and needs scans from two different days "
                    + "in that range to compare. Check back tomorrow, or try a longer --days."
            ])
        }
        return CLIResponse(changes: CLIChanges(from: comparison.old, to: comparison.new))
    }

    private func trash(_ targets: [String], confirmed: Bool) -> CLIResponse {
        guard scan.result != nil else { return notScannedYet() }
        let entries: [CleanupEntry]
        do {
            entries = try CLITrashTargets.entries(for: targets, in: scan.items, home: scan.home)
        } catch {
            return CLIResponse(error: error.message)
        }
        let total = entries.reduce(0) { $0 + $1.bytes }
        guard confirmed else {
            return CLIResponse(trash: CLITrashReport(confirmed: false, paths: entries.map(\.path), bytes: total))
        }
        let trasher = Trasher(home: scan.home)
        let report = trasher.trash(entries)
        TrashHistory.record(report, trasher: trasher)
        scan.remove(Set(report.moved))
        disk.refresh()
        return CLIResponse(trash: CLITrashReport(
            confirmed: true, paths: report.moved, bytes: report.movedBytes,
            failed: report.failed.map { CLITrashFailure(path: $0.path, reason: $0.reason) }
        ))
    }

    private func undo() -> CLIResponse {
        guard let (report, failed) = TrashHistory.undo() else {
            return CLIResponse(error: "Nothing to undo. Only the last trash run since \(Brand.name) opened "
                + "can be undone.")
        }
        let failedPaths = Set(failed.map(\.path))
        let putBack = report.moved.filter { !failedPaths.contains($0) }
        disk.refresh()
        scan.scan()
        return CLIResponse(undo: CLIUndoReport(
            paths: putBack, bytes: putBack.reduce(0) { $0 + (report.movedSizes[$1] ?? 0) },
            failed: failed.map { CLITrashFailure(path: $0.path, reason: $0.reason) }
        ))
    }

    private func notScannedYet() -> CLIResponse {
        CLIResponse(error: scan.isScanning
            ? "The first scan is still running. Try again when it's done, or run: diskforecast scan --wait"
            : "Nothing's been measured yet. Run: diskforecast scan --wait")
    }
}
