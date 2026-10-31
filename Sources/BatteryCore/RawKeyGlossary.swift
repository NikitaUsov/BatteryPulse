import Foundation

/// What the raw keys in the Developer section mean and how to show their values.
///
/// These keys are undocumented Apple internals. Entries are limited to meanings backed by Apple's
/// open-source code and headers, the battery driver's own symbol names, the USB Power Delivery
/// specification, the gauge's and charger's technical references, or consistency checks against
/// real captures; unknown keys get no explanation rather than a guess.
///
/// Keys of the registry entries below `AppleSmartBattery` are looked up with their class first
/// (`AppleSmartBatteryPack.BatteryData.Amperage`), then as the plain path (`BatteryData.Qmax`);
/// only entries whose text is specific to one class carry the prefix.
///
/// Summaries are English. The app localizes them through `Resources/Localizable.xcstrings`, which
/// `LocalizationCatalogTests` keeps in sync.
public enum RawKeyGlossary {
    public struct Info: Sendable, Equatable {
        public var summary: String?
        public var kind: RawValueKind
        public var sentinels: [Int64: RawSentinel]

        public init(_ kind: RawValueKind, _ summary: String?, sentinels: [Int64: RawSentinel] = [:]) {
            self.kind = kind
            self.summary = summary
            self.sentinels = sentinels
        }
    }

    /// The glossary key for a flattened path: array indices removed, `AppleRawAdapterDetails`
    /// folded into `AdapterDetails`, adapter details prefixed `AdapterDetails.` and IOPS keys
    /// prefixed `IOPS.`.
    public static func canonicalKey(captureKey: String, path: String) -> String {
        var key = removingArrayIndices(path)
        switch captureKey {
        case BatteryReading.CaptureKey.adapterDetails:
            key = "AdapterDetails." + key
        case BatteryReading.CaptureKey.powerSource:
            key = "IOPS." + key
        default:
            if key.hasPrefix("AppleRawAdapterDetails") {
                key = "AdapterDetails" + key.dropFirst("AppleRawAdapterDetails".count)
            }
        }
        return key
    }

    /// `UsbHvcMenu[2].MaxVoltage` → `UsbHvcMenu.MaxVoltage`: drops every `[digits]`. A plain scan,
    /// since a Regex took most of the time to build the Developer table's 600 rows.
    static func removingArrayIndices(_ path: String) -> String {
        guard path.contains("[") else { return path }
        var result = Substring()
        var rest = path[...]
        while let open = rest.firstIndex(of: "[") {
            let digits = rest.index(after: open)
            if let close = rest[digits...].firstIndex(of: "]"), close > digits,
                rest[digits..<close].allSatisfy({ $0.isASCII && $0.isNumber })
            {
                result += rest[..<open]
                rest = rest[rest.index(after: close)...]
            } else {
                result += rest[...open]
                rest = rest[digits...]
            }
        }
        result += rest
        return String(result)
    }

    public static func info(for key: String) -> Info? {
        if let info = entries[key] { return info }
        return families.first { key.hasPrefix($0.prefix) }?.info
    }

    /// Every English summary, for the localization catalog test.
    public static var summaries: Set<String> {
        Set((entries.values.map(\.summary) + families.map(\.info.summary)).compactMap { $0 })
    }

    static let entries: [String: Info] = Dictionary(uniqueKeysWithValues: table)

    /// Groups of similar keys explained together, matched by prefix (longest first).
    static let families: [(prefix: String, info: Info)] = familyTable.sorted { $0.prefix.count > $1.prefix.count }

