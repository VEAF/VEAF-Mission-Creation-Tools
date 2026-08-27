# 05 — The mission index

Status: ⬜ ready — **gated by ticket 00**
Type: refactor

51 call sites. The riskiest ticket of the campaign, and the one whose shape ticket 00 exists to decide.
**Do not start it before 00 has answered.**

## What we replace, and what we do not

MiST declares **31 tables** under `mist.DBs`. VEAF reads **8**. The 23 it never reads —
`aliveUnits`, `removedAliveUnits`, `unitsByCat`, `unitsById`, `zonesByName`, `zonesByNum`, `navPoints`,
`markList`, `deadObjects`, `activeHumans`, `dynGroupsAdded`, `spawnsByBase`, `drawingByName`,
`drawingIndexed`, `const`, `humansById`, `oldAliveUnits` and the six `MEunits*` — are dropped, not
ported.

## The trap

The native call is **not** a drop-in replacement. `Unit.getByName("x")` returns a **live DCS object**;
`mist.DBs.unitsByName["x"]` returns a **mission data record** — and that record exists for a unit that
has not spawned yet and for one already destroyed. Our callers want the second:
[`veafInterpreter.lua:92`](../../../src/scripts/veaf/veafInterpreter.lua) spells out what it reads,
*"a `mist.DBs.units` record: x, y, alt, coalitionId, groupName"*.

So an index is genuinely needed. What we drop is its size and its refresh rate, not its existence.

## The three sources of a record

| Source | How the index learns about it | Cost |
|---|---|---|
| Pre-placed in the Mission Editor | one `env.mission` walk at startup | one pass, no maintenance |
| **Spawned by us** | registered in the same call that creates the group — we built the record to hand it to DCS, so we already have it | free |
| Spawned by a third party — late activation, CTLD, Foothold, another script, a player taking a slot | birth event, then a **deferred** fill | one scheduled call per birth |

The deferral in the third row is not optional and not MiST clumsiness: at birth-event time the group is
not always reachable. MiST's own disabled log line says so —
[`mist.lua:1657`](../../../src/scripts/community/mist.lua): *"Group not accessible by unit in event
handler. This is a DCS bug"*. That is why MiST queues births and drains the queue at 5 Hz, and why it
also runs a `verifyDB()` poll over `coalition.getGroups()` to catch what the events missed.

**Whether we need the third row at all is ticket 00's question 1.** If no VEAF caller reads a record for
a unit a third party spawned, this ticket loses its event path entirely and becomes a startup index plus
our own registration.

## What replaces the tick

MiST's `mist.main` splits into three jobs. Only two matter, and neither survives as a tick:

- **20 Hz `updateAliveUnits`** — walks every unit in the mission to feed `aliveUnits` /
  `removedAliveUnits`. **Both are in the 23 tables we never read.** Dropped outright: this is the
  expensive half of the DB work and it buys us nothing.
- **5 Hz `checkSpawnedEventsNew`** — drains the birth-event queue. Becomes one scheduled call per birth
  through `veafScheduler` (ticket 01), not a polling loop. When nothing spawns, nothing runs.

## The four static reads, which need no index at all

| Table | Calls | Replacement |
|---|---:|---|
| `missionData.bullseye.blue` / `.red` | 5 | `env.mission.coalition.<side>.bullseye`, read directly |
| `units` | 5 | `env.mission`. Both consumers walk it **once at init** to build their own index — [`veaf.lua:2769`](../../../src/scripts/veaf/veaf.lua) for the country list, [`veafInterpreter.lua:156`](../../../src/scripts/veaf/veafInterpreter.lua) for unit aliases |
| `MEgroupsByName` | 3 | a frozen `deepCopy` in MiST → one `env.mission` walk |
| `humansByName` | 7 | an `env.mission` walk for skill `Client` / `Player` |

## The façade is already there

[`veaf.lua:147`](../../../src/scripts/veaf/veaf.lua) already wraps the database behind six accessors,
written for exactly this purpose — *"Centralizes the main access points to `mist.DBs` to isolate modules
from internal mist changes"*. **First close the façade** by migrating the 35 direct accesses onto it,
**then** swap the implementation. That way the substitution is one file's problem, not 32.

Included in the migration: [`veafSpawnAircraft.lua:788`](../../../src/scripts/veaf/veafSpawnAircraft.lua),
which deletes two `mist.DBs` entries by hand so an AFAC can respawn under a name it already used. Once
we own the index, that becomes a supported operation instead of a documented workaround.

## Definition of done

- [ ] Ticket 00's findings are in the PRD and this ticket was rewritten against them
- [ ] The 35 direct `mist.DBs` accesses are migrated onto the `veaf.*` façades **before** any
      implementation swap, as a separate reviewable step
- [ ] `veafMissionDb.lua` exists: startup index from `env.mission`, direct registration for our own
      spawns, and — only if ticket 00 says it is needed — a birth-event path with a deferred fill
- [ ] No polling loop and no periodic full scan
- [ ] The four static reads go straight to `env.mission`
- [ ] `veafSpawnAircraft.lua:788`'s hand-deletion is replaced by a supported call
- [ ] Lua tests: a record for a pre-placed unit, for one we spawned, for one already destroyed, for a
      name that does not exist, and the AFAC rename case that `veafSpawnAircraft` needs
- [ ] `grep -E 'mist\.DBs' src/scripts/veaf/` returns nothing
- [ ] `stylua --check` and `luacheck` clean
