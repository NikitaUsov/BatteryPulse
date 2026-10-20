import BatteryCore
import Dispatch
import Foundation
import Synchronization
import Testing

@testable import BatteryKit

/// A scripted lockdown connection that records every call. Replies are SYNTHETIC.
final class FakeLink: IDeviceLink {
    let connection: IDeviceConnection
    var connectStatus = IDeviceStatus.success
    var paired: Bool? = true
    var validateStatus = IDeviceStatus.success
    var sessionStatus = IDeviceStatus.success
    var serviceStatus = IDeviceStatus.success
    var values: [String: PropertyValue] = ["DeviceName": .string("Phone"), "ProductType": .string("iPhone18,2")]
    var batteryDomain: PropertyDictionary? = ["BatteryCurrentCapacity": .int(64)]
    /// Replies by `EntryClass`; a class without one gets `Status: Failure`.
    var entries: [String: PropertyDictionary] = ["AppleSmartBattery": ["DesignCapacity": .int(4000)]]
    /// Fails the receive of the request with this `EntryClass`.
    var failingReceive: String?
    /// Makes `connect` block until signalled (at most 10 s), like a device that stopped answering.
    var connectGate: DispatchSemaphore?
    private(set) var calls: [String] = []
    private var lastRequest: PropertyDictionary?

    init(_ connection: IDeviceConnection = .usb, name: String = "Phone") {
        self.connection = connection
        values["DeviceName"] = .string(name)
    }

    func resetCalls() {
        calls = []
    }

    func connect() -> IDeviceStatus {
        calls.append("connect")
        if let connectGate { _ = connectGate.wait(timeout: .now() + 10) }
        return connectStatus
    }

    func isPaired() -> Bool? {
        calls.append("isPaired")
        return paired
    }

    func validatePairing() -> IDeviceStatus {
        calls.append("validatePairing")
        return validateStatus
    }

    func startSession() -> IDeviceStatus {
        calls.append("startSession")
        return sessionStatus
    }

    func copyValue(domain: String?, key: String?) -> PropertyValue? {
        if let domain {
            calls.append("copyValue \(domain)")
            return domain == DiagnosticsRelay.batteryDomain ? batteryDomain.map(PropertyValue.dictionary) : nil
        }
        return key.flatMap { values[$0] }
    }

    func startService(_ name: String) -> IDeviceStatus {
        calls.append("startService \(name)")
        return serviceStatus
    }

    func send(_ message: PropertyDictionary) -> IDeviceStatus {
        calls.append("send " + (message["EntryClass"] ?? message["Request"] ?? .string("?")).description)
        lastRequest = message
        return .success
    }

    func receive() -> (status: IDeviceStatus, reply: PropertyDictionary?) {
        calls.append("receive")
        guard let request = lastRequest else { return (.receiveMessageFailed, nil) }
        let entryClass = request["EntryClass"]?.stringValue
        if let entryClass, entryClass == failingReceive { return (.receiveMessageFailed, nil) }
        guard let entryClass else { return (.success, ["Status": .string("Success")]) }
        guard let entry = entries[entryClass] else { return (.success, ["Status": .string("Failure")]) }
        return (
            .success, ["Status": .string("Success"), "Diagnostics": .dictionary(["IORegistry": .dictionary(entry)])]
        )
    }

    func closeService() {
        calls.append("closeService")
    }

    func stopSession() -> IDeviceStatus {
        calls.append("stopSession")
        return .success
    }

    func disconnect() -> IDeviceStatus {
        calls.append("disconnect")
        return .success
    }
}

