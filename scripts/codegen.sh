#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/common.sh"

IGNORE_STAMP=false
LOG_LEVEL=info
for arg in "$@"; do
  case "$arg" in
    --ignore-stamp|force)
      IGNORE_STAMP=true
      ;;
    --trace)
      LOG_LEVEL=trace
      ;;
    normal|linux-*)
      # Accepted for compatibility with the old script interface. Codegen is
      # now independent of a CMake preset.
      ;;
    *)
      recvx_die "usage: ./scripts/codegen.sh [--ignore-stamp] [--trace]"
      ;;
  esac
done

recvx_verify_xex
recvx_verify_sdk
recvx_prepare_logs
CODEGEN_LOG="$RECVX_ROOT/logs/codegen-$(recvx_timestamp).log"
printf 'Codegen log: %s\n' "$CODEGEN_LOG"

ARGS=(--log-level "$LOG_LEVEL" --log-file "$CODEGEN_LOG" codegen)
if [[ "$IGNORE_STAMP" == true ]]; then
  ARGS+=(--ignore-stamp)
fi
ARGS+=("$RECVX_MANIFEST")

cd "$RECVX_ROOT"
"$RECVX_REXGLUE_CLI" "${ARGS[@]}"
