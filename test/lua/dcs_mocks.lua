--- DCS World API mocks for unit testing outside DCS.
--- Provides lightweight stubs for all DCS globals so that VEAF modules can be
--- loaded and exercised in a plain Lua 5.1 interpreter.

-- ---------------------------------------------------------------------------
-- Controllable time (override in tests: dcs_mocks.currentTime = X)
-- ---------------------------------------------------------------------------
dcs_mocks = {}
dcs_mocks.currentTime = 0
dcs_mocks.logs = {} -- captured log lines

local function _log(level, text)
  table.insert(dcs_mocks.logs, { level = level, text = tostring(text) })
end

-- ---------------------------------------------------------------------------
-- env
-- ---------------------------------------------------------------------------
env = {
  setErrorMessageBoxEnabled = function(_) end,
  error = function(text)
    _log("E", text)
  end,
  warning = function(text)
    _log("W", text)
  end,
  info = function(text)
    _log("I", text)
  end,
  mission = {
    theatre = "Caucasus",
    date = { Day = 1, Month = 1, Year = 2024 },
    triggers = { zones = {} },
    coalition = {
      blue = { country = {} },
      red = { country = {} },
    },
  },
}

-- ---------------------------------------------------------------------------
-- timer
-- ---------------------------------------------------------------------------
timer = {
  getTime = function()
    return dcs_mocks.currentTime
  end,
  getAbsTime = function()
    return dcs_mocks.currentTime
  end,
  scheduleFunction = function(fn, args, t) end,
  --- Test-only: move mission time forward. Not a DCS API — DCS has no setter — but anything
  --- with an expiry (a timed security elevation, a cooldown) needs a way to reach the far side
  --- of it without the suite actually waiting.
  setTime = function(t)
    dcs_mocks.currentTime = t
  end,
}

-- ---------------------------------------------------------------------------
-- trigger
-- ---------------------------------------------------------------------------

--- Pilot-facing messages sent through trigger.action.outText*, in order:
--- { fn = "outTextForUnit", target = <id or nil>, text = "…", duration = <seconds> }.
--- Cleared by dcs_mocks.reset().
dcs_mocks.messages = {}

--- Record one message. Called by the outText* stubs.
function dcs_mocks.recordMessage(fn, target, text, duration)
  table.insert(dcs_mocks.messages, { fn = fn, target = target, text = text, duration = duration })
end

--- Return the recorded messages whose text contains `needle` (a plain substring).
function dcs_mocks.messagesContaining(needle)
  local found = {}
  for _, message in ipairs(dcs_mocks.messages) do
    if type(message.text) == "string" and message.text:find(needle, 1, true) then
      table.insert(found, message)
    end
  end
  return found
end

trigger = {
  action = {
    -- Recorded, not discarded: a module's pilot-facing messages are behaviour, and a
    -- test asserting on them against a no-op stub passes without checking anything.
    outText = function(text, duration)
      dcs_mocks.recordMessage("outText", nil, text, duration)
    end,
    outTextForGroup = function(groupId, text, duration)
      dcs_mocks.recordMessage("outTextForGroup", groupId, text, duration)
    end,
    outTextForUnit = function(unitId, text, duration)
      dcs_mocks.recordMessage("outTextForUnit", unitId, text, duration)
    end,
    outTextForCoalition = function(side, text, duration)
      dcs_mocks.recordMessage("outTextForCoalition", side, text, duration)
    end,
    markToAll = function(...) end,
    markToCoalition = function(...) end,
    removeMark = function(id) end,
    arrowToAll = function(...) end,
    lineToAll = function(...) end,
    circleToAll = function(...) end,
    rectToAll = function(...) end,
    quadToAll = function(...) end,
    textToAll = function(...) end,
    radioTransmission = function(...) end,
    setMarkupColor = function(...) end,
    setUserFlag = function(flag, val) end,
    smoke = function(...) end,
    signalFlare = function(...) end,
    illuminationBomb = function(...) end,
    explosion = function(...) end,
  },
  misc = {
    getUserFlag = function(flag)
      return 0
    end,
    getZone = function(name)
      return nil
    end,
  },
  smokeColor = {
    Green = 0,
    Red = 1,
    White = 2,
    Orange = 3,
    Blue = 4,
  },
}

