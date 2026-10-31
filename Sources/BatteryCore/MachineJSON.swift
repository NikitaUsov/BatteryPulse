import Foundation

/// The JSON `bpulse` prints for scripts (`--json`, each line of `--watch --json`, `--device <n>
/// --json`) and Copy JSON puts on the clipboard: the value's own keys plus `formatVersion`, sorted,
/// with ISO 8601 dates.
///
/// Compatibility: keys are only ever added. A rename, a removal or a change of meaning bumps the
/// shape's version and is called out in the release notes. Output without `formatVersion` is
/// 0.6's shape, whose device dates were seconds since 2001. `bpulse --accessories --json` stays a
/// bare array without a version, and ``HistoryExport`` writes its own ``HistoryExport/formatVersion``.
///
/// The version is added here, around the value, so the stored types' `Codable` conformances stay
/// as they are: History and the device store keep their own encoders and files.
public enum MachineJSON {
    /// The `formatVersion` of a Mac's battery, a ``BatterySnapshot``: `bpulse --json`,
    /// `--watch --json` and Copy JSON.
    public static let snapshotFormatVersion = 1
    /// The `formatVersion` of an iPhone's or iPad's battery, an ``IDeviceBattery``: `bpulse
    /// --device <n> --json`, and `--input` of a device capture with `--json`.
    public static let deviceBatteryFormatVersion = 1

    /// `snapshot` pretty-printed, or on one line when `compact` (each reading of `--watch --json`).
    public static func snapshot(_ snapshot: BatterySnapshot, compact: Bool = false) throws -> String {
        try string(snapshot, formatVersion: snapshotFormatVersion, compact: compact)
    }

    /// `battery` pretty-printed.
    public static func deviceBattery(_ battery: IDeviceBattery) throws -> String {
        try string(battery, formatVersion: deviceBatteryFormatVersion, compact: false)
    }

    /// `value`'s keys and `formatVersion` in one object. `value` must encode a keyed container (a
    /// struct with synthesized `Codable`) without a `formatVersion` key of its own.
    static func string(_ value: some Encodable, formatVersion: Int, compact: Bool) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = compact ? [.sortedKeys] : [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(Versioned(value: value, formatVersion: formatVersion))
        return String(decoding: data, as: UTF8.self)
    }

    /// Encodes the value's keys and then `formatVersion` into the same keyed container: asked for
    /// twice at one coding path, `JSONEncoder` returns the container it already made.
    private struct Versioned<Value: Encodable>: Encodable {
        let value: Value
        let formatVersion: Int

        private enum CodingKeys: String, CodingKey {
            case formatVersion
        }

        func encode(to encoder: any Encoder) throws {
            try value.encode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(formatVersion, forKey: .formatVersion)
        }
    }
}
