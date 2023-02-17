-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF mission triggers injection tool for DCS World
-- By Zip (2021)
--
-- Features:
-- ---------
-- * This tool processes a mission and injects the triggers necessary to load a VEAF scripted mission.
-- * The triggers and associated data come from the triggers table
--
-- Prerequisite:
-- ------------
-- * The mission file archive must already be exploded ; the script only works on the mission files, not directly on the .miz archive
--
-- Basic Usage:
-- ------------
-- First, create 5 "MISSION START" triggers with a "LUA PREDICATE" condition, and a "DO SCRIPT" action, first in the mission triggers list.
-- Then call the script by running it in a lua environment ; it needs the veafMissionEditor library, so the script working directory must contain the veafMissionEditor.lua file
-- 
-- veafMissionTriggerInjector.lua <mission folder path> [-debug|-trace]
-- 
-- Command line options:
-- * <mission folder path> the path to the exploded mission files (no trailing backslash)
-- * -debug if set, the script will output some information ; useful to find out which units were edited
-- * -trace if set, the script will output a lot of information : useful to understand what went wrong
-------------------------------------------------------------------------------------------------------------------------------------------------------------
require("veafMissionEditor")

veafMissionTriggerInjector = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in the log will start with this.
veafMissionTriggerInjector.Id = "MISSIONTRIGGERS_EDITOR - "

--- Version.
veafMissionTriggerInjector.Version = "1.1.0"

-- trace level, specific to this module
veafMissionTriggerInjector.Trace = false
veafMissionTriggerInjector.Debug = false

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function logError(message)
    print(veafMissionTriggerInjector.Id .. message)
end

function logInfo(message)
    print(veafMissionTriggerInjector.Id .. message)
end

function logDebug(message)
  if message and veafMissionTriggerInjector.Debug then 
    print(veafMissionTriggerInjector.Id .. message)
  end
end

function logTrace(message)
  if message and veafMissionTriggerInjector.Trace then 
    print(veafMissionTriggerInjector.Id .. message)
  end
end

function p(o, level)
    local MAX_LEVEL = 20
if level == nil then level = 0 end
if level > MAX_LEVEL then 
    veafServerHook.logError("max depth reached in p : "..tostring(MAX_LEVEL))
    return ""
end
local text = ""
if (type(o) == "table") then
    text = "\n"
    for key,value in pairs(o) do
        for i=0, level do
            text = text .. " "
        end
        text = text .. ".".. key.."="..p(value, level+1) .. "\n";
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
-- Data for injection -- do not change
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafMissionTriggerInjector.trig = {}

veafMissionTriggerInjector.trig.actions = {
    [1] = "a_do_script(\"VEAF_DYNAMIC_PATH = [[d:\\\\dev\\\\_VEAF\\\\VEAF-Mission-Creation-Tools]]\");",
    [2] = "a_do_script(\"VEAF_DYNAMIC_MISSIONPATH = [[d:\\\\dev\\\\_VEAF\\\\VEAF-Open-Training-Mission\\\\]]\");",
    [3] = "a_do_script(\"env.info(\\\"DYNAMIC SCRIPTS LOADING\\\")\");a_do_script(\"assert(loadfile(VEAF_DYNAMIC_PATH .. \\\"/src/scripts/community/mist.lua\\\"))()\");a_do_script(\"assert(loadfile(VEAF_DYNAMIC_PATH .. \\\"/src/scripts/community/DCS-SimpleTextToSpeech.lua\\\"))()\");a_do_script(\"assert(loadfile(VEAF_DYNAMIC_PATH .. \\\"/src/scripts/community/CTLD.lua\\\"))()\");a_do_script(\"assert(loadfile(VEAF_DYNAMIC_PATH .. \\\"/src/scripts/community/WeatherMark.lua\\\"))()\");a_do_script(\"assert(loadfile(VEAF_DYNAMIC_PATH .. \\\"/src/scripts/community/skynet-iads-compiled.lua\\\"))()\");a_do_script(\"assert(loadfile(VEAF_DYNAMIC_PATH .. \\\"/src/scripts/community/Hercules_Cargo.lua\\\"))()\");a_do_script(\"assert(loadfile(VEAF_DYNAMIC_PATH .. \\\"/src/scripts/community/HoundElint.lua\\\"))()\");a_do_script(\"assert(loadfile(VEAF_DYNAMIC_PATH .. \\\"/src/scripts/VeafDynamicLoader.lua\\\"))()\");",
    [4] = "a_do_script(\"env.info(\\\"STATIC SCRIPTS LOADING\\\")\");a_do_script_file(getValueResourceByKey(\"DictKey_ActionText_10202\"));a_do_script_file(getValueResourceByKey(\"DictKey_ActionText_10203\"));a_do_script_file(getValueResourceByKey(\"DictKey_ActionText_10204\"));a_do_script_file(getValueResourceByKey(\"DictKey_ActionText_10205\"));a_do_script_file(getValueResourceByKey(\"DictKey_ActionText_10206\"));a_do_script_file(getValueResourceByKey(\"DictKey_ActionText_10207\"));a_do_script_file(getValueResourceByKey(\"DictKey_ActionText_10208\"));a_do_script_file(getValueResourceByKey(\"DictKey_ActionText_10308\"));",
    [5] = "a_do_script(\"env.info(\\\"DYNAMIC CONFIG LOADING\\\")\");a_do_script(\"assert(loadfile(VEAF_DYNAMIC_MISSIONPATH .. \\\"/src/scripts/missionConfig.lua\\\"))()\");",
    [6] = "a_do_script(\"env.info(\\\"STATIC CONFIG LOADING\\\")\");a_do_script_file(getValueResourceByKey(\"DictKey_ActionText_10309\"));",
}

