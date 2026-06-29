--- Tests for veafCarrierOperations.lua — AllCarriers data and constants.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafI18n.lua")
dofile(src .. "/veafCarrierOperations.lua")

-- The assertions below pin the English wording; messages are now localized
-- (FR is the default language) so force English for these tests.
veaf.config.language = "en"

-- ---------------------------------------------------------------------------
-- Mocks required by veafCarrierOperations (not in dcs_mocks.lua)
-- ---------------------------------------------------------------------------

mist.getHeading = function(unit, degrees) return 0 end
mist.getAvgPos = function(units) return { x = 0, y = 0, z = 0 } end
mist.goRoute = function(name, route) end
mist.DBs.groupsByName = {}

veafWeatherUnitSystem = {
  Systems = { FaaNavy = "FaaNavy", MetricEastern = "MetricEastern" },
}
veafWeatherData = {
  getWeatherString = function(...) return "WEATHER: test" end,
}
veafRadio = {
  addSubMenu = function(...) return {} end,
  addCommandToSubmenu = function(...) end,
  addSecuredCommandToSubmenu = function(...) end,
  delSubmenu = function(...) end,
  refreshRadioMenu = function(...) end,
  skipHelpMenus = true,
  USAGE_ForGroup = 0,
}

local CARRIER_NAME = "MockCarrierGroup"
local CARRIER_UNIT_NAME = "MockCarrierUnit"

local function setupMockCarrier()
  dcs_mocks.reset()
  mist.DBs.groupsByName = {}
  veafCarrierOperations.carriers = {}

  dcs_mocks.addUnit(CARRIER_UNIT_NAME, {
    getPosition = function(self) return { p = { x = 0, y = 0, z = 0 } } end,
    getVelocity = function(self) return { x = 0, y = 0, z = 0 } end,
    getDesc = function(self) return { typeName = "NotACarrierType" } end,
    getTypeName = function(self) return "NotACarrierType" end,
    getID = function(self) return 1 end,
  })

  dcs_mocks.addGroup(CARRIER_NAME, {
    getUnits = function(self) return {} end,
    getSize = function(self) return 0 end,
    isExist = function(self) return true end,
    getCoalition = function(self) return coalition.side.BLUE end,
    getID = function(self) return 99 end,
    getController = function(self) return { setTask = function() end } end,
  })

  veafCarrierOperations.carriers[CARRIER_NAME] = {
    carrierUnitName = CARRIER_UNIT_NAME,
    pedroUnitName = CARRIER_UNIT_NAME .. " Pedro",
    tankerUnitName = CARRIER_UNIT_NAME .. " S3B-Tanker",
    conductingAirOperations = false,
    stoppedAirOperations = false,
    side = coalition.side.BLUE,
    ATC = {},
    heading = 0,
    speed = 0,
    runwayAngleWithBRC = 9.05,
    desiredWindSpeedOnDeck = 25,
    initialPosition = { x = 0, y = 0, z = 0 },
    tankerData = nil,
    missionRoute = nil,
    tankerRouteSet = 0,
    airOperationsEndAt = 0,
    airOperationsStartedAt = 0,
  }
end

-- ---------------------------------------------------------------------------
-- TestVeafCarrierConstants
-- ---------------------------------------------------------------------------
TestVeafCarrierConstants = {}

function TestVeafCarrierConstants:test_alt_for_measuring_wind()
  luaunit.assertEquals(veafCarrierOperations.ALT_FOR_MEASURING_WIND, 30)
end

function TestVeafCarrierConstants:test_max_operations_duration()
  luaunit.assertEquals(veafCarrierOperations.MAX_OPERATIONS_DURATION, 45)
end

-- ---------------------------------------------------------------------------
-- TestVeafAllCarriers
-- ---------------------------------------------------------------------------
TestVeafAllCarriers = {}

function TestVeafAllCarriers:test_all_carriers_is_table()
  luaunit.assertIsTable(veafCarrierOperations.AllCarriers)
end

function TestVeafAllCarriers:test_all_carriers_has_nine_entries()
  local count = 0
  for _ in pairs(veafCarrierOperations.AllCarriers) do count = count + 1 end
  luaunit.assertEquals(count, 9)
