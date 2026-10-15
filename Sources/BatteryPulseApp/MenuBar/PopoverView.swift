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
    @Environment(\.motion) private var motion

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
                UpdateAvailableRow(release: release)
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
                // Fades in when Demo Mode starts while the panel is open, and goes at once when
                // it stops, so it never fades out over the buttons that move up into its place.
                .transition(
                    AnyTransition.asymmetric(
                        insertion: AnyTransition.opacity.animation(motion.quickFade), removal: .identity))
            }

            Divider()

            HStack {
                Button("Open BatteryPulse") {
                    WindowOpener.openWindow = openWindow
                    WindowOpener.showMainWindow()
                }
                Spacer()
                Button {
                    WindowOpener.openWindow = openWindow
                    WindowOpener.show(WindowID.about)
                } label: {
                    Image(systemName: "info.circle")
                }
                .help("About BatteryPulse")
                .accessibilityLabel("About BatteryPulse")
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
        // The panel sizes to its content, so Demo Mode's animated changes stop here: rows that
        // come and go, and with them the panel's height, change at once. The percent and the
        // battery glyph still animate through their own animations, keyed on whole values.
        .transaction { $0.animation = nil }
        // Polls while the panel is open and on screen.
        .liveRefresh(monitor, every: .seconds(2), client: "popover")
    }
}

/// Opens the Software Update window. Its symbol bounces once when a version first shows up here,
/// so a new update is noticed; reopening the panel doesn't repeat it.
private struct UpdateAvailableRow: View {
    let release: ReleaseInfo
    @Environment(\.motion) private var motion
    @State private var bounces = 0
    /// The version whose arrival has been marked, for the life of the app.
    @MainActor private static var markedVersion: AppVersion?

    var body: some View {
        Button {
            WindowOpener.show(WindowID.update)
        } label: {
            Label("Update available: \(release.version.description)", systemImage: "arrow.down.circle.fill")
                .symbolEffect(.bounce, options: .nonRepeating, value: bounces)
        }
        .buttonStyle(.borderless)
        .task(id: release.version) {
            // A one-off extra: none under Reduce Motion or Low Power Mode, or while hidden.
            guard Self.markedVersion != release.version, motion.allowsFlourish else { return }
            Self.markedVersion = release.version
            bounces += 1
        }
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
                        .numericValue(snapshot.chargePercent)
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
                if let temperature = snapshot.temperatureCelsius {
                    row("Temperature", formatter.celsius(temperature))
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
