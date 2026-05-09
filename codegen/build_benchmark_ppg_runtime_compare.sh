#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CC_BIN="${CC:-clang}"
CFLAGS_VALUE="${CFLAGS:--O3 -std=c99 -Wall -Wextra}"
BUILD_DIR="build/runtime_compare"
BENCHMARK_SRC="benchmark_ppg_runtime_compare.c"
BENCHMARK_BIN="$BUILD_DIR/benchmark_ppg_runtime_compare"

if [[ "$(uname -s)" == "Darwin" ]]; then
  LIB_EXT="dylib"
  SHARED_FLAG="-dynamiclib"
  DL_FLAGS=""
else
  LIB_EXT="so"
  SHARED_FLAG="-shared"
  DL_FLAGS="-ldl"
fi

mkdir -p "$BUILD_DIR"

build_library() {
  local source_dir="$1"
  local output_lib="$2"
  local sources=()

  while IFS= read -r -d '' source_file; do
    sources+=("$source_file")
  done < <(find "$source_dir" -maxdepth 1 -name '*.c' ! -name 'spo2_pr_waveform_test.c' -print0 | sort -z)

  if [[ "${#sources[@]}" -eq 0 ]]; then
    echo "No generated C sources found in $source_dir" >&2
    exit 1
  fi

  "$CC_BIN" $CFLAGS_VALUE -fPIC "$SHARED_FLAG" -I"$source_dir" \
    "${sources[@]}" -o "$output_lib" -lm
}

build_library "ppg_process0507" "$BUILD_DIR/libppg_process0507.$LIB_EXT"
build_library "ppg_process_0509" "$BUILD_DIR/libppg_process_0509.$LIB_EXT"

"$CC_BIN" $CFLAGS_VALUE "$BENCHMARK_SRC" -o "$BENCHMARK_BIN" -lm $DL_FLAGS

echo "Built: $BENCHMARK_BIN"
echo "Run from codegen, for example:"
echo "  ./$BENCHMARK_BIN --data-ids 222,225 --repeat 5"

if [[ "${1:-}" == "--run" ]]; then
  shift
  "./$BENCHMARK_BIN" "$@"
fi
