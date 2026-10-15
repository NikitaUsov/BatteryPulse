#if os(macOS)
import BatteryCore
import SwiftUI

/// Battery electrical readings, the power adapter and system power.
struct PowerView: View {
    let snapshot: BatterySnapshot
    private let formatter = BatteryFormatter.app

    var body: some View {
        Form {
            batterySection
            if let adapter = snapshot.adapter {
                adapterSection(adapter)
                if !adapter.profiles.isEmpty {
                    profilesSection(adapter)
                }
            }
            systemSection
        }
        .formStyle(.grouped)
    }

    private var batterySection: some View {
        Section("Battery") {
            ValueRow("State", Phrases.state(snapshot))
            if let time = Phrases.timeRemaining(snapshot, formatter) {
                ValueRow("Time remaining", time)
            }
            if let watts = snapshot.batteryPowerWatts {
                ValueRow("Battery power", formatter.watts(watts, signed: true))
            }
            if let voltage = snapshot.voltageMV {
                ValueRow("Voltage", formatter.volts(millivolts: voltage))
            }
            if let current = snapshot.amperageMA {
                ValueRow("Current", formatter.milliamps(current, signed: true))
            }
            if let temperature = snapshot.temperatureCelsius {
                ValueRow("Temperature", formatter.celsius(temperature))
            }
            if snapshot.chargeState == .charging, let current = snapshot.chargingCurrentMA, current > 0 {
                ValueRow("Requested charge current", formatter.milliamps(current))
            }
            if snapshot.chargeState == .charging, let voltage = snapshot.chargingVoltageMV, voltage > 0 {
                if snapshot.isChargingVoltagePerCell {
                    ValueRow("Requested charge voltage per cell", formatter.volts(millivolts: voltage))
                } else {
                    ValueRow("Requested charge voltage", formatter.volts(millivolts: voltage))
                }
            }
            if let optimized = snapshot.isOptimizedChargingEngaged {
                // `false` means the feature isn't holding the charge right now, not that it's off.
                ValueRow(
                    "Optimized charging",
                    optimized ? String(localized: "Holding charge") : String(localized: "Not active"))
            }
        }
    }

    private func adapterSection(_ adapter: PowerAdapter) -> some View {
        Section("Power Adapter") {
            if let name = adapter.name {
                ValueRow("Name", name)
            }
            if let manufacturer = adapter.manufacturer {
                ValueRow("Manufacturer", manufacturer)
            }
            if let watts = adapter.watts {
                ValueRow("Rated power", formatter.watts(Double(watts), fractionDigits: 0))
            }
            if let voltage = adapter.voltageMV, let current = adapter.currentMA {
                ValueRow(
                    "Negotiated",
                    "\(formatter.volts(millivolts: voltage, fractionDigits: 0)) × \(formatter.amps(milliamps: current))"
                )
            }
            if adapter.isWireless == true {
                ValueRow("Type", String(localized: "Wireless"))
            }
        }
    }

    private func profilesSection(_ adapter: PowerAdapter) -> some View {
        Section {
            ForEach(adapter.profiles, id: \.index) { profile in
                LabeledContent {
                    HStack(spacing: 6) {
                        Text(formatter.amps(milliamps: profile.maxCurrentMA))
                            .monospacedDigit()
                        Text(verbatim: "·")
                            .foregroundStyle(.tertiary)
                        Text(formatter.watts(profile.maxWatts, fractionDigits: 0))
                            .monospacedDigit()
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                            .opacity(profile.index == adapter.activeProfileIndex ? 1 : 0)
                            .accessibilityLabel("In use")
                            .accessibilityHidden(profile.index != adapter.activeProfileIndex)
                    }
                } label: {
                    Text(formatter.volts(millivolts: profile.voltageMV, fractionDigits: 0))
                        .monospacedDigit()
                }
            }
        } header: {
            Text("USB Power Delivery")
        } footer: {
            Text("Voltages the adapter offers. The checkmark shows the one in use.")
        }
    }

    private var systemSection: some View {
        Section("System") {
            if snapshot.isExternalPowerConnected == true, let input = snapshot.systemPowerInWatts, input > 0 {
                ValueRow("Power from adapter", formatter.watts(input))
            }
            if let load = snapshot.systemLoadWatts {
                ValueRow("System load", formatter.watts(load))
            }
            if snapshot.isExternalPowerConnected == true, let loss = snapshot.adapterEfficiencyLossWatts, loss > 0 {
                ValueRow("Adapter loss", formatter.watts(loss))
            }
            if let lowPower = snapshot.isLowPowerModeEnabled {
                ValueRow("Low Power Mode", Phrases.onOff(lowPower))
            }
            if let thermal = snapshot.thermalState {
                ValueRow("Thermal state", Phrases.thermal(thermal))
            }
        }
    }
}
#endif