veafMissionTriggerInjector.trig.conditions = {
    [1] = "return(c_predicate(getValueDictByKey(\"DictKey_ActionText_10501\")) )",
    [2] = "return(c_predicate(getValueDictByKey(\"DictKey_ActionText_10502\")) )",
    [3] = "return(c_predicate(getValueDictByKey(\"DictKey_ActionText_10601\")) )",
    [4] = "return(c_predicate(getValueDictByKey(\"DictKey_ActionText_10701\")) )",
    [5] = "return(c_predicate(getValueDictByKey(\"DictKey_ActionText_10801\")) )",
    [6] = "return(c_predicate(getValueDictByKey(\"DictKey_ActionText_10901\")) )",
}

veafMissionTriggerInjector.trig.funcstartup = {
    [1] = "if mission.trig.conditions[1]() then mission.trig.actions[1]() end",
    [2] = "if mission.trig.conditions[2]() then mission.trig.actions[2]() end",
    [3] = "if mission.trig.conditions[3]() then mission.trig.actions[3]() end",
    [4] = "if mission.trig.conditions[4]() then mission.trig.actions[4]() end",
    [5] = "if mission.trig.conditions[5]() then mission.trig.actions[5]() end",
    [6] = "if mission.trig.conditions[6]() then mission.trig.actions[6]() end",
}

