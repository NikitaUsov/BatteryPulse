import Foundation
import Testing

@testable import BatteryCore

/// The iPhone & iPad widget: what each family shows from the feed for each choice, its states, its
/// names, read times, clicks and VoiceOver elements in both languages, and its timeline.
struct DevicesWidgetPlanTests {
    typealias Language = WidgetTextBudgetTests.Language

    static let formatter = WidgetChartTests.formatter
    static let utc = WidgetChartTests.utc
    /// 2026-11-05 10:07:30 UTC.
    static let now = WidgetChartTests.now
    static let fresh = WidgetTimelinePlan.Entry(date: now, showsEstimate: false)

    static func key(_ last: Character) -> DeviceKey {
        WidgetFeed.sampleKey(last)
    }

    /// A device read `minutes` before ``now``.
    static func device(
        _ last: Character, name: String? = nil, model: String? = nil, deviceClass: String? = "iPhone",
        percent: Int? = 50, state: ChargeState = .discharging, minutes: Double = 5
    ) -> WidgetFeed.Device {
        WidgetFeed.Device(
            key: key(last), name: name, model: model, deviceClass: deviceClass, percent: percent, state: state,
            maximumCapacity: 95, cycleCount: 278, temperature10: 365, readAt: now.addingTimeInterval(-minutes * 60))
    }

    static func feed(_ devices: [WidgetFeed.Device]?, readsDevices: Bool = true) -> WidgetFeed {
        WidgetFeed(
            writtenAt: now, languages: ["en"], recordsHistory: true, readsDevices: readsDevices, devices: devices)
    }

    /// Four devices in the feed's order (the most recently read first), the lowest third.
    static let four = [
        device("1", name: "Anna's iPhone", percent: 65, state: .charging, minutes: 3),
        device("2", model: "iPad Air", deviceClass: "iPad", percent: 82, minutes: 40),
        device("3", name: "Work iPhone", percent: 12, minutes: 300),
        device("4", deviceClass: "iPad", percent: nil, state: .unknown, minutes: 3_000),
    ]

    static func plan(
        _ size: WidgetSize, _ show: DevicesWidgetShow = .mostRecent, feed: WidgetFeed?,
        at entry: WidgetTimelinePlan.Entry = fresh, formatter: BatteryFormatter = formatter
    ) -> DevicesWidgetPlan {
        DevicesWidgetPlan.make(
            size: size, configuration: DevicesWidgetConfiguration(show: show), feed: feed, entry: entry,
            formatter: formatter, timeZone: utc)
    }

    static func layout(
        _ size: WidgetSize, _ show: DevicesWidgetShow = .mostRecent, feed: WidgetFeed?,
        at entry: WidgetTimelinePlan.Entry = fresh
    ) throws -> DevicesWidgetLayout {
        guard case .devices(let layout) = plan(size, show, feed: feed, at: entry) else { throw PlanError.empty }
        return layout
    }

    enum PlanError: Error { case empty }

    static func names(_ layout: DevicesWidgetLayout) -> [String] {
        layout.rows.map { if case .named(let name) = $0.name { name } else { "?" } }
    }

    /// The default shows the most recently read device in every size, whatever the feed's order.
    @Test func theDefaultIsTheMostRecentlyReadDevice() throws {
        let shuffled = Self.feed([Self.four[2], Self.four[0], Self.four[3], Self.four[1]])
        #expect(DevicesWidgetConfiguration().show == .mostRecent)
        for size in [WidgetSize.small, .medium, .large] {
            let layout = try Self.layout(size, feed: shuffled)
            #expect(layout.showsOne && Self.names(layout) == ["Anna's iPhone"], "\(size)")
        }
    }

