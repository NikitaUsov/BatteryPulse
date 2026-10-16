# Audit "app-chrome": MenuBar, Settings, Welcome and the widget (base 6133b4f; checked at 7bb2ac7)

Read-only audit. I read all 9 files in the area in full (1,847 lines):
- `Sources/BatteryPulseApp/MenuBar/`: `MenuBarLabel` (76), `BatteryIconView` (343), `PopoverView` (197),
  `PopoverAccessories` (88);
- `Sources/BatteryPulseApp/Settings/`: `SettingsView` (498), `WindowLookSettings` (240);
- `Sources/BatteryPulseApp/Welcome/`: `WelcomeView` (58), `AppIconView` (140);
- `Sources/BatteryPulseWidget/BatteryPulseWidget.swift` (207).

I followed the calls they make into BatteryCore (`BatteryIconState`, `MenuBarContent`,
`BatteryPresentation`, `WidgetTimelinePlan`, `AccessoryParser`), into `App/` (`WindowOpener`,
`LaunchAtLoginModel`, `Phrases`, `Motion.swift`) and into `Tests/BatteryCoreTests/MotionGuardTests.swift`,
and checked them against `v061/playbook.md` and CLAUDE.md. IDs are `CH-nn`. "Owner" is the playbook
work package whose files the change touches (§3.2). All paths below are relative to
`Sources/BatteryPulseApp/` unless they start with `Sources/` or `Tests/`.

## Already covered by the playbook or a sibling audit (not repeated)

- **SUI-06:** `BatteryFormatter.app` is a computed `static var`. In this area it is built in
  `MenuBarLabel.swift:27` and `:65` (twice per label body), `PopoverView.swift:135`,
  `PopoverAccessories.swift:54` (once per accessory part) and `SettingsView.swift:374`.
- **SUI-07:** the popover re-runs its whole body on every 2 s reading (`PopoverView.swift:19`
  reads `monitor.snapshot`). It is gated on body counts.
- **SUI-10 / UI-8:** `SettingsView.swift:420` `.task` and `PopoverView.swift:124` `.task(id:)` get names.
- **SUI-13 (WP-9):** split `SettingsView.swift` into one file per pane. `Crossfade` (`:46-72`) and
  `PreviewTilePicker` (`:275-364`) are shared components, so they move with that split, not into a
  pane file. `MotionGuardTests.glassAllowList` and CLAUDE.md's glass list name `SettingsView.swift`
  and must follow `PreviewTilePicker`.
- **SUI-20 (rejected):** keep the `didBecomeActiveNotification` `onReceive` (`SettingsView.swift:138`).
- **SW-06:** `AppearanceVariants` (`BatteryIconView.swift:325`) stays `@unchecked Sendable`: it is
  immutable and holds `CGImage`s.
- **SW-04 / WP-10:** `@MainActor` on `MenuBarIconRenderer` (`BatteryIconView.swift:266`) and on the
  two static flags (`PopoverView.swift:114`, `AppIconView.swift:17`) become redundant under default
  main-actor isolation. The widget stays nonisolated. Its `Task { @MainActor in … }` hops
  (`BatteryPulseWidget.swift:42, 48`) are needed because `MacBatteryProvider` is `@MainActor`
  (`Sources/BatteryKit/MacBatteryProvider.swift:23`).
- **SZ-07:** the widget copies every `.lproj` (`scripts/build-app.sh:90`) but uses about 15 strings.
  The size research leaves per-key filtering for later.
- **SZ-02:** the widget links all of BatteryKit for `MacBatteryProvider`. Dead-stripping with
  `_main` as the only export is what removes the rest.
- **AC-03 (app-core):** `LaunchAtLoginModel.refresh()` reads `SMAppService.status` twice. CH-02 below
  is about how many times the Settings views *call* `refresh()`, which multiplies that.

Verdict in one line: the area is small and careful, except for the two problems the maintainer
reported for 0.6.1, which both surface here. The menu bar icon is rendered once per state change,
and `level` only changes on whole percents because `Current Capacity` / `Max Capacity` is in
percent. The findings are:
- **P1, user-reported:**
  - the tile picker's glass selection floods the selected tile (CH-12). The in-progress fix moves
    the glass under the preview, where its foreground effects still alter the picture;
  - Clear's dimming leaves white text at 1.0:1 (Light, `7bb2ac7`) to 2.4:1 (the in-progress values)
    over a bright window. 65 % passes WCAG AA, with a Linux contrast test (CH-13, cross-area);
  - the window-style tiles copy the policy's tints by hand (CH-14; the in-progress edit already
    fixes it);
- a lifecycle bug in the menu bar label, by Apple's documented `Group` semantics (CH-08). It is the
  area's one energy-relevant defect, and it is the opposite of waste: the menu bar's power poll can
  switch itself off while power is still shown;
- one CLAUDE.md rule violation that the guard test misses (CH-01);
- a likely SwiftUI misuse that multiplies side effects in Settings (CH-02);
- a stale permission message (CH-03);
- small, exact cleanups (CH-04 to CH-07, CH-09 to CH-11).

`Sources/` is identical at `6133b4f` and `7bb2ac7`: `git diff --stat` between them lists only
`docs/` files. So every line reference in CH-01 to CH-11 holds at both, and those findings are
unchanged from the earlier pass. This revision adds CH-12 to CH-14, for the maintainer's report and
for the uncommitted working-tree edits seen while it ran.

---

## P1: the two problems the maintainer reported for 0.6.1

The 0.6.1 request names two visible problems: "the style picker floods the style itself" and "the
all-glass style has severe readability problems". Both sit in or next to this area:
- the tile picker is `PreviewTilePicker` (`Settings/SettingsView.swift`);
- the window-style tiles are `Settings/WindowLookSettings.swift`;
- the Clear style is drawn by `App/WindowLook.swift` with the values of
  `Sources/BatteryCore/WindowLook.swift`.

**Line numbers are at the committed `7bb2ac7`.** While this audit ran, the working tree gained
uncommitted edits to exactly these files: `SettingsView.swift`, `WindowLookSettings.swift`, both
`WindowLook.swift`, `WindowLookTests.swift`, CLAUDE.md and the user guide. They are the
maintainer's in-progress fix. Each finding below says what that edit does and whether it is
enough.

