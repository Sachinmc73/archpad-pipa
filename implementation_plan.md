# ArchPad Keyboard Quality Repair and FUTO Swipe Qualification Plan

## Final pre-FUTO audit — 2026-09-16

**Status:** Architecture-preserving cleanup is installed as
`archpad-keyboard 1.0.0-58`. FUTO code and models have not been added.

Release 58 fixes a settings-launch regression from release 57: the standard
Qt Quick Controls `ApplicationWindow` now starts visible. Previously the first
tap created a hidden settings process and only a second launch's D-Bus
`Activate()` call showed it.

### Release 57 cleanup

- Replaced the settings companion's Kirigami window with the standard Qt Quick
  Controls `ApplicationWindow` and removed the package's Kirigami dependency.
- Replaced direct parsing and watching of KDE's `~/.config/kdeglobals` with
  Qt 6.11's standard `QStyleHints::colorScheme` system appearance API.
- Flushes any pending debounced settings write when the settings companion
  exits, so a final slider change cannot be lost on immediate close.
- Removed the unimplemented swipe-delete and double-space preview cards. The
  section now exposes only the implemented long-press timing control, over the
  same complete `150..1000 ms` range enforced by the daemon.
- Removed hardcoded KWin and package version claims from the settings
  diagnostics and fixed the remaining Qt Quick layout-ownership warnings.
- Added error handling for every `UI_SET_KEYBIT` operation during uinput device
  creation.

### Verified results

- Native Linux `aarch64` build completed on the Xiaomi Pad 6.
- Main-keyboard and settings QML pass Qt 6.11 `qmllint` with the resource
  aliases resolved; no layout-positioning diagnostics remain.
- The package contains 23 expected files, has no install script, and no longer
  depends on Kirigami.
- `archpad-keyboard`, `plasma-desktop`, `plasma-workspace`, `kscreenlocker`,
  and `sddm` all report zero altered package-owned files.
- The restarted service owns one daemon process, initializes `/dev/uinput`,
  creates the LayerShell window, and logs no new keyboard warnings.
- The settings companion launches as one process and logs no current QML
  warnings. Final portrait/landscape interaction remains a real-touch check.

### Architectural boundary found by the audit

The current daemon is stable on the target tablet, but it is not yet a clean
multilingual text-commit foundation:

1. `ensureXkbOptions()` writes KDE's `~/.config/kxkbrc`, forces
   `Layout/LayoutList=us`, and enables three XKB options. A keyboard must not
   rewrite the desktop's physical-keyboard layout. This must be removed, but
   doing so without replacing text commit would regress the Rupee key and make
   output depend on the user's active hardware layout.
2. `tapText()` currently decomposes a string into US-layout key events over
   `/dev/uinput`. That is sufficient for today's English keys and raw
   navigation shortcuts, but it cannot correctly commit arbitrary UTF-8 words,
   maintain preedit text, replace a selected candidate, or scale to FUTO
   language models.
3. Automatic visibility is a KWin D-Bus adapter. The LayerShell surface itself
   uses a cross-compositor protocol, but other compositors will need their own
   activation adapter rather than KWin calls embedded in the core.

The live KWin 6.7.5 registry exposes `zwp_input_method_v1`,
`zwp_text_input_manager_v2`, and `zwp_text_input_manager_v3`. Input-method v1
provides UTF-8 `commit_string`, preedit, surrounding-text deletion, content
purpose, and input-panel lifecycle. The previously selected Hyprland path
exposes input-method v2 instead. Therefore the standards-based product
direction is a small backend interface:

```text
keyboard UI / FUTO candidates
        -> text-commit interface
             -> KWin input-method-v1 adapter
             -> input-method-v2 adapter for wlroots/Hyprland-class sessions
             -> uinput only for raw shortcuts/fallback
```

This is a separate architectural change and requires its own approved plan and
real application compatibility matrix. The isolated FUTO engine qualification
below can proceed before that change because it does not alter the installed
keyboard. Visible swipe integration must not use `tapText()` as its final
candidate-commit path.

