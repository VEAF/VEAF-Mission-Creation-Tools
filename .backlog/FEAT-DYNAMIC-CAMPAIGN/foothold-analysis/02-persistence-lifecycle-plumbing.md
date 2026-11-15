# 02 — Persistence, campaign lifecycle, player handling and engine plumbing (Foothold v6.5.3)

Source: upstream tag v6.5.3 (commit 27d8cf4a), files under `Common Scripts/`, `Setup files/` and the Caucasus `.miz`.
Short file names are used in citations: `zoneCommanderv2.lua` is the engine, `Config` is `Foothold Config.lua`, `Setup` is `MA_Setup_CAv2.lua`, `mission` is the `mission` file inside `Foothold_CA_6.5.2_Coldwar-Modern-Vietnam.miz`.

## Feature list

| Feature | One-line description | Main code location |
|---|---|---|
| Script load order | Four mission triggers load 12 Lua files in a fixed order | `mission:53-93`, `mission:276347-276560` |
| External config override | A `Foothold Config.lua` in `Saved Games\...\Missions\Saves` overrides the one in the `.miz` | `Config:1-186`, `Config:3517-3526` |
| Lua table serialiser | Every save file is a Lua chunk assigning one global table | `zoneCommanderv2.lua:7108-7275` |
| Campaign save (`zonePersistance`) | Zones, garrisons, credits, shop stock, AI groups, Director memory, tankers, carriers | `zoneCommanderv2.lua:25176-25855`, `44529-44579` |
| Staged autosave | Save every 60 s, collected 8 zones per 0.1 s then serialised in a coroutine | `zoneCommanderv2.lua:30328-30330`, `44410-44527` |
| Campaign load and re-apply | `bc:loadFromDisk()` then deferred restores | `zoneCommanderv2.lua:44601-45960`, `Setup:5835` |
| Save folder inventory | Eight files under `Missions\Saves`, one set per map, era and mode | `Setup:467-485`, `Foothold CTLD.lua:8105-8108` |
| Warehouse persistence | Weapon stock of airbases and FARPs in a CSV, one airbase per second | `zoneCommanderv2.lua:111502-112315` |
| Rank and player file | Per-UCID credits, career and settings, shared by all campaigns | `zoneCommanderv2.lua:43358-43419`, `44332-44378` |
| End, reset and restart | Victory/defeat detection, save wipe, flag 181 → `a_end_mission` | `Setup:2732-2849`, `zoneCommanderv2.lua:28111-28147`, `mission:63` |
| Era and PvE/PvP switches | Two config globals select templates, lists and the save name | `Config:196-202`, `Setup:440-477` |
| Player identification | Name at runtime, UCID on disk, alias and legacy handling | `zoneCommanderv2.lua:43685-43779` |
| Spawn handling and slot control | Airbase coalition, per-group user flags, birth-event rejection | `zoneCommanderv2.lua:101412-101500`, `51745-51747`, `56753-56767` |
| Takeoff, landing, ejection tracking | One world event handler feeding rewards, career and CSAR | `zoneCommanderv2.lua:42893-43106` |
| Friendly fire | Message, career counter and rank-credit penalty | `zoneCommanderv2.lua:42641-42670` |
| Map-marker commands | Player and admin commands typed in F10 markers, no admin list | `zoneCommanderv2.lua:28354-29253` |
| Main loops and timers | 10 s zone wave staggered at 0.1 s per zone, queues with budgets, watchdog | `zoneCommanderv2.lua:30226-30338`, `43235-43346` |
| Event handling | Three raw handlers, polling for zone state, few Moose sets | `zoneCommanderv2.lua:30228-30232`, `42893` |
| F10 menu management | Raw `missionCommands`, per-group handles, debounced refresh queues | `zoneCommanderv2.lua:17272-17317`, `40469-40500` |
| Messages and localisation | 10 locales, server / player / group scopes, key lookup with EN fallback | `Foothold_Localization.lua:20814-21049` |
| Moose dependency census | Class-by-class call counts for the engine and satellite scripts | section at the end |

## Script load order in the `.miz`

**Mission-maker view.**
The Caucasus mission has seven trigger rules (`mission:276347-276560`, compiled form at `mission:53-93`).
Rule 1 "Remove Trees" (mission start) removes scenery objects in 12 zones (`mission:57`).
Rule 2 "ScriptLoader 1" (mission start, no condition) loads three files in this order: `Moose_2026-10-11.lua`, `Foothold_Localization.lua`, `Foothold Config.lua` (`mission:58`, resource keys resolved in `l10n/DEFAULT/mapResource:11,65,63`).
Rule 3 (mission start, no condition) loads `zoneCommanderv2.lua`, `EWRS.lua`, `MA_Setup_CAv2.lua`, `WelcomeMessage.lua` (`mission:59`, `mapResource:38,54,28,10`).
Rule 4 "ScriptLoader 3" (once, `c_time_after(3)`) loads `Zeus.lua`, `Foothold CTLD.lua`, `Foothold_CTLD_Red.lua`, `Splash_Damage_3.4.1_leka.lua` (`mission:60,89`, `mapResource:70,31,36,7`).
Rule 5 "AIEN" (once, `c_time_after(12)`) loads `AIEN.lua` (`mission:61,90`, `mapResource:3`).
Rule 6 "Sounds" (mission start) plays every `.ogg` once to coalition group 41 so the files are embedded in the `.miz` (`mission:62`) (purpose is an estimation; the action list is read).
Rule 7 (once, `c_flag_is_true("181")`) runs `a_end_mission("blue", "", 0)` (`mission:63,92`): this is the only restart mechanism of the mission itself.

| Order | File | Role |
|---|---|---|
| 1 | `Moose_2026-10-11.lua` | The Moose framework, bundled |
| 2 | `Foothold_Localization.lua` | String tables for 10 locales and the `L10N`/`FootholdLocalization` lookup object |
| 3 | `Foothold Config.lua` | Server settings; may replace itself by the copy in the Saves folder |
| 4 | `zoneCommanderv2.lua` | The engine (classes only; nothing starts until the setup file runs) |
| 5 | `EWRS.lua` | Early-warning radar text reports for players |
| 6 | `MA_Setup_CAv2.lua` | Campaign data for the map; creates `bc`, zones, shop, calls `bc:loadFromDisk()` and `bc:init()` |
| 7 | `WelcomeMessage.lua` | Welcome text and per-player briefing on spawn |
| 8 | `Zeus.lua` | Map-marker spawn/destroy commands for game masters |
| 9 | `Foothold CTLD.lua` | Blue logistics on Moose CTLD/CSAR |
| 10 | `Foothold_CTLD_Red.lua` | Red-side CTLD (PvP) |
| 11 | `Splash_Damage_3.4.1_leka.lua` | Blast-damage script |
| 12 | `AIEN.lua` | Ground AI reaction script, 12 s after start |

**Reproduction notes.**
The order encodes dependencies: the config needs `UTILS.CheckFileExists` and `SCHEDULER` from Moose and `FootholdLocalization` (`Config:132,152,165-168`), the setup file needs the engine classes, and CTLD is loaded 3 s later so that `bc` and the zones exist.
No script is loaded with `dofile` from disk except the external config, so the mission runs from the `.miz` alone.

## External config override (`Foothold Config.lua` in the Saves folder)

**Admin view.**
If `<Saved Games>\<DCS>\Missions\Saves\Foothold Config.lua` exists, it is used instead of the copy embedded in the `.miz`, and the message "Loaded Foothold Config.lua externally." is shown for 30 s one second after start (`Config:1-6`, `Config:150-159`, `Config:3517-3523`).
On the Normandy map the file name is `Foothold Config WW2.lua` and the base file is read from `l10n/DEFAULT/` (`Config:2-6`, `Config:161-180`).
If the external file has a syntax error, "FOOTHOLD CONFIG ERROR: Foothold config did not load correctly, Check syntax." repeats every 30 s (`Config:138-148`).
If the external file is older than the mission and misses settings, the embedded defaults are kept for those, a warning lists them in `dcs.log`, and an on-screen warning repeats 12 times every 10 s (`Config:94-136`).
A companion Windows tool, `Foothold Config Manager 2.5.7.exe`, edits that file; the `-- @gui ...` comments in the config are its annotations (`Config:201`, `Config:490`).

**Mechanism.**
The embedded config runs first as a normal chunk and sets every global to its default.
At its top it only *compiles* the external file with `loadfile` (`Config:150-159`); at its very end it *executes* the compiled chunk, so external values overwrite the defaults already set (`Config:3517-3523`).
The external chunk runs under `setfenv` with a proxy environment whose `__newindex` records which globals it assigned (`Config:104-114`).
After it ran, each name in `FootholdConfigTrackedTableNames` (64 tables, `Config:9-74`) whose value is still the embedded table object, and each name in `FootholdConfigTrackedScalarNames` (18 scalars, `Config:76-95`) not assigned, is reported as missing (`Config:116-127`).
Tables are replaced whole, not merged; the "missing" check is by object identity (`Config:118`).
`PvP` is forced to `false` on any map other than Caucasus, Syria and Persian Gulf (`Config:3525`).
Requires `lfs` (for `lfs.writedir`) and `loadfile`, so `MissionScripting.lua` must be desanitised; without `lfs`, `savePath` is `nil` and the embedded config is used silently (`Config:1`, `Config:150`).
Moose use: `UTILS.CheckFileExists` (wraps `lfs.attributes`/`io.open`) and `SCHEDULER:New` for the delayed messages (`Config:132,150`).

## Lua table serialiser (`Utils.saveTable` / `Utils.loadTable`)

**Mechanism.**
A save file is Lua source: `<var> = {}` then one assignment per top-level key, `<var>["key"] = <literal>` (`zoneCommanderv2.lua:7140-7183`).
`Utils.serializeValue` emits numbers and booleans with `tostring`, strings with `%q`, and tables recursively with two-space indentation; functions and userdata are silently dropped (`zoneCommanderv2.lua:7214-7249`).
For the campaign file, the `zones` key is written one zone per statement so a zone can be re-serialised alone if it changed during a staged save (`zoneCommanderv2.lua:7142-7153`, `7185-7191`).
For the rank file, each player record is written with `name`, `lastSeen`, `credits` first (`zoneCommanderv2.lua:7154-7175`).
The whole text is built in memory with `table.concat` and written by one `io.open(filename, "w")`/`write`/`close`; there is no temp file or rename, so a crash during the write truncates the save (`zoneCommanderv2.lua:7196-7201`).
`Utils.loadTable` checks `lfs.attributes(filename)`, then `loadfile(filename)()`, which defines the global (`zonePersistance`, `RankSave`, …) (`zoneCommanderv2.lua:7251-7261`).
If the file does not compile, it is re-read line by line, lines whose key contains a slash or backslash are dropped, and the rest is run with `loadstring` — a repair for old saves with path-like keys (`zoneCommanderv2.lua:7263-7272`).
If `io` is absent on save, the message `PERSISTENCE_SAVE_DISABLED` is shown for 600 s once and saving is turned off (`Utils.canAccessFS = false`); if `lfs` is absent on load, `PERSISTENCE_SAVE_DESANITIZE` is shown (`zoneCommanderv2.lua:7132-7138`, `7252-7257`).
Desanitisation needed: `io` (open/write/read) and `lfs` (`writedir`, `mkdir`, `attributes`); `os` is not required by the serialiser (`zoneCommanderv2.lua:7128-7272`).

**Reproduction notes.**
The loader executes the save file as code in the mission environment, so the file must be trusted.
A global write-generation counter (`Utils.zonePersistenceWriteGeneration`) is incremented by every synchronous campaign write and lets a running staged save detect that it is stale (`zoneCommanderv2.lua:7109`, `7129-7131`, `7204-7207`, `44458-44464`).

## Files written under `Saved Games\<DCS>\Missions\Saves`

**Admin view.**
All files live in `lfs.writedir()..'Missions/Saves'` (`Setup:479-485`), created with `lfs.mkdir` if missing (`Setup:482`).
`<base>` is `FootholdSaveBaseName`, set per map and era by the setup file: `FootHold_CA_v0.3`, `FootHold_CA_v0.3_Coldwar`, `FootHold_CA_v0.3_Vietnam`, with `Pvp` appended in PvP mode (`Setup:467-477`).
Each era and each mode therefore has its own campaign; only the rank file is shared.

