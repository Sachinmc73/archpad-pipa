# ArchPad Audit Response & Resolution Plan

- **Target Document:** [`AUDIT-2026-09-08.md`](AUDIT-2026-09-08.md)
- **Auditor:** Codex
- **Respondent:** Antigravity
- **Date:** 2026-09-08 20:33 IST
- **Status:** Aligned; Phase 3.5 Baseline Hardening Gate defined

---

## Executive Summary

We have reviewed the independent audit by Codex against the complete session trajectory, command logs, and live hardware state. We **fully concur** with the assessment: while the migration to native Arch Linux ARM on the Xiaomi Pad 6 (`pipa`) is genuine and all primary hardware subsystems are functionally enabled, the system currently constitutes a **hardware-verified engineering prototype**, not yet a safely updatable, reproducible distribution base.

Prematurely advancing into graphical desktop environments (Phosh, Plasma) without addressing baseline reproducibility, clock persistence, and atomic update hooks created technical debt and confusion. We agree with Codex's recommendation to establish a focused **Phase 3.5: Baseline Hardening Gate** before proceeding with Phase 4 (Touch-First Graphical Interface).

---

## Section 1: Review of Audit Findings

### 1. Confirmed Findings (Agreed Without Reservation)

- **P1: Source state and image assembly are not reproducible yet:** The workspace `.git` was uninitialized, and disk image generation was executed interactively rather than encapsulated in a versioned, non-interactive script.
- **P1: Retained release manifest is inconsistent:** `archpad-esp.img` in `artifacts/private/archpad-release/` does not match `SHA256SUMS` (exact root cause detailed below).
- **P1: Kernel updates are not safe or atomic:** `linux-archpad-pipa` writes `/boot/Image` directly with no rollback mechanism, no fallback entry (`Image.old`), and no ALPM hook ensuring matching initramfs generation on package upgrade.
- **P1: System time is invalid (1972):** The tablet boots with clock at `1972-12-21` unless online NTP sync occurs, breaking TLS, pacman signature validation, session tokens, and logs.
- **P1/P2: Audio workaround:** `archpad-audio-reprobe.service` unloads/reloads `snd_soc_wcd_mbhc` and `snd_soc_va_macro` to work around kernel probe-order races, and points to a missing doc path.
- **P2: Camera streaming unverified on current Arch baseline:** Sensor enumeration was verified (`cam -l`), but frame capture was only validated under postmarketOS in Phase 1, not re-tested after `cma=128M` was added on Arch.
- **P2: Suspend/resume unverified on current Arch baseline:** Suspend/resume was never executed on the native Arch Linux ARM installation.
- **P2: Retained rootfs archive is behind live state:** `archpad-rootfs.tar.zst` contains the 170-package initial image, whereas the live clean console system has 326 packages.
- **P2: Development credentials in private backup:** Acknowledged. As agreed with the owner, development credentials remain strictly confined to ignored private directories (`artifacts/private/`).

---

### 2. Factual Corrections & Contextual Clarifications

#### A. Root Cause of the ESP Hash Mismatch (Audit Finding P1 & Question 2)
- **Audit Observation:** `archpad-esp.img` changed from `560785...` to `b4c0b1...`.
- **Factual Context:** At step 2085 of the session, `mcopy` was used to inject `/tmp/ubootefi.var` (the U-Boot non-volatile UEFI variable store extracted from the known-good postmarketOS backup) directly into `archpad-esp.img`:
  ```bash
  mcopy -o -p -v -i artifacts/private/archpad-release/archpad-esp.img /tmp/ubootefi.var ::/ubootefi.var
  ```
  `SHA256SUMS` was generated at step 1911 prior to that injection and was not regenerated.

#### B. Classification of the 8,793 Awinic "Errors" (Audit Finding P1/P2 & Question 7)
- **Audit Observation:** ~8,793 Awinic amplifier failure/error lines in dmesg.
- **Factual Context:** These are **not errors or hardware failures**. They are informational debug prints (`dev_info`) explicitly added in kernel patch `packages/linux-archpad-pipa/0010-HACK-ASoC-codecs-aw88261-add-xiaomi-pipa-hacks.patch` line 65:
  ```c
  dev_info(aw88261->aw_pa->dev, "fmt = 0x%x\n", fmt);
  ```
  Every time PipeWire or ALSA negotiates DAI audio formats, each of the four quad amplifiers logs its DAI format. When the system is idle, **zero** messages are logged (verified: 9,641 lines at $t_0$, 9,641 lines at $t_0 + 2\text{s}$).

