/// The IORegistry entries below `AppleSmartBattery`, stored in its dictionary the way
/// `ioreg -a -l` prints them: each child is a dictionary with its class under `IOObjectClass` and
/// its own children under `IORegistryEntryChildren`.
///
/// macOS 27 moved readings that older releases kept on `AppleSmartBattery` itself onto these
/// children:
/// - `AppleSmartBatteryPack` → `BatteryData.Temperature`, in hundredths of a degree Celsius.
/// - One `AppleSmartBatteryBank` per series cell, under the pack → `BankID` and
///   `BatteryData.CellVoltage` in mV.
/// - `AppleChargerData` → `ChargerData.ChargingCurrent` and `ChargingVoltage`.
///
/// `IORegistryEntryCreateCFProperties` never includes children, so the provider walks them
/// separately and adds them under ``childrenKey``.
public enum RegistryChildren {
    public static let childrenKey = "IORegistryEntryChildren"
    public static let classKey = "IOObjectClass"

    /// How deep the provider walks below `AppleSmartBattery`; the banks sit two levels down.
    public static let maximumDepth = 3

    public static let packClass = "AppleSmartBatteryPack"
    public static let bankClass = "AppleSmartBatteryBank"
    public static let chargerClass = "AppleChargerData"

    /// One child entry, without its own children.
    public struct Entry: Sendable, Equatable {
        public var className: String
        /// Class names from `AppleSmartBattery` down to this entry, this one last.
        public var path: [String]
        public var properties: PropertyDictionary
    }

    /// Every descendant of `dictionary`, depth first, in registry order.
    public static func entries(in dictionary: PropertyDictionary) -> [Entry] {
        var result: [Entry] = []
        func visit(_ children: [PropertyValue], path: [String]) {
            for child in children.compactMap(\.dictionaryValue) {
                let className = child[classKey]?.stringValue ?? "IORegistryEntry"
                var properties = child
                properties[classKey] = nil
                properties[childrenKey] = nil
                result.append(Entry(className: className, path: path + [className], properties: properties))
                visit(child[childrenKey]?.arrayValue ?? [], path: path + [className])
            }
        }
        visit(dictionary[childrenKey]?.arrayValue ?? [], path: [])
        return result
    }

    /// The pack's temperature in °C, or `nil` when it is missing or implausible.
    public static func temperatureCelsius(in dictionary: PropertyDictionary) -> Double? {
        guard let pack = entries(in: dictionary).first(where: { $0.className == packClass })?.properties,
            let raw = (pack["BatteryData"]?.dictionaryValue?["Temperature"] ?? pack["Temperature"])?.intValue
        else { return nil }
        let celsius = Double(raw) / 100
        return (-20...85).contains(celsius) ? celsius : nil
    }

    /// Cell voltages in mV ordered by `BankID`; empty unless every bank reports one.
    public static func cellVoltagesMV(in dictionary: PropertyDictionary) -> [Int] {
        let banks = entries(in: dictionary).filter { $0.className == bankClass }.map(\.properties)
        let cells = banks.compactMap { bank -> (id: Int, millivolts: Int)? in
            let value = bank["BatteryData"]?.dictionaryValue?["CellVoltage"] ?? bank["CellVoltage"]
            // A bank holds one cell; take the first value if it comes as a one-element array.
            guard let millivolts = value?.intValue ?? value?.arrayValue?.first?.intValue,
                SMCBattery.plausibleCellVoltage.contains(millivolts)
            else { return nil }
            return (bank["BankID"]?.intValue ?? 0, millivolts)
        }
        guard !banks.isEmpty, cells.count == banks.count else { return [] }
        return cells.sorted { $0.id < $1.id }.map(\.millivolts)
    }

    /// `ChargerData` of the `AppleChargerData` child, or an empty dictionary.
    public static func chargerData(in dictionary: PropertyDictionary) -> PropertyDictionary {
        guard let charger = entries(in: dictionary).first(where: { $0.className == chargerClass })?.properties
        else { return [:] }
        return charger["ChargerData"]?.dictionaryValue ?? charger
    }
}
