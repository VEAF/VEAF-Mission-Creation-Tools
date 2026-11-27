# FIX-OBJECTIVE-COMPLETION — a zone holding a static completes, the scenery register records

Status: ✅ done · archived 2026-11-24

Found on 2026-10-01 by the test mission of FEAT-OBJECTIVE-MISSION-PROMPT
(`D:\dev\_VEAF\tmp\test-objective-mission`), whose script finds a map object, blows up a static and the
object, and prints a verdict. Two defects older than that lot, both measured in game:

| Run | Read in dcs.log | Means |
|---|---|---|
| 1 | one `VEAF-MISSIONDB … Initializing module`; `scenery_destroyed=no` after three explosions | the destroyed-scenery register never subscribed to `S_EVENT_DEAD` |
| 2 (register subscribed by the test) | static `isExist=false life=0` 10 s and 70 s after its explosion; `static_zone_done=no`; map object destroyed, `scenery_zone_done=YES` | a destroyed static is still returned by `StaticObject.getByName`, and the watchdog counted it |

David's go: 2026-10-01 ("go").

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [the event bus subscribes the destroyed-scenery register](FIX-OBJECTIVE-COMPLETION.md) | ✅ |
| 02 | [a destroyed static no longer counts in a combat zone](FIX-OBJECTIVE-COMPLETION.md) | ✅ |
| 03 | [test mission v3, with no workaround: every line YES](FIX-OBJECTIVE-COMPLETION.md) | ✅ |

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**a combat zone holding a static completes, and the destroyed-scenery register records.** Found in game on 2026-10-01 by the FEAT-OBJECTIVE-MISSION-PROMPT test mission: `StaticObject.getByName` still returns a destroyed static (`isExist` false, life 0) and the zone watchdog counted it, so a zone with a static never completed; and the register of destroyed map objects never subscribed to `S_EVENT_DEAD` since #836 (no mission lists MISSIONDB for its second init). Waiting on the v3 test mission

## Tickets, in full

## 01 — the event bus subscribes the destroyed-scenery register

Status: ✅ done

Files: `src/scripts/veaf/veafMissionDb.lua`, `src/scripts/veaf/veafEventHandler.lua`,
`test/lua/test_veafMissionDb_scenery.lua`.

`veafMissionDb` is loaded before `veafEventHandler`, so its load-time `initialize` finds no bus. The
code counted on a second `initialize` on the module init pass, which the generator only emits for a
mission listing `MISSIONDB` — none does. Since #836 (2026-08-28) the register recorded nothing, so the
Combat Missions' *prevent destruction of map objects* objective could never fail. The wiring tests
called `veafMissionDb.initialize()` by hand, which no mission does.

### Done when

- `veafMissionDb.registerSceneryCallback` is public; `veafEventHandler.initialize` calls it once the
  bus exists. The guard keeps the two callers from subscribing twice.
- Tests: the bus alone subscribes the register; bus + register + bus again subscribe once.

## 02 — a destroyed static no longer counts in a combat zone

Status: ✅ done

Files: `src/scripts/veaf/veafCombatZone.lua`, `test/lua/test_veafCombatZone.lua`,
`veaf_libs/data/known-limitations.yaml` (+ regenerated `docs/agents/dcs-runtime-traps.md`).

`StaticObject.getByName` returns a destroyed static (`isExist()` false, `getLife()` 0), and both the
completion watchdog and the F10 report counted whatever it returned: a zone holding a static never
completed. The other `StaticObject.getByName` calls of the runtime (22) destroy or locate an object —
a wreck is fine there — so they are left alone.

### Done when

- `veafCombatZone.getStandingStatic(name)` returns the static only if `isExist()` is not false and
  `getLife()` is not ≤ 0 (a method missing or raising reads as standing); the watchdog and the report
  use it; `describeForDiag` says "destroyed static".
- Tests: a static with no life left, or no longer existing, lets the zone complete; a standing one keeps
  it open; the report does not list a destroyed static.
- `known-limitations.yaml` records the DCS behaviour, with the measurement.

## 03 — test mission v3, with no workaround: every line YES

Status: ✅ done

Measured in game on 2026-10-01 at 13:58 (dcs.log): `register subscribed before the test: true`, then
`VERDICT lookup=id 89434905 scenery_destroyed=YES static_zone_done=YES scenery_zone_done=YES operation_over=YES hook=YES`
— the operation ended one second after the map object fell.

The FEAT-OBJECTIVE-MISSION-PROMPT test mission (`D:\dev\_VEAF\tmp\test-objective-mission`), rebuilt with
this branch's Lua and **without** the v2 workaround that subscribed the register by hand.

### Done when

dcs.log shows `register subscribed before the test: true` and
`VERDICT lookup=id … scenery_destroyed=YES static_zone_done=YES scenery_zone_done=YES operation_over=YES hook=YES`.
That also closes tickets 04 and 05 of FEAT-OBJECTIVE-MISSION-PROMPT (ticket 03, the operation hook, is
only observable once the operation can end).
