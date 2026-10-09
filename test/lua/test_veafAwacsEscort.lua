--- Tests for `-awacs` and `-escort` (FEAT-AWACS-ESCORT-COMMANDS, #188 and #189): the `awacs` and
--- `air_escort` roles of veafAircraftSpawn, and the commands of veafSpawnAircraft that drive them.
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
dofile(src .. "/veafMove.lua")
dofile(src .. "/veafSecurity.lua") -- veafShortcuts hashes its aliases' passwords
dofile(src .. "/veafShortcuts.lua")

local NM = 1852
local SPOT = { x = 10000, y = 0, z = 20000 }
local ESCORT_TEMPLATE = "veafSpawn-F-15C - FOX3"

--- The submissions to `coalition.addGroup`, oldest first.
local function submitted(index)
  local entry = dcs_mocks.groupsAdded[index or #dcs_mocks.groupsAdded]
  return entry and entry.group
end

--- The tasks of a route point, in order.
local function tasksOf(point)
  return point.task.params.tasks
end

local function taskWithId(point, id)
  for _, task in ipairs(tasksOf(point)) do
    if task.id == id then
      return task
    end
  end
  return nil
end

--- Make whatever `addGroup` submits exist in DCS, the way DCS would.
local function groupsComeAlive(suite)
  suite._addGroup = coalition.addGroup
  coalition.addGroup = function(countryId, categoryId, group)
    suite._addGroup(countryId, categoryId, group)
    local unit = group.units[1]
    dcs_mocks.addGroup(group.name, {
      _id = group.groupId,
      getUnits = function()
        return {
          {
            isExist = function()
              return true
            end,
            getPoint = function()
              return { x = unit.x, y = unit.alt, z = unit.y }
            end,
            getPosition = function()
              local heading = unit.heading or 0
              return { p = { x = unit.x, y = unit.alt, z = unit.y }, x = { x = math.cos(heading), y = 0, z = math.sin(heading) } }
            end,
          },
        }
      end,
    })
  end
end

--- An airplane flying at `point`, heading north, of `side`.
local function flyingAirplane(name, point, side, id, active)
  dcs_mocks.addGroup(name, {
    _id = id or 77,
    _coalition = side,
    getUnits = function()
      return {
        {
          isExist = function()
            return true
          end,
          isActive = function()
            return active ~= false
          end,
          getPoint = function()
            return point
          end,
          getPosition = function()
            return { p = point, x = { x = 1, y = 0, z = 0 } }
          end,
        },
      }
    end,
  })
end

--- One `veafSpawn-` fighter template, whatever is asked for.
local function oneEscortTemplate(suite)
  veafMissionDb.groupsByName[ESCORT_TEMPLATE] = {
    name = ESCORT_TEMPLATE,
    groupName = ESCORT_TEMPLATE,
    category = "plane",
    country = "USA",
    countryId = 2,
    units = { { name = ESCORT_TEMPLATE .. "-1", type = "F-15C", x = 0, y = 0, alt = 6000, heading = 0, skill = "Average" } },
    route = { points = { [1] = { speed = 220, task = { id = "ComboTask", params = { tasks = {} } } } } },
  }
  suite._find = veafSpawn.findSpawnableAircraftGroupname
  veafSpawn.findSpawnableAircraftGroupname = function(name, side)
    suite.asked = { name = name, side = side }
    return ESCORT_TEMPLATE, veafMissionDb.groupsByName[ESCORT_TEMPLATE]
  end
end

local function setUpWorld(suite)
  dcs_mocks.reset()
  veafMissionDb.groupsByName = {}
  groupsComeAlive(suite)
  oneEscortTemplate(suite)
end

local function tearDownWorld(suite)
  coalition.addGroup = suite._addGroup
  veafSpawn.findSpawnableAircraftGroupname = suite._find
  veafMissionDb.groupsByName = {}
  dcs_mocks.reset()
end

-- ============================================================================
-- Ticket 01 — `-awacs`: an AWACS on its race-track
-- ============================================================================
TestAwacsSpawn = {}

function TestAwacsSpawn:setUp()
  setUpWorld(self)
end

function TestAwacsSpawn:tearDown()
  tearDownWorld(self)
end

--- The options the parser gives `_spawn awacs` with nothing else on the marker.
local function awacsOptions(text)
  local options = veafSpawn.markTextAnalysis(text or "_spawn awacs")
  options.country = options.country or "USA"
  options.side = options.side or coalition.side.BLUE
  options.silent = true
  return options
end

function TestAwacsSpawn:test_the_marker_turns_skynet_and_the_datalink_on()
  local options = veafSpawn.markTextAnalysis("_spawn awacs")
  luaunit.assertTrue(options.awacs)
  luaunit.assertTrue(options.skynet)
  luaunit.assertTrue(options.eplrs)
end

function TestAwacsSpawn:test_the_marker_turns_them_off_when_asked()
  local options = veafSpawn.markTextAnalysis("_spawn awacs, skynet false, eplrs false")
  luaunit.assertFalse(options.skynet)
  luaunit.assertFalse(options.eplrs)
  luaunit.assertFalse(veafSpawn.markTextAnalysis("_spawn awacs, datalink false").eplrs)
end

function TestAwacsSpawn:test_the_marker_reads_the_escort_template()
  luaunit.assertEquals(veafSpawn.markTextAnalysis("_spawn awacs, escort f15-fox3").escortTemplate, "f15-fox3")
  luaunit.assertNil(veafSpawn.markTextAnalysis("_spawn awacs").escortTemplate)
  luaunit.assertNil(veafSpawn.markTextAnalysis("_spawn awacs").escort, "the escort command is not the escort option")
end

function TestAwacsSpawn:test_the_alias_runs_the_awacs_command()
  veafShortcuts.buildDefaultList()
  luaunit.assertEquals(veafShortcuts.GetAlias("-awacs"):getVeafCommand(), "_spawn awacs")
end

function TestAwacsSpawn:test_blue_gets_an_e3_and_red_an_a50()
  luaunit.assertEquals(veafAircraftSpawn.awacsType(nil, coalition.side.BLUE), "E-3A")
  luaunit.assertEquals(veafAircraftSpawn.awacsType("", coalition.side.RED), "A-50")
  luaunit.assertEquals(veafAircraftSpawn.awacsType("e-2c", coalition.side.RED), "E-2C")
  luaunit.assertNil(veafAircraftSpawn.awacsType("F-16C_50", coalition.side.BLUE))
end

function TestAwacsSpawn:test_an_awacs_is_spawned_from_its_type_with_its_fuel()
  local name = veafSpawn.spawnAwacs(SPOT, awacsOptions())
  luaunit.assertEquals(name, "AWACS E-3A")
  local group = submitted()
  luaunit.assertEquals(dcs_mocks.groupsAdded[1].categoryId, Unit.Category.AIRPLANE)
  luaunit.assertEquals(group.task, "AWACS")
  luaunit.assertEquals(group.units[1].type, "E-3A")
  luaunit.assertEquals(group.units[1].payload.fuel, 65000)
end

function TestAwacsSpawn:test_it_flies_at_30000_ft_on_251_mhz_by_default()
  veafSpawn.spawnAwacs(SPOT, awacsOptions())
  local group = submitted()
  luaunit.assertAlmostEquals(group.units[1].alt, 30000 * 0.3048, 0.01)
  luaunit.assertEquals(group.frequency, 251)
  luaunit.assertEquals(group.modulation, 0)
  luaunit.assertTrue(group.communication)
end

function TestAwacsSpawn:test_the_first_waypoint_carries_the_awacs_task_the_datalink_and_the_race_track()
  veafSpawn.spawnAwacs(SPOT, awacsOptions())
  local group = submitted()
  local first = group.route.points[1]
  luaunit.assertNotNil(taskWithId(first, "AWACS"))
  local orbit = taskWithId(first, "Orbit")
  luaunit.assertEquals(orbit.params.pattern, "Race-Track")
  luaunit.assertEquals(orbit.params.altitude, first.alt)
  local eplrs = taskWithId(first, "WrappedAction").params.action
  luaunit.assertEquals(eplrs.id, "EPLRS")
  luaunit.assertTrue(eplrs.params.value)
  luaunit.assertEquals(eplrs.params.groupId, group.groupId, "the datalink names the group DCS was given")
end

function TestAwacsSpawn:test_no_datalink_when_asked()
  veafSpawn.spawnAwacs(SPOT, awacsOptions("_spawn awacs, eplrs false"))
  luaunit.assertNil(taskWithId(submitted().route.points[1], "WrappedAction"))
end

function TestAwacsSpawn:test_the_race_track_follows_the_heading_for_30_nm()
  veafSpawn.spawnAwacs(SPOT, awacsOptions("_spawn awacs, hdg 90"))
  local points = submitted().route.points
  luaunit.assertEquals(#points, 2)
  luaunit.assertAlmostEquals(points[1].x, SPOT.x, 0.01)
  luaunit.assertAlmostEquals(points[1].y, SPOT.z, 0.01)
  -- heading 90°: east, the mission-table `y`
  luaunit.assertAlmostEquals(points[2].x - points[1].x, 0, 0.01)
  luaunit.assertAlmostEquals(points[2].y - points[1].y, 30 * NM, 0.01)
end

function TestAwacsSpawn:test_type_altitude_leg_and_frequency_follow_the_marker()
  veafSpawn.spawnAwacs(SPOT, awacsOptions("_spawn awacs, type e-2c, alt 20000, dist 10, freq 255.5"))
  local group = submitted()
  luaunit.assertEquals(group.units[1].type, "E-2C")
  luaunit.assertAlmostEquals(group.units[1].alt, 20000 * 0.3048, 0.01)
  luaunit.assertEquals(group.frequency, 255.5)
  local points = group.route.points
  luaunit.assertAlmostEquals(points[2].x - points[1].x, 10 * NM, 0.01)
end

function TestAwacsSpawn:test_an_unknown_type_spawns_nothing_and_says_why()
  local options = awacsOptions("_spawn awacs, type f-16")
  options.silent = false
  luaunit.assertNil(veafSpawn.spawnAwacs(SPOT, options))
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
  luaunit.assertTrue(#dcs_mocks.messagesContaining("E-3A") > 0, "the message lists the known types")
end

function TestAwacsSpawn:test_a_second_awacs_gets_its_own_name()
  local first = veafSpawn.spawnAwacs(SPOT, awacsOptions())
  local second = veafSpawn.spawnAwacs(SPOT, awacsOptions())
  luaunit.assertNotEquals(first, second)
end

function TestAwacsSpawn:test_the_awacs_flies_its_role()
  local name = veafSpawn.spawnAwacs(SPOT, awacsOptions())
  luaunit.assertEquals(veafAircraftSpawn.getRole(name), "awacs")
end

--- Skynet: the command returns the group's name to `executeCommand`, whose shared tail integrates it
--- because `options.skynet` is true — the path every ground spawn with `skynet true` takes.
function TestAwacsSpawn:test_the_spawn_command_hands_the_awacs_to_skynet()
  local added = {}
  local originalSkynet = veafSkynet
  veafSkynet = {
    declareSpawn = function() end,
    defaultIADS = { [tostring(coalition.side.BLUE)] = "blue iads" },
    integratesDynamicSpawns = function()
      return false
    end,
    addGroupToNetwork = function(networkName, group)
      table.insert(added, { network = networkName, group = group:getName() })
      return true
    end,
  }
  veafSpawn.executeCommand(SPOT, "_spawn awacs, side blue", coalition.side.BLUE, nil, true, nil, nil, nil, nil, nil, nil, true)
  veafSkynet = originalSkynet
  luaunit.assertEquals(added, { { network = "blue iads", group = "AWACS E-3A" } })
end

function TestAwacsSpawn:test_awacs_types_match_the_dcs_awacs_attribute()
  -- `dcsUnits.yaml` lists four types with the `AWACS` attribute (2026-10-04); the Python side checks
  -- the fuel against it, this checks nothing was dropped from the table
  local types = {}
  for name, _ in pairs(veafAircraftSpawn.AWACS_TYPES) do
    table.insert(types, name)
  end
  table.sort(types)
  luaunit.assertEquals(types, { "A-50", "E-2C", "E-3A", "KJ-2000" })
end

-- ============================================================================
-- Ticket 02 — the escort: the `air_escort` role, and `-awacs, escort`
-- ============================================================================
TestAirEscort = {}

function TestAirEscort:setUp()
  setUpWorld(self)
end

function TestAirEscort:tearDown()
  tearDownWorld(self)
end

function TestAirEscort:test_the_escort_escorts_and_defends_its_charge()
  flyingAirplane("Cowboy-1", { x = 5000, y = 7000, z = 6000 }, coalition.side.BLUE, 42)
  local name = veafSpawn.spawnEscort("f15-fox3", "Cowboy-1", "USA", true, false)
  luaunit.assertEquals(name, "Cowboy-1 escort")
  local first = submitted().route.points[1]
  local escort = taskWithId(first, "Escort")
  luaunit.assertNotNil(escort, "the Escort task")
  luaunit.assertEquals(escort.params.groupId, 42, "the runtime id of the escorted group")
  luaunit.assertEquals(escort.params.engagementDistMax, 60000)
  luaunit.assertEquals(escort.params.targetTypes, { "Air" })
  luaunit.assertFalse(escort.params.lastWptIndexFlag)
  luaunit.assertTrue(escort.enabled)
end

function TestAirEscort:test_the_escort_is_allowed_to_fire()
  flyingAirplane("Cowboy-1", { x = 5000, y = 7000, z = 6000 }, coalition.side.BLUE)
  veafSpawn.spawnEscort("f15-fox3", "Cowboy-1", "USA", true, false)
  local roe = nil
  for _, task in ipairs(tasksOf(submitted().route.points[1])) do
    local action = task.params and task.params.action
    if action and action.id == "Option" and action.params.name == AI.Option.Air.id.ROE then
      roe = action.params.value
    end
  end
  luaunit.assertEquals(roe, AI.Option.Air.val.ROE.OPEN_FIRE)
end

function TestAirEscort:test_the_template_options_come_first_and_the_escort_last()
  veafMissionDb.groupsByName[ESCORT_TEMPLATE].route.points[1].task.params.tasks = {
    {
      id = "WrappedAction",
      number = 1,
      enabled = true,
      auto = false,
      params = { action = { id = "Option", params = { name = 4, value = 4 } } },
    },
  }
  flyingAirplane("Cowboy-1", { x = 5000, y = 7000, z = 6000 }, coalition.side.BLUE)
  veafSpawn.spawnEscort("f15-fox3", "Cowboy-1", "USA", true, false)
  local tasks = tasksOf(submitted().route.points[1])
  luaunit.assertEquals(tasks[1].params.action.params.name, 4, "the template's own option is kept")
  luaunit.assertEquals(tasks[#tasks].id, "Escort")
  for index, task in ipairs(tasks) do
    luaunit.assertEquals(task.number, index)
  end
end

function TestAirEscort:test_the_escort_appears_behind_its_charge_at_its_altitude()
  -- the charge flies north (`x`): behind is 3 km south
  flyingAirplane("Cowboy-1", { x = 5000, y = 7000, z = 6000 }, coalition.side.BLUE)
  veafSpawn.spawnEscort("f15-fox3", "Cowboy-1", "USA", true, false)
  local first = submitted().route.points[1]
  luaunit.assertAlmostEquals(first.x, 2000, 0.01)
  luaunit.assertAlmostEquals(first.y, 6000, 0.01)
  luaunit.assertAlmostEquals(first.alt, 7000, 0.01)
end

function TestAirEscort:test_the_escort_flies_for_the_side_asked()
  flyingAirplane("Cowboy-1", { x = 5000, y = 7000, z = 6000 }, coalition.side.BLUE)
  veafSpawn.spawnEscort("f15-fox3", "Cowboy-1", "USA", true, false)
  luaunit.assertEquals(self.asked, { name = "f15-fox3", side = coalition.side.BLUE })
end

function TestAirEscort:test_the_message_names_the_template_drawn()
  flyingAirplane("Cowboy-1", { x = 5000, y = 7000, z = 6000 }, coalition.side.BLUE)
  veafSpawn.spawnEscort("", "Cowboy-1", "USA", false, false)
  luaunit.assertTrue(#dcs_mocks.messagesContaining("F-15C - FOX3") > 0)
end

function TestAirEscort:test_nothing_to_escort_spawns_nothing()
  luaunit.assertNil(veafSpawn.spawnEscort("f15-fox3", "Nobody", "USA", true, false))
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

--- The refusal used to fall through to the template's own route: a group with no job at all.
function TestAirEscort:test_a_charge_gone_before_the_role_is_built_spawns_nothing()
  local spawned = VeafAircraftSpawn:new():fromGroup(ESCORT_TEMPLATE):at(SPOT):withRole("air_escort", { escorted = "Nobody" }):spawn()
  luaunit.assertNil(spawned)
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

function TestAirEscort:test_a_second_escort_does_not_replace_the_first()
  flyingAirplane("Cowboy-1", { x = 5000, y = 7000, z = 6000 }, coalition.side.BLUE)
  local first = veafSpawn.spawnEscort("f15-fox3", "Cowboy-1", "USA", true, false)
  local second = veafSpawn.spawnEscort("f15-fox3", "Cowboy-1", "USA", true, false)
  luaunit.assertNotEquals(first, second)
end

function TestAirEscort:test_the_awacs_escort_option_escorts_the_new_awacs()
  local options = veafSpawn.markTextAnalysis("_spawn awacs, escort f15-fox3")
  options.country, options.side, options.silent = "USA", coalition.side.BLUE, true
  local awacs = veafSpawn.spawnAwacs(SPOT, options)
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 2)
  local escort = submitted(2)
  -- `veafMove`'s naming convention for an escort
  luaunit.assertEquals(escort.name, awacs .. veafMove.EscortGroupNameSuffix)
  luaunit.assertEquals(taskWithId(escort.route.points[1], "Escort").params.groupId, submitted(1).groupId)
end

function TestAirEscort:test_the_suffix_is_the_one_veafmove_looks_for()
  luaunit.assertEquals(veafSpawn.EscortGroupNameSuffix, veafMove.EscortGroupNameSuffix)
end

-- ============================================================================
-- Ticket 03 — `-escort` next to an aircraft, and "Escort me" in the F10 menu
-- ============================================================================
TestEscortCommands = {}

function TestEscortCommands:setUp()
  setUpWorld(self)
end

function TestEscortCommands:tearDown()
  tearDownWorld(self)
end

function TestEscortCommands:test_the_alias_takes_the_template_as_its_name()
  veafShortcuts.buildDefaultList()
  luaunit.assertEquals(veafShortcuts.GetAlias("-escort"):getVeafCommand(), "_spawn escort, name")
  local options = veafSpawn.markTextAnalysis("_spawn escort, name f15-fox3")
  luaunit.assertTrue(options.escort)
  luaunit.assertEquals(options.name, "f15-fox3")
end

function TestEscortCommands:test_the_nearest_friendly_airplane_is_the_one_escorted()
  flyingAirplane("Far", { x = 0, y = 7000, z = 5000 }, coalition.side.BLUE)
  flyingAirplane("Near", { x = 0, y = 7000, z = 800 }, coalition.side.BLUE)
  luaunit.assertEquals(veafSpawn.findEscortableAircraft({ x = 0, y = 0, z = 0 }, coalition.side.BLUE), "Near")
end

function TestEscortCommands:test_a_neutral_airplane_can_be_escorted()
  flyingAirplane("Airliner", { x = 0, y = 7000, z = 800 }, coalition.side.NEUTRAL)
  luaunit.assertEquals(veafSpawn.findEscortableAircraft({ x = 0, y = 0, z = 0 }, coalition.side.BLUE), "Airliner")
end

function TestEscortCommands:test_an_enemy_airplane_is_never_escorted()
  flyingAirplane("Bandit", { x = 0, y = 7000, z = 100 }, coalition.side.RED)
  luaunit.assertNil(veafSpawn.findEscortableAircraft({ x = 0, y = 0, z = 0 }, coalition.side.BLUE))
end

function TestEscortCommands:test_a_late_activated_airplane_is_not_escorted()
  flyingAirplane("Waiting", { x = 0, y = 7000, z = 100 }, coalition.side.BLUE, 1, false)
  flyingAirplane("Flying", { x = 0, y = 7000, z = 900 }, coalition.side.BLUE)
  luaunit.assertEquals(veafSpawn.findEscortableAircraft({ x = 0, y = 0, z = 0 }, coalition.side.BLUE), "Flying")
end

function TestAirEscort:test_no_country_no_escort()
  flyingAirplane("Cowboy-1", { x = 5000, y = 7000, z = 6000 }, coalition.side.BLUE)
  luaunit.assertNil(veafSpawn.spawnEscort("fox3", "Cowboy-1", "NOWHERE", true, false))
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

function TestEscortCommands:test_an_airplane_beyond_10_nm_is_not_found()
  flyingAirplane("Far", { x = 0, y = 7000, z = 10 * NM + 1 }, coalition.side.BLUE)
  luaunit.assertNil(veafSpawn.findEscortableAircraft({ x = 0, y = 0, z = 0 }, coalition.side.BLUE))
end

function TestEscortCommands:test_the_marker_escorts_the_airplane_next_to_it()
  flyingAirplane("Cowboy-1", { x = 300, y = 7000, z = 0 }, coalition.side.BLUE, 42)
  local name = veafSpawn.executeCommand(
    { x = 0, y = 0, z = 0 },
    "_spawn escort, name f15-fox3, side blue",
    coalition.side.BLUE,
    nil,
    true,
    nil,
    nil,
    nil,
    nil,
    nil,
    nil,
    true
  )
  luaunit.assertNotNil(name)
  luaunit.assertEquals(taskWithId(submitted().route.points[1], "Escort").params.groupId, 42)
end

function TestEscortCommands:test_a_marker_with_nothing_near_says_so()
  local options = veafSpawn.markTextAnalysis("_spawn escort, name f15-fox3")
  options.side, options.country = coalition.side.BLUE, "USA"
  luaunit.assertNil(veafSpawn.spawnEscortNear({ x = 0, y = 0, z = 0 }, options))
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
  luaunit.assertTrue(#dcs_mocks.messagesContaining("10 NM") > 0)
end

--- The pilot of a player group, as the F10 menu hands him over: by unit name.
local function pilotIn(groupName, categoryEx)
  flyingAirplane(groupName, { x = 5000, y = 7000, z = 6000 }, coalition.side.BLUE, 42)
  dcs_mocks.addUnit(groupName .. "-1", {
    _categoryEx = categoryEx,
    getGroup = function()
      return Group.getByName(groupName)
    end,
  })
  return groupName .. "-1"
end

function TestEscortCommands:test_escort_me_escorts_the_pilots_own_group()
  local unitName = pilotIn("Cowboy-1")
  local name = veafSpawn.escortMe({ "fox3", unitName })
  luaunit.assertEquals(name, "Cowboy-1 escort")
  luaunit.assertEquals(self.asked, { name = "fox3", side = coalition.side.BLUE })
  luaunit.assertEquals(taskWithId(submitted().route.points[1], "Escort").params.groupId, 42)
end

function TestEscortCommands:test_escort_me_with_no_template_for_the_side_says_so()
  -- FIX-CAMPAIGN-MISSION-1-FINDINGS ticket 09: an "Escort me" in an A-10C answered nothing at all
  veafSpawn.findSpawnableAircraftGroupname = function()
    return nil
  end
  local unitName = pilotIn("Cowboy-1")
  luaunit.assertNil(veafSpawn.escortMe({ "fox3", unitName }))
  luaunit.assertTrue(#dcs_mocks.messagesContaining("fox3") > 0, "the pilot is told no template matched")
end

function TestEscortCommands:test_escort_me_whose_spawn_fails_says_so()
  local unitName = pilotIn("Cowboy-1")
  local original = VeafAircraftSpawn.spawn
  VeafAircraftSpawn.spawn = function()
    return nil
  end
  local name = veafSpawn.escortMe({ "fox3", unitName })
  VeafAircraftSpawn.spawn = original
  luaunit.assertNil(name)
  luaunit.assertTrue(#dcs_mocks.messagesContaining("Cowboy-1") > 0, "the pilot is told the escort did not come")
end

function TestEscortCommands:test_escort_me_refuses_a_helicopter()
  local unitName = pilotIn("Huey-1", Unit.Category.HELICOPTER)
  luaunit.assertNil(veafSpawn.escortMe({ "fox3", unitName }))
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

function TestEscortCommands:test_the_menu_offers_one_entry_per_template_per_group_at_known_pilot_level()
  local added = {}
  local original = veafRadio.addSecuredCommandToSubmenu
  veafRadio.addSecuredCommandToSubmenu = function(title, menu, method, parameters, usage)
    local command = { title = title, method = method, parameters = parameters, usage = usage }
    table.insert(added, command)
    return command
  end
  veafSpawn.addEscortRadioCommands({})
  veafRadio.addSecuredCommandToSubmenu = original
  luaunit.assertEquals(#added, #veafSpawn.EscortRadioMenuTemplates)
  for index, command in ipairs(added) do
    luaunit.assertEquals(command.method, veafSpawn.escortMe)
    luaunit.assertEquals(command.parameters, veafSpawn.EscortRadioMenuTemplates[index])
    luaunit.assertEquals(command.usage, veafRadio.USAGE_ForGroup)
    luaunit.assertEquals(command.securityLevel, veafSecurity.LEVEL_KNOWN_PILOT)
  end
end

function TestEscortCommands:test_the_spawn_menu_carries_the_escort_entries()
  local wired = false
  local original = veafSpawn.addEscortRadioCommands
  veafSpawn.addEscortRadioCommands = function()
    wired = true
  end
  veafSpawn.buildRadioMenu()
  veafSpawn.addEscortRadioCommands = original
  luaunit.assertTrue(wired)
end

os.exit(luaunit.LuaUnit.run())
