import Foundation
import Testing

@testable import BatteryCore

/// Demo Mode and the feed: the demo's readings never reach it, and nothing is written while it
/// runs but what the user removes meanwhile (Clear History, recording off, device reads off,
/// Forget), which leaves the feed at once, taken from the real settings and devices, with nothing
/// added, updated or moved. Device names and keys are made up.
@Suite struct WidgetFeedRemovalTests {
    static let now = WidgetFeedTests.now
    static let other = WidgetFeedTests.key(7)

    /// A full feed with two devices, written `minutesAgo` before ``now``.
    static func feed(minutesAgo: Double = 5) throws -> WidgetFeed {
        let samples = (0...200).reversed().map { index in
            WidgetFeedTests.sample(Double(index) * 7, percent: 50 + Double(index % 30) / 5, plugged: index % 30 < 10)
        }
        var source = WidgetFeedTests.source(
            samples: samples, days: [HistoryDay(day: "2026-11-01", capacityToDesignPercent: 99, cycleCount: 40)],
            devices: [WidgetFeedTests.device(WidgetFeedTests.phone), WidgetFeedTests.device(other, name: "Tablet")],
            current: WidgetFeedTests.sample(0))
        source.now = now.addingTimeInterval(-minutesAgo * 60)
        return try #require(WidgetFeed.build(source))
    }

    static func removal(
        historyCleared: Bool = false, recordsHistory: Bool = true, readsDevices: Bool = true,
        remembered: Set<DeviceKey> = [WidgetFeedTests.phone, other]
    ) -> WidgetFeed.Removal {
        WidgetFeed.Removal(
            historyCleared: historyCleared, recordsHistory: recordsHistory, readsDevices: readsDevices,
            remembered: remembered)
    }

    // MARK: The removal

    @Test func nothingRemovedChangesNothing() throws {
        let feed = try Self.feed()
        #expect(feed.removing(Self.removal()) == feed)
    }

