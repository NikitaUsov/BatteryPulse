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

    /// P2 §8.8: the widget reads accessory batteries only with `MacAccessoryProvider`'s one-shot
    /// `read()`. It never observes their change notifications (`observeChanges`), never runs an
    /// `AccessoryMonitor`, whose `start()` registers them, and never reads an `id`: an accessory's
    /// can be brute-forced back to a Bluetooth address. The `dlsym` lookup stays in BatterySource
    /// (`SecurityGuardTests`).
    @Test func theWidgetReadsAccessoriesOnceAndWithoutTheirIDs() throws {
        let code = try Self.widgetCode().map(\.code).joined(separator: "\n")
        #expect(Self.accessoryScan(code) == AccessoryScan(providerCalls: ["read"], observers: 0, idReads: 0))
    }

    /// What the accessory guard sees in the widget's code.
    struct AccessoryScan: Equatable {
        /// What each `MacAccessoryProvider` is used for: `read` for `MacAccessoryProvider().read()`,
        /// "other" for anything else.
        var providerCalls: [String]
        /// `observeChanges`, `AccessoryMonitor` or `SystemAccessories`.
        var observers: Int
        /// `.id`, as a member or a key path.
        var idReads: Int
    }

    /// Word boundaries as in most regex engines: Swift's default (Unicode) ones see none in
    /// `provider.observeChanges`.
    static func accessoryScan(_ code: String) -> AccessoryScan {
        let provider = #/\bMacAccessoryProvider\b(\s*\(\s*\)\s*\.\s*read\s*\(\s*\))?/#.wordBoundaryKind(.simple)
        let observer = #/\bobserveChanges\b|\bAccessoryMonitor\b|\bSystemAccessories\b/#.wordBoundaryKind(.simple)
        return AccessoryScan(
            providerCalls: code.matches(of: provider).map { $0.output.1 == nil ? "other" : "read" },
            observers: code.matches(of: observer).count,
            idReads: code.matches(of: #/\.\s*id\b/#.wordBoundaryKind(.simple)).count)
    }

    /// The accessory guard fails on code that observes, keeps a provider or reads an ID.
    @Test func theAccessoryGuardFailsOnBadCode() {
        func scan(_ text: String) -> AccessoryScan { Self.accessoryScan(SourceScanner.codeOnly(text)) }
        let read = "await MainActor.run { MacAccessoryProvider().read()?.accessories }"
        #expect(scan(read) == AccessoryScan(providerCalls: ["read"], observers: 0, idReads: 0))
        #expect(scan("let provider = MacAccessoryProvider()\nprovider.read()").providerCalls == ["other"])
        #expect(scan("MacAccessoryProvider().observeChanges { }").observers == 1)
        #expect(scan("let monitor = AccessoryMonitor(provider: nil)").observers == 1)
        #expect(scan("let provider = SystemAccessories.makeProvider()").observers == 1)
        #expect(scan("let key = accessory.id").idReads == 1)
        #expect(scan("ForEach(accessories, id: \\.id) { _ in }").idReads == 1)
        // Not an ID: an `id:` label, an entity's own `id`, a longer name; nor text in a comment.
        let fine = """
            ForEach(rows, id: \\.offset) { _ in }
            var id: String { field.rawValue }
            let detail = BatteryWidgetDetail.init(id: raw)
            let name = source.identifier
            // never accessory.id or observeChanges(
            """
        #expect(scan(fine) == AccessoryScan(providerCalls: [], observers: 0, idReads: 0))
    }

    /// An accessory's own name reaches the screen only through `AccessoryNameText`, which marks it
    /// privacy sensitive, in case macOS ever redacts a widget (P2 §8.8).
    @Test func accessoryNamesArePrivacySensitive() throws {
        var namers = 0
        for file in try Self.widgetCode() {
            let namer = file.code.firstMatch(of: #/struct AccessoryNameText: View \{([\s\S]*?)\n\}/#)
            if let namer {
                namers += 1
                #expect(namer.output.1.contains(".privacySensitive()"), "\(file.path)")
            }
            for name in file.code.matches(of: #/\.reported\b/#.wordBoundaryKind(.simple))
            where namer?.range.contains(name.range.lowerBound) != true {
                Issue.record("\(file.path): an accessory's name outside AccessoryNameText")
            }
        }
        #expect(namers == 1)
    }

    /// VoiceOver never reads a symbol's name (0.6.1's level symbol read "Three-Quarter-Charged
    /// Battery" at 80 %): the widget draws SF Symbols only through `decorativeSymbol(_:)`, which
    /// hides them, and names no symbol for a label to show.
    @Test func symbolsAreDrawnOnlyAsDecoration() throws {
        var helpers = 0
        for file in try Self.widgetCode() {
            let scan = Self.symbolScan(file.code)
            if scan.definesHelper {
                helpers += 1
                #expect(scan.helperHides, "\(file.path)")
            }
            #expect(scan.symbolsOutside == 0, "\(file.path): a symbol outside decorativeSymbol(_:)")
        }
        #expect(helpers == 1)
    }

    /// What the symbol guard sees in one file's code.
    struct SymbolScan: Equatable {
        /// The file defines `decorativeSymbol(_:)`.
        var definesHelper: Bool
        /// Its body hides the symbol from VoiceOver.
        var helperHides: Bool
        /// SF Symbols drawn outside it, as an image or a label's icon.
        var symbolsOutside: Int
    }

    static func symbolScan(_ code: String) -> SymbolScan {
        let helper = code.firstMatch(of: #/func decorativeSymbol\([^{]*\{([\s\S]*?)\n\}/#)
        let outside = code.matches(of: #/\bImage\s*\(\s*systemName\s*:|\bsystemImage\s*:/#)
            .filter { helper?.range.contains($0.range.lowerBound) != true }
        return SymbolScan(
            definesHelper: helper != nil, helperHides: helper?.output.1.contains(".accessibilityHidden(true)") == true,
            symbolsOutside: outside.count)
    }

    /// The guard fails on a symbol drawn outside the helper and on a helper that doesn't hide it.
    @Test func theSymbolGuardFailsOnBadCode() {
        func scan(_ text: String) -> SymbolScan { Self.symbolScan(SourceScanner.codeOnly(text)) }
        let helper = """
            func decorativeSymbol(_ name: String) -> some View {
                Image(systemName: name).accessibilityHidden(true)
            }

            """
        #expect(scan(helper) == SymbolScan(definesHelper: true, helperHides: true, symbolsOutside: 0))
        #expect(scan(helper + "let shown = Image(systemName: \"battery.100percent\")").symbolsOutside == 1)
        #expect(scan(helper + "let spaced = Image ( systemName : name)").symbolsOutside == 1)
        #expect(scan(helper + "let label = Label(\"Battery\", systemImage: \"bolt\")").symbolsOutside == 1)
        // A comment doesn't hide the symbol, and without the helper every symbol is outside it.
        let commented = """
            func decorativeSymbol(_ name: String) -> some View {
                Image(systemName: name)  // .accessibilityHidden(true)
            }
            """
        #expect(scan(commented) == SymbolScan(definesHelper: true, helperHides: false, symbolsOutside: 0))
        let bare = SymbolScan(definesHelper: false, helperHides: false, symbolsOutside: 1)
        #expect(scan("let a = Image(systemName: name)") == bare)
    }

    /// Each widget choice's BatteryCore mirror, by intent and parameter name.
    static let mirrors: [String: [String: [String]]] = [
        "BatteryWidgetIntent": [
            "layout": WidgetLayoutMode.allCases.map(\.rawValue),
            "mainValue": BatteryWidgetMain.allCases.map(\.rawValue),
            "mainVisual": BatteryWidgetVisual.allCases.map(\.rawValue),
            "statusLines": WidgetStatusLine.allCases.map(\.rawValue),
            "time": WidgetTimeStyle.allCases.map(\.rawValue),
            "colors": WidgetColorStyle.allCases.map(\.rawValue),
            "updateTime": WidgetUpdateTimeStyle.allCases.map(\.rawValue),
        ],
        "AccessoriesWidgetIntent": [
            "mode": AccessoryWidgetMode.allCases.map(\.rawValue)
        ],
    ]

    /// The body of the widget's `struct <type>`, where its parameters are declared.
    static func intentBody(_ type: String, in code: String) throws -> Substring {
        try #require(
            code.firstMatch(of: try Regex("struct \(type)\\b[^{]*\\{([\\s\\S]*?)\\n\\}"))?.output[1].substring,
            "struct \(type)")
    }

    /// A mirror's cases that the widget doesn't offer yet, each with its reason. Removing a case
    /// from here is the commit that offers it.
    static let notOfferedYet: [String: [String]] = [:]

    /// Each `AppEnum` of the widget maps one to one to its BatteryCore mirror, with equal raw
    /// values: its cases are the manifest's values, which are the mirror's cases in order (less
    /// those not offered yet), and its mapping takes each case to the mirror's case of that name.
    @Test func eachChoiceMapsToItsMirror() throws {
        let code = try Self.widgetCode().map(\.code).joined(separator: "\n")
        let intents = WidgetIntentManifest.shipping.kinds.compactMap(\.intent)
        #expect(intents.count == 2)
        for intent in intents {
            let intentBody = try Self.intentBody(intent.type, in: code)
            for parameter in intent.parameters {
                guard let values = parameter.values else { continue }
                let declaration = try Regex("@Parameter\\b[^@]*?\\bvar\\s+\(parameter.name)\\s*:\\s*\\[?(\\w+)")
                let type = try #require(
                    intentBody.firstMatch(of: declaration)?.output[1].substring, "\(intent.type).\(parameter.name)")
                let body = try #require(
                    code.firstMatch(of: try Regex("enum \(type): String, AppEnum \\{([\\s\\S]*?)\\n\\}"))?.output[1]
                        .substring, "enum \(type)")
                // A case without a raw value of its own: its raw value is its name.
                let cases = body.matches(of: #/(?m)^\s*case\s+([a-z]\w*(?:\s*,\s*[a-z]\w*)*)\s*$/#)
                    .flatMap { $0.output.1.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                #expect(cases == values, "\(type)")
                let mirror = try #require(
                    Self.mirrors[intent.type]?[parameter.name], "no mirror for \(intent.type).\(parameter.name)")
                let pending = Self.notOfferedYet[parameter.name] ?? []
                #expect(values == mirror.filter { !pending.contains($0) }, "\(parameter.name)")
                for value in values {
                    #expect(body.contains("case .\(value): .\(value)"), "\(type).\(value)")
                }
            }
        }
        // Every pending case is a mirror's.
        for (name, pending) in Self.notOfferedYet {
            let mirror = Self.mirrors.values.compactMap { $0[name] }.first
            #expect(pending.allSatisfy { mirror?.contains($0) == true }, "\(name)")
        }
    }

    /// The `default:` argument of each of `type`'s parameters, as written; "none" without one.
    static func parameterDefaults(_ type: String) throws -> [String: String] {
        let code = try Self.widgetCode().map(\.code).joined(separator: "\n")
        let body = try Self.intentBody(type, in: code)
        let intent = try #require(WidgetIntentManifest.shipping.kinds.compactMap(\.intent).first { $0.type == type })
        var defaults: [String: String] = [:]
        for parameter in intent.parameters {
            let declaration = try Regex("@Parameter\\(([^@]*?)\\)\\s*var\\s+\(parameter.name)\\s*:")
            let arguments = try #require(body.firstMatch(of: declaration)?.output[1].substring, "\(parameter.name)")
            let value = arguments.firstMatch(of: #/\bdefault\s*:\s*(\[[^\]]*\]|\.\w+|true|false)/#)?.output.1
            defaults[parameter.name] = value.map { String($0.replacing(#/\s+/#, with: " ")) } ?? "none"
        }
        return defaults
    }

    /// Each parameter's default is `BatteryWidgetConfiguration()`'s, which W-1's first test pins to
    /// 0.6.1's widget: a widget placed before 0.7 gets every default, so changing one would change
    /// how every placed widget looks. Details has none: an empty Custom list shows no details.
    @Test func eachDefaultIsTodaysWidget() throws {
        let c = BatteryWidgetConfiguration()
        let expected: [String: String] = [
            "layout": ".\(c.layout.rawValue)",
            "mainValue": ".\(c.main.rawValue)",
            "mainVisual": ".\(c.visual.rawValue)",
            "statusLines": "[" + c.statusLines.map { ".\($0.rawValue)" }.joined(separator: ", ") + "]",
            "details": "none",
            "time": ".\(c.time.rawValue)",
            "colors": ".\(c.colors.rawValue)",
            "updateTime": ".\(c.updateTime.rawValue)",
        ]
        #expect(c.details.isEmpty)
        let defaults = try Self.parameterDefaults("BatteryWidgetIntent")
        #expect(defaults == expected)
    }

    /// The Accessories widget's defaults are `AccessoriesWidgetConfiguration()`'s: every accessory,
    /// lowest first, the full ones too.
    @Test func eachAccessoriesDefaultIsTheModels() throws {
        let c = AccessoriesWidgetConfiguration()
        #expect(c.mode == .all && !c.hidesFullyCharged)
        #expect(
            try Self.parameterDefaults("AccessoriesWidgetIntent") == [
                "mode": ".\(c.mode.rawValue)", "hideFullyCharged": "\(c.hidesFullyCharged)",
            ])
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
