--- Tests for veafTransportMission.lua — constants, CargoTypes, markTextAnalysis.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafTransportMission.lua")

-- ---------------------------------------------------------------------------
-- TestVeafTransportConstants
-- ---------------------------------------------------------------------------
TestVeafTransportConstants = {}

function TestVeafTransportConstants:test_keyphrase()
  luaunit.assertEquals(veafTransportMission.Keyphrase, "_transport")
end

function TestVeafTransportConstants:test_id()
  luaunit.assertEquals(veafTransportMission.Id, "TRANSPORTMISSION")
end

function TestVeafTransportConstants:test_version()
  luaunit.assertIsString(veafTransportMission.Version)
end

function TestVeafTransportConstants:test_minimum_route_distance()
  luaunit.assertEquals(veafTransportMission.MinimumRouteDistance, 15000)
end

function TestVeafTransportConstants:test_safe_zone_distance()
  luaunit.assertEquals(veafTransportMission.SafeZoneDistance, 0.6)
end

-- ---------------------------------------------------------------------------
-- TestVeafTransportCargoTypes
-- ---------------------------------------------------------------------------
TestVeafTransportCargoTypes = {}

function TestVeafTransportCargoTypes:test_cargo_types_is_table()
  luaunit.assertIsTable(veafTransportMission.CargoTypes)
end

function TestVeafTransportCargoTypes:test_cargo_types_has_five_entries()
  luaunit.assertEquals(#veafTransportMission.CargoTypes, 5)
end

function TestVeafTransportCargoTypes:test_first_cargo_is_ammo()
  luaunit.assertEquals(veafTransportMission.CargoTypes[1], "ammo_cargo")
end

function TestVeafTransportCargoTypes:test_contains_barrels_cargo()
  local found = false
  for _, v in ipairs(veafTransportMission.CargoTypes) do
    if v == "barrels_cargo" then found = true end
  end
  luaunit.assertTrue(found)
end

function TestVeafTransportCargoTypes:test_contains_uh1h_cargo()
  local found = false
  for _, v in ipairs(veafTransportMission.CargoTypes) do
    if v == "uh1h_cargo" then found = true end
  end
  luaunit.assertTrue(found)
end

-- ---------------------------------------------------------------------------
-- TestVeafTransportMarkTextAnalysis
-- ---------------------------------------------------------------------------
TestVeafTransportMarkTextAnalysis = {}

function TestVeafTransportMarkTextAnalysis:test_matching_keyphrase_returns_table()
  local r = veafTransportMission.markTextAnalysis("_transport")
  luaunit.assertIsTable(r)
end

function TestVeafTransportMarkTextAnalysis:test_non_matching_returns_nil()
  local r = veafTransportMission.markTextAnalysis("_cas")
  luaunit.assertNil(r)
end

function TestVeafTransportMarkTextAnalysis:test_transport_field_set()
  local r = veafTransportMission.markTextAnalysis("_transport")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.transportmission)
end

function TestVeafTransportMarkTextAnalysis:test_size_keyword()
  local r = veafTransportMission.markTextAnalysis("_transport, size 3")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.size, 3)
end

os.exit(luaunit.LuaUnit.run())
