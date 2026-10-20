#if os(macOS)
import AppKit
import BatteryCore
import SwiftUI

/// Which battery notifications to post.
struct NotificationSettings: View {
    @AppStorage(AppSettings.alertChargeLimitKey) private var chargeLimit = 0
    @AppStorage(AppSettings.alertLowBatteryKey) private var lowBattery = 0
    @AppStorage(AppSettings.alertAccessoryLowKey) private var accessoryLow = 0
    @AppStorage(AppSettings.alertServiceKey) private var service = false
    @AppStorage(AppSettings.alertHeatKey) private var heat = false
    @State private var isDenied = false
    private let formatter = BatteryFormatter.app

    var body: some View {
        Section {
            Picker("When charged to", selection: $chargeLimit) {
                Text("Off").tag(0)
                ForEach([80, 85, 90, 95, 100], id: \.self) { Text(formatter.percent(Double($0))).tag($0) }
            }
            // On a row that is always there, not on a Section or the rows that come and go with
            // isDenied, so each runs once and the task doesn't restart.
            .task { isDenied = await BatteryNotifier.isDenied() }
            // Notifications may have been turned on or off in System Settings meanwhile.
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                Task { isDenied = await BatteryNotifier.isDenied() }
            }
            .onChange(of: [chargeLimit, lowBattery, accessoryLow, service ? 1 : 0, heat ? 1 : 0]) { _, _ in
                // Ask for permission the first time something is turned on.
                guard AppSettings.alerts.isAnyEnabled else { return }
                Task {
                    _ = await BatteryNotifier.requestAuthorization()
                    isDenied = await BatteryNotifier.isDenied()
                }
            }
            Picker("When the battery falls to", selection: $lowBattery) {
                Text("Off").tag(0)
                ForEach([10, 20, 30], id: \.self) { Text(formatter.percent(Double($0))).tag($0) }
            }
            // Bluetooth keyboards, mice, trackpads and headphones; once per discharge each.
            Picker("When an accessory falls to", selection: $accessoryLow) {
                Text("Off").tag(0)
                ForEach([10, 20, 30], id: \.self) { Text(formatter.percent(Double($0))).tag($0) }
            }
            Toggle("When battery service is recommended", isOn: $service)
            Toggle("When the Mac gets hot", isOn: $heat)
        } header: {
            Text("Notify Me")
        } footer: {
            Text(
                "Unplugging at around 80 percent most of the time slows battery aging. BatteryPulse must be running to notify you."
            )
        }

        Section {
            if !BatteryNotifier.isAvailable {
                Text("Notifications work in the packaged app, not under swift run.")
                    .foregroundStyle(.secondary)
            } else if isDenied {
                Text("Notifications are turned off for BatteryPulse in System Settings.")
                    .foregroundStyle(.secondary)
                Button("Open Notification Settings") { NSWorkspace.shared.open(AppLinks.notificationSettings) }
            } else {
                LabeledContent("Preview") {
                    Button("Send Test Notification") {
                        Task {
                            if await BatteryNotifier.requestAuthorization() { BatteryNotifier.sendTest() }
                            isDenied = await BatteryNotifier.isDenied()
                        }
                    }
                }
            }
        }
    }
}
#endif
