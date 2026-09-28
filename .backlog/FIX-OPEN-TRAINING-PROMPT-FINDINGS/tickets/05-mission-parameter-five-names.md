# 05 — The mission is named by five different parameters across the catalogue

Status: ✅ done
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

## Done — 2026-09-28

- **One name: `mission_path`.** The catalogue publishes it for every action that took `miz_path`,
  `target` or `folder_path`, and translates it back to the handler's own key at `run_action`, so no
  handler changed; the three former names stay accepted as aliases, and two different values under
  two names are refused.
- **`mission_yaml_path` is kept** — it names a different file — but a `mission_path` given in its
  place is read as the folder's `mission.yaml`, which is the `describe_module` failure the report met.
- `test_catalog.py::test_no_shipped_action_introduces_another_name_for_the_mission` fails on a sixth
  name. Developer doc updated (FR/EN).
