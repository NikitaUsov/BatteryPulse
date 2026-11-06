#if os(macOS)
import BatteryCore
import Darwin
import Foundation
import Testing

@testable import BatteryPulseWidget

/// The feed's reader against files of its own, on Darwin, where its POSIX calls compile: the
/// widget reads only its one path, but the checks are the same for any. Outside the sandbox, so
/// the exception itself is the M5's to show.
struct WidgetFeedReaderTests {
    static let now = Date(timeIntervalSince1970: 1_793_873_250)

    static let feed = WidgetFeed(
        writtenAt: now, languages: ["en"], recordsHistory: true, readsDevices: false,
        day: WidgetFeed.Series(
            start: now.addingTimeInterval(-900), step: 900, percent: [80, 79], batteryWatts10: [-85, nil],
            temperature10: [304, 301], plugged: [false, false]))

    /// A folder of the test's own, removed by `body`'s end.
    static func inFolder(_ body: (URL) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try body(folder)
    }

    @Test func theWidgetReadsTheEntitlementsPath() throws {
        let path = try #require(WidgetFeedReader.path)
        #expect(path.hasPrefix("/"))
        #expect(path.hasSuffix("/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget/feed.json"))
        #expect(path.hasSuffix(WidgetFeedStore.homeRelativePath + WidgetFeedStore.fileName))
    }

    @Test func aFeedIsRead() throws {
        try Self.inFolder { folder in
            let file = folder.appendingPathComponent("feed.json")
            try WidgetFeed.encoded(Self.feed).write(to: file)
            #expect(WidgetFeedReader.read(path: file.path, now: Self.now) == .feed(Self.feed))
        }
    }

    @Test func noFileIsNoFeed() throws {
        try Self.inFolder { folder in
            #expect(
                WidgetFeedReader.read(path: folder.appendingPathComponent("feed.json").path, now: Self.now) == .missing)
        }
    }

    /// `O_NOFOLLOW`: a link in the feed's place, even to a valid feed, is never followed.
    @Test func aLinkIsNeverFollowed() throws {
        try Self.inFolder { folder in
            let target = folder.appendingPathComponent("elsewhere.json")
            try WidgetFeed.encoded(Self.feed).write(to: target)
            let link = folder.appendingPathComponent("feed.json")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
            #expect(WidgetFeedReader.read(path: link.path, now: Self.now) == .rejected(.notARegularFile))
        }
    }

    /// A folder or a pipe in its place is no file, and a pipe doesn't hold the read.
    @Test func onlyARegularFileIsRead() throws {
        try Self.inFolder { folder in
            let directory = folder.appendingPathComponent("feed.json")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            #expect(WidgetFeedReader.read(path: directory.path, now: Self.now) == .rejected(.notARegularFile))
            let pipe = folder.appendingPathComponent("pipe")
            #expect(mkfifo(pipe.path, 0o600) == 0)
            #expect(WidgetFeedReader.read(path: pipe.path, now: Self.now) == .rejected(.notARegularFile))
        }
    }

    /// Larger than the limit: turned down by its size, before a byte is read.
    @Test func anOversizedFileIsRejected() throws {
        try Self.inFolder { folder in
            let file = folder.appendingPathComponent("feed.json")
            var data = try WidgetFeed.encoded(Self.feed)
            data.append(Data(repeating: 0x20, count: WidgetFeed.maximumBytes + 1 - data.count))
            try data.write(to: file)
            #expect(WidgetFeedReader.read(path: file.path, now: Self.now) == .rejected(.oversized))
            // At the limit it is read.
            try data.dropLast().write(to: file)
            #expect(WidgetFeedReader.read(path: file.path, now: Self.now) == .feed(Self.feed))
        }
    }

    @Test func aBrokenFeedIsRejected() throws {
        try Self.inFolder { folder in
            let file = folder.appendingPathComponent("feed.json")
            let data = try WidgetFeed.encoded(Self.feed)
            try data.prefix(data.count / 2).write(to: file)
            #expect(WidgetFeedReader.read(path: file.path, now: Self.now) == .rejected(.malformed))
            try WidgetFeed.encoded(Self.feed.written(at: Self.now.addingTimeInterval(3_600))).write(to: file)
            #expect(WidgetFeedReader.read(path: file.path, now: Self.now) == .rejected(.futureDate))
        }
    }

    /// A file it may not open is unreadable, with its errno, as a sandbox denial would be.
    @Test func aFileItMayNotOpenIsUnreadable() throws {
        try Self.inFolder { folder in
            let file = folder.appendingPathComponent("feed.json")
            try WidgetFeed.encoded(Self.feed).write(to: file)
            try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: file.path)
            defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path) }
            // Root reads it anyway; CI's runner isn't root.
            guard getuid() != 0 else { return }
            #expect(WidgetFeedReader.read(path: file.path, now: Self.now) == .unreadable(EACCES))
        }
    }
}
#endif
