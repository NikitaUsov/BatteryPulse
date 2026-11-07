import Foundation

/// The Charge Limit's percentage, as powerd keeps it in its charging preferences file while the
/// Mac is on its adapter: a property list with `bootSessionUUID` and `policies`, the latter an
/// `NSKeyedArchiver` archive of powerd's charge policies. On a MacBook Air M5 with macOS 27 it
/// held one policy with the limit (`soclimit` 80) and the reason `manualChargeLimit` at an 80 %
/// limit, none at 100 %, and none from about 5 minutes after an unplug until the next plug-in.
///
/// Neither the file nor the archive is documented. BatteryPulse reads the file and never writes
/// it, loads no private framework, and never looks up or instantiates powerd's class:
/// ``ChargePolicyRecord`` stands in for it, which Apple documents for an unarchiver
/// (`setClass(_:forClassName:)`). It accepts the one shape the M5 showed, so a macOS update that
/// changes the format makes the number unknown, and says why, rather than wrong. The file is read
/// apart from the battery, on the adapter only (`SystemChargeLimitReader` in BatterySource), and
/// never from a capture.
public enum SystemChargeLimitSource {
    /// The limits System Settings offers: 80 to 100 % (Apple, "About the Charge Limit on Mac").
    public static let range = 80...100

    /// The reason powerd gives the policy of a limit set in System Settings → Battery.
    static let manualReason = "manualChargeLimit"

    /// The name powerd archives each policy under, which ``ChargePolicyRecord`` stands in for.
    static let policyClassName = "ChargeCtrlPolicy"

    /// A larger file is turned down unread: the M5's held one policy in about 1 KB.
    static let maximumBytes = 64 * 1024

    /// What a read of powerd's file found: the limit, or why there is none. Each case logs as its
    /// name (``summary``).
    public enum Outcome: Sendable, Equatable {
        /// A policy in force with the reason `manualChargeLimit`: the limit set in System
        /// Settings → Battery, within ``SystemChargeLimitSource/range``.
        case manualChargeLimit(Int)
        /// No policy in force: no limit below 100 %, or the Mac is on battery.
        case noPolicy
        /// Policies in force, none of them a limit set in System Settings.
        case otherReason
        /// A limit set in System Settings outside 80 to 100 %.
        case outOfRange
        /// Not the shape the parser accepts: another format, a damaged file, or policies that
        /// disagree on the limit.
        case unknownFormat
        /// No file where powerd keeps it.
        case noFile
        /// The file couldn't be read.
        case notReadable

        /// The limit, for ``manualChargeLimit(_:)`` only.
        public var percent: Int? {
            if case .manualChargeLimit(let percent) = self { percent } else { nil }
        }

        /// The case's name, with the percentage for a limit: "manualChargeLimit, 80%",
        /// "noPolicy". Static text and a number, so it logs as public.
        public var summary: String {
            switch self {
            case .manualChargeLimit(let percent): "manualChargeLimit, \(percent)%"
            case .noPolicy: "noPolicy"
            case .otherReason: "otherReason"
            case .outOfRange: "outOfRange"
            case .unknownFormat: "unknownFormat"
            case .noFile: "noFile"
            case .notReadable: "notReadable"
            }
        }
    }

    /// The outcome for the file's contents. Without `policies` it is ``Outcome/noPolicy``; with
    /// anything else than an archive of policies there, ``Outcome/unknownFormat``.
    public static func outcome(fileData data: Data) -> Outcome {
        guard data.count <= maximumBytes, let file = try? PropertyListDecoder().decode(File.self, from: data) else {
            return .unknownFormat
        }
        guard let archive = file.policies else { return .noPolicy }
        guard let policies = policies(in: archive) else { return .unknownFormat }
        return outcome(of: policies)
    }

    /// The one key of the file the parser reads; `bootSessionUUID` and any other key are left
    /// alone.
    struct File: Decodable {
        var policies: Data?
    }

    /// The limit of the policies in force (not terminated) whose reason is `manualChargeLimit`;
    /// policies that disagree on it, or one without it, have none.
    static func outcome(of policies: [ChargePolicyRecord]) -> Outcome {
        let inForce = policies.filter { !$0.terminated }
        let manual = inForce.filter { $0.reason == manualReason }
        guard !manual.isEmpty else { return inForce.isEmpty ? .noPolicy : .otherReason }
        let limits = Set(manual.map(\.soclimit))
        guard limits.count == 1, let only = limits.first, let percent = only else { return .unknownFormat }
        return range.contains(percent) ? .manualChargeLimit(percent) : .outOfRange
    }

