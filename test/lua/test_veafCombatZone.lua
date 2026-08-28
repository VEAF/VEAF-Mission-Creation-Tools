--- Tests for veafCombatZone.lua — VeafCombatZoneElement and VeafCombatZone OOP objects.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
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
-- immobilised convoys (#290). FIX-COMBATZONE-ALARM-BY-NATURE then showed one global default could not
-- serve both natures — AUTO silences a SAM battery's radar — so the state is now resolved per group and
-- `alarmState` holds **nil** until a `#alarm=` tag states one.

function TestVeafCombatZoneElement:test_alarmState_is_unstated_by_default()
  luaunit.assertNil(self.el:getAlarmState(), "nil is what lets the nature of the group decide")
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

function TestVeafCombatZoneElement:test_alarm_out_of_range_is_reported_not_swallowed()
  -- Sourcery's review point: a fallback nobody is told about makes `#alarm=7` look like a choice.
  local warned = {}
  local logger = veaf.loggers.get(veafCombatZone.Id)
  local originalWarn = logger.warn
  logger.warn = function(_, text, ...)
    table.insert(warned, text)
  end
  self.el:setAlarmState(7)
  logger.warn = originalWarn
  luaunit.assertEquals(self.el:getAlarmState(), veafCombatZone.DefaultAlarmState)
  luaunit.assertEquals(#warned, 1)
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
-- FIX-COMBATZONE-DELAYED-COMMAND — #66
--
-- `#command="-samsr!30"` spawns 30 seconds late. The zone used to iterate the collection table on the
-- line after the call, so it was empty, the group was registered nowhere, and desactivate() — which
-- destroys getSpawnedGroups() — could not destroy it. The SAM outlived its zone.
--
-- The zone now registers a hook, which fires whenever the group actually appears.
-- ============================================================================
TestVeafCombatZoneDelayedCommand = {}

function TestVeafCombatZoneDelayedCommand:setUp()
  self.z = VeafCombatZone:new()
  self.z:setMissionEditorZoneName("DelayZone")
  self.z:setFriendlyName("Delay Zone")
  self.z:setActive(true)

  self.el = VeafCombatZoneElement:new()
  self.el:setName("FakeUnit")
  self.el:setPosition({ x = 0, y = 0, z = 0 })
  self.el:setCoalition(coalition.side.RED)
  self.el:setVeafCommand("-samsr!30")

  -- Stand in for the interpreter: capture the collection table and spawn NOTHING, which is exactly
  -- what a delayed command does — veaf.scheduleFunction takes the work and the call returns.
  self._captured = nil
  local this = self
  veafInterpreter = {
    execute = function(command, position, coa, route, spawnedGroups)
      this._captured = spawnedGroups
      return true
    end,
  }

  self._goRoute = mist.goRoute
  self.routed = {}
  mist.goRoute = function(groupName, route)
    table.insert(self.routed, groupName)
  end
end

function TestVeafCombatZoneDelayedCommand:tearDown()
  mist.goRoute = self._goRoute
  veafInterpreter = nil
end

-- The defect, as one assertion: nothing is known right after the call...
function TestVeafCombatZoneDelayedCommand:test_the_zone_knows_nothing_right_after_a_delayed_command()
  self.z:spawnElement(self.el, true)
  luaunit.assertEquals(#self.z:getSpawnedGroups(), 0)
  luaunit.assertNotNil(self._captured, "the interpreter must have received a collection table")
end

-- ... and the fix: the group is registered when it eventually appears.
function TestVeafCombatZoneDelayedCommand:test_a_delayed_group_is_registered_when_it_appears()
  self.z:spawnElement(self.el, true)
  veaf.collectSpawnedGroup(self._captured, "DelayedSAM")
  luaunit.assertEquals(self.z:getSpawnedGroups(), { "DelayedSAM" })
end

function TestVeafCombatZoneDelayedCommand:test_a_delayed_group_is_sent_on_its_route()
  self.el:setRoute({ wp1 = { x = 1, z = 2 } })
  self.z:spawnElement(self.el, true)
  veaf.collectSpawnedGroup(self._captured, "DelayedSAM")
  luaunit.assertEquals(self.routed, { "DelayedSAM" })
end

-- Nominal path must not regress: a command with no delay spawns synchronously, and the hook is what
-- registers it now, so this proves the immediate case still works.
function TestVeafCombatZoneDelayedCommand:test_an_immediate_group_is_still_registered()
  veafInterpreter.execute = function(command, position, coa, route, spawnedGroups)
    veaf.collectSpawnedGroup(spawnedGroups, "ImmediateSAM")
    return true
  end
  self.z:spawnElement(self.el, true)
  luaunit.assertEquals(self.z:getSpawnedGroups(), { "ImmediateSAM" })
end

function TestVeafCombatZoneDelayedCommand:test_several_delayed_groups_are_all_registered()
  self.z:spawnElement(self.el, true)
  veaf.collectSpawnedGroup(self._captured, "SAM-1")
  veaf.collectSpawnedGroup(self._captured, "SAM-2")
  luaunit.assertEquals(self.z:getSpawnedGroups(), { "SAM-1", "SAM-2" })
end

-- A group appearing after its zone was switched off has to be destroyed, not registered: nothing can
-- unschedule that deferred spawn, since desactivate() only knows its own `#spawndelay` schedules.
function TestVeafCombatZoneDelayedCommand:test_a_group_appearing_after_deactivation_is_destroyed()
  local destroyed = {}
  local previous = Group.getByName
  Group.getByName = function(name)
    return {
      getName = function()
        return name
      end,
      destroy = function()
        table.insert(destroyed, name)
      end,
    }
  end

  self.z:spawnElement(self.el, true)
  self.z:setActive(false)
  veaf.collectSpawnedGroup(self._captured, "TooLateSAM")

  Group.getByName = previous
  luaunit.assertEquals(destroyed, { "TooLateSAM" })
  luaunit.assertEquals(#self.z:getSpawnedGroups(), 0, "an inactive zone must not register a group")
end

TestVeafCombatZoneDestroySpawnedGroup = {}

function TestVeafCombatZoneDestroySpawnedGroup:test_an_unknown_group_does_not_raise()
  local z = VeafCombatZone:new()
  local ok = pcall(function()
    z:destroySpawnedGroup("no such group")
  end)
  luaunit.assertTrue(ok)
end

function TestVeafCombatZoneDestroySpawnedGroup:test_a_static_is_destroyed_when_no_group_matches()
  local destroyed = {}
  local previousStatic = StaticObject.getByName
  StaticObject.getByName = function(name)
    return {
      getName = function()
        return name
      end,
      destroy = function()
        table.insert(destroyed, name)
      end,
    }
  end
  local z = VeafCombatZone:new()
  z:destroySpawnedGroup("SomeStatic")
  StaticObject.getByName = previousStatic
  luaunit.assertEquals(destroyed, { "SomeStatic" })
end

-- ============================================================================
-- Run
-- ============================================================================

-------------------------------------------------------------------------------------------------
-- FIX-COMBATZONE-ALARM-BY-NATURE
--
-- PR #762 gave every group a zone spawns the AUTO alert state, so convoys would drive (#290). A SAM
-- battery on AUTO keeps its radar down, so the same edit silenced every air defence inside a combat
-- zone. Its own PRD had named the trade -- "right for a SAM battery, wrong for a convoy" -- and picked
-- one default anyway. The state is now resolved from the group's nature.
-------------------------------------------------------------------------------------------------

TestVeafCombatZoneAlarmByNature = {}

function TestVeafCombatZoneAlarmByNature:setUp()
  self.el = VeafCombatZoneElement:new()
  self.el:setName("SomeGroup")
  self._getGroupRoute = mist.getGroupRoute
  mist.getGroupRoute = function()
    return nil
  end
end

function TestVeafCombatZoneAlarmByNature:tearDown()
  mist.getGroupRoute = self._getGroupRoute
end

-- The constants exist as a pair on purpose: both defaults are right, for opposite groups.
function TestVeafCombatZoneAlarmByNature:test_the_two_defaults_are_auto_and_red()
  luaunit.assertEquals(veafCombatZone.DefaultAlarmStateMobile, veafCombatZone.ALARM_STATE_AUTO)
  luaunit.assertEquals(veafCombatZone.DefaultAlarmStateStatic, veafCombatZone.ALARM_STATE_RED)
end

-- The defect this lot fixes, in one assertion: a battery that stays put must fight.
function TestVeafCombatZoneAlarmByNature:test_a_group_with_no_route_gets_red()
  luaunit.assertFalse(self.el:isMobile())
  luaunit.assertEquals(self.el:resolveAlarmState(), veafCombatZone.ALARM_STATE_RED)
end

-- ... and the regression guard on #290: a convoy must still drive.
function TestVeafCombatZoneAlarmByNature:test_a_group_with_a_route_gets_auto()
  self.el:setRoute({ { x = 0 }, { x = 1 }, { x = 2 } })
  luaunit.assertTrue(self.el:isMobile())
  luaunit.assertEquals(self.el:resolveAlarmState(), veafCombatZone.ALARM_STATE_AUTO)
end

-- A single waypoint is where a group sits, not somewhere to go.
function TestVeafCombatZoneAlarmByNature:test_a_single_waypoint_is_not_mobile()
  self.el:setRoute({ { x = 0 } })
  luaunit.assertFalse(self.el:isMobile())
  luaunit.assertEquals(self.el:resolveAlarmState(), veafCombatZone.ALARM_STATE_RED)
end

function TestVeafCombatZoneAlarmByNature:test_an_empty_route_is_not_mobile()
  self.el:setRoute({})
  luaunit.assertFalse(self.el:isMobile())
end

-- A native zone group carries no route of its own -- only a `#command` fake unit does -- so the route
-- has to come from the mission.
function TestVeafCombatZoneAlarmByNature:test_a_native_group_route_is_read_from_the_mission()
  mist.getGroupRoute = function(name, task)
    luaunit.assertEquals(name, "SomeGroup")
    return { { x = 0 }, { x = 1 } }
  end
  luaunit.assertTrue(self.el:isMobile())
  luaunit.assertEquals(self.el:resolveAlarmState(), veafCombatZone.ALARM_STATE_AUTO)
end

-- mist raises on a group it cannot find, and a zone element may name one destroyed since parsing.
function TestVeafCombatZoneAlarmByNature:test_a_raising_mist_does_not_break_the_spawn()
  mist.getGroupRoute = function()
    error("group not found")
  end
  local ok, mobile = pcall(function()
    return self.el:isMobile()
  end)
  luaunit.assertTrue(ok)
  luaunit.assertFalse(mobile)
  luaunit.assertEquals(self.el:resolveAlarmState(), veafCombatZone.ALARM_STATE_RED)
end

function TestVeafCombatZoneAlarmByNature:test_an_element_with_no_name_is_not_mobile()
  local el = VeafCombatZoneElement:new()
  luaunit.assertFalse(el:isMobile())
end

-- An explicit tag beats the nature, in both directions.
function TestVeafCombatZoneAlarmByNature:test_an_explicit_tag_wins_over_the_nature()
  self.el:setRoute({ { x = 0 }, { x = 1 } }) -- mobile, so AUTO by nature
  self.el:setAlarmState(2)
  luaunit.assertEquals(self.el:resolveAlarmState(), veafCombatZone.ALARM_STATE_RED)
end

function TestVeafCombatZoneAlarmByNature:test_an_explicit_auto_on_a_static_group_wins_too()
  self.el:setAlarmState(0) -- static by nature, so RED, but the mission maker said AUTO
  luaunit.assertEquals(self.el:resolveAlarmState(), veafCombatZone.ALARM_STATE_AUTO)
end

function TestVeafCombatZoneAlarmByNature:test_an_explicit_green_is_honoured()
  self.el:setAlarmState(1)
  luaunit.assertEquals(self.el:resolveAlarmState(), veafCombatZone.ALARM_STATE_GREEN)
end

-- ============================================================================
-- FIX-COMBATZONE-TAGS-FIRST-UNIT-ONLY
--
-- `initialize` read the seven tags off each unit's name, built an element, then threw the element away
-- for every unit of a group but the first one the loop met — and that order comes from
-- `mist.getUnitsInZones` followed by `pairs()`, which promises nothing. Tagging one truck of a convoy
-- worked or did not work depending on an order the mission maker cannot see. A tag on a **group** name,
-- which the documentation has always promised, was never read at all.
--
-- A group's tags are now collected from its own name and from all its unit names, group name first then
-- unit names alphabetically, first value found winning and a later disagreement warned about.
-- `#command` is deliberately left out of the merge: it is a one-shot trigger attached to an object, not
-- a setting of the group.
-- ============================================================================
TestVeafCombatZoneTagCollection = {}

-- Every settings tag, with a second value to conflict against. Enumerated rather than sampled: the
-- defect hit all of them, so each assertion below runs over the whole family.
local SETTINGS_TAGS = {
  { key = "spawnRadius", tag = "#spawnradius=200", value = "200", other = "#spawnradius=300", otherValue = "300" },
  { key = "spawnChance", tag = "#spawnchance=50", value = "50", other = "#spawnchance=75", otherValue = "75" },
  { key = "spawnCount", tag = "#spawncount=3", value = "3", other = "#spawncount=4", otherValue = "4" },
  { key = "spawnGroup", tag = '#spawngroup="sam"', value = "sam", other = '#spawngroup="convoy"', otherValue = "convoy" },
  { key = "spawnDelay", tag = "#spawndelay=120", value = "120", other = "#spawndelay=60", otherValue = "60" },
  { key = "alarmState", tag = "#alarm=2", value = "2", other = "#alarm=0", otherValue = "0" },
}

function TestVeafCombatZoneTagCollection:setUp()
  self._logger = veaf.loggers.get(veafCombatZone.Id)
  self._originalWarn = self._logger.warn
  self:captureWarnings()
end

--- Point the logger's `warn` at a fresh list, and return it.
function TestVeafCombatZoneTagCollection:captureWarnings()
  self.warned = {}
  local warned = self.warned
  self._logger.warn = function(_, text, ...)
    table.insert(warned, { text = text, args = { ... } })
  end
  return self.warned
end

function TestVeafCombatZoneTagCollection:tearDown()
  self._logger.warn = self._originalWarn
end

function TestVeafCombatZoneTagCollection:test_every_tag_has_a_pattern()
  -- the seven tags the documentation lists, as a table, so a sweep over "all the tags" is enumerable
  local everyTag = { "spawnRadius", "spawnChance", "spawnCount", "spawnGroup", "spawnDelay", "command", "alarmState" }
  for _, key in ipairs(everyTag) do
    luaunit.assertNotNil(veafCombatZone.TAG_PATTERNS[key], "no pattern for " .. key)
  end
end

function TestVeafCombatZoneTagCollection:test_alarm_keeps_its_published_pattern()
  -- ALARM_TAG_PATTERN is asserted on directly by other tests; the table must reuse it, not fork it
  luaunit.assertEquals(veafCombatZone.TAG_PATTERNS.alarmState, veafCombatZone.ALARM_TAG_PATTERN)
end

function TestVeafCombatZoneTagCollection:test_parseTags_reads_every_tag_off_one_name()
  local name = 'ALPHA-SAM #spawnradius=200 #spawnchance=50 #spawncount=3 #spawngroup="sam" #spawndelay=120 #alarm=2 #command="-spawn sa-11"'
  local tags = veafCombatZone.parseTags(name)
  luaunit.assertEquals(tags.spawnRadius, "200")
  luaunit.assertEquals(tags.spawnChance, "50")
  luaunit.assertEquals(tags.spawnCount, "3")
  luaunit.assertEquals(tags.spawnGroup, "sam")
  luaunit.assertEquals(tags.spawnDelay, "120")
  luaunit.assertEquals(tags.alarmState, "2")
  luaunit.assertEquals(tags.command, "-spawn sa-11")
end

function TestVeafCombatZoneTagCollection:test_parseTags_is_case_insensitive()
  -- the name is lowercased before matching, which is what makes `#ALARM=2` work and also why a
  -- `#command` value comes back lowercased — long-standing behaviour, pinned here on purpose
  local tags = veafCombatZone.parseTags('ALPHA #SPAWNRADIUS=200 #COMMAND="-Spawn SA-11"')
  luaunit.assertEquals(tags.spawnRadius, "200")
  luaunit.assertEquals(tags.command, "-spawn sa-11")
end

function TestVeafCombatZoneTagCollection:test_parseTags_finds_nothing_in_a_plain_name()
  luaunit.assertEquals(veafCombatZone.parseTags("ALPHA-CONVOY-1"), {})
end

function TestVeafCombatZoneTagCollection:test_parseTags_tolerates_no_name()
  luaunit.assertEquals(veafCombatZone.parseTags(nil), {})
end

-- The defect itself, over the whole family: the tag is on the second unit of the group.
function TestVeafCombatZoneTagCollection:test_a_tag_on_any_unit_of_the_group_counts()
  for _, t in ipairs(SETTINGS_TAGS) do
    local tags = veafCombatZone.collectTags("ALPHA-CONVOY", { "ALPHA-CONVOY-TRUCK-1", "ALPHA-CONVOY-TRUCK-2 " .. t.tag })
    luaunit.assertEquals(tags[t.key], t.value, t.key .. " on the second unit")
  end
end

-- The documentation's other promise: a tag on the group's own name.
function TestVeafCombatZoneTagCollection:test_a_tag_on_the_group_name_counts()
  for _, t in ipairs(SETTINGS_TAGS) do
    local tags = veafCombatZone.collectTags("ALPHA-CONVOY " .. t.tag, { "ALPHA-CONVOY-TRUCK-1", "ALPHA-CONVOY-TRUCK-2" })
    luaunit.assertEquals(tags[t.key], t.value, t.key .. " on the group name")
  end
end

function TestVeafCombatZoneTagCollection:test_a_group_with_no_units_still_reads_its_own_name()
  local tags = veafCombatZone.collectTags("ALPHA-STATIC #spawnradius=0", {})
  luaunit.assertEquals(tags.spawnRadius, "0")
end

function TestVeafCombatZoneTagCollection:test_the_group_name_wins_over_a_unit()
  for _, t in ipairs(SETTINGS_TAGS) do
    local tags = veafCombatZone.collectTags("ALPHA-CONVOY " .. t.tag, { "ALPHA-CONVOY-TRUCK-1 " .. t.other })
    luaunit.assertEquals(tags[t.key], t.value, t.key .. ": the group name is read first")
  end
end

-- Alphabetical, not encounter order: encounter order *is* `pairs()`, so tie-breaking on it would
-- reinstate the coin toss. The units are handed over in reverse on purpose.
function TestVeafCombatZoneTagCollection:test_the_first_unit_alphabetically_wins()
  for _, t in ipairs(SETTINGS_TAGS) do
    local units = { "ALPHA-CONVOY-TRUCK-B " .. t.other, "ALPHA-CONVOY-TRUCK-A " .. t.tag }
    local tags = veafCombatZone.collectTags("ALPHA-CONVOY", units)
    luaunit.assertEquals(tags[t.key], t.value, t.key .. ": A comes before B whatever the order given")
  end
end

function TestVeafCombatZoneTagCollection:test_a_disagreement_is_reported()
  for _, t in ipairs(SETTINGS_TAGS) do
    local warned = self:captureWarnings()
    veafCombatZone.collectTags("ALPHA-CONVOY", { "ALPHA-CONVOY-TRUCK-A " .. t.tag, "ALPHA-CONVOY-TRUCK-B " .. t.other })
    luaunit.assertEquals(#warned, 1, t.key .. ": a disagreement must be reported once")
  end
end

function TestVeafCombatZoneTagCollection:test_units_repeating_the_same_value_are_silent()
  -- tagging every truck of a convoy identically is the ordinary way of doing it; one log line per
  -- truck would make the honest case noisy
  for _, t in ipairs(SETTINGS_TAGS) do
    local tags = veafCombatZone.collectTags("ALPHA-CONVOY", {
      "ALPHA-CONVOY-TRUCK-A " .. t.tag,
      "ALPHA-CONVOY-TRUCK-B " .. t.tag,
      "ALPHA-CONVOY-TRUCK-C " .. t.tag,
    })
    luaunit.assertEquals(tags[t.key], t.value)
  end
  luaunit.assertEquals(#self.warned, 0)
end

function TestVeafCombatZoneTagCollection:test_command_is_not_merged()
  -- a `#command` is a trigger attached to an object, not a setting of the group: merging it would
  -- silently drop the second command of a group carrying two, which works today
  local tags = veafCombatZone.collectTags("ALPHA-TRIGGER", { 'ALPHA-TRIGGER-1 #command="-spawn sa-11"' })
  luaunit.assertNil(tags.command)
  luaunit.assertEquals(#self.warned, 0)
end

-- Sourcery's review point on the first cut: `initialize` was parsing each name a second time just to
-- read its `#command` back. The commands come out of the same pass now, keyed by the name that carried
-- one, so a name is read exactly once and there is a single place that reads it.
function TestVeafCombatZoneTagCollection:test_commands_come_back_keyed_by_their_source()
  local _, commands = veafCombatZone.collectTags("ALPHA-PAIR", {
    'ALPHA-PAIR-1 #command="-spawn sa-11"',
    'ALPHA-PAIR-2 #command="-spawn sa-6"',
    "ALPHA-PAIR-3",
  })
  luaunit.assertEquals(commands, {
    ['ALPHA-PAIR-1 #command="-spawn sa-11"'] = "-spawn sa-11",
    ['ALPHA-PAIR-2 #command="-spawn sa-6"'] = "-spawn sa-6",
  })
end

function TestVeafCombatZoneTagCollection:test_a_command_on_the_group_name_comes_back_under_it()
  local groupName = 'ALPHA-GRPCMD #command="-spawn sa-11"'
  local _, commands = veafCombatZone.collectTags(groupName, { "ALPHA-GRPCMD-1" })
  luaunit.assertEquals(commands[groupName], "-spawn sa-11")
end

function TestVeafCombatZoneTagCollection:test_no_command_means_an_empty_table_not_nil()
  local _, commands = veafCombatZone.collectTags("ALPHA-CONVOY", { "ALPHA-CONVOY-1", "ALPHA-CONVOY-2" })
  luaunit.assertEquals(commands, {})
end

function TestVeafCombatZoneTagCollection:test_an_unreadable_alarm_tag_is_still_reported()
  -- FIX-COMBATZONE-CONVOY-ALARM's warning, moved to the collection step and keeping its meaning
  for _, bad in ipairs({ "#alarm", "#alarm=", "#alarm=x", "#alarm=-1" }) do
    local warned = self:captureWarnings()
    local tags = veafCombatZone.collectTags("ALPHA-SAM", { "ALPHA-SAM-1 " .. bad })
    luaunit.assertNil(tags.alarmState, bad)
    luaunit.assertEquals(#warned, 1, bad .. " must be reported")
  end
end

function TestVeafCombatZoneTagCollection:test_a_readable_alarm_elsewhere_in_the_group_silences_the_warning()
  -- the point of collecting: one unit's typo is answered by another unit's readable tag
  local tags = veafCombatZone.collectTags("ALPHA-SAM", { "ALPHA-SAM-1 #alarm=x", "ALPHA-SAM-2 #alarm=2" })
  luaunit.assertEquals(tags.alarmState, "2")
  luaunit.assertEquals(#self.warned, 0)
end

function TestVeafCombatZoneTagCollection:test_a_plain_group_produces_no_tags_and_no_noise()
  luaunit.assertEquals(veafCombatZone.collectTags("ALPHA-CONVOY", { "ALPHA-CONVOY-1", "ALPHA-CONVOY-2" }), {})
  luaunit.assertEquals(#self.warned, 0)
end

-- ============================================================================
-- The same, end to end through `initialize` — the tests above prove the merge, these prove the merged
-- tags actually reach the zone element instead of being discarded with it.
-- ============================================================================
TestVeafCombatZoneInitializeTags = {}

--- A unit as `initialize` consumes one: a name, a coalition, a position and a group.
local function fakeUnit(unitName, groupName)
  return {
    getName = function()
      return unitName
    end,
    getCoalition = function()
      return coalition.side.RED
    end,
    getPosition = function()
      return { p = { x = 10, y = 0, z = 20 } }
    end,
    getGroup = function()
      return {
        getName = function()
          return groupName
        end,
      }
    end,
  }
end

--- A static object as `initialize` consumes one: its own group, and category 3 rather than 1.
local function fakeStatic(name)
  local static = fakeUnit(name, name)
  static._category = Object.Category.STATIC
  return static
end

--- Build a zone holding exactly the units given, and initialize it.
local function initializedZone(units)
  local z = VeafCombatZone:new():setFriendlyName("Tag Zone"):setMissionEditorZoneName("TAGZONE")
  local groupNames = {}
  local seen = {}
  for _, unit in ipairs(units) do
    local groupName = unit:getGroup():getName()
    if not seen[groupName] then
      seen[groupName] = true
      table.insert(groupNames, groupName)
    end
  end
  z.findUnitsInCombatZone = function()
    return { units, groupNames }
  end
  return z:initialize()
end

local function elementNamed(zone, name)
  for _, element in pairs(zone:getZoneElements()) do
    if element:getName() == name then
      return element
    end
  end
  return nil
end

local function commandsOf(zone)
  local commands = {}
  for _, element in pairs(zone:getZoneElements()) do
    if element:getVeafCommand() then
      commands[element:getVeafCommand()] = true
    end
  end
  return commands
end

function TestVeafCombatZoneInitializeTags:setUp()
  veaf.triggerZones["TAGZONE"] = { name = "TAGZONE", type = 0, radius = 1000, x = 0, y = 0 }
  dcs_mocks.clearUnitsAndGroups()
end

function TestVeafCombatZoneInitializeTags:tearDown()
  veaf.triggerZones["TAGZONE"] = nil
  dcs_mocks.clearUnitsAndGroups()
end

function TestVeafCombatZoneInitializeTags:test_a_tag_on_the_second_unit_reaches_the_element()
  local z = initializedZone({
    fakeUnit("TAGZONE-CONVOY-1", "TAGZONE-CONVOY"),
    fakeUnit("TAGZONE-CONVOY-2 #alarm=2 #spawnchance=50", "TAGZONE-CONVOY"),
  })
  local element = elementNamed(z, "TAGZONE-CONVOY")
  luaunit.assertNotNil(element, "the group must produce one element")
  luaunit.assertEquals(element:getAlarmState(), 2)
  luaunit.assertEquals(element:getSpawnChance(), 50)
end

function TestVeafCombatZoneInitializeTags:test_a_tag_on_the_group_name_reaches_the_element()
  local groupName = "TAGZONE-CONVOY #alarm=0 #spawnradius=300"
  local z = initializedZone({ fakeUnit("TAGZONE-CONVOY-1", groupName), fakeUnit("TAGZONE-CONVOY-2", groupName) })
  local element = elementNamed(z, groupName)
  luaunit.assertNotNil(element)
  luaunit.assertEquals(element:getAlarmState(), 0)
  luaunit.assertEquals(element:getSpawnRadius(), 300)
end

function TestVeafCombatZoneInitializeTags:test_one_element_per_group_whatever_the_unit_count()
  local z = initializedZone({
    fakeUnit("TAGZONE-CONVOY-1", "TAGZONE-CONVOY"),
    fakeUnit("TAGZONE-CONVOY-2", "TAGZONE-CONVOY"),
    fakeUnit("TAGZONE-CONVOY-3", "TAGZONE-CONVOY"),
  })
  luaunit.assertEquals(#z:getZoneElements(), 1)
end

function TestVeafCombatZoneInitializeTags:test_a_command_unit_still_gets_its_own_element()
  local z = initializedZone({ fakeUnit('TAGZONE-TRIGGER #command="-spawn sa-11"', "TAGZONE-TRIGGER") })
  luaunit.assertEquals(#z:getZoneElements(), 1)
  luaunit.assertEquals(z:getZoneElements()[1]:getVeafCommand(), "-spawn sa-11, czName TAGZONE")
end

function TestVeafCombatZoneInitializeTags:test_a_command_unit_and_a_plain_group_coexist()
  -- long-standing behaviour: the command unit is its own element and the rest of the group is another
  local z = initializedZone({
    fakeUnit('TAGZONE-MIXED-1 #command="-spawn sa-11"', "TAGZONE-MIXED"),
    fakeUnit("TAGZONE-MIXED-2", "TAGZONE-MIXED"),
  })
  luaunit.assertEquals(#z:getZoneElements(), 2)
  luaunit.assertEquals(commandsOf(z), { ["-spawn sa-11, czName TAGZONE"] = true })
end

function TestVeafCombatZoneInitializeTags:test_two_command_units_in_one_group_keep_both_commands()
  -- why `#command` is left out of the merge: merging would drop one of these silently
  local z = initializedZone({
    fakeUnit('TAGZONE-PAIR-1 #command="-spawn sa-11"', "TAGZONE-PAIR"),
    fakeUnit('TAGZONE-PAIR-2 #command="-spawn sa-6"', "TAGZONE-PAIR"),
  })
  luaunit.assertEquals(commandsOf(z), {
    ["-spawn sa-11, czName TAGZONE"] = true,
    ["-spawn sa-6, czName TAGZONE"] = true,
  })
end

function TestVeafCombatZoneInitializeTags:test_a_command_on_the_group_name_makes_one_trigger()
  -- the documentation's group-name promise, honoured without duplicating the command per unit
  local groupName = 'TAGZONE-GRPCMD #command="-spawn sa-11"'
  local z = initializedZone({ fakeUnit("TAGZONE-GRPCMD-1", groupName), fakeUnit("TAGZONE-GRPCMD-2", groupName) })
  luaunit.assertEquals(#z:getZoneElements(), 1)
  luaunit.assertEquals(z:getZoneElements()[1]:getVeafCommand(), "-spawn sa-11, czName TAGZONE")
end

function TestVeafCombatZoneInitializeTags:test_a_settings_tag_on_the_group_reaches_a_command_element()
  -- a consequence of collecting: the group's `#spawndelay` now reaches a `#command` unit that had none
  local groupName = "TAGZONE-DELAYED #spawndelay=120"
  local z = initializedZone({ fakeUnit('TAGZONE-DELAYED-1 #command="-spawn sa-11"', groupName) })
  luaunit.assertEquals(z:getZoneElements()[1]:getSpawnDelay(), 120)
end

-- FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT — the assertion the previous lot left pinned to the broken
-- behaviour, flipped now that the default is reachable again. Why the rule is what it is lives on
-- `buildGroupElement`; the history lives in the PRD.
--
-- These assert the **applied** radius, never the constant: `test_defaultSpawnRadii` asserts the constant
-- and coexisted with the defect for three years, which is the gap being closed here.
function TestVeafCombatZoneInitializeTags:test_an_untagged_group_gets_the_unit_default()
  local z = initializedZone({ fakeUnit("TAGZONE-PLAIN-1", "TAGZONE-PLAIN") })
  luaunit.assertEquals(elementNamed(z, "TAGZONE-PLAIN"):getSpawnRadius(), veafCombatZone.DefaultSpawnRadiusForUnits)
end

function TestVeafCombatZoneInitializeTags:test_an_untagged_static_gets_the_static_default()
  local z = initializedZone({ fakeStatic("TAGZONE-STATIC-FARP") })
  luaunit.assertEquals(elementNamed(z, "TAGZONE-STATIC-FARP"):getSpawnRadius(), veafCombatZone.DefaultSpawnRadiusForStatics)
end

function TestVeafCombatZoneInitializeTags:test_a_tagged_spawn_radius_is_honoured()
  local z = initializedZone({ fakeUnit("TAGZONE-PLAIN-1 #spawnradius=200", "TAGZONE-PLAIN") })
  luaunit.assertEquals(elementNamed(z, "TAGZONE-PLAIN"):getSpawnRadius(), 200)
end

-- The reason the default is read off the tag's presence and not off the value: `#spawnradius=0` is how
-- a mission maker asks for no dispersion, and it has to survive the default.
function TestVeafCombatZoneInitializeTags:test_an_explicit_zero_means_no_dispersion()
  local z = initializedZone({ fakeUnit("TAGZONE-PLAIN-1 #spawnradius=0", "TAGZONE-PLAIN") })
  luaunit.assertEquals(elementNamed(z, "TAGZONE-PLAIN"):getSpawnRadius(), 0)
end

function TestVeafCombatZoneInitializeTags:test_a_zero_on_another_unit_of_the_group_counts_too()
  -- the collection of the previous lot and the default of this one, together
  local z = initializedZone({
    fakeUnit("TAGZONE-PLAIN-1", "TAGZONE-PLAIN"),
    fakeUnit("TAGZONE-PLAIN-2 #spawnradius=0", "TAGZONE-PLAIN"),
  })
  luaunit.assertEquals(elementNamed(z, "TAGZONE-PLAIN"):getSpawnRadius(), 0)
end

-- A command element is a one-shot trigger running a command *at its position*; scattering it would move
-- what the command spawns, so it keeps no dispersion, as it always has.
function TestVeafCombatZoneInitializeTags:test_a_command_element_is_never_scattered()
  local z = initializedZone({ fakeUnit('TAGZONE-TRIGGER #command="-spawn sa-11"', "TAGZONE-TRIGGER") })
  luaunit.assertEquals(z:getZoneElements()[1]:getSpawnRadius(), 0)
end

-- And nothing may reach `spawnElement`'s `getSpawnRadius() > 0` with a nil, which is why the
-- constructor still starts at 0 rather than at nil.
function TestVeafCombatZoneInitializeTags:test_every_element_carries_a_number()
  local z = initializedZone({
    fakeUnit('TAGZONE-MIX-1 #command="-spawn sa-11"', "TAGZONE-MIX"),
    fakeUnit("TAGZONE-MIX-2", "TAGZONE-MIX"),
    fakeStatic("TAGZONE-STATIC-FARP"),
  })
  for _, element in pairs(z:getZoneElements()) do
    luaunit.assertIsNumber(element:getSpawnRadius(), "element " .. tostring(element:getName()))
  end
end

function TestVeafCombatZoneInitializeTags:test_a_group_element_defaults_its_spawn_group_to_its_name()
  local z = initializedZone({ fakeUnit("TAGZONE-PLAIN-1", "TAGZONE-PLAIN") })
  luaunit.assertEquals(elementNamed(z, "TAGZONE-PLAIN"):getSpawnGroup(), "TAGZONE-PLAIN")
end

-- ============================================================================
-- FIX-COMBATZONE-RENAME-OPTION — Sharko's #289, open since 2025-02-03
--
-- A combat zone always renamed its units sequentially: `vars.renameUnitsSequentially = true` was
-- hard-coded in the `mist.teleportToPoint` call, the single occurrence of that field in the whole
-- runtime, so the answer to "can I turn it off?" was no. Renaming is useful on a finished map and gets
-- in the way while debugging a `.miz`, where the original unit name is gone.
--
-- The assertions below are on the **vars handed to MiST**, not on the setter: a setter that stores a
-- value nobody reads is exactly the shape of defect FIX-COMBATZONE-DEAD-SPAWN-RADIUS-DEFAULT was.
-- ============================================================================
TestVeafCombatZoneRenameOption = {}

function TestVeafCombatZoneRenameOption:setUp()
  self.z = VeafCombatZone:new():setFriendlyName("Rename Zone"):setMissionEditorZoneName("RENAMEZONE")
  self.z:setActive(true)

  self.el = VeafCombatZoneElement:new()
  self.el:setName("RENAMEZONE-CONVOY")
  self.el:setPosition({ x = 0, y = 0, z = 0 })
  self.el:setCoalition(coalition.side.RED)
  self.el:setDcsGroup(true)

  self._teleport = mist.teleportToPoint
  self.vars = nil
  local this = self
  mist.teleportToPoint = function(vars)
    this.vars = vars
    return nil -- a nil return keeps spawnElement on its "nothing came back" path, which is enough here
  end
end

function TestVeafCombatZoneRenameOption:tearDown()
  mist.teleportToPoint = self._teleport
end

function TestVeafCombatZoneRenameOption:test_the_default_is_todays_behaviour()
  -- every mission built before this lot got sequential renaming; the default must not move
  luaunit.assertTrue(self.z:isRenameUnitsSequentially())
end

function TestVeafCombatZoneRenameOption:test_the_setter_chains_like_its_neighbours()
  local returned = self.z:setRenameUnitsSequentially(false)
  luaunit.assertEquals(returned, self.z)
  luaunit.assertFalse(self.z:isRenameUnitsSequentially())
end

-- The one that matters: the value reaches MiST.
function TestVeafCombatZoneRenameOption:test_a_spawn_asks_mist_to_rename_by_default()
  self.z:spawnElement(self.el, true)
  luaunit.assertNotNil(self.vars, "mist.teleportToPoint must have been called")
  luaunit.assertTrue(self.vars.renameUnitsSequentially)
end

function TestVeafCombatZoneRenameOption:test_a_zone_that_declined_renaming_says_so_to_mist()
  self.z:setRenameUnitsSequentially(false)
  self.z:spawnElement(self.el, true)
  luaunit.assertFalse(self.vars.renameUnitsSequentially)
end

-- A static object goes down the same branch, so the setting has to reach it too.
function TestVeafCombatZoneRenameOption:test_a_static_element_honours_the_setting()
  self.el:setDcsGroup(false)
  self.el:setDcsStatic(true)
  self.z:setRenameUnitsSequentially(false)
  self.z:spawnElement(self.el, true)
  luaunit.assertFalse(self.vars.renameUnitsSequentially)
end

-- Zones are independent: this is a per-zone setting, not a global debug switch, precisely so that
-- nobody has to remember to turn it back on before shipping.
function TestVeafCombatZoneRenameOption:test_one_zone_declining_does_not_affect_another()
  local other = VeafCombatZone:new():setFriendlyName("Other"):setMissionEditorZoneName("OTHERZONE")
  self.z:setRenameUnitsSequentially(false)
  luaunit.assertTrue(other:isRenameUnitsSequentially())
end

-- ============================================================================
-- FIX-COMBATZONE-ZONE-TYPE-SILENT, second pass — Sourcery's review point on #775.
--
-- The helper returned nil for "I cannot read this zone" and the caller wrote `or {}`, so the
-- distinction had no observable effect: an unusable zone still behaved exactly like an empty one. It
-- does something now, and it is the worst symptom the lot named — a zone that cannot say what it holds
-- must not announce that everything in it is dead.
-- ============================================================================
TestVeafCombatZoneUnreadableTriggerZone = {}

function TestVeafCombatZoneUnreadableTriggerZone:setUp()
  self._savedZones = veaf.triggerZones
  veaf.triggerZones = {
    GOODZONE = { name = "GOODZONE", type = 0, x = 0, y = 0, radius = 500 },
    ODDZONE = { name = "ODDZONE", type = 7, x = 0, y = 0 },
  }
  self._savedInZones = mist.getUnitsInZones
  mist.getUnitsInZones = function()
    return {}
  end
  self._savedNames = veaf.getUnitsNamesOfCoalition
  veaf.getUnitsNamesOfCoalition = function()
    return {}
  end
  self._logger = veaf.loggers.get(veafCombatZone.Id)
  self._savedError = self._logger.error
  self._logger.error = function() end
end

function TestVeafCombatZoneUnreadableTriggerZone:tearDown()
  veaf.triggerZones = self._savedZones
  mist.getUnitsInZones = self._savedInZones
  veaf.getUnitsNamesOfCoalition = self._savedNames
  self._logger.error = self._savedError
end

--- A zone standing where `initialize` would have left it: `findUnitsInCombatZone` reads
--- `self.triggerZone`, which `initialize` fills in, so a zone that never went through it returns early
--- and reaches none of the code under test.
local function zoneNamed(name)
  local z = VeafCombatZone:new():setFriendlyName(name):setMissionEditorZoneName(name)
  z.triggerZone = veaf.getTriggerZone(name)
  return z
end

function TestVeafCombatZoneUnreadableTriggerZone:test_a_readable_zone_is_not_flagged()
  local z = zoneNamed("GOODZONE")
  z:findUnitsInCombatZone()
  luaunit.assertFalse(z:hasUnreadableTriggerZone())
  luaunit.assertTrue(z:isCompletable())
end

function TestVeafCombatZoneUnreadableTriggerZone:test_an_unreadable_zone_is_flagged()
  local z = zoneNamed("ODDZONE")
  z:findUnitsInCombatZone()
  luaunit.assertTrue(z:hasUnreadableTriggerZone())
end

-- The point of the whole thing: no completion, so no "all enemies destroyed" for a zone that never
-- knew what it held.
function TestVeafCombatZoneUnreadableTriggerZone:test_an_unreadable_zone_never_completes()
  local z = zoneNamed("ODDZONE")
  luaunit.assertTrue(z:isCompletable(), "before reading the zone, nothing is known")
  z:findUnitsInCombatZone()
  luaunit.assertFalse(z:isCompletable())
end

function TestVeafCombatZoneUnreadableTriggerZone:test_an_unreadable_zone_returns_the_empty_shape()
  -- the two-slot shape callers unpack, so the flag costs nobody a crash
  local z = zoneNamed("ODDZONE")
  local units, groupNames = veaf.safeUnpack(z:findUnitsInCombatZone())
  luaunit.assertEquals(units, {})
  luaunit.assertEquals(groupNames, {})
end

function TestVeafCombatZoneUnreadableTriggerZone:test_a_zone_the_mission_declared_uncompletable_stays_so()
  -- the flag only ever removes completability; it must not hand it back
  local z = zoneNamed("GOODZONE")
  z:setCompletable(false)
  z:findUnitsInCombatZone()
  luaunit.assertFalse(z:isCompletable())
end

function TestVeafCombatZoneUnreadableTriggerZone:test_the_flag_starts_clear()
  luaunit.assertFalse(zoneNamed("GOODZONE"):hasUnreadableTriggerZone())
end

-- ============================================================================
-- FIX-COMBATZONE-SPAWN-ROUTE-OFFSET — a zone dropped a group beside its route
--
-- MiST translates a respawned group's route by the teleport delta only when one of `offsetRoute`,
-- `offsetWP1` or `initTasks` is set (mist.lua:4561). `spawnElement` set none of them, so a group that
-- came up displaced kept a waypoint 1 at its editor position and drove back to it first.
--
-- The choice is `offsetWP1`. The delta is a local random displacement around the drawn position, so
-- `offsetRoute` would move waypoints placed on roads and bridges, and draw a different track on every
-- activation. As with the rename option, the assertions are on the **vars handed to MiST**: the value
-- has to reach the call, not merely exist.
-- ============================================================================
TestVeafCombatZoneSpawnRouteOffset = {}

function TestVeafCombatZoneSpawnRouteOffset:setUp()
  self.z = VeafCombatZone:new():setFriendlyName("Offset Zone"):setMissionEditorZoneName("OFFSETZONE")
  self.z:setActive(true)

  self.el = VeafCombatZoneElement:new()
  self.el:setName("OFFSETZONE-CONVOY")
  self.el:setPosition({ x = 0, y = 0, z = 0 })
  self.el:setCoalition(coalition.side.RED)
  self.el:setDcsGroup(true)

  self._teleport = mist.teleportToPoint
  self.vars = nil
  local this = self
  mist.teleportToPoint = function(vars)
    this.vars = vars
    return nil
  end
end

function TestVeafCombatZoneSpawnRouteOffset:tearDown()
  mist.teleportToPoint = self._teleport
end

function TestVeafCombatZoneSpawnRouteOffset:test_a_spawn_asks_mist_to_move_waypoint_1()
  self.z:spawnElement(self.el, true)
  luaunit.assertNotNil(self.vars, "mist.teleportToPoint must have been called")
  luaunit.assertTrue(self.vars.offsetWP1)
end

-- The decision, pinned. `offsetRoute` would translate every waypoint of a track the mission maker
-- drew on the terrain, and differently on each activation; if someone sets it later it should be
-- because they meant to, not because this line drifted.
function TestVeafCombatZoneSpawnRouteOffset:test_the_rest_of_the_route_is_left_where_it_was_drawn()
  self.z:spawnElement(self.el, true)
  luaunit.assertNil(self.vars.offsetRoute)
  luaunit.assertNil(self.vars.initTasks, "initTasks would delete every waypoint past the first")
end

-- Unconditional on purpose. The delta is not only the dispersion: MiST measures it against the
-- mission table's unit 1, while the element's position comes from the first unit the zone met, so a
-- group met out of editor order carries a delta even with no dispersion at all.
function TestVeafCombatZoneSpawnRouteOffset:test_a_group_with_no_dispersion_still_asks_for_the_offset()
  self.el:setSpawnRadius(0)
  self.z:spawnElement(self.el, true)
  luaunit.assertTrue(self.vars.offsetWP1)
end

function TestVeafCombatZoneSpawnRouteOffset:test_a_dispersed_group_asks_for_the_offset()
  self.el:setSpawnRadius(50)
  self.z:spawnElement(self.el, true)
  luaunit.assertTrue(self.vars.offsetWP1)
end

-- A static goes down the same branch. It has no route to speak of, but the var must not be
-- conditional on the element's kind — a conditional is what would rot.
function TestVeafCombatZoneSpawnRouteOffset:test_a_static_element_takes_the_same_path()
  self.el:setDcsGroup(false)
  self.el:setDcsStatic(true)
  self.z:spawnElement(self.el, true)
  luaunit.assertTrue(self.vars.offsetWP1)
end

-- The vars this lot did not touch must still arrive: this call site is the single place a combat zone
-- respawns anything, and a fix that dropped one of them would be silent.
function TestVeafCombatZoneSpawnRouteOffset:test_the_neighbouring_vars_are_untouched()
  self.z:spawnElement(self.el, true)
  luaunit.assertEquals(self.vars.gpName, "OFFSETZONE-CONVOY")
  luaunit.assertEquals(self.vars.action, "respawn")
  luaunit.assertNotNil(self.vars.point)
  luaunit.assertTrue(self.vars.renameUnitsSequentially)
end

-- ============================================================================
-- FIX-PLACEMENT-IGNORES-SCENERY ticket 02 — a zone element's spawn radius ignored the scenery
--
-- `getSpawnRadius() > 0` drew a raw point and used it unvalidated, so an element could be placed
-- inside a building or a forest in silence. `veaf.placePointOnLand` does not help: it writes the
-- terrain height and nothing else.
--
-- The failure path here is **not** ticket 01's. A zone element is editor content, declared by a
-- mission maker who is not in the room when the mission loads, so when no point is acceptable the
-- element keeps its declared position rather than being skipped — a partially built zone with
-- nobody to read the reason would be worse than an imperfectly placed one. Per ADR 0018 the
-- scenery criterion is quality only, never correctness.
-- ============================================================================
TestVeafCombatZoneSceneryAwareSpawn = {}

function TestVeafCombatZoneSceneryAwareSpawn:setUp()
  self.z = VeafCombatZone:new():setFriendlyName("Scenery Zone"):setMissionEditorZoneName("SCENERYZONE")
  self.z:setActive(true)

  self.el = VeafCombatZoneElement:new()
  self.el:setName("SCENERYZONE-GROUP")
  self.el:setPosition({ x = 0, y = 12, z = 0 })
  self.el:setCoalition(coalition.side.RED)
  self.el:setDcsGroup(true)

  self._teleport = mist.teleportToPoint
  self._savedDisposition = Disposition
  self._savedGetSurfaceType = land.getSurfaceType
  self._savedGetRandPoint = mist.getRandPointInCircle
  self._savedOptOut = veaf.doNotAvoidScenery
  Disposition = nil
  veaf.doNotAvoidScenery = false

  self.vars = nil
  local this = self
  mist.teleportToPoint = function(vars)
    this.vars = vars
    return nil
  end
end

function TestVeafCombatZoneSceneryAwareSpawn:tearDown()
  mist.teleportToPoint = self._teleport
  Disposition = self._savedDisposition
  land.getSurfaceType = self._savedGetSurfaceType
  mist.getRandPointInCircle = self._savedGetRandPoint
  veaf.doNotAvoidScenery = self._savedOptOut
end

function TestVeafCombatZoneSceneryAwareSpawn:_allWater()
  land.getSurfaceType = function()
    return land.SurfaceType.WATER
  end
end

--- Jitter walks the given x offsets, one per call; water is decided by x.
function TestVeafCombatZoneSceneryAwareSpawn:_jitter(xs, waterXs)
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

function TestVeafCombatZoneSceneryAwareSpawn:test_a_water_candidate_is_skipped()
  self.el:setSpawnRadius(1000)
  self:_jitter({ 100, 700 }, { 100 })
  self.z:spawnElement(self.el, true)
  luaunit.assertNotNil(self.vars)
  luaunit.assertEquals(self.vars.point.x, 700, "the water candidate must not become the element's position")
end

function TestVeafCombatZoneSceneryAwareSpawn:test_a_scenery_aware_point_is_used()
  self.el:setSpawnRadius(1000)
  Disposition = {
    getSimpleZones = function()
      return { { x = 420, y = 0, z = 77 } }
    end,
  }
  self:_jitter({ 100 })
  self.z:spawnElement(self.el, true)
  luaunit.assertEquals(self.vars.point.x, 420)
  luaunit.assertEquals(self.vars.point.z, 77)
end

-- The whole point of ticket 02's asymmetry with ticket 01. An unplaceable element still spawns.
function TestVeafCombatZoneSceneryAwareSpawn:test_no_acceptable_point_falls_back_to_the_declared_position()
  self.el:setSpawnRadius(1000)
  self:_allWater()
  self.z:spawnElement(self.el, true)
  luaunit.assertNotNil(self.vars, "an unplaceable element must still be spawned, not skipped")
  luaunit.assertEquals(self.vars.point.x, 0)
  luaunit.assertEquals(self.vars.point.z, 0)
end

-- The vertical is the element's declared one, not the terrain height the search writes. That is
-- today's behaviour and this ticket does not change it.
function TestVeafCombatZoneSceneryAwareSpawn:test_the_declared_altitude_is_kept()
  self.el:setSpawnRadius(1000)
  self:_jitter({ 700 })
  self.z:spawnElement(self.el, true)
  luaunit.assertEquals(self.vars.point.y, 12)
end

function TestVeafCombatZoneSceneryAwareSpawn:test_a_zero_radius_never_consults_the_singleton()
  self.el:setSpawnRadius(0)
  local asked = false
  Disposition = {
    getSimpleZones = function()
      asked = true
      return {}
    end,
  }
  self.z:spawnElement(self.el, true)
  luaunit.assertFalse(asked, "a zero radius means exactly here")
  luaunit.assertEquals(self.vars.point.x, 0)
  luaunit.assertEquals(self.vars.point.z, 0)
end

-- ============================================================================
-- FIX-COMBATZONE-SPAWN-REFERENCE-UNIT — the group's position came from the wrong unit
--
-- A zone's element took its position from the first unit the zone *met*, while MiST measures the
-- teleport delta against the mission table's **unit 1** (`diff = newCoord - newGroupData.units[1]`,
-- mist.lua:4470) and applies it to every unit. When those are not the same unit, the delta carries
-- the group's own intra-group spacing and the whole group is translated by it.
--
-- The trigger is not a `pairs()` lottery — `mist.getUnitsInZones` and `veaf.getUnitsNamesOfCoalition`
-- both preserve order. It is the **filtering**: getUnitsInZones only returns units inside the zone, so
-- a group straddling the zone boundary with its unit 1 outside hands over unit 2 as "the first one".
-- ============================================================================
TestVeafCombatZoneReferenceUnit = {}

--- A unit stub with just what buildGroupElement reads off it.
local function refUnit(name, x, z)
  return {
    getName = function()
      return name
    end,
    getCoalition = function()
      return coalition.side.RED
    end,
    getPosition = function()
      return { p = { x = x, y = 42, z = z } }
    end,
  }
end

function TestVeafCombatZoneReferenceUnit:setUp()
  self.unit1 = refUnit("ALPHA-CONVOY-1", 1000, 2000)
  self.unit2 = refUnit("ALPHA-CONVOY-2", 1030, 2000) -- 30 m down the road, as a convoy is
  self.group = {
    name = "ALPHA-CONVOY",
    isStatic = false,
    units = { self.unit1, self.unit2 },
    unitNames = { "ALPHA-CONVOY-1", "ALPHA-CONVOY-2" },
  }
  self._getByName = Group.getByName
  local this = self
  Group.getByName = function(name)
    if name ~= "ALPHA-CONVOY" then
      return nil
    end
    return {
      getUnit = function(_, index)
        return this.group.units[index]
      end,
    }
  end
end

function TestVeafCombatZoneReferenceUnit:tearDown()
  Group.getByName = self._getByName
end

-- The defect. The zone met unit 2 first because unit 1 sits outside the trigger zone; the element must
-- still be anchored on unit 1, the unit MiST will subtract.
function TestVeafCombatZoneReferenceUnit:test_the_position_comes_from_unit_1_not_the_first_unit_met()
  local element = veafCombatZone.buildGroupElement(self.unit2, self.group, {})
  luaunit.assertEquals(element:getPosition().x, 1000, "anchored on unit 1, not on the first unit met")
  luaunit.assertEquals(element:getPosition().z, 2000)
end

-- The nominal case must not move: when the zone did meet unit 1 first, nothing changes.
function TestVeafCombatZoneReferenceUnit:test_the_nominal_case_is_unchanged()
  local element = veafCombatZone.buildGroupElement(self.unit1, self.group, {})
  luaunit.assertEquals(element:getPosition().x, 1000)
  luaunit.assertEquals(element:getPosition().z, 2000)
end

-- A group DCS cannot hand back falls back on the unit the caller passed, rather than losing its
-- position: a zone with no position spawns at nil, which is worse than spawning 30 m off.
function TestVeafCombatZoneReferenceUnit:test_an_unknown_group_falls_back_on_the_unit_passed()
  Group.getByName = function()
    return nil
  end
  local element = veafCombatZone.buildGroupElement(self.unit2, self.group, {})
  luaunit.assertEquals(element:getPosition().x, 1030)
end

-- Same for a group that exists but hands back no unit 1.
function TestVeafCombatZoneReferenceUnit:test_a_group_with_no_first_unit_falls_back_too()
  Group.getByName = function()
    return {
      getUnit = function()
        return nil
      end,
    }
  end
  local element = veafCombatZone.buildGroupElement(self.unit2, self.group, {})
  luaunit.assertEquals(element:getPosition().x, 1030)
end

-- A static is its own group of one, so there is no reference unit to look up and no Group to ask.
-- It must keep taking the position it was handed.
function TestVeafCombatZoneReferenceUnit:test_a_static_keeps_the_position_it_was_handed()
  local staticGroup = { name = "ALPHA-DEPOT", isStatic = true, units = { self.unit2 }, unitNames = { "ALPHA-DEPOT" } }
  local element = veafCombatZone.buildGroupElement(self.unit2, staticGroup, {})
  luaunit.assertEquals(element:getPosition().x, 1030)
  luaunit.assertTrue(element:isDcsStatic())
end

-- The altitude comes along with the position it was read from, whichever unit that was.
function TestVeafCombatZoneReferenceUnit:test_the_altitude_travels_with_the_position()
  local element = veafCombatZone.buildGroupElement(self.unit2, self.group, {})
  luaunit.assertEquals(element:getPosition().y, 42)
end

-- Everything else buildGroupElement does must be untouched by the position change.
function TestVeafCombatZoneReferenceUnit:test_the_rest_of_the_element_is_unchanged()
  local element = veafCombatZone.buildGroupElement(self.unit2, self.group, {})
  luaunit.assertEquals(element:getName(), "ALPHA-CONVOY")
  luaunit.assertEquals(element:getCoalition(), coalition.side.RED)
  luaunit.assertTrue(element:isDcsGroup())
  luaunit.assertEquals(element:getSpawnRadius(), veafCombatZone.DefaultSpawnRadiusForUnits)
  luaunit.assertEquals(element:getSpawnGroup(), "ALPHA-CONVOY")
end

-- ============================================================================
-- FEAT-INTERPRETER-PARITY ticket 02 — a numeric tag accepts a range
--
-- #25 asked for the randomisable parameters (`veaf.getRandomizableNumeric`) to reach combat-zone
-- elements. They could not even be *written*: `TAG_PATTERNS` captured `(%d+)`, so `#spawnradius=100-300`
-- matched `100` and the `-300` was never seen — the mission maker got the lower bound and no warning.
--
-- Two things are pinned below beyond the feature: that a plain value is untouched, and that widening the
-- pattern did not open a hole. The setters convert with `tonumber`, which returns **nil** on "100-300",
-- and `getSpawnRadius() > 0` on nil raises — so a range reaching a setter unconverted is a crash, not a
-- wrong number.
-- ============================================================================
TestVeafCombatZoneRangeTags = {}

local RANGE_TAGS = {
  { tag = "#spawnradius=100-300", key = "spawnRadius", low = 100, high = 300 },
  { tag = "#spawnchance=20-80", key = "spawnChance", low = 20, high = 80 },
  { tag = "#spawncount=2-5", key = "spawnCount", low = 2, high = 5 },
  { tag = "#spawndelay=30-90", key = "spawnDelay", low = 30, high = 90 },
}

-- parseTags stays a raw reader: it hands back the text, conversion happens where the tag is applied.
function TestVeafCombatZoneRangeTags:test_a_range_is_read_whole_instead_of_truncated()
  for _, t in ipairs(RANGE_TAGS) do
    local tags = veafCombatZone.parseTags("ALPHA " .. t.tag)
    luaunit.assertStrContains(tags[t.key], "-", t.key .. " must keep its range, not just the lower bound")
  end
end

function TestVeafCombatZoneRangeTags:test_a_plain_value_is_unchanged()
  local tags = veafCombatZone.parseTags("ALPHA #spawnradius=200 #spawnchance=50 #spawncount=3 #spawndelay=60")
  luaunit.assertEquals(tags.spawnRadius, "200")
  luaunit.assertEquals(tags.spawnChance, "50")
  luaunit.assertEquals(tags.spawnCount, "3")
  luaunit.assertEquals(tags.spawnDelay, "60")
end

--- Build a one-static element carrying `tagText`, which is the shortest path to applyCollectedTags.
local function elementWithTag(tagText)
  return veafCombatZone.buildGroupElement({
    getCoalition = function()
      return coalition.side.RED
    end,
    getPosition = function()
      return { p = { x = 0, y = 0, z = 0 } }
    end,
    getName = function()
      return "ALPHA-1"
    end,
  }, { name = "ALPHA-1", isStatic = true, units = {}, unitNames = { "ALPHA-1" } }, veafCombatZone.parseTags("ALPHA-1 " .. tagText))
end

-- The one that matters, and it has to be discriminating: asserting "inside the range" passes on the
-- **unfixed** code too, since the truncated lower bound is inside its own range. So the draw is forced
-- to the top of the range — a value of 100 for `100-300` then means the range never reached the
-- converter.
function TestVeafCombatZoneRangeTags:test_the_element_gets_a_value_drawn_from_the_whole_range()
  local saved = veaf.getRandomizableNumeric
  veaf.getRandomizableNumeric = function(val)
    local s = tostring(val)
    local dash = s:find("%-")
    if dash then
      return tonumber(s:sub(dash + 1)) -- always the upper bound, so the assertion is exact
    end
    return tonumber(s)
  end
  local ok, err = pcall(function()
    for _, t in ipairs(RANGE_TAGS) do
      local element = elementWithTag(t.tag)
      local value = ({
        spawnRadius = element:getSpawnRadius(),
        spawnChance = element:getSpawnChance(),
        spawnCount = element:getSpawnCount(),
        spawnDelay = element:getSpawnDelay(),
      })[t.key]
      luaunit.assertEquals(value, t.high, t.key .. ": the whole range must reach the converter")
    end
  end)
  veaf.getRandomizableNumeric = saved
  if not ok then
    error(err, 0)
  end
end

-- And the real converter still yields something usable: a number in range, never nil. A nil here is a
-- crash rather than a wrong value — `getSpawnRadius() > 0` compares it.
function TestVeafCombatZoneRangeTags:test_the_real_converter_yields_a_number_in_range()
  for _, t in ipairs(RANGE_TAGS) do
    local element = elementWithTag(t.tag)
    local value = ({
      spawnRadius = element:getSpawnRadius(),
      spawnChance = element:getSpawnChance(),
      spawnCount = element:getSpawnCount(),
      spawnDelay = element:getSpawnDelay(),
    })[t.key]
    luaunit.assertIsNumber(value, t.key .. " must be a number, not nil")
    luaunit.assertTrue(value >= t.low and value <= t.high, t.key .. " = " .. tostring(value) .. " is outside its range")
  end
end

-- A plain value must survive the same path untouched.
function TestVeafCombatZoneRangeTags:test_a_plain_value_reaches_the_element_unchanged()
  local element = elementWithTag("#spawnradius=200 #spawndelay=60")
  luaunit.assertEquals(element:getSpawnRadius(), 200)
  luaunit.assertEquals(element:getSpawnDelay(), 60)
end

-- An enumeration is not a range. `#alarm=0-2` is a mistake, not a random alarm state, so the tag must
-- not accept it — and the existing out-of-bounds path already tells the mission maker.
function TestVeafCombatZoneRangeTags:test_the_alarm_state_tag_refuses_a_range()
  local tags = veafCombatZone.parseTags("ALPHA #alarm=0-2")
  luaunit.assertNotEquals(tags.alarmState, "0-2", "an alarm state is an enumeration, not a range")
end

-- `spawnGroup` is a name, and names contain dashes: widening the numeric patterns must not have touched it.
function TestVeafCombatZoneRangeTags:test_a_group_name_tag_keeps_its_dashes()
  local tags = veafCombatZone.parseTags('ALPHA #spawngroup="SA-11-BATTERY"')
  luaunit.assertEquals(tags.spawnGroup, "sa-11-battery")
end

-- ============================================================================
-- FEAT-GROUP-COMBAT-INEFFECTIVE ticket 02 — the F10 report adopts the predicate
--
-- The PRD asks for **one** caller to adopt `veaf.isGroupCombatEffective`, and warns that
-- `completionCheck` is "the visible one and therefore the riskiest" — adopting it changes when zones
-- complete, in every existing mission. So the report goes first: it adds information and removes none,
-- and no mission behaviour changes at all.
--
-- The distinction that matters below: a group with nothing left is **destroyed**, not "no longer able to
-- fight". Listing a dead group as out of action would be noise, and the predicate answers false for both.
-- ============================================================================
TestVeafCombatZoneReportEffectiveness = {}

function TestVeafCombatZoneReportEffectiveness:setUp()
  self._getByName = Group.getByName
  self._static = StaticObject.getByName
  self._findUnit = veafUnits.findUnit
  self._effective = veaf.isGroupCombatEffective

  self.z = VeafCombatZone:new():setFriendlyName("Report Zone"):setMissionEditorZoneName("REPORTZONE")
  self.z:setActive(true)
  self.z:setShowZonePositionInfo(false)

  veafUnits.findUnit = function()
    return { vehicle = true }
  end
  StaticObject.getByName = function()
    return nil
  end
end

function TestVeafCombatZoneReportEffectiveness:tearDown()
  Group.getByName = self._getByName
  StaticObject.getByName = self._static
  veafUnits.findUnit = self._findUnit
  veaf.isGroupCombatEffective = self._effective
end

--- Register groups by name, each with `count` living red vehicles.
function TestVeafCombatZoneReportEffectiveness:_groups(spec)
  local registry = {}
  for name, count in pairs(spec) do
    local units = {}
    for i = 1, count do
      table.insert(units, {
        getCoalition = function()
          return 1
        end,
        getTypeName = function()
          return "Ural-375"
        end,
        getName = function()
          return name .. "-" .. i
        end,
        isExist = function()
          return true
        end,
        isActive = function()
          return true
        end,
      })
    end
    registry[name] = {
      getName = function()
        return name
      end,
      isExist = function()
        return true
      end,
      getUnits = function()
        return units
      end,
    }
    self.z:addSpawnedGroup(name)
  end
  Group.getByName = function(n)
    return registry[n]
  end
end

function TestVeafCombatZoneReportEffectiveness:test_an_all_effective_zone_says_nothing_extra()
  self:_groups({ ["REPORTZONE-CONVOY"] = 3 })
  veaf.isGroupCombatEffective = function()
    return true
  end
  local info = self.z:getInformation(nil)
  luaunit.assertNil(info:find("REPORTZONE%-CONVOY"), "an effective group must not be named")
end

function TestVeafCombatZoneReportEffectiveness:test_an_ineffective_group_is_named()
  self:_groups({ ["REPORTZONE-SA10"] = 3 })
  veaf.isGroupCombatEffective = function()
    return false
  end
  local info = self.z:getInformation(nil)
  luaunit.assertNotNil(info:find("REPORTZONE%-SA10"), "the group that can no longer fight must be named")
end

-- The one that keeps the feature honest: a wiped-out group is destroyed, not "out of action". The
-- predicate says false for both, so the report has to tell them apart itself.
function TestVeafCombatZoneReportEffectiveness:test_a_destroyed_group_is_not_reported_as_out_of_action()
  self:_groups({ ["REPORTZONE-DEAD"] = 0 })
  veaf.isGroupCombatEffective = function()
    return false
  end
  local info = self.z:getInformation(nil)
  luaunit.assertNil(info:find("REPORTZONE%-DEAD"), "a group with nothing left is dead, not out of action")
end

function TestVeafCombatZoneReportEffectiveness:test_several_ineffective_groups_are_all_named()
  self:_groups({ ["REPORTZONE-SA10"] = 2, ["REPORTZONE-SA6"] = 2 })
  veaf.isGroupCombatEffective = function()
    return false
  end
  local info = self.z:getInformation(nil)
  luaunit.assertNotNil(info:find("REPORTZONE%-SA10"))
  luaunit.assertNotNil(info:find("REPORTZONE%-SA6"))
end

-- An inactive zone reports nothing about its contents at all, and that must not change.
function TestVeafCombatZoneReportEffectiveness:test_an_inactive_zone_reports_nothing_about_groups()
  self:_groups({ ["REPORTZONE-SA10"] = 2 })
  veaf.isGroupCombatEffective = function()
    return false
  end
  self.z:setActive(false)
  local info = self.z:getInformation(nil)
  luaunit.assertNil(info:find("REPORTZONE%-SA10"))
end

-- ===========================================================================
-- FIX-OPERATION-COMPLETE-SHOWS-ITS-KEY — a briefing must never show a translation key
--
-- Seen in game on the demo mission: a finished operation's briefing ended with the literal text
-- `combatzone.operation_complete`. `getInformation()` was calling `string.format` on the KEY rather than
-- `veaf.t` on it, so the player got the key and the operation's name was dropped — the key has no `%s`,
-- so string.format returns it unchanged and discards the argument.
--
-- Forty lines further down the same constant was used correctly, which is why nobody noticed: the event
-- message was fine, only the briefing was broken.
-- ===========================================================================
TestCombatOperationBriefing = {}

--- An operation that is over: `active` is false by default, which is the branch that was broken.
function TestCombatOperationBriefing:_completedOperation()
  local operation = VeafCombatOperation:new()
  operation.friendlyName = "Operation Gori free"
  operation.briefing = "Destroy the armored group in the city of Gori"
  operation.active = false
  return operation
end

function TestCombatOperationBriefing:test_a_completed_briefing_shows_no_translation_key()
  -- THE defect, stated as what a player must never see.
  local message = self:_completedOperation():getInformation()
  luaunit.assertNil(message:find("combatzone.", 1, true), "a raw translation key reached the player: " .. message)
end

function TestCombatOperationBriefing:test_it_shows_the_translated_sentence()
  local message = self:_completedOperation():getInformation()
  local expected = veaf.t("combatzone.operation_complete", "Operation Gori free")
  luaunit.assertNotNil(message:find(expected, 1, true), "expected [" .. expected .. "] in: " .. message)
end

function TestCombatOperationBriefing:test_it_names_the_operation()
  -- The second half of the same bug: `string.format` on a key with no `%s` silently threw the name away.
  local message = self:_completedOperation():getInformation()
  luaunit.assertNotNil(message:find("Operation Gori free", 1, true), "the operation is not named: " .. message)
end

function TestCombatOperationBriefing:test_an_active_operation_lists_its_tasking_orders_instead()
  -- The other branch, so the fix cannot be "always print the completion sentence".
  local operation = self:_completedOperation()
  operation.active = true
  local message = operation:getInformation()
  luaunit.assertNotNil(message:find("Air Tasking Orders", 1, true), "got: " .. message)
  luaunit.assertNil(message:find("combatzone.", 1, true))
end

function TestCombatOperationBriefing:test_the_briefing_is_still_there()
  -- Guards the tests above: if getInformation ever stopped returning the briefing, they would pass on a
  -- message that lost most of its content.
  local message = self:_completedOperation():getInformation()
  luaunit.assertNotNil(message:find("Destroy the armored group", 1, true))
end

os.exit(luaunit.LuaUnit.run())
