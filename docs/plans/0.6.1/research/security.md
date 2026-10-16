# BatteryPulse 0.6.1: security, privacy and native platform integration (verified)

Verified 2026-10-15 by an adversarial pass over `v061/security/research.md`. Scope: macOS 27, Swift 6.4,
Xcode 27, an ad-hoc signed DMG outside the App Store, no notarization. Code read at `fb41ff5` (branch
`claude/nice-faraday-k08mhb`), plus the `wip/devices` branch for the 0.6.0 device work. This file is
standalone and replaces `research.md` for planning.

**Method.**
- Every cited file was opened at the cited lines.
- Every cited Apple page was checked in the local JSON or text copies in `v061/security/dl/`. The two
  entitlement pages whose platform lists decide SEC-08 were fetched again live (`v061/security/vdl/`).
- WWDC quotes were matched against the transcripts. GitHub's lockfile page was fetched live.
- Cross-checked against the sibling verified research: `v061/swift/verified.md` (SW-12 logging, SW-13
  strict memory safety), `v061/energy/verified.md` (E10 URLSession, E11 install activity) and
  `v061/size/research.md` (SZ-01 strip, SZ-02 exports, SZ-03 ULMO DMG).

**Legend.** Priorities: **P0** must do in 0.6.1, **P1** should, **P2** if time allows, **P3** later or
optional. Effort: S is under half a day, M is 1–2 days, L is more.
- **[unverified-27]**: no source confirms it for macOS 27 / Swift 6.4. Check it on the M5 first.
- Verdicts: **KEEP** (holds as written), **CORRECTED** (holds after the change described), **REWRITTEN**
  (the problem is real but the fix was wrong), **REJECTED**, **NEW** (missed by the research).

---

## 0. Verdicts at a glance

| ID | Topic | Research | Verdict | Now | Why |
|----|-------|----------|---------|-----|-----|
| SEC-01 | Browser fallback for updates | P1 | **REWRITTEN** | **P1** | GitHub builds `browser_download_url` and `html_url` itself, so an attacker without the key can't point them off the repository. The real gap: after `.badSignature` (or for a newer release with no `.sig`), the window recommends **Download** of that same DMG as the default button. Pinning exact URL prefixes would also stop in-app updates after a repository rename. |
| SEC-02 | Release-notes links | P1 | **CORRECTED** | P2 | Holds (OpenURLAction covers links in attributed strings). Allow `https` on any host; a github.com-only rule adds nothing. Notes stay editable even on immutable releases, which makes the check worth having. |
| SEC-03 | Ephemeral URLSession | P1 | **CORRECTED** | P2 | Holds. `waitsForConnectivity = true` would hang **Check Now**, which waits for a running automatic check (UpdateChecker.swift:83–86). Same item as E10. The privacy gain is small, because the cached data is public JSON. |
| SEC-04 | Runtime code requirement | P2 | **REJECTED** (folded into SEC-07) | — | Duplicates `checkBundle`. Strict validation already binds Info.plist to the seal, and the release mistakes it targets are cheaper to catch at build time. |
| SEC-05 | Key list for rotation | P2 | **KEEP** (trimmed) | P2 | Holds. Do it together with SEC-01, which turns a key mismatch into a hard stop. Drop the manifest-format change. |
| SEC-06 | Release pipeline | P2 | **CORRECTED** | P2 | Moving `contents: write` to the only job changes nothing. Missing: `ci.yml` has no `permissions:` block, and `persist-credentials: false` isn't set. The lockfile is a **public preview** (`gh actions-lock`). |
| SEC-07 | Signing posture as an invariant | P1 | **KEEP** (extended) | **P1** build check / P2 guard test | Holds. Add the Info.plist invariants. Drop the unenforceable "no `.public` on paths" rule. |
| SEC-08 | Enhanced Security entitlements | P2 | **CORRECTED** | P2 spike, gated | Quotes verified. The live `checked-allocations` page still lists only iOS and iPadOS. If AMFI refuses the new version after the swap, the in-app update leaves a dead app behind, so qualifying needs an end-to-end in-app update on the M5. |
| SEC-09 | Defensive `dlopen` | P2 | **CORRECTED** | P3 (version capture P2 with 0.6.0) | `RTLD_FIRST`/`RTLD_LOCAL` are hygiene with no measurable security gain (constant absolute paths, unique `AM*` names). The framework version in diagnostics is useful. Drop the `dladdr` assertion. |
| SEC-10 | MobileDevice out of process | P2 / P1 if in-app | **KEEP** (condition met) | P2, promote on evidence | `wip/devices` reads devices in the app. Its own doc comment says a timed-out framework call "stalls all automatic work until the user acts", which a killable process fixes. Size cost after SZ-01/02 is estimated at +0.3–0.7 MB; there's a 0 MB alternative. |
| SEC-11 | Input limits | P2 | **CORRECTED** | P3 | Keep only the `PropertyValue` depth limit. The 1 MiB JSON cap and 200 MB DMG cap guard against GitHub itself and could block a future update. |
| SEC-12 | Logging privacy | P2 | **CORRECTED** | → SW-12 (P1 there) | Only UpdateInstaller.swift:523 (the `CFError` from code signing) can carry a path. :175 logs an `UpdateInstallError` case name, :259 a `Process` launch error for `/bin/sh`. |
| SEC-13 | Strict memory safety | P2 | **CORRECTED** | → SW-13 | `.strictMemorySafety()` on BatteryCore now (0 warnings, measured by the Swift verifier). BatteryKit later. `Span` doesn't remove the `unsafe` at the IOKit C call. |
| SEC-14 | Signal only our widget | P3 | **REJECTED** | — | No realistic threat: the target is the user's own process, signalled by the user's own app. The proposed path check could break the stale-widget fix when the old copy was renamed or deleted. |
| SEC-15 | Child env, `-noverify` | P3 | **CORRECTED** | P3 (`-noverify` only, measured) | Wiping the environment defends only against A5 (out of scope), and `/bin/sh`, `hdiutil` and `open` are platform binaries anyway. Dropping `HOME`/`TMPDIR` risks breaking them. Measure `-noverify` together with SZ-03 (ULMO). |
| SEC-16 | Privacy manifest, UDIDs | P3 | **KEEP** | P3 | Verified: required-reason APIs apply "on iOS, iPadOS, tvOS, visionOS, or watchOS". `wip/devices` already keeps UDIDs in memory only. |
| SEC-17 | Updater boundaries (docs) | P3 | **KEEP** (+1 check) | P3 | Release-note quotes verified. Added: macOS 27's XProtect app-data note, so check that History survives an update. |
| SEC-18 | Stable identity (self-signed) | P3 | **KEEP** | P3 research | — |
| SEC-19 | — | — | **NEW** | P2 | One repository constant (owner/repo) for the API endpoint, `AppLinks` and the SEC-01 check; it is written out five times today. |

---

## 1. Summary: what to do in 0.6.1

1. **SEC-01 (P1, S).** After an integrity failure (`.badSignature`, `.digestMismatch`, `.unexpectedBundle`,
   `.invalidCodeSignature`), and for a newer release with no signature (`.notSigned`), don't offer the DMG.
   Offer the release page, with a warning. Everything the app hands to `NSWorkspace.open` must be `https`
   on `github.com`; otherwise open the constant releases page. The pure decision lives in BatteryCore and is
   tested on Linux.
2. **SEC-07 (P1, S).** `build-app.sh` fails unless:
   - both bundles have the hardened runtime;
   - neither has `get-task-allow`;
   - the app has no entitlements and the widget has exactly its file's;
   - the Info.plist has no `LSFileQuarantineEnabled` and no `NSAppTransportSecurity`.

   A `SecurityGuardTests` (P2) pins where `dlopen`, IOKit user-client calls, `Process` and `kill` may
   appear, reusing the `MotionGuardTests` scanner.
