# ArchPad Keyboard TextCommitBackend Architecture Contract

Date: 2026-09-16

Status: **Proposed Architectural Contract (Phase I0b)**

---

## 1. Architectural Purpose

`archpad-keyboard` currently injects text exclusively via `/dev/uinput` using `tapText()`. While effective for ASCII keys and navigation shortcuts, this approach cannot safely commit arbitrary UTF-8 characters, pre-edit strings, or perform atomic candidate word replacements for gesture/swipe typing without resorting to layout-dependent synthetic Backspace sequences.

The `TextCommitBackend` interface decouples higher-level typing and candidate logic (such as FUTO Swipe prediction and alternatives) from the underlying compositor mechanism.

```text
┌────────────────────────────────────────────────────────┐
│             Keyboard UI / FUTO Swipe Candidate         │
└───────────────────────────┬────────────────────────────┘
                            │ (word commit / alternative replace)
                            ▼
┌────────────────────────────────────────────────────────┐
│               TextCommitBackend (Abstract)             │
└───────────────┬────────────────────────┬───────────────┘
                │                        │
       (Wayland V1 session)     (Wayland V2 session)
                │                        │
                ▼                        ▼
┌──────────────────────────────┐  ┌──────────────────────┐
│ WaylandInputMethodV1Backend │  │ WaylandInputMethodV2 │
│ (KWin / KDE Plasma)          │  │ (wlroots / Hyprland) │
└──────────────────────────────┘  └──────────────────────┘
                │
         (fallback / raw keys)
                │
                ▼
┌──────────────────────────────┐
│    UinputFallbackBackend     │
│ (Raw Shortcuts / Keystrokes) │
└──────────────────────────────┘
```

---

## 2. Abstract C++ Interface Definition

```cpp
#pragma once

#include <QObject>
#include <QString>
#include <cstdint>
#include <cstddef>

namespace ArchPad {

enum class ContentPurpose {
    Normal = 0,
    Alpha = 1,
    Digits = 2,
    Number = 3,
    Phone = 4,
    Url = 5,
    Email = 6,
    Name = 7,
    Password = 8,
    Pin = 9,
    Date = 10,
    Time = 11,
    DateTime = 12,
    Terminal = 13
};

enum class ContentHintFlag {
    None = 0x0000,
    AutoCompletion = 0x0001,
    AutoCorrection = 0x0002,
    AutoCapitalization = 0x0004,
    LowerCase = 0x0008,
    UpperCase = 0x0010,
    TitleCase = 0x0020,
    HiddenText = 0x0040,
    SensitiveData = 0x0080,
    Latin = 0x0100,
    MultiLine = 0x0200
};
Q_DECLARE_FLAGS(ContentHints, ContentHintFlag)

class TextCommitBackend : public QObject {
    Q_OBJECT

public:
    explicit TextCommitBackend(QObject *parent = nullptr) : QObject(parent) {}
    ~TextCommitBackend() override = default;

    // Backend availability and state
    virtual bool isAvailable() const = 0;
    virtual bool isActive() const = 0;
    virtual uint32_t currentSerial() const = 0;

    // Field purpose and surrounding context metadata
    virtual ContentPurpose contentPurpose() const = 0;
    virtual ContentHints contentHints() const = 0;
    virtual bool hasSurroundingText() const = 0;
    virtual size_t surroundingCursorBytes() const = 0;
    virtual size_t surroundingAnchorBytes() const = 0;
    virtual bool hasActiveSelection() const = 0;

    // Mutation requests
    virtual bool commitText(const QString &text) = 0;
    virtual bool replacePrevious(size_t beforeUtf8Bytes, const QString &newText) = 0;
    virtual bool deleteSurrounding(size_t beforeUtf8Bytes, size_t afterUtf8Bytes) = 0;

    // Safety checks
    bool isSensitiveField() const {
        ContentPurpose p = contentPurpose();
        return (p == ContentPurpose::Password || p == ContentPurpose::Pin ||
                contentHints().testFlag(ContentHintFlag::HiddenText) ||
                contentHints().testFlag(ContentHintFlag::SensitiveData));
    }

    bool isTerminalField() const {
        return contentPurpose() == ContentPurpose::Terminal;
    }

Q_SIGNALS:
    void activeChanged(bool active);
    void contentPurposeChanged(ContentPurpose purpose);
    void contentHintsChanged(ContentHints hints);
    void surroundingTextChanged(bool available, size_t cursorBytes, size_t anchorBytes);
    void stateReset();
};

} // namespace ArchPad
```

---

## 3. Protocol Implementation Specifications

### A. `WaylandInputMethodV1Backend` (KWin 6.x / KDE Plasma)
- **Wayland Global**: Binds `zwp_input_method_v1`.
- **Context Handling**:
  - `activate`: Attaches `zwp_input_method_context_v1_listener`.
  - `deactivate`: Destroys context object via `zwp_input_method_context_v1_destroy()`.
  - `commit_state`: Stores serial. All subsequent commits must use the latest known serial.
- **Replacement Semantics**:
  - `replacePrevious(N, text)` maps directly to:
    1. `zwp_input_method_context_v1_delete_surrounding_text(ctx, -(int32_t)N, N)`
    2. `zwp_input_method_context_v1_commit_string(ctx, serial, text)`
    3. `wl_display_flush(display)`
  - Confirmed: KWin translates this to text-input v2/v3 `deleteSurroundingText(N, 0)` followed by `commitString(text)` and `done()`.

### B. `WaylandInputMethodV2Backend` (wlroots / Hyprland)
- **Wayland Global**: Binds `zwp_input_method_manager_v2`.
- **Context Handling**:
  - Creates `zwp_input_method_keyboard_grab_v2` and `zwp_input_method_instance_v2`.
  - Serial tracking is bundled in `activate` / `state` events.
- **Replacement Semantics**:
  - `zwp_input_method_instance_v2_delete_surrounding_text(instance, N, 0)`
  - `zwp_input_method_instance_v2_commit_string(instance, text)`
  - `zwp_input_method_instance_v2_commit(instance, serial)`

### C. `UinputFallbackBackend` (Raw Shortcuts / Keystrokes)
- Retained for:
  - Raw system key combinations (`Ctrl`, `Alt`, `Super`, function keys).
  - Navigation keys (`Left`, `Right`, `Home`, `End`, `Tab`, `Escape`).
  - Terminal shortcuts where text-input protocols are not applicable.

---

## 4. Safety & Invariant Guarantees

1. **Focus Protection**: LayerShell surfaces with `KeyboardInteractivityNone` must never take focus. Backends operate headlessly without creating focusable window surfaces.
2. **Zero Surrounding Text Retention**: The backend tracks only presence (`hasSurroundingText`), byte lengths, and cursor offsets. It **never logs, caches, or writes text content to disk**.
3. **Sensitive Field Protection**:
   - If `isSensitiveField()` is true, the swipe engine automatically suppresses candidate generation, trail rendering, and caching.
4. **Terminal Protection**:
   - If `isTerminalField()` is true, word replacement (`replacePrevious`) is disabled because terminal emulators (e.g. Konsole) ignore `delete_surrounding_text`.