    /// Lowest charge: the device with the least charge; one without a charge never counts as the
    /// lowest.
    @Test func lowestChargeShowsTheLowest() throws {
        for size in [WidgetSize.small, .medium, .large] {
            let layout = try Self.layout(size, .lowest, feed: Self.feed(Self.four))
            #expect(layout.showsOne && Self.names(layout) == ["Work iPhone"], "\(size)")
        }
        let unknownFirst = Self.feed([Self.four[3], Self.four[1]])
        #expect(Self.names(try Self.layout(.small, .lowest, feed: unknownFirst)) == ["iPad Air"])
        // Equal charges: the first in the feed, which the app writes the most recently read first.
        let equal = Self.feed([
            Self.device("6", name: "New", percent: 40), Self.device("5", name: "Old", percent: 40, minutes: 60),
        ])
        #expect(Self.names(try Self.layout(.small, .lowest, feed: equal)) == ["New"])
    }

    /// One device: the chosen one in every size, the most recently read until one is chosen, and
    /// "This device was forgotten" once the feed no longer holds it.
    @Test func oneDeviceShowsTheChosenOne() throws {
        func one(_ key: DeviceKey?) -> DevicesWidgetConfiguration {
            DevicesWidgetConfiguration(show: .oneDevice, device: key)
        }
        let feed = Self.feed(Self.four)
        for size in [WidgetSize.small, .medium, .large] {
            let plan = DevicesWidgetPlan.make(
                size: size, configuration: one(Self.key("2")), feed: feed, entry: Self.fresh,
                formatter: Self.formatter, timeZone: Self.utc)
            guard case .devices(let layout) = plan else {
                Issue.record("\(size): \(plan)")
                continue
            }
            #expect(layout.showsOne && Self.names(layout) == ["iPad Air"], "\(size)")
            #expect(plan.route.page == .device(Self.key("2")))
        }
        func plan(_ configuration: DevicesWidgetConfiguration, feed: WidgetFeed?) -> DevicesWidgetPlan {
            DevicesWidgetPlan.make(
                size: .small, configuration: configuration, feed: feed, entry: Self.fresh, formatter: Self.formatter,
                timeZone: Self.utc)
        }
        guard case .devices(let unchosen) = plan(one(nil), feed: feed) else {
            Issue.record("none chosen")
            return
        }
        #expect(Self.names(unchosen) == ["Anna's iPhone"])
        let forgotten = plan(one(Self.key("9")), feed: feed)
        #expect(forgotten == .empty(.forgotten))
        #expect(forgotten.route.page == .devices)
        // Reads off and none remembered come first.
        #expect(plan(one(Self.key("9")), feed: Self.feed(Self.four, readsDevices: false)) == .empty(.readsOff))
        #expect(plan(one(Self.key("9")), feed: Self.feed([])) == .empty(.noDevices))
        #expect(plan(one(Self.key("9")), feed: nil) == .empty(.noFeed))
    }

    /// All lists the devices in the feed's order, which the app writes the most recently read
    /// first: three in medium, six in large, one fewer while the old feed's line shows; small has
    /// room for one, the most recently read.
    @Test func allListsAsManyAsTheSizeHasRoomFor() throws {
        let eight = (0..<8).map { Self.device(Character(String($0)), name: "Device \($0)", minutes: Double($0 + 1)) }
        let feed = Self.feed(eight)
        let medium = try Self.layout(.medium, .all, feed: feed)
        #expect(!medium.showsOne && Self.names(medium) == ["Device 0", "Device 1", "Device 2"])
        #expect(medium.rows.allSatisfy { $0.details.isEmpty })
        #expect(try Self.layout(.large, .all, feed: feed).rows.count == 6)
        let small = try Self.layout(.small, .all, feed: feed)
        #expect(small.showsOne && Self.names(small) == ["Device 0"])
        let old = WidgetTimelinePlan.Entry(date: Self.now.addingTimeInterval(2 * 3600), showsEstimate: false)
        #expect(try Self.layout(.medium, .all, feed: feed, at: old).rows.count == 2)
        #expect(try Self.layout(.large, .all, feed: feed, at: old).rows.count == 5)
        #expect(try Self.layout(.small, .all, feed: feed, at: old).rows.count == 1)
        // Fewer devices than room: all of them.
        #expect(try Self.layout(.large, .all, feed: Self.feed(Self.four)).rows.count == 4)
    }

