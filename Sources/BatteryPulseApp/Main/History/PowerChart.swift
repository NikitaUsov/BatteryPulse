#if os(macOS)
import BatteryCore
import Charts
import SwiftUI

/// The power into the battery and the Mac's load. A device has the battery's line alone.
struct PowerChart: View {
    let data: HistoryChartData
    /// The period on screen, for the time axis and the readout.
    let period: HistoryPeriod
    let domain: ClosedRange<Date>
    /// Off for a device: no legend naming the Mac.
    let showsLegend: Bool
    /// The hovered time, shared by the page's charts.
    @Binding var selection: Date?
    @Environment(\.tones) private var tones
    private let formatter = BatteryFormatter.app

    var body: some View {
        let battery = String(localized: "Battery")
        let mac = String(localized: "Mac")
        let isMonochrome = tones.isMonochrome
        let plot = Chart {
            ForEach(data.power) { value in
                Self.line(value, name: value.line == .battery ? battery : mac, isMonochrome: isMonochrome)
            }
            RuleMark(y: .value(ChartKey.zero, 0))
                .foregroundStyle(.secondary.opacity(0.5))
                .accessibilityHidden(true)
        }
        .chartForegroundStyleScale([
            battery: tones.color(.chart(.batteryPower)),
            mac: tones.color(.chart(.systemLoad)),
        ])
        .chartLegend(showsLegend ? .automatic : .hidden)
        .chartXScale(domain: domain)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let watts = value.as(Double.self) { Text(formatter.watts(watts, fractionDigits: 0)) }
                }
            }
        }
        .chartXAxis { HistoryTimeAxis.marks(for: period) }
        .chartXSelection(value: $selection)
        .chartOverlay { proxy in
            SelectionOverlay(
                proxy: proxy, points: data.points, selection: $selection, showsDate: period == .week,
                value: { point in
                    let watts = [point.batteryWatts, point.systemLoadWatts].compactMap { $0 }
                    return watts.isEmpty
                        ? nil : watts.map { formatter.watts($0, signed: true) }.joined(separator: " · ")
                })
        }
        .frame(height: 180)
        if isMonochrome {
            // Clear: every line is white, so the Mac's is dashed and fainter, in the legend too.
            plot.chartLineStyleScale([
                battery: lineStyle(.batteryPower),
                mac: lineStyle(.systemLoad),
            ])
        } else {
            plot
        }
    }

    /// One point of a power line. In Clear the line's dash encodes its series as well as its tone.
    @ChartContentBuilder
    private static func line(_ value: HistoryPowerValue, name: String, isMonochrome: Bool) -> some ChartContent {
        let mark = LineMark(
            x: .value("Time", value.time), y: .value("Watts", value.watts),
            series: .value(ChartKey.series, value.series)
        )
        .foregroundStyle(by: .value(ChartKey.line, name))
        if isMonochrome {
            mark.lineStyle(by: .value(ChartKey.line, name))
        } else {
            mark
        }
    }

    private func lineStyle(_ line: ChartLine) -> StrokeStyle {
        StrokeStyle(lineWidth: 2, lineCap: .round, dash: tones.dash(for: line).map { CGFloat($0) })
    }
}
#endif
