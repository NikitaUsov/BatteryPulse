import Foundation
import Testing

/// Keeps the logging rule of CLAUDE.md in every target, Darwin code included (NEW-12): only static
/// text, numbers and case names log as `.public`; error descriptions, paths, URLs, names, serial
/// numbers, UDIDs and device keys never do.
///
/// Reads the string interpolations of every Swift file of `Sources` (``SourceScanner/allFiles``),
/// comments left out, and fails on:
/// - a `privacy: .public` value that isn't in its file's entries of ``allowList``, or that the
///   file logs more often than its entry's count. Each entry says why its value is static text, a
///   number or a case name. An entry the file logs fewer times fails too
///   (``everyEntryMatchesItsFile(_:)``), so the list always holds exactly what the tree logs;
/// - a `.public` value that names one of ``deniedWords``, listed or not. Only `name` has
///   exceptions: an entry may vouch for a static name from the code, such as an SMC key's
///   four-character code (``PublicValue/overridesName``). An error's `domain` and `code`, a
///   constant and a number, don't name the error;
/// - a privacy this scan can't read: one that isn't written out in the interpolation (`.public`,
///   `.private`, `.auto`, `.sensitive`), an `OSLogPrivacy` anywhere in the code, and os_log's
///   `%{public}` format.
///
/// A new `.public` value fails with the entry to add. If the value is static text, a number or a
/// case name, add the entry under its file with its reason; otherwise log the value as
/// `.private`, or a device key as `.private(mask: .hash)`.
@Suite struct LogPrivacyGuardTests {
    /// A value that a file logs as `.public`.
    struct PublicValue: Sendable {
        /// The interpolated expression as written, with each run of white space as one space.
        var expression: String
        /// How many times the file logs it as public.
        var count: Int
        /// The expression names `name`, but its value is a static name from the code, never a
        /// device's, an accessory's or a file's.
        var overridesName: Bool
        /// Why the value is static text, a number or a case name.
        var reason: String

        init(_ expression: String, count: Int = 1, overridesName: Bool = false, reason: String) {
            self.expression = expression
            self.count = count
            self.overridesName = overridesName
            self.reason = reason
        }
    }

