import BatteryCore
import Foundation
import Testing

/// Keeps `Resources/Localizable.xcstrings` in sync with the app's UI strings.
///
/// Xcode extracts strings automatically, but the app is built with SwiftPM, so the catalog is
/// maintained by hand. This test finds the localized literals in `Sources/BatteryPulseApp` and
/// checks that each has a Russian translation with matching placeholders, and that the catalog
/// has no leftovers. The Developer section's ``RawKeyGlossary`` summaries are looked up by their
/// English text at run time, so they count as UI strings too. Conventions it relies on (see
/// `Localized.swift`): interpolations are always pre-formatted Strings, so every placeholder is
/// `%@`.
@Suite struct LocalizationCatalogTests {
    private static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Literals passed to these calls are localization keys.
    private static var localizingCall: Regex<(Substring, Substring)> {
        #/(?:\b(?:Text|Label|Button|Toggle|Picker|Section|LabeledContent|ValueRow|row|Card|Tab|TableColumn|Window|ContentUnavailableView|help|accessibilityLabel)\(|String\(\s*localized:|\btitle:|\bprompt:)\s*"((?:[^"\\]|\\.)*)"/#
    }

    /// Literal cases of `var title: LocalizedStringKey` switches and `("Label", value, color)` rows.
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

    private func catalog() throws -> Catalog {
        let url = Self.repository.appendingPathComponent("Resources/Localizable.xcstrings")
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
    }

    private func sourceKeys() throws -> Set<String> {
        let directory = Self.repository.appendingPathComponent("Sources/BatteryPulseApp")
        let enumerator = try #require(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil))
        var keys = RawKeyGlossary.summaries
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            var literals = source.matches(of: Self.localizingCall).map { String($0.output.1) }
            literals += source.matches(of: Self.tupleLiteral).map { String($0.output.1) }
            for block in source.matches(of: #/var title: LocalizedStringKey \{(?<body>[\s\S]*?)\n    \}/#) {
                literals += block.output.body.matches(of: Self.caseLiteral).map { String($0.output.1) }
            }
            for literal in literals where !Self.verbatim.contains(literal) {
                keys.insert(Self.catalogKey(for: literal))
            }
        }
        return keys
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
