import Foundation
import Testing

@testable import BatteryCore

@Suite struct AccessoryReportTests {
    @Test func listsEachAccessoryOnOneLine() throws {
        #expect(
            AccessoryReport.text(for: try AccessoryFixture.synthetic.accessories()) == """
                Backup Keyboard (keyboard, Bluetooth): 50 %
                Desk Keyboard (keyboard, Bluetooth): 76 %
                Travel Mouse (mouse, Bluetooth LE): 18 %
                Studio Trackpad (trackpad, USB): 54 % charging
                Test Buds (headphones, Bluetooth): left 64 %, right 61 %, case 90 % charging
                Test Headset (headphones, Bluetooth): 45 %
                game controller (game controller, Bluetooth LE): 30 % (last known)
                Generic Mouse (accessory, Bluetooth LE): 70 %
                """)
    }

    @Test func onPowerWithoutChargingAndUnnamedTransport() {
        let keyboard = AccessoryBattery(
            id: "acc-1", name: "Keys", kind: .keyboard, transport: .other,
            parts: [AccessoryPart(role: .single, percent: 100, isOnExternalPower: true)])
        #expect(AccessoryReport.text(for: [keyboard]) == "Keys (keyboard): 100 % on power")
    }

    @Test func emptyListSaysSo() {
        #expect(AccessoryReport.text(for: []) == "No accessory batteries reported.")
    }

    @Test func jsonCarriesNoIdentifiers() throws {
        let reading = try AccessoryFixture.synthetic.reading()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(reading.accessories)
        let objects = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(objects.count == 8)
        for object in objects {
            #expect(Set(object.keys) == ["kind", "name", "parts", "transport"])
        }

        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("acc-"))
        for source in reading.sources {
            for key in [AccessoryParser.Key.groupIdentifier, AccessoryParser.Key.accessoryIdentifier] {
                if let value = source[key]?.stringValue { #expect(!text.contains(value), "\(value)") }
            }
        }
        #expect(text.contains(#""kind":"headphones""#))
        #expect(text.contains(#""role":"case""#))
    }
}
