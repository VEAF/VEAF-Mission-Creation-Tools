# 02 — The mission briefing shows the flight plan

Status: ✅ done

David, 2026-10-08: "régénère les briefings avec les waypoints". The mission briefing deck (`campaign_manager/mission_deck.py`) has no page for the waypoints the players' aircraft carry: regenerating it showed nothing new.

- A "Plan de navigation" page (or a block of an existing page), **read from the built mission** like the rest of the deck: the waypoints of the players' flights after their departure point — name, position (DMS), altitude and its reference (BARO / AGL) — one table for planes and one for helicopters when they differ, `BULLSEYE` included.
- On the tactical map, the waypoints as numbered points, if the labels stay readable (`LabelPlacer`).
- Tests on a built mission fixture; `CAMPAIGN.md` / `.en.md` (the mission briefing's pages table).
- For tonight's *Kolkhida* mission 1, the DCS briefing already carries a hand-written "PLAN DE NAVIGATION" section.
