# 05 — `-cargoships` spawns nothing, silently

Status: ⬜ ready
Type: fix
Files: `src/scripts/veaf/veafShortcuts.lua` (`-cargoships`, `-escortedcargoships`, `-combatships`), `veafSpawn.lua` (`doSpawnGroup` for ship groups), `veaf-units.yaml` (`cargoships-nodef`), tests

## What happens

`-cargoships` expands to `_spawn group, name cargoships-nodef, country RUSSIA, offroad, speed 60, skynet true`.
Executed from a combat-zone `#command` carrier, and executed alone at sea through `veafShortcuts.executeCommand` (returns `true`), it creates **no group**; the log stops after `doSpawnGroup(...)` with no error.

## Measured

Demo mission in DCS, 2026-10-05, via `dcs-bridge`: `combatZone_Ochamchire_Navires` spawned its native corvette but no cargo; a standalone `-cargoships` at x=-250000, z=575000 (open sea) added no ship group.

## Fix

Find where the ship group is lost (category, `offroad` on water, or the spawn returning nil), make it spawn, and make a failed spawn say so.
Check `-escortedcargoships` and `-combatships` the same way.
Test on stubs: the generated group is submitted as a ship group at the requested point.

## Demo workaround to remove

Two native cargo ships placed in the zone (`tools/gen_06_corrections.py`).
