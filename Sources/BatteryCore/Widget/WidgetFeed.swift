import Foundation

/// What the app writes for its widget: a small copy of the last readings the sandboxed widget
/// can't read itself, `feed.json` in the one folder its read-only exception names
/// (``WidgetFeedStore``). Written by the app only (``build(_:)``), read by the widget only
/// (``decode(_:now:)``), which treats the file as untrusted input.
///
/// Version 1. Its schema only gains fields: a reader ignores fields it doesn't know, and a new
/// field is optional. A version a reader doesn't know is rejected whole.
///
/// It holds only what a widget can show, and nothing that isn't already in `History/` or
/// `Devices/devices.json` beside it: the last day's and week's charge, battery power, temperature
/// and plugged-in state in steps; the last 24 hours' figures; the start of the run on battery; up
/// to 90 days of capacity and cycle count; up to 8 remembered iPhones and iPads by their
/// `DeviceKey`, never a UDID, ECID or serial; BatteryPulse's language list; and whether recording
/// and device reads are on, so a widget can tell "off" from "none". Never Demo Mode's data and
/// never an accessory.
public struct WidgetFeed: Sendable, Equatable, Codable {
    /// The version this build writes and reads.
    public static let currentVersion = 1
    /// A file larger than this is rejected unread.
    public static let maximumBytes = 32 * 1024
    /// The most the builder writes, for the largest possible input (`WidgetFeedTests`).
    public static let largestBytes = 12 * 1024
    /// A date further ahead than this comes from a clock set ahead, or a forged file.
    public static let futureTolerance: TimeInterval = 10 * 60
    /// The most devices a feed holds, the most recently read first.
    public static let maximumDevices = 8
    /// A name or model is cut to this many Unicode scalars (not characters: 64 characters of joined
    /// emoji can take over a kilobyte).
    public static let maximumNameScalars = 64
    /// A device class ("iPhone", "iPad") is cut shorter.
    public static let maximumClassScalars = 16
    /// The most days of capacity and cycle count.
    public static let maximumDays = 90
    /// The most languages, and the longest language code.
    static let maximumLanguages = 8
    static let maximumLanguageLength = 35

    public var version: Int
    /// When the app built the feed, to the second: the widget's only sign that BatteryPulse runs.
    public var writtenAt: Date
    /// BatteryPulse's own preferred localizations, as `Bundle.main.preferredLocalizations` lists
    /// them ("ru", "en").
    public var languages: [String]
    /// Whether Record battery history is on.
    public var recordsHistory: Bool
    /// Whether Read iPhone and iPad batteries is on.
    public var readsDevices: Bool
    /// The last 24 hours in 96 steps of 15 minutes; `nil` without the history section.
    public var day: Series?
    /// The last 7 days in 84 steps of 2 hours; `nil` without the history section.
    public var week: Series?
    /// The figures of the last 24 hours, as the History page computes them; `nil` without the
    /// history section or without a sample in that time.
    public var statistics24h: Statistics?
    /// When the Mac's current run on battery began; `nil` on the adapter, without the history
    /// section or without samples.
    public var onBatterySince: Date?
    /// Up to 90 days of capacity and cycle count; `nil` without the history section or without a
    /// daily summary.
    public var daily: Daily?
    /// The remembered iPhones and iPads, the most recently read first; `nil` without the devices
    /// section.
    public var devices: [Device]?

    public init(
        version: Int = Self.currentVersion, writtenAt: Date, languages: [String], recordsHistory: Bool,
        readsDevices: Bool, day: Series? = nil, week: Series? = nil, statistics24h: Statistics? = nil,
        onBatterySince: Date? = nil, daily: Daily? = nil, devices: [Device]? = nil
    ) {
        self.version = version
        self.writtenAt = writtenAt
        self.languages = languages
        self.recordsHistory = recordsHistory
        self.readsDevices = readsDevices
        self.day = day
        self.week = week
        self.statistics24h = statistics24h
        self.onBatterySince = onBatterySince
        self.daily = daily
        self.devices = devices
    }