    /// The policies in `archive`, decoded with secure coding through ``ChargePolicyRecord``: an
    /// array of them, or one alone. `nil` for an archive of another shape: a class it doesn't
    /// allow, a value of another type, a damaged archive.
    static func policies(in archive: Data) -> [ChargePolicyRecord]? {
        // NSKeyedUnarchiver's integer and Boolean decoders may raise for a value of another type,
        // which Swift can't catch, so every policy's two such values are checked first, as plain
        // property-list values.
        guard let shape = try? PropertyListDecoder().decode(ArchiveShape.self, from: archive), shape.isPlain else {
            return nil
        }
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: archive) else { return nil }
        defer { unarchiver.finishDecoding() }
        // Set explicitly: Linux's Foundation sets neither, and its default policy traps.
        unarchiver.requiresSecureCoding = true
        unarchiver.decodingFailurePolicy = .setErrorAndReturn
        unarchiver.setClass(ChargePolicyRecord.self, forClassName: policyClassName)
        let root = unarchiver.decodeObject(
            of: [NSArray.self, ChargePolicyRecord.self], forKey: NSKeyedArchiveRootObjectKey)
        guard unarchiver.error == nil else { return nil }
        if let record = root as? ChargePolicyRecord { return [record] }
        guard let objects = root as? [Any] else { return nil }
        let records = objects.compactMap { $0 as? ChargePolicyRecord }
        return records.count == objects.count ? records : nil
    }

    /// The archive's objects as plain property-list values, as the stand-in reads them: every
    /// `soclimit` an integer (not a Boolean), every `terminated` a Boolean (Darwin's unarchiver
    /// fails an integer there), and every `reason` a reference to an object rather than a value of
    /// its own.
    struct ArchiveShape: Decodable {
        var objects: [Object]

        enum CodingKeys: String, CodingKey {
            case objects = "$objects"
        }

        struct Object: Decodable {
            var isPlain = true

            enum Key: String, CodingKey {
                case soclimit, terminated, reason
            }

            init(from decoder: any Decoder) throws {
                // A string, a number or data has none of the keys.
                guard let object = try? decoder.container(keyedBy: Key.self) else { return }
                func holds<T: Decodable>(_ type: T.Type, _ key: Key) -> Bool {
                    (try? object.decode(type, forKey: key)) != nil
                }
                let limit = !object.contains(.soclimit) || (holds(Int.self, .soclimit) && !holds(Bool.self, .soclimit))
                let terminated = !object.contains(.terminated) || holds(Bool.self, .terminated)
                let reason = !holds(String.self, .reason) && !holds(Int.self, .reason) && !holds(Bool.self, .reason)
                isPlain = limit && terminated && reason
            }
        }

        var isPlain: Bool { objects.allSatisfy(\.isPlain) }
    }
}

/// Stands in for powerd's charge policy while its archive is decoded, so powerd's class is never
/// looked up: it reads the limit, the reason and whether the policy ended, and no other key (never
/// `owner` or `token`, which name a process and a session).
final class ChargePolicyRecord: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    /// The limit in percent; `nil` without one.
    let soclimit: Int?
    let reason: String?
    let terminated: Bool

    /// A key the policy lacks is never asked for: Linux's unarchiver counts that as a failure.
    init?(coder: NSCoder) {
        soclimit = coder.containsValue(forKey: Key.soclimit) ? coder.decodeInteger(forKey: Key.soclimit) : nil
        reason =
            coder.containsValue(forKey: Key.reason)
            ? coder.decodeObject(of: NSString.self, forKey: Key.reason) as String? : nil
        terminated = coder.containsValue(forKey: Key.terminated) && coder.decodeBool(forKey: Key.terminated)
        super.init()
    }

    /// Never archived: BatteryPulse only reads powerd's policies.
    func encode(with coder: NSCoder) {}

    /// The keys it reads.
    enum Key {
        static let soclimit = "soclimit"
        static let reason = "reason"
        static let terminated = "terminated"
    }
}

/// When the app reads the Charge Limit's number from powerd's file (``SystemChargeLimitSource``):
/// the first reading on the adapter, a plug-in, the Charge Limit's hold beginning or ending
/// (bit 24 of `NotChargingReason`, ``SystemChargeLimit``), and Power appearing; never per poll.
/// Between those reads, a reading on the adapter keeps the number the last read found, and one on
/// battery has none: powerd keeps the policy only on the adapter, and drops it within minutes of
/// an unplug. A pure decision over the readings, which the reader in BatterySource keeps.
public struct SystemChargeLimitReadPolicy: Sendable, Equatable {
    /// Why a reading reads the file; logged as its case name.
    public enum Trigger: String, Sendable, CaseIterable {
        /// The first reading on the adapter since the reads began: the app's launch, a restart of
        /// its monitor, the end of Demo Mode, or `bpulse`'s first.
        case firstOnAdapter
        /// The adapter was plugged in since the last reading.
        case pluggedIn
        /// The Charge Limit's hold began or ended since the last reading: a limit set or changed
        /// at the hold, or the charge reaching it.
        case holdChanged
        /// Power appeared, which shows the number.
        case powerShown
    }

    /// What the last reading showed, `nil` before the first.
    private var last: Seen?

    private struct Seen: Sendable, Equatable {
        var onAdapter: Bool
        var held: Bool
    }

    public init() {}

    /// Why `snapshot`, the newest reading, reads the file; `nil` when it keeps the last number (on
    /// the adapter) or has none (on battery, or with the power unknown). `powerShown`: Power
    /// appeared since the last reading. Records the reading.
    public mutating func trigger(for snapshot: BatterySnapshot, powerShown: Bool) -> Trigger? {
        let onAdapter = snapshot.isExternalPowerConnected == true
        let held = onAdapter && (snapshot.notChargingReason ?? 0) & SystemChargeLimit.heldBit != 0
        let previous = last
        last = Seen(onAdapter: onAdapter, held: held)
        guard onAdapter else { return nil }
        guard let previous else { return .firstOnAdapter }
        if !previous.onAdapter { return .pluggedIn }
        if previous.held != held { return .holdChanged }
        return powerShown ? .powerShown : nil
    }
}
