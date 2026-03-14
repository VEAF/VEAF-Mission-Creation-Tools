--- Tests for veafCombatZone.lua — VeafCombatZoneElement and VeafCombatZone OOP objects.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafCombatZone.lua")

-- ---------------------------------------------------------------------------
-- TestCombatZoneModuleConstants
-- ---------------------------------------------------------------------------
TestCombatZoneModuleConstants = {}

function TestCombatZoneModuleConstants:test_id()
  luaunit.assertEquals(veafCombatZone.Id, "COMBATZONE")
end

function TestCombatZoneModuleConstants:test_version_string()
  luaunit.assertIsString(veafCombatZone.Version)
  luaunit.assertTrue(veafCombatZone.Version:find("^%d+%.%d+") ~= nil)
end

function TestCombatZoneModuleConstants:test_radioMenuName()
  luaunit.assertEquals(veafCombatZone.RadioMenuName, "COMBAT ZONES")
end

function TestCombatZoneModuleConstants:test_defaultSpawnRadii()
  luaunit.assertEquals(veafCombatZone.DefaultSpawnRadiusForUnits, 50)
  luaunit.assertEquals(veafCombatZone.DefaultSpawnRadiusForStatics, 0)
end

function TestCombatZoneModuleConstants:test_watchdog_delay()
  luaunit.assertEquals(veafCombatZone.SecondsBetweenWatchdogChecks, 60)
end

function TestCombatZoneModuleConstants:test_eventMessages_table()
  luaunit.assertNotNil(veafCombatZone.EventMessages)
  luaunit.assertIsString(veafCombatZone.EventMessages.CombatZoneComplete)
  luaunit.assertIsString(veafCombatZone.EventMessages.PopSmokeRequest)
end

-- ---------------------------------------------------------------------------
-- TestVeafCombatZoneElement
-- ---------------------------------------------------------------------------
TestVeafCombatZoneElement = {}

function TestVeafCombatZoneElement:setUp()
  self.el = VeafCombatZoneElement:new()
end

function TestVeafCombatZoneElement:test_initialName()
  luaunit.assertNil(self.el:getName())
end

function TestVeafCombatZoneElement:test_setGetName()
  self.el:setName("MyElement")
  luaunit.assertEquals(self.el:getName(), "MyElement")
end

function TestVeafCombatZoneElement:test_setGetPosition()
  local pos = { x = 100, y = 50, z = 200 }
  self.el:setPosition(pos)
  luaunit.assertIs(self.el:getPosition(), pos)
end

function TestVeafCombatZoneElement:test_setGetDcsStatic()
  luaunit.assertFalse(self.el:isDcsStatic())
  self.el:setDcsStatic(true)
  luaunit.assertTrue(self.el:isDcsStatic())
  self.el:setDcsStatic(false)
  luaunit.assertFalse(self.el:isDcsStatic())
end

function TestVeafCombatZoneElement:test_setGetDcsGroup()
  luaunit.assertFalse(self.el:isDcsGroup())
  self.el:setDcsGroup(true)
  luaunit.assertTrue(self.el:isDcsGroup())
end

function TestVeafCombatZoneElement:test_setGetVeafCommand()
  luaunit.assertNil(self.el:getVeafCommand())
  self.el:setVeafCommand("_cas size 3")
  luaunit.assertEquals(self.el:getVeafCommand(), "_cas size 3")
end

function TestVeafCombatZoneElement:test_setGetRoute()
  local route = { wp1 = { x = 0, z = 0 } }
  self.el:setRoute(route)
  luaunit.assertIs(self.el:getRoute(), route)
end

function TestVeafCombatZoneElement:test_setGetCoalition()
  luaunit.assertNil(self.el:getCoalition())
  self.el:setCoalition(1)
  luaunit.assertEquals(self.el:getCoalition(), 1)
end

function TestVeafCombatZoneElement:test_setGetSpawnRadius()
  self.el:setSpawnRadius(150)
  luaunit.assertEquals(self.el:getSpawnRadius(), 150)
end

function TestVeafCombatZoneElement:test_spawnRadius_string_coercion()
  self.el:setSpawnRadius("200")
  luaunit.assertEquals(self.el:getSpawnRadius(), 200)
end

function TestVeafCombatZoneElement:test_setGetSpawnChance()
  self.el:setSpawnChance(75)
  luaunit.assertEquals(self.el:getSpawnChance(), 75)
end

function TestVeafCombatZoneElement:test_spawnChance_default()
  luaunit.assertEquals(self.el.spawnChance, 100)
end

function TestVeafCombatZoneElement:test_setGetSpawnGroup()
  self.el:setSpawnGroup("grp1")
  luaunit.assertEquals(self.el:getSpawnGroup(), "grp1")
