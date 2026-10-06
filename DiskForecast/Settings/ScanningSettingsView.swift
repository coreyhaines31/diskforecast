import DiskForecastCore
import SwiftUI

struct ScanningSettingsView: View {
    let scan: ScanModel
    @AppStorage(Preferences.staleAfterDaysKey) private var staleAfterDays = 30
    @State private var hasFullDiskAccess = FullDiskAccess.isGranted

    var body: some View {
        Form {
            Section {
                Stepper(value: $staleAfterDays, in: 7...365, step: 7) {
                    LabeledContent("Old project after", value: "\(staleAfterDays) days")
                }
                .onChange(of: staleAfterDays) { scan.rebuildCleanupList() }
            } footer: {
                Text("Build folders in projects untouched this long are Safe to clear. Newer ones are Worth a look.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Full Disk Access") {
                    if hasFullDiskAccess {
                        Label("On", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Open System Settings", action: FullDiskAccess.openSettings)
                    }
                }
                LabeledContent("Last scan", value: lastScan)
                Button("Rescan Now") { scan.scan() }.disabled(scan.isScanning)
            } footer: {
                Text(hasFullDiskAccess
                    ? "\(Brand.name) can measure every folder in your home folder."
                    : "Without it, folders macOS guards (Mail, Messages, iCloud Drive, other apps' data) are skipped.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasFullDiskAccess = FullDiskAccess.isGranted
        }
    }

    private var lastScan: String {
        if case .scanning = scan.state { return "Scanning…" }
        guard let finished = scan.finishedAt, let result = scan.result else { return "Not yet" }
        let when = finished.formatted(date: .abbreviated, time: .shortened)
        return "\(when), \(result.fileCount.formatted()) files in \(Int(result.duration.rounded())) s"
    }
}
