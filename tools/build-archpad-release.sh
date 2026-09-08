#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Assemble the Xiaomi Pad 6 nested-GPT userdata image from explicit inputs.

set -euo pipefail

readonly SECTOR_SIZE=4096
readonly DISK_SIZE=114445758464
readonly ESP_OFFSET=8388608
readonly ESP_SIZE=503316480
readonly ROOT_OFFSET=511705088
readonly ROOT_SIZE=113934032896
readonly ESP_UUID='4523-4AA7'
readonly ROOT_UUID='c6e69b4d-faec-48bf-9df7-6083807d27cb'

usage() {
  cat <<'EOF'
Usage: sudo tools/build-archpad-release.sh \
  --rootfs ROOTFS.tar.zst \
  --boot-tree DIRECTORY \
  --layout sfdisk-loop0.dump \
  --output DIRECTORY \
  [--uboot-vars ubootefi.var]

The output directory must not already contain release images. The root
filesystem is created at its final 106 GiB partition size, so no undocumented
first-boot resize is required. The files are sparse, but img2simg still reads
the complete logical userdata size and may take time.
EOF
}

die() {
  printf 'build-archpad-release: %s\n' "$*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

rootfs=''
boot_tree=''
layout=''
output=''
uboot_vars=''

while (($#)); do
  case "$1" in
    --rootfs) rootfs=${2-}; shift 2 ;;
    --boot-tree) boot_tree=${2-}; shift 2 ;;
    --layout) layout=${2-}; shift 2 ;;
    --output) output=${2-}; shift 2 ;;
    --uboot-vars) uboot_vars=${2-}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ $EUID -eq 0 ]] || die 'run as root (required to preserve ownership and mount the root image)'
[[ -n $rootfs && -f $rootfs ]] || die '--rootfs must name an existing tar.zst archive'
[[ -n $boot_tree && -d $boot_tree ]] || die '--boot-tree must name an existing directory'
[[ -n $layout && -f $layout ]] || die '--layout must name an existing sfdisk dump'
[[ -n $output ]] || die '--output is required'
[[ -z $uboot_vars || -f $uboot_vars ]] || die '--uboot-vars file does not exist'

for command in awk chown dd e2fsck find grep img2simg losetup mcopy mkfs.ext4 \
  mkfs.vfat mkdir mktemp mount mountpoint mv readlink rm sfdisk sha256sum \
  sort sync tar truncate umount xargs; do
  need "$command"
done

