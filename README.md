# ArchPad-Pipa: Arch Linux ARM for Xiaomi Pad 6 (`pipa`)

<p align="center">
  <img src="artwork/logo-tablet.png" alt="ArchPad Logo" width="180">
</p>

<p align="center">
  <b>A pure, near-mainline Arch Linux ARM experience for the Xiaomi Pad 6 (Snapdragon 870).</b><br>
  Built with standard Linux desktop principles — no Android HALs, no libhybris, and zero Desktop Environment lock-in.
</p>

---

## Highlights

* **Pure Linux Desktop Experience**: Runs modern Wayland environments (KDE Plasma 6, GNOME, Phosh, Hyprland, Sway) with hardware-accelerated graphics.
* **Near-Complete Hardware Support**: 144Hz 2.8K display, Adreno 650 Vulkan/OpenGL acceleration, quad-speaker audio with lookahead peak limiter, dual cameras with autofocus, Wi-Fi 6, Bluetooth 5.2, and automatic screen rotation.
* **Clean Architecture**: All device enablement is implemented through standard Linux subsystems (`DRM/KMS`, `ALSA UCM2`, `PipeWire`, `IIO / SensorProxy`, `libcamera`, `UPower`, and `systemd-logind`).
* **Packaging & Reproducibility**: 100% managed through native Arch Linux `PKGBUILD`s in `packages/`. Full DKMS support via split kernel headers.

---

## Hardware Support Matrix

| Subsystem | Hardware Component | Status | Details |
| :--- | :--- | :---: | :--- |
| **Display** | 11.0" 2880×1800 144Hz IPS LCD | **Working** | 60/144Hz modes, DSC slice compression, standard DRM panel orientation. |
| **Touch & Pen** | Novatek NT36523 Digitizer | **Working** | Multi-touch, palm rejection via `libinput`, stylus digitizer recognized. |
| **GPU (3D)** | Qualcomm Adreno 650 | **Working** | Mesa `turnip` (Vulkan 1.3) & `freedreno` (OpenGL 4.6). Hardware Wayland planes. |
| **Video VPU** | Qualcomm Venus 5.4 | **Working** | Hardware accelerated H.264, HEVC, and VP9 decode/encode via V4L2 M2M. |
| **Audio (Out)** | 4× Awinic AW88261 Amps (TDM) | **Working** | ALSA UCM2 + PipeWire lookahead limiter (zero crackle at 100% volume). |
| **Audio (In)** | Triple Top Microphones + Jack | **Working** | Clear digital capture via QDSP6 TX macro; auto jack detection. |
| **Cameras** | Rear: OV13B10 13MP + VCM AF<br>Front: HI846 8MP | **Working** | Native `libcamera` pipeline with DW9714 Voice Coil Motor autofocus. |
| **Sensors** | Accelerometer, Gyro, ALS, Hall | **Working** | Qualcomm SSC on sDSP via FastRPC $\to$ `iio-sensor-proxy` (auto-rotation). |
| **Wi-Fi** | Qualcomm WCN6855 (Wi-Fi 6) | **Working** | Mainline `ath11k_pci` driver, high throughput 802.11ax, low latency. |
| **Bluetooth** | Qualcomm WCN6855 (BT 5.2) | **Working** | Mainline `btqca` / `hci_uart` via standard BlueZ stack. |
| **Battery / Power**| 8840 mAh + PM8150B Charger | **Working** | Accurate `power_supply` gauge, fast charging, ~0.89W idle power draw. |
| **Sleep / Wake** | Qualcomm PMIC + SPMI | **Working** | Deep suspend/resume, instant power-key wakeup (`archpad-pwrkey`). |
| **USB & DP** | USB Type-C 3.2 Gen 1 | **Working** | OTG host/peripheral modes, DisplayPort Alt Mode video output. |

---

## Repository Structure

