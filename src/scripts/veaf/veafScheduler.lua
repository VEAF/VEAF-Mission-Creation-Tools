------------------------------------------------------------------
-- VEAF scheduler for DCS World
-- By Zip (2026)
--
-- Features:
-- ---------
-- * Schedule a function on DCS's own timer, with the conveniences MiST added on top of it:
--   repetition, a stop time, a table of arguments, and a failing task that does not take the
--   others down with it
--
-- The DCS API is `timer.scheduleFunction(f, arg, time)`: one argument, no repetition, no stop
-- time, and an error inside the call simply ends it. MiST answered that with a scheduler of its
-- own — a task list walked by a main loop re-armed every 0.01 s. This module keeps MiST's
-- signature and drops the loop: every task is one native scheduled call, re-armed by returning
-- the next time. When nothing is due, nothing runs.
------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafScheduler = {}

--- Identifier. All output in the log will start with this.
veafScheduler.Id = "SCHEDULER"

-- trace level, specific to this module (uncomment for debugging)
--veafScheduler.LogLevel = "trace"

--- Smallest delay this module will hand to the native timer, in seconds.
---
--- MiST's loop ran every 0.01 s and executed anything whose time had come **or gone**, so a task
--- asked for "now" — or for a moment already past — was simply run on the next tick. One native
--- `timer.scheduleFunction` per task does not offer that guarantee, and callers rely on it: with
--- the default single shell, `veafSpawn.spawnSmoke` asks for exactly `timer.getTime()`, and
--- `veafSpawnEffects` asks for `timer.getTime() - 1` for the burst under a multi-shell plume. This
--- is the floor that keeps them equivalent to what MiST did.
veafScheduler.MinimumDelay = 0.01

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.loggers.new(veafScheduler.Id, veafScheduler.LogLevel)

--- Scheduled tasks, keyed by the id handed to the caller:
--- `{ f = <function>, vars = <table>, argCount = <number>, rep = <seconds|nil>, st = <time|nil>, nativeId = <number> }`.
veafScheduler.tasks = {}

--- Last id handed out. Ids are ours, not the native timer's, so a task can be re-armed without
--- the caller's id changing under it.
veafScheduler.lastId = 0

--- Number of positional slots in an argument table, holes included.
---
--- `{ position, nil, nil, color }` is a real call in `veafSpawnObjects`, and `#` is undefined on a
--- table with holes — it may answer 1 and silently drop the colour. Lua 5.1, which DCS runs, has
--- `table.maxn` for exactly this; it was removed in 5.2, so a newer interpreter falls back to a
--- scan of the numeric keys.
---
--- @param vars table the argument table
--- @return number the highest positional index in use, 0 for an empty table
local function argCount(vars)
  if table.maxn then
    return table.maxn(vars)
  end
  local count = 0
  for key in pairs(vars) do
    if type(key) == "number" and key > count then
      count = key
    end
  end
  return count
end

--- Run one task, then tell the native timer whether to come back.
---
--- Called by DCS as `fn(arg, time)`, so the argument is the task id and `time` is the model time
--- the call was scheduled for.
---
--- @param id number the task id
--- @return number|nil the next model time to run at, or nil to stop
local function runTask(id)
  local task = veafScheduler.tasks[id]
  if not task then
    return nil -- removed while it was pending
  end

  -- A stop time ends the task *before* the run, as MiST's own loop did: `st` is the time from
  -- which it no longer runs, not the time of its last run.
  if task.st and timer.getTime() >= task.st then
    veafScheduler.tasks[id] = nil
    return nil
  end

  if not task.rep then
    -- A one-shot task is gone before it runs, so removing it from inside its own body answers
    -- false rather than pretending there was still something to cancel.
    veafScheduler.tasks[id] = nil
  end

  local ok, err = pcall(task.f, unpack(task.vars, 1, task.argCount))
  if not ok then
    -- Concatenated rather than formatted: `veaf.Logger:error` reads Lua 5.1's `arg` for its
    -- varargs, so a `%s` here would reach the log unsubstituted on any newer interpreter, and
    -- the one thing this line exists to carry is the cause.
    veaf.loggers.get(veafScheduler.Id):error("error in scheduled function: " .. tostring(err))
  end

  if not task.rep then
    return nil
  end
  if veafScheduler.tasks[id] ~= task then
    return nil -- the task removed itself, or was replaced, while it ran
  end
  return timer.getTime() + task.rep
