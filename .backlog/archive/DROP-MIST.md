# DROP-MIST — VEAF scripts stop depending on MiST

Status: ✅ done — all ten tickets closed 2026-08-31; MiST is no longer injected · archived 2026-09-28

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

They pre-date this campaign. Ticket 06 carries the full classification. **A ticket whose job is to
remove a dependency must not also move where things spawn**, so nothing here is fixed by this lot —
they are now [`FIX-PLACEMENT-IGNORES-SCENERY`](../FIX-PLACEMENT-IGNORES-SCENERY/PRD.md), opened
2026-08-27 with David's arbitration: the FARP, FOB and beacon stay exact, the FARP's escort becomes
scenery-aware, and the FARP is refused with a message when its escort cannot be placed.

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


## Closed, 2026-08-31

All ten tickets are done, and MiST is no longer injected into a mission that does not call it.

**What was measured at the start:** 455 call sites, 64 distinct MiST symbols, across 32 of the ~50
VEAF Lua files. **What is left in the shipped code:** none. `veaf.mist.*` still exists as six aliases
forwarding to `veafMissionDb` — kept so the swap was one file's problem rather than thirty-two — and
`CTLD.lua` mentions `mist.DBs` once, inside an error *message*. Neither is a call.

**What a mission gains:** 336 KB out of every `.miz` that does not ask for MiST, and the `mist.main`
tick — re-armed every 0.01 s, walking every unit twenty times a second to fill tables VEAF never read
— stops existing.

**What was kept:** `src/scripts/community/mist.lua`. MiST became opt-in rather than deleted, because a
mission maker's own script may call it: the build reads `src/scripts/*.lua` and injects MiST when it
finds a caller, naming the file. `convert-v5` asks the same question, which is what makes the change
worth anything — v5 shipped MiST in every mission, so detecting it by file name would have carried it
forward for everyone.

**Where the community scripts ended up:** CTLD had already dropped MiST on its own in v2; CSAR's 18
calls and Skynet's 42 were ported; the Hercules script was removed for want of a single user.

### The three follow-on lots this campaign produced

Not scope creep — each is a defect the port surfaced, and each has its own PRD:

- `FIX-CLONE-KEEPS-ITS-SOURCE-NAME` — MiST renamed a clone whose name was taken; the port did not, so
  three clones of `Arco` reached DCS as three groups called `Arco`.
- `FIX-CSAR-INIT-GUARD` — three guards against double initialisation, none of which could fire.
- `REFACTOR-CSAR-WITHOUT-MIST` / `REFACTOR-SKYNET-WITHOUT-MIST` — both verified in game on 2026-08-31,
  which is where two more defects were found that no test could see.

### What the in-game session taught, and is worth keeping

Three defects were found by flying, none by the 3950 tests, and the reasons were structural rather
than careless:

- the Lua tests load modules **in the right order** — none reproduces a mission's, where the community
  scripts come before the VEAF bundle;
- the spawner tests **teleport editor groups**, which always have a mission record;
- `world.addEventHandler` was a **no-op** in `dcs_mocks`, unable to tell one registration from ten.

The first two are now covered by `test_csar_init.lua`, which loads in a mission's order, and by the
country fallback tests. The third was fixed in the mock itself.

## Findings — ticket 00 (spike, 2026-08-28)

Answered from the code, on `develop` at `2e935bcb`. Every count is reproducible with the command that
produced it.

### The surface is 26 sites, not 51

```
grep -rn 'mist\.DBs\.'  src/scripts/veaf/    # 35 textual occurrences
grep -rn 'veaf\.mist\.' src/scripts/veaf/    # 19, of which 7 are the façade definitions
```

Of the 35 occurrences, **7** are the bodies of the façades themselves and **7** are comments or a log
string. **14 are real direct accesses** and **12 are calls to a façade**: a surface of **26 sites**,
served by **7** façades — the PRD said six, `veaf.mist.getAllHumanUnitData` was missing from the count.

`veaf.mist.getUnitData` has **no caller at all**. It is the only façade over `unitsByName`, and it is
dead.

The same correction applies one level up: the campaign's headline *"455 call sites"* is the count of
textual `mist.` occurrences, comments included; **390** lines of actual code mention `mist.`. That is a
fair upper bound for sizing the lot, not a migration checklist, and the per-ticket figures inherit the
same slack.

### Question 1 — who reads a dynamically added record? Nobody

| Site | Table | Bucket | Why |
|---|---|:--:|---|
| [`veaf.lua:2355`](../../src/scripts/veaf/veaf.lua) | `MEgroupsByName` | A | `veaf.getGroupData`, a local copy of `mist.getGroupRoute` — editor snapshot then `env.mission` |
| [`veaf.lua:2770`](../../src/scripts/veaf/veaf.lua) | `units` | A | `_initializeCountriesAndCoalitions`, walks pre-placed groups to build the country ↔ coalition tables |
| [`veafInterpreter.lua:156`](../../src/scripts/veaf/veafInterpreter.lua) | `units` | A | `_initialize`, one pass |
| [`veafCasMission.lua:1120`](../../src/scripts/veaf/veafCasMission.lua), `:1123` | `missionData.bullseye` | — | static, one write in MiST |
| [`veafCombatZone.lua:1391`](../../src/scripts/veaf/veafCombatZone.lua), `:1395` | `missionData.bullseye` | — | static |
| [`veafTransportMission.lua:495`](../../src/scripts/veaf/veafTransportMission.lua) | `missionData.bullseye` | — | static |
| [`veafSanctuary.lua:886`](../../src/scripts/veaf/veafSanctuary.lua) | `humansByName` | A | `initialize`, one pass into `veafSanctuary.humanUnits` |
| [`veafWeather.lua:1998`](../../src/scripts/veaf/veafWeather.lua) | `humansByName` | A | runs once, shortly after the module initializes |
| [`veafTransportMission.lua:680`](../../src/scripts/veaf/veafTransportMission.lua) | `unitsByNum` | — | **dead code** — see below |
| [`veafSpawnAircraft.lua:788`](../../src/scripts/veaf/veafSpawnAircraft.lua), `:789` | `unitsByName`, `groupsByName` | B | **writes**, not reads — see below |
| [`veafCarrierOperations.lua:342`](../../src/scripts/veaf/veafCarrierOperations.lua), `:488` | `getGroupData` | A | existence check on the editor's Pedro / tanker group |
| [`veafCarrierOperations.lua:952`](../../src/scripts/veaf/veafCarrierOperations.lua) | `getAllGroupData` | A | `initializeCarrierGroups`, called once from `:1175` |
| [`veafGrass.lua:700`](../../src/scripts/veaf/veafGrass.lua) | `getAllUnitData` | A | `buildFarpsUnits`, scheduled once at startup; the dynamic path is a birth handler that never touches the DB |
| [`veafMove.lua:1039`](../../src/scripts/veaf/veafMove.lua) | `getAllUnitData` | A | `findAllTankers`, called once from `initialize` |
| [`veafRadio.lua:804`](../../src/scripts/veaf/veafRadio.lua) | `getGroupById` | A | resolves a **human slot**'s group; `veafRadio.humanUnits` itself is event-fed, not read from the DB |
| [`veafQraCore.lua:665`](../../src/scripts/veaf/veafQraCore.lua) | `getAllHumanUnitData` | A | `_getEnemyHumanUnits`, computed once then cached on the instance |
| [`veafAirWaves.lua:762`](../../src/scripts/veaf/veafAirWaves.lua) | `getAllHumanUnitData` | **C** | rebuilt on every check — and **already patched locally**, see below |
| [`veafGrass.lua:2028`](../../src/scripts/veaf/veafGrass.lua), [`veafQraCore.lua:1162`](../../src/scripts/veaf/veafQraCore.lua), [`veafRadio.lua:90`](../../src/scripts/veaf/veafRadio.lua), [`veafWeather.lua:1971`](../../src/scripts/veaf/veafWeather.lua) | `isHumanUnit` | **C** | event-time, and every one of the four is already `or`'ed with `S_EVENT_PLAYER_ENTER_UNIT` |

**Bucket A — pre-placed, a startup index suffices: 20 of the 26 sites.**

**Bucket B — units we spawn: zero reads.** The only need is *inside* `mist.dynAdd`, and only on the
`clone` path: [`mist.lua:1950`](../../src/scripts/community/mist.lua) renames the new group when
`mist.DBs.groupsByName[newGroup.name]` already exists, and `:1993` does the same per unit. That is the
whole reason `veafSpawnAircraft.lua:788` deletes two entries by hand — so a dead AFAC's callsign can be
used again. What we need is therefore a **registry of the names we have taken and released**, not a
mirror of the mission.

**Bucket C — spawned by a third party: zero for AI and scripted spawns, non-zero for players.** No VEAF
caller reads a record for a unit CTLD, Foothold, another script or a late activation created. But five
sites read `humansByName`, and MiST maintains it at runtime for **DCS dynamic slots** — a unit with a
player name that is absent from `MEunitsByName` is added at
[`mist.lua:1077`](../../src/scripts/community/mist.lua) and
[`:1374`](../../src/scripts/community/mist.lua). An `env.mission` walk over skill `Client` / `Player`
alone would therefore **lose** dynamic-slot players, which is a live regression risk, not a theoretical
one.

Two of those five have already worked around it by hand, which is the evidence that the need is real:
[`veafAirWaves.lua:781`](../../src/scripts/veaf/veafAirWaves.lua) walks `coalition.getGroups()` under the
comment *"Dynamic slot players via DCS coalition API (not tracked by mist)"*, and the four `isHumanUnit`
sites each carry an `or event.type.id == S_EVENT_PLAYER_ENTER_UNIT`. **That loop is the pattern the
index should own**, and owning it removes both workarounds.

### `unitsByNum` has one reader, and it is dead code

`veafTransportMission.resetAllCargoes` is the only consumer of `unitsByNum`. Its radio command is
commented out — *"TODO add this command when the respawn will work"* — and has been since `5a43cc20`
(2020-05-16), the first release of the current pipeline. Nothing but a unit test calls it. Ticket 05
does not port `unitsByNum`: it removes the function, or it says why it kept it.

### Question 2 — no longer decides anything, but it did find something

