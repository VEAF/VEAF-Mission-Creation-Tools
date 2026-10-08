# FEAT-CAMPAIGN-OBJECTIVE-WAYPOINTS — a campaign mission's flight plans carry its objectives, not the shipped example

Status: ⬜ ready

## Found

David, 2026-10-08, before flying *Kolkhida* mission 1: "par contre on a des waypoints chargés dans les appareils pour la mission ?".

The mission folder `campaign next` created carried the shipped example `src/waypoints.yaml`, copied from the campaign's template: every blue plane got `HOLDING_POINT` and `INITIAL_POINT` at x 75 869 / y 48 674 and x 70 000 / y 50 000 — nowhere near the Colchis plain — plus the automatic `BULLSEYE`, the only right one. The build said "Waypoints injectés dans 130 groupes d'aéronefs" and nothing looked wrong. Mission 1 was fixed by hand: `POTI`, `KHOBI`, `SENAKI` (the zones' centres, read in the running mission) at 10 000 ft for the blue planes and 500 ft AGL for the blue helicopters, in the order of the briefing's priorities.

On the way: a flight plan in `waypoints.yaml` takes its waypoints by **key** (`waypoints_manager.py`, `plan_data["waypoints"].keys()`); the value is never read, while the shipped example writes `HOLDING_POINT: "HOLDING_POINT"` as if it were a mapping. A plan written `POTI: "POTI_LOW"` silently gets `POTI`.

## What the lot would do

- `campaign next` writes the mission's `src/waypoints.yaml` from the campaign: one waypoint per zone the mission's tasks name (or the campaign's objectives), at the zone's centre, in the order of the tasks, for the players' side — planes at a cruise altitude, helicopters low — instead of copying the template's file. A second `campaign next` keeps a file edited since, like the rest of the mission folder.
- The shipped `waypoints.yaml` example and its doc say what a plan's value is (or the loader reads it, if a rename was meant).
- Tests, doc (`CAMPAIGN.md`, the waypoints page) FR + EN.

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-objective-waypoints.md) | `campaign next` writes the objectives as waypoints; the plan's key/value said plainly | ⬜ |
| [02](tickets/02-navigation-page.md) | The mission briefing shows the flight plan | ⬜ |
