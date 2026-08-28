--- Tests for veafAirWaves.lua — statusToString, constants, AirWaveZone OOP, and FSM.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafMissionDb.lua")
dofile(src .. "/veafAirWaves.lua")

-- ---------------------------------------------------------------------------
-- TestVeafAirWavesConstants
-- ---------------------------------------------------------------------------
TestVeafAirWavesConstants = {}

function TestVeafAirWavesConstants:test_id()
  luaunit.assertIsString(veafAirWaves.Id)
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

-- ---------------------------------------------------------------------------
-- TestAirWaveZoneSetters
-- ---------------------------------------------------------------------------
TestAirWaveZoneSetters = {}

function TestAirWaveZoneSetters:test_setZoneCenter()
  local z = AirWaveZone:new()
  z:setZoneCenter({ x = 1, y = 2 })
  luaunit.assertEquals(z.zoneCenter, { x = 1, y = 2 })
end

function TestAirWaveZoneSetters:test_setTriggerZone_existing_sets_center_and_radius()
  veaf.triggerZones["Z"] = { x = 10, y = 20, radius = 500 }
  local z = AirWaveZone:new()
  z:setTriggerZone("Z")
  luaunit.assertEquals(z.triggerZoneName, "Z")
  luaunit.assertEquals(z.zoneCenter, { x = 10, y = 20 })
  luaunit.assertEquals(z.zoneRadius, 500)
  veaf.triggerZones["Z"] = nil
end

function TestAirWaveZoneSetters:test_setTriggerZone_missing_keeps_existing_center()
  local z = AirWaveZone:new()
  z:setZoneCenter({ x = 1, y = 2 })
  -- trigger zone does not exist, but a center is already configured:
  -- the trigger zone is optional, the existing center must be preserved.
  z:setTriggerZone("DoesNotExist")
  luaunit.assertEquals(z.triggerZoneName, "DoesNotExist")
  luaunit.assertEquals(z.zoneCenter, { x = 1, y = 2 })
end

function TestAirWaveZoneSetters:test_setTriggerZone_missing_without_center_leaves_center_nil()
  local z = AirWaveZone:new()
  z:setTriggerZone("DoesNotExist")
  luaunit.assertEquals(z.triggerZoneName, "DoesNotExist")
  luaunit.assertNil(z.zoneCenter)
end

function TestAirWaveZoneSetters:test_setDrawZone_true()
  local z = AirWaveZone:new()
  z:setDrawZone(true)
  luaunit.assertTrue(z.drawZone)
end

function TestAirWaveZoneSetters:test_setDrawZone_false()
  local z = AirWaveZone:new()
  z:setDrawZone(false)
  luaunit.assertFalse(z.drawZone)
end

function TestAirWaveZoneSetters:test_setMessageWaitForHumans()
  local z = AirWaveZone:new()
  z:setMessageWaitForHumans("waiting...")
  luaunit.assertEquals(z.messageWaitForHumans, "waiting...")
end

function TestAirWaveZoneSetters:test_setOnStart_stored()
  local z = AirWaveZone:new()
  local cb = function() end
  z:setOnStart(cb)
  luaunit.assertEquals(z.onStart, cb)
end

function TestAirWaveZoneSetters:test_setOnStart_returns_self()
  local z = AirWaveZone:new()
  local result = z:setOnStart(function() end)
  luaunit.assertEquals(result, z)
end

function TestAirWaveZoneSetters:test_setOnWaitForHumans()
  local z = AirWaveZone:new()
  local cb = function() end
  z:setOnWaitForHumans(cb)
  luaunit.assertEquals(z.onWaitForHumans, cb)
end

function TestAirWaveZoneSetters:test_setMessageWaitToDeploy()
  local z = AirWaveZone:new()
  z:setMessageWaitToDeploy("deploying soon")
  luaunit.assertEquals(z.messageWaitToDeploy, "deploying soon")
end

function TestAirWaveZoneSetters:test_setOnWaitToDeploy()
  local z = AirWaveZone:new()
  local cb = function() end
  z:setOnWaitToDeploy(cb)
  luaunit.assertEquals(z.onWaitToDeploy, cb)
