import Foundation
import Testing

@testable import BatteryCore

@Suite struct ToneMapTests {
    private let color = ToneMap(style: .color)
    private let sheet = ToneMap(style: .color, onGlassSheet: true)
    private let mono = ToneMap(style: .monochrome, onGlassSheet: true)

    /// A regression test for the colours BatteryPulse drew before window styles.
    @Test func colorStyleKeepsTodaysColors() {
        #expect(color.tone(.level(.normal)) == .system(.green, opacity: 1))
        #expect(color.tone(.level(.low)) == .system(.orange, opacity: 1))
        #expect(color.tone(.level(.critical)) == .system(.red, opacity: 1))
        #expect(color.tone(.cycles) == .system(.blue, opacity: 1))
        #expect(color.tone(.capacity(.remaining)) == .system(.green, opacity: 1))
        #expect(color.tone(.capacity(.fullCharge)) == .system(.teal, opacity: 1))
        #expect(color.tone(.capacity(.design)) == .system(.gray, opacity: 1))
        #expect(color.tone(.chart(.charge)) == .system(.green, opacity: 1))
        #expect(color.tone(.chart(.batteryPower)) == .system(.blue, opacity: 1))
        #expect(color.tone(.chart(.systemLoad)) == .system(.orange, opacity: 1))
        #expect(color.tone(.chart(.temperature)) == .system(.orange, opacity: 1))
        #expect(color.tone(.chart(.capacity)) == .system(.green, opacity: 1))
        #expect(color.tone(.chart(.cycles)) == .system(.blue, opacity: 1))
        #expect(color.tone(.chargingSpan) == .system(.green, opacity: 0.16))
        #expect(color.tone(.holdingSpan) == .system(.green, opacity: 0.08))
        #expect(color.tone(.spanLegend) == .system(.green, opacity: 0.6))
        #expect(color.tone(.track) == .hierarchical(.quaternary))
        #expect(color.tone(.hairline) == .separator)
        #expect(color.tone(.accent) == .accent)
        #expect(color.tone(.warning) == .system(.orange, opacity: 1))
        #expect(color.tone(.onLevelFill) == .white(opacity: 1))
        #expect(color.tone(.demoStep(.charging)) == .system(.green, opacity: 1))
        #expect(color.tone(.demoStep(.warning)) == .system(.orange, opacity: 1))
        #expect(color.tone(.demoStep(.critical)) == .system(.red, opacity: 1))
        #expect(color.tone(.demoStep(.neutral)) == .accent)
        #expect(color.tone(.text(.secondary)) == .hierarchical(.secondary))
        #expect(color.tone(.text(.tertiary)) == .hierarchical(.tertiary))
        #expect(ToneMap.standard == color)
    }

    /// Translucent keeps the colours, with a defined channel under rings and no tertiary text.
    @Test func glassSheetChangesOnlyTracksAndTertiaryText() {
        for role in ToneRole.all where role != .track && role != .text(.tertiary) {
            #expect(sheet.tone(role) == color.tone(role), "\(role)")
        }
        #expect(sheet.tone(.track) == .fill(.secondary))
        #expect(sheet.tone(.text(.tertiary)) == .hierarchical(.secondary))
    }

    @Test(arguments: ToneRole.all)
    func monochromeHasNoHue(role: ToneRole) {
        let tone = mono.tone(role)
        #expect(!tone.hasHue, "\(role) → \(tone)")
        switch tone {
        case .white, .gray, .hierarchical, .fill, .separator: break
        case .system, .accent: Issue.record("\(role) resolves to a colour: \(tone)")
        }
    }

    @Test func monochromeOpacitySteps() {
        #expect(mono.tone(.level(.normal)) == .white(opacity: 0.95))
        #expect(mono.tone(.level(.critical)) == .white(opacity: 0.95))
        #expect(mono.tone(.chart(.batteryPower)) == .white(opacity: 0.95))
        #expect(mono.tone(.chart(.systemLoad)) == .white(opacity: 0.66))
        #expect(mono.tone(.capacity(.design)) == .white(opacity: 0.40))
        #expect(mono.tone(.track) == .white(opacity: 0.24))
        #expect(mono.tone(.hairline) == .white(opacity: 0.34))
        #expect(mono.tone(.chargingSpan) == .white(opacity: 0.10))
        #expect(mono.tone(.text(.primary)) == .white(opacity: 0.96))
        #expect(mono.tone(.text(.secondary)) == .white(opacity: 0.82))
        #expect(mono.tone(.text(.tertiary)) == .white(opacity: 0.82))
    }

