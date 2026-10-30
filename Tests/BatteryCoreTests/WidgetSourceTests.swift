import Foundation
import Testing

@testable import BatteryCore

/// What the widget's sources must say that only CI compiles: Linux reads them as text
/// (``SourceScanner``).
struct WidgetSourceTests {
    /// Each unit symbol of a `BatteryFormatter` built in `path`, as `label: key`, from the
    /// declaration that starts with `declaration` to its closing parentheses.
    static func unitSymbolKeys(in path: String, declaration: String) throws -> [String] {
        let text = try SourceScanner.file(path).text
        let start = try #require(text.range(of: declaration), "\(path): no \(declaration)")
        let end = try #require(text.range(of: ")))", range: start.upperBound..<text.endIndex), "\(path): no end")
        return text[start.upperBound..<end.upperBound].matches(of: #/(\w+):\s*String\(localized:\s*"([^"]*)"/#)
            .map { "\($0.output.1): \($0.output.2)" }
    }

    /// The widget's numbers use the app's unit symbols, the same six catalog keys (L10N-05).
    @Test func theWidgetsUnitSymbolsAreTheApps() throws {
        let app = try Self.unitSymbolKeys(
            in: "BatteryPulseApp/App/Localized.swift", declaration: "static let app = BatteryFormatter(")
        let widget = try Self.unitSymbolKeys(
            in: "BatteryPulseWidget/WidgetFormatter.swift", declaration: "static let widget = BatteryFormatter(")
        #expect(app.count == 6)
        #expect(widget == app)
    }

    /// The widget target's sources, as code without comments and strings.
    static func widgetCode() throws -> [SourceScanner.File] {
        try SourceScanner.files.get().filter { $0.path.hasPrefix("BatteryPulseWidget/") }
    }

    /// D-5: the widget makes a new provider for each read and reads the registry every time, so it
    /// never shows a registry an earlier read fetched: no cached scope, no `rereadsRegistry: false`.
    @Test func theWidgetReadsTheRegistryEveryTime() throws {
        let files = try Self.widgetCode()
        let code = files.map(\.code).joined(separator: "\n")
        let providers = code.matches(of: #/MacBatteryProvider\(([^)]*)\)(\.\w+)?/#)
        #expect(!providers.isEmpty)
        for provider in providers {
            #expect(provider.output.1 == "readsSMC: false" && provider.output.2 == ".readNonisolated")
        }
        let scopes = code.matches(of: #/\bscope\s*:\s*([\w.]+)/#).map { String($0.output.1) }
        #expect(!scopes.isEmpty)
        #expect(scopes.allSatisfy { $0 == ".full" || $0 == ".live" }, "\(scopes)")
        #expect(
            code.firstMatch(of: #/\.cachedSlow\b|BatteryReadScope\s*\.\s*cached\b|\brereadsRegistry\s*:\s*false\b/#)
                == nil)
    }

    /// Each widget choice's BatteryCore mirror, by parameter name.
    static let mirrors: [String: [String]] = [
        "layout": WidgetLayoutMode.allCases.map(\.rawValue),
        "mainValue": BatteryWidgetMain.allCases.map(\.rawValue),
        "mainVisual": BatteryWidgetVisual.allCases.map(\.rawValue),
        "statusLines": WidgetStatusLine.allCases.map(\.rawValue),
        "time": WidgetTimeStyle.allCases.map(\.rawValue),
        "colors": WidgetColorStyle.allCases.map(\.rawValue),
        "updateTime": WidgetUpdateTimeStyle.allCases.map(\.rawValue),
    ]

    /// A mirror's cases that the widget doesn't offer yet, each with its reason. Removing a case
    /// from here is the commit that offers it.
    static let notOfferedYet: [String: [String]] = [
        // The ring and the drawn battery come with the views that draw them.
        "mainVisual": ["ring", "drawnBattery"]
    ]

    /// Each `AppEnum` of the widget maps one to one to its BatteryCore mirror, with equal raw
    /// values: its cases are the manifest's values, which are the mirror's cases in order (less
    /// those not offered yet), and its mapping takes each case to the mirror's case of that name.
    @Test func eachChoiceMapsToItsMirror() throws {
        let code = try Self.widgetCode().map(\.code).joined(separator: "\n")
        let intents = WidgetIntentManifest.shipping.kinds.compactMap(\.intent)
        #expect(!intents.isEmpty)
        for parameter in intents.flatMap(\.parameters) {
            guard let values = parameter.values else { continue }
            let declaration = try Regex("@Parameter\\b[^@]*?\\bvar\\s+\(parameter.name)\\s*:\\s*\\[?(\\w+)")
            let type = try #require(code.firstMatch(of: declaration)?.output[1].substring, "\(parameter.name)")
            let body = try #require(
                code.firstMatch(of: try Regex("enum \(type): String, AppEnum \\{([\\s\\S]*?)\\n\\}"))?.output[1]
                    .substring, "enum \(type)")
            // A case without a raw value of its own: its raw value is its name.
            let cases = body.matches(of: #/(?m)^\s*case\s+([a-z]\w*(?:\s*,\s*[a-z]\w*)*)\s*$/#)
                .flatMap { $0.output.1.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
            #expect(cases == values, "\(type)")
            let mirror = try #require(Self.mirrors[parameter.name], "no mirror for \(parameter.name)")
            let pending = Self.notOfferedYet[parameter.name] ?? []
            #expect(values == mirror.filter { !pending.contains($0) }, "\(parameter.name)")
            for value in values {
                #expect(body.contains("case .\(value): .\(value)"), "\(type).\(value)")
            }
        }
        // Every pending case is a mirror's.
        for (name, pending) in Self.notOfferedYet {
            #expect(pending.allSatisfy { Self.mirrors[name]?.contains($0) == true }, "\(name)")
        }
    }

    /// Details' entity is identified by its field's frozen raw value.
    @Test func eachDetailIsIdentifiedByItsField() throws {
        let code = try Self.widgetCode().map(\.code).joined(separator: "\n")
        let entity = try #require(
            code.firstMatch(of: #/struct BatteryWidgetDetail: AppEntity \{([\s\S]*?)\n\}/#)?.output.1)
        #expect(entity.contains("let field: BatteryWidgetField"))
        #expect(entity.replacing(#/\s+/#, with: " ").contains("var id: String { field.rawValue }"))
        #expect(code.contains(#/@Parameter\b[^@]*?\bvar\s+details\s*:\s*\[BatteryWidgetDetail\]\?/#))
    }
}
