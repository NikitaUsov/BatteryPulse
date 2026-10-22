# BatteryPulse: everything left to do or decide (inventory to 1.0)

As of 2026-10-22, the day 0.6.1 was released. Repository at `9410861` (tree equal to v0.6.1, `7622373`
on `main`, plus the roadmap commit). English only; names no third-party product.

**Updated the same day with the maintainer's answers (2026-10-22).** He will not pay for an Apple
developer account for this app; Xcode is already installed on the M5; Clear's minimize fill is
(b); widgets in 0.7, no 0.6.3. Every other question was delegated ("do it by best practices, as
you see fit") and is decided as its recommendation. §12 and "The paid account" record them; the
rows they settle say so, and the counts include that.

**Further answers the same day (2026-10-22):**
- What 1.0 means is approved as written, with **no dates**: "this is a hobby project; we release
  when there is time and desire" (DIS-10; the roadmap's M-5).
- M-1's reason, in his words: he will not pay for an Apple developer account for this app; he is
  willing to spend on help with development, not on the account.
- 0.6.2's round A0 passed (DIS-04), so DIS-07 doesn't run.
- 0.6.2's integration branch is `claude/nice-faraday-k08mhb`; packages go on `claude/062-<pkg>`,
  the widget spikes on `claude/062-spike-widget` (P2 §3).
- 0.7 gains an anonymous version count, on by default and announced (DIS-11, a new row).
- 0.6.2 gains a release-statistics script, `scripts/release-stats.swift` (the roadmap's NEW-23,
  P2 WP-19; tooling, no app change, so no row of its own).

## How to read this

- **One row per item**, deduplicated across every source. When several sources describe the same
  work, the row lists them all.
- **Columns:** user-visible (yes, no, indirect: it changes freshness, energy or speed rather than
  what is shown); size (S ≤ 1 implementation run or ≤ 15 minutes of session time; M 2-3 runs or up
  to an hour; L 4-6 runs or several hours; XL more, or several releases); depends on (other rows or
  packages); blocked by (one or more of: **paid account**, **M5 session**, **Xcode on the Mac**,
  **maintainer taste**, **Apple API** (private, undocumented or unverified behaviour), **evidence**
  (waits for a measurement or a failure), **hardware** (a device not at hand), or **none**);
  version (the one the sources assign today: **0.6.2**, **0.7**, **later**, **not planned**,
  **rejected**, or **unassigned** when no source assigns one). A row whose version a maintainer
  decision of 2026-10-22 changed names the decision there. The paid-account and Xcode blockers
  keep their category with the answer in brackets ([declined], [installed]), as do the rows whose
  question changed their route. Every question behind "maintainer taste" is answered in §12, and
  what 1.0 means (DIS-10) in the roadmap's M-5; the looks themselves are still signed off in the
  sessions. A row that has since been done (DIS-04) stays, marked, so the counts hold.
- **Rows marked (new)** are gaps found while sweeping that no plan lists. They cite the files that
  show the gap.
- **Uncertainty** is marked "unverified" or "uncertain" in the row.

**Source abbreviations**

| Short | File |
|---|---|
| R:n | `docs/ROADMAP.md` as v0.6.1 shipped it, line n |
| UG:n | `docs/USER_GUIDE.md`, line n |
| RM:n | `README.md`, line n |
| RN:n | `.github/release-notes.md`, line n |
| P2 | the verified 0.6.2 plan, `docs/plans/0.6.2/PLAN.md` (section, package or question ID; `P2:n` is a line of the plan as committed at `bb6eeab`) |
| P1 | the 0.6.1 plan, `6aec4d2:docs/plans/0.6.1/PLAN.md` (in PR 11's history) (§6 deferred table at line 1372, Appendix A, Appendix B, Appendix C) |
| PB | `6aec4d2:docs/plans/0.6.1/playbook.md` |
| AUD-x | `6aec4d2:docs/plans/0.6.1/audit-x-verified.md` |
| RES-x | `6aec4d2:docs/plans/0.6.1/research/x.md` |

**Swept and found empty:** no `TODO`, `FIXME`, `XXX` or `HACK` in `Sources`, `Tests`, `scripts`,
`.github` or `Package.swift` (grep, 2026-10-22). No open GitHub issues:
`gh api repos/NikitaUsov/BatteryPulse/issues?state=open` returns `[]`; the repository's 11 issues are
all closed pull requests (#1-#11). The only known issue in the release notes is Clear's black
minimize frame (RN:12-13), row QUA-01.

---

## Summary

**131 items left to do or decide** (open, parked or not planned; 130 from the sweep plus DIS-11,
added with the maintainer's answer of 2026-10-22), **22 maintainer questions** and **62 rejected
ideas** that must not come back. Counts are computed from the tables below.

| Category | 0.6.2 | 0.7 | later | not planned | unassigned | Total |
|---|---|---|---|---|---|---|
| Feature | 6 | 9 | 7 | 12 | 0 | 34 |
| Quality | 10 | 2 | 0 | 2 | 2 | 16 |
| Energy and performance | 12 | 2 | 1 | 2 | 1 | 18 |
| Security | 4 | 1 | 1 | 1 | 1 | 8 |
| Size | 4 | 2 | 1 | 0 | 0 | 7 |
| Distribution | 5 | 1 | 0 | 3 | 2 | 11 |
| Docs | 6 | 2 | 0 | 0 | 2 | 10 |
| Tooling and CI | 7 | 2 | 0 | 1 | 1 | 11 |
| Platform debt | 3 | 0 | 1 | 0 | 1 | 5 |
| Accessibility | 4 | 1 | 0 | 1 | 0 | 6 |
| Localization | 3 | 2 | 0 | 0 | 0 | 5 |
| **All** | **64** | **24** | **11** | **22** | **10** | **131** |

- **Unassigned:** 10, of which 8 are gaps no plan lists (marked "new"): QUA-06, QUA-15, SEC-07,
  DIS-09, DIS-10, DOC-09, DOC-10, PLT-05. The other two are leftovers (ENG-18, TCI-09).
- **Settled by the answers of 2026-10-22** (moved to not planned): FEA-14 (Q-W1: 0.7), FEA-23
  (Q-B10: no fallback), FEA-24 (Q-B2: fill (b)), SEC-01 (Q-B8: no, and no Developer ID build);
  moved to later: FEA-25 (Q-B4: not in 0.6.2, with a beta style's graduation). Later the same
  day: DIS-04 passed (round A0), so DIS-07's condition isn't met; DIS-10 is decided (approved as
  written, no dates); DIS-11 is added in 0.7 (the anonymous version count).
- **Decisions:** 9 for 0.6.2 (Q-B2 to Q-B11) and 13 for widget customization (Q-W1 to Q-W13), §12.
  All are decided as of 2026-10-22: Q-B2, Q-B7 and Q-W1 by the maintainer, Q-W3 following his M-1
  answer, Q-B9 and Q-B11 settled before, the rest by delegation.
- **What blocks them** (a row can have several): an M5 session 54 rows (42 of them in 0.6.2, since
  FEA-23 and SEC-01 left it);
  maintainer taste 25 (the questions are now answered; the looks are still signed off in the
  sessions); Apple API behaviour 12; Xcode on the Mac 11 (installed on the M5, so these run,
  maintainer-run); the paid account 12 (7 name it, 5 iOS rows inherit it through FEA-29), which the
  maintainer declined, so they stay not planned or take the route without it; hardware not at
  hand 6; evidence still to come 4.
- **User-visible:** 73 yes, 13 indirect (freshness, energy, speed), 45 no. **Sizes:** 83 S, 39 M,
  6 L, 3 XL.

**The five largest open themes**

1. **Widget customization (0.7):** 36 rows (FEA-01 to FEA-21, ENG-16, ENG-17, SEC-08, SIZ-06,
   SIZ-07, L10N-03 to L10N-05, A11Y-05, A11Y-06, TCI-10, TCI-11, DOC-07, DOC-08, QUA-16) plus the 13
   Q-W questions. Six spikes in 0.6.2 (W0-1 to W0-6) decide the design; the MVP is the configurable
   Battery widget in small, medium and large (extra large on the look check's yes, Q-W10); the
   feed-backed History and iPhone & iPad widgets hang on an unverified sandbox exception (W0-3),
   since an App Group needs the paid account the maintainer declined.
2. **M5 verification debt:** 54 rows need the MacBook Air M5, many of them checks left open since
   0.4-0.6 (Stages 1.1-1.5, 5, 6): icon styles, the beta styles' evidence, accessibility passes,
   devices and accessories, the Charge Limit capture, spreadsheets, widgets across updates.
3. **Energy and the read path (0.6.2):** E20 off the main actor, E4b registry caching, E3b, the
   page and History speed work, and every energy number 0.6.1's session skipped (ENG-01 to ENG-12).
4. **Swift 6 and size foundation (0.6.2):** main actor by default (PLT-01), the `diskutil`
   installer (PLT-02), the `BatterySource` split and `-internalize-at-link` (SIZ-01, SIZ-02), strict
   memory safety for the system bindings (SEC-05): the groundwork 0.7's widget needs.
5. **Distribution and the road to 1.0:** Developer ID and notarization (not planned: the
   maintainer declined the paid account on 2026-10-22; 12 rows depend on it), in-app update and
   login-item/widget survival across updates (both seen kept across 0.6.0 → 0.6.1 in round A0),
   `bpulse` not shipped to users, the iOS promises in the README, the definition of 1.0 (approved,
   with no dates), and 0.7's anonymous version count (DIS-01 to DIS-11, DOC-09, PLT-05).

Not planned, kept visible: the iOS app and its widget and Live Activity (6 rows), iCloud, charge
limiting, apps using the most energy, chart descriptors, Developer ID and the package manager, App
Nap, Instruments profiling against the resource targets, the glossary and iPad captures, K-02's CI
half; and, since the answers of 2026-10-22, the 0.6.3 option, the Low Power Mode fallback, Clear's
desktop-following fill and the Enhanced Security spike.

---

## 1. Feature

| ID | Item | Description | Sources | User-visible | Size | Depends on | Blocked by | Version |
|---|---|---|---|---|---|---|---|---|
| FEA-01 | W0-1: App Intents metadata in a SwiftPM build (spike) | `build-app.sh` runs `appintentsmetadataprocessor` on the widget's `.swiftconstvalues`; CI fails without `extract.actionsdata`; tests the `size:` overload, an entity query, a button perform and an extracted `Summary` key. SwiftPM itself skips extraction (`LM_SKIP_METADATA_EXTRACTION=YES`, P2 App B) | P2 WP-W0 (P2:757), §8.16; R:550-553 | no | S | none | Apple API (manual processor step unverified), M5 session for (b) and (c) | 0.6.2 (P1, spike) |
| FEA-02 | W0-2: placed widgets survive the move to a configurable kind (spike) | SPIKE-C control, SPIKE-I, SPIKE-W installed the way `UpdateInstaller` does; `pluginkit` and screenshots before and after; Edit Widget shows the parameters, localized | P2 WP-W0 (P2:758), §6 Session A step 3; R:552-553 | no | S | FEA-01 | M5 session, Apple API | 0.6.2 (P1, spike) |
| FEA-03 | W0-3: can the sandboxed widget read what the app writes (spike) | Candidates A (read-only home-relative temporary exception), A′ (shared-preference exception, own domain), B (`notify(3)` state words); a denial is silent on macOS 27 | P2 WP-W0 (P2:759), §8.3 | no | S | none | M5 session, Apple API (exceptions under ad-hoc signing unverified) | 0.6.2 (P1, spike) |
| FEA-04 | W0-4: accessories from the sandbox; rendering modes; clicks (spike) | `IOPSCopyPowerSourcesByType(4)` from the widget; rendering mode per Icon & widget style and Dim widgets setting, desktop and Notification Center; `redactionReasons`; what a click delivers; whether `widgetURL` needs a URL scheme | P2 WP-W0 (P2:760), §8.7, §8.9 | no | S | none | M5 session, Apple API | 0.6.2 (P1, spike) |
| FEA-05 | W0-6: self-updating "time left" text (spike) | `Text(.currentDate, format: .offset(to:allowedFields:[.hour,.minute]))` in English and Russian; ticks each minute without a reload | P2 WP-W0 (P2:762), §8.5 Time | no | S | none | M5 session | 0.6.2 (P1, spike) |
| FEA-06 | W-3: configurable Battery widget | `AppIntentConfiguration` on today's kind; small, medium, large, extra large; Layout Automatic or Custom; main value and visual; details (1/4/8/12); status lines; clock time or time left; level colours or monochrome; read time; attention row; empty states; natural-page clicks; drawn-battery painter moved into code the widget compiles; previews from the real reading | P2 §8.5, §8.17, §8.14 W-3, §9.1; R:545-550 | yes | XL | FEA-07, FEA-08, ENG-08 (nonisolated read), SIZ-01, SIZ-02 | M5 session (0.7), maintainer taste (Q-W4 to Q-W7, Q-W13) | 0.7 (MVP) |
| FEA-07 | W-1: widget model in BatteryCore | `WidgetSize`, `WidgetKindID`, frozen-raw-value enums, `WidgetLayoutPlan` (`automatic` equals v0.6.1 small and medium), `WidgetTimeText`, `WidgetTextBudget`, `WidgetRow`, `WidgetSparkline`, `WidgetRoute`/`PageID`, `WidgetTimelinePlan`, and the frozen-surface pin test (kinds, raw values, routes, feed path, entitlement keys) | P2 §8.6, §8.13, §8.14 W-1 | no | L | spike answers (FEA-01 to FEA-05) | none (Linux) | 0.7 (MVP) |
| FEA-08 | W-2: App Intents metadata step in the shipping build | The processor step in `build-app.sh` before the widget's `codesign`; the macOS job fails unless every pinned intent, parameter and `AppEnum` case is in `Metadata.appintents` | P2 §8.14 W-2 | no | M | FEA-01 | Apple API | 0.7 (MVP) |
| FEA-09 | W-8: Accessories widget | Own one-shot read; All or Lowest (small always Lowest); earbuds per part; demo accessories in previews | P2 §8.4, §8.5 Accessories, W-8 | yes | M | FEA-04 passing, SIZ-01 (`BatterySource` holds `MacAccessoryProvider`) | Apple API | 0.7 (MVP if W0-4 passes; else later through the feed, if W0-3 passed) |
| FEA-10 | W-5: widget data feed | The app writes `Application Support/…/Widget/feed.json` (version 1, ≤ 8 KB: day and week series, 24-hour statistics, 90 daily summaries, up to 8 devices); atomic, only when content changes and a reader kind is placed; nothing in Demo Mode; rewritten on Clear History or Forget | P2 §8.3, W-5; Q-W3 | indirect | L | FEA-03 (A or A′), Q-W3 | Apple API, maintainer taste (Q-W3) [Q-W3 answered yes, 2026-10-22]; an App Group would replace it but needs the paid account (P2 §8.2) [declined, 2026-10-22: the feed is the only route] | 0.7 (stretch), else 1.1 |
| FEA-11 | W-6: History widget, and the Battery widget's feed fields and History chart | Period 24 h or 7 d; charge, battery power, temperature; 90-day capacity and cycle trend; statistics; charging spans; average drain and time on battery as Battery details | P2 §8.5 History, W-6 | yes | M | FEA-10 | maintainer taste (Q-W2, Q-W4) | 0.7 (stretch) |
| FEA-12 | W-7: iPhone & iPad widget | Most recently read, all, or a chosen device (`AppEntity` over the feed, or `AppEnum` only if entity queries fail); reading age always shown; names `.privacySensitive()` | P2 §8.5 iPhone & iPad, W-7 | yes | M | FEA-10, FEA-01 (b) | maintainer taste (Q-W2, Q-W11) | 0.7 (stretch) |
| FEA-13 | Configuration fallback: preset kinds | If the edit sheet can't work: Battery (plus large and extra large), Battery Health and Power as fixed `StaticConfiguration` kinds | P2 §8.16 row 1; Q-W2 | yes | M | FEA-01 failing | evidence | 0.7 (only if W0-1 fails; Q-W2 decided: no presets otherwise) |
| FEA-14 | Large and extra-large sizes of today's static widget, in a 0.6.3 | The one low-risk early slice: new sizes, no configuration, no App Intents, no new file | P2 §9 (P2:1859-1863); Q-W1 | yes | S | 0.6.2 shipped | maintainer taste (Q-W1) [answered 2026-10-22: 0.7] | not planned (Q-W1: 0.7, no 0.6.3) |
| FEA-15 | Widget Refresh button | `AppIntent` performed in the extension (`allowedExecutionTargets`), next to the read time, on Battery and Accessories; no system change | P2 §8.9, W-9; Q-W9 | yes | S | FEA-06, FEA-01 (c) | maintainer taste (Q-W9) | later |
| FEA-16 | Extra-large portrait size | `systemExtraLargePortrait`, macOS 27 only | P2 §8.2, W-9; Q-W10 | yes | S | FEA-06 | maintainer taste (Q-W10) | later |
| FEA-17 | Extra-large dashboard | Mac, History, devices and accessories in one widget | P2 §8.17, W-9; Q-W10 | yes | M | FEA-09 to FEA-12 | maintainer taste (Q-W10) | later |
| FEA-18 | Per-row widget links | A device row opens that device's page | P2 §8.9, W-9; Q-W8 | yes | S | FEA-06, FEA-12 | maintainer taste (Q-W8) | later |
| FEA-19 | Choose specific accessories in the widget | Entity id `AccessoryWidgetID` ("acw-" plus FNV-1a of kind and visible name), never `AccessoryBattery.id` | P2 §8.5 Accessories, §8.13, W-9 | yes | M | FEA-09 | maintainer taste (Q-W2) | later |
| FEA-20 | "Why it isn't charging" widget field | Only after the Charge Limit capture decodes `notChargingReason` (`BatterySnapshot.swift:63`) | P2 §8.5 catalogue, §9.1 Later | yes | S | QUA-05 | M5 session | later |
| FEA-21 | Hide fully charged accessories | A nice-to-have option of the Accessories widget | P2 §8.5 Accessories | yes | S | FEA-09 | maintainer taste | 0.7 (nice-to-have) |
| FEA-22 | Graduate Translucent and/or Clear from beta | `isBeta` false per style; Beta mark and, once none is left, the Beta window styles toggle go; `betaWindowStyles` stays frozen; What's New only on Q-B5 | P2 WP-13 items 3 and 5, G-13b; R:307-308, R:441-443, R:503-506 | yes | S | QUA-03, ENG-03 | maintainer taste, M5 session (default: stay beta) | 0.6.2 (gated) |
| FEA-23 | Low Power Mode fallback for the beta styles | If Translucent or Clear costs ≥ 15 % more than Standard and the maintainer agrees, it gives way to Standard under Low Power Mode, decided in `WindowLookPolicy` | P2 WP-13 item 5, G-13c; Q-B10; R:31-32 | yes | S | ENG-03 | M5 session, maintainer taste (Q-B10) [decided by delegation, 2026-10-22: no fallback] | not planned (Q-B10: no fallback) |
| FEA-24 | Clear's minimize fill that follows the desktop picture | Average of the desktop picture, decoded off the main actor when the window appears and on Space changes; only system folders and `~/Pictures`, else the grey fill; file-access prompt elsewhere unverified on macOS 27 | P2 WP-13 item 1 variant; Q-B2 | yes | M | QUA-01 | maintainer taste (Q-B2) [answered 2026-10-22: fill (b)] | not planned (Q-B2: fill (b)) |
| FEA-25 | Glass-sheet chart lines and Raw Data treatment | Thicker chart lines and wider area fills on the sheet; the content treatment on the Raw Data table (AppKit-backed) | R:340-341; P2 WP-13 item 4; Q-B4 | yes | S | none | maintainer taste (Q-B4) [decided by delegation, 2026-10-22: not in 0.6.2] | later (Q-B4: with a graduation) |
| FEA-26 | Apps using the most energy | Per-app watts over the last hour or day from per-coalition energy counters, with an unattributed remainder; a one-day spike first | R:576-584; P2 App A | yes | L | a spike on the M5 | Apple API (private calls, unproven without root on macOS 27), M5 session | not planned |
| FEA-27 | Charge limiting through the system's Charge Limit | Offer macOS's own 80-100 % limit through a private client, plus a read-only report of what the firmware allows; the SMC route is closed on macOS 27 | R:677-684, R:705 | yes | L | none | Apple API (private), the maintainer's stance | not planned |
| FEA-28 | Mac battery on the iPhone through iCloud | CloudKit private database, silent pushes, an iPhone widget, `CKQuerySubscription` alerts | R:645-651 | yes | XL | FEA-29 | paid account (CloudKit and push need it) [declined, 2026-10-22], the iOS app | not planned |
| FEA-29 | iOS app: target sharing SwiftUI components | Stage 2's first item | R:558-560; RM:14-15 | yes | XL | DIS-02 | paid account (beyond 7-day personal installs, R:13-14) [declined, 2026-10-22], the maintainer's stance | not planned |
| FEA-30 | iOS: charge, state, Low Power Mode, thermal state screen | Stage 2 | R:561 | yes | M | FEA-29 | as FEA-29 | not planned |
| FEA-31 | iOS: charging session while the app is open | %/min and an estimate to 100 % | R:562 | yes | M | FEA-29 | as FEA-29 | not planned |
| FEA-32 | iOS: analytics file import | Cycles, health, capacity, temperature from the exportable analytics file; its format is still unchecked against a real file | R:79-81, R:563; RM:205-206 | yes | L | FEA-29 | as FEA-29; a real analytics file | not planned |
| FEA-33 | WidgetKit widget on iOS | Stage 4 | R:589 | yes | M | FEA-29 | as FEA-29 | not planned |
| FEA-34 | iOS Live Activity while charging | Stage 4 | R:590 | yes | M | FEA-29 | as FEA-29 | not planned |

## 2. Quality (bugs, look and behaviour checks, code health)

| ID | Item | Description | Sources | User-visible | Size | Depends on | Blocked by | Version |
|---|---|---|---|---|---|---|---|---|
| QUA-01 | Clear turns black while it minimizes and comes back | An opaque minimize fill chosen from screen recordings of three candidates (today's, the tint over mid grey ≈ 19 % white, the window background); `WindowLookPolicy.minimizeFill`; Linux tests; Translucent Dark too if its recordings show it | RN:12-13; UG:162-163; R:357-359, R:503-506; P2 WP-13 item 1, G-13a; P1 App A UR-3 | yes | S | SPIKE-A2's fill switch | M5 session (Session A recordings), maintainer taste (Q-B2) [answered 2026-10-22: fill (b), the graphite composite] | 0.6.2 (P1) |
| QUA-02 | Clear's tile preview reads differently selected and unselected (V1b) | Make the preview identical in both states; the selection changes only the outline; Session B compares pixels | P2 §2.2 V1b, WP-13 item 2; R:504-505 | yes | S | none | M5 session (scripted) | 0.6.2 (P1) |
| QUA-03 | Beta styles: the graduation evidence | Glass sheet sampling the desktop; sidebar, toolbar, inspector and Demo Mode bar on it; graphite tint on the sidebar selection; Clear's dark appearance staying in its window; Form fills and table stripes; scroll edge under the title; full screen; Frosted beside the widget gallery; Clear's shadows in Instruments; 24 + 19 scripted screenshots | R:333-339, R:536-537; P2 WP-13 item 3, §6 Session B step 3 | yes | M | QUA-01 | M5 session, maintainer taste; Xcode on the Mac [installed] (Clear's shadows) | 0.6.2 (what Session B misses stays open in Stage 1.5) |
| QUA-04 | Menu bar icon styles signed off on the M5 | Symbol, Modern, Classic, Percentage Inside and Ring; the exact-level drawing with every state (bolt, plug, low, Low Power Mode); the 0.6.0 rework checks (the plug, 100 % on power, Percentage Inside with 1-3 digits). The light and dark comparison passed (V1d) | R:225-235, R:240-248; P2 §2.2 V1d, §6 optional | yes | S | none | M5 session (optional), maintainer taste | 0.6.2 (optional; else stays open) |
| QUA-05 | Charge Limit stop-point capture | `bpulse --record` while charging to the limit; a fixture, and it decides `notChargingReason` | R:145-146, R:536; P2 §6 optional, §8.3 | indirect | S | none | M5 session (optional) | 0.6.2 (optional; else stays open) |
| QUA-06 | Optimized charging hold not yet seen in a macOS 27 capture | IOPS `Optimized Battery Charging Engaged` appears only while the charge is on hold | R:53, R:76-77 | yes | S | none | M5 session (needs the hold to happen), evidence | unassigned (new; implied by R:76-77) |
| QUA-07 | Glossary: uncertain keys, and captures from M1-M4 Macs | About 20 keys still unexplained on the M5 (`RawKeyGlossaryTests`); other Macs' captures as fixtures | R:147-150; RM Contributing; P2 App A | yes (Raw Data) | M | contributors' captures | hardware | not planned |
| QUA-08 | iPad capture and `ManufactureDate` decoding | iPad (9th generation); the pack's date doesn't decode like the Mac's | R:620-621; P2 App A | yes | S | none | hardware (no iPad at hand) | not planned |
| QUA-09 | iPhone and iPad in the packaged app (F5) | Library validation, the Local Network prompt, attach and detach timing, the product ID range, sleep, page switching, Russian layout | R:634-635, R:539-540; P2 §6 Session A step 2 | yes | S | none | M5 session, hardware (an iPhone at hand) | 0.6.2 (Session A, if at hand) |
| QUA-10 | Accessories on macOS 27 (F5) | `bpulse --accessories --raw` beside `pmset -g accps -xml`: keyboard on Bluetooth and on its cable, earbuds in and out of the case; symbols; the Russian panel with three parts; whether macOS 27 hides the list from apps | R:662-669; P2 §6 Session A step 2 | yes | S | none | M5 session, hardware (accessories at hand) | 0.6.2 (Session A) |
| QUA-11 | Exported history in spreadsheet apps | CSV in a Russian and an English region; the Save panel | R:675-676, R:540; P2 §6 optional | yes | S | none | M5 session (optional) | 0.6.2 (optional; else stays open) |
| QUA-12 | E10: Check Now cancels a waiting automatic check | Today it waits for the automatic one, which Low Data Mode refuses at once, so Check Now can fail (inferred from code, not observed) | R:530; P2 WP-16 item 4; P1 §6; RES-energy E10 | yes | S | none | none | 0.6.2 (P3) |
| QUA-13 | SUI-09: `@State` initialized in one place | Kept to `App/`; optionally one `AppServices` grouping | R:531; P2 WP-19; RES-swiftui SUI-09 | no | S | none | none | 0.6.2 (P3) |
| QUA-14 | CB-02: device JSON dates as ISO 8601 | `bpulse --device <n> --json` writes `firstUseDate` as seconds since 2001 today; change with a release-notes line | R:554-556; P1 §8 Q3; AUD-cli-build CB-02 | yes (scripts) | S | none | frozen-output rule (needs a minor version) | 0.7 |
| QUA-15 | Remove the legacy `samples.jsonl` migration | No release ever wrote that file, so the migration only serves pre-0.3 development folders | AUD-cli-build CB-01 ("for a later decision"); PB §3.4 storage list | no | S | none | none (frozen storage list needs a version that announces it) | unassigned (new) |
| QUA-16 | 0.7's own M5 session | A 0.6.x widget after the in-app update; every kind × family × rendering mode in both languages at 12- and 24-hour time; the edit sheet; VoiceOver; clicks with and without a window; reloads requested against delivered; widget energy; the feed's contents | P2 §8.14 (P2:1767-1775) | yes | M | FEA-06 to FEA-12 | M5 session | 0.7 |

## 3. Energy and performance

| ID | Item | Description | Sources | User-visible | Size | Depends on | Blocked by | Version |
|---|---|---|---|---|---|---|---|---|
| ENG-01 | Menu bar energy against 0.6.0, 0.6.1 and the RC | S1 (icon and charge), S2 (power in the menu bar, alternated), S2 under Low Power Mode, S6 (displays asleep); pass: S2 −50 % against 0.6.0 | R:413-414, R:493-494, R:507-508; P2 WP-21; PB §2.7 | indirect | M | DEC Q-B11 (baseline branch kept) | M5 session (unattended window, admin password once) | 0.6.2 (P1) |
| ENG-02 | Launch to `menuBarReady` | 5 cold launches per build; exactly 1 read before it; p50 ≤ 0.6.0 | R:493-494; P2 WP-21 S7 | indirect | S | none | M5 session | 0.6.2 (P1) |
| ENG-03 | Energy of each window style (S4w) | Overview 5 minutes in Standard, Translucent and Clear (Frosted if time allows); decides FEA-23 | R:31-32, R:338, R:413-414, R:507-508, R:536-537; P2 WP-21, G-13c | indirect | S | none | M5 session | 0.6.2 (P1) |
| ENG-04 | Burst, covered window, memory | 3 plug cycles (1 read per burst, ≤ 1 widget reload per cycle); main window covered (S5); History → 7 d three times with `phys_footprint`; memory over the 2-hour field run | R:507-508; P2 WP-21 | indirect | S | none | M5 session (hands-on) | 0.6.2 (P1) |
| ENG-05 | Devices and accessories energy | An iPhone attached with all windows closed (target < 1 ms/s on average), memory after 2 hours; accessories connected | R:636-637, R:668-669, R:508; P2 WP-21 S9, S10 | indirect | S | none | M5 session, hardware (if at hand) | 0.6.2 (if at hand; else stays open) |
| ENG-06 | Sleep hygiene | No Preventing Sleep outside an install in every run; after a night with the lid closed, no wake attributed to BatteryPulse | P2 WP-21, §6 optional; PB §2.3 | indirect | S | none | M5 session (overnight, optional) | 0.6.2 (assertions always; overnight optional) |
| ENG-07 | Stage 1.4 motion check | Frame rate in Instruments; energy with the window visible, covered, minimized, on another Space and with the display asleep; S3 (popover open) | R:298-301, R:537-538; P2 WP-21 "Not run" | indirect | M | none | M5 session (hands-on mid-run), Xcode on the Mac [installed] | later (stays open in Stage 1.4) |
| ENG-08 | E20: full reads off the main actor (WP-14a) | Nonisolated `Sendable` provider (SMC state behind a `Mutex`), `@concurrent` reads with a generation number and coalescing; launch and manual reads stay synchronous; read p95 8.8 ms against a 4 ms gate | R:515-519; P2 WP-14a, §2.3, G-14a; P1 §6 | no | M | PLT-01 | M5 session (2-hour field run, V-01) | 0.6.2 (P1) |
| ENG-09 | E4b: read the registry only when it changes (WP-14b) | Polls reuse the registry, children, IOPS and adapter dictionaries; Power and Raw Data keep re-reading; 5-minute safety net (60 s if the premise fails); `registry.missed` event; one switch `RegistryReadPolicy.cachesOnPolls`; registry is 72 % of a read | R:515-519; P2 WP-14b, G-14b; RES-energy E4b | indirect (registry values up to the safety-net age old outside Power and Raw Data) | M | ENG-08; F13 premise | M5 session (pslog and ioreg in Session A; Session B criteria) | 0.6.2 (P1, gated) |
| ENG-10 | E3b: drop the `timeremaining` notify key | Only if every `timeremaining` is followed by "any" within about 10 ms over 2 hours on battery and 1 charging | R:517-518; P2 WP-14b item 6, G-14c; RES-energy E3b | no | S | ENG-09's pslog | M5 session (default: keep both keys) | 0.6.2 (gated) |
| ENG-11 | Page responsiveness (WP-17) | SUI-07 narrow inputs, E19 rebuild only changed Raw Data sections, SUI-11 table rows, SUI-12 vectorized power chart, each only where the instrument shows cost; goal `page.switch` p50 under 33 ms (30-65 ms today) | R:518-519; P2 WP-17, §2.1, G-17; P1 §6 | yes | M | none | M5 session (≥ 10 switches per page), Xcode on the Mac [installed] for the SwiftUI instrument (Q-B7) | 0.6.2 (P2) |
| ENG-12 | History riders | The 24-hour view loads 5× slower than 7 days (51.6 vs 9.9 ms p50 on the M5); `history.record` p95 11.6 ms; rerun bench B3, profile `HistoryLoad.read` | P2 WP-17 riders, §2.1; P1 App C B5 | yes | S | none | none (numbers from the M5 already) | 0.6.2 (P2) |
| ENG-13 | How often the mAh values change | Session A's ioreg sampler records `RemainingCapacity` every 10 s | R:574-575; P2 Session A step 9, WP-22 | no | S | none | M5 session (unattended) | 0.6.2 |
| ENG-14 | App Nap and the minute timer | Whether App Nap applies to a status-item-only app | R:574-575; RES-energy §6 item 1; PB §4; P2 App A | no | S | none | M5 session | not planned |
| ENG-15 | Profile against the resource targets | About 0 % CPU idle, under 30 MB RAM, binary under 5 MB, in Instruments | R:46, R:151; P2 App A (memory partly covered by WP-21) | no | M | none | Xcode on the Mac [installed] | not planned |
| ENG-16 | W-4: widget reload planner | `WidgetReloadPlanner` per kind inside `WidgetRefresher`, `currentConfigurations()`, day tests (Battery ≤ E15's day + 7; all kinds < ~100 a day), signposts `widget.timeline`, `widget.feed.*`, `widget.reload` triggers per kind; `WidgetReadCache` (one IOKit read per burst) | P2 §8.10, W-4 | indirect | M | FEA-07 | none | 0.7 (MVP) |
| ENG-17 | Widget reloads delivered and widget energy, measured | Compare `widget.timeline` with `widget.reload` over a day; if < ~90 % arrive, drop percent-step reloads first | P2 §8.10 targets, §8.14 0.7 session | indirect | S | ENG-16 | M5 session | 0.7 |
| ENG-18 | Unconfirmed runtime facts | `ri_energy_nj` non-zero for the app; shipping libdispatch leeway; memory tools on a hardened ad-hoc build; Low Data Mode per network; WidgetKit developer mode on macOS; the thermal-condition inducer for a Mac target; whether closed `Window` scenes release `@State` (E18) | RES-energy §6 items 4-9; PB §4 | no | S | none | M5 session, Xcode on the Mac [installed] | unassigned (some may fall out of ENG-01 to ENG-04; uncertain) |

## 4. Security

| ID | Item | Description | Sources | User-visible | Size | Depends on | Blocked by | Version |
|---|---|---|---|---|---|---|---|---|
| SEC-01 | SEC-08: Enhanced Security entitlements spike | Widget first; memory tagging (soft mode) and the dyld read-only entitlement testable on the M5; platform restrictions need an arm64e slice; checked pointer arithmetic needs M6 or later; ships only if AMFI accepts them on an ad-hoc signature and V-01 and F8 pass | R:527-528; P2 WP-20, §7.1; P1 §6; Q-B8 | no | M | none | M5 session, Apple API (AMFI on ad-hoc unverified), hardware (M6 for one part), maintainer taste (Q-B8, a session step or not) [decided by delegation, 2026-10-22: no] | not planned (Q-B8: no; no Developer ID build to retry it on) |
| SEC-02 | SEC-18: a self-signed code identity (research) | A stable designated requirement keeps the login item, notification and other grants across updates without a paid account; a second secret in the `release` environment; does **not** unlock an App Group | R:529-530; P2 WP-20; RES-security SEC-18 | indirect | M | none | M5 session (to check grants survive), none for the research | 0.6.2 (research only) |
| SEC-03 | SEC-10: MobileDevice in a helper process | Isolate the private framework; also enables real XPC peer checks with SEC-02 | R:526; P2 G19, App A; P1 §8 Q1; RES-security SEC-10 | no | M | none | evidence (a recorded hang or crash; none so far) | later (on evidence) |
| SEC-04 | SEC-15: skip image verification when mounting | `-noverify` or its `diskutil` equivalent, adopted only if it saves ≥ 100 ms; the image is already authenticated by digest and Ed25519 | R:529; P2 WP-16 item 3, Session A step 7 | no | S | PLT-02 | M5 session (timing) | 0.6.2 (gated; default no change) |
| SEC-05 | SW-13: strict memory safety for BatterySource and BatteryKit | `.strictMemorySafety()`; every IOKit, SMC, notify and MobileDevice unsafe site marked with its reason | R:531; P2 WP-19; P1 §6; RES-swift SW-13 | no | M | SIZ-01 | none | 0.6.2 (P2) |
| SEC-06 | No prompt for the app's own data after an update | macOS 27's XProtect may deny files created by other teams' apps; an ad-hoc app has no Team ID and a new cdhash per version: confirm History and settings read with no prompt after a real update | RES-security SEC-17 (added); PB §4 last row; P2 D3 | yes | S | DIS-04 | M5 session (after publishing) | 0.6.2 (in the after-publishing checks) |
| SEC-07 | Swap-renaming capability checked before the swap | `URLResourceKey.volumeSupportsSwapRenamingKey` for a clearer error; optional in SEC-17, not in Sources (grep) | RES-security SEC-17 | yes (error text) | S | none | none | unassigned (new; an optional rider not taken) |
| SEC-08 | Widget feed hardening | Reader rejects > 32 KB, unknown versions, mismatched lengths, NaN, future dates; strips control and bidirectional characters; folder 0700 and file 0600; no file API outside `WidgetFeedReader`, no `dlopen`/`dlsym`/`URLSession` in the widget's own files; pin that the widget calls only `MacAccessoryProvider.read()` | P2 §8.3, §8.8 | no | S | FEA-10 | none | 0.7 (with W-5) |

## 5. Size

| ID | Item | Description | Sources | User-visible | Size | Depends on | Blocked by | Version |
|---|---|---|---|---|---|---|---|---|
| SIZ-01 | K-03: a lower `BatterySource` target | CryptoKit and the device stack out of the widget (about 187 KB); `Diagnostics` public there; guards move; a test that `Sources/` folders equal the scanned targets; `build-app.sh` fails if the widget links CryptoKit | R:521-523; P2 WP-15 item 1, G-15; P1 §6, App C C1; AUD-kit K-03 | no | M | ENG-09 (git moves its files) | M5 session (F8 on the RC) or ships CI-only as a pure move | 0.6.2 (P1) |
| SIZ-02 | `-internalize-at-link` on the widget | A hidden Swift 6.4 frontend flag; −27 % of the widget's `__text` in a native test build; untested with Swift Build's prelink and at runtime; maybe the app too | R:522-523; P2 WP-15 item 2, G-15; P1 App C C1 | no | S | SIZ-01 | M5 session (SPIKE-I, then F8 on the RC) | 0.6.2 (gated) |
| SIZ-03 | SZ-11 LTO and SZ-14 `-dead_strip_dylibs` | CI experiments only; adopt above 10 % on top of the rest | R:532; P2 WP-15 item 3; RES-size SZ-11, SZ-14 | no | S | SIZ-01 | none | 0.6.2 (P3, cut early) |
| SIZ-04 | Widget ceilings lowered after the RC | RC + about 5 %, in a commit of its own, so 0.7's growth is visible | P2 WP-15 item 4, D1 | no | S | SIZ-01, SIZ-02 | none | 0.6.2 |
| SIZ-05 | SZ-08: the glossary table as data | `RawKeyGlossary`'s 17 KB initializer as a resource or read-only literal | R:532; P2 WP-19 "Not in 0.6.2", App A; RES-size SZ-08 | no | M | QUA-07 (glossary work) | none | later (only with glossary work) |
| SIZ-06 | 0.7 widget size budget | Growth of about 100-250 KB of `__text`; `Metadata.appintents` gets a `widget_appintents_bytes` row and ceiling; 80-120 new keys counted twice in `strings_bytes`; Swift Charts only under 15 KB of `__text`, else `Path` | P2 §8.12 | no | S | FEA-08, L10N-04 | none | 0.7 |
| SIZ-07 | A widget-only string table | Would roughly halve the widget's `.lproj`; changes `string-tables.swift` and the catalog rule | P2 §8.12 optional | no | M | L10N-04 | none | 0.7 (P3; measurement decides) |

## 6. Distribution and the update path

| ID | Item | Description | Sources | User-visible | Size | Depends on | Blocked by | Version |
|---|---|---|---|---|---|---|---|---|
| DIS-01 | Developer ID signing and notarization | Removes Open Anyway on first launch of every downloaded version; keeps permissions across updates; unlocks App Groups, iCloud and an official package catalog. See "The paid account" below | R:10-12, R:152-153, R:180-181, R:641-643, R:705-706; RM:22-25; UG:35-43 | yes | M (once the account exists) | none | paid account [declined, 2026-10-22] | not planned (no paid account: the maintainer's decision of 2026-10-22, not before 1.0) |
| DIS-02 | iOS distribution | Personal installs re-signed every 7 days, or TestFlight and the App Store with the paid account | R:13-14 | yes | S (decision) | none | paid account [declined, 2026-10-22], the maintainer's stance | not planned |
| DIS-03 | A package manager | A personal catalog works today but every install still needs Open Anyway; the main catalog needs notarization and some popularity | R:685-687 | yes | S | DIS-01 | paid account [declined, 2026-10-22] | not planned (needs notarization) |
| DIS-04 | 0.6.1's after-publishing checks (intake A0) | About shows 0.6.1; History shows past days; settings and menu bar unchanged; the widget current; `codesign` `flags=0x10002(adhoc,runtime)`; no quarantine; login item still listed; notification permission kept; first-day widget charge and "Lasts until" against the popover; any failure becomes a P1 item | P2 §5 A0, App A, Appendix C; P1 §4b; R:200-201 | yes | S | 0.6.1 published | M5 session (everyday use) | 0.6.2 (first; **passed**, 2026-10-22: 0.6.1 installed through Install and Relaunch from 0.6.0, the desktop widget stayed and shows the current charge, Open at login kept its state; no P1 item) |
| DIS-05 | Install from the app: tick Stage 1.2 | F12 on the RC through the `diskutil` path; tick once 0.6.1's after-publishing check and F12 pass | R:161-201; P2 WP-16 acceptance, WP-22, App A | yes | S | PLT-02, DIS-04 | M5 session | 0.6.2 |
| DIS-06 | Widgets kept on the desktop across an in-app update | Seen kept and lost across DMG replacements; the in-app swap keeps the path and raises `CFBundleVersion`; whether only a stable Developer ID signature keeps them is open | R:202-208, R:541; UG:425-426; P2 W0-2 control, Session B F8, App A | yes | S | FEA-02 | M5 session, possibly paid account (uncertain) [declined, 2026-10-22: a loss is a documented known limitation at 1.0] | 0.6.2 (evidence; round A0 saw them kept across the in-app update 0.6.0 → 0.6.1) |
| DIS-07 | Open at login survives an update | Store the choice in a new `openAtLogin` key and re-register once on the first launch of a new version; only if 0.6.1's check shows the login item lost | R:200-201; P2 WP-16 item 5 | yes | S | DIS-04 | evidence [A0 kept the login item, 2026-10-22] | 0.6.2 (conditional P2; not run: the condition isn't met) |
| DIS-08 | 0.6.2's freeze, Session B and release (D1-D3) | Benches and golden, storage and settings diffs; RC built as 0.5.99; Session B; release; after-publishing check with `--prerelease` rollback | P2 D1-D3 (P2:893-932), §6 Session B | yes | M | every 0.6.2 package | M5 session, maintainer (release approval) | 0.6.2 |
| DIS-09 | Ship `bpulse` to users (new) | The guide and the bug template tell users to run `swift run bpulse` (UG:563, UG:579, UG:598-600, UG:660-661), but releases hold only the app (P2 §6, "the DMG holds only the app"); accessory captures have no in-app export (UG:356-358) | UG and bug template as cited; P2 §6 | yes | M | none | none (an extra signed binary in the DMG or the app; quarantine for a CLI unverified) | unassigned (new) |
| DIS-10 | What 1.0 means (new) | No source defines 1.0's scope or criteria; README still says "Status: early development" (RM:14) | R:689-706 (no 1.0 entry); RM:14 | yes | S (decision) | none | maintainer taste [the roadmap's M-5: approved as written, with no dates, 2026-10-22] | unassigned (new; decided in the roadmap's §2) |
| DIS-11 | Anonymous version count (new: the maintainer's decision of 2026-10-22) | Once per installed version, at least 24 hours after it first ran, an automatic update check that reached GitHub also GETs `BatteryPulse-count.txt` from that version's release and ignores the body; the asset's public `download_count` is the number of Macs that ran the version. On by default (a missing key means on), announced in the release notes, What's New and README's and the guide's new Privacy sections, off in Settings → General (shown in the Welcome window); never from Check Now or while Check for updates is Never. No identifier, nothing about the Mac, its battery or its settings, no server of our own, no third-party service; no cookies on any update traffic. Three new settings keys and a new release asset: frozen surfaces, so a minor release | the maintainer's answer (2026-10-22); the roadmap's NEW-24 and C14 item 8; the 0.7 plan's W-13 and Appendix B; RM:120-125 and UG:502-509 (the privacy promise it rewords) | yes | M | the automatic update check (`UpdateChecker`), `release.yml`, the release-statistics script (the roadmap's NEW-23) | none (decided; seen in 0.7's own session, QUA-16, and its after-publishing check) | 0.7 (W-13; never cut) |

## 7. Docs

| ID | Item | Description | Sources | User-visible | Size | Depends on | Blocked by | Version |
|---|---|---|---|---|---|---|---|---|
| DOC-01 | CLAUDE.md for 0.6.2 | `BatterySource` in the layout and "a BatterySource twin"; `read`'s four triggers and `registry.missed`; E4b; E20's isolation; main actor by default; the `diskutil` installer; the opaque minimize fill; strict memory safety for BatterySource and BatteryKit | P2 WP-22 | no | S | the packages that land | none | 0.6.2 (P1, last) |
| DOC-02 | User Guide for 0.6.2 | Clear's known issue removed (UG:162-163); graduated styles without "beta"; a refresh sentence if E4b lands (UG:124-132); installer text | P2 WP-22 | yes | S | QUA-01, FEA-22, ENG-09 | none | 0.6.2 |
| DOC-03 | Roadmap for 0.6.2 | Ticks; the window-style Decisions line (R:31-32); "Performance baseline (0.6.1 → 0.6.2)"; reword "power in the menu bar for an hour" (R:507); Session A's length (R:500-501 says about 25 minutes, P2 §1 about 65, and Session B about 95); the 0.7 stage with §9.1's phases | P2 WP-21 output, WP-22 | no | S | ENG-01 to ENG-05 | none | 0.6.2 |
| DOC-04 | 0.6.2 release notes | `## What's new in 0.6.2` (checked by CB-06); only user-visible items that landed; the energy line; "Updating from 0.6.1" | P2 D1 | yes | S | DIS-08 | none | 0.6.2 |
| DOC-05 | Plan files | Commit the 0.6.2 plan under `docs/plans/0.6.2/`; at D3 move §8, §9.1, the Q-W answers and W0 results to `docs/plans/0.7.0/widgets.md` and link it from the roadmap | P2 header (P2:26-27), D3 | no | S | none | none | 0.6.2 |
| DOC-06 | Window-style screenshots for the User Guide | Session B produces 24 + 19 shots; whether any are committed to the guide is not decided (uncertain) | R:339; P2 §6 Session B step 3 | yes | S | QUA-03 | M5 session, maintainer taste | 0.6.2 (evidence; publication undecided) |
| DOC-07 | Widget docs for 0.7 | Rewrite the guide's Widget section (W-10); it still says a DMG replacement removes placed widgets (UG:425), which R:202-203 contradicts for 0.3.1 → 0.4.0, and calls the widget new (UG:428, RM:84) | P2 W-10 | yes | S | FEA-06 | none | 0.7 |
| DOC-08 | Privacy text with the widget feed | SEC-16: keep the guide's privacy section current; the feed is a new file in Application Support | RES-security SEC-16; P2 §8.8 | yes | S | FEA-10 | none | 0.7 (with W-5) |
| DOC-09 | iOS promises in the README (new) | "The iOS app comes later" (RM:14-15), "the planned workaround" (RM:205-206), the iOS 27 badge (RM:5) and the bug template's "or iOS 27" contradict "Not planned: an iOS app" (R:704-706) | as cited | yes | S | DIS-02 | maintainer taste (stance) [the roadmap's M-2, decided by delegation 2026-10-22: not in 1.x] | unassigned (new) |
| DOC-10 | Bug template asks no app version (new) | `.github/ISSUE_TEMPLATE/bug_report.yml` asks device and OS but not the BatteryPulse version | as cited | no | S | none | none | unassigned (new) |

## 8. Tooling and CI

| ID | Item | Description | Sources | User-visible | Size | Depends on | Blocked by | Version |
|---|---|---|---|---|---|---|---|---|
| TCI-01 | The 0.6.2 session script | `docs/plans/0.6.2/m5-session.sh`: fresh backups per session, a restore that covers Application Support, the energy runs, the swap helper, `y = looks right` wording, `bash -n` in CI | P2 WP-21, §3 session wording, §6 | no | M | none | none | 0.6.2 (P1) |
| TCI-02 | CI pins | Review `actions/checkout` v6.1.0 (a tag without a changelog entry) and `upload-artifact` v7.0.2; move only to a tagged, changelogged release pinned by SHA | R:533-534; P2 WP-19; P1 App C B6 | no | S | none | none | 0.6.2 |
| TCI-03 | SW-21: DocC check in CI | Only if it costs under a minute | R:531; P2 WP-19; RES-swift SW-21 | no | S | none | none | 0.6.2 (P3) |
| TCI-04 | C2: parser instruction budget | Tried once, never a gate | R:531-532; P2 WP-19; RES-energy C2 | no | S | none | none | 0.6.2 (P3) |
| TCI-05 | SUI-17: previews in a SwiftPM executable target | A 30-minute spike; if they don't work, a UI library target | R:520; P2 WP-18; RES-swiftui SUI-17 | no | S | none | Xcode on the Mac (Q-B7) [installed] | 0.6.2 (maintainer-run; else 0.7) |
| TCI-06 | SUI-18: the SwiftUI Specialist skill as a review checklist | Exported on the Mac; nothing committed | R:520; P2 WP-18 | no | S | none | Xcode on the Mac [installed] | 0.6.2 (maintainer-run; else 0.7) |
| TCI-07 | SUI-19: type-check timing of the slowest bodies | The 5 slowest bodies, ms each | R:520; P2 WP-18 | no | S | none | Xcode on the Mac [installed] | 0.6.2 (maintainer-run; else 0.7) |
| TCI-08 | K-02's CI half | A hung `swift test` past the swift-testing limit ends only at the job timeout | P1 App C A1 (P1:1709); P2 App A | no | S | none | none | not planned |
| TCI-09 | Unconfirmed toolchain facts | `@diagnose(StrictMemorySafety…)` on 6.4.0; `_logChanges`; a monotone `LinePlot` interpolation; `xcrun agent skills export` arguments; xctrace's SwiftUI template name; per-cell `.help` cost; whether SwiftUI skips a Binding-only change | RES-swift §7; RES-swiftui §6 | no | S | none | Xcode on the Mac [installed] | unassigned (part falls out of ENG-11 and TCI-05 to TCI-07) |
| TCI-10 | Widget render previews in CI | `ImageRenderer` PNGs per kind × family × language, a review aid | P2 W-3 | no | S | FEA-06 | none | 0.7 |
| TCI-11 | Widget guard rules | Flag `TimelineView(.periodic…)`, `.everyMinute`, `Text(…, style: .timer/.relative)` in the widget; file, `dlopen`, network placements; App Intents literal forms in the catalog scan | P2 §8.7, §8.8, §8.11 | no | S | FEA-06, FEA-10 | none | 0.7 (W-10) |

## 9. Platform debt

| ID | Item | Description | Sources | User-visible | Size | Depends on | Blocked by | Version |
|---|---|---|---|---|---|---|---|---|
| PLT-01 | WP-10: main actor by default for the app | `.defaultIsolation(MainActor.self)` for the app only; 35 annotations removed, 4 kept and pinned; off-main types marked `nonisolated`; V-01 on the M5 twice and after publishing | R:430-431, R:512-514; P2 WP-10, G-10; P1 §6, §8 Q2; RES-swift SW-04, V-01 | no | M | none | M5 session (runtime traps show only there) | 0.6.2 (P1, first) |
| PLT-02 | Installer on `diskutil` | `diskutil image attach` and `diskutil eject` (with a forced fallback) instead of `hdiutil attach/detach/imageinfo`, deprecated in macOS 27; CI exercises both 0.6.1's and the new path | R:524-525; P2 WP-16 items 1-2, G-16; P1 App C B1 | no | M | none | M5 session (F12; default: back to `hdiutil`) | 0.6.2 (P1) |
| PLT-03 | SZ-10: the Icon Composer icon | Compiled by `actool`; changes how the icon looks in the Clear and Tinted icon styles | R:520; P2 WP-18; Q-B7; RES-size SZ-10 | yes | S | none | Xcode on the Mac [installed], maintainer taste (Q-B7) [ships only on the maintainer's y to its screenshots] | 0.6.2 (maintainer-run; else 0.7) |
| PLT-04 | Private-API contingencies | If Apple breaks MobileDevice, the usbmuxd/lockdown protocol behind `IDeviceTransport`; if macOS 27 hides accessory batteries from apps, `pmset -g accps -xml` | R:603-605, R:664-667 | yes (only on breakage) | L | none | Apple API (a future change) | later (on breakage) |
| PLT-05 | iOS code kept building without an iOS app (new) | `IOSBatteryProvider` (`BatteryProvider.swift:58-59`) and CI's iOS build of BatteryKit (ci.yml:130-131) continue while the iOS app is not planned: keep as cheap insurance, or drop | as cited; R:705 | no | S | DIS-02 | maintainer taste (stance) [M-2: kept building until it first costs time] | unassigned (new) |

## 10. Accessibility

| ID | Item | Description | Sources | User-visible | Size | Depends on | Blocked by | Version |
|---|---|---|---|---|---|---|---|---|
| A11Y-01 | Chart descriptors for VoiceOver | Hourly or daily summaries for the History charts; Sources have no `accessibilityChartDescriptor` (grep) | R:573; P2 App A | yes | M | none | none | not planned |
| A11Y-02 | Stage 1.4 accessibility pass | The Liquid Glass slider at both ends; Reduce Motion; Prefer Cross-Fade Transitions; Reduce Transparency; Increase Contrast; Show Borders | R:298-301; P2 §6 optional | yes | S | none | M5 session (optional) | 0.6.2 (optional; else stays open) |
| A11Y-03 | Contrast audit of the window styles | Accessibility Inspector on every style | R:338, R:536-537; P2 WP-13 item 3; Q-B7 | yes | S | none | Xcode on the Mac [installed, Q-B7] | 0.6.2 (Session B, maintainer-run) |
| A11Y-04 | Menu bar icons under Increase Contrast and Reduce Transparency, and on a notch display | `scripts/menu-bar-shots.sh` | R:236-239, R:538-539; P2 §6 optional | yes | S | none | M5 session (optional) | 0.6.2 (optional; else stays open) |
| A11Y-05 | W0-5: VoiceOver on today's widget; Text size | What VoiceOver says for the bucketed level symbol (63-87 % shows the 75 % symbol); whether Text size reaches desktop widgets | P2 WP-W0 (P2:761), §6 Session A step 4 | yes | S | none | M5 session | 0.6.2 |
| A11Y-06 | Widget accessibility in 0.7 | One VoiceOver element per block, the level symbol hidden, one summary per chart, colour never the only signal in any rendering mode, text styles with scale limits; today's widget has no accessibility modifiers and a fixed 34 pt number | P2 §8.1, §8.7, §8.15 | yes | M | FEA-06 | M5 session (0.7) | 0.7 (MVP) |

## 11. Localization

| ID | Item | Description | Sources | User-visible | Size | Depends on | Blocked by | Version |
|---|---|---|---|---|---|---|---|---|
| L10N-01 | F9: Russian pages | Overview, Settings and the update warning in Russian; not run in 0.6.1's session | P2 §2.2, §6 Session B step 4 | yes | S | none | M5 session | 0.6.2 |
| L10N-02 | Strings for a graduated style | New Advanced footer and What's New keys with Russian; the Beta keys removed when no beta style is left | P2 §3 Strings, WP-13 item 5 | yes | S | FEA-22 | maintainer taste | 0.6.2 (only if a style graduates) |
| L10N-03 | Checking the widget in Russian | A per-extension `AppleLanguages` in the widget's container preferences; whether the widget and its edit sheet follow it is unverified | P2 §6 Session A step 3.3, Session B F8 | yes | S | none | M5 session, Apple API | 0.6.2 |
| L10N-04 | W-10: widget localization | Every parameter, case, entity type, description and summary with its Russian; the catalog test learns the App Intents literal forms; a reasoned placeholder exception if summaries extract as `${name}`; entity titles verbatim; no counted phrases; `WidgetTextBudget` length test; new "tomorrow" keys | P2 §8.6, §8.11, W-10 | yes | M | FEA-06 to FEA-12, FEA-01 (d) | none | 0.7 (MVP, last) |
| L10N-05 | Unit symbols in the widget | `BatteryFormatter.widget` with the app's catalog symbols; today's widget uses `BatteryFormatter()`'s English defaults (`BatteryFormatter.swift:33-41`). Whether any symbol shows in today's widget is uncertain (it shows %, cycles and temperature) | P2 §8.6 Formatter | yes (latent) | S | FEA-06 | none | 0.7 |

---

## 12. Decisions only the maintainer can make

Each question is the plan's own (P2 §10, P2:1876-1961). "Default" is what would have happened
without an answer. On 2026-10-22 the maintainer answered Q-B2, Q-B7 and Q-W1 (Q-W3 follows from his
M-1 answer) and delegated the rest ("do it by best practices, as you see fit"); each delegated
question is decided as its recommendation (the roadmap's §5.3 and plan-0.7.0 §14), and the looks are
still signed off in the sessions.

| ID | Question | Category | Blocks | Default if unanswered | Decided (2026-10-22) |
|---|---|---|---|---|---|
| Q-B2 | Clear's minimize fill: one of three recorded fills, or one that follows the desktop picture | quality | QUA-01, FEA-24 | fill (b), the graphite composite | **The maintainer:** fill (b), the graphite composite. FEA-24 is not built |
| Q-B4 | What still looks wrong in Translucent and Clear; which must be fixed before graduation; may Translucent graduate first | quality | FEA-22, FEA-25 | both stay beta | By delegation: both stay beta until the maintainer signs one off in Session B; FEA-25 is not in 0.6.2 (later, with a graduation) |
| Q-B5 | Announce a graduated style in What's New or only in the notes | docs | FEA-22 | `WhatsNew.version` stays 0.6.0 | By delegation: the release notes only; `WhatsNew.version` stays 0.6.0 |
| Q-B6 | Are the two sessions' lengths acceptable; which energy scenarios matter most | energy/perf | ENG-01 to ENG-06 | the plan's sessions as written | By delegation: the sessions as written, every scenario as planned |
| Q-B7 | Is Xcode on the M5; will the maintainer run the Xcode-only items; is the Icon Composer icon wanted | tooling/CI | ENG-11 (instrument), TCI-05 to TCI-07, PLT-03, A11Y-03, QUA-03 (shadows) | those items skipped or moved to 0.7 | **The maintainer:** Xcode is already installed. The Xcode-only items run, maintainer-run with Claude's step-by-step list; by delegation, the Icon Composer icon ships only on the maintainer's y to its screenshots |
| Q-B8 | Is the Enhanced Security spike worth a session step | security | SEC-01 | not run | By delegation: no; SEC-01 is not planned |
| Q-B9 | What happened on F12's first try in 0.6.1's session | distribution | DIS-05 | settled: GitHub's rate limit behind a VPN; Session B checks the remaining requests first | Settled before |
| Q-B10 | Should a style costing ≥ 15 % more energy give way to Standard under Low Power Mode | feature | FEA-23 | no fallback; decision stays open | By delegation: no fallback; FEA-23 is not planned |
| Q-B11 | Keep `claude/baseline-0.6.0` and `claude/nice-faraday-k08mhb` until 0.6.2 ships (answer before 0.6.1's branch cleanup) | tooling/CI | ENG-01 (build A), citations in P2 | kept until 0.6.2's D3 | Settled before; `claude/nice-faraday-k08mhb` is also 0.6.2's integration branch (the maintainer, 2026-10-22; P2 §3) |
| Q-W1 | Widgets in 0.7, or first a 0.6.3 with large and extra-large sizes of the static widget | feature | FEA-06, FEA-14 | 0.7 | **The maintainer:** 0.7; no 0.6.3 (FEA-14 not planned) |
| Q-W2 | Which kinds; specific accessories later; the 90-day trend; presets anyway | feature | FEA-09 to FEA-13, FEA-19 | all four kinds as phased, trend offered, no presets | By delegation: Battery and Accessories in 0.7; History and iPhone & iPad on the feed, with the trend; specific accessories later; no presets unless configuration fails |
| Q-W3 | May the app keep a small copy of recent readings for the widgets | feature | FEA-10 to FEA-12 | no copy: History and iPhone & iPad widgets wait for Developer ID | Following the maintainer's M-1 answer (the declined paid account): **yes**, if W0-3 passes. If it fails, those two widgets aren't possible without the account |
| Q-W4 | Main visual, main values, colour default, large and extra-large details, History chart on placed large widgets | feature | FEA-06, FEA-11 | today's number and symbol; level colours; §8.17's lists; chart replaces the last two rows | By delegation: the default, with a ring and a drawn battery offered; charge by default, plus maximum capacity, temperature and battery power; the details as the look check shows |
| Q-W5 | Clock time or time left, and which is the default | feature | FEA-06 | clock time | By delegation: clock time by default, time left offered if W0-6 passed |
| Q-W6 | "Updated 14:05" only when old, or always as an option | feature | FEA-06 | only when old | By delegation: only when old, with Always offered |
| Q-W7 | Offer battery power (up to half an hour old) at all | feature | FEA-06 | offered, with the read time | By delegation: offered, with the read time |
| Q-W8 | Does a row open its own page | feature | FEA-18 | one page per widget | By delegation: one page per widget |
| Q-W9 | A Refresh button later | feature | FEA-15 | not built | By delegation: not built |
| Q-W10 | Extra large as a dashboard or a bigger Battery; the portrait size | feature | FEA-16, FEA-17 | a bigger Battery; no portrait | By delegation: a bigger Battery (two panels, Battery and Power, if the look check approves it, else not in 0.7); no dashboard; no portrait |
| Q-W11 | Device names on the desktop, or only the model | feature | FEA-12 | the name, `.privacySensitive()` | By delegation: the name, `.privacySensitive()` |
| Q-W12 | °F where the region uses it, app-wide, or keep °C | localization | FEA-06, every temperature in the app | °C | By delegation: °C |
| Q-W13 | Attention row on by default | feature | FEA-06 | on | By delegation: on |

Stance questions raised by this inventory (not in P2), answered in the roadmap's §6 on 2026-10-22:
the paid account (DIS-01, see below: declined), the iOS promises (DOC-09, PLT-05: not in 1.x, by
delegation), and what 1.0 means (DIS-10: approved as written by the maintainer, with no dates).
One more decision of the maintainer's own, not a question of P2: the anonymous version count in
0.7, on by default and announced (DIS-11; the 0.7 plan's Q7-9).

---

## 13. Rejected: do not resurrect

Reasons are the verifiers'. "Revisit only if" is the one condition a source names; blank means none.

| ID | Idea | Area | Reason | Revisit only if | Source |
|---|---|---|---|---|---|
| REJ-01 | CORE-10: one registry and SMC pass per read | energy/perf | About 28 µs per read, unmeasurable; adds parallel overloads | parse above 1 ms on the M5 (it is 0.153 ms p50, P2 §2.1) | AUD-core CORE-10 |
| REJ-02 | CORE-11: a `BatteryUnits` namespace | quality | Ranges differ on purpose; churn across packages, removes no logic | | AUD-core CORE-11 |
| REJ-03 | CORE-13: day keys without `Calendar` | quality | No gain; risk to storage file names; infeasible guard | | AUD-core CORE-13 |
| REJ-04 | CORE-16: `IconRect` to `CGRect` | quality | Most visible element, CG semantics traps, about 50 lines | a release redesigns the icon (0.7's drawn-battery visual may) | AUD-core CORE-16; P2 App A |
| REJ-05 | CORE-18: a name check before deleting the update leftover | security | Already deletes only a bundle with this app's identifier; would break after a rename | | AUD-core CORE-18 |
| REJ-06 | CORE-20: move widget types out of `BatteryPresentation.swift` | quality | A pure move in a file being changed | the file is next substantively changed (0.7's W-1 may) | AUD-core CORE-20 |
| REJ-07 | K-06: suppress follow-up reads after Demo Mode | energy/perf | At most 5 reads once; they catch plug changes missed during Demo Mode | | AUD-kit K-06 |
| REJ-08 | K-10: cancellable deadline timers | energy/perf | `asyncAfter` already has a leeway; unmeasurable; crash and cycle risks | | AUD-kit K-10 |
| REJ-09 | K-11: end the attach loop on a deallocated monitor | quality | The monitor lives for the process; the fix doesn't fix it | | AUD-kit K-11 |
| REJ-10 | K-12: system-state-only reads and `io_service_t` reuse | energy/perf | Nothing to serve under E4b; a third scope adds a merge path | | AUD-kit K-12 |
| REJ-11 | AC-06: pause the Demo Mode clock with no window open | energy/perf | The menu bar shows the demo; would freeze a playing tour | | AUD-app-core AC-06 |
| REJ-12 | AV-03: `SidebarItem` as `RawRepresentable` | quality | Adds String work to every `==` and hash | | AUD-app-views AV-03 |
| REJ-13 | AV-13: skip Copy Report's forced read | quality | Unmeasurable; keeps the report's SMC values fresh | | AUD-app-views AV-13 |
| REJ-14 | CH-10: `onChange(of: AppSettings.alerts)` | quality | Hidden dependency, no gain | | AUD-app-chrome CH-10 |
| REJ-15 | CH-14 | quality | Already done in `6584585` | | AUD-app-chrome CH-14 |
| REJ-16 | CB-01: export migrates the legacy file | quality | No release ever wrote `samples.jsonl` (see QUA-15 for removing the migration instead) | | AUD-cli-build CB-01 |
| REJ-17 | CB-03: `--smc` as an output format | tooling/CI | Net-zero refactor on the frozen exit-code surface | the next real parser change, over CB-04's table | AUD-cli-build CB-03 |
| REJ-18 | Rejected parts of kept findings | quality | CORE-01's `Hex` type and stored value; CORE-02's `static let` regexes (don't compile) and literal prefilters; CORE-03's production `settleSeconds`; CORE-17's static cache; K-08's 0x85 → missing; K-13's cached Ed25519 key; AC-01's unconditional blocker; AC-04's file move; AV-04's `BatteryHero`, `GaugeRow`, `stateWithPower` merge, `levelTier`; AV-11's hex helper; AV-12's `@State` dedup; CB-04's render split; CB-05's decoder helper and test rewrites; CB-09's `STYLES` test | | P1 App B; the audits |
| REJ-19 | SUI-05 as written (reload on new samples) | energy/perf | Saves no reloads with recording on; freezes the time axis with it off | | RES-swiftui §5 |
| REJ-20 | SUI-06's "avoid closures" reason | quality | Apple exempts closures that take a parameter | | RES-swiftui §5 |
| REJ-21 | A Bool passed to `CopyReportButton` | energy/perf | Widens the dependency to the whole split view | | RES-swiftui §5 |
| REJ-22 | Diacritic folding in Raw Data search | localization | Changes Russian search results | | RES-swiftui §5 |
| REJ-23 | SUI-20: `appearsActive` for lifecycle | quality | A styling hint, not a lifecycle event | | RES-swiftui SUI-20 |
| REJ-24 | SUI-21 as a test | tooling/CI | Guards a problem the code doesn't have; a convention line suffices | | RES-swiftui §5 |
| REJ-25 | Snapshot split, `scenePhase` for occlusion, a `Canvas` glyph, `drawingGroup` on charts, blanket `.equatable()` | energy/perf | Considered and not recommended by the research and its verifier | | RES-swiftui §5; PB §3.3 |
| REJ-26 | SW-10: typed `NotificationCenter` messages | quality | The notifications post off the main actor; current pattern is correct | the SDK has `MainActorMessage` types for them | RES-swift SW-10 |
| REJ-27 | SW-22 `InlineArray`/`Span`; SW-23 noncopyable `Continuation` | quality | Two allocations per key; noncopyable can't be captured by the escaping callbacks used | | RES-swift §4 |
| REJ-28 | `ExplicitSendable`, permanent `PerformanceHints`, experimental flags, typed throws everywhere, `@inline(always)`/`@specialized`, module selectors, `isolated deinit`, `weak let` | quality | Noise, library-hot-path tools, or no site | | RES-swift §4; PB §3.3 |
| REJ-29 | The Subprocess package | distribution | A dependency; keep Foundation `Process` | | RES-swift §4 |
| REJ-30 | Main actor by default for the widget | platform debt | WidgetKit calls the provider on its own threads | | P2 WP-10; PB §3.3 |
| REJ-31 | `--explicit-target-dependency-import-check`; per-function `@diagnose(StrictMemorySafety…)` | tooling/CI | A no-op with Swift Build; doesn't turn the check on | | RES-swift SW-16, §7; PB §3.3 |
| REJ-32 | SW-16 `package` access; `AllPublicDeclarationsHaveDocumentation` and one-line-summary lint | quality | Readability only, no size effect, 766-line churn; "`public` stays" | | R:435-436; P1 §6; RES-swift SW-16 |
| REJ-33 | E4's private-message spike (and private IOKit messages or notify keys generally) | energy/perf | The public "any" key already signals new registry data | | RES-energy §0, E21 |
| REJ-34 | E9: `NSBackgroundActivityScheduler` for update checks | energy/perf | Moves the first check to hours after launch; 4 wake-ups a day at stake | only for the periodic part, keeping the one-shot check | RES-energy E9 |
| REJ-35 | E12: KVO download progress | energy/perf | The poll runs only during a download; not shorter | | RES-energy E12 |
| REJ-36 | E16: MetricKit | energy/perf | 60-100 lines; delivery to an ad-hoc app unverified; no server | as an off-by-default Developer option that saves reports locally | RES-energy E16 |
| REJ-37 | C5: an xctrace launch trace on CI | tooling/CI | The runner has no battery; S7 on the M5 covers launch | | RES-energy C5 |
| REJ-38 | SEC-04: a runtime code requirement in the installer | security | Duplicates `checkBundle`; SEC-07 covers release mistakes at build time | | RES-security SEC-04 |
| REJ-39 | SEC-14: signal only our own widget process | security | No boundary crossed; would break the stale-widget fix for renamed copies | | RES-security SEC-14 |
| REJ-40 | SEC-15's environment wiping; SEC-11's size caps; the `dladdr` assertion; moving `contents: write` | security | A5-only threat or no benefit; caps could block a real update | | RES-security §6 |
| REJ-41 | Certificate pinning; fd-based verification; exact URL-prefix pinning | security | Ed25519 anchors trust; same-user attacker; GitHub builds the URLs | | RES-security §6 |
| REJ-42 | An Enhanced Security helper extension for device reads | security | Its sandbox blocks usbmuxd | | RES-security §6 |
| REJ-43 | App Attest | security | For attesting to an app's own server; there is none | | RES-security §6 |
| REJ-44 | Post-quantum update signatures | security | Later, with the key list | a later key rotation (SEC-05) | RES-security §6 |
| REJ-45 | Provisional notification authorization | security | Would hide charge-limit and heat alerts | | RES-security §6 |
| REJ-46 | A privacy manifest | security | Required-reason APIs are for iOS-family App Store builds; covered by SEC-16's guide text | | RES-security SEC-16 |
| REJ-47 | App Sandbox for the main app | security | Breaks SMC reads, device reads and Install and Relaunch | Developer ID or App Store plans | RES-security §5 |
| REJ-48 | SZ-12: disable reflection metadata | size | About 50 KB against SwiftUI's dynamic-property discovery | | RES-size SZ-12 |
| REJ-49 | SZ-13: a shared dynamic framework | size | Small or negative saving; launch cost; library validation without a Team ID | Developer ID, if duplication stays large | RES-size SZ-13 |
| REJ-50 | `-objc_stubs_small`, binary `.strings`, zlib-9, UDBZ, `lzma-level`, `package` for size | size | Tiny, worse compression, deprecated or undocumented | | RES-size "Not worth it", SZ-03 |
| REJ-51 | `-no_exported_symbols` on the widget; `-Xlinker -S` | size | ld64 refuses it with `-exported_symbol`; `-S` drops the debug map | | RES-size SZ-01, SZ-02 |
| REJ-52 | Selection glass in the tile pickers | quality | The maintainer chose the accent outline | only with a pixel test | R:440-441; P1 §8 |
| REJ-53 | The app writing into the widget's own container | security | Another app's data container, denied by default on macOS 27 for a different or absent Team ID | | P2 §8.3 |
| REJ-54 | Accessory widget families on the Mac | feature | macOS has none | | P2 §8.2, §8.4 |
| REJ-55 | Smart Stack relevance | feature | iOS, iPadOS and watchOS only | | P2 §8.2, §8.4 |
| REJ-56 | A Control Center control | feature | The app changes nothing on the system; the menu bar item already opens it | | P2 §8.4 |
| REJ-57 | Widget push updates, and any network in the widget | feature | Push needs the paid account; read-only local app | | P2 §8.2, §8.4 |
| REJ-58 | A pager on small widgets | feature | One `UserDefaults` domain for every instance: widgets would page together | | P2 §8.4 |
| REJ-59 | Configurable level thresholds | feature | Thresholds shared with the menu bar and the app | | P2 §8.5 Colours |
| REJ-60 | App Intents types outside the widget target, or imported by the app | localization | Strings from a package reportedly show raw keys; the app routes by URL and activity | | P2 §8.9, §8.11 |
| REJ-61 | DiskImageKit for the installer | platform debt | Covers ASIF and raw images for Virtualization only | | P2 WP-16 item 1 |
| REJ-62 | `TimelineView(.periodic/.everyMinute)` and `.timer`/`.relative` text in the widget | energy/perf | Seconds and extra renders; the date-offset style updates without them | | P2 §8.7 |

---

## The paid account: declined (2026-10-22), and what it would unblock

**Decided 2026-10-22: no.** The maintainer declined the paid Apple Developer Program account: not
now, and not planned before 1.0. His reasons: a non-commercial hobby project; he will not pay for
an Apple developer account for this app (he is willing to spend on help with development, not on
the account); and about zero users. The usage evidence (GitHub's REST API, 2026-10-22):
- DMG downloads across all releases: 14 in total (0.2.0: 1, 0.3.0: 2, 0.3.1: 4, 0.4.0: 1, 0.5.0: 2,
  0.6.0: 3, 0.6.1: 1, the last being a signature check during the release);
- signature (`.sig`) downloads: 5. Each in-app install fetches the `.sig`, so this is a
  privacy-free proxy for in-app updates (a re-check later the same day showed 15 DMG and 6 `.sig`
  downloads, one more of each for 0.6.1);
- repository page views: 2, by 1 visitor, in 14 days;
- no stars, forks or issues from anyone else.

So the users are, in practice, the maintainer alone. From 0.6.2 on, each release's DMG and `.sig`
download counts, printed by `scripts/release-stats.swift`, are recorded in ROADMAP's Releases table
a week after publishing. Through 0.6.x the app sends nothing for them; from 0.7.0 the anonymous
version count adds one column, the number of Macs that ran each version (DIS-11).

What follows, in the roadmap: Developer ID signing and notarization stay not planned, revisited only
if the maintainer changes his mind (DIS-01); Enhanced Security (SEC-01) and the package manager's
official catalog (DIS-03) stay not planned, since both needed notarization; the History and iPhone
& iPad widgets can use only the app-written feed (FEA-10, Q-W3 yes), if W0-3 passes, and are not
possible without the account if it fails; Open Anyway on each DMG install, and permissions or
placed widgets possibly lost when the DMG replaces the app, are documented known limitations at
1.0. The analysis below is kept as background.

**Background: what the account would unblock.** The stance before the decision was "Developer ID
signing … not planned until there is a paid developer account" (R:705-706). Items blocked wholly or
partly by it, from the tables above: DIS-01, DIS-02, DIS-03, DIS-06 (uncertain), FEA-10 (an App
Group instead of an unverified temporary exception), FEA-28, FEA-29 to FEA-34 (iOS distribution
beyond 7-day re-signing), REJ-47 and REJ-49 (revisit conditions), REJ-57 (push), plus constraints
written into the sources: permissions tied to the ad-hoc identity are asked again after updates
(R:180-181, UG:493-494), and anything beyond IOPS for accessories needs Bluetooth permission, which
ad-hoc signing loses on every update (R:669-670).

The reasons that were weighed for revisiting before 1.0, each a claim with its source:
1. **First impression:** every new user, and every DMG install, goes through Done → Privacy &
   Security → Open Anyway (RM:22-25, UG:35-43). In-app updates avoid it only after the first
   install (R:161-201).
2. **0.7's widgets:** the History and iPhone & iPad widgets rest on a temporary-exception
   entitlement whose behaviour under ad-hoc signing on macOS 27 is unverified (W0-3, FEA-03); an App
   Group, the documented route, needs a Team ID (P2 §8.2, P2:1316). Without either they wait
   (P2 §8.3 candidate C).
3. **Stable identity:** login item, notification and other grants, and possibly placed widgets,
   survive updates more reliably with a stable signature (R:180-181, R:206-208). SEC-18's
   self-signed identity covers part of this without the account, but not App Groups (P2 WP-20).
4. **Cost:** $99 a year (R:642).

Unverified here: that notarization accepts an app that loads a private framework with `dlopen`
and resolves a private symbol with `dlsym` (notarization is a malware scan, not an API review, to
the best of current knowledge; uncertain for this app), and that library validation under a
Developer ID signature still allows MobileDevice (an Apple-signed framework, so it should). A
one-evening spike with the account would settle both, if the account is ever bought.
