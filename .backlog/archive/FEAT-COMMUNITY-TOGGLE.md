# Lot FEAT-COMMUNITY-TOGGLE — Enable/disable community scripts from mission.yaml

Status: ✅ done

**Goal**: Allow mission makers to individually enable or disable community Lua scripts (TUM, CTLD, CSAR, etc.) via a `community_scripts:` section in `mission.yaml`, analogous to the existing `lua_modules:` section.

**Branch**: `feature/community-toggle` → PR → `develop`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| COMM-001 | Give each community script a stable ID (key) in `get_community_script_files()` — return `list[dict]` instead of `list[tuple]` | `mission_tools/mission_constants.py` | refactor | 15 min | ✅ |
| COMM-002 | Parse `community_scripts:` section in `MissionBuilderWorker.__init__`; filter the list of community scripts to inject based on `enabled:` flags | `mission_builder/mission_builder_worker.py` | feat | 30 min | ✅ |
| COMM-003 | Apply the filter in both static trigger (`insert_veaf_trigrules`) and dynamic trigger (`insert_veaf_triggers`) | `mission_builder/mission_builder_worker.py` | feat | 20 min | ✅ |
| COMM-004 | Add `community_scripts:` block to the default `mission.yaml` with all scripts listed and `enabled: true` by default, with comments | `src/defaults/mission-folder/mission.yaml` | doc | 15 min | ✅ |
| COMM-005 | Update YAML reference doc (`MISSION_YAML_REFERENCE.md` + `.en.md`) with the new section | `doc/MISSION_YAML_REFERENCE.md`, `doc/MISSION_YAML_REFERENCE.en.md` | doc | 20 min | ✅ |
| COMM-006 | TDD tests: verify that a script with `enabled: false` is absent from the injected triggers | `test/python/` | test | 20 min | ✅ |
| COMM-007 | `convert-v5`: detect community scripts present in `published/src/scripts/community/` and emit `community_scripts:` section in generated `mission.yaml` | `mission_builder/v5_converter.py`, `test_v5_converter.py` | feat | 20 min | ✅ |
