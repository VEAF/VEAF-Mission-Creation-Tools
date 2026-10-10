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
-- a CAP or Intercept group with no air engagement is cloned with a role (FEAT-AIRCRAFT-ROLES)
dofile(src .. "/dcsUnits.lua")
dofile(src .. "/veafI18n.lua")
dofile(src .. "/veafGrass.lua")
dofile(src .. "/veafSpawn.lua")
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

-- ============================================================================
-- FEAT-AIRCRAFT-ROLES ticket 02: a scrambled interceptor with no job of its own defends the zone.
-- The Sayqal QRA of *Ligne rouge d'At Tanf* had one waypoint and no task, and landed every time.
-- ============================================================================
TestVeafQraZoneDefense = {}

local QRA_ZD_TEMPLATE = "QRA-Sayqal-MiG29"
local QRA_ZD_CLONE = QRA_ZD_TEMPLATE .. " #2"
local QRA_ZD_CENTRE = { x = 40000, y = 0, z = 30000 }

local function qraEngageAir()
  return {
    id = "ComboTask",
    params = { tasks = { { id = "EngageTargets", enabled = true, auto = true, params = { targetTypes = { "Air" }, priority = 0 } } } },
  }
end

function TestVeafQraZoneDefense:setUp()
  dcs_mocks.reset()
  veafMissionDb.groupsByName = {}
  self._originalSchedule = veaf.scheduleFunction
  self.scheduled = {}
  local scheduled = self.scheduled
  veaf.scheduleFunction = function(fn, args, time)
    table.insert(scheduled, { fn = fn, args = args, time = time })
    return 1
  end
  dcs_mocks.addGroup(QRA_ZD_CLONE, {})
end

function TestVeafQraZoneDefense:tearDown()
  veaf.scheduleFunction = self._originalSchedule
  veafMissionDb.groupsByName = {}
  dcs_mocks.reset()
end

