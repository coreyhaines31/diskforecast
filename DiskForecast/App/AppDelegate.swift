import AppKit
import DiskForecastCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var disk = DiskStatus(supportFolder: Self.supportFolder)
    private let scan = ScanModel()
    private var statusItemController: StatusItemController?
    private lazy var cleanupWindow = HostedWindow(title: "Cleanup", size: NSSize(width: 720, height: 620)) {
        CleanupView(scan: self.scan, disk: self.disk) { self.systemDataWindow.show() }
    }
    private lazy var systemDataModel = SystemDataModel(disk: disk)
    private lazy var systemDataWindow = HostedWindow(title: "System Data", size: NSSize(width: 640, height: 640)) {
        SystemDataView(model: self.systemDataModel)
    }

    static var supportFolder: URL {
        URL.applicationSupportDirectory.appending(path: Brand.supportFolderName)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.registerDefaults()
        statusItemController = StatusItemController(disk: disk, scan: scan)
        statusItemController?.openCleanup = { [weak self] in self?.cleanupWindow.show() }
        statusItemController?.openSystemData = { [weak self] in self?.systemDataWindow.show() }
        disk.onChange = { [weak self] in self?.statusItemController?.update() }
        scan.onChange = { [weak self] in self?.statusItemController?.update() }
        disk.start()
        scan.start()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.disk.refresh() }
        }
    }
}
