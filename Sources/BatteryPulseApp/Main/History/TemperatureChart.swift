#if os(macOS)
import BatteryCore
import Charts
import SwiftUI

/// The battery's temperature, on a scale fitted to it.
struct TemperatureChart: View {
    let data: HistoryChartData
    /// The period on screen, for the time axis and the readout.
    let period: HistoryPeriod
    let domain: ClosedRange<Date>
    /// The hovered time, shared by the page's charts.
    @Binding var selection: Date?
    @Environment(\.tones) private var tones
    private let formatter = BatteryFormatter.app

    var body: some View {
        let line = tones.style(.chart(.temperature))
        Chart {
            ForEach(data.temperature) { value in
                LineMark(
                    x: .value("Time", value.time), y: .value("Temperature", value.value),
                    series: .value(ChartKey.segment, value.segment)
                )
                .foregroundStyle(line)
                .interpolationMethod(.monotone)
            }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let celsius = value.as(Double.self) { Text(formatter.celsius(celsius)) }
                }
            }
        }
        .chartXAxis { HistoryTimeAxis.marks(for: period) }
        .chartXSelection(value: $selection)
        .chartOverlay { proxy in
            SelectionOverlay(
                proxy: proxy, points: data.points, selection: $selection, showsDate: period == .week,
                value: { point in point.temperatureCelsius.map { formatter.celsius($0) } })
        }
        .frame(height: 140)
    }
}
#endif
