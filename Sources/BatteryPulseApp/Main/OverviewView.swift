#if os(macOS)
import BatteryCore
import SwiftUI

/// The at-a-glance page: charge, the three key gauges, capacity and where the power goes.
struct OverviewView: View {
    let snapshot: BatterySnapshot
    private let formatter = BatteryFormatter.app
    @Environment(\.motion) private var motion

    var body: some View {
        ScrollView {
            CardGroup {
                VStack(spacing: 16) {
                    hero
                    gauges
                    if snapshot.currentCapacityMAh != nil || snapshot.designCapacityMAh != nil {
                        Card("Capacity") {
                            CapacityBars(snapshot: snapshot, formatter: formatter)
                        }
                    }
                    Card("Power Flow") {
                        PowerFlowView(snapshot: snapshot, formatter: formatter)
                    }
                }
            }
            // A new charge state brings or removes the hero's time line, which changes the height
            // of the cards above the rest: the whole page moves as one, once per event.
            .animation(motion.change, value: BatteryMotionKey(snapshot).chargeState)
            .padding(20)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
    }

    private var tint: Color {
        BatteryPresentation.levelTier(for: snapshot).color
    }

    private var hero: some View {
        Card {
            HStack(spacing: 24) {
                BatteryGlyph(
                    level: (snapshot.chargePercent ?? 0) / 100,
                    isCharging: snapshot.chargeState == .charging,
                    tint: tint
                )
                .frame(width: 132)
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.chargePercent.map { formatter.percent($0) } ?? "—")
                        .font(.system(size: 46, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .numericValue(snapshot.chargePercent)
                    // No animation of its own: the watts in it change with every reading.
                    Text(Phrases.stateWithPower(snapshot, formatter))
                        .font(.title3)
                    if let time = Phrases.timeRemaining(snapshot, formatter) {
                        Text(time)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var gauges: some View {
        HStack(alignment: .top, spacing: 16) {
            if let percent = snapshot.chargePercent {
                GaugeTile(
                    title: "Charge",
                    fraction: percent / 100,
                    value: formatter.percent(percent),
                    number: percent,
                    caption: snapshot.hardwareChargePercent.map {
                        String(localized: "Gauge: \(formatter.percent($0, fractionDigits: 1))")
                    },
                    captionHelp: String(
                        localized:
                            "The battery controller's own reading: remaining ÷ full-charge capacity. macOS keeps a small reserve, so the two differ slightly."
                    ),
                    tint: tint
                )
            }
            if let health = snapshot.healthPercent {
                GaugeTile(
                    title: "Maximum capacity",
                    fraction: health / 100,
                    value: formatter.percent(health),
                    number: health,
                    caption: Phrases.condition(snapshot.healthCondition),
                    tint: BatteryPresentation.healthTier(for: snapshot).color
                )
            }
            if let cycles = snapshot.cycleCount {
                let rated = snapshot.designCycleCount ?? 1000
                GaugeTile(
                    title: "Cycle count",
                    fraction: Double(cycles) / Double(rated),
                    value: cycles.formatted(),
                    number: Double(cycles),
                    caption: String(localized: "of \(rated.formatted()) rated"),
                    tint: .blue
                )
            }
        }
        // Tiles share the tallest tile's height.
        .fixedSize(horizontal: false, vertical: true)
    }
}
#endif