@Suite struct IDeviceReaderTests {
    @Test func fullReadInOrder() throws {
        let link = FakeLink()
        let capture = IDeviceReader.capture(id: "UDID-1", links: [link])

        #expect(
            link.calls == [
                "connect", "isPaired", "validatePairing", "startSession",
                "copyValue com.apple.mobile.battery", "startService com.apple.mobile.diagnostics_relay",
                "send AppleSmartBattery", "receive",
                "send AppleSmartBatteryPack", "receive", "send AppleSmartBatteryBank", "receive",
                "send AppleChargerData", "receive", "send Goodbye", "receive",
                "closeService", "stopSession", "disconnect",
            ])
        #expect(
            capture.steps.map(\.call) == [
                .connect, .validatePairing, .startSession, .startService, .closeService, .stopSession, .disconnect,
            ])
        #expect(capture.steps.allSatisfy { $0.status.isSuccess })
        #expect(capture.isPaired == true)
        #expect(capture.device["Connection"] == .string("USB"))
        #expect(capture.device["UniqueDeviceID"] == .string("UDID-1"))
        #expect(capture.device["ProductType"] == .string("iPhone18,2"))
        #expect(capture.lockdownBattery == ["BatteryCurrentCapacity": .int(64)])
        #expect(capture.exchanges.count == 5)
        #expect(capture.problem == nil)
        let battery = try #require(IDeviceBatteryParser.battery(in: capture))
        #expect(battery.designCapacityMAh == 4000)
        #expect(battery.chargePercent == 64)
    }

    @Test func fallsBackToIOPMPowerSource() {
        let link = FakeLink()
        link.entries = ["IOPMPowerSource": ["DesignCapacity": .int(4000)]]
        let capture = IDeviceReader.capture(id: "UDID-1", links: [link])
        #expect(
            link.calls.filter { $0.hasPrefix("send") }.prefix(2) == ["send AppleSmartBattery", "send IOPMPowerSource"])
        #expect(capture.batteryEntry?.className == "IOPMPowerSource")
    }

    @Test func aFailedReceiveEndsTheConversation() {
        let link = FakeLink()
        link.failingReceive = "AppleSmartBatteryPack"
        let capture = IDeviceReader.capture(id: "UDID-1", links: [link])
        // No more requests on a connection whose reply may still be in flight, and no Goodbye;
        // the teardown still happens.
        #expect(
            Array(link.calls.suffix(5)) == [
                "send AppleSmartBatteryPack", "receive", "closeService", "stopSession", "disconnect",
            ])
        #expect(capture.steps.contains(.init(.receive, .receiveMessageFailed)))
        #expect(capture.exchanges.last?.reply == nil)
        #expect(capture.problem == nil, "the battery arrived before the failure")
    }

    @Test func untrustedDeviceStopsBeforeTheService() {
        let link = FakeLink()
        link.paired = false
        link.validateStatus = .invalidHostID
        link.sessionStatus = .invalidHostID
        let wifi = FakeLink(.wifi)
        let capture = IDeviceReader.capture(id: "UDID-1", links: [link, wifi])
        #expect(link.calls == ["connect", "isPaired", "validatePairing", "startSession", "disconnect"])
        #expect(wifi.calls.isEmpty, "trust is per device; Wi-Fi would fail the same way")
        #expect(capture.problem == .notTrusted(.invalidHostID))
    }

    @Test func activeSessionIsUsedButNotStopped() {
        let link = FakeLink()
        link.sessionStatus = .sessionActive
        let capture = IDeviceReader.capture(id: "UDID-1", links: [link])
        #expect(!link.calls.contains("stopSession"))
        #expect(link.calls.last == "disconnect")
        #expect(capture.batteryEntry != nil)
    }

    @Test func refusedServiceSkipsTheRelay() {
        let link = FakeLink()
        link.serviceStatus = .invalidService
        let capture = IDeviceReader.capture(id: "UDID-1", links: [link])
        #expect(!link.calls.contains { $0.hasPrefix("send") || $0 == "closeService" })
        #expect(link.calls.suffix(2) == ["stopSession", "disconnect"])
        #expect(capture.problem == .relayUnavailable(.invalidService))
    }

    @Test func fallsBackToWiFiWhenUSBFails() {
        let usb = FakeLink(.usb)
        usb.connectStatus = .muxError
        let wifi = FakeLink(.wifi)
        let capture = IDeviceReader.capture(id: "UDID-1", links: [usb, wifi])
        #expect(usb.calls == ["connect"])
        #expect(capture.connection == .wifi)
        #expect(capture.batteryEntry != nil)
    }

    @Test func keepsTheAttemptThatGotFurthest() {
        let usb = FakeLink(.usb)
        usb.entries = [:]  // answers, but without a battery
        let wifi = FakeLink(.wifi)
        wifi.connectStatus = .notConnected
        let capture = IDeviceReader.capture(id: "UDID-1", links: [usb, wifi])
        #expect(capture.connection == .usb)
        #expect(capture.problem == .noBattery)
        #expect(IDeviceReader.capture(id: "UDID-1", links: []).problem == .unreachable(.missingResult))
    }

    @Test func infoComesFromTheFirstLinkThatConnects() {
        let usb = FakeLink(.usb)
        usb.connectStatus = .muxError
        let wifi = FakeLink(.wifi)
        wifi.paired = false
        let info = IDeviceReader.info(id: "UDID-1", links: [usb, wifi])
        #expect(
            info
                == IDeviceInfo(
                    id: "UDID-1", name: "Phone", productType: "iPhone18,2", connections: [.usb, .wifi], isPaired: false)
        )
        #expect(wifi.calls == ["connect", "isPaired", "disconnect"], "no session for the list")
    }
}

