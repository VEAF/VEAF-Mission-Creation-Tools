------------------------------------------------------------------
-- VEAF mission database for DCS World
-- By Zip (2026)
--
-- Features:
-- ---------
-- * Allocate unit ids for the objects VEAF creates at runtime
--
-- This module is the home of what VEAF needs to know about the mission itself. It starts with the id
-- allocator (DROP-MIST ticket 04); the mission index, the spawned-name registry and the player roster
-- follow in ticket 05.
------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafMissionDb = {}

--- Identifier. All output in the log will start with this.
veafMissionDb.Id = "MISSIONDB"

-- trace level, specific to this module (uncomment for debugging)
--veafMissionDb.LogLevel = "trace"

--- Where VEAF's own unit ids start.
---
--- Ids have to avoid three things: the ones the Mission Editor already assigned (three or four digits
--- in practice), the 6900–30000 band DCS reserves, and — for as long as MiST is still injected
--- alongside us — the ids MiST hands out itself.
---
--- MiST's counter starts at the highest id in the mission and, once past 6900, jumps to 30000 and
--- climbs from there. Starting at 200000 means MiST would have to allocate 170 000 units in a single
--- session before it could reach us. This is a quantitative guarantee, not a structural one; it stops
--- mattering when the injection is dropped and MiST no longer allocates anything.
veafMissionDb.FIRST_UNIT_ID = 200000

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.loggers.new(veafMissionDb.Id, veafMissionDb.LogLevel)

--- The last unit id handed out.
veafMissionDb.lastUnitId = veafMissionDb.FIRST_UNIT_ID - 1

--- A unit id no object in this mission is using.
---
--- @return number
function veafMissionDb.getNextUnitId()
  veafMissionDb.lastUnitId = veafMissionDb.lastUnitId + 1
  return veafMissionDb.lastUnitId
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- The editor snapshot
--
-- Every group and unit placed in the Mission Editor, read once from `env.mission` and never refreshed.
-- This is what a *mission record* is: it exists for a unit that has not spawned yet and for one
-- already destroyed, which is exactly why `Unit.getByName` is not a replacement for it — that answers
-- a live object or nothing.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Unit records by unit name. Built by `veafMissionDb.buildSnapshot`.
veafMissionDb.unitsByName = {}

--- Group records by group name.
veafMissionDb.groupsByName = {}

--- Group records by group id.
veafMissionDb.groupsById = {}

--- Countries that have pre-placed units, by coalition name:
--- `{ blue = { usa = { countryId = 2, country = "usa" } } }`. Read by `veaf`'s country/coalition
--- tables, which want nothing more than the id and the name.
veafMissionDb.countriesByCoalition = {}

--- Mission-editor group categories that hold units, in `env.mission.coalition[side].country[i]`.
veafMissionDb.UNIT_CATEGORIES = { "plane", "helicopter", "vehicle", "ship", "static" }

--- Read one unit out of a mission-editor group.
---
--- The fields are the ones VEAF actually reads — `veafInterpreter` documents its own set as
--- *"x, y, alt, coalitionId, groupName"*, `veafGrass` and `veafMove` want `type`, `veafAirWaves` and
--- `veafQraCore` want `coalition` and `category`. Nothing else is carried: a field nobody reads is a
--- field that goes stale unnoticed.
---
--- `x` and `y` are the mission-table shape, `y` being the easting — see docs/agents/dcs-coordinates.md.
---
--- @param unitData table the unit as `env.mission` holds it
--- @param groupData table the group it belongs to
--- @param context table coalition, coalitionId, country, countryId, category
--- @return table the record
local function unitRecord(unitData, groupData, context)
  return {
    unitName = unitData.name,
    unitId = unitData.unitId,
    groupName = groupData.name,
    groupId = groupData.groupId,
    type = unitData.type,
    x = unitData.x,
    y = unitData.y,
    alt = unitData.alt,
    heading = unitData.heading,
    skill = unitData.skill,
    coalition = context.coalition,
    coalitionId = context.coalitionId,
    category = context.category,
    country = context.country,
    countryId = context.countryId,
  }
end