3. **SEC-06 (P2, S).**
   - `ci.yml` gets `permissions: contents: read`.
   - Both workflows use `actions/checkout` with `persist-credentials: false`.
   - Actions are pinned to full commit SHAs.
   - Immutable releases are turned on.
   - Split the release job only if the token's exposure to build code is a concern.
4. **SEC-02 / SEC-03 / SEC-19 (P2, S).** Release-note links open only `https`. The update traffic goes
   through one ephemeral session, and automatic checks skip Low Data Mode and expensive networks without
   waiting. The owner/repo string lives in one constant.
5. **SEC-05 (P2, S).** `ReleaseSigning.publicKeys` becomes a list, and release.yml checks the secret
   against it.
6. **SW-12 / SW-13 (owned by the Swift research).** Make the code-signing error log private. Strict memory
   safety on BatteryCore.
7. **SEC-10 (P2, M), decide after 0.6.0 testing.** Move MobileDevice into a bundled XPC service, or run the
   app's own executable in a helper mode. Promote to P1 if 0.6.0 shows a hang or crash in MobileDevice on
   the M5.
8. **SEC-08 (P2 spike).** Enhanced Security entitlements on the widget first. Ship them only after an
   in-app update from 0.6.0 to the candidate succeeds on the M5.
9. **No App Sandbox for the main app** (section 5). **No privacy manifest** (SEC-16).

---

## 2. Threat model (corrected)

**Assets.**
- (a) The integrity of the installed app and of what it installs. The update channel is the highest-value
  asset, because the app replaces itself.
- (b) The release signing key: the `UPDATE_SIGNING_KEY` secret of the `release` environment.
- (c) User data: battery history (low sensitivity) and iPhone/iPad identifiers (moderate: UDIDs and
  serials are stable device identifiers).
- (d) Availability: the menu bar app must not crash or stall because of a device, a private framework or
  a bad reply.

**Trust boundaries.**
- GitHub API JSON and release assets (network).
- The iPhone diagnostics relay reply, through the private MobileDevice framework.
- IOKit/SMC replies (kernel, trusted).
- Files the app wrote itself (same user).
- Child processes: `/bin/sh`, `hdiutil` and `open`.

| # | Adversary | Capability | Today | Gap and recommendation |
|---|-----------|------------|-------|------------------------|
| A1 | Network attacker without a trusted root | Read or alter traffic | ATS defaults (no exceptions in Info.plist); the DMG needs the Ed25519 signature | Can only block or delay updates. Accept. |
| A2 | Write access to the GitHub repository or a token, **without** the signing key | Publish a **new** release with any DMG; edit notes; on mutable releases, replace assets. It **can't** change the host or repository in `browser_download_url`/`html_url`, which GitHub builds itself | In-app install refuses a DMG without a valid signature | **After the refusal, the window recommends downloading that same DMG** (`fallsBackToDownload` is true for `.badSignature`, UpdateInstall.swift:42; "Download" is the default button, UpdateViews.swift:243–244). A newer release without `.sig` gets the same offer. → SEC-01. Notes links → SEC-02. Asset replacement → immutable releases (SEC-06). |
| A3 | Holds the signing key | Sign a malicious DMG that the app installs | Required reviewer advised on the `release` environment | No planned rotation path (SEC-05); pinned actions (SEC-06). Clients that trust a leaked key can't be revoked. That is inherent, so document it. |
| A4 | Malformed device reply, or a framework change in a macOS update | Crash or stall the app; ABI mismatch through `unsafeBitCast` | Symbol checks, socket timeouts, typed `PropertyValue` | An in-process crash takes the menu bar app down, and a stuck call stalls device work (wip/devices `IDeviceMonitor` doc). → SEC-10, SEC-11 (depth) |
| A5 | Local malware as the same user | Everything the user can do | Hardened runtime, no `get-task-allow` | **Out of scope.** TOCTOU between verify and mount isn't a boundary (SEC-17). |
| A6 | Another local user | Read files | Everything lives under the user's home or the per-user `$TMPDIR` | None |
| A7 | Privacy: anyone reading logs, caches, captures | Learn identifiers or paths | UDIDs redacted; no telemetry | One log line can carry a path (SW-12); the API JSON is written to the on-disk URL cache (SEC-03). |

**Non-goals.** Root or kernel attackers, physical access, and Gatekeeper approval of ad-hoc builds (each
downloaded copy needs Open Anyway once; notarization needs a paid account).

---

## 3. Current posture: verified strengths (keep them)

- **Hardened runtime and entitlements.** Both bundles are signed with `--options runtime`
  (build-app.sh:133–134). The app has no entitlements. The widget has only `com.apple.security.app-sandbox`
  (Resources/BatteryPulseWidget.entitlements), and the build fails without it (build-app.sh:136–140).
  Apple: "Make sure to use only the entitlements that are absolutely necessary for your app's
  functionality" (Security › Hardened Runtime). Also: "You add entitlements only to executables" (same
  page).
- **Swift 6 language mode** (`swift-tools-version: 6.0`). No ATS exceptions and no
  `LSFileQuarantineEnabled` in the Info.plist (build-app.sh:57–80).
- **Updater** (UpdateInstaller.swift, UpdateInstall.swift), checks in this order:
  1. GitHub's digest; a malformed `sha256:` value counts as a mismatch (UpdateInstall.swift:56–65).
  2. The 1 KiB `.sig` cap (:81).
  3. Ed25519 over the DMG bytes (UpdateInstaller.swift:362–376).
  4. A read-only, `-nobrowse`, `-noautoopen` mount at a private mount point.
  5. The copy's bundle ID and version: exactly the tag and newer than the running app, which blocks
     downgrades (UpdateInstall.swift:121–128).
  6. `SecStaticCodeCheckValidityWithErrors` with strict, all-architectures and nested-code flags.
  7. An atomic `renamex_np(RENAME_SWAP)`. Apple: don't modify signed code in place ("Updating Mac
     Software").

  The relaunch path is a positional argument, so there's no injection (:140–151). Deleting the leftover
  copy is guarded.
- **SMC client.** Read-only by type: `SMCParamBlock.Command` has only `readKey = 5`,
  `getKeyFromIndex = 8` and `getKeyInfo = 9` (SMC.swift:72–76), sent through selector 2 (SMCClient.swift).
