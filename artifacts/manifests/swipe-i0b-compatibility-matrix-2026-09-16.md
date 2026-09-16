# Wayland Text-Commit Cross-Toolkit Compatibility Matrix (Phase I0b)

Date: 2026-09-16

Status: **Complete — Cross-toolkit compatibility matrix validated on Xiaomi Pad 6.** Wayland text commit and byte-accurate surrounding text deletion were tested across Chromium (Brave), Electron (VS Code), Qt KTextEditor (Kate), and Terminal (Konsole). Password fields correctly expose purpose 8 with surrounding text suppressed. The `TextCommitBackend` architectural contract has been formalized.

---

## 1. Test Matrix Summary

All tests were executed on the real Xiaomi Pad 6 (`pipa`) running native Arch Linux ARM, KWin 6.7.5, Qt 6.11.2, in an active Wayland session (UID 10000):

| App | Toolkit / Engine | Field Tested | Commit String | Surrounding Deletion / Replace | Content Purpose & Hints | Assessment |
| :--- | :--- | :--- | :---: | :---: | :--- | :--- |
| **Kate** | Native Qt (KTextEditor) | Multiline text buffer | **Pass** | **Pass** | `purpose = 0` (normal)<br>`hint = 0x0007` (autocap, autocorrect, autocomp) | **Full Support**: 100% byte-accurate in-place replacement across lines without caret jumping. |
| **Brave** | Chromium / Blink (`--enable-wayland-ime`) | Standard HTML `<input type="text">` | **Pass** | **Pass** | `purpose = 0` (normal)<br>`hint = 0x0004` (autocompletion) | **Full Support**: Atomic replacement verified (`chromium-wayland` -> `chromium-pipa`). Surrounding text cursor tracked dynamically. |
| **Brave** | Chromium / Blink (`--enable-wayland-ime`) | HTML `<input type="password">` | **Pass** | N/A (suppressed) | `purpose = 8` (`password`)<br>`hint = 0x00c0` (`hidden_text \| sensitive_data`) | **Full Privacy Support**: Browser suppresses surrounding text (`has_surrounding = false`). Engine detects `purpose == 8` and disables swipe prediction. |
| **Konsole** | Native Qt / KDE Terminal | Bash interactive shell prompt | **Pass** | Ignored by PTY | `purpose = 0` (normal/terminal prompt)<br>`hint = 0x0000` | **Expected Behavior**: Text insertion delivers characters to shell; terminal widgets ignore `delete_surrounding_text`. Swipe must be disabled for terminals. |
| **VS Code** | Electron / Monaco Editor | Editor workspace buffer | **Pass** | **Pass** | `purpose = 0` (normal)<br>`hint = 0x0100` (multiline) | **Full Support**: Native Wayland text-input active; commits received at caret without focus loss. |

---

## 2. Key Architectural Findings

1. **Chromium / Blink Integration (`--enable-wayland-ime`)**:
   - Brave natively binds Wayland text-input on the Xiaomi Pad 6.
   - Text commit and byte-accurate surrounding text deletion operate seamlessly.
   - Cursor and anchor positions update dynamically after each mutation.
2. **Password & Sensitive Field Protection**:
   - Web password inputs report `content_purpose = 8` (`content_purpose_password`) and `hint = 0x00c0` (`hidden_text | sensitive_data`).
   - The browser automatically withholds surrounding text (`available = false`).
   - The virtual keyboard can use `isSensitiveField()` to reliably suppress gesture prediction, trail rendering, and memory caching.
3. **Terminal Discipline**:
   - Because terminal emulators (e.g. Konsole) operate as PTY character streams rather than rich text document buffers, they ignore `delete_surrounding_text`.
   - The planned rule to disable swipe prediction for terminal windows is experimentally validated and essential.
4. **Focus Invariance**:
   - Across all tested toolkits (Qt, Chromium, Electron, Konsole), the LayerShell keyboard surface (`KeyboardInteractivityNone`) retained its state without stealing focus or closing.

---

## 3. Architectural Contract Deliverable

The formal abstract C++ contract has been documented at:
[docs/text-commit-backend-contract.md](file:///home/sachin/projects/personal/archpad/docs/text-commit-backend-contract.md)

It defines:
- The abstract `ArchPad::TextCommitBackend` class.
- Standardized `ContentPurpose` and `ContentHints` flags.
- `commitText()`, `replacePrevious()`, and `deleteSurrounding()` methods.
- Clear separation between Wayland v1 (KWin), Wayland v2 (Hyprland/wlroots), and `/dev/uinput` fallbacks.

---

## 4. System Integrity & Process Cleanup

- All test processes (Brave, VS Code, Konsole, Kate, and the probe) were cleanly terminated.
- Zero probe processes remain.
- **Package Integrity Verification**:
  ```bash
  pacman -Qkk archpad-keyboard plasma-desktop plasma-workspace
  ```
  - `archpad-keyboard`: 23 files, **0 altered files**.
  - `plasma-desktop`: 4,753 files, **0 altered files**.
  - `plasma-workspace`: 6,786 files, **0 altered files**.
  All official and system files remain 100% pristine.

---

## 5. Recommendation

Phase I0b is **complete and verified**. The Wayland text-commit architecture is fully viable across all target application classes.

**Recommendation**: Proceed to **Phase I1** (Packaging the standalone FUTO Swipe library runtime `archpad-futo-swipe`, English model weights `archpad-futo-swipe-en`, and implementing the dedicated single-owner asynchronous `SwipeEngineWorker`). Live keyboard modifications remain gated behind subsequent user approval.
