--- Unit tests for veafScheduler.lua — the native-timer adapter that replaces veaf.scheduleFunction.
---
--- Run:  lua test/lua/test_veafScheduler.lua
---
--- Covers:
---   - A one-shot task runs once, at its time, with its arguments
---   - A task scheduled in the future does not run early
---   - Arguments are unpacked positionally, holes included ({ pos, nil, nil, color })
---   - A repeating task runs again every `rep` seconds
---   - `st` stops a repeating task, and the run at or past the stop time does not happen
---   - Removal before the first run cancels the task, and the native timer is told
---   - Removing an unknown or already-run id returns false and raises nothing
---   - A task that raises does not break the chain, and the error is logged
---   - A repeating task that raises still repeats
---   - A task that removes itself from inside its own body does not repeat
---   - Ids are distinct

-- ---------------------------------------------------------------------------
-- Bootstrap: load the test framework, DCS mocks, and modules under test.
-- ---------------------------------------------------------------------------
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua") -- exported as global for test methods
dofile(_base .. "/dcs_mocks.lua")
dofile(_base .. "/../../src/scripts/veaf/veaf.lua")
dofile(_base .. "/../../src/scripts/veaf/veafScheduler.lua")
dofile(_base .. "/../../src/scripts/veaf/veafMath.lua")
dofile(_base .. "/../../src/scripts/veaf/veafGeo.lua")
dofile(_base .. "/../../src/scripts/veaf/veafMissionDb.lua")

TestVeafScheduler = {}

function TestVeafScheduler:setUp()
  dcs_mocks.reset()
  veafScheduler.tasks = {}
end

-- ---------------------------------------------------------------------------
-- One-shot tasks
-- ---------------------------------------------------------------------------

