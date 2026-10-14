import Foundation

/// What the raw keys in the Developer section mean and how to show their values.
///
/// These keys are undocumented Apple internals. Entries are limited to meanings backed by Apple's
/// open-source headers, the USB Power Delivery specification, the gauge's technical reference, or
/// consistency checks against real captures; unknown keys get no explanation rather than a guess.
/// Summaries are English. The app localizes them through `Resources/Localizable.xcstrings`, which
/// `LocalizationCatalogTests` keeps in sync.
public enum RawKeyGlossary {
    public struct Info: Sendable, Equatable {
        public var summary: String?
        public var kind: RawValueKind
        public var sentinels: [Int64: RawSentinel]

        public init(_ kind: RawValueKind, _ summary: String?, sentinels: [Int64: RawSentinel] = [:]) {
            self.kind = kind
            self.summary = summary
            self.sentinels = sentinels
        }
    }

    /// The glossary key for a flattened path: array indices removed, `AppleRawAdapterDetails`
    /// folded into `AdapterDetails`, adapter details prefixed `AdapterDetails.` and IOPS keys
    /// prefixed `IOPS.`.
    public static func canonicalKey(captureKey: String, path: String) -> String {
        var key = path.replacing(#/\[\d+\]/#, with: "")
        switch captureKey {
        case BatteryReading.CaptureKey.adapterDetails:
            key = "AdapterDetails." + key
        case BatteryReading.CaptureKey.powerSource:
            key = "IOPS." + key
        default:
            if key.hasPrefix("AppleRawAdapterDetails") {
                key = "AdapterDetails" + key.dropFirst("AppleRawAdapterDetails".count)
            }
        }
        return key
    }

    public static func info(for key: String) -> Info? {
        if let info = entries[key] { return info }
        return families.first { key.hasPrefix($0.prefix) }?.info
    }

    /// Every English summary, for the localization catalog test.
    public static var summaries: Set<String> {
        Set((entries.values.map(\.summary) + families.map(\.info.summary)).compactMap { $0 })
    }

    /// All glossary keys, for coverage tests.
    public static var keys: Set<String> { Set(entries.keys) }

    static let entries: [String: Info] = Dictionary(uniqueKeysWithValues: table)

    /// Groups of similar keys explained together, matched by prefix (longest first).
    static let families: [(prefix: String, info: Info)] = familyTable.sorted { $0.prefix.count > $1.prefix.count }

    private static let table: [(String, Info)] = []

    private static let familyTable: [(prefix: String, info: Info)] = []
}

/// One raw value in the Developer table, with its meaning and decoded form.
public struct RawRow: Sendable, Identifiable, Equatable {
    public var id: String
    /// Path inside its dictionary, with array indices (`UsbHvcMenu[2].MaxVoltage`).
    public var path: String
    /// Glossary key (``RawKeyGlossary/canonicalKey(captureKey:path:)``).
    public var key: String
    public var property: PropertyValue
    public var info: RawKeyGlossary.Info?
    public var decoded: DecodedRawValue?

    public var value: String { property.description }
}

/// One raw dictionary of the Developer table.
public struct RawSection: Sendable, Identifiable, Equatable {
    /// The ``BatteryReading/CaptureKey`` of the dictionary.
    public var id: String
    /// The API the dictionary comes from, shown verbatim.
    public var title: String
    public var rows: [RawRow]

    /// Sections for a raw capture, in a fixed order, skipping empty dictionaries.
    public static func sections(for capture: PropertyDictionary) -> [RawSection] {
        let sources = [
            (BatteryReading.CaptureKey.smartBattery, "AppleSmartBattery"),
            (BatteryReading.CaptureKey.powerSource, "IOPowerSources"),
            (BatteryReading.CaptureKey.adapterDetails, "IOPSCopyExternalPowerAdapterDetails"),
        ]
        return sources.compactMap { captureKey, title in
            guard let dictionary = capture[captureKey]?.dictionaryValue, !dictionary.isEmpty else { return nil }
            let rows = RawEntry.flatten(dictionary).map { entry in
                let key = RawKeyGlossary.canonicalKey(captureKey: captureKey, path: entry.path)
                let info = RawKeyGlossary.info(for: key)
                return RawRow(
                    id: captureKey + ":" + entry.path,
                    path: entry.path,
                    key: key,
                    property: entry.property,
                    info: info,
                    decoded: info.flatMap {
                        RawValueDecoder.decode(entry.property, as: $0.kind, sentinels: $0.sentinels)
                    }
                )
            }
            return RawSection(id: captureKey, title: title, rows: rows)
        }
    }
}
