import Foundation
import Testing

@testable import BatteryCore

/// The feed's file: its folder's and its own modes, the replace, and when nothing is written.
/// Each test works in a temporary folder of its own.
@Suite struct WidgetFeedStoreTests {
    static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Widget")
    }

    static func remove(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory.deletingLastPathComponent())
    }

    static func mode(_ url: URL) throws -> Int? {
        (try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue
    }

    static func names(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    static func feed(at date: Date = WidgetFeedTests.now, percent: Int? = 50) -> WidgetFeed {
        WidgetFeed(
            writtenAt: date, languages: ["en"], recordsHistory: true, readsDevices: false,
            day: WidgetFeed.Series(
                start: WidgetFeed.seriesStart(.day, at: date), step: 900, percent: [percent], batteryWatts10: [nil],
                temperature10: [nil], plugged: [false]))
    }

    @Test func theFolderAndTheFileAreTheUsersAlone() throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        let store = WidgetFeedStore(directory: directory)
        let outcome = try store.write(Self.feed())
        #expect(outcome == .written(bytes: try WidgetFeed.encoded(Self.feed()).count))
        #expect(try Self.mode(directory) == 0o700)
        #expect(try Self.mode(directory.appendingPathComponent("feed.json")) == 0o600)
        // Nothing else: no temporary file stays.
        #expect(try Self.names(in: directory) == ["feed.json"])
        let data = try Data(contentsOf: directory.appendingPathComponent("feed.json"))
        #expect(try WidgetFeed.decode(data, now: WidgetFeedTests.now) == Self.feed())
    }

    /// A folder above `Widget` that the store makes (BatteryPulse's own, when the feed is written
    /// before the history) gets the modes any new folder gets, not the feed's.
    @Test func theFoldersAboveKeepTheDefaultModes() throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        let plain = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: plain) }
        _ = try WidgetFeedStore(directory: directory).write(Self.feed())
        #expect(try Self.mode(directory) == 0o700)
        #expect(try Self.mode(directory.deletingLastPathComponent()) == Self.mode(plain))
    }

    /// A folder made with the default modes, and a feed some earlier copy left readable by all:
    /// both become the user's alone at the next write.
    @Test func existingModesAreTightened() throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        let manager = FileManager.default
        try manager.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
        let file = directory.appendingPathComponent("feed.json")
        #expect(
            manager.createFile(atPath: file.path, contents: Data("{}".utf8), attributes: [.posixPermissions: 0o644]))
        _ = try WidgetFeedStore(directory: directory).write(Self.feed())
        #expect(try Self.mode(directory) == 0o700)
        #expect(try Self.mode(file) == 0o600)
        #expect(try Self.names(in: directory) == ["feed.json"])
    }

    /// A reader that opened the old file reads the old file: the new one takes its place in one
    /// rename, never by rewriting it.
    @Test func theReplaceIsAtomic() throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        let store = WidgetFeedStore(directory: directory)
        let old = Self.feed(percent: 10)
        _ = try store.write(old)
        let file = directory.appendingPathComponent("feed.json")
        let reader = try FileHandle(forReadingFrom: file)
        defer { try? reader.close() }
        let new = Self.feed(percent: 90)
        _ = try store.write(new)
        #expect(try reader.readToEnd() == WidgetFeed.encoded(old))
        #expect(try Data(contentsOf: file) == WidgetFeed.encoded(new))
    }

    @Test func aFeedOnlyWrittenAgainIsntRewritten() throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        let store = WidgetFeedStore(directory: directory)
        let file = directory.appendingPathComponent("feed.json")
        _ = try store.write(Self.feed())
        let first = try Data(contentsOf: file)
        let later = WidgetFeedTests.now.addingTimeInterval(60)
        #expect(try store.write(Self.feed(at: later)) == .unchanged)
        #expect(try Data(contentsOf: file) == first)
        // The routine write goes out all the same.
        let routine = try store.write(Self.feed(at: later), unchanged: true)
        #expect(routine == .written(bytes: first.count))
        #expect(try Data(contentsOf: file) == WidgetFeed.encoded(Self.feed(at: later)))
        // A change goes out.
        #expect(try store.write(Self.feed(at: later, percent: 49)) != .unchanged)
    }

    /// The routine write goes out with nothing else changed, recording off included: `writtenAt`
    /// is the widget's only sign that BatteryPulse runs. An immediate reason with nothing changed
    /// writes nothing.
    @Test func theRoutineWriteGoesOutWithNothingChanged() throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        let store = WidgetFeedStore(directory: directory)
        func feed(at date: Date) throws -> WidgetFeed {
            let source = WidgetFeed.Source(
                now: date, languages: ["en"], recordsHistory: false, readsDevices: false, sections: [.history],
                samples: [WidgetFeedTests.sample(1)])
            return try #require(WidgetFeed.build(source))
        }
        let start = WidgetFeedTests.now
        _ = try store.write(feed(at: start))
        var schedule = WidgetFeed.StepSchedule()
        let first = schedule.isDue(at: start)
        let next = start.addingTimeInterval(15 * 60)
        let due = schedule.isDue(at: next)
        #expect(first && due)
        let devices = WidgetFeed.WriteReason.devices
        #expect(try store.write(feed(at: next), unchanged: devices.writesUnchanged) == .unchanged)
        let step = WidgetFeed.WriteReason.step
        #expect(try store.write(feed(at: next), unchanged: step.writesUnchanged) != .unchanged)
        let data = try Data(contentsOf: directory.appendingPathComponent("feed.json"))
        let written = try WidgetFeed.decode(data, now: next)
        #expect(written.writtenAt == next && written.day == nil)
    }

    /// A folder removed meanwhile is made again; a file removed meanwhile is written at the next
    /// change or the next routine write.
    @Test func aRemovedFolderIsMadeAgain() throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        let store = WidgetFeedStore(directory: directory)
        _ = try store.write(Self.feed())
        try FileManager.default.removeItem(at: directory)
        _ = try store.write(Self.feed(), unchanged: true)
        #expect(try Self.mode(directory) == 0o700)
        #expect(try Self.names(in: directory) == ["feed.json"])
    }

    @Test func removalLeavesTheFolder() throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        let store = WidgetFeedStore(directory: directory)
        _ = try store.write(Self.feed())
        try store.remove()
        #expect(try Self.names(in: directory) == [])
        try store.remove()
        // After a removal the same feed is written again.
        #expect(try store.write(Self.feed()) != .unchanged)
    }

    /// A link in the folder's place is refused, never written through; a file a write left
    /// behind is replaced, never written through.
    @Test func linksAreNeverFollowed() throws {
        let root = Self.temporaryDirectory().deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = FileManager.default
        let elsewhere = root.appendingPathComponent("Elsewhere")
        try manager.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        let directory = root.appendingPathComponent("Widget")
        try manager.createSymbolicLink(at: directory, withDestinationURL: elsewhere)
        #expect(throws: WidgetFeedStore.Failure.notAFolder) {
            try WidgetFeedStore(directory: directory).write(Self.feed())
        }
        #expect(try Self.names(in: elsewhere) == [])

        try manager.removeItem(at: directory)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = elsewhere.appendingPathComponent("target")
        #expect(manager.createFile(atPath: target.path, contents: Data("kept".utf8)))
        try manager.createSymbolicLink(
            at: directory.appendingPathComponent("feed.json.tmp"), withDestinationURL: target)
        _ = try WidgetFeedStore(directory: directory).write(Self.feed())
        #expect(try Data(contentsOf: target) == Data("kept".utf8))
        #expect(try Self.names(in: directory) == ["feed.json"])
    }

    /// The folder the widget's entitlement names.
    @Test func theFolderIsTheEntitlementsPath() {
        #expect(
            WidgetFeedStore.homeRelativePath == "/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget/"
        )
        let home = URL(fileURLWithPath: "/Users/someone", isDirectory: true)
        #expect(
            WidgetFeedStore.defaultDirectory(home: home).path
                == "/Users/someone/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget")
        #expect(WidgetFeedStore.fileName == "feed.json")
    }
}
