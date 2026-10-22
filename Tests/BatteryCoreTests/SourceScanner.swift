import Foundation
import Testing

/// The sources of the code that only compiles on macOS, for the suites that guard its rules on
/// Linux (``MotionGuardTests``, ``LocalizationCatalogTests``), every target's sources for the
/// rules that hold everywhere (``SecurityGuardTests``, ``EnergyGuardTests``), and the helpers
/// that scan them: code with comments and string literals blanked out, and calls with their
/// argument text.
///
/// Every Swift file of `Sources` is read and blanked once per test process (``files``,
/// ``allFiles``), however many suites and tests look at it.
enum SourceScanner {
    /// A Swift file of `Sources`.
    struct File: Sendable, CustomTestStringConvertible {
        /// Relative to `Sources/`, such as `BatteryPulseApp/Main/MainView.swift`.
        var path: String
        var text: String
        /// ``text`` through ``SourceScanner/codeOnly(_:)``.
        var code: String

        var testDescription: String { path }
    }

    struct ScanError: Error, CustomStringConvertible {
        var description: String
    }

    static let sources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources")

    /// The targets whose code only compiles on macOS.
    static let targets = ["BatteryPulseApp", "BatteryPulseWidget"]

    /// The other targets: Linux compiles them, but their `#if os(macOS)` blocks only CI does.
    static let otherTargets = ["BatteryCore", "BatteryKit", "bpulse"]

    /// Every Swift file of ``targets``, ordered by path. A `static let`, so it is built once, on
    /// first use, whichever test gets there first.
    static let files: Result<[File], any Error> = Result { try scan(targets) }

    /// Every Swift file of every target, ordered by path; ``files`` are not read twice.
    static let allFiles: Result<[File], any Error> = Result {
        try (files.get() + scan(otherTargets)).sorted { $0.path < $1.path }
    }

