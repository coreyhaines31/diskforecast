import DiskForecastCore
import PanelKit
import SwiftUI

/// The Brushed card at the top of the menu: a percent-full meter on the metal fascia, then the
/// days-to-full counter with the forecast phrase. Clicking it opens the Forecast window.
struct MenuCardView: View {
    static let width: CGFloat = 380
    private static let volumeName = (try? URL(filePath: "/").resourceValues(forKeys: [.volumeNameKey]))?
        .volumeName ?? "Macintosh HD"

    let disk: DiskStatus
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
