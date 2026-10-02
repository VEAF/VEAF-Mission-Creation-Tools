# 04 — Placement checks the surface where the elevation grid exists

Status: ⬜ ready

Files: `veaf_mission_mcp/add_group.py`, `veaf_mission_mcp/set_group_properties.py`, `veaf_mission_mcp/add_farp.py`,
`veaf_mission_mcp/composites.py` (`create_combat_zone`), `veaf_libs/terrain_elevation.py` (read side), tests.

## What happened

An Avenger battery was placed at Paphos at 0 m — in the sea — by `add_group`, with no warning; the
`terrain_elevation` action, asked afterwards, said 0 m. `set_group_properties` warns "DCS terrain is not
available design-time (land.getSurfaceType is a runtime API)" on every move, which is no longer true where
`grid_for_theatre` has a grid (Syria, swept 2026-10-01).

## Done when

- Where the theatre has a grid, a ground unit (vehicle, static, FARP) whose position reads 0 m gets a
  warning naming it and the height, and so does a ship whose position reads above 0 m. Where there is no
  grid the warning says so ("not checked: no elevation grid for <theatre>").
- The known limitation `dcs-ground-is-never-below-sea-level` is respected: 3 m is land, only 0 is sea.
- Tests on a small synthetic grid.
