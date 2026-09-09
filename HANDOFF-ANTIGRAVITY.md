# ArchPad Handoff to Antigravity

Updated: **2026-09-08 22:53 IST**

Read `ROADMAP.md` for the single project-level source of truth.

---

## 1. Current Device & System State

The tablet has successfully migrated from postmarketOS to **pure native Arch Linux ARM** and runs as a minimal, hardware-verified system.

- **Device:** Xiaomi Pad 6 (`pipa`), Snapdragon 870 (sm8250), 6/128 GB, Tianma LCD.
- **Active Slot:** Slot A (`boot_a`).
- **OS & Kernel:** Arch Linux ARM (aarch64), Linux `7.1.4-pipa-r8`, package `linux-archpad-pipa-7.1.4-8`.
- **Runlevel:** `multi-user.target` (pure console, zero desktop/GUI daemons active).
- **Physical Display:** Tianma DSI-1 (1800×2880 @ 120 Hz) with crisp 32px HiDPI font (`ter-v32b`).
- **Package Count:** **328 packages** (`pacman -Q`).
- **Resource Usage:** **421 MiB RAM** at the latest check, **2.8 GiB disk usage** (3% of 105 GB ext4 root on `/dev/loop0p2`).
- **Compressed Swap:** 2.7 GiB dynamic zram swap active (`zram-generator`).
- **Build Toolchain:** `git`, `fakeroot`, `binutils`, and `yay-bin` (13.0.1) are installed and ready.

### Network & SSH Access
- **USB Gadget Network:** `usb0` on `172.16.42.1/24` (host at `172.16.42.2`).
- **SSH Config:** Host `~/.ssh/config` is aliased as `archpad` (`HostName 172.16.42.1`, user `root`, key `~/.ssh/id_ed25519`).
- **Wi-Fi 6:** Qualcomm QCA6390 managed via `iwd` (`iwctl station wlan0 ...`).
- **Bluetooth 5.1:** `hci0` active with public MAC (`00:03:7F:12:05:06`).

---

## 2. Completed Milestones

| Phase / Stage | Status | Notes |
|---|---|---|
| **Phase 1: U-Boot Exploration** | Closed | U-Boot runs inside Android `boot_a` as standard UEFI firmware (`EFI v2.11 by Das U-Boot`), which launches `systemd-boot`. The host compile tree `work/u-boot` is archived. |
| **Tablet Backup Safety Gate** | **VERIFIED** | Full raw backup stored in `artifacts/private/tablet-backup-postmarketos-2026-09-07/` (3.5 GB). |
| **Phase 2: Arch Native Packaging & Boot** | **COMPLETE** | Custom kernel (`linux-archpad-pipa`), firmware, device packages, nested GPT userdata hook flashed. |
| **Phase 3: Functional Hardware Base** | **COMPLETE** | Display, GPU, basic audio, wireless and input smoke tests passed; both cameras enumerate. Native-Arch camera streaming, suspend/resume and deeper reliability remain in Phase 3.5. |
| **Rollback & Cleanup** | **COMPLETE** | Purged temporary GUI prototypes (Phosh, Plasma), vacuumed 311 MB journal logs, and reclaimed 31 GB on host workspace. |
| **Phase 3.5: Baseline Hardening** | **IN PROGRESS** | Kernel reproducibility, complete generations, rollback, clock and bounded hardware validation are complete; r9 first-boot confirmation and release-manifest disposition remain. |

Phase 3.5 clock hardening is complete. Package `archpad-clock` 1.0.1 restores
time from a Linux-owned PMIC-counter offset and never writes PMIC registers or
EFI variables. A reboot verified correction from the RTC's 1972 base to 2026
in roughly 50 ms; multi-user was reached in 18 seconds with no failed units.

Phase 3.5 kernel-update hardening is also complete. `archpad-boot` 1.1.4
creates a versioned boot generation only after checking the kernel, Tianma DTB,
matching module vermagic and generated initramfs, then changes the persistent
systemd-boot default only after hash validation. EFI variables are read-only in
this U-Boot environment, so the manager updates `loader.conf` atomically.

