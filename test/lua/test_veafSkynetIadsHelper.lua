--- Tests for veafSkynetIadsHelper.lua — constants, network/IADS lookup.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafSkynetIadsHelper.lua")

-- ---------------------------------------------------------------------------
-- TestVeafSkynetConstants
-- ---------------------------------------------------------------------------
TestVeafSkynetConstants = {}

function TestVeafSkynetConstants:test_id()
  luaunit.assertEquals(veafSkynet.Id, "SKYNET")
end

function TestVeafSkynetConstants:test_version()
  luaunit.assertIsString(veafSkynet.Version)
end

function TestVeafSkynetConstants:test_groupIntegrationModes_strict()
  luaunit.assertEquals(veafSkynet.GroupIntegrationModes.Strict, 0)
end

function TestVeafSkynetConstants:test_groupIntegrationModes_lenient()
  luaunit.assertEquals(veafSkynet.GroupIntegrationModes.Lenient, 1)
end

function TestVeafSkynetConstants:test_pointDefenceModes_none()
  luaunit.assertEquals(veafSkynet.PointDefenceModes.None, 0)
end

function TestVeafSkynetConstants:test_pointDefenceModes_skynet()
  luaunit.assertEquals(veafSkynet.PointDefenceModes.Skynet, 1)
end

function TestVeafSkynetConstants:test_pointDefenceModes_dcs()
  luaunit.assertEquals(veafSkynet.PointDefenceModes.Dcs, 2)
end

function TestVeafSkynetConstants:test_skynetElementStates_autonomous()
  luaunit.assertEquals(veafSkynet.SkynetElementStates.Autonomous, 0)
end

function TestVeafSkynetConstants:test_skynetElementStates_live()
  luaunit.assertEquals(veafSkynet.SkynetElementStates.Live, 1)
end

function TestVeafSkynetConstants:test_skynetElementStates_dark()
  luaunit.assertEquals(veafSkynet.SkynetElementStates.Dark, 2)
end

function TestVeafSkynetConstants:test_defaultIADS_blue()
  -- coalition.side.BLUE = 2, key is stored as string
  luaunit.assertEquals(veafSkynet.defaultIADS[tostring(coalition.side.BLUE)], "blue iads")
end

function TestVeafSkynetConstants:test_defaultIADS_red()
  -- coalition.side.RED = 1, key is stored as string
  luaunit.assertEquals(veafSkynet.defaultIADS[tostring(coalition.side.RED)], "red iads")
end

function TestVeafSkynetConstants:test_structure_table_exists()
  luaunit.assertIsTable(veafSkynet.structure)
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetGetNetwork
-- ---------------------------------------------------------------------------
TestVeafSkynetGetNetwork = {}

function TestVeafSkynetGetNetwork:setUp()
  veafSkynet.structure = {}
end

function TestVeafSkynetGetNetwork:test_getNetwork_returns_nil_for_unknown()
  local net = veafSkynet.getNetwork("nonexistent")
  luaunit.assertNil(net)
end

function TestVeafSkynetGetNetwork:test_getNetwork_returns_injected_network()
  veafSkynet.structure["blueNet"] = { iads = "BlueIads", name = "blueNet" }
  local net = veafSkynet.getNetwork("blueNet")
  luaunit.assertNotNil(net)
  luaunit.assertEquals(net.name, "blueNet")
end

function TestVeafSkynetGetNetwork:test_getIADS_returns_iads_from_network()
  veafSkynet.structure["redNet"] = { iads = "RedIadsObject", name = "redNet" }
  local iads = veafSkynet.getIADS("redNet")
  luaunit.assertEquals(iads, "RedIadsObject")
end

function TestVeafSkynetGetNetwork:test_getIADS_returns_nil_for_unknown()
  local iads = veafSkynet.getIADS("noSuchNet")
  luaunit.assertNil(iads)
end

function TestVeafSkynetGetNetwork:test_multiple_networks()
  veafSkynet.structure["net1"] = { iads = "iads1", name = "net1" }
  veafSkynet.structure["net2"] = { iads = "iads2", name = "net2" }
  luaunit.assertEquals(veafSkynet.getIADS("net1"), "iads1")
  luaunit.assertEquals(veafSkynet.getIADS("net2"), "iads2")
end

os.exit(luaunit.LuaUnit.run())
