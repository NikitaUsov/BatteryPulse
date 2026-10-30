// Checks the App Intents metadata that scripts/build-app.sh extracted into the widget against
// scripts/widget-manifest.json (the 0.7 plan's W-2):
//
//   swift scripts/appintents-check.swift <widget-manifest.json> <widget Resources folder>
//   swift scripts/appintents-check.swift --self-test
//
// The system shows a widget's edit sheet from Metadata.appintents/extract.actionsdata alone, and
// the processor can exit with 0 without writing it. So the check fails unless every intent,
// parameter and AppEnum case of the manifest is in the file, and it prints the keys of each
// ParameterSummary, which the String Catalog needs (the 0.6.2 widget spike's W0-1 (d)). While the
// manifest lists no intent and the widget has no metadata, there is nothing to check.
//
// extract.actionsdata is an undocumented Apple format that may change with Xcode, so the check
// fails, naming the problem, on a shape it doesn't know. --self-test runs it on
// scripts/appintents-sample.actionsdata, the metadata of the 0.6.2 widget spike's CI build, and on
// doctored copies of it, each of which must fail.
//
// A failed check exits with 1. It needs only Foundation, so it also runs on Linux.
import Foundation

let usage = """
    usage: swift scripts/appintents-check.swift <widget-manifest.json> <widget Resources folder>
           swift scripts/appintents-check.swift --self-test
    """

/// The format the check knows, named in every problem with the file's shape.
let knownFormat =
    "the check knows the format the 0.6.2 widget spike's build wrote with Xcode 27.1 (version 1, generator "
    + "xcode-tools 27A9275); update scripts/appintents-check.swift for this one"

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

/// Prints a line unbuffered, so it stays in order with the errors on stderr.
func say(_ line: String) {
    FileHandle.standardOutput.write(Data("\(line)\n".utf8))
}

/// The fields of scripts/widget-manifest.json (BatteryCore's `WidgetIntentManifest`) that the
/// check reads.
struct Manifest: Decodable {
    struct Kind: Decodable {
        var kind: String
        /// Nil for a static widget.
        var intent: Intent?
    }

    struct Intent: Decodable {
        var type: String
        var parameters: [Parameter]
    }

    struct Parameter: Decodable {
        var name: String
        /// The AppEnum's raw values, for an enum parameter.
        var values: [String]?
    }

    var kinds: [Kind]

    var intents: [Intent] { kinds.compactMap(\.intent) }
}

/// What a check prints, and the problems that fail it.
struct Report {
    var lines: [String] = []
    var problems: [String] = []
}

/// "1 intent", "2 intents".
func counted(_ count: Int, _ noun: String) -> String { "\(count) \(noun)\(count == 1 ? "" : "s")" }

/// A JSON value's kind, for a problem with the file's shape.
func kind(of value: Any?) -> String {
    guard let value else { return "missing" }
    if value is [String: Any] { return "an object" }
    if value is [Any] { return "an array" }
    if let text = value as? String { return "the string \"\(text)\"" }
    return "the value \(value)"
}

/// `value` as an object whose members are objects; a problem names each part that isn't.
func objectOfObjects(_ value: Any?, at path: String, _ problems: inout [String]) -> [String: [String: Any]] {
    guard let object = value as? [String: Any] else {
        problems.append("extract.actionsdata's \(path) is \(kind(of: value)), not an object: \(knownFormat)")
        return [:]
    }
    var members: [String: [String: Any]] = [:]
    for (key, member) in object {
        guard let member = member as? [String: Any] else {
            problems.append(
                "extract.actionsdata's \(path).\(key) is \(kind(of: member)), not an object: \(knownFormat)")
            continue
        }
        members[key] = member
    }
    return members
}

/// `value` as an array of objects; a problem names each part that isn't.
func arrayOfObjects(_ value: Any?, at path: String, _ problems: inout [String]) -> [[String: Any]] {
    guard let array = value as? [Any] else {
        problems.append("extract.actionsdata's \(path) is \(kind(of: value)), not an array: \(knownFormat)")
        return []
    }
    var elements: [[String: Any]] = []
    for (index, element) in array.enumerated() {
        guard let element = element as? [String: Any] else {
            problems.append(
                "extract.actionsdata's \(path)[\(index)] is \(kind(of: element)), not an object: \(knownFormat)")
            continue
        }
        elements.append(element)
    }
    return elements
}

