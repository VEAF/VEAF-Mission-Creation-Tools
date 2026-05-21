--- Tests for veafSpawn.lua — constants, markTextAnalysis, missionMaster, helpers.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafSpawn.lua")

-- ---------------------------------------------------------------------------
-- TestVeafSpawnConstants
-- ---------------------------------------------------------------------------
TestVeafSpawnConstants = {}

function TestVeafSpawnConstants:test_id()
  luaunit.assertEquals(veafSpawn.Id, "SPAWN")
end

function TestVeafSpawnConstants:test_version()
  luaunit.assertIsString(veafSpawn.Version)
end

function TestVeafSpawnConstants:test_spawnKeyphrase()
  luaunit.assertEquals(veafSpawn.SpawnKeyphrase, "_spawn")
end

function TestVeafSpawnConstants:test_destroyKeyphrase()
  luaunit.assertEquals(veafSpawn.DestroyKeyphrase, "_destroy")
end

function TestVeafSpawnConstants:test_teleportKeyphrase()
  luaunit.assertEquals(veafSpawn.TeleportKeyphrase, "_teleport")
end

function TestVeafSpawnConstants:test_drawingKeyphrase()
  luaunit.assertEquals(veafSpawn.DrawingKeyphrase, "_drawing")
end

function TestVeafSpawnConstants:test_missionMasterKeyphrase()
  luaunit.assertEquals(veafSpawn.MissionMasterKeyphrase, "_mm")
end

function TestVeafSpawnConstants:test_capWatchdogDelay()
  luaunit.assertEquals(veafSpawn.CAP_WATCHDOG_DELAY, 10)
end

function TestVeafSpawnConstants:test_defaultFlakPower()
  luaunit.assertEquals(veafSpawn.DEFAULT_FLAK_POWER, 1)
end

function TestVeafSpawnConstants:test_defaultFlakCloudSize()
  luaunit.assertEquals(veafSpawn.DEFAULT_FLAK_CLOUD_SIZE, 30)
end

function TestVeafSpawnConstants:test_defaultFlakFireDelay()
  luaunit.assertAlmostEquals(veafSpawn.DEFAULT_FLAK_FIRE_DELAY, 0.1, 1e-9)
end

function TestVeafSpawnConstants:test_defaultFlakRepeatDelay()
  luaunit.assertAlmostEquals(veafSpawn.DEFAULT_FLAK_REPEAT_DELAY, 0.2, 1e-9)
end

function TestVeafSpawnConstants:test_minRepeatDelay()
  luaunit.assertEquals(veafSpawn.MIN_REPEAT_DELAY, 5)
end

function TestVeafSpawnConstants:test_nbFlaksAtDensity1()
  luaunit.assertEquals(veafSpawn.NB_OF_FLAKS_AT_DENSITY_1, 30)
end

function TestVeafSpawnConstants:test_hideRadioMenu_false()
  luaunit.assertFalse(veafSpawn.HideRadioMenu)
end

function TestVeafSpawnConstants:test_jtacAutoLase_is_function()
  -- JTACAutoLase is a callback function, not a plain boolean
  luaunit.assertEquals(type(veafSpawn.JTACAutoLase), "function")
end

function TestVeafSpawnConstants:test_airUnitTemplatesPrefix()
  luaunit.assertEquals(veafSpawn.AirUnitTemplatesPrefix, "veafSpawn-")
end

function TestVeafSpawnConstants:test_logisticUnitCategory()
  luaunit.assertEquals(veafSpawn.LogisticUnitCategory, "Fortifications")
end

function TestVeafSpawnConstants:test_logisticUnitType()
  luaunit.assertEquals(veafSpawn.LogisticUnitType, "FARP Ammo Dump Coating")
end

function TestVeafSpawnConstants:test_houndElintAddDelay()
  luaunit.assertEquals(veafSpawn.HoundElintAddDelay, 1)
end

function TestVeafSpawnConstants:test_flakingInterval()
  luaunit.assertEquals(veafSpawn.FlakingInterval, 2)
end

function TestVeafSpawnConstants:test_illuminationFlareAglAltitude()
  luaunit.assertEquals(veafSpawn.IlluminationFlareAglAltitude, 1000)
end

function TestVeafSpawnConstants:test_shellingInterval()
  luaunit.assertEquals(veafSpawn.ShellingInterval, 5)
end

function TestVeafSpawnConstants:test_cargoWeightBiasRange()
  luaunit.assertEquals(veafSpawn.cargoWeightBiasRange, 6)
end

function TestVeafSpawnConstants:test_spawnedUnitsCounter_starts_at_zero()
  luaunit.assertEquals(veafSpawn.spawnedUnitsCounter, 0)
end

-- ---------------------------------------------------------------------------
-- TestVeafSpawnTables
-- ---------------------------------------------------------------------------
TestVeafSpawnTables = {}

function TestVeafSpawnTables:test_drawings_is_table()
  luaunit.assertIsTable(veafSpawn.drawings)
end

function TestVeafSpawnTables:test_spawnedConvoys_is_table()
  luaunit.assertIsTable(veafSpawn.spawnedConvoys)
end

function TestVeafSpawnTables:test_missionMasterRunnables_is_table()
  luaunit.assertIsTable(veafSpawn.missionMasterRunnables)
end

function TestVeafSpawnTables:test_airUnitTemplates_is_table()
  luaunit.assertIsTable(veafSpawn.airUnitTemplates)
end

function TestVeafSpawnTables:test_afac_maximum_amount()
  luaunit.assertEquals(veafSpawn.AFAC.maximumAmount, 8)
end

function TestVeafSpawnTables:test_afac_callsigns_is_table()
  luaunit.assertIsTable(veafSpawn.AFAC.callsigns)
