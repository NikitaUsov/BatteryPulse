import Foundation
import Testing

@testable import BatteryCore

@Suite struct MenuBarContentTests {
    private let english = BatteryFormatter(locale: Locale(identifier: "en_US"))

    private func title(_ content: MenuBarContent, _ s: BatterySnapshot?) -> String {
        content.title(for: s, formatter: english).replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    @Test func textPartsKeepTheirOrder() throws {
        let s = try Fixture.m5OnBatterySMC.snapshot()
        let all = MenuBarContent(showsIcon: true, showsCharge: true, showsPower: true, showsTemperature: true)
        #expect(all.items == [.icon, .charge, .power, .temperature])
        #expect(title(all, s) == "47% · −8.3 W · 34 °C")
        #expect(title(MenuBarContent(showsCharge: true), s) == "47%")
        #expect(title(MenuBarContent(showsCharge: false, showsPower: true), s) == "−8.3 W")
        #expect(title(MenuBarContent(showsCharge: false, showsTemperature: true), s) == "34 °C")
        #expect(title(MenuBarContent(showsPower: true, showsTemperature: true), s) == "47% · −8.3 W · 34 °C")
        #expect(
            title(MenuBarContent(showsCharge: false, showsPower: true, showsTemperature: true), s) == "−8.3 W · 34 °C")
        #expect(title(MenuBarContent(showsCharge: false), s) == "")
    }

    @Test func missingValuesAreLeftOut() throws {
        // The first M5 capture has no registry children, so no temperature.
        let s = try Fixture.m5OnBattery.snapshot()
        #expect(s.temperatureCelsius == nil)
        #expect(title(MenuBarContent(showsTemperature: true), s) == "70%")
        let temperatureOnly = MenuBarContent(showsIcon: false, showsCharge: false, showsTemperature: true)
        #expect(title(temperatureOnly, s) == "")
        // Nothing to show yet, so the icon stands in.
        #expect(temperatureOnly.showsIcon(title: ""))
        #expect(title(.default, nil) == "")
    }

    @Test func titleFollowsLocale() throws {
        let russian = BatteryFormatter(locale: Locale(identifier: "ru_RU")) { $0 == .watts ? "W-ru" : "?" }
        let content = MenuBarContent(showsPower: true, showsTemperature: true)
        let title = content.title(for: try Fixture.m5OnBatterySMC.snapshot(), formatter: russian)
        #expect(title.replacingOccurrences(of: "\u{00A0}", with: " ") == "47 % · −8,3 W-ru · 34 °C")
    }

    @Test func atLeastOnePartShows() {
        let nothing = MenuBarContent(showsIcon: false, showsCharge: false, showsPower: false, showsTemperature: false)
        #expect(nothing.items == [.icon])
        #expect(nothing.normalized == MenuBarContent(showsIcon: true, showsCharge: false))
        #expect(nothing.showsIcon(title: ""))
        #expect(!nothing.isOnlyItem(.icon))

        let chargeOnly = MenuBarContent(showsIcon: false, showsCharge: true)
        #expect(chargeOnly.items == [.charge])
        #expect(!chargeOnly.showsIcon(title: "70%"))
        #expect(chargeOnly.isOnlyItem(.charge))
        #expect(!chargeOnly.isOnlyItem(.icon))
        #expect(!MenuBarContent.default.isOnlyItem(.icon))
        #expect(MenuBarContent(showsCharge: false).isOnlyItem(.icon))
    }

    @Test func itemsRoundTrip() {
        for mask in 0..<16 {
            let items = Set(MenuBarItem.allCases.enumerated().filter { mask & (1 << $0.offset) != 0 }.map(\.element))
            let content = MenuBarContent(items: items)
            #expect(Set(MenuBarItem.allCases.filter(content.isOn)) == items)
            #expect(content.normalized.items == content.items)
        }
    }

