import SwiftUI

/// The small chart at the top of the menu: the last 30 days and the forecast, no axes.
struct MenuForecastView: View {
    private static let dayFormat = Date.FormatStyle.dateTime.month(.abbreviated).day()

    let disk: DiskStatus
    let grewMost: (name: String, bytes: Int64)?
    let open: () -> Void

    var body: some View {
        let series = ForecastSeries(disk: disk, days: 30)
        VStack(alignment: .leading, spacing: 4) {
            if series.history.count >= 2 {
                HStack {
                    Text("Free space").fontWeight(.semibold)
                    Spacer()
                    Text("Open Forecast…").foregroundStyle(Color.accentColor)
                }
                .font(.caption)
                ForecastChart(series: series, compact: true)
                    .frame(height: 72)
                HStack {
                    Text(series.start.formatted(Self.dayFormat))
                    Spacer()
                    Text(series.projection.isEmpty ? "Today" : series.end.formatted(Self.dayFormat))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                if let grewMost {
                    HStack(spacing: 4) {
                        Text("Grew most this week:").foregroundStyle(.secondary)
                        Text(grewMost.name).lineLimit(1).truncationMode(.middle)
                        DeltaText(delta: grewMost.bytes)
                    }
                    .font(.caption)
                    .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: 380, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
    }
}
