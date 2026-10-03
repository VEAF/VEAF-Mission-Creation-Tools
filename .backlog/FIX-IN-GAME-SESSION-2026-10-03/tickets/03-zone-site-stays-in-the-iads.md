# 03 — a deactivated zone's SAM site stays in the IADS

Status: ⬜ ready — to measure in game (see below)
Type: fix

## Measured

Tripack's `Skynet-test` mission (#946), rebuilt from `develop` on 2026-10-03. `TESTCZ` deactivated at
t=74 s and reactivated at t=84 s: the new SA-6 `TESTCZ [r] TESTCZ - SA6#10299` joined the network
(`GOING LIVE`), and the old `#10298` stayed listed by `iads:getSAMSites()` — still there at t=350 s,
although `Group.getByName` returned `nil` for it. Four sites became five.

`FIX-SKYNET-ADDS-DESTROYED-GROUPS` ticket 03 is meant to remove exactly this: a sweep every
`SecondsBetweenVanishedSitesSweeps` (60 s) drops a site whose group is gone and none of whose units
was reported lost. It did not, five sweeps in a row.

## What is already ruled out

The ledger's premise: DCS raises no `S_EVENT_DEAD` / `S_EVENT_UNIT_LOST` for a unit removed by
`Group:destroy()`. Checked the same day in another mission: a blue S-300 destroyed by script while an
event logger listened produced no loss event.

## Suspects, to settle with one instrumented run

1. the sweep was never armed in this configuration (the arming function returns early on a flag);
2. the zone's deactivation removes its groups by another path than `destroy()`, one that raises a
   loss event and so reads as a kill.

A `debug` log level on SKYNET shows the sweep's `removed N despawned element(s)` line, or its absence.

## Read before the run (2026-10-03, afternoon)

Both suspects are ruled out by the code and by `dcs.log` of the morning run:

1. the sweep **is** armed: `_armVanishedSitesSweep` is called just before `Skynet IADS has been
   initialized`, a line the log carries; no `VEAF-SCHEDULER|E|` line in the whole mission;
2. the zone removes its groups with `Group:destroy()` (`VeafCombatZone:destroySpawnedGroup`), and the
   respawn gives new group and unit ids (`veafDcsSpawner.lua`, `data.groupId = nil`).

What is left: either the stale site's `dcsRepresentation:isExist()` still answers `true`, or one of
its unit names is in `veafSkynet.lostUnits`. The log cannot tell: the removal line is at `debug` and
the module ran at `info`. The next run asks both directly, with the fiddle hook, then calls
`removeVanishedSites` by hand.
