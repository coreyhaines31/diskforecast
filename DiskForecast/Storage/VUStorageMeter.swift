import DiskForecastCore
import PanelKit
import SwiftUI

/// The VU meter: a needle at percent used with a red zone from 85%, then one engraved row per
/// category with a tape scaled to the largest.
struct VUStorageMeter: View {
    private static let meter = MeterConfig(
        size: CGSize(width: 312, height: 96), majorTicks: 5, minorTicks: 2, zones: [0.85...1],
        labels: [
            .init(0, "0"), .init(0.2, "20"), .init(0.4, "40"), .init(0.6, "60"), .init(0.8, "80"), .init(1, "100")
        ],
        word: "USED", wordSize: 15, accessibilityLabel: "Storage meter"
    )

    let reading: StorageReading
    let state: StorageMeterState
    let legend: [StorageLegendEntry]

    @Environment(\.panelTheme) private var theme

    var body: some View {
        let highlighted = legend.first { $0.category == state.highlighted }
        VStack(alignment: .leading, spacing: 0) {
            Meter(Self.meter, value: reading.fractionUsed, accessibilityValue: reading.spokenSummary)
                .frame(maxWidth: 250)
                .frame(maxWidth: .infinity)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Bytes.format(reading.usedBytes))
                    .font(PanelFont.condensed(20, .semibold))
                    .monospacedDigit()
                Text("of \(Bytes.format(reading.capacityBytes))")
                    .font(PanelFont.body(12))
                    .foregroundStyle(theme.sub)
                Spacer(minLength: 8)
                Text(highlighted.flatMap { $0.bytes > 0 ? $0.share : nil }
                    ?? "\(Bytes.format(max(0, reading.capacityBytes - reading.usedBytes))) free")
                    .font(PanelFont.body(11.5, highlighted == nil ? .regular : .medium))
                    .foregroundStyle(highlighted == nil ? theme.sub : theme.ink)
                    .lineLimit(1)
            }
            .padding(.top, 8)
            .padding(.bottom, 6)
            .accessibilityHidden(true)
            if reading.breakdown == nil {
                Text(reading.measuring)
                    .font(PanelFont.body(12))
                    .foregroundStyle(theme.sub)
                    .padding(.vertical, 6)
            } else {
                rows
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
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
                        Text(entry.size)
                            .font(PanelFont.body(11.5).monospacedDigit())
                            .foregroundStyle(theme.ink2)
                            .lineLimit(1)
                            .frame(width: 58, alignment: .trailing)
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
