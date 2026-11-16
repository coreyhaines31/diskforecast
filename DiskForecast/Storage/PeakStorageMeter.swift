import DiskForecastCore
import PanelKit
import SwiftUI

/// The Peak meter: a 50 x 5 dot-matrix LED bar in a black recess, amber for used space, red for
/// the Trash and dark for free space, over a three-column legend.
struct PeakStorageMeter: View {
    static let columnCount = 50
    static let rowCount = 5

    let reading: StorageReading
    let state: StorageMeterState
    let legend: [StorageLegendEntry]

    @Environment(\.panelTheme) private var theme

    var body: some View {
        let highlighted = legend.first { $0.category == state.highlighted }
        VStack(alignment: .leading, spacing: 8) {
            Text(reading.readout(highlighting: highlighted))
                .font(PanelFont.body(12, highlighted == nil ? .regular : .medium))
                .foregroundStyle(highlighted == nil ? theme.sub : theme.ink)
                .lineLimit(1)
                .accessibilityHidden(true)
            recess
            if reading.breakdown == nil {
                Text(reading.measuring)
                    .font(PanelFont.body(12))
                    .foregroundStyle(theme.sub)
                    .padding(.vertical, 4)
            } else {
                legendGrid
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private var recess: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return VStack(spacing: 6) {
            TimelineView(.animation(minimumInterval: 1 / 60, paused: !state.isDraining)) { time in
                PeakDots(
                    columns: columns,
                    drain: drainColumns,
                    drainProgress: state.drainProgress(at: time.date),
                    highlighted: state.highlighted,
                    isMeasuring: reading.breakdown == nil,
                    used: theme.caution,
                    trash: theme.stop
                )
            }
            .aspectRatio(PeakDots.aspectRatio(boundaries: boundaryCount), contentMode: .fit)
            .accessibilityElement()
            .accessibilityLabel("Storage meter")
            .accessibilityValue(reading.spokenSummary)
            scale
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 7)
        .background {
            shape.fill(Color(white: 0.043).shadow(.inner(color: .black.opacity(0.85), radius: 3, y: 2)))
                .shadow(color: .white.opacity(theme.isDark ? 0.07 : 0.6), radius: 0, y: 1)
        }
        .overlay {
            shape.strokeBorder(.black.opacity(theme.isDark ? 0.6 : 0.35), lineWidth: 0.5)
        }
    }

    /// 0, a quarter, half and three quarters of the disk, then its size.
    private var scale: some View {
        let quarter = Double(reading.capacityBytes) / 4 / 1_000_000_000
        let marks = (0..<4).map { "\(Int((quarter * Double($0)).rounded()))" } + [Bytes.format(reading.capacityBytes)]
        return HStack {
            ForEach(marks.indices, id: \.self) { index in
                if index > 0 { Spacer(minLength: 0) }
                Text(marks[index])
            }
        }
        .font(PanelFont.condensed(9, .semibold))
        .tracking(9 * 0.2)
        .foregroundStyle(Color(white: 0.44))
        .accessibilityHidden(true)
    }

    private var legendGrid: some View {
        let rows = stride(from: 0, to: legend.count, by: 3).map { Array(legend[$0..<min($0 + 3, legend.count)]) }
        return Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 0) {
            ForEach(rows.indices, id: \.self) { index in
                GridRow {
                    ForEach(rows[index]) { entry in legendItem(entry) }
                    ForEach(rows[index].count..<3, id: \.self) { _ in Color.clear.frame(height: 1) }
                }
            }
        }
        .padding(.horizontal, -5)
    }

    private func legendItem(_ entry: StorageLegendEntry) -> some View {
        let dimmed = state.highlighted.map { $0 != entry.category } ?? false
        return StorageLegendButton(entry: entry, state: state) {
            // The size sits under the name, so "System and other" fits a third of the card.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                StorageLED(color: ledColor(entry), glows: entry.bytes > 0)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.title)
                        .font(PanelFont.body(11.5, .medium))
                        .foregroundStyle(theme.ink)
                    Text(entry.size)
                        .font(PanelFont.body(11).monospacedDigit())
                        .foregroundStyle(theme.sub)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .opacity(dimmed ? 0.45 : 1)
        }
    }

    private func ledColor(_ entry: StorageLegendEntry) -> Color {
        guard entry.bytes > 0 else { return theme.color(for: .off) }
        return entry.category == .trash ? theme.stop : theme.caution
    }

    private var columns: [StorageCategory?] {
        if let breakdown = reading.breakdown {
            return breakdown.columns(Self.columnCount)
        }
        let lit = Int((reading.fractionUsed * Double(Self.columnCount)).rounded())
        return (0..<Self.columnCount).map { $0 < lit ? .other : nil }
    }

    /// The columns the emptied Trash lit, just past used space, while they drain.
    private var drainColumns: Range<Int>? {
        guard reading.breakdown?.bytes(of: .trash) == 0, let bytes = state.recentlyEmptied(),
              reading.capacityBytes > 0 else { return nil }
        let start = columns.firstIndex(of: nil) ?? Self.columnCount
        let count = max(1, Int((Double(bytes) / Double(reading.capacityBytes) * Double(Self.columnCount)).rounded()))
        return start..<min(Self.columnCount, start + count)
    }

    private var boundaryCount: Int {
        zip(columns, columns.dropFirst()).filter { $0 != nil && $1 != nil && $0 != $1 }.count
    }
}

/// The dots themselves, drawn in one canvas. A gap opens where one category meets the next.
struct PeakDots: View {
    static let gapRatio: CGFloat = 0.36
    static let boundaryRatio: CGFloat = 0.5
    static let off = Color(white: 0.165)

