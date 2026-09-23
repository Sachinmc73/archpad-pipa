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

### D. Touch Screen Dragging & Frame-Rate Invariant Exponential Damping
- **The Runaway Accumulator Bug**:
  - Sampling touch offset once on touch-down (`grabOffsetX = p.x`) and computing `targetX = root.windowX + (p.x - grabOffsetX)` on every touch event causes runaway oscillation because KWin updates window margins asynchronously on vsync. Touch events arriving before the next frame evaluate against an already-incremented requested position.
- **Fixed Discrete Gain ($\alpha$) vs Display Refresh Rate**:
  - Applying a fixed discrete gain (e.g. $\alpha = 0.55$) works well at 120Hz ($8.3\text{ ms}$ frame time).
  - However, at 60Hz ($16.7\text{ ms}$ frame time), the hardware touch digitizer emits 2 to 4 touch events per display frame. Compounding over multiple events raises effective gain to $(1 - (1 - \alpha)^N) \approx 0.91 - 0.96$, reintroducing jitter and instability.
- **The Continuous Time-Delta Solution ($\Delta t$)**:
  - Always use continuous time-delta exponential damping:
    $$\alpha(\Delta t) = 1.0 - \exp(-\lambda \cdot \Delta t)$$
    where $\Delta t = (t - t_{\text{last}})/1000.0$ and $\lambda \approx 96.0\text{ s}^{-1}$.
  - Because $(1 - \alpha(\Delta t_1)) \cdot (1 - \alpha(\Delta t_2)) = e^{-\lambda (\Delta t_1 + \Delta t_2)}$, physical convergence is **strictly invariant across 60Hz, 90Hz, 120Hz, and 144Hz**.
- **Capacitive Touch Deadband**:
  - Always filter out microscopic ADC sensor noise ($\pm 0.2\text{px}$ to $0.5\text{px}$) when stationary via a small deadband (`Math.abs(err) < 0.5 -> 0`) to prevent unnecessary GPU repaints and micro-jitter while resting.

### E. Display Timing Parity & Gate Driver Phase (Novatek NT36532 / Dual-DSI)
- **Even Line Parity Requirement ($V_{\text{total}} \pmod 2 == 0$)**:
  - The Novatek NT36532 panel DDIC uses dual-line (2H) gate driver multiplexing.
  - Total vertical lines ($V_{\text{total}} = V_{\text{active}} + V_{\text{fp}} + V_{\text{pw}} + V_{\text{bp}}$) **MUST be strictly even**.
  - If $V_{\text{total}}$ or $V_{\text{fp}}$ is odd, the gate driver clock inverts phase between frames, triggering an internal timing fault in the DDIC and shutting down output (black screen).
  - On the SoC side, this stalls the DSI link, logging `dsi_err_worker: status=5` ($0\text{x}1 \; \text{DSI\_ERR\_STATE\_TIMEOUT} \;|\; 0\text{x}4 \; \text{DSI\_ERR\_STATE\_FIFO}$).
  - All custom refresh rate modes MUST round $V_{\text{total}}$ to the nearest **even integer** (e.g., $V_{\text{total}} = 4164$ for 90Hz, $V_{\text{total}} = 7806$ for 48Hz).

### F. Keyboard Backlight D-Bus Ghost Interface & PowerDevil Architecture
- **The Upstream UPower & PowerDevil Logic Mismatch**:
  - Freedesktop's `upowerd` unconditionally exports a static singleton D-Bus path at `/org/freedesktop/UPower/KbdBacklight` on every machine, even when 0 physical keyboard LEDs exist in `/sys/class/leds`. When no hardware is present, it returns `GetMaxBrightness() = 0` and `NativePath = ""`.
  - In KDE Plasma 6's PowerDevil (`daemon/controllers/keyboardbrightnesscontroller.cpp`), it queries `GetMaxBrightness()` and checks:
    ```cpp
    QDBusPendingReply<int> rep = m_kbdBacklight->GetMaxBrightness();
    if (rep.isValid()) {
        m_maxBrightness = rep.value(); // = 0
        m_isSupported = true; // Flaw: checks D-Bus reply validity, NOT if maxBrightness > 0!
    }
    ```
  - Because `upowerd` replies successfully with integer `0`, `rep.isValid()` evaluates to `true`. PowerDevil registers `/org/kde/Solid/PowerManagement/Actions/KeyboardBrightnessControl` and Plasma's Brightness applet renders a dummy 0/0 slider in the system tray.
