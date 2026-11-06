import Foundation

/// What a placed iPhone & iPad widget is set to show: the widget's configuration intent maps to it
/// one to one. The default shows the most recently read device.
public struct DevicesWidgetConfiguration: Sendable, Equatable {
    public var show: DevicesWidgetShow
    /// One device's key, for ``DevicesWidgetShow/oneDevice``; `nil` until one is chosen, which
    /// shows the most recently read.
    public var device: DeviceKey?

    public init(show: DevicesWidgetShow = .mostRecent, device: DeviceKey? = nil) {
        self.show = show
        self.device = device
    }
}

/// What one timeline entry of the iPhone & iPad widget shows, decided in BatteryCore so it is
/// tested on Linux; the widget only draws it.
///
/// Its data is the feed the app writes (``WidgetFeed/devices``): the remembered devices' last
/// readings, never Demo Mode's. No feed, device reads off and no device remembered each show a
/// message; a feed over two hours old shows its last readings, each with its time, and "Open
/// BatteryPulse to update".
///
/// - **One device** (small, and the most recently read, the lowest or the chosen one in every
///   size): its charge large, its name, state and read time; medium adds its maximum capacity,
///   large its cycle count and temperature too. A click opens its page. A chosen device the feed
///   no longer holds was forgotten, which the widget says.
/// - **All** (medium and large): a row per device in the feed's order, the most recently read
///   first, each with its charge, state and read time: three in medium and six in large, one
///   fewer while "Open BatteryPulse to update" takes the last row's place. A click opens the
///   Devices section.
///
/// A row carries the device's `DeviceKey`, an HMAC with a key only the app reads, for the click
/// alone: never a UDID, ECID or serial number.
public enum DevicesWidgetPlan: Sendable, Equatable {
    case devices(DevicesWidgetLayout)
    case empty(DevicesWidgetEmptyReason)

    /// The most devices All lists in a size: one row fewer while the line under them shows.
    static func rowSlots(_ size: WidgetSize, isOutdated: Bool) -> Int {
        let slots =
            switch size {
            case .small: 1
            case .medium: 3
            case .large, .extraLarge, .extraLargePortrait: 6
            }
        return size == .small || !isOutdated ? slots : slots - 1
    }

    /// The details of one device a size shows under it: none in small, its maximum capacity in
    /// medium, and its cycle count and temperature too in large, each only when its reading has it.
    static func detailFields(_ size: WidgetSize) -> [BatteryWidgetField] {
        switch size {
        case .small: []
        case .medium: [.maximumCapacity]
        case .large, .extraLarge, .extraLargePortrait: [.maximumCapacity, .cycleCount, .temperature]
        }
    }

    /// The plan for `entry` of a timeline whose read found `feed`; `nil` means no feed (none
    /// written, or one the reader turned down). Read times are in `formatter`'s locale and
    /// `timeZone`.
    public static func make(
        size: WidgetSize, configuration c: DevicesWidgetConfiguration, feed: WidgetFeed?,
        entry: WidgetTimelinePlan.Entry, formatter: BatteryFormatter, timeZone: TimeZone
    ) -> DevicesWidgetPlan {
        guard let feed else { return .empty(.noFeed) }
        guard feed.readsDevices else { return .empty(.readsOff) }
        let devices = feed.devices ?? []
        guard var first = one(of: devices, by: c.show) else { return .empty(.noDevices) }
        if c.show == .oneDevice, let key = c.device {
            guard let chosen = devices.first(where: { $0.key == key }) else { return .empty(.forgotten) }
            first = chosen
        }
        let isOutdated = feed.isOutdated(at: entry.date)
        let showsOne = size == .small || c.show != .all
        let shown = showsOne ? [first] : Array(devices.prefix(rowSlots(size, isOutdated: isOutdated)))
        let details = showsOne ? detailFields(size) : []
        let rows = shown.map {
            DeviceWidgetRow($0, details: details, formatter: formatter, at: entry.date, timeZone: timeZone)
        }
        return .devices(DevicesWidgetLayout(rows: rows, showsOne: showsOne, isOutdated: isOutdated))
    }

