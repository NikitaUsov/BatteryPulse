import Foundation
import Testing

@testable import BatteryCore

@Suite struct RawValueDecodingTests {
    @Test func unitsAndSentinels() {
        #expect(RawValueDecoder.decode(.int(5760), as: .milliampHours) == .milliampHours(5760))
        #expect(RawValueDecoder.decode(.int(-612), as: .milliamps) == .milliamps(-612))
        #expect(
            RawValueDecoder.decode(.int(65535), as: .minutes, sentinels: [65535: .notAvailable])
                == .sentinel(.notAvailable))
        #expect(RawValueDecoder.decode(.int(339), as: .minutes, sentinels: [65535: .notAvailable]) == .minutes(339))
        #expect(RawValueDecoder.decode(.int(1), as: .boolean) == .boolean(true))
        #expect(RawValueDecoder.decode(.string("x"), as: .milliwatts) == nil)
        #expect(RawValueDecoder.decode(.int(48), as: .count) == nil)
    }

    @Test func unixTimestamps() {
        #expect(
            RawValueDecoder.decode(.int(1_791_994_651), as: .unixTime)
                == .date(Date(timeIntervalSince1970: 1_791_994_651)))
        #expect(RawValueDecoder.decode(.int(0), as: .unixTime) == .sentinel(.none))
    }

    @Test func negativeRegistersReadAsUnsigned32Bit() {
        // AdapterDetails.FamilyCode on a USB-C PD adapter.
        #expect(RawValueDecoder.decode(.int(-536_854_518), as: .hex) == .bits(0xE000_400A, setBits: []))
        #expect(RawValueDecoder.decode(.int(128), as: .flags) == .bits(0x80, setBits: [7]))
        #expect(RawValueDecoder.decode(.int(0), as: .flags) == .bits(0, setBits: []))
    }

    /// PDOs from the real M5 capture: a 60 W Apple adapter offering 5, 9, 15 and 20 V.
    @Test(arguments: [
        (UInt32(134_320_424), USBPowerDataObject.fixed(voltageMV: 5000, maxCurrentMA: 2960)),
        (184_620, .fixed(voltageMV: 9000, maxCurrentMA: 3000)),
        (307_500, .fixed(voltageMV: 15000, maxCurrentMA: 3000)),
        (409_899, .fixed(voltageMV: 20000, maxCurrentMA: 2990)),
        (409_799, .fixed(voltageMV: 20000, maxCurrentMA: 1990)),
    ])
    func fixedPowerDataObjects(raw: UInt32, expected: USBPowerDataObject) {
        #expect(USBPowerDataObject(rawValue: raw) == expected)
    }

    @Test func otherPowerDataObjectTypes() {
        #expect(USBPowerDataObject(rawValue: 0) == nil)
        #expect(USBPowerDataObject(rawValue: 409_899)?.maxPowerMW == 59800)
        // Variable 5–20 V, 3 A: type 10, max 400 × 50 mV, min 100 × 50 mV, 300 × 10 mA.
        let variable: UInt32 = 0b10 << 30 | 400 << 20 | 100 << 10 | 300
        #expect(
            USBPowerDataObject(rawValue: variable)
                == .variable(minVoltageMV: 5000, maxVoltageMV: 20000, maxCurrentMA: 3000))
        // Battery 5–20 V, 60 W: type 01, power in 250 mW units.
        let battery: UInt32 = 0b01 << 30 | 400 << 20 | 100 << 10 | 240
        #expect(
            USBPowerDataObject(rawValue: battery)
                == .battery(minVoltageMV: 5000, maxVoltageMV: 20000, maxPowerMW: 60000))
        // PPS 3.3–21 V, 3 A: type 11, subtype 00, voltages in 100 mV, current in 50 mA.
        let pps: UInt32 = 0b11 << 30 | 210 << 17 | 33 << 8 | 60
        #expect(
            USBPowerDataObject(rawValue: pps)
                == .programmable(minVoltageMV: 3300, maxVoltageMV: 21000, maxCurrentMA: 3000))
        #expect(USBPowerDataObject(rawValue: 0b11 << 30 | 0b01 << 28) == .otherAugmented(0b11 << 30 | 0b01 << 28))
    }

    /// Active contracts from the real M5 captures: the 4th offer (20 V) at 2.99 A and at 2 A.
    @Test func requestDataObjects() {
        #expect(
            USBRequestDataObject(rawValue: 1_166_322_987)
                == USBRequestDataObject(objectPosition: 4, operatingCurrentMA: 2990, maxCurrentMA: 2990))
        #expect(
            USBRequestDataObject(rawValue: 1_199_775_944)
                == USBRequestDataObject(objectPosition: 4, operatingCurrentMA: 2000, maxCurrentMA: 2000))
        #expect(USBRequestDataObject(rawValue: 0) == nil)
        #expect(RawValueDecoder.decode(.int(0), as: .usbRDO) == .sentinel(.none))
    }

    @Test(arguments: [
        ("AppleSmartBattery", "BatteryData.DesignCapacity", "BatteryData.DesignCapacity"),
        (
            "AppleSmartBattery", "PortControllerInfo[2].PortControllerPortPDO[3]",
            "PortControllerInfo.PortControllerPortPDO"
        ),
        (
            "AppleSmartBattery", "AppleRawAdapterDetails[0].UsbHvcMenu[1].MaxVoltage",
            "AdapterDetails.UsbHvcMenu.MaxVoltage"
        ),
        ("AdapterDetails", "Watts", "AdapterDetails.Watts"),
        ("PowerSource", "Time to Empty", "IOPS.Time to Empty"),
    ])
    func canonicalKeys(captureKey: String, path: String, expected: String) {
        #expect(RawKeyGlossary.canonicalKey(captureKey: captureKey, path: path) == expected)
    }
}
