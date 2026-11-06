#if os(macOS)
import BatteryCore
import BatterySource
import Foundation
import WidgetKit

/// One entry of an iPhone & iPad widget's timeline: what the read of the feed found, the moment
/// of the timeline it stands for (``WidgetTimelinePlan/devices(writtenAt:at:timeZone:)``), the
/// widget's configuration, and the language it draws in.
struct DevicesEntry: TimelineEntry {
    /// What the read of the feed found; `nil` without a read. Boxed, as the read keeps it.
    let feed: WidgetFeedState?
    let moment: WidgetTimelinePlan.Entry
    let configuration: DevicesWidgetConfiguration
    /// BatteryPulse's own, from the feed; the extension's own without one.
    var language = WidgetLanguageTable.extensionOwn

    var date: Date {
        moment.date
    }
}

struct DevicesTimelineProvider: AppIntentTimelineProvider {
    /// Made-up devices in the real layout, which WidgetKit draws redacted while the widget loads.
    func placeholder(in context: Context) -> DevicesEntry {
        DevicesEntry(
            feed: .feed(.sample(at: .now)), moment: WidgetTimelinePlan.Entry(date: .now, showsEstimate: false),
            configuration: DevicesWidgetConfiguration())
    }

    func snapshot(for configuration: DevicesWidgetIntent, in context: Context) async -> DevicesEntry {
        let feed = await Self.read(preview: context.isPreview)
        let language = await WidgetLanguageTable.current()
        return DevicesEntry(
            feed: feed, moment: WidgetTimelinePlan.Entry(date: .now, showsEstimate: false),
            configuration: DevicesWidgetConfiguration(configuration), language: language)
    }

    /// The app reloads the widget for a new reading that moved 3 points or changed state, at most
    /// every 15 minutes while it runs; the timeline's own half-hourly reload reads the feed again,
    /// and its other entries turn today's read times into dates at midnight and say when the
    /// feed has grown old (``WidgetTimelinePlan/devices(writtenAt:at:timeZone:)``).
    func timeline(for configuration: DevicesWidgetIntent, in context: Context) async -> Timeline<DevicesEntry> {
        let interval = Diagnostics.begin("widget.timeline", trigger: WidgetKindID.devices.signpostName)
        defer { interval.end() }
        let feed = await Self.read(preview: context.isPreview)
        let language = await WidgetLanguageTable.current()
        let plan = WidgetTimelinePlan.devices(
            writtenAt: feed?.feed?.writtenAt, at: .now, timeZone: .autoupdatingCurrent)
        let options = DevicesWidgetConfiguration(configuration)
        let entries = plan.entries.map {
            DevicesEntry(feed: feed, moment: $0, configuration: options, language: language)
        }
        return Timeline(entries: entries, policy: .after(plan.nextReload))
    }

    /// The feed through the extension's read cache. In the widget gallery, a Mac whose feed holds
    /// no device shows BatteryCore's made-up ones instead of a message, so the gallery shows the
    /// widget.
    private static func read(preview: Bool) async -> WidgetFeedState? {
        let state = await WidgetReads.feed.value()
        guard preview, state?.feed?.devices?.isEmpty != false else { return state }
        return .feed(.sample(at: .now))
    }
}
#endif
