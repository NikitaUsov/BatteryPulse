#if os(macOS)
import BatteryCore
import Foundation
import SwiftUI
import WidgetKit

/// A chart the plan laid out in a unit square (BatteryCore's `WidgetChart`), stroked as `Path`s:
/// the charging stretches shaded behind the line, battery power's zero dashed, the line in the
/// accent group, so in the accented and vibrant modes the three differ by alpha, line style and
/// position, never by hue alone. The value axis's ends are at its trailing edge, the time axis's
/// under it.
struct WidgetChartView: View {
    let chart: WidgetChart

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                ZStack {
                    WidgetChartSpans(spans: chart.pluggedSpans)
                        .fill(.quaternary)
                    if let zero = chart.zero {
                        WidgetChartLevel(y: zero)
                            .stroke(.secondary, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                    WidgetChartLine(runs: chart.runs)
                        .stroke(.tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .widgetAccentable()
                }
                VStack(alignment: .trailing, spacing: 0) {
                    Text(verbatim: chart.topLabel)
                    Spacer(minLength: 0)
                    Text(verbatim: chart.bottomLabel)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            HStack(spacing: 4) {
                Text(verbatim: chart.startLabel)
                Spacer(minLength: 0)
                Text(verbatim: chart.endLabel)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .lineLimit(1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The large Battery widget's chart, or the message in its place.
struct WidgetChartPlace: View {
    let content: WidgetChartContent
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        switch content {
        case .chart(let chart, let isOutdated):
            VStack(alignment: .leading, spacing: 2) {
                WidgetChartView(chart: chart)
                    .widgetElement(chart.summary.spokenLabel, strings: strings)
                if isOutdated {
                    WidgetOutdatedLine()
                }
            }
        case .message(let reason):
            widgetText(reason.message, strings)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .widgetElement(reason.spokenLabel, strings: strings)
        }
    }
}

/// The line under a feed's last data once it is two hours old. Its own VoiceOver element.
struct WidgetOutdatedLine: View {
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        Text("Open BatteryPulse to update", bundle: strings)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

// MARK: - Shapes

extension CGRect {
    /// A chart's point in its unit square, y up, in this place.
    fileprivate func chartPoint(_ point: WidgetChartPoint) -> CGPoint {
        CGPoint(x: minX + point.x * width, y: maxY - point.y * height)
    }
}

/// A chart's line: each run of points between gaps, and a run of one point as a dot.
struct WidgetChartLine: Shape {
    let runs: [[WidgetChartPoint]]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for run in runs {
            guard let first = run.first.map(rect.chartPoint) else { continue }
            if run.count == 1 {
                path.addEllipse(in: CGRect(x: first.x - 1, y: first.y - 1, width: 2, height: 2))
                continue
            }
            path.move(to: first)
            for point in run.dropFirst() {
                path.addLine(to: rect.chartPoint(point))
            }
        }
        return path
    }
}

/// A chart's stretches on the adapter, the whole height of the place.
struct WidgetChartSpans: Shape {
    let spans: [WidgetChartSpan]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for span in spans {
            path.addRect(
                CGRect(
                    x: rect.minX + span.start * rect.width, y: rect.minY, width: (span.end - span.start) * rect.width,
                    height: rect.height))
        }
        return path
    }
}

/// A level of a chart's value axis, across its place: battery power's zero.
struct WidgetChartLevel: Shape {
    let y: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // y up, as the chart's points.
        let level = rect.maxY - y * rect.height
        path.move(to: CGPoint(x: rect.minX, y: level))
        path.addLine(to: CGPoint(x: rect.maxX, y: level))
        return path
    }
}

// A chart's words, as resources so the previews' tests can compare their keys with the ones
// VoiceOver's labels use (BatteryCore's `WidgetChart`).

extension HistoryWidgetSeries {
    /// The series' name, as the History page and the edit sheet name it.
    var title: LocalizedStringResource {
        switch self {
        case .charge: "Charge"
        case .batteryPower: "Battery power"
        case .temperature: "Temperature"
        case .capacityToDesign: "Capacity compared with design"
        case .cycleCount: "Cycle count"
        }
    }
}

extension HistoryWidgetEmptyReason {
    var message: LocalizedStringResource {
        switch self {
        case .noFeed: "Open BatteryPulse to update"
        case .recordingOff: "Turn on Record battery history in BatteryPulse"
        case .noHistory: "No History Yet"
        }
    }
}

extension WidgetChartSummary.Span {
    /// The span VoiceOver reads with a chart.
    var title: LocalizedStringResource {
        switch self {
        case .hours24: "24 Hours"
        case .days7: "7 Days"
        case .days90: "90 Days"
        }
    }
}

extension WidgetChartSummary {
    /// The values VoiceOver reads with a chart.
    static let values: LocalizedStringResource = "Lowest %@, highest %@, latest %@"
}
#endif
