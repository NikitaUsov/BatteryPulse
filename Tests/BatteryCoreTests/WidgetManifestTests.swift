import Foundation
import Testing

@testable import BatteryCore

/// `scripts/widget-manifest.json`, ``WidgetIntentManifest/shipping`` and the widget's sources say
/// the same: what CI checks the built extension's metadata against is what the code declares.
struct WidgetManifestTests {
    static let file = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("scripts/widget-manifest.json")

    @Test func theFileIsTheTypesExport() throws {
        let data = try Data(contentsOf: Self.file)
        #expect(try JSONDecoder().decode(WidgetIntentManifest.self, from: data) == .shipping)
        #expect(data.last == UInt8(ascii: "\n"))
        let exported = try WidgetIntentManifest.shipping.json()
        #expect(try JSONDecoder().decode(WidgetIntentManifest.self, from: exported) == .shipping)
        // Byte for byte: decoding ignores keys the type doesn't have, and CI's metadata check
        // reads the file, so a hand edit could otherwise say more than the type.
        #expect(data == exported, "Write WidgetIntentManifest.shipping.json() to scripts/widget-manifest.json")
    }

    /// A widget configuration in the extension's sources: its kind, intent type and families.
    struct Declared: Equatable, CustomStringConvertible {
        var kind: String
        var intent: String?
        var families: [String]
        var description: String { "\(kind) \(intent ?? "static") \(families)" }
    }

    /// The kind expressions the widget may use for each kind string.
    static func kindString(_ expression: String) -> String? {
        for kind in WidgetKindID.allCases {
            let name = "\(kind)"
            if expression == "WidgetKindID.\(name).rawValue" || expression == "BatteryWidgetKind.\(name)" {
                return kind.rawValue
            }
        }
        return nil
    }

    static let familyNames: [String: WidgetSize] = [
        ".systemSmall": .small, ".systemMedium": .medium, ".systemLarge": .large,
        ".systemExtraLarge": .extraLarge, ".systemExtraLargePortrait": .extraLargePortrait,
    ]

    /// Each `StaticConfiguration` or `AppIntentConfiguration` with the `supportedFamilies` that
    /// follows it.
    static func declared() throws -> [Declared] {
        var declared: [Declared] = []
        for file in try SourceScanner.files.get() where file.path.hasPrefix("BatteryPulseWidget/") {
            let configurations = SourceScanner.calls(
                named: #/\b(?:StaticConfiguration|AppIntentConfiguration)/#, in: file.code)
            let families = SourceScanner.calls(named: #/\.supportedFamilies/#, in: file.code)
            #expect(configurations.count == families.count, "\(file.path): one supportedFamilies per configuration")
            for (configuration, family) in zip(configurations, families) {
                let expression = configuration.argument(labeled: "kind") ?? ""
                let kind = try #require(Self.kindString(expression), "\(file.path): unknown kind \(expression)")
                let intent = configuration.argument(labeled: "intent").map {
                    $0.replacingOccurrences(of: ".self", with: "")
                }
                let list = family.firstArgument.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                let names = try list.split(separator: ",").map {
                    let name = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    return try #require(Self.familyNames[name], "\(file.path): unknown family \(name)").rawValue
                }
                declared.append(Declared(kind: kind, intent: intent, families: names))
            }
        }
        return declared
    }

    @Test func theWidgetDeclaresTheManifestsKinds() throws {
        let expected = WidgetIntentManifest.shipping.kinds.map {
            Declared(kind: $0.kind, intent: $0.intent?.type, families: $0.families)
        }
        #expect(try Self.declared() == expected)
    }

    /// Each intent's parameters, in the order its type declares them.
    @Test func theIntentsDeclareTheManifestsParameters() throws {
        let files = try SourceScanner.files.get().filter { $0.path.hasPrefix("BatteryPulseWidget/") }
        for intent in WidgetIntentManifest.shipping.kinds.compactMap(\.intent) {
            let declaration = try Regex("struct \(intent.type)\\b[^{]*\\{([\\s\\S]*?)\\n\\}")
            guard let body = files.lazy.compactMap({ $0.code.firstMatch(of: declaration)?.output[1].substring }).first
            else {
                Issue.record("No struct \(intent.type) in the widget")
                continue
            }
            let names = body.matches(of: #/@Parameter\b[\s\S]*?\bvar\s+(\w+)/#).map { String($0.output.1) }
            #expect(names == intent.parameters.map(\.name), "\(intent.type)")
        }
    }
}
