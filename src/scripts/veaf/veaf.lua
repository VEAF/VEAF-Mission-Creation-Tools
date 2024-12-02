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

--- Version.
veaf.Version = "1.51.0"

--- Development version ?
veaf.Development = false
veaf.SecurityDisabled = false

-- trace level, specific to this module
--veaf.LogLevel = "debug"
--veaf.LogLevel = "trace"
--veaf.ForcedLogLevel = "trace"

-- log level, limiting all the modules
veaf.BaseLogLevel = 5 --trace

veaf.DEFAULT_GROUND_SPEED_KPH = 30
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

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
      -- not my code !
      ---@diagnostic disable-next-line: cast-local-type
      key, pos = veaf.json.parse(str, pos, '}')
      if key == nil then return obj, pos end
      if not delim_found then error('Comma missing between object items.') end
      pos = skip_delim(str, pos, ':', true)  -- true -> error if missing.
      -- not my code !
      ---@diagnostic disable-next-line: need-check-nil
      obj[key], pos = veaf.json.parse(str, pos)
      pos, delim_found = skip_delim(str, pos, ',')
    end
  elseif first == '[' then  -- Parse an array.
    local arr, val, delim_found = {}, true, true
    pos = pos + 1
    while true do
      -- not my code !
      ---@diagnostic disable-next-line: cast-local-type
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

local escapeChars = nil
---Escapes a string so it can no longer be a pattern (regex)
---@param stringToEscape string
---@return string
function veaf.escapeRegex(stringToEscape)
    local regexCharsToEscape = "^$()%.[]*+-?"
    if not escapeChars then
        escapeChars = {}
        for i = 1, string.len(regexCharsToEscape) do
            local char = string.sub(regexCharsToEscape,i,i)
            escapeChars[char] = true
        end
    end

    local result = ""
    if stringToEscape then
        for i = 1, string.len(stringToEscape) do
            local char = string.sub(stringToEscape,i,i)
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

    local function _sortNumberOrCaseInsensitive(a,b)
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
        if type(fields) ~= "table" then
            local field = fields
            fields = { field }
        end
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

function veaf.isNullOrEmpty(s)
    return (s == nil or (type(s) == "string" and s == ""))
end

function veaf.tableContains(table, element)
    if (table == nil or element == nil) then
        return false
    end
    
    for _, e in pairs(table) do
        if (e == element) then 
            return true 
        end
    end
    return false
end

function veaf.p(o, level, skip, includeMeta, dontRecurse)
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
    return veaf._p(o, level, skip, includeMeta, dontRecurse)
end

function veaf._p(o, level, skip, includeMeta, dontRecurse)
    local MAX_LEVEL = 20
    if level == nil then level = 0 end
    if level > MAX_LEVEL then
        veaf.loggers.get(veaf.Id):error("max depth reached in veaf.p : "..tostring(MAX_LEVEL))
        return ""
    end
    local text = ""
    if o == nil then
        text = "[nil]"
    elseif (type(o) == "table") and not(dontRecurse) then
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
                text = text .. ".".. key.."="..veaf.p(value, level+1, skip, includeMeta, dontRecurse) .. "\n"
            else
                text = text .. ".".. key.."= [[SKIPPED]]\n"
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
                    for i=0, level do
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
                        text = text .. "[META].".. key.."="..veaf.p(value, level+1, skip, includeMeta, true) .. "\n"
                    else
                        text = text .. "[META].".. key.."= [[SKIPPED]]\n"
                    end
                end
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
        text = tostring(o)
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
            return result / 3600
        else
            -- decimals
            return tonumber(value)
        end
    end

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

