import Foundation

/// Maps the power sources macOS publishes for accessories onto ``AccessoryBattery`` values.
///
/// Each source describes one battery: a keyboard's, or one part of earbuds (the left, the right,
/// the case). Parts of one accessory share a `Group Identifier`; sources without one are tied
/// together by name, identifier or model (``groupingKey(_:)``).
public enum AccessoryParser {
    /// Power source keys (`IOPSKeys.h`, `IOPSKeysPrivate.h`).
    public enum Key {
        public static let type = "Type"
        public static let accessorySourceType = "Accessory Source"
        public static let name = "Name"
        public static let partIdentifier = "Part Identifier"
        public static let partName = "Part Name"
        public static let groupIdentifier = "Group Identifier"
        public static let accessoryIdentifier = "Accessory Identifier"
        public static let category = "Accessory Category"
        public static let transport = "Transport Type"
        public static let currentCapacity = "Current Capacity"
        public static let maxCapacity = "Max Capacity"
        public static let isCharging = "Is Charging"
        public static let state = "Power Source State"
        public static let isPresent = "Is Present"
        public static let vendorID = "Vendor ID"
        public static let productID = "Product ID"
        public static let powerSourceID = "Power Source ID"
        public static let combinedParts = "Combined Parts"
    }

    /// `Power Source State` values.
    static let externalPowerState = "AC Power"
    static let offlineState = "Off Line"
    /// The category of an earbuds' charging case.
    static let audioCaseCategory = "Audio Battery Case"
    /// Types that are never accessories (`kIOPSInternalBatteryType`, `kIOPSUPSType`).
    static let otherTypes: Set<String> = ["InternalBattery", "UPS"]
    /// `kIOPSInvalidVendorID`, `kIOPSInvalidProductID`.
    static let invalidID = 0xffff
    /// The largest `Current Capacity` or `Max Capacity` taken as a reading: accessories publish
    /// a percentage, or tenths with a maximum of 1000.
    static let plausibleCapacity = 100_000.0

