# Scripts Reference — VEAF Lua Modules

All modules are bundled in `veaf-scripts.lua` and loaded at mission start. This page helps you find the right module for your needs.

---

## Find a Module

### By mission-maker workflow

What are you building? Pick the step that matches.

| Step | Modules | Purpose |
|------|---------|---------|
| **Foundation** | `veaf.lua`, `veafMarkers`, [veafRadio](veafRadio.en.md), [veafInterpreter](veafInterpreter.en.md), [veafCommands](veafCommands.en.md), [veafI18n](veafI18n.en.md), [veafUnits](veafUnits.en.md), `veafEventHandler`, `veafCacheManager` | Core infrastructure (always loaded) |
| **Setup** | [veafSecurity](veafSecurity.en.md), [veafNamedPoints](veafNamedPoints.en.md), [veafAirbases](veafAirbases.en.md) | Access control, map positions, airbase data |
| **Spawning** | [veafSpawn](veafSpawn.en.md), [veafMove](veafMove.en.md), [veafGroundAI](veafGroundAI.en.md) | Let players create, move and drive units |
| **Mission types** | [veafCasMission](veafCasMission.en.md), [veafCombatMission](veafCombatMission.en.md), [veafCombatZone](veafCombatZone.en.md), [veafTransportMission](veafTransportMission.en.md), [veafQraManager](veafQraManager.en.md), [veafAirWaves](veafAirWaves.en.md) | Structured gameplay scenarios |
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
| Opens F10 → Combat Zones → Activate zone | [veafCombatZone](veafCombatZone.en.md) | Pre-built combat area activates |
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

## A misspelt option is refused, not ignored {#unknown-options}

When a marker command carries an option no rule recognises — almost always a typo — the command is **refused** and the option is named back to you, with a suggestion when it is close to a real one:

```
_spawn group, name sa6, headng 270
      ↓
VEAF SPAWN: unknown parameter(s), command aborted: 'headng' (did you mean 'heading'?)
```

Refusing rather than running is deliberate: an unknown option does nothing, so the command would spawn or move something other than what you asked for, and nothing would tell you. The marker is left in place — fix it and drop it again.

Applies to the **`SPAWN`, `CASMISSION`, `MOVE`, `RADIO`, `TRANSPORTMISSION`, `GROUNDAI`** commands, artillery orders included. The name shown is the one the module also uses to prefix its DCS log lines, so the message and the log line up.

!!! note "Aliases are excluded"
    An alias (`-sa6`, `-samsr`) carries the parameters of the command it expands into rather than its own, so checking there would warn about perfectly valid options. A typo inside an alias is caught by the final command instead.

!!! tip "Artillery orders: the separator is a semicolon"
    An artillery order travels as the **value** of an `order` key, inside a marker that is already split on commas — hence the `;`: `aim; shells 10; radius 50`. Use a comma and the check now tells you, instead of silently losing the rest of the order.

## Shortcuts

| Module | File | What it does |
|--------|------|--------------|
| [veafShortcuts](veafShortcuts.en.md) | `veafShortcuts.lua` | Defines short aliases (`-sa6`, `-shilka`, `-destroy`, etc.) for common marker commands — [see full list](veafShortcuts.en.md#default-aliases-reference) |
| `veafTime.lua` | — | Mission time utilities |

---

## Complete API Reference

For the full public API of every module (functions, parameters, return values, examples), see the [Lua API Reference](../../LUA_API_REFERENCE.en.md).
