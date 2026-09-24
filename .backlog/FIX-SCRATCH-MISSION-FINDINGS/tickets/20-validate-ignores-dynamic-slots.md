# 20 — `validate_mission` says there is no player slot in a mission made of dynamic slots

Status: ✅ done (#1000)
Type: fix
Files: `src/python/veaf-tools/veaf_libs/mission_validator.py`, tests

## Origin

GermanyCW-v6 rebuild of 2026-09-24: `validate_mission` on the folder.

## Measured

Two warnings: « Aucune place joueur dans la mission » and « presets.yaml est configuré mais la mission
n'a aucun aéronef joueur », on a mission whose build offers dynamic slots at 12 bases with 102 types
injected.

## Cause

Both checks count `Client` / `Player` units only, through `_aircraft_counts`:
`_check_has_player_slot` (`mission_validator.py:268-283`) and `_check_presets_waypoints`
(`mission_validator.py:491-501`). Neither looks at `warehouses.yaml` / the warehouses' `dynamicSpawn`,
nor at the dynamic-slot templates the build injects. The prepare path — the one the MCP recommends —
has no `Client` unit by construction, so the warning fires on every such mission.

## What it is not

Not wrong for a mission with neither static slots nor dynamic slots: that one still deserves the
warning.

## Done when

- A mission with at least one base offering dynamic slots (as the build will configure them) and a
  template or template file raises neither warning
- Tests: static slots only, dynamic slots only, neither — the warning only in the third case

## Outcome

`validate` counts a dynamic slot when the build will open one: a template to spawn from (the mission's
own `dynSpawnTemplate` groups, or the catalogue the build injects unless `dynamic_slot_templates` is
off) and a blue or red base whose warehouse says `dynamicSpawn = true`, or whose side `warehouses.yaml`
declares (the step then opens it). Measured on GermanyCW-v6: 2 warnings before, 0 after; the `no
player slot` message now says it looked for dynamic slots too.