Current boot generations:

- `7.1.4-pipa-r9`: installed/default and hash-verified, from
  `linux-archpad-pipa 7.1.4-9`; first running-boot confirmation is pending.
- `7.1.4-pipa-r8`: last confirmed running kernel; its boot files remain until
  r9 boots and the guarded manager can safely remove this obsolete generation.
- `7.1.4-pipa`: known-good r7 fallback, owned by
  `linux-archpad-pipa-fallback 7.1.4-7` with its complete Image, DTB,
  initramfs and module tree.

Rollback was tested end-to-end after upgrading the active package: r7 booted,
loaded `nt36523_ts` from the separately retained module tree, passed all boot
hashes and had zero failed units. The system then booted back to r8. Automatic
module signing is disabled and the build uses no accidental ephemeral key;
signature-verification support remains because the kernel lockdown framework
requires it, while enforcement and Secure Boot are not active.

Kernel r9 reproducibility is verified. Two independent clean output trees
produced identical Image, full/unstripped vmlinux, Tianma DTB, compat VDSO,
generated A6xx header, config, System.map, Module.symvers and 585/585 modules.
The Image SHA-256 is
`e86f360ccc39f5b18eaf9cbb2279d948dac62edccb4909e583f8a38178c7e8f0`.
All 27 source checksums pass and all 25 patches apply to pristine Linux 7.1.4.

Native-Arch hardware gates now closed on r8:

- Rear OV13B10 and front HI846 each completed 30/30 frames at 1280x720 through
  libcamera's Simple/software-ISP path. The rear sensor's default full-resolution
  software-ISP allocation still exceeds the bounded 128 MiB CMA pool; normal
  preview resolutions work.
- A single `rtcwake -m mem -s 10` test entered `s2idle` and resumed with the
  same boot ID after about 14 seconds. No units failed, battery remained at
  99%, and touch, GPU, two cameras, audio, Wi-Fi and Bluetooth remained
  enumerated after resume.

Kernel-warning triage is complete for GUI-gate purposes. DSI retries recover,
the invalid 3.1872 GHz CPU request is excluded in favour of the working
2.8416 GHz maximum, and audio currently initializes without using its reprobe
path. Fast-charge-pump support and GPU cooling-device registration remain real
future power/thermal work; keyboard-cover suspend behaviour needs a later
manual check. `archpad-pipa-device` 1.0.0-2 fixes the service's previously
missing documentation file.

---

## 3. Strict Operating Standards (User-Mandated)

1. **No intrusive or non-standard workarounds:** Do not patch system binaries, mask essential system services without explicit necessity, or bypass security layers.
2. **Explain before acting:** Always explain why a step is necessary and what it does before applying system-level modifications.
3. **Solve problems at the root:** For example, do not disable or hide a lockscreen issue; resolve the underlying PAM / compositor integration cleanly.
4. **Preserve stability:** Do not touch partition tables, kernel modules, or hardware configs without safety checks.

---

## 4. Immediate Next Step: Confirm r9 and Finish Phase 3.5

Do not install the final GUI yet. The former blockers—Git versioning, image
builder, baseline manifest, persistent clock, atomic kernel update and complete
rollback generation and clean kernel reproducibility—are resolved. Complete
the remaining bounded checks:

1. determine the visible state of the tablet after the first r9 reboot and
   complete running-kernel/hardware validation;
2. use `archpad-kernel-generation remove 7.1.4-pipa-r8` only after r9 is both
   running and default;
3. regenerate or explicitly supersede the stale release manifest.

The Arch Linux ARM `[aur]` entry is a curated binary repository and is not the
same service as `aur.archlinux.org`; retain or remove it only through an
explicit repository-trust decision. Current audio initializes normally; its
bounded reprobe fallback and warning classification are documented.
