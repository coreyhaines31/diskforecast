import AppKit
import DiskForecastCore
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
        statusItem.button?.image = NSImage(systemSymbolName: "internaldrive", accessibilityDescription: Brand.name)
        statusItem.button?.imagePosition = .imageLeading
        update()
    }

    /// The menu bar button, for the README demo.
    var button: NSStatusBarButton? { statusItem.button }

    func update() {
        guard let button = statusItem.button else { return }
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

    func menuNeedsUpdate(_ menu: NSMenu) {
        disk.refresh()
        rebuild(menu)
    }

    func menuWillOpen(_ menu: NSMenu) {
        openMenu = menu
    }

    func menuDidClose(_ menu: NSMenu) {
        openMenu = nil
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(label("\(Bytes.format(disk.freeBytes)) free of \(Bytes.format(disk.capacityBytes))"))
        if let warning = disk.lowSpaceWarning {
            let item = ClosureMenuItem("\(warning). Reclaim space…") { [weak self] in self?.openCleanup() }
            let symbol = NSImage.SymbolConfiguration(paletteColors: [.systemOrange])
            item.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(symbol)
            menu.addItem(item)
        }
        menu.addItem(label(disk.forecastPhrase))
        addChart(to: menu)
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
    }

    /// The last 30 days as a small chart, once there are two days to draw. Clicking it opens
    /// the Forecast window.
    private func addChart(to menu: NSMenu) {
        guard disk.history.samples.count >= 2 else { return }
        let open = { [weak self, weak menu] in
            menu?.cancelTracking()
            self?.openForecast()
        }
        let grewMost = SnapshotComparison.grewMostThisWeek(in: snapshots)
        let view = NSHostingView(rootView: MenuForecastView(disk: disk, grewMost: grewMost, open: open))
        view.frame.size = view.fittingSize
        let item = NSMenuItem()
        item.view = view
        menu.addItem(item)
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
            menu.addItem(ClosureMenuItem("Empty Trash: \(Bytes.format(trash))…") { [self] in
                TrashFlow.confirmAndEmptyTrash(scan: scan, disk: disk)
            })
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
