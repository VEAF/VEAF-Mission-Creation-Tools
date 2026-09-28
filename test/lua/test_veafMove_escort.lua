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
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafMissionDb.lua")
dofile(src .. "/veafDcsSpawner.lua")
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
    route = {
      points = {
        { x = 0, y = 0, alt = 6000, speed = 200 },
        { x = 1000, y = 1000, alt = 6000, speed = 200, task = { params = { tasks = tasks } } },
      },
    },
  }
end

--- Build group data whose Escort task sits on an arbitrary waypoint, not necessarily the last.
--- This is the shape a mission maker actually produces: DCS puts no constraint on which waypoint
--- carries the task, and the repository's own demo mission puts it on waypoint 2 of 3.
-- @param groupId number  the id `veaf.getGroupData` matches on
-- @param escortedId number  the (stale) id the Escort task points at
-- @param taskIndex number  the 1-based waypoint carrying the Escort task
-- @param pointCount number  how many waypoints the route has
local function _groupDataWithTaskAt(groupId, escortedId, taskIndex, pointCount)
  local points = {}
  for index = 1, pointCount do
    points[index] = { x = index * 1000, y = index * 1000, alt = 6000, speed = 200 }
    if index == taskIndex then
      points[index].task = {
        params = {
          tasks = {
            [1] = {
              enabled = true,
              id = "Escort",
              params = { groupId = escortedId, pos = { x = -100, y = 0, z = 200 } },
            },
          },
        },
      }
    end
  end
  return { groupId = groupId, route = { points = points } }
end

--- Put `groups` (name -> group data) into the mocked mission, and index it the way the mission
--- database does at startup. The group's name lives in the mission data itself, which is where the
--- snapshot reads it — MiST kept a separate name-to-id table, and this helper used to fill that.
local function _mission(groups)
  local planes = {}
  for name, data in pairs(groups) do
    data.name = name
    table.insert(planes, data)
  end
  -- The country is named and numbered because a respawn needs it: `veafDcsSpawner.addGroup` refuses
  -- a group whose country it cannot resolve, and the snapshot takes the id from here.
  env.mission.coalition.blue.country = { [1] = { name = "USA", id = country.id.USA, plane = { group = planes } } }
  veafMissionDb.buildSnapshot()
end

--- Give a group data table the single unit a respawn needs.
--- `VeafGroupSpawn` refuses to spawn a group with no units, and refuses again when a unit has no
--- position, so a group meant to be put back needs both — the escort-task lookups above do not.
-- @param data table  group data from one of the builders above
-- @param unitName string  the unit's name, which DCS wants unique
local function _withUnits(data, unitName)
  data.units = { { name = unitName, unitId = 1, type = "F-15C", x = 1000, y = 2000, alt = 6000 } }
  return data
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

function TestVeafMoveFindEscortTask:test_the_escort_task_is_found_on_an_intermediate_waypoint()
  -- The shape the demo mission ships: three waypoints, the Escort task on the second. Searching the
  -- last waypoint alone found nothing here, so the repair reported "carries no Escort task" and gave
  -- up -- measured in game on 2026-08-28 on all three of the demo mission's escorts.
  _mission({ ["Arco escort"] = _groupDataWithTaskAt(20, 11, 2, 3) })

  local escortData, escortTask = veafMove.findEscortTask("Arco escort")

  luaunit.assertNotNil(escortData)
  luaunit.assertNotNil(escortTask, "an Escort task on waypoint 2 of 3 must be found")
  luaunit.assertEquals(escortTask.params.groupId, 11)
end

function TestVeafMoveFindEscortTask:test_the_escort_task_is_found_on_the_first_waypoint()
  _mission({ ["Arco escort"] = _groupDataWithTaskAt(20, 11, 1, 3) })

  local _, escortTask = veafMove.findEscortTask("Arco escort")

  luaunit.assertNotNil(escortTask, "an Escort task on the first waypoint must be found")
end

function TestVeafMoveFindEscortTask:test_the_last_waypoint_still_wins_when_two_carry_a_task()
  -- The search walks backwards, so a mission that already put its task on the last waypoint keeps
  -- resolving to exactly the same task as before this became a full-route search.
  local data = _groupDataWithTaskAt(20, 11, 3, 3)
  data.route.points[2].task = {
    params = { tasks = { [1] = { enabled = true, id = "Escort", params = { groupId = 99 } } } },
  }
  _mission({ ["Arco escort"] = data })

  local _, escortTask = veafMove.findEscortTask("Arco escort")

  luaunit.assertEquals(escortTask.params.groupId, 11, "the last waypoint's task must be preferred")