project_root=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")/..")
output=$(readlink -m "$output")
case "$output/" in
  "$project_root"/*) ;;
  *) die "output must remain inside $project_root" ;;
esac

for required in Image initramfs-linux.img \
  dtbs/qcom/sm8250-xiaomi-pipa-tianma.dtb \
  EFI/BOOT/BOOTAA64.EFI loader/loader.conf loader/entries/archpad.conf; do
  [[ -f "$boot_tree/$required" ]] || die "boot tree is missing $required"
done

rootfs_fstab=$(tar --zstd -xOf "$rootfs" ./etc/fstab 2>/dev/null || true)
grep -Fq "UUID=$ROOT_UUID" <<<"$rootfs_fstab" || \
  die "rootfs fstab does not reference expected root UUID $ROOT_UUID"
grep -Fq "UUID=$ESP_UUID" <<<"$rootfs_fstab" || \
  die "rootfs fstab does not reference expected ESP UUID $ESP_UUID"
grep -Fq "root=UUID=$ROOT_UUID" "$boot_tree/loader/entries/archpad.conf" || \
  die 'boot entry does not reference the expected root UUID'

mkdir -p "$output"
for name in archpad-esp.img archpad-root.img archpad-userdata.img \
  archpad-userdata-sparse.img SHA256SUMS BUILD-METADATA.txt nested-gpt.dump; do
  [[ ! -e "$output/$name" ]] || die "refusing to overwrite $output/$name"
done

tmpdir=$(mktemp -d "$output/.build.XXXXXX")
mountpoint="$tmpdir/root"
loopdev=''

cleanup() {
  set +e
  if mountpoint -q "$mountpoint"; then
    umount "$mountpoint"
  fi
  if [[ -n $loopdev ]]; then
    losetup -d "$loopdev"
  fi
  rm -rf -- "$tmpdir"
}
trap cleanup EXIT INT TERM

esp="$tmpdir/archpad-esp.img"
root="$tmpdir/archpad-root.img"
raw="$tmpdir/archpad-userdata.img"
sparse="$tmpdir/archpad-userdata-sparse.img"

printf 'Creating final ESP...\n'
truncate -s "$ESP_SIZE" "$esp"
mkfs.vfat -S "$SECTOR_SIZE" -F 32 -i "${ESP_UUID/-/}" -n ARCH_BOOT "$esp" >/dev/null
mcopy -s -p -i "$esp" "$boot_tree"/* ::/
if [[ -n $uboot_vars ]]; then
  mcopy -o -p -i "$esp" "$uboot_vars" ::/ubootefi.var
fi

printf 'Creating final-size sparse ext4 root...\n'
truncate -s "$ROOT_SIZE" "$root"
mkfs.ext4 -q -F -b "$SECTOR_SIZE" -U "$ROOT_UUID" -L ARCH_ROOT "$root"
mkdir -p "$mountpoint"
loopdev=$(losetup --find --show "$root")
mount "$loopdev" "$mountpoint"
tar --zstd --numeric-owner -xpf "$rootfs" -C "$mountpoint"
sync
umount "$mountpoint"
losetup -d "$loopdev"
loopdev=''
e2fsck -f -y "$root" >/dev/null

printf 'Creating nested GPT userdata image...\n'
truncate -s "$DISK_SIZE" "$raw"
sfdisk "$raw" < "$layout" >/dev/null
sfdisk --dump "$raw" > "$tmpdir/nested-gpt.dump"

actual_sector=$(sfdisk --json "$raw" | awk -F: '/"sectorsize"/ {gsub(/[^0-9]/, "", $2); print $2; exit}')
[[ $actual_sector == "$SECTOR_SIZE" ]] || die "nested GPT sector size is $actual_sector, expected $SECTOR_SIZE"
grep -Eq 'start=[[:space:]]*2048, size=[[:space:]]*122880, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B' \
  "$tmpdir/nested-gpt.dump" || die 'nested GPT ESP geometry or type is incorrect'
grep -Eq 'start=[[:space:]]*124928, size=[[:space:]]*27815926, type=B921B045-1DF0-41C3-AF44-4C6F280D3FAE' \
  "$tmpdir/nested-gpt.dump" || die 'nested GPT root geometry or type is incorrect'

dd if="$esp" of="$raw" bs=4M seek=$((ESP_OFFSET / 4194304)) \
  conv=notrunc,sparse status=progress
dd if="$root" of="$raw" bs=4M seek=$((ROOT_OFFSET / 4194304)) \
  conv=notrunc,sparse status=progress

printf 'Converting userdata to Android sparse format...\n'
img2simg "$raw" "$sparse" "$SECTOR_SIZE"

{
  printf 'format=archpad-nested-gpt-v1\n'
  printf 'sector_size=%s\n' "$SECTOR_SIZE"
  printf 'disk_size=%s\n' "$DISK_SIZE"
  printf 'esp_offset=%s\n' "$ESP_OFFSET"
  printf 'esp_size=%s\n' "$ESP_SIZE"
  printf 'esp_uuid=%s\n' "$ESP_UUID"
  printf 'root_offset=%s\n' "$ROOT_OFFSET"
  printf 'root_size=%s\n' "$ROOT_SIZE"
  printf 'root_uuid=%s\n' "$ROOT_UUID"
  printf 'rootfs_sha256=%s\n' "$(sha256sum "$rootfs" | awk '{print $1}')"
  printf 'boot_tree_sha256=%s\n' "$({ find "$boot_tree" -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum; } | sha256sum | awk '{print $1}')"
  printf 'layout_sha256=%s\n' "$(sha256sum "$layout" | awk '{print $1}')"
  if [[ -n $uboot_vars ]]; then
    printf 'uboot_vars_sha256=%s\n' "$(sha256sum "$uboot_vars" | awk '{print $1}')"
  else
    printf 'uboot_vars_sha256=absent\n'
  fi
} > "$tmpdir/BUILD-METADATA.txt"

(cd "$tmpdir" && sha256sum archpad-esp.img archpad-root.img \
  archpad-userdata.img archpad-userdata-sparse.img nested-gpt.dump \
  BUILD-METADATA.txt > SHA256SUMS)

mv "$esp" "$root" "$raw" "$sparse" "$tmpdir/nested-gpt.dump" \
  "$tmpdir/BUILD-METADATA.txt" "$tmpdir/SHA256SUMS" "$output/"

owner_uid=${SUDO_UID:-0}
owner_gid=${SUDO_GID:-0}
chown "$owner_uid:$owner_gid" "$output"/{archpad-esp.img,archpad-root.img,archpad-userdata.img,archpad-userdata-sparse.img,nested-gpt.dump,BUILD-METADATA.txt,SHA256SUMS}

trap - EXIT INT TERM
rm -rf -- "$tmpdir"
printf 'Release assembled and hashed in %s\n' "$output"
