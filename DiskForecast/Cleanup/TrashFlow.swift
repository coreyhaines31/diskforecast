import AppKit
import DiskForecastCore

/// Confirms, moves entries to the Trash, and says how to finish reclaiming the space.
@MainActor
enum TrashFlow {
    static func confirmAndTrash(_ entries: [CleanupEntry], summary: [String], scan: ScanModel, disk: DiskStatus) {
        guard !entries.isEmpty else { return }
        let total = entries.reduce(0) { $0 + $1.bytes }
        let confirm = NSAlert()
        confirm.messageText = "Move \(Bytes.format(total)) to the Trash?"
        confirm.informativeText = summary.joined(separator: "\n")
            + "\n\nNothing is deleted. You can put anything back from the Trash until you empty it."
        confirm.addButton(withTitle: "Move to Trash")
        confirm.addButton(withTitle: "Cancel")
        NSApp.activate()
        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        let trasher = Trasher(home: scan.home)
        let report = trasher.trash(entries)
        TrashHistory.record(report, trasher: trasher)
        scan.remove(Set(report.moved))
        disk.refresh()

        let done = NSAlert()
        done.messageText = report.moved.isEmpty
            ? "Nothing was moved to the Trash"
            : "Moved \(Bytes.format(report.movedBytes)) to the Trash"
        var details: [String] = []
        if !report.moved.isEmpty {
            details.append("Empty the Trash to reclaim the space.")
        }
        if !report.failed.isEmpty {
            let failures = report.failed.prefix(5).map { "• \(($0.path as NSString).lastPathComponent): \($0.reason)" }
            details.append("Couldn't move \(report.failed.count):\n" + failures.joined(separator: "\n"))
        }
        done.informativeText = details.joined(separator: "\n\n")
        done.addButton(withTitle: "Done")
        done.addButton(withTitle: "Open Trash")
        if !report.moved.isEmpty { done.addButton(withTitle: "Undo") }
        switch done.runModal() {
        case .alertSecondButtonReturn: openTrash()
        case .alertThirdButtonReturn: undo(scan: scan, disk: disk)
        default: break
        }
    }

    private static func undo(scan: ScanModel, disk: DiskStatus) {
        guard let (report, failed) = TrashHistory.undo() else { return }
        disk.refresh()
        scan.scan()
        guard !failed.isEmpty else { return }
        let alert = NSAlert()
        alert.messageText = "Couldn't put back \(failed.count) of \(report.moved.count)"
        alert.informativeText = failed.prefix(5)
            .map { "• \(($0.path as NSString).lastPathComponent): \($0.reason)" }
            .joined(separator: "\n")
        alert.runModal()
    }

    static func openTrash() {
        if let trash = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first {
            NSWorkspace.shared.open(trash)
        }
    }
}