--- Walk `env.mission` and index every pre-placed group and unit.
---
--- Runs once. MiST refreshed its equivalent twenty times a second over every unit in the mission; the
--- tables that refresh fed are ones VEAF never read, and the ones it does read describe what the
--- Mission Editor holds, which does not change while the mission runs.
function veafMissionDb.buildSnapshot()
  veafMissionDb.unitsByName = {}
  veafMissionDb.groupsByName = {}
  veafMissionDb.groupsById = {}
  veafMissionDb.countriesByCoalition = {}

  if not env.mission or not env.mission.coalition then
    veaf.loggers.get(veafMissionDb.Id):warn("no env.mission.coalition to index")
    return
  end

  for coalitionName, coalitionData in pairs(env.mission.coalition) do
    if type(coalitionData) == "table" and coalitionData.country then
      local coalitionId = coalition.side[string.upper(coalitionName)]
      veafMissionDb.countriesByCoalition[coalitionName] = veafMissionDb.countriesByCoalition[coalitionName] or {}
      for _, countryData in pairs(coalitionData.country) do
        if countryData.name then
          veafMissionDb.countriesByCoalition[coalitionName][countryData.name] = { countryId = countryData.id, country = countryData.name }
        end
        for _, category in ipairs(veafMissionDb.UNIT_CATEGORIES) do
          local categoryData = countryData[category]
          if type(categoryData) == "table" and type(categoryData.group) == "table" then
            for _, groupData in pairs(categoryData.group) do
              if type(groupData) == "table" and groupData.name then
                local context = {
                  coalition = coalitionName,
                  coalitionId = coalitionId,
                  country = countryData.name,
                  countryId = countryData.id,
                  category = category,
                }
                local group = {
                  groupName = groupData.name,
                  groupId = groupData.groupId,
                  coalition = coalitionName,
                  coalitionId = coalitionId,
                  category = category,
                  country = countryData.name,
                  countryId = countryData.id,
                  units = {},
                }
                for _, unitData in pairs(groupData.units or {}) do
                  if unitData.name then
                    local record = unitRecord(unitData, groupData, context)
                    veafMissionDb.unitsByName[record.unitName] = record
                    table.insert(group.units, record)
                  end
                end
                veafMissionDb.groupsByName[group.groupName] = group
                if group.groupId then
                  veafMissionDb.groupsById[group.groupId] = group
                end
              end
            end
          end
        end
      end
    end
  end

  veaf.loggers.get(veafMissionDb.Id):info(
    string.format(
      "indexed %d pre-placed groups and %d units",
      veaf.length(veafMissionDb.groupsByName),
      veaf.length(veafMissionDb.unitsByName)
    )
  )
end

--- The mission record of a unit, or nil.
--- @param unitName string
--- @return table|nil
function veafMissionDb.getUnitRecord(unitName)
  return veafMissionDb.unitsByName[unitName]
end

--- The mission record of a group, or nil.
--- @param groupName string
--- @return table|nil
function veafMissionDb.getGroupRecord(groupName)
  return veafMissionDb.groupsByName[groupName]
end

--- The mission record of a group, by its editor id, or nil.
--- @param groupId number
--- @return table|nil
function veafMissionDb.getGroupRecordById(groupId)
  return veafMissionDb.groupsById[groupId]
end

--- Every pre-placed unit record, keyed by unit name.
--- @return table
function veafMissionDb.getAllUnitRecords()
  return veafMissionDb.unitsByName
end

--- Every pre-placed group record, keyed by group name.
--- @return table
function veafMissionDb.getAllGroupRecords()
  return veafMissionDb.groupsByName
end

--- Countries that have pre-placed units, by coalition name.
--- @return table
function veafMissionDb.getCountriesByCoalitionFromMission()
  return veafMissionDb.countriesByCoalition
end

--- A coalition's bullseye, as the mission-table vec2 the Mission Editor stores.
---
--- Straight out of `env.mission`; MiST copied the same two numbers into a table of its own at startup
--- and never touched them again.
---
--- @param coalitionName string "blue" or "red"
--- @return table|nil `{ x, y }`, or nil when the mission declares no bullseye for that side
function veafMissionDb.getBullseye(coalitionName)
  local coalitionData = env.mission and env.mission.coalition and env.mission.coalition[coalitionName]
  return coalitionData and coalitionData.bullseye
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- The player roster
--
-- Who is a human slot. Unlike the snapshot this one is refreshed, because DCS **dynamic slots** create
-- player units that were never in `env.mission` — a walk over skill `Client` / `Player` alone would
-- lose them, silently, in exactly the missions that use the feature.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Human unit records by unit name: the editor's slots plus any dynamic ones seen since.
veafMissionDb.humansByName = {}

