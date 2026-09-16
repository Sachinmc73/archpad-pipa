# ArchPad System Handoff & Technical Briefing (for Codex / Future Agents)

**Last Updated**: 2026-09-16 13:10 IST
**Target Hardware**: Xiaomi Pad 6 (`pipa`) / Qualcomm Snapdragon 870 (SM8250)  
**Primary Git Branch**: `fixes/system-usability`  
**Working Tree Status**: Intentional uncommitted keyboard/package work is present; preserve unrelated changes

---

## 1. System Overview & Hardware Architecture

| Subsystem | Specification / Version |
| :--- | :--- |
| **SoC** | Qualcomm Snapdragon 870 (SM8250), Adreno 650 GPU (Mesa freedreno) |
| **Display Panel** | Novatek NT36532 (Tianma), 1800x2880 native portrait, dual-DSI with DSC |
| **Refresh Rates** | 120Hz (default/smooth), 60Hz (power save) |
| **Kernel** | `linux-archpad-pipa 7.1.4-16` (generation `7.1.4-pipa-r16`) |
| **Operating System** | Arch Linux ARM (`aarch64`), systemd, PAM, standard glibc |
| **Display Server** | Wayland via KWin 6.7.5 (`kwin_wayland`) |
| **Desktop Shell** | KDE Plasma 6.7.5 (`plasmashell`) |
| **Display Manager** | SDDM 0.21.0 on Wayland (with custom `archpad` theme) |
| **Toolkit** | Qt 6.11.2 (C++20 / QtQuick / QML) |
| **Network & SSH** | Wi-Fi DHCP (currently `192.168.29.231`; previous `192.168.1.4` is stale) & USB Gadget (`172.16.42.1`) |

---

## 2. Core Engineering Philosophies & Hard Rules

Codex / future agents **MUST strictly adhere** to the following project guidelines (defined in `AGENTS.md`):

1. **Zero Patchwork & Zero "Jugaads"**:
   - Never use arbitrary `sleep` hacks, polling loops, temporary sed scripts, or ALPM hooks that modify third-party packages.
   - Problems must always be resolved cleanly at the architectural layer using standard Linux, Freedesktop, Qt, and Wayland mechanisms.
2. **Absolute Pacman Package Integrity**:
   - **NEVER modify or overwrite files owned by official upstream pacman packages** in `/usr/share/`, `/usr/lib/`, `/etc/`, etc.
   - Running `pacman -Qkk <package>` must ALWAYS return **0 altered files**.
   - Custom configurations, UI overlays, and shell overrides must use standard XDG precedence directories:
     `~/.local/share/` -> `/usr/local/share/` -> `/usr/share/`.
3. **Rigorous Hardware & Version Awareness**:
   - Verify changes on real hardware via touch events, not synthetic mouse events.
   - Screen capture on Wayland via `/usr/local/bin/kwin-shot <path.png>` (run as user `archpad` with `XDG_RUNTIME_DIR=/run/user/10000`).

---

## 3. Key Components & Architectural Knowledge Base

### A. Virtual Keyboard Subsystem (`packages/archpad-keyboard`)
- **Focus-Stealing Trap**: Virtual keyboards in Wayland **must never use `xdg_toplevel`**. Touching an `xdg_toplevel` steals KWin focus, causing the active text field to blur and KWin to deactivate the keyboard.
- **LayerShellQt Solution**:
  - Anchored as a `zwlr_layer_surface_v1` overlay with:
    ```qml
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    ```
  - Direct hardware keystroke injection via `/dev/uinput` (`linux/uinput.h`).
- **Butter-Smooth 120Hz Dragging & Resizing**:
  - Uses continuous time-delta exponential damping:
    $$\alpha(\Delta t) = 1.0 - \exp(-\lambda \cdot \Delta t) \quad (\lambda \approx 96.0\text{ s}^{-1})$$
  - Invariant across display refresh rates (60Hz, 120Hz).
  - Deadband filtering for touch ADC sensor noise (`Math.abs(err) < 0.5 -> 0`).
