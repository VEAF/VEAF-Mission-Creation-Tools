-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF spawnable aircrafts editor tool for DCS World
-- By Zip (2021)
--
-- Features:
-- ---------
-- * This tool processes a mission and update flight plans.
-- * The flight plans templates can be customized
--
-- Prerequisite:
-- ------------
-- * The mission file archive must already be exploded ; the script only works on the mission files, not directly on the .miz archive
--
-- Basic Usage:
-- ------------
-- Call the script by running it in a lua environment ; it needs the veafMissionEditor library, so the script working directory must contain the veafMissionEditor.lua file
-- 
-- veafSpawnableAircraftsEditor.lua <mission folder path> <settings file> [-debug|-trace]
-- 
-- Command line options:
-- * <mission folder path> the path to the exploded mission files (no trailing backslash)
-- * <settings file> the path to the settings file
-- * -debug if set, the script will output some information ; useful to find out which units were edited
-- * -trace if set, the script will output a lot of information : useful to understand what went wrong
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSpawnableAircraftsEditor = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in the log will start with this.
veafSpawnableAircraftsEditor.Id = "SPAWN_AC_EDITOR - "

--- Version.
veafSpawnableAircraftsEditor.Version = "0.0.1"

-- trace level, specific to this module
veafSpawnableAircraftsEditor.Trace = false
veafSpawnableAircraftsEditor.Debug = false

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSpawnableAircraftsEditor.logError(message)
    print(veafSpawnableAircraftsEditor.Id .. message)
end

function veafSpawnableAircraftsEditor.logInfo(message)
    print(veafSpawnableAircraftsEditor.Id .. message)
end

function veafSpawnableAircraftsEditor.logDebug(message)
  if message and veafSpawnableAircraftsEditor.Debug then 
    print(veafSpawnableAircraftsEditor.Id .. message)
  end
end

function veafSpawnableAircraftsEditor.logTrace(message)
  if message and veafSpawnableAircraftsEditor.Trace then 
    print(veafSpawnableAircraftsEditor.Id .. message)
  end
end

function ifnn(o, field)
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

function ifnns(o, fields)
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

