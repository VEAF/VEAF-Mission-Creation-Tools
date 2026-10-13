# 04 — create_combat_zone: a convoy that starts on the road, at a convoy's speed

Status: ⬜ ready

Files: `veaf_mission_mcp/add_group.py` (`_build_waypoint`, `_DEFAULT_SPEED_MPS`), `veaf_mission_mcp/composites.py`, tests.

## What happened

Report finding 11 (already seen on the Sinai OT, its entry 13): `create_combat_zone` writes a convoy's first point `Off Road` and every point at 5.6 m/s (`_DEFAULT_SPEED_MPS`, 20 km/h).
`_build_waypoint` makes the first point `Off Road` for every ground group, a convoy included, and that start may be anywhere: the convoy crosses the country to reach its first road.

## Done when

- Measure first what the editor writes for a road convoy (first point `On Road`? speed?) in the missions under `test/`, before changing a constant: nothing here is decided from the report alone.
- A convoy's start is `On Road` when its route follows the roads, at the speed measured; a start that is not on a road is a warning.
- Tests on the waypoint action and the speed.
