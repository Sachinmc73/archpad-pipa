# ArchPad Engineering Guidelines & Knowledge Base for AI Agents (`AGENTS.md`)

This file is the authoritative guide and persistent memory for all AI agents working on the ArchPad codebase. 
**Every agent MUST read and adhere to these guidelines before proposing or making changes.**

---

## 1. Core Engineering Philosophies & Hard Rules

1. **Zero Patchwork & Zero "Jugaads"**:
   - Never use hacky workarounds, arbitrary sleeps, polling loops, temporary sed scripts, or ALPM hooks that mutate third-party files.
   - Always solve problems cleanly at the root architectural layer using official, standard Linux / Freedesktop / Qt / Wayland mechanisms.

2. **Absolute Pacman Package Integrity**:
   - **NEVER modify or overwrite files owned by official upstream pacman packages** in `/usr/share/`, `/usr/lib/`, `/etc/`, etc.
   - Running `pacman -Qkk <package>` must ALWAYS return **0 altered files**.
   - Custom configurations, UI overlays, and shell overrides must use standard XDG precedence directories:
     - Priority order: `~/.local/share/` -> `/usr/local/share/` -> `/usr/share/`.
     - For example, custom lock screen shells belong in `/usr/local/share/plasma/shells/org.kde.plasma.desktop/`, cleanly tracked by our own `archpad-keyboard` package.

3. **Rigorous, Version-Aware Research First**:
   - Never jump straight to coding or editing files based on assumptions.
   - Check the exact running versions on the hardware:
     - Kernel: `uname -r` (e.g. `7.1.4-pipa-r12`)
     - Compositor: `kwin_wayland --version` (e.g. `6.7.5`)
     - Desktop: `plasmashell --version` (e.g. `6.7.5`)
     - Qt: `qmake6 --version` / `qt6-base` (e.g. `6.11.2`)
   - Research official documentation, git commits, and upstream source code for those specific versions.

4. **Planning & Approval Protocol**:
   - For any architectural change or non-trivial fix:
     1. Research deeply and diagnose the exact root cause.
     2. Explain the outcome clearly to the user.
     3. Present a formal Implementation Plan artifact (`implementation_plan.md`).
     4. Wait for explicit user approval before touching source code or packages.

5. **No Fake or Emulated Testing**:
   - Do NOT rely on synthetic/emulated mouse events to validate touch gestures.
   - Always verify touch interactions, dragging, resizing, typing, and locking directly on the real Xiaomi Pad 6 hardware via real touch events.

---

## 2. Hard-Learned Lessons & Architectural Knowledge Base

### A. Wayland Virtual Keyboard Architecture & The Focus-Stealing Trap
- **The Problem with `xdg_toplevel` for Virtual Keyboards**:
  - In Wayland, standard windows (`xdg_toplevel`) are managed as regular interactive applications.
  - When the user taps a text input field in Kate, Firefox, or Terminal, KWin activates the text field and signals `org.kde.kwin.VirtualKeyboard.active = true`.
  - **CRITICAL TRAP**: If the keyboard window is an `xdg_toplevel` window (even with `Qt.WindowDoesNotAcceptFocus`), touching the keyboard causes KWin to switch window focus to the keyboard.
  - The instant the keyboard gains focus, the text field in Kate/Firefox **loses focus**, the blinking cursor disappears, and KWin emits `VirtualKeyboard.active = false`.
  - In response, `KeyboardManager::onKWinActiveChanged()` receives `active = false` and calls `setIsVisible(false)`: **the keyboard immediately vanishes / hides ("it doesn't stay")!**
  - Furthermore, hardware keystrokes injected via `/dev/uinput` fail to reach the text field because it is unfocused.
- **The Proven Solution**:
  - Virtual keyboards **MUST REMAIN IN `LayerShellQt` (`zwlr_layer_surface_v1`)** with:
    ```qml
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    ```
  - In KWin's `layershellv1window.cpp`, `acceptsFocus()` checks this property and guarantees KWin **never activates the window or steals focus away from the underlying app**.
  - Text fields remain active, cursor stays blinking, and the keyboard stays firmly open on the screen.

### B. Clean Lock Screen Architecture
- **Packaging via `/usr/local/share/`**:
  - `kscreenlocker_greet` loads its UI via `KPackage::PackageLoader::self()->loadPackage("Plasma/Shell")`.
  - `KPackage` prioritizes `/usr/local/share/` over `/usr/share/`.
  - We install `ArchpadLockKeyboard.qml` and `LockScreenUi.qml` into `/usr/local/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/`.
  - Upstream `plasma-desktop` remains 100% pristine. `pacman -Syu` upgrades will never touch or revert our files.
- **The Touch Bouncing Bug**:
  - Upstream `LockScreenUi.qml` contains `onExited: { uiVisible = false; }` in a `MouseArea`.
  - On touchscreens, releasing a finger synthesizes an exit event, snapping the login prompt closed.
  - Removing `onExited: { uiVisible = false; }` in our `/usr/local/share` package latches the lockscreen open on swipe/tap until unlocked or dismissed.

### C. System Boot Speed & Sensor Integration
- **SDDM & Orientation Sensor**:
  - Never add hard systemd dependencies like `After=iio-sensor-proxy.service` to `sddm.service` (stalled cold boots by 50 seconds).
  - KWin connects dynamically to `net.hadess.SensorProxy` over D-Bus via `QDBusServiceWatcher` when the service becomes available.