end

function TestVeafCombatZoneElement:test_setGetSpawnCount()
  self.el:setSpawnCount(3)
  luaunit.assertEquals(self.el:getSpawnCount(), 3)
end

function TestVeafCombatZoneElement:test_spawnCount_default()
  luaunit.assertEquals(self.el.spawnCount, 1)
end

function TestVeafCombatZoneElement:test_setGetSpawnDelay()
  self.el:setSpawnDelay(30)
  luaunit.assertEquals(self.el:getSpawnDelay(), 30)
end

function TestVeafCombatZoneElement:test_spawnDelay_string_coercion()
  self.el:setSpawnDelay("60")
  luaunit.assertEquals(self.el:getSpawnDelay(), 60)
end

function TestVeafCombatZoneElement:test_chaining_setters()
  local result = self.el
    :setName("chain")
    :setDcsStatic(true)
    :setSpawnRadius(100)
    :setSpawnChance(50)
  -- chaining returns self (or same instance)
  luaunit.assertEquals(self.el:getName(), "chain")
  luaunit.assertTrue(self.el:isDcsStatic())
  luaunit.assertEquals(self.el:getSpawnRadius(), 100)
  luaunit.assertEquals(self.el:getSpawnChance(), 50)
end

function TestVeafCombatZoneElement:test_new_with_copy()
  local src = { name = "copied", spawnChance = 42 }
  local el = VeafCombatZoneElement:new(src)
  -- after new(), name is reset to nil (init overrides), spawnChance too
  luaunit.assertEquals(el.spawnChance, 100) -- init resets to 100
end

-- ---------------------------------------------------------------------------
-- TestVeafCombatZone
-- ---------------------------------------------------------------------------
TestVeafCombatZone = {}

function TestVeafCombatZone:setUp()
  self.z = VeafCombatZone:new()
end

function TestVeafCombatZone:test_initialFriendlyName()
  luaunit.assertNil(self.z:getFriendlyName())
end

function TestVeafCombatZone:test_setGetFriendlyName()
  self.z:setFriendlyName("Alpha Zone")
  luaunit.assertEquals(self.z:getFriendlyName(), "Alpha Zone")
end

function TestVeafCombatZone:test_setGetMissionEditorZoneName()
  luaunit.assertNil(self.z:getMissionEditorZoneName())
  self.z:setMissionEditorZoneName("ZONE_A")
  luaunit.assertEquals(self.z:getMissionEditorZoneName(), "ZONE_A")
end

function TestVeafCombatZone:test_setGetBriefing()
  luaunit.assertNil(self.z:getBriefing())
  self.z:setBriefing("Destroy all red units in the zone.")
  luaunit.assertEquals(self.z:getBriefing(), "Destroy all red units in the zone.")
end

function TestVeafCombatZone:test_setGetActive()
  luaunit.assertFalse(self.z:isActive())
  self.z:setActive(true)
  luaunit.assertTrue(self.z:isActive())
  self.z:setActive(false)
  luaunit.assertFalse(self.z:isActive())
end

function TestVeafCombatZone:test_setGetTraining()
  luaunit.assertFalse(self.z:isTraining())
  self.z:setTraining(true)
  luaunit.assertTrue(self.z:isTraining())
  -- training=true forces showUnitsList and showZonePositionInfo to true
  luaunit.assertTrue(self.z:isShowUnitsList())
  luaunit.assertTrue(self.z:isShowZonePositionInfo())
end

function TestVeafCombatZone:test_setGetShowUnitsList()
  self.z:setShowUnitsList(false)
  luaunit.assertFalse(self.z:isShowUnitsList())
  self.z:setShowUnitsList(true)
  luaunit.assertTrue(self.z:isShowUnitsList())
end

function TestVeafCombatZone:test_setGetShowZonePositionInfo()
  self.z:setShowZonePositionInfo(false)
  luaunit.assertFalse(self.z:isShowZonePositionInfo())
end

function TestVeafCombatZone:test_setGetCompletable()
  luaunit.assertTrue(self.z:isCompletable())
  self.z:setCompletable(false)
  luaunit.assertFalse(self.z:isCompletable())
end

function TestVeafCombatZone:test_setGetRadioMenuPrefix()
  luaunit.assertNil(self.z:getRadioMenuPrefix())
  self.z:setRadioMenuPrefix("BLUE")
  luaunit.assertEquals(self.z:getRadioMenuPrefix(), "BLUE")
end

