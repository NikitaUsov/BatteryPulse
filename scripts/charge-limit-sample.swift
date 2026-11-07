// Makes a redacted copy of powerd's charging preferences, for a test fixture of the Charge Limit's
// number (plan-0.8.0 A-2 item 6). The M5 session's charge-limit step runs it at each read, from the
// repository's root:
//
//   xcrun swift scripts/charge-limit-sample.swift /Library/Preferences/com.apple.powerd.charging.plist <copy>
//   swift scripts/charge-limit-sample.swift --self-test
//
// The copy keeps the file's structure, its format and every value but these, each overwritten with
// zeros of the same length where they are: `bootSessionUUID` (the boot session's UUID, its hex
// digits zeroed); each policy's `token` and `owner` (powerd's record of the process that set the
// limit), whatever they hold: a UUID's bytes, a number (0), a string or data (zeros of its length);
// and any other UUID in the policies' archive, as bytes or written out. A token or owner that is
// nil refers to the archive's null object, which stays. The copy is then decoded by the rules of
// BatteryPulse's parser (BatteryCore's SystemChargeLimitSource, which
// `SystemChargeLimitSourceTests` holds this script to), and it must give what the original gives,
// with none of the original's UUIDs left in it; otherwise no copy is left. The last line printed
// says what it decodes to, "decodes to 80 (manualChargeLimit)" or "decodes to none (noPolicy)": a
// fixture is named by it, powerd-charging-<n>.plist or powerd-charging-none.plist
// (Tests/BatteryCoreTests/Fixtures/powerd).
//
// It reads powerd's file, which every user may read, and writes only the copy. It needs macOS:
// the archive's object references, the mutable property lists it edits in place and the class name
// its self-test archives under are Darwin Foundation's. Exit status: 0 with the copy written, 1 on a
// usage error or a file it can't redact, with nothing written; then the last line says why, which
// the session's step prints after "failed:".
import Foundation

#if os(macOS)

let usage = """
    usage: xcrun swift scripts/charge-limit-sample.swift <powerd's file> <the redacted copy>
           swift scripts/charge-limit-sample.swift --self-test
    """

struct Failure: Error, CustomStringConvertible {
    var description: String
}

// MARK: - Decoding, by the parser's rules

// From here to the redaction, each declaration but `Outcome` repeats one of BatteryCore's
// SystemChargeLimitSource.swift line for line, comments aside, which `SystemChargeLimitSourceTests`
// checks: the parser's constants, its decisions and its stand-in for powerd's class.

/// The limits System Settings offers: 80 to 100 %.
let range = 80...100

/// The reason powerd gives the policy of a limit set in System Settings → Battery.
let manualReason = "manualChargeLimit"

/// The name powerd archives each policy under, which `ChargePolicyRecord` stands in for.
let policyClassName = "ChargeCtrlPolicy"

/// A larger file is turned down unread.
let maximumBytes = 64 * 1024

/// What a file decodes to: the parser's outcomes of a file it read, printed as the limit, or
/// "none", and the case's name.
enum Outcome: Equatable, CustomStringConvertible {
    case manualChargeLimit(Int)
    case noPolicy
    case otherReason
    case outOfRange
    case unknownFormat

    var description: String {
        switch self {
        case .manualChargeLimit(let percent): "\(percent) (manualChargeLimit)"
        case .noPolicy: "none (noPolicy)"
        case .otherReason: "none (otherReason)"
        case .outOfRange: "none (outOfRange)"
        case .unknownFormat: "none (unknownFormat)"
        }
    }
}

/// The outcome for the file's contents.
func outcome(fileData data: Data) -> Outcome {
    guard data.count <= maximumBytes, let file = try? PropertyListDecoder().decode(File.self, from: data) else {
        return .unknownFormat
    }
    guard let archive = file.policies else { return .noPolicy }
    guard let policies = policies(in: archive) else { return .unknownFormat }
    return outcome(of: policies)
}

/// The one key of the file the parser reads.
struct File: Decodable {
    var policies: Data?
}