    /// Every value logged as `.public`, by file (relative to `Sources/`), each with its reason.
    ///
    /// A file that logs a new `.public` value gets an entry, and one that logs a listed value once
    /// more gets a higher count; a test names each entry to add, raise, lower or remove.
    static let allowList: [String: [PublicValue]] = [
        "BatteryKit/BatteryMonitor.swift": [
            PublicValue("effective.description", reason: "the live-refresh interval, a Duration such as 5.0 seconds"),
            PublicValue(
                "clients", count: 2, reason: "the requests' client names, which come from the code, such as menuBar"),
        ],
        "BatteryKit/IDeviceMonitor.swift": [
            PublicValue("action", count: 2, reason: "the failed call, static text from DeviceLog's callers"),
            PublicValue("reason", count: 2, reason: "an IDeviceError's case name, or an error's domain and code"),
        ],
        "BatteryKit/MobileDevice/MobileDeviceLibrary.swift": [
            PublicValue(
                "name", count: 2, overridesName: true,
                reason: "\"MobileDevice\" and the framework's version from its Info.plist")
        ],
        "BatteryPulseApp/App/BatteryPulseApp.swift": [
            PublicValue("via", count: 3, reason: "how a widget click arrived, a StaticString: url or activity"),
            PublicValue(
                "name", count: 2, overridesName: true,
                reason: "the page's signpost name, a StaticString such as overview; a device's key logs hashed"),
        ],
        "BatteryPulseApp/App/HistoryRecorder.swift": [
            PublicValue("what", reason: "the write, static text from the callers, such as the day's summary"),
            PublicValue("error.domain", reason: "the error's domain, a constant such as NSCocoaErrorDomain"),
        ],
        "BatteryPulseApp/App/WidgetRefresher.swift": [
            PublicValue("reason.rawValue", count: 3, reason: "a reload or launch reason's case name"),
            PublicValue("found", reason: "a count of widget extension processes"),
            PublicValue("byTerm", reason: "a count of widget extension processes"),
            PublicValue("byKill", reason: "a count of widget extension processes"),
            PublicValue("left", reason: "a count of widget extension processes"),
            PublicValue("elapsed", reason: "milliseconds"),
            PublicValue("snapshot.chargeState.rawValue", reason: "a ChargeState case name"),
            PublicValue("percent", reason: "the charge in whole percent, or -"),
            PublicValue("list.count", reason: "the number of accessories"),
            PublicValue("kinds.count", reason: "the number of placed widgets"),
            PublicValue("counts[.battery] ?? 0", reason: "the number of placed Battery widgets"),
            PublicValue("counts[.accessories] ?? 0", reason: "the number of placed Accessories widgets"),
            PublicValue("error.domain", reason: "WidgetKit's error domain, a constant"),
        ],
        "BatteryPulseApp/Main/History/HistoryView.swift": [
            PublicValue("what", reason: "the read, static text from the callers, such as the day summaries"),
            PublicValue("error.domain", reason: "the error's domain, a constant such as NSCocoaErrorDomain"),
        ],
        "BatteryPulseApp/Settings/AdvancedSettings.swift": [
            PublicValue("error.domain", reason: "the error's domain, a constant such as NSCocoaErrorDomain")
        ],
        "BatteryPulseApp/Updates/UpdateInstaller.swift": [
            PublicValue("version", reason: "the release's version number, such as 0.7.0"),
            PublicValue(
                "reason", count: 2,
                reason: "an UpdateInstallError's case name (no case has a value), and strerror's text for an errno"),
            PublicValue("status", count: 2, reason: "an OSStatus, Launch Services' or the code signature check's"),
            PublicValue("status ?? -1", reason: "diskutil's exit status, -1 when it didn't start"),
        ],
        "BatterySource/Diagnostics.swift": [
            PublicValue("text", count: 2, reason: "a signpost's trigger, a StaticString such as poll, or -"),
            PublicValue(
                "PerfLine.interval(label, duration: duration, trigger: text)",
                reason: "a perf line: the signpost's StaticString name, milliseconds and the trigger"),
            PublicValue(
                "PerfLine.event(label, trigger: text)",
                reason: "a perf line: the event's StaticString name and the trigger"),
        ],
        "BatterySource/SMCClient.swift": [
            PublicValue("code", reason: "IOKit's status, in hex"),
            PublicValue(
                "name", count: 3, overridesName: true, reason: "an SMC key's four-character code, such as B0AC"),
            PublicValue(
                "reason", reason: "an IOKit status, a reply's size or an SMC result, each a number in static text"),
        ],
        "BatterySource/SystemNotifications.swift": [
            PublicValue(
                "name", overridesName: true,
                reason: "a notify(3) name from the code, such as com.apple.system.powersources")
        ],
    ]

    /// The words a `.public` value may never name, each with why (CL "Logging"). An identifier
    /// names a word as one of its camel-case words, in the singular or plural: `deviceName` names
    /// `name`, `fileURL` names `url`, `UDIDs` names `udid`; `rename`, `curl` and `keyboard` name
    /// none.
    static let deniedWords: [(word: String, why: String)] = [
        ("error", "an error's description can name a path; its domain and code may log as public"),
        ("localizedDescription", "an error's description can name a path"),
        ("path", "a path names the user's folders"),
        ("url", "a URL can hold a path"),
        ("name", "a device's, an accessory's or a file's name is the user's"),
        ("serial", "a serial number identifies the hardware"),
        ("udid", "a UDID identifies an iPhone or iPad"),
        ("uuid", "a UUID can identify a device or a boot"),
        ("key", "a device key logs as .private(mask: .hash)"),
    ]

    // MARK: The scan

    /// A Swift file read for its string interpolations.
    struct LogScan {
        /// The file as it is.
        let characters: [Character]
        /// The file with comments and the text of string literals blanked, line breaks kept. The
        /// quotes and every interpolation stay, as code.
        private(set) var code: [Character]
        /// The file with only its comments blanked.
        private(set) var uncommented: [Character]
        /// The text between each interpolation's parentheses, nested ones included, by position.
        private(set) var interpolations: [Range<Int>] = []

        init(_ source: String) {
            characters = Array(source)
            code = characters
            uncommented = characters
            _ = scanCode(from: 0, nested: false)
            interpolations.sort { $0.lowerBound < $1.lowerBound }
        }

