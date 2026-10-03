# 03 — a deactivated zone's SAM site stays in the IADS

Status: 🔄 in-progress — cause measured and fixed 2026-10-03, verified hot in game
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

## Measured in game (2026-10-03, second pass)

`TESTCZ` deactivated and reactivated, then the stale site asked directly through the fiddle hook:

| | old site `#10211` |
|---|---|
| `Group.getByName("…#10211")` | nil |
| its stored object, `isExist()` | **true** |
| its stored object, `getName()` | **`…#10212`** — the new site |
| its stored object, `id_` | 44, the same as the new group |
| `lostUnits` | empty |

Neither suspect: the sweep runs, and no loss was recorded. `VeafGroupSpawn:respawn()` keeps the
template's ids (only `clone` drops them), so the zone's new SA-6 took group id 44 again, and a DCS
object being nothing but its id, the old site's object answered for the new group.

## Fixed

The sweep also counts an element as gone when its object answers a **different name** than the one
it was enrolled under (`_isGone`); an element Skynet named after an id is never compared. Hot-patched
in game before porting: `removeVanishedSites -> 1`, four sites again, the new SA-6 kept. Recorded as
`a-dcs-object-is-its-id` in `known-limitations.yaml`.

Not changed: `respawn()` keeping the template's ids under a new name. Anything else that holds a DCS
object across a zone cycle follows the new group the same way; worth its own look if another symptom
appears.
