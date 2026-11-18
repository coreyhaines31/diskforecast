import DiskForecastCore
import SwiftUI

/// The folders that grew and shrank the most from scan to scan over the forecast's two weeks.
/// Only made while free space is swinging, since that's what it helps explain.
struct KeepsChanging {
    static let shown = 3

    let since: Date
    let until: Date
    let folders: [FolderChurn]

    var days: Int { FolderChurns.days(from: since, to: until) }

    init?(store: FolderSnapshotStore, outlook: Forecast.Outlook, now: Date = Date()) {
        guard case .swinging = outlook else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -Forecast.windowDays, to: now) ?? now
        let window = store.snapshots(since: start).filter { !$0.folders.isEmpty }
        let folders = FolderChurns.churn(in: window)
        guard let first = window.first, let last = window.last, !folders.isEmpty else { return nil }
        since = first.day
        until = last.day
        self.folders = Array(folders.prefix(Self.shown))
    }
}

/// The few folders that moved most, each with how far it moved and where it ended:
/// "moved 41 GB over 9 days, ended 2.0 GB up".
struct KeepsChangingView: View {
    let keepsChanging: KeepsChanging

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What keeps changing").font(.headline)
            Text("Free space is swinging. These folders grew and shrank the most from one scan to the next.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(keepsChanging.folders) { folder in
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down").foregroundStyle(.secondary).frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("~/" + folder.path).lineLimit(1).truncationMode(.middle)
                        Text(folder.summary(days: keepsChanging.days))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }
}
