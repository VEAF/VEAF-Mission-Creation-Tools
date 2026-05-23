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

-- ---------------------------------------------------------------------------
-- TestVeafSpawnEffects
-- ---------------------------------------------------------------------------
TestVeafSpawnEffects = {}

function TestVeafSpawnEffects:setUp()
  dcs_mocks.reset()
  veaf.DO_NOT_EXPORT_JSON_FILES = true
end

function TestVeafSpawnEffects:test_spawnBomb_ground_level()
  veafSpawn.spawnBomb({ x = 0, y = 0, z = 0 }, 0, 1, 100, 0, 0, nil)
  luaunit.assertTrue(true)
end

function TestVeafSpawnEffects:test_spawnBomb_at_altitude()
  veafSpawn.spawnBomb({ x = 0, y = 0, z = 0 }, 0, 2, 100, 1000, 50, nil)
  luaunit.assertTrue(true)
end

function TestVeafSpawnEffects:test_spawnSmoke_single()
  veafSpawn.spawnSmoke({ x = 0, y = 0, z = 0 }, trigger.smokeColor.Red, 50, 1)
  luaunit.assertTrue(true)
end

function TestVeafSpawnEffects:test_spawnSmoke_multiple_shells()
  -- shells>1 triggers the explosion branch
  veafSpawn.spawnSmoke({ x = 0, y = 0, z = 0 }, trigger.smokeColor.Green, 50, 2)
  luaunit.assertTrue(true)
end

function TestVeafSpawnEffects:test_spawnSignalFlare()
  veafSpawn.spawnSignalFlare({ x = 0, y = 0, z = 0 }, 0, 1, trigger.flareColor.RED)
  luaunit.assertTrue(true)
end

function TestVeafSpawnEffects:test_spawnIlluminationFlare_simple()
  veafSpawn.spawnIlluminationFlare({ x = 0, y = 0, z = 0 }, 0, 2, 10, 500)
  luaunit.assertTrue(true)
end

function TestVeafSpawnEffects:test_spawnIlluminationFlare_heading_distance()
  veafSpawn.spawnIlluminationFlare({ x = 0, y = 0, z = 0 }, 0, 2, 10, 500, 45, 5)
  luaunit.assertTrue(true)
end

function TestVeafSpawnEffects:test_spawnIlluminationFlare_heading_speed()
  veafSpawn.spawnIlluminationFlare({ x = 0, y = 0, z = 0 }, 0, 2, 10, 500, 90, nil, 200)
  luaunit.assertTrue(true)
end

function TestVeafSpawnEffects:test_destroyObjectWithFlak_not_exist()
  local obj = { isExist = function() return false end }
  veafSpawn.destroyObjectWithFlak(obj, 1, 1)
  luaunit.assertTrue(true)
end

function TestVeafSpawnEffects:test_destroyObjectWithFlak_exists()
  local obj = {
    isExist     = function() return true end,
    getPoint    = function() return { x = 0, y = 100, z = 0 } end,
    getVelocity = function() return { x = 0, y = 0, z = 0 } end,
  }
  -- density=0.1 → 3 flak shells fired synchronously (no recursion since scheduleFunction is a stub)
  veafSpawn.destroyObjectWithFlak(obj, 1, 0.1)
  luaunit.assertTrue(true)
end

function TestVeafSpawnEffects:test_destroy_unitName_not_found()
  veafSpawn.destroy({ x = 0, y = 0, z = 0 }, 0, "NoSuchUnit")
  luaunit.assertTrue(true)
end

function TestVeafSpawnEffects:test_destroy_unitName_found()
  dcs_mocks.addUnit("targetUnit")
  veafSpawn.destroy({ x = 0, y = 0, z = 0 }, 0, "targetUnit")
  luaunit.assertTrue(true)
end

function TestVeafSpawnEffects:test_destroy_by_radius()
  veafSpawn.destroy({ x = 0, y = 0, z = 0 }, 50, nil)
  luaunit.assertTrue(true)
end

