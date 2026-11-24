import AppKit
import DiskForecastCore
import UserNotifications

/// Warns with a notification before the disk fills, since the menu only says so when it's open.
/// Clicking the notification opens Cleanup.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private let disk: DiskStatus
    private let scan: ScanModel
    private let snapshots: FolderSnapshotStore
    var openCleanup: () -> Void = {}

    init(disk: DiskStatus, scan: ScanModel, snapshots: FolderSnapshotStore) {
        self.disk = disk
        self.scan = scan
        self.snapshots = snapshots
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Sends an alert if one is due: a disk filling within minutes first, then one nearly out of
    /// space, then the daily alert.
    /// Cheap enough to call on every free-space reading.
    func check() {
        #if DEBUG
        if DemoMode.isOn { return }
        #endif
        guard Preferences.notifiesBeforeFull, disk.capacityBytes > 0 else { return }
        if let warning = FastFill.due(readings: disk.recentReadings, lastSent: Preferences.lastFastFillAlert) {
            // It already says space is low, so the daily alert waits a day rather than following a minute later.
            Preferences.lastFastFillAlert = Date()
            Preferences.lastDiskAlert = Date()
            // It names what's left too, so the floor it's already under doesn't get its own alert.
            Preferences.lastCriticalFloor = CriticalSpace.floor(under: disk.freeBytes) ?? Preferences.lastCriticalFloor
            send(warning.message(trashBytes: scan.trashBytes), identifier: "fastFill")
            return
        }
        let critical = CriticalSpace.decide(freeBytes: disk.freeBytes, lastFloor: Preferences.lastCriticalFloor)
        if critical.remembered != Preferences.lastCriticalFloor { Preferences.lastCriticalFloor = critical.remembered }
        if critical.alert != nil {
            Preferences.lastDiskAlert = Date()
            send(
                CriticalSpace.message(freeBytes: disk.freeBytes, trashBytes: scan.trashBytes), identifier: "critical"
            )
            return
        }
        guard let alert = DiskAlert.due(
            outlook: disk.outlook, freeBytes: disk.freeBytes, capacityBytes: disk.capacityBytes,
            lastSent: Preferences.lastDiskAlert
        ) else { return }
        Preferences.lastDiskAlert = Date()
        let message = alert.message(
            outlook: disk.outlook, freeBytes: disk.freeBytes,
            grewMost: SnapshotComparison.grewMostThisWeek(in: snapshots), trashBytes: scan.trashBytes
        )
        send(message, identifier: alert.rawValue)
    }

    /// A repeat with the same identifier replaces the earlier banner instead of stacking.
    private func send(_ message: (title: String, body: String), identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted { center.add(request) }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run { openCleanup() }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
