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
                == "io.github.nikitausov.batterypulse://page/device/0123456789abcdef0123456789abcdef")
    }

    @Test func widgetsNeverOpenTheDeveloperPagesOrTheDemo() {
        #expect(WidgetRoute(page: .developer) == nil)
        #expect(WidgetRoute(page: .demo) == nil)
        #expect(WidgetRoute(page: .device(.demo)) == nil)
    }

    @Test(arguments: [
        "io.github.nikitausov.batterypulse://page/developer",
        "io.github.nikitausov.batterypulse://page/demo",
        "io.github.nikitausov.batterypulse://page/device/demo",
        "io.github.nikitausov.batterypulse://page/device/NOT-A-KEY",
        "io.github.nikitausov.batterypulse://page/device/",
        "io.github.nikitausov.batterypulse://page/device:0123456789abcdef0123456789abcdef",
        "io.github.nikitausov.batterypulse://page/settings",
        "io.github.nikitausov.batterypulse://page/",
        "io.github.nikitausov.batterypulse://page",
        "io.github.nikitausov.batterypulse://page/power/extra",
        "io.github.nikitausov.batterypulse://page/power?action=reset",
        "io.github.nikitausov.batterypulse://page/power#top",
        "io.github.nikitausov.batterypulse://user@page/power",
        "io.github.nikitausov.batterypulse://page:80/power",
        "io.github.nikitausov.batterypulse://open/power",
        "io.github.nikitausov.batterypulse:/page/power",
        "batterypulse://page/power",
        "https://page/power",
        "file:///page/power",
    ])
    func otherURLsAreRejected(_ string: String) throws {
        let url = try #require(URL(string: string))
        #expect(WidgetRoute(url: url) == nil)
    }

    /// Schemes and hosts are case-insensitive, as the system may hand them over either way.
    @Test func schemeAndHostIgnoreCase() throws {
        let url = try #require(URL(string: "IO.GitHub.NikitaUsov.BatteryPulse://Page/power"))
        #expect(WidgetRoute(url: url)?.page == .power)
    }
}
