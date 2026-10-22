#if os(macOS)
import BatteryCore
import SwiftUI

/// A ring-shaped gauge (the built-in circular style is watchOS-only).
struct RingGaugeStyle: GaugeStyle {
    var tint: Color
    var diameter: CGFloat = 112
    var lineWidth: CGFloat = 11

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RingTrack(lineWidth: lineWidth)
            RingArc(value: configuration.value, tint: tint, lineWidth: lineWidth)
            RingLabels(value: configuration.currentValueLabel, label: configuration.label)
                // Keep the text inside the ring: roughly the square inscribed in its inner edge,
                // so long labels (Russian ones especially) wrap instead of running into the stroke.
                .frame(maxWidth: (diameter - lineWidth) * 0.74)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// The value and the title inside a ring; bold and medium on the glass sheet.
private struct RingLabels<Value: View, Title: View>: View {
    let value: Value
    let label: Title
    @Environment(\.windowLook) private var look

    var body: some View {
        VStack(spacing: 2) {
            value
                .font(.title2.weight(look.boldNumerals ? .bold : .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            label
                .font(look.boldNumerals ? .caption.weight(.medium) : .caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
}

/// The channel under the ring's arc.
private struct RingTrack: View {
    let lineWidth: CGFloat
    @Environment(\.tones) private var tones

    var body: some View {
        Circle()
            .stroke(tones.style(.track), lineWidth: lineWidth)
    }
}

/// The ring's coloured arc, a view of its own so it can read `\.motion`. In Clear it is a white
/// glass piece, whatever the tint.
private struct RingArc: View {
    let value: Double
    let tint: Color
    let lineWidth: CGFloat
    @Environment(\.motion) private var motion
    @Environment(\.tones) private var tones

    var body: some View {
        let fraction = max(0.001, min(1, value))
        let arc = Circle().trim(from: 0, to: fraction)
        let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        Group {
            // The colour styles keep the tint itself, so a new tier still crossfades.
            if let piece = tones.levelPieceStyle {
                arc.stroke(piece, style: stroke)
            } else {
                arc.stroke(tint, style: stroke)
            }
        }
        .rotationEffect(.degrees(-90))
        // The arc grows or shrinks to a new value (a whole percent, a cycle, maximum capacity)
        // and crossfades to a new tier colour. A built-in animatable shape: no body per frame.
        // Under Reduce Motion the arc snaps and only the colour fades; the inner modifier
        // wins when both change at once, so the arc never sweeps then.
        .animation(motion.change, value: fraction)
        .animation(motion.crossfade, value: tint)
        // Where the ring sits is the page's business: when the page's layout changes in the
        // same update, the arc moves with the track, not with its own animation.
        .geometryGroup()
    }
}
#endif
