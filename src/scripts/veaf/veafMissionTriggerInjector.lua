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
veafMissionTriggerInjector.Version = "1.0.0"

-- trace level, specific to this module
veafMissionTriggerInjector.Trace = false
veafMissionTriggerInjector.Debug = false

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafMissionTriggerInjector.logError(message)
    print(veafMissionTriggerInjector.Id .. message)
end

function veafMissionTriggerInjector.logInfo(message)
    print(veafMissionTriggerInjector.Id .. message)
end

function veafMissionTriggerInjector.logDebug(message)
  if message and veafMissionTriggerInjector.Debug then 
    print(veafMissionTriggerInjector.Id .. message)
  end
end

function veafMissionTriggerInjector.logTrace(message)
  if message and veafMissionTriggerInjector.Trace then 
    print(veafMissionTriggerInjector.Id .. message)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Data for injection -- do not change
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafMissionTriggerInjector.trig = {}

veafMissionTriggerInjector.trig.actions = {
    [1] = 'a_do_script("VEAF_DYNAMIC_PATH = [[d:\\dev\\_VEAF\\VEAF-Mission-Creation-Tools]]");a_do_script("VEAF_DYNAMIC_MISSIONPATH = [[D:\\dev\\_VEAF\\VEAF-Open-Training-Mission\\]]"));',
    [2] = 'a_do_script("env.info(\"DYNAMIC LOADING\")");a_do_script("assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/mist.lua\"))()");a_do_script("assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/DCS-SimpleTextToSpeech.lua\"))()");a_do_script("assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/CTLD.lua\"))()");a_do_script("assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/WeatherMark.lua\"))()");a_do_script("assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/skynet-iads-compiled.lua\"))()");a_do_script("assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/Hercules_Cargo.lua\"))()");a_do_script("assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/HoundElint.lua\"))()");a_do_script("assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/VeafDynamicLoader.lua\"))()");',
    [3] = 'a_do_script("env.info(\"STATIC LOADING\")");a_do_script_file(getValueResourceByKey("DictKey_ActionText_10202"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10203"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10204"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10205"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10206"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10207"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10208"));;a_do_script_file(getValueResourceByKey("DictKey_ActionText_10308"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10309"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10310"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10311"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10312"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10313"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10314"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10315"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10316"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10317"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10318"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10319"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10320"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10321"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10322"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10323"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10324"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10325"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10326"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10327"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10328"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10329"));a_do_script_file(getValueResourceByKey("DictKey_ActionText_10330"));',
    [4] = 'a_do_script("assert(loadfile(VEAF_DYNAMIC_MISSIONPATH .. \"/src/scripts/missionConfig.lua\"))()");',
    [5] = 'a_do_script_file(getValueResourceByKey("DictKey_ActionText_10401"));'
}

veafMissionTriggerInjector.trig.conditions = {
    [1] = 'return(c_predicate(getValueDictByKey("DictKey_ActionText_10501")) )',
    [2] = 'return(c_predicate(getValueDictByKey("DictKey_ActionText_10601")) )',
    [3] = 'return(c_predicate(getValueDictByKey("DictKey_ActionText_10701")) )',
    [4] = 'return(c_predicate(getValueDictByKey("DictKey_ActionText_10801")) )',
    [5] = 'return(c_predicate(getValueDictByKey("DictKey_ActionText_10901")) )'
}

