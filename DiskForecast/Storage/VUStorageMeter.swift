import DiskForecastCore
import PanelKit
import SwiftUI

/// The VU view: the card's fascia meter already shows percent full, so this adds one engraved row
/// per category, largest first, with a tape scaled to the largest.
struct VUStorageMeter: View {
    let reading: StorageReading
    let state: StorageMeterState
    let legend: [StorageLegendEntry]

    @Environment(\.panelTheme) private var theme

    var body: some View {
        Group {
            if reading.breakdown == nil {
                Text(reading.measuring)
                    .font(PanelFont.body(12))
                    .foregroundStyle(theme.sub)
                    .padding(.vertical, 6)
            } else {
                rows
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Storage meter")
        .accessibilityValue(reading.spokenSummary)
    }

    private var rows: some View {
        let largest = legend.map(\.bytes).max() ?? 0
        return VStack(spacing: 0) {
            ForEach(legend) { entry in
                let isLast = entry.id == legend.last?.id
                let dimmed = state.highlighted.map { $0 != entry.category } ?? false
                StorageLegendButton(entry: entry, state: state) {
                    HStack(spacing: 8) {
                        StorageLED(
                            color: entry.category == .trash && entry.bytes > 0 ? theme.stop : theme.color(for: .off),
                            glows: entry.category == .trash && entry.bytes > 0
                        )
                        .frame(width: 10)
                        Text(entry.title)
                            .font(PanelFont.body(12.5, .medium))
                            .foregroundStyle(theme.ink)
                            .lineLimit(1)
                            .frame(width: 118, alignment: .leading)
                        Tape(largest > 0 ? max(0.015, Double(entry.bytes) / Double(largest)) : 0)
                            .accessibilityHidden(true)
                        // The highlighted row also names its share of the disk.
                        Text(state.highlighted == entry.category && entry.bytes > 0
                             ? "\(entry.size) · \(entry.percentOfDisk)%" : entry.size)
                            .font(PanelFont.body(11.5).monospacedDigit())
                            .foregroundStyle(theme.ink2)
                            .lineLimit(1)
                            .fixedSize()
                            .frame(minWidth: 58, alignment: .trailing)
                    }
                    .padding(.horizontal, 4)
                    .frame(minHeight: 22)
                    .opacity(dimmed ? 0.45 : 1)
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(isLast ? .clear : theme.line).frame(height: 1)
                }
            }
        }
        .padding(.horizontal, -4)
    }
}
