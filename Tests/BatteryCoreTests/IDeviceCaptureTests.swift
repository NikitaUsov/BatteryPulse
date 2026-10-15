import Foundation
import Testing

@testable import BatteryCore

/// All captures are SYNTHETIC (see ``SyntheticIDevice``): no real iOS capture exists yet.
@Suite struct IDeviceCaptureTests {
    private typealias S = SyntheticIDevice

    @Test func batteryEntryNeedsASuccessfulReply() throws {
        var capture = S.iPhoneCapture
        let entry = try #require(capture.batteryEntry)
        #expect(entry.className == "AppleSmartBattery")
        #expect(entry.properties == S.iPhoneEntry)
        #expect(capture.registryEntry(forClass: "AppleSmartBatteryPack") == nil, "a Failure reply has no entry")

        capture.exchanges[0].reply = ["Status": .string("UnknownRequest")]
        #expect(capture.batteryEntry == nil)
        #expect(capture.problem == .noBattery)
    }

    @Test func fallsBackToThePowerSourceClass() throws {
        let capture = IDeviceCapture(
            exchanges: [
                .init(request: S.request("AppleSmartBattery"), reply: S.failure),
                .init(request: S.request("IOPMPowerSource"), reply: S.reply(S.iPadEntry)),
            ],
            steps: S.successfulSteps)
        #expect(capture.batteryEntry?.className == "IOPMPowerSource")
        #expect(try #require(IDeviceBatteryParser.battery(in: capture)).source == "IOPMPowerSource")
        #expect(capture.problem == nil)
    }

