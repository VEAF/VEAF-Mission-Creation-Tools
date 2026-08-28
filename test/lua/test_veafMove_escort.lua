--- Tests for veafMove's escort-task recovery — FIX-ESCORT-RESPAWN-TASK ticket 01.
--
-- The defect: DCS invalidates an `Escort` task's `groupId` the moment the escorted group is
-- recreated — by a teleport, or by a respawn. `veafMove.teleportEscort` already repaired it for the
-- teleport path; `veafAssets.respawn` did not, so a respawned tanker's escort flew its route and
-- landed after about ten minutes (measured in game 2026-08-18, issue #107).
--
-- What is asserted here is the shared recovery: the lookup that finds the task, and the reassignment
-- that writes the *current* group id into it. The in-game behaviour itself is not testable — the
-- mocks do not model what DCS does with a stale id — which is why the lot also carries an in-game
-- check.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafMove.lua")

-- ---------------------------------------------------------------------------
-- Helpers: a mission whose groups carry a route, and an Escort task in it
-- ---------------------------------------------------------------------------

--- Build the group data DCS keeps in `env.mission`, with an Escort task on the last waypoint.
-- @param groupId number  the id `veaf.getGroupData` matches on
-- @param escortedId number|nil  the (stale) id the Escort task points at; nil = no Escort task
local function _groupData(groupId, escortedId)
  local tasks = {}
  if escortedId then
    tasks[1] = {
      enabled = true,
      id = "Escort",
      params = { groupId = escortedId, pos = { x = -100, y = 0, z = 200 } },
    }
  end
  return {
    groupId = groupId,
    name = "whatever",
    route = {
      points = {
        { x = 0, y = 0, alt = 6000, speed = 200 },
        { x = 1000, y = 1000, alt = 6000, speed = 200, task = { params = { tasks = tasks } } },
      },
    },
  }
end

--- Put `groups` (name -> group data) into the mocked mission and MiST's ME database.
local function _mission(groups)
  local planes = {}
  local byName = {}
  for name, data in pairs(groups) do
    table.insert(planes, data)
    byName[name] = { groupId = data.groupId }
  end
  env.mission.coalition.blue.country = { [1] = { plane = { group = planes } } }
  mist.DBs.MEgroupsByName = byName
end

--- Make `veaf.scheduleFunction` run its argument at once, so scheduled work is observable.
local function _runScheduledImmediately()
  veaf.scheduleFunction = function(fn, args, _when)
    fn(unpack(args))
  end
end

-- ---------------------------------------------------------------------------
-- TestVeafMoveEscortConvention
-- ---------------------------------------------------------------------------
TestVeafMoveEscortConvention = {}

function TestVeafMoveEscortConvention:test_the_suffix_is_a_named_constant()
  luaunit.assertEquals(veafMove.EscortGroupNameSuffix, " escort")
end

-- ---------------------------------------------------------------------------
-- TestVeafMoveFindEscortTask
-- ---------------------------------------------------------------------------
TestVeafMoveFindEscortTask = {}

function TestVeafMoveFindEscortTask:setUp()
  dcs_mocks.reset()
  self._scheduleFunction = veaf.scheduleFunction
end

function TestVeafMoveFindEscortTask:tearDown()
  veaf.scheduleFunction = self._scheduleFunction
end

function TestVeafMoveFindEscortTask:test_the_escort_task_is_found_on_the_last_waypoint()
  _mission({ ["Arco escort"] = _groupData(20, 11) })

  local escortData, escortTask = veafMove.findEscortTask("Arco escort")

  luaunit.assertNotNil(escortData)
  luaunit.assertNotNil(escortTask)
  luaunit.assertEquals(escortTask.id, "Escort")
  luaunit.assertEquals(escortTask.params.groupId, 11, "the stale id must be returned as-is")
end

function TestVeafMoveFindEscortTask:test_the_route_points_are_returned_too()
  -- So no caller re-walks the route to find them: one traversal, one thing to keep in step.
  _mission({ ["Arco escort"] = _groupData(20, 11) })

  local _, _, points = veafMove.findEscortTask("Arco escort")

  luaunit.assertNotNil(points, "the points walked to find the task must be handed back")
  luaunit.assertEquals(#points, 2)
end

function TestVeafMoveFindEscortTask:test_a_group_with_no_escort_task_returns_nil()
  _mission({ ["Arco escort"] = _groupData(20, nil) })

  luaunit.assertNil(veafMove.findEscortTask("Arco escort"))
end

function TestVeafMoveFindEscortTask:test_an_unknown_group_returns_nil()
  _mission({})

  luaunit.assertNil(veafMove.findEscortTask("Arco escort"))
end

function TestVeafMoveFindEscortTask:test_a_group_with_no_route_returns_nil()
  _mission({ ["Arco escort"] = { groupId = 20, name = "whatever" } })

  luaunit.assertNil(veafMove.findEscortTask("Arco escort"))
end

function TestVeafMoveFindEscortTask:test_a_disabled_escort_task_is_not_returned()
  local data = _groupData(20, 11)
  data.route.points[2].task.params.tasks[1].enabled = false
  _mission({ ["Arco escort"] = data })

  luaunit.assertNil(veafMove.findEscortTask("Arco escort"))
end

-- ---------------------------------------------------------------------------
-- TestVeafMoveReestablishEscortTask
-- ---------------------------------------------------------------------------
TestVeafMoveReestablishEscortTask = {}

function TestVeafMoveReestablishEscortTask:setUp()
  dcs_mocks.reset()
  self._scheduleFunction = veaf.scheduleFunction
  _runScheduledImmediately()
end

function TestVeafMoveReestablishEscortTask:tearDown()
  veaf.scheduleFunction = self._scheduleFunction
end

--- Register the escorted group (with a fresh id) and its escort.
-- The escort's controller is the shared mock, which records setTask calls into dcs_mocks.tasksSet.
function TestVeafMoveReestablishEscortTask:_pair(freshEscortedId)
  dcs_mocks.addGroup("Arco", { _id = freshEscortedId })
  dcs_mocks.addGroup("Arco escort", { _id = 20 })
  _mission({ ["Arco escort"] = _groupData(20, 11) })
end

--- The Escort tasks of whatever mission was last pushed to the escort's controller.
local function _tasksPushedToEscort()
  for i = #dcs_mocks.tasksSet, 1, -1 do
    local entry = dcs_mocks.tasksSet[i]
    if entry.group == "Arco escort" then
      return entry.task.params.route.points[2].task.params.tasks
    end
  end
  return nil
end

function TestVeafMoveReestablishEscortTask:test_the_current_group_id_is_written_into_the_task()
  self:_pair(99)

  luaunit.assertTrue(veafMove.reestablishEscortTask("Arco"))

  local tasks = _tasksPushedToEscort()
  luaunit.assertNotNil(tasks, "the escort's mission was not replaced")
  luaunit.assertEquals(tasks[1].params.groupId, 99, "the Escort task still points at the dead id")
end

function TestVeafMoveReestablishEscortTask:test_a_group_with_no_escort_is_not_an_error()
  dcs_mocks.addGroup("Arco", { _id = 99 })
  _mission({})

  luaunit.assertFalse(veafMove.reestablishEscortTask("Arco"))
end

function TestVeafMoveReestablishEscortTask:test_an_escort_group_that_does_not_exist_is_not_an_error()
  -- The name follows the convention but no such group is in the mission: nothing to repair.
  dcs_mocks.addGroup("Arco", { _id = 99 })
  _mission({ ["Arco escort"] = _groupData(20, 11) })
  dcs_mocks.removeGroup("Arco escort")

  luaunit.assertFalse(veafMove.reestablishEscortTask("Arco"))
end

function TestVeafMoveReestablishEscortTask:test_the_escorted_group_must_exist()
  -- Nothing to point the task at: refuse rather than write a nil id into the task.
  self:_pair(99)
  dcs_mocks.removeGroup("Arco")

  veafMove.reestablishEscortTask("Arco")

  luaunit.assertNil(_tasksPushedToEscort(), "a mission was pushed for a group that no longer exists")
end

function TestVeafMoveReestablishEscortTask:test_the_id_is_read_after_the_delay_not_before()
  -- The whole point of scheduling: `Group.getID` must be read once the respawn has happened, or it
  -- returns the id that just died. The scheduled call is captured rather than run, the group's id is
  -- then changed, and only then is the call released.
  self:_pair(1)
  local pending = nil
  -- Only the first scheduled call is held: the repair itself schedules again through
  -- replaceMission, and capturing that one too would hide the very result being asserted.
  veaf.scheduleFunction = function(fn, args, _when)
    if pending == nil then
      pending = function()
        fn(unpack(args))
      end
    else
      fn(unpack(args))
    end
  end

  veafMove.reestablishEscortTask("Arco")
  luaunit.assertNil(_tasksPushedToEscort(), "the work must not run before its delay")

  dcs_mocks.removeGroup("Arco")
  dcs_mocks.addGroup("Arco", { _id = 4242 }) -- the respawn lands, with a new id
  pending()

  local tasks = _tasksPushedToEscort()
  luaunit.assertNotNil(tasks)
  luaunit.assertEquals(tasks[1].params.groupId, 4242, "the id was read before the respawn")
end

os.exit(luaunit.LuaUnit.run())
