# Ready lots

[Back to the backlog](README.md)

Lots written up and ready to take.

### [FEAT-BRIEFING-PER-LANGUAGE](FEAT-BRIEFING-PER-LANGUAGE/PRD.md) · ⬜

A `language` parameter for `build_mission_briefing`, writing only the archives of that language, so a bilingual mission (the demo's `_FR` and `_EN`) gets its briefing and kneeboard pages in each language. One ticket; asked from the demo's kneeboard step (2026-10-26).

### [FEAT-CLEAR-GROUND-COVERAGE](FEAT-CLEAR-GROUND-COVERAGE/PRD.md) · ⬜

Widen the shipped clear-ground catalogues to the places missions are built — round airfields, towns, road axes — under a weight ceiling per theatre. Needs a survey flown in DCS, so David's time; split from FIX-DEMO-VIDEO-FINDINGS (2026-10-23).

### [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) · ⬜

Broaden the shipped default radio presets, after phase 1 of the radio preset projection.

### [FEAT-LIVE-GAME-MASTER](FEAT-LIVE-GAME-MASTER/PRD.md) · ⬜

Claude acting in a running mission while the squadron flies — spawn, destroy, move convoys, radio messages — through the bridge, with an operator token and never raw Lua. Written up 2026-10-08 and decided by David: free by default, nothing shown when Claude plays red, text and SRS voice when it warns blue players; seven tickets, one of them in the bridge's repository.

### [POC-DCS-DYNAMIC-WEATHER](POC-DCS-DYNAMIC-WEATHER/PRD.md) · ⬜

Measure DCS's dynamic weather on our server before using it in persistent campaigns: does it change during a mission, do clients see the same, what a restart gives. A test mission flown by two clients on Privé 2; answers go to the DCS traps and the campaign page. Until then, persistent campaigns take the bot's real weather (David, 2026-11-17).

### [FIX-BFR-PORT-FINDINGS](FIX-BFR-PORT-FINDINGS/PRD.md) · ⬜

What BFR's port of SeaShepherd, Bluestorm and SandBlast found in the runtime and the docs (#1296-#1299, #1304-#1306, #1308): Skynet set-up warnings off the players' screens, a coalition that holds under a per-pilot parent, the player's name on a per-pilot menu, a QRA draw that keeps its count, and the docs. Five tickets; opened 2026-11-23.

### [FIX-CONVERT-V5-PARITY](FIX-CONVERT-V5-PARITY/PRD.md) · ⬜

A converted v5 mission behaves as it did in v5 or says what changed (#1300-#1303): a v5-parity configuration, a conversion that cannot finish writes nothing, `VEAF_DYNAMIC_MISSIONPATH` on the mission folder, `custom_scripts` syntax checked. Four tickets; opened 2026-11-23.