-- ---------------------------------------------------------------------------
-- world  (event constants taken from DCS scripting API)
-- ---------------------------------------------------------------------------
world = {
  event = {
    S_EVENT_INVALID = 0,
    S_EVENT_SHOT = 1,
    S_EVENT_HIT = 2,
    S_EVENT_TAKEOFF = 3,
    S_EVENT_LAND = 4,
    S_EVENT_CRASH = 5,
    S_EVENT_EJECTION = 6,
    S_EVENT_REFUELING = 7,
    S_EVENT_DEAD = 8,
    S_EVENT_PILOT_DEAD = 9,
    S_EVENT_BASE_CAPTURED = 10,
    S_EVENT_MISSION_START = 11,
    S_EVENT_MISSION_END = 12,
    S_EVENT_TOOK_CONTROL = 13,
    S_EVENT_REFUELING_STOP = 14,
    S_EVENT_BIRTH = 15,
    S_EVENT_HUMAN_FAILURE = 16,
    S_EVENT_ENGINE_STARTUP = 17,
    S_EVENT_ENGINE_SHUTDOWN = 18,
    S_EVENT_PLAYER_ENTER_UNIT = 20,
    S_EVENT_PLAYER_LEAVE_UNIT = 21,
    S_EVENT_SHOOTING_START = 22,
    S_EVENT_SHOOTING_END = 23,
    S_EVENT_MARK_ADDED = 25,
    S_EVENT_MARK_CHANGE = 26,
    S_EVENT_MARK_REMOVED = 27,
    S_EVENT_PLAYER_COMMENT = 28,
    S_EVENT_UNIT_LOST = 29,
    S_EVENT_LANDING_AFTER_EJECTION = 30,
    S_EVENT_MAX = 31,
  },
  addEventHandler = function(handler) end,
  removeEventHandler = function(handler) end,
  getAirbases = function(coalition_id)
    return {}
  end,
  searchObjects = function(category, volume, fn) end,
  getMarkPanels = function()
    return {}
  end,
  removeJunk = function(searchVolume)
    return 0
  end,
  weather = {
    getFogThickness = function()
      return 0
    end,
    getFogVisibilityDistance = function()
      return 0
    end,
    setFogAnimation = function(fogAnimationKeys) end,
    setFogThickness = function(thickness) end,
    setFogVisibilityDistance = function(visibility) end,
  },
}

-- ---------------------------------------------------------------------------
-- coalition
-- ---------------------------------------------------------------------------
coalition = {
  side = { NEUTRAL = 0, RED = 1, BLUE = 2 },
  getGroups = function(side, category)
    return {}
  end,
  getStaticObjects = function(side)
    return {}
  end,
  getAirbases = function(side)
    return {}
  end,
  addGroup = function(...) end,
  getCountryCoalition = function(countryId)
    -- Russia (0) → RED, USA (2) → BLUE
    if countryId == 0 then
      return 1
    end -- coalition.side.RED
    if countryId == 2 then
      return 2
    end -- coalition.side.BLUE
    return 0 -- NEUTRAL
  end,
}

-- ---------------------------------------------------------------------------
-- country
-- ---------------------------------------------------------------------------
country = {
  name = { [0] = "RUSSIA", [2] = "USA" },
  id = { RUSSIA = 0, USA = 2 },
}