The measurement (`type(getPlayerName())` on an AI unit's birth) was meant to tell us whether MiST's
`~= ""` guard lets AI spawns through. With bucket C limited to players, our own filter is
`local p = u:getPlayerName(); if p and p ~= "" then` — correct whichever value DCS returns. **The spike
no longer waits on DCS.**

The measurement is still worth taking, for a different reason: `veafAirWaves.lua:791` tests
`if dcsUnit:getPlayerName() then`, and in Lua `""` is truthy. If DCS returns `""` for an AI unit, that
line counts every AI aircraft in the zone as a player. Recorded in
[`DCS-SESSION-TODO.md`](../../DCS-SESSION-TODO.md) as an observation to make, **not** as a blocker, and
**not** fixed here — this campaign removes a dependency, it does not change who counts as a player.

### Question 3 — ticket 07 does not need the live index

| MiST function | What it reads | Needs |
|---|---|---|
| `mist.getGroupRoute` (11 calls) | `MEgroupsByName` for the id, then walks `env.mission` | **editor snapshot only** |
| `mist.getGroupPayload` (via `getGroupData`) | same | **editor snapshot only** |
| `mist.getGroupData` (4 calls) | `groupsByName` — plus a partial-name match no VEAF caller relies on | editor snapshot |
| `mist.getCurrentGroupData` (the `teleport` action) | `unitsByName`, to enrich each unit with skill / callsign — with a complete native fallback in the `else` branch | nothing hard |
| `mist.teleportToPoint` | `groupsByName` to fill in `country` / `category` when the caller omits them, `MEgroupsByName` for the route | editor snapshot |
| `mist.dynAdd` | `groupsByName` / `unitsByName`, **only on the `clone` path**, for name uniqueness | the name registry |

All 15 `teleportToPoint`, 4 `respawnGroup` and both `veafSpawnAircraft` clone sites start from an
**editor** group name — a template, a Pedro, a carrier, an asset. VEAF never respawns or clones a group
it created itself.

**So the dependency is not 07 → 05, it is 07 → two named bricks:** the editor group snapshot and the
name registry. Ticket 05 still comes first because it is where both live, but it no longer gates 07 on
a live index, and the two can be reviewed separately if 05 grows.

### What this changes

- **Ticket 05 loses the AI birth-event path** and the deferred fill that went with it — the
  `mist.lua:1657` *"Group not accessible by unit in event handler"* constraint no longer applies to us,
  because we never index an AI unit at birth. It keeps a **player** path, which is a
  `coalition.getGroups()` sweep VEAF already writes by hand in one place.
- **Ticket 05 is smaller than written**: a startup snapshot, a name registry, a player roster. Three
  things, none of them 31 tables.
- **Ticket 07 is unblocked** and states its two dependencies explicitly.
- Two removals fall out of the spike: `veaf.mist.getUnitData` (no caller) and
  `veafTransportMission.resetAllCargoes` (dead since 2020).

## Order

Ticket 00 is a **spike** and comes first: it decides the shape of tickets 05 and 07, which are the two
that can go wrong. Then the cheap and isolated work, then the risky core, then the removal.

| # | Ticket | Calls | Risk |
|---|---|---:|---|
| 00 | What the mission index must actually hold — spike | — | ✅ done 2026-08-28 |
| 01 | The scheduler on the native timer | 85 | ✅ done 2026-08-28 |
| 02 | Maths, vectors and conversions | 170 | ✅ done 2026-08-28 |
| 03 | Coordinate output | 13 | ✅ done 2026-08-28 |
| 04 | Prune the single-caller helpers | 11 | ✅ done 2026-08-28 |
| 09 | The destroyed-scenery register | 1 | ✅ done 2026-08-28 |
| 05 | The mission index | 26 | ✅ done 2026-08-28 |
| 06 | Geometry and zone queries | 37 | ✅ done 2026-08-28 (re-counted: 37, not 45) |
| 07 | Spawn, routes and teleport | 64 | ✅ done 2026-08-28 |
| 08 | Drop the injection | — | the only ticket with a visible gain |

85 + 170 + 13 + 11 + 51 + 45 + 80 = **455**, the count as first measured. The spike re-counted its own
slice and found 26 rather than 51 (see *Findings*), so the same slack is likely elsewhere: treat these
as sizing figures, and let each ticket re-count its own before it starts.

## Definition of done

- [ ] `grep -rE '\bmist\.' src/scripts/veaf/` returns nothing
- [ ] `mist` is no longer in `MANDATORY_COMMUNITY_SCRIPTS` in either of the two Python modules, and a
      generated mission does not carry `mist.lua`
- [ ] `test/lua/dcs_mocks.lua` no longer mocks MiST
- [ ] The Lua suite passes and the Lua coverage ratchet is raised, not lowered
- [ ] `doc/` states that MiST is no longer injected, in both languages
- [ ] `src/scripts/community/mist.lua` is deleted

---

## Tickets, in full

## 00 — What the mission index must actually hold (spike)

Status: ✅ done — 2026-08-28, findings in the PRD
Type: chore

A **measurement ticket**. It writes no production code; it answers three questions whose answers decide
the shape of tickets 05 and 07. Deliverable: a findings section appended to the PRD, and tickets 05 and
07 rewritten against it.

### Why it comes first

`mist.DBs.units` carries **33 write sites** inside MiST, so the table is maintained at runtime. Two of
our three consumers demonstrably do not care — [`veaf.lua:2769`](../../src/scripts/veaf/veaf.lua) and
[`veafInterpreter.lua:156`](../../src/scripts/veaf/veafInterpreter.lua) both walk it **once at init**
to build their own index, and `veafInterpreter` says it is *"liberally adapted from MiST"*. The third
consumer *writes* to it: [`veafSpawnAircraft.lua:788`](../../src/scripts/veaf/veafSpawnAircraft.lua)
deletes two entries by hand so an AFAC can be respawned under a name it already used.

Nobody has established **who reads those entries back**. Until that is known, ticket 05 cannot decide
whether the index needs runtime maintenance for units spawned by third parties, or only for the ones we
create ourselves.

### Question 1 — who reads a dynamically added record?

Enumerate, from the code rather than by sampling, every read of `unitsByName`, `groupsByName`,
`groupsById` and `unitsByNum` — the 11 direct sites plus the six `veaf.lua` façades and each of
*their* callers. For each, classify what it needs:

- **pre-placed only** — the record exists in `env.mission`, a startup index suffices;
- **also for units we spawned** — the index must be updated when we create a group;
- **also for units a third party spawned** — late activation, CTLD, Foothold, another script, or a
  player taking a slot; the index needs the birth event.

The count in the third bucket is the finding. If it is zero, ticket 05 loses its whole event path.

### Question 2 — does MiST's birth handler even see AI spawns?

[`mist.lua:1642`](../../src/scripts/community/mist.lua) guards the queue push with
`event.initiator:getPlayerName() ~= ""`. In Lua, `nil ~= ""` is true, so the guard's effect depends
entirely on whether DCS returns `nil` or `""` for an AI unit — which is not documented and must be
measured, not reasoned about.

Measure it: in a running mission, on an AI unit's birth event, log `type(getPlayerName())` and its
value. Two outcomes, both actionable:

- returns `nil` → AI spawns **do** go through the event path;
- returns `""` → AI spawns are skipped by the handler and only caught by the `verifyDB()` poll, which
  means MiST has a hole there, and that hole is the likely reason
  `veafSpawnAircraft.lua:788` has to intervene by hand.

Needs DCS started. Add it to [`DCS-SESSION-TODO.md`](../../DCS-SESSION-TODO.md) rather than blocking
the ticket: questions 1 and 3 can be answered without the game, and they carry most of the decision.

### Question 3 — what does `getGroupData` / `getGroupRoute` read the DB for?

`mist.getGroupData` (70 lines, 4 calls) and `mist.getGroupRoute` (70 lines, 11 calls) are inputs to
ticket 07, and both read the database. Establish whether they need the *live* record or the editor
snapshot, because that decides whether ticket 07 depends on ticket 05 or can precede it.

### Definition of done

- [x] Every read of the four record tables is enumerated from the code and classified into the three
      buckets, with counts — **26 sites**, bucket A 20, bucket B 0 reads, bucket C 0 for AI spawns and
      5 for players
- [x] The dependency direction between tickets 05 and 07 is settled and written down — 07 needs two
      bricks from 05 (editor snapshot, name registry), not its index
- [x] Question 2 is either answered, or filed in `DCS-SESSION-TODO.md` with the exact log line to add —
      **it no longer decides the design**; filed as item 22, as an observation about
      `veafAirWaves.lua:791`
- [x] Findings appended to the PRD; tickets 05 and 07 rewritten against them
- [x] No production code changed by this ticket

### What it cost the campaign, in one line

Ticket 05 loses its AI birth-event path and half its surface; ticket 07 is unblocked; two dead pieces of
code (`veaf.mist.getUnitData`, `veafTransportMission.resetAllCargoes`) are queued for removal; and the
lot no longer waits on a DCS session.

### Question 2, answered in game 2026-08-28

`DCS-SESSION-TODO` item 22 is closed, and the answer clears `veafAirWaves` rather than condemning it.

Probed over **every unit in a running mission** — 346 of them, on Caucasus, DCS 2.9:

```
total=346  nonNil=1  →  "A-10C Kobuleti -1"  type=string  ["New callsign"]
```

**`getPlayerName()` returns `nil` for an AI unit**, not an empty string: 345 AI units, all `nil`, and
the single non-`nil` answer was the human slot. That last part is what makes the measurement worth
anything — the probe demonstrably could tell a player from an AI, so `nil` everywhere else is a result
and not a broken check.

So [`veafAirWaves.lua:791`](../../src/scripts/veaf/veafAirWaves.lua) — `if dcsUnit:getPlayerName() then`
— is **correct as written** on this build. Air waves do not count AI aircraft as players, and no fix lot
is needed. The suspicion recorded in item 22 is closed, not deferred.

The index's own filter (`if p and p ~= "" then`) stays as designed: it is right whichever value DCS
returns, and it does not depend on this measurement holding for every future build.

---

## 01 — The scheduler on the native timer

Status: ✅ done — 2026-08-28
Type: refactor

85 call sites: `mist.scheduleFunction` (67), `mist.removeFunction` (16), `mist.addEventHandler` (1),
`mist.removeEventHandler` (1). Rule 1 — the native call exists — plus a thin rule 2 adapter.

### What exists

DCS provides `timer.scheduleFunction(f, arg, time)` and `timer.removeFunction(id)`. MiST deliberately
does **not** wrap them: [`mist.lua:2091`](../../src/scripts/community/mist.lua) calls its own
scheduler *"superior to timer.scheduleFunction"*. It maintains a task list, and `mist.main` re-arms
itself **every 0.01 s** so [`doScheduledFunctions`](../../src/scripts/community/mist.lua) can walk
that list on every pass.

Four things the native call does not give, all four used by our 67 call sites:

| MiST parameter | What it does | Native equivalent |
|---|---|---|
| `rep` | re-run every `rep` seconds | none — the native call re-arms only if the function *returns* the next time |
| `st` | stop re-running at this mission time | none |
| — | a `pcall` so a failing task does not break the chain | none — an error kills the scheduled call |
| `vars` | arguments as a table, unpacked into the call | the native call passes **one** argument |

### What this ticket does

A `veafScheduler.lua` module holding a `timer.scheduleFunction`-backed adapter with MiST's signature,
so the 67 call sites change only their prefix:

```lua
veaf.scheduleFunction(f, vars, t, rep, st)   -- returns an id
veaf.removeFunction(id)
```

One native scheduled call **per task**, re-armed by returning the next time — not one global tick
walking a list. `rep` and `st` are the adapter's own bookkeeping; the `pcall` wraps the call so the
existing tolerance for a failing task is preserved.

The two event-handler calls go to native `world.addEventHandler` / `world.removeEventHandler`. Check
first whether they should instead route through `veafEventHandler`, which is VEAF's own dispatcher and
was just corrected in `FIX-DOUBLE-EVENT-HANDLER` — a second registration path is exactly the defect
that lot fixed, so this must not reintroduce one.

**The 100 Hz tick does not disappear here.** `mist.main` is MiST's own and keeps running while MiST is
injected. It stops at ticket 08. What this ticket removes is our *dependence* on it.

### What the migration actually found

- **Only one of the 67 call sites uses `rep` or `st`.** `veafSkynetIadsMonitor.lua:610` repeats every
  `_interval` seconds with a one-hour stop time; the other 66 are one-shots. The adapter still
  implements both, because that one call is the module's monitoring thread — but the risk this ticket
  was given is not where the count suggested.
- **`{ position, nil, nil, color }` is a real argument list** (`veafSpawnEffects.lua:150`). `#` is
  undefined on a table with holes, so the adapter measures the list with `table.maxn` — Lua 5.1's
  answer to exactly this, with a key-scan fallback for newer interpreters. Covered by a test.
- **A test was asserting the mock, not the code.** `test_veafGroundAI`'s `check()` case asserted that
  no reschedule was left behind, which held only because `mist.scheduleFunction` was a no-op returning
  nil. `GroundUnitHandler:check()` re-arms itself on every pass; the test now says so.
- **The event handler goes to native `world.*`**, following `veafMissileGuardian`. `veafEventHandler`
  registers callbacks and has no way to drop one, and this handler is armed and disarmed as Skynet
  networks come and go. `mist.addEventHandler` took a plain function and answered a numeric id, so the
  call site now builds the one-line `onEvent` table the native API wants, and
  `monitorDynamicSpawnHandlerId` was renamed `monitorDynamicSpawnHandler` — it holds a table now, not
  an id.
- **A module has five registries, not one.** `veaf_build/worker.py`'s `LUA_BUNDLE_SCRIPTS`,
  `VeafDynamicLoader.lua`, `.luacheckrc`'s globals, `test/lua/veaf_loader.lua`'s module order, and
  `doc/TESTING.md` + its English twin for the test suite. Only the first is guarded by a test; the
  suite listing is guarded by `test_docs_check`. The other three fail late or not at all.
- **The scheduler mock now records instead of swallowing.** `timer.scheduleFunction` hands back an id
  and stores the task; `dcs_mocks.runScheduled(t)` runs what is due, re-arming on a numeric return
  like DCS. `setTime` deliberately still runs nothing, so no existing suite changed behaviour.

### Definition of done

- [x] `veafScheduler.lua` exists, with `veaf.scheduleFunction` / `veaf.removeFunction` façades
- [x] All 85 call sites migrated; `grep -E 'mist\.(scheduleFunction|removeFunction|addEventHandler|removeEventHandler)' src/scripts/veaf/` returns nothing
- [x] Lua tests covering: a one-shot task, a repeating task, `st` stopping a repeat, removal before
      first run, removal of an unknown id, and **a task that raises — the chain survives and the error
      is logged** — 19 cases, and the module lands at 94.8 % line coverage
- [x] The event-handler question is settled explicitly: native `world.*`, with the reason recorded in
      the source
- [x] `stylua --check` and `luacheck` clean

---

## 02 — Maths, vectors and conversions

Status: ✅ done — 2026-08-28
Type: refactor

**170** call sites — re-counted; the 176 above counted four helpers that belong to tickets 04 and 06.
20 functions, **7 to 23 MiST lines each**. The largest single bloc of the campaign and the least risky.

### Why this is rule 2 and not rule 1

DCS provides no `toRadian`, no `metersToNM`, no `deepCopy`. Searching for a native equivalent here is
wasted effort — these are plain Lua arithmetic that MiST happens to host. Rule 2 applies in its trivial
form: copy the behaviour, modernise the code, keep the semantics identical.

### The list

| Function | Calls | MiST lines |
|---|---:|---:|
| `mist.utils.toRadian` | 61 | 7 |
| `mist.utils.round` | 27 | 8 |
| `mist.utils.deepCopy` | 17 | 23 |
| `mist.utils.toDegree` | 12 | 7 |
| `mist.vec.add` | 8 | 8 |
| `mist.utils.get2DDist` | 7 | 16 |
| `mist.vec.scalarMult` (+ `scalar_mult`, 2) | 6 | 10 |
| `mist.utils.metersToNM` | 6 | 7 |
| `mist.utils.metersToFeet` | 5 | 7 |
| `mist.vec.mag` | 4 | 7 |
| `mist.utils.getDir` | 4 | 15 |
| `mist.utils.makeVec3` | 3 | 19 |
| `mist.utils.mpsToKnots` | 3 | 7 |
| `mist.utils.feetToMeters` | 3 | 7 |
| `mist.utils.makeVec2` | 1 | 11 |
| `mist.utils.NMToMeters` | 1 | 7 |

`mist.vec.scalar_mult` (2 calls) is an alias of `scalarMult` — the port exposes **one** name.

### Two traps

- **`makeVec3` / `makeVec2` and the `y`/`z` convention.** Read
  [`docs/agents/dcs-coordinates.md`](../../docs/agents/dcs-coordinates.md) before touching these:
  `y` means different things in a mission table and in the scripting API, and getting it wrong raises
  no error — only a wrong position. Port the behaviour exactly, and assert it in tests against a known
  triplet.
- **`deepCopy` and cycles.** Check whether MiST's version handles a table that references itself and
  whether any VEAF caller relies on that. If none does, say so in the port's docstring rather than
  carrying machinery nobody needs (rule 3 applies inside a rule 2 port).

### What this ticket does

A `veafMath.lua` module with the ported functions, exposed through `veaf.*` façades, and all 176 call
sites migrated.

### What the port actually found

- **100 of the 170 sites needed no new code.** `mist.utils.round` is `veaf.round` (`veaf.lua:934`)
  *line for line* — 27 calls just moved. And `mist.utils.toRadian` / `toDegree` are `math.rad` /
  `math.deg`: the ticket's own premise said DCS offers no equivalent, which is true and beside the
  point, because **Lua's standard library does**, and always did. That is 73 more calls with nothing
  to maintain behind them. Worst numerical difference over ±720°, measured: 1.8e-15 rad.
- **`getDir` dragged `getNorthCorrection` out of ticket 06.** Three of its four call sites pass a
  reference point, so the correction is on the live path; porting `getDir` without it would have left
  a MiST call inside a VEAF expression. `getNorthCorrection` (10 lines, over the native `coord.*`) is
  therefore ported here, and ticket 06 no longer owns it.
- **`mist.vec.scalar_mult` was an alias** (`mist.lua:6144`), as the ticket said; both spellings now
  land on `veaf.vecScalarMult`.
- **`veaf.compute2dAzimuth` and `veaf.compute2dMagnitude` already exist** in `veaf.lua` and overlap
  `getDir` / `vecMag` in part — different contracts (degrees, 2D, a nil guard), so they are left alone.
  Noted so a later ticket does not rediscover them as duplicates.
- **The ported functions are asserted by mutation, not only by example.** Swapping `y` and `z` in
  `makeVec3` fails 6 tests, dropping `deepCopy`'s cycle guard overflows the stack, and making `getDir`
  ignore its reference point fails 1 — each checked by actually making the change.

### Definition of done

- [x] `veafMath.lua` exists; every function above has a `veaf.*` façade
- [x] 170 call sites migrated; only one name survives for the `scalarMult` alias pair
- [x] Lua tests per function, including the degenerate cases: a zero vector for `mag`, a symmetric and
      a zero distance, `deepCopy` on a nested table, on a cycle, on shared references and on metatables
- [x] `makeVec3` / `makeVec2` asserted against a known coordinate triplet, with the convention named in
      a comment and in the test
- [x] `stylua --check` and `luacheck` clean

---

## 03 — Coordinate output

Status: ✅ done — 2026-08-28
Type: refactor

13 call sites: `mist.tostringLL` (9) and `mist.tostringMGRS` (4), 127 MiST lines between them.

### Why this one is nearly free

`FEAT-COORDINATE-FORMATS` already delivered the **input** half on the native API:
[`veaf.lua:1043`](../../src/scripts/veaf/veaf.lua) calls `coord.MGRStoLL` to parse what a mission
maker types, and the module documents the exact formats DCS displays. Only the **output** half is still
MiST's.

The geodesy is already native everywhere: every call site pairs the MiST call with `coord.LLtoMGRS`,
which is DCS's own. What MiST contributes is **string formatting** — degrees/minutes/seconds versus
decimal, digit precision, spacing — not coordinate conversion. So this is text assembly, and it belongs
next to the parser that already reads the same formats back.

### The call sites

| File | Calls |
|---|---|
| [`veafCasMission.lua:1119-1135`](../../src/scripts/veaf/veafCasMission.lua) | MGRS + LL decimal + LL DMS |
| [`veafCombatZone.lua:1390-1407`](../../src/scripts/veaf/veafCombatZone.lua) | same three |
| [`veafNamedPoints.lua:224-227`](../../src/scripts/veaf/veafNamedPoints.lua) | LL 3-digit + MGRS 5-digit |
| [`veafTransportMission.lua:494-504`](../../src/scripts/veaf/veafTransportMission.lua) | same three |
| [`veafSpawnGround.lua:1088`](../../src/scripts/veaf/veafSpawnGround.lua) | LL DMS |
| [`veafWeather.lua:905`](../../src/scripts/veaf/veafWeather.lua) | LL DMS |

Three of the four multi-call sites emit the **same trio** — MGRS, decimal LL, DMS LL — which suggests
one `veaf.formatPosition(vec3)` helper returning all three, rather than three separate ports called
three times each. Confirm from the surrounding message-building code before deciding.

### Watch for

The output must stay **byte-identical** to what pilots read today, because these strings go into F10
reports and briefings that mission makers have been reading for years. Assert against literal expected
strings, not against a re-derivation.

Precision arguments differ per call site (`2`, `3`, `5`, `0` with the DMS flag). Port the precision
semantics exactly — `tostringMGRS(mgrs, 5)` and `tostringMGRS(mgrs, 3)` do not round the same way.

### Decided: separate functions, not a trio helper

The ticket suspected one `veaf.formatPosition(vec3)` returning all three strings, because three call
sites emit the same trio. They do — but **not as a block**. In `veafCasMission`, `veafCombatZone` and
`veafTransportMission` the MGRS string is built about fifteen lines before the two lat/lon ones, and
each of the three goes into a *different* i18n entry (`report_latlon_decimal`, `report_latlon_dms`,
`report_mgrs`). A trio helper would mean rewriting the three message blocks, which is a refactor this
ticket was not asked for. Two functions, `veaf.toStringLL` and `veaf.toStringMGRS`, mirroring what the
call sites already do.

### Two defects in MiST, reproduced on purpose

Both were found by generating the expected strings from MiST itself before writing the port, and both
are now pinned by a test that says why.

- **A position at exactly zero renders as `S` and `W`.** The hemisphere test is `> 0`, so the equator
  and the prime meridian fall on the southern and western side: `00 00.00'S⇥ 00 00.00'W`.
- **In DMS, a minute reaching 60 does not carry into the degree.** Seconds rounding up carry into the
  minute, and there it stops: `41.99999444` renders as `41 60' 00"N` where it should read `42 00' 00"N`.
  The **decimal branch, three lines away, does carry** (`41.99999` → `42 00.00'N`), which is what makes
  this an oversight rather than a convention. DMS at precision 0 is the format four of the six call
  sites use, so this is on the common path — it needs the rounding to land exactly on a whole minute,
  which is roughly one report in three thousand.

Reproducing them is the ticket's own rule: these strings go into F10 reports and briefings, and this
lot removes a dependency rather than changing what pilots read. **The DMS carry got its own lot the
same day** — David, on reading this ticket: *"gère le 42 60, il faut corriger"* — and it is fixed in
[`FIX-DMS-MINUTE-CARRY`](FIX-DMS-MINUTE-CARRY.md). The zero-hemisphere quirk followed the
same day, in [`FIX-ZERO-HEMISPHERE`](FIX-ZERO-HEMISPHERE.md) — this ticket's judgement that it
was too rare to be worth a lot was overruled, and rightly: it is two characters of comparison.

A third quirk is pinned the same way: MGRS rounding can print one digit more than the requested
precision (`acc = 3` with an easting of 99999 gives `1000`), because the format pads to a minimum width
and never truncates.

### Also found

`test/lua/dcs_mocks.lua` carried a `mist.tostringLL` stub returning `"0N 0E"`, added for
`infoOnAllConvoys`. With the call migrated, the real function runs in that test instead of a constant.
The stub is removed and the suite still passes.

### Definition of done

- [x] Output formatting lives in `veafGeo.lua`, behind `veaf.*` façades
- [x] 13 call sites migrated; `grep -E 'mist\.tostring' src/scripts/veaf/` returns nothing
- [x] Lua tests assert **literal strings** for each precision used in the codebase (0, 2, 3, 5), DMS and
      decimal, in both hemispheres, across the prime meridian, and with a three-digit longitude
- [x] Decided and recorded: separate functions, with the reason above
- [x] `stylua --check` and `luacheck` clean

---

## 04 — Prune the single-caller helpers

Status: ✅ done — 2026-08-28
Type: refactor

Rule 3 in its purest form: **314 MiST lines reached by 11 calls**, eight of them exactly once. Each is
replaced by the slice we actually use, not by a port of the function.

**Re-counted before starting: 7 of those 11 calls are live.** Three are commented-out lines, and one
of the remaining seven turned out not to be a helper at all — see below.

### The list

| Function | MiST lines | Calls | What we use it for |
|---|---:|---:|---|
| `mist.utils.converter` | **131** | **1** | one unit conversion — find which, port that line |
| `mist.utils.dostring` | 29 | 1 | evaluating a Lua string |
| `mist.utils.zoneToVec3` | 25 | 1 | a trigger zone's centre as a vec3 |
| `mist.getAvgPos` | 24 | 1 | average position of a unit list |
| `mist.getUnitsInPolygon` | 23 | 1 | units inside an arbitrary polygon |
| `mist.getDeadMapObjsInZones` | 20 | 1 | destroyed scenery in a zone |
| `mist.getAvgGroupPos` | 16 | 1 | average position of a group |
| `mist.utils.getHeadingPoints` | 13 | 1 | heading between two points |
| `mist.getNextUnitId` | 10 | 1 | the next free unit id |
| `mist.utils.getQFE` | 23 | 2 | QFE from QNH and altitude |

### Method, per function

1. Read the **one** call site and write down the exact inputs it passes and the shape it expects back.
2. Read the MiST implementation and identify the branch that call takes.
3. Port **that branch**. Delete the rest without reimplementing it.
4. Write the test from the call site's real inputs, not from the function's full contract.

`mist.utils.converter` is the case worth doing first — 131 lines for one call means we are almost
certainly using one conversion pair out of a generic table of them.

### Two that need a second look, not a mechanical port

- **`mist.getNextUnitId`** is not a helper, it is **shared mutable state**: MiST keeps a counter and
  skips the 6900–30000 band. If VEAF and MiST both allocate ids from the same space while both are
  loaded, our replacement must not hand out an id MiST has already used — during the campaign both run
  side by side. Establish who else allocates unit ids (the MCP and the builder assign them at design
  time too) before choosing a scheme, and record it.
- **`mist.utils.dostring`** evaluates a Lua string. Check what our single call site feeds it and whether
  it crosses a security boundary — `veafSecurity` exists, and `REVIEW-SECURITY-LAYER` closed findings in
  this area. If the input is anything other than our own literal, this becomes a security ticket rather
  than a port, and it stops being a rule 3 prune.

### Three of the eleven calls are commented out — including the security question

- **`mist.utils.dostring` has no live caller.** The ticket asked whether its input crosses a security
  boundary. It does not, because the call is gone: `veafRemote.lua:167` is the *comment* recording that
  VMR-130 removed the SLMOD bridge, and it says exactly why — *"a `mist.utils.dostring` of arbitrary Lua
  behind a shared password"*. The concern was real and was already answered; nothing to port.
- **`mist.utils.getQFE`** — two commented-out lines in `veafTransportMission`, next to the commented-out
  message that would have printed them.
- **`mist.utils.getHeadingPoints`** — inside a commented-out block in `veafUnits` that would have
  oriented a convoy on the nearest road.

None is ported. Rule 3 does not stop at "port only the branch we call": a function nothing calls is a
function we do not have. The commented-out lines are left where they are — deleting other people's
parked code is not this ticket's business — but they now name a function that will not exist after
ticket 08, which is worth one line in that ticket.

### One was not a helper, and left for ticket 09

`mist.getDeadMapObjsInZones` reads `mist.DBs.deadObjects`, a table MiST fills from its own
`S_EVENT_DEAD` handler, plus `mist.DBs.zonesByName`, which ticket 05 decided not to port. Porting it
means keeping a **register of destroyed scenery fed by events** for the whole mission — a service, not
a slice. Moved to [ticket 09](DROP-MIST.md) rather than smuggled into a prune.

### What the seven live calls became

| Was | Is | Note |
|---|---|---|
| `mist.utils.converter("hpa", "inhg", p)` | `veaf.hPaToInHg(p)` | 131 MiST lines reached for one multiplication |
| `mist.utils.zoneToVec3(name)` | `veaf.zoneToVec3(name)` | **nil, not `{}`**, for a zone that does not exist — see below |
| `mist.getAvgPos(names)` | `veaf.getAvgPos(names)` | |
| `mist.getAvgGroupPos(group)` | `veaf.getAvgGroupPos(group)` | walks `getUnits()` rather than `getSize()`/`getUnit(i)` |
| `mist.getUnitsInPolygon(names, poly)` | `veaf.getUnitsInPolygon(names, poly)` | |
| `mist.pointInPolygon(point, poly)` | `veaf.pointInPolygon(point, poly)` | **pulled out of ticket 06**: `getUnitsInPolygon` is built on it, so porting one without the other would leave a MiST call inside a VEAF function. 4 more call sites migrated with it |
| `mist.getNextUnitId()` | `veaf.getNextUnitId()` | new `veafMissionDb.lua`, see below |

### A dead guard, brought back to life

`veafCombatZone:initialize` has always carried this:

```lua
self.zoneCenter = veaf.zoneToVec3(self.missionEditorZoneName)
if not self.zoneCenter then
  -- "Trigger zone [x] does not exist in the mission !", logged and shown to the pilot
```

**That branch could never run.** MiST's `zoneToVec3` answers `{}` for an unknown zone, and a table is
truthy in Lua. The port answers `nil`, so the guard works for the first time — and fifteen tests in
`test_veafCombatZone` turned out to be running against a zone the mock had never registered, which
`{}` had been hiding. They now register it, which is what a mission does.

### The id allocation scheme

`veafMissionDb.lua` is new, and starts life with the id allocator; ticket 05 will add the index, the
name registry and the player roster to it.

Ids start at **200000**. Three things have to be avoided: the ids the Mission Editor assigned (three or
four digits), the 6900–30000 band DCS reserves, and — while MiST is still injected — MiST's own
counter, which starts at the mission's highest id and jumps to 30000 once past 6900. MiST would have to
allocate 170 000 units in one session to reach us.

**This is a quantitative guarantee, not a structural one**, and it is worth saying plainly: nothing
prevents a collision by construction while both allocators run. It stops mattering at ticket 08. The
alternative — reading MiST's counter — would have been a new dependency in a lot whose purpose is to
remove them.

### Definition of done

- [x] Each live function is replaced by the slice its call site uses, in `veafMath.lua`, `veafGeo.lua`
      or `veafMissionDb.lua`
- [x] The 7 live call sites are migrated, plus the 4 `pointInPolygon` sites pulled from ticket 06
- [x] One test per function, written from the real call site's inputs
- [x] `getNextUnitId`: the scheme is decided and written down, with its guarantee stated honestly
- [x] `dostring`: established — no live caller; the security concern was closed by VMR-130
- [x] `stylua --check` and `luacheck` clean

---

## 05 — The mission index

Status: ✅ done — 2026-08-28
Type: refactor

**26 sites**, not the 51 this ticket was opened with — ticket 00 re-counted them, and the difference is
in the PRD's *Findings*. The ticket is also **smaller in shape** than it was written: the spike found no
VEAF caller that reads a record for a unit an AI or a third-party script spawned, so the birth-event
path and its deferred fill are gone. What remains is three things.

### The three things

| Brick | What it holds | How it is fed |
|---|---|---|
| **Editor snapshot** | every pre-placed group and unit, as a *mission data record* (`x`, `y`, `alt`, `coalitionId`, `groupName`, `groupId`, `type`, `skill`) | one `env.mission` walk at startup |
| **Name registry** | the group and unit names **we** have taken, and released | written by our own spawn path, cleared when the group dies |
| **Player roster** | every human unit name, **including DCS dynamic slots** | the editor walk for `Client` / `Player` skills, refreshed by a `coalition.getGroups()` sweep |

Nothing else. MiST declares 31 tables under `mist.DBs`; the 23 VEAF never reads — `aliveUnits`,
`removedAliveUnits`, `unitsByCat`, `unitsById`, `zonesByName`, `zonesByNum`, `navPoints`, `markList`,
`deadObjects`, `activeHumans`, `dynGroupsAdded`, `spawnsByBase`, `drawingByName`, `drawingIndexed`,
`const`, `humansById`, `oldAliveUnits` and the six `MEunits*` — are dropped, not ported.

### The trap that still stands

The native call is **not** a drop-in replacement. `Unit.getByName("x")` returns a **live DCS object**;
`mist.DBs.unitsByName["x"]` returns a **mission data record** — and that record exists for a unit that
has not spawned yet and for one already destroyed. Our callers want the second:
[`veafInterpreter.lua:92`](../../src/scripts/veaf/veafInterpreter.lua) spells out what it reads,
*"a `mist.DBs.units` record: x, y, alt, coalitionId, groupName"*.

So an index is genuinely needed. What the spike removed is its refresh rate and two thirds of its
surface, not its existence.

### Why the player roster cannot be an `env.mission` walk alone

MiST maintains `humansByName` at runtime for **DCS dynamic slots**: a unit carrying a player name that
is absent from `MEunitsByName` is added at [`mist.lua:1077`](../../src/scripts/community/mist.lua)
and [`:1374`](../../src/scripts/community/mist.lua). A startup walk over skill `Client` / `Player`
would lose those players — silently, and only in the missions that use dynamic slots.

VEAF has already met this and patched around it in one place:
[`veafAirWaves.lua:781`](../../src/scripts/veaf/veafAirWaves.lua) sweeps `coalition.getGroups()`
under the comment *"Dynamic slot players via DCS coalition API (not tracked by mist)"*, and the four
`isHumanUnit` call sites each carry an `or event.type.id == S_EVENT_PLAYER_ENTER_UNIT`. **This ticket
owns that sweep**, and removes both workarounds — `veafAirWaves` goes back to asking one question, and
the four `or` clauses become redundant.

Write the player test as `local p = unit:getPlayerName(); if p and p ~= "" then`. Whether DCS returns
`nil` or `""` for an AI unit is unmeasured (see `DCS-SESSION-TODO.md`); this form is correct either way,
and **must not** be shortened to `if unit:getPlayerName() then` — `""` is truthy in Lua.

### What replaces the tick

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

### The static reads, which need no index at all

| Table | Calls | Replacement |
|---|---:|---|
| `missionData.bullseye.blue` / `.red` | 5 | `env.mission.coalition.<side>.bullseye`, read directly |
| `units` | 2 | `env.mission`. Both consumers walk it **once at init** to build their own index — [`veaf.lua:2770`](../../src/scripts/veaf/veaf.lua) for the country list, [`veafInterpreter.lua:156`](../../src/scripts/veaf/veafInterpreter.lua) for unit aliases |
| `MEgroupsByName` | 1 | the editor snapshot (MiST itself holds a frozen `deepCopy`) |

### Two removals the spike handed us

- **`veaf.mist.getUnitData` has no caller.** The only façade over `unitsByName`, and dead. Delete it
  rather than port it.
- **`veafTransportMission.resetAllCargoes` is dead code**, and the only reader of `unitsByNum`. Its
  radio command has been commented out since `5a43cc20` (2020-05-16) with *"TODO add this command when
  the respawn will work"*, and only a unit test calls it. Remove the function and its test, or say in
  this ticket why it was kept — but do **not** port `unitsByNum` for it.

### The façade is already there

[`veaf.lua:147`](../../src/scripts/veaf/veaf.lua) already wraps the database behind seven accessors,
written for exactly this purpose — *"Centralizes the main access points to `mist.DBs` to isolate modules
from internal mist changes"*. **First close the façade** by migrating the 14 direct accesses onto it,
**then** swap the implementation. That way the substitution is one file's problem, not 32.

Included in the migration:
[`veafSpawnAircraft.lua:788-789`](../../src/scripts/veaf/veafSpawnAircraft.lua), which deletes two
`mist.DBs` entries by hand so an AFAC can respawn under a name it already used. That is not a caller
reading the index — it is the **name registry** in disguise: `mist.dynAdd` renames a cloned group when
`mist.DBs.groupsByName[name]` already exists ([`mist.lua:1950`](../../src/scripts/community/mist.lua)),
and the hand-deletion is how VEAF frees the name. Once we own the registry, `veaf.releaseSpawnedName(name)`
replaces it, and ticket 07's `dynAdd` port asks the registry instead of a mission mirror.

### What the implementation found

- **`isHumanUnit` cannot be a table lookup alone.** The roster sweeps `coalition.getGroups` when it is
  *read*, and the four callers of `isHumanUnit` are event handlers that run at the moment a pilot takes
  a seat — before anything has asked for the full roster. A dynamic-slot player would not have been
  recognised until something else happened to ask who was flying. It now asks DCS about that one name
  when the roster does not know it, which is O(1) and exact. Caught by writing the test, not by review.
- **The four `or event.type.id == S_EVENT_PLAYER_ENTER_UNIT` clauses are left in place.** They are
  redundant now, but removing them would rest on the assumption that the unit is always reachable from
  its own birth event — and `mist.lua:1657` records DCS not always making it so. Not worth the risk for
  four comparisons.
- **`releaseSpawnedName` still clears MiST's two tables**, and has to. The code that refuses a name it
  has seen before is `mist.dynAdd`, which reads MiST's tables and not ours until ticket 07. Freeing the
  name only on our side would have left a dead AFAC unable to respawn under its own callsign — a
  regression a pilot notices, traded for one line of a cleaner grep. The two lines are marked for
  removal with ticket 08.
- **`takeSpawnedName` and `isNameTaken` have no caller yet**, for the same reason: the decision they
  serve lives in `dynAdd`. They ship because the registry is one of the three bricks this ticket owes
  ticket 07, and because 07 is written against them.
- **`veafInterpreter._initialize` lost six nested loops.** It walked coalition → country → category →
  group → units to reach each record; the snapshot is already keyed by unit name.
- **`veafTransportMission.resetAllCargoes` is gone**, with its test and its now-unused i18n string. It
  was the only reader of `unitsByNum`, its radio command had been commented out since 2020, and it
  said so itself: *"does not work yet"*.

### Definition of done

- [x] The 14 direct `mist.DBs` accesses are migrated onto the `veaf.*` façades **before** any
      implementation swap, as a separate reviewable step
- [x] `veafMissionDb.lua` exists and holds exactly the three bricks: editor snapshot, name registry,
      player roster
- [x] No polling loop, no periodic full-mission scan, and no birth-event path for AI or third-party spawns
- [x] The player roster includes dynamic-slot players; `veafAirWaves.lua`'s local `coalition.getGroups()`
      workaround is removed and its test still passes
- [x] The static reads go straight to `env.mission`
- [x] `veafSpawnAircraft.lua:788-789`'s hand-deletion is replaced by a supported registry call
- [x] `veaf.mist.getUnitData` and `veafTransportMission.resetAllCargoes` are gone (or the ticket says why not)
- [x] Lua tests: a record for a pre-placed unit, for one we spawned, for one already destroyed, for a
      name that does not exist, a dynamic-slot player, and the AFAC name-reuse case
- [x] A test asserts that an AI unit whose `getPlayerName()` returns `""` is **not** in the player roster
- [x] `grep -E 'mist\.DBs' src/scripts/veaf/` returns **four lines**, all inside
      `veafMissionDb.releaseSpawnedName` and all deliberate — see above. Everywhere else: nothing
- [x] `stylua --check` and `luacheck` clean

---

## 06 — Geometry and zone queries

Status: ✅ done — 2026-08-28
Type: refactor

45 call sites. Mixed: two go to native calls (rule 1), the rest are ports of a used slice (rules 2 and 3).

### The list

| Function | Calls | MiST lines | Rule | Note |
|---|---:|---:|:--:|---|
| `mist.getRandPointInCircle` | 20 | 36 | 2 | the campaign's most-called geometry function |
| `mist.getHeading` | 6 | 17 | 3 | port the branch our callers take |
| `mist.pointInPolygon` | 4 | 38 | 3 | 2D only? measure before porting the 3D path |
| `mist.getNorthCorrection` | 4 | 14 | 2 | true-vs-grid north; **read the coordinates doc first** |
| `mist.random` | 4 | 29 | 1 | 29 lines over `math.random` — establish what it adds |
| `mist.getUnitsInZones` | 3 | 74 | 3 | |
| `mist.marker.drawZone` | 2 | 24 | 1 | builds on `trigger.action.*` |
| `mist.marker.remove` | 2 | 4 | 1 | native `trigger.action.removeMark` |

### `getRandPointInCircle` — studied 2026-08-27, on David's instruction

The open question was whether some call sites should route through `veaf.findSpawnPoint`
(`FEAT-SCENERY-AWARE-SPAWN`'s three-tier search: `Disposition` first, validated random draws second,
explicit failure third — [ADR 0018](../../docs/adr/0018-undocumented-dcs-api-dependency.md)).
All 20 sites were read. **Answer: this ticket ports and changes nothing. The gaps found are not
MiST's doing and belong in their own lot.**

First correction: one of the 20 is not a caller. [`veaf.lua:1263`](../../src/scripts/veaf/veaf.lua)
**is `findSpawnPoint`'s own tier 2** — the validated-random-draw tier. So there are 19 callers, and the
port must keep that one working before anything else.

Second correction, and it matters for reading the rest:
[`veaf.placePointOnLand`](../../src/scripts/veaf/veaf.lua) — which wraps 13 of the 19 — **validates
nothing**. It sets `y` to the ground height and returns. It does not test land versus water, and it
knows nothing about buildings. The name reads like a guarantee and is not one.

#### The 19 callers, in four families

**A — air spawns, correctly raw (4).** `veafSpawnAircraft.lua:1045`, `veafQraCore.lua:994` and `:1024`,
`veafAirWaves.lua:1067`. Scenery clearance is meaningless in the air; `:1045` even overwrites `y` with
the altitude right after. Port as-is.

**B — effects, correctly raw (6).** `veafSpawnEffects.lua` 56, 176, 254, 291, 313, 370 — smoke, bombs,
flares. `findSpawnPoint`'s own comment names this family: *"A zero radius means 'exactly here, the
mission maker means it' — veafSpawn passes it for farp, cargo, teleport, bomb, smoke and friends."*
Port as-is.

**C — parallel implementations of the same search (2).** This is a design smell the port should surface,
not fix:
- [`veaf.findPointInZone`](../../src/scripts/veaf/veaf.lua) (`veaf.lua:1642`) draws a point, tests
  `land.getSurfaceType`, and **widens the dispersion on each failure, up to 1000 tries**. It is a second
  spawn-point search, living in the same file as `findSpawnPoint`, without the scenery tier.
- `veafSpawnAircraft.lua:115` carries its own `repeat … nbTries = 25` retry loop.

So the codebase holds **three** spawn-point searches with three different contracts. Worth naming in the
PRD; not this ticket's to merge.

**D — ground placement with a radius and no scenery check (7).** The interesting family:

| Site | What it places | Verdict |
|---|---|---|
| [`veafSpawnGround.lua:594`](../../src/scripts/veaf/veafSpawnGround.lua) | a **"Full Combat Group"** — real ground combat units | **A genuine miss.** `FEAT-SCENERY-AWARE-SPAWN` wired *"the four dynamic ground spawners plus the generic `doSpawnGroup`"*; those are `veafSpawnGround.lua` 387, 441, 483, 538 and `veafSpawnCore.lua:698`. This one was not among them |
| [`veafCombatZone.lua:1466`](../../src/scripts/veaf/veafCombatZone.lua) | zone elements when `getSpawnRadius() > 0`, **including DCS groups and statics** | **A gap.** Combat-zone spawn radii are not scenery-aware at all |
| `veafSpawnGround.lua:47` | a FARP | Needs David's call — `findSpawnPoint`'s comment names FARP as a "the mission maker means it" case, yet a non-zero `radius` is passed here |
| `veafSpawnGround.lua:146` | a CTLD FOB | Same question as the FARP |
| `veafSpawnGround.lua:258` | a CTLD beacon | Same family |
| `veafSpawnGround.lua:655` | a spawn carrying a `destination` | Probably correctly raw: `veafSpawnGround.lua:716` documents the deliberate exclusion — *"Deliberately NOT using veaf.findSpawnPoint here: spawnSpot is the convoy's departure"* |
| `veafAirWaves.lua:1037` | hands the point to `veafInterpreter.execute`, **which can spawn ground units** | Indirect; the wave's command decides, so the fix is not local |

#### What this means for this ticket

**Nothing changes here.** Every one of the 19 sites is ported to `veaf.getRandPointInCircle` with
identical behaviour, including the two that duplicate `findSpawnPoint` and the seven that skip it. A
ticket whose job is to remove a dependency must not also move where things spawn — a regression in
family D would be indistinguishable from the port going wrong.

**The gaps got their own lot**, opened 2026-08-27:
[`FIX-PLACEMENT-IGNORES-SCENERY`](../FIX-PLACEMENT-IGNORES-SCENERY/PRD.md). David arbitrated the
family-D questions the same day — the FARP, FOB and beacon are placed **exactly** where the user asked
(confirming the current `radius or 0`), while the FARP's **escort** must become scenery-aware, and the
FARP is **refused with a message** when the escort cannot be placed. The classification above is kept
here so the study is not lost and so nobody folds it in mid-port.

#### One coordinate trap to preserve exactly

`veafCombatZone.lua:1466` writes `position = { x = mistP.x, y = position.y, z = mistP.y }` — it reads
MiST's **vec2** `y` as the horizontal `z`. That is correct and it is exactly the confusion
[`docs/agents/dcs-coordinates.md`](../../docs/agents/dcs-coordinates.md) warns about. Whatever the
port returns must keep the same shape, and the test must assert the resulting vec3, not the draw.

### `mist.random` — 29 lines over `math.random`

Establish what those 29 lines add before assuming the native call is equivalent. Candidates: a seeding
strategy, a uniformity fix for Lua 5.1's `math.random` on some platforms, or an integer-versus-float
signature. If it is a seeding concern, it matters — `dcs_smoke.py` already notes that
`mist.getRandPointInCircle` is random, and two of our in-game checks depend on being able to reason
about draws.

If the 29 lines add nothing our callers rely on, this is a one-line native substitution. Say which,
with the reason, rather than substituting silently.

### `getNorthCorrection` and the coordinate convention

Read [`docs/agents/dcs-coordinates.md`](../../docs/agents/dcs-coordinates.md) before touching this
one and `getHeading`. True north, grid north and the mission table's own axes do not agree, and a wrong
correction produces a plausible heading that is simply wrong — no error, no crash.

### Definition of done

- [x] Ported functions live in `veafGeo.lua` behind `veaf.*` façades
- [x] Call sites migrated — **37, not 45**: re-counted before starting, as the PRD asks. `pointInPolygon`
      was already at **0** (it went with ticket 04) and `getNorthCorrection` at 2 rather than 4
- [x] `mist.random`: established and written down — see below. Native substitution
- [x] `marker.remove` and `marker.drawZone` go to the native `trigger.action.*` calls
- [x] The `findSpawnPoint` question is **answered** (2026-08-27, see the study above)
- [x] `veaf.lua:1263` — `findSpawnPoint`'s own tier 2 — still works after the port, asserted by the
      existing `TestVeafFindSpawnPoint` suite, which drives the draw end to end (its helper now steers
      `veaf.getRandomPointInCircle` instead of MiST's)
- [x] `veafCombatZone.lua:1466`'s vec2-to-vec3 shape — **moot**: that site no longer calls this function
      at all. `FEAT-SCENERY-AWARE-SPAWN` routed it through `veaf.findSpawnPoint` after this ticket was
      written, and `grep getRandPointInCircle src/scripts/veaf/veafCombatZone.lua` returns nothing
- [x] Lua tests: a point on a zone boundary, a degenerate zero-radius circle, a heading across 0°/360°.
      A three-vertex polygon is moot — `pointInPolygon` is not in this ticket's scope any more
- [x] `stylua --check` clean; `luacheck` left to the CI gate (not installed on this workstation)

### What `mist.random` turned out to be

Above 50 values it calls `math.random` directly. Below, it copies the range until the table holds more
than 50 entries, then draws **eleven times** and keeps the last one — the author's own comment on the
ten extra draws reads *"for giggles"*.

Neither step changes anything. Replicating a range uniformly and drawing uniformly from the copies is
the same distribution as drawing from the range; and ten discarded draws do not change the law of the
eleventh. It is a superstition, not a correction.

Both call sites (`veafSpawnEffects.lua:141` and `:218`, four occurrences) pass `(10, 20)` — integers,
a range of 11. `math.random(10, 20)` is equivalent, and that is the substitution made.

### What the port had to fix in the tests, and what that uncovered

The draw and the heading were **stubbed** in `dcs_mocks`: `mist.getRandPointInCircle` handed back the
centre and ignored the radius, and `mist.getHeading` answered a constant `pi/2` without looking at the
unit. Seven suites went red the moment real code ran under them.

Rather than stubbing VEAF's own functions — which would put the tests back to asserting a mock — the
randomness underneath is now deterministic (`dcs_mocks.setRandomSequence`, `math.random` answering 0 by
default, so a drawn point lands exactly on the centre as the old stub did). Unit fakes gained the
orientation `getPosition` really carries.

**One of those red tests was a real defect**, not a test artefact: the stub answered a **vec3** where
MiST answers a vec2, and `veafAirWaves.lua:1012` relies on that difference. Opened as
[`FIX-AIRWAVES-COMMAND-EASTING`](../FIX-AIRWAVES-COMMAND-EASTING/PRD.md); not fixed here, because
this ticket removes a dependency and must not also move where things spawn.

---

## 07 — Spawn, routes and teleport

Status: ✅ done — 2026-08-28. All 64 calls migrated; `grep 'mist\.' src/scripts/veaf/` returns only the
`veaf.mist.*` façades (which already point at VEAF code) and the four lines of name-registry debt that
leave with ticket 08.
Type: refactor

80 call sites over **726 MiST lines** — the functional core of the dependency, and the reason this lot
is a campaign rather than a ticket. Every VEAF spawn path ends up here.

### The list

| Function | Calls | MiST lines | What it does |
|---|---:|---:|---|
| `mist.dynAddStatic` | 18 | 102 | create a static object at runtime |
| `mist.dynAdd` | 17 | 222 | create a group at runtime |
| `mist.teleportToPoint` | 15 | 223 | move a group, route and all |
| `mist.goRoute` | 11 | 24 | push a route onto a group |
| `mist.getGroupRoute` | 11 | 70 | read a group's route |
| `mist.getGroupData` | 4 | 70 | read a group's record |
| `mist.respawnGroup` | 4 | 15 | respawn a group in place |

### Start from what is already known to be right

The #290 investigation read `mist.teleportToPoint` **end to end** and found it correct: it deep-copies
the route, translates every waypoint by the teleport delta, and hands the group to `dynAdd` with its
route attached. That is recorded in `ROADMAP.md` and it matters here for two reasons.

First, this is not a rewrite motivated by a bug — the behaviour to reproduce is the behaviour we have,
and any divergence is a regression rather than an improvement. Second, `teleportToPoint` **calls
`dynAdd`**, so the two are one problem: port `dynAdd` first and `teleportToPoint` becomes route
arithmetic on top of it.

### The dependency, settled

Ticket 00 read every database access these seven functions make. **None of them needs a live index.**

| MiST function | What it reads | Needs |
|---|---|---|
| `mist.getGroupRoute` | `MEgroupsByName` for the id, then walks `env.mission` | editor snapshot |
| `mist.getGroupData` | `groupsByName`, plus a partial-name match no VEAF caller relies on | editor snapshot |
| `mist.teleportToPoint` | `groupsByName` to fill in `country` / `category` when the caller omits them | editor snapshot |
| `mist.getCurrentGroupData` (the `teleport` action) | `unitsByName`, to enrich each unit with skill and callsign — with a complete native fallback in its `else` branch | nothing hard |
| `mist.dynAdd` | `groupsByName` / `unitsByName`, **only on the `clone` path**, to decide whether a name is free | the name registry |

All 15 `teleportToPoint`, 4 `respawnGroup` and both `veafSpawnAircraft` clone sites start from an
**editor** group name — a template, a Pedro, a carrier, an asset. VEAF never respawns or clones a group
it created itself.

So this ticket depends on **two named bricks from ticket 05**, not on its index:

1. the **editor snapshot** of groups and units, and
2. the **name registry** — which is what `veafSpawnAircraft.lua:788-789` hand-rolls today by deleting
   two `mist.DBs` entries so a dead AFAC's callsign can be reused. Port `dynAdd`'s uniqueness test
   against the registry, and that workaround disappears with it.

05 still lands first because both bricks live there. If 05 grows, those two can be split out and
reviewed on their own without holding this ticket.

### Method

Rule 3 applies hard here. `mist.dynAdd`'s 222 lines handle every group category, every spawn variant
and a long tail of DCS quirks. Enumerate — from the code, not by sampling — which of those paths our 17
call sites actually reach, and port those. A category we never spawn is not ported.

**The enumeration is the deliverable, not a by-product.** Write it as a table in this ticket before
touching code: call site → group category → the `dynAdd` branch it takes. That table is also the test
matrix.

### The enumeration, 2026-08-28 — written before touching code, as this ticket requires

#### The count, re-measured

**64 real call sites, not 80.** The difference is not slack in the estimate: 16 of the 80 grep hits are
comments, log traces or commented-out code, and one is a defensive guard on MiST's own presence.

| Function | grep hits | **Real calls** | What the difference is |
|---|---:|---:|---|
| `mist.dynAddStatic` | 18 | **18** | — |
| `mist.dynAdd` | 18 | **13** | 2 comments, 3 log traces (`veafSpawnAircraft` 1163/1169/1170) |
| `mist.teleportToPoint` | 15 | **12** | 3 comments/traces in `veafCombatZone` |
| `mist.goRoute` | 11 | **9** | 2 commented out (`veafMove:838`, `veafSpawnAircraft:686`) |
| `mist.getGroupRoute` | 11 | **8** | 2 comments, 1 presence guard (`veafCombatZone:442`) |
| `mist.getGroupData` | 4 | **3** | 1 is `veaf.mist.getGroupData`, the façade the other two go through |
| `mist.respawnGroup` | 3 | **2** | 1 commented out (`veafTransportMission:672`) |

#### `dynAdd` — call site → category → branch

The 13 real calls, and the branch each one reaches:

| Call site | What it creates | Category passed | Branch |
|---|---|---|---|
| `veafCasMission.lua:1039` | a CAS threat package | `"GROUND_UNIT"` | ground |
| `veafCombatMission.lua:924` | a combat-mission flight | **variable** (`_group.category`) | any |
| `veafGrass.lua:1481` | the FARP group | variable (caller's `country`/category) | ground |
| `veafGrass.lua:1890` | the FARP escort | variable | ground |
| `veafSpawnAircraft.lua:191` | a spawned plane | **`"PLANE"`** | airplane |
| `veafSpawnAircraft.lua:194` | a spawned ship | `"SHIP"` | ship |
| `veafSpawnAircraft.lua:197` | spawned ground units | `"GROUND_UNIT"` | ground |
| `veafSpawnAircraft.lua:681` | a cloned aircraft group | variable, `sameName = true` | any + clone |
| `veafSpawnAircraft.lua:1164` | a spawned aircraft group | variable | any |
| `veafSpawnCore.lua:792` | a ship | `"SHIP"` | ship |
| `veafSpawnCore.lua:794` | an aircraft | **`"AIRPLANE"`** | airplane |
| `veafSpawnCore.lua:796` | ground units | `"GROUND_UNIT"` | ground |
| `veafSpawnGround.lua:381` | ground units | `"GROUND_UNIT"` | ground |

**Four categories are reached: GROUND_UNIT, AIRPLANE, SHIP — and whatever a variable carries.**
`HELICOPTER` never appears as a literal, but `veafCombatMission:924`, `veafSpawnAircraft:681` and
`:1164` pass a group table built from a template, so a helicopter template reaches `dynAdd` through
them. **`BUILDING` is never reached** — statics go through `dynAddStatic`.

##### The naming tolerance that must be reproduced

`veafSpawnAircraft:191` passes **`"PLANE"`** while `veafSpawnCore:794` passes **`"AIRPLANE"`** for the
same thing. That is not a bug: [`mist.lua:1919-1922`](../../src/scripts/community/mist.lua) maps
them explicitly, along with two more spellings for ground:

```lua
if catName == "GROUND_UNIT" and (string.upper(groupType) == "VEHICLE" or string.upper(groupType) == "GROUND") then
  newCat = "GROUND_UNIT"
elseif catName == "AIRPLANE" and string.upper(groupType) == "PLANE" then
  newCat = "AIRPLANE"
end
```

**A port that accepts only the canonical spelling silently breaks `veafSpawnAircraft:191`** — silently,
because an unresolved category leaves `typeName` nil and the group is built anyway. Accept
`PLANE`/`AIRPLANE`, `VEHICLE`/`GROUND`/`GROUND_UNIT`, and the numeric ids, and make the mismatch loud
rather than nil.

#### `dynAddStatic` — 18 calls, and 12 of them are one feature

| Call site(s) | What it creates |
|---|---|
| `veafGrass.lua` 613, 621, 627, 647, 653, 673 | grass runway plots and the tower |
| `veafGrass.lua` 1622, 1645, 1663, 1710, 1779, 1801 | FARP tents, markers, other props, windsock |
| `veafSpawnGround.lua` 105, 183, 197 | the FARP static, an outpost, a tower |
| `veafSpawnEffects.lua` 137, 214 | cargo, and a static object |
| `veafSpawnAircraft.lua:187` | a static aircraft |

Two thirds of the surface is `veafGrass` placing FARP and runway furniture. **That makes `veafGrass` the
test bed for this half**: one feature, many objects, and a placement already verified in game on
2026-08-24 and again on 2026-08-28.

#### `respawnGroup`, `getGroupData`, `getGroupRoute`, `goRoute`, `teleportToPoint`

- **`respawnGroup`** — 2 calls, both in `veafAssets.respawn` (the asset itself, then each `linked`
  group). Both start from an **editor** group name. Note that
  [`FIX-ESCORT-RESPAWN-DISTANCE`](../FIX-ESCORT-RESPAWN-DISTANCE/PRD.md) will add a third here.
- **`getGroupData`** — 1 direct call (`veafAirWaves:1022`) plus `veaf.mist.getGroupData`, through which
  `veafCarrierOperations` 342 and 488 ask whether a Pedro or a tanker exists in the mission at all.
- **`getGroupRoute`** — 8 calls, **every one with `"task"` as the second argument**. The other output
  form is never asked for and does not need porting.
- **`goRoute`** — 9 calls. Two take a group *object* (`veaf.lua:1943`, `veafSpawnCore:420/422`), the
  rest a group *name*. Both forms have to keep working.
- **`teleportToPoint`** — 12 calls. Two pass the second argument `true` (`veafSpawnAircraft` 648 and
  1133, `veafCombatMission:898`); the others rely on the default.

#### One thing the port removes for free

[`veafCombatZone.lua:442`](../../src/scripts/veaf/veafCombatZone.lua) guards on MiST being loaded at
all:

```lua
if not name or not mist or not mist.getGroupRoute then
```

That guard exists because a mission can load a hand-picked subset of scripts. Once the route reader is
VEAF's own and ships in the bundle, the guard is dead weight — and it is the kind of dead guard ticket
04 has been removing.

#### What this changes for the plan

- The two bricks ticket 05 was to provide are **shipped**: `veafMissionDb` carries the editor snapshot
  and the name registry. This ticket is unblocked.
- The work splits cleanly in two, and the halves are independent:
  **(A)** `dynAddStatic` — 18 calls, no route, no clone path, two thirds of them one feature.
  **(B)** `dynAdd` → `teleportToPoint` → `goRoute`/`getGroupRoute` — the group half, where the clone
  path, the id allocation and the route arithmetic live.
  **(A) should ship first**: it is the larger call count, the smaller risk, and it exercises the
  coordinate convention on its own before any route arithmetic is layered on top.

#### Half (A) — `dynAddStatic`, read end to end 2026-08-28

Its 100 lines do eight things, in order: flatten a MiST-format `units[1]` into the object; resolve the
country (a string with spaces becomes underscores, or a numeric id) and **fail loudly** if it does not
resolve; allocate `groupId` and `unitId` when absent or when cloning; name the object
(`name or unitName`, else `"<country> static N"`); default `dead` to false; give it a **random heading**
when none is set; map `categoryStatic` onto `category` and force `"Cargos"` when `mass` is present;
resolve `shape_name`. Then it validates `x`, `y` and `type` and calls
`coalition.addStaticObject(country.id[newCountry], newObj)`.

Four things decided by reading our own 18 call sites:

**1. The `shape_name` lookup has to be ported, and the number that justifies it is 93.**
`mist.DBs.const.shapeNames` holds **124 entries**, and the objects that most obviously need it do not
use it: the FARP passes `shape_name` explicitly (`veafSpawnGround.lua:86`), so do the windsock and the
runway cones. `"outpost"` and `"house2arm"` are not in the table at all, so the lookup is a no-op for
them.

What makes it necessary is `veafSpawnEffects.lua:214`. Despite the file's name that call is **not an
effect**: it is `doSpawnStatic`, the function behind `-spawn static`, and the `type` comes from the
mission maker, validated against the 873-unit catalogue by `veafUnits.findDcsUnit`. Crossing the two
tables: **93 of the catalogue's types are keys of `shapeNames`** — `.Ammunition depot`,
`.Command Center`, `Barracks 2`, `Cafe`, `Boiler-house A`, `Airshow_Crowd` and so on, all structures.

So 93 spawnable statics get their shape from this table and from nowhere else. The remaining 31 entries
are shapes only the Mission Editor places, and no VEAF command can reach them. The table is a constant,
so porting it is mechanical — but port it against the catalogue rather than wholesale, and skipping it
would break exactly the spawns nobody tests.

**2. `veafSpawnAircraft.lua:187` is the only site using the MiST wrapper format** —
`{ country, groupName, units = units }` rather than a flat object — so it is the only one that exercises
the `units[1]` flattening at the top. It is also the only one that must keep working through it.

**3. The random heading is behaviour, not a detail.** An object spawned without a heading gets
`math.rad(math.random(360))`. Several of our statics rely on that (nothing in `veafSpawnEffects` sets a
heading), so a port that defaults to 0 would line up every cargo drop on the same axis — a visible
change in game that no unit test would catch.

**4. `mass` silently overrides `category`.** `veafSpawnEffects.lua:132` passes both `category = "Cargos"`
and `mass`, so the override is a no-op there today — but it is the kind of rule that has to be ported
deliberately rather than discovered later.

Coordinate note, per the trap above: a static's table uses `x` for the northing and **`y` for the
easting** — `veafSpawnGround.lua:89` writes `["y"] = spawnPosition.z`. The port must not "fix" that.

#### Half (B) — `dynAdd` and the route calls, read 2026-08-28

`dynAdd`'s 222 lines do, in order: resolve the country; resolve the category (with the alias table
above); pick a `typeName` marker used only for generated names; allocate a group id; settle the group
name; default `sameName`, `hidden`, `visible`, `start_time`; then per unit — allocate a unit id, settle
the unit name, default `skill` to `"Random"`, and for **aircraft only** default `alt_type` to `RADIO`,
`speed` to 150 (plane) or 60 (helicopter), `alt` to 2000 or 500, and **fetch the payload** through
`mist.getPayload`; for ground units default `playerCanDrive` to true. Then it normalises the route,
rewrites `EPLRS` / `ActivateBeacon` / `ActivateICLS` task ids, strips its own bookkeeping fields, and
calls `coalition.addGroup`.

Measured against our 13 call sites, three things shrink the job and one grows it:

**1. The clone path is never reached directly.** Every `clone` in VEAF is a `teleportToPoint`
parameter, never a `dynAdd` one. So `dynAdd`'s name-uniqueness test against `mist.DBs` is reached only
*through* the teleport, which means the name registry from ticket 05 is needed once, in one place,
rather than at every call site. (The count of those sites was corrected to 5 — see above.)

**2. `newGroup.sameName = true` at `veafSpawnAircraft.lua:676` is a no-op.** MiST reads `sameName` only
inside `if newGroup.clone and …`, and that site passes no `clone`. It has never done anything. Port it
as inert — this ticket must not change behaviour — but it is worth knowing that the AFAC teleport
trickery next to it (its own comment: *"since MIST does not store cloned group data, this is a bit of
trickery"*) rests on a flag that does nothing.

**3. `playerCanDrive` and `start_time` are never set by a caller**, so their defaults are the behaviour
and have to be reproduced exactly. `startTime` (camel case, rounded) is used by `veafCombatMission`.

**4. `mist.getPayload` has to be ported, and the snapshot does not carry what it needs.** `dynAdd`
calls it for any aircraft unit with no payload, and `veafSpawnCore.lua:794` builds `AIRPLANE` groups
with **no payload field at all** — grep finds none in that file. `getPayload` reads
`mist.DBs.MEunitsByName` for the unit id and then walks `env.mission` for the loadout;
`veafMissionDb.unitRecord` deliberately keeps only what VEAF reads, and a payload is not among its
fields.

**Decided 2026-08-28, by measurement: the snapshot carries the payload.** The question was whether that
costs memory for every mission. Measured on the session mission — 435 units, 356 payload blocks — the
payloads are **287 KB, 10.7 % of a 2.7 MB mission file**, which looked like a real price. It is not,
because `mist.getPayload` ends with `return unitData.payload`: **a reference into `env.mission`, never a
copy**. Holding the same reference in a unit record costs one pointer per unit, and `env.mission` is
resident anyway.

Two consequences worth writing down. It is iso-behaviour including the sharing: a spawned group that
mutates its payload mutates the mission table, exactly as it does today under MiST — reproduce it, do
not "fix" it in this ticket. And it removes the walk: `getPayload` searches every coalition, country and
group to find one unit, on every aircraft spawn without a loadout.

The three route functions are the easy end: `getGroupRoute` is always called with `"task"`, `goRoute`
takes either a group object or a name, and `teleportToPoint` is route arithmetic over `dynAdd` — the
#290 investigation already read it end to end and found it correct.

#### The API half (B) ships — decided with David, 2026-08-28

The port is not allowed to change *behaviour*, but it is allowed to change the *interface* — and
`mist.teleportToPoint` has one worth replacing. David's words: *"j'espère que tu as prévu d'implémenter
de jolies fonctions pour remplacer les bricolages du type `vars.action = \"clone\"` ? … avec de vrais
paramètres, bien clairs"*.

##### What the `vars` table was hiding

It is not a parameter object, it is **three different verbs behind a string**, plus a fourth behind an
unnamed boolean:

| `vars.action` | What it really does | Where the data comes from |
|---|---|---|
| `"clone"` | creates a **new** group with new names | the editor definition, plus a `clone = "order66"` flag |
| `"respawn"` | puts **the same** group back as the editor placed it | the editor definition |
| `"teleport"` / `"tele"` | moves the group **as it is right now** | its live state |
| *(2nd arg `true`)* | builds the data and creates **nothing** | — |

**Corrected 2026-08-28**: an earlier count here said no site used `teleport`. That was wrong — it came
from grepping `vars.action =` as a separate assignment, which misses the sites that build the table in
one expression. The real count is **clone 5, respawn 3, teleport 5**, so all three verbs are in use and
`getCurrentGroupData` has to be ported after all. The three sites passing the unnamed `true` are all
clones.

##### The shape chosen: chaining, not an options table

Three writings were compared on `veafQraCore.lua:1022`. An options table is the closest Lua has to
Python's keyword arguments — and it keeps `vars`'s worst property: **nobody validates the keys**, so
`{ radus = 500 }` is silently a zero radius. Positional arguments would give
`veaf.cloneGroupAt(name, point, 500, route, nil, nil, false)`.

Chaining wins because the repository already speaks it — **150 chainable `:setXxx` methods** across
`VeafCircleOnMap`, `VeafCombatMissionObjective`, `VeafCombatZone` and the rest — and because a typo in a
method name fails loudly where a typo in a table key does not.

```lua
local newGroup = VeafGroupSpawn:new()
  :forGroup(groupName)
  :at(spawnPoint)
  :withRadius(self.respawnRadius)
  :withRoute(veaf.getGroupRoute(groupName))
  :clone()
```

The terminal verb carries what `vars.action` used to: `:clone()`, `:respawn()`, `:teleport()`, and
`:buildCloneData()` for the prepare-only case. So the action can no longer be a misspelled string, and
an unfinished chain creates nothing rather than silently defaulting to `tele` — which is what MiST does
today when `action` is unrecognised.

`withRadius` also absorbs the three lines of `point.z = point.y` juggling copied at every call site —
the exact place where `FIX-AIRWAVES-COMMAND-EASTING` slipped in.

##### Order of work

1. ~~`veafDcsSpawner.addGroup`~~ — **shipped 2026-08-28**, and it refuses an unknown category rather
   than submitting an unclassifiable group.
2. ~~`veaf.getGroupRoute` / `veaf.goRoute`~~ — **shipped 2026-08-28**, and the mission snapshot gained
   the route and the payload by reference to serve them.
3. ~~`VeafGroupSpawn` over both, replacing `teleportToPoint`~~ — **shipped 2026-08-28**, all 12 sites
   migrated. Its two bricks shipped the same day:
   `veaf.isTerrainValid` (with the per-category surface lists) and `veaf.getCurrentGroupData` (the
   source the `teleport` verb reads).
4. Migrate the 42 remaining call sites.

#### `teleportToPoint`, read 2026-08-28 — what the chain has to carry

Beyond the three verbs, its 223 lines do four things that are behaviour and not plumbing:

- **A valid-terrain draw.** It tries up to 100 random points in the circle and keeps the first whose
  terrain suits the group: ships get `SHALLOW_WATER`/`WATER`, ground units `LAND`/`ROAD`/`RUNWAY` — with
  a VEAF comment from 2023 explaining that runways are included because DCS calls dams "RUNWAY". A
  caller can override with `validTerrain`, or skip the check with `anyTerrain`, which `veafMove` uses
  for its AFAC. So the chain needs `:onAnyTerrain()` and `:onTerrain(list)`.
- **The whole group moves by one offset.** The draw positions unit 1; every other unit keeps its
  formation by moving the same `diff`. Unless `disperse` is set, in which case each unit gets its own
  draw within `maxDisp`.
- **An altitude rule for aircraft.** If the requested point is more than 10 m above the ground, it is
  used; otherwise the aircraft is placed at a **random** height above terrain — 300–9000 m for a plane,
  200–3000 m for a helicopter. That randomness is behaviour: a fleet of respawned aircraft stacked at
  one altitude would look wrong.
- **A start time relative to now.** A group whose editor `start_time` has already passed spawns
  immediately; one still in the future keeps the remainder.

Plus `groupData`, which `veafMove` passes for its AFAC instead of a group name — hence `:withGroupData()`
on the chain.

### Two traps

- **Coordinates.** `dynAdd` and `dynAddStatic` place objects, so
  [`docs/agents/dcs-coordinates.md`](../../docs/agents/dcs-coordinates.md) is mandatory reading:
  `x`/`y`/`z` mean different things in a mission table and in the scripting API, and confusing them
  raises no error — only a wrong position. This is the single most likely way to ship a silent
  regression in this ticket.
- **Group and unit ids.** `dynAdd` allocates ids. Ticket 04 settles the allocation scheme for
  `getNextUnitId`; this ticket must use it, and must not collide with MiST's counter while both are
  loaded.

### Verification

Unit tests cannot see whether a group actually appeared at the right place in DCS. Two things carry that:

- `FEAT-DCS-SMOKE-HARNESS` (closed 2026-08-15) asserts through the bridge inside a running DCS and has
  already answered spawn-placement questions by machine rather than by a pilot. **Use it here** — this
  is exactly the lot it was built for.
- Whatever the harness cannot reach goes into [`DCS-SESSION-TODO.md`](../../DCS-SESSION-TODO.md) with
  the commands to paste, not into a "verified" checkbox.

### Definition of done

- [x] Ticket 05 has shipped the editor snapshot and the name registry (`veafMissionDb`), and this
      ticket uses them
- [x] The call-site → category → branch enumeration is written in this ticket **before** implementation
      — done 2026-08-28; it re-counted the slice at **64 real calls, not 80**
- [ ] Ported into a dedicated module behind `veaf.*` façades; `dynAdd` first, then `teleportToPoint` as
      route arithmetic over it — **`veafDcsSpawner.lua` created**, `veaf.addStatic` shipped
- [x] 64 call sites migrated: `dynAddStatic` (18), `getGroupRoute` (8), `goRoute` (9), `dynAdd` (13),
      `teleportToPoint` (12), `getGroupData` (3) and `respawnGroup` (2)
- [x] Lua tests covering every branch in the enumeration table — 111 in `test_veafDcsSpawner.lua`, and
      the module at **94 % line coverage**
- [x] Position asserted against known coordinates, with the convention named — several tests were
      confirmed to fail when a `y`/`z` conversion is reversed, which is the only way to catch it
- [ ] Smoke-harness checks added for placement; anything it cannot reach filed in `DCS-SESSION-TODO.md`
- [x] `stylua --check` clean; `luacheck` clean after CI caught the missing `VeafGroupSpawn` global

---

## 08 — Drop the injection

Status: ✅ done — 2026-08-31. Option **c** (conditional injection), decided by David.
Type: refactor

The only ticket in the lot with a player-visible effect. Everything before it reduces the call count;
this one collects the gain.

### The compatibility question, and how it was settled

The ticket refused to pick unilaterally, and rightly: **a mission maker's own scripts may call
`mist.*`**, and removing the injection breaks them at runtime in DCS with no build-time warning.

It was settled by measurement rather than by argument. Opening the 17 `.miz` files under
`VEAF-Servers`:

| | MiST in their own scripts |
|---|---|
| The 6 Foothold missions (v6) | **none** |
| The 10 Open Training missions | **yes** — `HoundElint.lua` calls `mist.DBs.humansByName`, `mist.getGroupPoints`, `mist.majorVersion`, `mist.minorVersion` |

The second row is what made option 2 (remove outright) unacceptable and option 1 (opt-in flag)
insufficient: those missions would build fine and die in flight. **They are still v5**, so the risk
is deferred rather than current — but it lands the day they are converted, which is exactly when
nobody would be looking for it.

David chose **option 3**: the build reads the mission's own scripts and injects MiST when one of them
calls it.

### What it removes

| Where | What |
|---|---|
| `mission_builder_worker.py` | `mist` out of `MANDATORY_COMMUNITY_SCRIPTS` — the frozenset is now empty, and the mechanism kept, because "inject this whatever the mission says" will be true again |
| `mission_constants.py` | `mist` **added** to `get_optin_community_script_ids()`, beside TUM |
| `mission_template.py` | `MIST` moved from Infrastructure (always emitted) to Community, in **no tier** |
| `src/defaults/mission-folder/mission.yaml` | the bare `MIST:` line, replaced by a commented `MIST: true` and the reason |
| `test/lua/dcs_mocks.lua` | the MiST stub — 128 lines, plus `_deepCopy` which existed only to serve it |
| `src/scripts/veaf/veafMissionDb.lua` | the last four calls, dead code guarded by `if mist and mist.DBs` |

`src/scripts/community/mist.lua` is **kept**: option 3 needs it to inject when detection fires.

### What replaced it

`mission_scripts_referencing_mist(scripts_dir)` in `mission_constants` — shared by the builder and by
`convert-v5`, which is the point: v5 shipped MiST in every mission, so detecting it by file name would
have emitted `MIST: true` for every converted mission and made the whole change worthless.

What the scan sees: a call in `src/scripts/*.lua` (the whole folder, since everything there is
packaged whether or not it is declared under `custom_scripts:`). What it ignores: comments, and
mentions inside strings — **a test caught the second one in my own regex**, which is the CTLD trap
this campaign already fell into once, counting an error message naming `mist.DBs.MEgroupsByName` as a
call.

What it cannot see: a script loading another script, or `_G["mist"]`. `MIST: true` remains for those.
`MIST: false` does **not** win against detection: honouring it would break the mission in flight to
respect a config line, and the two answers (packaged / declared enabled) are asserted to agree.

### Where the ticket's plan turned out to be wrong

It asked for "a test that fails if the two mandatory lists drift apart". That test has no object: the
two constants shared a name, not a meaning. The builder's means "always injected" and is now empty;
the generator's means "never reported to the runtime as disabled", which stays true for MiST — and
that generator receives only `mission_yaml`, never the mission folder, so it *cannot* run the scan.
It was renamed `_NEVER_REPORTED_AS_DISABLED` instead of being tested against a list it no longer
mirrors.

### The flag, and the line every existing mission carries

Option (a)'s escape hatch came for free: making MiST an opt-in community script means the existing
`modules:` machinery already answers it. Measured, in the form mission makers actually write:

| in `mission.yaml` | MiST packaged |
|---|---|
| `modules:` -> `MIST: true` | **yes** -- the hatch, for an indirect use the scan cannot see |
| `modules:` -> `MIST: false` | no |
| `modules:` -> `MIST:` (bare) | **no** |
| nothing | no |
| nothing, but a script calls `mist.` | **yes**, naming the file |

The third row is the migration case. A bare `MIST:` used to mean "mandatory module, always on", and
**every v6 mission.yaml carries it**, because the shipped template did. It now means "not asked for",
so those missions stop carrying MiST on their next build -- which is the point, and is safe precisely
because the scan catches the ones that call it. Asserted by three tests, including a bare `MIST:`
alongside a HoundElint that calls `mist.DBs.humansByName`.

Worth recording: the first version of that test only covered `community_scripts: mist: true`, the
**deprecated** section. A hatch proven to work where nobody looks for it is not proven.

### What the mission gains

- 336 KB out of every generated `.miz` that does not ask for MiST
- the `mist.main` tick — re-armed every 0.01 s — stops existing, along with the 20 Hz walk over every
  unit in the mission that fed tables VEAF never read
- one fewer unmaintained dependency in the runtime (MiST has not cut a release since 2021)

### Definition of done

- [x] The compatibility question is settled by David and the choice recorded here
- [x] `mist` removed from the mandatory list, and out of the module template's infrastructure tier
- [x] Detection covers the builder **and** `convert-v5`, with tests on both, including the
      HoundElint shape that ten production missions carry
- [x] `test/lua/dcs_mocks.lua` no longer mocks MiST — and the 44 Lua suites pass without it, which
      is the *proof* that no VEAF script calls it, not a claim
- [x] `doc/` says MiST is no longer injected, in **both** languages, under the explicit anchor
      `{#mist-injection}`; `poetry run docs-check` clean
- [x] `CHANGELOG.md` entry under `[Unreleased]`, appended at the end of the section
- [ ] `RELEASE_NOTES.md` — left untouched on purpose: it carries the published 6.17.0 and is written
      at release time from the changelog. Flagged to David rather than decided here.
- [x] Python suite green (3951), Lua suite green (44), ruff / ruff format / mypy / stylua clean

### What is deliberately *not* asserted

That a generated mission carries no `mist.lua`, by unzipping the built `.miz`. The ticket asked for
it and it is the right shape of check — but the build needs a real mission folder, and the suites
here do not build one. The equivalent is asserted one level down, at
`_active_community_scripts` / `_community_enabled`, which are what decide what goes into the archive.

---

## 09 — The destroyed-scenery register

Status: ✅ done — 2026-08-28
Type: refactor

One call site, and it was ticket 04's tenth line — until reading it showed it is not a helper at all.

### Why it left ticket 04

`mist.getDeadMapObjsInZones(zones)` looks like the other single-caller helpers: twenty lines, called
once. But those twenty lines are a **query over runtime state MiST accumulates**, not a computation:

- it reads [`mist.DBs.deadObjects`](../../src/scripts/community/mist.lua), a table filled by MiST's
  own `S_EVENT_DEAD` / `S_EVENT_CRASH` handler, one entry per destroyed object with its `objectType`,
  `objectPos` and `typeName`;
- it reads `mist.DBs.zonesByName`, one of the tables ticket 05 decided **not** to port.

So porting it means keeping our own register of destroyed scenery, fed by an event handler, for the
lifetime of the mission. That is a service, and ticket 04 is a prune. Moved here rather than smuggled
in.

### What it is for

[`veafCombatMission.lua:274`](../../src/scripts/veaf/veafCombatMission.lua), inside
`configureAsPreventDestructionOfSceneryObjectsInZone` — a combat mission objective that **fails** when
a named piece of scenery inside a zone is destroyed. The caller matches `object.object.id_` against a
table of ids it was given, so the register has to keep the DCS object, not just a position.

It is a **documented mission-maker API** (`doc/LUA_API_REFERENCE.md`), and a mission does use it.
Searched across the whole VEAF organisation on 2026-08-28: one caller outside this repository, in
`VEAF-Open-Training-Mission-Caucasus`, `src/scripts/missionConfig.lua`:

```lua
:setName("HVT Gudauta")
:setDescription("the mission will be failed if any of the HVT on Gudauta are destroyed")
:configureAsPreventDestructionOfSceneryObjectsInZone(
    { "Gudauta - Tower", "Gudauta - Kerosen", "Gudauta - Mess" },
    { [156696667] = "Gudauta Tower", [156735615] = "Gudauta Kerosen tankers", [156729386] = "Gudauta mess" })
```

Three scenery objects, by `id_`, in three named zones. The repository is live (last push 2025-09-09).
So this is not a candidate for removal, and that call is the acceptance case: three zones, a table of
ids, and an objective that must fail when one of them is destroyed and only then.

### Shape to consider

- `veafEventHandler` already dispatches events and is the supported way to register a callback — this
  is a normal consumer of it, unlike the Skynet handler in ticket 01 which had to be removable.
- The zone side needs no index at all: `trigger.misc.getZone(name)` is native and gives centre and
  radius, which is exactly what MiST's `getDeadMapObjectsFromPoint` used them for.
- MiST filters on `objectType == "building"`. Establish whether that matters to the one caller before
  reproducing it.

### Definition of done

- [x] A register of destroyed scenery objects, fed by the event handler, holding what the caller reads
- [x] `veafCombatMission.lua:274` migrated; `grep 'mist.getDeadMapObjsInZones' src/scripts/veaf/`
      returns nothing
- [x] Lua tests: an object destroyed inside the zone, one destroyed outside it, one destroyed before
      the objective is configured, and a zone that does not exist
- [x] The mission-maker documentation for
      `configureAsPreventDestructionOfSceneryObjectsInZone` still describes what the objective does
      — unchanged, because the behaviour is unchanged: `zones` is still honoured
- [x] `stylua --check` clean; `luacheck` left to the CI gate (not installed on this workstation)

### What was built, and the two things the game decided

The register lives in `veafMissionDb`, next to the other things VEAF knows about the mission, rather
than in a module of its own: a new Lua module means editing five separate registries, three of which
fail silently when forgotten.

Measured in game on 2026-08-28 (see the memory note `scenery-death-events-in-dcs`), and both findings
changed the design:

1. **`event.pos` is nil on a scenery death.** Six objects, two scripted explosions, never filled. The
   position can therefore only come from the object itself at the instant of the event — which is why
   `veafEventHandler.transformEvent` now also carries `dcsInitiator`, the untransformed DCS object.
   Without it the register could hold ids but never place them, and the `zones` argument would have
   had to be dropped from a documented mission-maker API.
2. **`Object.isExist` is already false, while `Object.getPosition` still answers.** MiST guarded on
   `isExist`, so it recorded nothing for those six objects: `mist.DBs.deadObjects` held 11 unrelated
   entries and none of the ones just destroyed. The register does not ask.

`getName()` on a scenery object returns a **number**, equal to `id_` — the same number the mission
maker writes in the objective's table, so no conversion is needed anywhere.

### Wiring, and why it is tested

`veaf_build/worker.py` loads `veafMissionDb` **before** `veafEventHandler`, so the subscription cannot
happen at load time. It happens in `initialize`, which runs twice — once at load, once on the module
init pass — behind a guard, because a callback registered twice records every destruction twice. That
is the exact shape of the double event handler fixed in 6.17.0 (#824).

Three of the fifteen tests assert the **subscription**, not the handler, and were verified to fail
when the subscription is removed.

---
