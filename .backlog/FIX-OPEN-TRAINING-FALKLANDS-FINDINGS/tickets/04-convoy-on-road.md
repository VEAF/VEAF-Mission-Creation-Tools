# 04 — create_combat_zone: a convoy that starts on the road, at a convoy's speed

Status: ✅ done

Files: `veaf_mission_mcp/add_group.py` (`_build_waypoint`, `_DEFAULT_SPEED_MPS`), `veaf_mission_mcp/composites.py`, tests.

## What happened

Report finding 11 (already seen on the Sinai OT, its entry 13): `create_combat_zone` writes a convoy's first point `Off Road` and every point at 5.6 m/s (`_DEFAULT_SPEED_MPS`, 20 km/h).
`_build_waypoint` makes the first point `Off Road` for every ground group, a convoy included, and that start may be anywhere: the convoy crosses the country to reach its first road.

## Done when

- Measure first what the editor writes for a road convoy (first point `On Road`? speed?) in the missions under `test/`, before changing a constant: nothing here is decided from the report alone.
- A convoy's start is `On Road` when its route follows the roads, at the speed measured; a start that is not on a road is a warning.
- Tests on the waypoint action and the speed.

## Done

Measured first, 2026-10-13, over the 126 vehicle groups of 14 editor-built missions under `D:\dev\_VEAF` whose route has an `On Road` leg: the first point is `On Road` in 85 and `Off Road` in 37; the legs' speed has a median of 16.4 m/s (59 km/h), and 5.6 m/s is 11 % of them.
A ground route with two points or more now starts `On Road` and runs at 16.4 m/s (`_ROAD_SPEED_MPS` in `add_group.py`), for `add_group` and `create_combat_zone` alike; a point may carry its own `speed` (m/s), now in both schemas. A single stationary point stays `Off Road`; a ship keeps its `Turning Point` and its 5.6 m/s; the first point keeps the start speed.
**Not done: « a start that is not on a road is a warning »** — no file holds the roads, only the game does (`land.findPathOnRoads`); it goes with ticket 06.