| File | Format | Writer and period | Content |
|---|---|---|---|
| `<base>.lua` | Lua chunk, global `zonePersistance` | staged autosave, first at 30 s then every 60 s (`zoneCommanderv2.lua:30328-30330`) | the campaign (see next section) |
| `Foothold_Ranks.lua` | Lua chunk, global `RankSave` | same job as the campaign save, only if `RankingSystem == true` (`zoneCommanderv2.lua:44356-44378`, `44532-44534`) | per-UCID player records, shared by all maps and eras (`Setup:756`) |
| `<base>_storage.csv` | `AIRBASE;KIND;NAME;QTY` rows | every 300 s, first at 30 s, one airbase per second (`zoneCommanderv2.lua:112302-112315`, `112004-112052`) | weapon stock of every zone airbase and CTLD FARP |
| `<base>_CTLD_Save.csv` | Moose CTLD save format | Moose CTLD autosave every 300 s (`Foothold CTLD.lua:8105-8108`) | CTLD-built ground groups and dropped troops |
| `<base>_CTLD_Red_Save.csv` | same | same, red CTLD instance (`Foothold_CTLD_Red.lua:2283-2286`) | red CTLD units (PvP) |
| `<base>_CTLD_FARPS.csv` | `seq;name;x;y;zell;lat;lon;supplyStock;` rows after a header line | `TIMER` first at 30 s then every 300 s (`Foothold CTLD.lua:7611`, `7690-7708`, `8101-8103`) | player-built FARPs |
| `foothold.status` | one line: path of the campaign file | after every campaign save (`zoneCommanderv2.lua:44557-44568`) | pointer for external tools ("SITAC") |
| `Foothold Config.lua` | Lua | read only | external config (previous section) |

