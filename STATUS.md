# Status

## Current phase

The initial Linux host build is now verified for the pinned PAL Xbox 360 XEX. Android ARM64 packaging and runtime validation remain in progress.

## Verified target facts

- Title ID: `43430822`
- Media ID: `58A6EFFB`
- Internal module string: `Bio_cv.exe`
- XEX SHA-256: `c552c6995462a5cefdd52c07bebd28fff4481164b19a445c636d7b54736f3c70`
- ReXGlue baseline: `0.10.0-dev.g398e2ba`

## Verified build milestone

- The private XEX asset downloads successfully and its SHA-256 is checked before use.
- XEX metadata validation passes.
- ReXGlue code generation and the Linux host target compile complete successfully in GitHub Actions.
- The `recvx` Linux host executable and required runtime libraries are staged and uploaded as the `recvx-linux-host-build` artifact.
- The project CMake target now selects a shared library when configured for Android; this is a build-system foundation, not proof of an Android build or APK.

## Not yet claimed

- successful Android ARM64 cross-compilation
- a complete installable APK
- guest entrypoint execution
- rendered frame
- audio correctness
- controller input
- gameplay

Those milestones should only be checked off from logs produced by this exact project and XEX.

## Local XEX verification

The user verified the local game file on an Android/Termux device on 2026-10-21:

- File: `Default.xex`
- Size: `13774848` bytes
- Header: `XEX2`
- SHA-256: `c552c6995462a5cefdd52c07bebd28fff4481164b19a445c636d7b54736f3c70` (matches the expected target hash above)
- ASCII module references found: `Bio_cv.exe`, `xam.xex`, `xboxkrnl.exe`

This is a local-file identity check only. The retail XEX is intentionally not committed to this repository, and this check does not demonstrate successful Android compilation or gameplay.
