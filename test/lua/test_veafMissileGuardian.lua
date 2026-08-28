--- Tests for veafMissileGuardian.lua — VeafMG_Weapon and VeafMG_Guardian OOP.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafRadio.lua")
dofile(src .. "/veafMissileGuardian.lua")

-- ---------------------------------------------------------------------------
-- TestVeafMGConstants
-- ---------------------------------------------------------------------------
TestVeafMGConstants = {}

function TestVeafMGConstants:test_id()
  luaunit.assertEquals(veafMissileGuardian.Id, "MISSILEGUARDIAN")
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
  local fakeUnit = {
    getName = function()
      return "F-16"
    end,
  }
  local fake = {
    getLauncher = function()
      return fakeUnit
    end,
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
  local fakeLauncher = {
    getName = function()
      return "F-16C-1"
    end,
  }
  local fakeWeapon = {
    getLauncher = function()
      return fakeLauncher
    end,
  }
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

-- ============================================================================
-- TestVeafMGInitialize
-- ============================================================================
TestVeafMGInitialize = {}

function TestVeafMGInitialize:setUp()
  -- Start each case from a clean radio state so buildRadioMenu takes the
  -- "create" branch (rootPath == nil) deterministically.
  veafMissileGuardian.rootPath = nil
end

-- Regression guard: initialize() used to call the non-existent
-- veafMissileGuardian.dumpMissionsList, which raised a runtime error and
-- aborted the whole veaf-config.lua chunk (breaking marker dispatch, CTLD, …).
function TestVeafMGInitialize:test_initialize_no_crash()
  local ok, err = pcall(veafMissileGuardian.initialize)
  luaunit.assertTrue(ok, tostring(err))
end

-- Beyond "does not raise": assert the intended side effect actually happened —
-- initialize() builds the module's radio menu, so rootPath must be populated.
-- This catches a future silent regression that returns without wiring the menu.
function TestVeafMGInitialize:test_initialize_creates_radio_menu()
  veafMissileGuardian.initialize()
  luaunit.assertNotNil(veafMissileGuardian.rootPath)
end

-- initialize() must be safe to call twice: the second call takes the
-- clearSubmenu branch (rootPath already set) instead of re-creating the menu.
function TestVeafMGInitialize:test_initialize_idempotent()
  veafMissileGuardian.initialize()
  local firstRootPath = veafMissileGuardian.rootPath
  local ok, err = pcall(veafMissileGuardian.initialize)
  luaunit.assertTrue(ok, tostring(err))
  luaunit.assertEquals(veafMissileGuardian.rootPath, firstRootPath)
end

-------------------------------------------------------------------------------------------------
-- SECREV-2 / VMR-091 — VeafMG_Guardian:copy lost every protected unit
--
--     copy.protectedUnits = {}
--     for unitName, value in pairs(self.protectedUnits) do
--       copy.protectedZone[unitName] = value    -- wrong target
--     end
--     copy.protectedZone = {}                   -- and this wipes what was just written
--
-- Net effect: the copy comes back with an empty protectedUnits. protectedZone survives only
-- because the second block reinitialises it, which is what hid the defect.
-------------------------------------------------------------------------------------------------

TestVeafMissileGuardianCopy = {}

function TestVeafMissileGuardianCopy:_guardian()
  local g = VeafMG_Guardian:new()
  g.name = "test"
  g.friendlyName = "Test guardian"
  g.protectedUnits = { ["unit-a"] = true, ["unit-b"] = true }
  g.protectedZone = { "zone-1", "zone-2" }
  return g
end

function TestVeafMissileGuardianCopy:test_protected_units_survive_the_copy()
  local copy = self:_guardian():copy()
  luaunit.assertEquals(copy.protectedUnits["unit-a"], true)
  luaunit.assertEquals(copy.protectedUnits["unit-b"], true)
end

function TestVeafMissileGuardianCopy:test_protected_zones_survive_the_copy()
  local copy = self:_guardian():copy()
  luaunit.assertEquals(#copy.protectedZone, 2)
end

function TestVeafMissileGuardianCopy:test_protected_zone_holds_zones_not_units()
  -- The corruption: unit keys used to land in protectedZone before being wiped.
  local copy = self:_guardian():copy()
  luaunit.assertNil(copy.protectedZone["unit-a"])
end

function TestVeafMissileGuardianCopy:test_the_copy_is_independent()
  local original = self:_guardian()
  local copy = original:copy()
  copy.protectedUnits["unit-c"] = true
  luaunit.assertNil(original.protectedUnits["unit-c"])
end

function TestVeafMissileGuardianCopy:test_scalar_attributes_are_copied()
  local copy = self:_guardian():copy()
  luaunit.assertEquals(copy.name, "test")
  luaunit.assertEquals(copy.friendlyName, "Test guardian")
end

-- ===========================================================================
-- FIX-MISSILEGUARDIAN-NO-STORAGE — the public verbs
--
-- The existing tests above cover the classes' getters, setters and copy constructors, and nothing else:
-- not one of them went through a public verb, which is exactly where the module raised. `ActivateGuardian`
-- and `DesactivateGuardian` both opened on `veafMissileGuardian.GetGuardian(name)`, a function that was
-- never written, and the class has no `activate`, `desactivate` or `isSilent` either — so storage alone
-- would not have made them work.
--
-- The module stays a declared skeleton. What these tests pin is that it **refuses out loud** rather than
-- raising, because a skeleton that raises on its first line of work is indistinguishable from a broken
-- feature when it turns up in a DCS log.
-- ===========================================================================
TestVeafMGPublicVerbs = {}

function TestVeafMGPublicVerbs:setUp()
  self._savedGet = veaf.loggers.get
  self.logged = {}
  local logger = {}
  for _, level in ipairs({ "error", "warn", "info", "debug", "trace" }) do
    logger[level] = function(_, message, ...)
      table.insert(self.logged, { level = level, message = message })
    end
  end
  veaf.loggers.get = function(id)
    if id == veafMissileGuardian.Id then
      return logger
    end
    return self._savedGet(id)
  end
end

function TestVeafMGPublicVerbs:tearDown()
  veaf.loggers.get = self._savedGet
end

function TestVeafMGPublicVerbs:_warnings()
  local found = {}
  for _, entry in ipairs(self.logged) do
    if entry.level == "warn" then
      table.insert(found, entry.message)
    end
  end
  return found
end

function TestVeafMGPublicVerbs:test_activate_does_not_raise()
  -- The defect as the sweep found it: a call reaching a function nothing defines.
  local ok, err = pcall(veafMissileGuardian.ActivateGuardian, "anything", false)
  luaunit.assertTrue(ok, "ActivateGuardian must not raise: " .. tostring(err))
end

function TestVeafMGPublicVerbs:test_activate_refuses_rather_than_pretending()
  -- `false`, not nil: a caller reading the result gets a decision. And it must be in the log, since a
  -- mission that called this asked for protection it is not getting.
  luaunit.assertFalse(veafMissileGuardian.ActivateGuardian("anything", false))
  luaunit.assertEquals(#self:_warnings(), 1)
  luaunit.assertStrContains(self:_warnings()[1], "ActivateGuardian")
end

function TestVeafMGPublicVerbs:test_desactivate_does_not_raise()
  local ok, err = pcall(veafMissileGuardian.DesactivateGuardian, "anything", false)
  luaunit.assertTrue(ok, "DesactivateGuardian must not raise: " .. tostring(err))
  luaunit.assertEquals(#self:_warnings(), 1)
end

function TestVeafMGPublicVerbs:test_add_refuses_instead_of_returning_its_argument()
  -- It used to hand the guardian straight back, which reads as "registered" at every call site.
  local guardian = VeafMG_Guardian:new()
  luaunit.assertFalse(veafMissileGuardian.AddGuardian(guardian))
  luaunit.assertEquals(#self:_warnings(), 1)
end

function TestVeafMGPublicVerbs:test_listing_says_so_instead_of_printing_an_empty_list()
  -- It sorted an empty local and printed "List of all available guardians:" with nothing under it,
  -- which reads as "this mission defines none" rather than "this module cannot define any".
  luaunit.assertFalse(veafMissileGuardian.listGuardians())
  luaunit.assertEquals(#self:_warnings(), 1)
end

function TestVeafMGPublicVerbs:test_listActiveMissions_is_gone()
  -- It iterated `veafMissileGuardian.missionsDict`, a table this module never had — copied from
  -- veafCombatMission, where "missions" is a real concept. Its only possible outcome was an error.
  luaunit.assertNil(veafMissileGuardian.listActiveMissions)
end

function TestVeafMGPublicVerbs:test_the_verbs_are_still_there_to_be_called()
  -- Refusing is not the same as deleting: the module is offered as MISSILEGUARDIAN and a mission may
  -- call these. Removing them would turn a warning into a nil-call crash at the caller.
  luaunit.assertIsFunction(veafMissileGuardian.AddGuardian)
  luaunit.assertIsFunction(veafMissileGuardian.ActivateGuardian)
  luaunit.assertIsFunction(veafMissileGuardian.DesactivateGuardian)
end

-- ---------------------------------------------------------------------------
-- The weapon path — the line that would fail first if anyone wired this up
-- ---------------------------------------------------------------------------
TestVeafMGWeaponPath = {}

function TestVeafMGWeaponPath:setUp()
  self._savedGet = veaf.loggers.get
  self._savedMist = mist
  self.logged = {}
  local logger = {}
  for _, level in ipairs({ "error", "warn", "info", "debug", "trace" }) do
    logger[level] = function(_, message, ...)
      table.insert(self.logged, { level = level, message = message })
    end
  end
  veaf.loggers.get = function(id)
    if id == veafMissileGuardian.Id then
      return logger
    end
    return self._savedGet(id)
  end
  -- `mist.pointInPolygon` is not in the mocks; the guardian asks it whether the target is inside the
  -- protected zone, and the interesting branch is the one where it says yes.
  mist = mist or {}
  mist.pointInPolygon = function()
    return true
  end
end

function TestVeafMGWeaponPath:tearDown()
  veaf.loggers.get = self._savedGet
  mist = self._savedMist
end

--- A shot at `unitName`, shaped as `VeafMG_Guardian:onEvent` reads it.
function TestVeafMGWeaponPath:_shotAt(unitName)
  local target = {
    getName = function()
      return unitName
    end,
    getPoint = function()
      return { x = 0, y = 0, z = 0 }
    end,
    getGroup = function()
      return {
        getID = function()
          return 1
        end,
      }
    end,
    getPlayerName = function()
      return nil -- no player, so the warning message branch is skipped
    end,
  }
  return {
    id = world.event.S_EVENT_SHOT,
    weapon = {
      getTarget = function()
        return target
      end,
      getLauncher = function()
        return nil
      end,
    },
  }
end

function TestVeafMGWeaponPath:test_a_shot_at_a_protected_unit_does_not_raise()
  -- This is where `getLargeScaleProtector():setWeapon(...)` sat, on a stub returning nil. Unreachable
  -- today, since nothing constructs a guardian and so nothing registers the handler — but a raise inside
  -- a `world` event handler is the worst possible place to discover that, and this is the first line
  -- anyone wiring the module up would hit.
  local guardian = VeafMG_Guardian:new():setName("g"):addProtectedUnit("Chevy11")
  local ok, err = pcall(function()
    guardian:onEvent(self:_shotAt("Chevy11"))
  end)
  luaunit.assertTrue(ok, "onEvent must not raise on the missing protector: " .. tostring(err))
end

function TestVeafMGWeaponPath:test_and_it_says_why_nothing_happened()
  local guardian = VeafMG_Guardian:new():setName("g"):addProtectedUnit("Chevy11")
  pcall(function()
    guardian:onEvent(self:_shotAt("Chevy11"))
  end)
  local warned = false
  for _, entry in ipairs(self.logged) do
    if entry.level == "warn" then
      warned = true
    end
  end
  luaunit.assertTrue(warned, "a detected weapon that nothing follows must be reported")
end

function TestVeafMGWeaponPath:test_an_unprotected_unit_is_ignored_quietly()
  -- The guard must not turn every shot in the mission into a warning.
  local guardian = VeafMG_Guardian:new():setName("g"):addProtectedUnit("Chevy11")
  pcall(function()
    guardian:onEvent(self:_shotAt("SomebodyElse"))
  end)
  for _, entry in ipairs(self.logged) do
    luaunit.assertNotEquals(entry.level, "warn", "a shot at an unprotected unit must stay silent")
  end
end

-- ---------------------------------------------------------------------------
-- A weapon whose launcher is already gone
--
-- `getLauncher()` answers nil once the shooter no longer exists, which for a shot event processed a
-- moment later is ordinary. `setDcsWeapon` passed that nil straight to `veafMissileGuardian.getUnitName`,
-- which indexed it. The existing `test_setDcsWeapon_getDcsWeapon` above never saw this because its mock
-- always supplies a launcher — a happy-path mock hiding the branch that actually happens in flight.
-- ---------------------------------------------------------------------------
TestVeafMGWeaponWithoutLauncher = {}

function TestVeafMGWeaponWithoutLauncher:_weaponWithNoLauncher()
  return {
    getLauncher = function()
      return nil
    end,
  }
end

function TestVeafMGWeaponWithoutLauncher:test_it_does_not_raise()
  local weapon = VeafMG_Weapon:new()
  local ok, err = pcall(function()
    weapon:setDcsWeapon(self:_weaponWithNoLauncher())
  end)
  luaunit.assertTrue(ok, "a launcher-less weapon must not raise: " .. tostring(err))
end

function TestVeafMGWeaponWithoutLauncher:test_the_shooter_name_is_simply_absent()
  -- nil rather than an invented placeholder: the warning message built from it reads better empty than
  -- with a made-up name in it.
  local weapon = VeafMG_Weapon:new():setDcsWeapon(self:_weaponWithNoLauncher())
  luaunit.assertNil(weapon:getShooterName())
end

function TestVeafMGWeaponWithoutLauncher:test_a_launcher_still_gives_its_name()
  -- The guard must not swallow the normal case.
  local weapon = VeafMG_Weapon:new():setDcsWeapon({
    getLauncher = function()
      return {
        getName = function()
          return "Chevy11"
        end,
      }
    end,
  })
  luaunit.assertEquals(weapon:getShooterName(), "Chevy11")
end

os.exit(luaunit.LuaUnit.run())
