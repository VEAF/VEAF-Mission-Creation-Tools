# mission.yaml Reference

`mission.yaml` is the optional build-time configuration file for veaf-tools. Place it at the root of your mission folder, next to `veaf-tools-updater.exe`. If absent, `veaf-tools build` works with default settings.

This page covers the **top-level sections** of `mission.yaml`. Configuration for individual Lua modules is documented in each module's own page (see the [index by module](#index-by-module) below).

---

## Understanding the YAML file landscape

A VEAF mission folder uses **two distinct categories** of YAML files. Understanding the difference helps you know which file to edit for a given task.

### Category A — Build pipeline files

These files drive the **design-time injection** steps that `veaf-tools build` performs before writing the final `.miz`. Each step reads its own YAML file and injects data into the mission. They are listed under the `pipeline:` section of `mission.yaml`.

| File (in `src/`) | Pipeline step | What it does |
|------------------|--------------|--------------|
| `waypoints.yaml` | `waypoints` | Injects named waypoints into the mission |
| `presets.yaml` | `presets` | Configures radio presets for each aircraft group |
| `aircraft-templates.yaml` | `aircraft_groups` | Defines aircraft group templates |
| `versions.yaml` | `weather` | Generates one `.miz` variant per weather preset |

These files are **not** loaded at DCS runtime — they are consumed by `veaf-tools build` and then compiled into the `.miz`.

### Category B — Runtime module configuration (this file)

`mission.yaml` itself configures **how VEAF Lua modules behave at DCS runtime**. It is translated at build time into `veaf-config.lua`, which is injected into the mission and executed when DCS loads the mission.

Sections such as `lua_modules:`, `qra:`, `assets:`, and `shortcuts:` all describe runtime module behaviour.

```
mission folder/
├── mission.yaml          ← runtime module config (THIS FILE)
│   └── pipeline:
│       ├── waypoints: true  ──► src/waypoints.yaml     (build-time injection)
│       ├── presets:  true   ──► src/presets.yaml        (build-time injection)
│       ├── aircraft_groups: true  ──► src/aircraft-templates.yaml
│       └── weather:  true   ──► src/versions.yaml
└── src/
    ├── waypoints.yaml
    ├── presets.yaml
    ├── aircraft-templates.yaml
    └── versions.yaml
```

---

## Minimal working example

```yaml
# mission.yaml — minimum viable configuration
global_log_level: debug           # remove before deploying to players

mission:
  name: "My-Mission"

security:
  disabled: true

lua_modules:
  RADIO:
    enable: true
  ASSETS:
    enable: true
    assets:
      - sort: 1
        name: "Texaco"
        description: "Texaco (KC-135)"
        information: 'Tacan 51Y\nU251.00 (21)'
```

---

## Syntax errors

If `mission.yaml` contains a YAML syntax error (wrong indentation, a missing colon, a tab character…), `veaf-tools build` stops immediately and displays a clear message indicating the file name, the line and column of the problem, and a plain-language hint on how to fix it:

```
Syntax error in mission.yaml, line 81, column 4.
  The error starts near line 34, column 3.
  → Check the indentation around these lines. YAML uses spaces only (never tabs).
    All items in the same block must be aligned at the same column.
```

Common causes:

| Symptom | Cause | Fix |
|---------|-------|-----|
| `indentation` hint | A block is indented differently from the rest | Align the key with its siblings |
| `tab` hint | A tab character was used instead of spaces | Replace all tabs with spaces in your editor |
| `colon` hint | A key is missing its `:` separator | Write `key: value`, not `key value` |

!!! tip
    Most text editors can visualise whitespace characters — enable this option to quickly spot tab/space mix-ups.

---

## Top-level sections

### `global_log_level`

Forces a log level on all VEAF modules. Remove before deploying to players.

```yaml
global_log_level: debug     # error | warning | info | debug | trace
```

| Value | Description |
|-------|-------------|
| `error` | Errors only |
| `warning` | Errors and warnings |
| `info` | Standard operational messages *(production default)* |
| `debug` | Detailed module activity — use during development |
| `trace` | Extremely verbose — use when tracking specific issues |

---

### `mission:`

Mission identity fields used in radio menus, log messages, and export paths.

```yaml
mission:
  name: "My-Mission"          # shown in radio menus and log messages
  export_path: null           # null = default DCS Saved Games path
  era: MODERN                 # MODERN | COLD_WAR | WW2
  language: en                # locale for generated messages (optional)
```

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `name` | string | — | No | Mission name shown in menus and logs |
| `export_path` | string \| null | `null` | No | Override DCS Saved Games export path |
| `era` | string | `MODERN` | No | `MODERN` \| `COLD_WAR` \| `WW2` — affects available spawn groups |
| `language` | string | `en` | No | Locale for generated radio messages |

---

### `security:`

