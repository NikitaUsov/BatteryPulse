import Foundation
import Testing

@testable import BatteryCore

/// What the Accessories widget shows (``AccessoriesWidgetPlan``) and what VoiceOver reads on it,
/// on the synthetic capture of eight accessories and on Demo Mode's.
struct AccessoriesWidgetPlanTests {
    static let formatter = BatteryFormatter(locale: Locale(identifier: "en_US"))
    static let readAt = Date(timeIntervalSince1970: 1_800_000_000)
    static let fresh = WidgetTimelinePlan.Entry(date: readAt, showsEstimate: false)

    static func plan(
        _ size: WidgetSize, _ accessories: [AccessoryBattery]?,
        _ configuration: AccessoriesWidgetConfiguration = AccessoriesWidgetConfiguration(),
        entry: WidgetTimelinePlan.Entry = fresh
    ) -> AccessoriesWidgetPlan {
        AccessoriesWidgetPlan.make(
            size: size, configuration: configuration, accessories: accessories, readAt: readAt, entry: entry,
            formatter: formatter, timeZone: .gmt)
    }

    static func layout(_ plan: AccessoriesWidgetPlan) throws -> AccessoriesWidgetLayout {
        guard case .accessories(let layout) = plan else {
            Issue.record("Expected accessories, got \(plan)")
            throw CancellationError()
        }
        return layout
    }

    static func names(_ layout: AccessoriesWidgetLayout) -> [String] {
        layout.rows.map {
            switch $0.name {
            case .reported(let name): name
            case .kind(let kind): "(\(kind))"
            }
        }
    }

    static func synthetic() throws -> [AccessoryBattery] {
        try AccessoryFixture.synthetic.accessories()
    }

    static var demo: [AccessoryBattery] {
        AccessoryReading(sources: DemoAccessories.sources).accessories
    }

    /// A single-part accessory.
    static func accessory(
        _ name: String, _ percent: Int, charging: Bool = false, onPower: Bool = false, offline: Bool = false
    ) -> AccessoryBattery {
        AccessoryBattery(
            id: "acc-\(name)", name: name, kind: .mouse, transport: .bluetooth,
            parts: [
                AccessoryPart(
                    role: .single, percent: percent, isCharging: charging, isOnExternalPower: onPower,
                    isOffline: offline)
            ])
    }

    // MARK: Which accessories, in which order

