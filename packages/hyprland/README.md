# Temporary native Hyprland build

This directory is a semantically unchanged snapshot of Arch Linux's official
Hyprland `0.56.2-3` packaging recipe (two trailing spaces were normalized). It
exists only because Arch Linux ARM's repository
was temporarily inconsistent on 2026-09-09: its `hyprland 0.56.1-3` requires
`libaquamarine.so=13-64`, while the same repository offers only
`aquamarine 0.15.0-2`, which provides `libaquamarine.so=14-64`.

Do not force-install the stale binary or create a compatibility symlink. Build
this package natively in a fully updated AArch64 Arch environment and install
the resulting `hyprland-0.56.2-3-aarch64.pkg.tar.zst`. The normal repository
package may replace it once Arch Linux ARM publishes a newer release.

## Provenance

- Packaging repository: `https://gitlab.archlinux.org/archlinux/packaging/packages/hyprland.git`
- Packaging commit: `b4da40b4c27baf3032c7a5bc84426f890914d3f9`
- Commit date: `2026-09-04T08:56:46+03:00`
- Upstream source tag: `v0.56.2` (`efb5099` shown by the upstream release)
- Source archive SHA-256: `03ad3f5ef152ff44116ffd56fcf808486211ecabf4f0ba567108ee746ba5cd2e`
- Upstream `PKGBUILD` SHA-256: `45a68071b48a06e69b86dc6722e7b3017d02d20156c84a33feaabfce6a7eee8b`

The recipe is deliberately unmodified so this is a reproducible native rebuild,
not an ArchPad fork. Re-check the repository before every rebuild and remove
this temporary package source once Arch Linux ARM resolves the dependency.
