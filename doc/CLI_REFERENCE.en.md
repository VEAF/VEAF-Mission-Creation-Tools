# CLI reference — `veaf-tools`

All **37 `veaf-tools` commands**, with their arguments and **every** option. This is a reference
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

### `veaf-tools content pull-aircraft-groups` {#pull-aircraft-groups}

List what the aircraft-group catalogue shipped with veaf-tools has that your mission folder does not, and copy in the entries you choose. Without `--add` or `--add-new` the command writes nothing: it only prints the report. **An entry you already have is never replaced**, even when the shipped version differs; it is reported as kept.

| Name | Type | Required | Description |
|---|---|---|---|
| `MISSION_FOLDER` | `str` | no | Folder with the mission files. Defaults to `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--verbose` | `boolean` | `false` | If set, print detailed debug information; also names the kept entries instead of only counting them. |
| `--kind` | `str` | `both` | Which catalogue to work on: 'both' (default), 'spawnable' or 'dynamic-template'. |
| `--add` | `str` | *(none)* | Name of a group to copy in from the shipped catalogue. Repeatable. A name the shipped catalogue does not have stops the command with nothing written. |
| `--add-new` | `boolean` | `false` | Copy in every entry the shipped catalogue has and yours does not. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools content pull-aircraft-groups
veaf-tools content pull-aircraft-groups --kind dynamic-template --add "F-14BU Template"
veaf-tools content pull-aircraft-groups --add-new
```

*Flat alias : `veaf-tools pull-aircraft-groups`*

**See also** : [Dynamic slots](mission-maker/concepts/dynamic-slots.en.md#shipped-catalogue)

### `veaf-tools content airfield-channels` {#airfield-channels}

Lists the airfields the mission uses, most useful first, with the ATC frequencies and TACAN DCS gives them: the side holding each one (`warehouses`), whether it offers dynamic slots once `src/warehouses.yaml` is applied, how many slots are parked on it, and the channel it already has in the `bases` collection. A DCS radio holds about twenty channels: this is the list to choose from. Without `--apply`, the command writes nothing.

With `--apply`, it writes the chosen airfields into the `bases` collection of `src/presets.yaml`, with DCS's frequencies. An airfield already there keeps its alias (the `channel_lists` name it) and the spelling of its title (`Büchel` stays `Büchel` though DCS writes `Buchel`; only the TACAN suffix is refreshed); a new one is aliased `Base-<DCS name>`. An entry matching no chosen airfield (a FARP, a ship) is left as it is and reported. Nothing else changes: neither the tactical and flight channels nor the `channel_lists`. The command reports the written channels that are on no radio yet. An airfield DCS does not declare is refused: **an airfield frequency is never typed by hand**.

| Name | Type | Required | Description |
|---|---|---|---|
| `MISSION_FOLDER` | `str` | no | Mission folder (holds `src/mission/` and `src/presets.yaml`). Default `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--apply` | `str` | *(none)* | Airfield (DCS name or id) to write into the `bases` collection, in the order wanted. Repeatable. |
| `--neutral` | `boolean` | `false` | Also list the airfields no side holds. |
| `--verbose` | `boolean` | `false` | If enabled, displays detailed debug information. |
| `--pause` | `boolean` | `false` | If enabled, the script waits for a key press before exiting. |

```bash
.\veaf-tools.exe content airfield-channels
.\veaf-tools.exe content airfield-channels --apply "Batumi" --apply "Kutaisi" --apply "Vaziani"
```

*Flat alias : `veaf-tools airfield-channels`*

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

## Campaign — `veaf-tools campaign`

A [multi-mission campaign](mission-maker/CAMPAIGN.en.md) is run with these four commands, in the order `init`, then `next` and `apply` for every mission.

### `veaf-tools campaign init` {#campaign-init}

Start a campaign: create its state from campaign.yaml.

| Name | Type | Required | Description |
|---|---|---|---|
| `CAMPAIGN_FOLDER` | `str` | no | Campaign folder, holding campaign.yaml. Default `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

An existing state is never overwritten: it holds the missions already flown.

```powershell
.\veaf-tools.exe campaign init C:\Campaigns\Caucasus
```

*Flat alias : `veaf-tools campaign-init`*

### `veaf-tools campaign validate` {#campaign-validate}

Check a campaign folder: campaign.yaml, and the campaign state against it.

