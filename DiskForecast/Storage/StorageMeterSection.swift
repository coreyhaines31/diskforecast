import DiskForecastCore
import PanelKit
import SwiftUI

/// What the line under the meter says about the Trash, with the key that goes with it.
enum StorageFooter: Equatable {
    case trash(Int64)
    case emptied(Int64)
    case empty
    case activity(String)
    case needsAccess
}

/// What the meter shows: the categories once a scan has finished, or used space alone while one runs.
struct StorageReading {
    var breakdown: StorageBreakdown?
    var capacityBytes: Int64
    var usedBytes: Int64
    /// "Measuring… 1.2M files" while there are no categories to show.
    var measuring: String
    var footer: StorageFooter
}

/// The storage meter in the menu card: a section header, the Peak or VU meter with its legend,
/// and a footer about the Trash.
struct StorageMeterSection: View {
    let style: StorageMeterStyle
    let reading: StorageReading
    let state: StorageMeterState
    let emptyTrash: () -> Void
    let grantAccess: () -> Void

    @Environment(\.panelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Storage")
            switch style {
            case .peak: PeakStorageMeter(reading: reading, state: state, legend: legend)
            case .vuMeter: VUStorageMeter(reading: reading, state: state, legend: legend)
            }
            StorageFooterRow(footer: reading.footer, emptyTrash: emptyTrash, grantAccess: grantAccess)
        }
        .onAppear { state.startDrainIfPending(reduceMotion: reduceMotion) }
    }

    /// The categories to list: the shares, plus the Trash while it's draining or just emptied, so
    /// the legend keeps its size while the menu is open.
    private var legend: [StorageLegendEntry] {
        guard let breakdown = reading.breakdown else { return [] }
        let shares = style == .peak ? breakdown.shares : breakdown.bySize
        var entries = shares.map {
            StorageLegendEntry(
                category: $0.category, title: breakdown.title(of: $0.category),
                explanation: breakdown.explanation(of: $0.category), bytes: $0.bytes,
                capacityBytes: breakdown.capacityBytes
            )
        }
        if breakdown.bytes(of: .trash) == 0, state.recentlyEmptied() != nil {
            entries.append(StorageLegendEntry(
                category: .trash, title: StorageCategory.trash.title, explanation: StorageCategory.trash.explanation,
                bytes: 0, capacityBytes: breakdown.capacityBytes
            ))
        }
        return entries
    }
}

struct StorageLegendEntry: Identifiable {
    let category: StorageCategory
    let title: String
    let explanation: String
    let bytes: Int64
    let capacityBytes: Int64

    var id: StorageCategory { category }

    var size: String { bytes > 0 ? Bytes.format(bytes) : "Emptied" }

    var percentOfDisk: Int {
        capacityBytes > 0 ? Int((Double(bytes) / Double(capacityBytes) * 100).rounded()) : 0
    }

    /// "Photos · 64 GB, 13% of the disk".
    var share: String {
        let percent = percentOfDisk < 1 && bytes > 0 ? "under 1" : "\(percentOfDisk)"
        return "\(title) · \(Bytes.format(bytes)), \(percent)% of the disk"
    }
}

extension StorageReading {
    /// "352 GB of 494 GB used · 142 GB free".
    var usedLine: String {
        "\(Bytes.format(usedBytes)) of \(Bytes.format(capacityBytes)) used · "
            + "\(Bytes.format(max(0, capacityBytes - usedBytes))) free"
    }

    var fractionUsed: Double {
        capacityBytes > 0 ? min(1, Double(usedBytes) / Double(capacityBytes)) : 0
    }

    /// Used space then each category, largest first, for VoiceOver.
    var spokenSummary: String {
        var parts = ["\(Bytes.format(usedBytes)) of \(Bytes.format(capacityBytes)) used"]
        if let breakdown {
            parts.append(breakdown.bySize.map { "\(breakdown.title(of: $0.category)) \(Bytes.format($0.bytes))" }
                .joined(separator: ", "))
            if !breakdown.unmeasured.isEmpty {
                parts.append("Not measured: " + breakdown.unmeasured.map(\.title).joined(separator: ", "))
            }
        } else {
            parts.append(measuring)
        }
        return parts.joined(separator: ". ")
    }

    /// The line under the meter: the highlighted category's share, or used and free space.
    func readout(highlighting entry: StorageLegendEntry?) -> String {
        guard let entry, entry.bytes > 0 else { return usedLine }
        return entry.share
    }
}

/// A small status light, glowing when lit.
struct StorageLED: View {
    let color: Color
    var glows = true
    var size: CGFloat = 7

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: glows ? color.opacity(0.9) : .clear, radius: size * 0.4)
            .accessibilityHidden(true)
    }
}

/// One category in the legend: a real button that highlights the category in the meter, also
/// on hover.
struct StorageLegendButton<Label: View>: View {
    let entry: StorageLegendEntry
    let state: StorageMeterState
    @ViewBuilder let label: () -> Label

    @Environment(\.panelTheme) private var theme

    var body: some View {
        let isPinned = state.pinned == entry.category
        let isHovered = state.hovered == entry.category
        Button { state.toggle(entry.category) } label: {
            label()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 4)
                .fill(isPinned || isHovered ? theme.ink.opacity(theme.isDark ? 0.07 : 0.05) : .clear)
        }
        .onHover { state.hover(entry.category, $0) }
        .help(entry.explanation)
        .accessibilityLabel(entry.title)
        .accessibilityValue(entry.bytes > 0 ? "\(Bytes.format(entry.bytes)), \(entry.percentOfDisk) percent of the disk"
            : "Emptied")
        .accessibilityHint("Highlights it in the storage meter")
        .accessibilityAddTraits(isPinned ? .isSelected : [])
    }
}

/// The footer under the meter: what's in the Trash and a key to empty it, or what's missing.
struct StorageFooterRow: View {
    let footer: StorageFooter
    let emptyTrash: () -> Void
    let grantAccess: () -> Void

    @Environment(\.panelTheme) private var theme

    var body: some View {
        HStack(spacing: 9) {
            StorageLED(color: theme.color(for: status))
            Text(message)
                .font(PanelFont.body(11.5))
                .foregroundStyle(theme.sub)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            switch footer {
            case .trash:
                Button("Empty Trash…", action: emptyTrash)
                    .buttonStyle(PanelButtonStyle(.secondary, size: .compact))
                    .help("Asks before permanently deleting what's in the Trash")
            case .needsAccess:
                Button("Grant Access…", action: grantAccess)
                    .buttonStyle(PanelButtonStyle(.secondary, size: .compact))
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 9)
        .padding(.bottom, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.line).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var status: PanelStatus {
        switch footer {
        case .trash: .stop
        case .emptied, .empty: .go
        case .activity, .needsAccess: .caution
        }
    }

    private var message: String {
        switch footer {
        case .trash(let bytes): "The Trash is holding \(Bytes.format(bytes)) of things you've already deleted."
        case .emptied(let bytes): "Emptied the Trash. \(Bytes.format(bytes)) came back."
        case .empty: "The Trash is empty."
        case .activity(let text): text
        case .needsAccess: "Full Disk Access measures the Trash, Mail, Messages and the Photos library."
        }
    }
}