    private static let table: [(String, Info)] = [
        ("AdapterDetails", Info(.other, "Details of the connected power adapter; empty when the Mac runs on battery.")),
        (
            "AdapterDetails.AdapterID",
            Info(.hex, "Apple's model ID for the adapter; the Model key shows the same number in hex.")
        ),
        (
            "AdapterDetails.AdapterVoltage",
            Info(.millivolts, "Voltage of the power contract currently negotiated with the adapter.")
        ),
        (
            "AdapterDetails.Current",
            Info(.milliamps, "Current limit of the negotiated contract, equal to MaxCurrent of the active profile.")
        ),
        (
            "AdapterDetails.Description",
            Info(.text, "Charger type label, e.g. \"pd charger\" for a USB Power Delivery charger.")
        ),
        (
            "AdapterDetails.ErrorFlags",
            Info(.flags, "Adapter error bits, e.g. insufficient power or a foreign object on a wireless charger.")
        ),
        (
            "AdapterDetails.FamilyCode",
            Info(.hex, "Adapter family code: 0xE000400A is USB-C Power Delivery, 0 means nothing is connected.")
        ),
        ("AdapterDetails.FwVersion", Info(.text, "Firmware version string reported by the adapter.")),
        ("AdapterDetails.HwVersion", Info(.text, "Hardware revision string reported by the adapter.")),
        (
            "AdapterDetails.IsWireless",
            Info(.boolean, "True when power comes from a wireless (inductive) charger instead of a cable.")
        ),
        ("AdapterDetails.Manufacturer", Info(.text, "Adapter maker's name as reported by the adapter.")),
        ("AdapterDetails.Model", Info(.identifier, "Adapter model ID as a hex string; the same value as AdapterID.")),
        ("AdapterDetails.Name", Info(.text, "Adapter's own product name.")),
        (
            "AdapterDetails.PMUConfiguration",
            Info(.milliamps, "Input current limit the Mac's charger is set to draw from this adapter.")
        ),
        ("AdapterDetails.SerialString", Info(.identifier, "Adapter serial number.")),
        (
            "AdapterDetails.UsbHvcHvcIndex",
            Info(.identifier, "Zero-based position of the negotiated USB-PD power profile in the adapter's offer.")
        ),
        (
            "AdapterDetails.UsbHvcMenu.Index",
            Info(.identifier, "Zero-based position of this USB-PD profile in the adapter's offer list.")
        ),
        (
            "AdapterDetails.UsbHvcMenu.MaxCurrent",
            Info(.milliamps, "Maximum current the adapter offers at this profile's voltage.")
        ),
        (
            "AdapterDetails.UsbHvcMenu.MaxVoltage",
            Info(.millivolts, "Fixed voltage of this USB-PD profile offered by the adapter.")
        ),
        (
            "AdapterDetails.Watts",
            Info(.other, "Power of the negotiated contract in watts (voltage x current), not the label rating.")
        ),
        (
            "AdapterInfo",
            Info(.other, "Legacy IOPMPowerSource adapter-info field; Apple silicon always leaves it at 0.")
        ),
        (
            "Amperage",
            Info(
                .milliamps,
                "Average battery current from the gauge; negative while discharging, positive while charging.")
        ),
        (
            "AppleRawBatteryVoltage",
            Info(.millivolts, "Battery pack voltage; reads the same as Voltage on Apple silicon.")
        ),
        (
            "AppleRawCurrentCapacity",
            Info(.milliampHours, "Remaining charge in mAh, as reported by the gauge (pre-macOS 27).")
        ),
        (
            "AppleRawExternalConnected",
            Info(.boolean, "External power seen right now, without the 1-second unplug debounce of ExternalConnected.")
        ),
        (
            "AppleRawMaxCapacity",
            Info(.milliampHours, "Full charge capacity in mAh (pre-macOS 27); excludes the reserve.")
        ),
        (
            "AppleSmartBatteryPack.BatteryData.Amperage",
            Info(
                .milliamps,
                "Copy of Amperage in AppleSmartBatteryPack (macOS 27): average current, negative while discharging.")
        ),
        (
            "AppleSmartBatteryPack.BatteryData.AppleRawBatteryVoltage",
            Info(
                .millivolts,
                "Pack voltage in AppleSmartBatteryPack (macOS 27); equals Voltage and AppleRawBatteryVoltage."
            )
        ),
        (
            "AppleSmartBatteryPack.BatteryData.AppleRawCurrentCapacity",
            Info(
                .milliampHours,
                "Remaining charge in mAh in AppleSmartBatteryPack (macOS 27); equals RemainingCapacity (no reserve).")
        ),
        (
            "AppleSmartBatteryPack.BatteryData.AppleRawMaxCapacity",
            Info(
                .milliampHours,
                "Full charge capacity in mAh in AppleSmartBatteryPack (macOS 27); equals FullChargeCapacity (no reserve)."
            )
        ),
        (
            "AppleSmartBatteryPack.BatteryData.BatteryPower",
            Info(
                .milliwatts,
                "Reads 0 in AppleSmartBatteryPack on every Mac sampled; the battery's power is BatteryData.BatteryPower of AppleSmartBattery."
            )
        ),
        (
            "AppleSmartBatteryPack.BatteryData.InstantAmperage",
            Info(
                .milliamps,
                "Copy of InstantAmperage in AppleSmartBatteryPack (macOS 27): instant current, negative while discharging."
            )
        ),
        (
            "AtCriticalLevel",
            Info(.boolean, "True when the battery is critically low and macOS forces sleep or shutdown.")
        ),
        (
            "AvgTimeToEmpty",
            Info(
                .minutes, "Gauge estimate of minutes until empty at the average discharge current.",
                sentinels: [65535: .notAvailable])
        ),
        (
            "AvgTimeToFull",
            Info(
                .minutes, "Gauge estimate of minutes until full at the average charge current.",
                sentinels: [65535: .notAvailable])
        ),
        (
            "BankCount",
            Info(
                .count,
                "Number of cell banks wired in series in the pack; each has its own AppleSmartBatteryBank entry.")
        ),
        ("BankID", Info(.identifier, "Position of this bank (cell group) in the series string of the pack.")),
        (
            "BatteryCellDisconnectCount",
            Info(.count, "Number of battery cell disconnect events the gauge has recorded.")
        ),
        (
            "BatteryData.AbsoluteCapacity",
            Info(.other, "Gauge capacity field that reads 0 on every Apple silicon Mac sampled.")
        ),
        ("BatteryData.AdapterPower", Info(.other, "Power drawn from the adapter, in watts (floating point).")),
        (
            "BatteryData.AlgoChemID",
            Info(.identifier, "Chemistry ID used by the gauging algorithm; equals ChemID on every Mac sampled.")
        ),
        (
            "BatteryData.AvgTimeToEmpty",
            Info(
                .minutes, "Copy of AvgTimeToEmpty inside the macOS 27 BatteryData dictionary.",
                sentinels: [65535: .notAvailable])
        ),
        (
            "BatteryData.BatteryCellDisconnectCount",
            Info(.count, "Number of battery cell disconnect events the gauge has recorded.")
        ),
        (
            "BatteryData.BatteryPower",
            Info(.milliwatts, "Power flowing into (+) or out of (-) the battery, voltage times current.")
        ),
        (
            "BatteryData.CellVoltage",
            Info(.millivolts, "Voltage of each series cell; together they add up to the pack voltage.")
        ),
        (
            "BatteryData.ChargeAccum",
            Info(.milliampHours, "Charge accumulator in mAh; reads 0 on every Apple silicon Mac sampled.")
        ),
        (
            "BatteryData.ChemID",
            Info(.identifier, "Gauge chemistry ID: selects the cell voltage/impedance model used for gauging.")
        ),
        (
            "BatteryData.ChemicalWeightedRa",
            Info(.other, "Impedance (Ra) field of the gauge that reads 0 on every Apple silicon Mac sampled.")
        ),
        (
            "BatteryData.CurrentCapacity",
            Info(.percent, "Charge level shown to the user, as a percentage (same as top-level CurrentCapacity).")
        ),
        ("BatteryData.CycleCount", Info(.count, "Cycle count as reported inside BatteryData.")),
        (
            "BatteryData.DOD0",
            Info(.other, "Per-cell depth of discharge at the last rested voltage reading, scaled so 16384 = 100 %.")
        ),
        (
            "BatteryData.DailyMaxSoc",
            Info(.percent, "Daily maximum state of charge logged by the gauge; it is not updated live.")
        ),
        ("BatteryData.DailyMinSoc", Info(.percent, "Daily minimum state of charge logged by the gauge.")),
        ("BatteryData.DataFlashWriteCount", Info(.count, "Number of writes the gauge has made to its data flash.")),
        ("BatteryData.DateOfFirstUse", Info(.other, "Battery's date of first use as stored in the SMC.")),
        ("BatteryData.DesignCapacity", Info(.milliampHours, "Capacity the battery was designed to hold when new.")),
        ("BatteryData.FccComp1", Info(.milliampHours, "Full charge capacity without powerd's VAC-T mitigation.")),
        ("BatteryData.FccComp2", Info(.milliampHours, "Full charge capacity with powerd's VAC-T mitigation applied.")),
        (
            "BatteryData.FilteredCurrent",
            Info(.other, "Filtered-current field that reads 0 on every Apple silicon Mac sampled, even under load.")
        ),
        (
            "BatteryData.FullChargeCapacity",
            Info(.milliampHours, "Gauge-predicted capacity when full, excluding the reserve (PackReserve).")
        ),
        (
            "BatteryData.FullyCharged",
            Info(.boolean, "Numeric copy of FullyCharged: 1 when the gauge reports a full charge.")
        ),
        ("BatteryData.GasGaugeFirmwareVersion", Info(.identifier, "Firmware version of the battery gauge.")),
        (
            "BatteryData.GaugeFlagRaw",
            Info(
                .flags,
                "Gauge status bits as in SBS BatteryStatus: 0x80 initialized, 0x40 discharging or idle, 0x20 fully charged."
            )
        ),
        (
            "BatteryData.ISS",
            Info(
                .milliamps,
                "Current in mA, close to Amperage while it is steady but slow to follow a change: just after unplugging it still read the charge current."
            )
        ),
        (
            "BatteryData.LifetimeData.AverageTemperature",
            Info(.other, "Average battery temperature over the pack's life, in tenths of a degree Celsius.")
        ),
        (
            "BatteryData.LifetimeData.CycleCountLastQmax",
            Info(.count, "Cycle count at the gauge's most recent Qmax (capacity) update.")
        ),
        (
            "BatteryData.LifetimeData.MaximumChargeCurrent",
            Info(.milliamps, "Highest charge current seen over the pack's life.")
        ),
        (
            "BatteryData.LifetimeData.MaximumDischargeCurrent",
            Info(.milliamps, "Highest discharge current seen over the pack's life (negative).")
        ),
        (
            "BatteryData.LifetimeData.MaximumPackVoltage",
            Info(.millivolts, "Highest pack voltage seen over the battery's life.")
        ),
        (
            "BatteryData.LifetimeData.MaximumTemperature",
            Info(.other, "Highest battery temperature seen over the pack's life.")
        ),
        (
            "BatteryData.LifetimeData.MinimumPackVoltage",
            Info(.millivolts, "Lowest pack voltage seen over the battery's life.")
        ),
        (
            "BatteryData.LifetimeData.MinimumTemperature",
            Info(.other, "Lowest battery temperature seen over the pack's life.")
        ),
        (
            "BatteryData.LifetimeData.RDISCnt",
            Info(.count, "Number of times the gauge disabled impedance (Ra) updates.")
        ),
        (
            "BatteryData.LifetimeData.TemperatureSamples",
            Info(.count, "Number of temperature samples behind the lifetime average.")
        ),
        (
            "BatteryData.LifetimeData.TimeAtHighSoc",
            Info(.hex, "Binary histogram of time spent at high state of charge.")
        ),
        (
            "BatteryData.LifetimeData.TotalOperatingTime",
            Info(.other, "Total hours the battery gauge has been running since manufacture.")
        ),
        ("BatteryData.LifetimeData.UpdateTime", Info(.unixTime, "When the lifetime data was last refreshed.")),
        (
            "BatteryData.ManufactureDate",
            Info(
                .other,
                "Manufacture date: on TI bq gauges, six ASCII digits that read backwards as YYMMDD, years from 1992.")
        ),
        ("BatteryData.MaxCapacity", Info(.percent, "Scale for CurrentCapacity on Apple silicon; always 100.")),
        ("BatteryData.MfgData", Info(.hex, "Raw manufacturer data block read from the battery gauge.")),
        (
            "BatteryData.NominalChargeCapacity",
            Info(.milliampHours, "Full charge capacity including the reserve: FullChargeCapacity plus PackReserve.")
        ),
        (
            "BatteryData.PMUConfigured",
            Info(.milliamps, "Input current limit last applied by the PMU (pre-macOS 27 location).")
        ),
        (
            "BatteryData.PackCurrentAccumulator",
            Info(
                .other,
                "Running sum of battery current samples in mA; ÷ PackCurrentAccumulatorCount gives the average current."
            )
        ),
        (
            "BatteryData.PackCurrentAccumulatorCount",
            Info(.count, "Number of roughly once-a-second samples added to PackCurrentAccumulator.")
        ),
        (
            "BatteryData.PackReserve",
            Info(.milliampHours, "Capacity held back below 0 % that is not counted in FullChargeCapacity.")
        ),
        (
            "BatteryData.PassedCharge",
            Info(.milliampHours, "Charge moved since the last DOD0 reading; positive = discharged, negative = charged.")
        ),
        (
            "BatteryData.PermanentFailureStatus",
            Info(.flags, "Gauge permanent-failure bitfield; any nonzero bit means the battery needs service.")
        ),
        (
            "BatteryData.PresentDOD",
            Info(.percent, "Per-cell depth of discharge right now, as a percentage of that cell's Qmax.")
        ),
        (
            "BatteryData.Qmax",
            Info(.milliampHours, "Per-cell maximum chemical capacity learned by the gauge (no-load, full to empty).")
        ),
        (
            "BatteryData.RSS",
            Info(.other, "Gauge resistance field in milliohms; reads 0 on every Apple silicon Mac sampled.")
        ),
        (
            "BatteryData.RaTableRaw",
            Info(.hex, "Raw per-cell impedance tables from the gauge, one 32-byte block per cell.")
        ),
        (
            "BatteryData.RemainingCapacity",
            Info(.milliampHours, "Charge left in the battery as predicted by the gauge, excluding the reserve.")
        ),
        ("BatteryData.Serial", Info(.identifier, "Serial number of the battery pack.")),
        (
            "BatteryData.StateOfCharge",
            Info(.percent, "Gauge state of charge: RemainingCapacity as a share of FullChargeCapacity.")
        ),
        ("BatteryData.SystemPower", Info(.other, "Power consumed by the system, in watts (floating point).")),
        (
            "BatteryData.Temperature",
            Info(.centidegreesCelsius, "Battery pack temperature from the gauge, in hundredths of a degree Celsius.")
        ),
        (
            "BatteryData.TrueRemainingCapacity",
            Info(.other, "Gauge capacity field that reads 0 on every Apple silicon Mac sampled.")
        ),
        (
            "BatteryData.VacVoltageLimit",
            Info(.millivolts, "Per-cell charge voltage limit; before macOS 27 this key was in ChargerData.")
        ),
        (
            "BatteryData.VirtualTemperature",
            Info(.centidegreesCelsius, "Battery temperature estimate in hundredths of a degree Celsius.")
        ),
        ("BatteryData.Voltage", Info(.millivolts, "Battery pack voltage as seen by the gauge.")),
        (
            "BatteryData.WeightedRa",
            Info(.other, "Weighted average of the impedance in this bank's RaTableRaw, in units of 1/1024 ohm.")
        ),
        ("BatteryInstalled", Info(.boolean, "True when a battery is present.")),
        (
            "BatteryInvalidWakeSeconds",
            Info(.seconds, "Seconds after wake during which the time-remaining estimate is unreliable.")
        ),
        ("BatteryPackCount", Info(.count, "Number of battery packs the driver manages; 1 on MacBooks.")),
        (
            "BatteryShutdownReason.ShutDownDataError",
            Info(.flags, "Error flags for the saved shutdown record; nonzero means the record is invalid.")
        ),
        (
            "BatteryShutdownReason.ShutDownTimestamp",
            Info(.unixTime, "When the last battery-triggered shutdown happened, as stored by the SMC.")
        ),
        (
            "BestAdapterIndex",
            Info(
                .identifier, "Index into AppleRawAdapterDetails of the adapter macOS chose; AdapterDetails mirrors it.")
        ),
        (
            "BootPathUpdated",
            Info(.unixTime, "When the driver last finished a complete poll of every battery register (done at boot).")
        ),
        ("BootVoltage", Info(.millivolts, "Boot-voltage register; reads 0 on every Apple silicon Mac sampled.")),
        (
            "CarrierMode.CarrierModeHighVoltage",
            Info(.millivolts, "Upper per-cell voltage of the Carrier Mode charge window.")
        ),
        (
            "CarrierMode.CarrierModeLowVoltage",
            Info(.millivolts, "Lower per-cell voltage of the Carrier Mode charge window.")
        ),
        (
            "CarrierMode.CarrierModeStatus",
            Info(.boolean, "Whether Carrier Mode (a charge hold between two cell voltages) is active.")
        ),
        (
            "CellID",
            Info(.identifier, "Position of this cell among the parallel cells of its bank, counted from 0.")
        ),
        ("ChargerConfiguration", Info(.milliamps, "Input current limit currently programmed into the charger.")),
        ("ChargerCount", Info(.count, "Number of charger units the battery driver manages; 1 on MacBooks.")),
        (
            "ChargerData.ChargerAccumEfficiencyCount",
            Info(.count, "Number of samples added to ChargerAccumulatedEfficiency.")
        ),
        (
            "ChargerData.ChargerAccumulatedEfficiency",
            Info(.other, "Running sum of ChargerEfficiency samples; ÷ ChargerAccumEfficiencyCount gives the average.")
        ),
        (
            "ChargerData.ChargerEfficiency",
            Info(
                .other,
                "Efficiency of the Mac's built-in charger, from the charger's power telemetry; reads 0 on battery.")
        ),
        (
            "ChargerData.ChargerHwIlimBackoffReason",
            Info(
                .hex,
                "Why the charger hardware lowered its input current limit (Ilim); Apple does not document the values.")
        ),
        (
            "ChargerData.ChargerIBUS",
            Info(.other, "Current into the charger's input (IBUS), from its power telemetry; reads 0 on battery.")
        ),
        (
            "ChargerData.ChargerID",
            Info(.identifier, "Charger type ID: 12 on M1 Pro, 13 on M2 Pro/Max, 14 on the M4 and M5 Macs sampled.")
        ),
        ("ChargerData.ChargerInhibitReason", Info(.flags, "Bitfield of reasons the charger itself is inhibited.")),
        (
            "ChargerData.ChargerPower",
            Info(.other, "Charger power from the same telemetry as ChargerVBUS and ChargerIBUS; reads 0 on battery.")
        ),
        ("ChargerData.ChargerResetCounter", Info(.count, "Number of times the charger has been reset.")),
        ("ChargerData.ChargerStatus", Info(.hex, "Raw 64-byte charger status block.")),
        (
            "ChargerData.ChargerVBUS",
            Info(.other, "Voltage at the charger's input (VBUS), from its power telemetry; reads 0 on battery.")
        ),
        ("ChargerData.ChargingCurrent", Info(.milliamps, "Charge current the gauge is asking the charger for.")),
        ("ChargerData.ChargingVoltage", Info(.millivolts, "Per-cell charge voltage target the gauge requests.")),
        ("ChargerData.IsCharging", Info(.boolean, "Charger-side charging flag; mirrors top-level IsCharging.")),
        // Bit 24 is SystemChargeLimit.heldBit (m5-macos27-charge-limit.plist).
        (
            "ChargerData.NotChargingReason",
            Info(
                .flags,
                "Bitfield of reasons the battery is not charging; Apple does not document the bits. Bit 24 (0x01000000) is set while the Charge Limit holds the charge."
            )
        ),
        ("ChargerData.PMUConfiguration", Info(.milliamps, "Input current limit requested for the active adapter.")),
        (
            "ChargerData.PMUConfigured",
            Info(.milliamps, "Input current limit last applied by the PMU; equals ChargerConfiguration while charging.")
        ),
        (
            "ChargerData.SlowChargingReason",
            Info(.flags, "Bitfield of reasons charging is being slowed; Apple does not document the bits.")
        ),
        (
            "ChargerData.TimeChargingThermallyLimited",
            Info(.other, "Time during which charging was limited for thermal reasons.")
        ),
        (
            "ChargerData.VacVoltageLimit",
            Info(.millivolts, "Per-cell charge voltage limit; before macOS 27 this key was in ChargerData.")
        ),
        (
            "CurrentCapacity",
            Info(.percent, "Charge level as a percentage on Apple silicon (the IOKit header still says mAh).")
        ),
        ("CycleCount", Info(.count, "Number of full charge-discharge cycles the battery has gone through.")),
        (
            "DeadBatteryBootData.ActivePayloads",
            Info(
                .flags,
                "Which dead-battery boot records are present: bit 0 GeneralPayload, bit 1 SMCBootManagementPayload.")
        ),
        (
            "DesignCapacity",
            Info(.milliampHours, "Capacity the battery was designed to hold when new (pre-macOS 27 top level).")
        ),
        ("DesignCycleCount9C", Info(.count, "Cycle count the battery is rated for (gauge register 0x9C).")),
        ("DeviceName", Info(.text, "Model of the battery fuel-gauge chip (e.g. TI bq40z651).")),
        ("ExternalChargeCapable", Info(.boolean, "True when the connected power source can charge the battery.")),
        (
            "ExternalConnected",
            Info(.boolean, "True when the Mac is drawing external power (disconnects debounced by 1 s).")
        ),
        (
            "FedDetails.FedDesignCapacity",
            Info(.other, "Battery design capacity of the device on this port, from USB PD, in 0.1 Wh units.")
        ),
        (
            "FedDetails.FedDualRolePower",
            Info(
                .boolean,
                "Whether the last USB PD device on this port can both supply and sink power (dual-role power).")
        ),
        (
            "FedDetails.FedExternalConnected",
            Info(
                .boolean,
                "Whether the last USB PD device on this port reported external (wall) power; kept after unplugging.")
        ),
        (
            "FedDetails.FedPdSpecRevision",
            Info(.other, "USB PD revision of the device on this port, encoded as in the PD message header.")
        ),
        (
            "FedDetails.FedPortPowerRole",
            Info(.other, "Power role of the Mac on this port: 0 = sink (being charged), 1 = source (supplying power).")
        ),
        ("FedDetails.FedProductID", Info(.hex, "USB product ID of the device on this port, from its USB PD messages.")),
        (
            "FedDetails.FedRemainingCapacity",
            Info(.other, "Present battery capacity of the device on this port, from USB PD, in 0.1 Wh units.")
        ),
        (
            "FedDetails.FedStateOfCharge",
            Info(.percent, "Battery charge level of the device attached to this port, as reported over USB PD.")
        ),
        (
            "FedDetails.FedVendorID",
            Info(.hex, "USB-IF vendor ID of the device on this port, from its USB PD messages.")
        ),
        (
            "FullPathUpdated",
            Info(.unixTime, "When the driver last finished a 'full' poll (adds cycle count, failure status, etc.).")
        ),
        ("FullyCharged", Info(.boolean, "True when the gauge reports the battery fully charged.")),
        ("GasGaugeFirmwareVersion", Info(.identifier, "Firmware version of the battery gauge.")),
        ("ID", Info(.identifier, "ID of this battery pack or charger entry; 0 on MacBooks.")),
        (
            "IOGeneralInterest",
            Info(.other, "IOKit's list of clients registered for notifications from this service; not battery data.")
        ),
        (
            "IOPS.Battery Provides Time Remaining",
            Info(.boolean, "Marks a source that supplies its own time estimates; always true for the internal battery.")
        ),
        ("IOPS.BatteryHealth", Info(.text, "Coarse battery health rating: Good, Fair, Poor or Check Battery.")),
        (
            "IOPS.BatteryHealthCondition",
            Info(.text, "Health warning such as \"Check Battery\"; absent or empty when the battery is normal.")
        ),
        ("IOPS.Current", Info(.milliamps, "Battery current in mA from powerd, negative when discharging.")),
        ("IOPS.Current Capacity", Info(.percent, "Charge level that macOS shows in the menu bar.")),
        (
            "IOPS.DesignCycleCount",
            Info(
                .count, "Rated cycle count published by powerd; Apple silicon Macs show 300, not the battery's rating.")
        ),
        ("IOPS.Hardware Serial Number", Info(.identifier, "Serial number of the battery pack.")),
        ("IOPS.Is Charged", Info(.boolean, "True when plugged in and the battery counts as fully charged.")),
        ("IOPS.Is Charging", Info(.boolean, "True while the battery is actually charging.")),
        (
            "IOPS.Is Finishing Charge",
            Info(.boolean, "True while charging at 99 % or more, when macOS shows \"Finishing Charge\".")
        ),
        ("IOPS.Is Present", Info(.boolean, "True when the battery is installed.")),
        ("IOPS.LPM Active", Info(.boolean, "True when Low Power Mode is on.")),
        ("IOPS.Max Capacity", Info(.percent, "Scale for Current Capacity; always 100 for the internal battery.")),
        ("IOPS.Name", Info(.identifier, "Power source name; the first internal battery is InternalBattery-0.")),
        (
            "IOPS.Power Source ID",
            Info(
                .identifier,
                "Unique source ID: powerd's process ID in the high 16 bits, 99 for the battery in the low 16.")
        ),
        (
            "IOPS.Power Source State",
            Info(.text, "Where power comes from: \"AC Power\" when plugged in, \"Battery Power\" otherwise.")
        ),
        ("IOPS.Time to Empty", Info(.minutes, "Estimated time left on battery.", sentinels: [-1: .calculating])),
        (
            "IOPS.Time to Full Charge",
            Info(.minutes, "Estimated time until the battery is full.", sentinels: [-1: .calculating])
        ),
        (
            "IOPS.Transport Type",
            Info(
                .text,
                "How the source reports data: Internal for the built-in battery; USB, Serial or Ethernet for a UPS.")
        ),
        ("IOPS.Type", Info(.text, "Kind of power source: InternalBattery or UPS.")),
        (
            "IOReportLegend.IOReportChannelInfo.IOReportChannelUnit",
            Info(.other, "Unit of the battery IOReport channel; 0 means dimensionless (a plain count).")
        ),
        (
            "IOReportLegend.IOReportChannels",
            Info(.other, "IOReporting channel entry [ID, type, name]: here the BatteryCycleCount channel.")
        ),
        (
            "IOReportLegend.IOReportGroupName",
            Info(.text, "IOReporting group the battery channels belong to (\"Battery\").")
        ),
        (
            "IOReportLegendPublic",
            Info(.boolean, "Marks this service's IOReporting channels as publicly visible to reporting tools.")
        ),
        ("InstantAmperage", Info(.milliamps, "Instantaneous battery current; negative while discharging.")),
        ("IsCharging", Info(.boolean, "True when the battery is actually being charged right now.")),
        (
            "KioskMode",
            Info(.other, "Battery Kiosk Mode dictionary, empty: this battery reports no Kiosk Mode state or counters.")
        ),
        ("Location", Info(.identifier, "Battery position for multi-battery machines; 0 on single-battery Macs.")),
        ("ManufacturerData", Info(.hex, "Opaque manufacturer data block read from the battery gauge at boot.")),
        ("MaxCapacity", Info(.percent, "Scale for CurrentCapacity on Apple silicon; always 100.")),
        (
            "NominalChargeCapacity",
            Info(.milliampHours, "Full charge capacity including the reserve: AppleRawMaxCapacity plus PackReserve.")
        ),
        (
            "PackID",
            Info(
                .identifier,
                "ID of the pack this bank or cell belongs to; matches the AppleSmartBatteryPack entry's ID.")
        ),
        (
            "PackReserve",
            Info(.milliampHours, "Capacity held back below 0 % that is not counted in FullChargeCapacity.")
        ),
        (
            "PermanentFailureStatus",
            Info(.flags, "Gauge permanent-failure bitfield; any nonzero bit means the battery needs service.")
        ),
        (
            "PortControllerInfo.PortControllerActiveContractRdo",
            Info(.usbRDO, "USB PD Request Data Object of the last power contract the Mac negotiated on this port.")
        ),
        (
            "PortControllerInfo.PortControllerAttachCount",
            Info(.count, "Number of times something was plugged into this port.")
        ),
        (
            "PortControllerInfo.PortControllerBootFlags",
            Info(.flags, "Boot status flags reported by the USB-C port controller firmware.")
        ),
        (
            "PortControllerInfo.PortControllerDataRoleSwapCount",
            Info(.count, "Number of USB PD data-role swaps (host/device) on this port.")
        ),
        (
            "PortControllerInfo.PortControllerDataRoleSwapFailCount",
            Info(.count, "Number of failed USB PD data-role swaps on this port.")
        ),
        (
            "PortControllerInfo.PortControllerDetachCount",
            Info(.count, "Number of times something was unplugged from this port.")
        ),
        (
            "PortControllerInfo.PortControllerEvtBuffer",
            Info(.hex, "Raw log of recent port-controller events, ordered oldest to newest.")
        ),
        ("PortControllerInfo.PortControllerFwVersion", Info(.hex, "Firmware version of the USB-C port controller.")),
        ("PortControllerInfo.PortControllerHardResetCount", Info(.count, "Number of USB PD Hard Resets on this port.")),
        (
            "PortControllerInfo.PortControllerI2cErrCount",
            Info(.count, "I2C communication errors between the Mac and this port controller.")
        ),
        (
            "PortControllerInfo.PortControllerInpFetEnFailCount",
            Info(.count, "Times enabling this port's input power switch (FET) failed.")
        ),
        (
            "PortControllerInfo.PortControllerIrqCntHrdRst",
            Info(.count, "Port-controller interrupts for USB PD Hard Reset.")
        ),
        (
            "PortControllerInfo.PortControllerIrqCntPdStsUpd",
            Info(.count, "Port-controller 'PD Status Update' interrupts.")
        ),
        (
            "PortControllerInfo.PortControllerIrqCntPlg",
            Info(.count, "Port-controller plug interrupts (both plug-in and unplug).")
        ),
        (
            "PortControllerInfo.PortControllerIrqCntPwrStsUpd",
            Info(.count, "Port-controller 'Power Status Update' interrupts.")
        ),
        (
            "PortControllerInfo.PortControllerIrqCntRxIdSop",
            Info(.count, "Port-controller interrupts for Discover Identity responses received from the partner.")
        ),
        (
            "PortControllerInfo.PortControllerIrqCntRxRdo",
            Info(.count, "Port-controller interrupts for Request (RDO) messages received from a sink.")
        ),
        (
            "PortControllerInfo.PortControllerIrqCntRxSnkCap",
            Info(.count, "Port-controller interrupts for Sink_Capabilities messages received.")
        ),
        (
            "PortControllerInfo.PortControllerIrqCntRxSrcCap",
            Info(.count, "Port-controller interrupts for Source_Capabilities messages received from a charger.")
        ),
        ("PortControllerInfo.PortControllerIrqCntStsUpd", Info(.count, "Port-controller 'Status Update' interrupts.")),
        (
            "PortControllerInfo.PortControllerIrqCntldcm",
            Info(.count, "Port-controller interrupts from Liquid Detection and Corrosion Mitigation (LDCM).")
        ),
        (
            "PortControllerInfo.PortControllerMaxPower",
            Info(.milliwatts, "Maximum power of the charging contract currently active on this port.")
        ),
        (
            "PortControllerInfo.PortControllerNEprPDOs",
            Info(.count, "Number of Extended Power Range (EPR, above 20 V) PDOs the source on this port offered.")
        ),
        (
            "PortControllerInfo.PortControllerNPDOs",
            Info(.count, "Number of standard-range (SPR) PDOs the source on this port offered.")
        ),
        (
            "PortControllerInfo.PortControllerPortPDO",
            Info(
                .usbPDO,
                "Power Data Objects (offers) the charger on this port last advertised; slots 1-7 SPR, 8 and up EPR.")
        ),
        (
            "PortControllerInfo.PortControllerPwrRoleSwapCount",
            Info(.count, "Number of USB PD power-role swaps (source/sink) on this port.")
        ),
        (
            "PortControllerInfo.PortControllerPwrRoleSwapFailCount",
            Info(.count, "Number of failed USB PD power-role swaps on this port.")
        ),
        (
            "PortControllerInfo.PortControllerShortDetectCount",
            Info(.count, "Number of short-circuit detections on this port.")
        ),
        (
            "PortControllerInfo.PortControllerSleepCmdFailCount",
            Info(.count, "Times a sleep command to this port controller failed.")
        ),
        (
            "PortControllerInfo.PortControllerSlpWakIsSleepEnabled",
            Info(.boolean, "Whether this port controller is allowed to enter its low-power sleep state.")
        ),
        (
            "PortControllerInfo.PortControllerSrdyCount",
            Info(.count, "Times the Mac told the controller it is ready to sink power (TI 'SRDY' task).")
        ),
        (
            "PortControllerInfo.PortControllerSrdyRejectCount",
            Info(.count, "Times the controller rejected a 'ready to sink power' (SRDY) request.")
        ),
        (
            "PortControllerInfo.PortControllerVdoFailCount",
            Info(.count, "Failed exchanges of USB PD Vendor Data Objects (VDOs) with the device on this port.")
        ),
        (
            "PortControllerInfo.PortControllerWakeCmdFailCount",
            Info(.count, "Times a wake command to this port controller failed.")
        ),
        ("PortControllerInfo.PortControllerWakeFailCount", Info(.count, "Times this port controller failed to wake.")),
        (
            "PortControllerInfo.PortControllerWakeTimeoutCount",
            Info(.count, "Times waking this port controller timed out.")
        ),
        (
            "PostChargeWaitSeconds",
            Info(.seconds, "Seconds a calibration tool should let the battery settle after a full charge.")
        ),
        (
            "PostDischargeWaitSeconds",
            Info(.seconds, "Seconds a calibration tool should let the battery settle after a full discharge.")
        ),
        (
            "PowerDistribution.IPDChargingAllowed",
            Info(
                .boolean,
                "1 when the Mac lets the battery charge from the adapter; 0 on battery or while charging is paused.")
        ),
        (
            "PowerDistribution.IPDInputCurrent",
            Info(
                .milliamps,
                "Input current limit the Mac sets for the adapter; can be lower than the adapter's rated current.")
        ),
        (
            "PowerDistribution.IPDInputPower",
            Info(
                .milliwatts,
                "Input power limit, IPDInputVoltage × IPDInputCurrent; not the measured draw or the adapter rating.")
        ),
        (
            "PowerDistribution.IPDInputVoltage",
            Info(.millivolts, "Negotiated adapter voltage that the power-distribution logic budgets with.")
        ),
        (
            "PowerDistribution.IPDRatio",
            Info(
                .other,
                "Input power distribution ratio; reads 100 on every Mac sampled that reports it, charging or not.")
        ),
        (
            "PowerDistribution.IPDRatioOverride",
            Info(.other, "Override value for IPDRatio; 255 (0xFF) on every macOS 27 Mac sampled.")
        ),
        (
            "PowerDistribution.IPDWattageOverride",
            Info(
                .other,
                "Wattage override for input power distribution; 30000 on every Mac sampled, whatever the adapter.")
        ),
        (
            "PowerTelemetryData.AccumSystemEffectiveTotalLoad",
            Info(.other, "Running sum of SystemEffectiveTotalLoad samples; Macs leave it at 0.")
        ),
        (
            "PowerTelemetryData.AccumSystemEffectiveTotalLoadCount",
            Info(.count, "Number of samples added to AccumSystemEffectiveTotalLoad; Macs leave it at 0.")
        ),
        (
            "PowerTelemetryData.AccumulatedAdapterEfficiencyLoss",
            Info(.other, "Running total of AdapterEfficiencyLoss in µWh; reduce it modulo 2^32 to get the real sum.")
        ),
        (
            "PowerTelemetryData.AccumulatedBatteryDischarge",
            Info(
                .other, "Running sum of negative BatteryPower samples in mW; ÷ its count gives average discharge power."
            )
        ),
        (
            "PowerTelemetryData.AccumulatedBatteryPower",
            Info(.other, "Running sum of positive (charging) BatteryPower samples in mW; ÷ its count gives average.")
        ),
        (
            "PowerTelemetryData.AccumulatedSystemEnergyConsumed",
            Info(.other, "Running total of SystemEnergyConsumed in µWh; ignore steps of about 1193046471 (2^32 ÷ 3.6).")
        ),
        (
            "PowerTelemetryData.AccumulatedSystemLoad",
            Info(.other, "Running sum of SystemLoad samples in mW; ÷ SystemLoadAccumulatorCount gives average load.")
        ),
        (
            "PowerTelemetryData.AccumulatedSystemPowerIn",
            Info(
                .other, "Running sum of SystemPowerIn samples in mW; compare readings by their difference modulo 2^32.")
        ),
        (
            "PowerTelemetryData.AccumulatedWallEnergyEstimate",
            Info(.other, "Running total of WallEnergyEstimate: estimated µWh drawn from the wall socket.")
        ),
        (
            "PowerTelemetryData.AdapterEfficiencyLoss",
            Info(
                .microwattHoursPerSecond,
                "Estimated adapter loss over the last 1 s sample in µWh (× 3.6 = mW); negative at light load.")
        ),
        (
            "PowerTelemetryData.AdapterEfficiencyLossAccumulatorCount",
            Info(.count, "Number of samples added to AccumulatedAdapterEfficiencyLoss and the wall-energy total.")
        ),
        (
            "PowerTelemetryData.BatteryDischargeAccumulatorCount",
            Info(.count, "Number of discharging samples added to AccumulatedBatteryDischarge.")
        ),
        (
            "PowerTelemetryData.BatteryPower",
            Info(.milliwatts, "Power flowing into the battery (positive) or out of it (negative).")
        ),
        (
            "PowerTelemetryData.BatteryPowerAccumulatorCount",
            Info(.count, "Number of charging samples added to AccumulatedBatteryPower.")
        ),
        (
            "PowerTelemetryData.PowerTelemetryErrorCount",
            Info(.count, "Number of power-telemetry errors; 0 on every MacBook sampled, 84 on a Mac Studio.")
        ),
        (
            "PowerTelemetryData.SystemCurrentIn",
            Info(.milliamps, "Current flowing into the Mac from the external power adapter.")
        ),
        (
            "PowerTelemetryData.SystemEffectiveTotalLoad",
            Info(
                .other,
                "Effective total system load sample that AccumSystemEffectiveTotalLoad sums; Macs leave it at 0.")
        ),
        (
            "PowerTelemetryData.SystemEnergyConsumed",
            Info(
                .microwattHoursPerSecond,
                "Energy taken from the adapter in the last 1 s sample, in µWh (SystemPowerIn ÷ 3.6).")
        ),
        (
            "PowerTelemetryData.SystemLoad",
            Info(.milliwatts, "Power the whole Mac is using: adapter input minus battery charging power.")
        ),
        (
            "PowerTelemetryData.SystemLoadAccumulatorCount",
            Info(.count, "Number of roughly once-a-second samples added to AccumulatedSystemLoad.")
        ),
        (
            "PowerTelemetryData.SystemPowerIn",
            Info(.milliwatts, "Power entering the Mac from the adapter, after the adapter's own losses.")
        ),
        (
            "PowerTelemetryData.SystemPowerInAccumulatorCount",
            Info(.count, "Number of samples with adapter input added to AccumulatedSystemPowerIn.")
        ),
        ("PowerTelemetryData.SystemVoltageIn", Info(.millivolts, "Voltage at the Mac's power input from the adapter.")),
        (
            "PowerTelemetryData.WallEnergyEstimate",
            Info(
                .microwattHoursPerSecond,
                "Estimated wall-socket energy in the last 1 s sample, in µWh: adapter output plus adapter loss.")
        ),
        ("SMC.B0AC", Info(.milliamps, "Battery current read from the SMC; positive while charging.")),
        (
            "SMC.B0AT",
            Info(.decikelvin, "Battery gauge temperature read from the SMC, in tenths of a kelvin: 3069 is 33.75 °C.")
        ),
        ("SMC.B0AV", Info(.millivolts, "Battery pack voltage read from the SMC.")),
        ("SMC.BNCB", Info(.count, "Number of cells in series, read from the SMC.")),
        ("Serial", Info(.identifier, "Serial number of the battery pack.")),
        (
            "Temperature",
            Info(.centidegreesCelsius, "Battery temperature in hundredths of a degree Celsius: 3100 is 31 °C.")
        ),
        (
            "TimeRemaining",
            Info(
                .minutes, "Driver time estimate: time to empty on battery, time to full on power.",
                sentinels: [65535: .notAvailable])
        ),
        ("UpdateTime", Info(.unixTime, "When the driver last refreshed the battery data.")),
        (
            "UserVisiblePathUpdated",
            Info(.unixTime, "When the driver last finished its frequent poll of user-visible values.")
        ),
        (
            "VirtualTemperature",
            Info(
                .centidegreesCelsius, "Battery temperature in hundredths of a degree Celsius, as reported via the SMC.")
        ),
        ("Voltage", Info(.millivolts, "Battery pack voltage (sum of the cell voltages).")),
        ("built-in", Info(.boolean, "Marks the battery as built into the Mac.")),
    ]

