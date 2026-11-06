#if os(macOS)
import BatteryCore
import Foundation
import SwiftUI
import WidgetKit

/// Reads the widget's family and hands the views its size, and sets the language the entry draws
/// in, as the Battery widget's root does.
struct HistoryWidgetRoot: View {
    let entry: HistoryEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Self.content(entry, size: WidgetSize(family))
    }

    /// The widget for `entry` in `size`, in the entry's language, as the Battery widget's root
    /// draws its own. The previews draw it too.
    static func content(_ entry: HistoryEntry, size: WidgetSize, timeZone: TimeZone = .autoupdatingCurrent)
        -> some View
    {
        HistoryWidgetView(entry: entry, size: size, formatter: entry.language.formatter, timeZone: timeZone)
            .widgetLanguage(entry.language)
    }
}

/// One entry of the History widget, as ``HistoryWidgetPlan`` lays it out for the size; every state
/// opens History.
///
/// - Medium: the series' name and latest value over its chart.
/// - Large: the same, taller, and the last 24 hours' figures under it.
///
/// A feed over two hours old keeps its last data, with its times on the axis, and says "Open
/// BatteryPulse to update" under it.
struct HistoryWidgetView: View {
    let entry: HistoryEntry
    let size: WidgetSize
    var formatter = BatteryFormatter.widget
    var timeZone = TimeZone.autoupdatingCurrent

    var body: some View {
        let plan = HistoryWidgetPlan.make(
            size: size, configuration: entry.configuration, feed: entry.feed, entry: entry.moment,
            formatter: formatter, timeZone: timeZone)
        Group {
            switch plan {
            case .history(let layout):
                VStack(alignment: .leading, spacing: 8) {
                    HistoryChartBlock(chart: layout.chart)
                    if !layout.statistics.isEmpty {
                        Divider()
                        HistoryStatisticsList(statistics: layout.statistics)
                    }
                    if layout.isOutdated {
                        WidgetOutdatedLine()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case .empty(let reason):
                HistoryEmptyState(reason: reason)
            }
        }
        .widgetURL(plan.route.url)
    }
}

/// The series' name and its latest value over its chart: one VoiceOver element, the chart's
/// summary.
struct HistoryChartBlock: View {
    let chart: WidgetChart
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                widgetText(chart.series.title, strings)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(verbatim: chart.latest)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .font(.caption)
            .lineLimit(1)
            WidgetChartView(chart: chart)
        }
        .widgetElement(chart.summary.spokenLabel, strings: strings)
    }
}

/// The last 24 hours' figures: a row each, its label at the leading edge and its value at the
/// trailing one, as medium's details. Each row is one VoiceOver element.
struct HistoryStatisticsList: View {
    let statistics: [HistoryWidgetStatistic]
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(statistics.enumerated()), id: \.offset) { _, statistic in
                HStack(spacing: 8) {
                    widgetText(statistic.kind.label, strings)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    WidgetPlainValue(value: statistic.value)
                        .monospacedDigit()
                }
                .widgetElement(statistic.spokenLabel, strings: strings)
            }
        }
        .font(.caption)
        .lineLimit(1)
    }
}

/// The message of a History widget without a chart: one VoiceOver element, the message.
struct HistoryEmptyState: View {
    let reason: HistoryWidgetEmptyReason
    @Environment(\.widgetStrings) private var strings

    var body: some View {
        VStack(spacing: 6) {
            decorativeSymbol("chart.xyaxis.line")
                .font(.title)
            widgetText(reason.message, strings)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetElement(reason.spokenLabel, strings: strings)
    }
}

// The History widget's own words, as resources so the previews' tests can compare their keys
// with the ones VoiceOver's labels use (BatteryCore's `HistoryWidgetPlan`).

extension HistoryWidgetStatistic.Kind {
    /// The History page's names for its figures.
    var label: LocalizedStringResource {
        switch self {
        case .averageDrain: "Average drain"
        case .onBattery: "On battery"
        case .chargingSessions: "Charging sessions"
        }
    }
}
#endif
