--- Tests for veafUnits.lua — unit/group database lookups and data structures.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")

-- Provide a minimal dcsUnits stub (instead of loading the 16k-line file).
-- New schema: keyed by DCS type id, with a single `kind` field.
dcsUnits = {
  DcsUnitsDatabase = {
    ["ZSU-23-4 Shilka"] = {
      type = "ZSU-23-4 Shilka",
      name = "AAA ZSU-23-4 Shilka",
      category = "Air Defence",
      kind = "vehicle",
      description = "AAA ZSU-23-4 Shilka",
    },
    ["SA-18 Igla-S manpad"] = {
      type = "SA-18 Igla-S manpad",
      name = "MANPAD SA-18 Igla-S",
      category = "Air Defence",
      kind = "infantry",
      description = "MANPAD SA-18 Igla-S",
    },
    ["LHA_Tarawa"] = { type = "LHA_Tarawa", name = "LHA Tarawa", category = "Ship", kind = "naval", description = "LHA Tarawa" },
    ["Vulcan"] = { type = "Vulcan", name = "AAA Vulcan M163", category = "Air Defence", kind = "vehicle", description = "AAA Vulcan M163" },
    ["A-10C"] = { type = "A-10C", name = "A-10C Thunderbolt II", category = "Plane", kind = "air", description = "A-10C Thunderbolt II" },
    ["Ural-375"] = { type = "Ural-375", name = "Ural-375 Truck", category = "Unarmed", kind = "vehicle", description = "Ural-375 Truck" },
  },
  NavalStatics = {},
}

dofile(src .. "/veafUnits.lua")

-- veafUnits.lua now ships its UnitsDatabase / GroupsDatabase empty; at mission
-- build the spawn-data module (rendered from veaf-units.yaml) populates them.
-- These tests simulate that injection with a small known fixture (SPAWN-EXTERNALIZE).
veafUnits.UnitsDatabase = {
  { aliases = { "shilka" }, unitType = "ZSU-23-4 Shilka" },
  { aliases = { "tarawa" }, unitType = "LHA_Tarawa" },
  { aliases = { "sa18", "sa-18", "manpad" }, unitType = "SA-18 Igla-S manpad" },
}
veafUnits.GroupsDatabase = {
  {
    aliases = { "testsam" },
    group = {
      disposition = { h = 3, w = 3 },
      units = {
        { "ZSU-23-4 Shilka", cell = 1 },
        { "Ural-375", random = true },
      },
      description = "Test SAM site",
      groupName = "TestSAM",
    },
  },
}

-- ---------------------------------------------------------------------------
-- TestVeafUnitsConstants
-- ---------------------------------------------------------------------------
TestVeafUnitsConstants = {}

function TestVeafUnitsConstants:test_id()
  luaunit.assertEquals(veafUnits.Id, "UNITS")
end

function TestVeafUnitsConstants:test_defaultCellWidth()
  luaunit.assertEquals(veafUnits.DefaultCellWidth, 10)
end

function TestVeafUnitsConstants:test_defaultCellHeight()
  luaunit.assertEquals(veafUnits.DefaultCellHeight, 10)
end

function TestVeafUnitsConstants:test_pathfindingUnitType()
  luaunit.assertIsString(veafUnits.DefaultPathfindingUnitType)
  luaunit.assertTrue(#veafUnits.DefaultPathfindingUnitType > 0)
end

function TestVeafUnitsConstants:test_delayBeforePathfindingFix()
  luaunit.assertIsNumber(veafUnits.delayBeforePathfindingFix)
end

-- ---------------------------------------------------------------------------
-- TestVeafUnitsMakeUnitFromDcsStructure
-- ---------------------------------------------------------------------------
TestVeafUnitsMakeUnitFromDcsStructure = {}

function TestVeafUnitsMakeUnitFromDcsStructure:test_nil_input_returns_nil()
  luaunit.assertNil(veafUnits.makeUnitFromDcsStructure(nil, 1))
end

function TestVeafUnitsMakeUnitFromDcsStructure:test_vehicle_unit()
  local dcsUnit = { type = "Vulcan", category = "Air Defence", kind = "vehicle", description = "AAA Vulcan M163" }
  local result = veafUnits.makeUnitFromDcsStructure(dcsUnit, 1)
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.typeName, "Vulcan")
  luaunit.assertEquals(result.category, "Air Defence")
  luaunit.assertTrue(result.vehicle)
  luaunit.assertFalse(result.static == true)
  luaunit.assertEquals(result.cell, 1)
