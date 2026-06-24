# Lot FEAT-COMBATZONE-ACTIVATE — declaratively activate combat zones at mission start

Status: ✅ done

**Goal**: There is no declarative way in `mission.yaml` to **activate** combat zones at mission start. The generator (`lua_config_generator.py`, `COMBATZONE` branch) emits zone definitions and `veafCombatZone.initialize()`, but never the `veafCombatZone.ActivateZone("<name>", true)` calls — those used to be hand-written in the mission Lua (Tripack's screenshot: a block of `ActivateZone("OUTPOST_1", true)` …). Add a YAML mechanism so the build generates one `veafCombatZone.ActivateZone("<name>", true)` per requested zone, **after** `veafCombatZone.initialize()` (zones must be defined/registered first). Lockstep: `src/defaults/mission-folder/mission.yaml` + `doc/` (MISSION_YAML reference) + `test/python/`.

**YAML shape (decided — David)**: a **per-zone flag** inside `combat_zones:` — `active_at_start: true` on each zone to activate. Single source of truth (no zone-name duplication), consistent with the existing zone definitions. The generator collects the flagged zones and emits one `veafCombatZone.ActivateZone("<name>", true)` per flag, **after** `veafCombatZone.initialize()`.

**Branch**: `feat/combatzone-activate` → PR → `develop-v6`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FEAT-COMBATZONE-ACTIVATE-001 | Add a per-zone `active_at_start: true` flag inside `combat_zones:`; the build emits `veafCombatZone.ActivateZone("<name>", true)` for each flagged zone, after `veafCombatZone.initialize()`. Lockstep defaults + doc; add a generator test asserting the `ActivateZone` calls are emitted (and after `initialize()`). | `veaf_libs/lua_config_generator.py`, `src/defaults/mission-folder/mission.yaml`, `doc/`, `test/python/` | feat | ✅ (#501) |