veafMissionTriggerInjector.trigrules = {
    [1] = 
    {
        ["rules"] = 
        {
            [1] = 
            {
                ["flag"] = 1,
                ["text"] = "DictKey_ActionText_10501",
                ["KeyDict_text"] = "DictKey_ActionText_10501",
                ["predicate"] = "c_predicate",
            }, -- end of [1]
        }, -- end of ["rules"]
        ["eventlist"] = "",
        ["comment"] = "choose scripts loading method (false = static, true = dynamic)",
        ["actions"] = 
        {
            [1] = 
            {
                ["text"] = "VEAF_DYNAMIC_PATH = [[d:\\dev\\_VEAF\\VEAF-Mission-Creation-Tools]]",
                ["predicate"] = "a_do_script",
            }, -- end of [1]
        }, -- end of ["actions"]
        ["predicate"] = "triggerStart",
        ["colorItem"] = "0x00ffffff",
    },
    [2] = 
    {
        ["rules"] = 
        {
            [1] = 
            {
                ["flag"] = 1,
                ["text"] = "DictKey_ActionText_10502",
                ["KeyDict_text"] = "DictKey_ActionText_10502",
                ["predicate"] = "c_predicate",
            }, -- end of [1]
        }, -- end of ["rules"]
        ["eventlist"] = "",
        ["comment"] = "choose config loading method (false = static, true = dynamic)",
        ["actions"] = 
        {
            [1] = 
            {
                ["text"] = "VEAF_DYNAMIC_MISSIONPATH = [[d:\\dev\\_VEAF\\VEAF-Open-Training-Mission-Marianas\\]]",
                ["predicate"] = "a_do_script",
            }, -- end of [1]
        }, -- end of ["actions"]
        ["predicate"] = "triggerStart",
        ["colorItem"] = "0x00ffffff",
    },
    [3] = {
        ["rules"] = 
        {
            [1] = 
            {
                ["text"] = "DictKey_ActionText_10601",
                ["KeyDict_text"] = "DictKey_ActionText_10601",
                ["predicate"] = "c_predicate",
            }, -- end of [1]
        }, -- end of ["rules"]
        ["eventlist"] = "",
        ["comment"] = "mission start - dynamic",
        ["actions"] = 
        {
            [1] = 
            {
                ["text"] = "env.info(\"DYNAMIC SCRIPTS LOADING\")",
                ["predicate"] = "a_do_script",
            }, -- end of [1]
            [2] = 
            {
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/mist.lua\"))()",
                ["predicate"] = "a_do_script",
            }, -- end of [2]
            [3] = 
            {
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/DCS-SimpleTextToSpeech.lua\"))()",
                ["predicate"] = "a_do_script",
            }, -- end of [3]
            [4] = 
            {
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/CTLD.lua\"))()",
                ["predicate"] = "a_do_script",
            }, -- end of [4]
            [5] = 
            {
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/WeatherMark.lua\"))()",
                ["predicate"] = "a_do_script",
            }, -- end of [5]
            [6] = 
            {
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/skynet-iads-compiled.lua\"))()",
                ["predicate"] = "a_do_script",
            }, -- end of [6]
            [7] = 
            {
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/Hercules_Cargo.lua\"))()",
                ["predicate"] = "a_do_script",
            }, -- end of [7]
            [8] = 
            {
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/HoundElint.lua\"))()",
                ["predicate"] = "a_do_script",
            }, -- end of [8]
            [9] = 
            {
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/VeafDynamicLoader.lua\"))()",
                ["predicate"] = "a_do_script",
            }, -- end of [9]
        }, -- end of ["actions"]
        ["predicate"] = "triggerStart",
        ["colorItem"] = "0x00ff80ff",
    },
    [4] = {
        ["rules"] = 
        {
            [1] = 
            {
                ["text"] = "DictKey_ActionText_10701",
                ["KeyDict_text"] = "DictKey_ActionText_10701",
                ["predicate"] = "c_predicate",
            }, -- end of [1]
        }, -- end of ["rules"]
        ["eventlist"] = "",
        ["comment"] = "mission start - static",
        ["actions"] = 
        {
            [1] = 
            {
                ["text"] = "env.info(\"STATIC SCRIPTS LOADING\")",
                ["predicate"] = "a_do_script",
            }, -- end of [1]
            [2] = 
            {
                ["predicate"] = "a_do_script_file",
                ["file"] = "DictKey_ActionText_10202",
            }, -- end of [2]
            [3] = 
            {
                ["predicate"] = "a_do_script_file",
                ["file"] = "DictKey_ActionText_10203",
            }, -- end of [3]
            [4] = 
            {
                ["predicate"] = "a_do_script_file",
                ["file"] = "DictKey_ActionText_10204",
            }, -- end of [4]
            [5] = 
            {
                ["predicate"] = "a_do_script_file",
                ["file"] = "DictKey_ActionText_10205",
            }, -- end of [5]
            [6] = 
            {
                ["predicate"] = "a_do_script_file",
                ["file"] = "DictKey_ActionText_10206",
            }, -- end of [6]
            [7] = 
            {
                ["predicate"] = "a_do_script_file",
                ["file"] = "DictKey_ActionText_10207",
            }, -- end of [7]
            [8] = 
            {
                ["predicate"] = "a_do_script_file",
                ["file"] = "DictKey_ActionText_10208",
            }, -- end of [8]
            [9] = 
            {
                ["predicate"] = "a_do_script_file",
                ["file"] = "DictKey_ActionText_10308",
            }, -- end of [9]
        }, -- end of ["actions"]
        ["predicate"] = "triggerStart",
        ["colorItem"] = "0x00ff80ff",
    },
    [5] = {
        ["rules"] = 
        {
            [1] = 
            {
                ["text"] = "DictKey_ActionText_10801",
                ["KeyDict_text"] = "DictKey_ActionText_10801",
                ["predicate"] = "c_predicate",
            }, -- end of [1]
        }, -- end of ["rules"]
        ["eventlist"] = "",
        ["comment"] = "mission config - dynamic",
        ["actions"] = 
        {
            [1] = 
            {
                ["zone"] = 184,
                ["text"] = "env.info(\"DYNAMIC CONFIG LOADING\")",
                ["predicate"] = "a_do_script",
                ["meters"] = 1000,
            }, -- end of [1]
            [2] = 
            {
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_MISSIONPATH .. \"/src/scripts/missionConfig.lua\"))()",
                ["predicate"] = "a_do_script",
            }, -- end of [2]
        }, -- end of ["actions"]
        ["predicate"] = "triggerStart",
        ["colorItem"] = "0x8080ffff",
    },
    [6] = {
        ["rules"] = 
        {
            [1] = 
            {
                ["text"] = "DictKey_ActionText_10901",
                ["KeyDict_text"] = "DictKey_ActionText_10901",
                ["predicate"] = "c_predicate",
            }, -- end of [1]
        }, -- end of ["rules"]
        ["eventlist"] = "",
        ["comment"] = "mission config - static",
        ["actions"] = 
        {
            [1] = 
            {
                ["zone"] = 184,
                ["text"] = "env.info(\"STATIC CONFIG LOADING\")",
                ["predicate"] = "a_do_script",
                ["meters"] = 1000,
            }, -- end of [1]
            [2] = 
            {
                ["predicate"] = "a_do_script_file",
                ["file"] = "DictKey_ActionText_10309",
            }, -- end of [2]
        }, -- end of ["actions"]
        ["predicate"] = "triggerStart",
        ["colorItem"] = "0x8080ffff",
    }
}

