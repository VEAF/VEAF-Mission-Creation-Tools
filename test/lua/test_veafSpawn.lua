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
  local obj = {
    isExist = function()
      return false
    end,
  }
  veafSpawn.destroyObjectWithFlak(obj, 1, 1)
  luaunit.assertTrue(true)
end

function TestVeafSpawnEffects:test_destroyObjectWithFlak_exists()
  local obj = {
    isExist = function()
      return true
    end,
    getPoint = function()
      return { x = 0, y = 100, z = 0 }
    end,
    getVelocity = function()
      return { x = 0, y = 0, z = 0 }
    end,
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
  veafSpawn.registerCommandHandler("testkey", "OPEN", function()
    called = true
  end)
  luaunit.assertEquals(#veafSpawn.commandHandlers, 1)
  luaunit.assertEquals(veafSpawn.commandHandlers[1].key, "testkey")
end

--- The 2-argument form (key, fn) used to mean "no security check", so omitting the level
--- and forgetting it were indistinguishable. That is the shape SECREV-2 ticket 03 removes:
--- the call is now refused rather than silently registering an ungated command.
function TestVeafSpawnCore:test_registerCommandHandler_refuses_the_legacy_2arg_form()
  local ok, err = pcall(veafSpawn.registerCommandHandler, "k", function() end)

  luaunit.assertFalse(ok)
  luaunit.assertNotNil(string.find(tostring(err), "2-argument form", 1, true))
  luaunit.assertEquals(#veafSpawn.commandHandlers, 0)
end

--- A misspelled level must not be accepted and then quietly deny at dispatch either: it is
--- a typo in the source, and the place to catch it is registration.
function TestVeafSpawnCore:test_registerCommandHandler_refuses_an_unknown_level()
  local ok = pcall(veafSpawn.registerCommandHandler, "k", "BOGUS", function() end)

  luaunit.assertFalse(ok)
  luaunit.assertEquals(#veafSpawn.commandHandlers, 0)
end

function TestVeafSpawnCore:test_registerCommandHandler_stores_security_level()
  local fn = function() end
  veafSpawn.registerCommandHandler("k", "L9", fn)
  luaunit.assertEquals(veafSpawn.commandHandlers[1].fn, fn)
  luaunit.assertEquals(veafSpawn.commandHandlers[1].security, "L9")
end

function TestVeafSpawnCore:test_unknown_parameter_aborts_without_spawning()
  -- An unrecognized parameter (typo) must abort the command, not spawn anyway.
  local spawned = false
  veafSpawn.registerCommandHandler("unit", "OPEN", function()
    spawned = true
    return nil
  end)
  veafSpawn.executeCommand({ x = 0, y = 0, z = 0 }, "_spawn unit, name shilka, headng 90", 1, nil, true)
  luaunit.assertFalse(spawned)
end

function TestVeafSpawnCore:test_known_parameters_still_spawn()
  -- A valid command (no unknown parameter) still reaches its handler.
  local spawned = false
  veafSpawn.registerCommandHandler("unit", "OPEN", function()
    spawned = true
    return nil
  end)
  veafSpawn.executeCommand({ x = 0, y = 0, z = 0 }, "_spawn unit, name shilka, heading 90", 1, nil, true)
  luaunit.assertTrue(spawned)
end

function TestVeafSpawnCore:test_security_gate_blocks_handler_when_check_fails()
  local orig = veafSecurity.checkSecurity_MM
  veafSecurity.checkSecurity_MM = function()
    return false
  end
  local called = false
  veafSpawn.registerCommandHandler("mmGetFlag", "MM", function()
    called = true
  end)
  -- check fails -> handler must not run
  veafSpawn.executeCommand({ x = 0, y = 0, z = 0 }, "_mm getflag, name f", 2, 0, false, nil, nil, nil, nil, false)
  veafSecurity.checkSecurity_MM = orig
  luaunit.assertFalse(called)
end

function TestVeafSpawnCore:test_security_gate_allows_handler_when_check_passes()
  local orig = veafSecurity.checkSecurity_MM
  veafSecurity.checkSecurity_MM = function()
    return true
  end
  local called = false
  veafSpawn.registerCommandHandler("mmGetFlag", "MM", function()
    called = true
  end)
  veafSpawn.executeCommand({ x = 0, y = 0, z = 0 }, "_mm getflag, name f", 2, 0, false, nil, nil, nil, nil, false)
  veafSecurity.checkSecurity_MM = orig
  luaunit.assertTrue(called)
end

function TestVeafSpawnCore:test_security_gate_fail_closed_on_unknown_level()
  local called = false
  -- Registration refuses an unknown level outright now, so it is injected afterwards: this
  -- pins the *direction* of the dispatcher's fallback, which must deny rather than pass.
  veafSpawn.registerCommandHandler("mmGetFlag", "MM", function()
    called = true
  end)
  veafSpawn.commandHandlers[1].security = "BOGUS"
  veafSpawn.executeCommand({ x = 0, y = 0, z = 0 }, "_mm getflag, name f", 2, 0, false, nil, nil, nil, nil, false)
  luaunit.assertFalse(called)
end

function TestVeafSpawnCore:test_security_gate_bypassed_when_bypassSecurity()
  local orig = veafSecurity.checkSecurity_MM
  veafSecurity.checkSecurity_MM = function()
    return false
  end
  local called = false
  veafSpawn.registerCommandHandler("mmGetFlag", "MM", function()
    called = true
  end)
  -- bypassSecurity = true -> handler runs even though the check would fail
  veafSpawn.executeCommand({ x = 0, y = 0, z = 0 }, "_mm getflag, name f", 2, 0, true, nil, nil, nil, nil, false)
  veafSecurity.checkSecurity_MM = orig
  luaunit.assertTrue(called)
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
  local result =
    veafSpawn.doSpawnGroup({ x = 0, y = 0, z = 0 }, 0, "NonExistentGroup", nil, "usa", 0, 0, 10, nil, true, false, false, false)
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
  veafSpawn.missionMasterAddRunnable("MYCODE", function()
    return 42
  end, nil)
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
  veafSpawn.missionMasterAddRunnable("OK", function()
    return 99
  end, nil)
  veafSpawn.missionMasterRun("OK")
  luaunit.assertTrue(true)
end

function TestVeafSpawnCore:test_missionMasterRun_error()
  veafSpawn.missionMasterAddRunnable("ERR", function()
    error("boom")
  end, nil)
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
  veafSpawn.spawnedConvoys = {}
  self._savedCtld = ctld
  self._savedConfig = veaf.config.ctld
end

function TestVeafSpawnGround:tearDown()
  ctld = self._savedCtld
  veaf.config.ctld = self._savedConfig
end

-- A FOB needs CTLD, and there are two ways not to have it. The v1 code knew only one
-- (veaf.ctld_initialized, set by the init wrapper); the module gate distinguishes them.

function TestVeafSpawnGround:test_spawnFob_without_the_ctld_script()
  ctld = nil
  local result = veafSpawn.spawnFob({ x = 0, y = 0, z = 0 }, 0, "TestFOB", "usa", "simple", 1, 0, 10, true, false)
  luaunit.assertNil(result)
end

function TestVeafSpawnGround:test_spawnFob_with_the_ctld_module_disabled()
  veaf.config.ctld = { enable = false }
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

-- ---------------------------------------------------------------------------
-- TestVeafSpawnGroundSceneryAware — FEAT-SCENERY-AWARE-SPAWN
--
-- The four dynamic ground spawners and the generic doSpawnGroup now pick their
-- group centre through veaf.findSpawnPoint instead of jittering once and using the
-- result unvalidated. What is pinned here is the wiring, not the search itself
-- (that lives in test_veaf.lua): the centre that reaches placeGroup, and the
-- single abort-with-one-message when no point works anywhere.
-- ---------------------------------------------------------------------------
TestVeafSpawnGroundSceneryAware = {}

function TestVeafSpawnGroundSceneryAware:setUp()
  dcs_mocks.reset()
  veaf.DO_NOT_EXPORT_JSON_FILES = true
  self._savedDisposition = Disposition
  self._savedGetSurfaceType = land.getSurfaceType
  self._savedGetRandPoint = mist.getRandPointInCircle
  self._savedPlaceGroup = veafUnits.placeGroup
  self._savedOptOut = veaf.doNotAvoidScenery
  Disposition = nil
  veaf.doNotAvoidScenery = false
  -- Record the centre every spawn hands to placeGroup, then delegate.
  self.centres = {}
  veafUnits.placeGroup = function(group, spawnPoint, spacing, hdg, hasDest)
    table.insert(self.centres, { x = spawnPoint.x, y = spawnPoint.y, z = spawnPoint.z })
    return self._savedPlaceGroup(group, spawnPoint, spacing, hdg, hasDest)
  end
end

function TestVeafSpawnGroundSceneryAware:tearDown()
  Disposition = self._savedDisposition
  land.getSurfaceType = self._savedGetSurfaceType
  mist.getRandPointInCircle = self._savedGetRandPoint
  veafUnits.placeGroup = self._savedPlaceGroup
  veaf.doNotAvoidScenery = self._savedOptOut
end

--- All water, so every tier is exhausted.
function TestVeafSpawnGroundSceneryAware:_allWater()
  land.getSurfaceType = function()
    return land.SurfaceType.WATER
  end
end

--- Jitter walks the given x offsets, one per call; water is decided by x.
function TestVeafSpawnGroundSceneryAware:_jitter(xs, waterXs)
  local water = {}
  for _, x in ipairs(waterXs or {}) do
    water[x] = true
  end
  land.getSurfaceType = function(vec2)
    if water[vec2.x] then
      return land.SurfaceType.WATER
    end
    return land.SurfaceType.LAND
  end
  local calls = 0
  mist.getRandPointInCircle = function(spot, _r)
    calls = calls + 1
    return { x = xs[calls] or xs[#xs], y = 0, z = spot.z or 0 }
  end
end

function TestVeafSpawnGroundSceneryAware:test_a_water_candidate_is_skipped_and_the_spawn_still_happens()
  -- Before this lot the first jitter was used as-is, so this spawn put its centre in
  -- the sea and every unit was dropped downstream one by one.
  self:_jitter({ 100, 700 }, { 100 })
  local result = veafSpawn.spawnInfantryGroup({ x = 0, y = 0, z = 0 }, 1000, nil, "usa", 2, 0, 10, 1, 0, 3, true, false)
  luaunit.assertIsString(result)
  luaunit.assertEquals(#self.centres, 1)
  luaunit.assertEquals(self.centres[1].x, 700, "the water candidate must not become the group centre")
end

function TestVeafSpawnGroundSceneryAware:test_no_position_anywhere_aborts_before_placing_anything()
  self:_allWater()
  local result = veafSpawn.spawnInfantryGroup({ x = 0, y = 0, z = 0 }, 1000, nil, "usa", 2, 0, 10, 1, 0, 3, false, false)
  luaunit.assertNil(result)
  luaunit.assertEquals(#self.centres, 0, "placeGroup must not run when no centre was found")
  -- veafI18n is not loaded by this suite, so veaf.t echoes the key — same convention as
  -- test_veafAssist.lua asserting on "step.one".
  luaunit.assertEquals(#dcs_mocks.messagesContaining("spawn.no_position_group"), 1, "exactly one message, not one per unit")
end

function TestVeafSpawnGroundSceneryAware:test_silent_failure_says_nothing_to_the_players()
  self:_allWater()
  local result = veafSpawn.spawnInfantryGroup({ x = 0, y = 0, z = 0 }, 1000, nil, "usa", 2, 0, 10, 1, 0, 3, true, false)
  luaunit.assertNil(result)
  luaunit.assertEquals(#dcs_mocks.messages, 0)
end

function TestVeafSpawnGroundSceneryAware:test_armored_platoon_aborts_the_same_way()
  self:_allWater()
  local result = veafSpawn.spawnArmoredPlatoon({ x = 0, y = 0, z = 0 }, 1000, nil, "usa", 2, 0, 10, 1, 1, 3, true, false, false)
  luaunit.assertNil(result)
  luaunit.assertEquals(#self.centres, 0)
end

function TestVeafSpawnGroundSceneryAware:test_air_defense_battery_aborts_the_same_way()
  self:_allWater()
  local result = veafSpawn.spawnAirDefenseBattery({ x = 0, y = 0, z = 0 }, 1000, nil, "usa", 2, 0, 10, 1, true, false, false)
  luaunit.assertNil(result)
  luaunit.assertEquals(#self.centres, 0)
end

function TestVeafSpawnGroundSceneryAware:test_transport_company_aborts_the_same_way()
  self:_allWater()
  local result = veafSpawn.spawnTransportCompany({ x = 0, y = 0, z = 0 }, 1000, nil, "usa", 2, 0, 10, 1, 3, true, false, false)
  luaunit.assertNil(result)
  luaunit.assertEquals(#self.centres, 0)
end

function TestVeafSpawnGroundSceneryAware:test_scenery_aware_point_becomes_the_group_centre()
  -- Was written with a candidate at x=4200 for a 1000 m request, and passed — which is exactly
  -- the bug measured in a live DCS on 2026-08-06: Disposition's radius argument does not bound
  -- its answers, and tier 1 had no distance test, so a group could be placed kilometres from
  -- where it was asked for. The candidate is now inside the requested radius; the rejection is
  -- pinned by the test below.
  Disposition = {
    getSimpleZones = function()
      return { { x = 420, y = 0, z = 77 } }
    end,
  }
  self:_jitter({ 100 })
  local result = veafSpawn.spawnInfantryGroup({ x = 0, y = 0, z = 0 }, 1000, nil, "usa", 2, 0, 10, 1, 0, 3, true, false)
  luaunit.assertIsString(result)
  luaunit.assertEquals(self.centres[1].x, 420)
  luaunit.assertEquals(self.centres[1].z, 77)
end

function TestVeafSpawnGroundSceneryAware:test_a_far_scenery_point_does_not_become_the_group_centre()
  -- 4200 m for a 1000 m request. The whole group used to move there in silence.
  Disposition = {
    getSimpleZones = function()
      return { { x = 4200, y = 0, z = 77 } }
    end,
  }
  self:_jitter({ 100 })
  local result = veafSpawn.spawnInfantryGroup({ x = 0, y = 0, z = 0 }, 1000, nil, "usa", 2, 0, 10, 1, 0, 3, true, false)
  luaunit.assertIsString(result)
  luaunit.assertEquals(self.centres[1].x, 100, "out-of-range scenery point must give way to the jitter tier")
end

function TestVeafSpawnGroundSceneryAware:test_opt_out_ignores_the_singleton()
  local called = false
  Disposition = {
    getSimpleZones = function()
      called = true
      return { { x = 4200, y = 0, z = 77 } }
    end,
  }
  veaf.doNotAvoidScenery = true
  self:_jitter({ 100 })
  veafSpawn.spawnInfantryGroup({ x = 0, y = 0, z = 0 }, 1000, nil, "usa", 2, 0, 10, 1, 0, 3, true, false)
  luaunit.assertFalse(called)
  luaunit.assertEquals(self.centres[1].x, 100)
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
  local result = veafSpawn.spawnFob({ x = 0, y = 0, z = 0 }, 0, "TestFOB2", "usa", "", 1, 0, 0, true, false)
  luaunit.assertIsString(result)
  luaunit.assertStrContains(result, "TestFOB2")
end

function TestVeafSpawnGround:test_spawnFob_registers_a_logistic_zone_and_a_beacon()
  -- The v1 code pushed the name into three CTLD tables and numbered the beacon itself;
  -- both are the managers' business now.
  dcs_mocks.reset()
  veafSpawn.spawnFob({ x = 0, y = 0, z = 0 }, 0, "TestFOB3", "usa", "", 1, 0, 0, true, false)

  local zoneCalls = CTLDZoneManager.getInstance().calls
  luaunit.assertEquals(#zoneCalls, 1)
  luaunit.assertEquals(zoneCalls[1].method, "registerFOBAsLogistic")
  luaunit.assertStrContains(zoneCalls[1].args[1], "TestFOB3")

  local beaconCalls = CTLDBeaconManager.getInstance().calls
  luaunit.assertEquals(#beaconCalls, 1)
  luaunit.assertEquals(beaconCalls[1].method, "createAtPoint")
  -- isFOB: a FOB beacon never runs out of battery, as the v1 call said with -1.
  luaunit.assertTrue(beaconCalls[1].args[4].isFOB)
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
  -- Goes to the v2 manager, not the legacy ctld.JTACAutoLase wrapper: that one logs a
  -- DEPRECATED line on every call, and a mission spawns JTACs often.
  dcs_mocks.reset()
  veafSpawn.JTACAutoLase("JTAC1", 1688, nil)
  local calls = CTLDJTACManager.getInstance().calls
  luaunit.assertEquals(#calls, 1)
  luaunit.assertEquals(calls[1].method, "autoLase")
  luaunit.assertEquals(calls[1].args[1], "JTAC1")
  luaunit.assertEquals(calls[1].args[2], 1688)
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
  local result =
    veafSpawn.spawnAFAC({ x = 0, y = 0, z = 0 }, "AFAC1", "invalid_country", 15000, 300, 0, 130000000, "AM", 1688, false, true, false)
  luaunit.assertNil(result)
end

function TestVeafSpawnAircraft:test_spawnAFAC_no_template()
  local result = veafSpawn.spawnAFAC({ x = 0, y = 0, z = 0 }, "NoSuchAFAC", "usa", 15000, 300, 0, 130000000, "AM", 1688, false, true, false)
  luaunit.assertNil(result)
end

function TestVeafSpawnAircraft:test_spawnCombatAirPatrol_invalid_country()
  local result =
    veafSpawn.spawnCombatAirPatrol({ x = 0, y = 0, z = 0 }, 0, "MiG-29", "invalid_country", 0, 0, 0, 20, nil, 60, "random", true, false)
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
  veafUnits.findUnit = function(name)
    return nil
  end
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
