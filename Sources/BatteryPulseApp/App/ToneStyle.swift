#if os(macOS)
import AppKit
import BatteryCore
import SwiftUI

// The bridge from BatteryCore's tone map to SwiftUI. Views in `Main/` never name a system
// colour: they ask for a role (`tones.color(.level(tier))`, `tones.style(.track)`) and get
// today's colour in Standard, Frosted and Translucent, or Clear's white. This file is the one
// place that maps the names to SwiftUI colours; `MotionGuardTests` keeps colour names out of
// `Main/`, `App/Localized.swift` and `App/DemoController.swift`, so nothing bypasses Clear.

extension EnvironmentValues {
    /// The tones of this window's content. `.windowLook()` sets it on the main and compact
    /// windows; every other window (Settings, the menu bar panel) keeps ``ToneMap/standard``.
    @Entry var tones = ToneMap.standard
}

extension ToneMap {
    /// The role's tone as a colour, for APIs that take one (`tint(_:)`, a ring's or glyph's tint).
    func color(_ role: ToneRole) -> Color {
        tone(role).color
    }

    /// The role's tone as a shape style. Hierarchical tones stay hierarchical, so they render
    /// vibrant on materials and follow the window's foreground levels.
    func style(_ role: ToneRole) -> AnyShapeStyle {
        tone(role).style
    }

    /// Clear's glass piece for a level fill or a ring arc: white fading downward. `nil` in
    /// colour, where the fill keeps its tint.
    var levelPieceStyle: AnyShapeStyle? {
        levelPiece.map { piece in
            AnyShapeStyle(
                LinearGradient(
                    colors: [.white.opacity(piece.top), .white.opacity(piece.bottom)], startPoint: .top,
                    endPoint: .bottom))
        }
    }

    /// The tint for system controls: `nil` (the accent colour), or Clear's graphite.
    var controlTintColor: Color? {
        controlTint?.color
    }
}

extension Tone {
    var color: Color {
        switch self {
        case .system(let name, let opacity): opacity == 1 ? name.color : name.color.opacity(opacity)
        case .accent: .accentColor
        case .hierarchical(let level):
            switch level {
            case .primary: .primary
            case .secondary: .secondary
            case .tertiary: Color(nsColor: .tertiaryLabelColor)
            case .quaternary: Color(nsColor: .quaternaryLabelColor)
            }
        case .fill(let level):
            switch level {
            case .primary: Color(nsColor: .systemFill)
            case .secondary: Color(nsColor: .secondarySystemFill)
            case .tertiary: Color(nsColor: .tertiarySystemFill)
            case .quaternary: Color(nsColor: .quaternarySystemFill)
            }
        case .separator: Color(nsColor: .separatorColor)
        case .white(let opacity): opacity == 1 ? .white : .white.opacity(opacity)
        case .gray(let white): Color(white: white)
        }
    }

    var style: AnyShapeStyle {
        switch self {
        case .accent: AnyShapeStyle(.tint)
        case .hierarchical(let level):
            switch level {
            case .primary: AnyShapeStyle(.primary)
            case .secondary: AnyShapeStyle(.secondary)
            case .tertiary: AnyShapeStyle(.tertiary)
            case .quaternary: AnyShapeStyle(.quaternary)
            }
        case .fill(let level):
            switch level {
            case .primary: AnyShapeStyle(.fill)
            case .secondary: AnyShapeStyle(.fill.secondary)
            case .tertiary: AnyShapeStyle(.fill.tertiary)
            case .quaternary: AnyShapeStyle(.fill.quaternary)
            }
        case .separator: AnyShapeStyle(.separator)
        case .system, .white, .gray: AnyShapeStyle(color)
        }
    }
}

extension SystemColor {
    var color: Color {
        switch self {
        case .green: .green
        case .orange: .orange
        case .red: .red
        case .teal: .teal
        case .blue: .blue
        case .gray: .gray
        }
    }
}

extension BatteryPresentation.LevelTier {
    /// The level's colour where no window style applies (the menu bar panel).
    var color: Color {
        ToneMap.standard.color(.level(self))
    }
}
#endif
