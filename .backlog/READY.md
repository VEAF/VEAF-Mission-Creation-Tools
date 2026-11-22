# Ready lots

[Back to the backlog](README.md)

Lots written up and ready to take.

### [FIX-GROUNDAI-CLOSE-IN-REACHABLE](FIX-GROUNDAI-CLOSE-IN-REACHABLE/PRD.md) · ⬜

The cause behind FIX-CAMPAIGN-CONVOY-STUCK-IN-CONTACT: `closeIn` drives a convoy onto the enemy's exact point in one off-road segment, which DCS may refuse silently. Aim at a reachable point on a checked path (water, slope), check 30 s after an order that the convoy moved, and start no route `On Road` off the road. Three tickets; from the dcs-cartographie session's study of DCS ground AI movement (2026-11-22). Lands after FIX-CAMPAIGN-CONVOY-STUCK-IN-CONTACT.

### [FIX-CAMPAIGN-CONVOY-STUCK-IN-CONTACT](FIX-CAMPAIGN-CONVOY-STUCK-IN-CONTACT/PRD.md) · ⬜

A convoy that cannot drive onto its enemy renews its own contact at every push (`closeIn`, `pressOn`), so `convoyMayLeave` keeps it "in contact" for ever: on 2026-11-21 the Aleppo convoy stood still 1.3 km from Menagh from 22:00 to the end and held a place of the convoy cap. One ticket; found while watching the Campagne server (2026-11-21).

### [FIX-CAMPAIGN-GROUND-KILLS-UNPAID](FIX-CAMPAIGN-GROUND-KILLS-UNPAID/PRD.md) · ⬜

Since 2026-11-15 a player's kill of a ground unit pays nothing and counts nothing: the kill's target is read by name after the unit is gone, so it looks neutral and `readPlayerKill` drops it (31, 24, 13, 10 and 8 kills unpaid on 2026-11-21; only air kills paid). Ticket 02 puts every pilot who flew on the sitac's ranking, ticket 03 writes the evening's summary when the last player disconnects. Three tickets; found from David's report of an incomplete ranking (2026-11-21).

### [FEAT-CAMPAIGN-AIR-DEFENCE-VARIETY](FEAT-CAMPAIGN-AIR-DEFENCE-VARIETY/PRD.md) · ⬜

Every air defence DCS offers in the campaign: the Tor M2 and the Pantsir S1 in red's modern short range, a `medium_range_sam` zone option giving red an SA-11, SA-6 or SA-3 battery (red has no medium-range SAM at all today), and the IRIS-T SLM and the Rapier for blue, as a VEAF group and shop upgrades. Three tickets; asked by David after the 2026-11-21 evening on the Campagne server.

### [FEAT-CAMPAIGN-PILOT-EARNINGS-MENU](FEAT-CAMPAIGN-PILOT-EARNINGS-MENU/PRD.md) · ⬜

A "Mes gains" entry in the persistent campaign's F10 Campaign menu: each pilot reads what he earned this session, what his aircraft holds until landing, his campaign total and rank, and his kills. What each pilot earns was only in `dcs.log` and on the sitac's ranking page. One ticket; asked by David after the 2026-11-21 evening on the Campagne server.

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

