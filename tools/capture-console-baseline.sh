#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Emit a sanitized, read-only manifest of a running ArchPad console system.

set -euo pipefail
export LC_ALL=C

section() {
  printf '\n=== %s ===\n' "$1"
}

section IDENTITY
date -Ins
uname -a
cat /etc/os-release
printf 'machine-id-sha256: '
sha256sum /etc/machine-id | awk '{print $1}'

section BOOT
cat /proc/cmdline
findmnt -no SOURCE,FSTYPE,OPTIONS /
findmnt -no SOURCE,FSTYPE,OPTIONS /boot
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINTS
find /boot -xdev -type f -exec sha256sum {} + | LC_ALL=C sort -k2

section PACKAGES
pacman -Q | LC_ALL=C sort

section CUSTOM_PACKAGES
pacman -Qm | LC_ALL=C sort

section REPOSITORIES
pacman-conf --repo-list

section SYSTEMD
systemctl get-default
systemctl --failed --no-pager
systemctl is-enabled sshd systemd-networkd systemd-resolved systemd-timesyncd \
  iwd bluetooth archpad-audio-reprobe.service 2>&1 || true

section TIME
timedatectl

section RESOURCES
free -h
df -h / /boot
swapon --show

section HARDWARE
cat /proc/bus/input/devices
ip -brief link
for supply in /sys/class/power_supply/*; do
  printf '%s\n' "$supply"
  grep -H . "$supply"/{type,status,capacity,voltage_now,current_now} 2>/dev/null || true
done
cam -l 2>&1 || true
vulkaninfo --summary 2>&1 || true

section TRACKED_CONFIGURATION_HASHES
for path in \
  /etc/fstab \
  /etc/hostname \
  /etc/issue \
  /etc/iwd/main.conf \
  /etc/locale.conf \
  /etc/mkinitcpio.conf \
  /etc/mkinitcpio.conf.d/archpad.conf \
  /etc/pacman.conf \
  /etc/systemd/zram-generator.conf \
  /etc/vconsole.conf \
  /boot/loader/loader.conf \
  /boot/loader/entries/archpad.conf; do
  if [[ -f $path ]]; then
    sha256sum "$path"
  else
    printf 'MISSING  %s\n' "$path"
  fi
done

section CUSTOM_PACKAGE_INTEGRITY
pacman -Qkk linux-archpad-pipa archpad-pipa-firmware archpad-pipa-device \
  archpad-pipa-audio archpad-pipa-camera archpad-boot 2>&1 || true

section KERNEL_ERROR_SUMMARY
printf 'dsi_pll_lock_failures='
journalctl -b -k --no-pager | grep -c 'DSI PLL(0) lock failed' || true
printf 'awinic_format_messages='
journalctl -b -k --no-pager | grep -c 'aw88261.*fmt =' || true
printf 'awinic_failure_messages='
journalctl -b -k --no-pager | grep -c 'aw88261.*\(fail\|error\)' || true
printf 'failed_driver_probes='
journalctl -b -k --no-pager | grep -c 'probe with driver.*failed' || true

section REDACTION_NOTICE
printf '%s\n' 'Password hashes, SSH keys, authorized keys, Wi-Fi credentials and journal contents are intentionally excluded.'
