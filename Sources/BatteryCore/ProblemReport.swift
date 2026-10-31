import Foundation

/// The text file that Help → Report a Problem… previews and saves for a GitHub issue
/// (``fileName``). Nothing in it is sent: the user attaches it himself.
///
/// One UTF-8 text in English, like the text report and the captures, whatever the app's
/// language; the preview shows these bytes, so what the user sees is what he saves. It holds:
/// - the app's version and build, the system's version string (shown, never parsed) and the Mac's
///   model;
/// - the settings of ``includedSettings``;
/// - this launch's signposts (``PerfSummary``);
/// - the names of the app's crash reports (``isCrashReportName(_:)``);
/// - the battery capture, redacted as Export Capture redacts it
///   (``BatteryReading/redactedRawCapture``); the accessories, pseudonymized as
///   `bpulse --accessories --raw` writes them (``AccessoryReading/redactedRawCapture``); and the
///   last iPhone or iPad capture, redacted as `bpulse --device --raw` writes it
///   (``IDeviceCapture/redactedRawCapture``). Each is the XML property list `bpulse --input`
///   reads, between a BEGIN and an END line, so it can be cut out whole;
/// - only when the user also chooses so, the crash reports' contents, without their identifiers
///   and with the home folder written as `~` (``scrubbedCrashReport(_:homeDirectory:)``).
public enum ProblemReport {
    /// The name the Save panel suggests.
    public static let fileName = "BatteryPulse-report.txt"

    /// Where macOS writes the user's crash reports, relative to the home folder.
    public static let crashReportsFolder = "Library/Logs/DiagnosticReports"

    /// The app and the Mac, as the report names them.
    public struct Identity: Sendable, Equatable {
        /// `CFBundleShortVersionString`.
        public var appVersion: String?
        /// `CFBundleVersion`.
        public var build: String?
        /// `ProcessInfo`'s version string, such as "Version 27.1 (Build 27B48)": shown as it is.
        public var systemVersion: String
        /// The model identifier, such as "Mac17,3"; `nil` when unknown.
        public var model: String?

        public init(appVersion: String?, build: String?, systemVersion: String, model: String?) {
            self.appVersion = appVersion
            self.build = build
            self.systemVersion = systemVersion
            self.model = model
        }
    }

    /// A crash report of the app's, by its file name.
    public struct CrashReport: Sendable, Equatable {
        public var name: String
        /// The file, read only when its contents go in; `nil` when it wasn't read or couldn't be.
        public var contents: Data?

        public init(name: String, contents: Data? = nil) {
            self.name = name
            self.contents = contents
        }
    }

    /// What the crash reports folder showed.
    public enum CrashReports: Sendable, Equatable {
        /// The folder couldn't be listed: the report says so, and the app shows no error.
        case notReadable
        /// The app's reports, in the order to list them; the others are dropped.
        case found([CrashReport])
    }

    /// Everything the report is made of, read by the app when its window opens.
    public struct Inputs: Sendable {
        /// When the report was made.
        public var date: Date
        public var identity: Identity
        /// Demo Mode's scene while it is on. The battery capture is still this Mac's own.
        public var demoScene: String?
        /// The system's battery read; `nil` when it found no battery.
        public var battery: BatteryReading?
        /// `nil` when the accessories weren't read.
        public var accessories: AccessoryReading?
        /// The last iPhone or iPad capture since launch; `nil` while device reading is off or
        /// before a device was read.
        public var device: IDeviceCapture?
        /// The values of ``ProblemReport/includedSettings``, by key; any other key is dropped.
        public var settings: [String: SettingValue]
        public var perf: PerfSummary.Snapshot
        public var crashReports: CrashReports
        /// The second choice: the crash reports' contents go in too.
        public var includesCrashContents: Bool
        /// The user's home folder, written as `~` in the crash reports' contents.
        public var homeDirectory: String

        public init(
            date: Date, identity: Identity, demoScene: String? = nil, battery: BatteryReading?,
            accessories: AccessoryReading?, device: IDeviceCapture?, settings: [String: SettingValue],
            perf: PerfSummary.Snapshot, crashReports: CrashReports, includesCrashContents: Bool,
            homeDirectory: String
        ) {
            self.date = date
            self.identity = identity
            self.demoScene = demoScene
            self.battery = battery
            self.accessories = accessories
            self.device = device
            self.settings = settings
            self.perf = perf
            self.crashReports = crashReports
            self.includesCrashContents = includesCrashContents
            self.homeDirectory = homeDirectory
        }
    }

