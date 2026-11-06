# BatteryPulse 0.8.0: the plan (answers in the app)

Written 2026-10-30, the day 0.6.2 was released (`v0.6.2`, `main` at `0ecca33`), while 0.7.0
("Widgets you configure", `docs/plans/0.7.0/PLAN.md`) is being implemented on `claude/070-*`.
Nothing in 0.8 starts before 0.7.0 is published. Every 0.7 result this plan depends on is named in
§2, with what 0.8 does if it never comes.

**Scope.** RD §3.3 is the scope: four answers a non-expert gets inside the app (is my battery OK,
why isn't it charging, what does this number mean, how do I report a problem), working with
VoiceOver and the keyboard. M-10 and M-11 set the rules (decided by delegation, 2026-10-22). It
also takes the INV rows RD places in 0.8, and what 0.7's plan hands to 0.8: FEA-35's second half
(the Charge Limit's configured percentage), NEW-01's other causes, the session script's
`charge-limit` step, and 0.7's conditional carry-overs (§2.1). W-9's widget extras stay after 1.0,
and FEA-20's widget field stays in 1.1: 0.8 keeps off the widget.

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
| RD, INV | `docs/plans/1.0/ROADMAP.md`, `docs/plans/1.0/INVENTORY.md` |
| R, UG, RM, CL | `docs/ROADMAP.md`, `docs/USER_GUIDE.md`, `README.md`, `CLAUDE.md` (CL wins over every other source) |
| file:line | a file in `Sources`, `Tests`, `scripts`, `Resources` or `.github` |
| HIG | Apple's Human Interface Guidelines pages, named by topic |

- **Revision:** every file:line is at `0ecca33` (v0.6.2) unless it names a branch. 0.7 edits many
  of the same files (W-14, W-13, W-3c, W-1), so A-0 re-resolves them at the v0.7.0 tag.
- **0.7 branches** are cited as `origin/claude/070-<pkg>` at the commit read on 2026-10-30: `s1`
  `1ddbe23`, `w3a` `2435519`, `w13` `f94e3d1`, `r1` `583c67f`, `toolchain` `0d26a6d`,
  `integration` `8a0b222`.
- **Apple URLs:** fetched on 2026-10-30.

**Marks:** **[unverified]** nobody has checked it; **[uncertain]** the evidence is partial;
**[inference]** reasoned from verified facts, not observed; **[estimate]** a planning number.

**IDs:**
- Packages: A-0 (intake); A-1 to A-7 (the answers); X-1, X-2 (accessibility); P-1, P-2
  (protection: the sentinel and update safety); E-1 to E-3 (the engineering lane); T-1 (the
  session script); K-1, V-1 (0.7's conditional carry-overs); L-1 (localization, docs, What's New);
  D1-D3. A package split into a core half and an app half has `a` and `b` (A-6a, A-6b).
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
  0.9.0 can freeze and 0.9.x prove stability (RD §3).
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
    "80 %, reached") and in Overview's sentence, and in `bpulse --json` as
    `systemChargeLimitPercent` when known. It ships only if its check passes on the M5, from the
    app's own process (G8-1); otherwise the number stays unknown, a known limitation. Nothing
    sets a limit, and no private framework is loaded (M-3).
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
- **Resilience:** a sentinel around the private calls (P-1, NEW-14) and update safety (P-2,
  NEW-16 with SEC-07): the installer refuses a bundle that needs a newer macOS, checks that the
  volume can swap, and puts the old copy back if the new one doesn't launch.
- **The engineering lane** (Linux only, no maintainer time): frozen-surface tests with golden
  outputs (E-1, NEW-08; M-6 enters ROADMAP's Decisions), storage, perturbation and degradation
  tests (E-2, NEW-09, NEW-10), and the log-privacy guard with the legacy migration removed (E-3,
  NEW-12, QUA-15).
- **What 0.8 doesn't touch:** the widget (FEA-20 is 1.1; the `systemChargeLimit` field keeps
  "Reached" unless 0.7's feed shipped), settings keys (none added: §7.3), the capture format, and
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
- **Budget** [estimate]: about 29-40 implementation and review runs (§7.2; RD §3.3 says 30-38),
  plus 3 for fixing forward; 1-6 more if 0.7 left a conditional item (§2.1). The never-cut set is
  about 23-30.
- **Not in 0.8** (Appendix A has each row): `bpulse` inside the app (M-7), `SECURITY.md`, the 1.0
  docs and README's status line, closing the verification matrix, the Russian screenshot set and
  the beta styles' final stance (all 0.9.0); the soak, energy budgets and upgrade matrix (0.9.x);
  the History and iPhone & iPad widgets, the feed and FEA-20 (1.1); W-9 (after 1.0); setting a
  limit (FEA-27, M-3); grades of our own; telemetry beyond the version count; MetricKit; °F.

---

## 2. Inputs and dependencies on 0.7

### 2.1 What 0.8 takes from 0.7, and what it does if that is missing

0.8 starts from the v0.7.0 tag. A-0 checks each row against 0.7.0's Appendix C, read at 0.7's
`<keep>` (the tag no longer holds `docs/plans/0.7.0/`, P7:3025-3029).

| # | 0.7 item | What 0.8 needs from it | If it was cut, moved or missing |
|---|---|---|---|
| I-1 | W-14: `SystemChargeLimit`, `isAtSystemChargeLimit`, `WidgetStateWord.chargedToLimit`, `BatteryMotionKey`'s flag, the Demo scene, Power's "Charge limit: Reached", and the fixture `m5-macos27-charge-limit.plist` (P7:1444-1527) | A-1's cause type grows from it; A-2's number fills its row | **Moved whole to 0.8** (only by G7-18, already answered: the capture came, P7:2605): A-1 first lands W-14 as P7 specifies (+2 runs, its frozen field raw value `systemChargeLimit` included), then generalizes it |
| I-2 | W-13: the version-count toggle in Settings → General, three settings keys, What's New's "Anonymous version count" row for updaters from before 0.7 (P7:1729-1731, P7:1772-1776) | A-5 keeps the toggle in Welcome (NEW-24's announcement); L-1 keeps appending the row | **Moved to 0.8** (only if review found a promise of P7 §11 it couldn't keep, P7:2611): 0.8 carries W-13 whole before A-5 (+2 runs), with its own privacy review; A-5 then places the toggle |
| I-3 | S-1: `MachineJSON` with `formatVersion` (`MachineJSON.swift:7-8` on `origin/claude/070-s1`) and ISO 8601 device dates | E-1's goldens pin these 1.x shapes; A-2 adds a key under its rule | Never cut in 0.7 (G7-14). If absent: E-1 waits for it, and A-2's key goes in without a version field |
| I-4 | W-1: `localizedLiterals(in:)` in `LocalizationCatalogTests` and the widget types in `BatteryCore/Widget/` | X-2 extends the scanner to `accessibilityValue(`/`accessibilityHint(`; A-3 reuses `WidgetCondition` if it fits | X-2 extends today's `localizingCall` regex (`LocalizationCatalogTests.swift:19-21`) instead |
| I-5 | W-6's `WidgetChartSummary` (stretch, P7:1954) | X-1 reuses it for chart descriptors | **Expected missing** (W-6 is stretch): X-1a builds `ChartSummary` in BatteryCore (+1 run, RD §3.3) |
| I-6 | W-5's feed (stretch) | The widget field `systemChargeLimit` could show "80 %" | **Expected missing:** the field keeps "Reached" (RD §3.3); FEA-35's widget half goes to 1.1 with the feed |
| I-7 | W-12: the session script with `charge-limit` and `hold-watch` steps, the hands-free helpers, the menu-bar shot method that replaces CGWindowList (P7:524-532, P7:1339-1344), and `SESSION-R.md` | T-1 builds 0.8's sessions on them | **Expected missing:** P7's D3 removes `docs/plans/0.7.0/` and copies nothing forward (P7:2044-2047), unlike 0.6.2's D3, which copied the tooling for 0.7 (P7:263). So A-0 restores them from 0.7.0's `<keep>` commit or the release PR's head into `docs/plans/0.8.0/` (T-1 counts the run that adapts them), unless 0.7's D3 is asked to copy them first. No menu-bar method: T-1 uses the AX frame of the status item, else a computer-use crop (§6.7) |
| I-8 | QUA-06's `hold-watch` night (P7:2436-2438): whether an optimized hold was seen, and whether it sets bit 24 | G8-2: the optimized-hold cause | **No hold seen** (nobody knows which night macOS holds): T-1 offers the step again before 0.8's D1; still none: that cause waits until after 1.0, and today's "Charging on hold" stays (RD §5.1 QUA-06) |
| I-9 | D1's build-number clock that only grows (P7:2022-2028) | 0.8's look-shoot build and RCs must sit above the installed 0.7.0 | If 0.7 shipped without it: 0.8's A-0 lands it first (one commit), before any M5 build |
| I-10 | The installer's pre-swap end of the widget extension, pinned by a source test (P7:953-956) | P-2 edits the same function; the test keeps the order | If the test is missing: P-2 adds it |
| I-11 | K-1, the backup key's public half (P7:1641-1652, cut-order 8) | C15 needs two keys at 1.0 | **If it moved to 0.8:** K-1 runs here, once the maintainer has generated the key (§14 M-9 steps); if he never does, ROADMAP records the accepted risk (C15) |
| I-12 | R-1's `docs/VERIFICATION.md` (NEW-18; cut-order 7) | D3 fills 0.8's rows | **If it moved to 0.8:** V-1 creates it from `origin/claude/070-r1`'s draft (`583c67f`, +153 lines) |
| I-13 | G7-11's reload-delivery measurement (P7:2598) | — | If the logged day gave none: Session R8's day measures it (§6.5) |
| I-14 | W-0 item 9's open checks: the menu bar item on a dark bar and WP-18's Xcode items (P7:524-541), if 0.7's Session R didn't close them; and G7-12's widget tree read in English and Russian (P7:2367-2386), whose default leaves the row open (P7:2599) | C10 counts every widget family as reachable and named (RD:326-327), and 0.8's is the VoiceOver and keyboard sitting that passes C10's script (M-12; RD §3.3's exit criteria) | Session R8 runs them (§6.4 step 7, step 3 for the widgets, and step 11b for the Xcode items) |
| I-15 | W-3c: `PageID`, `WindowOpener.showMainWindow(page:)`, and the History-over-Raw-Data fix (P7:518-523) | A-4's popovers and X-2's keyboard paths run on `MainView` as W-3c leaves it | If it slipped: X-2 takes the History fix if Session R8's keyboard walk reproduces it |
| I-16 | 0.7's toolchain: CI's macOS job on Xcode 27.2 (Apple's release candidate 27B48), the Linux job still on Swift 6.4, the cloud sessions on Swift 6.4.2 (`origin/claude/070-toolchain`, `0d26a6d`'s message) | A-6 uses `fileExporter(…item:…)`; the `FileDocument` overload is deprecated in the 27.2 SDK (Appendix B) | Nothing changes: the `item:` overload is what the app already uses (`DeveloperView.swift:125-133`) |

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
- **The maintainer's standing requests:** hands-free sessions (2026-10-23); he decides only what he
  sees or does (RD §1.2 item 8).

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

- **Branches:** the integration branch is `claude/080-integration`, from the v0.7.0 tag; packages
  are on `claude/080-<pkg>`, look-shoot builds and spikes on `claude/080-spike-*` (never merged).
  This plan reaches it from `claude/080-plan` at A-0.
- **The "before"** is v0.7.0: CI's size report, `perf` lines, and the golden outputs E-1 commits.
- **The catalog:** one running package touches `Resources/Localizable.xcstrings` at a time, in §5's
  catalog order. A package with a core half and an app half (A-6, X-1, X-2, P-2) runs its
  BatteryCore half in the slot that never touches the catalog, and its app half, which owns the
  strings, in the catalog slot.
- **Screens are shot on the M5, not rendered in CI.** 0.7's CI PNGs cover widgets, which
  `ImageRenderer` can draw; the app's pages hold controls backed by AppKit, which it can't:
  Apple's page says it leaves out "more complex controls and containers" and "most types of UIKit
  and AppKit views", drawing a placeholder instead
  (https://developer.apple.com/documentation/swiftui/imagerenderer). So the look shoot (§6.1)
  takes every new screen from a CI build, in both languages, and the reviews run on those shots.
- **0.8 keeps off the widget target.** A package that needs `Sources/BatteryPulseWidget/` (only
  A-2 if 0.7's feed shipped, I-6) records the widget's numbers in its commit message as 0.7 did.
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

- **Source:** P7 D3; 0.7.0's Appendix C; §2 above.
- **Items:**
  1. Read 0.7.0's Appendix C at 0.7's `<keep>` (from the 0.7.0 release PR's `refs/pull/<n>/head`)
     and fill §2.1's last column with what happened to each row (I-1 to I-16): whether W-13 and
     W-14 shipped as planned, K-1, the NEW-18 file, W-5 and W-6, the hold-watch night, G7-11's
     measurement, the menu-bar method, and Session R's open checks, G7-12's widget tree included.
  2. Merge `claude/080-plan` into `claude/080-integration` (this file), and restore 0.7's session
     tooling into `docs/plans/0.8.0/` from `<keep>` (I-7: P7's D3 copies nothing forward), unless
     0.7's D3 already did.
  3. Re-resolve every file:line of this plan at the v0.7.0 tag. W-14, W-13, W-3c and W-1 move most
     of the app files 0.8 touches. P7, W, AC62 and the session reports stay cited at `0ecca33` or
     0.7's `<keep>`, since the tag no longer holds them.
  4. Check that every decision is as recorded (§2.3, §14), and that 0.7's build-number clock
     shipped (I-9).
  5. Record v0.7.0's CI sizes (§9) and the `.public` baseline for E-3 at the tag.
- **Acceptance:** §2.1 is complete; every package names its §2.1 rows.
- **Effort:** none in runs (the I-9 commit only if needed).

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
     hides, as W-14's does. The text report gains "Charge limit: 80 %". The widget keeps
     "Reached" unless 0.7's feed shipped (I-6).
  6. **The sample** (`scripts/charge-limit-sample.swift`, macOS only, run by T-1's
     `charge-limit` step): copies the file, overwrites `bootSessionUUID`, the `token` UUID's bytes
     and `owner`'s value in place with zeros of the same length, checks the copy still decodes to
     the same number, and saves it for the fixture. With `pmset -g battlimit`'s verbatim text and
     `defaults read com.apple.batteryui.charging.mac` beside it. Committed only after his yes before
     `send`.
  7. **Logs:** one `monitor` line per read: the source's case name and the percent, `.public`
     (numbers and case names only); never the path or an error description (CL logging).
- **Fixtures:** `Tests/BatteryCoreTests/Fixtures/powerd-charging-<n>.plist` (the policy at each
  limit the step read) and `powerd-charging-none.plist` (100 %), redacted by item 6, with README
  rows.
- **Files:** `Sources/BatteryCore/{SystemChargeLimitSource, BatterySnapshot, BatteryReport}.swift`,
  `Sources/BatterySource/SystemChargeLimitReader.swift`, `Sources/BatteryKit/BatteryMonitor.swift`,
  `Sources/bpulse/main.swift`, `Sources/BatteryPulseApp/App/{Localized, DemoController}.swift`,
  `Main/{PowerView, OverviewView}.swift`, `MenuBar/PopoverView.swift`,
  `Resources/Localizable.xcstrings`, `scripts/charge-limit-sample.swift`, the fixtures and README,
  `Tests/BatteryCoreTests/{SystemChargeLimitSourceTests, SecurityGuardTests}.swift`,
  `docs/USER_GUIDE.md` (Power), `.github/workflows/ci.yml` (the sample script's type-check).
- **Linux tests:** each redacted sample gives its number and the 100 % one nil; a terminated
  policy, another reason, 75 or 105, a missing `policies`, a truncated archive and an XML copy
  each give their case; the stand-in never reads `owner` or `token`; `--json` has the key only
  when known (a snapshot round trip); the Demo scene's number.
- **Guards** (`SecurityGuardTests`, with `catches` cases): the plist's path literal appears only
  in `SystemChargeLimitReader.swift`; `SystemChargeLimitReader` is forbidden under
  `BatteryPulseWidget/` (the widget reads the battery and nothing else, and W-3a's guard covers
  file APIs only there, `SecurityGuardTests.swift:130-136` on `origin/claude/070-w3a`; whether its
  sandbox could read the plist at all is [unverified]); `ChargeCtrlPolicy` appears only in
  BatteryCore's parser; no `NSClassFromString`.
- **Acceptance:** both jobs green; G8-1 passed on the M5 (§6.1 step 2), with the app's logged
  number equal to `battlimit`'s at the hold (and at a second limit when the charge allowed one),
  absent at 100 % and on battery; the redacted samples committed.
- **Effort:** M, 2-3 runs (+1 for the `battlimit` fallback only if G8-1 picks it).
- **Risks:** the format is private and undocumented, so a macOS 27.x update may change it: the
  reader then logs `format` and the number goes unknown, never wrong (the parser accepts one
  shape). Reading `/Library/Preferences` from the app's own process may differ from Terminal's
  reads [inference: not a consent-protected location in Apple's list, Appendix B]: G8-1 checks.
- **Rollback:** before D1, revert the reader's wiring and keep the parser (it reads nothing).
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
- **A-6a, the core (no catalog):**
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
  file. `IsolationGuardTests`: the assembly is on its off-main list.
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
- **X-1a, the core (no catalog):** `ChartSummary` in BatteryCore, built from `HistoryChartData`
  (`HistoryChartData.swift:15-34`): per series its name key, unit, time span, minimum, maximum and
  at most 48 points (hourly or daily, by the range shown), all pre-formatted. If 0.7 shipped W-6's
  `WidgetChartSummary` (I-5), X-1a reuses it and shrinks.
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
- **X-2a, the core (no catalog):** `AccessibilityText` in BatteryCore: the pre-formatted values
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
- **Files:** `Sources/BatteryCore/AccessibilityText.swift` and its tests (X-2a);
  `Sources/BatteryPulseApp/Main/Components/{RingGauge, PowerFlowView, CapacityBars}.swift`,
  `Settings/PreviewTilePicker.swift`, `Main/DeveloperView.swift`, `Updates/UpdateViews.swift`,
  `Resources/Localizable.xcstrings`, `Tests/BatteryCoreTests/LocalizationCatalogTests.swift` (X-2b).
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
- **P-2a, the core and the installer (no catalog):**
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
- **P-2b, the strings (the catalog):** the two new errors' words in the update window.
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

### E-3: The log-privacy guard and the legacy migration (P2, cut fourth; NEW-12, QUA-15)

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

### T-1: The session script and runbooks for 0.8 (P1)

- **Source:** 0.7's W-12 and its script (I-7); RD §3.3's sittings; §6 below; Session B's lessons
  (P7:524-532) and today's (§2.2).
- **Items:**
  1. **Steps** in `docs/plans/0.8.0/m5-session.sh` (0.7's script, copied forward): `look-shoot`
     (§6.1), `charge-limit` (G8-1, rebuilt: the app's own logged reads against `pmset -g
     battlimit`, `defaults read` and `bpulse --smc` at each limit, on AC and on battery, and
     A-2's sample script), `weak-adapter` (optional, Q8-3), `hold-watch` (0.7's, offered again,
     I-8), and Session R8's steps (§6.4).
  2. **The `battlimit` reading:** today's script looks for a number followed by "%"
     (`m5-session.sh:3768`, `:6623`, `:6911`), while Session A recorded `chargeSocLimitSoc = 80`;
     T-1 parses both forms, from A-2's verbatim sample [unverified until the sample].
  3. **Runbooks:** `docs/plans/0.8.0/SESSION-L.md` (the look shoot) and `SESSION-R.md` (R8, its
     day's end, Hold watch and After publishing, each short section making its own worktree under
     `~/bp-080/`), each with Session B's rules, privacy and proofs.
  4. **`docs/plans/0.8.0/section.sh`:** prints one section of a runbook by its heading, so a start
     sentence shows the session only its section (§6.0).
  5. **Today's rules** in preflight and the steps (§6.0): Dock presence before access, widget shots
     by the script, a redraw before every widget shot, the quit and postpone asks.
  6. **CI:** `bash -n` and the type-checks for the new and moved files (ci.yml), and the queue dry
     run moved to `docs/plans/0.8.0/`.
- **Files:** `docs/plans/0.8.0/*` (the script, helpers, runbooks, `section.sh`),
  `.github/workflows/ci.yml`.
- **Acceptance:** CI's dry run and `bash -n` green; the look shoot runs from it.
- **Effort:** M, 2-3 runs, one of them adapting the tooling A-0 restores (I-7, expected); 1-2 if
  0.7's D3 copied it forward. **Rollback:** fix forward.

### K-1 and V-1: 0.7's conditional carry-overs

- **K-1** (only if 0.7's K-1 moved here, I-11): as P7:1641-1652. `ReleaseSigning.publicKeys` gains
  the backup key's public half (today one key, `ReleaseSigning.swift:15-17`); `UpdateInstallTests`
  pins two. S, 1 run, after the maintainer has generated it (§14 M-9).
- **V-1** (only if R-1's file moved here, I-12): `docs/VERIFICATION.md` from
  `origin/claude/070-r1`'s draft, with 0.7's rows from its Appendix C. S, 1 run.

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
     (P7:1772-1776), so an update from 0.6.x still announces it. 0.7's entries that nothing else
     uses leave the catalog in the same commit (`catalogHasNoLeftovers`).
  4. **Docs:** §12's list, with CL's new lines checked against the merged code by `git grep`.
  5. **SIZ-07** (P3), only if 0.7 didn't ship it and §9's measurement favours it: 0.8's
     explanation texts never appear in the widget, which carries the whole catalog.
- **Files:** `Resources/Localizable.xcstrings`, `Sources/BatteryPulseApp/Updates/UpdateViews.swift`,
  `CLAUDE.md`, `docs/USER_GUIDE.md`, `README.md`, `docs/ROADMAP.md`, `docs/plans/1.0/*`,
  `.github/release-notes.md`.
- **Effort:** M, 2 runs. **Risk:** low.

### D1-D3: Freeze, Session R8, release

As P7 D1-D3, with 0.8's differences.

**D1, the freeze:**
- **Golden diff:** E-1's files against v0.7.0: the text report's cause and limit lines (A-1, A-2),
  `--smc`'s two values, and `--json`'s new key only where a limit is known (no fixture has one).
- **Storage round trip:** byte-identical; QUA-15 only stops reading a file no release wrote.
- **The settings-and-identifiers `git grep`:** no settings key added or changed; new strings only
  in the catalog; the one new `--json` key `systemChargeLimitPercent` (if A-2 ships).
- **Ceilings** (§9), each raise in a commit of its own that says why.
- **The notes draft** (§13) and the PR with the session checklist.
- **The candidates:** RC-U, built as 0.7.99 (Session R8 runs on it, above 0.7.0), and RC-F, built
  as 0.5.99 for F12. Same commit, two dispatches; both build numbers from 0.7's growing clock
  (I-9).

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
  `section.sh`), as 0.6.2's D3 did for 0.7 (P7:263; 0.7's D3 doesn't, I-7), then remove
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
| C0 | A-0, the intake (orchestrator) | | v0.7.0 published; 0.7's D3 |
| C1 | A-1 | E-3 | C0 |
| C2 | A-2 | T-1, then A-7 | A-1 (Overview, Power, the popover, `Localized`, the report, Demo Mode) |
| C3 | A-3 | A-6a | A-2 (`Localized`, `OverviewView`) |
| C4 | A-4 | E-1 | A-3 (`HealthView`); E-1: A-1 and A-2 (the text report) |
| C5 | A-5 | P-2a | A-4 (the catalog); A-5: A-7 (the guide link) |
| C6 | P-1 | X-1a, then X-2a | A-5 (the catalog) |
| C7 | A-6b | E-2 | P-1 (`AccessoryMonitor`, the sentinel); A-6a |
| **Look shoot** | the M5, hands-free (§6.1), on a CI build of C7's merge | | A-1 to A-6 merged; T-1 |
| **Look review** | the maintainer at his desk (§6.2) | | the shots |
| C8 | the look's fixes; X-1b, then P-2b | K-1, V-1 (only if I-11, I-12) | the look review; X-1a; P-2a |
| C9 | X-2b; E-2's gaps (their strings) | | X-2a; E-2 |
| C10 | L-1: its key list, **the Russian review** on it (§6.3), the answers, the docs; merges last | | everything above |
| D1 | freeze; RC-U and RC-F | | C10 |
| **Session R8** and its day | the M5, hands-free (§6.4, §6.5) | | D1 |
| D3 | release; after publishing (§6.6); a week later, the counts | | Session R8 |

**Why this order:**
- **A-1 first:** it settles the cause type, the sentence slot and Demo Mode that A-2 builds on, and
  it changes the text report before E-1 pins it.
- **A-2 right after A-1,** since they share six app files; its check (G8-1) needs the look shoot,
  so the earlier it merges, the more time the reader gets in CI first.
- **The look shoot after C7,** when every new screen exists: one shoot and one review, as RD asks
  ("one look review and one Russian review"). X-1 and X-2 change little that shows, so they follow
  the review, and Session R8 checks them.
- **The Russian review inside L-1,** on L-1's list of every key 0.8 added: the keys C8 and C9 add
  after the shoot (X-1b, P-2b, X-2b, E-2's gaps) would otherwise miss it, and RD §3.3 sends every
  new string through it.
- **The engineering lane fills slot 2** (E-3, E-1, E-2), with the core halves (A-6a, P-2a, X-1a,
  X-2a) and the tooling (T-1), so slot 2 never waits on a look.
- **Catalog order:** A-1, A-2, A-3, A-4, A-5, P-1, A-6b, the look's fixes, X-1b, P-2b, X-2b, E-2's
  gaps, L-1.

**Files no package shares** (the review checks): `App/Localized.swift` and `Main/OverviewView.swift`
(A-1, A-2, A-3, A-4 in sequence), `Main/PowerView.swift` (A-1, A-2, A-4),
`MenuBar/PopoverView.swift` (A-1, A-2, A-4), `Main/HealthView.swift` (A-3, A-4),
`App/DemoController.swift` and `BatteryCore/DemoBattery.swift` (A-1, A-2),
`BatteryCore/BatteryReport.swift` (A-1, A-2, then E-1's goldens), `App/AppSettings.swift` (A-1's
`AppLinks`, then A-7), `App/BatteryPulseApp.swift` (P-1, A-6b), `BatteryKit/AccessoryMonitor.swift`
(P-1, A-6b), `Updates/UpdateViews.swift` (P-2b, X-2b, L-1),
`Tests/BatteryCoreTests/SecurityGuardTests.swift` (A-2, P-1, A-6b) and `docs/USER_GUIDE.md` (each
package its own section, L-1 last). **Rebase-over only:** `.github/workflows/ci.yml` (A-2, T-1, E-1,
P-2a) and `SourceScanner.swift` (A-4, E-3).

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
0.7.0's, I-9). **Started by** the line below, in `~/BatteryPulse`, on the adapter, in the evening or
any time he can leave the Mac for about 2 hours [estimate].

```
DISABLE_AUTOUPDATER=1 claude --allowedTools 'Bash(bash ~/bp-080/L/run/docs/plans/0.8.0/m5-session.sh:*)' --permission-mode auto 'Run the BatteryPulse 0.8 look shoot hands-free: in ~/BatteryPulse run git fetch origin claude/080-integration && bash <(git show FETCH_HEAD:docs/plans/0.8.0/section.sh) FETCH_HEAD SESSION-L.md Look shoot, then follow only what it prints.'
```

The flags are [check on his CLI once before], as in P7 §6.2.

**His part:** the line; one yes to the list of changes (the build installed over 0.7.0 and put back,
the Charge Limit set to two values and put back, the app's language switched and back,
`hasSeenWelcome` cleared and restored, Demo Mode on and off, the window style set to Clear for
Q8-4's badge (beta styles on) and back, a sentinel file placed and removed); the approvals
(computer use for BatteryPulse, System Settings and Finder, after rule 2's window); quitting his
own apps; then the adapter: unplug at a beep, plug in at a second beep about 7 minutes later. With
Q8-3's yes, a low-wattage USB-C adapter in at a third beep and the usual one back at a fourth.

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
5. **Restore and the summary:** 0.7.0 reinstalled, every changed setting put back from
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
3. "The Charge Limit's number on Power ('80 %', '80 %, reached') and in Overview's sentence: y, or
   say which." (only if G8-1 passed; default y)
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
2. **Install RC-U** over 0.7.0 the `UpdateInstaller` way; About reads 0.7.99; the widgets placed
   from 0.7 shot by the script after a redraw (rule 4): unchanged, since 0.8 keeps off the widget.
3. **The tree VoiceOver walks (C10),** in English and Russian: `ui tree` over every page of the
   main window, the compact window, the popover, every Settings pane, About, What's New, Software
   Update, Welcome and Report a Problem. The script checks that every control has a role and a
   non-empty label, that only decorative images lack one, that `PowerFlowView`, `CapacityBars` and
   the rings read as one element with a value, and that each chart has its label and descriptor
   (X-1) [uncertain: whether AX exposes the descriptor; else Accessibility Inspector by computer
   use, a shot per chart]. **The widgets** (C10 names every family): `ui tree` at each placed
   BatteryPulse widget, against `WidgetAccessibility`'s labels, as 0.7's Session R step 7 did
   (P7:2367-2386), in Russian after a redraw (rule 4); only the families and languages 0.7 left
   open (I-14), else one family as a check that 0.8 changed nothing.
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
7. **Menu bar icons (A11Y-04):** `scripts/menu-bar-shots.sh` by 0.7's method, else the status
   item's AX frame with `screencapture -R`, else a computer-use crop: Increase Contrast and Reduce
   Transparency, a light and a dark bar, on the M5's notch display.
8. **The Russian pages:** every page and window in Russian, judged against §6.3's answers.
9. **The Charge Limit live** (only if G8-1 passed and he said yes): the hold set as in §6.1 step 2,
   Overview's sentence and Power's number against `pmset -g battlimit`, then put back.
10. **Report a Problem on the RC:** both choices, saved, and the file checked as in §6.1 step 3;
    the crash reports' names match `ls` of the folder (G8-5).
11. **The sentinel (P-1):** with BatteryPulse quit, the script places the accessory sentinel file
    and launches the app: the Accessories page shows the note (a shot); Turn On Again by an AX
    press; the file is gone and the page reads. The same for devices only if device reading is on.
11b. **Optional, in the GUI phase:** WP-18's Xcode items (SUI-17's previews, SUI-19's timing,
    SZ-10's icon), only if 0.7 left them open (I-14), as 0.6.2's Session B ran them.
12. **F12** (at the day's end, after the measurements, as P7 §6.3: the rate check first): RC-F
    (0.5.99) → Check for Updates → Install and Relaunch, by AX presses: did BatteryPulse come back
    as the published 0.7.x? y/n.
13. **Start the day:** the `perf` stream under `nohup`, the display assertion released; the
    session ends its turn.

### 6.5 The day, and its end (passive, then about 3-4 minutes)

- **During the day:** nothing to do.
- **"day-end":** the script stops the stream and records: crash reports for BatteryPulse and
  BatteryPulseWidget since prepare (must be 0, G8-10); `fault` messages in the subsystem (must be
  0); the reads, and the Charge Limit reader's reads per trigger (§10); G7-11's reload delivery if
  0.7 handed it on (I-13). Then F12 (step 12), his batch, the optional VoiceOver listen (Q8-6: five
  minutes with VoiceOver on Overview, Power and Health, in Russian; "y = names make sense"), his
  yes and `send`, then `restore end` (0.7.0 reinstalled for §6.6, every setting put back from
  `changes.tsv`).

### 6.6 After publishing (a short session, about 2 minutes of his; D3)

From the restored 0.7.0, with his widgets placed. D3 posts the start line on the release PR, with
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
   appears once with 0.8's list (without the version-count row, since 0.7.0 already announced
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
| **G8-2** the optimized hold's cause | `NotChargingCause.optimizedHold` | QUA-06: 0.7's `hold-watch` night (I-8), or 0.8's own before D1; a capture of the Mac's battery with IOPS "Optimized Battery Charging Engaged", and whether bit 24 is set with it | No capture: the cause waits until after 1.0, and today's "Charging on hold" stays (RD §5.1). A hold that sets bit 24: W-14's precedence (the flag wins) is checked against the capture before the case lands |
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

**Conditional:** A-1's extra causes (G8-2 to G8-4), K-1 and V-1 (I-11, I-12).

**Cut in this order if the budget runs short** (RD §3.3; a cut item moves to 0.9.0, lands before
its freeze, and one with a look joins 0.9.0's screenshot sitting; each is still in 1.0, C1, C12,
C17):
1. A-2, FEA-35's number (0.7's "Reached" stays);
2. A-7, NEW-06;
3. A-5, NEW-04 (Welcome keeps embedding General, so the version count's announcement stays);
4. E-3, NEW-12 and QUA-15 (to 0.9.0's engineering lane);
5. P-1, NEW-14.

**Effort, in runs [estimate]:**

| Package | Runs | | Package | Runs |
|---|---|---|---|---|
| A-1 | 2-3 | | X-2 (a, b) | 2-3 |
| A-2 | 2-3 | | P-1 | 1-2 |
| A-3 | 1 | | P-2 (a, b) | 2 |
| A-4 | 2-3 | | E-1 | 2 |
| A-5 | 1-2 | | E-2 | 2-3 |
| A-6 (a, b) | 3 | | E-3 | 1-2 |
| A-7 | 1 | | T-1 | 2-3 |
| X-1 (a, b) | 1-2 | | L-1 | 2 |
| | | | D1+D3 | 2-3 |

- **Totals:** about 29-40 runs, close to RD §3.3's 30-38, plus 3 to fix forward. The never-cut
  set is about 23-30.
- **Extra work:** W-14 moved whole (+2), W-13 moved whole (+2), K-1 (+1), V-1 (+1), `battlimit`'s
  fallback (+1), each cause G8-2 to G8-4 brings (+1 each).

### 7.3 Frozen surfaces 0.8 changes on purpose, and how the notes say so

The frozen surfaces P7 §7.3 lists, with the earlier lists it builds on, hold, except these
intended changes:

| Surface | 0.7.x | 0.8 | Release notes line (§13) |
|---|---|---|---|
| **`bpulse --json`, `--watch --json`, Copy JSON** (C14 item 4) | `formatVersion` 1 (S-1) | Plus `systemChargeLimitPercent` (Int) only when known, on AC (A-2, if G8-1 passes). `formatVersion` stays 1: an added key, by S-1's rule | "For scripts: `bpulse --json` adds `systemChargeLimitPercent` when macOS's Charge Limit is known" |
| **The text report** (not frozen, M-6) | `Not charging reason: 0x…` | The cause's name after the hex; "Charge limit: 80 %" when known | "The text report names why the battery isn't charging, when it knows" |
| **`bpulse --smc`'s text** (not frozen, M-6) | `CHLT` and `CHNC` without values | With values | (the same line, if any) |
| **Storage** (C14 item 2) | `HistoryStore` imports a legacy `samples.jsonl` | No longer read (QUA-15) | "History no longer imports files from development builds before 0.3" |
| **Application Support** | `History/`, `Devices/`, the widget's files | Plus `Sentinel/` (P-1): internal, not a 1.x promise, removed at Turn On Again | — |
| **Settings keys** (C14 item 1) | 0.6.x's keys, `betaWindowStyles`, W-13's three | **Unchanged:** none added, none changed | — |
| **The capture format** (C14 item 3) | Four top-level keys | Unchanged; no thermal-state key (Q8-5) | — |
| **Widgets** (C14 item 5) | P7 §7.3's new surfaces | Unchanged; `systemChargeLimit`'s value text shows "80 %" only with the feed (I-6) | — |
| **The update contract** (C14 item 6) | The DMG, `.sig`, dSYMs, `BatteryPulse-count.txt` | Unchanged. The installer also refuses a bundle that needs a newer macOS or a volume that can't swap, and puts the old copy back if the new one doesn't launch (P-2) | "Updates check that the new version runs on your macOS before installing it" |
| **Privacy** (C14 item 8) | The update check, a chosen download, the version count | Unchanged: Report a Problem saves a file and sends nothing (§11) | "Help → Report a Problem… saves a file you can attach to an issue; nothing is sent" |
| **The Help menu** | BatteryPulse Help (at `main`), What's New | Plus Report a Problem…; Help opens the guide at the release's tag | (the line above) |
| **Welcome** | Embeds General | Six lines and their controls (A-5); the same two keys | — |
| **`WhatsNew.version`** | 0.7.0 | 0.8.0 | — |
| **`ChargeState`** | Five cases | Unchanged: the cause is computed (A-1) | — |
| **Signposts** (CL) | P7 §7.3's | Unchanged names; A-2's reads stay inside `read`, A-6's assembly adds `report.build` | — (CL's list) |

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
| A-2 [3-4] | "%@, reached" · Overview's sentence with the number ("Charging stopped at the Charge Limit, %@, set in System Settings → Battery.") · the Demo scene's detail |
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

**Where it starts:** v0.7.0's CI size report, recorded by A-0. For reference, at WP-15's final
head (`64f8aaa`, 2026-10-24, AC62:109): app binary 2,837,888 B (ceiling 3,000,000), widget binary
778,640 B (818,000), DMG 1,257,281 B (1,520,000), `app_kb` 4,004 (4,840); string tables 238,124 B
at 0.6.1 (R:529; ceiling 251,000). At `0ecca33` itself (CI run 41077479486, from `0d26a6d`'s
message): widget binary 778,672 B, string tables 239,574 B. Ceilings: `scripts/size-budget.json`.

**0.8's growth [estimate]:**
- **Strings:** about 90-130 keys, with A-4's long texts the bulk: about 150-300 B of Russian per
  key per table, in two bundles (the widget gets every `.lproj`, `build-app.sh:142`),
  so about 30-75 KB of `strings_bytes`. `strings_bytes` will cross 251,000: a raise at D1 in its
  own commit, unless SIZ-07 (L-1 item 5) halves the widget's copy first.
- **App binary:** about 60-150 KB for the report, the explanations, the descriptors and the
  installer checks. Against 3,000,000 B, a raise at D1 is likely; C6's 5 MB outer bound holds.
- **Widget:** unchanged code; its string table grows with the catalog (above).
- **DMG:** about 20-40 KB compressed.

**Rules:** each raise is a commit of its own that says why, at the RC plus about 5 % (P7 §9);
outer bounds: the app binary under 5 MB (C6), the DMG under 1,520,000 B unless a raise says why.
**Cut order if a bound is crossed:** SIZ-07 first; then A-4's long texts shortened; then the cut
line (§7.2).

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

`perf-stats` on Session R8's day compares reads per hour with 0.7.0's day (P7 §6.3): no more than
A-2's triggers add.

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
- **The privacy statement** (P7 §11, in README and UG) stays word for word, with one sentence added
  in UG's Privacy section: "Report a Problem saves a file on your Mac; BatteryPulse sends nothing."

---

## 12. Docs

| Document | Change | Package |
|---|---|---|
| `docs/USER_GUIDE.md`, Overview and Power | Why it isn't charging: the causes BatteryPulse names, the info button, Battery Settings…; the Charge Limit's number on AC, unknown on battery, and why | A-1, A-2 |
| `docs/USER_GUIDE.md`, Health | The summary; what "Maximum capacity below 80 %" means and what "Service Recommended" means | A-3 |
| `docs/USER_GUIDE.md`, Understanding the numbers (UG:533-563) | Kept; it says the same explanations sit next to each number | A-4 |
| `docs/USER_GUIDE.md`, First launch | The new Welcome | A-5 |
| `docs/USER_GUIDE.md`, Reporting a problem (UG:659-666) | **Rewritten** around Report a Problem, with no `swift run bpulse` (C17) | A-6b |
| `docs/USER_GUIDE.md`, a new Accessibility section | VoiceOver, the keyboard paths, the chart descriptors | X-2b |
| `docs/USER_GUIDE.md`, Accessories and iPhone and iPad | The sentinel's note and Turn On Again | P-1 |
| `docs/USER_GUIDE.md`, Updates | What the installer checks and the fallback | P-2 |
| `docs/USER_GUIDE.md`, Privacy | One sentence (§11) | A-6b |
| `.github/ISSUE_TEMPLATE/bug_report.yml` | The capture field points to Report a Problem | A-6b |
| `CLAUDE.md` | **Layout:** `NotChargingCause`, `SystemChargeLimitSource` (and the reader in BatterySource), `HealthSummary`, `MetricExplanation`, `ProblemReport`, `PerfSummary`, `ChartSummary`, `AccessibilityText`, `SentinelPolicy`, `SystemIdentity`. **macOS 27 layout:** the Charge Limit's number from powerd's plist on AC only. **Guards:** `ExplanationGuardTests`, `LogPrivacyGuardTests`, `FrozenSurfaceTests` and the goldens; SecurityGuardTests' new placements. **Language:** `SystemIdentity`'s `unsafe` sysctl in BatterySource's list. **Signposts:** `report.build`. **Releases:** the installer's minimum-system check and the relaunch fallback. **Logging:** "enforced by `LogPrivacyGuardTests`" | L-1 (each package lists its lines in its PR) |
| `docs/ROADMAP.md` | The 0.8 entry rewritten to what shipped, then ticked; Decisions: M-6 (E-1), the cause rule, the Charge Limit's source and caveat; Stage 1.4 and Stage 1.3's accessibility lines from §6.4; the Releases row; "Next: 0.9.0" | L-1, E-1, D3 |
| `docs/plans/1.0/ROADMAP.md`, `INVENTORY.md` | §2.4's corrections (bit 12, the parse method, the format version, the line numbers, the `.public` count, the sittings' minutes); FEA-35, NEW-01, QUA-06, QUA-15, A11Y-01 to A11Y-04, DIS-09 marked with what shipped | L-1 |
| `docs/VERIFICATION.md` | 0.8's rows filled at D3 | D3 |
| `README.md` | A line for Report a Problem and the accessibility support; "Status: early development" stays until 0.9.0 (DIS-10) | L-1 |
| `.github/release-notes.md` | §13 | L-1, D1 |

---

## 13. Release steps

As P7 §13, with 0.8's lines:
1. **Version:** the tag `v0.8.0`; `BUILD_NUMBER` from 0.7's growing clock (I-9), above RC-U's.
2. **Notes:** `.github/release-notes.md` opens with `## What's new in 0.8` (`release.yml`'s check).
   Only what landed:
   - why the battery isn't charging (the causes that shipped), and the general reasons when the
     battery reports none;
   - the Charge Limit's number on Power, if G8-1 passed ("BatteryPulse can't read it on battery");
   - Health's summary; explanations next to the numbers;
   - the new Welcome (if A-5 shipped); Help → Report a Problem… ("nothing is sent");
   - VoiceOver and the keyboard;
   - "Updates check that the new version runs on your macOS before installing it";
   - "For scripts: …" (§7.3's lines, the text report's included);
   - QUA-15's line;
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
- **M-9, the backup key** (only if 0.7's K-1 moved here, I-11): the steps are P7 §14's M-9. If
  the key never exists, ROADMAP records the accepted risk (C15).

**Nothing here reopens M-3:** 0.8 reads the limit from a file and never sets one, and PowerUI stays
out.

---

## Appendix A: traceability of every 0.8 item

**Sources:** RD (`docs/plans/1.0/ROADMAP.md`) §3.3, §5.1, §5.2 and §6; INV
(`docs/plans/1.0/INVENTORY.md`); P7 (`docs/plans/0.7.0/PLAN.md`); all at `0ecca33`.

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
| … the widget's number | RD:902-903; FEA-10 | Not in 0.8 without the feed (I-6); 1.1 with it |
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
| NEW-13 backup key | RD:1372; P7 K-1 | K-1, only if it moved here (I-11) |
| NEW-18 verification matrix | RD:1377 | 0.8's rows at D3; V-1 only if the file moved here (I-12); closed in 0.9.0 |
| NEW-22 the quick check after each macOS 27.x update | RD:1381 | Ongoing; T-1 keeps 0.7's step |
| NEW-23 download counts | RD:1382 | §13 step 8 |
| NEW-24 the version count's announcement | RD:1383 | A-5 keeps it in Welcome; L-1 keeps What's New's row |
| NEW-11 `formatVersion` | RD:1370 | 0.7; A-2's key is an addition, no bump (§2.4) |
| 0.7's `charge-limit` step | P7:2238, P7:2435 | T-1 rebuilds it for G8-1 (§6.1 step 2) |
| 0.7's What's New row | P7:1772-1776 | L-1 item 3 |
| W-13 moved whole (only on a broken promise of P7 §11) | P7:2611 | Carried whole before A-5, +2 runs (I-2) |
| W-3c's History-over-Raw-Data fix | P7:518-523 | X-2, if W-3c slipped and Session R8's keyboard walk reproduces it (I-15) |
| G7-12's widget tree read, if left open (C10's widget families) | P7:2367-2386, P7:2599 | Session R8 step 3 (I-14, G8-6) |
| SIZ-07 widget-only string table | RD:1306; P7:1988, P7:2621 (0.7's cut 3) | L-1 item 5, only if 0.7 didn't ship it and §9 favours it |
| SEC-06 no prompt for own data after an update | RD:1297 ("repeated in every after-publishing check") | §6.6 step 4 |
| DIS-06 widgets kept across an in-app update | RD:1312 | §6.6 step 3 (evidence for C7) |
| 0.7's pre-swap extension end | P7:953-956 | P-2 keeps it and its test (I-10) |
| 0.7's growing build number | P7:2022-2028 | Checked by A-0 (I-9) |
| 0.7's `WidgetChartSummary` | P7:1954 | X-1a reuses it, or builds `ChartSummary` (I-5) |
| G7-11's measurement | P7:2598 | Session R8's day, if handed on (I-13) |
| 0.6.2's open checks (the dark bar, WP-18's Xcode items) | P7:524-541 | Session R8 steps 7 and 11b, if 0.7 didn't close them (I-14) |
| W-9 widget extras | W:536, W:650 | Not in 0.8 (after 1.0) |
| The feed, History and iPhone & iPad widgets | RD §3.2, §4.1 | Not in 0.8 (1.1) |
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
| §2.1's last column: what 0.7.0 shipped of I-1 to I-16 | A-0 | §4's conditional work |
| v0.7.0's CI sizes and the `.public` baseline | A-0 | §9; E-3's allow list |
| The Charge Limit's reads per limit, on AC, on battery and after a plug-in; the app's logged number; `CHLT` and `CHNC`; the samples | §6.1 step 2 | G8-1 |
| The weak-adapter captures | §6.1 step 4 | G8-3 |
| The optimized hold's capture | 0.7's or 0.8's `hold-watch` | G8-2 |
| The look review's and the Russian review's answers | §6.2, §6.3 | G8-11; L-1 |
| The tree, keyboard, contrast, Stage 1.4 and menu bar results, per page and language | §6.4 steps 3-8 | G8-6 to G8-8; `docs/VERIFICATION.md` |
| The report's file checks; the crash folder's names | §6.1 step 3, §6.4 step 10 | G8-5, G8-13 |
| The sentinel's pause and Turn On Again | §6.4 step 11 | P-1 |
| F12; crashes and faults; reads per trigger; G7-11 if handed on | §6.4 step 12, §6.5 | G8-9, G8-10; §10 |
| The after-publishing results | §6.6 | the release's state |
| The download counts a week later | §13 step 8 | ROADMAP's Releases table |
