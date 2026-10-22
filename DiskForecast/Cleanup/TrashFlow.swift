import AppKit
import DiskForecastCore

/// Confirms, moves entries to the Trash, and says how to finish reclaiming the space.
@MainActor
enum TrashFlow {
    static func confirmAndTrash(
        _ entries: [CleanupEntry], summary: [CleanupItem], scan: ScanModel, disk: DiskStatus
    ) {
        guard !entries.isEmpty else { return }
        let total = entries.reduce(0) { $0 + $1.bytes }
        let confirm = NSAlert()
        confirm.messageText = "Move \(Bytes.format(total)) to the Trash?"
        confirm.informativeText = "Nothing is deleted. You can put anything back from the Trash until you empty it."
        confirm.accessoryView = summaryGrid(summary)
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
        var details: [String] = []
        if report.diskFull {
            done.messageText = report.moved.isEmpty
                ? "Your disk is too full to use the Trash"
                : "Moved \(Bytes.format(report.movedBytes)), then the disk filled up"
            details.append(
                "Moving to the Trash needs a little free space. Empty the Trash, then try again. If it's "
                    + "already empty, select a large folder you can rebuild in Finder and press "
                    + "Option\u{2011}Command\u{2011}Delete to delete it right away."
            )
        } else {
            done.messageText = report.moved.isEmpty
                ? "Nothing was moved to the Trash"
                : "Moved \(Bytes.format(report.movedBytes)) to the Trash"
            if !report.moved.isEmpty {
                details.append("The space comes back when you empty the Trash.")
            }
        }
        if !report.failed.isEmpty && !(report.diskFull && report.moved.isEmpty) {
            details.append("Couldn't move \(report.failed.count):\n" + report.failureLines().joined(separator: "\n"))
        }
        done.informativeText = details.joined(separator: "\n\n")
        // With a full disk, emptying the Trash is the way forward, so it leads.
        var buttons = report.diskFull ? ["Open Trash", "Done"] : ["Done", "Open Trash"]
        if !report.moved.isEmpty { buttons.append("Undo") }
        buttons.forEach { done.addButton(withTitle: $0) }
        let index = done.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        switch buttons.indices.contains(index) ? buttons[index] : "" {
        case "Open Trash": openTrash()
        case "Undo": undo(scan: scan, disk: disk)
        default: break
        }
    }

    /// Each category's title and size on one row, sizes right-aligned and largest first, with what's
    /// in it underneath across the full width. Hovering a category explains it.
    private static func summaryGrid(_ summary: [CleanupItem]) -> NSView {
        let width: CGFloat = 300
        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let grid = NSGridView()
        grid.columnSpacing = 16
        grid.rowSpacing = 1
        for item in summary.sorted(by: { $0.bytes > $1.bytes }) {
            let title = NSTextField(labelWithString: item.title)
            title.font = font
            title.lineBreakMode = .byTruncatingTail
            title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            title.toolTip = item.explanation
            let size = NSTextField(labelWithString: Bytes.format(item.bytes))
            size.font = .monospacedDigitSystemFont(ofSize: font.pointSize, weight: .medium)
            let contents = NSTextField(wrappingLabelWithString: item.preview())
            contents.font = .systemFont(ofSize: NSFont.smallSystemFontSize - 1)
            contents.textColor = .secondaryLabelColor
            contents.preferredMaxLayoutWidth = width
            contents.maximumNumberOfLines = 2
            contents.toolTip = item.explanation
            if grid.numberOfRows > 0 { grid.row(at: grid.numberOfRows - 1).bottomPadding = 8 }
            grid.addRow(with: [title, size])
            grid.addRow(with: [contents, NSGridCell.emptyContentView])
            grid.mergeCells(inHorizontalRange: NSRange(location: 0, length: 2), verticalRange: NSRange(
                location: grid.numberOfRows - 1, length: 1
            ))
        }
        grid.column(at: 1).xPlacement = .trailing
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.widthAnchor.constraint(equalToConstant: width).isActive = true
        grid.layoutSubtreeIfNeeded()
        grid.frame.size = grid.fittingSize
        return scrolling(grid, maxHeight: 260)
    }

    /// Keeps a long list from pushing the alert's buttons off a small screen.
    private static func scrolling(_ view: NSView, maxHeight: CGFloat) -> NSView {
        guard view.frame.height > maxHeight else { return view }
        view.translatesAutoresizingMaskIntoConstraints = true
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: view.frame.width, height: maxHeight))
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        scroll.drawsBackground = false
        scroll.documentView = view
        view.scroll(NSPoint(x: 0, y: view.isFlipped ? 0 : view.frame.height))
        return scroll
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
