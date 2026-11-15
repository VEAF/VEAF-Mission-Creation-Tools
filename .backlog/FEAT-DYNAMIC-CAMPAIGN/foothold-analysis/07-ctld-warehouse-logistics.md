# 07 — CTLD and warehouse logistics (Foothold v6.5.3)

Source: upstream tag v6.5.3, commit 27d8cf4a.
Short file names used in citations: `CTLD.lua` = `Common Scripts/Foothold CTLD.lua`, `CTLD_Red.lua` = `Common Scripts/Foothold_CTLD_Red.lua`, `zc2` = `Common Scripts/zoneCommanderv2.lua`, `Moose` = `Common Scripts/Moose_2026-10-11.lua`, `Config` = `Common Scripts/Foothold Config.lua`, `L10N` = `Common Scripts/Foothold_Localization.lua`, `Setup` = `Setup files/MA_Setup_CAv2.lua`.

The bundled Moose `CTLD` class is version 1.4.45 (`Moose:76160`).
It is not a stock class used untouched: it already contains hooks that only exist for Foothold (e.g. `self._updateManagedWarehouseDynamicCargo` called from the Moose event handler, `Moose:77313`, `Moose:77346`, a function defined in `CTLD.lua:6603`).
In this document "Moose" means "implemented inside the bundled Moose `CTLD` class", "Foothold" means "implemented in `Foothold CTLD.lua` / the engine".

## Feature list

| # | Feature | One-line description | Main code location |
|---|---|---|---|
| 1 | CTLD instance and transport aircraft | One Moose CTLD per coalition, group-prefix filter, per-airframe capacities | `CTLD.lua:104-176`, `CTLD.lua:453-476` |
| 2 | Cargo catalogue | Troops, crate-built vehicles and SAMs, C-130J whole vehicles, static supply crates, per era | `CTLD.lua:264-367` |
| 3 | Prices, rank, availability | Credit price and minimum rank per item, hide unavailable items | `CTLD.lua:182-257`, `CTLD.lua:373-388` |
| 4 | Zones following ownership | Friendly zone = pickup zone, other zones = move targets, ships, FARPs | `CTLD.lua:483-542` |
| 5 | Load/unload/build flow and payment veto | Debit before spawn, refund of returned troops, voice clips | `CTLD.lua:6636-6675`, `Moose:78256-78283` |
| 6 | Stock and limits | Finite stock, oldest group removed under 5, 60 s refill, restore caps | `CTLD.lua:408-450`, `CTLD.lua:6087-6117`, `CTLD.lua:9331-9415` |
| 7 | Troops → capture / reinforce / return | Dropped troops capture neutral zones, supply friendly ones, or are refunded | `CTLD.lua:8286-9327` |
| 8 | Zone supplies | Physical supply crates tracked from pickup to delivery; capture or stock a zone | `CTLD.lua:3044-5476`, `CTLD.lua:6733-6782` |
| 9 | Warehouse cargo | Bundles that move weapon stock between airbase warehouses | `CTLD.lua:1309-1354`, `CTLD.lua:6300-6634`, `CTLD.lua:6785-6959` |
| 10 | Zone Spy and Demolition Team | AI special teams: one-hour zone intel, timed charges on zone structures | `CTLD.lua:1531-2589` |
| 11 | SAM add-ons and merge | Extra launcher/radar crates merged into a nearby HAWK/NASAMS/IRIS-T site | `CTLD.lua:556-1281`, `CTLD.lua:7847-8095` |
| 12 | SAM spacing rule (PvP) | 8 NM between same-type protected SAM builds | `CTLD.lua:2778-2900` |
| 13 | C-130J load, air-drop, auto-build | Dropped crate sets build themselves through a hidden helper soldier | `CTLD.lua:2595-2775`, `CTLD.lua:3455-3759` |
| 14 | FARP and FARP with ZELL kits | Player-built invisible FARP with warehouse, supply counter, optional ZELL launcher | `CTLD.lua:5525-5925` |
| 15 | Rewards, kill credit, career hooks | Build rewards, kills by player-built units, career statistics | `CTLD.lua:5930-6298`, `zc2:42827-42845` |
| 16 | Persistence | Moose CSV for units/troops, own CSV for FARPs, pruning by distance and caps | `CTLD.lua:7609-8284` |
| 17 | Warehouse logistics system | Finite weapon stocks per airbase, catalogue, refills, location policy, aircraft lists | `zc2:51006-51340`, `zc2:112318-115262`, `zc2:20074-20244` |
| 18 | LogisticCommander legacy logistics | Virtual "load supplies" menu (legacy mode), menus owner, take-off warning | `zc2:97554-98443`, `zc2:101336-101791` |
| 19 | F10 menu tree | Logistics → Zone supplies / Warehouse / Mark Zone / CTLD … | `zc2:101557-101781`, `Moose:80721-81133` |
| 20 | HercCargoDropSupply | Hercules-mod generic crate dropped over a zone = supply delivery | `zc2:102295-102457` |
| 21 | ExternalHeloCargoRoute | AI-only sling-cargo task builders (player sees AI helo with crate) | `zc2:58056-58240` |
| 22 | Red CTLD | Second CTLD instance for RED (PvE option or PvP) | `CTLD_Red.lua:1-2417` |
| 23 | Config settings | Summary table of CTLD and logistics settings | `Config:1273-1434`, `Config:1955-2176` |
| 24 | Performance devices | Throttles, queues, caches, dormancy | see §24 |
| 25 | Base Moose CTLD features relied on | Neutral list for comparison with another CTLD | see §25 |
| 26 | Zone "regular supply" economy | Ready-supply production, stock, AI dispatch permits, local repair/build jobs, timings | `zc2:52059-55000`, `zc2:8480-8504` |
| 27 | Destroyable warehouse building | `[WH]` static of a Logistic Center: siting, destruction effects, 30-min repair, shop items | `zc2:46108-46580`, `zc2:24155-24253` |
| 28 | `TheaterInfrastructure` | A destroyed map building permanently cuts a RED supply route | `Setup:2271-2360`, `zc2:53810-53861` |
| 29 | PvP industry and starting territory | Industry cores, income cut, industry strike mission, starting territory share | `zc2:55109-55159`, `zc2:102566-102742`, `Setup:5876-5908` |
| 30 | Train supply and repair (Normandy) | Not analysed (source no longer available) | — |

## 1. CTLD instance, options and transport aircraft

### Player view

Players in a transport-capable aircraft get an F10 `CTLD` menu (built by Moose `CTLD:_RefreshF10Menus`, `Moose:80721`).
The doors must be open to load or unload (`pilotmustopendoors = true`, `CTLD.lua:158`).
Crates may be dropped anywhere (`dropcratesanywhere = true`, `CTLD.lua:142`), hover load is not forced and auto hover-load is off (`CTLD.lua:143`, `CTLD.lua:155`), sling load is enabled (`CTLD.lua:156`).
Building takes 30 s (`buildtime = 30`, `CTLD.lua:159`).
Fixed-wing transports can para-drop above 100 m AGL and below 200 (unit as used by Moose) of speed (`CTLD.lua:149-151`).

### Mission-maker view

One Moose instance is created for BLUE: `Foothold_ctld = CTLD:New(coalition.side.BLUE, {prefix list}, "Lufttransportbrigade I")` (`CTLD.lua:104`).
The second argument is a list of **group-name prefixes** (Lua patterns): `CH.47`, `Ka.50.III`, `SA342L`, `UH.1H`, `Hercules`, `Mi.8MT`, `Ми.8МТВ2`, `Ми.24П`, `Bronco.OV`, `UH.60L`, `Mi.24P`, `OH.58D`, `KA.50`, `AH.64D`, `UH.60.DAP`, `C.130J.30`, `MH.60R` (`CTLD.lua:104`).
A client slot only gets CTLD if its group name starts with one of these prefixes: Moose builds `SET_GROUP:New():FilterCoalitions():FilterPrefixes(prefix):FilterStart()` (`Moose:83545-83551`).
Per-airframe capabilities are a global table `CTLDUnitCapabilities` (overridable before the script loads): `{canCrates, canTroops, crateLimit, troopLimit, length, maxCargoMassKg}` applied with `CTLD:SetUnitCapabilities` (`CTLD.lua:453-476`).

| Type | crates | troops | crate limit | troop limit | cargo mass (kg) |
|---|---|---|---|---|---|
| SA342L | no | yes | 1 | 2 | 400 |
| SA342M / Mistral / Minigun | no | yes | 0 | 2 | 400 |
| UH-1H | yes | yes | 1 | 8 | 800 |
| Mi-8MT | yes | yes | 3 | 16 | 6000 |
| Mi-8MTV2 | yes | yes | 3 | 18 | 6000 |
| Mi-24P / Mi-24V | yes | yes | 2 | 8 | 1000 |
| UH-60L / UH-60L_DAP | yes | yes | 2 | 20 | 3500 |
| CH-47Fbl1 | yes | yes | 5 | 32 | 10800 |
| Hercules (mod) | yes | yes | 8 | 20 | 20000 |
| C-130J-30 | yes | yes | 7 | 64 | 21500 |
| Ka-50, Ka-50_3, AH-64D_BLK_II, OH58D | no | no | 0 | 0 | 400 |

(`CTLD.lua:453-472`.)

Other instance options set by Foothold (all are Moose `CTLD` fields): `CrateDistance = 65`, `PackDistance = 120`, hover window 3–20 m, `smokedistance = 8000`, `dropAsCargoCrate = true`, `nobuildinloadzones = true` (false in PvP), `movecratesbeforebuild = false`, `usesubcats = true`, `TroopUnloadDistGroundHook = 35`, `droppedbeacontimeout = 7200`, `movetroopsdistance = MaxTroopsRunDistanceTowardZone or 5000`, `onestepmenu = true`, `basetype = "uh1h_cargo"`, a list of 5 vehicle move formations, `returntroopstobase = false` (`CTLD.lua:142-171`).
`UseC130LoadAndUnload` (Config global) is copied onto the instance (`CTLD.lua:168-170`).
`CaptureZoneWithEngineer` (Config, default false) decides whether the single "Engineer soldier" may capture or upgrade a zone (`CTLD.lua:173-174`, `CTLD.lua:1283-1287`).
The instance is started with `Foothold_ctld:__Start(1)` (`CTLD.lua:176`).

### Mechanism

Moose `CTLD:onafterStart` subscribes to `EVENTS.PlayerEnterAircraft`, `PlayerEnterUnit`, `PlayerLeaveUnit`, `UnitLost`, `NewDynamicCargo`, `DynamicCargoLoaded`, `DynamicCargoUnloaded`, `DynamicCargoRemoved`, `Land`, `Takeoff` (`Moose:83555-83564`), i.e. DCS `S_EVENT_PLAYER_ENTER_UNIT`, `S_EVENT_PLAYER_LEAVE_UNIT`, `S_EVENT_UNIT_LOST`, the four dynamic-cargo events, `S_EVENT_LAND`, `S_EVENT_TAKEOFF` through Moose `EVENT`/`world.addEventHandler`.
Moose runs a status FSM tick every 30 s (`__Status(-30)`, `Moose:83639`) that cleans dead dropped troops, refreshes F10 menus, checks dropped beacons, refreshes radio beacons, checks auto-hover-load and engineers (`Moose:83595-83603`).
Moose keeps per-unit state `Loaded_Cargo[unitName] = {Troopsloaded, Cratesloaded, Cargo = {CTLD_CARGO…}}`, cleared when a player enters or leaves the unit (`Moose:77273-77306`).
Localisation of every CTLD string is redirected to Foothold's own table through `SetGroupLocaleResolver` (`CTLD.lua:133-135`) and the `CTLD_MENU_LABEL_KEYS` map for menu labels (`CTLD.lua:50-99`).

### Reproduction notes

Everything in this file hangs on the Moose `CTLD` FSM (`OnAfterTroopsPickedUp`, `OnAfterTroopsDeployed`, `OnAfterGetCrates`, `OnAfterCratesPickedUp`, `OnAfterCratesBuild`, `OnAfterCratesBuildStarted`, `OnBeforeCratesPacked`, `OnAfterCratesPacked`, `OnAfterRemoveCratesNearby`, `OnAfterLoaded`) and on five veto hooks that Moose calls before acting and that default to `return true`: `CanGetTroops`, `CanGetUnits`, `CanGetCrates`, `CanUnloadAllTroops`, `CanBuildCrates` (`Moose:77542`, `Moose:78104`, `Moose:78230`, `Moose:79313`, `Moose:79580`).
Foothold overrides `CanGetTroops`, `CanGetUnits`, `CanGetCrates`, `_GetCrates` and (PvP) `CanBuildCrates`, `_CleanUpCrates`, `_BuildObjectFromCrates` (`CTLD.lua:6636`, `CTLD.lua:6654`, `CTLD.lua:6690`, `CTLD.lua:7346`, `CTLD.lua:2787-2896`).
A re-implementation needs an equivalent "veto before action / event after action" contract around each of load, unload, get crates, build, pack.

## 2. Cargo catalogue (troops, crates, direct-load units, static supply crates)

### Player view

The catalogue appears as sub-menus by sub-category because `usesubcats = true` (`CTLD.lua:157`); sub-categories used: `ANTI TANK`, `Support`, `SAM/AAA`, `SAM Addon`, `FARP`, `Zone supplies`, `Warehouse` (`CTLD.lua:280-366`).
Each item has a credit price and a minimum rank; both are Foothold additions (see §3).

### Troops (Moose `AddTroopsCargo`, `CTLD.lua:264-277`)

| Name | Template group | Type | Seats | Per-man kg | Stock | Availability | Default price / rank |
|---|---|---|---|---|---|---|---|
| Squad 8 | `CTLD_TROOPS_ATS` | TROOPS | 8 | 80 | 10 | always | 50 / 1 |
| Platoon 16 | `CTLD_TROOPS_Platon16` | TROOPS | 16 | 80 | 10 | always | 100 / 1 |
| Platoon 32 | `CTLD_TROOPS_Platon1` | TROOPS | 32 | 80 | 10 | always | 200 / 1 |
| Mortar Squad | `CTLD_TROOPS_MRS` | TROOPS | 6 | 80 | 10 | always | 100 / 1 |
| Engineer soldier | `CTLD_TROOPS_Engineers` | ENGINEERS | 1 | 80 | 10 | always | 50 / 1 |
| Zone Spy | `CTLD_TROOPS_SPY` | TROOPS | 1 | 80 | 10 | not in PvP | 100 / 2 |
| Demolition Team | `CTLD_TROOPS_DEMO` | TROOPS | 2 | 80 | 10 | not in PvP, only if `UseStatics` | 100 / 2 |
| Anti-Air Soldiers | `CTLD_TROOPS_AA` | TROOPS | 5 | 80 | 10 | not in Vietnam era | 100 / 1 |

Prices and ranks: `CTLD.lua:206-242`.

### Crate-built items (Moose `AddCratesCargo` / `AddCratesCargoNoMove`, `CTLD.lua:279-328`)

"NoMove" items stay where they are built; the others drive toward the nearest MOVE zone (Moose `movetroopsdistance`).

| Name | Template | Enum type | Crates | Crate kg | Stock | Sub-menu | Era | Moves | Price / rank |
|---|---|---|---|---|---|---|---|---|---|
| Mephisto | `CTLD_CARGO_Mephisto` | VEHICLE | 2 | 1500 | 10 | ANTI TANK | not Vietnam | yes | 250 / 2 |
| Humvee | `CTLD_CARGO_HMMWV` | VEHICLE | 2 | 1000 | 10 | ANTI TANK | not Vietnam | yes | 250 / 1 |
| Bradly | `CTLD_CARGO_Bradly` | VEHICLE | 2 | 1500 | 10 | ANTI TANK | not Vietnam | yes | 250 / 1 |
| L118 | `CTLD_CARGO_L118` | VEHICLE | 1 | 700 | 12 | Support | all | no | 150 / 1 |
| Ammo Truck | `CTLD_CARGO_AmmoTruck` | VEHICLE | 2 | 800 | 10 | Support | all | no | 100 / 1 |
| Humvee scout | `CTLD_CARGO_Scout` | VEHICLE | 2 | 1000 | 10 | Support | all | yes | 100 / 1 |
| HAWK System | `CTLD_CARGO_HAWKSite` | FOB | 4 | 1900 | 10 | SAM/AAA | all | no | 750 / 3 |
| Hawk TR / SR / LN Add-on | `CTLD_CARGO_HAWKSite_TR/_SR/_LN` | FOB | 1 | 1500 | 10 / 15 / 10 | SAM Addon | all | no | 250 / 3 |
| NASAMS System | `CTLD_CARGO_NasamsSite` | FOB | 4 | 1900 | 10 | SAM/AAA | Modern | no | 750 / 3 |
| NASAMS C2 / SR / LN Add-on | `CTLD_CARGO_NasamsSite_C2/_SR/_LN` | FOB | 1 | 1500 | 10 / 15 / 10 | SAM Addon | Modern | no | 250 / 3 |
| IRIS T System | `CTLD_CARGO_IRISTSLM_System` | FOB | 3 | 2800 | 10 | SAM/AAA | Modern | no | 1800 / 3 |
| IRIS T STR Add-on | `CTLD_CARGO_IRISTSLM_STR` | FOB | 1 | 2500 | 10 | SAM Addon | Modern | no | 750 / 3 |
| IRIS T LN Add-on | `CTLD_CARGO_IRISTSLM-LN` | FOB | 1 | 3500 | 15 | SAM Addon | Modern | no | 500 / 3 |
| IRIS T C2 Add-on | `CTLD_CARGO_IRISTSLM_C2` | FOB | 1 | 1900 | 10 | SAM Addon | Modern | no | 500 / 3 |
| Pantsir S1 | `Blue SAM SHORAD Pantsir` | FOB | 2 | 3000 | 10 | SAM/AAA | Modern + PvP + template present | no | 500 / 2 |
| C-RAM | `CTLD_CARGO_CRAM` | FOB | 2 | 1000 | 10 | SAM/AAA | Modern | no | 500 / 2 |
| HIMARS GMLRRS HE GUIDED | `CTLD_CARGO_GMLRS_HE` | VEHICLE | 2 | 3500 | 12 | Support | Modern | no | 1000 / 3 |
| Linebacker | `CTLD_CARGO_Linebacker` | VEHICLE | 2 | 1500 | 10 | SAM/AAA | not Vietnam | yes | 300 / 2 |
| Vulcan | `CTLD_CARGO_Vulcan` | VEHICLE | 2 | 1500 | 10 | SAM/AAA | not Vietnam | yes | 300 / 2 |
| FARP Huey | `CTLD_TROOP_FOB` | FOB | 3 | 700 | 10 | FARP | all, UH-1H only | – | 500 / 1 (alias of FARP, `CTLD.lua:182-184`) |
| FARP | `CTLD_TROOP_FOB` | FOB | 3 | 1200 | 10 | FARP | all | – | 500 / 1 |
| FARP with ZELL | `CTLD_TROOP_FOB_ZELL` | FOB | 3 | 750 | 10 | FARP | only if that template exists in the `.miz` | – | 750 / 1 |

