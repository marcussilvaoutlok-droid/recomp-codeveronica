#!/usr/bin/env bash
set -Eeuo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/common.sh
source "$ROOT_DIR/scripts/common.sh"

recvx_verify_sdk
recvx_export_runtime_library_path

readonly EXECUTABLE="$ROOT_DIR/out/stage/current/recvx"
[[ -x "$EXECUTABLE" ]] || recvx_die "built executable not found: $EXECUTABLE (run ./build.sh first)"

cd -- "$ROOT_DIR"
exec "$EXECUTABLE" "$@"
