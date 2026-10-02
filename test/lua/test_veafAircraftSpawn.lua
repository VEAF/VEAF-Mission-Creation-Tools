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

-- ============================================================================
-- Reading a route: the shapes real missions hold (ticket 02)
-- ============================================================================
TestAircraftSpawnRouteReading = {}

--- An engagement task, as the Mission Editor writes it.
local function engageTask(id, targetTypes, enabled)
  return {
    id = id,
    auto = true,
    enabled = enabled ~= false,
    number = 1,
    key = "CAP",
    params = { targetTypes = targetTypes, priority = 0 },
  }
end

local function combo(tasks)
  return { id = "ComboTask", params = { tasks = tasks } }
end

function TestAircraftSpawnRouteReading:test_no_route_engages_nothing()
  luaunit.assertFalse(veafAircraftSpawn.routeEngagesAir(nil))
  luaunit.assertFalse(veafAircraftSpawn.routeEngagesAir({}))
end

function TestAircraftSpawnRouteReading:test_the_create_qra_single_point_engages_nothing()
  -- one airborne point, an empty ComboTask: what `create_qra` writes, and what Sayqal flew
  local points = { { type = "Turning Point", x = 0, y = 0, alt = 5262, task = combo({}) } }
  luaunit.assertFalse(veafAircraftSpawn.routeEngagesAir(points))
end

function TestAircraftSpawnRouteReading:test_the_editor_cap_auto_task_engages_air()
  local points = { { type = "Turning Point", task = combo({ engageTask("EngageTargets", { "Air" }), templateOptions().params.tasks[1] }) } }
  luaunit.assertTrue(veafAircraftSpawn.routeEngagesAir(points))
end

function TestAircraftSpawnRouteReading:test_an_engagement_in_zone_on_the_second_point_engages_air()
  -- the Open Training Caucasus v5 shape: options first, the engagement and the orbit on the second point
  local points = {
    { type = "Turning Point", task = templateOptions() },
    {
      type = "Turning Point",
      task = combo({
        engageTask("EngageTargetsInZone", { "Air" }),
        { id = "Orbit", enabled = true, params = { pattern = "Race-Track" } },
      }),
    },
    { type = "Turning Point", task = combo({}) },
  }
  luaunit.assertTrue(veafAircraftSpawn.routeEngagesAir(points))
end

function TestAircraftSpawnRouteReading:test_a_task_outside_a_combo_task_is_read_too()
  luaunit.assertTrue(veafAircraftSpawn.routeEngagesAir({ { task = engageTask("EngageTargets", { "Fighters" }) } }))
end

function TestAircraftSpawnRouteReading:test_a_disabled_engagement_does_not_count()
  luaunit.assertFalse(veafAircraftSpawn.routeEngagesAir({ { task = combo({ engageTask("EngageTargets", { "Air" }, false) }) } }))
end

function TestAircraftSpawnRouteReading:test_an_engagement_of_ground_targets_is_not_an_air_engagement()
  luaunit.assertFalse(veafAircraftSpawn.routeEngagesAir({ { task = combo({ engageTask("EngageTargets", { "Ground Units" }) }) } }))
end

function TestAircraftSpawnRouteReading:test_first_waypoint_options_are_copied()
  local points = { { task = templateOptions() } }
  local options = veafAircraftSpawn.firstWaypointOptions(points)
  luaunit.assertEquals(options, templateOptions())
  luaunit.assertFalse(options == points[1].task, "a copy, so the role cannot edit the template")
end

function TestAircraftSpawnRouteReading:test_an_empty_first_waypoint_has_no_options()
  luaunit.assertNil(veafAircraftSpawn.firstWaypointOptions({ { task = combo({}) } }))
  luaunit.assertNil(veafAircraftSpawn.firstWaypointOptions({ { task = engageTask("EngageTargets", { "Air" }) } }))
  luaunit.assertNil(veafAircraftSpawn.firstWaypointOptions(nil))
end

