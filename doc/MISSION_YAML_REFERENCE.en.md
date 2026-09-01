# mission.yaml Reference

`mission.yaml` is the optional build-time configuration file for veaf-tools. Place it at the root of your mission folder, next to `veaf-tools-updater.exe`. If absent, `veaf-tools mission build` works with default settings.

This page covers the **top-level sections** of `mission.yaml`. Configuration for individual Lua modules is documented in each module's own page (see the [index by module](#index-by-module) below).

---

## Understanding the YAML file landscape

A VEAF mission folder uses **two distinct categories** of YAML files. Understanding the difference helps you know which file to edit for a given task.

### Category A — Build pipeline files

These files drive the **design-time injection** steps that `veaf-tools mission build` performs before writing the final `.miz`. Each step reads its own YAML file and injects data into the mission. They are listed under the `pipeline:` section of `mission.yaml`.

| File (in `src/`) | Pipeline step | What it does |
|------------------|--------------|--------------|
| `waypoints.yaml` | `waypoints` | Injects named waypoints into the mission |
| `presets.yaml` | `presets` | Configures radio presets for each aircraft group |
| `spawnables.yaml` | `spawnable_aircrafts` | Spawnable aircraft groups (`veafSpawn-` prefix) |
| `dynamic-slot-templates.yaml` | `dynamic_slot_templates` | Dynamic-slot templates (`dynSpawnTemplate=true`) |
| `warehouses.yaml` | `warehouses` | Dynamic-Slot warehouses: `dynamicSpawn`, stock, fuel, template links |
| `spawn-groups.yaml` | `spawn_data` | Spawn database for `_spawn unit` / `_spawn group` — **optional**: the step always runs, the framework data being embedded, and this file only adds to it |
| `versions.yaml` | `weather` | Generates one `.miz` variant per weather preset |

These files are **not** loaded at DCS runtime — they are consumed by `veaf-tools mission build` and then compiled into the `.miz`.

### Category B — Runtime module configuration (this file)

`mission.yaml` itself configures **how VEAF Lua modules behave at DCS runtime**. It is translated at build time into `veaf-config.lua`, which is injected into the mission and executed when DCS loads the mission.

The `modules:` section describes runtime module behaviour (QRA, assets or shortcuts configuration lives under the relevant module, e.g. `modules.QRA`).

```
mission folder/
├── mission.yaml          ← runtime module config (THIS FILE)
│   └── pipeline:
│       ├── waypoints: true  ──► src/waypoints.yaml     (build-time injection)
│       ├── presets:  true   ──► src/presets.yaml        (build-time injection)
│       ├── spawnable_aircrafts: true     ──► src/spawnables.yaml
│       ├── dynamic_slot_templates: true  ──► src/dynamic-slot-templates.yaml
│       ├── warehouses: true  ──► src/warehouses.yaml
│       ├── spawn_data: true  ──► src/spawn-groups.yaml  (optional)
│       └── weather:  true   ──► src/versions.yaml
└── src/
    ├── waypoints.yaml
    ├── presets.yaml
    ├── spawnables.yaml
    ├── dynamic-slot-templates.yaml
    ├── warehouses.yaml
    ├── spawn-groups.yaml
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

If `mission.yaml` contains a YAML syntax error (wrong indentation, a missing colon, a tab character…), `veaf-tools mission build` stops immediately and displays a clear message indicating the file name, the line and column of the problem, and a plain-language hint on how to fix it:

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

Mission identity (name, export path, era) **and** mission-wide options (e.g. `silence_atc_on_all_airbases`) — used in radio menus, log messages, and export paths. This block holds mission-level settings, not just identity.

```yaml
mission:
  name: "My-Mission"          # shown in radio menus and log messages
  export_path: null           # null = default DCS Saved Games path
  era: MODERN                 # MODERN | COLD_WAR | WW2
  language: fr                # in-game VEAF message language: fr | en (default: the tools' language)
  silence_atc_on_all_airbases: false  # mission-wide option: mute DCS ATC at every airbase
  third_party_mods: []        # third-party DCS mods to make non-blocking (see below)
