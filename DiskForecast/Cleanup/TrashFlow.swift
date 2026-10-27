import AppKit
import DiskForecastCore

/// Confirms, moves entries to the Trash or deletes them, and says how to finish reclaiming the space.
@MainActor
enum TrashFlow {
    static func confirmAndTrash(
        _ entries: [CleanupEntry], summary: [CleanupItem], scan: ScanModel, disk: DiskStatus
    ) {
        guard !entries.isEmpty else { return }
        let total = entries.reduce(0) { $0 + $1.bytes }
        let openFiles = OpenFiles.current()
        let confirm = NSAlert()
        confirm.messageText = "Move \(Bytes.format(total)) to the Trash?"
        confirm.informativeText = "You can put anything back from the Trash until you empty it. Delete "
            + "Immediately frees the space now, but can't be undone."
            + busyNote(Trasher.busy(entries, openFiles: openFiles))
        confirm.accessoryView = summaryGrid(summary)
        confirm.addButton(withTitle: "Move to Trash")
        confirm.addButton(withTitle: "Cancel")
        confirm.addButton(withTitle: "Delete Immediately").hasDestructiveAction = true
        NSApp.activate()
        switch confirm.runModal() {
        // Checked again when moving, in case an app was quit while this was open.
        case .alertFirstButtonReturn: dispose(entries, permanently: false, scan: scan, disk: disk)
        case .alertThirdButtonReturn: dispose(entries, permanently: true, scan: scan, disk: disk)
        default: break
        }
    }

    /// "\n\nCursor is open, so 1.2 GB of this stays. Quit it first to include everything."
    private static func busyNote(_ busy: [String: [CleanupEntry]]) -> String {
        guard !busy.isEmpty else { return "" }
        let apps = busy.keys.sorted().filter { $0 != OpenFiles.claudeCode }
        var notes: [String] = []
        if !apps.isEmpty {
            let bytes = apps.compactMap { busy[$0] }.joined().reduce(0) { $0 + $1.bytes }
            notes.append("\(appsPhrase(apps)) open, so \(Bytes.format(bytes)) of this stays. Quit "
                + (apps.count == 1 ? "it" : "them") + " first to include everything.")
        }
        // Claude Code runs in a terminal, so it's ended with /exit rather than quit.
        if let versions = busy[OpenFiles.claudeCode] {
            let bytes = versions.reduce(0) { $0 + $1.bytes }
            notes.append("Claude Code sessions are using \(versions.map(\.name).formatted(.list(type: .and))), so "
                + "\(Bytes.format(bytes)) stays. Type /exit in those sessions first to include everything.")
        }
        return "\n\n" + notes.joined(separator: " ")
    }

    /// Deleting can take a while, so it runs off the main thread while the menu says so.
    private static func dispose(_ entries: [CleanupEntry], permanently: Bool, scan: ScanModel, disk: DiskStatus) {
        let trasher = Trasher(home: scan.home)
        let total = entries.reduce(0) { $0 + $1.bytes }
        scan.activity = permanently ? "Deleting \(Bytes.format(total))…" : "Moving \(Bytes.format(total)) to the Trash…"
        Task {
            let report = await Task.detached(priority: .userInitiated) {
                trasher.trash(entries, permanently: permanently)
            }.value
            scan.activity = nil
            if !permanently { TrashHistory.record(report, trasher: trasher) }
            scan.remove(Set(report.moved))
            disk.refresh()
            scan.measureTrash()
            showResult(report, of: entries, scan: scan, disk: disk)
        }
    }

    private static func showResult(
        _ report: Trasher.Report, of entries: [CleanupEntry], scan: ScanModel, disk: DiskStatus
    ) {
        let done = NSAlert()
        (done.messageText, done.informativeText) = resultText(report)
        var buttons: [String]
        if report.diskFull {
            buttons = ["Delete Instead", "Empty Trash…", "Done"]
        } else if report.deleted {
            buttons = ["Done"]
        } else {
            buttons = ["Done", "Empty Trash…"]
            if !report.moved.isEmpty { buttons.append("Undo") }
        }
        for title in buttons {
            done.addButton(withTitle: title).hasDestructiveAction = title == "Delete Instead"
        }
        let index = done.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        switch buttons.indices.contains(index) ? buttons[index] : "" {
        case "Delete Instead":
            let moved = Set(report.moved)
            dispose(entries.filter { !moved.contains($0.path) }, permanently: true, scan: scan, disk: disk)
        case "Empty Trash…": confirmAndEmptyTrash(scan: scan, disk: disk)
        case "Undo": undo(scan: scan, disk: disk)
        default: break
        }
    }

