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
-- * -import if set, the script will import data from the .miz file (the exploded mission folder) instead of injecting data. Useful to update the settings file
-- * -dontclean, if set, the script will not delete all the groups starting with "veafSpawn-" from the mission
-- * -nameFilter, a regex that will be used to filter the groups that are processed (in either direction) by matching their names. Default to nil, all groups processed
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--require("src/scripts/veaf/veafMissionEditor")
require("veafMissionEditor")

veafSpawnableAircraftsEditor = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in the log will start with this.
veafSpawnableAircraftsEditor.Id = "SPAWN_AC - "

--- Version.
veafSpawnableAircraftsEditor.Version = "1.2.0"

-- trace level, specific to this module
veafSpawnableAircraftsEditor.Trace = false
--veafSpawnableAircraftsEditor.Trace = true
veafSpawnableAircraftsEditor.Debug = false

-- default position for all flights that are processed (imported from .miz to the configuration file) in meters, DCS model
local DEFAULT_POSITION_X = 0
local DEFAULT_POSITION_Y = 0

-- default callsign by id
local DEFAULT_CALLSIGNS_BY_ID = {
  [1] = "Enfield",
  [2] = "Springfield",
  [3] = "Uzi",
  [4] = "Colt",
  [5] = "Dodge",
  [6] = "Ford",
  [7] = "Chevy",
  [8] = "Pontiac"
}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local CATEGORIES = {"plane", "helicopter"}

