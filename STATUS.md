# Status

## Current phase

Initial ReXGlue bring-up scaffold for the supported PAL Xbox 360 XEX.

## Verified target facts

- Title ID: `43430822`
- Media ID: `58A6EFFB`
- Internal module string: `Bio_cv.exe`
- XEX SHA-256: `c552c6995462a5cefdd52c07bebd28fff4481164b19a445c636d7b54736f3c70`
- ReXGlue baseline: `0.10.0-dev.g398e2ba`

## Not yet claimed

- successful full codegen
- complete function registration
- guest entrypoint execution
- rendered frame
- audio correctness
- controller input
- gameplay

Those milestones should only be checked off from logs produced by this exact
project and XEX.

## Local XEX verification

The user verified the local game file on an Android/Termux device on 2026-10-21:

- File: `Default.xex`
- Size: `13774848` bytes
- Header: `XEX2`
- SHA-256: `c552c6995462a5cefdd52c07bebd28fff4481164b19a445c636d7b54736f3c70` (matches the expected target hash above)
- ASCII module references found: `Bio_cv.exe`, `xam.xex`, `xboxkrnl.exe`

This is a local-file identity check only. The retail XEX is intentionally not committed to this repository, and this check does not demonstrate successful code generation, Android compilation, or gameplay.
