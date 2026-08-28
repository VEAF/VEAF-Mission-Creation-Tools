# 05 — The mission index

Status: ⬜ ready — rewritten 2026-08-28 against ticket 00's findings
Type: refactor

**26 sites**, not the 51 this ticket was opened with — ticket 00 re-counted them, and the difference is
in the PRD's *Findings*. The ticket is also **smaller in shape** than it was written: the spike found no
VEAF caller that reads a record for a unit an AI or a third-party script spawned, so the birth-event
path and its deferred fill are gone. What remains is three things.

## The three things

| Brick | What it holds | How it is fed |
|---|---|---|
| **Editor snapshot** | every pre-placed group and unit, as a *mission data record* (`x`, `y`, `alt`, `coalitionId`, `groupName`, `groupId`, `type`, `skill`) | one `env.mission` walk at startup |
| **Name registry** | the group and unit names **we** have taken, and released | written by our own spawn path, cleared when the group dies |
| **Player roster** | every human unit name, **including DCS dynamic slots** | the editor walk for `Client` / `Player` skills, refreshed by a `coalition.getGroups()` sweep |

Nothing else. MiST declares 31 tables under `mist.DBs`; the 23 VEAF never reads — `aliveUnits`,
`removedAliveUnits`, `unitsByCat`, `unitsById`, `zonesByName`, `zonesByNum`, `navPoints`, `markList`,
`deadObjects`, `activeHumans`, `dynGroupsAdded`, `spawnsByBase`, `drawingByName`, `drawingIndexed`,
`const`, `humansById`, `oldAliveUnits` and the six `MEunits*` — are dropped, not ported.

## The trap that still stands

The native call is **not** a drop-in replacement. `Unit.getByName("x")` returns a **live DCS object**;
`mist.DBs.unitsByName["x"]` returns a **mission data record** — and that record exists for a unit that
has not spawned yet and for one already destroyed. Our callers want the second:
[`veafInterpreter.lua:92`](../../../src/scripts/veaf/veafInterpreter.lua) spells out what it reads,
*"a `mist.DBs.units` record: x, y, alt, coalitionId, groupName"*.

So an index is genuinely needed. What the spike removed is its refresh rate and two thirds of its
surface, not its existence.

## Why the player roster cannot be an `env.mission` walk alone

MiST maintains `humansByName` at runtime for **DCS dynamic slots**: a unit carrying a player name that
is absent from `MEunitsByName` is added at [`mist.lua:1077`](../../../src/scripts/community/mist.lua)
and [`:1374`](../../../src/scripts/community/mist.lua). A startup walk over skill `Client` / `Player`
would lose those players — silently, and only in the missions that use dynamic slots.

VEAF has already met this and patched around it in one place:
[`veafAirWaves.lua:781`](../../../src/scripts/veaf/veafAirWaves.lua) sweeps `coalition.getGroups()`
under the comment *"Dynamic slot players via DCS coalition API (not tracked by mist)"*, and the four
`isHumanUnit` call sites each carry an `or event.type.id == S_EVENT_PLAYER_ENTER_UNIT`. **This ticket
owns that sweep**, and removes both workarounds — `veafAirWaves` goes back to asking one question, and
the four `or` clauses become redundant.

Write the player test as `local p = unit:getPlayerName(); if p and p ~= "" then`. Whether DCS returns
`nil` or `""` for an AI unit is unmeasured (see `DCS-SESSION-TODO.md`); this form is correct either way,
and **must not** be shortened to `if unit:getPlayerName() then` — `""` is truthy in Lua.

## What replaces the tick

MiST's `mist.main` re-arms every 0.01 s and splits into three jobs. None survives as a tick:

- **20 Hz `updateAliveUnits`** — walks every unit in the mission to feed `aliveUnits` /
  `removedAliveUnits`, **both among the 23 tables we never read**. Dropped outright.
- **5 Hz `checkSpawnedEventsNew`** — drains the birth queue so AI spawns land in the DB. **We no longer
  need what it feeds.** Dropped.
