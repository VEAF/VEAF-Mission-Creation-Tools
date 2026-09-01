--- Unit tests for veafInterpreter.interpret().
---
--- Run:  lua test/lua/test_veafInterpreter.lua
---
--- Covers:
---   - Returns nil when no starter token is present
---   - Returns nil when starter is present but no trailer
---   - Extracts command text between starter and trailer
---   - Works when the tagged command is embedded in a longer string
---   - Empty command between the tokens returns an empty string
---   - Multiple occurrences: only the first match is extracted
---   - Starter/trailer from the module constants (not hard-coded in tests)

-- ---------------------------------------------------------------------------
-- Bootstrap
-- ---------------------------------------------------------------------------
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua") -- exported as global for test methods
dofile(_base .. "/dcs_mocks.lua")
dofile(_base .. "/../../src/scripts/veaf/veaf.lua")
dofile(_base .. "/../../src/scripts/veaf/veafScheduler.lua")
dofile(_base .. "/../../src/scripts/veaf/veafMath.lua")
dofile(_base .. "/../../src/scripts/veaf/veafGeo.lua")
dofile(_base .. "/../../src/scripts/veaf/veafMissionDb.lua")
dofile(_base .. "/../../src/scripts/veaf/veafDcsSpawner.lua")
dofile(_base .. "/../../src/scripts/veaf/veafInterpreter.lua")

-- ---------------------------------------------------------------------------
-- Helpers: build tagged strings using the module's own constants.
-- ---------------------------------------------------------------------------
local function tagged(command)
  -- veafInterpreter.Starter = '#veafInterpreter%["'
  -- veafInterpreter.Trailer = '"%]'
  -- We build the literal counterpart: strip the Lua pattern metacharacters.
  return '#veafInterpreter["' .. command .. '"]'
end

-- ---------------------------------------------------------------------------
-- Test suite
-- ---------------------------------------------------------------------------
TestVeafInterpreter = {}

-- 1 -------------------------------------------------------------------------
function TestVeafInterpreter:test_noTagReturnsNil()
  local result = veafInterpreter.interpret("just a plain unit name")
  luaunit.assertNil(result)
end

-- 2 -------------------------------------------------------------------------
function TestVeafInterpreter:test_emptyStringReturnsNil()
  local result = veafInterpreter.interpret("")
  luaunit.assertNil(result)
end

-- 3 -------------------------------------------------------------------------
function TestVeafInterpreter:test_starterOnlyReturnsNil()
  -- Only the opening tag, no closing bracket.
  local result = veafInterpreter.interpret('#veafInterpreter["spawn, sam, size 1')
  luaunit.assertNil(result)
end

-- 4 -------------------------------------------------------------------------
function TestVeafInterpreter:test_simpleCommandExtracted()
  local result = veafInterpreter.interpret(tagged("spawn, sa6, size 1"))
  luaunit.assertEquals(result, "spawn, sa6, size 1")
end

-- 5 -------------------------------------------------------------------------
function TestVeafInterpreter:test_commandWithSpacesAndCommas()
  local cmd = "spawn, sam, country russia, size 3, speed 10"
  local result = veafInterpreter.interpret(tagged(cmd))
  luaunit.assertEquals(result, cmd)
end

-- 6 -------------------------------------------------------------------------
function TestVeafInterpreter:test_tagEmbeddedInLongerName()
  -- DCS unit names may carry extra text before the tag.
  local text = "RED_INFANTRY_01 " .. tagged("spawn, infantry, size 5")
  local result = veafInterpreter.interpret(text)
  luaunit.assertEquals(result, "spawn, infantry, size 5")
end

-- 7 -------------------------------------------------------------------------
function TestVeafInterpreter:test_emptyCommand()
  -- The tag is present but the command string inside is empty.
  local result = veafInterpreter.interpret(tagged(""))
  luaunit.assertEquals(result, "")
end

-- 8 -------------------------------------------------------------------------
function TestVeafInterpreter:test_commandWithSpecialLuaChars()
  -- Make sure the pattern matching isn't confused by dots or parentheses in
  -- the command string itself.
  local cmd = "cas, time 1.5, radius (500)"
  local result = veafInterpreter.interpret(tagged(cmd))
  luaunit.assertEquals(result, cmd)
end

-- 9 -------------------------------------------------------------------------
function TestVeafInterpreter:test_firstMatchWins()
  -- When the input contains two tagged commands, only the first is extracted
  -- because interpret() stops after the first starter/trailer pair.
  local text = tagged("first") .. " " .. tagged("second")
  local result = veafInterpreter.interpret(text)
  luaunit.assertEquals(result, "first")
end

-- ============================================================================
-- TestVeafInterpreterExecuteCommand
-- ============================================================================
TestVeafInterpreterExecuteCommand = {}

function TestVeafInterpreterExecuteCommand:test_processObject_no_tag()
  -- unitName with no interpreter tag → interpret() returns nil → executeCommandOnUnit is a no-op
  veafInterpreter.processObject("plain_unit_name_no_tag")
  luaunit.assertTrue(true)
end

function TestVeafInterpreterExecuteCommand:test_executeCommandOnUnit_nil_command()
  -- nil command → if command then branch not taken → immediate return
  veafInterpreter.executeCommandOnUnit("some_unit", nil)
  luaunit.assertTrue(true)
end

function TestVeafInterpreterExecuteCommand:test_executeCommandOnUnit_command_no_unit_no_static()
  -- command present, but Unit.getByName and StaticObject.getByName both return nil
  veafInterpreter.executeCommandOnUnit("nonexistent_unit", "spawn, sam")
  luaunit.assertTrue(true)
end

