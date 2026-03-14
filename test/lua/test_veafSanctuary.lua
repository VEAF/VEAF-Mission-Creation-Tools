--- Tests for veafSanctuary.lua — VeafSanctuaryZone OOP and constants.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafSanctuary.lua")

-- ---------------------------------------------------------------------------
-- TestVeafSanctuaryConstants
-- ---------------------------------------------------------------------------
TestVeafSanctuaryConstants = {}

function TestVeafSanctuaryConstants:test_id()
  luaunit.assertEquals(veafSanctuary.Id, "SANCTUARY")
end

function TestVeafSanctuaryConstants:test_version()
  luaunit.assertIsString(veafSanctuary.Version)
end

function TestVeafSanctuaryConstants:test_default_delay_warning()
  luaunit.assertEquals(veafSanctuary.DEFAULT_DELAY_WARNING, 0)
end

function TestVeafSanctuaryConstants:test_default_delay_instant()
  luaunit.assertEquals(veafSanctuary.DEFAULT_DELAY_INSTANT, -1)
end

function TestVeafSanctuaryConstants:test_default_delay_spawn()
  luaunit.assertEquals(veafSanctuary.DEFAULT_DELAY_SPAWN, -1)
end

-- ---------------------------------------------------------------------------
-- TestVeafSanctuaryZoneOOP
-- ---------------------------------------------------------------------------
TestVeafSanctuaryZoneOOP = {}

function TestVeafSanctuaryZoneOOP:test_new_returns_table()
  local s = VeafSanctuaryZone:new()
  luaunit.assertIsTable(s)
end

function TestVeafSanctuaryZoneOOP:test_setName_getName()
  local s = VeafSanctuaryZone:new()
  s:setName("safezone1")
  luaunit.assertEquals(s:getName(), "safezone1")
end

function TestVeafSanctuaryZoneOOP:test_setRadius_getRadius()
  local s = VeafSanctuaryZone:new()
  s:setRadius(5000)
  luaunit.assertEquals(s:getRadius(), 5000)
end

function TestVeafSanctuaryZoneOOP:test_setCoalition_getCoalition()
  local s = VeafSanctuaryZone:new()
  s:setCoalition(2)  -- BLUE
  luaunit.assertEquals(s:getCoalition(), 2)
end

function TestVeafSanctuaryZoneOOP:test_setDelayWarning_getDelayWarning()
  local s = VeafSanctuaryZone:new()
  s:setDelayWarning(10)
  luaunit.assertEquals(s:getDelayWarning(), 10)
end

function TestVeafSanctuaryZoneOOP:test_setDelayInstant_getDelayInstant()
  local s = VeafSanctuaryZone:new()
  s:setDelayInstant(5)
  luaunit.assertEquals(s:getDelayInstant(), 5)
end

function TestVeafSanctuaryZoneOOP:test_setDelaySpawn_getDelaySpawn()
  local s = VeafSanctuaryZone:new()
  s:setDelaySpawn(30)
  luaunit.assertEquals(s:getDelaySpawn(), 30)
end

function TestVeafSanctuaryZoneOOP:test_setMessageWarning_getMessageWarning()
  local s = VeafSanctuaryZone:new()
  s:setMessageWarning("Warning: you are entering a sanctuary zone!")
  luaunit.assertEquals(s:getMessageWarning(), "Warning: you are entering a sanctuary zone!")
end

function TestVeafSanctuaryZoneOOP:test_setMessageSpawn_getMessageSpawn()
  local s = VeafSanctuaryZone:new()
  s:setMessageSpawn("Defence spawned!")
  luaunit.assertEquals(s:getMessageSpawn(), "Defence spawned!")
end

function TestVeafSanctuaryZoneOOP:test_setMessageShotTarget_getMessageShotTarget()
  local s = VeafSanctuaryZone:new()
  s:setMessageShotTarget("You were targeted in a sanctuary!")
  luaunit.assertEquals(s:getMessageShotTarget(), "You were targeted in a sanctuary!")
end

function TestVeafSanctuaryZoneOOP:test_setMessageShotLauncher_getMessageShotLauncher()
  local s = VeafSanctuaryZone:new()
  s:setMessageShotLauncher("You fired in a sanctuary!")
  luaunit.assertEquals(s:getMessageShotLauncher(), "You fired in a sanctuary!")
end

function TestVeafSanctuaryZoneOOP:test_setOffensesBeforeDestruction_getOffensesBeforeDestruction()
  local s = VeafSanctuaryZone:new()
  s:setOffensesBeforeDestruction(3)
  luaunit.assertEquals(s:getOffensesBeforeDestruction(), 3)
end

function TestVeafSanctuaryZoneOOP:test_spawnedGroups_initially_empty()
  local s = VeafSanctuaryZone:new()
  local sg = s:getSpawnedGroups()
  luaunit.assertIsTable(sg)
end

function TestVeafSanctuaryZoneOOP:test_addSpawnedGroups()
  local s = VeafSanctuaryZone:new()
  -- addSpawnedGroups takes a table of group name strings
  s:addSpawnedGroups({"group1", "group2"})
  local sg = s:getSpawnedGroups()
  luaunit.assertIsTable(sg)
  luaunit.assertNotNil(sg["group1"])
  luaunit.assertNotNil(sg["group2"])
end

os.exit(luaunit.LuaUnit.run())
