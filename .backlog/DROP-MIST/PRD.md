# DROP-MIST — VEAF scripts stop depending on MiST

Status: ⬜ ready

Origin: David, 2026-08-17 (*he wants to try removing it outright, and there is now a precedent — CTLD 2
dropped it*), carried as a vision line in `ROADMAP.md` §4 until 2026-08-27. That line closed with a
gate — *"start by counting the call sites per MiST function, since that number decides whether this is
a lot or a campaign"* — and this PRD opens with the count, so the gate is met rather than restated.

Doctrine settled by David, 2026-08-27, in three rules:

1. **Prefer the native DCS function** wherever one exists.
2. **When the MiST function is complex and useful, rewrite it on our side**, simplifying and modernising.
3. **When it is complex but only partly useful, prune what we never call**, then rewrite the remainder.

## Why

MiST is injected into **every** generated mission and cannot be switched off:
`MANDATORY_COMMUNITY_SCRIPTS = frozenset({"mist"})` in
[`mission_builder_worker.py:468`](../../src/python/veaf-tools/mission_builder/mission_builder_worker.py)
and [`lua_config_generator.py:270`](../../src/python/veaf-tools/veaf_libs/lua_config_generator.py);
disabling it in `modules:` is warned about and ignored. That buys us 340 KB and 9 813 lines of Lua, a
second scheduler, and every VEAF spawn path routed through a library nobody here maintains.

This is **not** a lot born of distrust in MiST's correctness. The #290 investigation read
`mist.teleportToPoint` end to end and found it right. The reasons are the dependency itself, and one
symptom worth naming: [`veafSpawnAircraft.lua:788`](../../src/scripts/veaf/veafSpawnAircraft.lua)
already reaches into `mist.DBs` and deletes entries by hand, with a VEAF contributor's comment saying
*"MIST does not do it on its own, I highly recommend looking for an alternative"*. We are already
writing into the library's internals.

## What was measured (2026-08-27)

**455 call sites, 64 distinct MiST symbols, in 32 of the ~50 VEAF Lua files.** The 47 functions we call
that could be located in `mist.lua` account for **1 635 of its 9 813 lines — 17 %**. The other 83 % is
never reached from VEAF.

### The functions we call, by MiST size

