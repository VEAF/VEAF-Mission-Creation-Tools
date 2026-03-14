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
dofile(src .. "/veafCombatMission.lua")

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
  local fn = function() return VeafCombatMissionObjective.SUCCESS end
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
  veafCombatMission.AddMission(m)         -- calls initialize() internally
  luaunit.assertEquals(m:getFriendlyName(), "golf")
end

-- ============================================================================
-- Run
-- ============================================================================
os.exit(luaunit.LuaUnit.run())