```

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `name` | string | — | No | Mission name shown in menus and logs, **and the name of the built `.miz`** — see the naming note below |
| `export_path` | string \| null | `null` | No | Override DCS Saved Games export path |
| `era` | string | *inferred* | No | `MODERN` \| `COLD_WAR` \| `WW2` — affects available spawn groups. **When absent it is inferred at every build** from the base mission's content: a WW2 unit type or a year ≤ 1945 gives `WW2`, a year ≤ 1991 `COLD_WAR`, otherwise `MODERN` (`era_detector.py`). The inferred value is **not** written back into your `mission.yaml` — it is recomputed; set the key to pin it. |
| `silence_atc_on_all_airbases` | boolean | `false` | No | Mission-wide option: mute DCS ATC at every airbase (emits `veaf.silenceAtcOnAllAirbases()`). `convert-v5` migrates it from an active call and annotates its provenance |
| `language` | string | *tools' language* | No | Language of in-game VEAF messages (`fr` \| `en`); emitted into `veaf-config.lua` as `veaf.config.language` and read by `veaf.t()`. When omitted, the build uses the tools' language (`--lang` > `VEAF_LANG` > user config > OS locale > `en`) |
| `third_party_mods` | list of strings | `[]` | No | **Third-party** DCS mods (paid/community aircraft) to make **non-blocking**: their ids are removed from the `.miz`'s `requiredModules` table at build, so a pilot who does not own the mod can still **load** the mission (that slot is simply unavailable). The list is **unioned** with a VEAF default list covering the common mods (Hercules, UH-60L, A-4E-C, T-45, AM2, SU-30/FlankerEx, Bronco-OV-10A) — only declare mods not already handled. Not to be confused with VEAF *Modules* (the `modules:` block, which are capabilities, not DCS add-ons) |

#### The `.miz` file name is an interface — `_ICAO_<code>` and real weather {#icao-naming}

`mission.name` becomes the built file name: `<name>_<YYYYMMDD>.miz`, plus a `_<VARIANT>` suffix
when [`build_variants:`](#build-variants) is used. Give a name ending in `.miz` instead and the
name is taken **verbatim**, with no date.

That matters because **server-side tooling reads the file name**. On the VEAF servers, the
RealWeather extension of [DCSServerBot](https://github.com/Special-K-s-Flightsim-Bots/DCSServerBot)
looks for **`_ICAO_<code>`** in the mission's file name and fetches that airfield's live METAR at
mission start — so the weather follows reality without rebuilding. Name the mission accordingly:

```yaml
mission:
  name: VEAF_Foothold_Caucasus_ICAO_URSS   # -> VEAF_Foothold_Caucasus_ICAO_URSS_20260728.miz
```

Two rules when picking the code:

- it must be **an airfield on that theatre** (any one; a large one is better);
- it must have a **live METAR station**. Check before trusting it — a station can exist and be
  stale, which is worse than no real weather at all, since the mission then advertises a
  "real" weather that is days old. A one-line check:

```bash
curl -s https://tgftp.nws.noaa.gov/data/observations/metar/stations/URSS.TXT
```

The first two digits of the `DDHHMMZ` group are the day of observation — compare them with today.

When a whole theatre is degraded, there are two defensible answers, and the choice belongs to
whoever runs the server. Measured on Afghanistan, **every** station lags (Kabul a month, Herat
sixteen days, Bagram a day; six airfields have no station at all): either **omit** the marker, so
RealWeather leaves the mission alone and the authored weather stands, or **take the least bad**
and know what you are getting. The VEAF Foothold Afghanistan uses `OAIX` (Bagram, about a day
behind) — a deliberate choice, not an oversight.

---

### `security:`

Controls the VEAF security system. **Security is active by default** (`veaf.SecurityDisabled = false` in `veaf.lua`): with no `security:` block nothing is emitted and the sensitive commands require a pilot level or a password. `disabled: true` turns it off for the whole mission.

```yaml
security:
  disabled: false                   # false = a password is required
  password_hashes:                  # SHA-1 hashes granting player/JTF access
    - "2a4efd2397e081bcacb82b3e447c584c65cc83ee"
  password_mm_hashes:               # SHA-1 hashes granting Mission Master access
    - "99685b3c7cb1fb08a829fc97d4a8564fc5f9435a"
```

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `disabled` | boolean | `false` | No | `true` = no password required |
| `password_hashes` | string[] | `[]` | No | **SHA-1** hashes granting player access. Emitted at levels **L1 and L9**, so the password opens marker authentication and the sensitive spawns, not only the L9 gates |
| `password_mm_hashes` | string[] | `[]` | No | **SHA-1** hashes granting Mission Master access (its own table, no level cascade) |

> **SHA-1, not SHA-256.** `veafSecurity._checkPassword` hashes what the player types with
> `sha1.hex(password)` and looks it up in the table, so a SHA-256 hash never matches and the
> password silently never works.
>
> To generate one: `echo -n "yourpassword" | sha1sum` (Linux/macOS), or
> `python -c "import hashlib,sys; print(hashlib.sha1(sys.argv[1].encode()).hexdigest())" yourpassword`.

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

### `module_settings:` {#module-settings}

Scalar settings written **straight onto a VEAF module's table** in the generated `veaf-config.lua`. Where `settings:` can only write `veaf.config.KEY`, this section targets any VEAF table.

```yaml
module_settings:
  veafSkynet.DelayForStartup: 150     # IADS start-up delay
  veafSkynet.DynamicSpawn: true
  veafRadio.RadioMenuName: "BFR"      # root radio menu name, seen by players
  veaf.DEFAULT_GROUND_SPEED_KPH: 25
