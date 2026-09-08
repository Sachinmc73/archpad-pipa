# linux-archpad-pipa-fallback

This transition package preserves the tested `7.1.4-pipa` r7 kernel as a
complete, pacman-owned rollback source. Place the ignored, verified artifact
`linux-archpad-pipa-7.1.4-7-aarch64.pkg.tar.xz` beside the PKGBUILD before
building. Its SHA-256 is
`971815f161448ac192182a4e50407b08c9812dd2af7b21ed4bbbf89a8960bf9b`.

The payload is staged below `/usr/lib/archpad/kernel-generations/` so it does
not conflict with the currently installed kernel package. `archpad-boot`
creates the boot entry and, after a future active-kernel upgrade removes the
old module directory, supplies a version-correct symlink to these retained
modules.