function TestVeafScheduler:test_oneShotRunsOnceAtItsTime()
  local calls = {}
  veaf.scheduleFunction(function(a, b)
    table.insert(calls, { a, b })
  end, { "x", 42 }, 10)

  luaunit.assertEquals(#calls, 0) -- nothing runs at schedule time

  dcs_mocks.runScheduled(20)
  luaunit.assertEquals(#calls, 1)
  luaunit.assertEquals(calls[1][1], "x")
  luaunit.assertEquals(calls[1][2], 42)

  dcs_mocks.runScheduled(100) -- and never again
  luaunit.assertEquals(#calls, 1)
end

function TestVeafScheduler:test_futureTaskDoesNotRunEarly()
  local ran = false
  veaf.scheduleFunction(function()
    ran = true
  end, {}, 100)

  dcs_mocks.runScheduled(99)
  luaunit.assertFalse(ran)

  dcs_mocks.runScheduled(100)
  luaunit.assertTrue(ran)
end

function TestVeafScheduler:test_taskSeesTheMissionTimeOfItsOwnRun()
  local seen
  veaf.scheduleFunction(function()
    seen = timer.getTime()
  end, {}, 30)

  dcs_mocks.runScheduled(80)
  luaunit.assertEquals(seen, 30)
end

function TestVeafScheduler:test_noVarsIsAllowed()
  local ran = false
  veaf.scheduleFunction(function()
    ran = true
  end, nil, 5)

  dcs_mocks.runScheduled(5)
  luaunit.assertTrue(ran)
end

--- `{ pos, nil, nil, color }` is a real argument list in veafSpawnObjects: `#` is undefined on a
--- table with holes, so an adapter that uses it drops the trailing arguments silently.
function TestVeafScheduler:test_argumentsWithHolesAreUnpackedInFull()
  local got = { n = -1 }
  veaf.scheduleFunction(function(a, b, c, d)
    got = { a, b, c, d, n = select("#", a, b, c, d) }
  end, { "position", nil, nil, "red" }, 1)

  dcs_mocks.runScheduled(1)
  luaunit.assertEquals(got.n, 4)
  luaunit.assertEquals(got[1], "position")
  luaunit.assertNil(got[2])
  luaunit.assertNil(got[3])
  luaunit.assertEquals(got[4], "red")
end

-- ---------------------------------------------------------------------------
-- Repetition and stop time
-- ---------------------------------------------------------------------------

function TestVeafScheduler:test_repeatingTaskRunsEveryRepSeconds()
  local count = 0
  veaf.scheduleFunction(function()
    count = count + 1
  end, {}, 10, 5)

  dcs_mocks.runScheduled(10)
  luaunit.assertEquals(count, 1)

  dcs_mocks.runScheduled(25) -- 15 and 20 and 25
  luaunit.assertEquals(count, 4)
end

function TestVeafScheduler:test_stopTimeEndsTheRepetition()
  local count = 0
  veaf.scheduleFunction(function()
    count = count + 1
  end, {}, 10, 5, 22)

  dcs_mocks.runScheduled(100)
  -- 10, 15, 20 run; the 25 pass is at or past the stop time and does not
  luaunit.assertEquals(count, 3)
end

--- MiST drops a repeating task whose stop time has passed **without executing it**, and the
--- boundary is `st <= now`, not `st < now`.
function TestVeafScheduler:test_stopTimeIsInclusive()
  local count = 0
  veaf.scheduleFunction(function()
    count = count + 1
  end, {}, 10, 5, 15)

  dcs_mocks.runScheduled(100)
  luaunit.assertEquals(count, 1) -- 10 runs, 15 is the stop time itself
end

function TestVeafScheduler:test_stopTimeIsForgottenOnceTheTaskIsDone()
  veaf.scheduleFunction(function() end, {}, 10, 5, 22)
  dcs_mocks.runScheduled(100)
  luaunit.assertEquals(next(veafScheduler.tasks), nil) -- nothing left behind
end

-- ---------------------------------------------------------------------------
-- Removal
-- ---------------------------------------------------------------------------

function TestVeafScheduler:test_removeBeforeFirstRunCancelsTheTask()
  local ran = false
  local id = veaf.scheduleFunction(function()
    ran = true
  end, {}, 10)

  luaunit.assertTrue(veaf.removeFunction(id))
  dcs_mocks.runScheduled(100)
  luaunit.assertFalse(ran)
end

function TestVeafScheduler:test_removeTellsTheNativeTimer()
  local id = veaf.scheduleFunction(function() end, {}, 10)
  luaunit.assertNotNil(next(dcs_mocks.scheduledTasks)) -- the native timer holds an entry

  veaf.removeFunction(id)
  luaunit.assertEquals(next(dcs_mocks.scheduledTasks), nil) -- the native entry is gone too
end

function TestVeafScheduler:test_removeStopsARepeatingTask()
  local count = 0
  local id = veaf.scheduleFunction(function()
    count = count + 1
  end, {}, 10, 5)

  dcs_mocks.runScheduled(15)
  luaunit.assertEquals(count, 2)

  veaf.removeFunction(id)
  dcs_mocks.runScheduled(100)
  luaunit.assertEquals(count, 2)
end

function TestVeafScheduler:test_removeUnknownIdReturnsFalse()
  luaunit.assertFalse(veaf.removeFunction(4242))
  luaunit.assertFalse(veaf.removeFunction(nil))
end

function TestVeafScheduler:test_removeAlreadyRunTaskReturnsFalse()
  local id = veaf.scheduleFunction(function() end, {}, 10)
  dcs_mocks.runScheduled(10)
  luaunit.assertFalse(veaf.removeFunction(id))
end

function TestVeafScheduler:test_idsAreDistinct()
  local a = veaf.scheduleFunction(function() end, {}, 10)
  local b = veaf.scheduleFunction(function() end, {}, 10)
  luaunit.assertNotEquals(a, b)
end

-- ---------------------------------------------------------------------------
-- A failing task
-- ---------------------------------------------------------------------------

function TestVeafScheduler:test_aTaskThatRaisesDoesNotBreakTheChain()
  local secondRan = false
  veaf.scheduleFunction(function()
    error("boom")
  end, {}, 10)
  veaf.scheduleFunction(function()
    secondRan = true
  end, {}, 11)

  dcs_mocks.runScheduled(20)
  luaunit.assertTrue(secondRan)
end

function TestVeafScheduler:test_aTaskThatRaisesIsLogged()
  veaf.scheduleFunction(function()
    error("boom")
  end, {}, 10)
  dcs_mocks.runScheduled(10)

  local found = false
  for _, entry in ipairs(dcs_mocks.logs) do
    if entry.text:find("boom") then
      found = true
    end
  end
  luaunit.assertTrue(found)
end

function TestVeafScheduler:test_aRepeatingTaskThatRaisesStillRepeats()
  local count = 0
  veaf.scheduleFunction(function()
    count = count + 1
    error("boom")
  end, {}, 10, 5)

  dcs_mocks.runScheduled(20)
  luaunit.assertEquals(count, 3) -- 10, 15, 20
end

-- ---------------------------------------------------------------------------
-- Self-removal from inside the task
-- ---------------------------------------------------------------------------

function TestVeafScheduler:test_aTaskThatRemovesItselfDoesNotRepeat()
  local count = 0
  local id
  id = veaf.scheduleFunction(function()
    count = count + 1
    veaf.removeFunction(id)
  end, {}, 10, 5)

  dcs_mocks.runScheduled(100)
  luaunit.assertEquals(count, 1)
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------
os.exit(luaunit.LuaUnit.run())
