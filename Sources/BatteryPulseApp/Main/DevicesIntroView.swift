#if os(macOS)
import BatteryCore
import BatteryKit
import SwiftUI

/// The Devices section with no iPhone or iPad to show: what it does and how to turn it on, how
/// to connect a device, or why devices can't be read.
struct DevicesIntroView: View {
    @Environment(IDeviceMonitor.self) private var devices
    @Environment(\.motion) private var motion

    var body: some View {
        content
            // Listing is how a device on Wi-Fi shows up; only in a window that can be seen.
            .task(id: motion.isVisible) {
                if motion.isVisible { devices.listIfStale() }
            }
    }

    @ViewBuilder
    private var content: some View {
        if !devices.isEnabled {
            ContentUnavailableView {
                Label("iPhone and iPad", systemImage: "ipad.and.iphone")
            } description: {
                Text(
                    "See the battery of an iPhone or iPad connected to this Mac: maximum capacity, cycle count and charge, with their history."
                )
            } actions: {
                Button("Turn On") { AppDevices.setReading(true) }
                    .buttonStyle(.borderedProminent)
            }
        } else if let unavailable = devices.unavailable {
            ContentUnavailableView {
                Label("iPhone and iPad", systemImage: "ipad.and.iphone")
            } description: {
                Text(Phrases.deviceUnavailable(unavailable))
            } actions: {
                // The framework missing can't change while the app runs; listing can be retried.
                if case .subscriptionFailed = unavailable { checkAgain }
            }
        } else {
            ContentUnavailableView {
                Label("No Devices", systemImage: "ipad.and.iphone")
            } description: {
                Text(
                    "Connect an iPhone or iPad with a cable and unlock it. If it asks Trust This Computer?, tap Trust."
                )
            } actions: {
                checkAgain
            }
        }
    }

    @ViewBuilder
    private var checkAgain: some View {
        if devices.isListing {
            ProgressView {
                Text("Looking for devices…")
            }
            .controlSize(.small)
        } else {
            Button("Check Again") { devices.checkAgain() }
        }
    }
}
#endif
