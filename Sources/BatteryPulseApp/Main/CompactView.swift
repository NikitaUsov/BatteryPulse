#if os(macOS)
import BatteryCore
import BatteryKit
import SwiftUI

/// A small, fixed-size window with the essentials, in the spirit of coconutBattery.
struct CompactView: View {
    let monitor: BatteryMonitor
    @Environment(DemoController.self) private var demo
    @Environment(\.dismissWindow) private var dismissWindow
    private let formatter = BatteryFormatter.app

    var body: some View {
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
        .padding(18)
        .frame(width: 380)
        .toolbar {
            ToolbarItem {
                Button("Full Window", systemImage: "arrow.up.left.and.arrow.down.right") {
                    WindowOpener.switchWindowStyle(compact: false)
                    dismissWindow(id: WindowID.compact)
                }
                .help("Show every detail in the full window")
            }
        }
        .onAppear { monitor.setLiveRefreshInterval(.seconds(2), for: "compact") }
        .onDisappear { monitor.setLiveRefreshInterval(nil, for: "compact") }
        .trackedWindow(WindowID.compact)
    }

    @ViewBuilder
    private func content(_ s: BatterySnapshot) -> some View {
        HStack(spacing: 16) {
            BatteryGlyph(
                level: (s.chargePercent ?? 0) / 100,
                isCharging: s.chargeState == .charging,
                tint: BatteryPresentation.levelTier(for: s).color
            )
            .frame(width: 84)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.chargePercent.map { formatter.percent($0) } ?? "—")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(Phrases.stateWithPower(s, formatter))
                    .font(.callout)
                if let time = Phrases.timeRemaining(s, formatter) {
                    Text(time)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if demo.isActive {
                Text("Demo")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .combine)

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
                    row("Cycle count", s.designCycleCount.map { Phrases.count(cycles, of: $0) } ?? cycles.formatted())
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
