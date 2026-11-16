import AppKit
import DiskForecastCore
import PanelKit
import SwiftUI

/// The menu bar item: free space as its title, and the menu built fresh each time it opens.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let disk: DiskStatus
    private let scan: ScanModel
    private let snapshots: FolderSnapshotStore
    private let updater: Updater
    private weak var openMenu: NSMenu?
    private let meterState = StorageMeterState()
    var openCleanup: () -> Void = {}
    var openSystemData: () -> Void = {}
    var openForecast: () -> Void = {}
    var grantAccess: () -> Void = {}
    var openSettings: () -> Void = {}

    init(disk: DiskStatus, scan: ScanModel, snapshots: FolderSnapshotStore, updater: Updater) {
        self.disk = disk
        self.scan = scan
        self.snapshots = snapshots
        self.updater = updater
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageLeading
        update()
    }

    /// The menu bar button, for the README demo.
    var button: NSStatusBarButton? { statusItem.button }

    func update() {
        guard let button = statusItem.button else { return }
        button.image = Self.reel(for: disk)
        switch Preferences.menuBarDisplay {
        case .freeSpace: button.title = disk.capacityBytes > 0 ? Bytes.format(disk.freeBytes) : ""
        case .percentFree: button.title = disk.capacityBytes > 0 ? "\(Int((disk.percentFree * 100).rounded()))%" : ""
        case .iconOnly: button.title = ""
        }
        button.imagePosition = button.title.isEmpty ? .imageOnly : .imageLeading
        button.toolTip = "\(Bytes.format(disk.freeBytes)) free · \(disk.forecastPhrase)"
        if let openMenu {
            rebuild(openMenu)
        }
    }

    /// The tape reel glyph: the fuller the disk, the more tape fills the reel's windows.
    private static func reel(for disk: DiskStatus) -> NSImage {
        let used = disk.capacityBytes > 0 ? 1 - disk.percentFree : 0
        let image = ReelGlyph.image(ReelGlyph.state(percentUsed: used, isLow: disk.lowSpaceWarning != nil))
        image.accessibilityDescription = Brand.name
        return image
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        disk.refresh()
        rebuild(menu)
    }

    func menuWillOpen(_ menu: NSMenu) {
        openMenu = menu
    }

    func menuDidClose(_ menu: NSMenu) {
        openMenu = nil
        meterState.menuClosed()
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()
        if let warning = disk.lowSpaceWarning {
            let item = ClosureMenuItem("\(warning). Reclaim space…") { [weak self] in self?.openCleanup() }
            let symbol = NSImage.SymbolConfiguration(paletteColors: [.systemOrange])
            item.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(symbol)
            menu.addItem(item)
        }
        menu.addItem(.separator())
        addConsumers(to: menu)
        addReclaim(to: menu)
        menu.addItem(.separator())
        if !FullDiskAccess.isGranted {
            menu.addItem(ClosureMenuItem("Grant Full Disk Access…") { [weak self] in self?.grantAccess() })
        }
        menu.addItem(ClosureMenuItem("Settings…", keyEquivalent: ",") { [weak self] in self?.openSettings() })
        let updates = ClosureMenuItem("Check for Updates…") { [updater] in updater.checkForUpdates() }
        updates.isEnabled = updater.canCheck
        menu.addItem(updates)
        menu.addItem(ClosureMenuItem("Quit \(Brand.name)", keyEquivalent: "q") { NSApp.terminate(nil) })
        // Last, so the card can take the width the other items give the menu.
        addCard(to: menu)
    }

    /// The Brushed card: free space, percent full, days to full and, once there are two days to
    /// draw, the last 30 days as a small chart. Clicking it opens Forecast.
    private func addCard(to menu: NSMenu) {
        let open = { [weak self, weak menu] in
            menu?.cancelTracking()
            self?.openForecast()
        }
        let grewMost = SnapshotComparison.grewMostThisWeek(in: snapshots)
        let card = MenuCardView(
            disk: disk, menuWidth: menu.size.width, grewMost: grewMost, storage: storageSection(in: menu), open: open
        )
        menu.insertItem(.panelCard(card), at: 0)
    }

    /// The storage meter, in the style chosen in Settings. Its Empty Trash key goes through the
    /// same confirmation as the menu item, after closing the menu.
    private func storageSection(in menu: NSMenu) -> StorageMeterSection {
        let emptyTrash = { [weak self, weak menu] in
            menu?.cancelTracking()
            Task { @MainActor in self?.emptyTrash() }
        }
        let grantAccess = { [weak self, weak menu] in
            menu?.cancelTracking()
            self?.grantAccess()
        }
        return StorageMeterSection(
            style: Preferences.storageMeterStyle, reading: storageReading(), state: meterState,
            emptyTrash: emptyTrash, grantAccess: grantAccess
        )
    }

    private func emptyTrash() {
        TrashFlow.confirmAndEmptyTrash(scan: scan, disk: disk) { [meterState] in meterState.trashEmptied($0) }
    }

    /// Categories once a scan has finished; while one runs, used space alone, so nothing stale shows.
    private func storageReading() -> StorageReading {
        let used = max(0, disk.capacityBytes - disk.freeBytes)
        var breakdown: StorageBreakdown?
        if !scan.isScanning, let result = scan.result {
            breakdown = StorageBreakdown(
                home: scan.home, scan: result, items: scan.items, capacityBytes: disk.capacityBytes,
                volumeUsedBytes: used, applicationsBytes: scan.applicationsBytes, trashBytes: scan.trashBytes,
                fullDiskAccess: scan.scannedWithFullDiskAccess
            )
        }
        var measuring = "Not measured yet"
        if case .scanning(let files) = scan.state {
            measuring = "Measuring… \(files.formatted(.number.notation(.compactName))) files"
        }
        return StorageReading(
            breakdown: breakdown, capacityBytes: disk.capacityBytes, usedBytes: breakdown?.usedBytes ?? used,
            measuring: measuring, footer: storageFooter()
        )
    }

    private func storageFooter() -> StorageFooter {
        if let activity = scan.activity { return .activity(activity) }
        let trash = scan.trashBytes
        if let emptied = meterState.recentlyEmptied(), (trash ?? 0) < 1_000_000 { return .emptied(emptied) }
        guard FullDiskAccess.isGranted else { return .needsAccess }
        guard let trash else { return .activity("Measuring the Trash…") }
        return trash >= 1_000_000 ? .trash(trash) : .empty
    }

    private func addConsumers(to menu: NSMenu) {
        guard let result = scan.result else { return }
        menu.addItem(NSMenuItem.sectionHeader(title: "Taking the most space"))
        let home = scan.home
        for node in result.tree.topConsumers(limit: 5) {
            let path = result.tree.path(of: node)
            let shown = path.hasPrefix(home + "/") ? "~/" + path.dropFirst(home.count + 1) : path
            let size = Bytes.format(result.tree.size(ofNode: node))
            let item = NSMenuItem(title: "\(shown)\t\(size)", action: nil, keyEquivalent: "")
            item.attributedTitle = Self.columns(String(shown), size)
            item.submenu = consumerMenu(for: path)
            menu.addItem(item)
        }
        menu.addItem(.separator())
    }

    /// What Cleanup knows inside a big folder, each opening Cleanup at that item, then Finder.
    private func consumerMenu(for path: String) -> NSMenu {
        let submenu = NSMenu()
        let known = scan.items.compactMap { item -> (item: CleanupItem, bytes: Int64)? in
            let inside = item.entries.filter { $0.path == path || $0.path.hasPrefix(path + "/") }
            let bytes = inside.reduce(0) { $0 + $1.bytes }
            return bytes > 0 ? (item, bytes) : nil
        }
        if known.isEmpty {
            submenu.addItem(label("Cleanup doesn't know what's in here"))
            submenu.addItem(ClosureMenuItem("Suggest a Rule…") { [weak self] in self?.suggestRule(for: path) })
        } else {
            submenu.addItem(NSMenuItem.sectionHeader(title: "In Cleanup"))
            for (item, bytes) in known.sorted(by: { $0.bytes > $1.bytes }) {
                let size = Bytes.format(bytes)
                let row = ClosureMenuItem("\(item.title)…\t\(size)") { [weak self] in
                    self?.scan.focusedItem = item.id
                    self?.openCleanup()
                }
                row.attributedTitle = Self.columns(item.title + "…", size)
                row.toolTip = item.explanation
                submenu.addItem(row)
            }
        }
        submenu.addItem(.separator())
        submenu.addItem(ClosureMenuItem("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: path)])
        })
        return submenu
    }

    /// Opens a GitHub issue asking for Cleanup to explain a folder, filled in with its location and
    /// size. Nothing is sent until the person submits it, and they can edit it first.
    private func suggestRule(for path: String) {
        let home = scan.home
        let shown = path.hasPrefix(home + "/") ? "~/" + path.dropFirst(home.count + 1) : path
        let size = scan.result.flatMap { $0.tree.size(of: path) }.map(Bytes.format) ?? "?"
        let body = """
            Cleanup doesn't know what's in `\(shown)` (\(size)).

            What app or tool makes it, if you know:

            Is it safe to remove, and does it come back?
            """
        var components = URLComponents(string: "https://github.com/coreyhaines31/diskforecast/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: "Explain \(shown) in Cleanup"),
            URLQueryItem(name: "body", value: body),
            URLQueryItem(name: "labels", value: "cleanup-rule")
        ]
        if let url = components?.url { NSWorkspace.shared.open(url) }
    }

    private func addReclaim(to menu: NSMenu) {
        if case .scanning(let files) = scan.state {
            let counted = files.formatted(.number.notation(.compactName))
            menu.addItem(label("Measuring… \(counted) files"))
            menu.addItem(ClosureMenuItem("Open Cleanup…") { [weak self] in self?.openCleanup() })
            menu.addItem(ClosureMenuItem("System Data…") { [weak self] in self?.openSystemData() })
            return
        }
        let safe = scan.safeToClear
        if !safe.isEmpty {
            menu.addItem(ClosureMenuItem("Safe to clear: \(Bytes.format(scan.safeToClearBytes))…") { [self] in
                TrashFlow.confirmAndTrash(
                    safe.flatMap(\.entries),
                    summary: safe,
                    scan: scan, disk: disk
                )
            })
        }
        if let activity = scan.activity {
            menu.addItem(label(activity))
        } else if let trash = scan.trashBytes, trash >= 1_000_000 {
            menu.addItem(ClosureMenuItem("Empty Trash: \(Bytes.format(trash))…") { [weak self] in self?.emptyTrash() })
        }
        menu.addItem(ClosureMenuItem("Open Cleanup…") { [weak self] in self?.openCleanup() })
        menu.addItem(ClosureMenuItem("System Data…") { [weak self] in self?.openSystemData() })
        menu.addItem(ClosureMenuItem("Forecast…") { [weak self] in self?.openForecast() })
        menu.addItem(ClosureMenuItem("Rescan") { [scan] in scan.scan() })
    }

    /// A name on the left and a size against a right-aligned tab stop, so sizes line up.
    private static func columns(_ name: String, _ size: String) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .right, location: 340)]
        style.lineBreakMode = .byTruncatingMiddle
        let shortened = name.count > 42 ? String(name.prefix(20)) + "…" + String(name.suffix(20)) : name
        return NSAttributedString(string: "\(shortened)\t\(size)", attributes: [
            .paragraphStyle: style, .font: NSFont.menuFont(ofSize: 0)
        ])
    }

    private func label(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