```

Each entry becomes the matching Lua assignment, here `veafSkynet.DelayForStartup = 150`.

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| *(key)* | string | — | — | The full Lua target, `veafXxx.Field`. A key that does not start with `veaf` is **refused at generation time**: this section is a migration path for VEAF settings, not a hatch for writing anywhere in the runtime |
| *(value)* | boolean \| number \| string | — | — | A scalar. Tables and functions cannot be expressed here |

> **A documented field beats a migration leftover.** When a setting now has its own field in
> `mission.yaml` **and** a `module_settings:` entry targets the same Lua variable, the **documented
> field** is what applies: the `module_settings:` entry is dropped, and the build says so, naming both.
> This section is a migration path, not a permanent override — delete the line that is no longer
> needed.
>
> One setting is in that position today: `veaf.HideNamesFromSpawnedGroups`, superseded by
> `mission.hide_names_from_spawned_groups`.

> **Where it comes from.** `convert-v5` fills this section automatically: under v5, half of these
> settings reached neither `mission.yaml` nor the generated Lua, and nothing reported it. Whatever
> the conversion still cannot carry — a table, a function — is now listed as comments in the
> generated `mission-script.lua`, under "Settings NOT migrated".

---

### Third-party modules: `SKYNET` / `CTLD` / `CSAR` (under `modules:`) {#third-party-modules}

> **v6 change (hard break)**: the `external_modules:` and `qra:` sections no longer exist. All of their configuration now lives under the `modules:` block, the single source of truth. See [ADR 0001](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0001-modules-single-source-of-truth.md).

Skynet IADS, CTLD and CSAR are configured like any other module, directly under `modules:`:

```yaml
modules:
  SKYNET:
    enabled: true
    include_red_in_radio: false      # add RED IADS status to F10 menu
    debug_red: false                 # verbose Skynet debug for RED
    include_blue_in_radio: false     # add BLUE IADS status to F10 menu
    debug_blue: false                # verbose Skynet debug for BLUE
  CTLD: true                         # configured in ctld-config.yaml, not here
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

#### `modules.CSAR` fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `false` | Enable CSAR integration |
| `settings` | mapping | — | `csar.xxx` pairs (e.g. `enableAllslots: true`) |

VEAF generates the `csar.xxx = value` assignments and the `csar.initialize()` call in `veaf-config.lua`. On `convert-v5`, these settings are extracted automatically from `missionConfig.lua`. For complex settings such as `aircraftType` (a per-aircraft table), continue using the Lua callback pattern in `mission-script.lua`.

#### `modules.CTLD`: a boolean, nothing else

CTLD 2 is configured **outside `mission.yaml`**, in a `ctld-config.yaml` file sitting next to it and edited with `ctld-tools.exe`. A `settings:` block under `CTLD` is **rejected by `validate`**: it was no longer read, and letting it pass in silence is exactly the defect this change removes. Exactly one key is read here besides the switch: `manage_logistics` (boolean, default `true`). With it on, the build **adds** the carriers and FARP ammo dumps VEAF has always recognised to the `logisticUnitTypes` / `troopZoneShipTypes` lists in your `ctld-config.yaml` — it adds, it does not replace.

```yaml
modules:
  CTLD:
    enabled: true
    manage_logistics: true
```

