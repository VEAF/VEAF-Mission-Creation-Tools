# AI Agent Instructions for VEAF Mission Creation Tools

## Communication & Collaboration

- **Language:** Français (speak to the developer in French)
- **Tone:** Treat the developer as an equal (direct, practical, no obsequiousness)
- **Style:** Brief explanations in chat, let code/docs speak for themselves

### Documentation Standards
- **English only:** All source code, comments, and documentation files
- **Harmonize:** Match existing patterns, conventions, and tone in the repository
- **Reuse:** Existing solutions first; ask before proposing alternatives
- **Avoid:** Meta-documentation ("What was done", "Implementation summary", etc.)

### File Naming Conventions
- Be specific: `BUILD_AND_RELEASE_GUIDE.md` ✅, not `IMPLEMENTATION_SUMMARY.md` ❌
- Standards: `README.md`, `QUICKSTART.md`, `ARCHITECTURE.md` ✅

### Code Quality
- **Always activate venv first:** `. .\.venv\Scripts\Activate.ps1` (PowerShell) or `source .venv/bin/activate` (Bash)
- Type hints on all functions, docstrings for public methods
- Follow existing code style, include error handling
- Test cross-platform compatibility when possible
- Remove old/unused scripts when replacing them

---

## Project Overview

VEAF Mission Creation Tools is a hybrid **Lua + Python** system for designing and running dynamic DCS World missions. The architecture separates **runtime scripting** (Lua executing in DCS) from **design-time tools** (Python CLI for mission manipulation).

### Key Distinction
- **Runtime** (`src/scripts/veaf/`): Lua modules that execute within DCS missions providing spawning, asset management, radio systems
- **Design-time** (`src/python/veaf-tools/`): Python CLI tools for mission file manipulation (miz format), preprocessing, injection

---

## Architecture Patterns

### Core Concepts

