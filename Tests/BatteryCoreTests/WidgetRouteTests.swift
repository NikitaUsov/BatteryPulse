import Foundation
import Testing

@testable import BatteryCore

struct WidgetRouteTests {
    static let key = DeviceKey("0123456789abcdef0123456789abcdef")!

    static var opened: [PageID] {
        [.overview, .power, .health, .history, .devices, .accessories, .device(key)]
    }

    @Test func pageIDsRoundTrip() {
        for page in PageID.named + [.device(Self.key), .device(.demo)] {
            #expect(PageID(rawValue: page.rawValue) == page)
        }
        #expect(PageID(rawValue: "device:\(Self.key.rawValue)") == .device(Self.key))
        #expect(PageID(rawValue: "device:") == nil)
        #expect(PageID(rawValue: "device:UPPER") == nil)
        #expect(PageID(rawValue: "Overview") == nil)
        #expect(PageID(rawValue: "") == nil)
    }

    @Test func routesRoundTrip() throws {
        for page in Self.opened {
            let route = try #require(WidgetRoute(page: page))
            #expect(WidgetRoute(url: route.url) == route)
        }
        #expect(
            WidgetRoute(page: .device(Self.key))?.url.absoluteString
                == "batterypulse://page/device/0123456789abcdef0123456789abcdef")
    }

    /// The URL a click on the medium widget delivered to the app on the M5, with no scheme
    /// registered.
    @Test func theURLAClickDeliveredOpensOverview() throws {
        let url = try #require(URL(string: "batterypulse://page/overview"))
        #expect(WidgetRoute(url: url)?.page == .overview)
        #expect(WidgetRoute(page: .overview)?.url == url)
    }

    @Test func widgetsNeverOpenTheDeveloperPagesOrTheDemo() {
        #expect(WidgetRoute(page: .developer) == nil)
        #expect(WidgetRoute(page: .demo) == nil)
        #expect(WidgetRoute(page: .device(.demo)) == nil)
    }

    @Test(arguments: [
        "batterypulse://page/developer",
        "batterypulse://page/demo",
        "batterypulse://page/device/demo",
        "batterypulse://page/device/NOT-A-KEY",
        "batterypulse://page/device/",
        "batterypulse://page/device:0123456789abcdef0123456789abcdef",
        "batterypulse://page/settings",
        "batterypulse://page/",
        "batterypulse://page",
        "batterypulse://page/power/extra",
        "batterypulse://page/power?action=reset",
        "batterypulse://page/power#top",
        "batterypulse://user@page/power",
        "batterypulse://page:80/power",
        "batterypulse://open/power",
        "batterypulse:/page/power",
        "io.github.nikitausov.batterypulse://page/power",
        "https://page/power",
        "file:///page/power",
    ])
    func otherURLsAreRejected(_ string: String) throws {
        let url = try #require(URL(string: string))
        #expect(WidgetRoute(url: url) == nil)
    }

    /// The manifest once both kinds take a configuration intent.
    static let configurable = WidgetIntentManifest(kinds: [
        .init(.battery, families: [.small, .medium], intent: .init(type: "BatteryWidgetIntent", parameters: [])),
        .init(
            .accessories, families: [.small, .medium, .large],
            intent: .init(type: "AccessoriesWidgetIntent", parameters: [])),
    ])

    /// A click without a URL opens the clicked kind's page, for every intent that ships and every
    /// one planned.
    @Test(arguments: [WidgetIntentManifest.shipping, configurable])
    func eachIntentOpensItsKindsPage(_ manifest: WidgetIntentManifest) throws {
        for declared in manifest.kinds {
            guard let intent = declared.intent else { continue }
            let kind = try #require(WidgetKindID(rawValue: declared.kind))
            #expect(WidgetRoute(activityType: intent.type, manifest: manifest)?.page == kind.page)
        }
    }

    @Test func theKindsPages() {
        #expect(WidgetRoute(activityType: "BatteryWidgetIntent", manifest: Self.configurable)?.page == .overview)
        #expect(
            WidgetRoute(activityType: "AccessoriesWidgetIntent", manifest: Self.configurable)?.page == .accessories)
        #expect(WidgetKindID.allCases.map(\.page) == [.overview, .accessories])
        // The app's route, over the intents that ship.
        #expect(WidgetRoute(activityType: "BatteryWidgetIntent")?.page == .overview)
        #expect(WidgetRoute(activityType: "AccessoriesWidgetIntent")?.page == .accessories)
    }

    /// The app's route names the intents the manifest ships, kind by kind, so it opens a page for
    /// exactly the activities the manifest's route does. A widget package that ships an intent
    /// adds its type name to both.
    @Test func theIntentTypesAreTheShippingManifests() throws {
        for kind in WidgetKindID.allCases {
            let declared = WidgetIntentManifest.shipping.kinds.first { $0.kind == kind.rawValue }
            #expect(kind.intentType == declared?.intent?.type, "\(kind)")
            if let type = kind.intentType {
                #expect(WidgetRoute(activityType: type) == WidgetRoute(activityType: type, manifest: .shipping))
            }
        }
    }

    /// Only an intent's own type name opens a page: not another app's, not a kind string, not a
    /// near miss.
    @Test(arguments: [
        "", "SpikeWidgetIntent", "batterywidgetintent", "BatteryWidgetIntent ",
        "BatteryPulseWidget.BatteryWidgetIntent",
        "io.github.nikitausov.BatteryPulse.battery", "NSUserActivityTypeBrowsingWeb",
    ])
    func otherActivityTypesAreRejected(_ type: String) {
        #expect(WidgetRoute(activityType: type, manifest: Self.configurable) == nil)
        #expect(WidgetRoute(activityType: type) == nil)
    }

    /// A static widget has no intent, so no activity type opens its page.
    @Test func aStaticKindHasNoActivityRoute() {
        let manifest = WidgetIntentManifest(kinds: [.init(.battery, families: [.small, .medium])])
        #expect(WidgetRoute(activityType: "BatteryWidgetIntent", manifest: manifest) == nil)
    }

    /// Schemes and hosts are case-insensitive, as the system may hand them over either way.
    @Test func schemeAndHostIgnoreCase() throws {
        let url = try #require(URL(string: "BatteryPulse://Page/power"))
        #expect(WidgetRoute(url: url)?.page == .power)
    }
}
