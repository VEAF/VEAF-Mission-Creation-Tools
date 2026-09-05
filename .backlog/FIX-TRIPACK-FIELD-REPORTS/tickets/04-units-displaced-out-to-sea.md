# 04 — ZU-23s of a combat zone come up kilometres out to sea

Status: 🧑 waiting-human

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

So the candidate is **the anchor**, not the radius.

## What was measured (2026-09-05)

`test/lua/test_veafCombatZone_displacement.lua` drives the real path — `VeafCombatZone:initialize` →
`buildGroupElement` → `referencePositionOf` → `spawnElement` → `VeafGroupSpawn:respawn` — with the
five editor coordinates above as the fixture, and asserts on the unit positions handed to
`coalition.addGroup`. No run of DCS was available.

**The defect is real and it is the anchor.** The offset was read from **two different sources**:

| End of the offset | Source | What "unit 1" means there |
|---|---|---|
| `VeafGroupSpawn._drawOrigin` (`data.units[1]`) | the mission record | the unit the **Mission Editor** put first |
| `veafCombatZone.referencePositionOf` | `Group:getUnit(1)` | the first **live** unit; the index shifts as DCS compacts its list |

When the two disagree, the offset becomes the spacing between two different units and every unit of
the group is translated by it. Measured on the real coordinates, before the fix:

| Scenario | Worst displacement |
|---|---|
| Everything alive, units met in editor order (baseline) | ≤ 50 m — the default dispersion, nothing else |
| `AAA-1` lost **before** `initialize` | **1 975.9 m** — the `AAA-1`→`AAA-2` spacing, on all five |
| Live list out of editor order, everything alive | **3 340.4 m** — the `AAA-1`→`AAA-4` spacing, on all five |
| `AAA-1` lost **after** `initialize` | ≤ 50 m — the element holds a position measured once, no re-anchor |
| Five activate/deactivate cycles in a row | ≤ 50 m — no drift, no compounding |
| The zone meeting the units out of order (`plainUnits[1]`) | ≤ 50 m — the anchor never was the unit the zone met |

## What was ruled out

- **The spawn radius.** 50 m, and `veaf.findSpawnPoint` bounds every tier to it — tier 1 explicitly
  distance-tests Disposition's answers, which are not bounded by its radius argument.
- **Compounding across activations.** The element's position is measured once, in `initialize`; a
  later death does not re-anchor it and five cycles produced no drift.
- **`plainUnits[1]`, the first unit the *zone* met.** It only decides the element's coalition. Both
  the anchor and that list come from DCS's own `getUnits()` order, so the documented fallback cannot
  disagree with the primary path.
- **`pairs(groupData.units)` ordering.** The mission's unit table is a clean 1..5 sequence.
- **CTLD.** `CTLDVehicleSpawner` registers this zone's Hawk battery and its Ural-375, not the ZU-23s.

## The fix

`referencePositionOf` now reads the anchor from the **mission record, by name** — the same unit
`_drawOrigin` measures against — so both ends name the same unit and the offset is zero by
construction, whatever DCS's live list looks like. A record whose unit 1 is no longer alive falls
back on that unit's **editor position** (offset zero, the group comes up where it was drawn) instead
of on some other unit, which is the defect itself.

## What is still not established

**Which of the two reproducing scenarios happened in Tripack's mission**, if either. Both require
`Group:getUnit(1)` to differ from the record's `units[1]`, and at mission start, with all five
ZU-23s alive, they should be the same object. The fix removes the whole family rather than a case
that was observed — honest framing: the mechanism is proven, the trigger is not.

An in-game check is queued in `DCS-SESSION-TODO.md`. What would settle it in one line is a `debug`
run of the mission: `spawnElement` traces the declared position and the point found, and
`_drawOrigin` the offset — three numbers that turn the remaining question into arithmetic.

## Definition of done

- [x] The displacement is reproduced, with the numbers that show it
- [x] Its cause is named — two sources for one offset
- [x] Fix, plus a test asserting the **built group's** unit positions — a widely spread group keeps
      its shape and every unit lands where the zone put it
- [x] `stylua --check` clean; `luacheck` crashes on this workstation (Lua version mismatch in the
      luarocks install), so the CI Lua gate is the one that answers for it
- [x] Lua coverage measured at **80.33 %** against a floor of 80 — already inside the ~2-point band,
      so the floor is left where it is rather than bumped onto a 0.33-point margin
- [ ] Confirmed in game against Tripack's mission (see `DCS-SESSION-TODO.md`)