end

function TestAirWaveZoneSetters:test_setMessageDeploy()
  local z = AirWaveZone:new()
  z:setMessageDeploy("deploying %s")
  luaunit.assertEquals(z.messageDeploy, "deploying %s")
end

function TestAirWaveZoneSetters:test_setMessageDeployPlayers()
  local z = AirWaveZone:new()
  z:setMessageDeployPlayers("wave %s")
  luaunit.assertEquals(z.messageDeployPlayers, "wave %s")
end

function TestAirWaveZoneSetters:test_setOnDeploy()
  local z = AirWaveZone:new()
  local cb = function() end
  z:setOnDeploy(cb)
  luaunit.assertEquals(z.onDeploy, cb)
end

function TestAirWaveZoneSetters:test_setMessageDestroyed()
  local z = AirWaveZone:new()
  z:setMessageDestroyed("destroyed!")
  luaunit.assertEquals(z.messageDestroyed, "destroyed!")
end

function TestAirWaveZoneSetters:test_setOnDestroyed()
  local z = AirWaveZone:new()
  local cb = function() end
  z:setOnDestroyed(cb)
  luaunit.assertEquals(z.onDestroyed, cb)
end

function TestAirWaveZoneSetters:test_setMessageOutsideOfZone()
  local z = AirWaveZone:new()
  z:setMessageOutsideOfZone("you're out!")
  luaunit.assertEquals(z.messageOutsideOfZone, "you're out!")
end

function TestAirWaveZoneSetters:test_setOnOutsideOfZone()
  local z = AirWaveZone:new()
  local cb = function() end
  z:setOnOutsideOfZone(cb)
  luaunit.assertEquals(z.onOutsideOfZone, cb)
end

function TestAirWaveZoneSetters:test_setOnWon()
  local z = AirWaveZone:new()
  local cb = function() end
  z:setOnWon(cb)
  luaunit.assertEquals(z.onWon, cb)
end

function TestAirWaveZoneSetters:test_setOnLost()
  local z = AirWaveZone:new()
  local cb = function() end
  z:setOnLost(cb)
  luaunit.assertEquals(z.onLost, cb)
end

function TestAirWaveZoneSetters:test_setMessageStop()
  local z = AirWaveZone:new()
  z:setMessageStop("offline")
  luaunit.assertEquals(z.messageStop, "offline")
end

function TestAirWaveZoneSetters:test_setOnStop()
  local z = AirWaveZone:new()
  local cb = function() end
  z:setOnStop(cb)
  luaunit.assertEquals(z.onStop, cb)
end

function TestAirWaveZoneSetters:test_setRespawnRadius_normal()
  local z = AirWaveZone:new()
  z:setRespawnRadius(1000)
  luaunit.assertEquals(z.respawnRadius, 1000)
end

function TestAirWaveZoneSetters:test_setRespawnRadius_clamped_below_250()
  local z = AirWaveZone:new()
  z:setRespawnRadius(100)
  luaunit.assertEquals(z.respawnRadius, 250)
end

function TestAirWaveZoneSetters:test_setRespawnDefaultOffset()
  local z = AirWaveZone:new()
  z:setRespawnDefaultOffset(500, 300)
  luaunit.assertEquals(z.respawnDefaultOffset.latDelta, 500)
  luaunit.assertEquals(z.respawnDefaultOffset.lonDelta, 300)
end

function TestAirWaveZoneSetters:test_addPlayerCoalition()
  local z = AirWaveZone:new()
  z:addPlayerCoalition(coalition.side.BLUE)
  luaunit.assertEquals(z.playerCoalitions[coalition.side.BLUE], coalition.side.BLUE)
end

function TestAirWaveZoneSetters:test_getPlayerCoalition_empty()
  local z = AirWaveZone:new()
  luaunit.assertNil(z:getPlayerCoalition())
end

function TestAirWaveZoneSetters:test_getPlayerCoalition_with_coalition()
  local z = AirWaveZone:new()
  z:addPlayerCoalition(coalition.side.RED)
  luaunit.assertEquals(z:getPlayerCoalition(), coalition.side.RED)
