# Antigravity Handoff — ArchPad Keyboard and FUTO Swipe

Date: 2026-09-16

This repository checkpoint is the authoritative restart point for continuing
the ArchPad keyboard work in Antigravity. Run `git log -1 --oneline` to identify
the checkpoint commit containing this file.

## 1. Mandatory reading order

Read these files completely before running commands or editing source:

1. `AGENTS.md` — binding engineering and safety rules.
2. `implementation_plan.md` — completed repairs and FUTO qualification gates.
3. `swipe_integration_plan.md` — proposed product integration architecture.
4. `artifacts/manifests/futo-swipe-phase-a-2026-09-16.md`
5. `artifacts/manifests/futo-swipe-phase-b-2026-09-16.md`
6. `artifacts/manifests/futo-swipe-phase-c-2026-09-16.md`
7. `artifacts/manifests/futo-swipe-phase-d1-2026-09-16.md`

Do not infer permission to skip an approval checkpoint from older chat text.

## 2. Verified current state

- The production tablet is a Xiaomi Pad 6 running Arch Linux ARM, KWin/Plasma
  6.7.5, Qt 6.11.2, and Wayland only. The known deployed kernel generation is
  `7.1.4-pipa-r16`; verify every live version before relying on it.
- Installed unlocked-session keyboard: `archpad-keyboard 1.0.0-58`.
- The main keyboard is independent from `archpad-plasma-lockscreen` and
  `archpad-sddm-theme`.
- The keyboard window is a non-focusable LayerShell surface with
  `KeyboardInteractivityNone`. This must not change.
- Normal text currently uses `/dev/uinput`; `tapText()` is not an acceptable
  path for swipe candidates or future arbitrary UTF-8 text.
- FUTO qualification A, B, C, and D1 are complete. No FUTO code is integrated
  into the production keyboard.
- Public-trace accuracy: 92.095% top-1 and 95.825% top-4 over 20,000 official
  non-single-letter traces at beam width 300.
- D1 full-pipeline latency: 10.27 ms p50 and 11.18 ms p95.
- D1 memory: about 93.5 MiB PSS and 106.7 MiB peak RSS. Treat this as a real
  product constraint.
- The latest tablet Wi-Fi address was `192.168.1.4`. It is DHCP and must be
  verified rather than assumed. The earlier `192.168.29.231` address belongs
  to the previous network.
- Tablet qualification workspaces:
  - `/home/archpad/builds/futo-phase-b-20260916/`
  - `/home/archpad/builds/futo-phase-c-20260916/`

### Operational access and integrity

- Prefer the configured `ssh archpad` host after verifying its current DHCP
  address. USB recovery is available as
  `ssh -F /dev/null -o StrictHostKeyChecking=no root@172.16.42.1`.
- Run session commands as UID 10000 with
  `XDG_RUNTIME_DIR=/run/user/10000`; do not guess a different runtime or bus.
- Package sources are under `packages/`. Build in a dedicated tablet build
  directory with `makepkg -f`; never build as root or edit installed files.
- Screen capture uses `/usr/local/bin/kwin-shot` in the `archpad` Wayland
  session when visual evidence is required.
- The verified package boundary is `archpad-keyboard`,
  `archpad-plasma-lockscreen`, and `archpad-sddm-theme`. Upstream KDE/SDDM
  packages must remain pristine and all relevant `pacman -Qkk` checks must
  report zero altered files.

## 3. Git safety before continuation

1. Confirm this checkpoint is clean with `git status --short`.
2. Do not reset, squash, amend, rebase, or discard this checkpoint.
3. Create a new child branch for continuation, for example
   `antigravity/i0a-wayland-probe`.
4. Preserve unrelated work and inspect the diff before every commit.
5. Never commit model blobs, build directories, credentials, SSH keys, tablet
   home contents, or generated dependency trees.

If the checkout is not clean on arrival, stop and explain the unexpected diff
before editing anything.

## 4. Authorized next task: I0a only

Implement and test only the isolated Wayland input-method-v1 proof described
below. Do not begin I1, FUTO packaging, touch capture, trail rendering,
candidate UI, settings, or any production keyboard edit.

### Deliverable

Add a small source-only probe under a clearly separate directory such as
`tools/input-method-v1-probe/`. It must:

- use the installed official protocol XML:
  `/usr/share/wayland-protocols/unstable/input-method/input-method-unstable-v1.xml`;
