# 01 — find where the 14 s go

Status: ⏸ paused
Type: fix
Files: `veaf-logs.spec`, possibly `src/python/veaf-tools/veaf_logs/ui/main_window.py`

## What

1. Split the 14 s before changing anything: bootloader extraction of the onefile archive into the
   temp folder (a hypothesis, unverified: Defender scanning every extracted `.pyd`/`.dll` would fit),
   interpreter start, Qt start, then the window's own work (session restore, remote tabs reopened
   over SSH). `PYINSTALLER_*` debug logging, `-X importtime`, and a `--onedir` build of the same
   spec measured back to back tell those apart.
2. Only then pick the cut: `--onedir` shipped as a zip, restoring remote tabs after the window is
   shown, or whatever the measurement names.

## Done when

The PRD's first definition-of-done item holds.
