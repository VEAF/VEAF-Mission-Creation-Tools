# FIX-AIR-SPAWN-ALTITUDE-GUARD — the aircraft height check reads the easting, not the altitude

Status: ✅ done — every ticket verified in game 2026-10-03; merged in #1055 · archived 2026-11-24
to answer whether the game lifts a too-low aircraft by itself (ticket 02, `DCS-SESSION-TODO.md` R9).

Found 2026-09-01 while delivering [`CHORE-ONE-TERRAIN-CHECK`](CHORE-ONE-TERRAIN-CHECK.md), and
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
| 02 | Does DCS lift a too-low aircraft on its own? The clearance rule depends on the answer | none — a question, no code | ✅ |
| 03 | Floor every aircraft given a role at a clearance above the ground | low — moves only a flight asked under 150 m above the ground | ✅ |

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
[`FIX-MG-ENERGY-READS-EASTING`](FIX-MG-ENERGY-READS-EASTING.md) —
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

## In-game check — 2026-10-03

From `FIX-IN-GAME-SESSION-2026-10-03`.

R9: `_spawn cap, side red, alt 2` over flat ground spawned a MiG-21 15 m above the ground; it hit
shrubs and trees within a second and crashed (`PILOT_DEAD`, `CRASH`). DCS does not clamp: refusing
only a point under the terrain is not enough, a clearance margin is needed — or the lift
`veafDcsSpawner` already applies. An aircraft static on a beach (1.8 m) spawns fine.

## Ticket 03 — the floor (2026-10-03)

David's call on the two forms of ticket 02: a floor, not a random band. The `-cap` that crashed never
reached `VeafGroupSpawn:_altitudeFor`: `VeafAircraftSpawn:spawn` writes `unit.alt = spot.y` for an
airborne role after the clone is built, so the 10 m clearance there never applied. The floor lives where
the altitude is decided:

- `veafAircraftSpawn.MINIMUM_CLEARANCE_METRES = 150` (about 500 ft) and
  `veafAircraftSpawn.flooredAltitude(point, altitude)`, which logs at info when it raises one;
- `VeafAircraftSpawn:spawn` floors the spot of any role that does not start on a take-off point — the
  unit, and the `zone_defense` patrol that flies at the spot's altitude. A QRA whose editor group
  answers no unit fell back to a spot at `y = 0`, sea level;
- `-cap` floors its altitude before building the race-track, so the patrol does not dive back to it.

`VeafGroupSpawn`'s own band (MiST's numbers, for clones without a role) is left alone: it serves combat
zone respawns that this measurement did not touch. Tests on both sides of the floor, proven red with
the floor disabled.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**the aircraft height check reads the easting.** `checkPositionForUnit` converts `spawnPosition.z` to a mission-table easting on line 390, then tests the same field as an altitude on line 412 (`z <= 10`). Every caller hands in a `veaf.placePointOnLand` result whose height is in `y` — `veafSpawnAircraft` writes `spawnSpot.y = alt` just before calling. So "an aircraft will not spawn below 10 m" tests whether the point is more than 10 m **east of the theatre origin**, true almost everywhere: the guard has never rejected anything. Found 2026-09-01 by `CHORE-ONE-TERRAIN-CHECK` and kept out of it, since that lot may not move a spawn answer. Third easting/altitude confusion in three days — enumerate the other height tests rather than sample. **Fixed 2026-09-01**: the test reads `y` and refuses a point *under* the terrain, which is the only form that does not break static aircraft on coastal ground (a literal `y <= 10` refuses them at 1 m). The enumeration found one other height test on the path, correct, and a **fourth** site off it — see FIX-MG-ENERGY-READS-EASTING. Left at 🧑 for the one question the code cannot answer: whether DCS lifts a too-low aircraft, which decides if a clearance margin is needed on top. **Answered in game 2026-10-03: it does not** — every aircraft given a role is now floored 150 m above the ground (ticket 03)

## Tickets, in full

## 01 — The height test reads the altitude, and two cases prove which field it read

Status: ✅ done — 2026-09-01. One line in `veafUnits.checkPositionForUnit`, five tests, four sabotages.
Type: fix

`spawnPosition.y` instead of `spawnPosition.z`, compared against the ground height at that point
rather than against the constant 10 — see *Why not the literal transposition* below, which is the one
judgement call in this ticket.

### What the callers actually put in each field — measured, not assumed

The PRD asserts *"every caller hands in a `veaf.placePointOnLand` result, whose height is in `y`"*.
Checked one by one, because if a single caller disagreed it would be the one deciding the fix:

