# FUTO Swipe Phase B Build Record

Date: 2026-09-16

Status: **Complete — isolated full-engine build and smoke test passed.** No
FUTO component was linked into, installed beside, or started by
`archpad-keyboard`.

## Deliverable

The qualification source is under
`packages/archpad-futo-swipe-qualification/`. It contains:

- a CPU-only CLI accepting normalized JSON swipe points;
- an offline build driver with immutable revision and asset checks;
- tracked patches for truthful test propagation, the beam-search default
  alphabet defect, stale scoring/resampling tests, the flatcc array bound,
  ExecuTorch XNNPACK exceptions, and the qualification target;
- no daemon, desktop entry, autostart unit, D-Bus ownership, or keyboard UI
  integration.

The native tablet build is located only in the uninstalled build workspace:

`/home/archpad/builds/futo-phase-b-20260916/`

## Native build result

- Architecture: Linux AArch64 on Xiaomi Pad 6
- Compiler: GCC 16.1.1
- CMake: 4.4.3
- Python code generation: 3.14.7
- ExecuTorch: pinned 1.2.0 / `0b0e2c5...`
- Backend: CPU XNNPACK with pinned KleidiAI
- CLI size: 2,411,440 bytes, unstripped PIE
- CLI SHA-256:
  `46ad02ed36de49f745299aa9e22d1148e68ae9fe7cac891482f950707df1ca42`
- Dynamic dependencies: only glibc, libstdc++, libgcc_s, libm, and the ELF
  loader; no network client library is linked.
- Complete build directory: 118 MiB. The 1.3 GiB source workspace includes
  Git history and dependency sources and is not an installed-size estimate.

All model and dictionary hashes matched the Phase A manifest before build.
Pinned build-wheel hashes were:

| Input | SHA-256 |
| --- | --- |
| PyTorch 2.10.0 CPU CPython 3.14 AArch64 wheel | `a28fdbcfa2fbacffec81300f24dd1bed2b0ccfdbed107a823cff12bc1db070f6` |
| PyYAML 6.0.3 CPython 3.14 AArch64 wheel | `501a031947e3a9025ed4405a168e6ef5ae3126c59f90ce0cd6f2bfc477be31b7` |
| typing-extensions 4.15.0 wheel | `f0fa19c6845758ab08074a0cfa8b7aecb71c999ca73d62883bc25cc018c4e548` |

Only `torchgen` was extracted from the PyTorch wheel. All Python inputs lived
inside the qualification build tree; no Python or pacman package was installed
or modified.

## Corrected test result

The Phase A false-success behavior was corrected before the neural build.
Results after diagnosing the three surfaced assertions:

- beam search, trie, layout, vocabulary parsing, and resampling: 33/33 pass;
- pruning and transition-C: 4/4 pass;
- vocabulary hash: 10/10 pass.

Root causes were:

1. `TrieBeamSearch` documented `num_chars=0` as deriving the alphabet from the
   trie, but never performed that initialization. It now resolves the alphabet
   on first decode.
2. The frequency-bonus test used positional aggregate initialization after the
   scoring structure evolved, so it set `gamma` rather than `lambda`. It now
   assigns named fields explicitly.
3. The 60 Hz test retained the former `ceil` sample count although the source
   intentionally switched to training-parity `round` behavior. Its expectation
   now matches the documented implementation.

Assertions now throw into the existing test-runner catch path instead of
returning into an unconditional pass increment. The LM vocabulary executable
also correctly requires all three path arguments.

## Full-model smoke result

One normalized synthetic trace shaped like `hello`, with context `say`, was
passed through the universal encoder, English/QWERTY decoder, beam search, and
English context model. The CLI confirmed both optional models were loaded and
returned:

1. `help`
2. `hello`
3. `hell`
4. `helps`

Reported warm timing for that single run was:

| Stage | Microseconds |
| --- | ---: |
| Resample | 1.927 |
| Encoder | 6,165.466 |
| Decoder | 2,052.430 |
| Beam search | 1,898.425 |
| Context LM | 3,226.400 |
| Total | 13,348.866 |

This proves the complete pinned model pipeline executes natively and produces
ranked candidates. It is not an accuracy result or performance distribution;
those belong to Phases C and D.

## Isolation verification

- Installed keyboard remained `archpad-keyboard 1.0.0-58`.
- `pacman -Qkk archpad-keyboard` reported 23 files and 0 altered files.
- The qualification process exited after the CLI run; it has no persistent
  service or idle process.
- No current keyboard process was restarted.

## Next checkpoint

Stop here. Phase C will add boundary and lifecycle tests and run the pinned
public FUTO trace set. Phase D will measure distributions, RSS/PSS, sustained
load, and thermals. Neither phase may add visible keyboard integration without
the later explicit integration approval.