--- Mission-editor skills that mark a slot as playable.
veafMissionDb.PLAYER_SKILLS = { Client = true, Player = true }

--- Group categories a player can occupy. Ground and naval slots exist, and every consumer of this
--- roster filters on `category` itself.
veafMissionDb.PLAYER_GROUP_CATEGORIES = {
  [Group.Category.AIRPLANE] = "plane",
  [Group.Category.HELICOPTER] = "helicopter",
  [Group.Category.GROUND] = "vehicle",
  [Group.Category.SHIP] = "ship",
}

--- Is this a real pilot's name?
---
--- Written out rather than `if unit:getPlayerName() then`: DCS is not documented on whether an AI unit
--- answers nil or an empty string, and **an empty string is truthy in Lua**. This form is right either
--- way. (`veafAirWaves` had the short form; DCS-SESSION-TODO item 22 is about measuring which it is.)
---
--- @param unit table a DCS unit
--- @return boolean
local function hasPlayerName(unit)
  local name = unit.getPlayerName and unit:getPlayerName()
  return name ~= nil and name ~= ""
end

--- Index the human slots the Mission Editor declares.
local function indexEditorSlots()
  for unitName, record in pairs(veafMissionDb.unitsByName) do
    if record.skill and veafMissionDb.PLAYER_SKILLS[record.skill] then
      veafMissionDb.humansByName[unitName] = record
    end
  end
end

--- Add the players DCS created outside the Mission Editor — dynamic slots.
---
--- This is the sweep `veafAirWaves` used to run by hand, under the comment *"Dynamic slot players via
--- DCS coalition API (not tracked by mist)"*. It belongs here, once, rather than in each consumer.
function veafMissionDb.refreshDynamicSlots()
  for _, coalitionId in pairs({ coalition.side.RED, coalition.side.BLUE }) do
    for categoryId, categoryName in pairs(veafMissionDb.PLAYER_GROUP_CATEGORIES) do
      local groups = coalition.getGroups(coalitionId, categoryId) or {}
      for _, group in pairs(groups) do
        for _, unit in pairs(group:getUnits() or {}) do
          local unitName = unit:getName()
          if unitName and not veafMissionDb.humansByName[unitName] and hasPlayerName(unit) then
            veafMissionDb.humansByName[unitName] = {
              unitName = unitName,
              groupName = group:getName(),
              groupId = group:getID(),
              coalition = coalitionId == coalition.side.RED and "red" or "blue",
              coalitionId = coalitionId,
              category = categoryName,
              dynamicSlot = true,
            }
            veaf.loggers.get(veafMissionDb.Id):debug("dynamic slot player in [%s]", veaf.p(unitName))
          end
        end
      end
    end
  end
end

--- Is this unit name a human slot?
---
--- The roster answers first. When it does not know the name, DCS is asked about that one unit rather
--- than sweeping every group: a dynamic-slot player is a human the moment he is in the seat, and the
--- callers of this are event handlers that run at exactly that moment — waiting for the next full
--- sweep would mean not recognising him until something else asked who was flying.
---
--- @param unitName string
--- @return boolean
function veafMissionDb.isHumanUnit(unitName)
  if veafMissionDb.humansByName[unitName] ~= nil then
    return true
  end
  local unit = unitName and Unit.getByName(unitName)
  return unit ~= nil and hasPlayerName(unit)
end