    /// The one device `show` picks: the lowest charge (one without a charge only when none has
    /// one), else the most recently read; equal ones, the first in the feed. All lists the feed in
    /// its order, which the app writes the most recently read first, so no choice sorts: a
    /// sort's generic code is the widget's largest per item it shows.
    static func one(of devices: [WidgetFeed.Device], by show: DevicesWidgetShow) -> WidgetFeed.Device? {
        guard show == .lowest else {
            return devices.max { ($0.readAt ?? .distantPast) < ($1.readAt ?? .distantPast) }
        }
        return devices.min { ($0.percent ?? .max) < ($1.percent ?? .max) }
    }

    /// One device opens its page; All, and every message, the Devices section, which lists the
    /// devices or says how to start; without a feed, Overview: opening BatteryPulse writes one.
    public var route: WidgetRoute {
        switch self {
        case .empty(.noFeed):
            WidgetRoute(widgetPage: .overview)
        case .empty:
            WidgetRoute(widgetPage: .devices)
        case .devices(let layout):
            layout.showsOne
                ? layout.rows.first.flatMap { WidgetRoute(page: .device($0.key)) } ?? WidgetRoute(widgetPage: .devices)
                : WidgetRoute(widgetPage: .devices)
        }
    }
}

/// Why the iPhone & iPad widget shows a message instead of a device: one line, and a click opens
/// the page that fixes it.
public enum DevicesWidgetEmptyReason: Sendable, Equatable, CaseIterable {
    /// No feed: BatteryPulse hasn't written one, or the widget couldn't read it ("Open
    /// BatteryPulse to update").
    case noFeed
    /// Read iPhone and iPad batteries is off ("Turn on Read iPhone and iPad batteries in
    /// BatteryPulse").
    case readsOff
    /// Reads are on and no device is remembered yet ("Connect an iPhone or iPad with a cable").
    case noDevices
    /// The chosen device isn't remembered any more ("This device was forgotten"): the edit sheet
    /// offers the others.
    case forgotten
}

/// The iPhone & iPad widget's content for one entry.
public struct DevicesWidgetLayout: Sendable, Equatable {
    /// One device, or All's rows in order.
    public var rows: [DeviceWidgetRow]
    /// One device drawn large, with its details: always in small, and for every choice but All.
    public var showsOne: Bool
    /// The feed is over two hours old: "Open BatteryPulse to update" under the last readings.
    public var isOutdated: Bool
}

/// A remembered device as the widget shows it: pre-formatted.
public struct DeviceWidgetRow: Sendable, Equatable {
    /// For the click's route only.
    public var key: DeviceKey
    public var name: DeviceWidgetName
    /// ``IDeviceModel/symbolName(deviceClass:)``: `ipad` or `iphone`.
    public var symbolName: String
    /// "65%", or "—" without a charge.
    public var charge: String
    public var isCharging: Bool
    /// The app's level tiers: low at 20 % and critical at 10 % while not charging.
    public var tier: BatteryPresentation.LevelTier
    public var state: WidgetStateWord
    /// One device's details (``DevicesWidgetPlan/detailFields(_:)``), each label and value.
    public var details: [WidgetRow]
    /// When BatteryPulse read it: the time today ("14:05"), the day before ("Oct 30"); `nil`
    /// without a read time.
    public var updated: String?

    /// The symbol beside a low charge, so its colour is never the only signal.
    public var cue: WidgetCue? { WidgetCue(tier) }