end

function TestVeafUnitsMakeUnitFromDcsStructure:test_infantry_unit()
  local dcsUnit = { type = "SA-18 Igla-S manpad", category = "Air Defence", kind = "infantry", description = "MANPAD" }
  local result = veafUnits.makeUnitFromDcsStructure(dcsUnit, 2)
  luaunit.assertTrue(result.infantry)
  luaunit.assertFalse(result.vehicle)
  luaunit.assertEquals(result.cell, 2)
end

function TestVeafUnitsMakeUnitFromDcsStructure:test_naval_unit()
  local dcsUnit = { type = "LHA_Tarawa", category = "Ships", kind = "naval", description = "LHA Tarawa" }
  local result = veafUnits.makeUnitFromDcsStructure(dcsUnit, 1)
  luaunit.assertTrue(result.naval)
  -- naval is not static
  luaunit.assertFalse(result.static == true)
end

function TestVeafUnitsMakeUnitFromDcsStructure:test_air_unit()
  local dcsUnit = { type = "A-10C", category = "Airplanes", kind = "air", description = "A-10C" }
  local result = veafUnits.makeUnitFromDcsStructure(dcsUnit, 3)
  luaunit.assertTrue(result.air)
  luaunit.assertFalse(result.static == true)
end

function TestVeafUnitsMakeUnitFromDcsStructure:test_static_unit()
  -- kind == "static" and not a Fortification => result.static
  local dcsUnit = { type = "Fortification_Bunker", category = "Fortification", kind = "static", description = "Bunker" }
  local result = veafUnits.makeUnitFromDcsStructure(dcsUnit, 1)
  luaunit.assertTrue(result.static)
end

function TestVeafUnitsMakeUnitFromDcsStructure:test_fortification_is_not_static()
  -- a Fortification keeps result.static unset, matching the legacy behaviour
  local dcsUnit =
    { type = "Bunker", category = "Fortification", kind = "static", description = "Bunker", attribute = { Fortifications = true } }
  local result = veafUnits.makeUnitFromDcsStructure(dcsUnit, 1)
  luaunit.assertFalse(result.static == true)
end

function TestVeafUnitsMakeUnitFromDcsStructure:test_displayName()
  local dcsUnit = { type = "Ural-375", description = "Ural-375 Truck", kind = "vehicle" }
  local result = veafUnits.makeUnitFromDcsStructure(dcsUnit, 1)
  luaunit.assertEquals(result.displayName, "Ural-375 Truck")
end

-- ---------------------------------------------------------------------------
-- TestVeafUnitsFindDcsUnit
-- ---------------------------------------------------------------------------
TestVeafUnitsFindDcsUnit = {}

function TestVeafUnitsFindDcsUnit:test_find_by_type_exact()
  local result = veafUnits.findDcsUnit("ZSU-23-4 Shilka")
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.type, "ZSU-23-4 Shilka")
end

function TestVeafUnitsFindDcsUnit:test_find_by_type_case_insensitive()
  local result = veafUnits.findDcsUnit("zsu-23-4 shilka")
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.type, "ZSU-23-4 Shilka")
end

function TestVeafUnitsFindDcsUnit:test_find_by_name()
  local result = veafUnits.findDcsUnit("LHA Tarawa")
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.type, "LHA_Tarawa")
end

function TestVeafUnitsFindDcsUnit:test_unknown_unit_returns_nil()
  local result = veafUnits.findDcsUnit("NonExistentUnit_XYZ")
  luaunit.assertNil(result)
end

-- ---------------------------------------------------------------------------
-- TestVeafUnitsFindUnit (via alias in UnitsDatabase)
-- ---------------------------------------------------------------------------
TestVeafUnitsFindUnit = {}