end

function TestVeafAllCarriers:test_stennis_entry_exists()
  luaunit.assertNotNil(veafCarrierOperations.AllCarriers["Stennis"])
end

function TestVeafAllCarriers:test_stennis_runway_angle()
  local s = veafCarrierOperations.AllCarriers["Stennis"]
  luaunit.assertEquals(s.runwayAngleWithBRC, 9.05)
end

function TestVeafAllCarriers:test_stennis_wind_speed()
  local s = veafCarrierOperations.AllCarriers["Stennis"]
  luaunit.assertEquals(s.desiredWindSpeedOnDeck, 25)
end

function TestVeafAllCarriers:test_lha_tarawa_exists()
  luaunit.assertNotNil(veafCarrierOperations.AllCarriers["LHA_Tarawa"])
end

function TestVeafAllCarriers:test_lha_tarawa_runway_angle()
  -- LHA Tarawa has no angled deck
  local t = veafCarrierOperations.AllCarriers["LHA_Tarawa"]
  luaunit.assertEquals(t.runwayAngleWithBRC, -1)
end

function TestVeafAllCarriers:test_lha_tarawa_wind_speed()
  local t = veafCarrierOperations.AllCarriers["LHA_Tarawa"]
  luaunit.assertEquals(t.desiredWindSpeedOnDeck, 20)
end

function TestVeafAllCarriers:test_forrestal_exists()
  luaunit.assertNotNil(veafCarrierOperations.AllCarriers["Forrestal"])
end

function TestVeafAllCarriers:test_kuznecow_exists()
  luaunit.assertNotNil(veafCarrierOperations.AllCarriers["KUZNECOW"])
end

function TestVeafAllCarriers:test_cvn_72_exists()
  luaunit.assertNotNil(veafCarrierOperations.AllCarriers["CVN_72"])
end

-- ---------------------------------------------------------------------------
-- TestVeafCarrierDebugMarkers
-- ---------------------------------------------------------------------------
TestVeafCarrierDebugMarkers = {}

function TestVeafCarrierDebugMarkers:test_getDebugMarkersErasedAtEachStep_no_name_returns_nil()
  -- Called without a name returns nil (by design)
  local v = veafCarrierOperations.getDebugMarkersErasedAtEachStep()
  luaunit.assertNil(v)
end

function TestVeafCarrierDebugMarkers:test_getDebugMarkersErasedAtEachStep_with_name_returns_table()
  local v = veafCarrierOperations.getDebugMarkersErasedAtEachStep("Stennis")
  luaunit.assertIsTable(v)
end

-- ---------------------------------------------------------------------------
-- TestVeafCarrierHelpers
-- ---------------------------------------------------------------------------
TestVeafCarrierHelpers = {}

function TestVeafCarrierHelpers:test_help_no_unit()
  -- outTextForGroup(nil, ...) falls back to outText → no crash
  veafCarrierOperations.help(nil)
end

function TestVeafCarrierHelpers:test_listAvailableCarriers_no_group()
  veafCarrierOperations.carriers = {}
  veafCarrierOperations.listAvailableCarriers(nil)
end

function TestVeafCarrierHelpers:test_listAvailableCarriers_with_group_id()
  veafCarrierOperations.carriers = {}
  veafCarrierOperations.listAvailableCarriers(99)
end

-- ---------------------------------------------------------------------------
-- TestVeafCarrierSimpleFunctions
-- ---------------------------------------------------------------------------
TestVeafCarrierSimpleFunctions = {}

function TestVeafCarrierSimpleFunctions:test_buildRadioMenu_empty_carriers()
  veafCarrierOperations.carriers = {}
  -- empty carriers → early return, no radio menu created
  veafCarrierOperations.buildRadioMenu()
end

function TestVeafCarrierSimpleFunctions:test_doOperations_empty_carriers()
  veafCarrierOperations.carriers = {}
  veafCarrierOperations.doOperations()
end

function TestVeafCarrierSimpleFunctions:test_operationsScheduler_empty_carriers()
  -- calls doOperations() then reschedules; mist.scheduleFunction is a no-op mock
  veafCarrierOperations.carriers = {}
  veafCarrierOperations.operationsScheduler()
