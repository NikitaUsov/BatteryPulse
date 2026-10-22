#if os(macOS)
import BatteryCore
import BatteryKit
import SwiftUI
import WidgetKit

/// The widget extension. SwiftPM builds it as a plain executable that `scripts/build-app.sh`
/// wraps into `BatteryPulse.app/Contents/PlugIns/BatteryPulseWidget.appex`. It is linked with
/// `-e _NSExtensionMain` (see Package.swift); `@main` keeps the bundle in the binary.
@main
struct BatteryPulseWidgets: WidgetBundle {
    var body: some Widget {
        BatteryWidget()
        // W0-1's test kind (spike branch only).
        SpikeWidget()
    }
}

/// SPIKE-W (W0-2): today's kind string with an App Intents configuration (`BatteryWidgetIntent`),
/// whose defaults draw 0.6.1's widget.
struct BatteryWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: BatteryWidgetKind.battery, intent: BatteryWidgetIntent.self, provider: BatteryTimelineProvider()
        ) { entry in
            BatteryWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                // SPIKE-W (W0-4): the rendering mode and redaction of each render.
                .modifier(SpikeRenderLog(kind: "battery"))
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
    /// The configuration; a placeholder gets the defaults.
    var options = BatteryWidgetOptions()
}

struct BatteryTimelineProvider: AppIntentTimelineProvider {
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

    func snapshot(for configuration: BatteryWidgetIntent, in context: Context) async -> BatteryEntry {
        await Self.read(BatteryWidgetOptions(configuration))
    }

    /// The app reloads the widget when the battery changes while it runs; the timeline's own
    /// reload keeps it roughly current when it doesn't (``WidgetTimelinePlan``).
    func timeline(for configuration: BatteryWidgetIntent, in context: Context) async -> Timeline<BatteryEntry> {
        let options = BatteryWidgetOptions(configuration)
        let reading = await Self.read(options)
        // SPIKE-W: what else the sandbox lets the widget read (W0-3, W0-4).
        await SpikeProbes.run()
        let plan = WidgetTimelinePlan(snapshot: reading.snapshot, at: reading.date)
        let entries = plan.entries.map {
            BatteryEntry(
                date: $0.date, snapshot: reading.snapshot, showsEstimate: $0.showsEstimate, options: options)
        }
        return Timeline(entries: entries, policy: .after(plan.nextReload))
    }

    /// Reads IOKit directly: the sandboxed extension has no shared container with the app
    /// under ad-hoc signing. The SMC can't be opened from the sandbox, so it is skipped.
    @MainActor static func read(_ options: BatteryWidgetOptions) -> BatteryEntry {
        BatteryEntry(date: .now, snapshot: MacBatteryProvider(readsSMC: false).read()?.snapshot, options: options)
    }
}

struct BatteryWidgetView: View {
    let entry: BatteryEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let formatter = BatteryFormatter()

    /// SPIKE-W (W0-4 (4) and (5)): the medium widget opens a URL of a scheme no app registers,
    /// the small one has no URL, so a click on each shows what reaches the app.
    var body: some View {
        content
            .widgetURL(family == .systemMedium ? SpikeRoute.url(for: entry.options) : nil)
    }

    @ViewBuilder private var content: some View {
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
            Text(verbatim: mainText(s, percent))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .contentTransition(reduceMotion ? .opacity : .numericText(value: percent))
            Text(state(s))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if entry.options.layout == .custom, family == .systemSmall {
                // Custom in small: the one chosen detail in place of the time line.
                if let field = entry.options.details.first {
                    HStack(spacing: 4) {
                        Text(field.title)
                        Text(verbatim: value(field, s) ?? "–")
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            } else if let time = timeText(s) {
                time
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func details(_ s: BatterySnapshot) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
            if entry.options.layout == .custom {
                // An empty Custom list shows no details, never the defaults.
                ForEach(entry.options.details.prefix(4), id: \.self) { field in
                    row(Text(field.title), value(field, s) ?? "–")
                }
            } else {
                // The Automatic layout: 0.6.1's three details.
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
        }
        .font(.caption)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        row(Text(label), value)
    }

    private func row(_ label: Text, _ value: String) -> some View {
        GridRow {
            // Russian labels are longer: they shrink a little before they would be cut off.
            label
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

    /// The main value's text: the charge, unless the configuration picks another (SPIKE-W).
    private func mainText(_ s: BatterySnapshot, _ percent: Double) -> String {
        switch entry.options.mainValue {
        case .charge: formatter.percent(percent)
        case .maximumCapacity: s.healthPercent.map { formatter.percent($0) } ?? "–"
        case .temperature: s.temperatureCelsius.map { formatter.celsius($0) } ?? "–"
        case .batteryPower: s.batteryPowerWatts.map { formatter.watts($0, signed: true) } ?? "–"
        }
    }

    /// A detail's value for the Custom layout; `nil` for the fields the spike doesn't show.
    private func value(_ field: SpikeField, _ s: BatterySnapshot) -> String? {
        switch field {
        case .charge: s.chargePercent.map { formatter.percent($0) }
        case .maximumCapacity: s.healthPercent.map { formatter.percent($0) }
        case .cycleCount: s.cycleCount.map { $0.formatted() }
        case .temperature: s.temperatureCelsius.map { formatter.celsius($0) }
        case .adapter: s.adapter.flatMap(\.watts).map { formatter.watts(Double($0), fractionDigits: 0) }
        case .macPowerUse: s.systemLoadWatts.map { formatter.watts($0) }
        case .batteryPower: s.batteryPowerWatts.map { formatter.watts($0, signed: true) }
        case .adapterInput: s.systemPowerInWatts.map { formatter.watts($0) }
        case .chargeMAh: s.currentCapacityMAh.map { formatter.milliampHours($0) }
        case .cycleLifeUsed: s.cycleLifeUsed.map { formatter.percent($0 * 100) }
        case .cellBalance: s.cellVoltageSpreadMV.map { formatter.millivolts($0) }
        case .voltage: s.voltageMV.map { formatter.volts(millivolts: $0) }
        case .state, .time, .lowPowerMode: nil
        }
    }

    /// The time line in the configured style: today's clock time, or a time left that the
    /// system counts down once a minute without a reload (W0-6). `sign: .never`, because the
    /// offset of a date before its anchor is negative.
    private func timeText(_ s: BatterySnapshot) -> Text? {
        switch entry.options.time {
        case .clockTime:
            return time(s).map { Text($0) }
        case .timeLeft:
            guard let end = estimateEnd(s) else { return nil }
            return Text(.currentDate, format: .offset(to: end, allowedFields: [.hour, .minute], sign: .never))
        }
    }

    /// When the estimate ends, while it is shown.
    private func estimateEnd(_ s: BatterySnapshot) -> Date? {
        guard entry.showsEstimate else { return nil }
        let minutes: Int?
        switch s.chargeState {
        case .charging: minutes = s.estimatedTimeToFullMinutes
        case .discharging: minutes = s.estimatedTimeToEmptyMinutes
        case .charged, .notCharging, .unknown: minutes = nil
        }
        return minutes.map { entry.date.addingTimeInterval(Double($0) * 60) }
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
