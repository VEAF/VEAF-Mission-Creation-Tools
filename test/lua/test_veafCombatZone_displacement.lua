--- FIX-TRIPACK-FIELD-REPORTS ticket 04 — a combat zone's widely spread group must keep its shape.
---
--- Tripack's `Snowfox_20260903.miz` shows two ZU-23s of `CMBT_ABU_MUSA_AIRPORT` standing in open water
--- kilometres south-west of Abu Musa, with all five ashore in the Mission Editor. The spawn translates
--- the **whole group** by one offset (`veafDcsSpawner._drawOrigin`), measured between the point the zone
--- element declares and the mission record's unit 1. That group is 4 330 m wide, so any mechanism that
--- anchors the element on a unit other than the record's first one moves every ZU-23 by kilometres.
---
--- These tests drive the real path — `VeafCombatZone:initialize` → `buildGroupElement` →
--- `referencePositionOf` → `spawnElement` → `VeafGroupSpawn:respawn` — with the five real editor
--- coordinates as the fixture, and assert on the unit positions actually handed to
--- `coalition.addGroup`. Nothing between the zone and DCS is stubbed.
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
dofile(src .. "/veafI18n.lua")
dofile(src .. "/veafCombatZone.lua")

veaf.config.language = "en"

local ZONE_NAME = "CMBT_ABU_MUSA_AIRPORT"
local GROUP_NAME = ZONE_NAME .. " - AAA"
local ZONE_CENTRE = { x = -31532.5, z = -121253.0 }
local ZONE_RADIUS = 4876.8

--- The five ZU-23s as Tripack drew them, in mission-table shape: `x` is the northing, `y` the easting.
local EDITOR_UNITS = {
  { name = GROUP_NAME .. "-1", unitId = 9001, x = -30382.9, y = -122247.2 },
  { name = GROUP_NAME .. "-2", unitId = 9002, x = -29154.8, y = -120699.3 },
  { name = GROUP_NAME .. "-3", unitId = 9003, x = -31826.8, y = -119503.7 },
  { name = GROUP_NAME .. "-4", unitId = 9004, x = -33555.6, y = -121202.2 },
  { name = GROUP_NAME .. "-5", unitId = 9005, x = -32818.9, y = -123007.7 },
}

-- ---------------------------------------------------------------------------
-- Fixture
-- ---------------------------------------------------------------------------

--- The mission table the zone and the spawner both read, rebuilt from EDITOR_UNITS.
local function buildMissionSnapshot()
  local units = {}
  for _, unit in ipairs(EDITOR_UNITS) do
    table.insert(units, {
      name = unit.name,
      unitId = unit.unitId,
      type = "ZU-23 Closed Insurgent",
      x = unit.x,
      y = unit.y,
      alt = 0,
      heading = 0,
      skill = "Average",
    })
  end
  env.mission.coalition.red = env.mission.coalition.red or {}
  env.mission.coalition.red.country = {
    [1] = {
      -- RUSSIA rather than Tripack's Insurgents: `veafDcsSpawner.addGroup` resolves the country against
      -- the `country` table, and the mocks carry only RUSSIA and USA. Nothing under test reads it.
      name = "RUSSIA",
      id = country.id.RUSSIA,
      vehicle = { group = { { name = GROUP_NAME, groupId = 900, units = units } } },
    },
  }
  veafMissionDb.buildSnapshot()
end

--- Register the live DCS units and their group.
---
--- `liveOrder` is the order `Group:getUnit(n)` answers in — DCS compacts the list as units die, so a
--- destroyed unit 1 makes unit 2 the first one the API hands back.
local function registerLiveGroup(liveOrder)
  local byName = {}
  for _, unit in ipairs(EDITOR_UNITS) do
    dcs_mocks.addUnit(unit.name, {
      _point = { x = unit.x, y = 0, z = unit.y },
      getPoint = function()
        return { x = unit.x, y = 0, z = unit.y }
      end,
      getCoalition = function()
        return coalition.side.RED
      end,
      getGroup = function()
        return Group.getByName(GROUP_NAME)
      end,
    })
    byName[unit.name] = Unit.getByName(unit.name)
  end

  local live = {}
  for _, name in ipairs(liveOrder) do
    table.insert(live, byName[name])
  end

  dcs_mocks.addGroup(GROUP_NAME, {
    getUnits = function()
      return live
    end,
    getUnit = function(_self, index)
      return live[index]
    end,
    getCategory = function()
      return Group.Category.GROUND
    end,
    getCoalition = function()
      return coalition.side.RED
    end,
  })
  return byName
end

