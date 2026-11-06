#if os(macOS)
import AppIntents
import BatteryCore
import Foundation
import WidgetKit

// The iPhone & iPad widget's configuration, under the Battery widget's rules
// (BatteryWidgetIntent.swift): its type name, parameter names and case raw values are frozen once a
// release ships them, each choice maps one to one to its BatteryCore mirror, and every string of
// its edit sheet is a String Catalog key with its Russian. The default needs no entity query: it
// shows the most recently read device of the feed.

/// The iPhone & iPad widget's configuration. The default shows the most recently read device.
struct DevicesWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose iPhone and iPad"
    static let description = IntentDescription("Choose which iPhones and iPads the widget shows.")

    /// One device, the most recently read or the lowest, or all of them.
    @Parameter(title: "Show", default: .mostRecent)
    var show: DevicesWidgetShowChoice

    /// macOS 27's edit sheet doesn't show the summary sentence, so it is a plain catalog key,
    /// never a parameter placeholder.
    static var parameterSummary: some ParameterSummary {
        Summary("iPhone and iPad") {
            \.$show
        }
    }
}

/// ``DevicesWidgetShow``.
enum DevicesWidgetShowChoice: String, AppEnum {
    case mostRecent, lowest, all

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Show"
    static let caseDisplayRepresentations: [DevicesWidgetShowChoice: DisplayRepresentation] = [
        .mostRecent: "Most recently read",
        .lowest: "Lowest charge",
        .all: "All",
    ]

    var show: DevicesWidgetShow {
        switch self {
        case .mostRecent: .mostRecent
        case .lowest: .lowest
        case .all: .all
        }
    }
}

extension DevicesWidgetConfiguration {
    /// The intent's choices as BatteryCore's model.
    init(_ intent: DevicesWidgetIntent) {
        self.init(show: intent.show.show)
    }
}
#endif
