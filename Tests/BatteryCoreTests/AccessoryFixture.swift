import BatteryCore
import Foundation
import Testing

/// Loads accessory captures from `Fixtures/` (the `bpulse --accessories --raw` format). Not a
/// case of ``Fixture``: those are Mac captures, and tests iterate them as such.
enum AccessoryFixture: String, CaseIterable {
    /// Synthetic: hand-written with the power source keys macOS uses, made-up names and
    /// identifiers. Twelve sources: an internal battery and a UPS (both ignored), a keyboard, a
    /// mouse, a trackpad charging on its cable, earbuds with a case, a headset with a combined
    /// part, a mouse that reports tenths, an offline game controller, a keyboard without `Type`,
    /// and two sources that are dropped (no capacity, not present).
    case synthetic = "synthetic-accessories"

    func raw() throws -> PropertyDictionary {
        let url = try #require(
            Bundle.module.url(forResource: rawValue, withExtension: "plist", subdirectory: "Fixtures"))
        let root = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        return try #require(PropertyValue.dictionary(fromAny: root))
    }

    func reading() throws -> AccessoryReading {
        try #require(AccessoryReading(rawCapture: try raw()))
    }

    func sources() throws -> [PropertyDictionary] {
        try reading().sources
    }

    func accessories() throws -> [AccessoryBattery] {
        try reading().accessories
    }
}
