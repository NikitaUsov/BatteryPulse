import Foundation

/// An accessory that fell to the user's threshold.
public struct AccessoryLowBattery: Sendable, Equatable {
    public let id: String
    public let name: String
    public let kind: AccessoryKind
    public let percent: Int

    public init(id: String, name: String, kind: AccessoryKind, percent: Int) {
        self.id = id
        self.name = name
        self.kind = kind
        self.percent = percent
    }
}

/// Which accessories have been announced, so each alerts once per discharge. Saved between
/// launches, and only while the alert is on.
public struct AccessoryAlertState: Sendable, Equatable, Codable {
    /// Accessories whose alert fired and hasn't re-armed: ``AccessoryBattery/id`` → when it
    /// fired.
    public var firedAt: [String: Date] = [:]

    public init() {}
}

/// What one evaluation changed.
public struct AccessoryAlertChanges: Sendable, Equatable {
    public var fired: [AccessoryLowBattery] = []
    /// Ids whose alert re-armed; their delivered notifications are withdrawn.
    public var rearmed: [String] = []

    public init(fired: [AccessoryLowBattery] = [], rearmed: [String] = []) {
        self.fired = fired
        self.rearmed = rearmed
    }
}

/// The low-battery alert for accessories: once per discharge per accessory, on the lowest part
/// that drains (``AccessoryBattery/level``), never on the case or a part that is out of reach.
public enum AccessoryAlerts {
    /// A fired entry is dropped once it is this old and its accessory is out of sight.
    public static let forgetAfter: TimeInterval = 7 * 24 * 60 * 60

    /// The notification's identifier, one per accessory, so a new alert replaces an old one and
    /// a re-armed one can be withdrawn.
    public static func notificationID(for accessoryID: String) -> String {
        "accessoryLowBattery." + accessoryID
    }

    /// The alerts `accessories` call for at `threshold` percent, updating `state`.
    ///
    /// An accessory alerts when its level falls to the threshold, including a first reading
    /// below it, and re-arms while it charges or once it is ``BatteryAlerts/rearmMargin`` above.
    /// An accessory out of sight keeps its entry, so one that reconnects at the same level
    /// doesn't alert again; the entry goes after ``forgetAfter``.
    public static func evaluate(
        _ accessories: [AccessoryBattery], threshold: Int, now: Date, state: inout AccessoryAlertState
    ) -> AccessoryAlertChanges {
        var changes = AccessoryAlertChanges()
        let rearmLevel = threshold + Int(BatteryAlerts.rearmMargin)
        for accessory in accessories {
            guard let level = accessory.level else { continue }
            if level.isCharging || level.percent >= rearmLevel {
                if state.firedAt.removeValue(forKey: accessory.id) != nil { changes.rearmed.append(accessory.id) }
            } else if level.percent <= threshold, state.firedAt[accessory.id] == nil {
                state.firedAt[accessory.id] = now
                changes.fired.append(
                    AccessoryLowBattery(
                        id: accessory.id, name: accessory.name, kind: accessory.kind, percent: level.percent))
            }
        }
        // A date in the future (the clock was set back) is kept.
        let present = Set(accessories.map(\.id))
        state.firedAt = state.firedAt.filter { id, firedAt in
            present.contains(id) || now.timeIntervalSince(firedAt) <= forgetAfter
        }
        return changes
    }
}
