import Foundation

/// A release version such as `0.3.0`, compared part by part.
public struct AppVersion: Sendable, Hashable, Comparable, CustomStringConvertible {
    public var parts: [Int]

    public init(parts: [Int]) {
        self.parts = parts
    }

    /// Parses "0.3.0", "v0.3.0" or "0.3"; ignores a pre-release or build suffix ("0.3.0-beta").
    public init?(_ string: String) {
        var text = Substring(string.trimmingCharacters(in: .whitespaces))
        if text.first == "v" || text.first == "V" { text = text.dropFirst() }
        let core = text.prefix { $0.isNumber || $0 == "." }
        let parts = core.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, parts.count <= 4, !parts.contains(nil) else { return nil }
        self.parts = parts.compactMap { $0 }
    }

    public var description: String { parts.map(String.init).joined(separator: ".") }

    /// 0.3 and 0.3.0 are the same version.
    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        lhs.padded(to: rhs.parts.count) == rhs.padded(to: lhs.parts.count)
    }

    public func hash(into hasher: inout Hasher) {
        var trimmed = parts
        while trimmed.last == 0 { trimmed.removeLast() }
        hasher.combine(trimmed)
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        return lhs.padded(to: count).lexicographicallyPrecedes(rhs.padded(to: count))
    }

    private func padded(to count: Int) -> [Int] {
        parts + Array(repeating: 0, count: max(0, count - parts.count))
    }
}

/// A published release, from GitHub's `GET /repos/{owner}/{repo}/releases/latest`.
public struct ReleaseInfo: Sendable, Equatable {
    public var version: AppVersion
    public var title: String
    /// Markdown release notes.
    public var notes: String
    public var pageURL: URL
    /// The DMG attached to the release, if any.
    public var downloadURL: URL?
    /// GitHub's digest of the DMG, such as `sha256:59ff…`; assets uploaded before June 2025 have
    /// none. See ``UpdateIntegrity/check(sha256Hex:against:)``.
    public var downloadDigest: String?
    /// The DMG's size in bytes, for the download's progress.
    public var downloadSize: Int64?
    /// The DMG's Ed25519 signature (`BatteryPulse.dmg.sig`), attached since 0.4.0. Without it the
    /// app doesn't install the update itself.
    public var signatureURL: URL?
    public var publishedAt: Date?

    public init(
        version: AppVersion, title: String, notes: String, pageURL: URL, downloadURL: URL? = nil,
        downloadDigest: String? = nil, downloadSize: Int64? = nil, signatureURL: URL? = nil, publishedAt: Date? = nil
    ) {
        self.version = version
        self.title = title
        self.notes = notes
        self.pageURL = pageURL
        self.downloadURL = downloadURL
        self.downloadDigest = downloadDigest
        self.downloadSize = downloadSize
        self.signatureURL = signatureURL
        self.publishedAt = publishedAt
    }

    public enum ParseError: Error, Equatable {
        case notARelease
        case draftOrPrerelease
        case badVersion(String)
    }

    private struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            var name: String
            var browserDownloadURL: URL
            var size: Int64?
            /// "sha256:<hex>", or null for assets uploaded before GitHub computed digests.
            var digest: String?

