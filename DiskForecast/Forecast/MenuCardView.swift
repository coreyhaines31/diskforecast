import DiskForecastCore
import PanelKit
import SwiftUI

/// The Brushed card at the top of the menu: a percent-full meter on the metal fascia, the
/// days-to-full counter with the forecast phrase, then the last 30 days and the forecast as a
/// small chart. Clicking it opens the Forecast window.
struct MenuCardView: View {
    static let width: CGFloat = 380
    private static let volumeName = (try? URL(filePath: "/").resourceValues(forKeys: [.volumeNameKey]))?
        .volumeName ?? "Macintosh HD"

    private static let dayFormat = Date.FormatStyle.dateTime.month(.abbreviated).day()

    let disk: DiskStatus
    let grewMost: (name: String, bytes: Int64)?
    let open: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = PanelTheme.resolve(colorScheme)
        VStack(alignment: .leading, spacing: 0) {
            Fascia(nameplate: "Disk", timestamp: capacityLine, detail: Self.volumeName, label: "Free space") {
                Meter(Self.meter, value: percentFull, accessibilityValue: "\(percentFullWhole) percent full")
            }
            Counter(daysDigits, title: "Days to full", message: disk.forecastPhrase, messageIsAlarm: isLow)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Days to full")
                .accessibilityValue(disk.forecastPhrase)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            let series = ForecastSeries(disk: disk, days: 30)
            if series.history.count >= 2 {
                chartHeader(theme)
                ForecastChart(chartConfig(series))
                if let grewMost {
                    HStack(spacing: 4) {
                        Text("Grew most this week:")
                        Text(grewMost.name).lineLimit(1).truncationMode(.middle)
                        Text((grewMost.bytes > 0 ? "+" : "−") + Bytes.format(abs(grewMost.bytes))).monospacedDigit()
                    }
                    .font(PanelFont.body(11.5))
                    .foregroundStyle(theme.sub)
                    .padding(.horizontal, 14)
                    .padding(.top, 2)
                    .padding(.bottom, 10)
                }
            }
        }
        .background(theme.background)
        .foregroundStyle(theme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.black.opacity(theme.isDark ? 0.5 : 0.12), lineWidth: 1)
        )
        .panelAccent(PanelAccent.diskForecast)
        .padding(.horizontal, 5)
        .padding(.bottom, 5)
        .frame(width: Self.width)
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
    }

    /// "Free space" with the way into the Forecast window, styled like a PanelKit section header.
    private func chartHeader(_ theme: PanelTheme) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Free space")
                .font(PanelFont.condensed(10, .semibold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(theme.sub)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Text("Open Forecast…")
                .font(PanelFont.body(11, .medium))
                .foregroundStyle(theme.isDark ? Color(red: 0.56, green: 0.69, blue: 1) : PanelAccent.diskForecast)
                .accessibilityAddTraits(.isButton)
        }
        .padding(.top, 12)
        .padding(.bottom, 6)
        .padding(.horizontal, 14)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.line).frame(height: 1)
        }
    }

    /// Space used over the range, rising towards capacity, with the dashed forecast to full.
    private func chartConfig(_ series: ForecastSeries) -> ForecastConfig {
        let capacity = Double(disk.capacityBytes) / 1_000_000_000
        let used = series.history.map { capacity - $0.gigabytes }
        let lowest = used.min() ?? 0
        let span = max(series.end.timeIntervalSince(series.start), 1)
        let today = series.history.last?.date ?? series.end
        let full = series.fullDate.flatMap { $0 <= series.end ? $0 : nil }
        var endLabel: String?
        if let full {
            endLabel = "Full \(full.formatted(Self.dayFormat))"
        } else if !series.projection.isEmpty {
            endLabel = series.end.formatted(Self.dayFormat)
        }
        let todayPosition = min(max(today.timeIntervalSince(series.start) / span, 0.05), 0.955)
        var config = ForecastConfig(
            history: used,
            lowerBound: max(0, lowest - (capacity - lowest) * 0.4),
            limit: capacity,
            todayPosition: todayPosition,
            startLabel: series.start.formatted(Self.dayFormat),
            // Today sits under the end label when the disk fills within days, so it gives way.
            todayLabel: endLabel != nil && todayPosition > 0.72 ? "" : "Today",
            endLabel: endLabel,
            limitLabel: Bytes.format(disk.capacityBytes),
            endIsAlarm: full != nil,
            accessibilityLabel: "Space used over the last 30 days. \(disk.forecastPhrase)"
        )
        config.projection = series.projection.last.map { capacity - $0.gigabytes }
        return config
    }

    private static let meter = MeterConfig(
        majorTicks: 5, minorTicks: 4, zones: [0.9...1],
        labels: [
            .init(0, "0"), .init(0.2, "20"), .init(0.4, "40"), .init(0.6, "60"), .init(0.8, "80"), .init(1, "100")
        ],
        word: "% FULL", wordSize: 20, accessibilityLabel: "Disk meter"
    )

    private var percentFull: Double {
        disk.capacityBytes > 0 ? 1 - disk.percentFree : 0
    }

    private var percentFullWhole: Int { Int((percentFull * 100).rounded()) }

    private var isLow: Bool { disk.lowSpaceWarning != nil }

    /// "142 GB free of 494 GB", the line that used to head the menu.
    private var capacityLine: String {
        "\(Bytes.format(disk.freeBytes)) free of \(Bytes.format(disk.capacityBytes))"
    }

    /// Days until full on the drum, or dashes while learning, steady or gaining.
    private var daysDigits: String {
        guard case .filling(let days, _) = disk.outlook, days < 999.5 else { return "---" }
        return String(format: "%03d", max(0, Int(days.rounded())))
    }
}
