# ArchPad System Handoff & Technical Briefing (for Codex / Future Agents)

**Last Updated**: 2026-09-14 16:15 IST  
**Target Hardware**: Xiaomi Pad 6 (`pipa`) / Qualcomm Snapdragon 870 (SM8250)  
**Primary Git Branch**: `fixes/system-usability`  
**Working Tree Status**: 100% Clean (`git status` clean, all packages cleanly committed)

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
| **Network & SSH** | Wi-Fi (`192.168.1.12` / `archpad.local`) & USB Gadget (`172.16.42.1`) |

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
- **Clean Lock Screen Packaging**:
  - Upstream `plasma-desktop` remains 100% pristine.
  - Custom `ArchpadLockKeyboard.qml` and `LockScreenUi.qml` are installed into `/usr/local/share/plasma/shells/org.kde.plasma.desktop/contents/lockscreen/`, tracked cleanly by `archpad-keyboard`.
  - Fixes upstream touch-bounce bug by removing `onExited: { uiVisible = false; }`.
- **Daemon Lifecycle**:
  - Started by `archpad-keyboard.service` with `--hidden` on login.
  - Controlled dynamically via `--show`, `--hide`, `--toggle`, or KWin VirtualKeyboard D-Bus state.

### B. SDDM Login & Wallpaper Sync
- **Touch Screen Keyboard at Login**:
  - Standalone SDDM theme at `/usr/share/sddm/themes/archpad/` containing integrated `ArchpadLockKeyboard`.
- **Dynamic Lockscreen Wallpaper Sync**:
  - Systemd user path watcher `archpad-sync-sddm-wallpaper.path` watches `~/.config/kscreenlockerrc`.
  - On change, syncs the user's wallpaper to `/var/lib/sddm/theme/lockscreen-wallpaper.png` (`chmod 644`) via standard `systemd-tmpfiles` permissions (`/usr/lib/tmpfiles.d/archpad-sddm.conf`).
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

The system is in a pristine, verified operational state:

1. **Pacman Package Integrity**:
   ```sh
   pacman -Qkk archpad-keyboard archpad-pipa-device plasma-desktop kwin
   # Output: 0 altered files across all packages
   ```
2. **Systemd Services**:
   - `systemctl --failed` returns **0 failed units**.
3. **Storage & Cleanup**:
   - Disk space: **12 GB used / 89 GB available (12% utilization)**.
   - Journal vacuumed and bounded.
   - Old build trees and temporary files purged.
   - Waydroid experiment uninstalled cleanly with 0 leftover files, services, or package traces.
4. **Git Repository**:
   - `git status` clean on `fixes/system-usability`.
   - All commits follow conventional commits format.

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
