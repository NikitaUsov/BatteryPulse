import Foundation
import Testing

@testable import BatteryCore

/// The anonymous version count's decisions (W-13): when an automatic check also counts the
/// installed version, the request it makes and what each answer means.
@Suite struct VersionCounterTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let hour: TimeInterval = 60 * 60
    private let v070 = AppVersion(parts: [0, 7, 0])

    /// `shouldCount` with every input but the one a test varies set so that it counts.
    private func counts(
        enabled: Bool = true, frequency: UpdateFrequency = .daily, current: AppVersion? = nil,
        lastCounted: AppVersion? = nil, since ago: TimeInterval? = 24 * 60 * 60
    ) -> Bool {
        VersionCounterPolicy.shouldCount(
            enabled: enabled, frequency: frequency, current: current ?? v070, lastCounted: lastCounted,
            versionSince: ago.map { now.addingTimeInterval(-$0) }, now: now)
    }

    @Test func onUnlessTurnedOff() {
        #expect(VersionCounterPolicy.isOnByDefault)
        #expect(VersionCounterPolicy.isEnabled(stored: nil))
        #expect(VersionCounterPolicy.isEnabled(stored: true))
        #expect(!VersionCounterPolicy.isEnabled(stored: false))
    }

    @Test func onlyWithAutomaticChecks() {
        #expect(!counts(frequency: .never))
        for frequency in [UpdateFrequency.daily, .weekly, .monthly] {
            #expect(counts(frequency: frequency), "\(frequency)")
        }
    }

    @Test func neverWhenOff() {
        #expect(!counts(enabled: false))
        #expect(!counts(enabled: false, lastCounted: AppVersion(parts: [0, 6, 2])))
    }

    @Test func oncePerVersion() {
        #expect(counts(lastCounted: nil))
        #expect(!counts(lastCounted: v070))
        #expect(!counts(lastCounted: AppVersion("0.7")), "0.7 is 0.7.0")
        #expect(counts(current: AppVersion(parts: [0, 7, 1]), lastCounted: v070))
        #expect(counts(current: AppVersion(parts: [1, 0, 0]), lastCounted: v070))
    }

    @Test func waitsADayAfterTheVersionFirstRan() {
        #expect(VersionCounterPolicy.gracePeriod == 24 * hour)
        #expect(!counts(since: 24 * hour - 60), "23 h 59 min")
        #expect(counts(since: 24 * hour))
        #expect(counts(since: 30 * 24 * hour))
        #expect(!counts(since: 0))
        #expect(!counts(since: nil), "no first-run date")
        #expect(counts(since: -hour), "clock moved back")
    }

    @Test func onlyReleaseVersionsHaveACounter() {
        for version in [
            UpdateInstallPolicy.unversioned, AppVersion(parts: [0, 7]), AppVersion(parts: [0, 7, 0, 1]),
            AppVersion(parts: [1]), AppVersion(parts: []), AppVersion(parts: [0, -7, 0]),
        ] {
            #expect(VersionCounterPolicy.url(for: version) == nil, "\(version)")
            #expect(!counts(current: version), "\(version)")
        }
        #expect(VersionCounterPolicy.url(for: AppVersion(parts: [0, 6, 99])) != nil, "a candidate's 404 marks it")
        #expect(VersionCounterPolicy.url(for: AppVersion(parts: [0, 0, 1])) != nil)
    }

    @Test func theCounterURL() {
        #expect(
            VersionCounterPolicy.url(for: v070)?.absoluteString
                == "https://github.com/NikitaUsov/BatteryPulse/releases/download/v0.7.0/BatteryPulse-count.txt")
        #expect(
            VersionCounterPolicy.url(for: AppVersion(parts: [1, 2, 3]))?.absoluteString
                == "https://github.com/NikitaUsov/BatteryPulse/releases/download/v1.2.3/BatteryPulse-count.txt")
        #expect(ReleaseChannel.counterAssetName == "BatteryPulse-count.txt")
    }

    /// The same URL GitHub gave as `browser_download_url` for 0.2.0's DMG.
    @Test func releaseAssetsAsGitHubBuildsThem() {
        #expect(
            ReleaseChannel.releaseAsset(ReleaseChannel.assetName, of: AppVersion(parts: [0, 2, 0])).absoluteString
                == "https://github.com/NikitaUsov/BatteryPulse/releases/download/v0.2.0/BatteryPulse.dmg")
    }

    @Test func outcomes() {
        #expect(VersionCounterPolicy.outcome(statusCode: 200) == .counted)
        #expect(VersionCounterPolicy.outcome(statusCode: 404) == .noCounter)
        for code in [403, 429, 500, 503, 302, 204, nil] as [Int?] {
            #expect(VersionCounterPolicy.outcome(statusCode: code) == .failed, "\(String(describing: code))")
        }
        #expect(VersionCounterPolicy.marksCounted(.counted))
        #expect(VersionCounterPolicy.marksCounted(.noCounter))
        #expect(!VersionCounterPolicy.marksCounted(.failed))
    }

    /// The `update` log shows these names, and the session script looks for `counted`.
    @Test func outcomeNamesAreTheLoggedOnes() {
        #expect(VersionCounterPolicy.Outcome.counted.rawValue == "counted")
        #expect(VersionCounterPolicy.Outcome.noCounter.rawValue == "noCounter")
        #expect(VersionCounterPolicy.Outcome.failed.rawValue == "failed")
    }

    @Test func sendsOnlyTwoHeaders() {
        #expect(
            VersionCounterPolicy.headers(for: v070) == ["User-Agent": "BatteryPulse/0.7.0", "Accept-Language": "*"])
        #expect(VersionCounterPolicy.headers(for: AppVersion(parts: [1, 2, 3]))["User-Agent"] == "BatteryPulse/1.2.3")
    }

    @Test func announcedAfterAnUpdateFromBeforeTheCount() {
        #expect(VersionCounterPolicy.introducedIn == v070)
        #expect(!VersionCounterPolicy.showsAnnouncement(previous: nil), "a fresh install")
        #expect(VersionCounterPolicy.showsAnnouncement(previous: AppVersion(parts: [0, 6, 2])))
        #expect(VersionCounterPolicy.showsAnnouncement(previous: AppVersion(parts: [0, 6, 99])))
        #expect(VersionCounterPolicy.showsAnnouncement(previous: AppVersion(parts: [0, 2])))
        #expect(!VersionCounterPolicy.showsAnnouncement(previous: v070))
        #expect(!VersionCounterPolicy.showsAnnouncement(previous: AppVersion(parts: [0, 7])))
        #expect(!VersionCounterPolicy.showsAnnouncement(previous: AppVersion(parts: [0, 7, 1])))
    }
}
