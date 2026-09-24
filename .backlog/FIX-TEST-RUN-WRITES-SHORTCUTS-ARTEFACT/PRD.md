# FIX-TEST-RUN-WRITES-SHORTCUTS-ARTEFACT — a local `pytest` leaves `veaf-shortcuts.json` in the source tree

Status: ✅ done

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
| 01 | [Stub the shortcut scan in the build orchestration tests](tickets/01-stub-the-shortcut-scan.md) | ✅ |
