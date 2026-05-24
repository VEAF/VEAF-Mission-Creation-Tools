# Migrating a Mission to VEAF MCT v6


This guide covers two scenarios:

1. **[From VEAF MCT v5.xx](#migrating-from-veaf-mct-v5xx)** — your mission already uses VEAF MCT scripts but predates the v6 toolchain
2. **[From a vanilla DCS mission](#integrating-veaf-mct-into-a-vanilla-dcs-mission)** — your mission has no VEAF MCT scripts at all

In both cases the end result is a **VEAF MCT v6 mission folder** that you manage with `veaf-tools.exe`.

---

## Before You Start

### Terminology

| Term | Meaning |
|------|---------|
| **Mission folder** | The directory managed by `veaf-tools` — contains source files, config, and the `.miz` |
| **`.miz` file** | The DCS mission file (a ZIP archive); the output of the build step |
| **`published/`** | Where `veaf-tools-updater.exe` installs the VEAF scripts |
| **`src/`** | Your mission-specific source files (scripts, data) |

### Prerequisites

1. Install `veaf-tools-updater.exe` — download from the [latest GitHub release](https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases/tag/published-latest)
2. Run the updater once to install `veaf-tools.exe` and all VEAF scripts:

```powershell
.\veaf-tools-updater.exe
```

3. Have your v5 mission folder on hand

> **Tip — Global User Configuration:** Before starting, create `~/veafmct.yaml` (i.e. `C:\Users\YourName\veafmct.yaml` on Windows) to set persistent defaults for all your VEAF projects on this machine — for example your language preference (`lang: fr`). See [Global User Configuration](GUIDE.md#global-user-configuration) for the full reference and CLI commands.

---

## Migrating from VEAF MCT v5.xx

### What Changed in v6

| Area | v5 | v6 |
|------|----|----|
| **Script delivery** | Individual `.lua` files delivered per mission, updated manually | All modules concatenated into a single `veaf-scripts.lua` managed centrally |
| **DCS trigger** | Manual `DO SCRIPT FILE` triggers pointing at each `.lua` file | Single trigger injected automatically by `veaf-tools build`; no manual trigger work |
| **Build toolchain** | No build step — scripts loaded directly from disk at mission start | `veaf-tools.exe build` assembles the `.miz` from `src/mission/` + `src/scripts/` |
| **Build script** | Complex `build.cmd` with one line per inject command | No `build.cmd` — just run `veaf-tools-updater.exe` then `veaf-tools.exe build` |
| **Auto-inject pipeline** | Each inject command (`inject-presets`, `inject-waypoints`, etc.) had to be added manually to `build.cmd` | `veaf-tools build` auto-detects and runs each step when the matching file is present in `src/` |
| **Tool updates** | Manual download and replacement of script files | `veaf-tools-updater.exe` — downloads and verifies the latest release in one command |
| **Build-time config** | No build-time config file | `mission.yaml` — controls log levels, module enable/disable, pipeline step overrides |
| **Module enable/disable** | Edit `missionConfig.lua` (or simply omit the `initialize()` call) | `mission.yaml` → `lua_modules:` section; generates `veaf-modules-config.lua` automatically |
| **Module configuration** | Direct assignment: `veafSpawn.SpawnKeyphrase = "_spawn"` in `missionConfig.lua` | Same direct assignment still works; or `veaf.setConfig("MODULE_ID", "key", value)` for config-driven overrides |
| **Module init pattern** | Bare `veafXxx.initialize()` calls | `if veafXxx then veafXxx.initialize() end` guard (tolerates missing modules) |
| **Config location** | Initialization scattered in DCS trigger scripts or a separate Lua file | Centralised in `src/scripts/missionConfig.lua` |
| **Config migration** | Manual rewrite | `veaf-tools.exe convert-v5` — one command converts `missionConfig.lua`, pipeline files (presets, waypoints, weather, aircraft groups), and generates `mission.yaml`. Use `migrate-config` only to migrate `missionConfig.lua` alone. |
| **Module log levels** | Set per-module by assigning `veafXxx.LogLevel` before init | `mission.yaml` → `lua_modules: → MODULE_ID: logLevel:` or `--log-modules` CLI flag |
| **Version control** | Binary `.miz` committed to Git | Source files (`src/`) committed; `.miz` is a build artifact |

### Step-by-step Migration

#### 1. Open your existing v5 mission folder

Navigate to the folder that already contains your v5 mission files — the one with `src/scripts/missionConfig.lua`, `src/radio/radioSettings.lua` (if you use presets), and similar v5 source files:

```powershell
cd C:\path\to\your-v5-mission-folder
```

> **Do not create an empty folder.** The converter reads your existing v5 source files directly.

#### 2. Install VEAF MCT v6

Copy `veaf-tools-updater.exe` into the folder and run:

```powershell
.\veaf-tools-updater.exe
```

This creates the `published/` directory with all scripts and tools. Your existing `src/` files are not touched.

#### 3. Convert the mission folder to v6

Run the all-in-one converter:

```powershell
.\veaf-tools.exe convert-v5 .
```

This single command handles everything in one pass:

- **`missionConfig.lua` migration** — comments out `doFile()` calls that load VEAF scripts (the builder injects them automatically), wraps bare `veafXxx.initialize()` calls in `if veafXxx then … end` guards.
- **Pipeline config conversion** — converts v5 config files (radio presets, waypoints, weather, aircraft groups) from Lua to v6 YAML format.
- **`mission.yaml` generation** — creates `mission.yaml` with the correct `lua_modules:` and `pipeline:` sections.
- **Conversion report** — saves `convert-v5-report.md` with all actions taken and any items requiring manual review.

If your pipeline contains `realweather` weather versions, the tool will ask for the ICAO airport code to embed in the generated config. You can supply it upfront to avoid the interactive prompt:

```powershell
.\veaf-tools.exe convert-v5 . --icao UGGG
```

Old DCS `DO SCRIPT FILE` triggers are removed automatically by `veaf-tools build` in the next step — no manual action needed.

> **If you only need to migrate `missionConfig.lua`** without converting pipeline files, use `veaf-tools.exe migrate-config src\scripts\missionConfig.lua` directly.

#### 4. Check removed v5 patterns

Some v5 constructs no longer exist or have been renamed:

| v5 | v6 |
|----|-----|
| `veaf.SecurityDisabled = true` | `veafSecurity.SecurityDisabled = true` |
| `veafSpawn.Keyphrase` set at top-level | Still `veafSpawn.Keyphrase` — unchanged |
| `veafAssets.Assets` inline table | Same table format — unchanged |
| Loading individual `.lua` files via `DO SCRIPT FILE` | Automatic — do not add these triggers manually |
| `IADS` scripts loaded manually | Load them via `src/scripts/` — they are picked up automatically |

#### 5. Verify with a test build

```powershell
.\veaf-tools.exe build
```

Open the resulting `.miz` in DCS, load the mission, and confirm:
- No duplicate `DO SCRIPT FILE` triggers in the trigger editor
- The v6 VEAF MCT loader trigger is present (named something like `VEAF scripts loader`)
- Radio menus and marker commands work as expected

#### 6. Set up version control

```powershell
git init
git add src/ .gitignore
git commit -m "feat: migrate my-mission to VEAF MCT v6"
```

Add `published/` and `*.miz` to `.gitignore` — they are build artifacts.

---

## Integrating VEAF MCT into a Vanilla DCS Mission

A **vanilla** mission has no VEAF MCT scripts, no special triggers, and was built entirely with the DCS Mission Editor.

### Step-by-step Integration

#### 1. Create the mission folder

```powershell
mkdir my-mission
cd my-mission
```

#### 2. Install VEAF MCT v6

```powershell
.\veaf-tools-updater.exe
```

#### 3. Convert the vanilla .miz

The `convert-mission` command does everything in one step: extract, inject VEAF scripts, rebuild.

```powershell
.\veaf-tools.exe convert-mission "C:\path\to\vanilla.miz" .
```

This:
1. Extracts `vanilla.miz` into `src/mission/`
2. Copies the default `src/scripts/missionConfig.lua`
3. Injects the v6 VEAF loader trigger
4. Rebuilds a new `.miz` next to the folder

#### 4. Optionally: prepare the folder with defaults only

If you want to set up the folder structure without converting a mission yet, use `prepare`:

```powershell
.\veaf-tools.exe prepare .
```

Then copy your `.miz` as `mission.miz` and run:

```powershell
.\veaf-tools.exe extract mission.miz .
.\veaf-tools.exe build mission .
```

#### 5. Configure which modules to enable

Open `src/scripts/missionConfig.lua`. By default, only the essential modules (markers, spawn, radio) are enabled. Uncomment the modules you want:

```lua
veaf.config.MISSION_NAME = "My Vanilla Mission"

if veafRadio then
    veafRadio.initialize(true)
end
if veafSpawn then
    veafSpawn.initialize()
end

-- Uncomment to enable CAS missions:
-- if veafCasMission then
--     veafCasMission.initialize()
-- end

-- Uncomment to enable carrier ops:
-- if veafCarrierOperations then
--     veafCarrierOperations.initialize()
-- end
```

See [missionConfig.lua reference](#missionconfiglua-reference) below and the individual script guides in [scripts/](scripts/README.md) for all options.

#### 6. Keep your existing mission content

Everything you built in the DCS Mission Editor (units, triggers, waypoints, zones) is preserved. VEAF does not remove or overwrite mission content — it only:
- Adds a single loader trigger at mission start
- Adds F10 radio menu entries at runtime
- Responds to F10 map marker commands

Your custom triggers, statics, and groups are untouched.

#### 7. Test and iterate

```powershell
# Rebuild after every config change
.\veaf-tools.exe build mission .
```

Each build produces a dated `.miz` file (e.g. `mission_20260516.miz`). Open it in DCS and test.

---

## Mission Folder Reference

After migration, your folder should look like this:

```
my-mission/
├── src/
│   ├── mission/                ← extracted DCS mission data (commit this)
│   │   ├── mission             ← main mission Lua dictionary
│   │   ├── options
│   │   └── warehouses
│   ├── scripts/
│   │   ├── missionConfig.lua   ← your module config (commit this)
│   │   └── veafDynamicConfig.lua   ← optional dynamic slots config
│   ├── presets.yaml            ← radio presets config (optional)
│   ├── spawnables.yaml         ← custom spawnable groups (optional)
│   └── waypoints.yaml          ← custom waypoints (optional)
├── published/                  ← installed by veaf-tools-updater (do NOT commit)
│   ├── veaf-scripts.lua
│   └── ...
├── veaf-tools.exe              ← installed by veaf-tools-updater (do NOT commit)
├── veaf-tools-updater.exe      ← commit this
└── mission_20260516.miz        ← build output (do NOT commit)
```

### Recommended .gitignore

```gitignore
published/
*.miz
*.log
__pycache__/
```

---

## missionConfig.lua Reference

The minimal working `missionConfig.lua`:

```lua
veaf.config.MISSION_NAME = "My Mission"   -- shown in logs

-- Radio module (required for all F10 menus)
if veafRadio then
    veafRadio.initialize(true)
end

-- Spawn module (required for marker commands)
if veafSpawn then
    veafSpawn.initialize()
end

-- Shortcuts (required for aliases)
if veafShortcuts then
    veafShortcuts.initialize()
end
```

For each additional module, see the corresponding guide in [scripts/](scripts/README.md).

---

## Common Issues

### "VEAF scripts loader" trigger appears twice

You have both an old manual `DO SCRIPT FILE` trigger and the v6 auto-injected one. Remove the manual trigger from the DCS Mission Editor (open the `.miz`, edit triggers, delete the old one, save), then re-extract and rebuild.

Alternatively, use `--migrate-from-v5` on the build to have the old triggers removed automatically (this is the default).

### Radio menus don't appear

Confirm `veafRadio.initialize(true)` is in `missionConfig.lua` and is not commented out.

### Marker commands don't work

Confirm `veafSpawn.initialize()` is called. Check the DCS log (Saved Games\DCS\Logs\dcs.log) for VEAF errors.

### Build fails with "VEAF scripts file not found"

Run `veaf-tools-updater.exe` first — the `published/` folder is missing or outdated.

---

## See Also

- [Mission Maker Guide](README.md) — general mission making workflow
- [Scripts Reference](scripts/README.md) — all available modules
- [Tools Reference](../TOOLS_REFERENCE.md) — full `veaf-tools.exe` CLI reference
