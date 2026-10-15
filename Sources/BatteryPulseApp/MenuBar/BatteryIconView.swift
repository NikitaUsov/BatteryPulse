#if os(macOS)
import AppKit
import BatteryCore
import CoreText
import SwiftUI

/// Paints a drawn battery icon (every style but the SF Symbol) from ``BatteryIconLayout``. The
/// decisions (state, colours, geometry) come from BatteryCore; this only turns them into paths.
struct BatteryIconPainter: Sendable {
    let layout: BatteryIconLayout
    let state: BatteryIconState
    /// The menu bar's text colour; black for a template image.
    let label: Color
    /// Device pixels per layout point, so the fill ends on a pixel edge.
    let pixelScale: CGFloat

    /// The label colour, or red when low and yellow in Low Power Mode.
    var fill: Color {
        switch state.tint {
        case .monochrome: label
        case .low: .red
        case .lowPower: .yellow
        }
    }

    func paint(in context: inout GraphicsContext, magnification: CGFloat) {
        context.scaleBy(x: magnification, y: magnification)
        // A layer of its own, so the knocked-out parts never cut into what's behind the icon.
        context.drawLayer { layer in
            if layout.isRing {
                paintRing(in: &layer)
            } else {
                paintBar(in: &layer)
            }
            paintGlyph(in: &layer)
        }
    }

    // MARK: Parts

    private func paintBar(in context: inout GraphicsContext) {
        let fillEnd = layout.fillArea.x + layout.fillWidth(level: state.level, pixelScale: Double(pixelScale))
        if layout.trackOpacity > 0 {
            var track = context
            track.clip(to: Path(trailing(from: fillEnd)))
            track.opacity = layout.trackOpacity
            track.fill(rounded(layout.body, layout.cornerRadius), with: .color(label))
        }
        if fillEnd > layout.fillArea.x {
            var fillContext = context
            fillContext.clip(to: Path(leading(to: fillEnd)))
            fillContext.fill(rounded(layout.fillArea, layout.fillCornerRadius), with: .color(fill))
        }
        if layout.outlineWidth > 0 {
            let inset = layout.outlineWidth / 2
            context.stroke(
                rounded(layout.body.insetBy(inset), max(0, layout.cornerRadius - inset)),
                with: .color(label), lineWidth: CGFloat(layout.outlineWidth))
        }
        if let nub = layout.nub {
            var nubContext = context
            nubContext.opacity = layout.nubOpacity
            nubContext.clip(to: Path(cgRect(nub)))
            // The right half of an ellipse twice the terminal's width: flat against the battery.
            nubContext.fill(
                Path(ellipseIn: CGRect(x: nub.x - nub.width, y: nub.y, width: nub.width * 2, height: nub.height)),
                with: .color(label))
        }
        if let digits = layout.digits, let percent = state.percent {
            paintDigits(digits, percent: percent, in: &context)
        }
    }

    /// The number and the glyph after it, knocked out of the battery (fill and track alike) so they
    /// keep one colour. Built from the font's outlines: exact cap height and baseline, and nothing
    /// can leave the box the layout gives it.
    private func paintDigits(_ digits: BatteryIconLayout.Digits, percent: Int, in context: inout GraphicsContext) {
        guard let number = DigitOutlines(String(percent), capHeight: digits.capHeight) else { return }
        let placement = digits.placement(textWidth: number.width, digitCount: number.count)
        var path = number.path(in: placement.text, scale: placement.scale, tracking: placement.tracking)
        if let box = placement.glyph {
            path.addPath(glyphPath(in: box))
        }
        var knockOut = context
        knockOut.blendMode = .destinationOut
        // The system leaves a tenth of the battery under the number.
        knockOut.opacity = digits.knockOut
        knockOut.fill(path, with: .color(.black))
    }

    /// The bold system font's digits (SF Pro Bold, default proportional figures) as Core Text
    /// outlines, at the size whose cap height is `capHeight`. Made for each render, which happens
    /// once per state change.
    private struct DigitOutlines {
        let font: CTFont
        let glyphs: [CGGlyph]
        let advances: [CGSize]
        /// The number's advance, in points.
        let width: Double
        var count: Int { glyphs.count }

