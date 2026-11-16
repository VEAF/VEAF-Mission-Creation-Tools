# Ready lots

[Back to the backlog](README.md)

Lots written up and ready to take.

### [FIX-OPEN-TRAINING-PILOT-FEEDBACK](FIX-OPEN-TRAINING-PILOT-FEEDBACK/PRD.md) · ⬜

David's notes after flying the Open Trainings: the helicopter hard tier is really a medium one (no radar-guided short-range system, add Tor, Tunguska, Osa), and the QNH must show inHg as well as hPa in the welcome message and the ATIS. The training ranges must stand out of the forests, starting with the Ceyhan helicopter range of Syria. His third note, the radio menu order, is already done by FEAT-RADIO-MENU-ORDER and waits for the next release. Three tickets, three decisions with a reco each (2026-11-15).

### [FEAT-BRIEFING-PER-LANGUAGE](FEAT-BRIEFING-PER-LANGUAGE/PRD.md) · ⬜

A `language` parameter for `build_mission_briefing`, writing only the archives of that language, so a bilingual mission (the demo's `_FR` and `_EN`) gets its briefing and kneeboard pages in each language. One ticket; asked from the demo's kneeboard step (2026-10-26).

### [FEAT-CLEAR-GROUND-COVERAGE](FEAT-CLEAR-GROUND-COVERAGE/PRD.md) · ⬜

Widen the shipped clear-ground catalogues to the places missions are built — round airfields, towns, road axes — under a weight ceiling per theatre. Needs a survey flown in DCS, so David's time; split from FIX-DEMO-VIDEO-FINDINGS (2026-10-23).

### [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) · ⬜

Broaden the shipped default radio presets, after phase 1 of the radio preset projection.

### [FEAT-LIVE-GAME-MASTER](FEAT-LIVE-GAME-MASTER/PRD.md) · ⬜

Claude acting in a running mission while the squadron flies — spawn, destroy, move convoys, radio messages — through the bridge, with an operator token and never raw Lua. Written up 2026-10-08 and decided by David: free by default, nothing shown when Claude plays red, text and SRS voice when it warns blue players; seven tickets, one of them in the bridge's repository.