            enum CodingKeys: String, CodingKey {
                case name, size, digest
                case browserDownloadURL = "browser_download_url"
            }
        }
        var tagName: String
        var name: String?
        var body: String?
        var htmlURL: URL
        var draft: Bool?
        var prerelease: Bool?
        var publishedAt: String?
        var assets: [Asset]?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name, body, draft, prerelease, assets
            case htmlURL = "html_url"
            case publishedAt = "published_at"
        }
    }

    /// Parses the GitHub API response; `assetName` picks the download, and the asset of that name
    /// plus `.sig` its signature.
    public static func parse(gitHubJSON data: Data, assetName: String = "BatteryPulse.dmg") throws -> ReleaseInfo {
        let release: GitHubRelease
        do {
            release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            throw ParseError.notARelease
        }
        guard release.draft != true, release.prerelease != true else { throw ParseError.draftOrPrerelease }
        guard let version = AppVersion(release.tagName) else { throw ParseError.badVersion(release.tagName) }
        let image = release.assets?.first { $0.name == assetName }
        let signatureName = UpdateInstallPolicy.signatureAssetName(for: assetName)
        return ReleaseInfo(
            version: version,
            title: release.name?.isEmpty == false ? release.name ?? "" : "BatteryPulse \(version)",
            notes: release.body ?? "",
            pageURL: release.htmlURL,
            downloadURL: image?.browserDownloadURL,
            downloadDigest: image?.digest,
            downloadSize: image?.size,
            signatureURL: release.assets?.first { $0.name == signatureName }?.browserDownloadURL,
            publishedAt: release.publishedAt.flatMap { try? Date($0, strategy: .iso8601) }
        )
    }
}

/// How often BatteryPulse checks for updates on its own. Check for Updates works with any of them.
public enum UpdateFrequency: String, Sendable, CaseIterable {
    case daily, weekly, monthly, never

    /// The time between automatic checks; `nil` for never.
    public var interval: TimeInterval? {
        switch self {
        case .daily: 24 * 60 * 60
        case .weekly: 7 * 24 * 60 * 60
        case .monthly: 30 * 24 * 60 * 60
        case .never: nil
        }
    }

    /// The stored setting, or else the on/off switch that came before it: off becomes never,
    /// on or unset becomes daily.
    public static func stored(_ rawValue: String?, legacyEnabled: Bool?) -> UpdateFrequency {
        if let rawValue, let frequency = UpdateFrequency(rawValue: rawValue) { return frequency }
        return legacyEnabled == false ? .never : .daily
    }
}

/// When to check for updates and what to tell the user.
public enum UpdatePolicy {
    public static func isCheckDue(lastCheck: Date?, now: Date, frequency: UpdateFrequency) -> Bool {
        guard let interval = frequency.interval else { return false }
        guard let lastCheck else { return true }
        // A clock moved backwards also makes a check due.
        return now.timeIntervalSince(lastCheck) >= interval || now < lastCheck
    }

    /// Whether to offer `release` to someone running `current`. Automatic checks also respect a
    /// version the user chose to skip; a check the user asks for always reports it.
    public static func shouldOffer(
        _ release: ReleaseInfo, current: AppVersion, skipped: AppVersion?, userInitiated: Bool
    ) -> Bool {
        guard release.version > current else { return false }
        return userInitiated || skipped.map { release.version > $0 } ?? true
    }

    /// The "What's New" window appears once after an update that brought the listed features
    /// (`features`, the version they arrived in), not after a fresh install and not again for a
    /// later bug-fix release.
    public static func showsWhatsNew(lastSeen: AppVersion?, current: AppVersion, features: AppVersion) -> Bool {
        guard let lastSeen else { return false }
        return lastSeen < features && features <= current
    }
}

/// Release notes prepared for `AttributedString(markdown:)` with inline-only syntax, which keeps
/// line breaks but shows headings literally: headings become bold lines.
public enum ReleaseNotes {
    /// Headings become bold lines, and the lines of a paragraph or list item wrapped in the
    /// source are joined, since inline-only Markdown would keep every line break. Code blocks and
    /// tables keep their lines, and so does a line that ends with a hard line break.
    public static func inlineMarkdown(_ notes: String) -> String {
        // Notes edited on github.com can use CRLF, which `split(separator: "\n")` would miss: in
        // Swift "\r\n" is a single Character.
        let normalized = notes.replacing("\r\n", with: "\n").replacing("\r", with: "\n")
        let source = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var joiner = LineJoiner()
        for (index, line) in source.enumerated() {
            joiner.add(line, next: index + 1 < source.count ? source[index + 1] : nil)
        }
        return joiner.lines.joined(separator: "\n")
    }
}

