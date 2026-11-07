import BatteryCore
import Foundation
import Synchronization

#if canImport(os)
import os
#endif

/// Reads the Charge Limit's number from powerd's charging preferences, the one source of the limit
/// set in System Settings → Battery (BatteryCore's `SystemChargeLimitSource`), as
/// `SystemChargeLimitReadPolicy` decides: the first reading on the adapter, a plug-in, the hold
/// beginning or ending, and Power appearing; never per poll. Between those reads it keeps the last
/// number while the Mac stays on the adapter, and on battery there is none.
///
/// The app's monitor and `bpulse` use it, apart from the battery's provider, which the sandboxed
/// widget uses too: the widget never reads this file (`SecurityGuardTests`), and shows the number
/// from the app's feed instead. A read of a capture never calls it. Nonisolated and `Sendable`,
/// what it keeps behind a `Mutex`, so the monitor calls it inside its reads off the main actor.
public nonisolated final class SystemChargeLimitReader: Sendable {
    /// powerd's charging preferences: root's, and readable by every user. This file is the only
    /// one that names it (`SecurityGuardTests`).
    public static let path = "/Library/Preferences/com.apple.powerd.charging.plist"

    private let readFile: @Sendable () -> SystemChargeLimitSource.Outcome
    private let logsReads: Bool
    private let state = Mutex(State())

    private struct State {
        var policy = SystemChargeLimitReadPolicy()
        /// The last read's number, kept while the Mac stays on the adapter.
        var percent: Int?
    }

    /// - Parameters:
    ///   - url: The file; tests pass one of their own.
    ///   - logsReads: Whether each read logs its `monitor` line: the app's do; `bpulse`'s don't,
    ///     so the session's count of the app's reads doesn't count the command line's.
    public convenience init(url: URL = URL(fileURLWithPath: SystemChargeLimitReader.path), logsReads: Bool = true) {
        self.init(logsReads: logsReads) { Self.read(url) }
    }

    /// A reader whose reads of the file are `readFile`: tests count them.
    init(logsReads: Bool, readFile: @escaping @Sendable () -> SystemChargeLimitSource.Outcome) {
        self.readFile = readFile
        self.logsReads = logsReads
    }

    /// Sets `reading`'s `systemChargeLimitPercent`: from a read of the file when the policy's
    /// trigger fires, else the last read's number on the adapter, and none on battery. `powerShown`:
    /// Power appeared since the last reading.
    public func update(_ reading: inout BatteryReading, powerShown: Bool = false) {
        let snapshot = reading.snapshot
        let trigger = state.withLock { $0.policy.trigger(for: snapshot, powerShown: powerShown) }
        let percent: Int?
        if let trigger {
            let outcome = readFile()
            log(outcome, trigger: trigger)
            percent = outcome.percent
        } else {
            percent = snapshot.isExternalPowerConnected == true ? state.withLock { $0.percent } : nil
        }
        state.withLock { $0.percent = percent }
        reading.snapshot.systemChargeLimitPercent = percent
    }

    /// Forgets what the readings showed, so the next one on the adapter reads the file: the
    /// monitor's restart, and Demo Mode's start and end.
    public func reset() {
        state.withLock { $0 = State() }
    }

    /// The outcome of one read of the file at `url`.
    static func read(_ url: URL) -> SystemChargeLimitSource.Outcome {
        do {
            return SystemChargeLimitSource.outcome(fileData: try Data(contentsOf: url))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return .noFile
        } catch {
            return .notReadable
        }
    }

    /// One `monitor` line per read, at notice so `log show` finds it: the trigger's and the
    /// outcome's case names and the percent, never the path or an error's description.
    private func log(_ outcome: SystemChargeLimitSource.Outcome, trigger: SystemChargeLimitReadPolicy.Trigger) {
        #if canImport(os)
        guard logsReads else { return }
        Diagnostics.monitor.notice(
            "Charge Limit read (\(trigger.rawValue, privacy: .public)): \(outcome.summary, privacy: .public)")
        #endif
    }
}