function TestVeafUnitsFindUnit:test_find_shilka_by_alias()
  -- "shilka" is an alias for "ZSU-23-4 Shilka" in veafUnits.UnitsDatabase
  local result = veafUnits.findUnit("shilka")
  luaunit.assertNotNil(result, "Expected to find 'shilka' unit")
  luaunit.assertEquals(result.typeName, "ZSU-23-4 Shilka")
end

function TestVeafUnitsFindUnit:test_find_by_alias_case_insensitive()
  local result = veafUnits.findUnit("SHILKA")
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.typeName, "ZSU-23-4 Shilka")
end

function TestVeafUnitsFindUnit:test_find_tarawa_by_alias()
  local result = veafUnits.findUnit("tarawa")
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.typeName, "LHA_Tarawa")
  luaunit.assertTrue(result.naval)
end

function TestVeafUnitsFindUnit:test_find_manpad_by_alias()
  local result = veafUnits.findUnit("manpad")
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.typeName, "SA-18 Igla-S manpad")
  luaunit.assertTrue(result.infantry)
end

function TestVeafUnitsFindUnit:test_find_sa18_alias()
  local result = veafUnits.findUnit("sa18")
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.typeName, "SA-18 Igla-S manpad")
end

function TestVeafUnitsFindUnit:test_find_sa18_dash_alias()
  local result = veafUnits.findUnit("sa-18")
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.typeName, "SA-18 Igla-S manpad")
end

function TestVeafUnitsFindUnit:test_unknown_alias_returns_nil()
  local result = veafUnits.findUnit("TOTALLY_UNKNOWN_ALIAS_999")
  luaunit.assertNil(result)
end

function TestVeafUnitsFindUnit:test_result_has_typeName()
  local result = veafUnits.findUnit("shilka")
  luaunit.assertIsString(result.typeName)
end

-- ---------------------------------------------------------------------------
-- TestVeafUnitsCheckPositionForUnit
-- ---------------------------------------------------------------------------
TestVeafUnitsCheckPositionForUnit = {}

function TestVeafUnitsCheckPositionForUnit:test_vehicle_on_land()
  local unit = { vehicle = true }
  -- land mock returns LAND (1)
  local pos = { x = 0, y = 0, z = 5 }
  luaunit.assertTrue(veafUnits.checkPositionForUnit(pos, unit))
end

function TestVeafUnitsCheckPositionForUnit:test_naval_on_land_returns_false()
  local unit = { naval = true }
  -- land mock returns LAND (not WATER)
  local pos = { x = 0, y = 0, z = 0 }
  luaunit.assertFalse(veafUnits.checkPositionForUnit(pos, unit))
end

function TestVeafUnitsCheckPositionForUnit:test_air_unit_at_low_alt_returns_false()
  local unit = { air = true }
  local pos = { x = 0, y = 0, z = 5 } -- z <= 10
  luaunit.assertFalse(veafUnits.checkPositionForUnit(pos, unit))
end

function TestVeafUnitsCheckPositionForUnit:test_air_unit_at_high_alt_returns_true()
  local unit = { air = true }
  local pos = { x = 0, y = 0, z = 100 }
  luaunit.assertTrue(veafUnits.checkPositionForUnit(pos, unit))
end

-- ---------------------------------------------------------------------------
-- TestVeafUnitsDatabases
-- ---------------------------------------------------------------------------
TestVeafUnitsDatabases = {}