end

--- Schedule a function, MiST-style.
---
--- @param f function the function to call
--- @param vars table|nil its arguments, unpacked positionally into the call
--- @param t number model time of the first run; a time already reached is pushed to the next tick
---   (`veafScheduler.MinimumDelay`) rather than handed to the native timer as-is
--- @param rep number|nil seconds between runs; nil for a one-shot task
--- @param st number|nil model time from which a repeating task no longer runs
--- @return number the id to hand to `veafScheduler.removeFunction`
function veafScheduler.scheduleFunction(f, vars, t, rep, st)
  assert(type(f) == "function", "variable 1, expected function, got " .. type(f))
  assert(type(vars) == "table" or vars == nil, "variable 2, expected table or nil, got " .. type(vars))
  assert(type(t) == "number", "variable 3, expected number, got " .. type(t))
  assert(type(rep) == "number" or rep == nil, "variable 4, expected number or nil, got " .. type(rep))
  assert(type(st) == "number" or st == nil, "variable 5, expected number or nil, got " .. type(st))

  vars = vars or {}
  veafScheduler.lastId = veafScheduler.lastId + 1
  local id = veafScheduler.lastId
  local task = { f = f, vars = vars, argCount = argCount(vars), rep = rep, st = st }
  veafScheduler.tasks[id] = task
  -- A task due now, or overdue, is armed for the next tick instead — see `MinimumDelay`. Asking
  -- the native timer for a moment that has already passed is not something to rely on, and a
  -- dropped task leaves no trace at all: `spawnSmoke` reported success and no smoke ever appeared.
  local earliest = timer.getTime() + veafScheduler.MinimumDelay
  if t < earliest then
    veaf.loggers.get(veafScheduler.Id):trace("task %s asked for %s, armed at %s", veaf.p(id), veaf.p(t), veaf.p(earliest))
    t = earliest
  end
  task.nativeId = timer.scheduleFunction(runTask, id, t)
  veaf.loggers.get(veafScheduler.Id):trace("scheduled task %s at %s (rep=%s, st=%s)", veaf.p(id), veaf.p(t), veaf.p(rep), veaf.p(st))
  return id
end

--- Cancel a scheduled function.
---
--- @param id number|nil the id returned by `veafScheduler.scheduleFunction`
--- @return boolean true if a pending task was cancelled, false if the id is unknown, already run
---   or already stopped
function veafScheduler.removeFunction(id)
  local task = veafScheduler.tasks[id]
  if not task then
    return false
  end
  veafScheduler.tasks[id] = nil
  if task.nativeId then
    timer.removeFunction(task.nativeId)
  end
  veaf.loggers.get(veafScheduler.Id):trace("removed task %s", veaf.p(id))
  return true
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Framework façades. Callers use `veaf.*` and never name the implementation, so swapping it stays
-- one file's problem — same contract as the `veaf.mist.*` database accessors above them.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- See `veafScheduler.scheduleFunction`.
function veaf.scheduleFunction(f, vars, t, rep, st)
  return veafScheduler.scheduleFunction(f, vars, t, rep, st)
end

--- See `veafScheduler.removeFunction`.
function veaf.removeFunction(id)
  return veafScheduler.removeFunction(id)
end

function veafScheduler.initialize()
  veaf.loggers.get(veafScheduler.Id):info("Initializing module")
end

veaf.loggers.get(veafScheduler.Id):info(veaf.loggers.get(veafScheduler.Id):getVersionInfo())
