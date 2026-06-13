# Roadmap — VEAF Mission Creation Tools

This document describes the intended direction for the project. Items are ordered by priority, not by date. No delivery dates are committed.

---

## Status Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Done — shipped in a release |
| 🔄 | In progress — on `develop-v6` |
| 🔵 | Planned — ticket exists in backlog |
| ⚪ | Idea — not yet ticketed |

---

## v6.x — Current development cycle (`develop-v6`)

### Foundation (Lot 1 — INFRA)
- ✅ **Poetry migration** — replace `requirements.txt` with `pyproject.toml` managed by Poetry
- ✅ **Python quality gate** — ruff (lint + format) + mypy (types) + pytest, enforced in CI
- ✅ **Python CI job** — `python-quality` GitHub Actions job alongside the existing Lua CI

### CLI improvements (Lot 2 — CLI)
- 🔵 **Version check on startup** — compare installed version against latest GitHub release, prompt to update
- 🔵 **Centralized `~/.veaf/` directory** — all user data (installed scripts, preferences, logs) in one place
- 🔵 **Embedded module list** — `veaf-tools` exe embeds the list of Lua modules with version info; exposed via `about --modules`

### Interactive mode (Lot 3 — TUI)
- ✅ **InquirerPy interactive mode** — launching `veaf-tools` with no arguments opens a guided prompt instead of showing help
- ✅ **Preference persistence** — last-used parameters saved to `~/.veaf/preferences.json` and pre-filled on next run

### Lua configuration system (Lot 4 — LUA-CONFIG)
- ✅ **`veaf.config` per module** — each Lua module registers its default configuration; modules can be enabled/disabled
- ✅ **`veaf-config.lua`** — build-generated config file (from `mission.yaml`); replaces hand-written `veaf-modules-config.lua`
- ✅ **`mission-script.lua`** — mission-level file for custom Lua code; replaces `missionConfig.lua`
- ✅ **`generate-config` command** — generates a documented `mission.yaml` template for a given mission
- ✅ **Mission YAML → module selection** — `lua_modules` section in `mission.yaml` drives which modules are included and how they are initialized

### Release
- ✅ **v6.x releases** — published continuously from `develop-v6` (`published-vx.y.z` tags); current version **6.5.0**. The `develop-v6` → `master` merge is reserved for stable milestones.
- ✅ **v6.3.0 release** — bug fixes and UX improvements (Lot 26 + FIX-SORT): convert-v5 crash fix, auto-pause on double-click, smart defaults filtering, veaf.initialize() nil-check
- ✅ **v6.3.3 release** — stabilization and bug fixes: Lua initialize() crashes, build pipeline fixes, build profiles, CSAR YAML-first, auto dependency resolution

---

## Quality & Testing

- ✅ Lua unit tests (31 suites, ~915 tests) — `luaunit` + `dcs_mocks.lua` + `poetry run test-lua`
- ✅ StyLua formatting check in CI
- ✅ Luacheck static analysis in CI
- ✅ Lua CI on GitHub Actions (`lua-unit-tests` + `luacheck` + `stylua-check`)
- ✅ Python unit tests — pytest with coverage
- ✅ Python quality gate in CI

---

## Beyond v6 (ideas, not yet ticketed)

- ✅ **Logger filter** (`--log-modules`) — filter which Lua modules write to the DCS log, for cleaner debugging
- ✅ **DCSUnits doc** — auto-generate `doc/DCS_UNITS.md` from `dcsUnits.lua` before each publish
- ⚪ **Mission validation** — `veaf-tools validate` command that checks a mission against known VEAF requirements
- ⚪ **Multi-map support** — better handling of missions across different DCS maps (Caucasus, Syria, Persian Gulf, etc.)
- ⚪ **VS Code extension** — syntax highlighting and validation for VEAF YAML config files

---

## Maintained but stable (v5)

The `master` branch carries the last v5 release (**v5.103.3**). Only critical bug fixes will be applied to v5.
New features target v6 only.
