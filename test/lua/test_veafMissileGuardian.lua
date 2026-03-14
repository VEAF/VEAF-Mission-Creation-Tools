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

os.exit(luaunit.LuaUnit.run())
