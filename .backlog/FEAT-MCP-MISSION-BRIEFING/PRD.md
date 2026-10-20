# FEAT-MCP-MISSION-BRIEFING — the mission briefing built by the server, for an AI with no shell

Status: 🔄 in progress

Origin: David, 2026-10-20: "could we do something for the briefing generation, so that non-agentic AIs (Claude in free mode for instance) can generate the briefs?"

## What exists

- The objective-mission prompt asks for a VEAF briefing as PPTX (and PDF if asked) plus briefing maps and the DCS briefing pictures, all made by **scripts** the assistant writes and runs: `python-pptx`, `Pillow`, map tiles. An assistant without a shell — Claude Desktop in chat mode — cannot (`describe_known_limitations`, `mission-prompt-scripts-need-a-shell`).
- `campaign_manager/mission_deck.py` already builds **the VEAF mission briefing, page for page**, from a built mission: date, time, weather, bullseye, flights and their waypoints, support, carrier, QRA zones, maps through `veaf_libs.map_tiles`, the VEAF template and the military register. It is reached only through the campaign actions (`campaign_briefing`, `campaign_next`), from a campaign's `briefing.yaml`.
- `python-pptx` and `Pillow` ship in the executable (`_DATA_PACKAGES` holds `pptx`).

## Proposal (to design before the tickets)

An MCP action, `build_mission_briefing`: the assistant passes the content it owns as structured fields — title, situation, objectives with their task, threats, the package and its roles, the plan's timing — and the executable builds the rest from the built `.miz`: the PPTX in `docs/`, the briefing maps, and the DCS briefing pictures written into the mission (`mapResource`, `pictureFileNameB`/`N`, red empty). The objective prompt then calls it rather than asking for scripts; an assistant with a shell may still script what the action does not cover.

Out of scope: the PDF. Converting PPTX to PDF needs PowerPoint or LibreOffice, which the executable does not have.

## Decisions (David, 2026-10-20)

1. **Pages.** The action covers the nine pages of the prompt's §3. From the built `.miz`: date, time, weather, bullseye and its bearing from the departure, departure, flights, support, control, QRA, flight plan, the presets **injected** into each flight's first aircraft (no Guard), the objectives' zones and the enemy units inside them (target coordinates in DMS, ground altitude in feet). From the assistant: title, context, mission bullets, objectives (combat zone + title + task), threats (group + family + engagement/detection radii when sourced), air opposition, air defences, other information, pilots and loadouts. Left to the assistant: the PDF, the Drive upload, `set_briefing`, the F10 drawings; looking at the rendered pages stays with a user whose assistant has no shell.
2. **Tiles.** Offline, a missing tile leaves a plain background, the map is drawn anyway and `map_offline` says so. A `basemap: osm | topo` parameter adds OpenTopoMap, with its credit and its own cache folder (the prompt asks for it in a desert). The PRD said the executable fetched OpenTopoMap: it fetched OpenStreetMap only.
3. **Builder.** Extract what is campaign-free (the ATO, frequency and navigation pages, the weather, the map canvas, the picture page) and compose a one-shot builder from it; the campaign deck keeps its own situation, flow and coordinates pages. The campaign deck loses its Guard line too, as the plan did in f1a26a4e.
4. The DCS briefing pictures go into the folder **and** the built `.miz`, so no rebuild is needed; the action owns the `MCP_Briefing_*` keys and replaces them on each run.
5. No step in the demo mission.

## Tickets

- [01 — Extract the campaign-free pieces](tickets/01-extract-shared.md)
- [02 — Read objectives, targets and presets from the built mission](tickets/02-read-mission.md)
- [03 — Maps of a one-shot mission](tickets/03-maps.md)
- [04 — The deck and the DCS briefing pictures](tickets/04-deck-and-pictures.md)
- [05 — The MCP action and its documentation](tickets/05-action.md)
- [06 — Prompts, guide, known limitation](tickets/06-prompts.md)
