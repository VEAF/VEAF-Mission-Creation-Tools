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
The spawn itself is Moose `SPAWN:NewFromTemplate(tpl, resolved, alias, true):InitSkill(...):OnSpawnGroup(cb)` then `SpawnAtParkingSpot(airbase, spots, takeoff)` with fallback `SpawnAtAirbase` (`68503-68507`, `68579-68582`); these wrap `coalition.addGroup` with a rewritten first waypoint (estimation for the Moose internals).
Skill is `AiPlaneSkill` (Config) for Red and always `"Excellent"` for Blue (`68504`).
Start is cold unless the group is a Blue (or PvP) supply flight or has `SpawnHot` (`68508-68509`).
Planes with no parking are not spawned (back to hangar); helicopters with no parking are spawned on the ground inside the zone by `_spawnFromGroundAt` (`68611-68617`, `66786`).
Blue AI spawns first call `_prepareBlueAiWarehouseSpawn` so the DCS warehouse holds the airframe (`68580`).
Supply helicopters can also launch from a player-built CTLD FARP (`_pendingSupplyFarpLaunch`, `SpawnAtAirbase(farpAb, Hot)`) (`68518-68553`).
After a successful spawn: `Spawned=true`, `state='takeoff'`, an intel message `INTEL_AIR_STARTING_UP_AT` is broadcast when the group is in the origin zone (`68667-68697`).

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

## 5. Strike tasking (CAS, SEAD, runway strike, anti-ship)

