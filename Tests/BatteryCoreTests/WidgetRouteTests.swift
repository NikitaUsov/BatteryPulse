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

    /// Schemes and hosts are case-insensitive, as the system may hand them over either way.
    @Test func schemeAndHostIgnoreCase() throws {
        let url = try #require(URL(string: "BatteryPulse://Page/power"))
        #expect(WidgetRoute(url: url)?.page == .power)
    }
}
