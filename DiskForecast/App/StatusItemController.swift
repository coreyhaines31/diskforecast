import AppKit
import DiskForecastCore

/// The menu bar item: free space as its title, and the menu built fresh each time it opens.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let disk: DiskStatus

    init(disk: DiskStatus) {
        self.disk = disk
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
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        disk.refresh()
        menu.removeAllItems()
        let header = NSMenuItem(
            title: "\(Bytes.format(disk.freeBytes)) free of \(Bytes.format(disk.capacityBytes))",
            action: nil, keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)
        let forecast = NSMenuItem(title: disk.forecastPhrase, action: nil, keyEquivalent: "")
        forecast.isEnabled = false
        menu.addItem(forecast)
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Quit \(Brand.name)", keyEquivalent: "q") { NSApp.terminate(nil) })
    }
}
