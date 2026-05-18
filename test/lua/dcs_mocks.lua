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
  error = function(text) _log("E", text) end,
  warning = function(text) _log("W", text) end,
  info = function(text) _log("I", text) end,
  mission = {
    theatre = "Caucasus",
    date    = { Day = 1, Month = 1, Year = 2024 },
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
  getTime = function() return dcs_mocks.currentTime end,
  getAbsTime = function() return dcs_mocks.currentTime end,
  scheduleFunction = function(fn, args, t) end,
}

-- ---------------------------------------------------------------------------
-- trigger
-- ---------------------------------------------------------------------------
trigger = {
  action = {
    outText = function(text, duration) end,
    outTextForGroup = function(groupId, text, duration) end,
    outTextForUnit = function(unitId, text, duration) end,
    markToAll = function(...) end,
    markToCoalition = function(...) end,
    removeMark = function(id) end,
    arrowToAll = function(...) end,
    lineToAll = function(...) end,
    circleToAll = function(...) end,
    rectToAll = function(...) end,
    textToAll = function(...) end,
    setMarkupColor = function(...) end,
    setUserFlag = function(flag, val) end,
    smoke = function(...) end,
    signalFlare = function(...) end,
    illuminationBomb = function(...) end,
  },
  misc = {
    getUserFlag = function(flag) return 0 end,
    getZone = function(name) return nil end,
  },
  smokeColor = {
    Green  = 0,
    Red    = 1,
    White  = 2,
    Orange = 3,
    Blue   = 4,
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
  getAirbases = function(coalition_id) return {} end,
  searchObjects = function(category, volume, fn) end,
}

-- ---------------------------------------------------------------------------
-- coalition
-- ---------------------------------------------------------------------------
coalition = {
  side = { NEUTRAL = 0, RED = 1, BLUE = 2 },
  getGroups = function(side, category) return {} end,
  getStaticObjects = function(side) return {} end,
  getAirbases = function(side) return {} end,
  addGroup = function(...) end,
  getCountries = function(side)
    if side == 1 then return { 0 } end  -- RED: Russia
    if side == 2 then return { 2 } end  -- BLUE: USA
    return {}
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
  getByName = function(name) return nil end,
  Category = { AIRPLANE = 0, HELICOPTER = 1, GROUND_UNIT = 2, SHIP = 3, STRUCTURE = 4 },
}
Group = {
  getByName = function(name) return nil end,
  Category = { GROUND = 0, AIRPLANE = 1, HELICOPTER = 2, SHIP = 3, TRAIN = 4 },
}
StaticObject = {
  getByName = function(name) return nil end,
}
Object = {
  Category = { UNIT = 1, WEAPON = 2, STATIC = 3, BASE = 4, SCENERY = 5, CARGO = 6 },
}
Airbase = {
  getByName = function(name) return nil end,
  Category = { AIRDROME = 0, HELIPAD = 1, SHIP = 2 },
}

-- ---------------------------------------------------------------------------
-- land / coord / atmosphere
-- ---------------------------------------------------------------------------
land = {
  getHeight = function(vec2) return 0 end,
  getSurfaceType = function(vec2) return 1 end,
  SurfaceType = { LAND = 1, SHALLOW_WATER = 2, WATER = 3, ROAD = 4, RUNWAY = 5 },
}
coord = {
  LLtoLO = function(lat, lon, alt) return { x = 0, y = 0, z = 0 } end,
  LOtoLL = function(vec3) return 0, 0, 0 end,
  LOtoMGRS = function(vec3) return { UTMZone = "", Easting = 0, Northing = 0 } end,
}
atmosphere = {
  getWind = function(point) return { x = 0, y = 0, z = 0 } end,
  getWindWithTurbulence = function(point) return { x = 0, y = 0, z = 0 } end,
  getTemperatureAndPressure = function(point) return 293.15, 101325 end,
}

-- ---------------------------------------------------------------------------
-- missionCommands
-- ---------------------------------------------------------------------------
missionCommands = {
  addCommand = function(...) return {} end,
  addSubMenu = function(...) return {} end,
  removeItem = function(item) end,
}

-- ---------------------------------------------------------------------------
-- log (DCS server-side log)
-- ---------------------------------------------------------------------------
log = {
  write = function(source, level, text) _log(level, "[" .. source .. "] " .. text) end,
  ALERT = 0, ERROR = 1, WARNING = 2, INFO = 3, DEBUG = 4,
}

-- ---------------------------------------------------------------------------
-- DCS (global DCS table)
-- ---------------------------------------------------------------------------
DCS = {
  getMissionName = function() return "TestMission" end,
  getModelTime = function() return dcs_mocks.currentTime end,
}
Sim = {
  getMissionName = function() return "TestMission" end,
}

-- ---------------------------------------------------------------------------
-- mist (minimal stub — only the parts used by veaf.lua core)
-- ---------------------------------------------------------------------------
local function _deepCopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == "table" then
    copy = {}
    for k, v in pairs(orig) do
      copy[_deepCopy(k)] = _deepCopy(v)
    end
    setmetatable(copy, _deepCopy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end

mist = {
  scheduleFunction  = function(fn, args, t) end,
  removeFunction    = function(fn) end,
  addEventHandler   = function(handler) return handler end,
  removeEventHandler= function(handler) end,
  dynAddStatic      = function(template) end,
  respawnGroup      = function(name, reset) end,
  DBs = {
    MEgroupsByName   = {},
    units            = {},
    unitsByName      = {},
    humansByName     = {},
  },
  getGroupRoute = function(groupName) return nil end,
  vec = {
    mag = function(v)
      local x = v.x or 0
      local y = v.y or 0
      local z = v.z or 0
      return math.sqrt(x*x + y*y + z*z)
    end,
    dp = function(v1, v2)
      return (v1.x or 0)*(v2.x or 0) + (v1.y or 0)*(v2.y or 0) + (v1.z or 0)*(v2.z or 0)
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
    metersToFeet    = function(m)   return m * 3.28084 end,
    feetToMeters    = function(ft)  return ft / 3.28084 end,
    NMToMeters      = function(nm)  return nm * 1852 end,
    metersToNM      = function(m)   return m / 1852 end,
    mpsToKnots      = function(mps) return mps * 1.94384 end,
    get2DDist       = function(v1, v2)
      local dx = (v1.x or 0) - (v2.x or 0)
      local dz = (v1.z or 0) - (v2.z or 0)
      return math.sqrt(dx * dx + dz * dz)
    end,
    toDegree = function(rad) return rad * 180 / math.pi end,
    toRadian = function(deg) return deg * math.pi / 180 end,
    converter       = function(from, to, value)
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
Object.getCategory = function(obj) return Object.Category.UNIT end

-- ---------------------------------------------------------------------------
-- Unit / Group extra stubs
-- ---------------------------------------------------------------------------
Unit.getGroup = function(unit) return nil end
Unit.destroy  = function(unit) end

-- ---------------------------------------------------------------------------
-- world.weather  (used by veafWeather module)
-- ---------------------------------------------------------------------------
world.weather = {
  getFogThickness           = function() return 0 end,
  getFogVisibilityDistance  = function() return 0 end,
}

-- ---------------------------------------------------------------------------
-- weathermark  (DCS internal; used inside veafWeatherData:create())
-- ---------------------------------------------------------------------------
weathermark = {
  _GetWind = function(vec3, altitude) return 270, 5 end,
}

-- ---------------------------------------------------------------------------
-- Helpers for tests
-- ---------------------------------------------------------------------------

--- Advance the mock clock by `seconds`.
function dcs_mocks.advanceTime(seconds)
  dcs_mocks.currentTime = dcs_mocks.currentTime + seconds
end

--- Reset the mock clock and log capture.
function dcs_mocks.reset()
  dcs_mocks.currentTime = 0
  dcs_mocks.logs = {}
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