Controls the VEAF security system. By default, security is disabled (all players have full access).

```yaml
security:
  disabled: true                    # true = no password required (default)
  password_hashes:                  # SHA-256 hashes for player/JTF access
    - "e3b0c44298fc1c149afbf4c8996fb924..."
  password_mm_hashes:               # SHA-256 hashes for Mission Master access
    - "e3b0c44298fc1c149afbf4c8996fb924..."
```

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `disabled` | boolean | `true` | No | `true` = no password required |
| `password_hashes` | string[] | `[]` | No | SHA-256 hashes for player access |
| `password_mm_hashes` | string[] | `[]` | No | SHA-256 hashes for Mission Master access |

> To generate a SHA-256 hash: `echo -n "yourpassword" | sha256sum` (Linux/macOS) or use an online tool.

---

### `settings:`

Arbitrary key-value pairs injected into the mission as `veaf.config.KEY = value`. Use this to pass mission-specific constants to Lua scripts.

```yaml
settings:
  MY_MISSION_FLAG: 42
  ENABLE_CONVOY: true
  MISSION_PHASE: "alpha"
```

Each key becomes `veaf.config.MY_MISSION_FLAG = 42` in the generated `veaf-config.lua`.

---

### `external_modules:`

Configuration for third-party Lua modules integrated via VEAF.

```yaml
external_modules:
  skynet:
    enabled: false
    include_red_in_radio: false      # add RED IADS status to F10 menu
    debug_red: false                 # verbose Skynet debug for RED
    include_blue_in_radio: false     # add BLUE IADS status to F10 menu
    debug_blue: false                # verbose Skynet debug for BLUE
  ctld:
    enabled: false
    # any ctld.xxx = value pairs can be added here
    # e.g. hoverPickup: true
```

#### `external_modules.skynet` fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `false` | Enable Skynet IADS integration |
| `include_red_in_radio` | boolean | `false` | Add RED IADS status to F10 radio menu |
| `debug_red` | boolean | `false` | Enable verbose Skynet debug for RED coalition |
| `include_blue_in_radio` | boolean | `false` | Add BLUE IADS status to F10 radio menu |
| `debug_blue` | boolean | `false` | Enable verbose Skynet debug for BLUE coalition |

#### `external_modules.ctld` fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `false` | Enable CTLD integration |
| *(any ctld property)* | any | — | Any `ctld.xxx` property (e.g. `hoverPickup: true`) |

> CSAR configuration is not yet available via `mission.yaml` — configure it in `mission-script.lua` directly.

---

### `veaf_tools:`

Version compatibility constraint for `veaf-tools-updater.exe`. The updater skips releases that don't match.

```yaml
veaf_tools:
  version: "6"          # accept any 6.x.x
```

| Format | Example | Meaning |
|--------|---------|---------|
| Major only | `"6"` | Any `6.x.x` |
| Major.Minor | `"6.1"` | Any `6.1.x` |
| Exact | `"6.1.3"` | Exactly `6.1.3` |
| Compatible | `"^6.1.3"` | `>=6.1.3, <7.0.0` |
| Approximate | `"~6.1.3"` | `>=6.1.3, <6.2.0` |

---

### `lua_modules:`

Enable, disable, or configure individual VEAF Lua modules. Modules not listed are enabled with their default settings.

```yaml
lua_modules:
  RADIO:
    enable: true
    logLevel: info            # optional per-module log level override
    init:
      help_menus: true
  SPAWN:
    enable: true
    logLevel: debug
```

The `enable` and `logLevel` fields are available for every module. Additional `init:` or data fields are module-specific — see each module's documentation page.

