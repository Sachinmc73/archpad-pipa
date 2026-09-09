# Phase 4 ArchPad shell handoff

Status: **first packaged shell slice installed; owner touch review pending — 2026-09-09**

## Installed result

- Official Arch Linux ARM `quickshell 0.3.1-1` and its five required packages
  were installed. The tablet lacked DNS, so the exact repository files and
  detached signatures were transferred through the host. Every signature was
  verified by the tablet's trusted Arch Linux ARM keyring before pacman
  installed anything.
- `archpad-shell 0.1.0-1` is built from `packages/archpad-shell/` and installed
  as an independent package.
- Package SHA-256:
  `4a2220343a67a0ce022e0138fae94e38f4546d04508a34c41f68704b9171c958`.
- The package is preserved in the ignored
  `artifacts/private/arch-packages-phase4b/` artifact store.
- `archpad-shell.service` is attached to UWSM's
  `graphical-session.target`, so it starts with every ArchPad graphical login.

The system now has 466 packages and still uses 4.5 GiB of the 105 GiB rootfs.
No system or user unit is failed.

## Visible scope

- top bar occupying 68 logical pixels;
- minute-resolution clock on the left;
- four live, tappable Hyprland workspace buttons;
- top-right development status/feedback capsule;
- centered 390 by 88 logical-pixel dock with four 72 by 64 touch targets;
- working Foot terminal launcher;
- ArchPad/App, Overview and USB recovery buttons with honest status feedback.

The top and bottom surfaces appear as native Quickshell layer-shell surfaces at
900 logical pixels wide. They reserve 68 pixels at the top and 112 at the
bottom, so normal applications currently stay clear of them.

This release intentionally does not fake the app drawer, Overview, quick
settings, automatic dock hiding, window pill, snap UI, gesture routing or OSK.
Those remain separate testable increments.

## Validation evidence

- Quickshell reported `Configuration Loaded` with no QML errors from both the
  temporary proof and installed service.
- Hyprland reported the two expected layer surfaces at `0,0 900x68` and
  `0,1328 900x112` on DSI-1.
- `pacman -Qkk archpad-shell quickshell` reported zero altered files.
- Autostart resolves to `/usr/lib/systemd/user/archpad-shell.service` and is a
  dependency of `graphical-session.target`.
- Idle proportional memory during this early proof was approximately 192 MiB
  for Quickshell, 172 MiB for Hyprland and 32 MiB for Foot. Total system used
  memory was about 1.21 GiB. This is a baseline, not yet an optimized result;
  the final graphical idle target remains below 800 MiB.

## Owner touch check

Confirm on the tablet:

1. the bar and dock are correctly sized and unobstructed;
2. workspace buttons 1–4 switch and update their highlight;
3. Terminal opens another Foot window;
4. Apps, Overview and USB Recovery update the top-right feedback message;
5. existing application touch and dragging remain correct outside the panels.

## Recovery

Stopping only the visible shell leaves Hyprland and USB SSH running:

```sh
runuser -u archpad -- env HOME=/home/archpad XDG_RUNTIME_DIR=/run/user/10000 \
  systemctl --user stop archpad-shell.service
```

The next bounded stage is the dependable interim OSK gate. After touch text
entry works in representative Qt, GTK, Chromium/Electron and terminal fields,
continue the shell with the real application drawer.
