#!/usr/bin/env python3
"""Enable the SDK's portable floating-point parser on Linux libc++."""
from pathlib import Path
import sys

path = Path(sys.argv[1]) / "include/rex/string/numeric.h"
text = path.read_text()
old = text
text = text.replace("#if REX_PLATFORM_MAC", "#if REX_PLATFORM_MAC || REX_PLATFORM_LINUX")
if text == old:
    if "REX_PLATFORM_MAC || REX_PLATFORM_LINUX" in text and "portable_float_from_chars(p, end, v.f32[i])" in text:
        print("Linux portable float parser already enabled")
        raise SystemExit(0)
    raise SystemExit("expected platform guards not found")
if "auto result = std::from_chars(p, end, v.f32[i], std::chars_format::general);" in text:
    raise SystemExit("vector float parser still calls floating from_chars")
if "auto [p, error] = std::from_chars(range.data(), range.data() + range.size(), result," in text:
    if "#if REX_PLATFORM_MAC || REX_PLATFORM_LINUX\n    auto [p, error] = portable_float_from_chars" not in text:
        raise SystemExit("fpfs fallback not enabled")
path.write_text(text)
print("Enabled portable float parsing for Linux libc++")
