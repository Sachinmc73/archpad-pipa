# Wayland input-method-v1 Text Commit Proof Record (Phase I0a)

Date: 2026-09-16

Status: **Complete — isolated Wayland input-method-v1 proof passed on the Xiaomi Pad 6.** All text insertion, multibyte UTF-8 commit, and byte-correct surrounding text deletion/replacement succeeded in Kate with full focus retention. No production keyboard code, daemon, package, or configuration was modified.

---

## 1. Scope and Boundary

This qualification establishes the Wayland-native text-commit foundation for ArchPad Keyboard to replace `/dev/uinput` `tapText()` simulation. 

- **Target Device**: Xiaomi Pad 6 (`pipa`), Arch Linux ARM `aarch64`.
- **Installed Unlocked Keyboard**: `archpad-keyboard 1.0.0-58` (unmodified).
- **Environment**: Wayland session UID 10000 (`XDG_RUNTIME_DIR=/run/user/10000`, `WAYLAND_DISPLAY=wayland-0`).
- **Isolation Guarantee**: The probe is a standalone uninstalled tool built in `/home/archpad/builds/input-method-v1-probe/`. It contains no input-panel surface, no keyboard UI, no systemd service, no desktop entry, and does not alter any system files in `/usr` or `/etc`.

---

## 2. Environment and Toolchain Versions

| Component | Version |
| :--- | :--- |
| Linux Kernel | `7.1.4-pipa-r16` (`aarch64`) |
| Compositor | KWin 6.7.5 (`kwin 6.7.5-1`) |
| Desktop Environment | KDE Plasma 6.7.5 (`plasma-desktop 6.7.5-1`, `plasma-workspace 6.7.5-1`) |
| Qt Framework | Qt 6.11.2 (`qt6-base 6.11.2-3`) |
| Wayland Libraries | `wayland 1.26.0-1` (`libwayland-client.so.0`) |
| Wayland Protocols | `wayland-protocols 1.49-1` |
| Protocol Definition | `/usr/share/wayland-protocols/unstable/input-method/input-method-unstable-v1.xml` (version 1) |
| C Compiler | GCC 16.1.1 (`/usr/bin/cc`) |
| CMake | 4.4.3 |
| Code Generator | `/usr/bin/wayland-scanner 1.26.0` |

---

## 3. Source Paths and Build Artifact

- **Repository Branch**: `antigravity/i0a-wayland-probe`
- **Source Paths**:
  - `tools/input-method-v1-probe/CMakeLists.txt`
  - `tools/input-method-v1-probe/main.c`
- **Build Directory on Tablet**: `/home/archpad/builds/input-method-v1-probe/build/`
- **Build Commands**:
  ```bash
  cmake -B /home/archpad/builds/input-method-v1-probe/build -S /home/archpad/builds/input-method-v1-probe/source
  cmake --build /home/archpad/builds/input-method-v1-probe/build
  ```
- **Binary Details**:
  - Path: `/home/archpad/builds/input-method-v1-probe/build/input-method-v1-probe`
  - Size: 75,656 bytes (unstripped PIE executable)
  - SHA-256: `a2f4a6602a632e0d2006f24b80159cf67d5f94671eb63f4a6793aebdbf6e8e35`
  - Dynamic Dependencies (`ldd`):
    - `libwayland-client.so.0`
    - `libsystemd.so.0` (for `sd-bus` session control)
    - `libc.so.6`, `libm.so.6`, `libffi.so.8`, `libgcc_s.so.1`
    - **Zero Qt, GUI, or X11 dependencies.**

---

## 4. Wayland Protocol and Compositor Binding

1. **Registry Discovery**:
   - `zwp_input_method_v1` version 1 advertised at global name 37.
   - `zwp_input_panel_v1` version 1 advertised at global name 62.
   - `zwp_text_input_manager_v2` version 1 advertised at global name 69.
   - `zwp_text_input_manager_v3` version 2 advertised at global name 70.
