# Scripts Reference — VEAF Lua Modules

All modules are bundled in `veaf-scripts.lua` and loaded at mission start. This page helps you find the right module for your needs.

---

## Find a Module

### By mission-maker workflow

What are you building? Pick the step that matches.

| Step | Modules | Purpose |
|------|---------|---------|
| **Foundation** | `veaf.lua`, `veafMarkers`, [veafRadio](veafRadio.en.md), `veafInterpreter`, `veafEventHandler`, `veafCacheManager` | Core infrastructure (always loaded) |
| **Setup** | [veafSecurity](veafSecurity.en.md), [veafNamedPoints](veafNamedPoints.en.md), [veafAirbases](veafAirbases.en.md) | Access control, map positions, airbase data |
| **Spawning** | [veafSpawn](veafSpawn.en.md), [veafMove](veafMove.en.md) | Let players create and move units |
| **Mission types** | [veafCasMission](veafCasMission.en.md), [veafCombatZone](veafCombatZone.en.md), [veafTransportMission](veafTransportMission.en.md), [veafQraManager](veafQraManager.en.md), [veafAirWaves](veafAirWaves.en.md) | Structured gameplay scenarios |
| **Assets & services** | [veafAssets](veafAssets.en.md), [veafCarrierOperations](veafCarrierOperations.en.md), [veafGrass](veafGrass.en.md), [veafWeather](veafWeather.en.md) | Managed tankers/AWACS/carriers, weather |
| **Protection** | [veafMissileGuardian](veafMissileGuardian.en.md), [veafSanctuary](veafSanctuary.en.md) | Missile defense, safe zones |
| **In-flight assistance** | [veafAssist](veafAssist.en.md) | Guided checklists: the mission boxes the right switch in the cockpit and ticks the line |
| **Integrations** | [veafSkynetIadsHelper](veafSkynetIadsHelper.en.md) | Third-party IADS systems |

### By player interaction

What will your players experience?

| Player action | Module | What happens |
|---------------|--------|--------------|
| Places a marker with `_spawn ...` | [veafSpawn](veafSpawn.en.md) | Units appear at marker position |
| Places a marker with `_cas` | [veafCasMission](veafCasMission.en.md) | Random target zone generated |
| Opens F10 → Combat Zones → Activate | [veafCombatZone](veafCombatZone.en.md) | Pre-built combat area activates |
| Enters an air-waves zone | [veafAirWaves](veafAirWaves.en.md) | Wave-based air combat starts |
| Opens F10 → ASSETS → [asset] | [veafAssets](veafAssets.en.md) | Info, respawn |
| Opens F10 → CARRIER OPS → Start carrier air operations for 45 minutes | [veafCarrierOperations](veafCarrierOperations.en.md) | Carrier turns into wind |
| Enters a protected zone | [veafQraManager](veafQraManager.en.md) | AI interceptors scramble |
| Types `_auth elevate` | [veafSecurity](veafSecurity.en.md) | The group rises to the requester's level for 2 minutes |
| Flies in a sanctuary area | [veafSanctuary](veafSanctuary.en.md) | Hostile missiles neutralized |

### By frequency of use

How commonly is this module used?

| Frequency | Modules |
|-----------|---------|
| **Essential** (almost every mission) | [veafSpawn](veafSpawn.en.md), [veafAssets](veafAssets.en.md), [veafNamedPoints](veafNamedPoints.en.md), [veafSecurity](veafSecurity.en.md) |
| **Common** (most combat missions) | [veafCasMission](veafCasMission.en.md), [veafCombatZone](veafCombatZone.en.md), [veafAirWaves](veafAirWaves.en.md), [veafCarrierOperations](veafCarrierOperations.en.md) |
| **Situational** (specific scenarios) | [veafQraManager](veafQraManager.en.md), [veafTransportMission](veafTransportMission.en.md), [veafMove](veafMove.en.md), [veafGrass](veafGrass.en.md), [veafWeather](veafWeather.en.md), [veafAirbases](veafAirbases.en.md) |
| **Specialized** (advanced setups) | [veafMissileGuardian](veafMissileGuardian.en.md), [veafSanctuary](veafSanctuary.en.md), [veafSkynetIadsHelper](veafSkynetIadsHelper.en.md) |

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

## Access Control

| Module | File | Role |
|--------|------|------|
| [veafSecurity](veafSecurity.en.md) | `veafSecurity.lua` | Role-based permission system (passwords, levels) |

---

## Protection Modules

| Module | File | What it does |
|--------|------|--------------|
| [veafSanctuary](veafSanctuary.en.md) | `veafSanctuary.lua` | Protected zones that automatically destroy intruding units |
| [veafMissileGuardian](veafMissileGuardian.en.md) | `veafMissileGuardian.lua` | Intercepts specific incoming missiles to protect assets |

---

## Third-Party Integrations

| Module | File | What it does |
|--------|------|--------------|
| [veafSkynetIadsHelper](veafSkynetIadsHelper.en.md) | `veafSkynetIadsHelper.lua` | Configures Skynet IADS from VEAF group data |
| `veafSkynetIadsMonitor.lua` | — | Monitors Skynet IADS health and sends radio alerts |
| `veafRemote.lua` | — | NIOD / SLMOD remote command integration |

---

## Server administration

| Component | File | What it does |
|-----------|------|--------------|
| [veafServerHook](veafServerHook.en.md) | `VEAF-Server-hook.lua` | Dedicated-server hook: chat commands (`/send`, `/pause`…), pilots list, opt-in restart/telemetry |

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
| [veafShortcuts](veafShortcuts.en.md) | `veafShortcuts.lua` | Defines short aliases (`-sa6`, `-shilka`, `-destroy`, etc.) for common marker commands — [see full list](veafShortcuts.en.md#default-aliases-reference) |
| `veafTime.lua` | — | Mission time utilities |

---

## Complete API Reference

For the full public API of every module (functions, parameters, return values, examples), see the [Lua API Reference](../../LUA_API_REFERENCE.en.md).