/// The limit of the policies in force whose reason is `manualChargeLimit`.
func outcome(of policies: [ChargePolicyRecord]) -> Outcome {
    let inForce = policies.filter { !$0.terminated }
    let manual = inForce.filter { $0.reason == manualReason }
    guard !manual.isEmpty else { return inForce.isEmpty ? .noPolicy : .otherReason }
    let limits = Set(manual.map(\.soclimit))
    guard limits.count == 1, let only = limits.first, let percent = only else { return .unknownFormat }
    return range.contains(percent) ? .manualChargeLimit(percent) : .outOfRange
}

/// The policies in `archive`, decoded with secure coding through `ChargePolicyRecord`; `nil` for
/// an archive of another shape.
func policies(in archive: Data) -> [ChargePolicyRecord]? {
    // The integer and Boolean values are checked first: the unarchiver's decoders may raise.
    guard let shape = try? PropertyListDecoder().decode(ArchiveShape.self, from: archive), shape.isPlain else {
        return nil
    }
    guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: archive) else { return nil }
    defer { unarchiver.finishDecoding() }
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

/// The archive's objects as plain property-list values: every `soclimit` an integer, every
/// `terminated` a Boolean, every `reason` a reference to an object.
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

/// Stands in for powerd's charge policy: the limit, the reason and whether the policy ended; never
/// `owner` or `token`.
final class ChargePolicyRecord: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    let soclimit: Int?
    let reason: String?
    let terminated: Bool

    init?(coder: NSCoder) {
        soclimit = coder.containsValue(forKey: Key.soclimit) ? coder.decodeInteger(forKey: Key.soclimit) : nil
        reason =
            coder.containsValue(forKey: Key.reason)
            ? coder.decodeObject(of: NSString.self, forKey: Key.reason) as String? : nil
        terminated = coder.containsValue(forKey: Key.terminated) && coder.decodeBool(forKey: Key.terminated)
        super.init()
    }

    func encode(with coder: NSCoder) {}

    enum Key {
        static let soclimit = "soclimit"
        static let reason = "reason"
        static let terminated = "terminated"
    }
}

// MARK: - Redacting

/// `text` with every hexadecimal digit a zero, its length and dashes kept.
func zeroed(_ text: String) -> String {
    String(text.map { $0.isHexDigit ? "0" : $0 })
}