function TestAircraftSpawnRouteReading:test_a_takeoff_first_waypoint_is_the_takeoff_point()
  for _, takeoffType in ipairs({ "TakeOffParking", "TakeOffParkingHot", "TakeOff", "TakeOffGround", "TakeOffGroundHot" }) do
    local points = { { type = takeoffType, x = 1, y = 2, airdromeId = 12 } }
    local takeoff = veafAircraftSpawn.takeoffPoint(points)
    luaunit.assertEquals(takeoff, points[1], takeoffType)
    luaunit.assertFalse(takeoff == points[1], "a copy")
  end
end

function TestAircraftSpawnRouteReading:test_an_airborne_first_waypoint_is_no_takeoff()
  luaunit.assertNil(veafAircraftSpawn.takeoffPoint({ { type = "Turning Point", x = 1, y = 2 } }))
  luaunit.assertNil(veafAircraftSpawn.takeoffPoint(nil))
end

function TestAircraftSpawnRouteReading:test_the_zone_comes_from_the_trigger_zone_first()
  local zone = veafAircraftSpawn.zoneToDefend({ x = 100, y = 200, radius = 30000 }, { x = 1, y = 0, z = 2 }, 5000)
  luaunit.assertEquals(zone, { x = 100, y = 200, radius = 30000 })
end

function TestAircraftSpawnRouteReading:test_the_zone_centre_puts_its_easting_in_y()
  local zone = veafAircraftSpawn.zoneToDefend(nil, { x = 1000, y = 450, z = 2000 }, 5000)
  luaunit.assertEquals(zone, { x = 1000, y = 2000, radius = 5000 })
end

function TestAircraftSpawnRouteReading:test_no_radius_no_zone()
  luaunit.assertNil(veafAircraftSpawn.zoneToDefend(nil, { x = 1, y = 0, z = 2 }, nil))
  luaunit.assertNil(veafAircraftSpawn.zoneToDefend({ x = 1, y = 2, radius = 0 }, nil, nil))
end

-- ============================================================================
-- Which editor groups a QRA or a wave gives the `zone_defense` role (ticket 02)
-- ============================================================================
TestAircraftSpawnNeedsZoneDefense = {}

function TestAircraftSpawnNeedsZoneDefense:setUp()
  veafMissionDb.groupsByName = {}
end

function TestAircraftSpawnNeedsZoneDefense:tearDown()
  veafMissionDb.groupsByName = {}
end

local function editorGroup(name, category, task, points)
  veafMissionDb.groupsByName[name] = {
    groupName = name,
    category = category,
    country = "USA",
    countryId = 2,
    task = task,
    units = { { name = name .. "-1", x = 0, y = 0, alt = 5000 } },
    route = { points = points },
  }
end

local AIRBORNE_EMPTY = { { type = "Turning Point", x = 0, y = 0, alt = 5000, task = combo({}) } }

function TestAircraftSpawnNeedsZoneDefense:test_an_interceptor_with_nothing_to_do_needs_it()
  editorGroup("QRA-Intercept", "plane", "Intercept", AIRBORNE_EMPTY)
  luaunit.assertTrue(veafAircraftSpawn.needsZoneDefense("QRA-Intercept"))
end

function TestAircraftSpawnNeedsZoneDefense:test_a_cap_flight_with_a_written_route_and_no_engagement_needs_it()
  editorGroup("Wave-CAP", "plane", "CAP", {
    { type = "Turning Point", x = 0, y = 0, task = combo({}) },
    { type = "Turning Point", x = 1000, y = 0, task = combo({}) },
  })
  luaunit.assertTrue(veafAircraftSpawn.needsZoneDefense("Wave-CAP"))
end

function TestAircraftSpawnNeedsZoneDefense:test_a_parked_interceptor_needs_it()
  editorGroup("QRA-Parked", "plane", "Intercept", { { type = "TakeOffParking", x = 0, y = 0, airdromeId = 3, task = combo({}) } })
  luaunit.assertTrue(veafAircraftSpawn.needsZoneDefense("QRA-Parked"))