- generate client bindings with `/usr/bin/wayland-scanner` during the normal
  CMake build;
- link to the standard `wayland-client` library;
- bind `zwp_input_method_v1` and track activation/deactivation;
- retain the latest `commit_state` serial for the active context;
- commit arbitrary UTF-8 using `commit_string(serial, text)`;
- perform byte-correct replacement through
  `delete_surrounding_text(-before_bytes, before_bytes)` followed by
  `commit_string`;
- reject commits when no current context exists;
- expose an auditable trigger that does not steal application focus. A narrow
  session D-Bus interface for `Commit`, `ReplacePrevious`, and read-only status
  is acceptable;
- report content purpose and whether surrounding text is available, but never
  log or persist the surrounding text itself;
- contain no input-panel surface, keyboard UI, daemon installation, desktop
  file, autostart unit, package hook, or network access.

Do not use Qt key events, clipboard insertion, `ydotool`, uinput text
simulation, fake Backspace, KWin scripting, accessibility injection, or an
`xdg_toplevel` helper as a substitute for the protocol.

### Tablet build and execution boundary

- Build natively on the tablet as user `archpad` in an uninstalled build
  directory.
- Do not install packages or overwrite files under `/usr` or `/etc`.
- Use the existing Wayland/session environment for UID 10000:
  `XDG_RUNTIME_DIR=/run/user/10000` and the matching session bus.
- Starting the probe is temporary. It must terminate normally and leave no
  service or process behind.
- Do not stop, restart, rebuild, install, or modify `archpad-keyboard`.

### Bounded I0a real test

Test only Kate in this checkpoint:

1. Open a normal Kate text field and keep it focused.
2. Start the headless probe without opening a focusable window.
3. Confirm the compositor sends an active input-method context.
4. Trigger insertion of an ASCII word from SSH/session D-Bus and verify it
   appears at the caret.
5. Trigger insertion of a non-ASCII UTF-8 sample and verify it is intact.
6. Commit a word, then replace precisely that word using byte-counted
   surrounding-text deletion and a second commit.
7. Confirm Kate retains focus throughout and the existing LayerShell keyboard
   does not vanish or gain focus.
8. Focus a password-purpose field only if one is already safely available;
   verify the probe reports the purpose without logging text. Do not broaden
   I0a merely to construct a password test application.
9. Stop the probe and confirm no probe process remains.
10. Run `pacman -Qkk archpad-keyboard plasma-desktop plasma-workspace` and
    require zero altered files.

Do not synthesize touch or claim broader application compatibility from this
Kate-only proof.

## 5. Required I0a stop conditions

Stop without modifying the production keyboard if:

- KWin does not advertise or activate `zwp_input_method_v1` for the probe;
- another input method owns the seat and the protocol reports a conflict;
- serial handling is unclear or a stale context can receive text;
- Kate loses focus;
- replacement requires simulated key events;
- an official package file would need modification;
- any step requires an arbitrary sleep, polling workaround, or persistent
  compositor configuration change.

Record the exact failure and protocol events rather than improvising a
workaround.

## 6. I0a completion record

Create `artifacts/manifests/swipe-i0a-wayland-proof-2026-09-16.md` containing:

- source paths and Git commit;
- compiler, Wayland, KWin, and protocol versions;
- build command and binary SHA-256;
- protocol globals observed;
- activation/deactivation and serial behavior;
- exact Kate insertion/replacement results;
- focus and password-purpose findings;
- process cleanup and package-integrity results;
- a concise recommendation: proceed to I0b, revise the approved plan, or stop.

Commit the probe and report on the child branch, then stop. I0b and every live
keyboard change require another explicit user decision.

## 7. Remaining work after I0a

The remaining stages are intentionally not authorized in this handoff:

- I0b: Firefox, Chromium, Konsole, Qt settings, selection, multiline, and
  password compatibility matrix; finalize v1/v2 backend contract.
- I1: package FUTO library/models and add a single-owner asynchronous engine
  worker.
- I2: popup-only touch capture and lightweight trail with real-touch testing.
- I3: automatic top-word commit and three safe replacement alternatives.
- I4: settings, input-method-v2 backend, D2 endurance/thermal testing, and
  release qualification.

Follow `swipe_integration_plan.md`; do not collapse these phases into one large
change.
