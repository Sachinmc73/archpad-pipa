# ArchPad roadmap and current state

Updated: **2026-09-09**
Device: **Xiaomi Pad 6 (`pipa`), Snapdragon 870, 6/128 GB, Tianma panel**

This is the single project-level source of truth. It records the milestone we
have reached, the fixed safety and boot decisions, what remains imperfect, and
the path to the final ArchPad system.

## Vision

ArchPad is a native, lightweight Arch Linux tablet and development
machine. Touch and eventually voice are primary interactions, while the Xiaomi
keyboard cover and ordinary terminal workflows remain first-class. It supports
development and terminal agents as well as browsing, video, streaming,
notes, pen input and light gaming.

The intended character is highly customisable and automation-friendly, inspired
by Omarchy but designed for a tablet rather than copied from a desktop setup.

OS-level AI agents and Google Gemini account integration are explicitly the
last phase. A dependable operating system comes first.

## Current milestone: Native Arch Linux ARM Base (Update-Safe)

The tablet runs **pure native Arch Linux ARM** with its core hardware foundation
functionally enabled and the userspace cleaned of graphical/desktop clutter.
Before deliberate Phase 4 compositor work, Phase 3.5 closes the remaining
reproducibility, update-safety, clock, rollback and native-Arch validation gaps.

| Component | Current validated value |
|---|---|
| Active slot | A |
| Userspace | Native Arch Linux ARM aarch64 (rolling), systemd, `multi-user.target` |
| Console Interface | Crisp 32px HiDPI Linux console on TTY1 (`ter-v32b` font) |
| Package Count | **328 packages** (326-package console baseline plus clock and fallback packages) |
| RAM Usage | **436 MiB / 5.40 GiB** in the r9 baseline manifest |
| Disk Usage | **2.8 GiB / 105 GiB (3%)** on nested GPT ext4 (`/dev/loop0p2`) |
| Kernel | Linux `7.1.4-pipa-r9`, package `linux-archpad-pipa-7.1.4-9`, running/default and hash-verified |
| Rollback kernel | `7.1.4-pipa` r7 as an independently packaged, fully boot-tested generation |
| Device package | `archpad-pipa-device-1.0.0-2`, Tianma variant |
| Firmware | `archpad-pipa-firmware-1.0.0-1` |
| Mesa/GPU | Mesa 26.2.2-arch1.1, Freedreno FD650 (GL 4.6 / GLES 3.2), Turnip (Vulkan 1.3) |
| Display | Tianma DSI-1, 1800×2880 native, 120 Hz, smooth `ktz8866-backlight` dimming |
| Audio Stack | ALSA UCM2 HiFi + PipeWire 1.6.8 + WirePlumber (4x Quad Speakers, 3-mic array) |
| Wireless | Qualcomm QCA6390 (Wi-Fi 6, iwd) + Bluetooth 5.1 (bluez) |
| Touch & Stylus | Novatek 10-point multitouch + 4096-level pressure/tilt Xiaomi Smart Pen |
| Camera stack | libcamera Simple pipeline; SK Hynix HI846W front + OV13B10 rear; CMA 128M |
| Swap / Memory | 2.7 GiB dynamic compressed RAM swap (`zram-generator`) |
| Workspace State | **13 GB** (31 GB reclaimed; safety backups and 30s kernel recompile tree kept) |

Pinned construction inputs:

- pmbootstrap commit `b6f47304382ed3a54968c9e56ed0602dba85dae9`
- pmaports commit `c6f27d1b653491029311e5c2bd0a25c4a654d436`
- U-Boot commit `c46bd5b2136158d3380d626d79c96827818226c5`
- upstream Linux 7.1.4 plus the checksummed pipa patches in
  `packages/linux-archpad-pipa/`
- pipa firmware source commit
  `842d35beffeda8c6d1b0e611b335543bf0e6b41e`
- signature-verified Arch Linux ARM AArch64 bootstrap; extracted pacman version
  7.1.0 and archive SHA-256
  `42a4eeaa038994ffd31fa173256ef2f0ef511358eeb41b9ea1f8626391b9b319`

Retained rollback kernel artifact:

- `linux-xiaomi-pipa-7.1.4-r7.apk`
- SHA-256 `82a0832e43badab375c082b5e6c72818f1af48075c214a4ccad88c42c5cac5ab`