--- Everything the zone needs to exist and to find its units, with a flat all-land island.
local function setUpFixture(liveOrder, unitNamesTheZoneSees)
  dcs_mocks.reset()
  dcs_mocks.clearUnitsAndGroups()
  Disposition = nil
  land.getHeight = function()
    return 0
  end
  land.getSurfaceType = function()
    return land.SurfaceType.LAND
  end

  veaf.triggerZones[ZONE_NAME] = {
    name = ZONE_NAME,
    type = 0,
    x = ZONE_CENTRE.x,
    y = ZONE_CENTRE.z,
    radius = ZONE_RADIUS,
  }
  dcs_mocks.addZone(ZONE_NAME, ZONE_CENTRE.x, ZONE_CENTRE.z, ZONE_RADIUS)

  buildMissionSnapshot()
  registerLiveGroup(liveOrder)

  local names = unitNamesTheZoneSees or liveOrder
  veaf.getUnitsNamesOfCoalition = function()
    local copy = {}
    for _, name in ipairs(names) do
      table.insert(copy, name)
    end
    return copy
  end
end

local function tearDownFixture()
  veaf.triggerZones[ZONE_NAME] = nil
  dcs_mocks.zones[ZONE_NAME] = nil
  dcs_mocks.clearUnitsAndGroups()
  dcs_mocks.reset()
end

--- The names of the five ZU-23s, in editor order.
local function editorOrder()
  local names = {}
  for _, unit in ipairs(EDITOR_UNITS) do
    table.insert(names, unit.name)
  end
  return names
end

