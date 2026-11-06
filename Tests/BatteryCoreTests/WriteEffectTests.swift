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
    /// reads its type without following it, and never writes through it. Darwin's Foundation
    /// refuses to replace the link, Linux's replaces it; either way, a write that goes out says the
    /// widgets couldn't use what was there.
    @Test func aLinkInTheFeedsPlaceIsOneTheWidgetsCouldntUse() throws {
        let (store, directory) = try Self.store(leaving: nil)
        defer { WidgetFeedStoreTests.remove(directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = directory.deletingLastPathComponent().appendingPathComponent("elsewhere.json")
        let fresh = try WidgetFeed.encoded(Self.feed())
        try fresh.write(to: target)
        try FileManager.default.createSymbolicLink(at: Self.file(directory), withDestinationURL: target)
        if let written = try? store.writeReporting(Self.feed(at: Self.at(minutes: 1))) {
            #expect(written.effect.repair == .unusable)
        }
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

    // MARK: A section added

    /// A section the feed holds and the one it replaced didn't: Record battery history or device
    /// reads turned on, or a kind WidgetKit's answer lists now and didn't before. A section taken
    /// out is a removal's, never an addition.
    @Test func aSectionTheFeedAddsIsAnAddition() {
        let full = Self.feed()
        var noHistory = full
        noHistory.recordsHistory = false
        noHistory.day = nil
        noHistory.week = nil
        noHistory.statistics24h = nil
        noHistory.statistics7d = nil
        noHistory.onBatterySince = nil
        noHistory.daily = nil
        var noDevices = full
        noDevices.devices = nil
        let later = Self.at(minutes: 15)
        #expect(full.written(at: later).effect(replacing: .feed(noHistory)) == .init(added: [.history]))
        #expect(full.written(at: later).effect(replacing: .feed(noDevices)) == .init(added: [.devices]))
        #expect(full.written(at: later).effect(replacing: .feed(full)) == .nothing)
        #expect(noDevices.written(at: later).effect(replacing: .feed(full)) == .nothing)
        // An empty list is a section held: none remembered, not "not written".
        var none = full
        none.devices = []
        #expect(none.written(at: later).effect(replacing: .feed(noDevices)) == .init(added: [.devices]))
        #expect(full.written(at: later).effect(replacing: .feed(none)) == .nothing)
        // Without a feed the widgets could use, everything it holds is new, beside the repair.
        #expect(full.effect(replacing: .missing) == .init(repair: .unusable, added: [.history, .devices]))
    }

    /// What a feed holds: the history whenever it was written with it, gaps and all, so Clear
    /// History keeps it; the devices whenever it was written with them, none remembered included.
    @Test func whatAFeedHolds() {
        let full = Self.feed()
        #expect(full.holds(.history) && full.holds(.devices))
        let removal = WidgetFeed.Removal(
            historyCleared: true, recordsHistory: true, readsDevices: true, remembered: [])
        let cleared = full.removing(removal)
        #expect(cleared.holds(.history) && cleared.holds(.devices) && cleared.devices == [])
        let off = full.removing(
            WidgetFeed.Removal(historyCleared: false, recordsHistory: false, readsDevices: false, remembered: []))
        #expect(!off.holds(.history) && !off.holds(.devices))
        let built = WidgetFeed.build(
            WidgetFeed.Source(
                now: Self.now, languages: ["en"], recordsHistory: true, readsDevices: true, sections: [.devices]))
        #expect(built?.holds(.history) == false && built?.holds(.devices) == true)
    }

    /// Before this launch's first write, a previous launch's feed written while no iPhone & iPad
    /// widget counted as placed: the first write that holds the devices adds them.
    @Test func aFirstWriteAddsWhatThePreviousLaunchLeftOut() throws {
        var old = Self.feed(at: Self.at(minutes: -20))
        old.devices = nil
        let (store, directory) = try Self.store(leaving: WidgetFeed.encoded(old))
        defer { WidgetFeedStoreTests.remove(directory) }
        #expect(try store.writeReporting(Self.feed()).effect == .init(added: [.devices]))
    }

    /// An addition reloads the kinds that show the section, as a removal does, within the same
    /// minimum: the history the large Battery widget and the History widget, the devices the
    /// iPhone & iPad widget.
    @Test func anAdditionReloadsTheKindsThatShowIt() {
        var planner = WidgetReloadPlanner()
        #expect(
            planner.written(.init(added: [.history]), at: Self.at(minutes: 0)) == [
                .init(.battery, .addition), .init(.history, .addition),
            ])
        #expect(planner.written(.init(added: [.devices]), at: Self.at(minutes: 1)) == [.init(.devices, .addition)])
        // Turned off and on again within the minimum: the reload waits, once.
        #expect(planner.removal(of: .devices, at: Self.at(minutes: 2)) == [])
        #expect(planner.written(.init(added: [.devices]), at: Self.at(minutes: 3)) == [])
        #expect(planner.pendingReloads(at: Self.at(minutes: 6)) == [.init(.devices, .removal)])
        #expect(planner.pendingReloads(at: Self.at(minutes: 12)) == [])
        // A repair and an addition together reload each kind once.
        #expect(
            planner.written(.init(repair: .outdated, added: [.history, .devices]), at: Self.at(minutes: 30)).map(
                \.kind) == [.battery, .history, .devices])
        #expect(WidgetReloadPlanner.Reason.addition.rawValue == "addition")
    }

    @Test func effectsAddUp() {
        var effect = WidgetFeed.WriteEffect(added: [.history])
        effect.formUnion(.init(repair: .outdated, added: [.devices]))
        #expect(effect == .init(repair: .outdated, added: [.history, .devices]))
    }

    // MARK: The day's budget

    /// The writes of a day that asks for every reload of the feed there is: the launch over no
    /// feed, recording and device reads turned on, two wakes after more than an hour asleep, an
    /// iPhone & iPad widget placed, Clear History and a device forgotten.
    struct FeedDay {
        enum Change {
            case written(WidgetFeed.WriteEffect)
            case removal(WidgetFeed.Section)
        }

        struct Event {
            var minute: Int
            var change: Change
        }

        static let launch = WidgetReloadPlannerTests.Day.wake

        let events: [Event] = [
            Event(minute: launch, change: .written(.init(repair: .unusable))),
            Event(minute: 9 * 60, change: .written(.init(added: [.history]))),
            Event(minute: 9 * 60 + 5, change: .written(.init(added: [.devices]))),
            Event(minute: 13 * 60 + 30, change: .written(.init(repair: .outdated))),
            Event(minute: 15 * 60, change: .written(.init(added: [.devices]))),
            Event(minute: 19 * 60, change: .written(.init(repair: .outdated))),
            Event(minute: 20 * 60, change: .removal(.history)),
            Event(minute: 21 * 60, change: .removal(.devices)),
        ]
    }

    /// Each kind's reloads for the feed's changes of ``FeedDay``, with one planner, as the app has.
    static func feedReloads(_ day: FeedDay = FeedDay()) -> [WidgetKindID: Int] {
        var planner = WidgetReloadPlanner()
        var counts: [WidgetKindID: Int] = [:]
        for event in day.events {
            let date = WidgetReloadPlannerTests.at(minutes: Double(event.minute))
            let reloads =
                switch event.change {
                case .written(let effect): planner.written(effect, at: date)
                case .removal(let section): planner.removal(of: section, at: date)
                }
            for reload in reloads {
                counts[reload.kind, default: 0] += 1
            }
        }
        return counts
    }

    @Test func aFeedDayReloadsEachKindAFewTimes() {
        let counts = Self.feedReloads()
        #expect(counts == [.battery: 5, .accessories: 1, .history: 5, .devices: 6])
    }
}
