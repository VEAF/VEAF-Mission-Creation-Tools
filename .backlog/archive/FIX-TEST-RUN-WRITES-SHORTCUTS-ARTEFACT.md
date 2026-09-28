# FIX-TEST-RUN-WRITES-SHORTCUTS-ARTEFACT — a local `pytest` leaves `veaf-shortcuts.json` in the source tree

Status: ✅ done · archived 2026-09-28

Origin: measured 2026-09-24 — `src/python/veaf-tools/veaf_libs/veaf-shortcuts.json` deleted before a
full local `poetry run pytest`, present after it.

## Why it matters

The file is a gitignored build artefact, and when present it **wins** over the live Lua scan in
`veaf_shortcuts_scanner.get_shortcuts()`. So after any later edit to
`src/scripts/veaf/veafShortcuts.lua`, the next local run fails
`test_veaf_shortcuts_scanner.py::TestLocalArtefactIsFresh`, and the MCP `list_shortcuts` serves stale
data — while CI, starting from a clean checkout, stays green. A test run must never modify the
source tree.

## Cause

`test/python/veaf_build/test_build_standalone.py::_recording_worker` stubs every side-effecting step
of `build_veaf_tools_standalone()` / `build_python_executables()` — except `_scan_lua_shortcuts`,
added to the worker after the helper was written. The five orchestration tests using the helper
therefore ran the real scan, which writes next to the module (`veaf_build/worker.py`,
`_scan_lua_shortcuts`).

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Stub the shortcut scan in the build orchestration tests](FIX-TEST-RUN-WRITES-SHORTCUTS-ARTEFACT.md) | ✅ |

---

## Tickets, in full

## 01 — Stub the shortcut scan in the build orchestration tests

Status: ✅ done

Type: fix · Files: `test/python/veaf_build/test_build_standalone.py`

### Change

Stub `_scan_lua_shortcuts` in `_recording_worker`, like `_scan_lua_modules` already is. The worker
itself is unchanged: writing the artefact next to the module is what the real build needs, since
PyInstaller bundles it from there.

### Definition of done

- [x] A test that failed before the fix: running both stubbed build paths leaves the two generated
      artefacts (`veaf-shortcuts.json`, `veaf_modules_list.json`) exactly as they were
- [x] A full local `poetry run pytest`, artefact deleted beforehand, leaves it absent

---
