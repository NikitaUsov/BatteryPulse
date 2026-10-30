import Foundation

/// When the app asks WidgetKit to reload the widget. The budget is about 40–70 reloads a day,
/// so plugging in, unplugging, a change of charge state and the first estimate after one go
/// through at once. A percentage that moved ``percentStep`` points, or an estimate whose clock
/// time ("Lasts until about 16:39") moved ``estimateShift``, waits until ``minimumInterval`` has
/// passed since the last reload: at most four such reloads an hour, so the widget never shows a
/// reading much older than a quarter of an hour while the battery changes.
public struct WidgetReloadPolicy: Sendable {
    public static let percentStep = 3
    public static let estimateShift: TimeInterval = 15 * 60
    public static let minimumInterval: TimeInterval = 15 * 60

    private struct Shown: Equatable {
        var state: ChargeState
        var isExternalPowerConnected: Bool?
        var percent: Int?
        /// When the shown estimate runs out; `nil` without one.
        var estimateEnd: Date?
    }

    private var shown: Shown?
    private var lastReload: Date?

    public init() {}

    /// Whether `snapshot` warrants a reload now; records it as shown when it does.
    public mutating func shouldReload(for snapshot: BatterySnapshot, at date: Date) -> Bool {
        let next = Shown(
            state: snapshot.chargeState,
            isExternalPowerConnected: snapshot.isExternalPowerConnected,
            percent: snapshot.chargePercent.map { Int($0.rounded()) },
            estimateEnd: WidgetTimelinePlan.estimateMinutes(snapshot).map { date.addingTimeInterval(Double($0) * 60) })
        guard let shown else {
            record(next, at: date)
            return true
        }
        let stateChanged =
            next.state != shown.state || next.isExternalPowerConnected != shown.isExternalPowerConnected
        // macOS calculates for a minute or so after plugging in or unplugging, so the reload at the
        // change itself shows no estimate.
        let estimateArrived = shown.estimateEnd == nil && next.estimateEnd != nil
        let percentMoved = abs((next.percent ?? 0) - (shown.percent ?? 0)) >= Self.percentStep
        // The estimate settles over the first minutes on battery and follows the load after that.
        let estimateMoved =
            if let shownEnd = shown.estimateEnd, let nextEnd = next.estimateEnd {
                abs(nextEnd.timeIntervalSince(shownEnd)) >= Self.estimateShift
            } else {
                false
            }
        let intervalPassed = lastReload.map { date.timeIntervalSince($0) >= Self.minimumInterval } ?? true
        guard stateChanged || estimateArrived || ((percentMoved || estimateMoved) && intervalPassed) else {
            return false
        }
        record(next, at: date)
        return true
    }

    private mutating func record(_ next: Shown, at date: Date) {
        shown = next
        lastReload = date
    }
}
