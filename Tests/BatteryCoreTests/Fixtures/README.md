# Test fixtures

Raw captures in the `bpulse --raw` format (serial numbers redacted).

| File | Source |
|------|--------|
| `m5-macos27-on-battery.plist` | Real: MacBook Air M5, macOS 27, on battery at 70 % |
| `m5-macos27-charging.plist` | Real: same Mac a minute later, charging from a 60 W adapter |
| `m5-macos27-on-battery-smc.plist` | Real: same Mac with BatteryPulse 0.3 (Raw Data → Export Capture), on battery at 47 %: also has the pack, bank, cell and charger entries below AppleSmartBattery and the SMC's battery keys |
| `synthetic-legacy-*.plist` | Hand-written pre-macOS 27 Apple Silicon layout; covers fallback keys |

To add a capture: `swift run bpulse --raw > Tests/BatteryCoreTests/Fixtures/<model>-<os>-<state>.plist`,
then add a case to `Fixture.swift`.
