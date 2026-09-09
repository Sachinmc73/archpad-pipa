# Phase 4B compositor and graphical-login foundation

Status: **installed and live-validated; cold-boot check pending — 2026-09-09**

## What is installed

- Hyprland `0.56.2-3`, built natively on the tablet from the unmodified Arch
  recipe semantics and upstream release source;
- Aquamarine `0.15.0-2` (`libaquamarine.so.14`);
- UWSM `0.26.7-1`;
- `xdg-desktop-portal 1.22.1-2` and
  `xdg-desktop-portal-hyprland 1.4.1-2`;
- polkit `127-3` with `hyprpolkitagent 0.1.3-10`;
- GNOME Keyring `50.0-1` for the Secret Service API;
- Foot `1.28.0-2` as the proof terminal;
- `archpad-session 0.2.0-1`, built from `packages/archpad-session/`;
- `archpad-graphical-session.service`, enabled on `graphical.target`, running
  UWSM as the unprivileged `archpad` user through PAM on seat0/TTY1.

The full system was updated first. The resulting installation has 459 packages,
used about 487 MiB RAM at the last console idle check and occupies 4.5 GiB of
the 105 GiB rootfs. `graphical.target` is now the default. No third-party
display manager is installed: the packaged ArchPad service owns graphical
startup and conflicts only with `getty@tty1.service`.

## Why Hyprland was built locally

On 2026-09-09 the Arch Linux ARM repository was internally inconsistent:
`hyprland 0.56.1-3` required `libaquamarine.so=13-64`, but its only Aquamarine
package was `0.15.0-2`, providing ABI 14. Forcing the old binary or making a
compatibility symlink would be unsafe.

The tracked `packages/hyprland/PKGBUILD` is the official Arch Linux
`0.56.2-3` recipe with only trailing whitespace normalized:

- packaging commit: `b4da40b4c27baf3032c7a5bc84426f890914d3f9`;
- upstream source commit/tag: `efb50993780079460b0cbed1363e2166a2de1d9f`
  / `v0.56.2`;
- source SHA-256:
  `03ad3f5ef152ff44116ffd56fcf808486211ecabf4f0ba567108ee746ba5cd2e`;
- built package SHA-256:
  `842ccd2c172bc87e43cf1aaae49d6858380109a058403457294d73155ef949b7`.

The built executable reports Aquamarine 0.15.0 and directly links
`libaquamarine.so.14`. The normal repository package can replace this build
when Arch Linux ARM publishes a newer Hyprland version.

The original `archpad-session 0.1.0-1` package SHA-256 was
`153b7f3904c480ac267319cbda279da586b65721e7424f2478419f3c8d7ef754`.
The installed `0.2.0-1` package SHA-256 is
`c60bedc16756a4ae28398d352936370db199d22c425fca53d3d6ffc641890d11`.
Both binary packages are retained under the ignored private artifact directory
`artifacts/private/arch-packages-phase4b/`; tracked package sources remain the
authoritative inputs.

## Checks already passed

- Hyprland's `--verify-config` reports `config ok` for the installed Lua file;
- the session launcher refuses root;
- Hyprland and `archpad-session` pass `pacman -Qkk` with zero altered files;
- r9 remains running and the default; r9 and fallback r7 boot generations pass
  all stored SHA-256 checks;
- zero failed system units and zero pending repository upgrades;
- the original `/etc/hosts` was restored byte-for-byte and all temporary
  mirror tunnels, pacman configurations and tablet build directories were
  removed.
- native DSI output at 1800x2880, 120 Hz, scale 2;
- touch taps, continuous dragging, touch scrolling, pinch and simultaneous
  multitouch contacts on a native Qt/Wayland test surface;
- touchscreen and pen are both exposed to Hyprland;
- the persistent service has an active PAM/logind `archpad` session on
  seat0/TTY1, with no failed user units or service warnings;
- a deliberate service restart cleanly destroyed and recreated Hyprland, Foot
  and the seat0 session with no warnings;
- `graphical.target`, the graphical service, USB networking and SSH are all
  active together; TTY1 getty alone is inactive by design.

## Remaining validation gate

The service and target were activated successfully without rebooting. A later
controlled power cycle must prove automatic cold-boot startup. This is kept
separate because the existing low-level issue can cause `systemctl reboot` to
power off instead of restarting; it does not invalidate graphical startup.

Still validate pen pressure/precision, keyboard-cover input, workspace gesture,
session restart after clean logout, and touch/pen after suspend-resume. These
are incremental checks and do not block beginning the visible shell.

## Recovery

If graphical startup fails, connect over USB SSH and run:

```sh
systemctl disable --now archpad-graphical-session.service
systemctl set-default multi-user.target
systemctl start getty@tty1.service
```

This restores the console boot path without touching either kernel generation,
the boot partition or any device package. Re-enable the service and set
`graphical.target` when ready to retry.
