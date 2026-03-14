# [![VEAF-logo]][VEAF website] Mission Creation Tools

[![Badge-Discord]][VEAF Discord]
![Badge-Wakatime]

Complete toolkit for creating dynamic [DCS World][DCS] missions using VEAF Lua scripts and automation tools.

**License:** [MIT](LICENSE.md) | **Version:** see [RELEASE_NOTES.md](RELEASE_NOTES.md)

---

## Documentation

Choose the guide that matches your role:

| Role | Guide | Description |
|------|-------|-------------|
| **Player** | [User Guide](doc/USER_GUIDE.md) | F10 menus, marker commands, in-mission features |
| **Mission Maker** | [Mission Maker Guide](doc/MISSION_MAKER_GUIDE.md) | Set up a mission, configure modules, build & deploy |
| **Developer** | [Developer Guide](doc/DEVELOPER_GUIDE.md) | Architecture, build pipeline, Python tools, contributing |
| **Lua API** | [Lua API Reference](doc/LUA_API_REFERENCE.md) | Full API for all 32 Lua runtime modules |
| **Tools CLI** | [Tools Reference](doc/TOOLS_REFERENCE.md) | `veaf-tools.exe` and `veaf-tools-updater.exe` command reference |
| **Testing** | [Testing Guide](doc/TESTING.md) | Lua unit test suite, CI/CD pipeline |

---

## Quick Start

### Players

You're in a mission that uses VEAF scripts. Open the F10 map, place a marker, and type a command (e.g. `_spawn unit T-80` or `_cas`). See the [User Guide](doc/USER_GUIDE.md) for all available commands.

### Mission Makers

```powershell
# 1. Download the updater from the GitHub release page, then:
.\veaf-tools-updater.exe update

# 2. Add veaf-scripts.lua to your DCS mission triggers (DO SCRIPT FILE)

# 3. Configure modules in missionconfig.lua
```

Full workflow: [Mission Maker Guide](doc/MISSION_MAKER_GUIDE.md)

### Developers

```powershell
# Setup
python -m venv .venv ; . .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# Build
python build-and-release.py build --version 6.0.5

# Test
.\test\lua\run_tests.ps1

# Publish
python build-and-release.py publish --version 6.0.5
```

Full reference: [Developer Guide](doc/DEVELOPER_GUIDE.md)

---

## About

VEAF Mission Creation Tools is a hybrid **Lua + Python** system:

- **Runtime** (`src/scripts/veaf/`) — 32 Lua modules loaded inside DCS missions, providing spawning, asset management, mission types, radio menus, and more
- **Design-time** (`src/python/veaf-tools/`) — Python CLI (`veaf-tools.exe`) for manipulating `.miz` files: normalizing, injecting weather/waypoints/radio presets/aircraft groups
- **Release pipeline** (`build-and-release.py`) — compiles Lua, builds EXE files, publishes to GitHub

---

## Community & Support

- [VEAF Discord][VEAF Discord] — real-time help
- [VEAF Website][VEAF website]
- [GitHub Issues][GitHub] — bug reports
- [Support the project][Zip on coff.ee]

---

[Badge-Discord]: https://img.shields.io/discord/471061487662792715?label=VEAF%20Discord&style=for-the-badge
[Badge-Wakatime]: https://wakatime.com/badge/github/VEAF/VEAF-Mission-Creation-Tools.svg
[VEAF-logo]: https://veaf.github.io/documentation/images/logo.png
[VEAF Discord]: https://www.veaf.org/discord
[Zip on Github]: https://github.com/davidp57
[Zip on coff.ee]: https://coff.ee/veaf_zip
[VEAF website]: https://www.veaf.org
[GitHub]: https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues
[DCS]: https://www.digitalcombatsimulator.com/
