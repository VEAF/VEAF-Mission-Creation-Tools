# 07 — MCP gaps the demo had to script around

Status: ✅ done
Type: feat (MCP actions)
Files: `veaf_mission_mcp` actions (`edit_route`, `describe_map`, `add_group` clear-ground sizing, new composites), tests

Each gap below cost the demo a script or a hand edit; each fix removes one.

| Gap | What the demo did instead |
|---|---|
| `edit_route` has no `On Road` (nor `Off Road`) waypoint type: a combat-zone convoy drives straight across fields | `tools/fix_convoy_on_road.py` (`load_folder_mission` / `save_folder_mission`) |
| No composite for a combat **operation** (`type: operation`, `tasking_orders`, `dependencies`, its trigger zone) | written by hand in `mission.yaml` + `add_trigger_zone` |
| No action for **briefing pictures** (`pictureFileNameB/N/R`, `mapResource`); `save_folder_mission` does not rewrite `mapResource` (same as the Caucasus Open Training, its finding n° 7) | `tools/gen_map.py`, `declare()` |
| `describe_map` gives zone positions but not group positions | `tools/dcslua.py` reads `src/mission/mission` |
| Clear-ground placement sizes a `#veafInterpreter["-sa11, …"]` carrier as **one vehicle** (« 0 m of clear ground needed for 1 vehicle »), while `#command` carriers are sized from their command | nothing; the SA-11 site (9 × 9 cells) to be checked in DCS |

## Done when

Each row has its action or option, a test, and the skill (`veaf-mission-authoring`) mentions it.