**Common fields (all modules):**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enable` | boolean | `true` | Enable or disable this module |
| `logLevel` | string | *(global)* | Override log level for this module only |

**Module IDs:**

| ID | Module | Doc page |
|----|--------|----------|
| `RADIO` | veafRadio | [veafRadio](mission-maker/scripts/veafRadio.md) |
| `SHORTCUTS` | veafShortcuts | [veafShortcuts](mission-maker/scripts/veafShortcuts.md) |
| `NAMEDPOINTS` | veafNamedPoints | [veafNamedPoints](mission-maker/scripts/veafNamedPoints.md) |
| `ASSETS` | veafAssets | [veafAssets](mission-maker/scripts/veafAssets.md) |
| `CARRIER` | veafCarrierOperations | [veafCarrierOperations](mission-maker/scripts/veafCarrierOperations.md) |
| `SANCTUARY` | veafSanctuary | [veafSanctuary](mission-maker/scripts/veafSanctuary.md) |
| `COMBATZONE` | veafCombatZone | [veafCombatZone](mission-maker/scripts/veafCombatZone.md) |
| `AIRWAVES` | veafAirWaves | [veafAirWaves](mission-maker/scripts/veafAirWaves.md) |
| `QRA` | veafQraManager | [veafQraManager](mission-maker/scripts/veafQraManager.md) |
| `CASMISSION` | veafCasMission | [veafCasMission](mission-maker/scripts/veafCasMission.md) |
| `SPAWN` | veafSpawn | [veafSpawn](mission-maker/scripts/veafSpawn.md) |
| `MOVE` | veafMove | [veafMove](mission-maker/scripts/veafMove.md) |
| `SECURITY` | veafSecurity | [veafSecurity](mission-maker/scripts/veafSecurity.md) |
| `GRASS` | veafGrass | [veafGrass](mission-maker/scripts/veafGrass.md) |
| `WEATHER` | veafWeather | [veafWeather](mission-maker/scripts/veafWeather.md) |
| `INTERPRETER` | veafInterpreter | [veafInterpreter](mission-maker/scripts/veafInterpreter.md) |
| `MISSILEGUARDIAN` | veafMissileGuardian | [veafMissileGuardian](mission-maker/scripts/veafMissileGuardian.md) |

---

### `qra:`, `cap_missions:`, `combat_missions:`

Top-level sections for QRA, CAP mission, and combat mission definitions. These require the corresponding modules enabled under `lua_modules:`.

See the respective module pages for full schema:
- [`qra:`](mission-maker/scripts/veafQraManager.md#configuration-missionyaml) — Quick Reaction Alert definitions
- [`cap_missions:` and `combat_missions:`](mission-maker/scripts/veafCasMission.md#configuration-missionyaml) — CAP and combat mission definitions

---

### `pipeline:`

Controls the optional build pipeline steps. See the [Pipeline Reference](PIPELINE_REFERENCE.md) for the full schema of each step's config file.

```yaml
pipeline:
  presets: false
  waypoints: true
  aircraft_groups:
    file: src/my-aircraft.yaml
    mode: replace
  weather: false
```

---

### `build:`

Controls how `veaf-tools build` resolves the VEAF scripts bundle.
These settings are normally set via the CLI (`--dev-mode`, `--scripts-path`) and then persisted here automatically.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `dev_mode` | `bool` | `false` | When `true`, scripts are loaded from `<scripts_path>/build/veaf-scripts.lua` instead of the published copy |
| `scripts_path` | `string` | *(user config)* | Path to a local VEAF-Mission-Creation-Tools clone; required when `dev_mode: true` |

`scripts_path` resolution order (first match wins):
1. `--scripts-path <path>` CLI option
2. `mission.yaml build.scripts_path`
3. `~/veafmct.yaml scripts_path`

```yaml
build:
  dev_mode: true
  scripts_path: C:/dev/VEAF-Mission-Creation-Tools
```

> See the [Developer Mode](developer/GUIDE.md#developer-mode) section of the Developer Guide for the full workflow.

---

### `profiles:`

Named build profiles. Each profile is a set of config overrides that deep-merge onto the base `mission.yaml` when you pass `--profile <name>` to `veaf-tools build`. Keys absent from the profile retain their base values. Lists are replaced, not concatenated. The `profiles:` key itself is never written to the built mission.

| Field | Type | Description |
|-------|------|-------------|
| `profiles.<name>` | `dict` | Any top-level `mission.yaml` key (e.g. `global_log_level`, `security`, `pipeline`) |

**Merge rules**
- Nested dicts are merged recursively (only the keys you specify are overridden).
- Scalar values and lists are replaced wholesale.
- `profiles:` is stripped from the effective config — it is never passed to the Lua generator or the pipeline.

```yaml
profiles:
  TEST:
    global_log_level: debug
    security:
      disabled: true
    pipeline:
      weather: false
  SERVER:
    global_log_level: info
    pipeline:
      weather: true
