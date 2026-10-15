/// The kinds of dictionary in the Developer table, for the section switch in its toolbar.
///
/// One choice per kind, in table order, so the bank and cell entries (two to three banks, each
/// with its cells) share a choice instead of taking one each. The app names the choices; the
/// grouping lives here so it is tested against real captures.
public enum RawSectionGroup: String, Sendable, Hashable, CaseIterable {
    /// `AppleSmartBattery` itself, and any entry below it that is none of the ones below.
    case battery
    /// `AppleSmartBatteryPack`.
    case pack
    /// The `AppleSmartBatteryBank` entries and the cells below them.
    case banks
    /// `AppleChargerData`.
    case charger
    /// `IOPowerSources`.
    case powerSources
    /// `IOPSCopyExternalPowerAdapterDetails`.
    case adapter
    /// The SMC's battery keys.
    case smc

    /// The group of a ``RawSection`` by its ``RawSection/id``; `nil` for an id that
    /// ``RawSection/sections(for:)`` doesn't make.
    public init?(sectionID id: String) {
        switch id {
        case BatteryReading.CaptureKey.smartBattery: self = .battery
        case BatteryReading.CaptureKey.powerSource: self = .powerSources
        case BatteryReading.CaptureKey.adapterDetails: self = .adapter
        case BatteryReading.CaptureKey.smc: self = .smc
        default:
            // A child entry: `AppleSmartBattery/<class>/<class>…#<ordinal>`.
            let prefix = BatteryReading.CaptureKey.smartBattery + "/"
            guard id.hasPrefix(prefix) else { return nil }
            let path = id.dropFirst(prefix.count).split(separator: "#").first ?? ""
            let classes = Set(path.split(separator: "/").map(String.init))
            if classes.contains(RegistryChildren.bankClass) {
                self = .banks
            } else if classes.contains(RegistryChildren.chargerClass) {
                self = .charger
            } else if classes.contains(RegistryChildren.packClass) {
                self = .pack
            } else {
                self = .battery
            }
        }
    }

    /// The groups that have at least one of `sections`, in table order.
    public static func groups(in sections: [RawSection]) -> [RawSectionGroup] {
        let present = Set(sections.compactMap { RawSectionGroup(sectionID: $0.id) })
        return allCases.filter(present.contains)
    }

    /// The sections of `group`, in their order; every section for `nil`.
    public static func sections(_ sections: [RawSection], in group: RawSectionGroup?) -> [RawSection] {
        guard let group else { return sections }
        return sections.filter { RawSectionGroup(sectionID: $0.id) == group }
    }
}
