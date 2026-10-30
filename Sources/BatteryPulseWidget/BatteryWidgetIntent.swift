#if os(macOS)
import AppIntents
import BatteryCore
import Foundation
import WidgetKit

// The Battery widget's configuration: what its edit sheet offers. Every App Intents type and its
// strings live in this target, never in BatteryCore or the app (an intent's strings from a package
// can show as raw keys). The system builds the sheet from the metadata that scripts/build-app.sh
// extracts at build time, and macOS stores each placed widget's choices under these names, so the
// intent's type name, its parameter names, every case's raw value and every detail's id are frozen
// once a release ships them (WidgetIntentManifest, scripts/widget-manifest.json). Each choice maps
// one to one to its BatteryCore mirror, whose decisions are tested on Linux, with equal raw values
// (WidgetSourceTests).
//
// The metadata is `static let`: a stored `static var` is global mutable state, an error in Swift
// 6, and a `let` satisfies the protocols' `{ get }` requirements. Every title, description, type
// name, case and summary is a String Catalog key with its Russian.

/// The Battery widget's configuration. Every default is 0.6.x's widget: a widget placed before
/// 0.7 gets them all, Automatic first, and looks as it did.
struct BatteryWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Battery Details"
    static let description = IntentDescription("Choose what the Battery widget shows.")

    /// Automatic shows each size's own details; Custom shows the chosen ones.
    @Parameter(title: "Layout", default: .automatic)
    var layout: WidgetLayoutChoice

    @Parameter(title: "Main value", default: .charge)
    var mainValue: BatteryMainValueChoice

    @Parameter(title: "Main visual", default: .symbol)
    var mainVisual: BatteryMainVisualChoice

    /// The lines under the main value; `nil` (no value stored) means both, as the default says.
    @Parameter(title: "Status lines", default: [.state, .time])
    var statusLines: [WidgetStatusLineChoice]?

    /// Custom's details, in the chosen order; none means no details, never Automatic's. As many
    /// as each size has slots (`WidgetLayoutPlan.detailSlots`); small's one takes the time line's
    /// place. An array of an entity, because only an entity's array can be sized per family.
    @Parameter(
        title: "Details",
        size: [
            .systemSmall: IntentCollectionSize(min: 0, max: 1), .systemMedium: IntentCollectionSize(min: 0, max: 4),
            .systemLarge: IntentCollectionSize(min: 0, max: 8),
            .systemExtraLarge: IntentCollectionSize(min: 0, max: 12),
        ])
    var details: [BatteryWidgetDetail]?

    @Parameter(title: "Time", default: .clockTime)
    var time: WidgetTimeChoice

    @Parameter(title: "Colors", default: .levelColors)
    var colors: WidgetColorsChoice

    @Parameter(title: "Update time", default: .whenOld)
    var updateTime: WidgetUpdateTimeChoice

    /// Details shows only with the Custom layout. macOS 27's edit sheet doesn't show the summary
    /// sentence, so each branch's is a plain catalog key, never a parameter placeholder.
    static var parameterSummary: some ParameterSummary {
        When(\.$layout, .equalTo, .custom) {
            Summary("Custom layout") {
                \.$layout
                \.$mainValue
                \.$mainVisual
                \.$statusLines
                \.$details
                \.$time
                \.$colors
                \.$updateTime
            }
        } otherwise: {
            Summary("Automatic layout") {
                \.$layout
                \.$mainValue
                \.$mainVisual
                \.$statusLines
                \.$time
                \.$colors
                \.$updateTime
            }
        }
    }
}

/// ``WidgetLayoutMode``.
enum WidgetLayoutChoice: String, AppEnum {
    case automatic, custom

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Layout"
    static let caseDisplayRepresentations: [WidgetLayoutChoice: DisplayRepresentation] = [
        .automatic: "Automatic",
        .custom: "Custom",
    ]

    var mode: WidgetLayoutMode {
        switch self {
        case .automatic: .automatic
        case .custom: .custom
        }
    }
}

/// ``BatteryWidgetMain``.
enum BatteryMainValueChoice: String, AppEnum {
    case charge, maximumCapacity, temperature, batteryPower

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Main value"
    static let caseDisplayRepresentations: [BatteryMainValueChoice: DisplayRepresentation] = [
        .charge: "Charge",
        .maximumCapacity: "Maximum capacity",
        .temperature: "Temperature",
        .batteryPower: "Battery power",
    ]

    var main: BatteryWidgetMain {
        switch self {
        case .charge: .charge
        case .maximumCapacity: .maximumCapacity
        case .temperature: .temperature
        case .batteryPower: .batteryPower
        }
    }
}

