# 03 — A ship at a quay is dragged ashore, then refused

Status: ✅ done

Type: fix

Measured 2026-09-05 on Tripack's `Snowfox_20260903.miz`. This ticket asked a question; the mission
answered it, and the answer is the opposite of what the log suggests.

## The fact

Six groups of three combat zones are never created:

```
VEAF-SPAWNER|E|_drawOrigin|8777: no point within 0m of the requested spot is valid terrain for [CMBT_BANDAR_E_JASK - Cargo Ship]   (also - Navy)
VEAF-SPAWNER|E|_drawOrigin|8777: no point within 0m of the requested spot is valid terrain for [CMBT_HAVADARYA - Submarine]        (also - Navy, - Cargo Ship)
VEAF-SPAWNER|E|_drawOrigin|8777: no point within 0m of the requested spot is valid terrain for [CMBT_RAJAEI - Cargo Ship]
```

All six are `ship` groups — read from the mission table, not assumed: `Dry-cargo ship-2`,
`ALBATROS`, `NEUSTRASH`, `KILO`, `REZKY`. So `terrainForCategory` gives them `veaf.WATER_TERRAIN`,
which accepts `WATER` and `SHALLOW_WATER`, and a hull sitting where the editor drew it passes.

## Why they are refused anyway: the search succeeded

`spawnElement` runs `findSpawnPoint(position, 50)` **before** the spawn, and that function only ever
returns dry land. Two populations follow, and the mission separates them cleanly:

| | Distance to land | `findSpawnPoint` | Result |
|---|---|---|---|
| **12 ships** (`CMBT_SOHAR - Navy`, `CMBT_QESHM_ISLAND - Submarine`, `CMBT_LAVAN_AIRPORT - Speedboat`, …) | > 50 m, out at sea | **fails** — logged, thirteen lines | position kept, `_drawOrigin` accepts water, **they spawn** |
| **6 ships** (the three ports: Bandar-e-Jask, Havadarya, Rajaei) | < 50 m, alongside a quay | **succeeds** — finds the quay | ship moved onto dry land, `_drawOrigin` refuses it, **never created** |

The cross-check is exact: **not one of the six refused groups appears among the thirteen logged
search failures**, and every logged failure belongs to a ship that did spawn. The closest logged
failure to any refused group is 16 km away.

So the refusal is not a terrain-check defect. The point it was handed was genuinely dry — the
search put it there. A ship at anchor in open water is safe precisely because the search could not
find it any land to be dragged onto.

## What fixes it

**Ticket 02.** Once `findSpawnPoint` searches the surfaces the element's category calls for, a hull
is never offered a quay and the refusal disappears. Nothing else is needed for the six groups.

What stays in this ticket is the reason the cause took a mission file to find: `_drawOrigin`'s
error names the radius and the group and **nothing that identifies the mistake** — not the resolved
category, not the surfaces it required, not the surface DCS actually reported at that point. With
those four values the log alone would have said "a ship was asked to stand on `LAND`".

## Definition of done

- [ ] `_drawOrigin`'s refusal names the category, the accepted surfaces, the point, and the surface
      DCS returned there
- [ ] A regression test on the combined path: an element declared on water, land within its spawn
      radius, spawns **on water** — the case that produced these six failures
- [ ] The six groups of `Snowfox_20260903.miz` spawn (verified against the built mission, or in game)
- [ ] `luacheck` + `stylua --check` clean; Lua coverage floor bumped per the ratchet policy
