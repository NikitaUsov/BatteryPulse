#if os(macOS)
import AppKit
import BatteryArt
import BatteryCore
import SwiftUI

/// An icon style as it looks in the menu bar, for Settings, at the sample state. Every style takes
/// the same frame (``BatteryIconLayout/previewSize``), so the tiles match.
struct MenuBarIconPreview: View {
    let style: MenuBarIconStyle
    let magnification: CGFloat

    var body: some View {
        let size = BatteryIconLayout.previewSize
        let state = BatteryIconState.sample
        Group {
            if let layout = BatteryIconLayout(style: style, state: state) {
                BatteryIconCanvas(layout: layout, state: state, magnification: magnification)
            } else {
                let symbol = BatteryPresentation.symbolName(
                    percent: state.level * 100, state: state.glyph == .bolt ? .charging : .discharging)
                // Fitted to the bar styles' battery (the canvas less the bolt's overshoot).
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: CGFloat(size.width) * magnification, height: CGFloat(size.height - 2) * magnification)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: CGFloat(size.width) * magnification, height: CGFloat(size.height) * magnification)
    }
}

/// Turns a drawn icon into an image for the status item, whose label shows images and text but
/// doesn't reliably draw shapes.
enum MenuBarIconRenderer {
    private struct Key: Equatable {
        var style: MenuBarIconStyle
        var state: BatteryIconState
        var scale: CGFloat
    }

    /// The menu bar asks for the image on every reading; it only changes with the state.
    private static var cached: (key: Key, image: NSImage)?

    /// A template image while monochrome, so the menu bar tints it for light and dark bars; with a
    /// red or yellow fill, an image that draws itself for the appearance it appears in. `nil` for
    /// the SF Symbol style, or when rendering fails.
    static func image(style: MenuBarIconStyle, state: BatteryIconState) -> NSImage? {
        guard let layout = BatteryIconLayout(style: style, state: state) else { return nil }
        // Render for the sharpest screen; a window server copy scales down cleanly.
        let scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
        let key = Key(style: style, state: state, scale: scale)
        if let cached, cached.key == key { return cached.image }

        let size = NSSize(width: layout.width, height: layout.height)
        let image: NSImage
        if state.isMonochrome {
            guard let cgImage = render(layout, state, label: .black, scale: scale) else { return nil }
            image = NSImage(cgImage: cgImage, size: size)
            image.isTemplate = true
        } else {
            guard let onLight = render(layout, state, label: .black, scale: scale),
                let onDark = render(layout, state, label: .white, scale: scale)
            else { return nil }
            image = adaptiveImage(size: size, variants: AppearanceVariants(onLight: onLight, onDark: onDark))
        }
        cached = (key, image)
        return image
    }

    private static func render(
        _ layout: BatteryIconLayout, _ state: BatteryIconState, label: Color, scale: CGFloat
    ) -> CGImage? {
        let renderer = ImageRenderer(
            content: BatteryIconCanvas(layout: layout, state: state, label: label, pixelScale: scale))
        renderer.scale = scale
        return renderer.cgImage
    }

    /// Nonisolated, so the drawing handler doesn't inherit the main actor: AppKit may call it
    /// whenever it draws the image.
    private nonisolated static func adaptiveImage(size: NSSize, variants: AppearanceVariants) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            variants.draw(in: rect)
        }
        image.isTemplate = false
        return image
    }
}

/// The two renderings of a coloured icon: dark parts for light menu bars, light parts for dark
/// ones. Immutable after creation. Nonisolated: it draws in the image's drawing handler, which
/// AppKit calls whenever it draws the image.
private nonisolated final class AppearanceVariants: @unchecked Sendable {
    private let onLight: CGImage
    private let onDark: CGImage

    init(onLight: CGImage, onDark: CGImage) {
        self.onLight = onLight
        self.onDark = onDark
    }

    /// AppKit sets the drawing appearance to that of the view drawing the image: here the menu
    /// bar's, which follows the wallpaper rather than the app's light or dark setting.
    func draw(in rect: NSRect) -> Bool {
        guard let context = NSGraphicsContext.current?.cgContext else { return false }
        let isDark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        context.draw(isDark ? onDark : onLight, in: rect)
        return true
    }
}
#endif
