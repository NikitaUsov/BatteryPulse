import Foundation
import Testing

@testable import BatteryCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let phoneKey = DeviceKey("aaaa") ?? .demo
private let padKey = DeviceKey("bbbb") ?? .demo

private func session(
    _ connections: [IDeviceConnection] = [.usb], listedAt: Date? = now, lastAttempt: Date? = nil,
    problem: IDeviceProblem? = nil, failures: Int = 0
) -> IDeviceSession {
    var session = IDeviceSession()
    session.connections = connections
    session.listedAt = listedAt
    session.lastAttempt = lastAttempt
    session.problem = problem
    session.consecutiveFailures = failures
    return session
}

@Suite struct IDeviceReadPolicyTests {
    private func next(_ s: IDeviceSession, visible: Bool = false, history: Bool = true) -> Date? {
        IDeviceReadPolicy.nextRead(s, isVisible: visible, recordsHistory: history, now: now)
    }

    @Test func firstUSBReadIsImmediate() {
        #expect(next(session()) == .distantPast)
        #expect(next(session(), history: false) == .distantPast, "the first read doesn't need history")
        var reading = session()
        reading.isReading = true
        #expect(next(reading) == nil, "nothing is scheduled while a read runs")
    }

    @Test func wifiIsNeverAutomatic() {
        #expect(next(session([.wifi])) == nil)
        #expect(next(session([.wifi]), visible: true) == nil)
        #expect(next(session([.unknown])) == nil)
        #expect(next(session([])) == nil, "not attached")
        #expect(next(session([.usb, .wifi])) == .distantPast)
    }

    @Test func quickRetriesThenCadence() {
        let delays = (1...4).map { failures in
            next(session(lastAttempt: now, problem: .locked, failures: failures))?.timeIntervalSince(now)
        }
        #expect(delays == [20, 60, 300, 300])
    }

    @Test func retriesStopWithHistoryOffAndPageHidden() {
        #expect(next(session(lastAttempt: now, problem: .locked, failures: 1), history: false) == now + 20)
        #expect(next(session(lastAttempt: now, problem: .locked, failures: 2), history: false) == now + 60)
        #expect(next(session(lastAttempt: now, problem: .locked, failures: 3), history: false) == nil)
    }

    @Test func visiblePageRetriesEveryMinute() {
        #expect(next(session(lastAttempt: now, problem: .locked, failures: 3), visible: true) == now + 60)
        #expect(
            next(session(lastAttempt: now, problem: .relayUnavailable(.invalidService), failures: 5), visible: true)
                == now + 60)
    }

    @Test func notTrustedStopsAfterQuickRetries() {
        let problem = IDeviceProblem.notTrusted(.invalidHostID)
        #expect(next(session(lastAttempt: now, problem: problem, failures: 1)) == now + 20)
        #expect(next(session(lastAttempt: now, problem: problem, failures: 2)) == now + 60)
        #expect(next(session(lastAttempt: now, problem: problem, failures: 3), visible: true) == nil)
    }

    @Test func noBatteryStopsAfterQuickRetries() {
        #expect(next(session(lastAttempt: now, problem: .noBattery, failures: 2)) == now + 60)
        #expect(next(session(lastAttempt: now, problem: .noBattery, failures: 3), visible: true) == nil)
    }

    @Test func timeoutIsNotRetryable() {
        #expect(!IDeviceReadPolicy.isRetryable(.transportFailed(.timedOut)))
        #expect(!IDeviceReadPolicy.isRetryable(.unreachable(.timedOut)))
        #expect(IDeviceReadPolicy.isRetryable(.transportFailed(.receiveMessageFailed)))
        #expect(IDeviceReadPolicy.isRetryable(.unreachable(.notConnected)))
        #expect(IDeviceReadPolicy.isRetryable(.sessionFailed(.sessionInactive)))
        #expect(IDeviceReadPolicy.isRetryable(.locked))
        #expect(!IDeviceReadPolicy.isRetryable(.notTrusted(nil)))
        #expect(!IDeviceReadPolicy.isRetryable(.noBattery))
    }

    @Test func visiblePageEveryMinute() {
        #expect(next(session(lastAttempt: now), visible: true) == now + 60)
        #expect(next(session(lastAttempt: now), visible: true, history: false) == now + 60)
    }

    @Test func backgroundOnlyWithHistoryOn() {
        #expect(next(session(lastAttempt: now)) == now + 300)
        #expect(next(session(lastAttempt: now), history: false) == nil)
    }

    @Test func nextWakeIncludesWiFiExpiry() {
        let wifi = session([.wifi], listedAt: now - 60, lastAttempt: now - 60)
        #expect(
            IDeviceReadPolicy.nextWake([padKey: wifi], visible: nil, recordsHistory: true, now: now)
                == now - 60 + IDeviceReadPolicy.wifiPresenceLifetime)
        // A due read comes first; an expiry that has passed doesn't wake anything.
        let usb = session(lastAttempt: now - 250)
        #expect(
            IDeviceReadPolicy.nextWake([padKey: wifi, phoneKey: usb], visible: nil, recordsHistory: true, now: now)
                == now + 50)
        let expired = session([.wifi], listedAt: now - 3600)
        #expect(IDeviceReadPolicy.nextWake([padKey: expired], visible: nil, recordsHistory: true, now: now) == nil)
        #expect(IDeviceReadPolicy.nextWake([:], visible: nil, recordsHistory: true, now: now) == nil)
        // The visible device reads every minute.
        #expect(
            IDeviceReadPolicy.nextWake([phoneKey: usb], visible: phoneKey, recordsHistory: false, now: now)
                == now - 190)
    }
}