```

Usage:

```powershell
veaf-tools.exe build --profile TEST
veaf-tools.exe build --profile SERVER
```

> If the named profile does not exist in `mission.yaml`, a warning is emitted and the base config is used unchanged.

---

## Index by category

### Core

| Section / Field | Description |
|-----------------|-------------|
| [`global_log_level`](#global_log_level) | Force a log level on all modules |
| [`mission:`](#mission) | Mission name, era, export path |
| [`settings:`](#settings) | Arbitrary `veaf.config.KEY = value` pairs |
| [`veaf_tools:`](#veaf_tools) | Version compatibility constraint |

### Security

| Section / Field | Description |
|-----------------|-------------|
| [`security:`](#security) | Enable/disable security, password hashes |
| `lua_modules.SECURITY` | [veafSecurity](mission-maker/scripts/veafSecurity.md) |

### Combat

| Section / Field | Description |
|-----------------|-------------|
| [`qra:`](#qra-cap_missions-combat_missions) | QRA definitions |
| [`cap_missions:`](#qra-cap_missions-combat_missions) | CAP mission definitions |
| [`combat_missions:`](#qra-cap_missions-combat_missions) | Combat mission definitions |
| `lua_modules.COMBATZONE` | [veafCombatZone](mission-maker/scripts/veafCombatZone.md) |
| `lua_modules.AIRWAVES` | [veafAirWaves](mission-maker/scripts/veafAirWaves.md) |
| `lua_modules.CASMISSION` | [veafCasMission](mission-maker/scripts/veafCasMission.md) |

### Air Defense

| Section / Field | Description |
|-----------------|-------------|
| `external_modules.skynet` | Skynet IADS integration |
| `lua_modules.SANCTUARY` | [veafSanctuary](mission-maker/scripts/veafSanctuary.md) |
| `lua_modules.MISSILEGUARDIAN` | [veafMissileGuardian](mission-maker/scripts/veafMissileGuardian.md) |
| `lua_modules.QRA` | [veafQraManager](mission-maker/scripts/veafQraManager.md) |

### Assets & Support

| Section / Field | Description |
|-----------------|-------------|
| `lua_modules.ASSETS` | [veafAssets](mission-maker/scripts/veafAssets.md) |
| `lua_modules.CARRIER` | [veafCarrierOperations](mission-maker/scripts/veafCarrierOperations.md) |
| `lua_modules.NAMEDPOINTS` | [veafNamedPoints](mission-maker/scripts/veafNamedPoints.md) |
| `lua_modules.RADIO` | [veafRadio](mission-maker/scripts/veafRadio.md) |
| `lua_modules.SHORTCUTS` | [veafShortcuts](mission-maker/scripts/veafShortcuts.md) |

### Build Pipeline

| Section / Field | Description |
|-----------------|-------------|
| [`pipeline:`](#pipeline) | Pipeline step control |
| `pipeline.presets` | [presets.yaml schema](PIPELINE_REFERENCE.md#step-1--radio-presets-presetsyaml) |
| `pipeline.waypoints` | [waypoints.yaml schema](PIPELINE_REFERENCE.md#step-2--waypoints-waypointsyaml) |
| `pipeline.aircraft_groups` | [aircraft-templates.yaml schema](PIPELINE_REFERENCE.md#step-3--aircraft-groups-aircraft-templatesyaml) |
| `pipeline.weather` | [versions.yaml schema](PIPELINE_REFERENCE.md#step-4--weather--time-versions-versionsyaml) |
| [`build:`](#build) | Developer mode and scripts path override |
| `build.dev_mode` | Use local Lua bundle instead of published scripts |
| `build.scripts_path` | Path to local VEAF-Mission-Creation-Tools clone |
| [`profiles:`](#profiles) | Named build profiles (deep-merge overrides for `--profile`) |

---

## Index by module

| Module | mission.yaml key | Doc page |
|--------|-----------------|----------|
| veafRadio | `lua_modules.RADIO` | [veafRadio](mission-maker/scripts/veafRadio.md#configuration-missionyaml) |
| veafShortcuts | `lua_modules.SHORTCUTS` | [veafShortcuts](mission-maker/scripts/veafShortcuts.md#configuration-missionyaml) |
| veafNamedPoints | `lua_modules.NAMEDPOINTS` | [veafNamedPoints](mission-maker/scripts/veafNamedPoints.md#configuration-missionyaml) |
| veafCarrierOperations | `lua_modules.CARRIER` | [veafCarrierOperations](mission-maker/scripts/veafCarrierOperations.md#configuration-missionyaml) |
| veafAssets | `lua_modules.ASSETS` | [veafAssets](mission-maker/scripts/veafAssets.md#configuration-missionyaml) |
| veafSanctuary | `lua_modules.SANCTUARY` | [veafSanctuary](mission-maker/scripts/veafSanctuary.md#configuration-missionyaml) |
| veafCombatZone | `lua_modules.COMBATZONE` | [veafCombatZone](mission-maker/scripts/veafCombatZone.md#configuration-missionyaml) |
| veafAirWaves | `lua_modules.AIRWAVES` | [veafAirWaves](mission-maker/scripts/veafAirWaves.md#configuration-missionyaml) |
| veafQraManager | `lua_modules.QRA` + `qra:` | [veafQraManager](mission-maker/scripts/veafQraManager.md#configuration-missionyaml) |
| veafCasMission | `cap_missions:` + `combat_missions:` | [veafCasMission](mission-maker/scripts/veafCasMission.md#configuration-missionyaml) |

---

## See Also

- [Pipeline Reference](PIPELINE_REFERENCE.md) — YAML schemas for presets, waypoints, aircraft-templates, versions
- [Mission Maker Guide](mission-maker/GUIDE.md) — complete workflow
- [Lua API Reference](LUA_API_REFERENCE.md) — Lua builder chain API for advanced use