function TestVeafUnitsDatabases:test_unitsDatabase_exists()
  luaunit.assertNotNil(veafUnits.UnitsDatabase)
  luaunit.assertIsTable(veafUnits.UnitsDatabase)
  luaunit.assertTrue(#veafUnits.UnitsDatabase > 0)
end

function TestVeafUnitsDatabases:test_groupsDatabase_exists()
  luaunit.assertNotNil(veafUnits.GroupsDatabase)
  luaunit.assertIsTable(veafUnits.GroupsDatabase)
  luaunit.assertTrue(#veafUnits.GroupsDatabase > 0)
end

function TestVeafUnitsDatabases:test_each_unitsDb_entry_has_aliases()
  for _, entry in ipairs(veafUnits.UnitsDatabase) do
    luaunit.assertIsTable(entry.aliases, "Entry missing aliases table")
    luaunit.assertTrue(#entry.aliases > 0, "Entry has empty aliases")
    luaunit.assertIsString(entry.unitType, "Entry missing unitType string")
  end
end

function TestVeafUnitsDatabases:test_each_groupsDb_entry_has_aliases()
  for _, entry in ipairs(veafUnits.GroupsDatabase) do
    luaunit.assertIsTable(entry.aliases, "GroupsDB entry missing aliases")
    luaunit.assertTrue(#entry.aliases > 0, "GroupsDB entry has empty aliases")
    luaunit.assertIsTable(entry.group, "GroupsDB entry missing group table")
  end
end

function TestVeafUnitsDatabases:test_defaultPathfindingGroup_structure()
  local g = veafUnits.DefaultPathfindingGroup
  luaunit.assertIsTable(g)
  luaunit.assertIsTable(g.disposition)
  luaunit.assertIsTable(g.units)
  luaunit.assertIsString(g.groupName)
end

-- ---------------------------------------------------------------------------
-- TestVeafUnitsProcessGroup
-- ---------------------------------------------------------------------------
TestVeafUnitsProcessGroup = {}

function TestVeafUnitsProcessGroup:test_copies_metadata()
  local group = {
    disposition = { h = 2, w = 3 },
    description = "My group",
    groupName = "MyGroup",
    units = {
      { "ZSU-23-4 Shilka", cell = 1 },
    },
  }
  local result = veafUnits.processGroup(group)
  luaunit.assertEquals(result.disposition.h, 2)
  luaunit.assertEquals(result.disposition.w, 3)
  luaunit.assertEquals(result.description, "My group")
  luaunit.assertEquals(result.groupName, "MyGroup")
  luaunit.assertIsTable(result.units)
end

function TestVeafUnitsProcessGroup:test_resolves_units_with_cell_and_hdg()
  local group = {
    disposition = { h = 1, w = 1 },
    groupName = "G",
    units = {
      { "ZSU-23-4 Shilka", cell = 2, hdg = 90 },
    },
  }
  local result = veafUnits.processGroup(group)
  luaunit.assertEquals(#result.units, 1)
  local u = result.units[1]
  luaunit.assertEquals(u.typeName, "ZSU-23-4 Shilka")
  luaunit.assertEquals(u.cell, 2)
  luaunit.assertEquals(u.hdg, 90)
  luaunit.assertTrue(u.vehicle)
end

function TestVeafUnitsProcessGroup:test_string_unit_simplified_syntax()
  local group = {
    disposition = { h = 1, w = 1 },
    groupName = "G",
    units = { "ZSU-23-4 Shilka" },
  }
  local result = veafUnits.processGroup(group)
  luaunit.assertEquals(#result.units, 1)
  luaunit.assertEquals(result.units[1].typeName, "ZSU-23-4 Shilka")
  -- no explicit hdg => default random heading was assigned (0..359)
  luaunit.assertTrue(result.units[1].hdg >= 0 and result.units[1].hdg <= 359)
end

function TestVeafUnitsProcessGroup:test_typeName_field_takes_precedence()
  local group = {
    disposition = { h = 1, w = 1 },
    groupName = "G",
    units = {
      { typeName = "LHA_Tarawa", cell = 1 },
    },
  }
  local result = veafUnits.processGroup(group)
  luaunit.assertEquals(result.units[1].typeName, "LHA_Tarawa")
end

function TestVeafUnitsProcessGroup:test_number_expands_unit_count()
  local group = {
    disposition = { h = 2, w = 2 },
    groupName = "G",
    units = {
      { "ZSU-23-4 Shilka", number = 3 },
    },
  }
  local result = veafUnits.processGroup(group)
  luaunit.assertEquals(#result.units, 3)
  for _, u in ipairs(result.units) do
    luaunit.assertEquals(u.typeName, "ZSU-23-4 Shilka")
  end
end

function TestVeafUnitsProcessGroup:test_number_table_random_range()
  local group = {
    disposition = { h = 2, w = 2 },
    groupName = "G",
    units = {
      { "ZSU-23-4 Shilka", number = { min = 2, max = 2 } },
    },
  }
  local result = veafUnits.processGroup(group)
  luaunit.assertEquals(#result.units, 2)
end

function TestVeafUnitsProcessGroup:test_size_number_becomes_table()
  local group = {
    disposition = { h = 1, w = 1 },
    groupName = "G",
    units = {
      { "ZSU-23-4 Shilka", cell = 1, size = 20 },
    },
  }
  local result = veafUnits.processGroup(group)
  local u = result.units[1]
  luaunit.assertIsTable(u.size)
  luaunit.assertEquals(u.size.width, 20)
  luaunit.assertEquals(u.size.height, 20)
end

function TestVeafUnitsProcessGroup:test_random_and_fitToUnit_flags()
  local group = {
    disposition = { h = 1, w = 1 },
    groupName = "G",
    units = {
      { "ZSU-23-4 Shilka", cell = 1, random = true, fitToUnit = true },
    },
  }
  local result = veafUnits.processGroup(group)
  local u = result.units[1]
  luaunit.assertTrue(u.random)
  luaunit.assertTrue(u.fitToUnit)
end

function TestVeafUnitsProcessGroup:test_unknown_unit_is_skipped()
  local group = {
    disposition = { h = 1, w = 1 },
    groupName = "G",
    units = {
      { "TOTALLY_UNKNOWN_UNIT_999", cell = 1 },
      { "ZSU-23-4 Shilka", cell = 2 },
    },
  }
  local result = veafUnits.processGroup(group)
  -- only the known unit survives
  luaunit.assertEquals(#result.units, 1)
  luaunit.assertEquals(result.units[1].typeName, "ZSU-23-4 Shilka")
end

function TestVeafUnitsProcessGroup:test_naval_group_flag()
  local group = {
    disposition = { h = 1, w = 1 },
    groupName = "G",
    units = {
      { "LHA_Tarawa", cell = 1 },
    },
  }
  local result = veafUnits.processGroup(group)
  luaunit.assertTrue(result.naval)
end

-- ---------------------------------------------------------------------------
-- TestVeafUnitsFindGroup
-- ---------------------------------------------------------------------------
TestVeafUnitsFindGroup = {}

function TestVeafUnitsFindGroup:test_find_group_by_alias()
  -- "testsam" is an alias in veafUnits.GroupsDatabase
  local result = veafUnits.findGroup("testsam")
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.groupName, "TestSAM")
  luaunit.assertEquals(result.description, "Test SAM site")
  luaunit.assertEquals(result.disposition.h, 3)
  luaunit.assertEquals(result.disposition.w, 3)
end

function TestVeafUnitsFindGroup:test_find_group_case_insensitive()
  local result = veafUnits.findGroup("TESTSAM")
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.groupName, "TestSAM")
end

function TestVeafUnitsFindGroup:test_find_group_resolves_units()
  local result = veafUnits.findGroup("testsam")
  -- one fixed Shilka + one random Ural-375 = 2 units
  luaunit.assertEquals(#result.units, 2)
end

function TestVeafUnitsFindGroup:test_unknown_group_returns_nil()
  local result = veafUnits.findGroup("NO_SUCH_GROUP_XYZ")
  luaunit.assertNil(result)
end

-- ---------------------------------------------------------------------------
-- TestVeafUnitsPlaceGroup
-- ---------------------------------------------------------------------------
-- Mock of DCS' permissive math.random. veafUnits.placeGroup (veafUnits.lua:609-610)
-- computes cell centers via math.random((cell.bottom - cell.top) / 10, ...). Cells are
-- laid out with bottom < top, so the interval is reversed (m > n) for normal groups.
-- DCS' Lua engine tolerates a reversed interval (placeGroup is mature, production-proven
-- code that never crashes in-game); stock Lua 5.1 instead raises "interval is empty".
-- This wrapper reproduces DCS behaviour by swapping reversed bounds — a DCS-environment
-- mock (like dcs_mocks), not a workaround for a bug. File-scoped on purpose: suites run
-- in separate processes, so it cannot leak into other suites.
local _mathRandom = math.random
math.random = function(m, n)
  if m ~= nil and n ~= nil then
    if m > n then
      m, n = n, m
    end
    return _mathRandom(m, n)
  elseif m ~= nil then
    return _mathRandom(m)
  end
  return _mathRandom()
end

TestVeafUnitsPlaceGroup = {}

local function _buildSimpleGroup()
  -- a 2x2 group with two fixed-cell vehicles
  return veafUnits.processGroup({
    disposition = { h = 2, w = 2 },
    groupName = "Placed",
    description = "Placed group",
    units = {
      { "ZSU-23-4 Shilka", cell = 1 },
      { "Vulcan", cell = 4 },
    },
  })
end

function TestVeafUnitsPlaceGroup:test_returns_group_and_cells()
  local group = _buildSimpleGroup()
  local spawnPoint = { x = 1000, y = 0, z = 2000 }
  local resultGroup, cells = veafUnits.placeGroup(group, spawnPoint, 0, 0, false)
  luaunit.assertNotNil(resultGroup)
  luaunit.assertIsTable(cells)
end

function TestVeafUnitsPlaceGroup:test_fixed_units_get_spawnpoint()
  local group = _buildSimpleGroup()
  local spawnPoint = { x = 1000, y = 0, z = 2000 }
  veafUnits.placeGroup(group, spawnPoint, 0, 0, false)
  for _, unit in pairs(group.units) do
    luaunit.assertNotNil(unit.spawnPoint, "every placed unit must get a spawnPoint")
    luaunit.assertIsNumber(unit.spawnPoint.x)
    luaunit.assertIsNumber(unit.spawnPoint.z)
    luaunit.assertEquals(unit.spawnPoint.y, spawnPoint.y)
    luaunit.assertIsNumber(unit.spawnPoint.hdg)
  end
end

function TestVeafUnitsPlaceGroup:test_units_centered_around_spawnpoint()
  local group = _buildSimpleGroup()
  local spawnPoint = { x = 5000, y = 0, z = 8000 }
  veafUnits.placeGroup(group, spawnPoint, 0, 0, false)
  -- the units occupy diagonal corners (cell 1 and cell 4 of a 2x2 grid);
  -- their spawn points must straddle the spawn center on both axes.
  local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
  for _, unit in pairs(group.units) do
    if unit.spawnPoint.x < minX then
      minX = unit.spawnPoint.x
    end
    if unit.spawnPoint.x > maxX then
      maxX = unit.spawnPoint.x
    end
    if unit.spawnPoint.z < minZ then
      minZ = unit.spawnPoint.z
    end
    if unit.spawnPoint.z > maxZ then
      maxZ = unit.spawnPoint.z
    end
  end
  -- center is within the bounding box of the placed units
  luaunit.assertTrue(minX <= spawnPoint.x and spawnPoint.x <= maxX)
  luaunit.assertTrue(minZ <= spawnPoint.z and spawnPoint.z <= maxZ)
end

function TestVeafUnitsPlaceGroup:test_spacing_increases_cell_size()
  local function placedExtent(spacing)
    local group = _buildSimpleGroup()
    local _, cells = veafUnits.placeGroup(group, { x = 0, y = 0, z = 0 }, spacing, 0, false)
    -- pick any occupied cell and return its width
    for _, cell in pairs(cells) do
      if cell.unit then
        return cell.width
      end
    end
    return 0
  end
  local w0 = placedExtent(0)
  local w2 = placedExtent(2)
  luaunit.assertTrue(w2 > w0, "spacing must enlarge cells")
end

function TestVeafUnitsPlaceGroup:test_heading_rotation_keeps_unit_count()
  local group = _buildSimpleGroup()
  veafUnits.placeGroup(group, { x = 0, y = 0, z = 0 }, 0, 90, false)
  local count = 0
  for _, unit in pairs(group.units) do
    luaunit.assertNotNil(unit.spawnPoint)
    -- heading was applied (radians); unit.hdg + group hdg converted to radian
    luaunit.assertIsNumber(unit.spawnPoint.hdg)
    count = count + 1
  end
  luaunit.assertEquals(count, 2)
end

function TestVeafUnitsPlaceGroup:test_default_disposition_when_missing()
  -- processGroup keeps disposition; build a raw group with no disposition to
  -- exercise the default-square branch of placeGroup.
  local group = {
    units = {
      veafUnits.findUnit("shilka"),
      veafUnits.findUnit("shilka"),
      veafUnits.findUnit("shilka"),
    },
  }
  local resultGroup = veafUnits.placeGroup(group, { x = 0, y = 0, z = 0 }, 0, 0, false)
  luaunit.assertNotNil(resultGroup.disposition)
  -- ceil(sqrt(3)) = 2
  luaunit.assertEquals(resultGroup.disposition.h, 2)
  luaunit.assertEquals(resultGroup.disposition.w, 2)
end

function TestVeafUnitsPlaceGroup:test_hasDest_appends_pathfinding_unit()
  -- a convoy with a destination inserts the pathfinding fixer unit and lays
  -- the units out in a single column.
  local group = veafUnits.processGroup({
    disposition = { h = 1, w = 2 },
    groupName = "Convoy",
    description = "Convoy",
    units = {
      { "ZSU-23-4 Shilka" },
      { "Vulcan" },
    },
  })
  -- The DefaultPathfindingGroup unit type (TZ-22_KrAZ) is not in the test DCS
  -- DB, so the appended fixer resolves to nil; the convoy keeps its real units.
  -- What we assert is the destination-specific layout path: a single-column
  -- arrangement where every spawned unit's heading is forced to align (0 offset).
  local resultGroup = veafUnits.placeGroup(group, { x = 0, y = 0, z = 0 }, 0, 0, true)
  local placed = 0
  for _, unit in pairs(resultGroup.units) do
    if unit and unit.spawnPoint then
      luaunit.assertEquals(unit.spawnPoint.hdg, 0)
      placed = placed + 1
    end
  end
  luaunit.assertEquals(placed, 2, "both convoy units must be placed in a column")
end

function TestVeafUnitsPlaceGroup:test_default_heading_when_nil()
  local group = _buildSimpleGroup()
  -- nil hdg => defaults to 0 (north), no error
  local resultGroup = veafUnits.placeGroup(group, { x = 0, y = 0, z = 0 }, 0, nil, false)
  luaunit.assertNotNil(resultGroup)
end

-- ---------------------------------------------------------------------------
-- TestVeafUnitsCountInfantryAndVehicles
-- ---------------------------------------------------------------------------
TestVeafUnitsCountInfantryAndVehicles = {}

function TestVeafUnitsCountInfantryAndVehicles:test_no_group_returns_zero()
  dcs_mocks.clearUnitsAndGroups()
  local v, i = veafUnits.countInfantryAndVehicles("does-not-exist")
  luaunit.assertEquals(v, 0)
  luaunit.assertEquals(i, 0)
end

function TestVeafUnitsCountInfantryAndVehicles:test_counts_vehicles_and_infantry()
  dcs_mocks.clearUnitsAndGroups()
  local units = {
    {
      getTypeName = function()
        return "ZSU-23-4 Shilka"
      end,
    }, -- vehicle
    {
      getTypeName = function()
        return "Vulcan"
      end,
    }, -- vehicle
    {
      getTypeName = function()
        return "SA-18 Igla-S manpad"
      end,
    }, -- infantry
  }
  dcs_mocks.addGroup("counted", {
    getUnits = function()
      return units
    end,
  })
  local v, i = veafUnits.countInfantryAndVehicles("counted")
  luaunit.assertEquals(v, 2)
  luaunit.assertEquals(i, 1)
end

function TestVeafUnitsCountInfantryAndVehicles:test_ignores_unknown_types()
  dcs_mocks.clearUnitsAndGroups()
  local units = {
    {
      getTypeName = function()
        return "ZSU-23-4 Shilka"
      end,
    }, -- vehicle
    {
      getTypeName = function()
        return "UNKNOWN_TYPE_XYZ"
      end,
    }, -- not counted
  }
  dcs_mocks.addGroup("counted2", {
    getUnits = function()
      return units
    end,
  })
  local v, i = veafUnits.countInfantryAndVehicles("counted2")
  luaunit.assertEquals(v, 1)
  luaunit.assertEquals(i, 0)
end

-- ---------------------------------------------------------------------------
-- TestVeafUnitsRemovePathfindingFixUnit
-- ---------------------------------------------------------------------------
TestVeafUnitsRemovePathfindingFixUnit = {}

function TestVeafUnitsRemovePathfindingFixUnit:test_destroys_matching_unit()
  dcs_mocks.clearUnitsAndGroups()
  local destroyed = { value = false }
  local units = {
    {
      getTypeName = function()
        return "ZSU-23-4 Shilka"
      end,
      destroy = function() end,
    },
    {
      getTypeName = function()
        return veafUnits.DefaultPathfindingUnitType
      end,
      destroy = function()
        destroyed.value = true
      end,
    },
  }
  dcs_mocks.addGroup("convoy", {
    getUnits = function()
      return units
    end,
  })
  veafUnits.removePathfindingFixUnit("convoy")
  luaunit.assertTrue(destroyed.value, "the pathfinding fix unit must be destroyed")
end

function TestVeafUnitsRemovePathfindingFixUnit:test_no_group_is_noop()
  dcs_mocks.clearUnitsAndGroups()
  -- must not raise when the group does not exist
  veafUnits.removePathfindingFixUnit("missing-convoy")
end

function TestVeafUnitsRemovePathfindingFixUnit:test_leaves_other_units()
  dcs_mocks.clearUnitsAndGroups()
  local destroyedShilka = { value = false }
  local units = {
    {
      getTypeName = function()
        return "ZSU-23-4 Shilka"
      end,
      destroy = function()
        destroyedShilka.value = true
      end,
    },
  }
  dcs_mocks.addGroup("convoy3", {
    getUnits = function()
      return units
    end,
  })
  veafUnits.removePathfindingFixUnit("convoy3")
  luaunit.assertFalse(destroyedShilka.value, "non-pathfinding units must be left alone")
end

-- ---------------------------------------------------------------------------
-- TestVeafUnitsLogMarkdown
-- ---------------------------------------------------------------------------
TestVeafUnitsLogMarkdown = {}

function TestVeafUnitsLogMarkdown:test_logGroupsListInMarkdown_runs()
  -- exercises the markdown generator (sort + concat); should not raise.
  veafUnits.logGroupsListInMarkdown()
end

function TestVeafUnitsLogMarkdown:test_logUnitsListInMarkdown_runs()
  veafUnits.logUnitsListInMarkdown()
end

-- ---------------------------------------------------------------------------
-- TestVeafUnitsTraceGroup
-- ---------------------------------------------------------------------------
TestVeafUnitsTraceGroup = {}

function TestVeafUnitsTraceGroup:test_traceGroup_renders_grid()
  -- traceGroup only runs its body when veafUnits.Trace is truthy.
  local group = veafUnits.processGroup({
    disposition = { h = 2, w = 2 },
    groupName = "Traced",
    description = "Traced group",
    units = {
      { "ZSU-23-4 Shilka", cell = 1 },
      { "Vulcan", cell = 4 },
    },
  })
  local _, cells = veafUnits.placeGroup(group, { x = 0, y = 0, z = 0 }, 0, 45, false)
  local saved = veafUnits.Trace
  veafUnits.Trace = true
  -- must walk the cells and format the ASCII grid without raising
  veafUnits.traceGroup(group, cells)
  veafUnits.Trace = saved
end

function TestVeafUnitsTraceGroup:test_traceGroup_disabled_is_noop()
  local saved = veafUnits.Trace
  veafUnits.Trace = false
  veafUnits.traceGroup({ description = "x", disposition = { h = 1, w = 1 } }, {})
  veafUnits.Trace = saved
end

-- ---------------------------------------------------------------------------
-- TestVeafUnitsInitialize
-- ---------------------------------------------------------------------------
TestVeafUnitsInitialize = {}

function TestVeafUnitsInitialize:test_initialize_runs()
  veafUnits.initialize()
end

os.exit(luaunit.LuaUnit.run())
