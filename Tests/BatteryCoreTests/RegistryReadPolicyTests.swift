import Foundation
import Testing

@testable import BatteryCore

struct RegistryReadPolicyTests {
    // MARK: - The rule

    @Test func theAppReusesTheRegistryForFiveMinutes() {
        #expect(RegistryReadPolicy.app.cachesOnPolls == RegistryReadPolicy.cachesOnPolls)
        #expect(RegistryReadPolicy.app.safetyNetAge == .seconds(300))
        #expect(RegistryReadPolicy.defaultSafetyNetAge == .seconds(300))
    }

    @Test(arguments: [true, false])
    func everyReadButAPollFetchesTheRegistry(cachesOnPolls: Bool) {
        let policy = RegistryReadPolicy(cachesOnPolls: cachesOnPolls)
        for age in [nil, Duration.zero, .seconds(1), .seconds(299), .seconds(300), .seconds(3600)] {
            #expect(policy.rereadsRegistry(isPoll: false, age: age, isShown: false))
            #expect(policy.rereadsRegistry(isPoll: false, age: age, isShown: true))
        }
    }

    @Test(arguments: [true, false])
    func aPollReusesTheRegistryUntilTheSafetyNet(cachesOnPolls: Bool) {
        let policy = RegistryReadPolicy(cachesOnPolls: cachesOnPolls)
        #expect(policy.rereadsRegistry(isPoll: true, age: nil, isShown: false), "the first read fetches it")
        #expect(policy.rereadsRegistry(isPoll: true, age: .zero, isShown: false) == !cachesOnPolls)
        #expect(policy.rereadsRegistry(isPoll: true, age: .seconds(60), isShown: false) == !cachesOnPolls)
        #expect(policy.rereadsRegistry(isPoll: true, age: .milliseconds(299_999), isShown: false) == !cachesOnPolls)
        #expect(policy.rereadsRegistry(isPoll: true, age: .seconds(300), isShown: false), "5 minutes old")
        #expect(policy.rereadsRegistry(isPoll: true, age: .seconds(3600), isShown: false))
    }

    @Test(arguments: [true, false])
    func aPollFetchesTheRegistryWhilePowerOrRawDataIsShown(cachesOnPolls: Bool) {
        let policy = RegistryReadPolicy(cachesOnPolls: cachesOnPolls)
        for age in [Duration.zero, .seconds(1), .seconds(299)] {
            #expect(policy.rereadsRegistry(isPoll: true, age: age, isShown: true))
        }
    }

    /// G-14b's other outcome: a 60-second safety net is the same rule with another age.
    @Test(arguments: [true, false])
    func theSafetyNetAgeIsTheOnlyOtherKnob(cachesOnPolls: Bool) {
        let policy = RegistryReadPolicy(cachesOnPolls: cachesOnPolls, safetyNetAge: .seconds(60))
        #expect(policy.rereadsRegistry(isPoll: true, age: .seconds(59), isShown: false) == !cachesOnPolls)
        #expect(policy.rereadsRegistry(isPoll: true, age: .seconds(60), isShown: false))
    }

    // MARK: - Merges over the M5 captures

    /// A capture's dictionaries, as a read fetches them.
    private static func registry(of reading: BatteryReading) -> RegistryCapture {
        RegistryCapture(
            smartBattery: reading.smartBattery, powerSource: reading.powerSource,
            adapterDetails: reading.adapterDetails)
    }

    /// The real captures that carry the SMC's battery keys.
    static let smcFixtures: [Fixture] = [.m5OnBatterySMC, .m5PluggedIn10s, .m5Unplugged]

    @Test(arguments: Fixture.allCases)
    func aCaptureParsesLikeItsDictionaries(_ fixture: Fixture) throws {
        let reading = try fixture.reading()
        let parsed = BatteryReading(
            registry: Self.registry(of: reading), smc: reading.smc, timestamp: Fixture.timestamp)
        #expect(parsed == reading)
    }

