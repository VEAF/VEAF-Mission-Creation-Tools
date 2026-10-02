# 05 — The build says what a QRA or wave group will do

Status: ✅ done

Type: feat

For each DCS aircraft group tasked `CAP` or `Intercept` that a QRA or an air wave deploys:

| Route | Message |
|---|---|
| empty: at most one waypoint, carrying nothing but options | information: it is given `zone_defense` — the Sayqal case, which nothing in the editor shows (David, 2026-10-02: "c'est justement l'origine de ce lot") |
| present, without air engagement | non-blocking warning: it will be replaced by `zone_defense` |
| engages air | information: used as written |

Any other task flies its route and is not reported. The rule mirrors `veafAircraftSpawn.routeEngagesAir`
and `needsZoneDefense`; a test reads the Lua tables (air target types, engagement task ids, zone-defense
tasks) and compares them with the Python ones, so the two cannot drift.

The build reports it on its own (`report_deployed_aircraft_routes`), not under the "missing mission.yaml
references" summary; `veaf-tools validate` carries the warning too.

## Definition of done

- [x] `mission_builder/aircraft_roles.py` + tests, wired into the build and `validate`