end

-- ---------------------------------------------------------------------------
-- TestVeafSpawnMarkTextAnalysis
-- ---------------------------------------------------------------------------
TestVeafSpawnMarkTextAnalysis = {}

function TestVeafSpawnMarkTextAnalysis:test_spawn_alone_returns_nil()
  -- "_spawn" without subtype is not a valid command
  local r = veafSpawn.markTextAnalysis("_spawn")
  luaunit.assertNil(r)
end

function TestVeafSpawnMarkTextAnalysis:test_spawn_unit_returns_nil_without_name()
  -- "unit" requires a "name" parameter — empty name must be rejected
  local r = veafSpawn.markTextAnalysis("_spawn unit")
  luaunit.assertNil(r)
end

function TestVeafSpawnMarkTextAnalysis:test_spawn_unit_returns_table_with_name()
  local r = veafSpawn.markTextAnalysis("_spawn unit, name F-16C")
  luaunit.assertIsTable(r)
end

function TestVeafSpawnMarkTextAnalysis:test_spawn_unit_sets_flag()
  local r = veafSpawn.markTextAnalysis("_spawn unit, name F-16C")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.unit)
end

function TestVeafSpawnMarkTextAnalysis:test_spawn_group_returns_nil_without_name()
  -- "group" requires a "name" parameter — empty name must be rejected
  local r = veafSpawn.markTextAnalysis("_spawn group")
  luaunit.assertNil(r)
end

function TestVeafSpawnMarkTextAnalysis:test_spawn_group_sets_flag()
  local r = veafSpawn.markTextAnalysis("_spawn group, name MyGroup")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.group)
end

function TestVeafSpawnMarkTextAnalysis:test_spawn_smoke_sets_flag()
  local r = veafSpawn.markTextAnalysis("_spawn smoke")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.smoke)
end

function TestVeafSpawnMarkTextAnalysis:test_spawn_flare_sets_flag()
  local r = veafSpawn.markTextAnalysis("_spawn flare")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.flare)
end

function TestVeafSpawnMarkTextAnalysis:test_spawn_signal_sets_flag()
  local r = veafSpawn.markTextAnalysis("_spawn signal")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.signal)
end

function TestVeafSpawnMarkTextAnalysis:test_spawn_bomb_sets_flag()
  local r = veafSpawn.markTextAnalysis("_spawn bomb")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.bomb)
end

function TestVeafSpawnMarkTextAnalysis:test_spawn_cargo_sets_flag()
  local r = veafSpawn.markTextAnalysis("_spawn cargo")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.cargo)
end

function TestVeafSpawnMarkTextAnalysis:test_spawn_group_name_keyword()
  local r = veafSpawn.markTextAnalysis("_spawn group, name Bravo")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.name, "Bravo")
end

function TestVeafSpawnMarkTextAnalysis:test_spawn_group_size_keyword()
  local r = veafSpawn.markTextAnalysis("_spawn group, name X, size 4")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.size, 4)
end

function TestVeafSpawnMarkTextAnalysis:test_spawn_group_defense_keyword()
  local r = veafSpawn.markTextAnalysis("_spawn group, name X, defense 3")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.defense, 3)
end

function TestVeafSpawnMarkTextAnalysis:test_spawn_group_armor_keyword()
  local r = veafSpawn.markTextAnalysis("_spawn group, name X, armor 5")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.armor, 5)
end

function TestVeafSpawnMarkTextAnalysis:test_spawn_group_country_keyword()
  local r = veafSpawn.markTextAnalysis("_spawn group, name X, country Russia")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.country, "RUSSIA")
end

function TestVeafSpawnMarkTextAnalysis:test_destroy_sets_flag()
  local r = veafSpawn.markTextAnalysis("_destroy")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.destroy)
end

function TestVeafSpawnMarkTextAnalysis:test_teleport_sets_flag()
  local r = veafSpawn.markTextAnalysis("_teleport, name G1")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.teleport)
end

function TestVeafSpawnMarkTextAnalysis:test_teleport_name_keyword()
  local r = veafSpawn.markTextAnalysis("_teleport, name MyGroup")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.name, "MyGroup")
end

function TestVeafSpawnMarkTextAnalysis:test_drawing_circle_sets_flag()
  local r = veafSpawn.markTextAnalysis("_drawing circle")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.drawCircle)
end

function TestVeafSpawnMarkTextAnalysis:test_drawing_square_sets_flag()
  local r = veafSpawn.markTextAnalysis("_drawing square")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.drawSquare)
end

function TestVeafSpawnMarkTextAnalysis:test_mm_getFlag_returns_table()
  local r = veafSpawn.markTextAnalysis("_mm getFlag 5")
  luaunit.assertIsTable(r)
end

function TestVeafSpawnMarkTextAnalysis:test_non_matching_returns_nil()
  local r = veafSpawn.markTextAnalysis("_cas")
  luaunit.assertNil(r)
end

-- ---------------------------------------------------------------------------
-- TestVeafSpawnConvertLaserToFreq
-- ---------------------------------------------------------------------------
TestVeafSpawnConvertLaserToFreq = {}

function TestVeafSpawnConvertLaserToFreq:test_1688_returns_40_4()
  -- convertLaserToFreq returns a string representation of the frequency
  luaunit.assertEquals(veafSpawn.convertLaserToFreq(1688), "40.4")
end

function TestVeafSpawnConvertLaserToFreq:test_1111_returns_31_55()
  luaunit.assertEquals(veafSpawn.convertLaserToFreq(1111), "31.55")
end

function TestVeafSpawnConvertLaserToFreq:test_returns_string()
  luaunit.assertIsString(veafSpawn.convertLaserToFreq(1500))
end

os.exit(luaunit.LuaUnit.run())
