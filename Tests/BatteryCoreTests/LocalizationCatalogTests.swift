import BatteryCore
import Foundation
import Testing

/// Keeps `Resources/Localizable.xcstrings` in sync with the app's UI strings.
///
/// Xcode extracts strings automatically, but the app is built with SwiftPM, so the catalog is
/// maintained by hand. This test finds the localized literals in `Sources/BatteryPulseApp` and
/// `Sources/BatteryPulseWidget` (whose bundle gets the same compiled catalog) and checks that each has a Russian translation with matching placeholders, and that the catalog
/// has no leftovers. The Developer section's ``RawKeyGlossary`` summaries are looked up by their
/// English text at run time, so they count as UI strings too. Conventions it relies on (see
/// `Localized.swift`): interpolations are always pre-formatted Strings, so every placeholder is
/// `%@`.
@Suite struct LocalizationCatalogTests {
    private static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Literals passed to these calls are localization keys.
    private static var localizingCall: Regex<(Substring, Substring)> {
        #/(?:\b(?:Text|Label|Link|Button|Toggle|Picker|Section|LabeledContent|ValueRow|row|figure|Card|confirmationDialog|Tab|TableColumn|Window|ContentUnavailableView|help|accessibilityLabel|configurationDisplayName|description|value)\(|String\(\s*localized:|\btitle:|\bdetail:|\bprompt:)\s*"((?:[^"\\]|\\.)*)"/#
    }

    /// App Intents' literal forms, which are build-time metadata the widget's edit sheet shows:
    /// `IntentDescription("…")`, a `ParameterSummary`'s `Summary("…")` and
    /// `TypeDisplayRepresentation(name: "…")`. `@Parameter(title:)` and
    /// `DisplayRepresentation(title:)` already match ``localizingCall``'s `title:`.
    private static var intentCall: Regex<(Substring, Substring)> {
        #/(?:\b(?:IntentDescription|Summary)\(|\bTypeDisplayRepresentation\(\s*name:)\s*"((?:[^"\\]|\\.)*)"/#
    }

    /// `static let title: LocalizedStringResource = "…"` and the other App Intents metadata a
    /// string literal initializes.
    private static var typedStaticLiteral: Regex<(Substring, Substring)> {
        #/\bstatic\s+(?:let|var)\s+\w+\s*:\s*(?:LocalizedStringResource|IntentDescription|TypeDisplayRepresentation|DisplayRepresentation)\s*=\s*"((?:[^"\\]|\\.)*)"/#
    }

    /// The `[.x: "…"]` entries of a `caseDisplayRepresentations` dictionary literal.
    private static var dictionaryLiteral: Regex<(Substring, Substring)> {
        #/\.\w+:\s*"((?:[^"\\]|\\.)*)"/#
    }

    /// Literal cases of `var title: LocalizedStringKey` (or `subtitle`, …) switches, and of
    /// `LocalizedStringResource` ones such as the widget's detail labels, and `("Label", value,
    /// color)` rows.
    private static var caseLiteral: Regex<(Substring, Substring)> {
        #/case \.\w+:\s*"((?:[^"\\]|\\.)*)"/#
    }
    private static var tupleLiteral: Regex<(Substring, Substring)> {
        #/\(\("((?:[^"\\]|\\.)*)",/#
    }

    /// Technical names shown verbatim, never translated.
    private static let verbatim: Set<String> = [
        "AppleSmartBattery", "IOPowerSources", "IOPSCopyExternalPowerAdapterDetails",
    ]

    private struct Catalog: Decodable {
        struct Entry: Decodable {
            struct Localization: Decodable {
                struct StringUnit: Decodable {
                    var state: String
                    var value: String
                }
                var stringUnit: StringUnit
            }
            var localizations: [String: Localization]?
        }
        var sourceLanguage: String
        var strings: [String: Entry]
    }

    /// The catalog and the source keys, decoded and scanned once for all the tests below.
    private static let decodedCatalog: Result<Catalog, any Error> = Result {
        let url = repository.appendingPathComponent("Resources/Localizable.xcstrings")
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    }
    private static let scannedSourceKeys: Result<Set<String>, any Error> = Result { try scanSourceKeys() }

    private func catalog() throws -> Catalog {
        try Self.decodedCatalog.get()
    }

    private func sourceKeys() throws -> Set<String> {
        try Self.scannedSourceKeys.get()
    }

    /// The localized literals of the app and the widget, from ``SourceScanner``'s files.
    private static func scanSourceKeys() throws -> Set<String> {
        var keys = RawKeyGlossary.summaries
        for file in try SourceScanner.files.get() {
            for literal in localizedLiterals(in: file.text) where !verbatim.contains(literal) {
                keys.insert(catalogKey(for: literal))
            }
        }
        return keys
    }