- **MobileDevice.**
  - `dlopen` on demand from two constant absolute paths (MobileDeviceLibrary.swift:54–55, 86); never linked.
  - Required and optional symbols are checked, with `dlclose` on failure (:96–126).
  - No pairing calls.
  - `wip/devices` keeps UDIDs in memory only (`IDeviceMonitor`: "The UDIDs of attached devices, never
    written anywhere").
- **Privacy.**
  - No telemetry (USER_GUIDE.md:271).
  - History is kept 10 days (History.swift:160) and can be cleared in Settings.
  - Notification permission is requested from Settings (SettingsView.swift:357, 369).
  - The login item uses `SMAppService.mainApp`, with a `requiresApproval` path (AppSettings.swift:257–293).

---

## 4. Recommendations

### SEC-01: REWRITTEN. Don't recommend an unverifiable DMG after the app refused it (P1, S)
- **Practice:** a failed authenticity check is a stop, not a reason to download the same file another
  way. Anything handed to `NSWorkspace.open` is checked first.
- **Why:**
  - **What happens today:**
    - `UpdateInstallError.fallsBackToDownload` is `self != .relaunchFailed` (UpdateInstall.swift:42). So
      after `.badSignature` the window shows "The update's signature isn't valid, so it wasn't
      installed.", then "You can download the update and install it from the DMG instead."
      (UpdateViews.swift:179–181).
    - It offers **Download** as the default (Return-key) button (UpdateViews.swift:243–244).
    - `UpdateChecker.download(_:)` opens `release.downloadURL ?? release.pageURL` (UpdateChecker.swift:105).
  - **A newer release without a `.sig`** (impossible for genuine releases since 0.4.0) gets `.notSigned`:
    "This release can only be installed from the DMG." (UpdateInstallPolicy.blocker, UpdateInstall.swift:
    106–108), with the same Download offer.
  - **An A2 attacker** can create such a release in the real repository. Immutable releases (SEC-06)
    don't stop a *new* release.
  - **The original premise was wrong.** It assumed an attacker could point the URLs at "a look-alike DMG
    elsewhere". GitHub generates `browser_download_url` as
    `https://github.com/{owner}/{repo}/releases/download/{tag}/{name}` and `html_url` the same way, so a
    host or repository allow-list doesn't close the gap.
  - **Exact-prefix pinning would also break in-app updates.** After a repository rename or transfer, the
    API still answers through GitHub's redirect, but with the new URLs. `downloadURL` would become `nil`,
    and `blocker` would return `.notSigned` for every future release.
  - Apple on TLS: "The only action your app must take is to use secure URLs" (Security › Preventing
    Insecure Network Connections). That guarantees transport, not origin.
- **How (all decisions in BatteryCore, tested on Linux):**
  1. Add `UpdateInstallError.isIntegrityFailure`: true for `.badSignature`, `.digestMismatch`,
     `.unexpectedBundle`, `.invalidCodeSignature` and `.notSigned`.
  2. Replace `fallsBackToDownload` with an enum, `UpdateFallback { case downloadDMG, releasePage, none }`:
     - network and environment failures → `.downloadDMG`;
     - integrity failures → `.releasePage`;
     - `.relaunchFailed` → `.none`.

     The window uses the mapping in both places it offers Download today: after `.failed(error)`, and in
     the idle state when `installer.blocker(for:)` is non-nil (UpdateViews.swift:187–193, 240–245), so an
     idle `.notSigned` gets the release page too.
  3. For `.releasePage`, the window shows a warning instead of "You can download…". Suggested text:
     "BatteryPulse couldn't confirm this update came from its developer. Check the release page before
     installing anything." The button is **Open Release Page**, not the default button. New strings go to
     `Localizable.xcstrings` with Russian (LocalizationCatalogTests).
  4. Add `ReleaseLinks.browserURL(for:) -> URL`. It returns the candidate only if `scheme == "https"` and
     `host == "github.com"` (case-insensitive); otherwise the constant releases page (SEC-19). Use it for
     every `NSWorkspace.open` in `UpdateChecker`. Don't filter the in-app download URLs: the Ed25519
     signature is the authority there.
  5. Keep the idle-state **Download** button next to Install and Relaunch. It is the user's explicit
     choice, the same as visiting the release page.
- **Measure:**
  - New `UpdateInstallTests` cases: each `UpdateInstallError` maps to the expected fallback, and
    `browserURL` rejects `http`, `file`, a custom scheme and a foreign host. Run `swift test` (Linux and
    macOS).
  - On the M5: serve a release JSON with a corrupted `.sig` through a local `URLProtocol` test double, or
    temporarily point `endpoint` at a fork. The window must offer only Open Release Page.
- **Benefit:** safety. It closes the one path where the app itself steers the user to an unauthenticated
  DMG. **Risk:** low. A *genuine* release with a broken signature (a maintainer mistake, or a key rotation
  without SEC-05) now shows a warning instead of a download button, which is the right outcome. Pair it
  with SEC-05. **Effort:** S. **Priority:** P1.

### SEC-02: CORRECTED. Release-note links open only `https` (P2, S)
- **Practice:** constrain what links in rendered untrusted Markdown can open.
- **Why:**
  - Verified: the notes are rendered as `AttributedString(markdown:options:baseURL: release.pageURL)` with
    `.inlineOnlyPreservingWhitespace` (UpdateViews.swift:256–261), so `[x](file:///…)` or
    `[x](someapp://…)` stays clickable.
  - Apple: a custom action set with `environment(_:_:)` is used by "the built-in Link view and Text views
    with markdown links, or links in attributed strings" (SwiftUI › OpenURLAction › Overview, macOS 11.0+,
    checked 2026-10-15).
  - Immutable releases keep "title and release notes … editable" (prior research,
    `in-app-update-research.json`, integrity section). So SEC-06 doesn't protect the notes, but this does.
- **How:**
  - `ReleaseNotes.isAllowedLink(_ url: URL) -> Bool` in BatteryCore: `https` only, any host. Notes may
    rightly link to developer.apple.com; a github.com-only rule adds nothing against A2, who can write
    github.com links anyway.
  - On the notes `Text`: `.environment(\.openURL, OpenURLAction { ReleaseNotes.isAllowedLink($0) ?
    .systemAction : .discarded })`.
  - Don't strip `.link` attributes in BatteryCore: Markdown parsing of `AttributedString` on Linux is
    **[unverified]**, and it isn't needed.
- **Measure:** unit tests for `isAllowedLink` (`https`, `http`, `file`, `x-apple.systempreferences:`,
  `mailto:`). On the M5, a notes body with `[x](file:///System)` does nothing when clicked.
- **Benefit:** safety. **Risk:** none: `--generate-notes` output and relative links (resolved against
  `pageURL`) are https. **Effort:** S. **Priority:** P2.

### SEC-03: CORRECTED. One ephemeral configuration for update traffic; automatic checks skip constrained networks without waiting (P2, S; same item as E10)
- **Practice:** don't persist caches or cookies you don't use. Defer discretionary traffic on constrained
  and expensive networks.
- **Why:**
  - Verified: the check and both downloads use `URLSession.shared` (UpdateChecker.swift:161,
    UpdateInstaller.swift:184 and 209).
  - The check sets `.reloadIgnoringLocalCacheData` (:157). That ignores the cache for the read, but the
    response is still written to the shared disk cache (also noted in energy E10).
  - Apple: an ephemeral configuration "doesn't store caches, credential stores, or any session-related
    data to disk… The only time an ephemeral session writes data to disk is when you tell it to write the
    contents of a URL to a file" (URLSessionConfiguration.ephemeral, macOS 10.9+). That still allows
    `download(for:)`.
  - `allowsConstrainedNetworkAccess` (macOS 10.15+): "set allowsConstrainedNetworkAccess (and
    allowsExpensiveNetworkAccess) to false and waitsForConnectivity to true". It also says that with no
    unconstrained interface, "any task created from the session fails" with
    `networkUnavailableReason == .constrained`.
  - **Correction:** `waitsForConnectivity = true` would suspend the automatic check while `status ==
    .checking`. **Check Now** then only sets `userIsWaiting` and returns (UpdateChecker.swift:83–86), so
    the user's check would hang for the whole resource timeout. The energy verifier found the same (E10).
- **How:**
  - Add `UpdateNetwork` in the app's `Updates/`, with two lazily built sessions:
    - `user`: `.ephemeral`, `urlCache = nil`, for Check Now, the `.sig` and the DMG;
    - `automatic`: the same plus `allowsConstrainedNetworkAccess = false` and
      `allowsExpensiveNetworkAccess = false`, and **no** `waitsForConnectivity`.
  - `fetchLatest` takes the session. A constrained failure lands in the existing `catch` (status `.idle`,
    no `recordCheck()`), so the next 6-hour tick tries again.
  - Only add `waitsForConnectivity` together with E10's required fix: Check Now cancels a waiting
    automatic check.
- **Measure:** on the M5, before and after,
  `ls ~/Library/Caches/io.github.nikitausov.BatteryPulse/ ~/Library/HTTPStorages/ | grep -i -e Cache.db
  -e BatteryPulse`. After an automatic check, `Cache.db`/`fsCachedData` must not appear (exact paths
  **[unverified-27]**). With Low Data Mode on (System Settings › Wi-Fi › Details; macOS 27 exposure
  **[unverified-27]**), an automatic check fails quietly and Check Now still succeeds.