        private func starts(with prefix: String, at index: Int) -> Bool {
            var position = index
            for character in prefix {
                guard position < characters.count, characters[position] == character else { return false }
                position += 1
            }
            return true
        }

        private mutating func blankComment(_ range: Range<Int>) {
            for index in range where characters[index] != "\n" {
                code[index] = " "
                uncommented[index] = " "
            }
        }

        private mutating func blankText(_ range: Range<Int>) {
            for index in range where characters[index] != "\n" { code[index] = " " }
        }

        /// Reads code from `start` to the end of the file or, in an interpolation (`nested`), to
        /// the `)` that closes it, whose position it returns.
        private mutating func scanCode(from start: Int, nested: Bool) -> Int {
            var index = start
            var depth = 0
            while index < characters.count {
                let character = characters[index]
                if starts(with: "//", at: index) {
                    var end = index
                    while end < characters.count, characters[end] != "\n" { end += 1 }
                    blankComment(index..<end)
                    index = end
                } else if starts(with: "/*", at: index) {
                    var level = 0
                    var end = index
                    repeat {
                        if starts(with: "/*", at: end) {
                            level += 1
                            end += 2
                        } else if starts(with: "*/", at: end) {
                            level -= 1
                            end += 2
                        } else {
                            end += 1
                        }
                    } while level > 0 && end < characters.count
                    end = min(end, characters.count)
                    blankComment(index..<end)
                    index = end
                } else if character == "\"" || (character == "#" && opensString(at: index)) {
                    index = scanString(at: index)
                } else {
                    if nested, character == "(" { depth += 1 }
                    if nested, character == ")" {
                        if depth == 0 { return index }
                        depth -= 1
                    }
                    index += 1
                }
            }
            return index
        }

        /// Whether the `#` at `index` opens a raw string (`#"`, `##"`), not `#if` or `#selector`.
        private func opensString(at index: Int) -> Bool {
            var position = index
            while position < characters.count, characters[position] == "#" { position += 1 }
            return position < characters.count && characters[position] == "\""
        }

        /// Reads the string literal whose first `#` or quote is at `start`, blanking its text and
        /// reading its interpolations as code; returns the position after it.
        private mutating func scanString(at start: Int) -> Int {
            var index = start
            var hashes = 0
            while characters[index] == "#" {
                hashes += 1
                index += 1
            }
            let isMultiline = starts(with: "\"\"\"", at: index)
            let quote = isMultiline ? "\"\"\"" : "\""
            index += quote.count
            let closing = quote + String(repeating: "#", count: hashes)
            let escape = "\\" + String(repeating: "#", count: hashes)
            while index < characters.count {
                if starts(with: closing, at: index) { return index + closing.count }
                if !isMultiline, characters[index] == "\n" { return index }
                if starts(with: escape, at: index) {
                    let next = index + escape.count
                    if next < characters.count, characters[next] == "(" {
                        let close = scanCode(from: next + 1, nested: true)
                        interpolations.append((next + 1)..<close)
                        index = close + 1
                    } else {
                        // An escape such as `\n` or `\"`: text, like the character it escapes.
                        blankText(index..<min(next + 1, characters.count))
                        index = next + 1
                    }
                    continue
                }
                blankText(index..<(index + 1))
                index += 1
            }
            return index
        }

        /// The line of the character at `offset`, from 1.
        func line(at offset: Int) -> Int {
            characters[..<offset].reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
        }