    /// Readings in steps of equal length, oldest first, as parallel arrays of one length; a step
    /// without a sample is `nil` in every array (a gap).
    public struct Series: Sendable, Equatable, Codable {
        /// The start of the first step, in UTC, a multiple of `step` seconds since 1970.
        public var start: Date
        /// The step's length in seconds.
        public var step: Int
        /// The mean charge, in whole percent.
        public var percent: [Int?]
        /// The mean battery power in tenths of a watt: positive while charging, negative while
        /// discharging.
        public var batteryWatts10: [Int?]
        /// The mean temperature in tenths of a degree Celsius.
        public var temperature10: [Int?]
        /// Whether the Mac was on its adapter for at least half the step's samples.
        public var plugged: [Bool?]

        public init(
            start: Date, step: Int, percent: [Int?], batteryWatts10: [Int?], temperature10: [Int?], plugged: [Bool?]
        ) {
            self.start = start
            self.step = step
            self.percent = percent
            self.batteryWatts10 = batteryWatts10
            self.temperature10 = temperature10
            self.plugged = plugged
        }

        /// The number of steps; the arrays' common length once validated.
        public var count: Int { percent.count }

        /// The start of step `index`.
        public func date(ofStep index: Int) -> Date {
            start.addingTimeInterval(TimeInterval(index * step))
        }
    }

    /// One of the two series: its step and how many steps it holds.
    public enum Period: Sendable, CaseIterable {
        case day, week

        /// In seconds; each divides a day, so the steps start at UTC midnight.
        public var step: Int { self == .day ? 15 * 60 : 2 * 60 * 60 }
        public var count: Int { self == .day ? 96 : 84 }
    }

    /// ``HistoryStatistics`` of the last 24 hours, the figures the widget shows.
    public struct Statistics: Sendable, Equatable, Codable {
        /// In percent per hour, to a tenth; `nil` until there is enough to go on.
        public var averageDrainPercentPerHour: Double?
        /// In whole seconds.
        public var timeOnBattery: Int
        public var chargingSessions: Int

        public init(averageDrainPercentPerHour: Double?, timeOnBattery: Int, chargingSessions: Int) {
            self.averageDrainPercentPerHour = averageDrainPercentPerHour
            self.timeOnBattery = timeOnBattery
            self.chargingSessions = chargingSessions
        }
    }

    /// Daily summaries as parallel arrays from `firstDay`, one entry per local day, `nil` for a
    /// day without a summary.
    public struct Daily: Sendable, Equatable, Codable {
        /// A local day as ``HistoryDay`` names it ("2026-10-14").
        public var firstDay: String
        /// The capacity compared with design, in tenths of a percent (unclamped).
        public var capacityToDesign10: [Int?]
        public var cycleCount: [Int?]

        public init(firstDay: String, capacityToDesign10: [Int?], cycleCount: [Int?]) {
            self.firstDay = firstDay
            self.capacityToDesign10 = capacityToDesign10
            self.cycleCount = cycleCount
        }
    }

    /// A remembered iPhone or iPad, as the app shows it.
    public struct Device: Sendable, Equatable, Codable {
        /// The keyed hash the app names the device by: never its UDID.
        public var key: DeviceKey
        /// The name the owner gave it.
        public var name: String?
        /// The model's name as the system names it for the app ("iPhone 17 Pro Max"); `nil` when
        /// the system doesn't know the model.
        public var model: String?
        /// "iPhone" or "iPad".
        public var deviceClass: String?
        /// The charge in whole percent.
        public var percent: Int?
        public var state: ChargeState
        /// The maximum capacity iOS Settings shows, in whole percent.
        public var maximumCapacity: Int?
        public var cycleCount: Int?
        /// In tenths of a degree Celsius.
        public var temperature10: Int?
        /// When the app last read its battery, to the second.
        public var readAt: Date?

        public init(
            key: DeviceKey, name: String? = nil, model: String? = nil, deviceClass: String? = nil,
            percent: Int? = nil, state: ChargeState = .unknown, maximumCapacity: Int? = nil, cycleCount: Int? = nil,
            temperature10: Int? = nil, readAt: Date? = nil
        ) {
            self.key = key
            self.name = name
            self.model = model
            self.deviceClass = deviceClass
            self.percent = percent
            self.state = state
            self.maximumCapacity = maximumCapacity
            self.cycleCount = cycleCount
            self.temperature10 = temperature10
            self.readAt = readAt
        }