    let columns: [StorageCategory?]
    let drain: Range<Int>?
    let drainProgress: Double?
    let highlighted: StorageCategory?
    let isMeasuring: Bool
    let used: Color
    let trash: Color

    /// Width over height for the grid, in dot units.
    static func aspectRatio(boundaries: Int) -> CGFloat {
        let columns = CGFloat(PeakStorageMeter.columnCount)
        let rows = CGFloat(PeakStorageMeter.rowCount)
        let width = columns + (columns - 1) * gapRatio + CGFloat(boundaries) * boundaryRatio
        return width / (rows + (rows - 1) * gapRatio)
    }

    var body: some View {
        Canvas { context, size in
            let boundaries = zip(columns, columns.dropFirst()).filter { $0 != nil && $1 != nil && $0 != $1 }.count
            let units = CGFloat(columns.count) + CGFloat(columns.count - 1) * Self.gapRatio
                + CGFloat(boundaries) * Self.boundaryRatio
            let dot = size.width / units
            let pitch = dot * (1 + Self.gapRatio)
            var glow = context
            glow.addFilter(.blur(radius: dot * 0.55))
            var x: CGFloat = 0
            var draining: [CGRect] = []
            for (index, owner) in columns.enumerated() {
                if index > 0, let owner, let previous = columns[index - 1], owner != previous {
                    x += dot * Self.boundaryRatio
                }
                for row in 0..<PeakStorageMeter.rowCount {
                    let rect = CGRect(x: x, y: CGFloat(row) * pitch, width: dot, height: dot)
                    let circle = Path(ellipseIn: rect)
                    guard let owner else {
                        context.fill(circle, with: .color(Self.off))
                        if let drain, drain.contains(index) { draining.append(rect) }
                        continue
                    }
                    let color = owner == .trash ? trash : used
                    if isMeasuring {
                        context.fill(circle, with: .color(color.opacity(0.35)))
                    } else if let highlighted, highlighted != owner {
                        context.fill(circle, with: .color(Self.off))
                        context.fill(circle, with: .color(color.opacity(0.28)))
                    } else {
                        glow.fill(Path(ellipseIn: rect.insetBy(dx: -dot * 0.15, dy: -dot * 0.15)),
                                  with: .color(color.opacity(0.75)))
                        context.fill(circle, with: .color(color))
                    }
                }
                x += pitch
            }
            if let drainProgress {
                drawDrain(draining, dot: dot, progress: drainProgress, in: &context)
            }
        }
    }

    /// Each Trash dot floats up and fades, on its own short delay, as in the design.
    private func drawDrain(_ rects: [CGRect], dot: CGFloat, progress: Double, in context: inout GraphicsContext) {
        let elapsed = progress * StorageMeterState.drainDuration
        let travel = dot * 3
        for (index, rect) in rects.enumerated() {
            let column = index / PeakStorageMeter.rowCount
            let row = index % PeakStorageMeter.rowCount
            let delay = Double((column * 7 + row * 13) % 11) * 0.07
            let raw = min(1, max(0, (elapsed - delay) / 0.9))
            let eased = raw * raw
            let scale = 1 - 0.6 * eased
            let moved = CGRect(
                x: rect.midX + travel * 0.17 * eased - rect.width * scale / 2,
                y: rect.midY - travel * eased - rect.height * scale / 2,
                width: rect.width * scale, height: rect.height * scale
            )
            context.fill(Path(ellipseIn: moved), with: .color(trash.opacity(1 - eased)))
        }
    }
}