veafMissionTriggerInjector.trigrules = {
    [1] = {
        ["actions"] = {
            [1] = {
                ["predicate"] = "a_do_script",
                ["text"] = "VEAF_DYNAMIC_PATH = [[d:\\dev\\_VEAF\\VEAF-Mission-Creation-Tools]]"
            },
            [2] = {
                ["predicate"] = "a_do_script",
                ["text"] = "VEAF_DYNAMIC_MISSIONPATH = [[D:\\dev\\_VEAF\\VEAF-Open-Training-Mission\\]]"
            }
        },
        ["colorItem"] = "0x00ffffff",
        ["comment"] = "choose - static or dynamic)",
        ["eventlist"] = "",
        ["predicate"] = "triggerStart",
        ["rules"] = {
            [1] = {
                ["flag"] = 1,
                ["KeyDict_text"] = "DictKey_ActionText_10501",
                ["predicate"] = "c_predicate",
                ["text"] = "DictKey_ActionText_10501"
            }
        }
    },
    [2] = {
        ["actions"] = {
            [1] = {
                ["predicate"] = "a_do_script",
                ["text"] = "env.info(\"DYNAMIC LOADING\")"
            },
            [2] = {
                ["predicate"] = "a_do_script",
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/mist.lua\"))()"
            },
            [3] = {
                ["predicate"] = "a_do_script",
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/DCS-SimpleTextToSpeech.lua\"))()"
            },
            [4] = {
                ["predicate"] = "a_do_script",
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/CTLD.lua\"))()"
            },
            [5] = {
                ["predicate"] = "a_do_script",
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/WeatherMark.lua\"))()"
            },
            [6] = {
                ["predicate"] = "a_do_script",
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/skynet-iads-compiled.lua\"))()"
            },
            [7] = {
                ["predicate"] = "a_do_script",
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/Hercules_Cargo.lua\"))()"
            },
            [8] = {
                ["predicate"] = "a_do_script",
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/community/HoundElint.lua\"))()"
            },
            [9] = {
                ["predicate"] = "a_do_script",
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_PATH .. \"/src/scripts/VeafDynamicLoader.lua\"))()"
            }
        },
        ["colorItem"] = "0x00ff80ff",
        ["comment"] = "mission start - dynamic",
        ["eventlist"] = "",
        ["predicate"] = "triggerStart",
        ["rules"] = {
            [1] = {
                ["KeyDict_text"] = "DictKey_ActionText_10601",
                ["predicate"] = "c_predicate",
                ["text"] = "DictKey_ActionText_10601"
            }
        }
    },
    [3] = {
        ["actions"] = {
            [1] = {
                ["predicate"] = "a_do_script",
                ["text"] = "env.info(\"STATIC LOADING\")"
            },
            [2] = {
                ["file"] = "DictKey_ActionText_10202",
                ["predicate"] = "a_do_script_file"
            },
            [3] = {
                ["file"] = "DictKey_ActionText_10203",
                ["predicate"] = "a_do_script_file"
            },
            [4] = {
                ["file"] = "DictKey_ActionText_10204",
                ["predicate"] = "a_do_script_file"
            },
            [5] = {
                ["file"] = "DictKey_ActionText_10205",
                ["predicate"] = "a_do_script_file"
            },
            [6] = {
                ["file"] = "DictKey_ActionText_10206",
                ["predicate"] = "a_do_script_file"
            },
            [7] = {
                ["file"] = "DictKey_ActionText_10207",
                ["predicate"] = "a_do_script_file"
            },
            [8] = {
                ["file"] = "DictKey_ActionText_10208",
                ["predicate"] = "a_do_script_file"
            },
            [9] = {
                ["file"] = "DictKey_ActionText_10308",
                ["predicate"] = "a_do_script_file"
            },
            [10] = {
                ["file"] = "DictKey_ActionText_10309",
                ["predicate"] = "a_do_script_file"
            },
            [11] = {
                ["file"] = "DictKey_ActionText_10310",
                ["predicate"] = "a_do_script_file"
            },
            [12] = {
                ["file"] = "DictKey_ActionText_10311",
                ["predicate"] = "a_do_script_file"
            },
            [13] = {
                ["file"] = "DictKey_ActionText_10312",
                ["predicate"] = "a_do_script_file"
            },
            [14] = {
                ["file"] = "DictKey_ActionText_10313",
                ["predicate"] = "a_do_script_file"
            },
            [15] = {
                ["file"] = "DictKey_ActionText_10314",
                ["predicate"] = "a_do_script_file"
            },
            [16] = {
                ["file"] = "DictKey_ActionText_10315",
                ["predicate"] = "a_do_script_file"
            },
            [17] = {
                ["file"] = "DictKey_ActionText_10316",
                ["predicate"] = "a_do_script_file"
            },
            [18] = {
                ["file"] = "DictKey_ActionText_10317",
                ["predicate"] = "a_do_script_file"
            },
            [19] = {
                ["file"] = "DictKey_ActionText_10318",
                ["predicate"] = "a_do_script_file"
            },
            [20] = {
                ["file"] = "DictKey_ActionText_10319",
                ["predicate"] = "a_do_script_file"
            },
            [21] = {
                ["file"] = "DictKey_ActionText_10320",
                ["predicate"] = "a_do_script_file"
            },
            [22] = {
                ["file"] = "DictKey_ActionText_10321",
                ["predicate"] = "a_do_script_file"
            },
            [23] = {
                ["file"] = "DictKey_ActionText_10322",
                ["predicate"] = "a_do_script_file"
            },
            [24] = {
                ["file"] = "DictKey_ActionText_10323",
                ["predicate"] = "a_do_script_file"
            },
            [25] = {
                ["file"] = "DictKey_ActionText_10324",
                ["predicate"] = "a_do_script_file"
            },
            [26] = {
                ["file"] = "DictKey_ActionText_10325",
                ["predicate"] = "a_do_script_file"
            },
            [27] = {
                ["file"] = "DictKey_ActionText_10326",
                ["predicate"] = "a_do_script_file"
            },
            [28] = {
                ["file"] = "DictKey_ActionText_10327",
                ["predicate"] = "a_do_script_file"
            },
            [29] = {
                ["file"] = "DictKey_ActionText_10328",
                ["predicate"] = "a_do_script_file"
            },
            [30] = {
                ["file"] = "DictKey_ActionText_10329",
                ["predicate"] = "a_do_script_file"
            },
            [31] = {
                ["file"] = "DictKey_ActionText_10330",
                ["predicate"] = "a_do_script_file"
            }
        },
        ["colorItem"] = "0x00ff80ff",
        ["comment"] = "mission start - static",
        ["eventlist"] = "",
        ["predicate"] = "triggerStart",
        ["rules"] = {
            [1] = {
                ["KeyDict_text"] = "DictKey_ActionText_10701",
                ["predicate"] = "c_predicate",
                ["text"] = "DictKey_ActionText_10701"
            }
        }
    },
    [4] = {
        ["actions"] = {
            [1] = {
                ["predicate"] = "a_do_script",
                ["text"] = "assert(loadfile(VEAF_DYNAMIC_MISSIONPATH .. \"/src/scripts/missionConfig.lua\"))()"
            }
        },
        ["colorItem"] = "0x8080ffff",
        ["comment"] = "mission config - dynamic)",
        ["eventlist"] = "",
        ["predicate"] = "triggerStart",
        ["rules"] = {
            [1] = {
                ["KeyDict_text"] = "DictKey_ActionText_10801",
                ["predicate"] = "c_predicate",
                ["text"] = "DictKey_ActionText_10801"
            }
        }
    },
    [5] = {
        ["actions"] = {
            [1] = {
                ["file"] = "DictKey_ActionText_10401",
                ["predicate"] = "a_do_script_file"
            }
        },
        ["colorItem"] = "0x8080ffff",
        ["comment"] = "mission config - static",
        ["eventlist"] = "",
        ["predicate"] = "triggerStart",
        ["rules"] = {
            [1] = {
                ["KeyDict_text"] = "DictKey_ActionText_10901",
                ["predicate"] = "c_predicate",
                ["text"] = "DictKey_ActionText_10901"
            }
        }
    }
}

