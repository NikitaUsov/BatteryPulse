#if os(macOS)
import BatteryCore
import BatterySource
import SwiftUI
import WidgetKit

/// The widget extension. SwiftPM builds it as a plain executable that `scripts/build-app.sh`
/// wraps into `BatteryPulse.app/Contents/PlugIns/BatteryPulseWidget.appex`. It is linked with
/// `-e _NSExtensionMain` (see Package.swift); `@main` keeps the bundle in the binary.
@main
struct BatteryPulseWidgets: WidgetBundle {
    var body: some Widget {
        BatteryWidget()
    }
}

struct BatteryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: BatteryWidgetKind.battery, provider: BatteryTimelineProvider()) { entry in
            BatteryWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Battery")
        .description("Charge, time remaining and battery health.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct BatteryEntry: TimelineEntry {
    let date: Date
    let snapshot: BatterySnapshot?
    /// Off once the estimate's time has passed (``WidgetTimelinePlan``).
    var showsEstimate = true
}

struct BatteryTimelineProvider: TimelineProvider {
    /// A generic battery in the real layout, which WidgetKit draws redacted while the widget
    /// loads. A Mac without a battery still gets "No battery information" from `getTimeline`.
    func placeholder(in context: Context) -> BatteryEntry {
        BatteryEntry(date: .now, snapshot: Self.sample)
    }

    private static var sample: BatterySnapshot {
        BatterySnapshot(
            timestamp: .now, chargePercent: 80, chargeState: .discharging, timeToEmptyMinutes: 300,
            fullChargeCapacityMAh: 4_500, designCapacityMAh: 4_500, cycleCount: 100, temperatureCelsius: 30)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (BatteryEntry) -> Void) {
        Task(name: "BatteryTimelineProvider.snapshot") {
            completion(BatteryEntry(date: .now, snapshot: await WidgetReadCache.battery.snapshot()))
        }
    }

    /// The app reloads the widget when the battery changes while it runs; the timeline's own
    /// reload keeps it roughly current when it doesn't (``WidgetTimelinePlan``).
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<BatteryEntry>) -> Void) {
        Task(name: "BatteryTimelineProvider.timeline") {
            let interval = Diagnostics.begin("widget.timeline", trigger: WidgetKindID.battery.signpostName)
            defer { interval.end() }
            let snapshot = await WidgetReadCache.battery.snapshot()
            let date = Date.now
            let plan = WidgetTimelinePlan(snapshot: snapshot, at: date)
            let entries = plan.entries.map {
                BatteryEntry(date: $0.date, snapshot: snapshot, showsEstimate: $0.showsEstimate)
            }
            completion(Timeline(entries: entries, policy: .after(plan.nextReload)))
        }
    }
}

struct BatteryWidgetView: View {
    let entry: BatteryEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let formatter = BatteryFormatter.widget

    var body: some View {
        if let snapshot = entry.snapshot, let percent = snapshot.chargePercent {
            switch family {
            case .systemMedium:
                HStack(spacing: 16) {
                    charge(snapshot, percent)
                    Divider()
                    details(snapshot)
                }
            default:
                charge(snapshot, percent)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "battery.0percent")
                    .font(.title)
                Text("No battery information")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func charge(_ s: BatterySnapshot, _ percent: Double) -> some View {
        // WidgetKit animates from one timeline entry to the next by itself; these say how the
        // symbol and the number change. Nothing runs between entries.
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: BatteryPresentation.symbolName(for: s))
                .font(.title2)
                // The level's colour only in full colour; in the accented and vibrant modes the
                // system colours the symbol itself (it is in the accent group).
                .foregroundStyle(renderingMode == .fullColor ? tint(s) : .primary)
                .widgetAccentable()
                .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
            Spacer(minLength: 0)
            Text(verbatim: formatter.percent(percent))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .contentTransition(reduceMotion ? .opacity : .numericText(value: percent))
            Text(state(s))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let time = time(s) {
                Text(time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func details(_ s: BatterySnapshot) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
            if let health = s.healthPercent {
                row("Maximum capacity", formatter.percent(health))
            }
            if let cycles = s.cycleCount {
                row("Cycle count", cycles.formatted())
            }
            if let temperature = s.temperatureCelsius {
                row("Temperature", formatter.celsius(temperature))
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        GridRow {
            // Russian labels are longer: they shrink a little before they would be cut off.
            Text(label)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(verbatim: value)
                .monospacedDigit()
                .fixedSize()
                .gridColumnAlignment(.trailing)
        }
    }

    private func tint(_ s: BatterySnapshot) -> Color {
        switch BatteryPresentation.levelTier(for: s) {
        case .normal: .green
        case .low: .orange
        case .critical: .red
        }
    }

    private func state(_ s: BatterySnapshot) -> String {
        switch s.chargeState {
        case .charging: String(localized: "Charging")
        case .discharging: String(localized: "On battery")
        case .charged: String(localized: "Fully charged")
        case .notCharging:
            s.isOptimizedChargingEngaged == true
                ? String(localized: "Charging on hold") : String(localized: "Not charging")
        case .unknown: String(localized: "Unknown")
        }
    }

    /// An absolute time, so the text stays right between reloads; gone once it has passed.
    private func time(_ s: BatterySnapshot) -> String? {
        guard entry.showsEstimate else { return nil }
        switch s.chargeState {
        case .charging:
            guard let minutes = s.estimatedTimeToFullMinutes else { return nil }
            let time = clock(entry.date.addingTimeInterval(Double(minutes) * 60))
            return String(localized: "Full at \(time)")
        case .discharging:
            guard let minutes = s.estimatedTimeToEmptyMinutes else { return nil }
            let time = clock(entry.date.addingTimeInterval(Double(minutes) * 60))
            return String(localized: "Lasts until about \(time)")
        case .charged, .notCharging, .unknown:
            return nil
        }
    }

    private func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
#else
// Widgets exist on macOS only; this keeps `swift build` working on Linux.
@main
enum BatteryPulseWidgetStub {
    static func main() {
        print("BatteryPulseWidget is a macOS widget extension.")
    }
}
#endif
