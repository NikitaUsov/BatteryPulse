import Foundation
import Testing

@testable import BatteryCore

/// The Charge Limit's number from powerd's charging preferences (``SystemChargeLimitSource``).
///
/// No sample of the M5's file is committed yet (A-2 item 6 brings them, redacted, as
/// `Fixtures/powerd/powerd-charging-<n>.plist`), so these tests archive policies themselves, with
/// every key Session A read on the M5 (`soclimit`, `reason`, `drain`, `isEndOfCharge`,
/// `noChargeToFull`, `terminated`, `owner`, `token`), under powerd's class name, as Appendix B's
/// scratch test did. Linux's archiver ignores `setClassName(_:for:)`, so the name is put in the
/// archive's XML by hand.
@Suite struct SystemChargeLimitSourceTests {
    /// The M5's policy at an 80 % limit; `owner` is a process ID [inference: battlimit prints
    /// PowerUIAgent's], the rest as Session A read them.
    static func m5Policy(limit: Int = 80) -> ArchivedPolicy {
        ArchivedPolicy([
            ("soclimit", .int(limit)), ("reason", .string("manualChargeLimit")), ("drain", .bool(true)),
            ("isEndOfCharge", .bool(true)), ("noChargeToFull", .bool(false)), ("terminated", .bool(false)),
            ("owner", .int(489)), ("token", .uuid(UUID())),
        ])
    }

    static func outcome(
        _ policies: [ArchivedPolicy], file: PropertyListSerialization.PropertyListFormat = .binary,
        archive: PropertyListSerialization.PropertyListFormat = .binary
    ) throws -> SystemChargeLimitSource.Outcome {
        let archived = try PolicyArchive.data(policies as NSArray, format: archive)
        return SystemChargeLimitSource.outcome(fileData: try PolicyArchive.file(policies: archived, format: file))
    }

    @Test(arguments: [80, 85, 90, 95, 100])
    func aLimitSetInSystemSettingsGivesItsNumber(limit: Int) throws {
        let outcome = try Self.outcome([Self.m5Policy(limit: limit)])
        #expect(outcome == .manualChargeLimit(limit))
        #expect(outcome.percent == limit)
    }

    /// `send` commits a sample as XML, which reads as the binary file powerd writes.
    @Test(arguments: [
        (PropertyListSerialization.PropertyListFormat.xml, PropertyListSerialization.PropertyListFormat.binary),
        (.binary, .xml), (.xml, .xml),
    ])
    func anXMLCopyReadsTheSame(
        file: PropertyListSerialization.PropertyListFormat, archive: PropertyListSerialization.PropertyListFormat
    ) throws {
        #expect(try Self.outcome([Self.m5Policy()], file: file, archive: archive) == .manualChargeLimit(80))
    }