    private static let familyTable: [(prefix: String, info: Info)] = [
        (
            "AppleSmartBatteryBank.BatteryData.Ra0",
            Info(
                .other,
                "Impedance at depth-of-discharge grid points 0-9 (1/1024 ohm). Every bank repeats the same values, the last bank's RaTableRaw; this bank's own are in its RaTableRaw."
            )
        ),
        (
            "AppleSmartBatteryBank.BatteryData.Ra1",
            Info(
                .other,
                "Impedance at depth-of-discharge grid points 10-14 (1/1024 ohm). Every bank repeats the same values, the last bank's RaTableRaw; this bank's own are in its RaTableRaw."
            )
        ),
        (
            "BatteryData.LifetimeData.",
            Info(
                .other,
                "Lifetime extremes and counters kept by the gauge (temperatures, currents, voltages, Qmax, FCC).")
        ),
        (
            "BatteryData.Ra0",
            Info(.other, "Cell impedance at depth-of-discharge grid points 0-9, in units of 1/1024 ohm.")
        ),
        (
            "BatteryData.Ra1",
            Info(.other, "Cell impedance at depth-of-discharge grid points 10-14, in units of 1/1024 ohm.")
        ),
        (
            "BatteryShutdownReason.ShutDown",
            Info(
                .other, "Gauge snapshot saved at the last battery-related shutdown (voltage, capacities, temperature).")
        ),
        (
            "FedDetails.Fed",
            Info(.other, "USB PD 3 details about the device last connected to this USB-C port, read from the SMC.")
        ),
        (
            "KioskMode.KioskMode",
            Info(.other, "Battery Kiosk Mode state and its counters of time spent at high charge.")
        ),
        (
            "PortControllerInfo.PortController",
            Info(
                .other, "Per-port USB-C/MagSafe port-controller telemetry the SMC publishes; one array entry per port.")
        ),
        (
            "PortControllerInfo.PortControllerIrqCnt",
            Info(.count, "Count of port-controller interrupts of one event type (plug, PD message, status change).")
        ),
        (
            "PortControllerInfo.PortControllerSlpWak",
            Info(.other, "Sleep/wake bookkeeping for the port controller (Apple sleepWakeInfo struct).")
        ),
        (
            "PowerTelemetryData.Accumulated",
            Info(
                .other,
                "Running sum of the matching once-a-second telemetry value; some totals carry spurious 2^32 jumps.")
        ),
        ("SMC.BC", Info(.millivolts, "Voltage of one series cell, read from the SMC.")),
        (
            "SMC.SBA",
            Info(.millivolts, "Voltage of one series cell, read from the SMC as a floating-point number; shown in mV.")
        ),
        (
            "SMC.TB",
            Info(.celsius, "Battery-area temperature sensor read from the SMC, in °C; TB0T sits at the hotspot.")
        ),
    ]
}

