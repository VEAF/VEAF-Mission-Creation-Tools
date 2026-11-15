# 06 — Player support tools (Foothold v6.5.3)

Scope: everything that helps a player fly and fight, outside the shop/economy rules, CTLD, AI flight execution and zone capture.
File names are shortened: `zc2` = `Common Scripts/zoneCommanderv2.lua`, `setup` = `Setup files/MA_Setup_CAv2.lua`, `WM` = `Common Scripts/WelcomeMessage.lua`, `loc` = `Common Scripts/Foothold_Localization.lua`, `cfg` = `Common Scripts/Foothold Config.lua`.

| # | Feature | One-line description | Main code location |
|---|---|---|---|
| 1 | JTAC drone (auto-lase) | purchased drone orbits an enemy zone, lases/IR-points one target, coalition menu for target, priority, code, smoke, flare | `zc2:7366-8148`, `setup:4234-4291` |
| 2 | 9-line JTAC drones (AM/FM) | purchased drone with the native DCS `FAC` task on 241 AM / 31 FM | `zc2:8150-8400`, `setup:4292-4470` |
| 3 | Player laser designator (`SelfJtac`) | scout aircraft lase targets in a cone in front of them, per-player options | `zc2:96368-97550` |
| 4 | CSAR and enemy pilots | downed pilots spawned on ejection, beacon, marker, hover/land pickup, hostile infantry, enemy-pilot capture and debrief | `zc2:98446-101025`, `zc2:101831-102230`, `zc2:42284-42440` |
| 5 | Zone intel | purchased 60-min intel: contents report, per-group map markers, diff updates | `zc2:5567-7014`, `setup:4762-4794` |
| 6 | Tankers on demand and control | Arco/Texaco spawn, TACAN, racetrack by menu or by markers, altitude/speed menus | `zc2:105300-106250`, `zc2:107547-107930`, `zc2:16696-17080` |
| 7 | AWACS | always-on AWACS repositioned behind the front after each capture | `zc2:9331-10146` |
| 8 | CAP control | menu and `caphere1/2` markers to move the purchased CAP | `zc2:28148-28352`, `zc2:105747` |
| 9 | Map-marker commands | the full list of marker texts understood by the engine | `zc2:28354-29290` |
| 10 | Carrier and ship control | "Sail to area" menu, Tarawa by marker, wind-over-deck speed, beacons, recovery tanker | `zc2:13403-16200`, `WM:779-926` |
| 11 | Welcome message, callsigns/IFF, ATIS | greeting, callsign and IFF allocation, ATIS menu, closest airfield, capture ATIS, refuel reward | `WM:1-1723`, `WM:2731-2941` |
| 12 | Escort flight for players | free 2-ship escort on request, altitude choice, patrol/racetrack/orbit/rejoin/RTB | `WM:1434-1470`, `WM:1724-2730` |
| 13 | EWRS | radar-based BRA picture, bogey dope, per-player settings menu | `EWRS.lua:1-1745` |
| 14 | Zeus | game-master marker commands (`-create`, `-destroyN`, `-explode`, `-smoke`, `-illuminate`) | `Zeus.lua:1-105`, `zeus_Full_v2.1.lua` |
| 15 | Smoke / flare / illumination on targets | purchased marking of up to 3 targets of an enemy zone | `zc2:23618-23775`, `setup:4547-4634` |
| 16 | `DynamicSupportNative` | registry and 30 s ammo monitor of purchased AI flights (airborne, winchester, landed, killed messages) | `zc2:106261-106469` |
| 17 | Hunt | red 2-ship sent after a player with many kills | `zc2:40974-41168` |
| 18 | Splash damage (Foothold variant) | splash kills credited to players, options tuned | `Splash_Damage_3.4.1_leka.lua` |
| 19 | Help, radio information, weather | help texts, radio settings validation, kneeboard frequency card, wind/temperature read-outs | `zc2:13632-13690`, `loc:2055` |

Moose subsystems: **none of `CSAR`, `INTEL`, `ATIS`, `AIRBOSS`, `RECOVERYTANKER`, `RESCUEHELO`, `MSRS` is instantiated** by the Foothold scripts of this theme (grep for `<CLASS>:New` in `zoneCommanderv2.lua`, `WelcomeMessage.lua`, `EWRS.lua`, `Zeus.lua`, the setup file: 0 hits).
Moose is used as a toolbox: `SPAWN`, `SCHEDULER`, `COORDINATE`, `UTILS`, `MESSAGE`, `MARKER`, `MENU_GROUP*` (WelcomeMessage only), `SET_CLIENT`, `ZONE*`, `AIRBASE`, `ASTAR`, `EVENTS`/`BASE:HandleEvent`.
Scripts shipped in the Caucasus `.miz`: `AIEN.lua`, `EWRS.lua`, `Foothold Config.lua`, `Foothold CTLD.lua`, `Foothold_CTLD_Red.lua`, `Foothold_Localization.lua`, `MA_Setup_CAv2.lua`, `Moose_2026-10-11.lua`, `Splash_Damage_3.4.1_leka.lua`, `WelcomeMessage.lua`, `Zeus.lua`, `zoneCommanderv2.lua`.

## 1. JTAC drone (auto-lase) — `JTAC`

### Player view

- Bought through the shop item `jtac` ("JTAC MQ9" label key `SYRIA_SHOP_ITEM_JTAC_MQ9`), then a target zone is picked; the zone must be red and not suspended (`setup:4246-4275`).
- A coalition-wide F10 submenu "JTAC … <zone>" (`JTAC_MENU_TITLE`) appears with: Target report, Next target, Smoke on target, Change smoke color (5 colours), Flare on target, Set priority (SAM / Structures / Infantry / Armor / Support / Clear), Set laser code (three-level digit dial 1111–1788, then "Accept"), Select target (numbered list, "More" submenus every 9 entries) (`zc2:7522-7720`, `zc2:8054-8148`).
- Messages are coalition-wide text: "JTAC is deployed, Looking for targets, standby" (`loc:1498`), the lasing report "Lasing <type> at <zone> … Code: <n>" followed by DDM, DMS, MGRS and altitude m/ft (`zc2:7781-7843`, `loc:1502`), "kill confirmed", "no more targets".
- The laser code can also be set by a map marker whose text is `jtac-code:<1111-1788>`; the marker is deleted after use (`zc2:7403-7418`).
- At most two JTAC drones at once; buying a third destroys the oldest (`setup:4255-4259`).
- Smoke is dropped 50–100 m from the target at a random bearing and the message gives the offset and the cardinal direction from smoke to target; flare is a red signal flare 20–40 m away (`zc2:7556-7592`, `zc2:7631-7663`).

### Mission-maker view

- The `.miz` needs late-activated drone groups named `jtacDrone1`, `jtacDrone2` (modern) and `jtacDroneColdwar1`, `jtacDroneColdwar2` (cold-war era, an F-14 "Tomcat" per the message keys); the setup destroys all four at start and builds the `JTAC` objects from the pair matching `ColdWarTechEra` (`setup:4236-4245`).
- The auto-lase JTAC is **not registered in PvP mode** (`GlobalSettings.pvpEnabled ~= true` guard, `setup:4240`, `setup:4291`).
- Price in `ShopPrices.jtac = 500`, rank requirement table entry `jtac = 2` (`setup:2908`, `setup:2945`).
- `UseStatics` adds the "Structures" priority category (`zc2:7372-7374`).

### Mechanism

- 100 % Foothold code on raw DCS API; Moose is used only for spawning (`SPAWN:NewFromTemplate(tpl, name, nil, true):OnSpawnGroup(...):SpawnFromCoordinate(coord)` → `coalition.addGroup` with the template taken from `_DATABASE.Templates.Groups[name].Template`), for the 5-second loop (`SCHEDULER:New(nil, self.searchIfNoTarget, {self}, 20, 5)` → `timer.scheduleFunction`), and for `COORDINATE`/`UTILS.tostringMGRS`/`UTILS.VecHdg` formatting (`zc2:7980-8003`, `zc2:7781-7830`).
- Deployment: the drone is spawned at 6 000 m above the zone centre (`zoneCom._cz.point`), then `setOrbit` sets it `SetInvisible`, `SetImmortal`, `SetUnlimitedFuel`, `EPLRS` on, `AI.Option.Air.id.SILENCE`, and gives it an `Orbit` / `Circle` task at 6 000 m; first target search 15 s later (`zc2:7980-8052`).
- Deploying also cancels any recon mission on that zone and sets `jtacIntelActive[zone] = true` (the zone is treated as "intel known" while a JTAC is over it) (`zc2:7986-7989`).
- Target list: every unit with `getLife() >= 1` of every group name in `zone.built`, every existing static of that list, plus the zone warehouse target; the list is cached in `zone._jtacTargetSnapshot` and rebuilt when one cached object is dead (`zc2:7420-7457`); the zone's own maintenance loop publishes the snapshot when a drone watches the zone (`zc2:46078-46100`).
- Priority filter: `Unit:hasAttribute(attr)` against the category attribute lists; "StaticObjects" matches `Object.Category.STATIC`; if nothing matches the priority is cleared with a message (`zc2:7888-7910`).
- Sort: lowest rank wins among attributes `SAM TR`=1, `IR Guided SAM`=2, `SAM SR`=3, `AAA`=4, `Tanks`=5, `IFV`=6, `APC`=7, `Artillery`=8, `SAM LL`=9, `SAM CC`=10, `Unarmed vehicles`=11, `Infantry`=12, `Structures`=13; a unit that is both AAA and radar gets +0.1 (`zc2:7459-7501`).
- Lasing: `Spot.createLaser(emitterUnit, {x=0,y=2,z=0}, targetPoint, code)` and `Spot.createInfraRed(...)`; both spots are moved with `Spot:setPoint` by a self-rescheduling 0.5 s timer (`timer.scheduleFunction`) as long as the target lives (`zc2:7731-7779`).
- Loop every 5 s (`searchIfNoTarget`): if the drone group is gone → clear; if target dead → "kill confirmed", hold 5 s, then next target; if the count of viable targets dropped → rebuild the Select-target menu (`zc2:7942-7978`, `zc2:7911-7922`).
- "Next target" picks a random viable target (`randomNext`), otherwise the top of the threat sort (`zc2:7924-7928`).
- End of life: no targets left or zone no longer hostile → `clearTarget` destroys the spots, stops the scheduler, destroys the drone group, removes the menu and removes itself from `jtacQueue` (`zc2:7845-7876`, `zc2:7930-7938`).
- State: global `jtacQueue` (active drones, max 2), `jtacIntelActive[zone]`, per-object `lasers`, `target` (unit name), `laserCode`, `priority`, `smokeColor`.
- Menus are **coalition** menus (`missionCommands.addSubMenuForCoalition`), not per group; the laser-code dial alone creates several hundred menu nodes per drone (`zc2:7689-7708`).

