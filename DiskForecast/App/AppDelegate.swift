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
    private var accessTimer: Timer?
    private lazy var onboardingWindow = HostedWindow(
        title: "Welcome to \(Brand.name)", size: NSSize(width: 500, height: 380), resizable: false
    ) {
        OnboardingView(openSettings: FullDiskAccess.openSettings) { self.finishOnboarding() }
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
        statusItemController?.grantAccess = { [weak self] in self?.onboardingWindow.show() }
        disk.start()
        if FullDiskAccess.isGranted || Preferences.onboardingDone {
            scan.start()
        } else {
            onboardingWindow.show()
            watchForAccess()
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkAccess() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.disk.refresh() }
        }
    }

    /// Polls while onboarding is open, since granting access in System Settings posts nothing.
    private func watchForAccess() {
        accessTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            MainActor.assumeIsolated { self.checkAccess() }
        }
    }

    private func checkAccess() {
        guard FullDiskAccess.isGranted else { return }
        if !Preferences.onboardingDone {
            finishOnboarding()
        } else if scan.result != nil && !scan.scannedWithFullDiskAccess && !scan.isScanning {
            scan.scan()
        }
    }

    private func finishOnboarding() {
        accessTimer?.invalidate()
        accessTimer = nil
        Preferences.onboardingDone = true
        onboardingWindow.close()
        scan.start()
    }
}