Several of these pass a crate static shape (`"iso_container_small"`, `"cds_crate"`, `"ammo_cargo"`, `"iso_container"`) and a resource-map category `"Cargos"` to Moose (`CTLD.lua:284-327`).

### Direct-load whole vehicles for the C-130J (Moose `AddUnits`, `CTLD.lua:315-323`)

`Humvee`, `Humvee scout` (all eras), and `Mephisto`, `Vulcan`, `Avenger`, `FV-107 Scimitar`, `FV-101 Scorpion` (not Vietnam), each with stock 10.
Moose stores these in `C130GetUnits` and serves them through `CTLD:_C130GetUnits(Group, Unit, Name)` from the `Manage Units → Get Units` menu (`Moose:78107-78229`); the Foothold side only registers them and prices them (Avenger 250 / 2, Scimitar 250 / 2, Scorpion 250 / 2, `CTLD.lua:239-241`).
What Moose does in game: the aircraft must be inside a LOAD zone and the stock not exhausted; the veto hook `CanGetUnits` is called (Foothold's credit and rank check); at most `maxUnitsNearby` (default 3) such vehicles may already stand within `UnitDistance` (default 90 m) of the aircraft, otherwise `TOO_MANY_UNITS_NEARBY`; then each template of the entry is spawned as a **live ground group** behind the aircraft (heading + 180°, at half the airframe length + 5 m, 2.5 m further per template) with `SPAWN:NewWithAlias(template, "<template>-<random>"):InitRandomizeUnits(true, 10, 2):InitCoalition():SpawnFromVec2()` (→ `coalition.addGroup`), recorded in `DroppedTroops`, with a `UnitsSpawn` FSM event, the stock decremented and the message `DEPLOYED_NEAR_YOU` (`Moose:78123-78228`).
So there is no crate and no build: the vehicle exists at once on the ramp, and getting it into the hold is left to the C-130J module's own vehicle-loading system (the script does nothing more with it; the loading itself is DCS behaviour, not read in code — (estimation)).

### Static supply crates (Moose `AddStaticsCargoFromType`, `CTLD.lua:330-367`)

These are not built into anything: they are the "currency" of the zone-supply and warehouse-supply systems (§8, §9).
Each is restricted to given airframes (the `unitTypes` argument) and shows under one display name.

| Cargo name | Static type | kg | Sub-menu | Airframes |
|---|---|---|---|---|
| Zone supplies C-130J | `iso_container_small` | 4000 | Zone supplies | C-130J-30 |
| Zone supplies CH-47 | `cds_crate` | 3500 | Zone supplies | CH-47Fbl1 |
| Zone supplies UH-1H | `ammo_cargo` | 500 | Zone supplies | UH-1H |
| Zone supplies SA342L | `ammo_cargo` | 350 | Zone supplies | SA342L |
| Zone supplies MI-8 | `ammo_cargo` | 2300 | Zone supplies | Mi-8MT |
| Zone supplies Blackhawk | `ammo_cargo` | 2000 | Zone supplies | UH-60L, UH-60L_DAP |
| Zone supplies Mi-24P | `ammo_cargo` | 500 | Zone supplies | Mi-24P |
| 15 of everything CH-47 / MI-8 / Blackhawk | `cds_crate` / `cds_crate` / `ammo_cargo` | 3500 / 3500 / 2000 | Warehouse | CH-47 / Mi-8MT / UH-60L(+DAP) |
| 15 A/A Missiles, 15 A/G Missiles, 15 A/G Bombs | `ammo_cargo` | 1000 | Warehouse | CH-47, UH-1H, Mi-8MT, Mi-24P, UH-60L(+DAP) |
| 15 A/G Rockets, 15 (Plane fuel tanks) and pylons | `ammo_cargo` | 500 | Warehouse | same helicopters |
| 25 of everything | `iso_container_small` | 4000 | Warehouse | C-130J-30 |
| 25 A/A Missiles, A/G Missiles, A/G Rockets, A/G Bombs, Plane fuel-tanks and pylons | `cds_crate` | 1000 | Warehouse | C-130J-30 |
| 50 of everything | `iso_container` | 8000 | Warehouse | C-130J-30 |
| 50 A/A Missiles, A/G Missiles, A/G Rockets, A/G Bombs, Plane fuel-tanks and pylons | `iso_container_small` | 2000 | Warehouse | C-130J-30 |
| 15 / 25 / 50 Modded weapons | `ammo_cargo` 500 / `cds_crate` 1000 / `iso_container_small` 2000 | – | Warehouse | helicopters / C-130J / C-130J, only if `AllowMods` and `Era == "Modern"` |

### Mechanism

All registration calls are Moose (`AddTroopsCargo` `Moose:81932`, `AddUnits` `Moose:81956`, `AddCratesCargo` `Moose:81994`, `AddCratesCargoNoMove` `Moose:82024`, `AddStaticsCargoFromType` `Moose:82093`).
Templates are late-activated groups in the `.miz` whose names are given above; Moose checks them with `_CheckTemplates` (`Moose:81917`).
Availability is a Foothold layer: after registration, every catalogue entry whose policy says `available = false` gets `DontShowInMenu = true`, and unavailable `C130GetUnits` entries get an empty airframe list (`CTLD.lua:373-388`).
Era gating is plain `if Era ~= "Vietnam"` / `if Era == 'Modern'` around the registration calls (`CTLD.lua:275-323`).

### Reproduction notes

The template names are a `.miz` convention: a mission without `CTLD_CARGO_*` / `CTLD_TROOPS_*` late-activated groups cannot build anything.
`FARP with ZELL` and `Pantsir S1` are registered only when their template exists (`CTLD.lua:326`, `CTLD.lua:305`).

## 3. Prices, rank requirement and availability policy

### Mission-maker view

`CTLDPrices` (Config global) is a table `name → number` or `name → {price=, reqRank=, available=}`; it is merged over the built-in `CTLDPriceDefaults` (`CTLD.lua:206-255`).
`CTLD_DEFAULT_PRICE = 0` for anything not listed (`CTLD.lua:257`), so the static supply crates are free by default.
`FARP Huey` is priced as `FARP` (`CTLD.lua:182-184`).

### Mechanism

`Foothold_ctld:_readCargoPolicy(name)` returns `available, price, reqRank` (`CTLD.lua:186-193`); `priceOf` and `reqRankOf` are global helpers (`CTLD.lua:195-203`).
The checks themselves live in the `CanGetTroops` / `CanGetCrates` / `CanGetUnits` overrides (§6).

## 4. Pickup and drop zones that follow zone ownership

### Player view

Troops and crates can only be requested inside a friendly campaign zone, on a carrier/LHA, or at a player-built FARP.
Built ground vehicles and dropped troops walk toward the nearest non-friendly campaign zone within `movetroopsdistance` (5 km by default, `CTLD.lua:162`).

### Mechanism

At load, every campaign zone whose name does not contain `hidden`, `carrier` or `fob alpha` is registered twice in Moose CTLD, as a `LOAD` zone and as a `MOVE` zone, both inactive (`CTLD.lua:493-499`).
Ship zones (`CTLD.CargoZoneType.SHIP`, with ship length/width) are added for `Tarawa`, `Khasab Tarawa`, `HMS Invincible`, `CVN-72/73/74/59`, `FOB ALPHA` when the era is not Vietnam (`CTLD.lua:483-492`).
`addCTLDZonesForBlueControlled(zoneName)` sets, for one zone or for all: inactive zone → both off; BLUE zone → `LOAD` on, `MOVE` off; anything else (RED or neutral) → `LOAD` off, `MOVE` on (`CTLD.lua:501-538`).
It is run once 5 s after load by a Moose `SCHEDULER` (`CTLD.lua:540-542`) and again by the engine for the affected zone at three places of `ZoneCommander` where a zone changes side or active state (`zc2:50227-50231`, `zc2:55433-55437`, `zc2:56645-56649`).
`AddCTLDZone`, `ActivateZone`, `DeactivateZone`, `IsUnitInZone` are Moose (`Moose:82269`, `Moose:82195`, `Moose:82222`, `Moose:82511`).
`nobuildinloadzones = true` (non-PvP) prevents building inside a `LOAD` zone, i.e. inside a friendly zone (`CTLD.lua:153`).
A player-built FARP becomes a `LOAD` zone of radius 150 m with blue smoke (`CTLD.lua:5826`, `CTLD.lua:5853`).

### Reproduction notes

The MOVE-zone trick is what makes dropped troops and built vehicles "attack" the nearest enemy or neutral zone without any Foothold code: it is Moose's `_MoveGroupToZone` (`Moose:80298`).
A re-implementation needs its own "nearest non-friendly zone within N metres → route there" on troop drop and on vehicle build.

## 5. Load / unload / build flow and the payment veto

### Player view

Requesting troops or crates costs credits when `CTLDCost` is true and requires the minimum rank of the item.
A refused purchase produces the engine's own "not enough credits / rank" message (from `bc:debit`, shop theme) and nothing is spawned.
Random voice clips play on troop load (`troops_load_to_action.ogg`, `troops_load_ready.ogg`, `troops_load_ao.ogg`) and unload (`troops_unload_everybody_off.ogg`, `…get_off.ogg`, `…here_we_go.ogg`, `…moving_out.ogg`, `…thanks.ogg`) (`CTLD.lua:8400-8422`).

### Mechanism

`CanGetTroops`: returns false if the item is unavailable; otherwise, if `CTLDCost == true`, calls `bc:debit(coalition, price × quantity, groupId, dcsGroup, reason, reqRank)` and returns its result (`CTLD.lua:6654-6675`).
`CanGetUnits` (C-130J whole vehicles): same logic (`CTLD.lua:6636-6652`).
`CanGetCrates`: skipped for drop and pack operations (`CTLD.lua:6691`); for "Zone supplies" it debits the pickup zone's supply stock (§8); for "Warehouse" bundles it checks and debits the airbase warehouse (§9); the credit charge for warehouse bundles is `price × sets` with rank check (`CTLD.lua:6885-6901`).
Ordinary build crates are not charged in `CanGetCrates` (the function returns true as soon as the cargo is neither zone-supply nor a known warehouse bundle, `CTLD.lua:6785-6788`).
The price of ordinary build crates is charged inside the bundled Moose itself: `CTLD:_GetCrates` reads `CTLDCost`, `self:GetCargoPrice()` or the global `priceOf(name)`, and calls `bc:debit(coal, charge, gid, dcs, reason, reqRank)` (`Moose:78256-78283`); the Moose menu labels also append the price (`CTLD:_GetCargoPriceLabel`, `Moose:76351-76370`).
So the bundled Moose depends on Foothold globals (`bc`, `CTLDCost`, `priceOf`).
`Foothold_ctld._GetCrates` is additionally wrapped to refuse `Tor M2` and non-PvP `Pantsir S1` and to carry the warehouse request through the Moose call (`CTLD.lua:7306-7350`, `CTLD.lua:7398-7401`).
Unused troops returned into a friendly zone are refunded: `refundOrReturnRejectedTroops` accumulates `priceOf(cargo)` per deployer group and flushes one `bc:credit(side, amount, gid, dcs, "Troops returned")` 2 s later (`CTLD.lua:8472-8532`).

### Reproduction notes

The debit happens before the spawn and has no rollback path if the Moose spawn then fails.
Refunds are batched over 2 s so that unloading a 32-man platoon made of several groups yields one credit line.

## 6. Stock, limits and "oldest is removed" rule

### Player view

Every catalogue item has a finite stock (10 to 15, see §2).
When the stock of an item falls under 5, loading or building one more deletes the oldest surviving group of that type and tells the player: `CTLD_LIMIT_REACHED_REMOVED_OLDEST` (crates) or `CTLD_TROOP_LIMIT_REACHED_REMOVED_OLDEST` (troops) (`CTLD.lua:6087-6117`, `CTLD.lua:8430-8469`).

### Mechanism

Foothold keeps two lists, `GroundUnits` (built from crates) and `TroopUnits` (dropped troops), each entry `{groupName, Timestamp, Group, CargoName, Stock, PlayerName}` (`CTLD.lua:548-549`, `CTLD.lua:6282-6289`, `CTLD.lua:8630-8640`).
`OnAfterCratesBuildStarted`: if the cargo's stock is below 5, the oldest `GroundUnits` entry of that cargo is destroyed, removed, and one stock unit is given back (`CTLD.lua:6102-6113`).
`OnAfterTroopsPickedUp`: same on troop load, restricted to entries whose recorded stock was below 5 (`CTLD.lua:8437-8459`); `OnAfterTroopsDeployed` repeats the check at drop time (`CTLD.lua:8680-8713`).
Every 60 s `RefillMissingWithCountTable` calls Moose `_CountStockPlusInHeloPlusAliveGroups` (`Moose:82855`) and, for each cargo, if stock + loaded + alive is lower than the initial stock (`Stock0`), adds the difference back; if it is higher, lowers the stock but never below 5 (`CTLD.lua:9331-9386`, timer `CTLD.lua:9415`).
The refill is skipped while a build is running (`buildRunning` counter incremented in `OnAfterCratesBuildStarted`, decremented in `OnAfterCratesBuild`, `CTLD.lua:9332`, `CTLD.lua:6089`, `CTLD.lua:6122`).
Building a FARP removes one stock unit of `CTLD_TROOP_FOB` (`CTLD.lua:5856`).

### Mission-maker view

`MAX_AT_SPAWN` (global, overridable) caps how many groups of each cargo are restored from the save file, oldest deleted first: e.g. Mephisto 2, L118 3, HAWK System 3, Hawk LN Add-on 8, IRIS T System 2, C-RAM 4, HIMARS 4, FARP 3, all infantry 0 except Anti-Air Soldiers 2 and Mortar Squad 2 (`CTLD.lua:408-447`).
`MAX_SAVED_FARPS` (default 3) caps restored FARPs (`CTLD.lua:450`).

### Reproduction notes

The effective world cap per item is "initial stock", enforced by conservation (stock + carried + alive = Stock0) rather than by a counter of built units.
Dead units give their stock back within 60 s, so losses are free.

## 7. Troop deployment → zone capture, reinforcement or return

### Player view

Troops dropped in or near a zone run to it (Moose MOVE zone), and the whole coalition sees `CTLD_TROOP_GROUP_ENTERED_ZONE` when they enter (`CTLD.lua:8862-8864`).
In a **neutral** zone they start a pending capture (capture rules: theme 01); in a **friendly** zone that can receive supply they are consumed as one supply delivery; in a friendly zone that needs nothing, or in the zone they were picked up from, they are removed and refunded; in an **enemy** zone they stay and fight.
On completion the coalition sees one line per zone `CTLD_TROOP_ZONE_EVENT_LINE` (player, action, zone) with action `captured`, `upgraded`, `stocked` or `captured and upgraded`, plus `CTLD_TROOP_ZONE_EVENT_TOTAL` with the credits earned (`CTLD.lua:9027-9113`).
Reward: half of `bc.rewards['Zone capture']` (default 200) or half of `bc.rewards['Zone supply delivery']` (default 150), stat names `Zone capture (troops)` / `Zone supply delivery (troops)` (`CTLD.lua:8945-8949`, `CTLD.lua:9300-9303`).
Engineers cannot capture unless `CaptureZoneWithEngineer` is true; Zone Spy and Demolition Team never capture (`CTLD.lua:1283-1287`, `CTLD.lua:1779-1782`).

### Mechanism

`OnAfterTroopsPickedUp` records the pickup zone on the Moose group (`updateLastPickupZone` → `bc:getZoneOfPoint`, falling back to the `supplyZones` list, `CTLD.lua:3761-3807`, `CTLD.lua:8433`).
`OnAfterTroopsDeployed` (Moose FSM event) does, for each dropped group (`CTLD.lua:8535-8827`):
- registers it in `deployedTroops`, in the Moose `SET_GROUP` `deployedTroopsSet`, and in `TroopUnits`;
- finds the catalogue entry by searching the template name inside the spawned group name (`CTLD.lua:8590-8603`);
- registers the group for kill rewards (§15);
- lists the campaign zones the group is already partly inside (`GROUP:IsPartlyOrCompletelyInZone`, `CTLD.lua:8714-8722`);
- stores `zoneCaptureInfo[groupName] = {troopGroup, zoneName, deployer, cargoName, cargoType, canCaptureZone, pickupZoneName, careerPlayerName…}`;
- friendly zone and (no pickup zone known, or same zone as pickup, or zone does not need supply per `zone:canRecieveSupply()`) → refund and destroy immediately (`CTLD.lua:8791-8802`);
- otherwise calls `CaptureZoneIfNeutral()`.
Groups dropped outside any zone are watched by `zoneSet`, a Moose `SET_ZONE` of all campaign zones (`CTLD.lua:8286-8290`) whose `Trigger(deployedTroopsSet)` FSM polls every `Checktime` seconds (Moose default 5 s, `Moose:10426`, `Moose:10626`) and fires `EnteredZone`; Foothold overrides `_TriggerCheck` to read each group's position once per pass and to skip groups flagged `_footholdZoneEntryComplete` (`CTLD.lua:8293-8351`), and stops the trigger FSM when no deployed troop is alive (`CTLD.lua:8385-8398`).
`zoneSet:OnAfterEnteredZone` updates `zoneCaptureInfo`, and for capture-capable troops in a friendly or neutral zone schedules `CaptureZoneIfNeutral()` 10 s later (`CTLD.lua:8829-8924`).
`CaptureZoneIfNeutral` queues zones and runs `processQueuedCaptures`, a serialized worker that handles one troop group at a time with 0.1–5 s between groups (`CTLD.lua:8971-9327`):
- neutral active zone → `zone:startPendingCapture(side, {kind="group", name, template, position, heading, destroyOnFinish=true, tombstone=true, stopGroup=true, delivery={handler="blue_ctld_troop_capture", payload}})` (`CTLD.lua:9263-9293`); the handler `completePendingBlueCtldTroop` pays the reward when the engine finishes the capture (`CTLD.lua:8926-8963`);
- friendly zone → `bc:_applyRegularSupplyDelivery(zone, side, now, true)`, destroy the group, pay half reward (`CTLD.lua:9294-9309`);
- non-capturing troops in a friendly zone → stock returned, group destroyed, message `CTLD_TROOPS_RETURNED_TO_BASE` (`CTLD.lua:9220-9234`).
When the rewarded player is on the ground inside a friendly zone, a synthetic `S_EVENT_LAND` is injected with `world.onEvent` 5 s later so the engine's landing-reward code banks the credits immediately (`CTLD.lua:9061-9099`).

### Reproduction notes

The hook into the capture system is a single engine call, `zone:startPendingCapture(side, request)`, plus a named completion handler registered with `bc:registerPendingCaptureHandler` (`CTLD.lua:8963`).
The "same zone as pickup" rule needs the pickup zone to be remembered per carried troop group: the bundled Moose stores `_footholdPickupZone` on the loaded cargo at load time (asking Foothold through `self:GetTroopPickupZone`, `Moose:77614-77616`, `CTLD.lua:8426-8428`) and copies it onto the dropped group (`Moose:79394`, `Moose:81776`).
The synthetic landing event is a coupling with the reward system (credits are "carried" until landing).

## 8. Zone supplies (player supply crates)

### Player view

Menu: F10 → `Logistics` → `Zone supplies` → the crate for the player's airframe, with a quantity sub-menu (`zc2:101588-101695`).
The crate is spawned next to the aircraft in a friendly zone (or FARP), loaded by the DCS ground crew / sling / C-130J cargo system, flown to another zone and unloaded or air-dropped there.
Messages: `CTLD_CRATE_LOADED_GROUND_CREW`, `CTLD_CRATE_UNLOADED_GROUND_CREW` (`CTLD.lua:4620`, `CTLD.lua:4787`), then `CTLD_ZONE_SUPPLIES_DELIVERED` with an action text: `captured`, `capturing`, `queued`, `stocked (ready/max)` (`CTLD.lua:4502-4508`, `CTLD.lua:5353-5357`).
Delivered into a neutral zone it starts a capture; into a friendly zone it adds one expedited supply unit to the zone's stock and 10 of every weapon to its warehouse; into a player FARP it adds 1 to the FARP's supply counter; into an enemy zone it is destroyed with reason `enemy zone` (`CTLD.lua:5196-5222`, `CTLD.lua:5315-5371`).
Reward 150 credits and stat `Zone supply delivery` (`CTLD.lua:5371`, `CTLD.lua:5216-5217`); a completed capture pays `bc.rewards['Zone capture']` (default 200) and stat `Zone capture` (`CTLD.lua:4555-4558`, `CTLD.lua:1362`).
Put back down in the zone it came from, the crate is removed and the stock refunded: `CTLD_SUPPLIES_RETURNED_TO_ZONE` (`CTLD.lua:5063-5075`).
Taking off from a supply zone without supplies triggers `LOGISTICS_WARNING_NOT_LOADED` and `micclick.ogg` for selected airframes (`zc2:101336-101410`).

### Mission-maker view

`PlayerZoneSuppliesConsumeStock` (Config): when true, taking a supply crate consumes one unit of the source zone's "regular supply" stock and fails with `CTLD_WAREHOUSE_NOT_AVAILABLE` / `CTLD_REASON_INSUFFICIENT_STOCK` when the zone has none (`CTLD.lua:6768-6782`).
`CTLDSupplyCapacity`: initial supply counter of a newly built FARP (`CTLD.lua:5718`).
`CTLDCargoTrackingInterval`: tracking period for ordinary crates, clamped to 3–6 s (`CTLD.lua:9437`).
`WarningNoSupplies` and `ZoneSupplyTakeoffWarningTypes`: take-off warning switch and airframe list (`zc2:97620-97644`).

### Mechanism

Pickup: `CanGetCrates` resolves the pickup zone, then either consumes FARP stock (`consumeBuiltFarpSupplyStock`) or zone stock (`zone:_consumePlayerRegularSupplyStock(sets, BLUE, now)`), and queues a "pickup debit" record keyed by unit name (`CTLD.lua:6733-6782`, `CTLD.lua:3175-3207`).
`OnAfterGetCrates` (Moose event after the crate statics are spawned) registers each crate in `zoneSupplyCrates[cargoId]` with pickup zone, group, player, carrier unit, airframe dimensions, and claims the pending debit so the crate remembers which zone stock it consumed (`CTLD.lua:7094-7177`, `CTLD.lua:3344-3417`, `CTLD.lua:3280-3335`).
`OnAfterCratesPickedUp` re-binds the tracking entry to whoever actually loaded it (`CTLD.lua:7270-7303`).
Tracking loop `tickZoneSupply`: every 3 s for C-130J crates and every `CTLDCargoTrackingInterval` for the others, one `timer.scheduleFunction` driving both cadences (`CTLD.lua:9418-9438`, `CTLD.lua:4191-4202`).
For each tracked crate `processZoneSupplyDeliveries` reads the static's position (`STATIC:GetVec3`), decides "moved" when it shifted more than 0.5 m since the last pass (`CTLD.lua:2968-2982`), and derives states `wasAirborne`, `attached`, `detached`, `_wasUnloaded` by comparing the crate position with the carrier unit position against a per-airframe box `{width, height, length, ropelength}` (`CTLD.lua:1372-1382`, `CTLD.lua:4703-4793`).
A crate is "on ground" when its AGL ≤ 0.5 m or it was unloaded and stopped moving (`CTLD.lua:4803`); C-130J para-drops are confirmed by a one-shot check 1 s later that the crate is below 10 m AGL and has not moved more than 0.5 m (`CTLD.lua:4143-4189`, `CTLD.lua:1368-1370`).
A grounded crate is matched to a zone with `bc:getZoneOfPoint(vec3)`, else against the `supplyZones` names through Moose `ZONE:IsVec3InZone` (`CTLD.lua:4817-4833`); outside any zone it is re-checked every 60 s and deleted after 600 s (`CTLD.lua:4971-4993`, `CTLD.lua:1364-1366`).
Ready crates are applied one at a time, 3 s apart, by `zoneSupplyProcessReadyQueue` → `zoneSupplyApplyOne` (`CTLD.lua:5375-5476`).
Neutral zone: `zone:startPendingCapture(BLUE, {kind="static", name, position, staticType, country, destroyOnFinish=true, tombstone=true, delivery={handler="blue_ctld_capture_delivery", …}})` (`CTLD.lua:5316-5363`); the handler `completePendingBlueCtldSupply` grants the warehouse bundle and pays (`CTLD.lua:4528-4561`).
Friendly zone: `zone:_addExpeditedRegularSupplyStock(1, now)`, `grantZoneBundle` (= `adjustWarehouseStockAtZone(zone, +10, all categories)`), reward (`CTLD.lua:5366-5371`, `CTLD.lua:3925-3929`).
The DCS raw API underneath: `StaticObject.getByName():destroy()` for removal (`CTLD.lua:4126-4135`), `Unit:getPoint/inAir/getVelocity`, `land.getHeight`.

### Reproduction notes

There is no DCS event for "cargo static put down in zone X" that works for sling, ground crew and C-130J alike, hence the polling state machine over every live crate; the number of polled objects equals the number of supply crates in the world.
The per-airframe box test replaces a missing "is this static inside that aircraft" API.
Deliveries are deliberately serialized (one every 3 s) and removals are queued (`zoneSupplyPendingRemoval`) to avoid bursts.
The `ZoneSupplyOnboardByGroup` cache (group id → has supplies aboard) exists only so the take-off warning does not scan all crates (`CTLD.lua:3109-3139`).

## 9. Warehouse cargo: moving weapon stock between airbases with CTLD

### Player view

Menu: F10 → `Logistics` → `Warehouse` → `15 / 25 / 50 of everything`, `… A/A Missiles`, `… A/G Missiles`, `… A/G Rockets`, `… A/G Bombs`, `… fuel tanks and pylons`, `… Modded weapons` (§2).
Taking a bundle removes that many of **every** weapon of the listed categories from the airbase the player stands on; delivering it to another friendly airbase/FARP adds them there.
Refusals: `CTLD_WAREHOUSE_NOT_AVAILABLE` (label, place, reasons `CTLD_REASON_NO_ITEMS` / `CTLD_REASON_INSUFFICIENT_STOCK` per category / `CTLD_REASON_NO_STORAGE`), `CTLD_WAREHOUSE_REMOVE_FAILED`, `CTLD_WAREHOUSE_MISCONFIGURED_INVALID_AMOUNT` (`CTLD.lua:6791-6925`).
Delivery: coalition message `CTLD_SUPPLIES_DELIVERED_BY` (label, zone, player), reward from the bundle definition (150 for "15/50 of everything", 75 for "25 of everything", 15–50 for single-category bundles), stat `Warehouse delivery` (`CTLD.lua:1309-1335`, `CTLD.lua:5294-5306`).
Dropped in an enemy zone the crate is destroyed (`enemy zone`); in a neutral zone it waits 60 s for the zone to turn friendly and is then destroyed (`neutral zone timeout`) (`CTLD.lua:5226-5246`).

### Mechanism

Only active when `WarehouseLogistics == true` (`CTLD.lua:6785`, `CTLD.lua:6301`).
`WAREHOUSE_SUPPLY_TYPES[name] = {categories, amount, reward, label}` (`CTLD.lua:1309-1347`); rockets count triple (`WAREHOUSE_CATEGORY_MULTIPLIER.AG_ROCKETS = 3`, `CTLD.lua:1398-1400`).
Pickup (`CanGetCrates`): find the airbase storage of the pickup zone (`getZoneStorageHandle`: `STORAGE:FindByName(zone.airbaseName or zone.baseName or zoneName)`, cached, `CTLD.lua:3858-3881`), check that the summed quantity of each category is at least `amount × sets`, charge credits, then `adjustWarehouseStockAtZone(zone, -amount×sets, categories)` (`CTLD.lua:6822-6907`).
`adjustWarehouseStockAtZone` walks `WEAPONSLIST.GetItems(category)` and for each item does `storage:SetItem(name, current + delta)`; on debit, items whose stock is lower than the need are skipped; on credit, era-restricted items are skipped in Coldwar, smart weapons listed in `WarehouseWeaponCaps` receive half when `StrictSmartWeaponsInventory` is true, and `ForbiddWeaponsInAllEra` items are always forced to 0 (`CTLD.lua:6300-6388`, `CTLD.lua:3904-3923`).
Delivery (`zoneSupplyApplyOne`): same tracking as zone supplies with `deliveryType = "warehouse"`, ending in `adjustWarehouseStockAtZone(zone, +amount, categories)` (`CTLD.lua:5225-5311`).
Two stricter variants exist: PvP, and the "managed" mode when a `WarehouseWeaponLocationPolicy` is active; in both the exact per-item quantities debited are stored on the crate (`cargo._warehouseDebitItems`) and re-applied item by item at destination by `ApplyWarehouseDebitItems` (`storage:AddItem`), with settlement states `applied` / `discarded` and a refund path when the crate is removed at its source (`CTLD.lua:6395-6425`, `CTLD.lua:6427-6505`, `CTLD.lua:6964-7006`).
Moose `STORAGE` wraps the DCS `Warehouse` object: see §17.

### Managed mode in detail (PvE with a weapon location policy)

- Entry: `Foothold_ctld._GetCrates` (the wrapper around the Moose function) builds a `warehouseRequest = {cargoName, _warehouseMeta}` when `WarehouseLogistics` is on, a policy is active and the cargo's sub-category is `Warehouse`, and passes it through the Moose call as an extra argument; the bundled Moose `CTLD:_GetCrates` calls back `_prepareManagedWarehousePickup` before spawning (`Moose:78338`), `_completeManagedWarehousePickup` after (`Moose:78609`) and `_bindManagedWarehouseDrop` when a dropped crate is replaced (`Moose:78578`) — three more Foothold-only hooks inside the bundled Moose (`CTLD.lua:7355-7360`, `CTLD.lua:7401-7402`).
- Prepare (`_prepareManagedWarehousePickup`): the source storage must exist and belong to the player's side; for each category of the bundle every catalogue item is resolved to a policy identity (`WarehouseWeaponLocationPolicy.GetItemIdentity`) and gets a row `{key, item, stock, optional, take}` (`CTLD.lua:6427-6453`).
- An item whose policy rule does not allow this airbase is "optional": whatever is in stock is taken, up to the limit; any other item is taken only if the stock covers the full limit (`amount × sets`, × 3 for rockets), otherwise none of it; the category is refused with `CTLD_REASON_INSUFFICIENT_STOCK` when the total stock of its expected items is below the requirement (`CTLD.lua:6455-6473`).
- The credit charge (`price × sets`, rank check) is debited at this stage through `bc:debit` and remembered in `request.paid` (`CTLD.lua:6489-6503`).
- Complete (`_completeManagedWarehousePickup`): if Moose spawned fewer crates than requested, the unspawned sets are refunded (`bc:credit(…, "warehouse crate spawn")`); each crate is flagged `_warehouseManaged` and stamped with its source zone, airbase, native airbase id, side, share of the price and buyer name; each row's `take` is split evenly between the crates (remainder to the first ones) into `cargo._warehouseDebitItems[key] = {item, amount}`, and only then is the storage debited with `storage:SetItem(key, stock - take)` (unlimited stocks are left alone) (`CTLD.lua:6518-6554`).
- So a managed crate is an exact manifest: what leaves one warehouse is what arrives in the other, item by item (`ApplyWarehouseDebitItems` adds `amount.amount` of `amount.item`, skipping forbidden items, era-restricted ones on delivery and destinations that hold the item in unlimited quantity) (`CTLD.lua:6395-6423`).
- Crate identity across DCS cargo operations: `_indexManagedWarehouseCargo` keeps `_managedWarehouseCargoByStatic[staticName] = cargo`; the dynamic-cargo events of the bundled Moose call `_updateManagedWarehouseDynamicCargo(event, "loaded" | "unloaded" | "removed")`, which re-points the tracking entry to the DCS dynamic-cargo object, marks the crate attached/detached, or discards the manifest when DCS removed the cargo (`CTLD.lua:6507-6516`, `CTLD.lua:6603-6634`, `Moose:77313`, `Moose:77346`).
- When Moose replaces a crate object on drop, `_bindManagedWarehouseDrop(original, replacement)` moves the whole manifest and settlement state to the replacement and re-registers it in the supply tracking loop as already unloaded (`CTLD.lua:6556-6595`).

### PvP mode in detail

- In PvP every crate request (not only warehouse bundles) opens a `_warehousePickupRequest` context holding the pickup unit, the LOAD zone it stands in and, when that zone is a player-built FARP, its record and native airbase; a FARP of the other side refuses the request (`CTLD.lua:7370-7388`).
- For warehouse bundles the request also carries the bundle definition and a quote phase (`awaiting` when `CTLDCost`, else `free`): the price is quoted and charged inside the hooks, and the stock actually admitted is attached to the spawned crates afterwards through `claimZoneSupplyPickupDebit` (source zone, side, native id, item manifest, price paid, buyer) (`CTLD.lua:7390-7400`, `CTLD.lua:7495-7511`).
- On a drop, when Moose spawns a replacement crate for one that carried a manifest or a consumed zone-supply unit, every `_warehouse*` / `_zoneSupply*` field is moved from the old cargo object to the new one and the tracking entry is re-keyed, marked airborne-then-unloaded (`CTLD.lua:7408-7475`).
- The same wrapper keeps the C-130J auto-build set consistent when one of its crates is replaced on drop (`CTLD.lua:7477-7494`).
- The wrapper also blocks `Tor M2` always and `Pantsir S1` outside PvP Modern, and any cargo whose policy says unavailable (`CTLD.lua:7347-7354`).

### Reproduction notes

In the default (non-managed) mode a bundle is not conserved: the debit skips items in short supply while the credit adds the full amount of every item, so a delivery can create stock.
The managed/PvP mode exists to close that gap and costs a per-crate manifest.

## 10. Special troop teams: Zone Spy and Demolition Team

Both are Foothold-only behaviours layered on Moose troop cargo; neither exists in PvP, and the Demolition Team requires `UseStatics` (`CTLD.lua:269-274`).

### Zone Spy — player view and mechanism

A single soldier dropped within `movetroopsdistance` of an enemy zone walks to the nearest RED zone (36 km/h route speed, controller speed forced to 10 m/s with `Controller:setSpeed`), `Diamond` formation (`CTLD.lua:1531-1537`, `CTLD.lua:1887-1945`).
On entering it, `startZoneIntel(zoneName, 3600, BLUE)` reveals the zone for one hour (intel system: other theme) and the coalition gets `CTLD_SPY_INTEL_ACTIVE` (`CTLD.lua:1947-1964`).
The spy then walks back to his drop point; on arrival: coalition message `CTLD_SPY_READY_EXTRACTION` with nearest zone name and MGRS, and blue smoke 30 m away (`CTLD.lua:1813-1868`).
If no enemy zone is in range: `CTLD_DEMO_NO_ENEMY_ZONE` with the range (`CTLD.lua:1924-1932`).
Routing uses Moose `GROUP:RouteGroundTo`, `COORDINATE:WaypointGround` and `GROUP:TaskFunction` (a waypoint task that calls a global Lua function by name, i.e. DCS `WrappedAction` with a `Script` command) (`CTLD.lua:1815-1831`).

### Demolition Team (the `Demolition` class, `CTLD.lua:1557-2589`)

What it is: a two-man AI sapper team that walks into an enemy zone, plants timed charges on the zone's **static structures** (`zoneObject.built` names resolved with `StaticObject.getByName`, `CTLD.lua:1972-1982`) and walks out before they explode.
Constants: route speed 36 km/h, waypoint standoff 35 m from the target, plant reach 150 m, fuse 120 s, planning speed 3.5 m/s, escape margin 25 m, confirmation distance +200 m, 16 escape rays, reward 50 credits per destroyed structure (`CTLD.lua:1558-1571`).
Target zone: nearest RED zone within `movetroopsdistance` that still has living structures; otherwise `CTLD_DEMO_NO_STRUCTURE_TARGETS` or `CTLD_DEMO_NO_ENEMY_ZONE` (`CTLD.lua:1984-2012`, `CTLD.lua:2420-2430`).
Targets are ordered by greedy nearest-neighbour (`OrderNearest`, `CTLD.lua:1747-1766`) and the team is routed to a point 35 m short of the first one with a waypoint task `Foothold_ctld.DemolitionPlantWaypoint` (`CTLD.lua:2085-2118`).
At the waypoint a "batch" is created: the primary target plus every other assigned structure within 150 m of any living team member gets a charge whose power is `max(100, ceil(life × 0.45 / 50) × 50)` (`CTLD.lua:1573-1576`, `CTLD.lua:2301-2366`); coalition message `CTLD_DEMO_PLANTING` (`CTLD.lua:2399-2403`).
Escape planning: each charge is a hazard circle whose radius is interpolated from power (100 → 200 m, 450 → 300 m, 750 → 350 m, 1800 → 450 m), plus one aggregate circle at the power-weighted centroid; 17 candidate directions (away from centroid + 16 rays, or straight to the next target if that clears all circles) are scored by exit distance, and infeasible ones (cannot be walked in 120 s at 3.5 m/s) are penalised (`CTLD.lua:1584-1730`).
Detonation: `timer.scheduleFunction(FuseBatch, batch, plantedAt + 120)`; the batch only explodes when the fuse has elapsed **and** every living team member is outside all hazard circles (re-checked at the escape waypoint and every 60 s by `RefreshPendingBatch`), using `trigger.action.explosion(point, power)`; one second later `ConfirmCharge` checks the static is dead and pays the owner if he is still alive in his aircraft (`CTLD.lua:2236-2286`, `CTLD.lua:2220-2234`, `CTLD.lua:2159-2172`).
Rewards: `bc:addContribution(owner, BLUE, 50)`, temp stat `Demolition kill`, career stat `DemolitionKills` (`CTLD.lua:2226-2230`).
Several teams in the same zone share targets: `RebalanceZone` gives each team a balanced quota, keeps the target a team is already walking to, and puts late arrivals in `reserve` until they are inside the zone (`CTLD.lua:2463-2556`).
Zone changes: zone turned neutral → team stops and holds, charges cancelled; zone turned BLUE → team destroyed and its stock refunded (`CTLD_TROOPS_RETURNED_TO_BASE`); zone back to RED → team walks home (`CTLD.lua:2558-2588`).
Team death is detected by the 60 s refill timer and announced with `CTLD_DEMO_KILLED` (`CTLD.lua:9388-9412`).
When finished, the team walks back to its drop point and announces `CTLD_DEMO_READY_EXTRACTION` with smoke, like the spy (`CTLD.lua:2135-2148`).
State lives on the `TroopUnits` entry as `entry.Demo = {deployer, ownerPlayerName, ownerGroupName, dropPoint, targetZoneName, status, routeGeneration, assignedTargets, currentTarget, planted, activeBatch…}` (`CTLD.lua:8654-8669`); a `routeGeneration` counter invalidates stale waypoint callbacks (`CTLD.lua:2373`).

### Reproduction notes

The whole thing is event-driven by waypoint tasks, so it costs nothing while the team walks; the only polling is the 60 s death/fuse refresh.
Hard parts: waypoint-task callbacks arriving after a re-route (hence the generation counter), and guaranteeing the team is clear before `trigger.action.explosion` (the explosion kills friendly infantry).
It depends on the zone object exposing its structure names (`zone.built`) — an engine concept from another theme.

## 11. SAM systems built in parts ("Add-on" crates and the merge)

### Player view

A `HAWK System`, `NASAMS System` or `IRIS T System` is a complete baseline site.
`… Add-on` crates (one crate each) built within 400 m of an existing system of the same family are absorbed into it: the site is respawned as one group with the extra launcher/radar/command post (`CTLD.lua:577`, `CTLD.lua:1180-1281`).
Messages: `CTLD_SAM_MERGE_COMPLETE` (family, role) or `CTLD_SAM_MERGE_FAILED_MISSING_TEMPLATE` / `_NO_COMPONENT` / `_APPEND` / `_SPAWN` (`CTLD.lua:1223-1279`).
Reward for an upgrade: 150 (HAWK, NASAMS) or 200 (IRIS-T), stats `Upgraded HAWK` etc. (`CTLD.lua:5947-5951`).

### Mechanism

`SAM_MERGE_PROFILES` describes each family: system template name, cargo names, role order, cargo-name → role, template → role, role → DCS unit type, and baseline unit counts (HAWK: TR 1, SR 1, LN 2, PCP 1, CWAR 1; NASAMS: C2 1, SR 1, LN 2; IRIS: STR 1, LN 1, C2 1) (`CTLD.lua:749-813`).
In `OnAfterCratesBuild`, if the built vehicle resolves to a profile and role, `samMergeTryMergeComponentIntoNearbySystem` is called (`CTLD.lua:6227-6246`).
It finds the nearest live system group of the profile (first in `GroundUnits`, else a one-shot Moose `SET_GROUP:FilterCoalitions("blue"):FilterZones({ZONE_RADIUS}):FilterOnce()` scan, `CTLD.lua:1128-1178`), takes the system's current template, appends the component's unit, reorders units by role, lays them out on rings of 6 slots (radius 120 m + 35 m per ring) around the anchor unit, spreads launcher headings evenly over 360°, clears wrecks with `world.removeJunk` in a 400 m sphere, spawns the merged template under a new name `<system_template>-<random>`, then destroys the old system and the component (`CTLD.lua:587-669`, `CTLD.lua:1234-1254`).
The tracking lists (`GroundUnits`, Moose `DroppedTroops`, kill-reward registry) are re-pointed to the new group (`CTLD.lua:1256-1273`).
Augmented sites survive restarts **without any save file of their own**: the Moose CTLD CSV already stores, for each saved group, a `Structure` column listing `unitType==count;…` (`UTILS.GetCountPerTypeName(group)`, `Moose:83881`, `Moose:83910-83912`), and Foothold re-reads that same file 5 s after the CTLD load (`CTLD.lua:8276-8283`):
- `LoadIRISAugments()` reads `Foothold_ctld.filename` again with `UTILS.LoadFromFile`, keeps the rows that are a SAM system of a known profile (system template name in the group name or in the cargo-templates column, or a system cargo name), converts the `Structure` column into a count per role, and keeps the rows where a role exceeds the profile's baseline: `{profile_key, x, y, extras = {[role] = count above baseline}}` (`CTLD.lua:7847-7924`);
- `ApplyIRISAugments(rows)`: Moose has just restored each site from its **baseline** template; for each row the nearest restored system of the same profile within `IRIS_MERGE_DISTANCE` (400 m) that is not already matched is taken, its template is extended with copies of the unit of each role until the saved counts are reached, the layout is re-flowed, and the site is respawned under a new name `<system_template>-<random>`, with the same re-pointing of `GroundUnits`, Moose `DroppedTroops` and the kill-reward registry as a live merge (`CTLD.lua:7926-8060`);
- `RunIrisOnePassStandaloneMerge()` then walks `GroundUnits` once and tries to merge every surviving stand-alone add-on component into a nearby system (`CTLD.lua:8062-8096`).
The three steps are skipped when a PvP round reset is pending (`CTLD.lua:8277`).
Packing an augmented site: `OnBeforeCratesPacked` counts the units of each role in the group being packed and, for each unit above the baseline, creates the matching add-on crate set next to the player (`_GetCrates(Group, Unit, addonCargo, extra × cratesPerSet, false, true, true, true)`, message `CTLD_CRATES_POSITIONED`), so that nothing is lost when a 3-launcher HAWK is packed back into crates; for a C-130J the new crates are registered like requested ones (`CTLD.lua:7520-7594`, `CTLD.lua:7596-7602`).
When the build comes from a C-130J auto-build helper, the merge radius is Moose's `EngineerSearch` instead of 400 m (`CTLD.lua:6229-6238`).

### Reproduction notes

DCS cannot add a unit to a live group: the merge is "respawn the whole site", which resets damage unless handled (`IRIS_RESTORE_UNIT_HEALTH_ON_MERGE`, default false, `CTLD.lua:581`) and changes the group name, so anything that references the old name (air-defence network, persistence, rewards) must be updated.

## 12. Minimum distance between built SAMs (PvP only)

In PvP, `CanBuildCrates` is overridden: crates named `Pantsir S1`, `Tor M2` or `SA-8` are removed from the build list when a live group built from the same cargo by the same coalition stands within 8 NM (`8 * 1852` m) of the crate, or when another build of the same cargo is pending within 8 NM (`CTLD.lua:2778-2866`).
The player (or the C-130J pilot behind an auto-build helper) gets `CTLD_SAM_BUILD_SPACING` with the cargo name (`CTLD.lua:2858-2864`).
`_CleanUpCrates` and `_BuildObjectFromCrates` are wrapped to register and clear the pending build position (`CTLD.lua:2868-2896`).
In the non-PvP game there is no spacing rule in `Foothold CTLD.lua`; the only placement rule is `nobuildinloadzones` (`CTLD.lua:153`).

## 13. C-130J (and Hercules mod): loading, air-drop and auto-build

### Player view

The C-130J-30 uses the DCS native cargo system: crates requested from the CTLD menu spawn on the ramp side, are loaded with the module's own loading UI, and can be unloaded on the ground or para-dropped in flight.
When **all** crates of a requested set have come to rest on the ground outside the zone they were picked up in, the item builds itself after about 2 s plus the 30 s build time, with no engineer and no menu action (`CTLD.lua:3604-3704`).
Messages: `CTLD_MOVE_CARGO_BEFORE_HERCULES_AUTOBUILD` (crates put down in their pickup zone), `CTLD_AUTO_BUILD_FAILED_DESTROYED` (a crate died), `CTLD_AUTO_BUILD_SKIPPED_AIRBORNE` (`CTLD.lua:3555`, `CTLD.lua:3586`, `CTLD.lua:3606`).
Zone-supply and warehouse crates dropped from a C-130J follow §8/§9 with a dedicated landing detection.
The C-130J can also take whole vehicles (`AddUnits`, §2) and up to 64 troops (§1).

### Mission-maker view

`UseC130LoadAndUnload` (Config) enables the feature (`CTLD.lua:168-170`, `CTLD.lua:7193`).

### Mechanism

`OnAfterGetCrates`: when the requesting unit is a C-130J (`CTLD:IsC130J`, Moose) and the feature is on, the buildable crates of the request are registered as one "auto-build set" `{id, groupName, playerName, unitName, pickupZone, crates, required}` and one entry per crate (`CTLD.lua:7193-7211`, `CTLD.lua:2720-2775`).
`processC130AutoBuild` runs in the 3 s tick (`CTLD.lua:4191-4194`, `CTLD.lua:3455-3759`): per crate it tracks `attached` (crate within `attach` = 10 m of the grounded aircraft), `detached` (more than `detach` = 14 m from the flying aircraft), `wasAirborne` (AGL ≥ 8 m) and `landed` (AGL ≤ 0.5 m, not moving, AGL stable within 0.05 m over two passes, and not in the pickup zone).
If nobody is recorded as owner, the first 10 m of crate movement resolves the owner as the nearest C-130J client (within 4 m in 2D, else within 250 m in 3D) from a Moose `SET_CLIENT` filtered on type `C-130J-30` (`CTLD.lua:2639-2699`, `CTLD.lua:3489-3499`).
When all crates of a set have landed, the set is abandoned with `CTLD_AUTO_BUILD_SKIPPED_AIRBORNE` ("auto-build skipped (aircraft not airborne)", `L10N:1706`) if the owning aircraft is on the ground with a player in it (`c130AutoBuildCarrierBlocksBuild`, `CTLD.lua:2603-2619`, `CTLD.lua:3605-3611`): auto-build is for air-dropped sets only, crates unloaded on the ground stay for a manual build.
Otherwise the script spawns an invisible helper: a one-man `Soldier M4` group `CTLD_C130_HELPER_<n>` at the centroid of the crates via `coalition.addGroup` (`CTLD.lua:3613-3655`).
Two seconds later it calls Moose `_BuildCrates(helperGroup, helperUnit, true, true, notifyGroup)` — the same build routine a player would trigger, with the helper acting as an engineer — and destroys the helper `buildtime + 5` s later; leftover crates are destroyed at the same time (`CTLD.lua:3668-3753`).
The helper name maps back to the real player for rewards and career stats (`ctldBuildRewardHelperOwners`, `CTLD.lua:3659-3664`, `CTLD.lua:6030-6041`) and airdropped builds get their own career counters (`CTLD.lua:6056-6064`).
The bundled Moose also contains its own C-130 dynamic-cargo auto-build (`_C130DcAuto*`, `Moose:76571-77249`, enabled only if `UseC130DynamicCargoAutoBuild` is set, `Moose:83574-83577`); Foothold does not set that flag in `CTLD.lua` and uses its own implementation above.
**Hercules mod**: it is a valid CTLD transport (prefix `Hercules`, capabilities 8 crates / 20 troops, `CTLD.lua:104`, `CTLD.lua:465`) and has a separate legacy path, `HercCargoDropSupply` (§20).

### Reproduction notes

Landing detection for free-falling/parachuted statics is pure polling with debouncing; the thresholds (0.5 m AGL, 0.05 m stability, 8 m "was airborne", 10/14 m attach/detach) are empirical.
The helper-soldier trick reuses a build routine that requires a builder unit near the crates.

## 14. FARP and "FARP with ZELL" construction kits

### Player view

Three crates of `FARP` (or `FARP Huey` for the UH-1H, lighter crates) built outside any campaign zone create a working invisible FARP named `CTLD FARP <name>` from a fixed list of 11 clear names (`CTLD.lua:5769-5807`).
Coalition message `DYNAMIC_FARP_IN_OPERATION` (`CTLD.lua:5854`).
On the F10 map: a 150 m circle and a text label `<name> [SUP] <n>` showing the FARP's supply counter (`CTLD.lua:5907-5923`, `CTLD.lua:1428-1431`).
The FARP is a CTLD pickup zone (troops, crates, zone supplies as long as its supply counter is above zero), has a warehouse, and can be used for rearm/refuel and (if the mission allows) dynamic spawn.
`FARP with ZELL` additionally spawns a `Zell` (zero-length launch) heliport object next to the FARP, stocked with one aircraft type and fuel, from which a jet can spawn (`CTLD.lua:5600-5692`, `CTLD.lua:5590-5597`).
Reward for building: 100 credits, stat `Built FARP`, career stat `FarpsBuilt` (`CTLD.lua:5932-5937`, `CTLD.lua:6142-6149`).
Building inside a campaign zone is silently refused (`CTLD.lua:5699-5702`).

### Mission-maker view

Templates `CTLD_TROOP_FOB` and (optional) `CTLD_TROOP_FOB_ZELL` must exist in the `.miz` (`CTLD.lua:324-328`).
Config: `CTLDSupplyCapacity` (initial FARP supply counter, default 1, `Config:1299`), `MAX_SAVED_FARPS` (max restored, default 3, `Config:2155`), price entries `FARP` and `FARP with ZELL` (`Config:2011-2012`).
Hard-coded in `CTLD.lua`: names London, Dallas, Paris, Moscow, Berlin, Rome, Madrid, Warsaw, Dublin, Perth, Stockholm (PvP red: Minsk, Kazan, Kursk…), radio frequency counter starting at 129 (AM) and incremented per FARP, ZELL aircraft `F-100D` (plus `F-104G`) in unlimited quantity (1073741823) and 10 000 000 of each liquid (`CTLD.lua:5529-5550`, `CTLD.lua:5800-5801`, `CTLD.lua:5830-5834`).
`FARPStock` (max FARPs kept in the save file) is read but defined nowhere in the scripts, so all live FARPs are saved (`CTLD.lua:7644`).

### Mechanism

Moose builds the `CTLD_TROOP_FOB` template group like any crate cargo; `OnAfterCratesBuild` recognises the template name in the new group's name, destroys that placeholder group and calls `BuildAFARP(coordinate, {zell=…})` (`CTLD.lua:6128-6196`).
`BuildAFARP` (`CTLD.lua:5695-5925`):
- picks a free name, creates a Moose `ZONE_RADIUS` of 150 m;
- calls Moose `UTILS.SpawnFARPAndFunctionalStatics(name, coord, ENUMS.FARPType.INVISIBLE, coalition, country, callsignNumber, frequency, AM, nil, nil, nil, 10000, 0, 0, nil, true, true, 3, 80, 80)` (`CTLD.lua:5830-5834`), i.e. no ADF beacon, no vehicle template, liquids 10000, equipment 0, airframes 0, no F10 text, dynamic spawn and hot start allowed, **3 pads** spaced 80 m;
  - what Moose does (`Moose:4843-5001`): with more than one pad it builds a group table of `Heliports`-category units of type `Invisible FARP` / shape `invisiblefarp` (`Moose:2030`), the first named `<name>` and the others `<name>-2`, `<name>-3`, placed on an equilateral triangle of side 80 m, each carrying `heliport_callsign_id`, `heliport_frequency`, `heliport_modulation`, `dynamicSpawn`, `allowHotStart`, and spawns it with **`coalition.addGroup(country, -1, groupData)`** (category −1), then injects a synthetic `EVENTS.Birth` with `world.onEvent` so that Moose registers the new airbase (`Moose:4888-4943`); a single pad would instead go through `SPAWNSTATIC:NewFromType(type, "Heliports", country):InitFARP(…):SpawnFromCoordinate` (→ `coalition.addStaticObject`) (`Moose:4945-4949`);
  - `PopulateStorage`: `STORAGE:New(name)` then `SetLiquid` of 10000 × 1000 = 10 000 000 for diesel, gasoline, jet fuel and MW50; equipment and airframes are left untouched because Foothold passes 0 (it stocks them itself in `CopyWarehouse`) (`Moose:4844-4866`, `Moose:4875-4878`, `Moose:4951`);
  - four service statics spawned with `SPAWNSTATIC` (→ `coalition.addStaticObject`) 100 m from the centre, 30° apart, facing it: `FUEL - <name>` (`FARP Fuel Depot`), `AMMO - <name>` (`FARP Ammo Dump Coating`), `TENT - <name>` (`FARP Tent`), `WINDSOCK - <name>` (`Windsock`), all in category `Fortifications`; these are the names the ZELL code looks up later (`Moose:4952-4968`, `CTLD.lua:5618-5619`);
- adds a Moose CTLD `LOAD` zone on it (`CTLD.lua:5853`);
- records `{name, coord, seq, zell, supplyStock}` in `BuiltFARPCoordinates` and `builtFarpSupplyRecordsByName`, and calls `bc:registerDynamicFarp(name, coord, side)` so the engine knows it (`CTLD.lua:5858-5877`);
- one second later `bc:CopyWarehouse(name, isFromSave)` stocks its warehouse (§17) (`CTLD.lua:5887-5905`);
- draws the circle and label with `trigger.action.circleToAll`, `textToAll`, `setMarkupText` (`CTLD.lua:5907-5923`).
`CopyWarehouse` also appends the FARP name to the global `supplyZones` list and to `allZones`, registers it with the welcome-message script and with warehouse persistence, and refreshes the shop's warehouse targets (`zc2:20112-20141`).
ZELL: the script computes a position from the bearings of the ammo and windsock statics, then spawns a static-like group with `coalition.addGroup(country, -1, {units={{category="Heliports", type="Zell", shape_name="ZELL", dynamicSpawn=true, allowHotStart=true…}}})` and fires a synthetic `EVENTS.Birth` so Moose registers the new airbase (`CTLD.lua:5618-5673`); its warehouse gets `FARP_ZELL_AIRCRAFT` and `F-104G` at `FARP_ZELL_AIRCRAFT_AMOUNT` and the four liquids at `FARP_ZELL_LIQUID_AMOUNT` (`CTLD.lua:5590-5597`).
FARP supply counter: `GetFarpSupplyStock`, `AddFarpSupplyStock`, `ConsumeFarpSupplyStock` (`CTLD.lua:1476-1508`); it is debited when a player takes zone supplies there and credited when supplies are delivered there.
PvP adds ownership (`side`, `country`, native airbase id), a limit of 3 active FARPs per side (`CTLD.lua:5708-5713`), `Airbase:autoCapture(true)` on the new base (`CTLD.lua:5840`) and separate red names.

### "FOB / Logistic Center"

There is no separate FOB kit in v6.5.3: the Moose cargo type `CTLD_CARGO.Enum.FOB` is used only as the "static site, does not move" type for the FARP kits and SAM sites (`CTLD.lua:287-327`).
`LogisticCenter` is a **zone property** in the engine (`zoneObj.LogisticCenter == true`), not something players build with CTLD crates: it marks the zones whose warehouse is the unlimited source of weapons when `WarehouseLogistics` is on (`zc2:115114`, `zc2:115191-115204`, §17).
It is set by the setup file for the starting bases, and players can create one in a fully upgraded friendly airbase zone with the shop item "Logistic Center [WH]", which spawns the `[WH]` building described in §27 (`Setup:5921-5934`, `zc2:24155-24210`).

### Reproduction notes

Spawning a functional FARP at runtime relies on DCS accepting `coalition.addGroup(country, -1, {units = {{category = "Heliports", type = "Invisible FARP", …}}})` (several pads) or `coalition.addStaticObject` with a `Heliports` static (one pad) and giving the result a warehouse; the warehouse is then reachable with `Airbase.getByName(name):getWarehouse()` (`Moose:4903-4949`).
Runtime FARPs are not in `env.mission`, so anything that enumerates airbases at start must be told about them (the `RegisterExtraAirbase` / `supplyZones` / `allZones` calls).

## 15. Rewards, kill credit and career hooks

Build rewards (`CTLD_BUILD_REWARD_BY_CARGO`): FARP 100 (`Built FARP`), HAWK System 150 (`Built HAWK`), NASAMS System 150 (`Built NASAMS`), IRIS T System 200 (`Built IRIS-T`); PvP adds Pantsir S1, SA-3, SA-8, Tor M2 at 150 (`CTLD.lua:5932-5945`).
Paid with `bc:addContribution(player, side, reward)` and `bc:addTempStat(player, stat, 1)` only if the player has a contribution record (`CTLD.lua:6066-6080`).
Kill credit for player-built units: `RegisterPlayerCtldRewardGroup(Vehicle, cargoName, playerName)` stores, per DCS unit id, `{groupName, playerName, stat}` with stat `CTLD <cargo> kill` (overrides: `CTLD HAWK kill`, `CTLD NASAMS kill`, `CTLD IRIS-T kill`, `CTLD HIMARS kill`) (`CTLD.lua:5957-6028`).
The engine's kill handler looks the shooter up in `Foothold_ctld.PlayerCtldRewards.unitsById[unit:getID()]` when the shooter is a ground unit, and credits the builder with `bc.rewards.ctldAir` (default 20) or `bc.rewards.ctldGround` (default 10) through `_handleCtldRewardKill` (`zc2:42827-42845`, `Config:1923-1924`).
The Moose save also writes the builder's name next to each saved group (`Moose:83888`), which is how `PlayerName` comes back in `OnAfterLoaded`.
Career statistics recorded through `bc:recordCareerStat` / `bc:recordCareerAircraftStat`: `CtldBuilds`, `CtldUpgrades`, `FarpsBuilt`, `AirDefenseBuilt`, `AirdroppedBuilds`, `AirdroppedAirDefenseBuilds`, `TroopDrops`, `TroopCaptures`, `SupplyUnitsDelivered`, `ZoneSupplyUnits`, `FarpSupplyUnits`, `AirdroppedSupplyUnits`, `WarehouseDeliveries`, `DemolitionKills` (`CTLD.lua:4241-4271`, `CTLD.lua:6043-6064`, `CTLD.lua:6142-6144`, `CTLD.lua:6241-6251`, `CTLD.lua:8564`, `CTLD.lua:8943`, `CTLD.lua:2229`).
Rank is only an entry condition (`reqRank` passed to `bc:debit`); CTLD actions feed rank indirectly through contributions and career stats.

## 16. Persistence of built units, troops and FARPs

### Mission-maker view

Requires a de-sanitized `io`/`lfs`; otherwise a 300 s message `CTLD_SAVE_LOAD_DISABLED_DESANITIZE` is shown to all (`CTLD.lua:8153-8154`).
Files (in `FootholdSavePath` or `<Saved Games>\Missions\Saves`): `<base>_CTLD_Save.csv` (Moose format; its `Structure` column is also what restores the SAM add-ons, §11), the FARP file `FarpFileName`, and `<base>_CTLD_Red_Save.csv` when the red CTLD exists (`CTLD.lua:8105-8110`, `CTLD.lua:8137-8146`).

### Mechanism

Built units and dropped troops: Moose CTLD's own save/load (`enableLoadSave = true`, `saveinterval = 300`, `__Load(1)`; Moose `onafterSave` `Moose:83829`, `onafterLoad` `Moose:84008`), with `eventoninject = true` so that `OnAfterCratesBuild` / `OnAfterTroopsDeployed` fire for restored groups, and `useprecisecoordloads = true` (`CTLD.lua:8105-8110`, `CTLD.lua:8161`).
`OnAfterLoaded` post-processes the restored groups (`CTLD.lua:8163-8284`):
- a group farther than 80 NM from the nearest enemy is not kept: it is destroyed and its stock returned (`bc:_restorePointTooFarFromEnemy(point, 80)`, `CTLD.lua:8188`, `CTLD.lua:8199-8209`);
- the rest are put in `GroundUnits` / `TroopUnits`, then `EnforceMaxAtSpawnForTrackedUnits` deletes the oldest beyond `MAX_AT_SPAWN` and returns their stock (`CTLD.lua:8221-8237`, `CTLD.lua:3419-3453`);
- all restored loose crates are destroyed and crates are removed from every `Loaded_Cargo` (only troops stay loaded) (`CTLD.lua:8251-8274`);
- 5 s later SAM augments are re-applied (`CTLD.lua:8276-8283`).
FARPs: `SaveFARPS` every 300 s (first at 30 s) writes one line per FARP `seq;name;x;y;zell;lat;lon;supplyStock;` (PvP adds side and country), keeping the newest `FARPStock` and renumbering `seq` from 1 (`CTLD.lua:7613-7710`, timers `CTLD.lua:8099-8103`).
`LoadFARPS` runs 1 s after load, accepts three legacy line formats, restores newest first up to `MAX_SAVED_FARPS`, and skips a FARP farther than 60 NM from the nearest enemy (`CTLD.lua:7712-7845`, `CTLD.lua:5735-5746`).
FARP warehouses are restored through `WarehousePersistence` (the FARP is registered as an "extra airbase" and its restore is sequenced by `BeginFarpStartupRestore` / `CompleteFarpStartupRestore`, `CTLD.lua:8098`, `CTLD.lua:7841-7844`, `zc2:20235-20242`).
`resetSaveFileAndFarp()` truncates all CTLD save files and clears the FARP tables (campaign reset) (`CTLD.lua:8113-8152`).

### Reproduction notes

Persistence of built units is entirely Moose's CSV plus template re-spawn; the Foothold additions are the distance-from-front pruning and the per-type caps.

## 17. Warehouse logistics system (engine side)

### Player view

With `WarehouseLogistics = true` (the shipped default, `Config:1279`) weapons are finite at every airbase/FARP except the Logistic Centers.
A freshly captured base has an empty weapon warehouse ("Neutral zones start without weapons; you must bring them or wait for AI delivery", `Config:1276-1279`); players stock it with zone-supply crates (+10 of everything), warehouse bundles (§9), shop items, or wait for AI deliveries and the periodic auto-fill.
Zone labels show a low-stock tag computed by a background "health scanner" (`zc2:111752-111822`).
With `WarehouseLogistics = false` every friendly airbase is simply set to unlimited weapons and the old "Load supplies" menu is used instead (§18).
Aircraft availability per base follows the era lists: in Coldwar/Vietnam (and PvP Modern with separate lists) only the listed airframes can be spawned at a base, and the list flips when the base changes side (`zc2:56522-56553`).

### Mission-maker view (Config)

| Setting | Default | Meaning | Ref |
|---|---|---|---|
| `WarehouseLogistics` | true | finite weapon stocks and CTLD supply cargo; false = legacy unlimited mode | `Config:1279` |
| `AutoFillResources` | 5 | every 15 min each friendly non-suspended zone airbase gains this many of every weapon | `Config:1350`, `zc2:51106-51136` |
| `AIDeliveryamount` | 20 | weapons of each type added by one AI helicopter/convoy supply run (50 for a supply plane) | `Config:1347`, `zc2:67860-67866` |
| `NormalSupplyCapacity` / `WarehouseSupplyCapacity` | 1 / 6 | ready supply packages a normal zone / a Logistic Center zone accumulates | `Config:1289-1294`, `zc2:52332-52341` |
| `PlayerZoneSuppliesConsumeStock` | true | player pickups consume those packages | `Config:1337` |
| `StrictSmartWeaponsInventory`, `WarehouseWeaponCaps` | false, `{}` | listed "smart" weapons receive half of any refill | `Config:1422-1427`, `zc2:19566-19588` |
| `WarehouseWeaponsAllowedAtAirbases` | `{}` | PvE only: per mission name, weapon id → list of the only airbases that may stock it | `Config:1429-1434`, `zc2:51167-51230` |
| `ForbiddWeaponsInAllEra` | RN-24, RN-28 | always forced to 0 | `zc2:114797-114800` |
| `restrictedWeapons`, `restrictedWeaponsVietnam` | lists (AIM-120, AIM-9X, AGM-154…) | removed from every warehouse in Coldwar/Vietnam | `zc2:114802-114812`, `zc2:114929-114939` |
| `allowedPlanes`, `allowedPlanesRed`, `allowedPlanesVietnam`, `allowedPlanesRedVietnam`, `allowedPlanesModern`, `allowedPlanesRedModern`, `AllowedWW2Planes`, `AllowedWW2RedPlanes` | per-era lists | airframes set to unlimited at a base according to era and owner; all others set to 0 | `zc2:114980-115020` |
| `restockAircraft` | list (UH-60L, Ka-50, OH-6A, mods…) | airframes re-set to unlimited in Modern era | `zc2:114925-114927`, `zc2:115076-115081` |
| `AIOnlyAircraft` | list (A-50, B-1B, An-26B…) | always unlimited so AI flights can spawn from a base | `zc2:8-14`, `zc2:11972-11976` |
| `AllowMods` | false | Modern only: adds a `MODS` weapon category and the "Modded weapons" bundles | `Config:258`, `zc2:114443-114445` |
| `PvPSeparateAircraftLists` | false | PvP: separate BLUE/RED aircraft lists applied per base and per FARP | `Config:2391`, `zc2:20209-20234` |
| `zone.LogisticCenter = true` | set in the setup file | marks the unlimited source bases | `Setup:5922-5934` |

Mission-editor rule stated in the config: every warehouse must have aircraft set to LIMITED, not copied to all ships (`Config:197`); the engine warns with `WAREHOUSE_UNLIMITED_AIRCRAFT_DETECTED` / `WAREHOUSE_UNLIMITED_WAREHOUSE_DETECTED` when it detects an unlimited one (`zc2:114943-114961`, `zc2:115093-115106`).

### Mechanism

**DCS API**: everything goes through Moose `STORAGE`, a thin wrapper: `STORAGE:New(name)` = `Airbase.getByName(name):getWarehouse()`; `AddItem` → `Warehouse:addItem`, `SetItem` → `Warehouse:setItem`, `GetItemAmount` → `Warehouse:getItemCount`, `RemoveItem` → `Warehouse:removeItem`, `SetLiquid` → `Warehouse:setLiquidAmount` (`Moose:35734-35738`), `GetInventory` → `Warehouse:getInventory()` returning aircraft, liquids, weapon tables (`Moose:35671-35727`, `Moose:35838-35841`).
`STORAGE:FindByName` reads Moose's `_DATABASE` storage registry (`Moose:35698-35701`); for runtime airbases the engine patches `storage.airbase` / `storage.warehouse` by hand (`zc2:20143-20147`, `zc2:15512-15527`).
The engine also uses `Warehouse.getResourceMap()` (name → wsType 4-tuple) and reads `env.warehouses.airports[id].weapons` for items the map does not name (`zc2:51139-51149`, `zc2:114625`, `zc2:114703-114719`).
"Unlimited" is represented by the quantity 1073741823 (`zc2:20204`, `zc2:115071`).

**`WEAPONSLIST`** (`zc2:112318-114937`): a hand-maintained catalogue `WEAPONSLIST.Items[category] = {weapon ids…}` with categories `AA_MISSILES`, `AG_MISSILES`, `AG_ROCKETS`, `AG_BOMBS`, `AG_GUIDED_BOMBS`, `FUEL_TANKS`, `MISC`, `MODS` (`zc2:112323-112372`), about 1 300 lines of ids plus a separate mods list (`zc2:113738-114440`).
Structure of the catalogue:
- A weapon entry carries **no attributes at all** (no name, no weight, no price, no era): it is only an identifier, in one of two forms accepted by the DCS `Warehouse` API — a resource string such as `'weapons.missiles.AIM-7E'`, `'weapons.nurs.ARAKM70BAP'`, `'weapons.bombs.AGM_62'`, `'weapons.droptanks.1100L Tank'`, `'weapons.containers.{GPU_5_POD}'`, `'weapons.gunmounts.A20_TopTurret_M2_L'`, or a wsType 4-tuple such as `{4,4,8,477}` for the items that have no resource string (`zc2:112375`, `zc2:112559-112560`, `zc2:112953-112956`).
- The category is the only metadata, given by the list the id is written in; `CategoryOrder` fixes the order in which the categories are walked, and `ItemCategory.ALL` is a pseudo-category for "every list" (`zc2:112323-112344`).

| Category | Content | Entries (strings + tuples) | Lines |
|---|---|---|---|
| `AA_MISSILES` | air-to-air missiles | 67 | `zc2:112373-112443` |
| `AG_MISSILES` | air-to-ground missiles, decoys, some guided glide weapons | 113 + 2 | `zc2:112444-112563` |
| `AG_ROCKETS` | unguided rockets (`weapons.nurs.*`) | 77 | `zc2:112564-112644` |
| `AG_BOMBS` | unguided, cluster and general bombs | 142 + 3 | `zc2:112645-112794` |
| `AG_GUIDED_BOMBS` | guided bombs | 40 + 1 | `zc2:112795-112840` |
| `FUEL_TANKS` | drop tanks | 106 | `zc2:112841-112951` |
| `MISC` | adapters, pylons, pods, containers, gun mounts, everything else | 768 + 8 | `zc2:112952-113737` |
| `MODS` | weapons of community aircraft mods; attached only when `AllowMods` and `Era == "Modern"` | 689 + 3 | `zc2:113738-114445` |

- So about 1 330 entries in the seven stock categories and about 690 more with mods (counts made by script on the listed line ranges).
- Everything else about a weapon lives outside the list, as separate name sets: era restriction (`restrictedWeapons`, `restrictedWeaponsVietnam` → `IsRestricted`), always-forbidden (`ForbiddWeaponsInAllEra`), "smart weapon" half refill (`WarehouseWeaponCaps`), per-airbase location rules (`WarehouseWeaponsAllowedAtAirbases`), the ×3 multiplier for the whole `AG_ROCKETS` category, and a `WEAPONSLIST_MODS_CLEAR_SET` used to zero mod weapons when mods are off (`zc2:114438-114445`, `zc2:114797-114812`, `CTLD.lua:1398-1400`).
- `_flattenUnique(itemsByCategory, categories)` builds the de-duplicated flat list behind `GetAllItems()`, and `_wsFilterRestricted` removes era-restricted ids in Coldwar/Vietnam (`zc2:114447-114484`).
`GetItems(category)` returns the list, minus era-restricted items in Coldwar/Vietnam; `GetAllItems()` is the cached flattened list; `IsRestricted(name)` tests the era list (`zc2:114498-114517`, `zc2:114937-114939`).
`SyncFromWarehouseLogistics` runs 0.1 s after load: it scans the inventory of the Logistic Center airbases for weapon keys not in the catalogue, files them under a category derived from their wsType, and zeroes them at all other friendly bases — a self-healing step for new DCS weapons (`zc2:114617-114768`, `zc2:115251-115262`).
`ClearWeaponsInStorage` sets every catalogue item to 0 (`zc2:114770-114787`).

**Initial stocking** — `checkWeaponsList()` 1 s after load (`zc2:115247-115249`, `zc2:115022-115245`):
- Modern era: for Logistic Center airbases (or all zone airbases when `WarehouseLogistics` is false) every catalogue weapon is set to unlimited unless the zone has a finite warehouse facility; `restockAircraft` set to unlimited; forbidden weapons to 0 (`zc2:115183-115245`).
- Coldwar/Vietnam: per airbase, restricted weapons removed, then weapons set to unlimited only at Logistic Centers (or everywhere if logistics is off), and the aircraft inventory replaced by the era list for the owning side (`zc2:115093-115181`).
- Normandy: only the aircraft lists are applied (`zc2:115023-115037`).

**On capture / side change** (`ZoneCommander:init` and the capture paths): the DCS airbase coalition is forced with `Airbase:setCoalition(side)` after `autoCapture(false)` (`zc2:51439`, `zc2:51450-51476`, `zc2:56757`), a synthetic `S_EVENT_BASE_CAPTURED` is injected (`zc2:56761-56767`), the base's service statics are respawned for the new side (`RespawnStaticsForAirbase`), and with `WarehouseLogistics` on and the zone not a Logistic Center **the weapon warehouse is emptied** (`WEAPONSLIST.ClearWeaponsAtAirbase`, `zc2:51451-51453`, `zc2:51477-51479`, `zc2:55364-55366`).
A Logistic Center zone that BLUE holds is pre-filled with 1000 of every weapon the resource map knows and the catalogue does not (`zc2:51440-51442`, `zc2:51294-51340`); in PvE a Logistic Center captured by RED loses the flag (`zc2:51459`).
The aircraft list is re-synchronised by `syncColdwarAllowedPlanesAtAirbase` (`zc2:56522-56553`, called at `zc2:55369`, `zc2:56771`).

**Refills**:
- `bc:addWarehouseItemsAtZone(zone, side, amount)` is the common primitive: `storage:AddItem` of `amount` for every catalogue weapon (×3 for rockets, halved for strict smart weapons, skipping forbidden, era-restricted and policy-denied ones), mirrored into the paired ZELL warehouse if any (`zc2:51022-51104`).
- Callers: auto-fill every 900 s, staggered 0.2 s per airbase (`zc2:51106-51136`); AI supply arrival (`zc2:67860-67866`); Hercules-mod crate (+10, `zc2:102425-102427`); shop item "Resupply warehouse with 50" (`applyWarehouseResupply`, `zc2:24300-24319`, `Config:1693`, `Config:1833`); activating a purchased Logistic Center (+500 000, `zc2:46356-46369`); pending-capture completion with a `warehouseAmount` payload (`zc2:24714`).
- `ManualAdjustWarehouse(zoneName, delta)` / `GroupCommander:_adjustWarehouseStock` add or remove a flat amount of every weapon (floor 0) — used by AI flights that draw from a base (`zc2:59529-59581`).
- CTLD: `adjustWarehouseStockAtZone` (§9).

**`WarehouseWeaponLocationPolicy`** (`zc2:51151-51292`): built at start from `WarehouseWeaponsAllowedAtAirbases[<mission name by theatre>]`; inactive in PvP or when empty (`zc2:51167-51186`).
Each rule is `{id, key, name, allowed = {airbaseName = true}}` keyed by the weapon's resource key (`zc2:51188-51214`).
`IsDenied(policy, airbase, item)` is consulted by every stocking routine above; `RestoreBalance` zeroes denied weapons on first contact with a warehouse and restores saved balances afterwards (`zc2:51245-51292`).
When a policy is active the CTLD warehouse bundles switch to the "managed" exact-manifest mode (§9).

**Dynamic FARPs and ZELLs** — `bc:CopyWarehouse(name, fromSave)` (`zc2:20074-20244`): despite the name it does not copy anything; it retries up to 10 times at 2 s until the `STORAGE` exists, then sets every catalogue weapon to 30 (rockets 90) for a new FARP, 0 for a restored one (the saved inventory is then loaded by `WarehousePersistence.Load`), or unlimited when logistics is off; sets the era's allowed aircraft to unlimited (PvP separate lists: zero everything first); and stocks `AIOnlyAircraft`.
**Carriers** are excluded from warehouse persistence (`_shouldSkip`, `zc2:111508-111520`) and are re-stocked with `checkWeaponsList(groupName)` when the carrier group is respawned by the carrier-navigation feature (`zc2:15512-15527`, `zc2:15569-15571`).

**`WarehousePersistence` from the logistics side**: started by `startWarehousePersistence()` from the setup file (`Setup:6013`) with load at +5 s, save at +30 s then every 300 s, file `<base>_storage.csv` (`zc2:112302-112316`); it covers friendly non-Logistic-Center zone airbases plus "extra airbases" registered at runtime — player FARPs and ZELLs (`RegisterExtraAirbase`, `zc2:111522-111535`, `zc2:111537-111568`).
A health scanner evaluates one zone per second in a round-robin and stores `WarehouseLowSupplies[zone] = {state, lowCategories…}` used for the zone label (`zc2:111825-111849`).
File format: theme 02.

**Zone "regular supply" stock** (the packages players consume): `zone._regularSupplyReady`, `_regularSupplyExpeditedReady`, `_regularSupplyPendingStock`, `_regularSupplyStockSide`; `_consumePlayerRegularSupplyStock(amount, side, now)` refuses when the zone is not the player's, or when ready minus reserved is short (it first tries to release delayed AI dispatch permits in the player's favour), and returns how many of the consumed units were "expedited" ones (`zc2:52369-52401`); `_restorePlayerRegularSupplyStock` puts them back (`zc2:52403-52416`).
Production, AI dispatch and the repair jobs that spend that stock are described in §26.

