#if os(macOS)
import BatteryCore
import Charts
import SwiftUI

/// The charge line over the stretches on the power adapter. The legend sits under the chart, clear
/// of the axis labels and the hover readout.
struct ChargeChart: View {
    let data: HistoryChartData
    /// The period on screen, for the time axis and the readout.
    let period: HistoryPeriod
    let domain: ClosedRange<Date>
    /// The hovered time, shared by the page's charts.
    @Binding var selection: Date?
    @Environment(\.tones) private var tones
    private let formatter = BatteryFormatter.app

    var body: some View {
        let line = tones.style(.chart(.charge))
        VStack(alignment: .trailing, spacing: 6) {
            Chart {
                ForEach(data.spans) { span in
                    RectangleMark(
                        xStart: .value(ChartKey.start, span.start), xEnd: .value(ChartKey.end, span.end),
                        yStart: .value(ChartKey.bottom, 0), yEnd: .value(ChartKey.top, 100)
                    )
                    // Charging a little stronger than holding the charge.
                    .foregroundStyle(tones.style(span.kind == .charging ? .chargingSpan : .holdingSpan))
                    .accessibilityHidden(true)
                }
                ForEach(data.charge) { value in
                    LineMark(
                        x: .value("Time", value.time), y: .value("Charge", value.value),
                        series: .value(ChartKey.segment, value.segment)
                    )
                    .foregroundStyle(line)
                    .interpolationMethod(.monotone)
                }
            }
            .chartXScale(domain: domain)
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let percent = value.as(Double.self) { Text(formatter.percent(percent)) }
                    }
                }
            }
            .chartXAxis { HistoryTimeAxis.marks(for: period) }
            .chartXSelection(value: $selection)
            .chartOverlay { proxy in
                SelectionOverlay(
                    proxy: proxy, points: data.points, selection: $selection, showsDate: period == .week,
                    value: { point in point.percent.map { formatter.percent($0) } })
            }
            .frame(height: 200)
            Label("On power adapter", systemImage: "square.fill")
                .font(.caption)
                .foregroundStyle(tones.style(.spanLegend))
                .labelStyle(.titleAndIcon)
        }
    }
}
#endif
