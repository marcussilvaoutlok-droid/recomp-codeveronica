#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
removed=0
while IFS= read -r -d '' path; do
  rm -f -- "$path"
  printf '[recvx] removed obsolete generated patch: %s\n' "${path#$ROOT/}"
  removed=1
done < <(find "$ROOT" -maxdepth 1 -type f \( -name 'ReXGlue-*.patch' -o -name '*.bak' \) -print0)
(( removed )) || printf '[recvx] root patch cleanup: already clean\n'
