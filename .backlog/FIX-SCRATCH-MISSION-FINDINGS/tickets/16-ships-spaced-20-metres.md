# 16 — Ships placed 20 m apart

Status: ✅ done (#1000)
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/add_group.py`, tests

## Origin

GermanyCW-v6 rebuild of 2026-09-24: a naval combat zone off Rostock (cargo ships, a tanker, frigates)
made with `create_combat_zone` in category `ship`.

## Measured

`combatZone_Rostock-navires`: 4 ships at x = -16437, -16417, -16397, -16377 — 20 m apart, in a line,
for hulls over 100 m long. They collide as they spawn. Fixed in the mission by hand, through a script
on the Lua table (600 m, staggered).

## Cause

`_build_units` offsets each unit by `len(built) * _UNIT_SPACING_METERS` on `x`
(`add_group.py:374`), with `_UNIT_SPACING_METERS = 20` (`add_group.py:22`). `_build_ship_group` uses
the same builder (`add_group.py:332`), so `add_group` and `create_combat_zone` (which goes through
`insert_group_into_content`, `composites.py:77`) both line ships up at vehicle spacing.

## What it is not

Not a vehicle problem: 20 m is a sensible spacing for a ground column. The fix belongs to the ship
path only.

## Done when

- Ships get a spacing that fits their size (per type if the data is at hand, a safe fixed value
  otherwise), through `add_group` and `create_combat_zone` alike
- Test: a four-ship group has no two units closer than the chosen spacing; vehicles keep 20 m

## Outcome

Ships are placed 600 m apart (`_SHIP_SPACING_METERS`), vehicles keep 20 m. Measured first: over the
89 multi-ship groups of the missions under `D:\dev\_VEAF`, the nearest-neighbour distance has a
median of 1 283 m and a 10th percentile of 277 m; 600 m clears a 300 m hull and is what fixed the
Rostock convoy by hand. Per-type sizes were not at hand (no hull length in `dcsUnits.yaml`).