    /// The report, built off the caller's actor: the captures' property lists and the crash
    /// reports' contents take a while.
    @concurrent
    public static func assemble(_ inputs: Inputs) async -> String {
        text(for: inputs)
    }

    /// The report's text: ``assemble(_:)`` without leaving the caller's actor.
    public static func text(for inputs: Inputs) -> String {
        text(for: inputs, limits: .standard)
    }

    /// How much of the crash reports' contents goes in.
    struct ContentLimits {
        /// The largest crash report whose contents go in.
        var perReport: Int
        /// All the contents together.
        var total: Int

        /// 2 MB a report and 20 MB in all, so the file stays under GitHub's 25 MB for an
        /// attachment.
        static let standard = ContentLimits(perReport: 2_000_000, total: 20_000_000)
    }

    static func text(for inputs: Inputs, limits: ContentLimits) -> String {
        var report = ReportText()
        report.line("BatteryPulse problem report, made \(inputs.date.formatted(.iso8601))")
        report.line("BatteryPulse sends nothing: this file stays on this Mac until it is attached to an issue.")
        report.line(
            "Left out: serial numbers, the battery's manufacturing data, the iPhone's or iPad's identifiers "
                + "and name, and the accessories' names and addresses.")

        report.section("BatteryPulse")
        let identity = inputs.identity
        let version = identity.appVersion.map(oneLine) ?? "unknown"
        let build = identity.build.map(oneLine).flatMap { $0 == version ? nil : $0 }
        report.line("Version: \(version)" + (build.map { " (\($0))" } ?? ""))
        report.line("macOS: \(oneLine(identity.systemVersion))")
        report.line("Mac: \(identity.model.map(oneLine) ?? "unknown")")
        report.line(
            inputs.demoScene.map { "Demo Mode: on (\(oneLine($0))); the battery capture is still this Mac's own" }
                ?? "Demo Mode: off")

        report.section("Settings")
        for line in settingsLines(inputs.settings) { report.line(line) }

        report.section("Performance since launch (\(elapsedText(inputs.perf.elapsed)))")
        let perfLines = inputs.perf.lines
        report.line(
            perfLines.isEmpty
                ? "Nothing measured yet."
                : "Intervals: count, total and longest time; events: count. By signpost name and trigger.")
        for line in perfLines { report.line(line) }

        let crashReports = Self.crashReports(in: inputs.crashReports)
        report.section("Crash reports")
        switch crashReports {
        case nil: report.line("Not readable: ~/\(crashReportsFolder) couldn't be listed.")
        case let reports? where reports.isEmpty: report.line("None in ~/\(crashReportsFolder).")
        case let reports?:
            report.line("In ~/\(crashReportsFolder):")
            for crashReport in reports { report.line(crashReport.name) }
            report.line(
                inputs.includesCrashContents
                    ? "Their contents are at the end of this file."
                    : "Their contents are not included.")
        }

        report.section("Battery")
        if let battery = inputs.battery {
            report.capture("battery", battery.redactedRawCapture)
        } else {
            report.line("Not read: the system reported no internal battery.")
        }

        report.section("Accessories")
        if let accessories = inputs.accessories {
            report.capture("accessories", accessories.redactedRawCapture)
        } else {
            report.line("Not read.")
        }

        report.section("iPhone or iPad")
        if let device = inputs.device {
            report.line("The last capture since launch.")
            report.capture("device", device.redactedRawCapture)
        } else {
            report.line("None: reading iPhones and iPads is off, or none was read since launch.")
        }

        if inputs.includesCrashContents, let reports = crashReports, !reports.isEmpty {
            report.section("Crash report contents")
            report.line(
                "Their identifiers left out (\(crashReportIdentifiers.sorted().joined(separator: ", "))), "
                    + "and the home folder written as ~.")
            var budget = limits.total
            for crashReport in reports {
                report.crashReport(
                    crashReport, homeDirectory: inputs.homeDirectory, largest: limits.perReport, budget: &budget)
            }
        }
        return report.text
    }

    // MARK: Crash reports

    /// Whether a file of the crash reports folder is one of the app's: the app's, the widget's
    /// (`BatteryPulseWidget…`) or the command-line tool's.
    public static func isCrashReportName(_ name: String) -> Bool {
        (name.hasPrefix("BatteryPulse") || name.hasPrefix("bpulse")) && !name.contains("/")
    }

