# [![VEAF-logo]][VEAF website] Mission Creation Tools

> 🇫🇷 [Lire ce document en français](#fr)

[![Badge-Discord]][VEAF Discord]
![Badge-Wakatime]

Complete toolkit for creating dynamic [DCS World][DCS] missions using VEAF Lua scripts and automation tools.

**License:** [MIT](LICENSE.md) | **Version:** see [CHANGELOG.md](CHANGELOG.md)

---

## Documentation

Choose the guide that matches your role:

| Role | Guide | Description |
|------|-------|-------------|
| **Player / Pilot** | [Pilot Guide](doc/pilot/README.md) | F10 menus, marker commands, assets, combat zones |
| **Mission Maker** | [Mission Maker Guide](doc/mission-maker/README.md) | Install, configure, build — all scripts documented |
| **Developer** | [Developer Guide](doc/developer/README.md) | Architecture, build pipeline, quality gates, contributing |

### Detailed References

| Reference | Description |
|-----------|-------------|
| [User Guide](doc/USER_GUIDE.md) | Extended pilot reference |
| [Lua API Reference](doc/LUA_API_REFERENCE.md) | Full API for all 34 Lua runtime modules |
| [Tools CLI Reference](doc/TOOLS_REFERENCE.md) | `veaf-tools.exe` and `veaf-tools-updater.exe` |
| [Testing Guide](doc/TESTING.md) | Lua unit test suite, CI/CD pipeline |
| [Roadmap](doc/ROADMAP.md) | Planned features and known limitations |

---

## Quick Start

### Players and Pilots

You're in a mission that uses VEAF scripts. Open the F10 map, place a marker, and type a command (e.g. `_spawn unit T-80` or `_cas`). See the [Pilot Guide](doc/pilot/README.md) for all available commands.

### Mission Makers

```powershell
# 1. Download the updater from the GitHub release page, then:
.\veaf-tools-updater.exe

# 2. Add veaf-scripts.lua to your DCS mission triggers (DO SCRIPT FILE)

# 3. Configure modules in missionconfig.lua
```

Full workflow: [Mission Maker Guide](doc/mission-maker/README.md)

### Developers

```powershell
# Setup
poetry install --with build

# Build
poetry run veaf-build build --version 6.0.5

# Test
.\test\lua\run_tests.ps1

# Publish
poetry run veaf-build publish --version 6.0.5
```

Full reference: [Developer Guide](doc/developer/README.md)

---

## About

VEAF Mission Creation Tools is a hybrid **Lua + Python** system:

- **Runtime** (`src/scripts/veaf/`) — 34 Lua modules loaded inside DCS missions, providing spawning, asset management, mission types, radio menus, and more
- **Design-time** (`src/python/veaf-tools/`) — Python CLI (`veaf-tools.exe`) for manipulating `.miz` files: normalizing, injecting weather/waypoints/radio presets/aircraft groups
- **Release pipeline** (`veaf-build` CLI) — compiles Lua, builds EXE files, publishes to GitHub

---

## Community & Support

- [VEAF Discord][VEAF Discord] — real-time help
- [VEAF Website][VEAF website]
- [GitHub Issues][GitHub] — bug reports
- [Support the project][Zip on coff.ee]

---

# [![VEAF-logo]][VEAF website] Outils de création de missions

> 🇫🇷 **Français** | 🇬🇧 [English](#-mission-creation-tools)

Ensemble complet d'outils pour créer des missions [DCS World][DCS] dynamiques avec les scripts Lua VEAF.

---

## Documentation

| Rôle | Guide |
|------|-------|
| **Joueur / Pilote** | [Guide du pilote](doc/pilot/README.md) |
| **Créateur de missions** | [Guide créateur de missions](doc/mission-maker/README.md) |
| **Développeur** | [Guide du développeur](doc/developer/README.md) |

Références : [Référence API Lua](doc/LUA_API_REFERENCE.md) · [Référence CLI](doc/TOOLS_REFERENCE.md) · [Feuille de route](doc/ROADMAP.md)

---

## Démarrage rapide

**Joueurs et pilotes** — Ouvrez la carte F10, placez un marqueur, tapez une commande (ex : `_spawn unit T-80`). Voir le [Guide du pilote](doc/pilot/fr/GUIDE.md).

**Créateurs de missions** :

```powershell
.\veaf-tools-updater.exe          # installe les outils et scripts VEAF
.\veaf-tools.exe build mission .  # construit le .miz
```

Guide complet : [Guide créateur de missions](doc/mission-maker/fr/GUIDE.md)

**Développeurs** :

```powershell
poetry install --with build
poetry run veaf-build build --version 6.0.5
```

Référence complète : [Guide du développeur](doc/developer/fr/GUIDE.md)

---

## Communauté & Support

- [VEAF Discord][VEAF Discord] — aide en temps réel
- [Site VEAF][VEAF website]
- [Issues GitHub][GitHub] — signalement de bugs
- [Soutenir le projet][Zip on coff.ee]

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
