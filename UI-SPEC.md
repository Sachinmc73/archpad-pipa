# ArchPad touch UI specification

Version: **draft 0.1 — 2026-09-09**

This is the interaction contract for the first ArchPad shell. It records user
intent before implementation so gestures, window state and visual behavior do
not evolve as unrelated one-off scripts.

## Design principles

- Touch-first and usable without the keyboard cover; keyboard and pen remain
  first-class.
- Low idle resource use: event-driven services, no frequent polling, and no
  animation work while surfaces are hidden.
- Large, reachable targets and short paths for common actions.
- One consistent scale and typography system, independently adjustable by the
  user.
- System gestures must be reversible, discoverable and inaccessible to normal
  applications only in narrow reserved edge regions.
- Every shell action has a keyboard-accessible equivalent and a TTY/SSH
  recovery path.

Initial performance budgets, to be measured rather than assumed:

- complete graphical idle below **800 MiB total RAM** on the 5.4 GiB device;
- shell/compositor below **1% average CPU** while visually idle;
- no continuous 120 Hz redraw when nothing is animating;
- user session usable within **3 seconds** after authentication.

## Surfaces and states

### Desktop

- Top bar: clock on the left, then numbered workspace indicators.
- Bottom dock: fully visible, with pinned apps, running indicators and a fixed
  ArchPad logo button that opens the application drawer.
- Desktop hosts app shortcuts and optional widgets. Normal mode does not steal
  touch focus; a deliberate edit mode enables move, resize and removal.
- Wallpaper and widgets are Quickshell background surfaces, not fake desktop
  windows managed by the compositor.

### App mode

- A single tiled application normally occupies the usable display and is
  treated as **tablet-maximized**, while narrow gesture-reveal regions remain.
- The dock hides when an application intersects its region. It reappears on
  the desktop and in Overview.
- True fullscreen is reserved for video, games and explicit application
  requests. A deliberate edge gesture must still recover system UI.

### Overview

- Shows all running and minimized applications as large cards grouped by
  workspace, with the dock visible at the bottom.
- Tapping a card activates it. Swiping a card away requests a graceful close;
  force termination is a separately confirmed action.
- Initial implementation may use application icon, title and state if reliable
  live thumbnails are not yet available. Live previews are polish, not a reason
  to use an unversioned compositor plugin.
- “Minimize” moves a window to an ArchPad-managed hidden workspace because
  Hyprland does not use the traditional desktop minimization model. Overview
  continues to show and restore it.

### Application drawer

- Full-screen searchable grid of GUI applications from freedesktop desktop
  entries; entries marked `NoDisplay` are excluded.
- Open by tapping the ArchPad logo or swiping upward from the dock.
- When Overview is already open, a second upward dock gesture opens the drawer.
- Supports pinned/recent categories first; arbitrary folders and advanced
  sorting are later polish.

### Quick settings

- Open with a downward/inward gesture beginning in the top-right edge zone, or
  by tapping the status area.
- A rounded right-side panel contains:
  - battery/charging state and date;
  - brightness and volume sliders;
  - Wi-Fi, Bluetooth, rotation lock, do-not-disturb, theme and OSK toggles;
  - audio output/input selection;
  - screenshot, Settings, Lock and Power actions.
- Hardware state comes from D-Bus/kernel interfaces (`iwd`, BlueZ, UPower,
  PipeWire and the ArchPad rotation service), not parsed command output.
- Destructive power actions require a second deliberate touch.

### Floating app mode and app pill

- A short pull from the top-center edge reveals a small app pill. Tapping it
  opens actions for Close, Minimize, Float/Tile, Snap Left, Snap Right and
  context-specific actions that are genuinely supported.
- A longer pull from the same top-center zone converts the current app to a
  centered floating window with a sensible tablet size.
- The pill remains visible above an ArchPad-floated window and acts as its
  touch drag handle.
- The pill invokes normal Hyprland close/move/resize/state operations; it never
  kills or reparents application processes to simulate window management.

## Gesture map

Gesture thresholds are configured in millimetres and converted from the
panel's physical size. This prevents scale and rotation changes from altering
the feel.