extension ReleaseNotes {
    /// Reads GitHub Markdown line by line with just enough of its block structure to tell a line
    /// wrapped inside a paragraph, list item or quote from one that starts a block or has to keep
    /// its line break.
    struct LineJoiner {
        /// How the last line of the open paragraph ends.
        enum LineEnd {
            case softWrap
            /// Two trailing spaces, Markdown's explicit line break.
            case spaces
            /// A trailing backslash, the other explicit line break. It's dropped once the next
            /// line continues the paragraph, since inline rendering keeps the line break anyway.
            case backslash
        }

        /// The start of a list item.
        struct ListMarker {
            /// The start number of an ordered item; nil for a bullet.
            var number: Int?
            /// The column the item's text starts at.
            var contentIndent: Int
        }

        private(set) var lines: [String] = []
        /// The last of `lines` holds the text of a paragraph, list item or quote that the next
        /// line can continue.
        private var paragraph = false
        private var paragraphEnd = LineEnd.softWrap
        /// The open paragraph started with `>`.
        private var quoted = false
        /// The content indent of each open list item, outermost first.
        private var listItems: [Int] = []
        /// The fence of the open fenced code block.
        private var fence: (character: Character, length: Int)?
        /// The indent that the lines of the open indented code block are 4 or more columns past.
        private var indentedCode: Int?
        private var table = false

        mutating func add(_ line: String, next: String?) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let fence {
                if Self.closes(fence, trimmed) { self.fence = nil }
                lines.append(line)
                return
            }
            // A table goes on as long as its lines have a pipe.
            if table, trimmed.contains("|") {
                lines.append(line)
                return
            }
            table = false
            let indent = Self.indentation(of: line)
            if let base = indentedCode, trimmed.isEmpty || indent >= base + 4 {
                lines.append(line)
                return
            }
            indentedCode = nil
            if trimmed.isEmpty {
                lines.append(line)
                paragraph = false
                return
            }
            let marker = Self.listMarker(line, indent: indent)
            if paragraph, !startsBlock(trimmed, marker: marker, indent: indent, next: next) {
                continueParagraph(line, trimmed: trimmed)
            } else {
                startBlock(line, trimmed: trimmed, marker: marker, indent: indent, next: next)
            }
        }

        /// Whether a line below the text of a paragraph starts a block instead of continuing it.
        private func startsBlock(_ trimmed: String, marker: ListMarker?, indent: Int, next: String?) -> Bool {
            if [">", "|"].contains(where: trimmed.hasPrefix) || Self.openingFence(trimmed) != nil
                || Self.heading(trimmed) != nil || Self.isDelimiterRow(trimmed) || Self.isDelimiterRow(next)
            {
                return true
            }
            guard let marker else { return false }
            // Like a bullet, an ordered list can interrupt a paragraph, but only from 1, so a line
            // such as "2020. Older ones too." continues a sentence. Any number starts an item where
            // the paragraph's list item or quote ends, such as "2." below the text of "1.".
            guard let number = marker.number, number != 1 else { return true }
            return quoted || indent < (listItems.last ?? 0)
        }

        private mutating func continueParagraph(_ line: String, trimmed: String) {
            switch paragraphEnd {
            case .softWrap:
                lines[lines.count - 1] += " " + trimmed
            case .spaces:
                lines.append(line)
            case .backslash:
                lines[lines.count - 1].removeLast()
                lines.append(line)
            }
            paragraphEnd = Self.end(of: line)
        }

        private mutating func startBlock(
            _ line: String, trimmed: String, marker: ListMarker?, indent: Int, next: String?
        ) {
            // A line that doesn't reach a list item's text (and doesn't continue its paragraph)
            // ends the item.
            while let item = listItems.last, item > indent { listItems.removeLast() }
            let interruptsParagraph = paragraph
            paragraph = false
            let base = listItems.last ?? 0
            if !interruptsParagraph, indent >= base + 4 {
                indentedCode = base
                lines.append(line)
            } else if let opening = Self.openingFence(trimmed) {
                fence = opening
                lines.append(line)
            } else if let heading = Self.heading(trimmed) {
                lines.append("**" + heading + "**")
            } else if Self.isDelimiterRow(trimmed) || Self.isDelimiterRow(next) {
                // A table: its header, delimiter row and the rows below it.
                table = true
                lines.append(line)
            } else {
                if let marker { listItems.append(marker.contentIndent) }
                lines.append(line)
                paragraph = true
                paragraphEnd = Self.end(of: line)
                quoted = trimmed.hasPrefix(">")
            }
        }

