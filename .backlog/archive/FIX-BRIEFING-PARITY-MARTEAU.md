# FIX-BRIEFING-PARITY-MARTEAU — the generated briefing at the level of the hand-made one

Status: ✅ done · archived 2026-11-24

"Marteau du Golan" (Syria, flown 2026-10-29) was briefed from a 52-page hand-made deck; FEAT-OBJECTIVE-BRIEFING-QUALITY (#1206) and FEAT-OBJECTIVE-MISSION-V2 (#1208) took its improvements into the tools.
A regeneration test on a copy of the mission (2026-10-28, `origin/develop` a1a070b9, same parameters) showed the tool below the hand-made version on its maps, its target sheets and its frequency plan.
This lot fixes the nine defects it found, so that the mission's hand-written scripts (`docs/build/`) can be retired (David's task T419).

| # | What | Ticket | Status |
|---|---|---|---|
| D1 | `zone_of("Sasa [r]")` gives `Sasa`: a zone's recon photos are no longer dropped | 01 | ✅ |
| D2 | Maps: the overview frames the whole theatre (bases, tankers, AWACS, front line, QRA), no pink fill, flight-plan names, a helicopter route of its own; the combat map shows the friendly units, the JTAC, the axes and the ranges | 02 | ✅ |
| D3 | Targets at unit level with readable names, not the group's technical suffix | 03 | ✅ |
| D4 | Bullseye bearing and range on every target and step; "Pour : <flight>" on each objective | 04 | ✅ |
| D5 | Main objectives are the operation's tasks; zones outside it are secondary; a chained zone is in neither list | 05 | ✅ |
| D6 | The frequency plan and the kneeboard flight card follow the ATO's flights, not the 61 dynamic-slot types: one block per radio plan | 06 | ✅ |
| D7 | PDF left-aligned, never justified; ATO, deployment and code words as tables | 07 | ✅ |
| D8 | `waypoint_notes` per plan (planes, helicopters), not only per name | 08 | ✅ |
| D9 | The briefing can replace the kneeboard pages that are not its own | 09 | ✅ |

Decided with the brief (2026-10-28): backward compatible, everything new optional; a test for each defect; documentation in the same lot; texts with their accents.
Validated by regenerating the briefing of a copy of the mission and looking at the result against the hand-made one.

One branch, one PR.

## Tickets, in full

## D1 — A spawned group's zone, even with nothing after its marker

Status: ✅ done

`veaf_libs/dcs_recon.py` `zone_of` cut a group name at ` [r] ` with a trailing space only: `Sasa [r]` (no name after the marker) was its own zone, `briefing_sidecar` wrote it, and the briefing dropped the photos of Sa'sa' and Kiswah ("zone 'Sasa [r]' is no objective").

Done when: covered by a test, and the documentation says it.

## D2 — Maps that show the theatre and the fight

Status: ✅ done

The overview is framed on the objectives only and filled pink by the QRA zones and the SA-11's reach; its labels are trigger names (`EWRTellHara`); the helicopters' route looks like the jets'. The combat-area map shows no friendly unit, no JTAC, no axis, no range. Expected: the overview frames the bases, tankers, AWACS, front line and QRA; QRA dashed, long-range SAMs outlined; objectives named as the flight plan names them; a helicopter route of its own (colour, dashes); on the combat map the friendly ground units, the JTAC, the ground axes and the ranges on the threat labels.

Done when: covered by a test, and the documentation says it.

## D3 — Targets at unit level, readable

Status: ✅ done

A target was a group, named by its technical suffix (`battery`, `armor-1`, `2s1`): the SA-6 had one sheet instead of five. Expected: one target per unit when the units carry their own names (radar, launchers 1 to 4), a readable name otherwise (the type, a VEAF spawn command's family), what it is and its role.

Done when: covered by a test, and the documentation says it.

## D4 — Bullseye and who goes where

Status: ✅ done

No bullseye bearing and range on the targets, the objectives or the steps; no "Pour : <flight>" on an objective. Expected: both on every sheet, the flights taken from an optional `objectives[].flights`.

Done when: covered by a test, and the documentation says it.

## D5 — Main objectives are the operation's

Status: ✅ done

"Objectifs principaux" listed every objective passed, the SA-11, Kiswah and the counter-attack included. Expected: the operation's tasks (`mission.yaml`) are the main objectives, the other objectives the secondary ones, a chained zone in neither list.

Done when: covered by a test, and the documentation says it.

## D6 — Frequencies by radio plan, for the ATO's flights

Status: ✅ done

The frequency plan listed the radios of each of the 61 dynamic-slot types (7 pages), and the kneeboard flight card's heading the 61 types. Expected: the ATO's filter applies — only the types its flights fly, one block per distinct radio plan, named by the flights that carry it.

Done when: covered by a test, and the documentation says it.

## D7 — A left-aligned PDF with tables

Status: ✅ done

The PDF justified its text (the VEAF template never does) and printed the ATO, the deployment and the code words as plain text. Expected: left-aligned text; the three as tables, in the PDF and the deck.

Done when: covered by a test, and the documentation says it.

## D8 — Waypoint notes per plan

Status: ✅ done

`waypoint_notes` were keyed by name only, and jets and helicopters share SASA, KANAKER, COLONNE, KHAN and BULLSEYE with different roles. Expected: `waypoint_notes` also takes `plane` and `helicopter` maps, a name's note per plan winning over the shared one.

Done when: covered by a test, and the documentation says it.

## D9 — The kneeboard the tool's own when asked

Status: ✅ done

The tool left the hand-made kneeboard pages in place: the `.miz` carried the 20 hand-made pages and the tool's 24. Expected: an optional `kneeboard_replace` removes the common kneeboard pages that are not the tool's, from the folder (kept in a backup) and from every built `.miz`.

Done when: covered by a test, and the documentation says it.
