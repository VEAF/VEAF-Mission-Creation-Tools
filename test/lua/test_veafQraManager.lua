--- Tests for veafQraManager.lua — statusToString, ToggleAllSilence, VeafQRA OOP.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafMissionDb.lua")
dofile(src .. "/veafDcsSpawner.lua")
dofile(src .. "/veafQraManager.lua")

-- ---------------------------------------------------------------------------
-- TestVeafQraManagerConstants
-- ---------------------------------------------------------------------------
TestVeafQraManagerConstants = {}

function TestVeafQraManagerConstants:test_id()
  luaunit.assertEquals(veafQraManager.Id, "QRA")
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
  q:setCoalition(1) -- RED
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
  luaunit.assertEquals(q.logistics.QRAmaxCount, 3)
end

-- ---------------------------------------------------------------------------
-- TestVeafQraLifecycle — state-machine transitions
-- ---------------------------------------------------------------------------
TestVeafQraLifecycle = {}

function TestVeafQraLifecycle:setUp()
  dcs_mocks.reset()
end

local function _newSilentQRA()
  local q = VeafQRA:new()
  q:setSilent(true) -- suppress outText calls
  q:addEnnemyCoalition(coalition.side.BLUE)
  -- provide a minimal zone so check() doesn't error
  q.zoneCenter = { x = 0, y = 0, z = 0 }
  q.zoneRadius = 10000
  return q
end

function TestVeafQraLifecycle:test_start_sets_state_ready()
  local q = _newSilentQRA()
  q:start()
  luaunit.assertEquals(q.state, veafQraManager.STATUS_READY)
end

function TestVeafQraLifecycle:test_rearm_after_dead_sets_state_ready()
  local q = _newSilentQRA()
  q.state = veafQraManager.STATUS_DEAD
  q:rearm()
  luaunit.assertEquals(q.state, veafQraManager.STATUS_READY)
end

function TestVeafQraLifecycle:test_destroyed_sets_state_dead()
  local q = _newSilentQRA()
  q.state = veafQraManager.STATUS_ACTIVE
  q:destroyed()
  luaunit.assertEquals(q.state, veafQraManager.STATUS_DEAD)
end

function TestVeafQraLifecycle:test_stop_schedules_stop_state()
  local q = _newSilentQRA()
  q:start()
  q:stop(true) -- silent=true
  luaunit.assertEquals(q.scheduled_state, veafQraManager.STATUS_STOP)
end

function TestVeafQraLifecycle:test_destroyed_decrements_QRAcount()
  local q = _newSilentQRA()
  q:setQRAcount(2)
  q:destroyed()
  luaunit.assertEquals(q.logistics.QRAcount, 1)
end

function TestVeafQraLifecycle:test_destroyed_QRAcount_not_below_zero()
  local q = _newSilentQRA()
  q:setQRAcount(0)
  q:destroyed()
  luaunit.assertEquals(q.logistics.QRAcount, 0)
end

function TestVeafQraLifecycle:test_onStart_callback_called()
  local called = false
  local q = _newSilentQRA()
  q:setOnStart(function()
    called = true
  end)
  q:start()
  luaunit.assertTrue(called)
end

function TestVeafQraLifecycle:test_onReady_callback_called()
  local called = false
  local q = _newSilentQRA()
  q:setOnReady(function()
    called = true
  end)
  q:rearm()
  luaunit.assertTrue(called)
end

function TestVeafQraLifecycle:test_onDestroyed_callback_called()
  local called = false
  local q = _newSilentQRA()
  q:setOnDestroyed(function()
    called = true
  end)
  q:destroyed()
  luaunit.assertTrue(called)
end

-- ---------------------------------------------------------------------------
-- TestVeafQraUnit — Unit.getByName via dcs_mocks.addUnit
-- ---------------------------------------------------------------------------
TestVeafQraUnit = {}

function TestVeafQraUnit:setUp()
  dcs_mocks.reset()
end

function TestVeafQraUnit:test_addUnit_returns_mock()
  dcs_mocks.addUnit("F-16_01", { coalition = coalition.side.BLUE })
  local u = Unit.getByName("F-16_01")
  luaunit.assertNotNil(u)
  luaunit.assertEquals(u.name, "F-16_01")
end

