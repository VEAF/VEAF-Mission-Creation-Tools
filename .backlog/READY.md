# Ready lots

[Back to the backlog](README.md)

Lots written up and ready to take.

### [FIX-BUILD-NAME-AND-OT-PLACEMENT](FIX-BUILD-NAME-AND-OT-PLACEMENT/PRD.md) · ⬜

Three Discord reports of 2026-11-12: the build wizard proposes the name of the last mission built anywhere instead of the folder's `mission.yaml` name (Flogas, Sinai OT); the OT prompt gets a rule placing each side's defenses on its own side of the front (Rex, Beslan) and a `clear-ground check` of Mission Editor vehicles (Rex, Akamas). Two tickets; the OT repositories are fixed in a separate session.

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
