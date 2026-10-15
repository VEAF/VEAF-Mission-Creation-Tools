# FIX-OPEN-TRAINING-FALKLANDS-FINDINGS — what building the Falklands Open Training v6 found

Status: ✅ done — tickets 01–05 and 07 done, 06 closed without the action (David, 2026-10-14: « on verra bien en jeu »)

Asked by David on 2026-10-13.
The Falklands Open Training v6 (`VEAF-Open-Training-Mission-Falklands-v6`) was built with veaf-tools 6.29.0 although the map was not supported end to end; its `tools/retours-vmct.md` lists twelve findings.
The data DCS gave (frequencies, parking) was captured in the main checkout and is delivered by tickets 01 and 02, which unblock the map.
Each finding below was checked against `develop` (3b7facc6) before being written down.

Findings 1, 2, 4, 5 and 6 of the report are tickets 01 and 02.
Finding 7 (`add_farp` cites `veaf-tools dcs farp-spot`, absent from the published exe) is **not a defect of `develop`**: the command was added on 2026-10-12 (`a1b9edce`, FIX-FARP-PLACEMENT ticket 03), after the 6.29.0 tag, and ships with the next release.
Finding 3 (the v5 coordinates are in a frame that no longer matches the map) concerns the v5 mission, not the tools.

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Falklands is a supported theatre](tickets/01-falklands-supported-theatre.md) | ✅ |
| 02 | [Falklands data delivered: frequencies, parking, presets](tickets/02-falklands-data.md) | ✅ |
| 03 | [add_farp: a FARP on a lake, and on a tower frequency](tickets/03-add-farp-surface-and-frequency.md) | ✅ |
| 04 | [create_combat_zone: a convoy that starts on the road, at a convoy's speed](tickets/04-convoy-on-road.md) | ✅ |
| 05 | [validate_mission: what a combat zone circle does with the groups around it](tickets/05-validate-combat-zone-overlap.md) | ✅ |
| 06 | [A convoy between two places, on the roads](tickets/06-convoy-between-places.md) | 🚫 |
| 07 | [Ground placement on a theatre with no clear-ground catalogue](tickets/07-no-clear-ground-catalogue.md) | ✅ |

Decision left to David: the Falklands elevation grid (`~/.veaf/terrain/Falklands.terrain`, 4.2 MB) is **not delivered** — no theatre ships its grid today, they are swept on each workstation (`terrain-sweep`); see ticket 02.

One branch, one PR.
