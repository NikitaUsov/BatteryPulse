import Foundation
import Testing

@testable import BatteryCore

/// The widget's feed: what the builder writes, how large it can get, and what the reader turns
/// down. Device names, keys and models are made up.
@Suite struct WidgetFeedTests {
    /// 2026-11-05 10:07:30 UTC.
    static let now = Date(timeIntervalSince1970: 1_793_873_250)
    static let utc = TimeZone(identifier: "UTC") ?? .current
    static let phone = DeviceKey("0123456789abcdef0123456789abcdef") ?? .demo

    /// A minute sample `minutesAgo` before ``now``.
    static func sample(
        _ minutesAgo: Double, percent: Double? = 50, plugged: Bool = false, watts: Double? = -8.5,
        temperature: Double? = 30.4, event: HistoryEvent? = nil
    ) -> HistorySample {
        HistorySample(
            time: now.addingTimeInterval(-minutesAgo * 60), event: event, percent: percent,
            state: plugged ? .charging : .discharging, isExternalPowerConnected: plugged, batteryWatts: watts,
            temperatureCelsius: temperature)
    }

    static func device(
        _ key: DeviceKey, name: String? = "Phone", productType: String? = "iPhone18,2", read: Date = now,
        percent: Double = 80
    ) -> RememberedDevice {
        var battery = IDeviceBattery(chargeState: .charging)
        battery.chargePercent = percent
        battery.maximumCapacityPercent = 96.4
        battery.cycleCount = 212
        battery.temperatureCelsius = 27.36
        return RememberedDevice(
            id: key, identity: IDeviceIdentity(name: name, deviceClass: "iPhone", productType: productType),
            battery: battery, at: read)
    }

    /// A made-up key: `n` in 32 hex digits.
    static func key(_ n: Int) -> DeviceKey {
        let hex = String(n, radix: 16)
        return DeviceKey(String(repeating: "0", count: 32 - hex.count) + hex) ?? .demo
    }

    static func source(
        samples: [HistorySample] = [], days: [HistoryDay] = [], devices: [RememberedDevice] = [],
        recordsHistory: Bool = true, readsDevices: Bool = true,
        sections: Set<WidgetFeed.Section> = [.history, .devices],
        current: HistorySample? = nil, isOverridden: Bool = false
    ) -> WidgetFeed.Source {
        WidgetFeed.Source(
            now: now, isOverridden: isOverridden, languages: ["ru", "en"], recordsHistory: recordsHistory,
            readsDevices: readsDevices, sections: sections, samples: samples, days: days, current: current,
            devices: devices, modelNames: ["iPhone18,2": "iPhone 17 Pro Max"], timeZone: utc)
    }

    static func build(_ source: WidgetFeed.Source) throws -> WidgetFeed {
        try #require(WidgetFeed.build(source))
    }

    // MARK: Size

    /// A name of `count` four-byte scalars: 64 of them are 256 bytes of UTF-8.
    static func longName(_ count: Int = 100) -> String {
        String(repeating: "\u{1F50B}", count: count)
    }

    /// Everything as large as the builder writes it: 8 devices with names of 64 four-byte scalars,
    /// 90 days, every step of both series with the longest values (`false` is longer than
    /// `true`), every statistic at the longest its bound allows.
    static func largestFeed() throws -> WidgetFeed {
        var samples: [HistorySample] = []
        // One sample a minute for 7 days and 2 hours, so every step of both series has one.
        for minute in stride(from: 0.0, through: 7 * 24 * 60 + 120, by: 1) {
            samples.append(sample(minute, percent: 100, plugged: false, watts: -999.9, temperature: -99.9))
        }
        samples.reverse()
        let calendar = HistoryDay.gregorian(in: utc)
        let days = (0..<120).map { offset in
            HistoryDay(
                day: HistoryDay.key(for: now.addingTimeInterval(-Double(offset) * 86_400), calendar: calendar),
                capacityToDesignPercent: 999.9, cycleCount: 99_999)
        }
        let devices = (0..<12).map { index in
            device(key(index + 1), name: longName(), productType: "Model\(index)", read: now, percent: 100)
        }
        var modelNames: [String: String] = [:]
        for index in 0..<12 { modelNames["Model\(index)"] = longName() }
        var source = source(samples: samples, days: days, devices: devices)
        source.modelNames = modelNames
        source.languages = [String](repeating: String(repeating: "a", count: 35), count: 20)
        var feed = try build(source)
        // The longest numbers each field may hold, the longest state and the longest class.
        feed.statistics24h = WidgetFeed.Statistics(
            averageDrainPercentPerHour: 999.9, timeOnBattery: WidgetFeed.Bounds.timeOnBattery.upperBound,
            chargingSessions: WidgetFeed.Bounds.sessions.upperBound)
        feed.onBatterySince = now.addingTimeInterval(-3_600)
        let longestState = ChargeState.allCases.max { $0.rawValue.utf8.count < $1.rawValue.utf8.count }
        feed.devices = feed.devices?.map { device in
            var device = device
            device.state = longestState ?? .notCharging
            device.deviceClass = WidgetFeed.sanitizedName(longName(), maximumScalars: WidgetFeed.maximumClassScalars)
            device.maximumCapacity = 999
            device.cycleCount = 99_999
            device.temperature10 = -999
            return device
        }
        return feed
    }

