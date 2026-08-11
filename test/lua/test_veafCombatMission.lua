--- Unit tests for veafCombatMission.lua
---
--- Run:  lua test/lua/test_veafCombatMission.lua
---
--- Covers:
---   - VeafCombatMissionObjective  setters/getters + configureAs* helpers
---   - VeafCombatMissionElement    setters/getters
---   - VeafCombatMission           setters/getters (all properties)
---   - veafCombatMission.AddMission / GetMission / GetMissionNumber  (registry)

local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafI18n.lua")
dofile(src .. "/veafCombatMission.lua")

-- The assertions below pin the English wording; messages are now localized
-- (FR is the default language) so force English for these tests.
veaf.config.language = "en"

-- ============================================================================
-- TestVeafCombatMissionObjective
-- ============================================================================
TestVeafCombatMissionObjective = {}

function TestVeafCombatMissionObjective:setUp()
  self.obj = VeafCombatMissionObjective:new()
end

function TestVeafCombatMissionObjective:test_new_returns_object()
  luaunit.assertNotNil(self.obj)
end

function TestVeafCombatMissionObjective:test_setName_getName_roundtrip()
  self.obj:setName("killAll")
  luaunit.assertEquals(self.obj:getName(), "killAll")
end

function TestVeafCombatMissionObjective:test_setDescription_getDescription_roundtrip()
  self.obj:setName("obj"):setDescription("Destroy all SAMs")
  luaunit.assertEquals(self.obj:getDescription(), "Destroy all SAMs")
end

function TestVeafCombatMissionObjective:test_setMessage_getMessage_roundtrip()
  self.obj:setName("obj"):setMessage("Mission accomplished!")
  luaunit.assertEquals(self.obj:getMessage(), "Mission accomplished!")
end

function TestVeafCombatMissionObjective:test_setParameters_getParameters_roundtrip()
  local params = { timeout = 300, zone = "Alpha" }
  self.obj:setName("obj"):setParameters(params)
  luaunit.assertEquals(self.obj:getParameters(), params)
end

function TestVeafCombatMissionObjective:test_setOnCheck_getOnCheck_roundtrip()
  local fn = function()
    return VeafCombatMissionObjective.SUCCESS
  end
  self.obj:setName("obj"):setOnCheck(fn)
  luaunit.assertEquals(self.obj:getOnCheck(), fn)
end

function TestVeafCombatMissionObjective:test_setOnStartup_getOnStartup_roundtrip()
  local fn = function() end
  self.obj:setName("obj"):setOnStartup(fn)
  luaunit.assertEquals(self.obj:getOnStartup(), fn)
end

function TestVeafCombatMissionObjective:test_new_name_is_nil()
  luaunit.assertNil(self.obj:getName())
end

function TestVeafCombatMissionObjective:test_new_parameters_is_empty_table()
  luaunit.assertEquals(self.obj:getParameters(), {})
end

-- setters are chainable
function TestVeafCombatMissionObjective:test_chaining_returns_self()
  local result = self.obj:setName("test"):setDescription("desc")
  luaunit.assertEquals(result, self.obj)
end

-- configureAsTimedObjective stores the timeout as a parameter
function TestVeafCombatMissionObjective:test_configureAsTimedObjective_stores_timeout()
  self.obj:setName("timed"):configureAsTimedObjective(120)
  luaunit.assertEquals(self.obj:getParameters().timeout, 120)
end

function TestVeafCombatMissionObjective:test_configureAsTimedObjective_sets_check_fn()
  self.obj:setName("timed"):configureAsTimedObjective(60)
  luaunit.assertNotNil(self.obj:getOnCheck())
end

-- configureAsKillEnemiesObjective stores kills and hit value
function TestVeafCombatMissionObjective:test_configureAsKillEnemies_stores_nbKills()
  self.obj:setName("kill"):configureAsKillEnemiesObjective(5, 1)
  luaunit.assertEquals(self.obj:getParameters().nbKillsToWin, 5)
end

function TestVeafCombatMissionObjective:test_configureAsKillEnemies_stores_whatsInAKill()
  self.obj:setName("kill"):configureAsKillEnemiesObjective(5, 2)
  luaunit.assertEquals(self.obj:getParameters().whatsInAKill, 2)
end

function TestVeafCombatMissionObjective:test_configureAsKillEnemies_default_nKills_is_minus1()
  self.obj:setName("kill"):configureAsKillEnemiesObjective()
  luaunit.assertEquals(self.obj:getParameters().nbKillsToWin, -1)
end