| Start region | Gesture | Result |
|---|---|---|
| Dock / bottom centre | upward | Desktop -> Drawer; App -> Overview; Overview -> Drawer |
| Bottom edge | short upward | App -> Overview |
| Top-right edge | downward/inward | Quick settings |
| Top-centre edge | short pull | Reveal app pill |
| Top-centre edge | long pull | Convert active app to floating mode |
| Left or right edge, lower half | inward | Best-effort application Back |
| Anywhere | three-finger horizontal | Previous/next workspace |

Initial dimensions at approximately 309 pixels per inch:

- reserved edge depth: **3 mm** (about 37 physical / 18 logical pixels at
  scale 2);
- gesture commit travel: **12 mm**;
- top-centre long-pull threshold: **30 mm**;
- minimum interactive target: **9 mm**, normally 48 logical pixels or larger.

### Gesture arbitration

- Multi-finger workspace gestures take priority over single-finger edge
  gestures.
- The top-right zone and top-centre zone do not overlap.
- Bottom corner starts wait briefly for direction: horizontal commits Back;
  vertical commits Overview.
- Until a system gesture passes its threshold, normal application input is not
  cancelled where the Wayland/compositor protocol permits this.
- Gesture sensitivity and handedness must be configurable.

“Back” is not a universal Linux window-system concept. Initially it sends the
standard application navigation shortcut (normally `Alt+Left`) through the
compositor and therefore works in browsers, file managers and many adaptive
apps, but not every application. ArchPad-native apps may later expose an
explicit navigation action. The gesture must never silently close an app when
navigation is unsupported.

## Window layout and rounded corners

- Default layout favors one tablet-maximized application. Split mode tiles two
  apps equally and permits a touch-draggable divider in a later iteration.
- Snap Left/Right uses compositor tiling, not arbitrary pixel positioning.
- Floating windows remember size and position separately for portrait and
  landscape when practical.
- Start with a **3.5 mm visual corner radius**. At this panel density and scale
  2 this is approximately 43 physical or 22 logical pixels. Calibrate visually
  against the Tianma panel corners rather than treating that estimate as final.
- System overlays use the same radius family; small controls use proportionally
  smaller radii.

## Scaling and typography

- Default compositor scale: **2.0**.
- Settings exposes display scale separately from shell/text size. Start with
  scale choices 1.5, 1.75 and 2.0, marking 2.0 as recommended.
- Shell typography uses named tokens (caption, body, title and display), all
  derived from one user-adjustable text-scale value.
- Do not apply both compositor and toolkit scale overrides globally; that
  causes double scaling and inconsistent application sizes.
- App grid labels and status controls must remain readable without truncating
  critical state at every supported scale.

## Implementation boundaries

- **Hyprland:** composition, workspace animation, window state, rounding,
  fullscreen, floating and device mapping.
- **Quickshell:** visible desktop, bar, dock, drawer, Overview, app pill and
  quick-settings surfaces.
- **archpad-session service:** rotation, keyboard-cover state, gesture policy,
  settings persistence and safe D-Bus adapters.
- **OSK:** proven external Wayland input method for the first GUI; future
  ArchPad Keyboard remains a separate component.

Quickshell can obtain Hyprland workspaces and toplevels and launch desktop
entries through supported APIs. Any missing capability must be proven before
adding a Hyprland plugin. Plugins are version-coupled to the compositor and
must not become silent release dependencies.

## Incremental build order

1. Prove Hyprland rendering, scale, touch/pen and clean return to TTY.
2. Create the static top bar and dock with clock/workspace/running-app state.
3. Add app drawer and ArchPad launcher button.
4. Add Overview and hidden-workspace minimization.
5. Add quick settings with brightness/volume first, then wireless controls.
6. Add edge gesture arbitration and workspace gestures.
7. Add app pill, float/minimize/snap actions and dock avoidance.
8. Add desktop widgets/edit mode and user-facing appearance settings.
9. Integrate the proven interim OSK and rotation/keyboard-cover policy.
10. Validate lock, suspend, crash recovery and resource budgets before
    enabling graphical login.

## First-release exclusions

- Gboard-class swipe/prediction/floating/split keyboard implementation;
- perfect live Overview thumbnails if the stable protocol path is incomplete;
- application-specific Back integrations beyond the standard shortcut;
- elaborate widget marketplace or downloadable shell extensions;
- voice and OS-level AI integration.

These exclusions preserve the architecture for later implementation; they are
not permission to omit basic touch text entry, accessibility or recovery.