All four use the same pattern: compute waypoints from the group's current position, build DCS task tables, wrap them with Moose `COORDINATE:WaypointAirTurningPoint(...)` / `WaypointAirLanding(...)` and push with `GROUP:Route(wp, 1)` (a `Mission` task set on the controller after 1 s), then `bc:setDefaultAG(group)` for options (`35309-35429`).
SEAD: `buildSeadIngressPlan` picks viable emitters and an ingress point; the route is start → optional climb → commit point (task = `EngageTargets {'SAM elements','Air Defence'}` + one attack task per viable unit from `getAttackTask`) → target → 20 nm approach fix → landing; a self-defence `EngageTargets` vs planes within 15 nm (Red) / 20 nm (Blue) rides on every leg (`35322-35423`).
`gmoose:TaskFunction("BattleCommander.MarkSeadIngressCommitted", routeState)` and `"BattleCommander.MarkAirReturnHome"` are script callbacks fired at waypoints to update FSM flags (`35377`, `35391`).
Runway strike: 4 waypoints along the straight line to the target airbase (attack at 75 % of the distance, 450 kt), task `BombingRunway {runwayId, weaponType=AnyBomb, expend=ALL, groupAttack=true}` (`35431-35521`); the three-ship templates carry BetAB-500 / Durandal (`MA_Setup_CAv2.lua:1145-1150`).
CAS plane/helicopter and anti-ship (`EngageCasMission` 36091, `EngageHeloCasMission` 36325, `EngageAntiShipMission` 35524) follow the same construction (not read line by line — estimation).
Blue runway-strike aircraft are made invisible to AI with the `SetInvisible` command (`35512-35514`).

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
Supply planes use `_assignPlaneRoute` (not read in detail — estimation: straight route and landing at the target airbase).
Supply helicopters get ROE via `_applySupplyHeloDefaultRoe` and `OptionPreferVerticalLanding` (`58301`, `68600`).

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
Fixed inside AIEN: `firemissions=true` (artillery fires on targets reported by other units and drones), `uavNightScan=true`, `reactions=true`, `suppression=true` (unarmoured groups hit by artillery or air are suppressed 15–45 s), `directorReaction=true` (`AIEN.lua:17-24`).
Exclusions by group-name fragment: `AIEN_xcl_tag = {"Testing","Hidden","hidden","supply","support","EscortGroup","attack"}` — so convoys named `…-supply-…` / `…-attack-…` are not touched; `"Red SAM"` groups may only delegate; `"Blue SAM"` groups keep awareness but never move or change ROE; `"Blue Armor …"` groups may answer attacks by delegation (`AIEN.lua:27-30`).
Movement limits: `maxGroupInMovement = 10` groups at once, `initiativeRange = 4000` m, `maxSlope = 25°`, speeds 8 m/s off-road, 15 m/s on road, 2 m/s infantry (`AIEN.lua:34`, `44-51`).
Mechanism: one `world.addEventHandler` handling `S_EVENT_HIT`, `S_EVENT_BIRTH`, `S_EVENT_DEAD`/`S_EVENT_UNIT_LOST` (`AIEN.lua:16057-16080`), plus a self-rescheduling `AIEN.performPhaseCycle` that rotates through phases (`update_GROUND`, `update_DRONE`, `update_TACTICAL`, `update_INITIATIVE`) at the cadence above (`AIEN.lua:14069-14071`, `14097`, `14253`, `14857`, `14868`, `15144`).
On a hit the group's situational awareness is scored and one reaction is chosen among: accelerate, disperse, panic (run away), drop smoke, withdraw, attack, cover in buildings, call ground support, move under air-defence cover, fire mission on the shooter (counter-battery) (`AIEN.lua:11933-12733`, `13595`).
Dismounts: trucks/APCs/IFVs hit but not killed drop infantry (MANPAD team if the shooter is airborne), which remount after `remountTime = 600` s (`AIEN.lua:56`, `11507-11870`, `15322-15330`).
Hooks into Foothold: `bc:getZoneOfPoint` to keep reactions inside the owning zone (many sites, e.g. `AIEN.lua:7817`, `12244`); `bc:roamGroupsInZoneNow` to make other groups of the zone move when one is hit (`AIEN.lua:9374`); `bc:startZoneAttackFlash(z, 60)` (`AIEN.lua:13658`); `bc:reportAIENAirSupportAttack` and `bc:reportAIENEnemyPositionAttack`, which ask the Director for an air-support CAP (10 % chance, 20 min cooldown) or an "enemy position response" sortie (30 % chance; helicopter CAS or convoy to the shooter's position) (`AIEN.lua:13554-13556`, `13619`, `15636`; `zoneCommanderv2.lua:70995-70997`, `71901-71907`).
An enemy-position-response convoy drives to the reported point, stays 15 s within 1 km, returns to within 1 km of home and despawns; a warning `AIEN_ENEMY_POSITION_ARTILLERY_CONVOY_WARNING` is sent 2–3 min after launch when the trigger was artillery (`69668-69737`).
`AIEN.ReactToSmoke(zoneObj, groupName, 20)` is called by the engine when smoke is used on a zone (`23658`, `AIEN.lua:11034`).

### Reproduction notes

AIEN is independent of Moose (raw DCS API) but is a large behaviour engine with its own intel database, timeouts and a per-group skill model; its cost is controlled by the phase cadence and the 10-group movement cap.
Roaming and convoys both depend on hand-placed numbered sub-zones in every zone.

## 11. Air defence: MANTIS network, MFD hiding, night settings

### Mission-maker view

Config (`Foothold Config.lua:508-538`): `DisableMantis = false`; `HideSAMOnMFD = "random"` (`false` shown, `true` hidden, `"random"` 50 % per spawn); `RevealSamOnMfdAfterDetection = false` (PvE only, requires `HideSAMOnMFD = true`); `NightMantisInterval = 30` (seconds between air-defence decisions at night, 0 = off, clamped 15–120); `NightRadarBlur = true`.
`.miz` conventions: SAM groups named with the prefix `Red SAM…`, EWR groups `Red EWR…` (plus `Red GCI` in PvP), AWACS group `AWACS_RED`, optional trigger zones prefixed `Scoot` for shoot-and-scoot relocation (`111399`, `111454-111455`).

### Mechanism

10 s after load, unless disabled or on Normandy/Vietnam: `FootholdMantis = MANTIS:New("Foothold MANTIS","Red SAM","Red EWR",nil,"red",true,"AWACS_RED")` (`111396-111399`).
MANTIS (Moose) keeps SAMs dark (alarm state green / emissions off) and switches a site to red when an EWR/AWACS-detected target enters its range; it embeds Moose `INTEL` workers for detection and a `SEAD` handler for ARM evasion (estimation for the Moose internals; the code reaches into `mantis.intelset`, `mantis.mysead`, `SamStateTracker`, `SuppressedGroups`, `InboundARMs`: `41616`, `109010-109021`).
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
| Zone dormancy | zones deeper than 80 nm (Blue) / 120 nm (Red) behind the front are suspended and their non-combat groups do not launch (`proximityWakeNm = 40`, `proximityWakeHoldSeconds = 600` control waking; wake logic not read) | `8524-8527`, `66135-66156` |
| No spawn near players | Red origin zone with a Blue player near → back to hangar | `66158-66165` |
| Regular supply budget | `regularSupplyDispatchBudgetPerTick = 2` | `8504` |
| Stuck aircraft | despawn after 12 min on the ground (`blockedDespawnTime`), landed aircraft after 60 s / 180 s | `67585-67590`, `8534-8535` |
| Landing cleanup | `_scheduleLandingCleanup`: destroy the group 0.5 s after landing was processed | `57461-57469` |
| Wreck cleanup | before each spawn, `world.removeJunk` on a sphere of the **target** zone's radius | `66599-66602`, `56873-56882` |
| AIEN | at most 10 groups moving; phase cadence 0.08–0.5 s | `AIEN.lua:34`, `Foothold Config.lua:2380-2382` |
| MANTIS | at most 3/3/3/6/6 active SAMs per class; detect interval 15 s (30 s at night) | `111450-111456` |

## 16. Reproduction notes for the sortie system as a whole

The FSM is a pure polling design (no `S_EVENT_*`): group existence, "any unit airborne", "all landed", "any unit in zone" are sampled each tick, so every state change has up to one tick (10 s, or 30 s for throttled in-air groups) of latency.
The Moose pieces it actually needs are: template cloning with unique names (`SPAWN:NewFromTemplate`, alias), parking-spot discovery and reservation (`AIRBASE:GetFreeParkingSpotsTable`, `SpawnAtParkingSpot`) — the hardest part to redo, since DCS exposes only `Airbase:getParking()` and the spawn must write per-unit `parking`/`parking_id` into the group table — and waypoint table builders.
Side-agnostic records (one authored origin→target pair usable by whichever coalition owns the origin) rest on the per-side template lists.
The in-air restore path after a server restart (`_processAirRestoredSpawn`, `68044`) re-spawns flights in the air at their saved position; it is the only air spawn of regular sorties (persistence theme).
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

