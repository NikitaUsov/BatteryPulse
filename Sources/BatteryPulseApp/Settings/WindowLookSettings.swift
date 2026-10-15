#if os(macOS)
import BatteryCore
import SwiftUI

/// Settings → General: how the main and compact windows look, from opaque to clear glass.
///
/// Only the main and compact windows follow it; Settings itself never turns see-through, so a
/// choice that turns out hard to read can always be undone here. The change applies at once,
/// without animation: a background swap is not a motion event.
struct WindowLookSettings: View {
    @AppStorage(AppSettings.windowLookKey) private var windowLook = WindowLook.standard
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let policy = WindowLookPolicy(
            setting: windowLook, reduceTransparency: reduceTransparency, increaseContrast: contrast == .increased)
        Section {
            PreviewTilePicker(selection: $windowLook, values: WindowLook.allCases, title: \.title) { look in
                WindowLookPreview(look: look)
            }
        } header: {
            Text("Window Style")
        } footer: {
            footer(policy)
        }
    }

    /// What the choice costs, or why it doesn't apply. The tiles stay enabled under an
    /// accessibility setting, so the choice can still be made for later.
    @ViewBuilder
    private func footer(_ policy: WindowLookPolicy) -> some View {
        if policy.override != nil {
            Text(
                "Standard is used while Reduce transparency or Increase contrast is on in Accessibility settings.")
        } else {
            switch policy.setting {
            case .standard:
                EmptyView()
            case .frosted:
                Text("Shows the desktop through BatteryPulse windows.")
            case .translucent:
                Text(
                    "Shows more of the desktop through BatteryPulse windows. Can be harder to read and uses more energy."
                )
            case .clear:
                Text(
                    "Pure glass: the desktop shows through and all content turns white. The hardest to read, and uses more energy."
                )
            }
        }
    }
}

/// A window style drawn small for its tile: a made-up wallpaper with a little window on it, the
/// way that style looks. A static drawing, not live glass, so Settings stays opaque; it follows
/// the system appearance like the rest of Settings.
struct WindowLookPreview: View {
    let look: WindowLook
    @Environment(\.colorScheme) private var colorScheme

    /// Nonisolated: the tile picker sizes every preview from it.
    nonisolated static let size = CGSize(width: 96, height: 64)

