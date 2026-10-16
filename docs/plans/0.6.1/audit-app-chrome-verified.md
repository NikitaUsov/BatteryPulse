# App-chrome audit: adversarial verification

Checked against `6133b4f` (0.6.0) with `git show 6133b4f:<path>`, and against HEAD `a32bfae`. Nothing in
the repository was modified.

**The baseline moved.** The audit was written against `7bb2ac7` plus uncommitted edits. Those edits are
now on `main`, and the working tree is clean:

- `6584585` dims Clear: near-black 40 % in Light, 32 % in Dark. The commit also includes CH-14's
  preview hunk.
- `ec61436` moves the selection glass onto the selected tile itself.

Two other commits, `994c09d` (widget reload) and `a32bfae` (earbud names), touch no file in this
audit. Since 0.6.0, `MenuBar/`, `Welcome/`, `BatteryPulseApp.swift`, the widget and `BatteryMonitor`
are unchanged. Line numbers are HEAD's except in the 0.6.0-only Settings sections (CH-02, CH-03, CH-06), which give 0.6.0's line numbers. HEAD's are 10 lower past line 300.

## Verdicts

| ID | Verdict | Priority | Package |
|---|---|---|---|
| CH-12 | keep-modified (rebase on `ec61436`) | P1 | WP-UR (new, Phase A; else WP-9's first commit) |
| CH-13 | keep-modified (rebase on `6584585`, M5 gate, doc fixes) | P1 | WP-UR |
| CH-14 | reject: already landed in `6584585` | — | — |
| CH-08 | keep-modified (add the M5 check for a hidden status item, with a fallback) | P2 | WP-2 (+3 lines in `BatteryPulseApp.swift`, coordinate with WP-4) |
| CH-01 | keep-modified (P3, not P2) | P3 | WP-12 |
| CH-02 | keep-modified (do it during the SUI-13 split, no gate) | P3 | WP-9 |
| CH-03 | keep | P3 | WP-9 |
| CH-04 | keep | P3 | WP-9 |
| CH-05 | keep | P3 | WP-11 |
| CH-06 | keep-modified (diagnostics, not security; WP-9 does it during the split) | P3 | WP-9 |
| CH-07 | keep | P3 | WP-9 |
| CH-09 | keep-modified (one owner, Phase C) | P3 | WP-11 |
| CH-10 | reject | — | — |
| CH-11 | keep (inside SUI-13) | P3 | WP-9 |

**WP-UR** is a one-item package for the two user-reported bugs ("the style picker floods the style
itself" and "Clear has wild readability problems"). It lands in Phase A, so that:

- the maintainer can judge both fixes on the M5 early;
- CH-12's edit to `SettingsView.swift` merges before WP-9 splits that file.

If the playbook prefers no new package, both become WP-9's first commit. CH-13's files
(`BatteryCore/WindowLook.swift`, `App/WindowLook.swift`, `WindowLookTests`, `USER_GUIDE.md`) belong to
no other package.

## CH-12: remove the tile picker's glass (keep-modified)

**Confirmed.** At 0.6.0 a separate `Color.clear.glassEffect(.regular)` sat in the selected tile's
`.background`, 4 pt outset, inside a `GlassEffectContainer`. Two explanations exist for what the user saw:

- **The audit's:** the glass sits behind a nearly transparent `.fill.quaternary`.
- **`ec61436`'s commit message:** the container drew the glass over the preview.

The audit's mechanism is shaky: the preview `Canvas` paints its whole frame (the wallpaper gradient), so
glass behind it can't wash it. `ec61436`'s explanation fits the maintainer's report (the selection floods
the style itself) better. Both agree the selected tile is flooded.

**The fix on main is unverified.** `ec61436` puts `.glassEffect(.regular, in: shape)` on the tile's
VStack, so the preview and the name become the glass's content. This was built on Linux; no M5 check
is recorded. Apple documents that `glassEffect` both renders the material behind the view and "applies
the foreground effects of Liquid Glass over a view". It is unknown whether those effects alter a
`Canvas` drawn with explicit `Color`s. That uncertainty is the reason to remove the glass rather than
tune it.

**Removal is the better fix on its own merits:**

- **Native:** System Settings → Appearance marks its thumbnails with an accent outline only, no glass.
- **Project rules:** ROADMAP.md:18-21 allows custom glass "only on controls that float over content".
  These tiles sit inside a grouped `Form`; they don't float.
- **Less code**, and SettingsView leaves `glassAllowList`, which tightens the guard.

The audit's motion argument is weak. Under full motion, `crossfade` and `change` are the same
`.smooth(0.35)`, and `ec61436` morphs the glass only under full motion. So the misuse is nominal, not a
Reduce Motion bug. The removal makes it moot anyway.

**Modification: rebase on `ec61436`.** `glassOutset` and `selectionGlass(for:)` are already gone. What
remains to delete:

- `GlassEffectContainer` (body);
- `@Namespace glassNamespace`;
- `let flows`;
- `.glassEffect`, `.glassEffectID` and `.glassEffectTransition` (`SettingsView.swift:326-328`);
- the `AnyShapeStyle` conditional (`:325`), which returns to `.background(.fill.quaternary, in: shape)`
  for every tile;
- the glass sentences of the doc comment (`:270-275`) and the comment at `:292-293`.

Keep:

- `.animation(motion.crossfade, value: selection)`, since the outline is a colour change;
- `.opacity(isEnabled ? 1 : 0.5)`;
- the Show Borders overlay;
- the `isSelected` trait.

The rest is as the audit says:

- `MotionGuardTests.swift:38-39` drops the allow-list entry, and `:491` flips to `#expect(flags(...))`.
- CLAUDE.md drops the tile-picker entry from its custom-glass list.
- ROADMAP.md:20 drops "the selection of the tile pickers in Settings".
- No string changes. Net about −15 lines.

The 0.5 release notes advertised "a glass selection that flows from style to style"
(`.github/release-notes.md:42`). The 0.6.1 notes therefore need one line saying the selection is now an
accent outline. The release notes aren't a UI string, so this doesn't conflict with WP-6's ownership of
`Localizable.xcstrings`.

**Measure:**

- **Linux:** `swift test --filter MotionGuardTests`, and the strict lint.
- **M5:** read one point of the Clear tile's sky with Digital Color Meter, unselected and then selected,
  in Light and Dark. The values must be identical. Repeat on an Icon Style tile.
- **M5:** with full motion and with Reduce Motion, nothing moves.
- **M5:** the disabled Icon Style tiles are dimmed; VoiceOver says "selected"; Show Borders still draws
  every tile's edge.
- **Maintainer:** sign-off on a screenshot.

**Fallback.** If the maintainer wants to keep glass, `ec61436` stays only if it passes the same pixel
test on the M5.

## CH-13: Clear's dimming (keep-modified)

**Confirmed numerically.** I reproduced the audit's WCAG model: sRGB blend over a white backdrop,
near-black (0.03) dimming, label white at 85 % and secondary at 55 % (the dark appearance's label
alphas):

| Opacity | Primary | Secondary | Desktop brightness |
|---|---|---|---|
| 0.32 (HEAD, Dark) | 1.96 | 1.57 | 68 % |
| 0.40 (HEAD, Light) | 2.41 | 1.82 | 60 % |
| 0.50 | 3.21 | 2.24 | 50 % |
| 0.60 | 4.41 | 2.83 | 40 % |
| 0.62 | 4.71 | 2.97 | 38 % |
| 0.65 | 5.22 | 3.21 | 35 % |

HEAD's values (`WindowLook.swift:181`) leave white text at about 2:1 over a white window. A white
web page or document behind the window is common in Light and not rare in Dark. The user-guide claim
that the dimming "keeps the white content readable" (`USER_GUIDE.md:149`) is false in that case.

0.65 is the smallest round value that clears both bars: 4.5:1 needs about 0.61, and 3:1 for secondary
needs about 0.63. Apple's WWDC guidance of "a dark dimming layer of 35 %" is aimed at small bold
controls over media, not a window of body text. It doesn't justify HEAD's 40/32 for text content.

The ContentTreatment halo (radius 6, 0.44 to 0.55) puts only about 0.1 opacity under a 1.5 pt stroke,
so it doesn't change the picture. The tight 1 pt shadow helps glyph edges but doesn't count for WCAG.

**Modifications:**

1. **Rebase on `6584585`.** Change only the constant: `.clear: Tint(white: 0.03, opacity: 0.65)`. Then
   update the doc comment and the `WindowLookTests.swift:131-132` expectations. CH-14's preview already
   reads `sheetTint`, so the Clear tile follows.
2. **Add the Linux test `clearKeepsTextReadableOverAWhiteWindow(systemDark:)`** (it needs
   `import Foundation`). It is a contrast floor computed from `sheetTint`, and it pins the readability
   guarantee rather than the number. Its comment should name the label alphas it assumes.
3. **Don't assume Light and Dark are equal on hardware.** HEAD's comment says the Dark glass is
   "already smokier", and `Glass.tint` isn't documented as a linear alpha. Measure both appearances on
   the M5 with Digital Color Meter in a backdrop gap over a white TextEdit page. The model expects about
   94/255.
   - **More than about 10 above:** draw Clear's dimming as a plain fill over untinted `Glass.clear`
     inside `GlassSheet`, for Clear only.
   - **Clearly below in Dark** (the glass adds its own smoke): Dark may take a smaller tint, as long as
     the measured value stays at or below about 94.
4. **Docs.** At 0.65, Clear in Dark is darker than Translucent's 45 %. The guide's "from the most opaque
   to the most transparent" (`USER_GUIDE.md:141`) then misleads; reword it to describe sharpness, from
   opaque to clear glass. Line 149: "almost sharp under a dark dimming that keeps…" becomes "sharp but
   dimmed", and the "lighter or smokier" clause goes. CLAUDE.md's "Clear with a dark dimming" stays.
   No UI string changes. The Settings footer "The hardest to read" can stay.
5. **Maintainer sign-off on screenshots** over a white page and a busy wallpaper, in Light and Dark.
   Clear becomes visibly darker; that is the price of readability. The audit's fallback (sheet at 0.40
   plus a near-black plate under each group) is effectively bringing back the cards Clear dropped, so it
   needs the maintainer's choice, not a default.

