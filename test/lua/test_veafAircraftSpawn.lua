--- Tests for veafAircraftSpawn.lua — spawning an aircraft with a role (FEAT-AIRCRAFT-ROLES).
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/dcsUnits.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafMissionDb.lua")
dofile(src .. "/veafDcsSpawner.lua")
dofile(src .. "/veafI18n.lua")
dofile(src .. "/veafGrass.lua")
dofile(src .. "/veafSpawn.lua")

local NM = 1852

--- The first-waypoint options a template author sets in the editor: ROE and reaction to threat.
local function templateOptions()
  return {
    id = "ComboTask",
    params = {
      tasks = {
        [1] = {
          id = "WrappedAction",
          number = 1,
          auto = false,
          enabled = true,
          params = { action = { id = "Option", params = { name = 0, value = 2 } } },
        },
        [2] = {
          id = "WrappedAction",
          number = 2,
          auto = false,
          enabled = true,
          params = { action = { id = "Option", params = { name = 1, value = 2 } } },
        },
      },
    },
  }
end

--- Capture what `veaf.scheduleFunction` is asked to run, without running it.
local function captureSchedules(suite)
  suite.scheduled = {}
  local scheduled = suite.scheduled
  suite._originalSchedule = veaf.scheduleFunction
  veaf.scheduleFunction = function(fn, args, time)
    table.insert(scheduled, { fn = fn, args = args, time = time })
    return 1
  end
end

--- The options a group's controller was given, by option id.
local function optionsSetOn(groupName)
  local result = {}
  for _, option in ipairs(dcs_mocks.optionsSet) do
    if option.group == groupName then
      result[option.id] = option.value
    end
  end
  return result
end

--- Register a spawned clone so that `Group.getByName` answers it, with the mock controller.
local function registerLiveGroup(name)
  dcs_mocks.addGroup(name, {
    getUnits = function()
      return { {
        getName = function()
          return name .. "-1"
        end,
      } }
    end,
  })
end

-- ============================================================================
-- The `-cap` contract, written before it moved (ticket 01). Every assertion is relative to the
-- first waypoint, so it pins the shape the CAP flies and not the scatter of its spawn point.
-- ============================================================================
TestAircraftSpawnCapContract = {}

local CAP_TEMPLATE = "veafSpawn-CAPCONTRACT"
local CAP_CLONE = string.format("%s #%04d", CAP_TEMPLATE, 1)

function TestAircraftSpawnCapContract:setUp()
  dcs_mocks.reset()
  veafMissionDb.groupsByName = {}
  veafMissionDb.groupsByName[CAP_TEMPLATE] = {
    name = CAP_TEMPLATE,
    groupName = CAP_TEMPLATE,
    category = "plane",
    country = "USA",
    countryId = 2,
    units = { { name = CAP_TEMPLATE .. "-1", type = "F-15C", x = 0, y = 0, alt = 6000, heading = 0, skill = "Average" } },
  }
  self._originalFind = veafSpawn.findSpawnableAircraftGroupname
  veafSpawn.findSpawnableAircraftGroupname = function(_)
    return CAP_TEMPLATE, { groupId = 1, units = {}, route = { points = { [1] = { task = templateOptions() } } } }
  end
  captureSchedules(self)
  registerLiveGroup(CAP_CLONE)
end

function TestAircraftSpawnCapContract:tearDown()
  veafSpawn.findSpawnableAircraftGroupname = self._originalFind
  veaf.scheduleFunction = self._originalSchedule
  veafMissionDb.groupsByName = {}
  dcs_mocks.reset()
end

--- A CAP heading east (90°), 20 NM legs, a 60 NM engagement zone, at 25 000 ft.
local function spawnTheCap()
  return veafSpawn.spawnCombatAirPatrol(
    { x = 10000, y = 0, z = 20000 },
    0,
    "CAPCONTRACT",
    "usa",
    25000,
    0,
    90,
    20,
    nil,
    60,
    "Excellent",
    true,
    false
  )