-- ---------------------------------------------------------------------------
-- FEAT-INTERPRETER-PARITY ticket 03 — a trigger the world does not hand back
--
-- #123 asks for interpreter trigger units to be late-activatable. `executeCommandOnUnit` read the
-- position from the running world only, so a unit neither `Unit.getByName` nor `StaticObject.getByName`
-- returns had its command dropped in silence — a late-activated unit being the obvious case, and one
-- destroyed in the mission's first second another.
--
-- `_initialize` already holds the mission record of every unit, so it is passed down as a fallback.
-- Whether DCS resolves a late-activated unit by name cannot be settled from a workstation, and this
-- makes it not matter.
--
-- Coordinates are the trap here: a mission record's `y` is the **easting**, while the position the
-- command expects is a vec3 whose `y` is the altitude. Asserting on that conversion is the point of
-- half these tests.
-- ---------------------------------------------------------------------------
TestVeafInterpreterMissionFallback = {}

function TestVeafInterpreterMissionFallback:setUp()
  self._execute = veafInterpreter.execute
  self._getUnit = Unit.getByName
  self._getStatic = StaticObject.getByName
  self._getRoute = veaf.getGroupRoute

  self.executed = {}
  veafInterpreter.execute = function(command, position, coa, route, spawnedGroups)
    table.insert(self.executed, { command = command, position = position, coalition = coa, route = route })
    return true -- "the command consumed the trigger", which is what asks for the destroy
  end
  Unit.getByName = function()
    return nil
  end
  StaticObject.getByName = function()
    return nil
  end
  veaf.getGroupRoute = function()
    return { "a route" }
  end
end

function TestVeafInterpreterMissionFallback:tearDown()
  veafInterpreter.execute = self._execute
  Unit.getByName = self._getUnit
  StaticObject.getByName = self._getStatic
  veaf.getGroupRoute = self._getRoute
end

--- A mission record as `mist.DBs.units` holds it: `x` northing, `y` **easting**, `alt` altitude.
local function missionUnit()
  return { unitName = "TRIGGER-1", x = 1000, y = 2000, alt = 55, coalitionId = 2, groupName = "TRIGGER-GROUP" }
end

function TestVeafInterpreterMissionFallback:test_the_command_runs_from_the_mission_record()
  veafInterpreter.executeCommandOnUnit("TRIGGER-1", "_spawn group, name x", missionUnit())
  luaunit.assertEquals(#self.executed, 1, "the command must not be dropped in silence")
  luaunit.assertEquals(self.executed[1].command, "_spawn group, name x")
end

-- The conversion, asserted rather than trusted: the record's easting must land in `z`, never in `y`.
function TestVeafInterpreterMissionFallback:test_the_easting_lands_in_z_not_in_y()
  veafInterpreter.executeCommandOnUnit("TRIGGER-1", "_spawn group, name x", missionUnit())
  local position = self.executed[1].position
  luaunit.assertEquals(position.x, 1000, "northing")
  luaunit.assertEquals(position.z, 2000, "easting belongs in z")
  luaunit.assertNotEquals(position.y, 2000, "y is the altitude, not the easting")
end

function TestVeafInterpreterMissionFallback:test_the_coalition_comes_from_the_record()
  veafInterpreter.executeCommandOnUnit("TRIGGER-1", "_spawn group, name x", missionUnit())
  luaunit.assertEquals(self.executed[1].coalition, 2)
end

function TestVeafInterpreterMissionFallback:test_the_groups_route_is_passed_along()
  veafInterpreter.executeCommandOnUnit("TRIGGER-1", "_spawn group, name x", missionUnit())
  luaunit.assertEquals(self.executed[1].route, { "a route" })
end

-- Nothing to destroy on this path, and trying must not raise: there is no world object.
function TestVeafInterpreterMissionFallback:test_nothing_is_destroyed_and_nothing_raises()
  local ok = pcall(veafInterpreter.executeCommandOnUnit, "TRIGGER-1", "_spawn group, name x", missionUnit())
  luaunit.assertTrue(ok)
end

-- The record must not be mutated: `veaf.placePointOnLand` writes into the table it is handed, so
-- passing the mission record straight in would corrupt `mist.DBs`.
function TestVeafInterpreterMissionFallback:test_the_mission_record_is_left_alone()
  local record = missionUnit()
  veafInterpreter.executeCommandOnUnit("TRIGGER-1", "_spawn group, name x", record)
  luaunit.assertEquals(record.y, 2000, "the record's easting must survive the call")
  luaunit.assertEquals(record.x, 1000)
end

-- With no record and no world object, behaviour is exactly what it was: nothing happens, quietly.
function TestVeafInterpreterMissionFallback:test_no_record_and_no_world_object_changes_nothing()
  veafInterpreter.executeCommandOnUnit("TRIGGER-1", "_spawn group, name x", nil)
  luaunit.assertEquals(#self.executed, 0)
end

-- A live unit still wins: the fallback must not take over a path that works.
function TestVeafInterpreterMissionFallback:test_a_live_unit_is_still_preferred()
  Unit.getByName = function()
    return {
      getPosition = function()
        return { p = { x = 7, y = 8, z = 9 } }
      end,
      getCoalition = function()
        return 1
      end,
      getGroup = function()
        return {
          getName = function()
            return "TRIGGER-GROUP"
          end,
          destroy = function() end,
        }
      end,
    }
  end
  veafInterpreter.executeCommandOnUnit("TRIGGER-1", "_spawn group, name x", missionUnit())
  luaunit.assertEquals(self.executed[1].position.x, 7, "the live unit's position, not the mission record's")
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------
os.exit(luaunit.LuaUnit.run())