## Proposed architecture migration: preserve the current keyboard and separate integration packages

**Status:** Completed and verified on the Xiaomi Pad 6 on 2026-09-15.

Plasma 6.7.5 `kscreenlocker_greet` loads its UI from the active `Plasma/Shell`
package. It does not provide an independently selectable lock-screen Global
Theme entry point. Therefore a Look-and-Feel-only package is not a valid
replacement for the working shell overlay on this target release.

The lowest-risk migration is:

1. Keep the existing `LayerShellQt` plus `/dev/uinput` keyboard architecture
   unchanged for the unlocked session.
2. Move the current Plasma shell lock-screen overlay unchanged into a separate
   `archpad-plasma-lockscreen` package pinned to the exact compatible Plasma
   release. Continue using XDG `/usr/local/share` precedence and never modify
   an upstream package-owned file.
3. Remove the recursive uninstall hook. Pacman must remove only files owned by
   the integration package.
4. Move the SDDM theme unchanged into a separate `archpad-sddm-theme` package.
   Give it the packaged ArchPad artwork as an independent default background.
5. Remove wallpaper synchronization, home-directory scanning, tmpfiles state,
   and the user-to-SDDM display-configuration copy from `archpad-keyboard`.
   SDDM orientation belongs to device/display-manager integration.
6. Keep the unmodified upstream Plasma lock screen as the rollback path.
7. Build the three packages and install them in one transaction, then verify
   normal typing, lock/unlock, SDDM login, orientation, ownership, and upstream
   package integrity on the real tablet.

The exact Plasma dependency is intentional: it converts a potentially silent
breakage into an explicit packaging compatibility requirement. The overlay
must be reviewed and rebuilt for each Plasma update until ArchPad adopts the
compositor-managed input-panel route or upstream Plasma gains a separate
lock-screen extension point suitable for this use case.

### Migration result

- Installed `archpad-keyboard 1.0.0-48`, containing only the keyboard daemon,
  settings companion, service, desktop entries, and sound asset.
- Installed `archpad-plasma-lockscreen 6.7.5-2`, pinned to Plasma,
  Plasma Workspace, and KScreenLocker 6.7.5.
- Installed `archpad-sddm-theme 1.0.0-2`, using the packaged ArchPad artwork
  instead of a synchronized user wallpaper.
- Removed the wallpaper synchronization executable and user units, tmpfiles
  state, home-directory scanning, display-config copy, and recursive removal
  hook from the keyboard package.
- Fixed the KWin/systemd check-then-register startup race by acquiring the
  `org.archpad.Keyboard` D-Bus name atomically before QML and `/dev/uinput`
  initialization. A cold reboot produced exactly one keyboard process.
- Verified real-touch lock/unlock and SDDM reboot/login successfully with the
  user.
- Verified zero altered files for all three ArchPad packages and upstream
  `plasma-desktop`, `plasma-workspace`, `kscreenlocker`, and `sddm`.

**Status:** SDDM release 4 is deployed; keyboard release 51 and lock-screen release 4 are prepared for deployment
**Current approval checkpoint:** FUTO qualification remains separate and unapproved
**Target:** Xiaomi Pad 6 (`pipa`), Arch Linux ARM `aarch64`, KWin/Plasma 6.7.5, Qt 6.11.2

### Final boundary and quality review — 2026-09-16

- Removed the migration-only dependency from `archpad-plasma-lockscreen` to
  `archpad-keyboard` and removed both secure keyboards' reads of the unlocked
  user's `keyboard.conf`.
- Made the secure keyboards derive their palettes from their own Kirigami
  theme, cleaned the lock-screen touch-exit no-op, modernized Qt state changes,
  and fixed all verified secure-keyboard layout-positioning diagnostics.
- Fixed the SDDM login signal handler for Qt 6.11 and pinned the copied Plasma
  theme implementation to `plasma-workspace=6.7.5`.
