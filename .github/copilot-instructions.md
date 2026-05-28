# Copilot Instructions — VEAF Mission Creation Tools (project-specific)

> This file complements `copilot-instructions-generic.md`. Only project-specific overrides and additions are documented here.
>
> Start every session by reading `copilot-instructions-generic.md` and applying it as base. Then apply the overrides below.

## Overrides

### Branches
- Integration branch: `develop` (currently `develop-v6` during v6 transition — temporary)
- Main branch: `master`

### Package manager
- **Poetry** — activate venv: `.\.venv\Scripts\Activate.ps1`
- Install dependencies: `poetry install`

### Linting commands
- **Python**: `ruff check src/python/ --fix` then `ruff format src/python/`
- **Lua**: `luacheck --config .luacheckrc src/scripts/veaf/` then `stylua --check src/scripts/veaf/`
- **All at once**: `pre-commit run --all-files`

### Test commands
- **Python**: `poetry run pytest`
- **Lua**: `poetry run test-lua`

### Version location
- `pyproject.toml` → `[tool.poetry] version`

### Per-change steps (override)
1. Make changes
2. Update tests — Python: `src/python/veaf-tools/test_*.py`, Lua: `test/lua/test_<module>.lua`
3. Run quality checks:
   - Python changed: `ruff check src/python/ --fix` + `poetry run pytest` + `mypy src/python/veaf-tools/`
   - Lua changed: `luacheck --config .luacheckrc src/scripts/veaf/` + `stylua --check src/scripts/veaf/` + `poetry run test-lua`
4. Update `CHANGELOG.md` under `[Unreleased]`
5. Bump patch version in `pyproject.toml`
6. `poetry install`

### mypy mode
- **Not strict** — incremental cleanup in progress (`disallow_untyped_defs = false`)
- New files must be fully typed (zero mypy errors)
- Files with known errors are listed in `[[tool.mypy.overrides]]` with `ignore_errors = true` — do not add new entries; fix the errors instead

### Coverage threshold
- Current minimum: **15%** (transitional baseline)
- Do not decrease coverage — new code must have tests
- Target: **50%** (planned future milestone)

### Type hints syntax
- Use `str | None` syntax — `UP007` enabled (see ticket TYP-001)

### Test location
- Python tests: `test/python/` (files matching `test_*.py`) — mirrors `test/lua/` convention (see ticket TST-001)
- Lua tests: `test/lua/test_<module>.lua`

### TDD — applies to Python and Lua
Generic TDD rules apply to both Python (`pytest`) and Lua (`luaunit` + DCS mocks in `test/lua/`).
Exception: pure routing/dispatch modules where DCS mock complexity makes unit testing impractical.

### CHANGELOG
- `CHANGELOG.md` is **maintained manually by the AI agent**
- Update `[Unreleased]` after every change (Added / Changed / Removed sections, one entry per feature/fix — not per commit)
- Do **not** regenerate with git-cliff — git-cliff is used only locally during release consolidation

### Release notes workflow
Release = AI-assisted consolidation:
1. AI reads `CHANGELOG.md` `[Unreleased]` + runs `git cliff --latest` locally for commit-level detail
2. AI asks consolidation questions (scope, highlights, breaking changes, audience)
3. AI writes feature-oriented `RELEASE_NOTES.md`
4. Developer reviews and validates
5. Commit `RELEASE_NOTES.md` + stamp `CHANGELOG.md` → tag → push → CI uses `RELEASE_NOTES.md` as-is

### Backlog / Roadmap paths
- `doc/backlog.md` (not root `BACKLOG.md`)
- `doc/ROADMAP.md`

### Notes system
When user says **"note"** or **"note that"**, update `.github/copilot-instructions.md` (this file).

### Keywords

| Keyword | Meaning |
|---------|---------|
| ticket  | Entry in `doc/backlog.md` |
| build   | `poetry run veaf-build build` |
| publish | `poetry run veaf-build publish` (creates GitHub release) |
| module  | A VEAF Lua module in `src/scripts/veaf/` |
| mission | A `.miz` DCS mission file |

---

## Project Stack

- **Lua 5.1** runtime scripts executing inside DCS World
- **Python 3.11+** CLI tools via Poetry (Typer + Rich)
- **pyproject.toml** — single source of truth for version, linting, and test config
- Pre-commit hooks: ruff + ruff-format (Python), StyLua + luacheck (Lua), detect-secrets

---

## Architecture

### Key Distinction
- **Runtime** (`src/scripts/veaf/`): Lua modules executing inside DCS missions — spawning, asset management, radio, command dispatch
- **Design-time** (`src/python/veaf-tools/`, package `veaf_build`): Python CLI for mission file manipulation, preprocessing, injection

### Mission Files (`.miz`)
ZIP archives containing Lua dictionaries:
- `mission` — groups, triggers, settings
- `options` — graphics and gameplay options
- `theatre` — map information
- `warehouses` — supply configurations
- Serialized/deserialized via the bundled `luadata` library (excluded from mypy and ruff)

### Worker Pattern
Each Python tool follows this structure:
- `*_worker.py` — entry point with `run()` method
- `*_manager.py` — data transformation logic
- `models.py` — dataclass definitions
- `*_README.py` — help/documentation generation

### Plugin System
Injector tools are modular (`weather_injector/`, `waypoints_injector/`, `aircrafts_injector/`, etc.):
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
- **`veaf_libs/`** — shared utilities (logger, progress, miz_tools)
- **`mission_tools/`** — core miz file handling (`DcsMission` dataclass, `read_miz`, `write_miz`)
- **`{tool_name}_injector/`** — specialized injectors with the worker/manager/models structure above

