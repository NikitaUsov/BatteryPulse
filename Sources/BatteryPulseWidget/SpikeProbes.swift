#if os(macOS)
import BatteryCore
import BatteryKit
import Darwin
import Foundation
import os

// SPIKE-W (docs/plans/0.6.2/PLAN.md, WP-W0), spike branch only: what the sandboxed widget can read
// besides the battery. Once per battery timeline it tries both feed candidates of W0-3 and the
// accessory read of W0-4 (1). Session A reads the lines; they hold the candidate's name, errno,
// byte counts and the feed's age and counter, never a path.

/// The feed's payload, as the app's `SpikeWidgetFeed` writes it.
struct SpikeFeedPayload: Codable {
    var version: Int
    var writtenAt: Date
    var sequence: Int
}

@MainActor
enum SpikeProbes {
    /// W0-3's candidates, as the log names them.
    enum Candidate: String {
        /// A file in the app's `Widget` folder of Application Support.
        case a = "A"
        /// A preference domain of its own (A′).
        case aPrime = "Aprime"
    }

    /// Candidate A′'s domain and key, as in the widget's entitlements and the app's writer.
    static let feedDomain = "io.github.nikitausov.BatteryPulse.widgetfeed"
    static let feedKey = "feed"
    /// The reader of §8.3 rejects larger files.
    static let maximumBytes = 32 * 1024

    /// The battery timeline's probes, in order.
    static func run() {
        readFileFeed()
        readPreferenceFeed()
        readAccessories()
    }

    /// Candidate A. A denial is silent on macOS 27, so the line has errno: 1 (EPERM) for the
    /// sandbox, 2 (ENOENT) when the app hasn't written the file yet.
    static func readFileFeed() {
        guard let home = realHome() else {
            spikeLog.error("spike feed candidate=A no home directory")
            return
        }
        let path = home + "/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget/feed.json"
        let descriptor = Darwin.open(path, O_RDONLY | O_CLOEXEC)
        guard descriptor >= 0 else {
            let code = errno
            spikeLog.notice("spike feed candidate=A failed errno=\(code, privacy: .public)")
            return
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
            report(.a, data)
        } catch {
            let code = (error as NSError).code
            spikeLog.notice("spike feed candidate=A read failed code=\(code, privacy: .public)")
        }
    }

    /// Candidate A′: the domain reads as empty when the sandbox keeps it from the widget.
    static func readPreferenceFeed() {
        guard let defaults = UserDefaults(suiteName: feedDomain) else {
            spikeLog.notice("spike feed candidate=Aprime no domain")
            return
        }
        guard let data = defaults.data(forKey: feedKey) else {
            spikeLog.notice("spike feed candidate=Aprime no value")
            return
        }
        report(.aPrime, data)
    }

    /// "feed ok" with the byte count, the feed's age in seconds and its counter, so a feed the
    /// app wrote while the widget wasn't running shows by its age.
    static func report(_ candidate: Candidate, _ data: Data) {
        guard data.count <= maximumBytes else {
            spikeLog.notice(
                "spike feed candidate=\(candidate.rawValue, privacy: .public) too large bytes=\(data.count, privacy: .public)"
            )
            return
        }
        do {
            let payload = try JSONDecoder().decode(SpikeFeedPayload.self, from: data)
            let age = Int(Date.now.timeIntervalSince(payload.writtenAt).rounded())
            spikeLog.notice(
                "spike feed candidate=\(candidate.rawValue, privacy: .public) feed ok bytes=\(data.count, privacy: .public) age=\(age, privacy: .public)s sequence=\(payload.sequence, privacy: .public) version=\(payload.version, privacy: .public)"
            )
        } catch {
            spikeLog.notice(
                "spike feed candidate=\(candidate.rawValue, privacy: .public) undecodable bytes=\(data.count, privacy: .public)"
            )
        }
    }

    /// The user's real home from the user database: inside the sandbox, `NSHomeDirectory()` is
    /// the extension's container, and the entitlement's path is relative to the real one.
    static func realHome() -> String? {
        guard let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir else { return nil }
        return String(cString: directory)
    }

    /// W0-4 (1): the one-shot read an Accessories widget would make, never the notify
    /// registrations. `unavailable` means the private function is missing; zero sources with an
    /// accessory connected means the sandbox hides them.
    static func readAccessories() {
        guard let reading = MacAccessoryProvider().read() else {
            spikeLog.notice("spike accessories unavailable")
            return
        }
        spikeLog.notice(
            "spike accessories sources=\(reading.sources.count, privacy: .public) accessories=\(reading.accessories.count, privacy: .public)"
        )
    }
}
#endif
