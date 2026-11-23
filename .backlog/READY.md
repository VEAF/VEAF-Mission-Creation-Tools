# Ready lots

[Back to the backlog](README.md)

Lots written up and ready to take.

### [FIX-RADIO-NEXT-PAGE-IN-F10](FIX-RADIO-NEXT-PAGE-IN-F10/PRD.md) · ⬜

Several radio menus show "Page suivante" in F9 and another entry in F10 (Campagne server, 2026-11-22): reproduce, list the menus, fix the cause in `veafRadio` so "Next page" is always the last entry of a page. One ticket, every mission concerned; split out of FIX-CAMPAIGN-SIXTH-SERVER-FLIGHT (2026-11-23).

### [FIX-CAMPAIGN-SIXTH-SERVER-FLIGHT](FIX-CAMPAIGN-SIXTH-SERVER-FLIGHT/PRD.md) · ⬜

What the 22/11 evening on the Campagne server showed: the capture timer counting up, a repair let through with an enemy convoy at the gates, that convoy sitting two hours "in contact", Menagh to rename Minakh (campaign data), a respawned AWACS that lost its callsign and says nothing, scattered infantry. Six tickets, one PR into `develop` (2026-11-23); the radio menus went to FIX-RADIO-NEXT-PAGE-IN-F10, the Fat Cow remark belongs to `VEAF/CTLD`.

### [FEAT-CLEAR-GROUND-COVERAGE](FEAT-CLEAR-GROUND-COVERAGE/PRD.md) · ⬜

Widen the shipped clear-ground catalogues to the places missions are built — round airfields, towns, road axes — under a weight ceiling per theatre. Needs a survey flown in DCS, so David's time; split from FIX-DEMO-VIDEO-FINDINGS (2026-10-23).

### [ENRICH-DEFAULT-PRESETS](ENRICH-DEFAULT-PRESETS/PRD.md) · ⬜

Broaden the shipped default radio presets, after phase 1 of the radio preset projection.

### [FEAT-LIVE-GAME-MASTER](FEAT-LIVE-GAME-MASTER/PRD.md) · ⬜

Claude acting in a running mission while the squadron flies — spawn, destroy, move convoys, radio messages — through the bridge, with an operator token and never raw Lua. Written up 2026-10-08 and decided by David: free by default, nothing shown when Claude plays red, text and SRS voice when it warns blue players; seven tickets, one of them in the bridge's repository.

### [POC-DCS-DYNAMIC-WEATHER](POC-DCS-DYNAMIC-WEATHER/PRD.md) · ⬜

Measure DCS's dynamic weather on our server before using it in persistent campaigns: does it change during a mission, do clients see the same, what a restart gives. A test mission flown by two clients on Privé 2; answers go to the DCS traps and the campaign page. Until then, persistent campaigns take the bot's real weather (David, 2026-11-17).


