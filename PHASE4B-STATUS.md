# Phase 4B reversible compositor proof

Status: **installed; physical validation pending — 2026-09-09**

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
- `archpad-session 0.1.0-1`, built from `packages/archpad-session/`.

The full system was updated first. The resulting console has 459 packages,
uses about 487 MiB RAM at idle and occupies 4.5 GiB of the 105 GiB rootfs.
`multi-user.target` is still the default and no display manager is installed or
enabled.

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

The `archpad-session` package SHA-256 is
`153b7f3904c480ac267319cbda279da586b65721e7424f2478419f3c8d7ef754`.
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

## Physical proof procedure

From TTY1, log in as the normal `archpad` user and run:

```sh
archpad-session
```

Expected first screen: a minimal Hyprland desktop at scale 2 with one Foot
terminal. This is a compositor test surface, not the finished ArchPad shell.
Use `Super+Return` for another terminal and `Super+Shift+E` for clean logout.

Validate, in order:

1. native panel mode, correct orientation, acceptable scale and no corruption;
2. touch taps and continuous dragging;
3. pen position, motion, pressure behavior and no obvious mapping offset;
4. keyboard-cover input and the recovery/logout shortcuts;
5. three-finger horizontal workspace switching;
6. clean logout back to TTY1;
7. after the first six pass, one suspend/resume cycle and repeat touch/pen.

During the running session, use SSH to capture `hyprctl monitors -j`,
`hyprctl devices -j`, renderer logs and resource use. Do not proceed to the
rotation service, OSK or Quickshell shell until this gate is recorded as passed.

## Recovery

The graphical session is not part of boot. If it fails, use another TTY or SSH
and stop the user's graphical session; the console remains the normal boot
path. Removing `archpad-session` and `hyprland` returns to the console state
without touching either kernel generation, boot partition or device packages.
