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
  q:setSilent(true)           -- suppress outText calls
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
  q:stop(true)  -- silent=true
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
  q:setOnStart(function() called = true end)
  q:start()
  luaunit.assertTrue(called)
end

function TestVeafQraLifecycle:test_onReady_callback_called()
  local called = false
  local q = _newSilentQRA()
  q:setOnReady(function() called = true end)
  q:rearm()
  luaunit.assertTrue(called)
end

function TestVeafQraLifecycle:test_onDestroyed_callback_called()
  local called = false
  local q = _newSilentQRA()
  q:setOnDestroyed(function() called = true end)
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
    setScheduledState = function(self, s) scheduledState = s end,
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

os.exit(luaunit.LuaUnit.run())
