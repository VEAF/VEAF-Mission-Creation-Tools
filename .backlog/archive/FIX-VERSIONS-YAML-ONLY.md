# Lot FIX-VERSIONS-YAML-ONLY — drop missions.yaml alias for weather pipeline

Status: ✅ done

**Goal**: Remove `missions.yaml` as an accepted alias for the weather pipeline config. `versions.yaml` is the only valid filename. Eliminates confusion with `mission.yaml`.

**Branch**: `feature/versions-yaml-only` → PR #386 → `develop`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| VYO-001 | Remove `missions.yaml` from `V6_PIPELINE_CANDIDATES["weather"]` | `mission_builder/v5_converter.py` | fix | 2 min | ✅ |
| VYO-002 | Remove legacy WEATHER-001 coexistence guard from `mission_builder_worker.py` | `mission_builder/mission_builder_worker.py` | fix | 5 min | ✅ |
| VYO-003 | Update `build.py` `_step_file` call and `weather.py` CLI default | `veaf_tools/commands/build.py`, `veaf_tools/commands/weather.py` | fix | 2 min | ✅ |
| VYO-004 | Update `weather_injector_README.py` and pipeline reference docs | `weather_injector/weather_injector_README.py`, `doc/PIPELINE_REFERENCE*.md` | doc | 5 min | ✅ |
| VYO-005 | Drop obsolete test `test_versions_not_copied_when_missions_exists` | `test/python/mission_builder/test_mission_builder_defaults.py` | test | 1 min | ✅ |
