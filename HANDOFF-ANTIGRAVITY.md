# ArchPad Current Handoff

Updated: **2026-09-09 22:40 IST**

Supersedes all older intermediate handoffs. `ROADMAP.md` remains the full
project source of truth.

## Owner's goal and standards

ArchPad is a native Arch Linux ARM tablet OS for Xiaomi Pad 6 (`pipa`), using
touch as the primary UI and terminal agents as a primary development tool.
Reliability, reproducibility, native Linux interfaces, pacman ownership and
safe upgrades are mandatory. Do not hide problems with startup loops, patched
system binaries or shell-command simulations when a standard systemd, D-Bus,
PAM, Wayland or compositor interface exists. AI/Gemini integration is last.

The owner explicitly does not need the former Android data. Never use
`qbootctl`. Preserve USB networking/SSH as the recovery path and do not alter
partitions, boot firmware or the kernel during GUI work.

## Current tablet state

- Device: Xiaomi Pad 6, Snapdragon 870, Tianma panel, active Android-style
  slot A. U-Boot is the firmware payload in `boot_a`, then launches
  systemd-boot; it is not GRUB and not a separately flashed U-Boot partition.
- OS: native Arch Linux ARM aarch64, `graphical.target`.
- Kernel: `linux-archpad-pipa 7.1.4-9`, running generation
  `7.1.4-pipa-r9`; independently packaged r7 rollback remains available.
- GUI: Hyprland `0.56.2-3`, Quickshell `0.3.1-1`,
  `archpad-session 0.3.2-5`, `archpad-shell 0.2.0-3`.
- Device/sensors: `archpad-pipa-device 1.0.0-5`, HexagonRPC `0.4.0-2`,
  iio-sensor-proxy `3.9-1`.
- Live state at handoff: graphical session, HexagonRPC, SensorProxy and the
  user rotation service are all active; system and user failed-unit lists are
  empty; Hyprland `configerrors` is empty.
- USB SSH: root at `172.16.42.1`; host is `172.16.42.2`. Use an explicit
  isolated invocation if no host alias is available:

  ```sh
  ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null root@172.16.42.1
  ```

The development account credentials are intentionally temporary and may be
used by agents during construction. They must be changed before release.

## Work completed in the latest stage

Git commit: **`271d27c Fix sensor startup and rotation races`**. The worktree
was clean immediately after that commit.

1. Fixed the cold-boot Sensor DSP ordering problem at its service boundary:
   the pipa fastrpc udev event requests
   `archpad-hexagonrpcd-sdsp.service`; its systemd unit remains `activating`
   until a bounded real `ssccli` accelerometer probe succeeds. SensorProxy is
   ordered after that readiness gate.
2. Removed the former rotation-service restart storm. The user daemon watches
   the standard `net.hadess.SensorProxy` D-Bus name and reconnects normally.
3. Fixed the finer service-name/device-discovery race. The rotation daemon
   waits for the authoritative standard `HasAccelerometer=true` property,
   claims the sensor once, then receives event-driven orientation updates.
   The temporary 250 ms GLib discovery check exists only while discovery is
   pending and stops after the claim.
4. Reproduced the race by starting the rotation client before restarting
   SensorProxy. The fixed daemon logged:

   ```text
   sensor proxy connected; waiting for accelerometer discovery
   accelerometer claimed
   orientation right-up applied as transform 3
   ```

   D-Bus then reported `HasAccelerometer=true` and
   `AccelerometerOrientation="right-up"`.
5. Cleared the visible Hyprland configuration warning. It was stale compositor
   state caused by pacman's atomic replacement of `hyprland.lua` while the
   compositor was running. The file was present, `pacman -Qkk` was clean, a
   normal `hyprctl reload` succeeded, and `configerrors` is now empty.
6. Packaged a safe interim logind policy:
   `HandlePowerKey=ignore` and `HandlePowerKeyLongPress=ignore`. This prevents
   the upstream desktop default from powering off the tablet and prevents an
   unsafe suspend that wakes directly into an unlocked desktop.

Native package artifacts retained under the ignored private artifact folder:

- `artifacts/private/arch-packages-phase4c-r2/archpad-pipa-device-1.0.0-5-any.pkg.tar.xz`
- `artifacts/private/arch-packages-phase4c-r2/archpad-session-0.3.2-5-aarch64.pkg.tar.xz`
  SHA-256: `a83689f9134e2634f68a9029badec01a7e3c3808796f581b6b7ebabe2ff7de19`

## Immediate validation still needed

The owner must physically rotate through portrait and both landscape
directions after the latest package install. Confirm display, touch and pen
remain aligned in every orientation. Then perform one later cold-boot check to
prove the complete hardware-to-session startup path. Do not reopen the sensor
implementation unless that test fails; collect logs first.

## Next implementation stage: secure login, lock and power UX

This has **not** been implemented yet. Currently both power-button actions are
intentionally inert.

Required behavior:

- short press: acquire a real Wayland session lock, complete PAM-backed locker
  startup, then request suspend through logind;
- wake: show the authenticated lock screen before any desktop content;
- cold boot/logout: show a proper PAM-backed graphical greeter rather than
  automatically recreating the user session;
- long press: show an ArchPad shell power menu with Sleep, Log out, Restart and
  Shut down; destructive actions require a second deliberate touch;
- all actual actions go through logind/systemd interfaces.

The recorded architecture selects `hyprlock` (repository version observed:
`0.9.6-3`) for the Wayland session-lock protocol and `greetd` (`0.10.3-2`) for
the graphical PAM login boundary. Do not install blindly. First design and
validate touch authentication: an ordinary OSK surface may not be visible over
the secure session-lock protocol. Use a secure integrated PIN/keyboard path or
another standards-compliant solution; never imitate a lock screen with a
normal Quickshell overlay. Only after lock-before-suspend works should logind's
short power action be enabled. Long-press detection and the menu belong to the
shell/input-policy layer, not a direct logind power-off action.

Read before changing this stage:

- `ROADMAP.md`
- `PHASE4-ARCHITECTURE.md`, especially “Login, locking and secrets”
- `UI-SPEC.md`, especially “Lock, wake and power key”
- `packages/archpad-session/README.md`

## Important unrelated known limitations

- Rear camera orientation/focus and ISP tuning remain later improvements.
- Fast charging, GPU cooling registration, long suspend/thermal endurance,
  DisplayPort combinations and other deep hardware tuning remain later gates.
- Sensor DSP startup emits noisy expected `temp.json` diagnostics; reduce this
  cleanly before public release.
- The current graphical login is still
  `archpad-graphical-session.service`, which starts the unprivileged `archpad`
  session through PAM and restarts it after logout because there is no greeter.
- Keep the power keys ignored if the secure lock stage cannot be completed.