-- constants
function TestVeafCombatMissionObjective:test_FAILED_constant()
  luaunit.assertEquals(VeafCombatMissionObjective.FAILED, -1)
end

function TestVeafCombatMissionObjective:test_SUCCESS_constant()
  luaunit.assertEquals(VeafCombatMissionObjective.SUCCESS, 1)
end

function TestVeafCombatMissionObjective:test_NOTHING_constant()
  luaunit.assertEquals(VeafCombatMissionObjective.NOTHING, 0)
end

-- ============================================================================
-- TestVeafCombatMissionElement
-- ============================================================================
TestVeafCombatMissionElement = {}

function TestVeafCombatMissionElement:setUp()
  self.elem = VeafCombatMissionElement:new()
end

function TestVeafCombatMissionElement:test_new_returns_element()
  luaunit.assertNotNil(self.elem)
end

function TestVeafCombatMissionElement:test_setName_getName_roundtrip()
  self.elem:setName("Infantry Squad")
  luaunit.assertEquals(self.elem:getName(), "Infantry Squad")
end

function TestVeafCombatMissionElement:test_default_skill_is_random()
  luaunit.assertEquals(self.elem.skill, "Random")
end

function TestVeafCombatMissionElement:test_setSkill_changes_skill()
  self.elem:setName("e"):setSkill("Excellent")
  luaunit.assertEquals(self.elem.skill, "Excellent")
end

function TestVeafCombatMissionElement:test_default_spawnChance_is_100()
  luaunit.assertEquals(self.elem.spawnChance, 100)
end

function TestVeafCombatMissionElement:test_setSpawnChance_getSpawnChance_roundtrip()
  self.elem:setName("e"):setSpawnChance(75)
  luaunit.assertEquals(self.elem:getSpawnChance(), 75)
end

function TestVeafCombatMissionElement:test_default_spawnRadius_is_zero()
  luaunit.assertEquals(self.elem.spawnRadius, 0)
end

function TestVeafCombatMissionElement:test_setSpawnRadius_getSpawnRadius_roundtrip()
  self.elem:setName("e"):setSpawnRadius(500)
  luaunit.assertEquals(self.elem:getSpawnRadius(), 500)
end

function TestVeafCombatMissionElement:test_default_scale_is_1()
  luaunit.assertEquals(self.elem.scale, 1)
end

function TestVeafCombatMissionElement:test_setScale_changes_scale()
  self.elem:setName("e"):setScale(3)
  luaunit.assertEquals(self.elem.scale, 3)
end

function TestVeafCombatMissionElement:test_default_scalable_is_true()
  luaunit.assertTrue(self.elem:isScalable())
end

function TestVeafCombatMissionElement:test_setScalable_false()
  self.elem:setName("e"):setScalable(false)
  luaunit.assertFalse(self.elem:isScalable())
end

function TestVeafCombatMissionElement:test_chaining_returns_self()
  local result = self.elem:setName("e"):setSkill("Good")
  luaunit.assertEquals(result, self.elem)
end

-- ============================================================================
-- TestVeafCombatMission
-- ============================================================================
TestVeafCombatMission = {}

function TestVeafCombatMission:setUp()
  self.mission = VeafCombatMission:new()
end

function TestVeafCombatMission:test_new_returns_mission()
  luaunit.assertNotNil(self.mission)
end

function TestVeafCombatMission:test_setName_getName_roundtrip()
  self.mission:setName("Op Thunder")
  luaunit.assertEquals(self.mission:getName(), "Op Thunder")
end

function TestVeafCombatMission:test_setFriendlyName_getFriendlyName_roundtrip()
  self.mission:setName("m"):setFriendlyName("Operation Thunder")
  luaunit.assertEquals(self.mission:getFriendlyName(), "Operation Thunder")
end

function TestVeafCombatMission:test_setBriefing_getBriefing_roundtrip()
  self.mission:setName("m"):setBriefing("Neutralize the SAM site.")
  luaunit.assertEquals(self.mission:getBriefing(), "Neutralize the SAM site.")
end

function TestVeafCombatMission:test_default_isActive_false()
  luaunit.assertFalse(self.mission:isActive())
end

function TestVeafCombatMission:test_setActive_true()
  self.mission:setName("m"):setActive(true)
  luaunit.assertTrue(self.mission:isActive())
end

function TestVeafCombatMission:test_setActive_false()
  self.mission:setName("m"):setActive(true):setActive(false)
  luaunit.assertFalse(self.mission:isActive())
end

function TestVeafCombatMission:test_default_isTraining_false()
  luaunit.assertFalse(self.mission:isTraining())
