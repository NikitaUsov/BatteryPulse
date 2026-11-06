import Foundation
import Testing

@testable import BatteryCore

@Suite struct SettingsPageFitTests {
    /// A MacBook Air's built-in display at its default resolution, 956 points tall, without the
    /// menu bar and a Dock at the bottom.
    static let air: Double = 956 - 37 - 75
    /// A taller external display.
    static let external: Double = 1440 - 25 - 75

    @Test(arguments: [SettingsPageFit.settings, .welcome])
    func capIsTheScreenLessTheWindowAroundThePage(fit: SettingsPageFit) {
        #expect(fit.cap(visibleHeights: [Self.air]) == Self.air - fit.chrome - SettingsPageFit.margin)
    }

    @Test func thePageKeepsItsOwnHeightBelowTheCap() {
        let cap = SettingsPageFit.settings.cap(visibleHeights: [Self.air])
        for ideal in [120.0, 480, cap - 1, cap] {
            #expect(SettingsPageFit.height(ideal: ideal, cap: cap) == ideal)
        }
    }

    @Test func aTallerPageTakesTheCap() {
        let cap = SettingsPageFit.settings.cap(visibleHeights: [Self.air])
        for ideal in [cap + 1, 1_200, 4_000] {
            #expect(SettingsPageFit.height(ideal: ideal, cap: cap) == cap)
        }
    }

    @Test func theWindowAtTheCapFitsTheScreen() {
        for fit in [SettingsPageFit.settings, .welcome] {
            let cap = fit.cap(visibleHeights: [Self.air])
            #expect(cap + fit.chrome < Self.air)
            #expect(cap >= SettingsPageFit.floor)
        }
    }

    @Test func theShortestScreenWins() {
        let fit = SettingsPageFit.settings
        let alone = fit.cap(visibleHeights: [Self.air])
        #expect(fit.cap(visibleHeights: [Self.external, Self.air]) == alone)
        #expect(fit.cap(visibleHeights: [Self.air, Self.external]) == alone)
        #expect(fit.cap(visibleHeights: [Self.external]) > alone)
    }

    @Test(arguments: [SettingsPageFit.settings, .welcome])
    func aTinyScreenGivesTheFloor(fit: SettingsPageFit) {
        #expect(fit.cap(visibleHeights: [300]) == SettingsPageFit.floor)
        #expect(fit.cap(visibleHeights: [fit.chrome]) == SettingsPageFit.floor)
        // The floor holds for the shortest of several screens too.
        #expect(fit.cap(visibleHeights: [Self.air, 240]) == SettingsPageFit.floor)
    }

    @Test func theWelcomeWindowLeavesThePageLessRoom() {
        let settings = SettingsPageFit.settings.cap(visibleHeights: [Self.air])
        let welcome = SettingsPageFit.welcome.cap(visibleHeights: [Self.air])
        #expect(welcome < settings)
        #expect(settings - welcome == SettingsPageFit.welcome.chrome - SettingsPageFit.settings.chrome)
    }

    @Test func noScreenMeansNoCap() {
        let fit = SettingsPageFit.settings
        #expect(fit.cap(visibleHeights: []) == .infinity)
        #expect(SettingsPageFit.height(ideal: 1_500, cap: fit.cap(visibleHeights: [])) == 1_500)
        // A height that isn't a positive number is no screen.
        #expect(fit.cap(visibleHeights: [0, -10, .nan, .infinity]) == .infinity)
        #expect(fit.cap(visibleHeights: [.nan, Self.air, 0]) == fit.cap(visibleHeights: [Self.air]))
    }
}
