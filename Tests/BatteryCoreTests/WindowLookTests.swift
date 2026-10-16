import Testing

@testable import BatteryCore

@Suite struct WindowLookTests {
    private func policy(
        _ look: WindowLook, reduceTransparency: Bool = false, increaseContrast: Bool = false
    ) -> WindowLookPolicy {
        WindowLookPolicy(setting: look, reduceTransparency: reduceTransparency, increaseContrast: increaseContrast)
    }

    @Test func defaultIsStandard() {
        #expect(WindowLook(stored: nil) == .standard)
        #expect(WindowLook(stored: "bogus") == .standard)
        #expect(WindowLook(stored: "") == .standard)
        #expect(WindowLook(stored: "clear") == .clear)
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
            #expect(!policy.allowsTertiaryText)
            #expect(policy.dividesGroupsWithHairlines)
            #expect(policy.hidesFormBackground)
            #expect(policy.clearsFormRows)
        }
        let standard = policy(.standard)
        #expect(!standard.usesGlassSheet)
        #expect(!standard.boldNumerals)
        #expect(standard.allowsTertiaryText)
        #expect(!standard.dividesGroupsWithHairlines)
        #expect(!standard.hidesFormBackground)
        #expect(!standard.clearsFormRows)
        // Frosted only drops the form background: its sections stay lighter layers.
        let frosted = policy(.frosted)
        #expect(frosted.hidesFormBackground)
        #expect(!frosted.clearsFormRows)
        #expect(!frosted.boldNumerals)
        #expect(frosted.allowsTertiaryText)
        #expect(!frosted.dividesGroupsWithHairlines)
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
        // wash left it unreadable over a bright desktop on the M5.
        #expect(policy(.clear).sheetTint(systemDark: true) == Tint(white: 0.03, opacity: 0.32))
        #expect(policy(.clear).sheetTint(systemDark: false) == Tint(white: 0.03, opacity: 0.4))
        for dark in [false, true] {
            #expect(policy(.standard).sheetTint(systemDark: dark) == nil)
            #expect(policy(.frosted).sheetTint(systemDark: dark) == nil)
            #expect(policy(.clear, reduceTransparency: true).sheetTint(systemDark: dark) == nil)
        }
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
