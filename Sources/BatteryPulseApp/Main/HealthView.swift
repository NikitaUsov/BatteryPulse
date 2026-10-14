#if os(macOS)
import BatteryCore
import SwiftUI

/// Battery health: maximum capacity, condition, cycles and the capacities behind them.
struct HealthView: View {
    let snapshot: BatterySnapshot
    private let formatter = BatteryFormatter.app

    var body: some View {
        Form {
            if snapshot.healthPercent != nil || snapshot.cycleCount != nil {
                Section {
                    gauges
                }
            }
            healthSection
            capacitySection
            if snapshot.deviceName != nil || snapshot.manufacturer != nil {
                Section("Battery") {
                    if let name = snapshot.deviceName {
                        ValueRow("Gauge chip", name)
                    }
                    if let manufacturer = snapshot.manufacturer {
                        ValueRow("Manufacturer", manufacturer)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var gauges: some View {
        HStack(spacing: 40) {
            if let health = snapshot.healthPercent {
                Gauge(value: health / 100) {
                    Text("Maximum Capacity")
                } currentValueLabel: {
                    Text(formatter.percent(health))
                }
                .gaugeStyle(RingGaugeStyle(tint: .green, diameter: 128))
            }
            if let cycles = snapshot.cycleCount {
                Gauge(value: Double(cycles) / Double(snapshot.designCycleCount ?? 1000)) {
                    Text("Cycle Count")
                } currentValueLabel: {
                    Text(cycles.formatted())
                }
                .gaugeStyle(RingGaugeStyle(tint: .blue, diameter: 128))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var healthSection: some View {
        Section {
            if let health = snapshot.healthPercent {
                ValueRow("Maximum capacity", formatter.percent(health))
            }
            if let condition = Phrases.condition(snapshot.healthCondition) {
                ValueRow("Condition", condition)
            }
            if let cycles = snapshot.cycleCount {
                ValueRow(
                    "Cycle count",
                    snapshot.designCycleCount.map { Phrases.count(cycles, of: $0) } ?? cycles.formatted())
            }
            if let used = snapshot.cycleLifeUsed {
                ValueRow("Rated cycle life used", formatter.percent(used * 100))
            }
        } header: {
            Text("Battery Health")
        } footer: {
            if let health = snapshot.healthPercent, let ratio = snapshot.capacityToDesignPercent, ratio > health {
                Text(
                    "macOS caps maximum capacity at \(formatter.percent(100)). The battery currently holds \(formatter.percent(ratio, fractionDigits: 1)) of its design capacity."
                )
            }
        }
    }

    private var capacitySection: some View {
        Section {
            if let design = snapshot.designCapacityMAh {
                ValueRow("Design capacity", formatter.milliampHours(design))
            }
            if let nominal = snapshot.nominalChargeCapacityMAh {
                ValueRow("Nominal full charge", formatter.milliampHours(nominal))
            }
            if let full = snapshot.fullChargeCapacityMAh {
                ValueRow("Full charge capacity", formatter.milliampHours(full))
            }
            if let remaining = snapshot.currentCapacityMAh {
                ValueRow("Remaining capacity", formatter.milliampHours(remaining))
            }
        } header: {
            Text("Capacity")
        } footer: {
            Text(
                "Nominal full charge is what macOS uses for maximum capacity; full charge capacity is the gauge's current measurement."
            )
        }
    }
}
#endif
