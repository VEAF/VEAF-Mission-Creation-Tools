-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF mission normalizer tool for DCS World
-- By Zip (2020)
--
-- Features:
-- ---------
-- This tool processes all files in a mission, apply filters to normalize them and writes them back.
-- Usually, DCSW Mission Editor shuffles the data in the mission files each time the mission is saved, making it all but impossible to compare with a previous version.
-- With this tool, it becomes easy to compare mission files after an edition in DCS World Mission Editor.
--
-- Prerequisite:
-- ------------
-- * The mission file archive must already be exploded ; the script only works on the mission files, not directly on the .miz archive
--
-- Basic Usage:
-- ------------
-- The following workflow should be used :
-- * explode the mission (unzip it)
-- * run the normalizer on the exploded mission
-- * version the exploded mission files (save it, back it up, commit it to a source control system, whatever fits your routine)
-- * compile the mission (zip the exploded files again)
-- * edit the compiled mission with DCSW Mission Editor
-- * explode the mission (unzip it)
-- * run the normalizer on the exploded mission
-- * now you can run a comparison between the exploded mission and its previous version
-- 
-- Call the script by running it in a lua environment ; it needs the veafMissionEditor library, so the script working directory must contain the veafMissionEditor.lua file
-- 
-- veafMissionNormalizer.lua <mission folder path> [-debug|-trace]
-- 
-- Command line options:
-- * <mission folder path> the path to the exploded mission files (no trailing backslash)
-- * -debug if set, the script will output some information ; useful to find out which units were edited
-- * -trace if set, the script will output a lot of information : useful to understand what went wrong
-- 
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafMissionNormalizer = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in the log will start with this.
veafMissionNormalizer.Id = "NORMALIZER - "

--- Version.
veafMissionNormalizer.Version = "1.0.0"

-- trace level, specific to this module
veafMissionNormalizer.Trace = false
veafMissionNormalizer.Debug = false
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafMissionNormalizer.logError(message)
    print(veafMissionNormalizer.Id .. message)
end

function veafMissionNormalizer.logInfo(message)
    print(veafMissionNormalizer.Id .. message)
end

function veafMissionNormalizer.logDebug(message)
  if message and veafMissionNormalizer.Debug then 
    print(veafMissionNormalizer.Id .. message)
  end
end

function veafMissionNormalizer.logTrace(message)
  if message and veafMissionNormalizer.Trace then 
    print(veafMissionNormalizer.Id .. message)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Core methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------
require("veafMissionEditor")

function veafMissionNormalizer.normalizeMission(filePath)
  -- normalize "mission" file
  local _filePath = filePath .. "\\mission"
  veafMissionEditor.editMission(_filePath, _filePath, "mission")

  -- normalize "warehouses" file
  _filePath = filePath .. "\\warehouses"
  veafMissionEditor.editMission(_filePath, _filePath, "warehouses")

  -- normalize "options" file
  _filePath = filePath .. "\\options"
  local _processFunction = function(table) 
    return {} -- delete all the content
  end
  veafMissionEditor.editMission(_filePath, _filePath, "options", nil, _processFunction)

  -- normalize "dictionary" file
  _filePath = filePath .. "\\l10n\\DEFAULT\\dictionary"
  veafMissionEditor.editMission(_filePath, _filePath, "dictionary")
  
  -- normalize "mapResource" file
  _filePath = filePath .. "\\l10n\\DEFAULT\\mapResource"
  veafMissionEditor.editMission(_filePath, _filePath, "mapResource")
  
end

veafMissionNormalizer.logDebug(string.format("#arg=%d",#arg))
for i=0, #arg do
    veafMissionNormalizer.logDebug(string.format("arg[%d]=%s",i,arg[i]))
end
if #arg < 1 then 
    veafMissionNormalizer.logError("USAGE : veafMissionNormalizer.lua <mission folder path>")
    return
end
local debug = arg[2] and arg[2]:upper() == "-DEBUG"
local trace = arg[2] and arg[2]:upper() == "-TRACE"
if debug or trace then
  veafMissionNormalizer.Debug = true
  veafMissionEditor.Debug = true
  if trace then 
    veafMissionNormalizer.Trace = true
    veafMissionEditor.Trace = true
  end
else
  veafMissionNormalizer.Debug = false
  veafMissionEditor.Debug = false
  veafMissionNormalizer.Trace = false
  veafMissionEditor.Trace = false
end

local filePath = arg[1]
veafMissionNormalizer.normalizeMission(filePath)