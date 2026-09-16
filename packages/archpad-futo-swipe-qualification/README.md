# ArchPad FUTO Swipe qualification tool

This directory builds the pinned FUTO Swipe engine as an isolated, CPU-only
command-line tool. It is deliberately not part of `archpad-keyboard` and
installs no daemon, desktop file, autostart unit, or D-Bus service.

The immutable source, model, dictionary, dependency, and license record is in
`../../artifacts/manifests/futo-swipe-phase-a-2026-09-16.md`.

## Input and output

`archpad-futo-swipe-qualify` reads one JSON object from `--trace FILE`, or from
standard input when `--trace -` is used:

```json
{
  "points": [
    {"x": 0.10, "y": 0.25, "t": 0.0},
    {"x": 0.20, "y": 0.25, "t": 8.0}
  ],
  "context": ["previous", "words"]
}
```

Coordinates must be finite and normalized to `0.0..1.0`. Timestamps are
finite, non-negative elapsed milliseconds in monotonically non-decreasing
order. Output is JSON containing ranked candidates and the engine's per-stage
timing counters.

The default asset root is `/usr/share/archpad-futo-swipe-qualification` and
can be overridden with `--assets DIR`. The tool performs no network access.

## Build boundary

`build-offline.sh` accepts an already hydrated source tree with the tracked
patches applied and pinned wheel contents extracted under `.python-build`. It
verifies the Git revisions and asset hashes, configures XNNPACK with a local
KleidiAI checkout, and then invokes CMake. Network access is neither requested
nor needed by the build stage.

The Phase C validation entry point is `validate-phase-c.py`. It exercises
invalid and boundary traces plus repeated full-process model lifecycle runs.
The tracked patch series also corrects context-model metadata validation, adds
a bounded public-JSONL evaluator, and covers serial dictionary replacement.

This remains a qualification-only tool. It does not collect touch input from
the keyboard, insert text, render a swipe trail, or install any runtime
component.
