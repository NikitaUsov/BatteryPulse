#if os(macOS)
import BatteryCore
import BatterySource
import Foundation
import WidgetKit

/// One entry of a History widget's timeline: the feed the read found, the moment of the timeline
/// it stands for (``WidgetTimelinePlan/history(writtenAt:at:)``), the widget's configuration, and
/// the language it draws in.
struct HistoryEntry: TimelineEntry {
    /// `nil` without one, or one the reader turned down.
    let feed: WidgetFeed?
    let moment: WidgetTimelinePlan.Entry
    let configuration: HistoryWidgetConfiguration
    /// BatteryPulse's own, from the feed; the extension's own without one.
    var language = WidgetLanguageTable.extensionOwn

    var date: Date {
        moment.date
    }
}

struct HistoryTimelineProvider: AppIntentTimelineProvider {
    /// A made-up history in the real layout, which WidgetKit draws redacted while the widget loads.
    func placeholder(in context: Context) -> HistoryEntry {
        HistoryEntry(
            feed: .sample(at: .now), moment: WidgetTimelinePlan.Entry(date: .now, showsEstimate: false),
            configuration: HistoryWidgetConfiguration())
    }

    func snapshot(for configuration: HistoryWidgetIntent, in context: Context) async -> HistoryEntry {
        let feed = await WidgetReads.feedContent(preview: context.isPreview)
        let language = await WidgetLanguageTable.current()
        return HistoryEntry(
            feed: feed, moment: WidgetTimelinePlan.Entry(date: .now, showsEstimate: false),
            configuration: HistoryWidgetConfiguration(configuration), language: language)
    }

    /// The app reloads the widget at a plug change while it runs, at most hourly; the timeline's
    /// own hourly reload reads the feed's new steps, and its last entry says when the feed has
    /// grown old (``WidgetTimelinePlan/history(writtenAt:at:)``).
    func timeline(for configuration: HistoryWidgetIntent, in context: Context) async -> Timeline<HistoryEntry> {
        let interval = Diagnostics.begin("widget.timeline", trigger: WidgetKindID.history.signpostName)
        defer { interval.end() }
        let feed = await WidgetReads.feedContent(preview: context.isPreview)
        let language = await WidgetLanguageTable.current()
        let plan = WidgetTimelinePlan.history(writtenAt: feed?.writtenAt, at: .now)
        let options = HistoryWidgetConfiguration(configuration)
        let entries = plan.entries.map {
            HistoryEntry(feed: feed, moment: $0, configuration: options, language: language)
        }
        return Timeline(entries: entries, policy: .after(plan.nextReload))
    }
}
#endif