Other writes outside this folder: `AIEN.lua` writes a log under `Logs\` (`AIEN.lua:9117-9118`).
Desanitisation: the engine needs `io` and `lfs`; no `os.` call was found by grep in `zoneCommanderv2.lua`.
Wall-clock time for the `lastSeen` field of rank records comes from LuaSocket `socket.gettime()` if a `socket` global or `package.loaded.socket` exists, otherwise `lastSeen` is not updated (`zoneCommanderv2.lua:43666-43683`).
A `require("socket")` exists at `zoneCommanderv2.lua:48459`, inside `fhEnsureCampaignSeed()`, which seeds the engine's own random generator once per session (`zoneCommanderv2.lua:48449-48475`).
It is guarded by `if package and require`, so it only runs when `require` is desanitised; it then extends `package.path`/`package.cpath` with `.\LuaSocket\` and uses `socket.gettime()` in microseconds as the seed.
Without it the seed is built from the mission date, `env.mission.start_time`, `timer.getAbsTime()` and `timer.getTime()` (`zoneCommanderv2.lua:48465-48475`).
`net.get_player_list`, `net.get_name` and `net.get_player_info` are called from the mission scripting environment (`zoneCommanderv2.lua:41170-41195`, `43698-43708`, `43789-43795`).

## Campaign save: what is in `zonePersistance`

**Top-level keys** (built by `_newPersistenceState`, `_collectPersistenceZoneState`, `_collectPersistenceZoneCommanders`, `_finalizePersistenceState`, `_writePersistenceState`):

| Key | Content | Code |
|---|---|---|
| `zones[zoneName]` | per-zone record, detailed below | `zoneCommanderv2.lua:25276-25320` |
| `accounts` | coalition credit balances | `zoneCommanderv2.lua:25717` |
| `shops[side][id].stock` | remaining stock of every shop item whose stock is not unlimited (-1) | `zoneCommanderv2.lua:25719-25728` |
| `playerStats` (by UCID), `legacyPlayerStats` (by name), `playerStatsIdentityVersion`, `ucidToName` | campaign statistics per player | `zoneCommanderv2.lua:25731-25734` |
| `ewrsSettings`, `selfJtacSettings` (+ `legacy…`), `settingsIdentityVersion` | per-player EWRS and self-JTAC preferences; dropped from this file when the rank file stored them | `zoneCommanderv2.lua:25735-25740`, `44535-44546` |
| `playerLocales` | language chosen by each player | `zoneCommanderv2.lua:25741-25743` |
| `zonesDetails[zoneName]` | `flavorText`, `hidden` — exported for external tools | `zoneCommanderv2.lua:25745-25761` |
| `missions` | title, description, `isRunning`, `isEscortMission` of active missions — exported for external tools | `zoneCommanderv2.lua:25764-25778`, `44486-44500` |
| `connections` | `from`/`to` pairs of the zone graph — exported for external tools | `zoneCommanderv2.lua:25781-25793` |
| `players` | last known player positions (`bc.playersState`) | `zoneCommanderv2.lua:25796-25802` |
| `ejectedPilots` | downed pilots awaiting CSAR: player, lost credits, coalition, lat/long/alt, timestamp | `zoneCommanderv2.lua:25804-25815`, parsed back at `44890-44928` |
| `tankers` | `arco` and `texaco`: unlocked, x/y/z, heading, leg, zone, speed (per side in PvP) | `zoneCommanderv2.lua:25817-25859` |
| `awacsLost` | PvP only, four booleans | `zoneCommanderv2.lua:25845-25847` |
| `carrierNavigation` | carrier group station/lane state | `zoneCommanderv2.lua:25860-25863`, `15298-15317` |
| `runwayPlaneSpawnBlocks[zoneName]` | remaining seconds a cratered runway blocks AI plane spawns | `zoneCommanderv2.lua:25864` |
| `redMassAttackMission` | state of a red mass attack in progress (PvE) | `zoneCommanderv2.lua:25866-25869` |
| `director`, `blueDirector`, `blueAreaCommitment` | Director memory: state, front memory, strategy, air posture, intelligence, cooldown remainders, decision histories, outcomes | `zoneCommanderv2.lua:25875-25886`, `92448-93027` |
| `airAiPersistence` | `inair[groupName]` and `spawnNowTakeoff[]` records of AI flights | `zoneCommanderv2.lua:25563-25640` |
| `surfaceAiPersistence` | `active[groupName]` records of convoys and ships en route or at destination | `zoneCommanderv2.lua:25641-25691` |
| `suspendedGciStateVersion` | schema version of the suspended-zone radar state | `zoneCommanderv2.lua:25697` |
| `customFlags` | free key/value table `CustomFlags` used by setup files for one-off campaign events | `zoneCommanderv2.lua:44530` |
| `globalExtraUnlock` | shop unlock flag (per side in PvP) | `zoneCommanderv2.lua:44531` |

`zonePersistance.difficultyModifier` is read on load (`zoneCommanderv2.lua:45690-45695`) but **nothing writes it** in v6.5.3: a grep of every `.lua` file of the extract finds the name only at its class default (`11997`), in `increaseDifficulty`/`decreaseDifficulty` (`19253-19265`) and in that load branch.
None of the persistence builders (`25176-25886`, `44529-44552`) puts it in the state, so the load branch is a leftover that never fires on a save produced by this version.
The value itself is also inert on Caucasus: it only moves when `bc.difficulty` exists, and the setup file calls `BattleCommander:new(filepath, 10, 60)` without the fourth `difficulty` argument (`Setup:754`, `zoneCommanderv2.lua:17082`, `17120`); see `04-director.md` section 15.

**Per-zone record** (`zoneCommanderv2.lua:25276-25320`, `25357-25400`):
`side`; `level` (number of built groups); `remainingUnits[slot]` = list of type names of the units still alive in each garrison group (life ≥ 1); `remainingUnitNames[slot]` for "Fixed" hand-placed groups (exact unit names); `spawnSubZones[slot]` (which sub-zone each group was placed in); `samMfdReveals`; `suspended`, `idleSuspended`, `suspendedLossesVersion`; `destroyed` (critical static objects destroyed); `active`; `isAwaken` (pop-up zones); `triggers[id] = hasRun`; `firstCaptureByRed`; `advanceCaptureThresholdArmed`; `upgradesUsed`, `upgradesUsedRed`, `upgradesUsedBlue`; `surrenderEvaluatedTier`; `extraUpgrade[] = {side, name}` (shop-bought groups); `lat_long`; `logisticCenter`; `warehouseFacility`; the regular-supply counters (`regularSupplyReady`, `…ExpeditedReady`, `…Progress`, `…Efficiency`, `…StockSide`, `…LossDelays`, `…LocalRecoveryJobs` with remaining seconds); `pendingCapture`; `captureObjectTombstones`; `randomUpgradesRed`, `randomUpgradesBlue` (the garrison template names drawn for this campaign); `retiredStaticUpgrades`.
For a suspended zone (units despawned) the survivor lists come from a snapshot taken at suspension, not from live groups (`zoneCommanderv2.lua:25190-25200`).

**Per AI flight record** (`zoneCommanderv2.lua:25441-25509`, `25609-25630`): group name, Director capability ids, origin and target zones, side, mission and mission type, template set and template name, CAP holding point, supply flags, then `position {x,y,z}`, `headingDeg`, `aliveCount`, `lastStateDuration`, and `capReturnHome`/`airReturnHome` when the flight has no weapon left for its mission (checked with `Unit.getAmmo`).
Fixed-wing flights are saved only if at least one unit is airborne (`zoneCommanderv2.lua:25618`).

**Per surface group record** (`zoneCommanderv2.lua:25510-25562`, `25672-25687`): same identity fields plus `aliveUnitTypes`, `savedState` (`enroute`/`atdestination`), `passedRoadExit`, artillery flags.

**What is not in the file.**
Player aircraft, weapons in flight, and AI flights on the ground other than those in state `takeoff` are not saved (`zoneCommanderv2.lua:25567-25572`).
Garrison unit positions and damage are not saved: only the list of surviving type names per group (`zoneCommanderv2.lua:25203-25219`).

## Staged autosave (6.4.8 design)

**Mechanism.**
One Moose `SCHEDULER` calls `requestStagedSaveToDisk()` first at 30 s then every `saveFrequency` = 60 s (`zoneCommanderv2.lua:30328-30330`, `Setup:754`).
A comment forbids event-triggered writes: events only update memory (`zoneCommanderv2.lua:30328-30329`).
The request creates a job and a second `SCHEDULER` ticking every 0.1 s (`persistenceSaveBatchInterval`) (`zoneCommanderv2.lua:44433-44447`, `17124-17126`).
Phase `collect`: each tick collects 8 zones (`persistenceSaveBatchSize`), both the zone record and its AI groups (`zoneCommanderv2.lua:44466-44479`).
Phase `finalize`: the rest runs inside a Lua coroutine that yields after every 8 serialised records or 32 768 bytes of text, or at forced checkpoints, and is resumed once per 0.1 s tick (`zoneCommanderv2.lua:44481-44517`).
Inside the coroutine: `_finalizePersistenceState` (accounts, shops, players, Director export), then the rank file, then the campaign file (`zoneCommanderv2.lua:44509-44516`, `44529-44552`).
The final `io.open`/`write` of each file is a single blocking call (`zoneCommanderv2.lua:7196-7201`).
If a new request arrives while a job runs, it is ignored unless the job has not ticked for 5 s, in which case the job is discarded and replaced (`zoneCommanderv2.lua:44411-44428`).
If a synchronous campaign write happened meanwhile (generation counter changed) or a campaign reset is pending, the job is cancelled (`zoneCommanderv2.lua:44458-44464`).
A zone flagged dirty while the coroutine is serialising is re-serialised before the write: the serialiser keeps, per zone, the index of its text chunk in `saveJob.zoneParts.indices` and a `dirty` set, and rewrites the dirty chunks just before `table.concat` (`zoneCommanderv2.lua:7144-7154`, `7188-7194`).
The only code that sets a zone dirty is `ZoneCommander:_requestSurrenderPersistenceRefresh()`: if a non-rank-only job is running and already collected this zone, it re-collects the zone record into the job's state and, if the zone chunk was already serialised, marks it dirty (`zoneCommanderv2.lua:45984-45992`).
Its single caller is the zone-surrender evaluation, when the zone's `surrenderEvaluatedTier` changes (`zoneCommanderv2.lua:56011`).
So the "dirty" mechanism protects one field only, the surrender tier (the reason, avoiding a second surrender roll after a restart, is an estimation); every other change made during a staged save simply waits for the next save.
When the job ends, a completion callback writes the warehouse CSV (only when `WarehouseLogistics == false`) and the `foothold.status` pointer file (`zoneCommanderv2.lua:44553-44575`).
A synchronous variant `saveToDisk()` builds the whole state in one call (`zoneCommanderv2.lua:44577-44579`, `25701-25709`).

**Reproduction notes.**
The cost being spread is twofold: `Group.getByName`/`getUnits`/`getLife`/`getDesc` over every garrison unit of every zone (`zoneCommanderv2.lua:25203-25212`), and string building.
The state is not a consistent snapshot: zones are read over several seconds while the game runs.
The design depends on `coroutine` being available in the mission environment and on Moose `SCHEDULER` treating a `nil` return as "continue" and `false` as "stop" (`zoneCommanderv2.lua:44478`, `44526`).

## Campaign load and re-application at start

**Sequence** (setup file, at mission start, one synchronous pass):

1. `BattleCommander:new(filepath, 10, 60)` then all zones, connections, shop items and missions are declared (`Setup:754`, `Setup:766` onward).
2. `bc:loadFromDisk()` (`Setup:5835`): loads the rank file, then the campaign file (`zoneCommanderv2.lua:44930-44931`).
3. Era- and mode-dependent fix-ups, starting funds on a fresh PvP start, starting-territory percent (`Setup:5836-5920`).
4. `bc:init()` (`Setup:5961`): each `ZoneCommander:init()` spawns its garrison from the loaded state (`zoneCommanderv2.lua:30252-30262`).
5. Deferred restores scheduled by `init`: AI flights and surface groups after 5 s, carrier navigation, pending captures after 15 s (`zoneCommanderv2.lua:30283-30286`, `29909`, `30173`, `30199`).
6. `startWarehousePersistence()`: warehouse CSV loaded after 5 s, health scan at 12 s (`zoneCommanderv2.lua:112302-112315`).
7. `Foothold CTLD.lua` (loaded 3 s later): `LoadFARPS` after 1 s, Moose CTLD `__Load(1)` re-injects built units (`Foothold CTLD.lua:8100-8101`, `8161`).

**Fresh start vs resume.**
`bc.saveLoaded = true` when the file has a `zones` table (`zoneCommanderv2.lua:44940-44941`); the setup file sets it back to `false` when `zones` is empty (`Setup:5853-5855`).
A reset writes `zonePersistance = {}`, which has no `zones` key, so the next start is a fresh one (`Setup:2805`, `zoneCommanderv2.lua:7140`).
On a fresh start each zone keeps the side, level and upgrade lists given in the setup file.

**Zone re-application** (`zoneCommanderv2.lua:44940-45460`, read in part):
`side`, `active`, `isAwaken`, trigger `hasRun` flags, capture tombstones, `upgradesUsed*` and supply counters are copied back onto the zone object.
The saved garrison template lists (`randomUpgradesRed/Blue`) replace the configured ones, after pruning names that no longer exist in the mission or are disabled in the config, topping up, and clamping to the template maximum (`zoneCommanderv2.lua:45332-45358`).
A missing template is replaced by one from the pool and a message is shown (`zoneCommanderv2.lua:45366-45388`).
`extraUpgrade` entries (shop purchases) are appended to the side's upgrade list (`zoneCommanderv2.lua:45390-45428`).
If the garrison list had to change, the survivor lists are discarded and the zone respawns at full strength (`zoneCommanderv2.lua:45359-45363`).

**Garrisons with losses.**
In `ZoneCommander:init`, for each saved slot with a non-empty survivor list the full group is spawned from its template (`zoneCommanderv2.lua:51593-51611`).
Then `weedOutRemainingUnits` destroys the surplus units: for "Fixed" groups by exact unit name, provided at least one saved name still exists in the group (`zoneCommanderv2.lua:51788-51850`).
Otherwise it matches by type: the saved list is turned into a count per type name, the live units are walked in order, each unit whose `getDesc().typeName` still has a positive count is kept (count decremented) and every other unit is destroyed with `Unit:destroy()` (`zoneCommanderv2.lua:51851-51865`).
So which unit of a type survives is the first in group order, not the one that actually survived, and position and damage are those of a fresh spawn.
Groups listed in the zone's upgrades but not in `built` are destroyed outright, and statics of `newStatics` that are not in `built` are destroyed too (`zoneCommanderv2.lua:51794-51807`, `51869-51888`).
The trim runs twice, 2 s and 4 s after the call, through two one-shot `SCHEDULER`s (`zoneCommanderv2.lua:51896-51900`).
A slot whose saved list is empty is not spawned at all (`zoneCommanderv2.lua:51612-51614`).
Static upgrades are only marked as built if the static still exists (`zoneCommanderv2.lua:51599-51604`).

**AI flights and convoys.**
Parsed into `_pendingAirAiPersistence` and `_pendingSurfaceAiPersistence` at load (`zoneCommanderv2.lua:44626-44889`), restored 5 s after `init` by a raw `timer.scheduleFunction` (`zoneCommanderv2.lua:29892-29918`, `30156-30178`), and requested again right after the warehouse load completes (`zoneCommanderv2.lua:112270`).
The mechanism is detailed in the next subsection.
Director memory is kept in `_pendingDirectorPersistence` and consumed by `Director:_restorePersistence` (`zoneCommanderv2.lua:44601-44624`, `93046`), detailed after it.
Cooldowns are saved as *remaining seconds*, not absolute times, because mission time restarts at each launch (`zoneCommanderv2.lua:92448-93027`, e.g. `recoveryRemainingSec`, `planningRemainingSec`).

### Restore of live AI flights and convoys (read in full: `29295-30180`, `68008-68265`, `70141-70470`)

**Two steps.**
The restore never spawns anything itself: it finds the `GroupCommander` that owned the saved group, hangs the saved record on it, forces its state machine to `preparing` with an expired timer, and runs one `update` so that the commander's own spawn code does the work (`zoneCommanderv2.lua:29866-29870`, `30140-30144`).
`GroupCommander:_processAirPreparing` then branches on `_pendingInAirRestore`: restored spawn instead of fresh spawn (`zoneCommanderv2.lua:68713-68722`); the surface counterpart consumes `_pendingSurfaceRestore` (`zoneCommanderv2.lua:70782-70784`).

**Waiting conditions.**
Both restores wait for the DynamicHybrid bootstrap (which generates the commanders): up to 12 retries 5 s apart (`zoneCommanderv2.lua:29590-29598`, `30050-30058`).
Flights saved in state `takeoff` additionally wait for the warehouse CSV to be loaded when `WarehouseLogistics` is on, because a ground start draws aircraft from the warehouse; in-air flights are restored without waiting (`zoneCommanderv2.lua:29600-29602`, `29877-29889`, `112270`).

**Finding the owner of a saved record** (`_resolveAirPersistenceCommander`, `_resolveSurfacePersistenceCommander`), in this order:
1. Director capability: if the record carries `directorCapabilityId` (or its group name is a capability id), the capability is re-instantiated with the saved instance name, derivative slot (2 or 3) and instance generation; generation mismatches and duplicates are refused with a reason string (`zoneCommanderv2.lua:29301-29387`).
2. Exact commander name, also after stripping a `_retasked_…` suffix (`zoneCommanderv2.lua:29406-29423`, `29939-29956`).
3. DynamicHybrid base name (`DYNH-…` without its numeric suffix): the only candidate, or the best by a score on origin (+4), target (+4), role (+2), side (+2), mission (+2), mission type (+2), unit category (+1), template (+1) (`zoneCommanderv2.lua:29295-29299`, `29425-29472`, `29958-30004`).
4. For non-supply records, any compatible commander by metadata score: origin +3, target +4, side +3, mission +3, mission type +3, unit category +2, template +2, accepted from 10 points for air and 9 for surface (`zoneCommanderv2.lua:29473-29500`, `30005-30031`).
5. Last resort for a DynamicHybrid record with no owner: a new `GroupCommander` is built from the saved fields (shop-bought supply helicopters for air; any role for surface), added to the origin zone and registered with the DynamicHybrid tracker, and the DynamicHybrid name counter is raised to the saved suffix (`zoneCommanderv2.lua:29522-29571`, `30074-30112`).
A record with no owner is dropped with an `env.info` line (`zoneCommanderv2.lua:29782`, `29872`, `30146`).

**Flights saved in state `takeoff`** (`spawnNowTakeoff`) are not restored in place: the commander is put in `preparing` with `_spawnNowImmediateCheck`, so it performs a normal fresh launch from its base at once (`zoneCommanderv2.lua:29771-29780`).
They are skipped when the origin zone changed side or is suspended (shop supply and regular supply from a suspended zone excepted) (`zoneCommanderv2.lua:29637-29641`).
In PvP an ordinary CAP in that state is not relaunched: it is handed to the Director's pending save data as a CAP timer or operation member with zero remaining delay, so the Director relaunches it under its own rules (`zoneCommanderv2.lua:29631-29636`, `29642-29701`).

**Sortie state copied back onto the commander before the spawn** (`zoneCommanderv2.lua:29825-29856`): sortie side, regular-supply origin, shop-launch and paid-supply flags, supply return-home, CAS altitude, CAP holding point with orbit distance and buffer, CAP SAM-return, CAP retask target, CAP return-home with its elapsed seconds and slot-released flag, the advance-capture flags and hold point, the Director retask original target and mission, and the current target zone.

**In-air re-creation** (`GroupCommander:_processAirRestoredSpawn`):
- Position: the saved `{x,y,z}`; a CAS or SEAD plane saved farther than `max(2 × route distance, 100 NM)` from both home and target is not restored (`zoneCommanderv2.lua:68044-68078`, `67025-67043`).
- The position is corrected per mission: a CAS group saved beyond its engagement line is pulled back to 1 NM before a point 5 NM (helicopter) or 20 NM (plane) short of the target on the home-target axis; supply helicopters and planes get a point computed towards their destination, or towards home when returning or when the target is no longer valid (`zoneCommanderv2.lua:68079-68107`, `67045-67089`, `59692-59711`).
- Altitude: the saved one for planes; for helicopters the saved height above ground clamped to 60–300 m, or 1500 ft AGL when no altitude was saved (`zoneCommanderv2.lua:68109-68124`).
- The template (saved `templateName`, else the commander's last or resolved template) is copied, its units are moved to the saved point keeping their formation offsets rotated to the saved heading, and its route is replaced by two "Turning Point" waypoints 2 NM apart along that heading with empty tasks (`zoneCommanderv2.lua:68057-68065`, `68126-68173`).
- Spawn is `SPAWN:NewFromTemplate(tpl, restoreTemplate, alias, true):InitSkill(...):OnSpawnGroup(...):Spawn()`, an air start because the first waypoint is a turning point; Red uses `AiPlaneSkill`, Blue "Excellent" (`zoneCommanderv2.lua:68184-68187`, `68245`).
- In the spawn callback: state `inair`, `lastStateTime = now − lastStateDuration` (so the sortie timers resume), side forced to the saved side, and units beyond the saved `aliveCount` destroyed from the end of the group (`zoneCommanderv2.lua:68199-68225`).
- 0.5 s (CAS) or 2.5 s (others) later `_assignRestoredAirMission` gives the group its real route with `_assignMissionAfterInAirRestore`, retrying every 0.5 s up to 10 times while the group is not yet available, and first waking an idle-suspended target zone (holding up to `idleZoneWakeHoldSec` = 120 s) (`zoneCommanderv2.lua:68233-68242`, `68008-68042`, `67335`, `8466`).
- A failed route assignment is shown on screen to everybody for 15 s (`zoneCommanderv2.lua:68035-68040`).
- Weapons fired and fuel burnt are not restored: the group comes back with the template loadout; only the "no weapon left, returning home" state is carried by `capReturnHome`/`airReturnHome` (`zoneCommanderv2.lua:68234-68235`, `25609-25630`).

**Surface re-creation** (`GroupCommander:_processSurfaceRestoredSpawn`):
- The restore is allowed only if the zones still make sense: the zone containing the saved point, the home zone and the target zone are checked against the saved side (attack needs an enemy target, supply a friendly or neutral one or a valid home when returning, artillery returning home a friendly home) (`zoneCommanderv2.lua:70158-70222`).
- The template is copied with the saved heading; the route is rebuilt **from the saved point**: remaining road route to the target or home for `enroute`, a route back home for returning artillery, a direct two-point off-road leg to the saved hold point for an advance-capture convoy waiting for a neutral zone, an attack route into the zone for an attack group saved `atdestination` (`zoneCommanderv2.lua:70257-70371`, `69018-69193`).
- If no route can be built the group is retired (`dead`) instead of spawned (`zoneCommanderv2.lua:70330-70352`).
- Spawn is `SPAWN:NewFromTemplate(tpl, restoreTemplate, self.name, true)` at the saved position (`zoneCommanderv2.lua:70382-70390`).
- In the callback: state set to the saved `enroute`/`atdestination`, timers resumed with `lastStateDuration`, flags restored, then the alive mask is applied: with `aliveUnitTypes`, units are kept per type up to the saved count and the others destroyed; without it, units beyond `aliveCount` are destroyed (`zoneCommanderv2.lua:70411-70421`, `70455`, `69196-69230`).
- The controller's task is popped and the rebuilt route pushed 5 s later (`zoneCommanderv2.lua:70456-70467`).
- On Normandy a battleship is moved to a safe water point first (`zoneCommanderv2.lua:70236-70248`).

After both passes every saved record is offered to `_retryDirectorSavedInstanceDisposal`, which throws away on-demand Director instances that ended up unused (`zoneCommanderv2.lua:29877-29885`, `30150-30153`, `26552`).

### `Director:_restorePersistence` (read in full: `93046-94266`)

It runs on the Director's first ready tick, refuses a table whose `version` is not 1 or whose `side` differs, and rebuilds each memory with validation against the current mission (`zoneCommanderv2.lua:93046-93047`, `95815-95818`).
Every `…RemainingSec` becomes `now + remaining`, and every `…ElapsedSec` becomes `now − elapsed` (`zoneCommanderv2.lua:93051-93052`, `93079-93080`, `93919-93934`).
Entries naming a group, capability or zone that no longer exists are dropped (ground history and reuse cooldowns: `zoneCommanderv2.lua:93054-93082`).
CAP slots are rebuilt one by one: the owner is re-resolved through `_restoreDirectorPersistenceCommander`, an unknown state falls back to `cooling`, a slot whose owner cannot be restored is put back to `cooling` without owner, and loss-recovery fields are re-anchored on `now` (`zoneCommanderv2.lua:93083-93183`).
Then, in file order: campaign front memory, campaign strategy (name and goal zone/region validated), campaign action, air posture, air reaction decision, Blue area commitment and Blue timers, CAP group timers, operation counter, the three outcome tables, `history`, zone-upgrade history and cooldown, the strategic-budget timers, intent and history, the tactical-airstrike cooldown and last target, the AIEN request, both intelligence memories, the recovery/planning/surge timers, the pending reaction, tactical-strike transfers and CAS capture diversions, and finally the running operation (`zoneCommanderv2.lua:93184-93558`).
Details of the middle part (`93196-93880`, read in the second pass):
- Outcome tables (`doctrineOutcomes`, `targetOutcomes`, `roleOutcomes`) go through `_restoreDirectorOutcome`, which re-dates each row from its saved age; target rows are dropped when the zone no longer exists, and the secondary-axis learning fields are restored only if younger than the intelligence expiry (`93239-93276`).
- `history` keeps at most `historySize` entries whose target zone still exists; `zoneUpgradeHistory` at most 4; `strategicBudgetHistory` at most 6 entries whose action is still a known shop action (`93277-93297`, `93337-93351`).
- The strategic-budget intent is restored only if its action is known, its target zone exists and it has remaining time; the decision timer falls back to the difficulty profile's initial delay when absent from the save (`93298-93336`).
- The AIEN air-support request is restored only if the reactive system is started with AIEN support enabled and the zone is still a usable Red zone (`93356-93378`).
- A pending Red reaction is re-queued with its allowance, mode, retry time and expiry (`93384-93406`).
- Tactical-strike transfers and CAS capture diversions are re-attached to their group only if that group is found (through its Director capability, its name, or its DynamicHybrid base name) and is alive or preparing; a diverted helicopter CAS gets its diverted target re-applied (`93408-93553`).
- The operation is restored only if the saved `state` is valid for the side (`shaping`/`assault`/`exploit`/`surge` for Red PvE, `support` for Blue and PvP) and its target zone is still active, visible, not suspended and not a carrier; otherwise the Director starts in `recovery` (Red) or `waiting` (Blue) (`93554-93568`).
- Operation fields: every clock is rebuilt from elapsed or remaining seconds (`startedAt`, `phaseDeadline`, `mainAuthorizeAt`, reassessment and SEAD-gate times), every ratio is clamped to 0–1, zone names are checked, and absent role-evidence fields are recomputed from the live zone (`93569-93770`).
- Each assignment is re-bound to a commander in this order: Director capability instance, exact name, DynamicHybrid base name; one whose route no longer matches its target (after undoing or re-applying a retask) is dropped; in PvP an assignment whose capability is not instantiated yet is kept as a queued record (`93776-93880`).
- After re-binding, the flags are made consistent with reality: a live group is `launched`, a launched group now dormant is `completed`, fixed-wing CAS behind a still-blocked SEAD gate is de-authorised, and Blue CAS/SEAD (and PvP combat roles) not yet launched are queued for capacity instead of authorised (`93961-94060`).
The operation is restored assignment by assignment: each one is re-bound to its live commander or to its capability, with its role, phase, target, `authorized`/`launched`/`completed` flags, kill counters, reserve and SEAD-gate fields (`zoneCommanderv2.lua:93882-93960`).
A SEAD ingress CAP support record is re-created and a launched CAP is re-routed to the ingress point (`zoneCommanderv2.lua:94200-94242`).
If no combat assignment survives, a Red PvE operation is released and the Director starts in `recovery`; otherwise the saved `state` is resumed (`zoneCommanderv2.lua:94247-94263`).

**Shops and accounts.**
`accounts` replaces the coalition balances and shop stock is restored per item with a fallback to the default stock (`_resolveSavedShopStock`, `zoneCommanderv2.lua:45642`).

**Reproduction notes.**
Load is tolerant by design: every restored name is checked against the current mission and config, so a mission update between two sessions does not break a save.
The restore depends on the order "declare everything → load → init": zone objects must exist before the file is applied, and nothing is spawned before `init`.

## Warehouse persistence (`WarehousePersistence`)

**Player view.**
Messages `WAREHOUSE_PERSISTENCE_STARTED` at start and `WAREHOUSE_PERSISTENCE_LOADED` (count, file name) after load (`zoneCommanderv2.lua:112309`, `112249`).

**Admin view.**
Active in full when `WarehouseLogistics == true`, which is the default (`Config:1279`, `zoneCommanderv2.lua:112308-112310`).
When `WarehouseLogistics == false`, a reduced mode runs with `force` and `warehouseOnly` options (`zoneCommanderv2.lua:112311-112314`, `44554-44556`).

**Mechanism.**
File `<base>_storage.csv`, header `AIRBASE;KIND;NAME;QTY` (`zoneCommanderv2.lua:112003`).
Row kinds: `B` marks an airbase block, `W` is a weapon item and quantity, `P` is a quantity for a "managed" weapon rule of `WarehouseWeaponLocationPolicy` (`zoneCommanderv2.lua:112025-112038`).
Only weapons are stored (inventory items whose name starts with `weapons.` plus items addressed by a 4-number wsType key); unlimited quantities (1073741823) and zero are skipped (`zoneCommanderv2.lua:111898-111945`).
Aircraft and fuel are not in this file (`zoneCommanderv2.lua:111898-111956`).
Ships and carriers are skipped; CTLD FARPs named `CTLD FARP ZELL …` are included (`zoneCommanderv2.lua:111508-111520`).
Save walks the airbases one per second with Moose `TIMER` (fallback `SCHEDULER`), reading `STORAGE:FindByName(ab)` then `GetInventory`/`GetItemAmount`, and writes the file once at the end with `UTILS.SaveToFile` (`zoneCommanderv2.lua:112009-112066`).
In `warehouseOnly` mode the rows of airbases not rewritten are carried over from the previous file (`zoneCommanderv2.lua:111990-111999`, `112054-112064`).
Load reads the CSV with `UTILS.LoadFromFile`/`UTILS.Split` and applies quantities to each `STORAGE`; a suspended blue zone whose average stock is under 500 gets 500 of each repair item added (`zoneCommanderv2.lua:112079-112125`, `112225-112246`).
FARPs rebuilt at startup delay the warehouse load until they exist (`zoneCommanderv2.lua:111570-111630`, `112261-112268`).
Moose: `STORAGE` is a thin wrapper over the DCS `Warehouse` object.
`STORAGE:New(name)` does `Airbase.getByName(name):getWarehouse()` and keeps the result in `self.warehouse` (`Moose_2026-10-11.lua:35671-35679`); `STORAGE:FindByName` only returns the instance Moose registered for that airbase in its database (`Moose_2026-10-11.lua:35698-35701`, `12649`).
Each method is one DCS call: `AddItem` → `warehouse:addItem(name, n)`, `SetItem` → `warehouse:setItem`, `RemoveItem` → `warehouse:removeItem`, `GetItemAmount` → `warehouse:getItemCount(name)`, `GetInventory` → `warehouse:getInventory(item)` returning its `aircraft`, `liquids` and `weapon` tables (`Moose_2026-10-11.lua:35710-35727`, `35838-35841`).
Cargo objects use `Warehouse.getCargoAsWarehouse(staticOrUnit)` instead (`Moose_2026-10-11.lua:35680-35697`).
`AIRBASE:FindByName` is used next to raw `Airbase.getByName` (`zoneCommanderv2.lua:111512-111518`).

**Reproduction notes.**
The save is staggered at one airbase per second (`zoneCommanderv2.lua:112005`, `112048-112052`); the reason (slow inventory read) is an estimation.
A reset in progress aborts a running save and truncates the file (`zoneCommanderv2.lua:111864-111890`, `112011-112015`).

## Rank and player-statistics file (`Foothold_Ranks.lua`)

**Admin view.**
Written only when `RankingSystem == true`, which is the default (`Config:285`, `zoneCommanderv2.lua:44357`).
One file for all maps, eras and modes (`Setup:756`, `zoneCommanderv2.lua:44332-44341`).
It is not cleared by a campaign reset: during a reset the staged job runs in `rankOnly` mode (`zoneCommanderv2.lua:44434`, `44509-44511`).

**Content** (`zoneCommanderv2.lua:43358-43419`, `44356-44378`):
`players[ucid]` = `{name, lastSeen, credits, career = {…}, aircraft = {…}}` (`zoneCommanderv2.lua:44089`, `44104`, `44404`);
`playerAliases[oldName] = ucid` (or `false` when ambiguous);
`legacyPlayers[name]` for records created before UCID keys;
`ewrs[ucid]`, `selfJtac[ucid]` compact per-player settings with `ewrsVersion`/`selfJtacVersion`;
`version`, `playerIdentityVersion` (2), `settingsIdentityVersion` (1).
Rank is derived, not stored: the index of the highest threshold not above `credits` (`zoneCommanderv2.lua:44385-44394`).
Current kill streaks are cleared on load (`zoneCommanderv2.lua:44345-44353`).
Schema migrations run on load: name-keyed records become UCID-keyed when the name maps to exactly one known UCID, otherwise they move to `legacyPlayers` (`zoneCommanderv2.lua:43381-43395`).
A guard refuses to save if the load failed (`zoneCommanderv2.lua:44358`, `25715`).

## Campaign lifecycle: end, reset and restart

**Player view.**
PvE victory: when no non-hidden zone is red, sound `BH.ogg` plays to blue and either the message `MISSION_COMPLETE_AUTORESTART` is shown, or `MISSION_COMPLETE_MANUAL_RESTART` plus a blue coalition F10 submenu `MENU_RESTART_AND_RESET` with Yes/No (`Setup:2786-2830`).
PvE defeat: when no non-hidden zone is blue, "Mission failed, Server restarting..." and an unconditional reset and restart (`Setup:2784-2812`).
PvP: a side wins when the other holds none of the `pvpVictoryZones`; same two branches, the menu goes to the winning side (`Setup:2736-2779`).

**Admin view.**
`AutoRestart` (default `false`): automatic reset and restart on victory (`Config:242-244`).
Marker commands: `StartaOm` (or alias `restartMission`) sets flag 181 without resetting; `AvslutaFoothold` (or alias `endMission`) runs `forceMissionComplete()` (`zoneCommanderv2.lua:29242-29245`, `28903-28911`, `Config:3505-3512`).

**Mechanism.**
The victory check is a zone trigger callback registered on `lost` and `destroyed` of every zone (and `captured` in PvP), plus one scheduled run after startup (`Setup:2836-2849`).
Reset = `bc._persistenceResetPending = true`, then `Utils.saveTable(bc.saveFile, 'zonePersistance', {})`, then `resetSaveFileAndFarp()` which truncates the CTLD save, the red CTLD save and the FARP file, and in PvP also the warehouse CSV and stops the FARP timers (`Setup:2800-2808`, `Foothold CTLD.lua:8113-8152`).
`_persistenceResetPending` then blocks every later campaign write for the rest of the session (`zoneCommanderv2.lua:44548`, `44458`, `111970`).
Restart = `trigger.action.setUserFlag(181, true)` five seconds later (`Setup:2809-2811`).
Flag 181 is consumed by mission trigger 7, `a_end_mission("blue", "", 0)` (`mission:63,92`).
No `net.load_mission` or `net.dostring_in` call exists in `zoneCommanderv2.lua` (grep returns nothing): after `a_end_mission`, reloading the mission is left to the dedicated server's mission list or an external tool (estimation for what happens next).
Flag 180 is set when the mission is completed and is read by the setup file to mute mission announcements (`Setup:2796`, `Setup:6202`).
`forceMissionComplete` duplicates the PvE victory branch (`zoneCommanderv2.lua:28111-28147`).
A plain server restart without reset resumes the campaign from the last autosave (`zoneCommanderv2.lua:30330`).

## Era and mode switches

**Admin view.**
`Era = "Modern"` | `"Coldwar"` | `"Vietnam"` (`"Gulfwar"` on Iraq) and `PvP = false` in the config (`Config:196-202`).
`PvP` is only honoured on Caucasus, Syria and Persian Gulf (`Config:3525`).

**What they switch** (Caucasus setup):
the save base name, hence a separate campaign per era and mode (`Setup:467-477`);
template names by suffix (`_CW`, `_VT`, `Coldwar`) for CAP, CAS, SEAD, bomber, armour and JTAC drone templates (`Setup:3049`, `3331`, `3446`, `3621`, `4299`, `5290`);
the blue point-defence SAM, HAWK or NASAMS (`Setup:32`);
shop items removed after load: `zsam` and `zcram` outside Modern, `zpat` in Vietnam (`Setup:5844-5851`);
carrier activation, off in Vietnam (`Setup:5982-5990`);
the allowed-aircraft lists per side (`Setup:441-463`);
`GlobalSettings.pvpEnabled = (PvP == true)` (`Setup:440`), tested throughout the engine (e.g. `zoneCommanderv2.lua:17085-17112`).
The era is a load-time constant: templates for all eras are present in the single `.miz` and the script picks them by name.

## Player identification

**Mechanism.**
At runtime almost everything is keyed by **player name** (`Unit:getPlayerName()`): stats, contributions, locale, spawn zone (`zoneCommanderv2.lua:42931-42933`, `101412-101420`, `Foothold_Localization.lua:20931-20948`).
For persistence the name is resolved to a **UCID**: the engine scans `net.get_player_list()`, matches `net.get_name(pid)` to the name, then reads `net.get_player_info(pid, 'ucid')` (`zoneCommanderv2.lua:43685-43708`, `41170-41192`).
The name → pid lookup is cached and re-validated on each use (`zoneCommanderv2.lua:41171-41183`).
A rename is detected when a known UCID arrives with a new name: the old name becomes an alias of the UCID, and an alias claimed by two UCIDs is marked ambiguous (`false`) (`zoneCommanderv2.lua:43727-43739`).
Records created before UCID keys stay under `legacyPlayers[name]` and are claimed by the first verified join with that name (`zoneCommanderv2.lua:43467-43471`, `43743-43744`).
The identity sync runs on every player spawn and, for all connected players, at every autosave (`zoneCommanderv2.lua:101468`, `44430-44432`, `43781-43802`).
Player names containing `'`, `/` or `\` are refused: the player is sent back to spectators with the message `PLAYER_ILLEGAL_NAME_CHARACTERS` (`zoneCommanderv2.lua:101418`, `101427-101430`).
This restriction matches the save-file repair that drops lines with path-like keys (`zoneCommanderv2.lua:7263-7268`).

