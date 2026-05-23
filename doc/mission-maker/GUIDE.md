# Mission Maker Guide — VEAF Mission Creation Tools


This guide is for DCS World mission designers who want to integrate the VEAF framework into their missions.

---

## Table of Contents

1. [What You Get](#what-you-get)
2. [Prerequisites](#prerequisites)
3. [Installation and Updates](#installation-and-updates)
4. [Global User Configuration](#global-user-configuration)
5. [Creating a New Mission](#creating-a-new-mission)
6. [How Scripts Are Loaded](#how-scripts-are-loaded)
7. [Configuring Modules](#configuring-modules)
8. [Design-Time Tools](#design-time-tools)
9. [Typical Build Workflow](#typical-build-workflow)
10. [Scripts Reference](#scripts-reference)
11. [Configuration Examples](#configuration-examples)
12. [Resources](#resources)

> **Migrating an existing mission?** See the [Migration Guide](MIGRATION_GUIDE.md) — covers both VEAF MCT v5 → v6 and vanilla DCS → VEAF MCT.

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
| `veaf-tools-updater.exe` | Downloads and installs the latest VEAF MCT release | Yes |
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
.\veaf-tools-updater.exe --tag published-v6.1.0
```

Full CLI reference: [Tools Reference](../TOOLS_REFERENCE.md)

---

## Global User Configuration

Create `~/veafmct.yaml` (i.e. `C:\Users\YourName\veafmct.yaml` on Windows) to set persistent defaults that apply to **all** your VEAF projects on this machine:

```yaml
# ~/veafmct.yaml
lang: fr                 # Tool output language: "en" (default) or "fr"
check_updates: true      # Check for new veaf-tools releases at startup
scripts_path: D:/dev/_VEAF/VEAF-Mission-Creation-Tools   # Local repo path (for --dev-mode)
```

All keys are optional. To initialise the file from the CLI:

```powershell
veaf-tools.exe user-config --init
```

Or inspect/edit values interactively:

```powershell
# Show effective configuration and its source
veaf-tools.exe user-config

# Set a value
veaf-tools.exe user-config --set lang=fr

# Remove a value (revert to default)
veaf-tools.exe user-config --unset lang
```

**Language detection order** (first match wins):
1. `--lang` CLI option
2. `VEAF_LANG` environment variable
3. `~/veafmct.yaml` → `lang:` key
4. OS locale (Windows registry / system locale on Linux–macOS)
5. `en` (built-in fallback)

---

## Creating a New Mission

### Recommended: Fork the Demo Mission

The fastest way to start is to fork [VEAF-Demo-Mission](https://github.com/VEAF/VEAF-Demo-Mission), which already has the correct folder structure, sample configurations, and build scripts.

```powershell
git clone https://github.com/VEAF/VEAF-Demo-Mission.git my-mission
cd my-mission
.\veaf-tools-updater.exe
```

### From Scratch

1. Create a folder for your mission project (this is your Git repository)
2. Copy your existing `.miz` file there
3. Run `veaf-tools-updater.exe` to fetch all VEAF scripts
4. Extract your mission: `veaf-tools.exe extract my-mission.miz`
5. Configure modules in `mission.yaml` and optionally `src/scripts/missionConfig.lua`

Recommended project layout:

```
MyMission/
├── src/
│   ├── mission/                  # Extracted DCS mission data (from extract)
│   ├── scripts/
│   │   └── missionConfig.lua    # Your runtime Lua configuration (optional)
│   ├── presets.yaml             # Radio frequency presets
│   ├── spawnables.yaml          # Predefined spawnable groups
│   └── waypoints.yaml           # Bullseye / navigation points
├── published/                    # VEAF scripts & tools (auto-installed)
├── mission.yaml                  # Build-time configuration
├── veaf-tools.exe                # CLI tool (auto-installed)
└── veaf-tools-updater.exe
```

---

## How Scripts Are Loaded

The `build` command **automatically injects** a `DO SCRIPT FILE` trigger at mission start that loads all VEAF scripts. You do **not** need to manually add any trigger in the DCS Mission Editor.

If you have a custom `src/scripts/missionConfig.lua`, it is also injected automatically by the builder.

### What the builder does

1. Reads `src/mission/` (the extracted DCS data)
2. Removes any existing VEAF triggers
3. Injects fresh `DO SCRIPT FILE` triggers for all VEAF scripts + your custom scripts
4. Writes the final `.miz`

---

## Configuring Modules

VEAF MCT has two configuration layers:

- **`mission.yaml`** (at the project root) — build-time configuration: which modules to enable/disable, log levels, security settings, asset declarations
- **`src/scripts/missionConfig.lua`** (optional) — runtime Lua code that runs at mission start, for advanced setup like custom aliases, QRA zones, combat zones, etc.

For most missions, `mission.yaml` is sufficient. Use `missionConfig.lua` only when you need Lua-level control.

### mission.yaml Example

```yaml
mission:
  name: "My-Mission"

lua_modules:
  SECURITY:
    enable: true
  SPAWN:
    logLevel: debug
  ASSETS:
    enable: true
    assets:
      - sort: 1
        name: "T1-Arco-1"
        description: "Arco-1 (KC-135)"
        information: "Tacan 64Y\nU290.50 (20)"
```

### missionConfig.lua Example (advanced)

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
veafSecurity.password_L9[sha1.hex("yourpassword")] = true
```

---

## Design-Time Tools

`veaf-tools.exe` manipulates `.miz` files at build time — before loading them in DCS.

| Command | What it does |
|---------|-------------|
| `build` | Builds the mission from `src/` — injects VEAF triggers, outputs a `.miz` |
| `extract` | Extracts a `.miz` to a source folder (run once to initialise your repo) |
| `inject-presets` | Injects radio frequency plans for all human cockpits |
| `inject-weather` | Creates weather/time variants from a YAML config |
| `inject-aircraft-groups` | Injects aircraft group templates |
| `extract-aircraft-groups` | Extracts aircraft groups from a mission |
| `inject-waypoints` | Injects waypoints (bullseye, nav points) for human groups |
| `extract-waypoints` | Extracts waypoints from a mission |
| `convert` | Converts a vanilla mission to VEAF MCT format |
| `convert-v5` | Migrates a v5 mission folder to v6 format |
| `user-config` | Shows or edits the global user config (`~/veafmct.yaml`) |

Full reference: [Tools Reference](../TOOLS_REFERENCE.md)

---

## Typical Build Workflow

```powershell
# 1. Build the mission (reads src/ folder, injects VEAF triggers → output .miz)
veaf-tools.exe build my-mission.miz

# 2. Inject radio presets from YAML config (optional, operates on the built .miz)
veaf-tools.exe inject-presets my-mission.miz --presets-file src/presets.yaml

# 3. Inject bullseye and nav waypoints (optional)
veaf-tools.exe inject-waypoints my-mission.miz --waypoints-file src/waypoints.yaml

# 4. Create weather/time variants (optional)
veaf-tools.exe inject-weather my-mission.miz --config-file missions.yaml
```

Commit the contents of `src/` to Git — not the built `.miz`. Use `extract` once to bootstrap the source folder from an existing mission:

```powershell
veaf-tools.exe extract my-mission.miz
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
