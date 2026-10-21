#!/usr/bin/env python3
"""Non-decrypting sanity check for a locally supplied Xbox 360 XEX."""
from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

EXPECTED_SHA256 = "c552c6995462a5cefdd52c07bebd28fff4481164b19a445c636d7b54736f3c70"


def ascii_strings(data: bytes, minimum: int = 6):
    pattern = rb"[\x20-\x7e]{%d,}" % minimum
    for match in re.finditer(pattern, data):
        yield match.start(), match.group().decode("ascii", "replace")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Inspect a local XEX without decrypting or uploading it"
    )
    parser.add_argument("xex", nargs="?", default="game/Default.xex")
    args = parser.parse_args()
    path = Path(args.xex)
    if not path.is_file():
        print(f"ERROR: XEX not found: {path}", file=sys.stderr)
        return 2

    data = path.read_bytes()
    sha256 = hashlib.sha256(data).hexdigest()
    print(f"file:   {path}")
    print(f"size:   {len(data)} bytes")
    print(f"magic:  {data[:4]!r}")
    print(f"sha256: {sha256}")
    print(f"target hash match: {'yes' if sha256 == EXPECTED_SHA256 else 'no'}")

    needles = ("Bio_cv.exe", "xboxkrnl.exe", "xam.xex")
    found = set()
    print("\ninteresting strings:")
    for offset, value in ascii_strings(data):
        if any(needle.lower() in value.lower() for needle in needles) and value not in found:
            print(f"  0x{offset:08X}: {value}")
            found.add(value)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