    var body: some View {
        let painter = WindowLookPainter(look: look, isDark: colorScheme == .dark)
        Canvas { context, size in
            // Drawn at 96 × 64 pt and scaled to the frame: four tiles take about the whole width
            // of a Settings row, so a row a few points narrower shrinks them instead of
            // overflowing.
            context.scaleBy(x: size.width / Self.size.width, y: size.height / Self.size.height)
            painter.paint(in: &context, size: Self.size)
        }
        .aspectRatio(Self.size.width / Self.size.height, contentMode: .fit)
        .frame(maxWidth: Self.size.width, maxHeight: Self.size.height)
        .clipShape(.rect(cornerRadius: 6, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Draws one preview. Coordinates are in the 96 × 64 pt tile.
private struct WindowLookPainter: Sendable {
    let look: WindowLook
    let isDark: Bool

    private static let panel = CGRect(x: 10, y: 8, width: 76, height: 50)
    private static let sidebarWidth: CGFloat = 20
    /// The two groups of content: a hero with a battery, and a group of rows.
    private static let groups = [
        CGRect(x: 34, y: 12, width: 48, height: 18), CGRect(x: 34, y: 34, width: 48, height: 20),
    ]

    func paint(in context: inout GraphicsContext, size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
        drawWallpaper(in: &context, bounds: bounds)
        let panelPath = Path(roundedRect: Self.panel, cornerRadius: 5)
        context.drawLayer { layer in
            layer.clip(to: panelPath)
            drawBackdrop(in: &layer, bounds: bounds)
            let sidebar = CGRect(
                x: Self.panel.minX, y: Self.panel.minY, width: Self.sidebarWidth, height: Self.panel.height)
            layer.fill(Path(sidebar), with: .color(sidebarColor))
        }
        drawGroups(in: &context)
        context.drawLayer { layer in
            // Clear's marks are white with a soft shadow under them, like its window's content.
            if look == .clear {
                layer.addFilter(.shadow(color: .black.opacity(0.55), radius: 1.5))
            }
            drawMarks(in: &layer)
        }
        context.stroke(panelPath, with: .color(rimColor), lineWidth: look == .clear ? 0.8 : 0.5)
    }

    // MARK: Wallpaper

    private func drawWallpaper(in context: inout GraphicsContext, bounds: CGRect) {
        let sky =
            isDark
            ? [Color(red: 0.17, green: 0.20, blue: 0.42), Color(red: 0.40, green: 0.25, blue: 0.48)]
            : [Color(red: 0.99, green: 0.72, blue: 0.45), Color(red: 0.93, green: 0.45, blue: 0.48)]
        context.fill(
            Path(bounds),
            with: .linearGradient(
                Gradient(colors: sky), startPoint: CGPoint(x: bounds.minX, y: bounds.minY),
                endPoint: CGPoint(x: bounds.maxX, y: bounds.maxY)))
        let sun = isDark ? Color(white: 0.92) : Color(red: 1, green: 0.94, blue: 0.72)
        context.fill(Path(ellipseIn: CGRect(x: 60, y: 4, width: 24, height: 24)), with: .color(sun))
        let hills =
            isDark
            ? [Color(red: 0.10, green: 0.18, blue: 0.22), Color(red: 0.06, green: 0.11, blue: 0.16)]
            : [Color(red: 0.25, green: 0.47, blue: 0.43), Color(red: 0.15, green: 0.33, blue: 0.37)]
        context.fill(Path(ellipseIn: CGRect(x: -24, y: 36, width: 84, height: 52)), with: .color(hills[0]))
        context.fill(Path(ellipseIn: CGRect(x: 36, y: 42, width: 86, height: 48)), with: .color(hills[1]))
    }

    /// What shows inside the little window: an opaque fill, frost, or the wallpaper through glass.
    private func drawBackdrop(in context: inout GraphicsContext, bounds: CGRect) {
        switch look {
        case .standard:
            context.fill(Path(bounds), with: .color(isDark ? Color(white: 0.12) : Color(white: 0.98)))
        case .frosted:
            context.drawLayer { blurred in
                blurred.addFilter(.blur(radius: 6))
                drawWallpaper(in: &blurred, bounds: bounds)
            }
            let frost = isDark ? Color(red: 0.12, green: 0.12, blue: 0.13).opacity(0.7) : .white.opacity(0.5)
            context.fill(Path(bounds), with: .color(frost))
        case .translucent:
            context.drawLayer { blurred in
                blurred.addFilter(.blur(radius: 1.5))
                drawWallpaper(in: &blurred, bounds: bounds)
            }
            context.fill(Path(bounds), with: .color(isDark ? .black.opacity(0.45) : .white.opacity(0.45)))
        case .clear:
            // The desktop almost sharp; only a faint tone of the glass.
            context.fill(Path(bounds), with: .color(isDark ? Color(white: 0.03).opacity(0.22) : .white.opacity(0.06)))
        }
    }

    // MARK: Content

    private func drawGroups(in context: inout GraphicsContext) {
        switch look {
        case .standard:
            let fill = isDark ? Color(white: 0.19) : Color(white: 0.93)
            for group in Self.groups {
                context.fill(Path(roundedRect: group, cornerRadius: 3), with: .color(fill))
            }
        case .frosted:
            for group in Self.groups {
                let path = Path(roundedRect: group, cornerRadius: 3)
                context.fill(path, with: .color(.white.opacity(isDark ? 0.06 : 0.30)))
                context.stroke(path, with: .color(.white.opacity(isDark ? 0.18 : 0.59)), lineWidth: 0.5)
            }
        case .translucent, .clear:
            // No surfaces: a hairline between the groups.
            let line = CGRect(
                x: Self.groups[1].minX, y: Self.groups[1].minY - 2, width: Self.groups[1].width, height: 0.5)
            let color: Color =
                look == .clear ? .white.opacity(0.34) : (isDark ? .white.opacity(0.25) : .black.opacity(0.18))
            context.fill(Path(line), with: .color(color))
        }
    }

    private func drawMarks(in context: inout GraphicsContext) {
        let ink = inkColor
        // The sidebar: the selected row and two more.
        let selection = Path(roundedRect: CGRect(x: 12.5, y: 13, width: 15, height: 4), cornerRadius: 2)
        context.fill(selection, with: .color(look == .clear ? Color(white: ToneMap.graphite) : .accentColor))
        for (y, width) in [(20.0, 11.0), (25.0, 9.0)] {
            context.fill(
                Path(roundedRect: CGRect(x: 14, y: y, width: width, height: 2), cornerRadius: 1),
                with: .color(ink.opacity(0.6)))
        }
        // The hero: a battery at 70 % and two lines of text.
        let battery = CGRect(x: 38, y: 17, width: 14, height: 8)
        context.stroke(Path(roundedRect: battery, cornerRadius: 2), with: .color(ink.opacity(0.7)), lineWidth: 0.8)
        let fill = CGRect(
            x: battery.minX + 1.5, y: battery.minY + 1.5, width: (battery.width - 3) * 0.7, height: battery.height - 3)
        context.fill(
            Path(roundedRect: fill, cornerRadius: 1), with: .color(look == .clear ? .white.opacity(0.95) : .green))
        context.fill(Path(roundedRect: CGRect(x: 56, y: 17, width: 20, height: 3), cornerRadius: 1), with: .color(ink))
        context.fill(
            Path(roundedRect: CGRect(x: 56, y: 22.5, width: 14, height: 2), cornerRadius: 1),
            with: .color(ink.opacity(0.6)))
        // The rows of the second group.
        for (y, width) in [(39.0, 30.0), (44.0, 22.0), (49.0, 26.0)] {
            context.fill(
                Path(roundedRect: CGRect(x: 38, y: y, width: width, height: 2), cornerRadius: 1),
                with: .color(ink.opacity(0.7)))
        }
    }

    /// Text and symbols: white on Clear and on dark backdrops, dark otherwise.
    private var inkColor: Color {
        look == .clear || isDark ? .white.opacity(0.92) : .black.opacity(0.75)
    }

    private var sidebarColor: Color {
        switch look {
        case .standard: isDark ? Color(white: 0.17) : Color(white: 0.90)
        case .frosted: isDark ? .black.opacity(0.15) : .white.opacity(0.25)
        case .translucent: isDark ? .black.opacity(0.15) : .white.opacity(0.2)
        case .clear: .black.opacity(isDark ? 0.2 : 0.12)
        }
    }

    /// The edge of the little window: Clear's bright specular rim, a faint one elsewhere.
    private var rimColor: Color {
        switch look {
        case .standard: .black.opacity(isDark ? 0.5 : 0.15)
        case .frosted: .white.opacity(isDark ? 0.18 : 0.59)
        case .translucent: .white.opacity(0.35)
        case .clear: .white.opacity(0.9)
        }
    }
}
#endif
