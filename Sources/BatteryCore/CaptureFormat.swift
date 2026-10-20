import Foundation

// What the app and `bpulse` hand out for bug reports.

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
