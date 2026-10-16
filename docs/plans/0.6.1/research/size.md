# BatteryPulse 0.6.1: app size, build configuration and code footprint (verified)

Date: 2026-10-15. This is the adversarially verified version of `v061/size/research.md`. It stands on its own.
Scope: the shipped DMG, the app and widget binaries, resources, compiler and linker settings, and a CI size gate.
Every recommendation uses only Apple's or the Swift project's own tools.

Labels:
- **[measured]**: measured on the real v0.5.0 artifacts or a Linux build with Swift 6.4.1.
- **[verified 6.4.1]**: checked against the installed Swift 6.4.1 toolchain or the Swift Build / SwiftPM 6.4.1
  build request and PIF.
- **[source]**: read in Apple's or the Swift project's source or documentation, cited inline.
- **[unverified macOS 27]**: must be confirmed on the `xcode-27` runner or the maintainer's Mac.

Working files are in `scratchpad/v061/size/`: the researcher's `tools/`, `exp/`, `strip/` and `x050/` (the
unpacked v0.5.0 DMG), plus the verifier's `verify/`. The verifier's files are the fetched ld64, Swift Build and
`strip(1)` sources, a SwiftPM probe package (`verify/pkg`) and the WWDC26 transcripts in `verify/tr`.

---

## Verdict summary

| ID | Change | Verdict | Prio |
|---|---|---|---|
| SZ-01 | Ship stripped app and widget binaries, keep dSYMs | **Kept, corrected.** SwiftPM's Release configuration already asks for dSYMs (`dwarf-with-dsym`), so first look for them in the bin path. SwiftPM itself turns stripping off. | **P0** |
| SZ-02 | Export only `_main` from both executables | **Kept, mechanism corrected.** The effect is real: unreachable public code is in the shipped widget. The cited reason is not what ld64's own source does for executables. It needs a link-line check and a `-why_live` check on the runner. | **P0** |
| SZ-03 | DMG as ULMO (LZMA) | **Kept.** The −38 % figure was reproduced. The made-up `lzma-level` key is dropped. Use the documented convert path to get a compact file. | **P0** |
| SZ-04 | CI size report and budget | **Kept, simplified.** It needs `GH_TOKEN`. The "+15 % unless the budget changed in the same PR" rule is dropped; the budget file is the only gate. | **P0** |
| SZ-05 | `-Osize` for the app and widget | **Kept, sources corrected.** Apple's `-Os` default is the Clang setting; Swift's Release default is `-O` + WMO. Verify with Instruments 27 Run Comparisons. | P1 |
| SZ-06 | Size-attribution tooling | **Kept.** The flags exist in 6.4.1. Note that Linux release builds already dead-strip unused public code, so Linux is no proxy for the macOS export issue. | P1 |
| SZ-07 | No English `.strings` table | **Kept.** 630 of 630 entries are identity. The download gain under ULMO is only ~4 KB; installed −157 KB. | P2 |
| SZ-08 | Glossary table as data | Kept as P3. | P3 |
| SZ-09 | Bundle hygiene assertions | Kept, folded into SZ-04. | P2 |
| SZ-10 | Icon Composer icon through `actool` | Kept as a nativeness item, with an `.icns` note added. Flags unverified. | P2 |
| SZ-11 | LTO, conditional runtime records, hermetic seal | Kept as one experiment, setting names corrected. | P3 (experiment) |
| SZ-12 | Do not disable reflection metadata | **Kept, one code reference corrected.** | not recommended |
| SZ-13 | Do not move shared code into an embedded dynamic framework | Kept. | not recommended |
| SZ-14 | **New:** `-dead_strip_dylibs` for the widget after SZ-02 | Optional measurement in the same CI run. | P3 |

Combined estimate after SZ-01, SZ-02, SZ-03 and SZ-05, to be measured by SZ-04. Functionality is unchanged.
- App binary: 5.40 MB → about 2.0 MB.
- Widget binary: 2.05 MB → about 0.6–0.8 MB.
- Installed `.app`: 8.05 MB → about 3.2–3.5 MB.
- DMG: 2.68 MB → about 1.0–1.15 MB. With SZ-01 + SZ-03 alone the LZMA payload is 1,105,943 B [measured estimate].

---

## 0. Baseline (v0.5.0), re-checked

All numbers below were re-measured by the verifier on `dl050/BatteryPulse.dmg` and `x050/`.

- **DMG:** 2,677,709 B, UDZO (zlib level 1), APFS, GPT layout with 8 `blkx` partitions.
  - UDIF data fork: 2,668,751 B.
  - XML plist: 8,446 B, plus the 512 B `koly` trailer.
- **Unreferenced data in the image [measured, confirmed]:**
  - Zlib chunks referenced by the `blkx` tables: 2,498,951 B.
  - One region of **169,797 B** at offset 495,397 is not referenced by any chunk. It starts with a 36-byte zlib
    stream that inflates to 3,072 B, followed by non-zlib data.
  - It is dead weight left by `hdiutil create` (6 % of the file).
- **Bundle:** 8,049,334 B in total (the research said 8,049,348).
  - `MacOS/BatteryPulse`: 5,403,776 B.
  - The widget executable: 2,050,752 B.
  - `AppIcon.icns`: 215,181 B.
  - The `en` and `ru` `Localizable.strings` (78,484 B and 107,028 B), shipped twice: once in the app, once in the appex.
