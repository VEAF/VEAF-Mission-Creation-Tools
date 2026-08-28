# Testing Guide

Documentation for the VEAF Lua unit test suite and CI/CD pipeline.

## Table of Contents

- [Overview](#overview)
- [Running Tests](#running-tests)
- [Coverage](#coverage)
- [Infrastructure](#infrastructure)
- [Test Suite](#test-suite)
- [Writing Tests](#writing-tests)
- [CI/CD Pipeline](#cicd-pipeline)

---

## Overview

The project covers the runtime modules with one Lua test suite per module — the "Test Suite" section lists them all, and ends with what is deliberately left uncovered. Tests run with plain **Lua 5.1** using the [luaunit](https://github.com/bluebird75/luaunit) framework. No DCS installation is required — the DCS API is stubbed out by `dcs_mocks.lua`.

---

## Running Tests

### All Tests

```shell
poetry run test-lua
```

Exit code `0` if all suites pass, `1` if any fail.

### Filtered Run

```shell
poetry run test-lua --filter spawn
poetry run test-lua --filter combat
```

### Single File

```shell
lua test/lua/test_veafSpawn.lua
```

### Requirements

- `poetry install` must have been run once
- Lua 5.1 on PATH (`lua5.1`, `lua51` or `lua`, or `C:\Program Files (x86)\Lua\5.1\lua.exe` on Windows)
- No other dependencies (luaunit is bundled in `test/lua/luaunit.lua`)

Version **5.1** is verified: every candidate is queried with `lua -v`, and a 5.2+ interpreter is
refused rather than used. That is deliberate — Lua 5.2 removed `unpack` and made
`string.format('%d', ...)` reject a fractional number, so a run under 5.4 produces dozens of
failures that look like regressions and are not.

On Windows, `scoop install lua51` provides Lua 5.1.5. Note that its `lua` shim replaces the one
of any other Lua already installed through scoop; the `lua51` shim lets you keep both.

---

## Coverage {#coverage}

Generate a per-file line coverage report using [luacov](https://github.com/lunarmodules/luacov):

```shell
poetry run test-lua --coverage
# or short form:
poetry run test-lua -c
```

After the test run a rich table is printed showing hits, missed lines, and coverage percentage per module. The report file is also written to `luacov.report.out` in the repository root for manual inspection.

### Requirements (coverage)

luacov must be installed via luarocks:

```shell
# Linux / DevContainer (luarocks is pre-installed)
luarocks install luacov

# Windows (may need an elevated shell)
luarocks install luacov
```

In the DevContainer, luacov is installed automatically — no extra steps needed.

### Configuration

Coverage is collected only for modules under `src/scripts/veaf/` (test helpers and luaunit are excluded). The `.luacov` file at the repository root controls this.

---

## Infrastructure

### File Layout

```
test/lua/
├── luaunit.lua         # Test framework (bundled)
├── dcs_mocks.lua       # DCS API stubs
├── veaf_loader.lua     # Module loader for src/scripts/veaf/
└── test_*.lua          # One file per module
```

### dcs_mocks.lua

Provides minimal stubs for the DCS global API so modules can be `require`d without a running DCS instance. Stubbed namespaces include:

- `env`, `timer`, `world`
- `Unit`, `Group`, `StaticObject`, `Airbase`
- `coalition`, `country`, `radio`
- `trigger` (including `trigger.smokeColor`, `trigger.action.*`)
- `mist` (basic utilities used by several modules)
- Math helpers (`math.isnan`, `math.inf`)

If a new module fails to load because a DCS API call is missing, add the stub to `dcs_mocks.lua`.

### veaf_loader.lua

Patches `package.path` so that `require("veaf")`, `require("veafSpawn")`, etc. resolve to `src/scripts/veaf/`. Each test file starts with:

```lua
dofile("test/lua/dcs_mocks.lua")
dofile("test/lua/veaf_loader.lua")
local luaunit = require("luaunit")
-- load the module under test:
require("veafSpawn")
```

### luaunit

Standard luaunit API applies. Notable: `assertNoError` does not exist in this version; use `pcall` instead:

```lua
local ok, err = pcall(function() veafSpawn.someFunction() end)
luaunit.assertIsTrue(ok, err)
```

---

## Test Suite

| Suite | What it covers |
|-------|----------------|
| `test_veaf.lua` | Core utilities, string/table/vector helpers, logging |
| `test_veafCacheManager.lua` | Cache get/set/invalidate |
| `test_veafScheduler.lua` | Native-timer scheduler: repetition, stop time, a failing task |
| `test_veafMath.lua` | Unit conversions, vectors, coordinate shapes, deep copy |
| `test_veafGeo.lua` | Coordinate text output, zones, average positions, polygons |
| `test_veafMissionDb.lua` | Mission snapshot, player roster, name registry, unit ids |
| `test_veafInterpreter.lua` | Mark text tokenizer |
| `test_veafTime.lua` | Time parsing, formatting, DCS time helpers |
| `test_veafSecurity.lua` | Security levels, admin management |
| `test_veafServerHook.lua` | Server hook: chat-command parsing and dispatch |
| `test_veafNamedPoints.lua` | Point registration, lookup, ATC helpers |
| `test_veafShortcuts.lua` | Shortcut registration and resolution |
| `test_veafWeather.lua` | Weather parsing, QNH/wind calculations |
| `test_dcsDataExport.lua` | Unit data export utilities |
| `test_veafCombatMission.lua` | Base combat mission lifecycle |
| `test_veafAirbases.lua` | Airbase data lookup |
| `test_veafCombatZone.lua` | Zone activation, scoring, state machine |
| `test_veafUnits.lua` | Unit template lookup, category filtering |
| `test_veafAssets.lua` | Asset registration, state tracking |
| `test_veafAssist.lua` | Pilot assistance: checklists, progression, menus |
| `test_veafRemote.lua` | Remote command parsing |
| `test_veafMarkers.lua` | Marker event handling |
| `test_veafEventHandler.lua` | Event dispatch, handler registration |
| `test_veafSkynetIadsHelper.lua` | Skynet IADS integration helpers |
| `test_veafSkynetIadsMonitor.lua` | Skynet monitor state |
| `test_veafGroundAI.lua` | Ground AI behavior flags |
| `test_veafRadio.lua` | Radio menu tree construction |
| `test_veafQraManager.lua` | QRA state machine, zone management |
| `test_veafAirWaves.lua` | Wave scheduling, group assignment |
| `test_veafSanctuary.lua` | Sanctuary zone detection |
| `test_veafMissileGuardian.lua` | Missile intercept logic |
| `test_veafCasMission.lua` | CAS threat package generation |
| `test_veafTransportMission.lua` | Transport mission setup |
| `test_veafCarrierOperations.lua` | Carrier recovery sequence |
| `test_veafMove.lua` | Move/teleport command parsing |
| `test_veafMove_escort.lua` | Escort-task recovery after the escorted group is recreated |
| `test_veafGrass.lua` | Grass runway initialization |
| `test_veafSpawn.lua` | Spawn commands, mark text analysis, laser freq conversion |
| `test_veafSpawnParser.lua` | Deterministic spawn mark-text parsing (`markTextAnalysis`) |
| `test_veafCommands.lua` | Command registry: priority ordering and dispatch |
| `test_veafI18n.lua` | Lua runtime i18n layer (`veaf.t`, `veafI18n` catalog) |

**Module not covered**:

| Module | Reason |
|--------|--------|
| `dcsUnits.lua` | Pure data file; exercised indirectly through `test_veafUnits.lua` |

---

## Writing Tests

### Minimal Template

```lua
-- test_veafMyModule.lua
package.path = package.path .. ";test/lua/?.lua;src/scripts/veaf/?.lua"
dofile("test/lua/dcs_mocks.lua")
dofile("test/lua/veaf_loader.lua")
local luaunit = require("luaunit")
require("veafMyModule")

TestVeafMyModuleConstants = {}

function TestVeafMyModuleConstants:test_Id()
  luaunit.assertEquals(veafMyModule.Id, "MYMODULE")
end

TestVeafMyModuleLogic = {}

function TestVeafMyModuleLogic:test_someFunction()
  local result = veafMyModule.someFunction("input")
  luaunit.assertEquals(result, "expected")
end

-- Entry point
os.exit(luaunit.LuaUnit.run())
```

### Conventions

- One file per module: `test_veaf<ModuleName>.lua`
- Group tests into classes: `TestVeaf<ModuleName>Constants`, `TestVeaf<ModuleName>Logic`, etc.
- Always end with `os.exit(luaunit.LuaUnit.run())`
- Use `pcall` instead of `assertNoError` (not available in this luaunit version)
- Don't test internal/private functions — only what the Lua module exports on its global table

### Adding DCS API Stubs

If your test fails with a "nil value" or "attempt to call a nil value" on a DCS function, add the stub to `dcs_mocks.lua`:

```lua
-- In dcs_mocks.lua:
trigger.action.myNewFunction = function(...) end
trigger.myNewConstant = 42
```

---

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/lua-ci.yml`) runs on every push and pull request:

### Jobs

**`lua-unit-tests`** — Ubuntu latest
1. Checkout repository
2. Install `lua5.1` via apt
3. Run all `test/lua/test_*.lua` files
4. Fail the job if any suite exits non-zero

**`luacheck`** — Ubuntu latest
1. Checkout repository
2. Install `lua5.1` + `luacheck` via LuaRocks
3. Run static analysis on `src/scripts/veaf/` with `luacheck --config .luacheckrc` (undefined globals, unused variables, shadowing)
4. Fail if any violation is found

**`stylua-check`** — Ubuntu latest
1. Checkout repository
2. Run `JohnnyMorganz/stylua-action@v5` with version `2.4.0`
3. Check `src/scripts/veaf/` **and** `test/lua/` against `.stylua.toml`
4. Fail if any file is not formatted

**`lua-coverage`** — Ubuntu latest
1. Checkout repository
2. Install `lua5.1` + `luacov` via LuaRocks, then Poetry and dependencies
3. Run `poetry run test-lua --cov-fail-under 72` (luacov line coverage)
4. Fail if coverage drops below the ratchet floor (the number only ever goes up)

### Running StyLua Locally

```powershell
# Check only (no writes)
stylua --check src/scripts/veaf/ test/lua/

# Auto-format
stylua src/scripts/veaf/ test/lua/
```

### Running Luacheck Locally

```powershell
luacheck --config .luacheckrc src/scripts/veaf/
```

StyLua configuration (`.stylua.toml`):

```toml
column_width = 140
line_endings = "Windows"
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
collapse_simple_statement = "Never"
```
