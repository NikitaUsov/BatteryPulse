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
        var symbols = BatteryFormatter.UnitSymbols.english
        symbols.watts = "W-ru"
        let russian = BatteryFormatter(locale: Locale(identifier: "ru_RU"), symbols: symbols)
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

    /// The app's menu bar choices fall back to these for a key never written, so a new install
    /// (or one after `defaults delete`) shows the icon and the percentage, with the modern icon.
    @Test func defaultsAreTheIconAndThePercentage() {
        #expect(MenuBarContent.default.items == [.icon, .charge])
        #expect(MenuBarContent.default == MenuBarContent(items: [.icon, .charge]))
        #expect(MenuBarIconStyle.default == .modern)
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
        // Every style but the SF Symbol is drawn with shapes.
        #expect(MenuBarIconStyle.allCases.filter { BatteryIconLayout(style: $0, state: .sample) == nil } == [.symbol])
        #expect(MenuBarIconStyle(rawValue: "percentageInside") == .percentageInside)
        // The values of the icon style before 0.4 aren't styles any more.
        #expect(MenuBarIconStyle(rawValue: "standard") == nil)
    }
}

@Suite struct BatteryIconStateTests {
    /// The digits in the icon read the same as the percentage the formatter writes, half steps
    /// included (42.5 is "42%" in both).
    @Test(arguments: Array(stride(from: 0.0, through: 100.0, by: 0.5)))
    func digitsRoundLikeTheFormatter(percent: Double) throws {
        let english = BatteryFormatter(locale: Locale(identifier: "en_US"))
        let snapshot = BatterySnapshot(timestamp: .now, chargePercent: percent, chargeState: .discharging)
        let digits = try #require(BatteryIconState(snapshot: snapshot).percent)
        #expect("\(digits)%" == english.percent(percent))
    }

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
    private let barStyles: [MenuBarIconStyle] = [.modern, .classic, .percentageInside]

    @Test func symbolIsNotDrawn() {
        #expect(BatteryIconLayout(style: .symbol, state: plain) == nil)
    }

    @Test func modernMatchesTheSystemItem() throws {
        let layout = try #require(BatteryIconLayout(style: .modern, state: plain))
        // Measured on the M5 (macOS 27, 2x): a 23 × 12 pt body with 4 pt corners, no outline.
        #expect(layout.body == IconRect(x: 0, y: 1, width: 23, height: 12))
        #expect(layout.cornerRadius == layout.body.height / 3)
        #expect(layout.outlineWidth == 0)
        #expect(layout.fillArea == layout.body)
        #expect(layout.trackOpacity == 0.48)
        // A 1.375 × 4 pt terminal 1 pt to the right, centred.
        let nub = try #require(layout.nub)
        #expect(nub.x - layout.body.maxX == 1)
        #expect(nub.width == 1.375 && nub.height == 4)
        #expect(nub.midY == layout.body.midY)
        #expect(layout.nubOpacity == 0.58)
        // The terminal's end rounded up to whole points, so the image has whole pixels.
        #expect(layout.width == nub.maxX.rounded(.up))
        // Room for the bolt's overshoot above and below.
        #expect(layout.height == layout.body.height + 2)
        #expect(layout.glyph == nil)
        #expect(layout.digits == nil)
        #expect(!layout.isRing)
    }

    @Test func classicIsOutlinedWithAnInsetFill() throws {
        let layout = try #require(BatteryIconLayout(style: .classic, state: plain))
        #expect(layout.outlineWidth == 1)
        #expect(layout.trackOpacity == 0)
        #expect(layout.nubOpacity == 1)
        #expect(layout.fillArea == layout.body.insetBy(2))
        #expect(layout.fillCornerRadius == layout.cornerRadius - 2)
    }

    @Test func barStylesShareOneCanvas() throws {
        let modern = try #require(BatteryIconLayout(style: .modern, state: plain))
        for style in barStyles {
            for state in [plain, charging, pluggedIn, BatteryIconState(level: 0)] {
                let layout = try #require(BatteryIconLayout(style: style, state: state))
                #expect(layout.width == modern.width && layout.height == modern.height)
                #expect(layout.body == modern.body && layout.nub == modern.nub)
            }
        }
        let ring = try #require(BatteryIconLayout(style: .ring, state: plain))
        #expect(ring.height == modern.height)
        #expect(BatteryIconLayout.previewSize == IconSize(width: modern.width, height: modern.height))
    }