/// ``IDeviceTransport`` over fake links, put together like ``MobileDeviceTransport``: every
/// call runs on one serial queue, discovery hands the work the grouped attachments.
final class FakeTransport: IDeviceTransport, @unchecked Sendable {
    // `@unchecked`: the links are used on `queue` only, and read by the test once it is idle.
    let queue = DispatchQueue(label: "FakeTransport")
    let attachments: [IDeviceAttachment<FakeLink>]
    let identityTimeout: TimeInterval

    /// One attachment per link; `id` is the device's UDID.
    init(_ links: [(id: String, link: FakeLink)], identityTimeout: TimeInterval = 5) {
        attachments = links.map { IDeviceAttachment(id: $0.id, connection: $0.link.connection, item: $0.link) }
        self.identityTimeout = identityTimeout
    }

    func devices(readingIdentity: Bool) async throws -> [IDeviceInfo] {
        guard readingIdentity else {
            return try await BlockingWork.run(on: queue, timeout: 5) { () throws -> [IDeviceInfo] in
                try self.withAttachedDevices { groups in
                    IDeviceList.sorted(groups.map { IDeviceAttachment.info(for: $0) })
                }
            }
        }
        return try await IDeviceListBuilder.run(on: queue, timeout: 5, identityTimeout: identityTimeout) { builder in
            try self.withAttachedDevices { groups in
                IDeviceReader.readIdentities(of: groups, into: builder) { $0.item }
            }
        }
    }

    func capture(deviceID: String) async throws -> IDeviceCapture {
        try await BlockingWork.run(on: queue, timeout: 5) { () throws -> IDeviceCapture in
            try self.withAttachedDevices { groups throws -> IDeviceCapture in
                guard let group = groups.first(where: { $0.first?.id == deviceID }) else {
                    throw IDeviceError.deviceNotFound
                }
                return IDeviceReader.capture(id: deviceID, links: group.map(\.item))
            }
        }
    }

    /// Waits until the queue has run everything sent to it so far.
    func idle() async throws {
        try await BlockingWork.run(on: queue, timeout: 15) {}
    }

    private func withAttachedDevices<T>(_ body: ([[IDeviceAttachment<FakeLink>]]) throws -> T) throws -> T {
        try body(IDeviceAttachment.grouped(attachments))
    }
}

/// A value set on one thread and read on another: the test target's one locked box.
final class LockedValue<Value: Sendable>: Sendable {
    private let state: Mutex<Value>

    init(_ value: Value) {
        state = Mutex(value)
    }

    var value: Value { state.withLock { $0 } }

    func set(_ newValue: Value) {
        state.withLock { $0 = newValue }
    }
}

extension LockedValue where Value == Int {
    func increment() {
        state.withLock { $0 += 1 }
    }
}

