#if os(macOS)
import BatteryCore
import SwiftUI

/// Battery electrical readings, the power adapter and system power.
struct PowerView: View {
    let snapshot: BatterySnapshot
    private let formatter = BatteryFormatter.app
    @Environment(\.motion) private var motion
    @Environment(\.tones) private var tones

    var body: some View {
        let key = BatteryMotionKey(snapshot)
        let hasAdapter = snapshot.adapter != nil
        LookForm {
            batterySection
            if let adapter = snapshot.adapter {
                adapterSection(adapter)
                if !adapter.profiles.isEmpty {
                    profilesSection(adapter)
                }
            }
            systemSection
        }
        // The rows and sections that come with plugging in, a new charge state or the Charge
        // Limit's hold (the adapter and USB PD sections, the requested charge, the Charge Limit,
        // power from the adapter, adapter loss) appear and go once per event; the rows below them
        // move, so under Reduce Motion it all changes at once. Battery power, voltage, current and
        // temperature change instantly.
        .animation(motion.change, value: key.isPluggedIn)
        .animation(motion.change, value: key.chargeState)
        .animation(motion.change, value: key.isAtSystemChargeLimit)
        .animation(motion.change, value: hasAdapter)
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
            // Reached, never a percentage: macOS holds the charge within a few points of the limit
            // and resumes only after a drop of more than 5 %, so the charge here would read as the
            // limit.
            if snapshot.isAtSystemChargeLimit {
                ValueRow("Charge limit", String(localized: "Reached"))
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
                        let isActive = profile.index == adapter.activeProfileIndex
                        Image(systemName: "checkmark")
                            .foregroundStyle(tones.style(.accent))
                            .opacity(isActive ? 1 : 0)
                            // Crossfades to the profile the adapter switched to.
                            .animation(motion.crossfade, value: isActive)
                            .accessibilityLabel("In use")
                            .accessibilityHidden(!isActive)
                    }
                } label: {
                    Text(formatter.volts(millivolts: profile.voltageMV, fractionDigits: 0))
                        .monospacedDigit()
                }
                .contentTreatment()
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
            // Both change rarely; the new value crossfades in.
            if let lowPower = snapshot.isLowPowerModeEnabled {
                ValueRow("Low Power Mode", Phrases.onOff(lowPower))
                    .contentTransition(.opacity)
                    .animation(motion.crossfade, value: lowPower)
            }
            if let thermal = snapshot.thermalState {
                ValueRow("Thermal state", Phrases.thermal(thermal))
                    .contentTransition(.opacity)
                    .animation(motion.crossfade, value: thermal)
            }
        }
    }
}
#endif