    @Test func onlyPowerNeedsPolling() {
        #expect(MenuBarContent.default.liveRefreshInterval == nil)
        #expect(MenuBarContent(showsTemperature: true).liveRefreshInterval == nil)
        #expect(MenuBarContent(showsPower: true).liveRefreshInterval == .seconds(10))
        #expect(
            MenuBarContent(showsIcon: false, showsCharge: false, showsPower: true).liveRefreshInterval == .seconds(10))
    }

    @Test(
        arguments: [
            ("percent" as String?, "standard" as String?, MenuBarContent(showsIcon: true, showsCharge: true)),
            ("power", "standard", MenuBarContent(showsIcon: true, showsCharge: false, showsPower: true)),
            ("percentAndPower", "large", MenuBarContent(showsIcon: true, showsCharge: true, showsPower: true)),
            ("iconOnly", "standard", MenuBarContent(showsIcon: true, showsCharge: false)),
            ("percent", "hidden", MenuBarContent(showsIcon: false, showsCharge: true)),
            ("percentAndPower", "hidden", MenuBarContent(showsIcon: false, showsCharge: true, showsPower: true)),
            // Icon only with the icon hidden still showed the icon.
            ("iconOnly", "hidden", MenuBarContent(showsIcon: true, showsCharge: false)),
            // Only one of the two was ever changed: the other had its default.
            (nil, "hidden", MenuBarContent(showsIcon: false, showsCharge: true)),
            ("power", nil, MenuBarContent(showsIcon: true, showsCharge: false, showsPower: true)),
            ("unknown", "unknown", MenuBarContent.default),
        ])
    func migratesSettingsFromBefore04(style: String?, icon: String?, expected: MenuBarContent) {
        #expect(MenuBarContent.migrated(legacyStyle: style, legacyIcon: icon) == expected)
    }

    @Test func nothingToMigrateOnAFreshInstall() {
        #expect(MenuBarContent.migrated(legacyStyle: nil, legacyIcon: nil) == nil)
    }

    @Test func iconStyles() {
        #expect(MenuBarIconStyle.allCases == [.symbol, .modern, .classic, .percentageInside, .ring])
        #expect(MenuBarIconStyle.allCases.filter { !$0.isDrawn } == [.symbol])
        #expect(MenuBarIconStyle(rawValue: "percentageInside") == .percentageInside)
        // The values of the icon style before 0.4 aren't styles any more.
        #expect(MenuBarIconStyle(rawValue: "standard") == nil)
    }
}

@Suite struct BatteryIconStateTests {
    @Test func dischargingIsMonochromeWithoutGlyph() throws {
        let state = BatteryIconState(snapshot: try Fixture.m5OnBattery.snapshot())
        #expect(state == BatteryIconState(level: 0.7, percent: 70, glyph: .none, tint: .monochrome))
        #expect(state.isMonochrome)
    }

    @Test func chargingShowsTheBolt() throws {
        let state = BatteryIconState(snapshot: try Fixture.m5Charging.snapshot())
        #expect(state.glyph == .bolt)
        #expect(state.tint == .monochrome)
    }

    @Test(
        arguments: [
            (ChargeState.charging, true as Bool?, BatteryIconState.Glyph.bolt),
            (.charged, true, .plug),
            (.notCharging, true, .plug),
            // Plugged into an adapter too weak for the load.
            (.discharging, true, .plug),
            (.discharging, false, .none),
            // Without the adapter flag, the state decides.
            (.charged, nil, .plug),
            (.notCharging, nil, .plug),
            (.discharging, nil, .none),
            (.unknown, nil, .none),
        ])
    func glyphs(state: ChargeState, isExternalPowerConnected: Bool?, expected: BatteryIconState.Glyph) {
        let s = BatterySnapshot(
            timestamp: .now, chargePercent: 80, chargeState: state, isExternalPowerConnected: isExternalPowerConnected)
        #expect(BatteryIconState(snapshot: s).glyph == expected)
    }

    @Test(
        arguments: [
            (50.0, ChargeState.discharging, false, BatteryIconState.Tint.monochrome),
            (21.0, .discharging, false, .monochrome),
            (20.0, .discharging, false, .low),
            (5.0, .discharging, false, .low),
            // Charging is never red, as in the app's level colours.
            (5.0, .charging, false, .monochrome),
            (5.0, .notCharging, false, .low),
            // Low Power Mode wins over low.
            (50.0, .discharging, true, .lowPower),
            (5.0, .discharging, true, .lowPower),
            (5.0, .charging, true, .lowPower),
        ])
    func tints(percent: Double, state: ChargeState, lowPowerMode: Bool, expected: BatteryIconState.Tint) {
        let s = BatterySnapshot(
            timestamp: .now, chargePercent: percent, chargeState: state, isLowPowerModeEnabled: lowPowerMode)
        let icon = BatteryIconState(snapshot: s)
        #expect(icon.tint == expected)
        #expect(icon.isMonochrome == (expected == .monochrome))
    }

    @Test func levelAndPercentAreClamped() {
        let over = BatteryIconState(
            snapshot: BatterySnapshot(timestamp: .now, chargePercent: 104.6, chargeState: .discharging))
        #expect(over.level == 1)
        #expect(over.percent == 100)
        let rounded = BatteryIconState(
            snapshot: BatterySnapshot(timestamp: .now, chargePercent: 69.6, chargeState: .discharging))
        #expect(rounded.percent == 70)
        #expect(abs(rounded.level - 0.696) < 1e-9)
        #expect(BatteryIconState(level: -1).level == 0)
    }

    @Test func noReadingIsAnEmptyMonochromeBattery() {
        #expect(
            BatteryIconState(snapshot: nil) == BatteryIconState(level: 0, percent: nil, glyph: .none, tint: .monochrome)
        )
    }
}