/// ``BatteryWidgetVisual``: the number with the level symbol, as in 0.6.x. The ring and the
/// drawn battery come with the views that draw them.
enum BatteryMainVisualChoice: String, AppEnum {
    case symbol

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Main visual"
    static let caseDisplayRepresentations: [BatteryMainVisualChoice: DisplayRepresentation] = [
        .symbol: "Number and symbol"
    ]

    var visual: BatteryWidgetVisual {
        switch self {
        case .symbol: .symbol
        }
    }
}

/// ``WidgetStatusLine``.
enum WidgetStatusLineChoice: String, AppEnum {
    case state, time

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Status lines"
    static let caseDisplayRepresentations: [WidgetStatusLineChoice: DisplayRepresentation] = [
        .state: "State",
        .time: "Time to full or empty",
    ]

    var line: WidgetStatusLine {
        switch self {
        case .state: .state
        case .time: .time
        }
    }
}

/// ``WidgetTimeStyle``.
enum WidgetTimeChoice: String, AppEnum {
    case clockTime, timeLeft

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Time"
    static let caseDisplayRepresentations: [WidgetTimeChoice: DisplayRepresentation] = [
        .clockTime: "Clock time",
        .timeLeft: "Time left",
    ]

    var style: WidgetTimeStyle {
        switch self {
        case .clockTime: .clockTime
        case .timeLeft: .timeLeft
        }
    }
}

/// ``WidgetColorStyle``.
enum WidgetColorsChoice: String, AppEnum {
    case levelColors, monochrome

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Colors"
    static let caseDisplayRepresentations: [WidgetColorsChoice: DisplayRepresentation] = [
        .levelColors: "Level colors",
        .monochrome: "Monochrome",
    ]

    var style: WidgetColorStyle {
        switch self {
        case .levelColors: .levelColors
        case .monochrome: .monochrome
        }
    }
}

/// ``WidgetUpdateTimeStyle``.
enum WidgetUpdateTimeChoice: String, AppEnum {
    case whenOld, always

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Update time"
    static let caseDisplayRepresentations: [WidgetUpdateTimeChoice: DisplayRepresentation] = [
        .whenOld: "When old",
        .always: "Always",
    ]

    var style: WidgetUpdateTimeStyle {
        switch self {
        case .whenOld: .whenOld
        case .always: .always
        }
    }
}

/// One detail the Custom layout shows: a field of ``BatteryWidgetField``, identified by its frozen
/// raw value, and titled with the label the widget shows beside it.
struct BatteryWidgetDetail: AppEntity {
    let field: BatteryWidgetField

    var id: String {
        field.rawValue
    }

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Detail"

    static var defaultQuery: BatteryWidgetDetailQuery {
        BatteryWidgetDetailQuery()
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: field.label)
    }

    /// The details the chooser offers, in the catalogue's order.
    static let offered = BatteryWidgetField.allCases.filter(\.isOffered).map(BatteryWidgetDetail.init(field:))

    init(field: BatteryWidgetField) {
        self.field = field
    }

    /// A stored id's detail; `nil` for an id no field has or the chooser doesn't offer.
    init?(id: String) {
        guard let field = BatteryWidgetField(rawValue: id), field.isOffered else { return nil }
        self.field = field
    }
}

/// Lists the details for the edit sheet's chooser, in the widget extension.
struct BatteryWidgetDetailQuery: EntityQuery {
    static var allowedExecutionTargets: IntentExecutionTargets {
        .widgetKitExtension
    }

    func entities(for identifiers: [String]) async throws -> [BatteryWidgetDetail] {
        identifiers.compactMap(BatteryWidgetDetail.init(id:))
    }

    func suggestedEntities() async throws -> [BatteryWidgetDetail] {
        BatteryWidgetDetail.offered
    }
}

extension BatteryWidgetField {
    /// The field's name in the edit sheet's chooser and beside its value: the app's own words for
    /// the value ("System load", "Power from adapter").
    var label: LocalizedStringResource {
        switch self {
        case .state: "State"
        case .time: "Time to full or empty"
        case .maximumCapacity: "Maximum capacity"
        case .condition: "Condition"
        case .cycleCount: "Cycle count"
        case .temperature: "Temperature"
        case .adapter: "Adapter"
        case .systemLoad: "System load"
        case .batteryPower: "Battery power"
        case .adapterInput: "Power from adapter"
        case .lowPowerMode: "Low Power Mode"
        case .remainingCapacity: "Remaining capacity"
        case .voltage: "Voltage"
        // Offered with their catalog keys by the package that adds the large widget.
        case .cycleLifeUsed, .cellBalance: LocalizedStringResource(stringLiteral: rawValue)
        }
    }

    /// Whether the Details chooser offers the field: every field with a catalog label.
    var isOffered: Bool {
        switch self {
        case .cycleLifeUsed, .cellBalance: false
        default: true
        }
    }
}
#endif