- Repaired click feedback with a 50 ms/48 kHz packaged asset, checked
  libcanberra errors, and routed modifier and symbol-mode keys through the same
  feedback path.
- Persisted Split Mode, removed the obsolete options-drawer D-Bus API, and
  corrected unchecked `/dev/uinput` writes.
- Added a narrow settings layout and removed all 43 settings and 24 main
  keyboard Qt layout-positioning diagnostics found by the tablet's Qt 6.11
  `qmllint`.
- Made settings-app D-Bus ownership atomic so rapid launches cannot create two
  settings windows.
- Installed and verified `archpad-keyboard 1.0.0-50` and
  `archpad-sddm-theme 1.0.0-4`. `archpad-keyboard 1.0.0-51` and
  `archpad-plasma-lockscreen 6.7.5-4` remain prepared locally because both USB
  and Wi-Fi SSH became unavailable before their final native build/deployment.
- Remaining architectural limitations, intentionally not changed in this
  repair: automatic visibility still uses KWin's private D-Bus surface, symbol
  coverage still mutates KDE `kxkbrc` options for `/dev/uinput`, and the secure
  QML component is duplicated between the two independent packages. Solving
  those requires a separately approved Wayland input-method/backend plan.

## 0A. Release 46 Quality Audit and Proposed Repairs

The following findings were verified against the current source and the live
tablet without changing source files, packages, configuration, or services.

### Small architecture-preserving fixes

1. Replace the 10 ms click asset with a short shaped sample long enough to
   survive the tablet's 21.3 ms PipeWire quantum. Check and log every
   libcanberra initialization, cache, and playback return value instead of
   silently ignoring failures.
2. Route modifier and symbol-mode key presses through the same click-feedback
   path as character, navigation, and Quick-Pad keys.
3. Persist `splitMode` in both the daemon and settings controller. The property
   currently changes live but is absent from both load/save implementations.
4. Replace raw `width`/`height` assignments on items managed by Qt Quick
   Layouts with `implicitWidth`/`implicitHeight` or `Layout.*` constraints in
   the keyboard header and drag bars.
5. Remove obsolete `optionsVisible` daemon API/state left behind when the
   in-surface options drawer was replaced by the companion settings app.
6. Remove the obsolete wallpaper synchronization path entirely as part of the
   package-boundary split.

### Responsive settings repair (medium-sized, no architecture change)

The companion settings application remains the correct `xdg_toplevel`
architecture. Its single landscape-oriented QML layout must be made responsive:

1. Add a portrait/narrow-window breakpoint and reduce navigation width at that
   breakpoint.
2. Constrain and elide/wrap the section title/subtitle, and adapt the fixed
   `Toggle Keyboard` action so it cannot push the header outside the window.
3. Reflow fixed horizontal preset groups into width-aware grids.
4. Reflow Quick-Pad's mandatory 300 px preview plus configurator from two
   columns into a vertically scrollable narrow layout.
5. Give all descriptive text a bounded width and wrapping, and let affected
   cards derive height from wrapped content.
6. Resolve the settings file's Qt 6.11 layout-positioning warnings rather than
   hiding overflow with clipping.

This is more than a tiny visual patch because every settings category is
affected, but it does not change the daemon, LayerShell keyboard surface,
D-Bus boundary, configuration format, or companion-app architecture.

### Separate approval required: package lifecycle

Do not include these changes in the small repair release without a separate
decision:

1. Stop copying `/home/archpad/.config/kwinoutputconfig.json` wholesale into
   SDDM state from the keyboard package install hook. Establish the correct
   owning package and migration path first.
2. Remove the recursive `post_remove` deletion of the complete
   `/usr/local/share/plasma/shells/org.kde.plasma.desktop` tree and rely on
   pacman ownership for packaged files, preserving unrelated local overlays.
3. Investigate repeated `kscreenlocker_greet` crash messages during
   suspend/resume with a focused real-hardware lock/unlock test before claiming
   that they originate in the ArchPad lock-screen QML.

