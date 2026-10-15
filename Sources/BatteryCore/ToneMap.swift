import Foundation

// Colour in the main and compact windows goes through roles: a view says what a mark means (a
// level, a capacity bar, a chart line) and the tone map answers with a tone. In Standard, Frosted
// and Translucent the answer is the system colour BatteryPulse has always used; in Clear, the
// colourless glass style, it is white at a fixed opacity step, so no hue reaches the glass and
// state is told by text, symbols and fill. `App/ToneStyle.swift` turns a ``Tone`` into SwiftUI.

/// How a window draws colour.
public enum ToneStyle: Sendable, Equatable, CaseIterable {
    /// System colours: Standard, Frosted and Translucent.
    case color
    /// White at fixed opacity steps and no hue: Clear.
    case monochrome
}

/// A line in one of the History charts.
public enum ChartLine: Sendable, Hashable, CaseIterable {
    case charge, batteryPower, systemLoad, temperature, capacity, cycles

    /// 0 for a chart's main line, 1 for the line drawn beside it (the Mac's power next to the
    /// battery's).
    public var rank: Int {
        self == .systemLoad ? 1 : 0
    }
}

/// What a Demo Mode step shows, for the tint of its symbol.
public enum DemoStepKind: Sendable, Hashable, CaseIterable {
    case charging, warning, critical, neutral
}

/// The levels of text.
public enum TextLevel: Sendable, Hashable, CaseIterable {
    case primary, secondary, tertiary
}

/// What a mark means, not what colour it is.
public enum ToneRole: Hashable, Sendable {
    /// A charge or health level: the battery's fill, the charge and maximum capacity rings.
    case level(BatteryPresentation.LevelTier)
    /// The cycle count ring.
    case cycles
    /// A capacity bar.
    case capacity(CapacityBar.Kind)
    /// A History chart line.
    case chart(ChartLine)
    /// History's bands behind the charge line: charging, and holding the charge on the adapter.
    case chargingSpan, holdingSpan
    /// The legend of those bands.
    case spanLegend
    /// The channel under a ring.
    case track
    /// A rule between groups.
    case hairline
    /// The accent on content, such as the checkmark of the choice in use.
    case accent
    /// A note that needs attention: the Demo badge, a problem's symbol.
    case warning
    /// A symbol drawn over a level fill: the charging bolt.
    case onLevelFill
    /// A Demo Mode step's symbol.
    case demoStep(DemoStepKind)
    /// Text.
    case text(TextLevel)

    /// Every role, for tests and previews.
    public static let all: [ToneRole] = {
        var roles: [ToneRole] = [
            .cycles, .chargingSpan, .holdingSpan, .spanLegend, .track, .hairline, .accent, .warning, .onLevelFill,
        ]
        roles += [BatteryPresentation.LevelTier.normal, .low, .critical].map(ToneRole.level)
        roles += CapacityBar.Kind.allCases.map(ToneRole.capacity)
        roles += ChartLine.allCases.map(ToneRole.chart)
        roles += DemoStepKind.allCases.map(ToneRole.demoStep)
        roles += TextLevel.allCases.map(ToneRole.text)
        return roles
    }()
}

/// A system colour by name; the app maps it to SwiftUI's, which adapts to Light, Dark and
/// Increase Contrast.
public enum SystemColor: Sendable, Equatable, CaseIterable {
    case green, orange, red, teal, blue, gray
}

/// A level of a hierarchical style.
public enum HierarchicalLevel: Sendable, Equatable {
    case primary, secondary, tertiary, quaternary
}

/// A resolved tone.
public enum Tone: Equatable, Sendable {
    /// A system colour at an opacity.
    case system(SystemColor, opacity: Double)
    /// The accent colour the person chose.
    case accent
    /// A level of the current foreground style (`.primary`, `.secondary`, …).
    case hierarchical(HierarchicalLevel)
    /// A level of the system fill (`.fill.secondary`, …).
    case fill(HierarchicalLevel)
    /// The system separator.
    case separator
    /// White at an opacity: Clear's marks.
    case white(opacity: Double)
    /// An opaque grey, from 0 (black) to 1 (white).
    case gray(white: Double)

    /// Whether the tone carries a hue, which Clear never shows.
    public var hasHue: Bool {
        switch self {
        case .system(let color, _): color != .gray
        case .accent: true
        case .hierarchical, .fill, .separator, .white, .gray: false
        }
    }
}

/// Clear's mark for a warning: a solid white capsule with dark text and a symbol, as the clear
/// Home Screen turns red badges white.
public enum ToneBadge: Sendable, Equatable {
    case none, inverted

    /// The symbol in the badge, before its text.
    public static let symbolName = "exclamationmark.triangle.fill"
}

/// Answers each ``ToneRole`` for a window's ``ToneStyle``.
public struct ToneMap: Sendable, Equatable {
    public let style: ToneStyle
    /// Translucent and Clear: the window is one glass sheet, so tracks get a defined channel and
    /// no text uses the tertiary level.
    public let onGlassSheet: Bool

    public init(style: ToneStyle, onGlassSheet: Bool = false) {
        self.style = style
        self.onGlassSheet = onGlassSheet
    }

    /// The colours of an opaque window, and of every window that follows no style.
    public static let standard = ToneMap(style: .color)