- **App binary [measured]:**
  - 57,767 symbols, of which 39,376 are STABS debug-map entries.
  - 66 `OSO` entries pointing at
    `/Users/runner/work/BatteryPulse/BatteryPulse/.build/out/Intermediates.noindex/BatteryPulse.build/Release/...`.
  - Export trie: 64,072 B. Chained fixups: 98,848 B.
  - `LC_BUILD_VERSION`: minos 27.0, sdk 27.0.
- **Exports [measured]:** both binaries export the same 2,709 symbols (`exports-app.txt` and
  `exports-widget.txt` are byte-identical).
- **Unreachable code in the widget [measured, new evidence]:** the widget defines these as `external`:
  - `static BatteryCore.RawSection.sections(for:)`. Its only caller is
    `Sources/BatteryPulseApp/Main/DeveloperView.swift:122`.
  - `static BatteryCore.RawKeyGlossary.canonicalKey(captureKey:path:)`. Its only caller is
    `RawKeyGlossary.swift:1179`, inside `sections(for:)`.

  Neither is a protocol witness or a vtable entry. Every class in BatteryCore and BatteryKit is `final` or an
  actor, so no vtable keeps methods alive. Nothing reachable from the widget's `_main` calls them.
- **Dylibs loaded by the widget [measured]:**
  - Frameworks: Foundation, CoreFoundation, **CryptoKit**, IOKit, SwiftUI, Symbols, WidgetKit.
  - 19 `libswift*` overlays.

  CryptoKit comes only from BatteryKit's `UpdateSignatureVerifier`, which the widget never calls.

### 0.1 What SwiftPM 6.4.1 actually configures [verified 6.4.1]

These were read from the build request and the PIF that SwiftPM hands to Swift Build. They were checked in a
Linux build of this repository (`review050/build/manifest.pif`) and in a release probe package (`verify/pkg`).
The overrides are not platform-specific, but confirm the macOS link line on the runner.

- **Build request overrides** (all configurations): `DEAD_CODE_STRIPPING = YES` and
  `STRIP_INSTALLED_PRODUCT = NO`.
  - `--enable-experimental-strip-products` flips the second to `YES`. On Linux it then ran `strip -D` on the
    product.