### Validation for an approved quality repair

- Build and install the next package release through the normal package flow.
- Require a clean Qt 6.11 QML lint result for layout-positioning diagnostics.
- Verify every settings category in both 800x1280 portrait and landscape.
- Verify audible feedback for letters, navigation keys, Shift/modifiers,
  symbol-mode toggles, Quick-Pad keys, and held/repeating keys on real hardware.
- Restart the daemon and confirm Split Mode and all existing settings persist.
- Re-test hide/reopen behavior, popup special-key scrolling, floating dragging
  and resizing, Quick-Pad, lock/unlock, and settings single-instance behavior.
- Require zero altered files from `pacman -Qkk` for ArchPad and upstream KDE
  packages.

## 0. Baseline Repair Before Swipe Work

Complete and verify the following existing settings integration before any FUTO
Swipe qualification or gesture work begins:

1. Add a D-Bus-accessible `SetSoundEnabled(bool)` daemon slot that routes to
   the existing `setSoundEnabled()` implementation.
2. Add a D-Bus-accessible `SetFloatingWidth(double)` daemon slot and make the
   settings controller send it when floating width changes.
3. Add `longPressDelay` as a bounded daemon property, persist it in
   `~/.config/archpad/keyboard.conf`, expose `SetLongPressDelay(int)` over
   D-Bus, and make the settings controller synchronize it.
4. Replace the hardcoded QML key hold interval with the daemon's
   `longPressDelay` property. Keep Backspace/Space repeat timing independent.
5. Connect the settings application to the relevant daemon change signals so
   values remain synchronized in both directions.
6. Remove the trailing blank-line formatting defect reported by
   `git diff --check` without reformatting unrelated code.

The historical `currentTab` QML errors require no patch because the offending
references are absent from the current release-45 source.

### Baseline validation

- Build the current source on the tablet using the normal package workflow.
- Inspect the package contents before installation.
- Install as the next package release and restart only the keyboard user
  service and settings application if it is running.
- Confirm the new D-Bus methods are exported.
- Confirm sound, floating width, and long-press delay update the running daemon
  without requiring a restart.
- Test long-press behavior using real touch on the Xiaomi Pad 6.
- Recheck ordinary taps, Shift, Backspace, popup special-key scrolling, the hide
  button, QuickPad, and settings launch for regressions.
- Run `pacman -Qkk archpad-keyboard plasma-desktop kwin` and require zero
  altered files.

### Baseline boundaries

- Preserve every existing release-45 feature and all unrelated uncommitted
  work.
- Add no swipe code, model, candidate bar, gesture overlay, or dependency.
- Do not modify any file owned by an upstream package.
- Report the baseline results and wait for approval before beginning the FUTO
  engine qualification below.

### Baseline implementation result — 2026-09-15

- Added and verified `SetSoundEnabled`, `SetFloatingWidth`, and
  `SetLongPressDelay` on the live daemon D-Bus interface.
- Added two-way floating-width and long-press signal synchronization to the
  settings companion application.
- Bound secondary-key hold timing to the persisted daemon setting while
  leaving key-repeat timing independent.
- Built and installed `archpad-keyboard 1.0.0-46` on the Xiaomi Pad 6.
- Exercised all three setters with temporary values through the live daemon and
  restored the user's original values exactly.
- Verified the keyboard service is active and package integrity reports zero
  altered files for `archpad-keyboard`, `plasma-desktop`, and `kwin`.
- Real-touch regression checks remain for the user; no synthetic touch events
  were generated.

## 1. Objective

Determine whether the standalone FUTO Swipe C++ library is suitable as the
swipe-recognition engine for ArchPad Keyboard. The qualification must establish
licensing, reproducible packaging, correctness, latency, memory use, and runtime
stability on the real tablet before it is connected to the keyboard UI.

The intended long-term boundary is:

```text
ArchPad QML touch handling -> FUTO Swipe engine -> ranked candidates
```

