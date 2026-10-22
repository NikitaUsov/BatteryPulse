// Checks the App Intents metadata that scripts/build-app.sh extracted into the widget, and prints
// it (W0-1, spike branch only):
//
//   swift scripts/appintents-metadata.swift <Metadata.appintents/extract.actionsdata> <intent>...
//
// The processor can exit with 0 without writing anything, so CI runs this on the bundle: every
// named intent must be a key of the file's `actions` (its type name, or the name with its module
// in front). Then the whole file is printed with sorted keys: the parameters, the entity query, the
// summary and the case display representations as the system reads them. A failed check exits with
// 1. It needs only Foundation, so it also runs on Linux.
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

let arguments = CommandLine.arguments.dropFirst()
guard let path = arguments.first, arguments.count > 1 else {
    fail("usage: appintents-metadata.swift <extract.actionsdata> <intent>...")
}
let url = URL(fileURLWithPath: path)
let object: Any
do {
    object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
} catch {
    fail("can't read \(path): \(error)")
}
guard let root = object as? [String: Any] else {
    fail("\(path) is not a JSON object")
}
let actions = root["actions"] as? [String: Any] ?? [:]
print("Top-level keys: \(root.keys.sorted().joined(separator: ", "))")
print("Actions: \(actions.keys.sorted().joined(separator: ", "))")
var missing: [String] = []
for intent in arguments.dropFirst() {
    if let key = actions.keys.first(where: { $0 == intent || $0.hasSuffix(".\(intent)") }) {
        print("Found \(intent) as \(key)")
    } else {
        missing.append(intent)
    }
}
do {
    let pretty = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    print(String(decoding: pretty, as: UTF8.self))
} catch {
    fail("can't print \(path): \(error)")
}
if !missing.isEmpty {
    fail("\(path) lacks the intents \(missing.joined(separator: ", "))")
}
