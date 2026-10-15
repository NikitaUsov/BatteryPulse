import BatteryCore
import Dispatch
import Foundation
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
    private(set) var calls: [String] = []
    private var lastRequest: PropertyDictionary?

    init(_ connection: IDeviceConnection = .usb) {
        self.connection = connection
    }

    func connect() -> IDeviceStatus {
        calls.append("connect")
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

@Suite struct BlockingWorkTests {
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