function p(o, level)
  if o and type(o) == "table" and (o.x and o.z and o.y and #o == 3) then
      return string.format("{x=%s, z=%s, y=%s}", p(o.x), p(o.z), p(o.y))
  elseif o and type(o) == "table" and (o.x and o.y and #o == 2)  then
      return string.format("{x=%s, y=%s}", p(o.x), p(o.y))
  end
  return _p(o, level)
end

function _p(o, level)
  local MAX_LEVEL = 20
  if level == nil then level = 0 end
  if level > MAX_LEVEL then 
      logError("max depth reached in p : "..tostring(MAX_LEVEL))
      return ""
  end
  local text = ""
  if (type(o) == "table") then
      text = "\n"
      for key,value in pairs(o) do
          for i=0, level do
              text = text .. " "
          end
          text = text .. ".".. key.."="..p(value, level+1) .. "\n"
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


-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Core methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------
require("veafMissionEditor")

-- Save copied tables in `copies`, indexed by original table.
function _deepcopy(orig, copies)
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

function veafSpawnableAircraftsEditor.editCategory(coa_name, country_name, category_name, category_t)
  local function parseTable(o, level)
    local MAX_LEVEL = 50
    if level == nil then level = 0 end
    if level > MAX_LEVEL then 
      logError("max depth reached in parseTable : "..tostring(MAX_LEVEL))
      return
    end
    if (type(o) == "table") then
      for key,value in pairs(o) do
        veafSpawnableAircraftsEditor.logTrace(string.format("parseTable %s", p(key)))
        if tostring(key):lower() == "groupid" then
          veafSpawnableAircraftsEditor.maxGroupId = veafSpawnableAircraftsEditor.maxGroupId + 1
          o[key] = veafSpawnableAircraftsEditor.maxGroupId
          veafSpawnableAircraftsEditor.logDebug(string.format("veafSpawnableAircraftsEditor.maxGroupId=[%s]", p(veafSpawnableAircraftsEditor.maxGroupId)))
        elseif tostring(key):lower() == "unitid" then
          veafSpawnableAircraftsEditor.maxUnitId = veafSpawnableAircraftsEditor.maxUnitId + 1
          o[key] = veafSpawnableAircraftsEditor.maxUnitId
          veafSpawnableAircraftsEditor.logDebug(string.format("veafSpawnableAircraftsEditor.maxUnitId=[%s]", p(veafSpawnableAircraftsEditor.maxUnitId)))
        end
        parseTable(value, level+1)
      end
    end
  end

  if not category_t then 
    return 
  end
  veafSpawnableAircraftsEditor.logDebug("Checking in settings")
  for setting, setting_t in pairs(settings) do
    local coalition = setting_t.coalition
    veafSpawnableAircraftsEditor.logDebug(string.format("  coalition=%s",p(coalition)))
    if not(coalition) or coalition:upper() == coa_name:upper() then
      veafSpawnableAircraftsEditor.logDebug("  Coalition checked")
      local country = setting_t.country
      veafSpawnableAircraftsEditor.logDebug(string.format("  country=%s",p(country)))
      if not(country) or country:upper() == country_name:upper() then
        veafSpawnableAircraftsEditor.logDebug("  Country checked")
        local category = setting_t.category
        veafSpawnableAircraftsEditor.logDebug(string.format("  category=%s",p(category)))
        if not(category) or category:upper() == category_name:upper() then
          veafSpawnableAircraftsEditor.logDebug("  Category checked")

          for _, settingsGroup in pairs(setting_t.groups) do
            if settingsGroup.name then
              local newGroup = _deepcopy(settingsGroup)
              parseTable(newGroup)
              local groupNameUpper = settingsGroup.name:upper()
              veafSpawnableAircraftsEditor.logDebug(string.format("  groupNameUpper=%s",p(groupNameUpper)))
              -- check if the aircraft group exists
              local existingIndex = nil
              for groupIndex, group in pairs(category_t.group) do
                if group.name and group.name:upper() == groupNameUpper then
                  -- found the group
                  existingIndex = groupIndex
                  break
                end
              end
              veafSpawnableAircraftsEditor.logDebug(string.format("  existingIndex=%s",p(existingIndex)))
              if existingIndex then
                -- replace an existing group
                category_t.group[existingIndex] = newGroup
              else
                -- append a new group
                table.insert(category_t.group, newGroup)
              end
            end
          end
        end
      end
    end
  end
end

function veafSpawnableAircraftsEditor.editGroups(missionTable)

  -- find max maxGroupId and unitId
  veafSpawnableAircraftsEditor.maxGroupId = 1
  veafSpawnableAircraftsEditor.maxUnitId = 1
  local function parseTable(o, level)
    local MAX_LEVEL = 50
    if level == nil then level = 0 end
    if level > MAX_LEVEL then 
      logError("max depth reached in parseTable : "..tostring(MAX_LEVEL))
      return
    end
    if (type(o) == "table") then
      for key,value in pairs(o) do
        veafSpawnableAircraftsEditor.logTrace(string.format("parseTable %s", p(key)))
        if tostring(key):lower() == "groupid" then
          local nVal = tonumber(value or "0")
          veafSpawnableAircraftsEditor.logTrace(string.format("groupid=[%s]", p(value)))
          if nVal > veafSpawnableAircraftsEditor.maxGroupId then
            veafSpawnableAircraftsEditor.maxGroupId = nVal
            veafSpawnableAircraftsEditor.logTrace(string.format("veafSpawnableAircraftsEditor.maxGroupId=[%s]", p(veafSpawnableAircraftsEditor.maxGroupId)))
          end
        elseif tostring(key):lower() == "unitid" then
          local nVal = tonumber(value or "0")
          veafSpawnableAircraftsEditor.logTrace(string.format("unitid=[%s]", p(value)))
          if nVal > veafSpawnableAircraftsEditor.maxUnitId then
            veafSpawnableAircraftsEditor.maxUnitId = nVal
            veafSpawnableAircraftsEditor.logTrace(string.format("veafSpawnableAircraftsEditor.maxUnitId=[%s]", p(veafSpawnableAircraftsEditor.maxUnitId)))
          end          
        end
        parseTable(value, level+1)
      end
    end
  end
  parseTable(missionTable)
  veafSpawnableAircraftsEditor.logDebug(string.format("veafSpawnableAircraftsEditor.maxGroupId=[%s]", p(veafSpawnableAircraftsEditor.maxGroupId)))
  veafSpawnableAircraftsEditor.logDebug(string.format("veafSpawnableAircraftsEditor.maxUnitId=[%s]", p(veafSpawnableAircraftsEditor.maxUnitId)))

  local coalitions_t = missionTable["coalition"]
  -- browse coalitions
  for coa, coa_t in pairs(coalitions_t) do
    local coa_name = coa_t["name"]
    veafSpawnableAircraftsEditor.logTrace(string.format("Browsing coalition [%s]",coa_name))
    local countries_t = coa_t["country"]
    -- browse countries
    for country, country_t in pairs(countries_t) do
      local country_name = country_t["name"]
      veafSpawnableAircraftsEditor.logTrace(string.format("Browsing country [%s]",country_name))
      -- process helicopters
      veafSpawnableAircraftsEditor.logTrace("Processing helicopters")
      local helicopters_t = country_t["helicopter"]
      if helicopters_t then
        veafSpawnableAircraftsEditor.editCategory(coa_name, country_name, "helicopter", helicopters_t)
      end
      -- process airplanes
      veafSpawnableAircraftsEditor.logTrace("Processing airplanes")
      local planes_t = country_t["plane"]
      if planes_t then
        veafSpawnableAircraftsEditor.editCategory(coa_name, country_name, "plane", planes_t)
      end
    end
  end

  return missionTable
end

function veafSpawnableAircraftsEditor.processMission(filePath, settingsPath)
  -- load the radioSettings file
  veafSpawnableAircraftsEditor.logDebug(string.format("Loading settings from [%s]",settingsPath))
  local file = assert(loadfile(settingsPath))
  if not file then
      veafMissionEditor.logError(string.format("Error while loading settings file [%s]",settingsPath))
      return
  end 
  file()
  veafSpawnableAircraftsEditor.logDebug("Settings loaded")

  -- edit the "mission" file
  veafSpawnableAircraftsEditor.logDebug(string.format("Processing mission at [%s]",filePath))
  local _filePath = filePath .. "\\mission"
  local _processFunction = veafSpawnableAircraftsEditor.editGroups
  veafMissionEditor.editMission(_filePath, _filePath, "mission", _processFunction)
  veafSpawnableAircraftsEditor.logDebug("Mission edited")
end

veafSpawnableAircraftsEditor.logDebug(string.format("#arg=%d",#arg))
for i=0, #arg do
    veafSpawnableAircraftsEditor.logDebug(string.format("arg[%d]=%s",i,arg[i]))
end
if #arg < 2 then 
    veafSpawnableAircraftsEditor.logError("USAGE : veafSpawnableAircraftsEditor.lua <mission folder path> <settings file> [-debug|-trace]")
    return
end

local filePath = arg[1]
local settingsPath = arg[2]
local debug = arg[3] and arg[3]:upper() == "-DEBUG"
local trace = arg[3] and arg[3]:upper() == "-TRACE"
if debug or trace then
  veafSpawnableAircraftsEditor.Debug = true
  veafMissionEditor.Debug = true
  if trace then 
    veafSpawnableAircraftsEditor.Trace = true
    veafMissionEditor.Trace = true
  end
else
  veafSpawnableAircraftsEditor.Debug = false
  veafMissionEditor.Debug = false
  veafSpawnableAircraftsEditor.Trace = false
  veafMissionEditor.Trace = false
end

veafSpawnableAircraftsEditor.processMission(filePath, settingsPath)