    /// The literals of `source` that are localization keys, in the order of the forms below.
    static func localizedLiterals(in source: String) -> [String] {
        var literals = source.matches(of: localizingCall).map { String($0.output.1) }
        literals += source.matches(of: tupleLiteral).map { String($0.output.1) }
        for block in source.matches(
            of: #/var \w+: (?:LocalizedStringKey|LocalizedStringResource) \{(?<body>[\s\S]*?)\n    \}/#)
        {
            literals += block.output.body.matches(of: caseLiteral).map { String($0.output.1) }
        }
        literals += source.matches(of: intentCall).map { String($0.output.1) }
        literals += source.matches(of: typedStaticLiteral).map { String($0.output.1) }
        for block in source.matches(of: #/\bcaseDisplayRepresentations\b[^=]*=\s*\[(?<body>[\s\S]*?)\]/#) {
            literals += block.output.body.matches(of: dictionaryLiteral).map { String($0.output.1) }
        }
        return literals
    }

    /// `"Charging at \(power)"` → `"Charging at %@"`, unescaping `\"`.
    static func catalogKey(for literal: String) -> String {
        var key = ""
        var index = literal.startIndex
        while index < literal.endIndex {
            if literal[index] == "\\", literal.index(after: index) < literal.endIndex {
                let next = literal.index(after: index)
                if literal[next] == "(" {
                    // Skip the balanced interpolation.
                    var depth = 0
                    var cursor = next
                    repeat {
                        if literal[cursor] == "(" { depth += 1 }
                        if literal[cursor] == ")" { depth -= 1 }
                        cursor = literal.index(after: cursor)
                    } while depth > 0 && cursor < literal.endIndex
                    key += "%@"
                    index = cursor
                    continue
                }
                key.append(literal[next])
                index = literal.index(after: next)
                continue
            }
            key.append(literal[index])
            index = literal.index(after: index)
        }
        return key
    }

    @Test func interpolationsBecomePlaceholders() {
        #expect(Self.catalogKey(for: #"Charging at \(power)"#) == "Charging at %@")
        #expect(Self.catalogKey(for: #"\(f.duration(minutes: m)) left"#) == "%@ left")
        #expect(Self.catalogKey(for: #"\(value.formatted()) of \(total.formatted())"#) == "%@ of %@")
    }

    /// A source fragment and the keys found in it.
    struct LiteralVector: Sendable, CustomTestStringConvertible {
        var source: String
        var keys: [String]
        var testDescription: String { source }

        init(_ source: String, _ keys: [String]) {
            self.source = source
            self.keys = keys
        }
    }

    /// One vector per App Intents form, so a key used only in intent metadata counts as used
    /// before any intent code exists.
    static let intentVectors: [LiteralVector] = [
        LiteralVector(
            #"static let title: LocalizedStringResource = "Choose Battery Details""#, ["Choose Battery Details"]),
        LiteralVector(
            #"static var title: LocalizedStringResource = "Choose Battery Details""#, ["Choose Battery Details"]),
        LiteralVector(#"static let description = IntentDescription("Choose a page.")"#, ["Choose a page."]),
        LiteralVector(#"static var description = IntentDescription("Choose a page.")"#, ["Choose a page."]),
        LiteralVector(#"static let description: IntentDescription = "Choose a page.""#, ["Choose a page."]),
        LiteralVector(#"IntentDescription("Choose a page.", categoryName: nil)"#, ["Choose a page."]),
        LiteralVector(#"@Parameter(title: "Main value", default: .charge) var main: MainEntity"#, ["Main value"]),
        LiteralVector(#"Summary("Show \(\.$main)") { \.$visual }"#, [#"Show \(\.$main)"#]),
        LiteralVector(#"static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Layout")"#, ["Layout"]),
        LiteralVector(#"static let typeDisplayRepresentation: TypeDisplayRepresentation = "Layout""#, ["Layout"]),
        LiteralVector(
            #".automatic: DisplayRepresentation(title: "Automatic", image: .init(systemName: "wand"))"#, ["Automatic"]),
        LiteralVector(
            """
            static let caseDisplayRepresentations: [LayoutEntity: DisplayRepresentation] = [
                .automatic: "Automatic",
                .custom: "Custom",
            ]
            """, ["Automatic", "Custom"]),
        LiteralVector(
            #"static let caseDisplayRepresentations: [Colors: DisplayRepresentation] = [.level: "Level colors"]"#,
            ["Level colors"]),
        // A detail's label, which its entity's `DisplayRepresentation(title:)` and the widget's row share.
        LiteralVector(
            """
            extension BatteryWidgetField {
                var label: LocalizedStringResource {
                    switch self {
                    case .state: "State"
                    case .maximumCapacity: "Maximum capacity"
                    }
                }
            }
            """, ["State", "Maximum capacity"]),
    ]

    @Test(arguments: intentVectors)
    func appIntentsLiteralsAreKeys(_ vector: LiteralVector) {
        #expect(Self.localizedLiterals(in: vector.source) == vector.keys)
    }

    /// The forms above stay narrow: other dictionaries, task names and summaries of our own aren't
    /// keys.
    @Test func otherLiteralsAreNotKeys() {
        let source = """
            let symbols: [Kind: String] = [.mouse: "computermouse"]
            Task(name: "WidgetRefresher.observe") {}
            let text = callSummary("raw")
            static let kind: String = "io.github.nikitausov.BatteryPulse.battery"
            """
        #expect(Self.localizedLiterals(in: source).isEmpty)
    }

    @Test func everyUIStringIsTranslated() throws {
        let catalog = try catalog()
        let missing = try sourceKeys().subtracting(catalog.strings.keys).sorted()
        #expect(missing.isEmpty, "Add to Resources/Localizable.xcstrings: \(missing)")
    }

    @Test func catalogHasNoLeftovers() throws {
        let unused = Set(try catalog().strings.keys).subtracting(try sourceKeys()).sorted()
        #expect(unused.isEmpty, "Remove from Resources/Localizable.xcstrings: \(unused)")
    }

    /// The repository is English only; Russian lives in the String Catalog and nowhere else.
    @Test func russianTextOnlyInTheCatalog() throws {
        let cyrillic = #/[\u{0400}-\u{04FF}]/#
        let textExtensions: Set<String> = ["swift", "md", "yml", "yaml", "sh", "json", "plist", "svg", "txt"]
        var offenders: [String] = []
        for folder in ["Sources", "Tests", "docs", "scripts", ".github", ".claude"] {
            let directory = Self.repository.appendingPathComponent(folder)
            guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
            else { continue }
            for case let url as URL in enumerator where textExtensions.contains(url.pathExtension) {
                let text = try String(contentsOf: url, encoding: .utf8)
                if text.contains(cyrillic) { offenders.append(url.path) }
            }
        }
        for file in ["README.md", "CLAUDE.md", "CONTRIBUTING.md", "SECURITY.md", "Package.swift"] {
            let url = Self.repository.appendingPathComponent(file)
            if let text = try? String(contentsOf: url, encoding: .utf8), text.contains(cyrillic) {
                offenders.append(url.path)
            }
        }
        #expect(offenders.isEmpty, "Russian text outside Resources/Localizable.xcstrings: \(offenders)")
    }

    /// A percentage has no space of any kind before its sign, in English and in Russian alike
    /// ("80%", never "80 %"), as ``BatteryFormatter/percent(_:fractionDigits:)`` writes it. A
    /// placeholder (`%@`, `%1$@`) is not a sign, so "Updated %@" is fine.
    @Test func noSpaceBeforeAPercentSign() throws {
        func spaced(_ text: String) -> Bool {
            let characters = Array(text)
            for index in characters.indices.dropFirst() where characters[index] == "%" {
                let rest = String(characters[(index + 1)...])
                let placeholder = rest.hasPrefix("@") || rest.prefixMatch(of: #/\d+\$@/#) != nil
                if !placeholder && characters[index - 1].isWhitespace { return true }
            }
            return false
        }
        #expect(["80 %", "80\u{00A0}%", "80\u{202F}%", "of 100 %."].allSatisfy(spaced))
        #expect(!["80%", "Updated %@", "%@ of %1$@", "99,5%"].contains(where: spaced))
        var offenders: [String] = []
        for (key, entry) in try catalog().strings {
            if spaced(key) { offenders.append(key) }
            for (language, localization) in entry.localizations ?? [:] where spaced(localization.stringUnit.value) {
                offenders.append("\(language): \(localization.stringUnit.value)")
            }
        }
        #expect(offenders.isEmpty, "A space before %: \(offenders.sorted())")
    }

    @Test func russianTranslationsAreCompleteAndKeepPlaceholders() throws {
        let catalog = try catalog()
        #expect(catalog.sourceLanguage == "en")
        for (key, entry) in catalog.strings {
            let russian = try #require(entry.localizations?["ru"]?.stringUnit, "No Russian for \"\(key)\"")
            #expect(russian.state == "translated", "\"\(key)\" is \(russian.state)")
            #expect(!russian.value.isEmpty, "Empty Russian for \"\(key)\"")
            #expect(
                russian.value.components(separatedBy: "%@").count == key.components(separatedBy: "%@").count,
                "Placeholders differ for \"\(key)\"")
        }
    }
}
