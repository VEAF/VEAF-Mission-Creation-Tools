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

--- The group name the current fixture uses. Normally `GROUP_NAME`; a fixture that exercises a
--- `#spawnradius=` tag appends it here, because a combat zone reads its tags from the **names** the
--- Mission Editor gave the group and its units.
local activeGroupName = GROUP_NAME

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
      vehicle = { group = { { name = activeGroupName, groupId = 900, units = units } } },
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
        return Group.getByName(activeGroupName)
      end,
    })
    byName[unit.name] = Unit.getByName(unit.name)
  end

  local live = {}
  for _, name in ipairs(liveOrder) do
    table.insert(live, byName[name])
  end

  dcs_mocks.addGroup(activeGroupName, {
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
---
--- `groupNameOverride` renames the **group** only, so a fixture can carry a `#spawnradius=` tag; the
--- unit names stay as EDITOR_UNITS holds them, which is what `displacements()` keys on.
local function setUpFixture(liveOrder, unitNamesTheZoneSees, groupNameOverride)
  activeGroupName = groupNameOverride or GROUP_NAME
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
  activeGroupName = GROUP_NAME
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

--- The regression. `referencePositionOf` used to anchor on `Group:getUnit(1)`, and DCS compacts that
--- list as units die: with the first ZU-23 lost before the zone is built, unit 2 became "the first one"
--- — 1 976 m from unit 1 — while the mission record still started at unit 1, so the offset carried that
--- spacing and translated all five. Measured before the fix: 1 976 m on every unit. The anchor now comes
--- from the record, so a group that lost its first unit still comes up where it was drawn.
function TestAbuMusaDeadFirstUnit:test_a_dead_first_unit_at_initialize_time_does_not_displace_the_group()
  local survivors = { EDITOR_UNITS[2].name, EDITOR_UNITS[3].name, EDITOR_UNITS[4].name, EDITOR_UNITS[5].name }
  setUpFixture(survivors)
  dcs_mocks.removeUnit(EDITOR_UNITS[1].name)
  activateZone()
  local worst, name = worstDisplacement()
  luaunit.assertTrue(worst <= 51, string.format("worst displacement %s m, on %s", tostring(worst), tostring(name)))
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
    luaunit.assertTrue(worst <= 51, string.format("cycle %d: worst displacement %s m, on %s", cycle, tostring(worst), tostring(name)))
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

--- The second regression, and the one that needs no death at all: DCS answering its units in an order
--- that is not the editor's. `Group:getUnit(1)` was then unit 4 — 3 340 m from the record's unit 1 — and
--- the whole group moved by it (measured before the fix). The anchor is named now, not indexed.
function TestAbuMusaUnitOrder:test_a_live_list_out_of_editor_order_does_not_displace_the_group()
  local shuffled = {
    EDITOR_UNITS[4].name,
    EDITOR_UNITS[1].name,
    EDITOR_UNITS[2].name,
    EDITOR_UNITS[3].name,
    EDITOR_UNITS[5].name,
  }
  setUpFixture(shuffled)
  activateZone()
  local worst, name = worstDisplacement()
  luaunit.assertTrue(worst <= 51, string.format("worst displacement %s m, on %s", tostring(worst), tostring(name)))
end

-- ---------------------------------------------------------------------------
-- `#spawnradius=0` — "these are placed exactly where I want them"
-- ---------------------------------------------------------------------------

--- Tripack asked for a way to keep a zone's elements exactly where he drew them: his Syrian air
--- defences sit in revetments the map provides, and a metre of dispersion puts a launcher on the berm
--- instead of inside it. `#spawnradius=0` is that request, and it already existed — but on its own it
--- was not enough, which is what `veafCombatZone.lua`'s own comment said out loud:
---
--- > Unconditional, including when spawnRadius is 0: the delta is *not* only the dispersion.
---
--- The dispersion was only one of the two terms. The other was the offset between the anchor and the
--- record's unit 1, and it applied whatever the radius — so a group could move with dispersion switched
--- off. Ticket 04 makes both terms zero, so this asserts **exactly zero**, not "within the radius":
--- with no dispersion asked for and every unit alive where the editor put it, a spawn must be the
--- identity.
TestAbuMusaFixedPlacement = {}

local FIXED_GROUP_NAME = GROUP_NAME .. " #spawnradius=0"

function TestAbuMusaFixedPlacement:setUp()
  setUpFixture(editorOrder(), nil, FIXED_GROUP_NAME)
  -- **This is what makes the suite discriminating.** The mocks answer `math.random()` with 0, so
  -- `getRandomPointInCircle` lands exactly on the centre whatever the radius — which means a
  -- "nothing moved" assertion passes with a 50 m radius just as happily as with a zero one, and
  -- proves nothing at all. Measured: without this line, dropping the tag from FIXED_GROUP_NAME
  -- leaves `test_not_one_unit_moves_at_all` green. Feeding 0.5 draws a real displacement of
  -- `50 * sqrt(0.5)` ≈ 35 m for the default radius, while a written zero short-circuits the draw
  -- before it happens (`veafGeo.getRandomPointInCircle`, `if r <= 0`).
  dcs_mocks.setRandomSequence({ 0.5 })
end

function TestAbuMusaFixedPlacement:tearDown()
  dcs_mocks.setRandomSequence(nil)
  tearDownFixture()
end

function TestAbuMusaFixedPlacement:test_the_tag_reaches_the_zone_element()
  local zone = activateZone()
  local elements = zone:getZoneElements()
  luaunit.assertEquals(#elements, 1)
  luaunit.assertEquals(elements[1]:getSpawnRadius(), 0, "#spawnradius=0 must survive as a written zero")
end

--- The promise made to a mission maker who writes `#spawnradius=0`: not "less than the radius", but
--- not one metre. Asserted to the millimetre on all five units.
function TestAbuMusaFixedPlacement:test_not_one_unit_moves_at_all()
  activateZone()
  local moved = spawnedPositions()
  for _, unit in ipairs(EDITOR_UNITS) do
    luaunit.assertAlmostEquals(moved[unit.name].x, unit.x, 0.001, unit.name .. " northing moved")
    luaunit.assertAlmostEquals(moved[unit.name].y, unit.y, 0.001, unit.name .. " easting moved")
  end
end

--- And the terrain search must not even be consulted: tier 1 exists to *move* a point, so a zero radius
--- has to skip it. If `findSpawnPoint` ran, a scenery-aware candidate could displace the group despite
--- the tag.
function TestAbuMusaFixedPlacement:test_the_spawn_point_search_is_not_consulted()
  local searched = false
  local realFindSpawnPoint = veaf.findSpawnPoint
  veaf.findSpawnPoint = function(...)
    searched = true
    return realFindSpawnPoint(...)
  end
  activateZone()
  veaf.findSpawnPoint = realFindSpawnPoint
  luaunit.assertFalse(searched, "a zero spawn radius must not search for a spawn point")
end

-- ---------------------------------------------------------------------------
-- FIX-SPAWN-ANCHOR-AND-STATIC-SHIPS ticket 01 — the anchor is read at the editor's instant
-- ---------------------------------------------------------------------------

--- FIX-TRIPACK-FIELD-REPORTS ticket 04 made both ends of the offset read the same *source*. It was
--- not enough: the anchor was that unit's **live** position while `_drawOrigin` subtracts its
--- **editor** position, so the offset was whatever unit 1 had drifted since mission start — and it
--- was applied to every unit of the group.
---
--- `initialize()` runs seconds into a mission, so a pre-placed ship already under way or a CAP already
--- airborne carried it. Tripack's ZU-23s stand still, which is why his report never showed this half.
TestAbuMusaDriftedAnchor = {}

function TestAbuMusaDriftedAnchor:tearDown()
  tearDownFixture()
end

--- Move the live unit 1 away from where the editor drew it, leaving the other four in place.
---
--- The already-registered object is edited in place rather than re-registered: `registerLiveGroup`
--- captured the unit references when it built the group, so replacing the entry would leave the group
--- holding the old object and the drift invisible.
local function driftUnitOne(metres)
  local drifted = EDITOR_UNITS[1]
  local unit = Unit.getByName(drifted.name)
  local moved = { x = drifted.x + metres, y = 0, z = drifted.y }
  unit._point = moved
  unit.getPoint = function()
    return moved
  end
  unit.getPosition = function()
    return { p = moved }
  end
end

--- The measurement: 100 m of drift used to translate all five units by 100 m.
function TestAbuMusaDriftedAnchor:test_a_drifted_first_unit_does_not_drag_the_group()
  setUpFixture(editorOrder())
  driftUnitOne(100)
  activateZone()
  local worst, name = worstDisplacement()
  luaunit.assertTrue(worst <= 51, string.format("worst displacement %s m, on %s", tostring(worst), tostring(name)))
end

--- And with no dispersion asked for, the promise is exact: the group is put back where it was drawn,
--- however far its first unit had got. This is the behaviour David chose on 2026-09-07 — a respawn
--- returns a group to its drawn position rather than to wherever it had reached.
function TestAbuMusaDriftedAnchor:test_a_drifted_first_unit_still_lands_on_the_editor_positions()
  setUpFixture(editorOrder(), nil, GROUP_NAME .. " #spawnradius=0")
  driftUnitOne(1500)
  activateZone()
  local moved = spawnedPositions()
  for _, unit in ipairs(EDITOR_UNITS) do
    luaunit.assertAlmostEquals(moved[unit.name].x, unit.x, 0.001, unit.name .. " northing")
    luaunit.assertAlmostEquals(moved[unit.name].y, unit.y, 0.001, unit.name .. " easting")
  end
end

os.exit(luaunit.LuaUnit.run())
