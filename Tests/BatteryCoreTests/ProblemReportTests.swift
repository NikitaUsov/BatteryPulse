import Foundation
import Testing

@testable import BatteryCore

@Suite struct ProblemReportTests {
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
        #expect(ProblemReport.settingText(key: "glassCards", value: .data(Data([1, 2, 3]))) == "left out: 3 bytes")
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

    @Test func settingValuesComeFromUserDefaultsObjects() {
        #expect(ProblemReport.SettingValue(any: nil) == nil)
        #expect(ProblemReport.SettingValue(any: true) == .bool(true))
        #expect(ProblemReport.SettingValue(any: 80) == .int(80))
        #expect(ProblemReport.SettingValue(any: 0.5) == .double(0.5))
        #expect(ProblemReport.SettingValue(any: "daily") == .string("daily"))
        #expect(ProblemReport.SettingValue(any: Data([1])) == .data(Data([1])))
        #expect(
            ProblemReport.SettingValue(any: Date(timeIntervalSince1970: 5)) == .date(Date(timeIntervalSince1970: 5)))
        #expect(ProblemReport.SettingValue(any: ["a"]) == .other)
        #expect(ProblemReport.SettingValue(any: ["a": 1]) == .other)
    }
}