```
archpad/
├── packages/
│   ├── linux-archpad-pipa/       # Linux kernel 7.1.x with pipa device patches (Tianma + CSOT DTBs)
│   ├── archpad-pipa-audio/       # ALSA UCM profiles, PipeWire limiter, QDSP6 period alignment
│   ├── archpad-pipa-camera/      # libcamera configuration, sensor tuning, udev permissions
│   ├── archpad-pipa-device/      # Core hardware integration, sensor gates, power key daemon (archpad-pwrkey)
│   ├── archpad-pipa-firmware/    # Signed Qualcomm DSP firmware and Wi-Fi/BT calibration blobs
│   ├── archpad-artwork/          # Official wallpapers and branding icons
│   ├── archpad-session/          # Optional touch-first Hyprland session policy
│   ├── archpad-boot/             # Boot hooks, systemd-boot generation manager, mkinitcpio config
│   ├── plasma-camera-pipa/       # KDE Camera with pipa focus and orientation patches
│   └── wvkbd-mobintl/            # Touch-friendly on-screen keyboard
├── artwork/                      # Official wallpapers, logos, and icon assets
├── tools/                        # Release assembly scripts and hardware validation diagnostics
└── ROADMAP.md                    # Detailed roadmap and technical architecture history
```

---

## Philosophy: Clean Design Over Android Hacks

1. **No Userspace Binary Shims**: We do not use `libhybris` or Android containers. Audio, cameras, sensors, and display are exposed through native Linux kernel subsystems.
2. **Desktop Environment Agnostic**: Configuration files live in `/usr/share/` and `/usr/lib/` under standard specifications (`pipewire.conf.d`, `wireplumber.conf.d`, `alsa/ucm2`, `net.hadess.SensorProxy`). You can switch between KDE Plasma, GNOME, Phosh, Sway, or Hyprland without breaking hardware support.
3. **Reproducible & Package-Managed**: Every customization is version-controlled in a clean `PKGBUILD`. Wiping and redeploying produces the identical operating system.

---

## Installation Guide (Fastboot)

### Prerequisites
* Xiaomi Pad 6 (`pipa`) with an **unlocked bootloader**.
* Host PC with `fastboot` installed (`android-tools` or `platform-tools`).
* A backup of your stock Android partitions (`boot`, `dtbo`, `userdata`).

### Flashing Prebuilt Release Images
1. Boot the tablet into Fastboot mode (Hold `Power + Volume Down`).
2. Flash the kernel and boot generation:
   ```bash
   fastboot flash boot boot.img
   ```
3. Flash the system rootfs image:
   ```bash
   fastboot flash userdata userdata.img
   ```
4. Reboot into ArchPad:
   ```bash
   fastboot reboot
   ```

---

## Building from Source

### Building Individual Packages
To build any package locally using Arch Linux's `makepkg`:
```bash
cd packages/archpad-pipa-audio
makepkg -sf
```

### Building the Kernel
The kernel package is a standard Arch split package producing both `linux-archpad-pipa` and `linux-archpad-pipa-headers`:
```bash
cd packages/linux-archpad-pipa
makepkg -sf
```

### Assembling Release Images
To build a full fastboot release image from a clean rootfs archive:
```bash
sudo tools/build-archpad-release.sh \
  --rootfs archpad-rootfs.tar.zst \
  --boot-tree /boot \
  --layout sfdisk-layout.dump \
  --output ./release
```

---

## Contributing

Contributions, bug reports, and hardware improvements are very welcome!
* **Display / DTB**: Both Tianma and CSOT display variants are supported in the device tree.
* **Camera 3A Tuning**: Improvements to `libcamera` IPA tuning files for the HI846 and OV13B10 sensors are actively encouraged.
* **Audio Optimization**: Speaker limiter settings can be inspected in `packages/archpad-pipa-audio/`.

Please submit pull requests or open issues on GitHub!

---

## Credits & Acknowledgments

* **Qualcomm Mainline Community**: For continuous upstreaming of SM8250 SoC drivers.
* **pipa-mainline Project**: For pioneering device trees and initial hardware enablement on Xiaomi Pad 6.
* **postmarketOS Community**: For valuable insights on Qualcomm sensor core (`hexagonrpcd`) and audio quirks.
* **Arch Linux ARM**: For providing the lean, fast, and up-to-date ARM64 distribution foundation.

---

## License

* Kernel patches and device tree bindings are licensed under **GPL-2.0**.
* Packaging scripts (`PKGBUILD`s) and integration tools are licensed under **GPL-2.0** / **MIT** unless specified otherwise in individual directories.
* Proprietary Qualcomm firmware binaries remain the property of their respective copyright holders.
