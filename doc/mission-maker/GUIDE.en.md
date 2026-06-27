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
10. [Build Profiles](#build-profiles)
11. [Scripts Reference](#scripts-reference)
12. [Configuration Examples](#configuration-examples)
13. [CTLD and CSAR Integration](#ctld-and-csar-integration)
14. [DCS Bridge](#dcs-bridge)
15. [Debug Logging](#debug-logging)
16. [Resources](#resources)

> **Migrating an existing mission?** See the [Migration Guide](MIGRATION_GUIDE.md) — covers both VEAF MCT v5 → v6 and vanilla DCS → VEAF MCT.

---

## What You Get

A VEAF mission is a standard DCS `.miz` file that loads the VEAF Lua framework at startup. This gives players and controllers:

- **Marker commands** — players type commands on the F10 map (spawn units, generate CAS zones, move groups…)
- **F10 radio menus** — dynamic menus for every enabled feature
- **Pre-built mission types** — CAS, transport, carrier ops, QRA, air waves, combat zones
- **Asset management** — tankers, AWACS, carriers with automatic state tracking and radio menus
- **Named points** — reusable map positions with optional ATC/TACAN services
- **Integrations** — Skynet IADS, CTLD/CSAR

---

## Prerequisites

| Tool | Purpose | Required |
|------|---------|----------|
| DCS World | The simulator | Yes |
| DCS Mission Editor | Create the base `.miz` (included with DCS) | Yes |
| Git | Version control for your mission project | Recommended |
| `veaf-tools-updater.exe` | Downloads and installs the latest VEAF MCT release | Yes |
| `veaf-tools.exe` | Build-time `.miz` manipulation CLI | Yes (for build pipeline) |
| VS Code or Notepad++ | Editing Lua/YAML config files | Recommended |

> **Base mission coalitions**: each side coalition (blue/red) needs at least one ground unit, otherwise its Lua coalition tables are incomplete and DCS purges the empty side — which used to require placing one blue and one red ground group by hand. **The build now handles this for you**: if a side coalition has no unit, it injects a single *hidden* placeholder ground unit (on the coalition bullseye) so DCS registers the side. You can still place your own ground groups — the placeholder is only added when a side is empty.

---

## Installation and Updates

### First Installation

Download `veaf-tools-updater.exe` from the [latest GitHub release](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/tag/published-latest) and place it in your mission project folder.

> **Windows security:** Windows may block `.exe` files downloaded from the internet. If the file doesn't run, right-click it → **Properties** → **General** tab → check **Unblock** at the bottom → **OK**.

Then run:

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
5. Configure modules in `mission.yaml` and optionally `src/scripts/mission-script.lua`

Recommended project layout:

```
MyMission/
├── src/
│   ├── mission/                  # Extracted DCS mission data (from extract)
│   ├── scripts/
│   │   ├── mission-script.lua    # Your custom Lua code (optional)
│   │   └── veafDynamicConfig.lua # Dynamic script-loading config (dev/test)
│   ├── options                  # DCS options table injected into the .miz
│   ├── presets.yaml             # Radio frequency presets (presets step)
│   ├── spawnables.yaml          # Spawnable aircraft groups (veafSpawn- prefix, spawnable_aircrafts step)
│   ├── dynamic-slot-templates.yaml # Dynamic-Slot templates (dynSpawnTemplate=true, dynamic_slot_templates step)
│   ├── warehouses.yaml          # Per-coalition Dynamic Slots (warehouses step, optional)
│   ├── spawn-groups.yaml        # Extend/override the spawn database (spawn_data step, optional)
│   ├── versions.yaml            # Weather/time variants (weather step)
│   └── waypoints.yaml           # Bullseye / navigation points (waypoints step)
├── published/                    # VEAF scripts & tools (auto-installed)
├── mission.yaml                  # Build-time configuration
├── .gitignore                    # Excludes generated/downloaded files
├── veaf-tools.exe                # CLI tool (auto-installed)
└── veaf-tools-updater.exe
```

> Every file listed under `src/` (except the `mission/` extract output) ships from
> the tool's `defaults/mission-folder/` scaffold and is consumed at the first
> build — the `*.yaml` files by their pipeline/module step, `options` by `.miz`
> injection, and the `scripts/*.lua` files by script loading.

---

## How Scripts Are Loaded

The `build` command **automatically injects** a `DO SCRIPT FILE` trigger at mission start that loads all VEAF scripts. You do **not** need to manually add any trigger in the DCS Mission Editor.

If you have a custom `src/scripts/mission-script.lua`, it is also injected automatically by the builder.

### What the builder does

1. Reads `src/mission/` (the extracted DCS data)
2. Removes any existing VEAF triggers
3. Injects fresh `DO SCRIPT FILE` triggers for all VEAF scripts + your custom scripts
4. Writes the final `.miz`

The full build then runs any optional pipeline steps whose configuration files are present (presets, waypoints, aircraft groups, weather):

```mermaid
flowchart TD
    subgraph Inputs
        YAML[mission.yaml]
        SRC[src/mission + src/scripts]
        LUA[VEAF Lua scripts]
    end
    YAML --> BUILD[veaf-tools build]
    SRC --> BUILD
    LUA --> BUILD
    BUILD --> GEN[Generate veaf-config.lua from mission.yaml]
    GEN --> TRIG[Inject DO SCRIPT FILE triggers]
    TRIG --> PIPE{Optional pipeline steps}
    PIPE -->|presets.yaml| P1[inject-presets]
    PIPE -->|waypoints.yaml| P2[inject-waypoints]
    PIPE -->|spawnables.yaml| P3[inject spawnable aircraft]
    PIPE -->|dynamic-slot-templates.yaml| P3b[inject Dynamic-Slot templates]
    PIPE -->|warehouses.yaml| P5[wire Dynamic Slots]
    PIPE -->|spawn-groups.yaml| P6[inject spawn data]
    PIPE -->|versions.yaml| P4[inject-weather]
    P1 --> OUT[Final .miz ready to fly]
    P2 --> OUT
    P3 --> OUT
    P3b --> OUT
    P5 --> OUT
    P6 --> OUT
    P4 --> OUT
```

> **Note — templates and multiplayer slots**: the groups injected from `spawnables.yaml` and `dynamic-slot-templates.yaml` are reusable **templates**. To keep them from showing up as pickable slots in the multiplayer briefing, the build automatically hides them from the slot list (`hiddenOnPlanner`/`hiddenOnMFD`) and locks them with a password. Dynamic-slot spawning (which references the template by name) stays fully functional.

---

## Configuring Modules {#configuring-modules}

VEAF MCT has two configuration layers:

- **`mission.yaml`** (at the project root) — build-time configuration: which modules to enable/disable, log levels, security settings, asset declarations
- **`src/scripts/mission-script.lua`** (optional) — custom Lua code that runs at mission start: aliases, helper functions, third-party script setup (CTLD, CSAR). Module initialization and configuration are generated automatically from `mission.yaml`.

For most missions, `mission.yaml` is sufficient. Use `mission-script.lua` only for custom Lua code that cannot be expressed in YAML.

### mission.yaml Example

```yaml
mission:
  name: "My-Mission"

modules:
  SECURITY: true        # shorthand: just enable the module
  SPAWN:
    logLevel: debug     # a module with extra config uses a block
  ASSETS:
    enabled: true
    assets:
      - sort: 1
        name: "T1-Arco-1"
        description: "Arco-1 (KC-135)"
        information: "Tacan 64Y\nU290.50 (20)"
```

> The unified `modules:` block replaces the older `lua_modules:` + `community_scripts:` keys, and `enabled:` replaces `enable:`. The legacy keys still work but emit a deprecation warning. See the [mission.yaml Reference](../MISSION_YAML_REFERENCE.md) for the full syntax.

### mission-script.lua Example

```lua
-- mission-script.lua — custom mission-level code
-- Module initialization is handled automatically by veaf-config.lua (generated from mission.yaml).
-- Put custom aliases, helper functions, and third-party script setup here.

-- Example: custom shortcut alias
-- veafShortcuts.AddAlias(VeafAlias:new():setName("-cas1"):setVeafCommand("_cas"))

-- Example: CTLD third-party integration (see CTLD and CSAR Integration for full details)
-- if ctld then ctld.initialize(function()
--     -- ctld.hoverPickup = false
-- end) end
```

### Security Levels

| Level | Constant | Who can use |
|-------|----------|-------------|
| 0 (public) | `veafSecurity.LEVEL_L0` | All players |
| 1 (pilots) | `veafSecurity.LEVEL_L1` | Non-spectator pilots |
| 9 (admin) | `veafSecurity.LEVEL_L9` | Authenticated admins |

Set passwords (SHA-256 hashes) in `mission.yaml`:

```yaml
security:
  disabled: false
  password_hashes:
    - "<SHA-256 hash of your password>"
```

---

## Design-Time Tools

`veaf-tools.exe` manipulates `.miz` files at build time — before loading them in DCS.

| Command | What it does |
|---------|-------------|
| `prepare` | Initialises/refreshes a mission folder from the default scaffold; `--template minimal\|standard\|full\|custom` generates a `mission.yaml` with the matching module set (`custom` = pick modules interactively); `--list-templates` to list them |
| `build` | Builds the mission from `src/` — injects VEAF triggers, outputs a `.miz`. Also validates the `mission.yaml` references to the Mission Editor (trigger zones, groups, units, airfields) and prints a **prominent end-of-build summary** of any that are missing — **without blocking** (the `.miz` is built anyway, so you can fix them in the Mission Editor and iterate). A COMBATZONE **operation**'s `zone_name` is not checked (it's only a label, not a required trigger zone) |
| `validate` | Lints the mission folder **before** build — reports config errors and runtime risks without building (exit non-zero on error; `--strict` fails on warnings too) |
| `extract` | Extracts a `.miz` to a source folder (run once to initialise your repo) |
| `export` | Exports a `.miz` to **JSON** (default), **YAML** or **Markdown** (readable brief): `export mission.miz out.json --format json`. Parsing is **pure-Python** (the `luadata` parser) and **never executes Lua** — a safe alternative to interpreting an untrusted `.miz` (arbitrary-code-execution risk). Writes to stdout when no output file is given |
| `inject-presets` | Injects radio frequency plans for all human cockpits |
| `inject-weather` | Creates weather/time variants from a YAML config |
| `inject-aircraft-groups` | Injects aircraft group templates |
| `extract-aircraft-groups` | Extracts aircraft groups from a mission |
| `inject-waypoints` | Injects waypoints (bullseye, nav points) for human groups |
| `extract-waypoints` | Extracts waypoints from a mission |
| `convert-v5` | Migrates a v5 mission folder to v6 format |
| `user-config` | Shows or edits the global user config (`~/veafmct.yaml`) |

Full reference: [Tools Reference](../TOOLS_REFERENCE.md)

### Interactive mode (wizard)

In an interactive terminal, `veaf-tools.exe` opens a guided wizard (TUI) instead of failing on a missing option:

- `veaf-tools.exe` (no arguments) → command-selection menu, then prompts.
- `veaf-tools.exe prepare` → the wizard asks for the target folder **and** the module template.
- `veaf-tools.exe prepare c:\my-mission` → the folder is already supplied, so the wizard only asks for the template.
- `--tui` appended to any command → opens the wizard even when nothing is missing (e.g. `veaf-tools.exe build --tui`).

Options already passed on the command line are pre-filled; unknown options (e.g. `--verbose`) are preserved as-is. Outside an interactive terminal (CI, redirected output), the wizard never triggers and the command runs normally.

**Navigation**: **Ctrl-B** (or **Escape** pressed twice) steps back to the previous prompt; from the main menu (or a command's first prompt) it quits the wizard. A reminder is shown at the bottom of each prompt.

---

## Typical Build Workflow

```powershell
# Build the mission — the integrated pipeline runs all enabled steps automatically
veaf-tools.exe build
```

The `build` command reads `mission.yaml` and runs every enabled pipeline step (presets, waypoints, aircraft groups, weather) in a single pass. Configure which steps are active under the `pipeline:` key in `mission.yaml`.

<details>
<summary>Advanced: running pipeline steps individually</summary>

If you need to run a single step in isolation (e.g. inject weather only, without a full rebuild):

```powershell
# Inject radio presets only
veaf-tools.exe inject-presets my-mission.miz --presets-file src/presets.yaml

# Inject bullseye and nav waypoints only
veaf-tools.exe inject-waypoints my-mission.miz --waypoints-file src/waypoints.yaml

# Create weather/time variants only
veaf-tools.exe inject-weather my-mission.miz --config-file versions.yaml
```

</details>

Commit the contents of `src/` to Git — not the built `.miz`. Use `extract` once to bootstrap the source folder from an existing mission:

```powershell
veaf-tools.exe extract my-mission.miz
```

---

## Build Profiles {#build-profiles}

Build profiles let you switch between different named configurations without editing `mission.yaml`. Define a `profiles:` section once, then select a profile at build time:

```yaml
# mission.yaml
global_log_level: info
security:
  disabled: false
pipeline:
  weather: true

profiles:
  TEST:
    global_log_level: debug
    security:
      disabled: true
    pipeline:
      weather: false   # skip weather variants during test builds
  SERVER:
    global_log_level: info
    pipeline:
      weather: true
```

```powershell
# Build for testing (no weather, security disabled, verbose logging)
veaf-tools.exe build --profile TEST

# Build for server deployment
veaf-tools.exe build --profile SERVER

# Build with no profile (base config)
veaf-tools.exe build
```

Profile keys **deep-merge** onto the base config: only the keys you specify are overridden, everything else stays as defined at the top of `mission.yaml`. Passing an unknown profile name emits a warning and falls back to the base config.

See [`profiles:` in the YAML Reference](../MISSION_YAML_REFERENCE.md#profiles) for the full field description.

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
| Integrations | [veafSkynetIadsHelper](scripts/veafSkynetIadsHelper.md) |

---

## Configuration Examples {#configuration-examples}

### QRA Zone

```lua
local northQra = VeafQRA:new()
  :setName("QRA-North")
  :setTriggerZone("ZONE-QRA-NORTH")
  :setCoalition(coalition.side.RED)
  :addGroup("MiG-29 QRA")
  :start()
```

### Combat Zone

```lua
local strikeZone = VeafCombatZone:new()
  :setMissionEditorZoneName("ZONE-STRIKE-ALPHA")
  :setFriendlyName("Strike Alpha")
  :setBriefing("Armoured column advancing on Senaki. Destroy all armoured vehicles; expect AAA.")
  :addZoneElement(VeafCombatZoneElement:new():setName("ARMOR"):setSpawnGroup("STRIKE-ALPHA-ARMOR"))
  :addZoneElement(VeafCombatZoneElement:new():setName("AAA"):setSpawnGroup("STRIKE-ALPHA-AAA"))
  :initialize()
```

### Air Waves Zone

```lua
local defenseZone = AirWaveZone:new()
  :setName("AW-Defense")
  :setTriggerZone("ZONE-DEFENSE")
  :setDescription("Intercept zone")
  :addPlayerCoalition(coalition.side.BLUE)
  :addWave({ "MiG-23 Wave 1", "MiG-23 Wave 1b" })
  :addWave({ "MiG-29 Wave 2" })
  :start()
```

---

## CTLD and CSAR Integration {#ctld-and-csar-integration}

[CTLD](https://github.com/ciribob/DCS-CTLD) (Combat Troop Loading and Deployment) and [CSAR](https://github.com/ciribob/DCS-CSAR) (Combat Search and Rescue) are third-party scripts that VEAF supports natively. VEAF monkey-patches their `initialize()` functions at startup, so you do not need to load or initialise them separately — just configure them via `mission.yaml` using the YAML-first approach below.

### Configuring CTLD via mission.yaml (YAML-first)

You can enable CTLD and set its properties directly in `mission.yaml`, without any Lua:

```yaml
modules:
  CTLD:
    enabled: true
    settings:                # ctld.xxx = value pairs
      hoverPickup: false
      slingLoad: true
```

VEAF generates the corresponding Lua configuration in `veaf-config.lua` at build time, including the `ctld.initialize()` call. Use `mission-script.lua` only for settings not yet supported by the YAML schema (e.g. `aircraftType` tables).

### Configuring CSAR via mission.yaml (YAML-first)

CSAR can be configured the same way:

```yaml
modules:
  CSAR:
    enabled: true
    settings:                # csar.xxx = value pairs
      enableAllslots: true
      useprefix: true
      csarPrefix: "MEDEVAC"
```

VEAF generates the `csar.xxx = value` assignments and the `csar.initialize()` call in `veaf-config.lua`. For complex settings such as `aircraftType` (a per-aircraft table), continue using the Lua callback pattern in `mission-script.lua`.

### Loading order in the DCS trigger chain

CTLD/CSAR scripts must be loaded before the VEAF scripts:

```
DO SCRIPT FILE → ctld.lua          (third-party)
DO SCRIPT FILE → csar.lua          (third-party)
DO SCRIPT FILE → veaf-scripts.lua  (VEAF modules)
DO SCRIPT FILE → veaf-config.lua   (generated from mission.yaml)
DO SCRIPT FILE → mission-script.lua (your custom code)
```

When `veaf-scripts.lua` loads, it detects the presence of `ctld` and `csar` global tables and wraps their `initialize()` functions, applying VEAF defaults before calling the real initialiser.

### Lua fallback — CTLD in mission-script.lua

For settings not covered by `mission.yaml`, use the Lua callback pattern:

```lua
if ctld then
    local initializeCTLD = true
    if initializeCTLD then
        veaf.loggers.get(veaf.Id):info("initialize CTLD")
        local function configurationCallback()
            -- Configure CTLD settings before it initialises
            -- ctld.hoverPickup = false
            -- ctld.slingLoad   = true
        end
        -- Calls the VEAF-wrapped version of ctld.initialize
        ctld.initialize(configurationCallback)
    else
        -- Prevent the auto-scheduled ctld.initialize from running
        ctld.alreadyInitialized = true
    end
end
```

The `configurationCallback` is called immediately before the real `ctld.initialize()` — set CTLD properties there, not before.

### Lua fallback — CSAR in mission-script.lua

For per-aircraft type overrides or other complex settings not supported by YAML:

```lua
if csar then
    local initializeCSAR = true
    if initializeCSAR then
        veaf.loggers.get(veaf.Id):info("initialize CSAR")
        local function configurationCallback()
            -- Configure CSAR settings before it initialises
            csar.enableAllslots = true
            csar.aircraftType["UH-1H"]  = 8
            csar.aircraftType["Mi-8MT"] = 16
            csar.useprefix  = true
            csar.csarPrefix = { "MEDEVAC" }
        end
        csar.initialize(configurationCallback)
    else
        csar.alreadyInitialized = true
    end
end
```

### VEAF automatic defaults

When VEAF wraps the initialisers it applies its own defaults: logging and a standard radio menu entry. You do not need to configure any of this manually.

---

## DCS Bridge

[VEAF-dcs-bridge](https://github.com/VEAF/VEAF-dcs-bridge) is an optional Lua module that opens a TCP socket between DCS World and an external server, enabling external control of the mission (Discord bots, dashboards, automation tools).

### Enabling dcs-bridge.lua injection

Add the following section to your `mission.yaml`:

```yaml
dcs_bridge:
  enabled: true
```

At build time, `veaf-tools` automatically downloads `dcs-bridge.lua` from GitHub and injects it as the very first DO SCRIPT FILE trigger in the mission (before all VEAF scripts).

### Using a local file

If you have a local clone of `VEAF-dcs-bridge`, point directly to the file:

```yaml
dcs_bridge:
  enabled: true
  lua_path: /path/to/VEAF-dcs-bridge/src/lua/dcs-bridge.lua
```

The path can be absolute or relative to the mission folder.

### Load order

When `dcs_bridge` is enabled, the trigger is inserted at **position 1**, before all other VEAF triggers. dcs-bridge is therefore available at the earliest possible point in mission startup, before `veaf-scripts.lua` is loaded.

---

## Debug Logging

All VEAF scripts write to the DCS log file (`Saved Games\DCS\Logs\dcs.log`). The build now produces a **single** `veaf-scripts.lua` loader; verbosity is controlled by log levels in `mission.yaml`, not by loading a different script file.

### Switching log levels {#debug-logging}

Set a global default with `global_log_level`, or override it per module with `logLevel`, then rebuild:

```yaml
global_log_level: info   # trace | debug | info | warning | error

modules:
  SPAWN:
    logLevel: debug   # overrides the global default for this module only
```

`veaf-tools.exe build` regenerates `veaf-config.lua` from `mission.yaml`. For a quick change without rebuilding, edit `veaf-config.lua` directly — it is a generated file so your changes will be overwritten on the next build.

### Reading the log

We recommend [Klogg](https://klogg.filimonov.dev/) — a fast log viewer with regex highlighting. Load `dcs.log` and filter on `VEAF` to see only VEAF messages.

A ready-to-use Klogg highlight profile is included in the repository at [`tools/klogg/veaf.conf`](../../tools/klogg/veaf.conf). It colour-codes log levels (errors in red, warnings in orange, VEAF info in green, debug in teal, trace in grey) and highlights MIST and CTLD entries. To install it: open Klogg → *File > Import highlights…* and select the file.

---

## Resources

- [Scripts Reference](scripts/README.md) — all scripts with configuration details
- [Tools Reference](../TOOLS_REFERENCE.md) — `veaf-tools.exe` CLI full reference
- [Lua API Reference](../LUA_API_REFERENCE.md) — complete Lua API documentation
- [VEAF Demo Mission](https://github.com/VEAF/VEAF-Demo-Mission) — working example mission
- [VEAF Discord](https://www.veaf.org/discord) — community help