- **Benefit:** small: privacy hygiene, fewer disk writes, one place for network policy (readability).
  **Risk:** none without `waitsForConnectivity`. **Effort:** S. **Priority:** P2.

### SEC-04: REJECTED (folded into SEC-07). Runtime code requirement in the installer
- **Claim checked:** `checkCodeSignature` passes `nil` as the requirement (UpdateInstaller.swift:521).
  That's true. `SecRequirementCreateWithString`, `kSecCodeInfoFlags` and `kSecCodeInfoEntitlementsDict`
  exist (Security docs, macOS 10.0+).
- **Why rejected:**
  - An `identifier` requirement duplicates `checkBundle`, which already compares `CFBundleIdentifier`.
    Strict validation makes Info.plist part of the seal, and `codesign` takes the identifier from
    `CFBundleIdentifier` when `-i` isn't given (build-app.sh:133–134).
  - The other checks (widget sandboxed, hardened runtime) catch *our own* release mistakes. A DMG only
    passes the Ed25519 check if release.yml built it with build-app.sh, so the build-time gate (SEC-07)
    covers it without new runtime code in the shipped app.
  - The remaining case is a DMG built locally and signed by hand with the key. The runbook in SEC-05
    covers it: always release through the workflow.
- `kSecCSRestrictSymlinks`/`kSecCSRestrictToAppLike` with ad-hoc signatures: **[unverified-27]**. Not
  worth a spike.

### SEC-05: KEEP, trimmed. A key list for planned rotation (P2, S)
- **Practice:** plan key rotation before you need it.
- **Why:**
  - `ReleaseSigning.publicKey` is one string (ReleaseSigning.swift:10).
  - release.yml reads it with a one-line `sed` (release.yml:40), and `UpdateSignatureVerifier.release`
    wraps it (UpdateSignature.swift:22).
  - Moving to a new key today means the release signed with it fails `.badSignature` for every user on
    the old key. After SEC-01 that would show an integrity warning.
  - The project already rotated once, before in-app installs shipped (commit b4157f4).
  - The earlier updater research describes the "rotate, don't remove" model of a widely used macOS
    updater.
- **How:**
  - `ReleaseSigning.publicKeys: [String]` (current key plus an optional next key). The verifier accepts a
    signature from any listed key.
  - release.yml's check changes from "equals" to "is one of". Keep one key per line for the `sed`, for
    example `"<key>", // current`.
  - Rotation runbook in `scripts/sign-update.swift --help` (one paragraph):
    1. Version N ships {K1, K2} and is signed with K1.
    2. N+1 is signed with K2.
    3. A later version drops K1.
  - Releases are always signed by the workflow, never by hand.
  - **Dropped:** signing a "name + version + digest" manifest. The signed Info.plist version already blocks
    downgrades, and it would need a transition release.
  - **Not now:** post-quantum signatures. `MLDSA65` exists in CryptoKit (macOS 26.0+). WWDC25 session 314
    ranks "harvest now, decrypt later" first; for signatures, an attacker with a quantum computer "needs
    to be actively involved".
- **Measure:** `UpdateSignatureTests`: a K2 signature verifies with {K1, K2} and fails with {K1}; an
  empty or malformed entry is ignored. A tag dry run on a fork passes the key check.
- **Benefit:** recoverability. **Risk:** none if both keys verify. **Effort:** S. **Priority:** P2. Do it
  in the same release as SEC-01.

### SEC-06: CORRECTED. Harden the release channel (P2, S)
- **Practice:** a least-privilege token, credentials that don't persist, immutable dependencies, immutable
  releases.
- **Why** (GitHub, "Secure use reference", docs.github.com/en/actions/reference/security/secure-use,
  checked 2026-10-15):
  - Make sure the `GITHUB_TOKEN` "is granted the minimum required permissions".
  - "The best measure is to lock your workflow dependencies with a lockfile… supersedes SHA pinning". The
    lockfile page (docs.github.com/en/actions/concepts/security/workflow-dependency-lockfiles, fetched
    2026-10-15) says: "Workflow dependency lockfiles are in **public preview** and subject to change". It
    is generated by `gh actions-lock`, a GitHub CLI extension, into `.github/workflows/actions.lock`.
  - "Pin actions to a full-length commit SHA" for repositories that don't adopt a lockfile.
- **Corrections to the research:**
  - release.yml has **one** job, so moving `contents: write` from the workflow (release.yml:19–20) to the
    job grants exactly the same. A real reduction needs a split: build and `swift test` without a write
    token, then a publish job. That costs a second macOS job and an artifact hand-off, so it is optional.
  - **Missed:**
    - `ci.yml` has no `permissions:` block. The token's scope then depends on the repository's default
      setting; set `permissions: contents: read`.
    - `actions/checkout` persists the token in `.git/config` by default, so `swift test` and
      `build-app.sh` run with a write-capable token on disk. Set `persist-credentials: false`; release.yml
      already passes `GH_TOKEN` explicitly to `gh`.
  - Already good: inputs reach shell steps through `env:` (release.yml:54–58), never `${{ }}` inside
    `run:`. CI uses `pull_request`, not `pull_request_target`. The `xcode-27` label is a GitHub-hosted VM
    (ci.yml:29–30, 41), not a self-hosted runner.
- **How:**
  1. `ci.yml`: add `permissions: contents: read` at the top.
  2. Both workflows: `actions/checkout@<sha> # v5` with `persist-credentials: false`, and
     `actions/upload-artifact@<sha> # v4`.
  3. Turn on immutable releases in Settings (GA 2025-10-28; prior research). `gh release create` with
     assets drafts, uploads, then publishes (prior research). Note: a broken asset can then only be
     fixed by a new version.
  4. Keep the required reviewer on the `release` environment.
  5. Optional: adopt the lockfile once it leaves preview.
- **Measure:**
  - Review the workflow YAML.
  - The next CI run's "Set up job" log lists `Contents: read`.
  - `grep -n "uses:" .github/workflows/*.yml` shows only SHAs.
  - After 0.6.1: `gh release verify-asset v0.6.1 build/BatteryPulse.dmg`.
- **Benefit:** safety of the highest-value asset. **Risk:** none to the app. **Effort:** S.
  **Priority:** P2.

### SEC-07: KEEP, extended. Signing posture and Info.plist as checked invariants (build check P1, guard test P2; S)
- **Practice:** the hardened runtime with the narrowest entitlements, verified on every build. Risky APIs
  stay in known places.
- **Why:**
  - Apple: "opt for the narrowest set of entitlements that enable the required functionality" (Xcode ›
    Configuring the hardened runtime). Verified.
  - Today build-app.sh checks only that the widget has the sandbox entitlement (:136–140). Nothing fails if
    the app gains an entitlement, if `--options runtime` or `get-task-allow` regress, or if someone adds
    `LSFileQuarantineEnabled`. That last one would silently force Open Anyway after every in-app update; the
    comment at :57 is the only guard.
  - `MotionGuardTests` already scans `Sources/` with comments and strings stripped
    (Tests/BatteryCoreTests/MotionGuardTests.swift:7–25, 315–330).
