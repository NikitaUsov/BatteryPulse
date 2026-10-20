import Foundation

/// Remembered iPhones and iPads on disk, with each one's battery history:
///
/// ```
/// Devices/
///   key            32 random bytes (0600): the secret behind every DeviceKey
///   devices.json   the registry (RememberedDeviceFile), written atomically
///   <device key>/  a HistoryStore directory in the Mac's format
/// ```
///
/// Nothing is created until it is used: the folder appears with the first derived key or the
/// first save. The registry never holds a UDID, a serial number or a raw capture.
public actor DeviceStore {
    public let directory: URL
    /// A newer registry version was found; ``save(_:)`` writes nothing, so this version never
    /// overwrites what a newer one wrote. Also set when the registry exists but can't be read.
    public private(set) var isReadOnly = false
    private var stores: [DeviceKey: HistoryStore] = [:]
    /// The clock of each device's ``HistoryStore``, injectable for tests.
    private let now: @Sendable () -> Date

    public enum StoreError: Error, Sendable, Equatable {
        /// `key` exists but isn't a 32-byte secret. It is never replaced: a new secret would
        /// orphan every device's history.
        case invalidSecret
    }

    public init(directory: URL, now: @escaping @Sendable () -> Date = { Date() }) {
        self.directory = directory
        self.now = now
    }

    /// `~/Library/Application Support/<bundle identifier>/Devices`.
    public static func defaultDirectory(bundleIdentifier: String?) -> URL {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(bundleIdentifier ?? "BatteryPulse").appendingPathComponent("Devices")
    }

    var secretURL: URL { directory.appendingPathComponent("key") }
    var registryURL: URL { directory.appendingPathComponent("devices.json") }
    var unreadableRegistryURL: URL { directory.appendingPathComponent("devices.unreadable.json") }

    // MARK: - Secret

    /// Reads `key`, creating it (32 random bytes, 0600) only when it doesn't exist. Any other
    /// problem throws and leaves the file as it is.
    public func secret() throws -> Data {
        let path = secretURL.path
        if !FileManager.default.fileExists(atPath: path) {
            if let created = try createSecret() { return created }
        }
        let data = try Data(contentsOf: secretURL)
        guard data.count == Self.secretLength else { throw StoreError.invalidSecret }
        return data
    }

    static let secretLength = 32

    /// Writes a new secret through a temporary file. The move never replaces an existing file,
    /// so a secret that appeared meanwhile wins; then `nil` tells the caller to read it.
    ///
    /// A folder it creates is 0700, so only this user can list or enter it; an existing folder
    /// keeps its mode (`~/Library` is 0700 anyway).
    private func createSecret() throws -> Data? {
        // The default generator is the system's cryptographically secure one.
        let bytes = Data((0..<Self.secretLength).map { _ in UInt8.random(in: .min ... .max) })
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let temporary = directory.appendingPathComponent(".key-" + UUID().uuidString)
        guard FileManager.default.createFile(atPath: temporary.path, contents: bytes) else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { try? FileManager.default.removeItem(at: temporary) }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
        do {
            try FileManager.default.moveItem(at: temporary, to: secretURL)
        } catch  where FileManager.default.fileExists(atPath: secretURL.path) {
            return nil
        }
        return bytes
    }

    // MARK: - Registry

    /// The remembered devices. A missing file gives none. A newer version gives none and makes
    /// the store read-only. A file that doesn't decode is set aside as `devices.unreadable.json`
    /// (replacing an older one) and gives none; histories re-attach as devices reconnect, since
    /// their keys don't change. A file that can't be read throws and makes the store read-only.
    public func load() throws -> [RememberedDevice] {
        guard FileManager.default.fileExists(atPath: registryURL.path) else { return [] }
        let data: Data
        do {
            data = try Data(contentsOf: registryURL)
        } catch {
            isReadOnly = true
            throw error
        }
        let decoder = Self.decoder()
        if let header = try? decoder.decode(Header.self, from: data),
            header.version > RememberedDeviceFile.currentVersion
        {
            isReadOnly = true
            return []
        }
        do {
            return try decoder.decode(RememberedDeviceFile.self, from: data).devices
        } catch {
            if FileManager.default.fileExists(atPath: unreadableRegistryURL.path) {
                try FileManager.default.removeItem(at: unreadableRegistryURL)
            }
            try FileManager.default.moveItem(at: registryURL, to: unreadableRegistryURL)
            return []
        }
    }

    private struct Header: Decodable {
        var version: Int
    }

    /// Writes the registry atomically; a no-op while ``isReadOnly``.
    public func save(_ devices: [RememberedDevice]) throws {
        guard !isReadOnly else { return }
        let data = try Self.encoder().encode(RememberedDeviceFile(devices: devices))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: registryURL, options: .atomic)
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - History

    /// The device's history, in `<key>/`; one store per key for the life of this actor, so its
    /// caches stay consistent.
    public func history(for key: DeviceKey) -> HistoryStore {
        if let store = stores[key] { return store }
        let store = HistoryStore(directory: directory.appendingPathComponent(key.rawValue), now: now)
        stores[key] = store
        return store
    }

    /// Saves `remaining`, then clears the cached store, evicts it and removes `<key>/`.
    ///
    /// The cached store is cleared first: it keeps the daily summaries in memory and would write
    /// them back on its next flush. The folder goes after the registry is saved, so a crash in
    /// between leaves an orphan folder (``clearHistory()`` removes it), never an entry without
    /// its history.
    public func forget(_ key: DeviceKey, remaining: [RememberedDevice]) async throws {
        try save(remaining)
        // Evicted before the await, so nothing hands out this store again meanwhile.
        if let store = stores.removeValue(forKey: key) { try await store.clear() }
        let folder = directory.appendingPathComponent(key.rawValue)
        if FileManager.default.fileExists(atPath: folder.path) { try FileManager.default.removeItem(at: folder) }
    }

    /// Clears every cached store, then removes every `<key>/` folder (only folders whose names
    /// are valid keys), orphans included. The registry and the secret stay.
    public func clearHistory() async throws {
        for store in stores.values { try await store.clear() }
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey])
        for url in contents where DeviceKey(rawValue: url.lastPathComponent) != nil {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Writes every cached store's pending daily summary.
    public func flush() async {
        for store in stores.values { try? await store.flush() }
    }
}
