// The widget's identifiers and choices, mirrored in BatteryCore so their decisions are tested on
// Linux: BatteryCore can't import WidgetKit or App Intents, so the widget target maps each of
// these one to one to its `WidgetFamily` or `AppEnum`.
//
// Every raw value is frozen once a release ships it: macOS stores a placed widget's kind and
// configuration under these strings, so renaming or removing one resets or removes placed
// widgets. Only the cases that ship are declared; a case is cut before a release candidate,
// never after. `WidgetSurfaceTests` pins them.

/// A widget family, by its size.
public enum WidgetSize: String, Sendable, CaseIterable {
    case small, medium, large, extraLarge, extraLargePortrait
}

/// A widget kind: the string WidgetKit stores for every placed widget of the kind.
public enum WidgetKindID: String, Sendable, CaseIterable {
    /// Today's kind, so widgets placed by 0.6.x stay.
    case battery = "io.github.nikitausov.BatteryPulse.battery"
    case accessories = "io.github.nikitausov.BatteryPulse.accessories"
}

/// A detail the Battery widget can show.
public enum BatteryWidgetField: String, Sendable, CaseIterable {
    /// Charging, On battery, Fully charged, Charging on hold or Not charging.
    case state
    /// The time to full or to empty.
    case time
    /// Capped at 100 % like System Settings.
    case maximumCapacity
    /// The condition macOS reports; "Normal" without one.
    case condition
    case cycleCount
    /// The pack's sensor: the sandboxed widget can't open the SMC.
    case temperature
    /// The adapter's rated watts.
    case adapter
    /// How hard the Mac is working, on and off power ("System load").
    case systemLoad
    /// Into (+) or out of (−) the battery; stale between reloads, so shown with the reading's time.
    case batteryPower
    /// What the adapter delivers ("Power from adapter").
    case adapterInput
    case lowPowerMode
    /// The remaining charge in mAh.
    case remainingCapacity
    /// The share of the rated cycle count used.
    case cycleLifeUsed
    /// The spread between the highest and lowest cell voltage.
    case cellBalance
    case voltage
}

/// The value the Battery widget shows large.
public enum BatteryWidgetMain: String, Sendable, CaseIterable {
    case charge, maximumCapacity, temperature, batteryPower
}

/// How the main value is drawn.
public enum BatteryWidgetVisual: String, Sendable, CaseIterable {
    /// The number with the level symbol, as in 0.6.x.
    case symbol
    /// The number inside a ring.
    case ring
    /// A battery drawn like the menu bar's Modern style.
    case drawnBattery
}

/// Automatic shows a size's own details (``WidgetLayoutPlan/automatic(_:)``); Custom shows the
/// chosen ones.
public enum WidgetLayoutMode: String, Sendable, CaseIterable {
    case automatic, custom
}

/// A line under the main value.
public enum WidgetStatusLine: String, Sendable, CaseIterable {
    case state, time
}

/// How the time to full or empty reads.
public enum WidgetTimeStyle: String, Sendable, CaseIterable {
    /// "Lasts until about 16:39".
    case clockTime
    /// "2 hours, 13 minutes", counting down without reloads.
    case timeLeft
}

/// Whether tiers show in colour: level colours as in 0.6.x, or none. A tier that isn't normal
/// also carries a ``WidgetCue`` in either style.
public enum WidgetColorStyle: String, Sendable, CaseIterable {
    case levelColors, monochrome
}

/// When the reading's time ("Updated 14:05") shows.
public enum WidgetUpdateTimeStyle: String, Sendable, CaseIterable {
    /// Once the reading is old: from the timeline's stale entry on.
    case whenOld
    case always
}

/// Which accessories the Accessories widget lists.
public enum AccessoryWidgetMode: String, Sendable, CaseIterable {
    /// Every accessory, lowest first.
    case all
    case lowest
}
