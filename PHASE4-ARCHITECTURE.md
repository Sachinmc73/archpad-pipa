# ArchPad Phase 4 touch-session architecture

Decision date: **2026-09-09**

This document fixes the Phase 4 direction before any graphical packages are
installed. It is intentionally an architecture and validation contract, not a
claim that the chosen session is already working.

## Decision

Build ArchPad's own touch-first session on this stack:

```text
systemd/logind
  -> UWSM-managed Hyprland Wayland session
  -> archpad-session policy services
       - display scale and orientation
       - touch and pen mapping
       - OSK visibility and keyboard-cover policy
       - idle, lock and power actions
  -> Quickshell tablet shell
       - launcher / overview
       - top status and quick settings
       - notifications and media controls
  -> native Wayland applications
```

The choice is **Hyprland**, not an Omarchy installation. ArchPad borrows the
small, composable and highly customisable character of Omarchy, while owning
its tablet interaction policy and package set.

Initial repository versions observed on the tablet on the decision date are:

| Role | Package | Version |
|---|---|---|
| compositor | `hyprland` | 0.56.1-3 |
| systemd session wrapper | `uwsm` | 0.26.7-1 |
| programmable shell | `quickshell` | 0.3.1-1 |
| compositor portal | `xdg-desktop-portal-hyprland` | 1.4.1-2 |
| fallback file-picker portal | `xdg-desktop-portal-gtk` | 1.15.3-1 |
| rotation sensor service | `iio-sensor-proxy` | 3.9-1 |
| secure screen locker | `hyprlock` | 0.9.6-3 |
| idle policy | `swayidle` | 1.9.0-1 |
| first OSK candidate | `squeekboard` | 1.43.1-5 |
| future login manager | `greetd` | 0.10.3-2 |

These are rolling repository observations, not permanently pinned release
inputs. The final v0.1 manifest must record the exact installed package
versions and repository state.

## Why this stack

### Hyprland

Hyprland supplies the required Wayland protocols, per-device touchscreen and
tablet-to-output mapping, output transforms, touch workspace gestures,
fractional scaling, and direct Quickshell integration. It is the closest match
to the requested lightweight, Omarchy-inspired and deeply customisable system.

### UWSM

UWSM gives the otherwise standalone compositor a proper systemd user-session
lifecycle, environment import, XDG autostart integration and clean shutdown.
Applications and ArchPad session components should be systemd user units or
UWSM-managed applications, not an unordered chain of compositor `exec`
commands.

### Quickshell

Quickshell is the UI construction layer, not the compositor and not a security
boundary. Its QML components can expose Hyprland workspaces, PipeWire, BlueZ,
UPower, notifications and media state while letting ArchPad build a genuinely
tablet-shaped interface.

### Alternatives retained as references

- **Niri** has excellent session design, output/input mapping and an attractive
  touch overview, but currently has less direct touchscreen-workspace behavior
  and no first-class Niri workspace integration in Quickshell's published
  integration list. Reconsider it if Hyprland proves unreliable on this GPU.
- **Phosh** has the most integrated phone/tablet behavior and Squeekboard path,
  but its opinionated GNOME mobile stack is a poorer fit for the custom
  Quickshell goal.
- **Plasma** already proved this hardware can provide a usable desktop and
  remains a valuable behavior reference, but it is not the lightweight custom
  base selected for ArchPad.
- **Sway** is stable and simple but would require more custom tablet behavior
  while providing fewer benefits than Hyprland for this design.

## Non-negotiable behavior

### Display and input

- Start at integer scale **2.0** on the 1800x2880 panel: 900x1440 logical
  pixels in portrait and 1440x900 in landscape. Test 1.75 later only if the
  extra space materially improves use without introducing application blur or
  sizing inconsistency.
- Bind both the Novatek touchscreen and Xiaomi pen tablet to `DSI-1` by their
  stable device identities, never by changing `/dev/input/event*` numbers.
- Rotation must update output orientation and verify touch/pen coordinates as
  one policy action. Do not ship a state where the picture rotates while touch
  remains mapped to the old orientation.