    private static func scan(_ targets: [String]) throws -> [File] {
        var files: [File] = []
        for target in targets {
            let directory = sources.appendingPathComponent(target)
            guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
            else { throw ScanError(description: "Can't list \(directory.path)") }
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                let components = url.standardizedFileURL.pathComponents
                guard let sourcesIndex = components.lastIndex(of: "Sources") else {
                    throw ScanError(description: "\(url.path) is outside Sources")
                }
                let text = try String(contentsOf: url, encoding: .utf8)
                let path = components[(sourcesIndex + 1)...].joined(separator: "/")
                files.append(File(path: path, text: text, code: codeOnly(text)))
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    /// The scanned file at `path`, relative to `Sources/`.
    static func file(_ path: String) throws -> File {
        guard let file = try files.get().first(where: { $0.path == path }) else {
            throw ScanError(description: "No scanned file at \(path)")
        }
        return file
    }

    // MARK: Calls

    struct Call {
        var name: String
        var start: String.Index
        /// Text between the parentheses.
        var arguments: Substring
        /// Applied to a view (`view.symbolEffect(…)`), not an implicit member such as
        /// `.contentTransition(.symbolEffect(.replace))` or `case .animation(let a):`.
        var isModifier: Bool

        /// The top-level arguments, trimmed.
        var topLevelArguments: [String] {
            var depth = 0
            var piece = ""
            var pieces: [String] = []
            for character in arguments {
                switch character {
                case "(", "[", "{": depth += 1
                case ")", "]", "}": depth -= 1
                case "," where depth == 0:
                    pieces.append(piece)
                    piece = ""
                    continue
                default: break
                }
                piece.append(character)
            }
            pieces.append(piece)
            return pieces.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        /// The first argument's expression, whatever its label.
        var firstArgument: String {
            topLevelArguments.first ?? ""
        }

        /// The expression of a top-level argument with this label.
        func argument(labeled label: String) -> String? {
            for piece in topLevelArguments where piece.hasPrefix(label) {
                let rest = piece.dropFirst(label.count).drop { $0 == " " }
                if rest.first == ":" { return rest.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            return nil
        }
    }

    /// Calls of `name` followed by `(`, with their balanced argument text.
    static func calls(named name: Regex<Substring>, in code: String) -> [Call] {
        var result: [Call] = []
        for match in code.matches(of: name) {
            var index = match.range.upperBound
            while index < code.endIndex, code[index] == " " { index = code.index(after: index) }
            guard index < code.endIndex, code[index] == "(" else { continue }
            let open = code.index(after: index)
            var depth = 1
            var cursor = open
            while cursor < code.endIndex, depth > 0 {
                if code[cursor] == "(" { depth += 1 }
                if code[cursor] == ")" { depth -= 1 }
                cursor = code.index(after: cursor)
            }
            guard depth == 0 else { continue }
            let close = code.index(before: cursor)
            result.append(
                Call(
                    name: String(code[match.range]).trimmingCharacters(in: .punctuationCharacters),
                    start: match.range.lowerBound,
                    arguments: code[open..<close],
                    isModifier: isModifier(dotAt: match.range.lowerBound, in: code)))
        }
        return result
    }

    /// Whether the member access at `dot` continues an expression (a modifier) rather than
    /// starting an implicit member expression.
    static func isModifier(dotAt dot: String.Index, in code: String) -> Bool {
        guard code[dot] == "." else { return false }
        var index = dot
        var sawSpace = false
        while index > code.startIndex {
            index = code.index(before: index)
            let character = code[index]
            if character.isWhitespace {
                sawSpace = true
                continue
            }
            switch character {
            case ")", "]", "}", "\"": return true
            // `view?.symbolEffect(…)` against `flag ? .symbolEffect(…) : …`.
            case "?", "!": return !sawSpace
            default:
                guard character.isLetter || character.isNumber || character == "_" else { return false }
                var start = index
                while start > code.startIndex {
                    let previous = code.index(before: start)
                    let c = code[previous]
                    guard c.isLetter || c.isNumber || c == "_" else { break }
                    start = previous
                }
                let word = code[start...index]
                let keywords: Set<Substring> = ["return", "case", "in", "else", "try", "await", "then", "some", "any"]
                // `Transition.symbolEffect(…)` is a static member of a type, not a modifier.
                return !keywords.contains(word) && !(word.first?.isUppercase ?? false)
            }
        }
        return false
    }

    // MARK: Blanking

    /// `source` with comments and the contents of string literals replaced by spaces; line breaks
    /// and the quotes themselves stay, so positions and line numbers match the original.
    static func codeOnly(_ source: String) -> String {
        let characters = Array(source)
        var output = characters
        var index = 0
        func blank(_ range: Range<Int>) {
            for i in range where characters[i] != "\n" { output[i] = " " }
        }
        // Compares in place: this runs at every character of every file.
        func starts(with prefix: String, at i: Int) -> Bool {
            var position = i
            for character in prefix {
                guard position < characters.count, characters[position] == character else { return false }
                position += 1
            }
            return true
        }
        while index < characters.count {
            if starts(with: "//", at: index) {
                var end = index
                while end < characters.count, characters[end] != "\n" { end += 1 }
                blank(index..<end)
                index = end
            } else if starts(with: "/*", at: index) {
                var depth = 0
                var end = index
                repeat {
                    if starts(with: "/*", at: end) {
                        depth += 1
                        end += 2
                    } else if starts(with: "*/", at: end) {
                        depth -= 1
                        end += 2
                    } else {
                        end += 1
                    }
                } while depth > 0 && end < characters.count
                blank(index..<min(end, characters.count))
                index = end
            } else if characters[index] == "\"" || (characters[index] == "#" && starts(with: "#\"", at: index)) {
                var hashes = 0
                var open = index
                while characters[open] == "#" {
                    hashes += 1
                    open += 1
                }
                let isMultiline = starts(with: "\"\"\"", at: open)
                let quote = isMultiline ? "\"\"\"" : "\""
                let closing = quote + String(repeating: "#", count: hashes)
                var end = open + quote.count
                while end < characters.count, !starts(with: closing, at: end) {
                    if hashes == 0, characters[end] == "\\" { end += 1 }
                    if !isMultiline, characters[end] == "\n" { break }
                    end += 1
                }
                let contentEnd = min(end, characters.count)
                blank((open + quote.count)..<contentEnd)
                index = min(contentEnd + closing.count, characters.count)
            } else {
                index += 1
            }
        }
        return String(output)
    }
}