end

function TestAirWaveZoneSetters:test_setMinimumAltitudeInFeet_converts()
  local z = AirWaveZone:new()
  z:setMinimumAltitudeInFeet(1000)
  luaunit.assertAlmostEquals(z.minimumAltitude, 1000 * 0.3048, 0.001)
end

function TestAirWaveZoneSetters:test_setMaximumAltitudeInFeet_converts()
  local z = AirWaveZone:new()
  z:setMaximumAltitudeInFeet(2000)
  luaunit.assertAlmostEquals(z.maximumAltitude, 2000 * 0.3048, 0.001)
end

function TestAirWaveZoneSetters:test_setMaxSecondsOutsideOfZoneIA()
  local z = AirWaveZone:new()
  z:setMaxSecondsOutsideOfZoneIA(60)
  luaunit.assertEquals(z.maxSecondsOutsideOfZoneIA, 60)
end

function TestAirWaveZoneSetters:test_disableOutsideOfZoneIA()
  local z = AirWaveZone:new()
  z:disableOutsideOfZoneIA()
  luaunit.assertNil(z.maxSecondsOutsideOfZoneIA)
end

function TestAirWaveZoneSetters:test_setMaxSecondsOutsideOfZonePlayers()
  local z = AirWaveZone:new()
  z:setMaxSecondsOutsideOfZonePlayers(45)
  luaunit.assertEquals(z.maxSecondsOutsideOfZonePlayers, 45)
end

function TestAirWaveZoneSetters:test_disableOutsideOfZonePlayers()
  local z = AirWaveZone:new()
  z:setMaxSecondsOutsideOfZonePlayers(45)
  z:disableOutsideOfZonePlayers()
  luaunit.assertNil(z.maxSecondsOutsideOfZonePlayers)
end

function TestAirWaveZoneSetters:test_setMinimumLifeForAiInPercent()
  local z = AirWaveZone:new()
  z:setMinimumLifeForAiInPercent(20)
  luaunit.assertEquals(z.minimumLifeForAiInPercent, 20)
end

function TestAirWaveZoneSetters:test_setIsEnemyWaveDeadCallback()
  local z = AirWaveZone:new()
  local cb = function()
    return true
  end
  z:setIsEnemyWaveDeadCallback(cb)
  luaunit.assertEquals(z.isEnemyWaveDeadCallback, cb)
end

function TestAirWaveZoneSetters:test_setIsEnemyGroupDeadCallback()
  local z = AirWaveZone:new()
  local cb = function()
    return true
  end
  z:setIsEnemyGroupDeadCallback(cb)
  luaunit.assertEquals(z.isEnemyGroupDeadCallback, cb)
end

function TestAirWaveZoneSetters:test_setHandleCrippledEnemyUnitCallback()
  local z = AirWaveZone:new()
  local cb = function() end
  z:setHandleCrippledEnemyUnitCallback(cb)
  luaunit.assertEquals(z.handleCrippledEnemyUnitCallback, cb)
end

function TestAirWaveZoneSetters:test_setState()
  local z = AirWaveZone:new()
  z:_setState(veafAirWaves.STATUS_ACTIVE)
  luaunit.assertEquals(z.state, veafAirWaves.STATUS_ACTIVE)
end

-- ---------------------------------------------------------------------------
-- TestAirWaveZoneAddWave
-- ---------------------------------------------------------------------------
TestAirWaveZoneAddWave = {}