    @Test func relayHelpers() {
        #expect(DiagnosticsRelay.status(of: S.failure) == "Failure")
        #expect(DiagnosticsRelay.registryEntry(in: S.reply(["A": .int(1)])) == ["A": .int(1)])
        #expect(DiagnosticsRelay.registryEntry(in: ["Status": .string("Success")]) == nil)
        #expect(
            DiagnosticsRelay.registryRequest(entryClass: "AppleSmartBattery")
                == ["Request": .string("IORegistry"), "EntryClass": .string("AppleSmartBattery")])
    }

    /// Through an XML property list and back, as `--device <n> --raw` and `--input` do. On Linux
    /// this also covers the Foundation quirks with 0/1 integers and booleans.
    @Test func rawCaptureRoundTrip() throws {
        var capture = S.iPhoneCapture
        capture.exchanges.append(.init(request: DiagnosticsRelay.goodbye, reply: nil))
        capture.steps.insert(.init(.receive, .receiveMessageFailed), at: 4)
        let xml = try PropertyListSerialization.data(
            fromPropertyList: PropertyValue.dictionary(capture.rawCapture).foundationValue, format: .xml, options: 0)
        let root = try PropertyListSerialization.propertyList(from: xml, format: nil)
        let raw = try #require(PropertyValue.dictionary(fromAny: root))
        let decoded = try #require(IDeviceCapture(rawCapture: raw))

        #expect(decoded == capture)
        #expect(decoded.steps[4].status == .receiveMessageFailed, "0xE800002E survives as an unsigned code")
        #expect(IDeviceBatteryParser.battery(in: decoded) == IDeviceBatteryParser.battery(in: capture))
    }

    @Test func redaction() throws {
        let raw = S.iPhoneCapture.redactedRawCapture
        let device = try #require(raw[IDeviceCapture.Key.device]?.dictionaryValue)
        #expect(device["UniqueDeviceID"] == .string("REDACTED"))
        #expect(device["DeviceName"] == .string("REDACTED"))
        #expect(device["ProductType"] == .string("iPhone12,1"))

        let decoded = try #require(IDeviceCapture(rawCapture: raw))
        let entry = try #require(decoded.batteryEntry?.properties)
        #expect(entry["Serial"] == .string("REDACTED"))
        #expect(entry["DesignCapacity"] == .int(3092))
        // The gauge chip's name is not personal and stays.
        var withGauge = S.iPhoneCapture
        withGauge.exchanges[0].reply = S.reply(S.iPhoneEntry.merging(["DeviceName": .string("bq27z561")]) { $1 })
        let gauge = try #require(IDeviceCapture(rawCapture: withGauge.redactedRawCapture)?.batteryEntry?.properties)
        #expect(gauge["DeviceName"] == .string("bq27z561"))

        let text = String(describing: raw)
        #expect(!text.contains("001A2B3C4D5E801C"))
        #expect(!text.contains("Owner's iPhone"))
        #expect(!text.contains("F5D0000000000000"))
    }

    @Test func tellsDeviceCapturesFromMacCaptures() throws {
        let mac = try Fixture.m5OnBattery.reading().rawCapture
        #expect(!IDeviceCapture.isDeviceCapture(mac))
        #expect(IDeviceCapture(rawCapture: mac) == nil)
        #expect(IDeviceCapture.isDeviceCapture(S.iPhoneCapture.rawCapture))
        #expect(IDeviceCapture(rawCapture: [IDeviceCapture.Key.calls: .array([])]) == IDeviceCapture())
    }

    @Test func unknownCallsAreSkipped() throws {
        let raw: PropertyDictionary = [
            IDeviceCapture.Key.calls: .array([
                .dictionary(["Call": .string("Connect"), "Status": .int(0)]),
                .dictionary(["Call": .string("SomethingNew"), "Status": .int(0)]),
                .dictionary(["Call": .string("StartSession"), "Status": .int(-1)]),
            ])
        ]
        #expect(try #require(IDeviceCapture(rawCapture: raw)).steps == [.init(.connect, .success)])
    }

    // MARK: Problems

    private func capture(_ steps: [(IDeviceCapture.Step.Call, IDeviceStatus)], isPaired: Bool? = true)
        -> IDeviceCapture
    {
        IDeviceCapture(isPaired: isPaired, steps: steps.map { IDeviceCapture.Step($0.0, $0.1) })
    }

    @Test func problems() {
        #expect(IDeviceCapture().problem == .unreachable(.missingResult))
        #expect(capture([(.connect, .muxError)]).problem == .unreachable(.muxError))
        #expect(
            capture([(.connect, .success), (.validatePairing, .success), (.startSession, .passwordProtected)]).problem
                == .locked)
        #expect(
            capture([(.connect, .success), (.validatePairing, .invalidHostID), (.startSession, .invalidHostID)])
                .problem == .notTrusted(.invalidHostID))
        #expect(
            capture([(.connect, .success), (.validatePairing, .missingPairRecord), (.startSession, .noResources)])
                .problem == .notTrusted(.missingPairRecord))
        #expect(
            capture(
                [(.connect, .success), (.validatePairing, .success), (.startSession, .noResources)], isPaired: false
            )
            .problem == .notTrusted(nil))
        #expect(
            capture([(.connect, .success), (.validatePairing, .success), (.startSession, .noResources)]).problem
                == .sessionFailed(.noResources))
        #expect(
            capture([
                (.connect, .success), (.validatePairing, .success), (.startSession, .success),
                (.startService, .serviceProhibited),
            ]).problem == .relayUnavailable(.serviceProhibited))
        #expect(
            capture([
                (.connect, .success), (.validatePairing, .success), (.startSession, .success),
                (.startService, .success), (.receive, .receiveMessageFailed),
            ]).problem == .transportFailed(.receiveMessageFailed))
        #expect(
            capture([
                (.connect, .success), (.validatePairing, .success), (.startSession, .sessionActive),
                (.startService, .success),
            ]).problem == .noBattery)
        #expect(S.iPhoneCapture.problem == nil)
    }

    @Test func untrustedAdviceIsTheTrustPrompt() {
        #expect(IDeviceProblem.notTrusted(nil).description.contains("Unlock the device and tap Trust."))
        #expect(IDeviceProblem.notTrusted(.invalidHostID).description.contains("kAMDInvalidHostIDError"))
        #expect(IDeviceProblem.sessionFailed(.noResources).description.contains("tap Trust"))
    }
}