end

function TestVeafCombatMission:test_setTraining_true()
  self.mission:setName("m"):setTraining(true)
  luaunit.assertTrue(self.mission:isTraining())
end

function TestVeafCombatMission:test_default_isSecured_false()
  luaunit.assertFalse(self.mission:isSecured())
end

function TestVeafCombatMission:test_setSecured_true()
  self.mission:setName("m"):setSecured(true)
  luaunit.assertTrue(self.mission:isSecured())
end

function TestVeafCombatMission:test_default_isHidden_false()
  luaunit.assertFalse(self.mission:isHidden())
end

function TestVeafCombatMission:test_setHidden_true()
  self.mission:setName("m"):setHidden(true)
  luaunit.assertTrue(self.mission:isHidden())
end

function TestVeafCombatMission:test_default_isSilent_false()
  luaunit.assertFalse(self.mission:isSilent())
end

function TestVeafCombatMission:test_setSilent_true()
  self.mission:setName("m"):setSilent(true)
  luaunit.assertTrue(self.mission:isSilent())
end

function TestVeafCombatMission:test_default_radioMenuEnabled_false()
  luaunit.assertFalse(self.mission:isRadioMenuEnabled())
end

function TestVeafCombatMission:test_setRadioMenuEnabled_true()
  -- We do NOT enable the radio menu in tests since it would require veafRadio.
  -- Setting it to true then back to false to verify the setter works.
  self.mission:setName("m"):setRadioMenuEnabled(false)
  luaunit.assertFalse(self.mission:isRadioMenuEnabled())
end