end

function TestVeafMoveFindEscortTask:test_a_disabled_task_on_a_late_waypoint_does_not_mask_a_valid_earlier_one()
  -- Bailing out at the first waypoint that carries *tasks* would stop here and report nothing.
  local data = _groupDataWithTaskAt(20, 11, 1, 3)
  data.route.points[3].task = {
    params = { tasks = { [1] = { enabled = false, id = "Escort", params = { groupId = 99 } } } },
  }
  _mission({ ["Arco escort"] = data })

  local _, escortTask = veafMove.findEscortTask("Arco escort")

  luaunit.assertNotNil(escortTask, "the disabled task must not hide the enabled one earlier in the route")
  luaunit.assertEquals(escortTask.params.groupId, 11)
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

-- ============================================================================
-- FIX-ESCORT-RESPAWN-DISTANCE — the escort is put back with its charge
--
-- Repairing the Escort task is not enough. A respawn puts the asset back where the Mission Editor
-- drew it while its escort keeps flying wherever the elapsed mission time has taken it: measured in
-- game on 2026-08-28, ~80 km apart minutes after a respawn, against the Escort task's own
-- `engagementDistMax` of 60 000 m read off the live task. The repaired task therefore pointed the
-- escort at a charge outside its own engagement distance.
--
-- David's call, 2026-08-28: the escort respawns with its charge. Both halves are needed — putting
-- the escort back does not restore the task, because what breaks the task is the *escorted* group's
-- id changing.
-- ============================================================================
TestVeafMoveRespawnEscort = {}

function TestVeafMoveRespawnEscort:setUp()
  dcs_mocks.reset()
end

function TestVeafMoveRespawnEscort:tearDown()
  dcs_mocks.reset()
end

--- The names of the groups handed to `coalition.addGroup`, in submission order.
local function _respawnedNames()
  local names = {}
  for _, entry in ipairs(dcs_mocks.groupsAdded) do
    table.insert(names, entry.group.name)
  end
  return names
end

--- A tanker and its escort in the mission, both spawnable; `alive` also registers the escort as a
--- live group, which is what `Group.getByName` answers.
function TestVeafMoveRespawnEscort:_pair(alive)
  _mission({
    ["Arco"] = _withUnits(_groupData(11, nil), "Arco-1"),
    ["Arco escort"] = _withUnits(_groupData(20, 11), "Arco escort-1"),
  })
  dcs_mocks.addGroup("Arco", { _id = 11 })
  if alive then
    dcs_mocks.addGroup("Arco escort", { _id = 20 })
  end
end

function TestVeafMoveRespawnEscort:test_the_escort_is_put_back()
  self:_pair(true)

  luaunit.assertTrue(veafMove.respawnEscort("Arco"))

  luaunit.assertEquals(_respawnedNames(), { "Arco escort" }, "the escort must actually reach DCS")
end

function TestVeafMoveRespawnEscort:test_the_escorted_group_is_not_respawned_here()
  -- The asset is the caller's business, and it has to come back *first*: this function does one thing.
  self:_pair(true)

  veafMove.respawnEscort("Arco")

  luaunit.assertEquals(_respawnedNames(), { "Arco escort" })
end

function TestVeafMoveRespawnEscort:test_the_escort_comes_back_with_its_escort_task()
  -- The route is the editor's, Escort task included, so the repair that follows has a task to fix.
  -- A bare group put back without its route would leave nothing for `reestablishEscortTask` to reach.
  self:_pair(true)

  veafMove.respawnEscort("Arco")

  local submitted = dcs_mocks.groupsAdded[1].group
  luaunit.assertNotNil(submitted.route, "the escort must be put back with a route")
  local tasks = submitted.route.points[2].task.params.tasks
  luaunit.assertEquals(tasks[1].id, "Escort")
end

