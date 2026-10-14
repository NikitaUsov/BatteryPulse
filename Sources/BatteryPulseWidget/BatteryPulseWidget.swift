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
}

struct BatteryTimelineProvider: TimelineProvider {
    /// The app reloads the widget when the battery changes while it runs; this keeps it roughly
    /// current when it doesn't, within WidgetKit's budget of 40–70 reloads a day.
    static let refreshInterval: TimeInterval = 30 * 60

    func placeholder(in context: Context) -> BatteryEntry {
        BatteryEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (BatteryEntry) -> Void) {
        Task { @MainActor in completion(Self.read()) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<BatteryEntry>) -> Void) {
        Task { @MainActor in
            let entry = Self.read()
            completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(Self.refreshInterval))))
        }
    }

    /// Reads IOKit directly: the sandboxed extension has no shared container with the app
    /// under ad-hoc signing. The SMC can't be opened from the sandbox, so it is skipped.
    @MainActor static func read() -> BatteryEntry {
        BatteryEntry(date: .now, snapshot: MacBatteryProvider(readsSMC: false).read()?.snapshot)
    }
}

struct BatteryWidgetView: View {
    let entry: BatteryEntry
    @Environment(\.widgetFamily) private var family
    private let formatter = BatteryFormatter()

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
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: BatteryPresentation.symbolName(for: s))
                .font(.title2)
                .foregroundStyle(tint(s))
                .widgetAccentable()
            Spacer(minLength: 0)
            Text(verbatim: formatter.percent(percent))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
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
            Text(label)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(verbatim: value)
                .monospacedDigit()
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

    /// An absolute time, so the text stays right between reloads.
    private func time(_ s: BatterySnapshot) -> String? {
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
