--- Tests for spawning helicopters from a marker (FEAT-HELICOPTER-SPAWN): the ground path
--- (`_spawn unit`, `_spawn group`) and the helicopter roles of veafAircraftSpawn.
---
--- The real veafUnits is loaded over the dcs_mocks stub: what decides whether a unit is a helicopter
--- is its DCS category in dcsUnits.lua, and a stub would answer whatever the test wanted.
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
dofile(src .. "/veafUnits.lua")
dofile(src .. "/veafSpawn.lua")

local SPOT = { x = 1000, y = 0, z = 2000 }

--- The group last handed to `coalition.addGroup`, and the category it was handed under.
local function lastSubmission()
  local entries = dcs_mocks.groupsAdded
  local entry = entries[#entries]
  return entry and entry.group, entry and entry.categoryId
end

local function spawnHelicopterUnit(name, alt, job)
  return veafSpawn.spawnUnit(SPOT, 0, name, nil, "usa", alt or 0, 90, nil, nil, false, nil, nil, nil, true, false, job)
end

local function helicopterGroupDefinition()
  return veafUnits.processGroup({
    disposition = { h = 1, w = 1 },
    units = { { "Mi-8MT", cell = 1 } },
    description = "two transport helicopters",
    groupName = "HELOS",
  })
end

local function spawnHelicopterGroup(hasDest, job)
  return veafSpawn.doSpawnGroup(SPOT, 0, helicopterGroupDefinition(), nil, "usa", 0, 0, 10, nil, true, hasDest, false, false, job)
end

-- ============================================================================
-- Ticket 02 — what makes a unit a helicopter
-- ============================================================================
TestHelicopterUnits = {}

function TestHelicopterUnits:setUp()
  dcs_mocks.reset()
  self._surface = land.getSurfaceType
end

function TestHelicopterUnits:tearDown()
  land.getSurfaceType = self._surface
end

function TestHelicopterUnits:test_a_helicopter_unit_is_marked()
  luaunit.assertTrue(veafUnits.findUnit("Mi-8MT").helicopter)
end

function TestHelicopterUnits:test_an_airplane_is_not_a_helicopter()
  local unit = veafUnits.findUnit("F-16C_50")
  luaunit.assertTrue(unit.air)
  luaunit.assertFalse(unit.helicopter)
end

function TestHelicopterUnits:test_a_group_of_helicopters_is_marked()
  luaunit.assertTrue(helicopterGroupDefinition().helicopter)
end

--- A helicopter is put down **on the ground**: on open water it would sink rather than wait.
function TestHelicopterUnits:test_a_helicopter_refuses_open_water()
  land.getSurfaceType = function()
    return land.SurfaceType.WATER
  end
  -- 10 m up, so the point is not refused for being under the ground: water is what refuses it
  local onTheSurface = { x = 0, y = 10, z = 0 }
  luaunit.assertTrue(veafUnits.checkPositionForUnit(onTheSurface, veafUnits.findUnit("F-16C_50")))
  luaunit.assertFalse(veafUnits.checkPositionForUnit(onTheSurface, veafUnits.findUnit("Mi-8MT")))
end

-- ============================================================================
-- Ticket 02 — `_spawn unit` lands a helicopter, engine off
-- ============================================================================
TestHelicopterSpawnUnit = {}

function TestHelicopterSpawnUnit:setUp()
  dcs_mocks.reset()
  veafAircraftSpawn.groupRoles = {}
end

--- DCS refuses a helicopter submitted as an airplane: `Invalid Unit Module: "Mi-8MT"` (R23, variant A).
function TestHelicopterSpawnUnit:test_it_is_submitted_as_a_helicopter()
  luaunit.assertIsString(spawnHelicopterUnit("Mi-8MT"))
  local _, category = lastSubmission()
  luaunit.assertEquals(category, Unit.Category.HELICOPTER)
end

--- The only variant of R23 that stayed on the ground: one `TakeOffGround` point and `uncontrolled`.
function TestHelicopterSpawnUnit:test_with_no_task_it_stays_parked()
  local name = spawnHelicopterUnit("Mi-8MT")
  local group = lastSubmission()
  luaunit.assertTrue(group.uncontrolled)
  luaunit.assertEquals(#group.route.points, 1)
  luaunit.assertEquals(group.route.points[1].type, "TakeOffGround")
  luaunit.assertEquals(veafAircraftSpawn.getRole(name), "parked")
end

--- On a helicopter the marker's `alt` is the job's altitude: lifting the spawn point to it put the
--- helicopter 500 m up with no speed and no route.
function TestHelicopterSpawnUnit:test_the_marker_altitude_does_not_lift_it()
  spawnHelicopterUnit("Mi-8MT", 500)
  local group = lastSubmission()
  luaunit.assertEquals(group.units[1].alt, veaf.getLandHeight({ x = SPOT.x, y = 0, z = SPOT.z }))
  luaunit.assertEquals(group.units[1].alt_type, "BARO")
end

function TestHelicopterSpawnUnit:test_an_airplane_is_still_refused()
  luaunit.assertNil(spawnHelicopterUnit("F-16C_50"))
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

-- ============================================================================
-- Ticket 02 — `_spawn group` lands a helicopter group
-- ============================================================================
TestHelicopterSpawnGroup = {}

function TestHelicopterSpawnGroup:setUp()
  dcs_mocks.reset()
  veafAircraftSpawn.groupRoles = {}
  self.scheduled = {}
  self._schedule = veaf.scheduleFunction
  local scheduled = self.scheduled
  veaf.scheduleFunction = function(fn, args, time)
    table.insert(scheduled, fn)
    return 1
  end
end

function TestHelicopterSpawnGroup:tearDown()
  veaf.scheduleFunction = self._schedule
end

--- Variant A of R23, the path as it stood: `category = "AIRPLANE"`, refused by DCS.
function TestHelicopterSpawnGroup:test_it_is_submitted_as_a_helicopter()
  luaunit.assertIsString(spawnHelicopterGroup(false))
  local _, category = lastSubmission()
  luaunit.assertEquals(category, Unit.Category.HELICOPTER)
end

function TestHelicopterSpawnGroup:test_with_no_task_it_stays_parked()
  local name = spawnHelicopterGroup(false)
  local group = lastSubmission()
  luaunit.assertTrue(group.uncontrolled)
  luaunit.assertEquals(group.route.points[1].type, "TakeOffGround")
  luaunit.assertEquals(veafAircraftSpawn.getRole(name), "parked")
end

--- `settleGroup` moves the whole group off scenery after the spawn point was chosen: the route has to
--- start where the helicopters stand, not where the group was first meant to go.
function TestHelicopterSpawnGroup:test_the_route_starts_where_the_settled_group_stands()
  local settle = veafUnits.settleGroup
  veafUnits.settleGroup = function(units)
    for _, unit in pairs(units) do
      unit.spawnPoint.x = unit.spawnPoint.x + 80
    end
    return 80
  end
  spawnHelicopterGroup(false)
  veafUnits.settleGroup = settle
  local group = lastSubmission()
  luaunit.assertEquals({ group.route.points[1].x, group.route.points[1].y }, { group.units[1].x, group.units[1].y })
end

--- Every unit refused by the position check leaves no helicopter to build a job from: nothing is
--- spawned, and the command says so rather than failing on a missing first unit.
function TestHelicopterSpawnGroup:test_a_group_with_no_placeable_unit_spawns_nothing()
  -- the group's centre is accepted; every unit position is then refused
  local check = veafUnits.checkPositionForUnit
  veafUnits.checkPositionForUnit = function()
    return false
  end
  local ok, result = pcall(spawnHelicopterGroup, false)
  veafUnits.checkPositionForUnit = check
  luaunit.assertTrue(ok, tostring(result))
  luaunit.assertNil(result)
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

--- A `dest` is where a helicopter flies, not a road: the convoy's pathfinding fix has no unit to remove.
function TestHelicopterSpawnGroup:test_a_destination_does_not_make_it_a_convoy()
  spawnHelicopterGroup(true)
  for _, fn in ipairs(self.scheduled) do
    luaunit.assertNotEquals(fn, veafUnits.removePathfindingFixUnit)
  end
end

-- ============================================================================
-- Ticket 03 — the catalogue's loadout reaches the helicopter
-- ============================================================================
TestHelicopterPayload = {}

function TestHelicopterPayload:setUp()
  dcs_mocks.reset()
  veafAircraftSpawn.groupRoles = {}
  self._units, self._payloads = veafUnits.UnitsDatabase, veafUnits.AircraftPayloads
  veafUnits.UnitsDatabase = {
    { aliases = { "mi24" }, unitType = "Mi-24P", pylons = { [1] = { CLSID = "{ATAKA}" }, [4] = { CLSID = "{GUN}" } } },
    { aliases = { "mi8" }, unitType = "Mi-8MT" },
  }
  veafUnits.AircraftPayloads = {
    ["Mi-24P"] = { fuel = 1701, chaff = 0, flare = 192 },
    ["Mi-8MT"] = { fuel = 1929, chaff = 0, flare = 128 },
  }
end

function TestHelicopterPayload:tearDown()
  veafUnits.UnitsDatabase, veafUnits.AircraftPayloads = self._units, self._payloads
end

function TestHelicopterPayload:test_an_alias_brings_its_pylons()
  luaunit.assertEquals(veafUnits.findUnit("mi24").pylons[4].CLSID, "{GUN}")
end

--- The catalogue entry is not handed out: a spawn that changed its unit would change the catalogue.
function TestHelicopterPayload:test_the_catalogue_pylons_are_copied()
  veafUnits.findUnit("mi24").pylons[4] = nil
  luaunit.assertEquals(veafUnits.findUnit("mi24").pylons[4].CLSID, "{GUN}")
end

function TestHelicopterPayload:test_an_armed_alias_flies_with_its_pylons_and_its_fuel()
  spawnHelicopterUnit("mi24")
  local payload = lastSubmission().units[1].payload
  luaunit.assertEquals(payload.fuel, 1701)
  luaunit.assertEquals(payload.flare, 192)
  luaunit.assertEquals(payload.pylons[1].CLSID, "{ATAKA}")
end

--- Without fuel a spawned aircraft falls out of the sky (`aircraft_payload.py`, measured 2026-08-19).
function TestHelicopterPayload:test_an_unarmed_alias_flies_with_fuel_and_no_pylons()
  spawnHelicopterUnit("mi8")
  local payload = lastSubmission().units[1].payload
  luaunit.assertEquals(payload.fuel, 1929)
  luaunit.assertEquals(payload.pylons, {})
end

function TestHelicopterPayload:test_a_group_unit_flies_with_its_fuel()
  spawnHelicopterGroup(false)
  luaunit.assertEquals(lastSubmission().units[1].payload.fuel, 1929)
end

-- ============================================================================
-- Ticket 04 — `orbit` and `transport`
-- ============================================================================
TestHelicopterJobs = {}

local DEST = { x = 5000, y = 0, z = 6000 }
local ROE = AI.Option.Air.val.ROE

--- The tasks a route point carries, flattened out of its ComboTask.
local function tasksAt(point)
  return (point.task and point.task.params and point.task.params.tasks) or {}
end

--- The ROE the route sets on its first point, or nil.
local function roeOf(points)
  for _, task in ipairs(tasksAt(points[1])) do
    local action = task.params and task.params.action
    if action and action.id == "Option" and action.params.name == AI.Option.Air.id.ROE then
      return action.params.value
    end
  end
end

local function taskOf(point, id)
  for _, task in ipairs(tasksAt(point)) do
    if task.id == id then
      return task
    end
  end
end

local function orbitTaskOf(point)
  return taskOf(point, "Orbit")
end

function TestHelicopterJobs:setUp()
  dcs_mocks.reset()
  veafAircraftSpawn.groupRoles = {}
  self._units, self._getPoint = veafUnits.UnitsDatabase, veafNamedPoints.getPoint
  veafUnits.UnitsDatabase = {
    { aliases = { "mi24" }, unitType = "Mi-24P", pylons = { [1] = { CLSID = "{ATAKA}" } } },
    { aliases = { "mi8" }, unitType = "Mi-8MT" },
  }
  veafNamedPoints.getPoint = function(name)
    if name == "FOB" then
      return DEST
    end
  end
  self.ground = veaf.getLandHeight({ x = SPOT.x, y = 0, z = SPOT.z })
end

function TestHelicopterJobs:tearDown()
  veafUnits.UnitsDatabase, veafNamedPoints.getPoint = self._units, self._getPoint
end

local function routeOf(name, job)
  local spawned = spawnHelicopterUnit(name, 0, job)
  local group = lastSubmission()
  return spawned, group and group.route.points, group
end

--- R23: `TakeOffGroundHot` was airborne 11 s after spawning.
function TestHelicopterJobs:test_orbit_takes_off_at_once_and_circles_its_point()
  local name, points, group = routeOf("mi8", { task = "orbit" })
  luaunit.assertEquals(veafAircraftSpawn.getRole(name), "orbit")
  luaunit.assertNil(group.uncontrolled)
  luaunit.assertEquals(points[1].type, "TakeOffGroundHot")
  local orbit = orbitTaskOf(points[2])
  luaunit.assertEquals(orbit.params.pattern, "Circle")
  luaunit.assertEquals({ points[2].x, points[2].y }, { SPOT.x, SPOT.z })
end

function TestHelicopterJobs:test_orbit_flies_150_m_above_the_ground_at_40_m_s_by_default()
  local _, points = routeOf("mi8", { task = "orbit" })
  local orbit = orbitTaskOf(points[2])
  luaunit.assertEquals(points[2].alt, self.ground + 150)
  luaunit.assertEquals(orbit.params.altitude, self.ground + 150)
  luaunit.assertEquals(orbit.params.speed, 40)
end

function TestHelicopterJobs:test_orbit_takes_the_marker_altitude_and_speed()
  local _, points = routeOf("mi8", { task = "orbit", altitude = 300, speed = 25 })
  luaunit.assertEquals(orbitTaskOf(points[2]).params.altitude, self.ground + 300)
  luaunit.assertEquals(orbitTaskOf(points[2]).params.speed, 25)
end

function TestHelicopterJobs:test_an_armed_orbit_is_weapons_free_and_an_unarmed_one_holds()
  local _, armed = routeOf("mi24", { task = "orbit" })
  luaunit.assertEquals(roeOf(armed), ROE.WEAPON_FREE)
  local _, unarmed = routeOf("mi8", { task = "orbit" })
  luaunit.assertEquals(roeOf(unarmed), ROE.WEAPON_HOLD)
end

function TestHelicopterJobs:test_transport_flies_to_its_destination_and_lands_there()
  local name, points = routeOf("mi8", { task = "transport", destination = "FOB" })
  luaunit.assertEquals(veafAircraftSpawn.getRole(name), "transport")
  luaunit.assertEquals(points[1].type, "TakeOffGroundHot")
  local land = taskOf(points[#points], "Land")
  luaunit.assertEquals(land.params.point, { x = DEST.x, y = DEST.z })
  luaunit.assertFalse(land.params.durationFlag) -- stays down
end

--- R26, 2026-10-02: sent into a forest, the Mi-8 hovered over its edge for minutes, looking for room.
--- The landing point is moved to the nearest clearing the scenery-aware search finds around it.
function TestHelicopterJobs:test_transport_lands_in_the_nearest_clearing()
  local find = veaf.findSpawnPoint
  local asked
  veaf.findSpawnPoint = function(centre, radius, clearance, surfaces, noRandomFallback)
    asked = { radius = radius, clearance = clearance, noRandomFallback = noRandomFallback }
    return { x = centre.x + 120, y = 0, z = centre.z }
  end
  local _, points = routeOf("mi8", { task = "transport", destination = "FOB" })
  veaf.findSpawnPoint = find
  luaunit.assertEquals(taskOf(points[#points], "Land").params.point, { x = DEST.x + 120, y = DEST.z })
  luaunit.assertEquals(asked, {
    radius = veafAircraftSpawn.HELICOPTER_LZ_SEARCH,
    clearance = veafAircraftSpawn.HELICOPTER_LZ_CLEARANCE,
    noRandomFallback = true,
  })
end

--- No clearing in reach is not a refusal: the helicopter is sent to the point and DCS looks around it.
function TestHelicopterJobs:test_with_no_clearing_it_lands_on_the_point_asked()
  local find = veaf.findSpawnPoint
  veaf.findSpawnPoint = function()
    return nil
  end
  local _, points = routeOf("mi8", { task = "transport", destination = "FOB" })
  veaf.findSpawnPoint = find
  luaunit.assertEquals(taskOf(points[#points], "Land").params.point, { x = DEST.x, y = DEST.z })
end

--- R24 and R25, 2026-10-02: a waypoint of type `Land` sent the Mi-8 to Kobuleti's parking, even with
--- its point 2.85 km from the field. The landing is a `Land` task, never a `Land` waypoint.
function TestHelicopterJobs:test_transport_has_no_land_waypoint()
  local _, points = routeOf("mi8", { task = "transport", destination = "FOB" })
  for _, point in ipairs(points) do
    luaunit.assertNotEquals(point.type, "Land")
  end
end

--- R24, 2026-10-02: a cruise point *over* the destination made the Mi-8 overfly it, fly on 1.9 km
--- and come back. The cruise point now sits short of it, on the way in, so the helicopter descends
--- as it arrives.
function TestHelicopterJobs:test_transport_cruises_to_a_point_short_of_its_destination()
  local _, points = routeOf("mi8", { task = "transport", destination = "FOB" })
  local cruise = points[2]
  local toDest = math.sqrt((DEST.x - cruise.x) ^ 2 + (DEST.z - cruise.y) ^ 2)
  local fromSpot = math.sqrt((cruise.x - SPOT.x) ^ 2 + (cruise.y - SPOT.z) ^ 2)
  local spotToDest = math.sqrt((DEST.x - SPOT.x) ^ 2 + (DEST.z - SPOT.z) ^ 2)
  luaunit.assertAlmostEquals(toDest, veafAircraftSpawn.HELICOPTER_APPROACH, 0.01)
  luaunit.assertAlmostEquals(fromSpot + toDest, spotToDest, 0.01) -- on the line in
  luaunit.assertEquals(cruise.alt, veaf.getLandHeight({ x = cruise.x, y = 0, z = cruise.y }) + 150)
end

--- A destination closer than the approach has no room for a cruise point: straight to the landing.
function TestHelicopterJobs:test_a_close_destination_is_flown_straight_to_the_landing()
  veafNamedPoints.getPoint = function()
    return { x = SPOT.x + 100, y = 0, z = SPOT.z }
  end
  local _, points = routeOf("mi8", { task = "transport", destination = "NEAR" })
  luaunit.assertEquals(#points, 2)
  luaunit.assertNotNil(taskOf(points[2], "Land"))
end

function TestHelicopterJobs:test_transport_only_returns_fire_even_armed()
  local _, points = routeOf("mi24", { task = "transport", destination = "FOB" })
  luaunit.assertEquals(roeOf(points), ROE.RETURN_FIRE)
end

function TestHelicopterJobs:test_transport_without_a_destination_is_refused()
  luaunit.assertNil(routeOf("mi8", { task = "transport" }))
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

function TestHelicopterJobs:test_transport_to_an_unknown_point_is_refused()
  luaunit.assertNil(routeOf("mi8", { task = "transport", destination = "NOWHERE" }))
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

--- A fighter role on a helicopter would build a 27 000 ft race-track: the helicopter roles only.
function TestHelicopterJobs:test_a_fighter_role_is_not_a_helicopter_task()
  luaunit.assertNil(routeOf("mi8", { task = "cap" }))
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

-- ============================================================================
-- Tickets 05 and 06 — `patrol`, `attack`, `escort`
-- ============================================================================
TestHelicopterCombatJobs = {}

local CONVOY_AT = { x = 8000, y = 0, z = 9000 }

function TestHelicopterCombatJobs:setUp()
  TestHelicopterJobs.setUp(self)
  dcs_mocks.addGroup("CONVOY", {
    _id = 42,
    getUnits = function()
      return { {
        getPoint = function()
          return CONVOY_AT
        end,
      } }
    end,
  })
end

function TestHelicopterCombatJobs:tearDown()
  TestHelicopterJobs.tearDown(self)
end

--- Every task of every point, with the index of the point that carries it.
local function allTasks(points)
  local result = {}
  for index, point in ipairs(points) do
    for _, task in ipairs(tasksAt(point)) do
      table.insert(result, { index = index, task = task })
    end
  end
  return result
end

local function findTask(points, id)
  for _, entry in ipairs(allTasks(points)) do
    if entry.task.id == id then
      return entry.task, entry.index
    end
  end
end

--- The `SwitchWaypoint` a looping route ends on: `{ from, to }`.
local function loopOf(points)
  for _, entry in ipairs(allTasks(points)) do
    local action = entry.task.params and entry.task.params.action
    if action and action.id == "SwitchWaypoint" then
      return { action.params.fromWaypointIndex, action.params.goToWaypointIndex }
    end
  end
end

local function distance2d(point, x, z)
  return math.sqrt((point.x - x) ^ 2 + (point.y - z) ^ 2)
end

-- ---- patrol, armed ----------------------------------------------------------

function TestHelicopterCombatJobs:test_an_armed_patrol_circuits_around_its_point_for_ever()
  local name, points = routeOf("mi24", { task = "patrol" })
  luaunit.assertEquals(veafAircraftSpawn.getRole(name), "patrol")
  luaunit.assertEquals(points[1].type, "TakeOffGroundHot")
  luaunit.assertEquals(#points, 5) -- take-off, then four corners
  for index = 2, 5 do
    luaunit.assertAlmostEquals(distance2d(points[index], SPOT.x, SPOT.z), veafAircraftSpawn.HELICOPTER_PATROL_LEG, 0.01)
  end
  luaunit.assertEquals(loopOf(points), { 5, 2 })
end

function TestHelicopterCombatJobs:test_an_armed_patrol_engages_ground_units_and_helicopters_around_its_point()
  local _, points = routeOf("mi24", { task = "patrol" })
  local engage = findTask(points, "EngageTargetsInZone")
  luaunit.assertEquals(engage.params.point, { x = SPOT.x, y = SPOT.z })
  luaunit.assertEquals(engage.params.zoneRadius, veafAircraftSpawn.HELICOPTER_ENGAGE_RADIUS)
  luaunit.assertEquals(engage.params.targetTypes, { "Ground Units", "Helicopters" })
  luaunit.assertEquals(roeOf(points), ROE.WEAPON_FREE)
end

function TestHelicopterCombatJobs:test_the_engagement_radius_comes_from_capradius()
  local _, points = routeOf("mi24", { task = "patrol", radius = 5000 })
  luaunit.assertEquals(findTask(points, "EngageTargetsInZone").params.zoneRadius, 5000)
end

function TestHelicopterCombatJobs:test_an_armed_patrol_with_a_destination_goes_to_and_fro()
  local _, points = routeOf("mi24", { task = "patrol", destination = "FOB" })
  luaunit.assertEquals(#points, 3)
  luaunit.assertEquals({ points[2].x, points[2].y }, { DEST.x, DEST.z })
  luaunit.assertEquals({ points[3].x, points[3].y }, { SPOT.x, SPOT.z })
  luaunit.assertEquals(loopOf(points), { 3, 2 })
  -- the zone covers the leg: centred between the two ends
  local engage = findTask(points, "EngageTargetsInZone")
  luaunit.assertEquals(engage.params.point, { x = (SPOT.x + DEST.x) / 2, y = (SPOT.z + DEST.z) / 2 })
end

-- ---- patrol, unarmed: the resupply run --------------------------------------

function TestHelicopterCombatJobs:test_an_unarmed_patrol_shuttles_landing_at_each_end_for_ever()
  local _, points = routeOf("mi8", { task = "patrol", destination = "FOB" })
  local landings = {}
  for _, entry in ipairs(allTasks(points)) do
    if entry.task.id == "Land" then
      table.insert(landings, entry.task.params)
    end
  end
  luaunit.assertEquals(#landings, 2)
  luaunit.assertEquals(landings[1].point, { x = DEST.x, y = DEST.z })
  luaunit.assertEquals(landings[2].point, { x = SPOT.x, y = SPOT.z })
  for _, landing in ipairs(landings) do
    luaunit.assertTrue(landing.durationFlag)
    luaunit.assertEquals(landing.duration, veafAircraftSpawn.HELICOPTER_GROUND_TIME)
  end
  luaunit.assertNotNil(loopOf(points))
  luaunit.assertNil(findTask(points, "EngageTargetsInZone"))
  luaunit.assertEquals(roeOf(points), ROE.RETURN_FIRE)
end

function TestHelicopterCombatJobs:test_an_unarmed_patrol_without_a_destination_is_refused()
  luaunit.assertNil(routeOf("mi8", { task = "patrol" }))
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

-- ---- attack -----------------------------------------------------------------

function TestHelicopterCombatJobs:test_attack_flies_to_its_destination_engages_there_and_stays()
  local name, points = routeOf("mi24", { task = "attack", destination = "FOB" })
  luaunit.assertEquals(veafAircraftSpawn.getRole(name), "attack")
  local last = points[#points]
  luaunit.assertEquals({ last.x, last.y }, { DEST.x, DEST.z })
  local engage = taskOf(last, "EngageTargetsInZone")
  luaunit.assertEquals(engage.params.point, { x = DEST.x, y = DEST.z })
  luaunit.assertEquals(engage.params.targetTypes, { "Ground Units", "Helicopters" })
  luaunit.assertEquals(taskOf(last, "Orbit").params.pattern, "Circle")
  luaunit.assertEquals(roeOf(points), ROE.WEAPON_FREE)
end

function TestHelicopterCombatJobs:test_attack_needs_a_destination_and_weapons()
  luaunit.assertNil(routeOf("mi24", { task = "attack" }))
  luaunit.assertNil(routeOf("mi8", { task = "attack", destination = "FOB" }))
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

-- ---- escort -----------------------------------------------------------------

function TestHelicopterCombatJobs:test_escort_joins_the_ground_group_and_covers_it()
  local name, points = routeOf("mi24", { task = "escort", destination = "CONVOY" })
  luaunit.assertEquals(veafAircraftSpawn.getRole(name), "escort")
  local escort, index = findTask(points, "GroundEscort")
  luaunit.assertEquals(escort.params.groupId, 42)
  luaunit.assertEquals(escort.params.engagementDistMax, veafAircraftSpawn.HELICOPTER_ENGAGE_RADIUS)
  luaunit.assertEquals({ points[index].x, points[index].y }, { CONVOY_AT.x, CONVOY_AT.z })
  luaunit.assertEquals(roeOf(points), ROE.WEAPON_FREE)
end

function TestHelicopterCombatJobs:test_escort_needs_a_group_that_exists_and_weapons()
  luaunit.assertNil(routeOf("mi24", { task = "escort", destination = "NO SUCH GROUP" }))
  luaunit.assertNil(routeOf("mi24", { task = "escort" }))
  luaunit.assertNil(routeOf("mi8", { task = "escort", destination = "CONVOY" }))
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

function TestHelicopterCombatJobs:test_the_marker_capradius_reaches_the_job()
  local job = veafSpawn.helicopterJob(veafSpawn.markTextAnalysis("_spawn unit, name mi24, task patrol, capradius 5000"))
  luaunit.assertEquals(job.radius, 5000)
end

-- ============================================================================
-- Ticket 02 — the marker's `task` reaches the spawn
-- ============================================================================
TestHelicopterMarker = {}

function TestHelicopterMarker:setUp()
  dcs_mocks.reset()
  veafAircraftSpawn.groupRoles = {}
end

local function handler(key)
  for _, entry in ipairs(veafSpawn.commandHandlers) do
    if entry.key == key then
      return entry.fn
    end
  end
end

function TestHelicopterMarker:test_the_marker_reads_a_task()
  local options = veafSpawn.markTextAnalysis("_spawn unit, name mi24, task Orbit")
  luaunit.assertEquals(options.task, "orbit")
end

--- `alt` in feet and `speed` in knots, as for `-afac` and `-cap`; the roles fly metres and m/s.
function TestHelicopterMarker:test_the_marker_altitude_and_speed_are_feet_and_knots()
  local job = veafSpawn.helicopterJob(veafSpawn.markTextAnalysis("_spawn unit, name mi8, task orbit, alt 1000, speed 100"))
  luaunit.assertAlmostEquals(job.altitude, 304.8, 0.01)
  luaunit.assertAlmostEquals(job.speed, 51.44, 0.01)
end

function TestHelicopterMarker:test_no_altitude_or_speed_leaves_the_defaults_to_the_role()
  local job = veafSpawn.helicopterJob(veafSpawn.markTextAnalysis("_spawn unit, name mi8, task orbit"))
  luaunit.assertNil(job.altitude)
  luaunit.assertNil(job.speed)
end

--- Through the `unit` handler: an unknown task is refused, which only happens if the task got there.
function TestHelicopterMarker:test_the_unit_handler_hands_the_task_over()
  local options = veafSpawn.markTextAnalysis("_spawn unit, name Mi-8MT, task nonsense, silent")
  options.radius, options.country = 0, "usa"
  luaunit.assertNil(handler("unit")(SPOT, options, 2, nil, true))
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

function TestHelicopterMarker:test_the_group_handler_hands_the_task_over()
  local original = veafUnits.findGroup
  veafUnits.findGroup = function()
    return helicopterGroupDefinition()
  end
  local options = veafSpawn.markTextAnalysis("_spawn group, name helos, task nonsense, silent")
  options.radius, options.country = 0, "usa"
  local result = handler("group")(SPOT, options, 2, nil, true)
  veafUnits.findGroup = original
  luaunit.assertNil(result)
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

os.exit(luaunit.LuaUnit.run())