2. **Context Lifecycle**:
   - Client successfully bound `zwp_input_method_v1`.
   - On text field activation in Kate, KWin emitted `zwp_input_method_v1.activate`, creating context `0xaaaae4c7a270`.
   - Context received:
     - `content_type`: `hint = 0x0007` (`auto_capitalization | auto_correction | auto_completion`), `purpose = 0` (`normal`).
     - `commit_state`: synchronized serial `717`.
     - `surrounding_text`: correctly reported `available = true`, cursor, and anchor.
   - **Privacy Integrity Verified**: Surrounding text content was processed for byte-offset tracking and presence, and was never logged or persisted to disk.

---

## 5. Live Test Results on Kate

All tests were performed against native Kate (`kate 26.08.1-1`) in an active Wayland session on the Xiaomi Pad 6:

### Test 1: ASCII Text Commit
- **Action**: D-Bus call `Commit("archpad")`.
- **Result**: `bs true "Committed 7 bytes at serial 717"`.
- **Observation**:
  - Text `"archpad"` appeared immediately at the Kate editor caret.
  - Kate editor updated tab title to `Untitled (archpad) *`.
  - Kate reported surrounding text cursor moved from 0 to 7.

### Test 2: Multibyte Non-ASCII UTF-8 Commit
- **Action**: D-Bus call `Commit(" ₹2026 🚀")`.
  - Byte composition: space (1 B) + Rupee sign `₹` (3 B: `0xE2 0x82 0xB9`) + `2026` (4 B) + space (1 B) + Rocket `🚀` (4 B: `0xF0 0x9F 0x99 0x80`) = 13 bytes.
- **Result**: `bs true "Committed 13 bytes at serial 717"`.
- **Observation**:
  - Kate displayed `archpad ₹2026 🚀` with 100% font rendering and UTF-8 integrity.
  - Kate reported surrounding text cursor updated from 7 to 20.

### Test 3: Byte-Correct Word Replacement
- **Step A**: Committed `" apple"` (6 bytes). Cursor updated to 26. Display text: `archpad ₹2026 🚀 apple`.
- **Step B**: Called `ReplacePrevious(before_bytes=5, text="banana")`.
  - Probe executed `zwp_input_method_context_v1_delete_surrounding_text(-5, 5)` followed by `zwp_input_method_context_v1_commit_string(717, "banana")`.
- **Result**: `bs true "Deleted 5 bytes and committed 6 bytes at serial 717"`.
- **Observation**:
  - Precisely the 5 bytes of `"apple"` were deleted and `"banana"` was inserted.
  - Final document text: `archpad ₹2026 🚀 banana`.
  - Kate reported surrounding text cursor updated to 27.
  - Replacement was atomic and clean: no caret jumping, no residual characters, and zero fake Backspace keypresses.

### Test 4: Focus Retention and LayerShell Integrity
- **Kate Window**: Maintained active Wayland focus throughout all commits and replacements. Titlebar remained active, and cursor remained blinking.
- **`archpad-keyboard` Surface**: The running virtual keyboard layer surface (`KeyboardInteractivityNone`) did not flicker, hide, crash, or steal focus.

---

## 6. Cleanup and System Integrity

1. **Process Teardown**:
   - Sent `Quit` method over session D-Bus.
   - Probe gracefully destroyed the Wayland input method context, unbound globals, disconnected from the Wayland display, released D-Bus ownership, and exited cleanly.
   - `pgrep -l input-method` confirmed 0 probe processes remained.
2. **Package Integrity Check**:
   ```bash
   pacman -Qkk archpad-keyboard plasma-desktop plasma-workspace
   ```
   **Result**:
   - `archpad-keyboard`: 23 total files, **0 altered files**.
   - `plasma-desktop`: 4,753 total files, **0 altered files**.
   - `plasma-workspace`: 6,786 total files, **0 altered files**.
   All 11,562 package-owned files remain 100% pristine.

---

## 7. Recommendation

Phase I0a is **completely successful**. The Wayland `zwp_input_method_v1` protocol is verified on KWin 6.7.5 to support arbitrary UTF-8 commits and atomic, byte-accurate word replacements without focus loss.

**Recommendation**: Proceed to **Phase I0b** (multi-toolkit compatibility matrix across Firefox, Chromium, Konsole, and System Settings; multi-line/selection replacement; and finalizing the abstract `TextCommitBackend` contract). Live modifications to `archpad-keyboard` remain gated behind subsequent explicit user approvals.