    private static func resultText(_ report: Trasher.Report) -> (title: String, details: String) {
        let amount = Bytes.format(report.movedBytes)
        let title: String
        var details: [String] = []
        if report.deleted {
            title = report.moved.isEmpty ? "Nothing was deleted" : "Deleted \(amount)"
            if !report.moved.isEmpty { details.append("The space is free now.") }
        } else if report.diskFull {
            title = report.moved.isEmpty
                ? "Your disk is too full to use the Trash" : "Moved \(amount), then the disk filled up"
            details.append(
                "Moving to the Trash needs a little free space. Delete instead to free the space now, or empty "
                    + "the Trash and try again. Deleting can't be undone."
            )
        } else {
            title = report.moved.isEmpty ? "Nothing was moved to the Trash" : "Moved \(amount) to the Trash"
            if !report.moved.isEmpty { details.append("The space comes back when you empty the Trash.") }
        }
        if !report.failed.isEmpty && !(report.diskFull && report.moved.isEmpty) {
            let verb = report.deleted ? "delete" : "move"
            details.append("Couldn't \(verb) \(report.failed.count):\n" + report.failureLines().joined(separator: "\n"))
        }
        return (title, details.joined(separator: "\n\n"))
    }

    /// Empties the Trash itself rather than through Finder, which stops at paths that are too long
    /// and at anything an app still has open.
    static func confirmAndEmptyTrash(scan: ScanModel, disk: DiskStatus) {
        let bin = TrashBin(home: scan.home)
        NSApp.activate()
        guard let contents = try? bin.contents() else {
            needAccessToEmpty()
            return
        }
        guard !contents.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "The Trash is already empty"
            alert.runModal()
            return
        }
        let openFiles = OpenFiles.current()
        let confirm = NSAlert()
        confirm.messageText = scan.trashBytes.map { "Permanently delete the \(Bytes.format($0)) in the Trash?" }
            ?? "Permanently delete everything in the Trash?"
        var text = "\(contents.count.formatted()) item\(contents.count == 1 ? "" : "s"). This can't be undone."
        let busy = Set(contents.compactMap(openFiles.user(of:))).sorted()
        if !busy.isEmpty {
            text += " \(appsPhrase(busy)) still using some of them, so those stay until you quit "
                + (busy.count == 1 ? "it." : "them.")
        }
        confirm.informativeText = text
        confirm.addButton(withTitle: "Empty Trash").hasDestructiveAction = true
        confirm.addButton(withTitle: "Cancel")
        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        let before = disk.freeBytes
        scan.activity = "Emptying the Trash…"
        Task {
            let report = await Task.detached(priority: .userInitiated) {
                try? bin.empty(openFiles: openFiles)
            }.value
            scan.activity = nil
            TrashHistory.clear()
            disk.refresh()
            scan.measureTrash()
            let done = NSAlert()
            let freed = max(0, disk.freeBytes - before)
            done.messageText = report?.moved.isEmpty == false ? "Emptied the Trash" : "The Trash wasn't emptied"
            var details = freed > 0 ? ["\(Bytes.format(freed)) is free again."] : []
            if let report, !report.failed.isEmpty {
                details.append(
                    "Left \(report.failed.count) in the Trash:\n" + report.failureLines().joined(separator: "\n")
                )
            }
            done.informativeText = details.joined(separator: "\n\n")
            done.runModal()
        }
    }

    private static func needAccessToEmpty() {
        let alert = NSAlert()
        alert.messageText = "\(Brand.name) needs Full Disk Access to empty the Trash"
        alert.informativeText = "macOS only lets apps with Full Disk Access see what's in the Trash. Turn it "
            + "on in System Settings, or empty the Trash from Finder."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Open Trash")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn: FullDiskAccess.openSettings()
        case .alertSecondButtonReturn: openTrash()
        default: break
        }
    }

    /// "Cursor is", "Cursor and Notion are", "Cursor, Notion, and Slack are".
    static func appsPhrase(_ apps: [String]) -> String {
        apps.formatted(.list(type: .and)) + (apps.count == 1 ? " is" : " are")
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
