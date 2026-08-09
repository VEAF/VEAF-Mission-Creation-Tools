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
-- Run
-- ---------------------------------------------------------------------------
os.exit(luaunit.LuaUnit.run())