| Name | Type | Required | Description |
|---|---|---|---|
| `CAMPAIGN_FOLDER` | `str` | no | Campaign folder, holding campaign.yaml. Default `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```powershell
.\veaf-tools.exe campaign validate C:\Campaigns\Caucasus
```

*Flat alias : `veaf-tools campaign-validate`*

### `veaf-tools campaign apply` {#campaign-apply}

Apply a flown mission's state file to the campaign, then play the turn between missions.

| Name | Type | Required | Description |
|---|---|---|---|
| `STATE_FILE` | `str` | yes | The state file the mission wrote (Saved Games/DCS/Missions/Saves/<campaign>/mission-NN.state). |
| `CAMPAIGN_FOLDER` | `str` | no | Campaign folder, holding campaign.yaml. Default `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

Refuses a file already applied, one from another campaign, or one that skips a mission; nothing is written then.

```powershell
.\veaf-tools.exe campaign apply mission-01.state C:\Campaigns\Caucasus
```

*Flat alias : `veaf-tools campaign-apply`*

### `veaf-tools campaign next` {#campaign-next}

Create, or refresh, the next mission's folder from the campaign state.

| Name | Type | Required | Description |
|---|---|---|---|
| `CAMPAIGN_FOLDER` | `str` | no | Campaign folder, holding campaign.yaml. Default `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--players` | `str` | — | How many players are expected tonight: a count (`6`) or a range (`5-7`). Sizes the mission's air opposition ([`opposition:` block](mission-maker/scripts/veafQraManager.en.md#opposition-level)), beating `campaign.yaml`'s `players`. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

The folder is copied from `template/` the first time, and only refreshed afterwards: what was designed in it survives.

```powershell
.\veaf-tools.exe campaign next C:\Campaigns\Caucasus
```

*Flat alias : `veaf-tools campaign-next`*

### `veaf-tools campaign briefing` {#campaign-briefing}

Write the coming mission's strategic briefing deck (PPTX), from the campaign and its briefing.yaml.

| Name | Type | Required | Description |
|---|---|---|---|
| `CAMPAIGN_FOLDER` | `str` | no | Campaign folder, holding campaign.yaml. Default `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

Writes `missions/mission-NN/briefing-campagne.pptx` and its map; `campaign next` does too. The prose comes from `briefing.yaml`, the facts from the campaign.

```powershell
.\veaf-tools.exe campaign briefing C:\Campaigns\Caucasus
```

*Flat alias : `veaf-tools campaign-briefing`*

**See also** : [mission-maker/CAMPAIGN.md](mission-maker/CAMPAIGN.en.md)

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

### `veaf-tools dcs clear-ground-sweep` {#clear-ground-sweep}

Sweep a theatre for clear ground, step by step, and write its catalogue. The command:

1. writes an **empty** survey mission into your DCS `Missions` folder. It must stay empty: the DCS
   probe counts vehicles as obstacles, so a unit standing on the map would be taken for forest;
2. makes sure `dcs-serve` runs: the small local server the mission's dcs-bridge script connects to, and the
   sweep goes through. When none answers, the command starts one itself (found next to `veaf-tools.exe`,
   on `PATH`, or through `--dcs-serve`), in a folder of its own, with a generated access key and listening
   on this computer only, and stops it at the end;
3. tells you what to do: allow mission scripts to talk to the outside once (`MissionScripting.lua`), open
   and start the mission, take the spectator slot;
4. waits for you to press Enter, then for the mission to answer;
5. probes the ground around the airfields (and, on request, the combat zones of a mission or given
   points), showing progress. An interrupted sweep resumes where it stopped;
6. writes the catalogue and says DCS can be closed.

The 21 Caucasus airfields take about 4 minutes, one combat zone about ten seconds. DCS freezes for
about 1.5 s at each batch, which does not matter on a mission nobody is flying.

| Name | Type | Required | Description |
|---|---|---|---|
| `THEATRE` | `str` | yes | DCS theatre name, as a mission spells it. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--zones-from` | `str` | *(none)* | Also sweep around the `combatZone...` trigger zones of this .miz. |
| `--around` | `str` | *(none)* | Also sweep around this point, as `x,y` mission coordinates (repeatable). |
| `--airfields` | `boolean` | `true` | Sweep around every airfield of the theatre. |
| `--out` | `str` | `<VEAF home>/clear-ground/<theatre>.clear-ground.json` | The catalogue to write. |
| `--survey-mission` | `str` | `<Saved Games>/DCS/Missions/veaf-survey-<theatre>.miz` | Where to write the survey mission. |
| `--bridge-lua` | `str` | *(none)* | Local dcs-bridge.lua to embed (default: download). |
| `--state-dir` | `str` | `<VEAF home>/clear-ground/sweep-<theatre>` | Where the sweep keeps its progress. |
| `--restart` | `boolean` | `false` | Throw away the progress of a different plan instead of refusing. |
| `--batch` | `int` | `10000` | Cells probed per call to DCS. |
| `--wait` | `int` | `900` | How many seconds to wait for the survey mission to answer. |
| `--api-key` | `str` | *(none)* | dcs-serve superuser Bearer token (default: read from dcs-serve.yaml). (environment variable `DCS_BRIDGE_API_KEY`) |
| `--config` | `str` | *(none)* | Path to a dcs-serve.yaml / dcs-client.yaml to read the key from. |
| `--serve-url` | `str` | `http://127.0.0.1:8080` | dcs-serve base URL. |
| `--dcs-serve` | `str` | *(none)* | The dcs-serve executable to start when none is running (default: next to veaf-tools, or on PATH). |
| `--verbose` | `boolean` | `false` | If enabled, displays detailed debugging information. |

