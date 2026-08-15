# veafUnits — The group database and ground placement

**Module ID:** `UNITS` | **File:** `veafUnits.lua`

---

## Purpose

Two roles, both serving `veafSpawn`:

1. **The VEAF group and unit database** — this is what makes `-sa6` mean a complete SA-6 battery, with
   its launchers, radar and resupply, rather than a single vehicle.
2. **Ground placement** — when a group spawns, this module decides where each vehicle lands, in a
   grid around the requested point.

This page is for **developers**. A mission maker goes through the aliases, documented in
[veafShortcuts](veafShortcuts.en.md), and a pilot through markers.

---

## Finding a group or a unit {#lookup}

`veafUnits.findGroup(alias)` and `veafUnits.findUnit(alias)` search both databases by **alias, case
insensitively**. A group carries several aliases; that is what lets `-sa6`, `-SA6` and its synonyms
mean the same thing.

An alias that is not found returns `nil`, and the caller decides what to say — this module does not
talk to the player.

---

## Grid placement {#placement}

`veafUnits.placeGroup(group, spawnPoint, spacing, hdg, hasDest)` lays the units out around the spawn
point.

- **With no declared disposition the default shape is a square**: the side is
  `ceil(sqrt(unit count))`. A 10-vehicle group therefore fills a partially populated 4×4 grid.
- **With no heading given the group faces north** (`hdg = 0`).
- `spacing` separates the units from each other; it is expressed in multiples of the unit's size, not
  in metres.

`veafUnits.checkPositionForUnit` refuses a position that does not suit the unit — that is what stops a
tank from spawning in water. Since `FEAT-SCENERY-AWARE-SPAWN`, the search for a valid point goes
through `veaf.findSpawnPoint`, which also knows how to avoid villages and forests.

---

## The pathfinding fix {#pathfinding-fix}

`veafUnits.removePathfindingFixUnit(groupName)` removes a unit added artificially to a group to unblock
DCS's route computation. A group spawning with a destination gets that fix, and the unit is removed
after a delay.

---

## Counting what a group holds {#counting}

`veafUnits.countInfantryAndVehicles(groupname)` returns a group's infantry and vehicle counts. It is
what feeds the status reports, notably the combat zones'.

---

## `mission.yaml` configuration

None. The module is infrastructure: it always loads.

---

## See also

- [veafShortcuts](veafShortcuts.en.md) — the aliases these databases make possible
- [veafSpawn](veafSpawn.en.md) — the module that spawns the groups
- [Lua API reference](../../LUA_API_REFERENCE.en.md) — each function's detailed signature
