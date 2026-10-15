import Foundation

/// Plain-text list of accessory batteries (`bpulse --accessories`), one line per accessory.
///
/// Locale-independent like ``BatteryReport``:
///
///     Desk Keyboard (keyboard, Bluetooth): 76 %
///     Test Buds (headphones, Bluetooth): left 64 %, right 61 %, case 90 % charging
///     game controller (game controller, Bluetooth LE): 30 % (last known)
public enum AccessoryReport {
    public static let emptyText = "No accessory batteries reported."

    public static func text(for accessories: [AccessoryBattery]) -> String {
        accessories.isEmpty ? emptyText : accessories.map(line).joined(separator: "\n")
    }

    static func line(_ accessory: AccessoryBattery) -> String {
        let kind = words(accessory.kind)
        let details = [kind, accessory.transport.displayName].compactMap { $0 }.joined(separator: ", ")
        let parts = accessory.parts.map { part in
            var text = "\(part.percent) %"
            if accessory.hasParts { text = words(part.role) + " " + text }
            if part.isCharging {
                text += " charging"
            } else if part.isOnExternalPower {
                text += " on power"
            }
            if part.isOffline { text += " (last known)" }
            return text
        }
        let name = accessory.name.isEmpty ? kind : accessory.name
        return "\(name) (\(details)): " + parts.joined(separator: ", ")
    }

    static func words(_ kind: AccessoryKind) -> String {
        switch kind {
        case .keyboard: "keyboard"
        case .mouse: "mouse"
        case .trackpad: "trackpad"
        case .headphones: "headphones"
        case .speaker: "speaker"
        case .gameController: "game controller"
        case .hearingAid: "hearing aid"
        case .other: "accessory"
        }
    }

    static func words(_ role: AccessoryPartRole) -> String {
        switch role {
        case .single: "battery"
        case .left: "left"
        case .right: "right"
        case .combined: "earbuds"
        case .other: "other"
        case .case: "case"
        }
    }
}
