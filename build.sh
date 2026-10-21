#!/usr/bin/env bash
set -Eeuo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

BUILD_KIND="relwithdebinfo"
CLEAN=0
INSTALL_DEPS=0
JOBS="${RECVX_BUILD_JOBS:-}"

readonly SDK_SOURCE="$ROOT_DIR/.deps/rexglue-sdk"
readonly SDK_BINARY_PATCH_HELPER="$ROOT_DIR/scripts/ensure-rexglue-binary-patches.py"
readonly SDK_TIMERQUEUE_HELPER="$ROOT_DIR/scripts/ensure-rexglue-timerqueue-blocking-wait.py"
readonly SDK_DISRUPTOR_HELPER="$ROOT_DIR/scripts/ensure-disruptorplus-blocking-wait-fix.py"
readonly SDK_DB16_NOOP_HELPER="$ROOT_DIR/scripts/ensure-rexglue-db16cyc-noop.py"
readonly SDK_SWITCH_TRAP_HELPER="$ROOT_DIR/scripts/ensure-rexglue-switch-trap-context.py"
readonly SDK_FLOAT_FROM_CHARS_HELPER="$ROOT_DIR/scripts/ensure-rexglue-float-from-chars.py"
readonly ROOT_PATCH_CLEANUP="$ROOT_DIR/scripts/cleanup-obsolete-root-patches.sh"

usage() {
  cat <<'EOF'
Usage: ./build.sh [options]

Build configuration:
  --debug           Build Debug
  --relwithdebinfo  Build RelWithDebInfo (default)
  --release         Build Release
  --clean           Fresh CMake configure + clean-first build
  --install-deps    Install missing host dependencies
  --jobs N          Parallel build jobs
  -h, --help        Show this help

This build always uses:
  .deps/rexglue-sdk

The pinned ReXGlue revision is taken from scripts/common.sh.
ReXGlue compatibility/optimization fixes are applied idempotently by scripts/
and no generated .patch files are required or created in the project root.
EOF
}

require_value() {
  [[ -n "${2:-}" ]] || recvx_die "$1 requires a value"
}

while (($#)); do
  case "$1" in
    --debug) BUILD_KIND="debug" ;;
    --relwithdebinfo) BUILD_KIND="relwithdebinfo" ;;
    --release) BUILD_KIND="release" ;;
    --clean) CLEAN=1 ;;
    --install-deps) INSTALL_DEPS=1 ;;
    --jobs)
      require_value "$1" "${2:-}"
      JOBS="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) recvx_die "unknown option '$1' (try --help)" ;;
  esac
  shift
done

[[ "$RECVX_HOST_ARCH" != "unsupported" ]] ||
  recvx_die "unsupported host architecture: $(uname -m)"

