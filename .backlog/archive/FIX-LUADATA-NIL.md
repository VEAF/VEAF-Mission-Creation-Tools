# Lot FIX-LUADATA-NIL — pure-Python luadata parser rejects `nil` values

Status: ✅ done

**Goal**: SECREV-001 replaced the lua-executing `luadata.unserialize` with a pure-Python state machine that never handled `nil` as a value. Real v5 configs write `key = nil` everywhere (notably `country = nil` and commented-out `["waypoints"]` blocks), so `convert-v5` failed to parse the `settings` table of `waypointsSettings.lua` (and any table with a `nil` value) — logged as `Unserialize luadata failed … unexpected character`, silently dropping that table's data. Discovered during IMC-Day 6.4.0 testing while reproducing IMC2-003.

**Branch**: `fix/luadata-nil-values` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-LUADATA-NIL-001 | Handle Lua `nil` as a value in the pure-Python unserializer: a `key = nil` entry is dropped (Lua semantics — the entry does not exist), matching the former lua-execution behaviour. No code execution reintroduced. Regression tests for named/bracketed `nil`, `nil` before a table key, and sibling preservation. | `luadata/serializer/unserialize.py`, `test/python/security/test_luadata_nil.py` | fix | ✅ |
