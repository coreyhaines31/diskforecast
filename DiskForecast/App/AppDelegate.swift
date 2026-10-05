import AppKit
import DiskForecastCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var disk = DiskStatus(supportFolder: Self.supportFolder)
    private var statusItemController: StatusItemController?

    static var supportFolder: URL {
        URL.applicationSupportDirectory.appending(path: Brand.supportFolderName)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.registerDefaults()
        statusItemController = StatusItemController(disk: disk)
        disk.onChange = { [weak self] in self?.statusItemController?.update() }
        disk.start()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.disk.refresh() }
        }
    }
}
