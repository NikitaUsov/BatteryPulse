#if os(macOS)
import BatteryCore
import SwiftUI

/// The app icon drawn in SwiftUI, so windows show it even when the app runs unbundled
/// (`swift run`). Mirrors `Resources/AppIcon.svg` in the same 1024-point coordinate space.
///
/// The pulse line is a shape on top of the drawing rather than part of it, so the welcome window
/// can draw it in with a trim: a built-in animation, where animating the `Canvas` would redraw
/// the whole icon on every frame.
struct AppIconView: View {
    private let drawsIn: Bool
    @Environment(\.motion) private var motion
    /// How much of the pulse line shows, from its start; `nil` until the view has appeared.
    @State private var pulseEnd: CGFloat?
    /// The draw-in plays once per launch, not every time the window opens.
    private static var hasDrawnIn = false

    /// - Parameter drawsIn: Draw the pulse line in from left to right when the view first appears
    ///   (the welcome window). It is a one-off extra: not under Reduce Motion or Low Power Mode,
    ///   and only once per launch.
    init(drawsIn: Bool = false) {
        self.drawsIn = drawsIn
    }

    private var willDrawIn: Bool {
        drawsIn && !Self.hasDrawnIn && motion.allowsFlourish
    }

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 1024
            context.scaleBy(x: scale, y: scale)

            let tile = Path(
                roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerRadius: 185, style: .continuous)
            context.fill(
                tile,
                with: .linearGradient(
                    Gradient(colors: [Color(rgb: 0x1E293B), IconColor.dark]),
                    startPoint: CGPoint(x: 512, y: 100), endPoint: CGPoint(x: 512, y: 924)))
            context.fill(
                tile,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .white.opacity(0.16), location: 0),
                        .init(color: .white.opacity(0), location: 0.5),
                    ]),
                    startPoint: CGPoint(x: 512, y: 100), endPoint: CGPoint(x: 512, y: 924)))

            context.stroke(
                Path(roundedRect: CGRect(x: 226, y: 352, width: 520, height: 320), cornerRadius: 72),
                with: .color(IconColor.light), lineWidth: 36)
            context.fill(
                Path(roundedRect: CGRect(x: 764, y: 447, width: 44, height: 130), cornerRadius: 18),
                with: .color(IconColor.light))
            context.fill(
                Path(roundedRect: CGRect(x: 268, y: 394, width: 330, height: 236), cornerRadius: 38),
                with: .linearGradient(
                    Gradient(colors: [Color(rgb: 0x22C55E), Color(rgb: 0xA3E635)]),
                    startPoint: CGPoint(x: 268, y: 512), endPoint: CGPoint(x: 598, y: 512)))
        }
        .overlay {
            // Hidden until the view appears when it is about to draw in, so it never flashes.
            Pulse(end: pulseEnd ?? (willDrawIn ? 0 : 1))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
        .onAppear { appear() }
    }

    private func appear() {
        guard pulseEnd == nil else { return }
        guard willDrawIn else {
            pulseEnd = 1
            return
        }
        Self.hasDrawnIn = true
        withAnimation(motion.iconDrawIn) { pulseEnd = 1 }
    }
}

/// The icon's pulse line: a dark outline under a light line, both drawn up to `end` (0…1).
private struct Pulse: View {
    let end: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width, geometry.size.height) / 1024
            let line = PulseLine().trim(from: 0, to: end)
            ZStack {
                line.stroke(
                    IconColor.dark, style: StrokeStyle(lineWidth: 62 * scale, lineCap: .round, lineJoin: .round))
                line.stroke(
                    IconColor.light, style: StrokeStyle(lineWidth: 30 * scale, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

/// The pulse line's path, from the 1024-point space of `Resources/AppIcon.svg` scaled to the
/// view as the `Canvas` scales the rest of the icon. Nonisolated, as `Shape` requires: SwiftUI
/// may ask for the path off the main actor.
private nonisolated struct PulseLine: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 1024
        let points = [
            CGPoint(x: 160, y: 512), CGPoint(x: 330, y: 512), CGPoint(x: 382, y: 420),
            CGPoint(x: 452, y: 640), CGPoint(x: 520, y: 360), CGPoint(x: 572, y: 560),
            CGPoint(x: 612, y: 512), CGPoint(x: 864, y: 512),
        ]
        var path = Path()
        path.addLines(points.map { CGPoint(x: rect.minX + $0.x * scale, y: rect.minY + $0.y * scale) })
        return path
    }
}

/// The icon's colors, as in `Resources/AppIcon.svg`.
private enum IconColor {
    static var light: Color { Color(rgb: 0xF8FAFC) }
    static var dark: Color { Color(rgb: 0x020617) }
}

extension Color {
    /// `Color(rgb: 0x1E293B)`.
    fileprivate init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255)
    }
}
#endif