@Suite struct BatteryIconLayoutTests {
    private let plain = BatteryIconState(level: 0.5, percent: 50)
    private let charging = BatteryIconState(level: 0.5, percent: 50, glyph: .bolt)
    private let pluggedIn = BatteryIconState(level: 0.5, percent: 50, glyph: .plug)

    @Test func symbolIsNotDrawn() {
        #expect(BatteryIconLayout(style: .symbol, state: plain) == nil)
    }

    @Test func modernMatchesTheSystemItem() throws {
        let layout = try #require(BatteryIconLayout(style: .modern, state: plain))
        // A 22 × 11 pt capsule with fully rounded ends and no outline.
        #expect(layout.body == IconRect(x: 0, y: 0, width: 22, height: 11))
        #expect(layout.cornerRadius == layout.body.height / 2)
        #expect(layout.outlineWidth == 0)
        #expect(layout.fillArea == layout.body)
        #expect(layout.trackOpacity == 0.35)
        // A translucent terminal 1 pt to the right, centred vertically.
        let nub = try #require(layout.nub)
        #expect(nub.x - layout.body.maxX == 1)
        #expect(nub.midY == layout.body.midY)
        #expect(layout.nubOpacity == layout.trackOpacity)
        #expect(layout.width == nub.maxX)
        #expect(layout.height == 11)
        #expect(layout.glyph == nil)
        #expect(layout.digitsFontSize == nil)
        #expect(!layout.isRing)
    }

    @Test func classicIsOutlinedWithAnInsetFill() throws {
        let layout = try #require(BatteryIconLayout(style: .classic, state: plain))
        #expect(layout.outlineWidth == 1)
        #expect(layout.trackOpacity == 0)
        #expect(layout.nubOpacity == 1)
        #expect(layout.fillArea.x > layout.outlineWidth)
        #expect(layout.fillArea.maxX < layout.body.maxX - layout.outlineWidth)
        #expect(layout.fillArea.midY == layout.body.midY)
    }

    @Test(arguments: [MenuBarIconStyle.modern, .classic, .ring])
    func glyphsSitCentredOnTheBattery(style: MenuBarIconStyle) throws {
        for state in [charging, pluggedIn] {
            let layout = try #require(BatteryIconLayout(style: style, state: state))
            let glyph = try #require(layout.glyph)
            #expect(abs(glyph.midX - layout.body.midX) < 1e-9)
            #expect(abs(glyph.midY - layout.body.midY) < 1e-9)
            #expect(glyph.x >= layout.body.x && glyph.maxX <= layout.body.maxX)
            #expect(glyph.y >= layout.body.y && glyph.maxY <= layout.body.maxY)
            let aspect = BatteryIconGlyphs.aspectRatio(state.glyph)
            #expect(abs(glyph.width / glyph.height - aspect) < 1e-9)
            // The gap only matters where the glyph crosses the fill.
            #expect((layout.glyphGap > 0) == !layout.isRing)
            // The icon keeps its size when the glyph appears.
            #expect(layout.width == BatteryIconLayout(style: style, state: plain)?.width)
        }
    }

    @Test func ringGlyphsStayInsideTheStroke() throws {
        for state in [charging, pluggedIn] {
            let layout = try #require(BatteryIconLayout(style: .ring, state: state))
            let glyph = try #require(layout.glyph)
            let inner = layout.body.width / 2 - layout.ringLineWidth
            let halfDiagonal = (glyph.width * glyph.width + glyph.height * glyph.height).squareRoot() / 2
            #expect(halfDiagonal + layout.glyphGap < inner)
        }
    }

    @Test func percentageInsideFitsThreeDigitsAndPutsTheGlyphAfterTheTerminal() throws {
        let layout = try #require(BatteryIconLayout(style: .percentageInside, state: plain))
        let fontSize = try #require(layout.digitsFontSize)
        // Bold rounded digits are about 0.6 em wide; "100" must fit between the rounded ends.
        #expect(fontSize * 0.62 * 3 < layout.body.width - layout.cornerRadius)
        #expect(fontSize < layout.body.height)
        #expect(layout.glyph == nil)

        let noReading = try #require(BatteryIconLayout(style: .percentageInside, state: BatteryIconState(level: 0)))
        #expect(noReading.digitsFontSize == nil)

        for state in [charging, pluggedIn] {
            let withGlyph = try #require(BatteryIconLayout(style: .percentageInside, state: state))
            let glyph = try #require(withGlyph.glyph)
            let nub = try #require(withGlyph.nub)
            #expect(glyph.x > nub.maxX)
            #expect(withGlyph.width == glyph.maxX)
            #expect(abs(glyph.midY - withGlyph.body.midY) < 1e-9)
            #expect(glyph.maxY <= withGlyph.height)
            // Outside the battery, nothing to knock out.
            #expect(withGlyph.glyphGap == 0)
        }
    }

