--- Tests for veafAirWaves.lua — statusToString, constants, AirWaveZone OOP.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafAirWaves.lua")

-- ---------------------------------------------------------------------------
-- TestVeafAirWavesConstants
-- ---------------------------------------------------------------------------
TestVeafAirWavesConstants = {}

function TestVeafAirWavesConstants:test_id()
  luaunit.assertIsString(veafAirWaves.Id)
end

function TestVeafAirWavesConstants:test_version()
  luaunit.assertIsString(veafAirWaves.Version)
end

function TestVeafAirWavesConstants:test_status_ready()
  luaunit.assertEquals(veafAirWaves.STATUS_READY, 1)
end

function TestVeafAirWavesConstants:test_status_waiting_for_more_humans()
  luaunit.assertEquals(veafAirWaves.STATUS_WAITING_FOR_MORE_HUMANS, 1.5)
end

function TestVeafAirWavesConstants:test_status_active()
  luaunit.assertEquals(veafAirWaves.STATUS_ACTIVE, 2)
end

function TestVeafAirWavesConstants:test_status_waiting_for_nextwave()
  luaunit.assertEquals(veafAirWaves.STATUS_WAITING_FOR_NEXTWAVE, 2.5)
end

function TestVeafAirWavesConstants:test_status_nextwave()
  luaunit.assertEquals(veafAirWaves.STATUS_NEXTWAVE, 3)
end

function TestVeafAirWavesConstants:test_status_over()
  luaunit.assertEquals(veafAirWaves.STATUS_OVER, 4)
end

function TestVeafAirWavesConstants:test_minimum_life_for_ai()
  luaunit.assertEquals(veafAirWaves.MINIMUM_LIFE_FOR_AI_IN_PERCENT, 0)
end

function TestVeafAirWavesConstants:test_watchdog_delay()
  luaunit.assertEquals(veafAirWaves.WATCHDOG_DELAY, 1)
end

function TestVeafAirWavesConstants:test_default_message_start()
  luaunit.assertIsString(veafAirWaves.DEFAULT_MESSAGE_START)
end

-- ---------------------------------------------------------------------------
-- TestVeafAirWavesStatusToString
-- ---------------------------------------------------------------------------
TestVeafAirWavesStatusToString = {}

function TestVeafAirWavesStatusToString:test_ready()
  luaunit.assertEquals(veafAirWaves.statusToString(1), "STATUS_READY")
end

function TestVeafAirWavesStatusToString:test_waiting_for_more_humans()
  luaunit.assertEquals(veafAirWaves.statusToString(1.5), "STATUS_WAITING_FOR_MORE_HUMANS")
end

function TestVeafAirWavesStatusToString:test_active()
  luaunit.assertEquals(veafAirWaves.statusToString(2), "STATUS_ACTIVE")
end

function TestVeafAirWavesStatusToString:test_waiting_for_nextwave()
  luaunit.assertEquals(veafAirWaves.statusToString(2.5), "STATUS_WAITING_FOR_NEXTWAVE")
end

function TestVeafAirWavesStatusToString:test_nextwave()
  luaunit.assertEquals(veafAirWaves.statusToString(3), "STATUS_NEXTWAVE")
end

function TestVeafAirWavesStatusToString:test_over()
  luaunit.assertEquals(veafAirWaves.statusToString(4), "STATUS_OVER")
end

function TestVeafAirWavesStatusToString:test_unknown_returns_empty()
  luaunit.assertEquals(veafAirWaves.statusToString(99), "")
end

-- ---------------------------------------------------------------------------
-- TestVeafAirWaveZoneOOP
-- ---------------------------------------------------------------------------
TestVeafAirWaveZoneOOP = {}

function TestVeafAirWaveZoneOOP:test_new_returns_table()
  local z = AirWaveZone:new()
  luaunit.assertIsTable(z)
end

function TestVeafAirWaveZoneOOP:test_setSilent()
  local z = AirWaveZone:new()
  z:setSilent(true)
  luaunit.assertTrue(z.silent)
end

function TestVeafAirWaveZoneOOP:test_setSilent_false()
  local z = AirWaveZone:new()
  z:setSilent(false)
  luaunit.assertFalse(z.silent)
end

function TestVeafAirWaveZoneOOP:test_setResetWhenDying()
  local z = AirWaveZone:new()
  z:setResetWhenDying(true)
  luaunit.assertTrue(z.resetWhenDying)
end

function TestVeafAirWaveZoneOOP:test_setDelayBetweenWaves()
  local z = AirWaveZone:new()
  z:setDelayBetweenWaves(30)
  luaunit.assertEquals(z.delayBetweenWaves, 30)
end

function TestVeafAirWaveZoneOOP:test_setDelayBeforeActivation()
  local z = AirWaveZone:new()
  z:setDelayBeforeActivation(60)
  luaunit.assertEquals(z.delayBeforeActivation, 60)
end

function TestVeafAirWaveZoneOOP:test_setDescription_getDescription()
  local z = AirWaveZone:new()
  z:setDescription("Test zone")
  luaunit.assertEquals(z:getDescription(), "Test zone")
end

function TestVeafAirWaveZoneOOP:test_setZoneRadius()
  local z = AirWaveZone:new()
  z:setZoneRadius(10000)
  luaunit.assertEquals(z.zoneRadius, 10000)
end

function TestVeafAirWaveZoneOOP:test_setMessageStart()
  local z = AirWaveZone:new()
  z:setMessageStart("Wave starting!")
  luaunit.assertEquals(z.messageStart, "Wave starting!")
end

function TestVeafAirWaveZoneOOP:test_setMessageWon()
  local z = AirWaveZone:new()
  z:setMessageWon("You won!")
  luaunit.assertEquals(z.messageWon, "You won!")
end

function TestVeafAirWaveZoneOOP:test_setMessageLost()
  local z = AirWaveZone:new()
  z:setMessageLost("You lost!")
  luaunit.assertEquals(z.messageLost, "You lost!")
end

function TestVeafAirWaveZoneOOP:test_name_field()
  local z = AirWaveZone:new()
  z.name = "myZone"
  luaunit.assertEquals(z:getName(), "myZone")
end

os.exit(luaunit.LuaUnit.run())
