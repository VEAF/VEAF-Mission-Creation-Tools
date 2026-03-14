--- Tests for veafCarrierOperations.lua — AllCarriers data and constants.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafCarrierOperations.lua")

-- ---------------------------------------------------------------------------
-- TestVeafCarrierConstants
-- ---------------------------------------------------------------------------
TestVeafCarrierConstants = {}

function TestVeafCarrierConstants:test_version()
  luaunit.assertIsString(veafCarrierOperations.Version)
end

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

os.exit(luaunit.LuaUnit.run())
