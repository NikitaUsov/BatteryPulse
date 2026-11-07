import Foundation
import Testing

@testable import BatteryCore

/// NEW-09 (RD C9, C14 item 2): every storage format a release wrote still decodes, this version
/// writes the same bytes, and a "future 1.x" file (extra fields, unknown cases, a higher version)
/// loses nothing: no record is dropped, nothing this version doesn't know is overwritten, and a
/// newer `devices.json` makes the store read-only. The widget's feed is a copy the app writes whole
/// from the others, so a newer one is read for what this version knows, or not at all, and the
/// next write replaces it: nothing it holds is lost.
///
/// The lines below are the shapes 0.3.0 to 0.7.1 wrote: the samples and daily summaries have kept
/// their keys since 0.3.0, `devices.json` its version 1 since 0.6.0, and the widget's
/// `Widget/feed.json` its version 1 since 0.7.1. Each test works in a temporary folder of its own.
@Suite struct StorageCompatibilityTests {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)
    /// The UTC day of ``start``, the name of its samples file.
    static let startDay = "2027-01-15"
    static let phone = DeviceKey("cfa3073fbe82243a2581b4d4ce99245e") ?? .demo

    static func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("StorageCompatibility-" + UUID().uuidString)
    }

    static func write(_ lines: [String], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(lines.map { $0 + "\n" }.joined().utf8).write(to: url)
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    // MARK: - History samples

    /// A sample line per shape: every key, each state, both events, and the fewest keys.
    static let shippedSamples: [(line: String, sample: HistorySample)] = [
        (
            #"{"b":-7.45,"c":31.4,"e":"launch","f":5862,"l":7.5,"p":70,"r":3901,"s":"discharging","t":1800000000,"x":false}"#,
            HistorySample(
                time: start, event: .launch, percent: 70, state: .discharging, isExternalPowerConnected: false,
                batteryWatts: -7.45, systemLoadWatts: 7.5, temperatureCelsius: 31.4, remainingMAh: 3901,
                fullChargeMAh: 5862)
        ),
        (
            #"{"b":31.25,"e":"wake","p":71.5,"s":"charging","t":1800000060,"x":true}"#,
            HistorySample(
                time: start.addingTimeInterval(60), event: .wake, percent: 71.5, state: .charging,
                isExternalPowerConnected: true, batteryWatts: 31.25)
        ),
        (
            #"{"p":80,"s":"notCharging","t":1800000120,"x":true}"#,
            HistorySample(
                time: start.addingTimeInterval(120), percent: 80, state: .notCharging, isExternalPowerConnected: true)
        ),
        (
            #"{"p":100,"s":"charged","t":1800000180,"x":true}"#,
            HistorySample(
                time: start.addingTimeInterval(180), percent: 100, state: .charged, isExternalPowerConnected: true)
        ),
        (
            #"{"s":"unknown","t":1800000240}"#,
            HistorySample(time: start.addingTimeInterval(240), percent: nil, state: .unknown)
        ),
    ]

    @Test func everyShippedSampleLineDecodesAndIsWrittenTheSame() async throws {
        let folder = Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Self.write(
            Self.shippedSamples.map(\.line), to: folder.appendingPathComponent("samples/\(Self.startDay).jsonl"))
        let samples = try await HistoryStore(directory: folder).samples(from: .distantPast)
        #expect(samples == Self.shippedSamples.map(\.sample))
        for (line, sample) in Self.shippedSamples {
            #expect(String(decoding: try Self.encoder.encode(sample), as: UTF8.self) == line)
        }
    }

    /// A later version's sample lines: new keys of every JSON type, a state and an event this
    /// version doesn't know. Each keeps its sample and every known value; the file is only
    /// appended to, so the newer lines stay as they were.
    @Test func aFutureSampleLineLosesNothing() async throws {
        let folder = Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let lines = [
            #"{"b":-7.45,"limit":{"percent":80,"set":true},"p":70,"s":"discharging","t":1800000000,"tags":["a"],"x":false,"z":null}"#,
            #"{"p":80,"s":"held","t":1800000060,"x":true}"#,
            #"{"e":"restart","p":81,"s":"charging","t":1800000120,"x":true}"#,
        ]
        let url = folder.appendingPathComponent("samples/\(Self.startDay).jsonl")
        try Self.write(lines, to: url)
        let store = HistoryStore(directory: folder, now: { Self.start.addingTimeInterval(600) })
        #expect(
            try await store.samples(from: .distantPast) == [
                HistorySample(
                    time: Self.start, percent: 70, state: .discharging, isExternalPowerConnected: false,
                    batteryWatts: -7.45),
                HistorySample(
                    time: Self.start.addingTimeInterval(60), percent: 80, state: .unknown,
                    isExternalPowerConnected: true),
                HistorySample(
                    time: Self.start.addingTimeInterval(120), percent: 81, state: .charging,
                    isExternalPowerConnected: true),
            ])

        let next = HistorySample(time: Self.start.addingTimeInterval(300), percent: 82, state: .charging)
        #expect(try await store.record(next))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text == lines.map { $0 + "\n" }.joined() + #"{"p":82,"s":"charging","t":1800000300}"# + "\n")
    }

    // MARK: - Daily summaries

    static let shippedDays: [(line: String, day: HistoryDay)] = [
        (
            #"{"capacityToDesignPercent":104.3,"cycleCount":48,"day":"2027-01-14","fullChargeCapacityMAh":5862,"healthPercent":100,"nominalChargeCapacityMAh":6006}"#,
            HistoryDay(
                day: "2027-01-14", healthPercent: 100, capacityToDesignPercent: 104.3, nominalChargeCapacityMAh: 6006,
                fullChargeCapacityMAh: 5862, cycleCount: 48)
        ),
        (#"{"day":"2027-01-15"}"#, HistoryDay(day: "2027-01-15")),
    ]

    @Test func everyShippedDayLineDecodesAndIsWrittenTheSame() async throws {
        let folder = Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try Self.write(Self.shippedDays.map(\.line), to: folder.appendingPathComponent("days.jsonl"))
        #expect(try await HistoryStore(directory: folder).dailySummaries() == Self.shippedDays.map(\.day))
        for (line, day) in Self.shippedDays {
            #expect(String(decoding: try Self.encoder.encode(day), as: UTF8.self) == line)
        }
    }

    /// `days.jsonl` is rewritten whole when a summary changes. A later version's line for a day
    /// this version doesn't record again comes back as it was, its new fields included; the day
    /// it does record is its own reading.
    @Test func aFutureDayLineLosesNothing() async throws {
        let folder = Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let future =
            #"{"chargeLimitPercent":80,"cycleCount":47,"day":"2027-01-13","healthPercent":100,"sessions":[{"start":1}]}"#
        let plain = Self.shippedDays[0].line
        let today = #"{"cycleCount":48,"day":"2027-01-15","healthPercent":99.5,"zone":"Europe/Berlin"}"#
        let url = folder.appendingPathComponent("days.jsonl")
        try Self.write([future, plain, today], to: url)
        let store = HistoryStore(directory: folder)
        #expect(
            try await store.dailySummaries() == [
                HistoryDay(day: "2027-01-13", healthPercent: 100, cycleCount: 47), Self.shippedDays[0].day,
                HistoryDay(day: "2027-01-15", healthPercent: 99.5, cycleCount: 48),
            ])

        try await store.record(HistoryDay(day: "2027-01-15", healthPercent: 99.4, cycleCount: 49), at: Self.start)
        let rewritten = try String(contentsOf: url, encoding: .utf8)
        #expect(
            rewritten
                == [future, plain, #"{"cycleCount":49,"day":"2027-01-15","healthPercent":99.4}"#].map { $0 + "\n" }
                .joined())
        // And again after a fresh start, which reads the kept line anew.
        let again = HistoryStore(directory: folder)
        try await again.record(HistoryDay(day: "2027-01-16", cycleCount: 49), at: Self.start)
        #expect(try String(contentsOf: url, encoding: .utf8).hasPrefix(future + "\n" + plain + "\n"))
    }

    // MARK: - devices.json

    /// The registry as 0.6.0 to 0.7 wrote it: one device with every field.
    static let shippedRegistry =
        #"{"devices":[{"battery":{"adapter":{"activeProfileIndex":0,"adapterDescription":"pd charger","currentMA":3000,"isWireless":false,"manufacturer":"Apple Inc.","name":"USB-C Power Adapter","profiles":[{"index":0,"maxCurrentMA":3000,"voltageMV":5000}],"voltageMV":5000,"watts":15},"amperageMA":2108,"cellVoltagesMV":[4137],"chargePercent":65,"chargeState":"charging","currentCapacityMAh":3151,"cycleCount":278,"designCapacityMAh":5030,"designCycleCount":1000,"errorCondition":"Cell Check Fault","firstUseDate":"2025-10-02T00:00:00Z","fullChargeCapacityMAh":4922,"instantAmperageMA":2087,"isExternalPowerConnected":true,"maximumCapacityPercent":95,"nominalChargeCapacityMAh":4800,"permanentFailureStatus":0,"source":"AppleSmartBattery","temperatureCelsius":36.5,"voltageMV":4137},"deviceClass":"iPhone","firstSeen":"2027-01-15T08:00:00Z","id":"cfa3073fbe82243a2581b4d4ce99245e","lastConnection":"USB","lastRead":"2027-01-15T08:00:00Z","lastSeen":"2027-01-15T08:01:00Z","name":"Phone","osVersion":"27.0.1","productType":"iPhone18,2"}],"version":1}"#

    static let shippedDevice: RememberedDevice = {
        let battery = IDeviceBattery(
            source: "AppleSmartBattery", chargePercent: 65, chargeState: .charging, isExternalPowerConnected: true,
            currentCapacityMAh: 3151, fullChargeCapacityMAh: 4922, nominalChargeCapacityMAh: 4800,
            designCapacityMAh: 5030, maximumCapacityPercent: 95,
            firstUseDate: Date(timeIntervalSinceReferenceDate: 781_056_000), cycleCount: 278, designCycleCount: 1000,
            temperatureCelsius: 36.5, voltageMV: 4137, amperageMA: 2108, instantAmperageMA: 2087,
            cellVoltagesMV: [4137],
            adapter: PowerAdapter(
                watts: 15, voltageMV: 5000, currentMA: 3000, name: "USB-C Power Adapter", manufacturer: "Apple Inc.",
                adapterDescription: "pd charger", isWireless: false,
                profiles: [PowerProfile(index: 0, voltageMV: 5000, maxCurrentMA: 3000)], activeProfileIndex: 0),
            errorCondition: "Cell Check Fault", permanentFailureStatus: 0)
        return RememberedDevice(
            id: phone,
            identity: IDeviceIdentity(
                name: "Phone", deviceClass: "iPhone", productType: "iPhone18,2", osVersion: "27.0.1"),
            battery: battery, at: start
        ).seen(over: .usb, at: start.addingTimeInterval(60))
    }()

    @Test func theShippedRegistryDecodesAndIsWrittenTheSame() async throws {
        let folder = Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("devices.json")
        try Self.write([Self.shippedRegistry], to: url)
        let store = DeviceStore(directory: folder)
        #expect(try await store.load() == [Self.shippedDevice])
        #expect(await !store.isReadOnly)
        try await store.save([Self.shippedDevice])
        #expect(try String(contentsOf: url, encoding: .utf8) == Self.shippedRegistry)
    }

    /// What this version writes it reads back as its own, whatever the numbers and dates: a
    /// registry is never taken for a newer one by mistake, which would stop it remembering devices.
    @Test(arguments: [0.1 + 0.2, 95.4, 95, 1e-7, 36.55, 12_345.678_9])
    func whatThisVersionWritesIsItsOwn(_ number: Double) async throws {
        let folder = Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        var device = Self.shippedDevice
        device.battery?.maximumCapacityPercent = number
        device.battery?.temperatureCelsius = -number
        device.battery?.chargePercent = number / 3
        device.lastSeen = Self.start.addingTimeInterval(number * 1000)
        device.lastConnection = .wifi
        device.battery?.adapter = nil
        device.battery?.cellVoltagesMV = []
        let other = RememberedDevice(
            id: DeviceKey("0123456789abcdef0123456789abcdef") ?? .demo, identity: IDeviceIdentity(),
            battery: IDeviceBattery(), at: Self.start)
        try await DeviceStore(directory: folder).save([device, other])
        let store = DeviceStore(directory: folder)
        #expect(try await store.load().count == 2)
        #expect(await !store.isReadOnly)
    }

    /// A later 1.x adds to version 1, or moves to a higher version. Either way this version shows
    /// none of its devices, stays read-only and leaves the file and the devices' histories as
    /// they were, through a save and a forget.
    @Test(arguments: [
        ("a new top-level field", #""version":1"#, #""version":1,"order":["cfa3073fbe82243a2581b4d4ce99245e"]"#),
        ("a new device field", #""name":"Phone""#, #""name":"Phone","nickname":"Work phone""#),
        ("a new battery field", #""cycleCount":278"#, #""cycleCount":278,"chargeLimitPercent":80"#),
        ("a new adapter field", #""watts":15"#, #""watts":15,"cable":{"lengthM":1}"#),
        ("a state this version doesn't know", #""chargeState":"charging""#, #""chargeState":"held""#),
        ("a connection this version doesn't know", #""lastConnection":"USB""#, #""lastConnection":"Bluetooth""#),
        ("a higher version", #""version":1"#, #""version":2"#),
    ])
    func aFutureRegistryLosesNothing(_ change: String, _ shipped: String, _ future: String) async throws {
        let folder = Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let text = Self.shippedRegistry.replacingOccurrences(of: shipped, with: future)
        #expect(text != Self.shippedRegistry, "\(change)")
        let url = folder.appendingPathComponent("devices.json")
        try Self.write([text], to: url)
        let history = folder.appendingPathComponent(Self.phone.rawValue + "/days.jsonl")
        try Self.write([Self.shippedDays[0].line], to: history)
        let written = try Data(contentsOf: url)

        let store = DeviceStore(directory: folder)
        #expect(try await store.load().isEmpty, "\(change)")
        #expect(await store.isReadOnly, "\(change)")
        try await store.save([Self.shippedDevice])
        #expect(try Data(contentsOf: url) == written, "\(change)")
        #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("devices.unreadable.json").path))
        // Its devices' histories are the newer version's too: they read, and stay when this
        // version forgets the device.
        #expect(try await store.history(for: Self.phone).dailySummaries() == [Self.shippedDays[0].day])
        try await store.forget(Self.phone, remaining: [])
        #expect(try Data(contentsOf: url) == written, "\(change)")
        #expect(try await DeviceStore(directory: folder).history(for: Self.phone).dailySummaries().count == 1)
    }

    // MARK: - The widget's feed

    /// `Widget/feed.json` as 0.7.1 wrote it, version 1, with every section: a step and a day
    /// without a reading, and a week without an average drain. The app writes it whole from
    /// `History/` and `devices.json`; the widget only reads it.
    static let shippedFeed =
        #"{"daily":{"capacityToDesign10":[1043,null],"cycleCount":[48,null],"firstDay":"2027-01-14"},"day":{"batteryWatts10":[-75,null,312],"percent":[70,null,71],"plugged":[false,null,true],"start":1799998200,"step":900,"temperature10":[314,null,315]},"devices":[{"cycleCount":278,"deviceClass":"iPhone","key":"cfa3073fbe82243a2581b4d4ce99245e","maximumCapacity":95,"model":"iPhone 17 Pro Max","name":"Phone","percent":65,"readAt":1800000000,"state":"charging","temperature10":365}],"languages":["ru","en"],"onBatterySince":1799996400,"readsDevices":true,"recordsHistory":true,"statistics24h":{"averageDrainPercentPerHour":8.2,"chargingSessions":1,"timeOnBattery":5400},"statistics7d":{"chargingSessions":3,"timeOnBattery":86400},"version":1,"week":{"batteryWatts10":[-80,150],"percent":[72,71],"plugged":[false,true],"start":1799992800,"step":7200,"temperature10":[312,314]},"writtenAt":1800000000}"#

    static let shippedFeedValue = WidgetFeed(
        writtenAt: start, languages: ["ru", "en"], recordsHistory: true, readsDevices: true,
        day: WidgetFeed.Series(
            start: start.addingTimeInterval(-1_800), step: 900, percent: [70, nil, 71],
            batteryWatts10: [-75, nil, 312], temperature10: [314, nil, 315], plugged: [false, nil, true]),
        week: WidgetFeed.Series(
            start: start.addingTimeInterval(-7_200), step: 7_200, percent: [72, 71], batteryWatts10: [-80, 150],
            temperature10: [312, 314], plugged: [false, true]),
        statistics24h: WidgetFeed.Statistics(
            averageDrainPercentPerHour: 8.2, timeOnBattery: 5_400, chargingSessions: 1),
        statistics7d: WidgetFeed.Statistics(
            averageDrainPercentPerHour: nil, timeOnBattery: 86_400, chargingSessions: 3),
        onBatterySince: start.addingTimeInterval(-3_600),
        daily: WidgetFeed.Daily(firstDay: "2027-01-14", capacityToDesign10: [1_043, nil], cycleCount: [48, nil]),
        devices: [
            WidgetFeed.Device(
                key: phone, name: "Phone", model: "iPhone 17 Pro Max", deviceClass: "iPhone", percent: 65,
                state: .charging, maximumCapacity: 95, cycleCount: 278, temperature10: 365, readAt: start)
        ])

    /// When the widget reads the feed: a minute after the app wrote it.
    static let feedReadAt = start.addingTimeInterval(60)

    /// The feed's folder in `root`, and its file.
    static func feedFolder(in root: URL) -> (folder: URL, file: URL) {
        let folder = root.appendingPathComponent("Widget")
        return (folder, folder.appendingPathComponent(WidgetFeedStore.fileName))
    }

    @Test func theShippedFeedDecodesAndIsWrittenTheSame() throws {
        let root = Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(WidgetFeed.currentVersion == 1)
        let read = try WidgetFeed.decode(Data(Self.shippedFeed.utf8), now: Self.feedReadAt)
        #expect(read == Self.shippedFeedValue)
        #expect(read.systemChargeLimitPercent == nil)
        #expect(String(decoding: try WidgetFeed.encoded(Self.shippedFeedValue), as: UTF8.self) == Self.shippedFeed)

        // Where the app keeps it, beside `History/` and `Devices/`, and who may read it: the folder
        // and the file are the user's alone.
        #expect(
            WidgetFeedStore.homeRelativePath == "/Library/Application Support/io.github.nikitausov.BatteryPulse/Widget/"
        )
        #expect(WidgetFeedStore.fileName == "feed.json")
        let (folder, file) = Self.feedFolder(in: root)
        #expect(
            try WidgetFeedStore(directory: folder).write(Self.shippedFeedValue)
                == .written(bytes: Self.shippedFeed.utf8.count))
        #expect(try String(contentsOf: file, encoding: .utf8) == Self.shippedFeed)
        #expect(try WidgetFeedStoreTests.mode(folder).map { $0 & 0o777 } == 0o700)
        #expect(try WidgetFeedStoreTests.mode(file).map { $0 & 0o777 } == 0o600)
    }

    /// 0.8's addition to version 1 (A-2): the Charge Limit's number, a top-level field that 0.7.1's
    /// file lacks and its widget ignores (``aFutureFeedReadsWhatThisVersionKnows(_:_:_:)``'s first
    /// case is that reader's view). Written only while known, at its sorted place; no version bump.
    static let chargeLimitFeed = shippedFeed.replacingOccurrences(
        of: #""version":1"#, with: #""systemChargeLimitPercent":80,"version":1"#)

    @Test func theChargeLimitsFieldIsAnAddition() throws {
        let root = Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(Self.chargeLimitFeed != Self.shippedFeed)
        var value = Self.shippedFeedValue
        value.systemChargeLimitPercent = 80
        #expect(try WidgetFeed.decode(Data(Self.chargeLimitFeed.utf8), now: Self.feedReadAt) == value)
        #expect(String(decoding: try WidgetFeed.encoded(value), as: UTF8.self) == Self.chargeLimitFeed)
        let (folder, file) = Self.feedFolder(in: root)
        #expect(try WidgetFeedStore(directory: folder).write(value) == .written(bytes: Self.chargeLimitFeed.utf8.count))
        #expect(try String(contentsOf: file, encoding: .utf8) == Self.chargeLimitFeed)
        // Without the number the file is 0.7.1's, byte for byte.
        _ = try WidgetFeedStore(directory: folder).write(Self.shippedFeedValue)
        #expect(try String(contentsOf: file, encoding: .utf8) == Self.shippedFeed)
    }

    /// A later 1.x adds fields to version 1 (C14). The widget reads such a feed with the fields
    /// it doesn't know left out and a state it doesn't know as unknown, everything else as
    /// written. This version's app never reads the feed back: its next write puts its own in the
    /// file's place, which holds nothing that isn't in `History/` and `devices.json`.
    @Test(arguments: [
        ("a new top-level field", #""version":1"#, #""version":1,"chargeLimit":{"percent":80}"#),
        ("a new series field", #""step":900"#, #""step":900,"systemLoad10":[61,null,58]"#),
        ("a new statistic", #""chargingSessions":1"#, #""chargingSessions":1,"longestRun":3600"#),
        ("a new daily field", #""firstDay":"2027-01-14""#, #""firstDay":"2027-01-14","health10":[1000,null]"#),
        ("a new device field", #""name":"Phone""#, #""name":"Phone","nickname":"Work phone""#),
        ("a state this version doesn't know", #""state":"charging""#, #""state":"held""#),
    ])
    func aFutureFeedReadsWhatThisVersionKnows(_ change: String, _ shipped: String, _ future: String) throws {
        let root = Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let text = Self.shippedFeed.replacingOccurrences(of: shipped, with: future)
        #expect(text != Self.shippedFeed, "\(change)")
        var expected = Self.shippedFeedValue
        if future.contains("held") { expected.devices?[0].state = .unknown }
        #expect(WidgetFeedState(data: Data(text.utf8), now: Self.feedReadAt) == .feed(expected), "\(change)")

        let (folder, file) = Self.feedFolder(in: root)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: file)
        _ = try WidgetFeedStore(directory: folder).write(Self.shippedFeedValue)
        #expect(try String(contentsOf: file, encoding: .utf8) == Self.shippedFeed, "\(change)")
    }

    /// A higher version is turned down whole: the widgets show what they show without a feed,
    /// "Open BatteryPulse to update", and this version's app puts its own version 1 in its place.
    @Test func aHigherFeedVersionIsTurnedDownAndReplaced() throws {
        let root = Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let text = Self.shippedFeed.replacingOccurrences(of: #""version":1"#, with: #""version":2"#)
        #expect(text != Self.shippedFeed)
        let state = WidgetFeedState(data: Data(text.utf8), now: Self.feedReadAt)
        #expect(state == .rejected(.unknownVersion))
        let entry = WidgetTimelinePlan.Entry(date: Self.feedReadAt, showsEstimate: false)
        let formatter = BatteryFormatter(locale: Locale(identifier: "en_US"))
        let utc = try #require(TimeZone(identifier: "UTC"))
        #expect(
            HistoryWidgetPlan.make(
                size: .medium, configuration: HistoryWidgetConfiguration(), feed: state.feed, entry: entry,
                formatter: formatter, timeZone: utc) == .empty(.noFeed))
        #expect(
            DevicesWidgetPlan.make(
                size: .medium, configuration: DevicesWidgetConfiguration(), feed: state.feed, entry: entry,
                formatter: formatter, timeZone: utc) == .empty(.noFeed))

        let (folder, file) = Self.feedFolder(in: root)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: file)
        _ = try WidgetFeedStore(directory: folder).write(Self.shippedFeedValue)
        #expect(try String(contentsOf: file, encoding: .utf8) == Self.shippedFeed)
    }

    // MARK: - A device's history

    /// A remembered device's history is a History folder in the Mac's format.
    @Test func aDeviceHistoryReadsTheMacsFormat() async throws {
        let folder = Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let deviceFolder = folder.appendingPathComponent(Self.phone.rawValue)
        try Self.write(
            Self.shippedSamples.map(\.line), to: deviceFolder.appendingPathComponent("samples/\(Self.startDay).jsonl"))
        try Self.write(Self.shippedDays.map(\.line), to: deviceFolder.appendingPathComponent("days.jsonl"))
        let history = await DeviceStore(directory: folder).history(for: Self.phone)
        #expect(try await history.samples(from: .distantPast) == Self.shippedSamples.map(\.sample))
        #expect(try await history.dailySummaries() == Self.shippedDays.map(\.day))
    }

    /// Files a later version adds beside these are never touched: recording, pruning, saving,
    /// flushing, and writing and removing the widget's feed leave them as they are.
    @Test func filesALaterVersionAddsAreKept() async throws {
        let root = Self.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: root) }
        let history = root.appendingPathComponent("History")
        let devices = root.appendingPathComponent("Devices")
        let widget = Self.feedFolder(in: root).folder
        let extras = [
            history.appendingPathComponent("limits.jsonl"), history.appendingPathComponent("samples/index.json"),
            history.appendingPathComponent("samples/2020-01-01.v2.jsonl"), devices.appendingPathComponent("order.json"),
            devices.appendingPathComponent(Self.phone.rawValue + "/notes.json"),
            widget.appendingPathComponent("feed.v2.json"), widget.appendingPathComponent("accessories.json"),
        ]
        for url in extras { try Self.write(["{}"], to: url) }
        // Day files long out of retention, more than the store always keeps: the first record
        // prunes the oldest.
        for day in 1...HistoryStore.keptDayFiles + 1 {
            let name = "samples/2020-01-" + (day < 10 ? "0" : "") + "\(day).jsonl"
            try Self.write([Self.shippedSamples[0].line], to: history.appendingPathComponent(name))
        }
        let later = Self.start.addingTimeInterval(30 * 24 * 60 * 60)

        let store = HistoryStore(directory: history, now: { later })
        #expect(try await store.record(HistorySample(time: later, percent: 50, state: .discharging)))
        try await store.record(HistoryDay(day: "2027-02-14", cycleCount: 50), at: later)
        try await store.flush()
        #expect(
            !FileManager.default.fileExists(atPath: history.appendingPathComponent("samples/2020-01-01.jsonl").path))
        let deviceStore = DeviceStore(directory: devices, now: { later })
        try await deviceStore.save([Self.shippedDevice])
        try await deviceStore.history(for: Self.phone).record(HistorySample(time: later, percent: 60, state: .charging))
        await deviceStore.flush()
        let feedStore = WidgetFeedStore(directory: widget)
        _ = try feedStore.write(Self.shippedFeedValue)
        _ = try feedStore.write(Self.shippedFeedValue.written(at: Self.feedReadAt), unchanged: true)
        try feedStore.remove()
        for url in extras {
            #expect(try String(contentsOf: url, encoding: .utf8) == "{}\n", "\(url.lastPathComponent)")
        }
    }

    // MARK: - Exports

    /// History's CSV and JSON exports read back, by column and key name, into the values the
    /// store keeps, to the digits each column is written with. The names are only ever added to.
    @Test func exportsReadBackToWhatTheStoreKeeps() throws {
        let samples = Self.shippedSamples.map(\.sample)
        let days = Self.shippedDays.map(\.day)
        let utc = try #require(TimeZone(identifier: "UTC"))
        let info = HistoryExportInfo(exportedAt: Self.start, generator: "bpulse", source: nil)
        #expect(
            Array(HistoryExport.sampleColumns.prefix(11)) == [
                "time", "localTime", "event", "chargePercent", "chargeState", "isExternalPowerConnected",
                "batteryWatts", "systemLoadWatts", "temperatureCelsius", "remainingMAh", "fullChargeMAh",
            ])
        #expect(
            Array(HistoryExport.dayColumns.prefix(6)) == [
                "day", "healthPercent", "capacityToDesignPercent", "nominalChargeCapacityMAh", "fullChargeCapacityMAh",
                "cycleCount",
            ])

        for dialect in [CSVDialect.standard, .decimalComma] {
            let sampleRows = Self.csvRecords(
                HistoryExport.data(
                    .samplesCSV, samples: samples, days: days, dialect: dialect, info: info, timeZone: utc),
                dialect: dialect)
            #expect(sampleRows.map(Self.sample) == samples.map(Self.sampleFields))
            let dayRows = Self.csvRecords(
                HistoryExport.data(.daysCSV, samples: samples, days: days, dialect: dialect, info: info, timeZone: utc),
                dialect: dialect)
            #expect(dayRows.map(Self.day) == days.map(Self.dayFields))
        }

        let data = HistoryExport.data(.json, samples: samples, days: days, info: info, timeZone: utc)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["format"] as? String == HistoryExport.formatName)
        #expect((object["formatVersion"] as? NSNumber)?.intValue == 1)
        let jsonSamples = try #require(object["samples"] as? [[String: Any]])
        let jsonDays = try #require(object["days"] as? [[String: Any]])
        #expect(jsonSamples.map { Self.sample(Self.texts($0)) } == samples.map(Self.sampleFields))
        #expect(jsonDays.map { Self.day(Self.texts($0)) } == days.map(Self.dayFields))
    }

    /// RFC 4180 records by header name, decimals written with a point.
    static func csvRecords(_ data: Data, dialect: CSVDialect) -> [[String: String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var quoted = false
        var characters = Array(String(decoding: data, as: UTF8.self)).makeIterator()
        while let character = characters.next() {
            if quoted {
                if character == "\"" {
                    quoted = false
                } else {
                    field.append(character)
                }
            } else if character == "\"" {
                if !field.isEmpty { field.append("\"") }
                quoted = true
            } else if character == dialect.fieldSeparator {
                record.append(field)
                field = ""
            } else if character == "\r\n" || character == "\n" {
                record.append(field)
                records.append(record)
                record = []
                field = ""
            } else {
                field.append(character)
            }
        }
        guard let header = records.first else { return [] }
        return records.dropFirst().map { values in
            var named: [String: String] = [:]
            for (name, value) in zip(header, values) where !value.isEmpty {
                named[name] = dialect.decimalSeparator == "," ? value.replacingOccurrences(of: ",", with: ".") : value
            }
            return named
        }
    }

    /// A JSON object's values as text, `null`s left out.
    static func texts(_ object: [String: Any]) -> [String: String] {
        object.compactMapValues { value -> String? in
            switch value {
            case is NSNull: nil
            case let text as String: text
            default: "\(value)"
            }
        }
    }

    /// The fields a reader keeps of a sample row, as numbers where they are numbers.
    static func sample(_ row: [String: String]) -> [String: Double] {
        var fields: [String: Double] = [:]
        for name in [
            "chargePercent", "batteryWatts", "systemLoadWatts", "temperatureCelsius", "remainingMAh", "fullChargeMAh",
        ] {
            if let value = row[name].flatMap(Double.init) { fields[name] = value }
        }
        if let connected = row["isExternalPowerConnected"] {
            fields["isExternalPowerConnected"] = ["1", "true"].contains(connected) ? 1 : 0
        }
        fields["state." + (row["chargeState"] ?? "")] = 1
        fields["event." + (row["event"] ?? "")] = 1
        if let time = row["time"].flatMap({ ISO8601DateFormatter().date(from: $0) }) {
            fields["time"] = time.timeIntervalSince1970
        }
        return fields
    }

    static func sampleFields(_ s: HistorySample) -> [String: Double] {
        var fields: [String: Double] = ["time": s.time.timeIntervalSince1970]
        fields["chargePercent"] = s.percent
        fields["batteryWatts"] = s.batteryWatts
        fields["systemLoadWatts"] = s.systemLoadWatts
        fields["temperatureCelsius"] = s.temperatureCelsius
        fields["remainingMAh"] = s.remainingMAh.map(Double.init)
        fields["fullChargeMAh"] = s.fullChargeMAh.map(Double.init)
        fields["isExternalPowerConnected"] = s.isExternalPowerConnected.map { $0 ? 1 : 0 }
        fields["state." + s.state.rawValue] = 1
        fields["event." + (s.event?.rawValue ?? "")] = 1
        return fields
    }

    static func day(_ row: [String: String]) -> [String: String] {
        var fields: [String: String] = [:]
        for name in HistoryExport.dayColumns {
            if let value = row[name] { fields[name] = name == "day" ? value : Double(value).map { "\($0)" } }
        }
        return fields
    }

    static func dayFields(_ day: HistoryDay) -> [String: String] {
        var fields = ["day": day.day]
        fields["healthPercent"] = day.healthPercent.map { "\($0)" }
        fields["capacityToDesignPercent"] = day.capacityToDesignPercent.map { "\($0)" }
        fields["nominalChargeCapacityMAh"] = day.nominalChargeCapacityMAh.map { "\(Double($0))" }
        fields["fullChargeCapacityMAh"] = day.fullChargeCapacityMAh.map { "\(Double($0))" }
        fields["cycleCount"] = day.cycleCount.map { "\(Double($0))" }
        return fields
    }
}