    /// One device's details: none in small; its maximum capacity, cycle count and temperature in
    /// medium (Look 2's answer: the medium Battery widget's rows beside it) and in large, each only
    /// when its reading has it, for every choice that shows one device.
    @Test func oneDevicesDetailsGrowWithTheSize() throws {
        let feed = Self.feed([Self.four[0]])
        #expect(try Self.layout(.small, feed: feed).rows[0].details.isEmpty)
        for size in [WidgetSize.medium, .large] {
            for show in [DevicesWidgetShow.mostRecent, .lowest, .oneDevice] {
                let details = try Self.layout(size, show, feed: feed).rows[0].details
                #expect(details.map(\.field) == [.maximumCapacity, .cycleCount, .temperature], "\(size), \(show)")
                #expect(
                    details.map(\.value) == [.text("95%"), .text("278"), .text(Self.formatter.celsius(36.5))],
                    "\(size), \(show)")
            }
            var sparse = Self.four[0]
            sparse.cycleCount = nil
            sparse.temperature10 = nil
            #expect(
                try Self.layout(size, feed: Self.feed([sparse])).rows[0].details.map(\.field) == [.maximumCapacity],
                "\(size)")
        }
        // All lists rows without details.
        #expect(try Self.layout(.medium, .all, feed: Self.feed(Self.four)).rows.allSatisfy { $0.details.isEmpty })
    }

    /// A row's charge, state, tier and symbol.
    @Test func aRowSaysTheChargeAndTheState() throws {
        let rows = try Self.layout(.large, .all, feed: Self.feed(Self.four)).rows
        #expect(rows.map(\.charge) == ["65%", "82%", "12%", "—"])
        #expect(rows.map(\.state) == [.charging, .onBattery, .onBattery, .unknown])
        #expect(rows.map(\.isCharging) == [true, false, false, false])
        #expect(rows.map(\.tier) == [.normal, .normal, .low, .normal])
        #expect(rows.map(\.symbolName) == ["iphone", "ipad", "iphone", "ipad"])
        #expect(WidgetStateWord(device: .charged) == .fullyCharged)
        #expect(WidgetStateWord(device: .notCharging) == .notCharging)
    }

    /// The owner's name, else the model's, else "iPhone" or "iPad", else "Unknown Device".
    @Test func theDisplayNameOrder() {
        func name(_ device: WidgetFeed.Device) -> DeviceWidgetName { DeviceWidgetName(device) }
        #expect(name(Self.device("1", name: "Anna's iPhone", model: "iPhone 17 Pro")) == .named("Anna's iPhone"))
        #expect(name(Self.device("1", model: "iPhone 17 Pro")) == .named("iPhone 17 Pro"))
        #expect(name(Self.device("1", deviceClass: "iPad")) == .named("iPad"))
        #expect(name(Self.device("1", deviceClass: "Watch")) == .unknown)
        #expect(name(Self.device("1", deviceClass: nil)) == .unknown)
        #expect(DeviceWidgetName.unknown.phrase == .key("Unknown Device"))
    }

    /// The read time today, the day otherwise, in the widget's language and time zone.
    @Test(arguments: Language.allCases)
    func theReadTimeIsTheTimeTodayAndTheDayBefore(_ language: Language) throws {
        func time(_ minutes: Double) -> String {
            DeviceWidgetRow.readTime(
                Self.now.addingTimeInterval(-minutes * 60), at: Self.now, locale: language.locale, timeZone: Self.utc)
        }
        func clock(_ minutes: Double) -> String {
            Self.now.addingTimeInterval(-minutes * 60).formatted(
                Date.FormatStyle(date: .omitted, time: .shortened, locale: language.locale, timeZone: Self.utc))
        }
        // 10:07 UTC: five hours before is today, eleven hours before the day before.
        #expect(time(3) == clock(3) && time(300) == clock(300))
        let day = time(11 * 60)
        #expect(day.contains("4") && !day.contains(":"), "\(day)")
        if language == .english { #expect(day == "Nov 4") }
        // The rows' read times, in the feed's order.
        let plan = Self.plan(
            .large, .all, feed: Self.feed(Self.four), formatter: try WidgetTextBudgetTests.formatter(language))
        guard case .devices(let layout) = plan else { throw PlanError.empty }
        #expect(layout.rows.prefix(3).map(\.updated) == [clock(3), clock(40), clock(300)])
        #expect(layout.rows[3].updated == time(3_000))
        if language == .english { #expect(layout.rows[3].updated == "Nov 3") }
    }

    /// Without a feed, with reads off, and with none remembered: a message, each with its page.
    @Test func theStatesWithoutADevice() {
        #expect(Self.plan(.small, feed: nil) == .empty(.noFeed))
        #expect(Self.plan(.medium, feed: Self.feed(Self.four, readsDevices: false)) == .empty(.readsOff))
        #expect(Self.plan(.large, feed: Self.feed([])) == .empty(.noDevices))
        #expect(Self.plan(.small, feed: nil).route.page == .overview)
        #expect(Self.plan(.small, feed: Self.feed(nil, readsDevices: false)).route.page == .devices)
        #expect(Self.plan(.small, feed: Self.feed([])).route.page == .devices)
    }

    /// Reads on, but a feed written while no iPhone & iPad widget counted as placed holds no
    /// devices yet: the widget waits for BatteryPulse to write them, as without a feed, and never
    /// says to connect a device that may be remembered already. Reads off still says so first.
    @Test func aFeedWithoutTheDevicesYetWaitsForThem() {
        for size in [WidgetSize.small, .medium, .large] {
            for show in DevicesWidgetShow.allCases {
                let plan = Self.plan(size, show, feed: Self.feed(nil))
                #expect(plan == .empty(.noFeed), "\(size) \(show)")
                #expect(plan.route.page == .overview)
                #expect(WidgetAccessibility.elements(plan) == [.phrases([.key("Open BatteryPulse to update")])])
            }
        }
        #expect(Self.plan(.small, feed: Self.feed(nil, readsDevices: false)) == .empty(.readsOff))
        // Once written, an empty list is none remembered.
        #expect(Self.plan(.small, feed: Self.feed([])) == .empty(.noDevices))
    }

    /// One device opens its page; All opens the Devices section.
    @Test func aClickOpensTheDeviceOrTheDevices() {
        let feed = Self.feed(Self.four)
        #expect(Self.plan(.small, feed: feed).route.page == .device(Self.key("1")))
        #expect(Self.plan(.medium, .lowest, feed: feed).route.page == .device(Self.key("3")))
        #expect(Self.plan(.medium, .all, feed: feed).route.page == .devices)
        #expect(
            Self.plan(.small, feed: feed).route.url.absoluteString
                == "batterypulse://page/device/\(Self.key("1").rawValue)")
    }

    /// A feed two hours old keeps its last readings and says "Open BatteryPulse to update".
    @Test func anOldFeedSaysSo() throws {
        let feed = Self.feed(Self.four)
        let almost = WidgetTimelinePlan.Entry(date: Self.now.addingTimeInterval(2 * 3600 - 1), showsEstimate: false)
        let old = WidgetTimelinePlan.Entry(date: Self.now.addingTimeInterval(2 * 3600), showsEstimate: false)
        #expect(try !Self.layout(.small, feed: feed, at: almost).isOutdated)
        let outdated = try Self.layout(.small, feed: feed, at: old)
        #expect(outdated.isOutdated && Self.names(outdated) == ["Anna's iPhone"])
        #expect(
            WidgetAccessibility.elements(.devices(outdated)).last == .phrases([.key("Open BatteryPulse to update")]))
    }

    /// Each device is one element, one device's details one each after it, every key with its
    /// Russian.
    @Test(arguments: Language.allCases)
    func eachDeviceIsOneElement(_ language: Language) throws {
        let localize = WidgetAccessibilityTests.localize(language)
        let f = try WidgetTextBudgetTests.formatter(language)
        let feed = Self.feed(Self.four)
        // Medium's one device has large's details, an element each.
        let medium = Self.plan(.medium, feed: feed, formatter: f)
        guard case .devices(let mediumLayout) = medium else {
            Issue.record("\(medium)")
            return
        }
        let mediumElements = WidgetAccessibility.elements(medium)
        #expect(mediumElements == [mediumLayout.rows[0].spokenLabel] + mediumLayout.rows[0].details.map(\.spokenLabel))
        #expect(mediumElements.count == 4)
        let one = Self.plan(.large, feed: feed, formatter: f)
        guard case .devices(let layout) = one else {
            Issue.record("\(one)")
            return
        }
        let elements = WidgetAccessibility.elements(one)
        #expect(elements == [layout.rows[0].spokenLabel] + layout.rows[0].details.map(\.spokenLabel))
        #expect(elements.count == 4)
        #expect(mediumElements == elements)
        let all = WidgetAccessibility.elements(Self.plan(.large, .all, feed: feed, formatter: f))
        #expect(all.count == 4)
        let empties = DevicesWidgetEmptyReason.allCases.map { WidgetAccessibility.elements(.empty($0)) }
        for element in mediumElements + elements + all + empties.flatMap({ $0 }) {
            let text = try #require(element.text(localize))
            #expect(!text.contains("%@"), "\(text)")
        }
        for key in (elements + all + empties.flatMap { $0 }).flatMap(\.keys) {
            #expect(try WidgetTextBudgetTests.text(key, .russian)?.isEmpty == false, "\(key)")
        }
        #expect(
            layout.rows[0].spokenLabel.text(WidgetAccessibilityTests.localize(.english))
                == "Anna's iPhone, 65%, Charging, Updated \(layout.rows[0].updated ?? "")")
    }

    /// Every half hour, with an entry at midnight when it comes first and one once the feed is two
    /// hours old, at least 15 minutes after the first; never more than three.
    @Test func theTimelineRefreshesEveryHalfHour() {
        let written = Self.now
        let plan = WidgetTimelinePlan.devices(
            writtenAt: written, at: written.addingTimeInterval(10 * 60), timeZone: Self.utc)
        #expect(
            plan.entries.map(\.date) == [written.addingTimeInterval(10 * 60), written.addingTimeInterval(2 * 3600)])
        #expect(plan.entries.map(\.isStale) == [false, true])
        #expect(plan.nextReload == written.addingTimeInterval(40 * 60))
        // Nearly two hours old: the old feed's entry waits the least interval.
        let late = WidgetTimelinePlan.devices(
            writtenAt: written, at: written.addingTimeInterval(115 * 60), timeZone: Self.utc)
        #expect(
            late.entries.map(\.date) == [written.addingTimeInterval(115 * 60), written.addingTimeInterval(130 * 60)])
        // Already old, and no feed: one entry.
        let old = WidgetTimelinePlan.devices(
            writtenAt: written, at: written.addingTimeInterval(3 * 3600), timeZone: Self.utc)
        #expect(old.entries.map(\.isStale) == [true])
        #expect(WidgetTimelinePlan.devices(writtenAt: nil, at: written, timeZone: Self.utc).entries.count == 1)
        // Ten minutes before midnight: midnight, then the old feed's entry.
        let midnight = Date(timeIntervalSince1970: 1_793_923_200)  // 2026-11-06 00:00 UTC
        let evening = midnight.addingTimeInterval(-10 * 60)
        let night = WidgetTimelinePlan.devices(
            writtenAt: evening.addingTimeInterval(-108 * 60), at: evening, timeZone: Self.utc)
        #expect(night.entries.map(\.date) == [evening, midnight, evening.addingTimeInterval(15 * 60)])
        #expect(night.entries.map(\.isStale) == [false, false, true])
        // A feed already old at midnight: midnight's entry is old too.
        let older = WidgetTimelinePlan.devices(
            writtenAt: evening.addingTimeInterval(-118 * 60), at: evening, timeZone: Self.utc)
        #expect(older.entries.map(\.date) == [evening, midnight, evening.addingTimeInterval(15 * 60)])
        #expect(older.entries.map(\.isStale) == [false, true, true])
        for plan in [plan, late, old, night, older] {
            #expect(plan.entries.count <= WidgetTimelinePlan.maximumEntries)
            #expect(plan.entries.map(\.date) == plan.entries.map(\.date).sorted())
        }
    }
}
