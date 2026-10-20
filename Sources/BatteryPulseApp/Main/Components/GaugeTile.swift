#if os(macOS)
import BatteryCore
import SwiftUI

/// Gauge tile used on the Overview: a ring with a caption underneath.
struct GaugeTile: View {
    let title: LocalizedStringKey
    let fraction: Double
    let value: String
    /// The number `value` shows (a percentage, a cycle count), so it rolls in the direction of a
    /// change.
    var number: Double?
    let caption: String?
    var captionHelp: String?
    let tint: Color
    /// Clear's warning badge, shown in place of the caption: the words of a low or critical tier.
    var badge: String?

    var body: some View {
        Card {
            VStack(spacing: 10) {
                Gauge(value: fraction) {
                    Text(title)
                } currentValueLabel: {
                    Text(value)
                        .numericValue(number)
                }
                .gaugeStyle(RingGaugeStyle(tint: tint))
                if let badge {
                    InvertedBadge(text: Text(badge))
                } else if let caption {
                    Text(caption)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .help(captionHelp ?? "")
                }
            }
            // Fill the row's height, so tiles stay equal when one caption wraps.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}
#endif