- **How:**
  1. build-app.sh, after the last `codesign`; it also runs in CI's macOS job and in release.yml:
     ```bash
     for bundle in "$APP" "$APPEX"; do
       codesign -dv "$bundle" 2>&1 | grep -Eq 'flags=0x[0-9a-f]+\([^)]*runtime' \
         || { echo "error: $bundle lacks the hardened runtime" >&2; exit 1; }
       codesign -d --entitlements - --xml "$bundle" 2>/dev/null | grep -q get-task-allow \
         && { echo "error: $bundle has get-task-allow" >&2; exit 1; }
     done
     [ -z "$(codesign -d --entitlements - --xml "$APP" 2>/dev/null)" ] \
       || { echo "error: the app must have no entitlements" >&2; exit 1; }
     diff <(codesign -d --entitlements - --xml "$APPEX" 2>/dev/null | plutil -convert xml1 -o - -) \
          <(plutil -convert xml1 -o - Resources/BatteryPulseWidget.entitlements) >/dev/null \
       || { echo "error: the widget's entitlements differ from its file" >&2; exit 1; }
     for key in LSFileQuarantineEnabled NSAppTransportSecurity; do
       plutil -extract "$key" raw "$APP/Contents/Info.plist" >/dev/null 2>&1 \
         && { echo "error: Info.plist must not contain $key" >&2; exit 1; }
     done
     ```
     Run it once on the M5 to confirm that the `plutil -convert xml1` round trip makes the two entitlement
     plists byte-identical. Key order is **[unverified-27]**; if it differs, compare `plutil -p` output
     instead. Extend the checks to any XPC service bundle (SEC-10).
  2. `SecurityGuardTests` (BatteryCoreTests, Linux). Move the scanner out of `MotionGuardTests` into a
     shared helper. Rules (current locations verified by grep):
     - `dlopen`/`dlsym`/`dlclose` only in `BatteryKit/MobileDevice/MobileDeviceLibrary.swift`;
     - `IOServiceOpen` and `IOConnectCall` only in `BatteryKit/SMCClient.swift`;
     - `Process()` only in `BatteryPulseApp/Updates/UpdateInstaller.swift` (lines 248, 463);
     - `kill(` only in `BatteryPulseApp/App/WidgetRefresher.swift`. The `kill -0` inside the relaunch
       script string in BatteryCore is stripped by the scanner;
     - `URLSession.shared` nowhere (after SEC-03);
     - `SMCParamBlock.Command` keeps exactly three cases (or `SMCTests` pins `allCases`).
     **Dropped:** "no `privacy: .public` on path variables". A regex can't tell a path from a version
     string; SW-12's review rule covers it.
- **Measure:** the CI macOS job runs build-app.sh. Flip one invariant in a throwaway branch (for example,
  add an entitlement to the app) and the job must fail. `swift test` on Linux runs the guard test.
- **Benefit:** safety, plus one place to look (readability). **Risk:** none. **Effort:** S.
  **Priority:** P1 (build check), P2 (guard test).

### SEC-08: CORRECTED. Spike the Enhanced Security entitlements, widget first, with a hard gate (P2, S to try, M to qualify)
- **Practice:** opt in to the platform's runtime memory-safety protections where the threat model justifies
  them.
- **Why** (Xcode › "Enabling enhanced security for your app", checked 2026-10-15; quotes verified):
  - **Memory tagging:** a tag mismatch makes "the app crash instead of performing the unsafe access".
    - "On devices without hardware memory tagging support, this setting has no effect. Supported devices
      include … Mac and Apple Vision Pro with an M5 chip or later."
    - Soft mode "produces a simulated crash instead of terminating the app".
  - **Run-time restrictions:** "additional checks on dynamic libraries your app or extension loads, and on
    Mach messages your app or extension receives". With XPC, or no explicit IPC, they are "unlikely to
    require you to make any code changes". IOKit calls go through MIG.
  - **`dyld-ro`:** read-only "internal platform state".
  - **Guard objects:** on with `enhanced-security-version-string` ≥ `2`. They "can cause an increase in
    memory usage or a decrease in execution speed… Profile your app". Turning them off
    (`no-guard-objects`) says "update your provisioning profile".
  - **Dependencies:** "Any entitlements that begin with `com.apple.security.hardened-process.` require both
    [hardened-process] and [enhanced-security-version-string]".
  - **Live platform lists (re-fetched 2026-10-15):**
    - `hardened-process`: macOS 26.0+.
    - `dyld-ro`, `hardened-heap`: macOS 26.0+.
    - `platform-restrictions-string`, `enhanced-security-version-string`: macOS 26.4+.
    - **`checked-allocations` and `.soft-mode`: iOS 26.0 and iPadOS 26.0 only.** This conflicts with the
      article's M5 Mac statement → **[unverified-27]**.
  - **macOS 27 release notes, Hardware Security:** arm64e.x1 with "CPA2 for stronger MIE protection" on
    "Mac computers with M6 or later chips", set in Xcode's enhanced security pane.
  - **Unverified:**
    - whether AMFI accepts these entitlements on an **ad-hoc** signature with no provisioning profile;
    - whether `platform-restrictions` assumes an arm64e slice. The article ties "additional runtime
      platform restrictions" to Xcode building arm64e. SwiftPM builds arm64.
- **Correction (risk):** the research said an AMFI refusal is "caught immediately". On the maintainer's
  M5, yes. But in-app updates swap the bundle **before** the relaunch (UpdateInstaller.swift:415–421). A
  new version that macOS refuses to launch leaves users with an app that doesn't open, recoverable only by
  downloading the previous DMG by hand. And MIE only acts on M5 or later, so users on M1–M4 test nothing.
- **How:**
  1. Widget only, in a throwaway build:
     - add `hardened-process` = true, `enhanced-security-version-string` = "2", `dyld-ro` = true and
       `platform-restrictions-string` = "2";
     - add `checked-allocations` + `.soft-mode` only if a test shows macOS honours them.
  2. If the widget renders for a week with no AMFI denials and no simulated crashes, add
     `Resources/BatteryPulse.entitlements` with the same set to the app's `codesign`, and update SEC-07's
     expected sets.
  3. **Gate before shipping:** on the M5, install 0.6.0 from its DMG, then let it update in-app to the
     candidate DMG (signed with a throwaway key in a local build, or a release-candidate tag). The new
     version must launch and pass the SMC, MobileDevice and update smoke checks.
  4. No arm64e builds with SwiftPM in 0.6.1.
  5. If SEC-10 lands, MobileDevice runs in its own process and can stay without the run-time restrictions
     while the app adopts them.
- **Measure:**
  - `codesign -d --entitlements - --xml <bundle>`.
  - `log show --last 10m --predicate 'process == "amfid" OR subsystem == "com.apple.MobileFileIntegrity"'`
    must show no denials; the exact predicate is **[unverified-27]**.
  - `~/Library/Logs/DiagnosticReports` stays free of BatteryPulse reports.
  - `footprint -p BatteryPulse` (or Activity Monitor › Memory) before and after: guard objects must not
    noticeably raise the footprint. Use the energy research's idle measurement.
- **Benefit:** safety for the C/ObjC code fed untrusted input (MobileDevice plist decoding) and our
  `unsafeBitCast` islands. **Risk:** medium (launch refusal, crashes under the restrictions). The gate
  covers it. **Effort:** S (try), M (qualify). **Priority:** P2. Drop it if ad-hoc signatures can't carry
  the entitlements.

### SEC-09: CORRECTED. Record the private framework's version; `RTLD_LOCAL | RTLD_FIRST` as hygiene (P2 for the version, P3 for the flags; S)
- **Why:**
  - `dlopen(path, RTLD_NOW)` (MobileDeviceLibrary.swift:86). dyld's `dlopen.3`: `RTLD_FIRST` tags the
    handle "so that any dlsym() calls on the handle will only search the image specified, and not
    subsequent images". "If neither RTLD_GLOBAL nor RTLD_LOCAL is specified, the default is RTLD_GLOBAL"
    (verified in `dl/dlopen.3`).
  - **Correction:** the security gain is nil in practice. The paths are constant and absolute, the `AM*`
    names are unique, and macOS uses two-level namespaces. `RTLD_FIRST` is tidiness, not protection.
  - The useful part is diagnostics. When a macOS update changes MobileDevice, the 0.6.0 Devices page and
    `bpulse --devices` should say which framework version they found.
