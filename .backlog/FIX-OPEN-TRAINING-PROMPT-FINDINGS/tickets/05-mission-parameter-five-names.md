# 05 — The mission is named by five different parameters across the catalogue

Status: ⬜ ready
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/catalog.py` and the action schemas, tests, AI
catalogue doc

## Origin

`FIX-SCRATCH-MISSION-FINDINGS` ticket 19 (point 7) made a misnamed parameter answer with the
expected names instead of a bare error. It left the names themselves alone. GermanyCW-v6,
2026-09-28: running actions in batches, four calls failed on the name alone (`geocode` and
`resolve_coordinates` given `miz_path`, `set_briefing` given `mission_path`, `describe_module`
given `mission_path` and `module`), each costing a retry.

## Measured

On `develop` at `8bc1a1fe`, 42 of the 47 actions take the mission, under five names:

| Name | Actions |
|---|---|
| `miz_path` | 17 (`describe_units`, `edit_route`, `add_map_drawing`, `set_unit_properties`, …) |
| `target` | 9 (`add_group`, `add_air_group`, `set_briefing`, `set_bullseye`, …) |
| `mission_yaml_path` | 6 (`set_mission_module`, `describe_module`, …) |
| `folder_path` | 6 (`validate_mission`, `build_mission`, `create_qra`, …) |
| `mission_path` | 4 (`geocode`, `resolve_coordinates`, `describe_map`, `list_airfields`) |

Most of them accept the same thing (a mission folder or a `.miz`); only `mission_yaml_path` names a
different file.

## Done when

- One name for "the mission folder or `.miz`" across the catalogue; the old names accepted as
  aliases, so no caller breaks.
- `mission_yaml_path` either kept (it is a different file) or derived from the folder, decided and
  written.
- A catalogue test that fails when a new action introduces another name.
