# Lot FEAT-BUILD-VALIDATE-REFS — build-time validation of mission.yaml references to Mission-Editor objects

Status: ✅ done

**Goal**: A `mission.yaml` references many objects the maker must have placed in the Mission Editor (trigger zones, groups, units, airfields). Today most missing references only fail at **runtime** inside DCS (an ERROR in `dcs.log`, or a silently broken feature). Surface them at **build time** instead, with a **fail-at-end** policy: run every check, log all warnings, collect all errors, let the build go to the end, then **abort** if ≥1 error — so a single run reports *everything*.

Infra reuse: [mission_validator.py](../../src/python/veaf-tools/veaf_libs/mission_validator.py) already aggregates `ValidationIssue(ERROR/WARNING)` and reads trigger zones (`_zone_names`); [group_validation.py](../../src/python/veaf-tools/mission_builder/group_validation.py) already collects group references. Airfields: [dcs_airdromes.py](../../src/python/veaf-tools/veaf_libs/dcs_airdromes.py) (`airdromes_for_theatre`). The build aborts via `logger.error(..., exception_type=...)` (note: `logger.error` raises `typer.Abort` by default → log non-fatally with `exception_type=None`).

**Validation rules** (the agreed list):

| # | Section | Key | ME object | Source of truth | Level |
|---|---------|-----|-----------|-----------------|-------|
| 1 | AIRWAVES | `trigger_zone_name` | trigger zone | `.miz` `triggers.zones` | WARN if `zone_center_coordinates`+`zone_radius` present, else ERROR |
| 2 | QRA | `trigger_zone` | trigger zone | `.miz` | ERROR |
| 3 | COMBATZONE (zone) | `zone_name` | trigger zone | `.miz` | ERROR |
| 4 | COMBATZONE (operation) | `zone_name` | trigger zone | `.miz` | ERROR |
| 5 | ASSETS · QRA · `cap_missions` · `combat_missions` | groups | group | `.miz` coalitions | ERROR (hardened from WARNING) |
| 6 | SANCTUARY | `polygon_units` | unit | `.miz` units | ERROR |
| 7 | QRA | `airport_link` | airfield | theatre airdrome table | ERROR (skip when the theatre is absent from the table → avoid false positives) |
| 8 | COMBATZONE (operation) | `tasking_orders.zone_name` + `dependencies` | declared `combat_zones` | `mission.yaml` (internal) | ERROR |

Out of scope: AIRWAVES `waves.groups` (spawn pattern, not a named ME group — kept excluded); TUM `BLUFOR`/`REDFOR` zones stay WARNING (unchanged).

**Branch**: `feature/build-validate-refs` → PR → `develop` (build-time only, no DCS validation needed).

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FEAT-BUILD-VALIDATE-REFS-001 | Collectors + finders for trigger-zone / unit / airfield / declared-combat-zone references (rules 1-4, 6-8) and harden the declared-group check to ERROR (rule 5). Aggregate into a reusable `validate_mission_content(yaml, mission, theatre)`; the build calls it fail-at-end (log all, abort at end if any ERROR); the `validate` command surfaces the same issues. luaunit/pytest TDD per rule, i18n FR/EN. | `mission_builder/group_validation.py`, `veaf_libs/mission_validator.py`, `mission_builder/mission_builder_worker.py`, `test/python/` | feat | ✅ (#509) |
