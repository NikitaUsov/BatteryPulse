#if os(macOS)
import BatteryCore
import BatteryKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// iPhones and iPads in the app: the store, the monitor and the setting that turns them on.
enum AppDevices {
    static let store = DeviceStore(
        directory: DeviceStore.defaultDirectory(bundleIdentifier: Bundle.main.bundleIdentifier))

    static let monitor = IDeviceMonitor(
        transport: SystemDevices.makeTransport(),
        store: store,
        makeKeys: { HMACDeviceKeyDeriver(secret: $0) },
        attachEvents: SystemDevices.makeAttachEvents(),
        recordsHistory: { AppSettings.recordsHistory })

    /// The only way to turn reading on or off: Settings and the Devices page's Turn On.
    static func setReading(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: AppSettings.readDevicesKey)
        monitor.setEnabled(on)
    }

    /// The iPhones and iPads the Devices section shows: in Demo Mode only the simulated one, so
    /// screenshots never show a real owner's device name. Real reads go on in the background.
    static func shownEntries(_ devices: IDeviceMonitor, demo: DemoController) -> [IDeviceEntry] {
        demo.isActive ? [DemoDevice.entry] : devices.entries
    }

    /// Loads the remembered devices and, with the setting on, starts watching USB. With the
    /// setting off nothing else runs: no USB watch, no framework, no file.
    static func start() {
        Task { await monitor.start(enabled: AppSettings.readsDevices) }
    }
}

/// The marketing name of a device model ("iPhone 17 Pro Max" for `iPhone18,2`), localized by the
/// system, from the type it declares for its device model codes. `nil` when the system doesn't
/// know the model; callers show the product type then.
enum IDeviceModelName {
    private static var cache: [String: String?] = [:]

    static func name(productType: String?) -> String? {
        guard let productType, !productType.isEmpty else { return nil }
        if let cached = cache[productType] { return cached }
        let usable = lookUp(productType)
        cache[productType] = usable
        return usable
    }

    /// A model the system doesn't declare gets a dynamic type, whose description says nothing.
    private static func lookUp(_ productType: String) -> String? {
        let tagClass = UTTagClass(rawValue: "com.apple.device-model-code")
        guard let type = UTType(tag: productType, tagClass: tagClass, conformingTo: nil),
            !type.isDynamic, let name = type.localizedDescription, !name.isEmpty, name != productType
        else { return nil }
        return name
    }
}

/// How a device is named on screen. Names and models are data, never catalog keys.
enum DeviceText {
    /// The owner's name, then the model's name, then "iPhone" or "iPad", then "Unknown Device".
    static func displayName(_ entry: IDeviceEntry) -> Text {
        if let name = plainName(entry) { return Text(verbatim: name) }
        return Text("Unknown Device")
    }

    /// The same, as a String for `%@` in a sentence.
    static func nameForSentence(_ entry: IDeviceEntry) -> String {
        plainName(entry) ?? String(localized: "Unknown Device")
    }

    private static func plainName(_ entry: IDeviceEntry) -> String? {
        if let name = entry.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        if let model = IDeviceModelName.name(productType: entry.productType) { return model }
        switch entry.deviceClass {
        case "iPhone"?, "iPad"?: return entry.deviceClass
        default: return nil
        }
    }

    /// The model's name, else its product type ("iPhone18,2").
    static func model(_ entry: IDeviceEntry) -> String? {
        IDeviceModelName.name(productType: entry.productType) ?? entry.productType
    }

    /// "14:32" today, "Oct 20, 2026 at 14:32" otherwise.
    static func date(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened) : date.formatted(date: .abbreviated, time: .shortened)
    }
}
#endif
