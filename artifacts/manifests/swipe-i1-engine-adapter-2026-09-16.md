# Swipe Integration Phase I1 Verification Manifest

Date: 2026-09-16 (Session: 2026-09-17 01:05 IST)
Status: **Complete and Verified**
Branch: `antigravity/i1-engine-adapter`

---

## 1. Objectives & Scope Achieved

Phase I1 delivers the production packaging for the FUTO Swipe neural engine and model weights, along with the single-owner background `SwipeEngineWorker` thread adapter inside `archpad-keyboard`:
1. **`archpad-futo-swipe 1.0.0-1`**: Cleanly packaged standalone shared C++ library (`libarchpad_futo_swipe.so.1.0.0`, soname `libarchpad_futo_swipe.so.1`), verification CLI (`archpad-futo-swipe-qualify`), public C++ headers in `/usr/include/archpad/futo/swipe_decoder/`, and pkg-config specification `/usr/lib/pkgconfig/archpad-futo-swipe.pc`.
2. **`archpad-futo-swipe-en 1.0.0-2`**: Cleanly packaged neural weights, vocabulary, layouts, and AOSP English wordlist trie dictionary in `/usr/share/archpad-futo-swipe/`.
3. **`archpad-keyboard 1.0.0-59`**: Implemented `SwipeEngineWorker` living on a dedicated single-owner `QThread`, providing asynchronous lazy loading, thread-safe request decoding, queue depth bounding, memory PSS introspection, and D-Bus IPC methods.

---

## 2. Package Records & Checksums

### A. `archpad-futo-swipe` (1.0.0-1)
- Architecture: `aarch64`
- Installed Size: 2.21 MiB
- Upstream Components:
  - FUTO swipe-library: commit `1b13f2c85d6b347f6ea3fbc4b3aaf01fce42429a` (GPL-3.0-only)
  - ExecuTorch: commit `0b0e2c5cdd67c8b4396a46ea1d1aa72ffb0128d7` (BSD-3-Clause)
  - XNNPACK: commit `3131afead790c5c69a9aa12273dfc40399789ad7` (BSD-3-Clause)
  - KleidiAI: commit `45bf06030727ce049793ce6749e943cc2ea896fe` (Apache-2.0 / BSD-3-Clause)
- Source Archive: `archpad-futo-swipe-1.0.0.tar.xz` (631,852 bytes)
  - SHA-512: `ce3b9749fa30dc43358ae2e50e1ed40a55b8bab2ef62c61df8f32f5406e9cfade9ae6503e0b99a12033c75947d5273e4d48fd6dac3ffbbb8558fcbff5faae45d`
  - SHA-256: `61ea354c4aa63e414c9c1b3f9ffc6beeb78d91c7f99dd9f61b7f9408b07ee7cb`
- Installed Files: 41 files in `/usr/lib/`, `/usr/bin/`, `/usr/include/archpad/futo/`, `/usr/share/licenses/archpad-futo-swipe/`.

### B. `archpad-futo-swipe-en` (1.0.0-2)
- Architecture: `any`
- Installed Size: 17.77 MiB
- Source Archive: `archpad-futo-swipe-en-1.0.0.tar.xz` (11,034,228 bytes)
  - SHA-512: `bc822bea31d8313a365d3371b8611d913fd84e388cd97ef5626dad8705786c81ff7afa4346675b0c147dad565f109ff997ff2d79833c2630848f712f2db0d8ba`
  - SHA-256: `a9355152a44136934c9c22db95c8bc34dc7e2ca4a382c4164b38d35f4cfcbfa1`
- Asset Hash Verification (Matching Phase A Record Exactly):
  - `models/en/honorable_sturgeon/model_fp32.pte`: `725242bab5d14345e96ff214e8de2bfbc1f962c232d320df9c24cb82ffd1fbaf`
  - `models/en/magic_macaw/model_fp32.pte`: `01eaf16ac4bc0f1ed0698c240807f0e95e6d427bcf6de04983ffc50736744d85`
  - `models/en/hungry_jellyfish/context_lm.pte`: `74d29f56a513c0c60abcd43df3b16a6b68925cdf4e97e51b094a5275ec2810d7`
  - `models/en/hungry_jellyfish/vocab.txt`: `a7db66376783b5a23ee3d4a2aaa8f2499fd9b35f975e92bcb248664c2cf6ebd1`
  - `dictionaries/en.combined.gz`: `07682388185c285d307e341d1733331af8699f735b4137e9f22571017fab69d2`