/// One raw value in the Developer table, with its meaning and decoded form.
public struct RawRow: Sendable, Identifiable, Equatable {
    public var id: String
    /// Path inside its dictionary, with array indices (`UsbHvcMenu[2].MaxVoltage`).
    public var path: String
    /// Glossary key (``RawKeyGlossary/canonicalKey(captureKey:path:)``).
    public var key: String
    public var property: PropertyValue
    public var info: RawKeyGlossary.Info?
    public var decoded: DecodedRawValue?

    public var value: String { property.description }
}

/// One raw dictionary of the Developer table.
public struct RawSection: Sendable, Identifiable, Equatable {
    /// The ``BatteryReading/CaptureKey`` of the dictionary.
    public var id: String
    /// The API the dictionary comes from, shown verbatim.
    public var title: String
    public var rows: [RawRow]

    /// Sections for a raw capture, in a fixed order, skipping empty dictionaries:
    /// `AppleSmartBattery`, one section per child entry below it, IOPS, the adapter and the SMC.
    public static func sections(for capture: PropertyDictionary) -> [RawSection] {
        RawSectionSource.sources(for: capture).compactMap { $0.section() }
    }

    /// `glossaryPrefix` is the class of a child entry: its keys are looked up as
    /// `AppleSmartBatteryPack.BatteryData.Amperage` first and then as the same path on
    /// `AppleSmartBattery`.
    fileprivate static func section(
        _ dictionary: PropertyDictionary, id: String, title: String, glossaryPrefix: String? = nil
    ) -> RawSection? {
        guard !dictionary.isEmpty else { return nil }
        let rows = RawEntry.flatten(dictionary).map { entry in
            let plainKey = RawKeyGlossary.canonicalKey(captureKey: glossaryPrefix == nil ? id : "", path: entry.path)
            let prefixedKey = glossaryPrefix.map { $0 + "." + plainKey }
            let info = prefixedKey.flatMap(RawKeyGlossary.info(for:)) ?? RawKeyGlossary.info(for: plainKey)
            return row(id: id, path: entry.path, key: prefixedKey ?? plainKey, property: entry.property, info: info)
        }
        return RawSection(id: id, title: title, rows: rows)
    }

