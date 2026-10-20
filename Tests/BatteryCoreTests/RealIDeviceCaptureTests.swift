import Foundation
import Testing

@testable import BatteryCore

/// Real device captures from `bpulse --device <n> --raw` (see Fixtures/README.md).
@Suite struct RealIDeviceCaptureTests {
    /// iPhone 17 Pro Max (iPhone18,2), iOS 27.0.1, read over USB while charging from a 15 W adapter.
    static let iPhone17ProMax = "iphone17promax-ios27.0.1-usb"

    static func capture(_ name: String) throws -> IDeviceCapture {
        try #require(IDeviceCapture(rawCapture: try fixtureDictionary(name)))
    }

    @Test func iPhone17ProMaxOnIOS27() throws {
        let capture = try Self.capture(Self.iPhone17ProMax)
        #expect(capture.steps.allSatisfy { $0.status == .success })
        let b = try #require(IDeviceBatteryParser.battery(in: capture))
        #expect(b.source == "AppleSmartBattery")
        #expect(b.chargePercent == 65)
        #expect(b.chargeState == .charging)
        #expect(b.isExternalPowerConnected == true)
        #expect(b.currentCapacityMAh == 3151)
        #expect(b.fullChargeCapacityMAh == 4922)
        #expect(b.nominalChargeCapacityMAh == 4800)
        #expect(b.designCapacityMAh == 5030)
        #expect(b.cycleCount == 278)
        #expect(b.voltageMV == 4137)
        #expect(b.amperageMA == 2108)
        #expect(b.instantAmperageMA == 2087)
        #expect(b.adapter?.watts == 15)
        #expect(b.adapter?.adapterDescription == "pd charger")
    }

    /// iOS 27 keeps the temperatures in the pack entry. The gauge's sensor (`Temperature`, 36.5 °C)
    /// wins over the `VirtualTemperature` estimate (35.09 °C), as another reader on the same
    /// iPhone showed 36.5 °C.
    @Test func temperatureIsTheSensorNotTheEstimate() throws {
        let b = try #require(IDeviceBatteryParser.battery(in: try Self.capture(Self.iPhone17ProMax)))
        #expect(b.temperatureCelsius == 36.5)
    }

    @Test func reportOfTheRealIPhone() throws {
        let text = IDeviceReport.text(for: try Self.capture(Self.iPhone17ProMax))
        #expect(text.contains("iPhone18,2 · iOS 27.0.1 (24A446) · USB"))
        #expect(text.contains("65 %  (3151 of 4922 mAh)"))
        #expect(text.contains("4800 mAh  (95.4 % of design)"))
        #expect(text.contains("4922 mAh  (97.9 % of design)"))
        #expect(text.contains("36.5 °C"))
    }

    @Test func maximumCapacityAndFirstUseMatchIOSSettings() throws {
        let b = try #require(IDeviceBatteryParser.battery(in: try Self.capture(Self.iPhone17ProMax)))
        // Settings → Battery → Battery Health on the same iPhone: Maximum Capacity 95 %,
        // Cycle Count 278, First Use October 2025.
        #expect(b.maximumCapacityPercent == 95)
        #expect(b.cycleCount == 278)
        let firstUse = try #require(b.firstUseDate)
        #expect(IDeviceReport.day(firstUse) == "2025-10-02")
    }

    /// The pack's `UUID` identifies the battery; it is redacted like the serial numbers.
    @Test func packIdentifierIsRedacted() throws {
        func withUUID(_ value: PropertyValue) -> PropertyValue {
            switch value {
            case .dictionary(let dictionary):
                .dictionary(
                    dictionary.reduce(into: [:]) { result, item in
                        result[item.key] = item.key == "UUID" ? .int(112_311_953) : withUUID(item.value)
                    })
            case .array(let items): .array(items.map(withUUID))
            default: value
            }
        }
        let fixture = try Self.capture(Self.iPhone17ProMax).rawCapture
        let raw = try #require(withUUID(.dictionary(fixture)).dictionaryValue)
        #expect(String(describing: raw).contains("112311953"))
        let capture = try #require(IDeviceCapture(rawCapture: raw))
        #expect(!String(describing: capture.redactedRawCapture).contains("112311953"))
    }
}