    @Test func aBatteryNeedsTheRegistryOrThePowerSource() {
        #expect(!RegistryCapture().hasBattery)
        #expect(!RegistryCapture(adapterDetails: ["Watts": .int(60)]).hasBattery)
        #expect(RegistryCapture(smartBattery: [:]).hasBattery)
        #expect(RegistryCapture(powerSource: [:]).hasBattery)
    }

    /// A poll that reuses the registry merges the SMC's newer live pair into the SMC values it
    /// keeps: the voltage and current are the newer ones, everything else is the capture's.
    @Test(arguments: smcFixtures)
    func aReusedRegistryTakesTheNewerLivePair(_ fixture: Fixture) throws {
        let full = try fixture.reading()
        let live = try #require(SMCBattery.liveElectrical(in: full.smc))
        // Further in the same direction, so the charge state stays.
        let voltage = live.voltageMV - 40
        let current = live.currentMA + (live.currentMA < 0 ? -150 : 150)

        var cache = SMCValueCache()
        let start = ContinuousClock.now
        for group in SMCValueCache.Group.allCases {
            cache.store(SMCBattery.values(in: full.smc), for: group, at: start)
        }
        cache.store(Self.livePair(voltageMV: voltage, currentMA: current), for: .live, at: start + .seconds(10))
        let poll = BatteryReading(registry: Self.registry(of: full), smc: cache.capture, timestamp: Fixture.timestamp)

        var expected = full.snapshot
        expected.voltageMV = voltage
        expected.amperageMA = current
        #expect(poll.snapshot == expected)
        #expect(poll.smartBattery == full.smartBattery)
        #expect(poll.smc.count == full.smc.count)
    }

    /// Values of different ages in one snapshot: one capture's registry with another's SMC values.
    /// The registry's values stay, the cells and temperature among them (on macOS 27 the SMC is
    /// their second source), and only the live pair comes from the SMC.
    @Test(arguments: smcFixtures)
    func theRegistryKeepsItsValuesBesideAnotherCapturesSMC(_ fixture: Fixture) throws {
        let registry = try fixture.reading()
        for other in Self.smcFixtures where other != fixture {
            let smc = try other.reading().smc
            let live = try #require(SMCBattery.liveElectrical(in: smc))
            let mixed = BatteryReading(registry: Self.registry(of: registry), smc: smc, timestamp: Fixture.timestamp)
            let snapshot = mixed.snapshot
            #expect(snapshot.voltageMV == live.voltageMV)
            #expect(snapshot.amperageMA == live.currentMA)
            #expect(snapshot.temperatureCelsius == registry.snapshot.temperatureCelsius)
            #expect(snapshot.cellVoltagesMV == registry.snapshot.cellVoltagesMV)
            #expect(snapshot.fullChargeCapacityMAh == registry.snapshot.fullChargeCapacityMAh)
            #expect(snapshot.cycleCount == registry.snapshot.cycleCount)
            #expect(snapshot.chargingCurrentMA == registry.snapshot.chargingCurrentMA)
            #expect(snapshot.systemPowerInMW == registry.snapshot.systemPowerInMW)
            #expect(snapshot.adapter == registry.snapshot.adapter)
            #expect(snapshot.gaugeUpdatedAt == registry.snapshot.gaugeUpdatedAt)
        }
    }

    /// 10 s after the adapter went in, macOS and the registry still say "not charging"; a poll that
    /// reuses that registry still follows the SMC's charge current, as 0.4's plug-in logic does.
    @Test func aReusedRegistryStillFollowsTheChargeCurrent() throws {
        let pluggedIn = try Fixture.m5PluggedIn10s.reading()
        let onBattery = try Fixture.m5OnBatterySMC.reading()
        let charging = try #require(SMCBattery.liveElectrical(in: pluggedIn.smc))

        let poll = BatteryReading(
            registry: Self.registry(of: pluggedIn),
            smc: SMCBattery.capture(
                Self.livePair(voltageMV: charging.voltageMV, currentMA: charging.currentMA + 100)
                    + SMCBattery.values(in: onBattery.smc).filter { !SMCBattery.liveKeys.contains($0.key) }),
            timestamp: Fixture.timestamp)
        #expect(poll.snapshot.chargeState == .charging)
        #expect(poll.snapshot.isTimeRemainingCalculating)
        #expect(poll.snapshot.amperageMA == charging.currentMA + 100)
    }

