## What's new in 0.3

- **Temperature and cells**: the battery's temperature on the Power page, in the compact window,
  the widget and History, and the voltage of each cell on the Health page.
- **History**: charge, power and temperature over the last 24 hours or 7 days, with the average
  drain, time on battery, energy from the battery and charging sessions; capacity and cycle
  count day by day.
- **Notifications** when the battery reaches a charge level, runs low, needs service, or the
  Mac gets hot (Settings → Notifications; all off until you turn them on).
- **Widget** for the desktop and Notification Center, in two sizes. It's experimental until
  BatteryPulse is notarized: if it doesn't show up in Edit Widgets, please open an issue.
- **Compact window**: a small window with just the essentials.
- **Raw Data inspector** and sections for the battery pack, each cell, the charger and the SMC.
- **Update check** once a day (Settings → General), and a What's New window after updating.

## Install

Requires a Mac with Apple silicon and macOS 27 or later.

1. Download **BatteryPulse.dmg** below and open it.
2. Drag **BatteryPulse** onto **Applications**.
3. Open BatteryPulse from Applications.

### First launch

BatteryPulse is not notarized by Apple yet, so macOS blocks it the first time you open it:

1. When macOS says it can't verify BatteryPulse, click **Done** (not *Move to Trash*).
2. Open **System Settings → Privacy & Security** and scroll down to **Security**.
3. Next to *"BatteryPulse" was blocked to protect your Mac*, click **Open Anyway** and confirm
   with your password or Touch ID.

Until BatteryPulse is notarized, you need to do this once for each new version you download;
after that it opens normally.

See the [User Guide](https://github.com/NikitaUsov/BatteryPulse/blob/main/docs/USER_GUIDE.md)
for everything else.
