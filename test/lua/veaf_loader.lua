--- Test harness: loads VEAF modules in the correct sequential order,
--- exactly as DCS would, using the plain Lua 5.1 interpreter.
---
--- Usage:
---   local loader = require("veaf_loader")
---   loader.load("veaf")              -- load just veaf.lua (core)
---   loader.load("veafCacheManager")  -- load a specific module (implies veaf)
---   loader.loadAll()                 -- load every VEAF module

local M = {}

-- Resolve the absolute path to src/scripts/veaf/ relative to this file's location.
-- __SCRIPTPATH__ is set by the run_tests script before loading this harness.
local _scriptDir = _VEAF_SCRIPT_DIR or (debug and debug.getinfo(1, "S").source:match("^@(.+[\\/])") or "./")
local _veafDir = _scriptDir .. "../../src/scripts/veaf/"

--- Cache of already-loaded modules (avoids double-loading).
local _loaded = {}

--- Ordered list of all VEAF modules (matches VeafDynamicLoader.lua order).
local _moduleOrder = {
  "veaf",
  "veafScheduler",
  "veafMath",
  "veafGeo",
  "veafTime",
  "veafAirbases",
  "veafWeather",
  "veafAssets",
  "veafCarrierOperations",
  "veafCasMission",
  "veafCombatMission",
  "veafCombatZone",
  "veafGrass",
  "veafInterpreter",
  "veafMarkers",
  "veafMove",
  "veafNamedPoints",
  "veafRadio",
  "veafSecurity",
  "veafShortcuts",
  "veafSpawn",
  "veafTransportMission",
  "dcsUnits",
  "veafUnits",
  "veafRemote",
  "veafSkynetIadsHelper",
  "veafSkynetIadsMonitor",
  "veafSanctuary",
  "veafQraManager",
  "veafAirWaves",
  "veafAssist",
  "veafEventHandler",
  "veafCacheManager",
  "veafGroundAI",
  "veafMissileGuardian",
  "veafMissionFlightPlanEditor",
}

--- Load a single VEAF module by name (without .lua extension).
--- If "veaf" is not yet loaded and the requested module is not "veaf",
--- "veaf" is loaded first automatically.
function M.load(name)
  if _loaded[name] then
    return
  end
  -- Ensure the core framework is always loaded first.
  if name ~= "veaf" and not _loaded["veaf"] then
    M.load("veaf")
  end
  local path = _veafDir .. name .. ".lua"
  local fn, err = loadfile(path)
  if not fn then
    error("veaf_loader: cannot load '" .. name .. "' from " .. path .. "\n" .. tostring(err))
  end
  fn()
  _loaded[name] = true
  -- veafScheduler, veafMath and veafGeo back veaf.* functions that veaf.lua itself calls: they are
  -- part of the framework floor, not optional modules, so loading the core pulls them in.
  if name == "veaf" then
    for _, floor in ipairs({ "veafScheduler", "veafMath", "veafGeo" }) do
      if not _loaded[floor] then
        M.load(floor)
      end
    end
  end
end

--- Load every module in the canonical order.
function M.loadAll()
  for _, name in ipairs(_moduleOrder) do
    M.load(name)
  end
end

--- Reset loaded state (call between isolated test suites if needed).
function M.reset()
  _loaded = {}
end

return M
