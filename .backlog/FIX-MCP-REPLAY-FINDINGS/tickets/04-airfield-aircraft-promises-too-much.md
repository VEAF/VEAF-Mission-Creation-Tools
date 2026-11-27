# 04 — `list_airfield_aircraft` promises every type on every base

Status: ✅ done
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/airfield_aircraft.py`, its entry in `actions.py`, `doc/mission-maker/AI_ASSISTANT_CATALOG.md` and `.en.md`, `doc/developer/mission-editing-mcp.md` and `.en.md`, tests

Found by the review of PR #1357 after its merge (2026-11-27), fixed with David's go.

1. The action's description and the catalogue pages said the build stocks every base with all the types listed. The build does so only for a base of its side with no `aircrafts:` list in `src/warehouses.yaml` (`warehouses_injector_worker.py`, `_apply_to_warehouse`): such a list replaces the catalogue. The wording now says so, and that the action does not read that file.
2. A neutral airfield answered both sides' types next to "The build stocks every one of them by default"; measured on Beslan: `owner: neutral`, two sides, 4 218 characters. A neutral airfield offers no dynamic slot. The answer now carries a `note` saying so and naming `set_airbase_coalition`, and the description no longer promises the types.

Not done, for David to decide: have the action read the folder's `src/warehouses.yaml` and answer the list the build will really stock (`airports:` selection, `exclude_airports:`, `defaults.aircrafts` and per-base overrides). That is the build's own selection logic to share, more than a wording fix. Until then the gap is the known limitation `airfield-aircraft-ignores-warehouses-yaml` (`known-limitations.yaml`, served by `describe_known_limitations`).
