#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Reproducible build recipe for archpad-futo-swipe-1.0.0.tar.xz
set -euo pipefail

if (( $# < 2 )); then
    echo "Usage: $0 SOURCE_ROOT BUILD_ROOT [OUTPUT_TAR_XZ]" >&2
    exit 2
fi

source_root=$(realpath "$1")
build_root=$(realpath -m "$2")
output_tar=${3:-archpad-futo-swipe-1.0.0.tar.xz}

et_build="$build_root/executorch"
swipe_build="$build_root/swipe"
stage_dir=$(mktemp -d /tmp/archpad-futo-swipe-stage-XXXXXX)
trap 'rm -rf "$stage_dir"' EXIT

mkdir -p "$stage_dir/lib" "$stage_dir/bin" "$stage_dir/include/archpad/futo/swipe_decoder" \
         "$stage_dir/licenses" "$stage_dir/lib/pkgconfig"

# 1. Build and install shared library
g++ -shared -fPIC -O3 -march=native -Wl,-soname,libarchpad_futo_swipe.so.1 \
    -o "$stage_dir/lib/libarchpad_futo_swipe.so.1.0.0" \
    "$swipe_build"/CMakeFiles/swipe_decoder.dir/src/*.o \
    -Wl,--whole-archive \
    "$et_build/libexecutorch.a" \
    "$et_build/libexecutorch_selected_kernels.a" \
    "$et_build/backends/xnnpack/libxnnpack_backend.a" \
    -Wl,--no-whole-archive \
    "$et_build/extension/module/libextension_module_static.a" \
    "$et_build/extension/tensor/libextension_tensor.a" \
    "$et_build/extension/data_loader/libextension_data_loader.a" \
    "$et_build/extension/flat_tensor/libextension_flat_tensor.a" \
    "$et_build/extension/named_data_map/libextension_named_data_map.a" \
    "$et_build/extension/threadpool/libextension_threadpool.a" \
    "$et_build/libexecutorch_core.a" \
    "$et_build/kernels/portable/libportable_kernels.a" \
    "$et_build/backends/xnnpack/third-party/XNNPACK/libXNNPACK.a" \
    "$et_build/backends/xnnpack/third-party/XNNPACK/libxnnpack-microkernels-prod.a" \
    "$et_build/backends/xnnpack/third-party/pthreadpool/libpthreadpool.a" \
    "$et_build/backends/xnnpack/third-party/cpuinfo/libcpuinfo.a" \
    "$et_build/third-party/flatcc_ep/lib/libflatccrt.a" \
    "$et_build/kleidiai/libkleidiai.a" \
    -lpthread -ldl

ln -s libarchpad_futo_swipe.so.1.0.0 "$stage_dir/lib/libarchpad_futo_swipe.so.1"
ln -s libarchpad_futo_swipe.so.1 "$stage_dir/lib/libarchpad_futo_swipe.so"

# 2. Build qualify CLI dynamically linked against the shared library
g++ -O3 -march=native -o "$stage_dir/bin/archpad-futo-swipe-qualify" \
    "$source_root/targets/qualification_cli.cpp" \
    -I"$source_root/include" \
    -I"$source_root/third_party/executorch/third-party/json/include" \
    -L"$stage_dir/lib" -larchpad_futo_swipe \
    -Wl,-rpath,/usr/lib

# 3. Strip unneeded symbols
strip --strip-unneeded "$stage_dir/lib/libarchpad_futo_swipe.so.1.0.0"
strip "$stage_dir/bin/archpad-futo-swipe-qualify"

# 4. Copy public headers
cp -r "$source_root/include/swipe_decoder/"* "$stage_dir/include/archpad/futo/swipe_decoder/"

# 5. Pkg-config specification
cat << 'EOF_PC' > "$stage_dir/lib/pkgconfig/archpad-futo-swipe.pc
prefix=/usr
exec_prefix=${prefix}
libdir=${prefix}/lib
includedir=${prefix}/include/archpad/futo

Name: archpad-futo-swipe
Description: Standalone FUTO Swipe C++ Engine for ArchPad
Version: 1.0.0
Libs: -L${libdir} -larchpad_futo_swipe
Cflags: -I${includedir}
EOF_PC

# 6. Pinned licenses
cp "$source_root/LICENSE" "$stage_dir/licenses/LICENSE.futo-swipe"
cp "$source_root/third_party/executorch/LICENSE" "$stage_dir/licenses/LICENSE.executorch"
cp "$source_root/third_party/executorch/backends/xnnpack/third-party/XNNPACK/LICENSE" "$stage_dir/licenses/LICENSE.xnnpack"
cp "$source_root/third_party/kleidiai/LICENSES/Apache-2.0.txt" "$stage_dir/licenses/LICENSE.kleidiai-apache"
cp "$source_root/third_party/kleidiai/LICENSES/BSD-3-Clause.txt" "$stage_dir/licenses/LICENSE.kleidiai-bsd"
cp "$source_root/third_party/executorch/backends/xnnpack/third-party/cpuinfo/LICENSE" "$stage_dir/licenses/LICENSE.cpuinfo"
cp "$source_root/third_party/executorch/backends/xnnpack/third-party/pthreadpool/LICENSE" "$stage_dir/licenses/LICENSE.pthreadpool"
cp "$source_root/third_party/executorch/backends/xnnpack/third-party/FP16/LICENSE" "$stage_dir/licenses/LICENSE.fp16"
cp "$source_root/third_party/executorch/backends/xnnpack/third-party/FXdiv/LICENSE" "$stage_dir/licenses/LICENSE.fxdiv"
cp "$source_root/third_party/executorch/third-party/flatcc/LICENSE" "$stage_dir/licenses/LICENSE.flatcc"
cp "$source_root/third_party/executorch/third-party/flatbuffers/LICENSE" "$stage_dir/licenses/LICENSE.flatbuffers"
cp "$source_root/third_party/executorch/third-party/json/LICENSE.MIT" "$stage_dir/licenses/LICENSE.json"

# Package archive
tar -cJf "$output_tar" -C "$stage_dir" .
echo "Created: $output_tar ($(stat -c%s "$output_tar") bytes)"
sha512sum "$output_tar"
