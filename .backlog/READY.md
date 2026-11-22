# Ready lots

[Back to the backlog](README.md)

Lots written up and ready to take.

### [FIX-CAMPAIGN-FIFTH-SERVER-FLIGHT](FIX-CAMPAIGN-FIFTH-SERVER-FLIGHT/PRD.md) · ⬜

What the 22/11 afternoon on the Campagne server showed: red CAS Su-25 shooting down the AWACS (weapon free, R-60M), Hatay's Hawk never firing (a SAM inside the garrison's single mixed group, to measure first), the AWACS holding too near the front, and supply helicopters destroyed by a fixed 20 min timeout shorter than their flight. Four tickets, one PR into `feature/dynamic-campaign` (2026-11-22).

### [FEAT-SPAWN-OWNERSHIP-DESPAWN](FEAT-SPAWN-OWNERSHIP-DESPAWN/PRD.md) · ⬜

Each pilot can remove from the F10 menu what his markers spawned (`-sa6`, `-armor`, `-cas`, `-convoy`, `-farp`…), all at once or one by one: the runtime records every marker-spawned group with its author, combat zones left out since they clean their own. `-destroy` stays a trusted member's command. Three tickets, eight questions with a reco each; asked by David while correcting the Open Training conduct sheet (2026-11-10).

### [FEAT-BRIEFING-PER-LANGUAGE](FEAT-BRIEFING-PER-LANGUAGE/PRD.md) · ⬜

A `language` parameter for `build_mission_briefing`, writing only the archives of that language, so a bilingual mission (the demo's `_FR` and `_EN`) gets its briefing and kneeboard pages in each language. One ticket; asked from the demo's kneeboard step (2026-10-26).

### [FEAT-CLEAR-GROUND-COVERAGE](FEAT-CLEAR-GROUND-COVERAGE/PRD.md) · ⬜

Widen the shipped clear-ground catalogues to the places missions are built — round airfields, towns, road axes — under a weight ceiling per theatre. Needs a survey flown in DCS, so David's time; split from FIX-DEMO-VIDEO-FINDINGS (2026-10-23).

### [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) · ⬜

Broaden the shipped default radio presets, after phase 1 of the radio preset projection.

### [FEAT-LIVE-GAME-MASTER](FEAT-LIVE-GAME-MASTER/PRD.md) · ⬜

Claude acting in a running mission while the squadron flies — spawn, destroy, move convoys, radio messages — through the bridge, with an operator token and never raw Lua. Written up 2026-10-08 and decided by David: free by default, nothing shown when Claude plays red, text and SRS voice when it warns blue players; seven tickets, one of them in the bridge's repository.