function TestAirWaveZoneAddWave:test_addWave_single_string()
  local z = AirWaveZone:new()
  z:addWave("group1")
  luaunit.assertEquals(#z.waves, 1)
  luaunit.assertEquals(z.waves[1].groups[1], "group1")
end

function TestAirWaveZoneAddWave:test_addWave_two_strings()
  local z = AirWaveZone:new()
  z:addWave("group1", "group2")
  luaunit.assertEquals(#z.waves, 1)
  luaunit.assertEquals(#z.waves[1].groups, 2)
end

function TestAirWaveZoneAddWave:test_addWave_table_with_groups_string()
  local z = AirWaveZone:new()
  z:addWave({ groups = "group1", number = 2, bias = 0 })
  luaunit.assertEquals(z.waves[1].groups[1], "group1")
  luaunit.assertEquals(z.waves[1].number, 2)
end

function TestAirWaveZoneAddWave:test_addWave_table_with_groups_array()
  local z = AirWaveZone:new()
  z:addWave({ groups = { "g1", "g2" }, number = 3, bias = 1, delay = 10 })
  luaunit.assertEquals(z.waves[1].groups, { "g1", "g2" })
  luaunit.assertEquals(z.waves[1].number, 3)
  luaunit.assertEquals(z.waves[1].delay, 10)
end

-- SECREV-008: a plain array of strings (no `groups` key) must insert each
-- element, not the whole parameter table.
function TestAirWaveZoneAddWave:test_addWave_plain_array_of_strings()
  local z = AirWaveZone:new()
  z:addWave({ "g1", "g2" })
  luaunit.assertEquals(z.waves[1].groups, { "g1", "g2" })
end

function TestAirWaveZoneAddWave:test_addWave_no_args_does_nothing()
  local z = AirWaveZone:new()
  z:addWave()
  luaunit.assertEquals(#z.waves, 0)
end

function TestAirWaveZoneAddWave:test_addWave_returns_self()
  local z = AirWaveZone:new()
  local result = z:addWave("g1")
  luaunit.assertEquals(result, z)
end

function TestAirWaveZoneAddWave:test_resetWaves_clears_table()
  local z = AirWaveZone:new()
  z:addWave("g1"):addWave("g2")
  luaunit.assertEquals(#z.waves, 2)
  z:resetWaves()
  luaunit.assertEquals(#z.waves, 0)
end

-- ---------------------------------------------------------------------------
-- TestAirWaveZoneSignals
-- ---------------------------------------------------------------------------
TestAirWaveZoneSignals = {}

function TestAirWaveZoneSignals:test_signalToPlayers_empty_units()
  local z = AirWaveZone:new()
  -- unitsInZone = {} by default; should not crash
  z:signalToPlayers("hello")
end

function TestAirWaveZoneSignals:test_signalStart_silent()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  z:signalStart()
end

function TestAirWaveZoneSignals:test_signalStart_non_silent_empty_coalitions()
  local z = AirWaveZone:new()
  z.name = "TestZone"
  -- playerCoalitions = {} → no trigger.action calls
  z:signalStart()
end

function TestAirWaveZoneSignals:test_signalStart_callback_fires()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  local fired = false
  z:setOnStart(function()
    fired = true
  end)
  z:signalStart()
  luaunit.assertTrue(fired)
end

function TestAirWaveZoneSignals:test_signalWaitForHumans_silent()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  z:signalWaitForHumans()
end

function TestAirWaveZoneSignals:test_signalWaitForHumans_callback_fires()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  local fired = false
  z:setOnWaitForHumans(function()
    fired = true
  end)
  z:signalWaitForHumans()
  luaunit.assertTrue(fired)
end

function TestAirWaveZoneSignals:test_signalWaitToDeploy_silent()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  z.delayBeforeNextWave = 10
  z:signalWaitToDeploy()
end

function TestAirWaveZoneSignals:test_signalWaitToDeploy_callback_fires()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  z.delayBeforeNextWave = 10
  local fired = false
  z:setOnWaitToDeploy(function()
    fired = true
  end)
  z:signalWaitToDeploy()
  luaunit.assertTrue(fired)
end

function TestAirWaveZoneSignals:test_signalDeploy_silent()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  z:signalDeploy()
end

function TestAirWaveZoneSignals:test_signalDeploy_non_silent_empty_coalitions()
  -- playerCoalitions = {} → for loop runs 0 times, no crash
  -- unitsInZone = {} → inner loop runs 0 times, no crash
  -- spawnedGroupsNames = {} → BRAA loop runs 0 times, no crash
  local z = AirWaveZone:new()
  z.name = "TestZone"
  z:signalDeploy()
end

function TestAirWaveZoneSignals:test_signalDeploy_callback_fires()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  local fired = false
  z:setOnDeploy(function()
    fired = true
  end)
  z:signalDeploy()
  luaunit.assertTrue(fired)
end

function TestAirWaveZoneSignals:test_signalDestroyed_silent()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  z:signalDestroyed()
end

function TestAirWaveZoneSignals:test_signalDestroyed_callback_fires()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  local fired = false
  z:setOnDestroyed(function()
    fired = true
  end)
  z:signalDestroyed()
  luaunit.assertTrue(fired)
end

function TestAirWaveZoneSignals:test_signalOutsideOfZone_silent()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  z:signalOutsideOfZone("unit1", 10)
end

function TestAirWaveZoneSignals:test_signalOutsideOfZone_callback_fires()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  local firedUnit, firedSecs
  z:setOnOutsideOfZone(function(_, unit, secs)
    firedUnit = unit
    firedSecs = secs
  end)
  z:signalOutsideOfZone("unit1", 10)
  luaunit.assertEquals(firedUnit, "unit1")
  luaunit.assertEquals(firedSecs, 10)
end

function TestAirWaveZoneSignals:test_signalWon_silent()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  z:signalWon()
end

function TestAirWaveZoneSignals:test_signalWon_non_silent()
  local z = AirWaveZone:new()
  z.name = "TestZone"
  -- playerCoalitions = {} → 0 iterations in the for loop
  -- signalToPlayers with empty unitsInZone → 0 iterations
  z:signalWon()
end

function TestAirWaveZoneSignals:test_signalWon_callback_fires()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  local fired = false
  z:setOnWon(function()
    fired = true
  end)
  z:signalWon()
  luaunit.assertTrue(fired)
end

function TestAirWaveZoneSignals:test_signalLost_silent()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  z:signalLost()
end

function TestAirWaveZoneSignals:test_signalLost_callback_fires()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  local fired = false
  z:setOnLost(function()
    fired = true
  end)
  z:signalLost()
  luaunit.assertTrue(fired)
end

function TestAirWaveZoneSignals:test_signalStop_silent()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  z:signalStop()
end

function TestAirWaveZoneSignals:test_signalStop_callback_fires()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  local fired = false
  z:setOnStop(function()
    fired = true
  end)
  z:signalStop()
  luaunit.assertTrue(fired)
end

-- ---------------------------------------------------------------------------
-- TestAirWaveZoneReset
-- ---------------------------------------------------------------------------
TestAirWaveZoneReset = {}

function TestAirWaveZoneReset:test_destroyCurrentWave_empty_spawned_groups()
  local z = AirWaveZone:new()
  -- spawnedGroupsNames = {} by default
  z:destroyCurrentWave()
  luaunit.assertEquals(z.spawnedGroupsNames, {})
end

function TestAirWaveZoneReset:test_destroyCurrentWave_with_unknown_group()
  local z = AirWaveZone:new()
  z.spawnedGroupsNames = { "no_such_group" }
  -- Group.getByName returns nil for unknown groups → no crash
  z:destroyCurrentWave()
  luaunit.assertEquals(z.spawnedGroupsNames, {})
end

function TestAirWaveZoneReset:test_reset_clears_state_fields()
  local z = AirWaveZone:new()
  z.currentWaveIndex = 5
  z.timeOfActivation = 999
  z.delayBeforeNextWave = 30
  z:reset()
  luaunit.assertEquals(z.currentWaveIndex, 0)
  luaunit.assertNil(z.timeOfActivation)
  luaunit.assertNil(z.delayBeforeNextWave)
end

function TestAirWaveZoneReset:test_reset_clears_spawned_groups()
  local z = AirWaveZone:new()
  z.spawnedGroupsNames = { "g1", "g2" }
  z:reset()
  luaunit.assertEquals(z.spawnedGroupsNames, {})
end

function TestAirWaveZoneReset:test_reset_removes_check_function_schedule()
  local z = AirWaveZone:new()
  -- veaf.removeFunction is a no-op mock; just verify no crash
  z.checkFunctionSchedule = 42
  z:reset()
  luaunit.assertNil(z.checkFunctionSchedule)
end

-- ---------------------------------------------------------------------------
-- TestAirWaveZoneFSMExtended
-- ---------------------------------------------------------------------------
TestAirWaveZoneFSMExtended = {}

function TestAirWaveZoneFSMExtended:test_canEnterNextWave_false_future_activation()
  local z = AirWaveZone:new()
  z.timeOfActivation = timer.getTime() + 100
  luaunit.assertFalse(AirWaveZone._canEnterNextWave(z, { {} }))
end

function TestAirWaveZoneFSMExtended:test_canEnterNextWave_false_nil_activation()
  local z = AirWaveZone:new()
  z.timeOfActivation = nil
  luaunit.assertFalse(AirWaveZone._canEnterNextWave(z, { {} }))
end

function TestAirWaveZoneFSMExtended:test_canEnterNextWave_true()
  local z = AirWaveZone:new()
  z.timeOfActivation = timer.getTime() - 1
  luaunit.assertTrue(AirWaveZone._canEnterNextWave(z, { {} }))
end

function TestAirWaveZoneFSMExtended:test_tickActive_early_return_when_ia_disabled()
  local z = AirWaveZone:new()
  z:disableOutsideOfZoneIA()
  -- spawnedGroupsNames has a group but IA check disabled → no Group.getByName call
  z.spawnedGroupsNames = { "some_group" }
  AirWaveZone._tickActive(z) -- should return immediately without crashing
end

function TestAirWaveZoneFSMExtended:test_onExitActive_destroys_and_signals_destroyed()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  local destroyed_cb_fired = false
  z:setOnDestroyed(function()
    destroyed_cb_fired = true
  end)
  AirWaveZone._onExitActive(z)
  luaunit.assertTrue(destroyed_cb_fired)
end

function TestAirWaveZoneFSMExtended:test_onEnterOver_fires_won()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  local won_fired = false
  z:setOnWon(function()
    won_fired = true
  end)
  AirWaveZone._onEnterOver(z)
  luaunit.assertTrue(won_fired)
end

function TestAirWaveZoneFSMExtended:test_onEnterWaitForNextWave_preset_delay_not_overwritten()
  local z = AirWaveZone:new()
  z:setSilent(true)
  z.name = "TestZone"
  z.delayBeforeNextWave = 15 -- already set
  AirWaveZone._onEnterWaitForNextWave(z)
  luaunit.assertEquals(z.delayBeforeNextWave, 15)
end

-- ---------------------------------------------------------------------------
-- TestAirWavesModuleFunctions
-- ---------------------------------------------------------------------------
TestAirWavesModuleFunctions = {}

function TestAirWavesModuleFunctions:test_add_and_get_by_zone_name()
  local z = AirWaveZone:new()
  z.name = "moduleTestZone"
  veafAirWaves.add(z)
  luaunit.assertEquals(veafAirWaves.get("moduleTestZone"), z)
end

function TestAirWavesModuleFunctions:test_add_with_explicit_name()
  local z = AirWaveZone:new()
  z.name = "originalName"
  veafAirWaves.add(z, "explicitName")
  luaunit.assertEquals(veafAirWaves.get("explicitName"), z)
end

function TestAirWavesModuleFunctions:test_get_nonexistent_returns_nil()
  luaunit.assertNil(veafAirWaves.get("no_such_zone_xyzzy"))
end

-------------------------------------------------------------------------------------------------
-- SECREV-2 / VMR-085 — a trigger zone name that names nothing must not take deployWaves down
--
-- `setTriggerZone` is deliberately lenient: when a center is already configured it keeps it and
-- only warns (see test_setTriggerZone_missing_keeps_existing_center above). But it stores the
-- name anyway, so `deployWaves` saw a `triggerZoneName`, called `veaf.getTriggerZone` on it,
-- got nil and indexed it. That leniency is what makes the crash reachable: the mission maker
-- gets a warning at configuration time and a raise at the first wave.
--
-- `AirWaveZone:check()` already has the right shape — trigger zone, else center, else complain —
-- so this aligns deployWaves with its neighbour rather than inventing a rule.
-------------------------------------------------------------------------------------------------

TestSecrev2AirWavesZoneCenter = {}

function TestSecrev2AirWavesZoneCenter:setUp()
  dcs_mocks.reset()
  self.deployed = {}
  self._savedExecute = veafInterpreter and veafInterpreter.execute
end

function TestSecrev2AirWavesZoneCenter:tearDown()
  veaf.triggerZones["AirWaveZoneThatExists"] = nil
  if veafInterpreter then
    veafInterpreter.execute = self._savedExecute
  end
end

--- A zone that will deploy one VEAF command, recording the position it is given.
function TestSecrev2AirWavesZoneCenter:_zoneDeployingOneCommand()
  local z = AirWaveZone:new()
  z.currentWaveIndex = 0
  z.waves = { {} }
  z.chooseGroupsToDeploy = function(_)
    return { "-shilka" }, nil
  end
  local positions = self.deployed
  veafInterpreter = veafInterpreter or {}
  veafInterpreter.execute = function(command, position, _, _, _)
    table.insert(positions, { command = command, position = position })
  end
  return z
end

function TestSecrev2AirWavesZoneCenter:test_a_missing_trigger_zone_falls_back_to_the_center()
  local z = self:_zoneDeployingOneCommand()
  -- A DCS vec3, which is what `setZoneCenter(vec3)` is documented to take and what
  -- `setZoneCenterFromCoordinates` produces through coord.LLtoLO.
  z:setZoneCenter({ x = 1000, y = 0, z = 2000 })
  z:setTriggerZone("NoSuchTriggerZone")
  local ok, err = pcall(function()
    z:deployWaves()
  end)
  luaunit.assertTrue(ok, "a trigger zone that does not exist must not raise at deploy time: " .. tostring(err))
  luaunit.assertEquals(#self.deployed, 1)
end

function TestSecrev2AirWavesZoneCenter:test_an_existing_trigger_zone_is_still_preferred()
  -- The control: the fallback must not shadow a zone that does exist.
  veaf.triggerZones["AirWaveZoneThatExists"] = { x = 77, y = 88, radius = 500 }
  local z = self:_zoneDeployingOneCommand()
  -- A DCS vec3, which is what `setZoneCenter(vec3)` is documented to take and what
  -- `setZoneCenterFromCoordinates` produces through coord.LLtoLO.
  z:setZoneCenter({ x = 1000, y = 0, z = 2000 })
  z:setTriggerZone("AirWaveZoneThatExists")
  z:deployWaves()
  luaunit.assertEquals(#self.deployed, 1)
  -- The trigger zone's coordinates, not the 1000/2000 centre set just before.
  luaunit.assertEquals(self.deployed[1].position.x, 77)
  -- The easting arrives as `y`, not `z`, and that is a **defect** rather than a convention:
  -- `veafAirWaves` hands this point straight to `veafInterpreter.execute`, which documents that a
  -- command expects a vec3 whose `z` is the easting — and `veafSpawnGround` reads `spawnPosition.z`.
  -- So a command-driven air wave spawns with a nil easting. The sibling call twenty lines further
  -- down converts explicitly (`vars.point.z = vars.point.y`); this one does not.
  --
  -- It was invisible until DROP-MIST ticket 06, because the MiST stub in dcs_mocks answered a vec3
  -- while MiST itself answers a vec2 — the test was asserting the mock. Asserted here as it actually
  -- behaves, so the defect stays visible until FIX-AIRWAVES-COMMAND-EASTING fixes it; that lot flips
  -- these two assertions.
  luaunit.assertEquals(self.deployed[1].position.y, 88, "the easting lands in y — see FIX-AIRWAVES-COMMAND-EASTING")
  luaunit.assertNil(self.deployed[1].position.z, "and z is left nil, which is what reaches the spawn")
end

function TestSecrev2AirWavesZoneCenter:test_neither_zone_nor_center_does_not_raise()
  local z = self:_zoneDeployingOneCommand()
  z:setTriggerZone("NoSuchTriggerZone")
  local ok = pcall(function()
    z:deployWaves()
  end)
  luaunit.assertTrue(ok, "a zone with no usable position must complain, not raise")
end

os.exit(luaunit.LuaUnit.run())
