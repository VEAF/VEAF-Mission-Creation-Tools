# 08 — The mission-maker and server-admin side (Foothold v6.5.3)

Sources, with the short names used in citations: `manual` = `Common Scripts/Foothold Manual v2.7.pdf` (63 pages, cited as `manual p.N`), `Config` = `Common Scripts/Foothold Config.lua`, `ConfigWW2` = `Common Scripts/Foothold Config WW2.lua`, `setup` = `Setup files/MA_Setup_CAv2.lua`, `kola` = `Setup files/kola_setup.lua`, `zc2` = `Common Scripts/zoneCommanderv2.lua`, `mission` = the `mission` file inside `Missions/Foothold_CA_6.5.2_Coldwar-Modern-Vietnam.miz`, `FCM-README` / `FCM-CHANGELOG` / `gui.json` = the three files read under `tools/FootholdConfigManager/`, `README` = the repository `README.md`.
This note is about what a person does to author, configure and run a Foothold map; the engine mechanisms themselves are in the sibling notes `01-zones-capture-map.md` to `07-ctld-warehouse-logistics.md` and are only linked from here.
Counts given as "measured" come from scripts run on the files (regex counts, Lua-table walks), not from reading.

## Feature list

| # | Feature | One-line description | Main location |
|---|---|---|---|
| 1 | The manual | 63-page PDF, 14 chapters; half of it is a reference of the Config Manager screens. | `manual p.1-63` |
| 2 | `Foothold Config.lua` | 202 top-level settings (135 scalars, 67 tables) in 22 sections, annotated with `@gui` comments read by the Config Manager. | `Config:186-3526` |
| 3 | External config override | A copy in `Saved Games\<profile>\Missions\Saves` replaces the one in the `.miz`; missing settings fall back to the internal default with an on-screen warning. | `Config:1-186`, `Config:3517-3526` |
| 4 | `Foothold Config WW2.lua` | Reduced config (104 settings) for Normandy, with its own aircraft lists. | `ConfigWW2:1-999` |
| 5 | Per-map setup file | One Lua file per map (5 000 to 10 000 lines) declaring zones, garrisons, connections, sorties, shop, missions, events. | `setup:1-10014` |
| 6 | `.miz` conventions | Trigger zones, late-activated template groups, statics, dynamic-spawn airbases, warehouses, 4 triggers. | `mission` |
| 7 | Foothold Config Manager | Windows tool: config editor, mission updater/downloader, weather/time profiles, desanitise helper, multi-instance. | `FCM-README`, `FCM-CHANGELOG`, `manual p.4-29` |
| 8 | Server operation | Desanitised `MissionScripting.lua`, save folder, reset, update paths, supported maps/eras, PvE/PvP, localisation. | `README`, `manual p.4-5, 25-29, 56, 61-63` |
| 9 | Admin commands | Marker words, renamable through the Config, with no identity check. | `Config:3468-3514`, `manual p.61-62` |
| 10 | Authoring cost of one map | Measured sizes a map author maintains by hand. | last section |

## 1. The manual (`Foothold Manual v2.7.pdf`)

The PDF has 63 pages and was read in full from a `pdftotext -layout` extraction (the Read tool could not render it on this machine: no `pdftoppm`); the screenshots were therefore not seen, only their captions.
About 25 of the 63 pages (p.5-29) are a field-by-field reference of the Config Manager; the gameplay chapters are short.

### Table of contents (as printed p.2-3)

| Chapter | Title | Pages |
|---|---|---|
| 1 | Introduction and How to Start | 4 |
| 2 | Mission Options and Config (2.1 Config file location, 2.2 Cold War / Modern era, 2.3 Era, aircraft and weapon settings, 2.4 Config Manager and options reference with 18 sub-sections, 2.5 Ranking system, 2.6 RED reactive counterpressure, 2.7 Mods support, 2.8 Updating the Manager and missions) | 5-29 |
| 3 | Warehouse Logistics (3.1 Zone supplies vs warehouse items, 3.2 Loading and unloading cargo, 3.3 C-130J-30 operations, 3.4 Airdrop, 3.5 Supply missions, production and recovery, 3.6 Legacy supplies) | 29-36 |
| 4 | Overview, Spawning and Zones (4.1 F10 map, 4.2 Spawning, 4.3 Zones explained) | 37-38 |
| 5 | Missions (5.1 Main, 5.2 Joint, 5.3 Side, 5.4 Tankers, 5.5 Carrier navigation) | 39-43 |
| 6 | AI Behaviour (6.1 Dynamic AI, 6.2 Hunt, 6.3 Ground AI units, 6.4 AIEN, 6.5 Quiet zones and performance, 6.6 MANTIS, 6.7 EWRS) | 43-44 |
| 7 | Shop (7.1 Radio menu shop, 7.2 JTAC MQ-9, 7.3 AI attack groups, 7.4 CAP control, 7.5 Other categories, 7.6 Map-marker purchases) | 44-49 |
| 8 | CTLD (8.1 Capable units, 8.2 Troops, 8.3 Crates, 8.4 Building and operating a FARP, 8.5 Red CTLD and C-130 airdrops) | 49-52 |
| 9 | CSAR (9.1 Overview, 9.2 Menu, 9.3 Recovering a pilot, 9.4 Capturing enemy pilots) | 52-53 |
| 10 | Private Escort | 54 |
| 11 | Stats and Budget | 55 |
| 12 | PvP Campaigns (12.1 Start, 12.2 Amount of AI support, 12.3 Fight, supply and replace losses, 12.4 Troops and CSAR, 12.5 PvP shop items) | 56-60 |
| 13 | Admin Commands | 61-62 |
| 14 | End Game, Discord and Support | 63 |

### Features documented, with the page

"Sibling" names the note whose feature table already has it; "not in sibling tables" means a grep of notes 01-07 for the feature's keywords found nothing or a passing mention only (note 07 was still short, 171 lines, when this was checked).

| Page | Audience | Feature as the manual states it | Sibling |
|---|---|---|---|
| 4 | player | Credits are earned personally and banked for the whole coalition by landing at a friendly base. | 05 #3 |
| 4 | admin | `MissionScripting.lua` must be desanitised, redone after every DCS update; the Config Manager has a panel that applies and checks it. | 02 (load order/saves); panel: this note §5 |
| 4 | admin | "Disable Tacview" as a performance tip. | not in sibling tables |
| 4 | admin | Mission must be run as a multiplayer server even solo, because of dynamic spawn. | 02 (slot control) |
| 5 | admin | First-run wizard installs `Foothold Config.lua` in `Saved Games\<profile>\Missions\Saves`; never unzip the `.miz` by hand. | 02 (external config) |
| 5-6 | mission maker | Era switch requires the Mission Editor warehouses to be "limited" for aircraft; ships (CVN-72/73/74/59, Tarawa) must be edited one by one, never "copy to all". | not in sibling tables |
| 7 | admin | Era list: Modern, Coldwar, Gulfwar, Vietnam; Active/Inactive aircraft and weapon lists; the mission date cannot be set by script (1989 recommended for Cold War, 1975 for Vietnam). | 02 (era switch) |
| 8 | admin | Presets: up to three named config snapshots per instance and config type. | this note §5 |
| 9 | admin | "Update Config > Update from MIZ" merges a new release's defaults into the existing config, with a timestamped backup (five kept). | this note §5 |
| 10 | admin | Ground units: max groups per zone, RED SAM template check-list, disable MANTIS, static ground targets, hide SAM on MFD, night air-defence reaction time, harder to detect at night. | 01 #2, 03 #11 |
| 10-11 | admin | AI flight template check-lists (12 lists), chance AI attacks helicopters. | 03 #1 |
| 11 | admin | Start Normal (reverse the campaign direction on 4 maps), Start From Incirlik, Remove Southern Syria. | not in sibling tables (Syria-only switches) |
| 11 | admin | Auto Restart, PVE Only, Allow Mods, credit and rank loss on death, Splash Damage, Show Kills, Store Limit, Ranking System, friendly-fire penalty, Invisible A-10, carrier rank requirement, Tarawa marker commands. | 02, 05 #7, 06 #10 |
| 12 | admin | Difficulty profiles (easy/medium/hard per role), AI spawn speed scaling per side, AI skills, Hunter, Director intelligence switches, RED reactive difficulty. | 04 #15, 03 #8 |
| 12 | admin | Stage tables: player threshold to amount, last row not above the counted players wins; ignore lists of aircraft types that do not count as players. | 04 #15 |
| 12-13 | admin | Message of the Day: one server text 10 s after start, then every interval. | 02 (one mention) |
| 13 | admin | Callsign families per aircraft with four LotATC IFF codes each. | 06 #11 |
| 13 | admin | Escort table: per player aircraft type, enabled and which BLUE CAP template escorts it; ground take-off option. | 06 #12 |
| 13-14 | admin | Warehouse Logistics switch, neutral capture time (120 s), supply capacities (normal 1, `[WH]` 6, CTLD FARP 1), supply and repair speed scaling per side, extra RED repair time with few players. | 01 #7 (capture time); production/repair timings: not in sibling tables |
| 14 | admin | Player pickups consume stock, C-130/Chinook native loaders, AI helicopters carry real cargo, AI delivery amount (20), auto-fill (5 every 15 min), disable or radio-pause BLUE AI supplies, take-off warning when empty, strict smart-weapon inventory. | 03 #9 (helicopter cargo); the rest not in sibling tables |
| 14-15 | admin | Shop: advance-capture threshold, prices, rank requirements, reward contribution table (15 keys), refuel reward, AI attack take-off from ground, admin buy, scripted supplies, night bonus. | 05 #5, #13 |
| 15-18 | admin | CTLD: cost switch, red CTLD, engineer capture, max saved FARPs, IRIS merge rule, price/rank table, "Max at spawn" restore limits, per-aircraft capability table. | 07 |
| 18-19 | admin + player | CSAR: allowed aircraft and seats, spawn chance without credits, max at once and at restart, pilot weight, hover distance/height/seconds, guidance distance, hostile infantry chance; self-recovery within 3 NM; credits of the downed pilot go to the rescuer. | 06 #4 |
| 19 | admin | Flight-time reward (per minute after 5 min) and its per-type table. | 05 #3.3 |
| 19-20 | admin | Tanker default speeds; in-game speed menu 220/286/300/320/340 kt saved over restarts. | 06 #6 |
| 20-21 | admin + player | EWRS: 22 defaults; one of them (update interval) is documented as having no effect ("the automatic scheduler is fixed at 20 seconds"), and Friendly Picture has no menu command. | 06 #13 |
| 21-22 | admin | AIEN switches and three cadence timers. | 03 #10 |
| 22 | admin | Aircraft/weapon lists per era; "Forbidden Weapons All Eras" (default: the RN-24 and RN-28 nuclear bombs). | 07 (warehouse) |
| 22-23 | admin | F10 connection display (arrows or lines, dynamic or white); AWACS, tanker and carrier radio tables. | 01 #13, 06 #6-#10 |
| 23 | admin | Settings locked while PvP is on (list of nine groups). | 03 #14, 04 #14 |
| 23-24 | player | Rank ladder: 20 titles from Recruit (0) to General of the Air Force (540 000), stored in `Foothold_Ranks.lua`, never reset, shared by every Foothold mission. | 05 #7 |
| 24 | player | RED reactive counterpressure: soft (faster supply and CAP) and hard (forced attack groups). | 04 #12 |
| 24 | mission maker | Mods: warehouse EQP column filled with 10 000 and copied to all airfields; never tick A/C or neutral bases become dynamic-spawn enabled. | not in sibling tables |
| 25-29 | admin | Mission update flows (files-only, full download, warehouse copy, server-list registration). | this note §5 |
| 29-31 | player | Warehouse logistics: `[WH]` logistics centre with unlimited stock, zone supplies vs warehouse items, low-stock label abbreviations (A/A, A/G, RKT, TNK, G-B, U-B), `[SUP]`/`[Supplies] n/m` labels with a five-cell progress bar, Building/Repairing/Training jobs (two at once), `[WH destroyed]` and a 30-min paid repair. | 07 (partly); label grammar and job timings not in sibling tables |
| 32-34 | player | Loading zone supplies through the DCS rearming "Cargo" panel only, never the CTLD load command; unload inside the zone. | 07 |
| 34-36 | player | C-130J-30: up to 4 zone supplies (4 = capture/upgrade plus 40 of every item), airdrop with parachutes, CTLD cargo auto-builds about 30 s after an airdrop if all parts land within 2 000 m and not on a house. | not in sibling tables (airdrop auto-build) |
| 36 | player | Production and recovery timings: 20 min per supply (10 min in a `[WH]` zone), BLUE repair base 15 min (5 min `[WH]`) + 2 min per unit or 3 min per radar, RED 1 min per unit, cap 20 min. | not in sibling tables |
| 36 | player | Legacy supplies when `WarehouseLogistics = false`: Load/Unload Supplies menu, one supply = one group. | 07 (estimation) |
| 37 | player | Welcome message with ATIS and runway (BRC on carriers), automatic callsign and IFF. | 06 #11 |
| 37-38 | player | Zone label `Name (waypoint) built/total`; hostile zones hide the count; RED zone tint red / light red (no air defence left) / purple (statics only); timed neutral capture with progress in the label. | 01 #4, #7, #12 |
| 39 | player | Main missions: Attack (plus a third "dynamic operation area"), Supply, Capture, CAS, CAP, Recon (10 min of intel), Bomb Runway, SEAD. | 05 #11 |
| 39-40 | player | Joint missions: up to four players, full reward each, 120 s to accept. | 05 #10 |
| 40-41 | player | Side missions: Strike (250-1 000), intercept airstrike / bomber / cargo plane, helicopter escort of a ground convoy (1 000 credits, a FARP at about 70 % of the route, convoy menu: stop/move, smoke, bearing). | 05 #11, 04 #16; the ground-escort convoy has one mention in 05 |
| 42 | player | Tankers: one-time unlock, control menu, racetrack by two markers (`arcohere1/2`, `texacohere1/2`), rank 3 by default. | 06 #6 |
| 43 | player | Carrier navigation: "Sail to <area>" menu, 5-min and 1-min turn warnings, Tarawa marker commands. | 06 #10 |
| 43 | player | Dynamic AI scales with player count; A-10, C-130 and helicopters are not counted; Hunt; patrolling ground units; BLUE defence response (ground counter-attack on breach); quiet zones suspended. | 03, 04 #9, 01 #9 |
| 44 | player | MANTIS network (EWR-driven, backup mode when all EWR are dead, shoot-and-scoot); EWRS settings menu. | 03 #11, 06 #13 |
| 45 | player | Shop categories: AI Attack, Zone Upgrades, JTAC & Intel, Combined Arms, Capture & resources, Other Support. | 05 #4, #5 |
| 45 | player | MQ-9 JTAC, laser 1688, six menu entries. | 06 #1 |
| 46-47 | player | AI attack groups with "Push now / Push on command" for SEAD and Decoy; CAP control menu and `caphere1/2` markers; CAP racetracks avoid known SAM coverage. | 05 #5, 06 #8 |
| 47 | player | Extra upgrade slot: two purchased upgrades per zone, a third after a coalition unlock (Normandy: one, then two). | 05 (shop catalogue) |
| 47 | player | Normandy train-route repair (2 000 credits). | not in sibling tables (one mention in 01 and 04) |
| 48 | player | Deploy FARP: marker outside zones, at least 10 NM from an enemy zone, friendly airbase within 100 NM, delivered by helicopter. | 05, 06 |
| 49 | player | Marker purchases `buy` and `buy:<itemID>`. | 05 #4 |
| 49-50 | player | CTLD special teams: Zone Spy (60 min of intel) and Demolition Team (destroys structures, shares targets between teams). | 07 (one mention each) |
| 50-51 | player | L118 fires on JTAC targets within 7 NM, HIMARS between 9 and 29 NM; SAM add-ons merge within 400 m; pack / pack and load / pack and remove with refund. | 07 |
| 51 | player | FARP and FARP with ZELL (F-100D zero-length launch point), 30 of most weapons and 90 rockets at build. | 07 |
| 52 | player | Red CTLD; PvP-only Pantsir (Blue) and Tor M2 (Red); same-type spacing of 8 NM for CTLD-built Pantsir/Tor/SA-8. | 07 (Pantsir mentioned), spacing rule not in sibling tables |
| 52-53 | player | CSAR menu, hover and landing pickup, enemy-pilot capture with a 50 % chance of 30 min of intel and 20 % chance of revealing Director plans. | 06 #4 |
| 54 | player | Private escort for A-10, C-130J-30, F-15E: two F/A-18 10 000 ft above, 40 NM protection distance, flight-sweep mode. | 06 #12 |
| 55 | player | Stats menu (My Stats, All Stats, Top 5), same-aircraft bonus, budget overview. | 05 #8 |
| 56 | admin | PvP: Caucasus, Syria and Persian Gulf only; starting territory 20/30/40/50 % per side; start-up funds 1 000 per side; separate save names; victory when the opponent owns none of the main victory zones. | 01 #18, 02; starting-territory share not in sibling tables |
| 56-57 | admin | PvP AI: shared fixed-wing AI group limit reduced by own player planes (0 = balance the player counts), automatic supplies switch, escorts switch, separate aircraft lists. | 03 #14, 04 #14 |
| 57 | player | PvP industrial strike objectives (300 per building, cap 1 000, friendly territory within 100 NM) and fixed EWR objectives (50 NM). | not in sibling tables |
| 58 | player | PvP: two AWACS slots per side, replaceable one at a time; destroyable tankers. | 06 #7 |
| 59-60 | admin | PvP shop tables: national upgrade tiers and the list of items not offered in PvP. | 05 #5 |
| 61-62 | admin | Admin commands: 11 renamable marker words, exact and case-sensitive, no name or password check. | 01 #17, 02 (marker commands) |
| 63 | admin | Victory: restart menu or automatic restart; mission and CTLD saves are deleted. | 01 #18, 02 |