        enum CodingKeys: String, CodingKey {
            case key, name, model, deviceClass, percent, state, maximumCapacity, cycleCount, temperature10, readAt
        }

        /// A state this version doesn't know reads as unknown, as in the history.
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            key = try c.decode(DeviceKey.self, forKey: .key)
            name = try c.decodeIfPresent(String.self, forKey: .name)
            model = try c.decodeIfPresent(String.self, forKey: .model)
            deviceClass = try c.decodeIfPresent(String.self, forKey: .deviceClass)
            percent = try c.decodeIfPresent(Int.self, forKey: .percent)
            state = (try? c.decodeIfPresent(ChargeState.self, forKey: .state)) ?? .unknown
            maximumCapacity = try c.decodeIfPresent(Int.self, forKey: .maximumCapacity)
            cycleCount = try c.decodeIfPresent(Int.self, forKey: .cycleCount)
            temperature10 = try c.decodeIfPresent(Int.self, forKey: .temperature10)
            readAt = try c.decodeIfPresent(Date.self, forKey: .readAt)
        }
    }

    /// The same feed written at `date`: what tells a feed whose content changed from one only
    /// written again.
    public func written(at date: Date) -> WidgetFeed {
        var feed = self
        feed.writtenAt = date
        return feed
    }
}

// MARK: - Sections

extension WidgetFeed {
    /// The parts of a feed that depend on what is placed: a section is written only while a
    /// widget that shows it may be placed, and only while its setting is on.
    public enum Section: String, Sendable, CaseIterable {
        /// The series, the figures, the start on battery and the daily summaries.
        case history
        /// The remembered iPhones and iPads.
        case devices

        /// The kinds that show the section. No kind shows the devices yet, so they are never
        /// written until one that does ships and joins its list.
        public var readers: [WidgetKindID] {
            switch self {
            case .history: [.battery]
            case .devices: []
            }
        }
    }

    /// The sections a write holds: each one its setting allows and a kind that shows it counts as
    /// placed for (``WidgetPlacements``, which counts every kind as placed until WidgetKit lists
    /// some). A section no kind shows is never written.
    public static func sections(
        recordsHistory: Bool, readsDevices: Bool, placements: WidgetPlacements,
        readers: (Section) -> [WidgetKindID] = \Section.readers
    ) -> Set<Section> {
        Set(
            allowedSections(recordsHistory: recordsHistory, readsDevices: readsDevices).filter { section in
                readers(section).contains(where: placements.isPlaced)
            })
    }

    /// Whether to ask WidgetKit for the placed widgets before a write at `date`: a section its
    /// setting allows has kinds that show it, none of which the last answer lists, and that answer
    /// is old enough to ask again (``WidgetPlacements/needsAnswer(toReload:at:)``).
    public static func needsPlacementAnswer(
        recordsHistory: Bool, readsDevices: Bool, placements: WidgetPlacements, at date: Date,
        readers: (Section) -> [WidgetKindID] = \Section.readers
    ) -> Bool {
        allowedSections(recordsHistory: recordsHistory, readsDevices: readsDevices).contains { section in
            let kinds = readers(section)
            return !kinds.isEmpty && kinds.allSatisfy { placements.needsAnswer(toReload: $0, at: date) }
        }
    }

    private static func allowedSections(recordsHistory: Bool, readsDevices: Bool) -> [Section] {
        Section.allCases.filter { section in
            switch section {
            case .history: recordsHistory
            case .devices: readsDevices
            }
        }
    }
}

// MARK: - Writes

extension WidgetFeed {
    /// Why the app writes the feed; logged as its case name.
    public enum WriteReason: String, Sendable, CaseIterable {
        /// The routine write, once per step of the day series, changed or not, so `writtenAt`
        /// keeps saying that BatteryPulse runs.
        case step
        /// Clear History.
        case historyCleared
        /// Record battery history turned on or off.
        case recording
        /// A device read, forgotten, or reads turned on or off.
        case devices
        /// The adapter plugged in or out.
        case plug
        /// Demo Mode ended: what it kept from being written is written now.
        case demoEnded

