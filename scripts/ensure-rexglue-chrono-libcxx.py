#!/usr/bin/env python3
"""Enable ReXGlue's chrono clock-cast shim on Linux libc++."""
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: ensure-rexglue-chrono-libcxx.py /path/to/rexglue-sdk")

header = Path(sys.argv[1]).resolve() / "include/rex/chrono/chrono.h"
if not header.is_file():
    raise SystemExit(f"[chrono-libcxx] missing ReXGlue header: {header}")

text = header.read_text(encoding="utf-8")
old = "#ifdef __APPLE__\n// Apple libc++ does not expose clock_time_conversion or clock_cast."
new = "#if defined(__APPLE__) || (defined(__linux__) && defined(_LIBCPP_VERSION))\n// Apple and Linux libc++ do not expose clock_time_conversion or clock_cast."
if new not in text:
    if old not in text:
        raise SystemExit("[chrono-libcxx] expected Apple chrono compatibility guard was not found")
    text = text.replace(old, new, 1)
    header.write_text(text, encoding="utf-8")

verified = header.read_text(encoding="utf-8")
if new not in verified:
    raise SystemExit("[chrono-libcxx] Linux libc++ compatibility guard was not enabled")
if "struct clock_time_conversion<::rex::chrono::WinSystemClock, ::rex::chrono::XSystemClock>" not in verified:
    raise SystemExit("[chrono-libcxx] first clock conversion specialization is missing")
if "struct clock_time_conversion<::rex::chrono::XSystemClock, ::rex::chrono::WinSystemClock>" not in verified:
    raise SystemExit("[chrono-libcxx] reverse clock conversion specialization is missing")

print("[chrono-libcxx] Linux libc++ chrono compatibility shim enabled and verified")
