# 03 — `veafSanctuary` stops comparing raw surface numbers

Status: ✅ done — 2026-09-01. Proven by a test that fails while the numbers are literal.
Type: fix

The one entry of the six that was a latent defect rather than a duplication.

## What it was

```lua
local surfaceType = land.getSurfaceType(veaf.makeVec2(position))
if surfaceType == 2 or surfaceType == 3 then
  -- this is water
```

Twice, once per defence wave. Right today — 2 and 3 are what `land.SurfaceType` gives
`SHALLOW_WATER` and `WATER` — and right for a reason nothing in the repository holds. `land.SurfaceType`
is DCS's table. Renumber it upstream and a sanctuary answers a speedboat with a Patriot: the branch
still runs, the aliases still resolve, the groups still spawn, and nothing raises.

The comment beside it said *"this is water"* instead of naming the constants, which is the tell.

## What it is now

One `isOverWater`, computed from `veaf.isTerrainValid(veaf.makeVec2(position), veaf.WATER_TERRAIN)` and
reused by both waves. The trace line reports the verdict rather than the number.

Note that `veaf.WATER_TERRAIN` includes `SHALLOW_WATER`, so this site does **not** share the
shallow-water-is-dry decision of the CSAR and ground-spawn sites — contrary to the PRD's reading that
five of the six answer "not water". Its verdict is unchanged: shallow water gets ships, as it did.

## The test that could not pass before

`TestSanctuaryDeployDefensesSurface.test_the_choice_survives_a_renumbering_of_land_SurfaceType`
replaces `land.SurfaceType` with `{ LAND = 11, SHALLOW_WATER = 12, WATER = 13, ROAD = 14, RUNWAY = 15 }`
and asks the same three questions. It was written before the fix and observed red — a renumbered
`WATER` produced `{ "-roland", "-roland" }`, the Patriot at sea, exactly the failure described above.

The two sibling tests (`WATER`/`SHALLOW_WATER` → ships, `LAND`/`ROAD`/`RUNWAY` → SAMs, on both waves)
were green before and after: naming the constants changed the code's exposure, not its answer.