**Reproduction notes.**
`net.*` functions are only meaningful on a server; on a single-player session `net.get_player_list()` returns nothing useful, hence the "listen-server host" comment (`zoneCommanderv2.lua:43709`).
Multicrew aircraft are handled by resolving the crew of a slot through `net.get_player_info(pid, 'slot')` (`zoneCommanderv2.lua:41194-41196`, `40562`).

## Player spawn handling and slot control

**Player view.**
Spawning in a zone owned by the other coalition: chat message `PVP_CANNOT_SPAWN_IN_ZONE`, a 5 s on-screen text, the aircraft is destroyed and the player is moved to spectators (`zoneCommanderv2.lua:101447-101452`, `101040-101049`).
With `PVE_Only = true`, any red slot is refused the same way with `PVP_MODE_DISABLED_RED_SLOTS` (`zoneCommanderv2.lua:101431-101434`, `Config:247-251`).
On an accepted spawn the player group gets its F10 menus (stats and language, missions, logistics when the type is allowed, EWRS, carrier and tanker control) (`zoneCommanderv2.lua:101473-101500`).

**Mission-maker view.**
No naming convention is needed for client groups: at init every group template whose first unit has skill `Client` and whose position lies inside a zone is attached to that zone as a "restricted group" (`zoneCommanderv2.lua:27186-27205`).
Zones flagged `isHidden` do not restrict spawns (`zoneCommanderv2.lua:101447`).