-- ---------------------------------------------------------------------------
-- Unit / Group / StaticObject / Object
-- ---------------------------------------------------------------------------
Unit = {
  getByName = function(name)
    return nil
  end,
  Category = { AIRPLANE = 0, HELICOPTER = 1, GROUND_UNIT = 2, SHIP = 3, STRUCTURE = 4 },
}
Group = {
  getByName = function(name)
    return nil
  end,
  Category = { GROUND = 0, AIRPLANE = 1, HELICOPTER = 2, SHIP = 3, TRAIN = 4 },
}
StaticObject = {
  getByName = function(name)
    return nil
  end,
}
Object = {
  Category = { UNIT = 1, WEAPON = 2, STATIC = 3, BASE = 4, SCENERY = 5, CARGO = 6 },
}
Airbase = {
  getByName = function(name)
    return nil
  end,
  Category = { AIRDROME = 0, HELIPAD = 1, SHIP = 2 },
}

-- ---------------------------------------------------------------------------
-- land / coord / atmosphere
-- ---------------------------------------------------------------------------
land = {
  getHeight = function(vec2)
    return 0
  end,
  getSurfaceType = function(vec2)
    return 1
  end,
  -- DCS returns the closest road point as two numbers (x, z); echo the query point.
  getClosestPointOnRoads = function(roadType, x, z)
    return x, z
  end,
  SurfaceType = { LAND = 1, SHALLOW_WATER = 2, WATER = 3, ROAD = 4, RUNWAY = 5 },
}
coord = {
  LLtoLO = function(lat, lon, alt)
    return { x = 0, y = 0, z = 0 }
  end,
  LOtoLL = function(vec3)
    return 0, 0, 0
  end,
  LOtoMGRS = function(vec3)
    return { UTMZone = "", Easting = 0, Northing = 0 }
  end,
  MGRStoLL = function(mgrs)
    return 0, 0
  end,
  LLtoMGRS = function(lat, lon)
    return { MGRSDigraph = "XX", Easting = 100000, Northing = 200000 }
  end,
}
atmosphere = {
  getWind = function(point)
    return { x = 0, y = 0, z = 0 }
  end,
  getWindWithTurbulence = function(point)
    return { x = 0, y = 0, z = 0 }
  end,
  getTemperatureAndPressure = function(point)
    return 293.15, 101325
  end,
}

-- ---------------------------------------------------------------------------
-- missionCommands
-- ---------------------------------------------------------------------------
missionCommands = {
  addCommand = function(...)
    return {}
  end,
  addCommandForCoalition = function(...)
    return {}
  end,
  addCommandForGroup = function(...)
    return {}
  end,
  addSubMenu = function(...)
    return {}
  end,
  addSubMenuForCoalition = function(...)
    return {}
  end,
  addSubMenuForGroup = function(...)
    return {}
  end,
  removeItem = function(item) end,
  removeItemForCoalition = function(coalitionSide, item) end,
  removeItemForGroup = function(groupId, item) end,
}

-- ---------------------------------------------------------------------------
-- log (DCS server-side log)
-- ---------------------------------------------------------------------------
log = {
  write = function(source, level, text)
    _log(level, "[" .. source .. "] " .. text)
  end,
  ALERT = 0,
  ERROR = 1,
  WARNING = 2,
  INFO = 3,
  DEBUG = 4,
}

-- ---------------------------------------------------------------------------
-- DCS (global DCS table)
-- ---------------------------------------------------------------------------
DCS = {
  getMissionName = function()
    return "TestMission"
  end,
  getModelTime = function()
    return dcs_mocks.currentTime
  end,
}
Sim = {
  getMissionName = function()
    return "TestMission"
  end,
}

-- ---------------------------------------------------------------------------
-- mist (minimal stub — only the parts used by veaf.lua core)
-- ---------------------------------------------------------------------------
local function _deepCopy(orig, seen)
  seen = seen or {}
  local orig_type = type(orig)
  local copy
  if orig_type == "table" then
    if seen[orig] then
      return seen[orig]
    end
    copy = {}
    seen[orig] = copy
    for k, v in pairs(orig) do
      copy[_deepCopy(k, seen)] = _deepCopy(v, seen)
    end
    setmetatable(copy, _deepCopy(getmetatable(orig), seen))
  else
    copy = orig
  end
  return copy
end

