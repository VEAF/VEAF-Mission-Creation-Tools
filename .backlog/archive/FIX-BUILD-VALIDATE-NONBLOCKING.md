# Lot FIX-BUILD-VALIDATE-NONBLOCKING — build references summary is non-blocking; operation zone_name not checked

Status: ✅ done

**Goal**: Two follow-up corrections to FEAT-BUILD-VALIDATE-REFS (#509):

1. **A COMBATZONE operation's `zone_name` is not a required trigger zone.** `VeafCombatOperation:initialize()` ([veafCombatZone.lua](../../src/scripts/veaf/veafCombatZone.lua)) does `if not self.missionEditorZoneName then return end` and **never** resolves it via `getTriggerZone`/`zoneToVec3` — the name is only a label/radio-menu name. Only a plain `VeafCombatZone:initialize()` errors without its trigger zone. So flagging an operation's `zone_name` as a missing trigger zone is a **false positive** (e.g. `goriOperation`); the operation is excluded from rule 4. (Rule 8 still validates the operation's tasking-order sub-zones against the declared `combat_zones`.)
2. **The build must not block on missing references.** Blocking the build denies the maker the `.miz` they need to fix the references in the Mission Editor and iterate. The build now **collects** the missing references and prints a **prominent warning summary at the very end** (after the `.miz` is written), never aborting. The `validate` command keeps its own severities (it doesn't produce a `.miz`).

**Branch**: `fix/build-validate-refs-nonblocking` → PR → `develop` (build-time only).

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-BUILD-VALIDATE-NONBLOCKING-001 | Exclude COMBATZONE operations from `find_missing_trigger_zone_refs`; make the build collect issues (`validate_references`) and report them in a non-blocking end-of-build summary (`report_reference_issues`); drop the abort path + `builder.validation_failed` key (→ `builder.reference_issues_header`). pytest TDD (operation not flagged; build non-blocking). Docs FR/EN updated. | `mission_builder/group_validation.py`, `mission_builder/mission_builder_worker.py`, `veaf_libs/locales/*.json`, `doc/`, `test/python/` | fix | ✅ (#510) |