        /// Whether the write goes out even when nothing but `writtenAt` changed.
        public var writesUnchanged: Bool { self == .step }

        /// The trigger of the `widget.feed.write` signpost.
        public var signpostName: StaticString {
            switch self {
            case .step: "step"
            case .historyCleared: "historyCleared"
            case .recording: "recording"
            case .devices: "devices"
            case .plug: "plug"
            case .demoEnded: "demoEnded"
            }
        }
    }

    /// When the routine write is due: once per step of the day series, at the first minute tick
    /// in it. A plain value with the caller's clock.
    public struct StepSchedule: Sendable {
        private var lastStep: Int?

        public init() {}

        /// Whether the routine write is due at `date`, the history recorder's tick; records it.
        /// A clock set back starts another step too.
        public mutating func isDue(at date: Date) -> Bool {
            let step = WidgetFeed.stepIndex(of: date, step: Period.day.step)
            guard step != lastStep else { return false }
            lastStep = step
            return true
        }
    }

    /// The index of the step of `step` seconds that holds `date`, counted from 1970.
    static func stepIndex(of date: Date, step: Int) -> Int {
        let seconds = date.timeIntervalSince1970
        guard seconds.isFinite, abs(seconds) < 1e15 else { return 0 }
        return Int((seconds / Double(step)).rounded(.down))
    }
}

// MARK: - Building

extension WidgetFeed {
    /// Everything the builder reads, gathered by the app: the settings and the devices on the main
    /// actor, the history from its store.
    public struct Source: Sendable {
        public var now: Date
        /// Demo Mode is on: nothing is written.
        public var isOverridden: Bool
        public var languages: [String]
        public var recordsHistory: Bool
        public var readsDevices: Bool
        /// What ``sections(recordsHistory:readsDevices:placements:readers:)`` allows.
        public var sections: Set<Section>
        /// The Mac's samples of at least the last week (``historyStart(at:)``), oldest first.
        public var samples: [HistorySample]
        /// The daily summaries, oldest first.
        public var days: [HistoryDay]
        /// The battery now, as a sample that may not be recorded yet: an unplug the history hasn't
        /// caught.
        public var current: HistorySample?
        public var devices: [RememberedDevice]
        /// Model names by product type, as the app resolves them.
        public var modelNames: [String: String]
        /// The time zone of the daily summaries' local days.
        public var timeZone: TimeZone

        public init(
            now: Date, isOverridden: Bool = false, languages: [String], recordsHistory: Bool, readsDevices: Bool,
            sections: Set<Section>, samples: [HistorySample] = [], days: [HistoryDay] = [],
            current: HistorySample? = nil, devices: [RememberedDevice] = [], modelNames: [String: String] = [:],
            timeZone: TimeZone = .current
        ) {
            self.now = now
            self.isOverridden = isOverridden
            self.languages = languages
            self.recordsHistory = recordsHistory
            self.readsDevices = readsDevices
            self.sections = sections
            self.samples = samples
            self.days = days
            self.current = current
            self.devices = devices
            self.modelNames = modelNames
            self.timeZone = timeZone
        }

        /// Whether the feed holds the history: recording is on and a placed kind shows it.
        public var includesHistory: Bool { recordsHistory && sections.contains(.history) }
        public var includesDevices: Bool { readsDevices && sections.contains(.devices) }
    }

    /// The earliest sample the builder uses at `now`: the start of the week series.
    public static func historyStart(at now: Date) -> Date {
        seriesStart(.week, at: now)
    }

