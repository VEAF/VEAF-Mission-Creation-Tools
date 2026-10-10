# FIX-OPEN-TRAINING-CAUCASUS-FINDINGS — what recompiling the Caucasus Open Training v6 in 6.29.0 found

Status: ⬜ ready

Asked by David on 2026-10-10.
The Caucasus Open Training v6 (`VEAF-Open-Training-Mission-Caucasus-v6`, PR #3 there) was recompiled with the 6.29.0 release for the radio-menu measurement of `FEAT-RADIO-MENU-WATCH` ticket 03, then loaded in single player.
Three things had to be fixed by hand in the mission; each is a defect of the tools, checked against the code of `develop` (364b26ff) before being written down.

- **No game master slot.** Every mission scaffolded since v6 has 0 slots for every unattached role (game master, tactical commander, JTAC, observer) and `isPilotControlVehicles = false`: `blank_mission.py` writes them that way and nothing in `mission.yaml` can change them. The v5 Open Training had 5 per role and per side, with vehicle control on. GermanyCW-v6 has the same gap, so does every OT built from the prompt (ticket 01).
- **A CTLD catalogue upgrade is only seen in game.** The 6.29.0 release vendors CTLD catalogue 2.2.0; the mission's `ctld-config.yaml` was written against 2.0.0. CTLD said so on screen at mission start (« 3 réglage(s) absent(s) de la config de la mission (version 2.0.0, catalogue CTLD 2.2.0) »), but neither `mission validate` nor `mission build` reads `configVersion`: the maker learns it from a player. The fix was three settings copied by hand from the vendored catalogue (ticket 02).
- **No dashed line.** `add_map_drawing` writes `style = "solid"` on every shape (`map_drawings.py`, five places). DCS offers sixteen styles. The Caucasus arena is a dashed circle on the briefing map and had to become a solid one on the F10 map (ticket 03).
- **A committed report that names the machine.** Found recompiling GermanyCW-v6 the same day: `presets-validation-report.md` carries the build date and two absolute paths, so a build from a worktree or another machine dirties a committed file with no finding changed (ticket 04).
- **A dropped preset channel is never reported.** Found recompiling Syria-v6 the same day: three UHF-only channels on the VHF `primary_2` list were skipped by the injector, which keeps their names in an attribute nothing reads; the mission's README advertised them for eight days (ticket 05).

Not filed: the game master's empty VEAF menu, seen in the same session. It is VMCT #128, closed `wontfix` with its measurements in `docs/exploration/DCS-UNATTACHED-PLAYER-ROLES.md`.

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Unattached roles and vehicle control set from mission.yaml](tickets/01-ground-control-roles.md) | ⬜ |
| 02 | [validate reports a CTLD catalogue gap, and a command fills it](tickets/02-ctld-catalogue-gap.md) | ⬜ |
| 03 | [add_map_drawing takes a line style](tickets/03-drawing-line-style.md) | ⬜ |
| 04 | [The presets report a mission commits names no machine path](tickets/04-presets-report-machine-paths.md) | ⬜ |
| 05 | [A channel the presets injector drops is reported](tickets/05-dropped-channels-reported.md) | ⬜ |

One branch, one PR for the five.
