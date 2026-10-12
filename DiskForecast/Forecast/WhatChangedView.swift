import AppKit
import DiskForecastCore
import SwiftUI

/// Two folder snapshots to compare: the earliest in the chart's range and the latest.
struct SnapshotComparison {
    let old: FolderSnapshot
    let new: FolderSnapshot

    init?(store: FolderSnapshotStore, since date: Date) {
        guard let new = store.latest(), let old = store.baseline(since: date) else { return nil }
        self.old = old
        self.new = new
    }

    var outsideHome: Int64 { FolderChanges.outsideHomeDelta(from: old, to: new) }

    func changes(under parent: String = "") -> [FolderChange] {
        FolderChanges.changes(from: old, to: new, under: parent)
    }
}

/// Which folders grew or shrank between two scans, biggest change first. Each folder opens to
/// show which of its folders did it.
struct WhatChangedView: View {
    let comparison: SnapshotComparison?
    let home: String
    let openSystemData: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let comparison {
                Text("What changed since \(comparison.old.day.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.headline)
                let top = comparison.changes()
                let outside = comparison.outsideHome
                if top.isEmpty && abs(outside) < 1_000_000_000 {
                    Text("No folder changed by more than 500 MB.")
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(top) { ChangeRow(change: $0, comparison: comparison, home: home) }
                        if abs(outside) >= 1_000_000_000 {
                            outsideRow(outside)
                        }
                    }
                    .listStyle(.bordered)
                    .frame(minHeight: 150)
                }
            } else {
                Text("What changed").font(.headline)
                Text(
                    "\(Brand.name) saves folder sizes after each scan and compares them over time. "
                        + "It needs scans from two different days, so check back tomorrow."
                )
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func outsideRow(_ delta: Int64) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "gearshape").foregroundStyle(.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text("Outside your home folder")
                Text("System Data, other accounts, and apps").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            DeltaText(delta: delta)
            Button("System Data…", action: openSystemData).controlSize(.small)
        }
    }
}

private struct ChangeRow: View {
    let change: FolderChange
    let comparison: SnapshotComparison
    let home: String

    var body: some View {
        if change.hasChildren {
            DisclosureGroup {
                ForEach(comparison.changes(under: change.path)) {
                    ChangeRow(change: $0, comparison: comparison, home: home)
                }
            } label: {
                label
            }
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: 8) {
            Image(systemName: change.isGone ? "folder.badge.minus" : "folder")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(change.path.contains("/") ? change.name : "~/" + change.path)
                .lineLimit(1)
                .truncationMode(.middle)
            if change.isNew {
                Text("New")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.orange.opacity(0.18), in: Capsule())
                    .foregroundStyle(.orange)
            }
            Spacer()
            DeltaText(delta: change.delta)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: home + "/" + change.path)])
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Show in Finder")
            .disabled(change.isGone)
        }
    }
}

/// "+88 GB" in orange when space was used, "−2 GB" in green when it came back.
struct DeltaText: View {
    let delta: Int64

    var body: some View {
        Text((delta > 0 ? "+" : "−") + Bytes.format(abs(delta)))
            .monospacedDigit()
            .foregroundStyle(delta > 0 ? Color.orange : Color.green)
    }
}