### Reproduction notes

DCS offers no "list all weapon ids" call, hence the 1 300-line hand catalogue and the self-healing scan of a reference warehouse.
Item keys are either strings (`weapons.missiles.AIM_120C`) or wsType 4-tuples; the code normalises with `_getWarehouseItemKey` and `ResourceKey` (`zc2:19590-19595`, `zc2:51153-51164`).
`Warehouse:setItem` on runtime-spawned airbases only works once the airbase object exists, hence the retry loop.
Every "refill" touches every weapon id of the catalogue on one warehouse (roughly 1 000 `addItem` calls), which is why refills are staggered per airbase.

## 18. LogisticCommander: the original "load supplies" logistics

### What is still active in v6.5.3

`LogisticCommander` is still instantiated by every setup file (`lc = LogisticCommander:new({battleCommander = bc, supplyZones = supplyZones})`, `lc:init()`, `Setup:5792`, `Setup:5833`) and remains the owner of: the per-player F10 `Logistics` menu, the CSAR/pilot-rescue system (theme 06), the birth/take-off handlers that build all per-group menus, and the take-off "supplies not loaded" warning.
Its **supply load/unload commands are only added when `WarehouseLogistics == false`** and the airframe is in `AllowedToCarrySupplies` (`zc2:101566-101585`); with the shipped default the same menu instead hosts the CTLD static-cargo entries (§19).
`init()` only starts the CSAR restore and a 10 s `update` loop (CSAR) (`zc2:102273-102278`).

