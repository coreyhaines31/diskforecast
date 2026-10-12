import Charts
import SwiftUI

/// Free space over time as a filled line, with the forecast as a dashed line to where the disk
/// would be full. The compact style drops the axes for the menu.
struct ForecastChart: View {
    let series: ForecastSeries
    var compact = false

    var body: some View {
        Chart {
            ForEach(series.history) { point in
                AreaMark(x: .value("Day", point.date), y: .value("Free", point.gigabytes))
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Color.accentColor.opacity(0.28), Color.accentColor.opacity(0.03)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                LineMark(
                    x: .value("Day", point.date), y: .value("Free", point.gigabytes),
                    series: .value("Line", "Free space")
                )
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: compact ? 1.5 : 2))
            }
            ForEach(series.projection) { point in
                LineMark(
                    x: .value("Day", point.date), y: .value("Free", point.gigabytes),
                    series: .value("Line", "Forecast")
                )
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: compact ? 1.5 : 2, dash: [4, 4]))
            }
            if let today = series.history.last {
                PointMark(x: .value("Day", today.date), y: .value("Free", today.gigabytes))
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(compact ? 18 : 44)
            }
            if !compact, let lowest = series.lowest, lowest.date != series.history.last?.date {
                PointMark(x: .value("Day", lowest.date), y: .value("Free", lowest.gigabytes))
                    .foregroundStyle(.secondary)
                    .symbolSize(30)
                    .annotation(position: .top, alignment: .center, spacing: 6) {
                        Text("Lowest").font(.caption2).foregroundStyle(.secondary)
                    }
            }
            if let full = series.fullDate, full <= series.end {
                PointMark(x: .value("Day", full), y: .value("Free", 0))
                    .foregroundStyle(.red)
                    .symbolSize(compact ? 18 : 44)
                    .annotation(position: .top, alignment: .trailing, spacing: 4) {
                        if !compact {
                            Text("Full").font(.caption.weight(.semibold)).foregroundStyle(.red)
                        }
                    }
            }
        }
        .chartXScale(domain: series.start...series.end)
        .chartYScale(domain: 0...max(1, series.peakGigabytes * 1.15))
        .chartXAxis {
            if !compact {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), collisionResolution: .greedy)
                }
            }
        }
        .chartPlotStyle { plot in plot.padding(.trailing, compact ? 4 : 12) }
        .chartYAxis {
            if !compact {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let gigabytes = value.as(Double.self) {
                            Text("\(Int(gigabytes)) GB")
                        }
                    }
                }
            }
        }
        .accessibilityLabel("Free space over time")
    }
}