1. **Mission Files (`.miz`)** - ZIP archives containing Lua dictionaries:
   - `mission` - Main mission data (groups, triggers, settings)
   - `options` - Graphics and gameplay options
   - `theatre` - Map information
   - `warehouses` - Supply configurations
   - Uses [luadata](https://github.com/toml-lang/toml-py) library for Lua serialization

2. **Worker Pattern** - Each tool follows consistent design:
   - `*_worker.py` classes with `run()` method entry point
   - Async-friendly patterns using `Path` objects
   - Error handling via `typer.Abort` exception
   - Logging through centralized `logger` instance

3. **Plugin System** - Injector tools are modular:
   - `weather_injector/`, `waypoints_injector/`, `aircrafts_injector/` etc.
   - Each can extract from AND inject into missions (dual mode)
   - Config-driven via YAML files

### Data Flow

```
Mission (.miz) → Read/Parse
    ↓
Python Tool (modify Lua structures)
    ↓
Write/Serialize → Mission (.miz)
```

---

## Python Code Conventions

### Module Organization
- **`veaf_libs/`** - Shared utilities (logger, progress, miz_tools)
- **`mission_tools/`** - Core miz file handling (DcsMission dataclass, read_miz, write_miz)
- **`{tool_name}_injector/`** - Specialized injectors with submodules:
  - `*_worker.py` - Main entry point (async/CLI compatible)
  - `*_manager.py` - Data transformation logic
  - `models.py` - Dataclass definitions
  - `*_README.py` - Help/documentation generation

### Logger Pattern
```python
from veaf_libs.logger import logger, console

logger.info("Processing mission...")
logger.debug("Detailed info")
logger.warning("Watch out")
logger.error("Failed", raise_exception=True)
```
- Logs to both file (`{module}.log`) and console (via Rich)
- Centralized in `veaf_libs/logger.py`

### Dataclass Usage
```python
from dataclasses import dataclass, field
from typing import Dict, Optional

@dataclass
class MissionConfig:
    version: str
    mappings: Dict[str, str] = field(default_factory=dict)
```
- Extensive use of `@dataclass` with `field(default_factory=...)` for mutable defaults
- YAML serialization via `yaml.safe_load/dump`

### Type Hints
- Always use `Path` from `pathlib` for file operations (not strings)
- Use `Optional[T]` for nullable fields
- Use `Dict[str, T]`, `List[T]` for collections

---

## Build & Release Workflow

### Key Script: `build-and-release.py`

Main orchestrator for the entire build pipeline:

```bash
# Activate venv first (critical!)
. .\.venv\Scripts\Activate.ps1

# Build
python build-and-release.py build --version 6.0.4

# Publish to GitHub (requires GITHUB_TOKEN)
python build-and-release.py publish --version 6.0.4
```

**What it does:**
1. Validates prerequisites (Git, Python, PyInstaller)
2. Compiles Lua scripts from `src/scripts/veaf/` → `build/`
3. Runs PyInstaller on `src/python/veaf-tools/veaf-tools.py` → `dist/veaf-tools.exe`
4. Creates `published.zip` with all artifacts
5. Publishes to GitHub Release with SHA256 checksum

**Configuration:** `veaf-tools-config.yaml` (optional)
```yaml
github:
  owner: VEAF
  repo: VEAF-Mission-Creation-Tools
  token: ${GITHUB_TOKEN}  # or env var
```

### Development Build Tasks

The workspace includes pre-configured build tasks (visible in VS Code):
- `build Demo mission` - Builds test/Demo mission (uses sample Lua)
- `build Helo Training mission` - Helicopter training scenario
- `test Mission Editor` - Runs mission editor validation

---

## Lua Runtime Scripts

### Module Loading Pattern

Lua modules follow a strict loading order (see `src/scripts/veaf/`):

1. **veaf.lua** - Core framework (logging, state management)
2. **veaf*.lua** - Feature modules (veafSpawn, veafRadio, veafMove, etc.)
3. **Dynamic modules** - Via `VeafDynamicLoader.lua` at mission start

### Key Points
- **No external dependencies** - Pure Lua, runs in DCS environment
- **Logging** - Via `veaf.loggers.new()` for module-scoped logging
- **State isolation** - Each module uses local scope patterns
- **Backward compatibility** - Mission files are sensitive to breaking changes

---

## Important Conventions

### File & Naming Standards
- Python files: `snake_case.py`
- Classes: `PascalCase` (e.g., `MissionBuilder`, `WeatherInjector`)
- Constants: `UPPER_SNAKE_CASE`
- Lua files: `veafFeatureName.lua` (lowercase 'veaf' prefix)

### Error Handling
- Python: Use `typer.Abort` for CLI errors
- Propagate `logger.error(..., raise_exception=True)` up the stack
- **Never silently swallow errors** - visibility is critical for mission makers

### Documentation
- User guides in `DETAILED_MANUAL.md` (reference), `BUILD_WORKFLOW.md` (procedures)
- API docs in source code docstrings (Python)
- Lua comments inline (no separate documentation needed)

---

## Integration Points & Dependencies

### External Libraries
- **typer** - CLI framework (argument parsing, help generation)
- **pyyaml** - Config file loading (YAML format)
- **rich** - Terminal UI (progress bars, colored output, tables)
- **luadata** - Lua serialization/deserialization
- **lupa** - Python ↔ Lua bridging (for dynamic features)
- **Pillow** - Image processing (weather icon generation)
- **pydantic** - Data validation (newer code)

### GitHub Integration
- Automated via `build-and-release.py` using GitHub REST API
- Requires `GITHUB_TOKEN` environment variable
- Creates tags, releases, uploads artifacts automatically

### DCS World Integration
- Missions are ZIP files with Lua dictionaries
- Scripts injected into `mission/` → `do file(...)` at mission start
- No API calls - everything is file-based manipulation

---

## Testing & Validation

### Running Tools Locally
```bash
# Activate venv
. .\.venv\Scripts\Activate.ps1

# Run a tool directly
python -m veaf_tools weather-inject --mission test/test.miz --output test/test-out.miz

# Run tests (if available)
python -m pytest test/
```

### Mission Validation
- Use `test Mission Editor` task to validate mission structure
- Check `veaf-tools.log` for runtime errors
- Validate Lua syntax before injecting

---

## Questions to Ask Before Implementation

1. **Is this runtime Lua or design-time Python?** (Different testing, deployment)
2. **Does it modify mission files?** (Need to handle miz format, ZIP, Lua serialization)
3. **Is this a new injector?** (Follow the `{tool_name}_injector/` pattern)
4. **Does it integrate with DCS?** (Consider mission loading, state persistence)

---

## Quick Checklist for New Features

- [ ] Follows Worker/Manager pattern if adding new tool
- [ ] Uses `logger` for all output (no print statements)
- [ ] Type hints on all functions
- [ ] Docstrings for public methods
- [ ] Configuration via YAML (not hardcoded)
- [ ] Error messages are user-friendly and actionable
- [ ] Tested against actual `.miz` files (not mocked)
- [ ] Updated `DETAILED_MANUAL.md` if user-facing

---

**Note:** Communication preferences (language, tone, documentation standards) are in [`.copilot-instructions.md`](../.copilot-instructions.md) at the repository root. This file focuses on technical architecture and code patterns.
