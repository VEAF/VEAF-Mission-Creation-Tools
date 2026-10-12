# 01 — create_qra: no automatic EngageTargets on an interceptor

Status: ⬜ ready

Files: `veaf_mission_mcp/composites.py` (`create_qra`), `veaf_mission_mcp/add_air_group.py` (`_cap_engage_task`, line 418), `veaf_mission_mcp/actions.py` (description), tests.

## What happened

`create_qra` passes each group's `task` to `insert_air_group_into_content` (`composites.py`, `task=spec.get("task", "Intercept")`).
With `task: "CAP"`, `insert_air_group_into_content` adds the Mission Editor's automatic `EngageTargets` (`_cap_engage_task`, `auto = true`) to the group's single waypoint.
The build then classes the group `ROUTE_ENGAGES_AIR` (`mission_builder/aircraft_roles.py`) and flies the route as written, instead of giving it the `zone_defense` role: one waypoint, no orbit, so the flight lands at the nearest airfield (known limitation `aircraft-at-the-end-of-its-route-lands`).
Seen on the Marianas OT: twelve build lines « Le groupe QRA … engage les aéronefs par sa propre route : elle est suivie telle quelle », for groups the action's own description says get « no task on purpose ».
Worked around with `edit_route clear_tasks` on the twelve groups; the build then said `zone_defense` for each.

## Done when

- A QRA group built by `create_qra` carries no task on its waypoint, whatever its `task` (`CAP` or `Intercept`), so the build gives it the `zone_defense` role.
- Or, if a CAP group with an engage task must stay possible, `create_qra` warns that such a group flies its route as written; pick one and say which in the description.
- Tests: a QRA group created with `task: "CAP"` is classed `ROUTE_ZONE_DEFENSE` by `find_deployed_aircraft_routes`.
