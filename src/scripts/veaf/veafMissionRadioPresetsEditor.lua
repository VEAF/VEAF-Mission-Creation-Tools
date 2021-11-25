-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF radio presets editor tool for DCS World
-- By Zip (2020)
--
-- Features:
-- ---------
-- * This tool processes a mission and sets predefined radio presets.
-- * The preset templates can be customized (see radioSettings-example.lua)
--
-- Prerequisite:
-- ------------
-- * The mission file archive must already be exploded ; the script only works on the mission files, not directly on the .miz archive
--
-- Basic Usage:
-- ------------
-- Call the script by running it in a lua environment ; it needs the veafMissionEditor library, so the script working directory must contain the veafMissionEditor.lua file
-- 
-- veafMissionRadioPresetsEditor.lua <mission folder path> <radio settings file> [-debug|-trace]
-- 
-- Command line options:
-- * <mission folder path> the path to the exploded mission files (no trailing backslash)
-- * <radio settings file> the path to the preset templates file (see radioSettings-example.lua)
-- * -debug if set, the script will output some information ; useful to find out which units were edited
-- * -trace if set, the script will output a lot of information : useful to understand what went wrong
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafMissionRadioPresetsEditor = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in the log will start with this.
veafMissionRadioPresetsEditor.Id = "RADIOPRESETS_EDITOR - "

--- Version.
veafMissionRadioPresetsEditor.Version = "1.2.1"

-- trace level, specific to this module
veafMissionRadioPresetsEditor.Trace = false
veafMissionRadioPresetsEditor.Debug = false

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafMissionRadioPresetsEditor.logError(message)
    print(veafMissionRadioPresetsEditor.Id .. message)
end

function veafMissionRadioPresetsEditor.logInfo(message)
    print(veafMissionRadioPresetsEditor.Id .. message)
end

function veafMissionRadioPresetsEditor.logDebug(message)
  if message and veafMissionRadioPresetsEditor.Debug then 
    print(veafMissionRadioPresetsEditor.Id .. message)
  end
end

function veafMissionRadioPresetsEditor.logTrace(message)
  if message and veafMissionRadioPresetsEditor.Trace then 
    print(veafMissionRadioPresetsEditor.Id .. message)
  end
end

function veafMissionRadioPresetsEditor.ifnn(o, field)
  return veafMissionRadioPresetsEditor.ifnns(o, {field})
end

function veafMissionRadioPresetsEditor.ifnns(o, fields)
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

function veafMissionRadioPresetsEditor.p(o, level)
  if o and type(o) == "table" and (o.x and o.z and o.y)  then
      return string.format("{x=%s, z=%s, y=%s}", veafMissionRadioPresetsEditor.p(o.x), veafMissionRadioPresetsEditor.p(o.z), veafMissionRadioPresetsEditor.p(o.y))
  elseif o and type(o) == "table" and (o.x and o.y)  then
      return string.format("{x=%s, y=%s}", veafMissionRadioPresetsEditor.p(o.x), veafMissionRadioPresetsEditor.p(o.y))
  end
  return veafMissionRadioPresetsEditor._p(o, level)
end

function veafMissionRadioPresetsEditor._p(o, level)
  local MAX_LEVEL = 20
  if level == nil then level = 0 end
  if level > MAX_LEVEL then 
    veafMissionRadioPresetsEditor.logError("max depth reached in veafMissionRadioPresetsEditor.p : "..tostring(MAX_LEVEL))
      return ""
  end
    local text = ""
    if (type(o) == "table") then
        text = "\n"
        for key,value in pairs(o) do
            for i=0, level do
                text = text .. " "
            end
            text = text .. ".".. key.."="..veafMissionRadioPresetsEditor.p(value, level+1) .. "\n";
        end
    elseif (type(o) == "function") then
        text = "[function]";
    elseif (type(o) == "boolean") then
        if o == true then 
            text = "[true]";
        else
            text = "[false]";
        end
    else
        if o == nil then
            text = "[nil]";    
        else
            text = tostring(o);
        end
    end
    return text
