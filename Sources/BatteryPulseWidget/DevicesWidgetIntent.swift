#if os(macOS)
import AppIntents
import BatteryCore
import Foundation
import WidgetKit

// The iPhone & iPad widget's configuration, under the Battery widget's rules
// (BatteryWidgetIntent.swift): its type name, parameter names and case raw values are frozen once a
// release ships them, each choice maps one to one to its BatteryCore mirror, and every string of
// its edit sheet is a String Catalog key with its Russian, but for the devices' names, which are
// shown as they are. The default needs no entity query: it shows the most recently read device of
// the feed. Only One device's chooser runs the query, in the extension, over the feed it reads.

/// The iPhone & iPad widget's configuration. The default shows the most recently read device.
struct DevicesWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose iPhone and iPad"
    static let description = IntentDescription("Choose which iPhones and iPads the widget shows.")

    /// One device, the most recently read, the lowest or a chosen one, or all of them.
    @Parameter(title: "Show", default: .mostRecent)
    var show: DevicesWidgetShowChoice

    /// One device's choice, offered only with One device; until one is chosen, the most recently
    /// read shows.
    @Parameter(title: "Device")
    var device: DevicesWidgetDevice?

    /// Device shows only with One device. macOS 27's edit sheet doesn't show the summary sentence,
    /// so each branch's is a plain catalog key, never a parameter placeholder.
    static var parameterSummary: some ParameterSummary {
        When(\.$show, .equalTo, .oneDevice) {
            Summary("iPhone and iPad") {
                \.$show
                \.$device
            }
        } otherwise: {
            Summary("iPhone and iPad") {
                \.$show
            }
        }
    }
}

/// ``DevicesWidgetShow``.
enum DevicesWidgetShowChoice: String, AppEnum {
    case mostRecent, lowest, all, oneDevice

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Show"
    static let caseDisplayRepresentations: [DevicesWidgetShowChoice: DisplayRepresentation] = [
        .mostRecent: "Most recently read",
        .lowest: "Lowest charge",
        .all: "All",
        .oneDevice: "One device",
    ]

    var show: DevicesWidgetShow {
        switch self {
        case .mostRecent: .mostRecent
        case .lowest: .lowest
        case .all: .all
        case .oneDevice: .oneDevice
        }
    }
}

/// A remembered iPhone or iPad One device can show: identified by its `DeviceKey` string, a keyed
/// hash only the app can make, never a hardware identifier, and titled with its name as the widget
/// shows it, verbatim, never looked up in a table.
struct DevicesWidgetDevice: AppEntity {
    let key: DeviceKey
    /// The name of the feed's device; `nil` for a key the feed doesn't hold, a device forgotten
    /// since it was chosen.
    let name: DeviceWidgetName?

    var id: String {
        key.rawValue
    }

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Device"

    static var defaultQuery: DevicesWidgetDeviceQuery {
        DevicesWidgetDeviceQuery()
    }

    var displayRepresentation: DisplayRepresentation {
        switch name {
        case .named(let name)?:
            // A placeholder alone, so a device named like a catalog key ("All") keeps its name in
            // every language.
            let title: String.LocalizationValue = "\(name)"
            return DisplayRepresentation(title: LocalizedStringResource(title))
        case .unknown?, nil:
            return DisplayRepresentation(title: "Unknown Device")
        }
    }
}

/// Lists the feed's devices for One device's chooser, in the widget extension, through the one
/// read of the feed every kind shares (`WidgetReads.feed`): no file of its own.
struct DevicesWidgetDeviceQuery: EntityQuery {
    static var allowedExecutionTargets: IntentExecutionTargets {
        .widgetKitExtension
    }

    /// Every stored id that is a device's key, whether or not the feed still holds it: a
    /// forgotten device stays chosen, so the widget can say it was forgotten.
    func entities(for identifiers: [String]) async throws -> [DevicesWidgetDevice] {
        let devices = await Self.devices()
        return identifiers.compactMap { id in
            guard let key = DeviceKey(rawValue: id), key != .demo else { return nil }
            return devices.first { $0.key == key } ?? DevicesWidgetDevice(key: key, name: nil)
        }
    }

    /// The feed's devices, in its order, the most recently read first; none without a feed or
    /// its devices.
    func suggestedEntities() async throws -> [DevicesWidgetDevice] {
        await Self.devices()
    }

    private static func devices() async -> [DevicesWidgetDevice] {
        let devices = await WidgetReads.feed.value()?.feed?.devices ?? []
        return devices.map { DevicesWidgetDevice(key: $0.key, name: DeviceWidgetName($0)) }
    }
}

extension DevicesWidgetConfiguration {
    /// The intent's choices as BatteryCore's model.
    init(_ intent: DevicesWidgetIntent) {
        self.init(show: intent.show.show, device: intent.device?.key)
    }
}
#endif
