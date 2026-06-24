# Lot QUALITY-GATE-FINISH — erode the remaining mypy exclusions

Status: ✅ done

**Goal**: finish the Quality Ratchet Policy (`CLAUDE.md` §3) — the `QUALITY-GATE` lot is closed but, per policy, the dedicated lot still mops up whatever workers no other lot reopened. Remaining `ignore_errors = true` application workers (the bundled `luadata` library stays excluded as third-party): `mission_converter.mission_converter_worker`, `mission_extractor.mission_extractor_worker`, `waypoints_injector.waypoints_manager`, `weather_injector.utils.lua_converter`, `weather_injector.weather.dcs_weather_converter`, `weather_injector.weather_injector_worker`. Drop each entry, fix the surfaced type errors, and do a final `--cov-fail-under` ratchet.

**Done**: removed all six application-worker entries from the mypy `ignore_errors` override (only `luadata*` third-party stays). Measuring first showed just **7 errors across 2 files** — the other four workers were error-free. Fixes were behaviour-preserving: `config: dict[str, Any]` annotation in `weather_injector/utils/lua_converter.py` (4 errors), and in `mission_extractor_worker.py` renamed a shadowed loop variable + dropped two redundant `: Path` re-annotations (3 errors). The whole `src/python/veaf-tools` tree now passes `mypy` with no per-module opt-outs. No `--cov-fail-under` bump: the lot adds no tests and coverage is unchanged (68.37 % vs gate 67, gap < 2). No behaviour change → existing tests cover (suite green).

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| QUALITY-GATE-FINISH-001 | Remove the remaining application-worker entries from the mypy `ignore_errors` list and fix the surfaced errors (keep `luadata*` third-party exclusion); bump `--cov-fail-under` per policy | `pyproject.toml`, `src/python/veaf-tools/**`, `test/python/` | chore | ✅ |