function TestVeafCombatZone:test_setGetRadioGroupName()
  luaunit.assertNil(self.z:getRadioGroupName())
  self.z:setRadioGroupName("GroupA")
  luaunit.assertEquals(self.z:getRadioGroupName(), "GroupA")
end

function TestVeafCombatZone:test_setGetRadioParentPath()
  luaunit.assertNil(self.z:getRadioParentPath())
  self.z:setRadioParentPath("path/to/menu")
  luaunit.assertEquals(self.z:getRadioParentPath(), "path/to/menu")
end

function TestVeafCombatZone:test_getRadioMenuName_no_prefix_inactive()
  self.z:setFriendlyName("BravoZone")
  local name = self.z:getRadioMenuName(false)
  luaunit.assertEquals(name, "BravoZone")
end

function TestVeafCombatZone:test_getRadioMenuName_no_prefix_active()
  self.z:setFriendlyName("BravoZone")
  local name = self.z:getRadioMenuName(true)
  luaunit.assertEquals(name, "* BravoZone")
end

function TestVeafCombatZone:test_getRadioMenuName_with_prefix_inactive()
  self.z:setFriendlyName("AlphaZone")
  self.z:setRadioMenuPrefix("RED")
  local name = self.z:getRadioMenuName(false)
  luaunit.assertEquals(name, "RED AlphaZone")
end

function TestVeafCombatZone:test_getRadioMenuName_with_prefix_active()
  self.z:setFriendlyName("AlphaZone")
  self.z:setRadioMenuPrefix("RED")
  local name = self.z:getRadioMenuName(true)
  luaunit.assertEquals(name, "RED * AlphaZone")
end

function TestVeafCombatZone:test_disableRadioMenu()
  luaunit.assertTrue(self.z.enableRadioMenu)
  self.z:disableRadioMenu()
  luaunit.assertFalse(self.z.enableRadioMenu)
end

function TestVeafCombatZone:test_disableJunkCleanup()
  luaunit.assertTrue(self.z.enableJunkCleanup)
  self.z:disableJunkCleanup()
  luaunit.assertFalse(self.z.enableJunkCleanup)
end

function TestVeafCombatZone:test_enableUserActivation_toggle()
  -- default is true
  luaunit.assertTrue(self.z.enableUserActivation)
  self.z:disableUserActivation()
  luaunit.assertFalse(self.z.enableUserActivation)
  self.z:setEnableUserActivation(true)
  luaunit.assertTrue(self.z.enableUserActivation)
end

function TestVeafCombatZone:test_setEnableSmokeAndFlare()
  luaunit.assertTrue(self.z.enableSmokeAndFlare)  -- default
  self.z:setEnableSmokeAndFlare(false)
  luaunit.assertFalse(self.z.enableSmokeAndFlare)
end

function TestVeafCombatZone:test_spawnedGroups_management()
  luaunit.assertEquals(#self.z:getSpawnedGroups(), 0)
  self.z:addSpawnedGroup("group1")
  self.z:addSpawnedGroup("group2")
  luaunit.assertEquals(#self.z:getSpawnedGroups(), 2)
  self.z:clearSpawnedGroups()
  luaunit.assertEquals(#self.z:getSpawnedGroups(), 0)
end

function TestVeafCombatZone:test_spawnedGroups_numeric_coercion()
  -- addSpawnedGroup coerces non-strings via tostring
  self.z:addSpawnedGroup(42)
  luaunit.assertEquals(#self.z:getSpawnedGroups(), 1)
end

function TestVeafCombatZone:test_onCompletedHook_setter()
  local called = false
  local hook = function() called = true end
  self.z:setOnCompletedHook(hook)
  self.z.onCompletedHook()
  luaunit.assertTrue(called)
end

function TestVeafCombatZone:test_setGetChainedCombatZones()
  self.z.chainedCombatZones = { "Zone2", "Zone3" }
  luaunit.assertEquals(#self.z.chainedCombatZones, 2)
end

function TestVeafCombatZone:test_new_independent_instances()
  local z1 = VeafCombatZone:new()
  local z2 = VeafCombatZone:new()
  z1:setFriendlyName("Z1")
  z2:setFriendlyName("Z2")
  luaunit.assertEquals(z1:getFriendlyName(), "Z1")
  luaunit.assertEquals(z2:getFriendlyName(), "Z2")
end

function TestVeafCombatZone:test_spawnedGroups_independent_per_instance()
  local z1 = VeafCombatZone:new()
  local z2 = VeafCombatZone:new()
  z1:addSpawnedGroup("g1")
  luaunit.assertEquals(#z1:getSpawnedGroups(), 1)
  luaunit.assertEquals(#z2:getSpawnedGroups(), 0)
end

os.exit(luaunit.LuaUnit.run())