--- The editor group, airborne at 5 262 m over the airfield, and the QRA that deploys it.
function TestVeafQraZoneDefense:_deploy(task, firstPointTask)
  veafMissionDb.groupsByName[QRA_ZD_TEMPLATE] = {
    groupName = QRA_ZD_TEMPLATE,
    category = "plane",
    country = "Russia",
    countryId = 0,
    task = task,
    units = { { name = QRA_ZD_TEMPLATE .. "-1", type = "MiG-29S", x = 0, y = 0, alt = 5262 } },
    route = { points = { { type = "Turning Point", x = 0, y = 0, alt = 5262, speed = 200, task = firstPointTask } } },
  }
  dcs_mocks.addGroup(QRA_ZD_TEMPLATE, {
    getUnit = function()
      return {
        getPoint = function()
          return { x = 0, y = 5262, z = 0 }
        end,
      }
    end,
  })
  local q = VeafQRA:new()
  q.name = "QraZoneDefense"
  q.silent = true
  q:setZoneCenter(QRA_ZD_CENTRE)
  q:setZoneRadius(40000)
  q:setRespawnRadius(0)
  q.chooseGroupsToDeploy = function(_, _)
    return { QRA_ZD_TEMPLATE }
  end
  q:deploy(1)
  luaunit.assertEquals(#dcs_mocks.groupsAdded, 1, "exactly one group must reach DCS")
  luaunit.assertEquals(q.spawnedGroupsNames, { QRA_ZD_CLONE }, "the QRA must track the clone")
  return dcs_mocks.groupsAdded[1].group.route.points
end

function TestVeafQraZoneDefense:test_an_interceptor_with_nothing_to_do_is_sent_to_patrol_the_zone()
  local points = self:_deploy("Intercept", { id = "ComboTask", params = { tasks = {} } })
  luaunit.assertEquals(#points, 3)
  -- the leg is centred on the zone, between the airfield and its centre
  luaunit.assertAlmostEquals((points[2].x + points[3].x) / 2, QRA_ZD_CENTRE.x, 0.01)
  luaunit.assertAlmostEquals((points[2].y + points[3].y) / 2, QRA_ZD_CENTRE.z, 0.01)
  luaunit.assertEquals(veafAircraftSpawn.getRole(QRA_ZD_CLONE), "zone_defense")
  luaunit.assertEquals(veafSpawn.capWatchdogZones[QRA_ZD_CLONE], { x = QRA_ZD_CENTRE.x, y = QRA_ZD_CENTRE.z, radius = 40000 })
  luaunit.assertEquals(#self.scheduled, 1, "one watchdog")
end

function TestVeafQraZoneDefense:test_an_interceptor_that_engages_air_keeps_its_editor_route()
  local points = self:_deploy("Intercept", qraEngageAir())
  luaunit.assertEquals(#points, 1)
  luaunit.assertEquals(points[1].task, qraEngageAir())
  luaunit.assertNil(veafAircraftSpawn.getRole(QRA_ZD_CLONE))
  luaunit.assertEquals(#self.scheduled, 0, "no watchdog")
end

function TestVeafQraZoneDefense:test_a_strike_flight_keeps_its_editor_route()
  local points = self:_deploy("Ground Attack", { id = "ComboTask", params = { tasks = {} } })
  luaunit.assertEquals(#points, 1)
  luaunit.assertNil(veafAircraftSpawn.getRole(QRA_ZD_CLONE))
end

-- ============================================================================
-- FEAT-AIRCRAFT-ROLES ticket 03: a `-cap` run by a QRA defends the QRA zone, not the 60 NM zone
-- around wherever its leg happened to fall, and keeps a single watchdog.
-- ============================================================================
TestVeafQraCommandDefendsTheZone = {}

local QRA_CAP_TEMPLATE = "veafSpawn-QRACAP"
local QRA_CAP_CLONE = string.format("%s #%04d", QRA_CAP_TEMPLATE, 1)
local QRA_CAP_CENTRE = { x = 40000, y = 0, z = 30000 }
-- the template's first-waypoint options: ROE weapons hold, reaction to threat evade
local QRA_CAP_OPTIONS = {
  id = "ComboTask",
  params = {
    tasks = {
      { id = "WrappedAction", enabled = true, number = 1, params = { action = { id = "Option", params = { name = 0, value = 4 } } } },
      { id = "WrappedAction", enabled = true, number = 2, params = { action = { id = "Option", params = { name = 1, value = 3 } } } },
    },
  },
}

function TestVeafQraCommandDefendsTheZone:setUp()
  dcs_mocks.reset()
  veafMissionDb.groupsByName = {}
  veafMissionDb.groupsByName[QRA_CAP_TEMPLATE] = {
    name = QRA_CAP_TEMPLATE,
    groupName = QRA_CAP_TEMPLATE,
    category = "plane",
    country = "USA",
    countryId = 2,
    units = { { name = QRA_CAP_TEMPLATE .. "-1", type = "F-15C", x = 0, y = 0, alt = 6000, heading = 0 } },
  }
  self._originalFind = veafSpawn.findSpawnableAircraftGroupname
  veafSpawn.findSpawnableAircraftGroupname = function(_)
    return QRA_CAP_TEMPLATE, { groupId = 1, units = {}, route = { points = { [1] = { task = QRA_CAP_OPTIONS } } } }
  end
  self._originalSchedule = veaf.scheduleFunction
  self.scheduled = {}
  local scheduled = self.scheduled
  veaf.scheduleFunction = function(fn, args, time)
    table.insert(scheduled, { fn = fn, args = args, time = time })
    return 1
  end
  dcs_mocks.addGroup(QRA_CAP_CLONE, {
    getUnit = function()
      return {
        getPoint = function()
          return { x = 1000, y = 7000, z = 2000 }
        end,
      }
    end,
  })
  self._savedInterpreter = veafInterpreter
end

function TestVeafQraCommandDefendsTheZone:tearDown()
  veafInterpreter = self._savedInterpreter
  veafSpawn.findSpawnableAircraftGroupname = self._originalFind
  veaf.scheduleFunction = self._originalSchedule
  veafMissionDb.groupsByName = {}
  dcs_mocks.reset()
end

function TestVeafQraCommandDefendsTheZone:test_a_cap_command_is_re_tasked_on_the_qra_zone()
  local q = VeafQRA:new()
  q.name = "QraCapCommand"
  q.silent = true
  q:setZoneCenter(QRA_CAP_CENTRE)
  q:setZoneRadius(40000)
  q:setRespawnRadius(0)
  q.chooseGroupsToDeploy = function(_, _)
    return { "-cap f15" }
  end
  -- the interpreter, as far as this test goes: a `-cap` at the position it is handed
  veafInterpreter = veafInterpreter or {}
  veafInterpreter.execute = function(_, position, _, _, spawnedGroups)
    local name = veafSpawn.spawnCombatAirPatrol(position, 0, "QRACAP", "usa", 25000, 0, 90, 20, nil, 60, "Excellent", true, false)
    -- the one insertion point of the real spawn, which notifies the caller's hook (#66, #1078)
    veaf.collectSpawnedGroup(spawnedGroups, name)
  end

  q:deploy(1)

  luaunit.assertEquals(q.spawnedGroupsNames, { QRA_CAP_CLONE })
  luaunit.assertEquals(veafAircraftSpawn.getRole(QRA_CAP_CLONE), "zone_defense")
  luaunit.assertEquals(veafSpawn.capWatchdogZones[QRA_CAP_CLONE], { x = QRA_CAP_CENTRE.x, y = QRA_CAP_CENTRE.z, radius = 40000 })
  luaunit.assertEquals(#self.scheduled, 1, "the watchdog the CAP started is re-aimed, not doubled")
  -- the new route, handed to the flying group, patrols across the QRA zone centre
  local mission = dcs_mocks.tasksSet[#dcs_mocks.tasksSet]
  luaunit.assertNotNil(mission, "the group must have been given a new route")
  local points = mission.task.params.route.points
  luaunit.assertAlmostEquals((points[2].x + points[3].x) / 2, QRA_CAP_CENTRE.x, 0.01)
  luaunit.assertAlmostEquals((points[2].y + points[3].y) / 2, QRA_CAP_CENTRE.z, 0.01)
  luaunit.assertEquals(points[1].task, QRA_CAP_OPTIONS, "the new route keeps the template's first-waypoint options")
end

-- ---------------------------------------------------------------------------
-- TestVeafQraSimpleGroupsBesideLevels — FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 03: simple_groups
-- (`:addGroup`, level 1) written next to scramble levels never deploy, whatever the lowest level.
-- ---------------------------------------------------------------------------
TestVeafQraSimpleGroupsBesideLevels = {}

function TestVeafQraSimpleGroupsBesideLevels:test_a_level_one_rule_replaces_them()
  local q = VeafQRA:new():addGroup("ALL"):setRandomGroupsToDeployByEnemyQuantity(1, { "PAIR" }, 1)
  luaunit.assertEquals(q:chooseGroupsToDeploy(1), { "PAIR" })
end

function TestVeafQraSimpleGroupsBesideLevels:test_levels_from_two_up_keep_them_from_ever_firing()
  local q = VeafQRA:new():addGroup("ALL"):setRandomGroupsToDeployByEnemyQuantity(2, { "PAIR" }, 1)
  -- deploy() returns before choosing anything below the lowest level the rules set
  luaunit.assertEquals(q.minimumNbEnemyPlanes, 2)
  luaunit.assertEquals(q:chooseGroupsToDeploy(2), { "PAIR" })
end

-- ---------------------------------------------------------------------------
-- #1078: a QRA whose command spawns later is neither dead nor landed before it arrives
-- ---------------------------------------------------------------------------
TestVeafQraDeferredSpawn = {}

function TestVeafQraDeferredSpawn:setUp()
  dcs_mocks.reset()
  self._savedInterpreter = veafInterpreter
  veafInterpreter = veafInterpreter or {}
  veafInterpreter.execute = function()
    return true -- accepted, spawned later
  end
end

function TestVeafQraDeferredSpawn:tearDown()
  veafInterpreter = self._savedInterpreter
end

function TestVeafQraDeferredSpawn:test_an_empty_deployment_waiting_for_its_group_is_not_destroyed()
  local q = VeafQRA:new()
  q.name = "QraDeferred"
  q.silent = true
  q:setZoneCenter({ x = 0, y = 0, z = 0 })
  q:setZoneRadius(10000)
  q:setCoalition(coalition.side.RED)
  q.chooseGroupsToDeploy = function()
    return { "-mig29, delayed 30" }
  end
  q:deploy(1)
  luaunit.assertEquals(q.state, veafQraManager.STATUS_ACTIVE)
  q:check()
  luaunit.assertEquals(q.state, veafQraManager.STATUS_ACTIVE, "not DEAD: the scramble has not taken off yet")
end

-- ---------------------------------------------------------------------------
-- FIX-QRA-GROUND-START: a QRA scrambled from the runway is not "landed" before it took off.
-- Kolkhida test mission, 2026-10-10: the Senaki pairs appeared on the runway and were destroyed by
-- the next watchdog tick, 5 s later, because "no unit in the air" read as "the QRA has landed".
-- ---------------------------------------------------------------------------
TestVeafQraGroundStart = {}

function TestVeafQraGroundStart:setUp()
  dcs_mocks.reset()
  timer.setTime(1000)
  self.inAir = false
  self.destroyed = {}
  local suite = self
  dcs_mocks.addGroup("QRA Senaki sol MiG-29 #2", {
    getCategory = function()
      return 0 -- airplanes
    end,
    getUnits = function()
      return {
        {
          isExist = function()
            return true
          end,
          getLife = function()
            return 1
          end,
          getLife0 = function()
            return 1
          end,
          inAir = function()
            return suite.inAir
          end,
        },
      }
    end,
  })
  self._savedDestroy = veafReactiveZone.destroyGroups
  veafReactiveZone.destroyGroups = function(names)
    for _, name in ipairs(names or {}) do
      table.insert(suite.destroyed, name)
    end
  end
end

function TestVeafQraGroundStart:tearDown()
  veafReactiveZone.destroyGroups = self._savedDestroy
  dcs_mocks.reset()
end

function TestVeafQraGroundStart:_scrambled()
  local q = VeafQRA:new()
  q.name = "QraSenakiSol"
  q.silent = true
  q:setZoneCenter({ x = 0, y = 0, z = 0 })
  q:setZoneRadius(45000)
  q:setCoalition(coalition.side.RED)
  -- no player in the zone: what is under test is the scrambled group, not who triggered it
  q._getEnemyHumanUnits = function()
    return {}
  end
  q.chooseGroupsToDeploy = function()
    return { "QRA Senaki sol MiG-29" }
  end
  local savedDeploy = veafReactiveZone.deployGroups
  veafReactiveZone.deployGroups = function()
    return { "QRA Senaki sol MiG-29 #2" }
  end
  q:deploy(1)
  veafReactiveZone.deployGroups = savedDeploy
  return q
end

function TestVeafQraGroundStart:test_a_group_rolling_to_the_runway_is_not_rearmed()
  local q = self:_scrambled()
  timer.setTime(1005)
  q:check()
  luaunit.assertEquals(q.state, veafQraManager.STATUS_ACTIVE, "on the ground before take-off is not landed")
  luaunit.assertEquals(self.destroyed, {})
end

function TestVeafQraGroundStart:test_a_group_that_took_off_then_landed_is_rearmed()
  local q = self:_scrambled()
  self.inAir = true
  timer.setTime(1180)
  q:check()
  luaunit.assertEquals(q.state, veafQraManager.STATUS_ACTIVE)
  self.inAir = false
  timer.setTime(2400)
  q:check()
  luaunit.assertEquals(q.state, veafQraManager.STATUS_READY, "back on the ground after flying: landed")
  luaunit.assertEquals(self.destroyed, { "QRA Senaki sol MiG-29 #2" })
end

function TestVeafQraGroundStart:test_a_group_still_on_the_ground_after_the_take_off_delay_is_rearmed()
  local q = self:_scrambled()
  timer.setTime(1000 + veafQraManager.TAKEOFF_TIMEOUT - 1)
  q:check()
  luaunit.assertEquals(q.state, veafQraManager.STATUS_ACTIVE, "still within its take-off delay")
  timer.setTime(1000 + veafQraManager.TAKEOFF_TIMEOUT + 1)
  q:check()
  luaunit.assertEquals(q.state, veafQraManager.STATUS_READY, "stuck on the ground: reset as before")
end

function TestVeafQraGroundStart:test_the_take_off_delay_is_ten_minutes()
  luaunit.assertEquals(veafQraManager.TAKEOFF_TIMEOUT, 600)
end

-- ---------------------------------------------------------------------------
-- FEAT-AIRWAVES-QRA-MERGE #183: the QRA side of its links
-- ---------------------------------------------------------------------------
TestVeafQraLinks = {}

function TestVeafQraLinks:setUp()
  dcs_mocks.reset()
  self._savedCheckLinks = veafReactiveZone.checkLinks
  self._savedAirbase = veaf.getAirbaseForCoalition
  self.linksState = veafReactiveZone.LINKS_OK
  veafReactiveZone.checkLinks = function()
    return self.linksState, self.linksState ~= veafReactiveZone.LINKS_OK and "Maykop" or nil
  end
  self.maykop = { name = "Maykop" }
  veaf.getAirbaseForCoalition = function(name, _)
    return name == "Maykop" and self.maykop or nil
  end
end

function TestVeafQraLinks:tearDown()
  veafReactiveZone.checkLinks = self._savedCheckLinks
  veaf.getAirbaseForCoalition = self._savedAirbase
end

function TestVeafQraLinks:_qra()
  local q = VeafQRA:new()
  q.name = "QraLinked"
  q.silent = true
  q:setCoalition(coalition.side.RED)
  q:addLink("Maykop")
  return q
end

function TestVeafQraLinks:test_a_lost_airbase_pauses_and_its_return_rearms_with_the_airbase()
  local q = self:_qra()
  local down, up = nil, nil
  q:setOnAirbaseDown(function(airbase)
    down = airbase or "nil"
  end)
  q:setOnAirbaseUp(function(airbase)
    up = airbase
  end)
  q.state = veafQraManager.STATUS_READY
  self.linksState = veafReactiveZone.LINKS_PAUSED
  q:checkLinks()
  q:applyScheduledState()
  luaunit.assertEquals(q.state, veafQraManager.STATUS_NOAIRBASE)
  luaunit.assertNotNil(down)
  self.linksState = veafReactiveZone.LINKS_OK
  q:checkLinks()
  luaunit.assertEquals(q.state, veafQraManager.STATUS_DEAD, "back in service, to be re-armed")
  luaunit.assertIs(up, self.maykop, "the callback is handed the airbase that came back")
end

function TestVeafQraLinks:test_a_link_lost_while_airborne_stops_without_announcing_a_destruction()
  local q = self:_qra()
  local destroyed = false
  q:setOnDestroyed(function()
    destroyed = true
  end)
  q.state = veafQraManager.STATUS_ACTIVE
  self.linksState = veafReactiveZone.LINKS_LOST
  q:checkLinks()
  luaunit.assertEquals(q.state, veafQraManager.STATUS_STOP)
  q:check()
  luaunit.assertFalse(destroyed)
end

function TestVeafQraLinks:test_set_airport_link_is_one_link()
  local savedGetByName = Airbase.getByName
  Airbase.getByName = function(name)
    return name == "Batumi" and {} or nil
  end
  local q = VeafQRA:new():setAirportLink("Batumi"):setAirportLink("Batumi")
  Airbase.getByName = savedGetByName
  luaunit.assertEquals(q.links, { "Batumi" })
  luaunit.assertEquals(q.airportLink, "Batumi")
end

-- ---------------------------------------------------------------------------
-- TestVeafQraTiers — FEAT-OPPOSITION-SCALES-WITH-PLAYERS ticket 01: the tier a QRA scrambles is the
-- biggest that fits whatever the order the tiers were set in, a tier can deploy all its groups, and a
-- random pick never sends the same group twice.
-- ---------------------------------------------------------------------------
TestVeafQraTiers = {}

function TestVeafQraTiers:tearDown()
  dcs_mocks.reset()
  -- a stub left by a failed assertion must not reach the next test
  veafOpposition = nil
end

local function _permutations(list)
  if #list <= 1 then
    return { list }
  end
  local result = {}
  for i = 1, #list do
    local rest = {}
    for j = 1, #list do
      if j ~= i then
        table.insert(rest, list[j])
      end
    end
    for _, tail in ipairs(_permutations(rest)) do
      table.insert(result, { list[i], unpack(tail) })
    end
  end
  return result
end

function TestVeafQraTiers:test_the_biggest_tier_that_fits_in_every_insertion_order()
  for _, order in ipairs(_permutations({ 1, 3, 5 })) do
    local q = VeafQRA:new()
    for _, tier in ipairs(order) do
      q:setGroupsToDeployByEnemyQuantity(tier, { "T" .. tier })
    end
    for enemies = 0, 8 do
      local expected = nil
      for _, tier in ipairs({ 1, 3, 5 }) do
        if enemies >= tier then
          expected = { "T" .. tier }
        end
      end
      luaunit.assertEquals(
        q:chooseGroupsToDeploy(enemies),
        expected,
        string.format("tiers set in order %s, %d enemies", table.concat(order, ","), enemies)
      )
    end
  end
end

function TestVeafQraTiers:test_a_tier_without_a_pick_deploys_every_group()
  local q = VeafQRA:new():setGroupsToDeployByEnemyQuantity(3, { "MiG-29", "Su-27" })
  luaunit.assertEquals(q:chooseGroupsToDeploy(4), { "MiG-29", "Su-27" })
end

function TestVeafQraTiers:test_a_pick_of_n_from_n_gives_n_distinct_groups()
  -- the mocks' draw answers 0: a draw with replacement would send the first group twice
  local q = VeafQRA:new():setRandomGroupsToDeployByEnemyQuantity(3, { "MiG-29", "Su-27" }, 2)
  local picked = q:chooseGroupsToDeploy(3)
  table.sort(picked)
  luaunit.assertEquals(picked, { "MiG-29", "Su-27" })
end

function TestVeafQraTiers:test_a_pick_never_draws_more_than_the_list_holds()
  local q = VeafQRA:new():setRandomGroupsToDeployByEnemyQuantity(1, { "MiG-29", "Su-27" }, 5)
  luaunit.assertEquals(#q:chooseGroupsToDeploy(1), 2)
end

function TestVeafQraTiers:test_a_qra_following_the_level_scrambles_its_tier()
  veafOpposition = {
    getLevel = function()
      return 6
    end,
  }
  local q =
    VeafQRA:new():setGroupsToDeployByEnemyQuantity(1, { "T1" }):setGroupsToDeployByEnemyQuantity(5, { "T5" }):setScaleWithOpposition()
  luaunit.assertEquals(q:tierCount(2), 6, "two in the zone, sized for six")
  luaunit.assertEquals(q:tierCount(8), 8, "more in the zone than the level: the zone")
  luaunit.assertEquals(q:chooseGroupsToDeploy(q:tierCount(2)), { "T5" })
  veafOpposition = nil
end

function TestVeafQraTiers:test_a_qra_not_following_the_level_ignores_it()
  veafOpposition = {
    getLevel = function()
      return 6
    end,
  }
  luaunit.assertEquals(VeafQRA:new():tierCount(2), 2)
  veafOpposition = nil
end

function TestVeafQraTiers:test_no_level_leaves_the_zone_count()
  veafOpposition = {
    getLevel = function()
      return nil
    end,
  }
  luaunit.assertEquals(VeafQRA:new():setScaleWithOpposition():tierCount(2), 2)
  veafOpposition = nil
  luaunit.assertEquals(VeafQRA:new():setScaleWithOpposition():tierCount(2), 2, "and no module at all")
end

function TestVeafQraTiers:test_deploy_scrambles_the_tier_of_the_level()
  veafOpposition = {
    getLevel = function()
      return 6
    end,
  }
  local q =
    VeafQRA:new():setGroupsToDeployByEnemyQuantity(1, { "T1" }):setGroupsToDeployByEnemyQuantity(5, { "T5" }):setScaleWithOpposition()
  local chosenFrom = nil
  local savedChoose = q.chooseGroupsToDeploy
  q.chooseGroupsToDeploy = function(self, count)
    chosenFrom = count
    return nil
  end
  q:deploy(2)
  q.chooseGroupsToDeploy = savedChoose
  veafOpposition = nil
  luaunit.assertEquals(chosenFrom, 6)
end

function TestVeafQraTiers:test_the_lowest_tier_gate_follows_the_level_too()
  veafOpposition = {
    getLevel = function()
      return 6
    end,
  }
  local q =
    VeafQRA:new():setGroupsToDeployByEnemyQuantity(3, { "T3" }):setGroupsToDeployByEnemyQuantity(5, { "T5" }):setScaleWithOpposition()
  local chosenFrom = nil
  q.chooseGroupsToDeploy = function(_, count)
    chosenFrom = count
    return nil
  end
  q:deploy(2)
  luaunit.assertEquals(chosenFrom, 6, "a pair in the zone of a QRA sized for six, lowest tier 3")
end

function TestVeafQraTiers:test_without_the_level_the_lowest_tier_still_gates()
  local q = VeafQRA:new():setGroupsToDeployByEnemyQuantity(3, { "T3" })
  local chosen = false
  q.chooseGroupsToDeploy = function()
    chosen = true
    return nil
  end
  q:deploy(2)
  luaunit.assertFalse(chosen)
end

function TestVeafQraTiers:test_a_dead_qra_rearms_with_the_zone_occupied_when_asked()
  local q = VeafQRA:new():setNoNeedToLeaveZoneBeforeRearming()
  luaunit.assertTrue(q.noNeedToLeaveZoneBeforeRearming)
end

os.exit(luaunit.LuaUnit.run())