if [[ -n "$JOBS" && ! "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
  recvx_die "--jobs must be a positive integer"
fi

if [[ -z "$JOBS" ]]; then
  if command -v nproc >/dev/null 2>&1; then
    JOBS="$(nproc)"
  else
    JOBS=2
  fi
fi

readonly PRESET="linux-$RECVX_HOST_ARCH-$BUILD_KIND"
readonly BUILD_DIR="$ROOT_DIR/out/build/$PRESET"
readonly STAGE_DIR="$ROOT_DIR/out/stage/$PRESET"

version_major() {
  "$1" --version 2>/dev/null | sed -nE '1{s/.*version ([0-9]+).*/\1/p;q;}'
}

select_clang() {
  local candidate major c_command
  CLANG_MAJOR=0
  CLANG_C=""
  CLANG_CXX=""
  for candidate in clang++ clang++-22 clang++-21 clang++-20 clang++-19 clang++-18; do
    command -v "$candidate" >/dev/null 2>&1 || continue
    major="$(version_major "$candidate")"
    [[ "$major" =~ ^[0-9]+$ ]] || continue
    c_command="${candidate/clang++/clang}"
    command -v "$c_command" >/dev/null 2>&1 || continue
    if ((major > CLANG_MAJOR)); then
      CLANG_MAJOR="$major"
      CLANG_C="$(command -v "$c_command")"
      CLANG_CXX="$(command -v "$candidate")"
    fi
  done
}

library_available() {
  local soname="$1"
  if command -v ldconfig >/dev/null 2>&1 &&
     ldconfig -p 2>/dev/null | grep -Fq "$soname"; then
    return 0
  fi
  find /usr/lib /usr/lib64 /lib /lib64 -maxdepth 2 -name "$soname" \
    -print -quit 2>/dev/null | grep -q .
}

declare -a MISSING_REQUIREMENTS=()

check_host_requirements() {
  local command_name
  MISSING_REQUIREMENTS=()

  for command_name in cmake ninja git python3 sha256sum pkg-config; do
    command -v "$command_name" >/dev/null 2>&1 ||
      MISSING_REQUIREMENTS+=("command:$command_name")
  done

  select_clang
  if [[ -z "$CLANG_CXX" ]] || ((CLANG_MAJOR < 18)); then
    MISSING_REQUIREMENTS+=("Clang>=18")
  fi

  for command_name in libvulkan.so.1 libX11.so.6 libX11-xcb.so.1 libxcb.so.1 \
    libwayland-client.so.0; do
    library_available "$command_name" ||
      MISSING_REQUIREMENTS+=("runtime-library:$command_name")
  done
}

install_arch_deps() {
  local -a cmd=()
  if ((EUID != 0)); then
    command -v sudo >/dev/null 2>&1 || recvx_die "sudo is required"
    cmd+=(sudo)
  fi
  cmd+=(pacman -S --needed --
    base-devel cmake ninja clang lld git python pkgconf curl unzip autoconf
    gtk3 libx11 libxss vulkan-headers vulkan-icd-loader wayland
    wayland-protocols libxkbcommon libdecor alsa-lib libpulse pipewire)
  recvx_run "${cmd[@]}"
}

check_host_requirements
if ((${#MISSING_REQUIREMENTS[@]})); then
  recvx_warn "missing host requirements: ${MISSING_REQUIREMENTS[*]}"
  if ((INSTALL_DEPS)); then
    if [[ -r /etc/os-release ]]; then
      # shellcheck disable=SC1091
      source /etc/os-release
    fi
    case " ${ID:-} ${ID_LIKE:-} " in
      *" arch "*) install_arch_deps ;;
      *) recvx_die "automatic --install-deps is currently configured for Arch only" ;;
    esac
    check_host_requirements
  fi
fi

((${#MISSING_REQUIREMENTS[@]} == 0)) ||
  recvx_die "missing requirements: ${MISSING_REQUIREMENTS[*]}"

recvx_info "compiler: $CLANG_CXX (Clang $CLANG_MAJOR)"
recvx_info "CMake: $(cmake --version | sed -n '1p')"
recvx_verify_xex

[[ -f "$ROOT_DIR/CMakeLists.txt" ]] || recvx_die "missing CMakeLists.txt"
[[ -f "$ROOT_DIR/CMakePresets.json" ]] || recvx_die "missing CMakePresets.json"
[[ -f "$RECVX_MANIFEST" ]] || recvx_die "missing recvx_manifest.toml"
[[ -f "$ROOT_DIR/generated/rexglue.cmake" ]] ||
  recvx_die "missing generated/rexglue.cmake scaffold"
[[ -f "$SDK_BINARY_PATCH_HELPER" ]] ||
  recvx_die "missing helper: $SDK_BINARY_PATCH_HELPER"
[[ -f "$SDK_TIMERQUEUE_HELPER" ]] ||
  recvx_die "missing helper: $SDK_TIMERQUEUE_HELPER"
[[ -f "$SDK_DISRUPTOR_HELPER" ]] ||
  recvx_die "missing helper: $SDK_DISRUPTOR_HELPER"
[[ -f "$SDK_DB16_NOOP_HELPER" ]] ||
  recvx_die "missing helper: $SDK_DB16_NOOP_HELPER"
[[ -f "$SDK_SWITCH_TRAP_HELPER" ]] ||
  recvx_die "missing helper: $SDK_SWITCH_TRAP_HELPER"
[[ -f "$SDK_FLOAT_FROM_CHARS_HELPER" ]] ||
  recvx_die "missing helper: $SDK_FLOAT_FROM_CHARS_HELPER"
[[ -f "$ROOT_PATCH_CLEANUP" ]] ||
  recvx_die "missing helper: $ROOT_PATCH_CLEANUP"

recvx_info "cleaning obsolete generated .patch files from project root"
recvx_run bash "$ROOT_PATCH_CLEANUP"

mkdir -p "$ROOT_DIR/.deps"

if [[ ! -d "$SDK_SOURCE/.git" ]]; then
  recvx_info "cloning pinned ReXGlue SDK into .deps/rexglue-sdk"
  recvx_run git clone --recursive "$RECVX_REXGLUE_REPOSITORY" "$SDK_SOURCE"
fi

sdk_head="$(git -C "$SDK_SOURCE" rev-parse HEAD 2>/dev/null || true)"
if [[ "$sdk_head" != "$RECVX_REXGLUE_COMMIT" && "$sdk_head" != "$RECVX_REXGLUE_COMMIT"* ]]; then
  recvx_info "checking out pinned ReXGlue revision: $RECVX_REXGLUE_COMMIT"
  recvx_run git -C "$SDK_SOURCE" fetch --all --tags
  recvx_run git -C "$SDK_SOURCE" checkout --detach "$RECVX_REXGLUE_COMMIT"
fi

recvx_run git -C "$SDK_SOURCE" submodule update --init --recursive

recvx_info "ensuring ReXGlue pre-codegen binary patch support"
recvx_run python3 "$SDK_BINARY_PATCH_HELPER" "$SDK_SOURCE"

recvx_info "ensuring ReXGlue TimerQueue blocking wait"
recvx_run python3 "$SDK_TIMERQUEUE_HELPER" "$SDK_SOURCE"

recvx_info "fixing vendored Disruptor++ blocking wait"
recvx_run python3 "$SDK_DISRUPTOR_HELPER" "$SDK_SOURCE"

recvx_info "restoring ReXGlue db16cyc codegen no-op"
recvx_run python3 "$SDK_DB16_NOOP_HELPER" "$SDK_SOURCE"

recvx_info "ensuring ReXGlue switch-trap CTR capture"
recvx_run python3 "$SDK_SWITCH_TRAP_HELPER" "$SDK_SOURCE"

recvx_info "enabling portable float parsing for Linux libc++"
recvx_run python3 "$SDK_FLOAT_FROM_CHARS_HELPER" "$SDK_SOURCE"

readonly SDK_PREFIX="$SDK_SOURCE/out/install/$RECVX_SDK_PRESET"

case "$BUILD_KIND" in
  debug) SDK_CMAKE_CONFIG="Debug" ;;
  relwithdebinfo) SDK_CMAKE_CONFIG="RelWithDebInfo" ;;
  release) SDK_CMAKE_CONFIG="Release" ;;
  *) recvx_die "unsupported SDK build kind: $BUILD_KIND" ;;
esac
readonly SDK_CMAKE_CONFIG

recvx_info "building local ReXGlue SDK: $SDK_SOURCE"
recvx_info "ReXGlue SDK configuration: $SDK_CMAKE_CONFIG"
RECVX_REXGLUE_PERF_COUNTERS="${RECVX_REXGLUE_PERF_COUNTERS:-OFF}"
case "${RECVX_REXGLUE_PERF_COUNTERS^^}" in
  ON|OFF) ;;
  *) recvx_die "RECVX_REXGLUE_PERF_COUNTERS must be ON or OFF" ;;
