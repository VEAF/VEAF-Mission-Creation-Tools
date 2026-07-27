# Lot FEAT-CUSTOM-SCRIPTS — custom_scripts section in mission.yaml

Status: ✅ done

**Goal**: Allow declaring custom Lua scripts in `mission.yaml` to suppress warnings and control the generation of the DCS load trigger.

**Branch**: `feature/custom-scripts` → PR → `develop`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CUSTOM-001 | Add `CustomScript` dataclass + parse `custom_scripts` in `__init__` | `mission_builder_worker.py` | feat | 10 min | ✅ |
| CUSTOM-002 | Update warning logic (declared = info, unknown = warning with hint) | `mission_builder_worker.py` | feat | 10 min | ✅ |
| CUSTOM-003 | Filter load triggers according to `generate_load_trigger` | `mission_builder_worker.py` | feat | 10 min | ✅ |
| CUSTOM-004 | TDD tests (warnings + trigger resolution) | `test_mission_builder_defaults.py` | test | 10 min | ✅ |
| CUSTOM-005 | Document the section in the default `mission.yaml` | `src/defaults/mission-folder/mission.yaml` | doc | 5 min | ✅ |