**Mechanism — three layers.**
1. *Airbase coalition*: when a zone changes side, `Airbase.getByName(name):setCoalition(side)` is called after `autoCapture(false)`, and a synthetic `S_EVENT_BASE_CAPTURED` is injected with `world.onEvent` (`zoneCommanderv2.lua:56753-56767`, `51439-51476`).
DCS itself then refuses slots on an airbase held by the other coalition (estimation: engine behaviour, not in the script).
2. *User flags*: for each restricted client group, `trigger.action.setUserFlag(<groupName>, blocked)` is set at zone init and re-checked at every zone update (`zoneCommanderv2.lua:51745-51747`, `55197-55202`).
The flag value is 1 when the group's coalition differs from the zone owner.
Nothing in the mission reads these flags: they are meant for a server-side slot-blocking hook that reads a flag named after the group (estimation; no such hook ships in the repository).
3. *Birth event*: `S_EVENT_BIRTH` (tested as `eventId == 15`) with a player name calls `LogisticCommander:_handleBirth` (`zoneCommanderv2.lua:42931-42947`).
It finds the zone containing the unit and, when the owner differs, calls `_rejectPlayerSpawn`: `net.send_chat_to(message, pid)`, `net.force_player_slot(pid, 0, '')` after 0.1 s, `outTextForGroup`, then `event.initiator:destroy()` (`zoneCommanderv2.lua:101029-101049`, `101443-101452`).
This third layer is the only one that works without a server hook, and it also covers dynamic-spawn slots and ground-start slots outside airbases, since it tests the unit position only (`zoneCommanderv2.lua:101413`).

On an accepted spawn `_handleBirth` also: clears the player's previous respawn state, records the spawn zone (`playerZoneSpawn[player]`), syncs the UCID identity, binds the group id to the player's locale, bumps a per-group "menu token", registers the group in `activeAircraftGroupsById`, starts a career flight if spawned in the air, registers with EWRS, and builds the menus (`zoneCommanderv2.lua:101421-101480`).
The menu token (`groupMenuTokens[groupid]`) is compared by every delayed callback so that work scheduled for a previous occupant of the same group id is dropped (`zoneCommanderv2.lua:97779`, `101056-101058`, `101490`).

**Warehouse aircraft availability.**
Aircraft counts per airbase are managed through the DCS warehouse (`STORAGE`), with `allowedPlanes*` lists per era and side and a `restockAircraft` table in the config (`Config:2622`, `Config:3144`, `Setup:441-463`); this was not analysed here (see "Seen outside this theme").

**Reproduction notes.**
`net.force_player_slot` and `net.send_chat_to` are called from the mission environment (`zoneCommanderv2.lua:101034-101036`).
The birth handler destroys the aircraft after the fact, so the player sees the cockpit for a moment.
DCS reuses group ids for dynamic-spawn slots, which is why the menu token exists (estimation for the reason; the token mechanism is read).

## Takeoff, landing, ejection and death tracking

**Mechanism.**
All of it hangs on the single `world.addEventHandler` of `BattleCommander:init` (`zoneCommanderv2.lua:30228-30232`).
`S_EVENT_TAKEOFF`: for a player, marks the carrier origin, flags the self-JTAC as airborne, starts the career flight for the whole crew, arms the "reward on landing" state, evaluates night conditions (night reward, night SAM behaviour), warns when a supply carrier takes off empty (`zoneCommanderv2.lua:42948-42977`, `101793-101829`).
`S_EVENT_LAND`: for a player, `_handleRewardPlayerLanding` pays out the pending contribution if the landing place qualifies; for AI, `_handleRewardAiLanding` (`zoneCommanderv2.lua:43096-43103`).
A synthetic `S_EVENT_LAND` is injected with `world.onEvent` for players already landed inside a zone at the moment it is captured, so they are paid without taking off again (`zoneCommanderv2.lua:56722-56745`, `41324`).
`S_EVENT_EJECTION`, `S_EVENT_PILOT_DEAD`, `S_EVENT_UNIT_LOST`, `S_EVENT_KILL`, `S_EVENT_SCORE` feed the reward and penalty code (`zoneCommanderv2.lua:43024-43031`, `43060-43106`).
`S_EVENT_LANDING_AFTER_EJECTION` creates the downed-pilot record used by CSAR (`zoneCommanderv2.lua:42978-42990`).
`S_EVENT_DEAD` of an airdrome object (runway destroyed) blocks AI plane spawns at that zone for 3300 s (`zoneCommanderv2.lua:42906-42920`).
`S_EVENT_SHOT` from a player `Hercules` drives the cargo air-drop supply (`zoneCommanderv2.lua:42921-42930`).
Every 60 s a scheduler removes pending contributions of players who are neither in an aircraft of that side nor connected on that side (`zoneCommanderv2.lua:43108-43148`).

## Friendly fire

**Player view.**
Message `FRIENDLY_FIRE_PLAYER` (killer, victim) or `FRIENDLY_FIRE_UNIT` (killer, unit name), followed by `FRIENDLY_FIRE_RANK_LOSS` when a penalty applies (`zoneCommanderv2.lua:42648-42670`).

**Admin view.**
`FriendlyFireRankPenalty = 500` credits, 0 disables the penalty (`Config:288`, `zoneCommanderv2.lua:42657-42658`).

**Mechanism.**
In the `S_EVENT_KILL` reward path, a kill whose target is on the killer's side calls `_handleRewardFriendlyKill`, which increments the career counter `FriendlyKills`, removes points from the session stats and removes rank credits (`zoneCommanderv2.lua:42641-42670`, `42879`, `44207-44212`).
No kick, ban or slot removal is done by the script (`zoneCommanderv2.lua:42641-42675`).

## Admin and player map-marker commands

**Player view.**
Commands are typed as the text of an F10 map marker; the marker is deleted when the command is accepted (`zoneCommanderv2.lua:29246-29248`).
Open to everybody: `help`, `buy` / `buy:<item>`, `status`, `stats`, `top`, `mystats`, `missions`, `intelstatus`, `whynot`, `jtac-code:<code>`, tanker and CAP station markers `arcohere1/2`, `texacohere1/2`, `caphere1/2`, `tarawahere…` (`zoneCommanderv2.lua:28356-28404`, `7403-7414`).