- **How:**
  - Before `dlopen`, read the version with `Bundle(path: <framework dir>)?.infoDictionary` (reads the
    plist, loads no code). Keep `CFBundleShortVersionString`/`CFBundleVersion` in `MobileDeviceLibrary`,
    show them in `bpulse --devices` and in `IDeviceError.frameworkUnavailable`, and log them once at
    `.info` (SW-12 `device` category).
  - Optional: `dlopen(path, RTLD_NOW | RTLD_LOCAL | RTLD_FIRST)`. The existing "missing <symbols>" error
    reports any symbol `RTLD_FIRST` hides. If a re-exported symbol disappears, drop `RTLD_FIRST`
    **[unverified-27]**.
  - **Dropped:** the `dladdr` debug assertion (code without a benefit).
- **Measure:** `bpulse --devices` on the M5 lists the iPhone and prints the framework version. The CI smoke
  run (ci.yml:56–59) still exits 0 or 2.
- **Benefit:** diagnosability. **Risk:** low. **Effort:** S. **Priority:** P2 (version, with 0.6.0
  devices), P3 (flags).

### SEC-10: KEEP. MobileDevice in a separate process (P2, M; promote to P1 on evidence)
- **Practice:** put crash-prone or untrusted-input work in a separate, killable process.
- **Why:**
  - Apple's archived XPC guide: "There are two main reasons to use XPC services: privilege separation and
    stability", and an XPC service "is private, and is available only to the main application that
    contains it" (verified in `dl/xpcarchive.html`).
  - `XPCSession` is macOS 14.0+ (verified). `XPCListener(service:…requirement:…)` and
    `XPCPeerRequirement` are macOS 26.0+ (prior download in `scratchpad/appledocs/`).
  - **The research's condition is met.** `wip/devices` adds `IDeviceMonitor` (BatteryKit), which reads
    devices in the app process. Its doc comment documents the failure this fixes: "a call that times out
    stalls all automatic work until the user acts, because a stuck framework call holds the transport's
    queue". A child process can be killed and restarted instead.
- **Two implementations; pick by measured size (the size research targets an app of about 3.3 MB after
  SZ-01/02):**
  - **A. Bundled XPC service (native).**
    - New SwiftPM executable `BatteryPulseDevices`, wrapped by build-app.sh into
      `Contents/XPCServices/BatteryPulseDevices.xpc` (`CFBundlePackageType XPC!`, `XPCService` with
      `ServiceType Application`). Same pattern as the `.appex`.
    - Signed with `--options runtime` and no sandbox: usbmuxd is outside a sandbox.
    - It links BatteryCore and BatteryKit's MobileDevice transport and serves `list`/`capture` as
      `Codable` requests through `XPCListener`.
    - Peer requirement: ad-hoc code has no Team ID, so `isFromSameTeam` probably fails
      **[unverified-27]**. Rely on the service being private to the bundle, or on SEC-18 later.
    - Size: one more binary. **Estimate +0.3–0.7 MB installed after SZ-01/SZ-02** (similar to the
      stripped widget, about 0.6–0.7 MB), not the research's +1–3 MB, which assumed unstripped binaries.
  - **B. Helper mode of the app's own executable (0 MB).**
    - `BatteryPulse --device-helper` is handled in a custom `main` before `BatteryPulseApp.main()`. The
      app runs it through `Process`, as it already does for `hdiutil`, with JSON over a pipe.
    - Crash containment and killability are the same. It is less native and has a process start per
      session, so keep the helper alive while devices are attached.
  - Rejected: an Enhanced Security helper extension, which "runs in a sandbox that restricts access to
    most system services" (verified), so usbmuxd would be out of reach.
- **Measure:**
  - After a device read, `vmmap $(pgrep -x BatteryPulse) | grep -c MobileDevice` is 0.
  - `kill -9` the service or helper mid-capture: the app shows an error, and the next read works without
    user action, which removes the documented stall.
  - `du -sk build/BatteryPulse.app` and the DMG size before and after.
- **Benefit:** stability of the menu bar app, plus a lower app footprint after device reads. **Risk:**
  medium (new IPC layer and lifecycle). **Effort:** M. **Priority:** P2. Promote to P1 if 0.6.0's M5
  testing shows a MobileDevice hang or crash.

### SEC-11: CORRECTED. A depth limit for `PropertyValue` (P3, S)
- **Why:**
  - `PropertyValue(any:)` recurses with no limit (PropertyValue.swift:30–33). It is fed by the MobileDevice
    reply (MobileDeviceTransport.swift:267), IOKit and `bpulse --input`.
  - Transport work may run on a secondary thread with a small stack **[unverified: thread and stack size
    in wip/devices]**.
  - A hostile reply needs a paired, trusted device, and MobileDevice's own decoder sees it first, so the
    risk is low.
  - No Apple source documents a recursion limit here **[engineering judgment]**.
- **How:** `PropertyValue(any:depth:)` with `maxDepth = 64`, dropping deeper nodes. IORegistry trees are
  about 6 deep, so real data never reaches it.
- **Rejected parts:**
  - The 1 MiB API response cap: the server is GitHub over TLS, so A1 can't send a bigger body, and A2
    can't exceed GitHub's own limits.
  - The 200 MB DMG cap and the size-before-hash check: the digest and the signature already fail a wrong
    file, and a fixed cap could block a future, larger update.
- **Measure:** a Linux test with a 10,000-deep nested array returns a bounded value without a crash.
- **Benefit:** robustness. **Risk:** none. **Effort:** S. **Priority:** P3.

### SEC-12: CORRECTED. Logging privacy (handled as SW-12)
- **Verified:**
  - The only log line that can carry user data is UpdateInstaller.swift:522–523:
    `String(describing: CFError)` from `SecStaticCodeCheckValidityWithErrors` with `privacy: .public`. It
    can include the staged bundle's path.
  - :175 logs `String(describing: UpdateInstallError)`, a static case name. :259 logs the `Process.run()`
    error for `/bin/sh`. :246 and :417 log a status code and `strerror`. All fine as public.
  - Apple: "try to limit your log messages to static strings and numbers… redact any values that contain
    sensitive user information" (os › Generating log messages from your code, verified).
- **How:** follow SW-12 (P1 in `v061/swift/verified.md`):
  - :523 logs the error code publicly and the description at the default private level, or
    `.private(mask: .hash)`;
  - device logging in 0.6.0 uses `.private(mask: .hash)` for UDIDs, serials and device names;
  - one `Logger` per category.
- **Measure:** `log stream --level debug --predicate 'subsystem == "io.github.nikitausov.BatteryPulse"'`
  during a failing update shows `<private>` for the description.

### SEC-13: CORRECTED. Strict memory safety (handled as SW-13)
- **Verified:**
  - WWDC25 session 311: "a new compiler mode in Swift 6.2 called Strict memory safety… The compiler alerts
    me to any unsafe code".
  - WWDC26 session 262: "you could turn on strict memory safety in security-critical functions".
  - The count is right: 32 matches of `unsafeBitCast|UnsafeMutableRawPointer|withUnsafe|Unmanaged` in five
    files (MobileDeviceTransport 15, MobileDeviceLibrary 13, SMCClient 2, MacBatteryProvider 1,
    UpdateInstaller 1).
- **Corrections:**
  - Per SW-13, `@diagnose(StrictMemorySafety, as: warning)` does **not** turn the check on for one function
    (measured with Swift 6.4.1). Enable it per module and mark audited spots with `unsafe` or
    `@diagnose(…, as: ignored, reason:)`.
  - BatteryCore first: 0 warnings, and it holds the parsers. BatteryKit later.
  - `Span` doesn't remove the `unsafe` at `IOConnectCallStructMethod`, which takes raw pointers. It can only
    narrow the unsafe region.
- **Measure:** the macOS CI job builds BatteryCore with `.strictMemorySafety()` and 0 warnings
  (SW-14 gate). `grep -rn "unsafe " Sources/BatteryKit` lists the audited spots once Kit is done.

### SEC-14: REJECTED. Signal only our own widget process
- **Claim checked:** `endPreviousExtension` sends `SIGTERM` to every process **named** `BatteryPulseWidget`
  that the user may signal (WidgetRefresher.swift:40–57), on the first launch of a new version
  (BatteryPulseApp.swift:48–50). That's true.
