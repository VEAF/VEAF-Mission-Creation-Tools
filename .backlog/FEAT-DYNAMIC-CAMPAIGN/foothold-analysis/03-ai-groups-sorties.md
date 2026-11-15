# 03 — AI groups and sorties (Foothold v6.5.3)

Scope: everything the AI flies, drives or sails, except the Red/Blue `Director` planner, capture rules, shop internals, CTLD internals and persistence.
All line references are to `zoneCommanderv2.lua` unless another file is named.

"(estimation)" marks anything not read in the code.

| # | Feature | One-line description | Main code location |
|---|---|---|---|
| 1 | Sortie declaration and templates | `addGroups` records (`DirectorCapability` / `GroupCommander`) naming origin, target, mission, template set | `11958`, `57265`, `57725`, `60357-60505`, `MA_Setup_CAv2.lua:1060-1340` |
| 2 | Air sortie state machine | hangar → preparing → takeoff → inair → landed, polled; parking spawn, tasking, supply landing → capture/delivery | `68725-68868`, `67521-68006`, `68330-68712` |
| 3 | Spawn eligibility and role caps | one gate deciding if a sortie may launch; CAP/CAS/SEAD/runway caps by player count and difficulty | `66102-66597`, `60825-61110`, `57104-57262` |
| 4 | CAP behaviour | race-track orbit with engage-en-route, winchester/target-lost RTB, SAM avoidance, Blue CAP assist | `35751-35999`, `67137-67333` |
| 5 | Strike tasking | CAS, SEAD, runway bombing, anti-ship routes as raw DCS tasks | `35309-35530`, `36091-36474` |
| 6 | Surface sorties | supply/attack convoys on roads, artillery batteries, ships; arrival → capture/delivery | `70792-70844`, `69739-70135`, `70508-70763`, `11024-11610` |
| 7 | Moose OPS usage | six small sites only (Hunter, battleship, navy artillery, V1) | `41099`, `10932`, `70022`, `109998`, `111165` |
| 8 | Hunter | Red two-ship scrambled after a player's kill streak | `40974-41168` |
| 9 | AI supply helicopter cargo | sling-loaded container, landing spots, stall recovery | `58056-58260`, `58495-58533`, `68267-68307` |
| 10 | Zone patrols and AIEN | groups roaming between sub-zones; AIEN reactions to fire, dismounts, suppression, initiative | `27654-28100`, `AIEN.lua` |
| 11 | Air defence network | MANTIS emission control, hide/reveal SAM on MFD, night reaction time and radar blur | `111396-111495`, `4432-4441`, `41579-41640` |
| 12 | Strategic bomber | air-spawned bomber raid with escort; Red interceptor roll against the Blue raid | `1500-2320`, `2350-4195` |
| 13 | Normandy artillery supports | navy artillery + enemy striker, V1 launch sites | `109927-110100`, `111165-111390` |
| 14 | Blue AI (PvE) and PvP differences | Blue support limits, supply cost, warehouse use; PvP limits and mirrored systems | `61022-61110`, `66386-66403`, `17095-17102` |
| 15 | Throttles and cleanup | staggered zone updates, dormant FSM, spawn-evaluation queue, wreck and landing cleanup | `43225-43346`, `56268-56440`, `65896-66000`, `17853-18000` |

## 1. GroupCommander — declaration and template resolution

### Mission-maker view