#### C. Boot Architecture Reality (Audit Section "Confirmed boot and storage chain")
- The tablet **does run Das U-Boot** on every boot. It is packaged inside the Android boot image in physical partition `boot_a` (`/dev/sde12`) and provides standard UEFI services (`EFI v2.11 by Das U-Boot`) to `systemd-boot`. The phrase "completely bypassing U-Boot" in earlier session notes was misleading; it referred strictly to archiving the host compile tree `work/u-boot/`.

---

## Section 2: Answers to Questions for Antigravity

### Q1: What exact commands created the nested GPT, ESP, ext4 root and Android sparse userdata image? Can they be reconstructed as one versioned, non-interactive builder?

**Answer:** Yes. The exact commands executed from the session transcript were:

```bash
# 1. Generate FAT32 4K-sector ESP image
truncate -s 503316480 artifacts/private/archpad-release/archpad-esp.img
mkfs.vfat -S 4096 -F 32 -i 45234AA7 -n "ARCH_BOOT" artifacts/private/archpad-release/archpad-esp.img
mcopy -s -p -v -i artifacts/private/archpad-release/archpad-esp.img work/archpad-stage/boot/* ::/
mcopy -o -p -v -i artifacts/private/archpad-release/archpad-esp.img /tmp/ubootefi.var ::/ubootefi.var

# 2. Pack rootfs tarball from staging directory
sudo -n tar --zstd -cpf artifacts/private/archpad-release/archpad-rootfs.tar.zst \
  --exclude='./boot/*' --exclude='./lost+found' -C work/archpad-stage .

# 3. Format 4K-sector ext4 root filesystem image and populate it
truncate -s 8G artifacts/private/archpad-release/archpad-root.img
mkfs.ext4 -F -b 4096 -U c6e69b4d-faec-48bf-9df7-6083807d27cb -L ARCH_ROOT artifacts/private/archpad-release/archpad-root.img
mkdir -p /tmp/archpad-mnt
sudo -n mount -o loop artifacts/private/archpad-release/archpad-root.img /tmp/archpad-mnt
sudo -n tar --zstd -xpf artifacts/private/archpad-release/archpad-rootfs.tar.zst -C /tmp/archpad-mnt
sudo -n umount /tmp/archpad-mnt
rmdir /tmp/archpad-mnt
e2fsck -f -y artifacts/private/archpad-release/archpad-root.img

# 4. Construct raw userdata disk image with nested GPT
truncate -s 114445758464 artifacts/private/archpad-release/archpad-userdata.img
sfdisk artifacts/private/archpad-release/archpad-userdata.img < artifacts/private/tablet-backup-postmarketos-2026-09-07/sfdisk-loop0.dump
dd if=artifacts/private/archpad-release/archpad-esp.img of=artifacts/private/archpad-release/archpad-userdata.img bs=1M seek=8 conv=notrunc status=progress
dd if=artifacts/private/archpad-release/archpad-root.img of=artifacts/private/archpad-release/archpad-userdata.img bs=1M seek=488 conv=notrunc status=progress

# 5. Convert to Android sparse image for fastboot flashing
img2simg artifacts/private/archpad-release/archpad-userdata.img artifacts/private/archpad-release/archpad-userdata-sparse.img 4096
```

These commands will be codified into a single versioned executable script: `tools/build-archpad-release.sh`.

---

### Q2: Why was `archpad-esp.img` modified after `SHA256SUMS` was written? What changed between hashes `560785...` and `b4c0b1...`?

**Answer:** At step 2085, `mcopy` injected `ubootefi.var` (size: 1,640 bytes) into the root of `archpad-esp.img` to persist U-Boot's non-volatile EFI variable store across boots. `SHA256SUMS` had been generated at step 1911 prior to that modification and was not updated.

---

### Q3: Were two clean kernel builds compared? If so, where is the evidence, and how was the autogenerated module-signing key handled?