- **Why rejected:**
  - A same-named process belongs to the same user; sending it `SIGTERM` crosses no boundary.
  - The proposed check, `proc_pidpath` ending in `/BatteryPulse.app/Contents/PlugIns/…`, fails for an old
    copy the user renamed. For a copy replaced from the DMG and already deleted, it may fail or return
    `ENOENT` **[unverified]**. Those are exactly the cases the function exists for, so the check risks the
    stale-widget fix for no gain.

### SEC-15: CORRECTED. `hdiutil attach -noverify`, measured; no environment wiping (P3, S)
- **Rejected:** `process.environment = ["PATH": …]`.
  - It defends only against A5 (out of scope).
  - `/bin/sh`, `/usr/bin/hdiutil` and `/usr/bin/open` are called by absolute path, and as platform
    binaries they ignore `DYLD_*`.
  - The relaunch script's only external command is `sleep`; `kill` is a shell builtin.
  - Dropping `HOME`/`TMPDIR` could change how `hdiutil` or `open` behave **[unverified]**.
- **Kept, optional:** add `-noverify` to `UpdateInstallPolicy.attachArguments` (UpdateInstall.swift:132–134).
  The image is fully authenticated (SHA-256 and Ed25519) before `attach`, so its internal checksum adds
  time and no safety.
  - Measure it **together with SZ-03** (ULMO): time `hdiutil attach` with and without `-noverify` on the
    real DMG, 5 runs each, and adopt it only if the difference is ≥ 100 ms.
  - Check `man hdiutil` on the M5 for the flag and for any deprecation in favour of `diskutil image`
    (secondary sources only; the macOS 27 release notes say nothing about it) **[unverified-27]**.
  - Update `UpdateInstallTests`.

### SEC-16: KEEP. Privacy manifest, identifiers, retention (P3, S)
- **Privacy manifest: not needed.**
  - Apple's required-reason page: "Describe the reasons your app or third-party SDK on iOS, iPadOS, tvOS,
    visionOS, or watchOS uses these APIs" (verified).
  - WWDC25 session 246: "Before you submit to the App Store, SDKs may require a privacy manifest file"
    (verified).
  - BatteryPulse is built by SwiftPM, not archived in Xcode, isn't on the App Store, and collects no data.
  - Keep the plain-language privacy section of USER_GUIDE.md current.
- **Identifiers:** `wip/devices` already follows the rule: UDIDs only in memory, and `RememberedDevice`
  stores no UDID, ECID or serial (RememberedDevice.swift:40, on that branch). Keep the rule in the 0.6.0
  review checklist. WWDC25 session 246: "Data minimization means using only the data you need".
- **Retention:** 10 days of samples plus daily summaries, with Clear History. Proportionate; no change.

### SEC-17: KEEP. Updater boundaries documented; one added check (P3, S, docs)
- **TOCTOU** between verify and mount and between check and swap: the files are writable only by the same
  user (A5), who can already replace the app. Not a boundary. Document it in the `UpdateInstaller` doc
  comment; don't build fd-based verification.
- **Quarantine and Gatekeeper.** Keep `LSFileQuarantineEnabled` absent (now enforced by SEC-07) and keep
  `clearQuarantine`. macOS 27 release notes (verified in `scratchpad/macos27.md`):
  - Gatekeeper: only the new `spctl --purge`.
  - launchd: "no longer supports loading launchd property list files with the quarantine extended
    attribute" (no plists here).
  - SIP: access to other developer teams' containers is "denied by default".
- **Added (missed by the research):** macOS 27 also says "XProtect may now restrict access to app data
  that is commonly targeted by malicious software. Accessing files created by other developer teams' apps
  may be denied by default". An ad-hoc app has no Team ID, and each version has a new cdhash. After a real
  update, confirm on the M5 that the new version still reads its own History and settings with no Privacy
  & Security prompt **[unverified-27]**.
- **Rename-swap.** Optionally check `URLResourceKey.volumeSupportsSwapRenamingKey` first, for a clearer
  error.
- **Downgrade.** Already blocked (`checkStagedBundle`). Add a test named for it.
- **After a real 0.6.0 → 0.6.1 update, on the M5:**
  - `xattr -l /Applications/BatteryPulse.app` (no `com.apple.quarantine`);
  - `sfltool dumpbtm | grep -A5 BatteryPulse` (the login item survives);
  - notification permission is kept;
  - the widget comes back;
  - History is intact.

### SEC-18: KEEP. A stable code identity without a paid account (P3, research only)
- **Why:**
  - Ad-hoc signatures have a cdhash-only designated requirement, so TCC grants and XPC peer requirements
    can't name the app across updates. Sources: TN3127 and Apple DTS in forum thread 795739, from the
    prior research.
  - A self-signed code-signing certificate gives a stable designated requirement (archived Code Signing
    Guide and TN2206, prior research).
- **Apply later:** a spike.
  1. Create a self-signed identity with a long validity.
  2. Import it in CI from a second secret in the `release` environment.
  3. Check on the M5 that TCC grants and the login item survive an update.

  Gatekeeper still treats the app as from an unidentified developer.
- **Benefit:** fewer prompts after updates; real XPC peer checks for SEC-10. **Risk:** a second secret.
  **Effort:** M. **Priority:** P3 (after 0.6.1).

### SEC-19: NEW. One constant for the release channel (P2, S)
- **Why:** `NikitaUsov/BatteryPulse` is written out five times: UpdateChecker.swift:55 and four `AppLinks`
  (AppSettings.swift:142, 144, 146, 148). SEC-01's host check and SEC-05's runbook add more
  places that must agree. It's a readability and foundation item, and the 0.6.1 brief asks for exactly
  that.
- **How:**
  - `ReleaseChannel` in BatteryCore holds `owner`, `repository`, `apiLatestRelease`, `releasesPage` and
    `assetName`.
  - `UpdateChecker.endpoint`, `AppLinks.project/releases/license/help` and `ReleaseLinks.browserURL`
    derive from it.
  - Don't build an exact-path check on it (SEC-01, rename risk).
- **Measure:** `grep -rn "NikitaUsov/BatteryPulse" Sources` returns one line. Existing tests pass.
- **Benefit:** readability; one edit if the repository moves. **Risk:** none. **Effort:** S.
  **Priority:** P2.

---

## 5. What App Sandbox would cost the main app (verdict kept: don't sandbox in 0.6.1)

| Feature | Under App Sandbox | Evidence |
|---|---|---|
| IORegistry / IOPS battery reads | Work | The shipped sandboxed widget reads them itself: `MacBatteryProvider(readsSMC: false)` (BatteryPulseWidget.swift:58–61) |
| SMC user client (`IOServiceOpen` AppleSMC) | Blocked. It would need `com.apple.security.temporary-exception.iokit-user-client-class` **[unverified-27]** | Widget comment "The SMC can't be opened from the sandbox" (:59); archived temporary-exception reference |
| MobileDevice (`dlopen`, usbmuxd socket, lockdown) | Very likely broken without temporary exceptions **[unverified-27]** | Archived temporary-exception reference |
| Install and Relaunch | Breaks: a sandboxed app's files are quarantined, it can't write to `/Applications`, and `hdiutil` inherits the sandbox | Prior research Q1a(d); archived XPC guide |
| Ending the stale widget process | Forbidden: "Terminating other running apps" | Security › Protecting user data with App Sandbox (verified) |
| History files | Move into the container (migration) | Same page |
| GitHub check and download | Need `com.apple.security.network.client` | Xcode › Configuring the macOS App Sandbox |
| Login item, notifications, widget reloads | Work | `SMAppService.mainApp` (macOS 13.0+), UserNotifications |

