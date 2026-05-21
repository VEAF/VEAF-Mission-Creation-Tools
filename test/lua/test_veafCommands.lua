--- Unit tests for veafCommands.lua — registry ordering and dispatch behaviour.
---
--- Run:  lua test/lua/test_veafCommands.lua
---
--- Covers:
---   - registerCommandHandler inserts entries in ascending priority order
---   - execute() stops at the first handler returning true
---   - execute() tries all handlers when none matches
---   - fromMarker flag is false on the execute() path
---   - bypassSecurity is true on the execute() path

-- ---------------------------------------------------------------------------
-- Bootstrap
-- ---------------------------------------------------------------------------
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafMarkers.lua")
dofile(src .. "/veafCommands.lua")

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function resetHandlers()
  veafCommands.commandHandlers = {}
end

local function makeHandler(retval, collector)
  return function(pos, event, bypass, fromMarker, groups, route)
    if collector then
      table.insert(collector, { bypass = bypass, fromMarker = fromMarker })
    end
    return retval
  end
end

local pos = { x = 0, y = 0, z = 0 }

-- ---------------------------------------------------------------------------
-- TestVeafCommandsRegistry — priority ordering
-- ---------------------------------------------------------------------------
TestVeafCommandsRegistry = {}

function TestVeafCommandsRegistry:setUp()
  resetHandlers()
end

function TestVeafCommandsRegistry:test_single_handler_registered()
  local fn = makeHandler(false)
  veafCommands.registerCommandHandler(fn, 10)
  luaunit.assertEquals(#veafCommands.commandHandlers, 1)
  luaunit.assertEquals(veafCommands.commandHandlers[1].priority, 10)
end

function TestVeafCommandsRegistry:test_handlers_sorted_ascending()
  veafCommands.registerCommandHandler(makeHandler(false), 30)
  veafCommands.registerCommandHandler(makeHandler(false), 10)
  veafCommands.registerCommandHandler(makeHandler(false), 20)
  luaunit.assertEquals(veafCommands.commandHandlers[1].priority, 10)
  luaunit.assertEquals(veafCommands.commandHandlers[2].priority, 20)
  luaunit.assertEquals(veafCommands.commandHandlers[3].priority, 30)
end

function TestVeafCommandsRegistry:test_equal_priority_preserves_insertion_order()
  local calls = {}
  local fn1 = function() table.insert(calls, 1) return false end
  local fn2 = function() table.insert(calls, 2) return false end
  veafCommands.registerCommandHandler(fn1, 20)
  veafCommands.registerCommandHandler(fn2, 20)
  veafCommands.execute(pos, "ignored", 2, nil, nil)
  luaunit.assertEquals(calls, { 1, 2 })
end

-- ---------------------------------------------------------------------------
-- TestVeafCommandsDispatch — execute() behaviour
-- ---------------------------------------------------------------------------
TestVeafCommandsDispatch = {}

function TestVeafCommandsDispatch:setUp()
  resetHandlers()
end

function TestVeafCommandsDispatch:test_stops_at_first_true()
  local calls = {}
  veafCommands.registerCommandHandler(function() table.insert(calls, 1) return true end, 10)
  veafCommands.registerCommandHandler(function() table.insert(calls, 2) return true end, 20)
  local result = veafCommands.execute(pos, "cmd", 2, nil, nil)
  luaunit.assertTrue(result)
  luaunit.assertEquals(calls, { 1 })
end

function TestVeafCommandsDispatch:test_tries_all_when_none_matches()
  local calls = {}
  veafCommands.registerCommandHandler(function() table.insert(calls, 1) return false end, 10)
  veafCommands.registerCommandHandler(function() table.insert(calls, 2) return false end, 20)
  local result = veafCommands.execute(pos, "cmd", 2, nil, nil)
  luaunit.assertFalse(result)
  luaunit.assertEquals(calls, { 1, 2 })
end

function TestVeafCommandsDispatch:test_execute_sets_fromMarker_false()
  local captured = {}
  veafCommands.registerCommandHandler(makeHandler(true, captured), 10)
  veafCommands.execute(pos, "cmd", 2, nil, nil)
  luaunit.assertFalse(captured[1].fromMarker)
end

function TestVeafCommandsDispatch:test_execute_sets_bypassSecurity_true()
  local captured = {}
  veafCommands.registerCommandHandler(makeHandler(true, captured), 10)
  veafCommands.execute(pos, "cmd", 2, nil, nil)
  luaunit.assertTrue(captured[1].bypass)
end

function TestVeafCommandsDispatch:test_no_handlers_returns_false()
  local result = veafCommands.execute(pos, "anything", 2, nil, nil)
  luaunit.assertFalse(result)
end

-- ---------------------------------------------------------------------------
os.exit(luaunit.LuaUnit.run())
