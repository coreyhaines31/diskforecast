import DiskForecastCore
import SwiftUI

/// The Forecast window: free space over a chosen range, where it's heading, and the numbers
/// behind the forecast.
struct ForecastView: View {
    enum Range: Int, CaseIterable, Identifiable {
        case twoWeeks = 14, month = 30, months = 120

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .twoWeeks: "2 Weeks"
            case .month: "30 Days"
            case .months: "4 Months"
            }
        }
    }

    let disk: DiskStatus
    @State private var range = Range.month

    var body: some View {
        let series = ForecastSeries(disk: disk, days: range.rawValue)
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Bytes.format(disk.freeBytes)) free")
                        .font(.system(size: 28, weight: .semibold))
                    Text("of \(Bytes.format(disk.capacityBytes)) · \(disk.forecastPhrase)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(Range.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            if series.history.count < 2 {
                ContentUnavailableView(
                    "The chart fills in day by day",
                    systemImage: "chart.xyaxis.line",
                    description: Text(
                        "\(Brand.name) saves one reading a day. Come back tomorrow to see the first line."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForecastChart(series: series)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                facts(series)
            }
            Text(Self.footnote)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 440)
    }

    private func facts(_ series: ForecastSeries) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 6) {
            GridRow {
                fact("Typical day", value: dailyChange(series.bytesPerDay))
                fact("Lowest in range", value: series.lowest.map(Self.lowestText) ?? "—")
                fact("Full by", value: series.fullDate?.formatted(.dateTime.month(.abbreviated).day().year())
                    ?? "Not filling up")
            }
        }
    }

    private static let footnote = "Free space is checked every hour and saved once a day. The forecast follows "
        + "the typical daily change over the last two weeks, so one big download or cleanup doesn't set it. "
        + "Your history stays on this Mac."

    private static func lowestText(_ point: ForecastSeries.Point) -> String {
        let bytes = Bytes.format(Int64(point.gigabytes * 1_000_000_000))
        return "\(bytes) on \(point.date.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func fact(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.body.monospacedDigit())
        }
    }

    private func dailyChange(_ bytesPerDay: Double?) -> String {
        guard let bytesPerDay else { return "Needs \(Forecast.minimumDays) days" }
        if abs(bytesPerDay) < 100_000_000 { return "About the same" }
        let amount = Bytes.format(Int64(abs(bytesPerDay)))
        return bytesPerDay < 0 ? "\(amount) less free" : "\(amount) more free"
    }
}
