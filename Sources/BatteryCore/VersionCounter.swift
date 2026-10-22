import Foundation

/// The anonymous version count: once per installed version, at least a day after it first ran,
/// an automatic update check that reached GitHub also downloads ``ReleaseChannel/counterAssetName``
/// from that version's release and ignores the body. The asset's public download count is then
/// the number of Macs that ran the version with automatic checks and the count on.
///
/// Nothing else is sent: the request carries only the User-Agent the check already sends and a
/// constant `Accept-Language` (``headers(for:)``), on the automatic check's session. Check for
/// Updates never counts, and neither does a Mac whose automatic checks are off.
///
/// The decisions live here so Linux tests cover them; the app's update checker makes the request.
/// Internal until the app uses it: BatteryCore's public code is linked into both the app and the
/// widget whether they use it or not.
enum VersionCounterPolicy {
    /// A missing setting means on. Only the toggle writes it, so a later release can change the
    /// default for everyone who never chose.
    static let isOnByDefault = true

    /// How long after a version first ran on this Mac it is counted, so the switch that turns the
    /// count off comes before the first count.
    static let gracePeriod: TimeInterval = 24 * 60 * 60

    /// The first version with the count. An update from an earlier one announces it.
    static let introducedIn = AppVersion(parts: [0, 7, 0])

    /// The setting, `nil` when the user never chose.
    static func isEnabled(stored: Bool?) -> Bool {
        stored ?? isOnByDefault
    }

    /// Whether an automatic check that just reached GitHub also counts `current`: the count is on,
    /// automatic checks are on, `current` is a release version (``url(for:)``) other than the last
    /// one counted, and it first ran on this Mac (`versionSince`) at least ``gracePeriod`` ago.
    /// Without that date nothing is counted. A clock moved backwards ends the wait, as it makes a
    /// check due (``UpdatePolicy/isCheckDue(lastCheck:now:frequency:)``).
    static func shouldCount(
        enabled: Bool, frequency: UpdateFrequency, current: AppVersion, lastCounted: AppVersion?,
        versionSince: Date?, now: Date
    ) -> Bool {
        guard enabled, frequency != .never, url(for: current) != nil, lastCounted != current,
            let versionSince
        else { return false }
        return now.timeIntervalSince(versionSince) >= gracePeriod || now < versionSince
    }

    /// The counter asset of `version`'s release, or `nil` unless `version` has exactly three parts
    /// and isn't ``UpdateInstallPolicy/unversioned``: releases are tagged `vX.Y.Z`, so any other
    /// version could only answer 404.
    static func url(for version: AppVersion) -> URL? {
        guard version.parts.count == 3, version.parts.allSatisfy({ $0 >= 0 }),
            version != UpdateInstallPolicy.unversioned
        else { return nil }
        return ReleaseChannel.releaseAsset(ReleaseChannel.counterAssetName, of: version)
    }

    /// The request's only headers: the User-Agent the update check sends, and a constant
    /// `Accept-Language` in place of the one URLSession would add from the user's languages.
    static func headers(for version: AppVersion) -> [String: String] {
        ["User-Agent": "BatteryPulse/\(version)", "Accept-Language": "*"]
    }

    /// What a count's answer means. The case names are what the `update` log shows.
    enum Outcome: String, Sendable {
        /// 200: GitHub counted the download.
        case counted
        /// 404: the release has no counter asset, or the version has no release, such as a release
        /// candidate's.
        case noCounter
        /// Anything else, including no answer at all: the next due automatic check tries again.
        case failed
    }

    /// The outcome of the final answer's status code, after GitHub's redirect; `nil` when no
    /// answer came (a transport error or a cancelled request).
    static func outcome(statusCode: Int?) -> Outcome {
        switch statusCode {
        case 200: .counted
        case 404: .noCounter
        default: .failed
        }
    }

    /// Whether the version is done with: counted, or without a counter that it could ever count.
    static func marksCounted(_ outcome: Outcome) -> Bool {
        outcome != .failed
    }

    /// Whether What's New announces the count after an update from `previous`, the version that
    /// ran before this launch: from any version before ``introducedIn``, so a jump from 0.6 straight
    /// to a later release announces it too. A fresh install (`nil`) sees the setting itself first.
    static func showsAnnouncement(previous: AppVersion?) -> Bool {
        guard let previous else { return false }
        return previous < introducedIn
    }
}
