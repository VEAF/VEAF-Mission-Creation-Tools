--- Tests for veafMissileGuardian.lua — VeafMG_Weapon and VeafMG_Guardian OOP.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafMissileGuardian.lua")

-- ---------------------------------------------------------------------------
-- TestVeafMGConstants
-- ---------------------------------------------------------------------------
TestVeafMGConstants = {}

function TestVeafMGConstants:test_id()
  luaunit.assertEquals(veafMissileGuardian.Id, "MISSILEGUARDIAN")
end

function TestVeafMGConstants:test_version()
  luaunit.assertIsString(veafMissileGuardian.Version)
end

-- ---------------------------------------------------------------------------
-- TestVeafMGWeapon
-- ---------------------------------------------------------------------------
TestVeafMGWeapon = {}

function TestVeafMGWeapon:test_new_returns_table()
  local w = VeafMG_Weapon:new()
  luaunit.assertIsTable(w)
end

function TestVeafMGWeapon:test_new_name_nil()
  local w = VeafMG_Weapon:new()
  luaunit.assertNil(w.name)
end

function TestVeafMGWeapon:test_new_dcsWeapon_nil()
  local w = VeafMG_Weapon:new()
  luaunit.assertNil(w.dcsWeapon)
end

function TestVeafMGWeapon:test_setName_getName()
  local w = VeafMG_Weapon:new()
  w:setName("AIM-120C")
  luaunit.assertEquals(w:getName(), "AIM-120C")
end

function TestVeafMGWeapon:test_setDcsWeapon_getDcsWeapon()
  local w = VeafMG_Weapon:new()
  -- dcsWeapon needs getLauncher() so veafMissileGuardian.getUnitName can work
  local fakeUnit = { getName = function() return "F-16" end }
  local fake = {
    getLauncher = function() return fakeUnit end,
    category = 1,
  }
  w:setDcsWeapon(fake)
  luaunit.assertEquals(w:getDcsWeapon(), fake)
end

function TestVeafMGWeapon:test_copy_preserves_name()
  local w = VeafMG_Weapon:new()
  w:setName("R-73")
  local c = w:copy()
  luaunit.assertEquals(c:getName(), "R-73")
end

function TestVeafMGWeapon:test_copy_is_new_instance()
  local w = VeafMG_Weapon:new()
  w:setName("Kh-31")
  local c = w:copy()
  c:setName("Kh-58")
  luaunit.assertEquals(w:getName(), "Kh-31")
  luaunit.assertEquals(c:getName(), "Kh-58")
end

-- ---------------------------------------------------------------------------
-- TestVeafMGGuardian
-- ---------------------------------------------------------------------------
TestVeafMGGuardian = {}

function TestVeafMGGuardian:test_new_returns_table()
  local g = VeafMG_Guardian:new()
  luaunit.assertIsTable(g)
end

function TestVeafMGGuardian:test_new_name_nil()
  local g = VeafMG_Guardian:new()
  luaunit.assertNil(g.name)
end

function TestVeafMGGuardian:test_new_protectedUnits_empty()
  local g = VeafMG_Guardian:new()
  luaunit.assertIsTable(g.protectedUnits)
end

function TestVeafMGGuardian:test_new_protectedZone_empty()
  local g = VeafMG_Guardian:new()
  luaunit.assertIsTable(g.protectedZone)
end

function TestVeafMGGuardian:test_name_field_set_directly()
  local g = VeafMG_Guardian:new()
  g.name = "BluePatriot"
  luaunit.assertEquals(g.name, "BluePatriot")
end

function TestVeafMGGuardian:test_copy_preserves_name()
  local g = VeafMG_Guardian:new()
  g.name = "EagleShield"
  local c = g:copy()
  luaunit.assertEquals(c.name, "EagleShield")
end

function TestVeafMGGuardian:test_copy_is_new_instance()
  local g = VeafMG_Guardian:new()
  g.name = "Alpha"
  local c = g:copy()
  c.name = "Beta"
  luaunit.assertEquals(g.name, "Alpha")
  luaunit.assertEquals(c.name, "Beta")
end

-- ============================================================================
-- TestVeafMGWeaponExtra
-- ============================================================================
TestVeafMGWeaponExtra = {}