**Admin view.**
There is **no admin list**: no UCID or name check exists in the marker handler; an admin command is protected only by the secrecy of its word (`zoneCommanderv2.lua:28455-28470`).
With `AdminCommands = false` (default) the built-in words apply, several in Swedish: `köp`, `rensa`, `upgradera`, `maxxa`, `blå`, `röd`, `StartaOm`, `AvslutaFoothold`, `addfunds:<n>`, `addfundsred:<n>`, `additems…`, `givemefarp…` (`zoneCommanderv2.lua:28885-28911`, `29242`, grep of `not adminAliases and` in `28470-29245`).
With `AdminCommands = true`, those built-in words are disabled and replaced by the words set in `AdminCommandAliases`: `addBlueFunds`, `addRedFunds`, `addZoneItems`, `buyWithoutRank`, `createFarp`, `captureNeutralBlue`, `captureNeutralRed`, `clearZone`, `upgradeZone`, `fullyUpgradeZone`, `restartMission`, `endMission` (`zoneCommanderv2.lua:28423-28436`, `Config:3468-3512`).
An alias is rejected if it contains `:` or a newline, is blank, collides with a built-in command, or is used twice (`zoneCommanderv2.lua:28409-28422`).
Other built-in words are not aliasable and stay active in both modes: `debug`, `spawn`, `prepp`, `addshop`, `removeshop`, `upgradeallred`, `upgradeallblue`, `event`, `event:<name>`, `recapture`, `capture:<…>`, `givemesupplies`, `addrank:<player>,<n>`, `Message:<text>`, `SpelaMusik`, `ConfigStatus`, `debughelp`, `adminbuy` (needs `AllowAdminBuy`) (`zoneCommanderv2.lua:28356-28404`, grep of `event.text==` in `28470-29245`).
`-code:<lua>` runs the rest of the marker text through `loadstring` and `pcall` with no guard at all (`zoneCommanderv2.lua:29203-29214`).

**Guards, command by command** (bodies read in full: `zoneCommanderv2.lua:28455-29253`).
The only test common to all commands is the handler's entry condition: event 26, a text, and a marker coalition of 1 or 2 (`zoneCommanderv2.lua:28456`).
No command body tests a UCID, a player name, a rank (except `buy`), a password or a "debug enabled" flag; there is no admin password and no admin list anywhere in the Config file, whose "Admin Commands" section holds only `AdminCommands` and `AdminCommandAliases` (`Config:3468-3512`).
`AdminCommandAliases` are all empty strings by default, and an empty alias disables that action, so turning `AdminCommands` on without filling the words removes the twelve aliasable actions entirely (`Config:3477-3512`, `zoneCommanderv2.lua:28411-28412`).

| Command | Guard in its body | Effect | Lines |
|---|---|---|---|
| `help`, `debughelp`, `ConfigStatus` | none | text to the author's group, else to the marker's coalition | `28481-28553` |
| `buy`, `buy:<item>` | rank: with `RankingSystem`, the author's rank must reach the item's `reqRank`; uses the marker's coalition account | list or purchase | `28555-28620` |
| `adminbuy`, `adminbuy:<item>` | config flag `AllowAdminBuy`, default `true`; no rank check | purchase without rank, at the marker's coalition cost | `28622-28660`, `Config:1948` |
| `köp…` / alias `buyWithoutRank` | secret word only | same as `adminbuy` | `28662-28705` |
| `debug` | none | dumps the zone's built groups and unit life to `dcs.log` | `28707-28746` |
| `spawn` | none | forces every `inhangar`/`dead` group of the zone under the marker to launch now | `28747-28760` |
| `spawnnow[:<side>]` | none | `spawnNowBySide(side)`, default side = marker coalition | `28761-28773` |
| `prepp` | none | moves the zone's `dead` groups to `inhangar` with an expired timer | `28774-28788` |
| `addshop`, `removeshop` | none | rebuilds or removes the Blue shop menu | `28789-28793`, `28804-28808` |
| `upgradeallred`, `upgradeallblue` | none | upgrades every zone of a side | `28794-28803` |
| `status`, `intelstatus`, `whynot`, `missions`, `stats`, `top`, `mystats` | none (player commands) | information | `28810-28834`, `28918`, `29068-29084`, `29215-29240` |
| `additems…` / alias `addZoneItems` | secret word only | adds weapons to the zone or FARP warehouse | `28836-28872` |
| `event` | none | lists event ids in `dcs.log` | `28874-28879` |
| `event:<id>` | none | `evc:triggerEvent(id)` | `28880-28885` |
| `rensa` / alias `clearZone` | secret word only | `zone:killAll()` | `28886-28895` |
| `Message:<text>` | none | `trigger.action.outText` to everybody, 10 s | `28896-28901` |
| `SpelaMusik` | none | sets flag 180 for 300 s and plays `BH.ogg` to Blue | `28902-28910` |
| `AvslutaFoothold` / alias `endMission` | secret word only | `forceMissionComplete()` | `28911-28917` |
| Tarawa markers | Blue coalition and `AllowTarawaToMoveFreely` for the free-move forms | carrier group routing | `28938-29009` |
| `farphere`, `givemefarpzell`, `escortmissionfarp` | PvP only for this branch; alias `createFarp` | builds a FARP at the marker | `29011-29040` |
| `givemefarp` / alias `createFarp` | secret word only | builds an ordinary FARP | `29042-29066` |
| `addfunds:<n>` / alias `addBlueFunds` | secret word only | `bc:addFunds(2, n)` | `29085-29096` |
| `addrank:<player>,<n>` | none | adds rank credits to a named player, with the rank-up sound | `29097-29123` |
| `addfundsred:<n>` / alias `addRedFunds` | secret word only | Red funds | `29125-29136` |
| `upgradera` / alias `upgradeZone` | secret word only; refuses a suspended zone | `zone:upgrade()` | `29137-29148` |
| `recapture` | none | `zone:RecaptureBlueZone()` | `29149-29156` |
| `givemesupplies` | none | adds 3 expedited supply stock to the zone | `29157-29163` |
| `maxxa` / alias `fullyUpgradeZone` | secret word only | `zone:MakeZoneSideAndUpgraded()` | `29164-29171` |
| `capture:<1|2>` | none | `zone:capture(side)` | `29172-29184` |
| `blå`, `röd` / aliases `captureNeutralBlue`, `captureNeutralRed` | secret word only | `zone:capture(2)` / `zone:capture(1)` | `29185-29202` |
| `-code:<lua>` | none | arbitrary Lua | `29203-29214` |
| `StartaOm` / alias `restartMission` | secret word only | sets flag 181 | `29242-29245` |

"Secret word only" means the branch is `(not adminAliases and text == <built-in word>) or customAdminAction == <action>`: knowing the word is the whole protection.
`AdminCommands = true` therefore hides only the twelve aliasable actions behind chosen words; the non-aliasable rows marked "none" (`spawn`, `capture:`, `addrank:`, `event:`, `Message:`, `recapture`, `upgradeall…`, `-code:`) stay open to every client with their fixed names.
Those names are published in game: the open `debughelp` command prints the text `ADMIN_DEBUG_HELP`, which lists `spawn`, `rensa`, `capture:`, `maxxa`, `event:`, `addfunds:`, `addrank:`, `upgradera`, `upgradeallred`, `spawnnow:` and `-code:` with examples (`zoneCommanderv2.lua:28492-28500`, `Foothold_Localization.lua:2056`).
A marker whose `event.coalition` is neither 1 nor 2 is ignored (`zoneCommanderv2.lua:28456`); whether a spectator or game-master marker carries such a value is an estimation.

**Mechanism.**
A dedicated `world.addEventHandler` object tests `event.id == 26` (`S_EVENT_MARK_CHANGE`) with a text and a coalition of 1 or 2 (`zoneCommanderv2.lua:28453-28456`, `29252`).
Zone-targeted commands use the marker position: `bc:getZoneOfPoint(event.pos)` (`zoneCommanderv2.lua:28886`).
A zone hit by a command is "woken" so its maintenance runs at once (`zoneCommanderv2.lua:28439-28445`).

**Reproduction notes.**
Any connected client of either coalition can run any command whose word they know, including arbitrary Lua through `-code:`.

## Engine main loops and timers

**The loops started by `BattleCommander:init`** (`zoneCommanderv2.lua:30226-30338`):

| Loop | First run | Period | What it does | Code |
|---|---|---|---|---|
| `update()` | 2 s | `updateFrequency` = 10 s | the zone update wave (below) | `30293`, `Setup:754` |
| `_autoZoneSuspend()` | 1 s | 60 s | despawns garrisons of zones far from the front | `30291`, `37445` |
| `_proximityWakeSuspendedZones()` | 10 s | 60 s | re-spawns a suspended zone when players approach | `30292` |
| watchdog | 60 s | 60 s | shows `SYSTEM_ENGINE_CRASH` if no update completed for `max(60, 2 × updateFrequency)` s, with phase, zone and group in `dcs.log` | `30294-30327` |
| `requestStagedSaveToDisk()` | 30 s | 60 s | autosave | `30330` |
| `_runShouldSpawnEvalTick()` | ~0.5 s | 0.5 s (+ up to 0.15 s jitter on the first) | drains a queue of "should this AI group spawn" evaluations, 8 per tick, 18 when more than 70 are waiting | `30331-30337`, `17127-17132`, `17982-18003` |
| contribution cleanup | 1 s | 60 s | drops pending rewards of absent players | `43108-43148` |
| message of the day | 10 s | `MessageOfTheDay.intervalSec` (1800 s) | repeats a configured text | `30208-30224` |
| territory overlay refresh | 0.1 s | once | draws the map | `30267-30275` |

**The zone update wave.**
`update()` first runs coalition-level supply stock, then schedules a chain of raw `timer.scheduleFunction` steps: one `ZoneCommander:update()` per step, 0.1 s apart (`zoneCommanderv2.lua:43235-43253`, `43291-43325`).
The very first cycle after start updates all zones in one call (`zoneCommanderv2.lua:43335-43345`).
If a new 10 s tick arrives while a wave is still running, it is only flagged and one extra cycle runs at the end of the wave (`zoneCommanderv2.lua:43328-43331`, `43277-43289`).
At the end of a wave: zone intel update, ROE checks for monitored groups, difficulty fade, and the watchdog timestamps (`zoneCommanderv2.lua:43255-43275`).
Each zone carries its own maintenance interval and dormancy state; an "active FSM bucket" counter spreads the AI groups of a zone over several ticks (`zoneCommanderv2.lua:43241-43244`, `28439-28444`) (the per-zone and per-group logic belongs to other themes).

**Timer primitives.**
The engine mixes two: 162 calls to raw `timer.scheduleFunction` (with 14 `timer.removeFunction`) and 97 `SCHEDULER:New` plus 3 `TIMER:New` (counts by grep on `zoneCommanderv2.lua`).
Raw timers are used for one-shot delays and self-rescheduling chains (the function returns the next time, e.g. `zoneCommanderv2.lua:43307`).
`SCHEDULER:New(obj, fn, args, start, repeat)` is used for the recurring loops and for many one-shots with `repeat = 0` (e.g. `zoneCommanderv2.lua:28084`, `17314-17316`).
Moose `SCHEDULER:New(master, fn, args, start, repeat, randomize, stop)` registers the call with the global `_SCHEDULEDISPATCHER` (`Moose_2026-10-11.lua:7884-7915`).
The dispatcher wraps `fn` in a `CallHandler` closure and starts it with `timer.scheduleFunction(CallHandler, {CallID, Info}, now + start)`; stopping is `timer.removeFunction(ScheduleID)` (`Moose_2026-10-11.lua:7954-7990`, `8071-8087`, `8088-8105`).
The handler runs `fn` under `xpcall` with an error handler that logs "Error in timer function" and a traceback to `dcs.log` (`Moose_2026-10-11.lua:7996-8003`, `8030`, `8038`).
Rescheduling rule: if the call succeeded and returned `nil` or any value other than `false`, and `repeat ~= 0`, the handler returns `now + repeat ± randomize × repeat / 2` to DCS; with `repeat == 0` the schedule is reclaimed; an error or a `false` return stops a repeating schedule (`Moose_2026-10-11.lua:8043-8056`).
So a Lua error inside a repeating `SCHEDULER` function kills that loop silently, which is the same failure mode the engine watchdog exists for.
The stop-on-`false` contract is relied on at `zoneCommanderv2.lua:44526`.
Moose `TIMER:New(fn, ...):Start(tstart, dT, duration)` is the lighter form: one direct `timer.scheduleFunction(self._Function, self, tstart)`, re-armed every `dT`, with no `xpcall` (`Moose_2026-10-11.lua:22991-23003`, `23042-23060`).
The bundled Moose is patched by Foothold: the dispatcher's error handler reads the engine global `bc` to add context to its log line (`Moose_2026-10-11.lua:7998`), so the file is not a stock Moose build.

