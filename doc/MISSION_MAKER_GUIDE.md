# Mission Maker Guide

Guide for creating and managing DCS World missions with VEAF scripts.

## Table of Contents

- [What is a VEAF Mission?](#what-is-a-veaf-mission)
- [Prerequisites](#prerequisites)
- [Getting VEAF Scripts](#getting-veaf-scripts)
- [Setting Up a New Mission](#setting-up-a-new-mission)
- [Loading Scripts in DCS](#loading-scripts-in-dcs)
- [Runtime Modules](#runtime-modules)
- [Design-Time Tools](#design-time-tools)
- [Building Your Mission](#building-your-mission)
- [Configuration Reference](#configuration-reference)

---

## What is a VEAF Mission?

A VEAF mission is a standard DCS World `.miz` file that loads the VEAF Lua framework at mission start. This gives players and controllers access to:

- **F10 map marker commands** — type a command on the map and VEAF interprets it (spawn units, create missions, mark positions…)
- **F10 radio menus** — dynamic menus for all VEAF features
- **Pre-built mission types** — CAS, transport, carrier ops, QRA, air waves, combat zones
- **Asset management** — tankers, AWACS, carriers with automatic state tracking
- **Named points** — reusable positions with ATC frequency support

---

## Prerequisites

| Tool | Purpose | Required |
|------|---------|----------|
| DCS World | The sim | ✅ |
| Git | Version control for your mission folder | ✅ |
| `veaf-tools-updater.exe` | Downloads and installs the latest VEAF release | ✅ |
| `veaf-tools.exe` | Build-time mission manipulation CLI | ✅ |

---

## Getting VEAF Scripts

### Initial Installation

Download `veaf-tools-updater.exe` from the [latest GitHub release](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/tag/published-latest), place it in your mission folder, then run:

```powershell
.\veaf-tools-updater.exe
```

This downloads `published.zip`, verifies the SHA256 checksum, and extracts all scripts into your mission folder.

### Staying Up to Date

Run the same command any time a new VEAF release is available:

```powershell
.\veaf-tools-updater.exe
```

For a specific version:

```powershell
.\veaf-tools-updater.exe --tag published-v6.0.5
```

See [TOOLS_REFERENCE.md](TOOLS_REFERENCE.md) for the full `veaf-tools-updater.exe` and `veaf-tools.exe` command reference.

---

## Setting Up a New Mission

### Recommended: Fork the Demo Mission

The fastest way to start is to fork [VEAF-Demo-Mission](https://github.com/VEAF/VEAF-Demo-Mission), which already has:
- The correct folder structure
- A working script injection trigger
- Sample configurations for common modules
- Build scripts

```powershell
git clone https://github.com/VEAF/VEAF-Demo-Mission.git my-mission
cd my-mission
.\veaf-tools-updater.exe
```

### From Scratch

If you start from an existing mission file:

1. Create a folder for your mission project (this is your Git repository)
2. Copy your `.miz` file there
3. Run `veaf-tools-updater.exe` to get all VEAF scripts
4. Add the script loader trigger (see [Loading Scripts in DCS](#loading-scripts-in-dcs))
5. Create a `missionconfig.lua` for your module configuration

---

## Loading Scripts in DCS

VEAF scripts are loaded via a `DO SCRIPT FILE` trigger in the DCS Mission Editor.

### Minimal Trigger Configuration

In the DCS Mission Editor:

1. Add a `MISSION START` trigger
2. Add a `DO SCRIPT FILE` action
3. Point it at `veaf-scripts.lua` in your mission folder

### Script Loading Order

For missions that need granular control:

```lua
-- In a DO SCRIPT action (inline Lua):
dofile(veaf.LuaUtils.joinPath(basePath, "veaf-scripts.lua"))

-- Then your mission config:
dofile(veaf.LuaUtils.joinPath(basePath, "missionconfig.lua"))
```

The `veaf-scripts.lua` file contains all modules concatenated in dependency order. Individual modules can be disabled in `missionconfig.lua`.

---

## Runtime Modules

All these modules are available once `veaf-scripts.lua` is loaded.

### Core

| Module | What it does |
|--------|-------------|
| `veaf` | Core framework, logging, and utility functions |
| `veafMarkers` | Intercepts F10 map markers and dispatches commands |
| `veafInterpreter` | Parses marker text into structured commands |
| `veafRadio` | Manages dynamic F10 radio menus |
| `veafSecurity` | Role-based permissions for VEAF commands |
| `veafNamedPoints` | Named positions with ATC/TACAN services |
| `veafShortcuts` | Shortcut aliases for common commands |
| `veafTime` | Mission time utilities |
| `veafEventHandler` | DCS event listener and dispatcher |
| `veafCacheManager` | Caches expensive computations |

### Spawning

| Module | What it does |
|--------|-------------|
| `veafSpawn` | Spawn aircraft, ground units, smoke, JTAC, cargo, FARP via markers |
| `veafUnits` | Unit template definitions (groups, coalitions, categories) |
| `veafMove` | Move/teleport existing units |
| `veafGroundAI` | Enhanced ground unit AI behavior |

### Mission Types

| Module | What it does |
|--------|-------------|
| `veafCombatMission` | Base class for all mission types |
| `veafCombatZone` | Activatable/deactivatable combat zones with scoring |
| `veafCasMission` | Generated CAS missions with threat packages |
| `veafTransportMission` | Helicopter/transport pickup and delivery missions |
| `veafCarrierOperations` | Carrier recovery (BRC, TACAN, ICLS management) |
| `veafAirWaves` | Recurring air attack waves with wave tracking |
| `veafQraManager` | Quick Reaction Aircraft with state machine |
| `veafSanctuary` | Protected zones that destroy violating units |
| `veafMissileGuardian` | Intercepts specific incoming missiles |

### Assets

| Module | What it does |
|--------|-------------|
| `veafAssets` | Tankers, AWACS, carriers — state tracking and radio menus |
| `veafAirbases` | Airbase data and ATC setup |
| `veafGrass` | Unprepared grass airstrip configuration |
| `veafWeather` | Dynamic weather and ATC conditions |

### Integrations

| Module | What it does |
|--------|-------------|
| `veafRemote` | NIOD/SLMOD remote commands via socket |
| `veafSkynetIadsHelper` | Configures Skynet IADS from VEAF data |
| `veafSkynetIadsMonitor` | Monitors Skynet IADS health and alerts |
| `veafHoundElintHelper` | Integrates with Hound ELINT |

### Enabling / Disabling Modules

In `missionconfig.lua`, call `initialize()` only on the modules you need:

```lua
-- Minimal setup: only markers and spawn
veafMarkers.initialize()
veafSpawn.initialize()

-- Full setup (example)
veafSecurity.initialize()
veafNamedPoints.initialize()
veafMarkers.initialize()
veafSpawn.initialize()
veafAssets.initialize()
veafRadio.initialize()
```

---

## Design-Time Tools

`veaf-tools.exe` manipulates `.miz` files at build time, before loading them in DCS. Run it from your mission folder with the virtual environment activated (if running from source) or directly as `.exe`.

### Available Operations

| Command | What it does |
|---------|-------------|
| `build` | Builds the mission from `src\mission\` and `src\scripts\` — outputs a dated `.miz` |
| `extract` | Extracts a `.miz` to a source folder (run once to initialise your repo) |
| `inject-presets` | Injects radio frequency plans for all human groups |
| `inject-weather` | Inserts real or configured weather |
| `inject-aircraft-groups` | Injects aircraft group templates |
| `extract-aircraft-groups` | Extracts aircraft groups from a mission |
| `inject-waypoints` | Injects waypoints (bullseye, etc.) for human groups |
| `extract-waypoints` | Extracts waypoints from a mission |

Full command reference: [TOOLS_REFERENCE.md](TOOLS_REFERENCE.md)

---

## Building Your Mission

### Typical Build Script

Most VEAF-based mission repositories follow this pattern (e.g., `build.cmd`):

```batch
@echo off
set MISSION_NAME=mission

REM 1. Build the mission (reads src\mission\ + src\scripts\ → mission_YYYYMMDD.miz)
veaf-tools.exe build %MISSION_NAME% .

REM 2. Inject radio presets (optional)
REM veaf-tools.exe inject-presets %MISSION_NAME% --presets-file src\presets.yaml

REM 3. Inject waypoints (optional)
REM veaf-tools.exe inject-waypoints %MISSION_NAME% --waypoints-file src\waypoints.yaml

REM 4. Inject weather variants (optional)
REM veaf-tools.exe inject-weather %MISSION_NAME% --config-file src\missions.yaml
```

### Clean Git Diffs

The `build` command reads from `src\mission\` (a folder of plain-text Lua files) rather than a binary `.miz`. Commit the contents of `src\mission\` to Git — not the `.miz` itself — for readable diffs. Use `extract` once to bootstrap the folder from an existing mission:

```batch
veaf-tools.exe extract my-mission.miz src
```

---

## Configuration Reference

### Module Configuration in missionconfig.lua

Each module exposes configuration constants you can override before calling `initialize()`:

```lua
-- Example: restrict spawn commands to pilots only
veafSecurity.DEFAULT_SECURITY_LEVEL = veafSecurity.SECURITY_LEVEL_FOR_ADMIN

-- Example: set JTAC auto-lase callback
veafSpawn.JTACAutoLase = function(unit)
  return unit:getCoalition() == coalition.side.RED
end

-- Example: configure a QRA
local myQra = VeafQRA:new()
  :setName("QRA-Blue-North")
  :setTriggerZone("ZONE-QRA-NORTH")
  :setCoalition(coalition.side.BLUE)
  :addGroup("F-15C QRA")
  :start()
```

### Log Level Control

#### Global level at build time

`mission.yaml` is an optional file you create manually at the **root of your mission folder** (next to `build.cmd` and `veaf-tools-updater.exe`). It is read by `veaf-tools build` — if it does not exist, the build works without it.

To set the log verbosity for the whole mission, create `mission.yaml` with:

```yaml
global_log_level: debug   # error | warning | info | debug | trace
```

`veaf-tools build` writes `veaf.ForcedLogLevel = "debug"` into the generated `veaf-modules-config.lua`, which overrides every module's log level. This is baked into the `.miz` — changing it requires a rebuild.

> Remove this line (or set it to `info`) before deploying to players.

#### Per-module level at build time

For finer control, configure individual modules via the `lua_modules` section in the same `mission.yaml`:

```yaml
lua_modules:
  SPAWN:
    logLevel: debug
  RADIO:
    logLevel: trace
  ASSETS:
    logLevel: info
```

This generates `veaf.setConfig("SPAWN", "logLevel", "debug")` calls in `veaf-modules-config.lua`. All other modules keep their default level.

Alternatively, use `--log-modules` on the CLI to keep full logging for a set of modules and silence everything else:

```powershell
veaf-tools.exe build mission --log-modules "SPAWN,RADIO"
```

#### Per-module level at runtime (live server)

For changes without a rebuild, set levels directly in your `missionconfig.lua`:

```lua
-- force=true bypasses the BaseLogLevel cap
veaf.loggers.get("SPAWN"):setLevel("debug", true)
veaf.loggers.get("RADIO"):setLevel("trace", true)
```

If your mission loads scripts from the filesystem (`dofile(lfs.writedir() .. "...")`) rather than from inside the `.miz`, editing `missionconfig.lua` on the server and reloading the mission is sufficient.

Log levels: `error` (1) → `warning` (2) → `info` (3, default) → `debug` (4) → `trace` (5).

### Security Levels

VEAF Security restricts commands to players with appropriate roles:

| Level | Constant | Who can use |
|-------|----------|-------------|
| 0 | `SECURITY_LEVEL_FOR_ALL` | All players |
| 1 | `SECURITY_LEVEL_FOR_PILOTS` | Pilots (non-spectators) |
| 2 | `SECURITY_LEVEL_FOR_ADMIN` | Mission admins only |

Players can be granted admin rights via `veafSecurity.addAdmin(playerName)` or through a SLMOD integration.

---

*See also: [USER_GUIDE.md](USER_GUIDE.md) for the player-facing F10 menu and marker command reference, [LUA_API_REFERENCE.md](LUA_API_REFERENCE.md) for the complete Lua API.*