/// `bpulse --devices` and `--device <n>` over ``FakeTransport``. UDIDs are SYNTHETIC. A
/// continuation that is never resumed would hang the run: the time limit names the test, and the
/// CI job's timeout ends it.
@Suite(.timeLimit(.minutes(1))) struct IDeviceListingTests {
    private static let phoneID = "00008150-001A2B3C4D5E801C"
    private static let padID = "00008030-000A11B22C33D4E5"
    private static let otherID = "00008140-000F00000000ABCD"

    @Test func listsByIdentifierWhateverTheNames() async throws {
        let phone = FakeLink(.usb, name: "A phone")
        let pad = FakeLink(.usb, name: "Z pad")
        let transport = FakeTransport([(Self.phoneID, phone), (Self.padID, pad)])
        let named = try await transport.devices(readingIdentity: true)
        #expect(named.map(\.id) == [Self.padID, Self.phoneID])
        #expect(named.map(\.name) == ["Z pad", "A phone"])

        // The pad can't be reached in a later run: the numbering stays.
        pad.connectStatus = .muxError
        let later = try await transport.devices(readingIdentity: true)
        #expect(later.map(\.id) == named.map(\.id))
        #expect(later.map(\.name) == [nil, "A phone"])
    }

    @Test func deviceNumberIsFoundWithoutConnectingToAnyDevice() async throws {
        let phone = FakeLink(.usb, name: "A phone")
        let padUSB = FakeLink(.usb, name: "Z pad")
        let padWiFi = FakeLink(.wifi, name: "Z pad")
        let transport = FakeTransport([(Self.phoneID, phone), (Self.padID, padWiFi), (Self.padID, padUSB)])
        let named = try await transport.devices(readingIdentity: true)
        [phone, padUSB, padWiFi].forEach { $0.resetCalls() }

        // `bpulse --device 2`: the list without identities, then device 2 of it.
        let listed = try await transport.devices(readingIdentity: false)
        #expect(listed.map(\.id) == named.map(\.id))
        #expect(
            listed == [
                IDeviceInfo(id: Self.padID, connections: [.usb, .wifi]),
                IDeviceInfo(id: Self.phoneID, connections: [.usb]),
            ])
        let untouched = [phone, padUSB, padWiFi].allSatisfy { $0.calls.isEmpty }
        #expect(untouched, "listing connects to no device")

        let capture = try await transport.capture(deviceID: listed[1].id)
        #expect(capture.device["UniqueDeviceID"] == .string(named[1].id))
        #expect(capture.device["DeviceName"] == .string("A phone"))
        #expect(padUSB.calls.isEmpty && padWiFi.calls.isEmpty, "only the chosen device is connected to")
        #expect(phone.calls.first == "connect")
    }

    @Test func aDeviceWhoseIdentityFailsIsListedUnnamed() async throws {
        let phone = FakeLink(.usb, name: "Phone")
        let pad = FakeLink(.wifi, name: "Pad")
        pad.connectStatus = .muxError
        let other = FakeLink(.usb, name: "Other")
        let transport = FakeTransport([(Self.phoneID, phone), (Self.padID, pad), (Self.otherID, other)])
        let devices = try await transport.devices(readingIdentity: true)
        #expect(devices.map(\.id) == [Self.padID, Self.otherID, Self.phoneID])
        #expect(devices.map(\.name) == [nil, "Other", "Phone"])
        #expect(devices[0] == IDeviceInfo(id: Self.padID, connections: [.wifi]))
        #expect(IDeviceList.text(devices).hasPrefix("1. Unknown device · Wi-Fi · ID …D4E5\n2. Other"))
    }

    @Test func aStuckIdentityReadCostsTheRestTheirNamesNotTheList() async throws {
        let gate = DispatchSemaphore(value: 0)
        let stuck = FakeLink(.wifi, name: "Stuck")
        stuck.connectGate = gate
        let wifi = FakeLink(.wifi, name: "Wi-Fi")
        let usb = FakeLink(.usb, name: "Cable")
        // Arrival order: the stuck Wi-Fi device first; the USB device is still read first.
        let transport = FakeTransport(
            [(Self.padID, stuck), (Self.otherID, wifi), (Self.phoneID, usb)], identityTimeout: 0.3)

        let started = Date()
        let devices = try await transport.devices(readingIdentity: true)
        #expect(Date().timeIntervalSince(started) < 5)
        #expect(devices.map(\.id) == [Self.padID, Self.otherID, Self.phoneID])
        #expect(devices.map(\.name) == [nil, nil, "Cable"])
        #expect(devices.map(\.connections) == [[.wifi], [.wifi], [.usb]])

        // Once the stuck call returns, the reads still queued are skipped.
        gate.signal()
        try await transport.idle()
        #expect(stuck.calls.first == "connect")
        #expect(wifi.calls.isEmpty)
    }

    @Test func overallDeadline() async throws {
        let queue = DispatchQueue(label: "IDeviceListingTests.deadline")
        let discovery = DispatchSemaphore(value: 0)
        let read = DispatchSemaphore(value: 0)
        let lateRecord = LockedValue<Bool?>(nil)

        // Discovery doesn't end: no list to give.
        await #expect(throws: IDeviceError.timedOut(seconds: 1)) {
            try await IDeviceListBuilder.run(on: queue, timeout: 0.2, identityTimeout: 10) { _ in
                _ = discovery.wait(timeout: .now() + 10)
            }
        }
        discovery.signal()

        // Discovery ended, an identity read didn't: the list as it stands.
        let devices = try await IDeviceListBuilder.run(on: queue, timeout: 0.3, identityTimeout: 10) { builder in
            guard builder.begin([IDeviceInfo(id: "B"), IDeviceInfo(id: "A")]) else { return }
            _ = builder.record(IDeviceInfo(id: "B", name: "Named"), at: 0)
            _ = read.wait(timeout: .now() + 10)
            lateRecord.set(builder.record(IDeviceInfo(id: "A", name: "Late"), at: 1))
        }
        #expect(devices == [IDeviceInfo(id: "A"), IDeviceInfo(id: "B", name: "Named")])
        read.signal()
        try await BlockingWork.run(on: queue, timeout: 15) {}
        #expect(lateRecord.value == false, "the caller has its list: stop reading")
    }

    @Test func errorsPassOn() async {
        let queue = DispatchQueue(label: "IDeviceListingTests.errors")
        await #expect(throws: IDeviceError.subscriptionFailed(.noResources)) {
            try await IDeviceListBuilder.run(on: queue, timeout: 5, identityTimeout: 5) { _ in
                throw IDeviceError.subscriptionFailed(.noResources)
            }
        }
    }
}

