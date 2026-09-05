# 04 — ZU-23s of a combat zone come up kilometres out to sea

Status: ⬜ ready

Type: fix

Re-scoped 2026-09-05 against Tripack's `Snowfox_20260903.miz`. The cause is still not identified,
but the mission overturned the reasoning that had ruled out the obvious family of mechanisms.

## The report

*"le déplacement automatique des unités CZ est un peu buggé"*, with the F10 map showing several
ZU-23s correctly on Abu Musa island and **two standing in open water** to the south-west, while the
Mission Editor has them all ashore.

## What the mission says

The zone is `CMBT_ABU_MUSA_AIRPORT`, centre `(-31532.5, -121253.0)`, radius 4876 m, **no
`#spawnradius=` tag** — so the default applies, and the log shows it resolving to 50 m.

Its ZU-23s are one single group of five, and Tripack spread them right around the island:

| Unit | x (northing) | y (easting) | Distance to unit 1 |
|---|---|---|---|
| `- AAA-1` | -30382.9 | -122247.2 | — |
| `- AAA-2` | -29154.8 | -120699.3 | 1 976 m |
| `- AAA-3` | -31826.8 | -119503.7 | 2 267 m |
| `- AAA-4` | -33555.6 | -121202.2 | **3 340 m** |
| `- AAA-5` | -32818.9 | -123007.7 | 2 660 m |

Overall span, `AAA-2` to `AAA-5`: **4 330 m**. All five sit inside the trigger zone, so none of them
is filtered out of it.

## Why that changes the reasoning

This ticket previously ruled out every displacement mechanism on the grounds that a 50 m spawn radius
cannot produce a kilometre. That argument was about the **radius**, and it is still true. But the
spawn translates the *whole group* by one offset measured against its first unit
([`veafDcsSpawner.lua:1008`](../../../src/scripts/veaf/veafDcsSpawner.lua)), and this group is
4.3 km wide. Any mechanism that anchors on the wrong unit therefore moves every ZU-23 by kilometres —
which is exactly the observed magnitude, and exactly the trap `referencePositionOf`'s own docstring
describes for a group straddling a zone edge.

So the candidate is **the anchor**, not the radius. Three readings, none of them conclusive:

1. `referencePositionOf` anchors on `Group.getByName(name):getUnit(1)` — the first **live** unit. With
   `AAA-1` destroyed it returns `AAA-2`, 1 976 m away. But zone elements are built once, in
   `VeafCombatZone:initialize` via `AddZone`, so a later loss should not re-anchor. *Should* — this is
   read, not measured.
2. The record's `units` order comes from `pairs(groupData.units)`
   ([`veafMissionDb.lua:201`](../../../src/scripts/veaf/veafMissionDb.lua)). The mission's table is a
   clean sequence here, so `pairs` walks it in order — but a group with a hole in its unit table would
   fall into the hash part, and the order would then be arbitrary.
3. Ruled out: CTLD. `CTLDVehicleSpawner` registers this zone's `Hawk` battery and its `Ural-375`, and
   **not** the ZU-23s, so it is not moving them.

## What is needed

A `debug` run: `VeafCombatZone:spawnElement` traces the declared position, the radius and the point
found, and `_drawOrigin` the offset. Those three numbers turn this into arithmetic. Failing that,
reproduce here — a zone whose group is deliberately spread over kilometres, activated repeatedly,
with units killed between activations to exercise reading 1.

## Definition of done

- [ ] The displacement is reproduced, with the numbers that show it
- [ ] Its cause is named
- [ ] Fix, plus a test asserting the **built group's** unit positions — a widely spread group keeps
      its shape and every unit lands where the zone put it
- [ ] `luacheck` + `stylua --check` clean; Lua coverage floor bumped per the ratchet policy