    /// One row per SMC key, valued as a number in the key's own unit.
    fileprivate static func smcSection(_ smc: PropertyDictionary) -> RawSection? {
        let rows = SMCBattery.values(in: smc).map { value in
            let name = value.key.description
            let key = "SMC." + name
            let property: PropertyValue =
                SMCBattery.displayNumber(value).map { number in
                    number.rounded() == number && abs(number) < 1e15 ? .int(Int64(number)) : .double(number)
                } ?? .data(Data(value.payload))
            return row(
                id: BatteryReading.CaptureKey.smc, path: name, key: key, property: property,
                info: RawKeyGlossary.info(for: key))
        }
        guard !rows.isEmpty else { return nil }
        return RawSection(id: BatteryReading.CaptureKey.smc, title: "AppleSMC", rows: rows)
    }

    private static func row(
        id: String, path: String, key: String, property: PropertyValue, info: RawKeyGlossary.Info?
    ) -> RawRow {
        RawRow(
            id: id + ":" + path,
            path: path,
            key: key,
            property: property,
            info: info,
            decoded: info.flatMap { RawValueDecoder.decode(property, as: $0.kind, sentinels: $0.sentinels) }
        )
    }
}

/// One dictionary of a raw capture before its rows are built: the source of one section of the
/// Developer table. ``RawDisplayTable`` compares sources to build again only the sections whose
/// dictionary changed.
struct RawSectionSource: Sendable, Equatable {
    /// How the dictionary's keys are looked up in the glossary.
    enum Kind: Sendable, Equatable {
        /// A dictionary of the capture itself: its keys under its capture key.
        case capture
        /// An entry below `AppleSmartBattery`: its keys under its class first.
        case child(className: String)
        /// The SMC's battery keys, one row per key.
        case smc
    }

