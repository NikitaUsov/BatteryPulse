import Foundation

/// The text file that Help → Report a Problem… previews and saves for a GitHub issue. Nothing in
/// it is sent.
public enum ProblemReport {}

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
