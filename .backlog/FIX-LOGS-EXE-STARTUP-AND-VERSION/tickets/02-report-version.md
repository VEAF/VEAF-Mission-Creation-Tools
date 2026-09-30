# 02 — the `veaf-logs` report carries the real version

Status: ⏸ paused
Type: fix
Files: `veaf-logs.spec`, `.github/workflows/release.yml`, possibly `veaf_build/worker.py`

## What

`veaf_libs.tool_version` reads `importlib.metadata.version("veaf-tools")`, then falls back to
`veaf_tools._version`. In the `veaf-logs` executable neither answers, as read on 2026-09-30:

- `veaf-logs.spec` bundles no `veaf-tools` distribution metadata (no `copy_metadata`);
- `veaf-build build` stamps `_version.py`, then restores the `"unknown"` stub, and the release
  workflow runs `pyinstaller veaf-logs.spec` only afterwards.

1. First confirm it in a built exe (the report dialog shows the `doctor` block).
2. Then stamp the version into the `veaf-logs` build — metadata in the spec, or build `veaf-logs`
   inside the stamped window of `veaf-build`.

## Done when

The PRD's second definition-of-done item holds.
