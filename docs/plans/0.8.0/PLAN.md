# BatteryPulse 0.8.0: the plan (answers in the app)

Written 2026-10-30, the day 0.6.2 was released (`v0.6.2`, `main` at `0ecca33`), while 0.7.0
("Widgets you configure", `docs/plans/0.7.0/PLAN.md`) is being implemented on `claude/070-*`.
Nothing in 0.8 starts before 0.7.0 is published. Every 0.7 result this plan depends on is named in
§2, with what 0.8 does if it never comes.

**Taken in on 2026-11-06 (A-0),** the day 0.7.1 ("The widgets that waited for the feed", ROADMAP
Stage 1.9) shipped, a release this plan didn't foresee: 0.8 starts from v0.7.1 (`main` at
`48b5da0`), not from v0.7.0 (`5e2e5c7`). 0.7.1 brought the feed (`Widget/feed.json`), the History
and iPhone & iPad widgets, the large Battery widget's History chart, the widgets in BatteryPulse's
language, Settings that scroll (0.7.1's S-1), What's New after every update, and the build-number
clock (0.7.1's B-1). §2.1's last column says what 0.7.0 and 0.7.1 shipped of this plan's inputs;
the six preparation packages (E-3, A-6a, P-2a, X-1a, X-2a, E-2), built and reviewed before 0.7.1,
come in with A-0; the maintainer added F-1 and T-1's item 7 (2026-11-06); and the rounds (§5) hold
what remains.

**Scope.** RD §3.3 is the scope: four answers a non-expert gets inside the app (is my battery OK,
why isn't it charging, what does this number mean, how do I report a problem), working with
VoiceOver and the keyboard. M-10 and M-11 set the rules (decided by delegation, 2026-10-22). It
also takes the INV rows RD places in 0.8, and what 0.7's plan hands to 0.8: FEA-35's second half
(the Charge Limit's configured percentage), NEW-01's other causes, the session script's
`charge-limit` step, and 0.7's conditional carry-overs (§2.1). W-9's widget extras stay after 1.0,
and FEA-20's widget field stays in 1.1: 0.8 keeps off the widget, but for A-2's number in its
Charge limit field, through 0.7.1's feed (I-6, §3).

**What this plan changes in RD §3.3, from the evidence** (§2.4 and Appendix B have the details):
- **Bit 12 is not decoded.** RD gives `NotChargingReason` bit 12 a meaning [unverified, CLR:96];
  the only bit-12 reading on the M5 is in `ChargerInhibitReason` (0x10001000), not
  `NotChargingReason` (Session A).
- **powerd's charging plist is read with `NSKeyedUnarchiver`'s class substitution, not a generic
  walk.** On Linux, keyed-archive UIDs decode to an opaque type, so a walk of `$objects` loses
  every link; `NSKeyedUnarchiver.setClass(_:forClassName:)` with a stand-in class decoded a
  synthetic `ChargeCtrlPolicy` archive on Linux (a scratch test, Appendix B).
- **The heat and weak-adapter causes wait for captures.** The capture format holds no thermal
  state, and no fixture shows a charger key for either; 0.8 adds no capture-format key for an
  unproven cause (Q8-5). An info button lists Apple's possible reasons without naming one (Q8-1).
- **The limit last set (`prior.limit`) is not shown** on battery: it read 80 with the limit at
  100 % (Q8-2). The number shows on AC, from powerd's policy.
- **`systemChargeLimitPercent` doesn't bump `formatVersion`.** 0.7's S-1 rule adds keys without
  a bump; the notes' "For scripts" line names the key (RD's "NEW-11's format version notes it").
- **The sittings are hands-free,** as the maintainer asked on 2026-10-23: about 45 minutes of his
  time in all, against RD's 135 by hand (§6).

**Sources and how they are cited** (as 0.7's plan; new short names below):

| Short | Source |
|---|---|
| P7 | `docs/plans/0.7.0/PLAN.md` at `0ecca33` (main's copy; the package branches cut from 0.6.1 carry an older one, and `claude/070-w0` and `-integration` W-0's re-resolved copy). The v0.7.0 tag won't hold it: 0.7's last commit removes `docs/plans/0.7.0/` (P7:3025-3029), so A-0 reads P7, its Appendix C included, at 0.7's `<keep>`, the commit before that removal, reachable through the 0.7.0 release PR's `refs/pull/<n>/head` |
| W | `docs/plans/0.7.0/widgets.md` |
| AC62 | `docs/plans/0.7.0/0.6.2-appendix-c.md` (0.6.2's Appendix C), with `sessions/A.md` and `sessions/B.md` |
| P71 | `docs/plans/0.7.1/PLAN.md`, 0.7.1's plan, readable at `dbc696a979b0cad265ae554d1e6d69db1eac1572` in the 0.7.1 release PR's head (`refs/pull/14/head`) |
| AC70 | 0.7.0's Appendix C, `docs/plans/0.7.1/0.7.0-appendix-c.md` at the same commit |
| AC71 | 0.7.1's Appendix C, `docs/plans/0.8.0/0.7.1-appendix-c.md` |
| AP71 | 0.7.1's after-publishing check on the M5 (its Session D3, 2026-11-06), `docs/plans/0.8.0/0.7.1-session-d3.md` |
| RD, INV | `docs/plans/1.0/ROADMAP.md`, `docs/plans/1.0/INVENTORY.md` |
| R, UG, RM, CL | `docs/ROADMAP.md`, `docs/USER_GUIDE.md`, `README.md`, `CLAUDE.md` (CL wins over every other source) |
| file:line | a file in `Sources`, `Tests`, `scripts`, `Resources` or `.github` |
| HIG | Apple's Human Interface Guidelines pages, named by topic |

- **Revision:** every file:line is at `0ecca33` (v0.6.2) unless it names a branch. 0.7.0 and 0.7.1
  edited many of the same files, so each package re-resolves its own at its start (A-0 item 3);
  the intake's own citations (§2.1's last column, Appendix C) are at v0.7.1 (`48b5da0`).
- **0.7 branches** are cited as `origin/claude/070-<pkg>` at the commit read on 2026-10-30: `s1`
  `1ddbe23`, `w3a` `2435519`, `w13` `f94e3d1`, `r1` `583c67f`, `toolchain` `0d26a6d`,
  `integration` `8a0b222`.
- **Apple URLs:** fetched on 2026-10-30.

**Marks:** **[unverified]** nobody has checked it; **[uncertain]** the evidence is partial;
**[inference]** reasoned from verified facts, not observed; **[estimate]** a planning number.

**IDs:**
- Packages: A-0 (intake); A-1 to A-7 (the answers); X-1, X-2 (accessibility); P-1, P-2
  (protection: the sentinel and update safety); E-1 to E-3 (the engineering lane); F-1 (the
  feed's placements, added at the intake); T-1 (the session script); K-1, V-1 (0.7's conditional
  carry-overs); L-1 (localization, docs, What's New); D1-D3. A package split into a core half and
  an app half has `a` and `b` (A-6a, A-6b).
- Gates are `G8-…`; new maintainer questions are `Q8-…`. RD's `M-…`, `C…` and `NEW-…`, INV's row
  IDs and 0.7's `W-…`, `G7-…`, `Q7-…` keep theirs.

This file is English only and names no third-party product, so it can be committed under
`docs/plans/0.8.0/` as is (`LocalizationCatalogTests` scans `docs/`). CLAUDE.md wins over
everything in it.

Contents:
1. At a glance
2. Inputs and dependencies on 0.7
3. How every package runs
4. Work packages
5. Order and parallelism
6. The maintainer's sittings
7. Gates and their defaults; cut line; frozen surfaces
8. Localization
9. Size budget
10. Energy
11. Privacy
12. Docs
13. Release steps
14. The maintainer's questions
- Appendix A: traceability of every 0.8 item
- Appendix B: facts verified for this plan, and what stays unverified
- Appendix C: facts 0.8 records (filled during the release)

---

## 1. At a glance

- **What 0.8 is:** the second feature release on the road to 1.0, with one headline: **answers in
  the app** (RD §3.3). It makes 1.0's promise 5 ("usable by a non-expert", RD §2) real inside the
  app, and lays the tests 1.x keeps (C9, C12, C14). 0.8 and 0.9 stay apart: new UI lands here, so
  0.9.0 can freeze and 0.9.x prove stability (RD §3). It starts from v0.7.1 (the intake above).
- **The answers (never cut, except where §7.2 says):**
  - **Why it isn't charging (A-1, NEW-01).** On Overview and in the menu bar popover, a cause
    shows only when a real fixture proves it (M-10). 0.7's W-14 brought the first, the Charge
    Limit's hold (bit 24). 0.8 turns W-14's Boolean into a cause type, adds the optimized hold if
    QUA-06's capture comes (G8-2), and a weak adapter or heat only if a capture shows a charger
    key for them (G8-3, G8-4). With no proven cause, an info button lists Apple's possible
    reasons and names none (Q8-1). Each cause gets a Demo Mode scene and a Linux test against its
    fixture.
  - **The Charge Limit's number (A-2, FEA-35's second half; first to cut).** Read from powerd's
    charging preferences file by the unsandboxed app, on AC only, and shown on Power ("80 %",
    "80 %, reached") and in Overview's sentence, in the widget's Charge limit field through 0.7.1's
    feed (I-6), and in `bpulse --json` as `systemChargeLimitPercent` when known. It ships only if
    its check passes on the M5, from the app's own process (G8-1); otherwise the number stays
    unknown, a known limitation. Nothing sets a limit, and no private framework is loaded (M-3).
  - **Is my battery OK (A-3, NEW-02).** A summary at the top of Health: condition, maximum
    capacity, and cycles out of the rated count, as label-value pairs, in macOS's own words.
  - **What does this number mean (A-4, NEW-03).** Every metric that isn't obvious gets a help tag
    and, in the main window, an info popover, taken from the guide's "Understanding the
    numbers". A new guard fails on a metric label without an explanation.
  - **Welcome (A-5, NEW-04).** One window, one line and one button each: where BatteryPulse
    lives, turning off macOS's battery item, one charge notification, adding the widget, iPhone
    reading, and 0.7's anonymous version count, which Welcome must keep announcing (NEW-24).
  - **Report a Problem (A-6, NEW-05).** Help → Report a Problem… previews one redacted text file,
    saves it where the user chooses and then opens GitHub's issue chooser. Nothing is sent
    (M-11). Crash-report contents go in only on a second choice.
  - **Help at the release's tag (A-7, NEW-06).**
- **Accessibility:** chart descriptors for History (X-1, A11Y-01) and VoiceOver and the keyboard
  for the custom components and the named paths (X-2, NEW-07). The sittings run C10's checks: the
  accessibility tree in English and Russian, the keyboard paths, the contrast audit (A11Y-03), the
  Stage 1.4 pass (A11Y-02) and the menu bar icons (A11Y-04).
- **The M5 checks 0.7.0 and 0.7.1 shipped without** (ROADMAP Stages 1.8 and 1.9; I-13, I-14):
  Session R8 runs them beside 0.8's own (§6.4 step 11c), the widgets' trees for every kind.
- **Resilience:** a sentinel around the private calls (P-1, NEW-14) and update safety (P-2,
  NEW-16 with SEC-07): the installer refuses a bundle that needs a newer macOS, checks that the
  volume can swap, and puts the old copy back if the new one doesn't launch.
- **The engineering lane** (Linux only, no maintainer time): frozen-surface tests with golden
  outputs (E-1, NEW-08; M-6 enters ROADMAP's Decisions), storage, perturbation and degradation
  tests (E-2, NEW-09, NEW-10), and the log-privacy guard with the legacy migration removed (E-3,
  NEW-12, QUA-15). E-2 and E-3, like the core halves of A-6, P-2, X-1 and X-2, were built and
  reviewed before 0.7.1 and come in with A-0 (§3); what is left of them is E-2's gaps (C9).
- **The feed's privacy** (F-1, the maintainer's addition of 2026-11-06): a removed widget's section
  leaves 0.7.1's feed within about an hour, not when BatteryPulse quits.
- **What 0.8 doesn't touch:** the widget, but for A-2's number in its `systemChargeLimit` field
  through the feed (I-6; FEA-20 is 1.1), settings keys (none added: §7.3), the capture format, and
  what is sent (nothing new: §11).
- **Maintainer time** (§6) [estimate], hands-free as he asked (2026-10-23):
  - **The look shoot,** a short local session on the M5: about 5-8 minutes of his (the start line,
    one yes, the approvals, the adapter at two beeps for the Charge Limit check), plus 2 if he
    plugs in a low-wattage adapter (Q8-3).
  - **The look review,** at the desk from the shots: about 15 minutes.
  - **The Russian review,** at the desk: about 10 minutes.
  - **Session R8,** the release candidate, hands-free: about 6-8 minutes at its start, a passive
    day, and 3-4 at its end (F12 is the session's), plus 1 once before to check the CLI; 5 more
    only if he chooses to listen to VoiceOver (Q8-6).
  - **The after-publishing check,** a short session: about 2 minutes.
  - **Optional:** the hold watch (I-8, G8-2), a night of his choosing before D1: about 2 minutes.
  - In all about 42-48 minutes, against about 135 by hand in RD §3 (40 + 85 + 10 for Xcode).
  - **Not a sitting:** the backup key (M-9, decided yes; K-1 moved here, I-11), about 5 minutes
    in Terminal whenever he chooses before C8 (P7 §14's steps), not counted above.
- **Budget** [estimate]: about 29-40 implementation and review runs in all (§7.2; RD §3.3 says
  30-38). The six preparation packages took about 7-9 of them before 0.7.1; about 25-33 remain,
  with A-2's widget half and F-1 added, plus K-1 (1, once the key exists; §2.1's one conditional
  item left) and 3 for fixing forward. The never-cut work left is about 18-23.
- **Not in 0.8** (Appendix A has each row): `bpulse` inside the app (M-7), `SECURITY.md`, the 1.0
  docs and README's status line, closing the verification matrix, the Russian screenshot set and
  the beta styles' final stance (all 0.9.0); the soak, energy budgets and upgrade matrix (0.9.x);
  FEA-20 (1.1); W-9 (after 1.0); setting a limit (FEA-27, M-3); grades of our own; telemetry
  beyond the version count; MetricKit; °F. The History and iPhone & iPad widgets and the feed,
  which this line once gave to 1.1, shipped in 0.7.1 (Stage 1.9).

---

## 2. Inputs and dependencies on 0.7

### 2.1 What 0.8 takes from 0.7, and what it does if that is missing

0.8 starts from v0.7.1 (`48b5da0`), not the v0.7.0 tag this plan was written for. A-0 checked each
row on 2026-11-06 against 0.7.0's Appendix C (AC70), 0.7.1's plan (P71, whose §5 names the rows
0.7.1 changes: I-5, I-6, I-7, I-9, I-13, I-14), 0.7.1's Appendix C (AC71), its after-publishing
check (AP71) and the code at v0.7.1; the last column says what happened, and the third and fourth
columns stay as written.

| # | 0.7 item | What 0.8 needs from it | If it was cut, moved or missing | What happened (A-0, 2026-11-06) |
|---|---|---|---|---|
| I-1 | W-14: `SystemChargeLimit`, `isAtSystemChargeLimit`, `WidgetStateWord.chargedToLimit`, `BatteryMotionKey`'s flag, the Demo scene, Power's "Charge limit: Reached", and the fixture `m5-macos27-charge-limit.plist` (P7:1444-1527) | A-1's cause type grows from it; A-2's number fills its row | **Moved whole to 0.8** (only by G7-18, already answered: the capture came, P7:2605): A-1 first lands W-14 as P7 specifies (+2 runs, its frozen field raw value `systemChargeLimit` included), then generalizes it | **Shipped whole in 0.7.0** (G7-18 answered): `SystemChargeLimit.swift`, `isAtSystemChargeLimit`, `WidgetStateWord.chargedToLimit`, `BatteryMotionKey`'s flag, the Demo scene (`DemoBattery`'s `isAtSystemChargeLimit`, which sets bit 24), Power's "Charge limit: Reached" and the fixture are at v0.7.1. So no +2: A-1 generalizes them. Never seen on the M5 (Session R's step 9b never ran: AC70, AC71's F rows), so the look shoot and Session R8 see them first (§6.1 steps 2-3, §6.4 step 9) |
| I-2 | W-13: the version-count toggle in Settings → General, three settings keys, What's New's "Anonymous version count" row for updaters from before 0.7 (P7:1729-1731, P7:1772-1776) | A-5 keeps the toggle in Welcome (NEW-24's announcement); L-1 keeps appending the row | **Moved to 0.8** (only if review found a promise of P7 §11 it couldn't keep, P7:2611): 0.8 carries W-13 whole before A-5 (+2 runs), with its own privacy review; A-5 then places the toggle | **Shipped in 0.7.0 as planned:** the toggle, `anonymousVersionCount`, `lastCountedVersion`, `versionFirstLaunch`, and What's New's row for updaters from before 0.7 (absent after 0.7.1's update from 0.7.0, as it should be: AP71's D3-count-row); v0.7.0's `BatteryPulse-count.txt` had 3 downloads on 2026-11-06 (AC71's D3 rows). So no +2: A-5 places the toggle, L-1 keeps the row. The toggle was seen on in Settings → General (AP71's notes), not yet greyed under Never |
| I-3 | S-1: `MachineJSON` with `formatVersion` (`MachineJSON.swift:7-8` on `origin/claude/070-s1`) and ISO 8601 device dates | E-1's goldens pin these 1.x shapes; A-2 adds a key under its rule | Never cut in 0.7 (G7-14). If absent: E-1 waits for it, and A-2's key goes in without a version field | **Shipped in 0.7.0:** `MachineJSON` with `formatVersion` 1 per shape (`snapshotFormatVersion`, `deviceBatteryFormatVersion`) and ISO 8601 device dates (AC70's S-1 row); 0.7.1's D1 found no output difference from v0.7.0 (AC71's D1 item 1). E-1 pins them; A-2's key goes in under the rule |
| I-4 | W-1: `localizedLiterals(in:)` in `LocalizationCatalogTests` and the widget types in `BatteryCore/Widget/` | X-2 extends the scanner to `accessibilityValue(`/`accessibilityHint(`; A-3 reuses `WidgetCondition` if it fits | X-2 extends today's `localizingCall` regex (`LocalizationCatalogTests.swift:19-21`) instead | **Shipped in 0.7.0:** `localizedLiterals(in:)` (`LocalizationCatalogTests.swift`) and the widget model in `BatteryCore/Widget/`, `WidgetCondition` with it. The scan doesn't read `accessibilityValue(` or `accessibilityHint(` yet, so X-2b extends `localizedLiterals(in:)` |
| I-5 | W-6's `WidgetChartSummary` (stretch, P7:1954) | X-1 reuses it for chart descriptors | **Expected missing** (W-6 is stretch): X-1a builds `ChartSummary` in BatteryCore (+1 run, RD §3.3) | **Shipped in 0.7.1** (W-6): `WidgetChartSummary` (`BatteryCore/Widget/WidgetChart.swift`), one VoiceOver label per widget chart, not a descriptor model (P71 §2.3 item 13). So X-1a built `ChartSummary` for the app's charts anyway (done before 0.7.1; its carry-over names the widgets' label beside it), and X-1b maps it |
| I-6 | W-5's feed (stretch) | The widget field `systemChargeLimit` could show "80 %" | **Expected missing:** the field keeps "Reached" (RD §3.3); FEA-35's widget half goes to 1.1 with the feed | **Shipped in 0.7.1** (W-5): the feed, version 1, whose schema only gains fields, read by the widget through its one read-only exception (seen on the M5: AC71's F rows, AP71). So the widget can show the number: A-2 takes FEA-35's widget half, as §3 allows (A-2 item 8: a feed field and the `systemChargeLimit` field's value, whose meaning is frozen and value isn't), still first to cut, +1 run [estimate] |
| I-7 | W-12: the session script with `charge-limit` and `hold-watch` steps, the hands-free helpers, the menu-bar shot method that replaces CGWindowList (P7:524-532, P7:1339-1344), and `SESSION-R.md` | T-1 builds 0.8's sessions on them | **Expected missing:** P7's D3 removes `docs/plans/0.7.0/` and copies nothing forward (P7:2044-2047), unlike 0.6.2's D3, which copied the tooling for 0.7 (P7:263). So A-0 restores them from 0.7.0's `<keep>` commit or the release PR's head into `docs/plans/0.8.0/` (T-1 counts the run that adapts them), unless 0.7's D3 is asked to copy them first. No menu-bar method: T-1 uses the AX frame of the status item, else a computer-use crop (§6.7) | **Came forward, nothing to restore:** 0.7.1's D3 moved its seven tools (`m5-session.sh`, `SESSION-R.md`, `ui.swift`, `frames.swift`, `swap.swift`, `start-session-r.sh`, `start-short-session.sh`) to `docs/plans/0.8.0/`, with `ci.yml`'s dry run, `bash -n` lines and type-checks (AC71's D3 rows). They still name 0.7.1 (`claude/071-integration`, `~/bp-071/`), which T-1 re-points. Their launchers already print only their runbook section, and P11 reads the menu bar item's frame by AX (Session F, AP71), so T-1 starts from both |
| I-8 | QUA-06's `hold-watch` night (P7:2436-2438): whether an optimized hold was seen, and whether it sets bit 24 | G8-2: the optimized-hold cause | **No hold seen** (nobody knows which night macOS holds): T-1 offers the step again before 0.8's D1; still none: that cause waits until after 1.0, and today's "Charging on hold" stays (RD §5.1 QUA-06) | **No hold seen:** neither release ran the `hold-watch` night (0.7.0 had no Session R, AC70; 0.7.1 only the short feed check, AC71's F rows). The step is in the tools (`hold-watch`, `SESSION-R.md`'s Hold watch); T-1 offers it again before D1 (§6, optional); still none: G8-2's default |
| I-9 | D1's build-number clock that only grows (P7:2022-2028) | 0.8's look-shoot build and RCs must sit above the installed 0.7.0 | If 0.7 shipped without it: 0.8's A-0 lands it first (one commit), before any M5 build | **Shipped in 0.7.1** (B-1): `scripts/build-number.sh`, whole seconds since 2026-01-01T00:00:00Z, read once per job in `ci.yml` and `release.yml`, pinned by `BuildNumberTests`: RC-U 26725241, RC-F 26725995, the published v0.7.1 26740846 (AP71's About), v0.7.0 9. Every 0.8 CI build sits above v0.7.1; no A-0 commit |
| I-10 | The installer's pre-swap end of the widget extension, pinned by a source test (P7:953-956) | P-2 edits the same function; the test keeps the order | If the test is missing: P-2 adds it | **In place since 0.6.2:** `UpdateInstallTests.endsTheWidgetExtensionRightBeforeTheSwap`; seen on the M5 at RC-U's install (Session F) and at 0.7.1's update (AP71: 1 found, 1 ended by SIGTERM, 65 ms, no CHSErrorDomain 1103 line). P-2a (done) keeps the order and its test |
| I-11 | K-1, the backup key's public half (P7:1641-1652, cut-order 8) | C15 needs two keys at 1.0 | **If it moved to 0.8:** K-1 runs here, once the maintainer has generated the key (§14 M-9 steps); if he never does, ROADMAP records the accepted risk (C15) | **Moved to 0.8** (the maintainer's decision, 2026-10-31, AC70): `ReleaseSigning.publicKeys` holds one key at v0.7.1. K-1 runs in C8 once he has generated the key (M-9, §14); else ROADMAP records the accepted risk (C15) |
| I-12 | R-1's `docs/VERIFICATION.md` (NEW-18; cut-order 7) | D3 fills 0.8's rows | **If it moved to 0.8:** V-1 creates it from `origin/claude/070-r1`'s draft (`583c67f`, +153 lines) | **Shipped in 0.7.0** (R-1), with 0.7.1's Session F column since its D3 (AC71's D3 rows). So no V-1: D3 fills 0.8's rows and Session R8's column. 0.7.1's after-publishing check (AP71) isn't in it yet (§12) |
| I-13 | G7-11's reload-delivery measurement (P7:2598) | — | If the logged day gave none: Session R8's day measures it (§6.5) | **Still open:** 0.7.0 ran no logged day (AC70) and 0.7.1 only the short feed check (AC71's F rows), so G7-11's default holds for all four kinds; Session R8's day measures reload delivery per kind (§6.5) |
| I-14 | W-0 item 9's open checks: the menu bar item on a dark bar and WP-18's Xcode items (P7:524-541), if 0.7's Session R didn't close them; and G7-12's widget tree read in English and Russian (P7:2367-2386), whose default leaves the row open (P7:2599) | C10 counts every widget family as reachable and named (RD:326-327), and 0.8's is the VoiceOver and keyboard sitting that passes C10's script (M-12; RD §3.3's exit criteria) | Session R8 runs them (§6.4 step 7, step 3 for the widgets, and step 11b for the Xcode items) | **Still open, all of it:** neither 0.7.0 nor 0.7.1's short feed check ran the dark bar, WP-18's Xcode items or the trees (AC71's F rows, `docs/VERIFICATION.md`), and 0.7.1 added the History and iPhone & iPad kinds, whose trees were never read either. Session R8 runs them (§6.4 steps 3, 7 and 11b), the trees for every kind in both languages, with the rest of the M5 checks 0.7.0 and 0.7.1 shipped without (ROADMAP Stages 1.8 and 1.9; §6.4 step 11c) |
| I-15 | W-3c: `PageID`, `WindowOpener.showMainWindow(page:)`, and the History-over-Raw-Data fix (P7:518-523) | A-4's popovers and X-2's keyboard paths run on `MainView` as W-3c leaves it | If it slipped: X-2 takes the History fix if Session R8's keyboard walk reproduces it | **Shipped in 0.7.0** (W-3c): `PageID` (`BatteryCore/Widget/WidgetRoute.swift`), `WindowOpener.showMainWindow(page:)` (`App/AppSettings.swift`) and Raw Data leaving at once on a page switch (`MainView`). The fix isn't seen on the M5 (`docs/VERIFICATION.md`'s History row), so Session R8's keyboard walk checks it |
| I-16 | 0.7's toolchain: CI's macOS job on Xcode 27.2 (Apple's release candidate 27B48), the Linux job still on Swift 6.4, the cloud sessions on Swift 6.4.2 (`origin/claude/070-toolchain`, `0d26a6d`'s message) | A-6 uses `fileExporter(…item:…)`; the `FileDocument` overload is deprecated in the 27.2 SDK (Appendix B) | Nothing changes: the `item:` overload is what the app already uses (`DeveloperView.swift:125-133`) | **Moved on:** CI's macOS job has Xcode 27.2's release (27B52; a runner on an older image still has the candidate, 27B48, at the same path) with Swift 6.4.2, the Linux job `swift:6.4-noble`, cloud sessions Swift 6.4.2 (AC71's V-0 rows; CL). The app's `fileExporter` calls use `item:` (`DeveloperView.swift`, `Main/HistoryExport.swift`): nothing changes |

### 2.2 The facts 0.8 builds on (from 0.6.2's record)

- **Bit 24** of `ChargerData.NotChargingReason` (0x01000000) is set while the Charge Limit holds,
  in AppleSmartBattery and its child AppleChargerData; it clears at 100 % and returns at 80 %;
  `IsCharging`, `ChargingCurrent` and `IPDChargingAllowed` follow it (AC62:70; `sessions/A.md`
  21:37 and 23:48).
- **Bit 7** (128) reads in every on-battery M5 fixture and 10 s after a plug-in
  (`m5-macos27-plugged-in-10s.plist:421-422`), and Session A read it 5 s after a plug-in, gone at
  the gauge's next update (`sessions/A.md`, 10:30). 0.8 shows no cause for it: its meaning on AC
  is an inference.
- **The configured number:** at the 80 % hold, `pmset -g battlimit` printed two entries, each
  `chargeSocLimitSoc` 80 with reason `manualChargeLimit`; powerd's plist held one
  `ChargeCtrlPolicy` (`soclimit` 80, `reason`, `drain`, `isEndOfCharge`, `noChargeToFull`,
  `terminated`, `owner`, `token`); the prior limit read 80. At 100 %: no policy, "No battery level
  limits set", prior limit still 80. On battery: no policy from about 5 minutes after unplugging;
  back at plug-in, 3 s before the adapter was logged, with the charge at 72 %, below the limit
  and before charging began (AC62:70; `sessions/A.md` 22:30, 23:48, 10:30). No read was taken
  while the Mac was charging toward the limit.
- **The SMC:** `bpulse --smc` lists `CHLT` (3 bytes) and `CHNC` (8), no `CHLS`, without values
  (AC62:70), because it reads values only for `B0`, `BC`, `BN`, `TB` and `SBA`
  (`Sources/bpulse/main.swift:305-306`).
- **The maintainer's limit is 100 % today** (Session B, 2026-10-30: `sessions/B.md:47`, `:403`),
  so the `charge-limit` step sets one, with his yes, and puts it back (§6.1).
- **Session B's lessons** (P7:495-541): CGWindowList lists no menu bar item window on macOS 27.2
  (P11); System Settings panes by URL open the wrong pane for appearance, desktop and displays
  (P8; the Battery pane's URL passed); Notification Center can't be named in a computer-use
  request (P10), so widgets are shot by the script; computer use leaves a 28×40 pointer overlay;
  banners at layer 23 block the desktop click; a widget changed by a step keeps its old render
  until a reload (F8-ru).
- **Today's after-publishing check** (0.6.2, 2026-10-30, as reported to the orchestrator; not yet
  in the repository [unverified here]): the session had to open BatteryPulse with a Dock presence
  before computer use asked for access; the widgets were shot by the script; the maintainer must
  not install the update himself before the session starts; the runbook's start sentence printed
  more than its section. §6.0 turns each into a rule.

### 2.3 Decisions in force

- **M-3** (RD:1495-1513): no setter; no private framework (PowerUI) for reading the limit; a
  read-only undocumented source that loads no private code is allowed, with its guard exception
  and caveats (clarified 2026-10-23).
- **M-6** (RD:1553-1560): machine outputs and exit codes frozen for 1.x; the text report, `--help`
  and the text of `--smc` and `--watch` may change with a line in the notes. It enters ROADMAP's
  Decisions with NEW-08 (E-1).
- **M-10** (RD:1600-1609): health is facts only, as label-value pairs; a "not charging" cause
  appears only when proven; Welcome is one window, not a tour; no counted phrases (`%@` only).
- **M-11** (RD:1611-1620): Report a Problem saves NEW-05's contents after a preview; nothing is
  sent; crash-report contents only on a second choice.
- **M-1** (no paid account), **M-5** (no dates), **M-12** (about two sittings per release; one
  VoiceOver and keyboard sitting) and **C14** (1.x only adds) hold as in RD §6 and §2.3.
- **M-9** (RD; decided yes by delegation, 2026-10-22): a backup release key, which only he
  generates; K-1 moved to 0.8 (I-11) and waits for its public half (§14).
- **0.8's own questions (§14), at the intake (2026-11-06):** Q8-1 to Q8-6 are unanswered, so their
  defaults hold until he answers. The look review (§6.2) asks the look questions, Q8-3 is asked
  before the look shoot, and Q8-6 at Session R8's day end; nothing is asked of him now.
- **The maintainer's standing requests:** hands-free sessions (2026-10-23); he decides only what he
  sees or does (RD §1.2 item 8); What's New for every version, from 0.7.1 on (his standing rule;
  ROADMAP Stage 1.9's decisions).

### 2.4 Where this plan departs from RD §3.3, and why

| RD §3.3 says | This plan | Why (Appendix B) |
|---|---|---|
| Bit 12 of `NotChargingReason` is "a drain toward a limit below the charge" [unverified, CLR:96] | Not decoded, in either key | The only M5 bit-12 reading is `ChargerInhibitReason` 0x10001000, with the limit set below the charge (`sessions/A.md` 23:48); `NotChargingReason` read 0x01000000 then |
| BatteryCore walks the archive's `$objects` and `$top` generically | `NSKeyedUnarchiver` with `setClass(_:forClassName:)` maps `ChargeCtrlPolicy` to a stand-in class in BatteryCore | Linux decodes UIDs to an opaque `_NSKeyedArchiverUID` (the research's scratch test); the stand-in decoded a synthetic archive on Linux, XML and binary (this plan's scratch test) |
| The thermal state is a cause | Only with a capture that shows a charger key at the time; no capture-format addition | No capture holds the thermal state (`MacPowerParser.swift:40-45`); Apple ties a charging stop to battery temperature, not to the thermal state (Apple's guide mh29198; `ProcessInfo.ThermalState`'s page never mentions charging) |
| A weak adapter is a cause [uncertain: a heuristic] | Only with a capture that shows a key for it | A heuristic is not proof (M-10); `AdapterDetails.ErrorFlags` is a candidate key, unparsed (`RawKeyGlossary.swift:102-105`) and in no Mac fixture (only the iPhone fixture's adapter entry holds it, at 0) |
| The prior limit shows on battery as the limit last set | Not shown (Q8-2) | It read 80 at 100 %, so on battery it can't tell a limit from none |
| "NEW-11's format version notes it" | No `formatVersion` bump; a "For scripts" line in the notes | S-1's rule: keys are only ever added, and only a rename, removal or change of meaning bumps (`MachineJSON.swift:7-8`, `origin/claude/070-s1`) |
| UG:530-559, UG:656-663; "23 `.public` sites"; C10's Stage 1.4 list at R:298-301 | UG:533-563, UG:659-666; 25 lines with 37 occurrences in 11 files; R:370-373 (R:298-301 is now the menu bar icon styles) | Counted at `0ecca33`; RD counted an older base |
| A look sitting of about 40 minutes and an RC sitting of about 85, by hand | A hands-free look shoot, two desk reviews and a hands-free Session R8: about 42-48 minutes of his time | The maintainer's request of 2026-10-23 (RD §1.2 item 7) |

L-1 corrects RD's and INV's lines at D3 from what shipped.

---

## 3. How every package runs (0.7's practices, kept)

P7 §3 applies in full: an implementation run then a separate review run, one commit per item,
format, build, test and lint before each commit, a green macOS job for Darwin code, `--no-ff`
merges, at most two agents and never two on one file, measure first, rules with guard tests,
pure decisions in BatteryCore, gates with defaults, frozen values decided before D1, session
wording, facts to Appendix C. Only these differ:

- **Branches:** the integration branch is `claude/080-integration`, from v0.7.1 (`48b5da0`), with
  this plan from `claude/080-plan` and 0.7.1's after-publishing record on it (`63a01f2`); packages
  are on `claude/080-<pkg>`, look-shoot builds and spikes on `claude/080-spike-*` (never merged). A
  branch whose history must change gets a new name, never a force-push: the six preparation
  packages come in as `claude/080-<pkg>-r` (A-0).
- **The "before"** is v0.7.1: CI's size report (RC-U's, whose code v0.7.1 is: Appendix C), the
  golden outputs E-1 commits (0.7.1's D1 found no output difference from v0.7.0, AC71), and for
  `perf` lines the last session that logged them, 0.6.2's Session B (0.7.0 and 0.7.1 logged no
  day: AC70, AC71's F rows).
- **Done before 0.7.1:** the six preparation packages (E-3, E-2 and the core halves A-6a, P-2a,
  X-1a, X-2a) were implemented and reviewed on their branches before 0.7.1 and come in with A-0.
  Their §4 sections stay as the record of what they build; the rounds (§5) hold the rest.
- **The catalog:** one running package touches `Resources/Localizable.xcstrings` at a time, in §5's
  catalog order. A package with a core half and an app half (A-6, X-1, X-2, P-2) runs its
  BatteryCore half in the slot that never touches the catalog, and its app half, which owns the
  strings, in the catalog slot; the four core halves are done (A-0), so only the app halves remain.
- **Screens are shot on the M5, not rendered in CI.** 0.7's CI PNGs cover widgets, which
  `ImageRenderer` can draw; the app's pages hold controls backed by AppKit, which it can't:
  Apple's page says it leaves out "more complex controls and containers" and "most types of UIKit
  and AppKit views", drawing a placeholder instead
  (https://developer.apple.com/documentation/swiftui/imagerenderer). So the look shoot (§6.1)
  takes every new screen from a CI build, in both languages, and the reviews run on those shots.
- **0.8 keeps off the widget target, but for A-2's widget half:** 0.7.1's feed shipped (I-6), so
  A-2 shows the number in the widget's `systemChargeLimit` field through it (A-2 item 8), in the
  catalog slot, and records the widget's numbers (its sizes, the field's text budget) in its
  commit messages, as 0.7 did; so does any fix of E-2's gaps that reaches the widget (C9). F-1
  changes the feed's placement decision and the app's writer, not the widget target.
- **No new settings key** without a frozen-surface note in §7.3 and the maintainer's look at it;
  this plan adds none (P-1 keeps its state in files, A-5 reuses `hasSeenWelcome`).
- **Nothing is sent:** a package whose code could reach the network (A-6) carries a guard that
  says it can't (§11).
- **Facts** go to this plan's Appendix C; at D3 the lasting parts move to ROADMAP, and
  `docs/plans/0.8.0/` is removed, after its tooling is copied forward for 0.9.0 (D3).

---

## 4. Work packages

**Priorities:** P1 must ship; P2 ships if the budget allows; conditional depends on a gate. Each
package lists: source; items; files; Linux tests; guards; acceptance; effort; risk; rollback.

### A-0: Intake (P1, the orchestrator, no code)

- **Source:** P7 D3; 0.7.0's Appendix C (AC70); 0.7.1's plan (P71, its §5 on 0.8's preparation
  branches), its Appendix C (AC71) and its after-publishing check (AP71); §2 above.
- **Items** (run on 2026-11-06, from v0.7.1, as each says):
  1. **Done:** §2.1's last column says what happened to each row (I-1 to I-16), from AC70, AC71,
     P71 and the code at v0.7.1.
  2. **Done:** `claude/080-integration` starts from v0.7.1 (`48b5da0`) and holds this plan, from
     `claude/080-plan`, and 0.7.1's after-publishing record (`63a01f2`). Nothing is restored:
     0.7.1's D3 moved the session tooling to `docs/plans/0.8.0/` (I-7). The six preparation
     packages, implemented and reviewed on `claude/080-<pkg>` before 0.7.1, are carried onto the
     integration branch as `claude/080-<pkg>-r` (E-3, A-6a, P-2a, X-1a, X-2a, E-2), rebased onto
     v0.7.1 as P71 §5 foresaw, by two agents beside this intake. Their merges, the two fixes where
     they met, CI and sizes at the head and what later packages inherit: Appendix C's carry-over
     block.
  3. **Changed: no re-resolving here.** The base moved twice (v0.7.0, then v0.7.1), so this plan's
     file:lines stay v0.6.2's as written, and each package re-resolves its own at its start, on the
     integration branch, as 0.7.1's packages did (AC71's V-0 rows). P7, W, AC62 and the session
     reports stay cited at `0ecca33` or 0.7's `<keep>`, since no tag holds them.
  4. **Done:** the decisions are as recorded (§2.3, §14): Q8-1 to Q8-6 are unanswered, so their
     defaults hold; the build-number clock shipped in 0.7.1 (I-9), so no commit lands it.
  5. **Done:** v0.7.1's CI sizes (§9's start) and the `.public` baseline for E-3, at v0.7.1, are in
     Appendix C, with G7-17's measurement, 0.7.1's after-publishing results and the pending
     download counts.
  6. **Done:** the plan after 0.7.1: §1, §3 and §5 (the rounds for what remains), A-2's widget
     half (I-6), and the maintainer's two additions of 2026-11-06, F-1 and T-1's item 7.
- **Acceptance:** §2.1 is complete; every package names its §2.1 rows; both jobs green on the
  intake's head.
- **Effort:** this intake and the six carry-overs (no I-9 commit).

### A-1: Why it isn't charging (P1, never cut; NEW-01)

- **Source:** RD §3.3 NEW-01 and its exit criterion ("no fixture, no cause", RD:964); M-10; M-3's
  pointer to System Settings → Battery; P7:1415-1417 (0.7 takes only the Charge Limit; NEW-01
  keeps the optimized hold, heat and a weak adapter, and builds on W-14's type); INV FEA-20 (the
  widget field stays 1.1), QUA-05 (proven), QUA-06 (open); RD §7 "Wrong or misleading
  explanations"; Apple's guide "If your Mac battery won't charge"
  (https://support.apple.com/guide/mac-help/mh29198/mac) and the Charge Limit article
  (https://support.apple.com/102338).
- **What is proven today:** only the Charge Limit's hold (bit 24, W-14's fixture). The optimized
  hold has Apple's IOPS flag (`MacPowerParser.swift:177`), which the app has shown as "Charging on
  hold" since before 0.6 (`App/Localized.swift:28-33`), but no macOS 27 capture of the Mac's own
  battery (QUA-06). No capture shows a key for heat or for a weak adapter (Appendix B).
- **Items:**
  1. **`NotChargingCause` in BatteryCore** (a new `Sources/BatteryCore/NotChargingCause.swift`,
     beside W-14's `SystemChargeLimit.swift`): an enum whose cases each name their fixture, and a
     computed `BatterySnapshot.notChargingCause` (never stored, so neither History nor `--json`
     changes; `ChargeState` keeps its five cases, P7:2671).
     - **Cases in 0.8:** `systemChargeLimit` (W-14's decision, unchanged); `optimizedHold` only if
       G8-2 brings a capture (its fixture, and whether bit 24 is set with it); `insufficientPower`
       or `heat` only if G8-3 or G8-4 brings a capture whose charger keys show it. A case is added
       in the commit that adds its fixture, never before.
     - **Precedence,** as W-14's: the SMC plug-in rule first (`MacPowerParser.swift:182-188`; a
       measured charge current means charging); then the optimized flag; then bit 24; else nil.
     - `isAtSystemChargeLimit` stays as a convenience (`notChargingCause == .systemChargeLimit`),
       since the widget reads it.
  2. **Overview and the popover:** W-14's sentence slot under the state line (P7:1469-1470) shows
     the cause's sentence and a **Battery Settings…** button (Overview) or link (popover) that opens
     System Settings → Battery (`x-apple.systempreferences:com.apple.Battery-Settings.extension`,
     which Session B's P8 opened: `sessions/B.md:91`; `m5-session.sh:3404`) [uncertain: P8 couldn't
     read the pane's sidebar]. The compact window keeps the state word only. Never a nested popover
     inside the menu bar window (HIG, Popovers).
  3. **No proven cause (Q8-1):** on external power, not charging and not full, with no cause, an
     info button beside "Not charging" (main window) opens a popover with Apple's reasons, naming
     none: battery health features (the Charge Limit, Optimized Battery Charging), a battery
     that's too warm ("charging may stop at 80%"), and an adapter that runs the Mac but can't also
     charge it, then "BatteryPulse names the reason only when the battery reports it." In the
     popover, the same text as a help tag. On battery or while charging, nothing.
  4. **Motion:** `BatteryMotionKey`'s `isAtSystemChargeLimit` flag (W-14) becomes the cause value;
     the sentence moves with it, never with `snapshot` (CL motion).
  5. **The text report:** "Not charging reason: 0x01000000" gains the cause's name in brackets when
     one is known (`BatteryReport.swift:76-80`). The text report isn't frozen (M-6); the notes say
     so (§13). `--json` doesn't change.
  6. **Raw Data:** `NotChargingReason`'s glossary line keeps W-14's bit 24 sentence and adds one
     observation, not a meaning: 0x80 reads on battery and for the first seconds after a plug-in
     on the M5 (the fixtures). Bit 12 and `ChargerInhibitReason` stay undecoded.
  7. **Demo Mode:** `DemoBattery` gains a `notChargingReason` field (today it hard-codes 0 on AC and
     128 on battery, `DemoBattery.swift:112`), and a scene per shown cause: W-14's
     `systemChargeLimit`, a "Not charging, no reason" scene for item 3's button, and one per case
     G8-2 to G8-4 add. Scenes aren't stored, so cases are free to add.
  8. **The guide's Overview text** (UG): the cause line, the info button, and that BatteryPulse
     names a reason only when the battery reports it.
- **Files:** `Sources/BatteryCore/{NotChargingCause, SystemChargeLimit, BatteryMotion,
  BatteryReport, DemoBattery, RawKeyGlossary}.swift`, `Sources/BatteryPulseApp/App/{Localized,
  DemoController, AppSettings}.swift` (`AppLinks.batterySettings`), `Main/{OverviewView,
  CompactView}.swift`, `MenuBar/PopoverView.swift`, `Resources/Localizable.xcstrings`,
  `Tests/BatteryCoreTests/NotChargingCauseTests.swift`, `docs/USER_GUIDE.md` (Overview).
- **Linux tests** (`NotChargingCauseTests`):
  - `m5-macos27-charge-limit` gives `.systemChargeLimit`; every other fixture, the synthetic ones
    included, gives nil (`plugged-in-10s` with 0x80 on AC too);
  - precedence: the optimized flag with bit 24 gives the flag's cause (or nil while
    `optimizedHold` isn't a case); a charge current at or above the threshold gives nil;
  - **no fixture, no cause:** every case's named fixture exists in `Fixtures/` and gives that case
    (a table test over `NotChargingCause.allCases`), so a case can't land without its capture;
  - each Demo scene gives its cause by the same decision; `BatteryMotionKey` differs when only the
    cause changes; the report line names the cause.
- **Guards:** the "no fixture, no cause" table test above. `MotionGuardTests` already covers the
  sentence (it moves only with `BatteryMotionKey`).
- **Acceptance:** both jobs green; the look shoot's Demo scenes in both languages (§6.1); Session
  R8 step 9 if the Charge Limit can be set.
- **Effort:** M, 2-3 runs (+1 per case G8-2 to G8-4 brings; +2 if W-14 moved whole, I-1).
- **Risks:** a cause that rests on one Mac's captures (RD §7); a macOS 27.x update could move bit
  24 (W-12's quick check and Raw Data show it). The info button's list is Apple's, so it can't be
  wrong about this Mac, only general.
- **Rollback:** revert before D1; nothing it adds is frozen.

### A-2: The Charge Limit's number (P2, first to cut; FEA-35's second half)

- **Source:** RD §3.3 FEA-35 (RD:864-907) and its exit criterion (RD:965-966); P7:1594-1639 (the
  candidates, reordered by Session A's final reads); INV FEA-35; M-3 (clarified 2026-10-23); RD
  REJ-17 (`--smc` stays a list, not a format); AC62:70.
- **Decided here** (engineering; the looks are the sitting's):
  - **One source ships: powerd's charging plist, read as a file, on AC.** It holds the active
    limit's policy only on AC (AC62:70). On AC a policy with reason `manualChargeLimit` gives the
    number; no policy gives unknown, never "off" (W-14's rule, P7:1436-1437).
  - **The prior limit is not shown** (Q8-2): it read 80 with the limit at 100 %.
  - **`CHLT` and `CHNC`:** `bpulse --smc` reads their values (item 4), as evidence for G8-1; the
    app doesn't read them in 0.8.
  - **`pmset -g battlimit`:** not built. It would need a `Process` exception
    (`SecurityGuardTests.swift:77-81` allows a process only in the installer); it is the
    fallback only if the plist fails its check and `battlimit` passes (G8-1), at +1 run.
  - **PowerUI:** never (M-3).
- **Items:**
  1. **The parser in BatteryCore** (`Sources/BatteryCore/SystemChargeLimitSource.swift`):
     - the outer file through `PropertyListSerialization` (via `PropertyValue(any:)`, CL);
     - `policies` as `Data`, decoded with `NSKeyedUnarchiver(forReadingFrom:)`,
       `setClass(ChargePolicyRecord.self, forClassName: "ChargeCtrlPolicy")` and
       `decodeObject(of:forKey:)` with an explicit class list, so the private class is never
       instantiated and secure coding stays on (Apple documents the substitution:
       https://developer.apple.com/documentation/foundation/nskeyedunarchiver, "Managing Class
       Names");
     - `ChargePolicyRecord` decodes only `soclimit`, `reason` and `terminated`; unknown keys are
       ignored;
     - the number is the `soclimit` of a policy that isn't terminated and whose reason is
       `manualChargeLimit`, in 80-100 (Apple's range, https://support.apple.com/102338); any
       other shape gives nil and a case name (`noPolicy`, `otherReason`, `outOfRange`,
       `format`);
     - if `policies` turns out not to be `Data` (inline), the run decodes it the same way from the
       outer file, or the source fails G8-1.
  2. **The model:** a stored `BatterySnapshot.systemChargeLimitPercent: Int?` (nil = unknown),
     which synthesized `Codable` leaves out of `--json` while nil. Set only on AC. No new
     identifier is a bare `chargeLimit` (P7:1446-1450).
  3. **The reader** (`Sources/BatterySource/SystemChargeLimitReader.swift`, nonisolated and
     `Sendable`, its last value behind a `Mutex`): reads the file with `Data(contentsOf:)` only on
     these triggers, inside the monitor's `@concurrent` read: the first read on AC after launch, an
     external-power change, a change of bit 24, and Power appearing; never per poll. The widget
     never calls it (item 7's guard). `BatteryMonitor` and `bpulse` (`--json`, the text report)
     call it; `--input` of a capture never does.
  4. **`bpulse --smc`:** `readPrefixes` (`main.swift:305-306`) gains exactly `CHLT` and `CHNC`, a
     reviewed change inside the read-only rule (commands 5, 8 and 9 through selector 2), so the
     session reads their values at each limit. The `--smc` text isn't frozen (M-6).
  5. **The look:** Power's "Charge limit" row (W-14's "Reached") reads "80 %" on AC with a policy,
     "80 %, reached" while bit 24 holds; Overview's and the popover's sentence name it ("Charging
     stopped at the Charge Limit, %@, set in System Settings → Battery."). On battery the row
     hides, as W-14's does. The text report gains "Charge limit: 80 %". The widget shows the
     number too, through 0.7.1's feed (item 8).
  6. **The sample** (`scripts/charge-limit-sample.swift`, macOS only, run by T-1's
     `charge-limit` step): copies the file, overwrites `bootSessionUUID`, the `token` UUID's bytes
     and `owner`'s value in place with zeros of the same length, checks the copy still decodes to
     the same number, and saves it for the fixture. With `pmset -g battlimit`'s verbatim text and
     `defaults read com.apple.batteryui.charging.mac` beside it. Committed only after his yes before
     `send`.
  7. **Logs:** one `monitor` line per read: the source's case name and the percent, `.public`
     (numbers and case names only); never the path or an error description (CL logging).
  8. **The widget half** (I-6: 0.7.1's feed shipped; added at A-0). The sandboxed widget can read
     none of the sources (RD §3.3 FEA-35's "Where"), so the app carries the number in the feed:
     an optional field (the feed's schema, version 1, only gains fields: P71 §7.3), written only
     while the number is known, never from a Demo Mode scene (the feed never holds Demo Mode's
     data), at the writes that already happen (the plug write and the 15-minute step; a new write
     moment only if the run shows a gap, said in its message). The `systemChargeLimit` field,
     whose meaning is frozen and value isn't (`WidgetOptions.swift`), reads as Power's row does:
     "80 %, reached" at the hold and "80 %" on AC while the number is known; without the number
     it keeps 0.7's "Reached" at the hold and is dropped otherwise. Its VoiceOver label and text
     budget follow (`WidgetAccessibility`, `WidgetTextBudget`), CI's widget previews draw it in
     both languages for the look review (§6.2 question 3), and the widget's numbers go in the
     commit messages (§3).
- **Fixtures:** `Tests/BatteryCoreTests/Fixtures/powerd-charging-<n>.plist` (the policy at each
  limit the step read) and `powerd-charging-none.plist` (100 %), redacted by item 6, with README
  rows.
- **Files:** `Sources/BatteryCore/{SystemChargeLimitSource, BatterySnapshot, BatteryReport}.swift`,
  `Sources/BatterySource/SystemChargeLimitReader.swift`, `Sources/BatteryKit/BatteryMonitor.swift`,
  `Sources/bpulse/main.swift`, `Sources/BatteryPulseApp/App/{Localized, DemoController}.swift`,
  `Main/{PowerView, OverviewView}.swift`, `MenuBar/PopoverView.swift`,
  `Resources/Localizable.xcstrings`, `scripts/charge-limit-sample.swift`, the fixtures and README,
  `Tests/BatteryCoreTests/{SystemChargeLimitSourceTests, SecurityGuardTests}.swift`,
  `docs/USER_GUIDE.md` (Power), `.github/workflows/ci.yml` (the sample script's type-check). Item
  8: `Sources/BatteryCore/Widget/{WidgetFeed, WidgetRow, WidgetAccessibility,
  WidgetTextBudget}.swift`, `Sources/BatteryPulseApp/App/WidgetFeedWriter.swift`, the field's view
  (`Sources/BatteryPulseWidget/WidgetDetailViews.swift`) and its previews,
  `Tests/BatteryCoreTests/{WidgetFeedTests, WidgetRowTests, WidgetTextBudgetTests}.swift`, and the
  guide's widget field.
- **Linux tests:** each redacted sample gives its number and the 100 % one nil; a terminated
  policy, another reason, 75 or 105, a missing `policies`, a truncated archive and an XML copy
  each give their case; the stand-in never reads `owner` or `token`; `--json` has the key only
  when known (a snapshot round trip); the Demo scene's number. Item 8: a feed with the number
  round-trips, and one without it (0.7.1's) decodes with the field absent; the builder writes it
  only while known and never from a Demo scene; the row gives "80 %, reached", "80 %", 0.7's
  "Reached" or nothing as above; the text budget holds the Russian in every place the field
  shows.
- **Guards** (`SecurityGuardTests`, with `catches` cases): the plist's path literal appears only
  in `SystemChargeLimitReader.swift`; `SystemChargeLimitReader` is forbidden under
  `BatteryPulseWidget/` (the widget reads the battery and nothing else, and W-3a's guard covers
  file APIs only there, `SecurityGuardTests.swift:130-136` on `origin/claude/070-w3a`; whether its
  sandbox could read the plist at all is [unverified]); `ChargeCtrlPolicy` appears only in
  BatteryCore's parser; no `NSClassFromString`.
- **Acceptance:** both jobs green; G8-1 passed on the M5 (§6.1 step 2), with the app's logged
  number equal to `battlimit`'s at the hold (and at a second limit when the charge allowed one),
  absent at 100 % and on battery; the redacted samples committed.
- **Effort:** M, 2-3 runs, +1 for the widget half (item 8) [estimate] (+1 for the `battlimit`
  fallback only if G8-1 picks it).
- **Risks:** the format is private and undocumented, so a macOS 27.x update may change it: the
  reader then logs `format` and the number goes unknown, never wrong (the parser accepts one
  shape). Reading `/Library/Preferences` from the app's own process may differ from Terminal's
  reads [inference: not a consent-protected location in Apple's list, Appendix B]: G8-1 checks.
- **Rollback:** before D1, revert the reader's wiring and the feed field's writes and keep the
  parser (it reads nothing); the widget then shows 0.7's "Reached" again. Once shipped, the
  feed's field stays in its schema, which only gains fields (P71 §7.3), and a 0.8.x that stops
  reading the source simply leaves it out, which the widget reads as unknown.
  Once shipped, `systemChargeLimitPercent` is frozen as a `--json` key (C14 item 4); if the
  source breaks, a 0.8.x stops reading it and the key goes absent, which "only added" allows.

### A-3: Is my battery OK: the Health summary (P1, never cut; NEW-02)

- **Source:** RD §3.3 NEW-02; M-10 (facts only, label-value pairs, `%@` only); RD:1209 (grades of
  our own rejected); `Main/HealthView.swift:91-118` (the facts exist).
- **Items:**
  1. **A summary card at the top of Health:** "Condition" (macOS's word, "Normal" when it reports
     none, `Phrases.condition`, `App/Localized.swift:127-137`), "Maximum capacity" (as System
     Settings shows it, capped at 100 %), "Cycle count" ("52 of 1,000", `Phrases.count`), and one
     line of source: "As macOS reports it in System Settings → Battery." The three rows move out of
     the Battery Health section (no duplicates); "Rated cycle life used" and the cap footer stay.
  2. **No grade of our own (Q8-4):** Clear's badge shows "Service Recommended" when only the
     capacity is under 80 % (`BatteryPresentation.swift:63-71`, `App/Localized.swift:141-154`),
     which macOS may not have said. With Q8-4's yes it reads "Maximum capacity below 80 %" (a
     fact), and "Service Recommended" shows only when macOS reports it. The colour tiers stay.
  3. **BatteryCore:** `HealthSummary.rows(for:)` builds the label keys and pre-formatted values, so
     the card and E-1's tests share one decision.
- **Files:** `Sources/BatteryCore/{HealthSummary, BatteryPresentation}.swift`,
  `Sources/BatteryPulseApp/Main/HealthView.swift`, `App/Localized.swift`, `Main/OverviewView.swift`
  (the badge only), `Resources/Localizable.xcstrings`,
  `Tests/BatteryCoreTests/HealthSummaryTests.swift`, `docs/USER_GUIDE.md` (Health).
- **Linux tests:** every Mac fixture gives three rows in order; no condition key and an empty one
  give "Normal" (CL); a capacity over 100 % shows 100 %; a missing rated count gives the plain
  count; a capacity of 79 % with "Normal" gives no "Service Recommended" word (with Q8-4's yes).
- **Guards:** none new (A-4's guard covers the labels).
- **Acceptance:** both jobs green; the look review's y on the card and the badge.
- **Effort:** S, 1 run. **Risk:** low. **Rollback:** revert; nothing frozen.

### A-4: What does this number mean: explanations (P1, never cut; NEW-03)

- **Source:** RD §3.3 NEW-03 and C12 (the explanation-key guard is a 1.0 gate, RD:349-350); UG's
  "Understanding the numbers" (UG:533-563); HIG "Offering help" (help tags of 60 to 75
  characters, starting with a verb, describing only the control) and "Popovers" (one at a time,
  never a cascade); SwiftUI `help(_:)`, which sets the accessibility hint and the help tag.
- **Items:**
  1. **`MetricExplanation` in BatteryCore:** a table from each metric's label key to a short help
     key (75 characters or fewer in English) and a long text key, written from UG:533-563 in plain
     words; the keys are catalog keys that `LocalizationCatalogTests` counts, as it counts
     `RawKeyGlossary.summaries` (`LocalizationCatalogTests.swift:69`).
  2. **`ValueRow` and `GaugeTile` take an explanation** (`Components/ValueRow.swift:6-24`, today
     label and value only): the row gets `.help(short)` (so VoiceOver reads it as the hint), and in
     the main window an info button opens the long text in a popover; in the menu bar panel only
     the help tag.
  3. **Which metrics:** every `ValueRow` and `GaugeTile` label on Overview, Power, Health, the
     device page and the popover, except an "obvious" list kept in the guard with a reason each
     (for example "Adapter" or "Low Power Mode"). The plan's count [estimate]: about 18-24 metrics.
  4. **The guide** keeps "Understanding the numbers" and says the same explanations sit next to
     each number in the app.
- **Files:** `Sources/BatteryCore/MetricExplanation.swift`,
  `Sources/BatteryPulseApp/Main/Components/{ValueRow, GaugeTile}.swift`,
  `Main/{OverviewView, PowerView, HealthView, DeviceView}.swift` (call sites only),
  `MenuBar/PopoverView.swift`, `Resources/Localizable.xcstrings`,
  `Tests/BatteryCoreTests/{MetricExplanationTests, ExplanationGuardTests, SourceScanner}.swift`,
  `docs/USER_GUIDE.md`.
- **Linux tests:** every table entry has both keys; every short key is at most 75 characters in
  English; no key is a counted phrase.
- **Guards:** **`ExplanationGuardTests`** (new; SourceScanner's model over `Main/` and `MenuBar/`):
  every `ValueRow("…")` and `GaugeTile(title: "…")` literal is in `MetricExplanation` or on the
  obvious list with its reason; `catches` cases for a new unexplained row. It joins SourceScanner's
  suites in the same commit.
- **Acceptance:** both jobs green; the look review's y on a row's help tag and popover in both
  languages.
- **Effort:** M, 2-3 runs. **Risks:** the strings budget (§9); Russian length in a 75-character
  tag (the Russian review). **Rollback:** revert; nothing frozen.

### A-5: Welcome, the first ten minutes (P2, cut third; NEW-04)

- **Source:** RD §3.3 NEW-04; M-10 (one window, not a tour); NEW-24 (Welcome announces the version
  count, RD:1383); P7:1729-1731 (W-13 relies on Welcome embedding General); HIG "Onboarding"
  (brief, ask for a permission when its feature is first used) and "The menu bar" (don't rely on
  a menu bar extra being visible; macOS hides them); Apple's menu bar settings page
  (https://support.apple.com/guide/mac-help/mchlad96d366/mac: System Settings → Menu Bar, its
  Battery item and "Allow in the Menu Bar").
- **Items:**
  1. **One window, one line and one control each** (`Welcome/WelcomeView.swift`, which today embeds
     `GeneralSettings()`, :32-34):
     - **where BatteryPulse lives:** the menu bar, and that macOS can hide it ("Allow in the Menu
       Bar"); the control is **Open at login** (today's Welcome shows it through General);
     - **macOS's own battery item:** "Turn it off if you prefer BatteryPulse's"
       (**Menu Bar Settings…**, `AppLinks.menuBarSettings`, `App/AppSettings.swift:175-179`);
     - **one charge notification:** "Notify me when charged to 80 %" (**Turn On**, which writes
       the existing alert setting and asks for notification permission at that moment, HIG);
     - **the widget:** how to add it (**Show How**, which opens the guide's Widget section at the
       release's tag, A-7);
     - **iPhone and iPad:** what it reads and that it loads a private framework (**Settings…**, the
       Devices pane; the opt-in toggle itself stays in Settings, as today);
     - **the anonymous version count:** W-13's toggle with its footer, disabled under Never, as in
       Settings → General (NEW-24; I-2).
  2. **Buttons:** Quit, Open BatteryPulse and Done stay (`WelcomeView.swift:36-46`).
  3. **No new key:** `hasSeenWelcome` and `showWelcomeAtLaunch` stay as they are.
- **Files:** `Sources/BatteryPulseApp/Welcome/WelcomeView.swift`, `Resources/Localizable.xcstrings`,
  `Tests/BatteryCoreTests/SecurityGuardTests.swift` or a source test (below), `docs/USER_GUIDE.md`
  (First launch).
- **Linux tests:** a source test that `WelcomeView.swift` binds the version count's key and the
  open-at-login setting, so NEW-24's announcement can't silently leave Welcome.
- **Acceptance:** both jobs green; the look review's y in both languages (shot with
  `hasSeenWelcome` cleared and restored, §6.1).
- **Effort:** S-M, 1-2 runs. **Risk:** low. **Rollback:** revert to the embedded General; the
  count's announcement then comes back with it.

### A-6: Report a Problem (P1, never cut; NEW-05; DIS-09's capture half)

- **Source:** RD §3.3 NEW-05 (RD:925-937); M-11; RD:1204 (sending stays rejected); REJ-36
  (MetricKit rejected: "NEW-05 covers diagnostics without it"); C17 (no user text asks anyone to
  run `swift run bpulse`; UG:659-666 does today, and so do UG:566-603, which 0.9.0's M-7 rewrites,
  RD:1059-1060); HIG "The menu bar" (Help items, the ellipsis).
- **Decided here** (engineering):
  - **One UTF-8 text file,** `BatteryPulse-report.txt`, that the preview shows byte for byte, so
    what the user sees is what he saves. GitHub accepts `.txt` attachments up to 25 MB
    (https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/attaching-files).
    The captures go in as their XML property lists between marker lines, so the maintainer can cut
    one out and run `bpulse --input` on it.
  - **English, like the text report and the captures;** the window's own words are localized.
  - **Saved with `fileExporter(isPresented:item:contentTypes:defaultFilename:…)`**, the
    `Transferable` overload the app already uses (`DeveloperView.swift:125-133`); the `FileDocument`
    overload is deprecated in the 27.2 SDK (Appendix B).
- **A-6a, the core (no catalog; done before 0.7.1, carried in A-0 as `claude/080-a6a-r`, which
  decides the report's settings against 0.7.1's keys, counts 0.7.1's widget signposts and keeps
  the feed out of the report):**
  1. **`ProblemReport` in BatteryCore:** assembles the sections from `Sendable` inputs in a
     `@concurrent` function: the battery capture (redacted as Export Capture redacts,
     `MacPowerParser.swift:59-98`); the accessories capture pseudonymized as `--accessories --raw`
     (`AccessoryCapture.swift:34`); the last device capture redacted as `--device --raw`
     (`IDeviceCapture.swift:261`); version, build, the macOS version string (shown, never parsed)
     and the Mac model; the settings' values from an allow list; this session's `perf` summary;
     the crash reports' names; and, only on the second choice, their contents with
     `crashReporterKey` and `incident` dropped and the home folder written as `~`.
  2. **`PerfSummary` in BatteryCore:** count, total and maximum per signpost name, kept in memory
     behind a `Mutex` and fed by both `Diagnostics` twins, since `perf` lines are debug lines the
     app can't read back (Apple: debug messages are not persisted).
  3. **`SystemIdentity` in BatterySource:** the Mac model from `sysctlbyname("hw.model")`, marked
     `unsafe` with its reason (strict memory safety, CL); its output format [unverified].
  4. **The settings allow list:** every `AppSettings` key (`App/AppSettings.swift:10-55`) is either
     included or left out with a reason (`updateLeftover` holds a path; the alert states are
     checked for names before they go in); a test fails on a key in neither list.
- **A-6b, the app (the catalog):**
  1. **Help → Report a Problem…** after BatteryPulse Help (`App/BatteryPulseApp.swift:85-88`).
  2. **The window:** what the file holds and that nothing is sent; the preview (monospaced,
     selectable, scrollable); "Include the crash reports' contents" (off; the second choice);
     **Save…**; after a save, the issue chooser
     (`https://github.com/NikitaUsov/BatteryPulse/issues/new/choose`) opens in the browser.
  3. **Reads at preview time:** one battery read through the system provider, never Demo Mode's
     (Demo Mode adds a line naming its scene); one accessory read through P-1's sentinel; the last
     device capture from `IDeviceMonitor.capture(for:)` (`IDeviceMonitor.swift:290`) only while
     device reading is on; the crash reports' names from `~/Library/Logs/DiagnosticReports`
     (`BatteryPulse*`, `bpulse*`) [inference: not a consent-protected folder; G8-5 checks].
  4. **The bug template and the guide:** `.github/ISSUE_TEMPLATE/bug_report.yml`'s capture field
     (as R-1 left it) points to Report a Problem; UG's "Reporting a problem" is rewritten around it,
     with no `swift run bpulse`.
- **Files:** A-6a: `Sources/BatteryCore/{ProblemReport, PerfSummary}.swift`,
  `Sources/BatterySource/{SystemIdentity, Diagnostics}.swift`,
  `Sources/BatteryPulseApp/App/Diagnostics.swift`, `Tests/BatteryCoreTests/{ProblemReportTests,
  PerfSummaryTests}.swift`. A-6b: `App/BatteryPulseApp.swift`, a new `Main/ReportProblemView.swift`,
  `Sources/BatteryKit/AccessoryMonitor.swift` (a read that keeps the sources),
  `Resources/Localizable.xcstrings`, `Tests/BatteryCoreTests/{SecurityGuardTests,
  IsolationGuardTests}.swift`, `.github/ISSUE_TEMPLATE/bug_report.yml`, `docs/USER_GUIDE.md`.
- **Linux tests:** a report built from every fixture holds no serial, `ManufacturerData`, `MfgData`,
  UDID, device name, user name or home path; a synthetic `.ips` keeps its `bug_type` and loses
  `crashReporterKey` and `incident`; without the second choice no crash content appears; the
  allow-list completeness test; the marker lines round-trip each capture to the same dictionary.
- **Guards:** `SecurityGuardTests`: no `URLSession`, `URLRequest` or `Network` use in the report's
  files, and the issue chooser's URL in one place; the `DiagnosticReports` path only in the report
  file, among `Sources` (`scripts/relaunch-fallback-check.sh` and `ci.yml`'s launch step name the
  folder too). `IsolationGuardTests`: the assembly is on its off-main list. A-6a's
  `theReportsFilesUseNoNetwork` checks a fixed list of two files (`ProblemReport.swift`,
  `PerfSummary.swift`): A-6b adds its window's file, or turns it into the rule
  `theReportTakesNothingFromTheWidgetFeed` already uses (every `Sources` file that names
  `ProblemReport`). A new settings key fails `everySettingsKeyIsIncludedOrLeftOut` until
  `ProblemReport` includes it or leaves it out with a reason. The report's perf section holds only
  the app's signposts; the widget's `widget.timeline` and `widget.feed.read` count in the
  extension's own summary, which no report reads.
- **Acceptance:** both jobs green; the look review's y on the window; Session R8 step 10's check
  of a saved file on the M5.
- **Effort:** L, 3 runs (A-6a 1, A-6b 2). **Risks:** a field the redaction misses (the tests list
  every identifier the fixtures hold); reading the crash folder may prompt (G8-5: the names then
  read "not readable", never an error dialog). **Rollback:** revert A-6b; A-6a reads nothing.

### A-7: Help at the release's tag (P2, cut second; NEW-06)

- **Source:** RD §3.3 NEW-06, C17 (RD:448-449); `AppLinks.help = ReleaseChannel.file(…)`
  (`App/AppSettings.swift:171`), which builds `…/blob/main/<path>`
  (`BatteryCore/Updates.swift:163-166`).
- **Items:** `ReleaseChannel.file(_:at:)` with the running version: `/blob/v<version>/…` for a
  versioned build, `main` for 0.0.0 (the unversioned check, `UpdateInstall.swift:133`); an anchor
  form for A-5's widget link. It sits beside W-13's `releaseAsset(_:of:)` (`Updates.swift:167-172`
  on `origin/claude/070-w13`).
- **Files:** `Sources/BatteryCore/Updates.swift`, `App/AppSettings.swift`,
  `Tests/BatteryCoreTests/UpdatesTests.swift` (or the existing release-channel tests).
- **Linux tests:** 0.8.0 gives `/blob/v0.8.0/docs/USER_GUIDE.md`; 0.0.0 gives `main`; an anchor
  is appended once.
- **Effort:** S, 1 run (no strings). **Risk:** an RC's link (0.7.99) opens a tag that doesn't
  exist; expected, and only in sessions. **Rollback:** revert.

### X-1: Chart descriptors (P1, never cut; A11Y-01)

- **Source:** RD §3.3 A11Y-01 and C10 ("every chart has a descriptor"); INV A11Y-01 (moved from not
  planned, RD:1344); `accessibilityChartDescriptor(_:)` (macOS 12+, for "any View that represents a
  chart") and `AXChartDescriptorRepresentable`; HIG "VoiceOver" (a concise description of each
  chart). Today no file uses it, and the chart parts are hidden
  (`Main/History/ChargeChart.swift:31`, `PowerChart.swift:29`, `HistoryChartParts.swift:51`).
- **X-1a, the core (no catalog; done before 0.7.1, carried in A-0 as `claude/080-x1a-r`):**
  `ChartSummary` in BatteryCore, built from `HistoryChartData`
  (`HistoryChartData.swift:15-34`): per series its name key, unit, time span, minimum, maximum and
  at most 48 points (hourly or daily, by the range shown), all pre-formatted. If 0.7 shipped W-6's
  `WidgetChartSummary` (I-5), X-1a reuses it and shrinks: 0.7.1's is one widget label, not a
  descriptor model, so X-1a kept its own.
- **X-1b, the app (the catalog):** `Main/History/ChartDescriptors.swift` maps a `ChartSummary` to an
  `AXChartDescriptor` for the Charge, Power and Temperature charts and the health trends
  (`HealthTrendCharts.swift`); each chart gets a label and the descriptor, and its parts stay
  hidden.
- **Files:** `Sources/BatteryCore/ChartSummary.swift`,
  `Tests/BatteryCoreTests/ChartSummaryTests.swift` (X-1a);
  `Sources/BatteryPulseApp/Main/History/*.swift`, `Resources/Localizable.xcstrings` (X-1b).
- **Linux tests:** every fixture day and an empty range give a summary; at most 48 points; the
  extremes equal the data's; a gap stays a gap (no invented zero).
- **Guards:** a source test that every `Chart {` in `Main/` has an `accessibilityChartDescriptor`.
- **Acceptance:** both jobs green; Session R8 step 3 finds each chart's label and descriptor
  [uncertain: whether the AX tree exposes the descriptor to a script; else Accessibility Inspector].
- **Effort:** M, 1-2 runs (+1 without I-5, already counted). **Risk:** low. **Rollback:** revert.

### X-2: VoiceOver and the keyboard (P1, never cut; NEW-07)

- **Source:** RD §3.3 NEW-07 and C10 (RD:325-338); HIG "Accessibility", "VoiceOver" and "Keyboards"
  (Full Keyboard Access; Control-Tab between groups); SwiftUI `focusable(_:interactions:)` (macOS
  14+) and `focusSection()` (macOS 13+). Today `RingGauge`, `PowerFlowView` and `CapacityBars` have
  no accessibility modifier (0 each, `Main/Components/`), and the only keyboard code is
  `.keyboardShortcut` on the Welcome and update buttons.
- **X-2a, the core (no catalog; done before 0.7.1, carried in A-0 as `claude/080-x2a-r`):**
  `AccessibilityText` in BatteryCore: the pre-formatted values
  for the power flow (adapter, Mac, battery, with directions), the capacity bars and the ring's
  value, tested on Linux over the fixtures; phrases use `%@` only.
- **X-2b, the app (the catalog):**
  1. **VoiceOver:** `PowerFlowView` and `CapacityBars` become one element each with a label and a
     value; `RingGauge` (a `GaugeStyle`) keeps the label and value it inherits from `Gauge`
     [inference: Apple notes a custom style inherits its control's accessibility; Session R8
     confirms]; decorative images stay hidden; every page, the popover and every Settings pane
     reach C10's "reachable and named".
  2. **The keyboard:** the sidebar and toolbar (standard), the Settings tile pickers
     (`Settings/PreviewTilePicker.swift:53-88`: `focusable(interactions: .activate)` and a focus
     ring), Raw Data's table and filter, the update window's buttons (default and cancel), and
     the Report a Problem window; `focusSection()` where Tab must visit a group first.
  3. **The catalog scan learns** `accessibilityValue(` and `accessibilityHint(` (in W-1's
     `localizedLiterals(in:)`, or today's regex, I-4), so their literals can't go untranslated.
  4. **X-2a's five waiting phrases** ("%@ adapter", "%@ from the adapter", "%@ to the Mac", "%@ to
     the battery", "%@ from the battery") enter the catalog with their Russian, and leave
     `AccessibilityTextTests.pendingKeys` in the same commit (its test fails otherwise); and
     `LocalizationCatalogTests` counts `AccessibilityText.catalogKeys` as used, as it counts
     `RawKeyGlossary.summaries`, since its scan reads only the app's, the widget's and BatteryArt's
     sources (`catalogHasNoLeftovers` fails otherwise).
- **Files:** `Sources/BatteryCore/AccessibilityText.swift` and its tests (X-2a);
  `Sources/BatteryPulseApp/Main/Components/{RingGauge, PowerFlowView, CapacityBars}.swift`,
  `Settings/PreviewTilePicker.swift`, `Main/DeveloperView.swift`, `Updates/UpdateViews.swift`,
  `Resources/Localizable.xcstrings`, `Tests/BatteryCoreTests/{LocalizationCatalogTests,
  AccessibilityTextTests}.swift` (X-2b).
- **Guards:** a source test that each custom view in `Main/Components/` has an accessibility
  modifier or is on a list as decorative, with its reason.
- **Acceptance:** both jobs green; Session R8 steps 3-4 (the tree in both languages, the keyboard
  walk).
- **Effort:** M-L, 2-3 runs. **Risk:** a control only VoiceOver itself reveals as unnamed; Q8-6's
  optional listen is the backstop. **Rollback:** revert per component.

### P-1: A sentinel around the private calls (P2, cut last; NEW-14)

- **Source:** RD §3.3 NEW-14 (threat A4 without SEC-10's helper process; SEC-03 stays after 1.0);
  the private calls: `MacAccessoryProvider`'s `IOPSCopyPowerSourcesByType` through `dlsym`
  (`BatterySource/MacAccessoryProvider.swift:41-42`, `:54-63`) and MobileDevice through `dlopen`
  (`BatteryKit/MobileDevice/MobileDeviceLibrary.swift:131`, `:144`).
- **Decided here:** **files, not a settings key.** Before each batch of private calls (one
  accessory read, one device read or listing), the app creates
  `Application Support/io.github.nikitausov.BatteryPulse/Sentinel/<feature>`, and removes it when
  the batch returns and at a clean termination. A file found at launch pauses that feature. So the
  pause survives relaunches with no new key (§7.3), and **Turn On Again** deletes the file. The
  folder is internal, not a 1.x storage promise (C14 item 2 names `History/` and `Devices/`).
- **Items:**
  1. **`SentinelPolicy` in BatteryCore:** found at launch → paused; Turn On Again → cleared; a
     clean termination → cleared; tested on Linux with a temporary folder.
  2. **The wrappers live in BatteryKit** (`AccessoryMonitor`, `IDeviceMonitor`), which the widget
     doesn't link (`bpulse` does, and calls neither monitor: `Package.swift:54-55`), never in
     `MacAccessoryProvider`: the widget calls the accessory symbol itself (W-8)
     and may write no files of ours (W-3a's guard). A crash inside the widget stays outside the
     sentinel in 0.8 (§6.7).
  3. **The note:** Accessories and the device page say that BatteryPulse stopped reading because
     it quit unexpectedly during a read, with **Turn On Again**; nothing else changes.
- **Files:** `Sources/BatteryCore/SentinelPolicy.swift`, `Sources/BatteryKit/{AccessoryMonitor,
  IDeviceMonitor}.swift`, the Accessories and device views, `App/BatteryPulseApp.swift` (the launch
  check), `Resources/Localizable.xcstrings`, `Tests/BatteryCoreTests/{SentinelPolicyTests,
  SecurityGuardTests}.swift`.
- **Guards:** `SecurityGuardTests`: every file that may call the private symbols' wrappers sits
  inside a sentinel scope (the call sites listed with their reason).
- **Acceptance:** both jobs green; Session R8 step 11 (a sentinel file placed before launch pauses
  the feature; Turn On Again resumes it).
- **Effort:** M, 1-2 runs. **Risk:** a false pause after a force quit or a power loss mid-read;
  the note says what to do. **Rollback:** revert; delete the folder at launch in the revert.

### P-2: Update safety (P1, never cut; NEW-16 with SEC-07)

- **Source:** RD §3.3 NEW-16, C8 (RD:308-313) and the exit criteria (RD:972-974); INV SEC-07;
  `checkStagedBundle` checks only the identifier, the exact version and newer-than-current
  (`BatteryCore/UpdateInstall.swift:161-169`); `build-app.sh` writes `LSMinimumSystemVersion` 27.0
  (`scripts/build-app.sh:128`, `:164`) and nothing reads it before the swap; the swap is
  `renamex_np(…, RENAME_SWAP)` (`Updates/UpdateInstaller.swift:427`); the relaunch is a `/bin/sh`
  script with `open -n` (`UpdateInstaller.swift:244-268`).
- **P-2a, the core and the installer (no catalog; done before 0.7.1, carried in A-0 as
  `claude/080-p2a-r`):**
  1. `checkStagedBundle` gains `minimumSystemVersion`: a bundle whose `LSMinimumSystemVersion` is
     above the running macOS is refused (a new `UpdateInstallError` case), and so is an unreadable
     value; `UpdateInstaller.checkBundle` reads the key (`:559`).
  2. **SEC-07:** before the swap, `volumeSupportsSwapRenaming` of `/Applications`' volume; false
     gives its own error, and the fallback offers the release page (`UpdateFallback`, CL).
  3. **The relaunch fallback:** the relaunch script waits up to 30 s for the new copy to write its
     launch marker (the existing launch-time write of `lastSeenVersion`, or a file in the staging
     folder; no new key), and if none comes it swaps back the old copy (kept in the staging folder
     until the new one has launched) and opens it [unverified: mechanics; the run decides and
     documents them]. The pre-swap end of the widget extension stays first, pinned by its source
     test (I-10).
  4. **A macOS CI check** (`scripts/relaunch-fallback-check.sh`): two throwaway bundles in a
     temporary folder, the newer one exiting at launch; the script expects the older one back.
- **P-2b, the strings (the catalog):** the two new errors' words in the update window. Until then
  `needsNewerMacOS` and `swapUnsupported` show `replaceFailed`'s sentence ("BatteryPulse couldn't
  replace the installed copy.", `UpdateInstaller.swift`'s error text), which P-2a left with a
  comment saying so; P-2b gives each its own.
- **Files:** `Sources/BatteryCore/UpdateInstall.swift`,
  `Sources/BatteryPulseApp/Updates/{UpdateInstaller, UpdateViews}.swift`,
  `Tests/BatteryCoreTests/UpdateInstallTests.swift`, `scripts/relaunch-fallback-check.sh`,
  `.github/workflows/ci.yml`, `Resources/Localizable.xcstrings`.
- **Linux tests:** a staged `LSMinimumSystemVersion` of 99.0 is refused (RD's exit criterion), 27.0
  and the running version pass, an empty or malformed value is refused; the new errors map to
  the fallback.
- **Guards:** `EnergyGuardTests`: the relaunch wait is a one-shot with its reason, if it is Swift;
  `SecurityGuardTests`: no new `Process` placement (the installer's own).
- **Acceptance:** both jobs green, the macOS job running the fallback check; F12 (§6.4 step 12):
  the RC built as 0.5.99 installs the published 0.7.x through this code.
- **Effort:** M, 2 runs. **Risk:** the fallback runs during every update, so a wrong marker check
  would put the old copy back after a good update: the CI check covers both outcomes.
  **Rollback:** revert before D1; after shipping, a 0.8.x.

### E-1: Frozen surfaces and golden outputs (P1, never cut; NEW-08, M-6)

- **Source:** RD §3.3 NEW-08 (after 0.7's CB-02, so the goldens pin the 1.x shapes); C14
  (RD:354-417); M-6; W-1's `WidgetSurfaceTests` (widgets, already pinned).
- **Items:**
  1. **Goldens:** for every fixture, `bpulse --input <f>` (the text report), `--input <f> --json`,
     `--input <f> --raw` (the redacted capture) and the compact JSON line `--watch --json` prints,
     plus `--accessories --json|--raw` and `--device --json|--raw` forms where a fixture exists,
     and `--export csv` (samples, `--days`, `--decimal-comma`) and `--export json` over a committed
     History folder (`HistoryExport`, `formatVersion` 1, `HistoryExport.swift:135`), as committed
     files compared on Linux and in the macOS job: every machine output C14 item 4 lists. An
     intended change updates the file in the same commit and, for a machine output, is an addition
     only.
  2. **`FrozenSurfaceTests`:** the settings keys (names, types, defaults: those of
     `App/AppSettings.swift:10-55` plus W-13's three) and their legacy migrations' BatteryCore
     halves (`MenuBarContent.migrated(legacyStyle:legacyIcon:)`, `MenuBarContent.swift:97`;
     `UpdateFrequency.stored(_:legacyEnabled:)`, `Updates.swift:205`; C14 item 1), the storage file
     names under `History/` and `Devices/`, the capture format's four top-level keys
     (`MacPowerParser.swift:40-45`), `bpulse`'s options and exit codes 0, 1, 2, the `--record`
     folder's file names (`CaptureRecorder.fileName(number:reason:date:)`,
     `CaptureRecorder.swift:331-332`), the release asset names (with `BatteryPulse-count.txt`), the
     bundle IDs and the log subsystem.
  3. **M-6 enters ROADMAP's Decisions:** machine outputs and exit codes frozen for 1.x; the text
     report, `--help` and the text of `--smc` and `--watch` may change with a line in the notes.
- **Files:** `Tests/BatteryCoreTests/{FrozenSurfaceTests}.swift`, `Tests/bpulseTests/Golden/*`,
  `Tests/bpulseTests/GoldenOutputTests.swift`, `.github/workflows/ci.yml` (the macOS compare),
  `docs/ROADMAP.md` (Decisions).
- **Order:** after A-1 and A-2 change the text report (§5).
- **Acceptance:** both jobs green; D1's golden diff is these files.
- **Effort:** M, 2 runs. **Risk:** low. **Rollback:** none needed (tests only).

### E-2: Storage, perturbation and degradation tests (P1, never cut; NEW-09, NEW-10, C9)

**Done before 0.7.1,** carried in A-0 as `claude/080-e2-r`, which also pins 0.7.1's feed among the
storage formats and says what a missing source leaves 0.7.0's and 0.7.1's widgets. What remains
is item 3's gaps, their strings in C9 (§5): rows the pages, and the Battery, iPhone & iPad and
Accessories widgets, leave out or empty without saying why (E-2's commit messages list them); a fix
that reaches the widget records its numbers as §3 says. **What E-2 pins for later packages:**
`DegradationTests` matches source text in `App/Localized.swift` (`deviceUnavailable`'s
`frameworkUnavailable` branch), `Main/DevicesIntroView.swift`, `Main/DeviceView.swift`,
`Main/AccessoriesView.swift` and `App/WidgetFeedWriter.swift` (`AppDevices.monitor.remembered`), so
a package that edits one (A-1 to A-4, P-1, F-1, E-2's gaps) keeps the pattern or updates the test in
the same commit; and since a `devices.json` with fields this version doesn't know now makes the store
read-only and lists no device (`DeviceStore`), the feed, which takes its devices from that registry,
holds none either, until a version that knows them runs again.

- **Source:** RD C9 (RD:314-324); the decoders that already tolerate change (`History.swift:86-94`,
  `HistoryStore.swift:333-337`, `DeviceStore.swift:90-95`).
- **Items:**
  1. **NEW-09:** every shipped storage format decodes (History days and samples, `devices.json`,
     the device history, `HistoryExport`'s CSV and JSON), and a "future 1.x" file with extra
     fields, unknown cases or a higher version loses nothing; a newer `devices.json` makes the
     store read-only, never lossy.
  2. **NEW-10, perturbation:** for every fixture, each key removed, each type swapped and an
     extreme value (0, negative, `Int64.max`) give no crash, and every derived value is nil ("—"
     or "Unavailable"), never 0 or another key's value.
  3. **NEW-10, degradation:** MobileDevice missing, `IOPSCopyPowerSourcesByType(4)` missing, the
     SMC keys missing and the registry children missing each give their explanation (a test over
     the phrase each view shows), never a blank. A gap found is fixed in the owning file with its
     string, in the catalog slot after E-2 (§5).
- **Files:** `Tests/BatteryCoreTests/{StorageCompatibilityTests, PerturbationTests,
  DegradationTests}.swift`, `Tests/BatterySourceTests/*`.
- **Acceptance:** both jobs green; the test count grows (C12).
- **Effort:** M-L, 2-3 runs. **Risk:** low. **Rollback:** none needed.

### E-3: The log-privacy guard and the legacy migration (P2, done before 0.7.1; NEW-12, QUA-15)

**Done before 0.7.1,** carried in A-0 as `claude/080-e3-r`, whose allow list holds 0.7.0's and
0.7.1's `.public` values (85 in 15 files, Appendix C), and 86 once P-2a's launch-marker errno
joined it at the carry-over (`3dc4d19`). Nothing remains, so it has left the cut order (§7.2), where
it was fourth. Every later package that logs a new `.public` value adds its entry with its reason
(the guard's failure names the line to add), and a renamed file moves its key.

- **Source:** RD §3.3 NEW-12, C12; CL "Logging" (only static text, numbers and case names as
  `.public`); P7:1829-1830 (0.7 checks log lines by hand until this guard exists); RD §3.3 QUA-15
  and INV QUA-15 (no release ever wrote `samples.jsonl` [uncertain]).
- **Items:**
  1. **`LogPrivacyGuardTests`** (SourceScanner's model, every target): `privacy: .public` only on
     an allow list per file with each line's reason, rebuilt at v0.7.0 (25 lines with 37
     occurrences in 11 files at `0ecca33`, plus W-13's and W-3c's lines); and never on an
     expression that names `error`, `localizedDescription`, `path`, `url`, `name`, `serial`,
     `udid` or a device key; `catches` cases for each.
  2. **QUA-15:** remove `legacySamplesURL` and its migration (`HistoryStore.swift:15`, `:24-26`,
     `:41-42`, `:98-100`, `:121`, `:147`, `:176-192`, `:246`) and the two test expectations that
     count it (`HistoryStoreTests.swift:41`, `:160-184`). The removed test,
     `theLegacyMigrationRunsOncePerSession`, gives way to one that a `samples.jsonl` in the folder
     is neither read nor removed, so the test count still only grows (C12); one line in the notes.
- **Files:** `Tests/BatteryCoreTests/{LogPrivacyGuardTests, HistoryStoreTests}.swift`,
  `Sources/BatteryCore/HistoryStore.swift`.
- **Acceptance:** both jobs green; the storage round trip at D1 is byte-identical.
- **Effort:** S-M, 1-2 runs. **Rollback:** revert either item alone.

### F-1: A removed widget leaves the feed within about an hour (P2, cut fourth; no catalog key)

- **Source:** the maintainer's addition (2026-11-06); G7-17, measured at 0.7.1's after-publishing
  check (Appendix C: WidgetKit's `currentConfigurations()` answers this ad-hoc-signed app with its
  real placements); `WidgetPlacements` as 0.7.1 left it (in
  `BatteryCore/Widget/WidgetReloadPlanner.swift`; AC71's X-2 rows; P71 §11: a kind the answer
  lists is never asked about again); CL's Energy rules; UG's Privacy section ("a kind you remove
  can still count until BatteryPulse quits").
- **Why:** once WidgetKit lists the placed widgets, the feed holds the remembered iPhones' and
  iPads' names and last readings only while an iPhone & iPad widget is placed. But the writer asks
  again only while an allowed section has no listed kind (`WidgetFeed.needsPlacementAnswer`), so
  once every allowed section has one, the answer is never renewed: removing the last iPhone & iPad
  widget leaves the devices in the feed until BatteryPulse quits, which can be days for an app that
  opens at login. G7-17's measurement (Appendix C) shows WidgetKit's answers are real, so an answer
  asked again can take the section out. (AP71's feed held devices for another reason: a widget
  Session F had left placed, which is T-1 item 7's.)
- **Items:**
  1. **The decision in BatteryCore:** `WidgetPlacements` gains a renewal age of about an hour
     [estimate; `WidgetFeed.repairAge`, the feed's own hour, is the model], and
     `WidgetFeed.needsPlacementAnswer(…)` is also true when the last answer is that old, whatever
     kinds it lists; a clock set back before the answer counts as old, as
     `needsAnswer(toReload:at:)` already does. Pure and `Sendable`, with Linux tests.
  2. **Asked only at a write that already happens:** the writer already consults
     `needsPlacementAnswer` before every write outside Demo Mode (`askForPlacementsIfNeeded`), and
     the routine write comes once per 15-minute step at `HistoryRecorder`'s minute tick
     (`WidgetFeed.WriteReason.step`), so at most one question an hour while BatteryPulse runs, and
     no timer, task or sleep of its own (CL's Energy rules). A removed kind's section leaves at most
     an hour and a quarter after the last answer. Demo Mode, whose writes are only the user's
     removals, asks nothing new.
  3. **The removal takes 0.7.1's path:** the renewed answer leaves the kind out, `sections` drops
     its section, the write takes it out, and the kinds that showed it reload as after any removal
     (`WriteEffect`, inside the 5-minute minimum). An empty or failed answer still counts as every
     kind placed: G7-17's fail-open stays, and whether an empty answer means none placed stays open
     (AC71's D3 rows). So a removed kind's section leaves while another BatteryPulse widget stays
     placed; with none left, the answer is empty and the feed holds all the settings allow, as the
     guide says today. The refresher's own answer (`WidgetRefresher`), which only decides which
     kinds reload, is unchanged.
  4. **The log:** a renewed answer logs as today's ("Placed widgets, for the widget feed: …", at
     notice only when its counts change), which is how a session sees a removal (T-1 item 7).
  5. **The words:** `WidgetPlacements`' comment, which says a removed kind counts "until the app
     quits", and the writer's `askForPlacementsIfNeeded` comment, which says when it asks, follow
     the change. UG's Privacy line ("a kind you remove can still count until BatteryPulse quits")
     becomes "stops counting within about an hour" in L-1, from the sentence F-1's PR gives (§12),
     since F-1 runs beside A-4, which edits the guide too (§5); CLAUDE.md's `WidgetPlacements` line
     if it changes, also L-1's (§12).
- **Files:** `Sources/BatteryCore/Widget/{WidgetReloadPlanner, WidgetFeed}.swift`,
  `Sources/BatteryPulseApp/App/WidgetFeedWriter.swift`,
  `Tests/BatteryCoreTests/WidgetFeedTests.swift`; not the guide (item 5).
- **Linux tests:** with every allowed section's kind listed, no question before the renewal age,
  one at it and one after a clock set back; with a section whose kinds no answer lists, today's
  15-minute rule unchanged; an answer that leaves the iPhone & iPad kind out drops the devices'
  section and keeps the history's while a Battery or History widget is listed; that write's effect
  reloads the iPhone & iPad kind as a removal does.
- **Guards:** none new: `EnergyGuardTests` (no sleep, timer or task added) and `IsolationGuardTests`
  (the decision is BatteryCore's, the writer's call stays where it is) cover it.
- **Acceptance:** both jobs green. On the M5 it shows only when a kind is removed while BatteryPulse
  runs: T-1 item 7 reads the counts and the feed after a session's removals, and Session R8 records
  what it saw [not a gate].
- **Effort:** S, 1 run [estimate]. **Risk:** low: one WidgetKit question an hour while BatteryPulse
  runs, at a write that happens anyway; a failed answer counts as every kind placed, as today.
  **Rollback:** revert, and L-1 leaves the guide's line as 0.7.1 wrote it; the feed is internal
  (P71 §7.3).

### T-1: The session script and runbooks for 0.8 (P1)

- **Source:** 0.7's W-12 and its script (I-7); 0.7.1's W-16 and W-17, which re-pointed it and
  added its own checks, and Session F's and AP71's lessons (AC71's F rows); RD §3.3's sittings;
  §6 below; Session B's lessons (P7:524-532) and today's (§2.2); the maintainer's item 7
  (2026-11-06).
- **Items:**
  1. **Steps** in `docs/plans/0.8.0/m5-session.sh` (0.7.1's script, moved forward by its D3, I-7,
     and re-pointed at 0.8: `claude/080-integration`, `~/bp-080/`, 0.8's result branches):
     `look-shoot` (§6.1), `charge-limit` (G8-1, rebuilt: the app's own logged reads against
     `pmset -g battlimit`, `defaults read` and `bpulse --smc` at each limit, on AC and on battery,
     and A-2's sample script), `weak-adapter` (optional, Q8-3), `hold-watch` (0.7's, offered again,
     I-8), and Session R8's steps (§6.4), the checks 0.7.0 and 0.7.1 shipped without among them
     (I-13, I-14; their steps are 0.7.1's Session R's, already in the script).
  2. **The `battlimit` reading:** written when today's script looked for a number followed by "%"
     (`m5-session.sh:3768`, `:6623`, `:6911` at v0.6.2), while Session A recorded
     `chargeSocLimitSoc = 80`. The moved script already reads both, `chargeSocLimitSoc` first
     (`battlimit_value`, `docs/plans/0.8.0/m5-session.sh` at v0.7.1), so T-1 only checks it
     against A-2's verbatim sample [unverified until the sample].
  3. **Runbooks:** `docs/plans/0.8.0/SESSION-L.md` (the look shoot) and `SESSION-R.md` (R8, its
     day's end, Hold watch and After publishing, each short section making its own worktree under
     `~/bp-080/`), each with Session B's rules, privacy and proofs.
  4. **`docs/plans/0.8.0/section.sh`:** prints one section of a runbook by its heading, so a start
     sentence shows the session only its section (§6.0). 0.7.1's launchers (`start-session-r.sh`,
     `start-short-session.sh`) already do it with `sed`: T-1 keeps one way for every start line.
  5. **Today's rules** in preflight and the steps (§6.0): Dock presence before access, widget shots
     by the script, a redraw before every widget shot, the quit and postpone asks; and 0.7.1's
     (AC71's F rows): a window closed by its close button or with BatteryPulse made active first, a
     routine feed write read from the feed's `writtenAt` rather than a log line, and another way
     than computer use into the widget edit sheet's menus and Language & Region's per-app menu,
     which it couldn't act in.
  6. **CI:** `bash -n` and the type-checks for the new and moved files (ci.yml); the queue dry run,
     `bash -n` and type-checks already point at `docs/plans/0.8.0/` (0.7.1's D3, I-7).
  7. **The session's gallery widgets, removed and checked** (the maintainer's addition,
     2026-11-06). AP71's feed held 4 devices through an iPhone & iPad widget still placed, most
     likely the small one Session F added from the gallery and didn't remove at its end
     (F-keep-widgets n; F's report records no removal) [inference; Appendix C, G7-17]. So
     `prepare` records the placed widgets per kind from the app's "Placed widgets" counts, which
     G7-17 showed are real; each widget a session adds stays a `desktop-widgets` change whose
     RESTORE item removes it by computer use unless he keeps it (`R-keep-widgets`,
     `F-keep-widgets`); `restored desktop-widgets` is recorded only when the app's next counts
     (after `restore end`'s relaunch, or F-1's renewed answer) are back at `prepare`'s, never on
     the session's word alone; and the report and the summary say what stayed, by kind and
     count, with an ALERT for each.
- **Files:** `docs/plans/0.8.0/*` (the script, helpers, runbooks, `section.sh`),
  `.github/workflows/ci.yml`.
- **Acceptance:** CI's dry run and `bash -n` green, the dry run covering item 7 (a count above
  `prepare`'s reads as stayed); the look shoot runs from it.
- **Effort:** M, 2 runs [estimate]: the tooling came forward (I-7), so nothing is restored, and
  item 7 is new. **Rollback:** fix forward.

### K-1 and V-1: 0.7's conditional carry-overs

- **K-1** (0.7's K-1 moved here, I-11; C8's slot 2): as P7:1641-1652. `ReleaseSigning.publicKeys`
  gains the backup key's public half (today one key, `ReleaseSigning.swift:15-17`);
  `UpdateInstallTests` pins two. S, 1 run, after the maintainer has generated it (§14 M-9).
- **V-1: not needed** (I-12: R-1's `docs/VERIFICATION.md` shipped in 0.7.0).

### L-1: Localization review, docs, What's New (P1; merges last)

- **Source:** RD §3.3 ("one look review and one Russian review"); §8, §12 below; P7's W-10.
- **Items:**
  1. **Terminology pass** over every key 0.8 added, in Apple's Russian (System Settings → Battery,
     Menu Bar, Accessibility; the Charge Limit's terms from https://support.apple.com/ru-ru/102338),
     listed key by key with its Russian in the PR for the Russian review (§6.3).
  2. **The Russian review's answers** applied, each a one-key fix.
  3. **What's New:** `WhatsNew.version` 0.8.0, 0.8's three or four entries (why it isn't charging,
     the health summary and explanations, Report a Problem, VoiceOver and the keyboard), and
     W-13's "Anonymous version count" row appended when `showsAnnouncement(previous:)` is true
     (P7:1772-1776), so an update from 0.6.x still announces it. 0.7.1's entries that nothing else
     uses leave the catalog in the same commit (`catalogHasNoLeftovers`). What's New comes after
     every update since 0.7.1, the maintainer's standing rule (§2.3).
  4. **Docs:** §12's list, with CL's new lines checked against the merged code by `git grep`.
  5. **SIZ-07** (P3), only if 0.7 didn't ship it and §9's measurement favours it: 0.8's
     explanation texts never appear in the widget, which carries the whole catalog. **Nothing
     left:** 0.7.1 shipped it (the widget's own string table, `scripts/widget-strings.swift`, holds
     only the keys its sources name), so 0.8's explanations stay out of the widget by themselves.
- **Files:** `Resources/Localizable.xcstrings`, `Sources/BatteryPulseApp/Updates/UpdateViews.swift`,
  `CLAUDE.md`, `docs/USER_GUIDE.md`, `README.md`, `docs/ROADMAP.md`, `docs/plans/1.0/*`,
  `.github/release-notes.md`.
- **Effort:** M, 2 runs. **Risk:** low.

### D1-D3: Freeze, Session R8, release

As P7 D1-D3, with 0.8's differences.

**D1, the freeze:**
- **Golden diff:** E-1's files against v0.7.1: the text report's cause and limit lines (A-1, A-2),
  `--smc`'s two values, and `--json`'s new key only where a limit is known (no fixture has one).
- **Storage round trip:** byte-identical; QUA-15 only stops reading a file no release wrote.
- **The settings-and-identifiers `git grep`:** no settings key added or changed; new strings only
  in the catalog; the one new `--json` key `systemChargeLimitPercent` (if A-2 ships).
- **Ceilings** (§9), each raise in a commit of its own that says why.
- **The notes draft** (§13) and the PR with the session checklist.
- **The candidates:** RC-U, built as 0.7.99 (Session R8 runs on it, above 0.7.1), and RC-F, built
  as 0.5.99 for F12. Same commit, two dispatches; both build numbers from 0.7.1's clock (I-9).

**D2** is Session R8 and its day (§6.4, §6.5).

**D3:**
- Apply the answers or the defaults; record the numbers in Appendix C; fill
  `docs/VERIFICATION.md`'s 0.8 rows.
- Move this plan's lasting decisions to ROADMAP (M-6, the Charge Limit's source and its caveat,
  the cause rule, the sentinel's files).
- **Move what 0.8 didn't build forward** (RD §1.2 item 9), as 0.7's D3 moves its leftovers to
  `docs/plans/1.1/widgets.md` (P7:2040-2043): a package §7.2 cut, with its §4 section, its gate and
  its strings, to `docs/plans/0.9.0/from-0.8.md`, which 0.9.0 lands before its freeze; the causes
  still waiting for a capture (G8-2 to G8-4, their gates and fixture rule) and G8-1's `battlimit`
  fallback, if unused, to the same file under "After 1.0", linked from ROADMAP's entries.
- **Copy the session tooling forward** to `docs/plans/0.9.0/` (the script, helpers, runbooks,
  `section.sh`), as 0.6.2's D3 did for 0.7 and 0.7.1's did for 0.8 (P7:263; I-7), then remove
  `docs/plans/0.8.0/` and the ci.yml lines that name it, noting `<keep>`.
- Release (§13), the after-publishing check (§6.6), and a week later the download counts (§13
  step 8).

---

## 5. Order and parallelism

At most two agents, never two packages on one file, and never two on `Localizable.xcstrings` at
once (P7 §5). Slot 1 owns the catalog; slot 2 never touches it. One-line additions to `ci.yml` and
`Package.swift` are mechanical rebase-overs, checked by the review.

| Round | Slot 1 (the catalog) | Slot 2 (no catalog) | Waits for |
|---|---|---|---|
| C0 | A-0, the intake (orchestrator): this plan after 0.7.1, and the six preparation packages carried onto the integration branch (E-3, A-6a, P-2a, X-1a, X-2a, E-2, as `claude/080-<pkg>-r`) | | v0.7.1 published (2026-11-06); 0.7.1's D3 |
| C1 | A-1 | T-1 | C0 |
| C2 | A-2, with its widget half | A-7 | A-1 (Overview, Power, the popover, `Localized`, the report, Demo Mode); A-7: A-1 (`AppSettings`' `AppLinks`) |
| C3 | A-3 | E-1 | A-2 (`Localized`, `OverviewView`); E-1: A-1 and A-2 (the text report) |
| C4 | A-4 | F-1 | A-3 (`HealthView`); F-1: A-2's widget half (`WidgetFeed`, `WidgetFeedWriter`) |
| C5 | A-5 | | A-4 (the catalog); A-7 (the guide link) |
| C6 | P-1 | | A-5 (the catalog) |
| C7 | A-6b | | P-1 (`AccessoryMonitor`, the sentinel, `BatteryPulseApp`); A-6a (C0) |
| **Look shoot** | the M5, hands-free (§6.1), on a CI build of C7's merge | | A-1 to A-6 merged; T-1 |
| **Look review** | the maintainer at his desk (§6.2) | | the shots |
| C8 | the look's fixes; X-1b, then P-2b | K-1, once the maintainer has generated the key (I-11, M-9); no V-1 (I-12) | the look review; X-1a and P-2a (C0) |
| C9 | X-2b; E-2's gaps (their strings) | | X-2a and E-2 (C0) |
| C10 | L-1: its key list, **the Russian review** on it (§6.3), the answers, the docs; merges last | | everything above |
| D1 | freeze; RC-U and RC-F | | C10 |
| **Session R8** and its day | the M5, hands-free (§6.4, §6.5) | | D1 |
| D3 | release; after publishing (§6.6); a week later, the counts | | Session R8 |

**Why this order:**
- **A-1 first:** it settles the cause type, the sentence slot and Demo Mode that A-2 builds on, and
  it changes the text report before E-1 pins it.
- **A-2 right after A-1,** since they share six app files; its check (G8-1) needs the look shoot,
  so the earlier it merges, the more time the reader gets in CI first. Its widget half comes
  before F-1, which edits the same feed files.
- **Slot 2 after the intake:** T-1 first (C1), so the tools are re-pointed long before the look
  shoot; A-7 once A-1's `AppLinks` is in (C2); E-1 once A-1 and A-2 have changed the text report
  (C3); F-1 after A-2's widget half (C4); K-1 once the key exists (C8).
- **The look shoot after C7,** when every new screen exists: one shoot and one review, as RD asks
  ("one look review and one Russian review"). X-1 and X-2 change little that shows, so they follow
  the review, and Session R8 checks them.
- **The Russian review inside L-1,** on L-1's list of every key 0.8 added: the keys C8 and C9 add
  after the shoot (X-1b, P-2b, X-2b, E-2's gaps) would otherwise miss it, and RD §3.3 sends every
  new string through it.
- **Slot 2 is thinner than planned:** E-3, E-2 and the core halves (A-6a, P-2a, X-1a, X-2a), which
  were to fill it, were done before 0.7.1 and come in with A-0, so from C5 to C7 slot 2 has
  nothing to run, and each of those rounds is one catalog package.
- **Catalog order:** A-1, A-2 (its widget half's words with it), A-3, A-4, A-5, P-1, A-6b, the
  look's fixes, X-1b, P-2b, X-2b, E-2's gaps, L-1. T-1, A-7, E-1, F-1 and K-1 add no key.

**Files no package shares** (the review checks): `App/Localized.swift` and `Main/OverviewView.swift`
(A-1, A-2, A-3, A-4 in sequence), `Main/PowerView.swift` (A-1, A-2, A-4),
`MenuBar/PopoverView.swift` (A-1, A-2, A-4), `Main/HealthView.swift` (A-3, A-4),
`App/DemoController.swift` and `BatteryCore/DemoBattery.swift` (A-1, A-2),
`BatteryCore/BatteryReport.swift` (A-1, A-2, then E-1's goldens), `App/AppSettings.swift` (A-1's
`AppLinks`, then A-7), `BatteryCore/Widget/{WidgetFeed, WidgetReloadPlanner}.swift` and
`App/WidgetFeedWriter.swift` (A-2's widget half, then F-1), `App/BatteryPulseApp.swift` (P-1,
A-6b), `BatteryKit/AccessoryMonitor.swift` (P-1, A-6b), `Updates/UpdateViews.swift` (P-2b, X-2b,
L-1), `Tests/BatteryCoreTests/SecurityGuardTests.swift` (A-2, P-1, A-6b) and `docs/USER_GUIDE.md`
(each package its own section, in sequence, L-1 last: nearly every slot-1 package edits it, §12,
so no slot-2 package does, and F-1's sentence is L-1's). The widget target and
`BatteryCore/Widget/`'s other files are A-2's alone, and E-2's gaps' if their fix reaches the widget
(C9). **Rebase-over only:** `.github/workflows/ci.yml` (T-1, A-2, E-1), keeping P-2a's "Check the
relaunch fallback" right after "Install the way 0.6.1 does, then launch" and before "Package the
profiling build", which deletes the app it reads. `SourceScanner.swift` has one editor left, A-4
(E-3's change came in with A-0).

---

## 6. The maintainer's sittings

### 6.0 Wording, and the rules from 0.6.2's sessions

P7 §6's wording holds: "y = looks right"; comparisons as numbered choices; screenshots and
recordings as the evidence; the script reads the logs; hands-free on the M5 (one local Claude Code
session with computer use runs the script, works the screen and judges the pictures, and he is
asked only for taste, consent and the physical moments); builds install the way `UpdateInstaller`
does. The new rules, each from a session of 0.6.2:

1. **The start sentence prints only its section.** Each start line runs `section.sh`, which prints
   the one runbook section the session follows (T-1 item 4), so a session never reads, or acts on,
   another section (today's after-publishing check).
2. **Dock presence before access.** Before computer use asks for access to BatteryPulse, the
   session opens a BatteryPulse window, so the app has a Dock icon and the access request can
   name it (today's after-publishing check).
3. **Widgets are shot by the script** (`screencapture -R` at the frames `ui` reads), never by
   computer use: Notification Center, the widgets' host, can't be named in a computer-use request
   (Session B's P10, `sessions/B.md:100`).
4. **Every widget or picture check causes its own redraw** and waits for it (a reload, the
   extension's new process or the app's reload line) before the shot; no redraw within its
   timeout is "not checked", never "n" (Session B's F8-ru; P7:495-512).
5. **Preflight asks him to quit the Claude desktop app and to postpone pending macOS updates**
   (Session B: their banners at layer 23 refused the desktop click and blocked five runs,
   P7:529-532).
6. **He doesn't install the release himself before the after-publishing session starts,** even
   when BatteryPulse offers it: the session takes the before-picture and runs Install and
   Relaunch (today's after-publishing check). The start line's sentence says so, and so does D3's
   post on the release PR.
7. **Computer use ends each batch with a pointer move to bare desktop** (its 28×40 overlay fails
   the occlusion check, `sessions/B.md` 12:24), and after any script desktop click, which leaves
   the click-wallpaper-to-show-desktop state on, one computer-use click on bare desktop ends it
   (Session B, `sessions/B.md` 12:37, 13:13).
8. **Window shots use `screencapture -R` at the window's frame after the occlusion check, never
   `-l`:** `-l` leaves out what lies behind a glass sheet, so a Translucent or Clear window (Q8-4's
   badge is Clear's) would be shot without its background (Session B's P3, `sessions/B.md:97`).

**His part in all** [estimate]: about 42-48 minutes, plus 9 optional, against about 135 by hand
(RD §3: a 40-minute look sitting, an 85-minute RC sitting and 10 for Xcode).

| Sitting | Where | His time |
|---|---|---|
| Once before (best the same day): `/mcp` shows computer use; the start line's flags checked against his CLI | the M5 | 1 min |
| §6.1 The look shoot: the start line, one yes, the approvals, two beeps for the adapter | the M5 | 5-8 min (+2 with Q8-3's adapter) |
| §6.2 The look review | his desk, a PR comment | about 15 min |
| §6.3 The Russian review | his desk, a PR comment | about 10 min |
| §6.4 Session R8's start: the line, one yes, the approvals, quitting his apps | the M5 | 6-8 min |
| §6.5 Its day (passive) and its end: "day-end", the batch, his yes to `send` | the M5 | 3-4 min (+5 with Q8-6's listen) |
| §6.6 After publishing: the line, the approvals, his yes | the M5 | about 2 min |
| Optional, any night before D1: the hold watch (I-8, G8-2), started like §6.1 with `SESSION-R.md`'s section Hold watch; the line in the evening, plugged in with the lid open, his yes before `send` in the morning | the M5 | about 2 min |

### 6.1 The look shoot (hands-free, about 5-8 minutes of his)

**When:** after C7 merges, on a CI build of `claude/080-integration` (its build number above
v0.7.1's, the clock's, I-9). **Started by** the line below, in `~/BatteryPulse`, on the adapter, in
the evening or any time he can leave the Mac for about 2 hours [estimate].

```
DISABLE_AUTOUPDATER=1 claude --allowedTools 'Bash(bash ~/bp-080/L/run/docs/plans/0.8.0/m5-session.sh:*)' --permission-mode auto 'Run the BatteryPulse 0.8 look shoot hands-free: in ~/BatteryPulse run git fetch origin claude/080-integration && bash <(git show FETCH_HEAD:docs/plans/0.8.0/section.sh) FETCH_HEAD SESSION-L.md Look shoot, then follow only what it prints.'
```

The flags are [check on his CLI once before], as in P7 §6.2.

**His part:** the line; one yes to the list of changes (the build installed over his 0.7.1 and put
back, the Charge Limit set to two values and put back, the app's language switched and back,
`hasSeenWelcome` cleared and restored, Demo Mode on and off, the window style set to Clear for
Q8-4's badge (beta styles on) and back, a sentinel file placed and removed); the approvals (computer
use for BatteryPulse, System Settings and Finder, after rule 2's window); quitting his own apps;
then the adapter: unplug at a beep, plug in at a second beep about 7 minutes later. With Q8-3's yes,
a low-wattage USB-C adapter in at a third beep and the usual one back at a fourth.

**The steps** (the session's; each failure is "not checked" with its reason, and its gate takes
its default):
1. **prepare:** a fresh backup into `~/bp-080/L`; reads of the Charge Limit (System Settings'
   pane by computer use, since `battlimit` shows none at 100 %), the language, Demo Mode; builds
   `bpulse`; installs the CI build the `UpdateInstaller` way.
2. **The Charge Limit (G8-1),** first, while he is there for the beeps:
   - with his yes, the session sets the Charge Limit by computer use (System Settings → Battery →
     (i) next to Charging) to the step at or just below the charge (the hold; Apple's article
     gives the 80-100 % range, not the step, so 5 % steps are [unverified]) and reads, a
     minute later (with the charge under 80 %, the Mac charges to 80 first, and the step waits for
     the hold, up to an hour, while step 3 shoots the screens): the app's `monitor` line (source
     case and percent), `pmset -g battlimit`, `defaults read com.apple.batteryui.charging.mac`,
     `bpulse --smc`'s `CHLT` and `CHNC`, and `bpulse --json`'s key;
   - then a step above the charge, if one exists below 100 % (charging toward a limit: Session A
     saw the policy at 72 % right after a plug-in, before charging began, but never while
     charging), the same reads;
   - then 100 % (no policy, the key absent), the same reads;
   - back to the first value; **unplug at the beep;** reads at 1 and at 6 minutes on battery (the
     number gone; the policy gone after about 5 minutes); **plug in at the second beep;** reads at
     5 s and at 1 minute (the policy back);
   - A-2's sample script for each policy read; the files wait for his yes before `send`;
   - his Charge Limit set back to prepare's value, confirmed by a shot.
3. **The screens,** in English, then Russian (the app's language in System Settings → Language &
   Region → Applications, then a relaunch): every new screen, by AX and the script's window shots
   (rule 8):
   - each Demo Mode scene of A-1 (Overview, the popover, Power) and A-2's number;
   - Health's summary (A-3) and Clear's badge in the worn-battery scene (Q8-4);
   - one row's help tag and info popover per page (A-4);
   - Welcome (A-5), with `hasSeenWelcome` cleared, then restored;
   - Report a Problem (A-6): the window, the preview's top and its end, both choices; the file it
     saves goes to the session folder, and the script checks it for this Mac's serial (from
     `ioreg`), the user name and the home path;
   - P-1's note: with BatteryPulse quit, the script places the accessory sentinel file and
     relaunches; the Accessories page with the note and **Turn On Again**, then an AX press on it
     and the file gone (RD §3.3: the resilience strings ride with the look review);
   - the help link's URL (A-7), read from the log line, not the browser.
4. **The weak adapter (Q8-3, optional):** a low-wattage adapter in at a beep, a bounded CPU load the
   script runs for 2 minutes, `bpulse --raw` captures at 30 s and 2 minutes, the usual adapter back
   at the next beep. G8-3 decides from them.
5. **Restore and the summary:** his 0.7.1 reinstalled, every changed setting put back from
   `changes.tsv`, and a summary in his language with an alert for anything not confirmed back.
6. **The shots go to a PR comment** (by `send`, after his yes, through the privacy lint), numbered
   for §6.2 and §6.3.

### 6.2 The look review (at the desk, about 15 minutes)

A PR comment with the English shots, each question offering the plan's answer first (RD §1.2
item 8). He answers in the comment; without an answer, the defaults apply.
1. "Why it isn't charging (A-1): the Charge Limit's sentence and the Battery Settings… button on
   Overview and in the panel: y, or say which." (default y)
2. "Not charging with no reason the battery reports: **1** an info button listing Apple's possible
   reasons (shown), **2** nothing, as today." (Q8-1; default 1)
3. "The Charge Limit's number on Power ('80 %', '80 %, reached'), in Overview's sentence and in the
   widget's Charge limit field (CI's previews): y, or say which." (only if G8-1 passed; default y)
4. "Health's summary at the top (Condition, Maximum capacity, Cycle count): y, or say which."
   (default y)
5. "Clear's badge for a capacity under 80 % that macOS calls Normal: **1** 'Maximum capacity
   below 80 %' (shown), **2** 'Service Recommended', as today." (Q8-4; default 1)
6. "A row's help tag and its info popover (pictures from each page): y, or name the row."
   (default y)
7. "Welcome (one window, six lines): y, or say which line." (default y)
8. "Report a Problem: the window and its preview: y, or say what." (default y)
9. "Accessories after a read was interrupted (P-1): the note and Turn On Again: y, or say
   what." (default y)
10. Any further cause G8-2 to G8-4 brings: "its sentence and Demo scene: y, or say which."

**Pre-answers:** the orchestrator checks each shot against the plan's text and the catalog first,
and marks what it found, so he mostly confirms.

### 6.3 The Russian review (at the desk, about 10 minutes)

A second PR comment, posted by L-1 in C10 once every other catalog package has merged: the look
shoot's screens in Russian beside the English, and L-1's list of every new key with its Russian
(§8). The keys no shot shows (C8's and C9's: X-1b's and X-2b's VoiceOver words, P-2b's two update
errors, which need a refused update to appear, and E-2's gap explanations) are reviewed as words,
English beside Russian. "y = reads right, or name the key and the word." L-1 applies each fix as a
one-key commit before it merges. Without an answer, L-1's terminology pass stands.

### 6.4 Session R8 (the release candidate, hands-free; about 6-8 minutes at its start)

As P7 §6.2's Session R: one local session on the M5, the CLI with computer use, runs
`bash ~/bp-080/R/run/docs/plans/0.8.0/m5-session.sh <step>` and does every step itself; he does
only the start line and one yes, the approvals, quitting his apps (rule 5), the Focus, and his
yes before `send`. The runbook is `SESSION-R.md`'s section R8.

```
DISABLE_AUTOUPDATER=1 claude --allowedTools 'Bash(bash ~/bp-080/R/run/docs/plans/0.8.0/m5-session.sh:*)' --permission-mode auto 'Run the BatteryPulse 0.8 Session R8 hands-free: in ~/BatteryPulse run git fetch origin claude/080-integration && bash <(git show FETCH_HEAD:docs/plans/0.8.0/section.sh) FETCH_HEAD SESSION-R.md R8, then follow only what it prints.'
```

**His yes covers** the list P7 §6.2 names, plus: Keyboard navigation on (System Settings →
Keyboard) and the accessibility display options (Reduce Motion, Prefer Cross-Fade Transitions,
Reduce Transparency, Increase Contrast, Show Borders, the Liquid Glass slider) each switched and
put back; the app's language; the Charge Limit only if step 9 sets it; a sentinel file placed and
removed (step 11). Xcode's components: if Xcode asks to install them (Session B, `sessions/B.md`
13:13), that prompt is his at the start, or the Xcode steps record "not run".

**The steps** (the GUI phase runs while he is away, about 2-3 hours [estimate], capped at 4):
1. **prepare:** backup, reads, `bpulse` built, P-checks again on 0.8's windows.
2. **Install RC-U** over his 0.7.1 the `UpdateInstaller` way; About reads 0.7.99; the widgets
   placed from 0.7.x shot by the script after a redraw (rule 4): unchanged, since 0.8 keeps off the
   widget, but for the Charge limit field's number when A-2 ships (I-6).
3. **The tree VoiceOver walks (C10),** in English and Russian: `ui tree` over every page of the
   main window, the compact window, the popover, every Settings pane, About, What's New, Software
   Update, Welcome and Report a Problem. The script checks that every control has a role and a
   non-empty label, that only decorative images lack one, that `PowerFlowView`, `CapacityBars` and
   the rings read as one element with a value, and that each chart has its label and descriptor
   (X-1) [uncertain: whether AX exposes the descriptor; else Accessibility Inspector by computer
   use, a shot per chart]. **The widgets** (C10 names every family): `ui tree` at each placed
   BatteryPulse widget, against `WidgetAccessibility`'s labels, as 0.7's Session R step 7 planned
   (P7:2367-2386), in Russian after a redraw (rule 4): every kind and family, the History and
   iPhone & iPad kinds included, since neither 0.7.0 nor 0.7.1 read them (I-14).
4. **The keyboard (C10):** with Keyboard navigation on, posted Tab, Shift-Tab, arrows, Space and
   Return, and after each the focused element read by AX: the sidebar, the toolbar, the tile
   pickers, Raw Data's table and filter, the update window, Report a Problem's Save. Each path
   reached is y; one that can't be reached names the control.
5. **The contrast audit (A11Y-03, C10):** Accessibility Inspector's audit by computer use on each
   page in Standard and Frosted, Light and Dark, and with Increase Contrast (beta styles exempt);
   a shot per audit and the failures listed. A failure is a fix before D3, or the row stays open
   with its reason (G8-7).
6. **The Stage 1.4 pass (A11Y-02):** each display option on and off with shots of the main and
   compact windows and the popover, judged against Stage 1.4's open check (R:370-373: the Liquid
   Glass slider at both ends, Reduce Motion, Prefer Cross-Fade Transitions, Reduce Transparency,
   Increase Contrast and Show Borders; RD C10 cites it as R:298-301, an older base).
7. **Menu bar icons (A11Y-04):** `scripts/menu-bar-shots.sh` with the status item's AX frame (P11,
   which passed in Session F and AP71) and `screencapture -R`, else a computer-use crop: Increase
   Contrast and Reduce Transparency, a light and a dark bar, on the M5's notch display.
8. **The Russian pages:** every page and window in Russian, judged against §6.3's answers.
9. **The Charge Limit live** (only if G8-1 passed and he said yes): the hold set as in §6.1 step 2,
   Overview's sentence and Power's number against `pmset -g battlimit`, then put back.
10. **Report a Problem on the RC:** both choices, saved, and the file checked as in §6.1 step 3;
    the crash reports' names match `ls` of the folder (G8-5).
11. **The sentinel (P-1):** with BatteryPulse quit, the script places the accessory sentinel file
    and launches the app: the Accessories page shows the note (a shot); Turn On Again by an AX
    press; the file is gone and the page reads. The same for devices only if device reading is on.
11b. **Optional, in the GUI phase:** WP-18's Xcode items (SUI-17's previews, SUI-19's timing,
    SZ-10's icon), still open (I-14), as 0.6.2's Session B ran them.
11c. **In the GUI phase, the checks 0.7.0 and 0.7.1 shipped without** (ROADMAP Stages 1.8 and
    1.9, `docs/VERIFICATION.md`; I-13, I-14), from the steps 0.7.1's script already has: placed
    widgets across the update from 0.6.2's static widget (its step 2's first half), the other sizes
    from the gallery, the edit sheet in both languages with Details' and One device's choosers, the
    widgets in BatteryPulse's own language set the user's way, the rendering modes and time left,
    the Accessories widget, the Battery and Accessories widgets' clicks and a click with
    BatteryPulse quit, the feed's rewrites and Demo Mode, Settings' other panes and Welcome on the
    Air's display (AP71 saw General scroll), and the maximum-capacity readings, each another way
    where computer use couldn't act (T-1 item 5). They may reach the 4-hour cap (AC71's V-0 rows):
    T-1 orders them after 0.8's own, and what doesn't fit stays open in `docs/VERIFICATION.md` with
    its reason. F12 (step 12) and the reloads per kind (§6.5) are the rest.
12. **F12** (at the day's end, after the measurements, as P7 §6.3: the rate check first): RC-F
    (0.5.99) → Check for Updates → Install and Relaunch, by AX presses: did BatteryPulse come back
    as the published 0.7.x? y/n.
13. **Start the day:** the `perf` stream under `nohup`, the display assertion released; the
    session ends its turn.

### 6.5 The day, and its end (passive, then about 3-4 minutes)

- **During the day:** nothing to do.
- **"day-end":** the script stops the stream and records: crash reports for BatteryPulse and
  BatteryPulseWidget since prepare (must be 0, G8-10); `fault` messages in the subsystem (must be
  0); the reads, and the Charge Limit reader's reads per trigger (§10); G7-11's reload delivery per
  kind, which 0.7.0 and 0.7.1 left open (I-13). Then F12 (step 12), his batch, the optional
  VoiceOver listen (Q8-6: five minutes with VoiceOver on Overview, Power and Health, in Russian;
  "y = names make sense"), his yes and `send`, then `restore end` (his 0.7.1 reinstalled for §6.6,
  every setting put back from `changes.tsv`).

### 6.6 After publishing (a short session, about 2 minutes of his; D3)

From the restored 0.7.1, with his widgets placed. D3 posts the start line on the release PR, with
`<n>` (the release PR) and `<keep>` (the last commit holding `docs/plans/0.8.0/`) filled in. Rules 3
and 4 need the script, so the line carries its allow rule, and the section first makes the worktree
`~/bp-080/D3/run` at `<keep>`, as P7 §6.2's short sessions do (0.6.2's check had no script):

```
DISABLE_AUTOUPDATER=1 claude --allowedTools 'Bash(bash ~/bp-080/D3/run/docs/plans/0.8.0/m5-session.sh:*)' --permission-mode auto 'Run the BatteryPulse 0.8.0 after-publishing check hands-free: in ~/BatteryPulse run git fetch origin refs/pull/<n>/head && bash <(git show <keep>:docs/plans/0.8.0/section.sh) <keep> SESSION-R.md After publishing, then follow only what it prints. Do not let anyone install the update before the before-picture.'
```

1. **Before anything:** he hasn't installed 0.8.0 (rule 6); the session opens BatteryPulse's main
   window (rule 2), then asks for access; the before-picture (the script's widget shots, rule 3,
   and `pluginkit`).
2. Check for Updates → Install and Relaunch to 0.8.0 by AX presses; About reads 0.8.0; What's New
   appears once with 0.8's list (without the version-count row, since 0.7 already announced
   it).
3. The widgets after a redraw (rule 4): **1** same, **2** blank or grey, **3** gone, **4**
   different; the `update` log's pre-swap line and no CHSErrorDomain 1103.
4. P7 §6.4's list: History, settings, `codesign -dv` (`flags=0x10002(adhoc,runtime)`), no
   quarantine, the login item, notification permission; no prompt for BatteryPulse's own data
   after the update (SEC-06, "repeated in every after-publishing check", RD §5.1); plus Help →
   Report a Problem… opens, and Help opens the guide at `v0.8.0` (from the log line).
5. **On a 2 or 4, or any other failure:** `gh release edit v0.8.0 --prerelease`, on his yes, and
   fix forward.
6. The first day's comparison: the popover against the widget, as P7 §6.4 step 7.

### 6.7 Risks the sittings watch

- **The tree is not VoiceOver:** a label the tree shows may still read badly. Q8-6's listen is the
  backstop, and NEW-20's Russian screenshot set (0.9.0) looks again.
- **The chart descriptor through AX** may not be readable by a script [uncertain]: Accessibility
  Inspector by computer use, else "not checked" and the row stays open.
- **The Charge Limit check needs his adapter and a charge near a step;** a charge above the limit
  gave the hold (83 % under 80 %, `sessions/A.md` 23:48), so a charge at 100 % should give it at
  any limit [inference], and step 2 always has at least the hold and 100 %.
- **The widget's own crashes** stay outside P-1's sentinel: the widget can't write files of ours.
  A crash shows as a blank widget, and `day-end` counts its crash reports (G8-10).
- **Xcode's component prompt** after a macOS update (Session B) blocks steps 3 and 5's
  Accessibility Inspector: his yes at the start, else "not run" and G8-7's default.
- **A banner over the desktop** (rule 5), **a pointer overlay** (rule 7) and **a setting left
  changed** (the summary he reads first, with its alert) as in 0.6.2.

---

## 7. Gates and their defaults; cut line; frozen surfaces

### 7.1 Gates

| Gate | Decides | Measured by | If no measurement comes |
|---|---|---|---|
| **G8-1** the Charge Limit's source | whether A-2's number ships, and from which source | §6.1 step 2: the app's own logged number equals `pmset -g battlimit`'s at the hold and, if possible, at a second limit; nil at 100 % and on battery; the policy back after a plug-in; no prompt; plus A-2's redacted samples as fixtures | **The number stays unknown** (a known limitation, RD §2.5): before D1 the reader's wiring is reverted and the parser stays (a default never ships read-path code no M5 run exercised, RD §1.2 item 3); Power keeps "Reached". The plist failing and `battlimit` passing: the `Process` fallback (+1 run) only on the maintainer's look at its guard exception |
| **G8-2** the optimized hold's cause | `NotChargingCause.optimizedHold` | QUA-06: 0.8's `hold-watch` night before D1 (0.7.0 and 0.7.1 ran none, I-8); a capture of the Mac's battery with IOPS "Optimized Battery Charging Engaged", and whether bit 24 is set with it | No capture: the cause waits until after 1.0, and today's "Charging on hold" stays (RD §5.1). A hold that sets bit 24: W-14's precedence (the flag wins) is checked against the capture before the case lands |
| **G8-3** a weak adapter's cause | `NotChargingCause.insufficientPower` | §6.1 step 4 (Q8-3): a capture with a low-wattage adapter under load that shows a key for it (a `NotChargingReason` or `SlowChargingReason` bit, or `AdapterDetails.ErrorFlags`) | No capture, or only a heuristic (input power against the load): not shown; Q8-1's general line covers it |
| **G8-4** heat's cause | `NotChargingCause.heat` | Any `bpulse --record` capture (CL) or session capture that shows a charger key at the time (`TimeChargingThermallyLimited` or a reason bit) with a high battery temperature; nobody heats the Mac on purpose | Not shown in 0.8 (Q8-5); Power's thermal row and the heat alert stay as today |
| **G8-5** reads from the app's own process | A-2's file read, A-6's crash-folder listing | §6.1 steps 2-3 and §6.4 step 10: no prompt, and the app's values equal Terminal's | A prompt or a refusal: that read is dropped before D1 (A-2: G8-1's default; A-6: the names read "not readable") |
| **G8-6** VoiceOver's view (C10) | X-1, X-2; the widget rows 0.7 left open (I-14) | §6.4 step 3 in both languages, Q8-6's optional listen | "Not checked": 0.8 ships the code (it removes nothing), the row stays open in `docs/VERIFICATION.md`, and 0.9.0's sitting runs it again |
| **G8-7** the contrast audit (C10, A11Y-03) | colour fixes | §6.4 step 5 | A failure in Standard or Frosted: a fix before D3 (a tone-map value), or the row stays open with its reason; not run: 0.9.0's sitting |
| **G8-8** the keyboard paths (C10) | X-2 | §6.4 step 4 | As G8-6 |
| **G8-9** the update path | the release | F12 (§6.4 step 12); §6.6; P-2's CI checks (99.0 refused; the fallback check) | F12 fails: the installer's last good code (as 0.6.2's G-16). §6.6 step 3 shows 2 or 4: `--prerelease`, fix forward |
| **G8-10** crashes and faults | whether the RC ships | §6.5's `day-end` | Any crash report or `fault`: no D3; fix forward, a new RC, and the steps the fix touches again |
| **G8-11** the looks | every new screen | §6.2 and §6.3 | The plan's answers (each question's default) |
| **G8-12** size | ceilings and cuts | CI's size report (§9) | A raise in a commit of its own; above the outer bounds, §9's cut order |
| **G8-13** the report's redaction | A-6 ships | A-6's Linux tests and the session's file checks (§6.1 step 3, §6.4 step 10) | Never cut: a leak is fixed before D1 |

### 7.2 Cut line

**Never cut** (RD §3.3, plus the process packages): A-0, A-1 (NEW-01), A-3 (NEW-02), A-4 (NEW-03),
A-6 (NEW-05), X-1 (A11Y-01), X-2 (NEW-07), P-2 (NEW-16 with SEC-07), E-1 (NEW-08), E-2 (NEW-09,
NEW-10), T-1, L-1 and D1-D3.

**Conditional:** A-1's extra causes (G8-2 to G8-4); K-1, which moved here (I-11) and waits only for
the key (M-9). V-1 isn't needed (I-12).

**Cut in this order if the budget runs short** (RD §3.3; a cut item moves to 0.9.0, lands before
its freeze, and one with a look joins 0.9.0's screenshot sitting; each is still in 1.0, C1, C12,
C17):
1. A-2, FEA-35's number, with its widget half (0.7's "Reached" stays);
2. A-7, NEW-06;
3. A-5, NEW-04 (Welcome keeps embedding General, so the version count's announcement stays);
4. F-1 (the feed keeps a removed kind's section until BatteryPulse quits, as 0.7.1's guide says);
5. P-1, NEW-14.

E-3, the fourth when this plan was written, was done before 0.7.1 and comes in with A-0, so nothing
of it is left to cut.

**Effort, in runs [estimate],** as the plan was written: A-1 2-3, A-2 2-3, A-3 1, A-4 2-3, A-5 1-2,
A-6 (a, b) 3, A-7 1, X-1 (a, b) 1-2, X-2 (a, b) 2-3, P-1 1-2, P-2 (a, b) 2, E-1 2, E-2 2-3, E-3
1-2, T-1 2-3, L-1 2, D1+D3 2-3: about 29-40, close to RD §3.3's 30-38. **What remains after the
intake** (A-0, 2026-11-06), with the a and b halves split by this estimate:

| Package | Runs | | Package | Runs |
|---|---|---|---|---|
| A-1 | 2-3 | | X-2b (X-2a done) | 1-2 |
| A-2, with its widget half | 3-4 | | P-1 | 1-2 |
| A-3 | 1 | | P-2b (P-2a done) | 1 |
| A-4 | 2-3 | | E-1 | 2 |
| A-5 | 1-2 | | E-2's gaps (E-2 done) | 0-1 |
| A-6b (A-6a done) | 2 | | F-1 | 1 |
| A-7 | 1 | | T-1 | 2 |
| X-1b (X-1a done) | 1 | | L-1 | 2 |
| K-1, once the key exists | 1 | | D1+D3 | 2-3 |

- **Totals:** about 25-33 runs left, plus K-1 (1) and 3 to fix forward; the six preparation
  packages took about 7-9 before 0.7.1 (E-3 1-2, E-2 2-3, the four core halves 1 each). The
  never-cut work left is about 18-23.
- **Extra work:** `battlimit`'s fallback (+1), each cause G8-2 to G8-4 brings (+1 each). Of §2.1's
  conditional items only K-1 came (in the table): W-14 and W-13 shipped in 0.7.0, and so did
  `docs/VERIFICATION.md` (no V-1).

### 7.3 Frozen surfaces 0.8 changes on purpose, and how the notes say so

The frozen surfaces P7 §7.3 and 0.7.1's (P71 §7.3, ROADMAP Stage 1.9) list, with the earlier lists
they build on, hold, except these intended changes:

| Surface | 0.7.x | 0.8 | Release notes line (§13) |
|---|---|---|---|
| **`bpulse --json`, `--watch --json`, Copy JSON** (C14 item 4) | `formatVersion` 1 (S-1) | Plus `systemChargeLimitPercent` (Int) only when known, on AC (A-2, if G8-1 passes). `formatVersion` stays 1: an added key, by S-1's rule | "For scripts: `bpulse --json` adds `systemChargeLimitPercent` when macOS's Charge Limit is known" |
| **The text report** (not frozen, M-6) | `Not charging reason: 0x…` | The cause's name after the hex; "Charge limit: 80 %" when known | "The text report names why the battery isn't charging, when it knows" |
| **`bpulse --smc`'s text** (not frozen, M-6) | `CHLT` and `CHNC` without values | With values | (the same line, if any) |
| **Storage** (C14 item 2) | `HistoryStore` imports a legacy `samples.jsonl` | No longer read (QUA-15) | "History no longer imports files from development builds before 0.3" |
| **Application Support** | `History/`, `Devices/`, the widget's files | Plus `Sentinel/` (P-1): internal, not a 1.x promise, removed at Turn On Again | — |
| **The widgets' feed** (`Widget/feed.json`, 0.7.1) | Version 1, internal, its schema only gains fields (P71 §7.3) | Plus an optional field for the Charge Limit's number (A-2 item 8); a removed widget's section leaves within about an hour, not at quit (F-1) | A-2's line below; F-1's in the privacy row |
| **Settings keys** (C14 item 1) | 0.6.x's keys, `betaWindowStyles`, W-13's three, W-4's `lastSeenLanguage` (0.7.1 added none) | **Unchanged:** none added, none changed | — |
| **The capture format** (C14 item 3) | Four top-level keys | Unchanged; no thermal-state key (Q8-5) | — |
| **Widgets** (C14 item 5) | P7 §7.3's new surfaces and 0.7.1's (the History and iPhone & iPad kinds, `historyChart`, two fields) | The `systemChargeLimit` field's value shows the number from the feed (A-2 item 8; its meaning frozen, its value not, I-6); every kind, intent, parameter, raw value and family unchanged | "The widget's Charge limit shows the percentage too" (with A-2's) |
| **The update contract** (C14 item 6) | The DMG, `.sig`, dSYMs, `BatteryPulse-count.txt` | Unchanged. The installer also refuses a bundle that needs a newer macOS or a volume that can't swap, and puts the old copy back if the new one doesn't launch (P-2) | "Updates check that the new version runs on your macOS before installing it" |
| **Privacy** (C14 item 8) | The update check, a chosen download, the version count; the feed, which never leaves the Mac | Unchanged: Report a Problem saves a file and sends nothing (§11); the feed drops a removed widget's section within about an hour (F-1) | "Help → Report a Problem… saves a file you can attach to an issue; nothing is sent"; "A widget you remove stops counting for the widgets' file within about an hour" |
| **The Help menu** | BatteryPulse Help (at `main`), What's New | Plus Report a Problem…; Help opens the guide at the release's tag | (the line above) |
| **Welcome** | Embeds General | Six lines and their controls (A-5); the same two keys | — |
| **`WhatsNew.version`** | 0.7.1 (What's New after every update since 0.7.1) | 0.8.0 | — |
| **`ChargeState`** | Five cases | Unchanged: the cause is computed (A-1) | — |
| **Signposts** (CL) | P7 §7.3's and 0.7.1's | Unchanged names; A-2's reads stay inside `read`, A-6's assembly adds `report.build` | — (CL's list) |

**New frozen surface 0.8 creates:** the `--json` key `systemChargeLimitPercent`, if A-2 ships (C14
item 4: once shipped, only added to; its absence stays valid). E-1's `FrozenSurfaceTests` and
goldens pin it with the rest, and D1's `git grep` lists it.

---

## 8. Localization

**Rules** (CL "Localization"; P7 §8): every literal a `LocalizedStringKey` or `String(localized:)`
keyed by its English text, with its Russian in the catalog in the same commit; placeholders `%@`
only; no counted phrases (label and value); never a ternary of literals to `Text`; Apple's Russian
terminology (System Settings → Battery, Menu Bar, Accessibility; Apple's Russian Charge Limit
article, https://support.apple.com/ru-ru/102338); the catalog's English follows macOS's US
spelling. The catalog's translation of "Charging on hold" stays Optimized Charging's (P7:1554-1555).

**New keys (English), by package** [count estimate in brackets]; the final wording is the look
review's and L-1's:

| Package | New keys |
|---|---|
| A-1 [6-10] | the general reasons' popover text (Q8-1) and its title · "Battery Settings…" · each new cause's sentence · the glossary line's added observation (it replaces today's line) · Demo scenes' titles and details |
| A-2 [3-5] | "%@, reached" · Overview's sentence with the number ("Charging stopped at the Charge Limit, %@, set in System Settings → Battery.") · the Demo scene's detail · the widget field's value, which the widget's own table takes (item 8; SIZ-07) |
| A-3 [2-4] | "As macOS reports it in System Settings → Battery." · "Maximum capacity below 80 %" (Q8-4) · the card's title if it needs one |
| A-4 [36-48] | for each explained metric, a short help (75 characters or fewer) and a long text · the info button's accessibility label |
| A-5 [10-14] | six lines and their buttons' titles ("Menu Bar Settings…", "Turn On", "Show How", "Settings…"); the count's toggle and footer are W-13's keys, reused |
| A-6b [10-14] | "Report a Problem…" · the window's title, intro and its "nothing is sent" sentence · "Include the crash reports' contents" · "Save…" · the save's message and confirmation label · "Couldn't Save the Report" |
| X-1b [5-8] | the charts' labels and descriptor titles, the series names (most reuse "Charge", "Battery power", "Temperature") |
| X-2b [4-8] | the components' labels and value formats ("%@ from the adapter, %@ to the Mac, %@ to the battery"-style, each a `%@` phrase) |
| P-1 [3] | the note for accessories and for devices · "Turn On Again" |
| P-2b [2] | "This update needs a newer version of macOS (%@)." · the swap error's text |
| L-1 [6-10] | What's New's entries, net of 0.7's removed ones |

**Count [estimate]:** about 90-130 new keys. Most are A-4's, so A-4's English is written short.

**Checks:** `LocalizationCatalogTests` (missing or unused keys, placeholders, no Cyrillic outside
the catalog), extended by X-2b to `accessibilityValue(` and `accessibilityHint(`; A-4's length test
for help tags; the Russian review (§6.3); `scripts/string-tables.swift` in both bundles.

---

## 9. Size budget

**Where it starts:** v0.7.1's CI size report (RC-U's, whose code v0.7.1 is), recorded by A-0 in
Appendix C: the app binary 3,249,712 B (ceiling 3,413,000), its `__text` 2,174,176 B (2,283,000),
`app_kb` 5,156 (5,414), the widget binary 1,615,152 B (1,696,000), `strings_bytes` 140,189 B
(147,200), the DMG 1,591,826 B (1,672,000). **After the carry-over** (the intake's head `2ca4c9b`,
`ci.yml` run 613, Appendix C's carry-over block), what the rounds start from: the app binary
3,283,984 B (129,016 B left), its `__text` 2,198,896 B (84,104 B left), `app_kb` 5,236 (178 left),
the widget binary 1,665,952 B (**30,048 B left**), its `__text` 1,047,248 B (**30,752 B left**),
`widget_appintents_bytes` 27,404 B (1,396 B left), `strings_bytes` 140,189 B (7,011 B left), the DMG
1,620,770 B (51,230 B left, +1.8 % over the published v0.7.1); no ceiling raised. The six packages
grew the widget more than the app (its binary +50,800 B, the app's +34,272 B), though the widget
calls none of their code: BatteryCore's code stays in every binary that links it unless nothing can
reach it, and an async function, a type's value witnesses and conformances only tests use all keep
it reachable (A-6a's `3741d40`, which kept most of the report out for that reason). Each branch's
own CI, against v0.7.1's widget `__text`: X-1a +13,404 B (`ChartSummary`), A-6a +6,600 B, E-2 +2,932
B, P-2a +1,004 B, E-3 −2,804 B, X-2a −476 B; and the binary grows mostly in 16 KB pages (X-1a's 13
KB of `__text` took it up 33,152 B), so 30 KB is one or two pages. For reference, before 0.7, at
WP-15's final head (`64f8aaa`, 2026-10-24, AC62:109): app binary 2,837,888 B (ceiling 3,000,000),
widget binary 778,640 B (818,000), DMG 1,257,281 B (1,520,000), `app_kb` 4,004 (4,840); string
tables 238,124 B at 0.6.1 (R:529; ceiling 251,000). At `0ecca33` itself (CI run 41077479486, from
`0d26a6d`'s message): widget binary 778,672 B, string tables 239,574 B. Ceilings:
`scripts/size-budget.json`.

**0.8's growth [estimate]:**
- **Strings:** about 90-130 keys, with A-4's long texts the bulk: about 150-300 B of Russian per
  key per table, in the app's bundle alone, since 0.7.1's widget has a table of its own that takes
  only the keys its sources name (SIZ-07, `scripts/widget-strings.swift`), A-2's few among them:
  so about 15-40 KB of `strings_bytes`, against the 7,011 B left under its ceiling. The first
  package that adds a few dozen keys crosses it, and the size report then fails the macOS job, so
  that package raises it in a commit of its own (the rules below), not D1.
- **App binary:** about 60-150 KB for the report, the explanations, the descriptors and the
  installer checks. Against 3,413,000 B (129,016 B left after the carry-over), a raise is likely;
  the app's `__text`, with 84,104 B left under 2,283,000, is the tighter; C6's 5 MB outer bound
  holds.
- **Widget:** A-2's widget half (a field's value and its words, in A-2's messages, §3), and
  whatever of the new BatteryCore code the widget can reach, with about 30 KB left under both of
  its ceilings. A-1 to A-5's BatteryCore halves keep app-only code out of its reach as `3741d40`
  did (no async function in BatteryCore, inputs passed as parameters, no conformance only tests
  use), and a package whose CI still crosses a widget ceiling raises it as below, with the
  widget's growth in its message.
- **DMG:** about 20-40 KB compressed, against the 51,230 B left after the carry-over.

**Rules:** a package that crosses a ceiling raises it in a commit of its own that says why, at its
build plus about 5 %, as 0.7's W-3a and 0.7.1's Z-1 did (G8-12); D1 sets every ceiling at the RC
plus about 5 % (P7 §9). Outer bounds: the app binary under 5 MB (C6); every other ceiling starts
from 0.7.1's D1 (AC71's D1 item 6), where 0.7.1's outer bounds left them. **Cut order if a bound
is crossed:** A-4's long texts shortened first (SIZ-07 shipped in 0.7.1); then the cut line (§7.2).

---

## 10. Energy

0.8 adds no periodic work: no new `sleep`, no timer, and `EnergyGuardTests`' one-shots stay as
they are unless P-2's relaunch wait is Swift (then one, with its reason). C5 (energy within 15 %
of 0.6.2, measured at the final 0.9.x) is the bar, and these keep 0.8 inside it:
- **A-2's reader:** one read of a small file (about 1-2 KB [estimate]) per trigger: the first read
  on AC after launch, an external-power change, a bit-24 change, Power appearing. Never per poll;
  `day-end` counts the reads per trigger (§6.5).
- **A-6:** reads only when the window opens (one battery read, one accessory read, a folder
  listing); `PerfSummary` updates an in-memory dictionary per signpost, no I/O.
- **P-1:** one file created and one removed per batch of private calls (an accessory read, a device
  read or listing), which already cost far more [estimate: microseconds against milliseconds].
- **X-1:** the chart summaries are built with the chart data, off the main actor, only while
  History is shown.
- **A-1, A-3, A-4, A-5:** decisions and views only.
- **A-2's widget half:** no write of its own: the number rides the feed's existing writes.
- **F-1:** at most one WidgetKit question an hour while BatteryPulse runs, at a routine feed write
  that happens anyway; no timer, task or sleep.

`perf-stats` on Session R8's day compares reads per hour with the last session that logged them,
0.6.2's Session B (0.7.0 and 0.7.1 logged no day; §3): no more than A-2's triggers add.

---

## 11. Privacy

- **Nothing is sent (M-11).** Report a Problem saves a file where the user chooses; then the
  browser opens GitHub's issue chooser, an ordinary page the user fills in himself. The app's
  internet requests stay the three P7 §11 lists (the update check, a chosen download, the version
  count), all to GitHub through `UpdateNetwork`. A-6's guard keeps network APIs out of its files.
- **What the report holds** (A-6): the battery capture with serials, `ManufacturerData` and
  `MfgData` removed (as Export Capture); accessories pseudonymized (as `--accessories --raw`); the
  last device capture redacted (as `--device --raw`); the version, build, macOS version string
  and Mac model; allow-listed settings (no paths, no accessory names); this session's `perf`
  counts; crash reports' names. **Only on the second choice:** their contents without
  `crashReporterKey` (Apple calls it "an anonymized per-device identifier" that is the same across
  a device's reports) and `incident`, with the home folder as `~` (Apple already replaces
  user-identifiable path components in `procPath` and image paths). Nothing from powerd's plist
  beyond the number.
- **The preview is the file:** byte for byte (A-6), so he sees all of it before saving.
- **powerd's plist** (A-2): read-only, on AC; `bootSessionUUID`, `token` and `owner` are never
  decoded, logged or stored; the committed samples have them zeroed in place (A-2 item 6).
- **Logs:** E-3's guard enforces CL's rule from 0.8 on (no `.public` path, error description,
  name, serial, UDID or device key); A-2 logs a case name and a number.
- **The sentinel** holds nothing but its own presence.
- **The widgets' feed** (0.7.1's `Widget/feed.json`, which never leaves the Mac): A-2 adds only
  the Charge Limit's number, a macOS setting; F-1 takes a removed widget's section out within about
  an hour instead of at quit, while another BatteryPulse widget stays placed (an empty answer keeps
  0.7.1's fail-open, so with none placed the feed holds all the settings allow, as today).
- **The privacy statement** (P7 §11, in README and UG) stays word for word, with one sentence added
  in UG's Privacy section: "Report a Problem saves a file on your Mac; BatteryPulse sends nothing";
  and the feed's line there (0.7.1's) changes with F-1: a kind you remove stops counting within
  about an hour, not when BatteryPulse quits.

---

## 12. Docs

| Document | Change | Package |
|---|---|---|
| `docs/USER_GUIDE.md`, Overview and Power | Why it isn't charging: the causes BatteryPulse names, the info button, Battery Settings…; the Charge Limit's number on AC, unknown on battery, and why | A-1, A-2 |
| `docs/USER_GUIDE.md`, Widgets | The Charge limit field shows the percentage when BatteryPulse knows it (A-2 item 8) | A-2 |
| `docs/USER_GUIDE.md`, Health | The summary; what "Maximum capacity below 80 %" means and what "Service Recommended" means | A-3 |
| `docs/USER_GUIDE.md`, Understanding the numbers (UG:533-563) | Kept; it says the same explanations sit next to each number | A-4 |
| `docs/USER_GUIDE.md`, First launch | The new Welcome | A-5 |
| `docs/USER_GUIDE.md`, Reporting a problem (UG:659-666) | **Rewritten** around Report a Problem, with no `swift run bpulse` (C17) | A-6b |
| `docs/USER_GUIDE.md`, a new Accessibility section | VoiceOver, the keyboard paths, the chart descriptors | X-2b |
| `docs/USER_GUIDE.md`, Accessories and iPhone and iPad | The sentinel's note and Turn On Again | P-1 |
| `docs/USER_GUIDE.md`, Updates | What the installer checks and the fallback | P-2 |
| `docs/USER_GUIDE.md`, Privacy | One sentence (§11) | A-6b |
| `docs/USER_GUIDE.md`, Privacy (the feed's paragraph) | "A kind you remove can still count until BatteryPulse quits" becomes within about an hour (§11), if F-1 shipped | L-1, from F-1's PR (F-1 runs beside A-4, which edits the guide, §5) |
| `.github/ISSUE_TEMPLATE/bug_report.yml` | The capture field points to Report a Problem | A-6b |
| `CLAUDE.md` | **Layout:** `NotChargingCause`, `SystemChargeLimitSource` (and the reader in BatterySource), `HealthSummary`, `MetricExplanation`, `ProblemReport`, `PerfSummary`, `ChartSummary`, `AccessibilityText`, `SentinelPolicy`, `SystemIdentity`. **macOS 27 layout:** the Charge Limit's number from powerd's plist on AC only. **Guards:** `ExplanationGuardTests`, `LogPrivacyGuardTests`, `FrozenSurfaceTests` and the goldens; SecurityGuardTests' new placements; E-2's `StorageCompatibilityTests` (every storage format, the feed's included), `PerturbationTests` and `DegradationTests` (with the source text it pins, §4 E-2). **Language:** `SystemIdentity`'s `unsafe` sysctl in BatterySource's list. **Signposts:** `report.build`. **Releases:** the installer's minimum-system check and the relaunch fallback, with `scripts/relaunch-fallback-check.sh` and its CI step. **Logging:** "enforced by `LogPrivacyGuardTests`". **Widget/:** `WidgetPlacements`' renewal (F-1) and the feed's Charge Limit field (A-2) | L-1 (each package lists its lines in its PR) |
| `docs/ROADMAP.md` | The 0.8 entry rewritten to what shipped, then ticked; Decisions: M-6 (E-1), the cause rule, the Charge Limit's source and caveat, "Placements fail open" with G7-17 measured (Appendix C) and F-1's renewal; Stage 1.4 and Stage 1.3's accessibility lines from §6.4; Stage 1.9's after-publishing item ticked from AP71 (still open at `63a01f2`); the Releases rows, v0.7.0's and v0.7.1's counts when due (Appendix C); "Next: 0.9.0" | L-1, E-1, D3 |
| `docs/plans/1.0/ROADMAP.md`, `INVENTORY.md` | §2.4's corrections (bit 12, the parse method, the format version, the line numbers, the `.public` count, the sittings' minutes); FEA-35, NEW-01, QUA-06, QUA-15, A11Y-01 to A11Y-04, DIS-09 marked with what shipped | L-1 |
| `docs/VERIFICATION.md` | 0.7.1's after-publishing check (AP71), which it doesn't hold yet (I-12); 0.8's rows filled at D3 | L-1, D3 |
| `README.md` | A line for Report a Problem and the accessibility support; "Status: early development" stays until 0.9.0 (DIS-10) | L-1 |
| `.github/release-notes.md` | §13 | L-1, D1 |

---

## 13. Release steps

As P7 §13, with 0.8's lines:
1. **Version:** the tag `v0.8.0`; `BUILD_NUMBER` from the clock 0.7.1 brought
   (`scripts/build-number.sh`, I-9), above RC-U's.
2. **Notes:** `.github/release-notes.md` opens with `## What's new in 0.8` (`release.yml`'s check).
   Only what landed:
   - why the battery isn't charging (the causes that shipped), and the general reasons when the
     battery reports none;
   - the Charge Limit's number on Power and in the widget's Charge limit field, if G8-1 passed
     ("BatteryPulse can't read it on battery");
   - Health's summary; explanations next to the numbers;
   - the new Welcome (if A-5 shipped); Help → Report a Problem… ("nothing is sent");
   - VoiceOver and the keyboard;
   - "Updates check that the new version runs on your macOS before installing it";
   - "For scripts: …" (§7.3's lines, the text report's included);
   - QUA-15's line;
   - F-1's privacy line, if F-1 shipped (§7.3);
   - "Updating from 0.7.x: Install and Relaunch."
3. **ROADMAP:** a Releases row, its counts left for step 8; §12's changes.
4. **Copy the tooling and `from-0.8.md` to `docs/plans/0.9.0/`, then remove `docs/plans/0.8.0/`**
   in the last commits (D3); the commit before the removal is `<keep>`.
5. **The PR** `claude/080-integration` → `main`: ready with the numbers, Appendix C and the session
   results; both jobs green with 0 warnings; merged after the maintainer's OK.
6. **Tag and release:** the maintainer approves the `release` environment run; `release.yml`
   attaches the DMG, `.sig`, dSYMs and `BatteryPulse-count.txt` as 0.7 made it.
7. **After publishing** (§6.6), with `gh release edit v0.8.0 --prerelease`, on his yes, as the
   rollback.
8. **A week after publishing** (NEW-23): `swift scripts/release-stats.swift`; v0.8.0's row in
   ROADMAP's Releases table, Count included, in a commit of its own.

---

## 14. The maintainer's questions

M-10 and M-11 (decided by delegation, 2026-10-22) and RD §3.3 settle most of 0.8. These are what
they leave open. Each has a recommendation and a default that applies without an answer; the looks
they lead to are still his to sign off in the look review (§6.2). Technical choices are not asked
(RD §1.2 item 8): the parse method, the reader's triggers, the report's file format, the
sentinel's files, the guards and the order.

**At the intake (A-0, 2026-11-06) none of Q8-1 to Q8-6 is answered,** so each default below holds
until he answers. The look review (§6.2) asks the look questions, Q8-1 and Q8-4 as its questions 2
and 5; Q8-3 is asked before the look shoot (§6.1), since it needs an adapter at hand; Q8-6 at
Session R8's day end (§6.5); and Q8-2 and Q8-5 keep their defaults (no) unless he raises them.
Nothing here needs his answer now, and the intake adds no question: F-1 and T-1's item 7 are his
own additions, and A-2's widget half and the re-planned rounds are technical (RD §1.2 item 8).

- **Q8-1 (no proven cause).** When the Mac is on the adapter, not charging and not full, and the
  battery reports no cause BatteryPulse can prove, should an info button beside "Not charging"
  list Apple's possible reasons (battery health features, a warm battery, an adapter too weak to
  charge), naming none?
  - **Recommended: yes.** It answers "why isn't it charging" without guessing (M-10), and the text
    is Apple's (https://support.apple.com/guide/mac-help/mh29198/mac). **Default: yes** (look-review
    question 2).
- **Q8-2 (the limit last set, on battery).** Should Power show System Settings' prior limit on
  battery, as "last set to 80 %"?
  - **Recommended: no.** It read 80 with the limit at 100 % (AC62:70), so on battery it can't tell
    a limit from none, and the limit doesn't act on battery anyway. **Default: no.**
- **Q8-3 (a weak-adapter capture).** Do you have a low-wattage USB-C adapter (a phone's, for
  example) to plug in for about 2 minutes during the look shoot (§6.1 step 4)?
  - **Recommended: yes, if one is at hand.** It is the only way the weak-adapter cause can be
    proven (G8-3). **Default: skipped;** the cause isn't shown.
- **Q8-4 (Clear's badge).** In the Clear style, the health badge says "Service Recommended" when
  only the capacity is under 80 %, even if macOS reports Normal. Should it say "Maximum capacity
  below 80 %" instead?
  - **Recommended: yes.** M-10 asks for facts only, and "Service Recommended" is macOS's word for
    its own judgement. **Default: yes** (look-review question 5).
- **Q8-5 (the capture format and heat).** Should 0.8 add the system's thermal state to the
  capture format, so that a capture could prove a heat cause?
  - **Recommended: no.** The format only adds within 1.x (C14 item 3), so the key would be
    forever, for a cause whose proof is a charger key, not the thermal state: Apple ties the
    charging stop to battery temperature. **Default: no;** heat waits for a capture (G8-4).
- **Q8-6 (an optional VoiceOver listen).** Five minutes at the day's end of Session R8, with
  VoiceOver reading Overview, Power and Health in Russian: "y = the names make sense".
  - **Recommended: yes, if you have the five minutes.** The tree read checks every name; only an
    ear checks how they sound. **Default: skipped;** NEW-20 (0.9.0) looks again.
- **M-9, the backup key** (decided yes, 2026-10-22; 0.7's K-1 moved here, I-11): not a question.
  Generating the key is his, with RD M-9's steps (P7 §14's M-9), whenever he chooses; K-1 runs in
  C8 once its public half is posted. If the key never exists, ROADMAP records the accepted risk
  (C15).

**Nothing here reopens M-3:** 0.8 reads the limit from a file and never sets one, and PowerUI stays
out.

---

## Appendix A: traceability of every 0.8 item

**Sources:** RD (`docs/plans/1.0/ROADMAP.md`) §3.3, §5.1, §5.2 and §6; INV
(`docs/plans/1.0/INVENTORY.md`); P7 (`docs/plans/0.7.0/PLAN.md`); all at `0ecca33`. The intake's
rows (2026-11-06) also cite P71, AC71 and AP71.

| Item | Source | 0.8 package or status |
|---|---|---|
| NEW-01 Why it isn't charging | RD §3.3, RD:1360 | A-1 (never cut) |
| … the Charge Limit's cause | W-14 (0.7), QUA-05 | Shipped in 0.7; A-1 generalizes it (I-1) |
| … the optimized hold | RD §3.3; QUA-06 | A-1 only with G8-2's capture; else after 1.0 |
| … heat | RD §3.3 | A-1 only with G8-4's capture; else not in 0.8 (no capture format key, Q8-5) |
| … a weak adapter | RD §3.3 | A-1 only with G8-3's capture showing a key; a heuristic never |
| … bit 12 | RD:852-853 [unverified, CLR:96] | Not decoded: the reading was `ChargerInhibitReason`'s (§2.4) |
| … the general reasons | M-10; Apple's guide mh29198 | A-1 item 3 (Q8-1) |
| FEA-35's number (INV FEA-35) | RD §3.3, RD:1257 | A-2 (first to cut; G8-1) |
| … candidate 1, powerd's plist | RD:869-880 | A-2: the one source, on AC |
| … candidate 2, the prior limit | RD:881-886 | Not shown (Q8-2); read by the session as evidence |
| … candidate 3, `CHLT` | RD:887-890 | `bpulse --smc` reads it as evidence (A-2 item 4); not read by the app in 0.8 |
| … candidate 4, `pmset -g battlimit` | RD:891-895 | Not built; the fallback only by G8-1 (+1 run) |
| … candidate 5, PowerUI | RD:896-897; M-3 | Never (M-3) |
| … the widget's number | RD:902-903; FEA-10 | A-2 item 8, through the feed 0.7.1 shipped (I-6) |
| … a ring or battery marker | P7:1439-1440, P7:1636-1640 ("perhaps the marker") | Not in 0.8: RD §3.3 lists none, and the number is unknown on battery |
| NEW-02 Health summary | RD §3.3 | A-3 (never cut) |
| NEW-03 Explanations and their guard | RD §3.3; C12 | A-4 (never cut) |
| NEW-04 Welcome | RD §3.3 | A-5 (cut third) |
| NEW-05 Report a Problem | RD §3.3; M-11 | A-6 (never cut) |
| DIS-09 (its capture half) | RD:1315; INV DIS-09 | A-6; `bpulse` in the app is 0.9.0 (M-7) |
| NEW-06 Help at the tag | RD §3.3; C17 | A-7 (cut second) |
| App-wide °F | RD:939; Q-W12 | Not in 0.8 (°C kept, decided by delegation) |
| A11Y-01 chart descriptors | RD:1344 | X-1 (never cut) |
| NEW-07 VoiceOver and keyboard | RD §3.3 | X-2 (never cut) |
| A11Y-02 Stage 1.4 pass | RD:1345 | Session R8 step 6 |
| A11Y-03 contrast audit | RD:1346; AC62 (not gathered in 0.6.2) | Session R8 step 5 (G8-7) |
| A11Y-04 menu bar icons | RD:1347 | Session R8 step 7 |
| NEW-14 sentinel | RD §3.3 | P-1 (cut last) |
| NEW-16 update safety | RD §3.3; C8 | P-2 (never cut) |
| SEC-07 swap-renaming check | RD:1298; INV SEC-07 | P-2 (never cut) |
| NEW-08 frozen surfaces, goldens | RD §3.3 | E-1 (never cut) |
| M-6 into ROADMAP's Decisions | RD:1553-1560 | E-1 item 3 |
| NEW-09 storage tests | RD §3.3; C9 | E-2 (never cut) |
| NEW-10 perturbation, degradation | RD §3.3; C9 | E-2 (never cut) |
| NEW-12 log-privacy guard | RD §3.3; C12 | E-3 (cut fourth) |
| QUA-15 legacy migration | RD:1272; INV QUA-15 | E-3 (cut fourth) |
| QUA-06 optimized hold capture | RD:1263 | T-1's `hold-watch` offered again (I-8); G8-2 |
| QUA-05 Charge Limit capture | RD:1262 | Done (0.6.2, 0.7's fixture); A-1's and A-2's base |
| FEA-20 the widget's cause field | RD:1242, RD:1150 | Not in 0.8 (1.1): "keeps 0.8 off the widget" |
| FEA-27 setting a limit | RD §4.2; M-3 | Not in 1.x |
| NEW-13 backup key | RD:1372; P7 K-1 | K-1: it moved here (I-11), and runs once the key exists (M-9) |
| NEW-18 verification matrix | RD:1377 | 0.8's rows at D3; no V-1, since the file shipped in 0.7.0 (I-12); closed in 0.9.0 |
| NEW-22 the quick check after each macOS 27.x update | RD:1381 | Ongoing; T-1 keeps 0.7's step |
| NEW-23 download counts | RD:1382 | §13 step 8 |
| NEW-24 the version count's announcement | RD:1383 | A-5 keeps it in Welcome; L-1 keeps What's New's row |
| NEW-11 `formatVersion` | RD:1370 | 0.7; A-2's key is an addition, no bump (§2.4) |
| 0.7's `charge-limit` step | P7:2238, P7:2435 | T-1 rebuilds it for G8-1 (§6.1 step 2) |
| 0.7's What's New row | P7:1772-1776 | L-1 item 3 |
| W-13 moved whole (only on a broken promise of P7 §11) | P7:2611 | Not needed: W-13 shipped in 0.7.0 (I-2) |
| W-3c's History-over-Raw-Data fix | P7:518-523 | Shipped in 0.7.0, not seen on the M5: Session R8's keyboard walk checks it, and X-2 fixes it only if the walk reproduces it (I-15) |
| G7-12's widget tree read (C10's widget families), left open by 0.7.0 and 0.7.1 | P7:2367-2386, P7:2599; AC71 | Session R8 step 3, every kind (I-14, G8-6) |
| SIZ-07 widget-only string table | RD:1306; P7:1988, P7:2621 (0.7's cut 3) | Shipped in 0.7.1 (the widget's own string table, `scripts/widget-strings.swift`): L-1 item 5 has nothing left |
| SEC-06 no prompt for own data after an update | RD:1297 ("repeated in every after-publishing check") | §6.6 step 4 |
| DIS-06 widgets kept across an in-app update | RD:1312 | §6.6 step 3 (evidence for C7) |
| 0.7's pre-swap extension end | P7:953-956 | In place since 0.6.2; P-2 keeps it and its test (I-10) |
| 0.7's growing build number | P7:2022-2028 | Shipped in 0.7.1 (I-9) |
| 0.7's `WidgetChartSummary` | P7:1954 | Shipped in 0.7.1 as the widgets' one chart label; X-1a's `ChartSummary` stays, for the app's charts (I-5) |
| G7-11's measurement | P7:2598 | Session R8's day (I-13: 0.7.0 and 0.7.1 left it open) |
| 0.6.2's open checks (the dark bar, WP-18's Xcode items) | P7:524-541 | Session R8 steps 7 and 11b (I-14: still open) |
| The other M5 checks 0.7.0 and 0.7.1 shipped without | ROADMAP Stages 1.8 and 1.9; `docs/VERIFICATION.md`; AC71's F rows | Session R8 step 11c (I-13, I-14) |
| G7-17, the placements WidgetKit answers this app with | P7 G7-17; AC71's D3 rows | Measured at the intake (Appendix C); F-1 builds on it; the fail-open for an empty answer stays |
| A removed widget's section leaves the feed within about an hour | the maintainer (2026-11-06); G7-17 | F-1 (P2, cut fourth) |
| The session's gallery widgets removed and checked against the app's counts | the maintainer (2026-11-06); AP71's feed | T-1 item 7 |
| W-9 widget extras | W:536, W:650 | Not in 0.8 (after 1.0) |
| The feed, History and iPhone & iPad widgets | RD §3.2, §4.1 | Shipped in 0.7.1 (Stage 1.9), not 0.8's |
| 0.9.0's contents: `bpulse` in the app (M-7), `SECURITY.md` (NEW-15), the 1.0 docs (NEW-17), README's status line (DIS-10), closing NEW-18, NEW-20, SEC-02, M-8 | RD §3.5 | Not in 0.8 |
| 0.9.x: the soak, energy budgets, the upgrade matrix (NEW-19), C13 | RD §3.6 | Not in 0.8 |
| NEW-21 macOS 28 compatibility | RD §3.8 | Not in 0.8 (1.1) |
| Grades of our own; telemetry beyond the count; MetricKit (REJ-36); an admin-prompt installer | RD §4.3 | Rejected, not in 0.8 |
| Developer ID | RD §3.4; M-1 | Not planned |

---

## Appendix B: facts verified for this plan, and what stays unverified

**Verified in the repository** (at `0ecca33` unless named):
- `NotChargingReason` is parsed from the charger entry merged over the top-level `ChargerData`,
  the child winning (`MacPowerParser.swift:134-135`, `:211`), and printed only as hex, only on
  external power (`BatteryReport.swift:76-80`).
- The SMC plug-in rule turns `notCharging` into `charging` at 100 mA unless full or the optimized
  flag is set (`MacPowerParser.swift:180-188`, `:254`); the optimized flag is IOPS "Optimized
  Battery Charging Engaged" (`:177`).
- `ChargeState` has five cases and is `Codable` (`BatterySnapshot.swift:162-170`); the thermal
  state is a snapshot field (`:85`), applied after parsing, and the raw capture has four top-level
  keys (`MacPowerParser.swift:40-45`), none for it.
- `DemoBattery` hard-codes `NotChargingReason` to 0 on AC and 128 on battery
  (`DemoBattery.swift:112`).
- `Phrases.state` shows "Charging on hold" only for the optimized flag
  (`App/Localized.swift:28-33`).
- Health already shows condition, maximum capacity and cycles "x of y"
  (`Main/HealthView.swift:91-118`); `healthTier` turns a capacity under 80 % into the low tier
  (`BatteryPresentation.swift:63-71`), and Clear's badge then says "Service Recommended"
  (`App/Localized.swift:141-154`, `Main/HealthView.swift:84-87`).
- `ValueRow` takes only a label and a value (`Main/Components/ValueRow.swift:6-24`).
- `RingGauge`, `PowerFlowView` and `CapacityBars` have no accessibility modifier (0 occurrences
  each); no `accessibilityChartDescriptor` in `Sources`; the chart parts are hidden
  (`ChargeChart.swift:31`, `PowerChart.swift:29`, `HistoryChartParts.swift:51`).
- Welcome embeds `GeneralSettings()` (`Welcome/WelcomeView.swift:32-34`); W-13 relies on it
  (P7:1729-1731).
- Help opens `blob/main` (`App/AppSettings.swift:171`, `BatteryCore/Updates.swift:163-166`).
- `checkStagedBundle` checks the identifier, the version and newer-than-current only
  (`UpdateInstall.swift:161-169`); `LSMinimumSystemVersion` is written (`build-app.sh:128`, `:164`)
  and read nowhere in `Sources`; no `volumeSupportsSwapRenaming` in `Sources`.
- The legacy migration: `HistoryStore.swift:15`, `:24-26`, `:41-42`, `:98-100`, `:121`, `:147`,
  `:176-192`, `:246`; its test, `HistoryStoreTests.swift:41`, `:160-184`.
- `privacy: .public`: 37 occurrences on 25 lines in 11 files.
- `bpulse --smc` lists `B`, `TB`, `SB`, `CH`, `AC` and reads values for `B0`, `BC`, `BN`, `TB`,
  `SBA` only (`Sources/bpulse/main.swift:304-306`); the app's SMC keys hold no `CH*` key
  (`SMC.swift:288-295`).
- A process may start only in the installer (`SecurityGuardTests.swift:77-81`).
- The catalog has 719 keys; `LocalizationCatalogTests`' scan covers `help` and
  `accessibilityLabel` but not `accessibilityValue` or `accessibilityHint` (`:19-21`).
- The widget reads with `MacBatteryProvider(readsSMC: false)` in its sandbox
  (`Sources/BatteryPulseWidget/WidgetReadCache.swift:40-45` on `origin/claude/070-w3a`), so a
  reader inside `MacBatteryProvider` would run there too.
- S-1's rule: "keys are only ever added. A rename, a removal or a change of meaning bumps the
  shape's version" (`Sources/BatteryCore/MachineJSON.swift:7-8` on `origin/claude/070-s1`).
- W-13's `showsAnnouncement(previous:)` (`Sources/BatteryCore/VersionCounter.swift:94` on
  `origin/claude/070-w13`).
- The session script's `battlimit` parse looks for a number and "%" (
  `docs/plans/0.7.0/m5-session.sh:3768`, `:6623`, `:6911`); its Battery pane URL is
  `x-apple.systempreferences:com.apple.Battery-Settings.extension` (`:3404`), which P8 opened
  (`sessions/B.md:91`, "battery=yes (sidebar unread)").
- Session A's Charge Limit reads, Session B's 100 % and its lessons: §2.2's citations.
- No `SystemChargeLimit`, `WidgetChartSummary` or charge-limit fixture on any `origin/claude/070-*`
  branch on 2026-10-30 (`git grep`).

**Verified by a scratch test** (Linux, Swift 6.4.1; not in the repository): an archive whose class
is named `ChargeCtrlPolicy` (an array of two, with `soclimit` 80, `reason` `manualChargeLimit`,
`drain`, and an `NSUUID` `token`), stored as `Data` under `policies` in an outer property list,
round-tripped through XML and binary, decoded with `NSKeyedUnarchiver(forReadingFrom:)`,
`setClass(_:forClassName:)` to a stand-in `NSSecureCoding` class and `decodeObject(of:forKey:)`:
both records read 80, `manualChargeLimit`, true, with no error. Two limits: Linux's
`NSKeyedArchiver.setClassName(_:for:)` was ignored (the archive named the Swift class), so the
test renamed the class in the XML; and powerd's real archive layout is [unverified] until A-2's
sample. The research's scratch test (the same toolchain): `PropertyListSerialization` decodes a
UID to an opaque `_NSKeyedArchiverUID` that casts to nothing, so a generic walk loses the links.

**Verified at Apple and GitHub** (fetched 2026-10-30):
- `NSKeyedUnarchiver`'s "Managing Class Names": `setClass(_:forClassName:)`, instance and class
  forms (https://developer.apple.com/documentation/foundation/nskeyedunarchiver);
  `init(forReadingFrom:)` "enables `requiresSecureCoding` by default"
  (https://developer.apple.com/documentation/foundation/nskeyedunarchiver/init(forreadingfrom:)).
- The Charge Limit: Apple silicon, macOS Tahoe 26.4 or later; System Settings → Battery → (i)
  next to Charging; 80-100 %; the battery menu's "Charged to [%] Limit"; charging resumes after a
  drop of more than 5 % (https://support.apple.com/102338).
- "If your Mac battery won't charge": battery health features; "charging may stop at 80%" above
  the recommended temperatures; an adapter that runs the Mac but can't charge it; a load above the
  input (https://support.apple.com/guide/mac-help/mh29198/mac).
- `ProcessInfo.ThermalState`: four cases, never tied to charging
  (https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum).
- `help(_:)` sets the accessibility hint and the help tag; HIG "Offering help" (60 to 75
  characters), "Popovers" (one at a time, no cascade), "VoiceOver", "Keyboards", "Onboarding",
  "The menu bar" (Help items; don't rely on a menu bar extra's presence).
- `accessibilityChartDescriptor(_:)` (macOS 12+); `focusable(_:interactions:)` (macOS 14+);
  `focusSection()` (macOS 13+).
- `ImageRenderer` leaves out complex controls and most AppKit views, drawing a placeholder
  (https://developer.apple.com/documentation/swiftui/imagerenderer): why §3 shoots screens on the
  M5.
- `fileExporter(isPresented:item:contentTypes:defaultFilename:onCompletion:onCancellation:)`
  (macOS 14+, `Transferable`); the `FileDocument` overload is "Deprecated at 27.2".
- Crash reports: `.ips` JSON with `bug_type`; `crashReporterKey` "an anonymized per-device
  identifier", `incident` unique per report; user-identifiable path components replaced
  (https://developer.apple.com/documentation/xcode/interpreting-the-json-format-of-a-crash-report).
- Debug log messages are not persisted (OSLog's "Generating log messages from your code");
  `OSLogStore.local()` needs an entitlement the app doesn't have.
- System Settings → Menu Bar: the Battery item and "Allow in the Menu Bar"
  (https://support.apple.com/guide/mac-help/mchlad96d366/mac).
- GitHub accepts `.txt` (and `.xml`, `.zip`, `.json`, `.log`) attachments up to 25 MB for files
  other than images and videos
  (https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/attaching-files).

**Unverified or uncertain, and who settles it:**
- Whether powerd's `policies` is `Data` or inline, and its archive's exact layout: A-2's sample
  (§6.1 step 2).
- Whether the app's own process reads `/Library/Preferences/com.apple.powerd.charging.plist` and
  `~/Library/Logs/DiagnosticReports` without a prompt [inference: neither is in Apple's list of
  consent-protected locations]: G8-5.
- Whether the policy is present on AC while charging toward the limit (Session A read it at the
  hold and at 72 % right after a plug-in, before charging began, AC62:70): §6.1 step 2's second
  limit.
- What `CHLT` and `CHNC` hold on the M5 (RD's description rests on one dump from another Mac):
  A-2 item 4, read in §6.1 step 2.
- `pmset -g battlimit`'s verbatim text (only paraphrased in `sessions/A.md`): A-2's sample.
- Whether the optimized hold publishes the IOPS flag for the Mac's battery on macOS 27, and
  whether it sets bit 24 (QUA-06): G8-2.
- Whether heat or a weak adapter sets a charger key: G8-3, G8-4.
- Bit 7's meaning on AC (observed: on battery and right after a plug-in) and bit 12 (seen only in
  `ChargerInhibitReason`): not decoded.
- Whether `RingGauge` inherits `Gauge`'s accessibility: Session R8 step 3.
- Whether AX exposes a chart descriptor to a script: Session R8 step 3.
- P-2's relaunch fallback mechanics: P-2a and its CI check.
- `sysctlbyname("hw.model")`'s output format on the M5: A-6a, and the look shoot's saved file.
- Today's after-publishing lessons (§2.2): reported, not yet in the repository.
- Every effort and minute figure: [estimate].

**Conflicts with RD, resolved here:** §2.4's table. L-1 corrects RD and INV at D3.

---

## Appendix C: facts 0.8 records (filled during the release)

| Fact | Where it comes from | What it decides |
|---|---|---|
| §2.1's last column: what 0.7.0 and 0.7.1 shipped of I-1 to I-16 | A-0: filled (A-0's block below) | §4's conditional work |
| v0.7.1's CI sizes and the `.public` baseline | A-0: filled (below) | §9; E-3's allow list |
| G7-17's placements; 0.7.1's after-publishing results; v0.7.0's and v0.7.1's week-later counts | A-0: filled, the counts when due (below) | F-1, T-1 item 7, A-3; ROADMAP |
| The carry-over: the six packages' merges, the fixes where they met, CI and sizes at the intake's head, what later packages inherit | A-0: filled (the carry-over block below) | §9; §4's carried sections; §5 |
| Each round's merges, the fixes where its packages met, CI and sizes at its head, and what its packages and their reviews hand to later packages and the sittings | each round's merge: C1 filled (round C1's block below) | §9; §5; the packages and sittings named |
| The Charge Limit's reads per limit, on AC, on battery and after a plug-in; the app's logged number; `CHLT` and `CHNC`; the samples | §6.1 step 2 | G8-1 |
| The weak-adapter captures | §6.1 step 4 | G8-3 |
| The optimized hold's capture | 0.8's `hold-watch` (0.7.0 and 0.7.1 ran none, I-8) | G8-2 |
| The look review's and the Russian review's answers | §6.2, §6.3 | G8-11; L-1 |
| The tree, keyboard, contrast, Stage 1.4 and menu bar results, per page and language; the checks 0.7.0 and 0.7.1 shipped without | §6.4 steps 3-8 and 11c | G8-6 to G8-8; `docs/VERIFICATION.md` |
| The report's file checks; the crash folder's names | §6.1 step 3, §6.4 step 10 | G8-5, G8-13 |
| The sentinel's pause and Turn On Again | §6.4 step 11 | P-1 |
| F12; crashes and faults; reads per trigger; G7-11 (I-13) | §6.4 step 12, §6.5 | G8-9, G8-10; §10 |
| Each session's gallery widgets: the counts at `prepare` and after its RESTORE items, and what stayed | T-1 item 7 | the summary's ALERT; F-1 seen on the M5 |
| The after-publishing results | §6.6 | the release's state |
| The download counts a week later | §13 step 8 | ROADMAP's Releases table |

**A-0** (the intake, 2026-11-06, at `claude/080-integration`'s `63a01f2`, whose code is v0.7.1's,
`48b5da0`):

| Fact | Shown by | Decides |
|---|---|---|
| **What 0.7.0 and 0.7.1 shipped of this plan's inputs:** §2.1's last column, row by row. In short: W-14, W-13, S-1, W-1, W-3c and R-1's `docs/VERIFICATION.md` shipped in 0.7.0, and the pre-swap end's test was there since 0.6.2; the feed, `WidgetChartSummary` and the build-number clock shipped in 0.7.1; the session tools came forward with 0.7.1's D3; K-1 moved here; the hold watch, the logged day (G7-11) and Session R's open checks (the dark bar, WP-18's Xcode items, the widgets' trees) are still open; CI's macOS job has Xcode 27.2's release (27B52) | AC70, AC71, P71 §5, AP71; the code at v0.7.1 | §4's conditional work: no W-14 or W-13 carry-over, no V-1, no I-9 commit; K-1 in C8; A-2's widget half (I-6); X-1a's own `ChartSummary` stays (I-5); T-1 re-points the tools (I-7); Session R8 carries the open checks (§6.4 step 11c) |
| **The "before": v0.7.1's sizes,** RC-U's (`ci.yml` run 587, id 42181969486, at `8900331`; v0.7.1 is built from code that is RC-U's, AC71's D3 rows): DMG 1,591,826 B, `app_kb` 5,156, app binary 3,249,712 B, app `__text` 2,174,176 B, widget binary 1,615,152 B, widget `__text` 1,026,448 B, `widget_appintents_bytes` 27,404 B, `strings_bytes` 140,189 B (the app's tables and the widget's own, SIZ-07), icon 215,181 B, one export each, every hygiene count 0. The ceilings since `99e490e`, each RC-U's value times 1.05 rounded up: DMG 1,672,000 B, `app_kb` 5,414, app binary 3,413,000 B, app `__text` 2,283,000 B, widget binary 1,696,000 B, widget `__text` 1,078,000 B, `widget_appintents_bytes` 28,800 B, `strings_bytes` 147,200 B, icon 226,000 B. The published v0.7.1 DMG is 1,591,778 B, its build number 26740846 (AP71's About) | AC71's D1 block (items 5 and 6); `scripts/size-budget.json`; GitHub's API (2026-11-06) | §9's start; each raise a commit of its own (G8-12) |
| **The `.public` baseline at v0.7.1:** 85 `privacy: .public` values on 51 lines in 15 files of `Sources` (v0.7.0: 52 on 33 lines in 13 files; v0.6.2: 37 on 25 lines in 11, §2.4). 0.7.1 added 33: 21 in the feed's writer (`WidgetFeedWriter.swift`), 6 in the widget's feed reader (`WidgetFeedReader.swift`) and 6 more in `WidgetRefresher.swift` (the placement counts among them). E-3's guard counts values per file: the allow list `claude/080-e3-r` carries (`LogPrivacyGuardTests.allowList`, at `bca07f5`) holds 57 entries in the same 15 files, whose counts sum to the same 85 | `git grep -o 'privacy: \.public'` at `48b5da0`, `5e2e5c7` and `0ecca33`; the allow list on `claude/080-e3-r` | E-3's allow list, carried in A-0; L-1's correction of RD's count (§2.4) |
| **G7-17 measured: WidgetKit's `currentConfigurations()` answers this ad-hoc-signed app with its real placements.** After 0.7.1's update on the M5 (AP71, 2026-11-06 19:28:33, the Mac's time, +0300), the app logged "Placed widgets, for the widget feed: 2 in all, 1 Battery, 0 Accessories, 0 History, 1 iPhone & iPad", and the refresher logged the same counts twice (the maintainer's `log show`). The Battery one is his medium widget (AP71's D3-widgets); the iPhone & iPad one, which no shot showed, is most likely the small one Session F added from the gallery and didn't remove at its end (F-keep-widgets n; F's report records no removal) [inference], and it is why AP71's feed held 4 devices | the maintainer's `log show`; AP71 (D3-widgets, the feed's check); AC71's F rows | F-1 (an answer asked again is a real one); T-1 item 7; the fail-open for an empty or failed answer stays, and whether an empty answer means none placed stays open (AC71's D3 rows); ROADMAP's "Placements fail open … (G7-17, not measured yet)", for L-1 (§12) |
| **0.7.1's after-publishing check** (AP71, 2026-11-06, 19:25 to 19:33 +0300 on the M5, hands-free, from his 0.7.0 (9)): **every answer the expected one** (y; 1 for the widgets and Login Items). Install and Relaunch by the session to 0.7.1 (26740846): the extension ended before the swap (1 found, 1 by SIGTERM, 65 ms), no CHSErrorDomain 1103 line, `codesign` `flags=0x10002(adhoc,runtime)`, no quarantine; What's New once, with no version-count row (from 0.7.0); his medium Battery widget the same; History, the settings, the menu bar, Login Items and Notifications as before; the feed 0600 in a 0700 folder, version 1, written 14 s before, the widget's exception its one read-only path; the popover and the widget at 56 %. **0.7.1's S-1 confirmed on the M5:** Settings → General scrolls to its last row and footer above the Dock, where under 0.7.0 it ran under the Dock. **Maximum capacity:** 100 % in System Settings' Battery Health (Condition Normal) and in BatteryPulse (100.0 %), 100 % from `system_profiler`, with `NominalChargeCapacity` 5935 of the 5760 mAh design (103.0 %), `AppleRawMaxCapacity` 5791 (100.5 %), 54 cycles. Not run: the version count's wait (v0.7.0's asset already counted, AC71) | AP71 | ROADMAP Stage 1.9's after-publishing item and `docs/VERIFICATION.md` (§12); A-3's maximum capacity as System Settings shows it, capped at 100 % (a nominal capacity above the design shows 100 %); W-17 item 18's third reading (AC71's D3 rows) |
| **v0.7.0's and v0.7.1's week-later download counts: pending.** v0.7.0 was published at 16:28 UTC on 2026-10-31, so its counts are due after 16:28 UTC on 2026-11-07; v0.7.1 at 12:03 UTC on 2026-11-06, due after 12:03 UTC on 2026-11-13. At 17:51 UTC on 2026-11-06: v0.7.0's DMG 3, signature 3, `BatteryPulse-count.txt` 3, dSYMs 2; v0.7.1's DMG 2, signature 2, count 0, dSYMs 1 (its count comes a day after a Mac first runs it) | GitHub's API (`gh api …/releases/tags/<tag>`); `scripts/release-stats.swift` when due | ROADMAP's Releases table, each in a commit of its own (§13 step 8; NEW-23) |

**A-0's carry-over** (2026-11-06: the six preparation packages merged onto `63a01f2`, and the
intake's review; the head `2ca4c9b` is the code the rounds start from):

| Fact | Shown by | Decides |
|---|---|---|
| **The merges,** `--no-ff` in this order: E-3 `8836130` (`claude/080-e3-r` at `bca07f5`), E-2 `be58f92` (`4a5a366`), X-1a `8539670` (`ccadd9f`), X-2a `8edc000` (`891e1bd`), A-6a `70529a8` (`3d6d700`), P-2a `599bad8` (`032a3ae`), then A-0's plan `7211a98` (`f822235`). Every carried commit is the same patch with the same message as on its branch from `cf847d0` (`git range-diff`: all `=`), and each branch adds only its adaptation commits for 0.7.0 and 0.7.1; no merge needed a hand resolution (`git show --remerge-diff` empty for all seven), and every file a package changed is in the head as that package left it, but `HistoryStore.swift` (E-3 and E-2) and `LogPrivacyGuardTests.swift` (the fix below) | `git` | §4's carried sections |
| **Where the packages met,** two fixes: `3dc4d19` lets P-2a's launch-marker errno (`failure`, a number) log as public, and rewords the installer's `reason` entry, which `needsNewerMacOS`'s minimum macOS version now feeds: the allow list holds **58 entries and 86 values in 15 files**, every `.public` value of the head; `2ca4c9b` removes `HistoryStore`'s `readLines` and `writeLines`, whose callers E-3 (the migration) and E-2 (the days file's own read and write) each took one of; Swift doesn't warn about an unused private function | the two commits | E-3's count (§4); later packages add their `.public` entries |
| **CI at the head,** `ci.yml` run 613 (id 42274865821) at `2ca4c9b`, green on both jobs with no compiler warning: Linux 1,168 tests (BatteryCoreTests 1,037 in 97 suites, from 929 in 89 at v0.7.1: E-3 +14, E-2 +27, X-1a +12, X-2a +8, A-6a +36, P-2a +11), the DocC link check and Session R's dry run; macOS 1,226 tests (BatteryCoreTests 1,038), packaging, the size report, the install the way 0.6.1 does, and P-2a's "Check the relaunch fallback": an update that exits at launch opened after 2 s and the previous version was back and open after 45 s; the CI-built app stayed, and deleted the previous version and the downloads | the run's two job logs | A-0's acceptance (with the review's head) |
| **Sizes at the head** (run 613): DMG 1,620,770 B (+1.8 % over the published v0.7.1), `app_kb` 5,236, app binary 3,283,984 B, app `__text` 2,198,896 B, widget binary 1,665,952 B, widget `__text` 1,047,248 B, `widget_appintents_bytes` 27,404 B, `strings_bytes` 140,189 B, icon 215,181 B, every hygiene count 0, no ceiling raised. Against v0.7.1's RC-U: the widget binary +50,800 B, the app binary +34,272 B; each branch's own CI puts the widget's `__text` growth on X-1a (+13,404 B), A-6a (+6,600 B), E-2 (+2,932 B) and P-2a (+1,004 B), less E-3 (−2,804 B) and X-2a (−476 B) | the size reports of run 613 and of each branch's last run (42259762075, 42263127912, 42263818055, 42259821459, 42262324731, 42263110182) | §9's start: about 30 KB left under both widget ceilings |
| **The review's checks** (on `2ca4c9b`, beside the CI): the privacy guard fails on an unlisted public value, on a device's name (as unlisted and as a denied word), on one occurrence too many and on one too few, each naming the entry to add, raise or remove; the feed's pins fail on a decoder that accepts a higher version, a 0644 file, an unknown state no longer read as unknown (both of its layers), a removal that takes the folder and unsorted keys; `ProblemReportTests` fails on a new settings key and on a `WidgetFeed` reference in the report; every signpost name CL lists reaches `PerfSummary.session` through the two `Diagnostics` twins; every settings key of the app is included or left out with a reason (34 and 1); the DocC check fails on a broken link in `ChartSummary` and in `AccessibilityText`. Each mutation reverted | the review's runs | the carried adaptations stand |
| **What later packages inherit:** X-2b moves the five waiting phrases from `AccessibilityTextTests.pendingKeys` into the catalog and counts `AccessibilityText.catalogKeys` as used (X-2b item 4); A-6b widens `theReportsFilesUseNoNetwork`'s two-file list and keeps the `DiagnosticReports` guard to `Sources` (A-6's guards); P-2b gives `needsNewerMacOS` and `swapUnsupported` their own words (P-2b); `DegradationTests`' pinned source text (E-2); `ci.yml`'s order around P-2a's step (§5); the names L-1 adds to CLAUDE.md (§12). And with E-2, a `devices.json` holding fields this version doesn't know lists no device, so the feed holds none either (E-2) | the carried branches' tests and messages; the carry-over agents' notes, each checked against the head | the sections named |

**Round C1** (2026-11-06: A-1 and T-1, each reviewed on its branch, merged onto `b8f1665`; the head
`6abe04a` is the code C2 starts from):

| Fact | Shown by | Decides |
|---|---|---|
| **The merges,** `--no-ff`, A-1 first: A-1 `8fde6a5` (`claude/080-a1` at `c2cc870`), then T-1 `6abe04a` (`claude/080-t1` at `348f59b`), both cut from `b8f1665`. No conflict and no hand resolution (`git show --remerge-diff` empty for both): the two share no file (A-1: `Sources`, `Tests`, the catalog and the guide; T-1: `docs/plans/0.8.0/` and `ci.yml`), so every file is in the head as its package left it. Each review's fixes are on its branch: A-1's `c2cc870` (a comma in the glossary's new English key, the same in the catalog and `NotChargingCauseTests`), T-1's seven, `fef8bb3` to `348f59b` (T-1's row below). Outside A-1's §4 file list: `Main/PowerView.swift` (the motion key's rename; §5 gives the file to A-1) and the adapted `DemoBatteryTests` and `SystemChargeLimitTests`. T-1 replaced 0.7.1's two launchers with `start-session.sh` and added `section.sh` and `SESSION-L.md`; `ci.yml` names the folder in the Linux job's dry run and in the macOS job's `bash -n` and type-check lines, which D3 removes with it | `git`; the two reviews | §4's A-1 and T-1; C2 starts here (A-2 and A-7 wait for A-1, §5); D3's `ci.yml` lines |
| **Where they met: nothing to fix,** so C1 has no fix commit. The session script reads A-1's work only through the catalog (`catalog_ru`), `bpulse --json`'s `notChargingReason` (A-1 left `--json` as it was) and Demo Mode's scenes by their titles through AX, never by position, so A-1's new scene and the report's cause name change none of its reads, and `R9b-demo`'s words (Overview's "Charged to limit", Power's "Reached") still hold. On the merged tree, locally as in CI: the build with warnings as errors, the whole suite, lint, the DocC link check and the dry run | the merged tree's runs; `m5-session.sh`'s reads | C1's acceptance |
| **CI at the head,** `ci.yml` run 625 (id 42316091626) at `6abe04a`, green on both jobs with no compiler warning: Linux 1,181 tests (BatteryCoreTests 1,050 in 98 suites, from 1,037 in 97 at the carry-over's head: A-1's +13, `NotChargingCauseTests` the new suite), lint, the DocC link check and the dry run's 79 checks, with battlimit's parse "unverified" until A-2's sample (T-1 item 2); macOS 1,239 tests (BatteryCoreTests 1,051), `bash -n` and the type-checks of T-1's files, packaging, the App Intents check, the size report, update signing, the install the way 0.6.1 does and the relaunch fallback: an update that exits at launch opened after 2 s and the previous version was back and open after 45 s; the CI-built app stayed, and deleted the previous version and the downloads. Each branch's last run was green on both jobs with no warning: A-1 run 620 (id 42293794547, at `c2cc870`), T-1 run 624 (id 42313988405, at `348f59b`; run 623, at `0df6d43`, was cancelled by the next push) | run 625's job logs (128228921168, 128228920898); the branches' runs | C1's acceptance |
| **Sizes at the head** (run 625): DMG 1,624,002 B (+2.0 % over the published v0.7.1's 1,591,778 B), `app_kb` 5,272, app binary 3,318,608 B, app `__text` 2,216,768 B, widget binary 1,665,968 B, widget `__text` 1,048,108 B, `widget_appintents_bytes` 27,404 B, `strings_bytes` 142,362 B, icon 215,181 B, one export each, every hygiene count 0, no ceiling raised. **Against v0.7.1** (RC-U, run 587): DMG +32,176 B, `app_kb` +116, app binary +68,896 B, app `__text` +42,592 B, widget binary +50,816 B, widget `__text` +21,660 B, `strings_bytes` +2,173 B, App Intents and icon the same. C1's own part, all A-1's (T-1 changes nothing that is built), against the carry-over's head (run 613): app binary +34,624 B, app `__text` +17,872 B, `app_kb` +36, widget binary +16 B, widget `__text` +860 B, `strings_bytes` +2,173 B (the catalog from 792 keys to 800), DMG +3,232 B. **Left under the ceilings:** app binary 94,392 B, app `__text` 66,232 B, `app_kb` 142, widget binary 30,032 B, widget `__text` 29,892 B, App Intents 1,396 B, `strings_bytes` 4,838 B, DMG 47,998 B, icon 10,819 B | the size reports of runs 625, 620 (A-1's: the same rows, the DMG 1,624,046 B) and 613; `scripts/size-budget.json` | §9; G8-12: at A-1's 2,173 B for 8 keys, A-2's and A-3's few keys may fit [estimate] and A-4's 36-48 won't; the package that crosses `strings_bytes` raises it in a commit of its own |
| **A-1, what its package and review found:** W-14 shipped whole in 0.7.0 (§2.1 I-1), so A-1 extended it at no extra run. `NotChargingCause` has one case, `systemChargeLimit` (its capture `m5-macos27-charge-limit`), with W-14's precedence (the plug-in rule, then Optimized Battery Charging's flag, then bit 24); `BatterySnapshot.notChargingCause` is computed and never stored, and `isAtSystemChargeLimit`, its convenience, is still what the widget's state word, its `systemChargeLimit` field, `WidgetReloadPlanner` and Power's "Charge limit: Reached" read. **G8-2, G8-3 and G8-4 have no capture, so their defaults hold:** "Charging on hold" stays, and neither a weak adapter's nor heat's cause shows. **Q8-1's default (yes) is built:** an info button beside "Not charging" on Overview and the same text as a help tag in the popover, never a nested popover. The fixtures' `NotChargingReason`: 0x80 in `on-battery`, `on-battery-smc`, `unplugged` and `plugged-in-10s` (on AC), 0 in `charging`, 0x1000000 in `charge-limit`; `ChargerInhibitReason` 0 wherever present. Over every Mac fixture against the base's BatteryCore, the text report differs only in `charge-limit`'s reason line, now "0x1000000 (Charge Limit)", and `--json` only in the run's time. The catalog went from 792 keys to 800 (8 new phrases, and the glossary's `NotChargingReason` line replaced by one with the M5's 0x80); the `.public` values stay 86. The Russian was checked against Apple's Russian pages of mh29198 and 102338 (2026-11-06): the battery health features', Optimized Charging's, the Charge Limit's and the battery settings' terms are Apple's, and the English the reasons take from mh29198 matches it verbatim. 12 mutations, each caught, among them a case added with no capture and one with a hand-written capture ("no fixture, no cause") | A-1's commits and review; `bpulse --input` over the fixtures; the catalog at both commits | G8-2 to G8-4 (their defaults); Q8-1; E-1's goldens and D1's golden diff (the reason line); §7.3's text report row; E-3's count (86) |
| **A-1, for the sittings and the reviews:** the Battery pane's URL stays [uncertain] until Battery Settings… opens it in the look shoot (§6.1 step 3). Overview's info glyph takes the body font beside the `.title3` state, while the popover's is sized to its `.subheadline` state text: the look review's (§6.2 question 2, G8-11). Right after a plug-in, until the SMC reads 100 mA, the state reads "Not charging", so the info button shows for those seconds and then fades (the plan's rule, with no timer): the look shoot's plug-in beep (§6.1 step 2) and R8's `R9-plug` show it. The help tags inside the menu bar window can only be judged on the M5. The no-cause scene's subtitle, "Plugged in but not charging, for no reason BatteryPulse can name.", leans on an idiom, and "with no reason the battery reports" would match the footnote: for L-1's terminology pass or the Russian review (§6.3). A macOS 27.x update could move bit 24 (W-12's quick check and Raw Data show it). Items 2 and 3 landed in one commit (`ce00798`), against P7 §3's one commit per item, since they share the views, `AppLinks` and the keys; the history isn't rewritten | A-1's review | §6.1, §6.2 questions 1-2, §6.3, §6.5's `R9-plug`; G8-11; L-1 |
| **T-1, what the sittings take from it** (its review's seven fixes and open points): battlimit's parse (item 2) stays "unverified" in the dry run until battlimit's verbatim text is committed beside A-2's fixtures as `powerd-charging-<n or none>-battlimit.txt`, named by the number its policy decodes to and never by `battlimit_value`'s own reading, which would make the check circular; the dry run fails any other name, and the session's samples are named by their read's tag alone. **Session R8's day end runs Q8-6's listen before F12,** while RC-U still runs (F12 leaves the published 0.7.1 installed until `restore end`), unlike §6.5's order; and R8 sends its report again after `summary end`, with the widgets' counts that only `restore end` and `widgets-check` read (item 7), under his yes and the privacy lint. F12 and the after-publishing check record the widget extension's processes before the install and crop only once a new one comes, within 60 s (`placed compare`, R8's steps 2 and 11c, within 30 s), else `F12-widget` and `F12-new-kinds` are "not checked" (§6.0 rule 4); `edit-shot` and `tick` still crop without a redraw signal, as in 0.7.1. `send` commits each property list as XML (`plutil -convert xml1`), since `LocalizationCatalogTests` reads every `.plist` under `docs/` and `Tests/` as UTF-8. `charge-limit hold wait` looks every 30 s in the background until the hold or the hour's end; a look comes only between L2's numbered steps (a HELD read relaunches BatteryPulse and ends Demo Mode), then L1's steps 3-7 with him at the Mac, and R8's step 9 keeps the same rule. The look shoot runs neither proof P1 nor P10 (it adds no widget) and judges the seven questions no step asks (`L-a1-scenes` to `L-a6-window`) once both languages are done. A kept widget reads as `KEPT`, not `ALERT`, in the script, and R8's runbook tells it to him as an alert (item 7's "an ALERT for each"). Unverified until the M5 runs: the widget edit sheet's process (`com.apple.WorkflowUI.WidgetConfigurationExtension`) and its AX tree, `AppleKeyboardUIMode`'s values on macOS 27, where the Liquid Glass slider sits, P-1's sentinel file's name, whether battlimit shows the limit while charging toward it, and auto mode allowing the start line's `bash <(git show …)` | T-1's commits and review; the dry run | §6.1, §6.4 steps 9 and 12, §6.5; G8-1, G8-6, G8-9; T-1 item 7's ALERT |
| **What later packages inherit:** A-2 (C2) builds on `NotChargingCause`, the sentence slot on Overview and in the popover, `DemoBattery.notChargingReason` with the Charge limit scene, and the report's reason line with the cause's name; and on T-1's script: `scripts/charge-limit-sample.swift` run from the repository's root as `xcrun swift scripts/charge-limit-sample.swift <powerd's file> <the redacted copy>`, the decoded number on its last line; its fixtures `powerd-charging-<n>.plist` (`-none` at 100 %) committed as XML, as `send` leaves them (a binary one fails `russianTextOnlyInTheCatalog`), with battlimit's verbatim text beside one, named as above; and its `monitor` line (A-2 item 7) with "limit" in its words, the source's case name and the percent, `.public`, at notice or above, since `day-end` counts it through `log show` (an info or debug line stays in memory, CL), the dry run's "Charge Limit read: manualChargeLimit, 85 %, from powerd" a stand-in until A-2's words land. A-7 (C2) adds its link beside `AppLinks.batterySettings` in `AppSettings.swift`; E-1 (C3) pins the reason line with A-2's limit line; L-1 adds CLAUDE.md's `NotChargingCause` line (§12) and weighs the scene's wording above | the merged tree; `m5-session.sh`'s `limit_sample`, `limit_line_in`, `day-end` and dry run; `LocalizationCatalogTests` | §4's A-2, A-7, E-1 and L-1 |