**Reproduction notes.**
The 0.1 s per-zone stagger, the evaluation queue with a budget, the staged save and the menu queues are all the same pattern: no loop is allowed to touch every zone, group or player in one frame.
The watchdog exists because an error inside the wave chain stops the chain silently; it reports the last phase, zone and group reached (`zoneCommanderv2.lua:30294-30326`, `43300-43302`).

## Event handling

**Mechanism.**
The engine registers only three raw DCS handlers with `world.addEventHandler`: the main dispatcher (`zoneCommanderv2.lua:30228-30232`), the marker-command handler (`29252`) and one per JTAC object for `jtac-code:` markers (`7403-7417`).
The main dispatcher `_handleWorldEvent` handles `S_EVENT_KILL`, `DEAD`, `CRASH`, `UNIT_LOST`, `SHOT`, `BIRTH` (15), `TAKEOFF`, `LANDING_AFTER_EJECTION`, `LAND`, `EJECTION`, `PILOT_DEAD`, `SCORE` (`zoneCommanderv2.lua:42893-43106`).
Zone state is **not** event-driven: unit deaths in a garrison are found by polling in the zone update, not from `S_EVENT_DEAD` (the dispatcher returns for `S_EVENT_DEAD` unless the object is an airdrome, `zoneCommanderv2.lua:42906-42909`).
Synthetic events are injected with `world.onEvent` for `S_EVENT_LAND` and `S_EVENT_BASE_CAPTURED` (`zoneCommanderv2.lua:56735`, `56762`, `41324`, `98336`, `102339`).
Moose event handling is used in only two places in the engine: a `BASE`-derived handler with `HandleEvent(EVENTS.Shot)` for runway-strike missions (`zoneCommanderv2.lua:61999-62074`, `62522-62573`) and the MANTIS subclass hook testing `EVENTS.Hit`/`EVENTS.UnitLost` (`zoneCommanderv2.lua:111460-111461`).
The satellite scripts lean on Moose events more: `WelcomeMessage.lua` handles `EVENTS.BaseCaptured`, `PlayerLeaveUnit`, `Refueling`, `RefuelingStop` (`WelcomeMessage.lua:2932-2935`), which is why the engine emits a synthetic `S_EVENT_BASE_CAPTURED`.

**Every `SET_*` in the engine** (`zoneCommanderv2.lua`):

| Line | Set | Tracks | Live? |
|---|---|---|---|
| `105305` | `BlueClients = SET_CLIENT` blue planes (blue and red in PvP), active | player aircraft, used by tanker and support logic | `FilterStart` |
| `17104` | same set re-filtered for both coalitions in PvP | — | `FilterOnce` |
| `65087-65093` | `SET_CLIENT` planes, active | players for recon missions | `FilterStart` |
| `27903-27905` | `SET_GROUP` by name prefix | garrison groups that roam between sub-zones | `FilterStart` |
| `104062` | `SET_GROUP` red ground, alive | groups entering the trigger zone of an escort mission | `FilterStart`, stopped with `FilterStop` at `104065` |
| `110008`, `111125`, `111208`, `111287` | `SET_GROUP` in a zone, by coalition, active | artillery and naval-strike targets | `FilterOnce` |
| `111446-111447` | MANTIS `SAM_Group`, `EWR_Group` | SAM and EWR groups given to MANTIS | `FilterOnce` |
| `111454` | `SET_ZONE` prefix `Scoot` | scoot zones for MANTIS | `FilterStart` |

`FilterOnce` is a single pass over the Moose database of that object kind (`self.Database`), adding the objects that pass the filters and removing the others; nothing is subscribed (`Moose_2026-10-11.lua:13954-13963`).
`SET_GROUP:FilterStart` does the same initial pass, then subscribes the set to `EVENTS.Birth` (add if it passes the filters), and to `Dead`, `Crash`, `RemoveUnit`, `UnitLost` and `PlayerLeaveUnit` (remove the group when its last unit goes) (`Moose_2026-10-11.lua:14358-14373`, `13970-13977`, `14009-14016`, `14392-14412`).
When the set has a zone filter it also starts a `TIMER` re-evaluating zone membership every 30 s (`Moose_2026-10-11.lua:14366-14370`).
`SET_CLIENT:FilterStart` subscribes to `Birth`, `Dead`, `Crash` and `PlayerLeaveUnit`, with the same optional 30 s zone timer (`Moose_2026-10-11.lua:15941-15955`).
`SET_ZONE:FilterStart` scans the zone database and subscribes to Moose's own `NewZone`/`DeleteZone` events (`Moose_2026-10-11.lua:16631-16644`).
`HandleEvent` registers the object with Moose's single `EVENT` dispatcher, which is one `world.addEventHandler(self)` for the whole framework and fans each DCS event out to the subscribed objects (`Moose_2026-10-11.lua:6620-6623`, `8630-8634`, `8846`).
So every live `SET_*` costs one callback per matching DCS event, plus a 30 s poll when filtered by zone.

**Reproduction notes.**
The hidden dependency is the Moose database itself: `_DATABASE.Templates.Groups[name]` is read 26 times to get a group template (units, country, category) by name (`zoneCommanderv2.lua:1160`, `1220`, `1277`, `5228`, `27187`).
That registry is what Moose builds from `env.mission` at load; the engine then spawns with its own `Respawn` helpers that call `coalition.addGroup` directly (`zoneCommanderv2.lua:1315-1336`, `1344-1414`).

## F10 radio menu management

**Mechanism.**
Menus are built with the raw `missionCommands` API: 392 calls in the engine (138 `addCommandForGroup`, 100 `addSubMenuForGroup`, 59 `removeItemForGroup`, 35 `addCommandForCoalition`, 36 `addSubMenuForCoalition`, 24 `removeItemForCoalition`; counts by grep).
Moose `MENU_GROUP` appears 7 times, all in the logistics (cargo) menu of `_handleBirth`, kept in `LogisticCommander.mooseLogisticsMenus` (`zoneCommanderv2.lua:101561-101739`).
Menus are per group (`…ForGroup(groupId, …)`), created at player birth, with the handles kept in tables indexed by group id (`statsMenus`, `languageMenus`, `MissionsRootMenus`, `printMissionMenus`, `zoneStatusMenus`, `groupMenus`) (`zoneCommanderv2.lua:101192-101234`, `101481-101486`, `101027-101029`).
Pagination is manual: a "More" submenu is inserted every 9 entries (`zoneCommanderv2.lua:101218-101224`).

**Refresh queues.**
Menus whose content depends on campaign state (zone status, shop selectors, dynamic control, tanker, strike and intel missions, joint missions) are never rebuilt in the caller.
`requestZoneStatusMenuRefresh(groupId | nil, intelOnly)` only records what is dirty (all groups, some groups, or intel only) and arms one `SCHEDULER` 0.15 s later (`zoneCommanderv2.lua:17301-17317`).
The flush turns the dirty set into a queue of groups and starts a raw timer chain that rebuilds **one group per 0.1 s** (`zoneCommanderv2.lua:17272-17299`, `40469-40500`).
Before rebuilding, each entry is validated: the group still exists, still has the same id, and its menu root and state object are the ones captured when queued (`zoneCommanderv2.lua:40473-40476`).
Requests arriving during a drain are accumulated and flushed when the queue empties (`zoneCommanderv2.lua:40496-40499`).
The same request/flush pattern exists for the shop selector, dynamic control, supply and tanker menus (`zoneCommanderv2.lua:17319-17345`, `17389`, `17419`, `17441-17455`, `17600`) and for joint-mission menus (`18911`).
No engine changelog ships in the extract (only `tools/FootholdConfigManager/CHANGELOG.md`), so the queues cannot be tied to the 6.4.9 or 6.5.0 crash fixes; what follows is the code as it stands in 6.5.3.

**The five queues of 6.5.3.**

| Queue | Request | Coalescing delay | Drain rate | Unit of work | Code |
|---|---|---|---|---|---|
| Zone status / intel | `requestZoneStatusMenuRefresh(groupId or nil, intelOnly)` | one-shot `SCHEDULER` 0.15 s | raw timer, **1 group per 0.1 s** | rebuild of one group's Red/Blue zone lists, or of its intel submenu only | `17272-17317`, `40469-40499` |
| Shop selectors | `requestShopSelectorRefreshForCoalition(side, tags or item ids)` | one-shot `SCHEDULER` 0.15 s | one-shot `SCHEDULER` re-armed every `shopSelectorRefreshInterval` = **0.25 s**, `shopSelectorRefreshBudget` = **1 job per tick** | one (group, shop item) pair: the zone-selector submenu of that item | `17319-17417`, `17513-17629`, `17649-17697`, `11999-12000` |
| Dynamic control | `requestDynamicControlMenuRefresh()` | shares the shop flush | shares the shop worker: while both have work, **every fourth tick** goes to dynamic control (after 3 non-priority shop jobs) | one group's "Dynamic Control" root menu | `17389-17392`, `17600-17613`, `17655-17667` |
| Supply / tanker | `requestDelayedSupplyMenuRefresh()`, `requestDelayedTankerMenuRefreshForBlue(needsShop)` | supply: raw timer, debounced to 1 s after the **last** request; tanker: raw timer 2 s | supply feeds the shop queue; tanker: **1 group per 0.5 s**, re-run 2 s later if requested meanwhile | supply: shop items `supplies`/`supplies2`; tanker: one group's shop menu or dynamic-control menu | `17419-17511` |
| Joint missions | `refreshJointMenusForSide(side)` | pending-side set | raw timer, **1 group per 0.1 s** | one group's joint request and pending-request submenus | `18911-18975` |

**Deduplication inside the queues.**
Zone status: the dirty state is three variables (`…RefreshAll`, `…RefreshIntel`, `…RefreshPendingGroups`), so any number of requests before the flush yields at most one entry per group (`zoneCommanderv2.lua:17301-17308`, `17278-17292`).
Shop selectors: a job is keyed `side|groupId|itemId` in a `seen` set, so the same pair is never queued twice; a "priority" item (`capture`, `advancecapture`) is moved to the head of the queue (`zoneCommanderv2.lua:17549-17596`).
Dynamic control: `indexByGroup` keeps one slot per group and overwrites it (`zoneCommanderv2.lua:17607-17612`).

**The "unchanged" checks that avoid a rebuild.**
- Zone status: the rows of each side (zone object, handler, label text) are compared with the rows last rendered for that group, together with the root handle, viewer side, translator, locale, side labels and "More" label; only a side that differs is removed and re-added, and nothing is touched when both match (`zoneCommanderv2.lua:40317-40324`, `40408-40466`).
- Dynamic control: a signature string concatenating every input of the menu (support flights active, spawn indexes, push modes, rank, …) is compared with `groupDynamicSignatures[groupId]`; when equal and not forced, only the tanker sub-part is refreshed (`zoneCommanderv2.lua:16408-16427`).
- Strike and intel mission menus: a signature of the active missions or zones is compared with the stored one, plus the rendered root and locale for intel (`zoneCommanderv2.lua:103218`, `103254-103258`, `103318`, `103364-103368`).
- Joint pending requests: the pending rows (player, label, request) and the four labels are compared with the previous rows; identical means return (`zoneCommanderv2.lua:18861-18877`).
- The shop root menu has no such check: `refreshShopMenuForGroup` removes every remembered item and rebuilds (`zoneCommanderv2.lua:22395-22411`).

**Handle tracking and validation.**
Handles are kept in tables keyed by group id: `zoneStatusMenus`, `redSideMenus`, `blueSideMenus`, `_zoneStatusMenuStateByGroup`, `groupSupportMenus[gid] = {menu, items, selectorNodes}`, `groupDynamicMenus`, `groupDynamicSignatures`, `groupTankerMenus`, `groupCarrierNavigationMenus`, `jointMenusByGroup`, `jointMenuOwnersByGroup`/`BySide`, plus `statsMenus`, `languageMenus`, `aiLogisticsMenus` on the `LogisticCommander` (`zoneCommanderv2.lua:40420-40466`, `22400-22411`, `97826-97889`).
A queued entry captures what it was queued against (root handle and state object for zone status; owner object and parent menu for joint; menu token for tanker) and is skipped at drain time if the live group no longer has the same id or the captured objects changed (`zoneCommanderv2.lua:17288-17290`, `40473-40476`, `18939-18945`, `17488`, `17665`).