end

function TestAircraftSpawnNeedsZoneDefense:test_an_interceptor_that_engages_air_keeps_its_route()
  editorGroup("QRA-Engages", "plane", "Intercept", { { type = "Turning Point", task = combo({ engageTask("EngageTargets", { "Air" }) }) } })
  luaunit.assertFalse(veafAircraftSpawn.needsZoneDefense("QRA-Engages"))
end

function TestAircraftSpawnNeedsZoneDefense:test_a_bomber_wave_keeps_its_route()
  for _, task in ipairs({ "Ground Attack", "CAS", "Pinpoint Strike", "Fighter Sweep", "Escort", "Nothing" }) do
    editorGroup("Wave-" .. task, "plane", task, AIRBORNE_EMPTY)
    luaunit.assertFalse(veafAircraftSpawn.needsZoneDefense("Wave-" .. task), task)
  end
end

function TestAircraftSpawnNeedsZoneDefense:test_a_ground_group_is_not_concerned()
  editorGroup("QRA-Tanks", "vehicle", "Ground Nothing", AIRBORNE_EMPTY)
  luaunit.assertFalse(veafAircraftSpawn.needsZoneDefense("QRA-Tanks"))
end

function TestAircraftSpawnNeedsZoneDefense:test_an_unknown_group_is_not_concerned()
  luaunit.assertFalse(veafAircraftSpawn.needsZoneDefense("nobody"))
end

-- ============================================================================
-- The `zone_defense` role, on what reaches DCS (ticket 02)
-- ============================================================================
TestAircraftSpawnZoneDefense = {}

local ZD_TEMPLATE = "QRA-ZoneDefense"
local ZD_CLONE = "QRA-ZoneDefense-clone"
-- the spawn point 40 km south and 30 km west of the zone: a 3-4-5 axis, 50 km long
local ZD_SPOT = { x = 0, y = 5000, z = 0 }
local ZD_ZONE = { x = 40000, y = 30000, radius = 50 * NM }

function TestAircraftSpawnZoneDefense:setUp()
  dcs_mocks.reset()
  veafMissionDb.groupsByName = {}
  editorGroup(
    ZD_TEMPLATE,
    "plane",
    "Intercept",
    { { type = "Turning Point", x = 0, y = 0, alt = 5000, speed = 220, task = templateOptions() } }
  )
  captureSchedules(self)
  registerLiveGroup(ZD_CLONE)
end

function TestAircraftSpawnZoneDefense:tearDown()
  veaf.scheduleFunction = self._originalSchedule
  veafMissionDb.groupsByName = {}
  dcs_mocks.reset()
end

local function spawnZoneDefense(spot, zone)
  return VeafAircraftSpawn:new()
    :fromGroup(ZD_TEMPLATE)
    :named(ZD_CLONE)
    :at(spot or ZD_SPOT)
    :withRole("zone_defense", { zone = zone or ZD_ZONE })
    :spawn()
end

function TestAircraftSpawnZoneDefense:test_the_clone_name_comes_back_with_its_role()
  luaunit.assertEquals(spawnZoneDefense(), ZD_CLONE)
  luaunit.assertEquals(veafAircraftSpawn.getRole(ZD_CLONE), "zone_defense")
end

function TestAircraftSpawnZoneDefense:test_the_first_waypoint_is_the_spawn_point_with_the_template_options()
  spawnZoneDefense()
  local first = submittedRoute()[1]
  luaunit.assertEquals({ first.x, first.y, first.alt }, { 0, 0, 5000 })
  luaunit.assertEquals(first.type, "Turning Point")
  luaunit.assertEquals(first.task, templateOptions())
end