Translucent is unchanged. Energy is unchanged: there is no new blur pass.

## CH-14: reject (done)

`6584585` committed exactly this hunk (`WindowLookSettings.swift:150-162`). The Translucent tile is
value-identical to 0.6.0: `Color(white: 0/1, opacity: 0.45)` equals `.black/.white.opacity(0.45)`, with
the same 1.5 blur. Nothing is left to do.

## CH-08: the menu bar poll stops when one label member goes (keep-modified)

**Confirmed** (`MenuBarLabel.swift:28-52`). Apple documents that modifiers applied to a `Group` "affect
all of that group's members". Here is what happens when one member disappears:

- turning the icon off;
- Demo Mode ending;
- the fallback icon going.

That member's `.onDisappear` sends `nil` for `"menuBar"`. `onChange(of: liveRefreshInterval)`
doesn't fire again, because the interval didn't change. So, with no window open, the 10 s power poll
stops while power is still shown (`BatteryMonitor.swift:80-90`), and the menu bar's power value goes
stale until an IOPS notification. A member that appears later re-runs `onChange(initial: true)`,
which is why the bug comes and goes.

The fix is right:

- delete `.onDisappear`;
- add Scene `.onChange(of: showInMenuBar)` sending `nil` when the item is removed (macOS 14+ API);
- put the `menuBarReady` signpost behind a once-flag.

