# 07 — MarianaIslands terrain data, and a placement warning that says what was not checked

Status: ⬜ ready

Files: `veaf_libs/data/` (elevation grid, parking, clear-ground catalogue for MarianaIslands), `veaf_mission_mcp/add_group.py` and the placement warnings, `known-limitations.yaml`, the Open Training prompt.

The sweeps need DCS: they are David's; the rest is code.

## What happened

- MarianaIslands has no elevation grid (`terrain_elevation`: `available: false`), no parking data (limitation `no-parking-data-outside-three-theatres`) and no clear-ground catalogue. Every placement said only « surface not checked: no elevation grid for MarianaIslands ».
- The mission checked land and sea itself against OpenStreetMap island outlines (`tools/coastlines.py`). That was not enough: probed in DCS on 2026-10-12 (`Disposition.getSimpleZones` small query, `land.getSurfaceType`), **57 of 97 vehicles stood in forest or buildings and one in the water** (a coastline OSM and DCS draw differently). A ring search with the small query then found a free spot for 51 of them at a median 100 m, and the convoys were snapped to `land.getClosestPointOnRoads`.
- Farallon de Medinilla reads surface type 5 (`RUNWAY`) in DCS and offered no free spot within 1 500 m: no battery can stand there.
- With no parking data, every QRA starts in the air at the centre of its circle.

## Done when

- The MarianaIslands elevation grid, parking data and clear-ground catalogue are swept (`veaf-tools dcs terrain-sweep MarianaIslands`, `capture-map --parking`, `clear-ground-sweep`) and shipped.
- The placement warning on a theatre without a grid or a catalogue says what was NOT checked (water, forest) and how to check it (`veaf-tools dcs clear-ground-check` on the built mission), instead of « surface not checked » alone.
- `known-limitations.yaml` gets the Farallon de Medinilla surface (an island DCS models as runway) if the sweep confirms it.
- The Marianas OT `tools/probe_clear.py` (ring search with the small query, road snap for convoys) is considered for `clear-ground-check --fix`: it is the measured way to move what stands in the trees.