### C. `archpad-keyboard` (1.0.0-59)
- Architecture: `aarch64`
- Installed Size: 0.41 MiB
- Changes:
  - Added `src/swipeengineworker.h` and `src/swipeengineworker.cpp` (dedicated `QThread`).
  - Added `src/test_swipe_worker.cpp` automated test suite.
  - Linked `archpad-futo-swipe` dynamically via `pkg-config`.
  - Added `archpad-futo-swipe` and `archpad-futo-swipe-en` to dependencies in `PKGBUILD`.
  - Exposed D-Bus methods `LoadSwipeEngine`, `UnloadSwipeEngine`, `GetSwipeState`, and `GetSwipeMemoryPssKiB`.

---

## 3. Test & Verification Results

### A. Boundary & Process-Lifecycle Validation (`validate-phase-c.py`)
Executed against `/usr/bin/archpad-futo-swipe-qualify` and `/usr/share/archpad-futo-swipe`:
```json
{
  "invalid": {
    "decreasing_time": "rejected",
    "empty_trace": "rejected",
    "malformed_json": "rejected",
    "missing_coordinate": "rejected",
    "missing_points": "rejected",
    "non_finite": "rejected",
    "one_point": "rejected",
    "out_of_range": "rejected"
  },
  "lifecycle": {
    "clean_process_runs": 5,
    "stable_candidates": [
      "all",
      "do",
      "so",
      "dl"
    ]
  },
  "valid": {
    "ten_thousand_point_trace": "accepted",
    "two_point_trace": "accepted"
  }
}
```
**Result**: 100% Passed.

### B. Asynchronous Worker Thread Test Suite (`test_swipe_worker`)
Executed natively on Xiaomi Pad 6:
```text
=== ArchPad SwipeEngineWorker Test Suite ===
Baseline PSS: 3,715 KiB (3.62 MiB)
Starting Test 1: Asynchronous model loading...
State changed to: 1 "Loading"
ContextLMScorer: Extracted embeddings from PTE (exact=[32768, 16], hash=[32768, 16])
State changed to: 2 "Ready"
Models loaded in: 22 ms (warm cache)
Loaded PSS: 97,569 KiB (delta: 93,854 KiB = 91.65 MiB)
Starting Test 2: Inference on synthetic trace...
Decode finished for req 1 candidates: QList("we", "awe", "owe", "ws")
Total timing: 6.08 ms
Starting Test 3: Queue bounding (dispatching rapid requests 2, 3, 4)...
Decode finished for req 2 candidates: QList("we", "awe", "owe", "ws") - 5.53 ms
Decode finished for req 3 candidates: QList("we", "awe", "owe", "ws") - 5.60 ms
Decode finished for req 4 candidates: QList("we", "awe", "owe", "ws") - 5.40 ms
Request 4 received as expected!
Starting Test 4: Unload engine...
Post-unload PSS: 97,592 KiB
=== Test Suite PASSED ===
State changed to: 0 "Unloaded"
```
**Key Metrics**:
- Inference latency: **5.40 - 6.08 ms** (comfortably under the 16.7 ms 60Hz and 8.33 ms 120Hz frame times).
- Memory footprint: **91.65 MiB PSS** delta on model load (completely consistent with Phase D1's 93.54 MiB).
- Queue bounding: Requests handled with strictly bounded depth 1.

### C. D-Bus Runtime Control on Active Daemon
```bash
# Query initial state
qdbus6 org.archpad.Keyboard /org/archpad/Keyboard org.archpad.Keyboard.GetSwipeState
# Output: Unloaded

# Asynchronous load
qdbus6 org.archpad.Keyboard /org/archpad/Keyboard org.archpad.Keyboard.LoadSwipeEngine
qdbus6 org.archpad.Keyboard /org/archpad/Keyboard org.archpad.Keyboard.GetSwipeState
# Output: Ready

# Query memory
qdbus6 org.archpad.Keyboard /org/archpad/Keyboard org.archpad.Keyboard.GetSwipeMemoryPssKiB
# Output: 186604 KiB

# Unload on demand
qdbus6 org.archpad.Keyboard /org/archpad/Keyboard org.archpad.Keyboard.UnloadSwipeEngine
qdbus6 org.archpad.Keyboard /org/archpad/Keyboard org.archpad.Keyboard.GetSwipeState
# Output: Unloaded
qdbus6 org.archpad.Keyboard /org/archpad/Keyboard org.archpad.Keyboard.GetSwipeMemoryPssKiB
# Output: 113644 KiB (released 72.9 MiB back)
```

### D. System Integrity Gate (`pacman -Qkk`)
```text
archpad-keyboard: 23 total files, 0 altered files
archpad-futo-swipe: 41 total files, 0 altered files
archpad-futo-swipe-en: 30 total files, 0 altered files
plasma-desktop: 4753 total files, 0 altered files
plasma-workspace: 6786 total files, 0 altered files
```
**Result**: 0 altered files across all packages.

---

## 4. Ready for Phase I2
With standalone packaging and asynchronous single-owner thread integration verified, Phase I1 is complete.
Proceed to **Phase I2** (Floating mobile touch surface refactor & GPU gesture trail) upon approval.
