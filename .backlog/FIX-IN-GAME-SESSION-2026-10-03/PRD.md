# FIX-IN-GAME-SESSION-2026-10-03 — what a DCS session flown without a pilot found

Status: ✅ done — merged in #1054 and #1055 (2026-10-03); every ticket done or closed (05, 07 wontfix)

Origin: the DCS session of 2026-10-03, run without anyone at the controls. Five missions were built
from `develop` (`d333d58a`, dev mode) in `D:\dev\_VEAF\tmp\dcs-session-2026-10-03\`; David loaded
them and took a slot; every check went through the fiddle hook (Lua run inside the mission), with AI
aircraft standing in for players. David looked at four things: a smoke, a map, a slot list and a
radio menu.

## What the session settled

Each line closes or advances the lot named; the lots carry the measurement.

| `DCS-SESSION-TODO` item | Lot | Result |
|---|---|---|
| R1 | `FIX-SKYNET-SITE-GOES-DARK-BEFORE-FIRING` | ✅ both SA-6 light at 25 km, stay lit and fire |
| R2 | `FIX-WAREHOUSES-INCREMENTAL` | ✅ 225 airfields in game, an untouched one keeps its warehouse |
| R3 | `FIX-WAREHOUSES-LIST-FORM` | ✅ the three assigned airfields hold their coalition |
| R5 | `FIX-ESCORT-RESPAWN-DISTANCE` | ✅ the escort comes back with the tanker, 1.0–1.8 km; shot down, it comes back and escorts |
| R7 (wave half) | `FIX-AIRWAVES-COMMAND-EASTING` | ✅ `[5000,0]` lands 5.2 km north, the default offset 4 km N / 7 km W |
| R9 | `FIX-AIR-SPAWN-ALTITUDE-GUARD` | ❌ **DCS does not lift** an aircraft spawned 15 m above the trees: it crashes within a second |
| R11 | `FIX-CAP-ENGAGES-PARACHUTES` | ✅ the CAP fires on a fighter, never lists a parachute |
| R12 | `FIX-TUTORIAL-FIRST-RUN` 05 | ✅ the scheduler runs the shell; the marker path failed for ticket 01 below |
| R13 | `FIX-TRIPACK-FIELD-REPORTS` 01 | ✅ Skynet wakes up, every site fires |
| R14 | `FIX-SKYNET-ADDS-DESTROYED-GROUPS` | ✅ no corpse enrolled at start; ❌ a deactivated zone's site stays (ticket 03 here) |
| R15 (group half) | `FIX-USER-REPORTS-985-989` | ✅ DCS keeps `hidden` on a group recreated by `coalition.addGroup` |
| R16 | `FIX-PLACEMENT-IGNORES-SCENERY` 12 | ✅ 8 vehicles under trees before `settleGroup`, 2 after, worst group 0.317 s |
| R17 | `FIX-IN-GAME-TEST-FINDINGS` | ✅ at start; the weapon-near-a-sanctuary line was not run |
| R18 | `FIX-PER-MODULE-LOGLEVEL-INERT` | ✅ only `VEAF-SPAWN` traces |
| R19 | `FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND` | ❌ on open ground the escort moves: the FARP's own vehicles occupy its spot |
| R21 | `FEAT-AIRCRAFT-ROLES` | ✅ the QRA intercepts and flies a race-track, never lands; the `-cap` has a route |
| R22 | `FIX-USER-REPORTS-985-989` 02 | ✅ CSAR menu in a dynamic-slot UH-1 |
| R32 | `FIX-CAP-SIDE-TEMPLATES` | ✅ ten red `-cap`, ten red templates |
| cloned QRA engages | `FIX-TRIPACK-FIELD-REPORTS` 05 | ✅ an R-27 on the intruder |
| zone SA-6 radar range | `FIX-SKYNET-CZ-RESPAWN-AND-RANGE` (archived) | ✅ 46.8 km, the zone SA-6 fires |
| zone smoke (Paluche) | `FIX-TUTORIAL-FIRST-RUN` 05 | ✅ seen by David |
| CTLD airfield capture | `FEAT-CTLD-AIRBASE-LOGISTICS` | ✅ Kobuleti's capture message seen by David |

## The defects it found

| # | Ticket | Status |
|---|---|---|
| 01 | [Smoke and flare colours are named the way DCS names them](tickets/01-dcs-colour-names.md) | ✅ |
| 02 | [`logger:warning` does not exist](tickets/02-logger-warning.md) | ✅ |
| 03 | [A deactivated zone's SAM site stays in the IADS](tickets/03-zone-site-stays-in-the-iads.md) | ✅ |
| 04 | [The CAP watchdog keeps adding tasks](tickets/04-cap-watchdog-task-count.md) | ✅ |
| 05 | [A `-cap` zone drawing outlives its group](tickets/05-cap-drawing-outlives-its-group.md) | 🚫 |
| 06 | [The QRA race-track sits beside its zone](tickets/06-qra-race-track-beside-its-zone.md) | ✅ |
| 07 | [The editor's DCS stubs teach the wrong colour names](tickets/07-editor-stubs-teach-the-wrong-colour-names.md) | 🚫 |
| 08 | [`_spawn signal` fires the smoke colour](tickets/08-signal-takes-the-smoke-colour.md) | ✅ |

R9 and R19 are not tickets here: their lots exist, and the measurement goes there.

## One PR

Tickets 01 and 02 ship together, with the backlog, `DCS-SESSION-TODO.md` and
`known-limitations.yaml` brought up to date. 03 to 06 each need their mechanism understood before a
fix is chosen.

## The second PR

Tickets 03 to 08 go in one branch with the two lots the session advanced:
[`FIX-AIR-SPAWN-ALTITUDE-GUARD`](../FIX-AIR-SPAWN-ALTITUDE-GUARD/PRD.md) (R9, the clearance floor) and
[`FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND`](../FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND/PRD.md) (R19, the
escort beside its own FARP). David's calls of 2026-10-03, on the plan: every recommendation taken.

## The second pass (2026-10-03 afternoon)

Built from this branch, run without a pilot in `D:\dev\_VEAF\tmp\dcs-session-2026-10-03b\`. Seen
working: every coloured smoke from a marker, the `-farp` green smoke and red flares, the convoy smokes
(David's eyes), the signal flares, a wave whose only element is invalid skipped without freezing its
zone, R7's QRA half (a bracketed command and a bare one, both where they should land), R9's floor,
R17's last line (a FAB-250 dropped over the Holzdorf sanctuary, no error), and tickets 03, 04 and 06.
Two defects found during the run and fixed in the branch: the Skynet sweep fooled by a reused group id
(ticket 03's real cause) and the FARP bearing walk ignoring forests. In passing, David saw Arco's escort
engage the threats and rejoin formation.
