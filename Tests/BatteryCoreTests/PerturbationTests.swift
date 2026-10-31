import Foundation
import Testing

@testable import BatteryCore

/// NEW-10 (RD C9): a capture with a key removed, its type swapped or an extreme value (0, −1,
/// `Int64.max`) never crashes, and what derives from that key shows "—" (`nil`): never 0, never
/// a wrong number and never another key's value.
///
/// Every key of every fixture is perturbed, containers included, and each reading is compared
/// with two others: the fixture's own and the one without that key.
/// - **Removed:** a shown value keeps its value or becomes `nil`; a list (the cells, the USB
///   power offers) only loses items. The exceptions are the parser's fallbacks, where another key
///   holds the same reading (`Perturbation.macFallbacks`).
/// - **Type swapped:** the reading is the one without the key.
/// - **`Int64.max`:** no key holds one, so the reading is the one without the key; so for 0 and −1,
///   except where they are readings (`Perturbation.readings`): no current, an empty battery.
@Suite struct PerturbationTests {
    @Test(arguments: Fixture.allCases)
    func everyKeyOfAMacCapture(_ fixture: Fixture) throws {
        let capture = PropertyValue.dictionary(try fixtureDictionary(fixture.rawValue))
        let failures = Perturbation.sweep(capture, fallbacks: Perturbation.macFallbacks) {
            Perturbation.shown(BatteryReading(rawCapture: $0.dictionaryValue ?? [:], timestamp: Fixture.timestamp))
        }
        #expect(failures.isEmpty, "\(fixture.rawValue):\n\(failures.joined(separator: "\n"))")
    }

