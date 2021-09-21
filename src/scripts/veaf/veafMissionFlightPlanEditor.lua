-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF flight plan editor tool for DCS World
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
-- veafMissionFlightPlanEditor.lua <mission folder path> <settings file> [-debug|-trace]
-- 
-- Command line options:
-- * <mission folder path> the path to the exploded mission files (no trailing backslash)
-- * <settings file> the path to the settings file
-- * -debug if set, the script will output some information ; useful to find out which units were edited
-- * -trace if set, the script will output a lot of information : useful to understand what went wrong
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafMissionFlightPlanEditor = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in the log will start with this.
veafMissionFlightPlanEditor.Id = "FPL_EDITOR - "

--- Version.
veafMissionFlightPlanEditor.Version = "1.0.1"

-- trace level, specific to this module
veafMissionFlightPlanEditor.Trace = false
veafMissionFlightPlanEditor.Debug = false

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafMissionFlightPlanEditor.logError(message)
    print(veafMissionFlightPlanEditor.Id .. message)
end

function veafMissionFlightPlanEditor.logInfo(message)
    print(veafMissionFlightPlanEditor.Id .. message)
end

function veafMissionFlightPlanEditor.logDebug(message)
  if message and veafMissionFlightPlanEditor.Debug then 
    print(veafMissionFlightPlanEditor.Id .. message)
  end
end

function veafMissionFlightPlanEditor.logTrace(message)
  if message and veafMissionFlightPlanEditor.Trace then 
    print(veafMissionFlightPlanEditor.Id .. message)
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

local function reverse(t)
  local n = #t
  local i = 1
  while i < n do
    t[i],t[n] = t[n],t[i]
    i = i + 1
    n = n - 1
  end
end

function veafMissionFlightPlanEditor.editGroup(coa_name, country_name, category_name, group_t, unitType)
  --veafMissionFlightPlanEditor.logTrace(string.format("editGroup(%s)",p(group_t)))
  local hasBeenEdited = false
  local groupName = group_t["name"]
  local groupId = group_t["groupId"]
  veafMissionFlightPlanEditor.logDebug(string.format("Testing group unitType=%s, groupName=%s, groupId=%s in coa_name=%s, country_name=%s) ", p(unitType), p(groupName), p(groupId),p(coa_name), p(country_name)))

  if not unitType then 
    return 
  end
  veafMissionFlightPlanEditor.logTrace("Checking in settings")
  for setting, setting_t in pairs(settings) do
    local coalition = setting_t["coalition"]
    veafMissionFlightPlanEditor.logTrace(string.format("  coalition=%s",p(coalition)))
    if not(coalition) or coalition == coa_name then
      veafMissionFlightPlanEditor.logTrace("  Coalition checked")
      local country = setting_t["country"]
      veafMissionFlightPlanEditor.logTrace(string.format("  country=%s",p(country)))
      if not(country) or country == country_name then
        veafMissionFlightPlanEditor.logTrace("  Country checked")
        local category = setting_t["category"]
        veafMissionFlightPlanEditor.logTrace(string.format("  category=%s",p(category)))
        if not(category) or category == category_name then
          veafMissionFlightPlanEditor.logTrace("  Category checked")
          local _type = setting_t["type"]
          veafMissionFlightPlanEditor.logTrace(string.format("  type=%s",p(_type)))
          if not(_type) or _type == unitType then
            veafMissionFlightPlanEditor.logTrace("  Unit type checked")
            
            -- edit the group
            if group_t["route"] then
              veafMissionFlightPlanEditor.logTrace("    found [route]")
              local points = group_t["route"]["points"]
              if points then
                veafMissionFlightPlanEditor.logTrace("    found [points]")
                
                if setting_t.replaceAllButFirst then
                  veafMissionFlightPlanEditor.logTrace("    clearing [points]")
                  for i = 2, #points do
                    if points[i] then
                      points[i] = nil
                    end
                  end
                  group_t["route"]["points"] = points
                end
                
                veafMissionFlightPlanEditor.logTrace(string.format("    setting_t[\"waypoints\"]=%s",p(setting_t["waypoints"])))
                for i = 1, #setting_t["waypoints"] do
                  local newPoint = setting_t["waypoints"][i]
                  veafMissionFlightPlanEditor.logTrace(string.format("    newPoint=%s",p(newPoint)))
                  if type(newPoint) == "string" then
                    -- this is a shortcut to the WAYPOINTS table
                    newPoint = waypoints[newPoint:upper()]
                  end
                  local newPointName = newPoint["name"]:upper()
                  veafMissionFlightPlanEditor.logTrace(string.format("    newPointName=%s",p(newPointName)))
                  local newPointPosition = -1
                  -- check if the waypoint exists in the points collection
                  for pointIndex, point in pairs(points) do
                    local name = point["name"]
                    veafMissionFlightPlanEditor.logTrace(string.format("      pointIndex=%s",p(pointIndex)))
                    veafMissionFlightPlanEditor.logTrace(string.format("      point=%s",p(point)))
                    if name and name:upper() == newPointName then
                      -- replace this point
                      newPointPosition = pointIndex
                      break
                    end
                  end
                  if newPointPosition > -1 then
                    -- replace
                    veafMissionFlightPlanEditor.logTrace(string.format("    replacing point %s at position %s",p(newPointName), p(newPointPosition)))
                    points[newPointPosition] = _deepcopy(newPoint)
                  else
                    -- insert at the end
                    veafMissionFlightPlanEditor.logTrace(string.format("    inserting point %s at the end",p(newPointName)))
                    table.insert(points, _deepcopy(newPoint))
                  end
                end
              end

              veafMissionFlightPlanEditor.logDebug(string.format("-> Edited group unitType=%s, groupName=%s, groupId=%s in coa_name=%s, country_name=%s) ", p(unitType), p(groupName), p(groupId),p(coa_name), p(country_name)))
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