### Statements of the manual worth keeping for a re-implementation

The manual says the Config Manager, not the mission, is the supported way to touch configuration: "Do not open the miz as a ZIP or manually move Foothold Config.lua" (`manual p.4`).
It states that `MessageUpdateInterval` of EWRS is exposed but not honoured by the runtime (`manual p.20`), and that "Allow Friendly Picture" has no menu entry (`manual p.20`).
It states that "Warehouse Weapon Caps" is misnamed: membership of the list halves each refill, there is no numeric cap (`manual p.14`).
It states that admin marker commands have no administrator-name or password check and must be protected by choosing secret words (`manual p.62`).
It states that the mission date cannot be changed by script and must be set in the Mission Editor per era (`manual p.7`).
It states that PvP exists on three maps only and that enabling PvP does not convert a running PvE save (`manual p.56`), which matches `Config:3525` forcing `PvP = false` on any other theatre.

## 2. `Foothold Config.lua`

### File structure

Lines 1-186 are loader code marked "do not touch": the file looks for a copy of itself in `lfs.writedir() .. "Missions\\Saves"` and, when found, runs that copy on top of the internal defaults (`Config:1-7`, `Config:153-186`).
Two lists, `FootholdConfigTrackedTableNames` (62 names) and `FootholdConfigTrackedScalarNames` (18 names), name the settings whose absence from the external copy must be reported (`Config:9-92`).
The external chunk is run in an environment whose `__newindex` records every assigned name; a tracked table still equal to the internal default, or a tracked scalar never assigned, is listed in an `env.warning` and in an on-screen message repeated 12 times at 10 s intervals (`Config:94-135`).
A syntax error in the external copy is reported on screen every 30 s as "FOOTHOLD CONFIG ERROR" (`Config:137-146`).
On Normandy the same loader reads `Foothold Config WW2.lua` from the `.miz` (`l10n/DEFAULT/`) and then from the Saves folder (`Config:2-6`, `Config:163-181`).
The last lines force `PvP = false` unless the theatre is Caucasus, Syria or PersianGulf and set `FootholdConfigLoadedOk` (`Config:3525-3526`).
Mechanism details of the override are in `02-persistence-lifecycle-plumbing.md` ("External config override").

Settings carry `-- @gui ...` comment annotations that Lua ignores and the Config Manager reads: `label`, `editor` (`checkboxTable`, `linkedTable`, `fieldTable`, `sideMultiplier`, `bucket`), `validValues`, `visibleWhen` / `disabledWhen` conditions on other settings, `installPolicy` (`mergeRows`, `replaceTable`, `keepTable`) used when merging a new release, `requiredValues` / `requiredSet` linking AI templates to the aircraft types that must stay in the warehouse lists (`Config:246-247`, `Config:552-556`, `Config:1607`, `Config:2393-2417`).
Row comments of the form `-- eras=Modern|Coldwar; label` tag each template row with the eras it belongs to, which the Manager uses to tick rows when the era changes (`Config:249-262`).
So the Lua file is at the same time the runtime configuration and the schema of the editing tool.

### Count

