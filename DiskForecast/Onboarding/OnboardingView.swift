import DiskForecastCore
import SwiftUI

struct OnboardingView: View {
    let openSettings: () -> Void
    let continueWithHomeFolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "internaldrive").font(.system(size: 36)).foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text("Let \(Brand.name) see the whole disk").font(.title2.bold())
                    Text("Optional, and you can change it any time.").foregroundStyle(.secondary)
                }
            }
            Text("Full Disk Access lets \(Brand.name) measure the folders macOS guards, like Mail, Messages, "
                + "iCloud Drive, and other apps' containers. Without it, those folders are skipped and their "
                + "space shows up as unexplained.")
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                Label("Click Open System Settings.", systemImage: "1.circle")
                Label("Turn on \(Brand.name) in the list. If it's missing, click + and choose it.",
                      systemImage: "2.circle")
                Label("Come back here. \(Brand.name) notices on its own.", systemImage: "3.circle")
            }
            Text("\(Brand.name) only reads sizes and names. It sends nothing anywhere, and it never deletes "
                + "anything: whatever you clear goes to the Trash.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Continue with home folder only", action: continueWithHomeFolder)
                Spacer()
                Button("Open System Settings", action: openSettings)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500)
    }
}
