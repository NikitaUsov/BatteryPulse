import Foundation

/// Every widget name that freezes once a release ships it: each kind string with its families,
/// and each configuration intent's type name, parameter names and `AppEnum` raw values. macOS
/// stores placed widgets and their configuration under these names, so a release may only add to
/// them.
///
/// ``shipping`` is what the widget target declares now; `scripts/widget-manifest.json` is its
/// export. A Linux test keeps the file, the type and the widget's sources equal, and CI compares
/// the file with the built extension's App Intents metadata.
public struct WidgetIntentManifest: Codable, Sendable, Equatable {
    public struct Kind: Codable, Sendable, Equatable {
        public var kind: String
        /// ``WidgetSize`` raw values, in the order the widget declares them.
        public var families: [String]
        /// `nil` for a static widget.
        public var intent: Intent?

        public init(_ kind: WidgetKindID, families: [WidgetSize], intent: Intent? = nil) {
            self.kind = kind.rawValue
            self.families = families.map(\.rawValue)
            self.intent = intent
        }
    }

    public struct Intent: Codable, Sendable, Equatable {
        public var type: String
        public var parameters: [Parameter]

        public init(type: String, parameters: [Parameter]) {
            self.type = type
            self.parameters = parameters
        }
    }

    public struct Parameter: Codable, Sendable, Equatable {
        public var name: String
        /// The `AppEnum`'s raw values, in its order, for an enum parameter.
        public var values: [String]?

        public init(name: String, values: [String]? = nil) {
            self.name = name
            self.values = values
        }
    }

    public var kinds: [Kind]

    public init(kinds: [Kind]) {
        self.kinds = kinds
    }

    /// The widgets the extension declares today: 0.6.x's static Battery widget.
    public static let shipping = WidgetIntentManifest(kinds: [Kind(.battery, families: [.small, .medium])])

    /// The JSON of `scripts/widget-manifest.json`: sorted keys, two-space indents, a final newline.
    public func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self) + Data("\n".utf8)
    }
}
