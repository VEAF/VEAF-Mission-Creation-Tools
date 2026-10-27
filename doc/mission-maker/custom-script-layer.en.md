# Porting a mission with its own script layer

Some missions do more than use the VEAF modules: they carry a script layer of their own, which drives the objectives, the menus, the persistence, the carriers…
This page says how to plug such a layer into VMCT 6.
The example followed is BFR's (Bullseye Francophone), whose campaigns ran on VMCT 5.103.3 with some twenty `bfr-*.lua` scripts and a `veafPatches.lua` file that replaced about fifteen VMCT functions at load.

The conversion itself is done with `.\veaf-tools.exe convert v5`: see the [Migration Guide](MIGRATION_GUIDE.en.md#own-script-layer), which says what the converter carries on its own.

## Isolate the layer behind a single interface {#one-interface}

The rule that keeps a port short: **one file talks to VEAF**.
At BFR it is `bfr-veaf.lua`: every call into VEAF is wrapped there in a function of the layer (`F.initializeCombatZone()`, `F.namedPointsSet(points)`…), and the other scripts call only those functions.
When VEAF changes, you rewrite the inside of that file, not the twenty others.

What cannot sit behind the interface — the editor's triggers, which call `veafCombatZone.ActivateZone` or `veafShortcuts.ExecuteBatchAliasesList` — should stick to VEAF's stable functions.

## Declare your scripts and your settings {#declare}

- The layer's scripts are declared in [`custom_scripts:`](../MISSION_YAML_REFERENCE.en.md#custom-scripts), **in their load order**: data before engines, the VEAF interface before what calls it.
  They load after `veaf-config.lua` and `mission-script.lua`, so after the modules are configured.
- A module setting written as a literal in a script (`veafRadio.RadioMenuName = "BFR"`) goes to `module_settings:`.
- A setting your script **read from its data** (mission name, export path) goes to `mission.yaml`: `veaf-config.lua` loads before all your scripts and cannot read them.

## Modules the mission starts itself {#initialized-by-mission}

A module declared active in `modules:` is started by the generated `veaf-config.lua`.
If your layer starts it too, it is started **twice**: two Skynet networks, duplicate menus, the carrier loop running again.
Declaring it `false` is no way out for `SKYNET` or `CTLD`: `false` also drops the community script.

The key `initialized_by_mission: true` keeps the script and applies the configuration, but leaves the `initialize()` call to your scripts:

```yaml
modules:
  SHORTCUTS:
    enabled: true
    initialized_by_mission: true   # bfr-raccourcis.lua initializes it
  SKYNET:
    enabled: true
    initialized_by_mission: true   # bfr-iads.lua calls veafSkynet.initialize(...)
    last_line_of_defence: false    # settings still apply
```

It works for any module of `modules:`, and for `SKYNET`, `CTLD` and `CSAR`.
`veaf.initialize()` skips such a module too, if your layer uses it.

## Functions a layer of your own can use {#functions}

| need | v6 |
|---|---|
| carriers without VEAF's 60 s loop | `CARRIER.init.operations_scheduler: false` — see [veafCarrierOperations](scripts/veafCarrierOperations.en.md) |
| no VEAF weather welcome when a slot is taken (the layer has its own) | `WEATHER.welcomeBrief: false` — see [veafWeather](scripts/veafWeather.en.md#welcome-brief) |
| declare a batch of named points from a script | `veafNamedPoints.declarePoints(points)` — see [veafNamedPoints](scripts/veafNamedPoints.en.md#declare-points) |
| an F10 submenu reserved to some groups | `veafRadio.addSubMenuForGroups(title, parent, filter)` — see [veafRadio](scripts/veafRadio.en.md#group-and-pilot-menus) |
| a submenu per pilot in multi-slot groups, answer to the clicking pilot only | `veafRadio.addSubMenuPerPilot(title, parent)` and `veaf.outTextForUnit(unitName, …)` |
| a password-free shortcut that admits a few options | `VeafAlias:setAllowedOptions{…}` — see [veafShortcuts](scripts/veafShortcuts.en.md#bypass-options) |

Per-group F10 commands now follow the pilots present: when a pilot leaves his slot, his wingmen get the group's commands back.
A layer that fixed this itself (BFR replaced `veafRadio.refreshRadioSubmenu`) can drop its fix.

## What changed since v5 {#v5-changes}

| v5 | v6 |
|---|---|
| `veafNamedPoints.Points = {…}` | `veafNamedPoints.declarePoints(points)`, or `NAMEDPOINTS.custom_points` in `mission.yaml` |
| `veafCombatZone.HideZoneNameFromGroupNames` | `mission.hide_names_from_spawned_groups` |
| `veafWeatherAtis.getAtisString` returns a fallback sentence without an ATIS | returns `nil`: accept it |
| VEAF menu labels and messages as text | translation keys; a text that is not a key is shown as is |
| CTLD v1 (`ctld.initialize(callback)`, `ctld.addCallback`) | CTLD 2, configured by `ctld-config.yaml` (see below) |
| `WeatherMark`, `HoundElint`, `Hercules_Cargo` shipped | gone |

The tables BFR reads directly still exist, with the fields it uses: `veafCombatZone.zonesList`, `.rootPath`, `veafRadio.USAGE_ForGroup`, `.humanGroups`, `.radioMenu`, `veafQraManager.qras`, `.STATUS_DEAD`, `veafCarrierOperations.carriers`, `.continueCarrierOperations`.

## Doing without MiST {#mist}

MiST is no longer shipped by default: the build injects it again when one of your scripts writes `mist.`, which works but adds 336 KB to the `.miz`.
VMCT 6 has the equivalents:

| MiST | v6 |
|---|---|
| `mist.scheduleFunction` | `veaf.scheduleFunction` |
| `mist.DBs.humansByName` | `veafMissionDb.getAllHumanRecords()` (dynamic slots included) |
| `mist.DBs.unitsByName` | `veafMissionDb.getAllUnitRecords()` |
| `mist.DBs.groupsByName` | `veafMissionDb.getAllGroupRecords()`, `veaf.getGroupRecord(name)` |
| `mist.DBs.groupsById` | `veafMissionDb.getGroupRecordById(id)` (`coalition` stays `"red"` / `"blue"`) |
| `mist.getGroupRoute(name, "task")`, `mist.goRoute` | `veafDcsSpawner.getGroupRoute(name)`, `veafDcsSpawner.goRoute` |
| `mist.getHeading(unit, true)` | `veafGeo.getHeading` |
| `mist.vec.mag`, `mist.utils.round`, `mist.utils.toDegree` | `veafMath.vecMag`, `veaf.round`, `math.deg` |

**The trap**: a call guarded by `if mist and mist.xxx then` goes quiet **without an error** once MiST is gone.
After replacing, a search for `mist` in `src/scripts` must return nothing, and the build log must no longer say that MiST is injected.

## CTLD 2: what replaces the CTLD v1 reads {#ctld2}

CTLD 2 is no longer configured from a script: its configuration is the mission's `ctld-config.yaml`, edited with `ctld-tools.exe`.
A layer that read CTLD v1's internals goes through its events and its managers:

| CTLD v1 read | CTLD 2 |
|---|---|
| `ctld.builtFOBS`, `buildTimeFOB` | events `OnFOBDeployed`, `OnFOBDestroyed`; `CTLDFOBManager.getInstance():getFOBsForCoalition(coalition)`; the build delay is in `ctld-config.yaml` |
| `ctld.pickupZones` | `CTLDZoneManager.getInstance():getTroopZonesForCoalition(coalition)`, `getTroopZoneAtPoint(point, coalition)`; event `OnTroopZoneUpdated` |
| `ctld.logisticUnits` | `CTLDZoneManager.getInstance():getLogisticZonesForCoalition(coalition)`, `getLogisticZoneAtPoint(point, coalition)`; event `OnLogisticZoneUpdated` |
| `ctld.completeAASystems` | events `OnAASystemDeployed`, `OnAASystemRepaired`, `OnAASystemRearmed` |
| `ctld.addCallback` (player actions) | `EventDispatcher.getInstance():subscribe(name, callback)` on `OnTroopsDeployed`, `OnCrateLoaded`, `OnCrateUnpacked`, `OnVehicleLoaded`, `OnVehicleUnloaded`, `OnJTACSpawned`… |

CTLD 2.0.0-rc13 publishes 47 events; their list is in `CTLD.lua` (`EventDispatcher:publish`).
Each subscriber receives a table describing the action (`carrierUnitName`, `player`, `fob.name`…).
VMCT adds no interface of its own until a BFR need is not covered by those events.

## v6 defaults worth knowing {#v6-defaults}

| change | effect | getting the old behaviour back |
|---|---|---|
| Skynet "last line of defence": each SAM site detects on its own at 10-15 km | flying under the radar cover no longer protects | `SKYNET.last_line_of_defence: false` |
| zone groups that have a route: alarm state AUTO instead of red | convoys and reinforcements start driving | `module_settings: veafCombatZone.DefaultAlarmStateMobile: 2` |
| VEAF weather welcome each time a slot is taken | two welcomes if the layer has its own | `WEATHER.welcomeBrief: false` |
| every airfield becomes a CTLD logistic zone | crates and troops on any field held | `CTLD.manage_airbase_logistics: false` |
| menus paginated beyond 10 entries | long menus split in pages | `veafRadio.doNotPaginate(menu)` |
| VEAF messages in the language of the machine that builds | | an explicit `mission.language` |

## What to test in game {#in-game-checks}

With at least two players in one group:

- the per-pilot F10 menus, then after the group's first pilot leaves;
- a reserved submenu, invisible to the groups it does not admit;
- a full carrier cycle, without a duplicate loop;
- a single welcome when a slot is taken;
- the password-free shortcuts (`-jtac, laser 1511`, `-smoke, color red`), and the refusal of an option they do not admit, on a server;
- the modules declared `initialized_by_mission`: one Skynet network, one menu per module;
- the CTLD actions: FOB, troops, JTAC.