mist = {
  scheduleFunction = function(fn, args, t) end,
  removeFunction = function(fn) end,
  addEventHandler = function(handler)
    return handler
  end,
  removeEventHandler = function(handler) end,
  dynAddStatic = function(template) end,
  respawnGroup = function(name, reset) end,
  DBs = {
    MEgroupsByName = {},
    units = {},
    unitsByName = {},
    humansByName = {},
    groupsByName = {},
  },
  getGroupRoute = function(groupName)
    return nil
  end,
  vec = {
    mag = function(v)
      local x = v.x or 0
      local y = v.y or 0
      local z = v.z or 0
      return math.sqrt(x * x + y * y + z * z)
    end,
    dp = function(v1, v2)
      return (v1.x or 0) * (v2.x or 0) + (v1.y or 0) * (v2.y or 0) + (v1.z or 0) * (v2.z or 0)
    end,
    add = function(v1, v2)
      return { x = (v1.x or 0) + (v2.x or 0), y = (v1.y or 0) + (v2.y or 0), z = (v1.z or 0) + (v2.z or 0) }
    end,
    scalarMult = function(v, s)
      return { x = (v.x or 0) * s, y = (v.y or 0) * s, z = (v.z or 0) * s }
    end,
  },
  utils = {
    deepCopy = _deepCopy,
    round = function(n, dec)
      if dec then
        local factor = 10 ^ dec
        return math.floor(n * factor + 0.5) / factor
      else
        return math.floor(n + 0.5)
      end
    end,
    metersToFeet = function(m)
      return m * 3.28084
    end,
    feetToMeters = function(ft)
      return ft / 3.28084
    end,
    NMToMeters = function(nm)
      return nm * 1852
    end,
    metersToNM = function(m)
      return m / 1852
    end,
    mpsToKnots = function(mps)
      return mps * 1.94384
    end,
    get2DDist = function(v1, v2)
      local dx = (v1.x or 0) - (v2.x or 0)
      local dz = (v1.z or 0) - (v2.z or 0)
      return math.sqrt(dx * dx + dz * dz)
    end,
    toDegree = function(rad)
      return rad * 180 / math.pi
    end,
    toRadian = function(deg)
      return deg * math.pi / 180
    end,
    converter = function(from, to, value)
      if from == "hpa" and to == "inhg" then
        return value * 0.02953
      end
      return value
    end,
  },
}

-- ---------------------------------------------------------------------------
-- Object helpers
-- ---------------------------------------------------------------------------
Object.getCategory = function(obj)
  return Object.Category.UNIT
end

-- ---------------------------------------------------------------------------
-- Unit / Group extra stubs
-- ---------------------------------------------------------------------------
Unit.getGroup = function(unit)
  return nil
end
Unit.destroy = function(unit) end
-- getCategoryEx() returns a Unit.Category (AIRPLANE/HELICOPTER/…); unlike getCategory()
-- which returns an Object.Category. Default to AIRPLANE; tests override per unit.
Unit.getCategoryEx = function(unit)
  return (unit and unit._categoryEx) or Unit.Category.AIRPLANE
end
StaticObject.destroy = function(obj) end
Group.destroy = function(obj) end

-- Additional mist stubs needed by veafSpawn sub-modules
mist.getRandPointInCircle = function(spot, r)
  return { x = spot.x or 0, y = spot.y or 0, z = spot.z or 0 }
end
mist.getNextUnitId = function()
  return 999
end
mist.teleportToPoint = function(vars)
  return nil
end
mist.dynAdd = function(template) end
mist.goRoute = function(group, route) end

-- ---------------------------------------------------------------------------
-- world.weather  (used by veafWeather module)
-- ---------------------------------------------------------------------------
world.weather = {
  getFogThickness = function()
    return 0
  end,
  getFogVisibilityDistance = function()
    return 0
  end,
}

-- ---------------------------------------------------------------------------
-- weathermark  (DCS internal; used inside veafWeatherData:create())
-- ---------------------------------------------------------------------------
weathermark = {
  _GetWind = function(vec3, altitude)
    return 270, 5
  end,
}