function TestVeafQraUnit:test_addGroup_returns_mock()
  dcs_mocks.addGroup("Blue_CAP_1")
  local g = Group.getByName("Blue_CAP_1")
  luaunit.assertNotNil(g)
  luaunit.assertEquals(g.name, "Blue_CAP_1")
end

function TestVeafQraUnit:test_removeUnit_returns_nil()
  dcs_mocks.addUnit("F-16_02")
  dcs_mocks.removeUnit("F-16_02")
  luaunit.assertNil(Unit.getByName("F-16_02"))
end

function TestVeafQraUnit:test_reset_clears_registries()
  dcs_mocks.addUnit("F-16_03")
  dcs_mocks.addGroup("Blue_CAP_2")
  dcs_mocks.reset()
  luaunit.assertNil(Unit.getByName("F-16_03"))
  luaunit.assertNil(Group.getByName("Blue_CAP_2"))
end

-- ---------------------------------------------------------------------------
-- TestVeafQraCoreSetters — verifies setters on VeafQRACore
-- ---------------------------------------------------------------------------
TestVeafQraCoreSetters = {}

function TestVeafQraCoreSetters:setUp()
  dcs_mocks.reset()
end

function TestVeafQraCoreSetters:test_setName_sets_name()
  local q = VeafQRA:new()
  q:setName("MyQRA")
  luaunit.assertEquals(q.name, "MyQRA")
end

function TestVeafQraCoreSetters:test_setTriggerZone()
  local q = VeafQRA:new():setName("Q")
  q:setTriggerZone("MyZone")
  luaunit.assertEquals(q.triggerZoneName, "MyZone")
end

function TestVeafQraCoreSetters:test_setZoneCenter()
  local q = VeafQRA:new():setName("Q")
  local center = { x = 100, y = 0, z = 200 }
  q:setZoneCenter(center)
  luaunit.assertEquals(q.zoneCenter, center)
end

function TestVeafQraCoreSetters:test_setZoneCenterFromCoordinates()
  local q = VeafQRA:new():setName("Q")
  q:setZoneCenterFromCoordinates("41.8 N, 41.7 E")
  luaunit.assertNotNil(q.zoneCenter)
end

function TestVeafQraCoreSetters:test_addGroup_creates_bucket()
  local q = VeafQRA:new():setName("Q")
  q:addGroup("F-16 Group")
  luaunit.assertNotNil(q.groupsToDeployByEnemyQuantity[1])
end

