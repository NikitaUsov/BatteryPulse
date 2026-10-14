#if os(macOS)
import SwiftUI

/// The app icon drawn in SwiftUI, so windows show it even when the app runs unbundled
/// (`swift run`). Mirrors `Resources/AppIcon.svg` in the same 1024-point coordinate space.
struct AppIconView: View {
    private static let pulse: [CGPoint] = [
        CGPoint(x: 160, y: 512), CGPoint(x: 330, y: 512), CGPoint(x: 382, y: 420),
        CGPoint(x: 452, y: 640), CGPoint(x: 520, y: 360), CGPoint(x: 572, y: 560),
        CGPoint(x: 612, y: 512), CGPoint(x: 864, y: 512),
    ]

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 1024
            context.scaleBy(x: scale, y: scale)

            let light = Color(rgb: 0xF8FAFC)
            let dark = Color(rgb: 0x020617)

            let tile = Path(
                roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerRadius: 185, style: .continuous)
            context.fill(
                tile,
                with: .linearGradient(
                    Gradient(colors: [Color(rgb: 0x1E293B), dark]),
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
                with: .color(light), lineWidth: 36)
            context.fill(
                Path(roundedRect: CGRect(x: 764, y: 447, width: 44, height: 130), cornerRadius: 18),
                with: .color(light))
            context.fill(
                Path(roundedRect: CGRect(x: 268, y: 394, width: 330, height: 236), cornerRadius: 38),
                with: .linearGradient(
                    Gradient(colors: [Color(rgb: 0x22C55E), Color(rgb: 0xA3E635)]),
                    startPoint: CGPoint(x: 268, y: 512), endPoint: CGPoint(x: 598, y: 512)))

            var pulse = Path()
            pulse.addLines(Self.pulse)
            context.stroke(
                pulse, with: .color(dark), style: StrokeStyle(lineWidth: 62, lineCap: .round, lineJoin: .round))
            context.stroke(
                pulse, with: .color(light), style: StrokeStyle(lineWidth: 30, lineCap: .round, lineJoin: .round))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
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