    /// The members a crash report's contents go in without: Apple's per-device identifier, which
    /// is the same in every report of this Mac, and the report's own, which the header repeats as
    /// `incident_id`. `deviceIdentifierForVendor` takes the per-device one's place in TestFlight
    /// builds.
    static let crashReportIdentifiers: Set<String> = [
        "crashReporterKey", "incident", "incident_id", "deviceIdentifierForVendor",
    ]

    /// A crash report's contents as they go in: its JSON objects (an `.ips` file holds two, the
    /// header line and the report) without ``crashReportIdentifiers`` at any depth, every other
    /// byte as written, and the home folder written as `~`. `nil` unless `data` is JSON.
    static func scrubbedCrashReport(_ data: Data, homeDirectory: String) -> String? {
        guard let json = JSONMemberCutter.removing(crashReportIdentifiers, from: data) else { return nil }
        return replacingHomeFolder(homeDirectory, in: String(decoding: json, as: UTF8.self))
    }

    /// `text` with `home` and its JSON-escaped form (`\/Users\/name`) written as `~`, wherever
    /// the name ends there: `/Users/jane2` stays for the home `/Users/jane`.
    static func replacingHomeFolder(_ home: String, in text: String) -> String {
        var home = home
        while home.count > 1, home.hasSuffix("/") { home.removeLast() }
        guard home.count > 1, home.hasPrefix("/") else { return text }
        var result = text
        for form in [home, home.replacing("/", with: "\\/")] {
            result = replacingPath(form, in: result)
        }
        return result
    }

    /// `text` with each `path` that ends a name written as `~`. On UTF-8 bytes: a crash report's
    /// contents can be 2 MB.
    private static func replacingPath(_ path: String, in text: String) -> String {
        let bytes = Array(text.utf8)
        let path = Array(path.utf8)
        guard let first = path.first, bytes.count >= path.count else { return text }
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var index = 0
        while index < bytes.count {
            if bytes[index] == first, bytes.count - index >= path.count,
                bytes[index..<index + path.count].elementsEqual(path),
                index + path.count == bytes.count || !isNameByte(bytes[index + path.count])
            {
                output.append(UInt8(ascii: "~"))
                index += path.count
            } else {
                output.append(bytes[index])
                index += 1
            }
        }
        return String(decoding: output, as: UTF8.self)
    }

    /// A byte that continues a folder's name: a letter, a digit, `.`, `_`, `-`, or part of a
    /// character beyond ASCII.
    private static func isNameByte(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: "a")...UInt8(ascii: "z"), UInt8(ascii: "A")...UInt8(ascii: "Z"),
            UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "."), UInt8(ascii: "_"), UInt8(ascii: "-"), 0x80...:
            true
        default: false
        }
    }

    /// The app's reports, with names that fit on one line; `nil` when the folder wasn't readable.
    private static func crashReports(in reports: CrashReports) -> [CrashReport]? {
        guard case .found(let reports) = reports else { return nil }
        return reports.filter { isCrashReportName($0.name) }.map { report in
            var report = report
            report.name = oneLine(report.name)
            return report
        }
    }

    // MARK: Text

    /// The marker lines around an attachment: a capture or a crash report.
    static func beginLine(_ kind: String, _ name: String) -> String { "-----BEGIN BATTERYPULSE \(kind) \(name)-----" }
    static func endLine(_ kind: String, _ name: String) -> String { "-----END BATTERYPULSE \(kind) \(name)-----" }

    /// The XML property list of the capture `name` (`battery`, `accessories` or `device`) in a
    /// report's text, as `bpulse --input` reads it. An XML string escapes `<`, so the first
    /// `</plist>` before the END line ends it.
    static func capture(named name: String, in text: String) -> String? {
        let begin = beginLine("CAPTURE", name) + "\n"
        guard let start = text.firstRange(of: begin)?.upperBound,
            let end = text[start...].firstRange(of: "</plist>\n" + endLine("CAPTURE", name))
        else { return nil }
        return String(text[start..<end.lowerBound]) + "</plist>\n"
    }

    /// `text` on one line: control characters and line separators become spaces, so a name can't
    /// break the report's structure.
    static func oneLine(_ text: String) -> String {
        String(
            String.UnicodeScalarView(
                text.unicodeScalars.map { scalar in
                    scalar.properties.generalCategory == .control || scalar == "\u{2028}" || scalar == "\u{2029}"
                        ? " " : scalar
                }))
    }

    /// "2 h 05 min", "12 min".
    static func elapsedText(_ elapsed: Duration) -> String {
        let minutes = max(elapsed.components.seconds, 0) / 60
        guard minutes >= 60 else { return "\(minutes) min" }
        let rest = String(minutes % 60)
        return "\(minutes / 60) h " + String(repeating: "0", count: 2 - rest.count) + rest + " min"
    }
}

