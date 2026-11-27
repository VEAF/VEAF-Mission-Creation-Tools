# Done lots

[Back to the backlog](README.md)

Closed lots still on disk; each moves to the archive three days after it closed.

## ✅ Done

### [FEAT-CHERRY-AI-SETUP](FEAT-CHERRY-AI-SETUP/PRD.md) · ✅

`ai-setup` connects Cherry Studio: it sets the MCP server `veaf` in Cherry's database with Cherry closed, with `--only`, `--cherry-assistant` and `--cherry-data-dir`. Closed 2026-11-27.

### [FEAT-MCP-PROMPTS](FEAT-MCP-PROMPTS/PRD.md) · ✅

The MCP server publishes four prompts, one per kind of mission, with typed arguments in French; phase 2 (editing prompts) is a list only. Closed 2026-11-27.

### [FIX-MCP-REPLAY-FINDINGS](FIX-MCP-REPLAY-FINDINGS/PRD.md) · ✅

What the local-model replay of Marteau du Golan block 1 found: the guide's examples are placeholders, the action `list_airfield_aircraft` says what an airfield offers, a misspelt aircraft type gets a suggestion. Closed 2026-11-27.

### [FEAT-AIRDROMES-DUMP-UNION](FEAT-AIRDROMES-DUMP-UNION/PRD.md) · ✅

The airfields DCS adds after the reference database resolve by name: the generator joins the database and the runtime dumps on the airdrome id, and GermanyCW was captured again on DCS 2.9.32 (+20 airfields). Kola's three new airfields wait for a capture. Closed 2026-11-26.

### [FIX-BRIEFING-ZONE-WAYPOINT-NUMBER](FIX-BRIEFING-ZONE-WAYPOINT-NUMBER/PRD.md) · ✅

Every zone page of a mission briefing gives its waypoint as the maps label it (`Point : W4/H4 — TALBISEH du plan de vol`). Closed 2026-11-24.

### [FEAT-ASSIST-FOLLOWUP](FEAT-ASSIST-FOLLOWUP/PRD.md) · ✅

What `FEAT-ASSIST-CHECKLISTS` left open: content-hashed resource names (DCS caches images by name), two pilots at once, and a pilot's review of the F-16C slice. Closed 2026-11-24. Flight check: change a label, rebuild and fly without restarting DCS (ticket 01); two assisted pilots at once, and an F-16C pilot through the checklist (tickets 02, 03). Ticket 04, the `c_cockpit_param_in_range` probe, was dropped.

### [FIX-CAMPAIGN-MISSION-1-FINDINGS](FIX-CAMPAIGN-MISSION-1-FINDINGS/PRD.md) · ✅

What the squadron found flying *Kolkhida* mission 1 on 2026-10-08, with no script error all evening: no radio presets nor right kneeboard on any aircraft, ATC not silenced, garrison units on the runways, CTLD crates and troops unavailable at the blue airfields, objective waypoints in the air, a red convoy smoking itself for blue, and the server's DCSServerBot replacing the campaign's date, time and clear sky with real weather. Decided: a QRA takes off from the ground by default. Ten tickets, one PR: the code is in; left are the CTLD release that takes the unit's country, the server's MizEdit filter, and the in-game checks of R47. Ticket 11, `campaign apply` crashing on a state file already in its mission folder, ships in its own PR. Flight check: none left; tickets 05, 08 and 09 were closed unchecked when the campaign was won (2026-11-24).

### [FEAT-CAMPAIGN-OBJECTIVE-WAYPOINTS](FEAT-CAMPAIGN-OBJECTIVE-WAYPOINTS/PRD.md) · ✅

