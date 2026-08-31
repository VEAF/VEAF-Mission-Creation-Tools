--- DCS World API mocks for unit testing outside DCS.
--- Provides lightweight stubs for all DCS globals so that VEAF modules can be
--- loaded and exercised in a plain Lua 5.1 interpreter.

-- ---------------------------------------------------------------------------
-- Controllable time (override in tests: dcs_mocks.currentTime = X)
-- ---------------------------------------------------------------------------
dcs_mocks = {}
dcs_mocks.currentTime = 0
dcs_mocks.missionStart = 0 -- what timer.getTime0 answers
--- Trigger zones visible to trigger.misc.getZone, keyed by name:
--- { point = { x, y, z }, radius = <metres> }. Empty unless a suite calls dcs_mocks.addZone.
dcs_mocks.zones = {}
dcs_mocks.logs = {} -- captured log lines
dcs_mocks.tasksSet = {} -- captured Controller:setTask calls, as { group = name, task = task }
dcs_mocks.staticsAdded = {} -- captured coalition.addStaticObject calls, as { countryId, object }
dcs_mocks.groupsAdded = {} -- captured coalition.addGroup calls, as { countryId, categoryId, group }

-- Registre des groupes, declare ICI et pas plus bas : `coalition.getGroups` le lit, et un local declare
-- apres son usage laisse la fermeture capturer la globale — c'est-a-dire nil.
local _group_registry = {} -- nom → table du groupe simule

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
--- Tasks handed to timer.scheduleFunction, keyed by the id it returned:
--- { fn = <function>, args = <any>, time = <model time>, done = <boolean> }.
--- Nothing runs on its own — see dcs_mocks.runScheduled.
dcs_mocks.scheduledTasks = {}
local _nextScheduleId = 0

timer = {
  getTime = function()
    return dcs_mocks.currentTime
  end,
  getAbsTime = function()
    return dcs_mocks.currentTime
  end,
  --- Mission start, in absolute time. A spawn subtracts it from getAbsTime to know how much of a
  --- group's editor start_time is left.
  getTime0 = function()
    return dcs_mocks.missionStart or 0
  end,
  --- Record a task and hand back an id. **It does not run**, and `setTime` does not run it
  --- either: a suite that merely advances the clock must keep behaving as it did when this
  --- was a no-op. Call dcs_mocks.runScheduled to make time actually pass for the scheduler.
  scheduleFunction = function(fn, args, t)
    _nextScheduleId = _nextScheduleId + 1
    dcs_mocks.scheduledTasks[_nextScheduleId] = { fn = fn, args = args, time = t, done = false }
    return _nextScheduleId
  end,
  removeFunction = function(id)
    dcs_mocks.scheduledTasks[id] = nil
  end,
  --- Test-only: move mission time forward. Not a DCS API — DCS has no setter — but anything
  --- with an expiry (a timed security elevation, a cooldown) needs a way to reach the far side
  --- of it without the suite actually waiting.
  setTime = function(t)
    dcs_mocks.currentTime = t
  end,
}

--- Test-only: run every scheduled task that is due at `untilTime`, the way DCS does.
---
--- DCS calls `fn(args, time)` and re-arms the same id when the call returns a number, so a
--- repeating task is one entry that keeps moving forward, not a new entry per repetition.
--- The clock is moved to each task's own time before its call, so a task reading
--- `timer.getTime()` sees what DCS would show it.
---
--- @param untilTime number model time to run up to (inclusive)
--- @param maxPasses number|nil safety stop for a task that re-arms in the past (default 1000)
--- @return number how many calls were made
function dcs_mocks.runScheduled(untilTime, maxPasses)
  local calls = 0
  local passes = 0
  local limit = maxPasses or 1000
  while passes < limit do
    passes = passes + 1
    -- Pick the earliest due task, so tasks fire in time order rather than id order.
    local dueId, due = nil, nil
    for id, task in pairs(dcs_mocks.scheduledTasks) do
      if task.time <= untilTime and (due == nil or task.time < due.time or (task.time == due.time and id < dueId)) then
        dueId, due = id, task
      end
    end
    if not dueId then
      break
    end
    dcs_mocks.currentTime = due.time
    dcs_mocks.scheduledTasks[dueId] = nil
    calls = calls + 1
    local nextTime = due.fn(due.args, due.time)
    if type(nextTime) == "number" then
      due.time = nextTime
      dcs_mocks.scheduledTasks[dueId] = due
    end
  end
  dcs_mocks.currentTime = untilTime
  return calls