function TestVeafSpawnEffects:test_teleport_silent()
  veafSpawn.teleport({ x = 0, y = 0, z = 0 }, "SomeGroup", true)
  luaunit.assertTrue(true)
end

function TestVeafSpawnEffects:test_teleport_not_silent()
  -- mist.teleportToPoint returns nil → outText "Cannot teleport group"
  veafSpawn.teleport({ x = 0, y = 0, z = 0 }, "SomeGroup", false)
  luaunit.assertTrue(true)
end

function TestVeafSpawnEffects:test_spawnCargo_not_found()
  -- veafUnits.findDcsUnit returns nil for both cargoType and cargoType.."_cargo" → logs error and returns
  veafSpawn.spawnCargo({ x = 0, y = 0, z = 0 }, 0, "unknown_cargo_xyz", "usa", 2, nil, nil, true, false)
  luaunit.assertTrue(true)
end

function TestVeafSpawnEffects:test_spawnLogistic_not_found()
  -- doSpawnStatic: veafUnits.findDcsUnit returns nil → unitName=nil → else branch → outText and return
  veafSpawn.spawnLogistic({ x = 0, y = 0, z = 0 }, 0, "usa", false, false)
  luaunit.assertTrue(true)
end

-- ---------------------------------------------------------------------------
-- TestVeafSpawnCore
-- ---------------------------------------------------------------------------
TestVeafSpawnCore = {}

function TestVeafSpawnCore:setUp()
  dcs_mocks.reset()
  veaf.DO_NOT_EXPORT_JSON_FILES = true
  veafSpawn.drawings = {}
  veafSpawn.drawingsMarkers = {}
  veafSpawn.missionMasterRunnables = {}
  veafSpawn.missionMasterRunnables.__silent = true
  veafSpawn.commandHandlers = {}
  veafSpawn.spawnedConvoys = {}
end