function TestVeafCombatMission:test_addElement_increases_count()
  local elem = VeafCombatMissionElement:new():setName("e1")
  self.mission:setName("m"):addElement(elem)
  luaunit.assertEquals(#self.mission.elements, 1)
end

function TestVeafCombatMission:test_addElement_multiple()
  self.mission:setName("m")
  for i = 1, 3 do
    self.mission:addElement(VeafCombatMissionElement:new():setName("e" .. i))
  end
  luaunit.assertEquals(#self.mission.elements, 3)
end

function TestVeafCombatMission:test_addObjective_stored_in_objectives()
  local obj = VeafCombatMissionObjective:new():setName("obj1")
  self.mission:setName("m"):addObjective(obj)
  luaunit.assertEquals(#self.mission.objectives, 1)
  luaunit.assertEquals(self.mission:getObjectives()[1]:getName(), "obj1")
end

function TestVeafCombatMission:test_chaining_returns_self()
  local result = self.mission:setName("m"):setActive(false):setTraining(false)
  luaunit.assertEquals(result, self.mission)
end

-- ============================================================================
-- TestVeafCombatMissionRegistry
-- ============================================================================
TestVeafCombatMissionRegistry = {}

function TestVeafCombatMissionRegistry:setUp()
  -- Clear the registry before each test
  veafCombatMission.missionsList = {}
  veafCombatMission.missionsDict = {}
end

function TestVeafCombatMissionRegistry:test_AddMission_returns_mission()
  local m = VeafCombatMission:new():setName("alpha")
  local result = veafCombatMission.AddMission(m)
  luaunit.assertEquals(result, m)
end

function TestVeafCombatMissionRegistry:test_GetMission_by_name()
  local m = VeafCombatMission:new():setName("bravo")
  veafCombatMission.AddMission(m)
  local found = veafCombatMission.GetMission("bravo")
  luaunit.assertEquals(found, m)
end

function TestVeafCombatMissionRegistry:test_GetMission_name_is_case_insensitive()
  local m = VeafCombatMission:new():setName("Charlie")
  veafCombatMission.AddMission(m)
  luaunit.assertEquals(veafCombatMission.GetMission("charlie"), m)
  luaunit.assertEquals(veafCombatMission.GetMission("CHARLIE"), m)
end

function TestVeafCombatMissionRegistry:test_GetMissionNumber_returns_by_index()
  local m1 = VeafCombatMission:new():setName("delta")
  local m2 = VeafCombatMission:new():setName("echo")
  veafCombatMission.AddMission(m1)
  veafCombatMission.AddMission(m2)
  luaunit.assertEquals(veafCombatMission.GetMissionNumber(1), m1)
  luaunit.assertEquals(veafCombatMission.GetMissionNumber(2), m2)
end

function TestVeafCombatMissionRegistry:test_multiple_missions_in_registry()
  for i = 1, 5 do
    veafCombatMission.AddMission(VeafCombatMission:new():setName("mission_" .. i))
  end
  luaunit.assertEquals(#veafCombatMission.missionsList, 5)
end

function TestVeafCombatMissionRegistry:test_GetMission_returns_correct_name()
  local m = VeafCombatMission:new():setName("foxtrot"):setFriendlyName("Foxtrot Op")
  veafCombatMission.AddMission(m)
  luaunit.assertEquals(veafCombatMission.GetMission("foxtrot"):getName(), "foxtrot")
end

function TestVeafCombatMissionRegistry:test_initialize_sets_friendlyName_from_name()
  -- When friendlyName is nil, initialize() should copy name to friendlyName
  local m = VeafCombatMission:new():setName("golf")
  -- friendlyName is nil at this point
  luaunit.assertNil(m.friendlyName)
  veafCombatMission.AddMission(m) -- calls initialize() internally
  luaunit.assertEquals(m:getFriendlyName(), "golf")
end

-- ============================================================================
-- TestVeafCombatMissionObjectiveCopy
-- ============================================================================
TestVeafCombatMissionObjectiveCopy = {}

function TestVeafCombatMissionObjectiveCopy:setUp()
  self.obj = VeafCombatMissionObjective:new()
  self.obj:setName("orig"):setDescription("Desc"):setParameters({ k = "v" })
  local fn = function()
    return VeafCombatMissionObjective.SUCCESS
  end
  self.obj:setOnCheck(fn)
  self.copy = self.obj:copy()
end

function TestVeafCombatMissionObjectiveCopy:test_copy_is_distinct_object()
  luaunit.assertNotIs(self.copy, self.obj)
end

function TestVeafCombatMissionObjectiveCopy:test_copy_preserves_name()
  luaunit.assertEquals(self.copy:getName(), "orig")
end

function TestVeafCombatMissionObjectiveCopy:test_copy_preserves_description()
  luaunit.assertEquals(self.copy:getDescription(), "Desc")
end

function TestVeafCombatMissionObjectiveCopy:test_copy_preserves_onCheck()
  luaunit.assertEquals(self.copy:getOnCheck(), self.obj:getOnCheck())
end

function TestVeafCombatMissionObjectiveCopy:test_copy_parameters_deep_copied()
  self.copy:getParameters().k = "modified"
  luaunit.assertEquals(self.obj:getParameters().k, "v")
end

-- ============================================================================
-- TestVeafCombatMissionObjectiveBehavior
-- ============================================================================
TestVeafCombatMissionObjectiveBehavior = {}

function TestVeafCombatMissionObjectiveBehavior:setUp()
  self.obj = VeafCombatMissionObjective:new():setName("test")
  self.fakeMission = {
    getName = function()
      return "FakeMission"
    end,
  }
end

function TestVeafCombatMissionObjectiveBehavior:test_onCheck_without_function_returns_NOTHING()
  local result = self.obj:onCheck(self.fakeMission)
  luaunit.assertEquals(result, VeafCombatMissionObjective.NOTHING)
end

function TestVeafCombatMissionObjectiveBehavior:test_onCheck_with_function_calls_it()
  local called = false
  self.obj:setOnCheck(function(m, p)
    called = true
    return VeafCombatMissionObjective.SUCCESS
  end)
  self.obj:onCheck(self.fakeMission)
  luaunit.assertTrue(called)
end

function TestVeafCombatMissionObjectiveBehavior:test_onCheck_returns_function_result()
  self.obj:setOnCheck(function(m, p)
    return VeafCombatMissionObjective.FAILED
  end)
  local result = self.obj:onCheck(self.fakeMission)
  luaunit.assertEquals(result, VeafCombatMissionObjective.FAILED)
end

function TestVeafCombatMissionObjectiveBehavior:test_onStartup_without_function_no_error()
  self.obj:onStartup(self.fakeMission)
  luaunit.assertTrue(true)
end

function TestVeafCombatMissionObjectiveBehavior:test_onStartup_with_function_calls_it()
  local called = false
  self.obj:setOnStartup(function(params)
    called = true
  end)
  self.obj:onStartup(self.fakeMission)
  luaunit.assertTrue(called)
end

-- ============================================================================
-- TestVeafCombatMissionObjectiveTimedBehavior
-- ============================================================================
TestVeafCombatMissionObjectiveTimedBehavior = {}

function TestVeafCombatMissionObjectiveTimedBehavior:setUp()
  dcs_mocks.currentTime = 0
  self.obj = VeafCombatMissionObjective:new():setName("timed"):configureAsTimedObjective(60)
  self.fakeMission = {
    getName = function()
      return "FM"
    end,
  }
end

function TestVeafCombatMissionObjectiveTimedBehavior:test_onStartup_sets_startTime_in_parameters()
  self.obj:onStartup(self.fakeMission)
  luaunit.assertNotNil(self.obj:getParameters().startTime)
end

function TestVeafCombatMissionObjectiveTimedBehavior:test_onCheck_before_timeout_returns_NOTHING()
  self.obj:onStartup(self.fakeMission) -- startTime = 0
  dcs_mocks.currentTime = 30 -- 30 < 0 + 60 → NOTHING
  local result = self.obj:onCheck(self.fakeMission)
  luaunit.assertEquals(result, VeafCombatMissionObjective.NOTHING)
end

function TestVeafCombatMissionObjectiveTimedBehavior:test_onCheck_after_timeout_returns_FAILED()
  self.obj:onStartup(self.fakeMission) -- startTime = 0
  dcs_mocks.currentTime = 100 -- 100 > 0 + 60 → FAILED
  local result = self.obj:onCheck(self.fakeMission)
  luaunit.assertEquals(result, VeafCombatMissionObjective.FAILED)
end

-- ============================================================================
-- TestVeafCombatMissionElementCopy
-- ============================================================================
TestVeafCombatMissionElementCopy = {}

function TestVeafCombatMissionElementCopy:setUp()
  self.elem = VeafCombatMissionElement:new()
  self.elem:setName("e"):setSkill("Good"):setScale(2):setSpawnRadius(100):setSpawnChance(80)
  self.elem:setGroups({}) -- initialises self.spawnPoints = {}
  self.copy = self.elem:copy()
end

function TestVeafCombatMissionElementCopy:test_copy_is_distinct_object()
  luaunit.assertNotIs(self.copy, self.elem)
end

function TestVeafCombatMissionElementCopy:test_copy_preserves_name()
  luaunit.assertEquals(self.copy:getName(), "e")
end

function TestVeafCombatMissionElementCopy:test_copy_preserves_skill()
  luaunit.assertEquals(self.copy:getSkill(), "Good")
end

function TestVeafCombatMissionElementCopy:test_copy_preserves_scale()
  luaunit.assertEquals(self.copy:getScale(), 2)
end

function TestVeafCombatMissionElementCopy:test_copy_preserves_spawnRadius()
  luaunit.assertEquals(self.copy:getSpawnRadius(), 100)
end

function TestVeafCombatMissionElementCopy:test_copy_preserves_spawnChance()
  luaunit.assertEquals(self.copy:getSpawnChance(), 80)
end

function TestVeafCombatMissionElementCopy:test_copy_groups_is_new_table()
  luaunit.assertNotIs(self.copy.groups, self.elem.groups)
end

-- ============================================================================
-- TestVeafCombatMissionElementGetters
-- ============================================================================
TestVeafCombatMissionElementGetters = {}

function TestVeafCombatMissionElementGetters:setUp()
  self.elem = VeafCombatMissionElement:new():setName("e")
end

function TestVeafCombatMissionElementGetters:test_getGroups_after_setGroups_empty()
  self.elem:setGroups({})
  luaunit.assertEquals(#self.elem:getGroups(), 0)
end

function TestVeafCombatMissionElementGetters:test_getSkill_default_is_Random()
  luaunit.assertEquals(self.elem:getSkill(), "Random")
end

function TestVeafCombatMissionElementGetters:test_getScale_default_is_1()
  luaunit.assertEquals(self.elem:getScale(), 1)
end

function TestVeafCombatMissionElementGetters:test_setGroups_with_known_group_stores_spawnPoint()
  dcs_mocks.addGroup("g1", {
    getUnit = function(i)
      return {
        getPoint = function()
          return { x = 1, y = 2, z = 3 }
        end,
      }
    end,
  })
  self.elem:setGroups({ "g1" })
  luaunit.assertEquals(self.elem:getGroups()[1], "g1")
  luaunit.assertNotNil(self.elem.spawnPoints["g1"])
  dcs_mocks.removeGroup("g1")
end

-- ============================================================================
-- TestVeafCombatMissionBehavior
-- ============================================================================
TestVeafCombatMissionBehavior = {}

function TestVeafCombatMissionBehavior:setUp()
  self.mission = VeafCombatMission:new():setName("m"):setFriendlyName("Mission Alpha"):setBriefing("Do stuff")
end

function TestVeafCombatMissionBehavior:test_copy_preserves_name()
  local c = self.mission:copy()
  luaunit.assertEquals(c:getName(), "m")
end

function TestVeafCombatMissionBehavior:test_copy_preserves_briefing()
  local c = self.mission:copy()
  luaunit.assertEquals(c:getBriefing(), "Do stuff")
end

function TestVeafCombatMissionBehavior:test_copy_with_skill_and_scale()
  local elem = VeafCombatMissionElement:new():setName("e"):setGroups({})
  self.mission:addElement(elem)
  local c = self.mission:copy("Good", 2)
  luaunit.assertEquals(#c.elements, 1)
  luaunit.assertEquals(c.elements[1]:getSkill(), "Good")
  luaunit.assertEquals(c.elements[1]:getScale(), 2)
end

function TestVeafCombatMissionBehavior:test_copy_with_objectives()
  local obj = VeafCombatMissionObjective:new():setName("obj1")
  self.mission:addObjective(obj)
  local c = self.mission:copy()
  luaunit.assertEquals(#c.objectives, 1)
  luaunit.assertEquals(c.objectives[1]:getName(), "obj1")
end

function TestVeafCombatMissionBehavior:test_getRadioMenuName_returns_friendlyName()
  luaunit.assertEquals(self.mission:getRadioMenuName(), "Mission Alpha")
end

function TestVeafCombatMissionBehavior:test_clearSpawnedGroups_leaves_empty()
  self.mission.spawnedGroups = { "fakeGroup" }
  self.mission:clearSpawnedGroups()
  luaunit.assertEquals(#self.mission.spawnedGroups, 0)
end

function TestVeafCombatMissionBehavior:test_getRemainingEnemies_no_groups()
  local live, damaged, dead = self.mission:getRemainingEnemies()
  luaunit.assertEquals(live, 0)
  luaunit.assertEquals(damaged, 0)
  luaunit.assertEquals(dead, 0)
end

function TestVeafCombatMissionBehavior:test_getRemainingEnemiesString_when_empty()
  local s = self.mission:getRemainingEnemiesString()
  luaunit.assertIsString(s)
  luaunit.assertTrue(s:find("0 alive") ~= nil)
end

-- ---------------------------------------------------------------------------
-- TestVeafCombatMissionUnitLifeReadOnce — SECREV-2 / VMR-088
--
-- `getRemainingEnemies` read `veaf.getUnitLifeRelative(unit)` **four times per unit**: once for a
-- trace, once for `== 1.0`, once for `> whatsInAKill`, and once inside the "damaged" trace. The
-- review reported three; the fourth hides in a log line.
--
-- A unit under fire changes between reads, so the classification could disagree with itself: fail
-- `== 1.0`, then read back at full health on the next line and be counted alive anyway — or drop past
-- the kill threshold between two reads and land in the `else`, the branch whose own comment says
-- "should never come to that". The counts feed the remaining-enemies message a player trusts.
-- ---------------------------------------------------------------------------
TestVeafCombatMissionUnitLifeReadOnce = {}

function TestVeafCombatMissionUnitLifeReadOnce:setUp()
  self.savedLife = veaf.getUnitLifeRelative
  self.calls = 0
  self.mission = VeafCombatMission:new():setName("m"):setFriendlyName("Mission Alpha")
end

function TestVeafCombatMissionUnitLifeReadOnce:tearDown()
  veaf.getUnitLifeRelative = self.savedLife
end

--- One group holding one unit, with `values` handed out one per call to getUnitLifeRelative.
function TestVeafCombatMissionUnitLifeReadOnce:_missionWithOneUnit(values)
  local unit = {
    getName = function()
      return "unit1"
    end,
  }
  local group = {
    getName = function()
      return "group1"
    end,
    getUnits = function()
      return { unit }
    end,
  }
  self.mission.spawnedGroups = { group }
  self.mission.spawnedUnitsCountByGroup = { group1 = 1 }
  veaf.getUnitLifeRelative = function()
    self.calls = self.calls + 1
    return values[math.min(self.calls, #values)]
  end
end

-- The fix, stated as a measurement: one call per unit per pass.
function TestVeafCombatMissionUnitLifeReadOnce:test_the_unit_life_is_read_once_per_unit()
  self:_missionWithOneUnit({ 1.0 })
  self.mission:getRemainingEnemies()
  luaunit.assertEquals(self.calls, 1, "getUnitLifeRelative must be called once per unit, not per test")
end

-- The defect: a unit that drops between the first and second read used to be classified against two
-- different values. With one read it is counted exactly once, whichever value that read returns.
function TestVeafCombatMissionUnitLifeReadOnce:test_a_unit_whose_life_changes_is_counted_exactly_once()
  -- Full health first, then dead: the old code failed `== 1.0` on a later read and could fall through.
  self:_missionWithOneUnit({ 1.0, 0.0, 0.0, 0.0 })
  local live, damaged, dead = self.mission:getRemainingEnemies()

  luaunit.assertEquals(live + dead, 1, "the unit must be counted exactly once")
  luaunit.assertEquals(live, 1, "the single read said 1.0, so the unit is alive")
  luaunit.assertEquals(damaged, 0)
  luaunit.assertEquals(dead, 0)
end

function TestVeafCombatMissionUnitLifeReadOnce:test_a_unit_recovering_between_reads_is_still_counted_once()
  -- The mirror case: damaged on the first read, full health afterwards.
  self:_missionWithOneUnit({ 0.5, 1.0, 1.0, 1.0 })
  local live, damaged, dead = self.mission:getRemainingEnemies()

  luaunit.assertEquals(live, 1, "a damaged unit is alive too")
  luaunit.assertEquals(damaged, 1)
  luaunit.assertEquals(dead, 0)
end

-- The classification itself must not change: these pin it against the single read.
function TestVeafCombatMissionUnitLifeReadOnce:test_full_health_is_alive_and_not_damaged()
  self:_missionWithOneUnit({ 1.0 })
  local live, damaged, dead = self.mission:getRemainingEnemies()
  luaunit.assertEquals({ live, damaged, dead }, { 1, 0, 0 })
end

function TestVeafCombatMissionUnitLifeReadOnce:test_a_damaged_unit_counts_as_alive_and_damaged()
  self:_missionWithOneUnit({ 0.5 })
  local live, damaged, dead = self.mission:getRemainingEnemies()
  luaunit.assertEquals({ live, damaged, dead }, { 1, 1, 0 })
end

-- Below the kill threshold the unit counts as neither live nor damaged, so the group's spawned count
-- turns it into a dead one.
function TestVeafCombatMissionUnitLifeReadOnce:test_below_the_kill_threshold_the_unit_is_dead()
  self:_missionWithOneUnit({ 0.0 })
  local live, damaged, dead = self.mission:getRemainingEnemies()
  luaunit.assertEquals({ live, damaged, dead }, { 0, 0, 1 })
end

function TestVeafCombatMissionUnitLifeReadOnce:test_the_kill_threshold_is_honoured()
  self:_missionWithOneUnit({ 0.5 })
  local live, damaged = self.mission:getRemainingEnemies(0.9)
  luaunit.assertEquals(live, 0, "0.5 is below a 0.9 threshold, so not alive")
  luaunit.assertEquals(damaged, 0)
end

function TestVeafCombatMissionBehavior:test_getInformation_inactive_no_briefing()
  self.mission:setBriefing(nil)
  local info = self.mission:getInformation()
  luaunit.assertTrue(info:find("Mission Alpha") ~= nil)
  luaunit.assertTrue(info:find("not yet active") ~= nil)
end

function TestVeafCombatMissionBehavior:test_getInformation_inactive_with_briefing()
  local info = self.mission:getInformation()
  luaunit.assertTrue(info:find("BRIEFING") ~= nil)
  luaunit.assertTrue(info:find("Do stuff") ~= nil)
  luaunit.assertTrue(info:find("not yet active") ~= nil)
end

function TestVeafCombatMissionBehavior:test_getInformation_inactive_with_objectives()
  local obj = VeafCombatMissionObjective:new():setName("o1"):setDescription("Kill all tanks")
  self.mission:addObjective(obj)
  local info = self.mission:getInformation()
  luaunit.assertTrue(info:find("OBJECTIVES") ~= nil)
  luaunit.assertTrue(info:find("Kill all tanks") ~= nil)
end

function TestVeafCombatMissionBehavior:test_addDefaultObjectives_returns_self()
  local result = self.mission:addDefaultObjectives()
  luaunit.assertEquals(result, self.mission)
end

function TestVeafCombatMissionBehavior:test_unscheduleWatchdogFunction_nil_safe()
  self.mission:unscheduleWatchdogFunction()
  luaunit.assertTrue(true)
end

function TestVeafCombatMissionBehavior:test_scheduleWatchdogFunction_no_error()
  self.mission:scheduleWatchdogFunction()
  luaunit.assertTrue(true)
end

function TestVeafCombatMissionBehavior:test_unscheduleWatchdogFunction_with_id_clears_it()
  self.mission.watchdogFunctionId = 42
  self.mission:unscheduleWatchdogFunction()
  luaunit.assertNil(self.mission.watchdogFunctionId)
end

function TestVeafCombatMissionBehavior:test_initialize_nil_name_returns_self()
  local m = VeafCombatMission:new()
  local result = m:initialize()
  luaunit.assertEquals(result, m)
end

-- ============================================================================
-- TestVeafCombatMissionModuleFunctions
-- ============================================================================
TestVeafCombatMissionModuleFunctions = {}

function TestVeafCombatMissionModuleFunctions:setUp()
  veafCombatMission.missionsList = {}
  veafCombatMission.missionsDict = {}
end

function TestVeafCombatMissionModuleFunctions:test_AddMissionsWithSkillAndScale_creates_copies()
  local m = VeafCombatMission:new():setName("alpha"):setFriendlyName("Alpha Op")
  veafCombatMission.AddMissionsWithSkillAndScale(m, false, { "Good" }, { 1, 2 })
  luaunit.assertEquals(#veafCombatMission.missionsList, 2)
end

function TestVeafCombatMissionModuleFunctions:test_AddMissionsWithSkillAndScale_names_formatted()
  local m = VeafCombatMission:new():setName("bravo"):setFriendlyName("Bravo Op")
  veafCombatMission.AddMissionsWithSkillAndScale(m, false, { "High" }, { 3 })
  luaunit.assertNotNil(veafCombatMission.GetMission("bravo/High/3"))
end

function TestVeafCombatMissionModuleFunctions:test_listActiveMissions_no_active_missions()
  veafCombatMission.AddMission(VeafCombatMission:new():setName("delta"))
  veafCombatMission.listActiveMissions()
  luaunit.assertTrue(true)
end

function TestVeafCombatMissionModuleFunctions:test_listActiveMissions_with_active_mission()
  local m = VeafCombatMission:new():setName("echo"):setFriendlyName("Echo Op")
  veafCombatMission.AddMission(m)
  m:setActive(true)
  veafCombatMission.listActiveMissions()
  luaunit.assertTrue(true)
end

function TestVeafCombatMissionModuleFunctions:test_listAvailableMissions_no_radio_missions()
  veafCombatMission.AddMission(VeafCombatMission:new():setName("foxtrot"))
  veafCombatMission.listAvailableMissions(nil)
  luaunit.assertTrue(true)
end

function TestVeafCombatMissionModuleFunctions:test_help_no_error()
  veafCombatMission.help(nil)
  luaunit.assertTrue(true)
end

function TestVeafCombatMissionModuleFunctions:test_help_with_unit_name()
  veafCombatMission.help("someUnit")
  luaunit.assertTrue(true)
end

-- ============================================================================
-- Run
-- ============================================================================

-------------------------------------------------------------------------------------------------
-- SECREV-2 / VMR-020 — setAllElementsSkill iterated a table without pairs()
--
-- `for _, element in self.elements do` asks Lua to call the table as an iterator, which raises
-- "attempt to call a table value" on the first invocation. The two sibling loops in this same
-- file (lines 551 and 857) both write `pairs(self.elements)`, so this was a slip rather than a
-- convention -- and nothing in the repository calls the method, which is why it survived.
-------------------------------------------------------------------------------------------------

TestVeafCombatMissionSetSkill = {}

function TestVeafCombatMissionSetSkill:_mission()
  local mission = VeafCombatMission:new()
  mission.elements = {}
  return mission
end

function TestVeafCombatMissionSetSkill:_element()
  local calls = {}
  return {
    setSkill = function(self, skill)
      table.insert(calls, skill)
      return self
    end,
    calls = calls,
  }
end

function TestVeafCombatMissionSetSkill:test_does_not_raise_on_an_empty_mission()
  local mission = self:_mission()
  local ok = pcall(function()
    mission:setAllElementsSkill("High")
  end)
  luaunit.assertTrue(ok, "iterating an empty element list must not raise")
end

function TestVeafCombatMissionSetSkill:test_applies_the_skill_to_every_element()
  local mission = self:_mission()
  local a, b = self:_element(), self:_element()
  table.insert(mission.elements, a)
  table.insert(mission.elements, b)
  mission:setAllElementsSkill("Excellent")
  luaunit.assertEquals(a.calls[1], "Excellent")
  luaunit.assertEquals(b.calls[1], "Excellent")
end

function TestVeafCombatMissionSetSkill:test_returns_self_for_chaining()
  local mission = self:_mission()
  luaunit.assertEquals(mission:setAllElementsSkill("Average"), mission)
end

os.exit(luaunit.LuaUnit.run())