### Reproduction notes

- No Moose dependency of substance; `Spot` API, `hasAttribute`, `trigger.action.smoke/signalFlare` are raw DCS.
- The drone needs the zone's list of spawned group names (`zone.built`) and the "intel" flag coupling.
- The 0.5 s laser-update timer per drone and the full re-sort on each search are the only recurring costs; two drones maximum bounds them.
- The marker listener is one `world.addEventHandler` per JTAC object (so two handlers, each parsing every mark change) (`zc2:7403-7418`).

## 2. 9-line JTAC drones (AM / FM) — `JTAC9line`, `JTAC9linefmr`

### Player view

- Shop items `9lineam` and `9linefm` (price 0, rank 1 in the Caucasus setup: `setup:2909-2910`, `setup:2991-2992`), then pick an enemy zone.
- The drone is a **native DCS FAC**: the player contacts it through the standard DCS radio menu (JTAC check-in, 9-line, laser/smoke/IR marking are all done by the DCS AI FAC logic).
- Frequencies: 241.000 MHz AM (`zc2:8245-8246`) and 31.000 MHz FM (`zc2:8374-8375`); callsign index `callname = 2`, `number = 1`, `designation = 'Auto'`, `datalink = true`.
- A coalition message announces the drone and its frequency (keys `SYRIA_SHOP_JTAC_REAPER_AM/FM`, `SYRIA_SHOP_JTAC_TOMCAT_AM/FM`) (`setup:4327-4338`).

### Mission-maker view

- Late-activated groups `JTAC9lineam`, `JTAC9lineamColdwar`, `JTAC9linefm`, `JTAC9linefmColdwar` in the `.miz`; destroyed at start, respawned from template (`setup:4296-4313`, `setup:4353-4371`).
- In PvP mode one object per side is created (the red one from a mirrored template) and both sides can buy it (`setup:4299-4308`, `setup:4345`).

### Mechanism

- Spawn at 6 000 m over the zone centre via `SPAWN:NewFromTemplate():SpawnFromCoordinate()`; `setTasks` applies `SetInvisible`, `SetImmortal`, `SetUnlimitedFuel`, `EPLRS`, then a `ComboTask` of `{id='FAC', params={frequency, modulation, callname, number, designation='Auto', datalink=true, priority=1}}` + `Orbit` circle at 6 000 m (`zc2:8162-8275`).
- `jtacZones[zone] = {drone = <group name>}` records which zone has a 9-line drone; `CheckJtacStatus()` destroys the drone when its zone is no longer an active enemy zone (`setup:4412-4470`); it is called from two places in `ZoneCommander` (`zc2:50222`, `zc2:55422`), presumably the capture/disable paths — (estimation) for the caller context.
- `BattleCommander:_hasActiveJtacOnZone` answers "is a JTAC (either kind) on this zone" for other subsystems (`zc2:37190-37216`).
- Everything the player hears is the DCS built-in FAC; Foothold writes no 9-line text itself.

### Reproduction notes

- Trivial without Moose: one `coalition.addGroup` and one `Controller:setTask`.
- The FAC task engages "Auto": DCS chooses targets among what the FAC detects; there is no Foothold target list here.

## 3. Player laser designator — `SelfJtac` ("Laser Designator" menu)

### Player view

- Group F10 submenu "Laser Designator" (`loc:1510`) for players flying one of the listed types: SA342L, SA342M, UH-60L, UH-60L_DAP, AH-6J, OH-6A, Bronco-OV-10A, F-4E-45MC (`zc2:97528-97542`).
- Entries: Search, Target info, Mark with Smoke, Clear, Priority (SAM / Infantry / Armor / Support / Structures / Clear), Options (Toggle KM / NM, Auto Search on/off, Auto-Next Target on/off, Hide coordinates on/off, Ignore structures on/off, Laser code dial), Select target (`zc2:96617-96746`).
- Report (group text, 60 s, clear-view): target type, laser code, magnetic bearing and distance from the player, then DDM / DMS / MGRS / altitude unless "hide coordinates" is on (`zc2:96963-97026`).
- "Mark with Smoke" puts **blue** smoke exactly on the target (`zc2:97029-97042`).
- Messages: "target out of bounds" when the target leaves the cone/range/line of sight, "kill confirmed", "no targets found", "target lost".

### Mission-maker view

- No Config switch found for the type table; the per-type limits are hard-coded: `minDist` (really the **maximum** range, km), `maxDeviation` (half-cone in degrees off the nose), `laserOffset` (IR pointer origin on the airframe) (`zc2:97528-97536`).
- Per-player options (auto search, auto next, hide coordinates, ignore structures) are persisted by player name and exported/imported with the rank save (`zc2:96393-96506`, `zc2:43833-43843`).

### Mechanism

- 100 % Foothold code; Moose only for `COORDINATE:HeadingTo`, `GetMagneticDeclination`, `ToStringMGRS` in the report (`zc2:96983-97007`).
- Creation: on player spawn, `LogisticCommander:_refreshSelfJtacForSpawn` builds a `SelfJtac` for the group if the unit type has stats, replacing any previous one (`zc2:101266-101287`); `setAirborne(true)` on takeoff and `setAirborne(false)` on landing/leave (`zc2:101806-101808`, `zc2:42451-42453`), landing clears the target (`zc2:96804-96814`).
- Search: `world.searchObjects({UNIT, STATIC}, SPHERE(player ground point, radius = minDist km))`, keep enemy-coalition active objects, then filter by distance, by `|bearing − aircraft heading| <= maxDeviation`, and by `land.isVisible(playerPoint+1.5 m, targetPoint+1.5 m)` (`zc2:97245-97311`).
- Choice: nearest viable target to the player, or — after a kill with auto-next — nearest to the previous target's last position with preference for the same enemy group (`zc2:97347-97371`, `zc2:97165-97181`).
- Tracking: `setTarget` re-checks range/cone/LOS, creates `Spot.createLaser(playerUnit, {0,5,0}, surfacePoint, code)` and `Spot.createInfraRed(playerUnit, laserOffset, point)`, moves them only if the target moved ≥ 0.5 m, and reschedules itself every **0.1 s** (1 s while re-acquiring) through `timer.scheduleFunction` (`zc2:96872-96961`).
- Loss of track with auto-search on: spots are destroyed, state `_reacquiring`, and each tick tests at most 3 cached targets (round-robin cursor) for visibility to hop to another target (`zc2:96911-96925`, `zc2:97086-97135`).
- Auto search: a 30 s per-player timer while airborne (`zc2:96789-96796`).
- Target metadata (category, display type, group name, attributes) is cached per target name and pruned to the objects seen in the last search (`zc2:96508-96556`).
- State: `SelfJtac.jtacs[groupId]`, `SelfJtac.savedPlayerSettings[playerName]`.

### Reproduction notes

- Per-player 10 Hz timer while a target is lased is the performance-relevant part; the search itself is a `world.searchObjects` sphere of up to 30 km radius, run on demand or every 30 s.
- The laser emitter is the player's own unit (`Spot.createLaser` with a player unit as source works in DCS), so the spot follows the aircraft.
- Menus are per group and rebuilt selectively (option items removed and re-added to show the current ON/OFF state) (`zc2:96686-96727`).

## 4. CSAR: downed pilots, rescue, enemy pilots

**None of this is Moose `CSAR`.**
The whole feature is Foothold code inside `LogisticCommander` (`zc2:98446-101025`, `zc2:101831-102230`); Moose is used for spawning (`SPAWN:NewWithAlias():InitCoalition():SpawnFromPointVec3()` → `coalition.addGroup`), for moving the survivor (`GROUP:RouteToVec2` → a `Mission` task with ground waypoints via `Controller:setTask`), for `COORDINATE:Translate/HeadingTo`, and for `SCHEDULER`.

### Player view