-- ---------------------------------------------------------------------------
-- Helpers for tests
-- ---------------------------------------------------------------------------

--- Advance the mock clock by `seconds`.
function dcs_mocks.advanceTime(seconds)
  dcs_mocks.currentTime = dcs_mocks.currentTime + seconds
end

--- Reset the mock clock, log capture, and unit/group registries.
function dcs_mocks.reset()
  dcs_mocks.currentTime = 0
  dcs_mocks.logs = {}
  dcs_mocks.messages = {}
  dcs_mocks.cockpitCalls = {}
  dcs_mocks.cockpitArguments = {}
  dcs_mocks.exportAvailable = true
  dcs_mocks.clearUnitsAndGroups()
  for _, manager in ipairs({ CTLDZoneManager, CTLDBeaconManager, CTLDJTACManager }) do
    if manager then
      manager._instance.calls = {}
    end
  end
end

-- ---------------------------------------------------------------------------
-- Configurable unit / group registry
-- ---------------------------------------------------------------------------

local _unit_registry = {} -- name → mock unit table
local _group_registry = {} -- name → mock group table

--- Register a mock unit so that Unit.getByName(name) returns it.
-- @param name  Unit name string
-- @param data  Table with unit attributes (coalition, point, …).
--              Attributes like isExist/inAir must be functions: { isExist = function() return true end }.
--              Methods not explicitly provided default to sensible stubs.
function dcs_mocks.addUnit(name, data)
  local u = data or {}
  u.name = name
  u.isExist = u.isExist ~= nil and u.isExist or function()
    return true
  end
  u.inAir = u.inAir ~= nil and u.inAir or function()
    return false
  end
  u.getPoint = u.getPoint or function()
    return { x = 0, y = 0, z = 0 }
  end
  u.getCoalition = u.getCoalition or function()
    return coalition.side.BLUE
  end
  u.getName = u.getName or function()
    return name
  end
  u.getGroup = u.getGroup or function()
    return nil
  end
  u.getCategoryEx = u.getCategoryEx or function(self)
    return self._categoryEx or Unit.Category.AIRPLANE
  end
  u.getID = u.getID or function(self)
    return self._id or 1
  end
  -- Cockpit animation arguments, read by veafAssist's `argument` check.
  -- A test sets them with { _drawArgs = { [510] = 1.0 } } and moves a switch by
  -- reassigning the entry.
  u.getDrawArgumentValue = u.getDrawArgumentValue or function(self, arg)
    return (self._drawArgs or {})[arg]
  end
  u.destroy = u.destroy or function() end
  _unit_registry[name] = u
end

--- Register a mock group so that Group.getByName(name) returns it.
-- @param name  Group name string
-- @param data  Table with group attributes.
function dcs_mocks.addGroup(name, data)
  local g = data or {}
  g.name = name
  g.isExist = g.isExist ~= nil and g.isExist or function()
    return true
  end
  g.getName = g.getName or function()
    return name
  end
  g.getID = g.getID or function()
    return g._id or 1
  end
  g.getUnits = g.getUnits or function()
    return {}
  end
  g.destroy = g.destroy or function() end
  _group_registry[name] = g
end

--- Remove a unit from the registry (simulates unit death / despawn).
function dcs_mocks.removeUnit(name)
  _unit_registry[name] = nil
end

--- Remove a group from the registry.
function dcs_mocks.removeGroup(name)
  _group_registry[name] = nil
end

--- Clear all registered units and groups.
function dcs_mocks.clearUnitsAndGroups()
  _unit_registry = {}
  _group_registry = {}
end

-- Wire up the DCS API stubs to the registries.
Unit.getByName = function(name)
  return _unit_registry[name]
end
Group.getByName = function(name)
  return _group_registry[name]
end

--- Return all captured log lines matching a pattern.
function dcs_mocks.findLog(pattern)
  local found = {}
  for _, entry in ipairs(dcs_mocks.logs) do
    if entry.text:find(pattern) then
      table.insert(found, entry)
    end
  end
  return found
