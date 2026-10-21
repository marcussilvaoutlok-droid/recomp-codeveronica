#!/usr/bin/env python3
"""Enable the SDK's portable floating-point parser on Linux libc++."""
from pathlib import Path
import sys

path = Path(sys.argv[1]) / "include/rex/string/numeric.h"
text = path.read_text()

# The SDK already provides a C-locale parser for macOS. Enable that same
# implementation for Linux, where the runner's libc++ lacks float from_chars.
text = text.replace(
    "#if REX_PLATFORM_MAC",
    "#if REX_PLATFORM_MAC || REX_PLATFORM_LINUX",
)

fpfs_guard = (
    "#if REX_PLATFORM_MAC || REX_PLATFORM_LINUX\n"
    "    auto [p, error] = portable_float_from_chars"
)
vec_guard = (
    "#if REX_PLATFORM_MAC || REX_PLATFORM_LINUX\n"
    "      auto result = detail::portable_float_from_chars(p, end, v.f32[i]);"
)
helper_guard = "#if REX_PLATFORM_MAC || REX_PLATFORM_LINUX\ntemplate <typename T>"

if fpfs_guard not in text:
    raise SystemExit("portable parser is not enabled in fpfs")
if vec_guard not in text:
    raise SystemExit("portable parser is not enabled in vector float parsing")
if helper_guard not in text:
    raise SystemExit("portable parser helper is not enabled for Linux")

path.write_text(text)
print("Linux portable float parsing enabled and verified")