    /// The ``RawSection/id`` of the section it becomes.
    var id: String
    /// The ``RawSection/title``, which numbers entries of a class that repeats.
    var title: String
    var dictionary: PropertyDictionary
    var kind: Kind

    /// The sources of ``RawSection/sections(for:)``, in its order, without the empty dictionaries.
    static func sources(for capture: PropertyDictionary) -> [RawSectionSource] {
        var sources: [RawSectionSource] = []
        if var smartBattery = capture[BatteryReading.CaptureKey.smartBattery]?.dictionaryValue {
            let children = RegistryChildren.entries(in: smartBattery)
            smartBattery[RegistryChildren.childrenKey] = nil
            sources.append(
                RawSectionSource(
                    id: BatteryReading.CaptureKey.smartBattery, title: "AppleSmartBattery", dictionary: smartBattery,
                    kind: .capture))
            let counts = Dictionary(children.map { ($0.className, 1) }, uniquingKeysWith: +)
            var seen: [String: Int] = [:]
            for child in children {
                seen[child.className, default: 0] += 1
                // Banks repeat once per cell, so number them in registry order.
                let ordinal = seen[child.className] ?? 1
                let title = (counts[child.className] ?? 0) > 1 ? "\(child.className) \(ordinal)" : child.className
                let id =
                    BatteryReading.CaptureKey.smartBattery + "/" + child.path.joined(separator: "/") + "#\(ordinal)"
                sources.append(
                    RawSectionSource(
                        id: id, title: title, dictionary: child.properties, kind: .child(className: child.className)))
            }
        }
        let captureSources = [
            (BatteryReading.CaptureKey.powerSource, "IOPowerSources"),
            (BatteryReading.CaptureKey.adapterDetails, "IOPSCopyExternalPowerAdapterDetails"),
        ]
        for (captureKey, title) in captureSources {
            sources.append(
                RawSectionSource(
                    id: captureKey, title: title, dictionary: capture[captureKey]?.dictionaryValue ?? [:],
                    kind: .capture))
        }
        if let smc = capture[BatteryReading.CaptureKey.smc]?.dictionaryValue {
            sources.append(
                RawSectionSource(id: BatteryReading.CaptureKey.smc, title: "AppleSMC", dictionary: smc, kind: .smc))
        }
        return sources.filter { !$0.dictionary.isEmpty }
    }

