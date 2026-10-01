# FIX-OBJECTIVE-COMPLETION — a zone holding a static completes, the scenery register records

Status: ✅ done

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
| 01 | [the event bus subscribes the destroyed-scenery register](tickets/01-subscribe-the-scenery-register.md) | ✅ |
| 02 | [a destroyed static no longer counts in a combat zone](tickets/02-destroyed-static-does-not-count.md) | ✅ |
| 03 | [test mission v3, with no workaround: every line YES](tickets/03-verify-in-game.md) | ✅ |
