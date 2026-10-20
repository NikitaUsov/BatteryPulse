import Foundation
import Testing

@testable import BatteryCore

/// Each test works in a temporary directory of its own. UDIDs are SYNTHETIC.
@Suite struct DeviceStoreTests {
    private static let start = Date(timeIntervalSince1970: 1_800_000_000)
    private static let phone = DeviceKey("cfa3073fbe82243a2581b4d4ce99245e") ?? .demo
    private static let pad = DeviceKey("0123456789abcdef0123456789abcdef") ?? .demo
    private static let udid = "00008150-001A2D3C4E5F601C"

    private static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Devices")
    }

    private static func makeStore(_ directory: URL) -> DeviceStore {
        DeviceStore(directory: directory, now: { .distantFuture })
    }

    private static func remove(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory.deletingLastPathComponent())
    }

    private static func device(_ key: DeviceKey, name: String = "Phone") throws -> RememberedDevice {
        var battery = try RememberedDeviceTests.realIPhone().battery
        battery.adapter?.serialNumber = "SYNTHETIC-ADAPTER-SERIAL"
        return RememberedDevice(
            id: key,
            identity: IDeviceIdentity(
                name: name, deviceClass: "iPhone", productType: "iPhone18,2", osVersion: "27.0.1"),
            battery: battery, at: start
        ).seen(over: .usb, at: start.addingTimeInterval(60))
    }

    private static func files(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
        else { return [] }
        return enumerator.compactMap { $0 as? URL }
    }

    @Test func secretIsCreatedOnceWith0600() async throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        let store = Self.makeStore(directory)
        let secret = try await store.secret()
        #expect(secret.count == 32)
        #expect(try await store.secret() == secret)
        #expect(try await Self.makeStore(directory).secret() == secret, "read back, not replaced")
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent("key").path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect(Self.files(in: directory).map(\.lastPathComponent) == ["key"], "no temporary file left behind")
    }

    /// The folder the secret creates is 0700; the secret is 0600.
    @Test func secretFolderIsCreatedWith0700() async throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        _ = try await Self.makeStore(directory).secret()
        func mode(_ url: URL) throws -> Int? {
            (try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue
        }
        #expect(try mode(directory) == 0o700)
        #expect(try mode(directory.appendingPathComponent("key")) == 0o600)
    }

    @Test func secretReadErrorIsNotReplaced() async throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        let key = directory.appendingPathComponent("key")
        try FileManager.default.createDirectory(at: key, withIntermediateDirectories: true)
        let store = Self.makeStore(directory)
        await #expect(throws: (any Error).self) { try await store.secret() }
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: key.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)

        // A file of the wrong size isn't a secret either, and stays as it is.
        try FileManager.default.removeItem(at: key)
        try Data([1, 2, 3]).write(to: key)
        await #expect(throws: DeviceStore.StoreError.invalidSecret) { try await store.secret() }
        #expect(try Data(contentsOf: key) == Data([1, 2, 3]))
    }

    @Test func nothingIsCreatedUntilUsed() async throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        let store = Self.makeStore(directory)
        #expect(try await store.load().isEmpty)
        _ = await store.history(for: Self.phone)
        await store.flush()
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func registryRoundTripsWithISODates() async throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        let store = Self.makeStore(directory)
        let devices = [try Self.device(Self.phone), try Self.device(Self.pad, name: "Tablet")]
        try await store.save(devices)
        let loaded = try await Self.makeStore(directory).load()
        #expect(loaded == devices)
        let json = try String(contentsOf: directory.appendingPathComponent("devices.json"), encoding: .utf8)
        #expect(json.contains(#""firstSeen":"2027-01-15T08:00:00Z""#))
        #expect(json.contains(#""version":1"#))
        #expect(json.contains(#""lastConnection":"USB""#))

        // Fractions of a second are dropped.
        var fractional = try Self.device(Self.phone)
        fractional.lastSeen = Self.start.addingTimeInterval(0.6)
        try await store.save([fractional])
        let reloaded = try await Self.makeStore(directory).load()
        #expect(abs(try #require(reloaded.first).lastSeen.timeIntervalSince(Self.start)) < 1)
        #expect(
            try #require(reloaded.first).lastSeen.timeIntervalSince1970.rounded()
                == reloaded.first?.lastSeen.timeIntervalSince1970)
    }

    @Test func newerVersionIsLoadedEmptyAndNeverOverwritten() async throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("devices.json")
        let newer = Data(#"{"version":2,"devices":[{"id":"cfa3073fbe82243a2581b4d4ce99245e","shape":"new"}]}"#.utf8)
        try newer.write(to: url)
        let store = Self.makeStore(directory)
        #expect(try await store.load().isEmpty)
        #expect(await store.isReadOnly)
        try await store.save([try Self.device(Self.phone)])
        try await store.forget(Self.phone, remaining: [])
        #expect(try Data(contentsOf: url) == newer)
    }

    @Test func unreadableRegistryIsSetAside() async throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("devices.json")
        let aside = directory.appendingPathComponent("devices.unreadable.json")
        try Data("old leftover".utf8).write(to: aside)
        let garbage = Data(#"{"version":1,"devices":[{"id":"../../escape"}]}"#.utf8)
        try garbage.write(to: url)
        let store = Self.makeStore(directory)
        #expect(try await store.load().isEmpty)
        #expect(await !store.isReadOnly)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(try Data(contentsOf: aside) == garbage, "replaces an older one")
        // Saving works again afterwards.
        try await store.save([try Self.device(Self.phone)])
        #expect(try await Self.makeStore(directory).load().count == 1)
    }

    /// A registry that doesn't decode and can't be set aside stays as it is. Here a dangling link
    /// holds the set-aside name: `fileExists` doesn't see it and the move won't replace it.
    @Test func registryThatCannotBeSetAsideIsNeverOverwritten() async throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("devices.json")
        let garbage = Data("not a registry".utf8)
        try garbage.write(to: url)
        try FileManager.default.createSymbolicLink(
            atPath: directory.appendingPathComponent("devices.unreadable.json").path,
            withDestinationPath: directory.appendingPathComponent("missing").path)
        let store = Self.makeStore(directory)
        await #expect(throws: (any Error).self) { try await store.load() }
        #expect(await store.isReadOnly)
        try await store.save([try Self.device(Self.phone)])
        #expect(try Data(contentsOf: url) == garbage)
    }

    @Test func historyIsSeparatePerDevice() async throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        let store = Self.makeStore(directory)
        let phoneHistory = await store.history(for: Self.phone)
        #expect(await store.history(for: Self.phone) === phoneHistory, "one store per key")
        let battery = try RememberedDeviceTests.realIPhone().battery
        try await phoneHistory.record(HistorySample(device: battery, at: Self.start))
        try await store.history(for: Self.pad).record(
            HistorySample(device: battery, at: Self.start.addingTimeInterval(60)))
        try await store.history(for: Self.pad).record(
            HistorySample(device: battery, at: Self.start.addingTimeInterval(120)))
        #expect(try await phoneHistory.samples(since: .distantPast).count == 1)
        #expect(try await store.history(for: Self.pad).samples(since: .distantPast).count == 2)
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(Self.phone.rawValue).path))
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(Self.pad.rawValue).path))
    }

    @Test func forgetRemovesEntryAndFolder() async throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        let store = Self.makeStore(directory)
        let pad = try Self.device(Self.pad, name: "Tablet")
        try await store.save([try Self.device(Self.phone), pad])
        let battery = try RememberedDeviceTests.realIPhone().battery
        try await store.history(for: Self.phone).record(HistorySample(device: battery, at: Self.start))
        try await store.history(for: Self.pad).record(HistorySample(device: battery, at: Self.start))

        try await store.forget(Self.phone, remaining: [pad])
        #expect(try await Self.makeStore(directory).load() == [pad])
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent(Self.phone.rawValue).path))
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent(Self.pad.rawValue).path))
        #expect(try await store.history(for: Self.phone).samples(since: .distantPast).isEmpty)
    }

    @Test func forgetDoesNotResurrectDays() async throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        let store = Self.makeStore(directory)
        let battery = try RememberedDeviceTests.realIPhone().battery
        let history = await store.history(for: Self.phone)
        // A first day is written at once; a change that isn't significant waits in memory.
        try await history.record(HistoryDay(device: battery, day: "2027-01-14"), at: Self.start)
        var later = battery
        later.fullChargeCapacityMAh = 4900
        try await history.record(HistoryDay(device: later, day: "2027-01-14"), at: Self.start.addingTimeInterval(60))

        try await store.forget(Self.phone, remaining: [])
        // The device comes back with the same key.
        let fresh = await store.history(for: Self.phone)
        try await fresh.record(HistorySample(device: battery, at: Self.start.addingTimeInterval(600)))
        try await fresh.record(HistoryDay(device: battery, day: "2027-01-16"), at: Self.start.addingTimeInterval(600))
        // The old store, if anything still held it, has nothing left to write.
        try await history.flush()
        await store.flush()
        let days = try await Self.makeStore(directory).history(for: Self.phone).dailySummaries().map(\.day)
        #expect(days == ["2027-01-16"])
    }

    @Test func clearHistoryKeepsRegistryAndRemovesOrphans() async throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        let store = Self.makeStore(directory)
        let secret = try await store.secret()
        let devices = [try Self.device(Self.phone)]
        try await store.save(devices)
        let battery = try RememberedDeviceTests.realIPhone().battery
        try await store.history(for: Self.phone).record(HistorySample(device: battery, at: Self.start))
        try await store.history(for: Self.phone).record(HistoryDay(device: battery, day: "2027-01-15"), at: Self.start)
        // An orphan (a device forgotten during a crash) and a folder that isn't a key.
        let orphan = directory.appendingPathComponent(Self.pad.rawValue).appendingPathComponent("samples")
        try FileManager.default.createDirectory(at: orphan, withIntermediateDirectories: true)
        let other = directory.appendingPathComponent("Not A Key")
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)

        try await store.clearHistory()
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent(Self.phone.rawValue).path))
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent(Self.pad.rawValue).path))
        #expect(FileManager.default.fileExists(atPath: other.path))
        #expect(try await Self.makeStore(directory).load() == devices)
        #expect(try await Self.makeStore(directory).secret() == secret)
        await store.flush()
        #expect(try await store.history(for: Self.phone).dailySummaries().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent(Self.phone.rawValue).path))
    }

    @Test func noIdentifierOnDisk() async throws {
        let directory = Self.temporaryDirectory()
        defer { Self.remove(directory) }
        let store = Self.makeStore(directory)
        _ = try await store.secret()
        try await store.save([try Self.device(Self.phone)])
        let battery = try RememberedDeviceTests.realIPhone().battery
        try await store.history(for: Self.phone).record(HistorySample(device: battery, at: Self.start))
        try await store.history(for: Self.phone).record(HistoryDay(device: battery, day: "2027-01-15"), at: Self.start)
        await store.flush()
        let files = Self.files(in: directory).filter { !$0.hasDirectoryPath && $0.lastPathComponent != "key" }
        #expect(files.count >= 3)
        for url in files {
            let text = String(decoding: try Data(contentsOf: url), as: UTF8.self)
            #expect(!text.contains(Self.udid), "\(url.lastPathComponent)")
            #expect(!text.contains("SYNTHETIC-ADAPTER-SERIAL"), "\(url.lastPathComponent)")
        }
    }
}