**Dropping handles.**
`LogisticCommander:pruneGroupMenus(groupid, groupname)` is the single clean-up, called when the player's aircraft is gone (after ejection handling, and from the player-aircraft clean-up of the event dispatcher) (`zoneCommanderv2.lua:97785`, `42158`, `43034`).
It bumps the group's menu token first, which invalidates every queued or delayed menu job for that group id (`zoneCommanderv2.lua:97786`, `97779-97783`).
It then checks whether a live DCS group with that name still has that id: if yes it calls `missionCommands.removeItemForGroup` on each tracked handle; if not it **only forgets the handles without calling DCS**, per the comment "Retire native handles without touching DCS when this group is no longer available" (`zoneCommanderv2.lua:97796-97800`, `97825-97873`).
It also clears the Moose CTLD menu fields cached on the Moose group object (`zoneCommanderv2.lua:97816-97823`).

**Reproduction notes.**
Removing and re-adding F10 items for many groups in one frame is the cost being avoided.
Stale handles are the main hazard: a group id can be reused by another player, hence the token and identity checks before every deferred menu operation (`zoneCommanderv2.lua:97779`, `40473-40476`).

## Message output and localisation

**Player view.**
F10 → stats menu → `LANGUAGE_MENU_SET` lists 10 languages; choosing one shows `LANGUAGE_SET_RESLOT` in the new language, and menus change at the next slot selection (`zoneCommanderv2.lua:101214-101231`, `96-107`).
Languages: EN, DE, FR, ES, RU, PT-BR, TR, IT, zh-CN, zh-TW (`zoneCommanderv2.lua:96-107`, `Config:204-217`).

**Admin view.**
`FootholdLocale` (default `"EN"`) sets the server language used for texts sent to everybody or to a coalition (`Config:204-221`).

**Mechanism.**
`Foothold_Localization.lua` defines the global `FootholdLocalization` with `Messages[locale][KEY] = text` (`Foothold_Localization.lua:14-27`).
`Get(key, locale)` looks in the requested locale, then in the default locale (EN), then returns the key itself (`Foothold_Localization.lua:20865-20879`).
`Format(key, ...)` is `string.format` on the result (`Foothold_Localization.lua:20881-20891`).
Map-specific strings are added with `Register(locale, entries)`; a locale without its own table for a map falls back to that map's EN table (`Foothold_Localization.lua:20840-20847`, `24621-24622`).
Three scopes of language exist: the server locale (`SetLocale`), a per-player locale keyed by player name (`SetPlayerLocale`, `Foothold_Localization.lua:20931-20948`), and a per-group binding made at birth with `BindGroupLocale(groupId, playerName)` (`Foothold_Localization.lua:20950-20977`, `zoneCommanderv2.lua:101469`).
`ForGroup(groupId)` / `ForLocale(locale)` return a cached "view" object `T` with `Get`/`Format` bound to one locale; menu builders receive `T` (`Foothold_Localization.lua:21000-21018`, `zoneCommanderv2.lua:101202-101204`).
The engine reaches it through a local facade `L10N` whose methods forward to `FootholdLocalization` (`zoneCommanderv2.lua:75-93`); `L10N:` is called 875 times in the engine (grep).
Player locales are saved in the campaign file and restored on load (`Foothold_Localization.lua:21024-21049`, `zoneCommanderv2.lua:25741-25743`).

**Output primitives.**
Raw `trigger.action.outText`, `outTextForCoalition`, `outTextForGroup`, `outTextForUnit`: 574 calls; `trigger.action.outSound*`: 67 calls; Moose `MESSAGE:New(...):ToAll()/ToGroup()`: 43 calls (counts by grep on the engine).
A coalition-wide text can only be in one language, so those use the server locale; per-group texts use the group's locale (`zoneCommanderv2.lua:101447-101448` shows both forms side by side).

**Reproduction notes.**
Because the per-player locale is keyed by name and the per-group one by group id, a language change only reaches menus after a re-slot.
The `Foothold_Localization.lua` file is 38 857 lines for 10 locales and is loaded before the config, which calls `SetLocale` (`mission:58`, `Config:220-222`).

## Moose dependency census

Counts are occurrences of `CLASS:method` or `CLASS.field` found by grep; they are approximate (comments included, instance methods on Moose objects not counted).

**Engine (`zoneCommanderv2.lua`).**

| Moose class | Count | What it is used for | Weight |
|---|---|---|---|
| `UTILS` | 384 | unit conversions: `NMToMeters` 111, `FeetToMeters` 71, `KnotsToKmph` 32, `KnotsToMps` 21, `MpsToKmph` 21, `MetersToNM` 17, `IasToTas` 12; `DeepCopy` 34; `VecDist` 25; `GetMarkID` 8; file helpers `SaveToFile`/`LoadFromFile`/`Split` | trivial helpers |
| `COORDINATE` | 182 | `COORDINATE:New` 132, `NewFromVec*` 46: positions, waypoints, bearings | medium: a vector class with route-point builders |
| `SCHEDULER` | 97 | timers (see above) | light |
| `GROUP` | 86 | `GROUP:FindByName` 85: wrapper objects to call controllable methods (routes, tasks, options) | medium |
| `AIRBASE` | 61 | `FindByName` 26, `FindByID` 10, `TerminalType` 21: parking spots and airbase lookup | medium (parking data) |
| `SPAWN` | 50 | `NewFromTemplate` 19, `NewWithAlias` 12, `New` 4, `SPAWN.Takeoff` 15; 42 `:Spawn…(` calls | heavy: AI aircraft spawning at airbases and in the air |
| `MESSAGE` | 43 | some on-screen messages | trivial |
| `ZONE` | 39 | `ZONE:FindByName` 37 | light |
| `BASE` | 35 | logging (`BASE:I`, `BASE:E`), tracing | trivial |
| `_DATABASE` | 32 | `Templates.Groups` 26: template registry | hidden but structural |
| `STORAGE` | 26 | `STORAGE:FindByName` 23: warehouses | medium |
| `ENUMS` | 14 | constants (ROE, formations…) | trivial |
| `CTLD` | 9 | references to the CTLD instance | see logistics theme |
| `EVENTS` | 8 | two handlers | trivial |
| `SET_GROUP` / `SET_CLIENT` / `SET_ZONE` | 7 / 3 / 1 | table above | light |
| `MENU_GROUP` | 7 | logistics menu only | light |
| `UNIT`, `STATIC`, `CLIENT`, `SPAWNSTATIC` | 7 / 5 / 2 / 4 | occasional wrappers | trivial |
| `TIMER` | 6 | warehouse save stagger | trivial |
| `AUFTRAG` | 6 | `NewANTISHIP`, `NewINTERCEPT`, `NewARTY` | heavy subsystem, 6 call sites |
| `FLIGHTGROUP` / `NAVYGROUP` / `ARMYGROUP` | 3 / 2 / 1 | battleship counter-strike, navy striker, intercept hunt, naval and V1 artillery | heavy subsystem (OPS), few call sites (`zoneCommanderv2.lua:10932-10944`, `41099-41101`, `70022-70044`, `109998-110075`, `111165`, `111330`) |
| `MANTIS` | 3 | red and blue integrated air defence (`zoneCommanderv2.lua:111399`, `111485`) | heavy subsystem |
| `ZONE_RADIUS`, `ZONE_UNIT`, `ZONE_GROUP` | 2 / 1 / 1 | ad-hoc zones | trivial |
| `BEACON`, `MARKER`, `ASTAR`, `USERSOUND`, `_SETTINGS` | 2 / 1 / 1 / 1 / 2 | TACAN constants, one marker, one path search, one sound | trivial |

Not used by the engine at all (0 hits): `INTEL`, `CSAR`, `ATIS`, `MSRS`, `SOCKET`, `PLAYERTASK*`, `AIRBOSS`, `MENU_COALITION`, `MENU_MISSION`, `EVENTHANDLER`, `OPSGROUP`, `CHIEF`, `AIRWING` (only commented `BASE:TraceClass` lines mention some, `zoneCommanderv2.lua:35425-35426`, `105299-105300`).
The engine's own `require("socket")` at `zoneCommanderv2.lua:48459` is LuaSocket, not Moose `SOCKET`.

**For comparison, raw DCS API in the engine**: `Group.getByName` 381, `trigger.action.outText*` 574, `missionCommands.*` 392, `timer.scheduleFunction` 162, map markup calls 113 + 30 drawing calls, `StaticObject.getByName` 71, `Unit.getByName` 23, `coalition.addGroup` 3 (inside the engine's own respawn helpers), `coalition.addStaticObject` 6.

**Satellite scripts.**

| File | Moose classes (count) |
|---|---|
| `Foothold CTLD.lua` | `CTLD_CARGO` 48, `CTLD` 32, `STORAGE` 20, `MESSAGE` 14, `UTILS` 11, `BASE` 11, `GROUP` 10, `COORDINATE` 9, `SCHEDULER` 8, `AIRBASE` 6, `ZONE_RADIUS` 4, `ZONE` 4, `TIMER` 4 |
| `Foothold_CTLD_Red.lua` | `CTLD_CARGO` 15, `CTLD` 14, `STORAGE` 6 |
| `EWRS.lua` | `UTILS` 61, `EVENTS` 10, `UNIT` 4, `SET_UNIT` 3, `SET_CLIENT` 1 |
| `WelcomeMessage.lua` | `MESSAGE` 35, `UTILS` 25, `MENU_GROUP_COMMAND` 15, `MENU_GROUP` 7, `SCHEDULER` 8, `UNIT` 8, `GROUP` 6, `EVENTS` 6, `COORDINATE` 4, `SPAWN` 3, `SET_CLIENT` 2 |
| `Zeus.lua` | `ZONE_RADIUS` 3, `SPAWN` 1, `EVENTHANDLER` 1, `COORDINATE` 1 |
| `MA_Setup_CAv2.lua` | `_DATABASE` 15, `UTILS` 8, `SCHEDULER` 6, `GROUP` 6, `AIRBASE` 3, `ZONE` 2, `SPAWN` 2 |

**Reading of the census.**
The engine core (zones, capture, persistence, menus, messages, events, timers, garrison spawning) is written against the raw DCS API with Moose used as a utility library.
The Moose classes that carry real weight are `SPAWN` (AI flights), `COORDINATE`/`GROUP`/`AIRBASE` (routing and parking), `STORAGE` (warehouses), `MANTIS` (air defence), the OPS classes at six call sites, and `CTLD`/`CTLD_CARGO` in the logistics scripts.

## Seen outside this theme

- Zone suspension and wake-up (despawn of garrisons far from the front, snapshot of survivors): `zoneCommanderv2.lua:37445`, `47925`, `48044`.
- "Should spawn" evaluation dispatcher for AI groups (queues per mission type, budget per tick): `zoneCommanderv2.lua:17982-18060`.
- Warehouse aircraft availability, `allowedPlanes*` lists and `restockAircraft`: `Config:2622`, `Config:3144`, `zoneCommanderv2.lua:20074` (`CopyWarehouse`), `19949`.
- `WarehouseWeaponLocationPolicy` (which weapons may be stored where): `zoneCommanderv2.lua:51153-51258`.
- Dynamic FARPs built by players, their save file and startup restore: `Foothold CTLD.lua:7609-7850`, `zoneCommanderv2.lua:111570-111630`.
- Carrier navigation (stations, lanes, Tarawa custom routes) and its saved state: `zoneCommanderv2.lua:14041-15700`.
- Tanker and AWACS persistence and the `arcohere`/`texacohere`/`caphere` markers: `zoneCommanderv2.lua:28149`, `106153`.
- Career statistics and achievements (`CAREER_STAT`, per-aircraft metrics): `zoneCommanderv2.lua:12021-12956`, `44089-44212`.
- Difficulty scaling (`difficultyModifier`, fade over time): `zoneCommanderv2.lua:43268-43272`, `8586`.
- Roaming of garrison groups between sub-zones (staggered moves by `SCHEDULER`): `zoneCommanderv2.lua:27895-28108`.
- Runway destruction blocking AI plane spawns for 3300 s: `zoneCommanderv2.lua:42906-42920`.
- Hercules cargo air-drop supply on `S_EVENT_SHOT`: `zoneCommanderv2.lua:102303-102444`.
- External "SITAC" tooling fed by `foothold.status`, `zonesDetails`, `connections`, `missions`, `players`: `zoneCommanderv2.lua:25745-25802`, `44557-44568`.
- `Foothold Config Manager` Windows tool and its `-- @gui` annotations: `tools/FootholdConfigManager/README.md`, `Config:201`.