### CH-12 [bug] The tile picker's glass selection floods the selected tile; drop the glass, keep the outline
- **Where** (`Settings/SettingsView.swift` at `7bb2ac7`):
  - `:268-273`: the doc comment ("their selection is Liquid Glass: one shape behind the selected
    tile … The tiles keep their standard fill (no glass on glass)").
  - `:283` `@Namespace private var glassNamespace`; `:285-297` the `GlassEffectContainer` around the
    `HStack`, with `.animation(motion.crossfade, value: selection)` (`:295`) and
    `.opacity(isEnabled ? 1 : 0.5)` (`:297`).
  - `:318` the tile's fill is `.fill.quaternary`; `:326` the accent outline of the selected tile;
    `:328-332` `.background { if isSelected { selectionGlass(for: value) } }`.
  - `:340-351` `selectionGlass(for:)`: `Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 12))`,
    `glassEffectID`, the `.matchedGeometry` transition and `.padding(-4)`. `:357-358` `PreviewTile.glassOutset`.
  - Two pickers use it: Window Style (`WindowLookSettings.swift:19`) and Icon Style
    (`SettingsView.swift:245`).
- **Why it floods (at `7bb2ac7`):**
  - `.fill.quaternary` is the faintest standard fill and mostly transparent. The `.regular` glass
    behind it shows through the whole tile and a 4 pt rim around it.
  - So the selected tile becomes a slab of glass, under the preview and its title, with its adaptive
    tint, highlights and refraction of the Form row. It fills the tile instead of marking it.
  - In the Window Style picker, a glass slab around "Standard" reads as one more window style.
- **The in-progress edit isn't enough** (working tree, `SettingsView.swift:325-327`):
  - It replaces the background glass with `.glassEffect(isSelected ? .regular : .identity, in: shape)`
    on the tile itself, and the selected tile loses its fill.
  - Apple documents `glassEffect(_:in:)` as doing two things: it "renders a shape anchored behind
    a view with the Liquid Glass material" **and** "applies the foreground effects of Liquid Glass
    over a view". The view here is the preview and its name.
  - So the miniature of a window style is drawn with glass foreground effects (vibrancy) on a glass
    surface. That alters the very picture the tile exists to show, which is "floods the style
    itself" in a new form.
  - **[unverified on macOS 27]** how strongly the foreground effects change a `Canvas` drawing. The
    pixel test below decides it.
  - Both versions also break two CLAUDE.md rules:
    - Motion: the glass *moves* from tile to tile under `motion.crossfade` (`:295`), but CLAUDE.md
      says "`crossfade` is for opacity and colour only"; `change` moves things.
    - Glass: the working tree's version puts content (the preview) on glass, and "never
      `glassEffect` on content".
- **Change:** no glass in the picker. The accent outline (`:326`) already marks the choice, and
  System Settings → Appearance marks its tiles the same way: an outline, no glass. **[check on the
  M5]** Compare against a screenshot of System Settings → Appearance. Starting from `7bb2ac7`, or by
  reverting the in-progress hunk:
  1. `body` becomes the `HStack` alone:
     ```swift
     HStack(alignment: .top, spacing: 8) {
         ForEach(values, id: \.self) { value in
             tile(value)
         }
     }
     // Only the outline changes, so it crossfades, under Reduce Motion too.
     .animation(motion.crossfade, value: selection)
     .opacity(isEnabled ? 1 : 0.5)
     ```
  2. Delete the following. Every tile keeps `.fill.quaternary`.
     - `:328-332`, the `.background { … selectionGlass … }`;
     - `:339-351`, `selectionGlass` and its doc comment;
     - `:283`, the `@Namespace`;
     - `:357-358`, `glassOutset` and its comment.
  3. Replace the doc comment's second paragraph (`:270-273`) with:
     `/// The selected tile has an accent outline, as in System Settings → Appearance. No glass: the tiles are content in a form row, and glass behind or under a preview changes the picture it shows. The outline crossfades; the choice itself is set without animation.`
  4. Glass leaves `SettingsView.swift`, so the guards and docs follow:
     - `Tests/BatteryCoreTests/MotionGuardTests.swift:38-39`: remove the `SettingsView.swift` entry and
       its comment from `glassAllowList`.
     - `:491`: change it to `#expect(flags(glass, path: "BatteryPulseApp/Settings/SettingsView.swift"))`.
     - CLAUDE.md's Liquid Glass paragraph: drop "`Settings/SettingsView.swift` (the tile pickers'
       selection)" from the custom-glass list.
     - `docs/ROADMAP.md:20`: drop "the selection of the tile pickers in Settings".
  - About 25 lines fewer and no new string.
  - WP-9's SUI-13 split no longer has to carry an allow-list entry to a new shared-components file.
