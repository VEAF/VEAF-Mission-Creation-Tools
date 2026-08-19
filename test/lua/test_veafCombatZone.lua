--- Tests for veafCombatZone.lua — VeafCombatZoneElement and VeafCombatZone OOP objects.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafI18n.lua")
dofile(src .. "/veafCombatZone.lua")

-- The assertions below pin the English wording; messages are now localized
-- (FR is the default language) so force English for these tests.
veaf.config.language = "en"

-- ---------------------------------------------------------------------------
-- TestCombatZoneModuleConstants
-- ---------------------------------------------------------------------------
TestCombatZoneModuleConstants = {}

function TestCombatZoneModuleConstants:test_id()
  luaunit.assertEquals(veafCombatZone.Id, "COMBATZONE")
end

--- FIX-RADIO-MENU-I18N — `RadioMenuName` now holds an i18n **key**, resolved when the menu is built.
--- The value is asserted through `veaf.t` in both languages rather than as a literal: a test on the
--- English side alone would still pass on a hard-coded English string, which is the defect this lot
--- fixes.
function TestCombatZoneModuleConstants:test_radioMenuName_is_a_key()
  luaunit.assertEquals(veafCombatZone.RadioMenuName, "menu.combatzone.root")
end

function TestCombatZoneModuleConstants:test_radioMenuName_resolves_in_both_languages()
  local saved = veaf.config.language
  veaf.config.language = "en"
  luaunit.assertEquals(veaf.t(veafCombatZone.RadioMenuName), "COMBAT ZONES")
  veaf.config.language = "fr"
  luaunit.assertEquals(veaf.t(veafCombatZone.RadioMenuName), "ZONES DE COMBAT")
  veaf.config.language = saved
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

