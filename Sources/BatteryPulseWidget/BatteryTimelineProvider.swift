#if os(macOS)
import BatteryCore
import BatterySource
import Foundation
import WidgetKit

/// One entry of a Battery widget's timeline: the reading, the moment of the timeline it stands
/// for (``WidgetTimelinePlan``), and the widget's configuration.
struct BatteryEntry: TimelineEntry {
    let snapshot: BatterySnapshot?
    let moment: WidgetTimelinePlan.Entry
    let configuration: BatteryWidgetConfiguration

    var date: Date {
        moment.date
    }
}

struct BatteryTimelineProvider: AppIntentTimelineProvider {
    /// A generic battery in the real layout, which WidgetKit draws redacted while the widget
    /// loads. A Mac without a battery still gets its message from `timeline(for:in:)`.
    func placeholder(in context: Context) -> BatteryEntry {
        BatteryEntry(
            snapshot: Self.sample, moment: WidgetTimelinePlan.Entry(date: .now, showsEstimate: true),
            configuration: BatteryWidgetConfiguration())
    }

    private static var sample: BatterySnapshot {
        BatterySnapshot(
            timestamp: .now, chargePercent: 80, chargeState: .discharging, timeToEmptyMinutes: 300,
            fullChargeCapacityMAh: 4_500, designCapacityMAh: 4_500, cycleCount: 100, temperatureCelsius: 30)
    }

    func snapshot(for configuration: BatteryWidgetIntent, in context: Context) async -> BatteryEntry {
        let snapshot = await Self.read(preview: context.isPreview)
        return BatteryEntry(
            snapshot: snapshot, moment: WidgetTimelinePlan.Entry(date: .now, showsEstimate: true),
            configuration: BatteryWidgetConfiguration(configuration))
    }

    /// The app reloads the widget when the battery changes while it runs; the timeline's own
    /// reload keeps it roughly current when it doesn't (``WidgetTimelinePlan``).
    func timeline(for configuration: BatteryWidgetIntent, in context: Context) async -> Timeline<BatteryEntry> {
        let interval = Diagnostics.begin("widget.timeline", trigger: WidgetKindID.battery.signpostName)
        defer { interval.end() }
        let snapshot = await Self.read(preview: context.isPreview)
        let plan = WidgetTimelinePlan(snapshot: snapshot, at: .now)
        let options = BatteryWidgetConfiguration(configuration)
        let entries = plan.entries.map { BatteryEntry(snapshot: snapshot, moment: $0, configuration: options) }
        return Timeline(entries: entries, policy: .after(plan.nextReload))
    }

    /// The battery through the extension's read cache. In the widget gallery, a Mac without a
    /// battery shows Demo Mode's battery instead of a message, so the gallery shows the widget.
    private static func read(preview: Bool) async -> BatterySnapshot? {
        let snapshot = await WidgetReads.battery.value()
        guard preview, snapshot == nil else { return snapshot }
        return DemoScenario.onBattery.battery?.reading(at: .now).snapshot
    }
}

extension BatteryWidgetConfiguration {
    /// The intent's choices as BatteryCore's model. Status lines that were never stored read as
    /// the parameter's default, both lines; no details is none.
    init(_ intent: BatteryWidgetIntent) {
        self.init(
            layout: intent.layout.mode, main: intent.mainValue.main, visual: intent.mainVisual.visual,
            details: (intent.details ?? []).map(\.field), time: intent.time.style, colors: intent.colors.style,
            updateTime: intent.updateTime.style)
        if let lines = intent.statusLines {
            statusLines = lines.map(\.line)
        }
    }
}
#endif
