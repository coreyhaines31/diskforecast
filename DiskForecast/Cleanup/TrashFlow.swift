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

        let sizes = Dictionary(entries.map { ($0.path, $0.bytes) }) { first, _ in first }
        let report = Trasher(home: scan.home).trash(entries.map(\.path), sizes: sizes)
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
        done.addButton(withTitle: "Open Trash")
        done.addButton(withTitle: "Done")
        if done.runModal() == .alertFirstButtonReturn {
            openTrash()
        }
    }

    static func openTrash() {
        if let trash = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first {
            NSWorkspace.shared.open(trash)
        }
    }
}
