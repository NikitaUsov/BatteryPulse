#if os(macOS)
import AppIntents
import BatteryCore
import Foundation
import WidgetKit

// The History widget's configuration, under the Battery widget's rules (BatteryWidgetIntent.swift):
// its type name, parameter names and case raw values are frozen once a release ships them, each
// choice maps one to one to its BatteryCore mirror, and every string of its edit sheet is a String
// Catalog key with its Russian.

/// The History widget's configuration. The defaults chart the last 24 hours' charge, with the
/// statistics in large.
struct HistoryWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose History"
    static let description = IntentDescription("Choose what the History widget shows.")

    /// The last 24 hours or 7 days; the 90-day series ignore it.
    @Parameter(title: "Period", default: .day)
    var period: HistoryPeriodChoice

    @Parameter(title: "Series", default: .charge)
    var series: HistorySeriesChoice

    /// Large only: the figures of the chart's period under it, the 7 days' under a 90-day series.
    @Parameter(title: "Statistics", default: true)
    var statistics: Bool

    /// Period hides for the 90-day series, Statistics shows only in large. macOS 27's edit sheet
    /// doesn't show the summary sentence, so each branch's is a plain catalog key, never a
    /// parameter placeholder.
    static var parameterSummary: some ParameterSummary {
        When(\.$series, .oneOf, [.capacityToDesign, .cycleCount]) {
            When(widgetFamily: .equalTo, .systemLarge) {
                Summary("History") {
                    \.$series
                    \.$statistics
                }
            } otherwise: {
                Summary("History") {
                    \.$series
                }
            }
        } otherwise: {
            When(widgetFamily: .equalTo, .systemLarge) {
                Summary("History") {
                    \.$period
                    \.$series
                    \.$statistics
                }
            } otherwise: {
                Summary("History") {
                    \.$period
                    \.$series
                }
            }
        }
    }
}

/// ``HistoryWidgetPeriod``.
enum HistoryPeriodChoice: String, AppEnum {
    case day, week

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Period"
    static let caseDisplayRepresentations: [HistoryPeriodChoice: DisplayRepresentation] = [
        .day: "24 Hours",
        .week: "7 Days",
    ]

    var period: HistoryWidgetPeriod {
        switch self {
        case .day: .day
        case .week: .week
        }
    }
}

/// ``HistoryWidgetSeries``: a reading over the period, or the 90-day trend of the battery's health.
enum HistorySeriesChoice: String, AppEnum {
    case charge, batteryPower, temperature, capacityToDesign, cycleCount

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Series"
    static let caseDisplayRepresentations: [HistorySeriesChoice: DisplayRepresentation] = [
        .charge: "Charge",
        .batteryPower: "Battery power",
        .temperature: "Temperature",
        .capacityToDesign: "Capacity compared with design",
        .cycleCount: "Cycle count",
    ]

    var series: HistoryWidgetSeries {
        switch self {
        case .charge: .charge
        case .batteryPower: .batteryPower
        case .temperature: .temperature
        case .capacityToDesign: .capacityToDesign
        case .cycleCount: .cycleCount
        }
    }
}

extension HistoryWidgetConfiguration {
    /// The intent's choices as BatteryCore's model.
    init(_ intent: HistoryWidgetIntent) {
        self.init(period: intent.period.period, series: intent.series.series, showsStatistics: intent.statistics)
    }
}
#endif