esac

recvx_run cmake --preset "$RECVX_SDK_PRESET" -S "$SDK_SOURCE" \
  -DCMAKE_C_COMPILER:FILEPATH="$CLANG_C" \
  -DCMAKE_CXX_COMPILER:FILEPATH="$CLANG_CXX" \
  -DCMAKE_CXX_FLAGS:STRING="${CXXFLAGS:-}" \
  -DREXGLUE_ENABLE_PERF_COUNTERS:BOOL="$RECVX_REXGLUE_PERF_COUNTERS"
readonly SDK_BUILD_DIR="$SDK_SOURCE/out/build/$RECVX_SDK_PRESET"
recvx_run cmake --build "$SDK_BUILD_DIR" \
  --config "$SDK_CMAKE_CONFIG" \
  --target install --parallel "$JOBS"

# ReXGlue upstream installs the CLI only for Release. Resident Evil Code: Veronica X uses the CLI from
# generated/rexglue.cmake in the host configuration (normally RelWithDebInfo),
# so ensure that exact CLI target exists and teach the installed CMake package
# where to find it for the selected configuration.
recvx_info "ensuring ReXGlue CLI for $SDK_CMAKE_CONFIG"
recvx_run cmake --build "$SDK_BUILD_DIR" \
  --config "$SDK_CMAKE_CONFIG" \
  --target rexglue --parallel "$JOBS"

case "$SDK_CMAKE_CONFIG" in
  Debug) SDK_CLI_FILENAME="rexglued" ;;
  RelWithDebInfo) SDK_CLI_FILENAME="rexgluerd" ;;
  Release) SDK_CLI_FILENAME="rexglue" ;;
  *) recvx_die "unsupported ReXGlue CLI configuration: $SDK_CMAKE_CONFIG" ;;
esac

