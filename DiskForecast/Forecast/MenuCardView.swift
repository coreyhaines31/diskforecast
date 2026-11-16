import DiskForecastCore
import PanelKit
import SwiftUI

/// The Brushed card at the top of the menu: a percent-full meter on the metal fascia, the
/// days-to-full counter with the forecast phrase, the last 30 days and the forecast as a small
/// chart, then the storage meter. Clicking above the storage meter opens the Forecast window.
struct MenuCardView: View {
    private static let volumeName = (try? URL(filePath: "/").resourceValues(forKeys: [.volumeNameKey]))?
        .volumeName ?? "Macintosh HD"

    private static let dayFormat = Date.FormatStyle.dateTime.month(.abbreviated).day()

    let disk: DiskStatus
    /// The menu's real width; the folder rows' size column makes it wider than PanelKit's 340.
    let menuWidth: CGFloat
    let grewMost: (name: String, bytes: Int64)?
    let storage: StorageMeterSection
    let open: () -> Void

    @Environment(\.panelTheme) private var theme

    var body: some View {
        MenuCard(accent: PanelAccent.diskForecast, menuWidth: menuWidth) {
            forecast
                .contentShape(Rectangle())
                .onTapGesture(perform: open)
            storage
        }
    }

    private var forecast: some View {
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
                SectionHeader("Free space", actionTitle: "Open Forecast…", action: open)
                ForecastChart(chartConfig(series))
                if let grewMost {
                    HStack(spacing: 4) {
                        Text("Grew most this week:")
                        Text(grewMost.name).lineLimit(1).truncationMode(.middle)
                        DeltaText(delta: grewMost.bytes)
                    }
                    .font(PanelFont.body(11.5))
                    .foregroundStyle(theme.sub)
                    .padding(.horizontal, 14)
                    .padding(.top, 2)
                    .padding(.bottom, 10)
                }
            }
        }
    }

    /// Space used over the range, rising towards capacity, with the dashed forecast to full. The
    /// labels over the line's start and today give free space, as the old menu chart did.
    private func chartConfig(_ series: ForecastSeries) -> ForecastConfig {
        let capacity = Double(disk.capacityBytes) / 1_000_000_000
        let points = series.history.map { ForecastPoint($0.date, capacity - $0.gigabytes) }
        let lowest = points.map(\.value).min() ?? 0
        let full = series.fullDate.flatMap { $0 <= series.end ? $0 : nil }
        var endLabel: String?
        if let full {
            endLabel = "Full \(full.formatted(Self.dayFormat))"
        } else if !series.projection.isEmpty {
            endLabel = series.end.formatted(Self.dayFormat)
        }
        return ForecastConfig(
            points: points,
            projection: series.projection.last.map { ForecastPoint($0.date, capacity - $0.gigabytes) },
            domain: series.start...max(series.end, series.start.addingTimeInterval(86_400)),
            lowerBound: max(0, lowest - (capacity - lowest) * 0.4),
            limit: capacity,
            startLabel: series.start.formatted(Self.dayFormat),
            endLabel: endLabel,
            limitLabel: Bytes.format(disk.capacityBytes),
            startValueLabel: series.history.first.map { Self.freeLabel($0.gigabytes) },
            todayValueLabel: series.history.last.map { Self.freeLabel($0.gigabytes) },
            endIsAlarm: full != nil,
            accessibilityLabel: "Space used over the last 30 days. \(disk.forecastPhrase)"
        )
    }

    private static func freeLabel(_ gigabytes: Double) -> String {
        "\(Bytes.format(Int64(gigabytes * 1_000_000_000))) free"
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
