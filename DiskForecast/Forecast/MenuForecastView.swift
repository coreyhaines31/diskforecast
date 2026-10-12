import SwiftUI

/// The small chart at the top of the menu: the last 30 days and the forecast, no axes.
struct MenuForecastView: View {
    let disk: DiskStatus
    let open: () -> Void

    var body: some View {
        let series = ForecastSeries(disk: disk, days: 30)
        VStack(alignment: .leading, spacing: 6) {
            if series.history.count >= 2 {
                ForecastChart(series: series, compact: true)
                    .frame(height: 64)
                HStack {
                    Text("\(series.caption(days: 30)) · \(Bytes.format(disk.freeBytes)) free now")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Open Forecast…").foregroundStyle(Color.accentColor)
                }
                .font(.caption)
            }
                    .font(.caption)
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
