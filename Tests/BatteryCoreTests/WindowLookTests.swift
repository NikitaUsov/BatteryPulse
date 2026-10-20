import Foundation
import Testing

@testable import BatteryCore

@Suite struct WindowLookTests {
    private func policy(
        _ look: WindowLook, reduceTransparency: Bool = false, increaseContrast: Bool = false
    ) -> WindowLookPolicy {
        WindowLookPolicy(setting: look, reduceTransparency: reduceTransparency, increaseContrast: increaseContrast)
    }

    /// The setting is an `@AppStorage` with the default `.standard`, which a missing or unknown
    /// stored value reads as.
    @Test func unknownStoredValuesAreNoStyle() {
        #expect(WindowLook(rawValue: "bogus") == nil)
        #expect(WindowLook(rawValue: "") == nil)
        #expect(WindowLook(rawValue: "clear") == .clear)
    }

    /// Stored in the defaults: a rename after release would reset everyone's choice.
    @Test func rawValuesAreStable() {
        #expect(WindowLook.allCases.map(\.rawValue) == ["standard", "frosted", "translucent", "clear"])
    }

    /// The picker shows the choices in this order.
    @Test func orderRunsFromOpaqueToClear() {
        #expect(WindowLook.allCases == [.standard, .frosted, .translucent, .clear])
    }

    @Test(arguments: WindowLook.allCases)
    func effectiveFollowsSettingWithoutAccessibilityFlags(look: WindowLook) {
        let policy = policy(look)
        #expect(policy.setting == look)
        #expect(policy.effective == look)
        #expect(policy.override == nil)
        #expect(policy.showsDesktop == (look != .standard))
    }

    @Test(arguments: [WindowLook.frosted, .translucent, .clear])
    func reduceTransparencyForcesStandard(look: WindowLook) {
        let policy = policy(look, reduceTransparency: true)
        #expect(policy.effective == .standard)
        #expect(policy.setting == look)
        #expect(policy.override == .reduceTransparency)
        #expect(!policy.showsDesktop)
    }

    @Test(arguments: [WindowLook.frosted, .translucent, .clear])
    func increaseContrastForcesStandard(look: WindowLook) {
        let policy = policy(look, increaseContrast: true)
        #expect(policy.effective == .standard)
        #expect(policy.override == .increaseContrast)
    }

    /// The footer names one setting.
    @Test func reduceTransparencyWinsOverIncreaseContrastInTheReason() {
        #expect(policy(.clear, reduceTransparency: true, increaseContrast: true).override == .reduceTransparency)
    }

    @Test func standardIsNeverOverridden() {
        for reduce in [false, true] {
            for contrast in [false, true] {
                let policy = policy(.standard, reduceTransparency: reduce, increaseContrast: contrast)
                #expect(policy.override == nil)
                #expect(policy.effective == .standard)
            }
        }
        #expect(WindowLookPolicy.standard == policy(.standard))
    }

    @Test func groupSurfacePerStyle() {
        #expect(WindowLook.allCases.map { policy($0).groupSurface } == [.card, .frostLayer, .none, .none])
    }

    @Test func backgroundPerStyle() {
        #expect(WindowLook.allCases.map { policy($0).background } == [.system, .material, .glassSheet, .glassSheet])
        for look in WindowLook.allCases {
            #expect(policy(look, reduceTransparency: true).background == .system)
            #expect(policy(look, increaseContrast: true).background == .system)
        }
    }

    @Test func sheetStylesShareTheLayoutRules() {
        for look in [WindowLook.translucent, .clear] {
            let policy = policy(look)
            #expect(policy.usesGlassSheet)
            #expect(policy.boldNumerals)
            // Tertiary text is too faint on the glass: it reads as secondary.
            #expect(policy.tones.tone(.text(.tertiary)) == policy.tones.tone(.text(.secondary)))
            #expect(policy.groupSurface == .none)
            #expect(policy.hidesFormBackground)
            #expect(policy.clearsFormRows)
        }
        let standard = policy(.standard)
        #expect(!standard.usesGlassSheet)
        #expect(!standard.boldNumerals)
        #expect(standard.tones.tone(.text(.tertiary)) != standard.tones.tone(.text(.secondary)))
        #expect(standard.groupSurface == .card)
        #expect(!standard.hidesFormBackground)
        #expect(!standard.clearsFormRows)
        // Frosted only drops the form background: its sections stay lighter layers.
        let frosted = policy(.frosted)
        #expect(frosted.hidesFormBackground)
        #expect(!frosted.clearsFormRows)
        #expect(!frosted.boldNumerals)
        #expect(frosted.tones.tone(.text(.tertiary)) != frosted.tones.tone(.text(.secondary)))
        #expect(frosted.groupSurface == .frostLayer)
    }

    @Test func onlyClearIsMonochromeAndDark() {
        for look in WindowLook.allCases {
            let policy = policy(look)
            #expect(policy.forcesDarkAppearance == (look == .clear))
            #expect(policy.shadowsContent == (look == .clear))
            #expect((policy.toneStyle == .monochrome) == (look == .clear))
            #expect(policy.tones.style == policy.toneStyle)
            #expect(policy.tones.onGlassSheet == policy.usesGlassSheet)
        }
    }