```bash
.\veaf-tools.exe dcs clear-ground-sweep Caucasus --zones-from MyMission.miz
```

*Flat alias : `veaf-tools clear-ground-sweep`*

### `veaf-tools dcs clear-ground-check` {#clear-ground-check}

Check in DCS whether the ground vehicles of a built mission stand in trees or buildings, **without
spawning them**. Their positions are read from the `.miz`, then probed on the empty survey mission: no
vehicle exists there, so none is counted as blocked by its neighbours — which is what happens as soon as
a battery that has already spawned is probed. Each answer is compared with what the clear-ground
catalogue predicted, and a disagreement is reported as a question about the catalogue. Combat-zone
markers (`#command`) are not checked: their group is drawn at runtime, which moves it off scenery
itself. Same flow as `clear-ground-sweep`: `dcs-serve`, survey mission, instructions, waiting.

| Name | Type | Required | Description |
|---|---|---|---|
| `MISSION` | `str` | yes | The .miz to check. It is read, never loaded in DCS. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--survey-mission` | `str` | `<Saved Games>/DCS/Missions/veaf-survey-<theatre>.miz` | Where to write the survey mission. |
| `--bridge-lua` | `str` | *(none)* | Local dcs-bridge.lua to embed (default: download). |
| `--wait` | `int` | `900` | How many seconds to wait for the survey mission to answer. |
| `--report` | `str` | *(none)* | Also write the report as JSON to this file. |
| `--api-key` | `str` | *(none)* | dcs-serve superuser Bearer token (default: read from dcs-serve.yaml). (environment variable `DCS_BRIDGE_API_KEY`) |
| `--config` | `str` | *(none)* | Path to a dcs-serve.yaml / dcs-client.yaml to read the key from. |
| `--serve-url` | `str` | `http://127.0.0.1:8080` | dcs-serve base URL. |
| `--dcs-serve` | `str` | *(none)* | The dcs-serve executable to start when none is running. |
| `--verbose` | `boolean` | `false` | If enabled, displays detailed debugging information. |

```bash
.\veaf-tools.exe dcs clear-ground-check build\MyMission.miz
```

*Flat alias : `veaf-tools clear-ground-check`*

### `veaf-tools dcs scenery-objects` {#scenery-objects}

Lists the **map objects** — bridges, buildings that are part of the map itself — around one or more
points, with their DCS id, their type and their distance to the point, nearest first. That id is what a
combat zone's [`scenery_targets`](mission-maker/scripts/veafCombatZone.en.md#scenery-targets) takes: a
map object is not created by the zone, so the zone can only recognise it by its number, and that number
exists only inside DCS. Same flow as `clear-ground-check`: `dcs-serve`, empty survey mission,
instructions, waiting. Points are in mission coordinates (`x` north, `y` east, metres).

| Name | Type | Required | Description |
|---|---|---|---|
| `THEATRE` | `str` | yes | The theatre, as DCS spells it (Caucasus, Syria…). |