`campaign next` writes the mission's objectives as waypoints for the players' side (planes at 10 000 ft, helicopters at 500 ft above the ground), and the mission briefing gains a navigation page read from the built mission. Merged on `develop` (#1107, 2026-10-08). Flight check: on a campaign mission, the waypoints are on the players' route and the briefing's navigation page matches them.

### [FIX-BUNDLE-LOCAL-LIMIT](FIX-BUNDLE-LOCAL-LIMIT/PRD.md) · ✅

The VEAF bundle built from `develop` no longer loaded in DCS: concatenated, its modules declared more than the 200 top-level locals a Lua 5.1 chunk accepts. Each module goes into its own `do … end` block, and a test runs the bundle under Lua 5.1. Merged on `develop` (#1102, 2026-10-08). Flight check: a mission built from `develop` loads its VEAF bundle in DCS.

### [FIX-SPAWN-DATA-LOAD-ORDER](FIX-SPAWN-DATA-LOAD-ORDER/PRD.md) · ✅

A campaign draws its garrisons while `veaf-config.lua` runs, but the groups database loaded from a last trigger, after it: every garrison came out without its air defence (no SA-10 at Senaki). The spawn data loads with the framework instead, as the last action of its load triggers. Merged on `develop` (#1104, 2026-10-08). Flight check: a campaign mission's garrisons come with their air defence and `dcs.log` has no `cannot find group`.

### [FIX-CAMPAIGN-ARROW-ALTITUDE](FIX-CAMPAIGN-ARROW-ALTITUDE/PRD.md) · ✅

DCS drew each assault-convoy arrow twice on the F10 map, one copy sliding as the map was panned; points on the terrain (#1103) did not change it. The axis becomes a line in the side's colour over the link. Merged on `develop` (#1105, 2026-10-08). Flight check: one line, which does not slide when the map is panned.

### [FEAT-CAMPAIGN-INTEL-DELAY](FEAT-CAMPAIGN-INTEL-DELAY/PRD.md) · ✅

The other side hears of an assault convoy `rules.intel_seconds` after it left (20 minutes by default), message and map line together; its own side at once. Merged on `develop` (#1106, 2026-10-08). Flight check: on a campaign mission, the other side hears of a convoy 20 minutes late.

### [FIX-COMBATZONE-DEAD-UNIT-HAS-NO-GROUP](FIX-COMBATZONE-DEAD-UNIT-HAS-NO-GROUP/PRD.md) · ✅

A combat zone's info panel and its completion disagreed: the panel was blind to static targets (fixed, #1030) and spawned vehicles now start warm — the scripts were seen asking for it in game on 2026-10-03. Flight check: the thermal look (R35 of `DCS-SESSION-TODO.md`), an IR pod finding a zone's vehicles.

### [FIX-SECU-VERB-AND-LOG-NOISE](FIX-SECU-VERB-AND-LOG-NOISE/PRD.md) · ✅

A private1 session where a level-99 pilot could not activate a zone, plus traceback-raising chat commands and log noise. Merged in #1032 (2026-09-30), deployed (6.26.0, hook on the six servers 2026-10-01). Flight check: R38 — a listed pilot clicks a secured command on a live server, before and after a reload.

### [FIX-SANCTUARY-WEAPON-TARGET-NO-ISEXIST](FIX-SANCTUARY-WEAPON-TARGET-NO-ISEXIST/PRD.md) · ✅

12 `attempt to call method 'isExist' (a nil value)` in the Privé 1 log of the Sinai Open Training (2026-10-12): `weapon:getTarget()` returned an object with no `isExist`. The sanctuary now ignores such a target and logs its category once per mission. Merged in #1139 (2026-10-14). Measured: a Maverick on a unit gets a complete `Unit`. Flight check: R50 — the logged category in the next server `dcs.log`, or a pilot's shots on a house and a hangar.

### [FEAT-COMBAT-LOG](FEAT-COMBAT-LOG/PRD.md) · ✅

A combat log for an exact debrief: every shot, hit, kill and gun burst written as JSON lines by the mission, and `veaf-tools mission combat-log` for the recap per pilot. Merged (#1222, #1223, 2026-10-30). Flight check: R54 of `DCS-SESSION-TODO.md`, a fight flown by two pilots, one in a helicopter with a gun, to measure what DCS gives for gun shells.

### [FIX-CAMPAIGN-GROUND-KILLS-UNPAID](FIX-CAMPAIGN-GROUND-KILLS-UNPAID/PRD.md) · ✅

Since 2026-11-15 a player's kill of a ground unit paid nothing and counted nothing: the kill's target was read by name after the unit was gone, so it looked neutral and `readPlayerKill` dropped it (31, 24, 13, 10 and 8 kills unpaid on 2026-11-21; only air kills paid). Fixed: the raw target is asked, then the campaign's own records; every pilot who took a slot is on the sitac's ranking; the evening's summary is written when the last player leaves his slot. Merged in #1327 (2026-11-22), shipped in 6.39.0. Flight check: an evening's ground kills paid and ranked on the Campagne server.

### [FIX-CAMPAIGN-CONVOY-STUCK-IN-CONTACT](FIX-CAMPAIGN-CONVOY-STUCK-IN-CONTACT/PRD.md) · ✅

A convoy that cannot drive onto its enemy renewed its own contact at every push, so `convoyMayLeave` kept it "in contact" for ever (Menagh, 2026-11-21). Fixed: only a shot or an enemy newly seen is a contact, and after 3 pushes that move nothing the convoy drives on. Merged in #1326 (2026-11-22), shipped in 6.39.0. Flight check: no convoy held in contact for hours on the Campagne server.

### [FIX-GROUNDAI-CLOSE-IN-REACHABLE](FIX-GROUNDAI-CLOSE-IN-REACHABLE/PRD.md) · ✅

The cause behind FIX-CAMPAIGN-CONVOY-STUCK-IN-CONTACT: `closeIn` drove a convoy onto the enemy's exact point in one off-road segment, which DCS may refuse silently. Fixed: the close in aims 300 m short of the enemy along a path checked for water and slope, an order that moved nothing is known 25 s later and the next push takes another aim at once, no route starts `On Road` off the road, and a spawned convoy gets its first route 5 s after its creation. Merged in #1328 and #1331 (2026-11-22), shipped in 6.39.0. Flight check: convoys seen closing in on the Campagne server.

### [FEAT-CAMPAIGN-PILOT-EARNINGS-MENU](FEAT-CAMPAIGN-PILOT-EARNINGS-MENU/PRD.md) · ✅

A "Mes gains" entry in the persistent campaign's F10 Campaign menu, split per pilot: each pilot reads, to him alone, what he earned this session by reason, what his aircraft holds until landing, his campaign total and rank, his kills and deaths, and the team's gains. "This session" is the period of the `CREDITS SUMMARY`. Merged in #1329 (2026-11-22), shipped in 6.39.0. Flight check: the entry read in game on the Campagne server.

### [FEAT-CAMPAIGN-AIR-DEFENCE-VARIETY](FEAT-CAMPAIGN-AIR-DEFENCE-VARIETY/PRD.md) · ✅

Every air defence DCS offers in the campaign: the Tor M2 and the Pantsir S1 in red's modern short range, a `medium_range_sam` zone option giving red an SA-11, SA-6 or SA-3 battery, and the IRIS-T SLM and the Rapier for blue, as a VEAF group and shop upgrades. One PR, merged in #1330 (2026-11-22), shipped in 6.39.0. Flight check: the new batteries seen on the Campagne server.

### [FEAT-CAMPAIGN-SKYNET](FEAT-CAMPAIGN-SKYNET/PRD.md) · ✅

The persistent campaign's SAM sites run under Skynet, both sides: `campaign next` turns the SKYNET module on (`dynamic.skynet.enabled: false` keeps it off); a garrison's multi-piece SAM (the blue level-5 Hawk) moves to a group of its own, `<zone> SAM`, on a fresh draw and on a loaded save; the campaign declares every SAM group it spawns to its side's network, replacing an old site of the same name, one `[CAMPAIGN SKYNET]` line each. Merged in #1335 (2026-11-22), shipped in 6.39.0. Flight check: on the Campagne server after the redeploy.

### [FIX-RADIO-NEXT-PAGE-IN-F10](FIX-RADIO-NEXT-PAGE-IN-F10/PRD.md) · ✅

"Next page" is the last entry of every radio menu page. DCS lists a menu's entries in the order they were created, so a per-group entry rendered when its pilot joins (the shop's escort, My earnings, My spawns, a secured command) or an entry recreated with new parameters landed below the "Next page" rendered before; `veafRadio` now renews the link, with the pages under it, when anything was created on its page. Merged in #1342 (2026-11-23), shipped in 6.39.1. Flight check: on the Campagne server, "Next page" is the last entry in F10 as in F9.

### [FEAT-CAMPAIGN-CONVOYS-FOLLOW-STRIKERS](FEAT-CAMPAIGN-CONVOYS-FOLLOW-STRIKERS/PRD.md) · ✅

The enemy's assault convoys sized for the players who can stop them (Griffin and David, 2026-11-21): one convoy on the road per 4 strikers, CAS aircraft or attack helicopters, neutral-zone assaults included, fighters and SEAD-only aircraft not counted; a counter-attack prefers a zone no such player is defending. Two tickets, merged in #1324 (2026-11-21), shipped in 6.39.0. Flight check: on the Campagne server, never two red convoys on the road for one or two strikers.

### [FIX-CAMPAIGN-ECONOMY-BALANCE](FIX-CAMPAIGN-ECONOMY-BALANCE/PRD.md) · ✅

What the players earn pays for what the shop sells (David, 2026-11-20): rewards aligned on Foothold's (SAM 30, aircraft 50, building 100, rescue 200), the NASAMS and the Patriot at Foothold's prices, an evening's balance of earned and spent in the log for both sides, an economy simulator and one price rule. Five tickets, merged in #1323 (2026-11-20), shipped in 6.39.0. Flight check: read an evening's `ECONOMY SUMMARY` and tune the prices.

### [FEAT-CAMPAIGN-SHOP-UPGRADES](FEAT-CAMPAIGN-SHOP-UPGRADES/PRD.md) · ✅

Air defence and the CAS and SEAD flights in the campaign shop (David, 2026-11-19, after comparing with Foothold's catalogue): zone upgrades — Hawk, NASAMS, Patriot, Avenger, Gepard, infantry, armour — that join the zone's garrison, two per zone, priced at their spawn price; CAS and SEAD flights against an enemy zone. Two tickets, merged in #1322 (2026-11-20), shipped in 6.39.0. Flight check: a pilot buys an upgrade and a SEAD flight on the Campagne server.

### [FEAT-CAMPAIGN-MISSION-FILE](FEAT-CAMPAIGN-MISSION-FILE/PRD.md) · ✅

A persistent campaign names its mission file in `campaign.yaml` (`campaign.mission_file`), and the build writes it with no date (`mission.date_suffix: false` in `mission.yaml`), so the DCS server browser shows a readable name and a redeploy just replaces the file. Decided by David on 2026-11-18 for "Bouclier de l'Oronte": `Campagne_Oronte.miz`. One ticket, merged in #1313 (2026-11-18), shipped in 6.39.0. Flight check: the server browser lists the mission without a date.

### [FEAT-CAMPAIGN-SITAC-STATE](FEAT-CAMPAIGN-SITAC-STATE/PRD.md) · ✅

The persistent campaign's `persistent.state` gains a `sitac` block for VEAF's web map `foothold-sitac`: zones with position, kind, waypoint, owner, garrison counts, capture, buildings and dormancy; the connections; the convoys under way; each side's credits and stock. One file, ignored by the reload. Merged in #1309 (2026-11-18), shipped in 6.39.0; the reader landed in `VEAF/foothold-sitac` (#148, 2026-11-18). Flight check: the web map draws the Campagne server's live save.

### [FIX-CAMPAIGN-ASSAULT-ORDER-OPEN](FIX-CAMPAIGN-ASSAULT-ORDER-OPEN/PRD.md) · ✅

Every player can order a paid blue assault (Rex and David, 2026-11-21): in a persistent campaign the Campaign → Assaults order is a purchase, so it is no longer secured, and the shop and the player guide say where it is and what it costs. One ticket, merged in #1325 (2026-11-21), on `develop` with #1336, shipped in 6.39.0. Flight check: on the Campagne server, a player who has not logged in to VEAF security orders an assault and a blue convoy leaves.

### [FEAT-PERSISTENT-CAMPAIGN-AI](FEAT-PERSISTENT-CAMPAIGN-AI/PRD.md) · ✅

Build a persistent campaign with the AI assistant alone, no repository and no terminal (David, 2026-11-24): MCP actions `campaign_init` (with the shipped example) and `campaign_validate`, `campaign.yaml` and `briefing.yaml` reachable by `read_mission_file` / `edit_mission_file`, a `persistent-campaign` mission prompt, and a "With an AI" section in the campaign page and the AI catalogue. Four tickets, one PR; done 2026-11-24.

### [FEAT-BRIEFING-PER-LANGUAGE](FEAT-BRIEFING-PER-LANGUAGE/PRD.md) · ✅

A `language` parameter for `build_mission_briefing`, writing only the archives of that language, so a bilingual mission (the demo's `_FR` and `_EN`) gets its briefing and kneeboard pages in each language. One ticket; asked from the demo's kneeboard step (2026-10-26), done 2026-11-23.

### [FIX-CONVERT-V5-PARITY](FIX-CONVERT-V5-PARITY/PRD.md) · ✅

A converted v5 mission behaves as it did in v5 or says what changed (#1300-#1303): a v5-parity configuration, a conversion that cannot finish writes nothing, `VEAF_DYNAMIC_MISSIONPATH` on the mission folder, `custom_scripts` syntax checked. Four tickets; opened 2026-11-23.

### [FIX-BFR-PORT-FINDINGS](FIX-BFR-PORT-FINDINGS/PRD.md) · ✅

What BFR's port of SeaShepherd, Bluestorm and SandBlast found in the runtime and the docs (#1296-#1299, #1304-#1306, #1308): Skynet set-up warnings off the players' screens, a coalition that holds under a per-pilot parent, the player's name on a per-pilot menu, a QRA draw that keeps its count, and the docs. Five tickets; opened 2026-11-23.

### [CHORE-VENDOR-CTLD-2-1-0](CHORE-VENDOR-CTLD-2-1-0/PRD.md) · ✅

CTLD `2.1.0` vendored for 6.39.0, with the fixes BFR asked for: dropped groups act on their own again, players can drive what CTLD creates, inactive troop and waypoint zones stay inactive, nothing is lost when DCS refuses a pack or an unpack. Catalogue `2.3.0` → `2.5.0` with three new settings (`maximumMoveDistance`, `spawnedUnitsPlayerCanDrive`, `forbidUnpackInLogisticZone`).

### [FIX-OT-KNEEBOARD-LAYOUT](FIX-OT-KNEEBOARD-LAYOUT/PRD.md) · ✅

The kneeboard pages of an Open Training, as the eight OTs regenerated with 6.37.0 showed them: a long title wrapped instead of running off the page, the "Commandes" sheet on one page, a zone's one recon photo under its zoom rather than on a half-empty page, the caption in DDM, and a zone entry never cut between two pages.

### [FIX-COMBATZONE-FIRST-ROUTE](FIX-COMBATZONE-FIRST-ROUTE/PRD.md) · ✅

A group a combat zone spawns from a VEAF command gets its route from the zone's hook in its creation frame, where DCS drops it; give it through `veafSpawn.giveFirstRoute`, 5 s later. Left over by FIX-SPAWN-GROUP-FIRST-ROUTE (2026-11-22). Merged into `feature/dynamic-campaign` (#1332). Done 2026-11-22: checked in game, the command group drove off 5 to 10 s after the zone's activation and followed its route north.

### [FIX-OPEN-TRAINING-SYRIA-FINDINGS](FIX-OPEN-TRAINING-SYRIA-FINDINGS/PRD.md) · ✅

What building the Syria Open Training v6 through the MCP found: callsigns, loadouts, QRA simple groups, FARP ammo, FAC task, METAR and more. All 18 tickets done on 2026-11-24; the last, the CTLD JTAC imposed laser code and ASSETS radio, shipped with CTLD `2.0.0-rc13` in 6.29.0.

## 🚫 Won't fix