    /// Clear's neutral tint for system controls (≈ #636366): white labels on it stay readable,
    /// where a white tint would leave white on white.
    public static let graphite = 0.39
    /// The dark of the inverted badge's text and of a symbol over a white fill (≈ #1C1C20).
    public static let ink = 0.11

    public var isMonochrome: Bool {
        style == .monochrome
    }

    public func tone(_ role: ToneRole) -> Tone {
        switch style {
        case .color: colorTone(role)
        case .monochrome: monochromeTone(role)
        }
    }

    /// The dash pattern of a chart line by its rank: solid in colour, where hue tells the lines
    /// apart; dashed and dotted lines after the first in monochrome.
    public func dash(forSeries rank: Int) -> [Double] {
        guard isMonochrome else { return [] }
        switch rank {
        case ...0: return []
        case 1: return [4, 3]
        default: return [1, 3]
        }
    }

    public func dash(for line: ChartLine) -> [Double] {
        dash(forSeries: line.rank)
    }

    /// Whether a level shows Clear's inverted badge: low and critical levels in monochrome. In
    /// colour the level's colour and its text already say it.
    public func badge(for tier: BatteryPresentation.LevelTier) -> ToneBadge {
        isMonochrome && tier != .normal ? .inverted : .none
    }

    /// The tint for system controls (the selected segment, a prominent button): `nil` keeps the
    /// accent colour; monochrome gives the neutral graphite, never white.
    public var controlTint: Tone? {
        isMonochrome ? .gray(white: Self.graphite) : nil
    }

    /// Clear's glass pieces (the battery's fill, ring arcs): a vertical gradient from just above
    /// the tone's opacity at the top to 15 points below it at the bottom. `nil` in colour and for
    /// tones that aren't white.
    public func pieceGradient(_ tone: Tone) -> (top: Double, bottom: Double)? {
        guard isMonochrome, case .white(let opacity) = tone else { return nil }
        return (min(1, opacity + 0.02), max(0, opacity - 0.15))
    }

    /// The glass piece of a level fill or a ring arc. Every level, and the cycle count, is the
    /// same white in monochrome, so one piece serves them all.
    public var levelPiece: (top: Double, bottom: Double)? {
        pieceGradient(tone(.level(.normal)))
    }

    // MARK: Colour

    private func colorTone(_ role: ToneRole) -> Tone {
        switch role {
        case .level(let tier):
            switch tier {
            case .normal: .system(.green, opacity: 1)
            case .low: .system(.orange, opacity: 1)
            case .critical: .system(.red, opacity: 1)
            }
        case .cycles: .system(.blue, opacity: 1)
        case .capacity(let kind):
            switch kind {
            case .remaining: .system(.green, opacity: 1)
            case .fullCharge: .system(.teal, opacity: 1)
            case .design: .system(.gray, opacity: 1)
            }
        case .chart(let line):
            switch line {
            case .charge, .capacity: .system(.green, opacity: 1)
            case .batteryPower, .cycles: .system(.blue, opacity: 1)
            case .systemLoad, .temperature: .system(.orange, opacity: 1)
            }
        case .chargingSpan: .system(.green, opacity: 0.16)
        case .holdingSpan: .system(.green, opacity: 0.08)
        case .spanLegend: .system(.green, opacity: 0.6)
        case .track: onGlassSheet ? .fill(.secondary) : .hierarchical(.quaternary)
        case .hairline: .separator
        case .accent: .accent
        case .warning: .system(.orange, opacity: 1)
        case .onLevelFill: .white(opacity: 1)
        case .demoStep(let kind):
            switch kind {
            case .charging: .system(.green, opacity: 1)
            case .warning: .system(.orange, opacity: 1)
            case .critical: .system(.red, opacity: 1)
            case .neutral: .accent
            }
        case .text(let level):
            switch level {
            case .primary: .hierarchical(.primary)
            case .secondary: .hierarchical(.secondary)
            case .tertiary: onGlassSheet ? .hierarchical(.secondary) : .hierarchical(.tertiary)
            }
        }
    }

    // MARK: Monochrome

    /// Opacity steps for fills and lines: the first, second and third of a kind.
    private static let fillSteps = [0.95, 0.66, 0.40]

    private func monochromeTone(_ role: ToneRole) -> Tone {
        let first = Self.fillSteps[0]
        let second = Self.fillSteps[1]
        switch role {
        case .level, .cycles, .accent, .warning:
            return .white(opacity: first)
        case .capacity(let kind):
            switch kind {
            case .remaining: return .white(opacity: first)
            case .fullCharge: return .white(opacity: second)
            case .design: return .white(opacity: Self.fillSteps[2])
            }
        case .chart(let line):
            return .white(opacity: Self.fillSteps[min(line.rank, Self.fillSteps.count - 1)])
        case .chargingSpan: return .white(opacity: 0.10)
        case .holdingSpan: return .white(opacity: 0.05)
        case .spanLegend: return .white(opacity: 0.82)
        case .track: return .white(opacity: 0.24)
        case .hairline: return .white(opacity: 0.34)
        case .onLevelFill: return .gray(white: Self.ink)
        case .demoStep(let kind):
            switch kind {
            case .charging: return .white(opacity: first)
            case .warning, .critical: return .white(opacity: second)
            case .neutral: return .white(opacity: 0.82)
            }
        case .text(let level):
            return .white(opacity: level == .primary ? 0.96 : 0.82)
        }
    }
}
