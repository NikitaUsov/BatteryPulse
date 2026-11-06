// Writes the widget's own String Catalog, the widget-only string table (INV SIZ-07): the entries
// of the app's catalog whose keys the widget's sources name, about a fifth of them, so the widget
// extension's .lproj folders hold its own words rather than the whole app's:
//
//   swift scripts/widget-strings.swift Resources/Localizable.xcstrings <output>.xcstrings \
//     Sources/BatteryPulseWidget Sources/BatteryCore/Widget
//
// A key is the widget's when a Swift file in one of the folders has it as a string literal, an
// interpolation counting as %@ ("Updated \(clock)" names "Updated %@"): the widget's views, its
// App Intents metadata, and the keys BatteryCore's widget model hands it for VoiceOver and its
// labels. A literal that only happens to equal a key (in a comment, say) adds an entry, which is
// harmless; a key the widget looks up but no file there names would draw in English, so
// `WidgetStringsTests` holds the widget's words to this rule on Linux. scripts/build-app.sh
// compiles the output into the extension and checks it with scripts/string-tables.swift, and CI's
// widget previews draw Russian from it. It needs only Foundation, so it also runs on Linux.
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

/// `"Charging at \(power)"` → `"Charging at %@"`: each balanced interpolation a placeholder, an
/// escaped character itself.
func catalogKey(_ literal: Substring) -> String {
    var key = ""
    var index = literal.startIndex
    while index < literal.endIndex {
        let character = literal[index]
        let next = literal.index(after: index)
        guard character == "\\", next < literal.endIndex else {
            key.append(character)
            index = next
            continue
        }
        if literal[next] == "(" {
            var depth = 0
            var cursor = next
            repeat {
                if literal[cursor] == "(" { depth += 1 }
                if literal[cursor] == ")" { depth -= 1 }
                cursor = literal.index(after: cursor)
            } while depth > 0 && cursor < literal.endIndex
            key += "%@"
            index = cursor
        } else {
            key.append(literal[next])
            index = literal.index(after: next)
        }
    }
    return key
}

/// Every one-line string literal of `source`, as a catalog key.
func literalKeys(in source: String) -> Set<String> {
    var keys: Set<String> = []
    for match in source.matches(of: #/"((?:[^"\\\n]|\\.)*)"/#) {
        keys.insert(catalogKey(match.output.1))
    }
    return keys
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 3 else {
    fail("usage: swift scripts/widget-strings.swift <catalog>.xcstrings <output>.xcstrings <source folder>...")
}
let catalogURL = URL(fileURLWithPath: arguments[0])
var catalog: [String: Any]
do {
    guard let object = try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any] else {
        fail("\(arguments[0]) is not a String Catalog")
    }
    catalog = object
} catch {
    fail("can't read \(arguments[0]): \(error)")
}
guard let strings = catalog["strings"] as? [String: Any] else { fail("\(arguments[0]) has no strings") }

var named: Set<String> = []
var files = 0
for folder in arguments.dropFirst(2) {
    let root = URL(fileURLWithPath: folder, isDirectory: true)
    guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
        fail("can't list \(folder)")
    }
    for case let url as URL in enumerator where url.pathExtension == "swift" {
        do {
            named.formUnion(literalKeys(in: try String(contentsOf: url, encoding: .utf8)))
            files += 1
        } catch {
            fail("can't read \(url.path): \(error)")
        }
    }
}
guard files > 0 else { fail("no Swift file in \(arguments.dropFirst(2).joined(separator: ", "))") }

let kept = strings.filter { named.contains($0.key) }
catalog["strings"] = kept
do {
    let data = try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: URL(fileURLWithPath: arguments[1]))
} catch {
    fail("can't write \(arguments[1]): \(error)")
}
print("\(arguments[1]): \(kept.count) of the catalog's \(strings.count) keys, named in \(files) files")
