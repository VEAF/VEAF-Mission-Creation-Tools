# Developer Guide

Complete reference for developers working on the VEAF Mission Creation Tools source code.

## Table of Contents

- [Architecture](#architecture)
- [Development Environment](#development-environment)
- [Lua Runtime Scripts](#lua-runtime-scripts)
- [Python Tools](#python-tools)
- [Build & Release](#build--release)
- [Technical Reference](#technical-reference)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

---

## Architecture

The project separates **runtime Lua scripting** (executed inside DCS World) from **design-time Python tooling** (run on the developer/mission-maker's machine).

```
┌──────────────────────────────────────────────────────────────────┐
│                    DEVELOPERS / ADMINISTRATORS                    │
│                                                                   │
│  build-and-release.py                                            │
│  ├── Compile Lua scripts (src/scripts/veaf/ → published/)        │
│  ├── Build Python executables (PyInstaller)                      │
│  ├── Create release package (published.zip + SHA256)             │
│  └── Publish to GitHub Release                                   │
│                          ↓                                        │
│                   GitHub Release                                  │
│                 (published.zip + SHA256)                          │
└──────────────────────────────────────────────────────────────────┘
                            ↓
                   (Available on GitHub)
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│                   MISSION MAKERS / USERS                          │
│                                                                   │
│  veaf-tools-updater.exe update                                   │
│  ├── Fetch latest release from GitHub                            │
│  ├── Download published.zip                                      │
│  ├── Verify SHA256 checksum                                      │
│  └── Extract files to mission folder                             │
└──────────────────────────────────────────────────────────────────┘
```

### Directory Layout

```
VEAF-Mission-Creation-Tools/
├── build-and-release.py          # Build & publish orchestrator
├── src/
│   ├── scripts/veaf/             # Lua runtime modules (32 files)
│   └── python/veaf-tools/        # Python CLI source code
├── published/                     # Compiled Lua output (before packaging)
├── dist/                          # PyInstaller output (.exe files)
├── build/                         # Temporary compilation workspace
├── test/lua/                      # Lua unit tests (31 suites)
├── doc/                           # Documentation by role
├── veaf-tools-config.yaml        # Local config (git-ignored)
└── RELEASE_NOTES.md              # Release notes (edited before publish)
```

### Security Model

```
Developer creates release
    ↓
build-and-release.py calculates SHA256
    ↓
SHA256 stored alongside ZIP on GitHub Release
    ↓
User downloads via veaf-tools-updater.exe
    ↓
Checksum verified before extraction
    ↓
✅ File is authentic and uncorrupted
```

---

## Development Environment

### Prerequisites

- Python 3.9+ (3.13 recommended)
- Git
- GitHub CLI (`gh`) — for publishing releases
- Lua 5.1 — for running unit tests locally

### Setup

```powershell
# Clone the repository
git clone https://github.com/VEAF/VEAF-Mission-Creation-Tools.git

# Create and activate virtual environment (always do this first!)
python -m venv .venv
. .\.venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt
```

### Python Dependencies

| Package | Purpose |
|---------|---------|
| `typer` | CLI framework (argument parsing, help generation) |
| `rich` | Terminal UI (progress bars, colored output) |
| `pyyaml` | Configuration file loading |
| `pyinstaller` | Build Windows executables |

---

## Lua Runtime Scripts

All runtime scripts live in `src/scripts/veaf/` and are loaded into DCS missions at mission start.

### Module List

| Module | Purpose |
|--------|---------|
| `veaf.lua` | Core framework — logging, utilities, state management |
| `veafCacheManager.lua` | Caching layer for expensive computations |
| `veafInterpreter.lua` | Mark text command parser |
| `veafSecurity.lua` | Role-based action permissions |
| `veafTime.lua` | Mission time utilities |
| `veafNamedPoints.lua` | Named position management with ATC |
| `veafShortcuts.lua` | Keyboard shortcut bindings |
| `veafWeather.lua` | Dynamic weather injection and ATC |
| `veafMarkers.lua` | F10 map marker handling |
| `veafEventHandler.lua` | DCS event listener dispatcher |
| `veafRadio.lua` | Dynamic F10 radio menu management |
| `veafMove.lua` | Unit movement and teleportation |
| `veafSpawn.lua` | Unit spawning (aircraft, ground, smoke, JTAC…) |
| `veafUnits.lua` | Unit template definitions |
| `dcsUnits.lua` | DCS unit data (pure data file) |
| `dcsDataExport.lua` | Unit data export utilities |
| `veafAssets.lua` | Tankers, AWACS, carrier asset management |
| `veafAirbases.lua` | Airbase data and ATC setup |
| `veafCombatMission.lua` | Base combat mission class |
| `veafCombatZone.lua` | Activatable combat zones |
| `veafCasMission.lua` | CAS mission generation |
| `veafTransportMission.lua` | Transport mission generation |
| `veafCarrierOperations.lua` | Aircraft carrier recovery management |
| `veafRemote.lua` | NIOD / SLMOD remote control integration |
| `veafGroundAI.lua` | Ground unit AI enhancements |
| `veafQraManager.lua` | Quick Reaction Aircraft manager |
| `veafAirWaves.lua` | Recurring air attack waves |
| `veafSanctuary.lua` | Sanctuary zone protection |
| `veafMissileGuardian.lua` | Missile threat guardian logic |
| `veafSkynetIadsHelper.lua` | Skynet IADS integration helper |
| `veafSkynetIadsMonitor.lua` | Skynet IADS health monitoring |
| `veafGrass.lua` | Grass runway configuration |
| `veafHoundElintHelper.lua` | Hound ELINT integration |

### Module Loading Pattern

Modules follow a strict load order (see `build_lua_scripts()` in `build-and-release.py`). Each module uses local scope and registers itself on a global table:

```lua
veafMyModule = {}
veafMyModule.Id = "MYMODULE"
veafMyModule.Version = "1.0.0"

local logger = veaf.loggers.new(veafMyModule.Id)

function veafMyModule.initialize()
  logger:info("Initialized")
end
```

### Design-Time Scripts (build/ only)

These scripts are not shipped in `published/veaf-scripts.lua` but are used by the Python tools at build/mission-prep time:

- `veafMissionEditor.lua`
- `veafMissionFlightPlanEditor.lua`
- `veafMissionNormalizer.lua`
- `veafMissionRadioPresetsEditor.lua`
- `veafMissionTriggerInjector.lua`
- `veafSpawnableAircraftsEditor.lua`

---

## Python Tools

### build-and-release.py

Main orchestrator for the complete release pipeline.

**Commands:**

```powershell
# Build (compile Lua + Python executables + package)
python build-and-release.py build --version 6.0.4

# Publish (create GitHub release + upload artifacts)
python build-and-release.py publish --version 6.0.4

# Force overwrite an existing release
python build-and-release.py publish --version 6.0.4 --force
```

**Build options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--version` | package.json | Semantic version string |
| `--dev` | false | Development build (unlocks internal dev flags) |
| `--skip-lua` | false | Skip Lua compilation |
| `--skip-python` | false | Skip Python executable compilation |
| `--verbose` | false | Detailed debug output |

**Publish options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--version` | package.json | Version to publish |
| `--token` | config/env | GitHub Personal Access Token |
| `--force` | false | Delete and re-create existing release |
| `--prerelease` | false | Mark as pre-release; does not update `published-latest` |
| `--verbose` | false | Detailed debug output |

**GitHub token precedence:** CLI `--token` > `veaf-tools-config.yaml` > `GITHUB_TOKEN` env var

### veaf-tools-updater.py

Utility for end users to download and install a release into a mission folder.

```powershell
veaf-tools-updater.exe update
veaf-tools-updater.exe update --mission-folder C:\path\to\mission
```

Workflow: discover latest release on GitHub → download `published.zip` → verify SHA256 → extract to mission folder.

---

## Build & Release

### Full Release Workflow

```powershell
# 1. Activate virtual environment
. .\.venv\Scripts\Activate.ps1

# 2. Build artifacts
python build-and-release.py build --version 6.0.5

# 3. Edit release notes
notepad RELEASE_NOTES.md

# 4. Publish to GitHub
python build-and-release.py publish --version 6.0.5
```

### Pre-release Testing Workflow

Use this to validate a build in real conditions (updater downloading from GitHub, actual
`published.zip` installed into a mission folder) **without affecting production users**.

```powershell
# 1. Build with a release-candidate version
python build-and-release.py build --version 6.1.0-rc1

# 2. Publish as pre-release — published-latest is NOT moved
python build-and-release.py publish --version 6.1.0-rc1 --prerelease

# 3. Test the updater by pointing it at the RC tag explicitly
veaf-tools-updater.exe update --tag published-v6.1.0-rc1 --mission-folder C:\path\to\mission
```

What this guarantees:
- GitHub shows `published-v6.1.0-rc1` as a pre-release (not "Latest")
- `published-latest` stays on the previous production release
- End users running `veaf-tools-updater update` without `--tag` are unaffected
- The version-check-on-startup in `veaf-tools` ignores pre-releases

Once testing passes, promote to a real release:

```powershell
python build-and-release.py build --version 6.1.0
python build-and-release.py publish --version 6.1.0
```

### Configuration File

Copy the example and add your GitHub token:

```powershell
cp veaf-tools-config.example.yaml veaf-tools-config.yaml
```

```yaml
github:
  token: "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  owner: "VEAF"
  repo: "VEAF-Mission-Creation-Tools"

publish:
  draft: false
  prerelease: false
  skipTag: false
```

> **Never commit `veaf-tools-config.yaml`** — it is in `.gitignore`.

### What the Build Produces

| File | Description |
|------|-------------|
| `published/veaf-scripts.lua` | All runtime Lua modules concatenated |
| `dist/veaf-tools.exe` | Main CLI tool |
| `dist/veaf-tools-updater.exe` | Updater utility |
| `published.zip` | All of the above in a single package |

### GitHub Release Structure

```
GitHub Release: published-v6.0.5
├── Tag: published-v6.0.5      (version-specific, permanent)
├── Tag: published-latest      (movable, always points to latest)
├── Release Notes: content of RELEASE_NOTES.md
└── Assets:
    ├── published.zip
    ├── veaf-tools-updater.exe (standalone)
    └── SHA256 checksum
```

### Selective Compilation

```powershell
# Lua changed only
python build-and-release.py build --skip-python --version 6.0.5

# Python changed only
python build-and-release.py build --skip-lua --version 6.0.5
```

---

## Technical Reference

### BuildAndReleaseWorker Class

```python
BuildAndReleaseWorker(
    version: Optional[str] = None,
    skip_lua: bool = False,
    skip_python: bool = False,
    development_build: bool = False,
    github_token: Optional[str] = None,
    output_path: Optional[Path] = None,
    verbose: bool = False,
    config: Optional[Dict[str, Any]] = None
)
```

| Method | Purpose |
|--------|---------|
| `validate_prerequisites()` | Check Git, Python, PyInstaller availability |
| `build_lua_scripts()` | Concatenate Lua sources with flag substitution |
| `build_python_executables()` | Invoke PyInstaller for each entry point |
| `create_release_package()` | Create `published.zip` + compute SHA256 |
| `_do_publish_to_github()` | Tag, create release, upload assets |
| `run()` | Execute complete pipeline |

### Lua Compilation Process

1. Clean `build/` directory
2. Copy Lua files from `src/scripts/veaf/`
3. Patch `veaf.lua` flags (dev mode, security flags)
4. Concatenate in dependency order with version markers
5. Write UTF-8 output to `published/veaf-scripts.lua`

### Python Executable Building

PyInstaller is invoked with `--onefile` for each entry point:

```bash
pyinstaller --onefile --distpath dist/ src/python/veaf-tools/veaf-tools.py
pyinstaller --onefile --distpath dist/ ...veaf-tools-updater.py
```

Output size: ~24–25 MB per executable, ~47 MB compressed in `published.zip`.

### Adding a New Lua Module

1. Add the `.lua` file to `src/scripts/veaf/`
2. Place it after its dependencies in the load order inside `build_lua_scripts()`
3. Add a unit test file in `test/lua/test_<module>.lua`
4. Run tests locally: `.\test\lua\run_tests.ps1`

### Adding a New Python Tool

1. Create the entry point in `src/python/veaf-tools/`
2. Follow the Worker/Manager pattern (`*_worker.py` + `run()` method)
3. Use `logger` for all output (no `print()` statements)
4. Add its PyInstaller invocation to `build_python_executables()`

---

## Testing

### Lua Unit Tests

The project has 31 test suites (~915 tests) covering all runtime Lua modules, using the [luaunit](https://github.com/bluebird75/luaunit) framework.

```powershell
# Run all tests
.\test\lua\run_tests.ps1

# Run a subset
.\test\lua\run_tests.ps1 -Filter spawn
```

Exit code: `0` = all pass, `1` = at least one failure.

Infrastructure files:

| File | Purpose |
|------|---------|
| `test/lua/luaunit.lua` | Test framework |
| `test/lua/dcs_mocks.lua` | DCS API stubs (World, Unit, Group, trigger…) |
| `test/lua/veaf_loader.lua` | Loads modules from `src/scripts/veaf/` |
| `test/lua/run_tests.ps1` | Discovers and runs all `test_*.lua` |

See [TESTING.md](TESTING.md) for full details.

### CI/CD

GitHub Actions runs on every push and pull request (`.github/workflows/lua-ci.yml`):

- **Lua unit tests** — Ubuntu, `lua5.1` via apt, runs all `test_*.lua`
- **StyLua formatting check** — verifies `src/scripts/veaf/` against `.stylua.toml`

---

## Troubleshooting

### "PyInstaller is not installed"
```powershell
. .\.venv\Scripts\Activate.ps1
pip install pyinstaller
```

### "Release package not found"
Run `build` before `publish`:
```powershell
python build-and-release.py build --version 6.0.5
```

### "HTTP 422: Release.tag_name already exists"
Use `--force` to overwrite:
```powershell
python build-and-release.py publish --version 6.0.5 --force
```

### "gh not found"
Install GitHub CLI from https://cli.github.com/ and authenticate:
```powershell
gh auth login
```

### Missing Python dependencies
```powershell
. .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Lua encoding errors
Ensure all Lua source files are UTF-8 encoded (no BOM). The compilation step removes BOM automatically, but malformed files may still cause issues.

---

*See also: [TOOLS_REFERENCE.md](TOOLS_REFERENCE.md) for the `veaf-tools.exe` command reference, [TESTING.md](TESTING.md) for the full test infrastructure guide.*