    /// All, the default: lowest first, as many as the size lists; one without a level (the game
    /// controller, out of reach) comes last.
    @Test func allListsLowestFirst() throws {
        let medium = try Self.layout(Self.plan(.medium, Self.synthetic()))
        #expect(!medium.showsLowest)
        #expect(Self.names(medium) == ["Travel Mouse", "Test Headset", "Backup Keyboard", "Studio Trackpad"])
        let large = try Self.layout(Self.plan(.large, Self.synthetic()))
        #expect(
            Self.names(large) == [
                "Travel Mouse", "Test Headset", "Backup Keyboard", "Studio Trackpad", "Test Buds", "Generic Mouse",
                "Desk Keyboard", "(gameController)",
            ])
        #expect(large.rows.map(\.level.percent) == [18, 45, 50, 54, 61, 70, 76, 30])
        #expect(AccessoriesWidgetPlan.rowSlots(.medium) == 4)
        #expect(AccessoriesWidgetPlan.rowSlots(.large) == 8)
    }

    /// Small always shows the lowest, whatever the configuration says: its edit sheet offers no
    /// choice. Lowest only does the same in medium and large.
    @Test func smallAndLowestOnlyShowTheLowest() throws {
        let configurations = [
            AccessoriesWidgetConfiguration(),
            AccessoriesWidgetConfiguration(mode: .lowest, hidesFullyCharged: true),
        ]
        for configuration in configurations {
            let small = try Self.layout(Self.plan(.small, Self.synthetic(), configuration))
            #expect(small.showsLowest)
            #expect(Self.names(small) == ["Travel Mouse"])
        }
        for size in [WidgetSize.medium, .large] {
            let lowest = try Self.layout(
                Self.plan(size, Self.synthetic(), AccessoriesWidgetConfiguration(mode: .lowest)))
            #expect(lowest.showsLowest)
            #expect(Self.names(lowest) == ["Travel Mouse"])
        }
    }

    /// When the lowest one goes away, the next lowest shows.
    @Test func theNextLowestFollowsWhenTheLowestGoes() throws {
        let rest = try Self.synthetic().filter { $0.name != "Travel Mouse" }
        #expect(try Self.names(Self.layout(Self.plan(.small, rest))) == ["Test Headset"])
    }

    /// The level leaves out the case and parts out of reach: earbuds sort by their lower bud, not
    /// their case, and a bud in use comes before one charging.
    @Test func earbudsSortByTheirLowerBud() throws {
        let buds = try #require(Self.demo.first { $0.hasParts })
        let mouse = Self.accessory("Mouse", 62)
        let layout = try Self.layout(Self.plan(.medium, [mouse, buds]))
        #expect(Self.names(layout) == ["AirPods Pro", "Mouse"])
        let row = try #require(layout.rows.first)
        #expect(row.level.percent == 61)
        #expect(row.hasParts)
        #expect(row.symbolName == "airpods")
        #expect(row.parts.map(\.role) == [.left, .right, .case])
        #expect(row.parts.map(\.charge.text) == ["64%", "61%", "90%"])
        #expect(row.parts.map(\.charge.isCharging) == [false, false, true])
    }

    /// Equal levels keep the reading's order.
    @Test func equalLevelsKeepTheirOrder() throws {
        let accessories = ["A", "B", "C", "D"].map { Self.accessory($0, 50) }
        #expect(try Self.names(Self.layout(Self.plan(.medium, accessories))) == ["A", "B", "C", "D"])
    }

    // MARK: Hide fully charged

    /// Hide fully charged leaves out an accessory whose every part that counts is full; a full case
    /// or a full part out of reach doesn't make one full. Small offers no choice, so it shows the
    /// lowest even when that is full.
    @Test func hideFullyChargedLeavesOutFullAccessories() throws {
        let full = Self.accessory("Full", 100)
        let onCable = Self.accessory("On cable", 100, onPower: true)
        let lastFull = Self.accessory("Out of reach", 100, offline: true)
        let half = Self.accessory("Half", 50)
        let caseOnly = AccessoryBattery(
            id: "acc-case", name: "Case", kind: .headphones, transport: .bluetooth,
            parts: [AccessoryPart(role: .case, percent: 100, isCharging: true, isOnExternalPower: true)])
        let accessories = [full, onCable, lastFull, half, caseOnly]
        #expect(full.isFullyCharged && onCable.isFullyCharged)
        #expect(!lastFull.isFullyCharged && !half.isFullyCharged && !caseOnly.isFullyCharged)

        let hide = AccessoriesWidgetConfiguration(hidesFullyCharged: true)
        #expect(try Self.names(Self.layout(Self.plan(.medium, accessories, hide))) == ["Half", "Out of reach", "Case"])
        #expect(try Self.names(Self.layout(Self.plan(.medium, accessories))).count == 4)
        #expect(try Self.names(Self.layout(Self.plan(.small, [full, onCable], hide))) == ["Full"])
    }

    // MARK: Empty states

    /// None connected, or a macOS that publishes none, says so; hiding every one says they are
    /// full. Every state opens the Accessories page.
    @Test func emptyStates() throws {
        for size in WidgetSize.allCases {
            #expect(Self.plan(size, []) == .empty(.noAccessories))
            #expect(Self.plan(size, nil) == .empty(.noAccessories))
        }
        let full = [Self.accessory("Full", 100)]
        let hide = AccessoriesWidgetConfiguration(mode: .lowest, hidesFullyCharged: true)
        #expect(Self.plan(.medium, full, hide) == .empty(.allFullyCharged))
        #expect(Self.plan(.large, full, hide) == .empty(.allFullyCharged))
        for plan in [Self.plan(.small, []), Self.plan(.medium, full, hide), Self.plan(.small, full)] {
            #expect(plan.route.page == .accessories)
            #expect(plan.route.url.absoluteString == "batterypulse://page/accessories")
        }
    }

    // MARK: Values

    /// An accessory that reports no name takes its kind's; the charge carries the app's tiers and
    /// states.
    @Test func namesChargesAndStates() throws {
        let rows = try Self.layout(Self.plan(.large, Self.synthetic())).rows
        func row(_ name: String) throws -> AccessoryWidgetRow {
            try #require(rows.first { $0.name == .reported(name) })
        }
        let controller = try #require(rows.last)
        #expect(controller.name == .kind(.gameController))
        #expect(controller.level == controller.parts.first?.charge)
        #expect(controller.level.isOffline)
        #expect(controller.level.status == .lastKnownCharge)
        #expect(controller.level.cue == nil, "a charge out of reach is only the last one reported")

        let mouse = try row("Travel Mouse")
        #expect(mouse.level.tier == .low)
        #expect(mouse.level.cue == .low)
        #expect(mouse.level.status == nil)
        #expect(!mouse.hasParts)

        let trackpad = try row("Studio Trackpad")
        #expect(trackpad.level.isCharging)
        #expect(trackpad.level.status == .charging)

        // On its cable without charging: on power, never a bolt.
        let onCable = AccessoryWidgetRow(Self.accessory("Cable", 15, onPower: true), formatter: Self.formatter)
        #expect(!onCable.level.isCharging)
        #expect(onCable.level.status == .connectedToPower)
        #expect(onCable.level.tier == .low)
        let critical = AccessoryWidgetRow(Self.accessory("Low", 8), formatter: Self.formatter)
        #expect(critical.level.cue == .critical)
        let charging = AccessoryWidgetRow(Self.accessory("Charging", 8, charging: true), formatter: Self.formatter)
        #expect(charging.level.tier == .normal)
    }

    /// The reading's time shows on the timeline's stale entry only.
    @Test func theReadingsTimeShowsOnceOld() throws {
        let plan = WidgetTimelinePlan.accessories(at: Self.readAt)
        #expect(plan.entries.count == 2)
        #expect(plan.nextReload == Self.readAt.addingTimeInterval(30 * 60))
        let fresh = try #require(plan.entries.first)
        let stale = try #require(plan.entries.last)
        #expect(stale.isStale && !fresh.isStale)
        #expect(try Self.layout(Self.plan(.medium, Self.demo, entry: fresh)).updated == nil)
        let updated = try Self.layout(Self.plan(.medium, Self.demo, entry: stale)).updated
        #expect(
            updated
                == Self.readAt.formatted(
                    Date.FormatStyle(date: .omitted, time: .shortened, locale: Self.formatter.locale, timeZone: .gmt)))
        #expect(updated?.isEmpty == false)
    }

    // MARK: VoiceOver

    /// One element per accessory, "name, charge", earbuds part by part, and the reading's time
    /// after them; never a symbol's name, never an identifier.
    @Test func voiceOverReadsEachAccessoryInWords() throws {
        let english: (String) -> String = { $0 }
        let layout = try Self.layout(Self.plan(.large, Self.demo))
        let labels = WidgetAccessibility.elements(.accessories(layout)).compactMap { $0.text(english) }
        #expect(
            labels == [
                "Magic Mouse, 18%",
                "AirPods Pro, Left, 64%, Right, 61%, Case, 90%, charging",
                "Magic Keyboard, 76%",
            ])
        let rows = try Self.layout(Self.plan(.large, Self.synthetic())).rows
        let synthetic = rows.compactMap { $0.spokenLabel.text(english) }
        #expect(synthetic.contains("Studio Trackpad, 54%, charging"))
        #expect(synthetic.last == "Game Controller, 30%, Last known charge")
        // An accessory's ID is "acc-" and 16 hex digits.
        #expect(synthetic.count == 8)
        #expect(synthetic.allSatisfy { !$0.contains("acc-") })
        let stale = WidgetTimelinePlan.Entry(date: Self.readAt, showsEstimate: false, isStale: true)
        let old = WidgetAccessibility.elements(Self.plan(.small, Self.demo, entry: stale))
        #expect(old.count == 2)
        #expect(old.last?.text(english)?.hasPrefix("Updated ") == true)
        #expect(
            WidgetAccessibility.elements(Self.plan(.small, [])) == [
                .phrases([.key("No accessories with batteries connected")])
            ])
    }
}