Measured with a script walking top-level assignments from line 186: 135 scalar settings and 67 table settings, 202 in total (the script's raw 139 scalars include `GlobalSettings = GlobalSettings or {}`, `AIEN = AIEN or {}`, `AIEN.config = ...` and `FootholdConfigLoadedOk`, which are not settings).
One of the 67 tables, `WarehouseWeaponLocationAirbases`, is a catalogue of warehouse names per map for the Manager's picker, not a behaviour setting (`Config:1436-1571`).
The tables hold 1 181 active first-level rows and 408 commented-out rows that the Manager shows as "inactive" choices (sum of the per-table counts of the same script).

### Inventory by section

Defaults are the values in the file; "rows" is the number of active entries at the first level of the table.

**Mission options** (`Config:193-299`, 20 settings)

| Setting | Default | Meaning |
|---|---|---|
| `Era` | `"Modern"` | `Modern`, `Coldwar`, `Gulfwar` (Iraq name of Coldwar) or `Vietnam`; selects templates, lists and save name (`Config:196-198`). |
| `PvP` | `false` | Symmetric mode; only Caucasus, Syria, Persian Gulf (`Config:200-202`, `Config:3525`). |
| `FootholdLocale` | `"EN"` | Language of global messages; 10 values EN, DE, FR, ES, RU, PT-BR, TR, IT, zh-CN, zh-TW (`Config:204-220`). |
| `StartNormal` | `true` | `false` starts from the other end of the map and disables the carrier zone; Caucasus, Persian Gulf, Syria, Afghanistan only (`Config:225-227`). |
| `StartFromIncirlik` | `false` | Syria, PvE: start from Incirlik instead of Akrotiri (`Config:229-233`). |
| `RemoveSouthSyria` | `false` | Syria: drop the southern zones, progress kept (`Config:235-240`). |
| `AutoRestart` | `false` | Automatic reset and restart on victory, else a menu (`Config:242-244`). |
| `PVE_Only` | `false` | Players on Red cannot spawn in red zones (`Config:246-251`). |
| `AllowMods` | `false` | Warehouse logistics also restocks mod weapons; Modern only (`Config:253-258`). |
| `CreditLosewhenKilled`, `CreditLosewhenKilledAmount` | `false`, `100` | Coalition credits lost per player death (`Config:260-264`). |
| `RankLoseWhenKilled`, `RankLoseWhenKilledAmount` | `true`, `100` | Rank credits lost per player death (`Config:266-270`). |
| `SplashDamage` | `false` | Load the splash-damage script (`Config:272-273`). |
| `ShowKills` | `false` | Foothold kill messages (`Config:275`). |
| `StoreLimit` | `false` | Earned-credit gates on expensive items (>250 needs 100 earned, >1000 needs 1000, >2000 needs 2000, >3000 needs 3000) (`Config:277-282`). |
| `RankingSystem` | `true` | Ranks and rank gates (`Config:284-285`). |
| `FriendlyFireRankPenalty` | `500` | Rank credits removed per friendly-fire event (`Config:287-288`). |
| `CarrierRankRequirement` | `5` | Rank needed to move the carrier (`Config:290-292`). |
| `AllowTarawaToMoveFreely` | `false` | Tarawa marker commands (`Config:294-299`). |

**PvP settings** (`Config:302-337`, 6 settings)

| Setting | Default | Meaning |
|---|---|---|
| `StartupFunds` | `{[1]=1000,[2]=1000}` | Credits per side at a new or reset PvP round (`Config:304-311`). |
| `PvPStartingTerritoryPercent` | `50` | Share of eligible zones given to each side at start: 20, 30, 40 or 50 (`Config:313-318`). |
| `pvp_supplies` | `true` | Automatic AI supplies for both sides, else only when bought (`Config:320-322`). |
| `PvPEscorts` | `false` | Free two-ship escort offer in PvP (`Config:324-327`). |
| `PvPDisableCombatAI` | `false` | No ordinary automatic combat flights (`Config:329-331`). |
| `PvPCombatAIGroupLimit` | `10` | Automatic fixed-wing combat groups per side minus own player planes; 0 = balance player counts (`Config:333-337`). |

**Frequencies** (`Config:340-397`, 5 tables)

| Setting | Default | Meaning |
|---|---|---|
| `AWACSRadioFrequencies` | 4 rows: Blue 251 / 251.5, Red 252 / 252.5 MHz AM | Red rows apply in PvP only (`Config:343-354`). |
| `TankerRadioSettings` | 5 rows: Blue Arco 260 / TACAN 101Y, Blue Texaco 266 / 102Y, Shell 253 / 103Y, Red Arco 260 / 104Y, Red Texaco 266 / 105Y | Frequency and TACAN per tanker (`Config:356-370`). |
| `CarrierNavigationRadios` | 3 rows: CVN-72 TACAN 72X ATC 272, CVN-74 74X 274, Tarawa 1X 271.5 | (`Config:372-383`). |
| `CarrierNavigationICLS` | CVN-72 = 12, CVN-74 = 14 | ICLS channel, 0 = off (`Config:385-390`). |
| `CarrierNavigationLink4` | CVN-72 = 372, CVN-74 = 374 | Link 4 MHz, 0 = off (`Config:392-397`). |

**F10 Map** (`Config:400-411`, 2 settings): `ConnectionMapStyle = "line"` (`"arrow"` or `"line"`) and `ConnectionMapColor = "dynamic"` (`"dynamic"` or `"white"`).

**Difficulty** (`Config:414-438`, 4 settings)

| Setting | Default | Meaning |
|---|---|---|
| `GlobalSettings.difficultyScaling` | `{[1]=1.0,[2]=1.0}` | Multiplier of non-supply AI timers per side, 0.10 to 5.00 (`Config:417-423`). |
| `GlobalSettings.directorBattlefieldIntelligenceEnabled` | `true` | Director remembers sortie and supply outcomes (`Config:425-431`). |
| `GlobalSettings.directorAirCombatIntelligenceEnabled` | `true` | Director uses recent air-combat results to redirect CAP (`Config:433-436`). |
| `RedReactiveDifficulty` | `"medium"` | Profile of the reactive counterpressure (`Config:438`). |

**Ground Units** (`Config:443-544`, 12 settings)

| Setting | Default | Meaning |
|---|---|---|
| `MaxRedGroundGroupsPerZone` | `12` | Cap of generated Red groups per zone in a fresh PvE campaign, 5 to 12; per-map maxima listed in the comment (Caucasus 10) (`Config:445-463`). |
| `MaxBlueGroundGroupsPerZone` | `4` | Same for the randomised Blue garrison, 1 to 4 (`Config:465-481`). |
| `DisableZonePatrol` | `false` | No roaming of ground groups inside zones (`Config:483-486`). |
| `RedTemplateEnabled` | 14 rows, all `true` | SA-2, SA-3, SA-5, SA-6, SA-8, SA-9, SA-13, SA-15, SA-19, SA-10, SA-11, Tor M2, Pantsir S1, MANPAD, each tagged with its eras (`Config:488-507`). |
| `DisableMantis` | `false` | Turn off the coordinated air defence (`Config:509-511`). |
| `UseStatics` | `true` | Static ground targets in zones (`Config:513-515`). |
| `HideSAMOnMFD` | `"random"` | `false`, `true` or `"random"` (50 % per spawn) (`Config:517-522`). |
| `RevealSamOnMfdAfterDetection` | `false` | PvE: reveal a SAM at its next spawn once it radiated or was identified by Intel (`Config:524-527`). |
| `NightMantisInterval` | `30` | Seconds between air-defence decisions at night (15 by day), 0 = off (`Config:529-533`). |
| `NightRadarBlur` | `true` | Low-flying players harder to detect at night (`Config:535-538`). |
| `RedAiGroundSkill`, `BlueAiGroundSkill` | `"Excellent"` | DCS skill of zone ground defenders (`Config:540-544`). |

**AI Flights** (`Config:547-882`, 24 settings)

| Setting | Default | Meaning |
|---|---|---|
| `RedCapPlaneEnabled` | 18 rows | Check-list of `.miz` template names such as `RED_MIG29S_CAP_R77x3_R27ET_R73x2`, each tagged with eras and the aircraft type it requires (`Config:550-590`). |
| `BlueCapPlaneEnabled` | 16 rows | (`Config:593-629`). |
| `RedCasPlaneEnabled` | 30 rows | (`Config:632-692`). |
| `BlueCasPlaneEnabled` | 13 rows | (`Config:695-722`). |
| `RedSeadPlaneEnabled` | 12 rows | (`Config:725-742`). |
| `BlueSeadPlaneEnabled` | 5 rows | (`Config:745-756`). |
| `RedRunwayStrikePlaneEnabled` | 4 rows | (`Config:759-767`). |
| `RedEnemyStrikePlaneEnabled` | 2 rows | (`Config:770-773`). |
| `RedCasHeloEnabled` | 14 rows | (`Config:776-799`). |
| `BlueCasHeloEnabled` | 11 rows | (`Config:802-824`). |
| `RedSupplyHeloEnabled`, `BlueSupplyHeloEnabled` | 2 rows each | (`Config:827-840`). |
| `PvPChanceAiAttackHelo` | `0` | Percent chance that AI air missions also target helicopters, PvP (`Config:845`). |
| `InvisibleA10` | `false` | A-10 excluded from Red fighter targets (`Config:848`). |
| `ChanceAiAttackHelo` | `0` | Same chance in PvE (`Config:854`). |
| `EnableHunter` | `true` | Hunter two-ship after a kill streak (`Config:858`). |
| `AiPlaneSkill` | `"Random"` | Skill of Red aircraft (`Config:861`). |
| `CapDifficulty`, `CasDifficulty`, `SeadDifficulty`, `RunwayStrikeDifficulty` | `"medium"` | Which column of the Red stage tables applies (`Config:866-874`). |
| `FriendlyCapSupport`, `FriendlyCasSupport`, `FriendlySeadSupport` | `"medium"` | Which column of the Blue support stage tables applies (`Config:877-882`). |

The twelve `*Enabled` tables total 129 template names; each named template must exist as a late-activated group in the `.miz` ("a check box cannot create a missing aircraft", `manual p.10`).

**Difficulty advanced** (`Config:885-1145`, 10 tables)

| Setting | Shape | Meaning |
|---|---|---|
| `CapLimitStages` | `easy` / `medium` / `hard`, each a list of `{ player = n, amount = m }` | Red CAP amount by counted players; one amount = one patrol + one attack group (`Config:888-927`). |
| `RedCasLimitStages`, `RedSeadLimitStages`, `RedRunwayStrikeLimitStages` | same shape | Simultaneous Red flights of each role (`Config:936-1044`). |
| `BlueCapSupportStages`, `BlueCasSupportStages`, `BlueSeadSupportStages` | same shape | Automatic Blue support, larger with fewer players (`Config:1053-1111`). |
| `CapCountIgnoreTypes` | 7 rows | Aircraft types not counted as players for CAP scaling (`Config:1113-1131`). |
| `RedCasCountIgnoreTypes`, `BlueCasCountIgnoreTypes` | 3 rows each | Same for CAS/SEAD/runway scaling (`Config:1134-1145`). |

**Message Of The Day** (`Config:1148-1162`, 1 table): `MessageOfTheDay = { enabled = false, durationSec = 15, intervalSec = 1800, text = [[...]] }`.

**Callsigns** (`Config:1164-1234`, 1 table): `CallsignOverrides`, 17 aircraft-family keys (each key is a prefix looked up by `applyCallsignOverrides`, `WelcomeMessage.lua:540-545`, e.g. `"F.A.18"`, `"F.16CM"`), each with one to five callsign families and four IFF codes per family (`Config:1166-1180`).

**Escort** (`Config:1238-1270`, 2 settings): `EscortTypeByPlayerType`, 16 rows `["<DCS type>"] = { enabled, "<BLUE CAP template>", "<RED CAP template>" }` (`Config:1241-1266`), and `EscortTakeoffFromGround = true` (`Config:1270`).

**Logistics / Warehouse** (`Config:1273-1571`, 23 settings)

| Setting | Default | Meaning |
|---|---|---|
| `WarehouseLogistics` | `true` | Warehouse and zone-supply system; `false` = legacy supplies (`Config:1279`). |
| `ZoneCaptureBuildSeconds` | `120` | Neutral capture timer, 0 = immediate (`Config:1284`). |
| `NormalSupplyCapacity` | `1` | Automatic ready-supply target of a normal zone, 1 to 3 (`Config:1289`). |
| `WarehouseSupplyCapacity` | `6` | Same for a `[WH]` zone, 3 to 6 (`Config:1294`). |
| `CTLDSupplyCapacity` | `1` | Starting supplies of a CTLD FARP (`Config:1299`). |
| `GlobalSettings.supplyDifficultyScaling` | `{[1]=1.0,[2]=1.0}` | Multiplier of AI supply timers and supply production per side (`Config:1301-1310`). |
| `GlobalSettings.repairDifficultyScaling` | `{[1]=1,[2]=1}` | Multiplier of repair/build time per side; base times are in the comment (`Config:1312-1325`). |
| `ExtraRedRepairTimeLowPlayerCountPercent` | `0` | Extra Red repair time when fewer than 2 Blue CAS players, 0 to 50 (`Config:1327-1332`). |
| `PlayerZoneSuppliesConsumeStock` | `true` | A player pickup removes one ready supply (`Config:1337`). |
| `UseC130LoadAndUnload` | `true` | Native C-130/CH-47 cargo systems tracked (`Config:1340`). |
| `SuppliesCargoTransport` | `true` | AI supply helicopters carry a real sling load (`Config:1344`). |
| `AIDeliveryamount` | `20` | Warehouse items added per type by an AI helicopter delivery (`Config:1347`). |
| `AutoFillResources` | `5` | Items added to every active Blue airbase every 15 min, 0 = off (`Config:1350`). |
| `NoAIBlueSupplies` | `false` | Stop regular Blue AI supplies (`Config:1352-1354`). |
| `NoAIBlueCapture` | `false` | Stop automatic Blue capture dispatches to neutral zones (`Config:1356-1359`). |
| `RadioMenuStopSupplies` | `false` | Players may pause Blue AI supplies from the menu (`Config:1361-1363`). |
| `AllowedToCarrySupplies` | 18 rows | Legacy per-type permission, ignored when `WarehouseLogistics` is on (`Config:1365-1386`). |
| `WarningNoSupplies` | `true` | Warn a supply-capable aircraft that takes off empty (`Config:1389`). |
| `ZoneSupplyTakeoffWarningTypes` | 21 rows | Types concerned by that warning (`Config:1396-1418`). |
| `StrictSmartWeaponsInventory` | `false` | Halve refills of the weapons listed below (`Config:1420-1422`). |
| `WarehouseWeaponCaps` | empty | The list of weapon ids concerned (`Config:1424-1427`). |
| `WarehouseWeaponsAllowedAtAirbases` | empty | PvE: per map, stock a given weapon only at named warehouses, e.g. AIM-54C only on the carriers (`Config:1429-1434`). |
| `WarehouseWeaponLocationAirbases` | 10 maps, 59 names for Caucasus | Picker catalogue of warehouse names (`Config:1436-1571`, Caucasus `Config:1450-1466`). |

**Shop / Rewards** (`Config:1574-1952`, 14 settings)

| Setting | Default | Meaning |
|---|---|---|
| `AllowCapAutoBuyAfterLoss`, `MaxCapAutoBuys` | `false`, `1` | Automatic re-purchase of a lost CAP flight (`Config:1577-1584`). |
| `TurnaroundRewardPercent` | `10` | Same-aircraft bonus, 0 to 50 (`Config:1586-1589`). |
| `NightRewardPercent` | `10` | Night take-off bonus, 0 to 50 (`Config:1591-1594`). |
| `AdvanceCaptureRemainingThreshold` | `50` | Percent of enemy upgrade groups left at which Advance Capture appears, 20 to 60 (`Config:1598-1602`). |
| `AvailableShopItems` | 70 rows | Shop item id to boolean, each row with visibility conditions on PvP and era (`Config:1604-1767`). |
| `ShopPrices` | 48 rows | Item id to credits, e.g. `smoke = 20`, `dynamiccap = 500`, `dynamicarco = 1000` (`Config:1771-1842`). |
| `ShopRankRequirements` | 47 rows | Item id to minimum rank (`Config:1846-1916`). |
| `RewardContribution` | 15 rows | infantry 10, ground 10, ctldGround 10, ctldAir 20, sam 30, airplane 50, ship 200, helicopter 50, crate 100, rescue 200, enemyPilotCapture 200, structure 100, Zone upgrade 100, Zone capture 200, Warehouse delivery 150 (`Config:1918-1936`). |
| `RefuelReward` | `2` | Credits per 100 lb received (`Config:1938-1939`). |
| `AIAttackTakeoffFromGround`, `AIAttackTakeoffFromGroundExtraNM` | `true`, `40` | Purchased flights start from an airbase, with extra stand-off (`Config:1941-1944`). |
| `AllowAdminBuy` | `true` | `adminbuy:<id>` marker bypassing the rank filter (`Config:1946-1948`). |
| `AllowScriptedSupplies` | `false` | Purchased supplies applied at once instead of flown in (`Config:1950-1952`). |

**CTLD** (`Config:1955-2195`, 10 settings)

| Setting | Default | Meaning |
|---|---|---|
| `CTLDCost` | `true` | CTLD items cost credits and need a rank (`Config:1958-1959`). |
| `Allow_Red_CTLD` | `false` | Red CTLD in PvE (`Config:1961-1963`). |
| `MaxTroopsRunDistanceTowardZone` | `5000` | Metres dropped troops will run to a zone, 2 000 to 15 000 (`Config:1965-1967`). |
| `CTLDCargoTrackingInterval` | `3` | Seconds between cargo checks, 3 to 6 (`Config:1969-1971`). |
| `CTLDPrices` | 49 rows | Item name to `{ available, price, reqRank }` (`Config:1973-2059`). |
| `MAX_AT_SPAWN` | 48 rows | Item name to number of saved copies restored at restart (`Config:2061-2146`). |
| `CaptureZoneWithEngineer` | `false` | Engineers count as capture troops (`Config:2148-2150`). |
| `MAX_SAVED_FARPS` | `3` | Player FARPs restored from the save (`Config:2153-2155`). |
| `IRIS_RESTORE_UNIT_HEALTH_ON_MERGE` | `false` | IRIS-T add-on merge rebuilds from the full template (`Config:2157-2161`). |
| `CTLDUnitCapabilities` | 18 rows | Type to `{ crates?, troops?, crate limit, troop limit, length m, max cargo kg }`, with the comment "changing values will mostly have negative impact on the CTLD code" (`Config:2163-2195`). |

**CSAR** (`Config:2198-2257`, 10 settings): `AllowedCsar` (21 rows, type to seats, 0 = no menu), `CsarPilotSpawnWithoutCreditsChance = 50`, `Max_CSAR_At_Once = 10`, `Max_CSAR_AT_Mission_Restart = 10`, `PilotWeight = 80`, `CsarHoverDistance = 20`, `CsarGuidanceDistance = 70`, `CsarHoverHeight = 60`, `CsarHoverSeconds = 10`, `CsarHostileInfantryChance = 25` (`Config:2205-2257`).

**Flight Time** (`Config:2259-2303`, 4 settings): `RewardFlightTime = true`, `FlightTimeRewardPerMinute = 2`, `RewardAllAircraft = false`, `AllowedFlightTimeReward` (25 rows, only `C-130J-30`, `CH-47Fbl1`, `Hercules` enabled per `manual p.19`).

**Tankers** (`Config:2306-2311`, 2 settings): `TexacoSpeed = 286`, `ArcoSpeed = 286` knots, with the comment that the orbit speed is hard-coded at 280.

**EWRS** (`Config:2314-2360`, 23 settings): `ewrs_enabled = true`, `ewrs_defaultReportStyle = 2`, `ewrs_maxRangeKm = 150`, `ewrs_maxRangeNm = 100`, `ewrs_defaultAircraftRangeLimit = 60`, `ewrs_defaultHelicopterRangeLimit = 20`, `ewrs_messageUpdateInterval = 20`, `ewrs_messageDisplayTime = 15`, `ewrs_restrictToOneReference = false`, `ewrs_defaultReference = "self"`, `ewrs_defaultMeasurements = "imperial"`, `ewrs_defaultShowTankers = false`, `ewrs_enableRedTeam = true`, `ewrs_enableBlueTeam = true`, `ewrs_disableMessageWhenNoThreats = true`, `ewrs_onDemand = false`, `ewrs_maxThreatDisplay = 5`, `ewrs_allowBogeyDope = true`, `ewrs_allowFriendlyPicture = true`, `ewrs_maxFriendlyDisplay = 3`, `ewrs_showType = true`, `ewrs_mergedRangeNm = 5`, and the table `ewrs_specialPlaneTypes` (4 rows).

**AIEN** (`Config:2363-2382`, 9 settings): `AIEN.config.dontInitialize = false`, `.blueAI = true`, `.redAI = true`, `.dismount = true`, `.message_feed = true`, `.initiative = true`, and the globals `phaseCycleTimerMin = 0.2`, `phaseCycleTimerActive = 0.08`, `phaseCycleTimerIdle = 0.5`.

**Aircraft / Weapons** (`Config:2385-3458`, 17 settings)

| Setting | Active rows (commented rows) | Meaning |
|---|---|---|
| `PvPSeparateAircraftLists` | `false` | One warehouse aircraft list per coalition in PvP (`Config:2388-2391`). |
| `allowedPlanesModern`, `allowedPlanesRedModern` | 18 (76), 17 (77) | Modern PvP lists when separate lists are on (`Config:2419-2617`). |
| `allowedPlanes` | 54 (3) | Blue warehouse aircraft in Coldwar/Gulfwar (`Config:2622-2680`). |
| `allowedPlanesSharedColdwarPvP`, `allowedPlanesBlueColdwarPvP` | 56 (9), 55 (3) | Coldwar PvP shared / Blue lists (`Config:2686-2817`). |
| `allowedPlanesRed`, `allowedPlanesRedColdwarPvP` | 53 (5), 53 (10) | Red/neutral warehouses in Coldwar (`Config:2822-2951`). |
| `allowedPlanesVietnam`, `allowedPlanesSharedVietnamPvP`, `allowedPlanesBlueVietnamPvP` | 16 (10), 22 (21), 16 (17) | Vietnam Blue / shared lists (`Config:2956-3073`). |
| `allowedPlanesRedVietnam`, `allowedPlanesRedVietnamPvP` | 6 (14), 8 (26) | Vietnam Red lists (`Config:3078-3140`). |
| `restockAircraft` | 35 | Mod aircraft restocked when `AllowMods` and Modern (`Config:3141-3180`). |
| `restrictedWeapons` | 83 (10) | DCS weapon ids removed from Coldwar/Gulfwar warehouses, e.g. `weapons.missiles.F16V_GBU39` (`Config:3182-3279`). |
| `restrictedWeaponsVietnam` | 45 (25) | Same for Vietnam (`Config:3284-3360`). |
| `ForbiddWeaponsInAllEra` | 2 (90) | Hard ban in every era (`Config:3365-3458`). |

Twenty-two `-- @gui requiredSet=...` comment lines link the AI template tables and shop items to the aircraft types that must stay in these lists, e.g. `F-4E-45MC` is required while `dynamiccas` is purchasable and flights take off from the ground (`Config:2393-2417`).

**Testing** (`Config:3461-3465`, 1 setting): `Testing = false`.

**Admin Commands** (`Config:3468-3514`, 2 settings): `AdminCommands = false`, and `AdminCommandAliases` with 12 empty string fields: `addBlueFunds`, `addRedFunds`, `addZoneItems`, `buyWithoutRank`, `createFarp`, `captureNeutralBlue`, `captureNeutralRed`, `clearZone`, `upgradeZone`, `fullyUpgradeZone`, `restartMission` (raises flag 181), `endMission` (`Config:3477-3514`).
The manual's table lists 11 of the 12 (`endMission` is absent from `manual p.62`).

### What `Foothold Config WW2.lua` changes for Normandy

The file is 999 lines against 3 530 and holds 104 settings (76 scalars, 28 tables) measured with the same script (`ConfigWW2:1-999`).
Its loader only looks for `Foothold Config WW2.lua` in the Saves folder and tracks 24 tables and 10 scalars (`ConfigWW2:18-60`, `ConfigWW2:116-132`).
Sections removed entirely: PvP settings, Frequencies, F10 Map, Escort, CTLD, Tankers, Testing; and from Mission options `Era`, `PvP`, `StartNormal`, `AllowMods`, carrier and Tarawa settings (`ConfigWW2:134-192`).
Removed from other sections: all template check-lists, SEAD stage tables and difficulty, MANTIS/MFD/night settings, the warehouse-item settings (`ConfigWW2:215-260`, `ConfigWW2:527-603`).
Changed defaults: `SplashDamage = true` (`ConfigWW2:177`), `MaxRedGroundGroupsPerZone = 6` (`ConfigWW2:220`), `ewrs_maxFriendlyDisplay = 5` (`ConfigWW2:843`), empty ignore lists (`ConfigWW2:456-463`), a shop of 20 items instead of 70 (`ConfigWW2:626-697`).
Added: `AddWeightToPlaneRed` (4 rows) and `AddWeightToPlaneBlue` (8 rows) (`ConfigWW2:425-445`), `ewrs_altitudeDisplayMode = "wwii"` reporting Low/Medium/High instead of an altitude (`ConfigWW2:813`), and the two warehouse lists `AllowedWW2Planes` and `AllowedWW2RedPlanes` of 18 types each (`ConfigWW2:891-935`).

## 3. The per-map setup file (`MA_Setup_CAv2.lua`, Caucasus)

The setup file is the sixth script loaded (after Moose, localisation, Config, engine and EWRS, see §4) and is the only place where the map exists as data.
It is one flat Lua chunk of 10 014 lines with no module structure: global tables first, then calls on the engine objects, then several thousand lines of shop actions and mission generators.
The counts below are regex counts on the file (script `setupstats.py` in the scratchpad), so a call inside a conditional branch or inside a callback is counted like any other.

### Structure from top to bottom

| Lines | Block | What the map author writes there |
|---|---|---|
| 1-87 | Helpers | Localisation shortcuts, `BlueUpgradeTemplateMigration` (25 old group names mapped to current ones so old saves still load, `setup:20-46`), `merge`, `allExcept`, `BuildEnabledTemplateList` (`setup:73-87`). |
| 89-294 | `upgrades` | 49 named garrison lists `{ blue = {...}, red = {...} }` of `.miz` group or static names. |
| 296-375 | `flavor` | One localised text per zone (waypoint number, role), about 75 entries. |
| 376-438 | `WaypointList` | 61 entries `Zone = ' (n)'`, the waypoint number shown in the map label. |
| 440-485 | Mode and save name | PvP aircraft-list selection, `FootholdSaveBaseName` per era and mode, save path under `Missions/Saves`. |
| 487-591 | Era swaps | `cwSwap` / `vnSwap` tables replacing Modern template names by Cold War or Vietnam ones, applied by `deepSwap` to `upgrades`. |
| 593-751 | Random garrisons | `RandomRedPool` (46 names), `RandomBluePool` (9), `ZoneSizeExclusions`, `RandomUpgradeTemplates` (14 size profiles), `RandomUpgradeTemplatesBlue`, PvP profiles. |
| 754-762 | Engine object | `bc = BattleCommander:new(filepath, 10, 60)` and the rank file path (`setup:754-757`). |
| 765-1002 | `zones` | 88 `ZoneCommander:new{...}` in the table plus one PvP-only zone, then per-zone PvP and era adjustments (`industryCores`, `pvpVictoryZones`, extra pinned SAMs). |
| 1004-1228 | AI template lists | Per-role lists of `.miz` template names (`AllCapPlaneTemplates`, `AllCasPlaneTemplates`, …) filtered by the Config check-lists, era variants of the convoy lists, altitude helpers. |
| 1230-1288 | Airbase binding | 56 assignments `zones.<x>.airbaseName = '<DCS airbase or FARP name>'`. |
| 1290-1839 | Sorties | 56 `zones.<x>:addGroups({...})` blocks holding 402 `DirectorCapability:new` and 7 `GroupCommander:new`. |
| 1841-2046 | `SpawnFriendlyAssets` | The zone-change hook: wakes hidden zones, adds connections at run time, activates carriers and their navigation area. |
| 2048-2064 | Registration | `bc:addZone(v)` for every zone, with PvP assertions on industry cores. |
| 2067-2112 | `missions` | 4 helicopter ground-escort missions (PvE only). |
| 2114-2269 | Connections | The static part of the 135 `bc:addConnection` and 14 `bc:addHiddenConnection` calls. |
| 2271-2507 | Director theatre data | `TheaterInfrastructure` (9 entries), `TheaterRegions` (empty on Caucasus), `TheaterAreas` (9 areas with zone roles). |
| 2509-2730 | Scripted zone triggers | Most of the 31 `registerTrigger` calls: counter-attacks on capture, zones disabled when lost, bonus credits. |
| 2732-2846 | Victory | `checkMissionComplete`, reset of the save, flag 181, restart menu. |
| 2848-2886 | Roaming | Name prefixes of the groups that patrol inside their zone, and of the ships that roam. |
| 2889-3883 | "DYNAMIC SHOP" | Price defaults and the action code of purchasable flights (CAP, CAS, bomber…), with their zone selectors. |
| 3886-4240 | Supply and capture shop actions | Not read (estimation from the function name `clearFriendlySupplyMenu`, `setup:3886`). |
| 4241-4795 | JTAC | JTAC drone objects per era, 9-line JTAC zones, `CheckJtacStatus`. |
| 4796-5404 | "Zone upgrades" | Shop items that add a garrison group to a zone, Red AI purchases (`redMassAttackAction`, `setup:4814`), extra slots. |
| 5406-5500 | Fallback tables | `ShopPrices = ShopPrices or {...}` used when the Config did not define it (rank defaults in the same block: estimation). |
| 5501-5751 | Shelves | 76 `bc:addShopItem(side, id, stock, order, rank, category)` calls and the seven category labels. |
| 5753-5833 | Logistics and mission slots | `supplyZones` (34 names), `LogisticCommander:new`, `init*Missions`. |
| 5835-5993 | Load and post-load | `bc:loadFromDisk()`, era shelf clean-up, PvP start funds, restoring `StartNormal` from the save, disabling one-shot zones, carrier activation. |
| 5996-6129 | Service start | Reward loop, caches, frontline, warehouse persistence, carrier navigation, hunter, AWACS, suspension distances, `EventCommander`, `MissionCommander`, `DynamicHybridConfig`, the two `Director` objects, reactive counterpressure. |
| 6131-6558 | Events | SCUD site, cargo-plane intercept, ship intercept, bomber event, airstrike. |
| 6559-9037 | Mission generators | SEAD (`setup:7461`), recon (`setup:7646`), artillery strike, CAP, CAS (`setup:8378`), ground escort (`setup:8553`), runway (`setup:8739`); lines 6559-7458 not read. |
| 9039-9716 | Strike events | Six high-value strike targets and seven "SAM warehouse" targets, each an `evc:addEvent` plus an `mc:trackMission`. |
| 9718-9890 | Timers | Mission-generation timers (120 s or 300 s re-arm) and `mc:init()`. |
| 9899-9936 | `airbaseStatics` | 35 FARPs with the names of their decor statics, read by `WelcomeMessage.lua:235-261`. |
| 9938-10009 | Testing area | Spawns test templates in the `testing` zone when `Testing` is on. |

### Counts (Caucasus)

| Thing | Count |
|---|---|
| Zones | 89 `ZoneCommander:new` (88 in the `zones` table, 1 PvP-only hidden EWR zone) |
| Zones by `facility` | 21 `airbase`, 35 `farp`, 1 `carrier`, 32 `none` |
| Zones by `size` | `small` 24, `mediumbig` 15, `smallmedium` 12, `sam` 12, `medium` 4, `bignosam` 4, `big` 1, `smallwithShorad` 1, `samspecial` 1, `redarmycamp3` 1, no size 14 |
| Starting side | 76 red, 8 neutral, 1 blue, 4 depending on `StartNormal` |
| Named garrison lists | 49 in `upgrades` |
| Sortie declarations | 402 `DirectorCapability:new` + 7 `GroupCommander:new` in 56 `addGroups` blocks |
| Sorties by `mission` | 247 supply, 86 attack, 76 patrol |
| Sorties by `MissionType` | 96 CAP, 28 CAS, 18 ARTY, 4 RUNWAYSTRIKE, 1 SEAD, 262 without |
| Sorties by `template` | `HeloSupplyTemplate` 208, `CapPlaneTemplate` 96, `PlaneSupplyTemplate` 25, `CasHeloTemplate` 21, `SupplyConvoy` 14, `ArtilleryConvoyShort` 14, `AttackConvoy` 8, `CasPlaneTemplate` 7, `ArtilleryConvoyLong` 4, `RunwayStrikePlaneTemplate` 4, `SeadPlaneTemplate` 1, own `.miz` group 7 |
| Sorties by `type` | 362 air, 47 surface |
| Sorties with a `condition` | 23 |
| Connections | 135 `bc:addConnection` (a few inside run-time callbacks, e.g. `setup:1903`) + 14 `bc:addHiddenConnection` |
| Shop items | 56 `bc:registerShopItem` calls for 45 distinct ids; 76 `bc:addShopItem` calls for 54 distinct ids (49 on the Blue shelf, 26 on the Red one) |
| Events | 17 `evc:addEvent` |
| Tracked missions | 44 `mc:trackMission` |
| Zone triggers | 31 `registerTrigger` (24 `lost`, 5 `captured`, 2 `destroyed`) |
| Director data | 9 `TheaterAreas`, 9 `TheaterInfrastructure`, 0 `TheaterRegions` |
| Localisation calls | 699 `L10N` / `LTGet` / `LTFormat` references |
| Mode branches | 262 references to `pvpEnabled`, 90 era tests (`Era ==`, `Era ~=`, `ColdWarTechEra`), 32 references to `StartNormal`, 63 to `CustomFlags[...]` |
| Direct `.miz` lookups | 84 `Group.getByName`, 24 `SCENERY:FindByZoneName` |

### One excerpt per kind of declaration

Long lines are cut with `…`; the number before each line is its line number in `MA_Setup_CAv2.lua`; skipped numbers are skipped lines.

Garrison lists (`upgrades`); an entry is a `.miz` group name, a static name, or `{ n = name, p = true }` for a pinned entry (field meanings in `01-zones-capture-map.md`):

```lua
89:  upgrades = {
90:  	redships = {
91:  		blue = {},
92:  		red = {'Molniya', 'Molniya', 'Rezky', 'Grisha', 'Molniya', 'Grisha', 'SpeedBoats', 'SpeedBoats','SpeedBoats'}
93:  	},
94:  	airfield1 = {
95:  		blue = {'blueInfantry', 'Blue Armor Modern', 'Blue SAM NASAMS'},
96:  		red = {'Enemy ground forces', 'Red SAM AAA', 'Red SAM AAA 2', 'Red Armour Group 2', 'Red Armour Group 3', 'Red SAM SHORAD SA-8', …}
97:  	},
98:  	Soganlug = {
99:  		blue = {'blueInfantry', 'Blue Armor Modern', { n = 'Blue SAM NASAMS', p = true }},
100: 		red = {'Red SAM AAA', 'Red SAM SHORAD SA-15'}
101: 	},
```

Random garrison profiles (one line per zone size; `{a,b}` is a range, `total` the number of groups):

```lua
698: RandomUpgradeTemplates = {
699: 	small = { sam = 0, shorad = {0,2}, aaa = {0,2}, ground = {0,3}, armor = {0,2}, arty = {0,2}, total = {4,6}, flakChance = 10, … },
702: 	medium = { sam = {0,1}, shorad = {0,3}, aaa = {0,3}, ground = {0,3}, armor = {0,3}, arty = {0,3}, total = {4,9}, flakChance = 20, … },
706: 	extrabig = { sam = {1,2}, shorad = {0,5}, aaa = {0,4}, ground = {0,4}, armor = {0,4}, arty = {0,4}, total = {7,12}, flakChance = 60, … },
710: 	redarmycamp = { sam = 0, shorad = 0, aaa = 0, ground = {3,5}, armor = 0, arty = {0,5}, total = {6,8} },
```

Zone declarations:

```lua
765: zones = {
766: 	redcarrier = ZoneCommander:new({facility='carrier', isHeloSpawn=Era ~= 'Vietnam' and true or nil, zone='Red Carrier', side=1, level=25, upgrades=upgrades.redships, crates={}, flavorText=flavor.redcarrier}),
768: 	batumi = ZoneCommander:new({facility='airbase', isPlaneSpawn=true, isHeloSpawn=true, zone='Batumi', side=1, size='big', level=25, upgrades=upgrades.airfield1, crates={}, flavorText=flavor.batumi}),
771: 	kutaisi = ZoneCommander:new({facility='airbase', isPlaneSpawn=true, isHeloSpawn=true, zone='Kutaisi', side=1, size='medium', level=25, upgrades=upgrades.airfield4Kutaisi, crates={}, flavorText=flavor.kutaisi, income=0.1}),
773: 	gudauta = ZoneCommander:new({facility='airbase', isHeloSpawn=true, zone='Gudauta', side=1, size='mediumbig', level=25, upgrades=upgrades.airfield2, crates={}, flavorText=flavor.gudauta}),
777: 	anapa = ZoneCommander:new({facility='airbase', isPlaneSpawn=true, isHeloSpawn=true, zone='Anapa', side=StartNormal and 2 or 1, size=StartNormal and 'bignosam' or 'mediumbig', level=25, upgrades=upgrades.Anapa, …}),
852: 	hidden1 = ZoneCommander:new({facility='none', zone='Hidden1', side=1, level=25, upgrades=upgrades.Hidden1Group, crates={}, flavorText=flavor.hidden1,NeutralAtStart=true}),
863: 	zones.blueEwr = ZoneCommander:new({facility='none', zone='HiddenBlueEWR', side=2, level=10,
864: 		upgrades={blue={'Blue EWR Fixed Pvp', 'Blue EWR Fixed Pvp-1', …}, red={}},
865: 		crates={}, isHidden=true})
```

Airbase binding (the DCS airbase or FARP static name that the zone owns):

```lua
1231: zones.batumi.airbaseName = 'Batumi'
1234: zones.maykop.airbaseName = 'Maykop-Khanskaya'
1235: zones.anapa.airbaseName = 'Anapa-Vityazevo'
1254: zones.lima.airbaseName = 'Lima'
```

Sortie declarations (`DirectorCapability`; fields in `03-ai-groups-sorties.md` and `04-director.md`):

```lua
1290: zones.kobuleti:addGroups({
1291: 	DirectorCapability:new({name='Support-SAM-India', mission='supply', targetzone='SAM-India',template='SupplyConvoy', type='surface', condition = function(self) return not (self.side == 1 and CustomFlags["SamAlphaWarehouse"])end}),
1292: 	DirectorCapability:new({name='Kobuleti-supply-Senaki', mission='supply',template='HeloSupplyTemplate', targetzone='Senaki'}),
1293: 	DirectorCapability:new({name='Kobuleti-supply-Batumi', mission='supply',template='HeloSupplyTemplate', targetzone='Batumi'}),
1294: 	DirectorCapability:new({name='Kobuleti-patrol-Batumi-Cap', mission='patrol',template='CapPlaneTemplate',MissionType='CAP', targetzone='Batumi', Altitude = CapAltitude()}),
1295: 	DirectorCapability:new({name='Kobuleti-attack-Kutaisi-Cap', mission='attack',template='CapPlaneTemplate',MissionType='CAP', targetzone='Kutaisi', Altitude = CapAltitude()}),
1296: 	DirectorCapability:new({name='Kobuleti-patrol-Kutaisi-Cap', mission='patrol',template='CapPlaneTemplate',MissionType='CAP', targetzone='Kutaisi', Altitude = CapAltitude()}),
1298: })
1365: 	DirectorCapability:new({name='Gudauta-attack-Sukhumi', mission='attack',template='AttackConvoy', targetzone='Sukhumi', type='surface'}),
1366: 	GroupCommander:new({name='Gudauta-attack-Sukhumi-Arty', mission='attack', targetzone='Sukhumi', type='surface', FixedArty = true, SetActiveMission = true}),
```

Connections (signature `addConnection(f, t, drawBoth, preserveDirection)` at `zc2:27025`; hidden ones at `zc2:27033`):

```lua
2114: bc:addConnection("Batumi","Kobuleti")
2115: bc:addConnection("Kobuleti","SAM-India")
2116: bc:addConnection("Kobuleti","Senaki")
2118: bc:addConnection("Senaki","Kutaisi")
2119: bc:addConnection("Kutaisi","India")
2120: bc:addConnection("India","Sukhumi")
2121: bc:addConnection("India","InsurgentCamp",nil,true)
2122: bc:addConnection("Sukhumi","SAM-Foxtrot",nil,true)
2246: bc:addConnection("Sachhere","Kvomo",true)
2252: bc:addHiddenConnection("Nalchik","Beslan")
2253: bc:addHiddenConnection("Mineralnye","Maykop")
```

Director theatre data (infrastructure tying a destructible building to a supply route; areas with a role per zone):

```lua
2271: TheaterInfrastructure = {
2272: 	{
2273: 		id = "kobuleti_sam_india_warehouse",
2274: 		flag = "SamAlphaWarehouse",
2275: 		effect = "defence_supply",
2276: 		side = coalition.side.RED,
2277: 		scope = "routes",
2278: 		sourceZone = "Kobuleti",
2279: 		targetZones = { "SAM-India" },
2280: 	},
2365: TheaterAreas = {
2366: 	{
2367: 		id = "western_georgia",
2368: 		kind = "air_network",
2369: 		name = "Western Georgia",
2370: 		zones = {
2371: 			{ name = "Batumi", role = "hub" },
2372: 			{ name = "MiningFacility", role = "resource" },
2374: 			{ name = "SAM-India", role = "defence" },
2379: 			{ name = "India", role = "gateway" },
```

Shop registration (the item and its action, `zc2:19322`) and shelving (side, id, stock where -1 is unlimited, menu order, rank, category, `zc2:19341`):

```lua
3053:     bc:registerShopItem('dynamiccap', LTGet("SYRIA_SHOP_ITEM_CAP_FLIGHT"), ShopPrices.dynamiccap, capAction, capAltAction, nil, 'CAP', { [1]=redRow, [2]=blueRow })
3055:     bc:registerShopItem('dynamiccap', LTGet("SYRIA_SHOP_ITEM_CAP_FLIGHT"), ShopPrices.dynamiccap, capAction, capAltAction)
3057: bc.shopItems['dynamiccap'].groupZoneSelector = {
3058: 	targetzoneside = 2,
3059: 	includeSuspended = false,
3060: 	sortPolicy = 'friendly_frontline',
5501: -- first value below is how much in stock, the second number value is the ranking in the shop menu list, the third is the new ranking system.
5509: bc:addShopItem(1, 'redwarehouse', -1, 3, ShopRankRequirements.redwarehouse) -- red AI rear supply depot
5537: bc:addShopItem(2, 'dynamiccap', -1, 1, ShopRankRequirements.dynamiccap, ShopCats.AIAttack) -- CAP Flight
5538: if GlobalSettings.pvpEnabled == true then bc:addShopItem(1, 'dynamiccap', -1, 1, ShopRankRequirements.dynamiccap, ShopCats.AIAttack) end
5743: bc:addShopItem(2, 'dynamicarco', 1, 1, ShopRankRequirements.dynamicarco, ShopCats.OtherSupport) -- Navy tanker
5749: bc:addShopItem(2, 'farphere', -1, 3, ShopRankRequirements.farphere, ShopCats.OtherSupport) -- deploy FARP
```

Missions of the "ground escort" kind (a `.miz` convoy group, a start zone, a target zone, a user flag, a hidden zone to activate):

```lua
2067: missions = GlobalSettings.pvpEnabled ~= true and {
2068:         ["Sochi"] = {
2069:         zone = "Sochi",
2070:         missionGroup = "SochiEscortGroup",
2071:         menuTitle = LTFormat("CA_MISSION_GROUND_ESCORT_TITLE", "Sochi"),
2072:         missionTitle = LTFormat("CA_MISSION_GROUND_ESCORT_TITLE", "Sochi"),
2073:         TargetZone = "Delta",
2074:         radius = 2500,
2075:         MissionType = "Escort",
2076:         flag = 001,
2077: 		ActivateZone = "hidden"
2078:     },
```

An event and its tracked mission (here a strike on a map building found through a trigger zone that carries the scenery object id):

```lua
9339: evc:addEvent({
9340: 	id = 'SamDeltaWarehouse',
9341: 	StrikeMission = true,
9342: 	action = function()
9343: 		local tgt = sceneryList['SamDeltaWarehouse'][1] or SCENERY:FindByZoneName('SamDeltaWarehouse')
9348: 		RegisterScoreTarget('SamDeltaWarehouse',tgt,500,L10N:Get("MISSION_STRIKE_DEFAULT_TITLE"),true)
9352: 			trigger.action.markToCoalition(missionMarkId,L10N:Get("CA_MISSION_STRIKE_SAM_DELTA_WAREHOUSE_TITLE"),p,2,false,false)
9356: 	canExecute = function()
9357: 	if ActiveMission['SamDeltaWarehouse'] then return false end
9358: 	if CustomFlags["SamDeltaWarehouse"] then return false end
9359: 	local sukhumi = bc:getZoneByName('Sukhumi')
9360: 	if sukhumi.side ~= 1 or (sukhumi.suspended and not sukhumi._idleSuspended) then return false end
9363: 	if bc:getZoneByName('India').side ~= 2 and bc:getZoneByName('Sochi').side ~= 2 then return false end
9368: mc:trackMission({
9369: 	title = LTGet("CA_MISSION_STRIKE_SAM_DELTA_WAREHOUSE_TITLE"),
9371: 	messageStart = L10N:Get("CA_MISSION_STRIKE_SAM_DELTA_WAREHOUSE_START"),
9384: 	isActive = function()
9385: 		if CustomFlags["SamDeltaWarehouse"] then return false end
```

Carriers (group activation and the carrier-navigation areas, which are trigger zones named `CVN72_AREA_*`):

```lua
5985: if carriersShouldBeActive then
5986: 	activateGroupIfNotActive('CVN-72')
5987: 	activateGroupIfNotActive('CVN-74')
5988: 	activateGroupIfNotActive('Tarawa')
6014: if Era ~= 'Vietnam' then
6015: 	bc:enableCarrierNavigation()
6018: 			bc:deployCarrierNavigationArea("CVN72_AREA_BATUMI")
6022: 			bc:deployCarrierNavigationArea("CVN72_AREA_NOVOROSSIYSK",true)
6025: 	bc:addCarrierNavigationSuspendConnection("CVN72_AREA_BATUMI", "Batumi", true)
6026: 	bc:addCarrierNavigationSuspendConnection("CVN72_AREA_SOCHI", "Sochi", true)
6034: 	bc:addCarrierNavigationSuspendConnection("CVN72_AREA_NOVOROSSIYSK", "Anapa", true)
```

Special cases (a scripted reaction registered on one zone, `registerTrigger(eventType, action, id, timesToRun, options)` at `zc2:50064`; and a hidden zone woken with a new connection when a neighbour is captured):

```lua
2701: zones.tankfactory:registerTrigger('lost', function(event, sender)
2702: 	if GlobalSettings.pvpEnabled == true then return end
2703: 	sender:disableZone(true)
2704: 	bc:addFunds(2,500)
2705: 	trigger.action.outTextForCoalition(2,L10N:Get("CA_SETUP_TANK_FACTORY_DESTROYED"),20)
2706: end, 'disabletankfactory', nil, {disablesZone = true})
1896: 	if not zones.insurgencygriddl22.isAwaken and zones.krymsk.side == 2 and not insurgencydl22campStarted then
1900: 		zones.insurgencygriddl22:AwakenZoneAndUpgrade()
1903: 		bc:addConnection("Krymsk", "Insurgency Grid DL22")
1904: 		bc:buildConnectionMap()
```

Era and PvP branches (the save name, which decides which campaign file is read, and the era swap table):

```lua
467: if Era == 'Vietnam' then
468: 	FootholdSaveBaseName = 'FootHold_CA_v0.3_Vietnam'
469: elseif Era == 'Coldwar' then
470: 	FootholdSaveBaseName = 'FootHold_CA_v0.3_Coldwar'
471: else
472: 	FootholdSaveBaseName = 'FootHold_CA_v0.3'
473: end
475: if GlobalSettings.pvpEnabled then
476: 	FootholdSaveBaseName = FootholdSaveBaseName .. 'Pvp'
477: end
487: local cwSwap = {
488: 	['Blue SAM NASAMS'] = 'Blue SAM HAWK',
490: 	['Red Armour Group 4']   						= 'Red Armor Group8',
```

### Start-up order inside the setup file

The order of the calls is part of what a map author reproduces: zones are created (`setup:765`), sorties attached (`setup:1290`), zones registered (`setup:2063`), connections declared (`setup:2114`), shop items registered and shelved (`setup:3053`, `setup:5504`), then `lc:init()` and `bc:loadFromDisk()` (`setup:5833-5835`), then the caches and services (`setup:6000-6013`), the event and mission commanders (`setup:6073-6075`), the two Directors (`setup:6120-6123`), and finally the mission generators and `mc:init()` (`setup:9890`).
Per-map tuning constants are set in the same pass: suspension distances `autoSuspendNmBlue = 70` and `autoSuspendNmRed = 95` in PvE, 100 and 100 with `proximityWakeNm = 50` in PvP (`setup:6062-6070`), AWACS orbit parameters (`setup:6053-6060`), `DynamicHybridConfig` with distance limits and 22 per-zone overrides (`setup:6077-6118`), `EventCommander` periods (`setup:6073`).

### Shared boilerplate versus per-map content (comparison with `kola_setup.lua`)

`kola_setup.lua` is 6 867 lines with the same skeleton: `upgrades` (`kola:93-259`), `WaypointList` (`kola:627-685`), `flavor` (`kola:687-742`), save name (`kola:745`), `zones` (`kola:842-939`), `TheaterInfrastructure`, `TheaterRegions` and `TheaterAreas` (`kola:1983-2335`), `supplyZones` (`kola:2338-2387`), `airbaseStatics` (`kola:6834-6867`).
Measured on whitespace-normalised non-blank lines, 62 % of Kola's lines (3 450 of 5 605) also exist verbatim in the Caucasus file.
The same measure for the other setup files against Caucasus gives Iraq 74 %, Sinai North 74 %, Persian Gulf 72 %, Afghanistan 69 %, Sinai extended 69 %, Syria 69 %, Germany Cold War 65 %, South Atlantic 62 %, Normandy 35 %.
Per 500-line slice of the Caucasus file, the share of lines also present in Kola is 2 % for lines 1501-2000 and 10 % for lines 2001-2500 (sorties, connections, theatre data), 60 to 77 % for lines 3001-5500 (shop actions and zone-upgrade items), and 27 to 59 % elsewhere.
So the shop action code, the JTAC and mission-generator code and the service start-up are copied from map to map with small edits, while the per-map data is concentrated in roughly 2 500 lines: garrison lists, zones, airbase binding, sorties, connections, theatre areas, scripted triggers, strike targets and FARP statics.
There is no shared include file: the copied code lives in each of the eleven setup files.

Kola counts for comparison (same script): 81 `ZoneCommander:new`, 315 `DirectorCapability:new` + 5 `GroupCommander:new` in 55 blocks, 91 connections + 3 hidden, 45 `registerShopItem`, 52 `addShopItem`, 18 events, 31 tracked missions, 3 `registerTrigger`, 16 `TheaterRegions`, 7 `TheaterAreas`.
Per-map differences seen in Kola: no PvP (2 references to `pvpEnabled` against 262) and no `StartNormal`; the starting side of whole countries is a variable (`sideSE`, `sideNO`, `sideFIN`, `sideFIN_SE`) set from saved flags, giving several campaign layouts (`kola:756-820`); a `DynCampaign` flag changes the save name (`kola:745`); its own size profiles (`mediumsam`, `bigsam`, `armor4`…); multi-zone `TheaterRegions` (`kola:2002-2208`).

## 4. The `.miz` conventions (Caucasus mission)

Source: `Missions/Foothold_CA_6.5.2_Coldwar-Modern-Vietnam.miz`, already extracted by a sibling into the scratchpad folder `miz-ca-02`; the `mission`, `options`, `warehouses`, `dictionary` and `mapResource` files were parsed with a small Lua-table parser in Python (scripts `miz1.py`, `miz2.py`, `miz3.py`, kept outside the extracted folder and run with `python -I`).
Every number in this section is measured on the parsed tables.
The archive holds `mission` (8.2 MB), `warehouses` (12.2 MB), `options`, `theatre`, `KNEEBOARD/IMAGES/Freq.png` and `l10n/DEFAULT` with 70 files: 12 Lua scripts, 54 `.ogg`, 1 `.wav`, 1 `.jpg`, `dictionary` and `mapResource`.

### Triggers and script load order

The mission has 7 trigger rules (`mission` table `trigrules`, with conditions and actions in `trig`).

| # | Name | Type | Condition | Actions |
|---|---|---|---|---|
| 1 | Remove Trees | start | none | 12 `a_remove_scene_objects` on trigger-zone ids, masks 0 or 1 (ids not resolved to zone names) |
| 2 | ScriptLoader 1 | start | none | `Moose_2026-10-11.lua`, `Foothold_Localization.lua`, `Foothold Config.lua` |
| 3 | ScriptLoader 2 | start | none | `zoneCommanderv2.lua`, `EWRS.lua`, `MA_Setup_CAv2.lua`, `WelcomeMessage.lua` |
| 4 | ScriptLoader 3 | once | `c_time_after(3)` | `Zeus.lua`, `Foothold CTLD.lua`, `Foothold_CTLD_Red.lua`, `Splash_Damage_3.4.1_leka.lua` |
| 5 | AIEN | once | `c_time_after(12)` | `AIEN.lua` |
| 6 | Sounds | once | none | 54 `a_out_sound_g` to group id 41, one per sound file |
| 7 | END GAME | once | `c_flag_is_true("181")` | `a_end_mission("blue", "", 0)` |

The "Sounds" rule plays every sound file to one group; its visible purpose is to make the Mission Editor keep the sound files in the archive, since the scripts play them by file name with `trigger.action.outSoundForCoalition` (e.g. `setup:1902`) (estimation on the purpose).
Flag 181 is the only link from the scripts back to the mission triggers (`setup:2811`, `Config:3508`).
Flag 180 is read by the setup file to mute mission sounds (`setup:6202`); where it is set was not looked up.
The load order and its consequences are detailed in `02-persistence-lifecycle-plumbing.md`.

### Trigger zones

There are 1 331 trigger zones: 1 240 circles and 91 quads.
Thirteen zones carry Mission Editor properties (`OBJECT ID`, `NAME`, `ROLE`, `VALUE`): they are the zones bound to a map building, used for strike targets (`StrikeTarget`, `StrikeTarget1`, `StrikeTarget2`, `StrikeVaziani`, `LefttHandMan`, `RightHandMan`, and the seven `Sam<X>Warehouse`).
No zone carries any other property: every engine meaning is carried by the zone name.

| Convention | Count | Example | Looked up by |
|---|---|---|---|
| `<Zone>` (plain name) | 120 | `Batumi`, `SAM-Alpha`, `Hidden4`, `TankFactory` | `zone='Batumi'` in `ZoneCommander:new` (`setup:768`); the zone table of the mission is indexed by name in `buildZoneByName` (`zc2:203-207`). |
| `<Zone>-N` | 717 | `Kutaisi-1` … `Kutaisi-15` | Spawn sub-zones, enumerated from 1 until a number is missing (`zc2:27236-27244`, `zc2:10676-10680`); the parent is recovered by stripping `-%d+$` (`zc2:5778-5781`). |
| `<Zone>-sam-N` | 60 | `Kutaisi-sam-0` | Sub-zones reserved for SAM sites, matched by the lower-case prefix `<zone>-sam-` (`zc2:4725-4734`). |
| `<Zone>-land`, `<Zone>-land-N` | 107 | `Batumi-land-0` | Helicopter landing spots of a zone (`zc2:610`, `zc2:652`, `zc2:58355`, `zc2:66757`, `zc2:99457`). |
| `<Zone>-land-forced-N` | 2 | `Gelendzhik-land-forced-0` | Landing spots that take priority (`zc2:273`, `zc2:633`). |
| `<Zone>-road`, `<Zone>-road-N` | 23 | `Anapa-road-0` | Road hook points for convoys (`zc2:10989-10994`). |
| `<Zone>-wh` | 35 | `Alpha-wh` | Position hint of the logistics-centre warehouse building (`zc2:46249-46268`). |
| `<A>-<B>-Supply-N` | 87 | `Guso-Digora-Supply-1` | Ordered waypoints of a helicopter supply corridor between two zones, usable in both directions (`zc2:209-216`, `zc2:58128-58138`). |
| `<A>-<B>-Supply-Landing`, `<A>-<B>-Landing` | 8 | `India-Revari-Supply-Landing` | Landing point of that corridor (`zc2:58148-58156`); the names without `-Supply` (e.g. `Hurzuk-Tyra-Landing`) do not match this lookup and no other lookup was found in `zoneCommanderv2.lua`. |
| `Arty-<A>-<B>`, `Arty-<A>-<B>-N` | 24 | `Arty-Krymsk-Alpha-0` | Firing positions of artillery sorties from A against B, with a legacy fallback `Arty-<B>` (`zc2:10354-10361`). |
| `Scoot-N`, `Scoot-<x>` | 78 + 9 | `Scoot-12` | Shoot-and-scoot relocation zones of MANTIS, taken by the prefix `Scoot` (`zc2:111454-111455`, `zc2:111490`). |
| `CVN72_AREA_<X>` | 6 quads | `CVN72_AREA_SOCHI` | Carrier navigation areas (`zc2:13876-13880`, `setup:6018-6034`). |
| `CVN72_AREA_<X>-N` | 36 | `CVN72_AREA_BATUMI-1` | Points inside an area, `-1` and `-2` being read first (`zc2:13879-13880`). |
| `<Area>-N-Edge` | 28 | `Red Carrier-3-Edge` | Edge points of a sea area, matched by `^%d+%-edge$` after the base name (`zc2:1445-1462`); two zones are spelt `-2-Ed-ge` and `-4-E-dge` and so do not match. |
| `Hidden`, `HiddenN`, `HiddenN-M` | 10 + 68 | `Hidden4-12` | Ordinary zones and sub-zones; their zone is declared `NeutralAtStart` or `isHidden` in the setup (`setup:852-865`). |
| Scenery-bound quads | 13 | `SamDeltaWarehouse` | `SCENERY:FindByZoneName` in the setup (`setup:9343`). |
| `Trees-<Zone>`, `Tree-Mezmay` | 6 | `Trees-Guso` | No script lookup found; presumably the "Remove Trees" mission trigger (estimation). |
| `testing`, `testing air` | 2 | | Test spawn area (`setup:9940`). |

Of the 1 006 zones whose name ends in a number (corridor and carrier zones excluded), 917 have a radius under 200 m (443 under 50 m, 141 at 50-100 m, 118 at 100-150 m, 215 at 150-200 m), i.e. each one is a spot for one group.
The 89 campaign zones therefore cost about 1 100 hand-placed helper zones.

### Groups

The mission holds 880 groups and 1 851 units: 542 non-static groups (206 planes, 40 helicopters, 283 ground, 13 ships) and 338 statics.
Of the 542 non-static groups, 508 are late-activated; the other 34 are the client slots.
No group is flagged `uncontrolled`.
By coalition: red 626 groups (Russia 445, CJTF Red 181), blue 216 (USA 158, CJTF Blue 54, Germany 4), neutral 38 statics.
Every AI group is therefore a template that the scripts copy; nothing is alive at mission start except what the scripts spawn.

| Family (group name) | Count | Side | Used by |
|---|---|---|---|
| `RED_<TYPE>_<ROLE>_<LOADOUT>[_nSHIP]` | 92 | red | AI flight templates; the names are the keys of the Config check-lists (`Config:553-840`) and of the setup lists (`setup:1042-1220`); picked through the `template` set of a sortie (`zc2:60474-60490`). |
| `BLUE_<TYPE>_<ROLE>_<LOADOUT>[_nSHIP]` | 49 | blue | Same for Blue support and purchased flights. |
| `CAP_Template`, `DynamicCas_Template`, `DynamicSead_Template`, `DynamicBomber_Template`, `DynamicDecoy_Template`, `DynamicStructure_Template`, each with `_CW` and `_VT` variants, and `RED_*` twins | about 30 | both | Purchased flights (`zc2:105244`, `zc2:107935`, `zc2:108217`, `zc2:108673`, `zc2:109335`, `zc2:109698`, `zc2:110205-110213`; PvP twins `setup:3049`). |
| `Red SAM …`, `Red SAM SHORAD …`, `Red SAM AAA n`, `Red Armour Group n`, `Red Mech group n`, `Red Arty n`, `Enemy ground forces`, `… Vietnam n` | about 90 | red | Garrison templates named in `upgrades` and `RandomRedPool` (`setup:89-294`, `setup:594-651`); MANTIS takes its SAMs by the prefix `Red SAM` and its radars by `Red EWR` (`zc2:111399`). |
| names containing `Fixed` (`Red EWR Fixed 1`, `hiddenground-Fixed-n`, `Blue EWR Fixed Pvp-n`) | about 40 | both | A name containing `Fixed` takes the branch of `CustomZone:spawnGroup` that uses the group's own Mission Editor template instead of a sub-zone placement (`zc2:5220-5234`); `hidden` + `fixed` is a further class (`zc2:1011-1015`). |
| `Blue SAM HAWK`, `Blue SAM NASAMS`, `Blue Armor Modern`, `blueInfantry`, … | about 15 | blue | Blue garrison templates (`setup:95`, `setup:668-678`). |
| `AttackConvoy n`, `AttackConvoy CW n`, `SupplyConvoy n`, `ArtilleryConvoyShort n`, `ArtilleryConvoyLong n`, `GroundAttackConvoy n`, `InsurgentConvoy n` | about 25 | both | Surface sortie templates (`setup:1004-1040`). |
| `<Origin>-attack-<Target>-Arty` | 9 | red | Fixed artillery groups referenced by name in `GroupCommander:new` (`setup:1366`). |
| `CTLD_CARGO_*`, `CTLD_TROOPS_*`, `CTLD_CARGO_RED_*` | about 45 | both | CTLD cargo templates (`Foothold CTLD.lua:264-270`). |
| `evt-*`, `RedBomberEvent`, `EscortBomber`, `Maykop-Scuds`, `Kutaisi-Sead-Attack…`, `interceptor-n` | about 25 | red | Event groups looked up by literal name in the setup (`setup:6214`, `setup:6225-6249`, `setup:2515-2529`). |
| `<Zone>EscortGroup` | 4 | blue | Ground-escort convoys (`setup:2070`). |
| `AWACS_RED`, `AWACS_BLUE`, `AWACS_BLUE_SECONDARY`, `…_VT`, `Arco`, `Texaco`, `Shell`, `jtacDrone1/2`, `JTAC9lineam/fm`, `Escort1_Hornet` … | about 25 | both | Support aircraft by literal name (`zc2:9332-9335`, `zc2:13660`, `setup:4242-4244`). |
| `CVN-72`, `CVN-74`, `Tarawa`; `Molniya`, `Rezky`, `Grisha`, `Moskva`, `SpeedBoats`, `MissileBoat`, `FacLa`, `evt-shiptercept n` | 13 | both | Carriers activated by name (`setup:5986-5988`), red ships as garrison of the carrier zone (`setup:92`) and roaming prefixes (`setup:2878-2885`). |
| `CSAR_RED_INF_1/2` | 2 | red | Hostile infantry near a downed pilot (`zc2:97724`). |
| `Testing …` | 17 | red | Testing area (`setup:9941-9945`). |

The "about" counts come from grouping names by family in the script output, not from an exact pattern per row.

### Static objects

There are 338 static groups: 254 red and 38 neutral fortifications, 35 red heliports, 5 red statics of the warehouses category, 4 red static helicopters, and 2 blue ones (one of them `Zone supplies UH-1H`, a cargo).
The 35 heliports are the FARP zones: 20 of type `FARP` and 15 `SINGLE_HELIPAD`, each named exactly like its zone (`Alpha`, `Hady`, …), which is what `zones.<x>.airbaseName` points to (`setup:1254-1288`).
Around them, `FARP Tent` (98), `Windsock` (73), `FARP Fuel Depot` (35) and `FARP Ammo Dump Coating` (35) are named `Farp<zone>ammo`, `Farp<zone>fuel`, `Farp<zone>tent1..4`, `Farp<zone>command`, `Farp<zone>wind` and listed per zone in `airbaseStatics` (`setup:9899-9936`).
The remaining named statics are destructible objectives placed in garrison lists or industry zones: `Mineralnye HQ`, `Kobuleti Fuel Tank`, `Communication Tower`, `Tank Factory`, `MiningFacility Factory`, `SecretTechFacility HQ`, `Ammunition Storage n`, `InsurgentCamp` (`setup:102-109`, `setup:869-870`).

### Client slots and dynamic spawn

The 34 client groups are all on the Blue side and all carry `dynSpawnTemplate = true`: one group per aircraft type or variant (25 planes, 9 helicopters), including Red-built types (`MiG-29S`, `Su-25T`, `Su-27`, `Su-33`, `MiG-29 Fulcrum`, `JF-17`, `Mi-8MT`, `Mi-24P`, `Ka-50_3`).
There is no fixed slot per airbase: players spawn through DCS dynamic spawn, and these groups serve as per-type templates.
The Red coalition has no client group at all in this file.
In the `warehouses` file, all 21 airports have `dynamicSpawn = true`, `dynamicCargo = true`, `allowHotStart = true`, `unlimitedAircrafts = false`, `unlimitedMunitions = false`, `unlimitedFuel = true`; 19 are Red and 2 Blue at start.
Of the 46 non-airport warehouses (FARPs, ships and warehouse statics), 38 have dynamic spawn enabled with the same limited-stock settings, 5 are unlimited with dynamic spawn off, and 3 are special cases.
A warehouse lists 146 plane types and 28 helicopter types with `initialAmount = 10000`, and 800 weapon entries of which 786 are at 10 000, 9 at 100 and 5 at 0 (read on the first airport and the first warehouse only).
So "limited" stock with very large amounts is the authoring convention, and the manual forbids "unlimited" for a Cold War mission because the era lists would otherwise not apply (`manual p.5-6`).
Which zone a player may spawn at is decided at run time from zone ownership; see "Spawn handling and slot control" in `02-persistence-lifecycle-plumbing.md`.

### Options that matter

`requiredModules` is empty: the mission declares no mod.
`forcedOptions` (enforced on clients): `userMarks = true` (marker commands depend on it), `externalViews = true`, `labels = 0`, `optionsView = "optview_allies"`, `easyCommunication = false`, `radio = false`, `unrestrictedSATNAV = true`, `permitCrash = false`, `wakeTurbulence = false`, `birds = 0`, `civTraffic = ""`, `padlock = false`, `miniHUD = false`, `immortal = false`, `fuel = false`, `weapons = false`, `Supercarrier = { deck_crew = true, speakers_enabled = true }`.
Ground-control roles: Blue has 2 artillery commanders, 2 forward observers, 2 observers and 2 instructors; Red has 2 observers and 2 instructors; `isPilotControlVehicles = true`.
Date 31 October 2024, start time 36 000 s (10:00), cloud preset `Preset11`.
The briefing text is the same for both sides and starts with "The goal is to capture all zones".
Coalition composition: Blue 4 countries, Red 3, neutral 85.

## 5. The Foothold Config Manager

Read: `tools/FootholdConfigManager/README.md`, `CHANGELOG.md`, `Foothold Config.gui.json`, and the manual pages that describe the tool; the C# source was not read (its file names were listed, and one text search for `.miz.orig` was run).
It is a Windows desktop program built on .NET 8 (`FCM-README`), shipped as `Common Scripts/Foothold Config Manager 2.5.7.exe`.
Its state (preferences, instances, presets) lives in `Saved Games/Foothold Config Manager` (`FCM-README`).

| Function | What it does for the admin | Source |
|---|---|---|
| First-run wizard | Pick a `.miz`, pick a Saved Games profile, install the Normal or WW2 config into `Missions\Saves`, validate and open it; an existing config is not overwritten. | `manual p.5` |
| Config editor | Categories on the left, typed fields, check-lists, linked grids (available + price + rank in one grid), per-field help, Lua syntax validation, Undo, Restore Defaults, a comments view. | `manual p.9-10`, `FCM-CHANGELOG` |
| Metadata-driven UI | Labels, editors, valid values, visibility and lock conditions come from the `@gui` comments of the Config itself; `Foothold Config.gui.json` holds 15 further entries (label, help, choices) such as `FootholdLocale`, `CallsignOverrides`, `ShopPrices`. | `Config:246-247`, `gui.json` |
| Era switch | Choosing an era offers to tick the template rows tagged for that era and refreshes the aircraft and weapon lists; aircraft required by enabled AI features are protected and explained. | `manual p.7, 22`, `FCM-CHANGELOG` (2026-10-25) |
| Presets | Three named snapshots per instance and config type; switching validates and backs up the live config. | `manual p.8` |
| Instances | Several DCS profiles or server instances, each with its own config; copy settings from one to another; update matching config variants across instances. | `manual p.10`, `FCM-CHANGELOG` |
| Update Config | Merge a new release's config (from a `.miz` or a file) into the current one, choosing per changed default; timestamped backup, five kept; merge rule per table (`mergeRows`, `replaceTable`, `keepTable`). | `manual p.9`, `Config:1607` |
| MissionScripting panel | Shows the path of `MissionScripting.lua`, applies the desanitise edit, re-checks the status. | `manual p.4` |
| Mission download | Lists the maps of a release, downloads the full missions into a chosen instance or a remembered custom folder, with a review of every output file name. | `manual p.27-29`, `FCM-CHANGELOG` (2026-11-05) |
| Files-only update | For missions verified compatible with the release, creates a copy with only the script files replaced, keeping the mission's own edits, warehouse and weather; several variants (day, night…) at once. | `manual p.25-26` |
| Warehouse copy | During a full download, copies the warehouse file of an older mission of the same map, including modded stock. | `manual p.28` |
| Weather and time profiles | Saved weather, date and time profiles applied to the created missions, with profile-based file names; settings can be read from another `.miz`. | `manual p.28`, file names `Weather*.cs` |
| Mission options | Applies prepared mission-option settings to the downloaded missions. | `manual p.28` |
| DCSServerBot support | Reads `.miz.orig` backups from discovered `.dcssb` folders as update sources and can save the result as a DCSServerBot original (`.miz.orig`). | `FCM-CHANGELOG` ("updating missions from DCSServerBot backups"), UI strings at `MainForm.MissionDownloads.Files.cs:904` and `MainForm.MissionDownloads.Review.cs:143` |
| Server list | For a verified dedicated-server instance, adds the created missions to the server mission list (running or stopped); does not start or load anything. | `manual p.28-29` |
| Self-update | Checks for a newer Manager and for mission releases separately. | `manual p.25` |
| Admin designer and user export | A password-protected designer can export a "user" executable with selected GUI settings; a Testing unlock shows the testing settings. | `FCM-README` |
| Command line | `--check <config>`, `--audit <config> <log>`, `--self-test-stability`, `--self-test-merge`. | `FCM-README` |

The manual tells admins to use this tool and not to edit the `.miz` or move the config by hand (`manual p.4`).

## 6. Operating Foothold on a server

### What the server needs

`MissionScripting.lua` must be desanitised so that `io` and `lfs` are available, and this must be redone after every DCS update (`manual p.4`).
Without `io` the engine prints `PERSISTENCE_SAVE_DISABLED` for 600 s and stops trying to save (`zc2:7136-7140`); without `lfs` it prints `PERSISTENCE_SAVE_DESANITIZE` and loads nothing (`zc2:7252-7258`).
The Config loader also uses `lfs.writedir()` and `loadfile` to find the external config (`Config:1`, `Config:153-155`).
The engine source has 4 `io.open`, 8 `lfs.` references and no `os.remove` (regex counts on `zoneCommanderv2.lua`), and a campaign reset is done by writing an empty table, not by deleting a file (`setup:2805-2806`).
The mission must be hosted as a multiplayer server even for one player, because slots are dynamic spawn (`manual p.4`).
No mod is required (`requiredModules` empty in `mission`); mods are an option handled by `AllowMods` and a warehouse edit (`manual p.24`).
The manual recommends disabling Tacview on the server for performance (`manual p.4`).

### Files on the server

Everything is under `Saved Games\<profile>\Missions\Saves`: `Foothold Config.lua` (and `Foothold Config WW2.lua`), the campaign save `<FootholdSaveBaseName>.lua`, the rank file `Foothold_Ranks.lua` shared by all campaigns (`setup:756`), and the CTLD, warehouse and other saves listed in "Save folder inventory" of `02-persistence-lifecycle-plumbing.md`.
One campaign save exists per map, era and mode: on Caucasus `FootHold_CA_v0.3`, `FootHold_CA_v0.3_Coldwar`, `FootHold_CA_v0.3_Vietnam`, each with a `Pvp` suffix in PvP (`setup:467-477`).
The save name does not contain the mission version (the mission is 6.5.2, the save name says `v0.3`), so a new release of the mission picks up the existing campaign.

### Reset and restart

On victory or defeat with `AutoRestart`, the setup writes an empty `zonePersistance` table, calls `resetSaveFileAndFarp`, and raises flag 181 five seconds later, which fires the `a_end_mission` trigger (`setup:2803-2812`, `mission` rule 7).
With `AutoRestart = false`, Blue gets a "restart and reset" menu with Yes and No instead (`setup:2813-2828`).
An admin can force the same with the `restartMission` and `endMission` marker words (`Config:3508-3513`).
What the server loads next is the server's own mission-list business: "Restart requests the mission restart flag; it does not itself choose a different MIZ" (`manual p.62`).
The rank file is never reset (`manual p.23`).

### Updating without losing progress

Progress survives an update because it lives outside the `.miz`, under save names that do not change between releases.
Three update paths exist, all through the Config Manager (§5): files-only update of the admin's own `.miz` (keeps edits, warehouse, weather), full download with optional warehouse copy, and config merge ("Update from MIZ").
An external config that lacks settings added by a new release still loads: the missing ones take the internal defaults and a warning is shown 12 times (`Config:94-135`).
Garrison templates renamed between releases are mapped by `BlueUpgradeTemplateMigration` (`setup:20-50`).

### `MizBatchUpdater.exe` and `MizFileReplacer.exe`

Both exist only as binaries in `tools/` (199 kB and 173 kB).
Neither the repository `README.md`, nor the manual, nor the Config Manager `README.md` and `CHANGELOG.md` mention them (0 text matches in each).
The only mention is in `THIRD_PARTY_NOTICES.md`, which lists "the authorship, dependency notices and corresponding source" of the two executables among the items whose provenance was not established.
From their names they replace script files inside one or several `.miz` archives, which is what the Config Manager's files-only update does (estimation; nothing was executed or disassembled).

### Supported maps, eras and modes

The release ships 11 mission files: Afghanistan, Caucasus, Germany Cold War, Iraq, Kola, Persian Gulf, South Atlantic (version 0.83), Sinai North, Sinai extended, Syria extended, and WWII Normandy (`Missions/`).
The `README` lists nine supported theatres (Caucasus, Persian Gulf, Sinai, Syria, Cold War Germany, Kola, Iraq, Afghanistan, WWII Normandy); South Atlantic is shipped but not in that list.
One `.miz` per map serves every era: the file name says `Coldwar-Modern-Vietnam` (Iraq: `Gulfwar_Modern_Vietnam`) and the era is the `Era` setting, which swaps template names and warehouse lists at load (`Config:198`, `setup:487-591`).
The mission date is the exception: it has to be changed in the Mission Editor (`manual p.7`).
There is no separate PvP mission file: PvP is the `PvP` setting, honoured only on Caucasus, Syria and Persian Gulf (`Config:3525`, `manual p.56`), with its own save name.
Normandy is a separate line: its own config file, a setup file with 35 % of its lines in common with Caucasus, and `zeus_Full_v2.1.lua` embedded instead of `Zeus.lua` (`THIRD_PARTY_NOTICES.md`).

### Localisation

`Foothold_Localization.lua` (38 857 lines) defines ten locales: EN, DE, FR, ES, RU, PT-BR, TR, IT, zh-CN, zh-TW (`Config:204-219`).
The server language is the `FootholdLocale` setting, applied by `FootholdLocalization:SetLocale` right after the config is read (`Config:220-223`, `Foothold_Localization.lua:20831`); an unknown value falls back to the default locale (`Foothold_Localization.lua:20823-20829`).
It governs global on-screen messages; each player can pick another language for their own menus and messages, and that choice is saved with the campaign (`zc2:25741-25742`).
The setup file contains no player-facing text, only keys (699 localisation call sites), so a new map also means new keys in the localisation file for every zone flavour text, mission title and event message (`setup:297-300`, `setup:6197-6199`).
Details in "Messages and localisation" of `02-persistence-lifecycle-plumbing.md`.

## Authoring cost of one map

Measured on Caucasus (v6.5.2 mission, v6.5.3 scripts); everything below is maintained by hand in the Mission Editor or in a text editor.

| Item | Size |
|---|---|
| Setup file | 10 014 lines, of which roughly 2 500 are map data and the rest is code copied from map to map (62 to 74 % of the lines of the other modern setup files are identical to Caucasus lines) |
| Zones declared | 89 (21 airbases, 35 FARPs, 1 carrier, 32 others) |
| Named garrison lists | 49, plus 14 random size profiles and a pool of 46 Red and 9 Blue template names |
| Waypoint numbers and flavour texts | 61 and about 75 |
| Airbase bindings | 56 |
| Sortie declarations | 409 (402 `DirectorCapability` + 7 `GroupCommander`) in 56 blocks |
| Connections | 135 visible + 14 hidden |
| Director theatre data | 9 areas, 9 infrastructure links |
| Shop | 45 registered item ids, 54 shelved ids, 76 shelf lines |
| Events and tracked missions | 17 and 44 |
| Scripted zone triggers | 31 |
| Mode and era branches in the setup | 262 PvP references, 90 era tests |
| Localisation call sites in the setup | 699 |
| Trigger zones in the `.miz` | 1 331 (120 plain names, 717 spawn sub-zones, 109 landing spots, 60 SAM spots, 87 corridor waypoints, 87 scoot zones, 70 carrier-area zones, 35 warehouse hints, 24 artillery positions, 23 road hooks, 8 corridor landings) |
| Template groups in the `.miz` | 508 late-activated groups (181 planes, 31 helicopters, 283 ground, 13 ships), among them 141 `RED_` / `BLUE_` flight loadouts |
| Client slot templates | 34 |
| Statics | 338 (35 FARP pads with about 240 decor statics, plus named objectives) |
| Warehouses | 21 airports + 46 others, each with 174 aircraft rows and 800 weapon rows |
| Sound files | 55 |
| Mission triggers | 7 |
| Config check-list rows naming `.miz` templates | 129 flight templates + 14 SAM families, to keep in step with the `.miz` |

The same mission file must also stay consistent across three eras: garrison and convoy templates exist in Modern, Cold War and Vietnam variants (`setup:487-591`, `setup:1004-1040`).

## Seen outside this theme

- `BlueUpgradeTemplateMigration`: a rename table applied to saved garrison names, i.e. a save-format migration living in the setup file (`setup:20-50`).
- `DynamicHybridConfig` and `bc:startDynamicHybridFiller`: generation of sortie capabilities at run time from distance rules, on top of the hand-written ones (`setup:6077-6118`, `zc2:23020`).
- `TheaterInfrastructure`: a destroyed map building cuts the Red supply route of a SAM zone (`setup:2271-2360`, `setup:1291`).
- `bc:roamGroupsToLocalSubZone`: patrol of garrison groups between sub-zones and roaming of ships, driven by name prefixes (`setup:2848-2886`).
- `HercCargoDropSupply.init(bc)`, `startWarehousePersistence()`, `Frontline.BuildFromZones` and seven caches are started explicitly by the setup file, not by the engine (`setup:6000-6013`).
- Kola variant: the starting side of whole countries comes from saved flags, and a `DynCampaign` flag changes the save name (`kola:745-820`).
- `ewrs_altitudeDisplayMode = "wwii"`: EWRS reports altitude bands on Normandy (`ConfigWW2:813`).
- `AddWeightToPlaneRed` / `AddWeightToPlaneBlue`: extra internal cargo weight applied to WWII aircraft types (`ConfigWW2:422-445`).