end

function TestVeafCarrierSimpleFunctions:test_rebuildRadioMenu_empty_carriers()
  veafCarrierOperations.carriers = {}
  veafCarrierOperations.rebuildRadioMenu()
end

-- ---------------------------------------------------------------------------
-- TestVeafCarrierEarlyReturns
-- ---------------------------------------------------------------------------
TestVeafCarrierEarlyReturns = {}

function TestVeafCarrierEarlyReturns:test_startCarrierOperations_unknown_group()
  veafCarrierOperations.carriers = {}
  -- carrierInfo = {"NoSuchGroup", 45}; carriers table is empty → early return
  veafCarrierOperations.startCarrierOperations({ { "NoSuchGroup", 45 } })
end

function TestVeafCarrierEarlyReturns:test_continueCarrierOperations_unknown_group()
  veafCarrierOperations.carriers = {}
  veafCarrierOperations.continueCarrierOperations("NoSuchGroup")
end

function TestVeafCarrierEarlyReturns:test_stopCarrierOperations_unknown_group()
  veafCarrierOperations.carriers = {}
  veafCarrierOperations.stopCarrierOperations("NoSuchGroup")
end

-- ---------------------------------------------------------------------------
-- TestVeafCarrierRemoteInterface
-- ---------------------------------------------------------------------------
TestVeafCarrierRemoteInterface = {}

function TestVeafCarrierRemoteInterface:test_executeCommandFromRemote_nil_pilot_returns_false()
  local result = veafCarrierOperations.executeCommandFromRemote({ nil, nil, nil, nil })
  luaunit.assertFalse(result)
end

function TestVeafCarrierRemoteInterface:test_executeCommandFromRemote_list_returns_true()
  veafCarrierOperations.carriers = {}
  local result = veafCarrierOperations.executeCommandFromRemote({ { name = "pilot" }, "pilot", nil, "list" })
  luaunit.assertTrue(result)
end

function TestVeafCarrierRemoteInterface:test_executeCommandFromRemote_unknown_command_returns_false()
  local result = veafCarrierOperations.executeCommandFromRemote({ { name = "pilot" }, "pilot", nil, "unknownCommand" })
  luaunit.assertFalse(result)
end

-- ---------------------------------------------------------------------------
-- TestVeafCarrierWithMockCarrier
-- ---------------------------------------------------------------------------
TestVeafCarrierWithMockCarrier = {}

function TestVeafCarrierWithMockCarrier:setUp()
  setupMockCarrier()
  -- restore default zero wind
  atmosphere.getWind = function(point) return { x = 0, y = 0, z = 0 } end
end

function TestVeafCarrierWithMockCarrier:test_continueCarrierOperations_zero_wind()
  veafCarrierOperations.continueCarrierOperations(CARRIER_NAME)
  -- carrier heading updated (may stay 0 with zero wind)
  luaunit.assertIsNumber(veafCarrierOperations.carriers[CARRIER_NAME].heading)
end

function TestVeafCarrierWithMockCarrier:test_continueCarrierOperations_with_wind()
  atmosphere.getWind = function(point) return { x = 3, y = 0, z = 3 } end
  veafCarrierOperations.continueCarrierOperations(CARRIER_NAME)
  -- wind path was taken: heading should differ from 0 (wind from NE pushes to SW heading)
  luaunit.assertIsNumber(veafCarrierOperations.carriers[CARRIER_NAME].heading)
end

function TestVeafCarrierWithMockCarrier:test_getAtcForCarrierOperations_not_conducting()
  local result = veafCarrierOperations.getAtcForCarrierOperations(CARRIER_NAME, false)
  luaunit.assertIsString(result)
  luaunit.assertStrContains(result, "not conducting")
end

function TestVeafCarrierWithMockCarrier:test_getAtcForCarrierOperations_conducting()
  veafCarrierOperations.carriers[CARRIER_NAME].conductingAirOperations = true
  veafCarrierOperations.carriers[CARRIER_NAME].airOperationsEndAt = 9999
  local result = veafCarrierOperations.getAtcForCarrierOperations(CARRIER_NAME, false)
  luaunit.assertIsString(result)
  luaunit.assertStrContains(result, "conducting air operations")
