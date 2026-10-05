import AppKit
import DiskForecastCore

/// The menu bar item: free space as its title, and the menu built fresh each time it opens.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let disk: DiskStatus
    private let scan: ScanModel
    private let updater: Updater
    private weak var openMenu: NSMenu?
    var openCleanup: () -> Void = {}
    var openSystemData: () -> Void = {}
    var grantAccess: () -> Void = {}
    var openSettings: () -> Void = {}

    init(disk: DiskStatus, scan: ScanModel, updater: Updater) {
        self.disk = disk
        self.scan = scan
        self.updater = updater
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.image = NSImage(systemSymbolName: "internaldrive", accessibilityDescription: Brand.name)
        statusItem.button?.imagePosition = .imageLeading
        update()
    }

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
        menu.addItem(label(disk.forecastPhrase))
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

    private func addConsumers(to menu: NSMenu) {
        guard let result = scan.result else { return }
        menu.addItem(NSMenuItem.sectionHeader(title: "Taking the most space"))
        let home = scan.home
        for node in result.tree.topConsumers(limit: 5) {
            let path = result.tree.path(of: node)
            let shown = path.hasPrefix(home + "/") ? "~/" + path.dropFirst(home.count + 1) : path
            let item = ClosureMenuItem("\(shown)\t\(Bytes.format(result.tree.size(ofNode: node)))") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: path)])
            }
            item.toolTip = "Show in Finder"
            menu.addItem(item)
        }
        menu.addItem(.separator())
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
                    summary: safe.map { "• \($0.title): \(Bytes.format($0.bytes))" },
                    scan: scan, disk: disk
                )
            })
        }
        menu.addItem(ClosureMenuItem("Open Cleanup…") { [weak self] in self?.openCleanup() })
        menu.addItem(ClosureMenuItem("System Data…") { [weak self] in self?.openSystemData() })
        menu.addItem(ClosureMenuItem("Rescan") { [scan] in scan.scan() })
    }

    private func label(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
