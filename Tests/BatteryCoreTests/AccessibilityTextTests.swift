import Foundation
import Testing

@testable import BatteryCore

/// What VoiceOver reads for the app's custom components (``AccessibilityText``), on every capture,
/// every Demo Mode scene and an iPhone's capture, in English and in the catalog's Russian: each
/// component is one element, its label the word the component shows, its value what it shows in
/// the same order, the battery's arrow by its direction in words.
struct AccessibilityTextTests {
    typealias Language = WidgetTextBudgetTests.Language

    /// Keys the app adds to the catalog with the views that read these elements. Their English is
    /// checked at once, their Russian once they are in the catalog, which moves them out of this
    /// list.
    static let pendingKeys: Set<String> = [
        "%@ adapter", "%@ from the adapter", "%@ to the Mac", "%@ to the battery", "%@ from the battery",
    ]

    private static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// The catalog's keys.
    private static let catalog: Result<Set<String>, any Error> = Result {
        struct Catalog: Decodable {
            struct Entry: Decodable {}
            var strings: [String: Entry]
        }
        let url = repository.appendingPathComponent("Resources/Localizable.xcstrings")
        return Set(try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url)).strings.keys)
    }

    /// A key's text in `language`; a pending key stays English until it has its Russian.
    static func localize(_ language: Language) -> (String) -> String {
        { key in
            guard !pendingKeys.contains(key) else { return key }
            return (try? WidgetTextBudgetTests.text(key, language)).flatMap { $0 } ?? key
        }
    }

    /// The captures, the Demo Mode scenes, and states the captures lack: an adapter that reports no
    /// rating, a battery inside the dead band on external power and on battery, and an adapter the
    /// registry still lists after unplugging.
    static func snapshots() throws -> [BatterySnapshot] {
        var snapshots = try Fixture.allCases.map { try $0.snapshot() }
        snapshots += DemoScenario.allCases.compactMap { $0.battery?.reading(at: Fixture.timestamp).snapshot }
        var unrated = try Fixture.m5Charging.snapshot()
        unrated.adapter?.watts = nil
        var resting = try Fixture.m5Charging.snapshot()
        resting.amperageMA = 10
        var restingOnBattery = try Fixture.m5OnBattery.snapshot()
        restingOnBattery.amperageMA = -10
        var unplugged = try Fixture.m5Charging.snapshot()
        unplugged.isExternalPowerConnected = false
        snapshots += [unrated, resting, restingOnBattery, unplugged]
        return snapshots
    }

    struct Case: CustomStringConvertible {
        var snapshot: BatterySnapshot
        var language: Language
        var formatter: BatteryFormatter
        var description: String {
            "\(language) \(snapshot.chargeState) \(snapshot.chargePercent ?? -1)"
        }
    }

    static func cases() throws -> [Case] {
        var cases: [Case] = []
        for language in Language.allCases {
            let formatter = try WidgetTextBudgetTests.formatter(language)
            cases += try snapshots().map { Case(snapshot: $0, language: language, formatter: formatter) }
        }
        return cases
    }

    /// Every element of `c`'s snapshot: the power flow, the capacity bars and the rings it has.
    static func elements(_ c: Case) -> [AccessibilityText] {
        let s = c.snapshot
        var elements = [
            AccessibilityText.powerFlow(PowerFlowText(s, formatter: c.formatter)),
            .capacity(CapacityBar.bars(for: s), formatter: c.formatter),
        ]
        if let percent = s.chargePercent { elements.append(.chargeRing(percent: percent, formatter: c.formatter)) }
        if let health = s.healthPercent {
            elements.append(.maximumCapacityRing(percent: health, formatter: c.formatter))
        }
        if let cycles = s.cycleCount {
            let rated = BatteryPresentation.ratedCycles(s.designCycleCount) ?? BatteryPresentation.fallbackRatedCycles
            elements.append(.cycleRing(count: cycles, rated: rated, formatter: c.formatter))
        }
        return elements
    }

    @Test func everyElementHasALabelAndAValue() throws {
        let cases = try Self.cases()
        #expect(cases.count > 40)
        for c in cases {
            let localize = Self.localize(c.language)
            let elements = Self.elements(c)
            #expect(elements.count == 5, "\(c)")
            for element in elements {
                let label = element.labelText(localize)
                let value = element.valueText(localize)
                #expect(!label.isEmpty && !value.isEmpty, "\(c): \(label)")
                #expect(!(label + value).contains("%@"), "\(c): \(label), \(value)")
                // The label is one word of the catalog, the component's title.
                #expect(element.label.keys.count == 1, "\(c): \(label)")
            }
        }
    }

    /// The power flow reads each value the card shows, in the card's order, and nothing it hides.
    @Test func thePowerFlowReadsTheCardInOrder() throws {
        var sawAdapterWithoutInput = false
        for c in try Self.cases() {
            let s = c.snapshot
            let flow = PowerFlowText(s, formatter: c.formatter)
            #expect(flow.showsAdapter == (s.isExternalPowerConnected == true && s.adapter != nil), "\(c)")
            if !flow.showsAdapter { #expect(flow.adapterRating == nil && flow.adapterInput == nil, "\(c)") }
            // The adapter's arrow shows a value only above 0 W, as the card's does: 0 W just after
            // plugging in (the m5-macos27-plugged-in-10s capture) leaves it without one.
            let drawsPower = (s.systemPowerInWatts ?? 0) > 0
            #expect((flow.adapterInput != nil) == (flow.showsAdapter && drawsPower), "\(c)")
            if flow.showsAdapter, s.systemPowerInWatts.map({ $0 <= 0 }) == true { sawAdapterWithoutInput = true }
            let shown = [flow.adapterRating, flow.adapterInput, flow.macLoad, flow.batteryPower, flow.charge]
            let text = AccessibilityText.powerFlow(flow).valueText(Self.localize(c.language))
            var rest = Substring(text)
            for value in shown.compactMap({ $0 }) {
                let range = try #require(rest.range(of: value), "\(c): \(value) in \(text)")
                rest = rest[range.upperBound...]
            }
            // One phrase per node and arrow, the adapter's even without its rating, and two for the
            // battery's name and charge.
            let arrows = [flow.adapterInput, flow.macLoad, flow.batteryPower].compactMap { $0 }.count
            let phrases = (flow.showsAdapter ? 1 : 0) + arrows + (flow.charge == nil ? 0 : 2)
            #expect(AccessibilityText.powerFlow(flow).value.count == phrases, "\(c): \(text)")
        }
        #expect(sawAdapterWithoutInput)
    }

    /// The battery's arrow says which way the power goes, with the dead band the card uses: no
    /// direction and no value where the card shows none.
    @Test func theBatteryArrowSaysItsDirection() throws {
        var seen: Set<String> = []
        for c in try Self.cases() where c.language == .english {
            let flow = PowerFlowText(c.snapshot, formatter: c.formatter)
            let keys = AccessibilityText.powerFlow(flow).keys
            let key = BatteryMotionKey(c.snapshot)
            #expect(keys.contains("%@ to the battery") == (key.flow == .intoBattery), "\(c)")
            #expect(keys.contains("%@ from the battery") == (key.flow == .outOfBattery), "\(c)")
            #expect((flow.batteryPower == nil) == (key.flow == .idle), "\(c)")
            #expect(flow.intoBattery == key.batteryArrowPointsIntoBattery, "\(c)")
            seen.insert("\(key.flow) \(key.isPluggedIn)")
        }
        // Each direction, and the dead band on external power and on battery.
        #expect(seen.isSuperset(of: ["intoBattery true", "outOfBattery false", "idle true", "idle false"]))
    }

    /// The words on the captures, in English: the card's numbers as it shows them.
    @Test func theWordsOnTheCaptures() throws {
        let english = BatteryFormatter(locale: Locale(identifier: "en_US"))
        let charging = try Fixture.m5Charging.snapshot()
        let onBattery = try Fixture.m5OnBattery.snapshot()
        let w = "\u{00A0}W"
        let mAh = "\u{00A0}mAh"
        let flow = AccessibilityText.powerFlow(PowerFlowText(charging, formatter: english))
        #expect(flow.labelText { $0 } == "Power Flow")
        #expect(
            flow.valueText { $0 }
                == "60\(w) adapter, 18.5\(w) from the adapter, 14.0\(w) to the Mac, 4.7\(w) to the battery, Battery, 70%"
        )
        #expect(
            AccessibilityText.powerFlow(PowerFlowText(onBattery, formatter: english)).valueText { $0 }
                == "7.5\(w) to the Mac, 7.5\(w) from the battery, Battery, 70%")
        let capacity = AccessibilityText.capacity(CapacityBar.bars(for: charging), formatter: english)
        #expect(capacity.labelText { $0 } == "Capacity")
        #expect(capacity.valueText { $0 } == "Remaining, 3,896\(mAh), Full charge, 5,866\(mAh), Design, 5,760\(mAh)")
        let cycles = AccessibilityText.cycleRing(count: 1184, rated: 1000, formatter: english)
        #expect([cycles.labelText { $0 }, cycles.valueText { $0 }] == ["Cycle count", "1,184 of 1,000"])
        let health = AccessibilityText.maximumCapacityRing(percent: 74.6, formatter: english)
        #expect([health.labelText { $0 }, health.valueText { $0 }] == ["Maximum capacity", "75%"])
        // An adapter that reports no rating is named alone; keys go through the language, the
        // formatted numbers don't.
        var unrated = charging
        unrated.adapter?.watts = nil
        let shouted = AccessibilityText.powerFlow(PowerFlowText(unrated, formatter: english)).valueText {
            $0.uppercased()
        }
        #expect(shouted.hasPrefix("ADAPTER, 18.5\(w) FROM THE ADAPTER, "))
    }

    /// The bars read in their order, each name before its value, a Mac's and an iPhone's alike.
    @Test func theCapacityBarsReadInTheirOrder() throws {
        let capture = try RealIDeviceCaptureTests.capture(RealIDeviceCaptureTests.iPhone17ProMax)
        let iPhone = try #require(IDeviceBatteryParser.battery(in: capture))
        let iPhoneBars = CapacityBar.bars(
            remainingMAh: iPhone.currentCapacityMAh, fullChargeMAh: iPhone.fullChargeCapacityMAh,
            designMAh: iPhone.designCapacityMAh)
        for language in Language.allCases {
            let formatter = try WidgetTextBudgetTests.formatter(language)
            let localize = Self.localize(language)
            var barSets = try Fixture.allCases.map { CapacityBar.bars(for: try $0.snapshot()) }
            barSets += [iPhoneBars, [CapacityBar(kind: .design, capacityMAh: 5760)]]
            for bars in barSets {
                let text = AccessibilityText.capacity(bars, formatter: formatter).valueText(localize)
                let expected = bars.map { localize($0.kind.titleKey) + ", " + formatter.milliampHours($0.capacityMAh) }
                #expect(text == expected.joined(separator: ", "), "\(language)")
            }
        }
        #expect(iPhoneBars.map(\.kind) == [.remaining, .fullCharge, .design])
    }

    /// Each ring reads the number it shows; the cycle ring also the rated cycles it fills toward.
    @Test func theRingsReadTheirNumbers() throws {
        for c in try Self.cases() {
            let s = c.snapshot
            let localize = Self.localize(c.language)
            let f = c.formatter
            if let percent = s.chargePercent {
                #expect(
                    AccessibilityText.chargeRing(percent: percent, formatter: f).valueText(localize)
                        == f.percent(percent))
            }
            if let health = s.healthPercent {
                let ring = AccessibilityText.maximumCapacityRing(percent: health, formatter: f)
                #expect(ring.valueText(localize) == f.percent(health), "\(c)")
            }
            if let cycles = s.cycleCount {
                let text = AccessibilityText.cycleRing(count: cycles, rated: 1000, formatter: f).valueText(localize)
                let count = cycles.formatted(.number.locale(f.locale))
                let rated = 1000.formatted(.number.locale(f.locale))
                #expect(text == WidgetPhrase.key("%@ of %@", [.verbatim(count), .verbatim(rated)]).text(localize))
                #expect(text.hasPrefix(count) && text.hasSuffix(rated), "\(c): \(text)")
            }
        }
    }

    /// The list the catalog's check reads is every key the elements use; each has its Russian, but
    /// the pending ones, which aren't in the catalog yet; and placeholders are `%@` only.
    @Test func everyKeyIsListedAndTranslated() throws {
        var used: Set<String> = []
        for c in try Self.cases() where c.language == .english {
            used.formUnion(Self.elements(c).flatMap(\.keys))
        }
        #expect(used == AccessibilityText.catalogKeys)
        let catalog = try Self.catalog.get()
        for key in AccessibilityText.catalogKeys {
            #expect(key.replacing("%@", with: "").firstMatch(of: #/%/#) == nil, "\(key)")
            if Self.pendingKeys.contains(key) {
                #expect(!catalog.contains(key), "Remove \"\(key)\" from pendingKeys")
            } else {
                #expect(try WidgetTextBudgetTests.text(key, .russian)?.isEmpty == false, "\(key)")
            }
        }
        #expect(Self.pendingKeys.isSubset(of: AccessibilityText.catalogKeys))
    }

    /// The labels and the bars' names are the words the components show, which the app's views
    /// write as literals.
    @Test func theLabelsAreTheComponentsWords() throws {
        func literals(_ path: String) throws -> Set<String> {
            Set(
                LocalizationCatalogTests.localizedLiterals(
                    in: try SourceScanner.file("BatteryPulseApp/Main/" + path).text))
        }
        let overview = try literals("OverviewView.swift")
        #expect(overview.isSuperset(of: ["Power Flow", "Capacity", "Charge", "Maximum capacity", "Cycle count"]))
        #expect(try literals("Components/PowerFlowView.swift").isSuperset(of: ["Adapter", "Battery"]))
        let bars = Set(CapacityBar.Kind.allCases.map(\.titleKey))
        #expect(try literals("Components/CapacityBars.swift").isSuperset(of: bars))
        #expect(try literals("HealthView.swift").isSuperset(of: ["Maximum capacity", "Cycle count"]))
    }
}
