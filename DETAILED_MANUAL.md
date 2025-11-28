# VEAF Tools - Detailed Manual

Complete technical reference for all VEAF build and release tools.

## Table of Contents

- [build-and-release.py](#build-and-releasepy)
- [veaf-tools-updater.py](#veaf-tools-updaterpy)
- [Python Environment](#python-environment)
- [Architecture](#architecture)
- [Development](#development)

---

## build-and-release.py

Main orchestrator for building Lua scripts, Python executables, and publishing releases.

### Overview

The tool manages the complete release pipeline:
1. Validates prerequisites (Git, Python, PyInstaller)
2. Compiles Lua scripts with text processing
3. Builds Python executables via PyInstaller
4. Creates release packages (ZIP files)
5. Publishes to GitHub with release notes

### Features Supported

**Runtime Features** (Loaded in DCS missions):
- Unit Spawning - Aircraft, ground units, portable TACANs
- Mission Types - Air-to-ground, air-to-air, transport, carrier operations
- Asset Management - Tankers, AWACS, aircraft carriers with state tracking
- Weather & ATC - Dynamic weather injection, ATC services
- Zones & Artillery - Shelling, illumination, zone management
- Named Points - Position management with ATC services
- Radio System - Dynamic radio menus, frequency management
- Remote Control - NIOD (RPC) and SLMOD socket integration
- Security - Role-based action permissions
- Templates - Reusable group definitions
- FARP Population - Auto-populate forward air bases
- Grass Runway Setup - Configure unprepared airfields
- Spawning Rules - Data-driven unit spawning at mission start

**Design-Time Features** (Mission creation automation):
- Mission Normalization - Standardize mission files for easy diffing
- Radio Presets - Globally inject standard frequency plans for the human groups into missions
- Weather Injection - Insert real weather into missions
- Aircraft Groups Injection - Inject predefined aircraft groups (e.g. templates, or spawnable groups) into missions; supports extraction from a mission too
- Waypoints Injection - Inject predefined waypoints for the human groups (e.g. bullseye) into missions; supports extraction from a mission too

### Architecture

#### BuildAndReleaseWorker Class

Main worker class that orchestrates the build process.

**Constructor:**
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

**Key Methods:**

| Method | Purpose |
|--------|---------|
| `validate_prerequisites()` | Check Git, Python, PyInstaller are available |
| `build_lua_scripts()` | Compile Lua with progress bar |
| `build_python_executables()` | Build EXE files with PyInstaller |
| `create_release_package()` | Create ZIP with all artifacts |
| `_do_publish_to_github()` | Manage GitHub release process |
| `run()` | Execute complete workflow |

### Lua Compilation Process

Compiles ~31 Lua scripts in specific order:

**Input:** `src/scripts/veaf/`
**Output:** `published/veaf-scripts.lua`

**Process:**
1. Clean `build/` directory
2. Copy Lua files from source
3. Modify `veaf.lua` flags:
   - Development flag for dev builds
   - Security flags
4. Comment out trace/debug logging (non-dev builds)
5. Concatenate in order with version markers
6. Write UTF-8 encoded output
7. Copy to `published/` directory

**Features:**
- Progress bar with 36+ steps
- Preserves file order for dependencies
- Handles BOM removal
- Validates file integrity

### Python Execution Building

Uses PyInstaller to create Windows executables.

**Executables:**
1. `veaf-tools.exe` - Main application
2. `veaf-tools-updater.exe` - Update utility

**PyInstaller Options:**
```bash
pyinstaller
  --onefile                          # Single executable
  --distpath dist/                   # Output directory
  --specpath dist/build/             # Spec directory
  --workpath dist/build/             # Build workspace
  [entry_point]                      # Python file to compile
```

**Output Location:** `dist/`

**Size:** ~24-25 MB per executable

### Release Package Creation

Creates `published.zip` with all artifacts.

**Contents:**
- All Lua scripts from `published/`
- `veaf-tools.exe`
- `veaf-tools-updater.exe`

**Size:** ~47 MB compressed

### GitHub Publishing

Manages release creation and asset upload.

**Process:**
1. Delete existing release (if `--force`)
2. Create git tags:
   - `published-v{version}` (e.g., `published-v6.0.4`)
   - `published-latest`
3. Push tags to GitHub
4. Create GitHub release with notes
5. Upload `published.zip`
6. Upload `veaf-tools-updater.exe`

**Authentication:**
- Passes GitHub token via `GH_TOKEN` environment variable
- Uses GitHub CLI (`gh`) for API calls

**Error Handling:**
- Captures and logs stdout/stderr separately
- Returns detailed error messages
- Continues on non-critical failures

### Configuration File

Supports `veaf-tools-config.yaml` for persistent settings.

**Structure:**
```yaml
github:
  token: "ghp_..."
  owner: "VEAF"
  repo: "VEAF-Mission-Creation-Tools"

publish:
  draft: false
  prerelease: false
  skipTag: false
```

**Loading:**
```python
def load_config() -> Dict[str, Any]:
    config_path = Path.cwd() / "veaf-tools-config.yaml"
    if not config_path.exists():
        return {}
    with open(config_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}
```

---

## veaf-tools-updater.py

Utility for downloading and installing VEAF Tools releases.

### Overview

The updater tool provides:
- Automatic release discovery
- Download management
- Extraction to mission folders
- Configuration management
- Checksum verification

### Architecture

#### UpdateWorker Class

Main worker class for update operations.

**Constructor:**
```python
UpdateWorker(
    mission_folder: Optional[Path] = None,
    verbose: bool = False,
    config: Optional[Dict[str, Any]] = None
)
```

**Key Methods:**

| Method | Purpose |
|--------|---------|
| `discover_latest_release()` | Fetch latest from GitHub |
| `download_release()` | Download artifacts |
| `extract_to_folder()` | Extract ZIP to mission folder |
| `verify_checksum()` | Validate downloaded files |

### Workflow

**Update Process:**

1. **Discover:** Fetch latest release from GitHub API
2. **Download:** Get `published.zip`
3. **Verify:** Calculate and compare SHA256
4. **Extract:** Unzip to mission folder
5. **Configure:** Update local settings

**Error Handling:**
- Validates release format
- Checks file integrity
- Handles network failures
- Provides clear error messages

---

## Python Environment

### Dependencies

**Runtime:**
```
typer>=0.12.0          # CLI framework
rich>=13.7.0           # Terminal UI
pyyaml>=6.0            # Configuration files
```

**Development:**
```
pyinstaller>=6.0       # Executable building
```

### Virtual Environment Setup

**Create:**
```bash
python -m venv .venv
```

**Activate (PowerShell):**
```bash
. .\.venv\Scripts\Activate.ps1
```

**Install Requirements:**
```bash
pip install -r requirements.txt
```

### Python Version

- **Recommended:** Python 3.9+
- **Tested:** Python 3.13.9

---

## Architecture

### Directory Structure

```
.
├── build-and-release.py          # Main build orchestrator
├── veaf-tools-updater.py         # Update utility
├── src/
│   ├── scripts/veaf/             # Lua scripts to compile
│   └── python/veaf-tools/        # Python source code
├── published/                     # Compiled Lua output
├── dist/                          # PyInstaller output
├── build/                         # Temporary build files
├── veaf-tools-config.yaml        # User configuration
└── RELEASE_NOTES.md              # Release documentation
```

### Workflow Pipeline

```
┌─────────────────────────────────────┐
│ User runs: build-and-release.py     │
└────────────┬────────────────────────┘
             │
             ├─ Validate Prerequisites
             │
             ├─ Build Lua Scripts
             │  ├─ Copy source files
             │  ├─ Modify flags
             │  ├─ Concatenate
             │  └─ Write to published/
             │
             ├─ Build Python Executables
             │  ├─ Run PyInstaller for veaf-tools
             │  ├─ Run PyInstaller for updater
             │  └─ Output to dist/
             │
             ├─ Create Release Package
             │  ├─ Create published.zip
             │  └─ Calculate SHA256
             │
             └─ (Optional) Publish to GitHub
                ├─ Create git tags
                ├─ Push tags
                ├─ Create GitHub release
                └─ Upload assets
```

### Error Handling

**Graceful Degradation:**
- Missing Lua files → skip compilation
- PyInstaller not found → suggest install
- GitHub CLI missing → warn but continue
- No token → skip GitHub upload

**Recovery:**
- Cleanup temporary files on failure
- Preserve existing artifacts if build fails
- Allow republishing with `--force`

---

## Development

### Adding New Features

#### Adding Lua Scripts

1. Add `.lua` file to `src/scripts/veaf/`
2. File will be automatically included in next build
3. Update compile order if dependencies change (in `build_lua_scripts()`)

#### Adding Build Options

1. Add parameter to `typer.Option()` in `build()` or `publish()` command
2. Pass value to `BuildAndReleaseWorker` constructor
3. Implement logic in worker class

#### Adding Config File Options

1. Add section to `veaf-tools-config.example.yaml`
2. Load in `load_config()` function
3. Extract in worker `__init__()` or command function
4. Update `BUILD_WORKFLOW.md` documentation

### Testing

**Unit Tests:**
```bash
python -m pytest tests/
```

**Manual Testing:**
```bash
# Syntax check
python -m py_compile build-and-release.py

# Help text
python build-and-release.py build --help
python build-and-release.py publish --help

# Dry run
python build-and-release.py build --verbose
```

### Code Style

- **Formatter:** black (configured in pyproject.toml)
- **Linter:** pylint/flake8
- **Type hints:** Required for public methods
- **Docstrings:** Google-style for classes and methods

### Logging

**Levels:**
- `DEBUG` - Only with `--verbose` flag
- `INFO` - Important milestones
- `WARNING` - Non-fatal issues
- `ERROR` - Build/publish failures

**Output:**
- Console: Spinners, progress bars, formatted messages
- File: `build-and-release.log` with full details

---

## Troubleshooting for Developers

### PyInstaller Issues

**Problem:** "Cannot find module X"
- **Solution:** Ensure all imports are at module level
- **Check:** Run `python src/python/veaf-tools/veaf-tools.py` directly first

**Problem:** Executable is too large
- **Solution:** Remove unused imports, check `--collect-all` requirements

### Lua Compilation Issues

**Problem:** Scripts not in correct order
- **Solution:** Check file list in `build_lua_scripts()` method
- **Verify:** Dependencies between files match order

**Problem:** Unicode/encoding errors
- **Solution:** Ensure files are UTF-8 encoded
- **Check:** Use `file.encoding` in text editor

### GitHub Publishing Issues

**Problem:** "gh not found"
- **Solution:** Install GitHub CLI: https://cli.github.com/
- **Verify:** `gh --version` works

**Problem:** "Repository not found"
- **Solution:** Check `owner` and `repo` in config
- **Verify:** Token has correct `repo` scope

---

## Performance Optimization

### Build Time

**Lua Compilation:**
- ~2-3 seconds for all scripts
- Progress bar shows ~36 steps

**Python Build:**
- ~30-60 seconds per executable
- Depends on system speed and PyInstaller version

**Total Build:** ~2-3 minutes (including Python)

### Optimization Tips

- Use `--skip-lua` if only Python changed
- Use `--skip-python` if only Lua changed
- Disable `--verbose` for faster output parsing
- Build on SSD for better performance

---

## Version History

### v6.0.3 (November 28, 2025)

- Added support for veaf-tools-config.yaml
- Implemented token precedence (CLI > config > env)
- Fixed GitHub release publishing (removed --clobber, using delete)
- Added `--force` flag for republishing
- Bilingual release notes (English + Français)
- Both executables included in ZIP
- Updater executable uploaded separately to release

### v6.0.2

- Migrated from PowerShell to pure Python Lua compilation
- Added rich Progress bar for build visibility
- Captured PyInstaller output to reduce console spam

### v6.0.1

- Initial refactoring with typer and rich
- Separated build and publish commands

---

**Last Updated:** November 28, 2025
