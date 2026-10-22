#if os(macOS)
import AppIntents
import Foundation
import WidgetKit

// SPIKE-W (W0-2, docs/plans/0.6.2/PLAN.md, WP-W0), spike branch only: the battery widget keeps its
// kind string but gets an App Intents configuration. The defaults are 0.6.1's widget field for
// field (Automatic layout, the charge, the clock time), so a widget that 0.6.1 placed shows
// whether it survives its kind becoming an AppIntentConfiguration. The parameters are a part of
// §8.5's: Layout, Main value and Time, and Details only while Layout is Custom.

/// Automatic is today's widget; Custom shows the chosen details instead of the default ones.
enum SpikeLayout: String, AppEnum {
    case automatic
    case custom

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Layout")
    }

    static var caseDisplayRepresentations: [SpikeLayout: DisplayRepresentation] {
        [
            .automatic: DisplayRepresentation(title: "Automatic"),
            .custom: DisplayRepresentation(title: "Custom"),
        ]
    }
}

/// The big value; the level symbol stays the charge's.
enum SpikeMainValue: String, AppEnum {
    case charge
    case maximumCapacity
    case temperature
    case batteryPower

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Main value")
    }

    static var caseDisplayRepresentations: [SpikeMainValue: DisplayRepresentation] {
        [
            .charge: DisplayRepresentation(title: "Charge"),
            .maximumCapacity: DisplayRepresentation(title: "Maximum capacity"),
            .temperature: DisplayRepresentation(title: "Temperature"),
            .batteryPower: DisplayRepresentation(title: "Battery power"),
        ]
    }
}

/// Clock time is today's "Lasts until about 16:39"; Time left counts down by itself (W0-6).
enum SpikeTimeStyle: String, AppEnum {
    case clockTime
    case timeLeft

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Time")
    }

    static var caseDisplayRepresentations: [SpikeTimeStyle: DisplayRepresentation] {
        [
            .clockTime: DisplayRepresentation(title: "Clock time"),
            .timeLeft: DisplayRepresentation(title: "Time left"),
        ]
    }
}

/// The battery widget's configuration. Its type name is frozen once 0.7 ships it (§8.13).
struct BatteryWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource {
        "Battery"
    }

    @Parameter(title: "Layout", default: .automatic)
    var layout: SpikeLayout

    @Parameter(title: "Main value", default: .charge)
    var mainValue: SpikeMainValue

    @Parameter(title: "Time", default: .clockTime)
    var time: SpikeTimeStyle

    @Parameter(title: "Details", size: [.systemSmall: 1, .systemMedium: 4, .systemLarge: 8, .systemExtraLarge: 12])
    var details: [SpikeDetail]?

    /// Details appear only with the Custom layout: an empty Custom list means no details.
    static var parameterSummary: some ParameterSummary {
        When(\.$layout, .equalTo, .custom) {
            Summary("\(\.$layout)") {
                \.$mainValue
                \.$time
                \.$details
            }
        } otherwise: {
            Summary("\(\.$layout)") {
                \.$mainValue
                \.$time
            }
        }
    }
}

/// The configuration as plain values for the timeline's entries.
struct BatteryWidgetOptions: Equatable {
    var layout = SpikeLayout.automatic
    var mainValue = SpikeMainValue.charge
    var time = SpikeTimeStyle.clockTime
    /// In the user's order, each field once.
    var details: [SpikeField] = []

    /// 0.6.1's widget: what a widget placed before the change gets.
    init() {}

    init(_ intent: BatteryWidgetIntent) {
        layout = intent.layout
        mainValue = intent.mainValue
        time = intent.time
        var seen = Set<SpikeField>()
        details = (intent.details ?? []).map(\.field).filter { seen.insert($0).inserted }
    }
}
#endif