/// An object reference of an archive: the index into `$objects` it stands for; `nil` for any other
/// value. Foundation hands a reference out as an opaque CF object whose class doesn't name it, so
/// the index is read from the reference's XML form, `<dict><key>CF$UID</key><integer>5</integer>`,
/// or else from its description, `<CFKeyedArchiverUID …>{value = 5}`.
func referenceIndex(_ value: Any) -> Int? {
    guard !(value is NSDictionary || value is NSArray || value is String || value is Data || value is NSNumber)
    else { return nil }
    if let xml = try? PropertyListSerialization.data(fromPropertyList: [value], format: .xml, options: 0) {
        let text = String(decoding: xml, as: UTF8.self)
        if let match = text.range(of: #"<key>CF\$UID</key>\s*<integer>\d+</integer>"#, options: .regularExpression) {
            return Int(text[match].filter(\.isNumber))
        }
    }
    let text = String(describing: value)
    guard text.contains("KeyedArchiverUID"), let match = text.range(of: #"value = \d+"#, options: .regularExpression)
    else { return nil }
    return Int(text[match].filter(\.isNumber))
}

/// `value` with its content zeroed at the same length: a number 0, a string's characters zeros,
/// data's bytes zeros. `nil` for a value of another kind.
func zeroedValue(_ value: Any) -> Any? {
    switch value {
    case let text as String: String(repeating: "0", count: text.count)
    case let data as Data: Data(count: data.count)
    case is NSNumber: 0 as NSNumber
    default: nil
    }
}

/// Whether `text` is a UUID written out, as `bootSessionUUID` is.
func isUUIDText(_ text: String) -> Bool {
    UUID(uuidString: text) != nil
}

/// Zeroes `object`'s value for `key`, a policy's `owner` or `token`, at its length: in place, or in
/// the object it refers to, a value, a mutable string's text or a UUID's bytes. A key the policy
/// lacks has nothing to zero, and so has one that refers to the archive's first object, `$null`,
/// which stands for nil and stays.
func zeroValue(of key: String, in object: NSMutableDictionary, objects: NSMutableArray) throws {
    guard let value = object[key] else { return }
    guard let index = referenceIndex(value) else {
        guard let zero = zeroedValue(value) else {
            throw Failure(description: "a policy's \(key) is of a kind the script can't zero: nothing written")
        }
        object[key] = zero
        return
    }
    guard index != 0 else { return }
    guard index > 0, index < objects.count else {
        throw Failure(description: "a policy's \(key) refers past the archive's objects: nothing written")
    }
    if let zero = zeroedValue(objects[index]) {
        objects[index] = zero
    } else if let string = objects[index] as? NSMutableDictionary, let text = string["NS.string"],
        let zero = zeroedValue(text)
    {
        // A mutable string, archived as an object of its own.
        string["NS.string"] = zero
    } else if let uuid = objects[index] as? NSMutableDictionary, let bytes = uuid["NS.uuidbytes"] as? Data {
        uuid["NS.uuidbytes"] = Data(count: bytes.count)
    } else {
        throw Failure(description: "a policy's \(key) refers to a value the script can't zero: nothing written")
    }
}

/// The archive with every UUID zeroed, as bytes or written out, and each policy's `owner` and
/// `token`, in its own format.
func redactedArchive(_ archive: Data) throws -> Data {
    var format = PropertyListSerialization.PropertyListFormat.binary
    guard
        let root = try PropertyListSerialization.propertyList(
            from: archive, options: .mutableContainersAndLeaves, format: &format) as? NSMutableDictionary,
        let objects = root["$objects"] as? NSMutableArray
    else { throw Failure(description: "policies isn't a keyed archive: nothing written") }
    // The objects are listed first: replacing one while the array is enumerated would raise.
    for object in objects.compactMap({ $0 as? NSMutableDictionary }) {
        if let bytes = object["NS.uuidbytes"] as? Data {
            object["NS.uuidbytes"] = Data(count: bytes.count)
        }
        try zeroValue(of: "owner", in: object, objects: objects)
        try zeroValue(of: "token", in: object, objects: objects)
    }
    // A UUID written out anywhere else in the archive, as a string or a mutable string's text.
    for index in 0..<objects.count {
        if let text = objects[index] as? String, isUUIDText(text) {
            objects[index] = zeroed(text)
        } else if let string = objects[index] as? NSMutableDictionary, let text = string["NS.string"] as? String,
            isUUIDText(text)
        {
            string["NS.string"] = zeroed(text)
        }
    }
    return try PropertyListSerialization.data(fromPropertyList: root, format: format, options: 0)
}

/// The file with `bootSessionUUID` zeroed and its policies' archive redacted, in its own format.
func redactedFile(_ data: Data) throws -> Data {
    var format = PropertyListSerialization.PropertyListFormat.binary
    guard
        let file = try PropertyListSerialization.propertyList(
            from: data, options: .mutableContainersAndLeaves, format: &format) as? NSMutableDictionary
    else { throw Failure(description: "not a property list dictionary: nothing written") }
    switch file["bootSessionUUID"] {
    case nil: break
    case let text as String: file["bootSessionUUID"] = zeroed(text)
    case let bytes as Data: file["bootSessionUUID"] = Data(count: bytes.count)
    default: throw Failure(description: "bootSessionUUID is of a kind the script can't zero: nothing written")
    }
    switch file["policies"] {
    case nil: break
    case let archive as Data: file["policies"] = try redactedArchive(archive)
    default: throw Failure(description: "policies isn't data, which the parser expects: nothing written")
    }
    return try PropertyListSerialization.data(fromPropertyList: file, format: format, options: 0)
}

/// The objects of `data`'s policies' archive; none without one.
func archiveObjects(ofFile data: Data) -> [Any] {
    guard let file = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
        let archive = file["policies"] as? Data,
        let root = try? PropertyListSerialization.propertyList(from: archive, format: nil) as? [String: Any]
    else { return [] }
    return root["$objects"] as? [Any] ?? []
}

/// The UUIDs `data`'s file holds: `bootSessionUUID`'s text, and in its archive every UUID's bytes,
/// every UUID written out and a token kept as bytes in its policy.
func identifiers(inFile data: Data) -> [Data] {
    guard let file = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
        return []
    }
    var found: [Data] = []
    if let text = file["bootSessionUUID"] as? String { found.append(Data(text.utf8)) }
    if let bytes = file["bootSessionUUID"] as? Data { found.append(bytes) }
    for object in archiveObjects(ofFile: data) {
        if let text = object as? String, isUUIDText(text) { found.append(Data(text.utf8)) }
        guard let fields = object as? [String: Any] else { continue }
        if let bytes = fields["NS.uuidbytes"] as? Data { found.append(bytes) }
        if let text = fields["NS.string"] as? String, isUUIDText(text) { found.append(Data(text.utf8)) }
        if let token = fields["token"] as? Data { found.append(token) }
    }
    return found.filter { !$0.allSatisfy { $0 == 0 || $0 == UInt8(ascii: "0") || $0 == UInt8(ascii: "-") } }
}

