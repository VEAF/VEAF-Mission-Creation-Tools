# CLI reference — `veaf-tools`

All **44 `veaf-tools` commands**, with their arguments and **every** option. This is a reference
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
| `--profile` / `-p` | `str` | *(none)* | Apply a named build profile from mission.yaml (e.g. TEST or SERVER). Profile keys deep-merge onto the base config. The `.miz` is suffixed with the profile's name (`_TEST`). |
| `--migrate-from-v5` | `boolean` | `true` | If set, the builder will parse the mission for old v5 triggers and remove them. |
| `--log-modules` | `str` | *(none)* | Comma-separated list of module IDs to keep at full log level. All other modules are silenced to 'error' level. Example: --log-modules 'SPAWN,RADIO' |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools mission build MaMission --profile PROD
```

*Flat alias : `veaf-tools build`*

**See also** : [PIPELINE_REFERENCE.md](PIPELINE_REFERENCE.en.md)

### `veaf-tools mission ctld-upgrade` {#ctld-upgrade}

Bring ctld-config.yaml up to the CTLD catalogue the tools vendor: add the settings it lacks at their default, change nothing else.

| Name | Type | Required | Description |
|---|---|---|---|
| `MISSION_FOLDER` | `str` | no | Folder containing mission.yaml and ctld-config.yaml. Default `.`. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |
| `--pause` | `boolean` | `false` | If set, the script will pause when finished and wait for the user to press a key. |

```bash
veaf-tools mission ctld-upgrade .
```

*Flat alias : `veaf-tools ctld-upgrade`*

**See also** : [mission-maker/build-messages/modules.en.md](mission-maker/build-messages/modules.en.md#validate-ctld-catalogue-gap)

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

### `veaf-tools mission password-hash` {#password-hash}

Turn a password into the SHA-1 hash `security.password_hashes` takes in `mission.yaml`.
It asks for the password twice, the input hidden, and prints only the hash: the password is never shown nor written.
Run it yourself, and give the hash, never the password, to an AI assistant that writes `mission.yaml`.
`password_hashes` holds the SENIOR_PILOT password (it also opens KNOWN_PILOT), `password_mm_hashes` the Mission Master's.
No argument, no option.

```powershell
.\veaf-tools.exe mission password-hash
```

*Flat alias : `veaf-tools password-hash`*

**See also** : [veafSecurity](mission-maker/scripts/veafSecurity.en.md)

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

### `veaf-tools dcs farp-spot` {#farp-spot}

Finds the **flat spots clear of trees and buildings** near a point, where a FARP can go, and lists them nearest first with their distance and height difference. It is what to run when `add_farp` warns that it could not check the trees or the slope (a theatre with no clear-ground catalogue and no elevation grid, such as MarianaIslands), or that the pad is on a slope: the warning gives the command, point included.

A spot is kept when the ground there is earth (not water, road or runway), when DCS finds a free 5 m spot within 20 m at the spot **and** at 8 points 40 m around it, and when the height difference over those 9 points is at most `--max-drop` metres. The search goes over a 50 m grid, in bands of 300 m so that each call to `dcs-serve` stays short. A spot it lists is clear; a spot it leaves out is not necessarily wooded — the DCS query it rests on can say « no room » on open grass (known limitation `disposition-small-query-blocks-open-grass`), so look in game before giving up on a place. Same flow as `clear-ground-check`: `dcs-serve`, empty survey mission, instructions, waiting. The point is in mission coordinates (`x` north, `y` east, metres).

| Name | Type | Required | Description |
|---|---|---|---|
| `THEATRE` | `str` | yes | The theatre, as DCS spells it (Caucasus, MarianaIslands…). |

| Options | Type | Default | Description |
|---|---|---|---|
| `--at` | `str` | *(required)* | The point to search around, as `x,y`. |
| `--radius` | `float` | `1200` | How far from the point to search, in metres. |
| `--max-drop` | `float` | `3` | The largest height difference accepted over a spot (its centre and the 40 m ring), in metres. |
| `--limit` | `int` | `10` | How many spots to list. |
| `--report` | `str` | *(none)* | Also write every spot found as JSON to this file. |
| `--survey-mission` | `str` | `<Saved Games>/DCS/Missions/veaf-survey-<theatre>.miz` | Where to write the survey mission. |
| `--bridge-lua` | `str` | *(none)* | Local dcs-bridge.lua to embed (default: download). |
| `--wait` | `int` | `900` | How many seconds to wait for the survey mission to answer. |
| `--api-key` | `str` | *(none)* | dcs-serve superuser Bearer token (default: read from dcs-serve.yaml). (environment variable `DCS_BRIDGE_API_KEY`) |
| `--config` | `str` | *(none)* | Path of a dcs-serve.yaml / dcs-client.yaml to read the key from. |
| `--serve-url` | `str` | `http://127.0.0.1:8080` | dcs-serve base URL. |
| `--dcs-serve` | `str` | *(none)* | The dcs-serve executable to start when none is running. |
| `--verbose` | `boolean` | `false` | If enabled, prints detailed debugging information. |

