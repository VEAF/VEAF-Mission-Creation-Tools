# 01 — Pin today's answer at all six sites, before anything is rerouted

Status: ✅ done — 2026-09-01. 24 assertions across four suites, all green against the **unchanged**
code, then still green after the rerouting.
Type: test

The lot's own prohibition — *"a unification that shifts one surface decision by one case is
indistinguishable from a bug"* — is only enforceable if the current answers are written down first.
So this ticket comes before any code change, and its tests are expected to pass **immediately**.

## What each site is asked

Enumerated from `land.SurfaceType` rather than sampled, one row per surface DCS can report. The
repository has already paid for the sampled version: thirteen hand-picked cases once supported the
claim that a whole family of crashes was fixed while three remained.

| Site | Suite | What the sweep pins |
|---|---|---|
| `veafUnits.checkPositionForUnit` | `test_veafUnits.lua` | ground / naval / offshore-static / non-naval-static / aircraft, each against all five surfaces |
| `acceptableGroundPoint` (via `veaf.findSpawnPoint`) | `test_veaf.lua` | four surfaces are acceptable ground, `WATER` alone is not |
| `veaf.resolveCsarSurvivorPoint` | `test_veaf.lua` | only `WATER` sends the survivor search out |
| `veaf.findPointInZone` | `test_veaf.lua` | **had no test at all**: ship → `WATER`, otherwise `LAND`/`ROAD`/`RUNWAY`, plus the widening and the 1000-draw bound |
| `veafSanctuary:deployDefenses` | `test_veafSanctuary.lua` | water → ships, land/road/runway → SAMs, on both waves |
| `veafDcsSpawner.isTerrainValid` | `test_veafDcsSpawner.lua` | the full 5×5 truth table |

## The one case that separates the two directions

`SHALLOW_WATER`. It is **dry** for a ground unit, for the spawn search and for a downed pilot
(FIX-CSAR-SPAWNS-ON-WATER: *"a survivor wading a few metres off a beach is rescuable"*), and it is
**not water enough** for a naval unit or for a ship in `findPointInZone`. The two directions are not
each other's mirror image, so a single "wet" list would have flipped one of them silently. That is
exactly what the sweeps refuse.

## Proof the tests can fail

Sabotaging the shared predicate afterwards, one change at a time:

| Sabotage | Suites that went red |
|---|---|
| `== actual` → `~= actual` in the match loop | all six sites, 39 tests |
| `point.z or point.y` → `point.y or point.z` (the coordinate trap) | the two sites that assert which spot is asked about |
| `veaf.OPEN_WATER` gains `SHALLOW_WATER` | the four sites that treat shallow water as dry |
| `veaf.DRIVABLE_TERRAIN` loses `RUNWAY` | `findPointInZone` and `terrainForCategory` |