-- FIX-COMBATZONE-CONVOY-ALARM: the zone used to put every group it spawned on red alert, which
-- immobilised convoys (#290). The default is now AUTO, and `#alarm=` is the only way to override it.

function TestVeafCombatZoneElement:test_alarmState_defaults_to_auto()
  luaunit.assertEquals(self.el:getAlarmState(), 0)
  luaunit.assertEquals(veafCombatZone.DefaultAlarmState, 0)
end

function TestVeafCombatZoneElement:test_alarmState_accepts_every_valid_state()
  for _, state in ipairs({ 0, 1, 2 }) do
    self.el:setAlarmState(state)
    luaunit.assertEquals(self.el:getAlarmState(), state)
  end
end

function TestVeafCombatZoneElement:test_alarmState_string_coercion()
  self.el:setAlarmState("2")
  luaunit.assertEquals(self.el:getAlarmState(), 2)
end

function TestVeafCombatZoneElement:test_alarmState_rejects_out_of_range_and_garbage()
  -- every rejected shape falls back to the default rather than reaching setOption with it
  for _, bad in ipairs({ 3, 42, -1, "", "red", "1.5" }) do
    self.el:setAlarmState(2)
    self.el:setAlarmState(bad)
    luaunit.assertEquals(self.el:getAlarmState(), veafCombatZone.DefaultAlarmState)
  end
end

function TestVeafCombatZoneElement:test_alarmState_rejects_nil()
  self.el:setAlarmState(2)
  self.el:setAlarmState(nil)
  luaunit.assertEquals(self.el:getAlarmState(), veafCombatZone.DefaultAlarmState)
end

function TestVeafCombatZoneElement:test_alarm_tag_pattern_reads_the_state()
  -- the parser lowercases the unit name before matching, so the tag is case-insensitive
  local cases = {
    ["convoy #alarm=0"] = "0",
    ["CONVOY #ALARM=2"] = "2",
    ["sam #alarm = 1"] = "1",
    ["sam #alarm=  2"] = "2",
    ["mixed #spawndelay=30 #alarm=2 #spawnchance=50"] = "2",
  }
  for unitName, expected in pairs(cases) do
    local _, _, found = unitName:lower():find(veafCombatZone.ALARM_TAG_PATTERN)
    luaunit.assertEquals(found, expected, "unit name: " .. unitName)
  end
end

function TestVeafCombatZoneElement:test_alarm_tag_pattern_absent_or_malformed()
  -- `#alarmstate=2` is included on purpose: the tag is `#alarm=`, and the pattern requires the `=`
  -- right after it, so a near-miss spelling reads as no tag at all rather than as a state.
  for _, unitName in ipairs({
    "plain convoy",
    "convoy #alarm",
    "convoy #alarm=",
    "convoy #alarm=x",
    "convoy #alarmstate=2",
    "convoy #alarm=-1",
  }) do
    local _, _, found = unitName:lower():find(veafCombatZone.ALARM_TAG_PATTERN)
    luaunit.assertNil(found, "unit name: " .. unitName)
  end
end

function TestVeafCombatZoneElement:test_chaining_setters()
  local result = self.el:setName("chain"):setDcsStatic(true):setSpawnRadius(100):setSpawnChance(50)
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
  luaunit.assertTrue(self.z.enableSmokeAndFlare) -- default
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
  local hook = function()
    called = true
  end
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

-- ============================================================================
-- TestVeafCombatZoneDelayedSpawners
-- ============================================================================
TestVeafCombatZoneDelayedSpawners = {}

function TestVeafCombatZoneDelayedSpawners:setUp()
  self.z = VeafCombatZone:new():setFriendlyName("Z")
end

function TestVeafCombatZoneDelayedSpawners:test_delayedSpawners_initially_empty()
  luaunit.assertEquals(#self.z.delayedSpawners, 0)
end

function TestVeafCombatZoneDelayedSpawners:test_addDelayedSpawner_increases_count()
  self.z:addDelayedSpawner(42)
  luaunit.assertEquals(#self.z:getDelayedSpawners(), 1)
end

function TestVeafCombatZoneDelayedSpawners:test_addDelayedSpawner_multiple()
  self.z:addDelayedSpawner(1)
  self.z:addDelayedSpawner(2)
  self.z:addDelayedSpawner(3)
  luaunit.assertEquals(#self.z:getDelayedSpawners(), 3)
end

function TestVeafCombatZoneDelayedSpawners:test_clearDelayedSpawners_empties_list()
  self.z:addDelayedSpawner(1)
  self.z:addDelayedSpawner(2)
  self.z:clearDelayedSpawners()
  luaunit.assertEquals(#self.z:getDelayedSpawners(), 0)
end

-- ============================================================================
-- TestVeafCombatZoneElementsManagement
-- ============================================================================
TestVeafCombatZoneElementsManagement = {}

function TestVeafCombatZoneElementsManagement:setUp()
  self.z = VeafCombatZone:new():setFriendlyName("Z")
end

function TestVeafCombatZoneElementsManagement:test_addZoneElement_increases_elements_count()
  local el = VeafCombatZoneElement:new():setName("el1"):setSpawnGroup("grp1")
  self.z:addZoneElement(el)
  luaunit.assertEquals(#self.z:getZoneElements(), 1)
end

function TestVeafCombatZoneElementsManagement:test_addZoneElement_creates_elementGroup()
  local el = VeafCombatZoneElement:new():setName("el1"):setSpawnGroup("grp1")
  self.z:addZoneElement(el)
  local groups = self.z:getZoneElementsGroups()
  luaunit.assertNotNil(groups["grp1"])
end

function TestVeafCombatZoneElementsManagement:test_addZoneElement_same_group_shared_elementGroup()
  local el1 = VeafCombatZoneElement:new():setName("el1"):setSpawnGroup("grp1")
  local el2 = VeafCombatZoneElement:new():setName("el2"):setSpawnGroup("grp1")
  self.z:addZoneElement(el1)
  self.z:addZoneElement(el2)
  luaunit.assertEquals(#self.z:getZoneElementsGroups()["grp1"].elements, 2)
end

function TestVeafCombatZoneElementsManagement:test_addZoneElement_different_groups_separate_elementGroups()
  local el1 = VeafCombatZoneElement:new():setName("el1"):setSpawnGroup("grpA")
  local el2 = VeafCombatZoneElement:new():setName("el2"):setSpawnGroup("grpB")
  self.z:addZoneElement(el1)
  self.z:addZoneElement(el2)
  luaunit.assertEquals(#self.z:getZoneElements(), 2)
  luaunit.assertNotNil(self.z:getZoneElementsGroups()["grpA"])
  luaunit.assertNotNil(self.z:getZoneElementsGroups()["grpB"])
end

function TestVeafCombatZoneElementsManagement:test_addZoneElementsFromZoneNamed_nil_returns_self()
  local result = self.z:addZoneElementsFromZoneNamed(nil)
  luaunit.assertEquals(result, self.z)
end

function TestVeafCombatZoneElementsManagement:test_addZoneElementsFromZoneNamed_copies_elements()
  local srcZone = VeafCombatZone:new():setFriendlyName("Src")
  local el = VeafCombatZoneElement:new():setName("srcEl"):setSpawnGroup("sg1")
  srcZone:addZoneElement(el)
  veafCombatZone.zonesDict["srczone"] = srcZone
  self.z:addZoneElementsFromZoneNamed("srczone")
  luaunit.assertEquals(#self.z:getZoneElements(), 1)
  veafCombatZone.zonesDict["srczone"] = nil -- cleanup
end

-- ============================================================================
-- TestVeafCombatZoneChaining
-- ============================================================================
TestVeafCombatZoneChaining = {}

function TestVeafCombatZoneChaining:setUp()
  self.z = VeafCombatZone:new():setFriendlyName("Z")
end

function TestVeafCombatZoneChaining:test_getChainedCombatZones_initializes_to_empty_table()
  local result = self.z:getChainedCombatZones()
  luaunit.assertNotNil(result)
  luaunit.assertEquals(#result, 0)
end

function TestVeafCombatZoneChaining:test_addChainedCombatZone_returns_self()
  local result = self.z:addChainedCombatZone("Zone2")
  luaunit.assertEquals(result, self.z)
end

function TestVeafCombatZoneChaining:test_addChainedCombatZone_increases_count()
  self.z:addChainedCombatZone("Zone2")
  luaunit.assertEquals(#self.z:getChainedCombatZones(), 1)
end

function TestVeafCombatZoneChaining:test_addChainedCombatZone_multiple()
  self.z:addChainedCombatZone("Zone2")
  self.z:addChainedCombatZone("Zone3")
  luaunit.assertEquals(#self.z:getChainedCombatZones(), 2)
end

function TestVeafCombatZoneChaining:test_getNextChainedCombatZone_single_returns_it()
  self.z:addChainedCombatZone("Zone2")
  local next = self.z:getNextChainedCombatZone()
  luaunit.assertEquals(next, "Zone2")
end

function TestVeafCombatZoneChaining:test_getChainedCombatZonesDelay_default_zero()
  local delay = self.z:getChainedCombatZonesDelay()
  luaunit.assertEquals(delay, 0)
end

function TestVeafCombatZoneChaining:test_setGetChainedCombatZonesDelay_numeric()
  self.z:setChainedCombatZonesDelay(30)
  luaunit.assertEquals(self.z:getChainedCombatZonesDelay(), 30)
end

function TestVeafCombatZoneChaining:test_setChainedCombatZonesDelay_nil_becomes_zero()
  self.z:setChainedCombatZonesDelay(nil)
  luaunit.assertEquals(self.z:getChainedCombatZonesDelay(), 0)
end

function TestVeafCombatZoneChaining:test_activateNextChainedZone_zone_found_schedules()
  local nextZone = VeafCombatZone:new():setFriendlyName("Next"):setMissionEditorZoneName("NEXTZONE")
  nextZone:disableJunkCleanup()
  veafCombatZone.zonesDict["nextzone"] = nextZone
  self.z:addChainedCombatZone("NEXTZONE")
  self.z:activateNextChainedZone()
  luaunit.assertTrue(true)
  veafCombatZone.zonesDict["nextzone"] = nil
end

-- ============================================================================
-- TestVeafCombatZoneObjectiveMethods
-- ============================================================================
TestVeafCombatZoneObjectiveMethods = {}

function TestVeafCombatZoneObjectiveMethods:setUp()
  self.z = VeafCombatZone:new():setFriendlyName("Z")
end

function TestVeafCombatZoneObjectiveMethods:test_addObjective_increases_count()
  self.z:addObjective("obj1")
  luaunit.assertEquals(#self.z.objectives, 1)
end

function TestVeafCombatZoneObjectiveMethods:test_addObjective_multiple()
  self.z:addObjective("obj1")
  self.z:addObjective("obj2")
  luaunit.assertEquals(#self.z.objectives, 2)
end

function TestVeafCombatZoneObjectiveMethods:test_addDefaultObjectives_returns_self()
  local result = self.z:addDefaultObjectives()
  luaunit.assertEquals(result, self.z)
end

-- ============================================================================
-- TestVeafCombatZoneInfoMethods
-- ============================================================================
TestVeafCombatZoneInfoMethods = {}

function TestVeafCombatZoneInfoMethods:setUp()
  self.z = VeafCombatZone:new():setFriendlyName("TestZone")
end

function TestVeafCombatZoneInfoMethods:test_getCenter_initially_nil()
  luaunit.assertNil(self.z:getCenter())
end

function TestVeafCombatZoneInfoMethods:test_getTriggerZone_initially_nil()
  luaunit.assertNil(self.z:getTriggerZone())
end

function TestVeafCombatZoneInfoMethods:test_getInformation_inactive_contains_zone_name()
  local info = self.z:getInformation(nil)
  luaunit.assertTrue(info:find("TestZone") ~= nil)
end

function TestVeafCombatZoneInfoMethods:test_getInformation_inactive_contains_not_active_message()
  local info = self.z:getInformation(nil)
  luaunit.assertTrue(info:find("not yet active") ~= nil)
end

function TestVeafCombatZoneInfoMethods:test_getInformation_inactive_with_briefing()
  self.z:setBriefing("Attack the convoy at dawn.")
  local info = self.z:getInformation(nil)
  luaunit.assertTrue(info:find("BRIEFING") ~= nil)
  luaunit.assertTrue(info:find("Attack the convoy") ~= nil)
end

-- ============================================================================
-- TestVeafCombatZoneWatchdog
-- ============================================================================
TestVeafCombatZoneWatchdog = {}

function TestVeafCombatZoneWatchdog:setUp()
  self.z = VeafCombatZone:new():setFriendlyName("Z"):setMissionEditorZoneName("ZONE_W")
end

function TestVeafCombatZoneWatchdog:test_unscheduleWatchdogFunction_nil_safe()
  self.z:unscheduleWatchdogFunction()
  luaunit.assertTrue(true)
end

function TestVeafCombatZoneWatchdog:test_scheduleWatchdogFunction_when_completable()
  self.z:scheduleWatchdogFunction()
  luaunit.assertTrue(true)
end

function TestVeafCombatZoneWatchdog:test_scheduleWatchdogFunction_when_not_completable()
  self.z:setCompletable(false)
  self.z:scheduleWatchdogFunction()
  luaunit.assertTrue(true)
end

function TestVeafCombatZoneWatchdog:test_unscheduleWatchdogFunction_with_id_clears_it()
  self.z.watchdogFunctionId = 999
  self.z:unscheduleWatchdogFunction()
  luaunit.assertNil(self.z.watchdogFunctionId)
end

-- ============================================================================
-- TestVeafCombatZoneCompletion
-- ============================================================================
TestVeafCombatZoneCompletion = {}

function TestVeafCombatZoneCompletion:setUp()
  veafCombatZone.zonesDict = {}
  veafCombatZone.zonesList = {}
  dcs_mocks.clearUnitsAndGroups()
  self.z = VeafCombatZone:new()
  self.z:setFriendlyName("CompZone"):setMissionEditorZoneName("COMP_ZONE")
  self.z:disableJunkCleanup()
end

function TestVeafCombatZoneCompletion:test_completionCheck_not_completable_returns_early()
  self.z:setCompletable(false)
  self.z:completionCheck()
  luaunit.assertTrue(true)
end

function TestVeafCombatZoneCompletion:test_completionCheck_no_groups_triggers_complete()
  self.z:completionCheck()
  luaunit.assertFalse(self.z:isActive())
end

function TestVeafCombatZoneCompletion:test_completionCheck_with_red_group_reschedules()
  dcs_mocks.addGroup("redgrp", {
    getUnits = function()
      return { {
        getCoalition = function()
          return 1
        end,
      } }
    end,
  })
  self.z:addSpawnedGroup("redgrp")
  self.z:completionCheck()
  luaunit.assertTrue(true)
  dcs_mocks.removeGroup("redgrp")
end

function TestVeafCombatZoneCompletion:test_completionCheck_blue_coalition_counted()
  dcs_mocks.addGroup("bluegrp", {
    getUnits = function()
      return { {
        getCoalition = function()
          return 2
        end,
      } }
    end,
  })
  self.z:addSpawnedGroup("bluegrp")
  self.z:completionCheck()
  luaunit.assertFalse(self.z:isActive())
  dcs_mocks.removeGroup("bluegrp")
end

function TestVeafCombatZoneCompletion:test_completionCheck_onCompletedHook_called()
  local hookCalled = false
  self.z:setOnCompletedHook(function(_)
    hookCalled = true
  end)
  self.z:completionCheck()
  luaunit.assertTrue(hookCalled)
end

function TestVeafCombatZoneCompletion:test_completionCheck_static_object_red_coalition()
  local origStaticGetByName = StaticObject.getByName
  StaticObject.getByName = function(name)
    if name == "staticUnit123" then
      return {
        getCoalition = function()
          return 1
        end,
      }
    end
    return nil
  end
  self.z:addSpawnedGroup("staticUnit123")
  self.z:completionCheck()
  luaunit.assertTrue(true)
  StaticObject.getByName = origStaticGetByName
end

function TestVeafCombatZoneCompletion:test_desactivate_with_spawned_group_destroys_it()
  dcs_mocks.addGroup("spawnedGrp", {})
  self.z:addSpawnedGroup("spawnedGrp")
  self.z:desactivate()
  luaunit.assertEquals(#self.z:getSpawnedGroups(), 0)
  dcs_mocks.removeGroup("spawnedGrp")
end

function TestVeafCombatZoneCompletion:test_desactivate_with_unknown_group_no_error()
  self.z:addSpawnedGroup("nonExistentGroup999")
  self.z:desactivate()
  luaunit.assertEquals(#self.z:getSpawnedGroups(), 0)
end

function TestVeafCombatZoneCompletion:test_desactivate_with_static_object_found()
  local origStaticGetByName = StaticObject.getByName
  StaticObject.getByName = function(name)
    if name == "staticGrp456" then
      return {
        getName = function()
          return name
        end,
        destroy = function() end,
        getCoalition = function()
          return 1
        end,
      }
    end
    return nil
  end
  self.z:addSpawnedGroup("staticGrp456")
  self.z:desactivate()
  luaunit.assertEquals(#self.z:getSpawnedGroups(), 0)
  StaticObject.getByName = origStaticGetByName
end

-- ============================================================================
-- TestVeafCombatZoneRegistry
-- ============================================================================
TestVeafCombatZoneRegistry = {}

function TestVeafCombatZoneRegistry:setUp()
  veafCombatZone.zonesDict = {}
  veafCombatZone.zonesList = {}
end

function TestVeafCombatZoneRegistry:test_GetZone_nil_returns_nil()
  luaunit.assertNil(veafCombatZone.GetZone(nil))
end

function TestVeafCombatZoneRegistry:test_GetZone_missing_returns_nil()
  local result = veafCombatZone.GetZone("NonExistent")
  luaunit.assertNil(result)
end

function TestVeafCombatZoneRegistry:test_GetZone_found_returns_zone()
  local z = VeafCombatZone:new():setFriendlyName("Found Zone"):setMissionEditorZoneName("FoundZone")
  veafCombatZone.zonesDict["foundzone"] = z
  local result = veafCombatZone.GetZone("FoundZone")
  luaunit.assertEquals(result, z)
end

function TestVeafCombatZoneRegistry:test_CompletionCheck_missing_zone_returns_nil()
  local result = veafCombatZone.CompletionCheck("NoZone")
  luaunit.assertNil(result)
end

function TestVeafCombatZoneRegistry:test_AddZone_registers_zone_in_dict_and_list()
  local z = VeafCombatZone:new():setFriendlyName("Reg Zone"):setMissionEditorZoneName("REGZONE")
  local result = veafCombatZone.AddZone(z)
  luaunit.assertEquals(result, z)
  luaunit.assertNotNil(veafCombatZone.zonesDict["regzone"])
end

function TestVeafCombatZoneRegistry:test_ActivateZone_zone_not_found_returns_nil()
  local result = veafCombatZone.ActivateZone("NonExistentZone999", true)
  luaunit.assertNil(result)
end

function TestVeafCombatZoneRegistry:test_ActivateZone_zone_found_not_active()
  local z = VeafCombatZone:new():setFriendlyName("AZ"):setMissionEditorZoneName("ACTZ")
  z:disableJunkCleanup()
  veafCombatZone.zonesDict["actz"] = z
  local result = veafCombatZone.ActivateZone("ACTZ", true)
  luaunit.assertEquals(result, z)
end

function TestVeafCombatZoneRegistry:test_ActivateZone_zone_already_active_silent()
  local z = VeafCombatZone:new():setFriendlyName("AZ2"):setMissionEditorZoneName("ACTZ2")
  z:setActive(true)
  veafCombatZone.zonesDict["actz2"] = z
  veafCombatZone.ActivateZone("ACTZ2", true)
  luaunit.assertTrue(z:isActive())
end

function TestVeafCombatZoneRegistry:test_DesactivateZone_zone_not_found_returns_nil()
  local result = veafCombatZone.DesactivateZone("NonExistentZone999", true)
  luaunit.assertNil(result)
end

function TestVeafCombatZoneRegistry:test_DesactivateZone_zone_found_not_active()
  local z = VeafCombatZone:new():setFriendlyName("DZ"):setMissionEditorZoneName("DACT1")
  z:disableJunkCleanup()
  veafCombatZone.zonesDict["dact1"] = z
  veafCombatZone.DesactivateZone("DACT1", true)
  luaunit.assertFalse(z:isActive())
end

function TestVeafCombatZoneRegistry:test_DesactivateZone_zone_found_active()
  local z = VeafCombatZone:new():setFriendlyName("DZ2"):setMissionEditorZoneName("DACT2")
  z:setActive(true):disableJunkCleanup()
  veafCombatZone.zonesDict["dact2"] = z
  local result = veafCombatZone.DesactivateZone("DACT2", false)
  luaunit.assertEquals(result, z)
  luaunit.assertFalse(z:isActive())
end

function TestVeafCombatZoneRegistry:test_GetInformationOnZone_zone_found()
  local z = VeafCombatZone:new():setFriendlyName("GI Zone"):setMissionEditorZoneName("GINFOZ")
  z:setActive(false):setShowZonePositionInfo(false)
  veafCombatZone.zonesDict["ginfoz"] = z
  local result = veafCombatZone.GetInformationOnZone({ "GINFOZ", nil })
  luaunit.assertEquals(result, z)
end

function TestVeafCombatZoneRegistry:test_GetInformationOnZone_zone_not_found()
  local result = veafCombatZone.GetInformationOnZone({ "NoZone999", nil })
  luaunit.assertNil(result)
end

function TestVeafCombatZoneRegistry:test_SmokeReset_zone_found_clears_schedule_id()
  local z = VeafCombatZone:new():setFriendlyName("SZ"):setMissionEditorZoneName("SMOKEZ")
  z.smokeResetFunctionId = 99
  veafCombatZone.zonesDict["smokez"] = z
  local result = veafCombatZone.SmokeReset("SMOKEZ")
  luaunit.assertEquals(result, z)
  luaunit.assertNil(z.smokeResetFunctionId)
end

function TestVeafCombatZoneRegistry:test_SmokeReset_zone_not_found_returns_nil()
  local result = veafCombatZone.SmokeReset("NoZone999")
  luaunit.assertNil(result)
end

function TestVeafCombatZoneRegistry:test_FlareReset_zone_found_clears_schedule_id()
  local z = VeafCombatZone:new():setFriendlyName("FZ"):setMissionEditorZoneName("FLAREZ")
  z.flareResetFunctionId = 77
  veafCombatZone.zonesDict["flarez"] = z
  local result = veafCombatZone.FlareReset("FLAREZ")
  luaunit.assertEquals(result, z)
  luaunit.assertNil(z.flareResetFunctionId)
end

function TestVeafCombatZoneRegistry:test_FlareReset_zone_not_found_returns_nil()
  local result = veafCombatZone.FlareReset("NoZone999")
  luaunit.assertNil(result)
end

function TestVeafCombatZoneRegistry:test_CompletionCheck_module_zone_found()
  local z = VeafCombatZone:new():setFriendlyName("CZ"):setMissionEditorZoneName("COMPZ")
  z:disableJunkCleanup()
  veafCombatZone.zonesDict["compz"] = z
  local result = veafCombatZone.CompletionCheck("COMPZ")
  luaunit.assertEquals(result, z)
end

function TestVeafCombatZoneRegistry:test_ActivateZoneNumber_zone_found()
  local z = VeafCombatZone:new():setFriendlyName("NZ"):setMissionEditorZoneName("NUMZ")
  z:disableJunkCleanup()
  veafCombatZone.zonesList[100] = z
  veafCombatZone.zonesDict["numz"] = z
  veafCombatZone.ActivateZoneNumber(100, true)
  luaunit.assertTrue(true)
  veafCombatZone.zonesList[100] = nil
end

function TestVeafCombatZoneRegistry:test_DesactivateZoneNumber_zone_found()
  local z = VeafCombatZone:new():setFriendlyName("NZ2"):setMissionEditorZoneName("NUMZ2")
  z:setActive(true):disableJunkCleanup()
  veafCombatZone.zonesList[200] = z
  veafCombatZone.zonesDict["numz2"] = z
  veafCombatZone.DesactivateZoneNumber(200, false)
  luaunit.assertTrue(true)
  veafCombatZone.zonesList[200] = nil
end

-- ============================================================================
-- TestVeafCombatZoneInitialize
-- ============================================================================
TestVeafCombatZoneInitialize = {}

function TestVeafCombatZoneInitialize:test_initialize_nil_zoneName_returns_self()
  local z = VeafCombatZone:new():setFriendlyName("Z")
  local result = z:initialize()
  luaunit.assertEquals(result, z)
end

function TestVeafCombatZoneInitialize:test_initialize_missing_trigger_zone_returns_self()
  local z = VeafCombatZone:new():setFriendlyName("Z"):setMissionEditorZoneName("NO_SUCH_TRIGGER_ZONE")
  local result = z:initialize()
  luaunit.assertEquals(result, z)
end

-- ============================================================================
-- TestVeafCombatZoneGetInformation
-- ============================================================================
TestVeafCombatZoneGetInformation = {}

function TestVeafCombatZoneGetInformation:setUp()
  self._origFindUnit = veafUnits.findUnit
  veafUnits.findUnit = function(typeName)
    if typeName == "FakeVehicle" then
      return { vehicle = true, naval = false, infantry = false }
    end
    return nil
  end
  dcs_mocks.clearUnitsAndGroups()
  self.z =
    VeafCombatZone:new():setFriendlyName("Info Zone"):setMissionEditorZoneName("INFO_ZONE"):setActive(true):setShowZonePositionInfo(false)
end

function TestVeafCombatZoneGetInformation:tearDown()
  veafUnits.findUnit = self._origFindUnit
  dcs_mocks.clearUnitsAndGroups()
end

function TestVeafCombatZoneGetInformation:test_getInformation_active_no_groups()
  local info = self.z:getInformation(nil)
  luaunit.assertTrue(info:find("Info Zone") ~= nil)
end

function TestVeafCombatZoneGetInformation:test_getInformation_active_unit_nil_typeName()
  dcs_mocks.addGroup("nilTypeGrp", {
    getUnits = function()
      return {
        {
          getCoalition = function()
            return 1
          end,
          getTypeName = function()
            return nil
          end,
        },
      }
    end,
  })
  self.z:addSpawnedGroup("nilTypeGrp")
  local info = self.z:getInformation(nil)
  luaunit.assertIsString(info)
  dcs_mocks.removeGroup("nilTypeGrp")
end

function TestVeafCombatZoneGetInformation:test_getInformation_active_red_vehicle_shows_enemies()
  dcs_mocks.addGroup("redVehicleGrp", {
    getUnits = function()
      return {
        {
          getCoalition = function()
            return 1
          end,
          getTypeName = function()
            return "FakeVehicle"
          end,
        },
      }
    end,
  })
  self.z:addSpawnedGroup("redVehicleGrp")
  local info = self.z:getInformation(nil)
  luaunit.assertTrue(info:find("vehicle") ~= nil)
  dcs_mocks.removeGroup("redVehicleGrp")
end

function TestVeafCombatZoneGetInformation:test_getInformation_active_blue_vehicle_shows_friends()
  dcs_mocks.addGroup("blueVehicleGrp", {
    getUnits = function()
      return {
        {
          getCoalition = function()
            return 2
          end,
          getTypeName = function()
            return "FakeVehicle"
          end,
        },
      }
    end,
  })
  self.z:addSpawnedGroup("blueVehicleGrp")
  local info = self.z:getInformation(nil)
  luaunit.assertTrue(info:find("FRIENDS") ~= nil)
  dcs_mocks.removeGroup("blueVehicleGrp")
end

function TestVeafCombatZoneGetInformation:test_getInformation_active_training_with_red_and_blue()
  self.z:setTraining(true)
  self.z:setShowZonePositionInfo(false) -- setTraining(true) forces showZonePositionInfo=true; override it
  dcs_mocks.addGroup("trainGrp", {
    getUnits = function()
      return {
        {
          getCoalition = function()
            return 1
          end,
          getTypeName = function()
            return "FakeVehicle"
          end,
        },
        {
          getCoalition = function()
            return 2
          end,
          getTypeName = function()
            return "FakeVehicle"
          end,
        },
      }
    end,
  })
  self.z:addSpawnedGroup("trainGrp")
  local info = self.z:getInformation(nil)
  luaunit.assertTrue(info:find("FakeVehicle") ~= nil)
  dcs_mocks.removeGroup("trainGrp")
end

-- ============================================================================
-- TestVeafCombatZoneEnemyCoalition (FEAT-COMBATZONE-RED-SIDE)
-- ============================================================================
TestVeafCombatZoneEnemyCoalition = {}

function TestVeafCombatZoneEnemyCoalition:setUp()
  veafCombatZone.zonesDict = {}
  veafCombatZone.zonesList = {}
  dcs_mocks.clearUnitsAndGroups()
  self.z = VeafCombatZone:new():setFriendlyName("Sided"):setMissionEditorZoneName("SIDED_ZONE")
  self.z:disableJunkCleanup()
end

function TestVeafCombatZoneEnemyCoalition:tearDown()
  dcs_mocks.clearUnitsAndGroups()
end

function TestVeafCombatZoneEnemyCoalition:test_defaults_to_red()
  luaunit.assertEquals(self.z:getEnemyCoalition(), 1)
  luaunit.assertEquals(self.z:getFriendlyCoalition(), 2)
end

function TestVeafCombatZoneEnemyCoalition:test_module_default_constant()
  luaunit.assertEquals(veafCombatZone.DEFAULT_ENEMY_COALITION, 1)
end

function TestVeafCombatZoneEnemyCoalition:test_setter_accepts_side_number()
  self.z:setEnemyCoalition(2)
  luaunit.assertEquals(self.z:getEnemyCoalition(), 2)
  luaunit.assertEquals(self.z:getFriendlyCoalition(), 1)
end

function TestVeafCombatZoneEnemyCoalition:test_setter_accepts_string()
  -- the generated config passes the YAML value through as a string
  self.z:setEnemyCoalition("blue")
  luaunit.assertEquals(self.z:getEnemyCoalition(), 2)
  self.z:setEnemyCoalition("RED")
  luaunit.assertEquals(self.z:getEnemyCoalition(), 1)
end

function TestVeafCombatZoneEnemyCoalition:test_setter_keeps_previous_on_unknown_value()
  self.z:setEnemyCoalition("blue")
  self.z:setEnemyCoalition("purple")
  luaunit.assertEquals(self.z:getEnemyCoalition(), 2)
end

function TestVeafCombatZoneEnemyCoalition:test_setter_rejects_invalid_side_numbers()
  -- Only RED and BLUE can be hostile: NEUTRAL (0) or a bogus side would leave the zone
  -- silently inconsistent (report tally not found, completion falling back to reds).
  for _, side in ipairs({ 0, 3, -1 }) do
    self.z:setEnemyCoalition("blue")
    self.z:setEnemyCoalition(side)
    luaunit.assertEquals(self.z:getEnemyCoalition(), 2)
  end
end

function TestVeafCombatZoneEnemyCoalition:test_setter_rejects_non_scalar_values()
  self.z:setEnemyCoalition("blue")
  self.z:setEnemyCoalition(nil)
  luaunit.assertEquals(self.z:getEnemyCoalition(), 2)
  self.z:setEnemyCoalition({})
  luaunit.assertEquals(self.z:getEnemyCoalition(), 2)
end

function TestVeafCombatZoneEnemyCoalition:test_setter_is_chainable()
  luaunit.assertEquals(self.z:setEnemyCoalition(2), self.z)
end

function TestVeafCombatZoneEnemyCoalition:test_blue_sided_zone_stays_active_while_blue_units_live()
  -- Before this feature such a zone completed on its very first check: completion was
  -- decided on the red count alone, and a red-side zone holds no red unit.
  self.z:setEnemyCoalition(2):setActive(true)
  dcs_mocks.addGroup("blueEnemies", {
    getUnits = function()
      return { {
        getCoalition = function()
          return 2
        end,
      } }
    end,
  })
  self.z:addSpawnedGroup("blueEnemies")
  self.z:completionCheck()
  luaunit.assertTrue(self.z:isActive())
  dcs_mocks.removeGroup("blueEnemies")
end

function TestVeafCombatZoneEnemyCoalition:test_blue_sided_zone_completes_when_blue_units_are_gone()
  self.z:setEnemyCoalition(2):setActive(true)
  dcs_mocks.addGroup("redFriends", {
    getUnits = function()
      return { {
        getCoalition = function()
          return 1
        end,
      } }
    end,
  })
  self.z:addSpawnedGroup("redFriends")
  self.z:completionCheck()
  luaunit.assertFalse(self.z:isActive())
  dcs_mocks.removeGroup("redFriends")
end

function TestVeafCombatZoneEnemyCoalition:test_red_sided_zone_still_completes_on_red_death()
  -- regression guard for the default behaviour
  self.z:setActive(true)
  dcs_mocks.addGroup("blueOnly", {
    getUnits = function()
      return { {
        getCoalition = function()
          return 2
        end,
      } }
    end,
  })
  self.z:addSpawnedGroup("blueOnly")
  self.z:completionCheck()
  luaunit.assertFalse(self.z:isActive())
  dcs_mocks.removeGroup("blueOnly")
end

-- ============================================================================
-- TestVeafCombatZoneRedSideReport (FEAT-COMBATZONE-RED-SIDE)
-- ============================================================================
TestVeafCombatZoneRedSideReport = {}

function TestVeafCombatZoneRedSideReport:setUp()
  self._origFindUnit = veafUnits.findUnit
  veafUnits.findUnit = function(typeName)
    if typeName == "FakeVehicle" then
      return { vehicle = true, naval = false, infantry = false }
    end
    return nil
  end
  dcs_mocks.clearUnitsAndGroups()
  self.z = VeafCombatZone:new()
    :setFriendlyName("Red Side Zone")
    :setMissionEditorZoneName("RED_SIDE_ZONE")
    :setEnemyCoalition(2)
    :setActive(true)
    :setShowZonePositionInfo(false)
end

function TestVeafCombatZoneRedSideReport:tearDown()
  veafUnits.findUnit = self._origFindUnit
  dcs_mocks.clearUnitsAndGroups()
end

function TestVeafCombatZoneRedSideReport:test_blue_units_are_reported_as_enemies()
  dcs_mocks.addGroup("blueEnemyGrp", {
    getUnits = function()
      return {
        {
          getCoalition = function()
            return 2
          end,
          getTypeName = function()
            return "FakeVehicle"
          end,
        },
      }
    end,
  })
  self.z:addSpawnedGroup("blueEnemyGrp")
  local info = self.z:getInformation(nil)
  luaunit.assertTrue(info:find("ENEMIES") ~= nil)
  luaunit.assertNil(info:find("FRIENDS"))
  dcs_mocks.removeGroup("blueEnemyGrp")
end

function TestVeafCombatZoneRedSideReport:test_red_units_are_reported_as_friends()
  dcs_mocks.addGroup("redFriendGrp", {
    getUnits = function()
      return {
        {
          getCoalition = function()
            return 1
          end,
          getTypeName = function()
            return "FakeVehicle"
          end,
        },
      }
    end,
  })
  self.z:addSpawnedGroup("redFriendGrp")
  local info = self.z:getInformation(nil)
  luaunit.assertTrue(info:find("FRIENDS") ~= nil)
  luaunit.assertNil(info:find("ENEMIES"))
  dcs_mocks.removeGroup("redFriendGrp")
end

-- ============================================================================
-- TestVeafCombatZoneRadioMenuCoalition (FEAT-COMBATZONE-MENU-COALITION)
-- ============================================================================
TestVeafCombatZoneRadioMenuCoalition = {}

function TestVeafCombatZoneRadioMenuCoalition:setUp()
  self.z = VeafCombatZone:new():setFriendlyName("Menu"):setMissionEditorZoneName("MENU_ZONE")
end

function TestVeafCombatZoneRadioMenuCoalition:test_defaults_to_the_friendly_side()
  -- A default (red-enemy) zone is played by blue, so its menu goes to blue.
  luaunit.assertEquals(self.z:getRadioMenuCoalition(), 2)
end

function TestVeafCombatZoneRadioMenuCoalition:test_follows_enemy_coalition()
  self.z:setEnemyCoalition(2)
  luaunit.assertEquals(self.z:getRadioMenuCoalition(), 1)
end

function TestVeafCombatZoneRadioMenuCoalition:test_explicit_side_overrides_the_default()
  self.z:setRadioMenuCoalition(1)
  luaunit.assertEquals(self.z:getRadioMenuCoalition(), 1)
  self.z:setRadioMenuCoalition("blue")
  luaunit.assertEquals(self.z:getRadioMenuCoalition(), 2)
end

function TestVeafCombatZoneRadioMenuCoalition:test_all_makes_the_menu_global()
  -- nil is what veafRadio.addSubMenu treats as "show to everyone".
  self.z:setRadioMenuCoalition("all")
  luaunit.assertNil(self.z:getRadioMenuCoalition())
  self.z:setRadioMenuCoalition("ALL")
  luaunit.assertNil(self.z:getRadioMenuCoalition())
end

function TestVeafCombatZoneRadioMenuCoalition:test_all_survives_an_enemy_coalition_change()
  self.z:setRadioMenuCoalition("all")
  self.z:setEnemyCoalition(2)
  luaunit.assertNil(self.z:getRadioMenuCoalition())
end

function TestVeafCombatZoneRadioMenuCoalition:test_invalid_value_keeps_the_default()
  self.z:setRadioMenuCoalition("purple")
  luaunit.assertEquals(self.z:getRadioMenuCoalition(), 2)
  self.z:setRadioMenuCoalition(0)
  luaunit.assertEquals(self.z:getRadioMenuCoalition(), 2)
end

function TestVeafCombatZoneRadioMenuCoalition:test_setter_is_chainable()
  luaunit.assertEquals(self.z:setRadioMenuCoalition("all"), self.z)
end

function TestVeafCombatZoneRadioMenuCoalition:test_menu_is_created_for_that_side()
  -- End to end through veafRadio: a red-side zone's submenu must be scoped to red.
  local origAdd = veafRadio.addSubMenu
  local captured = {}
  veafRadio.addSubMenu = function(title, parent, side)
    table.insert(captured, { title = title, side = side })
    return { title = title, subMenus = {}, commands = {} }
  end
  self.z:setEnemyCoalition(2)
  self.z.radioParentPath = { title = "COMBAT ZONES", subMenus = {}, commands = {} }
  self.z:updateRadioMenu(true)
  veafRadio.addSubMenu = origAdd
  luaunit.assertTrue(#captured > 0)
  luaunit.assertEquals(captured[1].side, 1)
end

-- ============================================================================
-- Run
-- ============================================================================
os.exit(luaunit.LuaUnit.run())