/// The report as it is written: lines, sections and attachments.
private struct ReportText {
    private(set) var text = ""

    mutating func line(_ line: String) {
        text += line + "\n"
    }

    mutating func section(_ title: String) {
        text += "\n== \(title) ==\n"
    }

    mutating func capture(_ name: String, _ capture: PropertyDictionary) {
        guard let data = try? PropertyValue.xmlPropertyListData(capture) else {
            line("Not written: the capture isn't a property list.")
            return
        }
        line(ProblemReport.beginLine("CAPTURE", name))
        text += String(decoding: data, as: UTF8.self)
        if !text.hasSuffix("\n") { text += "\n" }
        line(ProblemReport.endLine("CAPTURE", name))
    }

    /// One report's contents, unless it is larger than `largest` or than what is left of `budget`.
    mutating func crashReport(
        _ report: ProblemReport.CrashReport, homeDirectory: String, largest: Int, budget: inout Int
    ) {
        line("")
        line(ProblemReport.beginLine("CRASH REPORT", report.name))
        if let contents = report.contents {
            if contents.count > largest {
                line("Left out: larger than \(largest) bytes.")
            } else if contents.count > budget {
                line("Left out: the file would grow too large to attach.")
            } else if let scrubbed = ProblemReport.scrubbedCrashReport(contents, homeDirectory: homeDirectory) {
                budget -= contents.count
                text += scrubbed
                if !text.hasSuffix("\n") { text += "\n" }
            } else {
                line("Left out: not a JSON crash report.")
            }
        } else {
            line("Not readable.")
        }
        line(ProblemReport.endLine("CRASH REPORT", report.name))
    }
}

/// Cuts named members out of JSON text and keeps every other byte as written, so the key order
/// and numbers too large for a `Double`, such as a register's 64 bits, stay as they were.
struct JSONMemberCutter {
    private let bytes: [UInt8]
    private let names: Set<String>
    private var index = 0
    private var cuts: [Range<Int>] = []
    /// Crash reports nest about ten deep; the limit only bounds the recursion.
    private static let maxDepth = 256

    /// `data` without the members named `names`, in every object at any depth; `nil` unless
    /// `data` is one or more JSON values separated by whitespace.
    static func removing(_ names: Set<String>, from data: Data) -> Data? {
        var cutter = JSONMemberCutter(bytes: Array(data), names: names)
        guard cutter.values() else { return nil }
        return cutter.result()
    }

    private init(bytes: [UInt8], names: Set<String>) {
        self.bytes = bytes
        self.names = names
    }

    private var current: UInt8? {
        index < bytes.count ? bytes[index] : nil
    }

    private mutating func skipWhitespace() {
        while let byte = current, byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09 { index += 1 }
    }

    private mutating func values() -> Bool {
        var count = 0
        while true {
            skipWhitespace()
            if current == nil { return count > 0 }
            guard value(depth: 0) else { return false }
            count += 1
        }
    }

    private mutating func value(depth: Int) -> Bool {
        guard depth < Self.maxDepth else { return false }
        skipWhitespace()
        switch current {
        case UInt8(ascii: "{"): return object(depth: depth)
        case UInt8(ascii: "["): return array(depth: depth)
        case UInt8(ascii: "\""): return string() != nil
        case nil: return false
        default: return scalar()
        }
    }

    /// At a quote: the string's bytes between its quotes, escapes as written. JSON allows no raw
    /// control character in a string, so a line of the report can't hide in one.
    private mutating func string() -> Range<Int>? {
        index += 1
        let start = index
        while let byte = current {
            switch byte {
            case UInt8(ascii: "\""):
                let range = start..<index
                index += 1
                return range
            case UInt8(ascii: "\\"): index += 2
            case 0..<0x20: return nil
            default: index += 1
            }
        }
        return nil
    }

