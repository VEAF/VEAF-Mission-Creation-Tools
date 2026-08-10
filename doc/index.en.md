# VEAF Mission Creation Tools — Documentation

VEAF MCT turns a standard DCS mission into a dynamic, player-driven sandbox — 30+ Lua modules, a build pipeline, and a CLI tool that does the heavy lifting.

Complete toolkit for creating dynamic [DCS World](https://www.digitalcombatsimulator.com/) missions using VEAF Lua scripts and automation tools.

---

## Choose Your Guide

| Role | Start Here | What You'll Find |
|------|------------|-----------------|
| **Player / Pilot** | [Pilot Guide](pilot/README.en.md) | F10 menus, marker commands, available assets and combat zones |
| **Mission Maker** | [Mission Maker Guide](mission-maker/README.en.md) | Install, configure modules, build and deploy missions |
| **Developer** | [Developer Guide](developer/README.en.md) | Architecture, build pipeline, quality gates, contributing |

---

## How It Works

```mermaid
flowchart TD
    A["Base .miz\n(DCS Editor)"] -->|veaf-tools mission extract| B["Mission folder\n(src/ + mission.yaml)"]
    B --- C["published/\n(VEAF scripts)"]
    B -->|veaf-tools mission build| D[".miz ready to fly"]
    D -->|DCS loads| E["30+ Lua modules active"]
    E -->|Players use| F["F10 markers · Radio menus"]
```

1. **Extract** — Create a base mission in DCS Editor and extract it into version-controllable source files
2. **Configure** — `mission.yaml` declares active modules; `published/` provides the VEAF Lua scripts
3. **Build** — `veaf-tools mission build` assembles everything into a final `.miz`
4. **Runtime** — DCS loads the `.miz`; players interact via F10 markers and radio menus

---

## References

| Reference | Description |
|-----------|-------------|
| [Lua API Reference](LUA_API_REFERENCE.en.md) | Full API for the Lua runtime modules |
| [Tools CLI Reference](TOOLS_REFERENCE.en.md) | `veaf-tools.exe` — all commands and options |
| [Testing Guide](TESTING.en.md) | Lua unit test suite and CI/CD pipeline |
| [Roadmap](ROADMAP.en.md) | Planned features and known limitations |

---

## Quick Start

### Players and Pilots

You are in a mission that uses VEAF scripts. Open the F10 map, place a marker, and type a command — for example `_spawn unit T-80` or `_cas`. See the [Pilot Guide](pilot/README.en.md) for all available commands.

### Mission Makers

```powershell
# 1. Download veaf-tools-updater.exe from the GitHub release page and run it:
.\veaf-tools-updater.exe
# → installs veaf-tools.exe and all VEAF scripts in the current folder
```

Then, depending on your starting point:

**You already have a VEAF mission folder** (or forked the [Demo Mission](https://github.com/VEAF/VEAF-Demo-Mission)):
```powershell
veaf-tools.exe mission build
```

**You only have a `.miz` file:**
```powershell
veaf-tools.exe mission extract my-mission.miz
# → edit mission.yaml to enable the modules you want
veaf-tools.exe mission build
```

Full workflow: [Mission Maker Guide](mission-maker/README.en.md)

### Developers

```powershell
poetry install --with build
poetry run veaf-build build --version 6.0.5
poetry run test-lua
poetry run veaf-build publish --version 6.0.5
```

Full reference: [Developer Guide](developer/README.en.md)

---

## Community & Support

- [VEAF Discord](https://www.veaf.org/discord) — real-time help
- [GitHub Issues](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues) — bug reports and feature requests
- [VEAF Website](https://www.veaf.org)
