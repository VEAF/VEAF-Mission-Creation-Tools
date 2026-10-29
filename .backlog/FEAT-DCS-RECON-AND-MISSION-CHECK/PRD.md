# FEAT-DCS-RECON-AND-MISSION-CHECK — reconnaissance photos and an in-game mission check, from a running DCS

Status: ✅ done

Two things the "Marteau du Golan" session (Syria, 2026-10-28) did by hand against a running DCS, through the `dcs-fiddle` hook, and that every objective mission needs again.
The prototype lives in that mission's `docs/build/recon/` (`fiddle.py`, `shoot.py`, `proj.py`, `process.py`, `menu.lua`, `zones*.lua`, `cap.lua`, `reroute.lua`); its logic is taken over, not its code.

| # | What | Ticket |
|---|---|---|
| 1 | `veaf-tools dcs recon-photos prepare`: a shooting copy of a built mission — clear sky, chosen time, every combat zone active at start, real group names | 01 |
| 2 | `veaf-tools dcs recon-photos shoot`: read the live units from the `server` state, put the F11 camera on each shot's engagement axis from the `export` state, grab the DCS window, write the raw shot and its metadata | 02 |
| 3 | `veaf-tools dcs recon-photos render`: the reconnaissance look (contrasted black and white, grain, vignette, banner, heading rose) and red felt-pen marks placed by perspective projection (80° horizontal field, measured) | 03 |
| 4 | `veaf-tools dcs mission-check`: the F10 tree VEAF built (empty labels), every combat zone and combat mission toggled and counted, every routed ground group seen moving within 60 s, one line per check and a verdict | 04 |
| 5 | Documentation, CHANGELOG | 05 |

Decided with the brief (2026-10-28):

- nothing is done to a DCS session the user did not launch; nothing on a server; no sound; each command says what it will do and what it expects of the user;
- unit tests for everything that does not need DCS: projection, camera vectors, rendering, menu tree parsing, request building and parsing;
- CLI only, filed under the `dcs` group next to `smoke-test`: like it, both need a DCS running on this machine, which an MCP client building a mission elsewhere does not have (CLAUDE.md §7, "a CLI command exists because a mission maker will type it");
- the JPEG + JSON pair is the input of the objective briefing (lot FEAT-OBJECTIVE-BRIEFING-QUALITY's follow-up).

One branch, one PR.