function TestAircraftSpawnZoneDefense:test_the_leg_is_centred_on_the_zone_along_the_approach_axis()
  spawnZoneDefense()
  local points = submittedRoute()
  luaunit.assertEquals(#points, 3)
  -- 20 NM, shorter than the 100 NM diameter, so 10 NM either side of the centre along (0.8, 0.6)
  local half = 10 * NM
  luaunit.assertAlmostEquals(points[2].x, 40000 - 0.8 * half, 0.01)
  luaunit.assertAlmostEquals(points[2].y, 30000 - 0.6 * half, 0.01)
  luaunit.assertAlmostEquals(points[3].x, 40000 + 0.8 * half, 0.01)
  luaunit.assertAlmostEquals(points[3].y, 30000 + 0.6 * half, 0.01)
end

function TestAircraftSpawnZoneDefense:test_a_small_zone_shortens_the_leg_to_its_diameter()
  spawnZoneDefense(nil, { x = 40000, y = 30000, radius = 3000 })
  local points = submittedRoute()
  local dx, dy = points[3].x - points[2].x, points[3].y - points[2].y
  luaunit.assertAlmostEquals(math.sqrt(dx * dx + dy * dy), 6000, 0.01)
end

function TestAircraftSpawnZoneDefense:test_the_patrol_flies_at_the_spawn_altitude_and_the_template_speed()
  spawnZoneDefense()
  for index, point in ipairs(submittedRoute()) do
    luaunit.assertEquals(point.alt, 5000, "waypoint " .. index)
    luaunit.assertEquals(point.speed, 220, "waypoint " .. index)
  end
  for _, unit in pairs(dcs_mocks.groupsAdded[1].group.units) do
    luaunit.assertEquals(unit.alt, 5000)
  end
end

function TestAircraftSpawnZoneDefense:test_the_last_waypoint_loops_back_to_the_second()
  spawnZoneDefense()
  local action = submittedRoute()[3].task.params.tasks[1].params.action
  luaunit.assertEquals(action.id, "SwitchWaypoint")
  luaunit.assertEquals(action.params, { goToWaypointIndex = 2, fromWaypointIndex = 3 })
end

function TestAircraftSpawnZoneDefense:test_the_watchdog_guards_the_whole_zone()
  spawnZoneDefense()
  luaunit.assertTrue(optionsSetOn(ZD_CLONE)[AI.Option.Air.id.PROHIBIT_AA])
  luaunit.assertEquals(#self.scheduled, 1)
  luaunit.assertEquals(self.scheduled[1].fn, veafSpawn.startCapWatchdog)
  luaunit.assertEquals(self.scheduled[1].args[3], ZD_ZONE)
  luaunit.assertEquals(veafSpawn.capWatchdogZones[ZD_CLONE], ZD_ZONE)
end

function TestAircraftSpawnZoneDefense:test_a_parked_interceptor_takes_off_then_patrols()
  local takeoff =
    { type = "TakeOffParking", action = "From Parking Area", x = 0, y = 0, alt = 20, speed = 0, airdromeId = 7, task = combo({}) }
  editorGroup(ZD_TEMPLATE, "plane", "Intercept", { takeoff })
  veafMissionDb.groupsByName[ZD_TEMPLATE].units[1].alt = 20

  spawnZoneDefense({ x = 0, y = 20, z = 0 })

  local points = submittedRoute()
  luaunit.assertEquals(#points, 3)
  luaunit.assertEquals(points[1].type, "TakeOffParking", "the take-off is kept as the editor wrote it")
  luaunit.assertEquals(points[1].airdromeId, 7)
  luaunit.assertEquals({ points[1].x, points[1].y }, { 0, 0 }, "and is not scattered off its airfield")
  for index = 2, 3 do
    luaunit.assertAlmostEquals(points[index].alt, veafAircraftSpawn.DEFAULT_PATROL_ALTITUDE, 0.01)
  end
  luaunit.assertAlmostEquals(points[2].x, 40000 - 0.8 * 10 * NM, 0.01)
  local action = points[3].task.params.tasks[1].params.action
  luaunit.assertEquals(action.params, { goToWaypointIndex = 2, fromWaypointIndex = 3 })
end

os.exit(luaunit.LuaUnit.run())