**Added M5 check.** Turn BatteryPulse off in System Settings → Menu Bar ("Allow in the Menu Bar").
If that tears the label down, 0.6.0 stopped the poll, but after the fix it would keep polling every
10 s while the item is hidden. In that case, use a member count instead of deleting `.onDisappear`:

- `@State var shownMembers`;
- `+1` in `onAppear`, `−1` in `onDisappear`;
- `nil` at zero.

Either way, WP-2's EN-6/E5 policy still applies on top.

**Owner:** WP-2 owns `MenuBarLabel.swift`. The 3-line Scene hunk is in WP-4's `BatteryPulseApp.swift`;
rebase order or a note in WP-4 is enough.

## CH-01: the welcome icon's animation outside Motion.swift (keep-modified)

**Confirmed.** `AppIconView.swift:86-88` builds `.smooth(duration: 0.8).delay(0.2)` outside
`Motion.swift`, the only such site. A grep for Animation constructors outside `Motion.swift` finds no
other. `withAnimation(motion.iconDrawIn)` passes `goesThroughMotion`, so the guard misses it.

Moving the property and adding a row to the preset table costs about 4 lines. The row must state
that it is the one 0.8 s flourish, gated on `allowsFlourish`. That 0.8 s also breaks the 0.15–0.35 s
range in `Motion.swift`'s header.

The new guard rule:

- needs `\bAnimation\.`, so that `DemoAnimation.allCases` isn't flagged;
- must exclude `motion.linear(`;
- must pin both cases as allows.

**Priority P3, not P2:** there is no runtime effect. **Owner:** WP-12. Phase C comes after WP-2 is done
with `Motion.swift`.

## CH-02: modifiers on Sections (keep-modified)

**Plausible, unverified.** At 0.6.0 these modifiers sit on Sections:

- `onAppear`/`onReceive` on a 3-row Section (`:137-140`);
- `task`/`onChange` on the 1-2-row Preview Section (`:420-428`);
- `confirmationDialog` on a 2-row Section (`:460`).

