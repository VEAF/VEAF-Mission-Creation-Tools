# FIX-AIR-SPAWN-ALTITUDE-GUARD — the aircraft height check reads the easting, not the altitude

Status: 🧑 waiting-human — the read is fixed and shipped (ticket 01); the **clearance** rule needs DCS
to answer whether the game lifts a too-low aircraft by itself (ticket 02, `DCS-SESSION-TODO.md` R9).

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

## Scope

| # | Ticket | Risk | Status |
|---|---|---|---|
| 01 | The height test reads the altitude, and two cases prove which field it read | medium — it makes a dead guard live, so a spawn can now be refused that used to be accepted | ✅ |
| 02 | Does DCS lift a too-low aircraft on its own? The clearance rule depends on the answer | none — a question, no code | 🧑 |

## Definition of done

- [x] The height test reads the altitude, whatever field the callers actually put it in — established
      from the callers, not assumed
- [x] A test drives a position **low in altitude but far east**, and another **high in altitude but at
      easting 0**: those two cases separate the correct reading from the current one, and no test that
      passes both readings is worth having
- [x] The behaviour change is stated in `CHANGELOG.md` if any spawn moves, the way
      `FIX-WAVE-OFFSET-AXES` did — a mission relying on the guard never firing is a mission that
      changes
- [x] The test pinning today's behaviour, added by `CHORE-ONE-TERRAIN-CHECK` so the refactor could
      prove it changed nothing, is updated rather than deleted: it is the record of what was wrong
- [x] `poetry run test-lua`, `stylua --check src/scripts/veaf/ test/lua/` clean; `luacheck` left to CI
      (no Windows binary on this machine)

## Worth checking in the same pass

Whether other height tests in the spawn path read the same field. The easting/altitude confusion has
now been found **three times in three days** — `FIX-AIRWAVES-COMMAND-EASTING` (the position handed to
the interpreter), `FIX-WAVE-OFFSET-AXES` (the two offset deltas), and this one. Enumerate rather than
sample: that is what turned the first of those from one site into two.

## Out of scope

- The rest of `checkPositionForUnit`. Its naval/ground rules were verified correct by
  `CHORE-ONE-TERRAIN-CHECK` and are covered by its tests.

## What implementation found that this document did not say

**1. The enumeration answered: one other height test on the spawn path, and it is correct.** Every
comparison of a `y`, `z`, `alt` or `altitude` field in `src/scripts/veaf/` was listed, not sampled.
`VeafGroupSpawn:_altitudeFor` (`veafDcsSpawner.lua:912`) tests `self.point.y > ground +
MINIMUM_CLEARANCE_METRES`, which is the same rule as this one, read the right way round — and rather
than refusing, it lifts the aircraft into an altitude band. `veafGeo.pointInPolygon`'s altitude ceiling
also reads `y`, through `veaf.makeVec3`. Nothing else on the path compares a height at all: the other
sites *assign* one, always into `y`.

**2. A fourth site exists, off the spawn path, and has its own lot.**
[`FIX-MG-ENERGY-READS-EASTING`](../FIX-MG-ENERGY-READS-EASTING/PRD.md) —
`VeafMG_Weapon:getCurrentEnergy` computes a missile's potential energy as `mass × 9.81 ×
getPoint().z`, the easting. Not widened into this lot, per the instruction to open one instead.

**3. The literal transposition would have broken static aircraft, which is why the threshold changed
too.** `spawnPosition.y <= 10` looks like the minimal fix and refuses every aircraft placed as a static
on low-lying or coastal ground — where `veaf.placePointOnLand` puts it at 1 m. And *"an aircraft forced
to spawn as a static"* is the **only** air case `veafSpawn.spawnUnit` can reach, since
`veafSpawnAircraft.lua:74` returns early for a non-static air unit. See ticket 01.

**4. The guard was refusing something after all — the wrong thing.** *"The guard has never rejected
anything"* holds for the map, not for the axis: `z <= 10` did fire within ten metres of the theatre's
central meridian. It is also why the aircraft case of the pinning test looked correct.