```bash
.\veaf-tools.exe dcs farp-spot MarianaIslands --at -22300,-12450
```

The point is given with `--at` rather than as two arguments: a negative number in second position would be read as an option.

*Flat alias : `veaf-tools farp-spot`*

### `veaf-tools dcs terrain-sweep` {#terrain-sweep}

Sweeps the **ground elevation** of a whole theatre (`land.getHeight`, every 250 m by default) and writes
it to `<VEAF home>/terrain/<theatre>.terrain`. The MCP action `terrain_elevation` then reads that
grid with no DCS: a target's altitude, the highest ground along a route, terrain masking between a
route and a SAM site. Same flow as `clear-ground-sweep`: `dcs-serve`, empty survey mission,
instructions, waiting; an interrupted sweep resumes where it stopped. The extent swept is the map's,
asked to DCS; when it does not give it, the airfields' plus 50 km, and the command says so. **Terrain
only**: no buildings, pylons or trees.

A theatre VEAF has already swept needs no sweep: its grid is published on GitHub (release [`terrain-data`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/tag/terrain-data)), and veaf-tools downloads it on first use, into the same folder.
A grid already there — swept here or downloaded — is used as is.
Sweep a theatre when it is not published, or to replace a downloaded grid.

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

### Talking to a mission running in DCS: the VEAF bridge {#dcs-bridge}

`smoke-test`, `mission-check`, `recon-plan` and `recon-shoot` talk to the mission **you** launched in DCS, on this computer, one way only: the **VEAF bridge**. It is the `dcs-bridge.lua` script, embedded in the mission, connecting to `dcs-serve`, the small local server the commands go through.

