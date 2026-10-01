# 03 — test mission v3, with no workaround: every line YES

Status: ✅ done

Measured in game on 2026-10-01 at 13:58 (dcs.log): `register subscribed before the test: true`, then
`VERDICT lookup=id 89434905 scenery_destroyed=YES static_zone_done=YES scenery_zone_done=YES operation_over=YES hook=YES`
— the operation ended one second after the map object fell.

The FEAT-OBJECTIVE-MISSION-PROMPT test mission (`D:\dev\_VEAF\tmp\test-objective-mission`), rebuilt with
this branch's Lua and **without** the v2 workaround that subscribed the register by hand.

## Done when

dcs.log shows `register subscribed before the test: true` and
`VERDICT lookup=id … scenery_destroyed=YES static_zone_done=YES scenery_zone_done=YES operation_over=YES hook=YES`.
That also closes tickets 04 and 05 of FEAT-OBJECTIVE-MISSION-PROMPT (ticket 03, the operation hook, is
only observable once the operation can end).
