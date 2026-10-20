# Ready lots

[Back to the backlog](README.md)

Lots written up and ready to take.

### [FEAT-MCP-MISSION-BRIEFING](FEAT-MCP-MISSION-BRIEFING/PRD.md) · ⬜

An MCP action that builds the VEAF mission briefing — PPTX, maps, DCS briefing pictures — from the built mission and the content the assistant passes, so an assistant with no shell (Claude Desktop in chat mode) produces it too. The builder exists for campaign missions (`campaign_manager/mission_deck.py`). Asked by David on 2026-10-20.

### [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) · ⬜

Broaden the shipped default radio presets, after phase 1 of the radio preset projection.

### [FEAT-LIVE-GAME-MASTER](FEAT-LIVE-GAME-MASTER/PRD.md) · ⬜

Claude acting in a running mission while the squadron flies — spawn, destroy, move convoys, radio messages — through the bridge, with an operator token and never raw Lua. Written up 2026-10-08 and decided by David: free by default, nothing shown when Claude plays red, text and SRS voice when it warns blue players; seven tickets, one of them in the bridge's repository.
