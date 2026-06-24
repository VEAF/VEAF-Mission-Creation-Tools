# Lot 4 — LUA-CONFIG: Lua configuration system

Status: ✅ done

**Goal**: Each Lua module can be configured and disabled via `missionconfig.lua` without touching module source code. Fully backward compatible.
**Branch**: `feature/lua-config-system` → PR → `develop-v6`
**Depends on**: Lot 1 (quality gate for TOOL-003/LUA-005)

| # | Ticket | Type | Effort | Depends on | Status |
|---|--------|------|--------|------------|--------|
| LUA-001 | `veaf.config` per module + `enable=true` option in `veaf.lua` | feat | 90 min | — | [x] |
| LUA-002 | Load and apply `missionconfig.lua` | feat | 60 min | LUA-001 | [x] |
| LUA-003 | Deferred module initialization after missionconfig load | feat | 60 min | LUA-002 | [x] |
| LUA-004 | `veaf-tools generate-config` command → `missionconfig.lua` template | feat | 45 min | LUA-001, TOOL-003 | [x] |
| LUA-005 | Module selection + options via mission YAML (`veaf-tools build`) | feat | 60 min | LUA-004 | [x] |

**Raw total: 315 min → estimated (×1.15): ~360 min (~6h)**
⚠️ Highest-risk lot — impacts Lua runtime of all existing missions. Require Lua test coverage before merge.

<details>
<summary>Ticket details</summary>

**LUA-001 — veaf.config**
In `veaf.lua`: `veaf.config = {}`. Each module registers its default config on load:
```lua
-- In veafSpawn.lua
veaf.config["veafSpawn"] = {
  enable = true,
  logLevel = "info",
  -- module-specific options
}
```
Public API: `veaf.getConfig(moduleId)`, `veaf.setConfig(moduleId, key, value)`, `veaf.isEnabled(moduleId)`.

**LUA-002 — missionconfig.lua**
After all modules are loaded via `require`, `veaf.lua` attempts `dofile("missionconfig.lua")`. That file contains `veaf.setConfig(...)` calls that override defaults. If the file does not exist: unchanged behavior (full backward compatibility).

**LUA-003 — Deferred init**
Refactor the startup sequence: `require` (load modules) → `dofile missionconfig` (override config) → `veaf.initialize()` (triggers init of all enabled modules). Each module exposes a distinct `init()` function separate from loading. Modules with `enable = false` do not initialize. Backward fallback: if `veaf.initialize()` is not called explicitly within a timeout, trigger automatically for legacy missions.

**LUA-004 — generate-config**
New command `veaf-tools generate-config --mission <folder>`: reads the embedded module list (from TOOL-003 data), generates a `missionconfig.lua` template with all options documented in comments and their default values. Output to the mission folder.

**LUA-005 — Mission YAML → modules**
In `mission.yaml` (mission configuration): `lua_modules` section listing modules to enable with their options. During `veaf-tools build`: this section is read and converted to a generated `missionconfig.lua`, injected into the `.miz`. Missions without this section keep current behavior (all modules active).

</details>
