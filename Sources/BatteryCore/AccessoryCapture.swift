import Foundation

/// One read of the accessory power sources: the descriptions as macOS returned them and the
/// accessories parsed from them. `bpulse --accessories --raw` writes it, pseudonymized, in the
/// fixture format (``redactedRawCapture``).
public struct AccessoryReading: Sendable, Equatable {
    /// The power source descriptions, as read.
    public let sources: [PropertyDictionary]
    public let accessories: [AccessoryBattery]

    public init(sources: [PropertyDictionary]) {
        self.sources = sources
        accessories = AccessoryParser.accessories(from: sources)
    }

    public enum CaptureKey {
        public static let sources = "AccessorySources"
    }

    /// Keys that identify an accessory or its owner, replaced at any depth along with serial
    /// numbers.
    static let identifyingKeys: Set<String> = ["UUID", "Address", "Device Address", "BD_ADDR"]

    /// `{AccessorySources: [description, …]}`: the fixture format.
    public var rawCapture: PropertyDictionary {
        [CaptureKey.sources: .array(sources.map(PropertyValue.dictionary))]
    }

    /// ``rawCapture`` safe to attach to a public bug report or commit as a fixture. Identifiers
    /// and names become consistent pseudonyms (`group-1`, `accessory-1`, `Accessory 1`), so the
    /// capture groups into the same accessories as the original; serial numbers and addresses
    /// are replaced. Categories, part identifiers, capacities, states, model numbers and the
    /// per-boot power source numbers are kept.
    public var redactedRawCapture: PropertyDictionary {
        var pseudonyms = Pseudonyms()
        var groupNumbers: [String: Int] = [:]
        for key in sources.compactMap(AccessoryParser.groupingKey) where groupNumbers[key] == nil {
            groupNumbers[key] = groupNumbers.count + 1
        }
        let redacted = sources.map { source -> PropertyValue in
            let number = AccessoryParser.groupingKey(source).flatMap { groupNumbers[$0] }
            var entry = pseudonyms.replacing(in: source, accessoryNumber: number)
            if let parts = source[AccessoryParser.Key.combinedParts]?.arrayValue {
                entry[AccessoryParser.Key.combinedParts] = .array(
                    parts.map { part in
                        guard let part = part.dictionaryValue else { return part }
                        return .dictionary(pseudonyms.replacing(in: part, accessoryNumber: number))
                    })
            }
            return .dictionary(entry)
        }
        return BatteryReading.redactingSerialNumbers(
            in: [CaptureKey.sources: .array(redacted)], alsoRedacting: Self.identifyingKeys)
    }

    /// Re-reads a capture written from ``rawCapture``; `nil` unless `AccessorySources` is an
    /// array of dictionaries. An empty one is fine: "nothing connected" is evidence too.
    public init?(rawCapture raw: PropertyDictionary) {
        guard let items = raw[CaptureKey.sources]?.arrayValue else { return nil }
        let sources = items.compactMap(\.dictionaryValue)
        guard sources.count == items.count else { return nil }
        self.init(sources: sources)
    }
}

/// Numbers identifiers by first appearance and names accessories by their group.
private struct Pseudonyms {
    private typealias Key = AccessoryParser.Key
    private var groups: [PropertyValue: String] = [:]
    private var accessories: [PropertyValue: String] = [:]

    mutating func replacing(in source: PropertyDictionary, accessoryNumber: Int?) -> PropertyDictionary {
        var entry = source
        if let value = source[Key.groupIdentifier], value != .string("") {
            entry[Key.groupIdentifier] = .string(Self.pseudonym(for: value, in: &groups, prefix: "group"))
        }
        if let value = source[Key.accessoryIdentifier], value != .string("") {
            entry[Key.accessoryIdentifier] = .string(
                Self.pseudonym(for: value, in: &accessories, prefix: "accessory"))
        }
        let name = accessoryNumber.map { "Accessory \($0)" } ?? "Accessory"
        if let value = source[Key.name], value != .string("") {
            entry[Key.name] = .string(name)
        }
        if let value = source[Key.partName], value != .string("") {
            let part = AccessoryParser.string(source[Key.partIdentifier])
            entry[Key.partName] = .string(part.map { "\(name) \($0)" } ?? name)
        }
        return entry
    }

    private static func pseudonym(
        for value: PropertyValue, in map: inout [PropertyValue: String], prefix: String
    ) -> String {
        if let known = map[value] { return known }
        let pseudonym = "\(prefix)-\(map.count + 1)"
        map[value] = pseudonym
        return pseudonym
    }
}