--- The group the zone last handed `coalition.addGroup`, indexed by the editor unit name it came from.
---
--- The spawner keeps the record's unit order, so entry `n` is `EDITOR_UNITS[n]` moved.
local function spawnedPositions()
  local submitted = dcs_mocks.groupsAdded[#dcs_mocks.groupsAdded]
  if not submitted then
    return nil
  end
  local positions = {}
  for index, unit in ipairs(submitted.group.units) do
    positions[EDITOR_UNITS[index].name] = { x = unit.x, y = unit.y }
  end
  return positions
end

--- How far each spawned unit ended up from where the Mission Editor drew it, in metres.
local function displacements()
  local positions = spawnedPositions()
  if not positions then
    return nil
  end
  local distances = {}
  for _, unit in ipairs(EDITOR_UNITS) do
    local spawned = positions[unit.name]
    local dx, dy = spawned.x - unit.x, spawned.y - unit.y
    distances[unit.name] = math.sqrt(dx * dx + dy * dy)
  end
  return distances
end

local function worstDisplacement()
  local worst, worstName = 0, nil
  for name, distance in pairs(displacements()) do
    if distance > worst then
      worst, worstName = distance, name
    end
  end
  return worst, worstName
end

--- Build the zone as mission start does, then activate it.
local function activateZone()
  local zone = VeafCombatZone:new():setFriendlyName("Abu Musa"):setMissionEditorZoneName(ZONE_NAME):initialize()
  zone:activate()
  return zone
end

-- ---------------------------------------------------------------------------
-- The baseline: nothing wrong, nothing moves
-- ---------------------------------------------------------------------------
TestAbuMusaBaseline = {}

function TestAbuMusaBaseline:setUp()
  setUpFixture(editorOrder())
end

function TestAbuMusaBaseline:tearDown()
  tearDownFixture()
end

function TestAbuMusaBaseline:test_the_zone_builds_one_element_for_the_group()
  local zone = activateZone()
  local elements = zone:getZoneElements()
  luaunit.assertEquals(#elements, 1)
  luaunit.assertEquals(elements[1]:getName(), GROUP_NAME)
  luaunit.assertEquals(elements[1]:getSpawnRadius(), 50, "no #spawnradius tag, so the vehicle default")
end

function TestAbuMusaBaseline:test_the_group_reaches_dcs()
  activateZone()
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 1)
  luaunit.assertEquals(#dcs_mocks.groupsAdded[1].group.units, 5)
end

--- The whole point: with every unit alive and met in editor order, the group keeps its shape and no
--- unit moves further than the 50 m dispersion the default allows.
function TestAbuMusaBaseline:test_no_unit_moves_beyond_the_spawn_radius()
  activateZone()
  local worst, name = worstDisplacement()
  luaunit.assertTrue(worst <= 51, string.format("worst displacement %s m, on %s", tostring(worst), tostring(name)))
end

function TestAbuMusaBaseline:test_the_group_keeps_its_shape()
  activateZone()
  local moved = spawnedPositions()
  -- every unit translated by the same vector, so every spacing is preserved to the metre
  local reference = EDITOR_UNITS[1]
  local dx = moved[reference.name].x - reference.x
  local dy = moved[reference.name].y - reference.y
  for _, unit in ipairs(EDITOR_UNITS) do
    luaunit.assertAlmostEquals(moved[unit.name].x - unit.x, dx, 0.001, unit.name .. " northing")
    luaunit.assertAlmostEquals(moved[unit.name].y - unit.y, dy, 0.001, unit.name .. " easting")
  end
end

-- ---------------------------------------------------------------------------
-- Reading 1 — the anchor is the first *live* unit
-- ---------------------------------------------------------------------------
TestAbuMusaDeadFirstUnit = {}

function TestAbuMusaDeadFirstUnit:tearDown()
  tearDownFixture()
end

--- `referencePositionOf` anchors on `Group:getUnit(1)`, and DCS compacts that list as units die. If a
--- ZU-23 is lost before the zone is built, unit 2 becomes "the first one" — 1 976 m from unit 1 — while
--- the mission record still starts at unit 1. The offset then carries that spacing.
function TestAbuMusaDeadFirstUnit:test_a_dead_first_unit_at_initialize_time_displaces_the_group()
  local survivors = { EDITOR_UNITS[2].name, EDITOR_UNITS[3].name, EDITOR_UNITS[4].name, EDITOR_UNITS[5].name }
  setUpFixture(survivors)
  activateZone()
  local worst, name = worstDisplacement()
  luaunit.assertTrue(
    worst > 1000,
    string.format("expected a kilometre-scale displacement, got %s m on %s", tostring(worst), tostring(name))
  )
end

--- The same loss **after** the zone was built must change nothing: the element holds a position measured
--- once, at initialize, and no later death re-anchors it.
function TestAbuMusaDeadFirstUnit:test_a_unit_lost_after_initialize_does_not_re_anchor_the_element()
  setUpFixture(editorOrder())
  local zone = VeafCombatZone:new():setFriendlyName("Abu Musa"):setMissionEditorZoneName(ZONE_NAME):initialize()
  -- unit 1 is destroyed between the build and the activation
  local live = {}
  for index = 2, #EDITOR_UNITS do
    table.insert(live, Unit.getByName(EDITOR_UNITS[index].name))
  end
  local group = Group.getByName(GROUP_NAME)
  group.getUnit = function(_self, index)
    return live[index]
  end
  group.getUnits = function()
    return live
  end
  dcs_mocks.removeUnit(EDITOR_UNITS[1].name)

  zone:activate()
  local worst, name = worstDisplacement()
  luaunit.assertTrue(worst <= 51, string.format("worst displacement %s m, on %s", tostring(worst), tostring(name)))
end

-- ---------------------------------------------------------------------------
-- Reading 2 — repeated activations must not compound
-- ---------------------------------------------------------------------------
TestAbuMusaRepeatedActivations = {}

function TestAbuMusaRepeatedActivations:setUp()
  setUpFixture(editorOrder())
end

function TestAbuMusaRepeatedActivations:tearDown()
  tearDownFixture()
end

function TestAbuMusaRepeatedActivations:test_five_cycles_never_drift()
  local zone = VeafCombatZone:new():setFriendlyName("Abu Musa"):setMissionEditorZoneName(ZONE_NAME):initialize()
  for cycle = 1, 5 do
    zone:activate()
    local worst, name = worstDisplacement()
    luaunit.assertTrue(
      worst <= 51,
      string.format("cycle %d: worst displacement %s m, on %s", cycle, tostring(worst), tostring(name))
    )
    zone:desactivate()
  end
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 5)
end

-- ---------------------------------------------------------------------------
-- Reading 3 — the zone meets the units in an order of its own
-- ---------------------------------------------------------------------------
TestAbuMusaUnitOrder = {}

function TestAbuMusaUnitOrder:tearDown()
  tearDownFixture()
end

--- `plainUnits[1]` — the first unit the zone happened to meet — must not decide the position: the
--- element anchors on the group's unit 1 whatever order the zone walked in.
function TestAbuMusaUnitOrder:test_meeting_the_units_out_of_order_changes_nothing()
  local reversed = {}
  for index = #EDITOR_UNITS, 1, -1 do
    table.insert(reversed, EDITOR_UNITS[index].name)
  end
  setUpFixture(editorOrder(), reversed)
  activateZone()
  local worst, name = worstDisplacement()
  luaunit.assertTrue(worst <= 51, string.format("worst displacement %s m, on %s", tostring(worst), tostring(name)))
end

--- DCS answering its units in an order that is not the editor's, with every unit alive.
function TestAbuMusaUnitOrder:test_a_live_list_out_of_editor_order_displaces_the_group()
  local shuffled = {
    EDITOR_UNITS[4].name,
    EDITOR_UNITS[1].name,
    EDITOR_UNITS[2].name,
    EDITOR_UNITS[3].name,
    EDITOR_UNITS[5].name,
  }
  setUpFixture(shuffled)
  activateZone()
  local worst = worstDisplacement()
  luaunit.assertTrue(worst > 1000, string.format("expected a kilometre-scale displacement, got %s m", tostring(worst)))
end

os.exit(luaunit.LuaUnit.run())
