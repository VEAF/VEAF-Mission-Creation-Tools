# 05 — Read and lookup actions: one parameter name, the group id, a place that is not an island

Status: ⬜ ready

Files: `veaf_mission_mcp/actions.py`, `veaf_mission_mcp/describe_mission.py`, `veaf_mission_mcp/describe_units.py`, the `terrain_elevation` and `geocode` handlers, tests.

## What happened

- `describe_mission` takes `miz_path` and opens it as a zip (`actions.py:87`): given a mission folder, it dies on `PermissionError`, while every write action takes the folder.
- `describe_units` reports no group id, which `edit_route add_task attack_group` needs (`group_id`); the Marianas OT read it from the mission table.
- `terrain_elevation` takes `theatre`, every other action `mission_path`.
- `geocode` answered « Umatac, Guam » and « Hagåtña, Guam » with the centre of Guam (`osm_type: island`), and « San Jose, Tinian » with the centre of Tinian, with no warning: a village asked, an island given. One zone briefing of the Marianas OT named a starting point that was not there until the review caught it.

## Done when

- `describe_mission` accepts a mission folder (reading `src/mission/`).
- `describe_units` reports each group's `group_id` (and each unit's `unit_id`).
- `terrain_elevation` accepts `mission_path` and reads the theatre from it (`theatre` kept).
- `geocode` warns when the answer is an island, a territory or an administrative area while the query names a smaller place (a comma-qualified name, a village), and says what it found.
- Tests for each.