/// Whether `data`'s file, or its archive, holds `identifier`'s bytes.
func holds(_ data: Data, _ identifier: Data) -> Bool {
    if data.range(of: identifier) != nil { return true }
    guard let file = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
        let archive = file["policies"] as? Data
    else { return false }
    return archive.range(of: identifier) != nil
}

/// The redacted copy of `original`, checked: it decodes as the original does, and holds none of
/// its UUIDs.
func sample(of original: Data) throws -> (copy: Data, outcome: Outcome) {
    let expected = outcome(fileData: original)
    let copy = try redactedFile(original)
    let found = outcome(fileData: copy)
    guard found == expected else {
        throw Failure(description: "the copy decodes to \(found), the file to \(expected): nothing written")
    }
    if !identifiers(inFile: copy).isEmpty || identifiers(inFile: original).contains(where: { holds(copy, $0) }) {
        throw Failure(description: "a UUID of the file is still in the copy: nothing written")
    }
    return (copy, found)
}

// MARK: - Self-test

/// A policy as powerd archives it, for the self-test.
final class ArchivedPolicy: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    let limit: Int
    /// A process ID, a name, or `NSNull()` for none, which the archive keeps as its null object.
    let owner: Any
    /// Whether the policy's end is archived as a number, which the parser turns down, rather than
    /// the Boolean powerd archives.
    let endsAsNumber: Bool
    /// Whether the token is archived written out, as a string, rather than as a UUID's bytes.
    let tokenAsText: Bool
    let token = UUID()

    init(limit: Int, owner: Any, endsAsNumber: Bool = false, tokenAsText: Bool = false) {
        self.limit = limit
        self.owner = owner
        self.endsAsNumber = endsAsNumber
        self.tokenAsText = tokenAsText
    }

    init?(coder: NSCoder) { nil }

    func encode(with coder: NSCoder) {
        coder.encode(limit, forKey: "soclimit")
        coder.encode("manualChargeLimit" as NSString, forKey: "reason")
        coder.encode(true, forKey: "drain")
        coder.encode(true, forKey: "isEndOfCharge")
        coder.encode(false, forKey: "noChargeToFull")
        if endsAsNumber {
            coder.encode(0, forKey: "terminated")
        } else {
            coder.encode(false, forKey: "terminated")
        }
        switch owner {
        case let pid as Int: coder.encode(pid, forKey: "owner")
        case let name as String: coder.encode(name as NSString, forKey: "owner")
        case is NSNull: coder.encode(nil as Any?, forKey: "owner")
        default: break
        }
        if tokenAsText {
            coder.encode(token.uuidString as NSString, forKey: "token")
        } else {
            coder.encode(token as NSUUID, forKey: "token")
        }
    }
}

/// powerd's file with `policies` archived in `format`, the file itself in `fileFormat`.
func syntheticFile(
    _ policies: [ArchivedPolicy]?, format: PropertyListSerialization.PropertyListFormat,
    fileFormat: PropertyListSerialization.PropertyListFormat
) throws -> Data {
    var file: [String: Any] = ["bootSessionUUID": UUID().uuidString]
    if let policies {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        archiver.outputFormat = format
        archiver.setClassName(policyClassName, for: ArchivedPolicy.self)
        archiver.encode(policies as NSArray, forKey: NSKeyedArchiveRootObjectKey)
        archiver.finishEncoding()
        file["policies"] = archiver.encodedData
    }
    return try PropertyListSerialization.data(fromPropertyList: file, format: fileFormat, options: 0)
}

