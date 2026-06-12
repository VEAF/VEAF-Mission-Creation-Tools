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
    ["ZSU-23-4 Shilka"] = { type = "ZSU-23-4 Shilka", name = "AAA ZSU-23-4 Shilka", category = "Air Defence", kind = "vehicle", description = "AAA ZSU-23-4 Shilka" },
    ["SA-18 Igla-S manpad"] = { type = "SA-18 Igla-S manpad", name = "MANPAD SA-18 Igla-S", category = "Air Defence", kind = "infantry", description = "MANPAD SA-18 Igla-S" },
    ["LHA_Tarawa"] = { type = "LHA_Tarawa", name = "LHA Tarawa", category = "Ship", kind = "naval", description = "LHA Tarawa" },
    ["Vulcan"] = { type = "Vulcan", name = "AAA Vulcan M163", category = "Air Defence", kind = "vehicle", description = "AAA Vulcan M163" },
    ["A-10C"] = { type = "A-10C", name = "A-10C Thunderbolt II", category = "Plane", kind = "air", description = "A-10C Thunderbolt II" },
    ["Ural-375"] = { type = "Ural-375", name = "Ural-375 Truck", category = "Unarmed", kind = "vehicle", description = "Ural-375 Truck" },
  },
  NavalStatics = {},
}

dofile(src .. "/veafUnits.lua")

-- ---------------------------------------------------------------------------
-- TestVeafUnitsConstants
-- ---------------------------------------------------------------------------
TestVeafUnitsConstants = {}

function TestVeafUnitsConstants:test_id()
  luaunit.assertEquals(veafUnits.Id, "UNITS")
end

function TestVeafUnitsConstants:test_version()
  luaunit.assertIsString(veafUnits.Version)
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
  local pos = { x = 0, y = 0, z = 5 }  -- z <= 10
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

os.exit(luaunit.LuaUnit.run())
