# 02 — One predicate, in `veaf.lua`, and five sites routed through it

Status: ✅ done — 2026-09-01. `land.getSurfaceType` now appears once in `src/scripts/veaf/`.
Type: refactor

## Where it had to live, and why not where the PRD said

The PRD names the predicate `veaf.isTerrainValid`, and that name **already existed** — as a façade
assignment at the bottom of `veafDcsSpawner.lua`, pointing at the ported body. Unusable from three of
the six sites: `acceptableGroundPoint`, `findPointInZone` and `resolveCsarSurvivorPoint` all live in
`veaf.lua`, which loads first, and `test_veaf.lua` loads nothing else.

So the body moved into `veaf.lua`, unchanged, and `veafDcsSpawner.isTerrainValid` became the borrowed
name rather than the owner. The façade line was removed, since the function is no longer somebody
else's to lend.

## The three named lists

Written once, beside the predicate, each with the reason it has the shape it has:

| Constant | Surfaces | Used by |
|---|---|---|
| `veaf.OPEN_WATER` | `WATER` | `acceptableGroundPoint`, `resolveCsarSurvivorPoint`, `checkPositionForUnit`, `findPointInZone` (ship) |
| `veaf.WATER_TERRAIN` | `SHALLOW_WATER`, `WATER` | `veafSanctuary`, `veafDcsSpawner.TERRAIN_BY_CATEGORY.ship` |
| `veaf.DRIVABLE_TERRAIN` | `LAND`, `ROAD`, `RUNWAY` | `findPointInZone` (ground), `TERRAIN_BY_CATEGORY.vehicle` and `.ground_unit` |

`OPEN_WATER` is asked **negatively** at the three "not water" sites — `not veaf.isTerrainValid(p,
veaf.OPEN_WATER)` — rather than as a positive list of the four dry surfaces. Not a stylistic choice:
`~= WATER` accepts a surface value the enumeration does not know, and a positive list rejects it. The
two forms differ only for a value DCS does not document today, which is precisely the kind of
one-case shift the PRD forbids.

## `checkPositionForUnit` keeps everything it had

Its signature, its unit-based rule and its callers are untouched. It stops reading the surface itself
and asks the predicate once, keeping the single query it always made and its trace line.

## `findPointInZone` does **not** call `terrainForCategory`

The PRD's plan for this site would have changed a spawn. `veafDcsSpawner.terrainForCategory("ship")`
answers `{ SHALLOW_WATER, WATER }`, while `findPointInZone` accepts `WATER` alone for a ship — so
routing it through that helper would have let a ship draw a shallow-water point that is refused today.
Its ground half genuinely is the shared list and now uses it; its ship half keeps `veaf.OPEN_WATER`.