ArchPad retains ownership of the keyboard UI, LayerShell/KWin lifecycle,
special keys, settings, candidate presentation, and text-commit backend.

## 2. Explicit Non-Goals

This qualification will not:

- import or fork the FUTO Android keyboard application;
- add swipe gesture handling or a trail to the visible keyboard;
- alter normal taps, modifiers, Backspace, Shift, or toolbar behavior;
- automatically insert words into applications;
- add a candidate bar;
- implement autocorrect, personalization, or general multilingual input;
- replace `/dev/uinput` or implement the Wayland input-method protocol;
- install a background service or enable anything at boot.

Any product integration will receive a separate plan and approval after this
qualification is reviewed.

## 3. Upstream and Licensing Boundaries

1. Use only the standalone `keyboard/swipe-library` project, licensed GPL-3.0.
2. Pin an immutable upstream commit; do not track a moving branch.
3. Treat FUTO model weights as separately licensed data.
4. Preserve the FUTO Model Weights License and attribution requirements.
5. Do not copy code from the Source First-licensed Android keyboard repository.
6. Record the licenses of ExecuTorch, XNNPACK, dictionaries, and every packaged
   dependency before distributing a build.

The neural models should be packaged separately from executable code if the
qualification proceeds to a distributable package. This keeps licensing,
updates, and optional installation explicit.

## 4. Qualification Work

### Phase A — Reproducible source and dependency audit

- Record the exact FUTO Swipe commit and model revisions.
- Inspect the complete dependency graph and licenses.
- Confirm the supported Linux `aarch64` build path.
- Determine whether the required ExecuTorch build can be reproduced from
  immutable sources without modifying any installed system package.
- Audit upstream's current test harness and independently surface failing
  assertions rather than trusting its reported pass count.
- Stop and report if licensing or reproducibility cannot be made clean.

**Result (2026-09-16): Complete — proceed with conditions.** The immutable
source/model/dependency record, licensing analysis, tablet toolchain check, and
truthful-test findings are recorded in
`artifacts/manifests/futo-swipe-phase-a-2026-09-16.md`. No keyboard or tablet
runtime files were changed. The upstream build must not be used unchanged:
Phase B requires pinned offline sources, tracked patches, and corrected test
failure propagation. Three real core assertions are currently hidden by two
upstream false-positive test runners and must be diagnosed in Phase B.

### Phase B — Isolated full-engine build

- Build the full neural pipeline with the encoder, English/QWERTY decoder, and
  English context model.
- Keep all work isolated from the current `archpad-keyboard` executable.
- Add no daemon, desktop entry, autostart unit, or D-Bus ownership.
- Produce a small command-line qualification tool that accepts normalized
  swipe points and prints the ranked candidates and timing data.
- Ensure inference is CPU-only and performs no network access at runtime.

**Result (2026-09-16): Complete.** The pinned encoder, English/QWERTY decoder,
and English context model built natively on the Xiaomi Pad 6 with ExecuTorch
and XNNPACK. The isolated CLI loaded all three models and returned ranked
candidates plus per-stage timings from normalized input. The corrected
non-neural suites passed 33/33, 4/4, and 10/10. No keyboard package or runtime
was changed. Exact hashes, findings, and the smoke result are recorded in
`artifacts/manifests/futo-swipe-phase-b-2026-09-16.md`. Stop before Phase C.

### Phase C — Automated engine validation

- Run upstream unit tests with corrected failure propagation.
- Add boundary checks for empty, very short, long, malformed, and out-of-range
  traces.
- Exercise repeated model initialization, decoding, and clean shutdown.
- Exercise layout/dictionary changes serially; the upstream engine is declared
  non-thread-safe, so no concurrent calls are permitted.
- Use the official public FUTO test traces to measure top-1 and top-4 accuracy.
- Record any divergence from upstream-published results rather than tuning
  scoring parameters to hide it.

Recorded traces are valid for decoder accuracy testing. They are not a
substitute for real touch validation once UI integration begins.

