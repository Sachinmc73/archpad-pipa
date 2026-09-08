# ArchPad Handoff to Antigravity

Updated: **2026-09-08 22:48 IST**

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
| **Phase 3.5: Baseline Hardening** | **IN PROGRESS** | Versioning, reproducible image construction, complete kernel generations, clock persistence and bounded native-Arch validation. |

Phase 3.5 clock hardening is complete. Package `archpad-clock` 1.0.1 restores
time from a Linux-owned PMIC-counter offset and never writes PMIC registers or
EFI variables. A reboot verified correction from the RTC's 1972 base to 2026
in roughly 50 ms; multi-user was reached in 18 seconds with no failed units.

Phase 3.5 kernel-update hardening is also complete. `archpad-boot` 1.1.3
creates a versioned boot generation only after checking the kernel, Tianma DTB,
matching module vermagic and generated initramfs, then changes the persistent
systemd-boot default only after hash validation. EFI variables are read-only in
this U-Boot environment, so the manager updates `loader.conf` atomically.

Current boot generations:

- `7.1.4-pipa-r8`: current/default, from `linux-archpad-pipa 7.1.4-8`.
- `7.1.4-pipa`: known-good r7 fallback, owned by
  `linux-archpad-pipa-fallback 7.1.4-7` with its complete Image, DTB,
  initramfs and module tree.

Rollback was tested end-to-end after upgrading the active package: r7 booted,
loaded `nt36523_ts` from the separately retained module tree, passed all boot
hashes and had zero failed units. The system then booted back to r8. Automatic
in-tree module signing with a different generated key on every build was
disabled; Secure Boot and signature enforcement are not active.

Native-Arch hardware gates now closed on r8:

- Rear OV13B10 and front HI846 each completed 30/30 frames at 1280x720 through
  libcamera's Simple/software-ISP path. The rear sensor's default full-resolution
  software-ISP allocation still exceeds the bounded 128 MiB CMA pool; normal
  preview resolutions work.
- A single `rtcwake -m mem -s 10` test entered `s2idle` and resumed with the
  same boot ID after about 14 seconds. No units failed, battery remained at
  99%, and touch, GPU, two cameras, audio, Wi-Fi and Bluetooth remained
  enumerated after resume.

---

## 3. Strict Operating Standards (User-Mandated)

1. **No intrusive or non-standard workarounds:** Do not patch system binaries, mask essential system services without explicit necessity, or bypass security layers.
2. **Explain before acting:** Always explain why a step is necessary and what it does before applying system-level modifications.
3. **Solve problems at the root:** For example, do not disable or hide a lockscreen issue; resolve the underlying PAM / compositor integration cleanly.
4. **Preserve stability:** Do not touch partition tables, kernel modules, or hardware configs without safety checks.

---

## 4. Immediate Next Step: Finish Phase 3.5 Validation

Do not install the final GUI yet. The former blockers—Git versioning, image
builder, baseline manifest, persistent clock, atomic kernel update and complete
rollback generation—are resolved. Complete the remaining bounded checks:

1. classify the current non-fatal kernel warnings (fast-charge probe, top CPU
   voltage, SoundWire ports and pen-charging chatter);
2. regenerate the release manifest and perform two clean-build comparisons.

The Arch Linux ARM `[aur]` entry is a curated binary repository and is not the
same service as `aur.archlinux.org`; retain or remove it only through an
explicit repository-trust decision. The current audio journal contains real
amplifier failure lines in addition to harmless format debug prints, so keep
audio triage open.