The owner has completed the basic hardware smoke-test gate. Display and
brightness, touch dragging and browser multitouch, pen, keyboard cover, GPU,
Wi-Fi, Bluetooth, speakers, microphones, cameras, sensors/rotation,
battery/charging, USB and basic suspend/resume function. This is enough to
start the Arch system; it is not a claim of perfect tuning or endurance.

### Camera milestone

- Rear OV13B10 preview works but remains rotated, minimally processed and
  without working autofocus/actuator integration.
- Front camera is an AAC module using the SK Hynix HI846W sensor at CCI I2C
  address `0x20`, connected through CSIPHY4 with **two CSI-2 data lanes**.
- Front probe, raw capture, libcamera processing and Plasma Camera preview all
  work at 1632x1224 and 1280x720.
- Native Arch on kernel `7.1.4-pipa-r8` completed bounded 1280x720
  software-ISP viewfinder streams: 30/30 rear frames and 30/30 front frames.
  No frames were saved locally during this gate.
- The experimental 3264x1836 and 3264x2448 two-lane modes accepted STREAMON but
  returned no buffers. Kernel patch `0025` correctly hides them until their
  timings are solved.
- Mainline CAMSS provides raw capture; libcamera currently uses its software
  ISP. Proper sensor-specific exposure, colour and image-quality tuning remains
  future work.

### Known non-blocking limitations

- Audio currently uses a bounded module-reprobe service to recover an early
  kernel probe-order failure. This must eventually become a proper kernel fix.
- Microphone UCM gain was reduced from 124 to 112 to eliminate clipping.
- Camera orientation, rear focus and camera processing need improvement.
- Refresh-rate behaviour, speaker mapping, pen extras, charging combinations,
  DisplayPort combinations and long suspend/thermal endurance need deeper
  validation.
- Warning classification on the r8 validation boot:
  - four DSI PLL lock retries recovered before the display came up; three DSI
    status-5 recovery events also completed during the successful suspend test;
  - the failed 3.1872 GHz CPU voltage request is not exposed as an available
    frequency; CPU7 is bounded at its working 2.8416 GHz OPP;
  - `bq25980` charge-pump probing fails, so high-speed charging is not yet a
    supported claim; PM8150B USB power and `qcom-battery` reporting work;
  - GPU cooling-device registration is absent, so sustained thermal/load
    validation is required before heavy gaming or compilation claims;
  - four SoundWire port-count mismatches coexist with working playback and
    capture and remain audio-topology cleanup;
  - duplicate remoteproc handover and systemd `bpf-restrict-fs` messages did
    not produce a failed service or missing hardware;
  - Nanosic keyboard-cover I2C retries recover at boot, but one post-resume read
    error means cover behaviour needs a later manual suspend test;
  - Nuvolta's missing pen-SOC messages are incorrectly error-level chatter when
    no valid pen battery value is available.
- On the current r8 boot the Awinic driver emitted zero `fmt` debug messages
  and zero failure/error lines. The bounded audio service exited immediately
  because the ALSA card already existed. `archpad-pipa-device` 1.0.0-2 now
  installs the documentation referenced by that service; the service remains
  temporary until kernel probe ordering is fixed.
- These improvements can be delivered later as kernel, firmware or device-data
  package updates; none requires restarting the distribution design.

## Fixed boot and storage contract

The existing low-level boot path is proven and will be retained for ArchPad
v0.1:

```text
Qualcomm ROM
  -> Xiaomi firmware and ABL fastboot
  -> boot_a containing pipa U-Boot
  -> U-Boot maps the disk image inside Android userdata
  -> nested EFI System Partition and systemd-boot
  -> ArchPad kernel + initramfs + Tianma DTB
  -> nested ext4 Arch root
  -> systemd
```

The nested disk contains:

1. A FAT32 EFI System Partition with systemd-boot, kernel, initramfs and Tianma
   DTB.
2. An ext4 root partition containing Arch, pacman, modules, firmware and device
   packages.

Partition and filesystem UUIDs must be generated and recorded during each image
build. Boot entries use UUIDs rather than assumed `/dev/*` names.

## Non-negotiable safety rules

- **Never run `qbootctl` on pipa.** It previously damaged UFS GPT/slot metadata
  and caused an ABL fastboot loop.
- Change active slots only through Xiaomi ABL fastboot after verifying product,
  unlock state, slot count and current slot.
