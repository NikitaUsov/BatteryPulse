#if os(macOS)
import BatteryCore
import SwiftUI

/// Battery health: maximum capacity, condition, cycles and the capacities behind them.
struct HealthView: View {
    let snapshot: BatterySnapshot
    private let formatter = BatteryFormatter.app
    @Environment(\.motion) private var motion
    @Environment(\.tones) private var tones
    /// Set once this view has let its rings fill; see ``ringsHaveFilledThisLaunch``.
    @State private var ringsFilled = false
    /// The rings fill from zero once per launch, on the first visit to this page. Pages switch
    /// often, so not on every visit; and only where one-off extras are allowed.
    @MainActor private static var ringsHaveFilledThisLaunch = false

    var body: some View {
        LookForm {
            if snapshot.healthPercent != nil || snapshot.cycleCount != nil {
                Section {
                    gauges
                }
            }
            healthSection
            capacitySection
            if !snapshot.cellVoltagesMV.isEmpty {
                cellsSection
            }
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
    }

    /// The rings animate to a new value through `RingGaugeStyle` (rarely: maximum capacity and
    /// cycles change about once a day).
    @ViewBuilder
    private var gauges: some View {
        // Empty only on the first visit, until `onAppear` starts the fill.
        let filled: Double = ringsFilled || Self.ringsHaveFilledThisLaunch || !motion.allowsFlourish ? 1 : 0
        HStack(spacing: 40) {
            if let health = snapshot.healthPercent {
                Gauge(value: health / 100 * filled) {
                    Text("Maximum capacity")
                } currentValueLabel: {
                    Text(formatter.percent(health))
                        .numericValue(health)
                }
                .gaugeStyle(
                    RingGaugeStyle(
                        tint: tones.color(.level(BatteryPresentation.healthTier(for: snapshot))), diameter: 128))
            }
            if let cycles = snapshot.cycleCount {
                let rated =
                    BatteryPresentation.ratedCycles(snapshot.designCycleCount)
                    ?? BatteryPresentation.fallbackRatedCycles
                Gauge(value: Double(cycles) / Double(rated) * filled) {
                    Text("Cycle count")
                } currentValueLabel: {
                    Text(cycles.formatted())
                        .numericValue(Double(cycles))
                }
                .gaugeStyle(RingGaugeStyle(tint: tones.color(.cycles), diameter: 128))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .onAppear {
            guard !Self.ringsHaveFilledThisLaunch else { return }
            Self.ringsHaveFilledThisLaunch = true
            // The arcs animate from zero to their values (`RingGaugeStyle`); without one-off
            // extras they were full from the start and nothing changes.
            ringsFilled = true
        }
        .contentTreatment()
        // Clear has no orange or red: a worn battery says so in its badge, under the rings.
        let tier = BatteryPresentation.healthTier(for: snapshot)
        if tones.badge(for: tier) == .inverted {
            InvertedBadge(text: Text(Phrases.healthWarning(tier, condition: snapshot.healthCondition)))
                .frame(maxWidth: .infinity)
        }
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
                    BatteryPresentation.ratedCycles(snapshot.designCycleCount).map { Phrases.count(cycles, of: $0) }
                        ?? cycles.formatted())
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

    private var cellsSection: some View {
        Section {
            ForEach(Array(snapshot.cellVoltagesMV.enumerated()), id: \.offset) { index, millivolts in
                ValueRow("Cell \((index + 1).formatted())", formatter.volts(millivolts: millivolts, fractionDigits: 3))
            }
            if let spread = snapshot.cellVoltageSpreadMV {
                ValueRow("Spread", formatter.millivolts(spread))
            }
        } header: {
            Text("Cells")
        } footer: {
            Text(
                "The battery has cells in series. A spread that keeps growing hints at an ageing or unbalanced battery."
            )
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