**Verdict:** three core features break, for little gain in an app whose inputs are mostly kernel data. Keep
the current split: the sandboxed widget, a separate unsandboxed device process (SEC-10) and runtime
hardening (SEC-08). Re-evaluate only with a Developer ID or App Store plans.

---

## 6. Rejected for 0.6.1 (original and new)

- **Exact URL-prefix pinning of API URLs** (original SEC-01): GitHub builds those URLs, so it doesn't stop
  A2, and it breaks in-app updates after a rename. Replaced by the new SEC-01.
- **Runtime code requirement in the installer** (SEC-04): duplicate of `checkBundle`. Build-time SEC-07
  covers release mistakes.
- **Signal only our widget** (SEC-14): no threat; risks the stale-widget fix.
- **Environment wiping for child processes** (SEC-15): A5 only; risk to `hdiutil`/`open`.
- **API body and DMG size caps** (SEC-11): no attacker can trigger them, and a cap could block a real
  update.
- **`dladdr` assertion** (SEC-09): code with no benefit.
- **Moving `contents: write` to the single job** (SEC-06): grants the same.
- **Certificate pinning for api.github.com:** Ed25519 anchors trust, and pinning breaks on GitHub's
  certificate rotations.
- **fd-based "verify what you mount":** same-user attacker (SEC-17).
- **Enhanced Security helper extension for device reads:** its sandbox blocks usbmuxd.
- **App Attest (WWDC26 session 201):** for attesting to an app's own server; there is none.
- **Post-quantum update signatures (ML-DSA):** later (SEC-05).
- **Provisional notification authorization:** it would hide charge-limit and heat alerts.
- **Privacy manifest:** SEC-16.
- **App Sandbox for the main app:** section 5.

---

## 7. M5 verification checklist (for the 0.6.1 audit)

1. `codesign -dv --verbose=4 /Applications/BatteryPulse.app 2>&1 | grep flags` shows
   `flags=0x10002(adhoc,runtime)`; same for the `.appex` (and the `.xpc`, if SEC-10 lands). The SEC-07
   script passes on the release DMG's contents.
2. SEC-01: a release JSON with a corrupted `.sig` (local test double or a fork) offers only Open Release
   Page, with the warning.
3. SEC-03: no `Cache.db` under `~/Library/Caches/io.github.nikitausov.BatteryPulse` after an automatic
   check. With Low Data Mode, the automatic check stays quiet and Check Now works.
4. SEC-08 spike: AMFI log clean, widget renders, SMC and `bpulse --devices` work, **and an in-app update
   from 0.6.0 to the candidate launches.**
5. SEC-09: `bpulse --devices` prints the MobileDevice version (and works with `RTLD_FIRST`, if adopted).
6. SEC-10: `vmmap` shows no MobileDevice in the app; `kill -9` of the helper mid-capture recovers without
   user action.
7. SEC-15: `man hdiutil` (`-noverify`, any deprecation); attach timing with ULMO.
8. SEC-17, after a real update: `xattr -l`, `sfltool dumpbtm`, notification settings, the widget, and
   **History and settings still readable** (macOS 27 XProtect app-data note).

---

## 8. Sources (checked 2026-10-15; local copies in `v061/security/dl/`, re-fetches in `v061/security/vdl/`)

**Apple documentation** (JSON behind developer.apple.com/documentation/…):
- `xcode/enabling-enhanced-security-for-your-app`. Quotes in SEC-08 verified: M5 Mac support note,
  dependencies, guard objects, run-time restrictions, `no-guard-objects` provisioning profile.
- `bundleresources/entitlements/com.apple.security.hardened-process` (macOS 26.0+, re-fetched).
  - `.checked-allocations` (**iOS/iPadOS 26.0 only**, re-fetched) and `.soft-mode` (iOS/iPadOS only).
  - `.dyld-ro` and `.hardened-heap` (macOS 26.0+).
  - `.platform-restrictions-string` and `.enhanced-security-version-string` (macOS 26.4+).
- `xcode/creating-enhanced-security-helper-extensions` ("runs in a sandbox that restricts access to most
  system services").
- `security/hardened-runtime` ("absolutely necessary"; "only to executables").
  `xcode/configuring-the-hardened-runtime` ("narrowest set of entitlements").
- `security/protecting-user-data-with-app-sandbox` ("Terminating other running apps").
  `xcode/configuring-the-macos-app-sandbox`.
- `security/updating-mac-software` (don't modify signed code in place).
- `xpc/xpcsession` (macOS 14.0); `xpc/xpclistener`, `xpc/xpcpeerrequirement` (macOS 26.0; prior download
  in `scratchpad/appledocs/`).
- `security/secrequirementcreatewithstring(_:_:_:)`, `security/secstaticcodecheckvalidity(_:_:_:)`,
  `security/kseccodeinfoentitlementsdict`, `security/kseccodeinfoflags`, `security/kseccsrestricttoapplike`
  (macOS 10.0+, re-fetched).
- `foundation/urlsessionconfiguration/ephemeral` (macOS 10.9).
  `foundation/urlsessionconfiguration/allowsconstrainednetworkaccess` (macOS 10.15; the failure and
  `networkUnavailableReason` text, the "waitsForConnectivity" advice).
- `swiftui/openurlaction` (macOS 11.0; a custom action applies to "links in attributed strings").
- `security/preventing-insecure-network-connections`.
- `os/generating-log-messages-from-your-code` ("static strings and numbers").
- `bundleresources/privacy-manifest-files`; `bundleresources/describing-use-of-required-reason-api` ("on
  iOS, iPadOS, tvOS, visionOS, or watchOS").
- `servicemanagement/smappservice/mainapp` (macOS 13.0). `cryptokit/mldsa65` (macOS 26.0).
- macOS 27 Release Notes (`scratchpad/macos27.md`):
  - Gatekeeper `spctl --purge` (123097648);
  - launchd and quarantine;
  - System Integrity Protection: containers (161835690) and **XProtect app data (178668601)**;
  - TCC database;
  - Hardware Security: arm64e.x1/CPA2 on M6 (152103975).
- Archive: Daemons and Services Programming Guide › Creating XPC Services (stability; "private, and is
  available only to the main application"). Entitlement Key Reference › App Sandbox Temporary Exception
  Entitlements.

**WWDC** (transcripts in `dl/`; WWDC26 262 in the sibling research):
- WWDC25 246 "Integrate privacy into your development process" (data minimization; privacy manifests before
  App Store submission).
- WWDC25 311 "Safely mix C, C++, and Swift" (strict memory safety in Swift 6.2).
- WWDC25 314 "Get ahead with quantum-secure cryptography" ("harvest now, decrypt later"; an active attacker
  for signatures).
- WWDC26 262 "What's new in Swift" ("turn on strict memory safety in security-critical functions"; per
  SW-13 this per-function form doesn't work in 6.4.1).
- WWDC26 201 (App Attest): not applicable.

**Swift and toolchain:** dyld `doc/man/man3/dlopen.3` (`RTLD_FIRST`, the default `RTLD_GLOBAL`). Sibling
`v061/swift/verified.md`: SW-12, SW-13 (measured with Swift 6.4.1), SW-14.

**GitHub** (hosts the release channel):
- docs.github.com/en/actions/reference/security/secure-use (minimum permissions, lockfile, SHA pins,
  GitHub-hosted versus self-hosted runners).
- docs.github.com/en/actions/concepts/security/workflow-dependency-lockfiles (**public preview**,
  `gh actions-lock`, `.github/workflows/actions.lock`; fetched 2026-10-15).
- Immutable releases (GA 2025-10-28; notes stay editable; `gh release verify-asset`) and `gh release
  create`'s draft-upload-publish order: prior research `scratchpad/in-app-update-research.json`, integrity
  section.

**Repository facts** cite file:line at `fb41ff5`. `wip/devices` is cited by file
(`Sources/BatteryKit/IDeviceMonitor.swift`, `Sources/BatteryCore/RememberedDevice.swift`).
