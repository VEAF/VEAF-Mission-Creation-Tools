--- Tests for veafSpawn.lua — constants, markTextAnalysis, missionMaster, helpers.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
-- The catalog, not just the runtime: FEAT-CONVOY-WAYPOINTS asserts on the *messages* a convoy command
-- gives the player, and `veaf.t` hands back the bare key when the catalog was never loaded.
dofile(src .. "/veafI18n.lua")
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
  -- Was 1500, which this test asserted produced a frequency. It does not: a DCS laser code
  -- carries no 0 digit, so 1500 is not dialable and VMR-102 now refuses it. 1511 is.
  luaunit.assertIsString(veafSpawn.convertLaserToFreq(1511))
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

--- FIX-DOCAUDIT-CODE 01 — the tier names REVIEW-SECURITY-LAYER decision b settled on (2026-08-08)
--- were refused here too: this dispatcher's table held `L9`/`L1`/`MM`/`OPEN` only, so a handler
--- declaring `ADMIN` failed the assert. Both vocabularies now, in one sweep. `MM` and `OPEN` are
--- not tiers — a Mission Master password carries no level, and OPEN means "no check" — so they keep
--- their own spelling.
function TestVeafSpawnCore:test_registerCommandHandler_accepts_both_vocabularies()
  local levels = { "ADMIN", "SENIOR_PILOT", "KNOWN_PILOT", "L0", "L1", "L9", "MM", "OPEN" }
  for _, level in ipairs(levels) do
    veafSpawn.commandHandlers = {}
    veafSpawn.registerCommandHandler("k", level, function() end)
    luaunit.assertEquals(#veafSpawn.commandHandlers, 1, "level rejected: " .. tostring(level))
    luaunit.assertEquals(veafSpawn.commandHandlers[1].security, level)
  end
end

--- A deprecated name and its replacement share the **same** function, not a copy: two copies is
--- how one of two paths receives tomorrow's fix.
function TestVeafSpawnCore:test_a_deprecated_level_shares_its_replacement_check()
  luaunit.assertIs(veafSpawn.SECURITY_CHECKS.L0, veafSpawn.SECURITY_CHECKS.ADMIN)
  luaunit.assertIs(veafSpawn.SECURITY_CHECKS.L1, veafSpawn.SECURITY_CHECKS.SENIOR_PILOT)
  luaunit.assertIs(veafSpawn.SECURITY_CHECKS.L9, veafSpawn.SECURITY_CHECKS.KNOWN_PILOT)
end

--- The new names must be *enforced*, not merely accepted at registration — and enforced by the
--- check the name actually means. `ADMIN` is the tightest tier, so it runs `checkSecurity_L0`; the
--- ticket's own example claimed `ADMIN ≡ L9`, which `veafSecurity.LEVELS_BY_NAME` contradicts.
--- Stubbing that one function is what pins the wiring: a mis-aliased `ADMIN` would sail through.
function TestVeafSpawnCore:_runAdminHandlerWith(verdict)
  local orig = veafSecurity.checkSecurity_L0
  veafSecurity.checkSecurity_L0 = function()
    return verdict
  end
  local called = false
  veafSpawn.registerCommandHandler("unit", "ADMIN", function()
    called = true
    return nil
  end)
  veafSpawn.executeCommand({ x = 0, y = 0, z = 0 }, "_spawn unit, name shilka", 1, 0, false)
  veafSecurity.checkSecurity_L0 = orig
  return called
end

function TestVeafSpawnCore:test_an_admin_handler_is_blocked_when_the_admin_check_fails()
  luaunit.assertFalse(self:_runAdminHandlerWith(false))
end

function TestVeafSpawnCore:test_an_admin_handler_runs_when_the_admin_check_passes()
  luaunit.assertTrue(self:_runAdminHandlerWith(true))
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

-- A FOB needs CTLD, and there are three ways not to have it. The v1 code knew only one
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

function TestVeafSpawnGround:test_spawnFob_with_ctld_loaded_but_never_started()
  -- The third state, and the one that used to crash rather than refuse: the script is there
  -- and the module is on, but nothing called veaf.ctld_initialize(), so CTLD's configuration
  -- was never read (FIX-CTLD-NEVER-INITIALIZED).
  CTLDConfig._instance.isLoaded = false
  local result = veafSpawn.spawnFob({ x = 0, y = 0, z = 0 }, 0, "TestFOB", "usa", "simple", 1, 0, 10, true, false)
  luaunit.assertNil(result)
  luaunit.assertEquals(#CTLDZoneManager._instance.calls, 0)
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
  -- The suite loads veafI18n since FEAT-CONVOY-WAYPOINTS (its tests assert on the messages a convoy
  -- command gives the player), so `veaf.t` resolves rather than echoing the key. Matching on the
  -- rendered text keeps the assertion on what a player actually reads.
  luaunit.assertEquals(#dcs_mocks.messagesContaining(veaf.t("spawn.no_position_group")), 1, "exactly one message, not one per unit")
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

-------------------------------------------------------------------------------------------------
-- SECREV-2 / ticket 07, Lua batch 3 — the spawn family
-------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------
-- VMR-098 — no free AFAC callsign must refuse the spawn, not reuse a taken one
--
-- The callsign loop falls back to `callsigns[coalition][numberSpawned]` when it finds nothing
-- free, so a desynchronised counter handed out a callsign another live AFAC already answers to:
-- two aircraft on the same name, and the watchdog then frees a slot that is still flying.
--
-- The finding also asked for `>` → `>=` on the limit check. That one does NOT apply and was
-- deliberately left alone: `numberSpawned` is pre-incremented (set to 1 before the first spawn),
-- so `> maximumAmount` already refuses the 9th AFAC. `>=` would have capped missions at 7.
-------------------------------------------------------------------------------------------------

TestSecrev2AfacCallsigns = {}

function TestSecrev2AfacCallsigns:setUp()
  dcs_mocks.reset()
  veaf.DO_NOT_EXPORT_JSON_FILES = true
  veafSpawn.airUnitTemplates = {}
  veafSpawn.SpawnablePlanes = { { name = "veafSpawn-ALPHA", units = {} } }
  veafSpawn.initializeAirUnitTemplates()
  veafSpawn.SpawnablePlanes = nil
  for i = 1, veafSpawn.AFAC.maximumAmount do
    veafSpawn.AFAC.callsigns[coalition.side.BLUE][i].taken = false
  end
  veafSpawn.AFAC.numberSpawned[coalition.side.BLUE] = nil
end

function TestSecrev2AfacCallsigns:tearDown()
  for i = 1, veafSpawn.AFAC.maximumAmount do
    veafSpawn.AFAC.callsigns[coalition.side.BLUE][i].taken = false
  end
  veafSpawn.AFAC.numberSpawned[coalition.side.BLUE] = nil
end

local function _spawnAfac()
  return veafSpawn.spawnAFAC({ x = 0, y = 0, z = 0 }, "ALPHA", "usa", 15000, 300, 0, 130000000, "AM", 1688, false, true, false)
end

function TestSecrev2AfacCallsigns:test_every_callsign_taken_refuses_the_spawn()
  -- All 8 answered for, but the counter says there is room (what the watchdog leaves behind
  -- when it frees the counter without the callsign, or vice versa).
  for i = 1, veafSpawn.AFAC.maximumAmount do
    veafSpawn.AFAC.callsigns[coalition.side.BLUE][i].taken = true
  end
  veafSpawn.AFAC.numberSpawned[coalition.side.BLUE] = 1
  luaunit.assertFalse(_spawnAfac())
end

function TestSecrev2AfacCallsigns:test_refusing_leaves_the_taken_callsigns_alone()
  for i = 1, veafSpawn.AFAC.maximumAmount do
    veafSpawn.AFAC.callsigns[coalition.side.BLUE][i].taken = true
  end
  veafSpawn.AFAC.numberSpawned[coalition.side.BLUE] = 1
  _spawnAfac()
  for i = 1, veafSpawn.AFAC.maximumAmount do
    luaunit.assertTrue(veafSpawn.AFAC.callsigns[coalition.side.BLUE][i].taken, "callsign " .. i .. " was released by a refused spawn")
  end
end

-- The control. Without it the two tests above would also pass if spawnAFAC refused
-- everything, which is exactly the failure mode this ticket keeps running into.
function TestSecrev2AfacCallsigns:test_one_free_callsign_still_reaches_the_spawn()
  for i = 1, veafSpawn.AFAC.maximumAmount do
    veafSpawn.AFAC.callsigns[coalition.side.BLUE][i].taken = true
  end
  veafSpawn.AFAC.callsigns[coalition.side.BLUE][5].taken = false
  veafSpawn.AFAC.numberSpawned[coalition.side.BLUE] = 1
  -- mist.teleportToPoint returns nil in the mocks, so the spawn itself fails with nil —
  -- a different outcome from the `false` that means "refused before trying".
  luaunit.assertNil(_spawnAfac())
end

function TestSecrev2AfacCallsigns:test_the_limit_still_allows_eight_afacs()
  -- Guards the `>` the finding wanted turned into `>=`: with 7 AFACs flying the 8th is allowed.
  for i = 1, 7 do
    veafSpawn.AFAC.callsigns[coalition.side.BLUE][i].taken = true
  end
  veafSpawn.AFAC.numberSpawned[coalition.side.BLUE] = 8
  luaunit.assertNil(_spawnAfac())
end

function TestSecrev2AfacCallsigns:test_the_limit_still_refuses_the_ninth()
  for i = 1, veafSpawn.AFAC.maximumAmount do
    veafSpawn.AFAC.callsigns[coalition.side.BLUE][i].taken = true
  end
  veafSpawn.AFAC.numberSpawned[coalition.side.BLUE] = 9
  luaunit.assertFalse(_spawnAfac())
end

-------------------------------------------------------------------------------------------------
-- VMR-099 — `-showmfd` was inverted on the afac and cap commands
--
-- Every other handler passes `not options.showMFD` for the `hiddenOnMFD` parameter. These two
-- passed `options.showMFD` straight through, so the default (showMFD=false) left the aircraft
-- VISIBLE on every MFD and asking for it hid it. The finding named `afac` only; `cap` has it too.
-------------------------------------------------------------------------------------------------

TestSecrev2ShowMfd = {}

local function _handlerFor(key)
  for _, entry in ipairs(veafSpawn.commandHandlers) do
    if entry.key == key then
      return entry.fn
    end
  end
  return nil
end

function TestSecrev2ShowMfd:setUp()
  dcs_mocks.reset()
  self._savedAfac = veafSpawn.spawnAFAC
  self._savedCap = veafSpawn.spawnCombatAirPatrol
end

function TestSecrev2ShowMfd:tearDown()
  veafSpawn.spawnAFAC = self._savedAfac
  veafSpawn.spawnCombatAirPatrol = self._savedCap
end

--- Run a spawn command handler with the real spawner replaced by a recorder.
--- Returns the `hiddenOnMFD` argument the handler passed on.
local function _hiddenOnMfdFor(key, spawnerField, argIndex, showMFD)
  local captured
  veafSpawn[spawnerField] = function(...)
    captured = select(argIndex, ...)
    return "recorded-group"
  end
  _handlerFor(key)(
    { x = 0, y = 0, z = 0 },
    { [key] = true, showMFD = showMFD, country = "usa", mod = "fm" },
    coalition.side.BLUE,
    nil,
    true
  )
  return captured
end

function TestSecrev2ShowMfd:test_afac_handler_is_registered()
  luaunit.assertIsFunction(_handlerFor("afac"))
end

function TestSecrev2ShowMfd:test_afac_defaults_to_hidden_on_mfd()
  luaunit.assertTrue(_hiddenOnMfdFor("afac", "spawnAFAC", 12, false))
end

function TestSecrev2ShowMfd:test_afac_showmfd_shows_it()
  luaunit.assertFalse(_hiddenOnMfdFor("afac", "spawnAFAC", 12, true))
end

function TestSecrev2ShowMfd:test_cap_defaults_to_hidden_on_mfd()
  luaunit.assertTrue(_hiddenOnMfdFor("cap", "spawnCombatAirPatrol", 13, false))
end

function TestSecrev2ShowMfd:test_cap_showmfd_shows_it()
  luaunit.assertFalse(_hiddenOnMfdFor("cap", "spawnCombatAirPatrol", 13, true))
end

-------------------------------------------------------------------------------------------------
-- VMR-100 — the cargo weight computation must not write into the shared units database
--
-- `veafUnits.findDcsUnit` hands back the live `dcsUnits.DcsUnitsDatabase` entry, and the
-- min/max swap wrote both fields back into it. Every later reader of that type — the
-- dcsDataExport dump among them — saw the edited descriptor.
-------------------------------------------------------------------------------------------------

TestSecrev2CargoMass = {}

function TestSecrev2CargoMass:setUp()
  dcs_mocks.reset()
  veaf.DO_NOT_EXPORT_JSON_FILES = true
  self._savedFind = veafUnits.findDcsUnit
  self._savedDynAddStatic = mist.dynAddStatic
  -- A descriptor with the bounds the wrong way round: the branch the finding is about.
  self.shared = { type = "veaf_test_cargo", name = "VEAF test cargo", desc = { minMass = 100, maxMass = 50 } }
  veafUnits.findDcsUnit = function(name)
    return self.shared
  end
  self.spawned = {}
  mist.dynAddStatic = function(template)
    table.insert(self.spawned, template)
  end
end

function TestSecrev2CargoMass:tearDown()
  veafUnits.findDcsUnit = self._savedFind
  mist.dynAddStatic = self._savedDynAddStatic
end

function TestSecrev2CargoMass:test_the_shared_descriptor_is_left_untouched()
  veafSpawn.spawnCargo({ x = 0, y = 0, z = 0 }, 0, "veaf_test_cargo", "usa", 2, false, nil, true, false)
  luaunit.assertEquals(self.shared.desc.minMass, 100)
  luaunit.assertEquals(self.shared.desc.maxMass, 50)
end

-- The control: the mass must still be computed from the reordered bounds, otherwise the test
-- above would pass just as well on a function that gave up before reading them.
function TestSecrev2CargoMass:test_the_mass_is_still_computed_within_the_bounds()
  veafSpawn.spawnCargo({ x = 0, y = 0, z = 0 }, 0, "veaf_test_cargo", "usa", 2, false, nil, true, false)
  luaunit.assertEquals(#self.spawned, 1)
  local mass = self.spawned[1].mass
  luaunit.assertNotNil(mass)
  luaunit.assertTrue(mass >= 50 and mass <= 100, "mass " .. tostring(mass) .. " is outside the descriptor's bounds")
end

-------------------------------------------------------------------------------------------------
-- VMR-101 — one positionless convoy must not hide the others
--
-- `_findClosestConvoy` returned nil as soon as `veaf.getAveragePosition` failed for any single
-- convoy, so a despawned convoy still sitting in `spawnedConvoys` blinded "mark/stop/move
-- closest convoy" for every live one.
-------------------------------------------------------------------------------------------------

TestSecrev2ClosestConvoy = {}

function TestSecrev2ClosestConvoy:setUp()
  dcs_mocks.reset()
  self._savedGetAveragePosition = veaf.getAveragePosition
  self._savedGetHuman = veafRadio.getHumanUnitOrWingman
  veafRadio.getHumanUnitOrWingman = function(name)
    return {
      getPosition = function()
        return { p = { x = 0, y = 0, z = 0 } }
      end,
    }
  end
  veafSpawn.spawnedConvoys = {}
end

function TestSecrev2ClosestConvoy:tearDown()
  veaf.getAveragePosition = self._savedGetAveragePosition
  veafRadio.getHumanUnitOrWingman = self._savedGetHuman
  veafSpawn.spawnedConvoys = {}
end

--- Position every convoy but the ones named in `positionless`.
local function _positionConvoysExcept(positionless, positions)
  veaf.getAveragePosition = function(name)
    if positionless[name] then
      return nil
    end
    return positions[name]
  end
end

function TestSecrev2ClosestConvoy:test_a_positionless_convoy_does_not_hide_a_live_one()
  -- Both orders are exercised, since `pairs` gives no ordering guarantee: whichever way the
  -- table is walked, the live convoy must be the answer.
  veafSpawn.spawnedConvoys = { ["convoy-dead"] = {}, ["convoy-alive"] = {} }
  _positionConvoysExcept({ ["convoy-dead"] = true }, { ["convoy-alive"] = { x = 300, y = 0, z = 0 } })
  luaunit.assertEquals(veafSpawn._findClosestConvoy("player-1"), "convoy-alive")

  veafSpawn.spawnedConvoys = { ["aaa-dead"] = {}, ["zzz-alive"] = {} }
  _positionConvoysExcept({ ["aaa-dead"] = true }, { ["zzz-alive"] = { x = 300, y = 0, z = 0 } })
  luaunit.assertEquals(veafSpawn._findClosestConvoy("player-1"), "zzz-alive")
end

-- The control: with every convoy positioned, the closest one still wins.
function TestSecrev2ClosestConvoy:test_the_closest_positioned_convoy_still_wins()
  veafSpawn.spawnedConvoys = { ["convoy-far"] = {}, ["convoy-near"] = {} }
  _positionConvoysExcept({}, {
    ["convoy-far"] = { x = 9000, y = 0, z = 0 },
    ["convoy-near"] = { x = 120, y = 0, z = 0 },
  })
  luaunit.assertEquals(veafSpawn._findClosestConvoy("player-1"), "convoy-near")
end

function TestSecrev2ClosestConvoy:test_no_convoy_has_a_position_returns_nil()
  veafSpawn.spawnedConvoys = { ["convoy-dead"] = {} }
  _positionConvoysExcept({ ["convoy-dead"] = true }, {})
  luaunit.assertNil(veafSpawn._findClosestConvoy("player-1"))
end

-------------------------------------------------------------------------------------------------
-- FEAT-CONVOY-WAYPOINTS ticket 01/02 — a convoy walks an itinerary
--
-- `veafSpawn.advanceConvoy` moves a convoy onto the next leg of its itinerary, whether the arrival
-- watchdog or a player asked. A leg's route is generated from **where the convoy is now**, not from
-- the original spawn point: the convoy has driven since, and re-using the old origin would send it
-- back to the start before setting off again — the same defect
-- FIX-COMBATZONE-SPAWN-ROUTE-OFFSET fixed for combat zones.
-------------------------------------------------------------------------------------------------

TestConvoyItinerary = {}

function TestConvoyItinerary:setUp()
  dcs_mocks.reset()
  self._route = veaf.generateVehiclesRoute
  self._goRoute = mist.goRoute
  self._avg = veaf.getAveragePosition
  self._outText = trigger.action.outText

  self.generated = {}
  veaf.generateVehiclesRoute = function(startPoint, destination, onRoad, speed, patrol, groupName)
    table.insert(self.generated, {
      startPoint = startPoint,
      destination = destination,
      onRoad = onRoad,
      speed = speed,
      patrol = patrol,
      groupName = groupName,
    })
    return { { name = "generated for " .. tostring(destination) } }
  end
  self.routed = {}
  mist.goRoute = function(name, route)
    table.insert(self.routed, { name = name, route = route })
  end
  veaf.getAveragePosition = function()
    return { x = 500, y = 0, z = 600 }
  end
  trigger.action.outText = function() end

  veafSpawn.spawnedConvoys = {
    ["CONVOY-1"] = {
      name = "CONVOY-1",
      route = { { name = "initial" } },
      itinerary = { "KOBULETI", "BATUMI", "POTI" },
      legIndex = 1,
      speed = 40,
      offroad = false,
      patrol = false,
    },
  }
end

function TestConvoyItinerary:tearDown()
  veaf.generateVehiclesRoute = self._route
  mist.goRoute = self._goRoute
  veaf.getAveragePosition = self._avg
  trigger.action.outText = self._outText
  veafSpawn.spawnedConvoys = {}
end

function TestConvoyItinerary:test_advancing_moves_to_the_next_point()
  luaunit.assertTrue(veafSpawn.advanceConvoy("CONVOY-1"))
  luaunit.assertEquals(veafSpawn.spawnedConvoys["CONVOY-1"].legIndex, 2)
  luaunit.assertEquals(self.generated[1].destination, "BATUMI")
end

-- The leg starts from where the convoy stands, not from where it was spawned.
function TestConvoyItinerary:test_the_new_leg_starts_from_the_convoys_current_position()
  veafSpawn.advanceConvoy("CONVOY-1")
  luaunit.assertEquals(self.generated[1].startPoint.x, 500)
  luaunit.assertEquals(self.generated[1].startPoint.z, 600)
end

function TestConvoyItinerary:test_the_route_is_issued_and_remembered()
  veafSpawn.advanceConvoy("CONVOY-1")
  luaunit.assertEquals(#self.routed, 1)
  luaunit.assertEquals(self.routed[1].name, "CONVOY-1")
  luaunit.assertEquals(veafSpawn.spawnedConvoys["CONVOY-1"].route, self.routed[1].route)
end

function TestConvoyItinerary:test_advancing_twice_walks_the_whole_itinerary()
  veafSpawn.advanceConvoy("CONVOY-1")
  veafSpawn.advanceConvoy("CONVOY-1")
  luaunit.assertEquals(self.generated[1].destination, "BATUMI")
  luaunit.assertEquals(self.generated[2].destination, "POTI")
  luaunit.assertEquals(veafSpawn.spawnedConvoys["CONVOY-1"].legIndex, 3)
end

-- The end of the itinerary is a refusal, not a crash and not a silent no-op: the caller has to be
-- able to tell "moved on" from "there is nowhere left to go", because the watchdog stops on it.
function TestConvoyItinerary:test_the_last_point_refuses_to_advance()
  veafSpawn.spawnedConvoys["CONVOY-1"].legIndex = 3
  luaunit.assertFalse(veafSpawn.advanceConvoy("CONVOY-1"))
  luaunit.assertEquals(#self.generated, 0)
  luaunit.assertEquals(veafSpawn.spawnedConvoys["CONVOY-1"].legIndex, 3)
end

function TestConvoyItinerary:test_an_unknown_convoy_is_refused()
  luaunit.assertFalse(veafSpawn.advanceConvoy("NO-SUCH-CONVOY"))
end

-- A convoy with no position left (every vehicle destroyed) cannot start a leg from nowhere.
function TestConvoyItinerary:test_a_convoy_with_no_position_is_refused()
  veaf.getAveragePosition = function()
    return nil
  end
  luaunit.assertFalse(veafSpawn.advanceConvoy("CONVOY-1"))
  luaunit.assertEquals(#self.generated, 0)
end

-- `patrol` belongs to the end of the itinerary. Patrolling between two waypoints would contradict
-- the itinerary, so intermediate legs are never patrols and the final one is.
function TestConvoyItinerary:test_patrol_applies_only_on_the_last_leg()
  veafSpawn.spawnedConvoys["CONVOY-1"].patrol = true
  veafSpawn.advanceConvoy("CONVOY-1") -- leg to BATUMI, not the last
  luaunit.assertFalse(self.generated[1].patrol)
  veafSpawn.advanceConvoy("CONVOY-1") -- leg to POTI, the last
  luaunit.assertTrue(self.generated[2].patrol)
end

-- `offroad` is stored as written and handed to the route builder inverted, as the spawn does.
function TestConvoyItinerary:test_offroad_is_honoured_on_a_later_leg()
  veafSpawn.spawnedConvoys["CONVOY-1"].offroad = true
  veafSpawn.advanceConvoy("CONVOY-1")
  luaunit.assertFalse(self.generated[1].onRoad)
end

function TestConvoyItinerary:test_the_speed_travels_to_the_next_leg()
  veafSpawn.advanceConvoy("CONVOY-1")
  luaunit.assertEquals(self.generated[1].speed, 40)
end

-- A one-point itinerary is what a single `dest` produces, and it has no next leg at all.
function TestConvoyItinerary:test_a_one_point_itinerary_never_advances()
  veafSpawn.spawnedConvoys["CONVOY-1"].itinerary = { "KOBULETI" }
  luaunit.assertFalse(veafSpawn.advanceConvoy("CONVOY-1"))
end

-------------------------------------------------------------------------------------------------
-- FEAT-CONVOY-WAYPOINTS ticket 02 — arrival advances the convoy
--
-- The watchdog reschedules itself and advances the convoy when it has reached the point it was
-- heading for. Modelled on `veaf.PatrolWatchdog`, which is proven in play, with one deliberate
-- difference: it reads the convoy's **average** position rather than its lead vehicle's.
--
-- That difference answers one of the two things the PRD said to measure — "what is arrival when the
-- lead vehicle is destroyed?" — by removing the question instead of answering it. An average has no
-- lead vehicle to lose, and it returns nil exactly when there is nothing left alive, which is the
-- signal to stop watching.
--
-- Time and positions are injected, so nothing here waits 30 seconds.
-------------------------------------------------------------------------------------------------

TestConvoyArrivalWatchdog = {}

function TestConvoyArrivalWatchdog:setUp()
  dcs_mocks.reset()
  self._avg = veaf.getAveragePosition
  self._schedule = mist.scheduleFunction
  self._goRoute = mist.goRoute
  self._route = veaf.generateVehiclesRoute
  self._getByName = Group.getByName
  self._outText = trigger.action.outText

  self.scheduled = {}
  mist.scheduleFunction = function(fn, args, at)
    table.insert(self.scheduled, { fn = fn, args = args, at = at })
    return #self.scheduled
  end
  self.routed = {}
  mist.goRoute = function(name, route)
    table.insert(self.routed, { name = name, route = route })
  end
  veaf.generateVehiclesRoute = function(_, destination)
    return { { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 9000, y = 9000, name = tostring(destination) } }
  end
  Group.getByName = function()
    return {
      getName = function()
        return "CONVOY-1"
      end,
    }
  end
  trigger.action.outText = function() end

  -- the convoy is heading for a waypoint at mission-table (x=1000, y=2000) — note `y` is the easting
  veafSpawn.spawnedConvoys = {
    ["CONVOY-1"] = {
      name = "CONVOY-1",
      route = { { x = 0, y = 0 }, { x = 500, y = 500 }, { x = 1000, y = 2000, name = "END" } },
      itinerary = { "KOBULETI", "BATUMI" },
      legIndex = 1,
      speed = 40,
      offroad = false,
      patrol = false,
    },
  }
  self:_placeConvoyAt(0, 0)
end

function TestConvoyArrivalWatchdog:tearDown()
  veaf.getAveragePosition = self._avg
  mist.scheduleFunction = self._schedule
  mist.goRoute = self._goRoute
  veaf.generateVehiclesRoute = self._route
  Group.getByName = self._getByName
  trigger.action.outText = self._outText
  veafSpawn.spawnedConvoys = {}
end

--- Place the convoy at a runtime position: `x` northing, `z` easting.
function TestConvoyArrivalWatchdog:_placeConvoyAt(x, z)
  veaf.getAveragePosition = function()
    return { x = x, y = 0, z = z }
  end
end

function TestConvoyArrivalWatchdog:test_far_from_the_point_it_does_not_advance()
  self:_placeConvoyAt(0, 0)
  veafSpawn.convoyArrivalWatchdog("CONVOY-1")
  luaunit.assertEquals(veafSpawn.spawnedConvoys["CONVOY-1"].legIndex, 1)
  luaunit.assertEquals(#self.routed, 0)
end

-- The waypoint's `y` is the easting, so the convoy standing at runtime z = 2000 is *at* it. Getting
-- this backwards is the silent-coordinate mistake docs/agents/dcs-coordinates.md is about.
function TestConvoyArrivalWatchdog:test_on_the_point_it_advances()
  self:_placeConvoyAt(1000, 2000)
  veafSpawn.convoyArrivalWatchdog("CONVOY-1")
  luaunit.assertEquals(veafSpawn.spawnedConvoys["CONVOY-1"].legIndex, 2)
  luaunit.assertEquals(#self.routed, 1)
end

function TestConvoyArrivalWatchdog:test_it_reschedules_itself_while_the_convoy_lives()
  veafSpawn.convoyArrivalWatchdog("CONVOY-1")
  luaunit.assertEquals(#self.scheduled, 1)
  luaunit.assertEquals(self.scheduled[1].args[1], "CONVOY-1")
end

-- Reaching the last point ends the watch: nothing left to advance to, so nothing left to check.
function TestConvoyArrivalWatchdog:test_the_last_point_stops_the_watch()
  veafSpawn.spawnedConvoys["CONVOY-1"].legIndex = 2
  self:_placeConvoyAt(1000, 2000)
  veafSpawn.convoyArrivalWatchdog("CONVOY-1")
  luaunit.assertEquals(#self.scheduled, 0, "no point rescheduling a watch that can never act again")
end

function TestConvoyArrivalWatchdog:test_a_convoy_removed_from_the_registry_stops_the_watch()
  veafSpawn.spawnedConvoys = {}
  veafSpawn.convoyArrivalWatchdog("CONVOY-1")
  luaunit.assertEquals(#self.scheduled, 0)
end

-- Every vehicle destroyed: `getAveragePosition` returns nil, and the watch must end rather than
-- reschedule forever on a convoy that no longer exists.
function TestConvoyArrivalWatchdog:test_a_destroyed_convoy_stops_the_watch()
  veaf.getAveragePosition = function()
    return nil
  end
  veafSpawn.convoyArrivalWatchdog("CONVOY-1")
  luaunit.assertEquals(#self.scheduled, 0)
  luaunit.assertEquals(#self.routed, 0)
end

-- A player-stopped convoy is not advanced, but the watch stays alive: he may resume it.
function TestConvoyArrivalWatchdog:test_a_stopped_convoy_is_not_advanced_but_is_still_watched()
  veafSpawn.spawnedConvoys["CONVOY-1"].stopped = true
  self:_placeConvoyAt(1000, 2000)
  veafSpawn.convoyArrivalWatchdog("CONVOY-1")
  luaunit.assertEquals(veafSpawn.spawnedConvoys["CONVOY-1"].legIndex, 1)
  luaunit.assertEquals(#self.scheduled, 1)
end

-------------------------------------------------------------------------------------------------
-- FEAT-CONVOY-WAYPOINTS ticket 03 — advance, hold and stop as three different things
--
-- David's arbitration, and the part he was explicit about: `hold until further orders` lets the
-- current leg finish and parks at the next point; `stop` halts where it stands. "hold paces a
-- mission, stop rescues one going wrong; naming them alike would make the useful one unusable."
--
-- So the assertions below are as much about what each command *refuses* and what it *says* as about
-- what it sets: a hold that silently did nothing at the last point would be exactly the failure the
-- arbitration warns about.
-------------------------------------------------------------------------------------------------

TestConvoyHoldAndStop = {}

function TestConvoyHoldAndStop:setUp()
  dcs_mocks.reset()
  self._avg = veaf.getAveragePosition
  self._goRoute = mist.goRoute
  self._route = veaf.generateVehiclesRoute
  self._outForUnit = veaf.outTextForUnit
  self._closest = veafSpawn._findClosestConvoy
  -- Two tests below override Group.getByName in their own body. Saving it here is not belt and braces:
  -- without it the binding leaked into TestVeafSpawnAircraft and broke three of its tests. Sourcery
  -- flagged exactly this risk on PR #780 and was right about the risk, if not about the mechanism —
  -- luaunit does run tearDown after a failure, but it cannot restore what tearDown never saved.
  self._getByName = Group.getByName

  self.said = {}
  veaf.outTextForUnit = function(unitName, text, duration)
    table.insert(self.said, text)
  end
  veaf.getAveragePosition = function()
    return { x = 0, y = 0, z = 0 }
  end
  mist.goRoute = function() end
  veaf.generateVehiclesRoute = function()
    return { { x = 0, y = 0 }, { x = 1, y = 1 } }
  end
  veafSpawn._findClosestConvoy = function()
    return "CONVOY-1"
  end

  veafSpawn.spawnedConvoys = {
    ["CONVOY-1"] = {
      name = "CONVOY-1",
      route = { { x = 0, y = 0 }, { x = 1000, y = 2000 } },
      itinerary = { "KOBULETI", "BATUMI", "POTI" },
      legIndex = 1,
      speed = 40,
    },
  }
end

function TestConvoyHoldAndStop:tearDown()
  veaf.getAveragePosition = self._avg
  mist.goRoute = self._goRoute
  veaf.generateVehiclesRoute = self._route
  veaf.outTextForUnit = self._outForUnit
  veafSpawn._findClosestConvoy = self._closest
  Group.getByName = self._getByName
  veafSpawn.spawnedConvoys = {}
end

local function convoy()
  return veafSpawn.spawnedConvoys["CONVOY-1"]
end

-- `hold` does NOT brake. It marks the convoy so that the *arrival* leaves it parked.
function TestConvoyHoldAndStop:test_hold_lets_the_current_leg_finish()
  veafSpawn.holdClosestConvoy("player-1")
  luaunit.assertTrue(convoy().holding)
  luaunit.assertNotEquals(convoy().stopped, true, "hold must not stop the convoy where it stands")
end

function TestConvoyHoldAndStop:test_hold_names_the_point_it_will_park_at()
  veafSpawn.holdClosestConvoy("player-1")
  luaunit.assertEquals(#self.said, 1)
  luaunit.assertStrContains(self.said[1], "KOBULETI")
end

-- The refusal the arbitration implies: on the last leg there is no next point to park at, and saying
-- nothing would leave a game master believing the convoy is under orders.
function TestConvoyHoldAndStop:test_hold_on_the_last_leg_says_so_instead_of_doing_nothing()
  convoy().legIndex = 3
  veafSpawn.holdClosestConvoy("player-1")
  luaunit.assertNotEquals(convoy().holding, true)
  luaunit.assertEquals(#self.said, 1, "the player is told why nothing happened")
end

function TestConvoyHoldAndStop:test_a_held_convoy_can_be_released_by_advancing_it()
  veafSpawn.holdClosestConvoy("player-1")
  veafSpawn.advanceClosestConvoy("player-1")
  luaunit.assertNotEquals(convoy().holding, true)
  luaunit.assertEquals(convoy().legIndex, 2)
end

-- advance is the radio half of "both advance a convoy": same implementation as the watchdog's.
function TestConvoyHoldAndStop:test_advance_starts_the_next_leg_now()
  veafSpawn.advanceClosestConvoy("player-1")
  luaunit.assertEquals(convoy().legIndex, 2)
  luaunit.assertEquals(#self.said, 1)
  luaunit.assertStrContains(self.said[1], "BATUMI")
end

function TestConvoyHoldAndStop:test_advance_at_the_end_of_the_itinerary_says_so()
  convoy().legIndex = 3
  veafSpawn.advanceClosestConvoy("player-1")
  luaunit.assertEquals(convoy().legIndex, 3)
  luaunit.assertEquals(#self.said, 1)
end

-- The pair that must stay distinguishable: the two commands leave different state AND say different
-- things. A test on the state alone would pass on two menu entries reading identically.
function TestConvoyHoldAndStop:test_hold_and_stop_are_not_the_same_command()
  veafSpawn.holdClosestConvoy("player-1")
  local heldMessage = self.said[1]
  veafSpawn.spawnedConvoys["CONVOY-1"].holding = false
  self.said = {}
  veafSpawn.stopClosestConvoy("player-1")
  luaunit.assertNotEquals(self.said[1], heldMessage, "hold and stop must not report the same thing")
end

-- The three cases the tickets' definitions of done name explicitly, and which the tests above did not
-- cover. Written rather than assumed: a ticked box with no test behind it is how
-- FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT lived for three years next to a test that asserted the
-- constant and never its application.

-- Ticket 01: a point name that resolves to nothing. `generateVehiclesRoute` warns the player and
-- returns nil, so the leg must be refused *without* moving the convoy onto it — otherwise the itinerary
-- silently loses a point and the convoy stops one leg early.
function TestConvoyItinerary:test_an_unresolvable_point_does_not_consume_the_leg()
  veaf.generateVehiclesRoute = function()
    return nil
  end
  luaunit.assertFalse(veafSpawn.advanceConvoy("CONVOY-1"))
  luaunit.assertEquals(veafSpawn.spawnedConvoys["CONVOY-1"].legIndex, 1, "the leg is not consumed")
  luaunit.assertEquals(#self.routed, 0)
end

-- Ticket 02: the convoy lost its lead vehicle. The watch reads the group's *average* position, so
-- there is no lead vehicle to lose — this pins that property rather than the arithmetic.
function TestConvoyArrivalWatchdog:test_losing_the_lead_vehicle_does_not_stop_the_advance()
  local asked = {}
  veaf.getAveragePosition = function(name)
    table.insert(asked, name)
    return { x = 1000, y = 0, z = 2000 }
  end
  Group.getByName = function()
    -- a group whose first unit is gone: getUnit(1) is the survivor, and nothing here asks for it
    return {
      getUnit = function()
        return nil
      end,
    }
  end
  veafSpawn.convoyArrivalWatchdog("CONVOY-1")
  luaunit.assertEquals(veafSpawn.spawnedConvoys["CONVOY-1"].legIndex, 2, "arrival is judged on the average, not the lead")
  luaunit.assertTrue(#asked > 0, "the average position is what was consulted")
end

-- Ticket 03: stop then resume, the pair that existed before this lot and must keep working.
function TestConvoyHoldAndStop:test_stop_then_resume_still_works()
  local pushed = {}
  Group.getByName = function()
    return {
      getController = function()
        return {
          pushTask = function(_, task)
            table.insert(pushed, task)
          end,
        }
      end,
    }
  end
  veafSpawn.stopClosestConvoy("player-1")
  luaunit.assertTrue(convoy().stopped)
  luaunit.assertEquals(#pushed, 1)
  luaunit.assertEquals(pushed[1].id, "Hold")

  veafSpawn.moveClosestConvoy("player-1")
  luaunit.assertFalse(convoy().stopped)
end

-- And the refusals: neither command may report success on a convoy already in that state.
function TestConvoyHoldAndStop:test_stopping_a_stopped_convoy_is_refused()
  convoy().stopped = true
  Group.getByName = function()
    return {
      getController = function()
        return { pushTask = function() end }
      end,
    }
  end
  luaunit.assertFalse(veafSpawn.stopClosestConvoy("player-1"))
end

os.exit(luaunit.LuaUnit.run())
