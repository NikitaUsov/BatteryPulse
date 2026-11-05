import Foundation
import Synchronization

/// The widget's feed on disk: `feed.json` in `Widget/`, beside `History/` and `Devices/` in
/// BatteryPulse's Application Support folder, the one folder the widget's read-only exception
/// names. The app writes it; the widget only reads it.
///
/// - The folder is 0700, made so or set so at every write, and must be a folder, not a link.
/// - Each write goes to a temporary file in the folder, made 0600 before any byte is written,
///   then takes the feed's place in one rename, so a reader sees the old file or the new one,
///   never a part; the new file keeps its own 0600, not the old file's mode.
/// - A feed that differs from the last one written only in `writtenAt` isn't written, unless the
///   caller says so (the routine write).
///
/// Foundation alone, so it needs no pointer and no `unsafe`. Its calls block on the file system,
/// so the app makes them off the main actor; one runs at a time. A final class rather than an
/// actor, so a binary that never writes (the widget) strips its code.
public final class WidgetFeedStore: Sendable {
    /// The feed's file name.
    public static let fileName = "feed.json"
    /// The folder below the home folder, as the widget's entitlement names it: relative to the
    /// home, with a leading and a trailing slash. The entitlement and this must stay the same
    /// (`WidgetSurfaceTests`).
    public static let homeRelativePath =
        "/Library/Application Support/" + HistoryStore.appBundleIdentifier + "/Widget/"
    /// The folder's and the file's modes: the user's alone.
    static let folderMode = 0o700
    static let fileMode = 0o600
    /// The file a write goes to before it takes the feed's place.
    static let temporaryName = "feed.json.tmp"

    /// `<home>/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget`: the folder
    /// of the entitlement, whatever the bundle identifier of this build (`swift run` has none).
    public static func defaultDirectory(home: URL) -> URL {
        home.appendingPathComponent(String(homeRelativePath.dropFirst().dropLast()), isDirectory: true)
    }

    public let directory: URL
    public var fileURL: URL { directory.appendingPathComponent(Self.fileName) }
    private var temporaryURL: URL { directory.appendingPathComponent(Self.temporaryName) }
    /// The feed on disk as this store last wrote it, to tell a change from a write of the same
    /// content; its lock also keeps one write at a time.
    private let written = Mutex<WidgetFeed?>(nil)

    public init(directory: URL) {
        self.directory = directory
    }

    /// What a write did.
    public enum Outcome: Sendable, Equatable {
        /// The file now holds the feed, in so many bytes.
        case written(bytes: Int)
        /// The feed differs from the file only in `writtenAt`, so nothing was written.
        case unchanged
    }

    /// Why a write failed, besides an error of the file system.
    public enum Failure: Error, Sendable, Equatable {
        /// `Widget` is something other than a folder: a link or a file.
        case notAFolder
        /// The temporary file couldn't be made.
        case temporaryFile
    }

    /// Writes `feed`, unless it differs from the file only in `writtenAt` and `unchanged` is
    /// false.
    public func write(_ feed: WidgetFeed, unchanged: Bool = false) throws -> Outcome {
        try written.withLock { written in
            if !unchanged, let written, written.written(at: feed.writtenAt) == feed { return .unchanged }
            let bytes = try replace(with: WidgetFeed.encoded(feed))
            written = feed
            return .written(bytes: bytes)
        }
    }

    /// Writes `data` to a new 0600 file and puts it in the feed's place; returns its size.
    private func replace(with data: Data) throws -> Int {
        try prepareFolder()
        let manager = FileManager.default
        // A file left by a write that didn't finish: removed, never written through, in case it
        // is a link.
        if exists(temporaryURL) { try manager.removeItem(at: temporaryURL) }
        guard
            manager.createFile(
                atPath: temporaryURL.path, contents: nil, attributes: [.posixPermissions: Self.fileMode])
        else { throw Failure.temporaryFile }
        do {
            let handle = try FileHandle(forWritingTo: temporaryURL)
            do {
                try handle.write(contentsOf: data)
                try handle.close()
            } catch {
                try? handle.close()
                throw error
            }
            if exists(fileURL) {
                // By default the old file's permissions would stay; the new file's 0600 must.
                _ = try manager.replaceItemAt(
                    fileURL, withItemAt: temporaryURL, backupItemName: nil, options: .usingNewMetadataOnly)
            } else {
                try manager.moveItem(at: temporaryURL, to: fileURL)
            }
        } catch {
            try? manager.removeItem(at: temporaryURL)
            throw error
        }
        return data.count
    }

    /// Removes the feed, and a temporary file a write left; the folder stays.
    public func remove() throws {
        try written.withLock { written in
            written = nil
            for url in [fileURL, temporaryURL] where exists(url) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    /// Makes the folder 0700, or sets an existing one so. A missing folder above it gets the
    /// default modes, as the stores beside it make theirs: only `Widget` is made the user's alone,
    /// whichever store writes first.
    private func prepareFolder() throws {
        let manager = FileManager.default
        guard let attributes = try? manager.attributesOfItem(atPath: directory.path) else {
            try manager.createDirectory(at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
            try manager.createDirectory(
                at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: Self.folderMode])
            return
        }
        // Read without following a link: a link in its place is refused, never written through.
        guard attributes[.type] as? FileAttributeType == .typeDirectory else { throw Failure.notAFolder }
        let mode = (attributes[.posixPermissions] as? NSNumber)?.intValue
        if mode.map({ $0 & 0o777 }) != Self.folderMode {
            try manager.setAttributes([.posixPermissions: Self.folderMode], ofItemAtPath: directory.path)
        }
    }

    /// Whether anything, a dangling link included, is at `url`.
    private func exists(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
    }
}