    @Test func monochromeKeepsSeriesApartWithoutColor() {
        let battery = (mono.tone(.chart(.batteryPower)), mono.dash(for: .batteryPower))
        let mac = (mono.tone(.chart(.systemLoad)), mono.dash(for: .systemLoad))
        #expect(battery.0 != mac.0 || battery.1 != mac.1)
        #expect(battery.1.isEmpty)
        #expect(mac.1 == [4, 3])
        #expect(mono.dash(forSeries: 2) == [1, 3])
        #expect(Set([0, 1, 2].map { mono.dash(forSeries: $0) }).count == 3)
        // In colour hue tells the lines apart, so every line is solid and the legend unchanged.
        for line in ChartLine.allCases {
            #expect(color.dash(for: line).isEmpty)
            #expect(sheet.dash(for: line).isEmpty)
        }
    }

    @Test func capacityBarsStayOrderedInMonochrome() {
        func opacity(_ kind: CapacityBar.Kind) -> Double {
            guard case .white(let opacity) = mono.tone(.capacity(kind)) else { return -1 }
            return opacity
        }
        #expect(opacity(.remaining) > opacity(.fullCharge))
        #expect(opacity(.fullCharge) > opacity(.design))
        #expect(opacity(.design) > 0)
    }

    @Test func warningsGetTheInvertedBadgeOnlyInMonochrome() {
        #expect(mono.badge(for: .low) == .inverted)
        #expect(mono.badge(for: .critical) == .inverted)
        #expect(mono.badge(for: .normal) == .none)
        for tier in [BatteryPresentation.LevelTier.normal, .low, .critical] {
            #expect(color.badge(for: tier) == .none)
            #expect(sheet.badge(for: tier) == .none)
        }
    }

    /// Clear shows no colour, so every state other than normal needs its badge (text and a
    /// symbol), and the level itself still shows as a fill and a number.
    @Test func statesAreNeverToldByColorAlone() {
        #expect(!ToneBadge.symbolName.isEmpty)
        // Same tone for every tier: the badge and the text carry the difference.
        #expect(mono.tone(.level(.low)) == mono.tone(.level(.normal)))
        for tier in [BatteryPresentation.LevelTier.low, .critical] {
            #expect(mono.badge(for: tier) == .inverted)
        }
        // The symbol differs with the level too.
        let symbols = [5.0, 30, 55, 80, 95].map { BatteryPresentation.symbolName(percent: $0, state: .discharging) }
        #expect(Set(symbols).count == symbols.count)
    }

    /// White on the tint must stay readable: the selected sidebar row and a prominent button draw
    /// white labels on it.
    @Test func controlTintIsNeutralAndNeverWhite() throws {
        #expect(color.controlTint == nil)
        #expect(sheet.controlTint == nil)
        let tint = try #require(mono.controlTint)
        guard case .gray(let white) = tint else {
            Issue.record("not a grey: \(tint)")
            return
        }
        #expect(white < 0.5)
        #expect(Self.contrast(1, white) >= 4.5)
        #expect(!tint.hasHue)
        // The badge's ink reads on the badge's white.
        #expect(Self.contrast(0.95, ToneMap.ink) >= 7)
    }

    @Test(arguments: DemoStepKind.allCases)
    func demoStepsHaveNoHueInMonochrome(kind: DemoStepKind) {
        guard case .white = mono.tone(.demoStep(kind)) else {
            Issue.record("\(kind) → \(mono.tone(.demoStep(kind)))")
            return
        }
    }

    @Test func glassPiecesFadeDownward() throws {
        let piece = try #require(mono.pieceGradient(.white(opacity: 0.95)))
        #expect(abs(piece.top - 0.97) < 1e-9)
        #expect(abs(piece.bottom - 0.80) < 1e-9)
        #expect(mono.pieceGradient(.white(opacity: 0.99))?.top == 1)
        #expect(color.pieceGradient(.white(opacity: 0.95)) == nil)
        #expect(mono.pieceGradient(.gray(white: 0.4)) == nil)
    }

    // MARK: WCAG

    /// The contrast ratio of two opaque greys given as sRGB levels from 0 to 1.
    static func contrast(_ a: Double, _ b: Double) -> Double {
        func luminance(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let (high, low) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
        return (high + 0.05) / (low + 0.05)
    }
}

extension Tone {
    /// Whether the tone carries a hue, which Clear never shows.
    var hasHue: Bool {
        switch self {
        case .system(let color, _): color != .gray
        case .accent: true
        case .hierarchical, .fill, .separator, .white, .gray: false
        }
    }
}