| Caller | What reaches the function | Proof in the caller itself |
|---|---|---|
| `veafSpawnAircraft.lua:122` (`veafSpawn.spawnUnit`) | `veaf.placePointOnLand(...)`, then `spawnSpot.y = alt` when `alt > 0` | writes `["y"] = spawnSpot.z, ["alt"] = spawnSpot.y` into the DCS unit |
| `veafSpawnCore.lua:748` (`doSpawnGroup`) | `unit.spawnPoint`, whose `y` is copied from the group's `placePointOnLand` result (`veafUnits.lua:668`), overwritten by `alt` when `alt > 0` | `["y"] = spawnPoint.z, ["alt"] = spawnPoint.y` |
| `veafSpawnGround.lua:323` (`validateSpawnPosition`, from `_createDcsUnits`) | the same `unit.spawnPoint`; the group position is `veaf.placePointOnLand(spawnSpot)` | `["y"] = spawnPosition.z, ["alt"] = spawnPosition.y` |
| `veafCasMission.lua:1023` | the same, via `veafCasMission.placeGroup` → `veaf.placePointOnLand(groupPosition)` | `["y"] = spawnPosition.z, ["alt"] = spawnPosition.y` |

Four callers, one convention, no exception: **`y` is the altitude, `z` is the easting**. Each one then
writes the easting into the mission table's `y` and the altitude into `alt`, which is the mission-table
shape — `docs/agents/dcs-coordinates.md`. And `veaf.placePointOnLand` returns
`{ x = vec3.x, y = height, z = vec3.z }`, so the height is in `y` before any caller touches it.

### Why not the literal transposition

`spawnPosition.y <= 10` is the smallest possible edit and it is **wrong**, which is worth writing down
because it is the obvious thing to reach for:

- The air branch is reachable from `spawnUnit` **only for a unit forced to spawn as a static** —
  `veafSpawnAircraft.lua:74` returns early for `unit.air and not static`, since spawning aircraft
  properly is still marked work in progress. A static sits on the ground on purpose.
- On the ground, `y` is `veaf.getLandHeight(...)`, i.e. `floor(land.getHeight) + 1`. Over water and at
  the coast `land.getHeight` answers 0, so the aircraft stands at **1 m** and a ten-metre floor refuses
  it — twenty-five draws in a row, then *"cannot find a suitable position for spawning unit"*.

So a literal transposition would trade a guard that never fires for a guard that breaks
`_spawn unit, name <aircraft>, static` on every low-lying or coastal spot. `spawnPosition.y <
veaf.getLandHeight(spawnPosition)` refuses exactly one thing instead: a point **under** the terrain.
`test_a_static_aircraft_at_sea_level_is_accepted` is the test that fails under the literal form.

The clearance question — whether an aircraft needs to be *above* the ground by some margin rather than
merely not below it — is [ticket 02](FIX-AIR-SPAWN-ALTITUDE-GUARD.md), because it cannot be
answered without DCS.

### The tests, and that each of them can fail

Two cases separate the two readings, as the definition of done requires, plus the regression the
paragraph above argues for:

| Test | Position | Correct reading | Easting reading |
|---|---|---|---|
| `test_low_but_far_east_is_refused` | `y = 100`, `z = 50000`, ground 500 | refused | accepted |
| `test_high_but_at_easting_zero_is_accepted` | `y = 5000`, `z = 0`, ground 500 | accepted | refused |
| `test_the_easting_no_longer_decides_anything` | six eastings × above/below the terrain | easting is irrelevant | easting decides |
| `test_an_aircraft_placed_on_the_ground_as_a_static_is_accepted` | `placePointOnLand`, ground 500 | accepted | refused |
| `test_a_static_aircraft_at_sea_level_is_accepted` | `placePointOnLand`, ground 0 | accepted | refused |

All five were **red before the fix** (6 failures in `test_veafUnits.lua`, counting the two rewritten
cases in `TestVeafUnitsCheckPositionForUnit`), green after. Then the fixed line was broken four ways,
one at a time:

| Sabotage | Went red |
|---|---|
| `.y` back to `.z` — the original defect | all 6 |
| `<` to `>` | 6, including the surface sweep |
| guard disabled (`if false and …`) | the 3 that assert a refusal |
| `y <= 10`, the literal transposition | `test_low_but_far_east_is_refused` and `test_a_static_aircraft_at_sea_level_is_accepted` |

### The test CHORE-ONE-TERRAIN-CHECK left behind

