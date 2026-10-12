# 01 — add_farp checks its pad: clear ground and slope

Status: ⬜ ready

Files: `veaf_mission_mcp/add_farp.py`, `veaf_libs/clear_ground_placement.py` (reuse), the elevation grid reader behind `terrain_elevation`, `veaf_mission_mcp/actions.py` (description), tests.

## What happened

`add_farp` placed « FARP Merizo » (MarianaIslands, (-22300, -12450)) in the forest and on a slope with no warning beyond « surface not checked: no elevation grid ». It checks only water (`surface_warnings`), while `add_group` puts a stationary group on ground measured clear of trees and buildings when a clear-ground catalogue covers the place.

## Done when

- Where a clear-ground catalogue covers the place, `add_farp` checks the pad's footprint (the pad, and the ammunition dump 120 m east) like `add_group` does: moved to the nearest clear ground within a bound, with a warning saying where, or kept with `keep_position: true` and a warning that it stands in the trees.
- Where the elevation grid covers the place, `add_farp` measures the height range over the pad (centre and a ring at 40 m) and warns above 3 m (the accepted Marianas spot: 2.5 m over 80 m).
- Where neither exists, the warning says what was not checked (trees, slope) and how to check it in game (ticket 03, or `veaf-tools dcs clear-ground-check`).
- Tests: a pad on a slope of the test grid warns; a pad in a catalogued forest moves; `keep_position` keeps it and warns.