local countriesById = {
  [0] = { iso = "RUS", name = "Russia", shortname = "Russia", id=0 },
  [1] = { iso = "UKR", name = "Ukraine", shortname = "Ukraine", id=1 },
  [2] = { iso = "USA", name = "USA", shortname = "USA", id=2 },
  [3] = { iso = "TUR", name = "Turkey", shortname = "Turkey", id=3 },
  [4] = { iso = "UK", name = "UK", shortname = "UK", id=4 },
  [5] = { iso = "FRA", name = "France", shortname = "France", id=5 },
  [6] = { iso = "GER", name = "Germany", shortname = "Germany", id=6 },
  [7] = { iso = "AUSAF", name = "USAF Aggressors", shortname = "USAF Aggressors", id=7 },
  [8] = { iso = "CAN", name = "Canada", shortname = "Canada", id=8 },
  [9] = { iso = "SPN", name = "Spain", shortname = "Spain", id=9 },
  [10] = { iso = "NETH", name = "The Netherlands", shortname = "The Netherlands", id=10 },
  [11] = { iso = "BEL", name = "Belgium", shortname = "Belgium", id=11 },
  [12] = { iso = "NOR", name = "Norway", shortname = "Norway", id=12 },
  [13] = { iso = "DEN", name = "Denmark", shortname = "Denmark", id=13 },
  [15] = { iso = "ISR", name = "Israel", shortname = "Israel", id=15 },
  [16] = { iso = "GRG", name = "Georgia", shortname = "Georgia", id=16 },
  [17] = { iso = "INS", name = "Insurgents", shortname = "Insurgents", id=17 },
  [18] = { iso = "ABH", name = "Abkhazia", shortname = "Abkhazia", id=18 },
  [19] = { iso = "RSO", name = "South Ossetia", shortname = "South Ossetia", id=19 },
  [20] = { iso = "ITA", name = "Italy", shortname = "Italy", id=20 },
  [21] = { iso = "AUS", name = "Australia", shortname = "Australia", id=21 },
  [22] = { iso = "SUI", name = "Switzerland", shortname = "Switzerland", id=22 },
  [23] = { iso = "AUT", name = "Austria", shortname = "Austria", id=23 },
  [24] = { iso = "BLR", name = "Belarus", shortname = "Belarus", id=24 },
  [25] = { iso = "BGR", name = "Bulgaria", shortname = "Bulgaria", id=25 },
  [26] = { iso = "CZE", name = "Czech Republic", shortname = "Czech Republic", id=26 },
  [27] = { iso = "CHN", name = "China", shortname = "China", id=27 },
  [28] = { iso = "HRV", name = "Croatia", shortname = "Croatia", id=28 },
  [29] = { iso = "EGY", name = "Egypt", shortname = "Egypt", id=29 },
  [30] = { iso = "FIN", name = "Finland", shortname = "Finland", id=30 },
  [31] = { iso = "GRC", name = "Greece", shortname = "Greece", id=31 },
  [32] = { iso = "HUN", name = "Hungary", shortname = "Hungary", id=32 },
  [33] = { iso = "IND", name = "India", shortname = "India", id=33 },
  [34] = { iso = "IRN", name = "Iran", shortname = "Iran", id=34 },
  [35] = { iso = "IRQ", name = "Iraq", shortname = "Iraq", id=35 },
  [36] = { iso = "JPN", name = "Japan", shortname = "Japan", id=36 },
  [37] = { iso = "KAZ", name = "Kazakhstan", shortname = "Kazakhstan", id=37 },
  [38] = { iso = "PRK", name = "North Korea", shortname = "North Korea", id=38 },
  [39] = { iso = "PAK", name = "Pakistan", shortname = "Pakistan", id=39 },
  [40] = { iso = "POL", name = "Poland", shortname = "Poland", id=40 },
  [41] = { iso = "ROU", name = "Romania", shortname = "Romania", id=41 },
  [42] = { iso = "SAU", name = "Saudi Arabia", shortname = "Saudi Arabia", id=42 },
  [43] = { iso = "SRB", name = "Serbia", shortname = "Serbia", id=43 },
  [44] = { iso = "SVK", name = "Slovakia", shortname = "Slovakia", id=44 },
  [45] = { iso = "KOR", name = "South Korea", shortname = "South Korea", id=45 },
  [46] = { iso = "SWE", name = "Sweden", shortname = "Sweden", id=46 },
  [47] = { iso = "SYR", name = "Syria", shortname = "Syria", id=47 },
  [48] = { iso = "YEM", name = "Yemen", shortname = "Yemen", id=48 },
  [49] = { iso = "VNM", name = "Vietnam", shortname = "Vietnam", id=49 },
  [50] = { iso = "VEN", name = "Venezuela", shortname = "Venezuela", id=50 },
  [51] = { iso = "TUN", name = "Tunisia", shortname = "Tunisia", id=51 },
  [52] = { iso = "THA", name = "Thailand", shortname = "Thailand", id=52 },
  [53] = { iso = "SDN", name = "Sudan", shortname = "Sudan", id=53 },
  [54] = { iso = "PHL", name = "Philippines", shortname = "Philippines", id=54 },
  [55] = { iso = "MAR", name = "Morocco", shortname = "Morocco", id=55 },
  [56] = { iso = "MEX", name = "Mexico", shortname = "Mexico", id=56 },
  [57] = { iso = "MYS", name = "Malaysia", shortname = "Malaysia", id=57 },
  [58] = { iso = "LBY", name = "Libya", shortname = "Libya", id=58 },
  [59] = { iso = "JOR", name = "Jordan", shortname = "Jordan", id=59 },
  [60] = { iso = "IDN", name = "Indonesia", shortname = "Indonesia", id=60 },
  [61] = { iso = "HND", name = "Honduras", shortname = "Honduras", id=61 },
  [62] = { iso = "ETH", name = "Ethiopia", shortname = "Ethiopia", id=62 },
  [63] = { iso = "CHL", name = "Chile", shortname = "Chile", id=63 },
  [64] = { iso = "BRA", name = "Brazil", shortname = "Brazil", id=64 },
  [65] = { iso = "BHR", name = "Bahrain", shortname = "Bahrain", id=65 },
  [66] = { iso = "NZG", name = "Third Reich", shortname = "Third Reich", id=66 },
  [67] = { iso = "YUG", name = "Yugoslavia", shortname = "Yugoslavia", id=67 },
  [68] = { iso = "SUN", name = "USSR", shortname = "USSR", id=68 },
  [69] = { iso = "RSI", name = "Italian Social Republic", shortname = "Italian Social Republic", id=69 },
  [70] = { iso = "DZA", name = "Algeria", shortname = "Algeria", id=70 },
  [71] = { iso = "KWT", name = "Kuwait", shortname = "Kuwait", id=71 },
  [72] = { iso = "QAT", name = "Qatar", shortname = "Qatar", id=72 },
  [73] = { iso = "OMN", name = "Oman", shortname = "Oman", id=73 },
  [74] = { iso = "ARE", name = "United Arab Emirates", shortname = "United Arab Emirates", id=74 },
  [75] = { iso = "RSA", name = "South Africa", shortname = "South Africa", id=75 },
  [76] = { iso = "CUB", name = "Cuba", shortname = "Cuba", id=76 },
  [77] = { iso = "PRT", name = "Portugal", shortname = "Portugal", id=77 },
  [78] = { iso = "GDR", name = "GDR", shortname = "GDR", id=78 },
  [79] = { iso = "LBN", name = "Lebanon", shortname = "Lebanon", id=79 },
  [80] = { iso = "BLUE", name = "Combined Joint Task Forces Blue", shortname = "CJTF Blue", id=80 },
  [81] = { iso = "RED", name = "Combined Joint Task Forces Red", shortname = "CJTF Red", id=81 },
  [82] = { iso = "UN", name = "United Nations Peacekeepers", shortname = "UN", id=82 },
  [83] = { iso = "ARG", name = "Argentina", shortname = "Argentina", id=83 },
  [84] = { iso = "CYP", name = "Cyprus", shortname = "Cyprus", id=84 },
  [85] = { iso = "SVN", name = "Slovenia", shortname = "Slovenia", id=85 },
  [86] = { iso = "BOL", name = "Bolivia", shortname = "Bolivia", id=86 },
  [87] = { iso = "GHA", name = "Ghana", shortname = "Ghana", id=87 },
  [88] = { iso = "NGA", name = "Nigeria", shortname = "Nigeria", id=88 },
  [89] = { iso = "PER", name = "Peru", shortname = "Peru", id=89 },
  [90] = { iso = "ECU", name = "Ecuador", shortname = "Ecuador, id=90" }
}
local countriesByName = {}
local countriesByShortname = {}
for id, country in pairs(countriesById) do
  countriesByName[country.name] = country
  countriesByName[country.name:lower()] = country
  countriesByShortname[country.shortname] = country
  countriesByShortname[country.shortname:lower()] = country
