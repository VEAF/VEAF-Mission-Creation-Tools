# FIX-BRIEFING-PARITY-MARTEAU — the generated briefing at the level of the hand-made one

Status: ✅ done

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