### Logger Pattern
```python
from veaf_libs.logger import logger, console

logger.info("Processing mission...")
logger.debug("Detailed info")
logger.warning("Watch out")
logger.error("Failed", raise_exception=True)
```
- Logs to file (`{module}.log`) and console (via Rich)
- No `print()` statements — always use `logger`

### Dataclass Usage
```python
from dataclasses import dataclass, field

@dataclass
class MissionConfig:
    version: str
    mappings: dict[str, str] = field(default_factory=dict)
```
- `T | None` for nullable fields
- YAML serialization via `yaml.safe_load/dump`

### Error Handling
- Use `typer.Abort` for CLI errors
- Propagate via `logger.error(..., raise_exception=True)`
- Never silently swallow errors — visibility is critical for mission makers

---

## Lua Code Conventions

### Module Loading Order
1. `veaf.lua` — core framework (logging, state management)
2. `veaf*.lua` — feature modules (`veafSpawn`, `veafRadio`, `veafMove`, etc.)
3. Dynamic modules via `VeafDynamicLoader.lua` at mission start

### Quality Gates
- **Formatting**: StyLua (`.stylua.toml`)
- **Static analysis**: luacheck (`.luacheckrc`)
- **Unit tests**: luaunit + DCS mocks (`test/lua/dcs_mocks.lua`) — one file per module (`test/lua/test_<module>.lua`)

### Key Constraints
- No external dependencies — pure Lua 5.1, runs in DCS environment
- Logging via `veaf.loggers.new()` for module-scoped logging
- State isolation — each module uses local scope patterns
- Backward compatibility — mission files are sensitive to breaking changes

### Naming
- Files: `veafFeatureName.lua` (lowercase `veaf` prefix)
- Module table: `veafFeatureName = {}` (camelCase)
- Classes: `VeafFeatureName` (PascalCase)

---

## Build & Release

### Commands
```powershell
.\.venv\Scripts\Activate.ps1

# Build release package (Lua scripts + Python exe)
poetry run veaf-build build --version 6.1.5

# Publish to GitHub (creates release, uploads artifacts)
poetry run veaf-build publish --version 6.1.5

# CI: build + publish non-interactively
poetry run veaf-build build-and-publish --version 6.1.5 --ci
```

### What `veaf-build build` Does
1. Validates prerequisites (Git, Python, PyInstaller)
2. Compiles Lua scripts from `src/scripts/veaf/` → `build/`
3. Runs PyInstaller → `dist/veaf-tools.exe`
4. Creates `published.zip` with all artifacts

### Release Workflow
1. Complete all tickets for the batch
2. Run AI-assisted release consolidation (see Release notes workflow above)
3. Bump version in `pyproject.toml` (`MINOR` default — confirm `MAJOR` with user)
4. Stamp `CHANGELOG.md`: replace `[Unreleased]` with `[x.y.z] — YYYY-MM-DD`
5. Update `doc/ROADMAP.md`: move batch → Completed
6. Commit `RELEASE_NOTES.md`, `CHANGELOG.md`, `pyproject.toml`
7. Open PR `release/x.y.z` → `master`
8. After merge: `git tag published-vx.y.z` + push tag → CI builds and publishes automatically

---

## Integration Points & Dependencies

### Python Libraries
- **typer** — CLI framework
- **pyyaml** — config file loading
- **rich** — terminal UI (progress bars, colored output)
- **luadata** — Lua serialization/deserialization (bundled, excluded from mypy/ruff)
- **lupa** — Python ↔ Lua bridging
- **Pillow** — image processing (weather icons)
- **pydantic** — data validation
- **avwx-engine** — METAR/aviation weather parsing
- **astral** — sun/moon calculations
- **InquirerPy** — interactive CLI prompts

### CI/CD
- `python-quality.yml` — ruff + mypy + pytest on every push
- `lua-ci.yml` — luacheck + test-lua on every push
- `release.yml` — builds and publishes on `published-v*` tag push; reads committed `RELEASE_NOTES.md`

### DCS World Integration
- Missions are ZIP files with Lua dictionaries
- Scripts injected via `do file(...)` at mission start
- No API calls — everything is file-based

---

## Testing & Validation

### Python
```powershell
.\.venv\Scripts\Activate.ps1
poetry run pytest
```
Tests live in `src/python/veaf-tools/` (files `test_*.py`). Coverage report generated automatically.

### Lua
```powershell
poetry run test-lua
```
Tests in `test/lua/test_<module>.lua`, DCS API mocked via `test/lua/dcs_mocks.lua`.

### Mission Validation
- Check `veaf-tools.log` for runtime errors
- Validate Lua syntax with `luacheck` before injecting

---

## Questions to Ask Before Implementation

1. **Runtime Lua or design-time Python?** (Different testing, deployment paths)
2. **Does it modify mission files?** (miz format, ZIP, Lua serialization)
3. **New injector?** (Follow `{tool_name}_injector/` Worker/Manager pattern)
4. **Integrates with DCS?** (Consider mission loading, state persistence, backward compatibility)

---

## Quick Checklist for New Features

- [ ] Tests written first (TDD) — pytest for Python, luaunit for Lua
- [ ] Follows Worker/Manager pattern (Python tools)
- [ ] Uses `logger` for all output (no `print()`)
- [ ] Type hints on all functions (`str | None` syntax), Google-style docstrings
- [ ] New files: zero mypy errors (do not add to `ignore_errors` list)
- [ ] Configuration via YAML (not hardcoded)
- [ ] Error messages user-friendly and actionable
- [ ] `CHANGELOG.md` `[Unreleased]` updated
- [ ] Patch version bumped in `pyproject.toml` + `poetry install`