### Player view (legacy mode)

`Logistics` → `Load supplies` / `Unload supplies` (sub-menus "Load 1 supply … Load N supplies" when the airframe carries more than one: 2 for CH-47 and Mosquito, 3 for Hercules and C-130J, `zc2:97695-97707`), `List supply zones`, `Supplies Status`, `Mark Zone` (smoke on a chosen zone) (`zc2:101566-101585`, `zc2:101757-101771`).
Loading is only possible on the ground inside a friendly **supply zone** (names listed in the setup's `supplyZones`), within 200 m of a carrier, or inside a player/escort FARP zone (`zc2:98075-98190`).
The cargo is virtual: no object is spawned; the aircraft gets 100 kg of internal cargo per supply with `trigger.action.setUnitInternalCargo(unitName, 100 × count)` (`zc2:98056`, `zc2:98179`).
Unloading on the ground in a neutral zone starts a capture; in a friendly zone it adds one expedited supply package and pays `Zone upgrade` (100, or 25 % with `LOGISTICS_RESUPPLY_NO_DEMAND` when the zone needs nothing); unloading in the source zone just returns the stock; on a carrier it discards; in a FARP it adds to the FARP supply counter (`zc2:98194-98412`).
Messages: the `LOGISTICS_*` keys (`L10N:1638-1665`).

### Mechanism

State: `self.carriedCargo[groupId] = {source, count, stockConsumed, expeditedStockConsumed}` (`zc2:98173-98178`), reset at each birth (`zc2:101775`).
Unload schedules one "drop" per supply: the first after 1 s, the following every 3 s, each re-evaluating the zone under the aircraft (`zc2:98319-98352`).
Neutral zone: `zone:startPendingCaptureWithCargoStatic(side, point 10–20 m behind the aircraft, country, {delivery = {handler = "zonecommander_capture_delivery", payload}})` — a real cargo static is spawned on the ground as the capture token (`zc2:98246-98268`).
A synthetic `S_EVENT_LAND` is injected 5 s later to bank the reward (`zc2:98330-98346`).
Menus are created 0.5 s after `S_EVENT_BIRTH` of a player unit by `_handleBirth`, guarded by a per-group token so a stale scheduled build is dropped (`zc2:101471`, `zc2:101557-101558`, `zc2:101781`).
`pruneGroupMenus` removes every per-group menu of every subsystem when the player leaves, including clearing the Moose CTLD menu handles on the group object (`zc2:97785-97950`, `zc2:97816-97823`).

### Relation to CTLD

Same zone-side effects (capture token, `_addExpeditedRegularSupplyStock`, FARP supply counter) reached by two front-ends: virtual cargo here, physical tracked crates in §8.
The `Logistics` Moose menu created here is the parent under which Moose CTLD hangs its own `CTLD` menu (`Moose:80799-80806`).
Take-off warning: `_warnIfSupplyCarrierTakesOffEmpty` checks, at take-off from a friendly supply zone or FARP with stock available, whether the aircraft carries zone-action cargo (CTLD crates or capture-capable troops in logistics mode, `carriedCargo` in legacy mode) and, if not, shows `LOGISTICS_WARNING_NOT_LOADED` for 30 s with `micclick.ogg`; user flag 180 non-zero disables it (`zc2:101336-101410`).

## 19. The F10 menu tree as the player sees it (logistics mode, BLUE)

```
F10 Other
└─ Logistics                                   (LogisticCommander, Moose MENU_GROUP; zc2:101562)
   ├─ Supplies help                            (45 s overview text; zc2:101591)
   ├─ Zone supplies                            (CTLD static cargo, per airframe; zc2:101690)
   │   └─ <crate label + mass> → quantity sub-menu (Moose _AddCrateQuantityMenus; zc2:101677)
   ├─ Warehouse                                (same mechanism; pages of 9 with "More")
   │   └─ 15/25/50 of everything, A/A Missiles, A/G Missiles, A/G Rockets, A/G Bombs, fuel tanks and pylons, Modded weapons
   ├─ Mark Zone → <zone names, pages of 9>     (smoke on zone; zc2:101757)
   └─ CTLD                                     (Moose; Moose:80806)
      ├─ Manage Troops
      │   ├─ Load troops → [sub-category] → <troop type> → quantity
      │   ├─ Drop Troops → Drop ALL troops | <one line per loaded group>
      │   └─ Extract troops
      ├─ Manage Crates
      │   ├─ Get Crates → <sub-category: ANTI TANK, Support, SAM/AAA, SAM Addon, FARP> → <item> → quantity
      │   ├─ Load Crates → Load ALL | Show loadable crates
      │   ├─ Drop Crates → <per crate set>
      │   ├─ Build crates
      │   ├─ Repair
      │   ├─ Remove crates → Remove crates nearby
      │   ├─ Pack → Pack | Pack and Load | Pack and Remove
      │   └─ List crates nearby
      ├─ Manage Units (C-130J only) → Get Units → <vehicle> | Remove units nearby
      ├─ List boarded cargo
      ├─ Inventory
      ├─ List active zone beacons
      ├─ Smokes, Flares, Beacons → Smoke zones nearby | Drop smoke now (red/blue/green/orange/white) | Flare zones nearby | Fire flare now | Drop beacon now
      └─ Show hover parameters  (helicopters)  /  Show flight parameters (fixed wing)
```

Menu structure refs: `Moose:80808-80810` (troops), `Moose:80874-81042` (crates), `Moose:81063-81096` (units), `Moose:81100-81117` (common entries); English labels `Moose:84621-84682`.
The static supply crates are registered with `DontShowInMenu = true` (6th argument of `AddStaticsCargoFromType`, `CTLD.lua:330`, `Moose:82093`), so they do not appear under `CTLD → Get Crates`; Foothold lists them itself under `Logistics` (`zc2:101588-101695`).
Item labels carry the crate count, mass and price suffix (`Moose:76351-76393`).
The `CSAR` menu is a separate root built in the same handler (`zc2:101522-101553`) and reuses `Foothold_ctld:SmokeZoneNearBy` for "smoke/flare nearest zone" (`zc2:101532-101548`).
In PvE, RED players with `Allow_Red_CTLD` get `Logistics → Zone supplies` backed by `Foothold_redCtld` (`zc2:101697-101755`).

Player-facing messages are listed with each feature; the generic Moose CTLD messages (troops boarded, crates dropped, build started, etc.) come from Moose's own localisation table (`Moose:84600+`, not listed here).

## 20. HercCargoDropSupply (Hercules mod air-drop)

### Player view

A Hercules-mod (Anubis) player who releases the mod's `Generic Crate [20000lb]` over a zone performs a zone-supply delivery without any CTLD interaction.
Messages reuse `CTLD_ZONE_SUPPLIES_DELIVERED` with `captured` / `capture started at` / `queued…` / `stocked (n/m ready) at` (`zc2:102405-102431`).

### Mechanism

The engine's shot handler passes weapons whose type name is in `HercCargoDropSupply.allowedCargo` (`weapons.bombs.Generic Crate [20000lb]`) to `HandleShot` (`zc2:42927-42928`, `zc2:102297-102298`); the event is DCS `S_EVENT_SHOT` (`zc2:42921`).
The crate weapon is polled every 0.2 s with `timer.scheduleFunction` until it is below 5 m AGL (`zc2:102307-102318`, `zc2:102444-102457`).
`ProcessCargo`: finds the zone under the weapon (`bc:getZoneOfWeapon`); ignores the drop (and destroys the crate) if the aircraft has no recorded take-off zone or drops in its take-off zone (`herculesRegistry[unitName].takeoffzone`, set at take-off by `_updateHerculesTakeoffZone`, `zc2:101322-101334`, `zc2:102356-102361`).
Neutral zone → `startPendingCaptureWithCargoStatic(side, point, country, {staticType = "iso_container_small", mass = 4000, delivery = {…, warehouseAmount = 10}})` (`zc2:102378-102403`).
Friendly zone → `_addExpeditedRegularSupplyStock(1)`, 150 credits (`Zone supply delivery`), and +10 of every weapon if logistics is on (`zc2:102410-102427`).
The weapon object is destroyed afterwards (`zc2:102438`).
If the drop was made on the ground, a synthetic landing event is scheduled 5 s later (`zc2:102320-102349`).
`HercCargoDropSupply.init(bc)` is called from the setup file (`Setup:6001`).
The config notes that the Hercules mod cannot be included in the take-off warning because its generic cargo cannot be detected (`Config:1417`).

## 21. ExternalHeloCargoRoute (as far as players are concerned)

It is an AI-only helper: builders for the DCS helicopter tasks `ExternalCargoLoad` (`unitIdTransport`, cargo `groupId`/`unitId`) and `ExternalCargoUnLoad` (`zoneId`), a race-track orbit task, and waypoint generators for the AI supply helicopters that sling a visible cargo (`zc2:58056-58081`, `zc2:58083-58240`), used when `SuppliesCargoTransport` is true (`Config:1344`, call sites `zc2:58648`, `zc2:59354`).
Players never trigger it; what they see is an AI CH-47 or Mi-8 carrying a slung crate, and its arrival has the same warehouse effect as §17 "AI supply arrival".
Details: theme 03.

## 22. Red CTLD (`Foothold_CTLD_Red.lua`)

Loaded only when `Allow_Red_CTLD == true` (default false, `Config:1963`) or PvP is enabled (`CTLD_Red.lua:5`).
A second Moose instance `Foothold_redCtld = CTLD:New(coalition.side.RED, prefixes, "Red Logistics")` with prefixes `Mi.8MT`, `Hercules`, `Ми.8МТВ2`, `Ми.24П`, `Mi.24P` (+ `C.130J.30` in PvP) and the same option values as BLUE (`CTLD_Red.lua:40-88`).
Catalogue (`CTLD_Red.lua:784-815`): troops `Squad 4 AK47`, `Squad 8 AK47`; crates (2 each) `Scout BRDM 2`, `Ammo Truck`, `Arty SPH 253 Akatsia 8 NM`, `Truck with ZU-23`, and outside Vietnam `Arty SPM 259 Nona 3 NM`, `ATGM AT-3 SAGGER`, `Kord 12.7 MM`, `MLRS LC 80 MM 2.2 NM`, `MRAP M-ATV`; `SA-8` (2 crates) and `SA-3 SAM system` (4 crates) if those red templates are enabled; `Tor M2` (PvP Modern); sub-menus `Support`, `ARTY`, `SAM/AAA`, `ANTI TANK`, `LIGHT ARMOR`; stock 6 (PvE) or 10–12 (PvP).
Prices: `RedCTLDPrices`, PvE defaults from 100 (squad, Kord) up to 5000 / rank 8 (SA-3) (`CTLD_Red.lua:122-136`); PvP uses the shared `CTLDPrices` with red entries (25–750) (`CTLD_Red.lua:96-120`, `Config:2035-2058`).
Zone supplies: `Red zone supplies C-130J / MI-8 / Mi-24P` (`CTLD_Red.lua:818-820`) with its own, simpler tracking loop `tickRedZoneSupply` every 5 s (`CTLD_Red.lua:2218`, `CTLD_Red.lua:1895-2216`) and its own completion handler `completePendingRedCtldSupply` (`CTLD_Red.lua:1437`).
Red tracking loop in detail (`redCtldProcessZoneSupply`, `CTLD_Red.lua:1895-2207`), run for every tracked crate by `tickRedZoneSupply` on a Moose `TIMER` started at 15 s with a 5 s period, which returns at once when no crate is tracked and rebuilds the "supplies on board" cache at the end (`CTLD_Red.lua:2209-2218`):
- crate reported on board by Moose, or found inside the carrier's box → marked loaded; static gone while the carrier still exists → still on board; static gone otherwise → entry removed (`CTLD_Red.lua:1896-1924`);
- first movement of the crate → `CTLD_CRATE_LOADED_GROUND_CREW`, `wasAirborne = true`; once it has moved, "unloaded" is decided from the carrier: on the ground, crate farther than the airframe's `detach`/`width` (internal cargo, `ropelength == 0`) or outside `width`/`height` (sling); in flight, farther than `detach` in 3D or outside the `width × ropelength × width` box; without a carrier, crate at ≤ 0.5 m AGL (`RED_ZONE_SUPPLY_AGL_THRESHOLD`) (`CTLD_Red.lua:1931-1981`, `CTLD_Red.lua:863`);
- a crate is "on ground" at ≤ 0.5 m AGL or once unloaded and still; its zone is resolved from its position; outside any zone it is re-checked every 60 s and dropped after 600 s (`RED_ZONE_SUPPLY_NOZONE_RECHECK`, `_TTL`) (`CTLD_Red.lua:1984-1989`, `CTLD_Red.lua:2042-2051`, `CTLD_Red.lua:864-865`);
- PvP, crate on a player-built red FARP: a zone-supply crate adds 1 to the FARP's supply counter (150 credits, `Zone supply delivery`) or is refunded if it came from that FARP; a warehouse crate is settled into the FARP's storage (`CTLD_Red.lua:1990-2040`);
- PvP warehouse crates in a zone: settled with `Foothold_ctld.ApplyWarehouseDebitItems(storage, cargo, zone, "delivery" | "return")`, reward = the bundle's `reward` (else 100 for a multi-category bundle, 50 for a single one), stat `Warehouse delivery`; destroyed with a reason in an enemy zone, when logistics is off, or when no storage exists; left waiting in a neutral zone (`CTLD_Red.lua:2053-2118`);
- zone-supply crate back in its pickup zone → stock refunded (`CTLD_SUPPLIES_RETURNED_TO_ZONE`); in a BLUE zone → destroyed ("enemy zone"); in a neutral zone → `zone:startPendingCapture(RED, {kind = "static", …, delivery = {handler = "red_ctld_capture_delivery", payload}})`; in a RED zone → `zone:_addImportedRegularSupplyStock(1, now)` and `redCtldFinalizeDelivery(…, "CTLD_ZONE_SUPPLY_ACTION_STOCKED", "Zone supply delivery", 150, {ready, max})` (`CTLD_Red.lua:2120-2206`).
Differences from the BLUE loop (§8): no separate C-130J cadence or one-shot landing confirmation, no serialized "ready queue" (each crate is applied in the pass that sees it), no automatic warehouse bundle on a zone-supply delivery, and the stock added is an "imported" unit rather than an "expedited" one (`CTLD_Red.lua:2194`, `CTLD.lua:5366-5371`).
Zones: `addCTLDZonesForRedControlled` mirrors §4 with sides swapped; zone names containing `hidden`, `dropzone`, `carrier` or `fob alpha` are not registered (`CTLD_Red.lua:2220-2235`, `CTLD_Red.lua:2237-2274`).
Persistence: `<base>_CTLD_Red_Save.csv`, same Moose options (`CTLD_Red.lua:2276-2318`).
In PvP it borrows the BLUE implementations by assigning the functions (`CanBuildCrates`, `OnAfterTroopsDeployed`, `OnAfterTroopsPickedUp`, reward registry, career recorders…) (`CTLD_Red.lua:2297-2316`), clones the FARP templates as `CTLD_TROOP_FOB_RED` / `CTLD_TROOP_FOB_ZELL_RED` under country RUSSIA (`CTLD_Red.lua:765-782`), and copies the BLUE "Warehouse" bundles (`CTLD_Red.lua:822-836`).
PvP per-FARP restrictions: at most 3 active FARPs per side (`CTLD.lua:5708-5713`), FARP ownership checked by side and native airbase id on every pickup (`CTLD.lua:6715-6720`), and FARP/ZELL warehouses get the owner's aircraft list only (`zc2:20209-20234`, `CTLD.lua:5590-5593`).

## 23. Config settings summary (CTLD and logistics)

| Setting | Default | Ref |
|---|---|---|
| `CTLDCost` | true (false = everything free) | `Config:1959` |
| `Allow_Red_CTLD` | false | `Config:1963` |
| `MaxTroopsRunDistanceTowardZone` | 5000 m | `Config:1967` |
| `CTLDCargoTrackingInterval` | 3 s (clamped 3–6) | `Config:1971`, `CTLD.lua:9437` |
| `CTLDPrices` | table `{available, price, reqRank}` per item | `Config:1975-2058` |
| `MAX_AT_SPAWN` | per-item restore cap | `Config:2063-2147` |
| `CaptureZoneWithEngineer` | false | `Config:2150` |
| `MAX_SAVED_FARPS` | 3 | `Config:2155` |
| `IRIS_RESTORE_UNIT_HEALTH_ON_MERGE` | false | `Config:2161` |
| `CTLDUnitCapabilities` | per-airframe table | `Config:2176`, `CTLD.lua:453-476` |
| `UseC130LoadAndUnload` | true ("C-130J-30 and Chinook use the internal ground-crew loading system only") | `Config:1339-1340` |
| `UseStatics` | true | `Config:515` |
| `WarningNoSupplies`, `ZoneSupplyTakeoffWarningTypes` | true, per-airframe | `Config:1389-1418` |
| `AllowedToCarrySupplies` (legacy mode only) | per-airframe | `Config:1365-1367` |
| `rewards.ctldGround`, `rewards.ctldAir`, `Warehouse delivery` | 10, 20, 150 | `Config:1923-1924`, `Config:1935` |
| shop: `zwh50` "Resupply warehouse with 50", `farphere` "Deploy FARP", `supplies2` "Resupply friendly Zone" | prices 500, 1000, 200 | `Config:1792-1839` (theme 05) |
| warehouse settings | see §17 table | |

## 24. Performance devices

- One timer for both crate cadences; nothing runs when no crate is tracked (`if not next(zoneSupplyCrates) then return`) (`CTLD.lua:4191-4202`, `CTLD.lua:9418-9438`).
- Ready deliveries and capture processing are serialized with 3–5 s between items; re-entrancy guarded by `zoneSupplyProcessRunning` / `captureRunning` flags and a "queued" flag (`CTLD.lua:5375-5476`, `CTLD.lua:8968-8996`).
- Static removals are queued with a due time and flushed by a single rescheduling timer (`CTLD.lua:4378-4453`).
- Crates outside any zone are looked up only every 60 s (`_noZoneNextCheckAt`), and the throttle is cleared when a new FARP zone appears (`CTLD.lua:4817-4820`, `CTLD.lua:3061-3067`, `zc2:20129-20131`).
- Caches: storage handle per zone, weapon list per category, Moose zone wrapper per name, carrier unit and airframe dimensions per crate, onboard-by-group flag (`CTLD.lua:1390-1392`, `CTLD.lua:3858-3902`, `CTLD.lua:1522-1529`, `CTLD.lua:2984-3015`, `CTLD.lua:3130-3139`).
- The troop zone-entry trigger reads each group position once per pass, skips completed groups, and stops itself when no deployed troop is alive (`CTLD.lua:8293-8398`).
- Stock refill is skipped while a build is in progress (`CTLD.lua:9332-9334`).
- Warehouse refills are staggered 0.2 s per airbase; the health scanner does one zone per second (`zc2:51118-51129`, `zc2:111839-111847`).
- Menu builds are deferred 0.5 s after birth and invalidated by a per-group token (`zc2:101557-101558`).

## 25. Base Moose CTLD features Foothold relies on (for later comparison with another CTLD)

Features only, each with where Foothold uses it.

- Per-coalition instance filtered by group-name prefixes, with per-airframe capability table (can crates, can troops, crate limit, troop limit, length, max cargo mass) (`CTLD.lua:104`, `CTLD.lua:474-476`).
- Troop cargo from late-activated template groups, with seats, per-man mass and stock (`CTLD.lua:264-277`).
- Crate cargo building a template group from N crates, with per-crate mass, stock, sub-category, optional airframe restriction, crate static type/shape (`CTLD.lua:280-327`).
- "NoMove" variant (built group stays put) versus moving variant (built group routes to the nearest MOVE zone) (`CTLD.lua:284-313`).
- Direct-load whole units for the C-130J (`AddUnits`) (`CTLD.lua:315-323`).
- Static cargo created from a DCS static type, non-buildable, restricted to airframes, hidden from the standard menu (`CTLD.lua:330-367`).
- Engineer troop type (`CTLD_CARGO.Enum.ENGINEERS`) and repair crates menu entry (`CTLD.lua:268`, `Moose:81027`).
- Zone types LOAD, MOVE, SHIP (and DROP, UNLOAD, BEACON exist but are not used by Foothold), with activate/deactivate at runtime, smoke colour, ship dimensions (`CTLD.lua:483-538`).
- Stock accounting per cargo (`AddStock*`, `RemoveStock*`, `GetStock`, `GetStock0`) and the combined count "stock + in aircraft + alive groups" (`CTLD.lua:9335-9366`).
- Veto hooks before action: `CanGetTroops`, `CanGetCrates`, `CanGetUnits`, `CanBuildCrates`, `CanUnloadAllTroops` (`Moose:77542`, `Moose:78104`, `Moose:78230`, `Moose:79313`, `Moose:79580`).
- FSM events after action: `TroopsPickedUp`, `TroopsDeployed`, `TroopsExtracted`, `GetCrates`, `CratesPickedUp`, `CratesDropped`, `CratesBuildStarted`, `CratesBuild`, `CratesPacked`, `RemoveCratesNearby`, `Loaded`, `HelicopterLost` (`CTLD.lua:6087`, `CTLD.lua:6119`, `CTLD.lua:6964`, `CTLD.lua:7094`, `CTLD.lua:7215`, `CTLD.lua:7520`, `CTLD.lua:8163`, `CTLD.lua:8430`, `CTLD.lua:8535`).
- Build with a timer (`buildtime`), build from a non-player "engineer" group (`_BuildCrates(group, unit, true, true, notifyGroup)`), no-build-in-load-zone rule (`CTLD.lua:159`, `CTLD.lua:153`, `CTLD.lua:3689-3691`).
- Pack a built group back into crates (Pack / Pack and Load / Pack and Remove) (`CTLD.lua:145`, `CTLD.lua:7520-7611`).
- Loading modes: ground load with doors open, hover load window, sling load, DCS dynamic cargo (ground crew, CH-47, C-130J) with `NewDynamicCargo` / `DynamicCargoLoaded` / `DynamicCargoUnloaded` / `DynamicCargoRemoved` events (`CTLD.lua:143-158`, `Moose:83559-83562`).
- Fixed-wing para-drop of troops and crates with minimum height and maximum speed (`CTLD.lua:149-151`).
- Troops extraction (pick deployed troops up again) (`Moose:77729`; relied on by the spy/demolition extraction).
- Dropped troops and built vehicles moving to the nearest MOVE zone within a distance, with a list of formations (`CTLD.lua:162-166`).
- One-step menus with quantity sub-menus, sub-category menus, price label and stock suffix in menu items, per-group locale resolver and overridable text table (`CTLD.lua:133-141`, `CTLD.lua:157`, `CTLD.lua:163`).
- Save/load of dropped troops and built groups to CSV with interval, "inject" API (`InjectTroops`, `InjectVehicles`, `InjectStatics`) and events fired on load (`CTLD.lua:8105-8110`, `CTLD.lua:8161`).
- Smoke/flare nearest zone, smoke own position, radio beacons at zones and droppable beacon with timeout, hover/flight parameter display, cargo and inventory listings (`CTLD.lua:148`, `CTLD.lua:161`, `Moose:81100-81117`).
- Lookup helpers used by Foothold: `IsUnitInZone`, `_FindCratesCargoObject`, `_FindTroopsCargoObject`, `GetGenericCargoObjectFromGroupName`, `IsC130J`, `Loaded_Cargo`, `DroppedTroops`, `Spawned_Cargo`, `C130GetUnits` (`CTLD.lua:6713`, `CTLD.lua:6099`, `CTLD.lua:2822`, `CTLD.lua:7193`, `CTLD.lua:8251-8273`).
- Other Moose classes used around CTLD: `SET_GROUP`, `SET_ZONE` (with its `Trigger` FSM), `SET_CLIENT`, `ZONE` / `ZONE_RADIUS`, `GROUP` routing (`RouteGroundTo`, `Route`, `TaskFunction`), `COORDINATE`, `STORAGE`, `AIRBASE`, `STATIC`, `MESSAGE`, `USERSOUND`, `MENU_GROUP`, `SCHEDULER`, `TIMER`, `UTILS.SpawnFARPAndFunctionalStatics`, `UTILS.SaveToFile` / `LoadFromFile`.

## 26. Zone "regular supply" economy: production, stock, AI dispatch, local recovery

This is the engine-side model behind the `[SUP] n/max` figure of a zone label: every owned zone slowly manufactures "ready supplies", which are spent by players (zone-supply crates, §8), by AI supply flights to other zones, and by the zone's own repair and upgrade jobs.
Manual citations are from `Foothold Manual v2.7.pdf` §3.5 "Supply Missions, Production, and Recovery" (p. 36) and the Config Manager chapter.

### Player view

- Zone label: `[SUP] n/max [■■□□□] p%` while producing, `[Supplies] n/max` when the target is reached, `[Supplies] n` for a zone that holds stock but cannot produce; the bar has 5 cells; BLUE progress is shown in 1 % steps, RED in 10 % steps (`zc2:52471-52491`, `zc2:52433-52441`).
- The label also names the running jobs ("Building: Armor -- 57%", "Repairing", "Training" for infantry) and shows "Resupply!" when a BLUE zone has less ready stock than its remaining work needs (manual p. 30; label builder `_regularSupplyLocalRecoveryLabelText`, `zc2:52575-52635`, not read).
- When the AI is about to send supplies out of a zone, BLUE players standing on the ground in that zone in an aircraft able to carry zone supplies get "<zone>: Supplies are ready and will be dispatched to <target> in 30 seconds." — the window in which they can take the package themselves (`zc2:53746-53793`, `L10N:1650`).
- Loss of an AI supply sortie: "We have lost a supply helicopter / aircraft / convoy from <zone>." (`zc2:54192-54199`, `L10N:2188-2190`).
- RED SAM recovery is announced to BLUE with one of 3 random variants per event: construction started (family, zone, minutes), repair started, completed (`RED_SAM_<EVENT>_<1..3>`, `zc2:53229-53238`, `zc2:53454-53458`).
- `F10 > Stats and Settings > AI Logistics (Currently …)` toggles regular BLUE AI deliveries when `RadioMenuStopSupplies` is true; every BLUE player is told who switched it (`zc2:52108-52160`, `Config:1361-1363`).

### Mission-maker view

| Setting | Default | Meaning | Ref |
|---|---|---|---|
| `NormalSupplyCapacity` | 1 (1–3) | automatic production target of a normal zone | `Config:1286-1289`, `zc2:8484` |
| `WarehouseSupplyCapacity` | 6 (3–6) | automatic production target of a `[WH]` (Logistic Center) zone | `Config:1291-1294`, `zc2:8485` |
| `GlobalSettings.supplyDifficultyScaling = {[1]=1.0, [2]=1.0}` | 1.0 / 1.0 | multiplier on production time and AI supply-mission timers, per side (0.5 = twice as fast) | `Config:1301-1310`, `zc2:52425-52430` |
| `GlobalSettings.repairDifficultyScaling = {[1]=1, [2]=1}` | 1 / 1 | multiplier on repair / rebuild / installation time, per side (floor 0.1) | `Config:1312-1325`, `zc2:8486-8491` |
| `ExtraRedRepairTimeLowPlayerCountPercent` | 0 (0–50) | extra RED repair/build time when fewer than 2 BLUE CAS players are present, applied once at job start | `Config:1327-1332`, `zc2:53254-53256` |
| `PlayerZoneSuppliesConsumeStock` | true | a player pickup removes one ready supply | `Config:1334-1337` |
| `NoAIBlueSupplies` | false | permanently disables regular BLUE AI deliveries (and production in zones that only produce through AI routes) | `Config:1352-1354`, `zc2:52172` |
| `NoAIBlueCapture` | false | no automatic BLUE capture dispatch to neutral zones (PvE) | `Config:1356-1359`, `zc2:54275-54277` |
| `RadioMenuStopSupplies` | false | gives players the AI Logistics toggle | `Config:1361-1363` |
| `pvp_supplies` | true | PvP: when false, AI supplies only run when bought | `Config:320-322`, `zc2:54204-54206` |

Engine constants (set in a `do` block at load, not in the Config): production 20 min per supply in a normal zone and 10 min in a `[WH]` zone, player-priority delay 30 s, max 2 paid deliveries per target zone, local-recovery base 15 min (normal) / 5 min (`[WH]`), repair unit time 1 min (RED) / 2 min (BLUE), sensor unit time 3 min (both), maximum job time 20 min, permit retry 60 s, 2 dispatches per tick (`zc2:8480-8504`).

Timings as the manual states them (p. 36), which match the code above:
- production: one ready supply every 20 minutes in a regular zone, every 10 minutes in a `[WH]` zone, at Supply Speed Scaling 1.00 and full efficiency; missing or damaged upgrade groups add a delay capped at 10 minutes; production pauses when no upgrade group is operational, and stops at the automatic target (not a storage limit);
- BLUE repair/installation: 15-minute base in a regular zone or 5-minute base in a `[WH]` zone, plus 2 minutes per missing normal unit or 3 minutes per missing SR/TR/STR unit; supplies brought by players, CTLD, air-drop, "Add 3 supplies" and "Resupply friendly zone" skip the base time;
- RED repair/installation (PvE): no base time (RED must first receive a delivery), 1 minute per missing normal unit, 3 minutes per missing SR/TR/STR;
- every job is capped at 20 minutes at scaling 1.00, and the cap scales with Repair Time Scaling;
- up to two jobs per zone at once; each BLUE job consumes one stored supply; stock, production progress and job progress survive a restart.

### Mechanism

State per zone (`ZoneCommander` fields): `_regularSupplyStockSide`, `_regularSupplyReady`, `_regularSupplyExpeditedReady` (the part of the ready stock that was brought in rather than produced), `_regularSupplyProgress` (seconds accumulated toward the next supply), `_regularSupplyLastUpdateAt`, `_regularSupplyPendingStock` (ready units reserved by AI dispatch permits), `_regularSupplyEfficiency`, `_regularSupplyLossDelays`, and up to two local-recovery jobs (`zc2:52343-52366`, `zc2:53687-53743`, `zc2:52494`).

**Tick**: `bc:_updateRegularSupplyStock(now)` then `bc:_dispatchRegularSupplyStock(now)` are called once at the start of every zone-update cycle of the `BattleCommander` (`zc2:43251-43252`); there is no dedicated timer.

**Who can store and who can produce** (`_regularSupplyHasRouteForSide`, `zc2:52163-52191`, `zc2:53690-53692`):
- a zone can store when it is active, not hidden, RED or BLUE;
- it can produce when it is a Logistic Center (BLUE, or the owner in PvP), or its name is in the setup's `supplyZones` list, or it owns at least one supply `GroupCommander` of its side that is not shop-only (i.e. it has an AI supply route); with `NoAIBlueSupplies` a BLUE zone of the third kind does not produce.
- When the owner changes (or the zone cannot store) the stock, the expedited part and the progress are reset to 0 (`zc2:53695-53702`).

**Production** (`ZoneCommander:_updateRegularSupplyStock`, `zc2:53713-53741`):
- `interval = baseSeconds × supplyDifficultyScaling[side]`, base 1200 s (normal) or 600 s (Logistic Center) (`zc2:52418-52430`);
- `conditionDelay = 600 s × scale × (1 − efficiency)` and `productionRate = interval / (interval + conditionDelay)`; rate 0 when efficiency is 0;
- `progress += elapsed × productionRate`; each time `progress >= interval` and the stock is below the maximum, one supply becomes ready; progress is zeroed at the maximum.
- Efficiency = operational capacity ÷ number of upgrade slots of the zone, clamped to 0–1 (`_commitRegularSupplyEfficiency`); it is recomputed when the zone is marked dirty (unit lost, upgrade set changed), by code outside the range read (`zc2:52291-52329`).
- Maximum (the automatic target): `WarehouseSupplyCapacity` for a Logistic Center, `NormalSupplyCapacity` otherwise, and a fixed 3 for a PvE RED zone that has an operational warehouse building (`zc2:52332-52341`).

**Adding stock**:
- `_addImportedRegularSupplyStock(n)`: plain +n to the ready stock, **no upper limit** (deliveries may exceed the target; production then stays paused) (`zc2:52343-52358`);
- `_addExpeditedRegularSupplyStock(n)`: the same, and the units are flagged expedited, which makes the job they pay for skip the base time (`zc2:52360-52367`, `zc2:52863-52870`);
- callers: BLUE CTLD crate → expedited (§8), RED CTLD crate → imported (§22), Hercules drop and legacy unload → expedited (§18, §20), shop `zsup3` and scripted `supplies2` → expedited (`zc2:24289`), AI delivery arrival → `_applyRegularSupplyDelivery`.

**AI delivery arrival** (`bc:_applyRegularSupplyDelivery(zone, side, now, paidStockpile)`, `zc2:53286-53310`):
- a paid `supplies2` "stockpile" delivery → +1 expedited;
- BLUE (and RED in PvP) → +1 imported: the delivery only fills the stock, the zone then spends it itself;
- RED in PvE → no stock: the delivery immediately starts a RED recovery job on the first repair candidate, else the first upgrade candidate, else calls `zone:upgrade()`; each successful RED delivery also gives the RED coalition 100 credits.

**Local recovery jobs** (max 2 per zone, `REGULAR_SUPPLY_LOCAL_RECOVERY_MAX_JOBS = 2`):
- candidates (`_regularSupplyLocalRecoveryCandidates`, `zc2:52908-52970`): for each upgrade slot in index order, a built group with missing units is a `repair` (or a `rebuild` if nothing is left of it); a slot not built yet is an `upgrade`; statics, "dismounted" groups and slots already reserved by a job are skipped; "missing" is the template unit count minus the live group size, with sensors (SR/TR/STR) counted apart (`_regularSupplyRepairFacts`, `zc2:52637-52690`);
- choice (`_selectRegularSupplyLocalRecoveryTarget`): with both kinds pending and one job already running, the second job takes the other kind, so a zone repairs and builds in parallel; otherwise repairs first (`zc2:52972-53010`);
- BLUE start (`_startRegularSupplyLocalRecovery`): needs `ready − pending ≥ 1`, a free slot and a target; takes one ready supply (an expedited one first), and creates `{side, action, targetName, targetIndex, durationSec, startedAt, completeAt, usesExpeditedSupply, recoveryBaseSec, showLabel}`; jobs are started automatically at each tick as long as stock and slots allow (`zc2:53180-53227`, `zc2:53660-53679`);
- durations: repair = `min(max × scale, (base + normalMissing × unitSec + missingSensors × sensorSec) × scale)`; construction = the same with every template unit counted; `base` is 0 for an expedited supply and for RED (`zc2:52863-52906`);
- RED start (`_startRedRegularSupplyLocalRecovery`): no stored supply, no label, optional low-player-count surcharge, SAM messages to BLUE (`zc2:53241-53284`);
- finish (`_finishRegularSupplyLocalRecovery`): re-validates the target, then `zone:upgrade(silent, targetName)` for a repair/rebuild or `zone:upgrade(silent, nil, targetIndex)` for an installation; on failure the job is retried later; a BLUE repair whose group has meanwhile been wiped out becomes a rebuild, while a RED repair in the same case is cancelled and needs a new delivery (`zc2:53358-53384`, `zc2:53426-53468`);
- cancellation refunds the supply when the zone is merely suspended or the target vanished, not when the zone changed side (`zc2:53340-53349`, `zc2:53576-53581`);
- jobs are saved and restored with their remaining time (`zc2:53475-53555`).

**AI dispatch** (`bc:_dispatchRegularSupplyStock`, `zc2:54689-55000`):
- it first reconciles permits and runs the local-recovery update, then walks the zones round-robin from a cursor; a source zone qualifies when it holds unreserved ready stock of its own side, AI supply is enabled for that side, and it is active, not suspended, not hidden (`zc2:54690-54716`);
- its usable supply routes (the zone's supply `GroupCommander`s, rotated by a per-zone cursor) become "offers" grouped by target zone (`zc2:54747-54780`);
- target demand = missing upgrade slots + damaged groups (1 for a neutral zone) (`_regularSupplyTargetDemand`, `zc2:54287-54335`);
- target priority = `100 + 45 × missing + 35 × damaged` + 130 if neutral + frontline bonus (80 within 5 NM of the front, 50 within 15, 20 within 30) + waiting time (1 point per 30 s, max 90) − contention (220 + 60 per extra enemy delivery already committed to the same neutral zone) + a Director term (`_regularSupplyTargetPriority`, `zc2:54443-54504`);
- each tick at most `regularSupplyDispatchBudgetPerTick` (2) dispatches are made, picking the best "ticket" = priority + 30 per unfilled unit (max 3) − 70 per dispatch already made to that target this tick (`zc2:54960-55000`, `zc2:8504`);
- `_dispatchRegularSupplyCommander` reserves a **permit** on the group: `{sourceZone, targetZone, side, reservedAt, dispatchAt = now + 30 s, allowSuspendedSource}`, increments the source zone's `_regularSupplyPendingStock`, activates the group's state machine, and notifies the players in the zone (the 30 s window above) (`zc2:54615-54687`, `zc2:54208-54226`);
- a player who takes a crate during the window gets priority: `_consumePlayerRegularSupplyStock` releases as many still-delayed permits of that zone as needed (`zc2:52381-52387`, `zc2:53902-53939`);
- when the group actually launches, `_consumeRegularSupplyPermit` removes one ready supply from the source (an ordinary one first) and stamps the sortie with its origin (`zc2:53941-53967`);
- `_reconcileRegularSupplyPermits` releases a permit more than 60 s past its dispatch time, or whose source/target became invalid (side change, suspension, AI supply switched off, route cut by infrastructure, §28) (`zc2:54247-54285`);
- a lost sortie resets the source zone's production progress to 0; in PvE a lost RED helicopter or convoy also puts that route under a 300 s "loss delay" that starts counting only once the zone has stock again (`_handleRegularSupplySortieLoss`, `_recordRegularSupplyLossDelay`, `zc2:54156-54201`, `zc2:54013-54076`).

### Reproduction notes

- The model is three small pieces: a per-zone production accumulator, a stock with two flavours (produced / brought in), and a reservation ("permit") layer that arbitrates between the AI and the players for the same stock.
- Production cost is O(zones) arithmetic per cycle; dispatch is bounded by the per-tick budget and by the round-robin cursors.
- The asymmetry between sides is deliberate: BLUE zones hold stock and repair themselves from it; PvE RED zones hold (almost) no stock and repair only when a delivery arrives, which is what makes cutting RED supply routes meaningful.
- Hidden dependencies: the upgrade-slot model of a zone (`zone.built`, templates, `zone:upgrade`), the `GroupCommander` state machine for the supply flights, and the Director's priority term.

## 27. The destroyable warehouse building of a zone (`[WH]` static)

### Player view

- A Logistic Center has a physical building, a static named `[WH] <zone>`; the zone label shows `[WH]`, `[WH destroyed]` or `[WH] Repairing n%` (`zc2:46472`, `L10N:1388-1391`).
- While it stands, the zone has the Logistic Center benefits: unlimited weapon stock (§17), the higher supply target and the faster production and repair base times (§26).
- Destroying it (it is a normal target for player weapons, it is added to the target lists of the purchased CAS, bomber and structure-strike flights, and it appears in the JTAC and zone-intel target lists; `zc2:36122-36128`, `zc2:1508-1517`, `zc2:109751-109753`) removes those benefits: the supply stock is cut down to the normal-zone target, and the weapon warehouse becomes finite, reset to 50 of every allowed weapon (150 for rockets) (`zc2:46526-46570`, `zc2:51006-51020`).
- Shop: "Logistic Center [WH]" (`zlogc`, 5000) creates one in a fully upgraded friendly airbase zone; "Repair Logistic Center" (`zwhrepair`, 2000) starts a 30-minute repair: "Warehouse repair started at <zone>. Completion in 30 minutes of mission time.", then "Warehouse repair completed at <zone>. Logistic Center benefits restored." (`zc2:24155-24253`, `L10N:1394-1395`; manual p. 31).
- In PvE the RED Director can buy the same for RED (`redwarehouse`, `redwhrepair`): a RED "rear supply depot" (`Setup:4833-4864`, `zc2:24212-24234`).

### Mechanism

- State: `zone.warehouseFacility = {name = '[WH] <zone>', state = 'operational' | 'destroyed' | 'repairing', placement = {x, z, heading, kind, subZone, reservedSubZones}, object, repairCompleteAt, repairDurationSec, weaponStock}` (`zc2:24176`, `zc2:46385-46406`).
- Spawn: `coalition.addStaticObject(country, {category = 'Fortifications', type = 'af_hq', shape_name = 'syr_af_hq', name, x, y, heading})`, country RUSSIA for RED and USA for BLUE; if a wreck still holds the name it is destroyed first and the spawn is retried at the next update (`zc2:46301-46334`).
- Placement (`_findWarehousePlacement`, `zc2:46108-46299`), for an active airbase zone that is not a carrier:
  - the building footprint is about 100 m × 31 m (local X ±49.8 m, local Z −20.5 m to +10.8 m);
  - first choice: beside a road — a mission-maker hint (a trigger zone named `<zone>-wh`), else the road point nearest to the zone centre, else up to 8 road points cached for the zone's numbered sub-zones; the road direction is estimated from four `land.getClosestPointOnRoads` probes 20 m around the point, and the building is set 28 m back from the road, on either side, with its front wall toward it;
  - every footprint corner must be inside the zone, on `LAND` or `ROAD` surface, not on a road, and the ground height must not vary by more than 2 m;
  - fallback (BLUE only; a RED depot requires a road site): the centre of a free sub-zone, trying 8 headings and keeping the flattest;
  - a candidate is rejected when a living unit, static or scenery object lies within 100 m (`world.searchObjects` sphere), and it "reserves" every spawn sub-zone its footprint overlaps so that no defensive group is later spawned into the building;
  - the chosen placement is cached and saved, so the building comes back at the same spot.
- Purchase (`applyLogisticCenterUpgrade`): the zone must be friendly, active, an airbase, not already a Logistic Center, and fully upgraded (`not zone:canRecieveSupply()`); the static is spawned at once, the label is refreshed 1 s later, and 2 s later `_activateWarehouseFacility` sets `LogisticCenter = true` and adds 500 000 of every weapon to the airbase (`addWarehouseItemsAtZone(zone, side, 500000)`), releases the zone's pending supply permits and announces `WAREHOUSE_LOGISTIC_CENTER_CREATED` (`zc2:24155-24210`, `zc2:46356-46369`).
- Watch (`_updateWarehouseFacility(now)`, called at `zc2:55257` on the zone update path, which runs it only for zones that have a facility, `zc2:55150-55152`): an operational facility whose static no longer exists or has no life left becomes `destroyed`: `LogisticCenter = false`, the ready stock is clamped to the new maximum, surplus AI permits of the zone are released (the latest first), and the weapon inventory is reset by `_resetWarehouseFacilityWeapons` (`zc2:46526-46570`).
- Repair (`applyWarehouseRepair`): `state = 'repairing'`, `repairDurationSec = 1800`; when the time is up the static is respawned and the facility re-activated (`zc2:24236-24253`, `zc2:46572-46580`).
- While destroyed or repairing the zone has a **finite** weapon stock that is captured into the save (`_hasFiniteWarehouseStock`, `weaponStock = WarehousePersistence.CaptureWeapons(storage)`), so the inventory and the building state are saved in the same checkpoint (`zc2:46378-46406`).
- Restart: `_initWarehouseFacility` (called from `ZoneCommander:init`, `zc2:51389`) re-creates an operational building from its saved placement; for a destroyed or repairing one it re-creates the **wreck** by spawning the static and blowing it up with `trigger.action.explosion(point, 50)` after checking that nothing else stands within 50 m; a Logistic Center of an older save without placement gets one computed later, one zone per second (`zc2:46464-46524`, `zc2:46444-46462`).
- A zone that is a Logistic Center by setup (`zones.x.LogisticCenter = true`) gets its facility record created by `_initWarehouseFacility` the same way (`zc2:46470-46473`, `Setup:5921-5934`).

### Reproduction notes

- The building is one static whose life is polled by the owning zone's update; no event is used.
- The hard part is the automatic siting: road-side placement, flatness, clearance, and the reservation of the spawn sub-zones it covers.
- Restoring a destroyed state needs a visible wreck, obtained by spawning and exploding the static, which is only safe on a clear site.

## 28. `TheaterInfrastructure`: a destroyed map building cuts a RED supply route

### Player view

- Each RED SAM zone of the Caucasus campaign is resupplied from one RED base, and that link depends on a warehouse **building of the map** (a scenery object); destroying the building stops RED from resupplying, and therefore repairing, that SAM zone from that base.
- One larger target, the Vaziani supply warehouse, cuts a whole set of routes around Tbilisi and Vaziani; it is offered as a strike mission ("Strike Vaziani", 1000 credits) once BLUE holds Lima while Vaziani is still RED (`Setup:9295-9310`).

### Mission-maker view

`TheaterInfrastructure` is a global list in the setup file; each entry is `{id, flag, effect, side, scope, sourceZone, targetZones}` (`Setup:2271-2360`):

| `id` | `flag` | `effect` | `sourceZone` → `targetZones` |
|---|---|---|---|
| `kobuleti_sam_india_warehouse` | `SamAlphaWarehouse` | `defence_supply` | Kobuleti → SAM-India |
| `sukhumi_sam_foxtrot_warehouse` | `SamDeltaWarehouse` | `defence_supply` | Sukhumi → SAM-Foxtrot |
| `sochi_sam_echo_warehouse` | `SamEchoWarehouse` | `defence_supply` | Sochi → SAM-Echo |
| `anapa_sam_alpha_warehouse` | `SamGolfWarehouse` | `defence_supply` | Anapa → SAM-Alpha |
| `krasnodar_sam_charlie_warehouse` | `SamHotelWarehouse` | `defence_supply` | Krasnodar-Pashkovsky → SAM-Charlie |
| `mineralnye_sam_juliett_warehouse` | `SamJuliettWarehouse` | `defence_supply` | Mineralnye → SAM-Juliett |
| `mozdok_sam_kilo_warehouse` | `SamKiloWarehouse` | `defence_supply` | Mozdok → SAM-Kilo |
| `tbilisi_vaziani_warehouse` | `StrikeVaziani` | `regional_supply` | Tbilisi → Soganlug, Vaziani |
| `vaziani_warehouse` | `StrikeVaziani` | `regional_supply` | Vaziani → Kilo, Lima, Soganlug, Tbilisi, SAM-Lima, SAM-Mike |

- All entries are `side = RED`, `scope = "routes"`; `scope = "source"` (every route leaving the source zone) is also accepted (`zc2:75005-75024`).
- The `flag` is the name of a trigger zone placed on the building in the `.miz`: the setup resolves it with Moose `SCENERY:FindByZoneName(flag)` and reports a missing object at start (`Setup:9004-9038`).
- The Director validates the list at load (unique `id`, non-empty `flag`, valid side and scope, existing source zone, non-empty target list) and raises a Lua error otherwise (`zc2:74986-75035`).

### Mechanism

- A flag becomes true when its target is destroyed: `CustomFlags[flag] = true` is what the mission-target registry sets for a "custom" (one-shot) target, so the cut is permanent and persisted with the campaign (note 05 §11; `Setup:9302`).
- `bc:_ensureRegularSupplyInfrastructureIndex()` indexes the list by source zone and by target zone (`"*"` for `scope = "source"`) (`zc2:53810-53837`).
- `bc:_regularSupplyRouteInfrastructureBlocked(groupCommander)` returns true when an entry for the group's source zone and target zone (or a `"*"` entry) matches the group's side and its flag is set (`zc2:53839-53861`).
- It is consulted when a supply route is evaluated for dispatch, when delayed permits are reconciled, and by the Director when it plans RED supply (`zc2:54549`, `zc2:54262`, `zc2:77962`, `zc2:78094`).
- The same condition is also written directly on the supply capabilities of the setup, e.g. `DirectorCapability:new({name = 'Support-SAM-India', mission = 'supply', targetzone = 'SAM-India', template = 'SupplyConvoy', type = 'surface', condition = function(self) return not (self.side == 1 and CustomFlags["SamAlphaWarehouse"]) end})` (`Setup:1291`, `Setup:1633-1667`).
- Because a PvE RED zone repairs only on delivery (§26), a cut route means the SAM zone stays damaged.

### Reproduction notes

- The feature is a lookup table from "destroyed objective flag" to "blocked supply routes"; the cost is one table lookup per route evaluation.
- It needs scenery objects addressable from the `.miz` (a trigger zone over the building) and a persistent flag store.
- `effect` (`defence_supply` / `regional_supply`) is not used by the route check read here; it is carried into the Director's region catalogue (`zc2:95900`; its use there was not read).

## 29. PvP: industry objectives and starting territory share

### Industry zones (PvP only)

- Five zones of the Caucasus setup are industrial sites whose key buildings are declared as `industryCores` (a set of static names): Mining Facility (Factory, HQ), Insurgent Camp, Secret Tech Facility (Factory, Factory 2, HQ), Ammunition Depot (four storages), Tank Factory (two factories) (`Setup:868-874`).
- Income: at each zone update in PvP, a zone with an `income` and an owner pays that income to its owner's coalition account, unless `productionDisabled` (`zc2:55155-55159`).
- `_observeIndustryCores()` (each update): a core static that no longer exists or has no life left is "retired" for good (added to `zone.retiredStaticUpgrades`, removed from `zone.built`); when no core is alive any more, `zone.productionDisabled = true` and the income stops (`zc2:55109-55144`).
- Cores are excluded from the zone's own repair and rebuild jobs, so a destroyed factory is never rebuilt (`zc2:53013-53016`).
- Strike mission: `MissionCommander:new` builds, per side, an "industry strike" mission from the core statics of type `Workshop A`, `Tech combine` or `Tech hangar A`; a site is eligible when it is enemy-owned and each of its living cores lies within 100 NM of a zone the attacker owns; one eligible site is drawn at random and registered as a static group target `INDUSTRY:<side>:<zone>` worth `min(1000, 300 × number of buildings)`, with the coordinates of every building in the mission text (`zc2:102566-102600`, `zc2:102707-102737`).

### Starting territory share

- `PvPStartingTerritoryPercent` (Config, default 50; allowed 20, 30, 40, 50) is the share of the territory each coalition owns at the start of a new or reset PvP round, the rest being neutral (20 → 20 % RED, 20 % BLUE, 60 % neutral; 50 → everything split) (`Config:313-318`).
- The setup holds an ordered list of zone keys per side (`pvpStartingTerritoryOrder[1]`, `[2]`, nearest to the home base first — ordering principle not read) and computes `quota = round(total zones × percent / 100)`; the first `quota` zones of each list go to that side, the others start neutral (`Setup:5885-5892`).
- The industrial sites are outside the quota and follow a named neighbour: Mining Facility follows Batumi, Secret Tech Facility follows Sukhumi, Insurgent Camp follows India (else Isunderi), Ammunition Depot follows Sochi, Tank Factory follows the zone keyed `krasnodarc` (else `holmskiy`) (`Setup:5893-5898`).
- The value used is stored in `CustomFlags.PvPStartingTerritoryPercent`, so an existing save keeps its layout: saved ownership wins, and only zones absent from the save take the starting layout; `StartNormal` swaps the two sides (`Setup:5877-5884`, `Setup:5900-5908`).
- Anapa and Vaziani start as the two Logistic Centers of a PvP round, with a full supply stock (`Setup:5921-5927`).
- The PvP victory condition is evaluated on a separate list, `pvpVictoryZones` (`Setup:949-955`, `Setup:2738`, `Setup:2836`); that code was not read.

## 30. Train supply and train repair (Normandy)

Not analysed: the upstream source extract was no longer available in the scratchpad when this section was due (the `fh653` folder disappeared during the pass), so `addConnectionSupply` and the `'train'` supply type could not be read in v6.5.3.
Nothing in this section is known from the code; the only fact gathered elsewhere is that the Normandy map has its own supply and attack-front logic in several generators (`zc2:63804-63822`, `zc2:64150-64163`).

## Seen outside this theme

- Pending-capture machinery (`startPendingCapture`, `startPendingCaptureWithCargoStatic`, `registerPendingCaptureHandler`, tombstones): `zc2:46797-46986`, `zc2:24675` — theme 01.
- Zone "regular supply" production, AI dispatch permits and local recovery jobs: now detailed in §26.
- Warehouse **facility** building per zone (`[WH]` static) and the shop items that create and repair a Logistic Center: now detailed in §27.
- Shop items `zwh50`, `farphere` (AI-built FARP, messages `LOGISTICS_FARP_HELO_ENROUTE*`), `supplies2`: `Config:1609-1889` — theme 05.
- Zone intel started by the spy (`startZoneIntel`): `CTLD.lua:1956` — intel theme.
- CSAR / pilot rescue inside `LogisticCommander` (`zc2:98446-100730`, `zc2:101831-102270`) — theme 06.
- Career statistics and contribution/landing reward banking (`bc:addContribution`, `_handleRewardPlayerLanding`, `recordCareerStat`) — theme 05.
- Carrier navigation / carrier respawn that re-stocks carrier warehouses: `zc2:15512-15573`.
- Blue AI flights drawing their loadout from the base warehouse (`_prepareBlueAiWarehouseSpawn`, `BlueAiWarehouseEquipmentByClsid`): `zc2:19599-20072` — theme 03.
- `WarehousePersistence` save/load file format: `zc2:111851-112251` — theme 02.
- Welcome-message script registering new FARP zones (`RegisterWelcomeZone`): `zc2:20122-20124`.