- **Independent Lock-Screen Integration**:
  - `archpad-keyboard` contains only the unlocked-session keyboard daemon and settings companion.
  - The version-pinned `archpad-plasma-lockscreen` package owns the Plasma shell overlay under `/usr/local/share/plasma/shells/org.kde.plasma.desktop/`.
  - The secure keyboard neither runs nor reads configuration from `archpad-keyboard`.
  - Upstream `plasma-desktop`, `plasma-workspace`, and `kscreenlocker` files remain pristine.
- **Daemon Lifecycle**:
  - Started by `archpad-keyboard.service` with `--daemon` on login.
  - Controlled dynamically via `--show`, `--hide`, `--toggle`, or KWin VirtualKeyboard D-Bus state.

### B. Independent SDDM Login Theme
- **Touch Screen Keyboard at Login**:
  - `archpad-sddm-theme` owns the standalone theme under `/usr/share/sddm/themes/archpad/`.
  - It uses packaged ArchPad artwork and does not read user-home wallpaper or keyboard configuration.
  - No wallpaper watcher, tmpfiles state, or user-to-SDDM configuration copying exists.
- **SDDM Sensor Claim & Auto-Rotation**:
  - Polkit rule in `/usr/share/polkit-1/rules.d/10-archpad-power.rules` authorizes user `sddm` to claim `net.hadess.SensorProxy.claim-sensor`.
  - Fallback orientation configured in `/var/lib/sddm/.config/kwinoutputconfig.json` with `"transform": "Rotated270"` so cold boots start in landscape immediately.

### C. Power & Hardware Integration (`packages/archpad-pipa-device`)
- **Ghost Keyboard Backlight Fix**:
  - Upstream UPower exports a static D-Bus singleton `/org/freedesktop/UPower/KbdBacklight` even with 0 physical keyboard LEDs. PowerDevil registers a dummy 0/0 slider because `GetMaxBrightness()` returns a valid integer (`0`).
  - Solved cleanly via D-Bus policy `/etc/dbus-1/system.d/10-archpad-no-kbd-backlight.conf` denying `UPower.KbdBacklight`.
- **Sensor DSP (Hexagon sDSP)**:
  - Qualcomm Sensor DSP initialized via `hexagonrpcd` and `archpad-wait-ssc`.
  - Feeds into `iio-sensor-proxy` over FastRPC.

### D. Display Panel Timing & Kernel (`packages/linux-archpad-pipa`)
- **Even Line Parity Requirement ($V_{\text{total}} \pmod 2 == 0$)**:
  - The Novatek NT36532 panel DDIC uses 2H gate driver multiplexing.
  - Total vertical lines ($V_{\text{total}} = V_{\text{active}} + V_{\text{fp}} + V_{\text{pw}} + V_{\text{bp}}$) **MUST be strictly even**.
  - Odd vertical porches invert gate driver phase between frames, triggering DDIC fault and black screen.
  - Rock-solid modes currently active: 120Hz ($V_{\text{total}} = 3122$) and 60Hz ($V_{\text{total}} = 6244$).

---

## 4. Current State & Cleanliness Verification

The keyboard, secure integrations, and their upstream KDE packages have verified package integrity:

1. **Pacman Package Integrity**:
   ```sh
   pacman -Qkk archpad-keyboard archpad-plasma-lockscreen archpad-sddm-theme \
       plasma-desktop plasma-workspace kscreenlocker sddm
   # Output: 0 altered files across all packages
   ```
