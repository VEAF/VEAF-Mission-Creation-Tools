# Mission Maker Guide — VEAF Mission Creation Tools

> 🇫🇷 [Lire ce guide en français](GUIDE.md)

This guide is for DCS World mission designers who want to integrate the VEAF framework into their missions.

---

## Table of Contents

1. [What You Get](#what-you-get)
2. [Prerequisites](#prerequisites)
3. [Installation and Updates](#installation-and-updates)
4. [Creating a New Mission](#creating-a-new-mission)
5. [Loading Scripts in DCS](#loading-scripts-in-dcs)
6. [Configuring Modules](#configuring-modules)
7. [Design-Time Tools](#design-time-tools)
8. [Typical Build Workflow](#typical-build-workflow)
9. [Scripts Reference](#scripts-reference)
10. [Configuration Examples](#configuration-examples)
11. [Resources](#resources)

> **Migrating an existing mission?** See the [Migration Guide](MIGRATION_GUIDE.md) — covers both VEAF v5 → v6 and vanilla DCS → VEAF.

---

## What You Get

A VEAF mission is a standard DCS `.miz` file that loads the VEAF Lua framework at startup. This gives players and controllers:

- **Marker commands** — players type commands on the F10 map (spawn units, generate CAS zones, move groups…)
- **F10 radio menus** — dynamic menus for every enabled feature
- **Pre-built mission types** — CAS, transport, carrier ops, QRA, air waves, combat zones
- **Asset management** — tankers, AWACS, carriers with automatic state tracking and radio menus
- **Named points** — reusable map positions with optional ATC/TACAN services
- **Integrations** — Skynet IADS, Hound ELINT, CTLD/CSAR

---

## Prerequisites

| Tool | Purpose | Required |
|------|---------|----------|
| DCS World | The simulator | Yes |
| Git | Version control for your mission project | Recommended |
| `veaf-tools-updater.exe` | Downloads and installs the latest VEAF release | Yes |
| `veaf-tools.exe` | Build-time `.miz` manipulation CLI | Yes (for build pipeline) |
| VS Code or similar | Editing Lua/YAML config files | Recommended |

---

## Installation and Updates

### First Installation

Download `veaf-tools-updater.exe` from the [latest GitHub release](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/tag/published-latest) and place it in your mission project folder, then run:

```powershell
.\veaf-tools-updater.exe
```

This downloads `published.zip`, verifies the SHA256 checksum, and extracts all scripts and tools into your mission folder.

### Updating

Run the same command whenever a new release is available:

```powershell
.\veaf-tools-updater.exe
```

Only updates if the remote version is newer. To force a reinstall:

```powershell
.\veaf-tools-updater.exe --force
```

To pin to a specific version:

```powershell
.\veaf-tools-updater.exe --tag published-v6.0.5
```

Full CLI reference: [Tools Reference](../TOOLS_REFERENCE.md)

---

## Creating a New Mission

### Recommended: Fork the Demo Mission

The fastest way to start is to fork [VEAF-Demo-Mission](https://github.com/VEAF/VEAF-Demo-Mission), which already has the correct folder structure, a working script loader trigger, sample configurations, and build scripts.

```powershell
git clone https://github.com/VEAF/VEAF-Demo-Mission.git my-mission
cd my-mission
.\veaf-tools-updater.exe
```

### From Scratch

1. Create a folder for your mission project (this is your Git repository)
2. Copy your existing `.miz` file there
3. Run `veaf-tools-updater.exe` to fetch all VEAF scripts
4. Add the script loader trigger in DCS Mission Editor (see below)
5. Create a `missionconfig.lua` for your module configuration

Recommended project layout:

```
MyMission/
├── src/
│   ├── mission.miz               # Source .miz (unbuilt)
│   ├── scripts/
│   │   └── missionconfig.lua     # Your module configuration
│   ├── presets.yaml              # Radio frequency presets
│   ├── spawnables.yaml           # Predefined spawnable groups
│   └── waypoints.yaml            # Bullseye / navigation points
├── build-scripts/                # VEAF build scripts (auto-installed)
├── veaf-scripts/                 # VEAF Lua scripts (auto-installed)
├── veaf-tools.exe                # CLI tool (auto-installed)
├── veaf-tools-updater.exe
└── build.cmd                     # Your build script
```

---

## Loading Scripts in DCS

VEAF scripts are loaded via a `DO SCRIPT FILE` trigger in the DCS Mission Editor.

### Minimal Setup

In the DCS Mission Editor:

1. Open **Triggers**
2. Add a `MISSION START` trigger
3. Add a `DO SCRIPT FILE` action, pointing to `veaf-scripts.lua` in your mission folder
4. Optionally add a second `DO SCRIPT FILE` action for your `missionconfig.lua`

### Advanced: Inline Loader

For full control over the loading order, use a `DO SCRIPT` action with inline Lua:

```lua
local basePath = lfs.writedir() .. "Missions\\MyMission\\"
dofile(basePath .. "veaf-scripts.lua")
dofile(basePath .. "scripts\\missionconfig.lua")
```

`veaf-scripts.lua` contains all VEAF modules concatenated in dependency order. Your `missionconfig.lua` is loaded after, allowing you to configure and initialize modules.

---

## Configuring Modules

Each VEAF module exposes configuration constants you can set before calling `initialize()`. Your `missionconfig.lua` is where you do this.

### Minimal Configuration

```lua
-- Enable markers and basic spawn
veafMarkers.initialize()
veafSpawn.initialize()
veafRadio.initialize()
veafRadio.refreshRadioMenu()
```

### Full Configuration Example

```lua
-- Security: restrict spawn commands to authenticated users
veafSecurity.initialize()

-- Named points: pre-defined positions
veafNamedPoints.initialize()

-- Markers: intercept F10 map marker text
veafMarkers.initialize()

-- Spawn: allow players to spawn units via markers
veafSpawn.initialize()

-- CAS Mission: training CAS generator
veafCasMission.initialize()
veafCasMission.start()

-- Assets: tankers, AWACS, carriers
veafAssets.Assets = {
  {
    name = "Texaco",
    description = "Texaco (KC-135)",
    groupName = "KC-135 Texaco",
    information = true,
    disposable = false,
  },
  {
    name = "Overlord",
    description = "Overlord (E-3A)",
    groupName = "E-3A Overlord",
    information = true,
    disposable = false,
  },
}
veafAssets.initialize()

-- Radio menu
veafRadio.initialize()
veafRadio.refreshRadioMenu()
```

### Security Levels

| Level | Constant | Who can use |
|-------|----------|-------------|
| 0 (public) | `veafSecurity.LEVEL_L0` | All players |
| 1 (pilots) | `veafSecurity.LEVEL_L1` | Non-spectator pilots |
| 9 (admin) | `veafSecurity.LEVEL_L9` | Authenticated admins |

Set passwords (SHA-1 hashes) in `missionconfig.lua`:

```lua
veafSecurity.password_L9[sha1("yourpassword")] = true
```

---

## Design-Time Tools

`veaf-tools.exe` manipulates `.miz` files at build time — before loading them in DCS.

| Command | What it does |
|---------|-------------|
| `build` | Builds the mission from `src\mission\` and `src\scripts\` — outputs a dated `.miz` |
| `extract` | Extracts a `.miz` to a source folder (run once to initialise your repo) |
| `inject-presets` | Injects radio frequency plans for all human cockpits |
| `inject-weather` | Inserts real or configured weather data |
| `inject-aircraft-groups` | Injects aircraft group templates |
| `extract-aircraft-groups` | Extracts aircraft groups from a mission |
| `inject-waypoints` | Injects waypoints (bullseye, nav points) for human groups |
| `extract-waypoints` | Extracts waypoints from a mission |

Full reference: [Tools Reference](../TOOLS_REFERENCE.md)

---

## Typical Build Workflow

```batch
@echo off
set MISSION_NAME=mission

REM 1. Build the mission (reads src\mission\ + src\scripts\ → mission_YYYYMMDD.miz)
veaf-tools.exe build %MISSION_NAME% .

REM 2. Inject radio presets from YAML config (optional)
REM veaf-tools.exe inject-presets %MISSION_NAME% --presets-file src\presets.yaml

REM 3. Inject bullseye and nav waypoints (optional)
REM veaf-tools.exe inject-waypoints %MISSION_NAME% --waypoints-file src\waypoints.yaml

REM 4. Inject weather variants (optional)
REM veaf-tools.exe inject-weather %MISSION_NAME% --config-file src\missions.yaml
```

Commit the contents of `src\mission\` to Git — not the `.miz` itself. Use `extract` once to bootstrap the folder from an existing mission:

```batch
veaf-tools.exe extract my-mission.miz src
```

---

## Scripts Reference

All VEAF Lua modules are available once `veaf-scripts.lua` is loaded. See [scripts/README.md](scripts/README.md) for the complete list with configuration guides.

**Quick navigation by category:**

| Category | Modules |
|----------|---------|
| Core | [veafSpawn](scripts/veafSpawn.md), [veafMove](scripts/veafMove.md), [veafSecurity](scripts/veafSecurity.md), [veafNamedPoints](scripts/veafNamedPoints.md) |
| Mission types | [veafCasMission](scripts/veafCasMission.md), [veafCombatZone](scripts/veafCombatZone.md), [veafTransportMission](scripts/veafTransportMission.md), [veafQraManager](scripts/veafQraManager.md), [veafAirWaves](scripts/veafAirWaves.md) |
| Assets | [veafAssets](scripts/veafAssets.md), [veafCarrierOperations](scripts/veafCarrierOperations.md), [veafGrass](scripts/veafGrass.md), [veafWeather](scripts/veafWeather.md) |
| Protection | [veafSanctuary](scripts/veafSanctuary.md), [veafMissileGuardian](scripts/veafMissileGuardian.md) |
| Integrations | [veafSkynetIadsHelper](scripts/veafSkynetIadsHelper.md), [veafHoundElintHelper](scripts/veafHoundElintHelper.md) |

---

## Configuration Examples

### QRA Zone

```lua
local northQra = VeafQRA:new()
  :setName("QRA-North")
  :setZone("ZONE-QRA-NORTH")
  :setCoalition(coalition.side.RED)
  :setGroups({ "MiG-29 QRA" })
  :setRearmTime(600)
  :initialize()
```

### Combat Zone

```lua
local strikeZone = VeafCombatZone:new()
  :setName("Strike Alpha")
  :setZoneName("ZONE-STRIKE-ALPHA")
  :setDescription("Armoured column advancing on Senaki")
  :addElement(VeafCombatZoneElement:new():setGroupName("STRIKE-ALPHA-ARMOR"))
  :addElement(VeafCombatZoneElement:new():setGroupName("STRIKE-ALPHA-AAA"))
  :setBriefing("Destroy all armoured vehicles. Expect AAA.")
  :initialize()
```

### Air Waves Zone

```lua
local defenseZone = AirWaveZone:new()
  :setName("AW-Defense")
  :setZoneName("ZONE-DEFENSE")
  :setDescription("Intercept zone")
  :addWave({ "MiG-23 Wave 1", "MiG-23 Wave 1b" })
  :addWave({ "MiG-29 Wave 2" })
  :setMinimumPlayersForWave(1)
  :initialize()
```

---

## Resources

- [Scripts Reference](scripts/README.md) — all scripts with configuration details
- [Tools Reference](../TOOLS_REFERENCE.md) — `veaf-tools.exe` CLI full reference
- [Lua API Reference](../LUA_API_REFERENCE.md) — complete Lua API documentation
- [VEAF Demo Mission](https://github.com/VEAF/VEAF-Demo-Mission) — working example mission
- [VEAF Discord](https://www.veaf.org/discord) — community help