    /// battlimit listed two entries at the hold, both 80; the file held one.
    @Test func policiesThatAgreeGiveTheirLimit() throws {
        #expect(try Self.outcome([Self.m5Policy(), Self.m5Policy()]) == .manualChargeLimit(80))
        let lone = try PolicyArchive.data(Self.m5Policy(), format: .binary)
        #expect(
            SystemChargeLimitSource.outcome(fileData: try PolicyArchive.file(policies: lone))
                == .manualChargeLimit(80))
    }

    @Test func onlyAPolicyInForceCounts() throws {
        let ended = Self.m5Policy().with("terminated", .bool(true))
        #expect(try Self.outcome([ended]) == .noPolicy)
        #expect(try Self.outcome([ended.with("soclimit", .int(90)), Self.m5Policy()]) == .manualChargeLimit(80))
        // A Boolean archived as an integer reads the same.
        #expect(try Self.outcome([Self.m5Policy().with("terminated", .int(1))]) == .noPolicy)
        #expect(try Self.outcome([Self.m5Policy().with("terminated", .int(0))]) == .manualChargeLimit(80))
    }

    @Test func onlyTheLimitSetInSystemSettingsCounts() throws {
        let other = Self.m5Policy(limit: 90).with("reason", .string("optimizedBatteryCharging"))
        #expect(try Self.outcome([other]) == .otherReason)
        #expect(try Self.outcome([Self.m5Policy().without("reason")]) == .otherReason)
        #expect(try Self.outcome([other, Self.m5Policy()]) == .manualChargeLimit(80))
    }

    @Test(arguments: [75, 79, 101, 105, 0, -80])
    func aLimitOutsideApplesRangeIsNone(limit: Int) throws {
        #expect(try Self.outcome([Self.m5Policy(limit: limit)]) == .outOfRange)
    }

    /// At 100 % the file held no policy (Session A).
    @Test func noPoliciesIsNoLimit() throws {
        #expect(try Self.outcome([]) == .noPolicy)
        #expect(SystemChargeLimitSource.outcome(fileData: try PolicyArchive.file(policies: nil)) == .noPolicy)
    }

    /// A macOS that changes the format makes the number unknown, never wrong, and never traps.
    @Test func anotherShapeIsAnUnknownFormat() throws {
        let archive = try PolicyArchive.data([Self.m5Policy()] as NSArray, format: .binary)
        let file = try PolicyArchive.file(policies: archive)
        let unknown: [(String, Data)] = [
            ("an empty file", Data()),
            ("not a property list", Data("ChargeCtrlPolicy soclimit 80".utf8)),
            ("a cut file", file.prefix(file.count - 40)),
            ("a cut archive", try PolicyArchive.file(policies: archive.prefix(archive.count / 2))),
            ("an archive that isn't one", try PolicyArchive.file(policies: Data("80".utf8))),
            (
                "policies inline",
                try PropertyListSerialization.data(
                    fromPropertyList: ["policies": ["soclimit": 80]], format: .binary, options: 0)
            ),
            (
                "an array for a file",
                try PropertyListSerialization.data(fromPropertyList: [archive], format: .binary, options: 0)
            ),
            ("a file over 64 KB", try PolicyArchive.file(policies: archive, padding: 64 * 1024)),
            (
                "a renamed class",
                try PolicyArchive.file(
                    policies: PolicyArchive.data([Self.m5Policy()] as NSArray, className: "ChargeCtrlPolicyV2"))
            ),
            ("a limit as text", try Self.file(Self.m5Policy().with("soclimit", .string("80")))),
            ("a limit as a Boolean", try Self.file(Self.m5Policy().with("soclimit", .bool(true)))),
            ("the end as text", try Self.file(Self.m5Policy().with("terminated", .string("no")))),
            ("the reason as a value", try Self.file(Self.m5Policy().with("reason", .int(3)))),
            ("the reason as an object of another class", try Self.file(Self.m5Policy().with("reason", .foreign))),
            ("a limit without its number", try Self.file(Self.m5Policy().without("soclimit"))),
            ("limits that disagree", try Self.file(Self.m5Policy(), Self.m5Policy(limit: 90))),
        ]
        for (shape, data) in unknown {
            #expect(SystemChargeLimitSource.outcome(fileData: data) == .unknownFormat, "\(shape)")
        }
        // The size limit is the file's: a file just under it reads.
        let large = try PolicyArchive.file(policies: archive, padding: 60 * 1024)
        #expect(large.count < SystemChargeLimitSource.maximumBytes)
        #expect(SystemChargeLimitSource.outcome(fileData: large) == .manualChargeLimit(80))
    }

    /// The stand-in reads the limit, the reason and the end, and nothing else: an `owner` and a
    /// `token` of classes no decoder allows would fail the read if it touched them.
    @Test func theStandInNeverReadsTheOwnerOrTheToken() throws {
        let policy = Self.m5Policy().with("owner", .foreign).with("token", .foreign)
        let data = try PolicyArchive.data([policy] as NSArray, format: .binary)
        #expect(
            String(decoding: try PolicyArchive.data([policy] as NSArray, format: .xml), as: UTF8.self).contains(
                "PowerdSecret"))
        #expect(
            SystemChargeLimitSource.outcome(fileData: try PolicyArchive.file(policies: data)) == .manualChargeLimit(80))
        // A key of a later macOS changes nothing.
        let later = Self.m5Policy().with("schedule", .string("nightly")).with("priority", .int(2))
        #expect(try Self.outcome([later]) == .manualChargeLimit(80))
    }

    @Test func eachOutcomeLogsItsNameAndOnlyTheLimitItsNumber() {
        typealias Outcome = SystemChargeLimitSource.Outcome
        let outcomes: [Outcome] = [
            .manualChargeLimit(85), .noPolicy, .otherReason, .outOfRange, .unknownFormat, .noFile, .notReadable,
        ]
        #expect(
            outcomes.map(\.summary) == [
                "manualChargeLimit, 85%", "noPolicy", "otherReason", "outOfRange", "unknownFormat", "noFile",
                "notReadable",
            ])
        #expect(outcomes.compactMap(\.percent) == [85])
    }

    /// The M5's samples, once the look shoot brings them (A-2 item 6): each redacted copy gives
    /// the number in its name, and the one taken at 100 % none. Until then the folder is absent.
    @Test func theM5SamplesGiveTheirNumbers() throws {
        let fixtures = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let folder = fixtures.appendingPathComponent("powerd")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in names where name.hasPrefix("powerd-charging-") && name.hasSuffix(".plist") {
            let tag = name.dropFirst("powerd-charging-".count).dropLast(".plist".count)
            let data = try Data(contentsOf: folder.appendingPathComponent(name))
            let outcome = SystemChargeLimitSource.outcome(fileData: data)
            if tag.hasPrefix("none") {
                #expect(outcome == .noPolicy, "\(name)")
            } else {
                let number = try #require(Int(tag.prefix { $0.isNumber }), "\(name)")
                #expect(outcome == .manualChargeLimit(number), "\(name)")
            }
        }
    }

    /// `bpulse --json` has the key only while the number is known, which the snapshot keeps
    /// through a round trip; History and a capture never carry it.
    @Test func theJSONKeyIsThereOnlyWhenKnown() throws {
        var snapshot = try Fixture.m5ChargeLimit.snapshot()
        #expect(snapshot.systemChargeLimitPercent == nil)
        #expect(!(try MachineJSON.snapshot(snapshot)).contains("systemChargeLimitPercent"))
        snapshot.systemChargeLimitPercent = 80
        let json = try MachineJSON.snapshot(snapshot)
        #expect(json.contains(#""systemChargeLimitPercent" : 80"#))
        #expect(json.contains(#""formatVersion" : 1"#))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BatterySnapshot.self, from: Data(json.utf8))
        #expect(decoded.systemChargeLimitPercent == 80)
        // A sample keeps no limit.
        let sample = HistorySample(snapshot, at: snapshot.timestamp)
        #expect(!String(decoding: try JSONEncoder().encode(sample), as: UTF8.self).contains("Limit"))
    }

    static func file(_ policies: ArchivedPolicy...) throws -> Data {
        try PolicyArchive.file(policies: PolicyArchive.data(policies as NSArray, format: .binary))
    }
}