function veaf.getMagneticDeclination()
    local nDeclination = 0
    local sTheatre = string.lower(env.mission.theatre)

    if (sTheatre == "caucasus") then
        nDeclination = 6
    elseif (sTheatre == "persiangulf") then
        nDeclination = 2
    elseif (sTheatre == "nevada") then
        nDeclination = 12
    elseif (sTheatre == "normandy") then
        nDeclination = -10
    elseif (sTheatre == "thechannel") then
        nDeclination = -10
    elseif (sTheatre == "syria") then
        nDeclination = 5
    elseif (sTheatre == "marianaislands") then
        nDeclination = 2
    elseif (sTheatre == "falklands") then
        nDeclination = 12
    elseif (sTheatre == "sinaimap") then
        nDeclination = 4.8
    elseif (sTheatre == "kola") then
        nDeclination = 15
    elseif (sTheatre == "afghanistan") then
        nDeclination = 3
    end
  
    return nDeclination
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
    veaf.loggers.get(veaf.Id):debug("veaf.convertSpeeds(mach=%s, kias=%s, ktas=%s, altitude=%s, temperature=%s, pressure=%s) -> initial", veaf.p(mach), veaf.p(kias), veaf.p(ktas), veaf.p(altitude), veaf.p(temperature), veaf.p(pressure))

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
        if altitude<h_tropopause then
            temperature = T0 + Tz*altitude --troposphere (temp in K)
        else
            temperature = T_tropopause --tropopause (max altitude 20000m) (temp in K)
        end
    else
        temperature = temperature + 273.15 --conversion to Kelvin
    end

    local function P_troposphere(temperature)
        return P0*(1+(temperature-T0)/T0)^(-g/(r*Tz))
    end

    local pressure = pressure
    if not pressure then
        -- compute pressure based on altitude and ISA temperature
        if altitude<h_tropopause then
            pressure = P_troposphere(temperature)
        else
            pressure = P_troposphere(T_tropopause) * math.exp(-g*(altitude-h_tropopause)/(r*T_tropopause))
        end
    end

    ---comment
    ---@param temperature number temperature in K
    ---@return number speed of sound in m/s
    local function speedOfSound(temperature)
        return math.sqrt(Gamma*r*temperature)
    end

    local B = Gamma/(Gamma-1)

    ---comment
    ---@param mach number mach number to calculate (Pt-Ps)/Ps with Pt/Ps given by isentropic relations (NOTE : (Pt-Ps)=deltaP)
    ---@return number returns the ratio deltaP/P (DPP) (what a pitot tube would measure for M<1)
    local function isentropicDPP(mach)
        return (1+(Gamma-1)*mach^2/2)^B-1;
    end

    ---comment
    ---@param mach number mach number to calculate (Pt-Ps)/Ps after a normal shock (M>1) (NOTE : (Pt-Ps)=deltaP)
    ---@return number returns the ratio deltaP/P (DPP) after the normal shock (what a pitot tube would measure for M>1)
    local function lord_rayleighDPP(mach)
        local A = ((Gamma+1)*mach^2/2)^B
        local C = ((Gamma+1)/(2*Gamma*mach^2-Gamma+1))^(B/Gamma);
        return A*C-1;
    end

    ---comment
    ---@param mach1 number the starting mach (mach_0 or mach_p) which determines the deltaP/P1 being computed (for a pitot tube at sea level, subscript 0 (IAS) or at altitude (TAS), subscript p)
    ---@param getTAS boolean? if true, switches to conversion mode from IAS to TAS
    ---@return number so if you provide only mach_P (TAS), this will return mach_0 (IAS), and if you provide mach_0 and getTAS true (IAS), this will return mach_P (TAS)
    local function getConvertedMach(mach1, getTAS)

        veaf.loggers.get(veaf.Id):debug("getConvertedMach(mach1 = %s, getTAS = %s", veaf.p(mach1), veaf.p(getTAS))

        local DPP1 = 0;
        if mach1 > 1 then
            DPP1 = lord_rayleighDPP(mach1); --At this point it's still deltaP / Pp (DPPP) (subscript p = at pitot tube, subscript 0 = at sea level)
        else
            DPP1 = isentropicDPP(mach1); --At this point it's still deltaP / Pp (DPPP) (subscript p = at pitot tube, subscript 0 = at sea level)
        end

        veaf.loggers.get(veaf.Id):debug("DPP1 = %s -> initial", veaf.p(DPP1))

        if getTAS then
            DPP1 = P0*DPP1/pressure --conversion from DPP0 to DPPP
        else
            DPP1 = pressure*DPP1/P0 --conversion from DPPP to DPP0
        end

        veaf.loggers.get(veaf.Id):debug("DPP1 = %s -> final", veaf.p(DPP1))

        local mach2 = 1

        local function converge_2_DPP(machStep)
            while(lord_rayleighDPP(mach2) < DPP1) do --DPP2 = lord_rayleighDPP(mach2)
                mach2 = mach2+machStep
            end

            return mach2
        end

        if DPP1 > lord_rayleighDPP(1) then

            mach2 = converge_2_DPP(0.25) - 0.25 --coarse
            veaf.loggers.get(veaf.Id):debug("coarse mach2 = %s", veaf.p(mach2))
            mach2 = converge_2_DPP(0.0125) - 0.0125 --medium
            veaf.loggers.get(veaf.Id):debug("medium mach2 = %s", veaf.p(mach2))
            mach2 = converge_2_DPP(0.00625) --fine
            veaf.loggers.get(veaf.Id):debug("fine mach2 = %s", veaf.p(mach2))

        else
            mach2 = math.sqrt(2*((DPP1+1)^(1/B)-1)/(Gamma-1))
            veaf.loggers.get(veaf.Id):debug("subsonic mach2 = %s", veaf.p(mach2))
        end

        return mach2
    end

    local ms_2_kt = 1.94384
    local a1 = speedOfSound(temperature)
    local a0 = speedOfSound(T0)
    veaf.loggers.get(veaf.Id):debug("a0 = %s, a1 = %s", veaf.p(a0), veaf.p(a1))


    if mach then
        -- compute speeds from mach number
        result.Mach = mach

        result.TAS_ms = mach * a1
        result.KTAS = result.TAS_ms * ms_2_kt

        result.IAS_ms = getConvertedMach(result.Mach)*a0
        result.KIAS = result.IAS_ms * ms_2_kt
    elseif kias then
        -- compute speeds from ias
        result.KIAS = kias
        result.IAS_ms = result.KIAS / ms_2_kt

        result.TAS_ms = getConvertedMach(result.IAS_ms/a0, true)*a1
        result.KTAS = result.TAS_ms * ms_2_kt

        result.Mach = result.TAS_ms / a1
    elseif ktas then
        -- compute speeds from tas
        result.KTAS = ktas
        result.TAS_ms = result.KTAS / ms_2_kt

        result.Mach = result.TAS_ms / a1

        result.IAS_ms = getConvertedMach(result.Mach)*a0
        result.KIAS = result.IAS_ms * ms_2_kt
    end

    veaf.loggers.get(veaf.Id):debug("veaf.convertSpeeds(mach=%s, kias=%s, ktas=%s, altitude=%s, temperature=%s, pressure=%s) -> final", veaf.p(result.Mach), veaf.p(result.KIAS), veaf.p(result.KTAS), veaf.p(altitude), veaf.p(temperature), veaf.p(pressure))

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
    until ((isShip and landType == land.SurfaceType.WATER) or (not(isShip) and (landType == land.SurfaceType.LAND or landType == land.SurfaceType.ROAD or landType == land.SurfaceType.RUNWAY))) or tryCounter == 0
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
            if zone.verticies  then
                local pointInPolygon = mist.pointInPolygon(unitPosition, zone.verticies)
                if pointInPolygon then
                    unitIsInZone = true
                end
            else
                if ((unitPosition.x - zone.x)^2 + (unitPosition.z - zone.y)^2)^0.5 <= zone.radius then
                    unitIsInZone = true
                end
            end
        end
    end
    return unitIsInZone
end

