# FIX-AIR-SPAWN-ALTITUDE-GUARD — the aircraft height check reads the easting, not the altitude

Status: ⬜ ready

Found 2026-09-01 while delivering [`CHORE-ONE-TERRAIN-CHECK`](../CHORE-ONE-TERRAIN-CHECK/PRD.md), and
**deliberately left out of it**: that lot is forbidden from moving any spawn answer, and fixing this
moves some. Its finding 5 carries the analysis; this lot carries the repair.

## The defect

`veafUnits.checkPositionForUnit` reads the same field two ways, twenty-two lines apart:

```lua
390:  local vec2 = { x = spawnPosition.x, y = spawnPosition.z }   -- z is the EASTING here
...
412:  if spawnPosition.z <= 10 then -- if lower than 10m don't spawn unit
```

Line 390 converts a runtime vec3 to a mission-table vec2, so `z` is the **easting** — correct, and the
whole surface query depends on it. Line 412 then tests the same `z` as an **altitude**.

Every caller hands in a `veaf.placePointOnLand` result, whose height is in `y`; `veafSpawnAircraft`
writes `spawnSpot.y = alt` immediately before calling. So *"an aircraft will not spawn below 10 m"*
actually tests **whether the spawn point is more than 10 m east of the theatre's origin** — which is
true for essentially every position on every map.

Nothing raises an error either way, which is the standing hazard of
[`docs/agents/dcs-coordinates.md`](../../docs/agents/dcs-coordinates.md): both readings are plausible
numbers under plausible names.

## What it means in practice

The guard has never rejected anything. An aircraft asked to spawn at ground level, or below it, is
placed — and the check that exists to stop that has been answering a question about longitude since it
was written.

Whether that has ever produced a visible symptom is **unknown and worth establishing before choosing
how to fix it**: DCS may clamp a too-low aircraft on its own, in which case this is a dead guard rather
than a live defect. That changes what the repair should do, not whether the line is wrong.

## Definition of done

- [ ] The height test reads the altitude, whatever field the callers actually put it in — established
      from the callers, not assumed
- [ ] A test drives a position **low in altitude but far east**, and another **high in altitude but at
      easting 0**: those two cases separate the correct reading from the current one, and no test that
      passes both readings is worth having
- [ ] The behaviour change is stated in `CHANGELOG.md` if any spawn moves, the way
      `FIX-WAVE-OFFSET-AXES` did — a mission relying on the guard never firing is a mission that
      changes
- [ ] The test pinning today's behaviour, added by `CHORE-ONE-TERRAIN-CHECK` so the refactor could
      prove it changed nothing, is updated rather than deleted: it is the record of what was wrong
- [ ] `poetry run test-lua`, `stylua --check src/scripts/veaf/ test/lua/`, `luacheck` clean

## Worth checking in the same pass

Whether other height tests in the spawn path read the same field. The easting/altitude confusion has
now been found **three times in three days** — `FIX-AIRWAVES-COMMAND-EASTING` (the position handed to
the interpreter), `FIX-WAVE-OFFSET-AXES` (the two offset deltas), and this one. Enumerate rather than
sample: that is what turned the first of those from one site into two.

## Out of scope

- The rest of `checkPositionForUnit`. Its naval/ground rules were verified correct by
  `CHORE-ONE-TERRAIN-CHECK` and are covered by its tests.