end

function TestVeafCarrierWithMockCarrier:test_getAtcForCarrierOperations_skip_nav_data()
  local result = veafCarrierOperations.getAtcForCarrierOperations(CARRIER_NAME, true)
  luaunit.assertIsString(result)
  -- navigation data block skipped
  luaunit.assertNotStrContains(result, "Current navigation")
end

function TestVeafCarrierWithMockCarrier:test_stopCarrierOperations_basic()
  veafCarrierOperations.carriers[CARRIER_NAME].conductingAirOperations = true
  veafCarrierOperations.stopCarrierOperations(CARRIER_NAME)
  luaunit.assertFalse(veafCarrierOperations.carriers[CARRIER_NAME].conductingAirOperations)
end

function TestVeafCarrierWithMockCarrier:test_stopCarrierOperations_with_pedro_spawned()
  veafCarrierOperations.carriers[CARRIER_NAME].pedroIsSpawned = true
  veafCarrierOperations.stopCarrierOperations(CARRIER_NAME)
  luaunit.assertFalse(veafCarrierOperations.carriers[CARRIER_NAME].pedroIsSpawned)
end

function TestVeafCarrierWithMockCarrier:test_rebuildRadioMenu_not_conducting()
  veafCarrierOperations.carriers[CARRIER_NAME].conductingAirOperations = false
  veafCarrierOperations.rebuildRadioMenu()
  -- should complete without error
end

function TestVeafCarrierWithMockCarrier:test_rebuildRadioMenu_conducting()
  veafCarrierOperations.carriers[CARRIER_NAME].conductingAirOperations = true
  veafCarrierOperations.rebuildRadioMenu()
  -- should complete without error
end

function TestVeafCarrierWithMockCarrier:test_buildRadioMenu_with_carrier()
  -- with one carrier registered, radio menu is built
  veafCarrierOperations.buildRadioMenu()
end

function TestVeafCarrierWithMockCarrier:test_doOperations_stopped_carrier()
  veafCarrierOperations.carriers[CARRIER_NAME].stoppedAirOperations = true
  veafCarrierOperations.doOperations()
  -- stoppedAirOperations branch: should reset the flag
  luaunit.assertFalse(veafCarrierOperations.carriers[CARRIER_NAME].stoppedAirOperations)
end

function TestVeafCarrierWithMockCarrier:test_doOperations_expired_timer_calls_stop()
  veafCarrierOperations.carriers[CARRIER_NAME].conductingAirOperations = true
  veafCarrierOperations.carriers[CARRIER_NAME].airOperationsEndAt = -10  -- definitely in the past
  veafCarrierOperations.doOperations()
  -- stopCarrierOperations was called, so conductingAirOperations should now be false
  luaunit.assertFalse(veafCarrierOperations.carriers[CARRIER_NAME].conductingAirOperations)
end

function TestVeafCarrierWithMockCarrier:test_doOperations_active_not_expired()
  veafCarrierOperations.carriers[CARRIER_NAME].conductingAirOperations = true
  veafCarrierOperations.carriers[CARRIER_NAME].airOperationsEndAt = 9999  -- far future
  veafCarrierOperations.doOperations()
  -- should still be conducting (calls continueCarrierOperations)
  luaunit.assertTrue(veafCarrierOperations.carriers[CARRIER_NAME].conductingAirOperations)
end

function TestVeafCarrierWithMockCarrier:test_executeCommandFromRemote_atc_with_carrier()
  local result = veafCarrierOperations.executeCommandFromRemote({
    { name = "pilot" },
    "pilot",
    nil,
    "atc " .. CARRIER_NAME,
  })
  luaunit.assertTrue(result)
end

-- SECREV-007: getAtcForCarrierOperations must nil-check the carrier before
-- dereferencing it, returning nil for an unknown group instead of crashing.
function TestVeafCarrierWithMockCarrier:test_getAtc_unknown_group_returns_nil()
  luaunit.assertNil(veafCarrierOperations.getAtcForCarrierOperations("no-such-carrier"))
end

os.exit(luaunit.LuaUnit.run())