function TestVeafMoveRespawnEscort:test_a_group_with_no_escort_respawns_nothing()
  _mission({ ["Arco"] = _withUnits(_groupData(11, nil), "Arco-1") })
  dcs_mocks.addGroup("Arco", { _id = 11 })

  luaunit.assertFalse(veafMove.respawnEscort("Arco"))

  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0, "an asset with no escort must be left alone")
end

function TestVeafMoveRespawnEscort:test_an_escort_that_is_no_longer_flying_is_still_put_back()
  -- The guard is the **mission record**, not a live group. An escort that was shot down is precisely
  -- what a respawn is for, and `Group.getByName` answers nil for it -- which is also why this call
  -- has to come before `reestablishEscortTask`, whose own guard is the live group.
  self:_pair(false)

  luaunit.assertTrue(veafMove.respawnEscort("Arco"))

  luaunit.assertEquals(_respawnedNames(), { "Arco escort" })
end

-- ============================================================================
-- FIX-UNGUARDED-DCS-LOOKUPS — the lookup taken *after* the teleport
--
-- `teleportEscort` checks the escort group exists, computes its new waypoints, teleports it, and then
-- looks it up again — because a teleport destroys the group and recreates it, so the object it held is
-- stale. That second lookup was never checked, and its answer goes straight to `replaceMission`, whose
-- first statement is `unitGroup:getName()`. The guard above tested a different object entirely: the
-- group as it was before the teleport.
--
-- The same shape sits on the other two teleport paths, `moveTanker` and `moveAfac`, and all three are
-- fixed together. Here the teleport is stubbed to leave nothing behind, which is what a teleport that
-- fails to recreate its group looks like from this side.
-- ============================================================================
TestVeafMoveEscortLostByTheTeleport = {}

function TestVeafMoveEscortLostByTheTeleport:setUp()
  dcs_mocks.reset()
  self._savedGroupSpawn = VeafGroupSpawn
  self._savedSchedule = veaf.scheduleFunction
  -- `replaceMission` does its work in a scheduled call, and that is where `unitGroup:getName()` sits.
  -- Left on the mock scheduler it never runs, and the test would pass without the guard by never
  -- reaching the defect at all.
  _runScheduledImmediately()
  self._logger = veaf.loggers.get(veafMove.Id)
  self._originalWarn = self._logger.warn
  self.warned = {}
  local warned = self.warned
  self._logger.warn = function(_, text, ...)
    table.insert(warned, tostring(text))
  end

  -- veafSpawnCore is not loaded by this suite; a fluent stub is all `teleportEscort` uses of it. The
  -- teleport removes the group from the registry and puts nothing back, so the lookup that follows it
  -- comes back empty.
  self.teleported = false
  local test = self
  VeafGroupSpawn = {
    new = function(self_)
      local spawn
      spawn = {
        forGroup = function(_, name)
          spawn._name = name
          return spawn
        end,
        at = function()
          return spawn
        end,
        teleport = function()
          test.teleported = true
          dcs_mocks.removeGroup(spawn._name)
          return nil
        end,
      }
      return spawn
    end,
  }

  -- A tanker and its escort, both alive, the escort carrying an Escort task on a two-point route.
  dcs_mocks.addGroup("Arco", { _id = 11 })
  dcs_mocks.addGroup("Arco escort", { _id = 20 })
  _mission({ ["Arco escort"] = _groupData(20, 11) })
end

function TestVeafMoveEscortLostByTheTeleport:tearDown()
  self._logger.warn = self._originalWarn
  VeafGroupSpawn = self._savedGroupSpawn
  veaf.scheduleFunction = self._savedSchedule
  dcs_mocks.reset()
end

function TestVeafMoveEscortLostByTheTeleport:_move()
  return pcall(
    veafMove.teleportEscort,
    "Arco",
    { x = 5000, y = 5000, alt = 6000, speed = 200 },
    { x = 1000, y = 1000, alt = 6000, speed = 200 }
  )
end

-- The defect itself: without the guard, the nil goes to `replaceMission` and the scheduled call dies.
-- (It dies on `missionData` rather than on the group, because a nil first element leaves a hole in the
-- argument table `veaf.scheduleFunction` unpacks — which only makes the failure harder to read.)
function TestVeafMoveEscortLostByTheTeleport:test_an_escort_lost_by_its_teleport_does_not_raise()
  local ok, err = self:_move()
  luaunit.assertTrue(ok, string.format("teleportEscort raised when the escort did not come back: %s", tostring(err)))
