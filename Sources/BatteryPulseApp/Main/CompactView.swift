#if os(macOS)
import BatteryCore
import BatteryKit
import SwiftUI

/// A small, fixed-size window with the essentials.
struct CompactView: View {
    let monitor: BatteryMonitor
    @Environment(DemoController.self) private var demo
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.tones) private var tones
    @Environment(\.windowLook) private var look
    private let formatter = BatteryFormatter.app

    var body: some View {
        CardGroup {
            VStack(alignment: .leading, spacing: 14) {
                if let snapshot = monitor.snapshot {
                    content(snapshot)
                } else if monitor.hasBattery == false {
                    ContentUnavailableView(
                        "No Battery",
                        systemImage: "battery.0percent",
                        description: Text("This Mac has no internal battery.")
                    )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
        }
        .padding(18)
        .frame(width: 380)
        // The window sizes to its content, so Demo Mode's animated changes stop here: rows that
        // come and go, and with them the window's height, change at once. The percent and the
        // battery glyph still animate through their own animations, keyed on whole values.
        .transaction { $0.animation = nil }
        .toolbar {
            if demo.isActive {
                // A status readout, not a control, so it stays off the toolbar's glass.
                ToolbarItem(placement: .status) {
                    Text("Demo")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(tones.style(.warning))
                }
                .sharedBackgroundVisibility(.hidden)
            }
            ToolbarItem {
                Button("Full Window", systemImage: "arrow.up.left.and.arrow.down.right") {
                    WindowOpener.switchWindowStyle(compact: false)
                    dismissWindow(id: WindowID.compact)
                }
                .help("Show every detail in the full window")
            }
        }
    }

    @ViewBuilder
    private func content(_ s: BatterySnapshot) -> some View {
        HStack(spacing: 16) {
            BatteryGlyph(
                level: (s.chargePercent ?? 0) / 100,
                isCharging: s.chargeState == .charging,
                tint: tones.color(.level(BatteryPresentation.levelTier(for: s)))
            )
            .frame(width: 84)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.chargePercent.map { formatter.percent($0) } ?? "—")
                    .font(.system(size: 34, weight: look.boldNumerals ? .bold : .semibold, design: .rounded))
                    .monospacedDigit()
                    .numericValue(s.chargePercent)
                Text(Phrases.stateWithPower(s, formatter))
                    .font(look.boldNumerals ? .callout.weight(.medium) : .callout)
                if let time = Phrases.timeRemaining(s, formatter) {
                    Text(time)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                // Clear has no orange or red: a low level says so in its badge.
                if tones.badge(for: BatteryPresentation.levelTier(for: s)) == .inverted {
                    InvertedBadge(text: Text("Low battery"))
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        // Not in a card: the readout is a group of its own.
        .contentTreatment()
        .accessibilityElement(children: .combine)
        // The "Demo" badge sits in the toolbar, away from the numbers; VoiceOver still hears
        // with the readout that it is simulated. Two Text values, not a ternary of literals, so
        // the word is localized.
        .accessibilityValue(demo.isActive ? Text("Demo") : Text(verbatim: ""))

        if s.currentCapacityMAh != nil || s.designCapacityMAh != nil {
            Card {
                CapacityBars(snapshot: s, formatter: formatter)
            }
        }

        Card {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                if let health = s.healthPercent {
                    let condition = Phrases.condition(s.healthCondition).map { " · " + $0 } ?? ""
                    row("Maximum capacity", formatter.percent(health) + condition)
                }
                if let cycles = s.cycleCount {
                    row(
                        "Cycle count",
                        BatteryPresentation.ratedCycles(s.designCycleCount).map { Phrases.count(cycles, of: $0) }
                            ?? cycles.formatted())
                }
                if let watts = s.batteryPowerWatts {
                    row("Battery power", formatter.watts(watts, signed: true))
                }
                if let temperature = s.temperatureCelsius {
                    row("Temperature", formatter.celsius(temperature))
                }
                if s.isExternalPowerConnected == true, let adapter = s.adapter {
                    row(
                        "Power adapter",
                        [adapter.watts.map { formatter.watts(Double($0), fractionDigits: 0) }, adapter.name]
                            .compactMap { $0 }.joined(separator: " · "))
                }
            }
        }
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        GridRow {
            // The label keeps its full width and a long value is shortened instead: Grid
            // otherwise truncated the longer Russian labels.
            Text(label)
                .foregroundStyle(.secondary)
                .fixedSize()
            Text(value)
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}
#endif
