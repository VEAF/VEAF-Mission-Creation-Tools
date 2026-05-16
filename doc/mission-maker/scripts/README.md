# Scripts Reference — VEAF Lua Modules

All modules are bundled in `veaf-scripts.lua` and loaded at mission start. This page lists every module with its purpose, whether it needs explicit configuration, and links to the detailed guide.

---

## Loading and Initialisation Pattern

Every module follows the same pattern:

```lua
-- Optional: override defaults before initialising
veafModuleName.SomeConstant = value

-- Required: initialise the module
veafModuleName.initialize()

-- Some modules also require a start() call
veafModuleName.start()
```

Modules that are not `initialize()`d consume no resources and create no radio menus.

---

## Core Modules

These modules must always be loaded. They provide infrastructure used by all other modules.

| Module | Version | What it does | Config needed |
|--------|---------|--------------|---------------|
| `veaf.lua` | 1.56+ | Core framework — logging, utilities, mist wrappers | No |
| `veafEventHandler.lua` | — | DCS event listener and dispatcher | No |
| `veafMarkers.lua` | — | Intercepts F10 map marker text and dispatches commands | Minimal |
| `veafInterpreter.lua` | — | Parses marker command text into structured options | No |
| `veafRadio.lua` | — | Builds and refreshes the F10 dynamic radio menu | Minimal |
| `veafCacheManager.lua` | — | Caches expensive computations | No |

Minimal initialisation:

```lua
veafMarkers.initialize()
veafRadio.initialize()
veafRadio.refreshRadioMenu()
```

---

## Spawning and Movement

| Module | File | What it does |
|--------|------|--------------|
| [veafSpawn](veafSpawn.md) | `veafSpawn.lua` | Spawn aircraft, ground units, smoke, JTAC, cargo, convoys, FARPs via markers |
| [veafMove](veafMove.md) | `veafMove.lua` | Move or teleport existing groups; manage tanker routes |
| `veafUnits.lua` | — | Unit template definitions (groups, compositions, era support) |
| `veafGroundAI.lua` | — | Enhanced ground unit AI behaviour |

---

## Mission Types

| Module | File | What it does |
|--------|------|--------------|
| [veafCasMission](veafCasMission.md) | `veafCasMission.lua` | Generated CAS training zones with configurable threat packages |
| [veafCombatZone](veafCombatZone.md) | `veafCombatZone.lua` | Activatable/deactivatable combat zones with objective tracking |
| [veafTransportMission](veafTransportMission.md) | `veafTransportMission.lua` | Helicopter pickup-and-delivery missions |
| [veafQraManager](veafQraManager.md) | `veafQraManager.lua` | Quick Reaction Alert — AI interceptors triggered by intruders |
| [veafAirWaves](veafAirWaves.md) | `veafAirWaves.lua` | Recurring waves of AI attackers with state tracking |
| `veafCombatMission.lua` | — | Base class for mission types (not used directly) |

---

## Assets and Infrastructure

| Module | File | What it does |
|--------|------|--------------|
| [veafAssets](veafAssets.md) | `veafAssets.lua` | Tankers, AWACS, carriers — state tracking and radio menus |
| [veafCarrierOperations](veafCarrierOperations.md) | `veafCarrierOperations.lua` | Carrier recovery management (BRC, TACAN, ICLS, wind alignment) |
| [veafGrass](veafGrass.md) | `veafGrass.lua` | Unprepared grass airstrip configuration |
| [veafWeather](veafWeather.md) | `veafWeather.lua` | Dynamic weather and ATC conditions |
| [veafAirbases](veafAirbases.md) | `veafAirbases.lua` | Airbase data and ATC services |
| [veafNamedPoints](veafNamedPoints.md) | `veafNamedPoints.lua` | Named map positions with optional ATC/TACAN |

---

## Access Control

| Module | File | What it does |
|--------|------|--------------|
| [veafSecurity](veafSecurity.md) | `veafSecurity.lua` | Role-based permission system (passwords, levels) |

---

## Protection Modules

| Module | File | What it does |
|--------|------|--------------|
| [veafSanctuary](veafSanctuary.md) | `veafSanctuary.lua` | Protected zones that automatically destroy intruding units |
| [veafMissileGuardian](veafMissileGuardian.md) | `veafMissileGuardian.lua` | Intercepts specific incoming missiles to protect assets |

---

## Third-Party Integrations

| Module | File | What it does |
|--------|------|--------------|
| [veafSkynetIadsHelper](veafSkynetIadsHelper.md) | `veafSkynetIadsHelper.lua` | Configures Skynet IADS from VEAF group data |
| `veafSkynetIadsMonitor.lua` | — | Monitors Skynet IADS health and sends radio alerts |
| [veafHoundElintHelper](veafHoundElintHelper.md) | `veafHoundElintHelper.lua` | Registers VEAF-spawned units with Hound ELINT |
| `veafRemote.lua` | — | NIOD / SLMOD remote command integration |

---

## Data Modules

These are pure data files — no initialisation needed.

| Module | What it contains |
|--------|-----------------|
| `dcsUnits.lua` | Database of all DCS unit types with attributes |
| `dcsDataExport.lua` | Export utilities for unit data |

---

## Shortcuts

| Module | File | What it does |
|--------|------|--------------|
| `veafShortcuts.lua` | — | Defines short aliases for common marker commands |
| `veafTime.lua` | — | Mission time utilities |

---

## Complete API Reference

For the full public API of every module (functions, parameters, return values, examples), see the [Lua API Reference](../LUA_API_REFERENCE.md).
