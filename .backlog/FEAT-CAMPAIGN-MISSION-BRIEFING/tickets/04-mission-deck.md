# 04 — The mission briefing deck, from `campaign next` and `campaign briefing`

Status: ✅ done

`missions/mission-NN/briefing-mission.pptx`, the pages of the PRD, written with the campaign deck's helpers (pagination by the font's metrics, the VEAF template, the military register), from tickets 01–03 and the coming mission's page of `briefing.yaml` (title, tasks).

- It needs the **built** mission: `campaign briefing` writes it when a `.miz` exists in the mission folder, and says how to get one otherwise; the MCP action `campaign_briefing` returns its path too.
- Objective coordinates are zone centres in DMS, with ground elevation from the swept grid when there is one, and nothing in its place when there is none.
- No target coordinate and no flight plan: the briefing says positions are found in flight.

## Done when

Tests generate the deck from a fixture campaign and `.miz`: page titles in order, one zoom page per objective, the ATO without templates, frequencies split UHF/VHF, DMS never at 60 seconds.