    /// The section with the dictionary's rows; `nil` when it has none.
    func section() -> RawSection? {
        switch kind {
        case .capture: RawSection.section(dictionary, id: id, title: title)
        case .child(let className): RawSection.section(dictionary, id: id, title: title, glossaryPrefix: className)
        case .smc: RawSection.smcSection(dictionary)
        }
    }
}

/// A row of the Developer table with every text it shows, built once per reading, so neither the
/// cells nor the filter format a value or look up a translation.
public struct RawDisplayRow: Sendable, Identifiable, Equatable {
    /// The ``RawRow/id``.
    public let id: String
    /// The ``RawRow/path``.
    public let path: String
    /// The ``RawRow/value``.
    public let value: String
    /// The decoded value in the app's wording; `nil` for a key without a decoding.
    public let decoded: String?
    /// The glossary's summary in the app's language; `nil` for a key the glossary lacks.
    public let summary: String?
    /// The glossary's English summary, which the filter searches too.
    public let englishSummary: String?
    /// Everything the filter searches, one text per line.
    public let searchText: String

    /// `decoded` and `summary` word a decoded value and translate an English summary.
    public init(_ row: RawRow, decoded: (DecodedRawValue) -> String, summary: (String) -> String) {
        id = row.id
        path = row.path
        value = row.value
        self.decoded = row.decoded.map(decoded)
        englishSummary = row.info?.summary
        self.summary = englishSummary.map(summary)
        searchText = [path, value, self.decoded, englishSummary, self.summary].compactMap { $0 }.joined(
            separator: "\n")
    }