    /// The feed for `source`, or `nil` in Demo Mode. A pure function: the app calls it off the
    /// main actor. It applies the reader's caps itself, so the largest feed it writes is the
    /// largest a reader accepts.
    public static func build(_ source: Source) -> WidgetFeed? {
        guard !source.isOverridden else { return nil }
        var feed = WidgetFeed(
            writtenAt: wholeSeconds(source.now), languages: sanitizedLanguages(source.languages),
            recordsHistory: source.recordsHistory, readsDevices: source.readsDevices)
        if source.includesHistory {
            let samples = source.samples.filter { $0.time.timeIntervalSince1970.isFinite && $0.time <= source.now }
            feed.day = series(.day, from: samples, at: source.now)
            feed.week = series(.week, from: samples, at: source.now)
            let lastDay = samples.filter { $0.time >= source.now.addingTimeInterval(-24 * 60 * 60) }
            feed.statistics24h = lastDay.isEmpty ? nil : Statistics(HistoryStatistics(samples: lastDay))
            feed.onBatterySince = onBatterySince(samples, current: source.current).map(wholeSeconds)
            feed.daily = daily(source.days, at: source.now, timeZone: source.timeZone)
        }
        if source.includesDevices {
            feed.devices = devices(source.devices, modelNames: source.modelNames)
        }
        return feed
    }

    /// The start of the period's first step at `now`: its last step holds `now`.
    static func seriesStart(_ period: Period, at now: Date) -> Date {
        let last = stepIndex(of: now, step: period.step)
        return Date(timeIntervalSince1970: TimeInterval((last - period.count + 1) * period.step))
    }

    /// The samples re-bucketed into the period's steps: means, with an empty step a gap.
    static func series(_ period: Period, from samples: [HistorySample], at now: Date) -> Series {
        let start = seriesStart(period, at: now)
        let first = stepIndex(of: start, step: period.step)
        var steps = [Accumulator](repeating: Accumulator(), count: period.count)
        for sample in samples {
            let index = stepIndex(of: sample.time, step: period.step) - first
            guard steps.indices.contains(index) else { continue }
            steps[index].add(sample)
        }
        return Series(
            start: start, step: period.step, percent: steps.map { $0.percent.mean(scaledBy: 1, in: Bounds.percent) },
            batteryWatts10: steps.map { $0.batteryWatts.mean(scaledBy: 10, in: Bounds.watts10) },
            temperature10: steps.map { $0.temperature.mean(scaledBy: 10, in: Bounds.temperature10) },
            plugged: steps.map(\.isPlugged))
    }

    /// One step's samples, summed.
    private struct Accumulator {
        struct Mean {
            var sum = 0.0
            var count = 0

            mutating func add(_ value: Double?) {
                guard let value, value.isFinite else { return }
                sum += value
                count += 1
            }

            func mean(scaledBy scale: Double, in range: ClosedRange<Int>) -> Int? {
                count == 0 ? nil : WidgetFeed.scaled(sum / Double(count), by: scale, in: range)
            }
        }

        var percent = Mean()
        var batteryWatts = Mean()
        var temperature = Mean()
        var samples = 0
        var plugged = 0

        mutating func add(_ sample: HistorySample) {
            percent.add(sample.percent)
            batteryWatts.add(sample.batteryWatts)
            temperature.add(sample.temperatureCelsius)
            samples += 1
            if !sample.isOnBattery { plugged += 1 }
        }

        var isPlugged: Bool? { samples == 0 ? nil : plugged * 2 >= samples }
    }

    /// When the current run on battery began: the first sample of the run of samples on battery
    /// that ends the history, across sleep, but not before a launch, since nothing says what
    /// happened while BatteryPulse wasn't running. On the adapter now, or without samples, `nil`;
    /// unplugged since the last sample, the current reading's time.
    static func onBatterySince(_ samples: [HistorySample], current: HistorySample?) -> Date? {
        if let current, !current.isOnBattery { return nil }
        guard let last = samples.last else { return nil }
        guard last.isOnBattery else { return current?.time }
        var start = last
        for sample in samples.reversed() {
            guard sample.isOnBattery else { break }
            start = sample
            if sample.event == .launch { break }
        }
        return start.time
    }

