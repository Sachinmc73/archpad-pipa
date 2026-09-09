# linux-archpad-pipa

This is the source-built Arch package for the Xiaomi Pad 6 (`pipa`) kernel.
It is deliberately based on the exact kernel inputs that booted and passed the
initial hardware validation on the project's Tianma-panel tablet.

## Pinned inputs

- Upstream Linux: `7.1.4` from kernel.org
- Device patch/config source: postmarketOS pmaports commit
  `c6f27d1b653491029311e5c2bd0a25c4a654d436`
- Original pmaports package: `linux-xiaomi-pipa` `7.1.4-r1`
- Preserved fallback kernel release: `7.1.4-pipa` (`pkgrel=7`)
- Current installed and validated release: `pkgrel=9`, kernel
  `7.1.4-pipa-r9`
- The r9 source includes the front-camera fixes through patch `0025`, VDSO
  path normalization in `0026`, deterministic Qualcomm register generation in
  `0027`, and canonical debug/Rust prefix maps
- Toolchain mode: LLVM/Clang (`LLVM=1`), matching the validated build
- Display tree installed by the package:
  `qcom/sm8250-xiaomi-pipa-tianma.dtb`

Every source and local patch is covered by the `sha512sums` array in the
PKGBUILD. The files copied from pmaports retain their original bytes and were
rechecked against the pmaports APKBUILD checksums.

## Scope

The package installs the kernel image, Tianma DTB and modules. It does not yet
generate the ArchPad initramfs or boot entry directly. `archpad-boot` assembles
those files into a complete, hashed generation after pacman installs all
payload files, validates it, and only then changes the systemd-boot default.
The package release is included in `uname -r`, keeping module trees distinct
across upgrades.

The first successful Arch boot must use this source-built package. The existing
postmarketOS APK may be used as a comparison oracle, but must not be installed
into the Arch root filesystem.

## Build policy

Build this package in a clean AArch64 Arch Linux ARM environment. A native
tablet build is acceptable for development; release artifacts must additionally
be rebuilt twice from clean inputs and compared before publication.

The kernel build identity is fixed (`archpad@builder`) and its timestamp is
fixed to the Unix epoch. These values avoid embedding the builder's username,
hostname or wall-clock time in the package.

Two independent clean output trees were built on 2026-09-09. Their Image,
full and unstripped vmlinux, Tianma DTB, compat VDSO, generated Qualcomm A6xx
header, config, System.map, Module.symvers and all 585 modules were
byte-identical. The clean Image SHA-256 was
`e86f360ccc39f5b18eaf9cbb2279d948dac62edccb4909e583f8a38178c7e8f0`.
