#!/usr/bin/env bash

# Shared Resident Evil Code: Veronica X workflow helpers.
# Sourcing this file performs no network, package-manager or build mutation.

RECVX_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
RECVX_XEX="$RECVX_ROOT/game/Default.xex"
RECVX_MANIFEST="$RECVX_ROOT/recvx_manifest.toml"
RECVX_EXPECTED_XEX_SHA256="c552c6995462a5cefdd52c07bebd28fff4481164b19a445c636d7b54736f3c70"
RECVX_EXPECTED_REXGLUE_VERSION="0.10.0-dev.g398e2ba"
RECVX_REXGLUE_VERSION_PREFIX="0.10."
RECVX_REXGLUE_COMMIT="30dd72705e47f91f4e8d9e5f30e089cac7169802"
RECVX_REXGLUE_REPOSITORY="https://github.com/marcussilvaoutlok-droid/rexglue-sdk.git"

case "$(uname -m)" in
  x86_64|amd64) RECVX_HOST_ARCH="amd64" ;;
  aarch64|arm64) RECVX_HOST_ARCH="arm64" ;;
  *) RECVX_HOST_ARCH="unsupported" ;;
esac
RECVX_DEFAULT_PRESET="linux-$RECVX_HOST_ARCH-relwithdebinfo"
RECVX_SDK_PRESET="linux-$RECVX_HOST_ARCH"
RECVX_SDK_PREFIX=""
RECVX_REXGLUE_CLI=""

recvx_die() {
  printf '[recvx] ERROR: %s\n' "$*" >&2
  exit 1
}

recvx_warn() { printf '[recvx] WARNING: %s\n' "$*" >&2; }
recvx_info() { printf '[recvx] %s\n' "$*"; }

recvx_print_command() {
  printf '[recvx] +'
  printf ' %q' "$@"
  printf '\n'
}

recvx_run() {
  recvx_print_command "$@"
  "$@"
}

recvx_require_command() {
  command -v "$1" >/dev/null 2>&1 || recvx_die "missing host dependency: $1"
}

recvx_verify_xex() {
  [[ -f "$RECVX_XEX" ]] || recvx_die "missing case-sensitive XEX: $RECVX_XEX"
  recvx_require_command sha256sum
  local actual_sha
  actual_sha="$(sha256sum "$RECVX_XEX")"
  actual_sha="${actual_sha%% *}"
  [[ "$actual_sha" == "$RECVX_EXPECTED_XEX_SHA256" ]] ||
    recvx_die "unexpected Default.xex SHA-256: $actual_sha"
}

recvx_config_from_prefix() {
  local prefix="$1" candidate
  for candidate in \
    "$prefix/lib/cmake/rexglue" \
    "$prefix/lib64/cmake/rexglue" \
    "$prefix/share/rexglue/cmake"; do
    [[ -f "$candidate/rexglueConfig.cmake" ]] && {
      printf '%s\n' "$candidate"
      return 0
    }
  done
  return 1
}

recvx_package_version() {
  sed -nE 's/^[[:space:]]*set\(REXGLUE_VERSION_STRING[[:space:]]+"([^"]+)"\).*/\1/p' \
    "$1/rexglueConfig.cmake" | head -n 1
}

recvx_accept_sdk_prefix() {
  local prefix="$1" config version cli
  [[ -d "$prefix" ]] || return 1
  prefix="$(cd -- "$prefix" && pwd -P)"
  config="$(recvx_config_from_prefix "$prefix" || true)"
  [[ -n "$config" ]] || return 1
  version="$(recvx_package_version "$config")"
  [[ "$version" == "$RECVX_REXGLUE_VERSION_PREFIX"* ]] || return 1
  cli="$prefix/bin/rexglue"
  [[ -x "$cli" ]] || return 1
  [[ "$("$cli" --version 2>/dev/null | sed -n '1p')" == "$version" ]] || return 1
  RECVX_SDK_PREFIX="$prefix"
  RECVX_REXGLUE_CLI="$cli"
  return 0
}

