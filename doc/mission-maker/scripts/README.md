# Scripts Reference — VEAF Lua Modules

All modules are bundled in `veaf-scripts.lua` and loaded at mission start. This page helps you find the right module for your needs.

---

## Find a Module

### By mission-maker workflow

What are you building? Pick the step that matches.

| Step | Modules | Purpose |
|------|---------|---------|
| **Foundation** | `veaf.lua`, `veafMarkers`, `veafRadio`, `veafInterpreter`, `veafEventHandler`, `veafCacheManager` | Core infrastructure (always loaded) |
| **Setup** | [veafSecurity](veafSecurity.md), [veafNamedPoints](veafNamedPoints.md), [veafAirbases](veafAirbases.md) | Access control, map positions, airbase data |
| **Spawning** | [veafSpawn](veafSpawn.md), [veafMove](veafMove.md) | Let players create and move units |
| **Mission types** | [veafCasMission](veafCasMission.md), [veafCombatZone](veafCombatZone.md), [veafTransportMission](veafTransportMission.md), [veafQraManager](veafQraManager.md), [veafAirWaves](veafAirWaves.md) | Structured gameplay scenarios |
| **Assets & services** | [veafAssets](veafAssets.md), [veafCarrierOperations](veafCarrierOperations.md), [veafGrass](veafGrass.md), [veafWeather](veafWeather.md) | Managed tankers/AWACS/carriers, weather |
| **Protection** | [veafMissileGuardian](veafMissileGuardian.md), [veafSanctuary](veafSanctuary.md) | Missile defense, safe zones |
| **Integrations** | [veafSkynetIadsHelper](veafSkynetIadsHelper.md), [veafHoundElintHelper](veafHoundElintHelper.md) | Third-party IADS and ELINT systems |

### By player interaction

What will your players experience?

| Player action | Module | What happens |
|---------------|--------|--------------|
| Places a marker with `_spawn ...` | [veafSpawn](veafSpawn.md) | Units appear at marker position |
| Opens F10 → CAS Mission → Generate | [veafCasMission](veafCasMission.md) | Random target zone generated |
| Opens F10 → Combat Zones → Activate | [veafCombatZone](veafCombatZone.md) | Pre-built combat area activates |
| Opens F10 → Missions → Activate | [veafAirWaves](veafAirWaves.md) | Wave-based air combat starts |
| Opens F10 → Assets → Tanker/AWACS | [veafAssets](veafAssets.md) | Info, respawn, carrier recovery |
| Opens F10 → Carrier → Start Recovery | [veafCarrierOperations](veafCarrierOperations.md) | Carrier turns into wind |
| Enters a protected zone | [veafQraManager](veafQraManager.md) | AI interceptors scramble |
| Types `_auth [password]` | [veafSecurity](veafSecurity.md) | Elevated permissions granted |
| Flies in a sanctuary area | [veafSanctuary](veafSanctuary.md) | Hostile missiles neutralized |

### By frequency of use

How commonly is this module used?

| Frequency | Modules |
|-----------|---------|
| **Essential** (almost every mission) | [veafSpawn](veafSpawn.md), [veafAssets](veafAssets.md), [veafNamedPoints](veafNamedPoints.md), [veafSecurity](veafSecurity.md) |
| **Common** (most combat missions) | [veafCasMission](veafCasMission.md), [veafCombatZone](veafCombatZone.md), [veafAirWaves](veafAirWaves.md), [veafCarrierOperations](veafCarrierOperations.md) |
| **Situational** (specific scenarios) | [veafQraManager](veafQraManager.md), [veafTransportMission](veafTransportMission.md), [veafMove](veafMove.md), [veafGrass](veafGrass.md), [veafWeather](veafWeather.md), [veafAirbases](veafAirbases.md) |
| **Specialized** (advanced setups) | [veafMissileGuardian](veafMissileGuardian.md), [veafSanctuary](veafSanctuary.md), [veafSkynetIadsHelper](veafSkynetIadsHelper.md), [veafHoundElintHelper](veafHoundElintHelper.md) |

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
| [veafShortcuts](veafShortcuts.md) | `veafShortcuts.lua` | Defines short aliases (`-sa6`, `-shilka`, `-destroy`, etc.) for common marker commands — [see full list](veafShortcuts.md#default-aliases-reference) |
| `veafTime.lua` | — | Mission time utilities |

---

## Complete API Reference

For the full public API of every module (functions, parameters, return values, examples), see the [Lua API Reference](../../LUA_API_REFERENCE.md).