- Automatic rotation consumes the IIO sensor through `iio-sensor-proxy` and is
  inhibited while the keyboard cover is in laptop use. A quick-settings toggle
  must allow rotation lock.
- Preserve ten-point multitouch, dragging, pressure and tilt during every
  orientation.

### On-screen keyboard

The final target is a **Gboard-class tablet keyboard**, not merely a row of
clickable keys. ArchPad requires:

- normal docked mode;
- a draggable, resizable phone-sized floating mode;
- a split thumb layout for two-handed tablet use;
- continuous swipe-to-type with candidate words and correction;
- multiple languages, quick language switching, emoji and appropriate
  password/number/URL/terminal layouts;
- automatic appearance, manual override and keyboard-cover-aware suppression;
- local/private dictionaries and prediction by default;
- a future voice-input button, without making voice work part of Phase 4.

No currently mature Linux Wayland keyboard has been verified to provide this
whole experience. Therefore the OSK plan has two levels:

1. **Dependable interim OSK:** first test repository-packaged Squeekboard. It
   implements the Wayland input-method-v2 and virtual-keyboard protocols that
   Hyprland exposes and has touch-oriented, language-specific and terminal
   layouts. If its Hyprland integration fails, test the maintained `wvkbd`
   source as a pinned native package; it documents automatic input-method
   activation, international/emoji layouts, orientation-aware layouts and an
   optional external swipe-word pipeline.
2. **ArchPad Keyboard:** after the core GUI is dependable, build or adopt a
   native component with floating and split surfaces plus an offline swipe and
   prediction engine. Prefer Wayland input-method/virtual-keyboard protocols
   over unrestricted `/dev/uinput` injection. Keep UI, input transport,
   language data and prediction engine separable so each can be replaced.

Qt Virtual Keyboard is a useful source of QML, multilingual, predictive and
trace-input concepts, but is primarily an application/compositor integration
framework rather than a proven system-wide Hyprland OSK. Maliit is multilingual
but is unavailable in the tablet's current repositories and does not supply the
requested complete mode set. Onboard's Wayland support is explicitly
experimental outside KDE/GNOME.

Very new projects that claim more complete behavior may be evaluated in an
isolated source audit, but not adopted as trusted session infrastructure based
only on a feature list. In particular, Aurora Keyboard currently has no
release/package history, relies on privileged `/dev/uinput`, and its neural
engine uses FUTO-derived components with licensing that must be reviewed before
redistribution. `kway` demonstrates a split layout but still lists autocorrect
and auto-rotation as future work.

Automatic OSK appearance is a release gate, not something inferred from an OSK
window appearing manually.

Compatibility must be tested in GTK, Qt, Chromium/Electron and a terminal for:

1. appearing when a touch-focused editable field requests text input;
2. hiding when focus leaves the field;
3. correct password, number, URL and terminal layouts;
4. no lost focus or covered text field;
5. manual show/hide override;
6. suppression when the keyboard cover is usable, without disabling an
   explicit manual request.

Squeekboard documents Phosh as its primary shell. Its presence in the Arch
repository and matching protocols make this a justified experiment, **not yet
a verified Hyprland solution**. It is an interim input method, not the final
Gboard-class design. If it fails the matrix, stop and evaluate the pinned
`wvkbd` path or another maintained alternative as a separately packaged
component; do not force-show it permanently or patch applications.

### Login, locking and secrets

- First bring-up starts manually from TTY1. Keep `multi-user.target`, SSH and
  the console login available so a broken GUI cannot strand the tablet.
- Use `hyprlock` through the session-lock protocol for the first secure lock
  implementation. Validate PAM authentication, failure behavior, suspend
  locking and that killing shell UI does not expose the session.
- Quickshell may draw ordinary shell surfaces, but it must not imitate a lock
  screen unless it is using a correct session-lock and PAM design.
- Add `greetd` only after the compositor, lock and OSK pass their gates. Do not
  enable automatic login in the release configuration. A custom graphical
  greeter is optional and comes after reliable touch authentication.
- Development credentials may remain convenient during construction as the
  owner requested. Release documentation must require changing them.
