------------------------------------------------------------------
-- VEAF root script for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- * Contains all the constants and utility functions required by the other VEAF script libraries
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veaf = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the root VEAF constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veaf.Id = "VEAF"

--- Build stamp (veaf-tools package version + git sha) injected by the build pipeline via
--- the VEAF_BUILD_VERSION global, set before any framework file loads. Falls back to "dev"
--- when the scripts run unbuilt (hand-copied into a mission, or the Lua unit tests). This
--- is the single source of truth for "which code is running", logged once below.
veaf.BuildVersion = VEAF_BUILD_VERSION or "dev"

--- Development version ?
veaf.Development = false
veaf.SecurityDisabled = false

-- trace level, specific to this module
--veaf.LogLevel = "debug"
--veaf.LogLevel = "trace"
--veaf.ForcedLogLevel = "debug"

-- log level, limiting all the modules
veaf.BaseLogLevel = 3 --info

veaf.DEFAULT_GROUND_SPEED_KPH = 30

--- if true, the spawned group names will not contain any information pertaining to their type
veaf.HideNamesFromSpawnedGroups = true
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.config = {}
veaf.triggerZones = {}

--- Registry of modules that can be initialized via veaf.initialize().
--- Each entry: { initFn = function, order = number }
veaf.modules = {}

--- Flag set once veaf.initialize() has been called.
veaf._initialized = false

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Module configuration API
-- These functions are available immediately at load time (no loggers required).
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Return the configuration table for a module (empty table if none registered).
function veaf.getConfig(moduleId)
  return veaf.config[moduleId] or {}
end

--- Set a single configuration key for a module.
function veaf.setConfig(moduleId, key, value)
  if not veaf.config[moduleId] then
    veaf.config[moduleId] = {}
  end
  veaf.config[moduleId][key] = value
end

--- Return true if the module is enabled (default: true when no config exists).
function veaf.isEnabled(moduleId)
  local cfg = veaf.config[moduleId]
  if cfg == nil or cfg.enable == nil then
    return true
  end
  return cfg.enable
end

--- Register a module so that veaf.initialize() can initialize it.
--- @param id         string   — module identifier (e.g. veafSpawn.Id)
--- @param initFn     function — zero-argument wrapper calling the module's initialize()
--- @param defaults   table    — default config values merged into veaf.config[id]
--- @param order      number   — initialization order (lower = earlier, default 100)
function veaf.registerModule(id, initFn, defaults, order)
  -- Merge defaults into veaf.config[id], keeping values already set (e.g. by missionconfig.lua).
  if defaults then
    if not veaf.config[id] then
      veaf.config[id] = {}
    end
    for k, v in pairs(defaults) do
      if veaf.config[id][k] == nil then
        veaf.config[id][k] = v
      end
    end
  end
  -- Guarantee the enable key exists.
  if not veaf.config[id] then
    veaf.config[id] = {}
  end
  if veaf.config[id].enable == nil then
    veaf.config[id].enable = true
  end
  veaf.modules[id] = { initFn = initFn, order = order or 100 }
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------
veaf.theatreName = {
  Caucasus = "Caucasus",
  Nevada = "Nevada",
  Normandy = "Normandy",
  PersianGulf = "PersianGulf",
  TheChannel = "TheChannel",
  Syria = "Syria",
  MarianaIslands = "MarianaIslands",
  Falklands = "Falklands",
  Sinai = "SinaiMap",
  Kola = "Kola",
  Afghanistan = "Afghanistan",
}

veaf.ERA = {
  WW2 = "WW2",
  COLD_WAR = "COLD_WAR",
  MODERN = "MODERN",
}

veaf.config.era = veaf.ERA.MODERN -- default era

--- Default language for in-game messages (veaf.t). Overridden per mission by
--- `veaf.config.language`, emitted from mission.yaml's `mission.language`.
veaf.I18N_DEFAULT_LANGUAGE = "fr"
veaf.config.language = veaf.config.language or veaf.I18N_DEFAULT_LANGUAGE

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Mist database wrappers
-- Centralizes the main access points to mist.DBs to isolate modules from internal mist changes.
-- Note: direct mist.DBs access may still exist in some low-level or legacy code paths.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.mist = {}

--- Return the unit data table for a given unit name (from mist.DBs.unitsByName).
function veaf.mist.getUnitData(unitName)
  return mist.DBs.unitsByName[unitName]
end

--- Return the group data table for a given group name (from mist.DBs.groupsByName).
function veaf.mist.getGroupData(groupName)
  return mist.DBs.groupsByName[groupName]
end

--- Return true if the given unit name belongs to a human player (from mist.DBs.humansByName).
function veaf.mist.isHumanUnit(unitName)
  return mist.DBs.humansByName[unitName] ~= nil
end

--- Return the full unitsByName table (for iteration).
function veaf.mist.getAllUnitData()
  return mist.DBs.unitsByName
end

--- Return the full groupsByName table (for iteration).
function veaf.mist.getAllGroupData()
  return mist.DBs.groupsByName
end

--- Return the full humansByName table (for iteration).
function veaf.mist.getAllHumanUnitData()
  return mist.DBs.humansByName
end

--- Return the group data table for a given group id (from mist.DBs.groupsById).
function veaf.mist.getGroupById(groupId)
  return mist.DBs.groupsById[groupId]
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.EVENTMETA = {
  [world.event.S_EVENT_SHOT] = {
    Order = 1,
    Side = "I",
    Event = "OnEventShot",
    Text = "S_EVENT_SHOT",
  },
  [world.event.S_EVENT_HIT] = {
    Order = 1,
    Side = "T",
    Event = "OnEventHit",
    Text = "S_EVENT_HIT",
  },
  [world.event.S_EVENT_TAKEOFF] = {
    Order = 1,
    Side = "I",
    Event = "OnEventTakeoff",
    Text = "S_EVENT_TAKEOFF",
  },
  [world.event.S_EVENT_LAND] = {
    Order = 1,
    Side = "I",
    Event = "OnEventLand",
    Text = "S_EVENT_LAND",
  },
  [world.event.S_EVENT_CRASH] = {
    Order = -1,
    Side = "I",
    Event = "OnEventCrash",
    Text = "S_EVENT_CRASH",
  },
  [world.event.S_EVENT_EJECTION] = {
    Order = 1,
    Side = "I",
    Event = "OnEventEjection",
    Text = "S_EVENT_EJECTION",
  },
  [world.event.S_EVENT_REFUELING] = {
    Order = 1,
    Side = "I",
    Event = "OnEventRefueling",
    Text = "S_EVENT_REFUELING",
  },
  [world.event.S_EVENT_DEAD] = {
    Order = -1,
    Side = "I",
    Event = "OnEventDead",
    Text = "S_EVENT_DEAD",
  },
  [world.event.S_EVENT_PILOT_DEAD] = {
    Order = 1,
    Side = "I",
    Event = "OnEventPilotDead",
    Text = "S_EVENT_PILOT_DEAD",
  },
  [world.event.S_EVENT_BASE_CAPTURED] = {
    Order = 1,
    Side = "I",
    Event = "OnEventBaseCaptured",
    Text = "S_EVENT_BASE_CAPTURED",
  },
  [world.event.S_EVENT_MISSION_START] = {
    Order = 1,
    Side = "N",
    Event = "OnEventMissionStart",
    Text = "S_EVENT_MISSION_START",
  },
  [world.event.S_EVENT_MISSION_END] = {
    Order = 1,
    Side = "N",
    Event = "OnEventMissionEnd",
    Text = "S_EVENT_MISSION_END",
  },
  [world.event.S_EVENT_TOOK_CONTROL] = {
    Order = 1,
    Side = "N",
    Event = "OnEventTookControl",
    Text = "S_EVENT_TOOK_CONTROL",
  },
  [world.event.S_EVENT_REFUELING_STOP] = {
    Order = 1,
    Side = "I",
    Event = "OnEventRefuelingStop",
    Text = "S_EVENT_REFUELING_STOP",
  },
  [world.event.S_EVENT_BIRTH] = {
    Order = 1,
    Side = "I",
    Event = "OnEventBirth",
    Text = "S_EVENT_BIRTH",
  },
  [world.event.S_EVENT_HUMAN_FAILURE] = {
    Order = 1,
    Side = "I",
    Event = "OnEventHumanFailure",
    Text = "S_EVENT_HUMAN_FAILURE",
  },
  [world.event.S_EVENT_ENGINE_STARTUP] = {
    Order = 1,
    Side = "I",
    Event = "OnEventEngineStartup",
    Text = "S_EVENT_ENGINE_STARTUP",
  },
  [world.event.S_EVENT_ENGINE_SHUTDOWN] = {
    Order = 1,
    Side = "I",
    Event = "OnEventEngineShutdown",
    Text = "S_EVENT_ENGINE_SHUTDOWN",
  },
  [world.event.S_EVENT_PLAYER_ENTER_UNIT] = {
    Order = 1,
    Side = "I",
    Event = "OnEventPlayerEnterUnit",
    Text = "S_EVENT_PLAYER_ENTER_UNIT",
  },
  [world.event.S_EVENT_PLAYER_LEAVE_UNIT] = {
    Order = -1,
    Side = "I",
    Event = "OnEventPlayerLeaveUnit",
    Text = "S_EVENT_PLAYER_LEAVE_UNIT",
  },
  [world.event.S_EVENT_PLAYER_COMMENT] = {
    Order = 1,
    Side = "I",
    Event = "OnEventPlayerComment",
    Text = "S_EVENT_PLAYER_COMMENT",
  },
  [world.event.S_EVENT_SHOOTING_START] = {
    Order = 1,
    Side = "I",
    Event = "OnEventShootingStart",
    Text = "S_EVENT_SHOOTING_START",
  },
  [world.event.S_EVENT_SHOOTING_END] = {
    Order = 1,
    Side = "I",
    Event = "OnEventShootingEnd",
    Text = "S_EVENT_SHOOTING_END",
  },
  [world.event.S_EVENT_MARK_ADDED] = {
    Order = 1,
    Side = "I",
    Event = "OnEventMarkAdded",
    Text = "S_EVENT_MARK_ADDED",
  },
  [world.event.S_EVENT_MARK_CHANGE] = {
    Order = 1,
    Side = "I",
    Event = "OnEventMarkChange",
    Text = "S_EVENT_MARK_CHANGE",
  },
  [world.event.S_EVENT_MARK_REMOVED] = {
    Order = 1,
    Side = "I",
    Event = "OnEventMarkRemoved",
    Text = "S_EVENT_MARK_REMOVED",
  },
}

--[[ json.lua

Used from https://gist.github.com/tylerneylon/59f4bcf316be525b30ab with authorization

A compact pure-Lua JSON library.
The main functions are: json.stringify, json.parse.
## json.stringify:
This expects the following to be true of any tables being encoded:
 * They only have string or number keys. Number keys must be represented as
   strings in json; this is part of the json spec.
 * They are not recursive. Such a structure cannot be specified in json.
A Lua table is considered to be an array if and only if its set of keys is a
consecutive sequence of positive integers starting at 1. Arrays are encoded like
so: `[2, 3, false, "hi"]`. Any other type of Lua table is encoded as a json
object, encoded like so: `{"key1": 2, "key2": false}`.
Because the Lua nil value cannot be a key, and as a table value is considerd
equivalent to a missing key, there is no way to express the json "null" value in
a Lua table. The only way this will output "null" is if your entire input obj is
nil itself.
An empty Lua table, {}, could be considered either a json object or array -
it's an ambiguous edge case. We choose to treat this as an object as it is the
more general type.
To be clear, none of the above considerations is a limitation of this code.
Rather, it is what we get when we completely observe the json specification for
as arbitrary a Lua object as json is capable of expressing.
## json.parse:
This function parses json, with the exception that it does not pay attention to
\u-escaped unicode code points in strings.
It is difficult for Lua to return null as a value. In order to prevent the loss
of keys with a null value in a json string, this function uses the one-off
table value json.null (which is just an empty table) to indicate null values.
This way you can check if a value is null with the conditional
`val == json.null`.
If you have control over the data and are using Lua, I would recommend just
avoiding null values in your data to begin with.
--]]

veaf.json = {}

-- Internal functions.

local function kind_of(obj)
  if type(obj) ~= "table" then
    return type(obj)
  end
  local i = 1
  for _ in pairs(obj) do
    if obj[i] ~= nil then
      i = i + 1
    else
      return "table"
    end
  end
  if i == 1 then
    return "table"
  else
    return "array"
  end
end

local function escape_str(s)
  local in_char = { "\\", '"', "/", "\b", "\f", "\n", "\r", "\t" }
  local out_char = { "\\", '"', "/", "b", "f", "n", "r", "t" }
  for i, c in ipairs(in_char) do
    s = s:gsub(c, "\\" .. out_char[i])
  end
  return s
end

-- Returns pos, did_find; there are two cases:
-- 1. Delimiter found: pos = pos after leading space + delim; did_find = true.
-- 2. Delimiter not found: pos = pos after leading space;     did_find = false.
-- This throws an error if err_if_missing is true and the delim is not found.
local function skip_delim(str, pos, delim, err_if_missing)
  pos = pos + #str:match("^%s*", pos)
  if str:sub(pos, pos) ~= delim then
    if err_if_missing then
      error("Expected " .. delim .. " near position " .. pos)
    end
    return pos, false
  end
  return pos + 1, true
end

-- Expects the given pos to be the first character after the opening quote.
-- Returns val, pos; the returned pos is after the closing quote character.
local function parse_str_val(str, pos, val)
  val = val or ""
  local early_end_error = "End of input found while parsing string."
  if pos > #str then
    error(early_end_error)
  end
  local c = str:sub(pos, pos)
  if c == '"' then
    return val, pos + 1
  end
  if c ~= "\\" then
    return parse_str_val(str, pos + 1, val .. c)
  end
  -- We must have a \ character.
  local esc_map = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
  local nextc = str:sub(pos + 1, pos + 1)
  if not nextc then
    error(early_end_error)
  end
  return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
end

-- Returns val, pos; the returned pos is after the number's final character.
local function parse_num_val(str, pos)
  local num_str = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
  local val = tonumber(num_str)
  if not val then
    error("Error parsing number at position " .. pos .. ".")
  end
  return val, pos + #num_str
end

-- Public values and functions.