    /// A number, `true`, `false` or `null`.
    private mutating func scalar() -> Bool {
        let start = index
        while let byte = current, Self.isScalarByte(byte) { index += 1 }
        let token = bytes[start..<index]
        guard !token.isEmpty else { return false }
        if ["true", "false", "null"].contains(where: { token.elementsEqual($0.utf8) }) { return true }
        return token.allSatisfy { Self.isNumberByte($0) }
    }

    private static func isScalarByte(_ byte: UInt8) -> Bool {
        isNumberByte(byte) || (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
    }

    private static func isNumberByte(_ byte: UInt8) -> Bool {
        (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) || byte == UInt8(ascii: "-")
            || byte == UInt8(ascii: "+") || byte == UInt8(ascii: ".") || byte == UInt8(ascii: "e")
            || byte == UInt8(ascii: "E")
    }

    private mutating func array(depth: Int) -> Bool {
        index += 1
        skipWhitespace()
        if current == UInt8(ascii: "]") {
            index += 1
            return true
        }
        while true {
            guard value(depth: depth + 1) else { return false }
            skipWhitespace()
            switch current {
            case UInt8(ascii: ","): index += 1
            case UInt8(ascii: "]"):
                index += 1
                return true
            default: return false
            }
        }
    }

    private mutating func object(depth: Int) -> Bool {
        index += 1
        skipWhitespace()
        if current == UInt8(ascii: "}") {
            index += 1
            return true
        }
        var members: [(range: Range<Int>, isCut: Bool)] = []
        while true {
            skipWhitespace()
            guard current == UInt8(ascii: "\"") else { return false }
            let start = index
            guard let key = string() else { return false }
            skipWhitespace()
            guard current == UInt8(ascii: ":") else { return false }
            index += 1
            guard value(depth: depth + 1) else { return false }
            members.append((start..<index, names.contains(name(key))))
            skipWhitespace()
            switch current {
            case UInt8(ascii: ","): index += 1
            case UInt8(ascii: "}"):
                index += 1
                cut(members)
                return true
            default: return false
            }
        }
    }

    /// A key's text, its escapes undone.
    private func name(_ key: Range<Int>) -> String {
        let raw = bytes[key]
        guard raw.contains(UInt8(ascii: "\\")) else { return String(decoding: raw, as: UTF8.self) }
        let literal = Data([UInt8(ascii: "\"")] + raw + [UInt8(ascii: "\"")])
        return (try? JSONSerialization.jsonObject(with: literal, options: .fragmentsAllowed)) as? String
            ?? String(decoding: raw, as: UTF8.self)
    }

    /// Marks the cut members of one object, each with one comma, so the rest stays valid JSON.
    private mutating func cut(_ members: [(range: Range<Int>, isCut: Bool)]) {
        for (position, member) in members.enumerated() where member.isCut {
            if members[(position + 1)...].contains(where: { !$0.isCut }) {
                // Up to the next member: its comma and the space before the next go too.
                cuts.append(member.range.lowerBound..<members[position + 1].range.lowerBound)
            } else if let kept = members[..<position].last(where: { !$0.isCut }) {
                // The last member that stays loses its comma.
                cuts.append(kept.range.upperBound..<member.range.upperBound)
            } else {
                cuts.append(members[0].range.lowerBound..<member.range.upperBound)
            }
        }
    }

    private func result() -> Data {
        var kept: [UInt8] = []
        kept.reserveCapacity(bytes.count)
        var position = 0
        for cut in cuts.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if cut.lowerBound > position { kept += bytes[position..<cut.lowerBound] }
            position = max(position, cut.upperBound)
        }
        kept += bytes[position...]
        return Data(kept)
    }
}

// MARK: - Settings

extension ProblemReport {
    /// A setting's stored value, as `UserDefaults.object(forKey:)` returns it.
    public enum SettingValue: Sendable, Equatable {
        case bool(Bool)
        case int(Int64)
        case double(Double)
        case string(String)
        case date(Date)
        case data(Data)
        /// An array or a dictionary, which no setting holds: left out.
        case other

        /// `nil` when the key isn't set. Numbers go through ``PropertyValue/init(any:)``, which
        /// tells a Boolean from a number on every platform.
        public init?(any value: Any?) {
            guard let value else { return nil }
            if let date = value as? Date {
                self = .date(date)
                return
            }
            switch PropertyValue(any: value) {
            case .bool(let bool): self = .bool(bool)
            case .int(let int): self = .int(int)
            case .double(let double): self = .double(double)
            case .string(let string): self = .string(string)
            case .data(let data): self = .data(data)
            case .array, .dictionary, nil: self = .other
            }
        }
    }