See [CTLD and CSAR Integration](mission-maker/GUIDE.en.md#ctld-and-csar-integration) — including [where to get `ctld-tools`](mission-maker/GUIDE.en.md#getting-ctld-tools), which does not ship with VEAF MCT, and [FARPs placed in the editor](mission-maker/GUIDE.en.md#ctld-manage-logistics).

> **Sounds.** CTLD and CSAR play sounds by filename at runtime (`beacon.ogg`, `beaconsilent.ogg`, `CSAR.ogg`). When CTLD or CSAR is enabled, the build automatically injects the required sounds it ships (`src/scripts/community/sounds/`) into the mission's `l10n/DEFAULT/`, without overwriting any sound your mission already provides. A required sound shipped by neither the tools nor your mission is reported with a build warning — add it to `src/mission/l10n/DEFAULT/` (e.g. `radiobeep.ogg`, the JTAC fallback beep, is not redistributed).
>
> The build then **declares** every sound the mission carries in `mapResource`, through a "Declare mission sounds" trigger that plays it to a country no coalition uses — so nothing is audible. Without that declaration the DCS Mission Editor treats these files as orphans (it cannot know a script plays them by name) and **deletes them the moment you save the mission in the editor**, with no message at all.

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

### `modules:` {#modules}

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

**`RADIO` `init:` fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `help_menus` | boolean | `true` | Passed to `veafRadio.initialize` as `skipHelpMenus` |
| `create_menus` | boolean | `true` | `false` builds **no VEAF F10 menu at all** (`dontCreateMenus`). Combined with `security:`, that is how a public mission keeps the VEAF commands reachable only through password-protected map markers. Omit the key to keep today's behaviour |

```yaml
modules:
  RADIO:
    enabled: true
    init:
      create_menus: false       # no VEAF radio menu; commands via markers only
```

**Community scripts** are listed in the same block, using their IDs (case does not matter: `CTLD:` and `ctld:` are equivalent). When a script is absent from `modules:`, it keeps its default state — included for the *opt-out* scripts, excluded for the two *opt-in* ones (`MIST` and `TUM`, see below). Set a script to `false` to exclude it:

Because that default is easy to misread, generated files (`prepare --template`, `convert-v5`) and the shipped `mission.yaml` **always** write the five *opt-out* scripts (`STTS`, `CTLD`, `AIEN`, `CSAR`, `SKYNET`) out, at `true` or `false`: the state of a community script is never inferred from silence.

```yaml
modules:
  CTLD: true
  CSAR: true
  SKYNET: false               # excluded from this mission
```

| Community ID | Script |
|----|--------|
| `MIST` | MIST (Mission Scripting Tools) — **opt-in**, and auto-enabled when one of your own scripts calls `mist.` |
| `STTS` | DCS-SimpleTextToSpeech |
| `CTLD` | CTLD (Combat Transport & Logistics Dispatcher) |
| `AIEN` | AIEN (AI Enhancement) |
| `CSAR` | CSAR (Combat Search and Rescue) |
| `SKYNET` | Skynet IADS |
| `TUM` | The Universal Mission (TUM) |

> An unknown identifier in `modules:` is a **blocking error**: the build stops with a message naming the offending key.

> **`MIST` — opt-in, and injected only when something needs it.** MiST used to be injected into every
> mission, because the VEAF scripts called it everywhere. They no longer call it at all, so it is now
> **off by default** and the 336 KB it weighs stay out of your `.miz`. Before packaging, the build
> scans your own `src/scripts/*.lua`; if one of them calls `mist.`, MiST is injected and the build log
> names the file that asked for it. A `MIST: false` does **not** win against that scan — a script that
> calls MiST gets MiST, otherwise it would break in flight. Set `MIST: true` only when something
> reaches MiST indirectly, which the scan cannot see (through `_G["mist"]`, or from a script loaded by
> another script). A bare `MIST:` line inherited from an older `mission.yaml` now reads as
> "disabled", which is the right answer for almost every mission. See
> [MiST: injected only when you need it](mission-maker/GUIDE.en.md#mist-injection).

> **`TUM` (The Universal Mission) — mission prerequisite.** TUM is a self-contained PvE mission generator (third-party community script) that takes over the whole map at start-up: it makes every airbase neutral, then assigns zones and airfields to the coalitions based on the **trigger zones** defined in the mission editor. If you enable `TUM: true` on a mission that was not authored for TUM, the script aborts at start-up with an error such as:
>
> `Coalition red has no territory zones and/or controls no airfields. Please add zone with a name starting with REDFOR…`
>
> This is **not a VEAF bug**: it is a TUM design prerequisite. To use it, create in the mission editor a trigger zone whose name starts with `BLUFOR` and another starting with `REDFOR`, each containing **at least one airbase**, plus at least one other mission zone. Only enable `TUM` for a TUM-style mission.
>
> **Opt-in (like `MIST`, unlike the other community scripts).** TUM is **off by default**: a vanilla mission, a freshly v5-converted mission, or a `modules:` block that does not mention `TUM` all leave it **disabled**. Only an explicit `TUM: true` turns it on. `MIST` is opt-in too, for a different reason (see the note above); the remaining community scripts are *opt-out* (active unless you set them to `false`). When `TUM: true`, the build automatically calls `TUM.initialize()` at start-up — you do not need to add anything to `mission-script.lua`.

**VEAF module IDs:**

| ID | Module | Doc page |
|----|--------|----------|
| `RADIO` | veafRadio | [veafRadio](mission-maker/scripts/veafRadio.en.md) |
| `SHORTCUTS` | veafShortcuts | [veafShortcuts](mission-maker/scripts/veafShortcuts.en.md) |
| `NAMEDPOINTS` | veafNamedPoints | [veafNamedPoints](mission-maker/scripts/veafNamedPoints.en.md) |
| `ASSETS` | veafAssets | [veafAssets](mission-maker/scripts/veafAssets.en.md) |
| `CARRIER` | veafCarrierOperations | [veafCarrierOperations](mission-maker/scripts/veafCarrierOperations.en.md) |
| `ASSIST` | veafAssist | [veafAssist](mission-maker/scripts/veafAssist.en.md) |
| `SANCTUARY` | veafSanctuary | [veafSanctuary](mission-maker/scripts/veafSanctuary.en.md) |
| `COMBATZONE` | veafCombatZone | [veafCombatZone](mission-maker/scripts/veafCombatZone.en.md) |
| `AIRWAVES` | veafAirWaves | [veafAirWaves](mission-maker/scripts/veafAirWaves.en.md) |
| `QRA` | veafQraManager | [veafQraManager](mission-maker/scripts/veafQraManager.en.md) |
| `CASMISSION` | veafCasMission | [veafCasMission](mission-maker/scripts/veafCasMission.en.md) |
| `COMBATMISSION` | veafCombatMission | — |
| `SPAWN` | veafSpawn | [veafSpawn](mission-maker/scripts/veafSpawn.en.md) |
| `MOVE` | veafMove | [veafMove](mission-maker/scripts/veafMove.en.md) |
| `SECURITY` | veafSecurity | [veafSecurity](mission-maker/scripts/veafSecurity.en.md) |
| `GRASS` | veafGrass | [veafGrass](mission-maker/scripts/veafGrass.en.md) |
| `WEATHER` | veafWeather | [veafWeather](mission-maker/scripts/veafWeather.en.md) |
| `INTERPRETER` | veafInterpreter | [veafInterpreter](mission-maker/scripts/veafInterpreter.en.md) |
| `MISSILEGUARDIAN` | veafMissileGuardian | [veafMissileGuardian](mission-maker/scripts/veafMissileGuardian.en.md) |
| `TRANSPORTMISSION` | veafTransportMission | [veafTransportMission](mission-maker/scripts/veafTransportMission.en.md) |
| `AIRBASES` | veafAirbases | [veafAirbases](mission-maker/scripts/veafAirbases.en.md) |
| `GROUNDAI` | veafGroundAI | — |
| `REMOTE` | veafRemote | — |
| `SKYNET_MONITOR` | veafSkynetMonitor | — |
| `I18N` | veafI18n | — |

---

### `modules.RADIO.user_menus` — F10 radio menus in YAML

Since ADR 0011, a mission maker can declare a custom F10 radio menu (in particular for the Mission Master) **entirely in YAML**, with no Lua, under `modules.RADIO.user_menus`.

```yaml
modules:
  RADIO:
    user_menus:
      restrict_to_group: "MM Ctrl"   # optional: name of a DCS group; menu restricted to that group. Omitted = global.
      tree:
        - menu: "QRA Control"
          items:
            - { command: "Start QRA North", action: qra.start, qra: "QRA-North" }
            - { command: "Stop QRA North",  action: qra.stop,  qra: "QRA-North" }
        - { command: "Global message", action: message, text: "The mission is starting!" }
        - { command: "Custom function", action: lua, function: "myMission.startEverything", args: ["alpha", 3] }
```

Each node of `tree` is either a submenu (`{ menu: "...", items: [...] }`, recursive) or a command (`{ command: "...", action: <verb>, <keys> }`). The action vocabulary is closed (`qra.start`/`qra.stop`, `airwave.start`/`airwave.stop`/`airwave.reset`, `flag.on`/`flag.off`/`flag.set`/`flag.increment`/`flag.decrement`, `message`, `lua`). A `lua` action references a function defined in `mission-script.lua`: if the function is missing, the build fails.

See the full schema, the action table and a detailed example in [veafRadio → Radio menus in YAML](mission-maker/scripts/veafRadio.en.md#radio-menus-in-yaml).

---

### `modules.QRA`, `cap_missions:`, `combat_missions:`

QRA definitions live under `modules.QRA` (`silence_all` + `definitions:`). The `cap_missions:` / `combat_missions:` sections remain top-level. All require the corresponding modules enabled under `modules:`.

See the respective module pages for full schema:
- [`modules.QRA`](mission-maker/scripts/veafQraManager.en.md#configuration-missionyaml) — Quick Reaction Alert definitions
- [`cap_missions:` and `combat_missions:`](mission-maker/scripts/veafCasMission.en.md#configuration-missionyaml) — CAP and combat mission definitions

> **Radio menu shortcut (QRA / AirWaves).** A QRA definition (`modules.QRA.definitions[]`) or an AirWave zone (`modules.AIRWAVES.airwave_zones[]`) accepts `radio_menu: true` (and the optional `radio_menu_restrict_to_group: "<DCS group>"`) to automatically generate an F10 control submenu (start/stop, plus reset for AirWaves). See [veafQraManager](mission-maker/scripts/veafQraManager.en.md#configuration-missionyaml) and [veafAirWaves](mission-maker/scripts/veafAirWaves.en.md#configuration-missionyaml).

---

### `community_scripts:` *(legacy)* {#community-scripts}

> **Deprecated.** Community scripts are now configured in the unified [`modules:`](#modules) block using their uppercase IDs (e.g. `CTLD: true`). The separate `community_scripts:` section still works but emits a deprecation warning. See [`modules:`](#modules) for the current syntax and the list of community IDs.

---

### `custom_scripts:` {#custom-scripts}

Declares custom Lua scripts present in `src/scripts/` that are not part of the standard VEAF v6 set.  
A declared script is included in the `.miz` **without** triggering a warning. By default a DCS load trigger is generated for it automatically; setting `generate_load_trigger: false` disables that trigger (useful when the script is loaded manually from `mission-script.lua`).

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `generate_load_trigger` | `bool` | `true` | Global default: generate a DCS trigger for all scripts in the list |
| `scripts[].path` | `string` | *(required)* | Path to the file, relative to the mission folder (e.g. `src/scripts/FgMission.lua`) |
| `scripts[].generate_load_trigger` | `bool` | *(global default)* | Per-script override; if absent, the global default applies |
| `scripts[].delay_seconds` | `number` | *(none)* | Load this script **after** this delay (seconds) instead of with the rest. See below |

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

**Loading a script after a delay: `delay_seconds`**

By default every mission script is loaded in one go at start-up. Some scripts need time to pass before
they start — typically because they **inventory the world once** and must let the scripts before them
create their units first. AIEN in Foothold is exactly that: loaded 12 seconds after the rest.

```yaml
custom_scripts:
  scripts:
    - path: src/scripts/Moose.lua
    - path: src/scripts/zoneCommander.lua
    - path: src/scripts/AIEN.lua
      delay_seconds: 12          # its own trigger, 12 s in
```

- **Absent** (the default) → loaded in the shared trigger, exactly as before.
- **Present** → the script leaves the shared trigger for a `triggerOnce` of its own, gated on
  `c_time_after`. Scripts sharing the **same** delay share one trigger, in declaration order.
- The delay must be **greater than zero**. A zero, negative or non-numeric value is refused with a build
  warning and the script loads in the shared trigger instead — it is never lost.

> **The delay decides the order, not the position in the list.** A script at `delay_seconds: 12` loads
> after **every** undelayed one, wherever it is written. If a delayed script is declared before an
> undelayed one, the build warns you — the list then reads in a different order from the one it runs in.

**Dynamic builds behave the same way**: `veafDynamicConfig.lua` schedules the load instead of doing it
inline. Since `generate_load_trigger` governs both modes, a delay could not exist in only one of them.

`convert-other` **detects** these delays in the source mission and writes `delay_seconds:` for you, so an
adopted mission reproduces the upstream staging without you having to notice it.

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

Build the dev variant with `veaf-tools mission build --profile DEV` (it loads `FgMission.lua` + `FgDebug.lua`); the default build loads only `FgMission.lua`.

> ⚠️ **Pitfall**: profile deep-merge **replaces lists, it does not concatenate them** (see [`profiles:`](#profiles)). The profile's `custom_scripts.scripts` must therefore **repeat** the base scripts and add the variant-specific one — otherwise the base scripts are lost in that profile.

---

### `pipeline:` {#pipeline}

Controls the optional build pipeline steps. See the [Pipeline Reference](PIPELINE_REFERENCE.en.md) for the full schema of each step's config file.

Each step accepts either a **scalar** value (`true`/`false` to enable or skip the step) or a **mapping** of detailed options.

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

On top of the scalar form, the `presets` step accepts a mapping that keeps the radio injection while suppressing the PNG kneeboard plates globally:

```yaml
pipeline:
  presets:
    enabled: true       # default true — inject radio presets; false = disable the whole step
    kneeboards: false   # default true — when false, no kneeboard PNG (KNEEBOARD/<type>/IMAGES/presets[-<coalition>].png) is generated
```

The `waypoints` step takes the same kind of mapping, for the automatic injection of the mission's own
bullseye (see [The bullseye, injected for you](mission-maker/GUIDE.en.md#automatic-bullseye)):

```yaml
pipeline:
  waypoints:
    enabled: true       # default true — inject flight plans; false = disable the whole step
    bullseye: false     # default true — when false, no BULLSEYE waypoint is added automatically
```

---

### `build:`

Controls how `veaf-tools mission build` resolves the VEAF scripts bundle.
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

> See the [Developer Mode](developer/GUIDE.en.md#developer-mode) section of the Developer Guide for the full workflow.

---

### `profiles:` {#profiles}

Named build profiles. Each profile is a set of config overrides that deep-merge onto the base `mission.yaml` when you pass `--profile <name>` to `veaf-tools mission build`. Keys absent from the profile retain their base values. Lists are replaced, not concatenated. The `profiles:` key itself is never written to the built mission.

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
.\veaf-tools.exe mission build --profile TEST
.\veaf-tools.exe mission build --profile SERVER
```

> If the named profile does not exist in `mission.yaml`, a warning is emitted and the base config is used unchanged.

---

### `build_variants:` {#build-variants}

A list of build profiles to **emit together**: a single `veaf-tools mission build` then produces **one `.miz` per variant** (the "moulinette" goal — typically Modern and Cold-War from one mission folder, the variant being only a **config** difference). Each variant builds the full pipeline with its merged profile (see [`profiles:`](#profiles)) and its `.miz` is suffixed with the variant name (`<base>_<VARIANT>.miz`).

| Field | Type | Description |
|-------|------|-------------|
| `build_variants` | `list[str]` | Profile names (declared under `profiles:`) to each emit as a distinct `.miz`. |

**Rules**
- Without `build_variants:` (or an empty list) → a single `.miz`, behaviour unchanged.
- `--profile <name>` is the **escape hatch**: it forces building a single variant (that profile), unsuffixed — `build_variants:` is ignored.
- Variants build in declaration order; each name must match a `profiles:` profile (otherwise a warning + base config, like `--profile`).

```yaml
profiles:
  MODERN:
    mission:
      era: MODERN
  COLD_WAR:
    mission:
      era: COLD_WAR

build_variants:
  - MODERN
  - COLD_WAR
```

```powershell
.\veaf-tools.exe mission build          # produces <base>_MODERN.miz AND <base>_COLD_WAR.miz
.\veaf-tools.exe mission build --profile MODERN   # produces only the MODERN variant (unsuffixed)
```

---

## Keys documented elsewhere {#keys-documented-elsewhere}

Four top-level keys are read by the build but explained on the page that introduced them. They are
listed here so that reading this reference does not miss them.

| Key | What it does | Page that documents it |
|-----|--------------|------------------------|
| `conversion_profile` | Names the adoption profile applied to a third-party mission (imposed modules, incompatibilities refused at validation) | [`convert-other`](mission-maker/CONVERT_OTHER.en.md) |
| `config_override` | Injects raw configuration values over the ones the profile decided | [`convert-other`](mission-maker/CONVERT_OTHER.en.md) |
| `strip_native_triggers` | Lists the original mission's load triggers to remove, so the VEAF scripts are not loaded twice | [`convert-other`](mission-maker/CONVERT_OTHER.en.md) |
| `dcs_bridge` | Injects the `dcs-bridge.lua` bridge into the `.miz` (`enabled`, `lua_path`) — this is what makes data capture from a running DCS possible | [Mission maker's guide](mission-maker/GUIDE.en.md) |

---

## Index by category

The six domains match the French version, and every top-level section of this page appears in
exactly one of them.

### Core

| Section / Field | Description |
|-----------------|-------------|
| [`global_log_level`](#global_log_level) | Force a log level on all modules |
| [`mission:`](#mission) | Mission name, era, export path |
| [`settings:`](#settings) | Arbitrary `veaf.config.KEY = value` pairs |
| [`veaf_tools:`](#veaf_tools) | Version compatibility constraint |
| [`modules:`](#modules) | Enable, disable and configure each Lua module |
| [Keys documented elsewhere](#keys-documented-elsewhere) | `conversion_profile`, `config_override`, `strip_native_triggers`, `dcs_bridge` |

### Security

| Section / Field | Description |
|-----------------|-------------|
| [`security:`](#security) | Enable/disable security, password hashes |
| `modules.SECURITY` | [veafSecurity](mission-maker/scripts/veafSecurity.en.md) |

### Combat

| Section / Field | Description |
|-----------------|-------------|
| [`modules.QRA`](#modulesqra-cap_missions-combat_missions) | QRA definitions |
| [`cap_missions:`](#modulesqra-cap_missions-combat_missions) | CAP mission definitions |
| [`combat_missions:`](#modulesqra-cap_missions-combat_missions) | Combat mission definitions |
| `modules.COMBATZONE` | [veafCombatZone](mission-maker/scripts/veafCombatZone.en.md) |
| `modules.AIRWAVES` | [veafAirWaves](mission-maker/scripts/veafAirWaves.en.md) |
| `modules.CASMISSION` | [veafCasMission](mission-maker/scripts/veafCasMission.en.md) |

### Air Defense

| Section / Field | Description |
|-----------------|-------------|
| [`modules.SKYNET`](#third-party-modules) | Skynet IADS integration |
| `modules.SANCTUARY` | [veafSanctuary](mission-maker/scripts/veafSanctuary.en.md) |
| `modules.MISSILEGUARDIAN` | [veafMissileGuardian](mission-maker/scripts/veafMissileGuardian.en.md) |

### Assets & Support

| Section / Field | Description |
|-----------------|-------------|
| `modules.ASSETS` | [veafAssets](mission-maker/scripts/veafAssets.en.md) |
| `modules.CARRIER` | [veafCarrierOperations](mission-maker/scripts/veafCarrierOperations.en.md) |
| `modules.NAMEDPOINTS` | [veafNamedPoints](mission-maker/scripts/veafNamedPoints.en.md) |
| `modules.RADIO` | [veafRadio](mission-maker/scripts/veafRadio.en.md) |
| [`modules.RADIO.user_menus`](#modulesradiouser_menus--f10-radio-menus-in-yaml) | F10 radio menus declared in YAML |
| `modules.SHORTCUTS` | [veafShortcuts](mission-maker/scripts/veafShortcuts.en.md) |
| `modules.ASSIST` | [veafAssist](mission-maker/scripts/veafAssist.en.md) |
| [`modules.CTLD` / `modules.CSAR`](#third-party-modules) | Cargo transport and pilot recovery (third-party sidecars) |

### Build Pipeline

| Section / Field | Description |
|-----------------|-------------|
| [`pipeline:`](#pipeline) | Pipeline step control |
| `pipeline.presets` | [presets.yaml schema](PIPELINE_REFERENCE.en.md#pipeline-step-1-presets) |
| `pipeline.waypoints` | [waypoints.yaml schema](PIPELINE_REFERENCE.en.md#pipeline-step-2-waypoints) |
| `pipeline.spawnable_aircrafts` / `pipeline.dynamic_slot_templates` | [aircraft groups schema](PIPELINE_REFERENCE.en.md#pipeline-step-3-aircraft-groups) |
| `pipeline.weather` | [versions.yaml schema](PIPELINE_REFERENCE.en.md#pipeline-step-6-versions) |
| [`custom_scripts:`](#custom-scripts) | Custom Lua scripts to include in the mission |
| [`community_scripts:`](#community-scripts) | Bundled community scripts *(legacy form)* |
| [`build:`](#build) | Developer mode and scripts path override |
| `build.dev_mode` | Use local Lua bundle instead of published scripts |
| `build.scripts_path` | Path to local VEAF-Mission-Creation-Tools clone |
| [`profiles:`](#profiles) | Named build profiles (deep-merge overrides for `--profile`) |
| [`build_variants:`](#build-variants) | Produce one `.miz` variant per named profile |

---

## Index by module

| Module | mission.yaml key | Doc page |
|--------|-----------------|----------|
| veafRadio | `modules.RADIO` | [veafRadio](mission-maker/scripts/veafRadio.en.md#configuration-missionyaml) |
| veafShortcuts | `modules.SHORTCUTS` | [veafShortcuts](mission-maker/scripts/veafShortcuts.en.md#configuration-missionyaml) |
| veafNamedPoints | `modules.NAMEDPOINTS` | [veafNamedPoints](mission-maker/scripts/veafNamedPoints.en.md#configuration-missionyaml) |
| veafCarrierOperations | `modules.CARRIER` | [veafCarrierOperations](mission-maker/scripts/veafCarrierOperations.en.md#configuration-missionyaml) |
| veafAssets | `modules.ASSETS` | [veafAssets](mission-maker/scripts/veafAssets.en.md#configuration-missionyaml) |
| veafAssist | `modules.ASSIST` | [veafAssist](mission-maker/scripts/veafAssist.en.md#enable) |
| veafSanctuary | `modules.SANCTUARY` | [veafSanctuary](mission-maker/scripts/veafSanctuary.en.md#configuration-missionyaml) |
| veafCombatZone | `modules.COMBATZONE` | [veafCombatZone](mission-maker/scripts/veafCombatZone.en.md#configuration-missionyaml) |
| veafAirWaves | `modules.AIRWAVES` | [veafAirWaves](mission-maker/scripts/veafAirWaves.en.md#configuration-missionyaml) |
| veafQraManager | `modules.QRA` | [veafQraManager](mission-maker/scripts/veafQraManager.en.md#configuration-missionyaml) |
| veafCasMission | `cap_missions:` + `combat_missions:` | [veafCasMission](mission-maker/scripts/veafCasMission.en.md#configuration-missionyaml) |

---

## See Also

- [Pipeline Reference](PIPELINE_REFERENCE.en.md) — YAML schemas for presets, waypoints, spawnables, dynamic-slot-templates, warehouses, spawn-groups, versions
- [Mission Maker Guide](mission-maker/GUIDE.en.md) — complete workflow
- [Lua API Reference](LUA_API_REFERENCE.en.md) — Lua builder chain API for advanced use