function veaf.json.stringify(obj, as_key)
  local s = {} -- We'll build the string as an array of strings to be concatenated.
  local kind = kind_of(obj) -- This is 'array' if it's an array or type(obj) otherwise.
  if kind == "array" then
    if as_key then
      error("Can't encode array as key.")
    end
    s[#s + 1] = "["
    for i, val in ipairs(obj) do
      if i > 1 then
        s[#s + 1] = ", "
      end
      s[#s + 1] = veaf.json.stringify(val)
    end
    s[#s + 1] = "]"
  elseif kind == "table" then
    if as_key then
      error("Can't encode table as key.")
    end
    s[#s + 1] = "{"
    for k, v in pairs(obj) do
      if #s > 1 then
        s[#s + 1] = ", "
      end
      s[#s + 1] = veaf.json.stringify(k, true)
      s[#s + 1] = ":"
      s[#s + 1] = veaf.json.stringify(v)
    end
    s[#s + 1] = "}"
  elseif kind == "string" then
    return '"' .. escape_str(obj) .. '"'
  elseif kind == "number" then
    if as_key then
      return '"' .. tostring(obj) .. '"'
    end
    return tostring(obj)
  elseif kind == "boolean" then
    return tostring(obj)
  elseif kind == "nil" then
    return "null"
  else
    return '"Unjsonifiable type: ' .. kind .. '."'
    --error('Unjsonifiable type: ' .. kind .. '.')
  end
  return table.concat(s)
end

veaf.json.null = {} -- This is a one-off table to represent the null value.

function veaf.json.parse(str, pos, end_delim)
  pos = pos or 1
  if pos > #str then
    error("Reached unexpected end of input.")
  end
  local pos = pos + #str:match("^%s*", pos) -- Skip whitespace.
  local first = str:sub(pos, pos)
  if first == "{" then -- Parse an object.
    local obj, key, delim_found = {}, true, true
    pos = pos + 1
    while true do
      -- not my code !
      ---@diagnostic disable-next-line: cast-local-type
      key, pos = veaf.json.parse(str, pos, "}")
      if key == nil then
        return obj, pos
      end
      if not delim_found then
        error("Comma missing between object items.")
      end
      pos = skip_delim(str, pos, ":", true) -- true -> error if missing.
      -- not my code !
      ---@diagnostic disable-next-line: need-check-nil
      obj[key], pos = veaf.json.parse(str, pos)
      pos, delim_found = skip_delim(str, pos, ",")
    end
  elseif first == "[" then -- Parse an array.
    local arr, val, delim_found = {}, true, true
    pos = pos + 1
    while true do
      -- not my code !
      ---@diagnostic disable-next-line: cast-local-type
      val, pos = veaf.json.parse(str, pos, "]")
      if val == nil then
        return arr, pos
      end
      if not delim_found then
        error("Comma missing between array items.")
      end
      arr[#arr + 1] = val
      pos, delim_found = skip_delim(str, pos, ",")
    end
  elseif first == '"' then -- Parse a string.
    return parse_str_val(str, pos + 1)
  elseif first == "-" or first:match("%d") then -- Parse a number.
    return parse_num_val(str, pos)
  elseif first == end_delim then -- End of an object or array.
    return nil, pos + 1
  else -- Parse true, false, or null.
    local literals = { ["true"] = true, ["false"] = false, ["null"] = veaf.json.null }
    for lit_str, lit_val in pairs(literals) do
      local lit_end = pos + #lit_str - 1
      if str:sub(pos, lit_end) == lit_str then
        return lit_val, lit_end + 1
      end
    end
    local pos_info_str = "position " .. pos .. ": " .. str:sub(pos, pos + 10)
    error("Invalid json syntax starting at " .. pos_info_str)
  end
end

local escapeChars = nil
---Escapes a string so it can no longer be a pattern (regex)
---@param stringToEscape string
---@return string
function veaf.escapeRegex(stringToEscape)
  local regexCharsToEscape = "^$()%.[]*+-?"
  if not escapeChars then
    escapeChars = {}
    for i = 1, string.len(regexCharsToEscape) do
      local char = string.sub(regexCharsToEscape, i, i)
      escapeChars[char] = true
    end
  end

  local result = ""
  if stringToEscape then
    for i = 1, string.len(stringToEscape) do
      local char = string.sub(stringToEscape, i, i)
      if escapeChars[char] then
        result = result .. "%"
      end
      result = result .. char
    end
  end
  return result
end

--- efficiently remove elements from a table
--- credit : Mitch McMabers (https://stackoverflow.com/questions/12394841/safely-remove-items-from-an-array-table-while-iterating)
function veaf.arrayRemoveWhen(t, fnKeep)
  local pristine = true
  local j, n = 1, #t
  for i = 1, n do
    if fnKeep(t, i, j) then
      if i ~= j then
        -- Keep i's value, move it to j's pos.
        t[j] = t[i]
        t[i] = nil
      else
        -- Keep i's value, already at j's pos.
      end
      j = j + 1
    else
      t[i] = nil
      pristine = false
    end
  end
  return not pristine
end

function veaf.vecToString(vec)
  local result = ""
  if vec.x then
    result = result .. string.format(" x=%.1f", vec.x)
  end
  if vec.y then
    result = result .. string.format(" y=%.1f", vec.y)
  end
  if vec.z then
    result = result .. string.format(" z=%.1f", vec.z)
  end
  return result
end

function veaf.discoverMetadata(o)
  local text = ""
  for key, value in pairs(getmetatable(o)) do
    text = text .. " - " .. key .. "\n"
  end
  return text
end

function veaf.serialize(name, value, level)
  -- mostly based on slMod serializer

  local function _basicSerialize(s)
    if s == nil then
      return '""'
    else
      if (type(s) == "number") or (type(s) == "boolean") or (type(s) == "function") or (type(s) == "table") or (type(s) == "userdata") then
        return tostring(s)
      elseif type(s) == "string" then
        return string.format("%q", s)
      end
    end
  end

  -----Based on ED's serialize_simple2
  local basicSerialize = function(o)
    if type(o) == "number" then
      return tostring(o)
    elseif type(o) == "boolean" then
      return tostring(o)
    else -- assume it is a string
      return _basicSerialize(o)
    end
  end

  local function _sortNumberOrCaseInsensitive(a, b)
    if type(a) == "string" or type(b) == "string" then
      return string.lower(a) < string.lower(b)
    else
      return a < b
    end
  end

  local serialize_to_t = function(name, value, level)
    ----Based on ED's serialize_simple2

    local var_str_tbl = {}
    if level == nil then
      level = ""
    end
    if level ~= "" then
      level = level .. "  "
    end

    table.insert(var_str_tbl, level .. name .. " = ")

    if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
      table.insert(var_str_tbl, basicSerialize(value) .. ",\n")
    elseif type(value) == "table" then
      table.insert(var_str_tbl, "{\n")
      local tkeys = {}
      -- populate the table that holds the keys
      for k in pairs(value) do
        table.insert(tkeys, k)
      end
      -- sort the keys
      table.sort(tkeys, _sortNumberOrCaseInsensitive)
      -- use the keys to retrieve the values in the sorted order
      for _, k in ipairs(tkeys) do -- serialize its fields
        local v = value[k]
        local key
        if type(k) == "number" then
          key = string.format("[%s]", k)
        else
          key = string.format("[%q]", k)
        end

        table.insert(var_str_tbl, veaf.serialize(key, v, level .. "  "))
      end
      if level == "" then
        table.insert(var_str_tbl, level .. "} -- end of " .. name .. "\n")
      else
        table.insert(var_str_tbl, level .. "}, -- end of " .. name .. "\n")
      end
    else
      veaf.loggers.get(veaf.Id):error("Cannot serialize a " .. type(value))
    end
    return var_str_tbl
  end

  local t_str = serialize_to_t(name, value, level)

  return table.concat(t_str)
end

function veaf.ifnn(o, field)
  if o then
    if o[field] then
      if type(o[field]) == "function" then
        local sta, res = pcall(o[field], o)
        if sta then
          return res
        else
          return nil
        end
      else
        return o[field]
      end
    end
  else
    return nil
  end
end

function veaf.ifnns(o, fields)
  local result = nil
  if o then
    result = {}
    if type(fields) ~= "table" then
      local field = fields
      fields = { field }
    end
    for _, field in pairs(fields) do
      if o[field] then
        if type(o[field]) == "function" then
          local sta, res = pcall(o[field], o)
          if sta then
            result[field] = res
          else
            result[field] = nil
          end
        else
          result[field] = o[field]
        end
      end
    end
  end
  return result
end

function veaf.isNullOrEmpty(s)
  return (s == nil or (type(s) == "string" and s == ""))
end

function veaf.tableContains(table, element)
  if table == nil or element == nil then
    return false
  end

  for _, e in pairs(table) do
    if e == element then
      return true
    end
  end
  return false
end

--- Convert a numeric enum value to its string name using a mapping table.
-- @param value the numeric value to convert
-- @param mapping a table of { [numericValue] = "STRING_NAME" }
-- @return the string name, or an empty string if not found
function veaf.enumToString(value, mapping)
  if value == nil or mapping == nil then
    return ""
  end
  return mapping[value] or ""
end

function veaf.lp(value, level, skip, includeMeta, dontRecurse)
  return setmetatable({ _v = value, _level = level, _skip = skip, _includeMeta = includeMeta, _dontRecurse = dontRecurse }, {
    __tostring = function(self)
      return veaf.p(self._v, self._level, self._skip, self._includeMeta, self._dontRecurse)
    end,
  })
end

function veaf.p(o, level, skip, includeMeta, dontRecurse)
  local _mt = getmetatable(o)
  if _mt and _mt.__tostring then
    return _mt.__tostring(o)
  end
  -- VMR-084: the `#o == 3` / `#o == 2` tests these conditions used to carry could never be true.
  -- `#` measures a table's *sequence* part, and a coordinate holds only the named keys x/y/z, so
  -- `#o` is 0 — the branch was dead and every vec3 fell through to the multi-line generic dump.
  if o and type(o) == "table" and (o.x and o.z and o.y) then
    return string.format("{x=%s, z=%s, y=%s}", veaf.p(o.x), veaf.p(o.z), veaf.p(o.y))
  elseif o and type(o) == "table" and (o.x and o.y) then
    return string.format("{x=%s, y=%s}", veaf.p(o.x), veaf.p(o.y))
  end
  local skip = skip
  if skip and type(skip) == "table" then
    for _, value in ipairs(skip) do
      skip[value] = true
    end
  end
  return veaf._p(o, level, skip, includeMeta, dontRecurse)
end

function veaf._p(o, level, skip, includeMeta, dontRecurse)
  local MAX_LEVEL = 20
  if level == nil then
    level = 0
  end
  if level > MAX_LEVEL then
    veaf.loggers.get(veaf.Id):error("max depth reached in veaf.p : " .. tostring(MAX_LEVEL))
    return ""
  end
  local text = ""
  if o == nil then
    text = "[nil]"
  elseif (type(o) == "table") and not dontRecurse then
    text = "\n"
    local keys = {}
    local values = {}
    for key, value in pairs(o) do
      local sKey = tostring(key)
      table.insert(keys, sKey)
      values[sKey] = value
    end
    table.sort(keys)
    for _, key in pairs(keys) do
      local value = values[key]
      for i = 0, level do
        text = text .. " "
      end
      if not (skip and skip[key]) then
        text = text .. "." .. key .. "=" .. veaf.p(value, level + 1, skip, includeMeta, dontRecurse) .. "\n"
      else
        text = text .. "." .. key .. "= [[SKIPPED]]\n"
      end
    end
    if includeMeta then
      local metatable = getmetatable(o)
      if metatable then
        text = "\n"
        local keys = {}
        local values = {}
        for key, value in pairs(metatable) do
          local sKey = tostring(key)
          table.insert(keys, sKey)
          values[sKey] = value
        end
        table.sort(keys)
        for _, key in pairs(keys) do
          local value = values[key]
          for i = 0, level do
            text = text .. " "
          end
          if not (skip and skip[key]) then
            if key == "getID" then
              value = o:getID()
            elseif key == "getName" then
              value = o:getName()
            elseif key == "getTypeName" then
              value = o:getTypeName()
            elseif key == "getDesc" then
              value = o:getDesc()
            end
            text = text .. "[META]." .. key .. "=" .. veaf.p(value, level + 1, skip, includeMeta, true) .. "\n"
          else
            text = text .. "[META]." .. key .. "= [[SKIPPED]]\n"
          end
        end
      end
    end
  elseif type(o) == "function" then
    text = "[function]"
  elseif type(o) == "boolean" then
    if o == true then
      text = "[true]"
    else
      text = "[false]"
    end
  else
    text = tostring(o)
  end
  return text
end

function veaf.length(T)
  local count = 0
  if T ~= nil then
    for _ in pairs(T) do
      count = count + 1
    end
  end
  return count
end

--- Simple round
function veaf.round(num, numDecimalPlaces)
  local mult = 10 ^ (numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

--- shuffle a table elements around
function veaf.shuffle(tbl)
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end

--- Return the height of the land at the coordinate.
function veaf.getLandHeight(vec3)
  veaf.loggers.get(veaf.Id):trace(string.format("getLandHeight: vec3  x=%.1f y=%.1f, z=%.1f", vec3.x, vec3.y, vec3.z))
  local vec2 = { x = vec3.x, y = vec3.z }
  veaf.loggers.get(veaf.Id):trace(string.format("getLandHeight: vec2  x=%.1f z=%.1f", vec3.x, vec3.z))
  -- We add 1 m "safety margin" because data from getlandheight gives the surface and wind at or below the surface is zero!
  local height = math.floor(land.getHeight(vec2) + 1)
  veaf.loggers.get(veaf.Id):trace(string.format("getLandHeight: result  height=%.1f", height))
  return height
end

function veaf.invertHeading(heading)
  veaf.loggers.get(veaf.Id):trace(string.format("invertHeading(%s)", veaf.p(heading)))
  local result = heading - 180
  if result <= 0 then
    result = result + 360
  end
  return result
end

function veaf.compute2dAzimuth(vec3)
  if vec3 == nil or (vec3.x == 0 and vec3.z == 0) then
    return 0
  end
  local iAngleRadian = math.atan2(vec3.z, vec3.x) -- get azimuth angle in radians from the vector (x=north, z=east in DCS coordinates)
  local iAngleDegrees = math.deg(iAngleRadian)
  if iAngleDegrees < 0 then
    iAngleDegrees = iAngleDegrees + 360
  end
  return iAngleDegrees
end

function veaf.compute2dMagnitude(vec3)
  if vec3 == nil then
    return 0
  end
  return math.sqrt(vec3.x ^ 2 + vec3.z ^ 2)
end

-- get a LL position based on a string
-- can be UTM (U38TMP334456 or u37TMP4351)
-- can be LL with either : or - as a separator, and either DMS, DM decimal, or D decimal (N42:23:45E044-12.5 or N42.3345E044-12.5)
function veaf.computeLLFromString(value)
  local function _computeLLValueFromString(value)
    local result = -1
    if value:find(":") or value:find("-") then
      -- convert in arc-seconds
      local values = veaf.splitWithPattern(value, "[:-]+")
      local weights = { 3600, 60, 1 }
      for _, element in pairs(values) do
        veaf.loggers.get(veaf.Id):trace(string.format("element=%s", veaf.p(element)))
        local weight = table.remove(weights, 1)
        local elementInArcSec = tonumber(element) * weight
        result = result + elementInArcSec
      end
      return result / 3600
    else
      -- decimals
      return tonumber(value)
    end
  end

  if value then
    local _value = value:lower()
    local _firstChar = _value:sub(1, 1)
    if _firstChar == "u" then
      -- UTM coordinates
      local _zone, _digraph, _digits = _value:match("u(%d%d[a-z])([a-z][a-z])(%d+)")
      veaf.loggers.get(veaf.Id):trace(string.format("_zone=%s", veaf.p(_zone)))
      veaf.loggers.get(veaf.Id):trace(string.format("_digraph=%s", veaf.p(_digraph)))
      veaf.loggers.get(veaf.Id):trace(string.format("_digits=%s", veaf.p(_digits)))
      if _zone and _digraph and _digits then
        local _nDigits = #_digits
        local _northingString = _digits:sub(_nDigits / 2 + 1)
        local _northing = tonumber(_northingString)
        veaf.loggers.get(veaf.Id):trace(string.format("_northing=%s", veaf.p(_northing)))
        if #_northingString == 1 then
          _northing = _northing * 10000
        elseif #_northingString == 2 then
          _northing = _northing * 1000
        elseif #_northingString == 3 then
          _northing = _northing * 100
        elseif #_northingString == 4 then
          _northing = _northing * 10
        end

        local _eastingString = _digits:sub(1, _nDigits / 2)
        local _easting = tonumber(_eastingString)
        veaf.loggers.get(veaf.Id):trace(string.format("_easting=%s", veaf.p(_easting)))
        if #_eastingString == 1 then
          _easting = _easting * 10000
        elseif #_eastingString == 2 then
          _easting = _easting * 1000
        elseif #_eastingString == 3 then
          _easting = _easting * 100
        elseif #_eastingString == 4 then
          _easting = _easting * 10
        end

        local _utm = { UTMZone = _zone:upper(), MGRSDigraph = _digraph:upper(), Easting = _easting, Northing = _northing }
        veaf.loggers.get(veaf.Id):trace(string.format("_utm=%s", veaf.p(_utm)))
        return coord.MGRStoLL(_utm)
      end
    elseif _firstChar == "n" or _firstChar == "s" or _firstChar == "e" or _firstChar == "w" then
      -- LL coordinates
      local _signLat, _digitsLat, _signLon, _digitsLon = _value:match([[([news])([%d:\.-]+)([news])([%d:\.-]+)]])
      if _digitsLat and _digitsLon then
        local _multLat = 1
        if _signLat == "s" then
          _multLat = -1
        end
        local _multLon = 1
        if _signLon == "w" then
          _multLon = -1
        end
        local _lat = _multLat * _computeLLValueFromString(_digitsLat)
        local _lon = _multLon * _computeLLValueFromString(_digitsLon)
        return _lat, _lon
      end
    end
  end
  -- unrecognized format
  return nil
end

function veaf.findDcsAirbase(name)
  local dcsAirbase = Airbase.getByName(name)
  if dcsAirbase then
    return dcsAirbase
  end

  -- Remove "AIRBASE " prefix if it exists (case insensitive)
  name = name:gsub("^[Aa][Ii][Rr][Bb][Aa][Ss][Ee]%s+", "")

  -- Helper function to normalize strings
  local function normalize(s)
    -- Convert to lowercase
    s = s:lower()
    -- Remove spaces and punctuation
    s = s:gsub("[%s%p]", "")
    return s
  end

  name = normalize(name)

  local airBases = world.getAirbases()
  for i = 1, #airBases do
    dcsAirbase = airBases[i]
    local sAirbaseName = dcsAirbase:getName()
    -- Normalize each list item
    sAirbaseName = normalize(sAirbaseName)

    -- Compare normalized strings
    if sAirbaseName == name then
      return dcsAirbase
    end
  end

  return nil
end

function veaf.silenceAtcOnAllAirbases()
  local bases = world.getAirbases()
  for _, base in pairs(bases) do
    if base:getDesc() then
      if base:getDesc().category == Airbase.Category.AIRDROME then
        veaf.loggers.get(veaf.Id):info("silencing ATC at base %s", veaf.p(base:getDesc().displayName))
        base:setRadioSilentMode(true)
      end
    end
  end
end

--- Return a point at the same coordinates, but on the surface
function veaf.placePointOnLand(vec3)
  -- convert a vec2 to a vec3
  if not vec3.z then
    vec3.z = vec3.y
    vec3.y = 0
  end

  if not vec3.y then
    vec3.y = 0
  end

  veaf.loggers.get(veaf.Id):trace(string.format("getLandHeight: vec3  x=%.1f y=%.1f, z=%.1f", vec3.x, vec3.y, vec3.z))
  local height = veaf.getLandHeight(vec3)
  veaf.loggers.get(veaf.Id):trace(string.format("getLandHeight: result  height=%.1f", height))
  local result = { x = vec3.x, y = height, z = vec3.z }
  veaf.loggers.get(veaf.Id):trace(string.format("placePointOnLand: result  x=%.1f y=%.1f, z=%.1f", result.x, result.y, result.z))
  return result
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- spawn point search
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Number of candidate points examined per search tier in veaf.findSpawnPoint
veaf.SPAWN_SEARCH_ATTEMPTS = 10

--- Default clearance from scenery, in metres, requested for a spawned group
veaf.DEFAULT_SPAWN_CLEARANCE = 100

--- Set to true to skip the scenery-aware tier of veaf.findSpawnPoint
veaf.doNotAvoidScenery = false

--- Places a candidate on the terrain and tells whether a ground unit can stand there
-- Placing first normalises vec2 and vec3 inputs, so the surface test always has a z.
-- Only WATER is rejected, which is the criterion veafUnits.checkPositionForUnit applies
-- to a ground unit — SHALLOW_WATER keeps passing, as it does today.
-- The shape guard is not paranoia: tier 1 candidates come from an undocumented API whose
-- return shape we have not measured, and veaf.placePointOnLand would raise on a non-table
-- — outside the pcall, which only wraps the call to the singleton itself.
-- @return vec3 placed on land, or nil when the candidate is unusable
local function acceptableGroundPoint(candidate)
  if type(candidate) ~= "table" then
    return nil
  end
  local placed = veaf.placePointOnLand(candidate)
  if land.getSurfaceType({ x = placed.x, y = placed.z }) ~= land.SurfaceType.WATER then
    return placed
  end
  return nil
end

--- Horizontal distance between two points, either of which may be a vec2
-- A vec2's y is the map's z, which is the convention veaf.placePointOnLand applies. Reading
-- it as an altitude instead is how a distance test ends up comparing the wrong axis.
-- Horizontal on purpose: placePointOnLand writes the terrain height into y, so measuring in
-- three dimensions would let a hill push a perfectly good candidate out of range.
local function horizontalDistance(a, b)
  local dx = (a.x or 0) - (b.x or 0)
  local dz = (a.z or a.y or 0) - (b.z or b.y or 0)
  return math.sqrt(dx * dx + dz * dz)
end

--- Searches for an acceptable ground spawn point near a centre
-- Three bounded tiers, degrading in order: every criterion including clearance from
-- scenery, then every criterion except that clearance, then failure. Callers used to
-- jitter once and use the result unvalidated, so a centre could land in the sea and the
-- units were dropped one by one downstream.
-- @param vec3 centre point
-- @param radius search radius in metres — honoured by **every** tier, see below
-- @param safeRadius required clearance from scenery (default veaf.DEFAULT_SPAWN_CLEARANCE)
-- @return vec3 placed on land, or nil when no acceptable point was found
function veaf.findSpawnPoint(vec3, radius, safeRadius)
  safeRadius = safeRadius or veaf.DEFAULT_SPAWN_CLEARANCE

  -- Tier 1 — every criterion, clearance from buildings and forests included.
  -- Disposition is a native but *undocumented* DCS singleton, found in TUM. Measured in a live
  -- DCS on 2026-08-06: it exists, and the points it returns genuinely avoid buildings and
  -- forests (.backlog/FEAT-SCENERY-AWARE-SPAWN/tickets/01-probe-disposition.md). The guard and
  -- the pcall stay: a singleton absent on another DCS version or map, or whose signature
  -- changes under us, must degrade to tier 2 and never kill a spawn.
  --
  -- A zero radius means "exactly here, the mission maker means it" — veafSpawn passes it for
  -- farp, cargo, teleport, bomb, smoke and friends. Tier 1 exists to *move* a point, so it must
  -- not even be consulted.
  if not veaf.doNotAvoidScenery and radius and radius > 0 and Disposition and Disposition.getSimpleZones then
    -- One call yields several candidates, which is cheaper than one call each and matters
    -- because the per-call cost is still unmeasured.
    local ok, candidates = pcall(Disposition.getSimpleZones, vec3, radius, safeRadius, veaf.SPAWN_SEARCH_ATTEMPTS)
    if ok and type(candidates) == "table" then
      for _, candidate in ipairs(candidates) do
        local placed = acceptableGroundPoint(candidate)
        -- The distance test is not belt-and-braces: **Disposition's radius argument does not
        -- bound its answers.** Measured around one centre in wooded terrain — asked for 800 m
        -- it returned points 2035-2258 m out, and asked for 1600 m with a count of *one* it
        -- still returned a point 2628 m out, so the overshoot is not the count forcing a wider
        -- search. Without this test tier 1 took the first candidate that was merely on land, so
        -- `_spawn group, radius 50` in a forest could place the group kilometres away in
        -- silence. ADR 0018 requires this dependency to be quality-only and never correctness.
        if placed and horizontalDistance(placed, vec3) <= radius then
          veaf.loggers.get(veaf.Id):trace("findSpawnPoint: scenery-aware point found")
          return placed
        end
      end
      veaf.loggers.get(veaf.Id):debug("findSpawnPoint: Disposition proposed no usable point in range, dropping the scenery criterion")
    else
      veaf.loggers.get(veaf.Id):debug("findSpawnPoint: Disposition.getSimpleZones unusable, dropping the scenery criterion")
    end
  end

  -- Tier 2 — every criterion except clearance from scenery.
  for _ = 1, veaf.SPAWN_SEARCH_ATTEMPTS do
    local placed = acceptableGroundPoint(mist.getRandPointInCircle(vec3, radius))
    if placed then
      return placed
    end
  end

  -- Tier 3 — nothing acceptable anywhere. The caller reports it and aborts the spawn.
  veaf.loggers
    .get(veaf.Id)
    :info(string.format("findSpawnPoint: no acceptable spawn point within %sm of %s", tostring(radius), veaf.vecToString(vec3)))
  return nil
end

--- Trim a string
function veaf.trim(s)
  local a = s:match("^%s*()")
  local b = s:match("()%s*$", a)
  return s:sub(a, b - 1)
end

--- Split string. C.f. http://stackoverflow.com/questions/1426954/split-string-in-lua
function veaf.splitWithPattern(str, pat)
  local t = {} -- NOTE: use {n = 0} in Lua-5.0
  local fpat = "(.-)" .. pat
  local last_end = 1
  local s, e, cap = str:find(fpat, 1)
  while s do
    if s ~= 1 or cap ~= "" then
      table.insert(t, cap)
    end
    last_end = e + 1
    s, e, cap = str:find(fpat, last_end)
  end
  if last_end <= #str then
    cap = str:sub(last_end)
    table.insert(t, cap)
  end
  return t
end

--- Escape a separator so it is literal inside a Lua pattern.
---
--- VMR-082: `veaf.split` and `veaf.breakString` interpolate the separator straight into a
--- character class, so a Lua-magic separator changes what the class means. Measured rather than
--- assumed: `-` and `]` happen to survive, but `%` raises *malformed pattern* outright. Every
--- separator used inside this repository is a comma, a space or a semicolon — all harmless — but
--- both functions are public API and a mission can pass anything.
local function _escapePattern(sep)
  return (tostring(sep):gsub("(%W)", "%%%1"))
end

function veaf.split(str, sep)
  local result = {}
  local regex = ("([^%s]+)"):format(_escapePattern(sep))
  for each in str:gmatch(regex) do
    table.insert(result, each)
  end
  return result
end

--- Break string around a separator
function veaf.breakString(str, sep)
  local escaped = _escapePattern(sep)
  local regex = ("^([^%s]+)%s(.*)$"):format(escaped, escaped)
  local a, b = str:match(regex)
  if not a then
    a = str
  end
  local result = { a, b }
  return result
end

--- Get the average center of a group position (average point of all units position)
function veaf.getAveragePosition(group)
  if type(group) == "string" then
    group = Group.getByName(group)
  end

  local count

  local totalPosition = { x = 0, y = 0, z = 0 }
  if group then
    local units = Group.getUnits(group)
    for count = 1, #units do
      if units[count] then
        totalPosition = mist.vec.add(totalPosition, Unit.getPosition(units[count]).p)
      end
    end
    if #units > 0 then
      return mist.vec.scalar_mult(totalPosition, 1 / #units)
    else
      return nil
    end
  else
    return nil
  end
end

function veaf.emptyFunction() end

function veaf.getMagneticDeclination()
  local nDeclination = 0
  local sTheatre = string.lower(env.mission.theatre)

  if sTheatre == "caucasus" then
    nDeclination = 6
  elseif sTheatre == "persiangulf" then
    nDeclination = 2
  elseif sTheatre == "nevada" then
    nDeclination = 12
  elseif sTheatre == "normandy" then
    nDeclination = -10
  elseif sTheatre == "thechannel" then
    nDeclination = -10
  elseif sTheatre == "syria" then
    nDeclination = 5
  elseif sTheatre == "marianaislands" then
    nDeclination = 2
  elseif sTheatre == "falklands" then
    nDeclination = 12
  elseif sTheatre == "sinaimap" then
    nDeclination = 4.8
  elseif sTheatre == "kola" then
    nDeclination = 15
  elseif sTheatre == "afghanistan" then
    nDeclination = 3
  end

  return nDeclination
end

--- Returns the wind direction (from) and strength.
function veaf.getWind(point)
  -- Get wind velocity vector.
  local windvec3 = atmosphere.getWind(point)
  local direction = math.floor(math.deg(math.atan2(windvec3.z, windvec3.x)))

  if direction < 0 then
    direction = direction + 360
  end

  -- Convert TO direction to FROM direction.
  if direction > 180 then
    direction = direction - 180
  else
    direction = direction + 180
  end

  -- Calc 2D strength.
  local strength = math.floor(math.sqrt(windvec3.x ^ 2 + windvec3.z ^ 2))

  -- Debug output.
  veaf.loggers.get(veaf.Id):trace(string.format("Wind data: point x=%.1f y=%.1f, z=%.1f", point.x, point.y, point.z))
  veaf.loggers.get(veaf.Id):trace(string.format("Wind data: wind  x=%.1f y=%.1f, z=%.1f", windvec3.x, windvec3.y, windvec3.z))
  veaf.loggers.get(veaf.Id):trace(string.format("Wind data: |v| = %.1f", strength))
  veaf.loggers.get(veaf.Id):trace(string.format("Wind data: ang = %.1f", direction))

  -- Return wind direction and strength (in m/s).
  return direction, strength, windvec3
end

---comment
---@param mach number the mach number
---@param altitude any in feet, defaults to 10000
---@param temperature any in celsius, defaults to ISA temperature at altitude
function veaf.convertMachSpeed(mach, altitude, temperature)
  return veaf.convertSpeeds(mach, nil, nil, altitude, temperature)
end

---comment
---@param ktas number the true airspeed in knots
---@param altitude any in feet, defaults to 10000
---@param temperature any in celsius, defaults to ISA temperature at altitude
function veaf.convertTrueAirSpeed(ktas, altitude, temperature)
  return veaf.convertSpeeds(nil, nil, ktas, altitude, temperature)
end

---comment
---@param kias number the indicated airspeed in knots
---@param altitude any in feet, defaults to 10000
---@param temperature any in celsius, defaults to ISA temperature at altitude
function veaf.convertIndicatedAirSpeed(kias, altitude, temperature)
  return veaf.convertSpeeds(nil, kias, nil, altitude, temperature)
end

---Computes speeds based on a speed parameter (mach, tas, ias) and altitude/temperature
---@param mach number? the mach number
---@param kias number? the indicated airspeed in knots
---@param ktas number? the true airspeed in knots
---@param altitude any in meters, defaults to 10000
---@param temperature any in celsius, defaults to ISA temperature at altitude
---@param pressure any in pa, defaults to ISA temperature at altitude
---@return table result containing KTAS, KIAS, Mach, IAS_ms and TAS_ms
function veaf.convertSpeeds(mach, kias, ktas, altitude, temperature, pressure)
  veaf.loggers.get(veaf.Id):debug(
    "veaf.convertSpeeds(mach=%s, kias=%s, ktas=%s, altitude=%s, temperature=%s, pressure=%s) -> initial",
    veaf.lp(mach),
    veaf.lp(kias),
    veaf.lp(ktas),
    veaf.lp(altitude),
    veaf.lp(temperature),
    veaf.lp(pressure)
  )

  local result = {
    KTAS = 0,
    KIAS = 0,
    Mach = 0,
  }

  local h_tropopause = 11000 --m, tropopause start altitude<

  local altitude = altitude
  if not altitude then
    altitude = 10000 -- default to 10000m
  end

  local T0 = 288.15 --K, ISA+0 altitude, may need to be corrected for mission ground temp
  local Tz = -0.0065 --K/m, ISA temperature gradient in troposphere
  local T_tropopause = 216.65 --K, temperature at the border between tropopause and troposphere (temperature in the tropopause)
  local P0 = 101325 --Pa, standard pressure
  local Gamma = 1.4 --Air heat capacity ratio
  local r = 287.03 --J/kg/K Perfect Gas constant for air
  local g = 9.81 --m/s^2 gravity constant on earth, might need to account for which planet ED is on

  local temperature = temperature
  if not temperature then
    -- compute ISA temperature based on altitude
    if altitude < h_tropopause then
      temperature = T0 + Tz * altitude --troposphere (temp in K)
    else
      temperature = T_tropopause --tropopause (max altitude 20000m) (temp in K)
    end
  else
    temperature = temperature + 273.15 --conversion to Kelvin
  end

  local function P_troposphere(temperature)
    return P0 * (1 + (temperature - T0) / T0) ^ (-g / (r * Tz))
  end

  local pressure = pressure
  if not pressure then
    -- compute pressure based on altitude and ISA temperature
    if altitude < h_tropopause then
      pressure = P_troposphere(temperature)
    else
      pressure = P_troposphere(T_tropopause) * math.exp(-g * (altitude - h_tropopause) / (r * T_tropopause))
    end
  end

  ---comment
  ---@param temperature number temperature in K
  ---@return number speed of sound in m/s
  local function speedOfSound(temperature)
    return math.sqrt(Gamma * r * temperature)
  end

  local B = Gamma / (Gamma - 1)

  ---comment
  ---@param mach number mach number to calculate (Pt-Ps)/Ps with Pt/Ps given by isentropic relations (NOTE : (Pt-Ps)=deltaP)
  ---@return number returns the ratio deltaP/P (DPP) (what a pitot tube would measure for M<1)
  local function isentropicDPP(mach)
    return (1 + (Gamma - 1) * mach ^ 2 / 2) ^ B - 1
  end

  ---comment
  ---@param mach number mach number to calculate (Pt-Ps)/Ps after a normal shock (M>1) (NOTE : (Pt-Ps)=deltaP)
  ---@return number returns the ratio deltaP/P (DPP) after the normal shock (what a pitot tube would measure for M>1)
  local function lord_rayleighDPP(mach)
    local A = ((Gamma + 1) * mach ^ 2 / 2) ^ B
    local C = ((Gamma + 1) / (2 * Gamma * mach ^ 2 - Gamma + 1)) ^ (B / Gamma)
    return A * C - 1
  end

  ---comment
  ---@param mach1 number the starting mach (mach_0 or mach_p) which determines the deltaP/P1 being computed (for a pitot tube at sea level, subscript 0 (IAS) or at altitude (TAS), subscript p)
  ---@param getTAS boolean? if true, switches to conversion mode from IAS to TAS
  ---@return number so if you provide only mach_P (TAS), this will return mach_0 (IAS), and if you provide mach_0 and getTAS true (IAS), this will return mach_P (TAS)
  local function getConvertedMach(mach1, getTAS)
    veaf.loggers.get(veaf.Id):debug("getConvertedMach(mach1 = %s, getTAS = %s", veaf.lp(mach1), veaf.lp(getTAS))

    local DPP1 = 0
    if mach1 > 1 then
      DPP1 = lord_rayleighDPP(mach1) --At this point it's still deltaP / Pp (DPPP) (subscript p = at pitot tube, subscript 0 = at sea level)
    else
      DPP1 = isentropicDPP(mach1) --At this point it's still deltaP / Pp (DPPP) (subscript p = at pitot tube, subscript 0 = at sea level)
    end

    veaf.loggers.get(veaf.Id):debug("DPP1 = %s -> initial", veaf.lp(DPP1))

    if getTAS then
      DPP1 = P0 * DPP1 / pressure --conversion from DPP0 to DPPP
    else
      DPP1 = pressure * DPP1 / P0 --conversion from DPPP to DPP0
    end

    veaf.loggers.get(veaf.Id):debug("DPP1 = %s -> final", veaf.lp(DPP1))

    local mach2 = 1

    local function converge_2_DPP(machStep)
      while lord_rayleighDPP(mach2) < DPP1 do --DPP2 = lord_rayleighDPP(mach2)
        mach2 = mach2 + machStep
      end

      return mach2
    end

    if DPP1 > lord_rayleighDPP(1) then
      mach2 = converge_2_DPP(0.25) - 0.25 --coarse
      veaf.loggers.get(veaf.Id):debug("coarse mach2 = %s", veaf.lp(mach2))
      mach2 = converge_2_DPP(0.0125) - 0.0125 --medium
      veaf.loggers.get(veaf.Id):debug("medium mach2 = %s", veaf.lp(mach2))
      mach2 = converge_2_DPP(0.00625) --fine
      veaf.loggers.get(veaf.Id):debug("fine mach2 = %s", veaf.lp(mach2))
    else
      mach2 = math.sqrt(2 * ((DPP1 + 1) ^ (1 / B) - 1) / (Gamma - 1))
      veaf.loggers.get(veaf.Id):debug("subsonic mach2 = %s", veaf.lp(mach2))
    end

    return mach2
  end

  local ms_2_kt = 1.94384
  local a1 = speedOfSound(temperature)
  local a0 = speedOfSound(T0)
  veaf.loggers.get(veaf.Id):debug("a0 = %s, a1 = %s", veaf.lp(a0), veaf.lp(a1))

  if mach then
    -- compute speeds from mach number
    result.Mach = mach

    result.TAS_ms = mach * a1
    result.KTAS = result.TAS_ms * ms_2_kt

    result.IAS_ms = getConvertedMach(result.Mach) * a0
    result.KIAS = result.IAS_ms * ms_2_kt
  elseif kias then
    -- compute speeds from ias
    result.KIAS = kias
    result.IAS_ms = result.KIAS / ms_2_kt

    result.TAS_ms = getConvertedMach(result.IAS_ms / a0, true) * a1
    result.KTAS = result.TAS_ms * ms_2_kt

    result.Mach = result.TAS_ms / a1
  elseif ktas then
    -- compute speeds from tas
    result.KTAS = ktas
    result.TAS_ms = result.KTAS / ms_2_kt

    result.Mach = result.TAS_ms / a1

    result.IAS_ms = getConvertedMach(result.Mach) * a0
    result.KIAS = result.IAS_ms * ms_2_kt
  end

  veaf.loggers.get(veaf.Id):debug(
    "veaf.convertSpeeds(mach=%s, kias=%s, ktas=%s, altitude=%s, temperature=%s, pressure=%s) -> final",
    veaf.lp(result.Mach),
    veaf.lp(result.KIAS),
    veaf.lp(result.KTAS),
    veaf.lp(altitude),
    veaf.lp(temperature),
    veaf.lp(pressure)
  )

  return result
end

--- Find a suitable point for spawning a unit in a <dispersion>-sized circle around a spot
function veaf.findPointInZone(spawnSpot, dispersion, isShip)
  local unitPosition
  local tryCounter = 1000
  local dispersion = dispersion or 0
  local _dispersion = dispersion
  repeat -- Place the unit in a "dispersion" ft radius circle from the spawn spot
    unitPosition = mist.getRandPointInCircle(spawnSpot, _dispersion)
    local landType = land.getSurfaceType(unitPosition)
    tryCounter = tryCounter - 1
    _dispersion = _dispersion + dispersion
  until (
      (isShip and landType == land.SurfaceType.WATER)
      or (not isShip and (landType == land.SurfaceType.LAND or landType == land.SurfaceType.ROAD or landType == land.SurfaceType.RUNWAY))
    ) or tryCounter == 0
  if tryCounter == 0 then
    return nil
  else
    return unitPosition
  end
end

---Fixes a table of mixed units and unit names and returns a table of DCS units
---@param unitsOrNames table a list of units, unit names, or a mix
---@return table the DCS units
function veaf.fixUnitsTable(unitsOrNames)
  local units = {}
  for _, unitOrName in pairs(unitsOrNames) do
    local unit = nil
    if type(unitOrName) == "table" then
      -- already an unit
      unit = unitOrName
    elseif type(unitOrName) == "string" then
      -- find by name
      unit = Unit.getByName(unitOrName) or StaticObject.getByName(unitOrName)
    end
    if unit then
      table.insert(units, unit)
    end
  end
  return units
end

---checks if a unit is in a trigger zone
---@param unitOrName any a DCS unit or an unit name
---@param zoneOrName any a DCS trigger zone or a trigger zone name (any type)
---@return boolean true if the unit is in the trigger zone
function veaf.isUnitInZone(unitOrName, zoneOrName)
  local unitIsInZone = false
  local unit = nil
  if unitOrName then
    if type(unitOrName) == "table" then
      -- already an unit
      unit = unitOrName
    elseif type(unitOrName) == "string" then
      -- find by name
      unit = Unit.getByName(unitOrName) or StaticObject.getByName(unitOrName)
    end
  end

  local zone = nil
  if zoneOrName then
    if type(zoneOrName) == "table" then
      -- already a DCS zone
      zone = zoneOrName
    elseif type(zoneOrName) == "string" then
      -- find by name
      zone = veaf.getTriggerZone(zoneOrName)
    end
  end
  if zone and unit then
    local unitPosition = unit:getPosition().p
    local objectCategory = Object.getCategory(unit)
    if unitPosition and ((objectCategory == 1 and unit:isActive() == true) or objectCategory ~= 1) then -- it is a unit and is active or it is not a unit
      if zone.verticies then
        local pointInPolygon = mist.pointInPolygon(unitPosition, zone.verticies)
        if pointInPolygon then
          unitIsInZone = true
        end
      else
        if ((unitPosition.x - zone.x) ^ 2 + (unitPosition.z - zone.y) ^ 2) ^ 0.5 <= zone.radius then
          unitIsInZone = true
        end
      end
    end
  end
  return unitIsInZone
end

--- TODO doc
function veaf.generateVehiclesRoute(startPoint, destination, onRoad, speed, patrol, groupName)
  veaf.loggers.get(veaf.Id):trace(
    string.format(
      "veaf.generateVehiclesRoute(onRoad=[%s], speed=[%s], patrol=[%s])",
      tostring(onRoad or ""),
      tostring(speed or ""),
      tostring(patrol or "")
    )
  )

  speed = speed or veaf.DEFAULT_GROUND_SPEED_KPH
  onRoad = onRoad or false
  patrol = patrol or false
  veaf.loggers.get(veaf.Id):trace(string.format("startPoint = {x = %d, y = %d, z = %d}", startPoint.x, startPoint.y, startPoint.z))
  local action = "Diamond"
  if onRoad then
    action = "On Road"
  end

  local endPoint = veafNamedPoints.getPoint(destination)
  if not endPoint then
    -- check if these are coordinates
    local _lat, _lon = veaf.computeLLFromString(destination)
    veaf.loggers.get(veaf.Id):trace(string.format("_lat=%s", veaf.p(_lat)))
    veaf.loggers.get(veaf.Id):trace(string.format("_lon=%s", veaf.p(_lon)))
    if _lat and _lon then
      endPoint = coord.LLtoLO(_lat, _lon)
    end
  end
  if not endPoint then
    local msg = veaf.t("spawn.point_not_found", destination)
    veaf.loggers.get(veaf.Id):warn(msg)
    trigger.action.outText(msg, 5)
    return
  end
  veaf.loggers.get(veaf.Id):trace(string.format("endPoint=%s", veaf.p(endPoint)))

  local road_x = nil
  local road_z = nil
  local trueStartPoint = mist.utils.deepCopy(startPoint)
  if onRoad then
    veaf.loggers.get(veaf.Id):trace("setting startPoint on a road")
    road_x, road_z = land.getClosestPointOnRoads("roads", startPoint.x, startPoint.z)
    startPoint = veaf.placePointOnLand({ x = road_x, y = 0, z = road_z })
  else
    startPoint = veaf.placePointOnLand({ x = startPoint.x, y = 0, z = startPoint.z })
  end

  veaf.loggers.get(veaf.Id):trace(string.format("startPoint = {x = %d, y = %d, z = %d}", startPoint.x, startPoint.y, startPoint.z))

  local trueEndPoint = mist.utils.deepCopy(endPoint)
  if onRoad then
    veaf.loggers.get(veaf.Id):trace("setting endPoint on a road")
    road_x, road_z = land.getClosestPointOnRoads("roads", endPoint.x, endPoint.z)
    endPoint = veaf.placePointOnLand({ x = road_x, y = 0, z = road_z })
  else
    endPoint = veaf.placePointOnLand({ x = endPoint.x, y = 0, z = endPoint.z })
  end
  veaf.loggers.get(veaf.Id):trace(string.format("endPoint = {x = %d, y = %d, z = %d}", endPoint.x, endPoint.y, endPoint.z))

  local vehiclesRoute = {
    [1] = {
      ["x"] = trueStartPoint.x,
      ["y"] = trueStartPoint.z,
      ["alt"] = trueStartPoint.y,
      ["type"] = "Turning Point",
      ["ETA"] = 0,
      ["alt_type"] = "BARO",
      ["formation_template"] = "",
      ["name"] = "T_STA",
      ["ETA_locked"] = false,
      ["speed"] = 0,
      ["action"] = "Off Road",
      ["speed_locked"] = true,
    }, -- end of [1]
    [2] = {
      ["x"] = startPoint.x,
      ["y"] = startPoint.z,
      ["alt"] = startPoint.y,
      ["type"] = "Turning Point",
      ["ETA"] = 1,
      ["alt_type"] = "BARO",
      ["formation_template"] = "",
      ["name"] = "STA",
      ["ETA_locked"] = false,
      ["speed"] = speed / 3.6,
      ["action"] = action,
      ["speed_locked"] = false,
    }, -- end of [2]
    [3] = {
      ["x"] = endPoint.x,
      ["y"] = endPoint.z,
      ["alt"] = endPoint.y,
      ["type"] = "Turning Point",
      ["ETA"] = 2,
      ["alt_type"] = "BARO",
      ["formation_template"] = "",
      ["name"] = "END",
      ["ETA_locked"] = false,
      ["speed"] = speed / 3.6,
      ["action"] = action,
      ["speed_locked"] = true,
    }, -- end of [3]
  }

  if patrol then
    vehiclesRoute[4] = {
      ["x"] = startPoint.x,
      ["y"] = startPoint.z,
      ["alt"] = startPoint.y,
      ["type"] = "Turning Point",
      ["ETA"] = 3,
      ["alt_type"] = "BARO",
      ["formation_template"] = "",
      ["name"] = "STA2",
      ["ETA_locked"] = false,
      ["speed"] = speed / 3.6,
      ["action"] = action,
      ["task"] = {
        ["id"] = "ComboTask",
        ["params"] = {
          ["tasks"] = {}, -- end of ["tasks"]
        }, -- end of ["params"]
      }, -- end of ["task"]
      ["speed_locked"] = true,
    }

    veaf.PatrolWatchdog(groupName, vehiclesRoute, speed / 3.6, "notSeen")
  elseif onRoad then
    vehiclesRoute[4] = {
      ["x"] = trueEndPoint.x,
      ["y"] = trueEndPoint.z,
      ["alt"] = trueEndPoint.y,
      ["type"] = "Turning Point",
      ["ETA"] = 4,
      ["alt_type"] = "BARO",
      ["formation_template"] = "",
      ["name"] = "T_END",
      ["ETA_locked"] = false,
      ["speed"] = speed / 3.6,
      ["action"] = "Diamond",
      ["speed_locked"] = true,
    }
  end

  if not patrol then
    local endWaypoint = vehiclesRoute[4]
    if not onRoad then
      endWaypoint = vehiclesRoute[3]
    end

    endWaypoint.task = {}
    endWaypoint.task = {
      ["id"] = "ComboTask",
      ["params"] = {
        ["tasks"] = {
          [1] = {
            ["number"] = 1,
            ["auto"] = false,
            ["id"] = "WrappedAction",
            ["enabled"] = true,
            ["params"] = {
              ["action"] = {
                ["id"] = "Option",
                ["params"] = {
                  ["value"] = 2, --Alarm State RED
                  ["name"] = 9, --Alarm State
                }, -- end of ["params"]
              }, -- end of ["action"]
            }, -- end of ["params"]
          }, -- end of [1]
        }, -- end of ["tasks"]
      }, -- end of ["params"]
    }
  end
  veaf.loggers.get(veaf.Id):trace(string.format("vehiclesRoute = %s", veaf.p(vehiclesRoute)))

  return vehiclesRoute
end

function veaf.PatrolWatchdog(groupName, patrolRoute, speed, firstPass)
  veaf.loggers
    .get(veaf.Id)
    :debug(string.format("veaf.PatrolWatchdog(groupName=%s, speed=%s, firstPass=%s)", veaf.p(groupName), veaf.p(speed), veaf.p(firstPass)))
  veaf.loggers.get(veaf.Id):trace(string.format("patrolRoute=%s", veaf.p(patrolRoute)))

  local rescheduleTime = 30
  local maxDist = 10
  if firstPass then
    maxDist = 200
  end
  local startPoint = { x = patrolRoute[1].x, z = patrolRoute[1].y }

  local group = Group.getByName(groupName)
  if group then
    local controller = group:getController()
    if controller then
      veaf.loggers.get(veaf.Id):info("Checking if patrol is within " .. maxDist .. "m of it's start point...")

      local groupUnits = group:getUnits()

      if groupUnits and groupUnits[1] and groupUnits[1]:isActive() then
        local leadPos = groupUnits[1]:getPosition().p
        veaf.loggers.get(veaf.Id):trace(string.format("Lead vehicule name : %s", veaf.p(groupUnits[1]:getName())))
        veaf.loggers.get(veaf.Id):trace(string.format("Lead vehicule position : %s", veaf.p(leadPos)))

        if leadPos then
          local distanceToStart = (leadPos.x - startPoint.x) ^ 2 + (leadPos.z - startPoint.z) ^ 2
          local result = distanceToStart < maxDist ^ 2

          if firstPass == "notSeen" and result then
            firstPass = "seenOnce"
          elseif firstPass == "seenOnce" and not result then
            firstPass = false
          end

          if not firstPass and result then
            veaf.loggers.get(veaf.Id):info("Lead vehicle in range, setting route !")
            mist.goRoute(group, patrolRoute)
            controller:setSpeed(speed)
            firstPass = "notSeen"
          elseif firstPass then
            veaf.loggers.get(veaf.Id):debug("Lead vehicle is passing in the bubble, rescheduling in " .. rescheduleTime .. "s !")
          else
            veaf.loggers.get(veaf.Id):debug(
              "Lead vehicle/lead controller not found or lead vehicle not within "
                .. maxDist
                .. "m, rescheduling in "
                .. rescheduleTime
                .. "s !"
            )
          end

          mist.scheduleFunction(veaf.PatrolWatchdog, { groupName, patrolRoute, speed, firstPass }, timer.getTime() + rescheduleTime)
        end
      elseif not groupUnits[1]:isActive() then
        veaf.loggers.get(veaf.Id):debug("Lead vehicle not active, rescheduling in 60s !")
        mist.scheduleFunction(veaf.PatrolWatchdog, { groupName, patrolRoute, speed, firstPass }, timer.getTime() + 60)
      end
    end
  end

  veaf.loggers.get(veaf.Id):debug("========================================================================")
end

--- Add a unit to the <group> on a suitable point in a <dispersion>-sized circle around a spot
function veaf.addUnit(group, spawnSpot, dispersion, unitType, unitName, skill)
  local unitPosition = veaf.findPointInZone(spawnSpot, dispersion, false)
  if unitPosition ~= nil then
    table.insert(group, {
      ["x"] = unitPosition.x,
      ["y"] = unitPosition.y,
      ["type"] = unitType,
      ["name"] = unitName,
      ["heading"] = 0,
      ["skill"] = skill,
    })
  else
    veaf.loggers.get(veaf.Id):info("cannot find a suitable position for unit " .. unitType)
  end
end

--- Makes a group move to a waypoint set at a specific heading and at a distance covered at a specific speed in an hour
function veaf.moveGroupAt(groupName, leadUnitName, heading, speed, timeInSeconds, endPosition, pMiddlePointDistance)
  veaf.loggers.get(veaf.Id):debug(
    "veaf.moveGroupAt(groupName="
      .. groupName
      .. ", heading="
      .. heading
      .. ", speed="
      .. speed
      .. ", timeInSeconds="
      .. (timeInSeconds or 0)
  )

  local unitGroup = Group.getByName(groupName)
  if unitGroup == nil then
    veaf.loggers.get(veaf.Id):error("veaf.moveGroupAt: " .. groupName .. " not found")
    return false
  end

  local leadUnit = unitGroup:getUnits()[1]
  if leadUnitName then
    leadUnit = Unit.getByName(leadUnitName)
  end
  if leadUnit == nil then
    veaf.loggers.get(veaf.Id):error("veaf.moveGroupAt: " .. leadUnitName .. " not found")
    return false
  end

  local headingRad = mist.utils.toRadian(heading)
  veaf.loggers.get(veaf.Id):trace("headingRad=" .. headingRad)
  local fromPosition = leadUnit:getPosition().p
  ---@diagnostic disable-next-line: missing-fields
  fromPosition = { x = fromPosition.x, y = fromPosition.z }
  veaf.loggers.get(veaf.Id):trace("fromPosition=" .. veaf.vecToString(fromPosition))

  local mission = {
    id = "Mission",
    params = {
      ["communication"] = true,
      ["start_time"] = 0,
      route = {
        points = {
          -- first point
          [1] = {
            --["alt"] = 0,
            ["type"] = "Turning Point",
            --["formation_template"] = "Diamond",
            --["alt_type"] = "BARO",
            ["x"] = fromPosition.x,
            ["y"] = fromPosition.z,
            ["name"] = "Starting position",
            ["action"] = "Turning Point",
            ["speed"] = 9999, -- ahead flank
            ["speed_locked"] = true,
          }, -- end of [1]
        },
      },
    },
  }

  if pMiddlePointDistance then
    -- middle point (helps with having a more exact final bearing, specially with big hunks of steel like carriers)
    local middlePointDistance = 2000
    if pMiddlePointDistance then
      middlePointDistance = pMiddlePointDistance
    end

    local newWaypoint1 = {
      x = fromPosition.x + middlePointDistance * math.cos(headingRad),
      y = fromPosition.y + middlePointDistance * math.sin(headingRad),
    }
    fromPosition.x = newWaypoint1.x
    fromPosition.y = newWaypoint1.y
    veaf.loggers.get(veaf.Id):trace("newWaypoint1=" .. veaf.vecToString(newWaypoint1))

    table.insert(mission.params.route.points, {
      --["alt"] = 0,
      ["type"] = "Turning Point",
      --["formation_template"] = "Diamond",
      --["alt_type"] = "BARO",
      ["x"] = newWaypoint1.x,
      ["y"] = newWaypoint1.y,
      ["name"] = "Middle point",
      ["action"] = "Turning Point",
      ["speed"] = 9999, -- ahead flank
      ["speed_locked"] = true,
    })
  end

  local length
  if timeInSeconds then
    length = speed * timeInSeconds
  else
    length = speed * 3600 -- m travelled in 1 hour
  end
  veaf.loggers.get(veaf.Id):trace("length=" .. length .. " m")

  -- new route point
  local newWaypoint2 = {
    x = fromPosition.x + length * math.cos(headingRad),
    y = fromPosition.y + length * math.sin(headingRad),
  }
  veaf.loggers.get(veaf.Id):trace("newWaypoint2=" .. veaf.vecToString(newWaypoint2))

  table.insert(mission.params.route.points, {
    --["alt"] = 0,
    ["type"] = "Turning Point",
    --["formation_template"] = "Diamond",
    --["alt_type"] = "BARO",
    ["x"] = newWaypoint2.x,
    ["y"] = newWaypoint2.y,
    ["name"] = "",
    ["action"] = "Turning Point",
    ["speed"] = speed,
    ["speed_locked"] = true,
  })

  if endPosition then
    table.insert(mission.params.route.points, {
      --["alt"] = 0,
      ["type"] = "Turning Point",
      --["formation_template"] = "Diamond",
      --["alt_type"] = "BARO",
      ["x"] = endPosition.x,
      ["y"] = endPosition.z,
      ["name"] = "Back to starting position",
      ["action"] = "Turning Point",
      ["speed"] = 9999, -- ahead flank
      ["speed_locked"] = true,
    })
  end

  -- replace whole mission
  unitGroup:getController():setTask(mission)

  return true
end

veaf.defaultAlarmState = 2

function veaf.readyForCombat(group, alarm, disperseTime)
  veaf.loggers.get(veaf.Id):trace(string.format("group=%s, alarm=%s, disperseTime=%s", veaf.p(group), veaf.p(alarm), veaf.p(disperseTime)))
  if type(group) == "string" then
    group = Group.getByName(group)
  end
  if group then
    veaf.loggers.get(veaf.Id):trace("got group")

    local alarm = alarm
    if not alarm or alarm < 0 or alarm > 2 then
      alarm = veaf.defaultAlarmState
    end

    local disperseTime = disperseTime
    if not disperseTime or disperseTime < 0 then
      disperseTime = 0
    end

    local cont = group:getController()
    cont:setOnOff(true)
    cont:setOption(AI.Option.Ground.id.ALARM_STATE, alarm)
    cont:setOption(AI.Option.Ground.id.DISPERSE_ON_ATTACK, disperseTime) -- set disperse on attack according to the option
    cont:setOption(AI.Option.Air.id.ROE, AI.Option.Air.val.ROE.WEAPON_FREE) -- set fire at will
    cont:setOption(AI.Option.Ground.id.ROE, AI.Option.Air.val.ROE.WEAPON_FREE) -- set fire at will
    cont:setOption(AI.Option.Naval.id.ROE, AI.Option.Air.val.ROE.WEAPON_FREE) -- set fire at will
    cont:setOption(AI.Option.Ground.id.ENGAGE_AIR_WEAPONS, true) -- engage air-to-ground weapons with SAMs
  end
end

-- Makes a group move to a specific waypoint at a specific speed
function veaf.moveGroupTo(groupName, pos, speed, altitude)
  if not altitude then
    altitude = 0
  end
  veaf.loggers.get(veaf.Id):debug("veaf.moveGroupTo(groupName=" .. groupName .. ", speed=" .. speed .. ", altitude=" .. altitude)
  veaf.loggers.get(veaf.Id):debug("pos=" .. veaf.vecToString(pos))

  local unitGroup = Group.getByName(groupName)
  if unitGroup == nil then
    veaf.loggers.get(veaf.Id):error("veaf.moveGroupTo: " .. groupName .. " not found")
    return false
  end

  local route = {
    [1] = {
      ["alt"] = altitude,
      ["action"] = "Turning Point",
      ["alt_type"] = "BARO",
      ["speed"] = veaf.round(speed, 2),
      ["type"] = "Turning Point",
      ["x"] = pos.x,
      ["y"] = pos.z,
      ["speed_locked"] = true,
    },
    [2] = {
      ["alt"] = altitude,
      ["action"] = "Turning Point",
      ["alt_type"] = "BARO",
      ["speed"] = 0,
      ["type"] = "Turning Point",
      ["x"] = pos.x,
      ["y"] = pos.z,
      ["speed_locked"] = true,
    },
  }

  -- order group to new waypoint
  mist.goRoute(groupName, route)

  return true
end

function veaf.getAvgGroupPos(groupName) -- stolen from Mist and corrected
  local group = groupName -- sometimes this parameter is actually a group
  if type(groupName) == "string" and Group.getByName(groupName) and Group.getByName(groupName):isExist() == true then
    group = Group.getByName(groupName)
  end
  local units = {}
  for i = 1, group:getSize() do
    table.insert(units, group:getUnit(i):getName())
  end

  return mist.getAvgPos(units)
end

--- Computes the coordinates of a point offset from a route of a certain distance, at a certain distance from route start
--- e.g. we go from [startingPoint] to [destinationPoint], and at [distanceFromStartingPoint] we look at [offset] meters (left if <0, right else)
function veaf.computeCoordinatesOffsetFromRoute(startingPoint, destinationPoint, distanceFromStartingPoint, offset)
  veaf.loggers.get(veaf.Id):trace("startingPoint=" .. veaf.vecToString(startingPoint))
  veaf.loggers.get(veaf.Id):trace("destinationPoint=" .. veaf.vecToString(destinationPoint))

  local vecAB =
    { x = destinationPoint.x + -startingPoint.x, y = destinationPoint.y - startingPoint.y, z = destinationPoint.z - startingPoint.z }
  veaf.loggers.get(veaf.Id):trace("vecAB=" .. veaf.vecToString(vecAB))
  local alpha = math.atan2(vecAB.x, vecAB.z) -- atan2(y, x)
  veaf.loggers.get(veaf.Id):trace("alpha=" .. alpha)
  local r = math.sqrt(distanceFromStartingPoint * distanceFromStartingPoint + offset * offset)
  veaf.loggers.get(veaf.Id):trace("r=" .. r)
  local beta = math.atan(offset / distanceFromStartingPoint)
  veaf.loggers.get(veaf.Id):trace("beta=" .. beta)
  local tho = alpha + beta
  veaf.loggers.get(veaf.Id):trace("tho=" .. tho)
  local offsetPoint = { z = r * math.cos(tho) + startingPoint.z, y = 0, x = r * math.sin(tho) + startingPoint.x }
  veaf.loggers.get(veaf.Id):trace("offsetPoint=" .. veaf.vecToString(offsetPoint))
  local offsetPointOnLand = veaf.placePointOnLand(offsetPoint)
  veaf.loggers.get(veaf.Id):trace("offsetPointOnLand=" .. veaf.vecToString(offsetPointOnLand))

  return offsetPointOnLand, offsetPoint
end

function veaf.getBearingAndRangeFromTo(fromPoint, toPoint)
  veaf.loggers.get(veaf.Id):trace("fromPoint=" .. veaf.vecToString(fromPoint))
  veaf.loggers.get(veaf.Id):trace("toPoint=" .. veaf.vecToString(toPoint))

  local vec = { z = toPoint.z - fromPoint.z, x = toPoint.x - fromPoint.x }
  local angle = mist.utils.round(mist.utils.toDegree(mist.utils.getDir(vec)), 0)
  local distance = mist.utils.get2DDist(toPoint, fromPoint)
  return angle, distance, mist.utils.round(distance / 1000, 0), mist.utils.round(mist.utils.metersToNM(distance), 0)
end

function veaf.getGroupsOfCoalition(coa)
  local coalitions = { coalition.side.RED, coalition.side.BLUE, coalition.side.NEUTRAL }
  if coa then
    coalitions = { coa }
  end
  local allDcsGroups = {}
  for _, coa in pairs(coalitions) do
    local dcsGroups = coalition.getGroups(coa)
    for _, dcsGroup in pairs(dcsGroups) do
      table.insert(allDcsGroups, dcsGroup)
    end
  end
  return allDcsGroups
end

function veaf.getStaticsOfCoalition(coa)
  local coalitions = { coalition.side.RED, coalition.side.BLUE, coalition.side.NEUTRAL }
  if coa then
    coalitions = { coa }
  end
  local allDcsStatics = {}
  for _, coa in pairs(coalitions) do
    local dcsStatics = coalition.getStaticObjects(coa)
    for _, dcsStatic in pairs(dcsStatics) do
      table.insert(allDcsStatics, dcsStatic)
    end
  end
  return allDcsStatics
end

function veaf.getUnitsOfAllCoalitions(includeStatics)
  return veaf.getUnitsOfCoalition(includeStatics)
end

function veaf.getUnitsOfCoalition(includeStatics, coa)
  local allDcsUnits = {}
  local allDcsGroups = veaf.getGroupsOfCoalition(coa)
  for _, group in pairs(allDcsGroups) do
    for _, unit in pairs(group:getUnits()) do
      table.insert(allDcsUnits, unit)
    end
  end
  if includeStatics then
    local allDcsStatics = veaf.getStaticsOfCoalition(coa)
    for _, staticUnit in pairs(allDcsStatics) do
      table.insert(allDcsUnits, staticUnit)
    end
  end
  return allDcsUnits
end

function veaf.getUnitsNamesOfCoalition(includeStatics, coa)
  local allDcsUnits = {}
  local allDcsGroups = veaf.getGroupsOfCoalition(coa)
  for _, group in pairs(allDcsGroups) do
    for _, unit in pairs(group:getUnits()) do
      table.insert(allDcsUnits, unit:getName())
    end
  end
  if includeStatics then
    local allDcsStatics = veaf.getStaticsOfCoalition(coa)
    for _, staticUnit in pairs(allDcsStatics) do
      table.insert(allDcsUnits, StaticObject.getName(staticUnit))
    end
  end
  return allDcsUnits
end

function veaf.findUnitsInCircle(center, radius, includeStatics, onlyTheseUnits)
  veaf.loggers.get(veaf.Id):trace(string.format("findUnitsInCircle(radius=%s)", tostring(radius)))
  veaf.loggers.get(veaf.Id):trace(string.format("center=%s", veaf.p(center)))

  if not center then
    veaf.loggers.get(veaf.Id):error("veaf.findUnitsInCircle: center parameter is nil")
    return {}
  end

  local unitsToCheck = {}
  if onlyTheseUnits then
    for k = 1, #onlyTheseUnits do
      local unit = Unit.getByName(onlyTheseUnits[k]) or StaticObject.getByName(onlyTheseUnits[k])
      if unit then
        unitsToCheck[#unitsToCheck + 1] = unit
      end
    end
  else
    unitsToCheck = veaf.getUnitsOfAllCoalitions(includeStatics)
  end

  local result = {}
  for _, unit in pairs(unitsToCheck) do
    local pos = unit:getPosition().p
    if pos then -- you never know O.o
      local name = unit:getName()
      local distanceFromCenter = ((pos.x - center.x) ^ 2 + (pos.z - center.z) ^ 2) ^ 0.5
      veaf.loggers.get(veaf.Id):trace(string.format("name=%s; distanceFromCenter=%s", tostring(name), veaf.p(distanceFromCenter)))
      if distanceFromCenter <= radius then
        result[name] = unit
      end
    end
  end
  return result
end

--- modified version of mist.getGroupRoute that returns raw DCS group data
function veaf.getGroupData(groupIdent)
  -- refactor to search by groupId and allow groupId and groupName as inputs
  local gpId = groupIdent
  if mist.DBs.MEgroupsByName[groupIdent] then
    gpId = mist.DBs.MEgroupsByName[groupIdent].groupId
  else
    veaf.loggers.get(veaf.Id):info(groupIdent .. " not found in mist.DBs.MEgroupsByName")
  end

  for coa_name, coa_data in pairs(env.mission.coalition) do
    if (coa_name == "red" or coa_name == "blue") and type(coa_data) == "table" then
      if coa_data.country then --there is a country table
        for cntry_id, cntry_data in pairs(coa_data.country) do
          for obj_type_name, obj_type_data in pairs(cntry_data) do
            if obj_type_name == "helicopter" or obj_type_name == "ship" or obj_type_name == "plane" or obj_type_name == "vehicle" then -- only these types have points
              if
                (type(obj_type_data) == "table")
                and obj_type_data.group
                and (type(obj_type_data.group) == "table")
                and (#obj_type_data.group > 0)
              then --there's a group!
                for group_num, group_data in pairs(obj_type_data.group) do
                  if group_data and group_data.groupId == gpId then -- this is the group we are looking for
                    return group_data
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  veaf.loggers.get(veaf.Id):info(" no group data found for " .. groupIdent)
  return nil
end

function veaf.findInTable(data, key)
  local result = nil
  if data then
    result = data[key]
  end
  if result then
    veaf.loggers.get(veaf.Id):trace(".findInTable found " .. key)
  end
  return result
end

function veaf.getTankerData(tankerGroupName)
  veaf.loggers.get(veaf.Id):trace("getTankerData " .. tankerGroupName)
  local result = nil
  local tankerData = veaf.getGroupData(tankerGroupName)
  if tankerData then
    result = {}
    -- find callsign
    local units = veaf.findInTable(tankerData, "units")
    if units and units[1] then
      local callsign = veaf.findInTable(units[1], "callsign")
      if callsign then
        local name = veaf.findInTable(callsign, "name")
        if name then
          result.tankerCallsign = name
        end
      end
    end

    -- find frequency
    local communication = veaf.findInTable(tankerData, "communication")
    if communication == true then
      local frequency = veaf.findInTable(tankerData, "frequency")
      if frequency then
        result.tankerFrequency = frequency
      end
    end
    local route = veaf.findInTable(tankerData, "route")
    local points = veaf.findInTable(route, "points")
    if points then
      veaf.loggers.get(veaf.Id):trace("found a " .. #points .. "-points route for tanker " .. tankerGroupName)
      for i, point in pairs(points) do
        veaf.loggers.get(veaf.Id):trace("found point #" .. i)
        local task = veaf.findInTable(point, "task")
        if task then
          local tasks = task.params.tasks
          if tasks then
            veaf.loggers.get(veaf.Id):trace("found " .. #tasks .. " tasks")
            for j, task in pairs(tasks) do
              veaf.loggers.get(veaf.Id):trace("found task #" .. j)
              if task.params then
                veaf.loggers.get(veaf.Id):trace("has .params")
                if task.params.action then
                  veaf.loggers.get(veaf.Id):trace("has .action")
                  if task.params.action.params then
                    veaf.loggers.get(veaf.Id):trace("has .params")
                    if task.params.action.params.channel then
                      veaf.loggers.get(veaf.Id):trace("has .channel")
                      veaf.loggers.get(veaf.Id):info("Found a TACAN task for tanker " .. tankerGroupName)
                      result.tankerTacanTask = task
                      result.tankerTacanChannel = task.params.action.params.channel
                      result.tankerTacanMode = task.params.action.params.modeChannel
                      break
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  return result
end

function veaf.getCarrierATCdata(carrierGroupName, carrierUnitName)
  veaf.loggers.get(veaf.Id):trace("getCarrierData Group: " .. carrierGroupName .. " Unit: " .. carrierUnitName)
  local result = nil
  local carrierData = veaf.getGroupData(carrierGroupName)
  if carrierData then
    result = {}
    -- find carrier unit within group and gather the information
    local units = veaf.findInTable(carrierData, "units")
    local carrierUnitId = nil
    if units then
      for _, unit in pairs(units) do
        if unit and unit.name and unit.name == carrierUnitName then
          --get the unit ID which will be used later when searching for ICLS etc. assigned to the carrier itself and get the tower freq/modulation data
          carrierUnitId = unit.unitId
          if carrierUnitId then
            if unit.frequency then
              local towerString = string.format("%.2f", unit.frequency / 1000000)
              local towerMod = "AM"
              if unit.modulation and unit.modulation == 1 then
                towerMod = "FM"
              end
              result.tower = towerString .. " " .. towerMod .. " (Check Freq. Plan)"
            end
          end
        end
      end
    end

    --if the carrier was found and is identifiable
    if carrierUnitId then
      --find programmed tasks for the carrier (ACLS, ICLS, etc.)
      local tasks = veaf.findInTable(carrierData, "tasks")
      if tasks then
        veaf.loggers
          .get(veaf.Id)
          :trace("found " .. #tasks .. " programmed tasks for carrier " .. carrierUnitName .. " in group " .. carrierGroupName)
        for i, task in pairs(tasks) do
          if task then
            veaf.loggers.get(veaf.Id):trace("found task #" .. i)
            if task.params then
              veaf.loggers.get(veaf.Id):trace("has .params")
              if task.params.action then
                local action = task.params.action
                veaf.loggers.get(veaf.Id):trace("has .action")
                if task.params.action.params then
                  local actionParams = task.params.action.params
                  veaf.loggers.get(veaf.Id):trace("action has .params")
                  if task.params.action.params.unitId and task.params.action.params.unitId == carrierUnitId then
                    veaf.loggers.get(veaf.Id):trace("programmed task is linked to carrier unit")

                    if action.id == "ActivateBeacon" and actionParams.channel then
                      veaf.loggers.get(veaf.Id):info("Found a programmed TACAN task for carrier group " .. carrierGroupName)
                      local channel = actionParams.channel
                      local mode = "X"
                      if actionParams.modeChannel and actionParams.modeChannel == "Y" then --should never happen for carriers
                        mode = "Y"
                      end
                      local callsign = "No Code"
                      if actionParams.callsign then
                        callsign = actionParams.callsign
                      end
                      result.tacan = channel .. mode .. " (" .. callsign .. ")"
                    elseif action.id == "ActivateICLS" and actionParams.channel then
                      veaf.loggers.get(veaf.Id):info("Found a programmed ICLS task for carrier group " .. carrierGroupName)
                      result.icls = actionParams.channel
                    elseif action.id == "ActivateLink4" and actionParams.frequency then
                      veaf.loggers.get(veaf.Id):info("Found a programmed Link4 task for carrier group " .. carrierGroupName)
                      result.link4 = string.format("%.2f" .. "MHz", actionParams.frequency / 1000000)
                    elseif action.id == "ActivateACLS" then
                      veaf.loggers.get(veaf.Id):info("Found a programmed ACLS task for carrier group " .. carrierGroupName)
                      result.acls = true
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  return result
end

--- Shows a message to a unit, its group, or everyone
-- The nil check is a floor under **every** caller, not a fix for one. `trigger.action.outText*`
-- raises on a nil message, so a caller with nothing to say produced a DCS scripting error from a
-- *display* call — which reads in `dcs.log` as a bug in whatever feature was talking, not as
-- "somebody passed nothing". That is how issue #302's crash survived its own fix: the guard was added
-- where the value is computed, and the nil simply travelled one level further. There are dozens of
-- callers here, so guarding them one at a time would leave the trap armed.
-- It **logs** rather than returning quietly: a caller reaching this has a defect, and silence is worse
-- than a crash for whoever has to diagnose it later.
function veaf.outTextForUnit(unitName, message, duration, forAllGroup)
  if message == nil or (type(message) == "string" and message:match("^%s*$")) then
    veaf.loggers.get(veaf.Id):warn("outTextForUnit: refusing an empty message (unit=%s)", veaf.p(unitName))
    return
  end

  local unitId = nil
  local groupId = nil
  if unitName then
    local unit = Unit.getByName(unitName)
    if unit then
      unitId = unit:getID()
      local group = unit:getGroup()
      if group then
        groupId = group:getID()
      end
    end
  end
  if unitId and not forAllGroup then
    trigger.action.outTextForUnit(unitId, message, duration)
  elseif groupId then
    trigger.action.outTextForGroup(groupId, message, duration)
  else
    trigger.action.outText(message, duration)
  end
end

function veaf.outTextForGroup(unitName, message, duration)
  return veaf.outTextForUnit(unitName, message, duration, true)
end

--- Surface a message to a pilot in-game (UXPILOT-FEEDBACK).
--- Thin, test-safe wrapper over trigger.action.outText: when a coalition is
--- given, the message is shown only to that coalition (e.g. the pilot who placed
--- a marker); otherwise it is shown to everyone.
--- @param message string the text to display
--- @param duration number|nil seconds to display (defaults to 15)
--- @param coalition number|nil optional coalition id to scope the message to
function veaf.reportToPilot(message, duration, coalition)
  duration = duration or 15
  if coalition then
    trigger.action.outTextForCoalition(coalition, message, duration)
  else
    trigger.action.outText(message, duration)
  end
end

--- The coalition that issued a command, normalized for pilot feedback.
--- Use this for messages addressed to whoever placed the marker / carried the
--- interpreter command (reportToPilot), NOT for deciding the side of spawned
--- units (see veaf.getOppositeCoalition). Returns the RED/BLUE side, or nil when
--- the requester is unknown/all (callers then fall back to an all-coalitions message).
--- @param event table the command event (has a `coalition` field)
--- @treturn number|nil coalition.side.RED / .BLUE, or nil
function veaf.getRequesterCoalition(event)
  local c = event and event.coalition
  if c == coalition.side.RED or c == coalition.side.BLUE then
    return c
  end
  return nil
end

--- The opposing coalition — the default side for units spawned from a marker.
--- A marker placed by one coalition spawns threats for the other by default
--- (RED→BLUE, BLUE→RED). Anything else (neutral/all) defaults to RED, preserving
--- the historical behaviour. Pass an explicit `side`/`country` to override.
--- @param c number a coalition.side value
--- @treturn number the opposite coalition.side
function veaf.getOppositeCoalition(c)
  if c == coalition.side.RED then
    return coalition.side.BLUE
  elseif c == coalition.side.BLUE then
    return coalition.side.RED
  else
    return coalition.side.RED
  end
end

--- Translate an in-game message key to the active language.
--- The active language is `veaf.config.language` (set from mission.yaml, default
--- `veaf.I18N_DEFAULT_LANGUAGE` = "fr"). The catalog (`veaf.i18nCatalog`) is
--- populated by veafI18n.lua. Fallback order: requested language → default
--- language → the key itself (so a missing entry never crashes a message).
--- Extra arguments are interpolated with string.format.
--- @param key string the catalog key (e.g. "marker.command_failed")
--- @param ... any optional string.format arguments
--- @treturn string the localized (and formatted) message
function veaf.t(key, ...)
  local lang = (veaf.config and veaf.config.language) or veaf.I18N_DEFAULT_LANGUAGE
  local entry = veaf.i18nCatalog and veaf.i18nCatalog[key]
  local text
  if entry then
    text = entry[lang] or entry[veaf.I18N_DEFAULT_LANGUAGE]
  end
  if not text then
    text = key
  end
  if select("#", ...) > 0 then
    local ok, formatted = pcall(string.format, text, ...)
    if ok then
      text = formatted
    else
      -- a placeholder/argument mismatch: keep the raw text but log it so the
      -- catalog entry can be fixed (rather than silently swallowing the error).
      veaf.loggers.get(veaf.Id):warn(string.format("veaf.t: format failed for key '%s': %s", tostring(key), tostring(formatted)))
    end
  end
  return text
end

--- Levenshtein edit distance between two strings (used for "did you mean?" hints).
--- @param a string
--- @param b string
--- @treturn number the number of single-character edits to turn a into b
function veaf.levenshtein(a, b)
  a = a or ""
  b = b or ""
  if a == b then
    return 0
  end
  if #a == 0 then
    return #b
  end
  if #b == 0 then
    return #a
  end
  local prev = {}
  for j = 0, #b do
    prev[j] = j
  end
  for i = 1, #a do
    local cur = { [0] = i }
    local ai = a:sub(i, i)
    for j = 1, #b do
      local cost = (ai == b:sub(j, j)) and 0 or 1
      cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
    end
    prev = cur
  end
  return prev[#b]
end

--- Find the closest match to `word` among `candidates`, within `maxDistance`.
--- @param word string the (case-insensitive) input
--- @param candidates table list of candidate strings
--- @param maxDistance number|nil maximum accepted distance (defaults to 3)
--- @treturn string|nil the nearest candidate, or nil if none is close enough
function veaf.nearestMatch(word, candidates, maxDistance)
  maxDistance = maxDistance or 3
  local best, bestDistance = nil, maxDistance + 1
  local lowered = (word or ""):lower()
  for _, candidate in pairs(candidates or {}) do
    local distance = veaf.levenshtein(lowered, tostring(candidate):lower())
    if distance < bestDistance then
      best, bestDistance = candidate, distance
    end
  end
  return best
end

local function _initializeCountriesAndCoalitions()
  veaf.countriesByCoalition = {}
  veaf.coalitionByCountry = {}
  veaf.countriesByName = {}
  veaf.countriesNamesById = {}

  local function _sortByImportance(c1, c2)
    local importantCountries = { ["usa"] = true, ["russia"] = true }
    local imp1 = c1 and importantCountries[c1:lower()] or false
    local imp2 = c2 and importantCountries[c2:lower()] or false
    if imp1 ~= imp2 then
      return imp1
    end
    return (c1 or "") < (c2 or "")
  end

  -- Populate from mist.DBs.units (countries that have pre-placed unit groups)
  for coalitionName, countries in pairs(mist.DBs.units) do
    coalitionName = coalitionName:lower()
    veaf.loggers.get(veaf.Id):trace("coalitionName=%s", veaf.lp(coalitionName))

    if not veaf.countriesByCoalition[coalitionName] then
      veaf.countriesByCoalition[coalitionName] = {}
    end
    veaf.loggers.get(veaf.Id):trace("countries=%s", veaf.lp(countries))
    for countryName, countryData in pairs(countries) do
      veaf.loggers.get(veaf.Id):trace("country=%s", veaf.lp(countryData))
      countryName = countryName:lower()
      table.insert(veaf.countriesByCoalition[coalitionName], countryName)
      veaf.coalitionByCountry[countryName] = coalitionName:lower()
      veaf.countriesByName[countryName] = countryData
      veaf.countriesNamesById[countryData.countryId] = countryName
    end
  end

  -- Supplement from DCS country/coalition APIs so that coalitions without any
  -- pre-placed units (common in dynamic-spawn missions) still have usable entries.
  -- country.id: UPPERCASE_NAME -> id (int)
  -- coalition.getCountryCoalition(id): id -> coalition.side (0/1/2)
  if country and country.id and coalition and coalition.getCountryCoalition then
    local sideToName = {
      [coalition.side.RED] = "red",
      [coalition.side.BLUE] = "blue",
      [coalition.side.NEUTRAL] = "neutral",
    }
    for countryUpperName, countryId in pairs(country.id) do
      local side = coalition.getCountryCoalition(countryId)
      local coalitionName = sideToName[side]
      if coalitionName then
        if not veaf.countriesByCoalition[coalitionName] then
          veaf.countriesByCoalition[coalitionName] = {}
        end
        local lowerName = countryUpperName:lower()
        if not veaf.coalitionByCountry[lowerName] then
          table.insert(veaf.countriesByCoalition[coalitionName], lowerName)
          veaf.coalitionByCountry[lowerName] = coalitionName
        end
      end
    end
  end

  -- Sort each coalition's country list with important countries first
  for _, countries in pairs(veaf.countriesByCoalition) do
    table.sort(countries, _sortByImportance)
  end

  veaf.loggers.get(veaf.Id):trace("veaf.countriesByCoalition=%s", veaf.lp(veaf.countriesByCoalition))
  veaf.loggers.get(veaf.Id):trace("veaf.coalitionByCountry=%s", veaf.lp(veaf.coalitionByCountry))
  veaf.loggers.get(veaf.Id):trace("veaf.countriesByName=%s", veaf.lp(veaf.countriesByName))
  veaf.loggers.get(veaf.Id):trace("veaf.countriesNamesById=%s", veaf.lp(veaf.countriesNamesById))
end

function veaf.getCountryId(countryName)
  veaf.loggers.get(veaf.Id):trace("veaf.getCountryId(%s)", veaf.lp(countryName))
  if not veaf.countriesByName then
    _initializeCountriesAndCoalitions()
  end
  local countryName = string.lower(countryName or "")
  local country = veaf.countriesByName[countryName]
  if country then
    return country.countryId
  else
    return 0
  end
end

function veaf.getCountryName(countryId)
  veaf.loggers.get(veaf.Id):trace("veaf.getCountryName(%s)", veaf.lp(countryId))
  if not veaf.coalitionByCountry then
    _initializeCountriesAndCoalitions()
  end
  local countryName = veaf.countriesNamesById[countryId]
  return countryName
end

function veaf.getCountryForCoalition(coalition)
  veaf.loggers.get(veaf.Id):trace("veaf.getCountryForCoalition(coalition=%s)", tostring(coalition))
  local coalitionId = coalition
  if not coalitionId then
    coalitionId = 1
  end

  local coalitionName = nil
  if type(coalitionId) == "number" then
    if coalitionId == 1 then
      coalitionName = "red"
    elseif coalitionId == 2 then
      coalitionName = "blue"
    else
      coalitionName = "neutral"
    end
  else
    coalitionName = tostring(coalitionId)
  end

  if coalitionName then
    coalitionName = coalitionName:lower()
  else
    return nil
  end

  if not veaf.countriesByCoalition then
    _initializeCountriesAndCoalitions()
  end

  return veaf.countriesByCoalition[coalitionName][1]
end

function veaf.getCoalitionForCountry(countryName, asNumber)
  veaf.loggers
    .get(veaf.Id)
    :trace(string.format("veaf.getCoalitionForCountry(countryName=%s, asNumber=%s)", tostring(countryName), tostring(asNumber)))

  if countryName then
    countryName = countryName:lower()
  else
    return nil
  end

  if not veaf.coalitionByCountry then
    _initializeCountriesAndCoalitions()
  end

  local result = veaf.coalitionByCountry[countryName]
  if asNumber then
    if result == "neutral" then
      result = 0
    end
    if result == "red" then
      result = 1
    end
    if result == "blue" then
      result = 2
    end
  end
  return result
end

function veaf.getAirbaseForCoalition(airbase_name, coa)
  local airbase = nil

  veaf.loggers
    .get(veaf.Id)
    :trace(string.format("veaf.getAirbaseforCoalition(airbase_name = %s, coa = %s)", veaf.p(airbase_name), veaf.p(coa)))
  if coa and airbase_name then
    if type(coa) == "string" then
      if coa:lower() == "red" then
        coa = coalition.side.RED
      elseif coa:lower() == "blue" then
        coa = coalition.side.BLUE
      end
    end
    veaf.loggers.get(veaf.Id):trace(string.format("final coalition is = %s", veaf.p(coa)))

    if (coa == coalition.side.RED or coa == coalition.side.BLUE) and type(airbase_name) == "string" then
      local temp = Airbase.getByName(airbase_name)
      veaf.loggers.get(veaf.Id):trace(string.format("Associed Airbase ID : %s", veaf.p(temp)))

      if temp then
        veaf.loggers.get(veaf.Id):trace(string.format("Associed Airbase Coalition : %s", veaf.p(temp:getCoalition())))
        if temp:getCoalition() == coa then
          veaf.loggers.get(veaf.Id):trace(string.format("The Airbase was found and is held by the correct coalition"))
          airbase = temp
        end
      end
    end
  end

  return airbase
end

veaf.AIRBASES_LIFE0 = {}
veaf.STANDARD_CARRIER_LIFE0 = 1000 --this fluctuates a lot from ship to ship, took the lowest
veaf.STANDARD_AIRBASE_LIFE0 = 3600
veaf.STANDARD_HELIPAD_LIFE0 = 10000000
veaf.STANDARD_BUILDING_LIFE0 = 3600

function veaf.loadAirbasesLife0()
  local airbases = world.getAirbases()
  veaf.loggers.get(veaf.Id):trace(string.format("Loading Life0 of airbases..."))

  for _, airbase in pairs(airbases) do
    local airbase_name = airbase:getName()
    veaf.loggers.get(veaf.Id):trace(string.format("Checking airbase named %s", veaf.p(airbase_name)))
    veaf.AIRBASES_LIFE0[airbase_name] = veaf.getAirbaseLife(airbase_name, false, true)

    if veaf.AIRBASES_LIFE0[airbase_name] == 0 then
      veaf.loggers.get(veaf.Id):trace(string.format("Returned Life0 is 0, discarding result"))
      veaf.AIRBASES_LIFE0[airbase_name] = nil
    end
  end
end

--This method is used to get the life of any airbase/FARP/Carrier/HeloCarrier etc. through it's unit name. You can choose to have the life returned as a percentage (0 to 1) and also to not automatically adjust/store the maximum lifes of the airbases you might check through loading = true (loading mode is used for the function veaf.loadAirbasesLife0())
--Beware that, some airbases do not posses a life or a life0 to calculate a percentage. This method will return -1 if so.
function veaf.getAirbaseLife(airbase_name, percentage, loading)
  veaf.loggers.get(veaf.Id):trace(
    "veaf.getAirbaseLife(airbase_name = %s, percentage = %s, loading = %s)",
    veaf.lp(airbase_name),
    veaf.lp(percentage),
    veaf.lp(loading)
  )

  local airbase_life = -1
  local airbase_life0 = -1

  if airbase_name and type(airbase_name) == "string" then
    local airbase = Airbase.getByName(airbase_name)
    veaf.loggers.get(veaf.Id):trace(string.format("Airbase ID : %s", veaf.p(airbase)))

    if airbase then
      local airbase_desc = airbase:getDesc()
      veaf.loggers.get(veaf.Id):trace(string.format("Airbase Desc : %s", veaf.p(airbase_desc)))

      if airbase_desc and airbase_desc.life and airbase_desc.attributes then
        airbase_life0 = veaf.AIRBASES_LIFE0[airbase_name]
        airbase_life = airbase_desc.life

        -- local AirbaseUnit = StaticObject.getByName(airbase_name)
        -- if AirbaseUnit then
        --     veaf.loggers.get(veaf.Id):trace(string.format("Got an AirbaseUnit through StaticObject.getByName(), associated life is %s", veaf.p(AirbaseUnit:getLife())))
        -- end

        if
          airbase_desc.attributes["AircraftCarrier"]
          or airbase_desc.attributes["Aircraft Carriers"]
          or airbase_desc.attributes["HelicopterCarrier"]
        then
          local AircraftCarrier_unit = Unit.getByName(airbase_name)
          veaf.loggers.get(veaf.Id):trace(string.format("Airbase is a Carrier Unit ID : %s", veaf.p(AircraftCarrier_unit)))

          if AircraftCarrier_unit then
            --airbase_life0 = AircraftCarrier_unit:getLife0()  --returns 0, thanks ED, had to load them at mission start to counter this issue
            if not airbase_life0 then
              airbase_life0 = veaf.STANDARD_CARRIER_LIFE0
              veaf.loggers
                .get(veaf.Id)
                :trace(string.format("Carrier doesn't have a Life0 stored yet, using default of %s", veaf.p(veaf.STANDARD_CARRIER_LIFE0)))
            end
            airbase_life = AircraftCarrier_unit:getLife()
            veaf.loggers.get(veaf.Id):trace(string.format("Carrier Life : %s", veaf.p(airbase_life)))
          end
        elseif airbase_desc.attributes["Helipad"] and not airbase_life0 then
          airbase_life0 = veaf.STANDARD_HELIPAD_LIFE0
          veaf.loggers
            .get(veaf.Id)
            :trace(string.format("Helipad doesn't have a Life0 stored yet, using default of %s", veaf.p(veaf.STANDARD_HELIPAD_LIFE0)))
        elseif airbase_desc.attributes["Airfields"] and not airbase_life0 then
          airbase_life0 = veaf.STANDARD_AIRBASE_LIFE0
          veaf.loggers
            .get(veaf.Id)
            :trace(string.format("Airfield doesn't have a Life0 stored yet, using default of %s", veaf.p(veaf.STANDARD_AIRBASE_LIFE0)))
        elseif airbase_desc.attributes["Buildings"] then
          local BuildingUnit = StaticObject.getByName(airbase_name)
          veaf.loggers.get(veaf.Id):trace(string.format("Airbase is a Building Unit ID : %s", veaf.p(BuildingUnit)))

          if BuildingUnit then
            if not airbase_life0 then
              airbase_life0 = veaf.STANDARD_BUILDING_LIFE0
              veaf.loggers
                .get(veaf.Id)
                :trace(string.format("Building doesn't have a Life0 stored yet, using default of %s", veaf.p(veaf.STANDARD_BUILDING_LIFE0)))
            end
            airbase_life = BuildingUnit:getLife()
            veaf.loggers.get(veaf.Id):trace(string.format("Building Life : %s", veaf.p(airbase_life)))
          else
            airbase_life0 = -1
            airbase_life = -1
            veaf.loggers.get(veaf.Id):trace(string.format("Building that is an airbase doesn't have any life data, discarding"))
          end
        elseif not airbase_life0 then
          if airbase_life > 0 then
            airbase_life0 = airbase_life
            veaf.loggers.get(veaf.Id):trace(string.format("Airbase category does not have a default life0 setting, using life instead"))
          else
            airbase_life = -1
            airbase_life0 = -1
            veaf.loggers
              .get(veaf.Id)
              :trace(string.format("Airbase category does not have a default life0 setting nor does it have a life, discarding"))
          end
        end

        veaf.loggers.get(veaf.Id):trace(string.format("Airbase Life : %s, Airbase Life0 : %s", veaf.p(airbase_life), veaf.p(airbase_life0)))
      end
    end
  end

  if airbase_life0 and airbase_life0 > 0 and airbase_life and airbase_life > 0 then
    local airbase_life_percentage = airbase_life / airbase_life0

    if not loading then
      --if the airbase life percentage is superior to 100%, there standard life0 chosen was obviously wrong and needs updating
      if airbase_life_percentage > 1 then
        airbase_life_percentage = 1
        veaf.AIRBASES_LIFE0[airbase_name] = airbase_life
        veaf.loggers.get(veaf.Id):trace(string.format("Storing Life0 = Life for airbase..."))
      elseif not veaf.AIRBASES_LIFE0[airbase_name] then
        veaf.AIRBASES_LIFE0[airbase_name] = airbase_life0
        veaf.loggers.get(veaf.Id):trace(string.format("Storing default Life0 for airbase type..."))
      end
    end

    if percentage then
      airbase_life = airbase_life_percentage
    end
  end

  veaf.loggers.get(veaf.Id):trace(
    string.format("Final Airbase (named %s) Life : %s, isPercentage = %s", veaf.p(airbase_name), veaf.p(airbase_life), veaf.p(percentage))
  )
  return airbase_life
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- mission restart at a certain hour of the day
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veaf._endMission(delay1, message1, delay2, message2, delay3, message3)
  veaf.loggers.get(veaf.Id):trace(
    "veaf._endMission(delay1=%s, message1=%s, delay2=%s, message2=%s, delay3=%s, message3=%s)",
    veaf.lp(delay1),
    veaf.lp(message1),
    veaf.lp(delay2),
    veaf.lp(message2),
    veaf.lp(delay3),
    veaf.lp(message3)
  )

  if not delay1 then
    -- no more delay, let's end this !
    trigger.action.outText(veaf.t("mission.ending"), 30)
    veaf.loggers.get(veaf.Id):info("ending mission")
    trigger.action.setUserFlag("666", 1)
  else
    -- show the message
    trigger.action.outText(message1, 30)
    -- schedule this function after "delay1" seconds
    veaf.loggers.get(veaf.Id):info(string.format("schedule veaf._endMission after %d seconds", delay1))
    mist.scheduleFunction(veaf._endMission, { delay2, message2, delay3, message3 }, timer.getTime() + delay1)
  end
end

function veaf._checkForEndMission(
  endTimeInSeconds,
  checkIntervalInSeconds,
  checkMessage,
  delay1,
  message1,
  delay2,
  message2,
  delay3,
  message3
)
  veaf.loggers.get(veaf.Id):trace(
    "veaf._checkForEndMission(endTimeInSeconds=%s, checkIntervalInSeconds=%s, checkMessage=%s, delay1=%s, message1=%s, delay2=%s, message2=%s, delay3=%s, message3=%s)",
    veaf.lp(endTimeInSeconds),
    veaf.lp(checkIntervalInSeconds),
    veaf.lp(checkMessage),
    veaf.lp(delay1),
    veaf.lp(message1),
    veaf.lp(delay2),
    veaf.lp(message2),
    veaf.lp(delay3),
    veaf.lp(message3)
  )

  veaf.loggers.get(veaf.Id):trace(string.format("timer.getAbsTime()=%d", timer.getAbsTime()))

  if timer.getAbsTime() >= endTimeInSeconds then
    veaf.loggers.get(veaf.Id):trace("calling veaf._endMission")
    veaf._endMission(delay1, message1, delay2, message2, delay3, message3)
  else
    -- output the message if specified
    if checkMessage then
      trigger.action.outText(checkMessage, 30)
    end
    -- schedule this function after a delay
    veaf.loggers.get(veaf.Id):trace(string.format("schedule veaf._checkForEndMission after %d seconds", checkIntervalInSeconds))
    mist.scheduleFunction(
      veaf._checkForEndMission,
      { endTimeInSeconds, checkIntervalInSeconds, checkMessage, delay1, message1, delay2, message2, delay3, message3 },
      timer.getTime() + checkIntervalInSeconds
    )
  end
end

function veaf.endMissionAt(
  endTimeHour,
  endTimeMinute,
  checkIntervalInSeconds,
  checkMessage,
  delay1,
  message1,
  delay2,
  message2,
  delay3,
  message3
)
  veaf.loggers.get(veaf.Id):trace(
    "veaf.endMissionAt(endTimeHour=%s, endTimeMinute=%s, checkIntervalInSeconds=%s, checkMessage=%s, delay1=%s, message1=%s, delay2=%s, message2=%s, delay3=%s, message3=%s)",
    veaf.lp(endTimeHour),
    veaf.lp(endTimeMinute),
    veaf.lp(checkIntervalInSeconds),
    veaf.lp(checkMessage),
    veaf.lp(delay1),
    veaf.lp(message1),
    veaf.lp(delay2),
    veaf.lp(message2),
    veaf.lp(delay3),
    veaf.lp(message3)
  )

  local endTimeInSeconds = endTimeHour * 3600 + endTimeMinute * 60
  veaf.loggers.get(veaf.Id):trace(string.format("endTimeInSeconds=%d", endTimeInSeconds))
  veaf._checkForEndMission(endTimeInSeconds, checkIntervalInSeconds, checkMessage, delay1, message1, delay2, message2, delay3, message3)
end

function veaf.randomlyChooseFrom(aTable, bias)
  veaf.loggers.get(veaf.Id):trace(string.format("randomlyChooseFrom(%d):%s", bias or 0, veaf.p(aTable)))
  if aTable == nil or #aTable == 0 then
    return nil
  elseif #aTable == 1 then
    return aTable[1]
  end
  local index = math.floor(math.random(1, #aTable)) + (bias or 0)
  if index < 1 then
    index = 1
  end
  if index > #aTable then
    index = #aTable
  end
  veaf.loggers.get(veaf.Id):trace(string.format("index = %s", veaf.p(index)))
  return aTable[index]
end

--- Convert a marker parameter to a number, never raising, optionally clamped.
---
--- SECREV-2 group A. Marker text is player input: a keyword can arrive with no value at all, or
--- with something that is not a number, and the handlers were converting it inline. Two crash
--- shapes came out of that repeatedly — `string.format("%d", nil)` on a valueless keyword, and
--- `tonumber(val) <= 5`, which compares nil with a number and takes the whole handler down.
---
--- The review asked for this to live in "the shared marker parser". There is no such thing: ten
--- modules carry their own `markTextAnalysis`, and unifying them is a different lot. What *can*
--- be shared is the conversion, which is the part that was being written wrong each time.
---
--- @param value the raw parameter (string, number, or anything a player managed to produce)
--- @param options optional table: `default` when the value is unusable, `min`/`max` to clamp
--- @return number|nil the converted value, the clamped value, or `options.default`
function veaf.safeNumber(value, options)
  options = options or {}
  local _number = tonumber(value)
  if _number == nil then
    return options.default
  end
  if options.min and _number < options.min then
    return options.min
  end
  if options.max and _number > options.max then
    return options.max
  end
  return _number
end

--- Convert a marker parameter to a number, **rejecting** it when it falls outside `min`..`max`.
---
--- The bounded twin of `veaf.safeNumber`, which *clamps* instead. Marker keywords want the
--- rejecting form: `size 42` keeps the command's default rather than silently becoming 5.
---
--- Seven keywords across `veafCasMission` and `veafTransportMission` wrote this out inline, and
--- three of those copies still carried `tonumber(val) <= 5` because a fix reaches the copy it was
--- written against. Callers now name the bounds and test one value.
---
--- @param value the raw parameter (string, number, or anything a player managed to produce)
--- @param min lowest accepted value, inclusive
--- @param max highest accepted value, inclusive
--- @return number|nil the value when it converts and is in range, `nil` otherwise
function veaf.safeNumberInRange(value, min, max)
  local _number = veaf.safeNumber(value)
  if _number == nil or _number < min or _number > max then
    return nil
  end
  return _number
end

-------------------------------------------------------------------------------------------------
-- Shared marker-text parser (REFACTOR-MARKER-PARSER)
--
-- Every marker command has the same shape: a keyphrase, then separated `key value` pairs. That
-- loop was copied across the codebase, which is why a fix reached one copy and not its siblings
-- three times over (VMR-019, VMR-025, and the two FIX-MARKER-PARAM-CRASHES lots).
--
-- A module now DECLARES its parameters instead of writing the loop, so a new keyword cannot
-- reintroduce `tonumber(nil) <= 5`. The specification has to be able to express the quirks
-- ticket 01 measured, because several are load-bearing and a migration that drops one silently
-- changes a command in the field:
--
--   * `valueWhenAbsent` — a valueless keyword is nil in some modules and "" in others, which
--     decides whether a bare keyword reads as a flag or as an error.
--   * `separator` — every module splits on "," except ArtilleryUnitHandler, which uses ";".
--   * command descriptors seed different defaults per sub-verb, FIRST MATCH WINS: the chain's
--     order decides, not the text's, so `_move group tanker` is a group move.
--   * ALL matching parameter rules run, in declaration order, and a repeated keyword therefore
--     ends on its last occurrence.
--   * a value keeps everything after the FIRST space and is NOT trimmed: `side  BLUE` with two
--     spaces really is " BLUE", which is not "BLUE". Trimming here would change behaviour.
-------------------------------------------------------------------------------------------------

--- Ready-made `apply` functions for the common parameter kinds.
---
--- These are the four `veafSpawnParser` had as file-locals. They live here because the crash
--- family came from every module writing its own: `VMR-025` fixed the nil guard in `_num` and
--- left the identical hole in `_numNonNegative`, one function below it.
veaf.markerRules = {}

--- A numeric parameter, keeping the field's existing value when the input is unusable.
---
--- Conversion goes through `veaf.getRandomizableNumeric`, which also accepts the `1-5`
--- random-range syntax markers use — a third numeric kind beyond `safeNumber` and
--- `safeNumberInRange`, not a mistake.
function veaf.markerRules.number(field)
  return function(options, value)
    if value == nil then
      return
    end
    local _converted = veaf.getRandomizableNumeric(value)
    if _converted ~= nil then
      options[field] = _converted
    end
  end
end

--- A numeric parameter that must not go below zero, keeping the existing value otherwise.
---
--- Guards nil the same way `number` does. That symmetry is the point: this helper's whole history
--- is that it did *not* have the guard its sibling had.
function veaf.markerRules.nonNegativeNumber(field)
  return function(options, value)
    if value == nil then
      return
    end
    local _converted = veaf.getRandomizableNumeric(value)
    if _converted and _converted >= 0 then
      options[field] = _converted
    end
  end
end

--- A numeric parameter accepted only inside `min`..`max`, keeping the default otherwise.
---
--- Goes through `veaf.safeNumberInRange`, which **rejects** rather than clamps — `size 42` keeps
--- the command's default instead of silently becoming 5, the behaviour `VMR-019` settled on.
---
--- Deliberately not `getRandomizableNumeric`: the modules using bounded parameters never accepted
--- the `1-5` random-range syntax, and adding it here would be a behaviour change wearing a
--- refactor's clothes.
function veaf.markerRules.boundedNumber(field, min, max)
  return function(options, value)
    local _converted = veaf.safeNumberInRange(value, min, max)
    if _converted then
      options[field] = _converted
    end
  end
end

--- A string parameter, stored exactly as typed — including nil, which clears the field.
---
--- Use `textKeepingDefault` instead whenever the field has a default worth surviving a mistyped
--- keyword.
function veaf.markerRules.text(field)
  return function(options, value)
    options[field] = value
  end
end

--- A string parameter that leaves the field alone when the keyword carries no value.
---
--- The difference matters wherever a default exists: `_radio transmit, freq` used to set
--- `frequencies` to nil, and `executeCommand` requires that field, so the command did nothing at
--- all and said nothing to the pilot. An *unknown* keyword was harmless by comparison, since it
--- left the default intact — a mistyped recognised keyword should not be worse than an
--- unrecognised one.
function veaf.markerRules.textKeepingDefault(field)
  return function(options, value)
    if value ~= nil and value ~= "" then
      options[field] = value
    end
  end
end

--- A flag: present means true, and any value the pilot typed after it is discarded.
function veaf.markerRules.flag(field)
  return function(options)
    options[field] = true
  end
end

--- Build the lookup tables a specification needs, once, in place.
---
--- Mutates `spec` so the work is not redone on every marker: each rule gets a `_keyset` for O(1)
--- matching, and the spec gets the recognised-key list that powers the "did you mean" hint.
--- Idempotent, so a module may call it explicitly at load time or leave it to the first parse.
--- @param spec table the specification to prepare
--- @return table the same spec, prepared
function veaf.prepareMarkerSpec(spec)
  if spec._prepared then
    return spec
  end
  -- Keys are stored lower-cased because `parseMarkerText` looks them up that way: a spec
  -- declaring `keys = { "Size" }` would otherwise never match, and — worse — would be reported
  -- to the pilot as an unknown parameter. Every spec today declares lower-case, so this changes
  -- nothing now and removes a trap for the next one.
  spec.knownKeys = {}
  spec._knownKeySet = {}
  for _, rule in ipairs(spec.parameters or {}) do
    rule._keyset = {}
    for _, key in ipairs(rule.keys) do
      local keyLower = key:lower()
      rule._keyset[keyLower] = true
      if not spec._knownKeySet[keyLower] then
        spec._knownKeySet[keyLower] = true
        table.insert(spec.knownKeys, keyLower)
      end
    end
  end
  spec._prepared = true
  return spec
end

--- Parse marker text into an options table, following a module's declared specification.
---
--- @param text the raw marker text a player typed
--- @param spec table the module's specification:
---   * `defaults` — function(options) seeding the fields every command shares, or a table copied
---     field by field. Runs before the command descriptors.
---   * `commands` — list of `{ match = <lowercase substring>, init = function(options) }`. The
---     first whose `match` is found in the lowercased text wins and seeds its defaults; if none
---     matches, the text is not this module's command and `nil` is returned.
---   * `parameters` — list of `{ keys = {...}, apply = function(options, value), when = function(options) }`.
---     Every rule whose key matches runs, in order; `when` gates context-specific rules.
---   * `separator` — defaults to `","`.
---   * `valueWhenAbsent` — what a keyword with no value passes to `apply`. Defaults to `nil`;
---     pass `""` for the modules that read `str[2] or ""`.
---   * `reportUnknownKeys` — when true, unrecognised keys are collected into
---     `options.unknownParameters` with a nearest-match `suggestion`, so the caller can hint the
---     pilot about a typo. Keys starting with `_` are skipped: that is the command keyphrase.
---   * `validate` — function(options) run after the loop; returning false rejects the command,
---     which is how a mandatory parameter is enforced.
--- @return table|nil the options table, or nil when the text is not this module's command
function veaf.parseMarkerText(text, spec)
  if type(text) ~= "string" then
    return nil
  end
  veaf.prepareMarkerSpec(spec)

  local options = {}
  if type(spec.defaults) == "function" then
    spec.defaults(options)
  elseif type(spec.defaults) == "table" then
    for field, value in pairs(spec.defaults) do
      options[field] = value
    end
  end

  -- Detect the command keyphrase and seed its defaults. First match wins.
  local textLower = text:lower()
  local matched = false
  for _, command in ipairs(spec.commands or {}) do
    if textLower:find(command.match, 1, true) then
      if command.init then
        command.init(options)
      end
      matched = true
      break
    end
  end
  if not matched then
    return nil
  end

  -- `ipairs`, not `pairs`: order is load-bearing here — a repeated keyword must end on its LAST
  -- occurrence — and Lua does not guarantee `pairs` iterates a sequence in order. Every copied
  -- parser used `pairs` and got away with it; sharing the loop means fixing that once.
  for _, keyphrase in ipairs(veaf.split(text, spec.separator or ",")) do
    -- The first space separates key from value; everything after it IS the value, untrimmed.
    local parts = veaf.breakString(veaf.trim(keyphrase), " ")
    local key = parts[1]
    local value = parts[2]
    if value == nil then
      value = spec.valueWhenAbsent
    end
    local keyLower = key:lower()

    if spec.reportUnknownKeys and keyLower ~= "" and keyLower:sub(1, 1) ~= "_" and not spec._knownKeySet[keyLower] then
      options.unknownParameters = options.unknownParameters or {}
      table.insert(options.unknownParameters, {
        key = key,
        suggestion = veaf.nearestMatch(keyLower, spec.knownKeys, 3),
      })
    end

    -- ALL matching rules run, in declaration order.
    for _, rule in ipairs(spec.parameters or {}) do
      if rule._keyset[keyLower] and (not rule.when or rule.when(options)) then
        rule.apply(options, value)
      end
    end
  end

  if spec.validate and not spec.validate(options) then
    return nil
  end
  return options
end

function veaf.safeUnpack(package)
  if type(package) == "table" then
    return (unpack or table.unpack)(package) -- luacheck: ignore 143
  else
    return package
  end
end

--- Safely call a function with pcall, logging any error.
-- @param fn the function to call
-- @param ... arguments to pass to the function
-- @return the return values of fn, or nil if an error occurred
function veaf.safeCall(fn, ...)
  local results = { pcall(fn, ...) }
  if not results[1] then
    veaf.loggers.get(veaf.Id):error("safeCall caught error: %s", tostring(results[2]))
    return nil
  end
  return unpack(results, 2)
end

function veaf.getRandomizableNumeric_random(val)
  veaf.loggers.get(veaf.Id):trace(string.format("getRandomizableNumeric_random(%s)", tostring(val)))
  local MIN = 0
  local MAX = 99
  local nVal = tonumber(val)
  veaf.loggers.get(veaf.Id):trace("nVal=%s", veaf.lp(nVal))
  if nVal == nil then
    -- REFACTOR-MARKER-PARSER ticket 02: return nil rather than raising on something that is not
    -- a string. `string.find(nil, ...)` below is the crash VMR-025 described and then guarded
    -- against **in its caller** (`_num`), which left the hole reachable from every other caller
    -- — and `_numNonNegative`, one function away, walked straight into it. Fixed at the source
    -- this time, so the guard cannot be forgotten again. `_norandom` never had the problem.
    if type(val) ~= "string" then
      return nil
    end
    local dashPos = string.find(val, "%-")
    veaf.loggers.get(veaf.Id):trace("dashPos=%s", veaf.lp(dashPos))
    if dashPos then
      local lower = val:sub(1, dashPos - 1)
      veaf.loggers.get(veaf.Id):trace("lower=%s", veaf.lp(lower))
      if lower then
        lower = tonumber(lower)
      end
      if lower == nil then
        lower = MIN
      end
      local upper = val:sub(dashPos + 1)
      veaf.loggers.get(veaf.Id):trace("upper=%s", veaf.lp(upper))
      if upper then
        upper = tonumber(upper)
      end
      if upper == nil then
        upper = MAX
      end
      nVal = math.random(lower, upper)
      veaf.loggers.get(veaf.Id):trace("nVal=%s", veaf.lp(nVal))
    end
  end

  veaf.loggers.get(veaf.Id):trace(string.format("nVal=%s", tostring(nVal)))
  return nVal
end

function veaf.getRandomizableNumeric_norandom(val)
  veaf.loggers.get(veaf.Id):trace(string.format("getRandomizableNumeric_norandom(%s)", tostring(val)))
  local nVal = tonumber(val)
  veaf.loggers.get(veaf.Id):trace(string.format("nVal=%s", tostring(nVal)))
  if nVal == nil then
    if val == "1-2" then
      nVal = 2
    elseif val == "1-3" then
      nVal = 3
    elseif val == "1-4" then
      nVal = 3
    elseif val == "1-5" then
      nVal = 3
    elseif val == "2-3" then
      nVal = 2
    elseif val == "2-4" then
      nVal = 3
    elseif val == "2-5" then
      nVal = 3
    elseif val == "3-4" then
      nVal = 3
    elseif val == "3-5" then
      nVal = 4
    elseif val == "4-5" then
      nVal = 4
    elseif val == "5-10" then
      nVal = 7
    elseif val == "10-15" then
      nVal = 12
    end
  end
  veaf.loggers.get(veaf.Id):trace(string.format("nVal=%s", tostring(nVal)))
  return nVal
end

function veaf.getRandomizableNumeric(val)
  veaf.loggers.get(veaf.Id):trace(string.format("getRandomizableNumeric(%s)", tostring(val)))
  return veaf.getRandomizableNumeric_random(val)
end

function veaf.writeLineToTextFile(line, filename, filepath)
  local l_lfs = lfs
  if not l_lfs and SERVER_CONFIG and SERVER_CONFIG.getModule then
    l_lfs = SERVER_CONFIG.getModule("lfs")
  end

  local l_io = io
  if not l_io and SERVER_CONFIG and SERVER_CONFIG.getModule then
    l_io = SERVER_CONFIG.getModule("io")
  end

  local l_os = os
  if not l_os and SERVER_CONFIG and SERVER_CONFIG.getModule then
    l_os = SERVER_CONFIG.getModule("os")
  end

  local l_filepath = filepath
  if not l_filepath and l_os then
    l_filepath = l_os.getenv("VEAF_EXPORT_DIR")
    if l_filepath then
      l_filepath = l_filepath .. "\\"
    end
    veaf.loggers.get(veaf.Id):debug(string.format("filepath=%s", veaf.p(l_filepath)))
  end
  if not l_filepath and l_lfs then
    l_filepath = l_lfs.writedir()
    veaf.loggers.get(veaf.Id):debug(string.format("filepath=%s", veaf.p(l_filepath)))
  end
  if not l_filepath and l_os then
    l_filepath = l_os.getenv("TEMP")
    if l_filepath then
      l_filepath = l_filepath .. "\\"
    end
    veaf.loggers.get(veaf.Id):debug(string.format("filepath=%s", veaf.p(l_filepath)))
  end
  if l_filepath == "SERVER_SAVEDGAMES_DIR" then
    l_filepath = l_lfs.writedir()
    veaf.loggers.get(veaf.Id):debug(string.format("filepath=%s", veaf.p(l_filepath)))
  end

  if not l_filepath then
    return
  end

  local l_filename = l_filepath .. (filename or "default.log")

  local date = ""
  if l_os then
    date = tostring(l_os.date("%Y-%m-%d %H:%M:%S.000"))
  end

  veaf.loggers.get(veaf.Id):debug(string.format("filename=%s", veaf.p(l_filename)))
  local file = l_io.open(l_filename, "a")
  if file then
    veaf.loggers.get(veaf.Id):trace(string.format("file:write(%s)", veaf.p(line)))
    file:write(string.format("[%s] %s\r\n", date, line))
    file:close()
  end
end

function veaf.exportAsJson(data, name, jsonify, filename, export_path)
  local l_lfs = lfs
  if not l_lfs and SERVER_CONFIG and SERVER_CONFIG.getModule then
    l_lfs = SERVER_CONFIG.getModule("lfs")
  end

  local l_io = io
  if not l_io and SERVER_CONFIG and SERVER_CONFIG.getModule then
    l_io = SERVER_CONFIG.getModule("io")
  end

  local l_os = os
  if not l_os and SERVER_CONFIG and SERVER_CONFIG.getModule then
    l_os = SERVER_CONFIG.getModule("os")
  end

  local l_export_path = export_path
  if not l_export_path and l_os then
    l_export_path = l_os.getenv("VEAF_EXPORT_DIR")
    if l_export_path then
      l_export_path = l_export_path .. "\\"
    end
    veaf.loggers.get(veaf.Id):debug(string.format("filepath=%s", veaf.p(l_export_path)))
  end
  if not l_export_path and l_lfs then
    l_export_path = l_lfs.writedir()
    veaf.loggers.get(veaf.Id):debug(string.format("filepath=%s", veaf.p(l_export_path)))
  end
  if not l_export_path and l_os then
    l_export_path = l_os.getenv("TEMP")
    if l_export_path then
      l_export_path = l_export_path .. "\\"
    end
    veaf.loggers.get(veaf.Id):debug(string.format("filepath=%s", veaf.p(l_export_path)))
  end
  if l_export_path == "SERVER_SAVEDGAMES_DIR" then
    l_export_path = l_lfs.writedir()
    veaf.loggers.get(veaf.Id):debug(string.format("filepath=%s", veaf.p(l_export_path)))
  end

  if not l_export_path then
    return
  end

  local function writeln(file, text)
    file:write(text .. "\r\n")
  end

  local filename = filename or name .. ".json"
  veaf.loggers.get(veaf.Id):trace(string.format("filename=%s", veaf.p(filename)))

  veaf.loggers.get(veaf.Id):info("Dumping " .. name .. " as json to " .. filename .. " in " .. l_export_path)

  local header = "{\n"
  header = header .. '  "' .. name .. '": [\n'

  local content = {}
  for key, value in pairs(data) do
    local line = jsonify(key, value)
    veaf.loggers.get(veaf.Id):trace("line=%s", veaf.lp(line))
    table.insert(content, line)
  end
  local footer = "\n"
  footer = footer .. "]\n"
  footer = footer .. "}\n"

  -- The `if file then` used to sit after the three writes, so an unwritable export directory raised
  -- inside writeln on a nil handle -- in a script running in DCS (SECREV-2 / VMR-081).
  local file, fileError = l_io.open(l_export_path .. filename, "w")
  if not file then
    veaf.loggers.get(veaf.Id):error(string.format("cannot open %s for writing: %s", veaf.p(l_export_path .. filename), tostring(fileError)))
    return
  end
  writeln(file, header)
  writeln(file, table.concat(content, ",\n"))
  writeln(file, footer)
  file:close()
end

function veaf.isUnitAlive(unit)
  return unit and unit:isExist() and unit:isActive()
end

function veaf.getUnitLifeRelative(unit)
  if unit and veaf.isUnitAlive(unit) then
    local unitLife = unit:getLife()
    local unitLife0 = 0
    if unit.getLife0 then -- statics have no life0
      unitLife0 = unit:getLife0()
    end
    if unitLife0 > 0 then
      return unitLife / unitLife0
    else
      return unitLife
    end
  else
    return 0
  end
end

function veaf.setServerName(value)
  veaf.config.SERVER_NAME = value
end

function veaf.setServerBotChannel(value)
  veaf.config.DCS_SERVER_BOT_CHANNEL = value
end

function veaf.getPolygonFromUnits(unitNames)
  veaf.loggers.get(veaf.Id):debug(string.format("veaf.getPolygonFromUnits()"))
  veaf.loggers.get(veaf.Id):trace(string.format("unitNames = %s", veaf.p(unitNames)))
  local polygon = {}
  for _, unitName in pairs(unitNames) do
    veaf.loggers.get(veaf.Id):trace(string.format("unitName = %s", veaf.p(unitName)))
    local unit = Unit.getByName(unitName)
    if not unit then
      local group = Group.getByName(unitName)
      if group then
        unit = group:getUnit(1)
      end
    end
    if unit then
      -- get position, place tracing marker and remove the unit
      local position = unit:getPosition().p
      unit:destroy()
      veaf.loggers.get(veaf.Id):trace(string.format("position = %s", veaf.p(position)))
      table.insert(polygon, mist.utils.deepCopy(position))
    end
  end
  veaf.loggers.get(veaf.Id):trace(string.format("polygon = %s", veaf.p(polygon)))
  return polygon
end

function veaf.laserCodeToDigit(code)
  local codeDigit = {}
  codeDigit.units = code % 10
  codeDigit.tens = (code % 100 - codeDigit.units) / 10
  codeDigit.hundreds = (code % 1000 - codeDigit.tens * 10 - codeDigit.units) / 100
  codeDigit.thousands = (code - codeDigit.hundreds * 100 - codeDigit.tens * 10 - codeDigit.units) / 1000

  veaf.loggers.get(veaf.Id):debug(string.format("laser code : %s", veaf.p(code)))
  veaf.loggers.get(veaf.Id):debug(string.format("laser code digits : %s", veaf.p(codeDigit)))

  return codeDigit
end

--computes the heading between two points in radians
function veaf.headingBetweenPoints(point1, point2)
  local hdg

  if point1 and point2 and point1.x and point1.y and point2.x and point2.y then
    -- if hdg is not set, compute heading between point2 and point3
    hdg = math.floor(math.deg(math.atan2(point2.y - point1.y, point2.x - point1.x)))
    if hdg < 0 then
      hdg = hdg + 360
    end
  end

  -- convert heading to radians
  hdg = hdg * math.pi / 180

  return hdg
end

---checks if a string starts with a prefix
---@param aString any
---@param aPrefix any
---@param caseSensitive? boolean   ; if true, case sensitive search
---@return boolean
function veaf.startsWith(aString, aPrefix, caseSensitive)
  local aString = aString
  if not aString then
    veaf.loggers.get(veaf.Id):error("veaf.startsWith: parameter aString is mandatory")
    return false
  elseif not caseSensitive then
    aString = aString:upper()
  end
  local aPrefix = aPrefix
  if not aPrefix then
    veaf.loggers.get(veaf.Id):error("veaf.startsWith: parameter aPrefix is mandatory")
    return false
  elseif not caseSensitive then
    aPrefix = aPrefix:upper()
  end
  return string.sub(aString, 1, string.len(aPrefix)) == aPrefix
end

function veaf.getDcsTypeName(dcsElementName)
  veaf.loggers.get(veaf.Id):debug("veaf.getDcsTypeName(dcsElementName=%s", veaf.lp(dcsElementName))

  local result = "unknown"

  if not veaf.isNullOrEmpty(dcsElementName) then
    -- first check for a unit named like this, because the group and its units may have the same name
    local dcsUnit = Unit.getByName(dcsElementName)
    veaf.loggers.get(veaf.Id):trace("Unit.getByName(dcsElementName)=%s", veaf.lp(dcsUnit))
    if not dcsUnit then
      -- then check for a group named like that
      local dcsGroup = Group.getByName(dcsElementName)
      veaf.loggers.get(veaf.Id):trace("Group.getByName(dcsElementName)=%s", veaf.lp(dcsGroup))
      dcsUnit = dcsGroup and dcsGroup:getUnit(1)
    end
    if dcsUnit then
      veaf.loggers.get(veaf.Id):trace("dcsUnit=%s", veaf.lp(dcsUnit, nil, nil, true, false))
      result = dcsUnit:getTypeName()
    end
  end

  veaf.loggers.get(veaf.Id):trace("result=%s", veaf.lp(result))

  return result
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Logging
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.loggers = {}
veaf.loggers.dict = {}

veaf.Logger = {
  -- technical name
  name = nil,
  -- logging level
  level = nil,
}
veaf.Logger.__index = veaf.Logger

veaf.Logger.LEVEL = {
  ["error"] = 1,
  ["warning"] = 2,
  ["info"] = 3,
  ["debug"] = 4,
  ["trace"] = 5,
}

veaf.Logger.LEVEL_INV = {
  [1] = "ERROR",
  [2] = "WARNING",
  [3] = "INFO",
  [4] = "DEBUG",
  [5] = "TRACE",
}

--- Convert a log level (int or string) to a string
function veaf.Logger.levelToString(level)
  if type(level) == "string" then
    return level:lower()
  elseif type(level) == "number" then
    return veaf.Logger.LEVEL_INV[level] or "unknown"
  else
    return "unknown"
  end
end

function veaf.Logger:new(name, level)
  local self = setmetatable({}, veaf.Logger)
  self:setName(name)
  self:setLevel(level)
  return self
end

function veaf.Logger:setName(value)
  self.name = value
  return self
end

function veaf.Logger:getName()
  return self.name
end

function veaf.Logger:setLevel(value, force)
  if veaf.ForcedLogLevel then
    value = veaf.ForcedLogLevel
  end
  local level = value
  if type(level) == "string" then
    level = veaf.Logger.LEVEL[level:lower()]
  end
  if not level then
    level = veaf.Logger.LEVEL["info"]
  end
  if veaf.BaseLogLevel < level and not force then
    level = veaf.BaseLogLevel
  end
  self.level = level
  return self
end

function veaf.Logger:getLevel()
  return self.level
end

function veaf.Logger:getEffectiveLevel()
  local level = self.level
  if veaf.ForcedLogLevel then
    local forced = veaf.ForcedLogLevel
    if type(forced) == "string" then
      forced = veaf.Logger.LEVEL[forced:lower()]
    end
    if forced then
      level = forced
    end
  end
  return level
end

function veaf.Logger.splitText(text)
  local tbl = {}
  while text:len() > 4000 do
    local sub = text:sub(1, 4000)
    text = text:sub(4001)
    table.insert(tbl, sub)
  end
  table.insert(tbl, text)
  return tbl
end

function veaf.Logger.formatText(text, ...)
  if not text then
    return ""
  end
  if type(text) ~= "string" then
    text = veaf.p(text)
  else
    local args = ...
    if args and args.n and args.n > 0 then
      local pArgs = {}
      for i = 1, args.n do
        pArgs[i] = veaf.p(args[i])
      end
      -- add a few empty strings for safety
      for i = 1, 20 do
        table.insert(pArgs, "[nil]")
      end
      text = text:format(unpack(pArgs))
    end
  end
  local fName = nil
  local cLine = nil
  if debug and debug.getinfo then
    local dInfo = debug.getinfo(3)
    fName = dInfo.name
    cLine = dInfo.currentline
    -- local fsrc = dinfo.short_src
    --local fLine = dInfo.linedefined
  end
  if fName and cLine then
    return fName .. "|" .. cLine .. ": " .. text
  elseif cLine then
    return cLine .. ": " .. text
  else
    return " " .. text
  end
end

function veaf.Logger:print(level, text, logWithDcsServerBot)
  local texts = veaf.Logger.splitText(text)
  local levelChar = "E"
  local logFunction = env.error
  if level == veaf.Logger.LEVEL["warning"] then
    levelChar = "W"
    logFunction = env.warning
  elseif level == veaf.Logger.LEVEL["info"] then
    levelChar = "I"
    logFunction = env.info
  elseif level == veaf.Logger.LEVEL["debug"] then
    levelChar = "D"
    logFunction = env.info
  elseif level == veaf.Logger.LEVEL["trace"] then
    levelChar = "T"
    logFunction = env.info
  end
  for i = 1, #texts do
    if i == 1 then
      local name = self.name
      if not (name == veaf.Id) then
        name = veaf.Id .. "-" .. name
      end
      local theText = name .. "|" .. levelChar .. "|" .. texts[i]
      logFunction(theText)
      if logWithDcsServerBot and dcsbot and veaf.config.DCS_SERVER_BOT_CHANNEL then
        local current_mission = veaf.config.MISSION_NAME or "unknown"
        dcsbot.sendBotMessage(veaf.config.SERVER_NAME .. " | " .. current_mission .. " | " .. theText, veaf.config.DCS_SERVER_BOT_CHANNEL)
      end
    else
      local theText = texts[i]
      logFunction(theText)
      if logWithDcsServerBot and dcsbot and veaf.config.DCS_SERVER_BOT_CHANNEL then
        dcsbot.sendBotMessage(theText, veaf.config.DCS_SERVER_BOT_CHANNEL)
      end
    end
  end
end

function veaf.Logger:error(text, ...)
  if self:getEffectiveLevel() >= 1 then
    text = veaf.Logger.formatText(text, arg)
    local mText = text
    if debug and debug.traceback then
      mText = mText .. "\n" .. debug.traceback()
    end
    self:print(1, mText, true)
  end
end

function veaf.Logger:warn(text, ...)
  if self:getEffectiveLevel() >= 2 then
    text = veaf.Logger.formatText(text, arg)
    self:print(2, text)
  end
end

function veaf.Logger:info(text, ...)
  if self:getEffectiveLevel() >= 3 then
    text = veaf.Logger.formatText(text, arg)
    self:print(3, text)
  end
end

function veaf.Logger:debug(text, ...)
  if self:getEffectiveLevel() >= 4 then
    text = veaf.Logger.formatText(text, arg)
    self:print(4, text)
  end
end

function veaf.Logger:trace(text, ...)
  if self:getEffectiveLevel() >= 5 then
    text = veaf.Logger.formatText(text, arg)
    self:print(5, text)
  end
end

function veaf.Logger:wouldLogWarn()
  return self:getEffectiveLevel() >= 2
end

function veaf.Logger:wouldLogInfo()
  return self:getEffectiveLevel() >= 3
end

function veaf.Logger:wouldLogDebug()
  return self:getEffectiveLevel() >= 4
end

function veaf.Logger:wouldLogTrace()
  return self:getEffectiveLevel() >= 5
end

--- Format a module load line, with its logging level.
--- With a version (the framework build stamp), reports "Loading version <v> /<level>".
--- With no version, reports a numberless "loaded /<level>" line: per-module versions were
--- retired in favour of the single veaf.BuildVersion stamp, but the per-module load lines
--- are kept so the load order stays visible for runtime debugging.
function veaf.Logger:getVersionInfo(version)
  local moduleLevel = veaf.Logger.levelToString(self:getLevel())
  if version == nil then
    return string.format("loaded /%s", moduleLevel)
  end
  return string.format("Loading version %s /%s", version, moduleLevel)
end

function veaf.Logger:marker(id, header, message, position, markersTable, radius, fillColor)
  if not id then
    id = 99999
  end
  if self:getEffectiveLevel() >= 5 then
    local correctedPos = {}
    correctedPos.x = position.x
    if not position.z then
      correctedPos.z = position.y
      correctedPos.y = position.alt
    else
      correctedPos.z = position.z
      correctedPos.y = position.y
    end
    if not correctedPos.y then
      correctedPos.y = 0
    end
    local message = message
    if header and id then
      message = header .. id .. " " .. message
    end
    self:trace("creating trace marker #%s at point %s", id, veaf.vecToString(correctedPos))
    if radius then
      trigger.action.circleToAll(-1, id, correctedPos, radius, fillColor, fillColor, 3, false)
    else
      trigger.action.markToAll(id, message, correctedPos, false)
    end
    if markersTable then
      table.insert(markersTable, id)
      --self:trace("markersTable=%s", veaf.p(markersTable))
    end
  end
  return id + 1
end

function veaf.Logger:markerArrow(id, header, message, positionStart, positionEnd, markersTable, lineType, fillColor)
  if not id then
    id = 99999
  end
  if self:getEffectiveLevel() >= 5 then
    local points = { positionStart, positionEnd }
    for _, point in ipairs(points) do
      local correctedPos = {}
      correctedPos.x = point.x
      if not point.z then
        correctedPos.z = point.y
        correctedPos.y = point.alt
      else
        correctedPos.z = point.z
        correctedPos.y = point.y
      end
      if not correctedPos.y then
        correctedPos.y = 0
      end
      point.x = correctedPos.x
      point.y = correctedPos.y
      point.z = correctedPos.z
    end
    local positionStart = points[1]
    local positionEnd = points[2]

    local message = message
    if header and id then
      message = header .. id .. " " .. message
    end

    self:trace("creating trace arrow #%s from point %s to point %s", id, veaf.vecToString(positionStart), veaf.vecToString(positionEnd))

    trigger.action.arrowToAll(-1, id, positionEnd, positionStart, fillColor, fillColor, lineType, false, message)
    if markersTable then
      table.insert(markersTable, id)
      --self:trace("markersTable=%s", veaf.p(markersTable))
    end
  end
  return id + 1
end

function veaf.Logger:markerQuad(id, header, message, points, markersTable, lineType, fillColor)
  if not id then
    id = 99999
  end
  if self:getEffectiveLevel() >= 5 then
    local points = points
    for _, point in ipairs(points) do
      local correctedPos = {}
      correctedPos.x = point.x
      if not point.z then
        correctedPos.z = point.y
        correctedPos.y = point.alt
      else
        correctedPos.z = point.z
        correctedPos.y = point.y
      end
      if not correctedPos.y then
        correctedPos.y = 0
      end
      point.x = correctedPos.x
      point.y = correctedPos.y
      point.z = correctedPos.z
    end

    local message = message
    if header and id then
      message = header .. id .. " " .. message
    end

    self:trace("creating trace quad #%s", id)

    trigger.action.quadToAll(-1, id, points[1], points[2], points[3], points[4], fillColor, fillColor, lineType, false, message)
    if markersTable then
      table.insert(markersTable, id)
      --self:trace("markersTable=%s", veaf.p(markersTable))
    end
  end
  return id + 1
end

function veaf.Logger:cleanupMarkers(markersTable)
  local n = #markersTable
  for i = 1, n do
    local markerId = markersTable[i]
    markersTable[i] = nil
    self:trace("deleting trace marker #%s at pos", markerId, i)
    trigger.action.removeMark(markerId)
  end
end

function veaf.loggers.setBaseLevel(level)
  veaf.BaseLogLevel = level
  -- reset all loggers level if lower than the base level
  for name, logger in pairs(veaf.loggers.dict) do
    logger:setLevel(logger:getLevel())
  end
end

function veaf.loggers.new(loggerId, level)
  if not loggerId or #loggerId == 0 then
    return nil
  end
  local result = veaf.Logger:new(loggerId:upper(), level)
  veaf.loggers.dict[loggerId:lower()] = result
  return result
end

function veaf.loggers.get(loggerId)
  local result = nil
  if loggerId and #loggerId > 0 then
    result = veaf.loggers.dict[loggerId:lower()]
  end
  if not result then
    result = veaf.loggers.get("veaf")
  end
  return result
end

if veaf.Development then
  veaf.loggers.setBaseLevel(veaf.Logger.LEVEL["trace"])
end

veaf.loggers.new(veaf.Id, veaf.LogLevel)

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- unique identifers
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.UNIQUE_ID = 10000 + math.random(50, 500)

function veaf.getUniqueIdentifier()
  veaf.UNIQUE_ID = veaf.UNIQUE_ID + 1
  return veaf.UNIQUE_ID
end

function veaf.generateMilitaryGroupName()
  -- Different naming patterns
  local patterns = {
    "adjective_animal",
    "adjective_weapon",
    "number_adjective_noun",
    "callsign_squad",
    "geographic_unit",
    "mythological",
    "tactical_designation",
  }

  -- Word lists
  local adjectives = {
    "Iron",
    "Steel",
    "Thunder",
    "Lightning",
    "Storm",
    "Fire",
    "Ice",
    "Shadow",
    "Ghost",
    "Viper",
    "Wolf",
    "Eagle",
    "Hawk",
    "Razor",
    "Crimson",
    "Silver",
    "Golden",
    "Black",
    "Red",
    "Blue",
    "Elite",
    "Special",
    "Heavy",
    "Swift",
    "Silent",
    "Deadly",
    "Fierce",
    "Savage",
    "Wild",
    "Noble",
    "Brave",
    "Bold",
  }

  local animals = {
    "Wolf",
    "Eagle",
    "Hawk",
    "Lion",
    "Tiger",
    "Bear",
    "Viper",
    "Cobra",
    "Falcon",
    "Raven",
    "Panther",
    "Jaguar",
    "Shark",
    "Scorpion",
    "Spider",
    "Rhino",
    "Buffalo",
    "Stallion",
    "Hound",
    "Fox",
    "Lynx",
    "Wolverine",
  }

  local weapons = {
    "Sword",
    "Blade",
    "Lance",
    "Spear",
    "Arrow",
    "Bolt",
    "Hammer",
    "Axe",
    "Dagger",
    "Rifle",
    "Cannon",
    "Missile",
    "Torpedo",
    "Sabre",
    "Javelin",
  }

  local nouns = {
    "Battalion",
    "Regiment",
    "Division",
    "Brigade",
    "Company",
    "Platoon",
    "Squad",
    "Unit",
    "Force",
    "Guard",
    "Rangers",
    "Commandos",
    "Marines",
    "Troopers",
    "Warriors",
    "Fighters",
    "Soldiers",
    "Knights",
    "Legion",
  }

  local callsigns = {
    "Alpha",
    "Bravo",
    "Charlie",
    "Delta",
    "Echo",
    "Foxtrot",
    "Golf",
    "Hotel",
    "India",
    "Juliet",
    "Kilo",
    "Lima",
    "Mike",
    "November",
    "Oscar",
    "Papa",
    "Quebec",
    "Romeo",
    "Sierra",
    "Tango",
    "Uniform",
    "Victor",
    "Whiskey",
    "X-ray",
  }

  local geographic = {
    "Mountain",
    "Desert",
    "Forest",
    "Arctic",
    "Coastal",
    "Highland",
    "Valley",
    "Ridge",
    "Peak",
    "Storm",
    "Frost",
    "Dune",
    "Mesa",
    "Canyon",
    "River",
  }

  local mythological = {
    "Phoenix",
    "Dragon",
    "Griffin",
    "Hydra",
    "Kraken",
    "Valkyrie",
    "Titan",
    "Cerberus",
    "Pegasus",
    "Chimera",
    "Minotaur",
    "Cyclops",
    "Banshee",
  }

  local tactical = {
    "Recon",
    "Assault",
    "Strike",
    "Support",
    "Heavy",
    "Light",
    "Stealth",
    "Rapid",
    "Mobile",
    "Shock",
    "Elite",
    "Special",
    "Advanced",
    "Combat",
  }

  -- Helper function to get random element from table
  local function getRandomElement(tbl)
    return tbl[math.random(#tbl)]
  end

  -- Select random pattern
  local pattern = getRandomElement(patterns)
  local name = ""

  if pattern == "adjective_animal" then
    name = getRandomElement(adjectives) .. " " .. getRandomElement(animals)
  elseif pattern == "adjective_weapon" then
    name = getRandomElement(adjectives) .. " " .. getRandomElement(weapons)
  elseif pattern == "number_adjective_noun" then
    local number = math.random(1, 99)
    local suffix = "th"
    if number % 10 == 1 and number ~= 11 then
      suffix = "st"
    elseif number % 10 == 2 and number ~= 12 then
      suffix = "nd"
    elseif number % 10 == 3 and number ~= 13 then
      suffix = "rd"
    end
    name = number .. suffix .. " " .. getRandomElement(adjectives) .. " " .. getRandomElement(nouns)
  elseif pattern == "callsign_squad" then
    name = getRandomElement(callsigns) .. " " .. getRandomElement(nouns)
  elseif pattern == "geographic_unit" then
    name = getRandomElement(geographic) .. " " .. getRandomElement(nouns)
  elseif pattern == "mythological" then
    name = getRandomElement(mythological) .. " " .. getRandomElement(nouns)
  elseif pattern == "tactical_designation" then
    name = getRandomElement(tactical) .. " " .. getRandomElement(adjectives) .. " " .. getRandomElement(nouns)
  end

  return name
end

function veaf.getNameForSpawnedGroup(pCoalition, pBaseName, pCombatZoneName)
  local groupNameTemplate = "%s%s-%s#%s"

  local coaStr = "[n]"
  if pCoalition == coalition.side.RED then
    coaStr = "[r]"
  elseif pCoalition == coalition.side.BLUE then
    coaStr = "[b]"
  end

  local baseName = pBaseName
  local combatZoneName = pCombatZoneName
  if veaf.HideNamesFromSpawnedGroups or not baseName or baseName == "" then
    baseName = veaf.generateMilitaryGroupName()
  end
  if veaf.HideNamesFromSpawnedGroups or not combatZoneName then
    combatZoneName = nil
  end
  if combatZoneName then
    return string.format("%s %s %s#%s", combatZoneName, coaStr, baseName, veaf.getUniqueIdentifier())
  else
    return string.format("%s-%s#%s", coaStr, baseName, veaf.getUniqueIdentifier())
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- lines and figures on the map
-------------------------------------------------------------------------------------------------------------------------------------------------------------

VeafDrawingOnMap = {}
VeafDrawingOnMap.DEFAULT_COLOR = { 170 / 255, 10 / 255, 0 / 255, 220 / 255 }
VeafDrawingOnMap.DEFAULT_FILLCOLOR = { 170 / 255, 10 / 255, 0 / 255, 170 / 255 }
function VeafDrawingOnMap.init(object)
  -- technical name (identifier)
  object.name = nil
  -- coalition
  object.coalition = coalition.side.BLUE
  -- points forming the drawing
  object.points = {}
  -- color ({r, g, b, a})
  object.color = VeafDrawingOnMap.DEFAULT_COLOR
  -- fill color ({r, g, b, a})
  object.fillColor = VeafDrawingOnMap.DEFAULT_FILLCOLOR
  -- type of line (member of VeafDrawingOnMap.LINE_TYPE)
  object.lineType = VeafDrawingOnMap.LINE_TYPE["solid"]
  -- if true, the line is an arrow
  object.isArrow = false
  -- marker ids
  object.dcsMarkerIds = {}
end

-- Type of line marking the zone
-- 0  No Line
-- 1  Solid
-- 2  Dashed
-- 3  Dotted
-- 4  Dot Dash
-- 5  Long Dash
-- 6  Two Dash
VeafDrawingOnMap.LINE_TYPE = {
  ["none"] = 0,
  ["solid"] = 1,
  ["dashed"] = 2,
  ["dotted"] = 3,
  ["dotdash"] = 4,
  ["longdash"] = 5,
  ["twodashes"] = 6,
}

VeafDrawingOnMap.COLORS = {
  ["transparent"] = { 0, 0, 0, 0 },
  ["black"] = { 0, 0, 0, 1 },
  ["white"] = { 1, 1, 1, 1 },
  ["red"] = { 1, 0, 0, 1 },
  ["pink"] = { 1, 0, 0, 0.3 },
  ["green"] = { 0, 1, 0, 1 },
  ["blue"] = { 0, 0, 1, 1 },
}

function VeafDrawingOnMap:new(objectToCopy)
  veaf.loggers.get(veaf.Id):debug("VeafDrawingOnMap:new()")
  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self

  -- init the new object
  VeafDrawingOnMap.init(objectToCreate)

  return objectToCreate
end

function VeafDrawingOnMap:setName(value)
  veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[]:setName(%s)", veaf.lp(value))
  self.name = value
  return self
end

function VeafDrawingOnMap:getName()
  return self.name
end

function VeafDrawingOnMap:setCoalition(value)
  veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:setCoalition(%s)", veaf.lp(self:getName()), veaf.lp(value))
  self.coalition = value
  return self
end

function VeafDrawingOnMap:getCoalition()
  return self.coalition
end

function VeafDrawingOnMap:addPoint(value)
  veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:addPoint(%s)", veaf.lp(self.name), veaf.lp(value))
  table.insert(self.points, 1, mist.utils.deepCopy(value))
  return self
end

function VeafDrawingOnMap:addPoints(value)
  veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:addPoints(%s)", veaf.lp(self.name), veaf.lp(value))
  if value and #value > 0 then
    for _, item in pairs(value) do
      self:addPoint(item)
    end
  end
  return self
end

function VeafDrawingOnMap:setPointsFromUnits(unitNames)
  veaf.loggers.get(veaf.Id):debug("VeafDrawingOnMap[%s]:setPointsFromUnits()", veaf.lp(self.name))
  local polygon = veaf.getPolygonFromUnits(unitNames)
  self:addPoints(polygon)
  return self
end

function VeafDrawingOnMap:setColor(value)
  veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:setColor(%s)", veaf.lp(self:getName()), veaf.lp(value))
  if value and type(value) == "string" then
    value = VeafDrawingOnMap.COLORS[value:lower()]
  end
  if value then
    self.color = mist.utils.deepCopy(value)
  end
  return self
end

function VeafDrawingOnMap:setFillColor(value)
  veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:setFillColor(%s)", veaf.lp(self:getName()), veaf.lp(value))
  if value and type(value) == "string" then
    value = VeafDrawingOnMap.COLORS[value:lower()]
  end
  if value then
    self.fillColor = mist.utils.deepCopy(value)
  end
  return self
end

function VeafDrawingOnMap:setLineType(value)
  veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:setLineType(%s)", veaf.lp(self:getName()), veaf.lp(value))
  if value and type(value) == "string" then
    value = VeafDrawingOnMap.LINE_TYPE[value:lower()]
  end
  if value then
    self.lineType = value
  end
  return self
end

function VeafDrawingOnMap:setArrow()
  veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:setArrow()", veaf.lp(self:getName()))
  self.isArrow = true
  return self
end

function VeafDrawingOnMap:draw()
  veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:draw()", veaf.lp(self:getName()))

  -- start by erasing the drawing if it already is drawn
  self:erase()

  -- then draw it
  local lastPoint = nil
  local firstPoint = nil
  for _, point in pairs(self.points) do
    veaf.loggers.get(veaf.Id):trace("drawing line [%s] - [%s]", veaf.lp(lastPoint), veaf.lp(point))
    local id = veaf.getUniqueIdentifier()
    if lastPoint then
      veaf.loggers.get(veaf.Id):trace("id=[%s]", veaf.lp(id))
      if self.isArrow then
        trigger.action.arrowToAll(self:getCoalition(), id, lastPoint, point, self.color, self.fillColor, self.lineType, true)
      else
        trigger.action.lineToAll(self:getCoalition(), id, lastPoint, point, self.color, self.lineType, true)
      end
    else
      veaf.loggers.get(veaf.Id):trace("setting firstPoint to [%s]", veaf.lp(point))
      trigger.action.markToCoalition(id, self.name, point, self.coalition, true, nil)
      firstPoint = point
    end
    table.insert(self.dcsMarkerIds, id)
    lastPoint = point
  end

  -- finish the polygon
  if firstPoint and lastPoint and #self.points > 2 and not self.isArrow then
    veaf.loggers.get(veaf.Id):trace("finishing the polygon")
    local id = veaf.getUniqueIdentifier()
    veaf.loggers.get(veaf.Id):trace("id=[%s]", veaf.lp(id))
    if self.isArrow then
      trigger.action.arrowToAll(self:getCoalition(), id, lastPoint, firstPoint, self.color, self.fillColor, self.lineType, true)
    else
      trigger.action.lineToAll(self:getCoalition(), id, lastPoint, firstPoint, self.color, self.lineType, true)
    end
    table.insert(self.dcsMarkerIds, id)
  end

  return self
end

function VeafDrawingOnMap:erase()
  veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:erase()", veaf.lp(self:getName()))
  if self.dcsMarkerIds then
    for _, id in pairs(self.dcsMarkerIds) do
      veaf.loggers.get(veaf.Id):trace("removing mark id=[%s]", veaf.lp(id))
      trigger.action.removeMark(id)
    end
  end

  return self
end

VeafCircleOnMap = VeafDrawingOnMap:new()
function VeafCircleOnMap.init(object)
  -- inheritance
  VeafDrawingOnMap.init(object)

  -- radius in meters
  object.radius = nil
end
function VeafCircleOnMap:new(objectToCopy)
  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self

  -- init the new object
  VeafCircleOnMap.init(objectToCreate)

  return objectToCreate
end

function VeafCircleOnMap:setCenter(value)
  veaf.loggers.get(veaf.Id):trace("VeafCircleOnMap[%s]:setCenter(%s)", veaf.lp(self.name), veaf.lp(value))
  self.points = { mist.utils.deepCopy(value) }
  return self
end

function VeafCircleOnMap:setRadius(value)
  veaf.loggers.get(veaf.Id):trace("VeafCircleOnMap[%s]:setRadius(%s)", veaf.lp(self.name), veaf.lp(value))
  self.radius = value
  return self
end

function VeafCircleOnMap:draw()
  veaf.loggers.get(veaf.Id):trace("VeafCircleOnMap[%s]:draw()", veaf.lp(self:getName()))

  -- start by erasing the drawing if it already is drawn
  self:erase()

  -- then draw it
  local id = veaf.getUniqueIdentifier()
  veaf.loggers.get(veaf.Id):trace("id=[%s]", veaf.lp(id))
  trigger.action.circleToAll(self:getCoalition(), id, self.points[1], self.radius, self.color, self.fillColor, self.lineType, true)
  table.insert(self.dcsMarkerIds, id)

  return self
end

VeafSquareOnMap = VeafDrawingOnMap:new()
function VeafSquareOnMap.init(object)
  -- inheritance
  VeafDrawingOnMap.init(object)

  -- side length in meters
  object.side = nil
  -- center of the square
  object.center = nil
end
function VeafSquareOnMap:new(objectToCopy)
  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self

  -- init the new object
  VeafSquareOnMap.init(objectToCreate)

  return objectToCreate
end

function VeafSquareOnMap:setCenter(value)
  veaf.loggers.get(veaf.Id):trace("VeafSquareOnMap[%s]:setCenter(%s)", veaf.lp(self.name), veaf.lp(value))
  self.center = mist.utils.deepCopy(value)
  self:compute()
  return self
end

function VeafSquareOnMap:setSide(value)
  veaf.loggers.get(veaf.Id):trace("VeafSquareOnMap[%s]:setSide(%s)", veaf.lp(self.name), veaf.lp(value))
  self.side = value
  self:compute()
  return self
end

function VeafSquareOnMap:compute()
  veaf.loggers.get(veaf.Id):trace("VeafSquareOnMap[%s]:compute()", veaf.lp(self.name))
  if self.side and self.center then
    veaf.loggers.get(veaf.Id):trace("self.center=%s", veaf.lp(self.center))
    veaf.loggers.get(veaf.Id):trace("self.side=%s", veaf.lp(self.side))
    local leftDownPoint = { x = self.center.x - self.side / 2, y = self.center.y, z = self.center.z - self.side / 2 }
    veaf.loggers.get(veaf.Id):trace("leftDownPoint=%s", veaf.lp(leftDownPoint))
    local rightUpPoint = { x = self.center.x + self.side / 2, y = self.center.y, z = self.center.z + self.side / 2 }
    veaf.loggers.get(veaf.Id):trace("rightUpPoint=%s", veaf.lp(rightUpPoint))
    self.points = { leftDownPoint, rightUpPoint }
  end
  return self
end

function VeafSquareOnMap:draw()
  veaf.loggers.get(veaf.Id):trace("VeafSquareOnMap[%s]:draw()", veaf.lp(self:getName()))

  -- start by erasing the drawing if it already is drawn
  self:erase()

  -- then draw it
  local id = veaf.getUniqueIdentifier()
  veaf.loggers.get(veaf.Id):trace("id=[%s]", veaf.lp(id))
  trigger.action.rectToAll(self:getCoalition(), id, self.points[1], self.points[2], self.color, self.fillColor, self.lineType, true)
  table.insert(self.dcsMarkerIds, id)

  return self
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- trigger zones management
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veaf._discoverTriggerZones()
  for _, zones in pairs(env.mission.triggers) do
    for _, zoneData in pairs(zones) do
      veaf.triggerZones[zoneData.name] = {
        ["radius"] = zoneData.radius,
        ["zoneId"] = zoneData.zoneId,
        ["color"] = {
          [1] = zoneData.color[1],
          [2] = zoneData.color[2],
          [3] = zoneData.color[3],
          [4] = zoneData.color[4],
        },
        ["properties"] = zoneData.properties,
        ["hidden"] = zoneData.hidden,
        ["y"] = zoneData.y,
        ["x"] = zoneData.x,
        ["name"] = zoneData.name,
        ["type"] = zoneData.type,
      }
      if zoneData.type == 2 then
        veaf.triggerZones[zoneData.name].verticies = zoneData.verticies
      end
    end
  end
end

function veaf.getTriggerZone(zoneName)
  return veaf.triggerZones[zoneName]
end

--- Reads a raw trigger-zone property, as typed by the mission maker in the editor
-- DCS stores them as an array of { key = "…", value = "…" } pairs, never a map, and every
-- value is a string. Discovered zones have carried them since veaf._discoverTriggerZones,
-- but nothing read them until FEAT-SCENERY-AWARE-SPAWN.
-- @param zoneName name of the trigger zone
-- @param key property name
-- @return string, or nil when the zone, its properties or the key are missing
function veaf.getZoneProperty(zoneName, key)
  local zone = veaf.getTriggerZone(zoneName)
  if not zone or not zone.properties then
    return nil
  end
  for _, property in pairs(zone.properties) do
    if property.key == key then
      return property.value
    end
  end
  return nil
end

--- Reads a trigger-zone property as a boolean
-- Accepts "true"/"false" in any case; anything else is a miss and yields the default, so a
-- mission maker's typo cannot silently read as false.
-- @param zoneName name of the trigger zone
-- @param key property name
-- @param default value returned when absent or unparseable
-- @return boolean
function veaf.getZonePropertyBoolean(zoneName, key, default)
  local raw = veaf.getZoneProperty(zoneName, key)
  if raw == nil then
    return default
  end
  local text = tostring(raw):lower()
  if text == "true" then
    return true
  elseif text == "false" then
    return false
  end
  veaf.loggers.get(veaf.Id):warn(
    string.format(
      "getZonePropertyBoolean: zone [%s] property [%s] is not a boolean: [%s]",
      tostring(zoneName),
      tostring(key),
      tostring(raw)
    )
  )
  return default
end

--- Reads a trigger-zone property as a number, clamped into an optional range
-- Clamps rather than rejects, so a mission maker who types an absurd value gets the bound
-- instead of a dead module. Lua 5.1 has a single number type, hence one accessor and not
-- the float/int pair the source of this pattern exposes.
-- @param zoneName name of the trigger zone
-- @param key property name
-- @param default value returned when absent or not a number
-- @param min optional lower bound
-- @param max optional upper bound
-- @return number
function veaf.getZonePropertyNumber(zoneName, key, default, min, max)
  local raw = veaf.getZoneProperty(zoneName, key)
  if raw == nil then
    return default
  end
  local value = tonumber(raw)
  if not value then
    veaf.loggers.get(veaf.Id):warn(
      string.format(
        "getZonePropertyNumber: zone [%s] property [%s] is not a number: [%s]",
        tostring(zoneName),
        tostring(key),
        tostring(raw)
      )
    )
    return default
  end
  if min and value < min then
    value = min
  end
  if max and value > max then
    value = max
  end
  return value
end
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- initialize the random number generator to make it almost random
math.random()
math.random()
math.random()
local l_os = os
if not l_os and SERVER_CONFIG and SERVER_CONFIG.getModule then
  l_os = SERVER_CONFIG.getModule("os")
end
if l_os and l_os.time and math.randomseed then
  math.randomseed(l_os.time())
end

--- Enable/Disable error boxes displayed on screen.
env.setErrorMessageBoxEnabled(false)

veaf.loggers.get(veaf.Id):info(veaf.loggers.get(veaf.Id):getVersionInfo(veaf.BuildVersion))
veaf.loggers.get(veaf.Id):info("veaf.Development=%s", veaf.Development)
veaf.loggers.get(veaf.Id):info("veaf.SecurityDisabled=%s", veaf.SecurityDisabled)
veaf.loggers.get(veaf.Id):info("veaf.LogLevel=%s", veaf.LogLevel)
veaf.loggers.get(veaf.Id):info("veaf.ForcedLogLevel=%s", veaf.ForcedLogLevel)

-- discover trigger zones
veaf._discoverTriggerZones()

--store maximum airbase lifes
veaf.loadAirbasesLife0()

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- changes to AIEN
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Our AIEN_xcl_tag (VEAF version) does not autoinitialize. It's also set to log messages using the VEAF logging functions
-- Instead, we count on the mission makers to call AIEN.performPhaseCycle() from mission-script.lua
-- Here, we're upgrading the vanilla AIEN configuration to adapt it to our preferred defaults

if AIEN then
  AIEN.Id = "AIEN"
  --AIEN.LogLevel = "info"
  AIEN.LogLevel = "debug"
  --AIEN.LogLevel = "trace"
  AIEN.logger = veaf.loggers.new(AIEN.Id, AIEN.LogLevel)
  AIEN.loggers = veaf.loggers -- replace AIEN loggers with ours

  -- coalition affected by the script
  AIEN.config.blueAI = true -- true/false. If true, the AI enhancement will be applied to the blue coalition ground groups, else, no script effect will take place
  AIEN.config.redAI = true -- true/false. If true, the AI enhancement will be applied to the red  coalition ground groups, else, no script effect will take place

  -- Action sets allowed.
  AIEN.config.suppression = true -- true/false. If true, once a group take fire from arty or air and it's not armoured, it will be suppressed for 15-45 seconds and won't return fire. Require reactions to be set as 'true'
  AIEN.config.firemissions = true -- true/false. If true, each artillery in the coalition will fire automatically at available targets provided by other ground units and drones
  AIEN.config.reactions = true -- true/false. If true, when a mover group gets an hit, it will react accordingly to its skills and to its situational awareness, not staying there taking hits without doing nothing
  AIEN.config.dismount = true -- true/false. //BEWARE: CAN AFFECT PERFORMANCES ON LOW END SYSTEMS // Thanks to MBot's original script, if true AI ground units with infantry transport capabilities (mainly APC/IFV/Trucks) will dismount soldiers with rifle, rpg and sometimes mandpads when appropriate

  -- User advanced customization
  AIEN.config.AIEN_xcl_tag = "XCL" -- string, global, case sensitive. Can be dynamically changed by other script or triggers, since it's a global variable. used as a text format without spaces or special characters. only letters and numbers allowed. Any ground group with this 'tag' in its group name won't get AI enhancement behaviour, regardless of its coalition
  AIEN.config.AIEN_zoneFilter = "" -- string, global, case sensitive. Can be dynamically changed by other script or triggers, since it's a global variable. used as a text format without spaces or special characters. only letters and numbers allowed, i.e. "AIEN" will fit. If left nil, or void string like "", won't be used. Only groups inside the named trigger zone will be affected by AIEN script behaviors of reaction, dismount and suppression, and vice versa. If no trigger zone with the specific name is in the mission, then all the groups will use AIEN features.
  AIEN.config.message_feed = true -- true/false. If true, each relevant AI action starting will also create a trigger message feedback for its coalition
  AIEN.config.mark_on_f10_map = true -- true/false. If true, when an artillery fire mission is ongoing, a markpoint will appear on the map of the allied coalition to show the expected impact point
  AIEN.config.skill_action_const = false -- true/false. If true, AI available reactions types will be limited by the group average skill. If not, almost 2/3 of all available actions will be always be available regardless of the group skills

  -- User bug report: prior to report a bug, please try reproducing it with this variable set to "true"
  AIEN.config.AIEN_debugProcessDetail = true

  -- movement variables
  AIEN.config.outRoadSpeed = 8 -- do *3.6 for km/h, cause DCS thinks in m/s
  AIEN.config.inRoadSpeed = 15 -- do *3.6 for km/h, cause DCS thinks in m/s
  AIEN.config.infantrySpeed = 2 -- do *3.6 for km/h, cause DCS thinks in m/s
  AIEN.config.repositionDistance = 500 -- meters, radius to a specific destination point that will be randomized between 90% and 110% of this value. Used when a group is moved upon another group position: the other group position will be the destination.
  AIEN.config.rndFleeDistance = 2000 -- meters, reposition distance given to a group when a destination is not defined. The direction also will be totally random. Used, i.e., for "panic" reaction

  -- dismounted troops variables
  AIEN.config.droppedReposition = 80 -- if no enemy is identified, this is the distance where dismount group will reposition themselves
  AIEN.config.remountTime = 600 -- time after which dismounted troops will try to go back to their original vehicle for remount, if commanded
  AIEN.config.infantryExtractDist = 200 -- max distance from vehicle to troops to allow a group extraction
  AIEN.config.infantrySearchDist = 2000 -- max distance from vehicle to troops to allow a dismount group to run toward the enemies

  -- informative calls variables
  AIEN.config.outAmmoLowLevel = 0.5 -- factor on total amount

  -- reactions and tasking variables
  AIEN.config.intelDbTimeout = 1200 -- seconds. Used to cancel intelDb entries for units (not static!), when the time of the contact gathering is more than this value
  AIEN.config.artyFireLastContactThereshold = 300 -- seconds, max amount of time since last contact to consider an arty target ok
  AIEN.config.taskTimeout = 480 -- seconds after which a tasked group is removed from the database
  AIEN.config.targetedTimeout = 240 -- seconds after which a targeted variable in inteldb is removed from database
  AIEN.config.disperseActionTime = 120 -- seconds
  AIEN.config.counterBatteryRadarRange = 50000 -- m, capable distance for a radar to perform counter battery calculations
  AIEN.config.counterBatteryPlanDelay = 240 -- s, will be also randomized on +-35%. Used to define the delay of the planned counter battery fire if available
  AIEN.config.smoke_source_num = 5 -- number, between 4 and 9. Generated smokes for each unit when smoke reaction is called in. Any number below 4 or above 9 will be converted in the nearest threshold

  -- SA evaluation variables
  AIEN.config.proxyBuildingDistance = 4000 -- m, if buildings are within this distance value, they are considered "close"
  AIEN.config.proxyUnitsDistance = 5000 -- m, if units are within this distance value, they are considered "close"
  AIEN.config.supportDistance = 8000 -- m, maximum distance for evaluating support or cover movements when under attack
  AIEN.config.withrawDist = 15000 -- m, maximum distance for withdraw manoeuvre nearby a friendly support unit
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CTLD 2 integration
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CTLD 2 (https://github.com/VEAF/CTLD) configures itself from a complete YAML snapshot that the
-- build injects as CTLD_userConfig.lua, loaded just before CTLD.lua. That same file sets
-- ctld.dontInitialize, so the engine waits for us instead of starting itself on load: we register
-- it as a VEAF module, which gives it the framework's ordering, its enable flag and its logLevel.
--
-- VEAF sets no CTLD setting here. Everything a mission needs lives in its ctld-config.yaml, edited
-- with ctld-tools (see docs/adr/0016-ctld2-sidecar-configuration.md).

veaf.ctldId = "ctld"

--- Map a CTLD log level onto the matching VEAF logger method.
-- CTLD says WARN where the VEAF logger says warn, and an unknown level must not index nil.
veaf.ctldLogLevels = {
  ERROR = "error",
  WARN = "warn",
  WARNING = "warn",
  INFO = "info",
  DEBUG = "debug",
  TRACE = "trace",
}

--- Route CTLD's logging into the VEAF logger, then start the engine.
-- CTLD 2 funnels all of its logging through ctld.utils.log(level, fmt, ...) and has no level
-- filtering of its own: everything reaches env.info regardless. Overriding that single function
-- gives the mission maker one place to set verbosity — veaf.config.ctld.logLevel, like any other
-- VEAF module — where v1 needed seven separate overrides.
function veaf.ctld_initialize()
  if not ctld then
    veaf.loggers.get(veaf.Id):error("CTLD is enabled but CTLD.lua was not loaded")
    return
  end

  local ctldLogger = veaf.loggers.get(veaf.ctldId) or veaf.loggers.new(veaf.ctldId, "info")

  if ctld.utils then
    ctld.utils.log = function(level, message, ...)
      local method = veaf.ctldLogLevels[tostring(level):upper()] or "info"
      ctldLogger[method](ctldLogger, message, ...)
    end
  else
    veaf.loggers.get(veaf.Id):warn("CTLD.utils is missing - CTLD logs will not be routed to the VEAF logger")
  end

  -- Must come after the override: ctld.initialize() flushes CTLD's startup report, which is
  -- precisely the output naming a stale or incomplete configuration.
  ctld.initialize()
end

if ctld then
  -- Ordered before the VEAF modules that talk to CTLD (veafGrass 150, veafAssets 160).
  veaf.registerModule(veaf.ctldId, veaf.ctld_initialize, { enable = true }, 50)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- changes to CSAR
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Our CSAR (VEAF version) does not autoinitialize. It's also set to log messages using the VEAF logging functions
-- Instead, we count on the mission makers to call csar.initialize from mission-script.lua
-- Here, we're upgrading the vanilla CSAR initialize function so it's smarter

---The VEAF replacement function that wraps up around ctld.initialize
---@param configurationCallback function? a callback that will be called before calling the vanilla csar.initialize function
function veaf.csar_initialize_replacement(configurationCallback)
  if csar then
    veaf.loggers.get(veaf.Id):info(string.format("Setting up CSAR"))

    -- change the init function so we can call it whenever we want
    csar.skipInitialisation = true

    -- logging change
    csar.p = veaf.p
    csar.Id = "CSAR"
    --csar.LogLevel = "info"
    --csar.LogLevel = "trace"
    --csar.LogLevel = "debug"

    csar.logger = veaf.loggers.new(csar.Id, csar.LogLevel)

    -- override the csar logs with our own methods
    ---@diagnostic disable-next-line: duplicate-set-field
    csar.logError = function(message)
      veaf.loggers.get(csar.Id):error(message)
    end

    -- override the csar logs with our own methods
    ---@diagnostic disable-next-line: duplicate-set-field
    csar.logInfo = function(message)
      veaf.loggers.get(csar.Id):info(message)
    end

    -- override the csar logs with our own methods
    ---@diagnostic disable-next-line: duplicate-set-field
    csar.logDebug = function(message)
      veaf.loggers.get(csar.Id):debug(message)
    end

    -- override the csar logs with our own methods
    ---@diagnostic disable-next-line: duplicate-set-field
    csar.logTrace = function(message)
      veaf.loggers.get(csar.Id):trace(message)
    end

    -- global configuration change
    csar.enableAllslots = true
    csar.useprefix = false
    csar.radioSound = "csar-beacon.ogg"

    if configurationCallback and type(configurationCallback) == "function" then
      -- a configuration callback has been set, call it
      veaf.loggers.get(csar.Id):info("calling the configuration callback")
      configurationCallback()
      veaf.loggers.get(csar.Id):info("done calling the configuration callback")
    end

    -- call the actual CSAR.initialize
    ---@diagnostic disable-next-line: param-type-mismatch
    veaf.csar_initialize(true)
    veaf.csar_initialized = true
    veaf.loggers.get(csar.Id):info(string.format("Done setting up CSAR"))
  else
    veaf.loggers.get(veaf.Id):error(string.format("CSAR is not loaded"))
  end
end

if csar then
  veaf.loggers.get(veaf.Id):info(string.format("replacing CSAR.initialize()"))
  veaf.csar_initialize = csar.initialize -- used to call the vanilla csar.initialize from the VEAF replacement
  csar.initialize = veaf.csar_initialize_replacement -- replace the csar.initialize with the VEAF wrapper function
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- changes to STTS
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if STTS then
  veaf.loggers.get(veaf.Id):info(string.format("Setting up STTS"))

  --- configure SRS Text to Speech
  veaf.loggers.get(veaf.Id):trace(string.format("STTS - SERVER_CONFIG=%s", veaf.p(SERVER_CONFIG)))
  if SERVER_CONFIG then
    veaf.loggers.get(veaf.Id):info(string.format("Setting up STTS"))
    STTS.DIRECTORY = SERVER_CONFIG.SRS_DIRECTORY
    STTS.SRS_PORT = SERVER_CONFIG.SRS_PORT
    STTS.EXECUTABLE = SERVER_CONFIG.SRS_EXECUTABLE
    STTS.os = SERVER_CONFIG.getModule("os")
    STTS.io = SERVER_CONFIG.getModule("io")
    veaf.loggers.get(veaf.Id):info(string.format("Done setting up STTS"))
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Mission configuration loader (LUA-002)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Try to load "missionconfig.lua" from the DCS mission scripts directory.
--- If the file does not exist the call is silently skipped (full backward compatibility).
--- The file should contain veaf.setConfig() calls to override module defaults.
function veaf.loadMissionConfig()
  local configFile = "missionconfig.lua"
  local f = loadfile(configFile)
  if f then
    veaf.loggers.get(veaf.Id):info("Loading mission configuration from missionconfig.lua")
    local ok, err = pcall(f)
    if ok then
      veaf.loggers.get(veaf.Id):info("Mission configuration loaded successfully")
    else
      veaf.loggers.get(veaf.Id):error(string.format("Error loading missionconfig.lua: %s", tostring(err)))
    end
  else
    veaf.loggers.get(veaf.Id):info("No missionconfig.lua found - using default module configuration")
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF framework initializer (LUA-003)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Initialize all registered, enabled VEAF modules in registration order.
--- Optionally loads "missionconfig.lua" first to allow per-mission overrides.
---
--- This is the NEW entry point for mission makers who want a single call:
---   veaf.initialize()
---
--- Legacy missions that call each module's initialize() individually are
--- fully backward-compatible: veaf.registerModule() registrations are
--- simply ignored if veaf.initialize() is never called.
function veaf.initialize()
  if veaf._initialized then
    veaf.loggers.get(veaf.Id):warn("veaf.initialize() called more than once - ignoring")
    return
  end

  -- Detect an outdated veaf-scripts.lua (pre-Lot 14, before veafCommands.lua was added).
  -- Without veafCommands, every module that calls veafCommands.registerCommandHandler() during
  -- initialization will crash with a confusing nil error instead of a clear message.
  if not veafCommands then
    veaf.loggers.get(veaf.Id):error(
      "veafCommands is nil — your veaf-scripts.lua is outdated. "
        .. "Run veaf-tools-updater.exe to refresh the scripts package, then rebuild the mission."
    )
    return
  end

  veaf._initialized = true
  veaf.loggers.get(veaf.Id):info("VEAF framework initialization starting")

  -- Load optional per-mission configuration before any module is initialized.
  veaf.loadMissionConfig()

  -- Apply per-module logLevel overrides from config (set via veaf.setConfig or missionconfig.lua).
  for id, _ in pairs(veaf.modules) do
    local cfg = veaf.config[id]
    if cfg and cfg.logLevel then
      local moduleLogger = veaf.loggers.get(id)
      if moduleLogger then
        moduleLogger:setLevel(cfg.logLevel, true)
        veaf.loggers.get(veaf.Id):debug(string.format("Module [%s] log level forced to [%s]", id, cfg.logLevel))
      end
    end
  end

  -- Sort registered modules by their declared order.
  local orderedModules = {}
  for id, module in pairs(veaf.modules) do
    table.insert(orderedModules, { id = id, initFn = module.initFn, order = module.order })
  end
  table.sort(orderedModules, function(a, b)
    return a.order < b.order
  end)

  -- Initialize each enabled module.
  for _, module in ipairs(orderedModules) do
    if veaf.isEnabled(module.id) then
      veaf.loggers.get(veaf.Id):info(string.format("Initializing module [%s]", module.id))
      local ok, err = pcall(module.initFn)
      if not ok then
        veaf.loggers.get(veaf.Id):error(string.format("Error initializing module [%s]: %s", module.id, tostring(err)))
      end
    else
      veaf.loggers.get(veaf.Id):info(string.format("Module [%s] is disabled - skipping initialization", module.id))
    end
  end

  veaf.loggers.get(veaf.Id):info("VEAF framework initialization complete")
end
