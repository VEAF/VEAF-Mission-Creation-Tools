# Foothold 6.5.3 — functional and technical inventory

Written 2026-11-15 for [`FEAT-DYNAMIC-CAMPAIGN`](PRD.md), whose ticket 07 measures our own engine against Foothold.
This page is the entry point: the version analysed, the catalogue of features with what VEAF already has and what each would cost, and a proposed order.
The mechanisms themselves are in eight detailed notes under [`foothold-analysis/`](foothold-analysis/), every claim cited `file:line` in the analysed version.
The purpose is that a later session works from these pages without reading the upstream code again.
Nothing here is a decision: which features to integrate is David's call.

## 1. Version analysed

| | |
|---|---|
| Upstream | [`leka1986/Lekas-Foothold`](https://github.com/leka1986/Lekas-Foothold) |
| Analysed | tag `v6.5.3`, commit `27d8cf4a6e579f3c60a5f715bbdf06782fb1d351`, 2026-11-13 (latest release on 2026-11-15) |
| After the tag | 6 commits on `main` up to 2026-11-14, all on the Config Manager (2.5.8 to 2.6.0) and the saved-games folder; not analysed |
| Missions in the tag | still named 6.5.2 (`Missions/Foothold_CA_6.5.2_…miz`), with 6.5.3 scripts inside |
| What VEAF runs | 5.3.5, refreshed 2026-10-19 in the ten `VEAF-Foothold-*` repositories (`chore: update to Foothold 5.3.5`) |
| Engine size | `zoneCommanderv2.lua`: 102 728 lines in our 5.3.5, 115 262 in 6.5.3 |
| Local clone | `D:\dev\_dcs-other\Lekas-Foothold` (remotes `origin` = upstream, `fork` = `VEAF/Lekas-Foothold`); its `main` is at a 2025-12-29 commit, two commits ahead of nothing upstream — left untouched |

Sixteen releases separate 5.3.5 from 6.5.3.
What they added, from the release notes: PvP on Caucasus, Syria and Persian Gulf with a Red shop, Red CTLD and Red CSAR (5.4.0, 5.4.1); escort altitude choices and configurable AWACS, tanker and carrier radios (5.4.3); `NoAIBlueCapture` (5.4.4); the Director's learning and reassessment rework (5.4.5, 6.4.6); night-operation bonus and night air-defence settings, `MaxRedGroundGroupsPerZone` (6.4.6); staged autosave, queued wake-up of sleeping zones and queued menu refreshes (6.4.8 to 6.5.0); idle zones, ground-patrol switch, Blue ground-defence cap (6.5.1); PvE defeat restart, warehouse weapon locations, CAP auto-buy, SAM reveal (6.5.2); South Atlantic map (6.5.3).

### How to get the source again

The working copy used for this analysis was a temporary extract.
To rebuild it: `git -C D:\dev\_dcs-other\Lekas-Foothold fetch --tags origin`, then `git archive v6.5.3 | tar -x -C <empty folder>`.
A function index (one `line:signature` per definition) is rebuilt with `grep -nE '^\s*(local\s+)?function\s+[A-Za-z_][A-Za-z0-9_.:]*\s*\(' "Common Scripts/zoneCommanderv2.lua"`; it has about 3 100 entries.

### What is in the release

| File | Lines | Role |
|---|---|---|
| `Common Scripts/zoneCommanderv2.lua` | 115 262 | the engine, shared by every map |
| `Common Scripts/Moose_2026-10-11.lua` | 132 407 | bundled Moose, **modified for Foothold** (its CTLD calls Foothold functions, note 07 §1) |
| `Common Scripts/Foothold_Localization.lua` | 38 857 | every player-facing string, 10 locales |
| `Common Scripts/AIEN.lua` | 16 093 | ground AI reactions (Chromium18), customised |
| `Setup files/<map>.lua` | 5 000 to 10 000 | the campaign data of one map, hand-written |
| `Common Scripts/Foothold CTLD.lua`, `Foothold_CTLD_Red.lua` | 9 441, 2 417 | logistics on Moose CTLD |
| `Common Scripts/Splash_Damage_3.4.1_leka.lua` | 4 932 | splash damage, customised |
| `Common Scripts/Foothold Config.lua` | 3 530 | 202 server settings |
| `Common Scripts/WelcomeMessage.lua`, `EWRS.lua`, `Zeus.lua` | 2 941, 1 745, 105 | callsigns/ATIS/escort, radar picture, game-master markers |
| `zoneCommander.lua`, `zeus_Full_v2.1.lua`, `WelcomeMessagev2.lua` | — | present in the repository, **not loaded** by the missions |

## 2. The detailed notes

| Note | Covers | Lines |
|---|---|---|
| [`01-zones-capture-map.md`](foothold-analysis/01-zones-capture-map.md) | zone model, garrisons, losses, neutral state, capture channels, pending capture, advance capture, dormancy, connection graph, frontline, everything drawn on the F10 map, win and lose | 18 features |
| [`02-persistence-lifecycle-plumbing.md`](foothold-analysis/02-persistence-lifecycle-plumbing.md) | save files and their fields, staged autosave, load and re-apply, restart and reset, era and PvE/PvP switches, player identity, slot control, events, loops and timers, F10 menu queues, localisation, the Moose census, script load order | 21 features |
| [`03-ai-groups-sorties.md`](foothold-analysis/03-ai-groups-sorties.md) | `GroupCommander` state machines (air and surface), spawn eligibility and caps, CAP and strike tasking, AI supply helicopters, AIEN, MANTIS, bombers, Hunter, throttles | 15 features |
| [`04-director.md`](foothold-analysis/04-director.md) | the planner that authorises every AI launch: capabilities, cycle, target scoring, packages, posture, phases and gates, learning, CAP slots, ground release, events, difficulty scaling | 19 features |
| [`05-economy-shop-ranks-missions.md`](foothold-analysis/05-economy-shop-ranks-missions.md) | coalition and personal credits, kill attribution, the whole shop catalogue, ranks, statistics, career, joint missions, player missions, the F10 tree | 13 features |
| [`06-player-support-tools.md`](foothold-analysis/06-player-support-tools.md) | JTAC drones, player laser designator, CSAR, zone intel, tankers, AWACS, CAP control, every map-marker command, carrier control, welcome/callsigns/ATIS, escort, EWRS, Zeus, splash damage | 19 features |
| [`07-ctld-warehouse-logistics.md`](foothold-analysis/07-ctld-warehouse-logistics.md) | what Foothold adds to Moose CTLD, cargo catalogue, zone supplies, warehouse cargo, FARP kits, C-130J, spy and demolition teams, warehouse stocks, legacy logistics, Red CTLD, the list of Moose CTLD features relied on | 22 features |
| [`08-mission-maker-side.md`](foothold-analysis/08-mission-maker-side.md) | the manual (63 pages), the 202 Config settings, the structure of a setup file with excerpts, the `.miz` conventions measured, the Config Manager, server operation, the authoring cost of one map | 10 headings |

Each note opens with its feature table and ends with "Seen outside this theme".
Inside a note, "(estimation)" and "not read" mark what was not read in the code; section 8 below lists what remains so.

## 3. Findings that change what the PRD assumed

The PRD of this lot was written from Foothold 4.7.0 (read 2026-10-02).
Five of its statements no longer hold on 6.5.3.

1. **There is a licence now.**
   The PRD rules a fork out because upstream had `license: null`.
   6.5.3 ships `LICENSE` (GPL-3.0-only for Leka's code), with Apache-2.0 kept on the original zoneCommander parts, GPL-3 for Moose and AIEN, MIT for Splash Damage and EWRS (`THIRD_PARTY_NOTICES.md`).
   The second reason against a fork stands: the engine grew by 12 500 lines in four weeks.
   A consequence to weigh: code copied or closely adapted from Foothold into a VEAF module would bring GPL-3.0 terms with it; ideas and mechanisms do not.
2. **Moose is a toolbox in the engine, not its skeleton.**
   The census (note 02, "Moose dependency census") counts, in the engine, 392 raw `missionCommands` calls, 574 raw `outText`, 162 raw `timer.scheduleFunction`, 3 `world.addEventHandler`, against Moose used mostly for unit conversions (`UTILS`, 384), positions (`COORDINATE`, 182) and timers (`SCHEDULER`, 97).
   The PRD's "OPS layer (`AUFTRAG`/`FLIGHTGROUP`, one state machine per AI flight)" is gone from regular sorties: OPS is used at six side sites only (Hunter, battleship, naval artillery, V1), and every supply, CAP, CAS, SEAD, runway and convoy sortie is tasked with raw DCS tasks (note 03 §7).
   The Moose parts with real weight are `SPAWN` with `AIRBASE` (parking-spot spawn of AI aircraft), `STORAGE` (warehouses), `MANTIS` (air defence), `CTLD`, and the template registry `_DATABASE.Templates.Groups`.
   So "Moose costs the frames" is less likely than the PRD supposed; it is still unmeasured, and ticket 07 is still the way to know.
3. **Foothold already does what our performance section plans.**
   Dormant zones exist (distance suspension, idle suspension, wake-up by players, by the front or by an AI mission, respawn one group per 0.1 s, losses kept — note 01 §9).
   The zone update is one staggered wave (one zone per 0.1 s inside a 10 s period), spawn decisions go through a queue with a budget, the save is staged, menu refreshes are queued (note 02, "Engine main loops").
   The one thing we planned that Foothold does not do is use events for losses: it polls every garrison (note 01 §4) and every AI group state (note 03 §16).
4. **Sorties are no longer declared one by one as live objects.**
   The Caucasus setup declares 402 `DirectorCapability` records against 7 `GroupCommander:new`; a capability is passive data, instantiated when the Director authorises it, and a "DynamicHybrid" filler generates more from distance rules (notes 04 §2, 08 §3).
   This is close to our "sorties derived from the graph", arrived at from the other side.
5. **The authoring cost was under-counted.**
   Measured on Caucasus (note 08, "Authoring cost of one map"): 10 014 setup lines, 89 zones, 409 sortie declarations, 135 visible and 14 hidden connections, 1 331 trigger zones (717 of them spawn sub-zones), 508 late-activated template groups, 338 statics.
   62 to 74 % of the lines of the other modern setup files are identical to Caucasus lines: most of a setup file is code copied from map to map.

One finding concerns our servers today rather than the design; see section 9.

## 4. How Foothold works, in one page

A campaign is a graph of **zones** (89 on Caucasus), each with an owner (0 neutral, 1 red, 2 blue), a facility type (airbase, FARP, carrier, ground, logistics) and a **garrison**: an ordered list of template groups per owner, re-drawn at random per campaign from size profiles (note 01 §1–2).
A zone never changes side directly.
Its garrison is destroyed slot by slot; when the last slot is gone the zone turns **neutral** (note 01 §5).
A neutral zone is captured by bringing something into it — an AI supply helicopter or convoy, CTLD troops, a supply crate, a Hercules drop — which starts a **pending capture** of `ZoneCaptureBuildSeconds` (120 s) anchored on a physical object that the enemy can destroy (note 01 §6–7).
On capture the first garrison slot spawns; each later supply delivery adds or repairs one slot (note 01 §4).
An airbase zone switches the DCS airbase coalition, which is what opens or closes its dynamic-spawn slots (notes 01 §6, 02 "Player spawn handling").

The AI is two layers.
`GroupCommander` is the execution state machine of one sortie (hangar → preparing → takeoff → in air → landed), entirely polled (note 03 §2).
The `Director`, one per side, decides: every 30 s it scores Blue zones, picks one by weighted random, builds a package (CAP, SEAD, CAS, runway strike, surface, feint, reserve), authorises launches through gates, reassesses every 90 s, and keeps decaying memories of what worked (note 04 §3–8).
Routine CAP, ground convoy release and reactions to the players' captures are separate Director functions (note 04 §9–12).
Air defence is a MANTIS network per side (note 03 §11); ground groups react to fire through AIEN (note 03 §10).

Players earn **personal credits** for kills and deliveries, which become coalition credits and rank only when they **land in a friendly zone**; dying loses them, ejecting keeps 25 % (note 05 §3).
Coalition credits buy shop items — support flights, JTAC drones, intel, captures, zone upgrades, repairs — from an F10 menu or a `buy:<id>` map marker (note 05 §4–5).
A 20-step **rank** ladder gates shop and CTLD items (note 05 §7).
Player **missions** are a polled list of closures with rewards, shown in a menu and on the map (note 05 §11).

Logistics is Moose CTLD with Foothold on top: prices and ranks on cargo, zones that follow ownership, supply crates tracked physically, weapon stock moved between airbase **warehouses**, player-built FARPs (note 07).

State is saved every 60 s to Lua files under `Saved Games\<instance>\Missions\Saves` (eight files per map, era and mode — note 02 "Files written"), which needs `io` and `lfs` in `MissionScripting.lua`.
A win or a defeat wipes the save and sets flag 181, which a mission trigger turns into `a_end_mission`; the server reloads the mission (notes 01 §18, 02 "Campaign lifecycle").

## 5. What VEAF already has

Read from the modules' headers and by grep on `src/scripts/` (2026-11-15, `origin/develop` at `cfe3dcf8`); not a line-by-line read, except `veafCampaign.lua`'s function list.

| VEAF brick | What it gives against Foothold |
|---|---|
| `veafCampaign.lua` (1 559 lines, `FEAT-MULTI-MISSION-CAMPAIGN`, 🧑 waiting for its in-game check) | zones by owner with a neutral state, garrisons drawn once with `veafCasMission`'s generators and recorded, losses by `S_EVENT_DEAD`, capture of a neutral zone by ground presence held for a time (including CTLD crates), airbase coalition switch, zones and connections on the F10 map, a situation radio menu, assault convoys by rule and on player order paid from a ground reserve, the state file written through `io`/`lfs`, destroyed scenery, SAM missiles left, work counters |
| `veafCombatZone.lua` | editor-defined zones activated and deactivated on demand with their groups: the nearest thing to dormancy |
| `veafQraCore.lua`, `veafAirWaves.lua`, `veafReactiveZone.lua`, `veafOpposition.lua` | reactive AI flights around a zone, waves, and an opposition level that follows the number of players |
| `veafSkynetIadsHelper.lua` + Skynet-IADS | the integrated air defence, in place of MANTIS |
| `veafGroundAI.lua` + vendored `AIEN.lua` | ground group orders and reactions to fire |
| VEAF CTLD 2 (`src/scripts/community/CTLD.lua`) | troops, crates, FOB, with an `EventDispatcher` (`OnTroopsDeployed`, `OnCrateUnpacked`…); airfield logistic zones (`FEAT-CTLD-AIRBASE-LOGISTICS`, done); Fat Cow |
| `community/CSAR.lua` | pilot rescue |
| `veafCarrierOperations.lua`, `veafAssets.lua`, `veafMove.lua` | carrier operations by radio menu, tanker and AWACS information, tanker repositioning by marker |
| `veafWeather.lua`, `veafAirbases.lua`, `veafAirfieldFrequencies.lua` | ATIS and METAR, runway data, airfield frequencies |
| `veafSpawn*.lua`, `veafShortcuts.lua`, `veafSecurity.lua` | marker commands for a game master (spawn, destroy, smoke, flares, illumination) behind security tiers — Foothold's Zeus has no identity check |
| `veafRadio.lua`, `veafScheduler.lua`, `veafEventHandler.lua`, `veafI18n.lua` | paginated F10 menus that survive DCS's id recycling, native-timer scheduling, one event dispatcher, a FR/EN catalogue |
| `veafCombatLog.lua` | every shot, hit and kill with shooter and player: the raw material of a reward or statistics system |

Nothing in `src/scripts/veaf/` matches these words: `credit` as an economy, `shop`, a rank ladder, `splash`, `force_player_slot`, `dormant` (grep, 0 relevant hits).

## 6. Catalogue and synthesis table

Effort is what it would take to reproduce the feature on VEAF bricks, without Moose: **low** (days, on an existing brick), **medium** (a ticket or two, new code on known ground), **high** (a lot of its own, or dependent on unknowns in DCS).
"Ref" points to the note and section holding the mechanism.

### 6.1 Zones, capture and the map

| Feature | What the player sees | Mechanism | VEAF equivalent | Effort | Ref |
|---|---|---|---|---|---|
| Zone model with neutral state | zones coloured red, blue, grey | object per zone bound to a same-named trigger zone; owner 0/1/2; airbase auto-capture switched off | `veafCampaign` zones, declared in `campaign.yaml` | done | 01 §1, §5 |
| Random garrisons by size profile | a different defence each campaign | per-size counts by category (SAM, SHORAD, AAA, ground, armour, artillery) drawn from a template pool with a campaign seed | `veafCampaign.composeGarrison` over `veafCasMission` generators | done, by another route | 01 §2 |
| Spawn sub-zones | groups spread inside a zone, SAMs on prepared spots | 717 hand-placed sub-zones (`<Zone>-n`, `-SAM-`, `-SHORAD-`), random valid point on land | `veaf.findSpawnPoint`, `veafCampaign.placeGarrisonGroup`: no hand-placed sub-zone | done, by another route | 01 §2 |
| Loss detection | "zone lost a group" | **polled**: every built slot scanned every 10 to 60 s | `veafCampaign.onUnitDead` (event) | done | 01 §4 |
| Upgrade and repair one slot per delivery | "zone upgraded 3/8", repaired groups reappear whole | `upgrade()` repairs the first damaged group by respawn, else spawns the next slot | reinforcement only between missions (campaign rules) | medium: a live reinforcement rule and its trigger | 01 §4 |
| Combat effectiveness and surrender | weakened red zones change colour; the last weak units may surrender | states full / reduced / static from unit attributes; surrender roll 40 to 80 % by tier | none | low | 01 §4 |
| Zone income | credits per tick | owner paid `income` at each zone update | none (no economy) | low once an economy exists | 01 §4 |
| Disabled zones and critical objects | "zone destroyed", drawn black | zone deactivated for good when its critical statics are dead | destroyed scenery is recorded; no "destroyed zone" state | low | 01 §5 |
| Capture channels | land a helicopter, drop troops or a crate, drive a convoy in | every channel calls `startPendingCapture` with a participant | `veafCampaign.holdsGround`: one detection for any ground presence | done | 01 §6 |
| Pending capture | "Capturing X…", fill colour blending in 4 steps, enemy warned | 120 s timer tied to a living participant inside the zone; cancels if all are lost | hold time on a neutral zone exists | low: the colour blend and the warning | 01 §7 |
| Advance capture | buy a supply that holds near a worn zone and captures when it falls | eligibility threshold on built ratio; held supply released on neutralisation | none | medium, needs AI supply sorties first | 01 §8 |
| Zone dormancy | nothing visible; units appear as players approach | suspend destroys the garrison keeping per-slot survivors; resume respawns one group per 0.1 s then trims to the survivors; a dozen "hold" reasons | none; `veafCombatZone` activation is the closest | **high**: planned in ticket 02; the hold rules and loss-preserving respawn are the work | 01 §9 |
| Connection graph | lines or arrows between zones | hand-declared undirected edges, derived "connected to blue" tables, a zone-distance matrix | `veafCampaign` connections and `neighbours` | done | 01 §10 |
| Frontline computation | not drawn; drives CAP stations and AWACS | nearest-enemy segments and signed distance to front per zone | none | medium | 01 §11 |
| Zone shapes and labels on F10 | coloured circle or quad, a text box per coalition with garrison state | fixed mark ids updated in place with `setMarkup*` | `veafCampaign` drawing | done; label content is low | 01 §12 |
| Connection lines and supply arrows | coloured by ownership | `lineToAll` / `arrowToAll` between zone edges | `veafCampaign.drawConnections` | done | 01 §13 |
| Territory overlay | Voronoi cells tinted by owner with frontier borders | plain-Lua geometry, incremental redraw, many map marks | none | medium | 01 §14 |
| Hidden and pop-up zones, zone triggers | zones that appear during the campaign | name-based hidden flag; callbacks on captured / lost / destroyed | none | low | 01 §15 |
| Zone status menu | per-zone list by side, status text with health and coordinates | per-group menu rebuilt through a queue | `veafCampaign.buildRadioMenu`, `situationText` | done | 01 §16 |
| Win and lose | "Enemy has been defeated", restart | test on zone events; wipe the save; flag 181 → `a_end_mission` | none in `veafCampaign` (episodic campaign ends between missions) | low: ticket 05 | 01 §18 |

### 6.2 Persistence, lifecycle and plumbing

| Feature | What the player sees | Mechanism | VEAF equivalent | Effort | Ref |
|---|---|---|---|---|---|
| Campaign save | progress survives a restart | Lua table serialised to a file every 60 s; zones, garrison survivors, credits, shop stock, live AI groups, Director memory | `veafCampaign.writeState` (zones, garrisons, losses, stocks, scenery) | low: cadence and the extra fields | 02 "Campaign save" |
| Staged autosave | no stutter at save time | 8 zones per 0.1 s collected, then serialised in a coroutine | single write | low | 02 "Staged autosave" |
| Restore of live AI flights and convoys | flights reappear in the air after a restart | saved position and state per live group, re-spawned in the air | none | medium, with AI sorties | 02 "Campaign load", 03 §16 |
| Warehouse persistence | weapon stocks survive | CSV, one airbase per second | `veafCampaign` records stocks | low | 02 "Warehouse persistence" |
| Player file | credits, rank, career and language follow the player across maps | keyed by UCID on disk, by name at run time | none | medium: the first per-player persistent data in VEAF | 02 "Rank and player-statistics file" |
| Reset and restart | admin "end mission and reset" | empty save written, flag 181, the server reloads | none | low | 02 "Campaign lifecycle" |
| Era and PvE/PvP switches | Modern, Cold War, Vietnam; PvP variants | two Config globals select template sets and the save name | `mission.era` filters at build; build variants | low for era; PvP is a design of its own | 02 "Era and mode switches" |
| Slot control | slots only where your side holds the base | airbase coalition; a user flag per client group; rejection at `S_EVENT_BIRTH` by `net.force_player_slot` | `veafCampaign.setAirbaseCoalition`; no rejection at birth | low | 02 "Player spawn handling" |
| Friendly fire | message and rank penalty | on `S_EVENT_KILL` between friends | none | low | 02 "Friendly fire" |
| Marker commands for admins | none for players | plain words typed in a marker, no admin list, aliases configurable | `veafSecurity` tiers, `veafRemote` | done, and stricter | 02 "Admin and player map-marker commands" |
| Main loops, queues, watchdog | an on-screen "engine crash" warning if the loop dies | 10 s wave at 0.1 s per zone; evaluation queue with a budget; watchdog on the last completed update | `veafScheduler`; `veafCampaign.beat` | low: the patterns are known | 02 "Engine main loops" |
| F10 menu queues | menus refresh without a hitch | per-group handles, debounced refresh, one group per tick, "unchanged" check | `veafRadio` | done for the tree; per-group budgets are low | 02 "F10 radio menu management" |
| Localisation | each player picks one of 10 languages | key lookup with EN fallback, scopes server / player / group | `veafI18n` (FR, EN, one language per mission) | medium for per-player language | 02 "Message output and localisation" |

### 6.3 AI groups and sorties

| Feature | What the player sees | Mechanism | VEAF equivalent | Effort | Ref |
|---|---|---|---|---|---|
| Air sortie state machine | AI flights start from parking, fly, land, despawn | polled FSM per sortie; parking spawn; raw DCS tasks | `veafQraCore` / `veafAirWaves` state machines for defensive flights; no generic sortie | **high**: ticket 04 | 03 §2 |
| Parking-spot spawn | aircraft appear on stands | Moose `SPAWN` + `AIRBASE` free-spot tables write `parking` / `parking_id` per unit | `veafSpawnAircraft`, `veafAircraftSpawn` spawn aircraft; parking data per terrain exists in the tools | medium | 03 §16 |
| Spawn eligibility and role caps | fewer enemy flights with fewer players | one gate; caps on CAP, CAS, SEAD, runway by player count and difficulty | `veafOpposition` level | medium | 03 §3 |
| CAP behaviour | patrols that engage, go home winchester | racetrack with engage-en-route, RTB rules, SAM avoidance | QRA and air waves | medium | 03 §4 |
| Strike tasking (CAS, SEAD, runway, anti-ship) | enemy strikes on blue zones | raw task tables per role | `veafCombatMission` spawns enemy flights; no zone-targeted strike | medium each | 03 §5 |
| Surface sorties | convoys on roads, artillery, ships | road routes between zones, arrival → capture or delivery | `veafCampaign.sendConvoy`, `absorbConvoy` | done for assault convoys; supply convoys low | 03 §6 |
| AI supply helicopters | helicopters landing in zones, some with a sling load | landing spots (109 zones on Caucasus), stall recovery | none; two DCS traps on scripted helicopter landings are recorded in `dcs-runtime-traps.md` | **high**: landing a scripted helicopter on a point is not reliable in DCS | 03 §9 |
| Garrison roaming and AIEN | ground groups patrol, dismount, react to fire | name-prefix roaming between sub-zones; AIEN reactions | `veafGroundAI`, vendored AIEN | low | 03 §10 |
| Air defence network | SAMs that switch on and off, SAMs hidden on the MFD until seen | MANTIS per side; hide/reveal flag; night reaction time, low-level radar blur | Skynet through `veafSkynetIadsHelper` | low for the network; the night and reveal rules are low to medium | 03 §11 |
| Strategic bomber and interceptors | a bomber raid with escort; interceptors rolled against it | air-spawned raid, monitor, menus | none | medium | 03 §12 |
| Hunter | two fighters sent after a player on a kill streak | Moose OPS intercept | QRA scaling is the nearest | low to medium | 03 §8, 06 §17 |
| Throttles and cleanup | — | staggered updates, dormant FSM, spawn queue, wreck cleanup | caps planned in the PRD | medium | 03 §15 |

### 6.4 The Director

| Feature | What the player sees | Mechanism | VEAF equivalent | Effort | Ref |
|---|---|---|---|---|---|
| Capability catalogue | — | passive records: origin, target, role, templates, condition | "sorties derived from the graph" (PRD) | medium | 04 §2 |
| Planning cycle and operations | attacks that come as packages, with pauses | 30 s tick; states waiting / recovery / shaping / assault / exploit / surge | none; in `FEAT-MULTI-MISSION-CAMPAIGN` Claude plays the enemy between missions | **high** | 04 §3 |
| Target scoring | the enemy goes for weak or valuable zones | additive score, weighted-random pick | `veafCampaign.planAssaults` (rule: every neutral neighbour) | medium for a simple score | 04 §4 |
| Campaign objective | a consistent enemy push across a region | named strategy, areas declared per map, "strategic shadow" | none | high | 04 §5 |
| Package formation, feint, reserve | CAP + SEAD + strikers arriving together | doctrine → weighted role draw; conditional reserve | none | high | 04 §6 |
| Phases, gates, reassessment, learning | SEAD before CAS; attacks called off when they fail | phase machine, 90 s reassessment, decayed outcome counters saved as remaining time | none | high | 04 §8 |
| Routine CAP slots and scramble | enemy CAP where players fly | slot abstraction keeps the count stable | QRA, air waves | medium | 04 §9 |
| Ground release | a convoy or artillery group every so often | probabilistic release every 90 s under player-scaled limits | `veafCampaign.launchDueAssaults` | low | 04 §10 |
| Reactions to captures | CAS diverted onto a zone blue just took | reaction operations on capture and pressure | counter-attack convoy after a delay | medium | 04 §12 |
| Difficulty and player scaling | harder with more players, eases after losses | stage tables and difficulty profiles feed every limit | `veafOpposition` | low to medium | 04 §15 |
| Random events | a strike mission, a special event every 15 to 25 min | `EventCommander`; 17 events on Caucasus | none | low per event, content is the cost | 04 §16 |
| Blue AI in PvE | AI blue flights supporting the players' attack | support of the players' mission, not a plan | none | medium | 04 §14 |

`BudgetCommander` is dead code in 6.5.3 (note 04 §13).

### 6.5 Economy, shop, ranks, missions

| Feature | What the player sees | Mechanism | VEAF equivalent | Effort | Ref |
|---|---|---|---|---|---|
| Coalition credits | a shared balance | one account per side | the ground reserve of `veafCampaign` is a budget in units, not credits | low | 05 §1 |
| Personal credits banked on landing | "+50 credits (unclaimed)", cashed when landing in a friendly zone, lost on death | `S_EVENT_KILL` attribution, target class from DCS attributes, landing test 5 s later | `veafCombatLog` records the same events | medium | 05 §3 |
| Flight-time, turnaround, night, refuelling rewards | small bonuses | timers on takeoff and landing; refuelling events | none | low each | 05 §3 |
| Shop | F10 menu by category with zone pickers; `buy:<id>` markers | item registry, per-side shelves with stock and rank, deferred payment | none | medium for the mechanism; each item is its own effect | 05 §2, §4 |
| Shop catalogue | 45 item ids on Caucasus | each item calls an engine function | partial: several effects exist as VEAF commands (smoke, illumination, spawn of CAP or JTAC by marker) | per item, low to high | 05 §5 |
| CAP auto-buy | a destroyed CAP is replaced, paid automatically | authorisation count per purchase | none | low once CAP purchase exists | 05 §6 |
| Ranks | 20 ranks, gating items | thresholds on rank credits, saved per UCID | none | medium, with the player file | 05 §7 |
| Statistics and leaderboards | top lists, per-sortie recap | counters per sortie, session, lifetime | `veafCombatLog` + `veaf-tools mission combat-log` (after the flight) | low for an in-game recap | 05 §8 |
| Career and achievements | lifetime counters with paid milestones | per player and per aircraft | none | medium | 05 §9 |
| Joint missions | parties of up to 4 sharing rewards | invitation and reward split | none | medium | 05 §10 |
| Player missions | a list of available missions with rewards, map marks | polled closures `isActive` / `isCompleted`, 44 tracked on Caucasus | `veafCombatMission`, `veafCombatZone`, `veafCasMission`: on-demand missions without rewards | medium for a task board on existing missions | 05 §11 |

### 6.6 Player support tools

| Feature | What the player sees | Mechanism | VEAF equivalent | Effort | Ref |
|---|---|---|---|---|---|
| JTAC drone | a drone lasing targets of a zone, menu for code, priority, smoke | `Spot.createLaser`, 0.5 s update, target list from the zone's spawned groups | `_spawn jtac` and CTLD JTAC (estimation: not compared feature by feature) | low | 06 §1 |
| 9-line JTAC | talk to a FAC on the radio | native DCS `FAC` task | `veafSpawn` JTAC with frequency | done or low | 06 §2 |
| Player laser designator | scout aircraft lase what is in front of them | cone search by `world.searchObjects`, 10 Hz spot update per player | none | medium | 06 §3 |
| CSAR and enemy pilots | downed pilots with beacon and marker; capture enemy pilots | Foothold's own code inside `LogisticCommander`, **not** Moose CSAR | `community/CSAR.lua` | low to wire rewards; enemy-pilot capture medium | 06 §4 |
| Zone intel | a purchased 60-min report and markers per group | reads the zone's own spawn list ("omniscient"), snapshot and diff | `FEAT-CAMPAIGN-INTEL-DELAY` (briefing side) | medium | 06 §5 |
| Tankers and AWACS on demand | spawn a tanker, move its racetrack by menu or two markers | air spawn, TACAN, racetrack task | `veafMove` tanker flight plan by marker, `veafAssets` | low | 06 §6–7 |
| AWACS following the front | AWACS station moves after each capture | station computed from the frontline | none | low once a frontline exists | 06 §7 |
| CAP control | move a purchased CAP with `caphere1` / `caphere2` | marker pair → racetrack | none for purchased flights | low | 06 §8 |
| Carrier control | "sail to area" menu; Tarawa by marker; wind over deck | looped waypoint route, speed recalculated for wind, `ASTAR` sea routing | `veafCarrierOperations` | low: sailing to a named area | 06 §10 |
| Callsigns, IFF, ATIS, closest airfield | a callsign and IFF code at spawn; ATIS on request | allocation keyed on group-name patterns; runway in use from wind | `veafWeather` ATIS, `veafAirbases`; no callsign allocation | low | 06 §11 |
| Escort for players | a free two-ship escort with altitude and orbit commands | native `Escort` task, generation counters | `FEAT-AWACS-ESCORT-COMMANDS` lot (status not read) | medium | 06 §12 |
| EWRS | BRA picture and bogey dope, per-player settings | `getDetectedTargets(RADAR)` on friendly radars | none | medium | 06 §13 |
| Zeus | `-create`, `-destroy`, `-explode`, `-smoke`, `-illuminate` markers | no identity check | `veafSpawn`, `veafShortcuts` behind `veafSecurity` | done | 06 §14 |
| Smoke, flare, illumination on targets | purchased marking of 3 targets | raw `trigger.action` calls | `veafCombatZone` and `veafSpawnEffects` | done | 06 §15 |
| Splash damage | area kills credited to the player | third-party script, tuned | none | medium to vendor and maintain; a design choice | 06 §18 |

### 6.7 CTLD and warehouses

| Feature | What the player sees | Mechanism | VEAF equivalent | Effort | Ref |
|---|---|---|---|---|---|
| Cargo catalogue with prices and ranks | CTLD items cost credits and need a rank | veto hooks before load and build | CTLD 2 catalogue, no price | low once credits exist | 07 §2–3 |
| Zones following ownership | pickup zones appear at captured bases | zones activated and deactivated on capture | `FEAT-CTLD-AIRBASE-LOGISTICS` (airfield logistic zones follow the owner) | done | 07 §4 |
| Troops capture or reinforce | drop troops to capture a neutral zone | CTLD event → pending capture | CTLD 2 `OnTroopsDeployed` → `veafCampaign.holdsGround` | done | 07 §7 |
| Zone supplies | carry physical supply crates to upgrade a zone | crates tracked from pickup to delivery every 3 to 6 s | crate presence captures; no "supply upgrades a zone" | medium | 07 §8 |
| Warehouse logistics | finite weapon stocks per airbase, moved by players | DCS warehouse API through Moose `STORAGE`; refills; location policy | `veafCampaign` stocks; `veafQraLogistics` | medium | 07 §9, §17 |
| Player-built FARPs | build a FARP with a warehouse from a kit | invisible FARP static plus functional statics | Fat Cow and `add_farp` (tools); `veafGrass` FARP props | medium | 07 §14 |
| C-130J load, air-drop, auto-build | drop crates that build themselves | dynamic cargo events, hidden helper | Hercules script was withdrawn in 6.18.0; CTLD 2 support not checked (estimation) | medium | 07 §13 |
| SAM built in parts | add launchers to an existing site | merge of groups near a site | none | medium | 07 §11 |
| Spy and demolition teams | AI teams giving intel or blowing up structures | routed infantry with timers | none | medium | 07 §10 |
| Persistence of built units | built units and FARPs survive a restart | Moose CSV plus Foothold CSV | not checked in CTLD 2 (estimation) | medium | 07 §16 |

Note 07 §25 lists the base Moose CTLD features Foothold relies on, for a later comparison with CTLD 2.

### 6.8 The mission-maker side

| Feature | What the mission maker does | VEAF equivalent | Effort | Ref |
|---|---|---|---|---|
| Setup file | writes 5 000 to 10 000 lines of Lua per map | `campaign.yaml` + build generation (PRD) | done in principle | 08 §3 |
| `.miz` conventions | places 1 331 trigger zones and 508 template groups by naming convention | the build generates zones and slots; no template group | done in principle | 08 §4 |
| Config file | 202 settings in 22 sections | `mission.yaml`; for Foothold itself, `config_override:` (ADR 0008) | n/a | 08 §2 |
| Config Manager | a Windows tool edits the config, downloads and updates missions, handles DCSServerBot `.miz.orig` | `veaf-tools`, `Publish-Foothold.ps1` | n/a | 08 §5 |
| Server operation | desanitise `MissionScripting.lua`, saves folder, reset | already true on dcs.veaf.org (`io`, `lfs` open, measured 2026-10-03) | n/a | 08 §6 |

## 7. What is cheap, what is covered, what is dear

**Already covered by VEAF bricks** (the core loop): zones with a neutral state, random garrisons, capture by ground presence with a hold time, airbase coalition, the F10 map with zones and connections, the situation menu, assault convoys, the state file, CTLD troops capturing, logistic zones following the owner, game-master markers, the air-defence network.

**Cheap on those bricks**: win and lose with reset, the pending-capture colour blend and warning, surrender of weak zones, critical objects, a coalition credit account, income per zone, slot rejection at birth, tanker and CAP control by markers, carrier "sail to area", statistics recap, ground release rules, random events as a mechanism.

**Dear**, with the reason:

1. **Zone dormancy** — a dozen reasons to stay awake that must agree, and a respawn that restores exactly the survivors in the same places; it is also the feature that buys the most performance.
2. **Generic AI air sorties** — parking spawn, a state machine per sortie, tasking per role, restore after restart; Foothold spends about 13 500 lines on it (`GroupCommander`).
3. **AI supply helicopters landing in zones** — DCS does not reliably land a scripted helicopter on a point (two traps recorded in `docs/agents/dcs-runtime-traps.md`); Foothold needs 109 hand-placed landing zones and a stall recovery on one map.
4. **The Director** — 25 000 lines; not any single formula but the amount of shared state it reads and the hysteresis around every choice (note 04, "Reproduction notes").
5. **The player economy as a whole** — credits banked on landing, shop, ranks, career: each piece is medium, but together they need per-player persistent data, which VEAF has never had, and a catalogue of effects.
6. **Warehouse logistics** — finite weapon stocks moved by players touch every airbase warehouse and the save.

## 8. What was not read

The eight notes mark their own gaps.
A gap-filling pass on notes 01 to 04 was running when this page was written; see the commit log of `foothold-analysis/` for what it closed.
Known to remain unread or estimated at that time:

- note 05: DEAD, runway-strike and red mass-attack missions; recon completion; the joint-mission invitation flow; achievement tiers; the internals of purchased CAS, SEAD, decoy and bomber flights (only `spawnCapAt` was read in detail);
- note 06: `boardPilot` (credit refund at pick-up); the "CAP Control" menu tree; the intel snapshot/diff builder in detail; Splash Damage analysed by diff against the default version, without line numbers;
- note 07: SAM add-on save (`Foothold CTLD.lua:7847-8095`); managed/PvP warehouse mode (`6507-6634`, `7346-7520`); the Red CTLD tracking loop (`Foothold_CTLD_Red.lua:1895-2216`);
- note 08: setup lines 3886–4240 and 6559–7458; the manual's screenshots (text only was extracted); `MizBatchUpdater.exe` and `MizFileReplacer.exe` (no documentation in the repository); the Config Manager's C# code, on purpose;
- features several notes point at and none details: the zone "regular supply" production and local recovery jobs (`zoneCommanderv2.lua:52059-54689`), the destroyable warehouse building of a zone (`46108-46584`), PvP industry objectives and territory share, train repair on Normandy;
- the other nine maps' setup files were only compared by line similarity with Caucasus;
- nothing was run in DCS: every statement is from reading code, the manual and the mission file.

The VEAF column of section 6 comes from module headers and grep, not from reading each VEAF module; where it matters for a decision, check the module first.

## 9. A security finding on the missions we run today

In Foothold, an F10 map marker whose text starts with `-code:` has the rest of its text compiled with `loadstring` and executed (`zoneCommanderv2.lua:29203-29210` in 6.5.3).
The only condition on the handler is that the marker event carries coalition 1 or 2 (`zoneCommanderv2.lua:28456`); there is no player name, UCID, rank or password check on that branch, and the configurable admin aliases do not cover it.
The same code is in the 5.3.5 our missions run (`VEAF-Foothold-Caucasus/src/scripts/zoneCommanderv2.lua:26331`).
On dcs.veaf.org, `io` and `lfs` are available to missions (measured 2026-10-03, see the PRD), so that Lua can read and write files on the server.
Not tested in game.
`Zeus.lua` (spawn and destroy by marker) has no identity check either (note 06 §14).

## 10. A possible order of integration

A proposal to react to, not a plan; each step is a choice David can drop.

1. **Finish the core loop on what exists** — ticket 05 of this lot (periodic save cadence, win and lose, reset) plus the cheap capture polish (pending-capture colours and warning, critical objects).
   It makes a playable persistent campaign with convoys only, and it is what ticket 07 needs to measure anything.
2. **Dormancy** (ticket 02) — before adding AI, because it sets how many zones a server can carry, and Foothold's rules (note 01 §9) are a tested list of what must keep a zone awake.
3. **A small enemy** — graph-derived capabilities and a simple score for the target (notes 04 §2, §4, §10), ground first, then CAP through the QRA and air-wave bricks.
   The full Director is not needed to get counter-attacks; it can stay out, as the PRD already says.
4. **AI air sorties** (ticket 04) — CAS and SEAD strikes on zones, then supply flights; helicopters landing in zones last, or replaced by convoys and CTLD, given the DCS traps.
5. **An economy, if wanted** — a coalition credit account and income first, then a shop of a few items whose effects VEAF already has (JTAC, smoke and illumination, tanker, CAP), then personal credits banked on landing.
   Ranks, career and achievements need a per-player file and can come last or never.
6. **Logistics depth** — supplies that upgrade a zone through CTLD 2, then warehouse stocks.
7. **Comfort tools** — EWRS, zone intel, carrier "sail to area", callsign allocation, each independent of the rest.

The PRD currently puts shop, economy, ranks, events, the director, the task board, JTAC and on-demand tankers out of scope; steps 5 to 7 would each reopen part of that.
