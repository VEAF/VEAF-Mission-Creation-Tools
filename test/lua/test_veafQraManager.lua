--- Tests for veafQraManager.lua — statusToString, ToggleAllSilence, VeafQRA OOP.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafQraManager.lua")

-- ---------------------------------------------------------------------------
-- TestVeafQraManagerConstants
-- ---------------------------------------------------------------------------
TestVeafQraManagerConstants = {}

function TestVeafQraManagerConstants:test_id()
  luaunit.assertEquals(veafQraManager.Id, "QRA")
end

function TestVeafQraManagerConstants:test_version()
  luaunit.assertIsString(veafQraManager.Version)
end

function TestVeafQraManagerConstants:test_status_willrearm()
  luaunit.assertEquals(veafQraManager.STATUS_WILLREARM, 0)
end

function TestVeafQraManagerConstants:test_status_ready()
  luaunit.assertEquals(veafQraManager.STATUS_READY, 1)
end

function TestVeafQraManagerConstants:test_status_ready_waitingformore()
  luaunit.assertEquals(veafQraManager.STATUS_READY_WAITINGFORMORE, 1.5)
end

function TestVeafQraManagerConstants:test_status_active()
  luaunit.assertEquals(veafQraManager.STATUS_ACTIVE, 2)
end

function TestVeafQraManagerConstants:test_status_dead()
  luaunit.assertEquals(veafQraManager.STATUS_DEAD, 3)
end

-- ---------------------------------------------------------------------------
-- TestVeafQraManagerStatusToString
-- ---------------------------------------------------------------------------
TestVeafQraManagerStatusToString = {}

function TestVeafQraManagerStatusToString:test_willrearm()
  luaunit.assertEquals(veafQraManager.statusToString(0), "STATUS_WILLREARM")
end

function TestVeafQraManagerStatusToString:test_ready()
  luaunit.assertEquals(veafQraManager.statusToString(1), "STATUS_READY")
end

function TestVeafQraManagerStatusToString:test_ready_waitingformore()
  luaunit.assertEquals(veafQraManager.statusToString(1.5), "STATUS_READY_WAITINGFORMORE")
end

function TestVeafQraManagerStatusToString:test_active()
  luaunit.assertEquals(veafQraManager.statusToString(2), "STATUS_ACTIVE")
end

function TestVeafQraManagerStatusToString:test_dead()
  luaunit.assertEquals(veafQraManager.statusToString(3), "STATUS_DEAD")
end

function TestVeafQraManagerStatusToString:test_unknown_returns_empty()
  luaunit.assertEquals(veafQraManager.statusToString(99), "")
end

-- ---------------------------------------------------------------------------
-- TestVeafQraManagerToggleAllSilence
-- ---------------------------------------------------------------------------
TestVeafQraManagerToggleAllSilence = {}

function TestVeafQraManagerToggleAllSilence:test_toggle_true()
  VeafQRA.ToggleAllSilence(true)
  luaunit.assertTrue(veafQraManager.AllSilence)
end

function TestVeafQraManagerToggleAllSilence:test_toggle_false()
  VeafQRA.ToggleAllSilence(false)
  luaunit.assertFalse(veafQraManager.AllSilence)
end

-- ---------------------------------------------------------------------------
-- TestVeafQraOOP
-- ---------------------------------------------------------------------------
TestVeafQraOOP = {}

function TestVeafQraOOP:test_new_returns_table()
  local q = VeafQRA:new()
  luaunit.assertIsTable(q)
end

function TestVeafQraOOP:test_setDescription_getDescription()
  local q = VeafQRA:new()
  q:setDescription("Test QRA")
  luaunit.assertEquals(q:getDescription(), "Test QRA")
end

function TestVeafQraOOP:test_getName_before_setName_nil_or_string()
  local q = VeafQRA:new()
  -- getName may return nil or empty string before name is set
  local n = q:getName()
  luaunit.assertTrue(n == nil or type(n) == "string")
end

function TestVeafQraOOP:test_name_direct_assignment()
  local q = VeafQRA:new()
  q.name = "myQRA"
  luaunit.assertEquals(q:getName(), "myQRA")
end

function TestVeafQraOOP:test_setCoalition()
  local q = VeafQRA:new()
  q:setCoalition(1)  -- RED
  luaunit.assertEquals(q.coalition, 1)
end

function TestVeafQraOOP:test_setSilent()
  local q = VeafQRA:new()
  q:setSilent(true)
  luaunit.assertTrue(q.silent)
end

function TestVeafQraOOP:test_setSilent_false()
  local q = VeafQRA:new()
  q:setSilent(true)
  q:setSilent(false)
  luaunit.assertFalse(q.silent)
end

function TestVeafQraOOP:test_setZoneRadius()
  local q = VeafQRA:new()
  q:setZoneRadius(5000)
  luaunit.assertEquals(q.zoneRadius, 5000)
end

function TestVeafQraOOP:test_setMessageStart()
  local q = VeafQRA:new()
  q:setMessageStart("QRA on the way!")
  luaunit.assertEquals(q.messageStart, "QRA on the way!")
end

function TestVeafQraOOP:test_setMessageReady()
  local q = VeafQRA:new()
  q:setMessageReady("QRA ready")
  luaunit.assertEquals(q.messageReady, "QRA ready")
end

function TestVeafQraOOP:test_addEnnemyCoalition()
  local q = VeafQRA:new()
  q:addEnnemyCoalition(2)
  luaunit.assertEquals(q:getEnnemyCoalition(), 2)
end

function TestVeafQraOOP:test_setDelayBeforeRearming()
  local q = VeafQRA:new()
  q:setDelayBeforeRearming(120)
  luaunit.assertEquals(q.delayBeforeRearming, 120)
end

function TestVeafQraOOP:test_setQRAmaxCount()
  local q = VeafQRA:new()
  q:setQRAmaxCount(3)
  luaunit.assertEquals(q.QRAmaxCount, 3)
end

os.exit(luaunit.LuaUnit.run())