        /// `nil` when Core Text has no system font or no glyph for a character; the number is then
        /// not drawn.
        init?(_ string: String, capHeight: Double) {
            guard let reference = CTFontCreateUIFontForLanguage(.emphasizedSystem, 100, nil) else { return nil }
            let referenceCapHeight = CTFontGetCapHeight(reference)
            guard referenceCapHeight > 0,
                let font = CTFontCreateUIFontForLanguage(
                    .emphasizedSystem, CGFloat(capHeight) * 100 / referenceCapHeight, nil)
            else { return nil }
            let characters = Array(string.utf16)
            var glyphs = [CGGlyph](repeating: 0, count: characters.count)
            guard CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count) else { return nil }
            var advances = [CGSize](repeating: .zero, count: glyphs.count)
            width = CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)
            self.font = font
            self.glyphs = glyphs
            self.advances = advances
        }

        /// The baseline on `rect.maxY` and the first digit's origin at `rect.x`, scaled by `scale`,
        /// with `tracking` (points as drawn) after every digit.
        func path(in rect: IconRect, scale: Double, tracking: Double) -> Path {
            let outline = CGMutablePath()
            var x = rect.x
            for (glyph, advance) in zip(glyphs, advances) {
                if let glyphOutline = CTFontCreatePathForGlyph(font, glyph, nil) {
                    // Core Text is y up: flip it and put the baseline on rect.maxY.
                    let transform = CGAffineTransform(
                        a: CGFloat(scale), b: 0, c: 0, d: CGFloat(-scale), tx: CGFloat(x), ty: CGFloat(rect.maxY))
                    outline.addPath(glyphOutline, transform: transform)
                }
                x += Double(advance.width) * scale + tracking
            }
            return Path(outline)
        }
    }

    private func paintRing(in context: inout GraphicsContext) {
        let circle = cgRect(layout.body.insetBy(layout.ringLineWidth / 2))
        let ring = Path(ellipseIn: circle)
        var track = context
        track.opacity = layout.trackOpacity
        track.stroke(ring, with: .color(label), lineWidth: CGFloat(layout.ringLineWidth))
        guard state.level > 0 else { return }
        // The ellipse starts at three o'clock; turn it to start at the top and run clockwise.
        let rotation = CGAffineTransform(translationX: circle.midX, y: circle.midY)
            .rotated(by: -.pi / 2)
            .translatedBy(x: -circle.midX, y: -circle.midY)
        context.stroke(
            ring.trimmedPath(from: 0, to: CGFloat(state.level)).applying(rotation),
            with: .color(fill), style: StrokeStyle(lineWidth: CGFloat(layout.ringLineWidth), lineCap: .round))
    }

    /// The bolt or plug in the label colour, with a thin gap knocked out around it so it stays
    /// visible where it crosses the fill.
    private func paintGlyph(in context: inout GraphicsContext) {
        guard let box = layout.glyph else { return }
        let path = glyphPath(in: box)
        // A zero line width would still stroke a hairline.
        if layout.glyphGap > 0 {
            var knockOut = context
            knockOut.blendMode = .destinationOut
            knockOut.stroke(
                path, with: .color(.black),
                style: StrokeStyle(lineWidth: CGFloat(layout.glyphGap * 2), lineJoin: .round))
            knockOut.fill(path, with: .color(.black))
        }
        context.fill(path, with: .color(label))
    }

    private func glyphPath(in box: IconRect) -> Path {
        var path = Path()
        switch state.glyph {
        case .none:
            break
        case .bolt:
            path.addLines(BatteryIconGlyphs.bolt(in: box).map { CGPoint(x: $0.x, y: $0.y) })
            path.closeSubpath()
        case .plug:
            for part in BatteryIconGlyphs.plug(in: box) {
                path.addRoundedRect(
                    in: cgRect(part.rect), cornerSize: CGSize(width: part.cornerRadius, height: part.cornerRadius))
            }
        }
        return path
    }

    // MARK: Geometry

    private func cgRect(_ rect: IconRect) -> CGRect {
        CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
    }

    /// Circular corners, the shape measured on the system's battery (exact half circles when the
    /// radius reaches half the side).
    private func rounded(_ rect: IconRect, _ radius: Double) -> Path {
        Path(
            roundedRect: cgRect(rect), cornerRadius: CGFloat(min(radius, min(rect.width, rect.height) / 2)),
            style: .circular)
    }

    /// Everything left of `x`, with room to spare around the icon.
    private func leading(to x: Double) -> CGRect {
        CGRect(x: -1, y: -1, width: x + 1, height: layout.height + 2)
    }

    /// Everything right of `x`.
    private func trailing(from x: Double) -> CGRect {
        CGRect(x: x, y: -1, width: layout.width + 1 - x, height: layout.height + 2)
    }
}

/// A drawn battery icon at `magnification` times its menu bar size.
struct BatteryIconCanvas: View {
    let layout: BatteryIconLayout
    let state: BatteryIconState
    var label: Color = .primary
    var magnification: CGFloat = 1
    /// The device scale to align the fill to; the display's when `nil`.
    var pixelScale: CGFloat?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let factor = magnification
        let painter = BatteryIconPainter(
            layout: layout, state: state, label: label, pixelScale: (pixelScale ?? displayScale) * factor)
        Canvas { context, _ in
            painter.paint(in: &context, magnification: factor)
        }
        .frame(width: CGFloat(layout.width) * magnification, height: CGFloat(layout.height) * magnification)
        .accessibilityHidden(true)
    }
}

/// An icon style as it looks in the menu bar, for Settings.
struct MenuBarIconPreview: View {
    let style: MenuBarIconStyle
    var state = BatteryIconState.sample
    var magnification: CGFloat = 1.5

    var body: some View {
        if let layout = BatteryIconLayout(style: style, state: state) {
            BatteryIconCanvas(layout: layout, state: state, magnification: magnification)
        } else {
            let snapshot = BatterySnapshot(
                timestamp: .now, chargePercent: state.level * 100,
                chargeState: state.glyph == .bolt ? .charging : .discharging)
            Image(systemName: BatteryPresentation.symbolName(for: snapshot))
                .font(.system(size: 13 * magnification))
                .accessibilityHidden(true)
        }
    }
}

/// Turns a drawn icon into an image for the status item, whose label shows images and text but
/// doesn't reliably draw shapes.
@MainActor
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
/// ones. Immutable after creation.
private final class AppearanceVariants: @unchecked Sendable {
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