| MiST lines | VEAF calls | Symbol | Rule |
|---:|---:|---|:--:|
| 223 | 15 | `mist.teleportToPoint` | 2 |
| 222 | 17 | `mist.dynAdd` | 2 |
| 131 | **1** | `mist.utils.converter` | 3 |
| 106 | 9 | `mist.tostringLL` | 2 |
| 102 | 18 | `mist.dynAddStatic` | 2 |
| 74 | 3 | `mist.getUnitsInZones` | 3 |
| 70 | 11 | `mist.getGroupRoute` | 2 |
| 70 | 4 | `mist.getGroupData` | 2 |
| 38 | 4 | `mist.pointInPolygon` | 3 |
| 36 | 20 | `mist.getRandPointInCircle` | 2 |
| 29 | 4 | `mist.random` | 1 |
| 29 | **1** | `mist.utils.dostring` | 3 |
| 25 | **1** | `mist.utils.zoneToVec3` | 3 |
| 24 | 11 | `mist.goRoute` | 2 |
| 24 | 2 | `mist.marker.drawZone` | 1 |
| 24 | **1** | `mist.getAvgPos` | 3 |
| 23 | 17 | `mist.utils.deepCopy` | 2 |
| 23 | 2 | `mist.utils.getQFE` | 3 |
| 23 | **1** | `mist.getUnitsInPolygon` | 3 |
| 21 | 4 | `mist.tostringMGRS` | 2 |
| 20 | **1** | `mist.getDeadMapObjsInZones` | 3 |
| 19 | 3 | `mist.utils.makeVec3` | 2 |
| 18 | **67** | `mist.scheduleFunction` | 1 |
| 17 | 6 | `mist.getHeading` | 3 |
| 17 | 1 | `mist.removeEventHandler` | 1 |
| 16 | 16 | `mist.removeFunction` | 1 |
| 16 | 7 | `mist.utils.get2DDist` | 2 |
| 16 | 1 | `mist.getAvgGroupPos` | 3 |
| 15 | 4 | `mist.utils.getDir` | 2 |
| 15 | 4 | `mist.respawnGroup` | 2 |
| 15 | 1 | `mist.addEventHandler` | 1 |
| 14 | 4 | `mist.getNorthCorrection` | 3 |
| 13 | 1 | `mist.utils.getHeadingPoints` | 3 |
| 11 | 1 | `mist.utils.makeVec2` | 2 |
| 10 | 6 | `mist.vec.scalarMult` | 2 |
| 10 | 1 | `mist.getNextUnitId` | 3 |
| 8 | 27 | `mist.utils.round` | 2 |
| 8 | 8 | `mist.vec.add` | 2 |
| 7 | **61** | `mist.utils.toRadian` | 2 |
| 7 | 12 | `mist.utils.toDegree` | 2 |
| 7 | 6 | `mist.utils.metersToNM` | 2 |
| 7 | 5 | `mist.utils.metersToFeet` | 2 |
| 7 | 4 | `mist.vec.mag` | 2 |
| 7 | 3 | `mist.utils.mpsToKnots` | 2 |
| 7 | 3 | `mist.utils.feetToMeters` | 2 |
| 7 | 1 | `mist.utils.NMToMeters` | 2 |
| 4 | 2 | `mist.marker.remove` | 1 |
| — | 51 | `mist.DBs.*`, `getAll*Data`, `getUnitData`, `getGroupById`, `isHumanUnit` | 2 |

**Rule 1 covers 93 calls, not the majority.** DCS has no `toRadian`, no `metersToNM`, no `deepCopy` —
the 170 maths, vector and conversion calls are rule 2 in its trivial form: 7 to 23 lines of arithmetic
each, copied and modernised, not redesigned. Looking for a native equivalent there wastes time.

**Rule 3 has a bigger target than it looks.** Ten functions totalling **314 MiST lines** are called
**11 times** between them, eight of them exactly once. `mist.utils.converter` alone is 131 lines for a
single call site.

### The scheduler, in detail

