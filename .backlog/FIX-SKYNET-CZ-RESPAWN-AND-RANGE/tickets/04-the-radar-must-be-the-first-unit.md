# 04 — the radar must be the first unit, and `pairs` was losing that

Status: ✅ done — **verified in game 2026-09-09**
Type: fix

This ticket answers the question tickets 01–03 left open and wrote up as a DCS-session item: *why
does DCS report no sensor data for a radar unit it still holds?*

## The answer

**It is not about the radar. DCS gives a SAM group no sensors at all — on every unit — when the
group's first unit is not its radar.**

And VEAF was shuffling that order itself. `veafMissionDb.buildSnapshot` walked a group's units with

```lua
for _, unitData in pairs(groupData.units or {}) do
```

`pairs` has no defined order, so every mission record carried its units in hash order. A respawn
hands that order straight to `coalition.addGroup`. On Tripack's SA-6 the radar landed third of five.

## Measured, in game, against DCS itself

Through the bridge injected into the test mission, on 2026-09-09. Fourteen probe groups, each created
and destroyed in the running mission:

| probe | first unit | units with sensors |
|---|---|---|
| the record exactly as VEAF submits it | `Kub 2P25 ln` | **0 / 5** |
| the *same five units*, radar moved back to first | `Kub 1S91 str` | **5 / 5** |
| a hand-written pair, radar first | `Kub 1S91 str` | 2 / 2 |
| the *same pair*, launcher first | `Kub 2P25 ln` | **0 / 2** |

The check falls both ways: reordering repairs it, and inverting breaks a group that worked. Eleven
further probes cleared, one at a time, `coldAtStart`, `playerCanDrive`, `unitId`, `groupId`,
`missionData`, `route`, `task`, the coordinates, the unit count and `coalition.addGroup` itself.

The editor group standing outside the zone (`Sol_g-2`), same five unit types, reported 5/5 throughout
— it is never respawned, so nothing shuffled it. That is why the defect looked machine-specific and
was not.

## What it explains, all of it

- `getSensors()` nil → `SkynetIADSSAMSearchRadar:setupRangeData` finds no range → `maximumRange`
  stays 0 → `isTargetInRange` is always false → the site never goes live and never fires
- the same nil → `isRadarWorking()` false → the site is counted under `Raddest` on the status page

One word, both of #946's symptoms. It also retires ticket 01's re-read, which was built on the
explanation this measurement replaced: `Unit.getByName` hands back the very same handle, so
re-resolving it was a no-op (`rehandled=0` in the log of the run that measured it). The diagnostic
line naming each radar unit is kept as a canary for any other cause.

Beyond Skynet: everything that anchors on "unit 1" of a respawned group — the spawn offset of
FIX-TRIPACK-FIELD-REPORTS ticket 04 among them — was anchoring on whichever unit the hash order put
there.

## Verified in game

2026-09-09, `Skynet-test_20260908-fix946f`, launched from the mission list. No `RADAR RANGE` line at
all; the zone's SA-6 reported `ACTIVE: true`, `HAS AMMO: true`, `DETECTED TARGETS: 1` on the F/A-18 at
7.03 NM, its units stationary and carrying three missiles each; it held the lock and fired once the
aircraft came back inside its envelope.

## Definition of done

- [x] `ipairs`, with a comment carrying the measurement rather than the mechanics
- [x] tests that fail when the change is reverted — two of the three do so deterministically, through
      a non-array key that `pairs` visits and `ipairs` does not; asserting order alone would be flaky
      because Lua often walks a short array in order by luck
- [x] the re-read scaffolding of ticket 01 removed, its tests with it
- [x] verified in game
