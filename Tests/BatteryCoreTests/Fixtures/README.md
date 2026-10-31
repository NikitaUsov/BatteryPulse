# Test fixtures

Raw captures in the `bpulse --raw` format (serial numbers redacted).

| File | Source |
|------|--------|
| `m5-macos27-on-battery.plist` | Real: MacBook Air M5, macOS 27, on battery at 70 % |
| `m5-macos27-charging.plist` | Real: same Mac a minute later, charging from a 60 W adapter |
| `m5-macos27-on-battery-smc.plist` | Real: same Mac with BatteryPulse 0.3 (Raw Data → Export Capture), on battery at 47 %: also has the pack, bank, cell and charger entries below AppleSmartBattery and the SMC's battery keys |
| `m5-macos27-plugged-in-10s.plist` | Real: same Mac 10 s after plugging in a 35 W adapter; IOPS and the registry still say "not charging" with the old discharge current, while the SMC's `B0AC` already reads +1898 mA |
| `m5-macos27-unplugged.plist` | Real: same Mac just after unplugging; the registry still shows +250 mA, the SMC −562 mA |
| `m5-macos27-charge-limit.plist` | Real: same Mac on a 35 W adapter at 80 %, held by the Charge Limit set to 80 % in System Settings → Battery: `NotChargingReason` 0x01000000 (bit 24) in AppleSmartBattery's `ChargerData` and in its AppleChargerData child, `IsCharging` false, no charge current, `FullyCharged` false. No key holds the limit itself. Serials, `ManufacturerData` and `MfgData` redacted |
| `iphone17promax-ios27.0.1-usb.plist` | Real: iPhone 17 Pro Max (iPhone18,2), iOS 27.0.1, over USB while charging from a 15 W adapter (`bpulse --device 1 --raw`); its Settings showed Maximum Capacity 95 %, 278 cycles, first use October 2025. The pack's `UUID` was redacted by hand |
| `synthetic-legacy-*.plist` | Hand-written pre-macOS 27 Apple Silicon layout; covers fallback keys |
| `diskutil/info-apfs-macos27.plist` | Real: `diskutil info -plist` of the DMG mounted by CI's install step (macOS 27 runner, run 40039004378): its APFS volume on the synthesized container `disk18`, whose physical store `disk17s1` is on the image's own disk. Not a battery capture, so it sits in a folder of its own, out of the fixture loop that renders every capture |
| `synthetic-accessories.plist` | Hand-written accessory capture (`bpulse --accessories --raw` format, `AccessoryFixture.swift`): the power source keys macOS publishes for accessories, made-up names and identifiers; covers grouping, parts, kinds and the sources that are dropped |

To add a capture: `swift run bpulse --raw > Tests/BatteryCoreTests/Fixtures/<model>-<os>-<state>.plist`,
then add a case to `Fixture.swift`.
To catch a transition (plugging in, the Charge Limit stop), use `bpulse --record <folder>` and pick the capture.
For accessories:
`swift run bpulse --accessories --raw > Tests/BatteryCoreTests/Fixtures/<model>-<os>-accessories-<setup>.plist`
(names and identifiers are already pseudonyms; check that no real name is left), then add a case
to `AccessoryFixture.swift`, not to `Fixture`, whose cases are Mac captures.