    @Test func everyKeyOfAnIPhoneCapture() throws {
        let capture = PropertyValue.dictionary(try fixtureDictionary(RealIDeviceCaptureTests.iPhone17ProMax))
        let failures = Perturbation.sweep(capture, fallbacks: Perturbation.deviceFallbacks) {
            Perturbation.shown(IDeviceCapture(rawCapture: $0.dictionaryValue ?? [:]))
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    /// Accessories regroup when a key that ties a part to its accessory goes, so what is compared
    /// is the charges: every one shown is one the fixture shows, never a new number.
    @Test func everyKeyOfAnAccessoryCapture() throws {
        let capture = PropertyValue.dictionary(try AccessoryFixture.synthetic.raw())
        func charges(_ capture: PropertyValue) -> [Int] {
            let reading = AccessoryReading(rawCapture: capture.dictionaryValue ?? [:])
            let accessories = reading?.accessories ?? []
            _ = AccessoryReport.text(for: accessories)
            _ = accessories.map { ($0.level, $0.symbolName, $0.hasParts) }
            return accessories.flatMap(\.parts).map(\.percent).sorted()
        }
        let base = charges(capture)
        var failures: [String] = []
        for path in Perturbation.paths(in: capture) {
            let original = try #require(path.value(in: capture))
            for (variant, replacement) in Perturbation.variants(of: original) {
                let shown = charges(path.replacing(in: capture, with: replacement))
                if shown.contains(where: { !(0...100).contains($0) }) {
                    failures.append("\(path) \(variant): a charge outside 0…100 % in \(shown)")
                }
                // A new charge is a reading of the perturbed source itself: an empty part (0); a
                // source the key no longer turns away (without `Type` or `Is Present` it is kept);
                // or one without `Max Capacity`, whose charge is a percentage.
                let added = Perturbation.added(shown, to: base)
                let isEmptyPart = variant == "0" && path.key == AccessoryParser.Key.currentCapacity && added == [0]
                let isAdmitted =
                    ["removed", "swapped"].contains(variant)
                    && [AccessoryParser.Key.type, AccessoryParser.Key.isPresent].contains(path.key)
                let isPercentage = variant == "removed" && path.key == AccessoryParser.Key.maxCapacity
                if !added.isEmpty, !isEmptyPart, !isAdmitted, !isPercentage {
                    failures.append("\(path) \(variant): charges \(added) that the capture doesn't show")
                }
            }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    /// The Developer table decodes every value it has a unit for: an extreme one never traps, in
    /// the decoder or in the formatter the app's cells go through.
    @Test func rawDataDecodesEveryExtremeValue() {
        let kinds: [RawValueKind] = [
            .milliampHours, .millivolts, .milliamps, .milliwatts, .microwattHoursPerSecond, .percent, .celsius,
            .centidegreesCelsius, .decikelvin, .minutes, .seconds, .unixTime, .boolean, .hex, .flags, .usbPDO,
            .usbRDO, .count, .text, .identifier, .other,
        ]
        let values: [PropertyValue] = [
            .int(0), .int(-1), .int(.max), .int(.min), .double(.greatestFiniteMagnitude), .double(-1e300),
            .double(.nan), .double(.infinity), .string("42"), .data(Data([0xFF])), .bool(true),
        ]
        for kind in kinds {
            for value in values {
                if let decoded = RawValueDecoder.decode(value, as: kind) {
                    #expect(!RawDisplayTests.decodedText(decoded).isEmpty)
                }
            }
        }
    }

    /// Every real capture reads inside the plausible ranges, so introducing them changed no
    /// fixture's reading.
    @Test(arguments: Fixture.allCases)
    func everyFixtureReadsInsideThePlausibleRanges(_ fixture: Fixture) throws {
        let s = try fixture.snapshot()
        typealias Plausible = MacPowerParser.Plausible
        #expect(s.currentCapacityMAh.map(Plausible.remainingMAh.contains) == true)
        for capacity in [s.fullChargeCapacityMAh, s.designCapacityMAh] {
            #expect(capacity.map(Plausible.capacityMAh.contains) == true)
        }
        #expect(s.cycleCount != nil)
        #expect(s.voltageMV.map(Plausible.packVoltageMV.contains) == true)
        #expect(s.amperageMA != nil)
        #expect(s.chargePercent != nil)
    }
}

/// Perturbs a capture key by key and reads each result.
enum Perturbation {
    /// A place in a capture: dictionary keys and array indices from the root.
    struct Path: CustomStringConvertible {
        enum Step {
            case key(String)
            case index(Int)
        }

        var steps: [Step]

        /// "AppleSmartBattery.BatteryData.CellVoltage[3]".
        var description: String { text { "[\($0)]" } }
        /// The same with every index as "[i]", as the tables name places.
        var pattern: String { text { _ in "[i]" } }

        /// The last dictionary key on the way.
        var key: String? {
            for step in steps.reversed() { if case .key(let key) = step { return key } }
            return nil
        }

        private func text(index: (Int) -> String) -> String {
            var text = ""
            for step in steps {
                switch step {
                case .key(let key): text += (text.isEmpty ? "" : ".") + key
                case .index(let position): text += index(position)
                }
            }
            return text
        }

        func value(in root: PropertyValue) -> PropertyValue? {
            var current = root
            for step in steps {
                switch (step, current) {
                case (.key(let key), .dictionary(let dictionary)):
                    guard let next = dictionary[key] else { return nil }
                    current = next
                case (.index(let position), .array(let array)) where array.indices.contains(position):
                    current = array[position]
                default:
                    return nil
                }
            }
            return current
        }

        /// `root` with the value here replaced, or removed when `replacement` is `nil`.
        func replacing(in root: PropertyValue, with replacement: PropertyValue?) -> PropertyValue {
            Self.replacing(root, at: steps[...], with: replacement) ?? root
        }

        private static func replacing(
            _ value: PropertyValue, at steps: ArraySlice<Step>, with replacement: PropertyValue?
        ) -> PropertyValue? {
            guard let step = steps.first else { return replacement }
            switch (step, value) {
            case (.key(let key), .dictionary(var dictionary)):
                guard let child = dictionary[key] else { return value }
                dictionary[key] = replacing(child, at: steps.dropFirst(), with: replacement)
                return .dictionary(dictionary)
            case (.index(let position), .array(var array)) where array.indices.contains(position):
                if let replaced = replacing(array[position], at: steps.dropFirst(), with: replacement) {
                    array[position] = replaced
                } else {
                    array.remove(at: position)
                }
                return .array(array)
            default:
                return value
            }
        }
    }

    /// Every value in `capture` but the root, containers included, in key order.
    static func paths(in capture: PropertyValue) -> [Path] {
        var paths: [Path] = []
        func visit(_ value: PropertyValue, _ steps: [Path.Step]) {
            if !steps.isEmpty { paths.append(Path(steps: steps)) }
            switch value {
            case .dictionary(let dictionary):
                for (key, child) in dictionary.sorted(by: { $0.key < $1.key }) { visit(child, steps + [.key(key)]) }
            case .array(let array):
                for (position, item) in array.enumerated() { visit(item, steps + [.index(position)]) }
            default:
                break
            }
        }
        visit(capture, [])
        return paths
    }

    /// What replaces a value: nothing; a value of a type no reader takes for it; and for a number,
    /// 0, −1 and `Int64.max`.
    static func variants(of value: PropertyValue) -> [(name: String, replacement: PropertyValue?)] {
        var variants: [(String, PropertyValue?)] = [("removed", nil)]
        switch value {
        case .string: variants.append(("swapped", .data(Data([0x34, 0x32]))))
        default: variants.append(("swapped", .string("42")))
        }
        switch value {
        case .int, .double: variants += [("0", .int(0)), ("-1", .int(-1)), ("Int64.max", .int(.max))]
        default: break
        }
        return variants
    }

    /// What can be shown from a reading: every stored value, by name, and the values derived
    /// from them. `nil` and an unknown state are left out, as the views leave them out or show
    /// "—"; lists are sorted, so one that lost an item is a part of the whole.
    struct Shown: Equatable {
        var values: [String: String] = [:]
        var lists: [String: [String]] = [:]

        init(_ value: Any?) {
            if let value { add(value, name: "") }
        }

        mutating func add(_ value: Any, name: String) {
            let mirror = Mirror(reflecting: value)
            switch mirror.displayStyle {
            case .optional:
                if let wrapped = mirror.children.first?.value { add(wrapped, name: name) }
            case .struct where !(value is Date):
                for child in mirror.children {
                    let label = child.label ?? "?"
                    add(child.value, name: name.isEmpty ? label : name + "." + label)
                }
            case .collection:
                let items = mirror.children.map { String(describing: $0.value) }
                if !items.isEmpty { lists[name] = items.sorted() }
            default:
                if let state = value as? ChargeState, state == .unknown { return }
                values[name] = String(describing: value)
            }
        }

        mutating func add(_ metrics: [(String, Any?)]) {
            for (name, value) in metrics { if let value { add(value, name: name) } }
        }

        /// What differs from `base` other than by going, by name: a value that changed or
        /// appeared, a list with an item `base` doesn't have.
        func changes(from base: Shown) -> [(name: String, text: String)] {
            let values = self.values.filter { base.values[$0.key] != $0.value }.map {
                ($0.key, "\(base.values[$0.key] ?? "nil") → \($0.value)")
            }
            let lists = self.lists.filter { !Perturbation.added($0.value, to: base.lists[$0.key] ?? []).isEmpty }.map {
                ($0.key, "\(base.lists[$0.key] ?? []) → \($0.value)")
            }
            return (values + lists).sorted { $0.0 < $1.0 }
        }
    }

    /// The items of `list` beyond those in `base`, counting repeats.
    static func added<T: Hashable>(_ list: [T], to base: [T]) -> [T] {
        var remaining = Dictionary(base.map { ($0, 1) }, uniquingKeysWith: +)
        var added: [T] = []
        for item in list {
            if let count = remaining[item], count > 0 { remaining[item] = count - 1 } else { added.append(item) }
        }
        return added
    }

    /// A Mac's reading as the app, the report and the scripts use it. Everything that derives from
    /// the snapshot runs, so a trap anywhere fails the test.
    static func shown(_ reading: BatteryReading) -> Shown {
        let s = reading.snapshot
        var shown = Shown(s)
        shown.add([
            ("capacityToDesignPercent", s.capacityToDesignPercent), ("healthPercent", s.healthPercent),
            ("hardwareChargePercent", s.hardwareChargePercent), ("cycleLifeUsed", s.cycleLifeUsed),
            ("batteryPowerWatts", s.batteryPowerWatts), ("systemPowerInWatts", s.systemPowerInWatts),
            ("systemLoadWatts", s.systemLoadWatts), ("adapterEfficiencyLossWatts", s.adapterEfficiencyLossWatts),
            ("cellVoltageSpreadMV", s.cellVoltageSpreadMV),
            // `false` is also what an unknown request reads.
            ("isChargingVoltagePerCell", s.isChargingVoltagePerCell ? true : nil),
            ("estimatedTimeToEmptyMinutes", s.estimatedTimeToEmptyMinutes),
            ("estimatedTimeToFullMinutes", s.estimatedTimeToFullMinutes),
        ])
        _ = BatteryReport.text(for: s)
        _ = try? MachineJSON.snapshot(s, compact: true)
        _ = HistorySample(s, at: s.timestamp)
        _ = HistoryDay(s, day: "2027-01-15")
        _ = BatteryMotionKey(s)
        _ = CapacityBar.bars(for: s)
        _ = WidgetTimelinePlan(snapshot: s, at: s.timestamp)
        _ = (BatteryPresentation.symbolName(for: s), BatteryPresentation.levelTier(for: s))
        _ = BatteryPresentation.healthTier(for: s)
        return shown
    }

    /// An iPhone's or iPad's reading; without a battery, nothing is shown.
    static func shown(_ capture: IDeviceCapture?) -> Shown {
        guard let capture, let b = IDeviceBatteryParser.battery(in: capture) else { return Shown(nil) }
        var shown = Shown(b)
        shown.add([
            ("nominalToDesignPercent", b.nominalToDesignPercent),
            ("fullChargeToDesignPercent", b.fullChargeToDesignPercent), ("batteryPowerWatts", b.batteryPowerWatts),
        ])
        _ = try? MachineJSON.deviceBattery(b)
        _ = HistorySample(device: b, at: Fixture.timestamp)
        _ = HistoryDay(device: b, day: "2027-01-15")
        _ = BatteryPresentation.healthTier(device: b)
        _ = RememberedDevice.storable(b)
        return shown
    }

    /// A fallback: removing `source`, or a key above or inside it, may change `shown` to what
    /// another key that holds the same reading says.
    typealias Fallback = (source: String, shown: Set<String>, reason: String)

    static let timeRemaining: Set<String> = [
        "timeToEmptyMinutes", "timeToFullMinutes", "estimatedTimeToEmptyMinutes", "estimatedTimeToFullMinutes",
        "isTimeRemainingCalculating",
    ]

    /// The live readings the SMC gives and the registry repeats a minute late.
    static let liveElectrical = timeRemaining.union(["voltageMV", "amperageMA", "batteryPowerWatts", "chargeState"])

    static let macFallbacks: [Fallback] = [
        ("PowerSource.Time to Empty", timeRemaining, "the gauge's AvgTimeToEmpty, or the estimate from capacity"),
        ("PowerSource.Time to Full Charge", timeRemaining, "the gauge's AvgTimeToFull, or the estimate"),
        ("PowerSource.BatteryHealth", ["healthCondition"], "no condition is Normal, as in System Information"),
        (
            "AppleSmartBattery.BatteryData.NominalChargeCapacity", ["capacityToDesignPercent", "healthPercent"],
            "the full-charge capacity stands in for the nominal one"
        ),
        (
            "AppleSmartBattery.NominalChargeCapacity", ["capacityToDesignPercent", "healthPercent"],
            "the full-charge capacity stands in for the nominal one"
        ),
        (
            "AppleSmartBattery.IORegistryEntryChildren[i].BatteryData.Temperature", ["temperatureCelsius"],
            "the SMC's B0AT"
        ),
        ("AppleSmartBattery.IORegistryEntryChildren[i].IOObjectClass", ["temperatureCelsius"], "the SMC's B0AT"),
        (
            "AppleSmartBattery.IORegistryEntryChildren[i].IORegistryEntryChildren[i].BatteryData.CellVoltage",
            ["cellVoltagesMV", "cellVoltageSpreadMV"], "the SMC's cells, when a bank has none"
        ),
        (
            "AppleSmartBattery.IORegistryEntryChildren[i].IORegistryEntryChildren[i].IOObjectClass",
            ["cellVoltagesMV", "cellVoltageSpreadMV"], "the banks left"
        ),
        (
            "AppleSmartBattery.BatteryData.CellVoltage[i]", ["cellVoltageSpreadMV"],
            "a list without a cell reads like a pack with one fewer, whose spread is the cells' left"
        ),
        ("AppleSMC.B0AV", liveElectrical, "the registry's voltage and current"),
        ("AppleSMC.B0AC", liveElectrical, "the registry's voltage and current"),
    ]

    static let deviceFallbacks: [Fallback] = [
        (
            "DiagnosticsRelay[i].Reply.Diagnostics.IORegistry.BatteryData.LifetimeData.NccpFiltered",
            ["maximumCapacityPercent"], "nominal ÷ design capacity, as iOS falls back"
        ),
        (
            "DiagnosticsRelay[i].Request.EntryClass", ["maximumCapacityPercent", "temperatureCelsius"],
            "a reply without its request is no pack's: the battery's own keys stand in"
        ),
        (
            "DiagnosticsRelay[i].Reply.Status", ["maximumCapacityPercent", "temperatureCelsius"],
            "a reply without a status didn't succeed: the battery's own keys stand in"
        ),
        (
            "DiagnosticsRelay[i].Reply.Diagnostics.IORegistry.BatteryData.Temperature", ["temperatureCelsius"],
            "the pack's VirtualTemperature estimate"
        ),
    ]

    /// Keys whose 0 or −1 is a reading, by name.
    static let readings: [String: (zero: Bool, negative: Bool, reason: String)] = [
        "Amperage": (true, true, "no current, or a discharge"),
        "InstantAmperage": (true, true, "no current, or a discharge"),
        "RemainingCapacity": (true, false, "an empty battery"),
        "AppleRawCurrentCapacity": (true, false, "an empty battery"),
        "Current Capacity": (true, false, "an empty battery"),
        "CurrentCapacity": (true, false, "an empty battery"),
        "BatteryCurrentCapacity": (true, false, "an empty battery"),
        "CycleCount": (true, false, "a new battery"),
        "NotChargingReason": (true, false, "no reason"),
        "SlowChargingReason": (true, false, "no reason"),
        "PermanentFailureStatus": (true, false, "no failure"),
        "ChargingCurrent": (true, false, "the charger asks for nothing"),
        "ChargingVoltage": (true, false, "the charger asks for nothing"),
        "SystemPowerIn": (true, true, "nothing from the adapter; the telemetry's own sign"),
        "SystemLoad": (true, true, "the telemetry reads below 0 just after unplugging"),
        "AdapterEfficiencyLoss": (true, false, "no loss"),
        "Temperature": (true, true, "0 °C and −0.01 °C are temperatures (an iPhone's 0 is no reading)"),
        "Time to Empty": (false, true, "−1: macOS is still calculating"),
        "Time to Full Charge": (false, true, "−1: macOS is still calculating"),
        "Index": (true, false, "the first USB power offer"),
        "UsbHvcHvcIndex": (true, false, "the first USB power offer in use"),
        "BankID": (true, false, "the first bank"),
    ]

    /// Whether removing the key at `path` may change `name` to another value.
    static func isFallback(_ path: Path, _ name: String, in fallbacks: [Fallback]) -> Bool {
        let place = path.pattern
        return fallbacks.contains { fallback in
            fallback.shown.contains(name)
                && (place == fallback.source || fallback.source.hasPrefix(place + ".")
                    || fallback.source.hasPrefix(place + "[") || place.hasPrefix(fallback.source + "."))
        }
    }

    /// The failures of perturbing every key of `capture`, read by `read`.
    static func sweep(_ capture: PropertyValue, fallbacks: [Fallback], read: (PropertyValue) -> Shown) -> [String] {
        let base = read(capture)
        var failures: [String] = []
        for path in paths(in: capture) {
            guard let original = path.value(in: capture) else { continue }
            let removed = read(path.replacing(in: capture, with: nil))
            for change in removed.changes(from: base) where !isFallback(path, change.name, in: fallbacks) {
                failures.append("\(path) removed: \(change.name) \(change.text)")
            }
            for (variant, replacement) in variants(of: original) where variant != "removed" {
                // Showing less than without the key is fine: "—" where a fallback had a value.
                let changes = read(path.replacing(in: capture, with: replacement)).changes(from: removed)
                guard !changes.isEmpty else { continue }
                let reading = path.key.flatMap { readings[$0] }
                let isReading =
                    (variant == "0" && reading?.zero == true) || (variant == "-1" && reading?.negative == true)
                if !isReading {
                    let text = changes.map { "\($0.name) \($0.text)" }
                    failures.append("\(path) \(variant) shows more than without the key: \(text)")
                }
            }
        }
        return failures
    }
}
