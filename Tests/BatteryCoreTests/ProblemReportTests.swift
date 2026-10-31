import Foundation
import Testing

@testable import BatteryCore

@Suite struct ProblemReportTests {
    static let iPhone = "iphone17promax-ios27.0.1-usb"
    static let date = Date(timeIntervalSince1970: 1_800_000_000)
    static let home = "/Users/janedoe"

    static let identity = ProblemReport.Identity(
        appVersion: "0.8.0", build: "812", systemVersion: "Version 27.1 (Build 27B48)", model: "Mac17,3")

    /// What the app hands ``ProblemReport/text(date:identity:demoScene:battery:accessories:device:settings:perf:crashReports:includesCrashContents:homeDirectory:)``.
    struct Inputs {
        var date = ProblemReportTests.date
        var identity = ProblemReportTests.identity
        var demoScene: String?
        var battery: BatteryReading?
        var accessories: AccessoryReading?
        var device: IDeviceCapture?
        var settings: [String: ProblemReport.SettingValue] = ["showInMenuBar": .bool(true)]
        var perf = PerfSummary.Snapshot()
        var crashReports: ProblemReport.CrashReports = .found([])
        var includesCrashContents = false
        var homeDirectory = ProblemReportTests.home

        var text: String {
            ProblemReport.text(
                date: date, identity: identity, demoScene: demoScene, battery: battery, accessories: accessories,
                device: device, settings: settings, perf: perf, crashReports: crashReports,
                includesCrashContents: includesCrashContents, homeDirectory: homeDirectory)
        }

        func text(limits: ProblemReport.ContentLimits) -> String {
            ProblemReport.text(
                date: date, identity: identity, demoScene: demoScene, battery: battery, accessories: accessories,
                device: device, settings: settings, perf: perf, crashReports: crashReports,
                includesCrashContents: includesCrashContents, homeDirectory: homeDirectory, limits: limits)
        }
    }

    static func inputs(
        battery: BatteryReading? = nil, accessories: AccessoryReading? = nil, device: IDeviceCapture? = nil,
        crashReports: ProblemReport.CrashReports = .found([]), includesCrashContents: Bool = false
    ) -> Inputs {
        Inputs(
            battery: battery, accessories: accessories, device: device, crashReports: crashReports,
            includesCrashContents: includesCrashContents)
    }

    // MARK: Redaction

    /// A capture with every value the fixture has redacted put back as a live read holds it, a
    /// different one each (data for the gauge blobs), plus a serial number as an integer and as
    /// data; the values are collected in `planted`, as the report could show them.
    static func planting(_ value: PropertyValue, key: String? = nil, planted: inout [String]) -> PropertyValue {
        switch value {
        case .string("REDACTED"):
            let marker = "LEAK\(planted.count)X"
            if key == "ManufacturerData" || key == "MfgData" {
                let data = Data(marker.utf8)
                planted.append(data.base64EncodedString())
                return .data(data)
            }
            planted.append(marker)
            return .string(marker)
        case .dictionary(let dictionary):
            return .dictionary(
                Dictionary(uniqueKeysWithValues: dictionary.map { ($0, planting($1, key: $0, planted: &planted)) }))
        case .array(let items):
            return .array(items.map { planting($0, planted: &planted) })
        default:
            return value
        }
    }

    static func plantedMac(_ fixture: Fixture, planted: inout [String]) throws -> BatteryReading {
        var raw = try fixtureDictionary(fixture.rawValue)
        guard
            case .dictionary(var smartBattery) = planting(
                raw[BatteryReading.CaptureKey.smartBattery] ?? .dictionary([:]), planted: &planted)
        else { throw ScanError() }
        smartBattery["FirmwareSerialNumber"] = .int(987_654_321_012)
        smartBattery["PackSerialData"] = .data(Data("PACKSERIAL42".utf8))
        planted += ["987654321012", Data("PACKSERIAL42".utf8).base64EncodedString()]
        raw[BatteryReading.CaptureKey.smartBattery] = .dictionary(smartBattery)
        for key in [BatteryReading.CaptureKey.powerSource, BatteryReading.CaptureKey.adapterDetails] {
            raw[key] = raw[key].map { planting($0, planted: &planted) }
        }
        return BatteryReading(rawCapture: raw, timestamp: date)
    }

