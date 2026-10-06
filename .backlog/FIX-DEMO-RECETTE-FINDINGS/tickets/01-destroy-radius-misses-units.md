# 01 — `_destroy, radius …` spares units it has already found

Status: ✅ done
Type: fix
Files: `src/scripts/veaf/veafSpawnObjects.lua` (`veafSpawn.destroy`, « radius based destruction »), `test/lua/`

## What happens

`veafSpawn.destroy(spawnSpot, radius)` calls `veaf.findUnitsInCircle(spawnSpot, radius, true)`, which returns `{ [name] = unit object }`, then throws the objects away and looks each one up again by name: `Unit.getByName(name)`, then `StaticObject.getByName(name)`.
When the lookup fails the unit is silently skipped.

## Measured

Demo test mission, 2026-10-05, over the bridge, after `-armor` then `-menage` (`_destroy, radius 2000`) at the sandbox centre:

- the log shows `destroy(radius=2000, unitName=nil)`;
- `[r]-Armored Platoon#10252` survives, units at 1 295 m, 1 355 m, 1 512 m;
- `veaf.findUnitsInCircle(centre, 2000, true)` returns exactly those three units;
- `Unit.getByName("[r]-Armored Platoon#10252 - IFV BMP-3 [CH]")` returns nil, though the group's `getUnit(1):getName()` returns that very name.

Every unit spawned with a « [CH] » display name (the CH vehicle pack, drawn at random by `-armor`) is affected; the cause of the failed lookup is not established — the fix does not need it.
Same thing seen twice in that session (MCV-80 then CHAP_BMPT / CHAP_T64BV).

## Fix

Destroy the objects `findUnitsInCircle` returns (`unit:destroy()`, statics included), without the name round trip.
Check the other callers of `findUnitsInCircle` that re-resolve by name the same way (`grep -n "findUnitsInCircle"`).

## Test

A Lua test with a stub world where `Unit.getByName` cannot resolve a unit's name but the unit is in a group within the radius: `veafSpawn.destroy` must destroy it.