end


-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Core methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------
require("veafMissionEditor")

-- Save copied tables in `copies`, indexed by original table.
local function _deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[_deepcopy(orig_key, copies)] = _deepcopy(orig_value, copies)
            end
            setmetatable(copy, _deepcopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function veafMissionRadioPresetsEditor.editUnit(coa_name, country_name, unit_t)
  veafMissionRadioPresetsEditor.logTrace(string.format("editUnit(%s)",veafMissionRadioPresetsEditor.p(unit_t)))
  local hasBeenEdited = false
  local unitName = unit_t["name"]
  local unitId = unit_t["unitId"]
  local unitType = unit_t["type"]
  veafMissionRadioPresetsEditor.logDebug("\n\n")
  veafMissionRadioPresetsEditor.logDebug(string.format("Testing unit unitType=[%s], unitName=%s, unitId=%s in coa_name=%s, country_name=%s) ", veafMissionRadioPresetsEditor.p(unitType), veafMissionRadioPresetsEditor.p(unitName), veafMissionRadioPresetsEditor.p(unitId),veafMissionRadioPresetsEditor.p(coa_name), veafMissionRadioPresetsEditor.p(country_name)))

  if unit_t["skill"] and unit_t["skill"] == "Client" then -- only human players
    veafMissionRadioPresetsEditor.logTrace("Client found")
    if unitType then
      veafMissionRadioPresetsEditor.logTrace("Checking in radioSettings")
      for setting, setting_t in pairs(radioSettings) do
        veafMissionRadioPresetsEditor.logTrace("\n")
        veafMissionRadioPresetsEditor.logTrace(string.format("Testing setting %s", veafMissionRadioPresetsEditor.p(setting)))
        local coalition = setting_t["coalition"]
        veafMissionRadioPresetsEditor.logTrace(string.format("  coalition=%s / %s",veafMissionRadioPresetsEditor.p(coalition), veafMissionRadioPresetsEditor.p(coa_name)))
        if not(coalition) or coalition == coa_name then
          veafMissionRadioPresetsEditor.logTrace("  Coalition checked")
          local country = setting_t["country"]
          veafMissionRadioPresetsEditor.logTrace(string.format("  country=%s / %s",veafMissionRadioPresetsEditor.p(country),veafMissionRadioPresetsEditor.p(country_name)))
          if not(country) or country == country_name then
            veafMissionRadioPresetsEditor.logTrace("  Country checked")
            local type = setting_t["type"]
            veafMissionRadioPresetsEditor.logTrace(string.format("  type=[%s] / [%s]",veafMissionRadioPresetsEditor.p(type),veafMissionRadioPresetsEditor.p(unitType)))
            if not(type) or unitType:lower() == type:lower() or string.match(unitType:lower(), type:lower()) then
              veafMissionRadioPresetsEditor.logTrace("  Unit type checked")
              -- edit the unit
              veafMissionRadioPresetsEditor.logDebug(string.format("-> Edited unit unitType=%s, unitName=%s, unitId=%s in coa_name=%s, country_name=%s) ", veafMissionRadioPresetsEditor.p(unitType), veafMissionRadioPresetsEditor.p(unitName), veafMissionRadioPresetsEditor.p(unitId),veafMissionRadioPresetsEditor.p(coa_name), veafMissionRadioPresetsEditor.p(country_name)))
              --unit_t["Radio"] = nil
              unit_t["Radio"] = _deepcopy(setting_t["Radio"])
              hasBeenEdited = true
              break
            end
          end
        end
      end
    end
  end

  return hasBeenEdited
end

function veafMissionRadioPresetsEditor.editRadioPresets(missionTable)
  local _editGroups = function(coa_name, country_name, container) 
    local groups_t = container["group"]
    for group, group_t in pairs(groups_t) do
      veafMissionRadioPresetsEditor.logTrace(string.format("Browsing group [%s]",group))
      local units_t = group_t["units"]
      for unit, unit_t in pairs(units_t) do
        local hasBeenEdited = veafMissionRadioPresetsEditor.editUnit(coa_name, country_name, unit_t)
        if hasBeenEdited then
          -- set the "radioSet" value to false
          veafMissionRadioPresetsEditor.logTrace("seting the radioSet value to false")
          group_t["radioSet"] = false
        end
      end
    end
  end

  local coalitions_t = missionTable["coalition"]
  -- browse coalitions
  for coa, coa_t in pairs(coalitions_t) do
    local coa_name = coa_t["name"]
    veafMissionRadioPresetsEditor.logTrace(string.format("Browsing coalition [%s]",coa_name))
    local countries_t = coa_t["country"]
    -- browse countries
    for country, country_t in pairs(countries_t) do
      local country_name = country_t["name"]
      veafMissionRadioPresetsEditor.logTrace(string.format("Browsing country [%s]",country_name))
      veafMissionRadioPresetsEditor.logTrace(string.format("country_t=%s",veafMissionRadioPresetsEditor.p(country_t)))
      -- process helicopters
      veafMissionRadioPresetsEditor.logTrace("Processing helicopters")
      local helicopters_t = country_t["helicopter"]
      if helicopters_t then
        veafMissionRadioPresetsEditor.logTrace(string.format("helicopters_t=%s",veafMissionRadioPresetsEditor.p(helicopters_t)))
        _editGroups(coa_name, country_name, helicopters_t)
      end
      -- process airplanes
      veafMissionRadioPresetsEditor.logTrace("Processing airplanes")
      local planes_t = country_t["plane"]
      if planes_t then
        veafMissionRadioPresetsEditor.logTrace(string.format("planes_t=%s",veafMissionRadioPresetsEditor.p(planes_t)))
        _editGroups(coa_name, country_name, planes_t)
      end
    end
  end

  return missionTable
end

function veafMissionRadioPresetsEditor.processMission(filePath, radioSettingsPath)
  -- load the radioSettings file
  veafMissionRadioPresetsEditor.logDebug(string.format("Loading radio settings from [%s]",radioSettingsPath))
  local file = assert(loadfile(radioSettingsPath))
  if not file then
      veafMissionEditor.logError(string.format("Error while loading radio settings file [%s]",radioSettingsPath))
      return
  end 
  file()
  veafMissionRadioPresetsEditor.logDebug("Radio settings loaded")

  -- edit the "mission" file
  veafMissionRadioPresetsEditor.logDebug(string.format("Processing mission at [%s]",filePath))
  local _filePath = filePath .. "\\mission"
  local _processFunction = veafMissionRadioPresetsEditor.editRadioPresets
  veafMissionEditor.editMission(_filePath, _filePath, "mission", _processFunction)
  veafMissionRadioPresetsEditor.logDebug("Mission edited")
end

veafMissionRadioPresetsEditor.logDebug(string.format("#arg=%d",#arg))
for i=0, #arg do
    veafMissionRadioPresetsEditor.logDebug(string.format("arg[%d]=%s",i,arg[i]))
end
if #arg < 2 then 
    veafMissionRadioPresetsEditor.logError("USAGE : veafMissionRadioPresetsEditor.lua <mission folder path> <radio settings file> [-debug|-trace]")
    return
end

local filePath = arg[1]
local radioSettingsPath = arg[2]
local debug = arg[3] and arg[3]:upper() == "-DEBUG"
local trace = arg[3] and arg[3]:upper() == "-TRACE"
if debug or trace then
  veafMissionRadioPresetsEditor.Debug = true
  veafMissionEditor.Debug = true
  if trace then 
    veafMissionRadioPresetsEditor.Trace = true
    veafMissionEditor.Trace = true
  end
else
  veafMissionRadioPresetsEditor.Debug = false
  veafMissionEditor.Debug = false
  veafMissionRadioPresetsEditor.Trace = false
  veafMissionEditor.Trace = false
end

veafMissionRadioPresetsEditor.processMission(filePath, radioSettingsPath)