SDK_CLI_BUILD="$SDK_SOURCE/out/$RECVX_SDK_PRESET/$SDK_CMAKE_CONFIG/$SDK_CLI_FILENAME"
if [[ ! -x "$SDK_CLI_BUILD" ]]; then
  SDK_CLI_BUILD="$(find "$SDK_SOURCE/out/$RECVX_SDK_PRESET" -maxdepth 3 -type f -name "$SDK_CLI_FILENAME" -perm -u+x -print -quit 2>/dev/null || true)"
fi
[[ -n "$SDK_CLI_BUILD" && -x "$SDK_CLI_BUILD" ]] ||
  recvx_die "built ReXGlue CLI not found for $SDK_CMAKE_CONFIG ($SDK_CLI_FILENAME)"

mkdir -p "$SDK_PREFIX/bin"
recvx_run install -m 0755 "$SDK_CLI_BUILD" "$SDK_PREFIX/bin/rexglue"

REXGLUE_CLI="$SDK_PREFIX/bin/rexglue"

# Do not patch ReXGlue's installed CMake exports. Upstream installs the CLI
# target location only for Release, while Resident Evil Code: Veronica X is normally built as
# RelWithDebInfo. The host configure gets a temporary CMake project-include
# below that fixes only the imported executable target after rexglue is loaded.
readonly REXGLUE_CLI
[[ -x "$REXGLUE_CLI" ]] ||
  recvx_die "local ReXGlue CLI is missing: $REXGLUE_CLI"
recvx_info "ReXGlue CLI import: $SDK_CMAKE_CONFIG -> $REXGLUE_CLI"


recvx_info "ReXGlue CLI: $REXGLUE_CLI ($("$REXGLUE_CLI" --version | sed -n '1p'))"
recvx_info "ReXGlue prefix: $SDK_PREFIX"

# No title-specific guest binary patches are enabled by default.
# Add only addresses proven against this exact XEX.

recvx_prepare_logs
BUILD_LOG="$ROOT_DIR/logs/build-$(recvx_timestamp)-$$.log"
CODEGEN_LOG="$ROOT_DIR/logs/codegen-$(recvx_timestamp)-$$.log"
recvx_info "build log: $BUILD_LOG"
exec > >(tee "$BUILD_LOG") 2>&1

declare -a codegen_command=(
  "$REXGLUE_CLI"
  --log-level info
  --log-file "$CODEGEN_LOG"
  codegen
)

FORCE_CODEGEN=0
if grep -Rqs --include='*.cpp' '__builtin_ia32_pause' "$ROOT_DIR/generated/default" 2>/dev/null; then
  recvx_info "legacy db16cyc host pause detected; forcing one codegen regeneration"
  FORCE_CODEGEN=1
fi

# The switch-trap compatibility helper changes both the code generator and the
# generated PCH template. ReXGlue's normal module stamp does not include those
# local SDK source edits, so explicitly invalidate one codegen run when an old
# generated PCH is still present. Without this, the build can say "module up to
# date" and keep the old raw __builtin_trap() forever.
if grep -q 'REXGLUE_GDB_SWITCH_TRAP_HELPER' \
    "$SDK_SOURCE/resources/templates/codegen/pch_h.inja" 2>/dev/null && \
   ! grep -Rqs --include='*_pch.h' 'REXGLUE_GDB_SWITCH_TRAP_HELPER' \
    "$ROOT_DIR/generated/default" 2>/dev/null; then
  recvx_info "switch-trap helper changed generated PCH; forcing one codegen regeneration"
  FORCE_CODEGEN=1
fi

if ((FORCE_CODEGEN)); then
  codegen_command+=(--ignore-stamp)
else
  recvx_info "codegen: using dependency stamp"
fi
codegen_command+=("$RECVX_MANIFEST")
recvx_run "${codegen_command[@]}"

# generated/rexglue.cmake uses $<TARGET_FILE:rex::rexglue> for its codegen
# custom command. The installed SDK doesn't provide an imported CLI location
# for RelWithDebInfo, so defer a target-property fix until the end of the
# top-level CMake directory, after find_package(rexglue) has created the target.
CMAKE_FIX_DIR="$ROOT_DIR/out/cmake"
CMAKE_REXGLUE_CLI_FIX="$CMAKE_FIX_DIR/recvx-rexglue-cli-import.cmake"
mkdir -p "$CMAKE_FIX_DIR"

