# 08 — Settle each ground unit to the nearest scenery-free point

Status: ✅ done
Type: fix

## Problem

`findSpawnPoint` places the **group centre** clear of scenery, but `veafUnits.placeGroup` then
spreads individual units around that centre without consulting the scenery. Measured 2026-09-25:
53/184 zone groups had at least one unit in trees or water -- including batteries where the group
centre was on clear ground but a single offset vehicle landed inside a forest.

Three per-unit loops exist in the codebase; none of them recalculate scenery:
- `veafSpawnGround._createDcsUnits` (~l.333)
- `veafSpawnCore.doSpawnGroup` (~l.738)
- `veafCasMission.placeGroup` (~l.1095)

## What this ticket does

New function `veafUnits.settlePosition(spawnPosition, unit)`:
- No-op for air and naval units.
- If `Disposition` is unavailable, returns `spawnPosition` unchanged.
- Tries anneaux of 10, 25, 50 m with 5 m clearance, one `Disposition.getSimpleZones` call each.
- Returns the **closest acceptable candidate within the anneau** (on `veaf.DRIVABLE_TERRAIN`).
- If nothing found, returns `spawnPosition` unchanged (existing behaviour, logged at trace).

David's arbitration 2026-09-25: **recalculate all units (option a)**, not just those that would
fail the probe.

The function is called in all three per-unit loops, immediately before the
`checkPositionForUnit` / `validateSpawnPosition` test. The existing test still runs on the settled
position, catching naval placements on dry land etc.

## Definition of done

- [ ] `veafUnits.settlePosition` defined, documented, no-op for air/naval/no-Disposition
- [ ] Called in `_createDcsUnits`, `doSpawnGroup` and `veafCasMission.placeGroup` before the
      terrain check
- [ ] Tests: ground unit near trees -> nudged; air/naval unit -> unchanged; Disposition unavailable ->
      unchanged; no candidate in range -> unchanged
- [ ] `stylua --check` and `luacheck` clean