end

-- ---------------------------------------------------------------------------
-- trigger.flareColor (used by veafSpawnEffects.spawnSignalFlare)
-- ---------------------------------------------------------------------------
trigger.flareColor = { RED = 0, GREEN = 1, WHITE = 2, YELLOW = 3 }

-- ---------------------------------------------------------------------------
-- Controller  (DCS unit/group controller)
-- ---------------------------------------------------------------------------
Controller = {
  setCommand = function(controller, cmd) end,
  pushTask = function(controller, task) end,
}

-- ---------------------------------------------------------------------------
-- ctld  (minimal stub — only the API surface used by veafSpawn sub-modules)
--
-- Mixed v1 / v2 on purpose, for the length of the CTLD 2 migration: the v1 globals
-- below are still what veafGrass / veafSpawnGround / veafSpawnEffects poke, and they
-- go when FEAT-CTLD2-INTEGRATION ticket 05 ports those bridges to the v2 managers.
-- `utils.log` and `initialize` are the v2 surface veaf.lua drives today.
-- ---------------------------------------------------------------------------
ctld = {
  initialize = function() end,
  utils = {
    log = function(...) end,
  },
}

-- CTLD 2 managers. Each records its calls so a test can assert what VEAF asked of CTLD
-- without reaching into the engine; dcs_mocks.reset() clears them.
local function _manager(methods)
  local instance = { calls = {} }
  for name, fn in pairs(methods) do
    instance[name] = function(self, ...)
      table.insert(self.calls, { method = name, args = { ... } })
      return fn(...)
    end
  end
  return {
    getInstance = function()
      return instance
    end,
    _instance = instance,
  }
end

CTLDZoneManager = _manager({
  registerFOBAsLogistic = function() end,
  unregisterLogistic = function() end,
})

CTLDBeaconManager = _manager({
  -- Frequencies in Hz, as the real manager returns them.
  createAtPoint = function()
    return { vhf = 30000, uhf = 250000000, fm = 30000000 }
  end,
  removeBeacon = function()
    return true
  end,
})

CTLDJTACManager = _manager({
  autoLase = function() end,
  stopAutoLase = function() end,
})

-- ---------------------------------------------------------------------------
-- veafNamedPoints  (named points registry stub)
-- ---------------------------------------------------------------------------
veafNamedPoints = {
  addPoint = function(name, point) end,
  namePoint = function(pos, name, side, permanent) end,
  getPoint = function(name)
    return nil
  end,
}

-- ---------------------------------------------------------------------------
-- veafSecurity  (security checks — always pass in tests)
-- ---------------------------------------------------------------------------
veafSecurity = {
  checkPassword_L0 = function(...)
    return true
  end,
  -- The ADMIN tier's check. Missing here until FIX-DOCAUDIT-CODE 01 wired that tier into the two
  -- dispatchers, which is when a test could reach it at all.
  checkSecurity_L0 = function(...)
    return true
  end,
  checkSecurity_L9 = function(...)
    return true
  end,
  checkSecurity_L1 = function(...)
    return true
  end,
  checkSecurity_MM = function(...)
    return true
  end,
}

-- ---------------------------------------------------------------------------
-- veafUnits  (unit/group database stubs)
-- ---------------------------------------------------------------------------
veafUnits = {
  findUnit = function(name)
    return nil
  end,
  findDcsUnit = function(name)
    return nil
  end,
  findGroup = function(name)
    return nil
  end,
  checkPositionForUnit = function(pt, unit)
    return true
  end,
  processGroup = function(group, ...)
    return group
  end,
  placeGroup = function(group, ...)
    return group, {}
  end,
  removePathfindingFixUnit = function(...) end,
  delayBeforePathfindingFix = 1,
  countInfantryAndVehicles = function(groupData)
    return 0, 0
  end,
  traceGroup = function(...) end,
}