- **Clean Zero-Patchwork Resolution via D-Bus Policy**:
  - We do not patch upstream C++ or QML binaries.
  - Instead, we install `/etc/dbus-1/system.d/10-archpad-no-kbd-backlight.conf`, cleanly tracked and packaged in `archpad-pipa-device`:
    ```xml
    <!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
     "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
    <busconfig>
      <policy context="default">
        <deny send_destination="org.freedesktop.UPower"
              send_interface="org.freedesktop.UPower.KbdBacklight"/>
      </policy>
    </busconfig>
    ```
  - Screen brightness, battery status, and sleep controls remain 100% operational, and `pacman -Qkk` integrity remains pristine (0 modified files).

### G. SDDM Display Orientation, Sensor DSP Boot Timing & Polkit Sensor Claim
- **The Polkit Sensor Claim Trap for Display Managers**:
  - `iio-sensor-proxy` defines `net.hadess.SensorProxy.claim-sensor` with `allow_active: yes`, `allow_any: no`, `allow_inactive: no`.
  - In `systemd-logind` / `polkit`, SDDM's greeter session (running as user `sddm`) is classified as `greeter`, NOT an `active` user session.
  - When KWin under SDDM attempts to call `net.hadess.SensorProxy.ClaimAccelerometer`, D-Bus returns `Error org.freedesktop.DBus.Error.AccessDenied: Not Authorized: Sensor claim not allowed`.
  - **Resolution**: Install a polkit rule in `/usr/share/polkit-1/rules.d/10-archpad-power.rules` (packaged cleanly in `archpad-pipa-device`):
    ```javascript
    polkit.addRule(function(action, subject) {
        if (action.id == "net.hadess.SensorProxy.claim-sensor" && subject.user == "sddm") {
            return polkit.Result.YES;
        }
    });
    ```
- **Cold-Boot Sensor Delay & Fallback Orientation**:
  - On cold boot, Qualcomm Snapdragon Sensor DSP (`hexagonrpcd` / `archpad-wait-ssc`) takes ~45 seconds to initialize firmware sensors.
  - SDDM starts in ~2 seconds. During the initial ~45 seconds, KWin has no sensor data and falls back to `/var/lib/sddm/.config/kwinoutputconfig.json`.
  - The physical Novatek NT36532 panel is natively portrait (1800x2880), so `"transform": "Normal"` forces portrait.
  - Setting `"transform": "Rotated270"` with `"scale": 2.25` and `"autoRotation": "Always"` ensures SDDM boots directly in landscape, and once sensors are online, seamlessly auto-rotates when tilted.

### H. SDDM Theme Independence
- **No User-Home or Keyboard Coupling**:
  - User home directories are `0700`; the `sddm` user must not read a user's lock-screen configuration, wallpaper, or keyboard settings.
  - `archpad-sddm-theme` owns its theme and uses packaged `archpad-artwork` as its background.
  - Do not restore wallpaper-copy watchers, keyboard-owned tmpfiles state, home-directory scanning, or user-to-SDDM configuration copying.
  - The SDDM secure keyboard derives its palette from its own Kirigami theme and remains independent from the unlocked-session `archpad-keyboard` daemon and configuration.

### I. Virtual Keyboard Settings & The "Chicken-and-Egg" In-Surface Input Paradox
- **The Dilemma**:
  - The virtual keyboard daemon runs in `LayerShellQt` (`zwlr_layer_surface_v1`) with `keyboardInteractivity: KeyboardInteractivityNone` to ensure KWin never shifts focus away from active application text fields (Kate, Firefox, Terminal, Edge).
  - Consequently, an in-surface configuration drawer or popup within the keyboard surface cannot accept text input (e.g., typing custom macro labels or keycodes). Attempting to enable interactive keyboard focus inside a layer-surface causes focus oscillation and dismisses the keyboard.
