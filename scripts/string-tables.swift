// Checks the string tables that xcstringstool compiled from the String Catalog, and removes the
// source language's table when it holds only identity entries:
//
//   swift scripts/string-tables.swift Resources/Localizable.xcstrings <Resources folder>...
//
// scripts/build-app.sh runs it on the app's and the widget's Resources folder. In each one:
// - The source language's table (en.lproj/Localizable.strings) is removed when every value equals
//   its key, which is what the catalog compiles to while its strings are keyed by their English
//   text: a lookup that finds no table returns the key, so only the size changes. A table with any
//   other entry, a variation for example, is kept. The en.lproj folder must stay, even empty: it
//   declares the English localization.
// - Every other language of the catalog has a table with every key that is translated
//   (Localizable.strings, or Localizable.stringsdict for a plural).
// A failed check exits with 1. It needs only Foundation, so it also runs on Linux.
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

// The property list at `url`, or nil when there is no file.
func propertyList(at url: URL) -> Any? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    do {
        return try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
    } catch {
        fail("can't read \(url.path): \(error)")
    }
}

// The entries of the string table at `url`, or nil when there is no file.
func table(at url: URL) -> [String: Any]? {
    guard let plist = propertyList(at: url) else { return nil }
    guard let entries = plist as? [String: Any] else { fail("\(url.path) is not a string table") }
    return entries
}

let arguments = CommandLine.arguments.dropFirst()
guard arguments.count >= 2, let catalogPath = arguments.first else {
    fail("usage: swift scripts/string-tables.swift <catalog>.xcstrings <Resources folder>...")
}
let catalogURL = URL(fileURLWithPath: catalogPath)
let catalog: [String: Any]
do {
    guard let object = try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any] else {
        fail("\(catalogPath) is not a String Catalog")
    }
    catalog = object
} catch {
    fail("can't read \(catalogPath): \(error)")
}
guard let sourceLanguage = catalog["sourceLanguage"] as? String,
    let strings = catalog["strings"] as? [String: [String: Any]]
else {
    fail("\(catalogPath) has no sourceLanguage or strings")
}
let tableName = catalogURL.deletingPathExtension().lastPathComponent
let translatedKeys = Set(strings.filter { $0.value["shouldTranslate"] as? Bool != false }.keys)
let languages = Set(strings.values.flatMap { ($0["localizations"] as? [String: Any] ?? [:]).keys })
    .subtracting([sourceLanguage]).sorted()

// Every folder is checked before any table is removed, so a failed check changes nothing.
for folder in arguments.dropFirst() {
    let resources = URL(fileURLWithPath: folder, isDirectory: true)
    let source = resources.appendingPathComponent("\(sourceLanguage).lproj", isDirectory: true)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        fail("\(folder) has no \(sourceLanguage).lproj, which declares the \(sourceLanguage) localization")
    }
    for language in languages {
        let lproj = resources.appendingPathComponent("\(language).lproj", isDirectory: true)
        let singulars = table(at: lproj.appendingPathComponent("\(tableName).strings"))
        let plurals = table(at: lproj.appendingPathComponent("\(tableName).stringsdict"))
        guard singulars != nil || plurals != nil else { fail("\(folder) has no \(language).lproj/\(tableName) table") }
        let found = Set((singulars ?? [:]).keys).union((plurals ?? [:]).keys)
        let missing = translatedKeys.subtracting(found).sorted()
        guard missing.isEmpty else {
            let examples = missing.prefix(5).map { "\"\($0)\"" }.joined(separator: ", ")
            fail("\(folder): \(language).lproj lacks \(missing.count) of the catalog's keys, for example \(examples)")
        }
        print("\(folder): \(language).lproj has all \(translatedKeys.count) keys")
    }
}
for folder in arguments.dropFirst() {
    let sourceTable = URL(fileURLWithPath: folder, isDirectory: true)
        .appendingPathComponent("\(sourceLanguage).lproj/\(tableName).strings")
    guard let entries = table(at: sourceTable) else { continue }
    let changed = entries.filter { $0.value as? String != $0.key }.count
    guard changed == 0 else {
        print(
            "\(folder): kept \(sourceLanguage).lproj/\(tableName).strings, \(changed) of its entries aren't their key")
        continue
    }
    do {
        try FileManager.default.removeItem(at: sourceTable)
    } catch {
        fail("can't remove \(sourceTable.path): \(error)")
    }
    print("\(folder): removed \(sourceLanguage).lproj/\(tableName).strings, all \(entries.count) entries are their key")
}