veafMissionTriggerInjector.dictionary = {
    ["DictKey_ActionText_10501"] = "return false -- scripts",
    ["DictKey_ActionText_10502"] = "return false -- config",
    ["DictKey_ActionText_10701"] = "return VEAF_DYNAMIC_PATH==nil",
    ["DictKey_ActionText_10601"] = "return VEAF_DYNAMIC_PATH~=nil",
    ["DictKey_ActionText_10801"] = "return VEAF_DYNAMIC_MISSIONPATH~=nil",
    ["DictKey_ActionText_10901"] = "return VEAF_DYNAMIC_MISSIONPATH==nil",
}

veafMissionTriggerInjector.mapresource = {
    ["DictKey_ActionText_10202"] = "mist.lua",
    ["DictKey_ActionText_10203"] = "DCS-SimpleTextToSpeech.lua",
    ["DictKey_ActionText_10204"] = "CTLD.lua",
    ["DictKey_ActionText_10205"] = "WeatherMark.lua",
    ["DictKey_ActionText_10206"] = "skynet-iads-compiled.lua",
    ["DictKey_ActionText_10207"] = "Hercules_Cargo.lua",
    ["DictKey_ActionText_10208"] = "HoundElint.lua",
    ["DictKey_ActionText_10308"] = "veaf-scripts.lua",
    ["DictKey_ActionText_10309"] = "missionConfig.lua"
}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Core methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

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

