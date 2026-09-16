# FUTO Swipe Phase C Validation Record

Date: 2026-09-16

Status: **Complete — automated engine validation passed with one recorded
accuracy divergence.** Phase D has not started. Nothing was installed into or
linked with `archpad-keyboard`.

## Scope and isolation

Phase C used only the uninstalled tablet workspaces:

- source/build: `/home/archpad/builds/futo-phase-b-20260916/`
- public data/results: `/home/archpad/builds/futo-phase-c-20260916/`

The installed keyboard remained `archpad-keyboard 1.0.0-58` with 23 files and
zero altered package-owned files. No keyboard process was restarted, and no
qualification process remained after the tests.

## Correctness fixes and added coverage

Three tracked patches were added after Phase B:

1. `0005-contextlm-metadata-contract.patch` teaches the metadata contract test
   about the official `contextlm` model class and makes the runtime parser
   reject a wrong kind or empty codename. The previous test rejected
   `hungry_jellyfish/metadata.json` even though the runtime supported it.
2. `0006-bounded-jsonl-evaluation.patch` adds `--limit` to the existing upstream
   JSONL evaluator. The limit counts evaluated non-single-letter swipes, which
   reproduces FUTO's stated bounded benchmark without copying or rewriting the
   dataset.
3. `0007-serial-dictionary-swap-test.patch` swaps from the complete dictionary to
   a one-word dictionary and back in one engine instance, verifying candidate
   restriction and exact restoration.

`validate-phase-c.py` is the tracked CLI-level boundary and process-lifecycle
validator. The source patch series was applied from a fresh detached worktree
at `1b13f2c85d6b347f6ea3fbc4b3aaf01fce42429a`, and `git diff --check` passed.

## Test results

| Test executable/check | Result |
| --- | ---: |
| Beam search, trie, layouts, vocabulary parsing, resampling | 33/33 |
| Beam pruning and transition-C | 4/4 |
| Vocabulary hash | 10/10 |
| Model metadata sidecars | 3/3 |
| Full engine integration | 21/21 |

The engine suite covers negative initialization, encoder-only inference,
encoder/decoder/context-model combinations, context-dependent reranking,
scoring metadata and overrides, six shipping layouts, layout round-trip,
decoder load/unload round-trip, mismatch rejection, and the new serial
dictionary round-trip. Calls were strictly serial because the upstream engine
declares itself non-thread-safe.

Boundary and lifecycle results:

- rejected malformed JSON, a missing points array, empty and one-point traces,
  missing coordinates, non-finite values, coordinates outside `0..1`, and
  decreasing timestamps;
- accepted and decoded a valid two-point trace;
- accepted and decoded a valid 10,000-point trace;
- completed five independent model initialization/decode/process-exit cycles;
- returned the same ranked words in every lifecycle cycle.

## Official public-trace accuracy

Dataset source: `futo-org/swipe.futo.org` on Hugging Face, MIT licensed.

- pinned revision: `eb7bdec57eaca9946bf114e21b17c2cbd351d9e9`
- test split size: 269,612,671 bytes
- test split SHA-256:
  `d4e42e34ced1cae925a5ec94672bdaf48b4532598a1e39d72884f9c7b588721e`
- selection: first 20,000 evaluated non-single-letter swipes
- engine: universal encoder + English/QWERTY decoder + English context model
- beam width: 300
- candidates: 4
- model threads: 1
- scoring: pinned model metadata defaults, with no overrides or tuning

Result:

| Metric | Correct | Accuracy | Miss rate |
| --- | ---: | ---: | ---: |
| Top-1 | 18,419 / 20,000 | 92.095% | 7.905% |
| Top-4 | 19,165 / 20,000 | 95.825% | 4.175% |

FUTO publishes 7.38% top-1 and 4.19% top-4 miss rates for its first 20,000
non-single-letter public-test swipes. This build is 0.525 percentage points
worse at top-1 and 0.015 points better at top-4. The near-identical top-4 result
supports dataset/configuration parity, but the top-1 difference is retained as
a real divergence. No score was adjusted to conceal it.

The complete evaluator output SHA-256 is
`8ca4f844c605efcc08d8fa020fb018131b956a626ba20d718f1e0bcf829e34d1`.
Its stderr SHA-256 is
`d8079da23d85f58256a15c4cfa06843c18eefa48e82458f76c2928a6180bc53d`.

The evaluator also printed average stage timings, but those are incidental to
the accuracy run and are not accepted as Phase D performance measurements.

## Next checkpoint

Stop here. Phase D still needs cold-load time, warm p50/p95 latency, RSS/PSS,
CPU, installed-size projection, 60/120 Hz sampling checks, sustained stability,
thermal behavior, clean exit, and package-integrity verification. Visible
keyboard integration remains a later separately approved phase.
