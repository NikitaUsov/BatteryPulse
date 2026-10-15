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
    public var publishedAt: Date?

    public init(
        version: AppVersion, title: String, notes: String, pageURL: URL, downloadURL: URL? = nil,
        publishedAt: Date? = nil
    ) {
        self.version = version
        self.title = title
        self.notes = notes
        self.pageURL = pageURL
        self.downloadURL = downloadURL
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

            enum CodingKeys: String, CodingKey {
                case name
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

    /// Parses the GitHub API response; `assetName` picks the download.
    public static func parse(gitHubJSON data: Data, assetName: String = "BatteryPulse.dmg") throws -> ReleaseInfo {
        let release: GitHubRelease
        do {
            release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            throw ParseError.notARelease
        }
        guard release.draft != true, release.prerelease != true else { throw ParseError.draftOrPrerelease }
        guard let version = AppVersion(release.tagName) else { throw ParseError.badVersion(release.tagName) }
        return ReleaseInfo(
            version: version,
            title: release.name?.isEmpty == false ? release.name ?? "" : "BatteryPulse \(version)",
            notes: release.body ?? "",
            pageURL: release.htmlURL,
            downloadURL: release.assets?.first { $0.name == assetName }?.browserDownloadURL,
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
    /// source are joined, since inline-only Markdown would keep every line break.
    public static func inlineMarkdown(_ notes: String) -> String {
        // Notes edited on github.com can use CRLF, which `split(separator: "\n")` would miss: in
        // Swift "\r\n" is a single Character.
        let normalized = notes.replacing("\r\n", with: "\n").replacing("\r", with: "\n")
        var lines: [String] = []
        var joinsNext = false
        var inCodeBlock = false
        for line in normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") { inCodeBlock.toggle() }
            if inCodeBlock || trimmed.hasPrefix("```") {
                lines.append(line)
                joinsNext = false
            } else if let heading = heading(trimmed) {
                lines.append("**" + heading + "**")
                joinsNext = false
            } else if joinsNext, !trimmed.isEmpty, !startsBlock(trimmed), let last = lines.popLast() {
                lines.append(last + " " + trimmed)
                joinsNext = !line.hasSuffix("  ")
            } else {
                lines.append(line)
                // Two trailing spaces are Markdown's explicit line break.
                joinsNext = !trimmed.isEmpty && !line.hasSuffix("  ")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// The text of an ATX heading such as `## Install`; `#hashtag` is not one.
    static func heading(_ line: String) -> String? {
        let text = line.drop { $0 == "#" }
        guard text.count < line.count, text.first == " " else { return nil }
        return text.trimmingCharacters(in: .whitespaces)
    }

    /// A line that starts its own block: a list item, quote or table row.
    static func startsBlock(_ line: String) -> Bool {
        if ["- ", "* ", "+ ", ">", "|"].contains(where: line.hasPrefix) { return true }
        let digits = line.prefix { $0.isNumber }
        return !digits.isEmpty && line.dropFirst(digits.count).hasPrefix(". ")
    }
}