        /// The text of an ATX heading such as `## Install`; `#hashtag` is not one.
        static func heading(_ line: String) -> String? {
            let text = line.drop { $0 == "#" }
            guard text.count < line.count, text.first == " " else { return nil }
            return text.trimmingCharacters(in: .whitespaces)
        }

        static func end(of line: String) -> LineEnd {
            if line.hasSuffix("  ") { return .spaces }
            // A backslash escapes the one before it: only an odd run ends in a line break.
            let backslashes = line.reversed().prefix { $0 == "\\" }.count
            return backslashes.isMultiple(of: 2) ? .softWrap : .backslash
        }

        /// The width of the line's leading whitespace in columns, with tab stops every 4.
        static func indentation(of line: String) -> Int {
            var columns = 0
            for character in line {
                if character == " " {
                    columns += 1
                } else if character == "\t" {
                    columns += 4 - columns % 4
                } else {
                    break
                }
            }
            return columns
        }

        /// A bullet (`-`, `*`, `+`) or an ordered marker (`1.`, `1)`) followed by a space and text.
        static func listMarker(_ line: String, indent: Int) -> ListMarker? {
            let text = line.drop { $0 == " " || $0 == "\t" }
            var number: Int?
            let width: Int
            if let first = text.first, "-*+".contains(first) {
                width = 1
            } else {
                let digits = text.prefix { $0.isASCII && $0.isNumber }
                guard (1...9).contains(digits.count), let delimiter = text.dropFirst(digits.count).first,
                    delimiter == "." || delimiter == ")"
                else { return nil }
                number = Int(digits)
                width = digits.count + 1
            }
            let rest = text.dropFirst(width)
            let spaces = rest.prefix { $0 == " " || $0 == "\t" }.count
            // An item with no text can't interrupt a paragraph; past 4 spaces the text is code.
            guard spaces > 0, spaces < rest.count else { return nil }
            return ListMarker(number: number, contentIndent: indent + width + (spaces > 4 ? 1 : spaces))
        }

        /// The fence that opens a fenced code block: 3 or more backticks or tildes. A backtick
        /// fence's info string has no backtick, which tells it from a line starting with inline code.
        static func openingFence(_ trimmed: String) -> (character: Character, length: Int)? {
            guard let character = trimmed.first, character == "`" || character == "~" else { return nil }
            let length = trimmed.prefix { $0 == character }.count
            guard length >= 3, character == "~" || !trimmed.dropFirst(length).contains("`") else { return nil }
            return (character, length)
        }

        /// Whether a line closes `fence`: the same character, at least as many times, alone.
        static func closes(_ fence: (character: Character, length: Int), _ trimmed: String) -> Bool {
            trimmed.count >= fence.length && trimmed.allSatisfy { $0 == fence.character }
        }

        /// A table's delimiter row such as `--- | :---:`, with or without the outer pipes.
        static func isDelimiterRow(_ line: String?) -> Bool {
            guard let line, line.contains("|") else { return false }
            var row = Substring(line.trimmingCharacters(in: .whitespaces))
            if row.first == "|" { row.removeFirst() }
            if row.last == "|" { row.removeLast() }
            return row.split(separator: "|", omittingEmptySubsequences: false).allSatisfy { cell in
                var dashes = Substring(cell.trimmingCharacters(in: .whitespaces))
                if dashes.first == ":" { dashes.removeFirst() }
                if dashes.last == ":" { dashes.removeLast() }
                return !dashes.isEmpty && dashes.allSatisfy { $0 == "-" }
            }
        }
    }
}
