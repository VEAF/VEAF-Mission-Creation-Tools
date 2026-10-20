# FEAT-MCP-MISSION-BRIEFING — the mission briefing built by the server, for an AI with no shell

Status: ⬜ ready

Origin: David, 2026-10-20: "could we do something for the briefing generation, so that non-agentic AIs (Claude in free mode for instance) can generate the briefs?"

## What exists

- The objective-mission prompt asks for a VEAF briefing as PPTX (and PDF if asked) plus briefing maps and the DCS briefing pictures, all made by **scripts** the assistant writes and runs: `python-pptx`, `Pillow`, map tiles. An assistant without a shell — Claude Desktop in chat mode — cannot (`describe_known_limitations`, `mission-prompt-scripts-need-a-shell`).
- `campaign_manager/mission_deck.py` already builds **the VEAF mission briefing, page for page**, from a built mission: date, time, weather, bullseye, flights and their waypoints, support, carrier, QRA zones, maps through `veaf_libs.map_tiles`, the VEAF template and the military register. It is reached only through the campaign actions (`campaign_briefing`, `campaign_next`), from a campaign's `briefing.yaml`.
- `python-pptx` and `Pillow` ship in the executable (`_DATA_PACKAGES` holds `pptx`).

## Proposal (to design before the tickets)

An MCP action, `build_mission_briefing`: the assistant passes the content it owns as structured fields — title, situation, objectives with their task, threats, the package and its roles, the plan's timing — and the executable builds the rest from the built `.miz`: the PPTX in `docs/`, the briefing maps, and the DCS briefing pictures written into the mission (`mapResource`, `pictureFileNameB`/`N`, red empty). The objective prompt then calls it rather than asking for scripts; an assistant with a shell may still script what the action does not cover.

Out of scope: the PDF. Converting PPTX to PDF needs PowerPoint or LibreOffice, which the executable does not have.

## Open questions

1. Which pages of the prompt's §3 the action covers, and which stay with the assistant.
2. Map tiles: the executable fetches OpenTopoMap tiles (network, identifiable User-Agent, cache); what it does offline.
3. Whether `mission_deck.py` is generalised (campaign and one-shot missions share one builder) or wrapped.

## Tickets

To write once the open questions are settled.