**Result (2026-09-16): Complete.** The corrected upstream suites pass 33/33,
4/4, 10/10, all three model metadata contracts, and 21/21 full-engine tests.
Boundary validation rejects malformed, empty, single-point, non-finite,
out-of-range, and non-monotonic traces; valid two-point and 10,000-point traces
decode successfully. Five independent full model load/decode/exit cycles
returned stable rankings. Serial layout, decoder, context-model, and dictionary
changes pass.

The pinned official first 20,000 non-single-letter test swipes produced
92.095% top-1 and 95.825% top-4 accuracy at FUTO's published beam width of
300. This is a 7.905% top-1 miss rate and 4.175% top-4 miss rate. Compared with
the published 7.38% / 4.19% miss rates, top-1 is 0.525 percentage points worse
while top-4 is 0.015 points better. No scoring parameter was tuned. Complete
inputs, hashes, fixes, and results are recorded in
`artifacts/manifests/futo-swipe-phase-c-2026-09-16.md`. The installed keyboard
remains unchanged. Stop before Phase D.

### Phase D — Real-tablet performance qualification

- Run the isolated command-line tool on the Xiaomi Pad 6.
- Measure cold model-load time, warm decode latency, p50/p95 latency, peak RSS,
  CPU time, installed size, and idle resource use.
- Test both 60 Hz and 120 Hz system modes where relevant to input sampling.
- Run a sustained decode loop to expose crashes, leaks, and thermal behavior.
- Verify the tool exits completely and consumes zero resources afterward.
- Verify `pacman -Qkk` reports no altered files for official packages.

**D1 result (2026-09-16): Complete — suitable to begin integration planning.**
At the accuracy configuration (beam 300, top-4, encoder + decoder + context
model, one model thread), 1,000 deterministic warm decodes measured 10.272 ms
p50 and 11.178 ms p95. Ten fresh processes initialized in 221.2 ms p50 and
227.7 ms p95 with warm filesystem cache. The benchmark observed 93.5 MiB PSS,
106.7 MiB peak RSS, and a 19.1 MiB distributable-size proxy. The process exited
cleanly and `archpad-keyboard 1.0.0-58` retained zero altered files. Memory is
the main integration constraint and must be explicit in the product design.
Full D2 endurance, thermal, true cold-cache/reboot, and 60/120 Hz sampling
checks remain required before release. See
`artifacts/manifests/futo-swipe-phase-d1-2026-09-16.md`.

## 5. Qualification Gates

The engine is suitable for a later UI integration plan only if:

- its code and model licenses can be distributed cleanly with ArchPad;
- the build is reproducible from pinned sources;
- all meaningful tests return a truthful success/failure status;
- the full model-backed engine runs natively on Linux `aarch64`;
- ranked candidates are stable and useful on the public English test set;
- measured latency is appropriate for interactive typing on the tablet;
- memory, storage, CPU, and thermal costs are acceptable when reviewed;
- runtime inference remains fully offline;
- no existing keyboard behavior or package integrity is changed.

Performance measurements will be presented to the user before setting final
product thresholds. No result will be silently accepted merely because it
builds.

## 6. Expected Deliverables

- An immutable record of upstream code/model revisions and all licenses.
- Reproducible build/package instructions for Linux `aarch64`.
- An isolated qualification CLI and its test results.
- Xiaomi Pad 6 latency, memory, size, CPU, and stability measurements.
- A concise recommendation: adopt, adopt with stated conditions, or reject.
- If adopted, a separate proposed plan for popup-keyboard touch collection,
  lightweight trail rendering, automatic top-candidate insertion, and three
  selectable alternatives.

## 7. Safety and Rollback

- Preserve all current uncommitted keyboard work.
- Do not modify files owned by upstream pacman packages.
- If a qualification package is installed, give it a distinct package name,
  install no persistent service, and track every file through pacman.
- Removal of that isolated package and its model-data package must restore the
  exact pre-qualification runtime state.
- Do not deploy any UI integration during this plan.

