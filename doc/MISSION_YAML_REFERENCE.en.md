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
| `spawnables.yaml` | `spawnable_aircrafts` | Spawnable aircraft groups (`veafSpawn-` prefix) |
| `dynamic-slot-templates.yaml` | `dynamic_slot_templates` | Dynamic-slot templates (`dynSpawnTemplate=true`) |
| `warehouses.yaml` | `warehouses` | Dynamic-Slot warehouses: `dynamicSpawn`, stock, fuel, template links |
| `versions.yaml` | `weather` | Generates one `.miz` variant per weather preset |

These files are **not** loaded at DCS runtime — they are consumed by `veaf-tools build` and then compiled into the `.miz`.

### Category B — Runtime module configuration (this file)

`mission.yaml` itself configures **how VEAF Lua modules behave at DCS runtime**. It is translated at build time into `veaf-config.lua`, which is injected into the mission and executed when DCS loads the mission.

Sections such as `modules:`, `qra:`, `assets:`, and `shortcuts:` all describe runtime module behaviour.

```
mission folder/
├── mission.yaml          ← runtime module config (THIS FILE)
│   └── pipeline:
│       ├── waypoints: true  ──► src/waypoints.yaml     (build-time injection)
│       ├── presets:  true   ──► src/presets.yaml        (build-time injection)
│       ├── spawnable_aircrafts: true     ──► src/spawnables.yaml
│       ├── dynamic_slot_templates: true  ──► src/dynamic-slot-templates.yaml
│       ├── warehouses: true  ──► src/warehouses.yaml
│       └── weather:  true   ──► src/versions.yaml
└── src/
    ├── waypoints.yaml
    ├── presets.yaml
    ├── spawnables.yaml
    ├── dynamic-slot-templates.yaml
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

modules:
  RADIO:
    enabled: true
  ASSETS:
    enabled: true
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
  language: fr                # in-game VEAF message language: fr | en (default: the tools' language)
```

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `name` | string | — | No | Mission name shown in menus and logs |
| `export_path` | string \| null | `null` | No | Override DCS Saved Games export path |
| `era` | string | `MODERN` | No | `MODERN` \| `COLD_WAR` \| `WW2` — affects available spawn groups |
| `language` | string | *tools' language* | No | Language of in-game VEAF messages (`fr` \| `en`); emitted into `veaf-config.lua` as `veaf.config.language` and read by `veaf.t()`. When omitted, the build uses the tools' language (`--lang` > `VEAF_LANG` > user config > OS locale > `en`) |

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

### Third-party modules: `SKYNET` / `CTLD` / `CSAR` (under `modules:`)

> **v6 change (hard break)**: the `external_modules:` and `qra:` sections no longer exist. All of their configuration now lives under the `modules:` block, the single source of truth. See [ADR 0001](adr/0001-modules-single-source-of-truth.md).

Skynet IADS, CTLD and CSAR are configured like any other module, directly under `modules:`:

```yaml
modules:
  SKYNET:
    enabled: true
    include_red_in_radio: false      # add RED IADS status to F10 menu
    debug_red: false                 # verbose Skynet debug for RED
    include_blue_in_radio: false     # add BLUE IADS status to F10 menu
    debug_blue: false                # verbose Skynet debug for BLUE
  CTLD:
    enabled: true
    settings:                        # ctld.xxx = value pairs
      hoverPickup: true
  CSAR:
    enabled: true
    settings:                        # csar.xxx = value pairs
      enableAllslots: true
```

#### `modules.SKYNET` fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `false` | Enable Skynet IADS integration |
| `include_red_in_radio` | boolean | `false` | Add RED IADS status to F10 radio menu |
| `debug_red` | boolean | `false` | Enable verbose Skynet debug for RED coalition |
| `include_blue_in_radio` | boolean | `false` | Add BLUE IADS status to F10 radio menu |
| `debug_blue` | boolean | `false` | Enable verbose Skynet debug for BLUE coalition |

