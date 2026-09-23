#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Fastboot restoration pipeline for ArchPad (Xiaomi Pad 6 / pipa).

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

UBOOT_IMG="$PROJECT_ROOT/artifacts/private/validation-2026-09-05/u-boot-xiaomi-pipa.img"
USERDATA_IMG="$PROJECT_ROOT/artifacts/private/archpad-release/archpad-userdata-sparse.img"

echo "=== ArchPad Fastboot Restoration Tool ==="

# Check fastboot command
command -v fastboot >/dev/null 2>&1 || { echo "[!] Error: fastboot command not found." >&2; exit 1; }

# Check images
[[ -f "$UBOOT_IMG" ]] || { echo "[!] Error: U-Boot image missing: $UBOOT_IMG" >&2; exit 1; }
[[ -f "$USERDATA_IMG" ]] || { echo "[!] Error: ArchPad sparse userdata missing: $USERDATA_IMG" >&2; exit 1; }

echo "[*] Waiting for device in Fastboot mode..."
device=$(fastboot devices | awk '{print $1}' | head -n1)
if [[ -z "$device" ]]; then
    echo "[!] No fastboot device detected. Please put the tablet in Fastboot mode (hold Power + Volume Down) and connect via USB." >&2
    exit 1
fi
echo "[+] Detected device: $device"

echo "[*] Flashing Mainline U-Boot to boot_b..."
fastboot flash boot_b "$UBOOT_IMG"

echo "[*] Setting active slot to B..."
fastboot --set-active=b

echo "[*] Flashing ArchPad clean nested-GPT userdata (~106 GiB virtual, sparse)..."
fastboot flash userdata "$USERDATA_IMG"

echo "[*] Rebooting device into ArchPad..."
fastboot reboot

echo "[✓] Restoration complete! The device is now booting into ArchPad."
