# Test fixtures

Raw captures in the `bpulse --raw` format (serial numbers redacted).

| File | Source |
|------|--------|
| `m5-macos27-on-battery.plist` | Real: MacBook Air M5, macOS 27, on battery at 70 % |
| `m5-macos27-charging.plist` | Real: same Mac a minute later, charging from a 60 W adapter |
| `m5-macos27-on-battery-smc.plist` | Real: same Mac with BatteryPulse 0.3 (Raw Data → Export Capture), on battery at 47 %: also has the pack, bank, cell and charger entries below AppleSmartBattery and the SMC's battery keys |
| `m5-macos27-plugged-in-10s.plist` | Real: same Mac 10 s after plugging in a 35 W adapter; IOPS and the registry still say "not charging" with the old discharge current, while the SMC's `B0AC` already reads +1898 mA |
| `m5-macos27-unplugged.plist` | Real: same Mac just after unplugging; the registry still shows +250 mA, the SMC −562 mA |
| `iphone17promax-ios27.0.1-usb.plist` | Real: iPhone 17 Pro Max (iPhone18,2), iOS 27.0.1, over USB while charging from a 15 W adapter (`bpulse --device 1 --raw`); its Settings showed Maximum Capacity 95 %, 278 cycles, first use October 2025. The pack's `UUID` was redacted by hand |
| `synthetic-legacy-*.plist` | Hand-written pre-macOS 27 Apple Silicon layout; covers fallback keys |

To add a capture: `swift run bpulse --raw > Tests/BatteryCoreTests/Fixtures/<model>-<os>-<state>.plist`,
then add a case to `Fixture.swift`.
To catch a transition (plugging in, the Charge Limit stop), use `bpulse --record <folder>` and pick the capture.
