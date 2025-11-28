# [![VEAF-logo]][VEAF website] Mission Creation Tools

[![Badge-Discord]][VEAF Discord]
![Badge-Wakatime]

Complete toolkit for creating dynamic missions in DCS World using VEAF Lua scripts and automation tools.

**Current Version:** 6.0.3 (November 28, 2025)  
**Python Required:** 3.9+  
**License:** [MIT](LICENSE.md)

---

## Table of Contents

- [Overview](#overview)
- [Documentation](#documentation)
- [Quick Start](#quick-start)
- [Build & Release Workflow](#build--release-workflow)
- [Contributing & Support](#contributing--support)

---

## Overview

VEAF Mission Creation Tools provides comprehensive automation and mission design capabilities:

### Runtime Features

Loaded at mission start, providing dynamic functionality:
- **Unit Spawning** - Aircraft, ground units, portable TACANs
- **Mission Types** - Air-to-ground, air-to-air, transport, carrier operations
- **Asset Management** - Tankers, AWACS, aircraft carriers with state tracking
- **Weather & ATC** - Dynamic weather injection, ATC services
- **Zones & Artillery** - Shelling, illumination, zone management
- **Named Points** - Position management with ATC services
- **Radio System** - Dynamic radio menus, frequency management
- **Remote Control** - NIOD (RPC) and SLMOD socket integration
- **Security** - Role-based action permissions
- **Templates** - Reusable group definitions
- **FARP Population** - Auto-populate forward air bases
- **Grass Runway Setup** - Configure unprepared airfields
- **Spawning Rules** - Data-driven unit spawning at mission start

### Design-Time Features

Build-time automation for mission creation:
- **Mission Normalization** - Standardize mission files for easy diffing
- **Radio Presets** - Globally inject standard frequency plans for the human groups into missions.
- **Weather Injection** - Insert real weather into missions
- **Aircraft Groups Injection** - Inject predefined aircraft groups (e.g. templates, or spawnable groups) into missions; supports extraction from a mission too.
- **Waipoints Injection** - Inject predefined waypoints for the human groups (e.g. bullseye) into missions; supports extraction from a mission too.


### Build & Release Tools

**build-and-release.py** orchestrates the complete pipeline:
- ✅ Lua script compilation from source
- ✅ Python executable building (PyInstaller)
- ✅ Release package creation (ZIP)
- ✅ GitHub publishing with release notes
- ✅ Configuration file support
- ✅ Token-based authentication

---

## Documentation

### Primary Guides (Start Here)

| Document | Purpose |
|----------|---------|
| **[BUILD_WORKFLOW.md](BUILD_WORKFLOW.md)** | Step-by-step build and release workflow - commands and options |
| **[DETAILED_MANUAL.md](DETAILED_MANUAL.md)** | Complete technical reference - all functions and configuration |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | System design - how components interact |
| **[VEAF_TOOLS_GUIDE.md](VEAF_TOOLS_GUIDE.md)** | Mission maker guide - using tools in DCS |

### Additional Resources

- **[README-5.0.0.md](README-5.0.0.md)** - Upgrade guide from v5.x
- **[old_documentation/](old_documentation/)** - Legacy documentation archive
- **[project_rewrite_in_python.md](project_rewrite_in_python.md)** - Technical migration details
- **[VEAF Documentation Site][documentation-site]** - Complete online documentation
- **[Documentation Repository][documentation-repo]** - Contributing guide

---

## Quick Start

### For Mission Makers

1. **Get the latest release:**
   ```bash
   # Download from GitHub releases page
   # Extract veaf-tools.exe to your mission folder
   ```

2. **Update your tools:**
   ```bash
   veaf-tools-updater.exe update
   ```

3. **Use in missions:**
   - Copy `published/veaf-scripts.lua` to your DCS mission folder
   - Include it in your mission Lua environment

### For Developers

1. **Install prerequisites:**
   ```bash
   # Requires: Python 3.9+, Git, GitHub CLI (gh)
   pip install -r requirements.txt
   ```

2. **Build:**
   ```bash
   python build-and-release.py build
   ```

3. **Test:**
   ```bash
   # Run test mission with new scripts
   ./testMissionEditor.cmd
   ```

4. **Publish release:**
   ```bash
   python build-and-release.py publish --version 6.0.3
   ```

---

## Build & Release Workflow

### One-Minute Overview

```bash
# Build Lua scripts + Python executables
python build-and-release.py build

# Create GitHub release with artifacts
python build-and-release.py publish --version 6.0.3

# Force overwrite existing release
python build-and-release.py publish --version 6.0.3 --force
```

### Configuration

Create `veaf-tools-config.yaml` for persistent settings:

```yaml
github:
  token: "ghp_xxx..."
  owner: "VEAF"
  repo: "VEAF-Mission-Creation-Tools"
```

**Token Precedence:** CLI argument → config file → `GITHUB_TOKEN` environment variable

See **[BUILD_WORKFLOW.md](BUILD_WORKFLOW.md)** for complete build commands and options.

---

## Architecture

### Directory Structure

```
src/
  scripts/veaf/          # 31+ Lua modules
  python/                # Python source code

published/
  veaf-scripts.lua       # Compiled Lua (output)

dist/
  veaf-tools.exe         # Main application (output)
  veaf-tools-updater.exe # Update utility (output)

build/                   # Temporary compilation files
```

### Build Pipeline

```
Source Files
    ↓
validate_prerequisites() ─→ Check Git, Python, PyInstaller
    ↓
build_lua_scripts() ─→ Compile 31 Lua modules
    ↓
build_python_executables() ─→ Create EXE files
    ↓
create_release_package() ─→ ZIP all artifacts
    ↓
(Optional) _do_publish_to_github() ─→ GitHub release
```

See **[DETAILED_MANUAL.md](DETAILED_MANUAL.md)** for complete technical architecture.

---

## Version History

### v6.0.3 (November 28, 2025)

- ✅ Configuration file support (`veaf-tools-config.yaml`)
- ✅ Token precedence: CLI > config > environment
- ✅ Fixed GitHub release overwriting (use `--force`)
- ✅ Both executables included in release ZIP
- ✅ Updater EXE available standalone
- ✅ Bilingual release notes (English + Français)

### v6.0.2 (November 27, 2025)

- Migrated from PowerShell to pure Python compilation
- Added progress bar and rich terminal UI
- Improved output management

### v6.0.1

- Initial refactoring with typer CLI framework

---

## Contributing & Support

### Getting Help

1. **Check the documentation:**
   - [BUILD_WORKFLOW.md](BUILD_WORKFLOW.md) - common tasks
   - [DETAILED_MANUAL.md](DETAILED_MANUAL.md) - technical details
   - [ARCHITECTURE.md](ARCHITECTURE.md) - system design

2. **Ask the community:**
   - [VEAF Discord][VEAF Discord] - real-time help
   - [VEAF Forum][VEAF forum] - discussions
   - [GitHub Issues][GitHub] - bug reports

### Contributing Code

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test your modifications
5. Submit a pull request

### Reporting Issues

Include:
- Exact command you ran
- Full error output with `--verbose`
- Python version: `python --version`
- Windows PowerShell version

---

## Credits & Links

**VEAF Project:** [VEAF Website][VEAF website]  
**Lead Developer:** [Zip on Github]  
**Community:** [VEAF Discord][VEAF Discord]  
**DCS World:** [Digital Combat Simulator][DCS]  

If you like these tools, you can [support the project][Zip on coff.ee]!

---

**Last Updated:** November 28, 2025


[Badge-Discord]: https://img.shields.io/discord/471061487662792715?label=VEAF%20Discord&style=for-the-badge
[Badge-Wakatime]: https://wakatime.com/badge/github/VEAF/VEAF-Mission-Creation-Tools.svg
[VEAF-logo]: https://veaf.github.io/documentation/images/logo.png
[VEAF Discord]: https://www.veaf.org/discord
[Zip on Github]: https://github.com/davidp57
[Zip on coff.ee]: https://coff.ee/veaf_zip
[VEAF website]: https://www.veaf.org
[VEAF forum]: https://www.veaf.org/forum
[GitHub]: https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues
[DCS]: https://www.digitalcombatsimulator.com/

[documentation-old]: ./old_documentation/_index.md
[documentation-site]: https://veaf.github.io/documentation/
[documentation-repo]: https://github.com/VEAF/documentation