- **The Clean Architecture (The Gboard Companion App Pattern)**:
  - Decouple keyboard settings into a dedicated standalone `xdg_toplevel` companion application (`archpad-keyboard-settings`).
  - Being a standard application window, tapping any `TextField` inside the settings companion app causes KWin to automatically summon `archpad-keyboard`, allowing the user to type custom labels and shortcuts with the full virtual keyboard.
  - The main typing daemon stays substantially smaller than keeping the
    companion settings UI resident. Do not quote the historical `~6.8 MB`
    figure: the Qt 6.11 service measured about 40 MB immediately after a hidden
    restart and can retain more after rendering. Re-measure RSS/PSS as part of
    each performance qualification.
  - When closed, the companion application consumes **0 MB RAM and 0% CPU**.
  - Real-time two-way IPC over D-Bus (`org.archpad.Keyboard` <-> `org.archpad.KeyboardSettings`) and INI configuration (`~/.config/archpad/keyboard.conf`) keeps keyboard parameters synchronized instantaneously.

### J. Mobile MIPI DSI Video-Mode Panel Sequencing & The DSI FIFO Collision
- **The Dual-DSI / DSC Command-During-Video Pitfall**:
  - In Qualcomm SM8250 bonded dual-DSI video mode, active pixel streaming is driven by continuous hardware timing engines (`msm_dsi_bridge_enable()`).
  - Mobile panels with Display Stream Compression (DSC) like Novatek NT36532 MUST receive panel initialization, DSC Picture Parameter Set (PPS), and compression enabling commands strictly during `.prepare = nt36532_prepare` while the DSI host is in Low-Power Command Mode (LPM).
  - **CRITICAL TRAP**: If the panel driver also defines `.enable = nt36532_enable` and transmits DSC PPS or display-on commands there, DRM modeset will start the active video stream *before* `.enable` executes. Firing command DMA packets into an active video stream starves the DSI DMA hardware FIFO, logging `dsi_err_worker: status=5` ($0\text{x}1 \; \text{TIMEOUT} \;|\; 0\text{x}4 \; \text{FIFO}$).
  - In KWin Wayland, missed pageflips hit `s_pageflipTimeout = 1000ms`, causing KWin to trigger emergency connector crash recovery (`DPMS OFF` $\rightarrow$ `DPMS ON`), manifesting to the user as a violent double-flash on wake (Flash 1 $\rightarrow$ Dark $\rightarrow$ Flash 2).
  - **The Resolution**: Omit `.enable` and `.disable` completely from `drm_panel_funcs`, exactly as validated upstream in `drm-misc-next`. All DCS setup and PPS transmission belong strictly in `.prepare`, and power supply shutdown belongs in `.unprepare`.
- **Novatek Charge Pump Stabilization**:
  - Always give at least 120 ms delay (`msleep(120);`) after `mipi_dsi_dcs_exit_sleep_mode()` before calling `mipi_dsi_dcs_set_display_on()` to allow the panel's internal charge pumps and gate driver clock oscillator to reach steady state.
- **Sleep Delay Inhibitor Synchronization**:
  - Never use arbitrary sleeps (`LOCK_SETTLE_MS`) before calling logind `Suspend()`.
  - Let KWin's built-in sleep delay inhibitor (`compositor ... sleep Ensuring that the screen gets locked before going to sleep delay`) handle session locking and display blanking deterministically before s2idle kernel freeze.

### K. Canonical System Architecture & Atomic Build Inventory
- **Living Document Mandate**:
  - The canonical architectural documentation lives in:
    - **Interactive Atomic Build Inventory**: [`docs/ARCHPAD-SYSTEM-BUILD-INVENTORY.html`](file:///home/sachin/projects/personal/archpad/docs/ARCHPAD-SYSTEM-BUILD-INVENTORY.html)
    - **In-Depth Architecture Reference**: [`docs/ARCHPAD-SYSTEM-ARCHITECTURE.md`](file:///home/sachin/projects/personal/archpad/docs/ARCHPAD-SYSTEM-ARCHITECTURE.md)
  - **Every agent working on this codebase MUST update both documents** whenever:
    1. A new package, kernel module, patch, firmware blob, daemon, or udev/polkit rule is added, updated, or removed.
    2. The partition layout, bootloader chain, or storage architecture changes.
    3. Hardware workarounds, D-Bus policies, or desktop shell overrides are altered.
  - The inventory tracks all atomic building blocks spanning Silicon (Layer 0), Bootloader (Layer 1), Kernel (Layer 2), Platform (Layer 3), and Desktop (Layer 4), including their physical disk locations, build recipes, provenance, and architectural rationale.