function TestVeafMGWeaponExtra:test_setDcsWeapon_populates_shooter()
  local fakeLauncher = { getName = function() return "F-16C-1" end }
  local fakeWeapon = { getLauncher = function() return fakeLauncher end }
  local w = VeafMG_Weapon:new()
  w:setDcsWeapon(fakeWeapon)
  luaunit.assertEquals(w:getShooter(), fakeLauncher)
  luaunit.assertEquals(w:getShooterName(), "F-16C-1")
end

function TestVeafMGWeaponExtra:test_getCurrentPosition_nil_dcsWeapon()
  local w = VeafMG_Weapon:new()
  luaunit.assertNil(w:getCurrentPosition())
end

function TestVeafMGWeaponExtra:test_getCurrentTarget_nil_dcsWeapon()
  local w = VeafMG_Weapon:new()
  luaunit.assertNil(w:getCurrentTarget())
end

function TestVeafMGWeaponExtra:test_getCurrentEnergy_nil_dcsWeapon()
  local w = VeafMG_Weapon:new()
  luaunit.assertNil(w:getCurrentEnergy())
end

-- ============================================================================
-- TestVeafMGGuardianSetters
-- ============================================================================
TestVeafMGGuardianSetters = {}

function TestVeafMGGuardianSetters:test_setName_getName()
  local g = VeafMG_Guardian:new()
  g:setName("TestGuardian")
  luaunit.assertEquals(g:getName(), "TestGuardian")
end

function TestVeafMGGuardianSetters:test_setFriendlyName_getFriendlyName()
  local g = VeafMG_Guardian:new()
  g:setFriendlyName("Friendly Name")
  luaunit.assertEquals(g:getFriendlyName(), "Friendly Name")
end

function TestVeafMGGuardianSetters:test_addProtectedUnit_string()
  local g = VeafMG_Guardian:new()
  g:addProtectedUnit("F-16C-1")
  luaunit.assertEquals(g.protectedUnits["F-16C-1"], "protected")
end

function TestVeafMGGuardianSetters:test_setProtectedZone()
  local g = VeafMG_Guardian:new()
  local zone = { x = 0, y = 0, z = 0 }
  g:setProtectedZone(zone)
  luaunit.assertEquals(g.protectedZone, zone)
end

function TestVeafMGGuardianSetters:test_start_stop()
  -- world.addEventHandler / removeEventHandler are mocked as no-ops
  local g = VeafMG_Guardian:new()
  g:start()
  g:stop()
  luaunit.assertTrue(true)
end

-- ============================================================================
-- TestVeafMGProtector
-- ============================================================================
TestVeafMGProtector = {}

function TestVeafMGProtector:test_new_creates_instance()
  local p = VeafMG_Protector:new()
  luaunit.assertNotNil(p)
  luaunit.assertNil(p.name)
end

function TestVeafMGProtector:test_setName_getName()
  local p = VeafMG_Protector:new()
  p:setName("Protector1")
  luaunit.assertEquals(p:getName(), "Protector1")
end

function TestVeafMGProtector:test_setSecondsBetweenWatchdogChecks()
  local p = VeafMG_Protector:new()
  p:setSecondsBetweenWatchdogChecks(5.0)
  luaunit.assertEquals(p:getSecondsBetweenWatchdogChecks(), 5.0)
end

function TestVeafMGProtector:test_setWeapon()
  local p = VeafMG_Protector:new()
  local w = VeafMG_Weapon:new()
  p:setWeapon(w)
  luaunit.assertEquals(p.weapon, w)
end

function TestVeafMGProtector:test_copy_preserves_name()
  local p = VeafMG_Protector:new()
  p:setName("OriginalProtector")
  p:setSecondsBetweenWatchdogChecks(3.0)
  local c = p:copy()
  luaunit.assertEquals(c.name, "OriginalProtector")
  luaunit.assertEquals(c.secondsBetweenWatchdogChecks, 3.0)
end

function TestVeafMGProtector:test_start_stop_no_crash()
  -- start() and stop() have empty bodies
  local p = VeafMG_Protector:new()
  p:start()
  p:stop()
  luaunit.assertTrue(true)
end

os.exit(luaunit.LuaUnit.run())
