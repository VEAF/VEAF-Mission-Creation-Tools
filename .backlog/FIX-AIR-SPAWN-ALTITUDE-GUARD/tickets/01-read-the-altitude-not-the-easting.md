# 01 — The height test reads the altitude, and two cases prove which field it read

Status: ✅ done — 2026-09-01. One line in `veafUnits.checkPositionForUnit`, five tests, four sabotages.
Type: fix

`spawnPosition.y` instead of `spawnPosition.z`, compared against the ground height at that point
rather than against the constant 10 — see *Why not the literal transposition* below, which is the one
judgement call in this ticket.

## What the callers actually put in each field — measured, not assumed

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

## Why not the literal transposition

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
merely not below it — is [ticket 02](02-does-dcs-clamp-a-too-low-aircraft.md), because it cannot be
answered without DCS.

## The tests, and that each of them can fail

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

## The test CHORE-ONE-TERRAIN-CHECK left behind

`test_an_aircraft_is_refused_at_ten_and_accepted_above_it` pinned the defect on purpose, and is
**updated rather than deleted** — the record of what was wrong now lives in the comment heading
`TestVeafUnitsAircraftHeightGuard`. Worth noting what it was: `{ x = 0, y = 0, z = 10 }` is false and
`z = 11` is true — green under the easting reading **and** under the altitude reading, since `y = 0` is
under the terrain either way. It pinned the behaviour without being able to tell the two readings
apart, which is precisely the trap this lot is about.

Its neighbour in the surface sweep needed one change: the shared sweep point gained an altitude
(`y = 1000`) so *"an aircraft ignores the surface entirely"* still says that. The surface expectations
are untouched.
