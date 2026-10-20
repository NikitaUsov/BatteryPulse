#if os(macOS)
import BatteryCore
import SwiftUI

/// Where the power goes: adapter → Mac → battery (or battery → Mac on battery power).
///
/// Events animate, the watts don't: the adapter slides in and out when plugging in or out, the
/// battery arrow turns when the power flow changes direction, the battery symbol swaps at a new
/// level or charge state and bounces once on reaching full. Under Reduce Motion the adapter
/// fades while the other nodes snap to their new places, and the symbols crossfade.
struct PowerFlowView: View {
    let snapshot: BatterySnapshot
    let formatter: BatteryFormatter
    @Environment(\.motion) private var motion
    /// Counts the times the battery reached full while this view was shown; each change plays one
    /// bounce of the battery symbol.
    @State private var fullCount = 0

    var body: some View {
        let key = BatteryMotionKey(snapshot)
        let showsAdapter = snapshot.isExternalPowerConnected == true && snapshot.adapter != nil
        HStack(alignment: .center, spacing: 0) {
            if showsAdapter, let adapter = snapshot.adapter {
                node(title: "Adapter", value: adapter.watts.map { formatter.watts(Double($0), fractionDigits: 0) }) {
                    Image(systemName: "powerplug.portrait.fill")
                }
                .transition(motion.insertion(edge: .leading))
                arrow(
                    value: snapshot.systemPowerInWatts.flatMap { $0 > 0 ? formatter.watts($0) : nil },
                    pointsRight: true
                )
                .transition(motion.insertion(edge: .leading))
            }
            node(title: "Mac", value: snapshot.systemLoadWatts.map { formatter.watts($0) }) {
                Image(systemName: "laptopcomputer")
            }
            // The direction and the hidden value share `BatteryMotionKey.flow` and its dead band,
            // so noise around 0 W neither turns the arrow nor shows a value.
            arrow(
                value: key.flow == .idle ? nil : snapshot.batteryPowerWatts.map { formatter.watts(abs($0)) },
                pointsRight: key.batteryArrowPointsIntoBattery)
            node(title: "Battery", value: snapshot.chargePercent.map { formatter.percent($0) }) {
                Image(systemName: key.symbolName)
                    .contentTransition(motion.symbolSwap)
                    .symbolEffect(.bounce, options: .nonRepeating, value: fullCount)
                    .animation(motion.crossfade, value: key.symbolName)
                    .geometryGroup()
            }
        }
        .frame(maxWidth: .infinity)
        // The adapter slides in from the card's edge, not from beyond it.
        .clipped()
        // The nodes move to make room for the adapter: no animation under Reduce Motion.
        .animation(motion.change, value: showsAdapter)
        .onChange(of: key.chargeState) { old, new in
            // A one-off extra: not under Reduce Motion or Low Power Mode, nor in a hidden window.
            if BatteryMotionKey.reachedFull(from: old, to: new), motion.allowsFlourish {
                fullCount += 1
            }
        }
    }

    private func node<Symbol: View>(
        title: LocalizedStringKey, value: String?, @ViewBuilder symbol: () -> Symbol
    ) -> some View {
        VStack(spacing: 6) {
            symbol()
                .font(.title2)
                .frame(width: 52, height: 52)
                .background(.fill.tertiary, in: .circle)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value ?? "—")
                .font(.callout.weight(.medium))
                .monospacedDigit()
        }
        .frame(minWidth: 90)
    }

    private func arrow(value: String?, pointsRight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value ?? " ")
                .font(.caption.weight(.medium))
                .monospacedDigit()
            Image(systemName: pointsRight ? "arrow.right" : "arrow.left")
                .font(.title3)
                .foregroundStyle(value == nil ? .tertiary : .secondary)
                .contentTransition(motion.symbolSwap)
                .animation(motion.crossfade, value: pointsRight)
                // The symbol crossfades in place; where the arrow sits follows the row's own
                // animation, so it doesn't slide under Reduce Motion when the adapter comes and
                // the direction turns in the same update.
                .geometryGroup()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 28)
    }
}
#endif