veafMissionTriggerInjector.dictionary = {
    ["DictKey_ActionText_10501"] = "return false -- set to true for dynamic loading",
    ["DictKey_ActionText_10601"] = "return VEAF_DYNAMIC_PATH~=nil",
    ["DictKey_ActionText_10701"] = "return VEAF_DYNAMIC_PATH==nil",
    ["DictKey_ActionText_10801"] = "return VEAF_DYNAMIC_PATH~=nil",
    ["DictKey_ActionText_10901"] = "return VEAF_DYNAMIC_PATH==nil"
}

veafMissionTriggerInjector.mapresource = {
    ["DictKey_ActionText_10202"] = "mist.lua",
    ["DictKey_ActionText_10203"] = "DCS-SimpleTextToSpeech.lua",
    ["DictKey_ActionText_10204"] = "CTLD.lua",
    ["DictKey_ActionText_10205"] = "WeatherMark.lua",
    ["DictKey_ActionText_10206"] = "skynet-iads-compiled.lua",
    ["DictKey_ActionText_10207"] = "Hercules_Cargo.lua",
    ["DictKey_ActionText_10208"] = "HoundElint.lua",
    ["DictKey_ActionText_10308"] = "veaf.lua",
    ["DictKey_ActionText_10309"] = "veafRadio.lua",
    ["DictKey_ActionText_10310"] = "veafMarkers.lua",
    ["DictKey_ActionText_10311"] = "veafAssets.lua",
    ["DictKey_ActionText_10312"] = "veafSpawn.lua",
    ["DictKey_ActionText_10313"] = "veafCasMission.lua",
    ["DictKey_ActionText_10314"] = "veafCarrierOperations.lua",
    ["DictKey_ActionText_10315"] = "veafCarrierOperations2.lua",
    ["DictKey_ActionText_10316"] = "veafMove.lua",
    ["DictKey_ActionText_10317"] = "veafGrass.lua",
    ["DictKey_ActionText_10318"] = "dcsUnits.lua",
    ["DictKey_ActionText_10319"] = "veafUnits.lua",
    ["DictKey_ActionText_10320"] = "veafTransportMission.lua",
    ["DictKey_ActionText_10321"] = "veafNamedPoints.lua",
    ["DictKey_ActionText_10322"] = "veafShortcuts.lua",
    ["DictKey_ActionText_10323"] = "veafSecurity.lua",
    ["DictKey_ActionText_10324"] = "veafInterpreter.lua",
    ["DictKey_ActionText_10325"] = "veafCombatZone.lua",
    ["DictKey_ActionText_10326"] = "veafCombatMission.lua",
    ["DictKey_ActionText_10327"] = "veafRemote.lua",
    ["DictKey_ActionText_10328"] = "veafSkynetIadsHelper.lua",
    ["DictKey_ActionText_10329"] = "veafSanctuary.lua",
    ["DictKey_ActionText_10330"] = "veafHoundElintHelper.lua",
    ["DictKey_ActionText_10401"] = "missionConfig.lua"
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
  if not trig then return nil end

  -- insert the 5 needed actions (browse in reverse order because each item will be inserted at index #1)
  local actions = trig["actions"]
  if not actions then return nil end

  for i = #veafMissionTriggerInjector.trig.actions, 1, -1 do
    local action = veafMissionTriggerInjector.trig.actions[i]
    table.insert(actions, 1, action)
  end

  -- insert the 5 needed conditions (browse in reverse order because each item will be inserted at index #1)
  local conditions = trig["conditions"]
  if not conditions then return nil end

  for i = #veafMissionTriggerInjector.trig.conditions, 1, -1 do
    local condition = veafMissionTriggerInjector.trig.conditions[i]
    table.insert(conditions, 1, condition)
  end

  -- insert the 5 needed trigger rules (browse in reverse order because each item will be inserted at index #1)
  local trigrules = dataTable["trigrules"]
  if not trigrules then return nil end

  for i = #veafMissionTriggerInjector.trigrules, 1, -1 do
    local rule = veafMissionTriggerInjector.trigrules[i]
    table.insert(trigrules, 1, rule)
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
  veafMissionTriggerInjector.logDebug(string.format("#arg=%d",#arg))
  for i=0, #arg do
      veafMissionTriggerInjector.logDebug(string.format("arg[%d]=%s",i,arg[i]))
  end
  if #arg < 1 then 
      veafMissionTriggerInjector.logError("USAGE : veafMissionTriggerInjector.lua <mission folder path> [-debug|-trace]")
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
  veafMissionTriggerInjector.logDebug(string.format("Processing `mission` at [%s]",filePath))
  local _filePath = filePath .. [[\mission]]
  local _processFunction = veafMissionTriggerInjector.injectTriggersInMission
  veafMissionEditor.editMission(_filePath, _filePath, "mission", _processFunction)
  veafMissionTriggerInjector.logDebug("`mission` edited")

  -- inject the new dictionary keys in the `dictionary` file
  veafMissionTriggerInjector.logDebug(string.format("Processing `dictionary` at [%s]",filePath))
  local _filePath = filePath .. [[\l10n\DEFAULT\dictionary]]
  local _processFunction = veafMissionTriggerInjector.injectKeysInDictionary
  veafMissionEditor.editMission(_filePath, _filePath, "dictionary", _processFunction)
  veafMissionTriggerInjector.logDebug("`dictionary` edited")

  -- inject the new dictionary keys in the `mapResource` file
  veafMissionTriggerInjector.logDebug(string.format("Processing `mapResource` at [%s]",filePath))
  local _filePath = filePath .. [[\l10n\DEFAULT\mapResource]]
  local _processFunction = veafMissionTriggerInjector.injectKeysInMapResource
  veafMissionEditor.editMission(_filePath, _filePath, "mapResource", _processFunction)
  veafMissionTriggerInjector.logDebug("`mapResource` edited")
end

main(arg)