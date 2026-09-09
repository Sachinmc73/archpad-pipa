# Phase 4 ArchPad shell handoff

Status: **first shell touch proof and live native rotation complete; OSK next — 2026-09-09**

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

The system now has 474 packages. The latest system and graphical user-session
snapshots had no failed unit; `archpad-shell` and `archpad-rotation` were both
active. Their first cold-login autostart after the rotation package install
remains a physical check rather than an inferred pass.

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

## Owner touch check: passed

The owner confirmed that the bar/dock touch targets, workspace selection,
Terminal launcher, feedback targets and application touch/dragging behaved as
intended. The diagnostic bottom contact counter was not reliable, but its live
touch visualization and an independent browser multitouch test both responded
to multiple contacts.

## Native rotation slice

- Official Arch Linux ARM `iio-sensor-proxy 3.9-1` consumes the Qualcomm SSC
  accelerometer enabled only for pipa by `archpad-pipa-device 1.0.0-4`.
- A sandboxed system service runs `hexagonrpcd` against the Sensor DSP. The
  exact upstream HexagonRPC v0.4.0 source is pinned at tag commit
  `23a69640bf10dc498226c602c5b5db11d8cb3d8e`, with one checksummed patch that
  exposes the firmware registry-version marker expected by pipa's DSP image.
- `archpad-session 0.3.0-3` installs a small unprivileged GDBus service. It
  claims the accelerometer and applies the DSI-1, touchscreen and pen transforms
  together through Hyprland's supported Lua `eval` configuration interface.
- `HasAccelerometer=true`, raw SSC samples and iio-sensor-proxy orientation
  events were verified. The owner visually confirmed automatic transitions
  between normal and right-up.
- All four installed package trees passed `pacman -Qkk` with zero altered
  files. The ignored final artifact set is in
  `artifacts/private/arch-packages-phase4c/`:

  - `archpad-pipa-device-1.0.0-4-any.pkg.tar.xz` — SHA-256
    `07c6bf59df29d14de498ed2c3cd4a769ef76b6335fc6cf1daac6dfc2d2381845`
  - `archpad-pipa-firmware-1.0.0-2-any.pkg.tar.xz` — SHA-256
    `6245f153eddcbd41d3a36bf626819f65629f1ad86d253b64604e746dca5ea705`
  - `archpad-session-0.3.0-3-aarch64.pkg.tar.xz` — SHA-256
    `b3e00e2a68a9b1291e166cd301a29933ff73854539cb093bdbf134b3e54d3952`
  - `hexagonrpc-0.4.0-2-aarch64.pkg.tar.xz` — SHA-256
    `01a1e9f216ecc3d6c86d3d97aab27f06e3069bb42cb460694e5e9f7c59935c4c`

Package archives rebuilt at different times are not expected to be
byte-identical because makepkg records build metadata. Reproducibility here
means pinned, checksummed inputs and repeatable verified contents; byte-for-byte
package archive reproducibility is not yet claimed.

### Remaining physical rotation check

After the next cold graphical boot, confirm:

1. rotation starts automatically without SSH intervention;
2. normal, left-up, bottom-up and right-up all orient correctly;
3. single-touch corners and drag direction match in each orientation;
4. browser multitouch remains aligned;
5. pen position follows the tip in each orientation.

## Recovery

Stopping only the visible shell leaves Hyprland and USB SSH running:

```sh
runuser -u archpad -- env HOME=/home/archpad XDG_RUNTIME_DIR=/run/user/10000 \
  systemctl --user stop archpad-shell.service
```

After that short check, the next bounded stage is the dependable interim OSK
gate. Once touch text entry works in representative Qt, GTK,
Chromium/Electron and terminal fields, continue the shell with the real
application drawer.
