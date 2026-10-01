# 03 — test mission v3, with no workaround: every line YES

Status: 🧑 waiting-human

The FEAT-OBJECTIVE-MISSION-PROMPT test mission (`D:\dev\_VEAF\tmp\test-objective-mission`), rebuilt with
this branch's Lua and **without** the v2 workaround that subscribed the register by hand.

## Done when

dcs.log shows `register subscribed before the test: true` and
`VERDICT lookup=id … scenery_destroyed=YES static_zone_done=YES scenery_zone_done=YES operation_over=YES hook=YES`.
That also closes tickets 04 and 05 of FEAT-OBJECTIVE-MISSION-PROMPT (ticket 03, the operation hook, is
only observable once the operation can end).
