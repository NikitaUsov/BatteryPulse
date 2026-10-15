import Foundation
import Testing

@testable import BatteryCore

/// All captures are SYNTHETIC (see ``SyntheticIDevice``): no real iOS capture exists yet.
@Suite struct IDeviceReportTests {
    private func values(_ capture: IDeviceCapture) -> [String: String] {
        Dictionary(
            IDeviceReport.lines(for: capture).map { ($0.label, $0.value) }, uniquingKeysWith: { first, _ in first })
    }

    @Test func iPhoneReport() {
        let v = values(SyntheticIDevice.iPhoneCapture)
        #expect(v["Device"] == "iPhone12,1 · iOS 26.6 · USB", "the owner's device name stays out")
        #expect(v["Charge"] == "9 %  (219 of 2633 mAh)")
        #expect(v["State"] == "Charging")
        #expect(v["Maximum capacity"] == nil)
        #expect(v["Design capacity"] == "3092 mAh")
        #expect(v["Nominal capacity"] == "2564 mAh  (82.9 % of design)")
        #expect(v["Full charge capacity"] == "2633 mAh  (85.2 % of design)")
        #expect(v["Cycles"] == "768")
        #expect(v["Temperature"] == "35.5 °C")
        #expect(v["Voltage"] == "3.88 V")
        #expect(v["Current"] == "+1476 mA  (now +1460 mA)")
        #expect(v["Battery power"] == "+5.7 W")
        #expect(v["Cells"] == "3879 mV")
        #expect(v["Adapter"] == "12 W · usb host · 5.0 V × 2.40 A")
        #expect(v["Source"] == "AppleSmartBattery entry, diagnostics relay")
        #expect(v["Problem"] == nil)
        #expect(v["Calls"] == nil)
    }

    @Test func iPadReport() {
        let v = values(SyntheticIDevice.iPadCapture)
        #expect(v["Device"] == "iPad16,8 · iPadOS 27.0.1 · Wi-Fi")
        #expect(v["Charge"] == "81 %")
        #expect(v["Nominal capacity"] == "7913 mAh  (104.9 % of design)")
        #expect(v["Full charge capacity"] == nil)
        #expect(v["Temperature"] == "33.5 °C")
        #expect(v["Current"] == "+2139 mA")
    }

    @Test func problemReportShowsTheCalls() {
        let capture = IDeviceCapture(
            device: ["ProductType": .string("iPhone18,2"), "Connection": .string("USB")],
            isPaired: false,
            steps: [
                .init(.connect, .success), .init(.validatePairing, .invalidHostID),
                .init(.startSession, .invalidHostID), .init(.disconnect, .success),
            ])
        let v = values(capture)
        #expect(v["Device"] == "iPhone18,2 · USB")
        #expect(v["Problem"]?.contains("Unlock the device and tap Trust.") == true)
        #expect(
            v["Calls"]
                == "Connect 0x0 · IsPaired no · ValidatePairing 0xE800001C kAMDInvalidHostIDError · "
                + "StartSession 0xE800001C kAMDInvalidHostIDError · Disconnect 0x0")
        #expect(v["Charge"] == nil)
    }

    @Test func entryWithoutCapacity() {
        var capture = SyntheticIDevice.iPhoneCapture
        capture.exchanges[0].reply = SyntheticIDevice.reply(["CurrentCapacity": .int(50)])
        #expect(values(capture)["Problem"] == "The battery entry has no capacity values.")
    }

    @Test func textIsAligned() {
        let capture = SyntheticIDevice.iPadCapture
        let lines = IDeviceReport.lines(for: capture)
        let column = (lines.map(\.label.count).max() ?? 0) + 2
        let text = IDeviceReport.text(for: capture)
        #expect(text.hasPrefix("Device"))
        #expect(text.split(separator: "\n").map { String($0.dropFirst(column)) } == lines.map(\.value))
    }

    @Test func signedIntegers() {
        #expect(IDeviceReport.signedInteger(1476) == "+1476")
        #expect(IDeviceReport.signedInteger(-612) == "-612")
        #expect(IDeviceReport.signedInteger(0) == "0")
    }
}

@Suite struct IDeviceListTests {
    private let phone = IDeviceInfo(
        id: "00008150-001A2B3C4D5E801C", name: "Owner's iPhone", productType: "iPhone18,2",
        productVersion: "27.0.1", deviceClass: "iPhone", connections: [.usb, .wifi], isPaired: true)
    private let pad = IDeviceInfo(
        id: "00008030-000A11B22C33D4E5", name: "iPad", productType: "iPad12,1", productVersion: "27.0.1",
        deviceClass: "iPad", connections: [.usb], isPaired: false)

    @Test func stableOrder() {
        #expect(IDeviceList.sorted([phone, pad]).map(\.name) == ["Owner's iPhone", "iPad"])
        #expect(IDeviceList.sorted([pad, phone]) == IDeviceList.sorted([phone, pad]))
        let unnamed = IDeviceInfo(id: "B")
        let other = IDeviceInfo(id: "A")
        #expect(IDeviceList.sorted([unnamed, other]).map(\.id) == ["A", "B"])
    }

    @Test func text() {
        #expect(
            IDeviceList.text([phone, pad]) == """
                1. Owner's iPhone · iPhone18,2 · iOS 27.0.1 · USB + Wi-Fi · ID …801C
                2. iPad · iPad12,1 · iPadOS 27.0.1 · USB · ID …D4E5
                   Not trusted: Unlock the device and tap Trust.
                """)
        #expect(IDeviceList.line(for: IDeviceInfo(id: "")) == "Unknown device · ID …")
    }

    @Test func redactedIdentifier() {
        #expect(IDeviceInfo.redactedIdentifier("00008150-001A2B3C4D5E801C") == "…801C")
        #expect(IDeviceInfo.redactedIdentifier("short") == "…")
    }

    @Test func connections() {
        #expect(IDeviceConnection(interfaceType: 1) == .usb)
        #expect(IDeviceConnection(interfaceType: 2) == .wifi)
        #expect(IDeviceConnection(interfaceType: 0) == .unknown)
        #expect(IDeviceConnection(interfaceType: 3) == .unknown)
    }

    @Test func statusDescriptions() {
        #expect(IDeviceStatus.success.description == "0x0")
        #expect(IDeviceStatus(code: -402_653_158) == .passwordProtected)
        #expect(IDeviceStatus.passwordProtected.description == "0xE800001A kAMDPasswordProtectedError")
        #expect(IDeviceStatus(rawValue: 0xE800_00FF).description == "0xE80000FF")
    }
}