    /// The last 90 local days that have a summary, from the first of them to the last.
    static func daily(_ days: [HistoryDay], at now: Date, timeZone: TimeZone) -> Daily? {
        let calendar = HistoryDay.gregorian(in: timeZone)
        guard let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) else { return nil }
        let keys = (0..<maximumDays).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: noon).map { HistoryDay.key(for: $0, calendar: calendar) }
        }
        let byDay = Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { _, last in last })
        guard let first = keys.firstIndex(where: { byDay[$0] != nil }),
            let last = keys.lastIndex(where: { byDay[$0] != nil })
        else { return nil }
        let window = keys[first...last].map { byDay[$0] }
        return Daily(
            firstDay: keys[first],
            capacityToDesign10: window.map {
                $0?.capacityToDesignPercent.flatMap { scaled($0, by: 10, in: Bounds.capacity10) }
            },
            cycleCount: window.map { within($0?.cycleCount, Bounds.cycles) })
    }

    /// The remembered devices, the most recently read first, at most ``maximumDevices``, never
    /// Demo Mode's.
    static func devices(_ remembered: [RememberedDevice], modelNames: [String: String]) -> [Device] {
        let real = remembered.filter { $0.id != .demo }
        let ordered = real.sorted { ($0.lastRead ?? .distantPast) > ($1.lastRead ?? .distantPast) }
        return ordered.prefix(maximumDevices).map { device in
            let battery = device.battery
            return Device(
                key: device.id, name: sanitizedName(device.name),
                model: sanitizedName(device.productType.flatMap { modelNames[$0] }),
                deviceClass: sanitizedName(device.deviceClass, maximumScalars: maximumClassScalars),
                percent: battery?.chargePercent.flatMap { scaled($0, by: 1, in: Bounds.percent) },
                state: battery?.chargeState ?? .unknown,
                maximumCapacity: battery?.maximumCapacityPercent.flatMap {
                    scaled($0, by: 1, in: Bounds.maximumCapacity)
                },
                cycleCount: within(battery?.cycleCount, Bounds.cycles),
                temperature10: battery?.temperatureCelsius.flatMap { scaled($0, by: 10, in: Bounds.temperature10) },
                readAt: device.lastRead.map(wholeSeconds))
        }
    }

    /// The range a number may take; outside it, a value is a gap. So a corrupt sample can't trap
    /// a conversion or stretch a chart, and the largest feed has a size.
    enum Bounds {
        static let percent = 0...100
        /// ±999.9 W.
        static let watts10 = -9_999...9_999
        /// −99.9 to 199.9 °C.
        static let temperature10 = -999...1_999
        /// Up to 999.9 % of the design capacity.
        static let capacity10 = 0...9_999
        static let cycles = 0...99_999
        static let maximumCapacity = 0...999
        /// Up to 999.9 % per hour.
        static let drain10 = 0...9_999
        /// A week, in seconds.
        static let timeOnBattery = 0...(7 * 24 * 60 * 60)
        static let sessions = 0...9_999
    }

    /// `value × scale`, rounded, if it lies in `range`; `nil` for a value that isn't finite or is
    /// outside it.
    static func scaled(_ value: Double, by scale: Double, in range: ClosedRange<Int>) -> Int? {
        let scaled = (value * scale).rounded()
        guard scaled.isFinite, scaled >= Double(range.lowerBound), scaled <= Double(range.upperBound) else {
            return nil
        }
        return Int(scaled)
    }

    /// `value` if it lies in `range`.
    static func within(_ value: Int?, _ range: ClosedRange<Int>) -> Int? {
        value.flatMap { range.contains($0) ? $0 : nil }
    }

    static func wholeSeconds(_ date: Date) -> Date {
        Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
    }
}

extension WidgetFeed.Statistics {
    init(_ statistics: HistoryStatistics) {
        self.init(
            averageDrainPercentPerHour: statistics.averageDrainPercentPerHour.flatMap {
                WidgetFeed.scaled($0, by: 10, in: WidgetFeed.Bounds.drain10).map { Double($0) / 10 }
            },
            timeOnBattery: WidgetFeed.scaled(statistics.timeOnBattery, by: 1, in: WidgetFeed.Bounds.timeOnBattery) ?? 0,
            chargingSessions: WidgetFeed.within(statistics.chargingSessions, WidgetFeed.Bounds.sessions) ?? 0)
    }
}