    @Test(arguments: [MenuBarIconStyle.modern, .classic, .percentageInside, .ring])
    func everythingFitsTheCanvas(style: MenuBarIconStyle) throws {
        for state in [plain, charging, pluggedIn] {
            let layout = try #require(BatteryIconLayout(style: style, state: state))
            var rects = [layout.body, layout.fillArea]
            rects += [layout.nub, layout.glyph].compactMap { $0 }
            for rect in rects {
                #expect(rect.x >= 0 && rect.y >= 0)
                #expect(rect.maxX <= layout.width && rect.maxY <= layout.height)
            }
            // Menu bar icons stay well under the bar's height.
            #expect(layout.height <= 16)
        }
    }

    @Test func fillGrowsInWholePixels() throws {
        let layout = try #require(BatteryIconLayout(style: .modern, state: plain))
        #expect(layout.fillWidth(level: 0, pixelScale: 2) == 0)
        #expect(layout.fillWidth(level: 1, pixelScale: 2) == 22)
        #expect(layout.fillWidth(level: 0.5, pixelScale: 2) == 11)
        // 70 % of 22 pt is 15.4 pt: 30.8 px rounds to 31 px.
        #expect(layout.fillWidth(level: 0.7, pixelScale: 2) == 15.5)
        #expect(layout.fillWidth(level: 0.7, pixelScale: 1) == 15)
        // A sliver stays visible at 1 %.
        #expect(layout.fillWidth(level: 0.01, pixelScale: 2) == 0.5)
        #expect(layout.fillWidth(level: 1.5, pixelScale: 2) == 22)
        #expect(layout.fillWidth(level: 0.5, pixelScale: 0) == 0)

        let classic = try #require(BatteryIconLayout(style: .classic, state: plain))
        #expect(classic.fillWidth(level: 1, pixelScale: 2) == classic.fillArea.width)
    }
}

@Suite struct BatteryIconGlyphTests {
    private let box = IconRect(x: 10, y: 20, width: 6, height: 10)

    @Test func boltFillsItsBoxAndIsPointSymmetric() {
        let points = BatteryIconGlyphs.bolt(in: box)
        #expect(points.count == 6)
        #expect(points.map(\.x).min() == box.x)
        #expect(points.map(\.x).max() == box.maxX)
        #expect(points.map(\.y).min() == box.y)
        #expect(points.map(\.y).max() == box.maxY)
        // Rotating by 180° about the centre maps the outline onto itself.
        for (index, point) in points.enumerated() {
            let opposite = points[(index + 3) % 6]
            #expect(abs(point.x + opposite.x - 2 * box.midX) < 1e-9)
            #expect(abs(point.y + opposite.y - 2 * box.midY) < 1e-9)
        }
    }

    @Test func boltOutlineDoesNotCrossItself() {
        let points = BatteryIconGlyphs.bolt(in: box)
        func cross(_ o: IconPoint, _ a: IconPoint, _ b: IconPoint) -> Double {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        func intersects(_ p1: IconPoint, _ p2: IconPoint, _ q1: IconPoint, _ q2: IconPoint) -> Bool {
            let d1 = cross(q1, q2, p1)
            let d2 = cross(q1, q2, p2)
            let d3 = cross(p1, p2, q1)
            let d4 = cross(p1, p2, q2)
            return d1 * d2 < 0 && d3 * d4 < 0
        }
        let edges = points.indices.map { (points[$0], points[($0 + 1) % points.count]) }
        for i in edges.indices {
            for j in edges.indices where j > i + 1 && !(i == 0 && j == edges.count - 1) {
                #expect(!intersects(edges[i].0, edges[i].1, edges[j].0, edges[j].1), "edges \(i) and \(j)")
            }
        }
    }

    @Test func plugFillsItsBox() throws {
        let box = IconRect(x: 2, y: 3, width: 15, height: 10)
        let parts = BatteryIconGlyphs.plug(in: box)
        #expect(parts.count == 4)
        let rects = parts.map(\.rect)
        #expect(abs(try #require(rects.map(\.x).min()) - box.x) < 1e-9)
        #expect(abs(try #require(rects.map(\.maxX).max()) - box.maxX) < 1e-9)
        for part in parts {
            #expect(part.rect.y >= box.y && part.rect.maxY <= box.maxY)
            #expect(part.cornerRadius <= part.rect.height / 2 + 1e-9)
        }
        // A box of another shape keeps the plug's proportions, centred.
        let wide = BatteryIconGlyphs.plug(in: IconRect(x: 0, y: 0, width: 30, height: 10))
        #expect(abs(try #require(wide.map(\.rect.x).min()) - 7.5) < 1e-9)
    }
}
