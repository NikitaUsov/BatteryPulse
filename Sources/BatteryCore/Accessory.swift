import Foundation

/// What kind of accessory, from the power source's `Accessory Category`. Declaration order is
/// display order.
public enum AccessoryKind: String, Sendable, Codable, CaseIterable {
    case keyboard, mouse, trackpad, headphones, speaker, gameController, hearingAid, other

    /// `Headphone`, `Headset` and `Audio Battery Case` are headphones. `Watch`, `Pencil` and
    /// `Battery Case` pair with an iPhone or iPad rather than a Mac, so they fall to `other`
    /// together with `Unknown`, a missing category and categories macOS adds later.
    public init(category: String?) {
        switch category {
        case "Keyboard": self = .keyboard
        case "Mouse": self = .mouse
        case "Trackpad": self = .trackpad
        case "Headphone", "Headset", AccessoryParser.audioCaseCategory: self = .headphones
        case "Speaker": self = .speaker
        case "Game Controller": self = .gameController
        case "HearingAid": self = .hearingAid
        default: self = .other
        }
    }

    /// The SF Symbol; the app falls back to ``fallbackSymbolName`` when macOS lacks it.
    public var symbolName: String {
        switch self {
        case .keyboard: "keyboard"
        case .mouse: "magicmouse"
        case .trackpad: "trackpad"
        case .headphones: "headphones"
        case .speaker: "hifispeaker"
        case .gameController: "gamecontroller"
        case .hearingAid: "ear"
        case .other: Self.fallbackSymbolName
        }
    }

    public static let fallbackSymbolName = "dot.radiowaves.left.and.right"
}

/// A part of a multi-part accessory, from the power source's `Part Identifier`. Declaration
/// order is display order.
public enum AccessoryPartRole: String, Sendable, Codable, CaseIterable {
    case single, left, right, combined, other, `case`

    /// `Part Identifier` when present; without one, a source of category `Audio Battery Case` is
    /// the case and anything else is a single part.
    public init(partIdentifier: String?, category: String?) {
        switch partIdentifier {
        case "Left": self = .left
        case "Right": self = .right
        case "Case": self = .case
        case "Single": self = .single
        case "Combined": self = .combined
        case let identifier? where !identifier.isEmpty: self = .other
        default: self = category == AccessoryParser.audioCaseCategory ? .case : .single
        }
    }

    /// The symbol shown before a part's percentage when the accessory has parts; `nil` for a
    /// single part or one macOS doesn't name.
    public var symbolName: String? {
        switch self {
        case .left: "airpod.left"
        case .right: "airpod.right"
        case .combined: "airpods"
        case .case: "airpods.chargingcase"
        case .single, .other: nil
        }
    }
}

/// How the accessory is connected, from the power source's `Transport Type`.
public enum AccessoryTransport: String, Sendable, Codable {
    case bluetooth, bluetoothLE, usb, other

    public init(_ raw: String?) {
        switch raw {
        case "Bluetooth": self = .bluetooth
        case "Bluetooth LE": self = .bluetoothLE
        case "USB": self = .usb
        default: self = .other
        }
    }

    /// The same words in every language; `nil` for a transport the app doesn't name.
    public var displayName: String? {
        switch self {
        case .bluetooth: "Bluetooth"
        case .bluetoothLE: "Bluetooth LE"
        case .usb: "USB"
        case .other: nil
        }
    }
}

/// One battery of an accessory: the only one of a keyboard, or a bud or the case of earbuds.
public struct AccessoryPart: Sendable, Hashable, Encodable {
    public var role: AccessoryPartRole
    /// 0...100.
    public var percent: Int
    public var isCharging: Bool
    /// `Power Source State` is "AC Power": a keyboard on its cable, a bud in a charging case.
    public var isOnExternalPower: Bool
    /// `Power Source State` is "Off Line": ``percent`` is the last value reported.
    public var isOffline: Bool

    public init(
        role: AccessoryPartRole, percent: Int, isCharging: Bool = false, isOnExternalPower: Bool = false,
        isOffline: Bool = false
    ) {
        self.role = role
        self.percent = percent
        self.isCharging = isCharging
        self.isOnExternalPower = isOnExternalPower
        self.isOffline = isOffline
    }
}

/// One physical accessory with one or more parts (earbuds: left, right, case).
public struct AccessoryBattery: Sendable, Hashable, Identifiable, Encodable {
    /// "acc-" and 16 hex digits: FNV-1a 64 of the key that groups the accessory's power sources,
    /// stable across launches. A local key for view identity, alert state and notification
    /// identifiers only. It is not anonymous: a Bluetooth address behind it can be recovered by
    /// brute force, so it stays on this Mac: `Encodable` leaves it out, and it is never printed or
    /// put in a capture. Its only copies outside memory are the keys of the saved
    /// ``AccessoryAlertState`` (in the app's preferences, only while the low-battery alert is on)
    /// and the identifiers of the notifications that alert delivers.
    public var id: String
    /// As the accessory reports it; may be empty (the UI then shows the kind's name).
    public var name: String
    public var kind: AccessoryKind
    public var transport: AccessoryTransport
    /// Never empty, ordered by role.
    public var parts: [AccessoryPart]

    public init(
        id: String, name: String, kind: AccessoryKind, transport: AccessoryTransport, parts: [AccessoryPart]
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.transport = transport
        self.parts = parts
    }

    /// Without `id`: the JSON output carries no identifier.
    enum CodingKeys: String, CodingKey {
        case name, kind, transport, parts
    }

    /// More than one part, or a lone part that is the left, the right or the case. A lone
    /// combined part shows like a single one.
    public var hasParts: Bool {
        guard let only = parts.first, parts.count == 1 else { return parts.count > 1 }
        return [.left, .right, .case].contains(only.role)
    }

    /// The kind's symbol, or earbuds for headphones with parts.
    public var symbolName: String {
        kind == .headphones && hasParts ? "airpods" : kind.symbolName
    }

    /// The level alerts use, or `nil` when no part qualifies. The case never counts, nor does a
    /// part that is offline. The lowest part that drains decides, so a bud in use alerts while
    /// the other charges in the case; the level reads as charging only when no part drains.
    public var level: AccessoryLevel? {
        let candidates = parts.filter { !$0.isOffline && $0.role != .case }
        let draining = candidates.filter { !$0.isCharging && !$0.isOnExternalPower }
        if let lowest = draining.map(\.percent).min() { return AccessoryLevel(percent: lowest, isCharging: false) }
        return candidates.map(\.percent).min().map { AccessoryLevel(percent: $0, isCharging: true) }
    }
}

/// An accessory's charge as alerts see it.
public struct AccessoryLevel: Sendable, Equatable {
    public var percent: Int
    /// True only when every part that counts charges or is on external power.
    public var isCharging: Bool

    public init(percent: Int, isCharging: Bool) {
        self.percent = percent
        self.isCharging = isCharging
    }
}
