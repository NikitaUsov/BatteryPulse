#if os(macOS)
import BatteryCore
import SwiftUI

/// Battery health: first what macOS reports of it (condition, maximum capacity, cycles), then the
/// rings, the rated cycle life used, the capacities behind them and the cells.
struct HealthView: View {
    let snapshot: BatterySnapshot
    private let formatter = BatteryFormatter.app
    @Environment(\.motion) private var motion
    @Environment(\.tones) private var tones
    /// Set once this view has let its rings fill; see ``ringsHaveFilledThisLaunch``.
    @State private var ringsFilled = false
    /// The rings fill from zero once per launch, on the first visit to this page. Pages switch
    /// often, so not on every visit; and only where one-off extras are allowed.
    private static var ringsHaveFilledThisLaunch = false

    var body: some View {
        LookForm {
            summarySection
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
        // Clear has no orange or red: a worn battery says so in its badge, under the rings, in the
        // condition macOS reports or, when only the capacity warns, the capacity's own words.
        let tier = BatteryPresentation.healthTier(for: snapshot)
        if tones.badge(for: tier) == .inverted, let warning = Phrases.healthWarning(snapshot, formatter) {
            InvertedBadge(text: Text(warning))
                .frame(maxWidth: .infinity)
        }
    }

    /// Is the battery OK: the condition macOS reports, the maximum capacity and the cycles out of
    /// the rated count, label beside value, as BatteryCore's `HealthSummary` gives them, and where
    /// macOS shows them. No grade of BatteryPulse's own.
    private var summarySection: some View {
        Section {
            ForEach(HealthSummary.rows(for: snapshot, formatter: formatter), id: \.labelKey) { row in
                ValueRow(LocalizedStringKey(row.labelKey), row.valueText { Phrases.text(forKey: $0) })
            }
        } footer: {
            Text("As macOS reports it in System Settings → Battery.")
        }
    }

    /// The battery's capacity against its design capacity where the summary's maximum capacity
    /// stops at 100 %: a new battery often holds more than its design capacity.
    private var uncappedDesignPercent: Double? {
        guard let health = snapshot.healthPercent, let ratio = snapshot.capacityToDesignPercent, ratio > health
        else { return nil }
        return ratio
    }

    /// The rated cycle life used, and the cap behind the summary's maximum capacity; the summary
    /// holds the rest of the battery's health.
    @ViewBuilder
    private var healthSection: some View {
        let uncapped = uncappedDesignPercent
        if snapshot.cycleLifeUsed != nil || uncapped != nil {
            Section {
                if let used = snapshot.cycleLifeUsed {
                    ValueRow("Rated cycle life used", formatter.percent(used * 100))
                }
            } header: {
                Text("Battery Health")
            } footer: {
                if let uncapped {
                    Text(
                        "macOS caps maximum capacity at \(formatter.percent(100)). The battery currently holds \(formatter.percent(uncapped, fractionDigits: 1)) of its design capacity."
                    )
                }
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
