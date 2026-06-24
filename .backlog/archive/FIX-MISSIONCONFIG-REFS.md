# Lot FIX-MISSIONCONFIG-REFS — references to `missionConfig.lua` in doc and code

Status: ✅ done

**Goal**: Replace all user-facing references to `missionConfig.lua` with the correct v6 name (`mission-script.lua` for custom code, `mission.yaml` for configuration).

**Branch**: `fix/remove-convert-command` → PR #371 → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| MCR-001 | Fix `veafQraManager.md/en.md`: "Via missionConfig.lua" section | `doc/mission-maker/scripts/` | doc | 5 min | ✅ |
| MCR-002 | Fix `veafSkynetIadsHelper.md/en.md`: prerequisites and section title | `doc/mission-maker/scripts/` | doc | 5 min | ✅ |
| MCR-003 | Fix directory trees in `mission_builder_README.py` and `mission_extractor_README.py` | `src/python/veaf-tools/` | doc | 5 min | ✅ |
| MCR-004 | Fix AIEN/CTLD/CSAR comments in `veaf.lua` | `src/scripts/veaf/veaf.lua` | chore | 5 min | ✅ |
| MCR-005 | Fix test fixtures (`veafDynamicConfig.lua`, `mapResource`) | `test/veaf-tools/` | chore | 10 min | ✅ |
