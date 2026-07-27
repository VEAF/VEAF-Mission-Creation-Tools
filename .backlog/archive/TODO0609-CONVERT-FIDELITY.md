# Lot TODO0609-CONVERT-FIDELITY — convert-v5 report & extraction fidelity

Status: ✅ done

**Goal**: Make the `convert-v5` annotated report (`convert-v5-report.md`) and YAML output faithfully reflect what was migrated, so the mission-maker can spot at a glance the v5 code that was NOT auto-migrated and decide what to do (migrate by hand, report a bug, move to `mission-script.lua`). Covers todo-2026.06.09 items 4, 9, 10.

> Depends on TODO0609-MODULES-UNIFY for the target YAML shape that commented-out elements (-001) are emitted into.

**Branch**: `feat/convert-fidelity` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CONVERT-FIDELITY-001 | Re-parse commented-out v5 elements (any extractable module, e.g. a commented `combatZone_Abu_al_Duhur`) and re-emit them as **commented** YAML in `mission.yaml`, instead of silently dropping them. (todo item 4) | `mission_builder/config_migrator.py`, `mission_builder/v5_converter.py`, `test/python/` | feat | ✅ |
| CONVERT-FIDELITY-002 | In the annotated `missionConfig`, comment out the **entire** `if veafXxx then … end` init block of a migrated module (not only the `initialize()` line), so non-migrated code visually stands out. (todo item 9) | `mission_builder/config_migrator.py`, `test/python/` | feat | ✅ |
| CONVERT-FIDELITY-003 | Add `mission.silence_atc_on_all_airbases` to the default `mission.yaml` (value `true`) and emit the corresponding Lua. At conversion, scan `missionConfig.lua` for an active `veaf.silenceAtcOnAllAirbases()` call → `true`, else `false`. (todo item 10) | `src/defaults/mission-folder/mission.yaml`, `veaf_libs/lua_config_generator.py`, `mission_builder/config_migrator.py`, `test/python/` | feat | ✅ |
| CONVERT-FIDELITY-004 | Prepend a numeric summary header to `convert-v5-report.md` (e.g. "N modules migrated · M need manual action (lines …)") so the mission-maker sees at a glance whether work remains, without reading the full annotated config. Drives off the same data the annotation pass already computes. | `mission_builder/v5_converter.py`, `mission_builder/config_migrator.py`, `test/python/` | feat | ✅ |

> **001 done** (follow-up PR): a de-commented re-extraction of `missionConfig.lua` is diffed against the active `mission.yaml`; lines present only because of previously-commented elements are appended as a fully-commented "Commented-out v5 elements" block (generic — covers every extractor; pattern-based extraction filters prose). Covers all extractable types at once.
