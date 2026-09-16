# FUTO Swipe Phase A Qualification Record

Date: 2026-09-16

Status: **Complete — proceed to an isolated Phase B build with the conditions
below.** No swipe code, model, service, or package was added to the installed
ArchPad keyboard during this phase.

## Scope and conclusion

The standalone FUTO swipe library is a viable candidate for ArchPad. Its C++
API is suitable for receiving normalized key geometry and touch traces and
returning ranked candidates. The target tablet has an adequate native ARM64
toolchain, and the exact PyTorch/torchgen wheel required by the upstream build
exists for CPython 3.14 on Linux AArch64.

Do not integrate the Android keyboard application. Use only the standalone
swipe library and independently licensed assets recorded here.

Adoption is conditional because the upstream build is not reproducible as-is
and two native test executables report false success. Phase B must build in a
separate qualification package with pinned sources, no build-time network
access, tracked patches, and corrected failure propagation.

## Immutable upstream record

### Engine source

- Repository: <https://gitlab.futo.org/keyboard/swipe-library>
- Commit: `1b13f2c85d6b347f6ea3fbc4b3aaf01fce42429a`
- Commit date: `2026-06-18T04:42:35+03:00`
- Commit subject: `Add missing end_search call`
- License file SHA-256:
  `0d3c70b63f0fb7e937a993484bcd6667116dcc9b02b642d91ff8ce182aabac8e`
- Conservative license classification: `GPL-3.0-only`. The hosting page says
  GPL 3.0 or later, but the checked-out source contains the GPLv3 text without
  a per-file or repository-wide “or later” grant. Do not label the pinned
  source `GPL-3.0-or-later` unless upstream clarifies it.
- The CMake source contains a small Stack Overflow-derived function identified
  by upstream as CC BY-SA 3.0. Preserve its attribution in source packaging.

The engine API is explicitly non-thread-safe. ArchPad must serialize engine
initialization, recognition, and mode changes. Input coordinates are normalized
to `0.0..1.0`, timestamps are elapsed milliseconds, and layout key centers must
match the visible keyboard geometry. Duplicate letters are not supported in a
single engine layout.

### Model assets

- Repository: <https://huggingface.co/futo-org/futo-swipe>
- Commit: `18328c3042b066952c0936b3771d492fe2ec289a`
- Commit date: `2026-06-26T10:00:00Z`
- License: FUTO Model Weights License 1.0
- License file SHA-256:
  `ef6b4f6437efa0a2929de351b10c16a8c870b32e1c23054ac76af61531f5db21`

Pinned files:

| Role | File | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| Universal encoder | `honorable_sturgeon/model_fp32.pte` | 2,649,856 | `725242bab5d14345e96ff214e8de2bfbc1f962c232d320df9c24cb82ffd1fbaf` |
| English/QWERTY decoder | `magic_macaw/model_fp32.pte` | 1,247,468 | `01eaf16ac4bc0f1ed0698c240807f0e95e6d427bcf6de04983ffc50736744d85` |
| English context model | `hungry_jellyfish/context_lm.pte` | 6,247,616 | `74d29f56a513c0c60abcd43df3b16a6b68925cdf4e97e51b094a5275ec2810d7` |
| Context vocabulary | `hungry_jellyfish/vocab.txt` | 284,965 | `a7db66376783b5a23ee3d4a2aaa8f2499fd9b35f975e92bcb248664c2cf6ebd1` |

The three model binaries total 10,144,940 bytes (about 9.68 MiB). The model
license permits use and distribution but requires a visible end-user notice
that the product is powered by “FUTO Swipe” technology. The complete license
must accompany distributed weights. Package unmodified weights separately
from executable code so installation, attribution, updates, and removal remain
explicit.

### Dictionary chosen for qualification

The swipe repository does not ship the required English trie dictionary. Do
not copy it from the Source First-licensed FUTO Android application. Use the
official AOSP LatinIME English source dictionary instead:

- Repository: <https://android.googlesource.com/platform/packages/inputmethods/LatinIME>
- Commit: `127336e9f29d69607eab55982324b210279ae8c5`
- File: `dictionaries/en_wordlist.combined.gz`
- Compressed SHA-256:
  `07682388185c285d307e341d1733331af8699f735b4137e9f22571017fab69d2`
- Size: 914,050 compressed bytes; 7,270,298 uncompressed bytes; 165,544
  word records
- License/NOTICE: Apache-2.0; NOTICE SHA-256
  `d04394c729fc9fda050d5733d8ee11663fb54fe54d94532de968cf85c1cc42fb`

## Runtime dependency graph

The executable path is CPU-only:

```text
FUTO swipe-library (GPL-3.0-only, conservative)
  -> ExecuTorch 1.2.0a0 / 0b0e2c5... (BSD-3-Clause)
     -> XNNPACK / 3131afe... (BSD-3-Clause)
        -> KleidiAI / 45bf060... (Apache-2.0 and BSD-3-Clause files)
     -> cpuinfo / 8a92100... (BSD-2-Clause; bundled clog BSD-2-Clause)
     -> pthreadpool / c2ba5c5... (BSD-2-Clause)
     -> FP16 / 4dfe081... (MIT)
     -> FXdiv / b408327... (MIT)
     -> FlatBuffers / 595bf00... (Apache-2.0)
     -> flatcc / 896db54... (Apache-2.0 plus documented MIT/Apache components)
     -> gflags / a738fdf... (BSD-3-Clause)
     -> nlohmann/json / ac0133e... (MIT)
```

ExecuTorch commit:
`0b0e2c5cdd67c8b4396a46ea1d1aa72ffb0128d7`, reporting version
`1.2.0a0`. XNNPACK downloads KleidiAI commit
`45bf06030727ce049793ce6749e943cc2ea896fe` using archive SHA-256
`919683ceeedd6dd9db26c341eef448f9096616dfc4e9270e0209e481921e78e4`.
Phase B must supply that archive as a package source instead of allowing CMake
network access.

## Reproducibility findings

The upstream `make host` recipe is not acceptable unchanged:

1. It upgrades `pip`, `cmake`, `pyyaml`, and `typing_extensions` without
   versions or hashes.
2. It downloads a PyTorch 2.10.0 wheel during the build and extracts only
   `torchgen`.
3. XNNPACK downloads KleidiAI at CMake configure time.
4. It applies one tracked ExecuTorch patch but also performs an untracked
   `sed -i` mutation inside pinned flatcc source.
5. Model files, the English dictionary, and public evaluation traces are not
   fetched by a complete pinned build recipe.

Phase B must replace this with normal Arch package sources and checksums:

- use system CMake, Python, PyYAML, and typing-extensions where compatible;
- use the exact hash-pinned PyTorch 2.10.0 CPU wheel only as a build source for
  `torchgen`;
- provide every required subproject and KleidiAI as a pinned source before
  configuration, with networking unavailable during `build()`;
- replace the flatcc `sed` operation with a reviewed, checksum-tracked patch;
- keep all patches in the qualification package and never alter an installed
  upstream package file.

The target Xiaomi Pad 6 reports AArch64, CMake 4.4.3, GCC 16.1.1, Python
3.14.7, and more than 85 GiB free persistent storage. The official PyTorch CPU
index contains a `torch-2.10.0+cpu-cp314-cp314-manylinux_2_28_aarch64` wheel,
so the torchgen build input exists for the target ABI/Python combination.

The real-swipe corpus for later Phase C validation is the official MIT-licensed
`futo-org/swipe.futo.org` dataset. Pin commit
`eb7bdec57eaca9946bf114e21b17c2cbd351d9e9`; do not download its multi-gigabyte
training split for the build. Phase C should fetch only a checksum-pinned test
subset or deterministically derive a bounded test fixture from that revision.

## Truthful-test audit

An isolated host build without ExecuTorch completed, but its output exposed a
serious upstream test-runner defect.

`test_beam_search` and `test_beam_search_pruning` execute tests from static
constructors. Their `ASSERT` macro prints a failure and returns from the test
function, after which the constructor unconditionally increments
`tests_passed`. On the pinned source, `test_beam_search` printed three real
assertion failures but concluded `33/33 tests passed` and exited with status 0:

- `beam_search_identity_logprobs`
- `beam_search_freq_bonus`
- `resample_60hz_120hz_input`

The separate `test_vocab_hash` runner propagates failure correctly and passed
10/10 tests. `test_engine` also has a correct throwing assertion mechanism.
`test_lm_vocab` has an additional argument-count bug: it checks `argc < 3` but
then reads `argv[3]`; it must require at least four arguments.

Phase B must patch the two false-positive runners to throw/catch a test failure,
fix the LM test's argument guard, and run the tests again. The three surfaced
core failures must be diagnosed rather than suppressing or weakening their
expected values.

## Phase B checkpoint

The next phase is authorized only as an isolated full-engine build. It should:

1. create a distinct qualification package/tool, never link into or modify
   `archpad-keyboard`;
2. build ExecuTorch + XNNPACK natively for Linux AArch64 from the exact pins;
3. stage the three models, context vocabulary, AOSP dictionary, and layouts as
   separate checked assets;
4. provide a CLI that accepts normalized swipe points and prints ranked
   candidates plus timing;
5. run with no runtime network access, service, desktop entry, autostart, or
   D-Bus name;
6. preserve the installed r58 keyboard unchanged.

Do not start visible swipe handling, trail rendering, automatic insertion, or
candidate UI until the isolated engine passes Phases B through D and receives
a separate integration approval.