    /// Every accessory in `sources` (power source descriptions), its parts grouped, sorted by
    /// kind, then name, so rows never jump between reads.
    public static func accessories(from sources: [PropertyDictionary]) -> [AccessoryBattery] {
        var keys: [String] = []
        var groups: [String: [(source: PropertyDictionary, part: AccessoryPart)]] = [:]
        for source in sources where isAccessory(source) {
            guard let part = part(from: source), let key = groupingKey(source) else { continue }
            if groups[key] == nil { keys.append(key) }
            groups[key, default: []].append((source, part))
        }
        let ids = identifiers(for: keys) { groups[$0]?.first?.source ?? [:] }
        let accessories = keys.compactMap { key -> AccessoryBattery? in
            guard let members = groups[key], let first = members.first, let id = ids[key] else { return nil }
            var parts: [AccessoryPart] = []
            for part in members.map(\.part) where !parts.contains(where: { $0.role == part.role }) {
                parts.append(part)
            }
            let categories = members.compactMap { string($0.source[Key.category]) }
            let kind =
                categories.first { $0 != audioCaseCategory }.map(AccessoryKind.init(category:))
                ?? (categories.isEmpty ? .other : .headphones)
            return AccessoryBattery(
                id: id,
                // The case's own name says "Case"; the accessory is named after its earbuds.
                name: (members.filter { $0.part.role != .case } + members.filter { $0.part.role == .case })
                    .lazy.compactMap { string($0.source[Key.name]) }.first ?? "",
                kind: kind,
                transport: AccessoryTransport(string(first.source[Key.transport])),
                parts: parts.sorted { order(of: $0.role) < order(of: $1.role) })
        }
        return accessories.sorted { a, b in
            if a.kind != b.kind { return order(of: a.kind) < order(of: b.kind) }
            switch a.name.compare(b.name, options: [.caseInsensitive, .numeric]) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: return a.id < b.id
            }
        }
    }

    /// Whether a source can be an accessory's. The call that returns them returns accessories
    /// only, so a source without a `Type` is kept rather than lost.
    static func isAccessory(_ source: PropertyDictionary) -> Bool {
        if let type = string(source[Key.type]), otherTypes.contains(type) { return false }
        return source[Key.isPresent]?.boolValue != false
    }

    /// The key that ties a source to its accessory, or `nil` when it can't be tied to one: the
    /// group identifier; for a left, right, combined part or a case, the name; the accessory
    /// identifier; the name and model; the power source's number.
    static func groupingKey(_ source: PropertyDictionary) -> String? {
        if let group = string(source[Key.groupIdentifier]) { return "g:" + group }
        let name = string(source[Key.name])
        let role = AccessoryPartRole(
            partIdentifier: string(source[Key.partIdentifier]), category: string(source[Key.category]))
        if let name, [.left, .right, .case, .combined].contains(role) { return "n:" + name }
        if let identifier = string(source[Key.accessoryIdentifier]) { return "a:" + identifier }
        if let vendor = source[Key.vendorID]?.intValue, let product = source[Key.productID]?.intValue,
            vendor != invalidID, product != invalidID
        {
            return "p:\(name ?? "")|\(vendor)|\(product)"
        }
        return source[Key.powerSourceID]?.intValue.map { "s:\($0)" }
    }

    /// The battery a source describes, or `nil` without a usable `Current Capacity`. Without
    /// `Max Capacity` the charge is a percentage, so one above 100 is no reading, never a full
    /// battery; a maximum that is there but unusable (0, negative, not a number) leaves the scale
    /// unknown, so the charge is no reading either.
    static func part(from source: PropertyDictionary) -> AccessoryPart? {
        var maximum: Double?
        if let value = source[Key.maxCapacity] {
            guard let max = value.doubleValue, (1...plausibleCapacity).contains(max) else { return nil }
            maximum = max
        }
        guard let current = source[Key.currentCapacity]?.doubleValue,
            (0...(maximum == nil ? 100 : plausibleCapacity)).contains(current)
        else { return nil }
        let percent = maximum.map { current * 100 / $0 } ?? current
        let state = string(source[Key.state])
        return AccessoryPart(
            role: AccessoryPartRole(
                partIdentifier: string(source[Key.partIdentifier]), category: string(source[Key.category])),
            percent: Int(min(percent.rounded(), 100)),
            isCharging: source[Key.isCharging]?.boolValue ?? false,
            isOnExternalPower: state == externalPowerState,
            isOffline: state == offlineState)
    }

    /// Each grouping key's ``AccessoryBattery/id``: the ``stableID(for:)`` of the key, except for
    /// a source tied only by its `Power Source ID`. That number is per boot, and powerd gives a
    /// source a new one when its publisher creates it again (a reconnect), so the id comes from
    /// what the source says about itself (name, category, part, transport) and its rank among
    /// such sources that say the same, in `Power Source ID` order. Alert state keyed on the id
    /// then survives a reboot or a reconnect.
    static func identifiers(for keys: [String], source: (String) -> PropertyDictionary) -> [String: String] {
        var ids: [String: String] = [:]
        var bySelf: [(key: String, number: Int, description: String)] = []
        for key in keys {
            let values = source(key)
            guard key.hasPrefix("s:"), let number = values[Key.powerSourceID]?.intValue else {
                ids[key] = stableID(for: key)
                continue
            }
            let description = [Key.name, Key.category, Key.partIdentifier, Key.transport]
                .map { string(values[$0]) ?? "" }.joined(separator: "|")
            bySelf.append((key, number, description))
        }
        var ranks: [String: Int] = [:]
        for entry in bySelf.sorted(by: { $0.number < $1.number }) {
            let rank = ranks[entry.description, default: 0]
            ranks[entry.description] = rank + 1
            ids[entry.key] = stableID(for: "d:\(entry.description)#\(rank)")
        }
        return ids
    }

    /// FNV-1a 64 over the key's UTF-8 bytes, as "acc-" and 16 hex digits. (`Hasher` is seeded
    /// per process, so it can't give a key that lasts across launches.)
    static func stableID(for groupingKey: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in groupingKey.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        let hex = String(hash, radix: 16)
        return "acc-" + String(repeating: "0", count: 16 - hex.count) + hex
    }

    /// A non-empty string; numbers count too, since a publisher may send an identifier as one.
    static func string(_ value: PropertyValue?) -> String? {
        switch value {
        case .string(let string)? where !string.isEmpty: string
        case .int(let number)?: String(number)
        default: nil
        }
    }

    private static func order(of role: AccessoryPartRole) -> Int {
        AccessoryPartRole.allCases.firstIndex(of: role) ?? 0
    }

    private static func order(of kind: AccessoryKind) -> Int {
        AccessoryKind.allCases.firstIndex(of: kind) ?? 0
    }
}