    static func plantedDevice(planted: inout [String]) throws -> IDeviceCapture {
        guard case .dictionary(let raw) = planting(.dictionary(try fixtureDictionary(iPhone)), planted: &planted),
            let capture = IDeviceCapture(rawCapture: raw)
        else { throw ScanError() }
        return capture
    }

    /// The accessories' names, part names, identifiers, addresses and serial numbers, at any depth.
    static func accessoryIdentifiers(in value: PropertyValue, key: String? = nil) -> [String] {
        let identifying: Set<String> = [
            "Name", "Part Name", "Accessory Identifier", "Group Identifier", "Address", "Device Address", "BD_ADDR",
            "UUID",
        ]
        switch value {
        case .string(let string) where !string.isEmpty:
            guard let key, identifying.contains(key) || key.lowercased().contains("serial") else { return [] }
            return [string]
        case .dictionary(let dictionary): return dictionary.flatMap { accessoryIdentifiers(in: $1, key: $0) }
        case .array(let items): return items.flatMap { accessoryIdentifiers(in: $0, key: key) }
        default: return []
        }
    }

    struct ScanError: Error {}

    /// A report from each Mac fixture, with the iPhone and the accessories, holds none of their
    /// serial numbers, gauge blobs, UDIDs, device name, accessory names and addresses, and no user
    /// name or home folder.
    @Test(arguments: Fixture.allCases)
    func aReportHoldsNoIdentifier(_ fixture: Fixture) throws {
        var planted: [String] = []
        let battery = try Self.plantedMac(fixture, planted: &planted)
        let device = try Self.plantedDevice(planted: &planted)
        let accessories = try AccessoryFixture.synthetic.reading()
        var names = Self.accessoryIdentifiers(in: .dictionary(try AccessoryFixture.synthetic.raw()))
        #expect(names.contains("Desk Keyboard") && names.contains("02-00-00-00-00-01"))
        // The Mac's own battery, which the Mac's capture names the same way.
        names.removeAll { $0 == "InternalBattery-0" }
        // Planted: the captures do hold them before redaction.
        #expect(planted.count >= 5)
        let unredacted = try String(
            decoding: PropertyValue.xmlPropertyListData(battery.rawCapture), as: UTF8.self)
        #expect(unredacted.contains("987654321012"))

        let text = Self.inputs(battery: battery, accessories: accessories, device: device).text
        for value in planted + names {
            #expect(!text.contains(value), "\(value) leaked")
        }
        #expect(!text.contains("janedoe"))
        #expect(!text.contains("/Users/"))
        #expect(text.contains("REDACTED"))
    }

    /// Settings that hold a path never reach the report, nor do keys outside the allow list.
    @Test func settingsHoldNoPath() {
        var inputs = Self.inputs()
        inputs.settings = [
            "updateLeftover": .string(Self.home + "/Library/Caches/BatteryPulse.app"),
            "skippedVersion": .string(Self.home),
            "NSNavLastRootDirectory": .string(Self.home + "/Desktop"),
        ]
        let text = inputs.text
        #expect(!text.contains("janedoe"))
        #expect(text.contains("skippedVersion: left out: not a plain value"))
    }

    // MARK: Captures

    /// Each capture is cut out between its marker lines and reads back as the dictionary
    /// `bpulse --raw`, `--accessories --raw` and `--device --raw` write.
    @Test(arguments: Fixture.allCases)
    func markerLinesRoundTripEachCapture(_ fixture: Fixture) throws {
        let battery = try fixture.reading()
        let accessories = try AccessoryFixture.synthetic.reading()
        let device = try #require(IDeviceCapture(rawCapture: try fixtureDictionary(Self.iPhone)))
        let text = Self.inputs(battery: battery, accessories: accessories, device: device).text
        let expected: [String: PropertyDictionary] = [
            "battery": battery.redactedRawCapture, "accessories": accessories.redactedRawCapture,
            "device": device.redactedRawCapture,
        ]
        for (name, capture) in expected {
            let xml = try #require(ProblemReport.capture(named: name, in: text), "\(name)")
            #expect(xml.hasPrefix("<?xml"))
            let root = try PropertyListSerialization.propertyList(from: Data(xml.utf8), format: nil)
            #expect(PropertyValue.dictionary(fromAny: root) == capture, "\(name)")
            #expect(
                text.contains(
                    ProblemReport.beginLine("CAPTURE", name) + "\n" + xml + ProblemReport.endLine("CAPTURE", name)
                        + "\n"))
        }
        // `bpulse --input` reads the battery's back into the same battery.
        let xml = try #require(ProblemReport.capture(named: "battery", in: text))
        let root = try PropertyListSerialization.propertyList(from: Data(xml.utf8), format: nil)
        let reread = BatteryReading(
            rawCapture: try #require(PropertyValue.dictionary(fromAny: root)), timestamp: Self.date)
        #expect(reread.snapshot.redacted == battery.snapshot.redacted)
    }