| Options | Type | Default | Description |
|---|---|---|---|
| `--around` | `str` | *(none)* | A point to search around, as `x,y` or `x,y,radius` (radius 150 m by default). Repeatable. |
| `--report` | `str` | *(none)* | Also write the objects as JSON to this file. |
| `--survey-mission` | `str` | `<Saved Games>/DCS/Missions/veaf-survey-<theatre>.miz` | Where to write the survey mission. |
| `--bridge-lua` | `str` | *(none)* | Local dcs-bridge.lua to embed (default: download). |
| `--wait` | `int` | `900` | How many seconds to wait for the survey mission to answer. |
| `--api-key` | `str` | *(none)* | dcs-serve superuser Bearer token (default: read from dcs-serve.yaml). (environment variable `DCS_BRIDGE_API_KEY`) |
| `--config` | `str` | *(none)* | Path of a dcs-serve.yaml / dcs-client.yaml to read the key from. |
| `--serve-url` | `str` | `http://127.0.0.1:8080` | dcs-serve base URL. |
| `--dcs-serve` | `str` | *(none)* | The dcs-serve executable to start when none is running. |
| `--verbose` | `boolean` | `false` | If enabled, prints detailed debugging information. |

```bash
.\veaf-tools.exe dcs scenery-objects Syria --around -64230,352140,100
```

*Flat alias : `veaf-tools scenery-objects`*

### `veaf-tools dcs terrain-sweep` {#terrain-sweep}

Sweeps the **ground elevation** of a whole theatre (`land.getHeight`, every 250 m by default) and writes
it to `<VEAF home>/terrain/<theatre>.terrain`. The MCP action `terrain_elevation` then reads that
grid with no DCS: a target's altitude, the highest ground along a route, terrain masking between a
route and a SAM site. Same flow as `clear-ground-sweep`: `dcs-serve`, empty survey mission,
instructions, waiting; an interrupted sweep resumes where it stopped. The extent swept is the map's,
asked to DCS; when it does not give it, the airfields' plus 50 km, and the command says so. **Terrain
only**: no buildings, pylons or trees.

| Name | Type | Required | Description |
|---|---|---|---|
| `THEATRE` | `str` | yes | The theatre, as DCS spells it (Caucasus, Syria…). |

| Options | Type | Default | Description |
|---|---|---|---|
| `--spacing` | `float` | `250` | Distance between two samples, in metres. |
| `--bounds` | `str` | *(the map's)* | The extent to sweep, as `min_x,min_y,max_x,max_y` (mission coordinates). |
| `--measure-at` | `str` | *(none)* | Instead of sweeping the map, sweep a fine (50 m) 20 km patch around this point `x,y` and report, for each candidate spacing (100, 250, 500, 1000 m), the error at a point and how far a 10 km square's maximum falls short. Repeatable. |
| `--out` | `str` | `<VEAF home>/terrain/` | The grid (or, with `--measure-at`, the report) to write. |
| `--survey-mission` | `str` | `<Saved Games>/DCS/Missions/veaf-survey-<theatre>.miz` | Where to write the survey mission. |
| `--bridge-lua` | `str` | *(none)* | Local dcs-bridge.lua to embed (default: download). |
| `--state-dir` | `str` | `<VEAF home>/terrain/sweep-<theatre>` | Where the sweep keeps its progress. |
| `--restart` | `boolean` | `false` | Throw away the progress of a different plan instead of refusing. |
| `--batch` | `int` | `20000` | Heights read per call to DCS. |
| `--wait` | `int` | `900` | How many seconds to wait for the survey mission to answer. |
| `--api-key` | `str` | *(none)* | dcs-serve superuser Bearer token (default: read from dcs-serve.yaml). (environment variable `DCS_BRIDGE_API_KEY`) |
| `--config` | `str` | *(none)* | Path to a dcs-serve.yaml / dcs-client.yaml to read the key from. |
| `--serve-url` | `str` | `http://127.0.0.1:8080` | dcs-serve base URL. |
| `--dcs-serve` | `str` | *(none)* | The dcs-serve executable to start when none runs. |
| `--verbose` | `boolean` | `false` | If enabled, shows detailed debug information. |

```bash
.\veaf-tools.exe dcs terrain-sweep Caucasus
```

*Flat alias : `veaf-tools terrain-sweep`*

### `veaf-tools dcs smoke-test` {#smoke-test}

Assert VEAF runtime behaviour inside a running DCS, over the dcs-fiddle hook.

| Options | Type | Default | Description |
|---|---|---|---|
| `--url` | `str` | `http://127.0.0.1:12081` | Base URL of the dcs-fiddle-server.lua hook (default: http://127.0.0.1:12081). |
| `--timeout` | `float` | `10.0` | Per-request socket timeout, in seconds. |
| `--suite` | `str` | `default` | Which set of checks to run: `default` (every mission) or `spotter` (the demo-spotter-network rig only). |
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