function veafMissionFlightPlanEditor.editFlightPlans(missionTable)

  local _editGroups = function(coa_name, country_name, category, container) 
    local groups_t = container["group"]
    for group, group_t in pairs(groups_t) do
      veafMissionFlightPlanEditor.logTrace(string.format("Browsing group [%s]",p(group_t["name"])))
      -- check if the group contains at least one human client
      local units_t = group_t["units"]
      local clientUnit = nil
      for unit, unit_t in pairs(units_t) do
        if unit_t["skill"] and unit_t["skill"] == "Client" then
          clientUnit = unit_t
          veafMissionFlightPlanEditor.logTrace("Client found")
          break
        end
      end
      if clientUnit then
        veafMissionFlightPlanEditor.editGroup(coa_name, country_name, category, group_t, clientUnit["type"])
      end
    end
  end

  local coalitions_t = missionTable["coalition"]
  -- browse coalitions
  for coa, coa_t in pairs(coalitions_t) do
    local coa_name = coa_t["name"]
    veafMissionFlightPlanEditor.logTrace(string.format("Browsing coalition [%s]",coa_name))
    local countries_t = coa_t["country"]
    -- browse countries
    for country, country_t in pairs(countries_t) do
      local country_name = country_t["name"]
      veafMissionFlightPlanEditor.logTrace(string.format("Browsing country [%s]",country_name))
      --veafMissionFlightPlanEditor.logTrace(string.format("country_t=%s",p(country_t)))
      -- process helicopters
      veafMissionFlightPlanEditor.logTrace("Processing helicopters")
      local helicopters_t = country_t["helicopter"]
      if helicopters_t then
        --veafMissionFlightPlanEditor.logTrace(string.format("helicopters_t=%s",p(helicopters_t)))
        _editGroups(coa_name, country_name, "helicopter", helicopters_t)
      end
      -- process airplanes
      veafMissionFlightPlanEditor.logTrace("Processing airplanes")
      local planes_t = country_t["plane"]
      if planes_t then
        --veafMissionFlightPlanEditor.logTrace(string.format("planes_t=%s",p(planes_t)))
        _editGroups(coa_name, country_name, "plane", planes_t)
      end
    end
  end

  return missionTable
end

function veafMissionFlightPlanEditor.processMission(filePath, settingsPath)
  -- load the radioSettings file
  veafMissionFlightPlanEditor.logDebug(string.format("Loading settings from [%s]",settingsPath))
  local file = assert(loadfile(settingsPath))
  if not file then
      veafMissionEditor.logError(string.format("Error while loading settings file [%s]",settingsPath))
      return
  end 
  file()
  veafMissionFlightPlanEditor.logDebug("Settings loaded")

  -- edit the "mission" file
  veafMissionFlightPlanEditor.logDebug(string.format("Processing mission at [%s]",filePath))
  local _filePath = filePath .. "\\mission"
  local _processFunction = veafMissionFlightPlanEditor.editFlightPlans
  veafMissionEditor.editMission(_filePath, _filePath, "mission", _processFunction)
  veafMissionFlightPlanEditor.logDebug("Mission edited")
end

veafMissionFlightPlanEditor.logDebug(string.format("#arg=%d",#arg))
for i=0, #arg do
    veafMissionFlightPlanEditor.logDebug(string.format("arg[%d]=%s",i,arg[i]))
end
if #arg < 2 then 
    veafMissionFlightPlanEditor.logError("USAGE : veafMissionFlightPlanEditor.lua <mission folder path> <settings file> [-debug|-trace]")
    return
end

local filePath = arg[1]
local settingsPath = arg[2]
local debug = arg[3] and arg[3]:upper() == "-DEBUG"
local trace = arg[3] and arg[3]:upper() == "-TRACE"
if debug or trace then
  veafMissionFlightPlanEditor.Debug = true
  veafMissionEditor.Debug = true
  if trace then 
    veafMissionFlightPlanEditor.Trace = true
    veafMissionEditor.Trace = true
  end
else
  veafMissionFlightPlanEditor.Debug = false
  veafMissionEditor.Debug = false
  veafMissionFlightPlanEditor.Trace = false
  veafMissionEditor.Trace = false
end

veafMissionFlightPlanEditor.processMission(filePath, settingsPath)