# Developer Guide — VEAF Mission Creation Tools

This guide is for developers who want to contribute to the VEAF Mission Creation Tools source code, build new releases, or extend the framework.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Repository Layout](#repository-layout)
3. [Development Environment](#development-environment)
4. [Lua Runtime Scripts](#lua-runtime-scripts)
5. [Python Tools](#python-tools)
6. [Build and Release](#build-and-release)
7. [Testing](#testing)
8. [Quality Gates](#quality-gates)
9. [Contributing](#contributing)

---

## Architecture Overview

The project has two completely separate layers:

```
┌──────────────────────────────────────────────────────────┐
│  DESIGN-TIME (Python)                                    │
│                                                          │
│  veaf-tools.exe  ──────────────── .miz manipulation      │
│  veaf-tools-updater.exe ──────── release management      │
│  build-and-release.py ─────────── build pipeline         │
└──────────────────────────────────────────────────────────┘
                        ↓ produces
                  published.zip
                        ↓ consumed by
┌──────────────────────────────────────────────────────────┐
│  RUNTIME (Lua, inside DCS World)                         │
│                                                          │
│  veaf-scripts.lua  ────── all 32 modules concatenated   │
│  missionconfig.lua ────── mission-specific config        │
└──────────────────────────────────────────────────────────┘
```

- **Runtime** (`src/scripts/veaf/`) — 32 Lua modules loaded inside DCS missions
- **Design-time** (`src/python/veaf-tools/`) — Python CLI tools for `.miz` file manipulation

---

## Repository Layout

```
VEAF-Mission-Creation-Tools/
├── build-and-release.py          # Main build orchestrator
├── src/
│   ├── scripts/veaf/             # Lua runtime modules (32 files)
│   └── python/veaf-tools/        # Python CLI source
│       ├── veaf-tools.py         # Entry point
│       ├── veaf_libs/            # Shared utilities (logger, progress, miz)
│       ├── mission_tools/        # Core .miz read/write
│       └── *_injector/           # One folder per CLI command
├── published/                    # Compiled Lua output
├── dist/                         # PyInstaller .exe output
├── build/                        # Temporary build workspace
├── test/
│   └── lua/                      # Lua unit tests (31 suites)
├── doc/                          # Documentation
├── openspec/                     # Change management (OpenSpec workflow)
└── .github/
    └── workflows/                # CI/CD GitHub Actions
```

---

## Development Environment

### Prerequisites

- Python 3.9+ (3.13 recommended)
- Git
- GitHub CLI (`gh`) — for publishing releases
- Lua 5.1 — for running unit tests locally
- StyLua 2.4.0 — for Lua formatting (installed at `~/.local/bin/stylua.exe`)

### Setup

```powershell
# Clone
git clone https://github.com/VEAF/VEAF-Mission-Creation-Tools.git
cd VEAF-Mission-Creation-Tools

# Create virtual environment and activate (always do this first!)
python -m venv .venv
. .\.venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt
```

### Python Dependencies

| Package | Purpose |
|---------|---------|
| `typer` | CLI framework |
| `rich` | Terminal UI (progress bars, tables) |
| `pyyaml` | Config file loading |
| `luadata` | Lua serialisation/deserialisation |
| `pyinstaller` | Build Windows executables |
| `pillow` | Image processing (weather icons) |

---

## Lua Runtime Scripts

### Module Structure

Every Lua module follows this pattern:

```lua
moduleName = {}

moduleName.Id = "MODULE_ID"
moduleName.Version = "1.x.y"
-- moduleName.LogLevel = "trace"  -- uncomment to increase verbosity

veaf.loggers.new(moduleName.Id, moduleName.LogLevel)

function moduleName.initialize()
  -- register with markers, radio, event handler
end

function moduleName.start()
  -- start watchdogs, scheduled tasks
end
```

### Dependency Order

1. `veaf.lua` — must be first
2. `veafEventHandler.lua`
3. `veafMarkers.lua`, `veafRadio.lua`, `veafSecurity.lua`
4. All other modules (any order)

### Logging

```lua
veaf.loggers.get(moduleName.Id):info("Message")
veaf.loggers.get(moduleName.Id):debug("Debug: %s", variable)
veaf.loggers.get(moduleName.Id):trace("Trace: %s", veaf.lp(table))
```

Log levels: `error` (1) → `warn` (2) → `info` (3) → `debug` (4) → `trace` (5). Default is `info` (3).

For expensive arguments, use `veaf.lp()` (lazy proxy — only stringified when the level is active).

To increase verbosity for a mission at **build time** (global, baked into the `.miz`), add `global_log_level` in `mission.yaml`:

```yaml
global_log_level: debug
```

For **per-module or runtime** control, use `missionconfig.lua` directly:

```lua
veaf.loggers.get("SPAWN"):setLevel("debug", true)  -- force=true bypasses BaseLogLevel cap
```

### mist.DBs Access

Do not access `mist.DBs.*` directly. Use the `veaf.mist` wrapper:

```lua
local unitData  = veaf.mist.getUnitData(unitName)
local groupData = veaf.mist.getGroupData(groupName)
local isHuman   = veaf.mist.isHumanUnit(unitName)
local allUnits  = veaf.mist.getAllUnitData()
local groupById = veaf.mist.getGroupById(groupId)
```

---

## Python Tools

### CLI Architecture

Each `veaf-tools.exe` subcommand is implemented as a `*_injector/` package:

```
weather_injector/
├── weather_worker.py    # Entry point (run() method)
├── weather_manager.py   # Data transformation logic
├── models.py            # Dataclass definitions
└── weather_README.py    # Help/documentation strings
```

### Logger Pattern

```python
from veaf_libs.logger import logger, console

logger.info("Processing mission...")
logger.debug("Detailed info")
logger.warning("Watch out")
logger.error("Failed", raise_exception=True)
```

### Adding a New Tool

1. Create `src/python/veaf-tools/new_feature_injector/`
2. Implement `new_feature_worker.py` with a `run()` method
3. Register the command in `veaf-tools.py` using `typer`
4. Add YAML config schema in `models.py`

---

## Build and Release

### Local Build

```powershell
# Activate venv first
. .\.venv\Scripts\Activate.ps1

# Build (compiles Lua + builds .exe)
python build-and-release.py build --version 6.0.5
```

What it does:
1. Validates prerequisites (Git, Python, PyInstaller)
2. Concatenates Lua modules → `published/veaf-scripts.lua`
3. Builds `veaf-tools.exe` and `veaf-tools-updater.exe` via PyInstaller
4. Creates `published.zip` with all artifacts + SHA256 checksum

### Publishing a Release

```powershell
# Requires GITHUB_TOKEN environment variable
python build-and-release.py publish --version 6.0.5
```

This creates a Git tag, a GitHub Release, and uploads `published.zip` with the SHA256 file.

### Security Model

```
build-and-release.py computes SHA256 of published.zip
    ↓
SHA256 stored alongside ZIP in GitHub Release
    ↓
veaf-tools-updater.exe downloads both files
    ↓
Checksum verified before extraction
    ↓
✅ Integrity guaranteed
```

---

## Testing

### Run All Tests

```powershell
.\test\lua\run_tests.ps1
```

Exit code `0` = all pass, `1` = failures.

### Filtered Run

```powershell
.\test\lua\run_tests.ps1 -Filter spawn
.\test\lua\run_tests.ps1 -Filter combat
```

### Single Suite

```powershell
lua test\lua\test_veafSpawn.lua
```

### Infrastructure

- **Framework:** [luaunit](https://github.com/bluebird75/luaunit) (bundled in `test/lua/luaunit.lua`)
- **DCS stubs:** `test/lua/dcs_mocks.lua` — stubs for all DCS API namespaces
- **Module loader:** `test/lua/veaf_loader.lua`
- No DCS installation required

Full testing reference: [Testing Guide](../TESTING.md)

---

## Quality Gates

### Before Every Commit to Lua Files

```powershell
# Check formatting (same as CI)
~/.local/bin/stylua.exe --check src/scripts/veaf/

# Auto-fix
~/.local/bin/stylua.exe src/scripts/veaf/
```

StyLua version: **2.4.0** (enforced by the `StyLua Formatting` CI job).

### CI Jobs

| Job | What it checks |
|-----|---------------|
| `Lua Unit Tests` | All 31 test suites pass |
| `StyLua Formatting` | No formatting violations in `src/scripts/veaf/` |
| `Sourcery` | Code smell / complexity review |

Both CI jobs must be green before a PR can be merged.

---

## Contributing

### Git Flow

- **Feature work:** create `feature/xxx` from `develop-v6`, open PR → `develop-v6`
- **Bug fixes:** create `fix/xxx` from `develop-v6`, open PR → `develop-v6`
- **Hotfixes to production:** `fix/xxx` from `master`, PR → `master`
- **Releases:** `release/vX.Y.Z` from `develop-v6`, PR → `master`

### Commit Convention

```
type(scope): short description

feat(spawn): add convoy patrol mode
fix(qra): guard unit:isExist() before unit:inAir()
chore(deps): update luaunit to 3.4
docs(api): document veafMove tanker helpers
```

Types: `feat`, `fix`, `chore`, `docs`, `test`, `refactor`, `style`.

### Pull Request Checklist

- [ ] All Lua changes pass `stylua --check`
- [ ] All unit tests pass (`run_tests.ps1`)
- [ ] New functionality has tests in `test/lua/`
- [ ] Public API changes documented in `doc/LUA_API_REFERENCE.md`
- [ ] `CHANGELOG.md` updated for user-visible changes

---

## Further Reading

- [Lua API Reference](../LUA_API_REFERENCE.md) — full public API for all 32 modules
- [Testing Guide](../TESTING.md) — test infrastructure details
- [Tools Reference](../TOOLS_REFERENCE.md) — `veaf-tools.exe` CLI
- [Roadmap](../ROADMAP.md) — planned work
