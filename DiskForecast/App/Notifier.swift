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

    /// Sends an alert if one is due. Cheap enough to call on every free-space reading.
    func check() {
        #if DEBUG
        if DemoMode.isOn { return }
        #endif
        guard Preferences.notifiesBeforeFull, disk.capacityBytes > 0,
              let alert = DiskAlert.due(
                outlook: disk.outlook, freeBytes: disk.freeBytes, capacityBytes: disk.capacityBytes,
                lastSent: Preferences.lastDiskAlert
              )
        else { return }
        Preferences.lastDiskAlert = Date()
        let message = alert.message(
            outlook: disk.outlook, freeBytes: disk.freeBytes,
            grewMost: SnapshotComparison.grewMostThisWeek(in: snapshots), trashBytes: scan.trashBytes
        )
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        let request = UNNotificationRequest(identifier: alert.rawValue, content: content, trigger: nil)
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