- Do not casually overwrite or erase the known-good `boot_a` U-Boot path.
- Do not mix postmarketOS, PocketBlue/Silicium or Android flashing instructions;
  they use different partition contracts.
- Build, inspect and hash images offline before writing the tablet.
- Keep a known-good kernel and rollback artifact for every low-level update.
- Do not install Alpine APK binaries into the Arch root filesystem.
- Credentials and Telegram sessions remain only in ignored files.
- Device data preservation is not required, but fastboot recovery must remain
  available.

## Reproducible package boundaries

ArchPad will separate the device layer so hardware can improve independently:

```text
linux-archpad-pipa       kernel, modules and Tianma DTB
archpad-pipa-firmware    pinned proprietary firmware
archpad-pipa-device      udev, input, sensor, power and platform integration
archpad-pipa-audio       ALSA UCM and audio policy
archpad-pipa-camera      libcamera data, orientation and future tuning
archpad-boot             mkinitcpio nested-root logic and boot deployment
archpad-session          touch shell, OSK, rotation and interaction policy
```

The authoritative current kernel inputs are the PKGBUILD, config and patches in
`packages/linux-archpad-pipa/`, presently through patch `0027`. All 27 inputs
have SHA-512 checksums and the 25-patch series applies cleanly to pristine
Linux 7.1.4. Release packages must be built in a clean AArch64 Arch
environment; package signing remains a later repository-release requirement.

## Development phases

### Phase 1 — Hardware reference: complete

- Researched maintained pipa Linux projects and exact source references.
- Built and booted the Tianma-specific validation system.
- Verified the secondary U-Boot and nested-`userdata` boot model.
- Recovered and documented the `qbootctl` hazard.
- Brought up audio and corrected microphone clipping for validation.
- Added and validated the HI846W front camera.
- Completed the owner-level basic hardware smoke-test gate.

### Phase 2 — ArchPad v0.1 console: complete

1. **[COMPLETE]** Build `linux-archpad-pipa` as a native pacman package in the
   clean AArch64 Arch builder and verify kernel/modules/DTB consistency.
   - Package: `artifacts/private/arch-kernel-r7/linux-archpad-pipa-7.1.4-7-aarch64.pkg.tar.xz`
   - SHA-256: `971815f161448ac192182a4e50407b08c9812dd2af7b21ed4bbbf89a8960bf9b`
   - 585/585 modules, 2-lane HI846 DTB and vermagic `7.1.4-pipa` verified.
2. **[COMPLETE]** Inventory and package exact firmware (`archpad-pipa-firmware`)
   with provenance, checksums, and Hexagon sensor registry.
3. **[COMPLETE]** Port ALSA UCM (`archpad-pipa-audio`), libinput quirks/udev
   (`archpad-pipa-device`), and libcamera (`archpad-pipa-camera`) as native
   Arch packages in `artifacts/private/arch-packages-r1/`.
4. **[COMPLETE]** Implement mkinitcpio hook (`archpad-userdata`) and 4K-sector
   nested GPT image builder (`losetup -b 4096`).
5. **[COMPLETE]** Flash release image (`archpad-userdata-sparse.img`) to
   `userdata` via fastboot.
6. **[COMPLETE]** Repeatable native console boot verified with clean silent
   HiDPI console login prompt (`ter-v32b`), 105 GB ext4 root, and USB CDC-NCM.

### Phase 3 — Functional Arch hardware base: complete

- **[COMPLETE]** Re-run hardware smoke tests under Arch Linux ARM:
  - **Display / Backlight:** Tianma 2880x1800 @ 120 Hz, smooth backlight dimming via `brightnessctl` on `ktz8866-backlight`.
  - **GPU / 3D:** Adreno 650 hardware acceleration verified via Mesa Turnip (Vulkan 1.3) and Freedreno (OpenGL 4.6 Core / GLES 3.2).
  - **Audio:** ALSA UCM2 HiFi profiles verified; stereo speaker playback tested (`speaker-test`); top-side 3-mic array capture verified without clipping (`arecord`). PipeWire, PipeWire-Pulse, and WirePlumber installed.
  - **Wi-Fi:** Qualcomm QCA6390 (Wi-Fi 6) managed via `iwd` on `wlan0`; active scanning and AP discovery verified.
  - **Bluetooth:** Bluetooth 5.1 controller (`hci0`) initialized with public MAC (`00:03:7F:12:05:06`); powered on and scanning verified.
  - **Input:** 10-point multi-touch (`event1`) and 4096-level pressure/tilt stylus pen (`event2`) verified with `evtest`.
  - **Cameras:** Mainline Simple pipeline enumerates front HI846W (using the
  initial `hi846.yaml` bring-up profile) and rear OV13B10. CMA was expanded
  to 128 MiB; both sensors were subsequently stream-verified on native Arch as
  recorded in Phase 3.5.