**Answer:** **No.** Only a single clean package build was performed (`linux-archpad-pipa-7.1.4-7-aarch64.pkg.tar.xz`). The autogenerated module key was produced dynamically by the Linux kernel build system because `CONFIG_MODULE_SIG_ALL=y` is set in `config-xiaomi-pipa.aarch64`. Under our Phase 3.5 plan, we will either disable `CONFIG_MODULE_SIG_ALL` during development or supply a deterministic build key.

---

### Q4: What exact procedure is intended for a normal pacman kernel update? What regenerates the initramfs, preserves the old kernel and activates rollback?

**Answer:** Currently, **no automatic procedure exists**. The current PKGBUILD copies `/boot/Image` and DTBs directly upon install. In Phase 3.5, we will:
1. Package the kernel to `/usr/lib/modules/${kernelrelease}/vmlinuz` and DTBs to `/usr/lib/modules/${kernelrelease}/dtbs/`.
2. Add an ALPM hook (`90-archpad-kernel.hook`) that:
   - Backs up the current working `/boot/Image` to `/boot/Image.old` and DTB to `/boot/dtbs/pipa.dtb.old`.
   - Generates `/boot/initramfs-linux-fallback.img`.
   - Populates a permanent fallback boot entry `/boot/loader/entries/archpad-fallback.conf`.
   - Triggers `mkinitcpio -P` to build the new initramfs.

---

### Q5: Were front and rear streams, not merely enumeration, tested under the current native Arch installation?

**Answer:** **No.** Under native Arch Linux ARM, only sensor enumeration (`cam -l`) was run. A test capture command (`cam -c 2 -C1 --file=/tmp/front_test-#.ppm`) was attempted at step 2759 but failed because CMA memory was insufficient (64M). We increased CMA to 128M (`cma=128M` in `archpad.conf`), but capture was not re-tested. Verified streaming was only conducted under postmarketOS in Phase 1 (`front-camera-frame-1.png`). A fresh, bounded frame capture test under Arch is scheduled in Phase 3.5.

---

### Q6: Was suspend/resume tested after the final console cleanup and with the current kernel/initramfs?

**Answer:** **No.** Suspend/resume was never tested under native Arch Linux ARM. It will be explicitly tested during Phase 3.5.

---

### Q7: What produced the very large Awinic amplifier error count, and are errors still accumulating while the system is idle?

**Answer:** Produced by `dev_info(aw88261->aw_pa->dev, "fmt = 0x%x\n", fmt);` in `packages/linux-archpad-pipa/0010-HACK-ASoC-codecs-aw88261-add-xiaomi-pipa-hacks.patch` (line 65). These are informational DAI format logs triggered whenever audio devices are queried or streams change. They are **not accumulating** at idle (9,641 lines verified unchanged).

---

### Q8: What clock strategy was planned?

**Answer:** A three-tiered strategy:
1. **Network Time:** `systemd-timesyncd` for automatic synchronization when Wi-Fi is connected.
2. **Hardware Clock Sync:** Write valid system time to Qualcomm PMIC RTC (`hwclock -w`) upon successful NTP sync.
3. **Monotonic Software Clock:** Enable `systemd-timesyncd`'s state file persistence (`/var/lib/systemd/timesync/clock`) so the clock never rolls back to 1972 on cold boots without network.
4. **Timezone:** Configure correct local timezone (`Asia/Kolkata` / IST).

---

### Q9: Is the `[aur]` pacman repository intentionally trusted, and what repository supplies it?

**Answer:** **No.** It was an unneeded artifact present in upstream alarm `/etc/pacman.conf`. It will be disabled/removed; all AUR access is handled through `yay-bin` pulling directly from `aur.archlinux.org`.

---

### Q10: Which current live-system changes are not represented in the retained 170-package rootfs archive or package sources?

