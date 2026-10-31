#if os(macOS)
import BatteryCore
import SwiftUI

/// The at-a-glance page: charge, the three key gauges, capacity and where the power goes.
struct OverviewView: View {
    let snapshot: BatterySnapshot
    private let formatter = BatteryFormatter.app
    @Environment(\.motion) private var motion
    @Environment(\.tones) private var tones
    @Environment(\.windowLook) private var look

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
            // A new charge state brings or removes the hero's time line, and the Charge Limit's
            // hold its sentence, which changes the height of the cards above the rest: the whole
            // page moves as one, once per event. The hold can start with no new charge state, so
            // it is a key of its own. Under Reduce Motion the cards snap into place and only the
            // time line or the sentence fades.
            .animation(motion.change, value: BatteryMotionKey(snapshot).chargeState)
            .animation(motion.change, value: BatteryMotionKey(snapshot).isAtSystemChargeLimit)
            .padding(20)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
    }

    private var tint: Color {
        tones.color(.level(BatteryPresentation.levelTier(for: snapshot)))
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
                        .font(.system(size: 46, weight: look.boldNumerals ? .bold : .semibold, design: .rounded))
                        .monospacedDigit()
                        .numericValue(snapshot.chargePercent)
                    // No animation of its own: the watts in it change with every reading.
                    Text(Phrases.stateWithPower(snapshot, formatter))
                        .font(look.boldNumerals ? .title3.weight(.medium) : .title3)
                    // BatteryPulse only reads the limit; the user sets it in System Settings.
                    if snapshot.isAtSystemChargeLimit {
                        Text("Charging stopped at the Charge Limit set in System Settings → Battery.")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(motion.fadeTransition)
                    }
                    if let time = Phrases.timeRemaining(snapshot, formatter) {
                        Text(time)
                            .foregroundStyle(.secondary)
                            .transition(motion.fadeTransition)
                    }
                    // Clear has no orange or red: a low level says so in its badge.
                    if tones.badge(for: BatteryPresentation.levelTier(for: snapshot)) == .inverted {
                        InvertedBadge(text: Text("Low battery"))
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
                let tier = BatteryPresentation.healthTier(for: snapshot)
                GaugeTile(
                    title: "Maximum capacity",
                    fraction: health / 100,
                    value: formatter.percent(health),
                    number: health,
                    caption: Phrases.condition(snapshot.healthCondition),
                    tint: tones.color(.level(tier)),
                    badge: tones.badge(for: tier) == .inverted
                        ? Phrases.healthWarning(tier, condition: snapshot.healthCondition) : nil
                )
            }
            if let cycles = snapshot.cycleCount {
                let rated =
                    BatteryPresentation.ratedCycles(snapshot.designCycleCount)
                    ?? BatteryPresentation.fallbackRatedCycles
                GaugeTile(
                    title: "Cycle count",
                    fraction: Double(cycles) / Double(rated),
                    value: cycles.formatted(),
                    number: Double(cycles),
                    caption: String(localized: "of \(rated.formatted()) rated"),
                    tint: tones.color(.cycles)
                )
            }
        }
        // Tiles share the tallest tile's height.
        .fixedSize(horizontal: false, vertical: true)
    }
}
#endif