recvx_discover_sdk() {
  local requested="${REXGLUE_SDK_PREFIX:-${REXGLUE_PREFIX:-}}"
  local cache_config cli candidate prefix

  if [[ -n "$requested" ]]; then
    recvx_accept_sdk_prefix "$requested" ||
      recvx_die "no coherent ReXGlue $RECVX_REXGLUE_VERSION_PREFIX* SDK at $requested"
    return 0
  fi

  for candidate in \
    "$RECVX_ROOT/out/build/$RECVX_DEFAULT_PRESET/CMakeCache.txt" \
    "$RECVX_ROOT/out/build/linux-$RECVX_HOST_ARCH-debug/CMakeCache.txt" \
    "$RECVX_ROOT/out/build/linux-$RECVX_HOST_ARCH-release/CMakeCache.txt"; do
    [[ -f "$candidate" ]] || continue
    cache_config="$(sed -n 's/^rexglue_DIR:[^=]*=//p' "$candidate" | head -n 1)"
    [[ -n "$cache_config" ]] || continue
    prefix="$(cd -- "$cache_config/../../.." 2>/dev/null && pwd -P || true)"
    [[ -n "$prefix" ]] && recvx_accept_sdk_prefix "$prefix" && return 0
  done

  recvx_accept_sdk_prefix "$RECVX_ROOT/.deps/rexglue-sdk/out/install/$RECVX_SDK_PRESET" && return 0

  cli="$(command -v rexglue 2>/dev/null || true)"
  if [[ -n "$cli" ]]; then
    cli="$(readlink -f "$cli" 2>/dev/null || printf '%s' "$cli")"
    prefix="$(cd -- "$(dirname -- "$cli")/.." 2>/dev/null && pwd -P || true)"
    [[ -n "$prefix" ]] && recvx_accept_sdk_prefix "$prefix" && return 0
  fi

  for prefix in /usr/local /usr; do
    recvx_accept_sdk_prefix "$prefix" && return 0
  done
  return 1
}

recvx_verify_sdk() {
  if [[ -n "${REXGLUE_CLI:-}" ]]; then
    RECVX_REXGLUE_CLI="$REXGLUE_CLI"
    [[ -x "$RECVX_REXGLUE_CLI" ]] || recvx_die "REXGLUE_CLI is not executable"
    local cli_prefix
    cli_prefix="$(cd -- "$(dirname -- "$RECVX_REXGLUE_CLI")/.." && pwd -P)"
    recvx_accept_sdk_prefix "${REXGLUE_SDK_PREFIX:-${REXGLUE_PREFIX:-$cli_prefix}}" ||
      recvx_die "REXGLUE_CLI does not belong to a coherent installed SDK"
  elif ! recvx_discover_sdk; then
    recvx_die "ReXGlue SDK not found; run ./build.sh or set REXGLUE_SDK_PREFIX"
  fi

  local actual_version
  actual_version="$("$RECVX_REXGLUE_CLI" --version 2>/dev/null | sed -n '1p')"
  [[ "$actual_version" == "$RECVX_REXGLUE_VERSION_PREFIX"* ]] ||
    recvx_die "expected ReXGlue $RECVX_REXGLUE_VERSION_PREFIX*, found $actual_version"
}

recvx_prepare_logs() { mkdir -p -- "$RECVX_ROOT/logs"; }
recvx_timestamp() { date -u +%Y%m%dT%H%M%SZ; }

recvx_cmake_configure() {
  local preset="$1"
  shift
  cmake --preset "$preset" -S "$RECVX_ROOT" \
    -DCMAKE_PREFIX_PATH:PATH="$RECVX_SDK_PREFIX" \
    -Drexglue_DIR:PATH="$(recvx_config_from_prefix "$RECVX_SDK_PREFIX")" \
    "$@"
}

recvx_export_runtime_library_path() {
  local runtime_dir="$RECVX_SDK_PREFIX/lib"
  [[ -d "$runtime_dir" ]] || runtime_dir="$RECVX_SDK_PREFIX/lib64"
  if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
    export LD_LIBRARY_PATH="$runtime_dir:$LD_LIBRARY_PATH"
  else
    export LD_LIBRARY_PATH="$runtime_dir"
  fi
}