/// A policy archived under powerd's class name, with the values given, each encoded as powerd's
/// would be: integers and Booleans in place, strings and UUIDs as objects.
final class ArchivedPolicy: NSObject, NSSecureCoding {
    enum Value {
        case int(Int)
        case bool(Bool)
        case string(String)
        case uuid(UUID)
        /// An object of a class no decoder knows (`PowerdSecret` in the archive).
        case foreign
    }

    static var supportsSecureCoding: Bool { true }

    let values: [(key: String, value: Value)]

    init(_ values: [(String, Value)]) {
        self.values = values.map { (key: $0.0, value: $0.1) }
    }

    init?(coder: NSCoder) { nil }

    func encode(with coder: NSCoder) {
        for (key, value) in values {
            switch value {
            case .int(let number): coder.encode(number, forKey: key)
            case .bool(let flag): coder.encode(flag, forKey: key)
            case .string(let text): coder.encode(text as NSString, forKey: key)
            case .uuid(let uuid): coder.encode(uuid as NSUUID, forKey: key)
            case .foreign: coder.encode(ForeignValue(), forKey: key)
            }
        }
    }

    /// The same policy with `key` set to `value`.
    func with(_ key: String, _ value: Value) -> ArchivedPolicy {
        ArchivedPolicy(values.filter { $0.key != key }.map { ($0.key, $0.value) } + [(key, value)])
    }

    /// The same policy without `key`.
    func without(_ key: String) -> ArchivedPolicy {
        ArchivedPolicy(values.filter { $0.key != key }.map { ($0.key, $0.value) })
    }
}

/// A value of a class the parser never allows, archived as `PowerdSecret`.
final class ForeignValue: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    override init() {}

    init?(coder: NSCoder) { nil }

    func encode(with coder: NSCoder) {
        coder.encode("secret" as NSString, forKey: "value")
    }
}

/// Archives and files in powerd's shape.
enum PolicyArchive {
    /// `root` archived with secure coding, its policies under powerd's class name (or
    /// `className`), as a binary or XML property list.
    static func data(
        _ root: NSObject, format: PropertyListSerialization.PropertyListFormat = .binary,
        className: String = SystemChargeLimitSource.policyClassName
    ) throws -> Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        archiver.outputFormat = .xml
        archiver.setClassName(className, for: ArchivedPolicy.self)
        archiver.setClassName("PowerdSecret", for: ForeignValue.self)
        archiver.encode(root, forKey: NSKeyedArchiveRootObjectKey)
        archiver.finishEncoding()
        // Linux's archiver names the Swift classes whatever `setClassName` says.
        let xml = String(decoding: archiver.encodedData, as: UTF8.self)
            .replacingOccurrences(
                of: "<string>\(NSStringFromClass(ArchivedPolicy.self))</string>", with: "<string>\(className)</string>"
            )
            .replacingOccurrences(
                of: "<string>\(NSStringFromClass(ForeignValue.self))</string>", with: "<string>PowerdSecret</string>")
        let data = Data(xml.utf8)
        guard format == .binary else { return data }
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
    }

    /// powerd's file around `policies`: a boot session's UUID, the archive, and `padding` bytes
    /// of an extra key.
    static func file(
        policies: Data?, format: PropertyListSerialization.PropertyListFormat = .binary, padding: Int = 0
    ) throws -> Data {
        var plist: [String: Any] = ["bootSessionUUID": "00000000-0000-4000-8000-000000000000"]
        if let policies { plist["policies"] = policies }
        if padding > 0 { plist["padding"] = Data(count: padding) }
        return try PropertyListSerialization.data(fromPropertyList: plist, format: format, options: 0)
    }
}