end

local function submittedRoute()
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 1, "exactly one group must reach DCS")
  return dcs_mocks.groupsAdded[1].group.route.points
end

function TestAircraftSpawnCapContract:test_the_cap_name_comes_back()
  luaunit.assertEquals(spawnTheCap(), CAP_CLONE)
end

function TestAircraftSpawnCapContract:test_three_waypoints_at_the_patrol_altitude()
  spawnTheCap()
  local points = submittedRoute()
  luaunit.assertEquals(#points, 3)
  -- `altitudedelta 0` reads as "not given", so the default ±2 000 ft draw applies
  luaunit.assertTrue(points[1].alt >= 23000 * 0.3048 - 0.01 and points[1].alt <= 27000 * 0.3048 + 0.01, tostring(points[1].alt))
  for index, point in ipairs(points) do
    luaunit.assertEquals(point.alt, points[1].alt, "waypoint " .. index)
    luaunit.assertEquals(point.alt_type, "BARO", "waypoint " .. index)
  end
end

function TestAircraftSpawnCapContract:test_the_first_waypoint_carries_the_template_options()
  spawnTheCap()
  luaunit.assertEquals(submittedRoute()[1].task, templateOptions())
end

function TestAircraftSpawnCapContract:test_the_legs_follow_the_heading()
  spawnTheCap()
  local points = submittedRoute()
  -- heading 90°: east, which is the mission-table `y`
  luaunit.assertAlmostEquals(points[2].x - points[1].x, 0, 0.01)
  luaunit.assertAlmostEquals(points[2].y - points[1].y, 2500, 0.01)
  luaunit.assertAlmostEquals(points[3].x - points[2].x, 0, 0.01)
  luaunit.assertAlmostEquals(points[3].y - points[2].y, 20 * NM, 0.01)
end

function TestAircraftSpawnCapContract:test_the_patrol_waypoint_has_no_task_of_its_own()
  spawnTheCap()
  luaunit.assertEquals(submittedRoute()[2].task, { id = "ComboTask", params = { tasks = {} } })
end

function TestAircraftSpawnCapContract:test_the_last_waypoint_loops_back_to_the_second()
  spawnTheCap()
  local action = submittedRoute()[3].task.params.tasks[1].params.action
  luaunit.assertEquals(action.id, "SwitchWaypoint")
  luaunit.assertEquals(action.params, { goToWaypointIndex = 2, fromWaypointIndex = 3 })
end

function TestAircraftSpawnCapContract:test_air_to_air_is_prohibited_until_the_watchdog_decides()
  spawnTheCap()
  luaunit.assertTrue(optionsSetOn(CAP_CLONE)[AI.Option.Air.id.PROHIBIT_AA])
end

function TestAircraftSpawnCapContract:test_the_watchdog_guards_the_zone_between_the_legs()
  spawnTheCap()
  luaunit.assertEquals(#self.scheduled, 1)
  local watchdog = self.scheduled[1]
  luaunit.assertEquals(watchdog.fn, veafSpawn.startCapWatchdog)
  luaunit.assertEquals(watchdog.args[1], CAP_CLONE)
  local points = submittedRoute()
  local zone = watchdog.args[3]
  luaunit.assertAlmostEquals(zone.x, (points[2].x + points[3].x) / 2, 0.01)
  luaunit.assertAlmostEquals(zone.y, (points[2].y + points[3].y) / 2, 0.01)
  luaunit.assertAlmostEquals(zone.radius, 60 * NM, 0.01)
end

function TestAircraftSpawnCapContract:test_every_unit_gets_the_requested_skill()
  spawnTheCap()
  for _, unit in pairs(dcs_mocks.groupsAdded[1].group.units) do
    luaunit.assertEquals(unit.skill, "Excellent")
  end
end

os.exit(luaunit.LuaUnit.run())