/// The parts of extract.actionsdata the check reads.
struct Metadata {
    /// The intents, keyed by their type names.
    var actions: [String: [String: Any]]
    /// The AppEnums, keyed by their identifiers.
    var enums: [String: [String: Any]]
    /// The entities, keyed by their type names.
    var entities: [String: [String: Any]]
    var version: String
    var generator: String

    /// Nil, with the problems, when the file's top level isn't the shape the check knows.
    init?(_ root: Any, problems: inout [String]) {
        guard let root = root as? [String: Any] else {
            problems.append("extract.actionsdata's top level is \(kind(of: root)), not an object: \(knownFormat)")
            return nil
        }
        let before = problems.count
        actions = objectOfObjects(root["actions"], at: "actions", &problems)
        entities = objectOfObjects(root["entities"], at: "entities", &problems)
        enums = [:]
        for (index, appEnum) in arrayOfObjects(root["enums"], at: "enums", &problems).enumerated() {
            guard let identifier = appEnum["identifier"] as? String else {
                problems.append(
                    "extract.actionsdata's enums[\(index)].identifier is \(kind(of: appEnum["identifier"])), not a "
                        + "string: \(knownFormat)")
                continue
            }
            enums[identifier] = appEnum
        }
        version = root["version"].map { "\($0)" } ?? "missing"
        let generator = root["generator"] as? [String: Any]
        self.generator = [generator?["name"], generator?["version"]].compactMap { $0.map { "\($0)" } }
            .joined(separator: " ")
        guard problems.count == before else { return nil }
    }

    /// The action of an intent type: keyed by the type's name, or naming it as its identifier.
    func action(of type: String) -> (name: String, action: [String: Any])? {
        if let action = actions[type] { return (type, action) }
        return actions.first { $0.value["identifier"] as? String == type }.map { ($0.key, $0.value) }
    }
}

/// The AppEnum identifiers and entity type names that a parameter's value type names, at any depth
/// (the members of an array, for example).
func valueTypes(in value: Any?) -> (enums: [String], entities: [String]) {
    var enums: [String] = []
    var entities: [String] = []
    func visit(_ value: Any?) {
        if let array = value as? [Any] {
            array.forEach(visit)
        }
        guard let object = value as? [String: Any] else { return }
        for (key, member) in object {
            let wrapper = (member as? [String: Any])?["wrapper"] as? [String: Any]
            if key == "linkEnumeration", let identifier = wrapper?["identifier"] as? String {
                enums.append(identifier)
            }
            if key == "entity", let typeName = wrapper?["typeName"] as? String {
                entities.append(typeName)
            }
            visit(member)
        }
    }
    visit(value)
    return (enums, entities)
}

/// Every intent, parameter and AppEnum case of the manifest must be in the metadata.
func checkManifest(_ manifest: Manifest, _ metadata: Metadata, _ report: inout Report) {
    let before = report.problems.count
    var parameters = 0
    var cases = 0
    for intent in manifest.intents {
        guard let (name, action) = metadata.action(of: intent.type) else {
            let names = metadata.actions.keys.sorted().joined(separator: ", ")
            report.problems.append("the metadata lacks the intent \(intent.type); its actions are: \(names)")
            continue
        }
        let declared = arrayOfObjects(action["parameters"], at: "actions.\(name).parameters", &report.problems)
        for parameter in intent.parameters {
            parameters += 1
            cases += parameter.values?.count ?? 0
            guard let found = declared.first(where: { $0["name"] as? String == parameter.name }) else {
                report.problems.append("the metadata lacks the parameter \(parameter.name) of \(intent.type)")
                continue
            }
            guard let values = parameter.values else { continue }
            let named = valueTypes(in: found["valueType"]).enums
            guard named.count == 1, let identifier = named.first else {
                report.problems.append(
                    "\(intent.type).\(parameter.name) is an AppEnum in the manifest, but its value type in the "
                        + "metadata names \(named.isEmpty ? "none" : named.joined(separator: " and "))")
                continue
            }
            guard let appEnum = metadata.enums[identifier] else {
                report.problems.append(
                    "the metadata lacks the AppEnum \(identifier) of \(intent.type).\(parameter.name)")
                continue
            }
            let identifiers = Set(
                arrayOfObjects(appEnum["cases"], at: "enums[\(identifier)].cases", &report.problems)
                    .compactMap { $0["identifier"] as? String })
            for value in values where !identifiers.contains(value) {
                let place = "\(intent.type).\(parameter.name)"
                report.problems.append("the metadata lacks the case \(value) of \(place) (the AppEnum \(identifier))")
            }
        }
    }
    guard report.problems.count == before else { return }
    let intents = manifest.intents.count
    report.lines.append(
        "The metadata has the manifest's \(counted(intents, "intent")), \(counted(parameters, "parameter")), "
            + "\(counted(cases, "case"))")
}

