import Foundation

// The window style setting (Settings → General): Standard, Frosted, Translucent or Clear. Only
// the main and compact windows follow it. The decisions behind each style live here, free of
// SwiftUI, so they are tested on Linux; `App/WindowLook.swift` maps them to backgrounds and
// modifiers. Code says "window look" because SwiftUI already has a `WindowStyle`.

/// The window style setting, from an opaque window to clear glass. The raw values are stored in
/// the defaults, so they never change.
public enum WindowLook: String, CaseIterable, Sendable {
    /// An opaque window with cards, as before 0.6.
    case standard
    /// A material behind the window: the desktop shows through, blurred and frosted.
    case frosted
    /// One sheet of clear Liquid Glass with a dimming layer; colours kept, no cards.
    case translucent
    /// One sheet of clear Liquid Glass with a dark dimming; all content turns white.
    case clear

    /// Unknown or missing stored values read as ``standard``.
    public init(stored: String?) {
        self = stored.flatMap(Self.init(rawValue:)) ?? .standard
    }
}

/// What a window actually draws, from the stored setting and the accessibility settings.
///
/// Reduce Transparency or Increase Contrast gives ``WindowLook/standard`` whatever the setting:
/// Apple asks for opaque windows under Reduce Transparency and a higher-contrast scheme under
/// Increase Contrast, and a see-through window is neither.
public struct WindowLookPolicy: Equatable, Sendable {
    /// How a group of content (a card) is drawn.
    public enum GroupSurface: Sendable, Equatable {
        /// The standard opaque fill.
        case card
        /// One faint, lighter layer with a hairline rim, on the frosted background.
        case frostLayer
        /// No surface: groups sit on the glass sheet, apart by spacing, headings and hairlines.
        case none
    }

    /// The window background: the only part whose view structure differs between styles.
    public enum Background: Sendable, Equatable {
        /// The system's opaque window background.
        case system
        /// A standard material behind the window.
        case material
        /// One sheet of clear Liquid Glass behind the whole window.
        case glassSheet
    }

    /// Why ``effective`` differs from ``setting``.
    public enum Override: Sendable, Equatable {
        case reduceTransparency, increaseContrast
    }

    /// What the glass sheet's place behind the window draws.
    public enum SheetSurface: Sendable, Equatable {
        /// The clear glass with the sheet's tint, over the desktop it samples.
        case glass(tint: Tint)
        /// A still, plain fill and no glass, from the moment the window starts to minimize until
        /// it has been restored.
        case fill(Tint)
    }

    /// A colour-neutral tint: a grey level (0 black, 1 white) at an opacity.
    public struct Tint: Equatable, Sendable {
        public let white: Double
        public let opacity: Double

        public init(white: Double, opacity: Double) {
            self.white = white
            self.opacity = opacity
        }
    }

    /// The stored choice.
    public let setting: WindowLook
    /// What the window draws.
    public let effective: WindowLook
    /// Why ``effective`` differs from ``setting``, for the Settings footer; `nil` when it doesn't.
    public let override: Override?

    public init(setting: WindowLook, reduceTransparency: Bool, increaseContrast: Bool) {
        self.setting = setting
        // Standard is what the override gives, so it never counts as overridden. Reduce
        // Transparency is named first: it is the setting that asks for opaque windows.
        if setting == .standard {
            override = nil
        } else if reduceTransparency {
            override = .reduceTransparency
        } else if increaseContrast {
            override = .increaseContrast
        } else {
            override = nil
        }
        effective = override == nil ? setting : .standard
    }

    /// The policy of a window that follows no setting: Standard.
    public static let standard = WindowLookPolicy(
        setting: .standard, reduceTransparency: false, increaseContrast: false)

    /// Whether the desktop shows through the window.
    public var showsDesktop: Bool {
        effective != .standard
    }

    public var background: Background {
        switch effective {
        case .standard: .system
        case .frosted: .material
        case .translucent, .clear: .glassSheet
        }
    }

    /// Translucent and Clear: one glass sheet behind the whole window.
    public var usesGlassSheet: Bool {
        background == .glassSheet
    }

    /// Frosted keeps its material active while the window is inactive: the frost is the point of
    /// the choice, and the compact window is usually inactive.
    public var keepsMaterialActive: Bool {
        effective == .frosted
    }

    public var groupSurface: GroupSurface {
        switch effective {
        case .standard: .card
        case .frosted: .frostLayer
        case .translucent, .clear: .none
        }
    }