If Section distributes modifiers the way `Group` does, the costs are 6 `SMAppService.status` reads per
activation, idempotent authorization requests, and possibly two dialog presenters.

Moving each modifier onto one always-present row is behaviour-neutral either way. Apple's own
`confirmationDialog` examples attach it to the button that sets the flag. So no M5 gate is needed: do
it inside WP-9's SUI-13 split, which rewrites these lines anyway.

**Targets:**

- the "Open at login" VStack;
- the "When charged to" Picker, which is always present. Don't use the conditional Preview rows: a
  `.task` would restart when `isDenied` flips.
- the Clear History… button.

P3.

## CH-03: stale "notifications are off" (keep)

**Confirmed.** `isDenied` is read only in `.task` (`:420`) and after actions. Returning from System
Settings doesn't refresh it, while the Settings window stays open. `onReceive(didBecomeActive)` is the
pattern `GeneralSettings` already uses (`:138`). Attach it next to the `.task` on the Picker (see
CH-02). It costs one XPC per activation, only while the tab is shown. P3, WP-9.

## CH-04: WindowOpener in the panel (keep)

**Confirmed.** `MenuBarLabel` sets `WindowOpener.openWindow` on appear (`:47`), before the panel can
exist. The two per-button assignments in `PopoverView` (`:63`, `:68`) are redundant, and the Update row
(`:118`) shows they aren't needed.

One `.onAppear` on the panel root is fine. Deleting the two lines outright is also fine. P3, WP-9
(`PopoverView` is in its list).

## CH-05: MenuBarIconPreview's unused parameters (keep)

**Confirmed.** There is one caller (`SettingsView.swift:245`). It passes `magnification` and never
`state`, and the `BatterySnapshot` exists only to feed `symbolName(for:)`. Calling
`symbolName(percent:state:)` gives the same symbol. About −3 lines, zero risk. P3, WP-11.

## CH-06: Clear History swallows its error (keep-modified)

**Confirmed** (0.6.0 `:463-466`, HEAD `:454`, `try?`). `HistoryStore.clear()` throws before it resets anything in memory,
so the failure is silent rather than inconsistent. That breaks SW-R12, and the user believes local data
was deleted.

The fix is right, but it is diagnostics, not security. A user-facing error would need a new string
(WP-6 only) and is not proposed.

**Owner: WP-9, during the split.** WP-0's `App/Diagnostics.swift` already provides the `history`
`Logger` by then. Leaving it to WP-4 would mean a hunk in WP-9's freshly split file. P3.

## CH-07: the widget placeholder shows the error layout (keep)

**Confirmed** (`BatteryPulseWidget.swift:37-39`). `snapshot: nil` renders "No battery information"
redacted. WidgetKit's contract is a generic version of the real layout. A sample
`BatterySnapshot(timestamp:chargePercent:chargeState:)` exists (`BatterySnapshot.swift:86`). Only the
loading state changes; a Mac without a battery still gets the error from `getTimeline`.

P3, WP-9. The widget's views are in no other package's list.

## CH-09: the menu bar choices are declared twice (keep-modified)

**Confirmed.** Five `@AppStorage` declarations, with defaults that must agree, sit in
`MenuBarLabel.swift:13-17` and in `SettingsView.swift:210-214`. If they drift, the label and the toggles
disagree until a key is written: a real maintenance hazard, not just style.

A nested `DynamicProperty` with internal `@AppStorage` members gives `choices.$showsIcon` bindings, and
it must be a stored property.

**Modification:** one owner in Phase C (WP-11), after WP-2 (owner of `MenuBarLabel.swift`) and WP-9
(the split) merge. The audit's "WP-2 defines, WP-9 adopts" would couple two parallel worktrees. The
defaults should come from `MenuBarContent.default` and `MenuBarIconStyle.default`. Then:

- after `defaults delete`, the app shows icon + percentage;
- the migration in `AppSettings.swift:107-118` still writes the same keys.

P3.

## CH-10: reject

`.onChange(of: AppSettings.alerts)` would swap an explicit list of the view's own `@AppStorage` values
for a static `UserDefaults` read inside `body`. SwiftUI doesn't track that read; it only works because
the same keys happen to be `@AppStorage` dependencies of the view. The line count is the same and
nothing is measurable. It is a refactor that only moves code, and it adds a hidden dependency.

## CH-11: WelcomeView repeats SettingsPage (keep)

**Confirmed.** `WelcomeView.swift:32-37` repeats `SettingsPage`'s four lines, because `SettingsPage`
is `private` (`SettingsView.swift:31-40`). Make it internal and reuse it as part of SUI-13's
shared-components split. About −3 lines. P3, WP-9.
