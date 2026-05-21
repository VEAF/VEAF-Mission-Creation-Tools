--- Tests for veafAirWaves.lua — statusToString, constants, AirWaveZone OOP, and FSM.
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

function TestVeafAirWavesConstants:test_status_stop()
  luaunit.assertEquals(veafAirWaves.STATUS_STOP, 0)
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

function TestVeafAirWavesStatusToString:test_stop()
  luaunit.assertEquals(veafAirWaves.statusToString(0), "STATUS_STOP")
end

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

-- ---------------------------------------------------------------------------
-- TestVeafAirWavesFSM
-- ---------------------------------------------------------------------------
TestVeafAirWavesFSM = {}

function TestVeafAirWavesFSM:test_fsm_exists()
  luaunit.assertIsTable(AirWaveZone.FSM)
end

function TestVeafAirWavesFSM:test_fsm_has_all_active_states()
  luaunit.assertNotNil(AirWaveZone.FSM[veafAirWaves.STATUS_READY])
  luaunit.assertNotNil(AirWaveZone.FSM[veafAirWaves.STATUS_WAITING_FOR_MORE_HUMANS])
  luaunit.assertNotNil(AirWaveZone.FSM[veafAirWaves.STATUS_NEXTWAVE])
  luaunit.assertNotNil(AirWaveZone.FSM[veafAirWaves.STATUS_WAITING_FOR_NEXTWAVE])
  luaunit.assertNotNil(AirWaveZone.FSM[veafAirWaves.STATUS_ACTIVE])
  luaunit.assertNotNil(AirWaveZone.FSM[veafAirWaves.STATUS_OVER])
end

function TestVeafAirWavesFSM:test_stop_state_has_no_fsm_entry()
  -- STATUS_STOP is not in the FSM — a stopped zone does nothing in check()
  luaunit.assertNil(AirWaveZone.FSM[veafAirWaves.STATUS_STOP])
end

function TestVeafAirWavesFSM:test_ready_transitions_to_waiting()
  local readyDef = AirWaveZone.FSM[veafAirWaves.STATUS_READY]
  luaunit.assertNotNil(readyDef.transitions[veafAirWaves.STATUS_WAITING_FOR_MORE_HUMANS])
end

-- guard: READY → WAITING_FOR_MORE_HUMANS
function TestVeafAirWavesFSM:test_can_enter_wait_for_humans_with_humans()
  local z = AirWaveZone:new()
  local fake = {}
  luaunit.assertTrue(AirWaveZone._canEnterWaitForMoreHumans(z, { fake }))
end

function TestVeafAirWavesFSM:test_cannot_enter_wait_for_humans_without_humans()
  local z = AirWaveZone:new()
  luaunit.assertFalse(AirWaveZone._canEnterWaitForMoreHumans(z, {}))
end

function TestVeafAirWavesFSM:test_cannot_enter_wait_for_humans_with_nil()
  local z = AirWaveZone:new()
  luaunit.assertFalse(AirWaveZone._canEnterWaitForMoreHumans(z, nil))
end

-- guard: NEXTWAVE → OVER vs WAITING_FOR_NEXTWAVE (mutually exclusive)
function TestVeafAirWavesFSM:test_can_enter_over_when_all_waves_done()
  local z = AirWaveZone:new()
  z.waves = { {}, {} }
  z.currentWaveIndex = 2
  luaunit.assertTrue(AirWaveZone._canEnterOver(z))
  luaunit.assertFalse(AirWaveZone._canEnterWaitForNextWave(z))
end

function TestVeafAirWavesFSM:test_can_enter_wait_for_next_wave_when_more_waves()
  local z = AirWaveZone:new()
  z.waves = { {}, {} }
  z.currentWaveIndex = 1
  luaunit.assertFalse(AirWaveZone._canEnterOver(z))
  luaunit.assertTrue(AirWaveZone._canEnterWaitForNextWave(z))
end

-- guard: WAITING_FOR_NEXTWAVE → ACTIVE
function TestVeafAirWavesFSM:test_can_enter_active_when_timer_expired()
  local z = AirWaveZone:new()
  z.timeOfNextWave = timer.getTime() - 1 -- in the past
  luaunit.assertTrue(AirWaveZone._canEnterActive(z))
end

function TestVeafAirWavesFSM:test_cannot_enter_active_before_timer()
  local z = AirWaveZone:new()
  z.timeOfNextWave = timer.getTime() + 100 -- in the future
  luaunit.assertFalse(AirWaveZone._canEnterActive(z))
end

function TestVeafAirWavesFSM:test_cannot_enter_active_without_timer()
  local z = AirWaveZone:new()
  z.timeOfNextWave = nil
  luaunit.assertFalse(AirWaveZone._canEnterActive(z))
end

-- guard: ACTIVE → NEXTWAVE (wave dead)
function TestVeafAirWavesFSM:test_can_exit_active_when_wave_dead()
  local z = AirWaveZone:new()
  z.spawnedGroupsNames = {} -- empty = no live enemies
  z.currentWaveIndex = 1
  luaunit.assertTrue(AirWaveZone._canExitActive(z))
end

-- enter WAITING_FOR_MORE_HUMANS stores humans and sets activation timer
function TestVeafAirWavesFSM:test_on_enter_wait_stores_humans_and_sets_timer()
  local z = AirWaveZone:new()
  z:setDelayBeforeActivation(0)
  local humans = { "p1" }
  local names = { "p1" }
  AirWaveZone._onEnterWaitForMoreHumans(z, humans, names)
  luaunit.assertEquals(z.unitsInZone, humans)
  luaunit.assertEquals(z.playerUnitsNames, names)
  luaunit.assertNotNil(z.timeOfActivation)
end

-- exit WAITING_FOR_MORE_HUMANS resets wave counter
function TestVeafAirWavesFSM:test_on_exit_wait_resets_wave_index()
  local z = AirWaveZone:new()
  z.currentWaveIndex = 5
  AirWaveZone._onExitWaitForMoreHumans(z, {}, {})
  luaunit.assertEquals(z.currentWaveIndex, 0)
end

-- enter WAITING_FOR_NEXTWAVE sets the wave timer
function TestVeafAirWavesFSM:test_on_enter_wait_for_next_wave_sets_timer()
  local z = AirWaveZone:new()
  z.delayBetweenWaves = 10
  z:setSilent(true)
  AirWaveZone._onEnterWaitForNextWave(z)
  luaunit.assertNotNil(z.timeOfNextWave)
end

os.exit(luaunit.LuaUnit.run())