- **The mission must carry the bridge.** `recon-prepare` and `mission-check-prepare` embed it in the copy they write; for `smoke-test`, build the mission with the `dcs_bridge` section of `mission.yaml` enabled, or pass it through [`inject-bridge`](#inject-bridge).
- **`dcs-serve` is started for you.** When none answers, the command starts one as [`clear-ground-sweep`](#clear-ground-sweep) does: found next to `veaf-tools.exe`, on the `PATH`, or through `--dcs-serve`, with a generated key and listening on this computer only, and stopped at the end.
- **One change to make once on your DCS**: allow mission scripts to talk to the outside, by editing `Scripts\MissionScripting.lua` in the DCS install. It is the same as for `clear-ground-sweep` and the airbase capture; it is described step by step in [Capturing a map's airbases](developer/capture-airbases.en.md), step 0, and must be redone after every DCS update.
- **The bridge reconnects at its own pace**: up to a minute of mission time when `dcs-serve` starts after the mission. The command waits (`--wait`, 180 s by default) and says what it is waiting for. The mission must run **unpaused**: paused, the bridge does not answer.

These four commands share these options:

| Options | Type | Default | Description |
|---|---|---|---|
| `--serve-url` | `str` | `http://127.0.0.1:8080` | Base URL of dcs-serve. |
| `--dcs-serve` | `str` | *(none)* | The dcs-serve executable to start when none runs; default: next to veaf-tools.exe, then on PATH. |
| `--api-key` | `str` | *(none)* | The key of a dcs-serve you started yourself. (environment variable `DCS_BRIDGE_API_KEY`) |
| `--config` | `str` | *(none)* | The dcs-serve.yaml of a dcs-serve you started yourself, to read its key from. |
| `--wait` | `int` | `180` | Seconds to wait for the mission's bridge to connect. |

### `veaf-tools dcs smoke-test` {#smoke-test}

Assert VEAF runtime behaviour inside the mission running in DCS, through the [VEAF bridge](#dcs-bridge): the mission must be built with `dcs_bridge`. One line per check; exit code 1 when one fails.

| Options | Type | Default | Description |
|---|---|---|---|
| `--suite` | `str` | `default` | Which set of checks to run: `default` (every mission) or `spotter` (the demo-spotter-network rig only). |
| `--timeout` | `float` | `10.0` | Per-check timeout, in seconds. |
| `--verbose` | `boolean` | `false` | If set, the script will output a lot of debug information. |

Plus the [bridge options](#dcs-bridge).

```powershell
.\veaf-tools.exe dcs smoke-test
```

*Flat alias : `veaf-tools smoke-test`*

**See also** : [developer/smoke-harness.md](developer/smoke-harness.en.md)

### `veaf-tools dcs mission-check-prepare` {#mission-check-prepare}

Writes the test copy `mission-check` runs against: the built mission, the [VEAF bridge](#dcs-bridge) embedded, nothing else changed. The original mission is not touched.

| Arguments | Type | Description |
|---|---|---|
| `MISSION` | `Path` | The built mission (.miz); it is not modified. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--out` | `Path` | *(beside it, `_CHECK` appended)* | Where to write the copy. |
| `--bridge-lua` | `str` | *(none)* | A local dcs-bridge.lua to embed; downloaded from the VEAF-dcs-bridge repository otherwise. |
| `--verbose` | `boolean` | `false` | If enabled, prints detailed debug information. |

```powershell
.\veaf-tools.exe dcs mission-check-prepare MyMission.miz
```

*Flat alias : `veaf-tools mission-check-prepare`*

### `veaf-tools dcs mission-check` {#mission-check}

Checks the mission **running in DCS** — the copy written by [`mission-check-prepare`](#mission-check-prepare), which you launched yourself — through the [VEAF bridge](#dcs-bridge), and prints one line per check and a verdict:

- **F10 menus**: every entry of the VEAF radio menu has a label; an empty one is reported with its path (`VEAF > Zones > ∅`);
- **combat zones and missions**: each one is switched on then off, its units counted each time, and it is **left as it was found**; a CAP is checked under each of its variant names (`<name>/<skill>/<scale>`); an *operation* is reported but not toggled (it would take its zones with it);
- **columns**: every ground group with a route of more than one waypoint — from the mission or spawned by a zone — must drive within 60 seconds. This is the check that finds a column frozen by an "On Road" leg with no road to follow.

Keep DCS running **unpaused** during the check: paused, nothing spawns and nothing drives. Expect a few minutes (the command says how many). Exit code 1 when a check fails.

| Options | Type | Default | Description |
|---|---|---|---|
| `--only` | `str` | *(all)* | Zone or combat mission name to check; repeat for several. The menus and the mission's own columns are checked either way. |
| `--verbose` | `boolean` | `false` | If enabled, prints detailed debug information. |

Plus the [bridge options](#dcs-bridge).

```powershell
.\veaf-tools.exe dcs mission-check
```

*Flat alias : `veaf-tools mission-check`*

### Reconnaissance photos — `recon-prepare`, `recon-plan`, `recon-shoot`, `recon-render` {#recon-photos}

Four commands, one per step, because you act between each: they produce one reconnaissance photo per objective, taken **in DCS** along the planned engagement axis, with the look of a reconnaissance print (contrasted black and white, grain, banner, heading rose) and the targets circled **in red felt pen**. Units are drawn where DCS actually put them, the zones' random draws included. The result (a JPEG + JSON per shot, and a `recon.json` index) goes into the briefing.

The whole sequence:

1. `.\veaf-tools.exe dcs recon-prepare MyMission.miz` writes `MyMission_RECON.miz` beside it: clear sky, chosen time, every combat zone active at start, readable group names, and the [VEAF bridge](#dcs-bridge) embedded, through which `recon-plan` and `recon-shoot` talk to the mission. The original mission is not touched.
2. In DCS: open `MyMission_RECON.miz`, take a **spectator** slot, press **F11** (free camera). Keep the DCS window on the **primary screen**.
3. `.\veaf-tools.exe dcs recon-plan --operation "Golan Hammer"` writes `shots.yaml`: one shot per zone, with the names of the groups found.
4. Complete `shots.yaml`: for each shot, the engagement `heading` (the direction the attacker looks, in degrees on the mission's grid, as DCS turns its camera: the photo's banner and the briefing print it magnetic), and if needed `pitch` (degrees below the horizon), `slant` (distance in metres), `mark: units` to circle each vehicle, `labels` to name the targets.
5. `.\veaf-tools.exe dcs recon-shoot`: the command puts the camera on each shot and grabs the window. Do not touch the mouse or the keyboard until it is done.
6. `.\veaf-tools.exe dcs recon-render` writes the photos into `docs\recon\`, where the briefing (`build_mission_briefing`) looks for them.
   A shot tied to a bare group prefix (`Sasa [r]`) joins its zone (`Sasa`) when `recon-render` is run again: no need to take it again.

Run the commands from the mission folder: the raw shots go to `docs\build\recon\raw\`, the finished photos to `docs\recon\`.

A completed `shots.yaml`:

```yaml
operation: Golan Hammer
coalition: red
shots:
  - name: 03-sa11
    title: Kiswah SA-11 battery
    groups: [SA11Kiswah]
    heading: 70
    pitch: 30
    slant: 1100
    mark: units
    labels: {"SA-11 Buk SR": "RADAR 9S18", "SA-11 Buk LN": "TEL"}
```

The camera stands `slant` metres from the target, `pitch` degrees above the horizon, looking along `heading`. The marks are placed by projection with an 80° horizontal field, measured: the six vehicles of an SA-11 fall within a few pixels of their projection.

**One shot per objective, two at most**: the briefing keeps two and skips the rest. **A group of vehicles that move about** — tanks, light armour, trucks, 4x4 — **is never ringed**, whatever `mark` says: the photo shows its zone, not where each vehicle stood, since they will have moved. A group holding a SAM, a radar or artillery is a site and is ringed. The banner gives the target's position in DDM and MGRS.

#### `veaf-tools dcs recon-prepare` {#recon-prepare}

| Arguments | Type | Description |
|---|---|---|
| `MISSION` | `Path` | The built mission (.miz); it is not modified. |

| Options | Type | Default | Description |
|---|---|---|---|
| `--time` | `str` | `11:30` | Time of day of the photos, HH:MM on the theatre's clock. |
| `--out` | `Path` | *(beside it, `_RECON` appended)* | Where to write the copy. |
| `--bridge-lua` | `str` | *(none)* | A local dcs-bridge.lua to embed; downloaded from the VEAF-dcs-bridge repository otherwise. |
| `--verbose` | `boolean` | `false` | If enabled, prints detailed debug information. |

*Flat alias : `veaf-tools recon-prepare`*

#### `veaf-tools dcs recon-plan` {#recon-plan}

| Options | Type | Default | Description |
|---|---|---|---|
| `--out` | `Path` | `shots.yaml` | The shots file to write. |
| `--coalition` | `str` | `red` | The side to photograph: `red` or `blue`. |
| `--operation` | `str` | *(none)* | The operation's name, printed on every photo. |
| `--force` | `boolean` | `false` | Overwrite an existing shots file. |
| `--verbose` | `boolean` | `false` | If enabled, prints detailed debug information. |

Plus the [bridge options](#dcs-bridge).

*Flat alias : `veaf-tools recon-plan`*

#### `veaf-tools dcs recon-shoot` {#recon-shoot}

| Options | Type | Default | Description |
|---|---|---|---|
| `--shots` | `Path` | `shots.yaml` | The shots file. |
| `--raw-dir` | `Path` | `docs\build\recon\raw` | Folder of the raw shots (PNG + JSON). |
| `--only` | `str` | *(all)* | Shot name to take; repeat for several. |
| `--verbose` | `boolean` | `false` | If enabled, prints detailed debug information. |

Plus the [bridge options](#dcs-bridge).

The F11 camera is moved from DCS's `export` state, which the bridge reaches through `net.dostring_in`; the window is grabbed on this computer. The DCS window must be on the primary screen and visible: a grab of all screens returns the DirectX window black, and a black grab is retried up to eight times.

*Flat alias : `veaf-tools recon-shoot`*

#### `veaf-tools dcs recon-render` {#recon-render}

| Options | Type | Default | Description |
|---|---|---|---|
| `--shots` | `Path` | `shots.yaml` | The shots file (the order and the operation's name). |
| `--raw-dir` | `Path` | `docs\build\recon\raw` | Folder of the raw shots. |
| `--out-dir` | `Path` | `docs\recon` | Folder of the finished photos. |
| `--verbose` | `boolean` | `false` | If enabled, prints detailed debug information. |

Writes `<shot>.jpg`, `<shot>.json` and `recon.json`, the ordered list of shots. The JSON carries what the briefing reads — `zone` (the objective's combat zone: the shot's `zone` key, otherwise the one of the first `groups` prefix), `title`, `heading`, `pitch` (negative looking down), `x`/`y` and `altitude_m` (the camera, in mission coordinates), `order` — then the rest of the shot: camera, target in DCS coordinates, latitude/longitude and DMS, time, units.

*Flat alias : `veaf-tools recon-render`*

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

### `veaf-tools ai-setup` {#ai-setup}

Connects the AI assistants installed on this PC to the VEAF tools: **Claude Desktop**, **Claude Code**, **Codex** (ChatGPT Desktop), **Antigravity**, **Gemini CLI** and **OpenCode**.
The command declares the executable that runs it as the `veaf-mission-editor` MCP server in each one's configuration, without touching their other settings, and says for each whether it is connected, absent or failed.
It can be run again safely, for instance after moving the tools folder.

```powershell
.\veaf-tools.exe ai-setup
```

It takes no option. Then quit the AI assistant completely and start it again: it reads its servers only at start-up.
It exits with an error (code 1) when no assistant is found or a setting could not be written, leaving the file in question untouched.

**See also**: [Create with an AI](mission-maker/AI_ASSISTANT_INSTALL.en.md)

### `veaf-tools mcp` {#mcp}

Start the LLM-assisted mission-editing MCP server (stdio). Declared in your AI assistant by [`ai-setup`](#ai-setup).

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