- **Measure:**
  - Linux: `swift test --filter MotionGuardTests` (the flipped `:491` and `allowListedFilesExist`
    pass) and `swift format lint --strict`.
  - **Pixel test on the M5** (the acceptance criterion for "doesn't flood the style"). In Settings →
    General, Light and Dark, read one point of the Clear tile's sky with Digital Color Meter twice:
    once with Clear unselected and once selected. The values must be identical.
    - Before (`7bb2ac7`, and the working tree's version) they differ, or the tile visibly changes.
    - After, they match.
    - Repeat on one Icon Style tile (Settings → Menu Bar).
  - Click through all four styles with full motion and with Reduce Motion: the outline crossfades,
    nothing moves, and the main window changes at once.
  - With "Battery icon" off, the Icon Style tiles are dimmed.
  - VoiceOver still reads "selected" on the chosen tile.
  - Show Borders draws every tile's edge.
- **Risk:** low. The change is visible: the glass selection from 0.5 goes. That is what the
  maintainer asked for, and it leaves custom glass only where CLAUDE.md can defend it: the floating
  Demo Mode bar and the window sheet.
  - If the maintainer still wants glass here, the pixel test above is the gate the design has to
    pass.
- **Owner:** WP-9 (it owns `SettingsView.swift`, the `MotionGuardTests` lists and CLAUDE.md's glass
  list). Do it before the SUI-13 split. **Rule:** "real bugs" (user-reported); CLAUDE.md Liquid
  Glass and Motion; native (the System Settings pattern).

### CH-13 [bug] Clear's dimming leaves white text unreadable over a bright window; the in-progress 0.40 / 0.32 still gives 2.4:1 / 2.0:1
- **Where** (outside this area's files; no work package owns them, see "Owner"):
  - `Sources/BatteryCore/WindowLook.swift:175-181` (`7bb2ac7`), `sheetTint(systemDark:)` for Clear:
    `systemDark ? Tint(white: 0.03, opacity: 0.22) : Tint(white: 1, opacity: 0.06)`. That is
    near-black 22 % in Dark and a *white* wash of 6 % in Light.
  - `Tests/BatteryCoreTests/WindowLookTests.swift:129-130` pin those values.
  - `:186-189` `contentTreatment`: halo 0.55 / 0.44 at radius 6; shadow 0.6 at radius 1.
  - `Sources/BatteryPulseApp/App/WindowLook.swift:95-103` `GlassSheet`: the dimming is the glass's
    own tint, `Glass.clear.tint(tint)` (`:101`), not a layer.
  - Clear's text is the system's hierarchical primary and secondary in the forced dark appearance
    (`ToneMap.swift:240-244`): white at about 85 % and 55 %. Tertiary text is off on the glass
    (`allowsTertiaryText`).
  - **The working tree** changes Clear to `Tint(white: 0.03, opacity: systemDark ? 0.32 : 0.4)`, with
    the tests and the user guide to match. The user guide now says "a dark dimming that keeps the
    white content readable".
- **The arithmetic.** It uses sRGB-space blending, which is how Core Animation composites by
  default, and WCAG 2 contrast.
  - The worst case is an ordinary one: a white page or window behind the BatteryPulse window. The
    backdrop under Clear's glass is then `(1 − α)·white + α·0.03`.
  - Reproduce with the 10-line Python in "Measure".

  | Clear's dimming | primary text (white 85 %) | secondary text (white 55 %) |
  |---|---|---|
  | `7bb2ac7` Light: white 6 % | **1.0:1** (white on white) | 1.0:1 |
  | `7bb2ac7` Dark: near-black 22 % | 1.55:1 | 1.34:1 |
  | working tree Dark: 32 % | 1.96:1 | 1.57:1 |
  | working tree Light: 40 % | 2.41:1 | 1.82:1 |
  | 50 % | 3.21:1 | 2.24:1 |
  | 60 % | 4.41:1 | 2.83:1 |
  | **65 %** | **5.22:1** | **3.21:1** |
  | 70 % | 6.22:1 | 3.66:1 |

  - WCAG AA asks for 4.5:1 for text and 3:1 for large or bold text.
  - At `7bb2ac7`, Clear in Light is white text on a white wash. That is the reported problem.
  - The in-progress values roughly double the contrast but stay below 3:1 even for primary text.
    The user guide's new "keeps the white content readable" would not be true over a bright window.
  - The halo doesn't close the gap. A 6 pt blur under a 1–2 pt glyph stroke puts only a fraction of
    its 0.55 peak under the stroke, and the 1 pt shadow helps the edges, not the fills.
  - **[unverified]** Apple documents `Glass.tint(_:)` as the glass's tint colour, not as a dimming
    layer, so the effective α may be lower than the number. Apple's guidance for the clear variant
    over bright content is a separate dimming layer.
- **Change** (on top of the in-progress edit):
  1. `WindowLook.swift` (BatteryCore), Clear: `case .clear: Tint(white: 0.03, opacity: 0.65)` in
     both appearances. The worst case, a white window behind, is the same in Light and Dark.
     - Replace the doc comment's Clear sentence with: "Clear's dimming is near-black 65 % in both
       appearances: the least that keeps its white text at 4.5:1 (primary) and 3:1 (secondary)
       over a white window behind (`WindowLookTests`)."
     - `WindowLookTests`: expect `Tint(white: 0.03, opacity: 0.65)` for both appearances.
     - Add this test, which fails at `7bb2ac7` and in the working tree (the file needs
       `import Foundation` for `pow`):
       ```swift
       /// White text over a white window behind Clear's dimming (sRGB blend, WCAG contrast).
       @Test(arguments: [false, true])
       func clearKeepsTextReadableOverAWhiteWindow(systemDark: Bool) throws {
           let tint = try #require(policy(.clear).sheetTint(systemDark: systemDark))
           func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
           let backdrop = (1 - tint.opacity) + tint.opacity * tint.white
           func contrast(text opacity: Double) -> Double {
               let text = opacity + (1 - opacity) * backdrop
               return (linear(text) + 0.05) / (linear(backdrop) + 0.05)
           }
           #expect(contrast(text: 0.85) >= 4.5)  // primary
           #expect(contrast(text: 0.55) >= 3.0)  // secondary
       }
       ```
  2. Make the number real: measure first, and change `GlassSheet` only if the measurement says so.
     - On the M5, put a Clear window over a white TextEdit page. Read the backdrop with Digital
       Color Meter (sRGB) in a gap between groups.
     - Expected: about 94 of 255 at α = 0.65, and about 156 at 0.40.
     - If the reading is more than about 10 above that, the glass tint is weaker than its number.
       Then draw the dimming as Apple's dimming layer. `GlassSheet` takes `Glass.clear` without a
       tint and adds `.overlay { if let tint { Rectangle().fill(tint) } }` before `.ignoresSafeArea()`.
     - Do that for Clear only: pass `dimsWithLayer: policy.effective == .clear` from
       `WindowBackground` (`:86`). Translucent keeps its glass tint, so its look doesn't change
       unasked.
  3. `docs/USER_GUIDE.md:149`, Clear:
     - "almost sharp" becomes "sharp but dimmed, so white text stays readable over bright windows";
     - drop "while the glass is a little lighter or smokier with the system appearance": it is the
       same in both now.
     - No UI string changes. The Settings footer ("The hardest to read, and uses more energy.")
       stays true.
- **Measure:**
  - Linux: `swift test --filter WindowLookTests`. The new test fails before (2.41 and 1.96 for
    primary text in the working tree, 1.0 at `7bb2ac7`) and passes after.
  - The table: `python3 -I -c` with `lin(c) = c/12.92 if c <= 0.04045 else ((c+0.055)/1.055)**2.4`,
    `bg = (1-a) + a*0.03`, `text = t + (1-t)*bg`, `(lin(text)+0.05)/(lin(bg)+0.05)`.
  - On the M5, test Overview, Power, History, Health and one device page in Clear, Light and Dark,
    over a white TextEdit page and over a busy photo wallpaper:
    - Accessibility Inspector → Audit → Contrast on each page, before and after: fewer contrast
      warnings after.
    - Screenshots for the maintainer's OK.
  - The Digital Color Meter reading from step 2.
  - S4w (playbook §2.4): a plain fill adds no blur pass, so expect no change in Clear's energy or
    hitches.
- **Risk:** medium, and only visual. Clear becomes clearly darker. The desktop still shows through
  sharp, at 35 % of its brightness.
  - If the maintainer wants more desktop between groups, there is an alternative:
    - Keep the sheet at 0.40 and add a near-black plate at 0.42 under each group
      (`Card`/`CardGroup`/`LookForm` in Clear).
    - That gives `1 − 0.60 × 0.58 = 0.65` under the content and 0.40 in the gutters.
    - But a plate is a surface, which Clear's design avoids today (`groupSurface == .none`), and it
      touches `Main/`.
  - Either way, the contrast test pins the floor.
- **Owner:** unowned. Playbook §3.2 lists neither `BatteryCore/WindowLook.swift` nor
  `App/WindowLook.swift`. Give it to WP-9, which already re-measures the four styles' screens (S4w),
  or to a one-item package before Phase B. **Rule:** "real bugs" (user-reported); CLAUDE.md
  "Content stays free of glass and materials" (the fix is a plain fill, not more glass).

### CH-14 [readability] The window-style tiles copy the policy's tints by hand; keep the in-progress change that reads them
- **Where:** `Settings/WindowLookSettings.swift:150-159` (`7bb2ac7`).
  - The Translucent tile is `isDark ? .black.opacity(0.45) : .white.opacity(0.45)` (`:155`) and the
    Clear tile is `isDark ? Color(white: 0.03).opacity(0.22) : .white.opacity(0.06)` (`:158`), both
    by hand.
  - At `7bb2ac7` they match `WindowLookPolicy.sheetTint` only by copy. Any change to Clear, such as
    the in-progress edit or CH-13, leaves the tile showing the old, lighter Clear.
  - The working tree already replaces both literals with
    `WindowLookPolicy(setting: look, reduceTransparency: false, increaseContrast: false).sheetTint(systemDark: isDark)`
    (working-tree `:150-162`). That is the right change. The override is left out because the tile
    shows the style as chosen, and `isDark` is the system appearance, which Settings keeps.
- **Change:** keep that hunk when the in-progress edit is committed. If it is dropped, make the same
  change. Ten lines, no new string. The marks' 1.5 pt shadow (`:107-110`) stays: it is a miniature
  of the real halo, not a copy.
- **Measure:**
  - The Mac build compiles (CI macOS job).
  - On the M5, Settings → General, Light and Dark: the Clear tile's sky darkens along with each
    change to `sheetTint` (in-progress values, then CH-13's), with no edit to this file.
  - The Standard, Frosted and Translucent tiles are pixel-identical to 0.6.0 in screenshots.
- **Risk:** none; the preview is a static `Canvas`.
- **Owner:** WP-9. **Rule:** readability (a value duplicated by hand).

## P2

### CH-08 [bug] The menu bar label's lifecycle modifiers sit on a `Group`, so one item disappearing stops the power poll
- **Where:** `MenuBar/MenuBarLabel.swift`.
  - `:28-40`: `Group { if demo.isActive { Image } ; if content.showsIcon(title:) { icon } ; if !title.isEmpty { Text } }`.
    It has 1 to 3 members, and which ones exist changes at run time.
  - `:47` `.onAppear { WindowOpener.openWindow = openWindow }`, `:48-51`
    `.onChange(of: content.liveRefreshInterval, initial: true) { monitor.setLiveRefreshInterval(interval, for: "menuBar") }`,
    `:52` `.onDisappear { monitor.setLiveRefreshInterval(nil, for: "menuBar") }`, all applied to that `Group`.
  - Apple's `Group` page (fetched to `v061/chrome/group.json`): "The modifier applies to all members
    of the group — and not to the group itself. For example, if you apply `onAppear(perform:)` to the
    above group, it applies to all of the views produced by the `if isLoggedIn` conditional, and it
    executes every time `isLoggedIn` changes." So each member gets its own `onAppear`,
    `onChange(initial:)` and `onDisappear`.
  - `MenuBarContent.liveRefreshInterval` (`Sources/BatteryCore/MenuBarContent.swift:90-92`) depends
    only on `.power`. `BatteryMonitor.setLiveRefreshInterval` (`Sources/BatteryKit/BatteryMonitor.swift:80-90`)
    keeps one request per client, so a `nil` from any member removes the label's request.
- **Failure scenario** (no BatteryPulse window open, menu bar set to icon + power, so the label is the
  only poll client):
  1. Settings → Menu Bar → turn "Battery icon" off. The icon member disappears, its `onDisappear`
     sends `nil` for `"menuBar"`. The `Text` member stays, and its `onChange` doesn't fire because
     the interval is still 10 s. The 10 s poll stops; the watts in the menu bar change only when an
     IOPS notification happens to trigger a read.
  2. The same when Demo Mode stops (the demo `Image` member disappears).
  3. With the icon turned off, a reading whose title is empty (no snapshot yet, or no value for any
     chosen item) makes `showsIcon(title:)` add the icon member as a fallback; the next full reading
     removes it again, and its `onDisappear` sends `nil`. Whether that `nil` lands before or after
     the `Text` member's `onChange(initial:)` is up to SwiftUI's ordering.
  - The popover (2 s) and the main window mask it while they are open, which is why it can go
    unnoticed. It heals only when a member appears again (its `onChange(initial: true)` re-sends 10 s).
  - Related: WP-0 plans the `menuBarReady` signpost at "first `MenuBarLabel` appearance" (playbook
    §2.2, WP-0 touches). As an `.onAppear` on this `Group` it would fire once per member and again
    each time a member appears.
- **Change** (keeps `Group`, which the status item needs to flatten an image and a text; no `HStack`):
  1. Delete `.onDisappear` (`MenuBarLabel.swift:52`). Above `.onAppear` (`:47`) add the comment
     `// A modifier on a Group runs for each member: these two are idempotent, and the request ends with the scene (BatteryPulseApp).`
     Both remaining handlers are idempotent: the same `openWindow`, and the same interval for the
     same client (`isNewRequest` is false after the first call, `effective` doesn't change, so no
     extra read and no reschedule).
  2. In `App/BatteryPulseApp.swift`, after `.menuBarExtraStyle(.window)` (`:111`), end the request
     with the menu bar item, through `Scene.onChange(of:initial:_:)`:
     ```swift
     .onChange(of: showInMenuBar) { _, isShown in
         if !isShown { monitor.setLiveRefreshInterval(nil, for: "menuBar") }
     }
     ```
     Turning the item back on recreates the label, and its `onChange(initial: true)` asks again.
  3. WP-0's `menuBarReady`: emit it behind a `static var` once-flag (the pattern of
     `AppIconView.hasDrawnIn`), not as a bare `.onAppear` on the `Group`.
- **Measure:** on the M5, with WP-0's `refresh` signposts (`trigger: poll`) in Instruments → Points of
  Interest, or before WP-0 a `#if DEBUG print(client, interval)` in `setLiveRefreshInterval`. No
  window open, menu bar icon + power:
  - Baseline: one `poll` refresh about every 10 s.
  - Turn "Battery icon" off in Settings, close Settings, wait 60 s. Before: `nil` for `"menuBar"`
    is logged and the `poll` refreshes stop. After: no `nil`, about six `poll` refreshes.
  - Start Demo Mode, stop it from the popover, close all windows: the same before/after.
  - Turn "Show in menu bar" off: after the change, exactly one `nil` and no further `poll`
    refreshes (S1 idle energy unchanged from 0.6.0). Turn it on: one 10 s request, polls resume.
  - Welcome, About, Software Update and Settings still open from the Dock menu right after launch
    (`WindowOpener.openWindow` is still captured).
  - If the first "Before" step does not reproduce on macOS 27 (the status item host would then not
    distribute lifecycle modifiers), keep step 3 and drop steps 1–2.
- **Risk:** low. The only behaviour change is when the request ends: with the item's removal instead
  of with a label member's disappearance. The label also disappears at quit, where the request no
  longer matters.
- **Owner:** WP-2 (owns `MenuBarLabel.swift` and the live-refresh plumbing), with a 3-line hunk in
  WP-4's `BatteryPulseApp.swift`; step 3 is WP-0. Raise to P1 if the first "Before" step reproduces.
  **Rule:** "real bugs"; EN-6 (the poll's lifetime follows what is visible).

### CH-01 [readability] A hard-coded animation outside `Motion.swift`, which `MotionGuardTests` doesn't catch
- **Where:**
  - `Welcome/AppIconView.swift:83-89`: `extension MotionPolicy { fileprivate var iconDrawIn: Animation? { allowsFlourish ? .smooth(duration: 0.8).delay(0.2) : nil } }`.
  - CLAUDE.md, Motion: "no hard-coded animation outside `Motion.swift`".
  - `App/Motion.swift:31-45`: the preset table lists every other preset; `iconDrawIn` is missing.
  - Checked by grep over `Sources/BatteryPulseApp` and `Sources/BatteryPulseWidget`
    (`\.(smooth|spring|snappy|bouncy|easeIn|easeOut|easeInOut|linear|interactiveSpring|interpolatingSpring)\b`
    outside `Motion.swift`): this is the **only** animation built outside `Motion.swift`. The
    other hits are `.progressViewStyle(.linear)` (`Updates/UpdateViews.swift:80, 159, 164, 169`) and
    `motion.linear(…)` (`App/DemoController.swift:231`).
  - Why the guard misses it: `Tests/BatteryCoreTests/MotionGuardTests.swift:149-162` only inspects
    the *arguments* of `withAnimation(…)` and `.animation(…)`. `withAnimation(motion.iconDrawIn)`
    (`AppIconView.swift:79`) goes through `motion`, and the constructor sits in a property elsewhere.
- **Change:**
  1. Move the property, unchanged, into `App/Motion.swift` after `quickFade`, without `fileprivate`.
     Add a table row: `| ``iconDrawIn`` | smooth, 0.8 s after 0.2 s, once | `nil` | `nil` |`.
     Delete `AppIconView.swift:83-89`.
  2. In `MotionGuardTests`, inside `if !buildsPresets` (`:150`), flag an `Animation` built from
     scratch: `#/(?:^|[^\w)\]])\.(?:smooth|snappy|bouncy|spring|interactiveSpring|interpolatingSpring|easeIn|easeOut|easeInOut|linear|timingCurve)\s*\(/#`
     plus `words(#/\bAnimation\s*\.\s*[a-z]/#)`.
     - The leading class keeps `motion.linear(0.2)` and `.progressViewStyle(.linear)` legal.
     - It avoids a lookbehind; the existing rules use only lookaheads.
  3. Add one case to `catches(source:)`: `"var a: Animation? { on ? .smooth(duration: 0.8).delay(0.2) : nil }"`.
     Add two cases to `allows(source:)`: `".progressViewStyle(.linear)"` and
     `"withAnimation(motion.linear(0.2)) { x = 1 }"` (the second is already there, `:459`).
- **Measure:**
  - Linux: `swift test --filter MotionGuardTests`.
    - Before the move, the new rule flags `AppIconView.swift:87`. After the move, it passes.
    - `allowListedFilesExist` still passes.
  - On the M5, the welcome window: the pulse line draws in once per launch with full motion. It
    doesn't draw in under Reduce Motion or Low Power Mode, or on the second opening.
- **Risk:** none at run time; the property moves without changing. The new regex could flag a
  future legitimate use, such as a `ProgressView` style named like an animation followed by `(`.
  The `allows(source:)` cases pin the known ones.
- **Owner:** WP-12 (guards). The 7-line move goes with it; no other package edits `AppIconView.swift`.
  **Rule:** UI-13 *(existing)*, CLAUDE.md Motion.

### CH-02 [bug] **PLAUSIBLE**: lifecycle and presentation modifiers sit on `Section`s, so they may run once per row
- **Where** (`Settings/SettingsView.swift`):
  - `:137-140`: `.onAppear { launchAtLogin.refresh() }` and `.onReceive(didBecomeActiveNotification)`
    on the Section at `:105`. It has **3 rows**: the "Open at login" `VStack` (`:106`), the
    "Window to open" `Picker` (`:131`) and the welcome `Toggle` (`:135`).
  - `:420-428`: `.task { isDenied = … }` and `.onChange(of: [chargeLimit, …])`. The latter starts a
    `requestAuthorization` `Task`. They sit on the Section at `:401`, which has **1 or 2 rows**: 2 in
    the denied branch, a `Text` and a `Button`.
  - `:460-470`: `.confirmationDialog(isPresented: $confirmsClearing)` on the Section at `:441`, which
    has **2 rows**: the `Toggle` and the `LabeledContent`.
- **Why it matters:**
  - Apple documents for `Group` that "any modifier you apply to the group affects all of that
    group's members" (`developer.apple.com/documentation/swiftui/group`, fetched to
    `v061/chrome/group.json`). The `Section` page says nothing either way.
  - The same page's example says it outright for `onAppear(perform:)`: on a `Group` it "applies to
    all of the views produced by the" conditional "and it executes every time" the condition changes.
    CH-08 is the documented `Group` case in this area.
  - Inside `Form` and `List`, a `Section`'s content is flattened into rows the same way. That is
    why `.listRowBackground` and `.listRowSeparator` on a `Section` reach every row.
  - **[unverified on macOS 27]** whether `onAppear`, `onReceive`, `task`, `onChange` and
    `confirmationDialog` are distributed too. If they are:
    - `refresh()` runs 3× per appearance and per app activation, which with AC-03's two
      `SMAppService.status` reads is 6 XPC reads. With the Welcome window also open (it embeds
      `GeneralSettings` too), it is 12.
    - Each toggle of an alert starts up to 2 authorization tasks.
    - Two dialog presenters share one binding.
- **Change:** attach each modifier to one concrete view that always exists. Each move is a cut and
  paste:
  - `:137-140` → the "Open at login" `VStack` (close of `:130`), the row whose state it refreshes.
  - `:460-470` → `Button("Clear History…", role: .destructive)` (`:446`). This is Apple's documented
    placement: the control that presents the dialog.
  - `:420-428` → the first section's `Picker("When charged to", …)` (`:378-381`), with the comment
    `// On one row: a modifier on a Section applies to each of its rows.` Leave `isDenied` where it is.
- **Measure:** on the M5 with a debug build in Xcode 27, before and after. Use symbolic breakpoints
  that log and continue.
  - `-[SMAppService status]`: open Settings, then switch to Finder and back. Expect 6 → 2 per
    activation if the modifiers were distributed; 2 → 2 if not. Either way the code is clearer.
  - `-[UNUserNotificationCenter getNotificationSettingsWithCompletionHandler:]` on opening the
    Notifications tab, and `requestAuthorizationWithOptions:completionHandler:` when "When the Mac
    gets hot" is turned on.
  - Clear History… shows one dialog. Cancel leaves the history. Clear History empties the charts
    once (a breakpoint on `HistoryStore.clear`).
  - Login item, notification and Clear History behave as in 0.6.0.
- **Risk:** none. Each modifier keeps its trigger and its owner. If `Section` doesn't distribute,
  the change is behaviour-neutral.
- **Owner:** WP-9 (it splits this file anyway; do it in the same commit as the split, or just
  before it). **Rule:** "real bugs"; supports AC-03.

## P3

### CH-03 [bug] The Notifications pane keeps saying notifications are off after the user allows them
- **Where:** `Settings/SettingsView.swift:405-408` and `:420`.
  - `isDenied` is read once, by `.task` when the pane appears, and again after a toggle or a test
    notification.
  - The pane's own button sends the user to System Settings (`AppLinks.notificationSettings`).
    Coming back doesn't re-read the setting, so "Notifications are turned off for BatteryPulse in
    System Settings." stays until the user switches tabs or reopens Settings.
  - `GeneralSettings` handles the same round trip for Login Items with `didBecomeActiveNotification`
    (`:138-140`).
- **Change:** next to the `.task` (on the row CH-02 picks), add the same documented modifier
  `GeneralSettings` uses (SUI-20 keeps it):
  ```swift
  .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      Task { isDenied = await BatteryNotifier.isDenied() }
  }
  ```
  No new string; `isDenied()` (`App/BatteryNotifier.swift:209-212`) is unchanged.
- **Measure:** on the M5 (packaged app):
  1. Turn BatteryPulse's notifications off in System Settings → Notifications.
  2. Open Settings → Notifications; it shows the "turned off" text.
  3. Click Open Notification Settings, allow notifications, then click back into BatteryPulse's
     Settings window.
  - Before: the text stays. After: "Send Test Notification" appears without a tab switch.
  - Repeat in the other direction (allow → deny).
- **Risk:** one `getNotificationSettings` XPC per app activation, and only while the Notifications
  tab is on screen: the subscription ends with the view.
- **Owner:** WP-9. **Rule:** "real bugs".

### CH-04 [readability] The popover captures `openWindow` in two buttons but not in the third
- **Where:**
  - `MenuBar/PopoverView.swift:63` and `:68` assign `WindowOpener.openWindow = openWindow` before
    `showMainWindow()` and `show(WindowID.about)`.
  - `UpdateAvailableRow` (`:118`) calls `WindowOpener.show(WindowID.update)` without it.
  - The label assigns it on appear (`MenuBar/MenuBarLabel.swift:47`), and the panel can only open
    from the label. So the two assignments are redundant, or, if they are a deliberate backup, the
    third button lacks it.
- **Change:** one `.onAppear { WindowOpener.openWindow = openWindow }` on the panel's root `VStack`,
  next to `.liveRefresh` (`:101`). Delete the two per-button lines. This keeps a backup capture for
  all three buttons; the app-core audit decided to keep `WindowOpener` itself.
- **Measure:** on the M5, from the panel: Open BatteryPulse (full and compact preference), About,
  Settings and an Update available row (Demo Mode, or a test build with a pending release). Each
  opens its window, also right after launch with no window opened before.
- **Risk:** none.
- **Owner:** WP-9. **Rule:** readability (duplicated logic).

### CH-05 [dead-code] `MenuBarIconPreview`: two parameters nobody passes, and a snapshot built only for a symbol name
- **Where:** `MenuBar/BatteryIconView.swift:238-262`.
  - `var state = BatteryIconState.sample` (`:240`) and `var magnification: CGFloat = 1.5` (`:241`).
    The one caller (`Settings/SettingsView.swift:245`) passes neither `state:` nor the default
    magnification; it always passes `PreviewTile.iconMagnification` (2.5). Checked by grep over
    `Sources` and `Tests`.
  - `:249-253` builds a `BatterySnapshot(timestamp: .now, …)` to call `symbolName(for:)`. BatteryCore
    already has `BatteryPresentation.symbolName(percent:state:)`
    (`Sources/BatteryCore/BatteryPresentation.swift:12`). `symbolName(for:)` only forwards to it.
- **Change:**
  - `private let state = BatteryIconState.sample` and `let magnification: CGFloat`, with no default.
  - Replace `:249-253` with
    `Image(systemName: BatteryPresentation.symbolName(percent: state.level * 100, state: state.glyph == .bolt ? .charging : .discharging))`.
- **Measure:** Settings → Menu Bar shows the same tiles, the SF Symbol tile included: a 75 % battery
  for `sample` (level 0.7 → 70 → `battery.75percent`). Lint passes.
- **Risk:** none.
- **Owner:** WP-11 (dead code) or WP-9. **Rule:** DC-6, readability.

### CH-06 [security] Clear History swallows a failure
- **Where:** `Settings/SettingsView.swift:463-466`: `try? await AppHistory.store.clear()`.
  - If the store can't delete its files, the user sees the charts start over in memory, but nothing
    says so, and nothing is logged.
  - SW-R12: unexpected failures at I/O boundaries are logged.
- **Change:** after WP-0's `Diagnostics.swift`:
  `do { try await AppHistory.store.clear() } catch { Log.history.error("Clear History failed: \(error, privacy: .private)") }`.
  - The error text can contain a path, so it stays private (SW-R10).
  - The device clear (`:465`) still runs, as today.
- **Measure:** on the M5, `chmod a-w` the history `samples` folder, then Clear History. `log stream
  --predicate 'subsystem == "io.github.nikitausov.BatteryPulse" AND category == "history"'` shows
  one error with `<private>`. Restore the permission afterwards.
- **Risk:** none.
- **Owner:** WP-4 (it owns the `history` logger and SW-12), with a one-hunk touch in WP-9's file.
  **Rule:** SW-R12, SW-R10.

### CH-07 [native] The widget's placeholder is the "No battery information" state
- **Where:** `Sources/BatteryPulseWidget/BatteryPulseWidget.swift:37-39`:
  `placeholder(in:)` returns `BatteryEntry(date: .now, snapshot: nil)`.
  - The view renders `nil` as the error layout (`:84-94`): a `battery.0percent` symbol and "No
    battery information".
  - WidgetKit shows the placeholder, redacted, while the widget loads. Apple's `placeholder(in:)`
    documentation asks for a placeholder version of the widget, not an error state. So a loading
    widget flashes the error layout as grey blocks.
- **Change:** return a representative entry:
  `BatteryEntry(date: .now, snapshot: BatterySnapshot(timestamp: .now, chargePercent: 70, chargeState: .discharging))`.
  - It is the same initializer `MenuBarIconPreview` uses today, and 70 % matches
    `BatteryIconState.sample`.
  - `getSnapshot` and `getTimeline` keep reading IOKit, so the gallery still shows real values.
- **Measure:** on the M5, add the widget from Edit Widgets, small and medium. The loading flash shows
  the redacted charge layout (symbol, number, two lines), not the "No battery information" layout.
  After the first timeline, it shows the same as 0.6.0. A Mac without a battery still shows "No
  battery information", because that comes from `getTimeline`.
- **Risk:** none; it only changes what shows during loading. **[unverified]** how long macOS 27
  shows a placeholder.
- **Owner:** WP-9 (view structure). It adds no string. **Rule:** native.

### CH-09 [readability] The menu bar choices are declared twice, with defaults that must match
- **Where:**
  - `MenuBar/MenuBarLabel.swift:12-17` and `:20-23`: five `@AppStorage` (`menuBarShowsIcon`,
    `…Charge`, `…Power`, `…Temperature`, `menuBarIconStyle`) and the `content` builder.
  - `Settings/SettingsView.swift:209-214` and `:216-219`: the same five declarations, the same
    defaults, the same builder, and the same comment ("The defaults of MenuBarContent: the icon and
    the charge.").
  - The only other user of the keys is `AppSettings.migrate()` (`App/AppSettings.swift:107-118`),
    which writes them and reads none. Checked by grep over `Sources`.
- **Change:** one SwiftUI `DynamicProperty`, the framework's own way to share a group of stored
  settings between views, below `MenuBarLabel`:
  ```swift
  /// The menu bar items and icon style, as the label and Settings read them.
  struct MenuBarChoices: DynamicProperty {
      // The defaults of MenuBarContent: the icon and the charge.
      @AppStorage(AppSettings.menuBarShowsIconKey) var showsIcon = true
      @AppStorage(AppSettings.menuBarShowsChargeKey) var showsCharge = true
      @AppStorage(AppSettings.menuBarShowsPowerKey) var showsPower = false
      @AppStorage(AppSettings.menuBarShowsTemperatureKey) var showsTemperature = false
      @AppStorage(AppSettings.menuBarIconStyleKey) var iconStyle = MenuBarIconStyle.default

      var content: MenuBarContent {
          MenuBarContent(
              showsIcon: showsIcon, showsCharge: showsCharge, showsPower: showsPower, showsTemperature: showsTemperature)
      }
  }
  ```
  - `MenuBarLabel`: `private var choices = MenuBarChoices()`; `choices.content`, `choices.iconStyle`.
  - `MenuBarSettings`: the same property; `Toggle("Battery icon", isOn: choices.$showsIcon)` and so on;
    `PreviewTilePicker(selection: choices.$iconStyle, …)`.
  - About 12 lines fewer, one place for the defaults. No new string.
- **Measure:**
  - Settings → Menu Bar: each toggle and icon style changes the status item at once; the last item on
    stays disabled.
  - `defaults delete io.github.nikitausov.BatteryPulse` then launch: icon + percentage, as in 0.6.0.
  - SUI-07's body counts for `MenuBarLabel` per tick don't rise (the property only adds the same
    five `UserDefaults` observations).
- **Risk:** low. A `DynamicProperty` must be a stored `var` in the view for SwiftUI to install its
  `@AppStorage`; a `let` or a computed property would silently stop updating. Drop this item if WP-9
  prefers no new type.
- **Owner:** WP-2 (`MenuBarLabel.swift`) defines it; WP-9 adopts it in the Settings split.
  **Rule:** readability (duplicated logic).

### CH-10 [readability] The Notifications pane watches an ad-hoc `[Int]` with Bools coded as 0/1
- **Where:** `Settings/SettingsView.swift:421`:
  `.onChange(of: [chargeLimit, lowBattery, accessoryLow, service ? 1 : 0, heat ? 1 : 0])`, then
  `guard AppSettings.alerts.isAnyEnabled` (`:423`) reads the same five defaults again.
  - `AppSettings.alerts` (`App/AppSettings.swift:63-75`) already maps the five values to
    `AlertSettings`, which is `Equatable` (`Sources/BatteryCore/BatteryAlerts.swift:16`) and has
    `isAnyEnabled` (`:37-39`).
- **Change:** `.onChange(of: AppSettings.alerts) { _, alerts in guard alerts.isAnyEnabled else { return } … }`,
  the `Task` body unchanged. The body re-runs on each of the five `@AppStorage` changes, so the value
  is read after the write. Move it with CH-02's placement.
- **Measure:** same triggers as before: turning any alert on (or changing a threshold while one is
  on) asks for authorization once; turning the last one off asks nothing. In a new macOS user
  account (no permission asked yet), turning on "When the Mac gets hot" shows the system prompt once.
- **Risk:** none: `AlertSettings` changes exactly when the array did (0 ↔ `nil` maps one to one).
- **Owner:** WP-9. **Rule:** readability.

### CH-11 [readability] The welcome window repeats `SettingsPage`'s form setup
- **Where:** `Welcome/WelcomeView.swift:32-37`
  (`Form { GeneralSettings() }.formStyle(.grouped).scrollDisabled(true).fixedSize(horizontal: false, vertical: true)`)
  repeats `SettingsPage` (`Settings/SettingsView.swift:32-41`) modifier for modifier. `SettingsPage`
  is `private`, so the welcome window can't use it.
- **Change:** drop `private` from `SettingsPage`; `WelcomeView` uses `SettingsPage { GeneralSettings() }`.
  With SUI-13's split, `SettingsPage` goes to the shared-components file with `Crossfade` and
  `PreviewTilePicker`. The two windows that embed `GeneralSettings` then size it one way.
- **Measure:** screenshots of the welcome window (600 pt wide) and Settings → General before and
  after, light and dark, English and Russian: identical. The welcome window still doesn't scroll.
- **Risk:** none.
- **Owner:** WP-9. **Rule:** readability (duplicated logic).

---

## Checked, no change proposed

- **Menu bar icon cost.** `MenuBarIconRenderer.image` (`BatteryIconView.swift:280-301`) is called on
  every label body. It is keyed on `(style, state, scale)`. `state.level` comes from
  `Current Capacity / Max Capacity`, which is in whole percent on Apple Silicon
  (`MacPowerParser.swift:155-158`), so `ImageRenderer` runs at most once per percent or state change
  (twice while red or yellow). The adaptive image's drawing handler only draws a cached `CGImage`.
  `NSScreen.screens` per call is cheap. Keep.
- **`DigitOutlines` builds two `CTFont`s per render** (`:105-110`). This happens only on a cache
  miss, as above. Not worth a static cache.
- **Label body work** (`MenuBarLabel.swift:25-53`):
  - `content` is rebuilt three times and `Phrases.batteryIcon` runs one `String(localized:)` per
    snapshot change. That is microseconds, at most every 10 s with power shown.
  - SUI-06 removes the two formatter builds; nothing else is worth changing.
  - The label has no animation (`MotionGuardTests.menuBarLabelFiles`).
- **Popover accessory rows** (`PopoverAccessories.swift`):
  - `String(localized:)` per part (`:85`) and `Phrases.accessoryName` per row run only when the
    `[AccessoryBattery]` value changes: it is `Hashable`, so SwiftUI skips the subtree on the 2 s
    poll.
  - `ForEach(accessory.parts, id: \.role)` is safe: `AccessoryParser.accessories(from:)` keeps one
    part per role (`AccessoryParser.swift:55-57`).
  - `AccessorySymbols.isAvailable` caches its lookups.
- **`UpdateAvailableRow`'s `.task(id:)` with no `await`** (`PopoverView.swift:124-129`):
  - The 2027 SDK runs it synchronously (SUI-22), which is what it wants: the bounce key changes
    right after the row appears.
  - `onChange(initial: true)` could change in the same update as the insertion, and the bounce might
    not play. Keep.
- **Settings button in the popover** (`:75-82`): `SettingsLink` can't run `prepareToShowWindow()` or
  `NSApp.activate()`, and an `LSUIElement` app needs both. Keep `openSettings()`.
- **"Last checked …"** (`SettingsView.swift:157`) doesn't tick while Settings stays open.
  `Text(date, style: .relative)` would tick, which costs a timeline for no real need, and it would
  change the localized key. Keep.
- **`PreviewTilePicker`**: buttons with `.isSelected` are announced correctly. An
  `accessibilityRepresentation { Picker … }` would change the VoiceOver experience without a
  reported problem. Keep. (The glass selection does not stay: CH-12.)
- **`WindowLookPreview`**: four static `Canvas` drawings, two with a blur filter. They are redrawn
  only on an appearance change. Keep.
- **`AppIconView`**:
  - The SwiftUI drawing exists for unbundled runs and has to keep matching `AppIcon.svg` (SZ-10).
  - `IconColor`'s computed `static var`s are trivial.
- **Duplicated alert defaults:** every `@AppStorage` default in the area matches the other
  declarations of the same key and `AppSettings`' readers (checked by grep: `showInMenuBar` ×4 true,
  menu bar items ×2, `readDevices` ×2, `showDeveloper` ×2).
- **Widget:**
  - `state(_:)` repeats `Phrases.state`'s switch (`BatteryPulseWidget.swift:166-176`), because the
    widget can't import the app target. Moving the key choice into BatteryCore would still need a
    `String(localized:)` switch in each target. Keep.
  - `time(_:)` uses `entry.date` as the reading time. That is correct because
    `WidgetTimelinePlan` only sets `showsEstimate` on the entry dated at the read
    (`BatteryPresentation.swift:189-204`).
  - The `Task { @MainActor in }` hops are needed (see above). `BatteryFormatter()` there shows only
    percent and °C, so it needs no localized unit symbols.
- **Energy:**
  - The area has no timer, sleep, `DispatchQueue` or polling of its own.
  - The popover's 2 s poll and the label's 10 s poll go through `liveRefresh` /
    `setLiveRefreshInterval` (WP-2: E5–E7).
  - The welcome icon's draw-in plays once per launch.
- **Other `Group`s in the area:** `MenuBarIconPreview` (`BatteryIconView.swift:245-260`) has one member
  at a time and only a `.frame` on it; the menu bar label's `.transaction` (`MenuBarLabel.swift:43-46`)
  is meant to reach each member. Neither needs a change; only CH-08's lifecycle modifiers do.
- **Setting defaults outside the first pass's list:** `updateFrequency` (daily, matching
  `UpdateFrequency.stored(nil, …)`), `showWelcomeAtLaunch`, `prefersCompactWindow`, `windowLook`
  (×2, `.standard`), the five alert keys (0/false, matching `AppSettings.alerts`) and
  `recordHistory` (true, matching `AppSettings.recordsHistory`). All consistent.
- **`BatteryNotifier` calls from Settings** (`SettingsView.swift:402-427`): `isDenied()`,
  `requestAuthorization()` and `sendTest()` all return early when `isAvailable` is false
  (`App/BatteryNotifier.swift:204-216`), so an unbundled `swift run` never touches
  `UNUserNotificationCenter.current()`. Keep.
- **Widget tint** (`BatteryPulseWidget.swift:158-164`) repeats the app's level colours; it can't import
  the app target and BatteryCore must stay free of SwiftUI. Keep.
