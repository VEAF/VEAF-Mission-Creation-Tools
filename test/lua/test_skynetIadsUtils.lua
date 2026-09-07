--- Tests for the MiST-replacement scheduler inside the vendored Skynet artefact.
---
--- Run:  lua test/lua/test_skynetIadsUtils.lua
---
--- `src/scripts/community/skynet-iads-compiled.lua` is a compiled artefact, regenerated from
--- https://github.com/VEAF/Skynet-IADS — it is not edited here. The fork has no headless test
--- harness (its `unit-tests/` run inside DCS from a `.miz`, on top of MiST), so the guarantee the
--- artefact must keep is asserted on this side, against the artefact itself.
---
--- What is being guarded: `SkynetIADSUtils.scheduleFunction` replaced MiST's 0.01 s task loop,
--- which ran anything whose time had come **or gone**. Skynet passes a hardcoded `startTime` of 1
--- at three sites (`SkynetIADS:activate`, `SkynetIADS:scanForHarms`,
--- `SkynetIADSJammer:masterArmOn`), so once an IADS initialises more than a second into a mission
--- that time is already past. Handing it to the native timer unchanged lost the task silently —
--- Tripack's 2026-09-03 flight, three minutes in: no contact evaluation, every SAM dark, blank
--- status page, and not one error in `dcs.log`.
---
--- The assertions read the time actually handed to `timer.scheduleFunction` rather than the
--- module's floor constant: the constant was right before the fix too, it simply was not applied.
---
--- Covers:
---   - An overdue first run is armed in the future, and still runs
---   - A first run due exactly now is armed in the future, and still runs
---   - A comfortably future first run is armed at the time asked for, untouched
---   - Repetition survives a clamped first run
---   - `stopTime` still ends a repeating task
---   - `removeFunction` still cancels, and still answers false for an unknown id

-- ---------------------------------------------------------------------------
-- Bootstrap: DCS mocks, then the vendored artefact.
-- ---------------------------------------------------------------------------
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua") -- exported as global for test methods
dofile(_base .. "/dcs_mocks.lua")
dofile(_base .. "/../../src/scripts/community/skynet-iads-compiled.lua")

--- The single task the mock timer is currently holding, as the native timer received it.
---
--- `SkynetIADSUtils` hands back an id of its own, not the native one, so the arming time is read
--- from the mock's own record. Each test schedules exactly one task after a reset.
local function armedTask()
  local found = nil
  for _, task in pairs(dcs_mocks.scheduledTasks) do
    luaunit.assertNil(found, "expected exactly one armed task")
    found = task
  end
  luaunit.assertNotNil(found, "expected one armed task, found none")
  return found
end

TestSkynetIadsUtilsScheduler = {}

function TestSkynetIadsUtilsScheduler:setUp()
  dcs_mocks.reset()
end

-- ---------------------------------------------------------------------------
-- The floor on the first run
-- ---------------------------------------------------------------------------

function TestSkynetIadsUtilsScheduler:test_overdueFirstRunIsArmedInTheFutureAndStillRuns()
  dcs_mocks.currentTime = 180 -- an IADS coming up three minutes into the mission
  local calls = 0
  SkynetIADSUtils.scheduleFunction(function()
    calls = calls + 1
  end, {}, 1) -- the hardcoded start time SkynetIADS:activate uses

  local task = armedTask()
  luaunit.assertTrue(task.time > 180, "an overdue task must not be handed to the timer as-is, got " .. tostring(task.time))

  dcs_mocks.runScheduled(181)
  luaunit.assertEquals(calls, 1)
end

function TestSkynetIadsUtilsScheduler:test_firstRunDueNowIsArmedInTheFutureAndStillRuns()
  dcs_mocks.currentTime = 42
  local calls = 0
  SkynetIADSUtils.scheduleFunction(function()
    calls = calls + 1
  end, {}, timer.getTime())

  local task = armedTask()
  luaunit.assertTrue(task.time > 42, "a task due now must be armed for the next tick, got " .. tostring(task.time))

  dcs_mocks.runScheduled(43)
  luaunit.assertEquals(calls, 1)
end

function TestSkynetIadsUtilsScheduler:test_comfortablyFutureFirstRunIsLeftAlone()
  dcs_mocks.currentTime = 100
  SkynetIADSUtils.scheduleFunction(function() end, {}, 160)

  luaunit.assertEquals(armedTask().time, 160)
end

function TestSkynetIadsUtilsScheduler:test_argumentsAreStillUnpackedIntoAClampedFirstRun()
  dcs_mocks.currentTime = 180
  local seen = nil
  SkynetIADSUtils.scheduleFunction(function(a, b)
    seen = { a, b }
  end, { "iads", 7 }, 1)

  dcs_mocks.runScheduled(181)
  luaunit.assertEquals(seen, { "iads", 7 })
end

-- ---------------------------------------------------------------------------
-- Semantics the clamp must not have changed
-- ---------------------------------------------------------------------------

function TestSkynetIadsUtilsScheduler:test_repetitionSurvivesAClampedFirstRun()
  dcs_mocks.currentTime = 180
  local calls = 0
  SkynetIADSUtils.scheduleFunction(function()
    calls = calls + 1
  end, {}, 1, 5) -- Skynet's contact cycle: overdue start, then every few seconds

  dcs_mocks.runScheduled(200)
  luaunit.assertEquals(calls, 4) -- 180.01, 185.01, 190.01, 195.01; the next one falls past 200
end

function TestSkynetIadsUtilsScheduler:test_stopTimeStillEndsARepeatingTask()
  dcs_mocks.currentTime = 100
  local calls = 0
  SkynetIADSUtils.scheduleFunction(function()
    calls = calls + 1
  end, {}, 101, 5, 120)

  dcs_mocks.runScheduled(200)
  luaunit.assertEquals(calls, 4) -- 101, 106, 111, 116; the run at 121 is past the stop time
end

function TestSkynetIadsUtilsScheduler:test_removeFunctionStillCancelsAClampedTask()
  dcs_mocks.currentTime = 180
  local calls = 0
  local id = SkynetIADSUtils.scheduleFunction(function()
    calls = calls + 1
  end, {}, 1, 5)

  luaunit.assertTrue(SkynetIADSUtils.removeFunction(id))
  dcs_mocks.runScheduled(300)
  luaunit.assertEquals(calls, 0)
end

function TestSkynetIadsUtilsScheduler:test_removeFunctionStillAnswersFalseForAnUnknownId()
  luaunit.assertFalse(SkynetIADSUtils.removeFunction(999999))
  luaunit.assertFalse(SkynetIADSUtils.removeFunction(nil))
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------
os.exit(luaunit.LuaUnit.run())