function TestVeafQraCoreSetters:test_addGroup_inserts_into_bucket()
  local q = VeafQRA:new():setName("Q")
  q:addGroup("F-16 Group")
  q:addGroup("F-18 Group")
  luaunit.assertEquals(#q.groupsToDeployByEnemyQuantity[1], 2)
end

function TestVeafQraCoreSetters:test_addRandomGroup()
  local q = VeafQRA:new():setName("Q")
  q:addRandomGroup({ "F-16A", "F-16B" }, 1, 0)
  luaunit.assertNotNil(q.groupsToDeployByEnemyQuantity[1])
end

function TestVeafQraCoreSetters:test_setGroupsToDeployByEnemyQuantity()
  local q = VeafQRA:new():setName("Q")
  q:setGroupsToDeployByEnemyQuantity(2, { "Grp1" })
  luaunit.assertNotNil(q.groupsToDeployByEnemyQuantity[2])
end

function TestVeafQraCoreSetters:test_setRandomGroupsToDeployByEnemyQuantity()
  local q = VeafQRA:new():setName("Q")
  q:setRandomGroupsToDeployByEnemyQuantity(3, { "Grp1", "Grp2" }, 1, 0)
  luaunit.assertNotNil(q.groupsToDeployByEnemyQuantity[3])
end

function TestVeafQraCoreSetters:test_setMessageDeploy()
  local q = VeafQRA:new():setName("Q")
  q:setMessageDeploy("QRA on the way: %s")
  luaunit.assertEquals(q.messageDeploy, "QRA on the way: %s")
end

function TestVeafQraCoreSetters:test_setOnDeploy()
  local q = VeafQRA:new():setName("Q")
  local cb = function() end
  q:setOnDeploy(cb)
  luaunit.assertEquals(q.onDeploy, cb)
end

function TestVeafQraCoreSetters:test_setMessageOut()
  local q = VeafQRA:new():setName("Q")
  q:setMessageOut("QRA out: %s")
  luaunit.assertEquals(q.messageOut, "QRA out: %s")
end

function TestVeafQraCoreSetters:test_setOnOut()
  local q = VeafQRA:new():setName("Q")
  local cb = function() end
  q:setOnOut(cb)
  luaunit.assertEquals(q.onOut, cb)
end

function TestVeafQraCoreSetters:test_setMessageResupplied()
  local q = VeafQRA:new():setName("Q")
  q:setMessageResupplied("QRA resupplied: %s")
  luaunit.assertEquals(q.messageResupplied, "QRA resupplied: %s")
end

function TestVeafQraCoreSetters:test_setOnResupplied()
  local q = VeafQRA:new():setName("Q")
  local cb = function() end
  q:setOnResupplied(cb)
  luaunit.assertEquals(q.onResupplied, cb)
end

function TestVeafQraCoreSetters:test_setMessageAirbaseDown()
  local q = VeafQRA:new():setName("Q")
  q:setMessageAirbaseDown("Airbase down: %s")
  luaunit.assertEquals(q.messageAirbaseDown, "Airbase down: %s")
end

function TestVeafQraCoreSetters:test_setOnAirbaseDown()
  local q = VeafQRA:new():setName("Q")
  local cb = function() end
  q:setOnAirbaseDown(cb)
  luaunit.assertEquals(q.onAirbaseDown, cb)
end

function TestVeafQraCoreSetters:test_setMessageAirbaseUp()
  local q = VeafQRA:new():setName("Q")
  q:setMessageAirbaseUp("Airbase up: %s")
  luaunit.assertEquals(q.messageAirbaseUp, "Airbase up: %s")
end

function TestVeafQraCoreSetters:test_setOnAirbaseUp()
  local q = VeafQRA:new():setName("Q")
  local cb = function() end
  q:setOnAirbaseUp(cb)
  luaunit.assertEquals(q.onAirbaseUp, cb)
end

function TestVeafQraCoreSetters:test_setMessageStop()
  local q = VeafQRA:new():setName("Q")
  q:setMessageStop("QRA stopped: %s")
  luaunit.assertEquals(q.messageStop, "QRA stopped: %s")
end

function TestVeafQraCoreSetters:test_setOnStop()
  local q = VeafQRA:new():setName("Q")
  local cb = function() end
  q:setOnStop(cb)
  luaunit.assertEquals(q.onStop, cb)
end

function TestVeafQraCoreSetters:test_setDrawZone()
  local q = VeafQRA:new():setName("Q")
  q:setDrawZone(true)
  luaunit.assertTrue(q.drawZone)
end

function TestVeafQraCoreSetters:test_setReactOnHelicopters()
  local q = VeafQRA:new():setName("Q")
  q:setReactOnHelicopters()
  luaunit.assertTrue(q.reactOnHelicopters)
end

function TestVeafQraCoreSetters:test_setRespawnDefaultOffset()
  local q = VeafQRA:new():setName("Q")
  q:setRespawnDefaultOffset(500, 100)
  luaunit.assertNotNil(q.respawnDefaultOffset)
end

function TestVeafQraCoreSetters:test_setRespawnRadius_normal()
  local q = VeafQRA:new():setName("Q")
  q:setRespawnRadius(500)
  luaunit.assertEquals(q.respawnRadius, 500)
end

function TestVeafQraCoreSetters:test_setRespawnRadius_clamped_to_250()
  local q = VeafQRA:new():setName("Q")
  q:setRespawnRadius(100)
  luaunit.assertEquals(q.respawnRadius, 250)
end

function TestVeafQraCoreSetters:test_setDelayBeforeActivating()
  local q = VeafQRA:new():setName("Q")
  q:setDelayBeforeActivating(30)
  luaunit.assertEquals(q.delayBeforeActivating, 30)
end

function TestVeafQraCoreSetters:test_setMinimumAltitudeInFeet()
  local q = VeafQRA:new():setName("Q")
  q:setMinimumAltitudeInFeet(1000)
  luaunit.assertAlmostEquals(q:getMinimumAltitudeInMeters(), 304.8, 1)
end

function TestVeafQraCoreSetters:test_setMaximumAltitudeInFeet()
  local q = VeafQRA:new():setName("Q")
  q:setMaximumAltitudeInFeet(5000)
  luaunit.assertAlmostEquals(q:getMaximumAltitudeInMeters(), 1524, 1)
end

function TestVeafQraCoreSetters:test_setDescription()
  local q = VeafQRA:new():setName("Q"):setDescription("My Desc")
  luaunit.assertEquals(q.description, "My Desc")
end

function TestVeafQraCoreSetters:test_buildStatusMessage()
  local q = VeafQRA:new():setName("Q"):setDescription("TestDesc")
  local msg = q:_buildStatusMessage("Status: %s")
  luaunit.assertEquals(msg, "Status: TestDesc")
end

function TestVeafQraCoreSetters:test_sendStatusMessage_silent()
  local q = VeafQRA:new():setName("Q"):setDescription("TestDesc"):setSilent(true)
  q:_sendStatusMessage("Status: %s")
end

function TestVeafQraCoreSetters:test_sendStatusMessage_not_silent()
  local q = VeafQRA:new():setName("Q"):setDescription("TestDesc"):setSilent(false)
  q:addEnnemyCoalition(coalition.side.RED)
  q:_sendStatusMessage("Status: %s")
end

function TestVeafQraCoreSetters:test_setQRAresupplyDelay_proxy()
  local q = VeafQRA:new():setName("Q")
  q:setQRAresupplyDelay(120)
  luaunit.assertEquals(q.logistics.delayBeforeQRAresupply, 120)
end

function TestVeafQraCoreSetters:test_setQRAmaxResupplyCount_proxy()
  local q = VeafQRA:new():setName("Q")
  q:setQRAmaxResupplyCount(5)
  luaunit.assertEquals(q.logistics.QRAresupplyMax, 5)
end

function TestVeafQraCoreSetters:test_setQRAminCountforResupply_proxy()
  local q = VeafQRA:new():setName("Q")
  q:setQRAminCountforResupply(2)
  luaunit.assertEquals(q.logistics.QRAminCountforResupply, 2)
end

function TestVeafQraCoreSetters:test_setResupplyAmount_proxy()
  local q = VeafQRA:new():setName("Q")
  q:setResupplyAmount(3)
  luaunit.assertEquals(q.logistics.resupplyAmount, 3)
end

-- ---------------------------------------------------------------------------
-- TestVeafQraLogisticsSetters — verifies VeafQRALogistics setters and logic
-- ---------------------------------------------------------------------------
TestVeafQraLogisticsSetters = {}

function TestVeafQraLogisticsSetters:test_setQRAresupplyDelay_valid()
  local lg = VeafQRALogistics:new()
  lg:setQRAresupplyDelay(120)
  luaunit.assertEquals(lg.delayBeforeQRAresupply, 120)
end

function TestVeafQraLogisticsSetters:test_setQRAresupplyDelay_invalid_negative()
  local lg = VeafQRALogistics:new()
  lg:setQRAresupplyDelay(-5)
  luaunit.assertEquals(lg.delayBeforeQRAresupply, 0)
end

function TestVeafQraLogisticsSetters:test_setQRAmaxResupplyCount_valid()
  local lg = VeafQRALogistics:new()
  lg:setQRAmaxResupplyCount(5)
  luaunit.assertEquals(lg.QRAresupplyMax, 5)
end

function TestVeafQraLogisticsSetters:test_setQRAminCountforResupply_valid()
  local lg = VeafQRALogistics:new()
  lg:setQRAminCountforResupply(2)
  luaunit.assertEquals(lg.QRAminCountforResupply, 2)
end

function TestVeafQraLogisticsSetters:test_setQRAminCountforResupply_zero_rejected()
  local lg = VeafQRALogistics:new()
  lg:setQRAminCountforResupply(0)
  luaunit.assertEquals(lg.QRAminCountforResupply, -1)
end

function TestVeafQraLogisticsSetters:test_setResupplyAmount_valid()
  local lg = VeafQRALogistics:new()
  lg:setResupplyAmount(3)
  luaunit.assertEquals(lg.resupplyAmount, 3)
end

function TestVeafQraLogisticsSetters:test_setResupplyAmount_zero_rejected()
  local lg = VeafQRALogistics:new()
  lg:setResupplyAmount(0)
  luaunit.assertEquals(lg.resupplyAmount, 1)
end

function TestVeafQraLogisticsSetters:test_setQRAcount_valid()
  local lg = VeafQRALogistics:new()
  lg:setQRAcount(5)
  luaunit.assertEquals(lg:getQRAcount(), 5)
end

function TestVeafQraLogisticsSetters:test_getQRAcount_default()
  local lg = VeafQRALogistics:new()
  luaunit.assertEquals(lg:getQRAcount(), -1)
end

function TestVeafQraLogisticsSetters:test_isActive_false_by_default()
  local lg = VeafQRALogistics:new()
  luaunit.assertFalse(lg:isActive())
end

function TestVeafQraLogisticsSetters:test_isActive_true_when_count_set()
  local lg = VeafQRALogistics:new()
  lg:setQRAcount(3)
  luaunit.assertTrue(lg:isActive())
end

function TestVeafQraLogisticsSetters:test_checkWarehousing_count_zero_schedules_out()
  local lg = VeafQRALogistics:new()
  lg:setQRAmaxResupplyCount(0)
  lg.QRAcount = 0
  local scheduledState = nil
  local qra = {
    name = "Q",
    silent = true,
    outAnnounced = true,
    onOut = nil,
    setScheduledState = function(self, s)
      scheduledState = s
    end,
  }
  lg:checkWarehousing(qra)
  luaunit.assertEquals(scheduledState, veafQraManager.STATUS_OUT)
end

function TestVeafQraLogisticsSetters:test_resupply_increases_count()
  local lg = VeafQRALogistics:new()
  lg:setQRAcount(1)
  lg:setResupplyAmount(2)
  lg.isResupplying = true
  local qra = {
    name = "Q",
    silent = true,
    state = veafQraManager.STATUS_DEAD,
    scheduled_state = nil,
    onResupplied = nil,
    messageResupplied = nil,
    _sendStatusMessage = function() end,
  }
  lg:resupply(qra, 2)
  luaunit.assertEquals(lg:getQRAcount(), 3)
  luaunit.assertFalse(lg.isResupplying)
end

function TestVeafQraLogisticsSetters:test_resupply_aborts_when_stopped()
  local lg = VeafQRALogistics:new()
  lg:setQRAcount(1)
  lg.isResupplying = true
  local qra = {
    name = "Q",
    silent = true,
    state = veafQraManager.STATUS_DEAD,
    scheduled_state = veafQraManager.STATUS_STOP,
    _sendStatusMessage = function() end,
  }
  lg:resupply(qra, 1)
  luaunit.assertEquals(lg:getQRAcount(), 1)
  luaunit.assertFalse(lg.isResupplying)
end

function TestVeafQraLogisticsSetters:test_onQRADestroyed_decrements_count()
  local lg = VeafQRALogistics:new()
  lg:setQRAcount(3)
  local qra = { name = "Q", silent = true }
  lg:onQRADestroyed(qra)
  luaunit.assertEquals(lg:getQRAcount(), 2)
end

-- ---------------------------------------------------------------------------
-- TestVeafQraCoreReactOnHelicopters — setter honors its argument
-- ---------------------------------------------------------------------------
TestVeafQraCoreReactOnHelicopters = {}

function TestVeafQraCoreReactOnHelicopters:setUp()
  dcs_mocks.reset()
end

function TestVeafQraCoreReactOnHelicopters:test_default_is_false()
  luaunit.assertFalse(VeafQRA:new().reactOnHelicopters)
end

function TestVeafQraCoreReactOnHelicopters:test_no_arg_enables_legacy()
  local q = VeafQRA:new():setReactOnHelicopters()
  luaunit.assertTrue(q.reactOnHelicopters)
end

function TestVeafQraCoreReactOnHelicopters:test_explicit_false_is_honored()
  -- Regression: the setter used to ignore its argument and always set true (#299).
  local q = VeafQRA:new():setReactOnHelicopters(false)
  luaunit.assertFalse(q.reactOnHelicopters)
end

function TestVeafQraCoreReactOnHelicopters:test_explicit_true_is_honored()
  local q = VeafQRA:new():setReactOnHelicopters(true)
  luaunit.assertTrue(q.reactOnHelicopters)
end

-- ---------------------------------------------------------------------------
-- TestVeafQraCoreHumanBornEvent — dynamic-slot category detection (#299)
-- ---------------------------------------------------------------------------
TestVeafQraCoreHumanBornEvent = {}

function TestVeafQraCoreHumanBornEvent:setUp()
  dcs_mocks.reset()
end

-- Build a dynamic-slot intruder: a DCS object (no mist unitCategory/unitName fields),
-- exposing the API getters humanBornEvent relies on.
local function _dynSlotUnit(name, categoryEx)
  return {
    getCoalition = function()
      return coalition.side.RED
    end,
    getCategoryEx = function()
      return categoryEx
    end,
    getName = function()
      return name
    end,
  }
end

local function _qraForRed(reactOnHelicopters)
  local q = VeafQRA:new():setName("Q")
  q:addEnnemyCoalition(coalition.side.RED)
  q.reactOnHelicopters = reactOnHelicopters
  q._enemyHumanUnits = {}
  return q
end

function TestVeafQraCoreHumanBornEvent:test_airplane_slot_triggers_even_without_reactOnHelicopters()
  -- The core of #299: a dynamic-slot AIRPLANE must register regardless of reactOnHelicopters.
  local q = _qraForRed(false)
  q:humanBornEvent(_dynSlotUnit("Intruder1", Unit.Category.AIRPLANE))
  luaunit.assertEquals(q._enemyHumanUnits, { "Intruder1" })
end

function TestVeafQraCoreHumanBornEvent:test_helicopter_slot_ignored_when_reactOnHelicopters_false()
  local q = _qraForRed(false)
  q:humanBornEvent(_dynSlotUnit("Heli1", Unit.Category.HELICOPTER))
  luaunit.assertEquals(q._enemyHumanUnits, {})
end

function TestVeafQraCoreHumanBornEvent:test_helicopter_slot_triggers_when_reactOnHelicopters_true()
  local q = _qraForRed(true)
  q:humanBornEvent(_dynSlotUnit("Heli1", Unit.Category.HELICOPTER))
  luaunit.assertEquals(q._enemyHumanUnits, { "Heli1" })
end

-- ---------------------------------------------------------------------------
-- FIX-AIRWAVES-COMMAND-EASTING — a command element must be handed a vec3, not the draw's vec2
--
-- `VeafQRACore:deploy` is `AirWaveZone:deployWaves`'s twin, line for line, and it carried the same
-- slip: `veaf.getRandomPointInCircle` answers the **mission-table** shape (`{ x, y }`, easting in
-- `y`, no `z`), while `veafInterpreter.execute` wants a runtime vec3 whose easting is `z` and whose
-- `y` is the altitude. `veafSpawnGround` reads `spawnPosition.z` for the easting it writes, so an
-- unconverted draw spawned the QRA on the theatre's central meridian at an altitude equal to its
-- easting. See `docs/agents/dcs-coordinates.md`.
--
-- The lot's PRD named only `veafAirWaves`; this site was found by enumerating the three callers of
-- `veafInterpreter.execute` (`veafCombatZone` builds its vec3 by hand and is correct).
--
-- Absent, zero and correct are asserted apart: a missing easting is `nil` here and `0` after
-- anything defaults it, and a loose assertion would accept one of the two.
-- ---------------------------------------------------------------------------
TestVeafQraCommandEasting = {}

function TestVeafQraCommandEasting:setUp()
  dcs_mocks.reset()
  self.deployed = {}
  self._savedInterpreter = veafInterpreter
end

function TestVeafQraCommandEasting:tearDown()
  veaf.triggerZones["QraEastingZone"] = nil
  veafInterpreter = self._savedInterpreter
end

--- A QRA whose only group to deploy is a VEAF command, recording what the interpreter is handed.
function TestVeafQraCommandEasting:_qraDeployingOneCommand()
  local q = VeafQRA:new()
  q.name = "QraEasting"
  q.silent = true
  q.chooseGroupsToDeploy = function(_, _)
    return { "-shilka" }
  end
  local positions = self.deployed
  veafInterpreter = veafInterpreter or {}
  veafInterpreter.execute = function(command, position, _, _, _)
    table.insert(positions, { command = command, position = position })
  end
  return q
end

function TestVeafQraCommandEasting:test_the_easting_reaches_the_interpreter_in_z()
  -- A trigger zone is a mission-table position: `deployWaves`' twin moves its `y` into the zone
  -- centre's `z`. 88 is deliberately neither nil nor zero.
  veaf.triggerZones["QraEastingZone"] = { x = 77, y = 88, radius = 500 }
  local q = self:_qraDeployingOneCommand()
  q:setTriggerZone("QraEastingZone")
  q:deploy(0)
  luaunit.assertEquals(#self.deployed, 1)
  local position = self.deployed[1].position
  luaunit.assertEquals(position.x, 77, "the northing")
  luaunit.assertNotNil(position.z, "the easting is absent — the interpreter was handed a vec2")
  luaunit.assertNotEquals(position.z, 0, "the easting is zero — that is the central meridian, not the zone")
  luaunit.assertEquals(position.z, 88, "the easting must be the zone's own")
end

function TestVeafQraCommandEasting:test_the_altitude_reaches_the_interpreter_in_y()
  -- The zone centre path, because a trigger zone has no altitude of its own: 1500 is the centre's
  -- altitude and 2000 its easting, kept distinct so that reading one for the other shows up.
  local q = self:_qraDeployingOneCommand()
  q:setZoneCenter({ x = 1000, y = 1500, z = 2000 })
  q:deploy(0)
  luaunit.assertEquals(#self.deployed, 1)
  local position = self.deployed[1].position
  luaunit.assertNotNil(position.y, "the altitude is absent")
  luaunit.assertNotEquals(position.y, 2000, "the altitude is the easting — the two shapes were confused")
  luaunit.assertEquals(position.y, 1500, "the altitude must come from the zone centre")
  luaunit.assertEquals(position.z, 2000, "and the easting stays the easting")
end

--------------------------------------------------------------------------------------------------
-- FIX-WAVE-OFFSET-AXES — the QRA twin applies `[latDelta,lonDelta]` to the same axes
--
-- `veafQraCore` carries the same offset arithmetic as `AirWaveZone:deployWaves`, in both its
-- branches. That is precisely how the easting defect came to be fixed in two places rather than
-- one, so this module gets the same coverage: a swap repaired only in `veafAirWaves` would leave
-- every QRA spawning east where the mission asked for north.
--------------------------------------------------------------------------------------------------

TestVeafQraOffsetAxes = {}

local QRA_OFFSET_CENTRE = { x = 1000, y = 1500, z = 2000 }

function TestVeafQraOffsetAxes:setUp()
  dcs_mocks.reset()
  self.deployed = {}
  self._savedInterpreter = veafInterpreter
end

function TestVeafQraOffsetAxes:tearDown()
  veafInterpreter = self._savedInterpreter
end

--- The position the interpreter is handed for a single `[latDelta,lonDelta]` command.
function TestVeafQraOffsetAxes:_positionFor(command)
  local q = VeafQRA:new()
  q.name = "QraOffset"
  q.silent = true
  q:setZoneCenter(QRA_OFFSET_CENTRE)
  q:setRespawnRadius(0)
  q.chooseGroupsToDeploy = function(_, _)
    return { command }
  end
  local positions = self.deployed
  veafInterpreter = veafInterpreter or {}
  veafInterpreter.execute = function(_, position, _, _, _)
    table.insert(positions, position)
  end
  q:deploy(0)
  luaunit.assertEquals(#self.deployed, 1, "the command must have reached the interpreter exactly once")
  return self.deployed[1]
end

function TestVeafQraOffsetAxes:test_a_positive_latitude_moves_north_and_nothing_else()
  local position = self:_positionFor("[5000,0]-spawn su-27, country russia")

  luaunit.assertEquals(position.x - QRA_OFFSET_CENTRE.x, 5000, "a positive latitude delta must move north")
  luaunit.assertEquals(position.z - QRA_OFFSET_CENTRE.z, 0, "and must not touch the easting")
end

function TestVeafQraOffsetAxes:test_a_positive_longitude_moves_east_and_nothing_else()
  local position = self:_positionFor("[0,3000]-spawn su-27, country russia")

  luaunit.assertEquals(position.z - QRA_OFFSET_CENTRE.z, 3000, "a positive longitude delta must move east")
  luaunit.assertEquals(position.x - QRA_OFFSET_CENTRE.x, 0, "and must not touch the northing")
end

function TestVeafQraOffsetAxes:test_both_axes_at_once_do_not_cross()
  local position = self:_positionFor("[4000,-7000]-spawn su-27, country russia")

  luaunit.assertEquals(position.x - QRA_OFFSET_CENTRE.x, 4000, "the first number is the northing")
  luaunit.assertEquals(position.z - QRA_OFFSET_CENTRE.z, -7000, "the second number is the easting")
end

os.exit(luaunit.LuaUnit.run())