function TestVeafSpawnCore:test_registerCommandHandler()
  local called = false
  veafSpawn.registerCommandHandler("testkey", function() called = true end)
  luaunit.assertEquals(#veafSpawn.commandHandlers, 1)
  luaunit.assertEquals(veafSpawn.commandHandlers[1].key, "testkey")
end

function TestVeafSpawnCore:test_executeCommand_nil_text()
  local result = veafSpawn.executeCommand({ x = 0, y = 0, z = 0 }, nil, 2, 0, true, nil, nil, nil, nil, false)
  luaunit.assertFalse(result)
end

function TestVeafSpawnCore:test_executeCommand_nonmatching_text()
  local result = veafSpawn.executeCommand({ x = 0, y = 0, z = 0 }, "hello world", 2, 0, true, nil, nil, nil, nil, false)
  luaunit.assertFalse(result)
end

function TestVeafSpawnCore:test_addPointToDrawing_no_name()
  veafSpawn.addPointToDrawing({ x = 0, y = 0, z = 0 }, nil, nil, nil, nil, false)
  luaunit.assertEquals(next(veafSpawn.drawings), nil)
end

function TestVeafSpawnCore:test_addPointToDrawing_creates()
  veafSpawn.addPointToDrawing({ x = 0, y = 0, z = 0 }, "MyLine", nil, nil, nil, false)
  luaunit.assertNotNil(veafSpawn.drawings["myline"])
end

function TestVeafSpawnCore:test_addPointToDrawing_twice()
  veafSpawn.addPointToDrawing({ x = 0, y = 0, z = 0 }, "MyLine", nil, nil, nil, false)
  veafSpawn.addPointToDrawing({ x = 10, y = 0, z = 10 }, "MyLine", nil, nil, nil, false)
  luaunit.assertNotNil(veafSpawn.drawings["myline"])
end

function TestVeafSpawnCore:test_drawCircle()
  veafSpawn.drawCircle({ x = 0, y = 0, z = 0 }, "C1", 3000, nil, nil, nil)
  luaunit.assertNotNil(veafSpawn.drawings["c1"])
end

function TestVeafSpawnCore:test_drawSquare()
  veafSpawn.drawSquare({ x = 0, y = 0, z = 0 }, "S1", 2000, nil, nil, nil)
  luaunit.assertNotNil(veafSpawn.drawings["s1"])
end

function TestVeafSpawnCore:test_eraseDrawing_nil_name()
  veafSpawn.eraseDrawing(nil)
  luaunit.assertTrue(true)
end

function TestVeafSpawnCore:test_eraseDrawing_not_found()
  veafSpawn.eraseDrawing("nonexistent")
  luaunit.assertTrue(true)
end

function TestVeafSpawnCore:test_eraseDrawing_existing()
  veafSpawn.drawCircle({ x = 0, y = 0, z = 0 }, "Erase1", 1000, nil, nil, nil)
  luaunit.assertNotNil(veafSpawn.drawings["erase1"])
  veafSpawn.eraseDrawing("Erase1")
  luaunit.assertNil(veafSpawn.drawings["erase1"])
end

function TestVeafSpawnCore:test_doSpawnGroup_string_not_found()
  -- veafUnits.findGroup returns nil → doSpawnGroup returns nil
  local result = veafSpawn.doSpawnGroup({ x = 0, y = 0, z = 0 }, 0, "NonExistentGroup", nil, "usa", 0, 0, 10, nil, true, false, false, false)
  luaunit.assertNil(result)
end

function TestVeafSpawnCore:test_doSpawnGroup_table()
  local grpDef = {
    groupName = "TestGrp",
    description = "Test ground group",
    units = {},
    naval = false,
    air = false,
  }
  local result = veafSpawn.doSpawnGroup({ x = 0, y = 0, z = 0 }, 0, grpDef, nil, "usa", 0, 0, 10, nil, true, false, false, false)
  luaunit.assertIsString(result)
end

function TestVeafSpawnCore:test_missionMasterSetMessagingMode()
  veafSpawn.missionMasterSetMessagingMode(false, 99)
  luaunit.assertFalse(veafSpawn.missionMasterRunnables.__silent)
  luaunit.assertEquals(veafSpawn.missionMasterRunnables.__toGroupId, 99)
end

function TestVeafSpawnCore:test_missionMasterAddRunnable()
  veafSpawn.missionMasterAddRunnable("MYCODE", function() return 42 end, nil)
  luaunit.assertNotNil(veafSpawn.missionMasterRunnables["MYCODE"])
end

function TestVeafSpawnCore:test_missionMasterRun_empty_name()
  veafSpawn.missionMasterRun("")
  luaunit.assertTrue(true)
end

function TestVeafSpawnCore:test_missionMasterRun_not_found()
  veafSpawn.missionMasterRun("UNKNOWN")
  luaunit.assertTrue(true)
end

function TestVeafSpawnCore:test_missionMasterRun_success()
  veafSpawn.missionMasterAddRunnable("OK", function() return 99 end, nil)
  veafSpawn.missionMasterRun("OK")
  luaunit.assertTrue(true)
end

function TestVeafSpawnCore:test_missionMasterRun_error()
  veafSpawn.missionMasterAddRunnable("ERR", function() error("boom") end, nil)
  veafSpawn.missionMasterRun("ERR")
  luaunit.assertTrue(true)
end

function TestVeafSpawnCore:test_missionMasterSetFlag_nil_name()
  veafSpawn.missionMasterSetFlag(nil, 0)
  luaunit.assertTrue(true)
end

function TestVeafSpawnCore:test_missionMasterSetFlag()
  veafSpawn.missionMasterSetFlag("F1", 5)
  luaunit.assertTrue(true)
end

function TestVeafSpawnCore:test_missionMasterGetFlag_nil_name()
  veafSpawn.missionMasterGetFlag(nil)
  luaunit.assertTrue(true)
end

function TestVeafSpawnCore:test_missionMasterGetFlag()
  veafSpawn.missionMasterGetFlag("F1")
  luaunit.assertTrue(true)
end

function TestVeafSpawnCore:test_missionMasterAddValueToFlag_nil_name()
  veafSpawn.missionMasterAddValueToFlag(nil, 1)
  luaunit.assertTrue(true)
end

function TestVeafSpawnCore:test_missionMasterAddValueToFlag()
  veafSpawn.missionMasterAddValueToFlag("F1", 3)
  luaunit.assertTrue(true)
end

function TestVeafSpawnCore:test_missionMasterIncrementFlag()
  veafSpawn.missionMasterIncrementFlagValue("F1")
  luaunit.assertTrue(true)
end

function TestVeafSpawnCore:test_missionMasterDecrementFlag()
  veafSpawn.missionMasterDecrementFlagValue("F1")
  luaunit.assertTrue(true)
end

-- ---------------------------------------------------------------------------
-- TestVeafSpawnGround
-- ---------------------------------------------------------------------------
TestVeafSpawnGround = {}

function TestVeafSpawnGround:setUp()
  dcs_mocks.reset()
  veaf.DO_NOT_EXPORT_JSON_FILES = true
  veaf.ctld_initialized = false
  veafSpawn.spawnedConvoys = {}
end

function TestVeafSpawnGround:test_spawnFob_no_ctld()
  local result = veafSpawn.spawnFob({ x = 0, y = 0, z = 0 }, 0, "TestFOB", "usa", "simple", 1, 0, 10, true, false)
  luaunit.assertNil(result)
end

function TestVeafSpawnGround:test_spawnFarp_invisible()
  local result = veafSpawn.spawnFarp({ x = 0, y = 0, z = 0 }, 0, "FARP-Alpha", "usa", "invisible", 2, 0, 10, true, false, true)
  luaunit.assertEquals(result, "FARP-Alpha")
end

function TestVeafSpawnGround:test_spawnFarp_quad()
  local result = veafSpawn.spawnFarp({ x = 0, y = 0, z = 0 }, 0, "FARP-Quad", "usa", "quad", 2, 0, 10, true, false, true)
  luaunit.assertEquals(result, "FARP-Quad")
end

function TestVeafSpawnGround:test_spawnFarp_single()
  local result = veafSpawn.spawnFarp({ x = 0, y = 0, z = 0 }, 0, "FARP-Single", "usa", "single", 2, 0, 10, true, false, true)
  luaunit.assertEquals(result, "FARP-Single")
end

function TestVeafSpawnGround:test_spawnFarp_pad()
  local result = veafSpawn.spawnFarp({ x = 0, y = 0, z = 0 }, 0, "FARP-Pad", "usa", "pad", 2, 0, 10, true, false, true)
  luaunit.assertEquals(result, "FARP-Pad")
end

function TestVeafSpawnGround:test_spawnFarp_empty_name_generates_mgrs()
  -- coord.LLtoMGRS returns a table with MGRSDigraph="XX" etc.
  local result = veafSpawn.spawnFarp({ x = 0, y = 0, z = 0 }, 0, "", "usa", "invisible", 2, 0, 10, true, false, true)
  luaunit.assertIsString(result)
  luaunit.assertStrContains(result, "FARP")
end

function TestVeafSpawnGround:test_spawnInfantryGroup()
  local result = veafSpawn.spawnInfantryGroup({ x = 0, y = 0, z = 0 }, 0, nil, "usa", 2, 0, 10, 1, 0, 3, true, false)
  luaunit.assertIsString(result)
end

function TestVeafSpawnGround:test_spawnArmoredPlatoon()
  local result = veafSpawn.spawnArmoredPlatoon({ x = 0, y = 0, z = 0 }, 0, nil, "usa", 2, 0, 10, 1, 1, 3, true, false, false)
  luaunit.assertIsString(result)
end

function TestVeafSpawnGround:test_spawnAirDefenseBattery()
  local result = veafSpawn.spawnAirDefenseBattery({ x = 0, y = 0, z = 0 }, 0, nil, "usa", 2, 0, 10, 1, true, false, false)
  luaunit.assertIsString(result)
end

function TestVeafSpawnGround:test_spawnTransportCompany()
  local result = veafSpawn.spawnTransportCompany({ x = 0, y = 0, z = 0 }, 0, nil, "usa", 2, 0, 10, 1, 3, true, false, false)
  luaunit.assertIsString(result)
end

function TestVeafSpawnGround:test_spawnFullCombatGroup()
  local result = veafSpawn.spawnFullCombatGroup({ x = 0, y = 0, z = 0 }, 0, nil, "usa", 2, 0, 10, 1, 1, 3, true, false)
  luaunit.assertIsString(result)
end

function TestVeafSpawnGround:test_stopClosestConvoy_nil_unit()
  -- pass a string so string.format doesn't crash; veafRadio.getHumanUnitOrWingman returns nil
  veafSpawn.stopClosestConvoy("TestUnit")
  luaunit.assertTrue(true)
end

function TestVeafSpawnGround:test_moveClosestConvoy_nil_unit()
  veafSpawn.moveClosestConvoy("TestUnit")
  luaunit.assertTrue(true)
end

function TestVeafSpawnGround:test_markClosestConvoyWithSmoke_nil_unit()
  veafSpawn.markClosestConvoyWithSmoke("TestUnit")
  luaunit.assertTrue(true)
end

function TestVeafSpawnGround:test_markClosestConvoyRouteWithSmoke_nil_unit()
  veafSpawn.markClosestConvoyRouteWithSmoke("TestUnit")
  luaunit.assertTrue(true)
end

function TestVeafSpawnGround:test_infoOnAllConvoys_no_convoys()
  -- empty spawnedConvoys → "No convoy found"
  veafSpawn.infoOnAllConvoys("TestUnit")
  luaunit.assertTrue(true)
end

function TestVeafSpawnGround:test_cleanupAllConvoys_empty()
  veafSpawn.cleanupAllConvoys()
  luaunit.assertTrue(true)
end

function TestVeafSpawnGround:test_spawnGroup()
  -- Spawns a named group via the spawnGroup wrapper → doSpawnGroup
  veafSpawn.spawnGroup({ x = 0, y = 0, z = 0 }, 0, "US infgroup", nil, "usa", 0, 0, 10, nil, true, false, false)
  luaunit.assertTrue(true)
end

function TestVeafSpawnGround:test_spawnFob_with_ctld()
  -- Requires ctld_initialized=true and a full ctld stub (builtFOBS, beaconCount, fobBeacons, createRadioBeacon)
  veaf.ctld_initialized = true
  ctld.logisticUnits = {}
  ctld.builtFOBS     = {}
  ctld.beaconCount   = 0
  ctld.fobBeacons    = {}
  local result = veafSpawn.spawnFob({ x = 0, y = 0, z = 0 }, 0, "TestFOB2", "usa", "", 1, 0, 0, true, false)
  luaunit.assertIsString(result)
  luaunit.assertStrContains(result, "TestFOB2")
end

-- ---------------------------------------------------------------------------
-- TestVeafSpawnAircraft
-- ---------------------------------------------------------------------------
TestVeafSpawnAircraft = {}

function TestVeafSpawnAircraft:setUp()
  dcs_mocks.reset()
  veaf.DO_NOT_EXPORT_JSON_FILES = true
  veafSpawn.airUnitTemplates = {}
  veafSpawn.spawnedUnitsCounter = 0
  veafSpawn.AFAC.numberSpawned[coalition.side.BLUE] = nil
  veafSpawn.AFAC.numberSpawned[coalition.side.RED] = nil
end

function TestVeafSpawnAircraft:test_airUnitTemplate_new()
  local t = VeafAirUnitTemplate:new()
  luaunit.assertNotNil(t)
  luaunit.assertNil(t:getName())
  luaunit.assertNil(t:getCoalition())
end

function TestVeafSpawnAircraft:test_airUnitTemplate_setGetName()
  local t = VeafAirUnitTemplate:new()
  t:setName("ALPHA")
  luaunit.assertEquals(t:getName(), "ALPHA")
end

function TestVeafSpawnAircraft:test_airUnitTemplate_setGetCoalition()
  local t = VeafAirUnitTemplate:new()
  t:setCoalition(coalition.side.BLUE)
  luaunit.assertEquals(t:getCoalition(), coalition.side.BLUE)
end

function TestVeafSpawnAircraft:test_airUnitTemplate_setGetGroupData()
  local t = VeafAirUnitTemplate:new()
  local gd = { units = {}, country = "usa" }
  t:setGroupData(gd)
  luaunit.assertEquals(t:getGroupData(), gd)
end

function TestVeafSpawnAircraft:test_airUnitTemplate_chaining()
  local t = VeafAirUnitTemplate:new():setName("BRAVO"):setCoalition(coalition.side.RED)
  luaunit.assertEquals(t:getName(), "BRAVO")
  luaunit.assertEquals(t:getCoalition(), coalition.side.RED)
end

function TestVeafSpawnAircraft:test_initializeAirUnitTemplates_empty()
  -- coalition.getGroups returns {} → no templates added
  veafSpawn.initializeAirUnitTemplates()
  luaunit.assertEquals(next(veafSpawn.airUnitTemplates), nil)
end

function TestVeafSpawnAircraft:test_listAllCAP_empty()
  -- empty airUnitTemplates → "No CAP available for spawn"
  veafSpawn.listAllCAP(nil)
  luaunit.assertTrue(true)
end

function TestVeafSpawnAircraft:test_dumpSpawnablePlanesList_empty()
  -- DO_NOT_EXPORT_JSON_FILES=true → exportAsJson skipped, just sorts empty table
  veafSpawn.dumpSpawnablePlanesList(nil)
  luaunit.assertTrue(true)
end

function TestVeafSpawnAircraft:test_JTACAutoLase()
  local lased = false
  local origLase = ctld.JTACAutoLase
  ctld.JTACAutoLase = function(groupName, code, ...) lased = true end
  veafSpawn.JTACAutoLase("JTAC1", 1688, nil)
  ctld.JTACAutoLase = origLase
  luaunit.assertTrue(lased)
end

function TestVeafSpawnAircraft:test_afacWatchdog_nil_group_name()
  -- afacGroupName=nil → else branch ("AFAC is alive") → schedules watchdog
  veafSpawn.AFAC.numberSpawned[coalition.side.BLUE] = 1
  veafSpawn.afacWatchdog(nil, 1, coalition.side.BLUE, nil)
  luaunit.assertTrue(true)
end

function TestVeafSpawnAircraft:test_afacWatchdog_group_kia()
  -- afacGroupName set but not in registry (Group.getByName=nil) → if branch
  veafSpawn.AFAC.numberSpawned[coalition.side.BLUE] = 1
  veafSpawn.afacWatchdog("KIA-AFAC-01", 1, coalition.side.BLUE, nil)
  luaunit.assertEquals(veafSpawn.AFAC.numberSpawned[coalition.side.BLUE], 0)
  luaunit.assertFalse(veafSpawn.AFAC.callsigns[coalition.side.BLUE][1].taken)
end

function TestVeafSpawnAircraft:test_findSpawnableAircraftGroupname_not_found()
  local result = veafSpawn.findSpawnableAircraftGroupname("NonExistentTemplate")
  luaunit.assertNil(result)
end

function TestVeafSpawnAircraft:test_findSpawnableAircraftGroupname_nil_name()
  -- nil name → regex ".*" matches all, but empty templates → no match → returns nil
  local result = veafSpawn.findSpawnableAircraftGroupname(nil)
  luaunit.assertNil(result)
end

function TestVeafSpawnAircraft:test_spawnAFAC_invalid_country()
  local result = veafSpawn.spawnAFAC({ x = 0, y = 0, z = 0 }, "AFAC1", "invalid_country", 15000, 300, 0, 130000000, "AM", 1688, false, true, false)
  luaunit.assertNil(result)
end

function TestVeafSpawnAircraft:test_spawnAFAC_no_template()
  local result = veafSpawn.spawnAFAC({ x = 0, y = 0, z = 0 }, "NoSuchAFAC", "usa", 15000, 300, 0, 130000000, "AM", 1688, false, true, false)
  luaunit.assertNil(result)
end

function TestVeafSpawnAircraft:test_spawnCombatAirPatrol_invalid_country()
  local result = veafSpawn.spawnCombatAirPatrol({ x = 0, y = 0, z = 0 }, 0, "MiG-29", "invalid_country", 0, 0, 0, 20, nil, 60, "random", true, false)
  luaunit.assertNil(result)
end

function TestVeafSpawnAircraft:test_spawnCombatAirPatrol_no_template()
  -- valid country but no templates loaded → findSpawnableAircraftGroupname returns nil
  local result = veafSpawn.spawnCombatAirPatrol({ x = 0, y = 0, z = 0 }, 0, "NoSuchCAP", "usa", 0, 0, 0, 20, nil, 60, "random", true, false)
  luaunit.assertNil(result)
end

function TestVeafSpawnAircraft:test_startCapWatchdog_nil_name()
  veafSpawn.startCapWatchdog(nil, coalition.side.BLUE, nil, nil, nil)
  luaunit.assertTrue(true)
end

function TestVeafSpawnAircraft:test_startCapWatchdog_nil_coalition()
  veafSpawn.startCapWatchdog("cap-alpha", nil, nil, nil, nil)
  luaunit.assertTrue(true)
end

function TestVeafSpawnAircraft:test_startCapWatchdog_group_not_found()
  -- Group.getByName returns nil → "stopping watchdog" early return
  veafSpawn.startCapWatchdog("cap-alpha", coalition.side.BLUE, nil, nil, nil)
  luaunit.assertTrue(true)
end

function TestVeafSpawnAircraft:test_startCapWatchdog_group_no_position()
  -- group found but getUnits returns {} → getAveragePosition=nil → error return
  dcs_mocks.addGroup("cap-beta")
  veafSpawn.startCapWatchdog("cap-beta", coalition.side.BLUE, nil, nil, nil)
  luaunit.assertTrue(true)
end

function TestVeafSpawnAircraft:test_spawnUnit_not_found()
  local origFind = veafUnits.findUnit
  veafUnits.findUnit = function(name) return nil end
  local result = veafSpawn.spawnUnit({ x = 0, y = 0, z = 0 }, 0, "Unknown", nil, "usa", 0, 0, nil, nil, false, nil, nil, nil, true, false)
  veafUnits.findUnit = origFind
  luaunit.assertNil(result)
end

function TestVeafSpawnAircraft:test_spawnUnit_air_no_static()
  -- air unit with static=false → "Air units cannot be spawned" early return
  local origFind = veafUnits.findUnit
  veafUnits.findUnit = function(name)
    return { displayName = "F-16C", typeName = "F-16C_50", air = true, static = false, naval = false }
  end
  local result = veafSpawn.spawnUnit({ x = 0, y = 0, z = 0 }, 0, "F-16C_50", nil, "usa", 0, 0, nil, nil, false, nil, nil, nil, true, false)
  veafUnits.findUnit = origFind
  luaunit.assertNil(result)
end

function TestVeafSpawnAircraft:test_spawnUnit_ground_silent()
  -- ground unit, role=nil, silent=true → full spawn path, returns group name string
  local origFind = veafUnits.findUnit
  veafUnits.findUnit = function(name)
    return { displayName = "T-72B", typeName = "T-72B", air = false, static = false, naval = false }
  end
  local result = veafSpawn.spawnUnit({ x = 0, y = 0, z = 0 }, 0, "T-72B", nil, "usa", 0, 0, nil, nil, false, nil, nil, nil, true, false)
  veafUnits.findUnit = origFind
  luaunit.assertIsString(result)
end

function TestVeafSpawnAircraft:test_spawnUnit_jtac_role()
  -- role="jtac" with unitName=nil → JTAC name constructed from laser code digits
  -- Pre-register the expected group so Group.getByName succeeds after mist.dynAdd
  dcs_mocks.addGroup("JTAC 1 6 8 8")
  local origFind = veafUnits.findUnit
  veafUnits.findUnit = function(name)
    return { displayName = "M1128", typeName = "M1128", air = false, static = false, naval = false }
  end
  veafSpawn.spawnUnit({ x = 0, y = 0, z = 0 }, 0, "M1128", nil, "usa", 0, 0, nil, "jtac", false, 1688, 130000000, "AM", true, false)
  veafUnits.findUnit = origFind
  luaunit.assertTrue(true)
end

function TestVeafSpawnAircraft:test_spawnUnit_tacan_role()
  -- role="tacan" with unitName=nil → TACAN name constructed from freq+mod
  -- Pre-register the expected group so Group.getByName succeeds after mist.dynAdd
  dcs_mocks.addGroup("TACAN 99X")
  local origFind = veafUnits.findUnit
  veafUnits.findUnit = function(name)
    return { displayName = "M1128", typeName = "M1128", air = false, static = false, naval = false }
  end
  veafSpawn.spawnUnit({ x = 0, y = 0, z = 0 }, 0, "M1128", nil, "usa", 0, 0, nil, "tacan", false, 1688, 99, "X", true, false)
  veafUnits.findUnit = origFind
  luaunit.assertTrue(true)
end

function TestVeafSpawnAircraft:test_initializeAirUnitTemplates_with_planes()
  -- SpawnablePlanes table populated → templates indexed by upper-case name
  veafSpawn.SpawnablePlanes = { { name = "veafSpawn-ALPHA", units = {} } }
  veafSpawn.initializeAirUnitTemplates()
  veafSpawn.SpawnablePlanes = nil
  luaunit.assertNotNil(veafSpawn.airUnitTemplates["VEAFSPAWN-ALPHA"])
end

function TestVeafSpawnAircraft:test_listAllCAP_with_templates()
  -- populate a template so the non-empty path is exercised
  veafSpawn.SpawnablePlanes = { { name = "veafSpawn-ALPHA", units = {} } }
  veafSpawn.initializeAirUnitTemplates()
  veafSpawn.SpawnablePlanes = nil
  veafSpawn.listAllCAP("TestUnit")
  luaunit.assertTrue(true)
end

function TestVeafSpawnAircraft:test_dumpSpawnablePlanesList_with_templates()
  -- populate a template so the non-empty path is exercised
  veafSpawn.SpawnablePlanes = { { name = "veafSpawn-ALPHA", units = {} } }
  veafSpawn.initializeAirUnitTemplates()
  veafSpawn.SpawnablePlanes = nil
  veafSpawn.dumpSpawnablePlanesList(nil)
  luaunit.assertTrue(true)
end

function TestVeafSpawnAircraft:test_spawnAFAC_with_template()
  -- Populate templates so findSpawnableAircraftGroupname returns a valid name.
  -- mist.teleportToPoint returns nil → spawnAFAC logs error and returns nil.
  veafSpawn.SpawnablePlanes = { { name = "veafSpawn-ALPHA", units = {} } }
  veafSpawn.initializeAirUnitTemplates()
  veafSpawn.SpawnablePlanes = nil
  local result = veafSpawn.spawnAFAC({ x = 0, y = 0, z = 0 }, "ALPHA", "usa", 15000, 300, 0, 130000000, "AM", 1688, false, true, false)
  luaunit.assertNil(result)
end

function TestVeafSpawnAircraft:test_spawnCombatAirPatrol_with_template()
  -- Patch findSpawnableAircraftGroupname to return both name and non-nil data.
  -- mist.teleportToPoint returns nil → spawnCombatAirPatrol logs error and returns nil.
  local origFind = veafSpawn.findSpawnableAircraftGroupname
  veafSpawn.findSpawnableAircraftGroupname = function(name)
    return "veafSpawn-ALPHA", { groupId = 1, units = {}, route = nil }
  end
  local result = veafSpawn.spawnCombatAirPatrol({ x = 0, y = 0, z = 0 }, 0, "ALPHA", "usa", 0, 0, 0, 20, nil, 60, "random", true, false)
  veafSpawn.findSpawnableAircraftGroupname = origFind
  luaunit.assertNil(result)
end

os.exit(luaunit.LuaUnit.run())