end

-- It must have got as far as the teleport, or the test proves nothing about what follows it.
function TestVeafMoveEscortLostByTheTeleport:test_the_teleport_did_happen()
  self:_move()
  luaunit.assertTrue(self.teleported, "the case under test is the lookup *after* the teleport")
end

-- No mission is pushed to a group that is not there.
function TestVeafMoveEscortLostByTheTeleport:test_no_task_is_pushed()
  self:_move()
  luaunit.assertEquals(#dcs_mocks.tasksSet, 0)
end

function TestVeafMoveEscortLostByTheTeleport:test_the_warning_names_the_escort()
  self:_move()
  local named = false
  for _, warning in ipairs(self.warned) do
    if warning:find("Arco escort", 1, true) then
      named = true
    end
  end
  luaunit.assertTrue(named, "the warning must name the escort group that did not come back")
end

-- ============================================================================
-- FIX-TELEPORT-ESCORT-WAYPOINT — the rewrite follows the waypoint that carries the task
--
-- `teleportEscort` rewrites two waypoints: an approach, half-way between the teleport point and the
-- escorted group's next waypoint, and the point where the Escort task takes over, on that next
-- waypoint. It used to rewrite the last two, which is right only when the task is on the last one —
-- the demo mission puts it on waypoint 2 of 3, so the approach landed on the task's waypoint and the
-- task point on one that carries nothing.
--
-- The assertions are relative, so they do not depend on the escort's formation offset: whatever the
-- offset, the task point sits (M - T) / 2 past the approach, and the approach sits exactly one offset
-- length from the midpoint.
-- ============================================================================
TestVeafMoveTeleportEscortWaypoints = {}

local _TELEPORT = { x = 1000, y = 1000, alt = 6000, speed = 200 }
local _MOVE = { x = 5000, y = 5000, alt = 6000, speed = 200 }
local _OFFSET_LENGTH = math.sqrt(100 * 100 + 200 * 200) -- |pos| of the Escort task, as the builders set it

function TestVeafMoveTeleportEscortWaypoints:setUp()
  dcs_mocks.reset()
  self._savedGroupSpawn = VeafGroupSpawn
  self._savedSchedule = veaf.scheduleFunction
  _runScheduledImmediately()
  -- A teleport that brings the group back, which is all this suite needs of veafSpawnCore.
  VeafGroupSpawn = {
    new = function()
      local spawn
      spawn = {
        forGroup = function()
          return spawn
        end,
        at = function()
          return spawn
        end,
        teleport = function()
          return {}
        end,
      }
      return spawn
    end,
  }
  dcs_mocks.addGroup("Arco", { _id = 11 })
  dcs_mocks.addGroup("Arco escort", { _id = 20 })
end

function TestVeafMoveTeleportEscortWaypoints:tearDown()
  VeafGroupSpawn = self._savedGroupSpawn
  veaf.scheduleFunction = self._savedSchedule
  dcs_mocks.reset()
end

--- Teleport the escort of a route whose Escort task sits on `taskIndex` of `pointCount`, and return
--- the route points pushed to its controller.
local function _teleportedPoints(taskIndex, pointCount)
  _mission({ ["Arco escort"] = _groupDataWithTaskAt(20, 11, taskIndex, pointCount) })
  luaunit.assertTrue(veafMove.teleportEscort("Arco", _MOVE, _TELEPORT))
  local pushed = dcs_mocks.tasksSet[#dcs_mocks.tasksSet]
  luaunit.assertNotNil(pushed, "the escort's mission was not replaced")
  return pushed.task.params.route.points
end

local function _isApproach(point)
  local dx = point.x - (_TELEPORT.x + _MOVE.x) / 2
  local dy = point.y - (_TELEPORT.y + _MOVE.y) / 2
  return math.abs(math.sqrt(dx * dx + dy * dy) - _OFFSET_LENGTH) < 1e-6
end

local function _assertTaskPointFollowsApproach(approach, taskPoint)
  luaunit.assertTrue(_isApproach(approach), "the approach must sit one offset from the midpoint")
  luaunit.assertAlmostEquals(taskPoint.x - approach.x, (_MOVE.x - _TELEPORT.x) / 2, 1e-6)
  luaunit.assertAlmostEquals(taskPoint.y - approach.y, (_MOVE.y - _TELEPORT.y) / 2, 1e-6)
end

function TestVeafMoveTeleportEscortWaypoints:test_the_demo_mission_shape_rewrites_the_waypoint_carrying_the_task()
  -- Three waypoints, the task on the second: the approach is waypoint 1, the task point waypoint 2.
  local points = _teleportedPoints(2, 3)

  _assertTaskPointFollowsApproach(points[1], points[2])
  luaunit.assertEquals({ points[3].x, points[3].y }, { 3000, 3000 }, "a waypoint after the task keeps its editor position")
end

function TestVeafMoveTeleportEscortWaypoints:test_the_rewritten_waypoints_fly_the_move_leg_and_point_at_the_current_group()
  -- The move leg's altitude and speed, not the teleport's; and the task aimed at the escorted group's
  -- id as DCS knows it now (#107: a stale id is what makes an escort quit).
  -- A fresh id, different from the stale 11 the mission stores, or the assertion could not fail.
  dcs_mocks.removeGroup("Arco")
  dcs_mocks.addGroup("Arco", { _id = 4242 })
  _MOVE.alt, _MOVE.speed = 7000, 250
  local points = _teleportedPoints(2, 3)
  _MOVE.alt, _MOVE.speed = 6000, 200

  for _, index in ipairs({ 1, 2 }) do
    luaunit.assertEquals(points[index].alt, 7000)
    luaunit.assertEquals(points[index].speed, 250)
  end
  luaunit.assertEquals(points[2].task.params.tasks[1].params.groupId, 4242, "the task must point at the escorted group's current id")
end

function TestVeafMoveTeleportEscortWaypoints:test_a_task_on_the_last_waypoint_is_rewritten_as_before()
  -- The shape the code was written for: the approach and the task point are the same two waypoints.
  local points = _teleportedPoints(3, 3)

  _assertTaskPointFollowsApproach(points[1], points[2])
end

function TestVeafMoveTeleportEscortWaypoints:test_waypoints_before_the_approach_are_dropped()
  -- David, 2026-09-28: the escort must work wherever it appears. An editor waypoint left ahead of the
  -- approach sends it back to where the editor drew it before it ever reaches its charge.
  local points = _teleportedPoints(3, 4)

  luaunit.assertEquals(#points, 3, "the route must start at the approach")
  _assertTaskPointFollowsApproach(points[1], points[2])
  luaunit.assertEquals({ points[3].x, points[3].y }, { 4000, 4000 })
end

function TestVeafMoveTeleportEscortWaypoints:test_the_mission_record_is_left_as_the_editor_drew_it()
  -- The rewrite works on a copy. It used to write into the mission database itself, so an asset
  -- respawned after a teleport brought its escort back on the teleport's waypoints.
  _teleportedPoints(2, 3)

  local recorded = veaf.getGroupData("Arco escort").route.points
  luaunit.assertEquals(#recorded, 3)
  for index = 1, 3 do
    luaunit.assertEquals({ recorded[index].x, recorded[index].y }, { index * 1000, index * 1000 })
  end
  luaunit.assertEquals(veaf.getGroupRoute("Arco escort")[1].x, 1000, "a respawn must read the editor's route")
end

function TestVeafMoveTeleportEscortWaypoints:test_a_task_on_the_first_waypoint_is_taken_up_at_the_approach()
  -- There is no waypoint before it to approach through, so the task's own waypoint is the approach:
  -- offset from the midpoint as before, and nothing else in the route is touched.
  local points = _teleportedPoints(1, 3)

  luaunit.assertTrue(_isApproach(points[1]), "the task's waypoint must be placed at the approach")
  luaunit.assertEquals({ points[2].x, points[2].y }, { 2000, 2000 })
  luaunit.assertEquals({ points[3].x, points[3].y }, { 3000, 3000 })
end

function TestVeafMoveTeleportEscortWaypoints:test_a_one_point_route_carrying_the_task_can_be_teleported()
  -- The old "fewer than two waypoints" refusal was about rewriting the last two; one is now enough.
  local points = _teleportedPoints(1, 1)

  luaunit.assertTrue(_isApproach(points[1]))
end

os.exit(luaunit.LuaUnit.run())