    @Test func missingReadsSaySo() {
        let text = Self.inputs().text
        #expect(text.contains("== Battery ==\nNot read: the system reported no internal battery.\n"))
        #expect(text.contains("== Accessories ==\nNot read.\n"))
        #expect(
            text.contains(
                "== iPhone or iPad ==\nNone: reading iPhones and iPads is off, or none was read since launch.\n"))
        #expect(ProblemReport.capture(named: "battery", in: text) == nil)
        #expect(!text.contains("BEGIN BATTERYPULSE"))
    }

    // MARK: The header

    @Test func theHeaderNamesTheAppAndTheMac() {
        let text = Self.inputs().text
        #expect(text.hasPrefix("BatteryPulse problem report, made 2027-01-15T08:00:00Z\n"))
        #expect(
            text.contains(
                "\n== BatteryPulse ==\nVersion: 0.8.0 (812)\nmacOS: Version 27.1 (Build 27B48)\nMac: Mac17,3\nDemo Mode: off\n"
            ))
        #expect(text.contains("\n== Settings ==\n"))
        #expect(text.contains("showInMenuBar: true\n"))
        #expect(text.hasSuffix("\n"))
        #expect(!text.hasSuffix("\n\n"))
    }

    @Test func aBuildLikeTheVersionAndUnknownsAreWrittenPlainly() {
        var inputs = Self.inputs()
        inputs.identity = ProblemReport.Identity(
            appVersion: "0.0.0", build: "0.0.0", systemVersion: "Version 27.1\n(Build 27B48)", model: nil)
        inputs.demoScene = "Charging\nhot"
        let text = inputs.text
        #expect(text.contains("\nVersion: 0.0.0\nmacOS: Version 27.1 (Build 27B48)\nMac: unknown\n"))
        #expect(text.contains("\nDemo Mode: on (Charging hot); the battery capture is still this Mac's own\n"))
        inputs.identity = ProblemReport.Identity(appVersion: nil, build: nil, systemVersion: "", model: "Mac17,3")
        #expect(inputs.text.contains("\nVersion: unknown\n"))
    }

    @Test func thePerformanceSectionListsTheSummary() {
        var inputs = Self.inputs()
        #expect(
            inputs.text.contains("== Performance since launch (0 min) ==\nNothing measured yet.\n"))
        let summary = PerfSummary(started: .now)
        summary.recordInterval("read", trigger: "full", duration: .milliseconds(12))
        summary.recordEvent("menuBarReady", trigger: "-")
        inputs.perf = summary.snapshot(now: summary.started + .seconds(2 * 3600 + 5 * 60 + 59))
        let text = inputs.text
        #expect(text.contains("== Performance since launch (2 h 05 min) ==\n"))
        #expect(text.contains("\nread full: 1 in 12.000 ms, longest 12.000 ms\nmenuBarReady: 1\n"))
    }

    @Test(arguments: [
        (Duration.zero, "0 min"), (.seconds(59), "0 min"), (.seconds(12 * 60), "12 min"),
        (.seconds(3600), "1 h 00 min"),
        (.seconds(26 * 3600 + 7 * 60), "26 h 07 min"),
    ])
    func elapsedTime(_ elapsed: Duration, text: String) {
        #expect(ProblemReport.elapsedText(elapsed) == text)
    }

    @Test func theFileName() {
        #expect(ProblemReport.fileName == "BatteryPulse-report.txt")
    }

    // MARK: Settings

    /// Every settings key the app defines (a `static let …Key = "…"` in its sources) is either
    /// shown or left out with a reason, so a new key can't reach the report unchecked, or be
    /// forgotten.
    @Test func everySettingsKeyIsIncludedOrLeftOut() throws {
        let keys = try Self.appSettingsKeys()
        // The scan finds the keys: AppSettings' and the widget refresher's.
        #expect(keys.isSuperset(of: ["showInMenuBar", "updateLeftover", "readDevices", "lastSeenLanguage"]))
        for key in keys.sorted() {
            #expect(
                ProblemReport.includedSettings.contains(key) || ProblemReport.excludedSettings[key] != nil,
                "\(key) is in neither list")
        }
        #expect(ProblemReport.includedSettings.isDisjoint(with: ProblemReport.excludedSettings.keys))
        #expect(ProblemReport.excludedSettings.values.allSatisfy { !$0.isEmpty })
    }

    /// The values of `static let …Key = "…"` declarations in the app's sources. A declaration is
    /// found in the code with comments and strings blanked, and its literal read from the text at
    /// the same offset.
    static func appSettingsKeys() throws -> Set<String> {
        let declaration = #/\bstatic\s+let\s+\w+Key\s*=\s*"/#.wordBoundaryKind(.simple)
        var keys: Set<String> = []
        for file in try SourceScanner.files.get()
        where file.path.hasPrefix("BatteryPulseApp/") && file.code.contains("Key") {
            for match in file.code.matches(of: declaration) {
                let offset = file.code.distance(from: file.code.startIndex, to: match.range.upperBound)
                let literal = file.text[file.text.index(file.text.startIndex, offsetBy: offset)...].prefix {
                    $0 != "\""
                }
                keys.insert(String(literal))
            }
        }
        return keys
    }

    @Test func settingsShowEveryIncludedKeyAndNothingElse() {
        let lines = ProblemReport.settingsLines([
            "showInMenuBar": .bool(false),
            "alertChargeLimit": .int(80),
            "windowLook": .string("frosted"),
            "lastUpdateCheck": .date(Date(timeIntervalSince1970: 1_800_000_000)),
            "updateLeftover": .string("/Users/jane/.Trash/BatteryPulse.app"),
            "NSWindow Frame main": .string("0 0 800 600"),
        ])
        #expect(lines.count == ProblemReport.includedSettings.count)
        #expect(lines == lines.sorted())
        #expect(lines.contains("showInMenuBar: false"))
        #expect(lines.contains("alertChargeLimit: 80"))
        #expect(lines.contains("windowLook: frosted"))
        #expect(lines.contains("lastUpdateCheck: 2027-01-15T08:00:00Z"))
        #expect(lines.contains("readDevices: not set"))
        let text = lines.joined(separator: "\n")
        #expect(!text.contains("updateLeftover"))
        #expect(!text.contains("jane"))
        #expect(!text.contains("NSWindow"))
    }

    /// A string that isn't a plain word, such as a path or a name, stays out even under an
    /// included key.
    @Test(arguments: [
        ("0.7.1", "0.7.1"), ("zh-Hans", "zh-Hans"), ("battery_outline", "battery_outline"), ("", "(empty)"),
        ("/Users/jane/Downloads", "left out: not a plain value"),
        ("Jane's AirPods", "left out: not a plain value"),
        ("Gerät", "left out: not a plain value"),
        (String(repeating: "a", count: 65), "left out: not a plain value"),
    ])
    func onlyPlainStringsGoIn(value: String, text: String) {
        #expect(ProblemReport.settingText(key: "skippedVersion", value: .string(value)) == text)
    }

    @Test func otherValuesAreWrittenPlainly() {
        #expect(ProblemReport.settingText(key: "alertHeat", value: .bool(true)) == "true")
        #expect(ProblemReport.settingText(key: "alertLowBattery", value: .int(-1)) == "-1")
        #expect(ProblemReport.settingText(key: "alertLowBattery", value: .double(0.5)) == "0.5")
        #expect(ProblemReport.settingText(key: "alertLowBattery", value: nil) == "not set")
        #expect(ProblemReport.settingText(key: "glassCards", value: .other) == "left out: not a plain value")
        #expect(ProblemReport.settingText(key: "glassCards", value: .data(Data([1, 2, 3]))) == "left out: binary data")
    }

    /// The battery's alert state goes in as its flags and date.
    @Test func theAlertStateIsDecoded() throws {
        var state = AlertState()
        state.lowBatteryArmed = false
        state.lastHighTemperatureAlert = Date(timeIntervalSince1970: 1_800_000_000)
        let text = ProblemReport.settingText(key: "alertState", value: .data(try JSONEncoder().encode(state)))
        #expect(
            text
                == "chargeLimitArmed true, lowBatteryArmed false, serviceAnnounced false, highTemperatureArmed true, "
                + "lastHighTemperatureAlert 2027-01-15T08:00:00Z")
        #expect(ProblemReport.settingText(key: "alertState", value: .data(Data("{".utf8))) == "left out: not readable")
    }

    /// The accessories' alert state goes in as a count: its keys are the accessories' ids.
    @Test func theAccessoryAlertStateIsOnlyCounted() throws {
        var state = AccessoryAlertState()
        state.firedAt = ["acc-0123456789abcdef": .now, "acc-fedcba9876543210": .now]
        let text = ProblemReport.settingText(
            key: "accessoryAlertState", value: .data(try JSONEncoder().encode(state)))
        #expect(text == "2 fired, the accessories left out")
        #expect(!text.contains("acc-"))
    }

    /// Each kind of stored value, as the report writes it (`SettingValue` has no `==`: nothing but
    /// this test would use it).
    @Test func settingValuesComeFromUserDefaultsObjects() {
        func text(_ value: Any?) -> String {
            ProblemReport.settingText(key: "glassCards", value: ProblemReport.SettingValue(any: value))
        }
        #expect(ProblemReport.SettingValue(any: nil) == nil)
        #expect(text(true) == "true")
        #expect(text(80) == "80")
        #expect(text(0.5) == "0.5")
        #expect(text("daily") == "daily")
        #expect(text(Data([1])) == "left out: binary data")
        #expect(text(Date(timeIntervalSince1970: 5)) == "1970-01-01T00:00:05Z")
        #expect(text(["a"]) == "left out: not a plain value")
        #expect(text(["a": 1]) == "left out: not a plain value")
    }

    // MARK: Crash reports

    /// A crash report as macOS 27 writes it: a header line and the report, with escaped slashes.
    static let ips = """
        {"app_name":"BatteryPulse","timestamp":"2026-10-30 10:11:12.00 +0300","app_version":"0.8.0",\
        "slice_uuid":"0a1b2c3d-4e5f-6071-8293-a4b5c6d7e8f9","build_version":"812","platform":1,\
        "bundleID":"io.github.nikitausov.BatteryPulse","bug_type":"309","os_version":"macOS 27.1 (27B48)",\
        "name":"BatteryPulse","incident_id":"5F3A0E9C-1B2D-4C6E-8A7F-0123456789AB"}
        {
          "uptime" : 1200,
          "procRole" : "Foreground",
          "userID" : 501,
          "incident" : "5F3A0E9C-1B2D-4C6E-8A7F-0123456789AB",
          "procPath" : "\\/Users\\/janedoe\\/Applications\\/BatteryPulse.app\\/Contents\\/MacOS\\/BatteryPulse",
          "modelCode" : "Mac17,3",
          "crashReporterKey" : "C0FFEE00-1111-2222-3333-444455556666",
          "exception" : {"codes" : "0x0000000000000001, 0x00000001a2b3c4d5", "type" : "EXC_BREAKPOINT", "signal" : "SIGTRAP"},
          "threads" : [{"triggered" : true, "threadState" : {"x" : [{"value" : 18446744073709551615}, {"value" : 0}]}}],
          "usedImages" : [{"path" : "/Users/janedoe/Applications/BatteryPulse.app/Contents/MacOS/BatteryPulse", "base" : 4295000064, "name" : "BatteryPulse"}],
          "note" : "a \\"quoted\\" {brace} [bracket], /Users/janedoe2/x"
        }

        """

    @Test func aCrashReportLosesItsIdentifiersAndTheHomeFolder() throws {
        let scrubbed = try #require(
            ProblemReport.scrubbedCrashReport(Data(Self.ips.utf8), homeDirectory: Self.home + "/"))
        for identifier in ["crashReporterKey", "incident", "C0FFEE00", "5F3A0E9C"] {
            #expect(!scrubbed.contains(identifier), "\(identifier)")
        }
        #expect(scrubbed.contains("\"bug_type\":\"309\""))
        #expect(scrubbed.contains("\"procPath\" : \"~\\/Applications\\/BatteryPulse.app"))
        #expect(scrubbed.contains("\"path\" : \"~/Applications/BatteryPulse.app"))
        // Another user's folder whose name starts the same stays.
        #expect(scrubbed.contains("/Users/janedoe2/x"))
        // Every other byte as written: a register's 64 bits, the quotes, the layout.
        #expect(scrubbed.contains("{\"value\" : 18446744073709551615}"))
        #expect(scrubbed.contains("\"note\" : \"a \\\"quoted\\\" {brace} [bracket]"))
        #expect(
            scrubbed.contains(
                "\"name\":\"BatteryPulse\"}\n{\n  \"uptime\" : 1200,\n  \"procRole\" : \"Foreground\",\n  \"userID\" : 501,\n  \"procPath\""
            ))
        // Both objects are still JSON.
        let lines = scrubbed.split(separator: "\n", maxSplits: 1)
        let header = try #require(try JSONSerialization.jsonObject(with: Data(lines[0].utf8)) as? [String: Any])
        #expect(header["bug_type"] as? String == "309")
        #expect(header["incident_id"] == nil)
        let body = try #require(try JSONSerialization.jsonObject(with: Data(lines[1].utf8)) as? [String: Any])
        #expect(body["crashReporterKey"] == nil && body["incident"] == nil)
        #expect(body["modelCode"] as? String == "Mac17,3")
    }

    @Test(arguments: [
        (#"{"a":1,"incident":"x","b":2}"#, #"{"a":1,"b":2}"#),
        (#"{"incident":"x","a":1}"#, #"{"a":1}"#),
        (#"{"a":1,"incident":"x"}"#, #"{"a":1}"#),
        (#"{"a":1, "incident" : "x" , "crashReporterKey":"y" }"#, #"{"a":1 }"#),
        (#"{"incident":"x","crashReporterKey":{"n":[1,2]}}"#, #"{}"#),
        (#"{"a":{"b":[{"incident":"x","c":true}]},"d":null}"#, #"{"a":{"b":[{"c":true}]},"d":null}"#),
        (#"{"incid\u0065nt":"x","a":-1.5e3}"#, #"{"a":-1.5e3}"#),
        (
            #"{"a":-0,"b":1E+10,"c":0.5e-3,"incident":7,"d":[0,-12.25,3e2]}"#,
            #"{"a":-0,"b":1E+10,"c":0.5e-3,"d":[0,-12.25,3e2]}"#
        ),
        (#"{"a":"incident","b":"\"incident\":1"}"#, #"{"a":"incident","b":"\"incident\":1"}"#),
        (#"[{"incident":"x"},{"a":[]}] {"b":{}}"#, #"[{},{"a":[]}] {"b":{}}"#),
        ("{\n  \"a\" : 1,\n  \"incident\" : \"x\",\n  \"b\" : 2\n}", "{\n  \"a\" : 1,\n  \"b\" : 2\n}"),
        ("{\n  \"a\" : 1,\n  \"incident\" : \"x\"\n}", "{\n  \"a\" : 1\n}"),
    ])
    func membersAreCutWithTheirCommas(json: String, expected: String) throws {
        let cut = try #require(JSONMemberCutter.removing(["incident", "crashReporterKey"], from: Data(json.utf8)))
        #expect(String(decoding: cut, as: UTF8.self) == expected)
    }

    @Test(arguments: [
        "", "   ", "Incident Identifier: 5F3A0E9C", #"{"a":1"#, #"{"a" 1}"#, #"{"a":1,}"#, #"[1,]"#, #"{"a":tru}"#,
        "{\"a\":\"line\nbreak\"}", #"{"a":"\"}"#, #"{a:1}"#, #"{"a":1}}"#,
        // Numbers are JSON's only.
        "e", "-", #"{"a":e}"#, #"{"a":01}"#, #"{"a":1.}"#, #"{"a":.5}"#, #"{"a":1e}"#, #"{"a":1e+}"#, #"{"a":+1}"#,
        #"{"a":-}"#, "[1-2]",
        String(repeating: "[", count: 300) + String(repeating: "]", count: 300),
    ])
    func notJSONIsLeftOut(text: String) {
        #expect(JSONMemberCutter.removing(["incident"], from: Data(text.utf8)) == nil, "\(text)")
        #expect(ProblemReport.scrubbedCrashReport(Data(text.utf8), homeDirectory: Self.home) == nil)
    }

    @Test(arguments: [
        ("/Users/janedoe", "~"), ("/Users/janedoe/Library", "~/Library"), ("x /Users/janedoe\"", "x ~\""),
        ("/Users/janedoe2/x", "/Users/janedoe2/x"), ("/Users/janedoe.old", "/Users/janedoe.old"),
        (#"\/Users\/janedoe\/Library"#, #"~\/Library"#), ("/Users/jane", "/Users/jane"),
    ])
    func theHomeFolderIsWrittenAsATilde(text: String, expected: String) {
        #expect(ProblemReport.replacingHomeFolder(Self.home, in: text) == expected)
        #expect(ProblemReport.replacingHomeFolder(Self.home + "/", in: text) == expected)
    }

    @Test func anEmptyOrRootHomeChangesNothing() {
        #expect(ProblemReport.replacingHomeFolder("", in: "/Users/janedoe") == "/Users/janedoe")
        #expect(ProblemReport.replacingHomeFolder("/", in: "/Users/janedoe") == "/Users/janedoe")
    }

    static let crashReports: ProblemReport.CrashReports = .found([
        .init(name: "BatteryPulse-2026-10-30-101112.ips", contents: Data(ips.utf8)),
        .init(name: "BatteryPulseWidget-2026-10-30-101113.ips", contents: Data("not json".utf8)),
        .init(name: "bpulse-2026-10-30-101114.ips"),
        .init(name: "Safari-2026-10-30-101115.ips", contents: Data(ips.utf8)),
    ])

    /// Without the second choice, only the names go in, even when the contents were read.
    @Test func withoutTheSecondChoiceOnlyTheNamesGoIn() {
        let text = Self.inputs(crashReports: Self.crashReports).text
        #expect(
            text.contains(
                "\n== Crash reports ==\nIn ~/Library/Logs/DiagnosticReports:\nBatteryPulse-2026-10-30-101112.ips\n"
                    + "BatteryPulseWidget-2026-10-30-101113.ips\nbpulse-2026-10-30-101114.ips\n"
                    + "Their contents are not included.\n"))
        #expect(!text.contains("Safari"))
        for content in ["EXC_BREAKPOINT", "bug_type", "not json", "CRASH REPORT", "Crash report contents"] {
            #expect(!text.contains(content), "\(content)")
        }
    }

    @Test func withTheSecondChoiceTheContentsFollowScrubbed() throws {
        let text = Self.inputs(crashReports: Self.crashReports, includesCrashContents: true).text
        #expect(text.contains("Their contents are at the end of this file.\n"))
        let scrubbed = try #require(ProblemReport.scrubbedCrashReport(Data(Self.ips.utf8), homeDirectory: Self.home))
        let name = "BatteryPulse-2026-10-30-101112.ips"
        #expect(
            text.contains(
                ProblemReport.beginLine("CRASH REPORT", name) + "\n" + scrubbed
                    + ProblemReport.endLine("CRASH REPORT", name) + "\n"))
        let widget = "BatteryPulseWidget-2026-10-30-101113.ips"
        #expect(
            text.contains(
                ProblemReport.beginLine("CRASH REPORT", widget) + "\nLeft out: not a JSON crash report.\n"
                    + ProblemReport.endLine("CRASH REPORT", widget)))
        let cli = "bpulse-2026-10-30-101114.ips"
        #expect(
            text.contains(
                ProblemReport.beginLine("CRASH REPORT", cli) + "\nNot readable.\n"
                    + ProblemReport.endLine("CRASH REPORT", cli)))
        #expect(!text.contains("Safari"))
        for identifier in ["C0FFEE00", "5F3A0E9C", "janedoe/", "crashReporterKey\""] {
            #expect(!text.contains(identifier), "\(identifier)")
        }
        #expect(text.contains("\"bug_type\":\"309\""))
        #expect(text.hasSuffix(ProblemReport.endLine("CRASH REPORT", cli) + "\n"))
    }

    @Test func anUnreadableOrEmptyFolderSaysSo() {
        let unreadable = Self.inputs(crashReports: .notReadable, includesCrashContents: true).text
        #expect(
            unreadable.contains(
                "\n== Crash reports ==\nNot readable: ~/Library/Logs/DiagnosticReports couldn't be listed.\n"))
        let none = Self.inputs(crashReports: .found([]), includesCrashContents: true).text
        #expect(none.contains("\n== Crash reports ==\nNone in ~/Library/Logs/DiagnosticReports.\n"))
        #expect(!unreadable.contains("Crash report contents") && !none.contains("Crash report contents"))
    }

    /// A name that would break a line, or a marker, is written on one line.
    @Test func aCrashReportNameStaysOnOneLine() {
        let name = "BatteryPulse-x\n-----END BATTERYPULSE CAPTURE battery-----\r\u{2028}.ips"
        let text = Self.inputs(
            crashReports: .found([.init(name: name, contents: Data("{}".utf8))]), includesCrashContents: true
        ).text
        #expect(!text.contains("x\n-----END"))
        #expect(text.contains("BatteryPulse-x -----END BATTERYPULSE CAPTURE battery----- " + " .ips\n"))
    }

    /// The contents stay small enough to attach: one report at most 2 MB, all of them 20 MB.
    @Test func largeContentsAreLeftOut() {
        #expect(ProblemReport.ContentLimits.standard.perReport == 2_000_000)
        #expect(ProblemReport.ContentLimits.standard.total == 20_000_000)
        let large = Data(("{\"a\":\"" + String(repeating: "x", count: 2_000_000) + "\"}").utf8)
        let text = Self.inputs(
            crashReports: .found([.init(name: "BatteryPulse-big.ips", contents: large)]), includesCrashContents: true
        ).text
        #expect(text.contains("\nLeft out: larger than 2000000 bytes.\n"))
        #expect(!text.contains("xxxxxxxx"))
        // With smaller limits: 30 bytes a report, 70 in all.
        let report = Data(#"{"a":"0123456789abcdefghij"}"#.utf8)
        #expect(report.count == 28)
        let reports = (0..<3).map { ProblemReport.CrashReport(name: "BatteryPulse-\($0).ips", contents: report) }
        let limited = Self.inputs(
            crashReports: .found(reports + [.init(name: "BatteryPulse-big.ips", contents: report + Data("   ".utf8))]),
            includesCrashContents: true
        ).text(limits: .init(perReport: 30, total: 70))
        #expect(limited.split(separator: "\n").filter { $0 == #"{"a":"0123456789abcdefghij"}"# }.count == 2)
        #expect(
            limited.contains(
                ProblemReport.beginLine("CRASH REPORT", "BatteryPulse-2.ips")
                    + "\nLeft out: the file would grow too large to attach.\n"))
        #expect(
            limited.contains(
                ProblemReport.beginLine("CRASH REPORT", "BatteryPulse-big.ips") + "\nLeft out: larger than 30 bytes.\n")
        )
    }

    @Test(arguments: [
        ("BatteryPulse-2026-10-30-101112.ips", true), ("BatteryPulseWidget-2026-10-30-101112.ips", true),
        ("bpulse-2026-10-30-101112.ips", true), ("BatteryPulse_2026-10-30-101112_Mac.cpu_resource.diag", true),
        ("Safari-2026-10-30-101112.ips", false), ("batterypulse.ips", false), (".BatteryPulse.ips", false),
        ("BatteryPulse/../x.ips", false),
    ])
    func crashReportNames(name: String, isOurs: Bool) {
        #expect(ProblemReport.isCrashReportName(name) == isOurs)
    }

    // MARK: Guards

    /// Nothing is sent: the report's own files use no network API (CL Network; plan §11).
    @Test func theReportsFilesUseNoNetwork() throws {
        let network = #/\bURLSession\b|\bURLRequest\b|\bimport\s+Network\b|\bNW[A-Z]\w*|\bCFNetwork\b|\bsocket\s*\(/#
            .wordBoundaryKind(.simple)
        let files = try SourceScanner.allFiles.get().filter {
            ["BatteryCore/ProblemReport.swift", "BatteryCore/PerfSummary.swift"].contains($0.path)
        }
        #expect(files.count == 2)
        for file in files {
            #expect(!file.code.contains(network), "\(file.path)")
        }
        #expect("let session = URLSession(configuration: .ephemeral)".contains(network))
        #expect("import Network".contains(network))
    }
}
