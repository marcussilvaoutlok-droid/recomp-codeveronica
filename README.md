# Resident Evil Code: Veronica X HD — Android recompilation workspace

Private workspace for bringing up the Xbox 360 PAL build of **Resident Evil Code: Veronica X HD** with ReXGlue and investigating an Android build path.

> **Current status: experimental scaffold.** This is not a finished port. A successful APK, gameplay, graphics, sound, and the presence of any particular dubbing/audio track have not been verified.

## Target identification

- Title ID: `43430822`
- Media ID: `58A6EFFB`
- Internal module: `Bio_cv.exe`
- Expected executable: `game/Default.xex`
- Expected SHA-256 for the upstream-supported target: `c552c6995462a5cefdd52c07bebd28fff4481164b19a445c636d7b54736f3c70`
- ReXGlue baseline: `0.10.0-dev.g398e2ba`

## Game files and privacy

Place files from your own legally obtained game copy in `game/`, with the executable named exactly `Default.xex`. The `game/` directory is git-ignored: **do not commit or upload the XEX, game assets, keys, or archives**.

Check the executable locally:

```bash
python3 scripts/inspect-xex.py game/Default.xex
```

The script reports the file hash; compare it to the expected hash above before attempting code generation.

## What comes next

1. Import the upstream ReXGlue project glue and preserve its notices/licenses.
2. Validate the XEX locally without uploading retail content.
3. Build the pinned host SDK and run code generation.
4. Fix code-generation and host-build errors based on logs.
5. Investigate Android/ARM64 support separately; do not treat a Linux host build as an Android port.
6. Verify graphics, controls, and audio independently before claiming the game is playable.

The original upstream project is experimental and archived: [ResidentEvil-CodeVeronicaX-X360-ReXGlue](https://github.com/ant0-blase/ResidentEvil-CodeVeronicaX-X360-ReXGlue). This workspace does not imply that Android support already exists.

## Licensing

The original scaffold's source code and third-party components retain their own licenses. See `LICENSE` and `THIRD_PARTY_NOTICES.md` when those files are imported. This repository does not include or grant rights to proprietary game content.