--- Every human unit record, keyed by unit name, dynamic slots included.
---
--- The dynamic sweep runs here rather than on a timer: the roster is read when something needs to know
--- who is flying, and that is the moment the answer has to be current.
---
--- @return table
function veafMissionDb.getAllHumanRecords()
  veafMissionDb.refreshDynamicSlots()
  return veafMissionDb.humansByName
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- The spawned-name registry
--
-- Not an index of what exists — a record of the names VEAF has taken, so a group can be spawned again
-- under a name it used before. `veafSpawnAircraft` used to reach into `mist.DBs` and delete two
-- entries by hand for exactly this.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Names currently taken by something VEAF spawned.
---
--- `takeSpawnedName` and `isNameTaken` have no caller yet: the thing that decides whether a spawn's
--- name is free is `dynAdd`, which is still MiST's until ticket 07 ports it. They are here because the
--- registry is one of this ticket's three bricks and ticket 07 is written against it.
veafMissionDb.spawnedNames = {}

--- Remember that we have taken a name.
--- @param name string
function veafMissionDb.takeSpawnedName(name)
  if name then
    veafMissionDb.spawnedNames[name] = true
  end
end

--- Give a name back, so the next spawn may use it again.
---
--- This replaces `veafSpawnAircraft`'s hand-deletion of `mist.DBs.unitsByName[x]` and
--- `groupsByName[x]`, which existed so a dead AFAC's callsign could be reused.
---
--- **It still performs that deletion**, and has to, until ticket 07: the code that refuses a name it
--- has seen before is `mist.dynAdd`, and it reads MiST's tables, not ours. Freeing the name here
--- without freeing it there would leave the AFAC unable to respawn under its own callsign — a
--- regression a pilot would notice, traded for a grep that is one line cleaner. The two lines go when
--- ticket 08 drops the injection, and this comment goes with them.
---
--- @param name string
--- @return boolean true when the name was released somewhere
function veafMissionDb.releaseSpawnedName(name)
  if not name then
    return false
  end
  local released = veafMissionDb.spawnedNames[name] == true
  veafMissionDb.spawnedNames[name] = nil

  if mist and mist.DBs then
    released = released or mist.DBs.unitsByName[name] ~= nil or mist.DBs.groupsByName[name] ~= nil
    mist.DBs.unitsByName[name] = nil
    mist.DBs.groupsByName[name] = nil
  end

  if released then
    veaf.loggers.get(veafMissionDb.Id):trace("released spawned name [%s]", veaf.p(name))
  end
  return released
end

--- Is a name already in use — by the Mission Editor, or by something we spawned?
--- @param name string
--- @return boolean
function veafMissionDb.isNameTaken(name)
  if not name then
    return false
  end
  return veafMissionDb.spawnedNames[name] == true or veafMissionDb.unitsByName[name] ~= nil or veafMissionDb.groupsByName[name] ~= nil
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Framework façades. Callers use `veaf.*` and never name the implementation.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.getNextUnitId = veafMissionDb.getNextUnitId
veaf.getUnitRecord = veafMissionDb.getUnitRecord
veaf.getGroupRecord = veafMissionDb.getGroupRecord
veaf.getGroupRecordById = veafMissionDb.getGroupRecordById
veaf.getAllUnitRecords = veafMissionDb.getAllUnitRecords
veaf.getAllGroupRecords = veafMissionDb.getAllGroupRecords
veaf.getAllHumanRecords = veafMissionDb.getAllHumanRecords
veaf.isHumanUnit = veafMissionDb.isHumanUnit
veaf.getBullseye = veafMissionDb.getBullseye
veaf.getCountriesByCoalitionFromMission = veafMissionDb.getCountriesByCoalitionFromMission
veaf.takeSpawnedName = veafMissionDb.takeSpawnedName
veaf.releaseSpawnedName = veafMissionDb.releaseSpawnedName
veaf.isNameTaken = veafMissionDb.isNameTaken

function veafMissionDb.initialize()
  veaf.loggers.get(veafMissionDb.Id):info("Initializing module")
  veafMissionDb.buildSnapshot()
  veafMissionDb.humansByName = {}
  indexEditorSlots()
end

-- Built at load time, not on the module init pass: other modules read the snapshot from their own
-- `initialize`, and several read it from the top level of their file. This is the same shape
-- `veafEventHandler` uses, and for the same reason.
veafMissionDb.initialize()

veaf.registerModule(veafMissionDb.Id, veafMissionDb.initialize, { enable = true }, 5)

veaf.loggers.get(veafMissionDb.Id):info(veaf.loggers.get(veafMissionDb.Id):getVersionInfo())