--- TODO doc
function veaf.generateVehiclesRoute(startPoint, destination, onRoad, speed, patrol, groupName)
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

    local road_x = nil
    local road_z = nil
    local trueStartPoint = mist.utils.deepCopy(startPoint)
    if onRoad then
        veaf.loggers.get(veaf.Id):trace("setting startPoint on a road")
        road_x, road_z = land.getClosestPointOnRoads('roads',startPoint.x, startPoint.z)
        startPoint = veaf.placePointOnLand({x = road_x, y = 0, z = road_z})
    else
        startPoint = veaf.placePointOnLand({x = startPoint.x, y = 0, z = startPoint.z})
    end

    veaf.loggers.get(veaf.Id):trace(string.format("startPoint = {x = %d, y = %d, z = %d}", startPoint.x, startPoint.y, startPoint.z))

    local trueEndPoint = mist.utils.deepCopy(endPoint)
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
        [2] =
        {
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
        [3] =
        {
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

        vehiclesRoute[4] =
        {
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
            ["task"] =
            {
                ["id"] = "ComboTask",
                ["params"] =
                {
                    ["tasks"] =
                    {
                        --sounds good ! doesn't work, pathfinding goes dumb if done this way
                        --[1] = 
                        --{
                        --    ["enabled"] = true,
                        --    ["auto"] = false,
                        --    ["id"] = "GoToWaypoint",
                        --    ["number"] = 1,
                        --    ["params"] = 
                        --    {
                        --        ["fromWaypointIndex"] = 4,
                        --        ["nWaypointIndx"] = 2,
                        --    }, -- end of ["params"]
                        --}, -- end of [1]
                    }, -- end of ["tasks"]
                }, -- end of ["params"]
            }, -- end of ["task"]
            ["speed_locked"] = true,
        }

        veaf.PatrolWatchdog(groupName, vehiclesRoute, speed/3.6, "notSeen")
    elseif onRoad then
        vehiclesRoute[4] =
        {
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
        endWaypoint.task =
        {
            ["id"] = "ComboTask",
            ["params"] =
            {
                ["tasks"] =
                {
                    [1] =
                    {
                        ["number"] = 1,
                        ["auto"] = false,
                        ["id"] = "WrappedAction",
                        ["enabled"] = true,
                        ["params"] =
                        {
                            ["action"] =
                            {
                                ["id"] = "Option",
                                ["params"] =
                                {
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

function veaf.PatrolWatchdog(groupName,patrolRoute,speed,firstPass)
    veaf.loggers.get(veaf.Id):debug(string.format("veaf.PatrolWatchdog(groupName=%s, speed=%s, firstPass=%s)", veaf.p(groupName), veaf.p(speed), veaf.p(firstPass)))
    veaf.loggers.get(veaf.Id):trace(string.format("patrolRoute=%s", veaf.p(patrolRoute)))

    local rescheduleTime = 30
    local maxDist = 10
    if firstPass then
        maxDist = 200
    end
    local startPoint = {x = patrolRoute[1].x, z = patrolRoute[1].y}

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
                    local distanceToStart = (leadPos.x-startPoint.x)^2+(leadPos.z-startPoint.z)^2
                    local result = distanceToStart < maxDist^2

                    if firstPass == "notSeen" and result then
                        firstPass = "seenOnce"
                   elseif firstPass == "seenOnce" and not result then
                        firstPass = false
                    end

                    if not firstPass and result then

                        veaf.loggers.get(veaf.Id):info("Lead vehicle in range, setting route !")
                        mist.goRoute(group,patrolRoute)
                        controller:setSpeed(speed)
                        firstPass = "notSeen"

                    elseif firstPass then
                        veaf.loggers.get(veaf.Id):debug("Lead vehicle is passing in the bubble, rescheduling in " .. rescheduleTime .. "s !")
                    else
                        veaf.loggers.get(veaf.Id):debug("Lead vehicle/lead controller not found or lead vehicle not within " .. maxDist .. "m, rescheduling in " .. rescheduleTime .. "s !")
                    end

                    mist.scheduleFunction(veaf.PatrolWatchdog,{groupName, patrolRoute, speed, firstPass}, timer.getTime()+rescheduleTime)
                end
            elseif not groupUnits[1]:isActive() then
                veaf.loggers.get(veaf.Id):debug("Lead vehicle not active, rescheduling in 60s !")
                mist.scheduleFunction(veaf.PatrolWatchdog,{groupName, patrolRoute, speed, firstPass}, timer.getTime()+60)
            end
        end
    end

    veaf.loggers.get(veaf.Id):debug("========================================================================")
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
            local distanceFromCenter = ((pos.x - center.x)^2 + (pos.z - center.z)^2)^0.5
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
            for _,unit in pairs(units) do
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
                veaf.loggers.get(veaf.Id):trace("found " .. #tasks .. " programmed tasks for carrier " .. carrierUnitName .. " in group " .. carrierGroupName)
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
                                            result.link4 = string.format("%.2f".."MHz",actionParams.frequency / 1000000)
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

function veaf.outTextForUnit(unitName, message, duration, forAllGroup)
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

--- Weather Report. Report pressure QFE/QNH, temperature, wind at certain location.
--- stolen from the weatherReport script and modified to fit our usage
function veaf.weatherReport(vec3, alt, withLASTE)

    -- Get Temperature [K] and Pressure [Pa] at vec3.
    local T
    local Pqfe
    if not alt then
        alt = veaf.getLandHeight(vec3) + 15 -- get the weather at 15m over the ground, as it's done IRL in general aviation
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
    veaf.countriesByName={}
    veaf.countriesNamesById={}

    local function _sortByImportance(c1,c2)
        local importantCountries = { ['usa']=true, ['russia']=true}
        if c1 then
            return importantCountries[c1:lower()]
        end
        return string.lower(c1) < string.lower(c2)
    end

    for coalitionName, countries in pairs(mist.DBs.units) do
        coalitionName = coalitionName:lower()
        veaf.loggers.get(veaf.Id):trace("coalitionName=%s", veaf.p(coalitionName))

        if not veaf.countriesByCoalition[coalitionName] then
            veaf.countriesByCoalition[coalitionName]={}
        end
        veaf.loggers.get(veaf.Id):trace("countries=%s", veaf.p(countries))
        for countryName, country in pairs(countries) do
            veaf.loggers.get(veaf.Id):trace("country=%s", veaf.p(country))
            countryName = countryName:lower()
            table.insert(veaf.countriesByCoalition[coalitionName], countryName)
            veaf.coalitionByCountry[countryName]=coalitionName:lower()
            veaf.countriesByName[countryName] = country
            veaf.countriesNamesById[country.countryId] = countryName
        end

        table.sort(veaf.countriesByCoalition[coalitionName], _sortByImportance)
    end

    veaf.loggers.get(veaf.Id):trace("veaf.countriesByCoalition=%s", veaf.p(veaf.countriesByCoalition))
    veaf.loggers.get(veaf.Id):trace("veaf.coalitionByCountry=%s", veaf.p(veaf.coalitionByCountry))
    veaf.loggers.get(veaf.Id):trace("veaf.countriesByName=%s", veaf.p(veaf.countriesByName))
    veaf.loggers.get(veaf.Id):trace("veaf.countriesNamesById=%s", veaf.p(veaf.countriesNamesById))
end

function veaf.getCountryId(countryName)
    veaf.loggers.get(veaf.Id):trace("veaf.getCountryId(%s)", veaf.p(countryName))
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
    veaf.loggers.get(veaf.Id):trace("veaf.getCountryName(%s)", veaf.p(countryId))
    if not veaf.coalitionByCountry then
        _initializeCountriesAndCoalitions()
    end
    local countryName = veaf.countriesNamesById[countryId]
    return countryName
end

function veaf.getCountryForCoalition(coalition)
    veaf.loggers.get(veaf.Id):trace("veaf.getCountryForCoalition(coalition=%s)", tostring(coalition))
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
                        veaf.loggers.get(veaf.Id):trace(string.format("Airbase category does not have a default life0 setting nor does it have a life, discarding"))
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
    if aTable == nil or #aTable == 0 then
        return nil
    elseif #aTable == 1 then
        return aTable[1]
    end
    local index = math.floor(math.random(1, #aTable)) + (bias or 0)
    if index < 1 then index = 1 end
    if index > #aTable then index = #aTable end
    veaf.loggers.get(veaf.Id):trace(string.format("index = %s", veaf.p(index)))
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
    local MIN = 0
    local MAX = 99
    local nVal = tonumber(val)
    veaf.loggers.get(veaf.Id):trace("nVal=%s", veaf.p(nVal))
    if nVal == nil then
        local dashPos = string.find(val,"%-")
        veaf.loggers.get(veaf.Id):trace("dashPos=%s", veaf.p(dashPos))
        if dashPos then
            local lower = val:sub(1, dashPos-1)
            veaf.loggers.get(veaf.Id):trace("lower=%s", veaf.p(lower))
            if lower then
                lower = tonumber(lower)
            end
            if lower == nil then
                lower = MIN
            end
            local upper = val:sub(dashPos+1)
            veaf.loggers.get(veaf.Id):trace("upper=%s", veaf.p(upper))
            if upper then
                upper = tonumber(upper)
            end
            if upper == nil then
                upper = MAX
            end
            nVal = math.random(lower, upper)
            veaf.loggers.get(veaf.Id):trace("nVal=%s", veaf.p(nVal))
        end
    end
        --[[ 

        if val == "0-1" then nVal = math.random(0,1) end
        if val == "0-2" then nVal = math.random(0,2) end
        if val == "0-3" then nVal = math.random(0,3) end
        if val == "0-4" then nVal = math.random(0,4) end
        if val == "0-5" then nVal = math.random(0,5) end
        if val == "0-6" then nVal = math.random(0,6) end
        if val == "0-7" then nVal = math.random(0,7) end
        if val == "0-8" then nVal = math.random(0,8) end
        if val == "0-9" then nVal = math.random(0,9) end
        if val == "0-10" then nVal = math.random(0,10) end
        if val == "0-11" then nVal = math.random(0,11) end
        if val == "0-12" then nVal = math.random(0,12) end
        if val == "0-13" then nVal = math.random(0,13) end
        if val == "0-14" then nVal = math.random(0,14) end
        if val == "0-15" then nVal = math.random(0,15) end
        if val == "0-16" then nVal = math.random(0,16) end
        if val == "0-17" then nVal = math.random(0,17) end
        if val == "0-18" then nVal = math.random(0,18) end
        if val == "0-19" then nVal = math.random(0,19) end

        if val == "1-2" then nVal = math.random(1,2) end
        if val == "1-3" then nVal = math.random(1,3) end
        if val == "1-4" then nVal = math.random(1,4) end
        if val == "1-5" then nVal = math.random(1,5) end
        if val == "1-6" then nVal = math.random(1,6) end
        if val == "1-7" then nVal = math.random(1,7) end
        if val == "1-8" then nVal = math.random(1,8) end
        if val == "1-9" then nVal = math.random(1,9) end
        if val == "1-10" then nVal = math.random(1,10) end
        if val == "1-11" then nVal = math.random(1,11) end
        if val == "1-12" then nVal = math.random(1,12) end
        if val == "1-13" then nVal = math.random(1,13) end
        if val == "1-14" then nVal = math.random(1,14) end
        if val == "1-15" then nVal = math.random(1,15) end
        if val == "1-16" then nVal = math.random(1,16) end
        if val == "1-17" then nVal = math.random(1,17) end
        if val == "1-18" then nVal = math.random(1,18) end
        if val == "1-19" then nVal = math.random(1,19) end

        if val == "2-3" then nVal = math.random(2,3) end
        if val == "2-4" then nVal = math.random(2,4) end
        if val == "2-5" then nVal = math.random(2,5) end
        if val == "2-6" then nVal = math.random(2,6) end
        if val == "2-7" then nVal = math.random(2,7) end
        if val == "2-8" then nVal = math.random(2,8) end
        if val == "2-9" then nVal = math.random(2,9) end
        if val == "2-10" then nVal = math.random(2,10) end
        if val == "2-11" then nVal = math.random(2,11) end
        if val == "2-12" then nVal = math.random(2,12) end
        if val == "2-13" then nVal = math.random(2,13) end
        if val == "2-14" then nVal = math.random(2,14) end
        if val == "2-15" then nVal = math.random(2,15) end
        if val == "2-16" then nVal = math.random(2,16) end
        if val == "2-17" then nVal = math.random(2,17) end
        if val == "2-18" then nVal = math.random(2,18) end
        if val == "2-19" then nVal = math.random(2,19) end

        if val == "3-4" then nVal = math.random(3,4) end
        if val == "3-5" then nVal = math.random(3,5) end
        if val == "3-6" then nVal = math.random(3,6) end
        if val == "3-7" then nVal = math.random(3,7) end
        if val == "3-8" then nVal = math.random(3,8) end
        if val == "3-9" then nVal = math.random(3,9) end
        if val == "3-10" then nVal = math.random(3,10) end
        if val == "3-11" then nVal = math.random(3,11) end
        if val == "3-12" then nVal = math.random(3,12) end
        if val == "3-13" then nVal = math.random(3,13) end
        if val == "3-14" then nVal = math.random(3,14) end
        if val == "3-15" then nVal = math.random(3,15) end
        if val == "3-16" then nVal = math.random(3,16) end
        if val == "3-17" then nVal = math.random(3,17) end
        if val == "3-18" then nVal = math.random(3,18) end
        if val == "3-19" then nVal = math.random(3,19) end

        if val == "4-5" then nVal = math.random(4,5) end
        if val == "4-6" then nVal = math.random(4,6) end
        if val == "4-7" then nVal = math.random(4,7) end
        if val == "4-8" then nVal = math.random(4,8) end
        if val == "4-9" then nVal = math.random(4,9) end
        if val == "4-10" then nVal = math.random(4,10) end
        if val == "4-11" then nVal = math.random(4,11) end
        if val == "4-12" then nVal = math.random(4,12) end
        if val == "4-13" then nVal = math.random(4,13) end
        if val == "4-14" then nVal = math.random(4,14) end
        if val == "4-15" then nVal = math.random(4,15) end
        if val == "4-16" then nVal = math.random(4,16) end
        if val == "4-17" then nVal = math.random(4,17) end
        if val == "4-18" then nVal = math.random(4,18) end
        if val == "4-19" then nVal = math.random(4,19) end

        if val == "5-6" then nVal = math.random(5,6) end
        if val == "5-7" then nVal = math.random(5,7) end
        if val == "5-8" then nVal = math.random(5,8) end
        if val == "5-9" then nVal = math.random(5,9) end
        if val == "5-10" then nVal = math.random(5,10) end
        if val == "5-11" then nVal = math.random(5,11) end
        if val == "5-12" then nVal = math.random(5,12) end
        if val == "5-13" then nVal = math.random(5,13) end
        if val == "5-14" then nVal = math.random(5,14) end
        if val == "5-15" then nVal = math.random(5,15) end
        if val == "5-16" then nVal = math.random(5,16) end
        if val == "5-17" then nVal = math.random(5,17) end
        if val == "5-18" then nVal = math.random(5,18) end
        if val == "5-19" then nVal = math.random(5,19) end

        if val == "6-7" then nVal = math.random(6,7) end
        if val == "6-8" then nVal = math.random(6,8) end
        if val == "6-9" then nVal = math.random(6,9) end
        if val == "6-10" then nVal = math.random(6,10) end
        if val == "6-11" then nVal = math.random(6,11) end
        if val == "6-12" then nVal = math.random(6,12) end
        if val == "6-13" then nVal = math.random(6,13) end
        if val == "6-14" then nVal = math.random(6,14) end
        if val == "6-15" then nVal = math.random(6,15) end
        if val == "6-16" then nVal = math.random(6,16) end
        if val == "6-17" then nVal = math.random(6,17) end
        if val == "6-18" then nVal = math.random(6,18) end
        if val == "6-19" then nVal = math.random(6,19) end

        if val == "7-8" then nVal = math.random(7,8) end
        if val == "7-9" then nVal = math.random(7,9) end
        if val == "7-10" then nVal = math.random(7,10) end
        if val == "7-11" then nVal = math.random(7,11) end
        if val == "7-12" then nVal = math.random(7,12) end
        if val == "7-13" then nVal = math.random(7,13) end
        if val == "7-14" then nVal = math.random(7,14) end
        if val == "7-15" then nVal = math.random(7,15) end
        if val == "7-16" then nVal = math.random(7,16) end
        if val == "7-17" then nVal = math.random(7,17) end
        if val == "7-18" then nVal = math.random(7,18) end
        if val == "7-19" then nVal = math.random(7,19) end

        if val == "8-9" then nVal = math.random(8,9) end
        if val == "8-10" then nVal = math.random(8,10) end
        if val == "8-11" then nVal = math.random(8,11) end
        if val == "8-12" then nVal = math.random(8,12) end
        if val == "8-13" then nVal = math.random(8,13) end
        if val == "8-14" then nVal = math.random(8,14) end
        if val == "8-15" then nVal = math.random(8,15) end
        if val == "8-16" then nVal = math.random(8,16) end
        if val == "8-17" then nVal = math.random(8,17) end
        if val == "8-18" then nVal = math.random(8,18) end
        if val == "8-19" then nVal = math.random(8,19) end

        if val == "9-10" then nVal = math.random(9,10) end
        if val == "9-11" then nVal = math.random(9,11) end
        if val == "9-12" then nVal = math.random(9,12) end
        if val == "9-13" then nVal = math.random(9,13) end
        if val == "9-14" then nVal = math.random(9,14) end
        if val == "9-15" then nVal = math.random(9,15) end
        if val == "9-16" then nVal = math.random(9,16) end
        if val == "9-17" then nVal = math.random(9,17) end
        if val == "9-18" then nVal = math.random(9,18) end
        if val == "9-19" then nVal = math.random(9,19) end

        if val == "10-11" then nVal = math.random(10,11) end
        if val == "10-12" then nVal = math.random(10,12) end
        if val == "10-13" then nVal = math.random(10,13) end
        if val == "10-14" then nVal = math.random(10,14) end
        if val == "10-15" then nVal = math.random(10,15) end
        if val == "10-16" then nVal = math.random(10,16) end
        if val == "10-17" then nVal = math.random(10,17) end
        if val == "10-18" then nVal = math.random(10,18) end
        if val == "10-19" then nVal = math.random(10,19) end

        if val == "11-12" then nVal = math.random(11,12) end
        if val == "11-13" then nVal = math.random(11,13) end
        if val == "11-14" then nVal = math.random(11,14) end
        if val == "11-15" then nVal = math.random(11,15) end
        if val == "11-16" then nVal = math.random(11,16) end
        if val == "11-17" then nVal = math.random(11,17) end
        if val == "11-18" then nVal = math.random(11,18) end
        if val == "11-19" then nVal = math.random(11,19) end

        if val == "12-13" then nVal = math.random(12,13) end
        if val == "12-14" then nVal = math.random(12,14) end
        if val == "12-15" then nVal = math.random(12,15) end
        if val == "12-16" then nVal = math.random(12,16) end
        if val == "12-17" then nVal = math.random(12,17) end
        if val == "12-18" then nVal = math.random(12,18) end
        if val == "12-19" then nVal = math.random(12,19) end

        if val == "13-14" then nVal = math.random(13,14) end
        if val == "13-15" then nVal = math.random(13,15) end
        if val == "13-16" then nVal = math.random(13,16) end
        if val == "13-17" then nVal = math.random(13,17) end
        if val == "13-18" then nVal = math.random(13,18) end
        if val == "13-19" then nVal = math.random(13,19) end

        if val == "14-15" then nVal = math.random(14,15) end
        if val == "14-16" then nVal = math.random(14,16) end
        if val == "14-17" then nVal = math.random(14,17) end
        if val == "14-18" then nVal = math.random(14,18) end
        if val == "14-19" then nVal = math.random(14,19) end

        if val == "15-16" then nVal = math.random(15,16) end
        if val == "15-17" then nVal = math.random(15,17) end
        if val == "15-18" then nVal = math.random(15,18) end
        if val == "15-19" then nVal = math.random(15,19) end

        if val == "16-17" then nVal = math.random(16,17) end
        if val == "16-18" then nVal = math.random(16,18) end
        if val == "16-19" then nVal = math.random(16,19) end

        if val == "17-18" then nVal = math.random(17,18) end
        if val == "17-19" then nVal = math.random(17,19) end

        if val == "18-19" then nVal = math.random(18,19) end
        ]]

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
        if l_filepath then l_filepath = l_filepath .. "\\" end
        veaf.loggers.get(veaf.Id):debug(string.format("filepath=%s", veaf.p(l_filepath)))
    end
    if not l_filepath and l_lfs then
        l_filepath = l_lfs.writedir()
        veaf.loggers.get(veaf.Id):debug(string.format("filepath=%s", veaf.p(l_filepath)))
    end
    if not l_filepath and l_os then
        l_filepath = l_os.getenv("TEMP")
        if l_filepath then l_filepath = l_filepath .. "\\" end
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
        date = tostring(l_os.date('%Y-%m-%d %H:%M:%S.000'))
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
        if l_export_path then l_export_path = l_export_path .. "\\" end
        veaf.loggers.get(veaf.Id):debug(string.format("filepath=%s", veaf.p(l_export_path)))
    end
    if not l_export_path and l_lfs then
        l_export_path = l_lfs.writedir()
        veaf.loggers.get(veaf.Id):debug(string.format("filepath=%s", veaf.p(l_export_path)))
    end
    if not l_export_path and l_os then
        l_export_path = l_os.getenv("TEMP")
        if l_export_path then l_export_path = l_export_path .. "\\" end
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
        file:write(text.."\r\n")
    end

    local filename = filename or name .. ".json"
    veaf.loggers.get(veaf.Id):trace(string.format("filename=%s", veaf.p(filename)))

    veaf.loggers.get(veaf.Id):info("Dumping ".. name .." as json to "..filename .. " in ".. l_export_path)

    local header =    '{\n'
    header = header .. '  "' .. name .. '": [\n'

    local content = {}
    for key, value in pairs(data) do
        local line =  jsonify(key, value)
        veaf.loggers.get(veaf.Id):trace("line=%s", veaf.p(line))
        table.insert(content, line)
    end
    local footer =    '\n'
    footer = footer .. ']\n'
    footer = footer .. '}\n'

    local file = l_io.open(l_export_path .. filename, "w")
    writeln(file, header)
    writeln(file, table.concat(content, ",\n"))
    writeln(file, footer)
    if file then file:close() end
end

function veaf.isUnitAlive(unit)
    return unit and unit:isExist() and unit:isActive()
end

function veaf.getUnitLifeRelative(unit)
    if unit and veaf.isUnitAlive(unit) then
        local unitLife=unit:getLife()
        local unitLife0 = 0
        if unit.getLife0 then -- statics have no life0
          unitLife0 = unit:getLife0()
        end
        if unitLife0 > 0 then
            return unitLife/unitLife0
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
    return string.sub(aString,1,string.len(aPrefix))==aPrefix
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
        local args = ...
        if args and args.n and args.n > 0 then
            local pArgs = {}
            for i=1,args.n do
                pArgs[i] = veaf.p(args[i])
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
        text = veaf.Logger.formatText(text, arg)
        local mText = text
		if debug and debug.traceback then
			mText = mText .. "\n" .. debug.traceback()
		end
        self:print(1, mText)
    end
end

function veaf.Logger:warn(text, ...)
    if self.level >= 2 then
        text = veaf.Logger.formatText(text, arg)
        self:print(2, text)
    end
end

function veaf.Logger:info(text, ...)
    if self.level >= 3 then
        text = veaf.Logger.formatText(text, arg)
        self:print(3, text)
    end
end

function veaf.Logger:debug(text, ...)
    if self.level >= 4 then
        text = veaf.Logger.formatText(text, arg)
        self:print(4, text)
    end
end

function veaf.Logger:trace(text, ...)
    if self.level >= 5 then
        text = veaf.Logger.formatText(text, arg)
        self:print(5, text)
    end
end

function veaf.Logger:wouldLogWarn()
    return self.level >= 2
end

function veaf.Logger:wouldLogInfo()
    return self.level >= 3
end

function veaf.Logger:wouldLogDebug()
    return self.level >= 4
end

function veaf.Logger:wouldLogTrace()
    return self.level >= 5
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

VeafDrawingOnMap = {}
VeafDrawingOnMap.DEFAULT_COLOR = {170/255, 10/255, 0/255, 220/255}
VeafDrawingOnMap.DEFAULT_FILLCOLOR = {170/255, 10/255, 0/255, 170/255}
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
    ["twodashes"] = 6
}

VeafDrawingOnMap.COLORS = {
    ["transparent"] = {0, 0, 0, 0},
    ["black"] = {0, 0, 0, 1},
    ["white"] = {1, 1, 1, 1},
    ["red"] = {1, 0, 0, 1},
    ["pink"] = {1, 0, 0, 0.3},
    ["green"] = {0, 1, 0, 1},
    ["blue"] = {0, 0, 1, 1}
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
    veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[]:setName(%s)", veaf.p(value))
    self.name = value
    return self
end

function VeafDrawingOnMap:getName()
    return self.name
end

function VeafDrawingOnMap:setCoalition(value)
    veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:setCoalition(%s)", veaf.p(self:getName()), veaf.p(value))
    self.coalition = value
    return self
end

function VeafDrawingOnMap:getCoalition()
    return self.coalition
end

function VeafDrawingOnMap:addPoint(value)
    veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:addPoint(%s)", veaf.p(self.name), veaf.p(value))
    table.insert(self.points, 1, mist.utils.deepCopy(value))
    return self
end

function VeafDrawingOnMap:addPoints(value)
    veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:addPoints(%s)", veaf.p(self.name), veaf.p(value))
    if value and #value > 0 then
        for _, item in pairs(value) do
            self:addPoint(item)
        end
    end
    return self
end

function VeafDrawingOnMap:setPointsFromUnits(unitNames)
    veaf.loggers.get(veaf.Id):debug("VeafDrawingOnMap[%s]:setPointsFromUnits()", veaf.p(self.name))
    local polygon = veaf.getPolygonFromUnits(unitNames)
    self:addPoints(polygon)
    return self
end

function VeafDrawingOnMap:setColor(value)
    veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:setColor(%s)", veaf.p(self:getName()), veaf.p(value))
    if value and type(value) == "string" then
        value = VeafDrawingOnMap.COLORS[value:lower()]
    end
    if value then
        self.color = mist.utils.deepCopy(value)
    end
    return self
end

function VeafDrawingOnMap:setFillColor(value)
    veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:setFillColor(%s)", veaf.p(self:getName()), veaf.p(value))
    if value and type(value) == "string" then
        value = VeafDrawingOnMap.COLORS[value:lower()]
    end
    if value then
        self.fillColor = mist.utils.deepCopy(value)
    end
    return self
end

function VeafDrawingOnMap:setLineType(value)
    veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:setLineType(%s)", veaf.p(self:getName()), veaf.p(value))
    if value and type(value) == "string" then
        value = VeafDrawingOnMap.LINE_TYPE[value:lower()]
    end
    if value then
        self.lineType = value
    end
    return self
end

function VeafDrawingOnMap:setArrow()
    veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:setArrow()", veaf.p(self:getName()))
    self.isArrow = true
    return self
end

function VeafDrawingOnMap:draw()
    veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:draw()", veaf.p(self:getName()))

    -- start by erasing the drawing if it already is drawn
    self:erase()

    -- then draw it
    local lastPoint = nil
    local firstPoint = nil
    for _, point in pairs(self.points) do
        veaf.loggers.get(veaf.Id):trace("drawing line [%s] - [%s]", veaf.p(lastPoint), veaf.p(point))
        local id = veaf.getUniqueIdentifier()
        if lastPoint then
            veaf.loggers.get(veaf.Id):trace("id=[%s]", veaf.p(id))
            if self.isArrow then
                trigger.action.arrowToAll(self:getCoalition(), id, lastPoint, point, self.color, self.fillColor, self.lineType, true)
            else
                trigger.action.lineToAll(self:getCoalition(), id, lastPoint, point, self.color, self.lineType, true)
            end
        else
            veaf.loggers.get(veaf.Id):trace("setting firstPoint to [%s]", veaf.p(point))
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
        veaf.loggers.get(veaf.Id):trace("id=[%s]", veaf.p(id))
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
    veaf.loggers.get(veaf.Id):trace("VeafDrawingOnMap[%s]:erase()", veaf.p(self:getName()))
    if self.dcsMarkerIds then
        for _, id in pairs(self.dcsMarkerIds) do
            veaf.loggers.get(veaf.Id):trace("removing mark id=[%s]", veaf.p(id))
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
    veaf.loggers.get(veaf.Id):trace("VeafCircleOnMap[%s]:setCenter(%s)", veaf.p(self.name), veaf.p(value))
    self.points = { mist.utils.deepCopy(value) }
    return self
end

function VeafCircleOnMap:setRadius(value)
    veaf.loggers.get(veaf.Id):trace("VeafCircleOnMap[%s]:setRadius(%s)", veaf.p(self.name), veaf.p(value))
    self.radius = value
    return self
end

function VeafCircleOnMap:draw()
    veaf.loggers.get(veaf.Id):trace("VeafCircleOnMap[%s]:draw()", veaf.p(self:getName()))

    -- start by erasing the drawing if it already is drawn
    self:erase()

    -- then draw it
    local id = veaf.getUniqueIdentifier()
    veaf.loggers.get(veaf.Id):trace("id=[%s]", veaf.p(id))
    trigger.action.circleToAll(self:getCoalition(), id , self.points[1], self.radius , self.color, self.fillColor, self.lineType, true)
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
    veaf.loggers.get(veaf.Id):trace("VeafSquareOnMap[%s]:setCenter(%s)", veaf.p(self.name), veaf.p(value))
    self.center = mist.utils.deepCopy(value)
    self:compute()
    return self
end

function VeafSquareOnMap:setSide(value)
    veaf.loggers.get(veaf.Id):trace("VeafSquareOnMap[%s]:setSide(%s)", veaf.p(self.name), veaf.p(value))
    self.side = value
    self:compute()
    return self
end

function VeafSquareOnMap:compute()
    veaf.loggers.get(veaf.Id):trace("VeafSquareOnMap[%s]:compute()", veaf.p(self.name))
    if self.side and self.center then
        veaf.loggers.get(veaf.Id):trace("self.center=%s", veaf.p(self.center))
        veaf.loggers.get(veaf.Id):trace("self.side=%s", veaf.p(self.side))
        local leftDownPoint = { x = self.center.x - self.side / 2, y = self.center.y, z = self.center.z - self.side / 2 }
        veaf.loggers.get(veaf.Id):trace("leftDownPoint=%s", veaf.p(leftDownPoint))
        local rightUpPoint = { x = self.center.x + self.side / 2, y = self.center.y,z = self.center.z + self.side / 2 }
        veaf.loggers.get(veaf.Id):trace("rightUpPoint=%s", veaf.p(rightUpPoint))
        self.points = { leftDownPoint, rightUpPoint }
    end
    return self
end

function VeafSquareOnMap:draw()
    veaf.loggers.get(veaf.Id):trace("VeafSquareOnMap[%s]:draw()", veaf.p(self:getName()))

    -- start by erasing the drawing if it already is drawn
    self:erase()

    -- then draw it
    local id = veaf.getUniqueIdentifier()
    veaf.loggers.get(veaf.Id):trace("id=[%s]", veaf.p(id))
    trigger.action.rectToAll(self:getCoalition(), id , self.points[1], self.points[2], self.color, self.fillColor, self.lineType, true)
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
veaf.loggers.get(veaf.Id):info("veaf.LogLevel=%s", veaf.LogLevel)
veaf.loggers.get(veaf.Id):info("veaf.ForcedLogLevel=%s", veaf.ForcedLogLevel)

-- discover trigger zones
veaf._discoverTriggerZones()

--store maximum airbase lifes
veaf.loadAirbasesLife0()

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- changes to CTLD 
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Our CTLD (VEAF version) does not autoinitialize. It's also set to log messages using the VEAF logging functions
-- Instead, we count on the mission makers to call ctld.initialize from the missionConfig.lua file (since v5.0)
-- Here, we're upgrading the vanilla CTLD initialize function so it's smarter

---The VEAF replacement function that wraps up around ctld.initialize
---@param configurationCallback function? a callback that will be called before calling the vanilla ctld.initialize function
function veaf.ctld_initialize_replacement(configurationCallback)
    if ctld then
        veaf.loggers.get(veaf.Id):info(string.format("Setting up CTLD"))

        -- change the init function so we can call it whenever we want
        ctld.skipInitialisation = true

        -- logging change
        ctld.p = veaf.p
        ctld.Id = "CTLD"
        --ctld.LogLevel = "info"
        --ctld.LogLevel = "debug"
        ctld.LogLevel = "trace"

        ctld.logger = veaf.loggers.new(ctld.Id, ctld.LogLevel)

        -- override the ctld logs with our own methods
        ---@diagnostic disable-next-line: duplicate-set-field
        ctld.logError = function(message, args)
            veaf.loggers.get(ctld.Id):error(message, args)
        end

        -- override the ctld logs with our own methods
        ---@diagnostic disable-next-line: duplicate-set-field
        ctld.logInfo = function(message, args)
            veaf.loggers.get(ctld.Id):info(message, args)
        end

        -- override the ctld logs with our own methods
        ---@diagnostic disable-next-line: duplicate-set-field
        ctld.logDebug = function(message, args)
            veaf.loggers.get(ctld.Id):debug(message, args)
        end

        -- override the ctld logs with our own methods
        ---@diagnostic disable-next-line: duplicate-set-field
        ctld.logTrace = function(message, args)
            veaf.loggers.get(ctld.Id):trace(message, args)
        end

        -- global configuration change
        ctld.addPlayerAircraftByType = true
        ctld.loadCrateFromMenu = true -- if set to true, you can load crates with the F10 menu OR hovering, in case of using choppers and planes for example.
        ctld.slingLoad = true -- if false, crates can be used WITHOUT slingloading, by hovering above the crate, simulating slingloading but not the weight...
        ctld.crateWaitTime = 0 -- time in seconds to wait before you can spawn another crate
        
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
        ctld.unitLoadLimits["SA342L"] = 1
        ctld.unitLoadLimits["SA342M"] = 1
        ctld.unitLoadLimits["SA342Mistral"] = 1
        ctld.unitLoadLimits["SA342Minigun"] = 1
        ctld.unitLoadLimits["CH-47Fbl1"] = 33

        ctld.internalCargoLimits["Mi-8MT"] = 2
        ctld.internalCargoLimits["CH-47Fbl1"] = 4

        -- ************** Allowable actions for UNIT TYPES ******************
        ctld.aircraftTypeTable = {
                "Hercules",
                "UH-60L",
                "Ka-50",
                "Ka-50_3",
                "Mi-8MT",
                "Mi-24P",
                "SA342L",
                "SA342M",
                "SA342Mistral",
                "SA342Minigun",
                "UH-1H",
                "CH-47Fbl1",
                "Yak-52",
        }

        ctld.unitActions["Yak-52"] = {crates=false, troops=true}
        ctld.unitActions["UH-60L"] = {crates=true, troops=true}
        ctld.unitActions["SA342L"] = {crates=false, troops=true}
        ctld.unitActions["SA342M"] = {crates=false, troops=true}
        ctld.unitActions["SA342Mistral"] = {crates=false, troops=true}
        ctld.unitActions["SA342Minigun"] = {crates=false, troops=true}

        -- ************** INFANTRY GROUPS FOR PICKUP ******************

        ctld.autoInitializeAllLogistic = function()
            local LogisticTypeNames = {"LHA_Tarawa", "Stennis", "CVN_71", "KUZNECOW", "FARP Ammo Storage", "FARP Ammo Dump Coating"}
            veaf.loggers.get(ctld.Id):info("autoInitializeAllLogistic()")
            ctld.logisticUnits = {}
            local units = mist.DBs.unitsByName -- local copy for faster execution
            for name, unit in pairs(units) do
                veaf.loggers.get(ctld.Id):trace(string.format("name=%s, unit.type=%s", veaf.p(name), veaf.p(unit.type)))
                if unit then
                    for _, unitTypeName in pairs(LogisticTypeNames) do
                        if unitTypeName:lower() == unit.type:lower() then
                            table.insert(ctld.logisticUnits, unit.unitName)
                            veaf.loggers.get(ctld.Id):debug("Adding CTLD logistic unit %s of group %s", veaf.p(unit.unitName), veaf.p(unit.groupName))
                        end
                    end
                end
            end

            -- generate 20 logistic unit names in the form "logistic #001"
            veaf.loggers.get(ctld.Id):debug("generate 20 logistic unit names in the form 'logistic #001'")
            for i = 1, 20 do
                table.insert(ctld.logisticUnits, string.format("logistic #%03d",i))
            end

            veaf.loggers.get(ctld.Id):trace("ctld.logisticUnits=%s", veaf.p(ctld.logisticUnits))
        end

        ctld.autoInitializeAllPickupZones = function()
            local PickupShipNames = {"LHA_Tarawa", "Stennis", "CVN_71", "KUZNECOW"}
            veaf.loggers.get(ctld.Id):info("autoInitializeAllPickupZones()")
            ctld.pickupZones = {}
            -- add all ships to the pickup zones table
            local units = mist.makeUnitTable({"[all][ship]"}) -- get all ships in the mission
            veaf.loggers.get(ctld.Id):trace("units=%s", veaf.p(units))
            for _, unitName in pairs(units) do
                if unitName then
                    local unitObject = Unit.getByName(unitName)
                    local _unitCoalition = nil
                    if unitObject then
                        _unitCoalition = veaf.getCoalitionForCountry(veaf.getCountryName(unitObject:getCountry()), true)
                    end
                    local zone = {unitName, nil, -1, "yes", _unitCoalition, nil}
                    table.insert(ctld.pickupZones, zone)
                    veaf.loggers.get(ctld.Id):debug("Adding CTLD pickup zone for ship: [%s]", veaf.p(zone))
                end
            end

            -- generate 20 pickup zone names in the form "pickzone #001"
            veaf.loggers.get(ctld.Id):debug("generate 20 pickup zone names in the form 'pickzone #001'")
            for i = 1, 20 do
                table.insert(ctld.pickupZones, { string.format("pickzone #%03d",i), "none", -1, "yes", 0 })
            end

            veaf.loggers.get(ctld.Id):trace("ctld.pickupZones=%s", veaf.p(ctld.pickupZones))
        end

        -- automatically add all the carriers and FARPs to ctld.logisticUnits
        ctld.autoInitializeAllLogistic()

        -- automatically generate pickup zones names
        ctld.autoInitializeAllPickupZones()

        -- if a callback is defined, this is the right moment to call it
        if configurationCallback and type(configurationCallback) == "function" then
            -- a configuration callback has been set, call it
            veaf.loggers.get(ctld.Id):info("calling the configuration callback")
            configurationCallback()
            veaf.loggers.get(ctld.Id):info("done calling the configuration callback")
        end

        -- call the actual CTLD.initialize
        veaf.ctld_initialize(true)
        veaf.ctld_initialized = true
        veaf.loggers.get(ctld.Id):info(string.format("Done setting up CTLD"))
    else
        veaf.loggers.get(veaf.Id):error(string.format("CTLD is not loaded"))
    end
end

if ctld then
    veaf.loggers.get(veaf.Id):info(string.format("replacing CTLD.initialize()"))
    veaf.ctld_initialize = ctld.initialize -- used to call the vanilla ctld.initialize from the VEAF replacement
    ctld.initialize = veaf.ctld_initialize_replacement -- replace the ctld.initialize with the VEAF wrapper function
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- changes to CSAR 
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Our CSAR (VEAF version) does not autoinitialize. It's also set to log messages using the VEAF logging functions
-- Instead, we count on the mission makers to call csar.initialize from the missionConfig.lua file (since v5.0)
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