- **[COMPLETE]** Battery & fuel-gauge reporting accurate (`qcom-battery` / `pm8150b-charger`).
- **[COMPLETE]** Arch Linux ARM pacman repositories (`core`, `extra`, `alarm`,
  and its curated binary `aur` repository) synchronized.

### Phase 3.5 — Baseline hardening: complete

- **[COMPLETE]** Put authoritative sources and documents under Git version
  control; baseline commit `ef523e9` and builder/audit commit `f941910`.
- **[COMPLETE]** Preserve the nested-GPT/ESP/rootfs/sparse-image construction as a versioned,
  non-interactive builder with explicit inputs, root expansion and manifests.
- **[COMPLETE]** Remove kernel build nondeterminism: normalize the arm64 compat
  VDSO build path, sort Qualcomm register-generator set iteration, retain
  signature-verification support required by lockdown, disable automatic module
  signing and use no accidental build-time signing key. Two independent clean
  builds produced byte-identical Image, full/unstripped vmlinux, Tianma DTB,
  compat VDSO, generated A6xx header, config, System.map, Module.symvers and
  all 585 modules. Image SHA-256:
  `e86f360ccc39f5b18eaf9cbb2279d948dac62edccb4909e583f8a38178c7e8f0`.
- **[COMPLETE]** Deploy kernel updates as complete versioned generations:
  matching Image, DTB, initramfs and module tree, validated before activation.
  `archpad-boot` 1.1.4 provides the ALPM hook, generation manager and a guarded
  obsolete-generation removal command that refuses the running or default
  kernel. The active system is now r9; r8 was removed only after r9 and the r7
  fallback had both passed generation verification.
- **[COMPLETE]** Preserve r7 through the separately owned
  `linux-archpad-pipa-fallback` package. It was booted after the active kernel
  package had been upgraded to r8; its independent modules, touchscreen,
  hashes and clean system state were verified. The tablet was then returned to
  r8 for that rollback test and was subsequently upgraded to current/default
  r9.
- **[COMPLETE]** Set `Asia/Kolkata`, retain `systemd-timesyncd`, and install
  `archpad-clock` 1.0.1. Its bounded early-boot service explicitly loads the
  PMIC RTC module, restores wall time from a Linux-owned offset without writing
  PMIC/EFI state, and passed a cold userspace reboot: 1972 at RTC probe was
  corrected to 2026 in about 50 ms, with multi-user reached in 18 seconds.
- **[COMPLETE]** Capture a sanitized manifest of the exact 326-package console
  baseline at
  `artifacts/manifests/archpad-console-pre-hardening-2026-09-08.txt`.
- **[COMPLETE]** Verify bounded front/rear camera streams and suspend/resume on
  native Arch. Both cameras completed 30-frame 1280x720 streams. One
  RTC-alarm-controlled `s2idle` cycle resumed with the same boot ID after about
  14 seconds; zero units failed and touch, GPU, cameras, audio, Wi-Fi,
  Bluetooth and battery reporting remained present.
- **[COMPLETE]** Classify the Awinic/ASoC, DSI PLL, GPU cooling, charger,
  remoteproc, keyboard-I2C and BPF messages. No current item blocks GUI bring-up,
  but fast charging, GPU thermal integration and long suspend/load testing
  remain explicit reliability work.
- **[COMPLETE]** Install and cold-boot the reproducible r9 payload. r9 is
  running/default, both cameras enumerate, touchscreen/GPU/audio/Wi-Fi/
  Bluetooth/battery nodes are present, the clock one-shot succeeded and zero
  units failed. The guarded manager removed obsolete r8 only after r9 was
  running and default; r7 remains the independently packaged fallback.
