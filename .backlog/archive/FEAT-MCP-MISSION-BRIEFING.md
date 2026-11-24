# FEAT-MCP-MISSION-BRIEFING — the mission briefing built by the server, for an AI with no shell

Status: ✅ done (PR #1158, 2026-10-20) · archived 2026-11-24

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

- [01 — Extract the campaign-free pieces](FEAT-MCP-MISSION-BRIEFING.md)
- [02 — Read objectives, targets and presets from the built mission](FEAT-MCP-MISSION-BRIEFING.md)
- [03 — Maps of a one-shot mission](FEAT-MCP-MISSION-BRIEFING.md)
- [04 — The deck and the DCS briefing pictures](FEAT-MCP-MISSION-BRIEFING.md)
- [05 — The MCP action and its documentation](FEAT-MCP-MISSION-BRIEFING.md)
- [06 — Prompts, guide, known limitation](FEAT-MCP-MISSION-BRIEFING.md)

## Tickets, in full

## 01 — Extract the campaign-free pieces

Status: ✅ done

The ATO, frequency and navigation pages, the weather lines, the map canvas and the picture page move out of `mission_deck.py` / `tactical_map.py` into a module the campaign and the one-shot builder share. The campaign deck's frequency page loses its Guard line.

Done: the campaign deck tests stay green, with the Guard assertion changed.

## 02 — Read objectives, targets and presets from the built mission

Status: ✅ done

From the built `.miz` and `mission.yaml`: each objective's combat zone (centre, radius) and the enemy units and statics inside it, the presets injected into each player flight's first aircraft, named by the frequency catalogue.

Done: tests on a mission table: units out of the zone or friendly are left out; a channel with no alias shows its frequency.

## 03 — Maps of a one-shot mission

Status: ✅ done

An overview map (departure, route and numbered waypoints, objectives, threats with engagement and detection circles, support, carrier, QRA, bullseye, scale, credit) and one zoom per objective framed wide with its units. `basemap: topo` takes OpenTopoMap tiles, its credit and its own cache.

Done: tests with a fake fetch: symbols where expected, labels apart, the offline flag, the topo URL and credit.

## 04 — The deck and the DCS briefing pictures

Status: ✅ done

`docs/briefing.pptx`, the nine pages of the prompt's §3, in the mission's language. The maps as JPEG into the folder and the built `.miz`, `pictureFileNameB` then `N`, under `MCP_Briefing_*` keys replaced on every run; a non-empty red list is a warning.

Done: tests read the PPTX back (page titles, figures from the mission) and the mission tables after two runs.

## 05 — The MCP action and its documentation

Status: ✅ done

`build_mission_briefing` in the catalogue; `AI_ASSISTANT_CATALOG` and `mission-editing-mcp` in French and English; CHANGELOG.

Done: a test calls the action through the catalogue on a built mission.

## 06 — Prompts, guide, known limitation

Status: ✅ done

The objective-mission prompts (fr, en) §4.6, §5 and §6 call the action; the stale "No action does it" goes; the authoring guide names it; `mission-prompt-scripts-need-a-shell` keeps only what still needs a shell, and the traps page is regenerated.

Done: `docs-check` and the prompt tests pass.
