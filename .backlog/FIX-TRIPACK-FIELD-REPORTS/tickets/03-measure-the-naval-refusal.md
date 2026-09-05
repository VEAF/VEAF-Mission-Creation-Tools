# 03 — Why the terrain check refuses a ship already at sea

Status: ⬜ ready

Type: fix

## The fact

Six groups of three combat zones are **not created at all**, identically on both 6.19.0 loads of
Tripack's log:

```
VEAF-SPAWNER|E|_drawOrigin|8777: no point within 0m of the requested spot is valid terrain for [CMBT_BANDAR_E_JASK - Cargo Ship]
VEAF-SPAWNER|E|_drawOrigin|8777: no point within 0m of the requested spot is valid terrain for [CMBT_BANDAR_E_JASK - Navy]
VEAF-SPAWNER|E|_drawOrigin|8777: no point within 0m of the requested spot is valid terrain for [CMBT_HAVADARYA - Submarine]
VEAF-SPAWNER|E|_drawOrigin|8777: no point within 0m of the requested spot is valid terrain for [CMBT_HAVADARYA - Navy]
VEAF-SPAWNER|E|_drawOrigin|8777: no point within 0m of the requested spot is valid terrain for [CMBT_HAVADARYA - Cargo Ship]
VEAF-SPAWNER|E|_drawOrigin|8777: no point within 0m of the requested spot is valid terrain for [CMBT_RAJAEI - Cargo Ship]
```

`_drawOrigin` exhausts its hundred attempts, returns `nil`, and `_spawn` returns `false`. Whatever
those zones were meant to put on the water, the mission does not have it.

## What is not established

**Why the check fails.** Read on 2026-09-05, the path says it should pass:

- radius is 0 (the message prints it), so `getRandomPointInCircle` returns the centre itself, and a
  hundred attempts test the same point a hundred times;
- the centre is the element's declared position, which for these groups is at sea — `findSpawnPoint`
  had already failed on them and `spawnElement` logs *"keeping its declared position"*;
- a `ship` category validates against `veaf.WATER_TERRAIN`, which holds both `WATER` and
  `SHALLOW_WATER`;
- `veafDcsSpawner.ANY_TERRAIN`, the fallback when a category is unknown, holds **every** surface DCS
  names, so even a mis-resolved category should accept anything.

`makeVec3`, `veafGeo.getRandomPointInCircle` and `veaf.isTerrainValid` were each read and none of
them drops the easting. So one of the four statements above is false in the running game, and
guessing which costs more than measuring it.

The two candidates worth testing first, in order:

1. **`data.category` is not what the code assumes.** These names read like statics (`Cargo Ship` is a
   static in most missions), and a static travels a different branch of `_spawn`. What does
   `veafMissionDb.getGroupRecord` actually put in `category` for each of the six?
2. **The point tested is not the point logged.** `spawnElement` keeps the *declared* position on
   failure, and that position comes from `referencePositionOf` — a live unit's runtime vec3. If the
   element's unit 1 was filtered out of the zone, the anchor is another unit entirely.

## How to measure

The error message is the instrument, and today it prints only the radius and the group name. Make
it print what would settle this in one line: the resolved category, the surface list it tested
against, the point, and the surface DCS reported. That is worth having permanently — a terrain
refusal that names neither the surface nor the criterion cannot be diagnosed from a user's log,
which is exactly the position this ticket is in.

Then reproduce: a combat zone holding one ship group and one static ship, on water, `#spawnradius=`
written and not written. Ticket 02 is landed first, so the search no longer sends a hull inland.

## Definition of done

- [ ] `_drawOrigin`'s refusal names the category, the accepted surfaces, the point and the surface
      DCS returned
- [ ] The cause of the six refusals is named, with the measurement that shows it
- [ ] The fix follows from that measurement; a ship declared at sea spawns
- [ ] Unit tests covering the case found, written against the built group rather than the constant
- [ ] `luacheck` + `stylua --check` clean; Lua coverage floor bumped per the ratchet policy