/// The keys of every ParameterSummary, for the String Catalog (W0-1 (d)): each `summaryString`'s
/// `formatString`, which names a parameter as `${name}`.
func listSummaries(_ metadata: Metadata, _ report: inout Report) {
    var lines: [String] = []
    func visit(_ value: Any?, intent: String, path: [String]) {
        if let array = value as? [Any] {
            array.forEach { visit($0, intent: intent, path: path) }
        }
        guard let object = value as? [String: Any] else { return }
        for (key, member) in object.sorted(by: { $0.key < $1.key }) {
            guard key == "summaryString" else {
                let skipped: Set = ["wrapper", "actionConfiguration", "actionSummary"]
                visit(member, intent: intent, path: skipped.contains(key) ? path : path + [key])
                continue
            }
            let place = ([intent] + path).joined(separator: " ")
            guard let summary = member as? [String: Any], let format = summary["formatString"] as? String else {
                report.problems.append(
                    "\(place): a summaryString without a formatString, \(kind(of: member)): \(knownFormat)")
                continue
            }
            let parameters = (summary["parameterIdentifiers"] as? [Any] ?? []).map { "\($0)" }
            let named = parameters.isEmpty ? "" : " (parameters: \(parameters.joined(separator: ", ")))"
            lines.append("  \(place): \"\(format)\"\(named)")
        }
    }
    for name in metadata.actions.keys.sorted() {
        visit(metadata.actions[name], intent: name, path: [])
    }
    report.lines.append(lines.isEmpty ? "Summary keys: none" : "Summary keys, as the catalog needs them:")
    report.lines += lines
}

/// The check of one widget build: `metadata` is extract.actionsdata's JSON, nil when the widget has
/// none.
func check(manifest: Manifest, metadata root: Any?) -> Report {
    var report = Report()
    guard let root else {
        if manifest.intents.isEmpty {
            report.lines.append(
                "App Intents check: skipped (no intents): the manifest lists none, and the widget has no "
                    + "Metadata.appintents")
        } else {
            report.problems.append(
                "the widget has no Metadata.appintents/extract.actionsdata, but the manifest lists "
                    + "\(counted(manifest.intents.count, "intent")) (the processor can exit with 0 without writing it)")
        }
        return report
    }
    guard let metadata = Metadata(root, problems: &report.problems) else { return report }
    report.lines.append(
        "extract.actionsdata: version \(metadata.version), generator \(metadata.generator); actions: "
            + metadata.actions.keys.sorted().joined(separator: ", "))
    checkManifest(manifest, metadata, &report)
    listSummaries(metadata, &report)
    return report
}

/// The manifest of the 0.6.2 widget spike's configuration, as WidgetIntentManifest would export it:
/// what scripts/appintents-sample.actionsdata holds.
let sampleManifest = """
    {"kinds": [{"families": ["small", "medium"], "kind": "io.github.nikitausov.BatteryPulse.battery",
      "intent": {"type": "BatteryWidgetIntent", "parameters": [
        {"name": "layout", "values": ["automatic", "custom"]},
        {"name": "mainValue", "values": ["charge", "maximumCapacity", "temperature", "batteryPower"]},
        {"name": "time", "values": ["clockTime", "timeLeft"]},
        {"name": "details"}]}}]}
    """

