# Done lots

[Back to the backlog](README.md)

Closed lots still on disk; each moves to the archive three days after it closed.

## ✅ Done

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

### [FIX-BUILD-EXE-SMOKE](FIX-BUILD-EXE-SMOKE/PRD.md) · ✅

A build that produces a `veaf-tools` executable which cannot start now fails: `--collect-submodules` sees the source tree whatever interpreter runs PyInstaller, and every built executable is started once before the build hands back. Found preparing 6.38.0, where a build run outside Poetry exited 0 with a dead executable (#1314).

### [FIX-OPEN-TRAINING-PILOT-FEEDBACK](FIX-OPEN-TRAINING-PILOT-FEEDBACK/PRD.md) · ✅

David's notes after flying the Open Trainings. QNH in hPa and inHg everywhere (#1280); a real helicopter hard tier (Tor, Tunguska, Osa) in the six Open Trainings; the radio menu order was already done by FEAT-RADIO-MENU-ORDER. The training ranges stand out of the forests: Ceyhan moved and checked in game on Syria, then `forest-check` run on the six Open Trainings (2026-11-16) — Akamas and Karpas on Syria, three groups on Caucasus, the three jungle ranges of Marianas (44 groups into clearings) moved; Falklands, Persian Gulf and Sinai had nothing to move. Reaches the players with the next VMCT release and `Publish-OT`.

### [FEAT-FOREST-CHECK](FEAT-FOREST-CHECK/PRD.md) · ✅

Forests read from a DCS map's `.surface5` file without the game, and `veaf-tools dcs forest-check <mission.miz>` to list the vehicles standing in one (#1285). A point counts as forest only when the forest is the overlay drawn on top there: Agana's airfield on Marianas WWII, checked on David's F10 captures, is drawn over a forest texture. Validated on David's six Syria places and on the parking stands of the eleven maps (2026-11-16).

### [FEAT-SPAWN-OWNERSHIP-DESPAWN](FEAT-SPAWN-OWNERSHIP-DESPAWN/PRD.md) · ✅

Each pilot can remove from the F10 menu what his markers spawned (`-sa6`, `-armor`, `-cas`, `-convoy`, `-farp`…), all at once or one by one: the runtime records every marker-spawned group with its author, combat zones left out since they clean their own. `-destroy` stays a trusted member's command. Three tickets, eight questions with a reco each; asked by David while correcting the Open Training conduct sheet (2026-11-10). Done 2026-11-16: `veafCommands` hands marker handlers a watched collection, `veafSpawnOwnership.lua` files each marker's groups under its author and builds SPAWN › Next page › My spawns › [name] (remove all, or one marker), `-cas` passes its marker id; pilot guide, veafSpawn page, OT sheets and demo step (VEAF/VEAF-Demo-Mission-v6#14). Left: one look in game that the marker author matches the slot's player name.

### [FIX-COMBATZONE-FIRST-ROUTE](FIX-COMBATZONE-FIRST-ROUTE/PRD.md) · ✅

A group a combat zone spawns from a VEAF command gets its route from the zone's hook in its creation frame, where DCS drops it; give it through `veafSpawn.giveFirstRoute`, 5 s later. Left over by FIX-SPAWN-GROUP-FIRST-ROUTE (2026-11-22). Merged into `feature/dynamic-campaign` (#1332). Done 2026-11-22: checked in game, the command group drove off 5 to 10 s after the zone's activation and followed its route north.

### [FIX-BUILD-NAME-AND-OT-PLACEMENT](FIX-BUILD-NAME-AND-OT-PLACEMENT/PRD.md) · ✅

Three Discord reports of 2026-11-12: the build wizard proposes the name of the last mission built anywhere instead of the folder's `mission.yaml` name (Flogas, Sinai OT); the OT prompt gets a rule placing each side's defenses on its own side of the front (Rex, Beslan) and a `clear-ground check` of Mission Editor vehicles (Rex, Akamas). Done 2026-11-12: the wizard proposes the folder's `mission.yaml` name and the folder itself over saved values; the OT prompt (fr, en) and the authoring guide carry both rules. The OT repositories are fixed in a separate session.

### [FIX-OT-RADIO-PLAN-CONVENTION](FIX-OT-RADIO-PLAN-CONVENTION/PRD.md) · ✅

The OT prompt told sessions to put airfields and flights on both UHF and VHF, so each OT spreads them over two 20-channel radios and a pilot finds Ramat David only in UHF and Archer only in VHF (Syria, 2026-11-11). The prompt states the template's convention — VHF for the airfields, UHF for AWACS and tankers first, then carriers and flights, no drones, no Guard — and the eight OTs' plans are rewritten to it. Reported by David (2026-11-11). Done 2026-11-11: the prompt is fixed, the seven served-or-built OTs are rewritten, rebuilt and checked on a blue A-10C II, six deployed with `Publish-OT.ps1` (Falklands is served by no instance); Normandy left as it is (one radio).

### [FIX-RADIO-CAPACITY-FOLLOWUP](FIX-RADIO-CAPACITY-FOLLOWUP/PRD.md) · ✅

Presets assigned through `presets_assignments` stop at the radios' capacity too, on a copy (the defaults' blue CH-47F gets 20 of `radio_fm_30`'s 30 FM presets, the list unchanged), and a build logs one summary warning for every radio it cut instead of one per radio: a default build went from 29 warnings to one. Follow-up of #1263 (2026-11-11).

### [FEAT-RADIO-CAPACITY-ALL-TYPES](FEAT-RADIO-CAPACITY-ALL-TYPES/PRD.md) · ✅

Every radio of 87 of the 100 aircraft types stops at the preset count its module's `panelRadio` lists, read from the pinned DCS datamine by the radio-specs generator (`channels` in `dcs-radio-specs.yaml`), under the band-based default too; the cut goes by slot number so lists with gaps keep their channel numbers. The shipped `fm_supplement` holds 20 entries; warbird, Mosquito and AH-64D radios still cut the shipped shared lists, with a warning. Follow-up of #1262 (2026-11-10).

### [FIX-RADIO-PRESET-CAPACITY](FIX-RADIO-PRESET-CAPACITY/PRD.md) · ✅

The OH-58D, Mi-24P and CH-47F radios declare their capacity from their module's `panelRadio` channel count (Kiowa FM: 21; 32 crashed the client at spawn), and a truncation warns at build, once per radio. The shipped defaults raise it for the Kiowa template, whose 30-entry `fm_supplement` gave 32 FM presets. Reported by David, 2026-11-10.

### [FIX-KNEEBOARD-PAGE-WEIGHT](FIX-KNEEBOARD-PAGE-WEIGHT/PRD.md) · ✅

The kneeboard pages saved at 1024 px and JPEG quality 80 instead of 1536 px and 88, after the Open Training kneeboard added 9 to 18 MB per mission. Drawn as before, only brought down when saved. One ticket; decided by David (2026-11-10).

### [FEAT-RADIO-MENU-ORDER](FEAT-RADIO-MENU-ORDER/PRD.md) · ✅

The VEAF F10 root menus in the order pilots use them — combat zones, weather, assets first — through a fixed `sortKey` per root menu, the same in every language, instead of the alphabetical order that puts ZONES DE COMBAT last in French. The CAS menu stays forever at the end, and its entries stop being deleted and recreated. Three tickets; decided with David (2026-11-10).

### [FIX-ALIAS-SKIPS-HANDLER-LEVEL](FIX-ALIAS-SKIPS-HANDLER-LEVEL/PRD.md) · ✅

An alias called its module's `executeCommand` directly, past the level the dispatcher enforces: `_move`, `_radio` and `_gc` ran for any player through `-tankerlow`, `-send`, `-ai_set`, `-arty1_fire`…, unknown to the server included (worse than the survey's VEAF-pilot reading). A non-bypassing alias now applies the level of the handler its own command reaches, or the one it declares; the tanker and AFAC aliases declare VEAF pilot (David), `-send`/`-play` take trusted member, the `_gc` aliases VEAF pilot.

### [FEAT-OPEN-TRAINING-KNEEBOARD](FEAT-OPEN-TRAINING-KNEEBOARD/PRD.md) · ✅

An Open Training's briefing as kneeboard pages in the `.miz`: `build_mission_briefing` gains `kneeboard_only` (the kneeboard and nothing else — no deck, PDF or DCS picture, no flight card, a zone list with each zone's F10 path and centre) and `sheets` (free text first in the kneeboard); the OT prompt writes the mission, conduct and commands sheets and keeps the content in `docs/kneeboard.json`. Tried on a copy of the Caucasus OT: 36 pages. Putting it into the three OTs waits for a VMCT release.

