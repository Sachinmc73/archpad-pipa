# ArchPad Handoff to Antigravity

Updated: **2026-09-08 19:55 IST**

Read `ROADMAP.md` for the single project-level source of truth.

---

## 1. Current Device & System State

The tablet has successfully migrated from postmarketOS to **pure native Arch Linux ARM** and runs as a minimal, hardware-verified system.

- **Device:** Xiaomi Pad 6 (`pipa`), Snapdragon 870 (sm8250), 6/128 GB, Tianma LCD.
- **Active Slot:** Slot A (`boot_a`).
- **OS & Kernel:** Arch Linux ARM (aarch64), Linux `7.1.4-pipa`, package `linux-archpad-pipa-7.1.4-7`.
- **Runlevel:** `multi-user.target` (pure console, zero desktop/GUI daemons active).
- **Physical Display:** Tianma DSI-1 (1800×2880 @ 120 Hz) with crisp 32px HiDPI font (`ter-v32b`).
- **Package Count:** **326 packages** (`pacman -Q`).
- **Resource Usage:** **477 MiB RAM** idle (9%), **2.60 GiB disk usage** (2% of 105 GB ext4 root on `/dev/loop0p2`).
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

---

## 3. Strict Operating Standards (User-Mandated)

1. **No intrusive or non-standard workarounds:** Do not patch system binaries, mask essential system services without explicit necessity, or bypass security layers.
2. **Explain before acting:** Always explain why a step is necessary and what it does before applying system-level modifications.
3. **Solve problems at the root:** For example, do not disable or hide a lockscreen issue; resolve the underlying PAM / compositor integration cleanly.
4. **Preserve stability:** Do not touch partition tables, kernel modules, or hardware configs without safety checks.

---

## 4. Immediate Next Step: Phase 3.5 (Baseline Hardening)

Do not install the final GUI yet. Reconcile `AUDIT-2026-09-08.md` and
`AUDIT-RESPONSE-2026-09-08.md`, then complete the Phase 3.5 gate in
`ROADMAP.md`. In particular, do not implement an `Image.old`-only fallback:
rollback must retain matching kernel, DTB, initramfs and modules as one
bootable generation.

The Arch Linux ARM `[aur]` entry is a curated binary repository and is not the
same service as `aur.archlinux.org`; retain or remove it only through an
explicit repository-trust decision. The current audio journal contains real
amplifier failure lines in addition to harmless format debug prints, so keep
audio triage open.
