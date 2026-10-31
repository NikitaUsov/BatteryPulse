#if os(macOS)
import AppIntents
import BatteryCore
import Foundation
import WidgetKit

// The Accessories widget's configuration, under the Battery widget's rules (BatteryWidgetIntent.swift):
// its type name, parameter names and case raw values are frozen once a release ships them, each
// choice maps one to one to its BatteryCore mirror, and every string of its edit sheet is a String
// Catalog key with its Russian. No accessory identifier enters it: the widget lists what is
// connected, never a chosen accessory.

/// The Accessories widget's configuration. Small always shows the lowest accessory, so its edit
/// sheet offers nothing; medium and large offer which accessories and whether full ones show.
struct AccessoriesWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Accessories"
    static let description = IntentDescription("Choose which accessory batteries the widget shows.")

    /// All, lowest first, or the lowest alone.
    @Parameter(title: "Show", default: .all)
    var mode: AccessoryWidgetModeChoice

    /// Leaves out an accessory whose every part that counts is full.
    @Parameter(title: "Hide fully charged", default: false)
    var hideFullyCharged: Bool

    /// The choices show only in medium and large. macOS 27's edit sheet doesn't show the summary
    /// sentence, so each branch's is a plain catalog key, never a parameter placeholder.
    static var parameterSummary: some ParameterSummary {
        When(widgetFamily: .equalTo, .systemSmall) {
            Summary("Lowest only")
        } otherwise: {
            Summary("Accessories") {
                \.$mode
                \.$hideFullyCharged
            }
        }
    }
}

/// ``AccessoryWidgetMode``.
enum AccessoryWidgetModeChoice: String, AppEnum {
    case all, lowest

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Show"
    static let caseDisplayRepresentations: [AccessoryWidgetModeChoice: DisplayRepresentation] = [
        .all: "All",
        .lowest: "Lowest only",
    ]

    var mode: AccessoryWidgetMode {
        switch self {
        case .all: .all
        case .lowest: .lowest
        }
    }
}

extension AccessoriesWidgetConfiguration {
    /// The intent's choices as BatteryCore's model.
    init(_ intent: AccessoriesWidgetIntent) {
        self.init(mode: intent.mode.mode, hidesFullyCharged: intent.hideFullyCharged)
    }
}
#endif
