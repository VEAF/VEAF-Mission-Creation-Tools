# FIX-MARTEAU-PLAY-FINDINGS — fixes and rules from the evening of 2026-10-29

Status: 🧑 waiting-human (in-game check R53, #1221 merged)

Origin: the mission "Marteau du Golan" (Syria, built with VMCT 6.34.0) flown on Private 1 on 2026-10-29, then read through the server's `dcs.log` and the Tacview recording. David's task T426.

## Scope

| # | Ticket | Status |
|---|---|---|
| 01 | [AIEN counter-battery raises on a missing SA](tickets/01-aien-missing-sa.md) | ✅ |
| 02 | [The Opposition menu by default](tickets/02-opposition-by-default.md) | ✅ |
| 03 | [A shot-down CAP is no error](tickets/03-cap-watchdog-false-error.md) | ✅ |
| 04 | [Target coordinates: DDM and MGRS, never DMS](tickets/04-target-coordinates.md) | ✅ |
| 05 | [Design rules in the guide and the objective prompt](tickets/05-design-rules.md) | ✅ |
| 06 | [Profiles edit a combat zone by name](tickets/06-profile-zone-edits.md) | ✅ |
| 07 | [Recon photos: one per objective, vehicles not pinpointed](tickets/07-recon-photo-budget.md) | ✅ |

## Decisions

- Two lots, two PRs: this one holds fixes and rules; the combat log (FEAT-COMBAT-LOG) needs a check in game and goes on its own.
- Ticket 07 (David, 2026-10-30): one photo per objective, two at most. A photo of vehicles (tanks, light armour, trucks, 4x4…) shows the zone, not where each vehicle stands; the same goes for the coordinates the briefing gives for them.
