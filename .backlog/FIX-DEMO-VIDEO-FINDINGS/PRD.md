# FIX-DEMO-VIDEO-FINDINGS — what the AI worked around while building missions with the VEAF tools

Status: ✅ done

Two origins, both a free model (DeepSeek V4.1 Flash on OpenCode) building an objective mission from a clean Windows machine:

- **David's demo video, 2026-10-22** (VMCT 6.31.3, GermanyCW, "Cut the Werra Bridge"). In its final report the AI listed what the tools made it work around. Tickets 01–05 are its words, read off the video (around 5:06).
- **Martinho's session, 2026-10-22** (VMCT 6.31.4, SinaiMap, "Le carburant de la colonne"; the OpenCode export and his mission folder). David noticed that the briefing had no accents; reading the export and the folder turned up the rest. Tickets 06–14. A second run of the same kind (David's sandbox, Caucasus, 6.31.2) shows the same missing accents.

Each ticket measures first: a non-defect (DCS behaviour, a misuse the guide should prevent) is written down in its ticket with the measurement, and fixed in the guide or the known limitations instead of the code. A limitation is only recorded when nothing in the tools can lift it.

| # | What happened | Ticket |
|---|---|---|
| 1 | "the tools reject `Texaco` as a Tanker callsign family" — the KC-135 became `Enfield` | 01 |
| 2 | "the packer refuses 123.5 MHz for the UH-1H radio" — the Huey flight got 250.700 | 02 |
| 3 | "with dynamic slots the deck has no flight list" — a script filled the ATO page after every briefing | 03 |
| 4 | "Deck's Support line and tactical map only pick up the AWACS"; `inspect_built_mission` too | 04 |
| 5 | "`build_mission` overwrites the .miz and wipes briefing pictures" | 05 |
| 6 | The briefing, the zones' names and their briefings were written **without accents** (reasoning had them, the tool call did not) | 06 |
| 7 | The briefing and the F10 labels said NŒUD = W3, COLONNE = W4, OVDA = W6; the route had BULLSEYE third, so they were W4, W5, W7 | 07 |
| 8 | No PDF without PowerPoint: the AI improvised an Edge HTML print (video) or installed LibreOffice and failed (Martinho) | 08 |
| 9 | `read_mission_file` takes `file`, the AI passed `path` | 09 |
| 10 | `add_group` with the coalition `neutral`: a bare `KeyError`, no list of the valid ones | 10 |
| 11 | `validate_mission` warns that `waypoints.yaml` has no aircraft group to inject, with dynamic slots that receive it | 11 |
| 12 | "no clear-ground catalogue covers this place" read as "GermanyCW has no catalogue" — it covers 25 zones, not the AI's | 12 |
| 13 | `create_combat_zone` takes one category per call: thirteen `add_group` calls for the statics | 13 |
| 14 | `inspect_built_mission` shows neither the date nor the briefing pictures; the AI opened the `.miz` with a shell | 14 |

## Tickets

- [01 — "Texaco" refused for a tanker](tickets/01-texaco-tanker-callsign.md)
- [02 — 123.5 MHz refused on the UH-1H](tickets/02-uh1h-123-5.md)
- [03 — The ATO page is empty with dynamic slots](tickets/03-ato-dynamic-slots.md)
- [04 — Support: only the AWACS, the tanker forgotten](tickets/04-support-misses-the-tanker.md)
- [05 — `build_mission` wipes the briefing pictures](tickets/05-build-wipes-briefing-pictures.md)
- [06 — Accents lost in what the AI writes](tickets/06-accents-lost.md)
- [07 — Waypoint numbers in the briefing do not match the route](tickets/07-waypoint-numbers.md)
- [08 — A PDF of the briefing, from the executable](tickets/08-briefing-pdf.md)
- [09 — `read_mission_file` takes `path`](tickets/09-read-mission-file-path.md)
- [10 — `add_group` and the coalition `neutral`](tickets/10-neutral-coalition-error.md)
- [11 — `validate_mission` and dynamic slots](tickets/11-validate-dynamic-slots.md)
- [12 — The clear-ground message says what the catalogue covers](tickets/12-clear-ground-coverage-message.md)
- [13 — `create_combat_zone` takes statics and vehicles together](tickets/13-combat-zone-mixed-categories.md)
- [14 — `inspect_built_mission` shows the date and the briefing pictures](tickets/14-inspect-date-and-pictures.md)

Out of this lot: widening the clear-ground catalogue itself, which needs a survey flown in DCS ([FEAT-CLEAR-GROUND-COVERAGE](../FEAT-CLEAR-GROUND-COVERAGE/PRD.md)).