    /// Clear History leaves what a build from the cleared history writes: the steps as gaps, no
    /// figures, start on battery or daily summaries. The steps stay where they were.
    @Test func clearHistoryLeavesGapsOverTheSameSteps() throws {
        let feed = try Self.feed()
        #expect(feed.statistics24h != nil && feed.statistics7d != nil)
        let cleared = feed.removing(Self.removal(historyCleared: true))
        let day = try #require(cleared.day)
        let week = try #require(cleared.week)
        #expect(day.start == feed.day?.start && day.count == feed.day?.count)
        #expect(week.start == feed.week?.start && week.count == feed.week?.count)
        for series in [day, week] {
            #expect(series.percent.allSatisfy { $0 == nil })
            #expect(series.batteryWatts10.allSatisfy { $0 == nil })
            #expect(series.temperature10.allSatisfy { $0 == nil })
            #expect(series.plugged.allSatisfy { $0 == nil })
        }
        #expect(cleared.statistics24h == nil && cleared.statistics7d == nil)
        #expect(cleared.onBatterySince == nil && cleared.daily == nil)
        #expect(cleared.recordsHistory)
        // The devices and everything else stay.
        #expect(cleared.devices == feed.devices && cleared.writtenAt == feed.writtenAt)
        #expect(cleared.languages == feed.languages)
        // What a build from an empty history writes, but for the steps' place in time.
        let empty = try #require(
            WidgetFeed.build(WidgetFeedTests.source(devices: [WidgetFeedTests.device(WidgetFeedTests.phone)])))
        #expect(empty.day?.percent == day.percent && empty.week?.plugged == week.plugged)
        #expect(empty.statistics24h == nil && empty.statistics7d == nil && empty.daily == nil)
        // The reader takes it.
        #expect(try WidgetFeed.decode(WidgetFeed.encoded(cleared), now: Self.now) == cleared)
    }

    @Test func recordingOffDropsTheHistory() throws {
        let feed = try Self.feed()
        let off = feed.removing(Self.removal(recordsHistory: false))
        #expect(!off.recordsHistory)
        #expect(off.day == nil && off.week == nil && off.statistics24h == nil && off.statistics7d == nil)
        #expect(off.onBatterySince == nil && off.daily == nil)
        #expect(off.devices == feed.devices)
        // Clearing it too changes nothing more.
        #expect(feed.removing(Self.removal(historyCleared: true, recordsHistory: false)) == off)
    }

    @Test func readsOffDropTheDevices() throws {
        let feed = try Self.feed()
        let off = feed.removing(Self.removal(readsDevices: false))
        #expect(!off.readsDevices && off.devices == nil)
        #expect(off.day == feed.day && off.daily == feed.daily && off.recordsHistory)
    }

    @Test func aForgottenDeviceGoes() throws {
        let feed = try Self.feed()
        #expect(feed.devices?.count == 2)
        let forgotten = feed.removing(Self.removal(remembered: [Self.other]))
        #expect(forgotten.devices?.map(\.key) == [Self.other])
        #expect(forgotten.devices?.first == feed.devices?.first { $0.key == Self.other })
        #expect(feed.removing(Self.removal(remembered: [])).devices == [])
    }

    /// Nothing comes back or in while the demo runs: a setting turned on stays off in the feed, a
    /// device that wasn't in it stays out, and the time it was written stays.
    @Test func nothingIsAddedOrUpdated() throws {
        var feed = try Self.feed()
        feed.recordsHistory = false
        feed.readsDevices = false
        feed.day = nil
        feed.week = nil
        feed.statistics24h = nil
        feed.statistics7d = nil
        feed.onBatterySince = nil
        feed.daily = nil
        feed.devices = nil
        let after = feed.removing(
            Self.removal(remembered: [WidgetFeedTests.phone, Self.other, WidgetFeedTests.key(9)]))
        #expect(after == feed)
        let some = try Self.feed().removing(Self.removal(remembered: [Self.other]))
        let again = some.removing(Self.removal(remembered: [WidgetFeedTests.phone, Self.other]))
        #expect(again == some)
        #expect(again.writtenAt == Self.now.addingTimeInterval(-5 * 60))
    }

    /// Only the user's own changes rewrite the feed in Demo Mode; the routine write, a plug change,
    /// the demo's end and a launch's language write never run during it.
    @Test func theReasonsAUsersRemovalArrivesWith() {
        let reasons = WidgetFeed.WriteReason.allCases.filter(\.removesInDemoMode)
        #expect(reasons == [.historyCleared, .recording, .devices])
        #expect(WidgetFeed.WriteReason.language.signpostName.description == "language")
        #expect(!WidgetFeed.WriteReason.language.writesUnchanged)
    }

    // MARK: The store

    @Test func theStoreRewritesTheFeedItWrote() throws {
        let directory = WidgetFeedStoreTests.temporaryDirectory()
        defer { WidgetFeedStoreTests.remove(directory) }
        let store = WidgetFeedStore(directory: directory)
        // No feed yet: nothing to rewrite, and nothing is made.
        #expect(try store.rewrite { $0.removing(Self.removal(readsDevices: false)) } == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.path))

        let feed = try Self.feed()
        _ = try store.write(feed)
        #expect(try store.rewrite { $0.removing(Self.removal()) } == .unchanged)
        let off = feed.removing(Self.removal(readsDevices: false))
        let outcome = try store.rewrite { $0.removing(Self.removal(readsDevices: false)) }
        #expect(outcome == .written(bytes: try WidgetFeed.encoded(off).count))
        let data = try Data(contentsOf: store.fileURL)
        #expect(try WidgetFeed.decode(data, now: Self.now) == off)
        #expect(try WidgetFeedStoreTests.mode(store.fileURL) == 0o600)
        #expect(try WidgetFeedStoreTests.names(in: directory) == ["feed.json"])
        // The store remembers it: the same feed written again is no change.
        #expect(try store.write(off) == .unchanged)
    }

    /// Before its first write a store has no feed to take a part out of, so the file a previous
    /// launch left goes whole, which only removes; a link in its place is removed, never followed,
    /// and what it points to stays. The next full write makes the file again.
    @Test func beforeItsFirstWriteAStoreRemovesTheFile() throws {
        let directory = WidgetFeedStoreTests.temporaryDirectory()
        defer { WidgetFeedStoreTests.remove(directory) }
        let feed = try Self.feed()
        _ = try WidgetFeedStore(directory: directory).write(feed)
        let store = WidgetFeedStore(directory: directory)
        #expect(try store.rewrite { $0.removing(Self.removal()) } == .removed)
        #expect(try WidgetFeedStoreTests.names(in: directory) == [])
        #expect(try store.rewrite { $0.removing(Self.removal()) } == nil)
        #expect(try store.write(feed) == .written(bytes: try WidgetFeed.encoded(feed).count))

        let manager = FileManager.default
        let target = directory.deletingLastPathComponent().appendingPathComponent("target.json")
        try WidgetFeed.encoded(feed).write(to: target)
        try manager.removeItem(at: store.fileURL)
        try manager.createSymbolicLink(at: store.fileURL, withDestinationURL: target)
        #expect(try WidgetFeedStore(directory: directory).rewrite { $0 } == .removed)
        #expect(try WidgetFeedStoreTests.names(in: directory) == [])
        #expect(manager.fileExists(atPath: target.path))
    }
}
