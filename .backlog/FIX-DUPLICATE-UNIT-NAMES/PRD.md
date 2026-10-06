# FIX-DUPLICATE-UNIT-NAMES — spawned units of the same type share one name

Status: ⬜ ready

## Origin

The demo's bridge recette on the 6.28.0 candidate (`6.28.0+60130a90`, 2026-10-06) still found `-menage` (`_destroy, radius 2000`) leaving vehicles alive, after FIX-DEMO-RECETTE-FINDINGS ticket 01 (#1086) made `veafSpawn.destroy` destroy the objects it finds instead of looking them up again by name.
That ticket's diagnosis (« `Unit.getByName` cannot resolve « [CH] » names ») was wrong: the units it could not resolve had **duplicate names**.

David wants the fix in **6.28.0**.

## The defect

`veafSpawnGround.lua` (l. 373, the unit loop of the group spawn) names each unit `string.format("%s - %s", groupName, unit.displayName)` — or `"%s"` with `veafSpawn.HideTypeFromGroupNames` — with **no index**.
Two units of the same type in one group get the same name.
DCS then resolves neither by name, and everything keyed by unit name misses them: `_destroy` by radius, `findUnitsInCircle` (its result is keyed by name, so one of the two is dropped), and any script that looks a unit up by name.

## Measured

Demo test mission, 6.28.0 candidate, over dcs-bridge, after `-armor` then `-menage` at the sandbox centre:

- `[r]-Armored Platoon#10344` has two units, both named `[r]-Armored Platoon#10344 - MBT T-72B` (ids 200108 and 200109);
- `Unit.getByName` of that name returns nil;
- `veaf.findUnitsInCircle(centre, 2000, true)` returns the name once;
- both tanks survive `-menage` at 1 358 m and 1 405 m.

The CAS group already numbers its units (`veafCasMission.lua` l. 1111, `… / <type> #<n>`) and is destroyed correctly.

## Tickets

| # | Ticket |
|---|--------|
| [01](tickets/01-number-spawned-units.md) | Give every spawned unit a unique name |

## Definition of done

- A Lua test that fails before the fix: a group spawned with two units of the same type gets two distinct unit names.
- `CHANGELOG.md` entry, one PR into `develop`, then `develop` merged into `release/6.28.0` as for #1085 and #1086.
- In DCS: the demo's `python tools/recette_pont.py --lang fr sandbox` green on a fresh test mission (the `-menage` probe).
- FIX-DEMO-RECETTE-FINDINGS ticket 01 gets a line saying its diagnosis was superseded by this lot.
