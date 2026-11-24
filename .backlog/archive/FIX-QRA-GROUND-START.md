# FIX-QRA-GROUND-START — a QRA scrambled from the runway is destroyed before it takes off

Status: ✅ done — 2026-10-10, seen in game · archived 2026-11-24

## Found

Claude and David, 2026-10-10, *Kolkhida* mission 1 rebuilt as a test (R47 item 3 of `DCS-SESSION-TODO.md`), the Senaki QRA put on the runway by `create_qra` (FIX-CAMPAIGN-MISSION-1-FINDINGS ticket 04).
Scrambled through the fiddle hook at t=263 s (`qra:deploy(1)`, the QRA counting human aircraft only), it spawned the tier of the opposition level 7 — `QRA Senaki sol MiG-29 #2` and `QRA Senaki sol Su-27 #2` — on the runway; a minute later both groups were gone and the QRA was `STATUS_READY` again.

## Cause

`VeafQRACore:check`, every `WATCHDOG_DELAY` (5 s), on an `ACTIVE` QRA: a group with no unit in the air counts as landed, and a landed QRA is reset (`rearm`, which destroys the spawned groups).
Written for air starts, where a group is airborne from its first tick; a runway start is on the ground at the first tick, so it was destroyed 5 s after the scramble.
Ticket 04 of FIX-CAMPAIGN-MISSION-1-FINDINGS had concluded that "no new runtime code is needed for a ground start"; it was not checked in game.

## Decided (David, 2026-10-10)

Option a: a group is landed only once it has been seen airborne; a group still on the ground ten minutes after the scramble is taken for stuck, and the QRA is reset as before.

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](FIX-QRA-GROUND-START.md) | A group not airborne yet is taking off, not landed | ✅ |
| [02](FIX-QRA-GROUND-START.md) | An air-wave aircraft rolling to the runway is not crippled | ✅ |

## Definition of done

- Lua tests: a group rolling to the runway is not rearmed; one that flew and landed is; one still on the ground past `TAKEOFF_TIMEOUT` is.
- The QRA page (FR + EN) says what the take-off costs and the ten-minute delay.
- In game (R47 item 3): the Senaki QRA rolls from the runway and climbs; the minutes from the scramble to wheels up go into `veafQraManager.md`.

## The same defect in AirWaves

`AirWaveZone:isEnemyGroupDead` read a wave aircraft not in the air as crippled, and a crippled unit is destroyed: a wave started on a runway died at the first check. First proposed for later; David, 2026-10-10: « pourquoi pas y toucher ? » — same defect, same fix, same lot (ticket 02).

## Tickets, in full

## 01 — A group not airborne yet is taking off, not landed

Status: ✅ done

- `deploy` records when it scrambled (`deployedAt`) and which groups have been airborne since (`groupsSeenAirborne`).
- `check`, on an `ACTIVE` QRA: a group never seen airborne and within `veafQraManager.TAKEOFF_TIMEOUT` (600 s) of the scramble counts as in the air; past it, as landed — the reset of a stuck QRA, unchanged.
- Lua tests in `test_veafQraManager.lua` (`TestVeafQraGroundStart`): the first failed before the fix exactly as in game (`READY` at the first tick).
- **Seen in game 2026-10-10** (R47 item 3, second pass): the Senaki MiG-29 pair rolled from the runway, wheels up 25–35 s after the scramble, the QRA `ACTIVE` throughout; the time is in the QRA page.

## 02 — An air-wave aircraft rolling to the runway is not crippled

Status: ✅ done

`AirWaveZone:isEnemyGroupDead` counted an airplane or helicopter alive only `inAir()`; anything else went to `handleCrippledEnemyUnit`, which destroys the unit.

- `deployWaves` records when the wave left (`waveDeployedAt`) and the units seen airborne since (`unitsSeenAirborne`).
- A unit never seen airborne, within `veafAirWaves.TAKEOFF_TIMEOUT` (600 s), is alive; one that flew and is back on the ground, or one past the delay, is crippled as before.
- Lua tests `TestVeafAirWavesGroundStart`: the first failed before the fix.
- Doc: the fighter-group section of the AirWaves page (FR + EN).