/// Runs the check on the sample, which must pass, and on doctored copies, each of which must fail
/// with a problem that names what was changed; returns the failures.
func selfTest() -> [String] {
    var failures: [String] = []
    let sampleURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("appintents-sample.actionsdata")
    let sample: String
    let manifest: Manifest
    do {
        sample = try String(contentsOf: sampleURL, encoding: .utf8)
        manifest = try JSONDecoder().decode(Manifest.self, from: Data(sampleManifest.utf8))
    } catch {
        return ["can't read the sample or its manifest: \(error)"]
    }
    let noIntents = Manifest(kinds: [Manifest.Kind(kind: "io.github.nikitausov.BatteryPulse.battery")])
    func run(_ text: String?, _ manifest: Manifest) throws -> Report {
        try check(manifest: manifest, metadata: text.map { try JSONSerialization.jsonObject(with: Data($0.utf8)) })
    }

    // The sample passes.
    do {
        let report = try run(sample, manifest)
        if !report.problems.isEmpty {
            failures.append("the sample fails: \(report.problems.joined(separator: "; "))")
        }
        for expected in [
            "1 intent, 4 parameters, 8 cases",
            "BatteryWidgetIntent whenClause when: \"${layout}\" (parameters: layout)",
            "SpikeWidgetIntent: \"Show ${mainValue}\"",
        ] where !report.lines.contains(where: { $0.contains(expected) }) {
            failures.append("the sample's report lacks \"\(expected)\":\n\(report.lines.joined(separator: "\n"))")
        }
        say("The sample's report:")
        report.lines.forEach { say("  \($0)") }
    } catch {
        failures.append("the sample isn't JSON: \(error)")
    }

    // A changed copy of the sample: `target` must occur exactly once, unless `everywhere`. On a miss
    // the self-test fails, and the copy is the sample.
    func doctored(_ target: String, _ replacement: String, everywhere: Bool = false) -> String {
        let count = sample.components(separatedBy: target).count - 1
        guard count == 1 || (everywhere && count > 0) else {
            failures.append("the sample has \(count) of \(target), not one")
            return sample
        }
        return sample.replacingOccurrences(of: target, with: replacement)
    }
    let customCase = #",{"displayRepresentation":{"title":{"alternatives":[],"key":"Custom"}},"identifier":"custom"}"#
    let copies: [(name: String, text: String?, names: String)] = [
        ("a copy without the case custom", doctored(customCase, ""), "case custom"),
        ("a copy without the parameter time", doctored(#""name":"time""#, #""name":"clock""#), "parameter time"),
        (
            "a copy without the intent", doctored("BatteryWidgetIntent", "BatteryIntent", everywhere: true),
            "intent BatteryWidgetIntent"
        ),
        ("a top-level array", "[\(sample)]", "top level"),
        ("actions as an array", #"{"actions": [], "enums": [], "entities": {}}"#, "actions"),
        ("no enums", #"{"actions": {}, "entities": {}}"#, "enums"),
        ("no metadata for the manifest's intent", nil, "Metadata.appintents"),
    ]
    for copy in copies {
        do {
            let report = try run(copy.text, manifest)
            if report.problems.isEmpty {
                failures.append("\(copy.name) passes")
            } else if !report.problems.contains(where: { $0.contains(copy.names) }) {
                failures.append(
                    "\(copy.name) fails without naming \(copy.names): \(report.problems.joined(separator: "; "))")
            }
        } catch {
            failures.append("\(copy.name) isn't JSON: \(error)")
        }
    }
    // Without intents and without metadata there is nothing to check.
    do {
        let report = try run(nil, noIntents)
        if !report.problems.isEmpty || !report.lines.contains(where: { $0.contains("skipped (no intents)") }) {
            failures.append("a widget without intents isn't skipped: \(report.lines + report.problems)")
        }
    } catch {
        failures.append("a widget without intents: \(error)")
    }
    if failures.isEmpty {
        say("The self-test passed: the sample passes, and \(copies.count) doctored copies fail.")
    }
    return failures
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["--self-test"] {
    let failures = selfTest()
    guard failures.isEmpty else { fail("the self-test failed:\n" + failures.joined(separator: "\n")) }
    exit(0)
}
guard arguments.count == 2 else {
    fail(usage)
}
let manifest: Manifest
do {
    manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: URL(fileURLWithPath: arguments[0])))
} catch {
    fail("can't read the manifest \(arguments[0]): \(error)")
}
let metadataFolder = URL(fileURLWithPath: arguments[1], isDirectory: true)
    .appendingPathComponent("Metadata.appintents", isDirectory: true)
let actionsData = metadataFolder.appendingPathComponent("extract.actionsdata")
var metadata: Any?
if FileManager.default.fileExists(atPath: actionsData.path) {
    do {
        metadata = try JSONSerialization.jsonObject(with: Data(contentsOf: actionsData))
    } catch {
        fail("\(actionsData.path) isn't JSON, so it isn't the format the check knows: \(error)")
    }
    let versionFile = metadataFolder.appendingPathComponent("version.json")
    if let data = FileManager.default.contents(atPath: versionFile.path),
        let version = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    {
        let fields = version.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
        say("Metadata.appintents/version.json: \(fields.joined(separator: ", "))")
    }
}
let report = check(manifest: manifest, metadata: metadata)
report.lines.forEach(say)
guard report.problems.isEmpty else {
    fail("the App Intents metadata fails its check:\n" + report.problems.joined(separator: "\n"))
}