    @Test(arguments: [MenuBarIconStyle.modern, .classic])
    func boltOvershootsTheBodyLikeTheSystem(style: MenuBarIconStyle) throws {
        let layout = try #require(BatteryIconLayout(style: style, state: charging))
        let bolt = try #require(layout.glyph)
        #expect(bolt.height == 14 && bolt.y == 0 && bolt.maxY == layout.height)
        #expect(abs(bolt.width / bolt.height - 0.7) < 1e-9)
        #expect(abs(bolt.midX - layout.body.midX) < 1e-9)
        #expect(layout.glyphGap == 1.2)
        // The plug stays inside the battery.
        let plug = try #require(BatteryIconLayout(style: style, state: pluggedIn)?.glyph)
        #expect(plug.y > layout.body.y && plug.maxY < layout.body.maxY)
        #expect(abs(plug.midX - layout.body.midX) < 1e-9 && abs(plug.midY - layout.body.midY) < 1e-9)
    }

    @Test func ringGlyphsStayInsideTheStroke() throws {
        for state in [charging, pluggedIn] {
            let layout = try #require(BatteryIconLayout(style: .ring, state: state))
            let glyph = try #require(layout.glyph)
            #expect(abs(glyph.midX - layout.body.midX) < 1e-9 && abs(glyph.midY - layout.body.midY) < 1e-9)
            let inner = layout.body.width / 2 - layout.ringLineWidth
            let halfDiagonal = (glyph.width * glyph.width + glyph.height * glyph.height).squareRoot() / 2
            #expect(halfDiagonal + layout.glyphGap < inner)
            #expect(layout.ringLineWidth == 3)
        }
    }