- **100 Hz `doScheduledFunctions`** — the scheduler, and ticket 01's subject, not this one's.

The player roster refresh is the only recurring work this ticket adds, and it is a sweep over
`coalition.getGroups()`, not a per-unit poll. Trigger it on `S_EVENT_BIRTH` and `S_EVENT_PLAYER_ENTER_UNIT`
rather than on a timer if the event proves sufficient; if a timer is kept, say in a comment why, and keep
it in seconds, not hundredths.

## The static reads, which need no index at all

| Table | Calls | Replacement |
|---|---:|---|
| `missionData.bullseye.blue` / `.red` | 5 | `env.mission.coalition.<side>.bullseye`, read directly |
| `units` | 2 | `env.mission`. Both consumers walk it **once at init** to build their own index — [`veaf.lua:2770`](../../../src/scripts/veaf/veaf.lua) for the country list, [`veafInterpreter.lua:156`](../../../src/scripts/veaf/veafInterpreter.lua) for unit aliases |
| `MEgroupsByName` | 1 | the editor snapshot (MiST itself holds a frozen `deepCopy`) |

## Two removals the spike handed us

- **`veaf.mist.getUnitData` has no caller.** The only façade over `unitsByName`, and dead. Delete it
  rather than port it.
- **`veafTransportMission.resetAllCargoes` is dead code**, and the only reader of `unitsByNum`. Its
  radio command has been commented out since `5a43cc20` (2020-05-16) with *"TODO add this command when
  the respawn will work"*, and only a unit test calls it. Remove the function and its test, or say in
  this ticket why it was kept — but do **not** port `unitsByNum` for it.

## The façade is already there

[`veaf.lua:147`](../../../src/scripts/veaf/veaf.lua) already wraps the database behind seven accessors,
written for exactly this purpose — *"Centralizes the main access points to `mist.DBs` to isolate modules
from internal mist changes"*. **First close the façade** by migrating the 14 direct accesses onto it,
**then** swap the implementation. That way the substitution is one file's problem, not 32.

Included in the migration:
[`veafSpawnAircraft.lua:788-789`](../../../src/scripts/veaf/veafSpawnAircraft.lua), which deletes two
`mist.DBs` entries by hand so an AFAC can respawn under a name it already used. That is not a caller
reading the index — it is the **name registry** in disguise: `mist.dynAdd` renames a cloned group when
`mist.DBs.groupsByName[name]` already exists ([`mist.lua:1950`](../../../src/scripts/community/mist.lua)),
and the hand-deletion is how VEAF frees the name. Once we own the registry, `veaf.releaseSpawnedName(name)`
replaces it, and ticket 07's `dynAdd` port asks the registry instead of a mission mirror.

## Definition of done

- [ ] The 14 direct `mist.DBs` accesses are migrated onto the `veaf.*` façades **before** any
      implementation swap, as a separate reviewable step
- [ ] `veafMissionDb.lua` exists and holds exactly the three bricks: editor snapshot, name registry,
      player roster
- [ ] No polling loop, no periodic full-mission scan, and no birth-event path for AI or third-party spawns
- [ ] The player roster includes dynamic-slot players; `veafAirWaves.lua`'s local `coalition.getGroups()`
      workaround is removed and its test still passes
- [ ] The static reads go straight to `env.mission`
- [ ] `veafSpawnAircraft.lua:788-789`'s hand-deletion is replaced by a supported registry call
- [ ] `veaf.mist.getUnitData` and `veafTransportMission.resetAllCargoes` are gone (or the ticket says why not)
- [ ] Lua tests: a record for a pre-placed unit, for one we spawned, for one already destroyed, for a
      name that does not exist, a dynamic-slot player, and the AFAC name-reuse case
- [ ] A test asserts that an AI unit whose `getPlayerName()` returns `""` is **not** in the player roster
- [ ] `grep -E 'mist\.DBs' src/scripts/veaf/` returns nothing
- [ ] `stylua --check` and `luacheck` clean
