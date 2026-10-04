# 01 — drop the macOS Intel target

Status: ✅ done — 2026-10-04
Type: chore

Remove the `macos-13` / `veaf-tools-macos-x86_64` entry and its best-effort plumbing from the `standalone` matrix of `.github/workflows/release.yml`.
Remove `("darwin", "x86_64")` from `veaf_libs/platform_assets.py`, and pin in its test that Darwin/x86_64 is now unsupported.
