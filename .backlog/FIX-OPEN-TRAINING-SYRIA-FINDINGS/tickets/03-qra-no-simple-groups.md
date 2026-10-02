# 03 — create_qra: no simple_groups next to the scramble levels

Status: ✅ done

Files: `veaf_mission_mcp/composites.py` (`"simple_groups": group_names`), the validator,
`doc/mission-maker/scripts/veafQraManager.md`, tests.

## What happened

`create_qra` writes every interceptor into `simple_groups` and appends the caller's `groups_by_enemy_count`.
At runtime `:addGroup` (simple_groups) fills level 1, and `setRandomGroupsToDeployByEnemyQuantity(1, …)` then
replaces level 1 (`veafQraCore.lua`, `setGroupsToDeployByEnemyQuantity`): with a level-1 rule the effect is
the intended one. With levels starting at 2 or above, level 1 keeps `simple_groups`, and **every**
interceptor scrambles at the first intruder. The YAML reads as if both lists applied.

**Measured while doing the ticket (2026-10-02), the second case is wrong**: `addGroup` does not lower
`minimumNbEnemyPlanes`, so a lowest level of 2 sets that minimum to 2 and `deploy()` returns before choosing
anything at one intruder — level 1 never fires. Either way `simple_groups` beside levels **never deploy**;
the harm is a YAML that lies, not a scramble at the first intruder. `test_veafQraManager.lua`
(`TestVeafQraSimpleGroupsBesideLevels`) pins both cases, and the validator warns on both.

## Done when

- `create_qra` writes `simple_groups` only when the caller gives no `groups_by_enemy_count`.
- `validate` warns on a QRA definition that has both, naming it (any lowest level: both cases are dead).
- Tests: the composite with levels writes no `simple_groups`; the validator warning.