    /// `B0AV` and `B0AC` as the M5's SMC answers them: little-endian `ui16` and `si16`.
    private static func livePair(voltageMV: Int, currentMA: Int) -> [SMCRawValue] {
        let voltage = UInt16(voltageMV)
        let current = UInt16(bitPattern: Int16(currentMA))
        return [
            SMCRawValue(
                key: "B0AV", info: SMCKeyInfo(size: 2, type: "ui16", attributes: 0x84),
                payload: [UInt8(voltage & 0xFF), UInt8(voltage >> 8)]),
            SMCRawValue(
                key: "B0AC", info: SMCKeyInfo(size: 2, type: "si16", attributes: 0x84),
                payload: [UInt8(current & 0xFF), UInt8(current >> 8)]),
        ]
    }

    // MARK: - The field signal

    private static let earlier = Date(timeIntervalSince1970: 1_792_045_678)
    private static let later = Date(timeIntervalSince1970: 1_792_045_735)

    /// Whether a read that begins and ends now, finding `updated`, saw a missed update.
    private static func fetch(_ updated: Date?, into watch: inout RegistryUpdateWatch) -> Bool {
        let mark = watch.mark
        return watch.fetched(updated: updated, mark: mark)
    }

    @Test func anUpdateWithoutANotificationIsMissed() {
        var watch = RegistryUpdateWatch()
        let first = Self.fetch(Self.earlier, into: &watch)
        let same = Self.fetch(Self.earlier, into: &watch)
        let newer = Self.fetch(Self.later, into: &watch)
        let again = Self.fetch(Self.later, into: &watch)
        #expect(!first, "the first fetch has nothing to compare")
        #expect(!same, "the same data")
        #expect(newer, "new data, and no notification")
        #expect(!again)
    }

    @Test func anUpdateAfterANotificationIsNotMissed() {
        var watch = RegistryUpdateWatch()
        _ = Self.fetch(Self.earlier, into: &watch)
        watch.notificationArrived()
        let missed = Self.fetch(Self.later, into: &watch)
        #expect(!missed)
    }

    /// The registry changed just before a read fetched it, and its notification came while the
    /// read was under way: the change was announced.
    @Test func aNotificationDuringTheReadCounts() {
        var watch = RegistryUpdateWatch()
        _ = Self.fetch(Self.earlier, into: &watch)
        let mark = watch.mark
        watch.notificationArrived()
        let missed = watch.fetched(updated: Self.later, mark: mark)
        #expect(!missed)
    }

    /// A notification that came during the last read counts for the next one, whose read may be
    /// the first to see its change.
    @Test func aNotificationDuringTheLastReadCountsForTheNext() {
        var watch = RegistryUpdateWatch()
        let mark = watch.mark
        watch.notificationArrived()
        _ = watch.fetched(updated: Self.earlier, mark: mark)
        let missed = Self.fetch(Self.later, into: &watch)
        #expect(!missed)
    }

    @Test func aReadWithoutAnUpdateTimeChangesNothing() {
        var watch = RegistryUpdateWatch()
        _ = Self.fetch(Self.earlier, into: &watch)
        let none = Self.fetch(nil, into: &watch)
        let newer = Self.fetch(Self.later, into: &watch)
        #expect(!none)
        #expect(newer, "compared with the last update time found")
    }

    @Test func aResetForgetsTheLastFetch() {
        var watch = RegistryUpdateWatch()
        _ = Self.fetch(Self.earlier, into: &watch)
        watch.reset()
        let afterReset = Self.fetch(Self.later, into: &watch)
        let again = Self.fetch(Self.later, into: &watch)
        #expect(!afterReset, "Demo Mode or a stop came in between")
        #expect(!again)
    }
}
