--- Unit tests for VEAF-Server-hook.lua
---
--- Run:  lua test/lua/test_veafServerHook.lua
---
--- The hook runs in the DCS *hook* environment, not the mission one, so it is loaded
--- here with a stubbed `lfs` and a `Sim.setUserCallbacks` that does nothing. Nothing
--- else about it is faked: the real file is loaded and the real code paths run.
---
--- Covers (SECREV-2, findings VMR-001 and VMR-002):
---   - every value the hook injects survives as *data*, never as code
---   - the two layers that make that true, tested apart because either alone is a hole:
---       * the templates quote their values, so a value cannot close its own literal
---       * the transport quotes the payload, so a value cannot close the outer bracket
---   - the deliberate `-code` admin path still executes arbitrary Lua, as designed

local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")

-- The hook calls lfs.writedir() at load time to locate its pilots file. It is never
-- read here (loadPilots is only called from initialize), so a path is enough.
package.loaded["lfs"] = {
  writedir = function()
    return _base .. "/"
  end,
}

-- Registering the callbacks is the very last thing the file does; in the hook
-- environment DCS provides this, here it only has to exist.
Sim = Sim or {}
Sim.setUserCallbacks = function() end
Sim.getUnitProperty = function()
  return "TestUnit"
end
Sim.UNIT_NAME = "UNIT_NAME"

--- Everything the hook hands to net.dostring_in, newest last.
local injected = {}