-- ---------------------------------------------------------------------------
-- veafCasMission  (CAS group generators)
-- ---------------------------------------------------------------------------
veafCasMission = {
  SIDE_BLUE = 2,
  SIDE_RED = 1,
  generateInfantryGroup = function(...)
    return { units = {} }
  end,
  generateArmorPlatoon = function(...)
    return { units = {} }
  end,
  generateAirDefenseGroup = function(...)
    return { units = {} }
  end,
  generateTransportCompany = function(...)
    return { units = {} }
  end,
  generateCasGroup = function(...)
    return {}
  end,
}

-- ---------------------------------------------------------------------------
-- veafRadio  (radio menu stubs)
-- ---------------------------------------------------------------------------
veafRadio = {
  getHumanUnitOrWingman = function(name)
    return nil
  end,
  addMenu = function(...)
    return {}
  end,
  addSubMenu = function(...)
    return {}
  end,
  addCommandToSubmenu = function(...) end,
  addSecuredCommandToSubmenu = function(...) end,
  addCommandToMainMenu = function(...) end,
  addSecuredCommandToMainMenu = function(...) end,
  delCommand = function(...) end,
  delSubmenu = function(...) end,
  clearSubmenu = function(...) end,
  doNotPaginate = function(...) end,
  refreshRadioMenu = function(...) end,
  USAGE_ForAll = 0,
  USAGE_ForGroup = 1,
  USAGE_ForUnit = 2,
}

-- ---------------------------------------------------------------------------
-- mist.tostringLL  (used by infoOnAllConvoys with non-empty convoy data)
-- ---------------------------------------------------------------------------
mist.tostringLL = function(lat, lon, acc)
  return "0N 0E"
end

-- Update addGroup to include controller and category defaults
local _original_addGroup = dcs_mocks.addGroup
function dcs_mocks.addGroup(name, data)
  _original_addGroup(name, data)
  local g = _group_registry[name] -- already set by _original_addGroup
  if not g.getController then
    local _ctrl = {
      setCommand = function() end,
      pushTask = function() end,
      getDetectedTargets = function()
        return {}
      end,
    }
    g.getController = function(self)
      return _ctrl
    end
  end
  g.getCategory = g.getCategory or function(self)
    return Group.Category.GROUND
  end
  g.getCoalition = g.getCoalition or function(self)
    return coalition.side.BLUE
  end
  g.getUnit = g.getUnit or function(self, idx)
    return nil
  end
end

-- Group.getUnits(group) — delegates to the instance method so addGroup's getUnits stub is used.
Group.getUnits = function(grp)
  return grp:getUnits()
end

-- ---------------------------------------------------------------------------
-- Cockpit primitives — and the environment boundary they sit behind
--
-- Measured in game (docs/exploration/DCS-COCKPIT-ASSISTANCE-API.md): a_cockpit_*
-- and a_out_picture_* do NOT exist in the environment mission scripts run in.
-- They live in the trigger environment, reachable only through
-- net.dostring_in("mission", <code>). The mocks reproduce that boundary rather
-- than the convenient fiction of one flat namespace: a module that called them
-- directly would pass its tests here and fail in game, which is exactly what
-- happened before this was measured.
--
-- So the primitives below are deliberately NOT globals. They are reachable only
-- through the net.dostring_in stub, which evaluates the chunk against them.
-- ---------------------------------------------------------------------------

--- Calls recorded by the cockpit stubs, in order: { fn = "…", args = { … } }.
dcs_mocks.cockpitCalls = {}

local function _recordCockpitCall(name, ...)
  table.insert(dcs_mocks.cockpitCalls, { fn = name, args = { ... } })
end

--- Return the recorded calls to one cockpit function, in order.
function dcs_mocks.cockpitCallsTo(name)
  local found = {}
  for _, call in ipairs(dcs_mocks.cockpitCalls) do
    if call.fn == name then
      table.insert(found, call)
    end
  end
  return found
end

--- The trigger environment's globals. Everything a chunk passed to
--- net.dostring_in("mission", …) can see — and nothing a mission script can.
local _triggerEnv = {}

