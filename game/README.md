# Local game files

This directory is reserved for the user's own legally obtained Xbox 360 game files. Retail content is ignored by Git and must not be committed or uploaded.

The supported executable is named exactly:

```text
game/Default.xex
```

Expected target fingerprint for the upstream scaffold:

- Title ID: `43430822`
- Media ID: `58A6EFFB`
- Module: `Bio_cv.exe`
- SHA-256: `c552c6995462a5cefdd52c07bebd28fff4481164b19a445c636d7b54736f3c70`

Run `python3 scripts/inspect-xex.py game/Default.xex` locally to inspect the hash and a few identifying strings. Do not upload the XEX to GitHub Actions.