    /// The maintainer's choice: Frosted's frost stays when its window is inactive.
    @Test func onlyFrostedKeepsItsMaterialActive() {
        #expect(WindowLook.allCases.filter { policy($0).keepsMaterialActive } == [.frosted])
        #expect(!policy(.frosted, reduceTransparency: true).keepsMaterialActive)
    }

    @Test func sheetTintPerStyleAndAppearance() {
        typealias Tint = WindowLookPolicy.Tint
        #expect(policy(.translucent).sheetTint(systemDark: true) == Tint(white: 0, opacity: 0.45))
        #expect(policy(.translucent).sheetTint(systemDark: false) == Tint(white: 1, opacity: 0.45))
        // Clear's content is white in both appearances, so its dimming is dark in both: a white
        // wash left it unreadable over a bright desktop on the M5, and a lighter dimming over a
        // white window behind it.
        #expect(policy(.clear).sheetTint(systemDark: true) == Tint(white: 0.03, opacity: 0.65))
        #expect(policy(.clear).sheetTint(systemDark: false) == Tint(white: 0.03, opacity: 0.65))
        for dark in [false, true] {
            #expect(policy(.standard).sheetTint(systemDark: dark) == nil)
            #expect(policy(.frosted).sheetTint(systemDark: dark) == nil)
            #expect(policy(.clear, reduceTransparency: true).sheetTint(systemDark: dark) == nil)
        }
    }

    /// The worst case behind a Clear window is a white one (a web page, a document). Seen through
    /// the glass, the white is dimmed by the sheet's tint; Clear's content is white on top of that.
    /// The model blends in sRGB, as the sheet is composited, and assumes the dark appearance's
    /// label alphas: white at 85 % for primary text (`labelColor`) and 55 % for secondary text
    /// (`secondaryLabelColor`). WCAG asks for 4.5:1 and 3:1. It ignores the glass's own frost and
    /// Clear's shadow and halo, which only help.
    @Test(arguments: [false, true])
    func clearKeepsTextReadableOverAWhiteWindow(systemDark: Bool) throws {
        let tint = try #require(policy(.clear).sheetTint(systemDark: systemDark))
        func over(_ backdrop: Double, white: Double, alpha: Double) -> Double {
            white * alpha + backdrop * (1 - alpha)
        }
        func luminance(_ srgb: Double) -> Double {
            srgb <= 0.04045 ? srgb / 12.92 : pow((srgb + 0.055) / 1.055, 2.4)
        }
        func contrast(_ a: Double, _ b: Double) -> Double {
            let (lighter, darker) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
            return (lighter + 0.05) / (darker + 0.05)
        }
        let window = over(1, white: tint.white, alpha: tint.opacity)
        let primary = over(window, white: 1, alpha: 0.85)
        let secondary = over(window, white: 1, alpha: 0.55)
        #expect(contrast(primary, window) >= 4.5)
        #expect(contrast(secondary, window) >= 3)
    }

    /// While a window minimizes, sits in the Dock and is restored, the sheet's place is a plain
    /// fill of the same tint: the animation shows only the window's own layers, without the
    /// desktop the glass samples.
    @Test(arguments: [false, true])
    func minimizingSwapsTheGlassForAStillFill(systemDark: Bool) throws {
        typealias Surface = WindowLookPolicy.SheetSurface
        for look in [WindowLook.translucent, .clear] {
            let policy = policy(look)
            let tint = try #require(policy.sheetTint(systemDark: systemDark))
            #expect(policy.sheetSurface(systemDark: systemDark, isMinimized: false) == Surface.glass(tint: tint))
            #expect(policy.sheetSurface(systemDark: systemDark, isMinimized: true) == Surface.fill(tint))
            // Never an opaque frame, and never nothing: the desktop shows through a dimmed sheet.
            #expect(tint.opacity > 0 && tint.opacity < 1)
        }
        // Standard and Frosted have no sheet, so minimizing changes nothing.
        for look in [WindowLook.standard, .frosted] {
            for minimized in [false, true] {
                #expect(policy(look).sheetSurface(systemDark: systemDark, isMinimized: minimized) == nil)
            }
        }
        #expect(policy(.clear, reduceTransparency: true).sheetSurface(systemDark: systemDark, isMinimized: true) == nil)
    }

    @Test func onlyClearTreatsItsContent() throws {
        for look in [WindowLook.standard, .frosted, .translucent] {
            #expect(policy(look).contentTreatment(systemDark: false) == nil)
            #expect(policy(look).contentTreatment(systemDark: true) == nil)
        }
        #expect(policy(.clear, increaseContrast: true).contentTreatment(systemDark: true) == nil)
        let light = try #require(policy(.clear).contentTreatment(systemDark: false))
        let dark = try #require(policy(.clear).contentTreatment(systemDark: true))
        #expect(light.haloOpacity == 0.55)
        #expect(dark.haloOpacity == 0.44)
        // A tight shadow under a soft halo, the same in both appearances.
        #expect(light.shadowRadius < light.haloRadius)
        #expect(light.shadowOpacity == dark.shadowOpacity)
    }

    /// Standard under an accessibility setting is the full colour window, with nothing of Clear.
    @Test func accessibilityOverrideDropsClearsExtras() {
        let policy = policy(.clear, reduceTransparency: true)
        #expect(policy.toneStyle == .color)
        #expect(!policy.forcesDarkAppearance)
        #expect(!policy.shadowsContent)
        #expect(policy.groupSurface == .card)
        #expect(policy.tones == .standard)
    }
}