    @Test func percentageInsideKnocksTheNumberOutOfTheBattery() throws {
        let layout = try #require(BatteryIconLayout(style: .percentageInside, state: plain))
        let digits = try #require(layout.digits)
        // 7.4 pt digits, 2.3 pt clear of the body's top and bottom, centred; a tenth of the
        // battery stays under them, as the system draws it.
        #expect(digits.capHeight == 7.4)
        #expect(digits.box.height == digits.capHeight)
        #expect(abs(digits.box.y - layout.body.y - 2.3) < 1e-9)
        #expect(abs(layout.body.maxY - digits.box.maxY - 2.3) < 1e-9)
        #expect(digits.box.midX == layout.body.midX)
        #expect(digits.knockOut == 0.9)
        #expect(digits.glyphSize == nil)
        #expect(layout.glyph == nil)

        for state in [charging, pluggedIn] {
            let withGlyph = try #require(BatteryIconLayout(style: .percentageInside, state: state))
            let inline = try #require(withGlyph.digits?.glyphSize)
            #expect(inline.height <= digits.capHeight)
            // Inside the battery, knocked out with the number: nothing drawn over it.
            #expect(withGlyph.glyph == nil)
        }

        // Without a reading it is drawn like Modern.
        let noReading = try #require(
            BatteryIconLayout(style: .percentageInside, state: BatteryIconState(level: 0, glyph: .bolt)))
        #expect(noReading.digits == nil)
        #expect(noReading.glyph == BatteryIconLayout(style: .modern, state: charging)?.glyph)
    }

    @Test func digitsFitTheirBoxAndStayCentred() throws {
        let digits = try #require(BatteryIconLayout(style: .percentageInside, state: charging)?.digits)
        let box = digits.box
        let bolt = try #require(digits.glyphSize)
        // "99" + bolt at the system's pitch fits as it is: full size, no tracking, centred
        // together, the bolt 1 pt after the number, both centred vertically.
        let two = digits.placement(textWidth: 12.4, digitCount: 2)
        #expect(two.scale == 1 && two.tracking == 0)
        #expect(two.text.height == digits.capHeight && abs(two.text.width - 12.4) < 1e-9)
        let glyph = try #require(two.glyph)
        #expect(glyph.width == bolt.width && glyph.height == bolt.height)
        #expect(abs((two.text.x + glyph.maxX) / 2 - box.midX) < 1e-9)
        #expect(abs(glyph.x - two.text.maxX - digits.spacing) < 1e-9)
        #expect(abs(glyph.midY - box.midY) < 1e-9 && abs(two.text.midY - box.midY) < 1e-9)
        // A wider face is set closer, not narrowed: 6.5 pt digits get -0.3 pt between them.
        let wide = digits.placement(textWidth: 13, digitCount: 2)
        #expect(abs(wide.tracking + 0.3) < 1e-9 && abs(wide.text.width - 12.7) < 1e-9)
        #expect(wide.scale == 1 && wide.text.height == digits.capHeight)
        // "100" + bolt doesn't fit: everything scales down by the same factor (height included,
        // as the system does) and fills the box exactly.
        let three = digits.placement(textWidth: 17, digitCount: 3)
        let scale = box.width / (17 + digits.spacing + bolt.width)
        #expect(three.tracking == 0 && abs(three.scale - scale) < 1e-9)
        #expect(abs(three.text.height - digits.capHeight * scale) < 1e-9)
        #expect(abs(three.text.width - 17 * scale) < 1e-9)
        #expect(abs(three.text.x - box.x) < 1e-9 && abs((three.glyph?.maxX ?? 0) - box.maxX) < 1e-9)
        #expect(abs((three.glyph?.height ?? 0) - bolt.height * scale) < 1e-9)
        #expect(three.text.y >= box.y && three.text.maxY <= box.maxY)
        // No glyph: the number alone is centred; odd input doesn't break the layout.
        let plain = try #require(BatteryIconLayout(style: .percentageInside, state: plain)?.digits)
        let alone = plain.placement(textWidth: 12.4, digitCount: 2)
        #expect(alone.glyph == nil && abs(alone.text.midX - box.midX) < 1e-9 && alone.scale == 1)
        #expect(plain.placement(textWidth: 0, digitCount: 0).scale == 1)
        #expect(plain.placement(textWidth: -1, digitCount: 1).text.width == 0)
    }

    @Test(arguments: [MenuBarIconStyle.modern, .classic, .percentageInside, .ring])
    func everythingFitsTheCanvas(style: MenuBarIconStyle) throws {
        for state in [plain, charging, pluggedIn] {
            let layout = try #require(BatteryIconLayout(style: style, state: state))
            var rects = [layout.body, layout.fillArea]
            rects += [layout.nub, layout.glyph, layout.digits?.box].compactMap { $0 }
            for rect in rects {
                #expect(rect.x >= 0 && rect.y >= 0)
                #expect(rect.maxX <= layout.width && rect.maxY <= layout.height)
            }
            if let box = layout.digits?.box {
                #expect(box.x >= layout.body.x && box.maxX <= layout.body.maxX)
                #expect(box.y >= layout.body.y && box.maxY <= layout.body.maxY)
            }
            // Menu bar icons stay well under the bar's height.
            #expect(layout.height <= 16)
        }
    }

    @Test func fillGrowsInWholePixels() throws {
        let layout = try #require(BatteryIconLayout(style: .modern, state: plain))
        #expect(layout.fillWidth(level: 0, pixelScale: 2) == 0)
        #expect(layout.fillWidth(level: 1, pixelScale: 2) == 23)
        #expect(layout.fillWidth(level: 0.5, pixelScale: 2) == 11.5)
        // 70 % of 23 pt is 16.1 pt: 32.2 px rounds to 32 px.
        #expect(layout.fillWidth(level: 0.7, pixelScale: 2) == 16)
        #expect(layout.fillWidth(level: 0.7, pixelScale: 1) == 16)
        // A sliver stays visible at 1 %.
        #expect(layout.fillWidth(level: 0.01, pixelScale: 2) == 0.5)
        #expect(layout.fillWidth(level: 1.5, pixelScale: 2) == 23)
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