// MARK: - Names

extension WidgetFeed {
    /// `name` without control, line-separator and bidirectional-control characters, trimmed and
    /// cut to `maximumScalars` Unicode scalars; `nil` when nothing is left.
    public static func sanitizedName(_ name: String?, maximumScalars: Int = maximumNameScalars) -> String? {
        guard let name else { return nil }
        let kept = name.unicodeScalars.filter { scalar in
            let properties = scalar.properties
            switch properties.generalCategory {
            case .control, .lineSeparator, .paragraphSeparator: return false
            default: return !properties.isBidiControl
            }
        }
        let trimmed = String(String.UnicodeScalarView(kept)).trimmingCharacters(in: .whitespacesAndNewlines)
        let cut = String(String.UnicodeScalarView(trimmed.unicodeScalars.prefix(maximumScalars)))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cut.isEmpty ? nil : cut
    }

    /// Language codes as `Bundle.preferredLocalizations` writes them: letters, digits, `-` and
    /// `_`; anything else is dropped.
    static func sanitizedLanguages(_ languages: [String]) -> [String] {
        let valid = languages.filter { language in
            (1...maximumLanguageLength).contains(language.utf8.count)
                && language.utf8.allSatisfy { byte in
                    (0x30...0x39).contains(byte) || (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte)
                        || byte == 0x2D || byte == 0x5F
                }
        }
        return Array(valid.prefix(maximumLanguages))
    }
}

// MARK: - Coding

extension WidgetFeed {
    /// Why a reader turned a file down; logged as its case name.
    public enum Rejection: String, Error, Sendable, CaseIterable {
        /// Larger than ``WidgetFeed/maximumBytes``.
        case oversized
        /// Not a regular file: a link, a folder, a pipe.
        case notARegularFile
        /// Not a feed: not JSON, cut short, or a field of the wrong type.
        case malformed
        /// A version this reader doesn't know.
        case unknownVersion
        /// A series' or the daily summaries' arrays differ in length, or hold more than their
        /// period's steps, or a series' step isn't its period's.
        case mismatchedLengths
        /// A number that is NaN or infinite.
        case notFinite
        /// A date more than ``WidgetFeed/futureTolerance`` ahead.
        case futureDate
    }