- A short power press must lock successfully before logind suspends. Wake
  returns to that PAM-authenticated lock, never directly to the desktop. A long
  press is handled by the shell as a power-menu request with explicit Sleep,
  Log out, Restart and Shut down choices; logind must not turn it directly into
  power-off.

### Portals and desktop integration

Use `xdg-desktop-portal-hyprland` for compositor-specific screen capture and
`xdg-desktop-portal-gtk` for generic chooser/settings interfaces. Add another
portal only for a demonstrated missing interface; multiple overlapping portal
backends must not be installed speculatively.

Polkit and the secrets/keyring service must run inside the graphical user
session with correct PAM integration. File pickers, opening links, screen
sharing and sandboxed applications are explicit tests.

## Package boundary

Create one new native package, `archpad-session`, for ArchPad-owned policy:

```text
/usr/share/archpad-session/           versioned defaults and scripts
/usr/lib/systemd/user/                session policy units
/usr/share/wayland-sessions/          final UWSM session entry, when proven
/usr/share/xdg-desktop-portal/        explicit portal preference
/etc/xdg/archpad/                     administrator-overridable defaults
```

User customisations live under `~/.config/` and are never overwritten on
upgrade. Device kernel, firmware, camera and audio data remain in their current
packages; the GUI package must not own or mutate them.

Quickshell UI is independently packaged as `archpad-shell`; even its first
bar/dock slice has a meaningful release, validation and rollback lifecycle.
`archpad-session` remains limited to compositor and session policy.

## Staged implementation and stop points

### 4A — Architecture: complete

- Choose the stack and boundaries.
- Record exact available package versions and known uncertainty.
- Make no tablet package changes.

### 4B — Reversible compositor proof

- Install only the compositor/session, portal, polkit, keyring and one terminal
  needed for a meaningful proof.
- Launch Hyprland manually from TTY1 through UWSM; do not enable a display
  manager or change the default target.
- Verify native resolution/120 Hz, scale 2, Freedreno rendering, touch, pen,
  keyboard cover, clean exit to TTY and suspend/resume.
- Stop and revert the Phase 4 packages if the compositor has GPU/display/input
  instability.

### 4C — Rotation and mapping

- Add the sensor-driven policy service in `archpad-session`.
- Test all four orientations, touch corners, multitouch, pen coordinates,
  rotation lock and cover attach/detach.

### 4D — OSK gate

- Test Squeekboard against the full application matrix above.
- If necessary, package and test a pinned `wvkbd` revision as the interim OSK.
- Record a separate ArchPad Keyboard design for floating, split, swipe,
  prediction and multilingual behavior; do not block the basic GUI on building
  that full keyboard immediately.
- Do not proceed to shell polish until touch text entry is reliable.

### 4E — Quickshell shell

- Build a large-target launcher/overview, status area, quick settings,
  notifications, brightness/volume controls and explicit OSK/rotation toggles.
- Keep all critical actions usable from touch and keyboard.

### 4F — Secure daily session

- Validate hyprlock/PAM, idle locking, suspend locking, logout/restart/poweroff,
  crash recovery and session resource use.
- Only then add and enable the graphical login path.

### 4G — Tablet and developer applications

- Add browser/media, note/pen, file management and terminal/development tools
  in small reviewed groups.
- Capture the final package manifest, build the release image and test a clean
  installation plus package update and rollback.

Voice integration remains a later polish phase. OS-level AI and Gemini remain
last, after the system is a dependable tablet and development machine.

## Phase 4 acceptance gate

Phase 4 is complete only when a cold boot and a suspend/resume cycle preserve:

- accelerated Wayland rendering and correct scale;
- touch, drag, multitouch and pen mapping in every supported orientation;
- automatic and manual OSK behavior with and without the keyboard cover;
- working audio, camera, Wi-Fi, Bluetooth, brightness and battery controls;
- secure lock/PAM behavior and clean logout;
- a usable TTY/SSH recovery path;
- zero newly failed systemd units and no new unexplained error class.

The unrelated platform restart-path issue and missing `CONFIG_CRYPTO_USER`
remain tracked low-level work and must be resolved before the first public
release, even though they do not block the reversible compositor proof.
