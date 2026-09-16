# FUTO Swipe Phase D1 Essential Performance Gate

Date: 2026-09-16

Status: **Complete — suitable to begin integration planning, with memory as an
explicit constraint.** This is D1 only; D2 remains required before release.

## Configuration

The isolated native AArch64 `benchmark_e2e` executable ran on the Xiaomi Pad 6
with the pinned universal encoder, English/QWERTY decoder, and English context
model. Configuration was one model thread, beam width 300, top four candidates,
50 warmups, and 1,000 deterministic synthetic paths of nominally 80 points.

`measure-phase-d1.py` used the benchmark's per-stage timings, `wait4` resource
usage, and `/proc/<pid>/smaps_rollup`. It introduced no service, installation,
or change to the keyboard.

## Results

| Measurement | Result |
| --- | ---: |
| Warm decode p50 | 10.272 ms |
| Warm decode p95 | 11.178 ms |
| Warm decode p99 | 11.607 ms |
| Fresh-process initialization p50 | 221.2 ms |
| Fresh-process initialization p95 | 227.7 ms |
| Maximum observed PSS | 95,787 KiB (93.54 MiB) |
| Peak RSS | 109,264 KiB (106.70 MiB) |
| CPU during active benchmark | 10.905 CPU-s / 10.936 wall-s |
| Distributable-size proxy | 20,022,108 bytes (19.09 MiB) |

The initialization runs used separate processes but warm filesystem cache. A
true cold-cache or post-reboot initialization measurement belongs to D2 and is
not claimed here.

Average active decoding consumed essentially one model thread for roughly
10.2 ms per completed gesture. It does not imply continuous 100% CPU use in a
keyboard because inference runs only when a swipe finishes.

The size proxy contains the three model files, context vocabulary, English
dictionary, QWERTY layout, and the standalone benchmark executable. The final
integrated package size will differ slightly with the production executable and
packaging metadata.

## Assessment

Latency has comfortable headroom under a 16.7 ms frame and is suitable for
interactive post-lift recognition. Initialization is short enough for session
startup or controlled lazy loading. The roughly 94 MiB PSS is the main cost;
the integration plan must specify whether models remain resident, load on first
use, or can be unloaded under memory pressure. This cost must not be described
as negligible.

D1 is sufficient to begin the separate integration architecture and planning
phase. D2 must still cover sustained decoding, leak and thermal behavior, true
cold startup, and 60/120 Hz input-sampling behavior before release acceptance.

## Integrity and artifacts

- result JSON SHA-256:
  `8e8a7884276dc221d3c458e4661b8bc92b089f7a8bca0bb1fed45b7a0e2201f8`
- result location on tablet:
  `/home/archpad/builds/futo-phase-c-20260916/phase-d1-results.json`
- benchmark exited completely;
- installed keyboard remained `archpad-keyboard 1.0.0-58`;
- `pacman -Qkk archpad-keyboard`: 23 files, 0 altered files.