- **[COMPLETE]** Capture the sanitized r9 runtime manifest at
  `artifacts/manifests/archpad-console-r9-2026-09-09.txt` (SHA-256
  `e397fb362c4f8a5b76d6c18a7d70d18d6c09edbbea6a08e9748d5d600f073757`).
  The older full image is explicitly retained only as a pre-GUI recovery
  artifact; regenerating a 114 GB image now would be immediately invalidated
  by Phase 4. A final flashable image and manifest are required after the GUI
  package set is fixed.
- **[OPEN, NON-BLOCKING]** `systemctl reboot` completed orderly userspace
  shutdown but left the tablet powered off; a long power-button press produced
  a normal 17.5-second cold boot. Diagnose the platform restart path before the
  first public release.
- **[OPEN, NEXT KERNEL]** BlueZ 5.87 requests `crypto_user`, while the kernel
  has `CONFIG_CRYPTO_USER` disabled. Bluetooth works and
  `systemd-modules-load` succeeds, so do not delete BlueZ's package-owned load
  file; enable the expected module in the next planned kernel release.

### Phase 4 — Touch-first ArchPad interface: in progress

- **[COMPLETED: Base Reset & Rollback]** Reset the environment back to pure minimal Arch Linux ARM console (`multi-user.target`, `ter-v32b` font, 326 packages) after evaluating prototype GUI shells (Phosh, Plasma).
- **[COMPLETED: Library & Workspace Cleanup]** Purged 50 residual desktop libraries and pruned 311 MB of journal logs; freed 31 GB on the host workspace while preserving recovery backups and the 30-second kernel rebuild tree.
- **[COMPLETE: Architecture]** `PHASE4-ARCHITECTURE.md` selects an
  UWSM-managed Hyprland session with ArchPad-owned policy and a Quickshell
  tablet shell. It defines the security, rotation, input-mapping, OSK and
  rollback gates and records the alternatives considered. `UI-SPEC.md` fixes
  the first shell's desktop, dock, drawer, Overview, quick-settings, app-pill,
  floating-window and edge-gesture behavior.
- **[NEXT: Reversible compositor proof]** Install the minimal compositor stack,
  retain `multi-user.target`, and launch it manually from TTY1. Do not enable a
  display manager or graphical autostart until GPU, touch, pen, scale,
  suspend/resume and clean exit are validated.
- **[PENDING]** Implement synchronized rotation/input mapping, then pass the
  automatic OSK compatibility matrix before building the Quickshell UI. The
  interim keyboard must provide dependable text entry; the recorded long-term
  target adds Gboard-class floating, split, swipe, prediction and multilingual
  modes without delaying the initial GUI proof.

### Phase 5 — Advanced Customization & AI Integration (Future)

- Tailor custom widget and status bar environment (e.g., Quickshell or Waybar) for tablet workflows.
- Native pen/stylus handwriting recognition and palm rejection tuning.
- OS-level Gemini AI agent integration.

## Immediate next action

Review the completed `PHASE4-ARCHITECTURE.md`, then execute its reversible 4B
compositor proof.
Keep the reboot path and `CONFIG_CRYPTO_USER` as explicit low-level backlog;
do not let GUI work hide either issue. Build the next full flashable release
only after the Phase 4 package set is fixed.
The former GUI blockers—source versioning, clock persistence, console
manifest, atomic kernel generations and a tested rollback—are now resolved.

## Minimal repository map

- `ROADMAP.md` — this project state and plan
- `PHASE4-ARCHITECTURE.md` — selected GUI stack, package boundaries and gates
- `UI-SPEC.md` — touch interaction, shell states and incremental build order
- `packages/` — authoritative Arch package sources
- `device/temporary-validation/` — only live-system workarounds still relevant
  during the Arch port; credentials are ignored
- `tools/` — reusable pipa inspection and camera diagnostics
- `telegram/` — bounded, read-only research client and its security README
- `artifacts/` — ignored downloads, validation images and recovery artifacts
- `work/` — ignored build environments and checkouts required for the next
  stage

Superseded research, build checkpoints, boot-contract notes and camera handoffs
were removed from the working tree after this milestone. A recoverable copy is
kept outside normal context discovery at
`artifacts/private/archpad-pre-arch-milestone-docs-2026-09-06.tar.gz`, SHA-256
`8d7b22ed471856851494d34bb97ff24b210d9026d85b9eb8c9a8d9344a0f61a0`.
