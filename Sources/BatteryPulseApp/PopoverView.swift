#if os(macOS)
import AppKit
import BatteryCore
import BatteryKit
import SwiftUI

/// The window that opens from the menu bar icon.
struct PopoverView: View {
    let monitor: BatteryMonitor
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let snapshot = monitor.snapshot {
                SummaryView(snapshot: snapshot)
            } else if monitor.hasBattery == false {
                ContentUnavailableView(
                    "No Battery",
                    systemImage: "battery.0percent",
                    description: Text("This Mac has no internal battery.")
                )
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }

            Divider()

            HStack {
                Button("Details…") {
                    openWindow(id: WindowID.details)
                    NSApp.activate()
                }
                Spacer()
                Button {
                    openSettings()
                    NSApp.activate()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .help("Quit BatteryPulse")
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 300)
        .onAppear { monitor.setLiveRefreshInterval(.seconds(2), for: "popover") }
        .onDisappear { monitor.setLiveRefreshInterval(nil, for: "popover") }
    }
}

private struct SummaryView: View {
    let snapshot: BatterySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(snapshot.chargePercent.map(BatteryPresentation.percentText) ?? "—")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 2) {
                    Text(BatteryPresentation.stateTitle(for: snapshot))
                        .font(.headline)
                    if let time = BatteryPresentation.timeText(for: snapshot) {
                        Text(time)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let percent = snapshot.chargePercent {
                ProgressView(value: percent, total: 100)
                    .tint(levelColor(percent))
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                ForEach(BatteryPresentation.summaryLines(for: snapshot), id: \.label) { line in
                    GridRow {
                        Text(line.label)
                            .foregroundStyle(.secondary)
                        Text(line.value)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private func levelColor(_ percent: Double) -> Color {
        if snapshot.chargeState == .charging || percent > 20 { return .green }
        return percent > 10 ? .orange : .red
    }
}
#endif
