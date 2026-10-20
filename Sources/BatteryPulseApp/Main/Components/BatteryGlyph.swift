#if os(macOS)
import BatteryCore
import SwiftUI

/// A battery drawn to the exact level, with a bolt while charging. Used by the Overview, the
/// compact window and the menu bar panel.
///
/// The fill follows a new whole percent and crossfades to a new tier colour; the bolt draws in
/// when charging starts and goes when it stops. In Clear the fill is a white glass piece and the
/// bolt over it dark.
struct BatteryGlyph: View {
    let level: Double
    let isCharging: Bool
    let tint: Color
    @Environment(\.motion) private var motion
    @Environment(\.tones) private var tones

    var body: some View {
        // The fill animates per whole percent, the step the app shows.
        let wholePercent = (level * 100).rounded()
        GeometryReader { geometry in
            let height = geometry.size.height
            let terminalWidth = height * 0.12
            let bodyWidth = geometry.size.width - terminalWidth - height * 0.04
            let inset = height * 0.1
            let fillWidth = max(0, (bodyWidth - inset * 2) * min(1, max(0, level)))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height * 0.24, style: .continuous)
                    .strokeBorder(.secondary, lineWidth: max(2, height * 0.06))
                    .frame(width: bodyWidth)
                let fill = RoundedRectangle(cornerRadius: height * 0.15, style: .continuous)
                Group {
                    if let piece = tones.levelPieceStyle {
                        fill.fill(piece)
                    } else {
                        fill.fill(tint.gradient)
                    }
                }
                .frame(width: fillWidth, height: height - inset * 2)
                .padding(.leading, inset)
                RoundedRectangle(cornerRadius: terminalWidth / 2, style: .continuous)
                    .fill(.secondary)
                    .frame(width: terminalWidth, height: height * 0.36)
                    .offset(x: bodyWidth + height * 0.04)
                if isCharging {
                    // Primary over the empty part of the battery, white over the fill (dark over
                    // Clear's white fill), so the bolt stays visible at any level in Light and
                    // Dark Mode.
                    let bolt = Image(systemName: "bolt.fill")
                        .font(.system(size: height * 0.5, weight: .bold))
                        .frame(width: bodyWidth)
                    // One view, so both copies draw in and out together.
                    ZStack {
                        bolt
                            .foregroundStyle(.primary)
                        bolt
                            .foregroundStyle(tones.style(.onLevelFill))
                            .mask(alignment: .leading) {
                                Rectangle()
                                    .frame(width: inset + fillWidth)
                            }
                    }
                    .transition(motion.boltTransition)
                }
            }
            // Scoped to the glyph, which shows nothing that changes with the live readings. The
            // white bolt's mask moves with the fill. The fill moves, so under Reduce Motion it
            // snaps (the innermost modifier wins when several values change at once); the tint
            // and the bolt only fade.
            .animation(motion.change, value: wholePercent)
            .animation(motion.crossfade, value: tint)
            .animation(motion.crossfade, value: isCharging)
        }
        .aspectRatio(2.2, contentMode: .fit)
        // The glyph's place on the page follows the page's animation, not the ones above: a new
        // tint in the same update as a layout change doesn't slide the glyph.
        .geometryGroup()
        .accessibilityHidden(true)
    }
}
#endif