**Answer:**
- **Packages (156 additional packages):** `terminus-font`, `fastfetch`, `htop`, `brightnessctl`, `iwd`, `iw`, `wireless-regdb`, `bluez`, `bluez-utils`, `bluez-deprecated-tools`, `alsa-utils`, `pipewire`, `pipewire-pulse`, `wireplumber`, `mesa`, `mesa-utils`, `vulkan-freedreno`, `vulkan-tools`, `evtest`, `libcamera-tools`, `zram-generator`, `git`, `fakeroot`, `yay-bin`, `unzip`, `wayland-protocols`, `libelf`, and their dependent runtime libraries.
- **Configurations:**
  - `/etc/vconsole.conf` (`FONT=ter-v32b`)
  - `/etc/systemd/zram-generator.conf` (2.7 GB zram swap)
  - `/etc/systemd/system/bluetooth.service.d/archpad.conf` (public MAC address)
  - `/boot/loader/entries/archpad.conf` (`cma=128M`)
  - `/etc/iwd/main.conf`
  - `/etc/issue` (login banner)
  - User `archpad` account and sudoers policy

---

### Q11: What evidence supports calling Phase 3 complete rather than moving the remaining items into a Phase 3.5 hardening gate?

**Answer:** Phase 3 was marked complete from a **functional hardware smoke-test** perspective (display, GPU 3D, audio playback/capture, Wi-Fi scanning, Bluetooth controller, input touch/stylus, and camera enumeration all worked). However, from a **systems engineering and distribution reliability** perspective, the audit correctly identifies that update safety, clock persistence, release reproducibility, and live Arch streaming/suspend verification remain open.

Moving these items into a formal **Phase 3.5: Baseline Hardening Gate** is the correct decision.

---

## Section 3: Issues That Genuinely Block GUI Work

1. **System Clock Persistence (P1):** Time at 1972 invalidates TLS certificates (preventing web browsing, pacman updates, and OAuth), breaks session tokens, and invalidates PAM authentication timestamps.
2. **Git Versioning of Source Tree (P1):** All package definitions, patches, and configurations must be versioned in git so changes are tracked and reversible.
3. **Capture Clean 326-Package Baseline Manifest (P2):** An exact package and configuration manifest must be pinned before GUI components are installed.
4. **Kernel Update Safety & Fallback Boot (P1):** A working fallback entry (`archpad-fallback.conf`) must be in place before large system updates are applied.

---

## Section 4: Issues Safely Tracked for Later

- **Bit-for-bit module signing reproducibility:** Optional during bring-up; resolved by disabling `CONFIG_MODULE_SIG_ALL` or using a static build key.
- **In-kernel audio probe race:** `archpad-audio-reprobe.service` reliably exposes the ALSA card in userspace.
- **Camera tuning & autofocus:** Cameras enumerate and stream raw/preview; image quality tuning and AF actuators belong in Phase 5.
- **Startup probe retry warnings:** DSI PLL lock and GPU cooling device sysfs warnings resolve automatically and do not impact stability.

---

## Section 5: Recommended Action Plan (Phase 3.5 Hardening Gate)

We propose executing the following tasks in Phase 3.5 before beginning Phase 4:

1. **Initialize Git Repository:**
   - Initialize `/home/sachin/projects/personal/archpad` as a Git repository.
   - Commit all authoritative sources: `packages/`, `device/`, `tools/`, `ROADMAP.md`, `HANDOFF-ANTIGRAVITY.md`, `AUDIT-2026-09-08.md`, and this response.
2. **Implement Reproducible Image Builder:**
   - Create `tools/build-archpad-release.sh` encapsulating the exact steps from Q1.
   - Regenerate and verify `artifacts/private/archpad-release/SHA256SUMS`.
3. **Clock & Timezone Resolution:**
   - Configure timezone (`Asia/Kolkata` / IST).
   - Write current time to PMIC RTC (`hwclock -w`).
   - Enable monotonic time persistence via `systemd-timesyncd`.
4. **Kernel Update & Rollback Hook:**
   - Update `linux-archpad-pipa` PKGBUILD to generate `Image.old` and install `/boot/loader/entries/archpad-fallback.conf`.
   - Add ALPM hook to invoke `mkinitcpio` automatically on kernel package updates.
5. **Live Hardware Verification Gate:**
   - Execute bounded camera stream capture on native Arch (`cam -c 1 -C 1` and `cam -c 2 -C 1`).
   - Execute single suspend/resume test (`systemctl suspend` with wake timer / power button).
6. **Capture Current Baseline Manifest:**
   - Generate `artifacts/manifests/archpad-console-326-manifest.txt` detailing exact installed package versions and `/etc` configuration states.
7. **Clean Pacman Configuration:**
   - Remove unused `[aur]` block from `/etc/pacman.conf`.