### [DOC-HOTLOAD-RECIPE](DOC-HOTLOAD-RECIPE/PRD.md) · ✅

A developer page on loading dcs-hotload (MacFlorent/dcs-hotload) in a VMCT-built mission with no VMCT code, rewritten on 2026-11-11 to follow hotload's own model: one copy extracted into the mission folder, unlocked with its `hotload-setup.py`, booted by a script declared in `custom_scripts` that finds it from `VEAF_DYNAMIC_MISSIONPATH`, so in a dynamic build only, and writes a `HOTLOAD: not booted:` line to `dcs.log` otherwise. Reservations: install-wide `io`/`lfs` unlock, `status` blind to this boot, one F10 root entry, VEAF modules are not reloaded. Chosen by David and Flogas over a `hotload:` build key; merged in #1257, revised by ticket 02 (which also fixed the reference's `FgDebug.lua` profile example), not tested in game.

### [FEAT-DCS-EDITOR-LUA-LAYOUT](FEAT-DCS-EDITOR-LUA-LAYOUT/PRD.md) · ✅

Two points Flogas raised (2026-11-09): a built mission's `mission` file is written in the Mission Editor's layout (`["coalition"] = `, tabs, `-- end of`), so tools that read a mission's text read VEAF's too; and the migration guide shows how to add your own steps after the build with a `build.ps1` and a build profile, since v6 has no `build.cmd` to edit. One PR (#1251).

### [CHORE-RELEASE-CI-REDUNDANCY](CHORE-RELEASE-CI-REDUNDANCY/PRD.md) · ✅

The 6.36.0 release started 27 runs, 15 of them on a tree its pull request had already tested: the check workflows no longer run on a push to `master`, and the release back-merge carries `[skip ci]`. The bot and chatbot publications keep `master`. And the release carries its SBOM again: `publish --force` recreated the release after `sbom.yml` had attached it. One PR.

### [CHORE-VENDOR-CTLD-RC17](CHORE-VENDOR-CTLD-RC17/PRD.md) · ✅

CTLD `2.0.0-rc17` vendored ahead of the release: a piloted Fat Cow leaves its FARP open and packs it as crates on the ground, loadouts come as crates to load, no Fat Cow menu for aeroplanes, and the JTAC logs its laser code. No new setting, catalogue unchanged.

### [FEAT-BFR-V6-SUPPORT](FEAT-BFR-V6-SUPPORT/PRD.md) · ✅

What VMCT needs so BFR (Sharko) can plug its own script layer into v6, from the study of Bluestorm V2 and SeaShepherd V2 (2026-10-27): two security fixes, the F10 menu in multiplayer (live pilot, group submenus, per-pilot submenus), combat zone fixes, a carrier option, modules initialized by the mission, the weather welcome switch, named points from a script, the v5 converter, and a page on porting a mission with its own script layer. Fourteen tickets, one PR. Merged in #1203 and shipped in 6.33.0; closed on 2026-11-04 without the in-game checks of tickets 01, 03-05, 07, 12 and 13, left to BFR.

### [FIX-AUDIT-FINDINGS-2026-11](FIX-AUDIT-FINDINGS-2026-11/PRD.md) · ✅

The four audit findings on VMCT (`davidp57/security-audits` #137, #138, #146, #147) and the seven `pypdf` Dependabot alerts: nested filtered F10 menus keep their filter, `help_menus` negated with the same generated call by default, a static on another unit warned again, `set_route` takes `HOME, IP, TGT, HOME`. Five tickets, one PR (#1236).

### [FEAT-TRAINING-BRIEFING-PAGES](FEAT-TRAINING-BRIEFING-PAGES/PRD.md) · ✅

The training versions in the mission briefing: one page per version at the end of the deck and of the PDF, computed with the build's own rules, and a `label:` key to name an element or a draw for the pilots. Used for *Marteau du Golan*'s training versions on Privé 1 and Privé 2 (2026-11-03). One PR (#1234).

### [FEAT-ROLE-TRAINING-VARIANTS](FEAT-ROLE-TRAINING-VARIANTS/PRD.md) · ✅

Training versions of a mission night, built with it from a `training:` block in `mission.yaml`: one per role (A2G, CAP, SEAD) in the state "the other roles have done their job", one common, same setting and same briefing. What the briefing describes vaguely is drawn again at every launch by a combat zone; a draw follows the rules of what it draws, and the CAP version keeps every air defence. `remove_groups:` for any profile, and two MCP actions to draft and write the block. Checked in DCS on a copy of *Marteau du Golan* (2026-11-03): the draws differ at every launch, and `math.randomseed` does not exist in a mission. One PR.

### [FIX-FLAKY-AIRDROME-POSITIONS](FIX-FLAKY-AIRDROME-POSITIONS/PRD.md) · ✅

A random red on `python-quality`: the `update-dcs-data` dispatch tests left the airdromes generator unpatched, so `--all` downloaded the reference database and rewrote the shipped `airdrome-positions.yaml` in place while other xdist workers read it — a reader caught it truncated and got `None`. The generator is patched, and a guard test asserts a dispatch run leaves `veaf_libs/data` untouched. One PR.

### [CHORE-VENDOR-CTLD-RC16](CHORE-VENDOR-CTLD-RC16/PRD.md) · ✅

CTLD `2.0.0-rc16` vendored ahead of the release: an AI Fat Cow that loses its flight can be taken over, **Release the Fat Cow**, and fixes to the AI cow's return and landing. No new setting, catalogue unchanged.

### [FIX-BRIEFING-MAGNETIC-HEADINGS](FIX-BRIEFING-MAGNETIC-HEADINGS/PRD.md) · ✅

The briefing's headings and bullseye bearings were taken on the DCS grid and printed with no unit, 6.9 degrees off the cockpit on the Golan: they are now magnetic, `°M`, the World Magnetic Model's declination at the mission's date taken off the true bearing, as DCS and the F-16C and F/A-18C read them; the carrier's course, the recon photos and `set_route` too, and the ranges on the ellipsoid. Two tickets, one PR. Shipped in #1219.

### [FIX-BRIEFING-PARITY-MARTEAU-2](FIX-BRIEFING-PARITY-MARTEAU-2/PRD.md) · ✅

What the retest of #1210 still found in "Marteau du Golan"'s briefing (2026-10-28): bases, flight levels and one helicopter route on the overview, a combat map the key does not cover, frequency headings of their own, a prerequisite objective, the kneeboard flight card as a table, levels and support in the ATO. One PR. Shipped in #1212.

### [FEAT-OBJECTIVE-MISSION-V2](FEAT-OBJECTIVE-MISSION-V2/PRD.md) · ✅

What "Marteau du Golan" did by hand, in the tools (2026-10-28): the objective prompt (prose validated first, a Mission Maker sheet, ways out, code words), a combat-area map, kneeboard maps turned attack axis up, recon photos, seven tool fixes, a poster, a calendar banner and a Discord post. Twelve tickets, one PR; the in-game half is another lot. Shipped in #1208.

### [FIX-DYNSLOT-RADIO-RANGE](FIX-DYNSLOT-RADIO-RANGE/PRD.md) · ✅

DCS 2.9.31 moved the La-7 to a 3.7–6.06 MHz HF radio, and its two dynamic-slot templates at 121.5 MHz stop the Mission Editor from saving a built mission (2026-10-29). Radio specs bumped to that DCS build, the radio-less La-7 kept in them, the templates retuned, and a catalogue test (#1217).

### [REFACTOR-BRIDGE-ONLY](REFACTOR-BRIDGE-ONLY/PRD.md) · ✅

One way to talk to a running DCS (David, 2026-10-28): `recon-*`, `mission-check`, `smoke-test` and the airfield frequency capture move from the DCS Fiddle hook to the VEAF bridge, and the hook goes. One PR, before release 6.34.0.

### [FIX-FATCOW-CTLD-FARPS](FIX-FATCOW-CTLD-FARPS/PRD.md) · ✅

GRASS refilled CTLD's Fat Cow FARPs on every birth, making a cow unlimited, and CSAR gave the CH-47F no menu: GRASS now skips `CTLD_` FARPs and `csar.aircraftType` lists `CH-47Fbl1` (24). From the Fat Cow server run of 2026-10-26 (VEAF/CTLD#273). Demo step in VEAF/VEAF-Demo-Mission-v6#12 (2026-10-29).

## 🚫 Won't fix

### [FEAT-SIGNED-RELEASES](FEAT-SIGNED-RELEASES/PRD.md) · 🚫

Signing the Windows executables through SignPath Foundation: the license audit ([audit.md](FEAT-SIGNED-RELEASES/audit.md)) found every code component OSI-licensed, but DCS-derived reference data under no license inside `veaf-tools.exe`, which SignPath may refuse with no appeal; dropped by David on 2026-11-13. The audit also lists compliance gaps worth knowing (third-party notices not shipped, WMM files copied from DCS, VEAF-dcs-bridge without a license).