    init(
        _ device: WidgetFeed.Device, details fields: [BatteryWidgetField], formatter f: BatteryFormatter, at date: Date,
        timeZone: TimeZone
    ) {
        key = device.key
        name = DeviceWidgetName(device)
        symbolName = IDeviceModel.symbolName(deviceClass: device.deviceClass)
        charge = device.percent.map { f.percent(Double($0)) } ?? WidgetValue.missing
        isCharging = device.state == .charging
        tier = BatteryPresentation.levelTier(percent: device.percent.map(Double.init), state: device.state)
        state = WidgetStateWord(device: device.state)
        details = fields.compactMap { field in
            let value: String? =
                switch field {
                case .maximumCapacity: device.maximumCapacity.map { f.percent(Double($0)) }
                case .cycleCount: device.cycleCount.map { $0.formatted(.number.locale(f.locale)) }
                case .temperature: device.temperature10.map { f.celsius(Double($0) / 10) }
                default: nil
                }
            return value.map { WidgetRow(field: field, value: .text($0)) }
        }
        updated = device.readAt.map { Self.readTime($0, at: date, locale: f.locale, timeZone: timeZone) }
    }

    /// The time of a read today at `date`, else its day, in the widget's language: "14:05",
    /// "Oct 30".
    static func readTime(_ read: Date, at date: Date, locale: Locale, timeZone: TimeZone) -> String {
        let calendar = HistoryDay.gregorian(in: timeZone)
        guard calendar.isDate(read, inSameDayAs: date) else {
            return read.formatted(
                Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, timeZone: timeZone).month(.abbreviated)
                    .day())
        }
        return read.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone))
    }
}

/// A device's name: the owner's, else its model's, else "iPhone" or "iPad", as the app names it;
/// "Unknown Device" without one. Shown as it is, never looked up, and privacy sensitive.
public enum DeviceWidgetName: Sendable, Equatable {
    case named(String)
    case unknown

    public init(_ device: WidgetFeed.Device) {
        if let name = device.name ?? device.model {
            self = .named(name)
        } else if let deviceClass = device.deviceClass, deviceClass == "iPhone" || deviceClass == "iPad" {
            self = .named(deviceClass)
        } else {
            self = .unknown
        }
    }
}

extension WidgetStateWord {
    /// An iPhone's or iPad's state, in the app's words for it: they report neither the optimized
    /// hold nor the Charge Limit's.
    init(device state: ChargeState) {
        self =
            switch state {
            case .charging: .charging
            case .discharging: .onBattery
            case .charged: .fullyCharged
            case .notCharging: .notCharging
            case .unknown: .unknown
            }
    }
}

// MARK: - VoiceOver

extension WidgetAccessibility {
    /// Every element of the iPhone & iPad widget's `plan`, in the order it shows them: each device
    /// (one device's details after it), then "Open BatteryPulse to update".
    static func elements(_ plan: DevicesWidgetPlan) -> [WidgetSpokenLabel] {
        switch plan {
        case .empty(let reason):
            return [reason.spokenLabel]
        case .devices(let layout):
            return layout.rows.flatMap { [$0.spokenLabel] + $0.details.map(\.spokenLabel) }
                + (layout.isOutdated ? [HistoryWidgetEmptyReason.outdatedLabel] : [])
        }
    }
}

extension DeviceWidgetRow {
    /// "Anna's iPhone, 65%, Charging, Updated 14:05".
    public var spokenLabel: WidgetSpokenLabel {
        .phrases(
            [name.phrase, .verbatim(charge), state.phrase]
                + (updated.map { [WidgetPhrase.key("Updated %@", [.verbatim($0)])] } ?? []))
    }
}

extension DevicesWidgetEmptyReason {
    /// The message the widget shows; its symbol is hidden.
    public var spokenLabel: WidgetSpokenLabel {
        .phrases([.key(messageKey)])
    }

    var messageKey: String {
        switch self {
        case .noFeed: HistoryWidgetEmptyReason.outdatedKey
        case .readsOff: "Turn on Read iPhone and iPad batteries in BatteryPulse"
        case .noDevices: "Connect an iPhone or iPad with a cable"
        case .forgotten: "This device was forgotten"
        }
    }
}

// The catalog keys of the iPhone & iPad widget's own words, the same keys its views use (a macOS
// test compares them).

extension DeviceWidgetName {
    var phrase: WidgetPhrase {
        switch self {
        case .named(let name): .verbatim(name)
        case .unknown: .key("Unknown Device")
        }
    }
}
