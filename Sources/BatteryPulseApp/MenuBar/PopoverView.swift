#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import SwiftUI

/// The window that opens from the menu bar item: a compact summary and ways into the app.
struct PopoverView: View {
    let monitor: BatteryMonitor
    @Environment(DemoController.self) private var demo
    @Environment(UpdateChecker.self) private var updater
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let snapshot = monitor.snapshot {
                PopoverSummary(snapshot: snapshot)
            } else if monitor.hasBattery == false {
                ContentUnavailableView(
                    "No Battery",
                    systemImage: "battery.0percent",
                    description: Text("This Mac has no internal battery.")
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }

            if let release = updater.pendingRelease {
                Button {
                    WindowOpener.show(WindowID.update)
                } label: {
                    Label("Update available: \(release.version.description)", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderless)
            }

            if demo.isActive {
                // The numbers above are simulated; say so and offer the way out.
                HStack {
                    Label("Demo", systemImage: "play.rectangle.on.rectangle")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Stop Demo") { demo.stop() }
                        .controlSize(.small)
                }
            }

            Divider()

            HStack {
                Button("Open BatteryPulse") {
                    WindowOpener.openWindow = openWindow
                    WindowOpener.showMainWindow()
                }
                Spacer()
                Button {
                    DockIconPolicy.prepareToShowWindow()
                    openSettings()
                    NSApp.activate()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
                .accessibilityLabel("Settings")
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .help("Quit BatteryPulse")
                .accessibilityLabel("Quit BatteryPulse")
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 300)
        .onAppear { monitor.setLiveRefreshInterval(.seconds(2), for: "popover") }
        .onDisappear { monitor.setLiveRefreshInterval(nil, for: "popover") }
    }
}

private struct PopoverSummary: View {
    let snapshot: BatterySnapshot
    private let formatter = BatteryFormatter.app

    var body: some View {
        let tier = BatteryPresentation.levelTier(for: snapshot)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                BatteryGlyph(
                    level: (snapshot.chargePercent ?? 0) / 100,
                    isCharging: snapshot.chargeState == .charging,
                    tint: tier.color
                )
                .frame(width: 58)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.chargePercent.map { formatter.percent($0) } ?? "—")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(Phrases.stateWithPower(snapshot, formatter))
                        .font(.subheadline)
                    if let time = Phrases.timeRemaining(snapshot, formatter) {
                        Text(time)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(spacing: 6) {
                if let health = snapshot.healthPercent {
                    row("Maximum capacity", formatter.percent(health))
                }
                if let cycles = snapshot.cycleCount {
                    row("Cycle count", cycles.formatted())
                }
                if let adapter = snapshot.adapter, let watts = adapter.watts {
                    row("Power adapter", formatter.watts(Double(watts), fractionDigits: 0))
                }
                if let load = snapshot.systemLoadWatts {
                    row("System load", formatter.watts(load))
                }
            }
        }
    }

    /// Label on the leading edge, value on the trailing edge, so longer translations never crowd
    /// the numbers.
    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Text(value)
                .monospacedDigit()
                .fixedSize()
        }
    }
}
#endif
