# 05 — The build says what a QRA or wave group will do

Status: ⬜ ready

Type: feat

For each DCS aircraft group a QRA or an air wave deploys:

| Route | Message |
|---|---|
| empty: at most one waypoint, carrying nothing but options | none — the normal case, the script completes it |
| present, without air engagement | non-blocking warning: it will be replaced by `zone_defense` |
| engages air | information: used as written |

The rule mirrors `veafAircraftSpawn.routeEngagesAir`; a test reads the Lua table of aircraft target
types and compares it with the Python one, so the two cannot drift.

## Definition of done

- [ ] `mission_builder` function + tests, wired where the build reports declared-group problems