#### `modules.CTLD` / `modules.CSAR` fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `false` | Enable CTLD / CSAR integration |
| `settings` | mapping | — | `ctld.xxx` / `csar.xxx` pairs (e.g. `hoverPickup: true`, `enableAllslots: true`) |

VEAF generates the `ctld.xxx = value` / `csar.xxx = value` assignments and the `initialize()` call in `veaf-config.lua`. On `convert-v5`, these settings are extracted automatically from `missionConfig.lua`. For complex settings such as `aircraftType` (a per-aircraft table), continue using the Lua callback pattern in `mission-script.lua`. See [CTLD and CSAR Integration](mission-maker/GUIDE.en.md#ctld-and-csar-integration).

> **Sounds.** CTLD and CSAR play sounds by filename at runtime (`beacon.ogg`, `beaconsilent.ogg`, `CSAR.ogg`). When CTLD or CSAR is enabled, the build automatically injects the required sounds it ships (`src/scripts/community/sounds/`) into the mission's `l10n/DEFAULT/`, without overwriting any sound your mission already provides. A required sound shipped by neither the tools nor your mission is reported with a build warning — add it to `src/mission/l10n/DEFAULT/` (e.g. `radiobeep.ogg`, the JTAC fallback beep, is not redistributed).

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

### `modules:`

The unified `modules:` block enables, disables, or configures every VEAF Lua module **and** every community script in a single place. Modules not listed are enabled with their default settings.

> **Migration note.** `modules:` replaces the older `lua_modules:` + `community_scripts:` keys. The legacy keys still work but emit a deprecation warning at build time. `enabled:` replaces the old `enable:` key.

Each entry can take **three forms**:

```yaml
modules:
  # 1. Shorthand — just enable an optional module with default settings:
  RADIO: true

  # 2. Block — enable and configure:
  SPAWN:
    enabled: true
    logLevel: debug           # optional per-module log level override
    init:
      help_menus: true

  # 3. Bare null — mandatory infrastructure module, configure only:
  UNITS:
    logLevel: debug
```

> **Infrastructure modules are always active.**
> `UNITS`, `TIME`, `CACHE`, `EVENTS`, `MARKERS`, and `COMMANDS` are mandatory and always loaded. Do **not** set `enabled:` on them — it is a build error. They may still appear in `modules:` to configure other fields such as `logLevel`.

**Common fields (all modules):**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `true` | Enable or disable this module *(optional modules only — not allowed on Infrastructure modules)* |
| `logLevel` | string | *(global)* | Override log level for this module only |

Additional `init:` or data fields are module-specific — see each module's documentation page.

**Community scripts** are listed in the same block, using their uppercase IDs. When a script is absent from `modules:`, it keeps its default state (included). Set it to `false` to exclude it:

```yaml
modules:
  CTLD: true
  CSAR: true
  SKYNET: false               # excluded from this mission
```

| Community ID | Script |
|----|--------|
| `MIST` | MIST (Mission Scripting Tools) |
| `STTS` | DCS-SimpleTextToSpeech |
| `CTLD` | CTLD (Combat Transport & Logistics Dispatcher) |
| `AIEN` | AIEN (AI Enhancement) |
| `CSAR` | CSAR (Combat Search and Rescue) |
| `HERCULES` | Hercules Cargo |
| `SKYNET` | Skynet IADS |
| `TUM` | The Universal Mission (TUM) |

> An unknown identifier triggers a build warning and is ignored.

> **`TUM` (The Universal Mission) — mission prerequisite.** TUM is a self-contained PvE mission generator (third-party community script) that takes over the whole map at start-up: it makes every airbase neutral, then assigns zones and airfields to the coalitions based on the **trigger zones** defined in the mission editor. If you enable `TUM: true` on a mission that was not authored for TUM, the script aborts at start-up with an error such as:
>
> `Coalition red has no territory zones and/or controls no airfields. Please add zone with a name starting with REDFOR…`
>
> This is **not a VEAF bug**: it is a TUM design prerequisite. To use it, create in the mission editor a trigger zone whose name starts with `BLUFOR` and another starting with `REDFOR`, each containing **at least one airbase**, plus at least one other mission zone. Only enable `TUM` for a TUM-style mission.
>
> **Opt-in (unlike the other community scripts).** TUM is the only community script that is **off by default**: a vanilla mission, a freshly v5-converted mission, or a `modules:` block that does not mention `TUM` all leave it **disabled**. Only an explicit `TUM: true` turns it on. The other community scripts are *opt-out* (active unless you set them to `false`). When `TUM: true`, the build automatically calls `TUM.initialize()` at start-up — you do not need to add anything to `mission-script.lua`.

**VEAF module IDs:**

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

### `modules.QRA`, `cap_missions:`, `combat_missions:`

QRA definitions live under `modules.QRA` (`silence_all` + `definitions:`). The `cap_missions:` / `combat_missions:` sections remain top-level. All require the corresponding modules enabled under `modules:`.

See the respective module pages for full schema:
- [`modules.QRA`](mission-maker/scripts/veafQraManager.md#configuration-missionyaml) — Quick Reaction Alert definitions
- [`cap_missions:` and `combat_missions:`](mission-maker/scripts/veafCasMission.md#configuration-missionyaml) — CAP and combat mission definitions

---

### `community_scripts:` *(legacy)*

> **Deprecated.** Community scripts are now configured in the unified [`modules:`](#modules) block using their uppercase IDs (e.g. `CTLD: true`). The separate `community_scripts:` section still works but emits a deprecation warning. See [`modules:`](#modules) for the current syntax and the list of community IDs.

---

### `custom_scripts:`

Declares custom Lua scripts present in `src/scripts/` that are not part of the standard VEAF v6 set.  
A declared script is included in the `.miz` **without** triggering a warning. By default a DCS load trigger is generated for it automatically; setting `generate_load_trigger: false` disables that trigger (useful when the script is loaded manually from `mission-script.lua`).

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `generate_load_trigger` | `bool` | `true` | Global default: generate a DCS trigger for all scripts in the list |
| `scripts[].path` | `string` | *(required)* | Path to the file, relative to the mission folder (e.g. `src/scripts/FgMission.lua`) |
| `scripts[].generate_load_trigger` | `bool` | *(global default)* | Per-script override; if absent, the global default applies |

**Loading behaviour**

- `generate_load_trigger: true` (default) → the script is loaded at mission start, in **both** loading modes: in **static** builds it is embedded in the `.miz` and loaded by the VEAF mission-loading trigger; in **dynamic** builds it is loaded from disk by the generated `veafDynamicConfig.lua`. The same flag governs both modes — there is no per-mode flag.
- `generate_load_trigger: false` → the script is still injected into the `.miz` but **no** load is generated in either mode; `mission-script.lua` (or another script) must load it via `dofile`.

**Load order**: mission scripts always load as `veaf-config.lua` → `mission-script.lua` → your `custom_scripts` (in declaration order). So a custom script can rely on the VEAF config and on `mission-script.lua` already being loaded.

```yaml
custom_scripts:
  generate_load_trigger: true       # global default for all scripts below
  scripts:
    - path: src/scripts/FgMission.lua
    - path: src/scripts/FgTools.lua
      generate_load_trigger: false  # loaded manually from mission-script.lua
```

> Any `.lua` file present in `src/scripts/` but **absent** from this section (and not one of the standard files) triggers a build warning with a reminder to declare it here.

**A script only in one variant (e.g. a dynamic-only debug script)**

`generate_load_trigger` is a single flag — it does not distinguish static from dynamic. To load a script in only one variant (a debug helper you want **only** in your local dynamic dev build, never in the static distribution), use a [build profile](#profiles) instead of a per-script flag:

```yaml
custom_scripts:
  scripts:
    - path: src/scripts/FgMission.lua   # always loaded (both variants)

profiles:
  DEV:
    custom_scripts:
      scripts:
        - path: src/scripts/FgMission.lua    # ⚠️ must repeat the base scripts
        - path: src/scripts/FgDebug.lua      # extra, dev-only
```

Build the dev variant with `veaf-tools build --profile DEV` (it loads `FgMission.lua` + `FgDebug.lua`); the default build loads only `FgMission.lua`.

> ⚠️ **Pitfall**: profile deep-merge **replaces lists, it does not concatenate them** (see [`profiles:`](#profiles)). The profile's `custom_scripts.scripts` must therefore **repeat** the base scripts and add the variant-specific one — otherwise the base scripts are lost in that profile.

---

### `pipeline:`

Controls the optional build pipeline steps. See the [Pipeline Reference](PIPELINE_REFERENCE.md) for the full schema of each step's config file.

```yaml
pipeline:
  presets: false
  waypoints: true
  spawnable_aircrafts:
    file: src/my-spawnables.yaml
    mode: replace
  dynamic_slot_templates: false
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
| `dynamic_loading` | `bool` | `false` | When `true`, VEAF **and** mission scripts are loaded from disk at runtime (dynamic mode, dev/test) instead of being embedded in the `.miz`. Profile-overridable. CLI: `--dynamic-mode` / `--no-dynamic-mode` (takes precedence) |

`scripts_path` resolution order (first match wins):
1. `--scripts-path <path>` CLI option
2. `mission.yaml build.scripts_path`
3. `~/veafmct.yaml scripts_path`

`dynamic_loading` resolves as: `--dynamic-mode`/`--no-dynamic-mode` (CLI) > `build.dynamic_loading` (profile-overridable) > `false`.

**Dynamic loading — DEV vs PROD.** When `dynamic_loading: true`, scripts load from disk at runtime (so they are not exposed inside the `.miz`/`.trk`):

- **DEV** (`dev_mode: true`) — `scripts_path` must point at a VEAF-Mission-Creation-Tools checkout; the framework loads the **individual** `veaf/*.lua` via `VeafDynamicLoader.lua` (edit and re-test without rebuilding).
- **PROD** (`dev_mode: false`) — the framework loads the concatenated **bundle** `veaf/veaf-scripts.lua` from `scripts_path` (default `<mission>/published`, installed by the updater).

In **both** modes the mission scripts — including your `custom_scripts:` — are loaded from disk via a **generated** `src/scripts/veafDynamicConfig.lua` (do not edit it by hand; declare scripts in `custom_scripts:`). The build errors out if the framework loader is missing under `scripts_path`.

```yaml
build:
  dev_mode: true
  scripts_path: C:/dev/VEAF-Mission-Creation-Tools
  dynamic_loading: false

profiles:
  test:
    build:
      dynamic_loading: true   # dynamic loading for the test profile
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
| `modules.SECURITY` | [veafSecurity](mission-maker/scripts/veafSecurity.md) |

### Combat

| Section / Field | Description |
|-----------------|-------------|
| [`modules.QRA`](#modulesqra-cap_missions-combat_missions) | QRA definitions |
| [`cap_missions:`](#modulesqra-cap_missions-combat_missions) | CAP mission definitions |
| [`combat_missions:`](#modulesqra-cap_missions-combat_missions) | Combat mission definitions |
| `modules.COMBATZONE` | [veafCombatZone](mission-maker/scripts/veafCombatZone.md) |
| `modules.AIRWAVES` | [veafAirWaves](mission-maker/scripts/veafAirWaves.md) |
| `modules.CASMISSION` | [veafCasMission](mission-maker/scripts/veafCasMission.md) |

### Air Defense

| Section / Field | Description |
|-----------------|-------------|
| `modules.SKYNET` | Skynet IADS integration |
| `modules.SANCTUARY` | [veafSanctuary](mission-maker/scripts/veafSanctuary.md) |
| `modules.MISSILEGUARDIAN` | [veafMissileGuardian](mission-maker/scripts/veafMissileGuardian.md) |
| `modules.QRA` | [veafQraManager](mission-maker/scripts/veafQraManager.md) |

### Assets & Support

| Section / Field | Description |
|-----------------|-------------|
| `modules.ASSETS` | [veafAssets](mission-maker/scripts/veafAssets.md) |
| `modules.CARRIER` | [veafCarrierOperations](mission-maker/scripts/veafCarrierOperations.md) |
| `modules.NAMEDPOINTS` | [veafNamedPoints](mission-maker/scripts/veafNamedPoints.md) |
| `modules.RADIO` | [veafRadio](mission-maker/scripts/veafRadio.md) |
| `modules.SHORTCUTS` | [veafShortcuts](mission-maker/scripts/veafShortcuts.md) |

### Build Pipeline

| Section / Field | Description |
|-----------------|-------------|
| [`pipeline:`](#pipeline) | Pipeline step control |
| `pipeline.presets` | [presets.yaml schema](PIPELINE_REFERENCE.md#step-1--radio-presets-presetsyaml) |
| `pipeline.waypoints` | [waypoints.yaml schema](PIPELINE_REFERENCE.md#step-2--waypoints-waypointsyaml) |
| `pipeline.spawnable_aircrafts` / `pipeline.dynamic_slot_templates` | [aircraft groups schema](PIPELINE_REFERENCE.md#step-3--aircraft-groups-spawnables-b-and-dynamic-slot-templates-c) |
| `pipeline.weather` | [versions.yaml schema](PIPELINE_REFERENCE.md#step-4--weather--time-versions-versionsyaml) |
| [`custom_scripts:`](#custom_scripts) | Custom Lua scripts to include in the mission |
| [`build:`](#build) | Developer mode and scripts path override |
| `build.dev_mode` | Use local Lua bundle instead of published scripts |
| `build.scripts_path` | Path to local VEAF-Mission-Creation-Tools clone |
| [`profiles:`](#profiles) | Named build profiles (deep-merge overrides for `--profile`) |

---

## Index by module

| Module | mission.yaml key | Doc page |
|--------|-----------------|----------|
| veafRadio | `modules.RADIO` | [veafRadio](mission-maker/scripts/veafRadio.md#configuration-missionyaml) |
| veafShortcuts | `modules.SHORTCUTS` | [veafShortcuts](mission-maker/scripts/veafShortcuts.md#configuration-missionyaml) |
| veafNamedPoints | `modules.NAMEDPOINTS` | [veafNamedPoints](mission-maker/scripts/veafNamedPoints.md#configuration-missionyaml) |
| veafCarrierOperations | `modules.CARRIER` | [veafCarrierOperations](mission-maker/scripts/veafCarrierOperations.md#configuration-missionyaml) |
| veafAssets | `modules.ASSETS` | [veafAssets](mission-maker/scripts/veafAssets.md#configuration-missionyaml) |
| veafSanctuary | `modules.SANCTUARY` | [veafSanctuary](mission-maker/scripts/veafSanctuary.md#configuration-missionyaml) |
| veafCombatZone | `modules.COMBATZONE` | [veafCombatZone](mission-maker/scripts/veafCombatZone.md#configuration-missionyaml) |
| veafAirWaves | `modules.AIRWAVES` | [veafAirWaves](mission-maker/scripts/veafAirWaves.md#configuration-missionyaml) |
| veafQraManager | `modules.QRA` | [veafQraManager](mission-maker/scripts/veafQraManager.md#configuration-missionyaml) |
| veafCasMission | `cap_missions:` + `combat_missions:` | [veafCasMission](mission-maker/scripts/veafCasMission.md#configuration-missionyaml) |

---

## See Also

- [Pipeline Reference](PIPELINE_REFERENCE.md) — YAML schemas for presets, waypoints, spawnables, dynamic-slot-templates, warehouses, spawn-groups, versions
- [Mission Maker Guide](mission-maker/GUIDE.md) — complete workflow
- [Lua API Reference](LUA_API_REFERENCE.md) — Lua builder chain API for advanced use
