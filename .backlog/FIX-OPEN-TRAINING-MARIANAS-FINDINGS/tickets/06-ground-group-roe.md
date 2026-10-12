# 06 — A ground group that holds fire and does not disperse

Status: ✅ done

Files: `veaf_mission_mcp/add_group.py`, `veaf_mission_mcp/composites.py` (`create_combat_zone` groups), `veaf_mission_mcp/actions.py`, tests.

## What happened

The Open Training prompt (4.6) wants the easy-level targets as one-vehicle groups, warm, **weapons hold** and **not dispersing under fire**.
No action sets either option: GermanyCW, Syria and Marianas each wrote a script that rewrites the first waypoint's task in the mission table (`statics_to_groups.py`, `inert_targets.py`), in the editor's shape (`Option` 0 = 4 for weapons hold, `Option` 8 with no value for no dispersal).

## Done when

- `add_group` and each group of `create_combat_zone` take `roe` (`weapons_free` | `return_fire` | `weapons_hold`) and `disperse` (bool), written as the editor writes them on the first waypoint.
- Or one `inert: true` that sets both, if that is the only use; say which.
- The prompt's 4.6 names the option instead of describing the shape.
- Tests: the written task matches the editor's shape; a group without the options is unchanged.

## Done

Two parameters, `roe` and `disperse` (David, 2026-10-12), on `add_group` and each `create_combat_zone` group, vehicle groups only. Values measured over 606 missions under D:/dev/_VEAF: `Option` 0 = 2 / 3 / 4, an unchecked dispersal `Option` 8 with no value (2 151 occurrences). `disperse: true` is DCS's default and writes nothing. The prompt's 4.6 names the options.