cat > "$CMAKE_REXGLUE_CLI_FIX" <<EOF
# Generated by RECVX build.sh. Kept under out/ and never committed.
function(_recvx_fix_rexglue_cli_import)
  if(NOT TARGET rex::rexglue)
    message(FATAL_ERROR "RECVX: rex::rexglue target was not created by the SDK")
  endif()

  foreach(_recvx_cfg DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
    set_property(
      TARGET rex::rexglue
      APPEND PROPERTY IMPORTED_CONFIGURATIONS \${_recvx_cfg})
    set_target_properties(
      rex::rexglue
      PROPERTIES IMPORTED_LOCATION_\${_recvx_cfg} "$REXGLUE_CLI")
  endforeach()
endfunction()

cmake_language(DEFER CALL _recvx_fix_rexglue_cli_import)
EOF

recvx_info "host CMake CLI fix: $CMAKE_REXGLUE_CLI_FIX"

declare -a configure_extra=(
  -DCMAKE_C_COMPILER:FILEPATH="$CLANG_C"
  -DCMAKE_CXX_COMPILER:FILEPATH="$CLANG_CXX"
  -DCMAKE_CXX_FLAGS:STRING="${CXXFLAGS:-}"
  -DCMAKE_PREFIX_PATH:PATH="$SDK_PREFIX"
  -Drexglue_DIR:PATH="$(recvx_config_from_prefix "$SDK_PREFIX")"
  -DCMAKE_PROJECT_INCLUDE:FILEPATH="$CMAKE_REXGLUE_CLI_FIX"
)

if ((CLEAN)); then
  configure_extra+=(--fresh)
fi

recvx_cmake_configure "$PRESET" "${configure_extra[@]}"

declare -a build_command=(cmake --build "$BUILD_DIR" --parallel "$JOBS")
if ((CLEAN)); then
  build_command+=(--clean-first)
fi
recvx_run "${build_command[@]}"

BINARY_PATH="$BUILD_DIR/recvx"

find_sdk_library() {
  local library_name="$1"
  local candidate=""
  for candidate in \
    "$SDK_PREFIX/lib/$library_name" \
    "$SDK_PREFIX/lib64/$library_name"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  find "$SDK_PREFIX" -type f -name "$library_name" -print -quit 2>/dev/null
}

case "$BUILD_KIND" in
  debug)
    GPU_PLUGIN_NAME="librexgpu-xenosd.so"
    RUNTIME_NAME="librexruntimed.so"
    ;;
  relwithdebinfo)
    GPU_PLUGIN_NAME="librexgpu-xenosrd.so"
    RUNTIME_NAME="librexruntimerd.so"
    ;;
  release)
    GPU_PLUGIN_NAME="librexgpu-xenos.so"
    RUNTIME_NAME="librexruntime.so"
    ;;
  *) recvx_die "unsupported build kind: $BUILD_KIND" ;;
esac

RUNTIME_PATH="$(find_sdk_library "$RUNTIME_NAME" || true)"
PLUGIN_PATH="$(find_sdk_library "$GPU_PLUGIN_NAME" || true)"

[[ -x "$BINARY_PATH" ]] || recvx_die "build produced no executable: $BINARY_PATH"
[[ -n "$RUNTIME_PATH" && -f "$RUNTIME_PATH" ]] ||
  recvx_die "local SDK has no $RUNTIME_NAME"
[[ -n "$PLUGIN_PATH" && -f "$PLUGIN_PATH" ]] ||
  recvx_die "local SDK has no $GPU_PLUGIN_NAME"

mkdir -p -- "$STAGE_DIR"
recvx_run install -m 0755 "$BINARY_PATH" "$STAGE_DIR/recvx"
recvx_run install -m 0755 "$PLUGIN_PATH" "$STAGE_DIR/$GPU_PLUGIN_NAME"
recvx_run install -m 0755 "$RUNTIME_PATH" "$STAGE_DIR/$RUNTIME_NAME"

for stale_runtime in librexruntime.so librexruntimed.so librexruntimerd.so; do
  [[ "$stale_runtime" == "$RUNTIME_NAME" ]] && continue
  rm -f "$STAGE_DIR/$stale_runtime"
done

if [[ -L "$ROOT_DIR/out/stage/current" || ! -e "$ROOT_DIR/out/stage/current" ]]; then
  recvx_run ln -sfn "$PRESET" "$ROOT_DIR/out/stage/current"
fi

printf '\n'
recvx_info "build successful"
recvx_info "local SDK: $SDK_SOURCE"
recvx_info "executable: $STAGE_DIR/recvx"
recvx_info "launch from project root with: ./run.sh"
