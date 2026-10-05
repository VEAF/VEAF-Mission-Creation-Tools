# 01 — Emit `initialize()` after the missions it builds the menu from

Status: 🧑 waiting-human
Type: fix
Files: `src/python/veaf-tools/veaf_libs/lua_config_generator.py` (branch `elif mod_id == "COMBATMISSION":`), `test/python/veaf_libs/`, `CHANGELOG.md`

## What happens

See the [PRD](../PRD.md): `veafCombatMission.initialize()` is emitted first, `buildRadioMenu()` finds no mission and builds nothing, and the missions added after it never get a menu.

## Fix

Move `lines.append(f"    {var_name}.initialize()")` after the `cap_missions` and `combat_missions_data` loops, with a comment saying why the order matters.
`initialize()` also dumps the missions list (`dumpMissionsList`) and registers the remote module: both read better after the missions exist, and neither is needed before.
Check that no other emitted line in this branch relies on `initialize()` having run first (`addCapMission`, `AddMissionsWithSkillAndScale`, `VeafCombatMission:initialize` only read module tables).

Considered and not taken: making `AddMission` rebuild the menu.
It would rebuild the whole paginated menu once per mission (32 times in the demo) and changes runtime code for a generator ordering bug.

## Test

`test/python/veaf_libs/test_combat_mission_init_order.py`, written and seen failing before the fix:

- with one `cap_missions` entry and one `combat_missions` entry, the index of `veafCombatMission.initialize()` in the generated lines is greater than every `.addCapMission(` / `.AddMissionsWithSkillAndScale(` line;
- with `COMBATMISSION` enabled and no mission, `veafCombatMission.initialize()` is still emitted.

Look at `test/python/mission_builder/test_cap_missions_arguments.py` for how a generator test builds its config, and at `_emit_combat_mission` for the keys a minimal `combat_missions` entry needs.

## Branch and PR

Branch `fix/combat-mission-menu`, PR #1085. First aimed at `release/6.28.0`, then moved onto `develop` at David's request (2026-10-05); the CHANGELOG entry sits under `[Unreleased]`.
