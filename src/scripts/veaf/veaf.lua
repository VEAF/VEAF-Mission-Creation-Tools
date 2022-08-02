--------------------------------------------------------------------------------------------------------------------------------------------------------------- VEAF root script library for DCS Workd
-- By zip (2018)
--
-- Features:
-- ---------
-- Contains all the constants and utility functions required by the other VEAF script libraries
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
--
-- Load the script:
-- ----------------
-- 1.) Download the script and save it anywhere on your hard drive.
-- 2.) Open your mission in the mission editor.
-- 3.) Add a new trigger:
--     * TYPE   "4 MISSION START"
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of MIST and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location where you saved the script and click OK.
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the root VEAF constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veaf.Id = "VEAF"

--- Version.
veaf.Version = "1.22.0"

--- Development version ?
veaf.Development = true
veaf.SecurityDisabled = true

-- trace level, specific to this module
veaf.LogLevel = "trace"
--veaf.LogLevel = "debug"
--veaf.ForcedLogLevel = "trace"

-- log level, limiting all the modules
veaf.BaseLogLevel = 5 --trace

veaf.DEFAULT_GROUND_SPEED_KPH = 30
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.monitoredFlags = {}
veaf.maxMonitoredFlag = 27000
veaf.config = {}
veaf.triggerZones = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.EVENTMETA = {
    [world.event.S_EVENT_SHOT] = {
        Order = 1,
        Side = "I",
        Event = "OnEventShot",
        Text = "S_EVENT_SHOT"
    },
    [world.event.S_EVENT_HIT] = {
        Order = 1,
        Side = "T",
        Event = "OnEventHit",
        Text = "S_EVENT_HIT"
    },
    [world.event.S_EVENT_TAKEOFF] = {
        Order = 1,
        Side = "I",
        Event = "OnEventTakeoff",
        Text = "S_EVENT_TAKEOFF"
    },
    [world.event.S_EVENT_LAND] = {
        Order = 1,
        Side = "I",
        Event = "OnEventLand",
        Text = "S_EVENT_LAND"
    },
    [world.event.S_EVENT_CRASH] = {
        Order = -1,
        Side = "I",
        Event = "OnEventCrash",
        Text = "S_EVENT_CRASH"
    },
    [world.event.S_EVENT_EJECTION] = {
        Order = 1,
        Side = "I",
        Event = "OnEventEjection",
        Text = "S_EVENT_EJECTION"
    },
    [world.event.S_EVENT_REFUELING] = {
        Order = 1,
        Side = "I",
        Event = "OnEventRefueling",
        Text = "S_EVENT_REFUELING"
    },
    [world.event.S_EVENT_DEAD] = {
        Order = -1,
        Side = "I",
        Event = "OnEventDead",
        Text = "S_EVENT_DEAD"
    },
    [world.event.S_EVENT_PILOT_DEAD] = {
        Order = 1,
        Side = "I",
        Event = "OnEventPilotDead",
        Text = "S_EVENT_PILOT_DEAD"
    },
    [world.event.S_EVENT_BASE_CAPTURED] = {
        Order = 1,
        Side = "I",
        Event = "OnEventBaseCaptured",
        Text = "S_EVENT_BASE_CAPTURED"
    },
    [world.event.S_EVENT_MISSION_START] = {
        Order = 1,
        Side = "N",
        Event = "OnEventMissionStart",
        Text = "S_EVENT_MISSION_START"
    },
    [world.event.S_EVENT_MISSION_END] = {
        Order = 1,
        Side = "N",
        Event = "OnEventMissionEnd",
        Text = "S_EVENT_MISSION_END"
    },
    [world.event.S_EVENT_TOOK_CONTROL] = {
        Order = 1,
        Side = "N",
        Event = "OnEventTookControl",
        Text = "S_EVENT_TOOK_CONTROL"
    },
    [world.event.S_EVENT_REFUELING_STOP] = {
        Order = 1,
        Side = "I",
        Event = "OnEventRefuelingStop",
        Text = "S_EVENT_REFUELING_STOP"
    },
    [world.event.S_EVENT_BIRTH] = {
        Order = 1,
        Side = "I",
        Event = "OnEventBirth",
        Text = "S_EVENT_BIRTH"
    },
    [world.event.S_EVENT_HUMAN_FAILURE] = {
        Order = 1,
        Side = "I",
        Event = "OnEventHumanFailure",
        Text = "S_EVENT_HUMAN_FAILURE"
    },
    [world.event.S_EVENT_ENGINE_STARTUP] = {
        Order = 1,
        Side = "I",
        Event = "OnEventEngineStartup",
        Text = "S_EVENT_ENGINE_STARTUP"
    },
    [world.event.S_EVENT_ENGINE_SHUTDOWN] = {
        Order = 1,
        Side = "I",
        Event = "OnEventEngineShutdown",
        Text = "S_EVENT_ENGINE_SHUTDOWN"
    },
    [world.event.S_EVENT_PLAYER_ENTER_UNIT] = {
        Order = 1,
        Side = "I",
        Event = "OnEventPlayerEnterUnit",
        Text = "S_EVENT_PLAYER_ENTER_UNIT"
    },
    [world.event.S_EVENT_PLAYER_LEAVE_UNIT] = {
        Order = -1,
        Side = "I",
        Event = "OnEventPlayerLeaveUnit",
        Text = "S_EVENT_PLAYER_LEAVE_UNIT"
    },
    [world.event.S_EVENT_PLAYER_COMMENT] = {
        Order = 1,
        Side = "I",
        Event = "OnEventPlayerComment",
        Text = "S_EVENT_PLAYER_COMMENT"
    },
    [world.event.S_EVENT_SHOOTING_START] = {
        Order = 1,
        Side = "I",
        Event = "OnEventShootingStart",
        Text = "S_EVENT_SHOOTING_START"
    },
    [world.event.S_EVENT_SHOOTING_END] = {
        Order = 1,
        Side = "I",
        Event = "OnEventShootingEnd",
        Text = "S_EVENT_SHOOTING_END"
    },
    [world.event.S_EVENT_MARK_ADDED] = {
        Order = 1,
        Side = "I",
        Event = "OnEventMarkAdded",
        Text = "S_EVENT_MARK_ADDED"
    },
    [world.event.S_EVENT_MARK_CHANGE] = {
        Order = 1,
        Side = "I",
        Event = "OnEventMarkChange",
        Text = "S_EVENT_MARK_CHANGE"
    },
    [world.event.S_EVENT_MARK_REMOVED] = {
        Order = 1,
        Side = "I",
        Event = "OnEventMarkRemoved",
        Text = "S_EVENT_MARK_REMOVED"
    }
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
  if type(obj) ~= 'table' then return type(obj) end
  local i = 1
  for _ in pairs(obj) do
    if obj[i] ~= nil then i = i + 1 else return 'table' end
  end
  if i == 1 then return 'table' else return 'array' end
end

local function escape_str(s)
  local in_char  = {'\\', '"', '/', '\b', '\f', '\n', '\r', '\t'}
  local out_char = {'\\', '"', '/',  'b',  'f',  'n',  'r',  't'}
  for i, c in ipairs(in_char) do
    s = s:gsub(c, '\\' .. out_char[i])
  end
  return s
end

-- Returns pos, did_find; there are two cases:
-- 1. Delimiter found: pos = pos after leading space + delim; did_find = true.
-- 2. Delimiter not found: pos = pos after leading space;     did_find = false.
-- This throws an error if err_if_missing is true and the delim is not found.
local function skip_delim(str, pos, delim, err_if_missing)
  pos = pos + #str:match('^%s*', pos)
  if str:sub(pos, pos) ~= delim then
    if err_if_missing then
      error('Expected ' .. delim .. ' near position ' .. pos)
    end
    return pos, false
  end
  return pos + 1, true
end

-- Expects the given pos to be the first character after the opening quote.
-- Returns val, pos; the returned pos is after the closing quote character.
local function parse_str_val(str, pos, val)
  val = val or ''
  local early_end_error = 'End of input found while parsing string.'
  if pos > #str then error(early_end_error) end
  local c = str:sub(pos, pos)
  if c == '"'  then return val, pos + 1 end
  if c ~= '\\' then return parse_str_val(str, pos + 1, val .. c) end
  -- We must have a \ character.
  local esc_map = {b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
  local nextc = str:sub(pos + 1, pos + 1)
  if not nextc then error(early_end_error) end
  return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
end

-- Returns val, pos; the returned pos is after the number's final character.
local function parse_num_val(str, pos)
  local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
  local val = tonumber(num_str)
  if not val then error('Error parsing number at position ' .. pos .. '.') end
  return val, pos + #num_str
end


-- Public values and functions.

function veaf.json.stringify(obj, as_key)
  local s = {}  -- We'll build the string as an array of strings to be concatenated.
  local kind = kind_of(obj)  -- This is 'array' if it's an array or type(obj) otherwise.
  if kind == 'array' then
    if as_key then error('Can\'t encode array as key.') end
    s[#s + 1] = '['
    for i, val in ipairs(obj) do
      if i > 1 then s[#s + 1] = ', ' end
      s[#s + 1] = veaf.json.stringify(val)
    end
    s[#s + 1] = ']'
  elseif kind == 'table' then
    if as_key then error('Can\'t encode table as key.') end
    s[#s + 1] = '{'
    for k, v in pairs(obj) do
      if #s > 1 then s[#s + 1] = ', ' end
      s[#s + 1] = veaf.json.stringify(k, true)
      s[#s + 1] = ':'
      s[#s + 1] = veaf.json.stringify(v)
    end
    s[#s + 1] = '}'
  elseif kind == 'string' then
    return '"' .. escape_str(obj) .. '"'
  elseif kind == 'number' then
    if as_key then return '"' .. tostring(obj) .. '"' end
    return tostring(obj)
  elseif kind == 'boolean' then
    return tostring(obj)
  elseif kind == 'nil' then
    return 'null'
  else
    return '"Unjsonifiable type: ' .. kind .. '."'
    --error('Unjsonifiable type: ' .. kind .. '.')
  end
  return table.concat(s)
end

veaf.json.null = {}  -- This is a one-off table to represent the null value.

function veaf.json.parse(str, pos, end_delim)
  pos = pos or 1
  if pos > #str then error('Reached unexpected end of input.') end
  local pos = pos + #str:match('^%s*', pos)  -- Skip whitespace.
  local first = str:sub(pos, pos)
  if first == '{' then  -- Parse an object.
    local obj, key, delim_found = {}, true, true
    pos = pos + 1
    while true do
      key, pos = veaf.json.parse(str, pos, '}')
      if key == nil then return obj, pos end
      if not delim_found then error('Comma missing between object items.') end
      pos = skip_delim(str, pos, ':', true)  -- true -> error if missing.
      obj[key], pos = veaf.json.parse(str, pos)
      pos, delim_found = skip_delim(str, pos, ',')
    end
  elseif first == '[' then  -- Parse an array.
    local arr, val, delim_found = {}, true, true
    pos = pos + 1
    while true do
      val, pos = veaf.json.parse(str, pos, ']')
      if val == nil then return arr, pos end
      if not delim_found then error('Comma missing between array items.') end
      arr[#arr + 1] = val
      pos, delim_found = skip_delim(str, pos, ',')
    end
  elseif first == '"' then  -- Parse a string.
    return parse_str_val(str, pos + 1)
  elseif first == '-' or first:match('%d') then  -- Parse a number.
    return parse_num_val(str, pos)
  elseif first == end_delim then  -- End of an object or array.
    return nil, pos + 1
  else  -- Parse true, false, or null.
    local literals = {['true'] = true, ['false'] = false, ['null'] = veaf.json.null}
    for lit_str, lit_val in pairs(literals) do
      local lit_end = pos + #lit_str - 1
      if str:sub(pos, lit_end) == lit_str then return lit_val, lit_end + 1 end
    end
    local pos_info_str = 'position ' .. pos .. ': ' .. str:sub(pos, pos + 10)
    error('Invalid json syntax starting at ' .. pos_info_str)
  end
end

--- efficiently remove elements from a table
--- credit : Mitch McMabers (https://stackoverflow.com/questions/12394841/safely-remove-items-from-an-array-table-while-iterating)
function veaf.arrayRemoveWhen(t, fnKeep)
    local pristine = true    
    local j, n = 1, #t;
    for i=1,n do
        if (fnKeep(t, i, j)) then
            if (i ~= j) then
                -- Keep i's value, move it to j's pos.
                t[j] = t[i];
                t[i] = nil;
            else
                -- Keep i's value, already at j's pos.
            end
            j = j + 1;
        else
            t[i] = nil;
            pristine = false
        end
    end
    return not pristine;
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
    for key,value in pairs(getmetatable(o)) do
       text = text .. " - ".. key.."\n";
    end
	return text
end

function veaf.serialize(name, value, level)
    -- mostly based on slMod serializer 
  
    local function _basicSerialize(s)
      if s == nil then
        return "\"\""
      else
        if ((type(s) == 'number') or (type(s) == 'boolean') or (type(s) == 'function') or (type(s) == 'table') or (type(s) == 'userdata') ) then
          return tostring(s)
        elseif type(s) == 'string' then
          return string.format('%q', s)
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
            for k in pairs(value) do table.insert(tkeys, k) end
            -- sort the keys
            table.sort(tkeys, _sortNumberOrCaseInsensitive)
            -- use the keys to retrieve the values in the sorted order
            for _, k in ipairs(tkeys) do  -- serialize its fields
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
                local sta, res = pcall(o[field],o)
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
        for _, field in pairs(fields) do
            if o[field] then
                if type(o[field]) == "function" then
                    local sta, res = pcall(o[field],o)
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

function veaf.p(o, level, skip)
    if o and type(o) == "table" and (o.x and o.z and o.y and #o == 3) then
        return string.format("{x=%s, z=%s, y=%s}", veaf.p(o.x), veaf.p(o.z), veaf.p(o.y))
    elseif o and type(o) == "table" and (o.x and o.y and #o == 2)  then
        return string.format("{x=%s, y=%s}", veaf.p(o.x), veaf.p(o.y))
    end
    local skip = skip
    if skip and type(skip)=="table" then
        for _, value in ipairs(skip) do
            skip[value]=true
        end
    end
    return veaf._p(o, level, skip)
end

function veaf._p(o, level, skip)
    local MAX_LEVEL = 20
    if level == nil then level = 0 end
    if level > MAX_LEVEL then 
        veaf.loggers.get(veaf.Id):error("max depth reached in veaf.p : "..tostring(MAX_LEVEL))
        return ""
    end
    local text = ""
    if (type(o) == "table") then
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
            for i=0, level do
                text = text .. " "
            end
            if not (skip and skip[key]) then
                text = text .. ".".. key.."="..veaf.p(value, level+1, skip) .. "\n"
            else
                text = text .. ".".. key.."= [[SKIPPED]]\n"
            end
        end
    elseif (type(o) == "function") then
        text = "[function]"
    elseif (type(o) == "boolean") then
        if o == true then 
            text = "[true]"
        else
            text = "[false]"
        end
    else
        if o == nil then
            text = "[nil]"   
        else
            text = tostring(o)
        end
    end
    return text
end

function veaf.length(T)
    local count = 0
    if T ~= nil then
        for _ in pairs(T) do count = count + 1 end
    end
    return count
end

--- Simple round
function veaf.round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
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
    local vec2 = {x = vec3.x, y = vec3.z}
    veaf.loggers.get(veaf.Id):trace(string.format("getLandHeight: vec2  x=%.1f z=%.1f", vec3.x, vec3.z))
    -- We add 1 m "safety margin" because data from getlandheight gives the surface and wind at or below the surface is zero!
    local height = math.floor(land.getHeight(vec2) + 1)
    veaf.loggers.get(veaf.Id):trace(string.format("getLandHeight: result  height=%.1f",height))
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

-- get a LL position based on a string 
-- can be UTM (U38TMP334456 or u37TMP4351)
-- can be LL with either : or - as a separator, and either DMS, DM decimal, or D decimal (N42:23:45E044-12.5 or N42.3345E044-12.5)
function veaf.computeLLFromString(value)
    local function _computeLLValueFromString(value)
        local result = -1
        if value:find(":") or value:find("-") then
            -- convert in arc-seconds
            local values = veaf.splitWithPattern(value, "[:-]+")
            local weights = {3600, 60, 1}
            for _, element in pairs(values) do
                veaf.loggers.get(veaf.Id):trace(string.format("element=%s",veaf.p(element)))
                local weight = table.remove(weights, 1)
                local elementInArcSec = tonumber(element)*weight
                result = result + elementInArcSec
            end
            result = result / 3600
        else
            -- decimals
            result = tonumber(value)
        end
        return result
    end
    
    local result = -1
    if value then
        local _value = value:lower()
        local _firstChar = _value:sub(1,1)
        if _firstChar == "u" then
            -- UTM coordinates
            local _zone, _digraph, _digits = _value:match("u(%d%d[a-z])([a-z][a-z])(%d+)")
            veaf.loggers.get(veaf.Id):trace(string.format("_zone=%s",veaf.p(_zone)))
            veaf.loggers.get(veaf.Id):trace(string.format("_digraph=%s",veaf.p(_digraph)))
            veaf.loggers.get(veaf.Id):trace(string.format("_digits=%s",veaf.p(_digits)))
            if _zone and _digraph and _digits then
                local _nDigits = #_digits
                local _northingString = _digits:sub(_nDigits/2+1)
                local _northing = tonumber(_northingString)
                veaf.loggers.get(veaf.Id):trace(string.format("_northing=%s",veaf.p(_northing)))
                if #_northingString == 1 then
                    _northing = _northing * 10000
                elseif #_northingString == 2 then
                    _northing = _northing * 1000
                elseif #_northingString == 3 then
                    _northing = _northing * 100
                elseif #_northingString == 4 then
                    _northing = _northing * 10
                end

                local _eastingString = _digits:sub(1, _nDigits/2)
                local _easting = tonumber(_eastingString)
                veaf.loggers.get(veaf.Id):trace(string.format("_easting=%s",veaf.p(_easting)))
                if #_eastingString == 1 then
                    _easting = _easting * 10000
                elseif #_eastingString == 2 then
                    _easting = _easting * 1000
                elseif #_eastingString == 3 then
                    _easting = _easting * 100
                elseif #_eastingString == 4 then
                    _easting = _easting * 10
                end

                local _utm= { UTMZone = _zone:upper(), MGRSDigraph = _digraph:upper(), Easting = _easting, Northing = _northing }  
                veaf.loggers.get(veaf.Id):trace(string.format("_utm=%s",veaf.p(_utm)))
                return coord.MGRStoLL(_utm)
            end
        elseif _firstChar == "n" or _firstChar == "s" or _firstChar == "e" or _firstChar == "w" then
            -- LL coordinates
            local _signLat, _digitsLat, _signLon, _digitsLon = _value:match([[([news])([%d:\.-]+)([news])([%d:\.-]+)]])
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
    -- unrecognized format
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
    veaf.loggers.get(veaf.Id):trace(string.format("getLandHeight: result  height=%.1f",height))
    local result={x=vec3.x, y=height, z=vec3.z}
    veaf.loggers.get(veaf.Id):trace(string.format("placePointOnLand: result  x=%.1f y=%.1f, z=%.1f", result.x, result.y, result.z))
    return result
end

--- Trim a string
function veaf.trim(s)
    local a = s:match('^%s*()')
    local b = s:match('()%s*$', a)
    return s:sub(a,b-1)
end

--- Split string. C.f. http://stackoverflow.com/questions/1426954/split-string-in-lua
function veaf.splitWithPattern(str, pat)
    local t = {}  -- NOTE: use {n = 0} in Lua-5.0
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)
    while s do
        if s ~= 1 or cap ~= "" then
            table.insert(t, cap)
        end
        last_end = e+1
        s, e, cap = str:find(fpat, last_end)
    end
    if last_end <= #str then
        cap = str:sub(last_end)
        table.insert(t, cap)
    end
    return t
end

function veaf.split(str, sep)
    local result = {}
    local regex = ("([^%s]+)"):format(sep)
    for each in str:gmatch(regex) do
        table.insert(result, each)
    end
    return result
end

--- Break string around a separator
function veaf.breakString(str, sep)
    local regex = ("^([^%s]+)%s(.*)$"):format(sep, sep)
    local a, b = str:match(regex)
    if not a then a = str end
    local result = {a, b}
    return result
end

--- Get the average center of a group position (average point of all units position)
function veaf.getAveragePosition(group)
    if type(group) == "string" then 
        group = Group.getByName(group)
    end

    local count

	local totalPosition = {x = 0,y = 0,z = 0}
	if group then
		local units = Group.getUnits(group)
		for count = 1,#units do
			if units[count] then 
				totalPosition = mist.vec.add(totalPosition,Unit.getPosition(units[count]).p)
			end
		end
		if #units > 0 then
			return mist.vec.scalar_mult(totalPosition,1/#units)
		else
			return nil
		end
	else
		return nil
	end
end

function veaf.emptyFunction()
end

--- Returns the wind direction (from) and strength.
function veaf.getWind(point)

    -- Get wind velocity vector.
    local windvec3  = atmosphere.getWind(point)
    local direction = math.floor(math.deg(math.atan2(windvec3.z, windvec3.x)))
    
    if direction < 0 then
      direction = direction + 360
    end
    
    -- Convert TO direction to FROM direction. 
    if direction > 180 then
      direction = direction-180
    else
      direction = direction+180
    end
    
    -- Calc 2D strength.
    local strength=math.floor(math.sqrt((windvec3.x)^2+(windvec3.z)^2))
    
    -- Debug output.
    veaf.loggers.get(veaf.Id):trace(string.format("Wind data: point x=%.1f y=%.1f, z=%.1f", point.x, point.y,point.z))
    veaf.loggers.get(veaf.Id):trace(string.format("Wind data: wind  x=%.1f y=%.1f, z=%.1f", windvec3.x, windvec3.y,windvec3.z))
    veaf.loggers.get(veaf.Id):trace(string.format("Wind data: |v| = %.1f", strength))
    veaf.loggers.get(veaf.Id):trace(string.format("Wind data: ang = %.1f", direction))
    
    -- Return wind direction and strength (in m/s).
    return direction, strength, windvec3
  end

--- Find a suitable point for spawning a unit in a <dispersion>-sized circle around a spot
function veaf.findPointInZone(spawnSpot, dispersion, isShip)
    local unitPosition
    local tryCounter = 1000
    local _dispersion = 0
    repeat -- Place the unit in a "dispersion" ft radius circle from the spawn spot
        unitPosition = mist.getRandPointInCircle(spawnSpot, _dispersion)
        local landType = land.getSurfaceType(unitPosition)
        tryCounter = tryCounter - 1
        _dispersion = _dispersion + dispersion
    until ((isShip and landType == land.SurfaceType.WATER) or (not(isShip) and (landType == land.SurfaceType.LAND or landType == land.SurfaceType.ROAD or landType == land.SurfaceType.RUNWAY))) or tryCounter == 0
    if tryCounter == 0 then
        return nil
    else
        return unitPosition
    end
end

--- TODO doc
function veaf.generateVehiclesRoute(startPoint, destination, onRoad, speed, patrol)
    veaf.loggers.get(veaf.Id):trace(string.format("veaf.generateVehiclesRoute(onRoad=[%s], speed=[%s], patrol=[%s])", tostring(onRoad or ""), tostring(speed or ""), tostring(patrol or "")))

    speed = speed or veaf.DEFAULT_GROUND_SPEED_KPH
    onRoad = onRoad or false
    patrol = patrol or false
    veaf.loggers.get(veaf.Id):trace(string.format("startPoint = {x = %d, y = %d, z = %d}", startPoint.x, startPoint.y, startPoint.z))
    local action = "Diamond"
    if onRoad then
        action = "On Road"
    end

    local endPoint = veafNamedPoints.getPoint(destination)
    if not(endPoint) then
        -- check if these are coordinates
        local _lat, _lon = veaf.computeLLFromString(destination)
        veaf.loggers.get(veaf.Id):trace(string.format("_lat=%s",veaf.p(_lat)))
        veaf.loggers.get(veaf.Id):trace(string.format("_lon=%s",veaf.p(_lon)))
        if _lat and _lon then 
            endPoint = coord.LLtoLO(_lat, _lon)
        end
    end
    if not(endPoint) then
        local msg = "A point named "..destination.." cannot be found, and these are not valid coordinates !"
        veaf.loggers.get(veaf.Id):warn(msg)
        trigger.action.outText(msg, 5)
        return
    end
    veaf.loggers.get(veaf.Id):trace(string.format("endPoint=%s", veaf.p(endPoint)))
        
    if onRoad then
        veaf.loggers.get(veaf.Id):trace("setting startPoint on a road")
        local road_x, road_z = land.getClosestPointOnRoads('roads',startPoint.x, startPoint.z)
        startPoint = veaf.placePointOnLand({x = road_x, y = 0, z = road_z})
    else
        startPoint = veaf.placePointOnLand({x = startPoint.x, y = 0, z = startPoint.z})
    end
    
    veaf.loggers.get(veaf.Id):trace(string.format("startPoint = {x = %d, y = %d, z = %d}", startPoint.x, startPoint.y, startPoint.z))

    if onRoad then
        veaf.loggers.get(veaf.Id):trace("setting endPoint on a road")
        road_x, road_z =land.getClosestPointOnRoads('roads',endPoint.x, endPoint.z)
        endPoint = veaf.placePointOnLand({x = road_x, y = 0, z = road_z})
    else
        endPoint = veaf.placePointOnLand({x = endPoint.x, y = 0, z = endPoint.z})
    end
    veaf.loggers.get(veaf.Id):trace(string.format("endPoint = {x = %d, y = %d, z = %d}", endPoint.x, endPoint.y, endPoint.z))
    
    local vehiclesRoute = {
        [1] = 
        {
            ["x"] = startPoint.x,
            ["y"] = startPoint.z,
            ["alt"] = startPoint.y,
            ["type"] = "Turning Point",
            ["ETA"] = 0,
            ["alt_type"] = "BARO",
            ["formation_template"] = "",
            ["name"] = "STA",
            ["ETA_locked"] = true,
            ["speed"] = speed / 3.6,
            ["action"] = action,
            ["task"] = 
            {
                ["id"] = "ComboTask",
                ["params"] = 
                {
                    ["tasks"] = 
                    {
                    }, -- end of ["tasks"]
                }, -- end of ["params"]
            }, -- end of ["task"]
            ["speed_locked"] = true,
        }, -- end of [1]
        [2] = 
        {
            ["x"] = endPoint.x,
            ["y"] = endPoint.z,
            ["alt"] = endPoint.y,
            ["type"] = "Turning Point",
            ["ETA"] = 0,
            ["alt_type"] = "BARO",
            ["formation_template"] = "",
            ["name"] = "END",
            ["ETA_locked"] = false,
            ["speed"] = speed / 3.6,
            ["action"] = action,
            ["speed_locked"] = true,
        }, -- end of [2]
    }

    if patrol then
        vehiclesRoute[3] = 
        {
            ["x"] = startPoint.x,
            ["y"] = startPoint.z,
            ["alt"] = startPoint.y,
            ["type"] = "Turning Point",
            ["ETA"] = 0,
            ["alt_type"] = "BARO",
            ["formation_template"] = "",
            ["name"] = "STA",
            ["ETA_locked"] = true,
            ["speed"] = speed / 3.6,
            ["action"] = action,
            ["task"] = 
            {
                ["id"] = "ComboTask",
                ["params"] = 
                {
                    ["tasks"] = 
                    {
                        [1] = 
                        {
                            ["enabled"] = true,
                            ["auto"] = false,
                            ["id"] = "GoToWaypoint",
                            ["number"] = 1,
                            ["params"] = 
                            {
                                ["fromWaypointIndex"] = 3,
                                ["nWaypointIndx"] = 1,
                            }, -- end of ["params"]
                        }, -- end of [1]
                    }, -- end of ["tasks"]
                }, -- end of ["params"]
            }, -- end of ["task"]
            ["speed_locked"] = true,
        }
    end
    veaf.loggers.get(veaf.Id):trace(string.format("vehiclesRoute = %s", veaf.p(vehiclesRoute)))

    return vehiclesRoute
end


--- Add a unit to the <group> on a suitable point in a <dispersion>-sized circle around a spot
function veaf.addUnit(group, spawnSpot, dispersion, unitType, unitName, skill)
    local unitPosition = veaf.findPointInZone(spawnSpot, dispersion, false)
    if unitPosition ~= nil then
        table.insert(
            group,
            {
                ["x"] = unitPosition.x,
                ["y"] = unitPosition.y,
                ["type"] = unitType,
                ["name"] = unitName,
                ["heading"] = 0,
                ["skill"] = skill
            }
        )
    else
        veaf.loggers.get(veaf.Id):info("cannot find a suitable position for unit "..unitType)
    end
end

--- Makes a group move to a waypoint set at a specific heading and at a distance covered at a specific speed in an hour
function veaf.moveGroupAt(groupName, leadUnitName, heading, speed, timeInSeconds, endPosition, pMiddlePointDistance)
    veaf.loggers.get(veaf.Id):debug("veaf.moveGroupAt(groupName=" .. groupName .. ", heading="..heading.. ", speed=".. speed..", timeInSeconds="..(timeInSeconds or 0))

    local unitGroup = Group.getByName(groupName)
    if unitGroup == nil then
        veaf.loggers.get(veaf.Id):error("veaf.moveGroupAt: " .. groupName .. ' not found')
		return false
    end
    
    local leadUnit = unitGroup:getUnits()[1]
    if leadUnitName then
        leadUnit = Unit.getByName(leadUnitName)
    end
    if leadUnit == nil then
        veaf.loggers.get(veaf.Id):error("veaf.moveGroupAt: " .. leadUnitName .. ' not found')
		return false
    end
    
    local headingRad = mist.utils.toRadian(heading)
    veaf.loggers.get(veaf.Id):trace("headingRad="..headingRad)
    local fromPosition = leadUnit:getPosition().p
    fromPosition = { x = fromPosition.x, y = fromPosition.z }
    veaf.loggers.get(veaf.Id):trace("fromPosition="..veaf.vecToString(fromPosition))

    local mission = { 
		id = 'Mission', 
		params = { 
			["communication"] = true,
			["start_time"] = 0,
			route = { 
				points = { 
					-- first point
                    [1] = 
                    {
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
			} 
		} 
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
        veaf.loggers.get(veaf.Id):trace("newWaypoint1="..veaf.vecToString(newWaypoint1))

        table.insert(mission.params.route.points, 
            {
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
            }
        )
    end

    local length
    if timeInSeconds then 
        length = speed * timeInSeconds
    else
        length = speed * 3600 -- m travelled in 1 hour
    end
    veaf.loggers.get(veaf.Id):trace("length="..length .. " m")

    -- new route point
	local newWaypoint2 = {
		x = fromPosition.x + length * math.cos(headingRad),
		y = fromPosition.y + length * math.sin(headingRad),
	}
    veaf.loggers.get(veaf.Id):trace("newWaypoint2="..veaf.vecToString(newWaypoint2))

    table.insert(mission.params.route.points, 
        {
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
        }
    )

    if endPosition then
        table.insert(mission.params.route.points, 
            {
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
            }
        )
    end

	-- replace whole mission
	unitGroup:getController():setTask(mission)
    
    return true
end

veaf.defaultAlarmState = 2

function veaf.readyForCombat(group, alarm, disperseTime)
    veaf.loggers.get(veaf.Id):trace(string.format("group=%s, alarm=%s, disperseTime=%s", veaf.p(group), veaf.p(alarm), veaf.p(disperseTime)))
    if type(group) == 'string' then
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
    if not(altitude) then
        altitude = 0
    end
    veaf.loggers.get(veaf.Id):debug("veaf.moveGroupTo(groupName=" .. groupName .. ", speed=".. speed .. ", altitude=".. altitude)
    veaf.loggers.get(veaf.Id):debug("pos="..veaf.vecToString(pos))

	local unitGroup = Group.getByName(groupName)
    if unitGroup == nil then
        veaf.loggers.get(veaf.Id):error("veaf.moveGroupTo: " .. groupName .. ' not found')
		return false
    end
    
    local route = {
        [1] =
        {
            ["alt"] = altitude,
            ["action"] = "Turning Point",
            ["alt_type"] = "BARO",
            ["speed"] = veaf.round(speed, 2),
            ["type"] = "Turning Point",
            ["x"] = pos.x,
            ["y"] = pos.z,
            ["speed_locked"] = true,
        },
        [2] = 
        {
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
	if type(groupName) == 'string' and Group.getByName(groupName) and Group.getByName(groupName):isExist() == true then
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
    veaf.loggers.get(veaf.Id):trace("startingPoint="..veaf.vecToString(startingPoint))
    veaf.loggers.get(veaf.Id):trace("destinationPoint="..veaf.vecToString(destinationPoint))
    
    local vecAB = {x = destinationPoint.x +- startingPoint.x, y = destinationPoint.y - startingPoint.y, z = destinationPoint.z - startingPoint.z}
    veaf.loggers.get(veaf.Id):trace("vecAB="..veaf.vecToString(vecAB))
    local alpha = math.atan2(vecAB.x, vecAB.z) -- atan2(y, x) 
    veaf.loggers.get(veaf.Id):trace("alpha="..alpha)
    local r = math.sqrt(distanceFromStartingPoint * distanceFromStartingPoint + offset * offset)
    veaf.loggers.get(veaf.Id):trace("r="..r)
    local beta = math.atan(offset / distanceFromStartingPoint)
    veaf.loggers.get(veaf.Id):trace("beta="..beta)
    local tho = alpha + beta
    veaf.loggers.get(veaf.Id):trace("tho="..tho)
    local offsetPoint = { z = r * math.cos(tho) + startingPoint.z, y = 0, x = r * math.sin(tho) + startingPoint.x}
    veaf.loggers.get(veaf.Id):trace("offsetPoint="..veaf.vecToString(offsetPoint))
    local offsetPointOnLand = veaf.placePointOnLand(offsetPoint)
    veaf.loggers.get(veaf.Id):trace("offsetPointOnLand="..veaf.vecToString(offsetPointOnLand))

    return offsetPointOnLand, offsetPoint
end

function veaf.getBearingAndRangeFromTo(fromPoint, toPoint)
    veaf.loggers.get(veaf.Id):trace("fromPoint="..veaf.vecToString(fromPoint))
    veaf.loggers.get(veaf.Id):trace("toPoint="..veaf.vecToString(toPoint))
    
    local vec = { z = toPoint.z - fromPoint.z, x = toPoint.x - fromPoint.x}
    local angle = mist.utils.round(mist.utils.toDegree(mist.utils.getDir(vec)), 0)
    local distance = mist.utils.get2DDist(toPoint, fromPoint)
    return angle, distance, mist.utils.round(distance / 1000, 0), mist.utils.round(mist.utils.metersToNM(distance), 0)
end

function veaf.getGroupsOfCoalition(coa)
    local coalitions = { coalition.side.RED, coalition.side.BLUE, coalition.side.NEUTRAL}
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
    local coalitions = { coalition.side.RED, coalition.side.BLUE, coalition.side.NEUTRAL}
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

function veaf.findUnitsInCircle(center, radius, includeStatics, onlyTheseUnits)
    veaf.loggers.get(veaf.Id):trace(string.format("findUnitsInCircle(radius=%s)", tostring(radius)))
    veaf.loggers.get(veaf.Id):trace(string.format("center=%s", veaf.p(center)))

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
            distanceFromCenter = ((pos.x - center.x)^2 + (pos.z - center.z)^2)^0.5
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
            veaf.loggers.get(veaf.Id):info(groupIdent..' not found in mist.DBs.MEgroupsByName')
        end

    for coa_name, coa_data in pairs(env.mission.coalition) do
        if (coa_name == 'red' or coa_name == 'blue') and type(coa_data) == 'table' then
            if coa_data.country then --there is a country table
                for cntry_id, cntry_data in pairs(coa_data.country) do
                    for obj_type_name, obj_type_data in pairs(cntry_data) do
                        if obj_type_name == "helicopter" or obj_type_name == "ship" or obj_type_name == "plane" or obj_type_name == "vehicle" then	-- only these types have points
                            if ((type(obj_type_data) == 'table') and obj_type_data.group and (type(obj_type_data.group) == 'table') and (#obj_type_data.group > 0)) then	--there's a group!
                                for group_num, group_data in pairs(obj_type_data.group) do
                                    if group_data and group_data.groupId == gpId	then -- this is the group we are looking for
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
    
    veaf.loggers.get(veaf.Id):info(' no group data found for '..groupIdent)
    return nil
end

function veaf.findInTable(data, key)
    local result = nil
    if data then
        result = data[key]
    end
    if result then 
        veaf.loggers.get(veaf.Id):trace(".findInTable found ".. key)
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
                    if (tasks) then
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

function veaf.outTextForUnit(unitName, message, duration)
    local groupId = nil
    if unitName then
    local unit = Unit.getByName(unitName)
    if unit then 
        local group = unit:getGroup()
        if group then 
            groupId = group:getID()
        end
    end
    end
    if groupId then 
        trigger.action.outTextForGroup(groupId, message, duration)
    else
        trigger.action.outText(message, duration)
    end
end

--- Weather Report. Report pressure QFE/QNH, temperature, wind at certain location.
--- stolen from the weatherReport script and modified to fit our usage
function veaf.weatherReport(vec3, alt, withLASTE)
     
    -- Get Temperature [K] and Pressure [Pa] at vec3.
    local T
    local Pqfe
    if not alt then
        alt = veaf.getLandHeight(vec3)
    end

    -- At user specified altitude.
    T,Pqfe=atmosphere.getTemperatureAndPressure({x=vec3.x, y=alt, z=vec3.z})
    veaf.loggers.get(veaf.Id):trace(string.format("T = %.1f, Pqfe = %.2f", T,Pqfe))
    
    -- Get pressure at sea level.
    local _,Pqnh=atmosphere.getTemperatureAndPressure({x=vec3.x, y=0, z=vec3.z})
    veaf.loggers.get(veaf.Id):trace(string.format("Pqnh = %.2f", Pqnh))
    
    -- Convert pressure from Pascal to hecto Pascal.
    Pqfe=Pqfe/100
    Pqnh=Pqnh/100 
     
    -- Pressure unit conversion hPa --> mmHg or inHg
    local _Pqnh=string.format("%.2f mmHg (%.2f inHg)", Pqnh * weathermark.hPa2mmHg, Pqnh * weathermark.hPa2inHg)
    local _Pqfe=string.format("%.2f mmHg (%.2f inHg)", Pqfe * weathermark.hPa2mmHg, Pqfe * weathermark.hPa2inHg)
   
    -- Temperature unit conversion: Kelvin to Celsius or Fahrenheit.
    T=T-273.15
    local _T=string.format('%d°C (%d°F)', T, weathermark._CelsiusToFahrenheit(T))
  
    -- Get wind direction and speed.
    local Dir,Vel=weathermark._GetWind(vec3, alt)
    veaf.loggers.get(veaf.Id):trace(string.format("Dir = %.1f, Vel = %.1f", Dir,Vel))

    -- Get Beaufort wind scale.
    local Bn,Bd=weathermark._BeaufortScale(Vel)
    
    -- Formatted wind direction.
    local Ds = string.format('%03d°', Dir)
      
    -- Velocity in player units.
    local Vs=string.format('%.1f m/s (%.1f kn)', Vel, Vel * weathermark.mps2knots) 
    
    -- Altitude.
    local _Alt=string.format("%d m (%d ft)", alt, alt * weathermark.meter2feet)
      
    local text="" 
    text=text..string.format("Altitude %s ASL\n",_Alt)
    text=text..string.format("QFE %.2f hPa = %s\n", Pqfe,_Pqfe)
    text=text..string.format("QNH %.2f hPa = %s\n", Pqnh,_Pqnh)
    text=text..string.format("Temperature %s\n",_T)
    if Vel > 0 then
        text=text..string.format("Wind from %s at %s (%s)", Ds, Vs, Bd)
    else
        text=text.."No wind"
    end

    local function getLASTEat(vec3, alt)
        local T,_=atmosphere.getTemperatureAndPressure({x=vec3.x, y=alt, z=vec3.z})
        local Dir,Vel=weathermark._GetWind(vec3, alt)
        local laste = string.format("\nFL%02d W%03d/%02d T%d", alt * weathermark.meter2feet / 1000, Dir, Vel * weathermark.mps2knots, T-273.15)
        return laste
    end

    if withLASTE then
        text=text.."\n\nLASTE:"
        text=text..getLASTEat(vec3, math.floor(((alt * weathermark.meter2feet + 2000)/1000)*1000+500)/weathermark.meter2feet)
        text=text..getLASTEat(vec3, math.floor(((alt * weathermark.meter2feet + 8000)/1000)*1000+500)/weathermark.meter2feet)
        text=text..getLASTEat(vec3, math.floor(((alt * weathermark.meter2feet + 16000)/1000)*1000+500)/weathermark.meter2feet)
        --text=text..getLASTEat(vec3, _Alt + 7500)
    end

    return text
end

local function _initializeCountriesAndCoalitions()
    veaf.countriesByCoalition={}
    veaf.coalitionByCountry={}

    local function _sortByImportance(c1,c2)
        local importantCountries = { ['usa']=true, ['russia']=true}
        if c1 then
            return importantCountries[c1:lower()]
        end
        return string.lower(c1) < string.lower(c2)
    end

    for coalitionName, countries in pairs(mist.DBs.units) do
        coalitionName = coalitionName:lower()
        veaf.loggers.get(veaf.Id):trace(string.format("coalitionName=%s", veaf.p(coalitionName)))

        if not veaf.countriesByCoalition[coalitionName] then 
            veaf.countriesByCoalition[coalitionName]={} 
        end
        for countryName, _ in pairs(countries) do
            countryName = countryName:lower()
            table.insert(veaf.countriesByCoalition[coalitionName], countryName)
            veaf.coalitionByCountry[countryName]=coalitionName:lower()
        end

        table.sort(veaf.countriesByCoalition[coalitionName], _sortByImportance)
    end

    veaf.loggers.get(veaf.Id):trace(string.format("veaf.countriesByCoalition=%s", veaf.p(veaf.countriesByCoalition)))
    veaf.loggers.get(veaf.Id):trace(string.format("veaf.coalitionByCountry=%s", veaf.p(veaf.coalitionByCountry)))
end

function veaf.getCountryId(countryName)
    veaf.loggers.get(veaf.Id):trace("veaf.getCountryId(%s)", veaf.p(countryName))
    local countryName = string.lower(countryName or "")
    for id, name in pairs(country.name) do
        if name:lower() == countryName then
            return id
        end
    end
    return 0
end

function veaf.getCountryForCoalition(coalition)
    veaf.loggers.get(veaf.Id):trace(string.format("veaf.getCountryForCoalition(coalition=%s)", tostring(coalition)))
    local coalition = coalition
    if not coalition then 
        coalition = 1 
    end

    local coalitionName = nil
    if type(coalition) == "number" then
        if coalition == 1 then 
            coalitionName = "red" 
        elseif coalition == 2 then 
            coalitionName = "blue" 
        else
            coalitionName = "neutral" 
        end
    else
        coalitionName = tostring(coalition)
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
    veaf.loggers.get(veaf.Id):trace(string.format("veaf.getCoalitionForCountry(countryName=%s, asNumber=%s)", tostring(countryName), tostring(asNumber)))

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
        if result == 'neutral' then result = 0 end
        if result == 'red' then result = 1 end
        if result == 'blue' then result = 2 end
    end
    return result
end

function veaf.getAirbaseForCoalition(airbase_name, coa)
    local airbase = nil
    
    veaf.loggers.get(veaf.Id):trace(string.format("veaf.getAirbaseforCoalition(airbase_name = %s, coa = %s)", veaf.p(airbase_name), veaf.p(coa)))
    if coa and airbase_name then

        if type(coa) == 'string' then 
            if coa:lower() == "red" then 
                coa = coalition.side.RED
            elseif coa:lower() == "blue" then
                coa = coalition.side.BLUE
            end
        end
        veaf.loggers.get(veaf.Id):trace(string.format("final coalition is = %s", veaf.p(coa)))

        if (coa == coalition.side.RED or coa == coalition.side.BLUE) and type(airbase_name) == 'string' then
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

    for _,airbase in pairs(airbases) do
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
    veaf.loggers.get(veaf.Id):trace(string.format("veaf.getAirbaseLife(airbase_name = %s, percentage = %s, loading = %s)", veaf.p(airbase_name), veaf.p(percentage), veaf.p(loading)))

    local airbase_life = -1
    local airbase_life0 = -1

    if airbase_name and type(airbase_name) == 'string' then
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
                
                if airbase_desc.attributes["AircraftCarrier"] or airbase_desc.attributes["Aircraft Carriers"] or airbase_desc.attributes["HelicopterCarrier"] then
                    local AircraftCarrier_unit = Unit.getByName(airbase_name)
                    veaf.loggers.get(veaf.Id):trace(string.format("Airbase is a Carrier Unit ID : %s", veaf.p(AircraftCarrier_unit)))
                    
                    if AircraftCarrier_unit then
                        --airbase_life0 = AircraftCarrier_unit:getLife0()  --returns 0, thanks ED, had to load them at mission start to counter this issue
                        if not airbase_life0 then 
                            airbase_life0 = veaf.STANDARD_CARRIER_LIFE0
                            veaf.loggers.get(veaf.Id):trace(string.format("Carrier doesn't have a Life0 stored yet, using default of %s", veaf.p(veaf.STANDARD_CARRIER_LIFE0)))
                        end
                        airbase_life = AircraftCarrier_unit:getLife()
                        veaf.loggers.get(veaf.Id):trace(string.format("Carrier Life : %s", veaf.p(airbase_life)))
                    end
                elseif airbase_desc.attributes["Helipad"] and not airbase_life0 then
                    airbase_life0 = veaf.STANDARD_HELIPAD_LIFE0
                    veaf.loggers.get(veaf.Id):trace(string.format("Helipad doesn't have a Life0 stored yet, using default of %s", veaf.p(veaf.STANDARD_HELIPAD_LIFE0)))
                elseif airbase_desc.attributes["Airfields"] and not airbase_life0 then
                    airbase_life0 = veaf.STANDARD_AIRBASE_LIFE0
                    veaf.loggers.get(veaf.Id):trace(string.format("Airfield doesn't have a Life0 stored yet, using default of %s", veaf.p(veaf.STANDARD_AIRBASE_LIFE0)))
                elseif airbase_desc.attributes["Buildings"] then
                    local BuildingUnit = StaticObject.getByName(airbase_name)
                    veaf.loggers.get(veaf.Id):trace(string.format("Airbase is a Building Unit ID : %s", veaf.p(BuildingUnit)))

                    if BuildingUnit then
                        if not airbase_life0 then
                            airbase_life0 = veaf.STANDARD_BUILDING_LIFE0
                            veaf.loggers.get(veaf.Id):trace(string.format("Building doesn't have a Life0 stored yet, using default of %s", veaf.p(veaf.STANDARD_BUILDING_LIFE0)))
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
                        eaf.loggers.get(veaf.Id):trace(string.format("Airbase category does not have a default life0 setting nor does it have a life, discarding"))
                    end
                end

                veaf.loggers.get(veaf.Id):trace(string.format("Airbase Life : %s, Airbase Life0 : %s", veaf.p(airbase_life), veaf.p(airbase_life0)))
            end
        end
    end

    if airbase_life0 and airbase_life0 > 0 and airbase_life and airbase_life > 0 then
        local airbase_life_percentage = airbase_life/airbase_life0
        
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

    veaf.loggers.get(veaf.Id):trace(string.format("Final Airbase (named %s) Life : %s, isPercentage = %s", veaf.p(airbase_name), veaf.p(airbase_life), veaf.p(percentage)))
    return airbase_life
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- mission restart at a certain hour of the day
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veaf._endMission(delay1, message1, delay2, message2, delay3, message3)
    veaf.loggers.get(veaf.Id):trace(string.format("veaf._endMission(delay1=%s, message1=%s, delay2=%s, message2=%s, delay3=%s, message3=%s)", veaf.p(delay1), veaf.p(message1), veaf.p(delay2), veaf.p(message2), veaf.p(delay3), veaf.p(message3)))

    if not delay1 then
        -- no more delay, let's end this !
        trigger.action.outText("Ending mission !",30)
        veaf.loggers.get(veaf.Id):info("ending mission")
        trigger.action.setUserFlag("666", 1)
    else 
        -- show the message
        trigger.action.outText(message1,30)
        -- schedule this function after "delay1" seconds
        veaf.loggers.get(veaf.Id):info(string.format("schedule veaf._endMission after %d seconds", delay1))
        mist.scheduleFunction(veaf._endMission, {delay2, message2, delay3, message3}, timer.getTime()+delay1)
    end
end

function veaf._checkForEndMission(endTimeInSeconds, checkIntervalInSeconds, checkMessage, delay1, message1, delay2, message2, delay3, message3)
    veaf.loggers.get(veaf.Id):trace(string.format("veaf._checkForEndMission(endTimeInSeconds=%s, checkIntervalInSeconds=%s, checkMessage=%s, delay1=%s, message1=%s, delay2=%s, message2=%s, delay3=%s, message3=%s)", veaf.p(endTimeInSeconds), veaf.p(checkIntervalInSeconds), veaf.p(checkMessage), veaf.p(delay1), veaf.p(message1), veaf.p(delay2), veaf.p(message2), veaf.p(delay3), veaf.p(message3)))
    
    veaf.loggers.get(veaf.Id):trace(string.format("timer.getAbsTime()=%d", timer.getAbsTime()))

    if timer.getAbsTime() >= endTimeInSeconds then
        veaf.loggers.get(veaf.Id):trace("calling veaf._endMission")
        veaf._endMission(delay1, message1, delay2, message2, delay3, message3)
    else
        -- output the message if specified
        if checkMessage then
            trigger.action.outText(checkMessage,30)
        end
        -- schedule this function after a delay
        veaf.loggers.get(veaf.Id):trace(string.format("schedule veaf._checkForEndMission after %d seconds", checkIntervalInSeconds))
        mist.scheduleFunction(veaf._checkForEndMission, {endTimeInSeconds, checkIntervalInSeconds, checkMessage, delay1, message1, delay2, message2, delay3, message3}, timer.getTime()+checkIntervalInSeconds)
    end
end

function veaf.endMissionAt(endTimeHour, endTimeMinute, checkIntervalInSeconds, checkMessage, delay1, message1, delay2, message2, delay3, message3)
    veaf.loggers.get(veaf.Id):trace(string.format("veaf.endMissionAt(endTimeHour=%s, endTimeMinute=%s, checkIntervalInSeconds=%s, checkMessage=%s, delay1=%s, message1=%s, delay2=%s, message2=%s, delay3=%s, message3=%s)", veaf.p(endTimeHour), veaf.p(endTimeMinute), veaf.p(checkIntervalInSeconds), veaf.p(checkMessage), veaf.p(delay1), veaf.p(message1), veaf.p(delay2), veaf.p(message2), veaf.p(delay3), veaf.p(message3)))

    local endTimeInSeconds = endTimeHour * 3600 + endTimeMinute * 60
    veaf.loggers.get(veaf.Id):trace(string.format("endTimeInSeconds=%d", endTimeInSeconds))
    veaf._checkForEndMission(endTimeInSeconds, checkIntervalInSeconds, checkMessage, delay1, message1, delay2, message2, delay3, message3)    
end

function veaf.randomlyChooseFrom(aTable, bias)
    veaf.loggers.get(veaf.Id):trace(string.format("randomlyChooseFrom(%d):%s",bias or 0, veaf.p(aTable)))
    local index = math.floor(math.random(1, #aTable)) + (bias or 0)
    if index < 1 then index = 1 end
    if index > #aTable then index = #aTable end
    return aTable[index]
end

function veaf.safeUnpack(package)
    if type(package) == 'table' then
        return unpack(package)
    else
        return package
    end
end

function veaf.getRandomizableNumeric_random(val)
    veaf.loggers.get(veaf.Id):trace(string.format("getRandomizableNumeric_random(%s)", tostring(val)))
    local nVal = tonumber(val)
    veaf.loggers.get(veaf.Id):trace(string.format("nVal=%s", tostring(nVal)))
    if nVal == nil then 
        --[[
        local dashPos = nil
        for i = 1, #val do
            local c = val:sub(i,i)
            if c == '-' then 
                dashPos = i
                break
            end
        end
        if dashPos then 
            local lower = val:sub(1, dashPos-1)
            veaf.loggers.get(veaf.Id):trace(string.format("lower=%s", tostring(lower)))
            if lower then 
                lower = tonumber(lower)
            end
            if lower == nil then lower = 0 end
            local upper = val:sub(dashPos+1)
            veaf.loggers.get(veaf.Id):trace(string.format("upper=%s", tostring(upper)))
            if upper then 
                upper = tonumber(upper)
            end
            if upper == nil then upper = 5 end
            nVal = math.random(lower, upper)
            veaf.loggers.get(veaf.Id):trace(string.format("random nVal=%s", tostring(nVal)))
        end
        --]]

        -- [[
        
        if val == "0-1" then nVal = math.random(1,2) end
        if val == "0-2" then nVal = math.random(1,2) end
        if val == "0-3" then nVal = math.random(1,3) end
        if val == "0-4" then nVal = math.random(1,4) end
        if val == "0-5" then nVal = math.random(1,5) end
        if val == "0-6" then nVal = math.random(1,6) end
        if val == "0-7" then nVal = math.random(1,7) end
        if val == "0-8" then nVal = math.random(1,8) end
        if val == "0-9" then nVal = math.random(1,9) end
    
        if val == "1-2" then nVal = math.random(1,2) end
        if val == "1-3" then nVal = math.random(1,3) end
        if val == "1-4" then nVal = math.random(1,4) end
        if val == "1-5" then nVal = math.random(1,5) end
        if val == "1-6" then nVal = math.random(1,6) end
        if val == "1-7" then nVal = math.random(1,7) end
        if val == "1-8" then nVal = math.random(1,8) end
        if val == "1-9" then nVal = math.random(1,9) end

        if val == "2-3" then nVal = math.random(2,3) end
        if val == "2-4" then nVal = math.random(2,4) end
        if val == "2-5" then nVal = math.random(2,5) end
        if val == "1-6" then nVal = math.random(1,6) end
        if val == "1-7" then nVal = math.random(1,7) end
        if val == "1-8" then nVal = math.random(1,8) end
        if val == "1-9" then nVal = math.random(1,9) end

        if val == "3-4" then nVal = math.random(3,4) end
        if val == "3-5" then nVal = math.random(3,5) end
        if val == "3-6" then nVal = math.random(3,6) end
        if val == "3-7" then nVal = math.random(3,7) end
        if val == "3-8" then nVal = math.random(3,8) end
        if val == "3-9" then nVal = math.random(3,9) end

        if val == "4-5" then nVal = math.random(4,5) end
        if val == "4-6" then nVal = math.random(4,6) end
        if val == "4-7" then nVal = math.random(4,7) end
        if val == "4-8" then nVal = math.random(4,8) end
        if val == "4-9" then nVal = math.random(4,9) end

        if val == "5-6" then nVal = math.random(5,6) end
        if val == "5-7" then nVal = math.random(5,7) end
        if val == "5-8" then nVal = math.random(5,8) end
        if val == "5-9" then nVal = math.random(5,9) end

        if val == "6-7" then nVal = math.random(6,7) end
        if val == "6-8" then nVal = math.random(6,8) end
        if val == "6-9" then nVal = math.random(6,9) end

        if val == "7-8" then nVal = math.random(7,8) end
        if val == "7-9" then nVal = math.random(7,9) end

        if val == "8-9" then nVal = math.random(8,9) end

        if val == "10-15" then nVal = math.random(10,15) end
        --]]

        --[[
        if val == "1-2" then nVal = 2 end
        if val == "1-3" then nVal = 3 end
        if val == "1-4" then nVal = 3 end
        if val == "1-5" then nVal = 3 end

        if val == "2-3" then nVal = 2 end
        if val == "2-4" then nVal = 3 end
        if val == "2-5" then nVal = 3 end

        if val == "3-4" then nVal = 3 end
        if val == "3-5" then nVal = 4 end

        if val == "4-5" then nVal = 4 end

        if val == "5-10" then nVal = 7 end
        
        if val == "10-15" then nVal = 12 end
        --]]

    --[[
        -- maybe it's a range ?
        local dashPos = val:find("-")
        veaf.loggers.get(veaf.Id):trace(string.format("dashPos=%s", tostring(dashPos)))
        if dashPos then 
            local lower = val:sub(1, dashPos-1)
            veaf.loggers.get(veaf.Id):trace(string.format("lower=%s", tostring(lower)))
            if lower then 
                lower = tonumber(lower)
            end
            if lower == nil then lower = 0 end
            local upper = val:sub(dashPos+1)
            veaf.loggers.get(veaf.Id):trace(string.format("upper=%s", tostring(upper)))
            if upper then 
                upper = tonumber(upper)
            end
            if upper == nil then upper = 5 end
            nVal = math.random(lower, upper)
            veaf.loggers.get(veaf.Id):trace(string.format("random nVal=%s", tostring(nVal)))
        end
        --]]
    end
    veaf.loggers.get(veaf.Id):trace(string.format("nVal=%s", tostring(nVal)))
    return nVal
end

function veaf.getRandomizableNumeric_norandom(val)
    veaf.loggers.get(veaf.Id):trace(string.format("getRandomizableNumeric_norandom(%s)", tostring(val)))
    local nVal = tonumber(val)
    veaf.loggers.get(veaf.Id):trace(string.format("nVal=%s", tostring(nVal)))
    if nVal == nil then 
        if val == "1-2" then nVal = 2 end
        if val == "1-3" then nVal = 3 end
        if val == "1-4" then nVal = 3 end
        if val == "1-5" then nVal = 3 end

        if val == "2-3" then nVal = 2 end
        if val == "2-4" then nVal = 3 end
        if val == "2-5" then nVal = 3 end

        if val == "3-4" then nVal = 3 end
        if val == "3-5" then nVal = 4 end

        if val == "4-5" then nVal = 4 end

        if val == "5-10" then nVal = 7 end
        
        if val == "10-15" then nVal = 12 end
    end
    veaf.loggers.get(veaf.Id):trace(string.format("nVal=%s", tostring(nVal)))
    return nVal
end

function veaf.getRandomizableNumeric(val)
    veaf.loggers.get(veaf.Id):trace(string.format("getRandomizableNumeric(%s)", tostring(val)))
    return veaf.getRandomizableNumeric_random(val)
end

function veaf.writeLineToTextFile(line, filename, filepath)
    veaf.loggers.get(veaf.Id):trace(string.format("writeLineToTextFile(%s, %s)", veaf.p(line), veaf.p(filename)))

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

    local filepath = filepath
    if not filepath and l_os then
        filepath = l_os.getenv("VEAF_EXPORT_DIR")
        if filepath then filepath = filepath .. "\\" end
        veaf.loggers.get(veaf.Id):trace(string.format("filepath=%s", veaf.p(filepath)))
    end
    if not filepath and l_os then
        filepath = l_os.getenv("TEMP")
        if filepath then filepath = filepath .. "\\" end
        veaf.loggers.get(veaf.Id):trace(string.format("filepath=%s", veaf.p(filepath)))
    end
    if not filepath and l_lfs then
        filepath = l_lfs.writedir()
        veaf.loggers.get(veaf.Id):trace(string.format("filepath=%s", veaf.p(filepath)))
    end

    if not filepath then
        return
    end

    local filename = filepath .. (filename or "default.log")

    local date = ""
    if l_os then
        date = l_os.date('%Y-%m-%d %H:%M:%S.000')
    end
    
    veaf.loggers.get(veaf.Id):trace(string.format("filename=%s", veaf.p(filename)))
    local file = l_io.open(filename, "a")
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

    local function writeln(file, text)
        file:write(text.."\r\n")
    end
    
    local export_path = export_path
    if not export_path and l_os then
        export_path = l_os.getenv("VEAF_EXPORT_DIR")
        if export_path then export_path = export_path .. "\\" end
        veaf.loggers.get(veaf.Id):trace(string.format("export_path=%s", veaf.p(export_path)))
    end
    if not export_path and l_os then
        export_path = l_os.getenv("TEMP")
        if export_path then export_path = export_path .. "\\" end
        veaf.loggers.get(veaf.Id):trace(string.format("export_path=%s", veaf.p(export_path)))
    end
    if not export_path and l_lfs then
        export_path = l_lfs.writedir()
        veaf.loggers.get(veaf.Id):trace(string.format("export_path=%s", veaf.p(export_path)))
    end
    
    if not export_path then
        return
    end
    
    local filename = filename or name .. ".json"
    veaf.loggers.get(veaf.Id):trace(string.format("filename=%s", veaf.p(filename)))
    
    veaf.loggers.get(veaf.Id):info("Dumping ".. name .." as json to "..filename .. " in "..export_path)

    local header =    '{\n'
    header = header .. '  "' .. name .. '": [\n'   

    local content = {}
    for key, value in pairs(data) do
        local line =  jsonify(key, value)
        table.insert(content, line)
    end
    local footer =    '\n'
    footer = footer .. ']\n'
    footer = footer .. '}\n'

    local file = l_io.open(export_path..filename, "w")
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
        local life0=unit:getLife0()
        local lifeN=unit:getLife()
        return lifeN/life0
    else
        return 0
    end
end

function veaf.setServerName(value)
    veaf.config.SERVER_NAME = value
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
    codeDigit.units=code%10
    codeDigit.tens=(code%100-codeDigit.units)/10
    codeDigit.hundreds=(code%1000-codeDigit.tens*10-codeDigit.units)/100
    codeDigit.thousands=(code-codeDigit.hundreds*100-codeDigit.tens*10-codeDigit.units)/1000

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
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Logging
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.loggers = {}
veaf.loggers.dict = {}

veaf.Logger =
{
    -- technical name
    name = nil,
    -- logging level
    level = nil,
}
veaf.Logger.__index = veaf.Logger

veaf.Logger.LEVEL = {
    ["error"]=1,
    ["warning"]=2,
    ["info"]=3,
    ["debug"]=4,
    ["trace"]=5,
}

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
    if type(text) ~= 'string' then
        text = veaf.p(text)
    else
        if arg and arg.n and arg.n > 0 then
            local pArgs = {}
            for index,value in ipairs(arg) do
                pArgs[index] = veaf.p(value)
            end
            text = text:format(unpack(pArgs))
        end            
    end
    local fName = nil
    local cLine = nil
    if debug then
        local dInfo = debug.getinfo(3)
        fName = dInfo.name
        cLine = dInfo.currentline
        -- local fsrc = dinfo.short_src
        --local fLine = dInfo.linedefined
    end
    if fName and cLine then
        return fName .. '|' .. cLine .. ': ' .. text
    elseif cLine then
        return cLine .. ': ' .. text
    else
        return ' ' .. text
    end
end

function veaf.Logger:print(level, text)
    local texts = veaf.Logger.splitText(text)
    local levelChar = 'E'
    local logFunction = env.error
    if level == veaf.Logger.LEVEL["warning"] then
        levelChar = 'W'
        logFunction = env.warning
    elseif level == veaf.Logger.LEVEL["info"] then
        levelChar = 'I'
        logFunction = env.info
    elseif level == veaf.Logger.LEVEL["debug"] then
        levelChar = 'D'
        logFunction = env.info
    elseif level == veaf.Logger.LEVEL["trace"] then
        levelChar = 'T'
        logFunction = env.info
    end
    for i = 1, #texts do
        if i == 1 then
            logFunction(self.name .. '|' .. levelChar .. '|' .. texts[i])
        else
            logFunction(texts[i])
        end
    end
end

function veaf.Logger:error(text, ...)
    if self.level >= 1 then
        text = veaf.Logger.formatText(text, unpack(arg))
        self:print(1, text)
    end
end

function veaf.Logger:warn(text, ...)
    if self.level >= 2 then
        text = veaf.Logger.formatText(text, unpack(arg))
        self:print(2, text)
    end
end

function veaf.Logger:info(text, ...)
    if self.level >= 3 then
        text = veaf.Logger.formatText(text, unpack(arg))
        self:print(3, text)
    end
end

function veaf.Logger:debug(text, ...)
    if self.level >= 4 then
        text = veaf.Logger.formatText(text, unpack(arg))
        self:print(4, text)
    end
end

function veaf.Logger:trace(text, ...)
    if self.level >= 5 then
        text = veaf.Logger.formatText(text, unpack(arg))
        self:print(5, text)
    end
end

function veaf.Logger:marker(id, header, message, position, markersTable, radius, fillColor)
    if not id then
        id = 99999 
    end
    if self.level >= 5 then
        local correctedPos = {}
        correctedPos.x = position.x
        if not(position.z) then
            correctedPos.z = position.y
            correctedPos.y = position.alt
        else
            correctedPos.z = position.z
            correctedPos.y = position.y
        end
        if not (correctedPos.y) then
            correctedPos.y = 0
        end
        local message = message
        if header and id then
            message = header..id.." "..message
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
    if self.level >= 5 then
        local points = { positionStart, positionEnd }
        for _, point in ipairs(points) do
            local correctedPos = {}
            correctedPos.x = point.x
            if not(point.z) then
                correctedPos.z = point.y
                correctedPos.y = point.alt
            else
                correctedPos.z = point.z
                correctedPos.y = point.y
            end
            if not (correctedPos.y) then
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
            message = header..id.." "..message
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
    if self.level >= 5 then
        local points = points
        for _, point in ipairs(points) do
            local correctedPos = {}
            correctedPos.x = point.x
            if not(point.z) then
                correctedPos.z = point.y
                correctedPos.y = point.alt
            else
                correctedPos.z = point.z
                correctedPos.y = point.y
            end
            if not (correctedPos.y) then
                correctedPos.y = 0
            end
            point.x = correctedPos.x
            point.y = correctedPos.y
            point.z = correctedPos.z
        end

        local message = message
        if header and id then
            message = header..id.." "..message
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
    local n=#markersTable
    for i=1,n do
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
-- Quick Reaction Alert - https://en.wikipedia.org/wiki/Quick_Reaction_Alert
-------------------------------------------------------------------------------------------------------------------------------------------------------------
VeafQRA =
{
    -- technical name (QRA instance name)
    name = nil,
    -- trigger zone name (if set, we'll use a DCS trigger zone)
    triggerZoneCenter = nil,
    -- center (point in the center of the circle, when not using a DCS trigger zone)
    zoneCenter = nil,
    -- radius (size of the circle, when not using a zone)
    zoneRadius = nil,
    -- description for the briefing
    description = nil,
    -- aircraft groups forming the QRA
    groups = nil,
    -- aircraft groups forming the QRA, in a table by enemy quantity (i.e. if this number of enemies are in the zone, spawn these groups)
    groupsToDeployByEnemyQuantity = nil,
    -- coalition for the QRA
    coalition = nil,
    -- coalitions the QRA is defending against
    ennemyCoalitions = nil,
    -- message when the QRA is started
    messageStart = nil,
    -- message when the QRA is triggered
    messageDeploy = nil,
    -- message when the QRA is destroyed
    messageDestroyed = nil,
    -- message when the QRA is ready
    messageReady = nil,
    -- message when the QRA is out of aircrafts
    messageOut = nil,
    -- message when the QRA has been resupplied and will start operations against
    messageResupplied = nil,
    -- message when the QRA has lost the airbase it operates from
    messageAirbaseDown = nil,
    -- message when the QRA has retrieved the airbase it operates from and will start operations again
    messageAirbaseUp = nil,
    -- message when the QRA is stopped
    messageStop = nil,
    -- silent means no message is emitted
    silent = nil,
    -- radius of the defenders groups spawn
    respawnRadius = nil,
    -- reacts when helicopters enter the zone
    reactOnHelicopters = nil,
    -- delay before activating
    delayBeforeActivating = -1,
    -- delay before rearming
    delayBeforeRearming = -1,
    -- the enemy does not have to leave the zone before the QRA is rearmed
    noNeedToLeaveZoneBeforeRearming = false,
    -- reset the QRA immediately if all the enemy units leave the zone
    resetWhenLeavingZone = false,
    -- maximum number of QRA ready for action at once, -1 indicates infinite
    QRAmaxCount = -1,
    -- number of groups of aircrafts that can be spawned for this QRA in total, -1 indicates infinite.
    QRAcount = -1,
    -- delay in minutes before the QRA counter is increased by one, simulating some sort of logistic chain of aircrafts.
    delayBeforeQRAresupply = 0,
    -- maximum number of resupplies at a given time, simulating some sort of warehousing, -1 indicates infinite. Is decremented every time a resupply happens. 0 indicates no resupply.
    QRAresupplyMax = -1,
    -- minimum QRAcount that will trigger a resupply, -1 indicates as soon as an aircraft is lost
    QRAminCountforResupply = -1,
    -- how many aircraft groups are resupplied at once   
    resupplyAmount = 1,
    -- indicator to know if the QRA is being resupplied or not
    isResupplying = false,
    -- name of the airport to which the QRA is linked, QRAs will be deployed only if this is set and the airport is captured by the QRA's coalition or if this is not set
    airportLink = nil,
    -- minimum linked airbase life percentage (from 0 to 1) for the QRA to have it's airbase available
    airportMinLifePercent = nil,
    -- boolean to know if the status OUT was announced or not
    outAnnounced = false,
    -- boolean to know if the status NOAIRBASE was announced or not
    noAB_announced = false,

    timer = nil,
    state = nil,
    scheduled_state = nil,
    _enemyHumanUnits = nil
}
VeafQRA.__index = VeafQRA

VeafQRA.Id = "QRA"
VeafQRA.LogLevel = "trace"

veaf.loggers.new(VeafQRA.Id, VeafQRA.LogLevel)

VeafQRA.STATUS_WILLREARM = 0
VeafQRA.STATUS_READY = 1
VeafQRA.STATUS_READY_WAITINGFORMORE = 1.5
VeafQRA.STATUS_ACTIVE = 2
VeafQRA.STATUS_DEAD = 3

--scheduled states
VeafQRA.STATUS_OUT = 4
VeafQRA.STATUS_NOAIRBASE = 5
VeafQRA.STATUS_STOP = 6

VeafQRA.WATCHDOG_DELAY = 5

VeafQRA.DEFAULT_airbaseMinLifePercent = 0.9

VeafQRA.AllSilence = false --value to set all spawned QRAs to silent if true. By default it's false but this value can be set in the missionConfig
VeafQRA.DEFAULT_MESSAGE_START = "%s is online"
VeafQRA.DEFAULT_MESSAGE_DEPLOY = "%s is deploying"
VeafQRA.DEFAULT_MESSAGE_DESTROYED = "%s has been destroyed"
VeafQRA.DEFAULT_MESSAGE_READY = "%s is ready"
VeafQRA.DEFAULT_MESSAGE_OUT = "%s is out of aircrafts"
VeafQRA.DEFAULT_MESSAGE_RESUPPLIED = "%s has been resupplied"
VeafQRA.DEFAULT_MESSAGE_AIRBASE_DOWN = "%s lost it's airbase"
VeafQRA.DEFAULT_MESSAGE_AIRBASE_UP = "%s now has an airbase"
VeafQRA.DEFAULT_MESSAGE_STOP = "%s is offline"

function VeafQRA.ToggleAllSilence(state)
    if state then 
        VeafQRA.AllSilence = true
    else
        VeafQRA.AllSilence = false
    end
end

function VeafQRA:new()
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA:new()"))
    local self = setmetatable({}, VeafQRA)
    self.name = nil
    self.zoneCenter = nil
    self.zoneRadius = nil
    self.description = nil
    self.groupsToDeployByEnemyQuantity = {}
    self.spawnedGroups = {}
    self.coalition = nil
    self.ennemyCoalitions = {}
    self.messageStart = VeafQRA.DEFAULT_MESSAGE_START
    self.messageDeploy = VeafQRA.DEFAULT_MESSAGE_DEPLOY
    self.messageDestroyed = VeafQRA.DEFAULT_MESSAGE_DESTROYED
    self.messageReady = VeafQRA.DEFAULT_MESSAGE_READY
    self.messageOut = VeafQRA.DEFAULT_MESSAGE_OUT
    self.messageResupplied = VeafQRA.DEFAULT_MESSAGE_RESUPPLIED
    self.messageAirbaseDown = VeafQRA.DEFAULT_MESSAGE_AIRBASE_DOWN
    self.messageAirbaseUp = VeafQRA.DEFAULT_MESSAGE_AIRBASE_UP
    self.messageStop = VeafQRA.DEFAULT_MESSAGE_STOP
    self.silent = VeafQRA.AllSilence
    self.respawnRadius = 250
    self.reactOnHelicopters = false
    self.delayBeforeRearming = -1
    self.delayBeforeActivating = -1
    self.noNeedToLeaveZoneBeforeRearming = false
    self.resetWhenLeavingZone = false
    self.QRAmaxCount = -1
    self.QRAcount = -1
    self.delayBeforeQRAresupply = 0
    self.QRAresupplyMax = -1
    self.QRAminCountforResupply = -1
    self.resupplyAmount = 1
    self.isResupplying = false
    self.airportLink = nil
    self.airportMinLifePercent = VeafQRA.DEFAULT_airbaseMinLifePercent
    self.outAnnounced = false
    self.noAB_announced = false
    
    self._enemyHumanUnits = nil
    self.timeSinceReady = -1
    self.state = nil
    self.scheduled_state = nil
    return self
end

function VeafQRA:setName(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[]:setName(%s)", veaf.p(value)))
    self.name = value
    return self
end

function VeafQRA:setTriggerZone(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setTriggerZone(%s)", veaf.p(self.name), veaf.p(value)))
    self.triggerZone = value
    local triggerZone = veaf.getTriggerZone(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("triggerZone=%s", veaf._p(triggerZone)))
    return self
end

function VeafQRA:setZoneCenter(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setZoneCenter(%s)", veaf.p(self.name), veaf.p(value)))
    self.zoneCenter = value
    return self
end    

function VeafQRA:setZoneCenterFromCoordinates(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setZoneCenterFromCoordinates(%s)", veaf.p(self.name), veaf.p(value)))
    local _lat, _lon = veaf.computeLLFromString(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("_lat=%s)", veaf.p(_lat)))
    veaf.loggers.get(VeafQRA.Id):trace(string.format("_lon=%s)", veaf.p(_lon)))
    local vec3 = coord.LLtoLO(_lat, _lon)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("vec3=%s)", veaf.p(vec3)))
    return self:setZoneCenter(vec3)
end

function VeafQRA:setZoneRadius(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setZoneRadius(%s)", veaf.p(self.name), veaf.p(value)))
    self.zoneRadius = value
    return self
end

function VeafQRA:setDescription(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setDescription(%s)", veaf.p(self.name), veaf.p(value)))
    self.description = value
    return self
end

function VeafQRA:getDescription()
    return self.description or self.name
end

function VeafQRA:addGroup(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:addGroup(%s)", veaf.p(self.name), veaf.p(value)))
    if not self.groupsToDeployByEnemyQuantity[1] then
        self.groupsToDeployByEnemyQuantity[1] = {}
    end
    table.insert(self.groupsToDeployByEnemyQuantity[1], value)
    return self
end

function VeafQRA:addRandomGroup(groups, number, bias)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:addRandomGroup(%s, %s, %s)", veaf.p(self.name), veaf.p(groups), veaf.p(number), veaf.p(bias)))
    return self:addGroup({groups, number or 1, bias or 0})
end

function VeafQRA:setGroupsToDeployByEnemyQuantity(enemyNb, groupsToDeploy)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setGroupsToDeployByEnemyQuantity(%s) -> %s", veaf.p(self.name), veaf.p(enemyNb), veaf.p(groupsToDeploy)))
    self.groupsToDeployByEnemyQuantity[enemyNb] = groupsToDeploy
    return self
end

function VeafQRA:setRandomGroupsToDeployByEnemyQuantity(enemyNb, groups, number, bias)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setRandomGroupsToDeployByEnemyQuantity(%s, %s, %s, %s)", veaf.p(self.name), veaf.p(enemyNb), veaf.p(groups), veaf.p(number), veaf.p(bias)))
    return self:setGroupsToDeployByEnemyQuantity(enemyNb, {groups, number or 1, bias or 0})
end

function VeafQRA:setCoalition(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setCoalition(%s)", veaf.p(self.name), veaf.p(value)))
    self.coalition = value
    return self
end

function VeafQRA:addEnnemyCoalition(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:addEnnemyCoalition(%s)", veaf.p(self.name), veaf.p(value)))
    self.ennemyCoalitions[value] = value
    return self
end

function VeafQRA:setMessageStart(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageStart(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageStart = value
    return self
end

function VeafQRA:setMessageDeploy(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageDeploy(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageDeploy = value
    return self
end

function VeafQRA:setMessageDestroyed(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageDestroyed(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageDestroyed = value
    return self
end

function VeafQRA:setMessageReady(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageReady(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageReady = value
    return self
end

function VeafQRA:setMessageOut(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageOut(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageOut = value
    return self
end

function VeafQRA:setMessageResupplied(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageResupplied(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageResupplied = value
    return self
end

function VeafQRA:setMessageAirbaseDown(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageAirbaseDown(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageAirbaseDown = value
    return self
end

function VeafQRA:setMessageAirbaseUp(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageAirbaseUp(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageAirbaseUp = value
    return self
end

function VeafQRA:setMessageStop(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setMessageStop(%s)", veaf.p(self.name), veaf.p(value)))
    self.messageStop = value
    return self
end

function VeafQRA:setSilent(state)
    
    local state = state
    if state then 
        state = true
    else
        state = false
    end

    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setSilent(%s)", veaf.p(self.name), veaf.p(state)))
    self.silent = state
    return self
end

--TODO, warehousing for each group within a QRA and not just the whole QRA
function VeafQRA:setQRAcount(count)

    if count and type(count) == 'number' and count >= -1 then 
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setQRAcount(%s)", veaf.p(self.name), veaf.p(count)))
        self.QRAcount = count
    end
    return self
end

function VeafQRA:setQRAmaxCount(maxCount)

    if maxCount and type(maxCount) == 'number' and maxCount >= -1 then 
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setQRAmaxCount(%s)", veaf.p(self.name), veaf.p(maxCount)))
        self.QRAmaxCount = maxCount
    end
    return self
end

function VeafQRA:setQRAresupplyDelay(resupplyDelay)

    if resupplyDelay and type(resupplyDelay) == 'number' and resupplyDelay >= 0 then 
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setQRAresupplyDelay(%s)", veaf.p(self.name), veaf.p(resupplyDelay)))
        self.delayBeforeQRAresupply = resupplyDelay
    end
    return self
end

function VeafQRA:setQRAmaxResupplyCount(maxResupplyCount)

    if maxResupplyCount and type(maxResupplyCount) == 'number' and maxResupplyCount >= -1 then 
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setQRAmaxResupplyCount(%s)", veaf.p(self.name), veaf.p(maxResupplyCount)))
        self.QRAresupplyMax = maxResupplyCount
    end
    return self
end

function VeafQRA:setQRAminCountforResupply(minCountforResupply)

    if minCountforResupply and type(minCountforResupply) == 'number' and minCountforResupply >= -1 and minCountforResupply ~= 0 then 
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setQRAminCountforResupply(%s)", veaf.p(self.name), veaf.p(minCountforResupply)))
        self.QRAminCountforResupply = minCountforResupply
    end
    return self
end

function VeafQRA:setResupplyAmount(resupplyAmount)

    if resupplyAmount and type(resupplyAmount) == 'number' and resupplyAmount >= 1 then 
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setResupplyAmount(%s)", veaf.p(self.name), veaf.p(resupplyAmount)))
        self.resupplyAmount = resupplyAmount
    end
    return self
end

function VeafQRA:setAirportLink(airport_name)

    if airport_name and type(airport_name) == 'string' and Airbase.getByName(airport_name) then 
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setAirportLink(%s)", veaf.p(self.name), veaf.p(airport_name)))
        self.airportLink = airport_name
    end
    return self
end

function VeafQRA:setAirportMinLifePercent(value)

    if value and value >= 0 and value <= 1 then 
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setAirportMinLifePercent(%s)", veaf.p(self.name), veaf.p(value)))
        self.airportMinLifePercent = value
    end
    return self
end

function VeafQRA:setReactOnHelicopters()
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setReactOnHelicopters()", veaf.p(self.name)))
    self.reactOnHelicopters = true
    return self
end

function VeafQRA:setRespawnRadius(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setRespawnRadius(%s)", veaf.p(self.name), veaf.p(value)))
    self.respawnRadius = value
    if self.respawnRadius < 250 then self.respawnRadius = 250 end
    return self
end

function VeafQRA:setDelayBeforeRearming(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setDelayBeforeRearming(%s)", veaf.p(self.name), veaf.p(value)))
    self.delayBeforeRearming = value
    return self
end

function VeafQRA:setNoNeedToLeaveZoneBeforeRearming()
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setNoNeedToLeaveZoneBeforeRearming()", veaf.p(self.name)))
    self.noNeedToLeaveZoneBeforeRearming = true
    return self
end

function VeafQRA:setResetWhenLeavingZone()
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setResetWhenLeavingZone()", veaf.p(self.name)))
    self.resetWhenLeavingZone = true
    return self
end

function VeafQRA:setDelayBeforeActivating(value)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setDelayBeforeActivating(%s)", veaf.p(self.name), veaf.p(value)))
    self.delayBeforeActivating = value
    return self
end

function VeafQRA:_getEnemyHumanUnits()
    --veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:_getEnemyHumanUnits() - computing", veaf.p(self.name)))
    if not self._enemyHumanUnits then
        veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:_getEnemyHumanUnits() - computing", veaf.p(self.name)))
        self._enemyHumanUnits = {}
        veaf.loggers.get(VeafQRA.Id):trace(string.format("ennemyCoalitions[]=%s", veaf.p(self.ennemyCoalitions)))
        for _, unit in pairs(mist.DBs.humansByName) do
            --veaf.loggers.get(VeafQRA.Id):trace("unit=%s", unit)
            veaf.loggers.get(VeafQRA.Id):trace("unit.unitName=%s", unit.unitName)
            veaf.loggers.get(VeafQRA.Id):trace("unit.groupName=%s", unit.groupName)
            veaf.loggers.get(VeafQRA.Id):trace(string.format("unit.coalition=%s", veaf.p(unit.coalition)))
            local coalitionId = 0
            if unit.coalition then
                if unit.coalition:lower() == "red" then
                    coalitionId = coalition.side.RED
                elseif unit.coalition:lower() == "blue" then
                    coalitionId = coalition.side.BLUE
                end
            end                    
            if self.ennemyCoalitions[coalitionId] then
                if unit.category then
                    veaf.loggers.get(VeafQRA.Id):trace("unit.category=%s", unit.category)
                    if     (unit.category == "plane")
                        or (unit.category == "helicopter" and self.reactOnHelicopters)
                    then
                        veaf.loggers.get(VeafQRA.Id):trace("adding unit to enemy human units for QRA")
                        table.insert(self._enemyHumanUnits, unit.unitName)
                    end
                end
            end
        end
    end
    return self._enemyHumanUnits
end

function VeafQRA:check()
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:check()", veaf.p(self.name)))
    veaf.loggers.get(VeafQRA.Id):trace(string.format("self.state=%s", veaf._p(self.state)))
    veaf.loggers.get(VeafQRA.Id):trace(string.format("timer.getTime()=%s", veaf._p(timer.getTime())))

    --scheduled state application is attempted regardless of airportlink checks etc. to take into account user requested states which go through scheduled_states as well
    --Stop scheduled is checked before even running the check function as it has the highest priority
    self:applyScheduledState()

    if self.state ~= VeafQRA.STATUS_STOP then

        --if the QRA is linked to an airbase. Airport is checked before even trying to deploy a group and check warehousing which has a lower priority
        if self.airportLink then
            veaf.loggers.get(VeafQRA.Id):trace(string.format("Checking Airport link : %s", veaf.p(self.airportLink)))
            self:checkAirport()
            self:applyScheduledState()
        end

        if self.state ~= VeafQRA.STATUS_NOAIRBASE then
 
            --if warehousing is activated. Warehousing is checked before even trying to deploy a group
            if self.QRAcount ~= -1 then
                veaf.loggers.get(VeafQRA.Id):trace(string.format("Checking Warehousing..."))
                veaf.loggers.get(VeafQRA.Id):trace(string.format("QRACount : %s", veaf.p(self.QRAcount)))
                self:checkWarehousing()
                self:applyScheduledState()
            end

            if self.state ~= VeafQRA.STATUS_OUT then
                local unitNames = self:_getEnemyHumanUnits()
                veaf.loggers.get(VeafQRA.Id):trace(string.format("unitNames=%s", veaf.p(unitNames)))
                local unitsInZone = nil
                local triggerZone = veaf.getTriggerZone(self.triggerZone)
                if triggerZone then
                    veaf.loggers.get(VeafQRA.Id):trace(string.format("triggerZone=%s", veaf._p(triggerZone)))
                    if triggerZone.type == 0 then -- circular
                        unitsInZone = mist.getUnitsInZones(unitNames, {self.triggerZone})
                    elseif triggerZone.type == 2 then -- quad point
                        veaf.loggers.get(VeafQRA.Id):trace(string.format("checking in polygon %s", veaf._p(triggerZone.verticies)))
                        unitsInZone = mist.getUnitsInPolygon(unitNames, triggerZone.verticies)
                    end
                else
                    unitsInZone = veaf.findUnitsInCircle(self.zoneCenter, self.zoneRadius, false, unitNames)
                end
                local nbUnitsInZone = 0
                for _ in pairs(unitsInZone) do nbUnitsInZone = nbUnitsInZone + 1 end
                veaf.loggers.get(VeafQRA.Id):trace(string.format("unitsInZone=%s", veaf._p(unitsInZone)))
                veaf.loggers.get(VeafQRA.Id):trace(string.format("#unitsInZone=%s", veaf._p(#unitsInZone)))
                veaf.loggers.get(VeafQRA.Id):trace(string.format("nbUnitsInZone=%s", veaf._p(nbUnitsInZone)))
                veaf.loggers.get(VeafQRA.Id):trace(string.format("state=%s", veaf._p(self.state)))
                if (self.state == VeafQRA.STATUS_READY) and (unitsInZone and nbUnitsInZone > 0) then
                    veaf.loggers.get(VeafQRA.Id):debug(string.format("self.state set to VeafQRA.STATUS_READY_WAITINGFORMORE at timer.getTime()=%s", veaf._p(timer.getTime())))
                    self.state = VeafQRA.STATUS_READY_WAITINGFORMORE
                    self.timeSinceReady = timer.getTime()
                elseif (self.state == VeafQRA.STATUS_READY_WAITINGFORMORE) and (unitsInZone and nbUnitsInZone > 0) and (timer.getTime() - self.timeSinceReady > self.delayBeforeActivating) then
                    -- trigger the QRA
                    self:deploy(nbUnitsInZone)
                    self.timeSinceReady = -1
                elseif (self.state == VeafQRA.STATUS_DEAD) and (self.noNeedToLeaveZoneBeforeRearming or (not unitsInZone or nbUnitsInZone == 0)) then
                    -- rearm the QRA after a delay (if set)
                    if self.delayBeforeRearming > 0 then
                        mist.scheduleFunction(VeafQRA.rearm, {self}, timer.getTime()+self.delayBeforeRearming)
                        self.state = VeafQRA.STATUS_WILLREARM
                    else
                        self:rearm()
                    end
                elseif (self.state == VeafQRA.STATUS_ACTIVE) then
                    local qraAlive = false
                    local inAir = false
                    for _, groupName in pairs(self.spawnedGroups) do
                        local group = Group.getByName(groupName)
                        if group then
                            qraAlive = true
                            local units = group:getUnits()
                            if units then
                                for _,unit in pairs(units) do
                                    if unit and unit:inAir() then
                                        inAir = true
                                    end
                                end
                            end
                        end
                    end
                    if not qraAlive then
                        -- signal QRA destroyed
                        self:destroyed()
                    elseif (self.resetWhenLeavingZone and nbUnitsInZone == 0) or inAir == false then 
                        -- QRA reset
                        self:rearm()
                    end
                end
            end
        end
    
        mist.scheduleFunction(VeafQRA.check, {self}, timer.getTime() + VeafQRA.WATCHDOG_DELAY) 
    end
end

function VeafQRA:setScheduledState(scheduledState)
    --priority level 1
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:setScheduledState(%s)", veaf.p(self.name), veaf.p(scheduledState)))
    if scheduledState == VeafQRA.STATUS_STOP then
        self.scheduled_state = VeafQRA.STATUS_STOP
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA STOP scheduled"))
    --priority level 2
    elseif scheduledState == VeafQRA.STATUS_NOAIRBASE and self.scheduled_state ~= VeafQRA.STATUS_STOP then
        self.scheduled_state = VeafQRA.STATUS_NOAIRBASE
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA NOAIRBASE scheduled"))
    --priority level 3
    elseif scheduledState == VeafQRA.STATUS_OUT and self.scheduled_state ~= VeafQRA.STATUS_STOP and self.scheduled_state ~= VeafQRA.STATUS_NOAIRBASE then
        self.scheduled_state = VeafQRA.STATUS_OUT
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA OUT scheduled"))
    end
    return self
end

function VeafQRA:applyScheduledState()
    if self.scheduled_state and self.state ~= VeafQRA.STATUS_ACTIVE then
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA taking scheduled status : %s", veaf.p(self.scheduled_state)))
        self.state = self.scheduled_state
    end
end

function VeafQRA:checkAirport()
    local QRA_airportObject = veaf.getAirbaseForCoalition(self.airportLink, self.coalition)
    local airport_life_percent = nil
    if QRA_airportObject then
        airport_life_percent = veaf.getAirbaseLife(self.airportLink, true)
    end

    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s] is linked to airbase %s", veaf.p(self.name), veaf.p(self.airportLink)))

    if not QRA_airportObject or airport_life_percent < self.airportMinLifePercent then
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA lost it's airbase"))
        self:setScheduledState(VeafQRA.STATUS_NOAIRBASE)
        if not self.silent and not self.noAB_announced then
            local msg = string.format(self.messageAirbaseDown, self:getDescription())
            for coalition, _ in pairs(self.ennemyCoalitions) do
                trigger.action.outTextForCoalition(coalition, msg, 15) 
            end
        end
        self.noAB_announced = true
        
    elseif self.state == VeafQRA.STATUS_NOAIRBASE then
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA has it's airbase %s", veaf.p(QRA_airportObject:getName())))
        if not self.silent then
            local msg = string.format(self.messageAirbaseUp, self:getDescription())
            for coalition, _ in pairs(self.ennemyCoalitions) do
                trigger.action.outTextForCoalition(coalition, msg, 15) 
            end
        end

        self.noAB_announced = false
        self.state = VeafQRA.STATUS_DEAD --QRA that have just been recommisionned act as if they were dead since they need to be rearmed after a delay
        if self.scheduled_state == VeafQRA.STATUS_NOAIRBASE then self.scheduled_state = nil end --make sure you reset the scheduled state if you are within the bounds of this method
    end
end

    -- -- maximum number of QRA ready for action at once, -1 indicates infinite
    -- QRAmaxCount = -1
    -- -- number of groups of aircrafts that can be spawned for this QRA in total, -1 indicates infinite
    -- QRAcount = -1
    -- -- delay in minutes before the QRA counter is increased by one, simulating some sort of logistic chain of aircrafts.
    -- delayBeforeQRAresupply = 0
    -- -- maximum number of resupplies at a given time, simulating some sort of warehousing, -1 indicates infinite. Is decremented every time a resupply happens if not equal to -1 originally. 0 indicated no resupply.
    -- QRAresupplyMax = -1
    -- -- minimum QRAcount that will trigger a resupply, -1 indicates as soon as an aircraft is lost
    -- QRAminCountforResupply = -1
    -- -- how many aircraft groups are resupplied at once   
    --resupplyAmount = 1
    -- -- indicator to know if the QRA is being resupplied or not
    --isResupplying = false
    
function VeafQRA:checkWarehousing()
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s] resupply state is %s", veaf.p(self.name), veaf.p(self.isResupplying)))
    
    --if a resupply is not already on the way and if there are aircrafts in stock and if the available aircraft count is below the threshold or if an aircraft was just lost and the resupply mode indicates to resupply whenever an aircraft is lost
    if not self.isResupplying and self.QRAresupplyMax ~= 0 and (self.QRAcount < self.QRAminCountforResupply or (self.QRAcount < self.QRAmaxCount or (self.QRAmaxCount == -1 and self.state == VeafQRA.STATUS_DEAD)) and self.QRAminCountforResupply == -1) then
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA has %s/%s aircraft groups available", veaf.p(self.QRAcount), veaf.p(self.QRAmaxCount)))
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA has %s aircraft groups ready for resupply (-1 for infinite)", veaf.p(self.QRAresupplyMax)))   
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA resupply asks for %s aircraft groups", veaf.p(self.resupplyAmount)))
        local resupplyAmount = self.resupplyAmount
        --take into account the maximum number of QRA groups as to not oversupply it
        if self.QRAmaxCount ~= -1 and resupplyAmount > self.QRAmaxCount - self.QRAcount then
            resupplyAmount = self.QRAmaxCount - self.QRAcount
            veaf.loggers.get(VeafQRA.Id):trace(string.format("There are only %s available aircraft group slots for this QRA", veaf.p(self.QRAmaxCount - self.QRAcount)))
        end

        --take into account the maximum number of QRA groups that can be supplied by the stock
        if self.QRAresupplyMax ~= -1 and resupplyAmount > self.QRAresupplyMax then
            resupplyAmount = self.QRAresupplyMax
            veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA can only be resupplied by %s aircraft groups", veaf.p(self.QRAresupplyMax)))
        end
        
        veaf.loggers.get(VeafQRA.Id):trace(string.format("%s aircraft groups will be handled for resupply", veaf.p(resupplyAmount)))
        if resupplyAmount > 0 then
            self.isResupplying = true
            if self.delayBeforeQRAresupply > 0 then
                veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA will be resupplied in %s seconds", veaf.p(self.delayBeforeQRAresupply)))
                mist.scheduleFunction(VeafQRA.resupply, {self, resupplyAmount}, timer.getTime()+self.delayBeforeQRAresupply)
            else
                veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA is being resupplied..."))
                self:resupply(resupplyAmount)
            end
        end
    end

    if self.QRAcount == 0 then
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA is out of aircraft groups"))
        if not self.silent and not self.outAnnounced then
            local msg = string.format(self.messageOut, self:getDescription())
            for coalition, _ in pairs(self.ennemyCoalitions) do
                trigger.action.outTextForCoalition(coalition, msg, 15) 
            end

            self.outAnnounced = true
        end

        self:setScheduledState(VeafQRA.STATUS_OUT)
    end
end

function VeafQRA:resupply(resupplyAmount)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:resupply(%s)", veaf.p(self.name), veaf.p(resupplyAmount)))

    --if the QRA can still operate, then execute the resupply, the list would need to be expanded if new scheduled status blocking operations were added
    if self.scheduled_state ~= VeafQRA.STATUS_NOAIRBASE and self.scheduled_state ~= VeafQRA.STATUS_STOP then
        if resupplyAmount and type(resupplyAmount) == 'number' and resupplyAmount > 0 then
            veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA is going to be resupplied, old count is : %s", veaf.p(self.QRAcount)))
            self.QRAcount = self.QRAcount + resupplyAmount
            veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA was resupplied, new count is : %s", veaf.p(self.QRAcount)))
            
            veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA previously had %s aircraft groups ready for resupply (-1 for infinite)", veaf.p(self.QRAresupplyMax)))
            if self.QRAresupplyMax ~= -1 then
                self.QRAresupplyMax = self.QRAresupplyMax - resupplyAmount
                if self.QRAresupplyMax < 0 then
                    self.QRAresupplyMax = 0
                end
            end
            veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA now only has %s aircraft groups ready for resupply (-1 for infinite)", veaf.p(self.QRAresupplyMax)))

            if self.state == VeafQRA.STATUS_OUT then
                veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA now has at least one aircraft group ready for action, resuming service..."))
                if not self.silent then
                    local msg = string.format(self.messageResupplied, self:getDescription())
                    for coalition, _ in pairs(self.ennemyCoalitions) do
                        trigger.action.outTextForCoalition(coalition, msg, 15) 
                    end
                end

                self.outAnnounced = false
                self.state = VeafQRA.STATUS_DEAD --QRA that have just arrived act as if the QRA had just died, they need to be rearmed
                if self.scheduled_state == VeafQRA.STATUS_OUT then self.scheduled_state = nil end --make sure you reset the scheduled state if you are within the bounds of this method
            end
        end
    else
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA is no longer operating, resupply did not take place"))
    end

    self.isResupplying = false
end

function VeafQRA:chooseGroupsToDeploy(nbUnitsInZone)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:chooseGroupsToDeploy(%s)", veaf.p(self.name), veaf.p(nbUnitsInZone)))
    local biggestNumberLowerThanUnitsInZone = -1
    local groupsToDeploy = nil
    for enemyNb, groups in pairs(self.groupsToDeployByEnemyQuantity) do
        if nbUnitsInZone >= enemyNb then 
            biggestNumberLowerThanUnitsInZone = enemyNb
            groupsToDeploy = groups
        end 
    end
    if groupsToDeploy then
        -- process a random group definition
        local groupsToChooseFrom = groupsToDeploy[1]
        local numberOfGroups = groupsToDeploy[2]
        local bias = groupsToDeploy[3] 
        veaf.loggers.get(VeafQRA.Id):trace(string.format("groupsToChooseFrom=%s", veaf._p(groupsToChooseFrom)))
        veaf.loggers.get(VeafQRA.Id):trace(string.format("numberOfGroups=%s", veaf._p(numberOfGroups)))
        veaf.loggers.get(VeafQRA.Id):trace(string.format("bias=%s", veaf._p(bias)))
        if groupsToChooseFrom and type(groupsToChooseFrom) == "table" and numberOfGroups and type(numberOfGroups) == "number" and bias and type(bias) == "number" then
        local result = {}
            for _ = 1, numberOfGroups do
                local group = veaf.randomlyChooseFrom(groupsToChooseFrom, bias)
                veaf.loggers.get(VeafQRA.Id):trace(string.format("group=%s", veaf._p(group)))
                table.insert(result, group)
            end
            groupsToDeploy = result
        end
    end
    return groupsToDeploy
end

function VeafQRA:deploy(nbUnitsInZone)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:deploy()", veaf.p(self.name)))
    veaf.loggers.get(VeafQRA.Id):trace(string.format("nbUnitsInZone=[%s]", veaf.p(nbUnitsInZone)))
    if not self.silent then
        local msg = string.format(self.messageDeploy, self:getDescription())
        for coalition, _ in pairs(self.ennemyCoalitions) do
            trigger.action.outTextForCoalition(coalition, msg, 15)
        end
    end
    local groupsToDeploy = self:chooseGroupsToDeploy(nbUnitsInZone)
    self.spawnedGroups = {}
    if groupsToDeploy then
        for _, groupName in pairs(groupsToDeploy) do
            local group = Group.getByName(groupName)
            local spawnSpot = group:getUnit(1):getPoint()
            local vars = {}
            vars.point = mist.getRandPointInCircle(spawnSpot, self.respawnRadius)
            vars.point.z = vars.point.y 
            vars.point.y = spawnSpot.y
            vars.gpName = groupName
            vars.action = 'clone'
            vars.route = mist.getGroupRoute(groupName, 'task')
            local newGroup = mist.teleportToPoint(vars) -- respawn with radius
            table.insert(self.spawnedGroups, newGroup.name)
        end
        veaf.loggers.get(VeafQRA.Id):trace(string.format("self.spawnedGroups=%s", veaf._p(self.spawnedGroups)))
        self.state = VeafQRA.STATUS_ACTIVE
    end
end

function VeafQRA:destroyed()
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:destroyed()", veaf.p(self.name)))
    if not self.silent then
        local msg = string.format(self.messageDestroyed, self:getDescription())
        for coalition, _ in pairs(self.ennemyCoalitions) do
            trigger.action.outTextForCoalition(coalition, msg, 15)
        end
    end
    self.state = VeafQRA.STATUS_DEAD

    if self.QRAcount > 0 then
        veaf.loggers.get(VeafQRA.Id):trace(string.format("QRA will now see one of it's aicraft groups removed"))
        self.QRAcount = self.QRAcount - 1
    end
end

function VeafQRA:rearm(silent)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:rearm()", veaf.p(self.name)))
    if not self.silent and not silent then
        local msg = string.format(self.messageReady, self:getDescription())
        for coalition, _ in pairs(self.ennemyCoalitions) do
            trigger.action.outTextForCoalition(coalition, msg, 15) 
        end
    end
    if self.spawnedGroups then 
        for _, groupName in pairs(self.spawnedGroups) do
            local group = Group.getByName(groupName)
            if group then
                group:destroy()
            end
        end
    end
    self.state = VeafQRA.STATUS_READY
end

function VeafQRA:start()
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:start()", veaf.p(self.name)))
    self:rearm()
    self:check()
    self.scheduled_state = nil --make sure you reset the scheduled state if you are within the bounds of this method

    if not self.silent then
        local msg = string.format(self.messageStart, self:getDescription())
        for coalition, _ in pairs(self.ennemyCoalitions) do
            trigger.action.outTextForCoalition(coalition, msg, 15)
        end
    end

    return self
end

function VeafQRA:stop(silent)
    veaf.loggers.get(VeafQRA.Id):trace(string.format("VeafQRA[%s]:stop()", veaf.p(self.name)))
    self:setScheduledState(VeafQRA.STATUS_STOP)

    if not self.silent and not silent then
        local msg = string.format(self.messageStop, self:getDescription())
        for coalition, _ in pairs(self.ennemyCoalitions) do
            trigger.action.outTextForCoalition(coalition, msg, 15) 
        end
    end

    return self
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- unique identifers
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.UNIQUE_ID = 10000 + math.random(50,500)

function veaf.getUniqueIdentifier()
    veaf.UNIQUE_ID = veaf.UNIQUE_ID + 1
    return veaf.UNIQUE_ID
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- lines and figures on the map
-------------------------------------------------------------------------------------------------------------------------------------------------------------

VeafDrawingOnMap =
{
    -- technical name (identifier)
    name = nil,
    -- coalition
    coalition = nil,
    -- points forming the drawing
    points = nil,
    -- color ({r, g, b, a})
    color = nil,
    -- fill color ({r, g, b, a})
    fillColor = nil,
    -- type of line (member of VeafDrawingOnMap.LINE_TYPE)
    lineType = nil,
    -- if true, the line is an arrow
    isArrow = nil,
    -- marker ids
    dcsMarkerIds = nil
}
VeafDrawingOnMap.__index = VeafDrawingOnMap

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
    ["twodashes"] = 6
}

VeafDrawingOnMap.COLORS = {
    ["transparent"] = {0, 0, 0, 0},
    ["black"] = {0, 0, 0, 1},
    ["white"] = {1, 1, 1, 1},
    ["red"] = {1, 0, 0, 1},
    ["green"] = {0, 1, 0, 1},
    ["blue"] = {0, 0, 1, 1}
}

VeafDrawingOnMap.DEFAULT_COLOR = {170/255, 10/255, 0/255, 220/255}
VeafDrawingOnMap.DEFAULT_FILLCOLOR = {170/255, 10/255, 0/255, 170/255}

function VeafDrawingOnMap:new()
    veaf.loggers.get(veaf.Id):trace(string.format("VeafDrawingOnMap:new()"))
    local self = setmetatable({}, VeafDrawingOnMap)
    self.name = nil
    self.coalition = -1
    self.points = {}
    self.color = VeafDrawingOnMap.DEFAULT_COLOR
    self.fillColor = VeafDrawingOnMap.DEFAULT_FILLCOLOR
    self.lineType = VeafDrawingOnMap.LINE_TYPE.solid
    self.isArrow = false
    self.dcsMarkerIds = {}
    return self
end

function VeafDrawingOnMap:setName(value)
    veaf.loggers.get(veaf.Id):trace(string.format("VeafDrawingOnMap[]:setName(%s)", veaf.p(value)))
    self.name = value
    return self
end

function VeafDrawingOnMap:getName()
    return self.name
end
 
function VeafDrawingOnMap:setCoalition(value)
    veaf.loggers.get(veaf.Id):trace(string.format("VeafDrawingOnMap[%s]:setCoalition(%s)", veaf.p(self:getName()), veaf.p(value)))
    self.coalition = value
    return self
end

function VeafDrawingOnMap:getCoalition()
    return self.coalition
end

function VeafDrawingOnMap:addPoint(value)
    veaf.loggers.get(veaf.Id):trace(string.format("VeafDrawingOnMap[%s]:addPoint(%s)", veaf.p(self.name), veaf.p(value)))
    table.insert(self.points, 1, mist.utils.deepCopy(value))
    return self
end

function VeafDrawingOnMap:addPoints(value)
    veaf.loggers.get(veaf.Id):trace(string.format("VeafDrawingOnMap[%s]:addPoints(%s)", veaf.p(self.name), veaf.p(value)))
    if value and #value > 0 then
        for _, item in pairs(value) do
            self:addPoint(item)
        end
    end
    return self
end

function VeafDrawingOnMap:setPointsFromUnits(unitNames)
    veaf.loggers.get(veaf.Id):debug(string.format("VeafDrawingOnMap[%s]:setPointsFromUnits()", veaf.p(self.name)))
    local polygon = veaf.getPolygonFromUnits(unitNames)
    self:addPoints(polygon)
    return self
end

function VeafDrawingOnMap:setColor(value)
    veaf.loggers.get(veaf.Id):trace(string.format("VeafDrawingOnMap[%s]:setColor(%s)", veaf.p(self:getName()), veaf.p(value)))
    if value and type(value) == "string" then
        value = VeafDrawingOnMap.COLORS[value:lower()]
    end
    if value then
        self.color = mist.utils.deepCopy(value)
    end
    return self
end

function VeafDrawingOnMap:setFillColor(value)
    veaf.loggers.get(veaf.Id):trace(string.format("VeafDrawingOnMap[%s]:setFillColor(%s)", veaf.p(self:getName()), veaf.p(value)))
    if value and type(value) == "string" then
        value = VeafDrawingOnMap.COLORS[value:lower()]
    end
    if value then
        self.fillColor = mist.utils.deepCopy(value)
    end
    return self
end

function VeafDrawingOnMap:setLineType(value)
    veaf.loggers.get(veaf.Id):trace(string.format("VeafDrawingOnMap[%s]:setLineType(%s)", veaf.p(self:getName()), veaf.p(value)))
    if value and type(value) == "string" then
        value = VeafDrawingOnMap.LINE_TYPE[value:lower()]
    end
    if value then
        self.lineType = value
    end
    return self
end

function VeafDrawingOnMap:setArrow()
    veaf.loggers.get(veaf.Id):trace(string.format("VeafDrawingOnMap[%s]:setArrow()", veaf.p(self:getName())))
    self.isArrow = true
    return self
end

function VeafDrawingOnMap:draw()
    veaf.loggers.get(veaf.Id):trace(string.format("VeafDrawingOnMap[%s]:draw()", veaf.p(self:getName())))

    -- start by erasing the drawing if it already is drawn
    self:erase()

    -- then draw it
    local lastPoint = nil
    local firstPoint = nil
    for _, point in pairs(self.points) do
        veaf.loggers.get(veaf.Id):trace(string.format("drawing line [%s] - [%s]", veaf.p(lastPoint), veaf.p(point)))
        local id = veaf.getUniqueIdentifier()
        if lastPoint then
            veaf.loggers.get(veaf.Id):trace(string.format("id=[%s]", veaf.p(id)))
            if self.isArrow then
                trigger.action.arrowToAll(self:getCoalition(), id, lastPoint, point, self.color, self.fillColor, self.lineType, true)
            else
                trigger.action.lineToAll(self:getCoalition(), id, lastPoint, point, self.color, self.lineType, true)
            end
        else
            veaf.loggers.get(veaf.Id):trace(string.format("setting firstPoint to [%s]", veaf.p(point)))
            trigger.action.markToCoalition(id, self.name, point, self.coalition, true, nil)
            firstPoint = point
        end
        table.insert(self.dcsMarkerIds, id)
        lastPoint = point
    end

    -- finish the polygon
    if firstPoint and lastPoint and #self.points > 2 and not self.isArrow then
        veaf.loggers.get(veaf.Id):trace(string.format("finishing the polygon"))
        local id = veaf.getUniqueIdentifier()
        veaf.loggers.get(veaf.Id):trace(string.format("id=[%s]", veaf.p(id)))
        if self.isArrow then
            trigger.action.arrowToAll(self:getCoalition(), id, lastPoint, firstPoint, self.color, self.fillColor, self.lineType, true)
        else
            trigger.action.lineToAll(self:getCoalition(), id, lastPoint, firstPoint, self.color, self.lineType, true)
        end
        table.insert(self.dcsMarkerIds, id)
    end
end

function VeafDrawingOnMap:erase()
    veaf.loggers.get(veaf.Id):trace(string.format("VeafDrawingOnMap[%s]:erase()", veaf.p(self:getName())))
    if self.dcsMarkerIds then
        for _, id in pairs(self.dcsMarkerIds) do
            veaf.loggers.get(veaf.Id):trace(string.format("removing mark id=[%s]", veaf.p(id)))
            trigger.action.removeMark(id)
        end
    end
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
                ["color"] =
                {
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
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- initialize the random number generator to make it almost random
math.random(); math.random(); math.random()

--- Enable/Disable error boxes displayed on screen.
env.setErrorMessageBoxEnabled(false)

veaf.loggers.get(veaf.Id):info("Loading version %s", veaf.Version)
veaf.loggers.get(veaf.Id):info("veaf.Development=%s", veaf.Development)
veaf.loggers.get(veaf.Id):info("veaf.SecurityDisabled=%s", veaf.SecurityDisabled)
veaf.loggers.get(veaf.Id):info("veaf.Debug=%s", veaf.Debug)
veaf.loggers.get(veaf.Id):info("veaf.Trace=%s", veaf.Trace)

-- discover trigger zones
veaf._discoverTriggerZones()

--store maximum airbase lifes
veaf.loadAirbasesLife0()

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- changes to CTLD 
-------------------------------------------------------------------------------------------------------------------------------------------------------------
if ctld then
    veaf.loggers.get(veaf.Id):info(string.format("Setting up CTLD"))

    -- change the init function so we can call it whenever we want
    ctld.skipInitialisation = true

    -- logging change
    ctld.p = veaf.p
    ctld.Id = "CTLD"
    ctld.LogLevel = "info"
    --ctld.LogLevel = "trace"
    --ctld.LogLevel = "debug"

    ctld.logger = veaf.loggers.new(ctld.Id, ctld.LogLevel)

    ctld.logError = function(message)
        veaf.loggers.get(ctld.Id):error(message)
    end

    ctld.logInfo = function(message)
        veaf.loggers.get(ctld.Id):info(message)
    end    

    ctld.logDebug = function(message)
        veaf.loggers.get(ctld.Id):debug(message)
    end    

    ctld.logTrace = function(message)
        veaf.loggers.get(ctld.Id):trace(message)
    end    

    -- global configuration change
    ctld.cratesRequiredForFOB = 1

    --- replace the crate 3D model with an actual crate
    ctld.spawnableCratesModel_load = {
        ["category"] = "Cargos",
        ["shape_name"] = "bw_container_cargo",
        ["type"] = "container_cargo"
    }

    -- Simulated Sling load configuration
    ctld.minimumHoverHeight = 5.0 -- Lowest allowable height for crate hover
    ctld.maximumHoverHeight = 15.0 -- Highest allowable height for crate hover
    ctld.maxDistanceFromCrate = 8.0 -- Maximum distance from from crate for hover
    ctld.hoverTime = 10 -- Time to hold hover above a crate for loading in seconds

    -- ************** Maximum Units SETUP for UNITS ******************

    ctld.unitLoadLimits["UH-1H"] = 10
    ctld.unitLoadLimits["Mi-24P"] = 10
    ctld.unitLoadLimits["Mi-8MT"] = 20
    ctld.unitLoadLimits["UH-60L"] = 20
    ctld.unitLoadLimits["Yak-52"] = 1

    -- ************** Allowable actions for UNIT TYPES ******************

    ctld.unitActions["Yak-52"] = {crates=false, troops=true}
    ctld.unitActions["UH-60L"] = {crates=true, troops=true}

    -- ************** INFANTRY GROUPS FOR PICKUP ******************

    table.insert(ctld.loadableGroups, {name = "2x - Standard Groups", inf = 12, mg = 4, at = 4 })
    table.insert(ctld.loadableGroups, {name = "3x - Mortar Squad", mortar = 18})
    
    ctld.autoInitializeAllHumanTransports = function()
        veaf.loggers.get(ctld.Id):info("autoInitializeAllHumanTransports()")
        local TransportTypeNames = {"Mi-8MT", "UH-1H", "Mi-24P", "Yak-52", "UH-60L"}
        for name, unit in pairs(mist.DBs.humansByName) do
            veaf.loggers.get(ctld.Id):trace(string.format("human player found name=%s, unitName=%s, groupName=%s", name, unit.unitName,unit.groupName))
            -- check if it's a transport helo
            for _, transportTypeName in pairs(TransportTypeNames) do
                if transportTypeName:lower() == unit.type:lower() then
                    table.insert(ctld.transportPilotNames, unit.unitName)
                    veaf.loggers.get(ctld.Id):debug(string.format("Adding CTLD transport pilot %s of group %s", unit.unitName, unit.groupName))
                end
            end
        end
        veaf.loggers.get(ctld.Id):trace("ctld.transportPilotNames=%s", veaf.p(ctld.transportPilotNames))
    end

    ctld.autoInitializeAllLogistic = function()
        veaf.loggers.get(ctld.Id):info("autoInitializeAllLogistic()")
        local CarrierTypeNames = {"LHA_Tarawa", "Stennis", "CVN_71", "KUZNECOW"}
        local units = mist.DBs.unitsByName -- local copy for faster execution
        for name, unit in pairs(units) do
            veaf.loggers.get(ctld.Id):trace(string.format("name=%s, unit.type=%s", veaf.p(name), veaf.p(unit.type)))
            --veaf.loggers.get(ctld.Id):trace(string.format("unit=%s", veaf.p(unit)))
            --local unit = Unit.getByName(name)
            if unit then 
                for _, carrierTypeName in pairs(CarrierTypeNames) do
                    if carrierTypeName:lower() == unit.type:lower() then
                        table.insert(ctld.logisticUnits, unit.unitName)
                        veaf.loggers.get(ctld.Id):debug(string.format("Adding CTLD logistic unit %s of group %s", unit.unitName, unit.groupName))
                    end
                end
            end
        end
        veaf.loggers.get(ctld.Id):trace("ctld.logisticUnits=%s", veaf.p(ctld.logisticUnits))
    end

    -- generate 20 pickup zone names in the form "pickzone #001"
    veaf.loggers.get(ctld.Id):debug("generate 20 pickup zone names in the form 'pickzone #001'")
    ctld.pickupZones = {}
    for i = 1, 20 do
        table.insert(ctld.pickupZones, { string.format("pickzone #%03d",i), "none", -1, "yes", 0 })
    end

    -- generate 20 logistic unit names in the form "logistic #001"
    veaf.loggers.get(ctld.Id):debug("generate 20 logistic unit names in the form 'logistic #001'")
    ctld.logisticUnits = {}
    for i = 1, 20 do
        table.insert(ctld.logisticUnits, string.format("logistic #%03d",i))
    end
    
    -- Use only the automatic initialization
    ctld.transportPilotNames = {} 

    -- automatically add all the human-manned transport aircrafts to ctld.transportPilotNames
    ctld.autoInitializeAllHumanTransports()

    -- Use only the automatic initialization
    ctld.logisticUnits = {}

    -- automatically add all the carriers and FARPs to ctld.logisticUnits
    ctld.autoInitializeAllLogistic()

    ctld.initialize(true)

    veaf.loggers.get(ctld.Id):info(string.format("Done setting up CTLD"))
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