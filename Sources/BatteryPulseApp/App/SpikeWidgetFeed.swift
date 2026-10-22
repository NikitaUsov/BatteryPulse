#if os(macOS)
import Foundation
import os

/// SPIKE-W (docs/plans/0.6.2/PLAN.md, WP-W0, W0-3), spike branch only: one small payload for both
/// of the widget's feed candidates. A is `feed.json` in `Widget` beside `Devices` in Application
/// Support, the folder the widget's home-relative-path exception names (0700, the file 0600);
/// A′ is the same bytes in a preference domain of its own, never the settings domain.
///
/// Written at launch and before each widget reload, moments the app already wakes for; the
/// refresher skips Demo Mode, so nothing is written for it. The payload holds a version, the
/// write time and a counter, nothing about the battery or the user.
@MainActor
enum SpikeWidgetFeed {
    /// Candidate A′'s domain and key, as in the widget's entitlements and reader.
    static let domain = "io.github.nikitausov.BatteryPulse.widgetfeed"
    static let key = "feed"

    private struct Payload: Codable {
        var version: Int
        var writtenAt: Date
        var sequence: Int
    }

    /// Counts the writes since launch, so the widget's lines show which write it read.
    private static var sequence = 0

    /// `~/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget`: the path in the
    /// widget's entitlement, whatever the bundle identifier of this build.
    static var directory: URL {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("io.github.nikitausov.BatteryPulse").appendingPathComponent("Widget")
    }

    static func write() {
        sequence += 1
        let data: Data
        do {
            data = try JSONEncoder().encode(Payload(version: 1, writtenAt: .now, sequence: sequence))
        } catch {
            Diagnostics.widget.error("spike feed write: the payload didn't encode")
            return
        }
        writeFile(data)
        writePreference(data)
    }

    private static func writeFile(_ data: Data) {
        let file = directory.appendingPathComponent("feed.json")
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try data.write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            Diagnostics.widget.notice(
                "spike feed write candidate=A ok bytes=\(data.count, privacy: .public) sequence=\(sequence, privacy: .public)"
            )
        } catch {
            let code = (error as NSError).code
            Diagnostics.widget.error("spike feed write candidate=A failed code=\(code, privacy: .public)")
        }
    }

    private static func writePreference(_ data: Data) {
        guard let defaults = UserDefaults(suiteName: domain) else {
            Diagnostics.widget.error("spike feed write candidate=Aprime no domain")
            return
        }
        defaults.set(data, forKey: key)
        Diagnostics.widget.notice(
            "spike feed write candidate=Aprime ok bytes=\(data.count, privacy: .public) sequence=\(sequence, privacy: .public)"
        )
    }
}
#endif