2. **Keyboard Runtime**:
   - Atomic D-Bus ownership prevents the KWin/systemd startup race from leaving two live keyboard instances.
   - Installed on the tablet: `archpad-keyboard 1.0.0-58`, `archpad-plasma-lockscreen 6.7.5-3`, and `archpad-sddm-theme 1.0.0-4`.
   - Keyboard r57 packages four volume-normalized AOSP mobile keypress profiles
     (`Standard`, `Soft`, `Crisp`, `Deep`) with Apache-2.0 provenance. The
     settings companion persists and previews `soundProfile` and applies an
     independent `soundVolume` (`0..100`, default `70`) through libcanberra's
     decibel gain property without changing PipeWire system volume.
   - r57 removes the settings companion's Kirigami dependency, follows the
     system appearance through Qt `QStyleHints`, flushes pending settings on
     exit, removes unimplemented gesture preview cards, and passes Qt 6.11 QML
     lint without layout-positioning diagnostics.
   - r58 makes the standard Qt settings `ApplicationWindow` visible on initial
     construction, so the first toolbar tap opens it; the existing D-Bus
     `Activate()` path still raises an already-running copy.
   - FUTO Swipe qualification Phases A, B, and C are complete. Exact upstream revisions,
     model/dictionary hashes, licenses, dependency pins, reproducibility
     requirements, and upstream false-positive test findings are recorded in
     `artifacts/manifests/futo-swipe-phase-a-2026-09-16.md`. The isolated
     ARM64 full-engine build, truthful test fixes, CLI hash, and smoke result
     are in `artifacts/manifests/futo-swipe-phase-b-2026-09-16.md`. Automated
     boundaries, lifecycle, serial mode changes, and the official 20,000-trace
     result are in `artifacts/manifests/futo-swipe-phase-c-2026-09-16.md`.
     Phase D1's essential performance gate is complete and supports beginning
     integration planning; its measurements are in
     `artifacts/manifests/futo-swipe-phase-d1-2026-09-16.md`. D2 endurance,
     thermal, true cold-cache, and 60/120 Hz checks remain required before
     release. The r58 keyboard remains unchanged.
   - The final audit identified one intentionally unresolved product boundary:
     the daemon still forces `LayoutList=us` in KDE `kxkbrc` and emits text as
     uinput keycodes. Do not connect FUTO candidate insertion to `tapText()` as
     a final design. Plan a text-commit backend using KWin's exposed
     input-method-v1 protocol and input-method-v2 on supporting compositors;
     retain uinput for raw shortcut/navigation fallback.
   - Prepared locally but not yet deployed: lock-screen `6.7.5-4`.
3. **Working Tree**:
   - Do not describe the repository as clean or discard unrelated changes without checking current `git status`.

---

## 5. Development & Deployment Workflows

### Accessing the Tablet
```sh
# Via Wi-Fi
ssh archpad

# Via USB Cable (recovery / direct)
ssh -F /dev/null -o StrictHostKeyChecking=no root@172.16.42.1
```

### Building and Deploying Packages
Package directories live in `packages/`:
- `packages/archpad-keyboard`
- `packages/archpad-plasma-lockscreen`
- `packages/archpad-sddm-theme`
- `packages/archpad-pipa-device`
- `packages/linux-archpad-pipa`

To build on the tablet or cross-compile:
```sh
cd /home/archpad/build/<package-dir>
makepkg -f
sudo pacman -U --noconfirm <built-package>.pkg.tar.xz
```

### Inspecting Live UI & Taking Screenshots
```sh
sudo -u archpad XDG_RUNTIME_DIR=/run/user/10000 /usr/local/bin/kwin-shot /tmp/screen.png
```

---

## 6. Recommended Next Steps for Codex

1. **Hardware Power Profiles & Dynamic Refresh Rates**:
   - Tie KWin screen refresh rate switching (120Hz on touch/interaction -> 60Hz after idle) into PowerDevil / power profiles.
2. **Camera Subsystem (libcamera / V4L2)**:
   - Front camera (hi846) and rear camera (ov13b10) pipeline tuning.
3. **Bluetooth Audio & Codecs**:
   - LDAC/aptX tuning via PipeWire WirePlumber.
