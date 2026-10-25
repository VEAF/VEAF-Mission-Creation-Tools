# 11 — `set_route`: write a flight plan in one action

Status: ✅ done

The assistant wrote the route by replacing the template's example points in `src/waypoints.yaml` with `edit_mission_file`: a 2 kB search-and-replace, the altitudes computed by hand from `terrain_elevation`, the plan edited in a second call, and the same-named points of ticket 02.
Trakdah's assistant proposed an action that takes a list of points and writes the plan.

`set_route(mission_path, plan, points, applies_to)`:

- `points`: ordered, each with a `name` and a position (x/y, lat/lon, or a geocode-style place + bearing + distance, resolved like `resolve_coordinates`), optional `speed_kt`;
- every point's altitude set to the ground under it from the theatre's grid (`alt_type: BARO`), as the guide asks — the flight altitude stays in the briefing; no grid → refused with the reason, or `alt: 0` with a warning (choose and say which);
- names unique within the plan, refused otherwise (ticket 02);
- `applies_to`: the plan's selector (coalition, category, type), defaulting to the blue planes;
- writes the points and the plan in `waypoints.yaml`, comments of the rest of the file preserved, backed up first like `edit_mission_file`; replaces a plan of the same name;
- returns, per leg, heading and distance, so the briefing and the F10 labels are written from it.

Done when: the action exists with its tests, its entry in the catalogue page (FR and EN, MCP action catalogue lockstep), and the objective prompt uses it instead of `edit_mission_file` for the route.

## Result

`set_route` takes points as x/y or lat/lon; a place name goes through `geocode` first, as everywhere else, rather than a second geocoder inside this action. With no elevation grid the points are written at sea level, with a warning.
Found while writing it: a plan without an aircraft type ties with the template's `all_blue_planes`, declared first, which then wins (`get_flight_plan_for`). `set_route` names any plan that would win over the one it wrote.
Tests: `test_set_route.py`. The catalogue page (FR and EN) and `mission-editing-mcp` list it; the objective prompt uses it.
