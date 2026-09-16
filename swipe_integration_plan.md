# ArchPad Popup Swipe Typing Integration Plan

Date: 2026-09-16

Status: **Proposed — no keyboard source, package, configuration, or tablet
runtime has been changed. Explicit approval is required before Phase I0.**

## 1. Decision and scope

Adopt the qualified standalone FUTO Swipe engine for the unlocked-session
ArchPad keyboard's floating popup layout only. Preserve ArchPad's QML UI,
LayerShell surface, visibility behavior, taps, modifiers, special-key bar,
Backspace, and settings companion.

The first product increment will provide:

- touch swipe recognition over the popup letter rows;
- a lightweight GPU-rendered trail;
- automatic insertion of the top-ranked word;
- three selectable alternatives;
- safe replacement of the most recently inserted swipe word.

Docked portrait, laptop, split, Quick Pad, lock-screen, and SDDM keyboards are
out of scope. Swipe is disabled for password, PIN, terminal, and other content
purposes where prediction is inappropriate.

## 2. Non-negotiable architecture

```text
FloatingMobile touch surface
        -> gesture classifier and normalized trace
        -> single-owner FUTO worker thread
        -> ranked candidate model
        -> candidate bar
        -> TextCommitBackend
             -> KWin input-method-v1 backend
             -> input-method-v2 backend (wlroots-class compositors)

Raw shortcuts/navigation -> existing uinput backend
```

The LayerShell window remains
`KeyboardInteractivityNone`; it must never become an `xdg_toplevel` or take
focus. Normal UTF-8 text and candidate replacement use Wayland
`commit_string`/`delete_surrounding_text`. `/dev/uinput` remains only for raw
keys and shortcuts. The keyboard must stop rewriting KDE's `kxkbrc` once all
text/symbol paths supported by the new backend have equivalent behavior.

No candidate may be committed through `tapText()` as a transitional shortcut.

## 3. Packaging boundary

Create normal Arch packages from immutable sources:

- `archpad-futo-swipe`: pinned GPL-3.0 library and ExecuTorch/XNNPACK runtime;
- `archpad-futo-swipe-en`: English models, dictionary, layout, hashes, FUTO
  Model Weights License, and attribution;
- `archpad-keyboard`: links the packaged library and discovers installed
  language assets through a versioned manifest.

No network access occurs at build execution or runtime. No upstream package
file is overwritten. Language/model assets are independent so later model
updates and languages do not require copying data into the keyboard source.

## 4. Implementation phases

### I0 — Isolated Wayland commit proof

- Generate client bindings from the installed official
  `input-method-unstable-v1.xml` using `wayland-scanner`.
- Build a separate non-installed probe that binds KWin's
  `zwp_input_method_v1`, tracks activation/context serials, commits UTF-8, and
  replaces text using byte-correct surrounding-text deletion.
- Prove behavior in Kate, Firefox, Chromium, Konsole, and Qt settings fields.
- Confirm passwords expose no surrounding text and receive no prediction.
- Confirm the LayerShell keyboard never steals focus.
- Define the same `TextCommitBackend` contract for v2 without embedding KWin
  calls in the core.

Stop and report before modifying the keyboard if KWin will not grant a context
to the service or if any tested toolkit cannot receive standard commits.

### I1 — Packaged engine adapter

- Turn the qualified build into the two packages above with all revisions,
  patches, checksums, and licenses tracked.
- Add a `SwipeEngineWorker` owned by one dedicated thread. All initialization,
  decode, mode changes, and destruction occur on that thread because the
  upstream engine is non-thread-safe.
- Load asynchronously when floating swipe mode is first enabled, never on a
  key-release critical path. Keep it resident until the process exits for the
  first implementation; expose loaded/loading/failed state and measured memory
  honestly.
- Bound trace length and queue depth; cancel stale requests rather than queueing
  several gestures.

### I2 — Popup touch capture and trail

- Refactor only `FloatingMobile.qml` letter rows around a shared gesture
  surface. Derive letter centers from actual rendered key geometry; do not
  duplicate hardcoded visual coordinates in C++.
- Classify a short, low-movement contact as the existing tap and a
  threshold-crossing contact as a swipe. A swipe must never also emit its first
  letter.
- Preserve Shift, Backspace, symbols, number row, and the scrollable special
  bar outside the swipe surface.
- Render the trail with one lightweight scene-graph line-strip item and a
  bounded point buffer. Clear it on release, cancellation, layout destruction,
  hide, and mode change.
- Feed normalized monotonic points to the worker only after release.

Real touch on the Xiaomi Pad 6—not synthesized events—determines the final
gesture threshold and validates 60/120 Hz behavior.

### I3 — Automatic word and alternatives

- On a successful result, commit candidate zero through `TextCommitBackend`.
- Show candidates 1–3 in a bounded candidate strip without breaking the
  popup's special-key scrolling or narrow portrait layout.
- Track the committed UTF-8 byte range and surrounding-text revision. Tapping
  an alternative replaces the word only while the compositor confirms that
  the cursor and surrounding text still match. Otherwise candidates are
  dismissed without destructive fallback.
- Clear candidates on external edits, cursor movement, focus change, hide,
  Backspace, layout change, or new gesture.
- Do not add automatic spacing, autocorrect, personalization, learning, or
  multilingual selection in this first increment.

### I4 — Settings, compatibility, and release gate

- Add settings for Swipe Typing, Trail, and Auto Insert. Defaults remain off
  until the real-touch matrix passes; no fake preview card is allowed.
- Implement the v2 backend using the externally maintained v2 protocol XML and
  select backends strictly from advertised registry globals. Unsupported
  compositors retain tap typing and show a truthful diagnostic.
- Test Kate, Firefox, Chromium, Konsole, settings text fields, multiline text,
  selections, password/PIN fields, focus changes, popup drag/resize, hide and
  reopen, suspend/resume, and daemon restart.
- Complete D2 endurance, leak, thermal, true cold-cache, and 60/120 Hz checks.
- Require clean QML lint, package ownership, license installation, and
  `pacman -Qkk` results before enabling Swipe Typing by default.

## 5. State and failure rules

- Exactly one gesture may be collecting or decoding at a time.
- Input-method activation and its serial/context are authoritative; never
  commit to a stale or inactive context.
- Candidate replacement counts UTF-8 bytes as required by Wayland, not Qt
  UTF-16 code units.
- Engine/model absence, initialization failure, backend unavailability, or a
  decode timeout disables swipe cleanly while ordinary tapping remains usable.
- Password/PIN content purpose clears trace, context, candidates, and trail.
- No touch traces, surrounding text, or candidate history are written to disk
  or sent over a network.

## 6. Resource and quality gates

The D1 baseline is 10.27 ms p50 / 11.18 ms p95 decode, approximately 93.5 MiB
PSS, and a 19.1 MiB distributable proxy. Integration must:

- keep p95 release-to-candidate latency below 20 ms on the target tablet;
- add no continuous CPU usage while idle;
- document actual daemon PSS before and after model load;
- avoid unbounded trace, candidate, or request storage;
- preserve normal-tap behavior when swipe is disabled or unavailable.

## 7. Rollback and approval checkpoints

Each phase produces a separately buildable package and stops for tablet
verification. The installed release remains `archpad-keyboard 1.0.0-58` until
I0 succeeds and the first keyboard-changing phase is approved. Rollback is a
normal pacman downgrade/removal of ArchPad-owned packages; no upstream or user
configuration file is restored by scripts.

Approval of this document authorizes **I0 only**. Results will be reported
before I1 or any visible keyboard change begins.