- Group F10 submenu "CSAR" for aircraft whose type has a capacity > 0 in `AllowedCsar`: Info on closest pilot, Info on three closest pilots, Deploy smoke at closest pilot, Deploy flare at closest pilot, Smoke nearest zone, Flare nearest zone (these two call the CTLD object's `SmokeZoneNearBy`), and — when the enemy-pilot template exists — Info on closest enemy pilot, Deploy smoke at closest enemy pilot (`zc2:101522-101553`, `loc:1808-1814`).
- Each downed friendly pilot has a coalition map marker whose label is "[player] Lost: N Credits" or "Downed pilot", plus "ADF: nnn kHz"; enemy pilots are labelled "enemy pilot" (`zc2:99283-99362`, `loc:1830-1833`).
- Each friendly pilot transmits an ADF beacon (`beacon.ogg`) on a random frequency 250–700 kHz, 1 000 W (`zc2:100578-100602`).
- Rescue flow: within 3 km the pilot answers ("We hear you! Request smoke if needed", bearing/distance info) and fires 3 flares; within 650 m "You're close now! I'm at your N o'clock. Land in a safe place, we will come to you" and 3 more flares; if the helicopter is on the ground within 650 m the survivor runs to it ("I'm coming to you. ETA n seconds") and boards within 20 m; alternatively a hover pickup: within the hover distance, below the hover height and under 5 m/s for the hover time, with "Forward/Right/Left/Back n m, descend n ft" guidance and a countdown (`zc2:100612-100692`, `zc2:100387-100440`, `zc2:100953-100996`, `zc2:97764-97766`, `loc:1846-1858`).
- Boarding adds `PilotWeight` (80 kg) per pilot to the aircraft (`trigger.action.setUnitInternalCargo`) and prints "Pilot onboard [n/max]" (`zc2:98766`, `loc:1862`).
- Drop-off: land in a friendly zone; "Pilots dropped off", and each rescued player gets his "Deaths" stat decremented (`zc2:98767-98774`).
- The lost credits appear to be paid back at pick-up (message "[X] rescued [Y] +N credits. Land at any friendly zone to drop off.", `loc:1860`); the paying code inside `boardPilot` (`zc2:100440-100576`) was not read — (estimation).
- A player who ejects and lands **inside a friendly zone** is "landed safely" and gets the lost credits back; inside an enemy zone he gets a 60 s grace then is treated as in hostile territory, or "captured by enemy forces … Assumed dead" (`zc2:101926-101957`).
- A survivor within 3 NM of a friendly zone or FARP runs home by himself at 3.6 m/s ("Ejected Pilot X is running toward Y"), and is completed on arrival ("is now home", credits recovered); a nearby helicopter can interrupt the run to pick him up (`zc2:99761-99811`, `zc2:99677-99743`, `zc2:100694-100728`, `loc:1837-1841`).
- Enemy infantry: 25 % chance (Config) that 1–3 hostile infantry groups spawn 0.2–0.4 NM around a downed pilot who is outside any zone and within 20 NM of an enemy zone; 120 s later the coalition is told "Enemy forces have surrounded [X]. Hurry and save him" (`zc2:101977-102112`, `zc2:102196-102217`).
- Enemy pilots (PvE): a red AI pilot who lands after ejection inside a blue zone is "captured" at once; elsewhere a `RedDownedPilot` group is spawned and can be picked up (load distance 50 m) and delivered to a friendly zone for `enemyPilotCapture` credits (default 200) and a "debrief" (`zc2:101904-101924`, `zc2:100767`, `zc2:42284-42311`).
- Approaching an enemy pilot has a 10 % chance of an ambush (1–3 infantry groups, message `CSAR_ENEMY_AMBUSH`) (`zc2:98474-98541`).
- Debrief of captured pilots (10–60 s later): 50 % chance per pilot of zone intel on one enemy zone, 20 % chance of a message revealing the enemy Director's current operation target/phase or defensive priority, else one of 7 "debrief failed" lines (`zc2:42313-42363`).

### Mission-maker view

- Templates in the `.miz`: `Downed Pilot` (blue), `RedDownedPilot` (its presence switches enemy-pilot CSAR on: `zc2:102274`), `CSAR_RED_INF_1`, `CSAR_RED_INF_2` hostile infantry (`zc2:97724`).
- Config (`cfg:2198-2257`): `AllowedCsar` (type → seats; 0 hides the menu; e.g. UH-1H 11, Mi-8MT 24, CH-47 32, AH-64D 2), `CsarPilotSpawnWithoutCreditsChance = 50`, `Max_CSAR_At_Once = 10`, `Max_CSAR_AT_Mission_Restart = 10`, `PilotWeight = 80`, `CsarHoverDistance = 20`, `CsarGuidanceDistance = 70`, `CsarHoverHeight = 60`, `CsarHoverSeconds = 10`, `CsarHostileInfantryChance = 25`.
- Hard-coded: approach 3 000 m, extract 650 m, load 20 m (`zc2:97764-97766`); home run 3 NM / arrival 120 m / 3.6 m/s unless `CsarHomeDistanceNM`, `CsarHomeArrivalDistance`, `CsarHomeRunSpeed` are defined (`zc2:97719-97721`).
- Reward `enemyPilotCapture = 200` in the rewards table (`cfg:1931`).
- Hostile infantry are skipped on the Normandy map (`zc2:101977`).

### Mechanism

- Events (one `world.addEventHandler` in BattleCommander): `S_EVENT_EJECTION` → `_handleRewardEjection` records who ejected and the credits lost, keyed by aircraft id (`ejectedPilotOwnersByAircraft`) (`zc2:43081-43086`, `zc2:42133`); `S_EVENT_LANDING_AFTER_EJECTION` → `_handleLandingAfterEjection(event, pilotUnit, aircraftID = event.place.id_, …)` (`zc2:42980-42991`).
- On landing: water → the DCS pilot object is destroyed and nothing happens; AI pilot without owner data → spawned only with `CsarPilotSpawnWithoutCreditsChance`; one survivor per AI aircraft; otherwise a `Downed Pilot` group is spawned 10 m from the wreck/landing point (8 candidate headings, avoiding water) and set invisible to AI if hostiles were spawned (`zc2:101851-101888`, `zc2:101960-101975`, `zc2:102113-102126`, `zc2:102139-102183`).
- The pilot record (`player`, `coalition`, `lostCredits`, `timestamp`, hostile group names, ambush flag) is bound to the spawned unit's object id in `csarPilotDataByObject` / `landedPilotOwners`; the unit goes into `self.ejectedPilots` (`zc2:102186-102229`, `zc2:100244-100290`).
- Main loop: `SCHEDULER:New(nil, self.update, {self}, 10, 10)` — every 10 s (`zc2:102276`); it prunes dead survivors (KIA message), refreshes beacons (re-emitted only if the point changed, checked every 25 s), then for each survivor × each eligible player aircraft computes distance and applies the thresholds above (`zc2:100237-100300`, `zc2:100757-101023`).
- Adaptive polling: per survivor a `csarNextTick` (10 s beyond 3 km, 5 s inside, 3 s inside 650 m, 1 s when loading/hovering) and, when a helicopter is near, a dedicated fast `timer.scheduleFunction` loop every 3 s; the hover countdown has its own 2 s timer per (pilot, group) (`zc2:100997-101015`, `zc2:100912-100918`, `zc2:100410-100432`).
- Messages are de-duplicated per (pilot, group) and clustered: a second survivor within 92 m and 20 s does not repeat the message (`zc2:100625-100638`).
- Carrying: `carriedPilots[groupId]` count and `carriedPilotData[groupId]` manifest; if the rescuing aircraft is lost its manifest is cleared (`zc2:43062-43068`); functions named `_cloneCarriedPilotDataForEjection` / `carriedRescuedPilots` suggest the carried survivors are re-spawned when the rescuer's crew ejects (`zc2:98638-98676`, `zc2:101953-101957`) — (estimation).
- Limit: the oldest survivors are removed beyond `Max_CSAR_At_Once` (`zc2:99960`); survivors are persisted and restored at restart (`zc2:100094`, `zc2:44890`).
- Smoke/flare at pilot: blue smoke on the nearest survivor, flare bursts via `_signalPilotFlareBurst` (`zc2:98830-98958`).

### Reproduction notes

- The identification of "which player ejected" relies on `event.place.id_` of `S_EVENT_LANDING_AFTER_EJECTION` being the aircraft object id recorded at `S_EVENT_EJECTION`.
- The DCS-native ejected pilot object is replaced by a controllable infantry group (so it can be routed and survive as a group); the native object is destroyed.
- Beacons use `trigger.action.radioTransmission(file, point, AM, loop, freq, power, name)` and must be stopped by name (`stopRadioTransmission`) when the survivor moves or is rescued.
- Cost model: O(survivors × eligible player aircraft) every 10 s, bounded by `Max_CSAR_At_Once`, with per-survivor back-off.
- The survivor "running home" and "running to the helicopter" need ground routing off-road and an arrival poll (30 s for home).

## 5. Zone intel ("Intel on enemy zone")

**Not Moose `INTEL`.** No `INTEL:New` exists in any Foothold file; the feature is a set of free functions `_zoneIntel*` (`zc2:5567-7014`) reading the zone's own list of spawned groups.

### Player view

- Entry point: shop item `intel`, then pick an enemy, non-suspended zone; message "gathering intel" (`setup:4762-4794`).
- 10 s later a coalition message with sound `Intel.ogg`: "Intel on <zone>:" then lines "Identified SAMs: …", "Armor: …", "Artillery: …", "Ground forces: …" (with MANPAD flag), "AAA: …", "Structures: …" (including "Warehouse building"), "Additional contacts: …" (`zc2:6387-6417`, `loc:1232-1273`).
- Map: one read-only coalition marker per alive enemy group/static of the zone, placed on its first alive unit and labelled with the group name, plus a marker on the zone warehouse (`zc2:6749-6821`).
- Every 20 s the markers follow the groups and an "Intel update on <zone>:" message lists differences: "X destroyed", "X detected", "TR destroyed; site degraded", "Enemy repaired X STR", "MANPAD threat neutralized…" (`zc2:6897-6907`, `loc:1233-1256`).
- While intel is active on a zone, other subsystems emit extra "Intel:" lines for it: a roaming group "is on the move", enemy aircraft "starting up at / just took off from / inbound and about to land at", "enemy convoy moving out from / about to arrive at", "The enemy is launching a mass attack on" (`loc:1257-1264`, `zc2:6691`).
- Duration: 60 min for a purchase, 30 min when granted by a captured enemy pilot; buying again while active keeps the later of the two expiries (it does not add) (`zc2:6962-6991`, `zc2:42411`); on expiry "Intel on <zone> has expired." (`zc2:6947-6950`).
- F10 group menu "Intel" lists the zones with active intel and reprints the current report (`zc2:103337-103393`); the map-marker command `intelstatus` on a zone prints its status with intel detail (`zc2:29068-29079`).
- No "extend coverage" wording was found in the localisation file under that name; the only extension mechanism read is the max-of-expiries above.

### Mission-maker view

- Globals `zoneIntelRefreshSec` (default 20, floor 5) and `zoneIntelStartupMessageDelaySec` (default 10) (`zc2:5567-5569`).
- Classification of contacts is by **group-name patterns** (functions `_zoneIntelMatchLongSiteName`, `_zoneIntelIsArmorGroupName`, `_zoneIntelIsAAAGroupName`, …), so it depends on the template naming convention of the setup file (`zc2:5783-5825`, not read in detail).

### Mechanism

- State per side and zone: `zoneIntels[side][zone]` (last snapshot, marker table, next refresh time), `intelExpireTimes[side][zone]`, `intelActiveZones[side][zone]` (`zc2:6954-7013`).
- No timer of its own: `_zoneIntelUpdateActiveZones(now)` is called at the end of every BattleCommander zone-update cycle (`zc2:43255-43258`) and self-throttles with `state.nextIntelAt` (`zc2:6882-6909`).
- Intel stops when the zone becomes neutral or friendly, or at expiry (`zc2:6873-6877`).
- Markers: Moose `MARKER:New(coord, text):ReadOnly():ToCoalition(side)`, moved with `UpdateCoordinate` when the point changed by more than 1 m (`MARKER` wraps `trigger.action.markToCoalition` / remove + re-add) (`zc2:6719-6726`, `zc2:6796-6803`).
- Starting intel cancels a pending recon mission on the same zone (`zc2:6999-7003`); a JTAC drone over the zone sets `jtacIntelActive[zone]` separately (`zc2:7989`).
- In PvE with the "SAM MFD reveal" option, blue intel on a red zone also reveals SAM sites (`revealSamSites`, `zc2:6885`).

### Reproduction notes

- The snapshot/diff message builder (≈450 lines, `zc2:6203-6660`) is the bulk of the work: it counts units per category, tracks radar loss per SAM site and compares two snapshots.
- It is "omniscient": no detection model, it reads the zone's own spawn list.
- Markers are per group, refreshed every 20 s only for zones with active intel.

## 6. Tankers on demand (Arco / Texaco) and their control

### Player view

- Shop items `dynamicarco` ("Tanker (Drogue)") and `dynamictexaco` ("Tanker (Boom)"): the purchase "unlocks" a coalition menu to choose the spawn zone, or directly takes zone + pattern from the group shop menu: "Orbit" or "Hot 360/045/…/315" × "10/20/30/40/50 NM Leg" (`setup:3099-3189`, `setup:3191`).
- On station message with TACAN (`101Y`/`102Y`), frequency (260 / 266 MHz AM) and preset hint (BTN 14 / 20) (`zc2:107766-107782`, `zc2:13651-13664`).
- Approaching within 2 000 ft horizontally / 500 ft vertically of the tanker shows "Approaching Arco, <radio info>" to that client (`zc2:105306-105312`, `zc2:105571-105597`).
- Group F10 "Tankers Control" (rank-gated): "<Tanker>: Move to Zone" (friendly zone → Orbit or heading → leg), "<Tanker>: Altitude" (list, current marked), "<Tanker>: Speed" (list in kt), "Tanker Help" (radio info + marker help) (`zc2:16795-17078`, `loc:1887-1926`).
- "Move by Position" menus are commented out, replaced by marker commands (`zc2:16912-16913`).
- Map markers `arcohere1` then `arcohere2` (or `texacohere1` / `texacohere2`): point 1 is drawn as a blue circle (250 m) with a text label "ARCO 1"; point 2 computes heading and leg from point 1 and sends the tanker; message "Arco moving, distance N NM. New racetrack: N NM leg, heading N°" (`zc2:28148-28352`, `loc:1952-1956`).
- A reposition is refused with "Players currently near the tanker. Try again later." while a player is close to it (`zc2:105340-105366`).
- The racetrack is drawn on the F10 map (`DrawDynamicTankerRacetrack`, `zc2:105861-105928`, not read in detail).

### Mission-maker view

- Templates `Arco` and `Texaco` in the `.miz` (spawned through `Respawn.SpawnAtPoint('Arco', …)`) (`zc2:107726-107728`).
- Config: `TankerRadioSettings` (`Blue Arco` 260 MHz / TACAN 101, `Blue Texaco` 266 / 102, `Shell` 253 / 103, `Red Arco` 260 / 104, `Red Texaco` 266 / 105; TACAN always Y band) (`cfg:356-369`); `TexacoSpeed = 286`, `ArcoSpeed = 286` kt (`cfg:2306-2311`); prices 1 000 and required rank 3 (`cfg:1776-1777`, `cfg:1860-1861`).
- Marker control requires a human-crewed, non-helicopter group of the owning side with rank ≥ the tanker's required rank (`zc2:28217-28232`).

### Mechanism

- Spawn: Foothold's own `Respawn.SpawnAtPoint` (`zc2:1344`) builds the group from the template at the zone, 1 s later applies protection commands (`ApplyProtectionCommandsToGroupController`), activates the TACAN with `Controller:setCommand({id='ActivateBeacon', params={type=BEACON.Type.TACAN, system=BEACON.System.TACAN_TANKER_Y, AA=true, bearing=true, …}})`, and sets the racetrack (`zc2:107734-107765`, `zc2:107591-107611`).
- Racetrack: `BuildOrbitTask(point, heading, legNm, TAS, altitude)` + `ApplyOrbitMissionToGroup(...)` — a raw mission/orbit task, IAS converted with `UTILS.IasToTas` (`zc2:106089-106110`).
- The station (point, heading, leg, zone, speed, altitude) is saved and restored after a restart (`_saveTankerStation`, `schedulePersistentTankerRestore`, `zc2:106112`, `zc2:106153`).
- Proximity message: a Moose zone attached to the tanker unit (`newUnitEnvelopeZone`, a `ZONE_UNIT`-like object) with `:Trigger(BlueClients)` where `BlueClients = SET_CLIENT:New():FilterCoalitions():FilterCategories("plane"):FilterActive():FilterStart()`; Moose polls set membership on a timer and fires `OnAfterEnteredZone` (`zc2:105305`, `zc2:105580-105595`).
- Marker handler: single `world.addEventHandler` on event id 26 (`S_EVENT_MARK_CHANGE`); pending point 1 kept in `bc._pendingDynamicTankerRacetrackPoints[kind]` with its drawing ids (`trigger.action.circleToAll`, `textToAll`) (`zc2:28242-28285`).

### Reproduction notes

- Only Moose-heavy part is the proximity zone on a `SET_CLIENT`; the rest is raw tasks.
- "Hot NNN" means the racetrack axis heading from the zone; "Orbit" is leg 0.
- A tanker lost in PvP is tracked (`_handlePvpSupportAircraftLoss`, `zc2:106043`).

## 7. AWACS (automatic, front-following)

### Player view

- One red AWACS and one or two blue AWACS are always airborne; players only use them through the DCS radio (AWACS menu) and datalink.
- Frequencies are shown in the welcome/briefing text and configured (`cfg:343-353`).
- PvP only: a lost AWACS stays lost until the shop item `replaceawacs` ("Replace one lost AWACS", 1 000 credits, rank 3) is bought; message "AWACS replaced" (`setup:3283`, `zc2:106029-106041`, `cfg:1779`, `cfg:1863`).

### Mission-maker view

- Templates `AWACS_RED`, `AWACS_BLUE` (or `AWACS_BLUE_VT` in the Vietnam era), `AWACS_BLUE_SECONDARY` (`AWACS_BLUE_VT_SECONDARY`), `AWACS_RED_SECONDARY_PVP` (`zc2:9331-9336`).
- Setup: `AWACS_CFG = { [1] = {alt=30000, speed=350, hdg=270, leg=15, sep=150}, [2] = {…, sep=70} }` where `sep` is the wanted distance in NM from the nearest enemy zone; spawned 10 s after start by `spawnAwacs(1|2, nil, 10)` (`setup:6046-6060`).
- Config `AWACSRadioFrequencies` (Blue 1 251, Blue 2 251.5, Red 1 252, Red 2 252.5 MHz AM) (`cfg:347-353`).

### Mechanism

- 100 % Foothold code on raw tasks (`Respawn.SpawnAtPoint`, `Controller:setCommand` `SetInvisible`, `SetImmortal` (PvE only), `SetUnlimitedFuel`, `EPLRS`, `REACTION_ON_THREAT = NO_REACTION`) (`zc2:10038-10146`).
- Station choice `_computeAwacsStationWithZone(side)`: among own active zones, pick the one whose distance to the nearest enemy zone is closest to `sep`; ties broken by waypoint order (blue PvE) then by number of same-side neighbours (`zc2:9618-9665`).
- A second blue AWACS takes a station at least 100 NM away from the first (`_computeAwacsStationWithZoneSecondary(…, 100)`, `zc2:10134-10141`).
- `RepositionAwacsToFront()` is scheduled 15 s after a zone changes side (`SCHEDULER:New(nil, RepositionAwacsToFront, {}, 15)`, `zc2:56680`) and re-tasks every AWACS; a move of less than 50 m is ignored (`zc2:9870-9922`, `zc2:9939-9943`).
- The orbit is a raw `Orbit` task, circle or racetrack, baro altitude, heading towards the nearest enemy zone (`zc2:9945-9960`, `zc2:10069-10073`).

### Reproduction notes

- Needs a zone-distance index (`_buildAwacsZoneInfo`, `Frontline._zoneInfo`) shared with the frontline computation.
- AWACS is invisible and (PvE) immortal: it is a service, not a target.

## 8. CAP control and other purchased-flight control by players

- Group F10 "CAP Control" exists while a purchased CAP flight (`dynamiccap`) is alive: "CAP: Reposition by Zone", "CAP: Reposition by Position", "CAP: Hold Racetrack", "CAP: Flightsweep", "CAP: Destroy", "CAP Help", plus an "Engage If Engaged / Engage All" toggle and "Stop CAP auto-buy" (`loc:34-35`, `loc:1874-1881`, `loc:1937-1938`; menu builder `bc:refreshDynamicControlMenusForBlue`, called by `buildCapControlMenu`, `zc2:107172-107174`; builder body not read — (estimation) for the exact tree).
- Map markers `caphere1` / `caphere2` move the CAP exactly like the tankers (same handler, `kind = "cap"`, `setCapRacetrack`), without the rank or helicopter restriction but still requiring a human-crewed group of the owning side (`zc2:28154-28155`, `zc2:28224-28232`, `zc2:28318-28320`, `zc2:105747`).
- Strategic bombers have their own dynamic control menu (`StrategicBomber.AddDynamicControlMenuForGroup`, `zc2:4195`) — not analysed here (AI flights theme).
- The purchased flights themselves are registered in `DynamicSupportNative` (section 15).

## 9. Map-marker commands (complete list)

All are handled by one event handler created in `BattleCommander:startMonitorPlayerMarkers` (`zc2:28354-29290`), triggered on **mark change** (event id 26) for coalition 1 or 2; the marker text is the command; the marker is removed when the command succeeded (`zc2:28456`, `zc2:29246-29248`).
In the branches read, no command checks the identity of the player (name, UCID, slot); the "admin" ones are only obscured by Swedish words, which are replaced by the configurable `AdminCommandAliases` when `AdminCommands == true` (`zc2:28355-28437`); the bodies of `debug`, `spawn`, `prepp`, `addshop`… were not read, so a guard inside them is not excluded — (estimation).

| Marker text | Effect | Who / condition | Code |
|---|---|---|---|
| `arcohere1`, `arcohere2` | set the Arco racetrack from two points | human, fixed-wing, rank ≥ tanker rank | `zc2:28148-28352` |
| `texacohere1`, `texacohere2` | same for Texaco | idem | idem |
| `caphere1`, `caphere2` | same for the purchased CAP flight | human group of the owning side | idem |
| `tarawahere`, `tarawahereandstop` | send the Tarawa to the marker and stop | carrier navigation enabled; if `AllowTarawaToMoveFreely`, blue point must be in blue/neutral territory | `zc2:28957-28966` |
| `tarawahere1`, `tarawahere2` | Tarawa racetrack between two water points | `AllowTarawaToMoveFreely`, blue only | `zc2:28967-29003` |
| `tarawareturn` | Tarawa back to its navigation area | carrier navigation enabled | `zc2:29004-29008` |
| `tarawahelp` | prints the Tarawa commands | — | `zc2:28948-28956` |
| `jtac-code:NNNN` | laser code of the JTAC drone(s) | anyone | `zc2:7403-7418` |
| `help` | prints the command help (`ADMIN_COMMAND_HELP`) | anyone | `zc2:28481-28491` |
| `status` | status of the zone under the marker | anyone | `zc2:28810-28835` |
| `intelstatus` | zone status with intel override | anyone | `zc2:29068-29079` |
| `missions` | prints the mission list | anyone | `zc2:29080-29084` |
| `stats`, `top`, `mystats` | leaderboard / top 5 / own stats | anyone | `zc2:29215-29239` |
| `whynot` | explains why the zone is suspended | anyone | `zc2:28918-28926` |
| `buy`, `buy:<item>` | shop by marker (agent 05) | — | `zc2:28555-28620` |
| `farphere…`, `givemefarp…`, `givemefarpzell`, `escortmissionfarp` | dynamic FARP creation (other theme) | PvP / admin | `zc2:29011-29067` |
| `debughelp`, `ConfigStatus`, `debug`, `spawn`, `spawnnow…`, `prepp`, `addshop`, `removeshop`, `upgradeallred`, `upgradeallblue`, `event`, `event:<name>`, `recapture`, `givemesupplies`, `capture:<…>`, `additems…`, `adminbuy[:item]` (needs `AllowAdminBuy`), `addfunds:<n>`, `addfundsred:<n>`, `addrank:<player>,<n>`, `Message:<text>`, `SpelaMusik`, and the Swedish/aliased `köp[:item]`, `rensa`, `upgradera`, `maxxa`, `blå`, `röd`, `AvslutaFoothold`, `StartaOm` | admin/debug | unguarded text match | `zc2:28492-29245` |
| `-code:<lua>` | **executes arbitrary Lua** through `loadstring` | unguarded | `zc2:29203-29214` |

Zeus adds its own marker commands (section 13) and EWRS/WelcomeMessage add none.

## 10. Carrier and ship control

**No Moose `AIRBOSS`, `RECOVERYTANKER` or `RESCUEHELO`** is instantiated anywhere in the Foothold files; carrier operations use the native DCS carrier ATC, and Foothold adds navigation, beacons and information.

### Player view

- Group F10 "Carrier navigation" (label key `DYNAMIC_CARRIER_NAVIGATION`), shown when the feature is enabled and, with the ranking system on, when the player's rank ≥ `CarrierRankRequirement` (5): "Carrier info" (per carrier: ATC MHz, TACAN, callsign, ICLS channel, Link 4 MHz) and one "Sail to <area>" entry per available area ("More" submenus beyond 9) (`zc2:16081-16138`, `cfg:290-292`).
- Messages: "<carrier> moving to <area>", "area unavailable", "route failed", and — until the red carrier zone is cleared — "red carrier required" (`zc2:15986-16014`, `zc2:13549-13554`).
- Coalition warnings before the carrier turns at the end of a racetrack leg (5 min and 1 min) (`zc2:15112-15137`).
- Carrier areas are drawn/labelled on the F10 map ("Carrier: <label>") (`zc2:13905`, `zc2:14234`).
- Tarawa by map marker: see section 9; `tarawahelp` text depends on `AllowTarawaToMoveFreely` (`zc2:28948-28954`).
- ATIS for a carrier gives BRC (magnetic), wind at 18 m, radio line (section 11).

### Mission-maker view

- Ships must be groups/units named `CVN-72`, `CVN-74`, `Tarawa` (navigation); beacons are also refreshed for `CVN-73`, `CVN-59`, `CVN-75` if present (`WM:918-923`).
- Navigation areas are quad trigger zones `CVN72_AREA_<NAME>` with point sub-zones `-1`/`-2` (CVN-72 racetrack ends), `-3`/`-4` (Tarawa), `-5`/`-6` (CVN-74) (`zc2:13868-13925`).
- Setup calls: `bc:deployCarrierNavigationArea("CVN72_AREA_SOCHI", true)`, `bc:setCarrierNavigationAreaAvailability({AREA = bool | {available=, autoMove=, …}})`, `bc:setCarrierNavigationAutoRoute({...})`, `bc:addCarrierNavigationSuspendConnection(area, zone)`; in the Caucasus setup the areas open as zones are captured and the carriers auto-move forward (`setup:1946-2040`, `zc2:13735`, `zc2:13828`, `zc2:27056`).
- Config: `CarrierNavigationRadios` (CVN-72: TACAN 72X, ATC 272; CVN-74: 74X, 274; Tarawa: 1X, 271.5), `CarrierNavigationICLS`, `CarrierNavigationLink4` (0 = off), `CarrierRankRequirement = 5`, `AllowTarawaToMoveFreely = false` (`cfg:290-299`, `cfg:373-394`).
- Globals `CarrierNavigationSpeedCheckInitialSec` 60, `…IntervalSec` 1 800, `…AfterMoveSec` 120, `CarrierNavigationSpeedDeadbandKt` 1, `CarrierNavigationTargetWodKt` 24 (`zc2:13403-13408`, `zc2:14961`).

### Mechanism

- Route: start point → optional "via" stations → nearest end of the destination racetrack → other end, with a `GoToWaypoint`-style task on the last waypoint looping back to the first station waypoint, so the ship runs the racetrack forever (`zc2:14669-14714`).
- Path finding over water: direct leg if valid, otherwise Moose `ASTAR:New()` on a grid of `land.SurfaceType.WATER` nodes (step ≥ 2 km), `SetValidNeighbourLoS(corridor)`, `GetPath` (`zc2:14491-14518`).
- Speed: periodic "speed check" (60 s after start, then every 30 min, 2 min after a move, 4 min after a turn) recomputes the ship speed so that wind over deck ≈ 24 kt: `targetSpeed = clamp(24 − natural headwind)` from `atmosphere.getWind` at 18 m, and re-applies the route if it differs by ≥ 1 kt; it also routes back a carrier found outside its area (`zc2:14949-14963`, `zc2:15012-15058`).
- Radios: `SetFrequency` command on the ship unit for the ATC frequency (`zc2:13600-13606`); TACAN (`ActivateBeacon`, type 4, system 3), ICLS (`ActivateICLS`, type 131584), Link 4 (`ActivateLink4`) and ACLS (`ActivateACLS`) are sent by `WelcomeMessage.lua` `refreshBeacons()`, every hour (`SCHEDULER:New(nil, refreshBeacons, {}, 5, 3600)`) (`WM:788-926`).
- Recovery tanker: `bc:spawnCarrierRecoveryTanker("Shell", "CVN-72", distNm)` respawns template `Shell` near the carrier with its radio settings — a plain respawn, not Moose `RECOVERYTANKER` (`zc2:15814-15843`).
- Carrier state (area, lane, next station, speed, custom Tarawa route) is persisted and the ship is teleported back at restart (`zc2:15282-15330`, `zc2:15529`, `zc2:15638`).
- Tarawa custom route: `_carrierNavigationApplyTarawaCustomRoute("tarawa-stop" | "tarawa-racetrack", points, …)` (`zc2:14825-14878`).

### Reproduction notes

- The only Moose-heavy dependency is `ASTAR` for sea routing.
- The whole subsystem is ≈2 800 lines (`zc2:13403-16200`), mostly availability rules, persistence and menus; the navigation core is the looped waypoint route plus the wind-over-deck speed recalculation.
- Beacons must be re-sent after any respawn/teleport of the ship (unit id changes; Link 4/ACLS are sent once per unit id, `WM:848-861`).

## 11. `WelcomeMessage.lua`: welcome text, callsign/IFF assignment, ATIS, airfield information

`WelcomeMessage.lua` (2 941 lines) is far more than a welcome text: it holds the ATIS menu, the callsign/IFF allocator, the carrier beacons (section 10), the whole escort feature (section 12), the refuelling reward, the airbase-static respawn on capture and the player-leave cleanup.
Its `static` table is **not** about static objects in general: it is `STATIC:FindByName("EventMan", true)`, a Moose wrapper around a static object named `EventMan` in the `.miz`, used only as the event-handler object (`static:HandleEvent(EVENTS.BaseCaptured | PlayerLeaveUnit | Refueling | RefuelingStop, …)`) and as the namespace of `static:processPlayerSpawn` (`WM:45`, `WM:2932-2935`).
`WelcomeMessagev2.lua` (2 641 lines) also exists in the folder, but the Caucasus `.miz` ships `WelcomeMessage.lua`.

### Player view

- On spawn in a zone: a greeting "Welcome to <zone>, <rank> <name>, you are <callsign>, IFF <code>" (or "standby" when no callsign is free), and 60 s later a detailed message with wind, temperature, altimeter and active runway (airbase zones) or carrier radio line + BRC + wind over the deck (carrier zones); the wording differs for a first visit and a return ("welcome back") (`WM:1530-1628`).
- F10 "Change callsign" group menu to pick another callsign family/number among the ones configured for the aircraft type (`WM:1630-1723`, body not read beyond the menu creation).
- F10 "ATIS / Closest airfield" group menu (aeroplanes only): "Closest friendly airfield" and a submenu "ATIS information" with "Mother" (blue, when a carrier exists) and one entry per friendly airbase zone, sorted by waypoint number descending, "More" every 9 (`WM:1306-1341`).
- "Closest friendly airfield": for Hornets/Tomcats each active carrier (distance NM, magnetic bearing, radio line or TACAN, BRC), then the nearest friendly airbase zone with distance, magnetic bearing, wind, altimeter, active runway with magnetic course (`WM:1191-1271`).
- ATIS for a zone: "ATIS for <zone>: wind DDD at N kt, altimeter …, active runway NN (course DDD°M)", 20 s (`WM:1110-1130`, `WM:1156-1163`).
- Capture ATIS: 10 s after an airbase is captured, every aeroplane client of the new owner receives that airbase's ATIS, and all ATIS menus are rebuilt (one group every 0.1 s) (`WM:1381-1431`, `WM:1345-1379`).

### Mission-maker view

- A static object named `EventMan` must exist in the `.miz` (`WM:45`).
- `atisZones` / `allZones` are built at load from the Foothold `zones` table (zones with an airbase get ATIS) (`WM:84-161`, `WM:186-187`); the file must therefore run after the setup file.
- Config: the welcome text block and the callsign table "Welcome Message Callsigns" (`cfg:1156-1169`); `aircraftAssignments` maps a **group-name pattern** (e.g. `"F.A.18"`) to callsign families each with 4 IFF codes (e.g. `Arctic1` → 1400–1403) (`WM:566-720`).
- Moose user settings forced at the end of the file: `_SETTINGS:SetPlayerMenuOff()`, `SetA2G_BR()`, `SetA2A_BULLS()`, `SetImperial()` (`WM:2936-2939`).

### Mechanism

- Entry point: `LogisticCommander` calls `static:processPlayerSpawn(mooseUnit, zoneName)` on player spawn (`zc2:101261`); the greeting is sent at once and the detailed message by `SCHEDULER:New(nil, sendDetailedMessageToPlayer, {...}, 60)` kept in `followID[playerName]` (`WM:1624-1628`).
- Callsigns: `findOrAssignSlot(playerName, groupName, zoneName)` keeps `zoneAssignments[zone]` and `globalCallsignAssignments[player]`, reuses the player's callsign if he respawns in the same zone, releases it otherwise, and gives the first free number of the preferred family; IFF is `details.IFFs[number]` (`WM:341-475`).
- ATIS data is computed by Foothold from Moose airbase helpers, **not by the Moose `ATIS` class** (no `ATIS:New` anywhere): wind = `COORDINATE:GetWind(10)` (→ `atmosphere.getWind`), runway = `AIRBASE:GetActiveRunway()` + `GetRunwayName()` (Moose picks the runway from wind), pressure = `readAltimeterPressure()`, temperature = `COORDINATE:GetTemperature` (`WM:1004-1058`, `WM:1096-1106`).
- Carrier BRC = ship heading − magnetic declination (`WM:863-874`); carrier wind = `COORDINATE:GetWind(18)` (`WM:972-995`).
- Menus are Moose `MENU_GROUP` / `MENU_GROUP_COMMAND` (→ `missionCommands.addSubMenuForGroup` / `addCommandForGroup`) (`WM:1318-1338`).
- Capture: Moose `EVENTS.BaseCaptured` (→ `S_EVENT_BASE_CAPTURED`), clients enumerated with `SET_CLIENT:New():FilterCategories("plane"):FilterCoalitions():FilterAlive():FilterOnce()` (`WM:1383-1415`).
- Text is plain on-screen text; nothing is spoken (no SRS/MSRS use found).
- Refuelling reward: `EVENTS.Refueling` stores the fuel fraction at contact (for AI-tanker events, every player within 300 m of the tanker is recorded), `EVENTS.RefuelingStop` converts the gained fraction × `fuelMassMax` to pounds and pays `floor(lbs/100) × RefuelReward` if ≥ `RefuelRewardMinimumLbs` (`WM:2731-2828`).
- Airbase statics: `GatherStaticDetails()` records the statics listed per airbase in `airbaseStatics`, and `RespawnStaticsForAirbase(airbase, side)` respawns them with the new coalition when the zone changes side (called from `zc2:51447-51473`, `zc2:55361`, `zc2:56759`) (`WM:234-306`).
- Player leave: `static:OnEventPlayerLeaveUnit` resets contributions, temp stats, callsign slot, menus, escort (`WM:2867-2930`).

### Reproduction notes

- The active-runway choice and runway naming come from Moose `AIRBASE` (runway geometry from `Airbase:getRunways()` and wind).
- Callsign allocation keys on group-name patterns, so slot naming in the `.miz` matters.
- Messages are localised per player (`L10N:ForGroup`), which is why reports are cached per locale when broadcast (`WM:1157-1161`).

## 12. Escort flight for players

### Player view

- Eligible types get, 10 s after spawn, "Escort available" + `ding.ogg` and a group menu "Request escort" with: Same altitude, 2 000 ft above, 5 000 ft above, 10 000 ft above (`WM:1491-1514`, `WM:1724-1739`).
- A 2-ship fighter escort then either takes off from the closest friendly airfield ("scrambling, taxi", when `EscortTakeoffFromGround`) or is air-spawned 1 500 m behind the player, 10 000 ft above him (or holds at 27 000 ft over the home base if the player is on the ground) (`WM:2133-2172`, `WM:2284-2294`, `WM:2298-2316`).
- Menu "Escort": Patrol ahead (15 NM on the nose), Racetrack on the nose, Racetrack left-to-right, Racetrack right-to-left, Start orbit (25 000 ft over the player's position), Rejoin, RTB (`WM:2321-2339`).
- "Rejoin" on the ground makes the escort hold at 10 000 ft and join after take-off ("can't join, you are on the ground") (`WM:2573-2602`).
- If the escort is shot down the menu is removed and the player is notified (`WM:2428-2450`, `WM:2621-2633`).

### Mission-maker view

- Config `EscortTypeByPlayerType[type] = { enabled, blueTemplate | index, altitude, [redTemplate] }` (enabled by default for C-130J-30, AV8BNA, A-10C/A-10C_2/A-10A, Hercules, F-15ESE, AJS37), `EscortTakeoffFromGround = true`, `PvPEscorts = false` (`cfg:325-327`, `cfg:1238-1270`, `WM:193-211`).
- The escort template is one of the enabled CAP templates (`BlueCapPlaneEnabled` / `RedCapPlaneEnabled`) (`WM:1434-1450`).

### Mechanism

- Spawn: `SPAWN:NewWithAlias(template, alias):InitGrouping(2):InitHeading():OnSpawnGroup(cb):SpawnFromCoordinate(coord)` (→ `coalition.addGroup`), alias `<group>_<player>_Escort_NNN` (`WM:2158-2171`, `WM:2244`).
- Tasks are raw DCS tasks set through `SetEscortNativeTask`: `{id="Escort", params={groupId, pos={x,y,z}, engagementDistMax=40 NM, targetTypes={"Air"}}}` for follow/patrol-ahead (pos x=15 NM ahead, or x=−100, z=300 for rejoin), `{id="Orbit", …RACE_TRACK}` for racetracks, `{id="EngageTargets", targetTypes={"Air"}}` (`WM:1770-1812`, `WM:2498-2502`, `WM:2584`).
- Options: `CommandSetUnlimitedFuel(true)`, radar continuous search, no waypoint pass report (`WM:2272`).
- Loss tracking: `escortOwnerByUnitName[unit]` is consulted by the BattleCommander unit-lost handler (`HandleEscortUnitLost`, `zc2:43069`); take-off of the player triggers `HandleEscortTakeoff` (`WM:2635`).
- State: `spawnedGroups[groupName]`, `escortGroups[groupName]`, `escortPendingJoin`.

### Reproduction notes

- Entirely doable with the native `Escort` task; the subtle parts are the ground cases (player not airborne, escort scrambling) and the generation counters that cancel stale delayed tasks (`escortOrbitGeneration`, `WM:2459-2473`).

## 13. `EWRS.lua`: early-warning radar picture

A modified copy of the public "EWRS by Steggles" script (`EWRS.lua:1743-1745`), 1 745 lines, largely independent of the engine (only `L10N`, Moose `SET_CLIENT`/`UTILS`/`BASE` and the persistence hooks).

### Player view

- Every 20 s (default) each player with automatic reports on receives a text "picture" of the closest radar-detected enemy aircraft within his range limit: type (NATO reporting name), bearing (rounded to 5°), range (rounded: 1 below 20, 5 below 60, 10 above), altitude (thousands of ft or tens of m), speed, heading, aspect Hot/Flanking/Beaming/Cold (`EWRS.lua:692-705`, `EWRS.lua:738-790`, `EWRS.lua:1719-1741`).
- Reference is the player's own aircraft (BRA) or the coalition bullseye (`coalition.getMainRefPoint`) (`EWRS.lua:718-727`).
- Style 2 shows "Merged" under 5 NM (`cfg:2353`).
- Optional friendly lines (other friendly aircraft, tankers Arco/Texaco) (`EWRS.lua:792-830`, `EWRS.lua:1114-1203`).
- F10 group menu (label key `EWRS_MENU_ROOT`): Request bogey dope; (on-demand mode) Request picture; Set detection range (km or nm lists); Set threat limit (1–5, All); Friendlies (show on/off, limit 1–5, show tankers on/off); Auto picture on/off; Group settings → reference (bullseye/self), measurements (imperial/metric), report style (1/2) (`EWRS.lua:1591-1695`).
- Settings are saved per player name and aircraft category and restored at next spawn and after a restart (`EWRS.lua:331-656`).

### Mission-maker view

- Config block `ewrs_*` (`cfg:2318-2355`): `ewrs_enabled = true`, `ewrs_defaultReportStyle = 2`, `ewrs_maxRangeKm = 150`, `ewrs_maxRangeNm = 100`, `ewrs_defaultAircraftRangeLimit = 60`, `ewrs_defaultHelicopterRangeLimit = 20`, `ewrs_messageUpdateInterval = 20`, `ewrs_messageDisplayTime = 15`, `ewrs_restrictToOneReference = false`, `ewrs_defaultReference = "self"`, `ewrs_defaultMeasurements = "imperial"`, `ewrs_defaultShowTankers = false`, `ewrs_enableRedTeam = true`, `ewrs_enableBlueTeam = true`, `ewrs_disableMessageWhenNoThreats = true`, `ewrs_onDemand = false`, `ewrs_maxThreatDisplay = 5`, `ewrs_allowBogeyDope = true`, `ewrs_allowFriendlyPicture = true`, `ewrs_maxFriendlyDisplay = 3`, `ewrs_showType = true`, `ewrs_mergedRangeNm = 5`, `ewrs_specialPlaneTypes` (types that see friendlies by default).
- The config must be loaded before `EWRS.lua` (`cfg:2318`).

### Mechanism

- Detection: a "radar registry" of every unit with attribute `SAM SR`, `EWR` or `AWACS`, per side, built once from `coalition.getGroups` and maintained by Moose events `Birth`, `Dead`, `Crash`, `RemoveUnit`, `UnitLost` (`BASE:HandleEvent` → `world.addEventHandler`) (`EWRS.lua:1349-1394`).
- Each cycle, for each radar of the player's side: `unit:getController():getDetectedTargets(Controller.Detection.RADAR)`; keep objects that exist, are in the air and have attribute `Planes` or `Helicopters`; de-duplicated by object id (`EWRS.lua:1396-1431`).
- So the picture is what **friendly radars really detect** (terrain masking and radar range apply), computed once per side per cycle and shared by all players of that side (`EWRS.lua:1722-1736`).
- Player list: `ewrs.update()` → `buildActivePlayers()` uses `SET_CLIENT:New():FilterActive(true):FilterOnce()`; it is called from the engine on player spawn/leave (`ewrs.registerPlayer`, `ewrs.pruneGroup`), not on a timer (`EWRS.lua:687-690`, `EWRS.lua:1205-1232`, `EWRS.lua:1308-1333`).
- The registry is torn down when no player is active (`EWRS.lua:1226`, `EWRS.lua:1340-1347`).
- One global timer (`timer.scheduleFunction`, first run at +6 s, period `messageUpdateInterval`) loops over active players; a per-cycle `contactFacts` cache shares position/heading/type per contact between players (`EWRS.lua:1719-1741`).
- Reporting names: Moose `UNIT:Find(obj)` then a table lookup with overrides for WW2 types (`EWRS.lua:140-162`, `EWRS.lua:245-275`).
- Output: `trigger.action.outTextForGroup` (in `ewrs.outText`, `EWRS.lua:966-1083`).

### Reproduction notes

- No heavy Moose dependency; the core is `Controller:getDetectedTargets(RADAR)` on each friendly search radar.
- Cost: O(friendly radars) detection queries per cycle per side, plus O(players × contacts) formatting; the registry avoids rescanning all units.
- The per-player settings persistence (compact encoded profiles) is ≈300 lines by itself.

## 14. Zeus: game-master marker commands (`Zeus.lua`, `zeus_Full_v2.1.lua`)

The Caucasus mission loads the short `Zeus.lua` (105 lines), not `zeus_Full_v2.1.lua` (the `.miz` contains only `l10n/DEFAULT/Zeus.lua`).

### `Zeus.lua` commands (marker text, lower-cased, must start with `-`)

| Marker text | Effect | Code |
|---|---|---|
| `-create <name>` | spawns the template `<name>` at the marker; allowed names: SA-8, SA-9, SA-13, SA-15, SA-19, Soldier, Truck, Shilka, Igla, Igla-S, RPG, BMP2, Tank, BTR80, CTLD_CARGO_HMMWV, mig21, JTAC9lineam, JTAC9linefm, Tankm1, CTLD_CARGO_L118, CTLD_CARGO_Scout, CTLD_CARGO_AmmoTruck, CTLD_CARGO_GMLRS_HE | `Zeus.lua:15-29` |
| `-destroy1` | destroys every unit within 500 m | `Zeus.lua:37-42` |
| `-destroy2`, `-destroy3` | destroys every unit within 1 000 m | `Zeus.lua:44-49` |
| `-destroy4` | destroys every unit within 10 000 m | `Zeus.lua:51-56` |
| `-explode <power> [delay]` | explosion at the marker (default power 100) | `Zeus.lua:58-64` |
| `-smoke <red/blue/green/orange/white>` | smoke at the marker (default red) | `Zeus.lua:66-74` |
| `-illuminate` | illumination bomb 1 000 m above the marker, power 700 000 | `Zeus.lua:89-91` |
| `-static`, `-debug` | empty stubs | `Zeus.lua:32-33` |

- Trigger: `world.addEventHandler` on `S_EVENT_MARK_ADDED` and `S_EVENT_MARK_CHANGE`; the marker is removed after a recognised command (`Zeus.lua:76-102`).
- **Who may use them: anyone who can place a marker.** There is no check of coalition, player name, UCID or slot in the file (`Zeus.lua:76-102`).
- Moose use: `SPAWN:NewWithAlias(name, name..rnd):SpawnFromVec2`, `ZONE_RADIUS:New():SearchZone(fn, Object.Category.UNIT)` (→ `world.searchObjects` sphere), `COORDINATE:Explosion` (→ `trigger.action.explosion`), `COORDINATE:Smoke*` (→ `trigger.action.smoke`), `COORDINATE:IlluminationBomb` (→ `trigger.action.illuminationBomb`).

### `zeus_Full_v2.1.lua` (1 750 lines, not loaded by the CA mission)

- Same `-destroyN`, `-explode`, `-smoke`, `-illuminate` commands (`zeus_Full_v2.1.lua:1465-1485`).
- Semicolon syntax on **mark change** only: `<model>;<unit name>[;red/blue]` spawns an aircraft from built-in templates (`airUnitDB`: mig29, mig23, mig21, j11, m2k, f14, f15, f16, f18, f1, f5, mig28, f4, p51, spit, mossie, bf109, fw190a8, fw190d9, ju88, plus `jtac`, `texaco`, `arco`) at the marker via `coalition.addGroup`; support types spawn on the player's side, others as adversaries unless overridden (`zeus_Full_v2.1.lua:1497-1533`, `zeus_Full_v2.1.lua:1668-1742`).
- `destroy;<spawn name>` dismisses a spawned package; `illumin;` drops 5 illumination bombs (power 1 000 000, 600–1 200 m, staggered 5–13 s after a 15 s delay); `smoke;<colors>`; `strike;` = 16 explosions over 5–20 s (`zeus_Full_v2.1.lua:1534-1549`, `zeus_Full_v2.1.lua:1572-1602`).
- Optional napalm / phosphor effects, both off by default (`zeus_Full_v2.1.lua:11-14`).
- It ignores marker texts that match the engine's own commands (exclusion list: help, buy, status, stats, capture, `-code:`, …) (`zeus_Full_v2.1.lua:17-55`).
- Only guard: at least one player must be in the mission (`zeus_Full_v2.1.lua:1509`, `zeus_Full_v2.1.lua:1532`); no admin check.

## 15. Smoke, flare and illumination on a zone's targets

- Shop items `smoke`, `flare`, `illum` → pick an enemy, non-suspended zone → `bc:smokeTargets(zone)`, `bc:flareTargets(zone)`, `bc:illumTargets(zone)` and a coalition message (`setup:4547-4634`).
- Smoke: up to 3 random alive units/statics of the zone get **red** smoke (`trigger.action.smoke(point, 1)`); the smoked groups are told to react through `AIEN.ReactToSmoke(zone, groupName, 20)` (the ground-AI script) (`zc2:23618-23660`).
- Flare: up to 3 random targets, each with 3 red signal flares 5 s apart (`trigger.action.signalFlare`, `timer.scheduleFunction`) (`zc2:23662-23694`).
- Illumination: up to 3 positions (group leaders when the zone has ≥ 3 groups, else random units), altitude 1 000 m, power 700 000 via `trigger.action.illuminationBomb(point, power)` (`zc2:23696-23774`).
- Other on-request marking already listed: JTAC drone smoke/flare (section 1), player designator blue smoke (section 3), CSAR smoke/flare at pilot and "smoke/flare nearest zone" (section 4), Zeus `-smoke` / `-illuminate` (section 14).
- All raw DCS trigger actions; no Moose.

## 16. `DynamicSupportNative`: life-cycle tracker of purchased AI support flights

- Purpose: a registry of the player-purchased flights (CAP, CAS, SEAD, bomber, decoy…) that reports their life cycle to the coalition and drives the control-menu refresh; it is **not** itself an on-demand support request (`zc2:106261-106469`).
- `Register(record, group)` stores `record` under `record.groupName` with callbacks/messages: `airborneMessage`, `onMissionStarted`, `winchesterMessage` / `onWinchester`, `completedMessage`, `landedMessage`, `killedMessage`, `clearActive()`, `isActive()` (`zc2:106367-106378`).
- Ammo monitor: one shared `timer.scheduleFunction` every 30 s while any flight is registered; `_hasMissionAmmo` scans `Unit:getAmmo()` for bombs, rockets and non-AAM missiles (or only AAMs when `aamOnly`); the first time a flight that had mission ammo has none left → "winchester" message and callback (`zc2:106266-106291`, `zc2:106303-106365`).
- The same tick wakes idle-suspended zones along the flight's footprint (`_idleWakeFootprint`) and finishes flights whose group disappeared (`zc2:106314-106350`).
- Event hooks called from the BattleCommander handler: `HandleTakeoff` (airborne message, menu refresh), `HandleUnitLost` (last unit lost → "killed" message, optional CAP auto-rebuy via `_replaceLostPurchasedCap` when `AllowCapAutoBuyAfterLoss`), `HandleLanding` (`zc2:106402-106469`, `zc2:43070-43073`).
- `ReportMissionStarted` / `ReportMissionComplete` are called by the flights' own task scripts (`zc2:106380-106400`).
- No Moose; "Native" refers to the use of raw DCS groups and tasks instead of Moose OPS flightgroups (naming inference — (estimation)).

## 17. "Hunt": enemy fighters dispatched against a successful player

- This is a threat, not a support tool, but it is the only thing named `Hunt` in the engine.
- Config `EnableHunter = true` (disabled in PvP) (`cfg:856-858`, `zc2:40974-40986`).
- Setup: `bc:initHunter(HuntNumber, AirHuntNumber)` with a ground-kill threshold of 6–15 (8–15 with splash damage) and an air-kill threshold of 4–8, drawn at mission start (`setup:6040-6043`).
- `registerHuntKill(pname, unit, killType)` counts kills per blue player (helicopters, A-10C_2, A-10A and AV8BNA are exempt); once the threshold is reached each further kill has a 10 % chance (once per life) to call `_spawnHunterForPlayer`, which picks a red airbase with 2 free parking spots and launches a 2-ship against the player (`zc2:41136-41168`, `zc2:41059-41075`).
- Counters are reset when the player leaves or respawns (`WM:2888`, `zc2:41695`).

## 18. `Splash_Damage_3.4.1_leka.lua`: Foothold customisations (brief)

- Third-party "Splash Damage 3.4.1" script; the Foothold variant differs from `Splash_Damage_3.4.1_Default.lua` by about 370 changed lines.
- The whole script only runs when `SplashDamage == true` (Config default `false`, `cfg:273`) or on the Normandy map, where it also forces `larger_explosions`, radius modifier 2, cascade scaling 2 and ordnance protection (diff, head of file).
- Options changed: `dynamic_blast_radius_modifier = 1.5`, `cascade_scaling = 1.5`, `ordnance_protection = false`, `killfeed_enable = true`, `killfeed_lekas_foothold_integration = true`, `killfeed_lekas_contribution_delay = 0`.
- Rewards for splash kills: each object found dead/damaged by splash is priced with `bc:objectToRewardPoints2(object, name)` (red objects only), queued in the killfeed table, then a timer applies `bc:addTempStat`, `bc:addContribution(player, 2, points)`, `bc:registerCasMissionKill`, `bc:registerSeadMissionKill` and `bc:registerMissionTargetKill` for players who have a contribution record.
- Smoke/fire on damaged vehicles: the stock "all units" smoke/cook-off effects are kept, with a `processedSmoke` table that now expires per unit (retention window) so an effect is not replayed.
- Weapon table: two entries added (`F16V_GBU53`, `F16V_GBU39`, explosive 25); weapons missing from the table are logged once per type; booster objects (`ZELL Booster`, `SPRD-99`) are ignored.
- Line numbers are not cited here because the comparison was made on a diff of the two files, not on a read of the 4 932-line file; treat the detail as (estimation) beyond the option names and function calls quoted.

## 19. Help texts, radio information, weather

- Marker `help` prints `ADMIN_COMMAND_HELP`; `debughelp` prints `ADMIN_DEBUG_HELP`; `tarawahelp` prints the Tarawa commands (`zc2:28481-28501`, `zc2:28948-28956`, `loc:1896`).
- Menu help entries: "Tanker Help" (radio info of both tankers + marker syntax), "CAP Help" (marker syntax), "Carrier info" (ATC/TACAN/ICLS/Link 4), "Rank Help", "Supplies help", joint-mission "Help" (`loc:1913-1914`, `loc:1875-1876`, `loc:1024`, `loc:1634`, `loc:1606`).
- Radio frequency information is centralised in `BattleCommander:_initializeSupportRadioSettings` (AWACS, tankers, Shell) and `enableCarrierNavigation` (carriers), validated at load with `assert` (30–400 MHz, TACAN 1–126) (`zc2:13630-13676`, `zc2:13560-13597`).
- The `.miz` ships one kneeboard image, `KNEEBOARD/IMAGES/Freq.png` (frequency card); no script generates kneeboard pages.
- Weather: only read, never changed: `atmosphere.getWind` (player position, carrier deck at 18 m), Moose `COORDINATE:GetWind(10)`, `GetTemperature`, altimeter (`WM:1081-1106`, `WM:753-777`, `zc2:14959`); no time-of-day helper was found in this theme.

## Seen outside this theme

- Recon missions (`BattleCommander:initReconMissions`, slots, trackers `ReconMissionTrackers`) are a mission type of the MissionCommander; zone intel and JTAC deployment cancel them (`zc2:62654-62690`, `zc2:6999-7003`, `zc2:7986-7987`).
- Dynamic FARP creation by marker (`farphere`, `givemefarp`, `escortmissionfarp`) (`zc2:29011-29067`).
- Shop by marker (`buy`, `buy:<item>`, `adminbuy`, `köp`) and the admin economy commands (`addfunds:`, `addrank:`) (`zc2:28555-28706`, `zc2:29085-29135`).
- Zone status display `ZoneCommander:displayStatus` and the "Intel / zone status" menu (`zc2:50274`, `zc2:40330`).
- Purchased AI flights themselves: `spawnCapAt`, CAS/SEAD/bomber/decoy shop actions, `StrategicBomber` control menu (`zc2:107204`, `setup:3053-3780`, `zc2:4195`).
- `AIEN.lua` ground-AI reactions (`AIEN.ReactToSmoke`) (`zc2:23658`).
- Career/statistics (`recordCareerStat`, `printStats`, `mystats`) (`zc2:29215-29239`, `WM:2802`).
- Player rank gating of menus (`_getGroupRank`, `CarrierRankRequirement`, tanker rank) (`zc2:28227`, `zc2:16084`).
- Territory overlay used to validate Tarawa moves (`_territoryOverlaySideAtPoint`) (`zc2:28930`).
- `-code:<lua>` marker executes arbitrary Lua for anyone able to edit a marker (`zc2:29203-29214`).
- Persistence of support state: tanker stations, carrier navigation, CSAR pilots, SelfJtac and EWRS player settings (`zc2:106153`, `zc2:15298`, `zc2:44890`, `zc2:43833`, `EWRS.lua:529-656`).