## 8. Approval Checkpoint

After approval, execute only the qualification described above. Return the
measurements and findings for review. Do not begin visible swipe typing or
keyboard integration without a second explicit approval.

**Integration checkpoint (2026-09-16):** Qualification phases A–C and the D1
essential performance gate are complete. The separate staged product plan is
`swipe_integration_plan.md`. Approval of that document authorizes its isolated
I0 Wayland text-commit proof only; it does not authorize a live keyboard
package change.
# Keypress Sound Profile Selector

**Status:** Implemented, built, and installed as `archpad-keyboard 1.0.0-56`.
Backend D-Bus, package integrity, asset hashes, and persistence were verified
on the Xiaomi Pad 6. Final hands-on portrait/landscape UI and subjective audio
selection remain for the user to confirm.

## Goal

Replace the single hardcoded keypress sound with four user-selectable,
volume-matched mobile keyboard profiles and an application-level volume
control in the existing settings companion.
This stays within the current libcanberra, D-Bus, INI settings, and companion
application architecture.

## Profiles

The four auditioned profiles are derived from Apache-2.0 Android Open Source
Project keyboard effects and normalized to approximately -18 dB peak:

1. `Standard` — subtle normal Android letter-key click.
2. `Soft` — rounder spacebar-style tap.
3. `Crisp` — shorter delete-style tap.
4. `Deep` — compact return-style tap.

The current high-volume `_120` asset is removed. Existing configurations that
do not yet contain a profile value migrate to `Standard`.

## Implementation

1. Package the four 48 kHz previewed assets under
   `/usr/share/archpad-keyboard/sounds/`, with upstream provenance, source
   hashes, transformation details, and Apache-2.0 licensing retained.
2. Add a bounded `soundProfile` daemon property (`0..3`), persist it as
   `General/soundProfile`, and resolve it to a fixed packaged path. Invalid or
   future values fall back to `Standard`.
3. Export `SetSoundProfile(int)` and `PreviewSoundProfile(int)` over the
   existing `org.archpad.Keyboard` D-Bus interface. Preview is an explicit
   settings action and does not emit a key event.
4. Add a bounded `soundVolume` property (`0..100`, default `70`), persist it as
   `General/soundVolume`, and export `SetSoundVolume(int)`. Convert the
   percentage to amplitude gain in decibels and pass it through
   libcanberra's standard `CA_PROP_CANBERRA_VOLUME`; `0` skips playback while
   `100` applies no gain above the already normalized asset level.
5. Mirror `soundProfile` and `soundVolume` in `SettingsController`, synchronize daemon changes
   in both directions, include it in reset-to-defaults, and preserve the
   existing independent sound-enabled switch.
6. Expand the existing Appearance & Sound card with four responsive selection
   buttons. Tapping a button selects and previews that profile immediately;
   the selected state is visually clear in portrait and landscape layouts.
   Add a keyboard-only `0..100%` volume slider with a live percentage label;
   slider changes affect previews and subsequent keypresses without changing
   the PipeWire system volume.
7. Remove the obsolete single high-volume asset and avoid embedding duplicate
   audio data in the executable when playback uses the installed files.

## Validation

- Build and install through pacman as the next `archpad-keyboard` release.
- Require `git diff --check`, a successful native ARM64 build, and `pacman
  -Qkk archpad-keyboard` with zero altered files.
- Verify all four choices preview, persist across daemon/settings restarts,
  and change real keypress audio without restarting.
- Verify `0%`, `70%`, and `100%` app volume levels, persistence, live preview,
  and that the PipeWire system sink volume is never modified.
- Verify the master sound switch still mutes every profile.
- Inspect the settings card in tablet portrait and landscape for clipping,
  overflow, or inaccessible options.
- Test real letter, modifier, navigation, held/repeating, and Quick-Pad keys on
  the Xiaomi Pad 6.

## Approval Checkpoint

Do not modify the daemon, settings controller, QML, or packaged sound set until
the user approves this profile-selector plan.