end

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
    --- Answers a zone registered with dcs_mocks.addZone, nil otherwise — which is what an unknown
    --- zone name gives in DCS, and what every suite saw before zones could be registered at all.
    getZone = function(name)
      return dcs_mocks.zones[name]
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
  -- Search volume shapes, as taken by world.searchObjects and world.removeJunk. Both were already
  -- called by the runtime (veafCombatZone's junk cleanup, veafGrass's occupancy probe) while this
  -- enum was missing from the mock, so any test reaching those lines died on a nil index.
  VolumeType = {
    SEGMENT = 0,
    BOX = 1,
    SPHERE = 2,
    PYRAMID = 3,
  },
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
-- AI.Option  (ids and values taken from veaf_libs/data/dcs-schema/dcs-world-api-schema.json)
-- Only the enums the VEAF scripts actually read; add from the schema rather than from memory.
-- ---------------------------------------------------------------------------
AI = {
  Option = {
    Air = {
      id = {
        NO_OPTION = -1,
        ROE = 0,
        REACTION_ON_THREAT = 1,
        RADAR_USING = 3,
        FLARE_USING = 4,
        SILENCE = 7,
        ECM_USING = 13,
        MISSILE_ATTACK = 18,
      },
      val = {
        ROE = { WEAPON_FREE = 0, OPEN_FIRE_WEAPON_FREE = 1, OPEN_FIRE = 2, RETURN_FIRE = 3, WEAPON_HOLD = 4 },
        RADAR_USING = { NEVER = 0, FOR_ATTACK_ONLY = 1, FOR_SEARCH_IF_REQUIRED = 2, FOR_CONTINUOUS_SEARCH = 3 },
        ECM_USING = { NEVER_USE = 0, USE_IF_ONLY_LOCK_BY_RADAR = 1, USE_IF_DETECTED_LOCK_BY_RADAR = 2, ALWAYS_USE = 3 },
      },
    },
    Ground = {
      id = { NO_OPTION = -1, ROE = 0, FORMATION = 5, DISPERSE_ON_ATTACK = 8, ALARM_STATE = 9, ENGAGE_AIR_WEAPONS = 20 },
      val = {
        ROE = { OPEN_FIRE = 2, RETURN_FIRE = 3, WEAPON_HOLD = 4 },
        ALARM_STATE = { AUTO = 0, GREEN = 1, RED = 2 },
      },
    },
    Naval = {
      id = { NO_OPTION = -1, ROE = 0 },
      val = { ROE = { OPEN_FIRE = 2, RETURN_FIRE = 3, WEAPON_HOLD = 4 } },
    },
  },
}

