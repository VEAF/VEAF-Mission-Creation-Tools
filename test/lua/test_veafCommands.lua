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
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafMissionDb.lua")
dofile(src .. "/veafDcsSpawner.lua")
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
  veafCommands.registerCommandHandler(fn, 10, veafCommands.SECURITY_HANDLED)
  luaunit.assertEquals(#veafCommands.commandHandlers, 1)
  luaunit.assertEquals(veafCommands.commandHandlers[1].priority, 10)
end

function TestVeafCommandsRegistry:test_handlers_sorted_ascending()
  veafCommands.registerCommandHandler(makeHandler(false), 30, veafCommands.SECURITY_HANDLED)
  veafCommands.registerCommandHandler(makeHandler(false), 10, veafCommands.SECURITY_HANDLED)
  veafCommands.registerCommandHandler(makeHandler(false), 20, veafCommands.SECURITY_HANDLED)
  luaunit.assertEquals(veafCommands.commandHandlers[1].priority, 10)
  luaunit.assertEquals(veafCommands.commandHandlers[2].priority, 20)
  luaunit.assertEquals(veafCommands.commandHandlers[3].priority, 30)
end

function TestVeafCommandsRegistry:test_equal_priority_preserves_insertion_order()
  local calls = {}
  local fn1 = function()
    table.insert(calls, 1)
    return false
  end
  local fn2 = function()
    table.insert(calls, 2)
    return false
  end
  veafCommands.registerCommandHandler(fn1, 20, veafCommands.SECURITY_HANDLED)
  veafCommands.registerCommandHandler(fn2, 20, veafCommands.SECURITY_HANDLED)
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
  veafCommands.registerCommandHandler(function()
    table.insert(calls, 1)
    return true
  end, 10, veafCommands.SECURITY_HANDLED)
  veafCommands.registerCommandHandler(function()
    table.insert(calls, 2)
    return true
  end, 20, veafCommands.SECURITY_HANDLED)
  local result = veafCommands.execute(pos, "cmd", 2, nil, nil)
  luaunit.assertTrue(result)
  luaunit.assertEquals(calls, { 1 })
end

function TestVeafCommandsDispatch:test_tries_all_when_none_matches()
  local calls = {}
  veafCommands.registerCommandHandler(function()
    table.insert(calls, 1)
    return false
  end, 10, veafCommands.SECURITY_HANDLED)
  veafCommands.registerCommandHandler(function()
    table.insert(calls, 2)
    return false
  end, 20, veafCommands.SECURITY_HANDLED)
  local result = veafCommands.execute(pos, "cmd", 2, nil, nil)
  luaunit.assertFalse(result)
  luaunit.assertEquals(calls, { 1, 2 })
end

function TestVeafCommandsDispatch:test_execute_sets_fromMarker_false()
  local captured = {}
  veafCommands.registerCommandHandler(makeHandler(true, captured), 10, veafCommands.SECURITY_HANDLED)
  veafCommands.execute(pos, "cmd", 2, nil, nil)
  luaunit.assertFalse(captured[1].fromMarker)
end

function TestVeafCommandsDispatch:test_execute_sets_bypassSecurity_true()
  local captured = {}
  veafCommands.registerCommandHandler(makeHandler(true, captured), 10, veafCommands.SECURITY_HANDLED)
  veafCommands.execute(pos, "cmd", 2, nil, nil)
  luaunit.assertTrue(captured[1].bypass)
end

function TestVeafCommandsDispatch:test_no_handlers_returns_false()
  local result = veafCommands.execute(pos, "anything", 2, nil, nil)
  luaunit.assertFalse(result)
end

-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- TestVeafCommandsSecurityDeclaration (SECREV-2 ticket 03, finding VMR-003)
--
-- The dispatcher used to delegate the security decision to each handler, so a handler
-- that simply did not check ran for anyone and nothing noticed. Four of the nine had
-- drifted that way. The level is now an argument with no default: the point of these
-- tests is that forgetting it is an error at registration, not an open door at dispatch.
-- ---------------------------------------------------------------------------
TestVeafCommandsSecurityDeclaration = {}

function TestVeafCommandsSecurityDeclaration:setUp()
  resetHandlers()
  self.savedChecks = veafCommands.SECURITY_CHECKS
  self.savedSecurity = veafSecurity
end

function TestVeafCommandsSecurityDeclaration:tearDown()
  veafCommands.SECURITY_CHECKS = self.savedChecks
  veafSecurity = self.savedSecurity
end

--- The acceptance criterion: adding a handler that forgets a level fails a test, not a server.
function TestVeafCommandsSecurityDeclaration:test_registering_without_a_level_is_refused()
  local ok, err = pcall(veafCommands.registerCommandHandler, makeHandler(true), 10)

  luaunit.assertFalse(ok)
  luaunit.assertNotNil(string.find(tostring(err), "security", 1, true))
  luaunit.assertEquals(#veafCommands.commandHandlers, 0)
end

--- A misspelled level must not read as "no level, carry on".
function TestVeafCommandsSecurityDeclaration:test_registering_an_unknown_level_is_refused()
  local ok = pcall(veafCommands.registerCommandHandler, makeHandler(true), 10, "L99")

  luaunit.assertFalse(ok)
  luaunit.assertEquals(#veafCommands.commandHandlers, 0)
end

--- Both vocabularies, in one sweep. The new names come from REVIEW-SECURITY-LAYER decision b
--- (2026-08-08); the old ones stay for one release. FIX-DOCAUDIT-CODE 01: the dispatcher accepted
--- only the 2021 spellings, so registering a handler with the decided vocabulary hit the assert --
--- the rename existed in the documentation and in one function nothing called.
function TestVeafCommandsSecurityDeclaration:test_every_documented_level_is_accepted()
  local levels = {
    "ADMIN",
    "SENIOR_PILOT",
    "KNOWN_PILOT",
    "L0",
    "L1",
    "L9",
    "OPEN",
    veafCommands.SECURITY_HANDLED,
  }
  for _, level in ipairs(levels) do
    resetHandlers()
    veafCommands.registerCommandHandler(makeHandler(true), 10, level)
    luaunit.assertEquals(#veafCommands.commandHandlers, 1, "level rejected: " .. tostring(level))
    luaunit.assertEquals(veafCommands.commandHandlers[1].security, level)
  end
end

--- A deprecated name and its replacement must be the **same** function, not two copies of it:
--- a copy is how one of two paths receives tomorrow's fix (the lesson REFACTOR-MARKER-PARSER paid
--- for). `ADMIN` is the tightest tier and maps to `L0`, not to `L9` -- the ticket's own example had
--- that backwards, and `veafSecurity.LEVELS_BY_NAME` settles it.
function TestVeafCommandsSecurityDeclaration:test_a_deprecated_name_shares_its_replacement_check()
  luaunit.assertIs(veafCommands.SECURITY_CHECKS.L0, veafCommands.SECURITY_CHECKS.ADMIN)
  luaunit.assertIs(veafCommands.SECURITY_CHECKS.L1, veafCommands.SECURITY_CHECKS.SENIOR_PILOT)
  luaunit.assertIs(veafCommands.SECURITY_CHECKS.L9, veafCommands.SECURITY_CHECKS.KNOWN_PILOT)
end

--- Registering with an old name warns, through the function that carries the warning --
--- `veafSecurity.levelForName`, which had no production caller at all before this.
function TestVeafCommandsSecurityDeclaration:test_a_deprecated_name_warns_through_levelForName()
  local resolved = {}
  veafSecurity = {
    DEPRECATED_LEVEL_NAMES = { L0 = "ADMIN", L1 = "SENIOR_PILOT", L9 = "KNOWN_PILOT" },
    levelForName = function(name)
      table.insert(resolved, name)
      return 1
    end,
  }

  veafCommands.registerCommandHandler(makeHandler(true), 10, "L9")
  veafCommands.registerCommandHandler(makeHandler(true), 20, "KNOWN_PILOT")
  veafCommands.registerCommandHandler(makeHandler(true), 30, "OPEN")

  luaunit.assertEquals(resolved, { "L9" }, "only a deprecated spelling goes through the warning path")
  luaunit.assertEquals(#veafCommands.commandHandlers, 3, "warning about a name must not refuse it")
end

-- ---------------------------------------------------------------------------
-- TestVeafCommandsSecurityEnforcement — the dispatcher acts on the declaration
-- ---------------------------------------------------------------------------
TestVeafCommandsSecurityEnforcement = {}

function TestVeafCommandsSecurityEnforcement:setUp()
  resetHandlers()
  self.savedChecks = veafCommands.SECURITY_CHECKS
  self.ran = {}
end

function TestVeafCommandsSecurityEnforcement:tearDown()
  veafCommands.SECURITY_CHECKS = self.savedChecks
end

--- Replace the real checks so the test states the verdict rather than the password rules.
function TestVeafCommandsSecurityEnforcement:setVerdict(allowed)
  veafCommands.SECURITY_CHECKS = {
    L0 = function()
      return allowed
    end,
    L1 = function()
      return allowed
    end,
    L9 = function()
      return allowed
    end,
    OPEN = function()
      return true
    end,
  }
end

function TestVeafCommandsSecurityEnforcement:recordingHandler(name)
  local ran = self.ran
  return function()
    table.insert(ran, name)
    return true
  end
end

function TestVeafCommandsSecurityEnforcement:test_a_denied_handler_does_not_run()
  self:setVerdict(false)
  veafCommands.registerCommandHandler(self:recordingHandler("gated"), 10, "L9")

  local consumed = veafCommands.dispatchMarker(pos, { text = "-test", idx = 1 })

  luaunit.assertFalse(consumed)
  luaunit.assertEquals(#self.ran, 0)
end

function TestVeafCommandsSecurityEnforcement:test_an_allowed_handler_runs()
  self:setVerdict(true)
  veafCommands.registerCommandHandler(self:recordingHandler("gated"), 10, "L9")

  local consumed = veafCommands.dispatchMarker(pos, { text = "-test", idx = 1 })

  luaunit.assertTrue(consumed)
  luaunit.assertEquals(self.ran, { "gated" })
end

--- Denying one handler must not swallow the event: a later handler still gets its turn.
function TestVeafCommandsSecurityEnforcement:test_a_denied_handler_does_not_block_the_chain()
  self:setVerdict(false)
  veafCommands.registerCommandHandler(self:recordingHandler("gated"), 10, "L9")
  veafCommands.registerCommandHandler(self:recordingHandler("open"), 20, "OPEN")

  local consumed = veafCommands.dispatchMarker(pos, { text = "-test", idx = 1 })

  luaunit.assertTrue(consumed)
  luaunit.assertEquals(self.ran, { "open" })
end

--- A handler that checks itself must not be checked twice -- the dispatcher has no
--- password to check with, so gating it here would deny everything it protects.
function TestVeafCommandsSecurityEnforcement:test_a_self_checking_handler_is_not_gated()
  self:setVerdict(false)
  veafCommands.registerCommandHandler(self:recordingHandler("own"), 10, veafCommands.SECURITY_HANDLED)

  luaunit.assertTrue(veafCommands.dispatchMarker(pos, { text = "-test", idx = 1 }))
  luaunit.assertEquals(self.ran, { "own" })
end

--- The interpreter path runs unit-name commands authored by the mission maker, so it
--- bypasses the gate by design. Pinned so that a later change has to be deliberate.
function TestVeafCommandsSecurityEnforcement:test_the_interpreter_path_bypasses_the_gate()
  self:setVerdict(false)
  veafCommands.registerCommandHandler(self:recordingHandler("gated"), 10, "L9")

  luaunit.assertTrue(veafCommands.execute(pos, "-test", 2))
  luaunit.assertEquals(self.ran, { "gated" })
end

--- An unrecognised level reaching dispatch denies rather than allows. Registration
--- refuses one, so this pins the direction of the fallback if the table is ever edited.
function TestVeafCommandsSecurityEnforcement:test_an_unknown_level_at_dispatch_denies()
  veafCommands.registerCommandHandler(self:recordingHandler("gated"), 10, "L9")
  veafCommands.commandHandlers[1].security = "L42"

  luaunit.assertFalse(veafCommands.dispatchMarker(pos, { text = "-test", idx = 1 }))
  luaunit.assertEquals(#self.ran, 0)
end

-- ---------------------------------------------------------------------------
-- TestVeafCommandsRecognitionBeforeSecurity — FIX-SECURITY-BEFORE-RECOGNITION
-- ---------------------------------------------------------------------------
--- David, in game 2026-08-14: a refused `_transport` printed its message **three times**. The cause
--- is broader than that command — `isAllowed` ran before the handler said whether it recognised the
--- text, so every handler whose tier the pilot lacked printed a refusal for a command it would never
--- have handled. A pilot writing "RDV ici" on a marker got two "give the L1 password" messages.
---
--- These tests count *security calls*, not messages: the message is a consequence, the call is the
--- defect.
TestVeafCommandsRecognitionBeforeSecurity = {}

function TestVeafCommandsRecognitionBeforeSecurity:setUp()
  resetHandlers()
  self.savedChecks = veafCommands.SECURITY_CHECKS
  self.calls = 0
  local counter = self
  veafCommands.SECURITY_CHECKS = {
    SENIOR_PILOT = function()
      counter.calls = counter.calls + 1
      return false
    end,
    KNOWN_PILOT = function()
      counter.calls = counter.calls + 1
      return false
    end,
    OPEN = function()
      return true
    end,
  }
end

function TestVeafCommandsRecognitionBeforeSecurity:tearDown()
  veafCommands.SECURITY_CHECKS = self.savedChecks
end

--- The everyday case: plain text on a marker must not be run past anybody's security.
function TestVeafCommandsRecognitionBeforeSecurity:test_plain_text_is_never_checked_for_security()
  veafCommands.registerCommandHandler(makeHandler(false), 60, "SENIOR_PILOT", "_move")
  veafCommands.registerCommandHandler(makeHandler(false), 70, "SENIOR_PILOT", "_radio")

  veafCommands.dispatchMarker(pos, { text = "RDV ici", idx = 1 })

  luaunit.assertEquals(self.calls, 0, "annotating the map must not ask for a password")
end

--- The filter must not swallow the real case.
function TestVeafCommandsRecognitionBeforeSecurity:test_a_matching_keyphrase_still_reaches_security()
  veafCommands.registerCommandHandler(makeHandler(false), 60, "SENIOR_PILOT", "_move")
  veafCommands.registerCommandHandler(makeHandler(false), 70, "SENIOR_PILOT", "_radio")

  veafCommands.dispatchMarker(pos, { text = "_move group, name x", idx = 1 })

  luaunit.assertEquals(self.calls, 1, "only the handler whose keyphrase matches is checked")
end

--- Matching follows what the modules do today: `event.text:lower():find(Keyphrase)`.
function TestVeafCommandsRecognitionBeforeSecurity:test_matching_is_case_insensitive()
  veafCommands.registerCommandHandler(makeHandler(false), 60, "SENIOR_PILOT", "_move")

  veafCommands.dispatchMarker(pos, { text = "_MOVE GROUP, name x", idx = 1 })

  luaunit.assertEquals(self.calls, 1, "a pilot typing in capitals is still typing the command")
end

--- Additive by construction: a handler registered without a keyphrase keeps today's behaviour, so the
--- five callers can be migrated one at a time.
function TestVeafCommandsRecognitionBeforeSecurity:test_a_handler_without_a_keyphrase_is_still_checked()
  veafCommands.registerCommandHandler(makeHandler(false), 60, "SENIOR_PILOT")

  veafCommands.dispatchMarker(pos, { text = "RDV ici", idx = 1 })

  luaunit.assertEquals(self.calls, 1, "no keyphrase declared means no filtering")
end

os.exit(luaunit.LuaUnit.run())