- **Release configuration** in the PIF:
  - `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`;
  - `DEPLOYMENT_POSTPROCESSING = YES`;
  - `COPY_PHASE_STRIP = YES` (copy phases only, which SwiftPM doesn't use);
  - `SWIFT_OPTIMIZATION_LEVEL = -Owholemodule`.
- **Global symbol export.** `LD_EXPORT_GLOBAL_SYMBOLS` (`-Xclang-linker -rdynamic`, which is `-export_dynamic`
  on Darwin) is turned on only when testability is enabled. Source: swift-build
  `Sources/SWBCore/Settings/Settings.swift`, the `ENABLE_TESTABILITY` block, "So symbols are available for testing
  even when LTO is enabled".
  - Debug Linux links of this repository carry `-rdynamic`. A release probe link carries only
    `-Xlinker --gc-sections`.
  - In that release probe, an unused `public` function was present in `Lib.o` and absent from the executable.
- **Swift Build's spec defaults** (https://github.com/swiftlang/swift-build, `main`, fetched 2026-10-15):
  - `DEAD_CODE_STRIPPING` defaults to `NO` (`CoreBuildSystem.xcspec`). SwiftPM's override turns it on, and
    `Ld.xcspec` then passes `-Xlinker -dead_strip` (Darwin); `UnixLd.xcspec` passes `--gc-sections` (Linux).
  - `LD_EXPORT_SYMBOLS` defaults to `YES`; `NO` maps to `-Xlinker -no_exported_symbols` (`Ld.xcspec`).

---

## 1. Recommendations

### SZ-01: Ship stripped binaries, keep dSYMs (P0, S)

- **Practice.** Ship stripped executables and keep the debug information in `.dSYM` bundles tied by UUID, as
  Xcode does for a distributed app.
- **Why.**
  - Apple, Build settings reference (https://developer.apple.com/documentation/xcode/build-settings-reference,
    fetched 2026-10-15):
    - `STRIP_INSTALLED_PRODUCT`: "the linked product of the build will be stripped of symbols when performing
      deployment postprocessing".
    - `STRIP_STYLE` "All Symbols: Completely strips the binary, removing the symbol table and relocation
      information".
  - Apple, "Building your app to include debugging information"
    (https://developer.apple.com/documentation/xcode/building-your-app-to-include-debugging-information): the
    binary and its dSYM "are tied together by a build UUID", and Debug Information Format should be "DWARF with
    dSYM File".
  - `ld(1)` `-x`: non-global symbols "are useful when debugging and getting symbol names in back traces, but are
    not used at runtime" (ld64-820.1 `doc/man/man1/ld.1`).
  - `strip(1)` (cctools, https://github.com/apple-oss-distributions/cctools/blob/main/man/strip.1): with no
    options on an executable that uses the dynamic linker, "the effect … is the same as using the -u and -r
    options". That keeps undefined symbols and symbols referenced dynamically.
- **What is wrong today.**
  - SwiftPM forces `STRIP_INSTALLED_PRODUCT = NO` (§0.1).
  - `scripts/build-app.sh` copies `$BIN_PATH/BatteryPulse` and `$BIN_PATH/BatteryPulseWidget` unstripped
    (`cp "$BINARY" …`, `cp "$BIN_PATH/BatteryPulseWidget" "$WIDGET"`).
  - So the DMG ships the debug map and the CI runner's absolute paths (133 `/Users/runner` strings in the app
    binary, 0 after stripping) [measured].
- **Measured effect** (llvm-objcopy on the v0.5.0 binaries; Apple `strip` keeps `__mh_execute_header` and the
  undefined symbols, a few KB more):

| Binary | as shipped | `-S` | `-x` | all |
|---|---:|---:|---:|---:|
| App | 5,403,776 | 4,754,384 | 2,415,072 | **2,212,624** |
| Widget | 2,050,752 | 1,693,792 | 1,236,496 | **1,039,360** |

- **How** (`scripts/build-app.sh`):
  1. **dSYMs first.**
     - Swift Build's Release configuration already says `dwarf-with-dsym` (§0.1), so the `.dSYM` bundles probably
       already sit next to the products: `ls "$BIN_PATH"/*.dSYM` **[unverified macOS 27]**.
     - If they are there, use them. Otherwise run `xcrun dsymutil "$BIN_PATH/BatteryPulse" -o
       build/BatteryPulse.app.dSYM`, and the same for the widget. The unstripped `.build` binaries still point at
       their `.o` files.
  2. Keep the existing `nm` checks, but **run them on `$BIN_PATH/…`, never on the bundle copies**. Verified:
     - after a full strip, `BatteryPulseWidget.BatteryPulseWidgets` is gone (0 matches);
     - only the undefined `_NSExtensionMain` import survives (`strip/BatteryPulseWidget.strip-all`).
  3. After `cp` into the bundle and **before** `codesign`, run `xcrun strip "$APP/Contents/MacOS/BatteryPulse"`
     and `xcrun strip "$WIDGET"`. If anything misbehaves, `strip -x` costs about +0.2 MB.
  4. Do not use `-Xlinker -S` instead. It drops the debug map, so `dsymutil` would have nothing to read.
  5. Distribute the dSYMs:
     - `release.yml`: zip them as `BatteryPulse-dSYMs.zip` and attach the zip to the release.
     - `ci.yml`: upload them as an artifact.
     - They contain symbol names, line tables and runner paths of a public GPL project.
- **Alternative, closest to Xcode.** `swift build -c release --enable-experimental-strip-products` sets
  `STRIP_INSTALLED_PRODUCT = YES` [verified 6.4.1].
  - Drawbacks: it is experimental, its macOS ordering against dSYM generation is **[unverified macOS 27]**, and it
    strips `$BIN_PATH` itself, which breaks the WidgetBundle `nm` check.
  - Prefer the explicit steps above.
- **Verify.**
  - SZ-04 numbers before and after.
  - `dwarfdump --uuid` on each binary and its dSYM: the UUIDs match.
  - `codesign --verify --strict --deep` (already in the script).
  - Launch the app; add the widget; run one in-app update with the RC.
  - `atos -o <dSYM>/Contents/Resources/DWARF/BatteryPulse -arch arm64 -l <load> <addr>` on one address from a test
    crash (https://developer.apple.com/documentation/xcode/adding-identifiable-symbol-names-to-a-crash-report).
- **Benefit.** −3.2 MB app binary, −1.0 MB widget, −52 % installed. The DMG payload is −31 % at zlib-1 and
  −29 % under LZMA.
- **Risk.** None at runtime.
  - Swift metadata lives in `__swift5_*` sections, not in the symbol table.
  - The only `dlsym` (`Sources/BatteryKit/MobileDevice/MobileDeviceLibrary.swift:96`) targets the MobileDevice
    handle.
  - Crash logs and Instruments need the dSYM. To profile a release build, point Instruments at the dSYM or
    profile the unstripped `$BIN_PATH` binary.
- **Effort.** S. **Priority:** P0.

### SZ-02: Export only `_main` from both executables (P0, S)

- **Practice.** A main executable without plug-ins that link back to it needs no exported symbols. Give each
  executable an explicit export list.
- **Why.**
  - Apple, Build settings reference, `LD_EXPORT_SYMBOLS`: "Disabling this setting can be useful for binaries which
    have no API or plug-ins and thus need no symbol exports. [-no_exported_symbols]".
  - WWDC22 "Link fast: Improve build and launch times" (https://developer.apple.com/videos/play/wwdc2022/110362/):
    - "a main app binary usually does not need any exported symbols";
    - `-no_exported_symbols` skips the export trie, "which will improve link time";
    - it can't be used if "your app loads plugins which link back to the main executable, or you use xctest with
      your app as the host". BatteryPulse does neither.
  - `ld(1)`:
    - `-exported_symbol` keeps one symbol global;
    - with an export list, "All other global symbols will be treated as if they were marked as
      __private_extern__";
    - `-dead_strip`: "Remove functions and data that are unreachable by the entry point or exported symbols".
- **Correction: the mechanism.**
  - The research (and the sibling SW-17) say ld64 treats every exported symbol as a dead-strip root. That is not
    what ld64's own source does for main executables. In `Options::allGlobalsAreDeadStripRoots()`
    (https://github.com/apple-oss-distributions/ld64/blob/ld64-957.1/src/ld/Options.cpp, lines 310–334; same in
    ld64-820.1), a `kDynamicExecutable` makes globals roots only with `-export_dynamic`.
  - SwiftPM sets neither `-export_dynamic` nor testability in release (§0.1).
  - Yet the shipped widget keeps unreachable public functions (§0).
  - The most likely explanation is that the default linker in Xcode 27, a newer implementation than the published
    ld64 code, treats exported globals of an executable as roots, as the man page sentence literally says.
    **[unverified macOS 27]**
  - The other explanation is that `-dead_strip` is missing from the macOS link line.
  - Either way the symptom is measured, and the fix below covers both cases.
- **Evidence it matters [measured].**
  - The widget's `__text` is 670,304 B. About 369 KB of it belongs to BatteryCore and BatteryKit types the widget
    never uses (`IDevice*`, `History*`, `ReleaseInfo`, `DemoBattery`, `RawKeyGlossary`, `BatteryReport`,
    `MenuBarContent`, `MobileDeviceLibrary`, `BatteryMonitor`). 68 KB of that is witness code.
  - The widget's own sources use only `MacBatteryProvider(readsSMC: false)`, `BatteryFormatter` and SwiftUI
    (`Sources/BatteryPulseWidget/BatteryPulseWidget.swift:61,70`).
- **How.**
  - `Package.swift` is the place:
    - widget target: add `"-Xlinker", "-exported_symbol", "-Xlinker", "_main"` to the existing macOS
      `linkerSettings` `.unsafeFlags`. Restrict it with `.when(platforms: [.macOS], configuration: .release)`, or
      keep it in all configurations, since the widget has no tests;
    - app target (`BatteryPulseApp`): the same flags, release only, so debug test hosting stays possible.
  - Or pass the flags on both `swift build` lines in `build-app.sh`. That is simpler but less discoverable.
  - Keep `_main` exported in the widget. It is linked with `-e _NSExtensionMain`, and the extension runtime
    probably reaches the Swift `@main` entry through `main` **[unverified]**. Keeping it costs nothing.
  - Don't use `-no_exported_symbols` for the widget. ld64 also refuses it together with `-exported_symbol`.
  - **Also check that `-dead_strip` is on the macOS link line:** `swift build -c release --product
    BatteryPulseWidget -v`. If it is missing, add `-Xlinker -dead_strip`.
- **Verify.**
  - `dyld_info -exports <binary>` lists `_main` (plus the header). Today it lists 2,709.
  - Link map before and after: `-Xlinker -map -Xlinker build/widget.map`.
  - `-Xlinker -why_live -Xlinker '_$s11BatteryCore10RawSectionV8sections3forSayACGSDySSAA13PropertyValueOG_tFZ'`
    (the exact name, from `exports-widget.txt`) should report nothing in the widget. Before the change it shows what kept it.
  - Smoke test on the Mac:
    - the widget appears in the gallery and refreshes;
    - the app opens every window, and Check Now works;
    - the menu bar item and notifications work.
- **Expected.**
  - Widget `__text`: up to −250…−300 KB **[estimate]**. Type descriptors, value witnesses and conformance
    witnesses stay, because the `__swift5_types`/`__swift5_proto` records are always live.
  - App: up to −64 KB of export trie, plus any public API only the widget used (small).
  - Faster link (WWDC22).
- **Risk.** Low. Nothing in the code looks up its own symbols by name.
  - `@objc` selectors (`BatteryPulseApp.swift:205`, `Motion.swift:286`) go through the Objective-C runtime.
  - The widget uses `StaticConfiguration`, not App Intents.
  - The smoke test covers WidgetKit.
- **Effort.** S. **Priority:** P0. The same flags fix the sibling SW-17 link maps.

### SZ-03: DMG as ULMO (LZMA) (P0, S)

- **Why.** `hdiutil(1)` (mirror https://ss64.com/mac/hdiutil.html, fetched 2026-10-15; confirm with
  `hdiutil help create` on the runner):
  - "ULMO - UDIF lzma-compressed image (macOS 10.15+ only)", "providing smaller images compared to ULFO".
  - "For UDZO … The default compression level is 1 (fastest)".
  - "UDBZ … (deprecated)" (macOS 12).
- **Measured [reproduced by the verifier with `tools/udif.py`].** The real image recompressed in 1 MiB chunks:

| Payload | zlib-1 (today) | zlib-9 | bzip2 | LZMA |
|---|---:|---:|---:|---:|
| as shipped | 2,504,706 | 2,235,044 | 2,089,884 | **1,553,090 (−38 %)** |
| after SZ-01 | 1,721,958 | 1,584,201 | – | **1,105,943 (−36 %)** |

- **How.**
  - In `build-app.sh`, change `-format UDZO` to `-format ULMO`.
  - **Dropped:** `-imagekey lzma-level=…`. No such key is documented; the man page documents only `zlib-level`
    for UDZO.
  - To get rid of the 170 KB of unreferenced data, use the man page's documented space-optimal route: create a
    read/write or sparse image from the folder, then `hdiutil convert … -format ULMO -o build/BatteryPulse.dmg`
    ("This method produces space-optimal images"). Keep the existing retry loop around `create`.
  - Keep APFS. Filesystem metadata is about 2,033 non-zero 4 KiB blocks and compresses to almost nothing.
  - LZMESH (new in the 27 SDKs) is "available through the buffer API only"
    (https://developer.apple.com/documentation/compression/compression_lzmesh). Apple claims a better ratio than
    LZFSE and zlib, not than LZMA. A UDIF format based on it is **[unverified]**: check `hdiutil help create`.
- **Verify.**
  - `hdiutil imageinfo build/BatteryPulse.dmg` shows the format.
  - `hdiutil verify`.
  - Size in SZ-04.
  - **End-to-end update test from the currently released version.**
    - Existing installs (0.5.x / 0.6.0) shell out to `/usr/bin/hdiutil attach … -nobrowse -readonly -noautoopen
      -mountpoint` (`Sources/BatteryCore/UpdateInstall.swift:132-133`), so they read ULMO with no code change.
    - The Ed25519 signature covers the file bytes, so the format doesn't matter to it.
- **Risk.** Low.
  - ULMO is "not supported in-kernel". The updater doesn't pass `-kernel`, and the default has been a helper
    process since macOS 10.5.
  - Attach is slower than zlib in principle; measure it on the M5 (milliseconds for 8 MB).
- **Effort.** S. **Priority:** P0.

### SZ-04: CI size report and budget (P0, S)

- **Why.**
  - Size regressions are invisible today. The DMG has grown v0.2.0 1.12 MB → v0.5.0 2.68 MB.
  - WWDC26 "What's new in Xcode 27" (https://developer.apple.com/videos/play/wwdc2026/258/, verified): the
    Organizer's new metric "breaks down documents, data, and binary size – since binary size impacts cellular
    downloads and launch time". It is App Store only, so a DMG app needs its own report.
- **How.**
  - `scripts/size-report.sh`, run after `build-app.sh` in `ci.yml` and `release.yml`. It writes a Markdown table to
    `$GITHUB_STEP_SUMMARY` and `build/size.json`, using Apple tools only:
    - `stat -f%z` for the DMG, binaries, `.strings` and `.icns`;
    - `du -sk` for the `.app`;
    - `size -m` for both binaries;
    - `dyld_info -exports … | wc -l` **[output format unverified]**;
    - `hdiutil imageinfo`.
  - **Budget:** `scripts/size-budget.json`, one ceiling per component, read with `plutil -extract <key> raw -o -`
    (**[confirm plutil reads JSON on the runner]**; otherwise use an XML plist). It fails when a ceiling is
    exceeded. Raising a ceiling is a commit that says why.
  - **Trend, informational only:** compare with the latest release's DMG (`gh api
    repos/$GITHUB_REPOSITORY/releases/latest --jq …`). The step needs `env: GH_TOKEN: ${{ github.token }}`, like
    the existing "Resolve version" step.
    - **Dropped:** the research's "+15 % fails unless the budget changed in the same PR" rule. It needs
      PR-diff logic, and the budget already gates.
  - **Hygiene assertions (SZ-09)** in the same script:
    - `otool -L` shows no `@rpath/libswift`;
    - no `Contents/Frameworks`;
    - no `.dSYM`, `.o` or `.swiftmodule` inside the bundle;
    - no `/Users/runner` string in a shipped binary (`strings -a | grep -c`). This catches a lost strip step
      (SZ-01).
  - Upload `size.json` and the SZ-06 link maps as artifacts.
- **Verify.** Run it once on the v0.5.0 bundle: the DMG must read 2,677,709 B and the app binary 5,403,776 B.
  Then start the budget from the 0.6.1 numbers plus about 5 %.
- **Risk.** None. **Effort.** S. **Priority:** P0. Land it first, so every other item has a before/after row.

### SZ-05: `-Osize` for the shipped app and widget (P1, S)

- **Why.**
  - Apple, Build settings reference, `SWIFT_OPTIMIZATION_LEVEL`: "Optimize for Size [-Osize]" is a documented
    choice.
  - Swift.org, "Code Size Optimization Mode in Swift 4.1" (https://www.swift.org/blog/osize/, **2018**): "-Osize
    reduces code size from 5% to even 30%", "For most applications the performance hit … will be negligible".
    The numbers are old; the measurement below is current.
- **Correction.**
  - The research also cites Apple's size guide
    (https://developer.apple.com/documentation/xcode/doing-basic-optimization-to-reduce-your-app-s-size): "The
    default optimization level for the Release configuration is Fastest, Smallest [-Os]". That is the **Clang**
    setting.
  - Apple's Swift Release default is `-O` with whole-module optimization, as SwiftPM's PIF shows (§0.1).
  - So `-Osize` is a deliberate deviation for a UI app with small hot paths, not "Apple's default".
- **Measured [re-checked]:** Linux `bpulse` with `-Xswiftc -Osize`: `.text` 495,201 → 429,134 (−13.3 %); stripped
  binary 857,656 → 798,936 (−6.8 %).
- **How.** Add `-Xswiftc -Osize` to both `swift build -c release` lines in `build-app.sh` (the last `-O*` wins). Leave
  `swift test` and the CI `bpulse` build alone.
- **Verify.**
  - Size from SZ-04.
  - Responsiveness with **Instruments 27 "Run Comparisons"**. WWDC26 "Profile, fix, and verify: Improve app
    responsiveness with Instruments" (https://developer.apple.com/videos/play/wwdc2026/268/): it "computes the
    exact performance delta" between runs in one document. Profile a release build, as the session stresses.
  - Workloads: switching sidebar sections, scrolling the Raw Data table, scrubbing the History chart, opening the
    menu bar window.
  - Energy: Activity Monitor Energy Impact over 10 minutes idle in the menu bar. It should not change.
- **Expected.** About −100…−200 KB across app and widget **[extrapolated from Linux]**.
- **Risk.** Low, and easy to revert. **Effort.** S. **Priority:** P1.

### SZ-06: Size-attribution tooling (P1, S)

- **How.**
  - Link maps: `-Xlinker -map -Xlinker build/<product>.map`.
  - `-Xlinker -why_live -Xlinker <symbol>` (ld(1): "Only applicable with -dead_strip").
  - `swift build --experimental-enable-codesize-profile --experimental-codesize-profile-output-dir <dir>`
    [verified 6.4.1, hidden help: "Generate SIL, LLVM IR, and optimization record files for code size
    profiling"]. The researcher's `tools/asmsize.py` sums the instruction counts per file.
  - Per-module and per-type tables from the unstripped `$BIN_PATH` binaries (`tools/textmap.py`,
    `tools/bytype.py`). That needs symbols, which is one more reason to strip only the bundle copies.
- **Measured findings worth keeping.**
  - Generic specializations are 7.8 % of the app's `__text`. SwiftUI builder closures are 24 % and witness thunks
    20 %.
  - The largest single function in both binaries is the `RawKeyGlossary.table` initializer (17,204 B arm64).
- **Correction.** Linux release links already drop unused public functions (`--gc-sections`, no `-rdynamic`; §0.1).
  So Linux maps cannot show the macOS export problem. Read the macOS maps from CI.
- **Effort.** S. **Priority:** P1.

### SZ-07: Ship no English `.strings` table (P2, S)

- **Measured [re-checked].**
  - `en.lproj/Localizable.strings` is an XML plist with 630 entries, all value == key. `ru` has 4 identity
    entries.
  - Cause: `Resources/Localizable.xcstrings` has no explicit `en` localizations, and all 630 entries are
    `extractionState: manual`. So `xcstringstool compile` writes the source-language table out in full.
  - Gain: 157 KB installed (app + appex). About 30 KB in a zlib-1 DMG, but **only ~4 KB under ULMO**
    (1,105,943 → 1,101,507 together with dropping the widget's tables).
- **How.**
  - In `build-app.sh`, right after `xcstringstool compile`, delete `en.lproj/Localizable.strings` only if every
    entry is identity. Check with `plutil -convert json -o - …` and a small Swift check script, so a future plural
    or variation keeps its table.
  - The appex copies the `.lproj` folders later in the script, so it inherits the change.
  - Keep the empty `en.lproj`.
- **Verify.**
  - The app and widget in English and Russian, including format strings with `%@`.
  - `Bundle.main.preferredLocalizations` still contains `en` with an empty `en.lproj` **[unverified macOS 27]**.
  - `LocalizationCatalogTests` is unaffected.
- **Risk.** Low with the guard. **Effort.** S. **Priority:** P2 (installed size; next to nothing in the download).

### SZ-08: Glossary table as data (P3, M)

- **Why.** Apple's size guide: "use a property list for bundling any data with your app instead of using strings
  in code … significantly reduces the size of your app's binary". `RawKeyGlossary.swift` is 56 KB of source, and
  its `table` initializer is the largest function (17 KB).
- **How.** Either a resource file read through `Bundle.module` (then `build-app.sh` must copy the resource bundle),
  or a literal the optimizer can place in read-only data. After SZ-02 only the app carries it.
- **Priority.** P3. Do it only if the readability work touches the glossary.

### SZ-09: Bundle hygiene assertions (P2, S)

Folded into SZ-04. No back-deployment libraries are needed or shipped on macOS 27 [measured]: every Swift library
loads from `/usr/lib/swift`, there is no `Contents/Frameworks`, and minos is 27.0. `--disable-local-rpath` would
drop the unused `@loader_path` rpath. That is hygiene only; test it before adopting.

### SZ-10: Icon Composer icon compiled by `actool` (P2, nativeness; size-neutral)

- **Why.** Apple: "Use Icon Composer to create a single multilayer file … The system automatically renders your app
  icon for the different platforms, appearances, and sizes"
  (https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer). That gives the
  macOS 26/27 icon variants.
- **How.**
  - `xcrun actool Resources/AppIcon.icon --compile "$APP/Contents/Resources" --platform macosx
    --minimum-deployment-target 27.0 --app-icon AppIcon --output-partial-info-plist build/icon.plist`.
  - Merge `CFBundleIconName` into Info.plist.
  - **[actool flags for `.icon` outside an Xcode project unverified; test on the runner.]**
  - Coordinate with the design research. `AppIconView` must keep matching the icon.
- **Notes on today's `.icns` [measured].**
  - `iconutil` stores the 256 px and 512 px images twice by design (`ic08`/`ic13`, `ic09`/`ic14`): 64 KB
    installed, mostly compressed away in the DMG.
  - `sips` re-encodes the 1024 px master as 69 KB, against the 50 KB `Resources/AppIcon.png`. If the `.icns` stays,
    copy the master unchanged into `icon_512x512@2x.png` (−19 KB).
- **Size.** Expect ±100 KB; measure with SZ-04. Do this for nativeness, not size.

### SZ-11: LTO, conditional runtime records, hermetic seal (P3, one CI experiment)

- **Toolchain [verified 6.4.1].**
  - `swiftc -frontend -help-hidden` lists `-conditional-runtime-records`, `-internalize-at-link` ("assume all
    client code of public types is part of the same link unit, or that external symbols are explicitly requested
    via -exported_symbols_list"), `-experimental-hermetic-seal-at-link`, `-enable-llvm-vfe` and `-enable-llvm-wme`.
  - SwiftPM has a hidden `--experimental-lto-mode`.
- **Correction.** Apple's documented `LLVM_LTO` setting is the Clang one. Swift LTO in Swift Build is
  `SWIFT_LTO` (`-lto=llvm-full` / `-lto=llvm-thin`, swift-build `Swift.xcspec`), which is not in Apple's Build
  settings reference.
- **Measured on Linux (`bpulse`).**
  - Conditional runtime records alone: no change.
  - LTO with the default Swift Build backend: the link fails.
  - LTO with the deprecated native backend: −7 % stripped.
  - LTO + hermetic seal: the link fails.
- **Recommendation.** One macOS CI job that reports SZ-04 numbers with LTO. Adopt only if it builds reliably and
  saves more than 10 % on top of SZ-01, SZ-02 and SZ-05.
  - LTO does not touch the `dlsym` names, because those are looked up in MobileDevice, not in our binary.
- **Priority.** P3. Not for 0.6.1 by default.

### SZ-12: Keep reflection metadata (not recommended to disable)

- **Size at stake [measured].** ~32 KB of reflection sections in the app, ~20 KB in the widget. Linux `bpulse`:
  −2.9 % stripped.
- **Risk.**
  - Apple, `SWIFT_REFLECTION_METADATA_LEVEL` None: "reflection in Swift code may not be able to discover children
    of types, such as properties and enum cases".
  - SwiftUI finds a view's dynamic properties (`@State`, `@Environment`) by walking its stored fields
    **[plausible, consistent with Apple's description]**.
  - **Correction:** of the two `String(describing:)` uses the research named, only
    `Sources/BatteryPulseApp/Updates/UpdateInstaller.swift:173` depends on reflection names. There it describes
    `UpdateInstallError`, a plain enum, and the case name would degrade to the type name in the log.
    Line 258 describes an `Error` thrown by `Process.run()`, a Foundation `NSError` whose description doesn't come
    from Swift reflection.
- **Verdict.** Not worth ~50 KB.

### SZ-13: Shared dynamic framework (not recommended for 0.6.1)

- **Why not.**
  - **Size:** after SZ-02 the duplicated code is only what the widget uses. A dylib must keep all of its public
    API. Net saving ≤ 0.1–0.2 MB, possibly negative.
  - **Launch:** "dynamic libraries have little impact on build time but noticeable launch time consequences" (WWDC23
    "Meet mergeable libraries", https://developer.apple.com/videos/play/wwdc2023/10268/).
  - **Signing:** library validation "prevents a program from loading frameworks, plug-ins, or libraries unless
    they're either signed by Apple or signed with the same Team ID as the main executable"
    (https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.disable-library-validation,
    verified). Ad-hoc signatures carry no Team ID **[load failure unverified]**. Disabling validation makes
    "Gatekeeper run extra security checks".
- **SwiftPM:** targets of one package link statically into its executables.
- **Revisit** with a Developer ID, if SZ-04 still shows large duplication.

### SZ-14 (new): `-dead_strip_dylibs` for the widget (P3, measure only)

- **Why.** `ld(1)`: it suppresses "load command commands for dylibs which supplied no symbols during the link".
  After SZ-02 the widget should no longer reference CryptoKit (only `UpdateSignatureVerifier` uses it), but the
  load command stays without this flag.
- **How.** Add `-Xlinker -dead_strip_dylibs` to the widget's release link in the SZ-02 CI run. Compare `otool -L`
  and an Instruments App Launch trace of the widget extension.
- **Risk.** The man page warns against it when a dylib is "required at runtime for some indirect reason such as …
  an important initializer". Smoke-test the widget.
- **Expected.** A few fewer images loaded per widget launch, all from the shared cache, so the gain is tiny.
  Adopt only if it is measurable.

### Not worth it

- `-Xlinker -objc_stubs_small` (WWDC22 110363): the app's `__objc_stubs` is 3,616 B.
- Binary-plist `.strings`: `ru` grows from 107,028 to 107,456 B, and compresses worse.
- zlib level 9: −11 %, against −38 % for ULMO.
- UDBZ: deprecated in macOS 12 per `hdiutil(1)`.
- `public` → `package` for size: same global symbols (sibling SW-16, verified). It has no size effect.

---

## 2. Corrections to the research (log)

1. **SZ-02 / SW-17 mechanism.**
   - ld64's own code (ld64-820.1 and ld64-957.1, `Options::allGlobalsAreDeadStripRoots`) does not make a main
     executable's exported globals dead-strip roots unless `-export_dynamic` is passed. SwiftPM passes that only
     with testability, which is debug-only.
   - The retained unreachable public functions in the shipped widget are real. The cause is most likely the newer
     default linker in Xcode 27, or a missing `-dead_strip`.
   - The fix is unchanged. Verification now includes the link line and `-why_live`.
2. **SZ-02 Linux cross-check.**
   - Linux release links have no `-rdynamic`, and `--gc-sections` already removes unused public functions (probe
     package, verified).
   - So Linux confirms only the "not exported → removed" half. It is no proxy for the macOS export behaviour.
3. **SZ-01 dSYMs.**
   - SwiftPM's Release configuration already sets `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym`. Look for existing
     `.dSYM` bundles before running `dsymutil`.
   - Nothing is stripped because SwiftPM overrides `STRIP_INSTALLED_PRODUCT = NO`.
   - `--enable-experimental-strip-products` flips that override; it is the native but experimental path.
4. **SZ-03.**
   - Removed the undocumented `lzma-level` image key.
   - Replaced "a final `hdiutil convert` … [plausible]" with the man page's documented create-then-convert route.
   - The 169,797 B gap was confirmed: unreferenced, starting with a 36-byte zlib stream.
5. **SZ-04.**
   - `gh api` needs `GH_TOKEN`.
   - Dropped the PR-diff "+15 %" rule.
   - Added a `/Users/runner` string check as the guard for SZ-01.
6. **SZ-05.** Apple's "-Os" Release default is Clang's. Swift's default is `-O` + WMO. The swift.org figures date
   from 2018. Added Instruments 27 Run Comparisons for verification.
7. **SZ-07.** The download gain under ULMO is ~4 KB, not "≈0 / ~28 KB". Explained why `xcstringstool` writes the
   identity table (manual extraction, no `en` entries).
8. **SZ-11.** `LLVM_LTO` is the Clang setting. Swift's is `SWIFT_LTO` in Swift Build.
9. **SZ-12.** `UpdateInstaller.swift:258` is a Foundation error, unaffected by reflection settings. Only line 173
   is affected.
10. **Baseline.**
    - The bundle total is 8,049,334 B.
    - `llvm-size` is not part of the Swift 6.4.1 toolchain; the system `llvm-size` was used.
    - Everything else in §0 was reproduced (symbol counts, STABS, OSO paths, export trie, chained fixups, exports
      list, strip sizes, recompression numbers).

## 3. Open questions for the runner or the Mac

1. Does Swift Build write `$BIN_PATH/*.dSYM` for release products (`ls .build/out/Products/Release/*.dSYM`)?
2. Exact macOS link line: `swift build -c release --product BatteryPulseWidget -v`. Is `-Xlinker -dead_strip`
   present? Is `-export_dynamic` absent?
3. After SZ-02:
   - Does `-why_live` report `RawSection.sections(for:)` as dead in the widget?
   - Does the widget still start with only `_main` exported?
4. Does `hdiutil help create` on macOS 27 list an LZMESH-based format? Does the create → convert ULMO route remove
   the 170 KB gap?
5. Does `actool` compile a `.icon` outside an Xcode project?
6. What is the arm64 `-Osize` delta for the SwiftUI-heavy app module?
7. Does `plutil -extract … raw` read a JSON budget file?

## 4. Sources (all fetched or run 2026-10-15)

- **Apple documentation** (JSON behind developer.apple.com):
  - `xcode/build-settings-reference`: `LD_EXPORT_SYMBOLS`, `DEAD_CODE_STRIPPING`, `STRIP_INSTALLED_PRODUCT`,
    `STRIP_STYLE`, `STRIP_SWIFT_SYMBOLS`, `COPY_PHASE_STRIP`, `DEBUG_INFORMATION_FORMAT`,
    `SWIFT_OPTIMIZATION_LEVEL`, `SWIFT_REFLECTION_METADATA_LEVEL`, `LLVM_LTO`, `EXPORTED_SYMBOLS_FILE`;
  - `xcode/doing-basic-optimization-to-reduce-your-app-s-size`;
  - `xcode/building-your-app-to-include-debugging-information`;
  - `xcode/adding-identifiable-symbol-names-to-a-crash-report`;
  - `xcode/creating-your-app-icon-using-icon-composer`;
  - `compression/compression_lzmesh`;
  - `bundleresources/entitlements/com.apple.security.cs.disable-library-validation`.
- **WWDC:**
  - WWDC26 262 "What's new in Swift" (Swift Build is SwiftPM's default backend; `@inline(always)` in 6.4,
    `@specialized` in 6.3);
  - WWDC26 258 "What's new in Xcode 27" (App Size metric);
  - WWDC26 268 "Profile, fix, and verify" (Run Comparisons, Top Functions; profile release builds);
  - WWDC22 110362 "Link fast" (`-no_exported_symbols`, `dyld_info`, `-dead_strip`);
  - WWDC22 110363 (`objc_stubs_small`);
  - WWDC23 10268 "Meet mergeable libraries".
- **Apple open source:**
  - ld64 `doc/man/man1/ld.1` (ld64-820.1) and `src/ld/Options.cpp` (ld64-820.1, ld64-957.1:
    `allGlobalsAreDeadStripRoots`, `-no_exported_symbols`/`-exported_symbol` handling);
  - cctools `man/strip.1` (default `-u -r`, `-T`).
- **Swift project:**
  - swift-build `main`: `Sources/SWBCore/Settings/Settings.swift` (testability → `LD_EXPORT_GLOBAL_SYMBOLS`),
    `Sources/SWBUniversalPlatform/Specs/Ld.xcspec`, `Sources/SWBGenericUnixPlatform/Specs/UnixLd.xcspec`,
    `Sources/SWBCore/Specs/CoreBuildSystem.xcspec`, `Sources/SWBUniversalPlatform/Specs/Swift.xcspec` (`SWIFT_LTO`);
  - SwiftPM 6.4.1: `swift build --help-hidden`, the build request and PIF of a release probe and of a Linux build
    of this repository;
  - `swiftc -frontend -help-hidden`;
  - swift.org blog "Code Size Optimization Mode in Swift 4.1" (2018).
- **`hdiutil(1)`** (ss64.com mirror; confirm on the runner).
- **Artifacts:** the v0.5.0 `BatteryPulse.dmg` from GitHub Releases, unpacked on Linux.
