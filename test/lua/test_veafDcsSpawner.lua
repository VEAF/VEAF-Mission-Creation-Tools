--- Tests for the runtime static spawner — DROP-MIST ticket 07, half (A).
--
-- This replaces `mist.dynAddStatic`, the call behind every static VEAF puts into a running mission:
-- FARP furniture and runway plots (12 of the 18 call sites, all in veafGrass), the FARP itself, an
-- outpost, a tower, cargo, a `-spawn static`, and a static aircraft.
--
-- What is asserted is what reaches `coalition.addStaticObject`, because that is the only thing DCS
-- ever sees. The mock records the submission rather than discarding it.
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

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- The last object submitted to DCS.
local function submitted()
  local entries = dcs_mocks.staticsAdded
  return entries[#entries] and entries[#entries].object
end

local function countrySubmitted()
  local entries = dcs_mocks.staticsAdded
  return entries[#entries] and entries[#entries].countryId
end

--- Sentinel meaning "remove this field", since `{ name = nil }` creates no key at all and `pairs`
--- would never see it — the default would quietly survive and the test would assert nothing.
local NONE = {}

--- A minimal valid static: mission-table shape, x northing and y easting.
local function _static(overrides)
  local object = { type = "outpost", country = "USA", x = 1000, y = 2000, name = "thing" }
  for key, value in pairs(overrides or {}) do
    if value == NONE then
      object[key] = nil
    else
      object[key] = value
    end
  end
  return object
end

-- ---------------------------------------------------------------------------
-- TestVeafDcsSpawnerAddStatic
-- ---------------------------------------------------------------------------
TestVeafDcsSpawnerAddStatic = {}

function TestVeafDcsSpawnerAddStatic:setUp()
  dcs_mocks.reset()
end

function TestVeafDcsSpawnerAddStatic:test_a_valid_static_reaches_dcs()
  local result = veafDcsSpawner.addStatic(_static())

  luaunit.assertNotNil(result)
  luaunit.assertEquals(#dcs_mocks.staticsAdded, 1)
  luaunit.assertEquals(submitted().type, "outpost")
end

function TestVeafDcsSpawnerAddStatic:test_the_coordinates_are_passed_through_untouched()
  -- x is the northing, y the **easting** — the mission-table shape. veafSpawnGround writes
  -- `["y"] = spawnPosition.z` on purpose, and a port that "fixes" it moves every static.
  veafDcsSpawner.addStatic(_static({ x = 12345, y = -6789 }))

  luaunit.assertEquals(submitted().x, 12345)
  luaunit.assertEquals(submitted().y, -6789)
  luaunit.assertNil(submitted().z, "a static's table has no z")
end

function TestVeafDcsSpawnerAddStatic:test_the_country_is_resolved_to_its_id()
  veafDcsSpawner.addStatic(_static({ country = "USA" }))

  luaunit.assertEquals(countrySubmitted(), country.id.USA)
end

function TestVeafDcsSpawnerAddStatic:test_a_country_id_is_accepted_as_well_as_a_name()
  veafDcsSpawner.addStatic(_static({ country = NONE, countryId = country.id.RUSSIA }))

  luaunit.assertEquals(countrySubmitted(), country.id.RUSSIA)
end

function TestVeafDcsSpawnerAddStatic:test_a_country_name_is_matched_case_insensitively()
  veafDcsSpawner.addStatic(_static({ country = "usa" }))

  luaunit.assertEquals(countrySubmitted(), country.id.USA)
end

function TestVeafDcsSpawnerAddStatic:test_an_unknown_country_creates_nothing()
  -- Loud, not silent: an object with no country cannot belong to anyone.
  luaunit.assertFalse(veafDcsSpawner.addStatic(_static({ country = "Atlantis" })))
  luaunit.assertEquals(#dcs_mocks.staticsAdded, 0)
end

function TestVeafDcsSpawnerAddStatic:test_a_static_without_coordinates_creates_nothing()
  luaunit.assertFalse(veafDcsSpawner.addStatic(_static({ x = NONE })))
  luaunit.assertFalse(veafDcsSpawner.addStatic(_static({ y = "over there" })))
  luaunit.assertEquals(#dcs_mocks.staticsAdded, 0)
end

function TestVeafDcsSpawnerAddStatic:test_a_static_without_a_type_creates_nothing()
  luaunit.assertFalse(veafDcsSpawner.addStatic(_static({ type = NONE })))
  luaunit.assertEquals(#dcs_mocks.staticsAdded, 0)
end

function TestVeafDcsSpawnerAddStatic:test_the_caller_table_is_not_mutated()
  -- The caller keeps its own table: veafGrass reuses a template across several plots.
  local original = _static({ heading = NONE })

  veafDcsSpawner.addStatic(original)

  luaunit.assertNil(original.heading, "the caller's table must not gain a heading")
  luaunit.assertNil(original.unitId, "nor an id")
end

-- ---------------------------------------------------------------------------
-- The four behaviours the port had to preserve deliberately
-- ---------------------------------------------------------------------------

function TestVeafDcsSpawnerAddStatic:test_the_mist_wrapper_form_is_flattened()
  -- veafSpawnAircraft:187 is the only site passing { country, groupName, units = { … } }.
  veafDcsSpawner.addStatic({
    country = "USA",
    groupName = "static flight",
    units = { [1] = { type = "outpost", x = 500, y = 600, name = "the unit" } },
  })

  luaunit.assertEquals(#dcs_mocks.staticsAdded, 1, "the wrapper form must still create the object")
  luaunit.assertEquals(submitted().type, "outpost")
  luaunit.assertEquals(submitted().x, 500)
  luaunit.assertEquals(submitted().name, "the unit")
end

function TestVeafDcsSpawnerAddStatic:test_a_static_with_no_heading_gets_a_random_one()
  -- Nothing in veafSpawnEffects sets a heading. Defaulting to zero would line every cargo drop up on
  -- the same axis — visible in game, invisible to a test that only checks the object exists.
  dcs_mocks.setRandomSequence({ 0.5 })

  veafDcsSpawner.addStatic(_static({ heading = NONE }))

  luaunit.assertNotNil(submitted().heading)
  luaunit.assertTrue(submitted().heading > 0, "a drawn heading, not zero")
end

function TestVeafDcsSpawnerAddStatic:test_a_heading_that_was_given_is_kept()
  veafDcsSpawner.addStatic(_static({ heading = 1.25 }))

  luaunit.assertEquals(submitted().heading, 1.25)
end

function TestVeafDcsSpawnerAddStatic:test_mass_forces_the_cargo_category()
  veafDcsSpawner.addStatic(_static({ category = "Fortifications", mass = 500 }))

  luaunit.assertEquals(submitted().category, "Cargos", "mass overrides whatever the caller said")
end

function TestVeafDcsSpawnerAddStatic:test_categoryStatic_is_an_alias_for_category()
  -- The spelling veafGrass uses throughout for its FARP furniture.
  veafDcsSpawner.addStatic(_static({ categoryStatic = "Fortifications" }))

  luaunit.assertEquals(submitted().category, "Fortifications")
end

-- ---------------------------------------------------------------------------
-- Shapes
-- ---------------------------------------------------------------------------

function TestVeafDcsSpawnerAddStatic:test_a_shape_given_explicitly_is_kept()
  -- The FARP, the windsock and the runway cones all pass their own shape.
  veafDcsSpawner.addStatic(_static({ shape_name = "invisiblefarp" }))

  luaunit.assertEquals(submitted().shape_name, "invisiblefarp")
end

function TestVeafDcsSpawnerAddStatic:test_shapeName_is_an_alias_for_shape_name()
  veafDcsSpawner.addStatic(_static({ shapeName = "H-Windsock_RW" }))

  luaunit.assertEquals(submitted().shape_name, "H-Windsock_RW")
end

function TestVeafDcsSpawnerAddStatic:test_a_known_type_gets_its_shape_from_the_table()
  -- The reason the 124-entry table is ported at all: `-spawn static, Cafe` supplies no shape, and 93
  -- of the catalogue's types need one.
  veafDcsSpawner.addStatic(_static({ type = "Cafe" }))

  luaunit.assertEquals(submitted().shape_name, "stolovaya")
end

function TestVeafDcsSpawnerAddStatic:test_an_unknown_type_is_submitted_without_a_shape()
  -- "outpost" is not in the table, and MiST submitted it anyway.
  veafDcsSpawner.addStatic(_static({ type = "outpost" }))

  luaunit.assertEquals(#dcs_mocks.staticsAdded, 1)
  luaunit.assertNil(submitted().shape_name)
end

function TestVeafDcsSpawnerAddStatic:test_the_shape_table_carries_the_whole_mist_set()
  local count = 0
  for _ in pairs(veafDcsSpawner.SHAPE_NAMES) do
    count = count + 1
  end

  luaunit.assertEquals(count, 124, "the table is ported verbatim, not filtered")
  luaunit.assertEquals(veafDcsSpawner.SHAPE_NAMES["FARP"], "farps")
end

-- ---------------------------------------------------------------------------
-- Identity
-- ---------------------------------------------------------------------------

function TestVeafDcsSpawnerAddStatic:test_ids_are_allocated_when_absent()
  veafDcsSpawner.addStatic(_static())

  luaunit.assertNotNil(submitted().unitId)
  luaunit.assertNotNil(submitted().groupId)
  luaunit.assertTrue(submitted().unitId >= veafMissionDb.FIRST_UNIT_ID, "ids come from VEAF's own allocator")
end

function TestVeafDcsSpawnerAddStatic:test_an_id_that_was_given_is_kept()
  veafDcsSpawner.addStatic(_static({ unitId = 4242, groupId = 77 }))

  luaunit.assertEquals(submitted().unitId, 4242)
  luaunit.assertEquals(submitted().groupId, 77)
end

function TestVeafDcsSpawnerAddStatic:test_two_statics_never_share_a_unit_id()
  veafDcsSpawner.addStatic(_static({ name = "one" }))
  veafDcsSpawner.addStatic(_static({ name = "two" }))

  luaunit.assertNotEquals(dcs_mocks.staticsAdded[1].object.unitId, dcs_mocks.staticsAdded[2].object.unitId)
end

function TestVeafDcsSpawnerAddStatic:test_a_nameless_static_is_named_after_its_country()
  veafDcsSpawner.addStatic(_static({ name = NONE }))

  luaunit.assertNotNil(submitted().name)
  luaunit.assertStrContains(submitted().name, "USA")
end

function TestVeafDcsSpawnerAddStatic:test_unitName_serves_as_the_name()
  veafDcsSpawner.addStatic(_static({ name = NONE, unitName = "windsock 3" }))

  luaunit.assertEquals(submitted().name, "windsock 3")
end

function TestVeafDcsSpawnerAddStatic:test_dead_defaults_to_false_and_is_not_overwritten()
  veafDcsSpawner.addStatic(_static())
  luaunit.assertEquals(submitted().dead, false)

  veafDcsSpawner.addStatic(_static({ dead = true }))
  luaunit.assertEquals(submitted().dead, true, "a caller asking for a wreck must get one")
end

function TestVeafDcsSpawnerAddStatic:test_nothing_at_all_is_survivable()
  luaunit.assertFalse(veafDcsSpawner.addStatic(nil))
  luaunit.assertEquals(#dcs_mocks.staticsAdded, 0)
end

-- ---------------------------------------------------------------------------
-- TestVeafDcsSpawnerRoutes
-- ---------------------------------------------------------------------------
-- `getGroupRoute` replaces `mist.getGroupRoute(name, "task")` — every one of the eight VEAF call sites
-- passed "task", so the task-less form is not ported.
TestVeafDcsSpawnerRoutes = {}

function TestVeafDcsSpawnerRoutes:setUp()
  dcs_mocks.reset()
end

--- Put a group with a route into the mocked mission, and index it the way startup does.
function TestVeafDcsSpawnerRoutes:_mission(groupName, route)
  env.mission.coalition.blue.country = {
    [1] = { name = "USA", id = country.id.USA, plane = { group = { { name = groupName, groupId = 42, route = route, units = {} } } } },
  }
  veafMissionDb.buildSnapshot()
end

function TestVeafDcsSpawnerRoutes:test_the_route_points_are_returned()
  self:_mission("Arco", { points = { { x = 1, y = 2 }, { x = 3, y = 4 } } })

  local route = veafDcsSpawner.getGroupRoute("Arco")

  luaunit.assertNotNil(route)
  luaunit.assertEquals(#route, 2)
end

function TestVeafDcsSpawnerRoutes:test_the_projection_carries_the_fields_callers_read()
  self:_mission("Arco", {
    points = {
      { x = 10, y = 20, speed = 200, alt = 6000, alt_type = "BARO", action = "Turning Point", type = "Turning Point", airdromeId = 7 },
    },
  })

  local point = veafDcsSpawner.getGroupRoute("Arco")[1]

  luaunit.assertEquals(point.x, 10)
  luaunit.assertEquals(point.y, 20, "y is the easting, as the mission table holds it")
  luaunit.assertEquals(point.speed, 200)
  luaunit.assertEquals(point.alt, 6000)
  luaunit.assertEquals(point.alt_type, "BARO")
  luaunit.assertEquals(point.airdromeId, 7)
  luaunit.assertEquals(point.form, "Turning Point", "MiST called the action `form` as well, and callers read it")
  luaunit.assertEquals(point.action, "Turning Point")
end

function TestVeafDcsSpawnerRoutes:test_the_task_is_carried()
  -- Always: the eight call sites all asked for it.
  self:_mission("Arco", { points = { { x = 1, y = 2, task = { id = "ComboTask" } } } })

  luaunit.assertEquals(veafDcsSpawner.getGroupRoute("Arco")[1].task.id, "ComboTask")
end

function TestVeafDcsSpawnerRoutes:test_a_vec2_point_shape_is_preserved()
  -- The editor can write `point = {x, y}` instead of loose coordinates; MiST kept whichever it found.
  self:_mission("Arco", { points = { { point = { x = 5, y = 6 } } } })

  local point = veafDcsSpawner.getGroupRoute("Arco")[1]

  luaunit.assertNotNil(point.point)
  luaunit.assertEquals(point.point.x, 5)
  luaunit.assertNil(point.x, "the loose form must not be invented alongside it")
end

function TestVeafDcsSpawnerRoutes:test_an_unknown_group_returns_nil()
  self:_mission("Arco", { points = { { x = 1, y = 2 } } })

  luaunit.assertNil(veafDcsSpawner.getGroupRoute("Nobody"))
end

function TestVeafDcsSpawnerRoutes:test_a_group_without_a_route_returns_nil()
  self:_mission("Arco", nil)

  luaunit.assertNil(veafDcsSpawner.getGroupRoute("Arco"))
end

function TestVeafDcsSpawnerRoutes:test_an_empty_route_returns_nil()
  self:_mission("Arco", { points = {} })

  luaunit.assertNil(veafDcsSpawner.getGroupRoute("Arco"), "no points is not a route")
end

function TestVeafDcsSpawnerRoutes:test_the_caller_cannot_reach_into_the_mission_table()
  -- The projection is a new table; MiST's was too. A caller that mutates its route must not rewrite
  -- what the Mission Editor placed.
  self:_mission("Arco", { points = { { x = 1, y = 2, speed = 100 } } })

  local route = veafDcsSpawner.getGroupRoute("Arco")
  route[1].speed = 999

  luaunit.assertEquals(veafDcsSpawner.getGroupRoute("Arco")[1].speed, 100)
end

-- ---------------------------------------------------------------------------
-- goRoute
-- ---------------------------------------------------------------------------

function TestVeafDcsSpawnerRoutes:test_goRoute_sets_a_mission_task_on_the_group()
  dcs_mocks.addGroup("Convoy", { _id = 5 })

  luaunit.assertTrue(veafDcsSpawner.goRoute("Convoy", { { x = 1, y = 2 } }))

  local entry = dcs_mocks.tasksSet[#dcs_mocks.tasksSet]
  luaunit.assertEquals(entry.group, "Convoy")
  luaunit.assertEquals(entry.task.id, "Mission")
  luaunit.assertEquals(#entry.task.params.route.points, 1)
end

function TestVeafDcsSpawnerRoutes:test_goRoute_accepts_a_group_object()
  -- veaf.lua and veafSpawnCore pass the object; the other seven sites pass the name.
  dcs_mocks.addGroup("Convoy", { _id = 5 })

  luaunit.assertTrue(veafDcsSpawner.goRoute(Group.getByName("Convoy"), { { x = 1, y = 2 } }))
end

function TestVeafDcsSpawnerRoutes:test_goRoute_on_an_unknown_group_is_false_not_an_error()
  luaunit.assertFalse(veafDcsSpawner.goRoute("Ghost", { { x = 1, y = 2 } }))
end

function TestVeafDcsSpawnerRoutes:test_goRoute_copies_the_route_it_is_given()
  dcs_mocks.addGroup("Convoy", { _id = 5 })
  local route = { { x = 1, y = 2 } }

  veafDcsSpawner.goRoute("Convoy", route)
  route[1].x = 999

  luaunit.assertEquals(dcs_mocks.tasksSet[#dcs_mocks.tasksSet].task.params.route.points[1].x, 1)
end

-- ---------------------------------------------------------------------------
-- TestVeafDcsSpawnerAddGroup
-- ---------------------------------------------------------------------------
-- Replaces `mist.dynAdd`, which was a **no-op stub** in these mocks and which no test ever overrode.
-- The 13 call sites it serves were therefore never exercised; the branches below come from the
-- call-site enumeration in DROP-MIST ticket 07.
TestVeafDcsSpawnerAddGroup = {}

function TestVeafDcsSpawnerAddGroup:setUp()
  dcs_mocks.reset()
end

local function _group(overrides)
  local group = {
    country = "USA",
    category = "GROUND_UNIT",
    name = "a group",
    units = { { type = "M-1 Abrams", x = 100, y = 200 } },
  }
  for key, value in pairs(overrides or {}) do
    if value == NONE then
      group[key] = nil
    else
      group[key] = value
    end
  end
  return group
end

local function submittedGroup()
  local entries = dcs_mocks.groupsAdded
  return entries[#entries] and entries[#entries].group
end

local function submittedCategory()
  local entries = dcs_mocks.groupsAdded
  return entries[#entries] and entries[#entries].categoryId
end

function TestVeafDcsSpawnerAddGroup:test_a_valid_group_reaches_dcs()
  luaunit.assertNotNil(veafDcsSpawner.addGroup(_group()))

  luaunit.assertEquals(#dcs_mocks.groupsAdded, 1)
  luaunit.assertEquals(submittedGroup().name, "a group")
end

-- The categories the enumeration found, including the two spellings of the same thing -------------

function TestVeafDcsSpawnerAddGroup:test_ground_units()
  veafDcsSpawner.addGroup(_group({ category = "GROUND_UNIT" }))

  luaunit.assertEquals(submittedCategory(), Unit.Category.GROUND_UNIT)
end

function TestVeafDcsSpawnerAddGroup:test_airplane_spelled_AIRPLANE()
  -- veafSpawnCore.lua:794
  veafDcsSpawner.addGroup(_group({ category = "AIRPLANE" }))

  luaunit.assertEquals(submittedCategory(), Unit.Category.AIRPLANE)
end

function TestVeafDcsSpawnerAddGroup:test_airplane_spelled_PLANE()
  -- veafSpawnAircraft.lua:191 passes this spelling for the same thing. MiST mapped it; a port that
  -- only accepted the canonical name would break that site and say nothing.
  veafDcsSpawner.addGroup(_group({ category = "PLANE" }))

  luaunit.assertEquals(submittedCategory(), Unit.Category.AIRPLANE)
end

function TestVeafDcsSpawnerAddGroup:test_ship()
  veafDcsSpawner.addGroup(_group({ category = "SHIP" }))

  luaunit.assertEquals(submittedCategory(), Unit.Category.SHIP)
end

function TestVeafDcsSpawnerAddGroup:test_helicopter()
  -- Never a literal at a call site, but it arrives through the three sites that pass a group table
  -- built from a template.
  veafDcsSpawner.addGroup(_group({ category = "HELICOPTER" }))

  luaunit.assertEquals(submittedCategory(), Unit.Category.HELICOPTER)
end

function TestVeafDcsSpawnerAddGroup:test_the_ground_aliases_are_accepted()
  for _, spelling in ipairs({ "VEHICLE", "GROUND", "ground_unit" }) do
    dcs_mocks.reset()
    veafDcsSpawner.addGroup(_group({ category = spelling }))
    luaunit.assertEquals(submittedCategory(), Unit.Category.GROUND_UNIT, spelling .. " must resolve to ground")
  end
end

function TestVeafDcsSpawnerAddGroup:test_an_unknown_category_creates_nothing_and_says_so()
  -- MiST left the type nil and submitted the group anyway, so a typo produced a group DCS could not
  -- classify and nobody was told.
  luaunit.assertFalse(veafDcsSpawner.addGroup(_group({ category = "SUBMARINE" })))
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

-- What it fills in --------------------------------------------------------------------------------

function TestVeafDcsSpawnerAddGroup:test_ids_are_allocated()
  veafDcsSpawner.addGroup(_group())

  luaunit.assertNotNil(submittedGroup().groupId)
  luaunit.assertNotNil(submittedGroup().units[1].unitId)
  luaunit.assertTrue(submittedGroup().groupId >= veafMissionDb.FIRST_UNIT_ID)
end

function TestVeafDcsSpawnerAddGroup:test_given_ids_are_kept()
  veafDcsSpawner.addGroup(_group({ groupId = 11, units = { { type = "M-1 Abrams", x = 1, y = 2, unitId = 22 } } }))

  luaunit.assertEquals(submittedGroup().groupId, 11)
  luaunit.assertEquals(submittedGroup().units[1].unitId, 22)
end

function TestVeafDcsSpawnerAddGroup:test_a_unit_with_no_name_is_named_after_its_group()
  veafDcsSpawner.addGroup(_group({ name = "Convoy" }))

  luaunit.assertEquals(submittedGroup().units[1].name, "Convoy unit1")
end

function TestVeafDcsSpawnerAddGroup:test_groupName_is_accepted_as_the_name()
  veafDcsSpawner.addGroup(_group({ name = NONE, groupName = "from groupName" }))

  luaunit.assertEquals(submittedGroup().name, "from groupName")
end

function TestVeafDcsSpawnerAddGroup:test_skill_defaults_to_random()
  veafDcsSpawner.addGroup(_group())

  luaunit.assertEquals(submittedGroup().units[1].skill, "Random")
end

function TestVeafDcsSpawnerAddGroup:test_a_ground_unit_can_be_driven_by_a_player()
  veafDcsSpawner.addGroup(_group())

  luaunit.assertTrue(submittedGroup().units[1].playerCanDrive)
end

function TestVeafDcsSpawnerAddGroup:test_startTime_is_rounded_into_start_time()
  veafDcsSpawner.addGroup(_group({ startTime = 12.7 }))

  luaunit.assertEquals(submittedGroup().start_time, 13)
end

function TestVeafDcsSpawnerAddGroup:test_start_time_defaults_to_zero()
  veafDcsSpawner.addGroup(_group())

  luaunit.assertEquals(submittedGroup().start_time, 0)
end

-- Aircraft ----------------------------------------------------------------------------------------

function TestVeafDcsSpawnerAddGroup:test_an_airplane_gets_its_cruise_defaults()
  veafDcsSpawner.addGroup(_group({ category = "AIRPLANE", units = { { type = "F-16C_50", x = 1, y = 2 } } }))

  luaunit.assertEquals(submittedGroup().units[1].speed, 150)
  luaunit.assertEquals(submittedGroup().units[1].alt, 2000)
  luaunit.assertEquals(submittedGroup().units[1].alt_type, "RADIO")
end

function TestVeafDcsSpawnerAddGroup:test_a_helicopter_gets_slower_and_lower_defaults()
  veafDcsSpawner.addGroup(_group({ category = "HELICOPTER", units = { { type = "UH-1H", x = 1, y = 2 } } }))

  luaunit.assertEquals(submittedGroup().units[1].speed, 60)
  luaunit.assertEquals(submittedGroup().units[1].alt, 500)
end

function TestVeafDcsSpawnerAddGroup:test_a_baro_altitude_is_left_alone()
  veafDcsSpawner.addGroup(_group({
    category = "AIRPLANE",
    units = { { type = "F-16C_50", x = 1, y = 2, alt = 9000, alt_type = "BARO" } },
  }))

  luaunit.assertEquals(submittedGroup().units[1].alt_type, "BARO", "a caller asking for barometric altitude means it")
  luaunit.assertEquals(submittedGroup().units[1].alt, 9000)
end

function TestVeafDcsSpawnerAddGroup:test_an_aircraft_with_no_route_gets_an_empty_one()
  -- Without it DCS sends the aircraft home the moment it spawns.
  veafDcsSpawner.addGroup(_group({ category = "AIRPLANE", units = { { type = "F-16C_50", x = 1, y = 2 } } }))

  luaunit.assertNotNil(submittedGroup().route)
  luaunit.assertNotNil(submittedGroup().route.points)
end

function TestVeafDcsSpawnerAddGroup:test_a_ground_group_with_no_route_gets_none_invented()
  veafDcsSpawner.addGroup(_group())

  luaunit.assertNil(submittedGroup().route)
end

function TestVeafDcsSpawnerAddGroup:test_a_bare_list_of_points_is_wrapped_into_a_route()
  veafDcsSpawner.addGroup(_group({ route = { { x = 1, y = 2 }, { x = 3, y = 4 } } }))

  luaunit.assertNotNil(submittedGroup().route.points)
  luaunit.assertEquals(#submittedGroup().route.points, 2)
end

-- The payload, which is why the snapshot carries it ------------------------------------------------

function TestVeafDcsSpawnerAddGroup:test_an_aircraft_without_a_payload_gets_the_editor_one()
  env.mission.coalition.blue.country = {
    [1] = {
      name = "USA",
      id = country.id.USA,
      plane = {
        group = { { name = "Template", groupId = 7, units = { { name = "Template-1", unitId = 3, payload = { fuel = 5000 } } } } },
      },
    },
  }
  veafMissionDb.buildSnapshot()

  veafDcsSpawner.addGroup(_group({
    category = "AIRPLANE",
    units = { { type = "F-16C_50", x = 1, y = 2, unitName = "Template-1" } },
  }))

  luaunit.assertNotNil(submittedGroup().units[1].payload, "the loadout must come from the mission")
  luaunit.assertEquals(submittedGroup().units[1].payload.fuel, 5000)
end

function TestVeafDcsSpawnerAddGroup:test_a_payload_that_was_given_is_kept()
  veafDcsSpawner.addGroup(_group({
    category = "AIRPLANE",
    units = { { type = "F-16C_50", x = 1, y = 2, payload = { fuel = 1 } } },
  }))

  luaunit.assertEquals(submittedGroup().units[1].payload.fuel, 1)
end

-- Tasks that name the ids just allocated -----------------------------------------------------------

function TestVeafDcsSpawnerAddGroup:test_an_eplrs_task_points_at_the_new_group_id()
  local group = _group({
    route = { points = { { task = { params = { tasks = { { params = { action = { id = "EPLRS", params = { groupId = 999 } } } } } } } } } },
  })

  veafDcsSpawner.addGroup(group)

  local action = submittedGroup().route.points[1].task.params.tasks[1].params.action
  luaunit.assertEquals(action.params.groupId, submittedGroup().groupId)
end

function TestVeafDcsSpawnerAddGroup:test_a_beacon_task_points_at_the_new_unit_id()
  local group = _group({
    route = {
      points = { { task = { params = { tasks = { { params = { action = { id = "ActivateBeacon", params = { unitId = 999 } } } } } } } } },
    },
  })

  veafDcsSpawner.addGroup(group)

  local action = submittedGroup().route.points[1].task.params.tasks[1].params.action
  luaunit.assertEquals(action.params.unitId, submittedGroup().units[1].unitId)
end

-- Refusals and hygiene -----------------------------------------------------------------------------

function TestVeafDcsSpawnerAddGroup:test_a_group_with_no_units_creates_nothing()
  luaunit.assertFalse(veafDcsSpawner.addGroup(_group({ units = {} })))
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 0)
end

function TestVeafDcsSpawnerAddGroup:test_an_unknown_country_creates_nothing()
  luaunit.assertFalse(veafDcsSpawner.addGroup(_group({ country = "Atlantis" })))
end

function TestVeafDcsSpawnerAddGroup:test_nothing_at_all_is_survivable()
  luaunit.assertFalse(veafDcsSpawner.addGroup(nil))
end

function TestVeafDcsSpawnerAddGroup:test_the_bookkeeping_fields_are_stripped()
  -- DCS reads country and category from the call arguments and chokes on them in the table.
  veafDcsSpawner.addGroup(_group({ groupName = "x", startTime = 5 }))

  luaunit.assertNil(submittedGroup().category)
  luaunit.assertNil(submittedGroup().country)
  luaunit.assertNil(submittedGroup().groupName)
  luaunit.assertNil(submittedGroup().units[1].unitName)
end

function TestVeafDcsSpawnerAddGroup:test_the_caller_table_is_not_mutated()
  local original = _group()

  veafDcsSpawner.addGroup(original)

  luaunit.assertEquals(original.category, "GROUND_UNIT", "the caller keeps its own table")
  luaunit.assertNil(original.groupId)
end

os.exit(luaunit.LuaUnit.run())
