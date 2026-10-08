# 03 — Campaigns and Claude size the opposition, and the briefing says it

Status: ⬜ ready

- `campaign.yaml` may set the squadron's expected size (`players: 5-7`); `campaign next` sets the mission's opposition level from it, and the MCP action `campaign_next` asks Claude to set it from what the mission maker says of tonight's attendance.
- Claude's instructions (the `campaign_next` / `create_qra` descriptions): a campaign mission's enemy air has tiers by enemy count, the biggest sized to the squadron's expected size; never a single fixed pair for 5+ players.
- The mission briefing (FEAT-CAMPAIGN-MISSION-BRIEFING) says the air threat as intelligence ("la chasse adverse renforce son alerte face à un dispositif important"), never as tiers or numbers.

## Done when

`campaign next` writes the level; the MCP descriptions carry the rule; a fixture campaign's mission briefing says the scaled threat without a figure.