function veafMissionTriggerInjector.injectTriggersInMission(dataTable)
  local trig = dataTable["trig"]
  if trig then
    logDebug("`trig` table found")

    -- insert the needed actions (browse in reverse order because each item will be inserted at index #1)
    local actions = trig["actions"]
    if actions then
        logDebug("`trig.actions` table found")
        for i = #veafMissionTriggerInjector.trig.actions, 1, -1 do
            local action = veafMissionTriggerInjector.trig.actions[i]
            logDebug(string.format("processing item %s", i))
            logTrace(string.format("item=%s", p(action)))
            table.insert(actions, 1, action)
        end
    end

    -- insert the needed conditions (browse in reverse order because each item will be inserted at index #1)
    local conditions = trig["conditions"]
    if conditions then
        logDebug("`trig.conditions` table found")
        for i = #veafMissionTriggerInjector.trig.conditions, 1, -1 do
            local condition = veafMissionTriggerInjector.trig.conditions[i]
            logDebug(string.format("processing item %s", i))
            logTrace(string.format("item=%s", p(condition)))
            table.insert(conditions, 1, condition)
        end
    end
    -- insert the needed startup functions (browse in reverse order because each item will be inserted at index #1)
    local funcstartup = trig["funcstartup"]
    if funcstartup then
        logDebug("`trig.funcstartup` table found")
        for i = #veafMissionTriggerInjector.trig.funcstartup, 1, -1 do
            local func = veafMissionTriggerInjector.trig.funcstartup[i]
            logDebug(string.format("processing item %s", i))
            logTrace(string.format("item=%s", p(func)))
            table.insert(funcstartup, 1, func)
        end
    end

  end

  -- insert the needed trigger rules (browse in reverse order because each item will be inserted at index #1)
  local trigrules = dataTable["trigrules"]
  if trigrules then
    logDebug("`trigrules` table found")
    for i = #veafMissionTriggerInjector.trigrules, 1, -1 do
        local rule = veafMissionTriggerInjector.trigrules[i]
        logDebug(string.format("processing item %s", i))
        logTrace(string.format("item=%s", p(rule)))
        table.insert(trigrules, 1, rule)
    end
  end

  return dataTable

end

function veafMissionTriggerInjector.injectKeysInDictionary(dataTable)
  local dictionary = dataTable
  if not dictionary then return nil end

  -- add the required keys
  for key, value in pairs(veafMissionTriggerInjector.dictionary) do
    dictionary[key] = value
  end

  return dataTable

end

function veafMissionTriggerInjector.injectKeysInMapResource(dataTable)
  local mapresource = dataTable
  if not mapresource then return nil end

  -- add the required keys
  for key, value in pairs(veafMissionTriggerInjector.mapresource) do
    mapresource[key] = value
  end

  return dataTable

end

local function main(arg)
  logDebug(string.format("#arg=%d",#arg))
  for i=0, #arg do
      logDebug(string.format("arg[%d]=%s",i,arg[i]))
  end
  if #arg < 1 then 
      logError("USAGE : veafMissionTriggerInjector.lua <mission folder path> [-debug|-trace]")
      return
  end

  local filePath = arg[1]
  local debug = arg[2] and arg[2]:upper() == "-DEBUG"
  local trace = arg[2] and arg[2]:upper() == "-TRACE"
  if debug or trace then
    veafMissionTriggerInjector.Debug = true
    veafMissionEditor.Debug = true
    if trace then 
      veafMissionTriggerInjector.Trace = true
      veafMissionEditor.Trace = true
    end
  else
    veafMissionTriggerInjector.Debug = false
    veafMissionEditor.Debug = false
    veafMissionTriggerInjector.Trace = false
    veafMissionEditor.Trace = false
  end

  -- inject the triggers in the `mission` file
  logDebug(string.format("Processing `mission` at [%s]",filePath))
  local _filePath = filePath .. [[\mission]]
  local _processFunction = veafMissionTriggerInjector.injectTriggersInMission
  veafMissionEditor.editMission(_filePath, _filePath, "mission", _processFunction)
  logDebug("`mission` edited")

  -- inject the new dictionary keys in the `dictionary` file
  logDebug(string.format("Processing `dictionary` at [%s]",filePath))
  local _filePath = filePath .. [[\l10n\DEFAULT\dictionary]]
  local _processFunction = veafMissionTriggerInjector.injectKeysInDictionary
  veafMissionEditor.editMission(_filePath, _filePath, "dictionary", _processFunction)
  logDebug("`dictionary` edited")

  -- inject the new dictionary keys in the `mapResource` file
  logDebug(string.format("Processing `mapResource` at [%s]",filePath))
  local _filePath = filePath .. [[\l10n\DEFAULT\mapResource]]
  local _processFunction = veafMissionTriggerInjector.injectKeysInMapResource
  veafMissionEditor.editMission(_filePath, _filePath, "mapResource", _processFunction)
  logDebug("`mapResource` edited")
end

main(arg)