_triggerEnv.a_cockpit_highlight = function(id, element)
  _recordCockpitCall("a_cockpit_highlight", id, element)
  return true
end

_triggerEnv.a_cockpit_remove_highlight = function(id)
  _recordCockpitCall("a_cockpit_remove_highlight", id)
  return true
end

_triggerEnv.a_out_picture_u = function(unitId, resource, duration, clearView, startDelay, hAlign, vAlign, size, units)
  _recordCockpitCall("a_out_picture_u", unitId, resource, duration, clearView, startDelay, hAlign, vAlign, size, units)
  return true
end

_triggerEnv.a_out_picture_stop = function()
  _recordCockpitCall("a_out_picture_stop")
  return true
end

--- Resolve an embedded resource key. The real one maps the key to the file the
--- build embedded; here the key is its own resolution, which is enough to assert
--- that the right state was displayed.
_triggerEnv.getValueResourceByKey = function(key)
  return key
end

--- Cockpit parameters the fake aircraft publishes, as the engine's "NAME:value" dump.
--- A test sets dcs_mocks.cockpitParams to drive it.
dcs_mocks.cockpitParams = {}

_triggerEnv.list_cockpit_params = function()
  local lines = {}
  for name, value in pairs(dcs_mocks.cockpitParams) do
    lines[#lines + 1] = name .. ":" .. tostring(value)
  end
  return table.concat(lines, "\n")
end

-- The standard-library names a probe chunk needs. The trigger environment is a
-- namespace of its own, so nothing is inherited from the mission script's globals.
_triggerEnv.type = type
_triggerEnv.tostring = tostring
_triggerEnv.pairs = pairs
_triggerEnv.table = table
_triggerEnv.string = string

--- The pristine trigger environment, so a test can put back what it removed.
local _pristineTriggerEnv = {}
for name, value in pairs(_triggerEnv) do
  _pristineTriggerEnv[name] = value
end

--- Override or remove a trigger-environment global, for a test.
function dcs_mocks.setTriggerGlobal(name, value)
  _triggerEnv[name] = value
end

--- Put every trigger-environment global back the way it was.
function dcs_mocks.restoreTriggerGlobals()
  for name in pairs(_triggerEnv) do
    _triggerEnv[name] = nil
  end
  for name, value in pairs(_pristineTriggerEnv) do
    _triggerEnv[name] = value
  end
end

-- ---------------------------------------------------------------------------
-- The export environment — a THIRD namespace
--
-- Export.lua's own, where GetDevice(0):get_argument_value(arg) reads a cockpit
-- control's POSITION. Neither the mission nor the trigger environment can
-- (measured in game). Kept separate here for the same reason as the trigger one:
-- a module reaching for GetDevice directly must fail in the tests exactly as it
-- would in game.
-- ---------------------------------------------------------------------------

--- Cockpit animation arguments the fake aircraft reports: { [510] = -1.0 }.
dcs_mocks.cockpitArguments = {}

--- Whether the export environment answers at all. A dedicated server is expected
--- to look like `false`; set it to exercise the degraded path.
dcs_mocks.exportAvailable = true

local _exportEnv = {
  type = type,
  tostring = tostring,
  GetDevice = function(_)
    return {
      get_argument_value = function(_, argument)
        return dcs_mocks.cockpitArguments[argument]
      end,
    }
  end,
}

--- net.dostring_in — the only bridge out of a mission script. Compiles the chunk
--- against the target environment, so a module that reaches for a_cockpit_highlight
--- or GetDevice directly gets nil, exactly as it would in game.
net = net or {}
net.dostring_in = function(environment, code)
  local target
  if environment == "mission" then
    target = _triggerEnv
  elseif environment == "export" then
    if not dcs_mocks.exportAvailable then
      return nil
    end
    target = _exportEnv
  else
    return nil
  end
  local chunk, err = loadstring(code)
  if not chunk then
    error("net.dostring_in: " .. tostring(err))
  end
  setfenv(chunk, target)
  return chunk()
end