@Suite struct IDeviceRosterTests {
    private func remembered(_ key: DeviceKey, _ name: String?, lastSeen: Date = now - 3600) -> RememberedDevice {
        var device = RememberedDevice(
            id: key, identity: IDeviceIdentity(name: name, deviceClass: "iPhone", productType: "iPhone18,2"),
            battery: IDeviceBattery(chargePercent: 50), at: now - 7200)
        device.lastSeen = lastSeen
        return device
    }

    @Test func sortedByNameNotByConnection() throws {
        let zed = try #require(DeviceKey("0001"))
        let devices = [remembered(zed, "Zed"), remembered(phoneKey, "alpha"), remembered(padKey, "Beta")]
        let sessions = [zed: session(lastAttempt: now)]
        let names = IDeviceRoster.entries(remembered: devices, sessions: sessions, hidden: [], now: now).map(\.name)
        #expect(names == ["alpha", "Beta", "Zed"])
        let unnamed = [remembered(padKey, nil), remembered(phoneKey, nil), remembered(zed, "Zed")]
        let keys = IDeviceRoster.entries(remembered: unnamed, sessions: [:], hidden: [], now: now).map(\.id)
        #expect(keys == [zed, phoneKey, padKey])
        let same = [remembered(padKey, "iPhone"), remembered(phoneKey, "iPhone")]
        #expect(
            IDeviceRoster.entries(remembered: same, sessions: [:], hidden: [], now: now).map(\.id) == [
                phoneKey, padKey,
            ])
    }

    @Test func wifiPresenceExpiresAfterTenMinutes() {
        #expect(IDeviceRoster.connection(of: session([.wifi], listedAt: now - 599), now: now) == .wifi)
        #expect(IDeviceRoster.connection(of: session([.wifi], listedAt: now - 601), now: now) == nil)
        #expect(IDeviceRoster.connection(of: session([.usb], listedAt: now - 3600), now: now) == .usb)
        #expect(IDeviceRoster.connection(of: session([], listedAt: now), now: now) == nil)
        #expect(IDeviceRoster.connection(of: session([.unknown], listedAt: now), now: now) == .unknown)
    }

    @Test func usbBeatsWiFi() {
        #expect(IDeviceRoster.connection(of: session([.wifi, .usb]), now: now) == .usb)
    }

    @Test func unrememberedDeviceAppearsOnlyAfterAnAttempt() {
        let listed = session([.wifi])
        #expect(IDeviceRoster.entries(remembered: [], sessions: [padKey: listed], hidden: [], now: now).isEmpty)
        #expect(IDeviceRoster.entries(remembered: [], sessions: [phoneKey: session()], hidden: [], now: now).isEmpty)
        let attempted = session(lastAttempt: now)
        let entries = IDeviceRoster.entries(remembered: [], sessions: [phoneKey: attempted], hidden: [], now: now)
        #expect(entries.map(\.id) == [phoneKey])
        #expect(entries.first?.isRemembered == false)
        #expect(entries.first?.connection == .usb)
        // Unplugged: a device that was never remembered goes.
        let gone = session([], lastAttempt: now)
        #expect(IDeviceRoster.entries(remembered: [], sessions: [phoneKey: gone], hidden: [], now: now).isEmpty)
    }

    @Test func transientDeviceUsesLockdownName() {
        var untrusted = session(lastAttempt: now, problem: .notTrusted(.invalidHostID), failures: 1)
        untrusted.identity = IDeviceIdentity(name: "Owner's iPad", deviceClass: "iPad", productType: "iPad12,1")
        let entry = IDeviceRoster.entries(remembered: [], sessions: [padKey: untrusted], hidden: [], now: now).first
        #expect(entry?.name == "Owner's iPad")
        #expect(entry?.osName == "iPadOS")
        #expect(entry?.battery == nil)
        #expect(entry?.problem == .notTrusted(.invalidHostID))
    }

    @Test func rememberedDeviceTakesThisSessionsValues() {
        var current = session(lastAttempt: now)
        current.battery = IDeviceBattery(chargePercent: 80)
        current.readAt = now
        current.hasCapture = true
        let device = remembered(phoneKey, "Phone")
        let entry = IDeviceRoster.entries(remembered: [device], sessions: [phoneKey: current], hidden: [], now: now)
        #expect(entry.first?.battery?.chargePercent == 80)
        #expect(entry.first?.readAt == now)
        #expect(entry.first?.hasCapture == true)
        #expect(entry.first?.connection == .usb)
        let offline = IDeviceRoster.entries(remembered: [device], sessions: [:], hidden: [], now: now).first
        #expect(offline?.battery?.chargePercent == 50)
        #expect(offline?.readAt == now - 7200)
        #expect(offline?.lastSeen == now - 3600)
        #expect(offline?.connection == nil)
    }

    @Test func hiddenKeysAreLeftOut() {
        let devices = [remembered(phoneKey, "Phone"), remembered(padKey, "Pad")]
        let sessions = [phoneKey: session(lastAttempt: now)]
        let entries = IDeviceRoster.entries(remembered: devices, sessions: sessions, hidden: [phoneKey], now: now)
        #expect(entries.map(\.id) == [padKey])
    }
}

@Suite struct DemoDeviceTests {
    @Test func demoDeviceIsPlausibleAndAnonymous() {
        let entry = DemoDevice.entry
        #expect(entry.id == .demo)
        #expect(entry.name == "iPhone")
        #expect(entry.deviceClass == "iPhone")
        #expect(entry.connection == .usb)
        let battery = entry.battery
        #expect(battery?.maximumCapacityPercent == 95)
        #expect(battery?.chargePercent == 65)
        #expect(battery?.chargeState == .charging)
        #expect(battery?.cycleCount == 278)
        #expect(battery?.adapter?.watts == 20)
        #expect(battery?.adapter?.serialNumber == nil)
        #expect(battery.map { BatteryPresentation.healthTier(device: $0) } == .normal)
        let ratio = battery?.nominalToDesignPercent ?? 0
        #expect(abs(ratio - 95.4) < 0.1)
        #expect(battery?.firstUseDate.map(IDeviceReport.day) == "2025-10-02")
    }
}