    /// The bytes the app writes: compact, with sorted keys so the same feed is the same file.
    public static func encoded(_ feed: WidgetFeed) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(feed)
    }

    /// The feed in `data`, validated as untrusted input at `now`, with its names cleaned and its
    /// lists capped as the builder caps them. Fields it doesn't know are ignored.
    public static func decode(_ data: Data, now: Date) throws(Rejection) -> WidgetFeed {
        guard data.count <= maximumBytes else { throw .oversized }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        struct Header: Decodable { var version: Int }
        guard let header = try? decoder.decode(Header.self, from: data) else { throw .malformed }
        guard header.version == currentVersion else { throw .unknownVersion }
        guard let feed = try? decoder.decode(WidgetFeed.self, from: data) else { throw .malformed }
        try feed.validate(now: now)
        return feed.sanitized()
    }

    /// Throws the first rule `self` breaks.
    func validate(now: Date) throws(Rejection) {
        let dates =
            [writtenAt, day?.start, week?.start, onBatterySince].compactMap { $0 }
            + (devices ?? []).compactMap(\.readAt)
        let numbers = dates.map(\.timeIntervalSince1970) + [statistics24h?.averageDrainPercentPerHour].compactMap { $0 }
        guard numbers.allSatisfy(\.isFinite) else { throw .notFinite }
        guard dates.allSatisfy({ $0.timeIntervalSince(now) <= Self.futureTolerance }) else { throw .futureDate }
        for (series, period) in [(day, Period.day), (week, Period.week)] {
            guard let series else { continue }
            let lengths = [
                series.percent.count, series.batteryWatts10.count, series.temperature10.count, series.plugged.count,
            ]
            guard series.step == period.step, Set(lengths).count == 1, series.count <= period.count else {
                throw .mismatchedLengths
            }
        }
        if let daily {
            guard daily.capacityToDesign10.count == daily.cycleCount.count, daily.cycleCount.count <= Self.maximumDays
            else { throw .mismatchedLengths }
            guard Self.isDayKey(daily.firstDay) else { throw .malformed }
        }
    }

    /// Whether `text` is a day as ``HistoryDay/key(for:calendar:)`` writes it: "2026-10-14", a
    /// date that exists.
    static func isDayKey(_ text: String) -> Bool {
        guard text.utf8.count == 10, let utc = TimeZone(identifier: "UTC") else { return false }
        let calendar = HistoryDay.gregorian(in: utc)
        guard let date = HistoryDay(day: text).date(calendar: calendar) else { return false }
        return HistoryDay.key(for: date, calendar: calendar) == text
    }

    /// Names cleaned, Demo Mode's device dropped, the lists capped, and a number outside its
    /// range a gap, as the builder writes them.
    func sanitized() -> WidgetFeed {
        var feed = self
        feed.languages = Self.sanitizedLanguages(languages)
        feed.day = day?.bounded()
        feed.week = week?.bounded()
        feed.statistics24h = statistics24h.map { statistics in
            var statistics = statistics
            statistics.averageDrainPercentPerHour = statistics.averageDrainPercentPerHour.flatMap {
                Self.scaled($0, by: 10, in: Bounds.drain10).map { Double($0) / 10 }
            }
            statistics.timeOnBattery = Self.within(statistics.timeOnBattery, Bounds.timeOnBattery) ?? 0
            statistics.chargingSessions = Self.within(statistics.chargingSessions, Bounds.sessions) ?? 0
            return statistics
        }
        feed.daily = daily.map { daily in
            var daily = daily
            daily.capacityToDesign10 = daily.capacityToDesign10.map { Self.within($0, Bounds.capacity10) }
            daily.cycleCount = daily.cycleCount.map { Self.within($0, Bounds.cycles) }
            return daily
        }
        feed.devices = devices.map { devices in
            devices.filter { $0.key != .demo }.prefix(Self.maximumDevices).map { device in
                var device = device
                device.name = Self.sanitizedName(device.name)
                device.model = Self.sanitizedName(device.model)
                device.deviceClass = Self.sanitizedName(device.deviceClass, maximumScalars: Self.maximumClassScalars)
                device.percent = Self.within(device.percent, Bounds.percent)
                device.maximumCapacity = Self.within(device.maximumCapacity, Bounds.maximumCapacity)
                device.cycleCount = Self.within(device.cycleCount, Bounds.cycles)
                device.temperature10 = Self.within(device.temperature10, Bounds.temperature10)
                return device
            }
        }
        return feed
    }
}

extension WidgetFeed.Series {
    /// The series with each number outside its range a gap.
    func bounded() -> WidgetFeed.Series {
        var series = self
        series.percent = percent.map { WidgetFeed.within($0, WidgetFeed.Bounds.percent) }
        series.batteryWatts10 = batteryWatts10.map { WidgetFeed.within($0, WidgetFeed.Bounds.watts10) }
        series.temperature10 = temperature10.map { WidgetFeed.within($0, WidgetFeed.Bounds.temperature10) }
        return series
    }
}

/// What the widget found where the feed should be.
public enum WidgetFeedState: Sendable, Equatable {
    /// A valid feed; boxed, so the state stays one word wide.
    indirect case feed(WidgetFeed)
    /// No file: BatteryPulse hasn't written one, or the folder is gone.
    case missing
    /// A file the reader turned down.
    case rejected(WidgetFeed.Rejection)
    /// The file couldn't be opened or read: `errno`, `EPERM` when the sandbox denies it.
    case unreadable(Int32)

    /// The feed's state for `data`, read at `now`.
    public init(data: Data, now: Date) {
        do {
            self = .feed(try WidgetFeed.decode(data, now: now))
        } catch {
            self = .rejected(error)
        }
    }

    /// The feed, if there is one.
    public var feed: WidgetFeed? {
        if case .feed(let feed) = self { feed } else { nil }
    }
}