    /// Forms and tables drop their own background so the window's shows.
    public var hidesFormBackground: Bool {
        showsDesktop
    }

    /// Form rows drop their section fill too: the rows sit on the glass sheet.
    public var clearsFormRows: Bool {
        usesGlassSheet
    }

    /// Numbers in bold and running text in medium weight, for legibility on the glass.
    public var boldNumerals: Bool {
        usesGlassSheet
    }

    /// Whether text may use the tertiary level; on the glass it is too faint.
    public var allowsTertiaryText: Bool {
        !usesGlassSheet
    }

    /// Groups are told apart by hairlines instead of surfaces.
    public var dividesGroupsWithHairlines: Bool {
        groupSurface == .none
    }

    /// Clear puts its window in the dark appearance: content is white in Light and Dark alike.
    public var forcesDarkAppearance: Bool {
        effective == .clear
    }

    /// Clear has no colour: every tint goes through the monochrome tone map.
    public var toneStyle: ToneStyle {
        effective == .clear ? .monochrome : .color
    }

    /// The tone map for this window's content.
    public var tones: ToneMap {
        ToneMap(style: toneStyle, onGlassSheet: usesGlassSheet)
    }

    /// Clear puts a soft shadow under each group of white content, on top of its dimming.
    public var shadowsContent: Bool {
        effective == .clear
    }

    /// The glass sheet's tint for the system appearance: Translucent's dimming layer (black 45 %
    /// in Dark, a white wash of 45 % in Light) or Clear's dark dimming, near-black 65 % in both.
    /// Clear's content is white in both appearances, so a white wash would leave it unreadable
    /// over a bright desktop. 65 % is the smallest round value that keeps white text at 4.5:1 and
    /// secondary text at 3:1 even over a white window behind it; the glass stays colourless and
    /// the desktop visible. `nil` without a sheet.
    public func sheetTint(systemDark: Bool) -> Tint? {
        switch effective {
        case .standard, .frosted: nil
        case .translucent: Tint(white: systemDark ? 0 : 1, opacity: 0.45)
        case .clear: Tint(white: 0.03, opacity: 0.65)
        }
    }

    /// What the glass sheet's place draws: the tinted glass, or, while the window minimizes, sits
    /// in the Dock and is restored, a plain fill of the same tint at the tint's own opacity over
    /// the still see-through window.
    ///
    /// The minimize animation and the Dock show the window's own layers, and the desktop that the
    /// glass samples behind the window isn't one of them, so the sheet would turn near-black for
    /// the whole animation. The fill is the sheet without its blur, and never opaque, so the
    /// desktop still shows through it. The swap is not a motion event and never animates; the
    /// glass comes back once the window is restored. `nil` without a sheet: Standard and Frosted
    /// draw as always.
    public func sheetSurface(systemDark: Bool, isMinimized: Bool) -> SheetSurface? {
        guard let tint = sheetTint(systemDark: systemDark) else { return nil }
        return isMinimized ? .fill(tint) : .glass(tint: tint)
    }

    /// Clear's treatment under each group of white content, for the system appearance: a tight
    /// shadow and a soft halo, a little lighter in Dark, where the glass is smokier. `nil` in
    /// the other styles.
    public func contentTreatment(systemDark: Bool) -> ContentTreatment? {
        guard shadowsContent else { return nil }
        return ContentTreatment(haloOpacity: systemDark ? 0.44 : 0.55)
    }
}

/// Clear's second legibility aid, on top of its dimming: each group of white content (a card, a
/// Form row) gets a tight shadow and a soft halo, Apple's "other treatment beneath the glass". One
/// composited pair per group, never per text, and never on the sidebar or the toolbar.
public struct ContentTreatment: Equatable, Sendable {
    public let shadowOpacity: Double
    public let shadowRadius: Double
    public let shadowOffsetY: Double
    public let haloOpacity: Double
    public let haloRadius: Double

    public init(
        shadowOpacity: Double = 0.6, shadowRadius: Double = 1, shadowOffsetY: Double = 0.5, haloOpacity: Double,
        haloRadius: Double = 6
    ) {
        self.shadowOpacity = shadowOpacity
        self.shadowRadius = shadowRadius
        self.shadowOffsetY = shadowOffsetY
        self.haloOpacity = haloOpacity
        self.haloRadius = haloRadius
    }
}
