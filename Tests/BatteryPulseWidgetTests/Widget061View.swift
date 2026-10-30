#if os(macOS)
import BatteryCore
import Foundation
import SwiftUI
import WidgetKit

@testable import BatteryPulseWidget

/// 0.6.1's Battery widget, the one 0.6.2 still ships (its `BatteryWidgetView` at v0.6.2), copied
/// so the look check's first question can set small and medium Automatic beside it, drawn from the
/// same reading (plan-0.7.0 §6.1: "next to 0.6.1's widget"), and a pixel diff can show what
/// changed. Its layout, fonts and colours are kept as they were. Only what a picture needs differs:
/// the size, the words' table, the locale and the time zone are inputs rather than WidgetKit's,
/// the main bundle's and the Mac's, and nothing animates. Never change it to match 0.7.
struct Widget061View: View {
    let snapshot: BatterySnapshot?
    /// The timeline entry's date.
    let date: Date
    /// Off once the estimate's time has passed.
    let showsEstimate: Bool
    let size: WidgetSize
    let locale: Locale
    let timeZone: TimeZone
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.widgetStrings) private var strings

    /// 0.6.1's formatter: the locale's numbers, English unit symbols.
    private var formatter: BatteryFormatter { BatteryFormatter(locale: locale) }

    var body: some View {
        if let snapshot, let percent = snapshot.chargePercent {
            switch size {
            case .medium:
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
                word("No battery information")
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
                .foregroundStyle(renderingMode == .fullColor ? tint(s) : .primary)
                .widgetAccentable()
            Spacer(minLength: 0)
            Text(verbatim: formatter.percent(percent))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
            state(s)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let time = time(s) {
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
            if let health = s.healthPercent {
                row("Maximum capacity", formatter.percent(health))
            }
            if let cycles = s.cycleCount {
                row("Cycle count", cycles.formatted(.number.locale(locale)))
            }
            if let temperature = s.temperatureCelsius {
                row("Temperature", formatter.celsius(temperature))
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            word(label)
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

    private func state(_ s: BatterySnapshot) -> Text {
        switch s.chargeState {
        case .charging: word("Charging")
        case .discharging: word("On battery")
        case .charged: word("Fully charged")
        case .notCharging: s.isOptimizedChargingEngaged == true ? word("Charging on hold") : word("Not charging")
        case .unknown: word("Unknown")
        }
    }

    /// An absolute time; gone once it has passed.
    private func time(_ s: BatterySnapshot) -> Text? {
        guard showsEstimate else { return nil }
        switch s.chargeState {
        case .charging:
            guard let minutes = s.estimatedTimeToFullMinutes else { return nil }
            let time = clock(date.addingTimeInterval(Double(minutes) * 60))
            return Text("Full at \(time)", bundle: strings)
        case .discharging:
            guard let minutes = s.estimatedTimeToEmptyMinutes else { return nil }
            let time = clock(date.addingTimeInterval(Double(minutes) * 60))
            return Text("Lasts until about \(time)", bundle: strings)
        case .charged, .notCharging, .unknown:
            return nil
        }
    }

    private func clock(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone))
    }

    /// A catalog word in the picture's language.
    private func word(_ key: String) -> Text {
        Text(LocalizedStringKey(key), bundle: strings)
    }
}
#endif
