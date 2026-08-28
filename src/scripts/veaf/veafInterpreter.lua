------------------------------------------------------------------
-- VEAF interpreter for DCS World
-- By Zip (2019)
--
-- Features:
-- ---------
-- * interprets a command and a position, and executes one of the VEAF script commands as if it had been requested in a map marker
-- * Possibilities :
-- *    - at mission start, have pre-placed units trigger specific commands
-- *    - serve as a base for activating commands in Combat Zones (see veafCombatZone.lua)
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

--- veafInterpreter Table.
veafInterpreter = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafInterpreter.Id = "INTERPRETER"

-- trace level, specific to this module
--veafInterpreter.LogLevel = "trace"

veaf.loggers.new(veafInterpreter.Id, veafInterpreter.LogLevel)

--- Key phrase to look for in the unit name which triggers the interpreter.
veafInterpreter.Starter = '#veafInterpreter%["'
veafInterpreter.Trailer = '"%]'

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- delay before the mission editor unit names are interpreted
veafInterpreter.DelayForStartup = 1

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the text
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafInterpreter.interpret(text)
  veaf.loggers.get(veafInterpreter.Id):trace(string.format("veafInterpreter.interpret([%s])", text))
  local result = nil
  local p1, p2 = text:find(veafInterpreter.Starter)
  if p2 then
    -- starter has been found
    text = text:sub(p2 + 1)
    p1, p2 = text:find(veafInterpreter.Trailer)
    if p1 then
      -- trailer has been found
      result = text:sub(1, p1 - 1)
    end
  end
  return result
end

function veafInterpreter.execute(command, position, coalition, route, spawnedGroups)
  if command == nil or position == nil then
    return
  end
  veaf.loggers.get(veafInterpreter.Id):trace("veafInterpreter.execute([%s],[%s])", command, position)
  spawnedGroups = spawnedGroups or {}
  return veafCommands.execute(position, command, coalition, spawnedGroups, route)
end

--- Run the command a trigger object carries, from the mission's own record of it.
---
--- The fallback for a trigger the running world does not hand back — a **late-activated** unit above
--- all, which is what #123 asks for, and equally one destroyed in the mission's first second. Without
--- it, `executeCommandOnUnit` reached neither of its two branches and the command was dropped in
--- silence.
---
--- Whether DCS resolves a late-activated unit through `Unit.getByName` cannot be settled from a
--- workstation. This makes the answer irrelevant rather than guessing it: `_initialize` already walks
--- `mist.DBs.units` and holds every unit's record, so it passes it down.
---
--- **Coordinates.** A mission record's `y` is the **easting** while the position a command expects is a
--- runtime vec3 whose `y` is the altitude (`docs/agents/dcs-coordinates.md`). `veaf.placePointOnLand`
--- takes exactly the former shape and returns the latter — and it *writes into the table it is given*,
--- so it gets a copy: handing it the mission record would corrupt `mist.DBs`.
---
--- Nothing is destroyed here. There is no world object to destroy.
---
--- @param command string the command read out of the name
--- @param missionUnit table a `mist.DBs.units` record: x, y, alt, coalitionId, groupName
--- @return boolean true when the command ran
local function executeFromMissionRecord(command, missionUnit)
  if not missionUnit or not missionUnit.x or not missionUnit.y then
    return false
  end
  veaf.loggers
    .get(veafInterpreter.Id)
    :debug("the world does not have [%s]; running its command from the mission record", veaf.p(missionUnit.unitName))
  local position = veaf.placePointOnLand({ x = missionUnit.x, y = missionUnit.y })
  local route = nil
  if missionUnit.groupName then
    route = mist.getGroupRoute(missionUnit.groupName, "task")
  end
  veafInterpreter.execute(command, position, missionUnit.coalitionId, route, nil)
  return true
end

function veafInterpreter.executeCommandOnUnit(unitName, command, missionUnit)
  if command then
    -- found an interpretable command
    veaf.loggers.get(veafInterpreter.Id):debug(string.format("found an interpretable command : [%s]", command))
    local unit = Unit.getByName(unitName)
    if unit then
      local position = unit:getPosition().p
      veaf.loggers.get(veafInterpreter.Id):trace(string.format("found the unit at : [%s]", veaf.vecToString(position)))
      local groupName = unit:getGroup():getName()
      veaf.loggers.get(veafInterpreter.Id):debug(string.format("in [%s]", groupName))
      local route = mist.getGroupRoute(groupName, "task")
      veaf.loggers.get(veafInterpreter.Id):trace(string.format("route = [%s]", veaf.p(route)))
      if veafInterpreter.execute(command, position, unit:getCoalition(), route, nil) then
        unit:getGroup():destroy()
      end
    else
      -- it may be a static instead of a unit
      local static = StaticObject.getByName(unitName)
      if static then
        local position = static:getPosition().p
        veaf.loggers.get(veafInterpreter.Id):trace("found the static at : [%s]", veaf.vecToString(position))
        if veafInterpreter.execute(command, position, static:getCoalition(), nil, nil) then
          static:destroy()
        end
      else
        executeFromMissionRecord(command, missionUnit)
      end
    end
  end
end

function veafInterpreter.processObject(unitName, missionUnit)
  veaf.loggers.get(veafInterpreter.Id):trace(string.format("veafInterpreter.processObject([%s])", unitName))
  local command = veafInterpreter.interpret(unitName)
  veafInterpreter.executeCommandOnUnit(unitName, command, missionUnit)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafInterpreter.initialize()
  veaf.scheduleFunction(veafInterpreter._initialize, {}, timer.getTime() + veafInterpreter.DelayForStartup)
end

function veafInterpreter._initialize()
  -- the following code is liberally adapted from MiST (thanks Grimes !)
  local l_units = mist.DBs.units --local reference for faster execution
  for coa, coa_tbl in pairs(l_units) do
    for country, country_table in pairs(coa_tbl) do
      for unit_type, unit_type_tbl in pairs(country_table) do
        if type(unit_type_tbl) == "table" then
          for group_ind, group_tbl in pairs(unit_type_tbl) do
            if type(group_tbl) == "table" then
              for unit_ind, mist_unit in pairs(group_tbl.units) do
                local unitName = mist_unit.unitName
                veaf.loggers.get(veafInterpreter.Id):trace(string.format("initialize - checking unit [%s]", unitName))
                -- the mission record travels with the name, so a trigger the world does not hand back
                -- still has a position to run its command at
                veafInterpreter.processObject(unitName, mist_unit)
              end
            end
          end
        end
      end
    end
  end
end

veaf.loggers.get(veafInterpreter.Id):info(veaf.loggers.get(veafInterpreter.Id):getVersionInfo())

veaf.registerModule(veafInterpreter.Id, veafInterpreter.initialize, { enable = true }, 170)
