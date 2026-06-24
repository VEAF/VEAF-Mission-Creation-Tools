# Lot FIX-CONVERT-V5-DEPS — Resolve module dependencies when generating mission.yaml

Status: ✅ done

**Goal**: When `convert-v5` generates `mission.yaml`, pre-resolve module dependencies so required modules are already enabled in the generated file — no build-time auto-enable warning.

**Branch**: handled on `feature/UI-OUTPUT` (per user request) — no separate branch.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CVDEP-001 | Expose the dependency graph / resolver from `lua_config_generator.py` so the converter can reuse it — added pure `resolve_module_dependencies()` helper | `veaf_libs/lua_config_generator.py` | refactor | ✅ |
| CVDEP-002 | In `convert-v5` module generation, auto-enable required dependencies (transitively) and emit them explicitly in the generated `mission.yaml` | `mission_builder/v5_converter.py`, `locales/*.json` | feat | ✅ |
| CVDEP-003 | TDD: a v5 folder enabling `CASMISSION` produces a `mission.yaml` with `GROUNDAI` (and `SPAWN`) enabled | `test/python/` | test | ✅ |