    /// The app's settings keys whose values the report shows. Each holds a Boolean, a number, a
    /// date, a version, a language or a choice's raw value; a string that isn't a plain word goes
    /// in as left out all the same (``settingText(key:value:)``). The two alert states are
    /// decoded first: the battery's holds only flags and a date, and the accessories' only its
    /// count goes in, since its keys are the accessories' ids.
    public static let includedSettings: Set<String> = [
        // Menu bar and Dock.
        "showInMenuBar", "showDockIcon", "menuBarShowsIcon", "menuBarShowsCharge", "menuBarShowsPower",
        "menuBarShowsTemperature", "menuBarIconStyle",
        // Keys of earlier versions, which `AppSettings.migrate()` reads at launch.
        "menuBarStyle", "menuBarIcon", "glassCards", "checkForUpdates",
        // Windows and the Welcome window.
        "showDeveloperSection", "showWelcomeAtLaunch", "hasSeenWelcome", "prefersCompactWindow", "windowLook",
        "betaWindowStyles",
        // Updates.
        "updateFrequency", "lastUpdateCheck", "skippedVersion", "lastSeenVersion",
        // History, devices and the widget's language.
        "recordHistory", "readDevices", "lastSeenLanguage",
        // Notifications.
        "alertChargeLimit", "alertLowBattery", "alertService", "alertHeat", "alertState", "alertAccessoryLow",
        "accessoryAlertState",
        // 0.7's anonymous version count (W-13), listed ahead of its keys.
        "anonymousVersionCount", "lastCountedVersion", "versionFirstLaunch",
    ]

    /// The app's settings keys the report leaves out, each with why.
    public static let excludedSettings: [String: String] = [
        "updateLeftover": "a path in the user's folders: where an update moved the previous version"
    ]

    /// The settings section: every key of ``includedSettings``, sorted, with its value or "not
    /// set". A key of `values` outside that list never appears.
    static func settingsLines(_ values: [String: SettingValue]) -> [String] {
        includedSettings.sorted().map { key in "\(key): \(settingText(key: key, value: values[key]))" }
    }

    /// One setting's value as the report writes it.
    static func settingText(key: String, value: SettingValue?) -> String {
        guard let value else { return "not set" }
        switch value {
        case .bool(let bool): return String(bool)
        case .int(let int): return String(int)
        case .double(let double): return String(double)
        case .string(let string):
            guard !string.isEmpty else { return "(empty)" }
            return isPlainWord(string) ? string : "left out: not a plain value"
        case .date(let date): return date.formatted(.iso8601)
        case .data(let data):
            switch key {
            case "alertState": return alertStateText(data)
            case "accessoryAlertState": return accessoryAlertStateText(data)
            default: return "left out: \(data.count) bytes"
            }
        case .other: return "left out: not a plain value"
        }
    }

    /// Letters, digits, `.`, `_` and `-`, at most 64: a version, a language or a raw value, never
    /// a path or a name with spaces.
    static func isPlainWord(_ string: String) -> Bool {
        string.unicodeScalars.count <= 64
            && string.unicodeScalars.allSatisfy { scalar in
                switch scalar {
                case "a"..."z", "A"..."Z", "0"..."9", ".", "_", "-": true
                default: false
                }
            }
    }

    /// ``AlertState``'s flags and date, as `BatteryNotifier` stores it (JSON).
    private static func alertStateText(_ data: Data) -> String {
        guard let state = try? JSONDecoder().decode(AlertState.self, from: data) else {
            return "left out: not readable"
        }
        var parts = [
            "chargeLimitArmed \(state.chargeLimitArmed)", "lowBatteryArmed \(state.lowBatteryArmed)",
            "serviceAnnounced \(state.serviceAnnounced)", "highTemperatureArmed \(state.highTemperatureArmed)",
        ]
        if let date = state.lastHighTemperatureAlert {
            parts.append("lastHighTemperatureAlert \(date.formatted(.iso8601))")
        }
        return parts.joined(separator: ", ")
    }

    /// How many accessories' alerts have fired; their ids stay out (``AccessoryBattery/id``).
    private static func accessoryAlertStateText(_ data: Data) -> String {
        guard let state = try? JSONDecoder().decode(AccessoryAlertState.self, from: data) else {
            return "left out: not readable"
        }
        return "\(state.firedAt.count) fired, the accessories left out"
    }
}