@Suite struct IDeviceAttachmentTests {
    private func attachment(_ id: String, _ connection: IDeviceConnection, _ item: Int) -> IDeviceAttachment<Int> {
        IDeviceAttachment(id: id, connection: connection, item: item)
    }

    @Test func groupsPerDeviceUSBFirst() {
        let groups = IDeviceAttachment.grouped([
            attachment("A", .wifi, 1), attachment("B", .usb, 2), attachment("A", .usb, 3), attachment("A", .usb, 4),
            attachment("", .usb, 5), attachment("", .wifi, 6), attachment("C", .unknown, 7), attachment("C", .wifi, 8),
        ])
        #expect(groups.map { $0.map(\.item) } == [[3, 1], [2], [5], [6], [8, 7]])
    }
}

/// The time limit names a test whose continuation is never resumed; the CI job's timeout ends it.
@Suite(.timeLimit(.minutes(1))) struct BlockingWorkTests {
    private let queue = DispatchQueue(label: "BlockingWorkTests")

    @Test func returnsTheResult() async throws {
        #expect(try await BlockingWork.run(on: queue, timeout: 5) { 42 } == 42)
    }

    @Test func passesErrorsOn() async {
        await #expect(throws: IDeviceError.deviceNotFound) {
            try await BlockingWork.run(on: queue, timeout: 5) { () throws -> Int in throw IDeviceError.deviceNotFound }
        }
    }

    @Test func stopsWaitingAtTheDeadline() async {
        let release = DispatchSemaphore(value: 0)
        let started = Date()
        await #expect(throws: IDeviceError.timedOut(seconds: 1)) {
            try await BlockingWork.run(on: queue, timeout: 0.2) { () -> Int in
                _ = release.wait(timeout: .now() + 10)
                return 1
            }
        }
        #expect(Date().timeIntervalSince(started) < 5)
        release.signal()
    }
}
