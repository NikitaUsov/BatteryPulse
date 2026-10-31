#if os(macOS)
import BatteryCore
import BatterySource
import Foundation
import WidgetKit

/// One entry of an Accessories widget's timeline: what the read found, when, the moment of the
/// timeline it stands for (``WidgetTimelinePlan/accessories(at:)``), and the widget's
/// configuration.
struct AccessoriesEntry: TimelineEntry {
    /// `nil` when this macOS publishes no accessory batteries.
    let accessories: [AccessoryBattery]?
    let readAt: Date
    let moment: WidgetTimelinePlan.Entry
    let configuration: AccessoriesWidgetConfiguration

    var date: Date {
        moment.date
    }
}

struct AccessoriesTimelineProvider: AppIntentTimelineProvider {
    /// Demo Mode's accessories in the real layout, which WidgetKit draws redacted while the widget
    /// loads.
    func placeholder(in context: Context) -> AccessoriesEntry {
        AccessoriesEntry(
            accessories: Self.demo, readAt: .now, moment: WidgetTimelinePlan.Entry(date: .now, showsEstimate: false),
            configuration: AccessoriesWidgetConfiguration())
    }

    func snapshot(for configuration: AccessoriesWidgetIntent, in context: Context) async -> AccessoriesEntry {
        let accessories = await Self.read(preview: context.isPreview)
        return AccessoriesEntry(
            accessories: accessories, readAt: .now,
            moment: WidgetTimelinePlan.Entry(date: .now, showsEstimate: false),
            configuration: AccessoriesWidgetConfiguration(configuration))
    }

    /// The app reloads the widget at once when an accessory connects or disconnects while it runs,
    /// and after a 10-point step; the timeline's own reload keeps it roughly current when it
    /// doesn't (``WidgetTimelinePlan/accessories(at:)``).
    func timeline(for configuration: AccessoriesWidgetIntent, in context: Context) async -> Timeline<AccessoriesEntry> {
        let interval = Diagnostics.begin("widget.timeline", trigger: WidgetKindID.accessories.signpostName)
        defer { interval.end() }
        let accessories = await Self.read(preview: context.isPreview)
        let now = Date.now
        let plan = WidgetTimelinePlan.accessories(at: now)
        let options = AccessoriesWidgetConfiguration(configuration)
        let entries = plan.entries.map {
            AccessoriesEntry(accessories: accessories, readAt: now, moment: $0, configuration: options)
        }
        return Timeline(entries: entries, policy: .after(plan.nextReload))
    }

    /// Demo Mode's accessories, product names rather than anyone's own.
    private static var demo: [AccessoryBattery] {
        AccessoryReading(sources: DemoAccessories.sources).accessories
    }

    /// The accessories through the extension's read cache. In the widget gallery, a Mac with none
    /// connected shows Demo Mode's instead of a message, so the gallery shows the widget.
    private static func read(preview: Bool) async -> [AccessoryBattery]? {
        let accessories = await WidgetReads.accessories.value()
        guard preview, accessories?.isEmpty != false else { return accessories }
        return demo
    }
}
#endif