A zone's AI sorties are declared in the setup file with `zones.<zone>:addGroups({ ... })` (`MA_Setup_CAv2.lua:1290-1297`).
In v6.5.3 almost every entry is a `DirectorCapability:new({...})` record (402 occurrences in `MA_Setup_CAv2.lua`), and only 7 are direct `GroupCommander:new({...})` (all fixed artillery, e.g. `MA_Setup_CAv2.lua:1366`).
A `DirectorCapability` is a passive table carrying the same fields as a `GroupCommander`; it is tagged `_isDirectorCapability`, defaults `type='air'` and may not define FSM methods (`zoneCommanderv2.lua:11958-11969`).
`ZoneCommander:addGroups` routes tagged records to `addDirectorCapabilities` and inserts plain `GroupCommander` objects into `zone.groups` (`56468-56489`).
A capability becomes a live `GroupCommander` only when `BattleCommander:activateDirectorCapability` copies its fields into `GroupCommander:new(authored)`, calls `originZone:addGroup` and `:init()`, and activates its FSM (`26383-26450`); up to two extra "derivative" instances (slots 2 and 3) can be created from the same record, named `<name>__Director2/3` (`26389-26415`).
(When and why a capability is activated is the Director's business — not analysed here.)

Fields seen in the setup file and read by the engine:

| Field | Meaning | Where read |
|---|---|---|
| `name` | Unique id; also the `.miz` group name when no `template` is given | `57265`, `60484-60487` |
| `mission` | `'supply'`, `'patrol'` or `'attack'` (selects respawn timer row and eligibility branch) | `57264`, `66102-66593` |
| `MissionType` | `'CAP'`, `'CAS'`, `'SEAD'`, `'RUNWAYSTRIKE'`, `'ANTISHIP'`, `'ARTY'`, `'BATTLESHIP'` (sub-role; absent for supply and plain ground attack/patrol) | `68336-68425`, `66170` |
| `targetzone` | Name of the zone the group works on | `66163` |
| `type` | `'air'` (default), `'carrier_air'` (lands at carrier) or `'surface'` (ground or ship) | `57271-57279` |
| `template` | Name of a global Lua table listing `.miz` template group names (e.g. `CapPlaneTemplate`); one is picked at spawn | `60474-60505` |
| `Altitude` | Cruise altitude in feet, usually a random helper (`CapAltitude()` = 22–32 kft, `CasAltitude()` 15–25 kft, `SeadAltitude()` 25–33 kft, `RunwayStrikeAltitude()` 23–28 kft) | `MA_Setup_CAv2.lua:1227-1230` |
| `condition`, `Bluecondition`, `Redcondition` | Predicates; `false` blocks the spawn; the coloured ones also restrict the side | `66220-66238` |
| `urgent` | Boolean or function; switches to the short "urgent" timers and allows first capture of a neutral zone | `66242-66243`, `66375-66380` |
| `ForceUrgent` | Lets an urgent supply capture a neutral zone even after Red already captured it once | `66375` |
| `diceChance` | 1–100: probability that the sortie actually launches when its hangar timer expires | `67943-67957` |
| `spawnDelayFactor` | Number or function multiplying the hangar/dead timers | `57727`, `65831` |
| `Airbase` | Force spawn at a named airbase/ship instead of the zone's `airbaseName` | `68583-68596` |
| `ForceFromGround` | Helicopter: spawn on the ground inside the zone instead of on parking | `68573-68575` |
| `SpawnHot` | Engines-running start (forced for SEAD when force-spawned) | `66205`, `68519` |
| `ShopLaunchOnly` | Supply group that only flies when bought in the shop | `66127-66129` |
| `NotCargo` | Supply helicopter without sling load | `67697` |
| `FixedArty`, `SetActiveMission` | Fixed artillery group flags (see artillery section) | `MA_Setup_CAv2.lua:1366` |
| `terminalType` | Moose parking terminal type override | `60551` |

Template sets are plain global Lua arrays of `.miz` group names built in the setup file.
`AllCapPlaneTemplates`, `AllCasPlaneTemplates`, `AllSeadPlaneTemplates`, `AllRunwayStrikePlaneTemplates`, `AllCasHeloTemplates`, `AllSupplyHeloTemplates` list every late-activated template group in the mission (names encode side, airframe, role, loadout and flight size, e.g. `RED_SU25_CAS_KH25ML_S25Lx2_FAB500M62x2_B8x2_SPPU_2SHIP`) (`MA_Setup_CAv2.lua:1060-1187`).
The active sets (`CapPlaneTemplate`, `CasPlaneTemplate`, `SeadPlaneTemplate`, `RunwayStrikePlaneTemplate`, `CasHeloTemplate`, `HeloSupplyTemplate`) are the master lists filtered by per-side enable maps (`RedCapPlaneEnabled`, `BlueCapPlaneEnabled`, …) coming from the Config (`MA_Setup_CAv2.lua:73-88`, `1189-1194`).
Ground/plane sets are literal: `SupplyConvoy` = `"SupplyConvoy 1..3"`, `"SupplyConvoy_Blue 1"`; `PlaneSupplyTemplate` = `"IL-76MD"`, `"C-130J-30"`, `"AN-30M"`; `ArtilleryConvoyLong/Short`, `InsurgentConvoy` (`MA_Setup_CAv2.lua:1196-1224`).
Each zone that launches aircraft has `zones.<z>.airbaseName = '<DCS airbase or FARP name>'` (`MA_Setup_CAv2.lua:1232-1288`).

### Mechanism

`GroupCommander:new` sets `state='inhangar'`, `side=0`, `landsatcarrier = (type=='carrier_air')`, `diceChance` default 0, and marks every non-shop supply group `AllowSupplyLaunchFromSuspendedZone` (`57265-57286`).
`GroupCommander:init` resolves the template set through `_getTemplateSet` (a global table named by `template`, else `dc.SETS[template]`) (`60474-60482`), then for each template reads the live DCS group (`Group.getByName`) or the Moose template database `_DATABASE.Templates.Groups[name]` to learn the coalition (`ResolveTemplateSide`), the unit category of unit 1 and the flight size (`AirCount`), and sorts templates into `_tplBySide[1]` / `_tplBySide[2]` (`57725-57805`).
Non-air template groups found alive at mission start are destroyed at init (`57750`, `57770`, `57790`).
A missing template prints `ZONE_ERROR_GROUP_TEMPLATE_MISSING` to all (`57761-57763`).
Because templates are indexed per side, the same record serves whichever coalition owns the origin zone: on each evaluation `self.side` is switched to the zone's side if a template exists for that side, otherwise the spawn is refused (`66209-66222`).
At spawn `_resolveTemplateName` picks a template for the current side; for aircraft it goes through `Respawn.PickTemplateFamilyVariant` (`60484-60505`, `1293`), for surface groups a uniform random pick.
Without `template`, the group is the `.miz` group named `name` and is re-spawned with `Respawn.Group(self.name)` (`68623-68639`).

### Template groups required in the `.miz`

One late-activated group per name in every template set, with the aircraft type, loadout, flight size and coalition country set in the Mission Editor (side is derived from the group, not from the name) (`57741-57757`).
Fixed (non-template) groups such as `'Gudauta-attack-Sukhumi-Arty'` exist under that exact name (`MA_Setup_CAv2.lua:1366`).

## 2. GroupCommander — air state machine

States for `type='air'`/`'carrier_air'`: `inhangar → preparing → takeoff → inair → landed → inhangar`, plus `dead` (`68725-68868`).
The FSM is not event-driven: `GroupCommander:update` is called from the zone update loop and polls the DCS group (`70846-70870`).
On each update the DCS group is fetched (`_getDcsGroupCached`), and a missing or empty group in any live state moves the FSM to `dead` with `lastStateTime = now` (`68753-68787`).

Timers (seconds) come from `GlobalSettings.respawnTimers[side][mission]` = `{dead, hangar, preparing}`, defaults 15 min / 18 min / 2 min for every mission and both sides (`8572-8582`), scaled per side by `GlobalSettings.difficultyScaling` and separately for supply by `supplyDifficultyScaling` (`8660-8683`).
Urgent groups use `GlobalSettings.urgentRespawnTimers` = dead 35 s, hangar 20 s, preparing 5 s (`8565-8569`).

| State | Leaves when | Code |
|---|---|---|
| `inhangar` | `now - lastStateTime > hangar × spawnDelayFactor` (or an air-limit retry time is reached); then the optional `diceChance` roll (fail → `dead`), then `evaluateSpawnEligibility`; success → `preparing`; denial → retry scheduling or re-enter hangar | `67938-67977` |
| `preparing` | after `preparing` seconds: eligibility is re-checked and the group is spawned → `takeoff` | `68713-68723`, `68444-68712` |
| `takeoff` | any unit airborne → `inair`; still on the ground after `blockedDespawnTime` (12 min) and fully stopped → destroyed, back to `inhangar` | `67521-67591`, `8534` |
| `inair` | all units landed → `landed` | `67593-67763` |
| `landed` | supply: in target zone → capture or delivery; any: in home/recovery zone → `inhangar`; otherwise despawn after `landedDespawnTime` (60 s helicopters, 180 s planes) | `67765-67936`, `8535` |
| `dead` | after `dead × spawnDelayFactor`: eligibility check; success → `inhangar` (a new full hangar wait), else a dormant retry | `67979-68006` |

Entering the hangar (`_enterHangar`) clears all per-sortie flags and sets `lastStateTime = now + delay`, where delay is 0–25 min random for normal groups (60 s minimum at mission start) and 0 (20 s at start) for urgent ones (`57288-57312`, `57569-57664`).
This random hangar offset is the main de-synchroniser of AI launches.
Red supply flights wait longer when few Blue players are online: ×1.5 with 0 players, ×1.3 with 1 (PvE only) (`68835-68843`).

### Spawn (preparing → takeoff)

`_processAirFreshSpawn` first calls `clearWreckage` on the target zone (`68462`), picks the template, then resolves a parking spawn (`68468-68494`).
`_resolveAirbaseSpawn` uses Moose `AIRBASE:FindByName`, `IsAirdrome/IsHelipad/IsShip`, `GetFreeParkingSpotsTable(terminalType)` and needs `AirCount` free spots; it returns the spot ids (`60507-60544`); aircraft on a zone without its own spots fall back to `_resolveParkingWithBelonging` (a neighbouring airbase listed in `AirbaseBelonging`) (`68490-68492`, `57832`).
The spawn itself is Moose `SPAWN:NewFromTemplate(tpl, resolved, alias, true):InitSkill(...):OnSpawnGroup(cb)` then `SpawnAtParkingSpot(airbase, spots, takeoff)` with fallback `SpawnAtAirbase` (`68503-68507`, `68579-68582`); these wrap `coalition.addGroup` with a rewritten first waypoint (detail in "What the Moose parking spawn writes" below).
Skill is `AiPlaneSkill` (Config) for Red and always `"Excellent"` for Blue (`68504`).
Start is cold unless the group is a Blue (or PvP) supply flight or has `SpawnHot` (`68508-68509`).
Planes with no parking are not spawned (back to hangar); helicopters with no parking are spawned on the ground inside the zone by `_spawnFromGroundAt` (`68611-68617`, `66786`).
Blue AI spawns first call `_prepareBlueAiWarehouseSpawn` so the DCS warehouse holds the airframe (`68580`).
Supply helicopters can also launch from a player-built CTLD FARP (`_pendingSupplyFarpLaunch`, `SpawnAtAirbase(farpAb, Hot)`) (`68518-68553`).
After a successful spawn: `Spawned=true`, `state='takeoff'`, an intel message `INTEL_AIR_STARTING_UP_AT` is broadcast when the group is in the origin zone (`68667-68697`).

### What the Moose parking spawn writes (to redo it without Moose)

Parking query, `AIRBASE:GetFreeParkingSpotsTable(termtype, allowTOAC)` (`Moose_2026-10-11.lua:33755-33770`): one DCS call, `Airbase:getParking(true)` (the `true` asks DCS for free spots only, `33597-33604`), then two filters.
Filter 1, terminal type: each DCS record has `Term_Type`; with `termtype == nil` every spot except runway spawn points (16) is accepted; otherwise the type must match exactly or belong to a composite — `OpenMedOrBig` (176) = 72 or 104; `HelicopterUsable` (216) = 72, 104 or 40; `FighterAircraft` (244) = 72, 104 or 68 (shelter); `FighterAircraftSmall` (344) adds small-fighter spots (`33324-33335`, `33943-33976`).
Filter 2, "take-off or landing aircraft": a spot whose `TO_AC` flag is true is skipped unless `allowTOAC` is true (`33760`).
Each returned spot is the cached Moose record built once from `getParking(false)`: `TerminalID = Term_Index`, `Coordinate`/`Vec3 = vTerminalPos`, `TerminalType = Term_Type`, `DistToRwy = fDistToRW`, `TOAC`, plus `ClientSpot` when a client slot of the mission starts within 2 m of the spot (`33679-33724`).
Foothold then keeps only as many spots as the flight has aircraft and passes their `TerminalID`s (`60507-60544`).

`SPAWN:SpawnAtParkingSpot(airbase, spotIds, takeoff)` re-reads each id (`GetParkingSpotData`, which recomputes `Free` by comparing `getParking(false)` and `getParking(true)`), requires as many free spots as units, and calls `SpawnAtAirbase(airbase, takeoff, nil, nil, nil, parkingData)` (`21719-21749`, `33728-33754`, `33771-33782`).
`SPAWN:SpawnAtAirbase` then edits the group table (a copy of the editor template) (`21486-21718`):

| Field | Value written | Code |
|---|---|---|
| `route.points[1].airdromeId` | The airbase id for an airdrome; nil otherwise. | `21508-21518` |
| `route.points[1].helipadId` and `.linkUnit` | The airbase id for a FARP/helipad or a ship; nil for an airdrome. | `21510-21516` |
| `route.points[1].type` / `.action` | Cold: `"TakeOffParking"` / `"From Parking Area"`; hot: `"TakeOffParkingHot"` / `"From Parking Area Hot"`; runway: `"TakeOff"` / `"From Runway"`; air: `"Turning Point"` / `"Turning Point"`. | `21520-21521`, `29382-29387` |
| `route.points[1].x`, `.y`, `.alt` | Position of the first parking spot (`alt` first set to 0, then to the spot height). | `21519`, `21702-21704` |
| `units[i].x`, `.y`, `.alt` | Position of parking spot `i` (`Coordinate.x`, `.z`, `.y`). | `21686-21690` |
| `units[i].parking` | `TerminalID` (DCS `Term_Index`) of spot `i`. | `21695-21699` |
| `units[i].parking_id` | Cleared (nil); Moose does not set it. | `21696` |
| group `x`, `y` | Position of the first spot. | `21705-21706` |
| `uncontrolled` | The spawner's uncontrolled flag (false here). | `21707` |
| `parked` (Moose-private flag on the template) | true, so a second call does not re-park. | `21671-21672` |

When no explicit spot list is given the same function searches spots itself with `FindFreeParkingSpotForAircraft` (terminal type chosen from the group attributes: helicopters `HelicopterOnly` then `HelicopterUsable`, bombers/transports/tankers/AWACS `OpenBig` then `OpenMedOrBig`, others `FighterAircraft`, with a 50 m obstacle scan of units and statics); on FARPs and ships ("autoparking") it puts every unit on the first spot and lets DCS distribute them (`21529-21620`).
With not enough spots it falls back to an air start 500–2 500 m above the field (100–1 000 m for helicopters), which Foothold avoids by always passing an explicit list and checking the count first (`21635-21650`).

Finally `SpawnWithIndex` → `_Prepare` and `DATABASE:Spawn` finish the table and call DCS (`21246`, `22179-22225`, `12903-12923`):

- `name` = the alias-based spawn name; `groupId = nil`; every `units[i].unitId = nil` and `units[i].name = "<group name>-<NN>"`; `lateActivation = false`;
- optional per-unit `skill`, `livery_id`, `onboard_num`, `heading`/`psi`, and group `hiddenOnMFD`, `hiddenOnPlanner`, `hidden`, `communication`/`frequency`/`modulation` according to the `Init…` calls used;
- `CoalitionID`, `CountryID`, `CategoryID` are removed from the table and passed as arguments: `coalition.addGroup(countryId, categoryId, template)`.

So, without Moose, a parking spawn is: `Airbase.getByName(name):getParking(true)` → filter on `Term_Type` and `TO_AC` → take N spots → write the fields of the table above into a copy of the template with fresh names and no ids → `coalition.addGroup`.

### Tasking after spawn

`_onFreshAirSpawn` (the `OnSpawnGroup` callback) dispatches by role (`68330-68442`):

| Role | Call | Line |
|---|---|---|
| CAP patrol | station picked by `Frontline.PickStationNearZone(targetzone, side, ±35 nm, …)`, then `_assignCapTask` with a 30–40 nm orbit | `68336-68351` |
| CAP attack | station by `Frontline.PickCapStationFromOrigin(origin, target, side, 100, 35/25 nm)`, orbit 35–45 nm | `68353-68366` |
| Supply helicopter | `_routeFreshSupplyHelo` 2 s later | `68368-68391` |
| Supply plane | `_routeFreshSupplyPlane` 2 s later | `68393-68406` |
| CAS plane | `bc:EngageCasMission(targetzone, …, Altitude, landUnitID, side, …{routeSpeedIasKnots=300})` | `68408-68414` |
| CAS helicopter | `bc:EngageHeloCasMission` (or `EngageHeloCasAtPoint` for an enemy-position response) | `68416-68429` |
| SEAD | `bc:EngageSeadMission` | `68430-68432` |
| Runway strike | `bc:EngageRunwayBombing(homeAirbase, targetzone, …)` | `68434-68435` |
| Anti-ship | `bc:EngageAntiShipMission` | `68437-68438` |

### Arrival of a supply flight

When every unit of a supply flight is landed and at least one is inside the target zone (`Utils.someOfGroupInZone`): if the zone is neutral, `tg:startPendingCaptureFromAircraft(side, group, captureDelivery, …)` starts the capture; if it is friendly, `bc:_applyRegularSupplyDelivery(tg, side, now, paid)` delivers supplies (repair/upgrade — capture theme) (`67803-67861`).
For Blue (and Red in PvP) with warehouse logistics, a delivery also adds 20 warehouse items (`AIDeliveryamount`) for a helicopter or 50 for a plane (`67819-67827`, `67863-67871`).
The outcome is reported to the Director (`_recordDirectorRegularSupplyOutcome` 'delivered'/'aborted') (`67830-67834`).
A Red supply helicopter landing at a friendly zone while a Blue player is near waits 60 s before delivering (PvE) (`67810-67816`).
The FSM then returns to `inhangar` and `_scheduleLandingCleanup(gr)` removes the aircraft (`67836-67873`).
An invalid target (enemy-owned, suspended) aborts the delivery (`67791-67808`).
Blue normal supply costs credits in PvE when players are online: `min(blueZoneCount × 10, 100)`, checked at eligibility and debited at spawn (`66386-66403`, `68370-68374`).

### RTB, landing, losses

Non-supply aircraft that land in their home or CAP recovery zone go back to `inhangar`; in PvE each such Red landing credits Red 100 (`67895-67922`).
A plane on attack/patrol that lands anywhere else is also recycled immediately; helicopters wait `landedDespawnTime` (`67924-67934`).
There is no per-unit loss accounting inside the FSM: a group only becomes `dead` when its DCS group is gone or has size 0 (`68753-68787`); partial losses are invisible to it.
A Blue supply helicopter that dies between 60 and 120 s after spawn is retried once without cargo (`68759-68781`).
A supply helicopter still inside its home zone 280 s after take-off is destroyed and re-queued without cargo (`67599-67606`).

### Restore of air sorties after a server restart

What is saved per live air sortie (`_buildAirPersistenceRecord`, `25441-25560`): commander name, Director capability id / derivative slot / instance generation, origin and target zone, side, `mission`, `MissionType`, unit category, template set and the template actually used, plus role extras (CAS altitude, CAP holding point, orbit distance, buffer, SAM-return and return-home state, CAP-assist retask, supply return-home and shop flags, advance-capture phase and hold point).
The save splits them into `inair` (position, heading, alive count, time in state) and `spawnNowTakeoff` (flights that were still on the ground: they are simply launched again) (`29604-29610`, `29788-29790`).
`bc:init()` schedules `_runPendingAirAiRestore` 5 s after start; it waits (up to 12 × 5 s) for the dynamic-hybrid bootstrap, and holds the take-off list until the warehouse persistence has loaded (`30285`, `29573-29602`, `29892-29919`).

Matching a saved record to a commander (`_resolveAirPersistenceCommander`, `29389-29501`): first by Director capability id (the capability is re-activated into a commander, `29301-29387`); else by exact name (a `_retasked_…` suffix stripped); else, for dynamic-hybrid groups, by base name with a score on origin/target/role/side/mission; else by metadata score (origin 3, target 4, side 3, mission 3, MissionType 3, category 2, template 2), accepted from 10 points up; supply records never use the metadata fallback.
The matched commander receives the saved extras, `state = 'preparing'` with `lastStateTime = now − 999999` so that the next `update` spawns at once, and for an in-air record `_pendingInAirRestore = saved` (`29741-29780`, `29825-29870`).
A take-off record is dropped when the origin zone changed side, or is fully suspended and the group is neither a shop supply nor an authorised regular supply (`29637-29641`).

`_processAirRestoredSpawn(restoreData, …)` (`68044-68265`), called from the `preparing` state instead of the parking spawn:

1. Abort to hangar when the saved position or the template is missing, or when a CAS/SEAD plane was saved farther than max(2 × origin–target distance, 100 NM) from both its origin and its target (`68045-68078`, `67025-67043`).
2. Adjust the spawn point: CAS is put back on its origin→target axis (`_getRestoreCasSpawnPoint`); a supply helicopter or plane saved inside its final approach is moved back to 1 NM before the approach fix, the destination being the target, or the origin when it was returning or the target is no longer valid (`68079-68107`, `59692-59709`).
3. Altitude: the saved one; helicopters are clamped to 60–300 m AGL (1 500 ft AGL when no altitude was saved) (`68109-68124`).
4. Template rewrite, without parking: every unit is translated/rotated around unit 1 to the saved position and heading and given `alt`, `heading`, `psi`; the route is replaced by two "Turning Point" waypoints, the spawn point and a point 2 NM ahead, both `alt_type = "BARO"` at the saved altitude and the template speed (380 m/s default) (`68126-68173`).
5. `SPAWN:NewFromTemplate(tpl, template, alias, true):InitSkill(…):OnSpawnGroup(cb):Spawn()` → `coalition.addGroup` in the air (`68183-68245`).
6. In the callback: `state = 'inair'`, `lastStateTime = now − saved time in state`, surplus units destroyed from the last index down so that only `aliveCount` remain, cargo weight applied to planes, and `_assignRestoredAirMission` scheduled 0.5 s (CAS) or 2.5 s later (`68199-68242`).
7. `_assignRestoredAirMission` first waits (0.5 s retries, up to `idleZoneWakeHoldSec`) for the idle zones of the target footprint to wake, then calls `_assignMissionAfterInAirRestore`, which re-issues the normal tasking of the role from the current position with the "restore direct" variants; "Not available" is retried up to 10 times at 0.5 s (`68008-68042`).

There is no restore of fuel, weapons or damage: the flight comes back with a full template loadout and only the unit count is preserved.

## 3. Spawn eligibility: how a group decides it may launch

### Mechanism

`GroupCommander:evaluateSpawnEligibility` is the single gate, called at the `inhangar`, `preparing` and `dead` transitions (`66102-66597`).
Generic refusals, in order: origin zone inactive (`66111`); supply dispatch disabled for the side (`66121-66125`); `ShopLaunchOnly` without a shop request (`66127`); runway of the origin blocked (`isRunwayPlaneSpawnBlockedForGroup`, `66131`); origin zone suspended, except attack/patrol missions and authorised supply (`66135-66156`); **a Blue player near the Red origin zone** (`zone.BlueIsNear`, or `BluePlaneIsNear` for planes) — this sends the Red group back to a fresh hangar wait so nothing spawns in front of a player (`66158-66165`); target zone unknown, suspended or inactive (`66167-66171`); `NoAIBlueCapture` forbids Blue AI from capturing neutral zones in PvE (`66172-66179`).
Then: the template set must contain a group for the zone's current side, and `self.side` must equal the origin zone's side (`66209-66222`); `condition` / `Bluecondition` / `Redcondition` (`66224-66238`).
Front-line distance: `Frontline.ZoneDistToFrontNm(targetzone)`; non-supply missions are refused when the target is deeper behind the front than `frontlineDistanceLimitBlue` (30 nm) / `frontlineDistanceLimitRed` (60 nm), and CAP additionally by `capRearlineNmBlue` (30) / `capRearlineNmRed` (60) (`66245-66266`, `8508-8509`, `8522-8523`).

Per mission:

| Mission | Rule | Code |
|---|---|---|
| `attack` + CAS/SEAD/RUNWAYSTRIKE/ANTISHIP | target must be enemy-owned (not neutral); SEAD needs `HasSeadTargets`; the count of active groups of that role must be below the role limit | `66271-66361` |
| `supply` | target neutral: only an urgent group may capture it (and not if Red captured it before, unless `ForceUrgent`); target friendly or neutral: only if `tg:canRecieveSupply()`; Blue pays (see §2) | `66363-66411` |
| `patrol` + CAP | target must be friendly; active CAP count below limit; the target must rank within the "CAP window" of zones closest to players | `66413-66497` |
| `attack` + CAP | target must be enemy-owned; same limit and ranking logic | `66499-66575` |
| `attack` without MissionType (convoys, artillery, ships) | target enemy-owned | `66578-66582` |
| `patrol` without MissionType | target friendly | `66584-66588` |

Target choice is therefore static: each record names one `targetzone`, and the "graph" is the set of authored origin→target pairs; a record only fires when the ownership of its two ends matches its mission.
(The Director may retask or pick among records; out of scope.)

### Caps on simultaneous AI sorties

Red CAP limit by Blue player count and `CapDifficulty` (Config, `"easy"|"medium"|"hard"`): medium = 1,2,3,4,4,5,5,5,5,5,6,7,7 for 0…12+ players; easy tops at 6, hard at 8 (`60867-60961`).
Red strike limits (`CasDifficulty`, `SeadDifficulty`, `RunwayStrikeDifficulty`, `AntiShipDifficulty`): medium = 1 (≤1 player), 2 (≤3), 3 (4), 4 (5+) planes; plus one extra helicopter slot per role (`60963-61020`, `66298-66326`).
Blue AI support (`FriendlyCapSupport`, `FriendlyCasSupport`, `FriendlySeadSupport`): medium = 1 group with 0–1 player, 0 beyond; easy = 2/2/1; hard = 0 (`61022-61110`).
Every table can be overridden by "stages" lists (`CapLimitStages`, `RedCasLimitStages`, `BlueCapSupportStages`, … = `{ {player=n, amount=m}, … }`) (`60825-60836`).
Player counts come from `refreshPlayers()` snapshots (`getBluePlayersCount`, `getBlueCasPlayersCount`, `getRedCasPlayersCount`) (`60619-60647`).
Active counts are kept in incremental buckets (`_capDelta`, `_nonCapDeltaStrike`, `getActiveCAPCount`, `getActiveStrikeCount`) rather than recounted (`61114-61961`).
A denied CAP/strike gets a retry time instead of a normal hangar cycle: CAP 5 min +2 min per denial up to 15 min; CAS/SEAD 4 min +4 up to 20 with a 4-min random window; runway strike 15–25 min (`57104-57111`, `57324-57347`).
Denied Red CAP groups of the same mission form a ranked "cohort" (nearest-to-players first) with 2–5 min gaps so that later candidates cannot overtake the leader (`57113-57262`).
CAP zones are ranked by `getClosestCapZonesToPlayers` (distance to players, enemy adjacency bonus) and only the top `limit − current` zones may launch (`66432-66470`, `65609`).

## 4. CAP behaviour in flight

### Mechanism

`Frontline.SetUpCapTask` builds a race-track: two points 10–15 km either side of the station, perpendicular to the route axis when given, pulled back so the leg stays `bufferNm` from the nearest enemy zone centre (`35751-35830`).
`Frontline.AssignCapRoute` issues a raw DCS `Mission` task through `controller:setTask`: waypoint 1 with an `EngageTargets` en-route task (`maxDist` = orbit range 30–45 nm, target types `Planes`, or `Planes`+`Helicopters`, or fighter/bomber classes when `InvisibleA10` is on), waypoints p1 and p2 at 280 m/s, a `ControlledTask` wrapping an `Orbit` (race-track, 250 m/s) with a `duration` stop condition, then a landing waypoint at the home airbase (`35931-35999`).
A `WrappedAction`/`Script` task on the orbit waypoint calls back `CapRef[name]:_capOrbitEvent(groupId, version)` to timestamp the start of the orbit; the deadline is `now + duration` (`35978-35986`, `67206-67213`).
`SetUpCAP_DefaultAA` sets the controller options: no air-to-ground, RTB on bingo, RTB when out of missiles, threat reaction bypass-and-escape, missile attack range "target threat estimate", jettison empty tanks only (`9077-9089`).
The helicopter-targeting probability comes from Config `ChanceAiAttackHelo` (PvE, Red only) / `PvPChanceAiAttackHelo`; Blue CAP in PvE always engages helicopters (`35764-35776`, `Foothold Config.lua:842-854`).
Each `inair` update (`_checkCapReturnHome`) sends the CAP home when it has no air-to-air ammunition left (`_airGroupHasMissionAmmo`) or when its target zone changed side/was suspended (`67313-67333`, `67295-67311`).
RTB is a two-waypoint Moose route (`COORDINATE:WaypointAirTurningPoint` + `WaypointAirLanding`, `GROUP:Route`) to the nearest valid recovery zone found by `bc:_findCapRecoveryZone` (`67137-67189`, `67261-67293`).
`_checkCapSamReturn` re-flies the original leg if a SAM threat that displaced the CAP is gone, every 30 s, only if all aircraft have ≥ 40 % fuel (`67215-67259`).
"CAP assist": when a Red CAP gets airborne, a Blue CAP already flying may be retasked toward its target zone after 120–300 s (`GlobalSettings.capAssist*`, `8510-8520`, `67581-67584`, `61582`).

### CAP assist (Blue CAP retasked against a Red CAP), PvE only

Settings: `capAssistEnabled = true`, `capAssistCoverageNm = 30`, `capAssistDelayMinSec = 120`, `capAssistDelayMaxSec = 300`, `capAssistTargetZoneCooldownSec = 300` (`8510-8520`).
Trigger: `_tryScheduleBlueCapAssistFromRedCap(redGc)` when a Red CAP becomes airborne; it needs at least one airborne Blue CAP, no cooldown and no pending request on that Red CAP's target zone (`61582-61607`).
Mode: `patrol` when the Red CAP's target zone is Blue (Red is attacking a Blue zone), `attack` otherwise (`61273-61280`).
Desired station: patrol = `Frontline.PickStationNearZone(zone, 2, −35 NM, …, safe 30 NM)`; attack = `Frontline.PickCapStationFromOrigin(blueOrigin, zone, 2, 100, 25 NM)` computed per candidate (`61287-61305`).
Already covered: if a Blue CAP assigned to that zone has its current holding point within 30 NM of the desired station (patrol) or an equivalent attack coverage exists, nothing is scheduled and the zone gets a 60 s cooldown (`61307-61339`, `61613-61630`).
Candidate: the airborne Blue CAP, not returning home, not already retasked during this sortie, "retask-ready" (airborne, with a positive `_capRetaskCapabilityScore` = 12 points per remaining air-to-air missile, capped at 12 missiles per type, plus up to 20 points of gun rounds, counted only for the weapon types of its template profile — and a minimum fuel fraction of at least 0.40 across the flight, `19839-19878`), whose current holding point is nearest to the desired station (`61376-61434`, `19875-19878`).
A request `{token, executeAt = now + random(120, 300), assistMode, blueGroupName}` is stored per target zone and executed by `_executeBlueCapAssistForTargetzone` (`61640-61650`).
At execution the checks are redone (a Red CAP still `inair` on that zone, still no coverage, candidate still valid, else another candidate is selected); then the Blue group simply receives a new `_assignCapTask` at the new station with an orbit range of 35–40 NM (attack) or 30–40 NM (patrol), is flagged `_capAssistRetaskedThisSortie` and `_capAssistRetaskedTargetzone`, and the zone gets the 300 s cooldown; any failure sets a 60 s cooldown (`61453-61580`).
The retask is saved and restored with the sortie (`25476-25477`, `29749-29750`).

### CAP target ranking (`CapTargets`, `CapRef`, `getClosestCapZonesToPlayers`)

`BattleCommander:buildCapSpawnBuckets()` rebuilds four global tables from every air CAP commander and every not-yet-activated Director CAP capability (`30667-30759`):

- `CapTargets[side][mission][targetZone] = { candidates = {{name, origin, dist, state, unitCategory, capability}, …}, ranksByName = {name → rank} }`, the candidates of one target sorted by `_sortCapBucketCandidates` (origin→target distance from `ZONE_DISTANCES` is the stored `dist`) (`30683-30699`, `30717-30736`);
- `CapSpawnBucket[side][mission][targetZone]` = the same order as a list of names, and `CapRankIndex[name] = {side, mission, target, rank}` (`30732-30734`);
- `CapRef[name]` = the live `GroupCommander` object for a CAP name, also maintained when a Director capability is activated or disposed; it is what the orbit-start `Script` task and the denial cohorts use to find the commander from a name (`30698`, `26450`, `26752`, `35985`, `57244`);
- `CapAnchors[side][mission]` = every zone that is the target of at least one CAP record, used as fallback anchors; `CapAnchorRowByZoneName[zone]` = that zone's row of `ZONE_DISTANCES` (`30741-30756`).

It is rebuilt after each capture and neutralisation (zones theme) and ends by re-staggering the CAP hangar delays (`30757-30758`).

`getClosestCapZonesToPlayers(missionType, side, …)` ranks the target zones of one side and mission (`65609-65780`):

1. Anchors = the zones in `playerZoneSpawn` (player name → zone where that player's airplane last started; A-10A/C, AV-8B and Hercules/C-130J are not recorded) that are owned by the **enemy of the patrolling side** for `patrol`, or by the acting side for `attack`, active, awake and visible; with no such anchor, all CAP target zones (`CapAnchors`) are used (`65621-65639`, `101090-101099`).
2. Candidates = keys of `CapTargets[side][mission]` that are active, awake, visible and of the right owner (own side for patrol, enemy and not neutral for attack) (`65686-65711`).
3. Score = mean distance from the candidate to all anchors (`ZONE_DISTANCES`), multiplied by 0.6 when the candidate has an enemy neighbour in the connection graph; ascending sort (`65713-65727`).
4. The geometric result is cached per (side, mission, bucket version, target-state generation, anchor set) for at least 300 s (`65647-65660`, `65729-65736`).
5. It also returns `capMeta = {limit, currentCap, capLeft = max(1, limit − currentCap), targets, enemyAdj}` (`65738-65752`).

Use in the gate (`66442-66475`): the group's target must rank within `capWindow = min(#ranked, capLeft)`, or within the top `max(3, capWindow)` when it has an enemy neighbour; a refused Red group gets the air-limit denial (retry timers of §3), a refused Blue group returns to the hangar.
Then, inside the target's own candidate list, the group counts the better-ranked candidates already `preparing` so that two groups do not take the same slot (`66465-66475`).
For Red in PvE the ranked list is passed through the Director (`rankCapZones`); Blue and PvP use `getCapSpawnRankingForSide`, a mirrored/Director-aware variant (`66435-66443`, `30848`).

## 5. Strike tasking (CAS, SEAD, runway strike, anti-ship)

All four use the same pattern: compute waypoints from the group's current position, build DCS task tables, wrap them with Moose `COORDINATE:WaypointAirTurningPoint(...)` / `WaypointAirLanding(...)` and push with `GROUP:Route(wp, 1)` (a `Mission` task set on the controller after 1 s), then `bc:setDefaultAG(group)` for options (`35309-35429`).
SEAD: `buildSeadIngressPlan` picks viable emitters and an ingress point; the route is start → optional climb → commit point (task = `EngageTargets {'SAM elements','Air Defence'}` + one attack task per viable unit from `getAttackTask`) → target → 20 nm approach fix → landing; a self-defence `EngageTargets` vs planes within 15 nm (Red) / 20 nm (Blue) rides on every leg (`35322-35423`).
`gmoose:TaskFunction("BattleCommander.MarkSeadIngressCommitted", routeState)` and `"BattleCommander.MarkAirReturnHome"` are script callbacks fired at waypoints to update FSM flags (`35377`, `35391`).
Runway strike: 4 waypoints along the straight line to the target airbase (attack at 75 % of the distance, 450 kt), task `BombingRunway {runwayId, weaponType=AnyBomb, expend=ALL, groupAttack=true}` (`35431-35521`); the three-ship templates carry BetAB-500 / Durandal (`MA_Setup_CAv2.lua:1145-1150`).
Blue runway-strike aircraft are made invisible to AI with the `SetInvisible` command (`35512-35514`).

### The task tables, as built

What the Moose helpers produce, so that the tables can be written by hand.
`GROUP:Route(points, delay)` = `controller:setTask({id='Mission', params={airborne=<is air>, route={points=points}}})` after `delay` seconds (`Moose_2026-10-11.lua:27090-27098`, `27177-27186`, `26038-26054`).
`COORDINATE:WaypointAirTurningPoint(altType, speedKmh, tasks, name)` = `{x, y=<z>, alt, alt_type, type="Turning Point", action="Turning Point", speed=<m/s>, speed_locked=true, ETA=0, ETA_locked=false, name, task={id="ComboTask", params={tasks=tasks}}}`; `WaypointAirLanding(speedKmh, airbase)` is the same with `type="Land"`, `action="Landing"`, `speed_locked=false` and `airdromeId = <airbase id>` (or `helipadId` + `linkUnit` for a FARP or ship) (`Moose_2026-10-11.lua:18720-18764`, `18777-18779`).
`GROUP:EnRouteTaskEngageTargets(dist, types, prio)` = `{id='EngageTargets', params={maxDistEnabled=true, maxDist=dist, targetTypes=types, priority=prio}}` (`Moose_2026-10-11.lua:26804-26815`).
`GROUP:TaskFunction("Fn", args…)` = a `WrappedAction` whose action is a `Script` command running `Fn(GROUP:Find(...), unpack(args))`, the arguments being parked in a Moose state table keyed by the group (`Moose_2026-10-11.lua:26951-26964`).
`getAttackTask(name, expend, altitude)` returns, for a group name, `{id='AttackGroup', params={groupId, expend, weaponType=Weapon.flag.AnyWeapon, altitudeEnabled=(altitude~=nil), altitude, groupAttack=false}}`, and for a static or unit name `{id='AttackUnit', params={unitId, expend, weaponType=AnyWeapon, groupAttack=true, altitudeEnabled, altitude}}` (`36557-36597`).
`setDefaultAG(group, search)` sets the controller options `JETT_TANKS_IF_EMPTY=true`, `PROHIBIT_JETT=true`, `RTB_ON_BINGO=true`, `REACTION_ON_THREAT=BYPASS_AND_ESCAPE`, `SILENCE=true`, `RADAR_USING=FOR_CONTINUOUS_SEARCH` when `search`, and `RTB_ON_OUT_OF_AMMO = 2147485694 + 30720 + 4161536` (a weapon-flag mask) (`36613-36624`).

`EngageCasMission(targetZone, groupName, expend, weapon, altitudeFt, landAirbaseId, side, approachFrom, restoreDirect, opts)` (`36091-36323`):

- attack task: one `ComboTask` holding one `getAttackTask` per name in the target zone's `built` (plus the zone's warehouse static as an `AttackUnit`), `expend` defaulting to `AI.Task.WeaponExpend.ONE`, optional `weaponType`, `groupAttack`, `attackQtyLimit`/`attackQty` overrides (`36112-36183`);
- en-route task: `EngageTargets` with `maxDist` 20 NM (Blue) / 15 NM (Red) and target types `{'Planes','Ground Units'}`, or `{'Planes','Helicopters','Ground Units'}` for Blue in PvE and for Red on a `ChanceAiAttackHelo` roll, or `{'Multirole fighters','Interceptors','Bombers','Ground Units'}` with `InvisibleA10` (`36138-36158`);
- geometry: axis from the launch point (or `approachFrom`) to the first target; altitude = `Altitude` in feet → metres (default 6 000 m), except Su-25 / Su-25T CAS which fly a random 5 000–10 000 ft kept for the life of the group (`36185-36201`, `36211-36226`);
- waypoints, all "Turning Point": WP1 at the current position (350 m/s unless a route speed is given; regular CAS passes 300 kt IAS), WP2 5 NM along the axis carrying the en-route task, WP3 20 NM short of the target carrying en-route + the attack `ComboTask`, WP4 15 NM beyond the start along the axis (or 10 NM short of the recovery airbase when return tracking is on) carrying en-route + the `MarkAirReturnHome` callback, then a `Land` waypoint at the airbase `landAirbaseId` (300 kt) (`36280-36299`);
- after `Route`: `CommandSetUnlimitedFuel(true)` and `setDefaultAG(group, true)` (`36308-36322`).

`EngageHeloCasMission` (`36325-36472`): radar option set to 3 (`SetOptionRadarUsing(3)`), 300 ft AGL by default, 70 m/s; en-route `EngageTargets{maxDist = 4 NM, targetTypes = {'Ground Units'}}`; the same `ComboTask` of `AttackGroup`/`AttackUnit` built from the zone's garrison and warehouse, the geometry aiming at the zone centroid; waypoints = a raw take-off point `{type=TAKEOFF, action=FIN_POINT, speed=0, alt=0}` with the prefer-vertical-landing option, "CAS Mid 1 NM" (en-route task), "CAS Approach 5 NM" short of the zone centre (en-route + attack + a `MarkHeloCasIngressCommitted` callback), optionally "CAS RTB Approach" 3 NM short of home (`MarkAirReturnHome` callback), then either a `Land` waypoint at an airbase or a turning point carrying `{id='Land', params={point=<home vec2>, durationFlag=false, combatLandingFlag=false}}`; then `setDefaultAG(group)` (`36338-36471`, `Moose_2026-10-11.lua:26688-26703`).
It returns a `routeState` (`committed` once within 5 NM of the target) that the FSM uses to know whether the attack has begun (`36369-36378`).

`EngageAntiShipMission` (`35524-35586`): target = the up to three nearest `built` groups of the zone whose first unit is a ship; each gets `{id='AttackGroup', params={groupId, expend = ALL by default, altitudeEnabled=true, altitude = 4 572 m or the given altitude, weaponType?}}` in one `ComboTask`.
The route comes from `getDefaultWaypoints`: a raw `{id='Mission', params={route={points={WP1 at the current position (350 m/s), WP2 over the first target (250 m/s), Land at the airbase}}}}` where WP1 and WP2 both carry the attack `ComboTask` (`36979-37002`); an `EngageTargets{maxDist = 30 NM, targetTypes = {'Ships'}}` is appended to the tasks of points 2 and 3 when they have a task list, and the whole thing is set with `controller:setTask` directly, then `setDefaultAG` (`35566-35585`).

Supply plane route, `_assignPlaneRoute` (`57887-57920`, plan in `_resolvePlaneRoutePlan`, `59660-59690`): three waypoints pushed with `GROUP:Route(wp, 1)` — a raw take-off point at the current position, an "Approach" turning point 20 NM short of the target airbase on the line from the start (BARO, cruise altitude = `Altitude` or 10 000 ft, 250 kt IAS converted to TAS), and a `Land` waypoint at the target zone's airbase (50 m/s); no task on any of them.
The target airbase is the zone's `airbaseName`; if its DCS coalition differs from the zone's side it is first forced neutral (`SetCoalition(0)`) so that the landing is accepted (`59664-59668`).
Unless told otherwise the function also removes 50 items from the origin warehouse (`57915-57917`).

## 6. GroupCommander — surface state machine (convoys, artillery, ships)

States for `type='surface'`: `inhangar → preparing → enroute → atdestination → inhangar`, plus `dead` (`70792-70844`).
Timers use the same table; extra slow-down by Blue player count for Red supply convoys and all attack convoys: ×3 with 0 players, ×2.5 with 1, ×2 with 2, ×1.5 with 3, ×1.25 with 4 (attack only) (`65840-65870`).

### Spawn and route

`_processSurfaceFreshSpawn` builds the route first; if no route exists the group is retired or handed back to the Director (`70545-70580`).
Routes come from the `dc` ("DynamicConvoy") helpers and are cached per origin>target pair (`10244-10249`, `11694`, `11932`).
`dc.BuildAttackConvoyRoute`: refuses pairs more than 40 nm apart (`ZONE_DISTANCES`); start point = the origin sub-zone closest to the road hook or to the target; `land.getClosestPointOnRoads("roads", …)` gives the on-road entry and exit; waypoints are start (Off Road) → road start (`on_road`) → road end → then every target sub-zone visited greedily nearest-first at half speed in a random formation (Cone/Diamond/Vee) (`11024-11176`).
Default speed is 20 m/s, raised to 60 km/h for Red (`dc.DEFAULT_SPEED`, `dc.RouteTaskForSide`, `10254-10288`).
`.miz` conventions: sub-zones named `<Zone>-<number>` are the patrol/arrival points (`1423-1442`); road hooks are zones named `<Zone>-road` and `<Zone>-road-0…9`, snapped to the nearest road inside the hook zone (`10975-10999`).
The group is spawned at the start point with Moose `SPAWN:NewFromTemplate(tpl, name, self.name, true):InitGroupHeading(...)` and `SpawnFromPointVec2` (→ `coalition.addGroup`), and 5 s later the route is pushed with raw `controller:popTask()` / `controller:pushTask(selectedTask)` (`70592-70636`).
A convoy departure triggers intel messages only by chance: on each `enroute` update a 2 % roll (`math.random(0,100) > 98`) sends "enemy supply/attack/artillery convoy inbound" text and sound to Blue once per sortie (`69842-69864`).

### Arrival

`enroute → atdestination` when any unit is inside the target zone (`69818-69841`).
Supply convoy at a friendly zone: after `landedDespawnTime` (60 s) it delivers (`_applyRegularSupplyDelivery`) and is destroyed (`69885-69975`).
Supply or attack convoy at a neutral zone: `tg:startPendingCapture(side, {kind="group", …, destroyOnFinish=true, stopGroup=true})` — the convoy itself becomes the capturing force (`69931-69953`, `70079-70103`).
Attack convoy at an enemy zone: no explicit action; the units fight with their DCS AI while walking the sub-zone tail, and the FSM stays in `atdestination` until the zone changes side or the group dies (`70061-70135`).
A Red convoy arriving where a Blue player is near waits 60 s (`70070-70077`).

### Restore of surface sorties after a server restart

`_runPendingSurfaceAiRestore` (scheduled like the air one) resolves each saved record of `pending.active` to a commander and hands it to `_processSurfaceRestoredSpawn(restoreData, now, bc)` (`30034-30075`, `30286`, `70141-70505`).
Validity test: the group is restored only if what it was doing still makes sense — the zone under its saved position, or its target, must still have the right owner for its mission (supply: target friendly or neutral, or home when returning; attack: target enemy; artillery returning: home still owned; advance capture: target still enemy); otherwise it goes back to the hangar (`70158-70222`).
If the target footprint is idle-suspended the restore is postponed until the zones are awake, for at most `idleZoneWakeHoldSec` (`70223-70234`).
Route: rebuilt from the saved position — `_buildSurfaceRestoreTask` (road route from that point to the target, or to home for a returning supply), a two-point off-road `Mission` to the saved hold point for a convoy waiting in advance capture, `_buildSurfaceArtilleryHomeTaskFromPoint` for artillery going home, and for an attack convoy saved `atdestination` a new sub-zone tour of the target (`70284-70371`).
Spawn: the template is rotated to the saved heading and spawned with `SPAWN:NewFromTemplate(tpl, template, self.name, true)` at the saved position (`70268-70279`, `70382-70390`).
In the callback the FSM is set to the saved state (`enroute` or `atdestination`) with `lastStateTime = now − saved duration`, the dead units of the saved "alive mask" are removed (`_applySurfaceRestoreAliveMask`), and the route is pushed 5 s after a `controller:popTask()` (`70411-70467`, `69196`).
A Normandy battleship is first moved to a safe water point within 5 km (`70236-70248`).

### Artillery

`MissionType='ARTY'` (or any group whose units have the `MLRS`/`Artillery` attribute) routes to a firing point at stand-off range from the target centre: 8 nm for templates named `ArtilleryConvoyLong…`, 2.2 nm otherwise, or `artilleryRangeNm` (`10321-10331`, `11505-11560`, `24754-24762`).
The last waypoint runs a script `bc:startFiringAtZone(groupName, target, 10, true)`: every 10 min `_fireAtResolvedZone` fires on the zone's built units; when the target is no longer Blue or has no targets the battery is routed home (`_routeSurfaceArtilleryHome`) (`11512`, `24931-24972`).
While `_artilleryOnStation` the FSM `enroute` handler does nothing (`69794-69796`).
`FixedArty=true` groups are `.miz` groups respawned in place with `Respawn.Group` (no template) and `SetActiveMission` sets `ActiveMission[name]=true` for the mission tracker (`70700-70722`, `70771-70773`).

### Ships

`MissionType='BATTLESHIP'` (Normandy only): routed by `dc.BuildSupplyNavalRoute`; 30 s after arrival a Moose `NAVYGROUP:New(name)` is created and one `AUFTRAG:NewARTY(enemyShipGroup, nil, 250)` per enemy ship group in the zone is added, with `SetDetection()` / `SetEngageDetectedOn()` (`70011-70059`).
Spawning a battleship schedules an enemy counter-strike: 30 s later `SPAWN:New('AXEAntishipJU88Template' | 'UKAntiShipF4UDTemplate'):SpawnAtAirbase(Hot)` wrapped in `FLIGHTGROUP:New` with `AUFTRAG:NewANTISHIP(battleship, 3000)` (`10834-10945`, `70662-70665`).
Naval and air supply variants (`SupplyNavalTemplate`, `SupplyAirTemplate`) also exist for Normandy (`68989-68996`).

## 7. How much relies on Moose OPS

Counts in `zoneCommanderv2.lua` (grep): `FLIGHTGROUP:New` 3, `NAVYGROUP:New` 2, `ARMYGROUP:New` 1, `AUFTRAG:New*` 6, `:AddMission(` 6; no `AIRWING`, `SQUADRON`, `LEGION`, `CHIEF`, `COMMANDER`, `INTEL`, `OPSGROUP` direct use, no `AI_*` dispatcher.
Against that: `SPAWN:New*` 35, `:Route(` 30, `controller:setTask`/`:setTask(` 22, `SCHEDULER:New` 97, `timer.scheduleFunction` 162.
The OPS sites are all side features:

| Site | OPS use | Line |
|---|---|---|
| Hunter two-ship | `FLIGHTGROUP` + `AUFTRAG:NewINTERCEPT`, FSM hooks `OnAfterTakeoff/Dead/Landed` | `41099-41129` |
| Battleship counter-strike | `FLIGHTGROUP` + `AUFTRAG:NewANTISHIP` | `10932-10940` |
| Battleship engagement | `NAVYGROUP` + `AUFTRAG:NewARTY` | `70022-70053` |
| Navy artillery support (Normandy) | `NAVYGROUP` + `AUFTRAG:NewARTY`; striker `FLIGHTGROUP` + `AUFTRAG:NewANTISHIP` | `109998-110093` |
| V1 launcher (Normandy) | `ARMYGROUP` + `AUFTRAG:NewARTY` | `111165`, `111330` |

What OPS provides there: mission lifecycle (queue, execute, done), automatic RTB and landing, and the `OnAfter*` FSM events used for messages and cleanup.
The whole regular sortie system (supply, CAP, CAS, SEAD, runway, convoys, artillery) uses raw DCS tasks; Moose is used as a toolbox: `SPAWN` (template copy + unique naming + parking spawn), `AIRBASE` (parking spot queries), `COORDINATE` waypoint builders, `GROUP:Route`, `GROUP:TaskFunction`, `ZONE`, `SCHEDULER`.

## 8. Hunter (Red two-ship sent after a successful player)

### Player view

After enough kills a Blue coalition message `COMBAT_HUNT_SCRAMBLE` (with the player's name) appears when the hunters take off, and the hunted player hears `Watch your six.ogg` (`41106-41120`).

### Mission-maker view

Config `EnableHunter = true` (disabled in PvP) (`Foothold Config.lua:856-858`).
Setup: `bc:initHunter(HuntNumber, AirHuntNumber)` with thresholds drawn at mission start: ground kills 6–15 (8–15 with Splash Damage), air kills 4–8 (`MA_Setup_CAv2.lua:6038-6042`).

### Mechanism

`registerHuntKill(pname, unit, killType)` counts kills per player; helicopters and A-10C/A-10A/AV-8B pilots are exempt; once the threshold is reached each further kill has a 9 % chance (`roll < 10`) to trigger, once per player life (`41136-41168`).
`_spawnHunterForPlayer` picks a Red airdrome with two free parking spots (`_pickHunterBase`), a random Red CAP template, spawns `HUNTER_<player>` hot on parking, wraps it in `FLIGHTGROUP`, sets home base and an `AUFTRAG:NewINTERCEPT(playerGroup)` at 25 000 ft / 500 kt (`41059-41131`).
`OnAfterLanded` destroys the group after 5 s; `OnAfterDead` resets the player's counters (`41123-41128`).
`Hunt` and `Intercept` are globals, so only the last hunter is referenced (`41099-41101`).

## 9. AI supply helicopters: sling-load cargo and landing spots (`ExternalHeloCargoRoute`)

### Player view

Supply helicopters carry a visible sling-loaded container, announce their dispatch (`LOGISTICS_SUPPLY_HELO_DISPATCH` / `LOGISTICS_SUPPLY_PLANE_DISPATCH`) and, for Red, trigger intel messages and the sounds `Enemy supply helicopter detected.ogg` / `Enemy supply plane detected.ogg` when they start up, take off and arrive (`68652-68656`, `67536-67550`, `68679-68693`).

### Mission-maker view

Config: `SuppliesCargoTransport = true` (AI helicopters use cargo transport), `AIDeliveryamount = 20` (warehouse items per run), `NoAIBlueSupplies`, `NoAIBlueCapture`, `RadioMenuStopSupplies` (`Foothold Config.lua:1344-1363`).
`.miz`: optional landing-spot zones `<Zone>-land` / `<Zone>-land-<n>` (and generated `<Zone>-land-forced-<n>`) give the cargo pick-up and landing points (`610-676`, `59309-59316`).

### Mechanism

`_routeFreshSupplyHelo` (2 s after spawn) chooses the route: plain route (`_assignHeloRoute`) when cargo is off, sling-load route (`_assignHeloExternalCargoLogisticsRoute`) when `WarehouseLogistics` and `SuppliesCargoTransport` are on and the group is not `NotCargo`, internal-cargo route for Chinook-type templates (currently disabled: "DCS internal cargo is broken", the template is forced to `NotCargo`) (`68267-68307`, `68510-68513`).
The container is a raw `coalition.addStaticObject(country, {type="container_cargo", category="Cargos", canCargo=true, mass=600, …})` placed at a landing spot of the origin zone or just ahead of the helicopter (`58495-58533`, `59309-59330`).
`ExternalHeloCargoRoute` is a small table of raw DCS task builders: `ExternalCargoLoad {unitIdTransport, groupId, unitId}`, `ExternalCargoUnLoad {zoneId, unitIdTransport}`, a zero-speed race-track `Orbit` used as a hover hold, air waypoints, and transit-route helpers (`58056-58260`).
Safety nets: a helicopter hovering below a speed threshold inside the target zone for too long has its cargo destroyed so it can land (`67691-67741`); an "advance capture" variant holds the helicopter in orbit outside an enemy zone until it turns neutral, then releases it (`67621-67653`).
Supply planes use `_assignPlaneRoute`: take-off point, an approach fix 20 NM short of the target airbase at cruise altitude, landing at that airbase (detail in §5) (`57887-57920`).
Supply helicopters get ROE via `_applySupplyHeloDefaultRoe` and `OptionPreferVerticalLanding` (`58301`, `68600`).

### Internal cargo of AI supply helicopters (written, switched off in v6.5.3)

Scope: only a Blue supply helicopter whose template unit type is `CH-47Fbl1`, with `WarehouseLogistics` on, `SuppliesCargoTransport` not false, not `NotCargo`, not a no-cargo retry and not a route-only FARP launch (`59028-59033`, `59126-59130`).
In v6.5.3 the two spawn paths force `NotCargo = true` for such templates and the call to `_prepareHeloInternalCargoSpawn` is commented out ("Internal cargo temporarily disabled after the DCS update"), so the code below is dormant (`66793-66794`, `68509-68512`).
Mechanism when enabled: `_prepareHeloInternalCargoSpawn` wraps the Moose spawner's `SpawnWithIndex` so that, before `coalition.addGroup`, it fixes the lead unit's `unitId`, reserves three cargo ids, and rewrites the template route; right after the spawn it creates three statics behind the helicopter (12 m aft, 1.3 m apart) with `coalition.addStaticObject(country.id.USA, {type='cds_crate', shape_name='cds_crate', category='Cargos', canCargo=true, mass=400, groupId, unitId, x, y, heading, name='<group>_INTCARGO_<i>'})` (`59131-59178`).
The first waypoint receives one task per crate `{id='CargoTransportationPlane', params={x, y, unitIdTransport=<helo unit id>, groupId=<crate>, unitId=<crate>}}` followed by a `Script` callback `bc:_markInternalSupplyLoaded(group, version, heloUnitId)` (`59044-59053`).
Delivery leg (`_buildHeloInternalCargoRoute`): the usual supply transit waypoints at 289 km/h, an "Approach" point at 500 ft, then a "Landing Approach" point at 400 ft / 160 km/h whose task list is: optional return-home callback, `Land{point = destination, duration 2 s, combatLanding for Blue}`, one `{id='CargoUnloadPlane', params={groupId, unitId}}` per crate, and a `Script` callback `bc:_markInternalSupplyUnloaded(…)` (`59072-59117`).
`_markInternalSupplyUnloaded` forces the FSM to `landed`, which lets the normal arrival code capture or deliver (`59258-59272`).
Advance-capture variant: instead of landing, a slowdown point 1.5 NM before the hold and a hover `Orbit` at 100 m AGL / 140 km/h at the hold point (80 % of the way, at least 10 NM short), with the same 120 s / 600 s release timers as the sling-load case (`59054-59071`, `59091-59100`).
The origin warehouse is debited `AIDeliveryamount` (20) once per sortie (`59206-59210`).

### Reproduction notes

The cargo tasks (`ExternalCargoLoad`/`ExternalCargoUnLoad`) are undocumented DCS tasks needing live unit/group ids of the static and a trigger-zone id; the code keeps several timeouts because helicopters often stall.
Capture-by-landing relies on polling "all landed + any unit in zone", not on `S_EVENT_LAND`.

## 10. Ground movement inside zones (roaming) and AIEN

### Zone patrol ("roam")

Mission-maker: Config `DisableZonePatrol = false` (`Foothold Config.lua:486`); setup call `bc:roamGroupsToLocalSubZone(prefixes, 50, nil, {groupMin=10, groupMax=45, zoneMin=120, zoneMax=360, cycleMin=420, cycleMax=720})` 30 s after start, with group-name prefixes such as `"Red Armour Group"`, `"Red SAM SHORAD"`, and a second call for ships (`'Moskva #'`, `'Rezky #'`, …) with a 30–38 min cycle (`MA_Setup_CAv2.lua:2850-2886`).
Mechanism: `SET_GROUP:New():FilterPrefixes(p):FilterStart()` keeps live sets per prefix (`27901-27905`); only zones connected to or near a Blue zone (within 50 nm) are processed (`27912-27960`); zones are visited one at a time with a random delay between groups and between zones.
For each group a free sub-zone `<Zone>-<n>` is picked (`_roamPickLocalSubZone`) and, only if the lead unit is stationary and the sub-zone is less than 3 nm away, the group is sent there at 30–60 km/h in a random formation, by road when both ends are near a road (`27721-27760`, `27842-27878`).
Ships use Moose `GROUP:RouteGroundTo(coord, speed, "Off Road", 1)` (`27749-27753`).

### AIEN (`AIEN.lua`, 16 093 lines)

AIEN is a third-party ground-AI script ("AI ENhancement") bundled and modified for Foothold; it runs on its own and calls back into `bc`.
What Foothold exposes in Config: `AIEN.config.dontInitialize=false`, `blueAI=true`, `redAI=true`, `dismount=true`, `message_feed=true`, `initiative=true`, and the scheduler cadences `phaseCycleTimerMin=0.2`, `phaseCycleTimerActive=0.08`, `phaseCycleTimerIdle=0.5` s (`Foothold Config.lua:2363-2382`).
Fixed inside AIEN: `firemissions=true` (artillery fires on targets reported by other units and drones), `uavNightScan=true`, `reactions=true`, `suppression=true` (the source comment says unarmoured groups are suppressed 15–45 s; the code does the opposite test, see "AIEN reactions in detail" below), `directorReaction=true` (`AIEN.lua:17-24`).
Exclusions by group-name fragment: `AIEN_xcl_tag = {"Testing","Hidden","hidden","supply","support","EscortGroup","attack"}` — so convoys named `…-supply-…` / `…-attack-…` are not touched; `"Red SAM"` groups may only delegate; `"Blue SAM"` groups keep awareness but never move or change ROE; `"Blue Armor …"` groups may answer attacks by delegation (`AIEN.lua:27-30`).
Movement limits: `maxGroupInMovement = 10` groups at once, `initiativeRange = 4000` m, `maxSlope = 25°`, speeds 8 m/s off-road, 15 m/s on road, 2 m/s infantry (`AIEN.lua:34`, `44-51`).
Mechanism: one `world.addEventHandler` handling `S_EVENT_HIT`, `S_EVENT_BIRTH`, `S_EVENT_DEAD`/`S_EVENT_UNIT_LOST` (`AIEN.lua:16057-16080`), plus a self-rescheduling `AIEN.performPhaseCycle` that rotates through phases (`update_GROUND`, `update_DRONE`, `update_TACTICAL`, `update_INITIATIVE`) at the cadence above (`AIEN.lua:14069-14071`, `14097`, `14253`, `14857`, `14868`, `15144`).
On a hit the group's situational awareness is scored and one reaction is chosen among: accelerate, disperse, panic (run away), drop smoke, withdraw, attack, cover in buildings, call ground support, move under air-defence cover, fire mission on the shooter (counter-battery) (`AIEN.lua:11933-12733`, `13595`).
Dismounts: trucks/APCs/IFVs hit but not killed drop infantry (MANPAD team if the shooter is airborne), which remount after `remountTime = 600` s (`AIEN.lua:56`, `11507-11870`, `15322-15330`).
Hooks into Foothold: `bc:getZoneOfPoint` to keep reactions inside the owning zone (many sites, e.g. `AIEN.lua:7817`, `12244`); `bc:roamGroupsInZoneNow` to make other groups of the zone move when one is hit (`AIEN.lua:9374`); `bc:startZoneAttackFlash(z, 60)` (`AIEN.lua:13658`); `bc:reportAIENAirSupportAttack` and `bc:reportAIENEnemyPositionAttack`, which ask the Director for an air-support CAP (10 % chance, 20 min cooldown) or an "enemy position response" sortie (30 % chance; helicopter CAS or convoy to the shooter's position) (`AIEN.lua:13554-13556`, `13619`, `15636`; `zoneCommanderv2.lua:70995-70997`, `71901-71907`).
An enemy-position-response convoy drives to the reported point, stays 15 s within 1 km, returns to within 1 km of home and despawns; a warning `AIEN_ENEMY_POSITION_ARTILLERY_CONVOY_WARNING` is sent 2–3 min after launch when the trigger was artillery (`69668-69737`).
`AIEN.ReactToSmoke(zoneObj, groupName, 20)` is called by the engine when smoke is used on a zone (`23658`, `AIEN.lua:11034`).

### AIEN reactions in detail

Entry point: `event_hit(unit, shooter, weapon)` from `S_EVENT_HIT`, only for vehicles of a group that passes `groupAllowedForAI` (exclusion tags, coalition switch) (`AIEN.lua:15179-15265`).
Friendly fire is ignored (`AIEN.lua:15267-15279`).
Order of effects on a hit:

1. `Blue SAM` groups only produce the "zone under attack" report (`reportOnlyReaction`) on their first hit and nothing else (`AIEN.lua:15281-15301`, `13710-13715`).
2. Suppression: if the shooter is known and has the attribute `Air`, `Ships` or `Indirect fire`, and the hit unit has the attribute `Armored vehicles`, `groupSuppress` sets ground ROE to 4 (weapon hold) and back to 2 after 2 × the reaction time (`AIEN.lua:15303-15315`, `10412-10431`).
3. Dismount, first hit only: shooter airborne → the MANPAD team carried by the group is dropped 8–15 s later; shooter is a ground unit within 1 000 m → all carried infantry is dropped 8–15 s later; both remount after `remountTime` (600 s) (`AIEN.lua:15317-15330`, `11793-11860`).
4. Reaction choice, first hit only (a group stays "under attack" for `underAttackTimeout` = 600 s and does not re-evaluate) (`AIEN.lua:15339-15343`, `14150-14153`, `69`): the group is stopped (`trigger.action.groupStopMoving`), and seven facts are computed — weapon category `w_cat` (shell/missile/rocket/bomb), shooter category `s_cat` (plane/helicopter/ground/ship/structure), `s_indirect` (shooter has `Indirect fire`, or unknown shooter with shell/rocket), `s_close` (shooter inside the group's own weapon range), `s_fireMis` (shooter seen less than 30 s ago and slower than 1 m/s, or a 30 % roll), own class `o_cls`, shooter class `s_cls` (`ARBN` for an unknown shooter with missile/bomb) (`AIEN.lua:15354-15466`).
5. The candidate list is the 11 entries of `reactionsDb` minus the ones ruled out by the situation (table below), minus every entry whose index is greater than 2 × the group's skill number (`AIEN.lua:15483-15548`).
   The skill number is the mean `skillVal` of the units as authored in the mission file, a random 4–12 for "Random", and a random 2–5 when the group id is not found in `env.mission` (which is the case of groups created at runtime — estimation) (`AIEN.lua:9842-9879`).
6. Each remaining entry is scored as the sum of seven table look-ups, one per fact (`w_cat`, `s_cat`, `s_indirect`, `s_close`, `s_fireMis`, `o_cls`, `s_cls` weights stored in the entry), the list is sorted by descending score, and `executeReactions` runs the functions in that order until one returns true (`AIEN.lua:15558-15598`, `13595-13610`).
7. On success the group is told to continue moving (`trigger.action.groupContinueMoving`) when the entry has `resume`, and the message, flash and sound of the zone-attack report are produced (`AIEN.lua:13611-13684`).

| # | Reaction | Removed when | What it does | Code |
|---|---|---|---|---|
| 1 | `ac_accelerate` | — | Only if the group is moving: `controller:setSpeed(30, true)`. | `AIEN.lua:11933-11960` |
| 2 | `ac_panic` | — | Drops its infantry, then after the reaction time moves to a random valid terrain point 500–2 000 m away (by road when a road is near and the trip is over 700 m) and sets speed to 30 m/s. | `AIEN.lua:11980-12064` |
| 3 | `ac_disperse` | shooter is a helicopter or a plane | Enables the DCS "disperse under fire" option for the group. | `AIEN.lua:11962-11978`, `15512-15527` |
| 4 | `ac_dropSmoke` | hit unit is not armoured | Needs at least 50 % of units with `HeavyArmoredUnits` or `IFV`; after the reaction time spawns `smoke_source_num` (5) smokes 15–30 m around each such unit, staggered over 1–5 s, and shifts the group a few metres. | `AIEN.lua:12066-12166`, `15532-15534` |
| 5 | `ac_withdraw` | own class is ARTY/MLRS/MISSILE; map Kola | Moves toward the nearest friendly group **of the same zone's garrison** that is 2 000–3 500 m away; 600–900 s later goes back to the end of its editor route or to its original position. | `AIEN.lua:12169-12262`, `15495-15500` |
| 6 | `ac_attack` | shooter position unknown or not detected; shooter is a plane; own class SAM/SHORAD/ARTY/MLRS/AAA | Refused when the enemy strength within 8 km of the shooter exceeds 20; otherwise ROE free, drops infantry (unless the attacker is a helicopter), moves on the shooter's position in cone formation at 10 m/s (4 m/s with dismounts); returns 120 s after getting within 300 m, or after 600 s. | `AIEN.lua:12275-12410`, `15501-15527` |
| 7 | `ac_coverBuildings` | map Kola | Tests four points 2 500 m N/S/E/W of the group, inside the same zone, having at least 4 scenery buildings within 2 500 m (`CustomZone:getZoneBuildings`) and no enemy unit; moves to the centroid of the buildings of the nearest such point; returns after 420–900 s. | `AIEN.lua:12419-12540` |
| 8 | `ac_groundSupport` | shooter not recent enough (`s_fireMis` < 1); shooter unknown; shooter airborne; map Kola | Picks, among the other garrison groups of the same zone, the one with the best class weight (MBT 10, ATGM 9, IFV 7, APC 5.5, SHORAD 5 …) and sends **it** to the hit group's position. | `AIEN.lua:12545-12610`, `253-274`, `15489-15527` |
| 9 | `ac_coverADS` | shooter class is not `ARBN` | Picks the garrison group of the same zone with the best anti-air weight (SAM 10, SHORAD 9, MANPADS 8, AAA 7 …) and, if not already inside its threat range, moves next to it; returns after 900–1 200 s. | `AIEN.lua:12623-12720`, `276-296`, `15529-15531` |
| 10 | `ac_fireMissionOnShooter` | shooter unknown/not detected, or neither a helicopter nor a ground unit | The first idle friendly `ARTY` group with the shooter inside 80 % of its range drops its task and fires 20 rounds at the shooter's position. | `AIEN.lua:12733-12765`, `15501-15511` |
| 11 | `ac_airSupport` | — | Inert: the table entry references a function `ac_airSupport` that is not defined anywhere in the file, so `executeReactions` skips it. | `AIEN.lua:13486-13488`, `13599-13600` |

The reaction time used by every delayed action is `random(1..3) × 25 / skill` seconds (`AIEN.lua:130-131`, `9149-9157`).

After the reaction, still inside the hit handler (`AIEN.lua:15601-15800`):

- counter-battery (`firemissions`): unless the reaction already was a fire mission and unless the shooter is a plane, an idle friendly ARTY/MLRS with the shooter inside 90 % of its range may fire back; it requires a friendly unit with `SAM SR`, `SAM TR` or `EWR` within 50 km of the impact, succeeds with probability `1 − (d / 50 km)²`, announces "identified enemy artillery fire" and fires after 160 s ± 35 % at a point scattered by up to `300 × (d / 50 km)^1.5` m (`AIEN.lua:11121-11215`);
- Director response (Foothold hook, Red only, not Normandy): if the hit group's zone is a Red airbase zone with plane spawn, "armed" for advance capture and not yet eligible, and the attacker is a player helicopter within 5 NM or artillery within 10 NM, then once per zone a 30 % roll calls `bc:reportAIENEnemyPositionAttack(zone, attackerPos, kind)` (`AIEN.lua:13554-13591`, `15618-15638`);
- delegation: a Red SAM/SHORAD/ARTY/MLRS group hit by a helicopter, or any group hit by an eligible ground attacker, hands the fight to the best idle mobile group of the same zone's garrison (class weight × 10 000 − distance, within 4 000 m for the anti-helicopter case and 10 000 m for the ground case); that group runs `ac_attack` with return-to-zone, a second one joins with 25 % chance, and the zone is locked against further delegation for 1 200 s (`AIEN.lua:15641-15800`, `78`);
- zone roam: when nothing stronger was launched, a 10 % roll (15-minute cooldown per zone) calls `bc:roamGroupsInZoneNow(zone, candidates, {stepDelay = 5})` so that other groups of the zone change sub-zone (`AIEN.lua:9360-9378`, `79-81`).

Outside hits, the phase cycle runs these enabled behaviours:

- phase A `update_GROUND`: one group per step, refreshes its situational awareness (`getSA`), expires `tasked` flags after `taskTimeout` and the under-attack flag after 600 s (`AIEN.lua:14097-14190`);
- phase B `update_ISR`: purges dead or stale entries of the intel database (`AIEN.lua:14194-14246`);
- phase C `update_DRONE`: one drone (UAV) group per step gets the same situational-awareness refresh (`getSA`) as ground groups, which is how its contacts enter the intel database; dead drones are dropped (`AIEN.lua:14253-14300`);
- phase D `update_ARTY` (`firemissions`): each idle ARTY/MLRS with rounds left searches enemy units inside 85 % of its range (and outside its minimum range), requires a contact younger than 180 s and, for an unguided battery, a target slower than 0.5 m/s, then fires; **Blue batteries (and both sides in PvP) additionally need a spotter on the target's zone** — a JTAC in the Foothold JTAC queue, an active 9-line, an active scout, or active zone intel (`_zoneIntelIsActive`) (`AIEN.lua:14412-14800`, `14430`, `14556-14600`);
- phase E `update_TACTICAL`: empty in this version, it only advances the phase (`AIEN.lua:14857-14861`);
- phase F `update_INITIATIVE` (`initiative`, not on Kola): only MBT/ATGM/IFV/APC/RECCE groups without an editor route, idle, not under attack, with a strength above 3 and at least one known target; the nearest known enemy group within 4 000 m is compared in strength, and if weaker the group advances to a point on the line toward it (`pointBetween(own, enemy, 5000)`) in cone formation, announces "moving to engage hasty targets", and returns to its post 480 s later; at most `maxGroupInMovement` (10) such moves per cycle (`AIEN.lua:14868-15060`).

### Reproduction notes

AIEN is independent of Moose (raw DCS API) but is a large behaviour engine with its own intel database, timeouts and a per-group skill model; its cost is controlled by the phase cadence and the 10-group movement cap.
Roaming and convoys both depend on hand-placed numbered sub-zones in every zone.

## 11. Air defence: MANTIS network, MFD hiding, night settings

### Mission-maker view

Config (`Foothold Config.lua:508-538`): `DisableMantis = false`; `HideSAMOnMFD = "random"` (`false` shown, `true` hidden, `"random"` 50 % per spawn); `RevealSamOnMfdAfterDetection = false` (PvE only, requires `HideSAMOnMFD = true`); `NightMantisInterval = 30` (seconds between air-defence decisions at night, 0 = off, clamped 15–120); `NightRadarBlur = true`.
`.miz` conventions: SAM groups named with the prefix `Red SAM…`, EWR groups `Red EWR…` (plus `Red GCI` in PvP), AWACS group `AWACS_RED`, optional trigger zones prefixed `Scoot` for shoot-and-scoot relocation (`111399`, `111454-111455`).

### Mechanism

10 s after load, unless disabled or on Normandy/Vietnam: `FootholdMantis = MANTIS:New("Foothold MANTIS","Red SAM","Red EWR",nil,"red",true,"AWACS_RED")` (`111396-111399`).
MANTIS (Moose) keeps SAMs dark (alarm state green / emissions off) and switches a site to red when an EWR/AWACS-detected target enters its range; it embeds Moose `INTEL` workers for detection and a `SEAD` handler for ARM evasion (detail in "What MANTIS does for Foothold" below; Foothold's own code reaches into `mantis.intelset`, `mantis.mysead`, `SamStateTracker`, `SuppressedGroups`, `InboundARMs`: `41616`, `109010-109021`).

### What MANTIS does for Foothold (bundled Moose, `Moose_2026-10-11.lua`)

Membership: two prefix-filtered live sets, `SAM_Group` (`"Red SAM"`) and `EWR_Group` (`"Red EWR"`), both `SET_GROUP:New():FilterPrefixes(...):FilterCoalitions(...)`, so any group spawned later with a matching name joins the network; the sensor set actually filters on the SAM prefixes, the EWR prefixes **and** the AWACS group name, so SAM radars and the AWACS are detectors too (`56826-56842`).
Classification: every third status tick `_RefreshSAMTable` rebuilds five tables — all, long, medium, short, point defence — of records `{name, coordinate, radius, height, blind range, type, ARM capacity}` from `_GetSAMRange` (the function Foothold overrides) (`58458-58461`, `58010`, `57788`).
Start state (`SetSAMStartState`): every SAM gets `EnableEmission(false)` + `OptionAlarmStateGreen()` and `OptionEngageRange(95)` (engage at 95 % of maximum range), and a Moose `SEAD` object is created over all SAM group names (`57925-58009`).
Detection source (`StartIntelDetection`): two `INTEL` workers, one fed by the EWR set and one by the SAM set itself, each processing one detecting group per 0.1 s, with the optional acoustic detection (players within the configured radius, default helicopters only), fused by an `INTEL_DLINK` with a 120 s contact cache (`57512-57554`); the AWACS is not a separate detector here, it is a member of the first worker's set, and in "advanced" mode (not enabled by Foothold) it also counts as a live EWR (`56832-56834`, `57252-57275`).
Main loop: FSM event `Status` re-armed every `detectinterval` seconds (30 by default, 15 set by Foothold); `onbeforeStatus` → `_Check` builds a snapshot of all contacts (group, position, height, category) and runs `_CheckLoop` once per class with that class's cap (`58458-58527`, `58276-58353`).
`_CheckLoop`, per SAM record (`58167-58275`): skip dead sites and sites that lost their tracking radar or are out of missiles; `_CheckObjectInZone` = is any contact within the site's `radius` (2D) and below its `height`; a site is switched on when a contact is in range, the site is not suppressed, not an active SHORAD, and either the class cap is not reached or the threat is "close" (within half the radius once the cap is full) — short-range and point-defence sites are not counted against the cap test for long-range sites.
Emission on/off calls: on = `group:EnableEmission(true)` (when "EmOnOff" mode is used) or `group:OptionAlarmStateRed()`, then FSM event `RedState` (the hook Foothold uses to reveal a SAM on MFDs); off = `EnableEmission(false)` + `OptionAlarmStateGreen()`, then `GreenState`; the current state per name is `SamStateTracker[name]` = `"RED"`/`"GREEN"` (`58210-58262`).
Fallback: when no EWR is alive, one random live SAM that still has a tracking radar is switched on at each tick, so the network is never fully blind (`58466-58492`).
Hit reaction (`_EventHandler`, `S_EVENT_HIT` / `S_EVENT_UNIT_LOST` on a SAM or EWR of the network): the site is switched on at once, `SAMUnitHit`/`SAMUnitLost` fire, and the SHORAD link wakes the neighbours (`56886-56997`).
SHORAD link: `onafterStart` creates a Moose `SHORAD` object over the same SAM set with prefix `"SHORAD"`, activation distance 25 km, active time 600 s, defence limits 80–95 %; whenever a site goes red with the contact closer than 25 km (or inside the site's blind range), or is hit, `Shorad:WakeUpShorad(name, 25 km, 600 s)` switches on the SHORAD groups around it for 75–100 % of the active time, then puts them back to sleep (`58433-58457`, `58248-58253`, `59508-59560`).
ARM defence: the `SHORAD`/`SEAD` shot handlers watch `S_EVENT_SHOT` for anti-radiation and Maverick-type weapons aimed at a network member; `SeadAllowSuppression` lets the targeted site shut down and relocate only when the number of inbound ARMs reaches its `ARMCapacity` (or it has no missiles left); the suppressed site is listed in `SuppressedGroups` and left alone by the main loop until the suppression ends (`58116-58166`, `59703-59720`, `58557-58582`).
Scoot: with `AddScootZones(zoneSet, 3, true, "Cone")`, each time a SHORAD group is woken, put back to sleep or shot at, `onafterShootAndScoot` picks at random one of the first three "Scoot" zones lying 100–3 000 m away and, if the group is stationary, drives it to a random land/road point of that zone at 20 km/h in cone formation (`RouteGroundTo`) (`57013-57021`, `59674-59702`).
A second definition of `_CheckLoop` / `onbeforeStatus` at the end of the class wraps the originals with the jammer extension (not enabled by Foothold) (`59055-59108`).
Foothold overrides `_GetSAMRange` to derive range/height/type from its own upgrade-template cache (largest SAM family in the template wins; names containing `SHORAD` become point defence) (`111401-111435`); registers the SON-9 profile for `Red SAM AAA 3/4` and filters all other `Red SAM AAA…` groups out of the network (`111436-111447`).
Settings: `SetDetectInterval(15)`, `SetAccousticDetectionOn(3000, nil, true, playerSnapshotProvider)` (acoustic detection of players within 3 km), `AddScootZones(SET_ZONE prefix "Scoot", 3, true, "Cone")`, `SetMaxActiveSAMs(3, 3, 3, 6, 6)` (`111450-111456`).
PvP adds a mirrored Blue network `MANTIS:New("Foothold Blue MANTIS","Blue SAM",{"BlueGCI","Blue GCI","Blue EWR"},nil,"blue",true,AWACS_GROUPS[2])` and filters hit/lost events to the own coalition (`111457-111464`, `111484-111493`).
Hide on MFD: at spawn the template field `tpl.hiddenOnMFD` is set for groups whose name contains `Red SAM`, `Blue SAM`, `blueHAWK`, `bluePD`, `bluePATRIOT` (`4432-4441`, `4652`, `5191`, `5238`).
Reveal: each SAM group carries a Moose property `FOOTHOLD_SAM_MFD_SLOT`; `FootholdMantis:OnAfterRedState` records the reveal in `zone.samMfdReveals[index]`, so the next respawn of that slot is spawned with `hiddenOnMFD=false` (`47696-47726`, `111465-111482`, `8417`).
Night: on every player take-off `_nightTakeoffFacts` computes sunrise/sunset at a reference point; if night, `_applyNightMantisState` sets the detect interval to `NightMantisInterval` and applies `INTEL:SetRadarBlur(150, 25, 100, 20)` with `RadarBlurPlayersOnly=true` to every MANTIS intel worker; a daytime take-off restores 15 s and the saved blur values (`101814-101824`, `41579-41640`).
The shop's SEAD/decoy support forces a SAM to red and marks it suppressed for 300 s by writing MANTIS internals (`109007-109024`) — hook only.

### Reproduction notes

MANTIS is the heaviest Moose dependency of this theme: detection fusion (EWR + AWACS + acoustic), emission control with a cap on simultaneously active sites per class, ARM-inbound suppression, shoot-and-scoot.
Foothold additionally depends on private MANTIS/INTEL fields, so behaviour is tied to the bundled Moose build (`Moose_2026-10-11.lua`).

## 12. Strategic bomber, escorts and interceptors (`StrategicBomber`, `DynamicBomber`)

### Player view

Red raid: a mission target "intercept bombers" worth 500 is registered (`RegisterGroupTarget(template, 500, …, "bomb")`) (`4160`).
Blue raid (shop item, hook only): F10 control menu to push/hold/destroy, optional player escort with rewards (`3293`, `3936-4121`, `4195`).
When Red launches an interceptor against the Blue bomber: `ding.ogg` + `STRATEGIC_BOMBER_INTERCEPTOR_LAUNCHED` (`2680-2692`).

### Mission-maker view

`StrategicBomber.Configure({[1]={…}, [2]={…}})` in the setup file: bomber template (`RedBomberEvent[_CW]`, `BlueBomberEvent[_CW]`), `escortTemplates` (the side's CAP templates), route/attack altitude 25 000 ft, speeds (hold 300, to-ingress 380, after-ingress 350 kt), `weaponExpend`, `ingressDistanceNm=25`, `rtbApproachDistanceNm=30`, `pickOptions` (`minTargetSpawnNm=80`, `minPlayerSpawnNm=80`, `avoidPlayerCoalition`, `randomCandidateLimit=5`), Blue-only `interceptorTemplates`, `recoveryZones` (`MA_Setup_CAv2.lua:3652-3715`).
The Red raid is launched by a setup-file event calling `StrategicBomber.LaunchRed()` (`MA_Setup_CAv2.lua:4828`).
Not available in the Vietnam era (`4127`).

### Mechanism

`DynamicBomber.PickMission(attackerSide, targetSide, opts)` collects enemy zones on front-line connections (`CollectTargetCandidates`) and, for each, friendly airbases at least 80 nm from the target and 80 nm from any player (`PickSpawnForTarget`) (`2166-2318`).
The bomber is **air-spawned** with `Respawn.SpawnAtPoint(template, coord, heading, 5, altitude, speed, …)` and radio-silenced (`4140-4144`); the escort is spawned later (`SpawnEscortLater`) and given a raw `ComboTask` of `Follow` (offset 15 nm ahead for Red, 2 000 ft above) + `EngageTargets` planes within 40 nm (`2055-2090`).
`StartBomberAuftrag` (despite the name, raw tasks) → `DynamicBomber.AssignIngressBombingTask`: `BuildBombingTaskForZone` makes one bombing task per unit/static of the target zone's built groups, including its warehouse, then an RTB route with an approach fix and a `Script` task that destroys the group at the last waypoint (`1500-1700`, `1702-1740`, `1776`).
`StrategicBomber.StartMonitor(side)` polls the raid's status; `Finish` applies cooldowns and loss penalties (`2980-3057`).

### The monitor and the Blue controls in detail

Monitor (`3018-3057`): one self-rescheduling `timer.scheduleFunction` per side, period 20 s, first run 20 s after launch, guarded by a per-side token so that a newer raid silently cancels the older loop.
Each tick looks up the bomber by its template name (`Group.getByName(cfg.template)`, the bomber is spawned under that fixed name): if it is gone → `Finish(side, "dead")`; otherwise it refreshes `status = "alive"`, `lastAliveTime`, and re-wakes the idle zones of the raid's footprint.
The successful end is not detected by the monitor: the bomber's last-waypoint script (and the landing handler) call `MarkRecoveredByGroupName`, which sets `status = "recovered"`, pays the player-escort rewards, records the result, cleans up the escort and clears the state without going through `Finish` (`2923-2948`, `1591-1593`, `42268-42269`).
`Finish(side, status)` (`2980-3016`): records `lastResult[side] = {status, time, targetZone, spawnZone}` and tells the Red Director (`onStrategicBomberResult`); on `"dead"` sets `cooldownUntil[side] = now + deathCooldownSeconds` (default 3 600 s) and, for Blue, debits `lossPenaltyCredits` (default 500) with `cancel.ogg` and `STRATEGIC_BOMBER_LOST_CREDITS`; queues the landing cleanup of escort and interceptor (Blue) or destroys the escort (Red, unless the bomber died); destroys the bomber group and clears the state (`2883-2899`).

Blue raid life cycle (`LaunchBlue`, `3759-3935`): the bomber is air-spawned, given unlimited fuel, and either pushes at once or first holds.
Hold reasons: `"player"` when the buyer chose a player escort, `"sam"` when the target zone contains a SAM type listed in `StrategicBomber.BadSamDisplayByName` (the hold message names them) (`3784-3790`, `2552-2582`).
The hold is a raw one-waypoint mission at the spawn point: `{id="Mission", params={route={points={{type="Turning Point", alt=<route altitude>, alt_type="BARO", speed=<300 kt IAS as TAS>, task=ComboTask{ {id="Orbit", params={pattern="Circle", speed, altitude}} }}}}}}` (`3341-3386`).
Blue F10 menu: under the per-group root `Dynamic Control` (`MENU_DYNAMIC_CONTROL`, built by `buildCapControlMenu`), a sub-menu named after the bomber ("B-1B Lancer", "B-52H Stratofortress" in Cold War) with `Push` (only while not yet pushed) and `Destroy`; there is no `Hold` command in the menu although `HoldBlue` and its label exist (`4195-4223`, `16425`, `16656-16657`, `Foothold_Localization.lua:162`, `656-657`, `693-695`).
`PushBlue` (`3936-4039`): refuses when already pushing; calls `StartBomberAuftrag(missionId, template, targetZone, escortName, nil, {routeAltitudeFt, attackAltitudeFt, weaponExpend, toIngressSpeedKt, afterIngressSpeedKt, staticsLast=true, deferBombingTaskToIngress=true, landAndRefuelAtOrigin=true, homeAirbaseName, rtbApproachDistanceNm})`, sets `pushed`, rolls the Red interceptor (`TrySpawnBlueInterceptor`), plays `ding.ogg` and announces `STRATEGIC_BOMBER_PUSHING` with an ETA to ingress (or the player-escort variant), then rebuilds the control menu.
`DestroyBlue` destroys bomber and escort and clears the state, with `STRATEGIC_BOMBER_DESTROYED` to the caller (`4101-4121`).
Player escort (`3100-3340`): a client counts as escorting while within 2 NM horizontally and ±2 000 ft of the bomber lead (`PlayerEscortRadiusMeters`, `PlayerEscortAltitudeToleranceMeters`, `2339-2340`); after 60 s in that envelope (`PlayerEscortQualifySeconds`, `2341`) the player is "qualified", and if the raid was holding for a player escort and no bad SAM remains, the first qualification pushes the bomber automatically (`3161-3185`, `3207-3232`).
When the bomber is recovered, `playerEscortReward` (default 1 000) is split equally between the qualified players as contribution credit, with the career stat "Strategic bomber escort" and the message `STRATEGIC_BOMBER_ESCORT_COMPLETED_SOLO` / `_MULTI` (`3125-3159`).
Interceptor vs Blue bomber: one roll per raid, `math.random(1,10) <= threshold` with threshold 1/3/6 for `CapDifficulty` easy/medium/hard; spawned from the closest Red CAP-recovery airbase on free fighter parking (`FindFreeParkingSpotForAircraft`) from a random Red CAP template, tasked by `AssignInterceptorTask` (`2344-2348`, `2640-2678`, `2787-2880`).
WW2/Normandy has a parallel older bomber set (`bomberRedTemplate = 'DynamicBomberRed_Template'`, `redInterceptorTemplate`, min spawn distances 40 nm) (`110205-110228`).

## 13. Normandy-only artillery supports (navy artillery, strikers, V1)

`spawnNavyArtyAt(zone, targetZone, strikerZone)`: returns immediately unless the map is Normandy (`109950-109951`); spawns template `UK_NavyArty` on water (`SPAWN:New():SpawnFromCoordinate`), wraps it in `NAVYGROUP`, `AddWeaponRange(1, 8, Auto)`, and adds one `AUFTRAG:NewARTY(group, nil, 250)` per Red group found in the target zone by a one-shot `SET_GROUP` filter (`109968-110024`).
Messages `NAVY_ARTY_ENGAGING_TARGETS`, `NAVY_ARTY_MISSION_COMPLETED`, `NAVY_ARTY_GROUP_DESTROYED`; a menu entry rebuilt by `buildCapControlMenu()` allows despawning (`109940-109948`, `110025-110036`).
Optional enemy "striker": template `AXE_NavyArty_Striker` air-spawned at 7 620 m in the striker zone, `FLIGHTGROUP` + `AUFTRAG:NewANTISHIP(navyGroup, 3000)`, half weapon expend, destroyed 5 s after landing (`110037-110095`).
V1 sites: `spawnV1ArtyAt(site, cfg)` / `launchRandomV1Artillery()` use `ARMYGROUP` + `AUFTRAG:NewARTY(target, 1, 100)`, five rockets then a 600 s reload (`111165`, `111330-111349`, `111373-111389`).

## 14. Blue AI in PvE, and PvP differences

### PvE

Blue AI flights exist but are throttled to support, not replace, players: CAP/CAS/SEAD limits of 1 group with at most one player online and 0 beyond at the default `"medium"` (`61022-61110`); Blue CAP always also engages helicopters (`35772-35774`); Blue runway-strike aircraft are invisible to AI (`35512-35514`).
Blue AI aircraft are spawned at `"Excellent"` skill, Red at `AiPlaneSkill` (default `"Random"`) (`68504`, `Foothold Config.lua:861`).
Blue regular supply costs credits when players are online and is gated by `NoAIBlueSupplies` / the F10 toggle `RadioMenuStopSupplies`; `NoAIBlueCapture` stops Blue AI capturing neutral zones (`66121-66125`, `66172-66179`, `66386-66403`, `Foothold Config.lua:1354-1363`).
Blue supply and Blue AI aircraft draw airframes from the DCS warehouse (`_prepareBlueAiWarehouseSpawn`) and add warehouse stock on delivery (`68580`, `67863-67871`).
Blue ground defences are the `blue = {'blueInfantry', 'Blue Armor Modern', 'Blue SAM NASAMS', …}` lists of each zone's upgrade table, capped by `MaxBlueGroundGroupsPerZone = 4` (Red: `MaxRedGroundGroupsPerZone = 12`), with skills `BlueAiGroundSkill` / `RedAiGroundSkill` (`MA_Setup_CAv2.lua:94-97`, `Foothold Config.lua:463-481`, `541-544`).
Shop-bought support flights (CAP/CAS/SEAD/decoy/bomber/structure strike) use separate templates (`CAP_Template`, `DynamicCas_Template`, `DynamicSead_Template`, `DynamicDecoy_Template`, `DynamicBomber_Template`, `DynamicStructure_Template`, each with `_CW`/`_VT` variants) and `DynamicSupportNative`; Config `AIAttackTakeoffFromGround = true` decides ground start vs air spawn for them (`105244`, `107935`, `108217`, `108673`, `109335`, `109698`, `106266`, `106500-106502`, `Foothold Config.lua:1941-1944`) — hook only.

### PvP (`GlobalSettings.pvpEnabled`)

Role limits come from the per-side Director (`director:_configuredRoleLimit`, `_groupSlotAvailable`) instead of the player-count tables (`66288-66312`, `66421-66426`).
Config `PvPDisableCombatAI` removes automatic combat flights; `PvPCombatAIGroupLimit = 10` caps automatic fixed-wing combat groups per coalition, reduced by that side's own player planes (0 = balance the sides) (`Foothold Config.lua:328-337`, `17095-17102`).
Red gets the Blue treatment: hot-start supply, warehouse draw, no credit debit (`68508`, `68373-68375`).
Intel messages and map markers about enemy convoys/transports are only sent to a side holding an active intel grant on the source zone (`67526-67535`, `69805-69816`).
Hunter is disabled (`40975-40978`); a Blue MANTIS exists (`111484`); Blue ground groups also roam (`MA_Setup_CAv2.lua:2865-2876`).
The "Blue player near origin" spawn block does not apply to air and supply groups (`66158-66160`).

## 15. Throttles, staggering and cleanup

| Mechanism | Value | Code |
|---|---|---|
| Main loop | `BattleCommander:update` every `updateFrequency` (10 s); after the first pass zones are updated one per 0.1 s "wave" step | `17117-17121`, `43282-43346` |
| Active-FSM list | each zone only updates groups in `_activeFsmGroups`; a group is deactivated when it is `inhangar`/`dead` with nothing pending | `56268-56371` |
| Dormant sleep | `inhangar`/`dead` groups skip updates until `lastStateTime + delay − 30 s`, re-checked at most every 30 s (`dormantFsmLeadSec`, `dormantFsmMaxSleepSec`, `dormantFsmRetrySec`) | `65896-66000`, `8531-8533` |
| In-flight throttle | non-supply `inair` and surface `enroute` groups are processed one tick in three (`activeFsmThrottleBuckets = 3`) | `66977-66994`, `17136`, `43241-43250` |
| Spawn-evaluation queue | eligibility checks are queued and evaluated by a dispatcher: tick 0.5 s (±0.15 jitter), 8 evaluations per tick (18 when more than 70 are queued), result cached 60 s | `17126-17133`, `17853-18000`, `66090-66098` |
| Hangar jitter | 0–25 min random offset on every return to hangar | `57288-57312` |
| Role caps | see §3 | |
| Zone dormancy | zones deeper than 80 nm (Blue) / 120 nm (Red) behind the front are suspended and their non-combat groups do not launch (`proximityWakeNm = 40`, `proximityWakeHoldSeconds = 600` control waking; the suspend/wake logic is described in note 01, section 9) | `8524-8527`, `66135-66156` |
| No spawn near players | Red origin zone with a Blue player near → back to hangar | `66158-66165` |
| Regular supply budget | `regularSupplyDispatchBudgetPerTick = 2` | `8504` |
| Stuck aircraft | despawn after 12 min on the ground (`blockedDespawnTime`), landed aircraft after 60 s / 180 s | `67585-67590`, `8534-8535` |
| Landing cleanup | `_scheduleLandingCleanup`: destroy the group 0.5 s after landing was processed | `57461-57469` |
| Wreck cleanup | before each spawn, `world.removeJunk` on a sphere of the **target** zone's radius | `66599-66602`, `56873-56882` |
| AIEN | at most 10 groups moving; phase cadence 0.08–0.5 s | `AIEN.lua:34`, `Foothold Config.lua:2380-2382` |
| MANTIS | at most 3/3/3/6/6 active SAMs per class; detect interval 15 s (30 s at night) | `111450-111456` |

## 16. Reproduction notes for the sortie system as a whole

The FSM is a pure polling design (no `S_EVENT_*`): group existence, "any unit airborne", "all landed", "any unit in zone" are sampled each tick, so every state change has up to one tick (10 s, or 30 s for throttled in-air groups) of latency.
The Moose pieces it actually needs are: template cloning with unique names (`SPAWN:NewFromTemplate`, alias), parking-spot discovery and reservation (`AIRBASE:GetFreeParkingSpotsTable`, `SpawnAtParkingSpot`) — the hardest part to redo, since DCS exposes only `Airbase:getParking()` and the spawn must write per-unit `parking` (the `Term_Index`) and the first waypoint's airbase link into the group table (see "What the Moose parking spawn writes" in §2) — and waypoint table builders.
Side-agnostic records (one authored origin→target pair usable by whichever coalition owns the origin) rest on the per-side template lists.
The in-air restore path after a server restart (`_processAirRestoredSpawn`, `68044`) re-spawns flights in the air at their saved position; it is the only air spawn of regular sorties (see "Restore of air sorties" in §2 and "Restore of surface sorties" in §6).
Hidden dependencies: `Frontline` (distance to front, CAP station picking), `ZONE_DISTANCES` and the sub-zone/road-hook caches, the intel system (`_zoneIntelBroadcast`, `_jtacMessage`), the warehouse logistics, and the Director callbacks sprinkled through every state (`_recordDirectorRegularSupplyOutcome`, `onManagedSpawnDenied`, `requestDirectorInstanceDisposal`).

## Seen outside this theme

- `DirectorCapability` records and their activation/derivatives — Director theme (`11958`, `26280-26450`).
- "Dynamic hybrid" generation of missing capabilities along connections — Director theme (`31805-34000`).
- `RunwayHandler` / runway strike **player** mission: `EVENT` shot handler tracking player bombs with Moose `WEAPON:SetFuncImpact`, reward 100/200, then `bc:blockRunwayPlaneSpawns(zone, 3300)` which stops AI plane spawns from that zone for 55 min (`62287-62602`, `30463-30466`) — missions theme.
- `HercCargoDropSupply`: player Hercules cargo drops capturing or supplying a zone (`102303-102444`) — logistics theme.
- Player-bought ground attack groups (`playerGroundAttack`, `dc.BuildPlayerGroundAttackRouteFromPoint`, retasking) (`69559`, `20335`) — shop theme.
- Shop support flights and `DynamicSupportNative` (`105244-109700`, `106266-106469`) — shop theme.
- Zone capture start (`startPendingCapture`, `startPendingCaptureFromAircraft`) and supply stock (`_applyRegularSupplyDelivery`, regular supply permits) — capture/logistics themes (`67828`, `69940`).
- Surface/air "intel" last-known markers and route reports (`_scheduleSurfaceIntelRouteReports`, `69407`) — intel theme.
- Career/night reward on take-off (`101808-101813`) — rewards theme.
- CAP player missions and generators (`checkAndGenerateCAPMission`, `65505`) — missions theme.

