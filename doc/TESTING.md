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

The project has 31 Lua test suites covering all runtime modules, totalling ~915 tests. Tests run with plain **Lua 5.1** using the [luaunit](https://github.com/bluebird75/luaunit) framework. No DCS installation is required — the DCS API is stubbed out by `dcs_mocks.lua`.

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
- Lua 5.1 on PATH (`lua5.1` on Linux/DevContainer, `lua` or `C:\Program Files (x86)\Lua\5.1\lua.exe` on Windows)
- No other dependencies (luaunit is bundled in `test/lua/luaunit.lua`)

---

## Coverage

Generate a per-file line coverage report using [luacov](https://github.com/lunarmodules/luacov):

```shell
poetry run test-lua --coverage
# or short form:
poetry run test-lua -c
```

After the test run a rich table is printed showing hits, missed lines, and coverage percentage per module. The report file is also written to `luacov.report.out` in the repository root for manual inspection.

### Requirements

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
└── test_*.lua          # One file per module (31 files)
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

| Suite | Tests | What it covers |
|-------|-------|----------------|
| `test_veaf.lua` | 93 | Core utilities, string/table/vector helpers, logging |
| `test_veafCacheManager.lua` | 12 | Cache get/set/invalidate |
| `test_veafInterpreter.lua` | 9 | Mark text tokenizer |
| `test_veafTime.lua` | 71 | Time parsing, formatting, DCS time helpers |
| `test_veafSecurity.lua` | 24 | Security levels, admin management |
| `test_veafNamedPoints.lua` | 25 | Point registration, lookup, ATC helpers |
| `test_veafShortcuts.lua` | 39 | Shortcut registration and resolution |
| `test_veafWeather.lua` | 65 | Weather parsing, QNH/wind calculations |
| `test_dcsDataExport.lua` | 29 | Unit data export utilities |
| `test_veafCombatMission.lua` | 59 | Base combat mission lifecycle |
| `test_veafAirbases.lua` | 13 | Airbase data lookup |
| `test_veafCombatZone.lua` | 51 | Zone activation, scoring, state machine |
| `test_veafUnits.lua` | 34 | Unit template lookup, category filtering |
| `test_veafAssets.lua` | 19 | Asset registration, state tracking |
| `test_veafRemote.lua` | 25 | Remote command parsing |
| `test_veafMarkers.lua` | 17 | Marker event handling |
| `test_veafEventHandler.lua` | 21 | Event dispatch, handler registration |
| `test_veafSkynetIadsHelper.lua` | 18 | Skynet IADS integration helpers |
| `test_veafSkynetIadsMonitor.lua` | 18 | Skynet monitor state |
| `test_veafGroundAI.lua` | 26 | Ground AI behavior flags |
| `test_veafRadio.lua` | 24 | Radio menu tree construction |
| `test_veafQraManager.lua` | 28 | QRA state machine, zone management |
| `test_veafAirWaves.lua` | 30 | Wave scheduling, group assignment |
| `test_veafSanctuary.lua` | 19 | Sanctuary zone detection |
| `test_veafMissileGuardian.lua` | 16 | Missile intercept logic |
| `test_veafCasMission.lua` | 14 | CAS threat package generation |
| `test_veafTransportMission.lua` | 14 | Transport mission setup |
| `test_veafCarrierOperations.lua` | 16 | Carrier recovery sequence |
| `test_veafMove.lua` | 19 | Move/teleport command parsing |
| `test_veafGrass.lua` | 12 | Grass runway initialization |
| `test_veafSpawn.lua` | 55 | Spawn commands, mark text analysis, laser freq conversion |

**Modules not covered** (design-time or external-only):

| Module | Reason |
|--------|--------|
| `veafMissionEditor.lua` | Operates on `.miz` ZIP files; tested via Python integration tests |
| `veafMissionFlightPlanEditor.lua` | idem |
| `veafMissionNormalizer.lua` | idem |
| `veafMissionRadioPresetsEditor.lua` | idem |
| `veafMissionTriggerInjector.lua` | idem |
| `veafSpawnableAircraftsEditor.lua` | idem |
| `dcsUnits.lua` | Pure data file; exercised indirectly through `test_veafUnits.lua` |
| `veaf-scripts-trace.lua` | Config/include wrapper with no testable logic |

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

function TestVeafMyModuleConstants:test_Version()
  luaunit.assertNotNil(veafMyModule.Version)
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

**`stylua-check`** — Ubuntu latest
1. Checkout repository
2. Run `JohnnyMorganz/stylua-action@v4` with version `2.4.0`
3. Check `src/scripts/veaf/` against `.stylua.toml`
4. Fail if any file is not formatted

### Running StyLua Locally

```powershell
# Check only (no writes)
stylua --check src/scripts/veaf/

# Auto-format
stylua src/scripts/veaf/
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
