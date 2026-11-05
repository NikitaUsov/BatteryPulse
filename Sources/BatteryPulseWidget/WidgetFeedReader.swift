#if os(macOS)
import BatteryCore
import BatterySource
import Darwin
import Foundation
import os

/// The one file of BatteryPulse's the widget reads: the feed the app writes for it
/// (`WidgetFeedStore`), through the widget's one read-only exception, which names its folder and
/// nothing else. The only widget file with a file API (`SecurityGuardTests`).
///
/// It opens that one path, never following a link, checks that it is a regular file of at most
/// `WidgetFeed.maximumBytes`, reads at most one byte more, and hands the bytes to BatteryCore's
/// validating decoder, which treats them as untrusted. The calls are POSIX ones because the
/// sandbox's `NSHomeDirectory()` is the extension's container, while the exception's path is
/// relative to the real home.
enum WidgetFeedReader {
    /// `<home>/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget/feed.json`, in
    /// the real home; `nil` when the user database has no home.
    static let path: String? = realHome().map { $0 + WidgetFeedStore.homeRelativePath + WidgetFeedStore.fileName }

    /// The feed's state now.
    static func read(now: Date = .now) -> WidgetFeedState {
        guard let path else {
            Diagnostics.widget.notice("Reading the widget feed: the user has no home folder")
            return .unreadable(ENOENT)
        }
        return read(path: path, now: now)
    }

    /// The state of the feed at `path`. The widget reads only ``path``; the previews' tests read
    /// files of their own here.
    static func read(path: String, now: Date) -> WidgetFeedState {
        let interval = Diagnostics.begin("widget.feed.read")
        defer { interval.end() }
        // Non-blocking, so a pipe in its place can't hold the read; a regular file reads the same.
        let descriptor = Darwin.open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard descriptor >= 0 else {
            let code = errno
            switch code {
            case ENOENT:
                // BatteryPulse hasn't written one yet.
                return .missing
            case ELOOP:
                return reject(.notARegularFile, bytes: 0)
            default:
                // A sandbox denial is silent on macOS 27 but for this errno (EPERM, 1): the line
                // that shows an exception a macOS update narrowed.
                Diagnostics.widget.notice("Opening the widget feed failed: errno \(code, privacy: .public)")
                return .unreadable(code)
            }
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        var info = stat()
        guard fstat(descriptor, &info) == 0 else {
            let code = errno
            Diagnostics.widget.notice("Checking the widget feed failed: errno \(code, privacy: .public)")
            return .unreadable(code)
        }
        // S_IFMT and S_IFREG: a regular file, not a folder, a pipe or a device.
        guard info.st_mode & 0o170000 == 0o100000 else { return reject(.notARegularFile, bytes: 0) }
        guard info.st_size <= off_t(WidgetFeed.maximumBytes) else {
            return reject(.oversized, bytes: Int(clamping: info.st_size))
        }
        let data: Data
        do {
            data = try handle.read(upToCount: WidgetFeed.maximumBytes + 1) ?? Data()
        } catch {
            let code = (error as NSError).code
            Diagnostics.widget.notice("Reading the widget feed failed: code \(code, privacy: .public)")
            return .unreadable(Int32(clamping: code))
        }
        let state = WidgetFeedState(data: data, now: now)
        switch state {
        case .rejected(let rejection):
            return reject(rejection, bytes: data.count)
        case .feed:
            Diagnostics.widget.debug("Read the widget feed: \(data.count, privacy: .public) bytes")
        case .missing, .unreadable:
            break
        }
        return state
    }

    /// A rejection logs its case name and the file's size, so `log show` finds it.
    private static func reject(_ rejection: WidgetFeed.Rejection, bytes: Int) -> WidgetFeedState {
        Diagnostics.widget.notice(
            "The widget feed was rejected: \(rejection.rawValue, privacy: .public), \(bytes, privacy: .public) bytes")
        return .rejected(rejection)
    }

    /// The user's real home, from the user database: inside the sandbox, `NSHomeDirectory()` is
    /// the extension's container. Read once.
    private static func realHome() -> String? {
        guard let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir else { return nil }
        let home = String(cString: directory)
        return home.isEmpty ? nil : home
    }
}
#endif
