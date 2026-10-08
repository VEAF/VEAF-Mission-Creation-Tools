# 06 — Objective waypoints sit on the ground

Status: ⬜ ready
Type: feat

## Found

David, 2026-10-08, during the flight: "point de nav au sol ça serait mieux".

`FEAT-CAMPAIGN-OBJECTIVE-WAYPOINTS` gives the players' side one waypoint per objective zone (`POTI`, `KHOBI`, `SENAKI` on mission 1), at 10 000 ft for planes and 500 ft above the ground for helicopters.
Decided by David the same evening: **every** objective waypoint on the ground, planes included — the objective is on the ground, where a targeting pod or a weapon slaved to the steerpoint looks.

## To do

- Write an objective waypoint at the terrain elevation of the zone's centre (the repo already reads terrain elevation, `FEAT-TERRAIN-ELEVATION`), for planes and helicopters alike — no altitude kept for navigation.
- Update the navigation page of the mission briefing if it shows the altitude, the tests and `CAMPAIGN.md` (FR + EN).

## Done when

The objective waypoints of a mission built by `campaign next` sit at the ground elevation of their zone.
