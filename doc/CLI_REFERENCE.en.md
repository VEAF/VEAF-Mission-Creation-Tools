# CLI reference — `veaf-tools`

All **25 `veaf-tools` commands**, with their arguments and **every** option. This is a reference
page: it says what each command accepts, not how to take a mission from start to finish. For that,
read the [mission maker's guide](mission-maker/GUIDE.en.md), which tells the story in order, and the
[pipeline reference](PIPELINE_REFERENCE.en.md), which details each build step.

The tools that are **not** `veaf-tools` — `veaf-tools-updater` for updating and `veaf-build` for
publishing — live in [TOOLS_REFERENCE](TOOLS_REFERENCE.en.md).

## How to read this page {#how-to-read}

**Commands are grouped by theme**: `veaf-tools convert v5` rather than
`veaf-tools convert-v5`. The old flat spelling is still registered and still works — your scripts
and shortcuts need no change — it is merely hidden from `--help`. Each command states its flat alias
below its table.

Three things hold for **every** command:

- **`--lang fr` / `--lang en`** is a global option and goes before the command:
  `veaf-tools --lang en mission build`. It changes the language of the messages *and* of the help.
- **Every boolean flag has an automatic negative form.** `--dev-mode` is cancelled by
  `--no-dev-mode`; the tables below list only the positive spelling.
- **A command invoked without a required option opens the interactive wizard** instead of failing,
  pre-filled with what you already typed. `--tui` forces it, and so does a bare invocation.

Finally, `--verbose`, `--pause` and `--readme` recur on most commands and mean the same thing
everywhere: show detailed debug output, wait for a keypress before exiting, print the command's
README. They are still listed command by command, because an incomplete reference sends you looking
somewhere else.

**With no terminal, no command asks a question.** In a CI job, a batch file, or an invocation whose
output is captured, confirmations are skipped and the command runs to the end: `veaf-tools about`
prints its information and exits `0` (it used to print `Aborted.` and exit `1`), `--readme` prints
the README, and an overwrite confirmation answers "no" — pass `--force` when you really do mean to
overwrite.

## What this page guarantees {#coverage}

The option tables are **enumerated from the code's signatures**, not copied by hand, and the CI
documentation check refuses an option that does not appear here. That is what `capture-map
--parking` lacked — it shipped with no documentation at all, through a green CI.

---

## Missions — `veaf-tools mission`

### `veaf-tools mission build` {#build}

Build a DCS mission (.miz) from a VEAF mission folder.

| Name | Type | Required | Description |
|---|---|---|---|
| `MISSION_NAME_OR_FILE` | `str` | no | Mission name; will build the mission with this name and the current date; can be set to a .miz file. Default `mission.miz`. |
| `MISSION_FOLDER` | `str` | no | Folder with the mission files. Default `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--readme` | `boolean` | `false` | Provide access to the README file. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--no-veaf-triggers` | `boolean` | `false` | If set, the VEAF triggers will not be injected in the resulting mission. |
| `--dynamic-mode` | `boolean` | *(none)* | If set, the mission will dynamically load the scripts from the provided location (via --scripts-path or in the local published and src/scripts folders). |
| `--dev-mode` | `boolean` | *(none)* | Resolve VEAF scripts from a local dev repo (build/veaf-scripts.lua) instead of published/. Requires --scripts-path pointing to the VEAF-Mission-Creation-Tools repo root. This setting is persisted in mission.yaml (build.dev_mode). |
| `--scripts-path` | `str` | *(none)* | Path to the VEAF and community scripts. Persisted in mission.yaml (build.scripts_path). |
| `--profile` / `-p` | `str` | *(none)* | Apply a named build profile from mission.yaml (e.g. TEST or SERVER). Profile keys deep-merge onto the base config. |
| `--migrate-from-v5` | `boolean` | `true` | If set, the builder will parse the mission for old v5 triggers and remove them. |
| `--log-modules` | `str` | *(none)* | Comma-separated list of module IDs to keep at full log level. All other modules are silenced to 'error' level. Example: --log-modules 'SPAWN,RADIO' |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools mission build MaMission --profile PROD
```

*Flat alias : `veaf-tools build`*

**See also** : [PIPELINE_REFERENCE.md](PIPELINE_REFERENCE.en.md)

### `veaf-tools mission export` {#export}

Export a .miz or mission folder to JSON/YAML/Markdown (pure-Python parse, never runs Lua).

| Name | Type | Required | Description |
|---|---|---|---|
| `MISSION_NAME_OR_FILE` | `str` | no | The .miz file or extracted mission folder to export. Default `mission.miz`. |
| `OUTPUT` | `str` | no | Output file; written to stdout when omitted. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--format` / `-f` | `str` | `json` | Output format: json (default), yaml or markdown. |
| `--compact` | `boolean` | `false` | For JSON, emit without indentation. |
| `--extract-dir` | `str` | *(none)* | When the input is a .miz, extract its embedded resources (scripts, l10n sounds/images) into this directory. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools mission export MaMission.miz --format yaml --output mission.yaml
```

*Flat alias : `veaf-tools export`*

**See also** : [developer/export-json-contract.md](developer/export-json-contract.en.md)

### `veaf-tools mission extract` {#extract}

Extract a .miz mission file into a folder.

| Name | Type | Required | Description |
|---|---|---|---|
| `MISSION_NAME_OR_FILE` | `str` | no | Mission name; will extract from the mission with this name (most recent .miz file); can be set to a .miz file. Default `mission.miz`. |
| `MISSION_FOLDER` | `str` | no | Folder where the mission files will be extracted. Default `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--readme` | `boolean` | `false` | Provide access to the README file. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools mission extract MaMission.miz ./src/mission
```

*Flat alias : `veaf-tools extract`*

### `veaf-tools mission prepare` {#prepare}

Initialize a VEAF mission folder with default templates.

| Name | Type | Required | Description |
|---|---|---|---|
| `MISSION_FOLDER` | `str` | no | Folder to initialize as a VEAF mission folder. Default `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--template` / `-t` | `str` | *(none)* | Module preset for the generated mission.yaml: minimal | standard | full | custom (custom = pick modules interactively). Omit to keep the shipped default. On a folder that already has a `mission.yaml`, the template is applied only if you agree to replace that file (or with `--force`): keeping yours leaves it untouched, and the command says so. |
| `--list-templates` | `boolean` | `false` | List the available templates and exit. |
| `--theatre` | `str` | *(none)* | Lay down a synthetic blank mission for this DCS theatre into src/mission (no DCS round-trip). Omit to leave src/mission empty. |
| `--list-theatres` | `boolean` | `false` | List the theatres a blank mission can be generated for, and exit. |
| `--readme` | `boolean` | `false` | Provide access to the README file. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--force` | `boolean` | `false` | Do not ask before replacing existing files (same as pressing A). |

```bash
veaf-tools mission prepare MaMission --template
```

*Flat alias : `veaf-tools prepare`*

**See also** : [mission-maker/GUIDE.md](mission-maker/GUIDE.en.md)

### `veaf-tools mission validate` {#validate}

Validate a mission folder before build: report config and runtime issues, exit non-zero on error.

| Name | Type | Required | Description |
|---|---|---|---|
| `MISSION_FOLDER` | `str` | no | Folder containing the mission files to validate. Default `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--strict` | `boolean` | `false` | Treat warnings as errors (exit non-zero if any warning). |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools mission validate .
```

*Flat alias : `veaf-tools validate`*

**See also** : [mission-maker/GUIDE.md](mission-maker/GUIDE.en.md)

## Conversion — `veaf-tools convert`

### `veaf-tools convert generate-config` {#generate-config}

Generate a documented mission.yaml template for a mission folder.

| Options | Type | Default | Description |
|---|---|---|---|
| `--output` | `str` | `.` | Output directory for the generated mission.yaml template. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools convert generate-config
```

*Flat alias : `veaf-tools generate-config`*

**See also** : [MISSION_YAML_REFERENCE.md](MISSION_YAML_REFERENCE.en.md)

### `veaf-tools convert migrate-config` {#migrate-config}

Migrate a missionConfig.lua to v6 format (mission-script.lua).

| Name | Type | Required | Description |
|---|---|---|---|
| `INPUT_FILE` | `str` | yes | Path to the missionConfig.lua to migrate (v5 → v6). |

| Options | Type | Default | Description |
|---|---|---|---|
| `--output` | `str` | *(none)* | Output path for the migrated file. Defaults to <input>_v6.lua next to the input. |
| `--yaml-output` | `str` | *(none)* | Write the lua_modules YAML snippet to this file instead of printing it. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools convert migrate-config ./src
```

*Flat alias : `veaf-tools migrate-config`*

**See also** : [mission-maker/MIGRATION_GUIDE.md](mission-maker/MIGRATION_GUIDE.en.md)

### `veaf-tools convert other` {#convert-other}

Adopt a third-party (non-VEAF) .miz mission onto the v6 toolchain.

| Name | Type | Required | Description |
|---|---|---|---|
| `INPUT_MIZ` | `str` | no | Path to the third-party mission to adopt: a .miz, or a release .zip containing exactly one (the rest of the archive is ignored). Default `mission.miz`. |
| `OUTPUT_FOLDER` | `str` | no | Output mission folder to create or populate. Default `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--force` | `boolean` | `false` | Overwrite an existing mission.yaml without asking. |
| `--report-file` | `str` | *(none)* | Save the conversion report to a Markdown file. Defaults to <output_folder>/convert-other-report.md. |
| `--profile` | `str` | *(none)* | Conversion profile tailoring the scaffold (bundled name, e.g. 'foothold', or a path to a .yaml profile). Without it, a generic 'minimal' scaffold is produced. |
| `--update` | `boolean` | `false` | Re-import a fresher upstream .miz into an already-adopted folder: refresh the third-party scripts and mission base, preserve the tuned mission.yaml, and report scripts added/removed/updated upstream. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools convert other Foothold.miz ./foothold
```

*Flat alias : `veaf-tools convert-other`*

**See also** : [mission-maker/CONVERT_OTHER.md](mission-maker/CONVERT_OTHER.en.md)

### `veaf-tools convert v5` {#convert-v5}

Convert a v5-style VEAF mission folder to v6 format.

| Name | Type | Required | Description |
|---|---|---|---|
| `MISSION_FOLDER` | `str` | no | Path to the VEAF mission folder to convert (where mission.yaml should be created). Default `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--force` | `boolean` | `false` | Overwrite existing mission.yaml without asking. |
| `--no-backup` | `boolean` | `false` | Do not create a .bak copy of missionConfig.lua before migrating it. |
| `--no-convert-pipeline` | `boolean` | `false` | Skip automatic conversion of v5 pipeline config files (presets, waypoints, weather, aircraft groups). Files will be listed as needing manual conversion instead. |
| `--no-promote` | `boolean` | `false` | Do not promote src/mission/ to v6 (skip the base build + extract round-trip). |
| `--report-file` | `str` | *(none)* | Save the conversion report to a Markdown file. Defaults to <mission_folder>/convert-v5-report.md. |
| `--icao` | `str` | `` | ICAO airport code to use for realweather pipeline steps (e.g. UGGG). Skips the interactive prompt. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools convert v5 . --icao UGKO
```

*Flat alias : `veaf-tools convert-v5`*

**See also** : [mission-maker/MIGRATION_GUIDE.md](mission-maker/MIGRATION_GUIDE.en.md)

## Mission content — `veaf-tools content`

### `veaf-tools content extract-aircraft-groups` {#extract-aircraft-groups}

Extract aircraft group templates from a .miz mission to a YAML file.

| Name | Type | Required | Description |
|---|---|---|---|
| `MISSION_NAME_OR_FILE` | `str` | no | Mission name; will extract from the mission with this name (most recent .miz file); can be set to a .miz file. Default `mission.miz`. |
| `MISSION_FOLDER` | `str` | no | Folder with the mission files. Default `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--readme` | `boolean` | `false` | Provide access to the README file. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--interactive` | `boolean` | `false` | Interactive mode: select which groups to include. |
| `--kind` | `str` | `both` | Which families to extract: 'both' (default), 'spawnable' or 'dynamic-template'. |
| `--output-spawnables` | `str` | `src/spawnables.yaml` | Output path for spawnable aircraft groups (veafSpawn- prefix). |
| `--output-dynamic-templates` | `str` | `src/dynamic-slot-templates.yaml` | Output path for dynamic-slot templates (dynSpawnTemplate=true). |
| `--group-name-pattern` | `str` | `.*` | Regular expression pattern to match aircraft group names. |
| `--merge` | `boolean` | `false` | Merge into the output files instead of replacing them: groups the mission does not have are kept, a group of the same name is replaced by the mission's version and named in the report. |
| `--only-airplanes` | `boolean` | `false` | Extract only airplanes. |
| `--only-helicopters` | `boolean` | `false` | Extract only helicopters. |
| `--lua-input` | `str` | *(none)* | Path to a Lua file (e.g., settings-templates.lua) to extract from instead of a .miz mission. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools content extract-aircraft-groups MaMission.miz aircraft-templates.yaml
```

*Flat alias : `veaf-tools extract-aircraft-groups`*

**See also** : [PIPELINE_REFERENCE.md](PIPELINE_REFERENCE.en.md)

### `veaf-tools content inject-aircraft-groups` {#inject-aircraft-groups}

Inject aircraft group templates from a YAML file into a .miz mission.

| Name | Type | Required | Description |
|---|---|---|---|
| `MISSION_NAME_OR_FILE` | `str` | no | Mission name; will inject into the mission with this name (most recent .miz file); can be set to a .miz file. Default `mission.miz`. |
| `OUTPUT_MISSION` | `str` | no | Mission file to save; defaults to the same as input. |
| `MISSION_FOLDER` | `str` | no | Folder with the mission files. Default `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--readme` | `boolean` | `false` | Provide access to the README file. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--mode` | `str` | `add` | Injection mode: 'add' (add new groups) or 'replace' (replace existing groups). |
| `--template-file` | `str` | `src/spawnables.yaml` | Path to the YAML file containing aircraft groups. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools content inject-aircraft-groups MaMission.miz aircraft-templates.yaml out.miz
```

*Flat alias : `veaf-tools inject-aircraft-groups`*

**See also** : [PIPELINE_REFERENCE.md](PIPELINE_REFERENCE.en.md)

### `veaf-tools content inject-presets` {#inject-presets}

Inject radio presets from a YAML file into a .miz mission.

| Name | Type | Required | Description |
|---|---|---|---|
| `INPUT_MISSION_NAME_OR_FILE` | `str` | no | Mission name; will inject in the mission with this name (most recent .miz file); can be set to a .miz file. Default `mission.miz`. |
| `OUTPUT_MISSION` | `str` | no | Mission file to save; defaults to the same as input. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--readme` | `boolean` | `false` | Provide access to the README file. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--presets-file` | `str` | `./src/presets.yaml` | Configuration file containing the presets. |
| `--validate-report` | `str` | *(none)* | Write a Markdown validation report of all frequency issues to this file (reports ALL aircraft types, not only DCS-critical ones). |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools content inject-presets MaMission.miz ./src/presets.yaml
```

*Flat alias : `veaf-tools inject-presets`*

**See also** : [PIPELINE_REFERENCE.md](PIPELINE_REFERENCE.en.md)

### `veaf-tools content extract-waypoints` {#extract-waypoints}

Extract waypoints from a .miz mission to a YAML file.

| Name | Type | Required | Description |
|---|---|---|---|
| `MISSION_NAME_OR_FILE` | `str` | no | Mission name; will extract from the mission with this name (most recent .miz file); can be set to a .miz file. Default `mission.miz`. |
| `MISSION_FOLDER` | `str` | no | Folder with the mission files. Default `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--readme` | `boolean` | `false` | Provide access to the README file. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--interactive` | `boolean` | `false` | Interactive mode: select which groups to extract. |
| `--output-yaml` | `str` | `waypoints.yaml` | Output YAML file path. |
| `--group-name-pattern` | `str` | `.*` | Regular expression pattern to match waypoint/group names. |
| `--only-airplanes` | `boolean` | `false` | Extract only airplanes. |
| `--only-helicopters` | `boolean` | `false` | Extract only helicopters. |
| `--lua-input` | `str` | *(none)* | Path to a Lua file (e.g., settings-waypoints.lua) to extract from instead of a .miz mission. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools content extract-waypoints MaMission.miz waypoints.yaml
```

*Flat alias : `veaf-tools extract-waypoints`*

**See also** : [PIPELINE_REFERENCE.md](PIPELINE_REFERENCE.en.md)

### `veaf-tools content inject-waypoints` {#inject-waypoints}

Inject waypoints from a YAML file into a .miz mission.

| Name | Type | Required | Description |
|---|---|---|---|
| `MISSION_NAME_OR_FILE` | `str` | no | Mission name; will inject into the mission with this name (most recent .miz file); can be set to a .miz file. Default `mission.miz`. |
| `OUTPUT_MISSION` | `str` | no | Mission file to save; defaults to the same as input. |
| `MISSION_FOLDER` | `str` | no | Folder with the mission files. Default `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--readme` | `boolean` | `false` | Provide access to the README file. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--waypoints-file` | `str` | `waypoints.yaml` | Path to the YAML file containing waypoint definitions. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools content inject-waypoints MaMission.miz waypoints.yaml out.miz
```

*Flat alias : `veaf-tools inject-waypoints`*

**See also** : [PIPELINE_REFERENCE.md](PIPELINE_REFERENCE.en.md)

### `veaf-tools content inject-weather` {#inject-weather}

Inject weather variants from a YAML config into .miz missions.

| Name | Type | Required | Description |
|---|---|---|---|
| `MISSION_NAME_OR_FILE` | `str` | no | Mission name or .miz file to use as base for creating weather/time variants. Default `mission.miz`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--readme` | `boolean` | `false` | Provide access to the README file. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--config-file` | `str` | `versions.yaml` | Path to YAML configuration file (or Lua file to convert). |
| `--convert-lua` | `boolean` | `false` | Convert legacy Lua configuration to YAML and exit. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools content inject-weather MaMission
```

*Flat alias : `veaf-tools inject-weather`*

**See also** : [PIPELINE_REFERENCE.md](PIPELINE_REFERENCE.en.md)

## Cockpit — `veaf-tools cockpit`

### `veaf-tools cockpit explore-cockpit` {#explore-cockpit}

Explore a live cockpit: name a control to see it, or move one to name it.

| Name | Type | Required | Description |
|---|---|---|---|
| `AIRCRAFT` | `str` | yes | DCS type name of the aircraft you are sitting in, e.g. F-14BU. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--control` | `str` | *(none)* | Box this control before watching, described in plain words. |
| `--serve-url` | `str` | `http://127.0.0.1:8080` | dcs-serve base URL. |
| `--api-key` | `str` | *(none)* | dcs-serve superuser Bearer token. (environment variable `DCS_BRIDGE_API_KEY`) |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |

```bash
veaf-tools cockpit explore-cockpit "main pwr"
```

*Flat alias : `veaf-tools explore-cockpit`*

**See also** : [mission-maker/scripts/veafAssist.md](mission-maker/scripts/veafAssist.en.md)

### `veaf-tools cockpit resolve-checklist` {#resolve-checklist}

Fill in the technical fields of a guided checklist written in plain words.

| Name | Type | Required | Description |
|---|---|---|---|
| `CHECKLIST_FILE` | `str` | yes | The checklist YAML to resolve, in place. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--dry-run` | `boolean` | `false` | Show what would be written, without touching the file. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools cockpit resolve-checklist checklists/f16c-start.yaml
```

*Flat alias : `veaf-tools resolve-checklist`*

**See also** : [mission-maker/scripts/veafAssist.md](mission-maker/scripts/veafAssist.en.md)

### `veaf-tools cockpit verify-checklist` {#verify-checklist}

Check a resolved checklist against a real cockpit (needs DCS running here).

| Name | Type | Required | Description |
|---|---|---|---|
| `CHECKLIST_FILE` | `str` | yes | The checklist YAML to verify. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--serve-url` | `str` | `http://127.0.0.1:8080` | dcs-serve base URL. |
| `--api-key` | `str` | *(none)* | dcs-serve superuser Bearer token. (environment variable `DCS_BRIDGE_API_KEY`) |
| `--timeout` | `float` | `60.0` | Seconds to wait for the pilot on each step. |
| `--write` | `boolean` | `false` | Mark the confirmed steps `verified: true` in the file. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools cockpit verify-checklist checklists/f16c-start.yaml
```

*Flat alias : `veaf-tools verify-checklist`*

**See also** : [mission-maker/scripts/veafAssist.md](mission-maker/scripts/veafAssist.en.md)

## Running DCS — `veaf-tools dcs`

### `veaf-tools dcs capture-map` {#capture-map}

Capture a theatre's airbases from a running bridge mission (via dcs-serve) into <theatre>.json.

| Options | Type | Default | Description |
|---|---|---|---|
| `--api-key` | `str` | *(none)* | dcs-serve superuser Bearer token (default: read from dcs-serve.yaml). (environment variable `DCS_BRIDGE_API_KEY`) |
| `--config` | `str` | *(none)* | Path to a dcs-serve.yaml / dcs-client.yaml to read the key from. |
| `--serve-url` | `str` | `http://127.0.0.1:8080` | dcs-serve base URL. |
| `--out-dir` | `str` | `.` | Directory to write <theatre>.json into. |
| `--parking` | `boolean` | `false` | Also capture every airfield's parking slots into parking/<theatre>.json. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |

```bash
veaf-tools dcs capture-map --parking
```

*Flat alias : `veaf-tools capture-map`*

**See also** : [developer/capture-airbases.md](developer/capture-airbases.en.md)

### `veaf-tools dcs inject-bridge` {#inject-bridge}

Embed the dcs-bridge + a start trigger into a .miz, turning it into a bridge mission.

| Name | Type | Required | Description |
|---|---|---|---|
| `MISSION` | `str` | yes | Path to the .miz to turn into a bridge mission (edited in place). |

| Options | Type | Default | Description |
|---|---|---|---|
| `--bridge-lua` | `str` | *(none)* | Local dcs-bridge.lua to embed (default: download the latest). |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |

```bash
veaf-tools dcs inject-bridge MaMission.miz
```

*Flat alias : `veaf-tools inject-bridge`*

**See also** : [developer/dcs-data.md](developer/dcs-data.en.md)

### `veaf-tools dcs smoke-test` {#smoke-test}

Assert VEAF runtime behaviour inside a running DCS, over the dcs-fiddle hook.

| Options | Type | Default | Description |
|---|---|---|---|
| `--url` | `str` | `http://127.0.0.1:12081` | Base URL of the dcs-fiddle-server.lua hook (default: http://127.0.0.1:12081). |
| `--timeout` | `float` | `10.0` | Per-request socket timeout, in seconds. |
| `--probe-only` | `boolean` | `false` | Only report what a running DCS lets the harness do, run no checks. |
| `--full` | `boolean` | `false` | Launch DCS, load --mission, assert, then quit — a full unattended run. |
| `--mission` | `str` | *(none)* | Path to the .miz to load for a --full run. |
| `--dcs-exe` | `str` | *(none)* | Path to DCS.exe for a --full run (default: discovered from a running DCS's install dir). |
| `--allow-running` | `boolean` | `false` | For --full: use a DCS that is already running instead of refusing (it loads the mission over the current session). |
| `--fiddle-token` | `str` | *(none)* | The hook's per-session Basic-auth password (default: read from ~/dcs-fiddle-token.txt, or $DCS_FIDDLE_TOKEN). |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |

```bash
veaf-tools dcs smoke-test
```

*Flat alias : `veaf-tools smoke-test`*

**See also** : [developer/smoke-harness.md](developer/smoke-harness.en.md)

## The tool itself

### `veaf-tools about` {#about}

Show information about VEAF Mission Creation Tools.

| Options | Type | Default | Description |
|---|---|---|---|
| `--modules` | `boolean` | `false` | Show the list of embedded VEAF Lua modules. |

```bash
veaf-tools about
```

### `veaf-tools doctor` {#doctor}

Collect the versions, paths and recent errors a bug report needs: tool version, DCS version, operating system, where the logs live. The command first prints a readable table, then a **block to paste** as-is into a report.

Windows paths carry your account name, so the block is **redacted before it is shown** (`C:\Users\<user>\…`), along with IP addresses and anything shaped like a token. It is safe to publish.

| Options | Type | Default | Description |
|---|---|---|---|
| `--paste` | `boolean` | `false` | Print only the block to paste, without the readable table. |
| `--errors` | `integer` | `3` | How many recent error records from the tool log to include (0 for none). |

```powershell
.\veaf-tools.exe doctor
```

It works with no DCS installed, no `VEAF_HOME` set and no log file: a fact it cannot read reports `unknown` and the rest is produced anyway.

**See also** : [Getting help](SUPPORT.en.md), and [the block format](developer/diagnostic-block.en.md) for whoever consumes it.

### `veaf-tools ask` {#ask}

Ask a question about the VEAF documentation (AI assistant). With no question, starts an interactive session.

| Name | Type | Required | Description |
|---|---|---|---|
| `QUESTION` | `str` | no | The question to ask. Omit to start an interactive session. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |

```bash
veaf-tools ask "comment activer une zone de combat au démarrage ?"
```

The assistant runs on a free allowance shared with the website chatbot: on a busy day it can run
out, and the command says so plainly when it does. See
[the documentation assistant](SUPPORT.en.md#assistant).

### `veaf-tools mcp` {#mcp}

Start the LLM-assisted mission-editing MCP server (stdio). Used by the veaf-mission-editor Claude plugin.

```bash
veaf-tools mcp
```

**See also** : [developer/mission-editing-mcp.md](developer/mission-editing-mcp.en.md)

### `veaf-tools user-config` {#user-config}

Show and manage the global user configuration (~/veafmct.yaml).

| Options | Type | Default | Description |
|---|---|---|---|
| `--set` | `str` | *(none)* | Set a configuration key (format: key=value, e.g. lang=fr). |
| `--unset` | `str` | *(none)* | Remove a configuration key. |
| `--init` | `boolean` | `false` | Create a default ~/veafmct.yaml if it does not exist. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools user-config --show
```