`mist.scheduleFunction` is not a wrapper over the native call — MiST says so itself
([`mist.lua:2091`](../../src/scripts/community/mist.lua): *"Modified Slmod task scheduler, superior to
timer.scheduleFunction"*). `mist.main` re-arms itself **every 0.01 s** and
[`doScheduledFunctions`](../../src/scripts/community/mist.lua) walks the whole task list on each pass.

What the native `timer.scheduleFunction` does not offer, and what the 67 VEAF call sites use:
repetition (`rep`), a stop time (`st`), a `pcall` so one failing task does not break the chain, and
arguments as a table. That is **~40 lines of adapter** over the native call.

### The mission database

MiST declares **31 tables** under `mist.DBs`. VEAF reads **8**. The 23 it never reads include
`aliveUnits`, `removedAliveUnits`, `unitsByCat`, `zonesByName`, `navPoints`, `markList`, `deadObjects`
and the whole `MEunits*` family.

`mist.main`'s tick splits into three jobs of very unequal value to us:

| Frequency | Job | Useful to VEAF |
|---|---|---|
| 100 Hz | `doScheduledFunctions()` — drain the task list | Yes (the scheduler) |
| 5 Hz | `checkSpawnedEventsNew()` + `updateDBTables` coroutine | **Yes** — drains a queue the birth-event handler fills |
| 20 Hz | `updateAliveUnits` coroutine — walks **every unit in the mission** | **No** — feeds `aliveUnits` / `removedAliveUnits`, never read |

So the expensive half of the DB work maintains tables we never look at, and the half that matters is
event-fed rather than a poll: when nothing spawns, `checkSpawnedEventsNew` does nothing.

**The constraint we inherit, not a MiST clumsiness:** MiST defers the DB write instead of doing it in
the birth handler because at event time the group is not always reachable. Its own disabled log line
says why — [`mist.lua:1657`](../../src/scripts/community/mist.lua): *"Group not accessible by unit in
event handler. This is a DCS bug"*. Hence the deferral, plus a `verifyDB()` safety net walking
`coalition.getGroups()` for anything the events missed.

**What our 8 tables are actually read for:**

| Table | Calls | What the caller wants | Replacement |
|---|---:|---|---|
| `missionData.bullseye.blue` / `.red` | 5 | the bullseye | `env.mission.coalition.<side>.bullseye`. Static, one write in MiST |
| `units` | 5 | **pre-placed** groups by coalition/country | `env.mission`. Both consumers ([`veaf.lua:2769`](../../src/scripts/veaf/veaf.lua), [`veafInterpreter.lua:156`](../../src/scripts/veaf/veafInterpreter.lua)) walk it **once at init** to build their own index — none of its 33 dynamic writes reach them |
| `MEgroupsByName` | 3 | a group's `groupId` from the editor | a frozen snapshot (`deepCopy` at init) → one `env.mission` walk at startup |
| `humansByName` | 7 | the player slots | an `env.mission` walk (skill `Client` / `Player`) |
| `unitsByName`, `groupsByName`, `groupsById`, `unitsByNum` | 11 + the 6 façades | the **record** of a unit or group: `x`, `y`, `alt`, `coalitionId`, `groupName` | our own index — see the trap below |

**The trap that decides ticket 05:** the native call is not a drop-in replacement for those four.
`Unit.getByName("x")` returns a **live DCS object**; `mist.DBs.unitsByName["x"]` returns a **mission
data record**, which exists for a unit that has not spawned yet and for one already destroyed.
Our callers want the second — [`veafInterpreter.lua:92`](../../src/scripts/veaf/veafInterpreter.lua)
spells it out: *"a `mist.DBs.units` record: x, y, alt, coalitionId, groupName"*. So we do need an
index; just not a 31-table one refreshed 20 times a second.

## Found while measuring, and deliberately left out of scope

Studying the 20 `getRandPointInCircle` call sites for ticket 06 (David, 2026-08-27) turned up three
things that are **not MiST's doing** and are recorded so the campaign does not absorb them:

- **`veaf.placePointOnLand` validates nothing.** It sets `y` to the ground height and returns — no land
  versus water test, no building clearance. It wraps 13 of the 20 call sites, and its name reads like a
  guarantee it does not give.
- **There are three spawn-point searches, with three contracts.** `veaf.findSpawnPoint` (three tiers,
  scenery-aware), `veaf.findPointInZone` (`veaf.lua:1642` — draw, `land.getSurfaceType`, widen the
  dispersion, up to 1000 tries), and `veafSpawnAircraft.lua:115`'s own 25-try loop.
- **Seven ground-placement sites skip the scenery tier**, including `veafSpawnGround.lua:594` — a
  *"Full Combat Group"* of real ground units — and `veafCombatZone.lua:1466`, which covers every combat
  zone element with a non-zero spawn radius. `FEAT-SCENERY-AWARE-SPAWN` wired the four dynamic ground
  spawners plus the generic `doSpawnGroup`; these were not among them.

They pre-date this campaign and two of them need an arbitration rather than code (the FARP and FOB
radius semantics). Ticket 06 carries the full classification. **A ticket whose job is to remove a
dependency must not also move where things spawn**, so nothing here is fixed by this lot.

## Two footholds already in the repository

- **The façade exists.** [`veaf.lua:147`](../../src/scripts/veaf/veaf.lua) — *"Centralizes the main
  access points to `mist.DBs` to isolate modules from internal mist changes"* — already wraps the
  database behind six VEAF accessors (`veaf.getUnitData`, `getGroupData`, `isHumanUnit`,
  `getAllUnits`, `getAllGroups`, `getGroupById`). Its own comment admits direct accesses remain; there
  are 35. **Completing that façade, then swapping what sits behind it, is the shape of this whole
  campaign** — the 32 calling files never change.
- **Half the coordinate work is done.** `FEAT-COORDINATE-FORMATS` shipped the **reading** side on the
  native API ([`veaf.lua:1043`](../../src/scripts/veaf/veaf.lua) calls `coord.MGRStoLL`). Only the
  **writing** side is still MiST's (`tostringLL` + `tostringMGRS`, 127 lines, 13 calls).

## Architecture (David, 2026-08-27)

**Façades in `veaf.lua`, implementations in dedicated modules.** `veaf.lua` is already 220 KB / 6 051
lines; adding ~1 600 ported lines would grow it by a quarter and mix trigonometry into the framework
core. The six existing `mist.DBs` accessors are the precedent: callers see `veaf.*` only, so every
substitution stays invisible to the 32 calling files.

New modules: `veafMath.lua` (maths, vectors, conversions), `veafGeo.lua` (geometry, zones, coordinate
output), `veafScheduler.lua` (the native-timer adapter), `veafMissionDb.lua` (the index).

## Scope, and what it explicitly is not

**In scope:** replacing all 455 call sites, then removing `mist.lua` from the mandatory injection list
and from the test mocks.

**Not in scope:** matching MiST feature-for-feature. Every function is ported at the surface **we
actually call**, per rule 3. A behaviour MiST offers and no VEAF code uses is dropped, not
reimplemented "in case".

## The honest cost/benefit, stated up front

**No intermediate ticket delivers a player-visible gain.** MiST stays injected until the last call site
is gone, so until ticket 08 lands we still ship 340 KB, still run the 100 Hz tick, and still carry the
dependency. What the intermediate tickets do buy is a simpler test base (`test/lua/dcs_mocks.lua`
carries a MiST mock today) and a strictly decreasing call count — which is the only progress metric
this lot has.

David accepted that framing on 2026-08-27. It is written here so nobody re-opens it mid-campaign, and
so the lot is not judged on the wrong criterion at ticket 03.

## Order

Ticket 00 is a **spike** and comes first: it decides the shape of tickets 05 and 07, which are the two
that can go wrong. Then the cheap and isolated work, then the risky core, then the removal.

| # | Ticket | Calls | Risk |
|---|---|---:|---|
| 00 | What the mission index must actually hold — spike | — | de-risks 05 and 07 |
| 01 | The scheduler on the native timer | 85 | low, isolated |
| 02 | Maths, vectors and conversions | 170 | low, mechanical |
| 03 | Coordinate output | 13 | low |
| 04 | Prune the single-caller helpers | 11 | low, drops 334 MiST lines of surface |
| 05 | The mission index | 51 | **high** — gated by 00 |
| 06 | Geometry and zone queries | 45 | medium |
| 07 | Spawn, routes and teleport | 80 | **high** — gated by 00 |
| 08 | Drop the injection | — | the only ticket with a visible gain |

85 + 170 + 13 + 11 + 51 + 45 + 80 = **455**, the full measured count. No call site is unassigned.

## Definition of done

- [ ] `grep -rE '\bmist\.' src/scripts/veaf/` returns nothing
- [ ] `mist` is no longer in `MANDATORY_COMMUNITY_SCRIPTS` in either of the two Python modules, and a
      generated mission does not carry `mist.lua`
- [ ] `test/lua/dcs_mocks.lua` no longer mocks MiST
- [ ] The Lua suite passes and the Lua coverage ratchet is raised, not lowered
- [ ] `doc/` states that MiST is no longer injected, in both languages
- [ ] `src/scripts/community/mist.lua` is deleted