    /// Whether the key, the value, the decoded value or a summary contains `query`, ignoring case
    /// but not diacritics, which tell Russian letters apart (U+0438 and U+0439, U+0435 and U+0451).
    ///
    /// One search over the joined text finds what searching each text on its own finds, since
    /// a match can't run across a line break that the query lacks. A query with a line break,
    /// which only pasting can enter, searches each text on its own.
    public func matches(_ query: String) -> Bool {
        guard query.contains(where: \.isNewline) else { return searchText.localizedCaseInsensitiveContains(query) }
        return [path, value, decoded, englishSummary, summary].contains {
            $0?.localizedCaseInsensitiveContains(query) ?? false
        }
    }
}

/// One dictionary of the Developer table, with its rows' text.
public struct RawDisplaySection: Sendable, Identifiable, Equatable {
    /// The ``RawSection/id``.
    public let id: String
    /// The ``RawSection/title``.
    public let title: String
    public var rows: [RawDisplayRow]

    public init(_ section: RawSection, decoded: (DecodedRawValue) -> String, summary: (String) -> String) {
        id = section.id
        title = section.title
        rows = section.rows.map { RawDisplayRow($0, decoded: decoded, summary: summary) }
    }

    /// The table for a raw capture: ``RawSection/sections(for:)`` with every row's text.
    public static func sections(
        for capture: PropertyDictionary, decoded: (DecodedRawValue) -> String, summary: (String) -> String
    ) -> [RawDisplaySection] {
        RawSection.sections(for: capture).map { RawDisplaySection($0, decoded: decoded, summary: summary) }
    }

    /// The rows of `sections` that match `query` (``RawDisplayRow/matches(_:)``), without the
    /// sections left empty. A query of spaces, or none, keeps everything.
    public static func filter(_ sections: [RawDisplaySection], by query: String) -> [RawDisplaySection] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return sections }
        return sections.compactMap { section in
            var section = section
            section.rows = section.rows.filter { $0.matches(query) }
            return section.rows.isEmpty ? nil : section
        }
    }
}

/// The Developer table kept from one reading to the next, so that a reading builds again only the
/// sections whose dictionary changed (E19). A poll changes the live values of the registry and
/// the SMC; the adapter's and IOPS's dictionaries rarely change, and an unchanged section keeps
/// its rows, which also makes comparing it with the table on screen cheap. Built off the main
/// actor, like the sections it holds.
public struct RawDisplayTable: Sendable {
    /// A built section and the source it was built from.
    private struct Entry: Sendable {
        var source: RawSectionSource
        /// `nil` for a source without rows.
        var section: RawDisplaySection?
    }

    /// The table, as ``RawDisplaySection/sections(for:decoded:summary:)`` builds it for the
    /// capture of the last ``update(for:wording:decoded:summary:)``.
    public private(set) var sections: [RawDisplaySection] = []
    /// What the last update built or kept, by section id.
    private var entries: [String: Entry] = [:]
    /// The wording of the last update.
    private var wording: String?

    /// An empty table.
    public init() {}

    /// The table for `capture`. A section whose id, title and dictionary are what the last update
    /// saw keeps its rows; the others are built again with `decoded` and `summary`. `wording`
    /// names what else the rows' text depends on, such as the locale and the time zone: when it
    /// changes, every section is built again. Returns how many sections were built.
    @discardableResult
    public mutating func update(
        for capture: PropertyDictionary, wording: String, decoded: (DecodedRawValue) -> String,
        summary: (String) -> String
    ) -> Int {
        if wording != self.wording {
            entries = [:]
            self.wording = wording
        }
        var built = 0
        var kept: [String: Entry] = [:]
        var sections: [RawDisplaySection] = []
        for source in RawSectionSource.sources(for: capture) {
            let entry: Entry
            if let previous = entries[source.id], previous.source == source {
                entry = previous
            } else {
                let section = source.section().map { RawDisplaySection($0, decoded: decoded, summary: summary) }
                entry = Entry(source: source, section: section)
                built += 1
            }
            kept[source.id] = entry
            if let section = entry.section { sections.append(section) }
        }
        entries = kept
        self.sections = sections
        return built
    }
}
