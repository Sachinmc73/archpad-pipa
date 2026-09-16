#!/usr/bin/bash
set -euo pipefail

if (( $# < 2 || $# > 3 )); then
    echo "Usage: $0 SOURCE_ROOT BUILD_ROOT [JOBS]" >&2
    exit 2
fi

source_root=$(realpath "$1")
build_root=$(realpath -m "$2")
jobs=${3:-4}
et_root="$source_root/third_party/executorch"
python_root="$source_root/.python-build"
kleidiai_root="$source_root/third_party/kleidiai"

require_file() {
    if [[ ! -f "$1" ]]; then
        echo "Missing required build input: $1" >&2
        exit 1
    fi
}

verify_sha256() {
    local expected=$1
    local file=$2
    require_file "$file"
    printf '%s  %s\n' "$expected" "$file" | sha256sum --check --status
}

require_file "$source_root/CMakeLists.txt"
require_file "$et_root/CMakeLists.txt"
require_file "$python_root/torchgen/__init__.py"
require_file "$python_root/yaml/__init__.py"
require_file "$source_root/targets/qualification_cli.cpp"
require_file "$kleidiai_root/CMakeLists.txt"

verify_sha256 725242bab5d14345e96ff214e8de2bfbc1f962c232d320df9c24cb82ffd1fbaf \
    "$source_root/models/honorable_sturgeon/model_fp32.pte"
verify_sha256 01eaf16ac4bc0f1ed0698c240807f0e95e6d427bcf6de04983ffc50736744d85 \
    "$source_root/models/magic_macaw/model_fp32.pte"
verify_sha256 74d29f56a513c0c60abcd43df3b16a6b68925cdf4e97e51b094a5275ec2810d7 \
    "$source_root/models/hungry_jellyfish/context_lm.pte"
verify_sha256 a7db66376783b5a23ee3d4a2aaa8f2499fd9b35f975e92bcb248664c2cf6ebd1 \
    "$source_root/models/hungry_jellyfish/vocab.txt"
verify_sha256 07682388185c285d307e341d1733331af8699f735b4137e9f22571017fab69d2 \
    "$source_root/models/vocabs/en.combined.gz"

if [[ -d "$source_root/.git" ]]; then
    [[ $(git -C "$source_root" rev-parse HEAD) == \
        1b13f2c85d6b347f6ea3fbc4b3aaf01fce42429a ]]
    [[ $(git -C "$et_root" rev-parse HEAD) == \
        0b0e2c5cdd67c8b4396a46ea1d1aa72ffb0128d7 ]]
    [[ $(git -C "$kleidiai_root" rev-parse HEAD) == \
        45bf06030727ce049793ce6749e943cc2ea896fe ]]
    [[ $(git -C "$et_root/backends/xnnpack/third-party/XNNPACK" rev-parse HEAD) == \
        3131afead790c5c69a9aa12273dfc40399789ad7 ]]
    [[ $(git -C "$et_root/backends/xnnpack/third-party/FP16" rev-parse HEAD) == \
        4dfe081cf6bcd15db339cf2680b9281b8451eeb3 ]]
    [[ $(git -C "$et_root/backends/xnnpack/third-party/FXdiv" rev-parse HEAD) == \
        b408327ac2a15ec3e43352421954f5b1967701d1 ]]
    [[ $(git -C "$et_root/backends/xnnpack/third-party/cpuinfo" rev-parse HEAD) == \
        8a9210069b5a37dd89ed118a783945502a30a4ae ]]
    [[ $(git -C "$et_root/backends/xnnpack/third-party/pthreadpool" rev-parse HEAD) == \
        c2ba5c50bb58d1397b693740cf75fad836a0d1bf ]]
    [[ $(git -C "$et_root/third-party/flatbuffers" rev-parse HEAD) == \
        595bf0007ab1929570c7671f091313c8fc20644e ]]
    [[ $(git -C "$et_root/third-party/flatcc" rev-parse HEAD) == \
        896db54787e8b730a6be482c69324751f3f5f117 ]]
    [[ $(git -C "$et_root/third-party/gflags" rev-parse HEAD) == \
        a738fdf9338412f83ab3f26f31ac11ed3f3ec4bd ]]
    [[ $(git -C "$et_root/third-party/json" rev-parse HEAD) == \
        ac0133ea89a8fd730a9cc9649c5226a9995dc3e1 ]]
fi

selected_ops=$(sort -u \
    "$source_root/models/honorable_sturgeon/ops.txt" \
    "$source_root/models/magic_macaw/ops.txt" \
    "$source_root/models/hungry_jellyfish/ops.txt" | paste -sd, -)

et_build="$build_root/executorch"
swipe_build="$build_root/swipe"
mkdir -p "$build_root"

PYTHONPATH="$python_root" cmake -S "$et_root" -B "$et_build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DPYTHON_EXECUTABLE=/usr/bin/python3 \
    -DEXECUTORCH_BUILD_XNNPACK=ON \
    -DEXECUTORCH_BUILD_EXTENSION_MODULE=ON \
    -DEXECUTORCH_BUILD_EXTENSION_TENSOR=ON \
    -DEXECUTORCH_BUILD_EXTENSION_DATA_LOADER=ON \
    -DEXECUTORCH_BUILD_EXTENSION_FLAT_TENSOR=ON \
    -DEXECUTORCH_BUILD_EXTENSION_NAMED_DATA_MAP=ON \
    -DEXECUTORCH_BUILD_KERNELS_QUANTIZED=OFF \
    -DEXECUTORCH_BUILD_VULKAN=OFF \
    -DEXECUTORCH_BUILD_MPS=OFF \
    -DEXECUTORCH_BUILD_COREML=OFF \
    -DEXECUTORCH_BUILD_QNN=OFF \
    -DEXECUTORCH_BUILD_TESTS=OFF \
    -DEXECUTORCH_OPTIMIZE_SIZE=ON \
    -DXNNPACK_BUILD_ALL_MICROKERNELS=OFF \
    -DXNNPACK_ENABLE_SPARSE=OFF \
    -DXNNPACK_BUILD_TESTS=OFF \
    -DXNNPACK_BUILD_BENCHMARKS=OFF \
    -DXNNPACK_ENABLE_ARM_SME=OFF \
    -DXNNPACK_ENABLE_ARM_SME2=OFF \
    -DKLEIDIAI_SOURCE_DIR="$kleidiai_root" \
    -DEXECUTORCH_SELECT_OPS_LIST="$selected_ops"

PYTHONPATH="$python_root" cmake --build "$et_build" --parallel "$jobs"

cmake -S "$source_root" -B "$swipe_build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_MARCH_NATIVE=ON \
    -DET_BUILD="$et_build"
cmake --build "$swipe_build" --parallel "$jobs"

echo "Built isolated CLI: $swipe_build/archpad-futo-swipe-qualify"
