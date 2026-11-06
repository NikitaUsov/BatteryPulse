import Foundation
import Testing

@testable import BatteryCore

/// X-2: what a write of the widget feed shows the placed widgets that their own timelines would
/// show only at their next refresh, up to an hour later, and the reloads it asks for. A launch
/// reloaded nothing and the first write reloaded nothing, so after BatteryPulse was quit for two
/// hours or more, or without a feed at all (an update from 0.7.0), the History widget kept "Open
/// BatteryPulse to update" until its hourly timeline, and the iPhone & iPad widget and the large
/// Battery widget's chart until their half-hourly ones.
@Suite struct WriteEffectTests {
    static let now = WidgetFeedTests.now

    static func at(minutes: Double) -> Date {
        now.addingTimeInterval(minutes * 60)
    }

    static func feed(at date: Date = now) -> WidgetFeed {
        WidgetFeed.sample(at: date)
    }

    static func file(_ directory: URL) -> URL {
        directory.appendingPathComponent(WidgetFeedStore.fileName)
    }

    /// A store over a folder that holds `contents` as the feed a previous launch left, if any.
    static func store(leaving contents: Data?) throws -> (WidgetFeedStore, URL) {
        let directory = WidgetFeedStoreTests.temporaryDirectory()
        if let contents {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try contents.write(to: file(directory))
        }
        return (WidgetFeedStore(directory: directory), directory)
    }

    // MARK: The feed a write replaces

    /// Before this launch's first write, the store reads the file a previous launch left as the
    /// widget reads it: none, or one the widget turns down, is one the widgets couldn't use.
    @Test func aFirstWriteOverAFileTheWidgetsCouldntUseRepairsIt() throws {
        let garbage = Data("{\"version\":1}".utf8)
        let future = try WidgetFeed.encoded(Self.feed(at: Self.at(minutes: 11)))
        let oversized = Data(repeating: 0x20, count: WidgetFeed.maximumBytes + 1)
        for contents in [nil, garbage, future, oversized] {
            let (store, directory) = try Self.store(leaving: contents)
            defer { WidgetFeedStoreTests.remove(directory) }
            let (outcome, effect) = try store.writeReporting(Self.feed())
            #expect(outcome != .unchanged)
            #expect(effect.repair == .unusable, "\(contents.map(\.count) ?? -1) bytes")
        }
    }

    /// A link in the feed's place, to a feed just written, is one the widget turns down: the store
    /// reads its type without following it, and replaces the link, never what it points to.
    @Test func aLinkInTheFeedsPlaceIsOneTheWidgetsCouldntUse() throws {
        let (store, directory) = try Self.store(leaving: nil)
        defer { WidgetFeedStoreTests.remove(directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = directory.deletingLastPathComponent().appendingPathComponent("elsewhere.json")
        let fresh = try WidgetFeed.encoded(Self.feed())
        try fresh.write(to: target)
        try FileManager.default.createSymbolicLink(at: Self.file(directory), withDestinationURL: target)
        #expect(try store.writeReporting(Self.feed()).effect.repair == .unusable)
        #expect(try Data(contentsOf: target) == fresh)
    }

    /// A feed a previous launch left an hour ago or more: the widgets' timelines made from it can
    /// reach "Open BatteryPulse to update" before their own refresh reads the new one.
    @Test func aFirstWriteOverAnAgedFileRepairsIt() throws {
        for (minutes, repair) in [(-60.0, WidgetFeed.Repair.outdated), (-59, nil), (-3 * 60, .outdated), (-1, nil)] {
            let (store, directory) = try Self.store(
                leaving: WidgetFeed.encoded(Self.feed(at: Self.at(minutes: minutes))))
            defer { WidgetFeedStoreTests.remove(directory) }
            #expect(try store.writeReporting(Self.feed()).effect.repair == repair, "\(minutes) minutes")
        }
    }

    /// Within a launch, the feed last written is the one the widgets read: only a gap of an hour
    /// (the Mac asleep, Demo Mode, writes that failed) or a clock set back over 10 minutes needs a
    /// reload. A write of nothing new writes nothing, and shows nothing.
    @Test func aLaterWriteRepairsOnlyAfterAGap() throws {
        let (store, directory) = try Self.store(leaving: nil)
        defer { WidgetFeedStoreTests.remove(directory) }
        #expect(try store.writeReporting(Self.feed()).effect.repair == .unusable)
        #expect(try store.writeReporting(Self.feed(at: Self.at(minutes: 15)), unchanged: true).effect == .nothing)
        let unchanged = try store.writeReporting(Self.feed(at: Self.at(minutes: 15)).written(at: Self.at(minutes: 16)))
        #expect(unchanged.outcome == .unchanged && unchanged.effect == .nothing)
        #expect(try store.writeReporting(Self.feed(at: Self.at(minutes: 74)), unchanged: true).effect == .nothing)
        #expect(
            try store.writeReporting(Self.feed(at: Self.at(minutes: 135)), unchanged: true).effect.repair == .outdated)
        // The clock set back 5 minutes: the last feed is still one the widgets take.
        #expect(try store.writeReporting(Self.feed(at: Self.at(minutes: 130)), unchanged: true).effect == .nothing)
        // Set back 11 minutes more: they turn it down as written in the future.
        #expect(
            try store.writeReporting(Self.feed(at: Self.at(minutes: 119)), unchanged: true).effect.repair == .unusable)
    }