`test_an_aircraft_is_refused_at_ten_and_accepted_above_it` pinned the defect on purpose, and is
**updated rather than deleted** — the record of what was wrong now lives in the comment heading
`TestVeafUnitsAircraftHeightGuard`. Worth noting what it was: `{ x = 0, y = 0, z = 10 }` is false and
`z = 11` is true — green under the easting reading **and** under the altitude reading, since `y = 0` is
under the terrain either way. It pinned the behaviour without being able to tell the two readings
apart, which is precisely the trap this lot is about.

Its neighbour in the surface sweep needed one change: the shared sweep point gained an altitude
(`y = 1000`) so *"an aircraft ignores the surface entirely"* still says that. The surface expectations
are untouched.

## 02 — Does DCS lift a too-low aircraft on its own? The clearance rule depends on the answer

Status: ✅ done — verified in game 2026-10-03
Type: question

[Ticket 01](FIX-AIR-SPAWN-ALTITUDE-GUARD.md) fixed the field the height test reads, which is
wrong whatever the answer here. What it deliberately did **not** decide is the threshold: today the
guard refuses a point under the terrain and nothing else.

### The question

An aircraft group spawned at, or a metre above, ground level — does DCS place it there and let it
explode, or does it lift it to a flyable altitude by itself?

Nobody in this repository can answer it without the game, and the answer decides between two different
rules. It also decides whether this was ever a **live** defect or merely a dead guard: the PRD says as
much, and the code cannot tell.

### The two forms

**Form A — what shipped.** Refuse only a point below the terrain.

```lua
if spawnPosition.y < veaf.getLandHeight(spawnPosition) then
  return false
end
```

Nothing legitimate moves: an aircraft on the ground is accepted, which is where a static one belongs.
If DCS lifts a too-low aircraft, this is the whole of the correct answer and the ticket closes as a
non-finding.

**Form B — clearance, if DCS does not lift.** The line's author wrote `10`, and the MiST-derived
spawner in this same repository already applies exactly that number:
`VeafGroupSpawn.MINIMUM_CLEARANCE_METRES = 10` (`veafDcsSpawner.lua:750`), compared against
`land.getHeight` at the point — the correct reading of the same rule, and evidence that MiST did not
trust DCS to clamp.

Two things must be settled before that form can ship, which is why it is not in this PR:

1. **What to do instead of refusing.** `veafDcsSpawner` does not refuse: it drops the aircraft into an
   altitude band above the ground (`ALTITUDE_BANDS`, 300–9000 m for a plane, 200–3000 m for a
   helicopter). Refusing means twenty-five identical redraws and then *"cannot find a suitable
   position"*, which for an altitude problem is a poor answer — the position was fine, the altitude was
   not. `checkPositionForUnit` is a boolean validator and cannot lift anything, so this form implies the
   correction happens in the callers instead.
2. **Statics must be exempt.** An aircraft placed as a static is on the ground on purpose and clears
   nothing. `checkPositionForUnit` cannot currently tell: `veafSpawn.spawnUnit` passes the unit from the
   database, whose `air` is true and whose `static` is false — the *"spawn it as a static"* decision is a
   separate parameter the function never sees. So form B needs the caller to say so, which is a
   signature change the PRD puts out of scope.

### What to run

In `DCS-SESSION-TODO.md`, item **R9**. Short version: spawn an aircraft group at an explicit low
altitude over flat terrain and look at what the game does with it — nothing to rebuild, the answer is
about DCS rather than about our scripts.

## 03 — Floor every aircraft given a role at a clearance above the ground

Status: ✅ done — verified in game 2026-10-03
Type: fix

Ticket 02's answer (DCS does not lift a too-low aircraft, 2026-10-03) turned into a floor: David's call
the same day, a floor rather than MiST's random band, at 150 m. What was done and why is in the
[PRD](FIX-AIR-SPAWN-ALTITUDE-GUARD.md#ticket-03-the-floor-2026-10-03).

### To see in game

`_spawn cap, side red, alt 2` over flat ground: the MiG appears about 150 m above the ground, does not
crash, and its `dcs.log` line reads `altitude … is too close to the ground, raised to …`.

### Seen in game (2026-10-03, second pass)

`_spawn cap, side red, alt 2, altdelta 1` over 20 m ground: both MiG-23 at **168 m** above the ground,
still flying more than 30 s later (this morning the MiG-21 crashed within a second). The first try
without `altdelta 1` drew an altitude above the floor and proved nothing — `altdelta 0` reads as
"not given", the ±2 000 ft default.