-- ---------------------------------------------------------------------------
-- coalition
-- ---------------------------------------------------------------------------
coalition = {
  side = { NEUTRAL = 0, RED = 1, BLUE = 2 },
  -- Rend les groupes enregistres, au lieu d'une liste toujours vide. Dans DCS, un groupe qu'on peut
  -- chercher par son nom EST dans la liste de sa coalition ; un double qui repond `{}` ici laisse passer
  -- tout code qui enumere les groupes, sans jamais l'exercer.
  --
  -- `_coalition` dans les donnees passees a `addGroup` filtre ; un groupe qui n'en declare pas apparait
  -- pour toutes les coalitions, ce qui garde les tests existants inchanges.
  getGroups = function(side, category)
    local found = {}
    for _, g in pairs(_group_registry) do
      if g._coalition == nil or g._coalition == side then
        table.insert(found, g)
      end
    end
    return found
  end,
  getStaticObjects = function(side)
    return {}
  end,
  getAirbases = function(side)
    return {}
  end,
  -- Present in the real API (`dcs-world-api.lua:1395`) and it was missing here, which is why nothing
  -- could test a player-name lookup. Empty by default; a test that cares overrides it.
  getPlayers = function(side)
    return {}
  end,
  --- Records what was submitted, for the same reason addStaticObject does.
  --- Entries are `{ countryId, categoryId, group }`. Cleared by dcs_mocks.reset().
  addGroup = function(countryId, categoryId, group)
    table.insert(dcs_mocks.groupsAdded, { countryId = countryId, categoryId = categoryId, group = group })
  end,
  --- Records what was submitted, rather than discarding it: what a spawner hands DCS *is* the
  --- behaviour under test, and asserting against a no-op stub asserts nothing.
  --- Entries are `{ countryId = <id>, object = <the table submitted> }`. Cleared by dcs_mocks.reset().
  addStaticObject = function(countryId, object)
    table.insert(dcs_mocks.staticsAdded, { countryId = countryId, object = object })
  end,
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
  -- `UTMZone` manquait, alors que le vrai DCS le fournit toujours : tout code qui construit une grille
  -- lisible fait `grid.UTMZone .. " " .. grid.MGRSDigraph .. …` et mourait sur une concatenation de nil.
  -- Un mock incomplet ne fait pas echouer le code qui le lit — il le fait planter ailleurs.
  LLtoMGRS = function(lat, lon)
    return { UTMZone = "37T", MGRSDigraph = "XX", Easting = 100000, Northing = 200000 }
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
-- Object helpers
-- ---------------------------------------------------------------------------
-- Defaults to UNIT; a test that needs a static or a piece of cargo sets `_category` on its fake,
-- which is how combat-zone tests tell a static object from a vehicle.
Object.getCategory = function(obj)
  return (obj and obj._category) or Object.Category.UNIT
end

--- The position DCS reports for an object, in its `{ p = vec3, x/y/z = orientation }` form.
--- A fake sets `_point`; anything else has no position, which is what the register treats as
--- "cannot be placed" rather than as an error.
Object.getPosition = function(obj)
  if obj and obj._point then
    return { p = obj._point }
  end
  return nil
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
-- getCategory() returns an Object.Category, which is the trap FIX-EVENTHANDLER-UNITCATEGORY was
-- about: it looks like it answers "airplane or ground unit?" and does not.
Unit.getCategory = function(unit)
  return (unit and unit._category) or Object.Category.UNIT
end
StaticObject.destroy = function(obj) end
Group.destroy = function(obj) end

-- ---------------------------------------------------------------------------
-- Deterministic randomness
-- ---------------------------------------------------------------------------
-- `veaf.getRandomPointInCircle` is VEAF's own code since DROP-MIST ticket 06, so the draw actually
-- runs in tests instead of being answered by a stub that handed back the centre and ignored the
-- radius. Rather than stubbing our own function — which would put the tests back to asserting a mock —
-- the randomness underneath it is made deterministic: `math.random()` answers 0, so the drawn angle is
-- 0 and the drawn distance is `radius * sqrt(0)` = 0, which lands exactly on the centre. That is what
-- the MiST stub used to return, so suites that never cared about the draw keep seeing what they saw.
--
-- A suite that *does* care drives it with dcs_mocks.setRandomSequence.
local _realRandom = math.random
dcs_mocks.randomSequence = nil
dcs_mocks.randomIndex = 0

--- Feed the next draws. Each entry is a number in [0, 1); the sequence repeats once exhausted.
--- Call with nil to go back to the constant 0.
function dcs_mocks.setRandomSequence(values)
  dcs_mocks.randomSequence = values
  dcs_mocks.randomIndex = 0
end

--- The unit draw the mocks answer: the next value of the sequence, or 0.
local function nextUnitDraw()
  local sequence = dcs_mocks.randomSequence
  if not sequence or #sequence == 0 then
    return 0
  end
  dcs_mocks.randomIndex = (dcs_mocks.randomIndex % #sequence) + 1
  return sequence[dcs_mocks.randomIndex]
end

local _deterministicRandom = function(a, b)
  local draw = nextUnitDraw()
  if a == nil then
    return draw
  end
  local low, high = 1, a
  if b ~= nil then
    low, high = a, b
  end
  -- Mirror math.random(m, n): an integer in [low, high].
  return low + math.floor(draw * (high - low + 1))
end
math.random = _deterministicRandom

--- Restore Lua's own generator, for a test that genuinely needs unpredictability.
--- Undone by dcs_mocks.reset(), so it cannot leak into the next suite.
function dcs_mocks.useRealRandom()
  math.random = _realRandom
end

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
  dcs_mocks.scheduledTasks = {}
  dcs_mocks.zones = {}
  dcs_mocks.logs = {}
  dcs_mocks.tasksSet = {}
  dcs_mocks.staticsAdded = {}
  dcs_mocks.groupsAdded = {}
  dcs_mocks.messages = {}
  dcs_mocks.cockpitCalls = {}
  dcs_mocks.cockpitArguments = {}
  dcs_mocks.exportAvailable = true
  dcs_mocks.setRandomSequence(nil)
  math.random = _deterministicRandom
  dcs_mocks.clearUnitsAndGroups()
  for _, manager in ipairs({ CTLDZoneManager, CTLDBeaconManager, CTLDJTACManager }) do
    if manager then
      manager._instance.calls = {}
    end
  end
  if CTLDConfig then
    CTLDConfig._instance.isLoaded = true
    -- Back to CTLD's shipped default, or a test that switches sling loading off leaks into the next one.
    CTLDConfig._instance.settings = { enableHoverSlingload = true }
  end
end

-- ---------------------------------------------------------------------------
-- Configurable unit / group registry
-- ---------------------------------------------------------------------------

local _unit_registry = {} -- name → mock unit table
-- (declare en haut du fichier : `coalition.getGroups` doit le voir)

--- Register a mock unit so that Unit.getByName(name) returns it.
-- @param name  Unit name string
-- @param data  Table with unit attributes (coalition, point, …).
--              Attributes like isExist/inAir must be functions: { isExist = function() return true end }.
--              Methods not explicitly provided default to sensible stubs.
--- Register a trigger zone so trigger.misc.getZone(name) returns it.
---
--- @param name string zone name
--- @param x number northing of its centre
--- @param z number easting of its centre
--- @param radius number|nil radius in metres, default 500
function dcs_mocks.addZone(name, x, z, radius)
  dcs_mocks.zones[name] = { point = { x = x, y = 0, z = z }, radius = radius or 500 }
end

function dcs_mocks.addUnit(name, data)
  local u = data or {}
  u.name = name
  u.isExist = u.isExist ~= nil and u.isExist or function()
    return true
  end
  u.inAir = u.inAir ~= nil and u.inAir or function()
    return false
  end
  -- A unit is active unless the suite says otherwise: late activation is the exception, not the rule.
  u.isActive = u.isActive or function()
    return true
  end
  u.getPoint = u.getPoint or function()
    return { x = 0, y = 0, z = 0 }
  end
  -- DCS's getPosition returns a full orientation plus the point. `x` is the unit's forward vector, and
  -- it is read for real now that `veaf.getHeading` is VEAF's own code rather than a MiST stub that
  -- answered a constant. `_heading` (radians) sets it; the default keeps the pi/2 the old stub returned,
  -- so a suite that never cared about heading sees exactly what it saw before.
  u.getPosition = u.getPosition
    or function(self)
      local target = self or u
      local heading = target._heading or (math.pi / 2)
      return { p = target:getPoint(), x = { x = math.cos(heading), y = 0, z = math.sin(heading) } }
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
  -- The settings reader, which a real CTLD defines unconditionally (`CTLD.lua:359`) and which every
  -- VEAF path that reads a CTLD setting goes through. Delegates to the config singleton below, exactly
  -- as the engine does, so a test that writes a setting sees the write.
  gs = function(key)
    return CTLDConfig.get():getSetting(key)
  end,
  -- The engine's shipped dictionaries. `i18n_lang` is the module-level default CTLD hard-codes to
  -- "en"; a mission's own language is supposed to override it, and `veaf.ctld_initialize` is what
  -- does that (FIX-CTLD-LANGUAGE). Only the languages CTLD actually ships are listed, because the
  -- override has to refuse a language the engine cannot speak rather than make ctld.tr() warn on
  -- every single string.
  i18n_lang = "en",
  i18n = { en = {}, fr = {}, es = {}, ko = {} },
}

-- CTLDConfig — the singleton `veaf.isCtldReady()` probes. `isLoaded` is the flag the real
-- `ctld.initialize()` raises once it has parsed the configuration, so it is what tells an engine
-- that was started apart from one still parked on `ctld.dontInitialize`. The mock starts it **true**
-- (the nominal case, so every existing CTLD test keeps exercising the code it was written for);
-- a test flips it to false to reach the other state, and dcs_mocks.reset() restores it.
CTLDConfig = {
  -- `settings` is the live table the engine's own getSetting consults *before* falling back to its
  -- embedded catalogue, which is what makes a mid-mission setSetting take effect. `enableHoverSlingload`
  -- starts **true**, the value CTLD ships, so a test reads the real default rather than a convenient one.
  _instance = {
    isLoaded = true,
    settings = { enableHoverSlingload = true },
    getSetting = function(self, key)
      return self.settings[key]
    end,
    setSetting = function(self, key, value)
      self.settings[key] = value
      return self
    end,
  },
  get = function()
    return CTLDConfig._instance
  end,
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

-- Update addGroup to include controller and category defaults
local _original_addGroup = dcs_mocks.addGroup
function dcs_mocks.addGroup(name, data)
  _original_addGroup(name, data)
  local g = _group_registry[name] -- already set by _original_addGroup
  if not g.getController then
    local _ctrl = {
      setCommand = function() end,
      pushTask = function() end,
      -- Recorded rather than dropped: replaceMission pushes a whole Mission task through setTask,
      -- and asserting what it contains is the only way to see an escort task being repaired.
      setTask = function(_self, task)
        table.insert(dcs_mocks.tasksSet, { group = name, task = task })
      end,
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

-- Group.getID(group) — the static form, which is what the escort-task repair uses: only this id is
-- the one DCS wants for an Escort task, and what a mission file stores does not correspond to it.
Group.getID = function(grp)
  return grp:getID()
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