end

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
  if message and veafSpawnableAircraftsEditor.Debug or veafSpawnableAircraftsEditor.Trace then
    print(veafSpawnableAircraftsEditor.Id .. message)
  end
end

function veafSpawnableAircraftsEditor.logTrace(message)
  if message and veafSpawnableAircraftsEditor.Trace then
    print(veafSpawnableAircraftsEditor.Id .. message)
  end
end

local p = nil

local function _p(o, level)
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
          text = text .. "." .. key .. "=" .. p(value, level+1) .. "\n"
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

p = function(o, level)
  if o and type(o) == "table" and (o.x and o.z and o.y and #o == 3) then
      return string.format("{x=%s, z=%s, y=%s}", p(o.x), p(o.z), p(o.y))
  elseif o and type(o) == "table" and (o.x and o.y and #o == 2)  then
      return string.format("{x=%s, y=%s}", p(o.x), p(o.y))
  end
  return _p(o, level)
end

---checks if a string starts with a prefix
---@param aString any
---@param aPrefix any
---@param caseSensitive? boolean   ; if true, case sensitive search
---@return boolean
local function startsWith(aString, aPrefix, caseSensitive)
    local aString = aString
    if not aString then
        return false
    elseif not caseSensitive then
        aString = aString:upper()
    end
    local aPrefix = aPrefix
    if not aPrefix then
        return false
    elseif not caseSensitive then
        aPrefix = aPrefix:upper()
    end
    return string.sub(aString,1,string.len(aPrefix))==aPrefix
end

local function deepcopy(obj, seen)
    -- Handle non-tables and previously-seen tables.
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end

    -- New table; mark it as seen and copy recursively.
    local s = seen or {}
    local res = {}
    s[obj] = res
    for k, v in pairs(obj) do res[deepcopy(k, s)] = deepcopy(v, s) end
    return setmetatable(res, getmetatable(obj))
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Core methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

---Loads the .lua settings file containing all the spawnable aircrafts
---@param settingsPath string the complete path to the settings file
---@param nameFilter string? a regex that will filter out the group names that we want to load; defaults to nil -> all groups are loaded
---@return table veafSpawnableAircrafts a table containing all the loaded spawnable aircraft groups, by lowercased name
local function loadSpawnableAircraftSettings(settingsPath, nameFilter)
  veafSpawnableAircraftsEditor.logDebug(string.format("Loading settings from [%s]",settingsPath))
  local file, err = loadfile(settingsPath)
  if file then
      file()
  else
    veafSpawnableAircraftsEditor.logInfo(string.format("File does not exist: [%s]",settingsPath))
  end

  local veafSpawnableAircrafts = {}

  local function addGroupIfFilterMatches(categoryName, coalitionName, countryName, groupData)
    local groupName = groupData.name or ""
    if (nameFilter == nil) or groupName:match(nameFilter) then
      groupData.veafSpawnableAircraftsEditorData = {}
      groupData.veafSpawnableAircraftsEditorData.categoryName = categoryName
      groupData.veafSpawnableAircraftsEditorData.coalitionName = coalitionName
      groupData.veafSpawnableAircraftsEditorData.countryName = countryName
      veafSpawnableAircrafts[groupData.name:lower()] = groupData
    end
  end

  if settings then
    -- old syntax
    --[[
      settings = {
    ["FR planes"] = {
        ["category"] = "plane",
        ["coalition"] = "blue",
        ["country"] = "france",
        ["groups"] = {
            [1] = {
    ]]
    for _, settingData in pairs(settings) do
      local groups_t = settingData.groups
      if groups_t then
        for _, groupData in pairs(groups_t) do
          addGroupIfFilterMatches(settingData.category, settingData.coalition, settingData.country, groupData)
        end
      end
    end
    -- new syntax
    --[[
      settings = {
        ["categories"] = {
            ["plane"] = {
                ["coalitions"] = {
                    ["blue"] = {
                        ["countries"] = {
                            ["france"] = {
                                ["groups"] = {
                                    ["veafSpawn-m2000-fox1"] = {         
    ]]
    local categories_t = settings.categories
    if categories_t then
      for categoryName, categoryData in pairs(categories_t) do
        local coalitions_t = categoryData.coalitions
        if coalitions_t then
          for coalitionName, coalitionData in pairs(coalitions_t) do
            local countries_t = coalitionData.countries
            if countries_t then
              for countryName, countryData in pairs(countries_t) do
                local groups_t = countryData.groups
                if groups_t then
                  for _, groupData in pairs(groups_t) do
                    addGroupIfFilterMatches(categoryName, coalitionName, countryName, groupData)
                  end
                end
              end
            end
          end
        end
      end
    end
    veafSpawnableAircraftsEditor.logDebug("Settings loaded")
  end

  return veafSpawnableAircrafts
end

local function processGroup(group)
  local rGroup = nil
  if group ~= nil then
    rGroup = deepcopy(group)
    if rGroup.name and not startsWith(rGroup.name, "veafSpawn-", false) then
      rGroup.name = "veafSpawn-" .. rGroup.name
    end
    rGroup.hidden = true
    rGroup.lateActivation = true
    rGroup.x = DEFAULT_POSITION_X
    rGroup.y = DEFAULT_POSITION_Y
    local route = rGroup.route
    if route then
      local points = route.points
      if points then
        for index, point in pairs(points) do
          if index ~= 1 then
            points[index] = nil -- remove all navigation points after the first one
          else
            points[index].x = DEFAULT_POSITION_X
            points[index].y = DEFAULT_POSITION_Y
          end
        end
      end
    end
    local units = rGroup.units
    if units then
      local unitNumber = 0
      for _, unit in pairs(units) do
        unitNumber = unitNumber + 1
        unit.name = string.format("%s #%02d", group.name, unitNumber)
        unit.x = DEFAULT_POSITION_X
        unit.y = DEFAULT_POSITION_Y
      end
    end
  end
  return rGroup
end

---Reads a mission file and appends the resulting groups (after processing) into the spawnable aircrafts settings file
---@param missionPath string the mission file path (folder where the `mission` file resides)
---@param settingsPath string the spawnable aircrafts settings file path
---@param nameFilter string? a regex that will filter out the group names that we want to get from the mission; defaults to nil -> all groups are loaded
function veafSpawnableAircraftsEditor.retrieveFromMission(missionPath, settingsPath, nameFilter)

  -- load the mission file
  veafSpawnableAircraftsEditor.logDebug(string.format("Loading mission from [%s]",missionPath))
  local filePath = missionPath .. "\\mission"
  local file = assert(loadfile(filePath))
  if not file then
    veafMissionEditor.logError(string.format("Error while loading mission file [%s]",missionPath))
    return
  end
  file()
---@diagnostic disable-next-line: undefined-global -- "mission" is defined by the file() function
  local mission = mission
  veafSpawnableAircraftsEditor.logDebug("Mission loaded")

  local function processCategory(missionGroups, coalitionName, countryName, countryData, categoryName)
    local category_t = countryData[categoryName]
    if category_t then
      veafSpawnableAircraftsEditor.logDebug(string.format("  checking category [%s]", categoryName))
      local group_t = category_t.group
      for _, groupData in pairs(group_t) do
        local groupName = groupData.name
        veafSpawnableAircraftsEditor.logDebug(string.format("   groupName=%s",p(groupName)))
        if groupName then
          if not(nameFilter) or groupName:match(nameFilter) then
            veafSpawnableAircraftsEditor.logDebug("   Group name checked")
            local missionGroup = groupData
            missionGroup.veafSpawnableAircraftsEditorData = {}
            missionGroup.veafSpawnableAircraftsEditorData.coalitionName = coalitionName
            missionGroup.veafSpawnableAircraftsEditorData.countryName = countryName
            missionGroup.veafSpawnableAircraftsEditorData.categoryName = categoryName
            table.insert(missionGroups, missionGroup)
          end
        end
      end
    end
  end

  -- parse the mission and get the aircrafts groups
  local missionGroups = {}
  if mission then
    local coalition_t = mission.coalition
    if coalition_t then
      for coalitionName, coalitionData in pairs(coalition_t) do
        veafSpawnableAircraftsEditor.logDebug(string.format("  coalitionName=%s",p(coalitionName)))
        local country_t = coalitionData.country
        if country_t then
          for _, countryData in pairs(country_t) do
            local countryName = countryData.name
            if countryName then
              veafSpawnableAircraftsEditor.logDebug(string.format("  countryName=%s",p(countryName)))
              -- process categories
              for _, categoryName in pairs(CATEGORIES) do
                processCategory(missionGroups, coalitionName, countryName, countryData, categoryName)
              end
            end
          end
        end
      end
    end
  end

  -- load the spawnable aircrafts settings file
  local veafSpawnableAircrafts = loadSpawnableAircraftSettings(settingsPath) -- load all groups, do not apply nameFilter!

  -- inject the mission groups into the spawnable aircrafts groups
  if missionGroups then
    for _, groupData in pairs(missionGroups) do
      local groupName = groupData.name
      if veafSpawnableAircrafts[groupName:lower()] then
        veafSpawnableAircraftsEditor.logInfo(string.format("REPLACING group [%s]", groupName))
      else
        veafSpawnableAircraftsEditor.logInfo(string.format("ADDING group [%s]", groupName))
      end
      veafSpawnableAircrafts[groupName:lower()] = groupData -- replace or insert
    end
  end

  -- save the spawnable aircrafts settings file
  local rSettings = { categories = {}}
  local rCategories = rSettings.categories
  for _, groupData in pairs(veafSpawnableAircrafts) do
    local rGroupData = processGroup(groupData)
    local categoryName = rGroupData.veafSpawnableAircraftsEditorData.categoryName:lower()
    if not rCategories[categoryName] then
      rCategories[categoryName] = { coalitions = {}}
    end
    local rCoalitions = rCategories[categoryName].coalitions
    local coalitionName = rGroupData.veafSpawnableAircraftsEditorData.coalitionName:lower()
    if not rCoalitions[coalitionName] then
      rCoalitions[coalitionName] = { countries = {}}
    end
    local rCountries = rCoalitions[coalitionName].countries
    local countryName = rGroupData.veafSpawnableAircraftsEditorData.countryName
    if not rCountries[countryName] then
      rCountries[countryName] = { groups = {}}
    end
    local rGroups = rCountries[countryName].groups
    rGroupData.veafSpawnableAircraftsEditorData = nil
    local groupName = rGroupData.name
    rGroups[groupName] = rGroupData
  end
  local tableAsLua = veafMissionEditor.serialize("settings", rSettings, nil, false)
  veafMissionEditor.writeMissionFile(settingsPath, tableAsLua)
end

function veafSpawnableAircraftsEditor.injectInMission(filePath, settingsPath, nameFilter)
  -- load the spawnable aircrafts settings file
  local veafSpawnableAircrafts = loadSpawnableAircraftSettings(settingsPath, nameFilter) -- only load groups that match the nameFilter parameter, if any

  -- map the spawnable aircrafts groups by country and category
  local veafSpawnableAircraftsByCountryAndCategory = {}
  for groupName, groupData in pairs(veafSpawnableAircrafts) do
    local countryName = groupData.veafSpawnableAircraftsEditorData.countryName
    if countryName then
      if veafSpawnableAircraftsByCountryAndCategory[countryName] == nil then
        veafSpawnableAircraftsByCountryAndCategory[countryName] = {}
      end
      local countryCategoriesTable = veafSpawnableAircraftsByCountryAndCategory[countryName]
      local categoryName = groupData.veafSpawnableAircraftsEditorData.categoryName
      if countryCategoriesTable[categoryName] == nil then
        countryCategoriesTable[categoryName] = {}
      end
      countryCategoriesTable[categoryName][groupName] = groupData
    end
  end

  local availableCallsigns = {}
  for digit1 = 1, 8, 1 do
    for digit2 = 1, 9, 1 do
      for digit3 = 1, 9, 1 do
        local callsignId = digit1*100+digit2*10+digit3
        availableCallsigns[callsignId] = true
      end
    end
  end

  local availableGroupIds = {}
  for i = 1, 30000, 1 do
    availableGroupIds[i] = true
  end

  local availableUnitIds = {}
  for i = 1, 50000, 1 do
    availableUnitIds[i] = true
  end

  local function getNextAvailableId(idLibrary, maxId)
    for i = 1, maxId, 1 do
      if idLibrary[i] then
        idLibrary[i] = false
        return i
      end
    end
  end

  local function getNextAvailableCallsign()
    return getNextAvailableId(availableCallsigns, 999)
  end

  local function getNextAvailableGroupId()
    return getNextAvailableId(availableGroupIds, 30000)
  end

  local function getNextAvailableUnitId()
    return getNextAvailableId(availableUnitIds, 50000)
  end

  local function findAvailableIds(o)
    if (type(o) == "table") then
      for key,value in pairs(o) do
        --veafSpawnableAircraftsEditor.logTrace(string.format("parseTable %s", p(key)))
        if tostring(key):lower() == "groupid" then
          local groupId = tonumber(value)
          if groupId then
            availableGroupIds[groupId] = false
            veafSpawnableAircraftsEditor.logTrace(string.format("groupId [%s] is not available", p(groupId)))
          end
        elseif tostring(key):lower() == "unitid" then
          local unitId = tonumber(value)
          if unitId then
            availableUnitIds[unitId] = false
            veafSpawnableAircraftsEditor.logTrace(string.format("unitId [%s] is not available", p(unitId)))
          end
        elseif tostring(key):lower() == "callsign" then
          if type(value) == "table" then
            local digit1 = value[1] or 0
            local digit2 = value[2] or 0
            local digit3 = value[3] or 0
            local callsignId = digit1*100+digit2*10+digit3
            availableCallsigns[callsignId] = false
            veafSpawnableAircraftsEditor.logTrace(string.format("callsignId [%s] is not available", p(callsignId)))
          end
        end
        findAvailableIds(value)
      end
    end
  end

  ---This function is called by the mission editor to process the lua mission table before it's written back to disk
  ---@param missionTable table a LUA mission table as read from the `mission` file
  ---@return table missionTable the same LUA mission table, processed and ready to be written back to the `mission` file
  local function processMissionTable(missionTable)

    -- find all available ids (groups, units, callsigns)
    findAvailableIds(missionTable) -- this will populate the local availableCallsigns, availableGroupIds, availableUnitIds variables

    -- find the country tables in the mission table
    local missionCountryTablesByName = {}
    local missionCoalitionTablesByName = {}
    -- browse coalitions
    for _, missionCoalition_t in pairs(missionTable["coalition"]) do
      local missionCoalitionName = missionCoalition_t["name"]
      veafSpawnableAircraftsEditor.logTrace(string.format("found coalition [%s]",missionCoalitionName))
      if missionCoalitionTablesByName[missionCoalitionName] == nil then
        missionCoalitionTablesByName[missionCoalitionName] = missionCoalition_t
      end
      -- browse countries
      for _, missionCountry_t in pairs(missionCoalition_t["country"]) do
        local missionCountryName = missionCountry_t["name"]
        if missionCountryName then
          veafSpawnableAircraftsEditor.logTrace(string.format("found country [%s]",missionCountryName))
          missionCountryTablesByName[missionCountryName:lower()] = missionCountry_t
        end
        -- remove all the existing veafSpawn aircrafts groups
        if not veafSpawnableAircraftsEditor.leaveExistingGroupsInPlace then
          for _, categoryName in pairs(CATEGORIES) do
            local missionCategory_t = missionCountry_t[categoryName]
            if missionCategory_t then
              local missionCategoryGroup_t = missionCategory_t.group
              if missionCategoryGroup_t then
                for index, missionGroup_t in pairs(missionCategoryGroup_t) do
                  local groupName = missionGroup_t.name
                  if groupName and startsWith(groupName, "veafSpawn-", false) then
                    veafSpawnableAircraftsEditor.logDebug(string.format("removing existing group from mission: [%s]",groupName))
                    missionCategoryGroup_t[index] = nil
                  end
                end
              end
            end
          end
        end
      end
    end

    -- process all the spawnable aircrafts groups by country
    for spawnCountryName, spawnCategoriesTable in pairs(veafSpawnableAircraftsByCountryAndCategory) do
      local missionCountry_t = missionCountryTablesByName[spawnCountryName:lower()]
      -- create the country in the mission if missing
      if not missionCountry_t then
        local spawnCoalitionName = nil
        for _, spawnCategoryTable in pairs(spawnCategoriesTable) do
          for _, spawnGroupTable in pairs(spawnCategoryTable) do
            spawnCoalitionName = spawnGroupTable.veafSpawnableAircraftsEditorData.coalitionName
            break
          end
        end
        local missionCoalition_t = missionCoalitionTablesByName[spawnCoalitionName]
        if missionCoalition_t then
          local countryData = countriesByName[spawnCountryName]
          if not countryData then
            countryData = countriesByShortname[spawnCountryName]
          end
          if countryData then
            veafSpawnableAircraftsEditor.logInfo(string.format("Missing country %s in the mission; adding it automatically", spawnCountryName))
            missionCountry_t = { id = countryData.id, name = countryData.shortname}
            table.insert(missionCoalition_t["country"], missionCountry_t)
          end
        end
      end
      if not missionCountry_t then
      else
        veafSpawnableAircraftsEditor.logTrace(string.format("Processing country [%s]", spawnCountryName))
        -- process categories
        for spawnCategoryName, spawnGroupsTable in pairs(spawnCategoriesTable) do
          local missionCategory_t = missionCountry_t[spawnCategoryName]
          -- create the category if it doesn't exist
          if not missionCategory_t then
            veafSpawnableAircraftsEditor.logInfo(string.format("Missing category %s for country %s in the mission; adding it automatically", spawnCategoryName, spawnCountryName))
            missionCountry_t[spawnCategoryName] = { group = {}}
          end
          for spawnGroupName, spawnGroupData in pairs(spawnGroupsTable) do
            -- find the group in the category groups table
            local missionGroups_t = missionCountry_t[spawnCategoryName].group
            local foundIndex = nil
            for index, group_t in pairs(missionGroups_t) do
              local missionGroupName = group_t.name
              if missionGroupName:upper() == spawnGroupName:upper() then
                foundIndex = index
                break
              end
            end
            local newGroupData = deepcopy(spawnGroupData)
            -- change the group and units ids
            newGroupData.groupId = getNextAvailableGroupId()
            for _, newUnitData in pairs(newGroupData.units) do
              newUnitData.unitId = getNextAvailableUnitId()
              local callsignData = newUnitData.callsign
              if callsignData and type(callsignData) == "table" then
                local oldCallsign = callsignData.name
                local availableCallsignId = getNextAvailableCallsign()
                local digit1 = math.floor(availableCallsignId / 100)
                local digit2 = math.floor((availableCallsignId - (digit1*100)) / 10)
                local digit3 = availableCallsignId - (digit1*100) - (digit2*10)
                callsignData.name = DEFAULT_CALLSIGNS_BY_ID[digit1] .. digit2 .. digit3
                callsignData[1] = digit1
                callsignData[2] = digit2
                callsignData[3] = digit3
                veafSpawnableAircraftsEditor.logTrace(string.format("unitName=[%s] unitId=[%s], callsign changed from [%s] to [%s]", newUnitData.name, newUnitData.unitId, oldCallsign, callsignData.name))
              end
            end
            -- reset work data
            newGroupData.veafSpawnableAircraftsEditorData = nil
            -- force late activation
            newGroupData.lateActivation = true
            -- force hidden on map
            newGroupData.hidden = true
            if foundIndex then
              -- found it, let's replace the group data
              veafSpawnableAircraftsEditor.logDebug(string.format("replacing existing group in mission: [%s]", spawnGroupName))
              missionGroups_t[foundIndex] = newGroupData
            else
              -- inject the group as new
              veafSpawnableAircraftsEditor.logDebug(string.format("adding new group in mission: [%s]", spawnGroupName))
              table.insert(missionGroups_t, newGroupData)
            end
          end
        end
      end
    end

    return missionTable
  end

  -- edit the "mission" file
  veafSpawnableAircraftsEditor.logDebug(string.format("Processing mission at [%s]",filePath))
  local _filePath = filePath .. "\\mission"
  veafMissionEditor.editMission(_filePath, _filePath, "mission", processMissionTable)
  veafSpawnableAircraftsEditor.logDebug("Mission edited")
end

veafSpawnableAircraftsEditor.logDebug(string.format("#arg=%d",#arg))
for i=0, #arg do
    veafSpawnableAircraftsEditor.logDebug(string.format("arg[%d]=%s",i,arg[i]))
end
if #arg < 2 then
    veafSpawnableAircraftsEditor.logError("USAGE : veafSpawnableAircraftsEditor.lua <mission folder path> <settings file> [-debug|-trace] [-import] [-namefilter <filter>]")
    return
end

veafSpawnableAircraftsEditor.debug = false
veafSpawnableAircraftsEditor.trace = false
local import = false
local nameFilter = nil
local filePath = arg[1]
local settingsPath = arg[2]
for i = 3, #arg, 1 do
  -- processing an argument
  if arg[i]:lower() == "-debug" then
    veafSpawnableAircraftsEditor.debug = true
  elseif arg[i]:lower() == "-trace" then
    veafSpawnableAircraftsEditor.trace = true
  elseif arg[i]:lower() == "-import" then
    import = true
  elseif arg[i]:lower() == "-namefilter" then
    nameFilter = arg[i+1]
  elseif arg[i]:lower() == "-dontclean" then
    veafSpawnableAircraftsEditor.leaveExistingGroupsInPlace = true
  end
end
if veafSpawnableAircraftsEditor.debug or veafSpawnableAircraftsEditor.trace then
  veafSpawnableAircraftsEditor.Debug = true
  veafMissionEditor.Debug = true
  if veafSpawnableAircraftsEditor.trace then
    veafSpawnableAircraftsEditor.Trace = true
    veafMissionEditor.Trace = true
  end
else
  veafSpawnableAircraftsEditor.Debug = false
  veafMissionEditor.Debug = false
  veafSpawnableAircraftsEditor.Trace = false
  veafMissionEditor.Trace = false
end

if import then
  veafSpawnableAircraftsEditor.logInfo("Importing data from the mission and/or reprocessing the settings file)")
  veafSpawnableAircraftsEditor.retrieveFromMission(filePath, settingsPath, nameFilter)
else
  veafSpawnableAircraftsEditor.logInfo("Injecting data into the mission")
  veafSpawnableAircraftsEditor.injectInMission(filePath, settingsPath, nameFilter)
end