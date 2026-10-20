import Foundation

// What the app and `bpulse` hand out for bug reports.

extension PropertyValue {
    /// `dictionary` as an XML property list: the capture format of `bpulse --raw`, Export Capture,
    /// `bpulse --record` and the test fixtures, which `bpulse --input` reads.
    public static func xmlPropertyListData(_ dictionary: PropertyDictionary) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: PropertyValue.dictionary(dictionary).foundationValue, format: .xml, options: 0)
    }
}

extension BatterySnapshot {
    /// The snapshot without the battery's and the adapter's serial numbers: what Copy JSON puts on
    /// the clipboard for a public bug report.
    public var redacted: BatterySnapshot {
        var snapshot = self
        snapshot.serialNumber = nil
        snapshot.adapter?.serialNumber = nil
        return snapshot
    }
}
