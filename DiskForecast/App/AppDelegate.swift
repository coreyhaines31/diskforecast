import AppKit
import DiskForecastCore
import PanelKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var disk = DiskStatus(supportFolder: Self.supportFolder)
    private let scan = ScanModel()
    private let updater = Updater()
    private lazy var settingsWindow = SettingsWindow(updater: updater, scan: scan)
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

    private lazy var snapshots = FolderSnapshotStore(folder: Self.supportFolder.appending(path: "Snapshots"))
    private lazy var forecastWindow = HostedWindow(title: "Forecast", size: NSSize(width: 680, height: 760)) {
        ForecastView(disk: self.disk, scan: self.scan, snapshots: self.snapshots) { self.systemDataWindow.show() }
    }

    private var cliServer: CLIServer?
    private lazy var notifier = Notifier(disk: disk, scan: scan, snapshots: snapshots)

    static var supportFolder: URL {
        #if DEBUG
        if DemoMode.isOn { return DemoMode.supportFolder }
        #endif
        return URL.applicationSupportDirectory.appending(path: Brand.supportFolderName)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Preferences.registerDefaults()
        PanelFont.register()
        #if !DEBUG
        applyLaunchAtLoginDefault()
        #endif
        #if DEBUG
        if DemoMode.isOn { DemoMode.prepare(home: scan.home) }
        #endif
        statusItemController = StatusItemController(disk: disk, scan: scan, snapshots: snapshots, updater: updater)
        statusItemController?.openCleanup = { [weak self] in self?.cleanupWindow.show() }
        statusItemController?.openSystemData = { [weak self] in self?.systemDataWindow.show() }
        statusItemController?.openForecast = { [weak self] in self?.forecastWindow.show() }
        notifier.openCleanup = { [weak self] in self?.cleanupWindow.show() }
        disk.onChange = { [weak self] in
            self?.statusItemController?.update()
            self?.notifier.check()
        }
        scan.onChange = { [weak self] in self?.statusItemController?.update() }
        scan.onFinished = { [weak self] result in self?.recordSnapshot(of: result) }
        statusItemController?.grantAccess = { [weak self] in self?.onboardingWindow.show() }
        statusItemController?.openSettings = { [weak self] in self?.settingsWindow.show() }
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.statusItemController?.update() }
        }
        disk.start()
        startCLIServer()
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
        #if DEBUG
        if DemoMode.isOn { showForDemo() }
        #endif
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.disk.refresh() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        cliServer?.stop()
    }

    /// Answers the `diskforecast` command.
    private func startCLIServer() {
        #if DEBUG
        if DemoMode.isOn { return }
        #endif
        let commands = CLICommands(disk: disk, scan: scan, snapshots: snapshots) { [weak self] window in
            switch window {
            case .forecast: self?.forecastWindow.show()
            case .cleanup: self?.cleanupWindow.show()
            case .systemData: self?.systemDataWindow.show()
            case .settings: self?.settingsWindow.show()
            }
        }
        cliServer = CLIServer { await commands.handle($0) }
        cliServer?.start()
    }

    #if DEBUG
    /// Opens what the README image needs once the demo data is loaded.
    private func showForDemo() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in
            switch DemoMode.show {
            case "menu":
                DemoMode.captureAndQuit(windowTitled: nil)
                statusItemController?.button?.performClick(nil)
            case "forecast":
                forecastWindow.show()
                DemoMode.captureAndQuit(windowTitled: "Forecast")
            case "cleanup":
                cleanupWindow.show()
                DemoMode.captureAndQuit(windowTitled: "Cleanup")
            case "settings":
                settingsWindow.show()
                DemoMode.captureAndQuit(windowTitled: "General")
            default: break
            }
        }
    }
    #endif

    /// Turns on launch at login once, so the daily readings survive a restart. Tries again next launch if it fails.
    /// Debug builds skip it so a DerivedData copy never becomes the login item.
    private func applyLaunchAtLoginDefault() {
        guard !Preferences.appliedLaunchAtLoginDefault else { return }
        guard (try? SMAppService.mainApp.register()) != nil else { return }
        Preferences.appliedLaunchAtLoginDefault = true
    }

    /// Saves today's folder sizes, with the System Data that's quick to read, so later scans can say
    /// what grew.
    private func recordSnapshot(of result: ScanResult) {
        disk.refresh()
        let unmeasured = result.skippedPaths + result.stalledPaths + result.deniedSamples
        // Saved first without swap and the snapshot count, so a slow command can't hold up the day's reading.
        let snapshot = FolderSnapshot(
            tree: result.tree, freeBytes: disk.freeBytes,
            systemData: SystemDataReading(purgeableBytes: disk.purgeableBytes, localSnapshotCount: nil),
            at: Date(), unmeasured: unmeasured
        )
        try? snapshots.save(snapshot)
        Task {
            var updated = snapshot
            let swap = await Shell.run("/usr/sbin/sysctl", ["vm.swapusage"])
            if let usage = Swap.parse(swap.text) {
                updated.systemData?.swapBytes = usage.totalBytes
                try? snapshots.save(updated)
            }
            let listed = await Shell.run("/usr/bin/tmutil", ["listlocalsnapshots", "/"])
            guard listed.succeeded else { return }
            updated.systemData?.localSnapshotCount = LocalSnapshots.parse(listed.text).count
            try? snapshots.save(updated)
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
