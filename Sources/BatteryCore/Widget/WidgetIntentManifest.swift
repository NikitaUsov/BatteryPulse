import Foundation

/// Every widget name that freezes once a release ships it: each kind string with its families,
/// and each configuration intent's type name, parameter names and `AppEnum` raw values. macOS
/// stores placed widgets and their configuration under these names, so a release may only add to
/// them.
///
/// ``shipping`` is what the widget target declares now; `scripts/widget-manifest.json` is its
/// export. A Linux test keeps the file, the type and the widget's sources equal, and CI compares
/// the file with the built extension's App Intents metadata.
struct WidgetIntentManifest: Codable, Sendable, Equatable {
    struct Kind: Codable, Sendable, Equatable {
        var kind: String
        /// ``WidgetSize`` raw values, in the order the widget declares them.
        var families: [String]
        /// `nil` for a static widget.
        var intent: Intent?

        init(_ kind: WidgetKindID, families: [WidgetSize], intent: Intent? = nil) {
            self.kind = kind.rawValue
            self.families = families.map(\.rawValue)
            self.intent = intent
        }
    }

    struct Intent: Codable, Sendable, Equatable {
        var type: String
        var parameters: [Parameter]

        init(type: String, parameters: [Parameter]) {
            self.type = type
            self.parameters = parameters
        }
    }

    struct Parameter: Codable, Sendable, Equatable {
        var name: String
        /// The `AppEnum`'s raw values, in its order, for an enum parameter.
        var values: [String]?

        init(name: String, values: [String]? = nil) {
            self.name = name
            self.values = values
        }
    }

    var kinds: [Kind]

    init(kinds: [Kind]) {
        self.kinds = kinds
    }

    /// The widgets the extension declares today: 0.6.x's Battery kind, configurable. Main visual
    /// lists only the number and symbol until the views that draw the ring and the drawn battery
    /// exist; Details is an entity, whose ids are ``BatteryWidgetField``'s raw values.
    static let shipping = WidgetIntentManifest(kinds: [
        Kind(
            .battery, families: [.small, .medium],
            intent: Intent(
                type: "BatteryWidgetIntent",
                parameters: [
                    Parameter(name: "layout", values: WidgetLayoutMode.allCases.map(\.rawValue)),
                    Parameter(name: "mainValue", values: BatteryWidgetMain.allCases.map(\.rawValue)),
                    Parameter(name: "mainVisual", values: [BatteryWidgetVisual.symbol.rawValue]),
                    Parameter(name: "statusLines", values: WidgetStatusLine.allCases.map(\.rawValue)),
                    Parameter(name: "details"),
                    Parameter(name: "time", values: WidgetTimeStyle.allCases.map(\.rawValue)),
                    Parameter(name: "colors", values: WidgetColorStyle.allCases.map(\.rawValue)),
                    Parameter(name: "updateTime", values: WidgetUpdateTimeStyle.allCases.map(\.rawValue)),
                ]))
    ])

    /// The JSON of `scripts/widget-manifest.json`: sorted keys, two-space indents, a final newline.
    func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self) + Data("\n".utf8)
    }
}