    @Test func theLargestFeedFitsItsLimit() throws {
        let feed = try Self.largestFeed()
        #expect(feed.devices?.count == WidgetFeed.maximumDevices)
        #expect(feed.devices?.allSatisfy { $0.name?.unicodeScalars.count == WidgetFeed.maximumNameScalars } == true)
        #expect(feed.daily?.cycleCount.count == WidgetFeed.maximumDays)
        #expect(feed.day?.percent.allSatisfy { $0 == 100 } == true)
        #expect(feed.week?.batteryWatts10.allSatisfy { $0 == -9_999 } == true)
        #expect(feed.day?.plugged.allSatisfy { $0 == false } == true)
        #expect(feed.week?.plugged.allSatisfy { $0 == false } == true)
        let bytes = try WidgetFeed.encoded(feed).count
        // Over 8 KB, as the plan's model expected: the limit is 12 KB, well under the reader's 32.
        #expect(bytes > 8 * 1024)
        #expect(bytes <= WidgetFeed.largestBytes, "\(bytes) bytes")
        #expect(WidgetFeed.largestBytes < WidgetFeed.maximumBytes)
    }

    /// Names count Unicode scalars, not characters: 64 characters of joined emoji would be over a
    /// kilobyte.
    @Test func namesAreCutInScalars() {
        let family = String(repeating: "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}", count: 64)
        #expect(family.count == 64)
        let cut = WidgetFeed.sanitizedName(family)
        #expect(cut?.unicodeScalars.count == 64)
        #expect((cut?.utf8.count ?? 0) <= 256)
    }

    // MARK: Builder

    @Test func demoModeWritesNothing() {
        #expect(WidgetFeed.build(Self.source(samples: [Self.sample(1)], isOverridden: true)) == nil)
    }

    @Test func demoModesDeviceIsNeverWritten() throws {
        let feed = try Self.build(Self.source(devices: [Self.device(.demo), Self.device(Self.phone)]))
        #expect(feed.devices?.map(\.key) == [Self.phone])
    }

    @Test func aDeviceAsTheAppShowsIt() throws {
        let feed = try Self.build(Self.source(devices: [Self.device(Self.phone, name: " Anna\u{202E}'s phone\n")]))
        let device = try #require(feed.devices?.first)
        #expect(device.name == "Anna's phone")
        #expect(device.model == "iPhone 17 Pro Max")
        #expect(device.deviceClass == "iPhone")
        #expect(device.percent == 80)
        #expect(device.state == .charging)
        #expect(device.maximumCapacity == 96)
        #expect(device.cycleCount == 212)
        #expect(device.temperature10 == 274)
        #expect(device.readAt == Self.now)
    }

    /// X-1: a device read while the clock ran ahead, set right since, keeps a read time ahead of
    /// now until it is read again. The builder writes it as now, in the read order it had, so the
    /// reader, which turns down a whole feed with a date over 10 minutes ahead, keeps the feed.
    @Test func aReadTimeAheadOfNowIsWrittenAsNow() throws {
        let ahead = Self.device(Self.key(1), read: Self.now.addingTimeInterval(3 * 3_600))
        let earlier = Self.device(Self.key(2), read: Self.now.addingTimeInterval(-60))
        let feed = try Self.build(Self.source(devices: [earlier, ahead]))
        #expect(feed.devices?.map(\.key) == [Self.key(1), Self.key(2)])
        #expect(feed.devices?.map(\.readAt) == [Self.now, Self.now.addingTimeInterval(-60)])
        #expect(try WidgetFeed.decode(Self.data(feed), now: Self.now) == feed)
    }

    /// The most recently read 8, newest first.
    @Test func devicesAreTheEightReadLast() throws {
        let devices = (0..<10).map { index in
            Self.device(Self.key(index + 1), read: Self.now.addingTimeInterval(-Double(index) * 60))
        }
        let feed = try Self.build(Self.source(devices: devices.shuffled()))
        #expect(feed.devices?.map(\.key) == devices.prefix(8).map(\.id))
    }

