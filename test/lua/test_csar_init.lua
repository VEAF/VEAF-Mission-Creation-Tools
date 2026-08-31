--- CSAR initialisation — FIX-CSAR-INIT-GUARD.
--
-- The load order here is the one a VEAF build produces, and it is the point of the file: the
-- community scripts are injected **before** the VEAF bundle (CSAR fifth, veaf-scripts.lua seventh).
-- Every other Lua suite loads VEAF first, which is why neither of the two defects below could be
-- seen from the tests — one of them shipped and broke every mission until it was found in game.
--
-- What is asserted is the wiring, not the flags: how many event handlers DCS ends up holding. A
-- test on `csar.alreadyInitialized` would have passed against code that never sets it.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")

-- CSAR first, as a mission does.
dofile(_base .. "/../../src/scripts/community/CSAR.lua")

-- Then the VEAF bundle, which replaces csar.initialize with its own wrapper.
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafMissionDb.lua")
dofile(src .. "/veafDcsSpawner.lua")

TestCsarInitialisation = {}

function TestCsarInitialisation:setUp()
  dcs_mocks.reset()
  -- Both initialisation flags, or a test inherits the previous one's "already done" and asserts
  -- against the leak rather than against the code. The suite is about initialising twice, so
  -- carrying that state across tests would be the one mistake guaranteed to mislead.
  csar.alreadyInitialized = nil
  veaf.csar_initialized = nil
  csar.csarUnits = {}
  csar.woundedGroups = {}
end

--- CSAR loads at all, which is not a given.
---
--- Its dependency check used to run at load time, asserting on `veaf` — which cannot exist yet at
--- this point in the order. Every mission with CSAR enabled opened on "The VEAF framework has not
--- been loaded!". This file loading is the regression test for that.
function TestCsarInitialisation:test_csar_loads_before_veaf_without_complaining()
  luaunit.assertEquals(type(csar), "table", "CSAR loaded even though veaf came after it")
  luaunit.assertEquals(type(csar.initialize), "function")
end

function TestCsarInitialisation:test_veaf_replaced_the_initialiser()
  -- The wrapper is what a mission actually calls, so it is what these tests must exercise.
  luaunit.assertEquals(csar.initialize, veaf.csar_initialize_replacement, "veaf.lua wraps csar.initialize")
end

function TestCsarInitialisation:test_initialising_once_registers_one_event_handler()
  csar.initialize()

  luaunit.assertEquals(#dcs_mocks.eventHandlers, 1, "one handler after one initialisation")
end

function TestCsarInitialisation:test_initialising_twice_still_registers_only_one()
  -- The path `veaf.lua` documents to mission makers: "we count on the mission makers to call
  -- csar.initialize from mission-script.lua". That call lands on top of the automatic one scheduled
  -- two seconds after load, so this is two initialisations in a normal mission, not an abuse.
  --
  -- DCS does not deduplicate handlers. A second registration means every ejection is handled twice:
  -- two MAYDAYs, two downed pilots for one crash. That is #824, in a different file.
  csar.initialize()
  csar.initialize()

  luaunit.assertEquals(#dcs_mocks.eventHandlers, 1, "the second initialisation must not add a handler")
end

function TestCsarInitialisation:test_re_initialising_applies_the_new_configuration()
  -- Re-initialising is a feature, not an accident: it is how a mission maker's configuration
  -- callback gets applied. So the fix must not be "refuse the second call" — the second call has to
  -- do its work, and only the handler must not stack.
  local calls = 0
  csar.initialize(function()
    calls = calls + 1
  end)
  csar.initialize(function()
    calls = calls + 1
  end)

  luaunit.assertEquals(calls, 2, "both configuration callbacks ran")
  luaunit.assertEquals(#dcs_mocks.eventHandlers, 1, "and still one handler")
end

--- How many pending tasks are scheduled for `fn`.
local function pendingFor(fn)
  local count = 0
  for _, task in pairs(dcs_mocks.scheduledTasks) do
    if task.fn == fn then
      count = count + 1
    end
  end
  return count
end

function TestCsarInitialisation:test_re_initialising_does_not_start_a_second_polling_chain()
  -- `csar.addMedevacMenuItem` reschedules *itself* every five seconds, so each initialisation that
  -- starts one leaves an independent chain running for the rest of the mission — they accumulate
  -- and never stop. Worse than the duplicated handler: that one at least stops when the mission does.
  --
  -- Found by review on #852, after the handler fix; the same second call was doing two harmful
  -- things and only one had been dealt with.
  csar.initialize()
  luaunit.assertEquals(pendingFor(csar.addMedevacMenuItem), 1, "one chain after one initialisation")

  csar.initialize()

  luaunit.assertEquals(pendingFor(csar.addMedevacMenuItem), 1, "still one chain, not two")
end

function TestCsarInitialisation:test_the_chain_keeps_running_after_a_re_initialisation()
  -- Suppressing the duplicate must not suppress the original: the menu still has to be refreshed.
  csar.initialize()
  csar.initialize()
  dcs_mocks.runScheduled(12)

  luaunit.assertTrue(pendingFor(csar.addMedevacMenuItem) >= 1, "the surviving chain still reschedules")
end

function TestCsarInitialisation:test_csars_own_guard_is_no_longer_a_dead_branch()
  -- `csar.alreadyInitialized` is read by the vanilla initialiser and was written by nobody, so its
  -- bypass branch was unreachable and its log line had never once been printed. Asserting the flag
  -- here is asserting that a *direct* call to the vanilla function now short-circuits.
  csar.initialize()

  luaunit.assertTrue(csar.alreadyInitialized, "the flag the vanilla guard reads is now set")
end

function TestCsarInitialisation:test_forcing_reinitialisation_does_not_stack_handlers()
  -- `force` exists to redo the setup deliberately — after a configuration change, say. Redoing it
  -- must not leave the previous handler behind.
  csar.initialize()
  csar.initialize(true)

  luaunit.assertEquals(#dcs_mocks.eventHandlers, 1, "forcing replaces the handler, it does not add one")
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------
local runner = luaunit.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
