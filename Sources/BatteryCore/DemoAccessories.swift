import Foundation

/// The accessories Demo Mode shows in place of real ones, so screenshots of the menu bar panel
/// never show a person's accessory names. Power source dictionaries like the ones macOS
/// publishes, parsed by the real parser; the names are product names, never a person's.
public enum DemoAccessories {
    private typealias Key = AccessoryParser.Key

    public static let sources: [PropertyDictionary] = [
        source(name: "Magic Keyboard", category: "Keyboard", identifier: "demo-keyboard", percent: 76),
        // Below 20 percent: the orange level.
        source(name: "Magic Mouse", category: "Mouse", identifier: "demo-mouse", percent: 18),
        source(name: "AirPods Pro", category: "Headphone", identifier: "demo-left", percent: 64, part: "Left"),
        source(name: "AirPods Pro", category: "Headphone", identifier: "demo-right", percent: 61, part: "Right"),
        source(
            name: "AirPods Pro", category: "Audio Battery Case", identifier: "demo-case", percent: 90, part: "Case",
            isCharging: true),
    ]

    private static func source(
        name: String, category: String, identifier: String, percent: Int64, part: String? = nil,
        isCharging: Bool = false
    ) -> PropertyDictionary {
        var source: PropertyDictionary = [
            Key.type: .string(Key.accessorySourceType),
            Key.name: .string(name),
            Key.category: .string(category),
            Key.transport: .string("Bluetooth"),
            Key.accessoryIdentifier: .string(identifier),
            Key.currentCapacity: .int(percent),
            Key.maxCapacity: .int(100),
            Key.isCharging: .bool(isCharging),
            Key.state: .string(isCharging ? AccessoryParser.externalPowerState : "Battery Power"),
            Key.isPresent: .bool(true),
        ]
        if let part {
            source[Key.partIdentifier] = .string(part)
            source[Key.groupIdentifier] = .string("demo-1")
        }
        return source
    }
}