    /// W-5's review: a device read every 5 minutes that read the same again changes nothing the
    /// feed shows, so the devices' observation writes nothing for it; a change the widget shows
    /// does.
    @Test func onlyAChangeTheFeedShowsRewritesTheDevices() {
        func content(_ devices: [RememberedDevice], reads: Bool = true) -> WidgetFeed.DevicesContent {
            WidgetFeed.DevicesContent(
                readsDevices: reads, remembered: devices, modelNames: ["iPhone18,2": "iPhone 17 Pro Max"])
        }
        let phone = Self.device(Self.phone, read: Self.now)
        let pad = Self.device(Self.key(2), name: "Pad", read: Self.now.addingTimeInterval(-600))
        let before = content([phone, pad])
        // Read again five minutes later, the same.
        #expect(content([Self.device(Self.phone, read: Self.now.addingTimeInterval(300)), pad]) == before)
        #expect(content([pad, phone]) == before)
        #expect(content([phone, pad, Self.device(.demo)]) == before)
        // A new charge, another device read last, a name, a device forgotten, reads off.
        #expect(content([Self.device(Self.phone, percent: 79), pad]) != before)
        #expect(
            content([phone, Self.device(Self.key(2), name: "Pad", read: Self.now.addingTimeInterval(60))]) != before)
        #expect(content([Self.device(Self.phone, name: "Anna's"), pad]) != before)
        #expect(content([phone]) != before)
        #expect(content([phone, pad], reads: false) != before)
        #expect(content([phone, pad], reads: false) == content([], reads: false))
    }

    @Test func readsOffWriteNoDevices() throws {
        let feed = try Self.build(Self.source(devices: [Self.device(Self.phone)], readsDevices: false))
        #expect(feed.devices == nil)
        #expect(feed.readsDevices == false)
        // On, with none remembered: an empty list, which a widget tells from "off".
        #expect(try Self.build(Self.source()).devices == [])
    }

    @Test func recordingOffWritesNoHistory() throws {
        let feed = try Self.build(
            Self.source(
                samples: [Self.sample(5), Self.sample(1)], days: [HistoryDay(day: "2026-11-05", cycleCount: 10)],
                recordsHistory: false))
        #expect(feed.recordsHistory == false)
        #expect(feed.day == nil && feed.week == nil && feed.statistics24h == nil)
        #expect(feed.onBatterySince == nil && feed.daily == nil)
        // The rest is written all the same: the routine write keeps saying BatteryPulse runs.
        #expect(feed.writtenAt == Self.now)
        #expect(feed.languages == ["ru", "en"])
    }

    @Test func aSectionNotPlacedIsLeftOut() throws {
        let feed = try Self.build(
            Self.source(samples: [Self.sample(1)], devices: [Self.device(Self.phone)], sections: []))
        #expect(feed.day == nil && feed.devices == nil)
        #expect(feed.recordsHistory && feed.readsDevices)
    }

    // MARK: Sections

    @Test func sectionsFollowThePlacedKinds() {
        func sections(_ placements: WidgetPlacements, history: Bool = true, devices: Bool = true)
            -> Set<WidgetFeed.Section>
        {
            WidgetFeed.sections(recordsHistory: history, readsDevices: devices, placements: placements)
        }
        var placements = WidgetPlacements()
        // No answer yet, an empty one and a failed one: every section the settings allow.
        #expect(sections(placements) == [.history, .devices])
        placements.record(answer: [], at: Self.now)
        #expect(sections(placements) == [.history, .devices])
        placements.recordFailure(at: Self.now)
        #expect(sections(placements) == [.history, .devices])
        #expect(sections(placements, history: false) == [.devices])
        #expect(sections(placements, devices: false) == [.history])
        // An answer that lists widgets: only what they show.
        placements.record(answer: [WidgetKindID.battery.rawValue], at: Self.now)
        #expect(sections(placements) == [.history])
        placements.record(answer: [WidgetKindID.devices.rawValue, "io.example.other"], at: Self.now)
        #expect(sections(placements) == [.devices])
        #expect(sections(placements, devices: false) == [])
    }

    /// The large Battery widget and the History widget show the history, the iPhone & iPad widget
    /// the devices; the Accessories widget neither. Before WidgetKit answers, both are written.
    @Test func eachSectionHasItsReaders() {
        #expect(WidgetFeed.Section.history.readers == [.battery, .history])
        #expect(WidgetFeed.Section.devices.readers == [.devices])
        #expect(
            WidgetFeed.sections(recordsHistory: true, readsDevices: true, placements: WidgetPlacements()) == [
                .history, .devices,
            ])
        // A History widget alone keeps the history, and so does a Battery widget alone.
        var placements = WidgetPlacements()
        for kind in [WidgetKindID.history, .battery] {
            placements.record(answer: [kind.rawValue], at: Self.now)
            #expect(WidgetFeed.sections(recordsHistory: true, readsDevices: true, placements: placements) == [.history])
        }
        // An iPhone & iPad widget alone keeps the devices, and nothing of the history.
        placements.record(answer: [WidgetKindID.devices.rawValue], at: Self.now)
        #expect(WidgetFeed.sections(recordsHistory: true, readsDevices: true, placements: placements) == [.devices])
        placements.record(answer: [WidgetKindID.accessories.rawValue], at: Self.now)
        #expect(WidgetFeed.sections(recordsHistory: true, readsDevices: true, placements: placements).isEmpty)
    }

    /// §11 of 0.7.1's plan: a device is in the feed by its key, its names and its last reading
    /// alone. Nothing else the app remembers of it reaches the widget: not its product identifier,
    /// its system's version, when it was first or last seen or how it connected, and never a UDID,
    /// an ECID or a serial number, which the app doesn't remember either.
    @Test func aDeviceHoldsOnlyItsNamesAndItsLastReading() throws {
        var device = Self.device(Self.phone, name: "Anna's iPhone")
        device.osVersion = "27.0.1"
        device.lastConnection = .usb
        device.lastSeen = Self.now.addingTimeInterval(-60)
        let feed = try Self.build(Self.source(devices: [device]))
        let data = try WidgetFeed.encoded(feed)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let devices = try #require(object["devices"] as? [[String: Any]])
        #expect(
            Set(devices.flatMap(\.keys)) == [
                "key", "name", "model", "deviceClass", "percent", "state", "maximumCapacity", "cycleCount",
                "temperature10", "readAt",
            ])
        let text = String(decoding: data, as: UTF8.self)
        for absent in ["iPhone18,2", "27.0.1", "usb", "udid", "ecid", "serial"] {
            #expect(!text.lowercased().contains(absent.lowercased()), "\(absent)")
        }
    }

    @Test func placementsAreAskedOnlyWhenTheyCouldChangeASection() {
        func needs(_ placements: WidgetPlacements, after minutes: Double, history: Bool = true, devices: Bool = true)
            -> Bool
        {
            WidgetFeed.needsPlacementAnswer(
                recordsHistory: history, readsDevices: devices, placements: placements,
                at: Self.now.addingTimeInterval(minutes * 60))
        }
        var placements = WidgetPlacements()
        #expect(needs(placements, after: 0))
        // Both sections' kinds listed: never again.
        placements.record(answer: [WidgetKindID.battery.rawValue, WidgetKindID.devices.rawValue], at: Self.now)
        #expect(!needs(placements, after: 60))
        // A section none of whose kinds is listed: again once the answer is 15 minutes old.
        placements.record(answer: [WidgetKindID.battery.rawValue], at: Self.now)
        #expect(!needs(placements, after: 10))
        #expect(needs(placements, after: 15))
        #expect(!needs(placements, after: 15, devices: false))
        // Nothing the settings allow: no question.
        #expect(!needs(WidgetPlacements(), after: 0, history: false, devices: false))
        // A section no kind shows can't change: no question for it.
        #expect(
            !WidgetFeed.needsPlacementAnswer(
                recordsHistory: false, readsDevices: true, placements: WidgetPlacements(), at: Self.now,
                readers: { $0 == .devices ? [] : $0.readers }))
        #expect(
            WidgetFeed.needsPlacementAnswer(
                recordsHistory: false, readsDevices: true, placements: WidgetPlacements(), at: Self.now))
    }

    // MARK: Series

    @Test func theSeriesEndAtTheStepThatHoldsNow() throws {
        let feed = try Self.build(Self.source(samples: [Self.sample(1)]))
        let day = try #require(feed.day)
        let week = try #require(feed.week)
        #expect(day.step == 900 && day.count == 96)
        #expect(week.step == 7_200 && week.count == 84)
        // 10:07:30 is in the step from 10:00; the day starts 95 steps before it.
        #expect(day.date(ofStep: 95) == Date(timeIntervalSince1970: 1_793_872_800))
        #expect(day.start == Date(timeIntervalSince1970: 1_793_872_800 - 95 * 900))
        // 10:00 starts a 2-hour step too.
        #expect(week.date(ofStep: 83) == Date(timeIntervalSince1970: 1_793_872_800))
        #expect(Int(week.start.timeIntervalSince1970) % 7_200 == 0)
        #expect(WidgetFeed.historyStart(at: Self.now) == week.start)
        #expect(day.percent.last == 50)
        #expect(day.percent.dropLast().allSatisfy { $0 == nil })
    }

    @Test func stepsAreMeansWithGapsAsNulls() throws {
        let samples = [
            Self.sample(7, percent: 60, plugged: true, watts: 10, temperature: 30),
            Self.sample(6, percent: 59, plugged: true, watts: 11, temperature: 31),
            Self.sample(5, percent: 57, plugged: false, watts: nil, temperature: nil),
            // A gap of two steps.
            Self.sample(45, percent: 70, plugged: false, watts: -8.04, temperature: 29.95),
        ].sorted { $0.time < $1.time }
        let day = try #require(try Self.build(Self.source(samples: samples)).day)
        #expect(day.percent.suffix(4) == [70, nil, nil, 59])
        #expect(day.batteryWatts10.suffix(4) == [-80, nil, nil, 105])
        #expect(day.temperature10.suffix(4) == [300, nil, nil, 305])
        // Two of three samples plugged in.
        #expect(day.plugged.suffix(4) == [false, nil, nil, true])
    }

    @Test func stepsSplitAtUTCMidnight() throws {
        // 00:05 UTC on 2026-11-06.
        let midnight = Date(timeIntervalSince1970: 1_793_923_200)
        let now = midnight.addingTimeInterval(5 * 60)
        let samples = [
            HistorySample(time: midnight.addingTimeInterval(-30), percent: 40, state: .discharging),
            HistorySample(time: midnight.addingTimeInterval(30), percent: 39, state: .discharging),
        ]
        var source = Self.source(samples: samples)
        source.now = now
        let feed = try Self.build(source)
        let day = try #require(feed.day)
        #expect(day.date(ofStep: 95) == midnight)
        #expect(day.percent.suffix(2) == [40, 39])
        // In the week, both fall in the 2-hour steps either side of midnight too.
        #expect(feed.week?.date(ofStep: 83) == midnight)
        #expect(feed.week?.percent.suffix(2) == [40, 39])
    }

    /// A corrupt sample is a gap, never a trap.
    @Test func implausibleNumbersAreGaps() throws {
        let samples = [Self.sample(1, percent: 1e300, watts: .infinity, temperature: -1e12)]
        let day = try #require(try Self.build(Self.source(samples: samples)).day)
        #expect(day.percent.last == .some(nil))
        #expect(day.batteryWatts10.last == .some(nil))
        #expect(day.temperature10.last == .some(nil))
        #expect(day.plugged.last == false)
    }

    @Test func theStatisticsAreTheLastDays() throws {
        let samples = (0...120).reversed().map { Self.sample(Double($0), percent: 60 - Double(120 - $0) / 20) }
        let old = Self.sample(25 * 60, percent: 100, plugged: true)
        let feed = try Self.build(Self.source(samples: [old] + samples))
        let expected = HistoryStatistics(samples: samples)
        let statistics = try #require(feed.statistics24h)
        #expect(statistics.timeOnBattery == Int(expected.timeOnBattery))
        #expect(statistics.chargingSessions == expected.chargingSessions)
        let drain = try #require(expected.averageDrainPercentPerHour)
        #expect(statistics.averageDrainPercentPerHour == (drain * 10).rounded() / 10)
        // No sample in the last day: no figures.
        #expect(try Self.build(Self.source(samples: [old])).statistics24h == nil)
    }

    // MARK: On battery since

    @Test func onBatterySinceIsTheStartOfTheLastRun() throws {
        let run = [
            Self.sample(30, plugged: true), Self.sample(20), Self.sample(10), Self.sample(1),
        ]
        #expect(try Self.build(Self.source(samples: run)).onBatterySince == Self.sample(20).time)
        // Across sleep, but not before a launch.
        let slept = [Self.sample(600, plugged: true), Self.sample(300), Self.sample(20, event: .wake), Self.sample(1)]
        #expect(try Self.build(Self.source(samples: slept)).onBatterySince == Self.sample(300).time)
        let launched = [Self.sample(300), Self.sample(20, event: .launch), Self.sample(1)]
        #expect(try Self.build(Self.source(samples: launched)).onBatterySince == Self.sample(20).time)
    }

    @Test func onBatterySinceFollowsTheReadingNow() throws {
        let unplugged = [Self.sample(20), Self.sample(1)]
        // Plugged in since the last sample: none.
        #expect(
            try Self.build(Self.source(samples: unplugged, current: Self.sample(0, plugged: true))).onBatterySince
                == nil)
        // Unplugged since the last sample: from now.
        let plugged = [Self.sample(20, plugged: true), Self.sample(1, plugged: true)]
        #expect(
            try Self.build(Self.source(samples: plugged, current: Self.sample(0))).onBatterySince
                == Self.now)
        #expect(try Self.build(Self.source(samples: plugged)).onBatterySince == nil)
        #expect(try Self.build(Self.source(samples: [], current: Self.sample(0))).onBatterySince == nil)
    }

    // MARK: Daily

    @Test func dailyIsTheLastNinetyDaysWithGaps() throws {
        let days = [
            HistoryDay(day: "2026-07-01", capacityToDesignPercent: 101, cycleCount: 1),
            HistoryDay(day: "2026-08-08", capacityToDesignPercent: 100.04, cycleCount: 10),
            HistoryDay(day: "2026-08-10", capacityToDesignPercent: 99.96, cycleCount: 12),
            HistoryDay(day: "2026-11-04", capacityToDesignPercent: 98.5),
            // From a clock set ahead.
            HistoryDay(day: "2026-12-01", cycleCount: 99),
        ]
        let daily = try #require(try Self.build(Self.source(days: days)).daily)
        // 90 days end on 2026-11-05: the first is 2026-08-08.
        #expect(daily.firstDay == "2026-08-08")
        #expect(daily.capacityToDesign10.count == 89)
        #expect(daily.capacityToDesign10.prefix(3) == [1_000, nil, 1_000])
        #expect(daily.cycleCount.prefix(3) == [10, nil, 12])
        #expect(daily.capacityToDesign10.last == 985)
        #expect(daily.cycleCount.last == .some(nil))
        #expect(try Self.build(Self.source(days: [])).daily == nil)
    }

    // MARK: The rest

    @Test func languagesAreCodesOnly() {
        #expect(
            WidgetFeed.sanitizedLanguages(["ru", "en-GB", "zh_Hans", "", "e\u{0301}n", "a b"]) == [
                "ru", "en-GB", "zh_Hans",
            ])
    }

    @Test func controlAndBidirectionalCharactersAreStripped() {
        #expect(WidgetFeed.sanitizedName("a\u{202E}b\u{0007}c\u{200F}d\u{2066}e\u{061C}f\u{2028}g") == "abcdefg")
        #expect(WidgetFeed.sanitizedName("\u{202D}\u{0000} ") == nil)
        #expect(WidgetFeed.sanitizedName(nil) == nil)
        #expect(WidgetFeed.sanitizedName("Pad 7 \u{1F50B}") == "Pad 7 \u{1F50B}")
    }

    @Test func theRoutineWriteIsOncePerStep() {
        var schedule = WidgetFeed.StepSchedule()
        let step = Date(timeIntervalSince1970: 1_793_872_800)
        // The ticks of a step, the next step's first, and a clock set back, which is another step.
        let due = [10, 70, 899, 900, 960, -3_600].map { schedule.isDue(at: step.addingTimeInterval($0)) }
        #expect(due == [true, false, false, true, false, true])
        #expect(WidgetFeed.WriteReason.allCases.filter(\.writesUnchanged) == [.step])
        #expect(
            WidgetFeed.WriteReason.allCases.map(\.signpostName.description)
                == WidgetFeed.WriteReason.allCases.map(\.rawValue))
    }

    // MARK: Reader

    static func data(_ feed: WidgetFeed) throws -> Data {
        try WidgetFeed.encoded(feed)
    }

    /// The feed as JSON to edit: a dictionary, with the dates as numbers.
    static func object(_ feed: WidgetFeed) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data(feed)) as? [String: Any])
    }

    static func decode(_ object: [String: Any]) throws(WidgetFeed.Rejection) -> WidgetFeed {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { throw .malformed }
        return try WidgetFeed.decode(data, now: now)
    }

    static func fullFeed() throws -> WidgetFeed {
        // Runs of 140 minutes on battery, 4 points each, between charges.
        let samples = (0...200).reversed().map { index in
            sample(Double(index) * 7, percent: 50 + Double(index % 30) / 5, plugged: index % 30 < 10)
        }
        return try build(
            source(
                samples: samples, days: [HistoryDay(day: "2026-11-01", capacityToDesignPercent: 99, cycleCount: 40)],
                devices: [device(phone)], current: sample(0)))
    }

    @Test func aFullFeedRoundTrips() throws {
        let feed = try Self.fullFeed()
        #expect(feed.statistics24h != nil && feed.onBatterySince != nil && feed.daily != nil)
        #expect(try WidgetFeed.decode(Self.data(feed), now: Self.now) == feed)
        #expect(WidgetFeedState(data: try Self.data(feed), now: Self.now) == .feed(feed))
        // Compact: one line, no slash escaped.
        let text = String(decoding: try Self.data(feed), as: UTF8.self)
        #expect(!text.contains("\n") && !text.contains("\\/"))
    }

    /// The names version 1 writes; a later version only adds to them.
    @Test func theSchemaKeepsItsNames() throws {
        let object = try Self.object(Self.fullFeed())
        #expect(
            object.keys.sorted() == [
                "daily", "day", "devices", "languages", "onBatterySince", "readsDevices", "recordsHistory",
                "statistics24h", "version", "week", "writtenAt",
            ])
        let day = try #require(object["day"] as? [String: Any])
        #expect(day.keys.sorted() == ["batteryWatts10", "percent", "plugged", "start", "step", "temperature10"])
        let statistics = try #require(object["statistics24h"] as? [String: Any])
        #expect(statistics.keys.sorted() == ["averageDrainPercentPerHour", "chargingSessions", "timeOnBattery"])
        let daily = try #require(object["daily"] as? [String: Any])
        #expect(daily.keys.sorted() == ["capacityToDesign10", "cycleCount", "firstDay"])
        let device = try #require((object["devices"] as? [[String: Any]])?.first)
        #expect(
            device.keys.sorted() == [
                "cycleCount", "deviceClass", "key", "maximumCapacity", "model", "name", "percent", "readAt", "state",
                "temperature10",
            ])
        #expect(object["version"] as? Int == 1)
        #expect(PropertyValue(any: object["writtenAt"] as Any) == .int(1_793_873_250))
    }

    @Test func unknownFieldsAreIgnored() throws {
        var object = try Self.object(Self.fullFeed())
        object["chargeLimit"] = 80
        var day = try #require(object["day"] as? [String: Any])
        day["systemLoad10"] = [Int](repeating: 1, count: 96)
        object["day"] = day
        #expect(try Self.decode(object) == Self.fullFeed())
    }

    @Test func aTruncatedFileIsRejected() throws {
        let data = try Self.data(Self.fullFeed())
        for length in [0, 1, data.count / 2, data.count - 1] {
            #expect(throws: WidgetFeed.Rejection.malformed) {
                try WidgetFeed.decode(data.prefix(length), now: Self.now)
            }
        }
        #expect(throws: WidgetFeed.Rejection.malformed) { try WidgetFeed.decode(Data("[1, 2]".utf8), now: Self.now) }
    }

    @Test func anOversizedFileIsRejected() throws {
        var data = try Self.data(Self.fullFeed())
        data.append(Data(repeating: 0x20, count: WidgetFeed.maximumBytes - data.count))
        // Trailing white space is still JSON: at the limit it is read.
        #expect(try WidgetFeed.decode(data, now: Self.now) == Self.fullFeed())
        data.append(0x20)
        #expect(throws: WidgetFeed.Rejection.oversized) { try WidgetFeed.decode(data, now: Self.now) }
    }

    @Test func anotherVersionIsRejected() throws {
        var object = try Self.object(Self.fullFeed())
        object["version"] = 2
        #expect(throws: WidgetFeed.Rejection.unknownVersion) { try Self.decode(object) }
        object["version"] = nil
        #expect(throws: WidgetFeed.Rejection.malformed) { try Self.decode(object) }
    }

    @Test func aFutureDateIsRejected() throws {
        var feed = try Self.fullFeed()
        feed.writtenAt = Self.now.addingTimeInterval(9 * 60)
        #expect(try WidgetFeed.decode(Self.data(feed), now: Self.now) == feed)
        feed.writtenAt = Self.now.addingTimeInterval(11 * 60)
        #expect(throws: WidgetFeed.Rejection.futureDate) { try WidgetFeed.decode(Self.data(feed), now: Self.now) }
        feed = try Self.fullFeed()
        feed.devices?[0].readAt = Self.now.addingTimeInterval(3_600)
        #expect(throws: WidgetFeed.Rejection.futureDate) { try WidgetFeed.decode(Self.data(feed), now: Self.now) }
        feed = try Self.fullFeed()
        feed.onBatterySince = .distantFuture
        #expect(throws: WidgetFeed.Rejection.futureDate) { try WidgetFeed.decode(Self.data(feed), now: Self.now) }
    }

    @Test func seriesOfDifferentLengthsAreRejected() throws {
        var feed = try Self.fullFeed()
        feed.day?.plugged.removeLast()
        #expect(throws: WidgetFeed.Rejection.mismatchedLengths) {
            try WidgetFeed.decode(Self.data(feed), now: Self.now)
        }
        feed = try Self.fullFeed()
        feed.week?.percent.append(1)
        feed.week?.batteryWatts10.append(1)
        feed.week?.temperature10.append(1)
        feed.week?.plugged.append(true)
        #expect(throws: WidgetFeed.Rejection.mismatchedLengths) {
            try WidgetFeed.decode(Self.data(feed), now: Self.now)
        }
        feed = try Self.fullFeed()
        feed.day?.step = 600
        #expect(throws: WidgetFeed.Rejection.mismatchedLengths) {
            try WidgetFeed.decode(Self.data(feed), now: Self.now)
        }
        feed = try Self.fullFeed()
        feed.daily?.cycleCount.append(1)
        #expect(throws: WidgetFeed.Rejection.mismatchedLengths) {
            try WidgetFeed.decode(Self.data(feed), now: Self.now)
        }
    }

    @Test func notANumberIsRejected() throws {
        // JSON has no NaN: a file that writes one doesn't parse.
        let text = String(decoding: try Self.data(Self.fullFeed()), as: UTF8.self)
        let nan = text.replacing(#/"averageDrainPercentPerHour":[0-9.]+/#, with: #""averageDrainPercentPerHour":NaN"#)
        #expect(nan != text)
        #expect(throws: (any Error).self) { try WidgetFeed.decode(Data(nan.utf8), now: Self.now) }
        // A value that isn't finite, however it got in, is turned down.
        var feed = try Self.fullFeed()
        feed.statistics24h?.averageDrainPercentPerHour = .nan
        #expect(throws: WidgetFeed.Rejection.notFinite) { try feed.validate(now: Self.now) }
        feed = try Self.fullFeed()
        feed.writtenAt = Date(timeIntervalSince1970: .infinity)
        #expect(throws: WidgetFeed.Rejection.notFinite) { try feed.validate(now: Self.now) }
    }

    @Test func malformedValuesAreRejected() throws {
        var object = try Self.object(Self.fullFeed())
        var devices = try #require(object["devices"] as? [[String: Any]])
        devices[0]["key"] = "../Devices/key"
        object["devices"] = devices
        #expect(throws: WidgetFeed.Rejection.malformed) { try Self.decode(object) }
        object = try Self.object(Self.fullFeed())
        object["languages"] = "ru"
        #expect(throws: WidgetFeed.Rejection.malformed) { try Self.decode(object) }
        var feed = try Self.fullFeed()
        feed.daily?.firstDay = "2026-02-30"
        #expect(throws: WidgetFeed.Rejection.malformed) { try WidgetFeed.decode(Self.data(feed), now: Self.now) }
    }

    /// What the reader keeps of a file the builder wouldn't have written.
    @Test func theReaderCleansWhatItKeeps() throws {
        var feed = try Self.fullFeed()
        let device = try #require(feed.devices?.first)
        var forged = device
        forged.name = "\u{202E}" + Self.longName() + "\u{0007}"
        forged.percent = 1_000
        forged.temperature10 = 50_000
        feed.devices = [WidgetFeed.Device(key: .demo, name: "Demo")] + [WidgetFeed.Device](repeating: forged, count: 11)
        feed.day?.percent[0] = 101
        feed.week?.batteryWatts10[0] = -1_000_000
        feed.languages = ["ru", "\u{202E}en"]
        let read = try WidgetFeed.decode(Self.data(feed), now: Self.now)
        #expect(read.devices?.count == 8)
        #expect(read.devices?.allSatisfy { $0.key == Self.phone } == true)
        #expect(read.devices?.first?.name == WidgetFeed.sanitizedName(Self.longName()))
        #expect(read.devices?.first?.percent == nil)
        #expect(read.devices?.first?.temperature10 == nil)
        #expect(read.day?.percent.first == .some(nil))
        #expect(read.week?.batteryWatts10.first == .some(nil))
        #expect(read.languages == ["ru"])
    }

    @Test func anUnknownStateReadsAsUnknown() throws {
        var object = try Self.object(Self.fullFeed())
        var devices = try #require(object["devices"] as? [[String: Any]])
        devices[0]["state"] = "levitating"
        object["devices"] = devices
        #expect(try Self.decode(object).devices?.first?.state == .unknown)
    }
}