    /// The age is where a timeline made from the feed it replaces still refreshes before the
    /// feed turns two hours old: a write within it reaches every widget before "Open BatteryPulse
    /// to update" would show.
    @Test func theRepairAgeLeavesTheWidgetsTimeToRefresh() {
        #expect(WidgetFeed.repairAge == 60 * 60)
        let written = Self.now
        let outdated = written.addingTimeInterval(WidgetFeed.outdatedAge)
        // A timeline made from the feed at any moment before the next write, which comes within
        // the repair age, reads again before the feed turns two hours old.
        for minutes in stride(from: 0.0, to: WidgetFeed.repairAge / 60, by: 1) {
            let made = written.addingTimeInterval(minutes * 60)
            #expect(WidgetTimelinePlan.history(writtenAt: written, at: made).nextReload < outdated)
            #expect(WidgetTimelinePlan.devices(writtenAt: written, at: made, timeZone: .gmt).nextReload < outdated)
            #expect(WidgetTimelinePlan(snapshot: nil, at: made).nextReload < outdated)
        }
    }

    @Test func eachRepairReloadsTheKindsThatShowIt() {
        #expect(WidgetFeed.Repair.outdated.readers == [.battery, .history, .devices])
        #expect(WidgetFeed.Repair.unusable.readers == WidgetKindID.allCases)
        var effect = WidgetFeed.WriteEffect(repair: .outdated)
        effect.formUnion(WidgetFeed.WriteEffect(repair: .unusable))
        #expect(effect.repair == .unusable)
        effect.formUnion(WidgetFeed.WriteEffect(repair: .outdated))
        effect.formUnion(.nothing)
        #expect(effect.repair == .unusable)
    }

    // MARK: The reloads

    /// A repair reloads its kinds at once, within each kind's immediate minimum, which it shares
    /// with the removals and the Battery kind's five immediate reasons; one that waits reloads at
    /// the first evaluation after it, once.
    @Test func aRepairReloadsWithinTheImmediateMinimum() {
        var planner = WidgetReloadPlanner()
        #expect(
            planner.written(WidgetFeed.WriteEffect(repair: .unusable), at: Self.at(minutes: 0))
                == WidgetKindID.allCases.map { .init($0, .repair) })
        #expect(planner.written(WidgetFeed.WriteEffect(repair: .outdated), at: Self.at(minutes: 2)) == [])
        #expect(planner.pendingReloads(at: Self.at(minutes: 4)) == [])
        #expect(planner.pendingReloads(at: Self.at(minutes: 5)).map(\.kind) == [.battery, .history, .devices])
        #expect(planner.pendingReloads(at: Self.at(minutes: 6)) == [])
        #expect(planner.written(.nothing, at: Self.at(minutes: 30)) == [])
        // The removal right after a repair waits for the minimum too.
        #expect(planner.written(WidgetFeed.WriteEffect(repair: .outdated), at: Self.at(minutes: 30)).count == 3)
        #expect(planner.removal(of: .devices, at: Self.at(minutes: 31)) == [])
        #expect(planner.pendingReloads(at: Self.at(minutes: 35)) == [.init(.devices, .removal)])
        #expect(WidgetReloadPlanner.Reason.repair.rawValue == "repair")
    }

    /// The Battery kind's repair shares the minimum of its five immediate reasons.
    @Test func theBatteryKindsRepairSharesItsImmediateMinimum() {
        var planner = WidgetReloadPlanner()
        let off = WidgetReloadPlannerTests.snapshot()
        let on = WidgetReloadPlannerTests.snapshot(lowPower: true)
        #expect(planner.battery(off, at: Self.at(minutes: 0)) == nil)
        #expect(planner.battery(on, at: Self.at(minutes: 1)) == .lowPowerMode)
        #expect(
            planner.written(WidgetFeed.WriteEffect(repair: .outdated), at: Self.at(minutes: 2)).map(\.kind) == [
                .history, .devices,
            ])
        #expect(planner.pendingReloads(at: Self.at(minutes: 6)) == [.init(.battery, .repair)])
        #expect(planner.battery(off, at: Self.at(minutes: 7)) == nil)
        #expect(planner.battery(off, at: Self.at(minutes: 11)) == .lowPowerMode)
    }

    // MARK: The day's budget

    /// The writes of a day that asks for every feed reload there is: the launch over no feed, and
    /// two wakes after more than an hour asleep.
    struct FeedDay {
        struct Event {
            var minute: Int
            var effect: WidgetFeed.WriteEffect
        }

        static let launch = WidgetReloadPlannerTests.Day.wake
        static let wakes = [13 * 60 + 30, 19 * 60]

        var events: [Event] = [Event(minute: launch, effect: WidgetFeed.WriteEffect(repair: .unusable))]

        init() {
            events += Self.wakes.map { Event(minute: $0, effect: WidgetFeed.WriteEffect(repair: .outdated)) }
        }
    }

    /// Each kind's reloads for the feed's writes of ``FeedDay``, with one planner, as the app has.
    static func feedReloads(_ day: FeedDay = FeedDay()) -> [WidgetKindID: Int] {
        var planner = WidgetReloadPlanner()
        var counts: [WidgetKindID: Int] = [:]
        for event in day.events {
            for reload in planner.written(event.effect, at: WidgetReloadPlannerTests.at(minutes: Double(event.minute)))
            {
                counts[reload.kind, default: 0] += 1
            }
        }
        return counts
    }

    @Test func aFeedDayReloadsEachKindAFewTimes() {
        let counts = Self.feedReloads()
        #expect(counts == [.battery: 3, .accessories: 1, .history: 3, .devices: 3])
    }
}
