#if os(macOS)
import BatteryCore
import SwiftUI

/// Horizontal capacity bars: remaining, full and design mAh on one scale.
struct CapacityBars: View {
    let bars: [CapacityBar]
    let formatter: BatteryFormatter
    @Environment(\.tones) private var tones
    @Environment(\.windowLook) private var look

    init(snapshot: BatterySnapshot, formatter: BatteryFormatter) {
        self.init(bars: CapacityBar.bars(for: snapshot), formatter: formatter)
    }

    /// Bars from any battery, such as an iPhone's.
    init(bars: [CapacityBar], formatter: BatteryFormatter) {
        self.bars = bars
        self.formatter = formatter
    }

    var body: some View {
        let scale = CapacityBar.scale(of: bars)
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            // Identified by kind, so a bar that appears or goes away is that bar, not the last
            // row. The mAh values change every few readings and are not animated.
            ForEach(bars) { bar in
                GridRow {
                    Text(bar.kind.title)
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(bar.capacityMAh), total: scale)
                        .tint(tones.color(.capacity(bar.kind)))
                        .gridColumnAlignment(.leading)
                    Text(formatter.milliampHours(bar.capacityMAh))
                        .monospacedDigit()
                        .gridColumnAlignment(.trailing)
                        .fontWeight(look.boldNumerals ? .bold : nil)
                }
            }
        }
    }
}

extension CapacityBar.Kind {
    var title: LocalizedStringKey {
        switch self {
        case .remaining: "Remaining"
        case .fullCharge: "Full charge"
        case .design: "Design"
        }
    }
}
#endif
