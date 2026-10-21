#!/usr/bin/env python3
"""Enable the SDK's locale-independent float parser on Linux libc++ builds."""
from pathlib import Path
import sys

root = Path(sys.argv[1])
path = root / "include/rex/string/numeric.h"
text = path.read_text()
original = text

text = text.replace("#if REX_PLATFORM_MAC\n#include <locale.h>\n#endif",
                    "#if REX_PLATFORM_MAC || REX_PLATFORM_LINUX\n#include <locale.h>\n#endif")
text = text.replace("#if REX_PLATFORM_MAC\ntemplate <typename T>\ninline std::from_chars_result portable_float_from_chars",
                    "#if REX_PLATFORM_MAC || REX_PLATFORM_LINUX\ntemplate <typename T>\ninline std::from_chars_result portable_float_from_chars")
text = text.replace("#if REX_PLATFORM_MAC\n    auto [p, error] = portable_float_from_chars",
                    "#if REX_PLATFORM_MAC || REX_PLATFORM_LINUX\n    auto [p, error] = portable_float_from_chars")
text = text.replace("#if REX_PLATFORM_MAC\n      auto result = detail::portable_float_from_chars",
                    "#if REX_PLATFORM_MAC || REX_PLATFORM_LINUX\n      auto result = detail::portable_float_from_chars")

if text == original:
    if ("#if REX_PLATFORM_MAC || REX_PLATFORM_LINUX" in text and
        "portable_float_from_chars(p, end, v.f32[i])" in text):
        print("Linux portable float parser already enabled")
        raise SystemExit(0)
    raise SystemExit("could not apply Linux float from_chars compatibility patch")
if "auto [p, error] = std::from_chars(range.data(), range.data() + range.size(), result," in text and "#if REX_PLATFORM_MAC || REX_PLATFORM_LINUX\n    auto [p, error] = portable_float_from_chars" not in text:
    raise SystemExit("floating parser fallback was not enabled in fpfs")
if "auto result = std::from_chars(p, end, v.f32[i], std::chars_format::general);" in text:
    raise SystemExit("vector float parser still calls unsupported floating from_chars")
path.write_text(text)
print("Enabled portable float parsing for Linux libc++")