        /// An interpolation's top-level arguments, each as written and as code.
        func arguments(of range: Range<Int>) -> [(text: String, code: String)] {
            var pieces: [Range<Int>] = []
            var depth = 0
            var start = range.lowerBound
            for index in range {
                switch code[index] {
                case "(", "[", "{": depth += 1
                case ")", "]", "}": depth -= 1
                case "," where depth == 0:
                    pieces.append(start..<index)
                    start = index + 1
                default: break
                }
            }
            pieces.append(start..<range.upperBound)
            return pieces.map { piece in
                (
                    String(characters[piece]).trimmingCharacters(in: .whitespacesAndNewlines),
                    String(code[piece]).trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        }
    }

    /// An interpolation with a `privacy:` argument.
    struct PrivacyValue {
        /// Where its arguments start, in characters from the start of the file.
        var offset: Int
        /// The interpolated expression as written, with each run of white space as one space.
        var expression: String
        /// The same with the text of its string literals blanked.
        var expressionCode: String
        /// The `privacy:` argument with its white space removed, such as `.public`.
        var privacy: String
    }

    /// Every interpolation of `scan` with a `privacy:` argument.
    static func privacyValues(in scan: LogScan) -> [PrivacyValue] {
        scan.interpolations.compactMap { range in
            let arguments = scan.arguments(of: range)
            guard
                let privacy = arguments.dropFirst().first(where: {
                    $0.code.hasPrefix("privacy")
                        && $0.code.dropFirst("privacy".count).trimmingPrefix(while: \.isWhitespace).first == ":"
                })
            else { return nil }
            let value = privacy.code.drop { $0 != ":" }.dropFirst().filter { !$0.isWhitespace }
            return PrivacyValue(
                offset: range.lowerBound, expression: collapsed(arguments[0].text),
                expressionCode: collapsed(arguments[0].code), privacy: String(value))
        }
    }

    /// `text` with each run of white space as one space.
    static func collapsed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Whether a file may log at all, read before anything else: most files don't.
    static func mayLog(_ source: String) -> Bool {
        source.contains("rivacy") || source.contains("%{public")
    }

    // MARK: The rules

    /// The words of ``deniedWords`` that `expression`, a value's code, names.
    static func deniedWordsNamed(in expression: String) -> [String] {
        let characters = Array(expression)
        func continuesIdentifier(_ character: Character) -> Bool {
            character.isLetter || character.isNumber || character == "_"
        }
        var named: [String] = []
        var index = 0
        while index < characters.count {
            let character = characters[index]
            guard character.isLetter || character == "_" else {
                index += 1
                // A number's letters (`0x1F`, `1e3`) start no identifier.
                if character.isNumber {
                    while index < characters.count, continuesIdentifier(characters[index]) { index += 1 }
                }
                continue
            }
            var end = index
            while end < characters.count, continuesIdentifier(characters[end]) { end += 1 }
            let identifier = Array(characters[index..<end])
            // `error.domain` and `error.code` are a constant and a number.
            let member = String(characters[end...]).trimmingPrefix(while: \.isWhitespace)
            let isDomainOrCode = member.prefixMatch(of: #/\.\s*(?:domain|code)\b/#) != nil
            for (word, _) in Self.deniedWords where !named.contains(word) && Self.identifier(identifier, names: word) {
                if word == "error", isDomainOrCode { continue }
                named.append(word)
            }
            index = end
        }
        return named
    }

    /// Whether `identifier` names `word` as one or more of its camel-case words in a row, in the
    /// singular or plural; matching ignores case.
    static func identifier(_ identifier: [Character], names word: String) -> Bool {
        let target = Array(word.lowercased())
        let lowered = identifier.map { $0.lowercased().first ?? $0 }
        guard target.count <= identifier.count else { return false }
        func startsWord(_ index: Int) -> Bool {
            index == 0 || identifier[index].isUppercase || !identifier[index - 1].isLetter
        }
        func endsWord(_ index: Int) -> Bool {
            index == identifier.count || identifier[index].isUppercase || !identifier[index].isLetter
        }
        for start in 0...(identifier.count - target.count) where startsWord(start) {
            guard Array(lowered[start..<(start + target.count)]) == target else { continue }
            let end = start + target.count
            if endsWord(end) || (identifier[end] == "s" && endsWord(end + 1)) { return true }
        }
        return false
    }

    /// Every rule `source` breaks as "path:line: message", ordered by position. An entry the file
    /// logs fewer times than its count is no violation here (``unusedEntries(in:path:)``).
    static func violations(in source: String, path: String) -> [String] {
        guard mayLog(source) else { return [] }
        let scan = LogScan(source)
        let entries = allowList[path] ?? []
        var found: [(Int, String)] = []
        var logged: [String: Int] = [:]
        for value in privacyValues(in: scan) {
            let expression = value.expression
            guard value.privacy == ".public" else {
                if value.privacy.wholeMatch(of: #/\.(?:private|auto|sensitive)(?:\(.*\))?/#) == nil {
                    found.append(
                        (
                            value.offset,
                            "privacy `\(value.privacy)` for `\(expression)`: write it out as .public, .private, .auto or .sensitive"
                        ))
                }
                continue
            }
            logged[expression, default: 0] += 1
            let entry = entries.first { $0.expression == expression }
            if let entry {
                if logged[expression, default: 0] > entry.count {
                    found.append(
                        (
                            value.offset,
                            "`\(expression)` logs as .public more often than its entry's count of \(entry.count) in LogPrivacyGuardTests.allowList; raise it if this value is also static text, a number or a case name"
                        ))
                }
            } else {
                found.append(
                    (
                        value.offset,
                        "`\(expression)` logs as .public but isn't on the file's allow list; if it is static text, a number or a case name, add PublicValue(\"\(expression)\", reason: \"…\") under \"\(path)\" in LogPrivacyGuardTests.allowList"
                    ))
            }
            for word in deniedWordsNamed(in: value.expressionCode)
            where !(word == "name" && entry?.overridesName == true) {
                let why = Self.deniedWords.first { $0.word == word }?.why ?? ""
                found.append((value.offset, "`\(expression)` names `\(word)`, which never logs as .public: \(why)"))
            }
        }
        let code = String(scan.code)
        for match in code.matches(of: #/\bOSLogPrivacy\b/#.wordBoundaryKind(.simple)) {
            let offset = code.distance(from: code.startIndex, to: match.range.lowerBound)
            found.append((offset, "an OSLogPrivacy in the code; write the privacy out in the interpolation"))
        }
        let uncommented = String(scan.uncommented)
        for range in uncommented.ranges(of: "%{public") {
            let offset = uncommented.distance(from: uncommented.startIndex, to: range.lowerBound)
            found.append((offset, "os_log's %{public} format; log through a Logger with an interpolation"))
        }
        // By position, and in the order found at one position.
        return found.enumerated().sorted { ($0.element.0, $0.offset) < ($1.element.0, $1.offset) }.map {
            "\(path):\(scan.line(at: $0.element.0)): \($0.element.1)"
        }
    }

    /// The entries of `path` that `source` logs fewer times than their count, as messages.
    static func unusedEntries(in source: String, path: String) -> [String] {
        let values = mayLog(source) ? privacyValues(in: LogScan(source)).filter { $0.privacy == ".public" } : []
        return (allowList[path] ?? []).compactMap { entry in
            let logged = values.count { $0.expression == entry.expression }
            guard logged < entry.count else { return nil }
            let fix = logged == 0 ? "remove the entry" : "lower its count to \(logged)"
            return
                "\(path): `\(entry.expression)` has count \(entry.count) on the allow list, logged as .public \(logged); \(fix)"
        }
    }

    // MARK: Tests

    /// One case per file, so a failure names the file.
    @Test(arguments: (try? SourceScanner.allFiles.get()) ?? [])
    func sourcesLogOnlyAllowedValuesAsPublic(_ file: SourceScanner.File) {
        let violations = Self.violations(in: file.text, path: file.path)
        #expect(violations.isEmpty, "\(violations.joined(separator: "\n"))")
    }

    /// The list holds exactly what each file logs, so a removed or moved line can't leave an
    /// entry that a new one would slip through.
    @Test(arguments: (try? SourceScanner.allFiles.get()) ?? [])
    func everyEntryMatchesItsFile(_ file: SourceScanner.File) {
        let unused = Self.unusedEntries(in: file.text, path: file.path)
        #expect(unused.isEmpty, "\(unused.joined(separator: "\n"))")
    }

    @Test func allowListedFilesExist() {
        for path in Self.allowList.keys {
            #expect(
                FileManager.default.fileExists(atPath: SourceScanner.sources.appendingPathComponent(path).path),
                "\(path)")
        }
    }

    @Test func everyEntryIsWrittenAsTheScanReadsIt() {
        for (path, entries) in Self.allowList {
            #expect(Set(entries.map(\.expression)).count == entries.count, "\(path): an expression listed twice")
            for entry in entries {
                #expect(entry.expression == Self.collapsed(entry.expression), "\(path): \(entry.expression)")
                #expect(entry.count > 0, "\(path): \(entry.expression)")
                #expect(!entry.reason.isEmpty, "\(path): \(entry.expression)")
                // An exception to the rule only where the rule applies, and the only one: the
                // other denied words have none.
                let named = Self.deniedWordsNamed(in: entry.expression)
                #expect(entry.overridesName == named.contains("name"), "\(path): \(entry.expression)")
                #expect(named.allSatisfy { $0 == "name" }, "\(path): \(entry.expression) names \(named)")
            }
        }
    }

    /// The scan finds every `privacy: .public` that the code holds, wherever the interpolation sits,
    /// so no value is missed by the rules above.
    @Test(arguments: (try? SourceScanner.allFiles.get()) ?? [])
    func theScanFindsEveryPublicValue(_ file: SourceScanner.File) {
        guard Self.mayLog(file.text) else { return }
        let scan = LogScan(file.text)
        let written = String(scan.code).matches(of: #/\bprivacy\s*:\s*\.\s*public\b/#.wordBoundaryKind(.simple)).count
        #expect(Self.privacyValues(in: scan).count { $0.privacy == ".public" } == written)
    }

    private static let somewhere = "BatteryKit/BatteryMonitor.swift"

    private func flags(_ source: String, path: String = somewhere) -> Bool {
        !Self.violations(in: source, path: path).isEmpty
    }

    @Test(arguments: [
        #"log.error("Failed: \(error, privacy: .public)")"#,
        #"log.error("Failed: \(error.localizedDescription, privacy: .public)")"#,
        #"log.error("Failed: \(failure.localizedDescription, privacy: .public)")"#,
        #"log.error("Failed: \(String(describing: error), privacy: .public)")"#,
        #"log.error("Failed: \(underlyingError.userInfo, privacy: .public)")"#,
        #"log.info("Reading \(url.path, privacy: .public)")"#,
        #"log.info("Reading \(fileURL, privacy: .public)")"#,
        #"log.info("Reading \(bundle.bundlePath, privacy: .public)")"#,
        #"log.info("Reading \(paths.joined(), privacy: .public)")"#,
        #"log.info("Device \(device.name, privacy: .public)")"#,
        #"log.info("Accessory \(accessoryName, privacy: .public)")"#,
        #"log.info("Device \(serialNumber, privacy: .public)")"#,
        #"log.info("Device \(udid, privacy: .public)")"#,
        #"log.info("Device \(info.UDID, privacy: .public)")"#,
        #"log.info("Boot \(bootSessionUUID, privacy: .public)")"#,
        #"log.info("Device \(key.rawValue, privacy: .public)")"#,
        #"log.info("Device \(deviceKey, privacy: .public)")"#,
        #"log.info("Devices \(DeviceKeys.all, privacy: .public)")"#,
        // A value that isn't listed, however harmless it looks.
        #"log.info("Read \(count, privacy: .public) values")"#,
        #"log.info("Read \(count, align: .right(columns: 4), privacy: .public)")"#,
        // Any spelling and any literal.
        #"log.info("Reading \(path,privacy:.public)")"#,
        #"log.info("Reading \( path , privacy : . public )")"#,
        "log.info(\"\"\"\n    Reading \\(path, privacy: .public)\n    \"\"\")",
        ##"log.info(#"Reading \#(path, privacy: .public)"#)"##,
        #"log.info("Reading \(String(format: "%@ (", path), privacy: .public)")"#,
        // An interpolation inside another one's string.
        #"log.info("Failed: \("\(error)", privacy: .public)")"#,
        // A privacy that the scan can't read.
        #"log.info("Reading \(path, privacy: open)")"#,
        #"log.info("Reading \(path, privacy: OSLogPrivacy.public)")"#,
        "let open: OSLogPrivacy = .public",
        #"os_log("Reading %{public}@", log: log, path)"#,
    ])
    func catches(source: String) {
        #expect(flags(source), "\(source)")
    }

    @Test(arguments: [
        #"log.info("Reading \(path)")"#,
        #"log.info("Reading \(path, privacy: .private)")"#,
        #"log.info("Device \(key, privacy: .private(mask: .hash))")"#,
        #"log.info("Reading \(path, privacy: .sensitive)")"#,
        #"log.info("Reading \(path, privacy: .auto(mask: .hash))")"#,
        #"log.info("Read \(count) values")"#,
        // Listed for this file.
        #"log.debug("Slow values on every read for \(clients, privacy: .public)")"#,
        // Text, not an interpolation.
        "// log.info(\"Reading \\(path, privacy: .public)\")",
        "/* \\(path, privacy: .public) */",
        #"let text = "privacy: .public, %{private}@""#,
        #"let text = "\\(path, privacy: .public)""#,
        ##"let text = #"\(path, privacy: .public)"#"##,
        #"log.info("\(path) /* \(count) */ // done")"#,
    ])
    func allows(source: String) {
        #expect(!flags(source), "\(Self.violations(in: source, path: Self.somewhere))")
    }

    /// An entry allows its value only in its file, only as often as its count, and a denied word
    /// only where it says so.
    @Test func eachEntryAllowsItsValueOnlyInItsFileAndCount() {
        let smc = "BatterySource/SMCClient.swift"
        let key = "log.debug(\"\\(name, privacy: .public) isn't readable\")\n"
        #expect(!flags(key, path: smc))
        #expect(!flags(key + key + key, path: smc))
        #expect(flags(key + key + key + key, path: smc))
        #expect(flags(key, path: "BatteryKit/IDeviceMonitor.swift"))
        let domain = "log.error(\"Failed (\\(error.domain, privacy: .public) \\(error.code))\")"
        #expect(!flags(domain, path: "BatteryPulseApp/Settings/AdvancedSettings.swift"))
        #expect(flags(domain, path: smc))
        let description = "log.error(\"Failed: \\(error.description, privacy: .public)\")"
        #expect(flags(description, path: "BatteryPulseApp/Settings/AdvancedSettings.swift"))
    }

    @Test func anErrorsDomainAndCodeDontNameIt() {
        #expect(Self.deniedWordsNamed(in: "error.domain").isEmpty)
        #expect(Self.deniedWordsNamed(in: "error . code").isEmpty)
        #expect(Self.deniedWordsNamed(in: "error") == ["error"])
        #expect(Self.deniedWordsNamed(in: "error.localizedDescription") == ["error", "localizedDescription"])
        #expect(Self.deniedWordsNamed(in: "error.domainName") == ["error", "name"])
        #expect(Self.deniedWordsNamed(in: "(error as NSError).domain") == ["error"])
    }

    @Test func wordsAreCamelCaseWords() {
        let names: [(String, String)] = [
            ("deviceName", "name"), ("names", "name"), ("fileURL", "url"), ("URLSession", "url"),
            ("NSURL", "url"), ("UDIDs", "udid"), ("SMCKey", "key"), ("key_path", "path"),
            ("localizedDescription", "localizedDescription"),
        ]
        for (identifier, word) in names {
            #expect(Self.identifier(Array(identifier), names: word), "\(identifier) names \(word)")
        }
        let others: [(String, String)] = [
            ("rename", "name"), ("namespace", "name"), ("curl", "url"), ("keyboard", "key"), ("monkey", "key"),
            ("description", "localizedDescription"), ("terror", "error"),
        ]
        for (identifier, word) in others {
            #expect(!Self.identifier(Array(identifier), names: word), "\(identifier) doesn't name \(word)")
        }
    }

    @Test func entriesThatNoLongerMatchAreReported() {
        let smc = "BatterySource/SMCClient.swift"
        let key = "log.debug(\"\\(name, privacy: .public) isn't readable\")\n"
        let unused = Self.unusedEntries(in: key, path: smc)
        #expect(
            unused.contains("\(smc): `name` has count 3 on the allow list, logged as .public 1; lower its count to 1"))
        #expect(unused.contains("\(smc): `code` has count 1 on the allow list, logged as .public 0; remove the entry"))
        #expect(Self.unusedEntries(in: key, path: "BatteryKit/NoLogs.swift").isEmpty)
    }

    @Test func reportsLineNumbers() {
        let source = "let a = 1\n// \\(path, privacy: .public)\nlog.info(\"\\(path, privacy: .public)\")\n"
        #expect(
            Self.violations(in: source, path: "X.swift") == [
                "X.swift:3: `path` logs as .public but isn't on the file's allow list; if it is static text, a number or a case name, add PublicValue(\"path\", reason: \"…\") under \"X.swift\" in LogPrivacyGuardTests.allowList",
                "X.swift:3: `path` names `path`, which never logs as .public: a path names the user's folders",
            ])
    }
}