net = net or {}
net.dostring_in = function(environment, code)
  injected[#injected + 1] = { environment = environment, code = code }
  return true
end
net.get_player_info = function(id)
  return net._playerInfo or { name = "player" .. tostring(id), ucid = "ucid-" .. tostring(id) }
end

dofile(_base .. "/../../src/scripts/Hooks/VEAF-Server-hook.lua")

-- ============================================================================
-- Detonation harness
-- ============================================================================

--- Compile and run `code` in a sandbox, returning what a_do_script received.
---
--- A breakout at the transport layer shows up here in one of two ways: the chunk
--- fails to compile, or it compiles and `delivered` is not the payload the hook
--- meant to send.
---
---@param code string the exact string handed to net.dostring_in
---@return table result `{compiled, delivered, beacon}` -- beacon is true if attacker
---        code ran while the transport chunk was being evaluated
local function unwrapTransport(code)
  local result = { compiled = false, delivered = nil, beacon = false }
  local env = {
    tostring = tostring,
    a_do_script = function(script)
      result.delivered = script
      return true
    end,
  }
  -- Reachable only by breaking out of the transport, so any call proves execution.
  env.BEACON = function()
    result.beacon = true
    return ""
  end
  local chunk = loadstring(code)
  if not chunk then
    return result
  end
  result.compiled = true
  setfenv(chunk, env)
  pcall(chunk)
  return result
end

--- Compile and run an injected payload against recording stand-ins for the mission
--- functions it calls, and report whether anything executed that should not have.
---
---@param payload string the Lua the hook wants the mission to run
---@return table result `{compiled, pwned, calls}`
local function detonate(payload)
  local result = { compiled = false, pwned = false, calls = {} }
  local function record(name)
    return function(...)
      result.calls[#result.calls + 1] = { fn = name, args = { ... } }
    end
  end
  local env = {
    tostring = tostring,
    veafRemote = {
      registerUser = record("registerUser"),
      registerUserSlot = record("registerUserSlot"),
      executeCommandFromRemote = record("executeCommandFromRemote"),
    },
    trigger = { action = { outText = record("outText") } },
  }
  -- Set only by attacker-supplied code, never by the templates themselves.
  env.PWNED = false
  local chunk = loadstring(payload)
  if not chunk then
    return result
  end
  result.compiled = true
  setfenv(chunk, env)
  pcall(chunk)
  result.pwned = env.PWNED
  return result
end

--- Run the last thing the hook injected all the way through both layers.
---@return table transport, table payload
local function detonateLastInjection()
  local last = injected[#injected]
  local transport = unwrapTransport(last.code)
  local payload = transport.delivered and detonate(transport.delivered) or { compiled = false, pwned = false, calls = {} }
  return transport, payload
end

--- First recorded call to `name`, or nil.
local function firstCall(result, name)
  for _, call in ipairs(result.calls) do
    if call.fn == name then
      return call
    end
  end
  return nil
end

-- ============================================================================
-- Attack strings
-- ============================================================================

-- Closes registerUser's first argument, runs a statement, reopens a call. Crafted to
-- stay syntactically valid: a syntax error would only be a crash, not an execution.
local ESCAPE_LITERAL = '") PWNED = true; veafRemote.registerUser("'

-- Closes the transport's long bracket and concatenates a call. Expression form, not
-- statement form: the transport chunk is `return a_do_script(...)`, and a statement
-- after a return does not compile -- so only an expression proves execution here.
local ESCAPE_BRACKET = "x]===]..tostring(BEACON())..[===[y"

-- ============================================================================
-- Test suite
-- ============================================================================

TestVeafServerHook = {}

function TestVeafServerHook:setUp()
  dcs_mocks.reset()
  injected = {}
  net._playerInfo = nil
  veafServerHook.pilots = {}
end

-- ---------------------------------------------------------------------------
-- VMR-001 / VMR-002 -- the two criticals, on the pre-authentication connect path
-- ---------------------------------------------------------------------------

--- A player name is data. Whatever it contains, it must reach registerUser as a
--- string and execute nothing. This is the finding, end to end through the real
--- callback DCS invokes before the player is authenticated.
function TestVeafServerHook:test_connect_with_a_crafted_name_executes_nothing()
  net._playerInfo = { name = ESCAPE_LITERAL, ucid = "ucid-1" }

  veafServerHook.onPlayerConnect(1)

  luaunit.assertEquals(#injected, 1)
  local transport, payload = detonateLastInjection()
  luaunit.assertTrue(transport.compiled)
  luaunit.assertTrue(payload.compiled)
  luaunit.assertFalse(payload.pwned)

  local call = firstCall(payload, "registerUser")
  luaunit.assertNotNil(call)
  luaunit.assertEquals(call.args[1], ESCAPE_LITERAL)
  -- The attack works by producing a *second* call; one call means it did not.
  luaunit.assertEquals(#payload.calls, 1)
end

--- The transport layer, tested on its own. Quoting the values is not enough: `%q`
--- escapes quotes and backslashes but not `]`, so a name carrying the closing long
--- bracket still breaks out of a fixed `[===[ ... ]===]` wrapper.
function TestVeafServerHook:test_connect_with_a_name_closing_the_transport_bracket()
  net._playerInfo = { name = ESCAPE_BRACKET, ucid = "ucid-1" }

  veafServerHook.onPlayerConnect(1)

  local transport, payload = detonateLastInjection()
  luaunit.assertTrue(transport.compiled)
  luaunit.assertFalse(transport.beacon)
  luaunit.assertTrue(payload.compiled)

  local call = firstCall(payload, "registerUser")
  luaunit.assertNotNil(call)
  luaunit.assertEquals(call.args[1], ESCAPE_BRACKET)
end

--- Characters that a plain "%s" template cannot carry at all: an unescaped newline
--- is a syntax error inside a short Lua string, so before the fix these names broke
--- the registration outright rather than merely being unsafe.
function TestVeafServerHook:test_connect_round_trips_awkward_names()
  for _, name in ipairs({ 'quote"inside', "back\\slash", "new\nline", "carriage\rreturn", "bracket]]end", "" }) do
    injected = {}
    net._playerInfo = { name = name, ucid = "ucid-1" }

    veafServerHook.onPlayerConnect(1)

    local transport, payload = detonateLastInjection()
    luaunit.assertTrue(transport.compiled, "transport did not compile for name: " .. string.format("%q", name))
    luaunit.assertTrue(payload.compiled, "payload did not compile for name: " .. string.format("%q", name))
    luaunit.assertFalse(payload.pwned)
    local call = firstCall(payload, "registerUser")
    luaunit.assertNotNil(call, "registerUser never called for name: " .. string.format("%q", name))
    luaunit.assertEquals(call.args[1], name)
  end
end

--- The slot callback interpolates three values the same way.
function TestVeafServerHook:test_change_slot_with_a_crafted_name_executes_nothing()
  net._playerInfo = { name = ESCAPE_LITERAL, ucid = "ucid-1", side = 0, slot = "" }

  veafServerHook.onPlayerChangeSlot(1)

  local _, payload = detonateLastInjection()
  luaunit.assertTrue(payload.compiled)
  luaunit.assertFalse(payload.pwned)
  local call = firstCall(payload, "registerUserSlot")
  luaunit.assertNotNil(call)
  luaunit.assertEquals(call.args[1], ESCAPE_LITERAL)
end

-- ---------------------------------------------------------------------------
-- The chat paths
-- ---------------------------------------------------------------------------

--- A command argument is attacker-controlled text and reaches RUN_COMMAND.
function TestVeafServerHook:test_command_argument_executes_nothing()
  local pilot = { level = 1 }

  veafServerHook.parse(pilot, "player", "ucid-1", "TestUnit", "/test " .. ESCAPE_LITERAL)

  local _, payload = detonateLastInjection()
  luaunit.assertTrue(payload.compiled)
  luaunit.assertFalse(payload.pwned)
  luaunit.assertNotNil(firstCall(payload, "executeCommandFromRemote"))
end

--- `-send` reaches trigger.action.outText through SEND_MESSAGE, and is open to any
--- registered pilot including level 0.
function TestVeafServerHook:test_send_message_executes_nothing()
  veafServerHook.sendMessage(ESCAPE_LITERAL, 10)

  local _, payload = detonateLastInjection()
  luaunit.assertTrue(payload.compiled)
  luaunit.assertFalse(payload.pwned)
  local call = firstCall(payload, "outText")
  luaunit.assertNotNil(call)
  luaunit.assertEquals(call.args[1], ESCAPE_LITERAL)
  luaunit.assertEquals(call.args[2], 10)
end

-- ---------------------------------------------------------------------------
-- What must keep working
-- ---------------------------------------------------------------------------

--- `-code` is a deliberate arbitrary-execution feature gated at level 90. Escaping it
--- would break it. It is here so that a later hardening pass cannot remove it by
--- accident, and to pin that the gate is what protects it.
function TestVeafServerHook:test_code_command_still_executes_arbitrary_lua()
  veafServerHook.parse({ level = 90 }, "admin", "ucid-1", "TestUnit", "/code PWNED = true")

  local transport = unwrapTransport(injected[#injected].code)
  luaunit.assertTrue(transport.compiled)
  local payload = detonate(transport.delivered)
  luaunit.assertTrue(payload.compiled)
  luaunit.assertTrue(payload.pwned)
end

--- ...and that a pilot below the bar cannot reach it at all.
function TestVeafServerHook:test_code_command_is_refused_below_level_90()
  local handled = veafServerHook.parse({ level = 89 }, "player", "ucid-1", "TestUnit", "/code PWNED = true")

  luaunit.assertFalse(handled)
  -- Only the registration injection, never the command itself.
  for _, entry in ipairs(injected) do
    luaunit.assertNil(string.find(entry.code, "PWNED", 1, true))
  end
end

--- An ordinary name must still arrive unchanged -- the fix must not start mangling
--- the values it protects.
function TestVeafServerHook:test_ordinary_connect_is_unchanged()
  net._playerInfo = { name = "Zip", ucid = "ucid-42" }
  veafServerHook.pilots["ucid-42"] = { level = 10 }

  veafServerHook.onPlayerConnect(1)

  local _, payload = detonateLastInjection()
  local call = firstCall(payload, "registerUser")
  luaunit.assertNotNil(call)
  luaunit.assertEquals(call.args[1], "Zip")
  luaunit.assertEquals(call.args[2], "10")
  luaunit.assertEquals(call.args[3], "ucid-42")
end

-- ---------------------------------------------------------------------------
-- FIX-REMOTE-SLOT-NIL-UNIT — what the hook sends for a player in no unit
--
-- `tostring(unitName or "nil")` sent the four-character string, which is truthy on the mission side, so
-- the player was registered as occupying a unit called `nil`. The value the hook puts on the wire is
-- what these assert; the mission side normalising it is covered in test_veafRemote.
-- ---------------------------------------------------------------------------

--- The third argument of the registerUserSlot call the hook injected, whatever it was.
local function lastSlotUnitName()
  local _, payload = detonateLastInjection()
  local call = firstCall(payload, "registerUserSlot")
  luaunit.assertNotNil(call, "registerUserSlot was never called")
  return call.args[3]
end

function TestVeafServerHook:test_a_spectator_reports_no_unit_rather_than_the_string_nil()
  -- side 0 with an empty slot is the spectator case, and the game-master one
  net._playerInfo = { name = "Zip", ucid = "ucid-1", side = 0, slot = "" }
  veafServerHook.onPlayerChangeSlot(1)
  luaunit.assertEquals(lastSlotUnitName(), "")
end

function TestVeafServerHook:test_a_player_with_no_slot_reports_no_unit()
  net._playerInfo = { name = "Zip", ucid = "ucid-1", side = 1, slot = nil }
  veafServerHook.onPlayerChangeSlot(1)
  luaunit.assertEquals(lastSlotUnitName(), "")
end

function TestVeafServerHook:test_the_literal_nil_is_never_sent_again()
  -- the assertion that pins the defect: any of the three "no unit" shapes must not produce "nil"
  for _, info in ipairs({
    { name = "Zip", ucid = "u", side = 0, slot = "" },
    { name = "Zip", ucid = "u", side = 1, slot = "" },
    { name = "Zip", ucid = "u", side = 0, slot = "1" },
  }) do
    net._playerInfo = info
    veafServerHook.onPlayerChangeSlot(1)
    luaunit.assertNotEquals(lastSlotUnitName(), "nil")
  end
end

function TestVeafServerHook:test_a_player_in_a_slot_still_reports_his_unit()
  -- non-regression: the nominal path, which Sim.getUnitProperty stubs to "TestUnit"
  net._playerInfo = { name = "Zip", ucid = "ucid-1", side = 1, slot = "1" }
  veafServerHook.onPlayerChangeSlot(1)
  luaunit.assertEquals(lastSlotUnitName(), "TestUnit")
end

function TestVeafServerHook:test_a_multi_seat_slot_still_reports_its_unit()
  -- a seat id is stripped off before the property lookup, and that must keep working
  net._playerInfo = { name = "Zip", ucid = "ucid-1", side = 2, slot = "12_2" }
  veafServerHook.onPlayerChangeSlot(1)
  luaunit.assertEquals(lastSlotUnitName(), "TestUnit")
end

os.exit(luaunit.LuaUnit.run())
