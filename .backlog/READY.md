# Ready lots

[Back to the backlog](README.md)

Lots written up and ready to take.

### [FEAT-CLEAR-GROUND-COVERAGE](FEAT-CLEAR-GROUND-COVERAGE/PRD.md) · ⬜

Widen the shipped clear-ground catalogues to the places missions are built — round airfields, towns, road axes — under a weight ceiling per theatre. Needs a survey flown in DCS, so David's time; split from FIX-DEMO-VIDEO-FINDINGS (2026-10-23).

### [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) · ⬜

Broaden the shipped default radio presets, after phase 1 of the radio preset projection.

### [FEAT-LIVE-GAME-MASTER](FEAT-LIVE-GAME-MASTER/PRD.md) · ⬜

Claude acting in a running mission while the squadron flies — spawn, destroy, move convoys, radio messages — through the bridge, with an operator token and never raw Lua. Written up 2026-10-08 and decided by David: free by default, nothing shown when Claude plays red, text and SRS voice when it warns blue players; seven tickets, one of them in the bridge's repository.

### [POC-DCS-DYNAMIC-WEATHER](POC-DCS-DYNAMIC-WEATHER/PRD.md) · ⬜

Measure DCS's dynamic weather on our server before using it in persistent campaigns: does it change during a mission, do clients see the same, what a restart gives. A test mission flown by two clients on Privé 2; answers go to the DCS traps and the campaign page. Until then, persistent campaigns take the bot's real weather (David, 2026-11-17).

### [FEAT-CHERRY-AI-SETUP](FEAT-CHERRY-AI-SETUP/PRD.md) · ⬜

`ai-setup` declares the VEAF MCP server in Cherry Studio, the chat client of the local-model tutorial, so pilots do not import it by hand. A study first (where Cherry keeps its MCP servers), then `setup_cherry`, then the doc; after PR #1349 (David, 2026-11-26).

### [FIX-MCP-REPLAY-FINDINGS](FIX-MCP-REPLAY-FINDINGS/PRD.md) · ⬜

What the local-model replay of Marteau du Golan block 1 found (2026-11-27): the guide's examples replayed as written, no action for the aircraft an airfield offers, and a tanker display name accepted. One PR, three tickets.

### [FEAT-CHERRY-PORTABLE-KIT](FEAT-CHERRY-PORTABLE-KIT/PRD.md) · ⬜

Study shipping Cherry Studio portable with its data folder prefilled, so the kit's users get the two VEAF assistants without a restore (David, 2026-11-27).