func selfTest() throws {
    var checks = 0
    func check(_ condition: Bool, _ what: String) throws {
        guard condition else { throw Failure(description: "self-test: \(what)") }
        checks += 1
    }
    let formats: [PropertyListSerialization.PropertyListFormat] = [.binary, .xml]
    for format in formats {
        for fileFormat in formats {
            for owner in [489, "PowerUIAgent"] as [Any] {
                let original = try syntheticFile(
                    [ArchivedPolicy(limit: 80, owner: owner)], format: format, fileFormat: fileFormat)
                let (copy, found) = try sample(of: original)
                try check(found == .manualChargeLimit(80), "a limit of 80 decodes to \(found)")
                try check(copy != original, "the copy differs from the file")
                try check(!identifiers(inFile: original).isEmpty, "the file's UUIDs are found")
                try check(identifiers(inFile: copy).isEmpty, "the copy holds no UUID")
                try check(
                    !(owner is String) || !holds(copy, Data("PowerUIAgent".utf8)), "the owner's name is gone")
            }
        }
    }
    let none = try sample(of: syntheticFile(nil, format: .binary, fileFormat: .binary))
    try check(none.outcome == .noPolicy, "a file without policies decodes to none")
    let empty = try sample(of: syntheticFile([], format: .binary, fileFormat: .binary))
    try check(empty.outcome == .noPolicy, "no policy in force decodes to none")
    let outside = try sample(
        of: syntheticFile([ArchivedPolicy(limit: 75, owner: 1)], format: .binary, fileFormat: .binary))
    try check(outside.outcome == .outOfRange, "75 is out of range")
    let number = try sample(
        of: syntheticFile(
            [ArchivedPolicy(limit: 80, owner: 1, endsAsNumber: true)], format: .binary, fileFormat: .binary))
    try check(number.outcome == .unknownFormat, "a policy's end as a number is another format")
    // A token written out and a policy without an owner: the token's text goes, and the archive's
    // null object, which the owner refers to, stays.
    let textual = ArchivedPolicy(limit: 85, owner: NSNull(), tokenAsText: true)
    let withText = try syntheticFile([textual], format: .binary, fileFormat: .binary)
    let tokenText = Data(textual.token.uuidString.utf8)
    try check(
        archiveObjects(ofFile: withText).contains { ($0 as? [String: Any])?["owner"].flatMap(referenceIndex) == 0 },
        "a policy without an owner refers to the null object")
    try check(
        holds(withText, tokenText) && identifiers(inFile: withText).contains(tokenText), "the token's text is found")
    let (textCopy, textFound) = try sample(of: withText)
    try check(textFound == .manualChargeLimit(85), "a token written out: a limit of 85 decodes to \(textFound)")
    try check(!holds(textCopy, tokenText), "the token's text is gone")
    try check(identifiers(inFile: textCopy).isEmpty, "the copy with a token written out holds no UUID")
    try check(archiveObjects(ofFile: textCopy).first as? String == "$null", "the null object stays")
    // A file the script can't read is refused, and the outcome printed names its last line.
    try check(
        (try? sample(of: Data("not a property list".utf8))) == nil, "a file that isn't a property list is refused")
    try check(
        "\(Outcome.manualChargeLimit(85))" == "85 (manualChargeLimit)" && "\(Outcome.noPolicy)" == "none (noPolicy)",
        "the outcome's words")
    print("The self-test passed: \(checks) checks.")
}

// MARK: - Main

let arguments = Array(CommandLine.arguments.dropFirst())
do {
    if arguments == ["--self-test"] {
        try selfTest()
        exit(0)
    }
    guard arguments.count == 2 else {
        FileHandle.standardError.write(Data((usage + "\n").utf8))
        exit(1)
    }
    let original = try Data(contentsOf: URL(fileURLWithPath: arguments[0]))
    let (copy, found) = try sample(of: original)
    try copy.write(to: URL(fileURLWithPath: arguments[1]), options: .atomic)
    print("wrote \(arguments[1]), \(copy.count) bytes, from a file of \(original.count)")
    print("decodes to \(found)")
} catch {
    // Why nothing was written, on the last line: the session's step prints it after "failed:".
    print("\(error)")
    exit(1)
}
#else
print("the sample script needs macOS: nothing written")
exit(1)
#endif
