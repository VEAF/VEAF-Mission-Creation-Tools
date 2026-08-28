--- Tests for veafSkynetIadsHelper.lua — constants, network/IADS lookup.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafSkynetIadsHelper.lua")

-- ---------------------------------------------------------------------------
-- TestVeafSkynetConstants
-- ---------------------------------------------------------------------------
TestVeafSkynetConstants = {}

function TestVeafSkynetConstants:test_id()
  luaunit.assertEquals(veafSkynet.Id, "SKYNET")
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

-- ---------------------------------------------------------------------------
-- Shared mock helpers (module-level)
-- ---------------------------------------------------------------------------
local function _makeMockIads(name)
  local natoMock = { setActAsEW = function() end }
  return {
    name = name,
    coalitionID = nil,
    getSAMSites = function(self)
      return {}
    end,
    getEarlyWarningRadars = function(self)
      return {}
    end,
    addSAMSite = function(self, gname)
      return {}
    end,
    addEarlyWarningRadar = function(self, uname)
      return {}
    end,
    getSAMSitesByNatoName = function(self, nname)
      return natoMock
    end,
    activate = function(self) end,
    deactivate = function(self) end,
    getCoalitionString = function(self)
      return "blue"
    end,
    getDebugSettings = function(self)
      return {
        radarWentLive = false,
        noWorkingCommmandCenter = false,
        ewRadarNoConnection = false,
        samNoConnection = false,
        jammerProbability = false,
        addedEWRadar = false,
        hasNoPower = false,
        harmDefence = false,
        samSiteStatusEnvOutput = false,
        earlyWarningRadarStatusEnvOutput = false,
      }
    end,
    addCommandCenter = function(self, obj) end,
    buildRadarCoverage = function(self) end,
    addRadioMenu = function(self) end,
    removeRadioMenu = function(self) end,
    isCommandCenterUsable = function(self)
      return false
    end,
    getCommandCenters = function(self)
      return {}
    end,
    getContacts = function(self)
      return {}
    end,
  }
end

SkynetIADS = {
  database = {},
  create = function(self, name)
    return _makeMockIads(name)
  end,
}
dcsUnits = { DcsUnitsDatabase = {} }

local function _makeGroupWithUnits(unitTypes)
  local units = {}
  for i, t in ipairs(unitTypes) do
    units[i] = {
      getName = function()
        return "Unit_" .. i
      end,
      getTypeName = function()
        return t
      end,
      getID = function()
        return 100 + i
      end,
    }
  end
  return {
    getName = function()
      return "TestGroup"
    end,
    getID = function()
      return 99
    end,
    getCoalition = function()
      return coalition.side.BLUE
    end,
    getUnits = function()
      return units
    end,
  }
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetGetStringSkynetElement
-- ---------------------------------------------------------------------------
TestVeafSkynetGetStringSkynetElement = {}

function TestVeafSkynetGetStringSkynetElement:test_not_exist_returns_not_exist_string()
  local el = {
    dcsName = "TestSite",
    typeName = "SA-10",
    dcsRepresentation = {
      isExist = function()
        return false
      end,
    },
  }
  local s = veafSkynet.getStringSkynetElement(el)
  luaunit.assertStrContains(s, "does not exist")
end

function TestVeafSkynetGetStringSkynetElement:test_exists_with_nato_name_includes_name()
  local rep = {
    isExist = function()
      return true
    end,
    getID = function()
      return 42
    end,
  }
  setmetatable(rep, Group)
  local el = {
    dcsName = "SA6Site",
    typeName = "SA-6 Launcher",
    dcsRepresentation = rep,
    getNatoName = function(self)
      return "Gainful"
    end,
  }
  local s = veafSkynet.getStringSkynetElement(el)
  luaunit.assertStrContains(s, "SA6Site")
  luaunit.assertStrContains(s, "42")
end

function TestVeafSkynetGetStringSkynetElement:test_exists_without_nato_name_uses_type_name()
  local rep = {
    isExist = function()
      return true
    end,
    getID = function()
      return 7
    end,
  }
  setmetatable(rep, Unit)
  local el = {
    dcsName = "UnitSite",
    typeName = "SA-15 Tor",
    dcsRepresentation = rep,
  }
  local s = veafSkynet.getStringSkynetElement(el)
  luaunit.assertStrContains(s, "SA-15 Tor")
end

function TestVeafSkynetGetStringSkynetElement:test_exists_with_static_metatable_shows_static()
  local rep = {
    isExist = function()
      return true
    end,
    getID = function()
      return 5
    end,
  }
  setmetatable(rep, StaticObject)
  local el = {
    dcsName = "StaticSite",
    typeName = "SBORKA",
    dcsRepresentation = rep,
  }
  local s = veafSkynet.getStringSkynetElement(el)
  luaunit.assertStrContains(s, "static")
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetGetDcsGroupFromSkynetElement
-- ---------------------------------------------------------------------------
TestVeafSkynetGetDcsGroupFromSkynetElement = {}

function TestVeafSkynetGetDcsGroupFromSkynetElement:test_nil_representation_returns_nil()
  local el = { dcsRepresentation = nil }
  luaunit.assertNil(veafSkynet.getDcsGroupFromSkynetElement(el))
end

function TestVeafSkynetGetDcsGroupFromSkynetElement:test_not_exist_returns_nil()
  local el = { dcsRepresentation = {
    isExist = function()
      return false
    end,
  } }
  luaunit.assertNil(veafSkynet.getDcsGroupFromSkynetElement(el))
end

function TestVeafSkynetGetDcsGroupFromSkynetElement:test_group_metatable_returns_representation()
  local rep = {
    isExist = function()
      return true
    end,
  }
  setmetatable(rep, Group)
  local el = { dcsRepresentation = rep }
  luaunit.assertEquals(veafSkynet.getDcsGroupFromSkynetElement(el), rep)
end

function TestVeafSkynetGetDcsGroupFromSkynetElement:test_unit_metatable_calls_unit_getgroup()
  local rep = {
    isExist = function()
      return true
    end,
  }
  setmetatable(rep, Unit)
  local el = { dcsRepresentation = rep }
  luaunit.assertNil(veafSkynet.getDcsGroupFromSkynetElement(el))
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetGetSkynetData
-- ---------------------------------------------------------------------------
TestVeafSkynetGetSkynetData = {}

function TestVeafSkynetGetSkynetData:test_empty_database_returns_nil()
  SkynetIADS.database = {}
  local el = {
    dcsName = "TestEl",
    typeName = "SA-10",
    dcsRepresentation = {
      isExist = function()
        return false
      end,
    },
    launchers = {},
    trackingRadars = {},
    searchRadars = {},
  }
  luaunit.assertNil(veafSkynet.getSkynetData(el))
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetCanBePointDefence
-- ---------------------------------------------------------------------------
TestVeafSkynetCanBePointDefence = {}

function TestVeafSkynetCanBePointDefence:test_nil_returns_false()
  luaunit.assertFalse(veafSkynet.canBePointDefence(nil))
end

function TestVeafSkynetCanBePointDefence:test_no_harm_returns_false()
  luaunit.assertFalse(veafSkynet.canBePointDefence({ type = "single", can_engage_harm = false }))
end

function TestVeafSkynetCanBePointDefence:test_wrong_type_returns_false()
  luaunit.assertFalse(veafSkynet.canBePointDefence({ type = "ewr", can_engage_harm = true }))
end

function TestVeafSkynetCanBePointDefence:test_single_with_harm_returns_true()
  luaunit.assertTrue(veafSkynet.canBePointDefence({ type = "single", can_engage_harm = true }))
end

function TestVeafSkynetCanBePointDefence:test_complex_with_harm_returns_true()
  luaunit.assertTrue(veafSkynet.canBePointDefence({ type = "complex", can_engage_harm = true }))
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetGetIadsOfCoalition
-- ---------------------------------------------------------------------------
TestVeafSkynetGetIadsOfCoalition = {}

function TestVeafSkynetGetIadsOfCoalition:setUp()
  veafSkynet.structure = {}
end

function TestVeafSkynetGetIadsOfCoalition:test_matching_coalition_returns_iads()
  local mockIads = _makeMockIads("blue iads")
  veafSkynet.structure["blue iads"] = { iads = mockIads, coalitionID = coalition.side.BLUE }
  local result = veafSkynet.getIadsOfCoalition("blue iads", coalition.side.BLUE)
  luaunit.assertEquals(result, mockIads)
end

function TestVeafSkynetGetIadsOfCoalition:test_mismatched_coalition_returns_nil()
  local mockIads = _makeMockIads("blue iads")
  veafSkynet.structure["blue iads"] = { iads = mockIads, coalitionID = coalition.side.BLUE }
  local result = veafSkynet.getIadsOfCoalition("blue iads", coalition.side.RED)
  luaunit.assertNil(result)
end

function TestVeafSkynetGetIadsOfCoalition:test_unknown_network_returns_nil()
  local result = veafSkynet.getIadsOfCoalition("no such net", coalition.side.BLUE)
  luaunit.assertNil(result)
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetDelayedActivate
-- ---------------------------------------------------------------------------
TestVeafSkynetDelayedActivate = {}

function TestVeafSkynetDelayedActivate:setUp()
  veafSkynet.structure = {}
end

function TestVeafSkynetDelayedActivate:test_unknown_network_is_noop()
  veafSkynet.delayedActivate("no such net")
end

function TestVeafSkynetDelayedActivate:test_schedules_activation()
  veafSkynet.structure["da1"] = { iads = _makeMockIads("da1"), coalitionID = 2, groups = {} }
  veafSkynet.delayedActivate("da1")
end

function TestVeafSkynetDelayedActivate:test_already_scheduled_is_idempotent()
  local mockIads = _makeMockIads("da2")
  veafSkynet.structure["da2"] = { iads = mockIads, coalitionID = 2, groups = {}, delayedActivation = 42 }
  veafSkynet.delayedActivate("da2")
  luaunit.assertEquals(veafSkynet.structure["da2"].delayedActivation, 42)
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetActivatePrivate
-- ---------------------------------------------------------------------------
TestVeafSkynetActivatePrivate = {}

function TestVeafSkynetActivatePrivate:setUp()
  veafSkynet.structure = {}
end

function TestVeafSkynetActivatePrivate:test_activates_iads_and_clears_delay()
  local activated = false
  local mockIads = _makeMockIads("act1")
  mockIads.activate = function(self)
    activated = true
  end
  veafSkynet.structure["act1"] = { iads = mockIads, coalitionID = 2, groups = {}, delayedActivation = 1 }
  veafSkynet._activateIADS("act1")
  luaunit.assertTrue(activated)
  luaunit.assertNil(veafSkynet.structure["act1"].delayedActivation)
end

function TestVeafSkynetActivatePrivate:test_unknown_network_is_noop()
  veafSkynet._activateIADS("no such net")
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetMonitorDynamicSpawn
-- ---------------------------------------------------------------------------
TestVeafSkynetMonitorDynamicSpawn = {}

function TestVeafSkynetMonitorDynamicSpawn:setUp()
  veafSkynet.monitorDynamicSpawnHandler = nil
end

function TestVeafSkynetMonitorDynamicSpawn:test_on_sets_handler()
  veafSkynet.monitorDynamicSpawn(true)
  luaunit.assertNotNil(veafSkynet.monitorDynamicSpawnHandler)
end

function TestVeafSkynetMonitorDynamicSpawn:test_on_idempotent()
  veafSkynet.monitorDynamicSpawn(true)
  local first = veafSkynet.monitorDynamicSpawnHandler
  veafSkynet.monitorDynamicSpawn(true)
  luaunit.assertEquals(veafSkynet.monitorDynamicSpawnHandler, first)
end

function TestVeafSkynetMonitorDynamicSpawn:test_off_when_not_set_is_noop()
  veafSkynet.monitorDynamicSpawn(false)
  luaunit.assertNil(veafSkynet.monitorDynamicSpawnHandler)
end

function TestVeafSkynetMonitorDynamicSpawn:test_off_clears_handler()
  veafSkynet.monitorDynamicSpawn(true)
  veafSkynet.monitorDynamicSpawn(false)
  luaunit.assertNil(veafSkynet.monitorDynamicSpawnHandler)
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetIsGroupUsable
-- ---------------------------------------------------------------------------
TestVeafSkynetIsGroupUsable = {}

function TestVeafSkynetIsGroupUsable:setUp()
  veafSkynet.iadsSamUnitsTypes = {}
  veafSkynet.iadsEwrUnitsTypes = {}
  veafSkynet.GroupIntegrationMode = veafSkynet.GroupIntegrationModes.Lenient
end

function TestVeafSkynetIsGroupUsable:test_strict_all_known_returns_true()
  veafSkynet.GroupIntegrationMode = veafSkynet.GroupIntegrationModes.Strict
  veafSkynet.iadsSamUnitsTypes["SAM-UNIT"] = true
  local dcsGroup = _makeGroupWithUnits({ "SAM-UNIT", "SAM-UNIT" })
  luaunit.assertTrue(veafSkynet.isGroupUsable(dcsGroup))
end

function TestVeafSkynetIsGroupUsable:test_strict_one_unknown_returns_false()
  veafSkynet.GroupIntegrationMode = veafSkynet.GroupIntegrationModes.Strict
  veafSkynet.iadsSamUnitsTypes["SAM-UNIT"] = true
  local dcsGroup = _makeGroupWithUnits({ "SAM-UNIT", "UNKNOWN" })
  luaunit.assertFalse(veafSkynet.isGroupUsable(dcsGroup))
end

function TestVeafSkynetIsGroupUsable:test_strict_empty_group_returns_true()
  veafSkynet.GroupIntegrationMode = veafSkynet.GroupIntegrationModes.Strict
  local dcsGroup = _makeGroupWithUnits({})
  luaunit.assertTrue(veafSkynet.isGroupUsable(dcsGroup))
end

function TestVeafSkynetIsGroupUsable:test_lenient_one_known_returns_true()
  veafSkynet.iadsSamUnitsTypes["SAM-UNIT"] = true
  local dcsGroup = _makeGroupWithUnits({ "SAM-UNIT" })
  luaunit.assertTrue(veafSkynet.isGroupUsable(dcsGroup))
end

function TestVeafSkynetIsGroupUsable:test_lenient_all_unknown_returns_false()
  local dcsGroup = _makeGroupWithUnits({ "UNKNOWN" })
  luaunit.assertFalse(veafSkynet.isGroupUsable(dcsGroup))
end

function TestVeafSkynetIsGroupUsable:test_lenient_ewr_unit_returns_true()
  veafSkynet.iadsEwrUnitsTypes["EWR-UNIT"] = true
  local dcsGroup = _makeGroupWithUnits({ "EWR-UNIT" })
  luaunit.assertTrue(veafSkynet.isGroupUsable(dcsGroup))
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetRemovePointDefences
-- ---------------------------------------------------------------------------
TestVeafSkynetRemovePointDefences = {}

function TestVeafSkynetRemovePointDefences:test_element_with_defences_clears_them()
  local called = false
  local pd = {
    setIsAPointDefence = function(self, v)
      called = true
    end,
  }
  local el = { pointDefences = { pd } }
  veafSkynet.removePointDefencesFromSkynetElement(el)
  luaunit.assertTrue(called)
  luaunit.assertEquals(#el.pointDefences, 0)
end

function TestVeafSkynetRemovePointDefences:test_element_without_defences_initializes_empty()
  local el = {}
  veafSkynet.removePointDefencesFromSkynetElement(el)
  luaunit.assertNotNil(el.pointDefences)
  luaunit.assertEquals(#el.pointDefences, 0)
end

function TestVeafSkynetRemovePointDefences:test_removePointDefences_empty_iads()
  local mockIads = _makeMockIads("rp1")
  veafSkynet.removePointDefences(mockIads)
end

function TestVeafSkynetRemovePointDefences:test_removePointDefences_clears_sam_site_defences()
  local called = false
  local pd = {
    setIsAPointDefence = function(self, v)
      called = true
    end,
  }
  local samSite = { pointDefences = { pd } }
  local mockIads = _makeMockIads("rp2")
  mockIads.getSAMSites = function(self)
    return { samSite }
  end
  veafSkynet.removePointDefences(mockIads)
  luaunit.assertTrue(called)
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetAddGroupToNetwork
-- ---------------------------------------------------------------------------
TestVeafSkynetAddGroupToNetwork = {}

function TestVeafSkynetAddGroupToNetwork:setUp()
  veafSkynet.structure = {}
  veafSkynet.iadsSamUnitsTypes = {}
  veafSkynet.iadsEwrUnitsTypes = {}
  veafSkynet.GroupIntegrationMode = veafSkynet.GroupIntegrationModes.Lenient
  SkynetIADS = {
    database = {},
    create = function(self, name)
      return _makeMockIads(name)
    end,
  }
  dcsUnits = { DcsUnitsDatabase = {} }
end

function TestVeafSkynetAddGroupToNetwork:test_not_usable_returns_false()
  local dcsGroup = _makeGroupWithUnits({ "UNKNOWN" })
  veafSkynet.structure["blue iads"] = {
    iads = _makeMockIads("blue iads"),
    coalitionID = coalition.side.BLUE,
    groups = {},
  }
  local result = veafSkynet.addGroupToNetwork("blue iads", dcsGroup, false, false, nil, true)
  luaunit.assertFalse(result)
end

function TestVeafSkynetAddGroupToNetwork:test_sam_added_returns_true()
  veafSkynet.iadsSamUnitsTypes["SA-6 Launcher"] = true
  local mockIads = _makeMockIads("blue iads")
  veafSkynet.structure["blue iads"] = { iads = mockIads, coalitionID = coalition.side.BLUE, groups = {} }
  local dcsGroup = _makeGroupWithUnits({ "SA-6 Launcher" })
  local result = veafSkynet.addGroupToNetwork("blue iads", dcsGroup, false, false, nil, true)
  luaunit.assertTrue(result)
end

function TestVeafSkynetAddGroupToNetwork:test_ewr_added_returns_true()
  veafSkynet.iadsEwrUnitsTypes["EWR-UNIT"] = true
  local mockIads = _makeMockIads("blue iads")
  veafSkynet.structure["blue iads"] = { iads = mockIads, coalitionID = coalition.side.BLUE, groups = {} }
  local dcsGroup = _makeGroupWithUnits({ "EWR-UNIT" })
  local result = veafSkynet.addGroupToNetwork("blue iads", dcsGroup, false, false, nil, true)
  luaunit.assertTrue(result)
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetReinitialize
-- ---------------------------------------------------------------------------
TestVeafSkynetReinitialize = {}

function TestVeafSkynetReinitialize:setUp()
  veafSkynet.initialized = false
  veafSkynet.structure = {}
end

function TestVeafSkynetReinitialize:test_reinitializeNetwork_not_initialized_returns_false()
  local result = veafSkynet.reinitializeNetwork("blue iads")
  luaunit.assertFalse(result)
end

function TestVeafSkynetReinitialize:test_reinitialize_not_initialized_returns_false()
  local result = veafSkynet.reinitialize()
  luaunit.assertFalse(result)
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetCommandCenter
-- ---------------------------------------------------------------------------
TestVeafSkynetCommandCenter = {}

function TestVeafSkynetCommandCenter:setUp()
  veafSkynet.initialized = false
  veafSkynet.structure = {}
  veafSkynet.CommandCentersPreinitialize = {}
end

function TestVeafSkynetCommandCenter:test_preinitialize_stores_when_not_initialized()
  veafSkynet.addCommandCenterOfCoalition(2, "CC1")
  luaunit.assertEquals(#veafSkynet.CommandCentersPreinitialize, 1)
end

function TestVeafSkynetCommandCenter:test_addCommandCenter_unknown_cc_logs_error()
  local mockIads = _makeMockIads("testnet")
  local network = { iads = mockIads, coalitionID = coalition.side.BLUE, groups = {} }
  veafSkynet.addCommandCenter(network, "NonExistentCC")
end

function TestVeafSkynetCommandCenter:test_destroyCommandCenters_early_exit_when_cc_not_usable()
  local mockIads = _makeMockIads("dcNet")
  local network = { iads = mockIads, coalitionID = coalition.side.BLUE, groups = {} }
  veafSkynet.destroyCommandCenters(network)
end

-- ---------------------------------------------------------------------------
-- TestVeafSkynetInitialize
-- ---------------------------------------------------------------------------
TestVeafSkynetInitialize = {}

function TestVeafSkynetInitialize:setUp()
  veafSkynet.initialized = false
  veafSkynet.structure = {}
  veafSkynet.iadsSamUnitsTypes = {}
  veafSkynet.iadsEwrUnitsTypes = {}
  veafSkynet.CommandCentersPreinitialize = {}
  veafSkynet.monitorDynamicSpawnHandler = nil
  veafSkynet.loadAllAtInit = {
    [tostring(coalition.side.BLUE)] = true,
    [tostring(coalition.side.RED)] = true,
  }
  SkynetIADS = {
    database = {},
    create = function(self, name)
      return _makeMockIads(name)
    end,
  }
  dcsUnits = { DcsUnitsDatabase = {} }
end

function TestVeafSkynetInitialize:tearDown()
  veafSkynet.DynamicSpawn = false
  veafSkynet.monitorDynamicSpawnHandler = nil
end

function TestVeafSkynetInitialize:test_initialize_creates_blue_and_red_networks()
  veafSkynet._initialize(false, false, false, false)
  luaunit.assertTrue(veafSkynet.initialized)
  luaunit.assertNotNil(veafSkynet.structure["blue iads"])
  luaunit.assertNotNil(veafSkynet.structure["red iads"])
end

function TestVeafSkynetInitialize:test_initialize_clears_preinit_command_centers()
  veafSkynet.CommandCentersPreinitialize = {
    { CoalitionId = coalition.side.BLUE, CommandCenterName = "FakeCC" },
  }
  veafSkynet._initialize(false, false, false, false)
  luaunit.assertEquals(#veafSkynet.CommandCentersPreinitialize, 0)
end

function TestVeafSkynetInitialize:test_dynamic_spawn_true_sets_handler()
  veafSkynet.DynamicSpawn = true
  veafSkynet._initialize(false, false, false, false)
  luaunit.assertNotNil(veafSkynet.monitorDynamicSpawnHandler)
end

-------------------------------------------------------------------------------------------------
-- SECREV-2 / VMR-096 — removing an element whose DCS group is already gone
--
-- `getDcsGroupFromSkynetElement` returns nil when the DCS representation no longer exists — which
-- is the very situation `removeSkynetElement` is called in — and the caller indexed it anyway,
-- under a `---@diagnostic disable-next-line: need-check-nil` that recorded the problem instead of
-- fixing it.
--
-- The network's `groups` table is keyed by group name, and for the SAM sites this function
-- removes, `skynetElement.dcsName` **is** that group name (see the `sam.dcsName == dcsGroupName`
-- comparison in addGroupsToNetwork). So the entry can still be cleared by name; that matters,
-- because leaving it behind would keep the group looking present to the network.
-------------------------------------------------------------------------------------------------

TestSecrev2RemoveSkynetElement = {}

--- A Skynet element whose DCS representation is a Group that may or may not still exist.
local function _skynetElement(dcsName, groupExists)
  local dcsRepresentation = {
    isExist = function()
      return groupExists
    end,
    getName = function()
      return dcsName
    end,
    getID = function()
      return 4242
    end,
    enableEmission = function(_) end,
  }
  setmetatable(dcsRepresentation, Group)
  return {
    dcsName = dcsName,
    typeName = "SA-6 Kub LN 2P25",
    dcsRepresentation = dcsRepresentation,
    cleanUp = function(_) end,
    getDCSRepresentation = function(_)
      return dcsRepresentation
    end,
  }
end

local function _network(groupName)
  return {
    iads = { samSites = {} },
    groups = { [groupName] = { forceEwr = false } },
  }
end

function TestSecrev2RemoveSkynetElement:test_a_live_group_is_removed_from_the_network()
  -- The control: the normal path must keep working.
  local network = _network("SAM-alive")
  veafSkynet.removeSkynetElement(_skynetElement("SAM-alive", true), network)
  luaunit.assertNil(network.groups["SAM-alive"])
end

function TestSecrev2RemoveSkynetElement:test_a_destroyed_group_does_not_raise()
  local network = _network("SAM-dead")
  local ok, err = pcall(veafSkynet.removeSkynetElement, _skynetElement("SAM-dead", false), network)
  luaunit.assertTrue(ok, "removing an element whose group is gone must not raise: " .. tostring(err))
end

function TestSecrev2RemoveSkynetElement:test_a_destroyed_group_is_still_removed_from_the_network()
  local network = _network("SAM-dead")
  pcall(veafSkynet.removeSkynetElement, _skynetElement("SAM-dead", false), network)
  luaunit.assertNil(network.groups["SAM-dead"], "the network still lists a group that no longer exists")
end

function TestSecrev2RemoveSkynetElement:test_another_group_is_left_alone()
  local network = _network("SAM-dead")
  network.groups["SAM-other"] = { forceEwr = false }
  pcall(veafSkynet.removeSkynetElement, _skynetElement("SAM-dead", false), network)
  luaunit.assertNotNil(network.groups["SAM-other"])
end

-------------------------------------------------------------------------------------------------
-- FIX-SKYNET-DYNAMICSPAWN-SCOPE — #151 and #261
--
-- One global boolean answered two issues badly:
--   * `DynamicSpawn` was module-wide, so deactivating one coalition's network removed the birth
--     event handler shared by *both* — and nothing ever re-armed it.
--   * `addGroupToNetwork` ended in an unconditional `delayedActivate`, so integrating a group into
--     a deliberately deactivated network woke it back up.
--   * the birth handler never looked at the per-spawn `skynet` option, so a convoy declared
--     `skynet false` joined the IADS anyway as soon as dynamic integration was on.
-------------------------------------------------------------------------------------------------

--- Capture veaf.scheduleFunction calls so a deferred call can be inspected and fired on demand.
local function _captureSchedule()
  local calls = {}
  local previous = veaf.scheduleFunction
  veaf.scheduleFunction = function(fn, args, t)
    table.insert(calls, { fn = fn, args = args, time = t })
    return #calls
  end
  return calls, function()
    veaf.scheduleFunction = previous
  end
end

local function _netWithIads(name, coa, extra)
  local network = { iads = _makeMockIads(name), coalitionID = coa, groups = {} }
  for k, v in pairs(extra or {}) do
    network[k] = v
  end
  veafSkynet.structure[name] = network
  return network
end

-- ---------------------------------------------------------------------------
-- Ticket 02 — the flag is per network, not module-wide
-- ---------------------------------------------------------------------------
TestVeafSkynetDynamicSpawnScope = {}

function TestVeafSkynetDynamicSpawnScope:setUp()
  veafSkynet.structure = {}
  veafSkynet.monitorDynamicSpawnHandler = nil
  veafSkynet.DynamicSpawn = false
  veafSkynet.declaredSpawns = {}
  veafSkynet.iadsSamUnitsTypes = {}
  veafSkynet.iadsEwrUnitsTypes = {}
  veafSkynet.initialized = true
  SkynetIADS = {
    database = {},
    create = function(self, name)
      return _makeMockIads(name)
    end,
  }
  dcsUnits = { DcsUnitsDatabase = {} }
end

function TestVeafSkynetDynamicSpawnScope:tearDown()
  veafSkynet.DynamicSpawn = false
  veafSkynet.monitorDynamicSpawnHandler = nil
  veafSkynet.initialized = false
end

function TestVeafSkynetDynamicSpawnScope:test_network_is_created_with_the_module_flag()
  veafSkynet.DynamicSpawn = true
  veafSkynet._initialize(false, false, false, false)
  luaunit.assertTrue(veafSkynet.structure["blue iads"].dynamicSpawn)
  luaunit.assertTrue(veafSkynet.structure["red iads"].dynamicSpawn)
end

function TestVeafSkynetDynamicSpawnScope:test_network_created_without_the_flag_does_not_integrate()
  veafSkynet._initialize(false, false, false, false)
  luaunit.assertFalse(veafSkynet.structure["blue iads"].dynamicSpawn)
  luaunit.assertNil(veafSkynet.monitorDynamicSpawnHandler)
end

function TestVeafSkynetDynamicSpawnScope:test_refresh_arms_when_one_network_wants_it()
  _netWithIads("blue iads", coalition.side.BLUE, { dynamicSpawn = false })
  _netWithIads("red iads", coalition.side.RED, { dynamicSpawn = true })
  veafSkynet.refreshDynamicSpawnMonitoring()
  luaunit.assertNotNil(veafSkynet.monitorDynamicSpawnHandler)
end

function TestVeafSkynetDynamicSpawnScope:test_refresh_disarms_when_no_network_wants_it()
  _netWithIads("blue iads", coalition.side.BLUE, { dynamicSpawn = true })
  veafSkynet.refreshDynamicSpawnMonitoring()
  veafSkynet.structure["blue iads"].dynamicSpawn = false
  veafSkynet.refreshDynamicSpawnMonitoring()
  luaunit.assertNil(veafSkynet.monitorDynamicSpawnHandler)
end

function TestVeafSkynetDynamicSpawnScope:test_setDynamicSpawn_touches_one_network_only()
  _netWithIads("blue iads", coalition.side.BLUE, { dynamicSpawn = true })
  _netWithIads("red iads", coalition.side.RED, { dynamicSpawn = true })
  veafSkynet.setDynamicSpawn("red iads", false)
  luaunit.assertFalse(veafSkynet.structure["red iads"].dynamicSpawn)
  luaunit.assertTrue(veafSkynet.structure["blue iads"].dynamicSpawn)
end

function TestVeafSkynetDynamicSpawnScope:test_setDynamicSpawn_on_unknown_network_returns_false()
  luaunit.assertFalse(veafSkynet.setDynamicSpawn("no such net", true))
end

-- The defect of #261, in one assertion: deactivating red used to disarm blue.
function TestVeafSkynetDynamicSpawnScope:test_deactivating_red_leaves_blue_armed()
  _netWithIads("blue iads", coalition.side.BLUE, { dynamicSpawn = true })
  local red = _netWithIads("red iads", coalition.side.RED, { dynamicSpawn = true })
  veafSkynet.refreshDynamicSpawnMonitoring()
  luaunit.assertNotNil(veafSkynet.monitorDynamicSpawnHandler)

  veafSkynet.deactivateNetwork(red)

  luaunit.assertNotNil(veafSkynet.monitorDynamicSpawnHandler, "deactivating red disarmed the shared handler")
  luaunit.assertTrue(veafSkynet.structure["blue iads"].dynamicSpawn, "blue lost its dynamic integration")
end

function TestVeafSkynetDynamicSpawnScope:test_integratesDynamicSpawns_unknown_network_is_false()
  luaunit.assertFalse(veafSkynet.integratesDynamicSpawns("no such net"))
end

function TestVeafSkynetDynamicSpawnScope:test_integratesDynamicSpawns_reads_the_network_flag()
  _netWithIads("blue iads", coalition.side.BLUE, { dynamicSpawn = true })
  _netWithIads("red iads", coalition.side.RED, { dynamicSpawn = false })
  luaunit.assertTrue(veafSkynet.integratesDynamicSpawns("blue iads"))
  luaunit.assertFalse(veafSkynet.integratesDynamicSpawns("red iads"))
end

-- ---------------------------------------------------------------------------
-- Ticket 03 — a network deactivated on purpose stays down
-- ---------------------------------------------------------------------------
TestVeafSkynetDeactivatedStaysDown = {}

function TestVeafSkynetDeactivatedStaysDown:setUp()
  veafSkynet.structure = {}
  veafSkynet.monitorDynamicSpawnHandler = nil
  veafSkynet.iadsSamUnitsTypes = {}
  veafSkynet.iadsEwrUnitsTypes = {}
  veafSkynet.GroupIntegrationMode = veafSkynet.GroupIntegrationModes.Lenient
  veafSkynet.initialized = true
  SkynetIADS = {
    database = {},
    create = function(self, name)
      return _makeMockIads(name)
    end,
  }
  dcsUnits = { DcsUnitsDatabase = {} }
end

function TestVeafSkynetDeactivatedStaysDown:tearDown()
  veafSkynet.initialized = false
end

function TestVeafSkynetDeactivatedStaysDown:test_deactivateNetwork_marks_the_network()
  local net = _netWithIads("red iads", coalition.side.RED)
  veafSkynet.deactivateNetwork(net)
  luaunit.assertTrue(net.deactivated)
end

function TestVeafSkynetDeactivatedStaysDown:test_delayedActivate_refuses_a_deactivated_network()
  _netWithIads("red iads", coalition.side.RED, { deactivated = true })
  local calls, restore = _captureSchedule()
  veafSkynet.delayedActivate("red iads")
  restore()
  luaunit.assertEquals(#calls, 0, "a deactivated network was scheduled for activation")
  luaunit.assertNil(veafSkynet.structure["red iads"].delayedActivation)
end

function TestVeafSkynetDeactivatedStaysDown:test_delayedActivate_still_works_on_a_live_network()
  _netWithIads("blue iads", coalition.side.BLUE)
  local calls, restore = _captureSchedule()
  veafSkynet.delayedActivate("blue iads")
  restore()
  luaunit.assertEquals(#calls, 1)
end

-- Belt to delayedActivate's braces: a schedule taken out *before* the deactivation must not fire.
function TestVeafSkynetDeactivatedStaysDown:test_pending_activation_does_not_fire_after_deactivation()
  local activated = false
  local net = _netWithIads("red iads", coalition.side.RED, { delayedActivation = 7 })
  net.iads.activate = function()
    activated = true
  end
  veafSkynet.deactivateNetwork(net)
  veafSkynet._activateIADS("red iads")
  luaunit.assertFalse(activated, "a pending activation woke a deliberately deactivated network")
end

function TestVeafSkynetDeactivatedStaysDown:test_activateNetwork_clears_the_mark_and_activates()
  local net = _netWithIads("red iads", coalition.side.RED, { deactivated = true })
  local calls, restore = _captureSchedule()
  local result = veafSkynet.activateNetwork(net)
  restore()
  luaunit.assertTrue(result)
  luaunit.assertNil(net.deactivated)
  luaunit.assertEquals(#calls, 1, "reactivating on purpose must schedule the activation")
end

function TestVeafSkynetDeactivatedStaysDown:test_activateNetworkOfCoalition_targets_the_default_network()
  local net = _netWithIads(veafSkynet.defaultIADS[tostring(coalition.side.RED)], coalition.side.RED, { deactivated = true })
  luaunit.assertTrue(veafSkynet.activateNetworkOfCoalition(coalition.side.RED))
  luaunit.assertNil(net.deactivated)
end

function TestVeafSkynetDeactivatedStaysDown:test_activateNetwork_on_nil_returns_false()
  luaunit.assertFalse(veafSkynet.activateNetwork(nil))
end

function TestVeafSkynetDeactivatedStaysDown:test_activateNetwork_on_an_unregistered_network_returns_false()
  local orphan = { iads = _makeMockIads("orphan"), coalitionID = coalition.side.RED, groups = {} }
  luaunit.assertFalse(veafSkynet.activateNetwork(orphan))
end

function TestVeafSkynetDeactivatedStaysDown:test_reinitializeNetwork_clears_the_mark()
  _netWithIads("red iads", coalition.side.RED, { deactivated = true, includeInRadio = false })
  veafSkynet.reinitializeNetwork("red iads")
  luaunit.assertNil(veafSkynet.structure["red iads"].deactivated)
end

-- The reproduction of #261, as measured in DCS: the group is attached, the network stays down.
function TestVeafSkynetDeactivatedStaysDown:test_a_group_spawned_into_a_deactivated_network_does_not_wake_it()
  veafSkynet.iadsSamUnitsTypes["SA-6 Launcher"] = true
  local net = _netWithIads("blue iads", coalition.side.BLUE)
  veafSkynet.deactivateNetwork(net)

  local calls, restore = _captureSchedule()
  local added = veafSkynet.addGroupToNetwork("blue iads", _makeGroupWithUnits({ "SA-6 Launcher" }), false, false, nil, true)
  restore()

  luaunit.assertTrue(added, "the group must still be attached — that is what `skynet true` asks for")
  luaunit.assertEquals(#calls, 0, "attaching a group woke a deliberately deactivated network")
end

-- ---------------------------------------------------------------------------
-- Ticket 04 — the dynamic path honours the per-spawn `skynet` option
-- ---------------------------------------------------------------------------
TestVeafSkynetDeclaredSpawns = {}

function TestVeafSkynetDeclaredSpawns:setUp()
  veafSkynet.structure = {}
  veafSkynet.declaredSpawns = {}
  veafSkynet.monitorDynamicSpawnHandler = nil
  veafSkynet.iadsSamUnitsTypes = {}
  veafSkynet.iadsEwrUnitsTypes = {}
  veafSkynet.GroupIntegrationMode = veafSkynet.GroupIntegrationModes.Lenient
  veafSkynet.initialized = true
  self._groupByName = Group.getByName
end

function TestVeafSkynetDeclaredSpawns:tearDown()
  Group.getByName = self._groupByName
  veafSkynet.initialized = false
  veafSkynet.declaredSpawns = {}
end

function TestVeafSkynetDeclaredSpawns:test_skynet_false_keeps_the_group_out()
  veafSkynet.declareSpawn("Convoy-1", false)
  luaunit.assertNil(veafSkynet.resolveDynamicSpawnNetwork("Convoy-1", coalition.side.RED))
end

function TestVeafSkynetDeclaredSpawns:test_a_named_network_wins_over_the_coalition_default()
  veafSkynet.declareSpawn("SAM-1", "custom net")
  luaunit.assertEquals(veafSkynet.resolveDynamicSpawnNetwork("SAM-1", coalition.side.RED), "custom net")
end

function TestVeafSkynetDeclaredSpawns:test_skynet_true_takes_the_coalition_default()
  veafSkynet.declareSpawn("SAM-2", true)
  luaunit.assertEquals(
    veafSkynet.resolveDynamicSpawnNetwork("SAM-2", coalition.side.RED),
    veafSkynet.defaultIADS[tostring(coalition.side.RED)]
  )
end

-- A group nobody declared comes from the Mission Editor or a third-party script: that is precisely
-- what dynamic spawn integration exists for, and it must keep working.
function TestVeafSkynetDeclaredSpawns:test_an_undeclared_group_takes_the_coalition_default()
  luaunit.assertEquals(
    veafSkynet.resolveDynamicSpawnNetwork("EditorPlacedSAM", coalition.side.BLUE),
    veafSkynet.defaultIADS[tostring(coalition.side.BLUE)]
  )
end

function TestVeafSkynetDeclaredSpawns:test_a_declaration_is_consumed_once()
  veafSkynet.declareSpawn("Convoy-2", false)
  veafSkynet.resolveDynamicSpawnNetwork("Convoy-2", coalition.side.RED)
  luaunit.assertEquals(
    veafSkynet.resolveDynamicSpawnNetwork("Convoy-2", coalition.side.RED),
    veafSkynet.defaultIADS[tostring(coalition.side.RED)]
  )
end

function TestVeafSkynetDeclaredSpawns:test_declareSpawn_ignores_a_nil_group_name()
  veafSkynet.declareSpawn(nil, false)
  luaunit.assertEquals(next(veafSkynet.declaredSpawns), nil)
end

-- The measured case: -hv_convoy_red passes `skynet false` and carries a Tor, a Tunguska and a
-- Strela, all of them in Skynet's database. Before the fix it joined the IADS regardless.
-- NOTE on the coalition used below: `_makeGroupWithUnits` hardcodes `coalition.side.BLUE`, and
-- `addGroupToNetwork` refuses a network whose coalitionID does not match the group's. Running these
-- against a RED network would therefore make them pass on the coalition mismatch instead of on the
-- guard under test — which is exactly what happened before this note existed.
function TestVeafSkynetDeclaredSpawns:test_a_convoy_declared_skynet_false_is_not_integrated()
  veafSkynet.iadsSamUnitsTypes["Tor 9A331"] = true
  local net = _netWithIads("blue iads", coalition.side.BLUE, { dynamicSpawn = true })
  local group = _makeGroupWithUnits({ "Tor 9A331" })
  Group.getByName = function(name)
    return group
  end
  local added = false
  net.iads.addSAMSite = function()
    added = true
    return {}
  end

  veafSkynet.declareSpawn("High Value Attack convoy red", false)
  veafSkynet._integrateDynamicSpawn("High Value Attack convoy red", coalition.side.BLUE)

  luaunit.assertFalse(added, "a convoy spawned with `skynet false` was integrated into the IADS")
end

-- The control for the test above: same setup, no declaration, and the group *does* get integrated.
-- Without it, `assertFalse(added)` could pass because nothing was ever integrable.
function TestVeafSkynetDeclaredSpawns:test_the_same_group_undeclared_is_integrated()
  veafSkynet.iadsSamUnitsTypes["Tor 9A331"] = true
  local net = _netWithIads("blue iads", coalition.side.BLUE, { dynamicSpawn = true })
  local group = _makeGroupWithUnits({ "Tor 9A331" })
  Group.getByName = function()
    return group
  end
  local added = false
  net.iads.addSAMSite = function()
    added = true
    return {}
  end

  veafSkynet._integrateDynamicSpawn("High Value Attack convoy red", coalition.side.BLUE)

  luaunit.assertTrue(added, "an undeclared group must still join its coalition's network")
end

function TestVeafSkynetDeclaredSpawns:test_a_network_with_the_flag_off_integrates_nothing()
  veafSkynet.iadsSamUnitsTypes["SA-6 Launcher"] = true
  local net = _netWithIads("blue iads", coalition.side.BLUE, { dynamicSpawn = false })
  local group = _makeGroupWithUnits({ "SA-6 Launcher" })
  Group.getByName = function()
    return group
  end
  local added = false
  net.iads.addSAMSite = function()
    added = true
    return {}
  end

  veafSkynet._integrateDynamicSpawn("SomeSAM", coalition.side.BLUE)

  luaunit.assertFalse(added)
end

function TestVeafSkynetDeclaredSpawns:test_a_group_that_died_before_integration_is_a_noop()
  Group.getByName = function()
    return nil
  end
  veafSkynet.declareSpawn("Gone", false)
  veafSkynet._integrateDynamicSpawn("Gone", coalition.side.RED)
  luaunit.assertNil(veafSkynet.declaredSpawns["Gone"], "the declaration of a dead group must not leak")
end

function TestVeafSkynetDeclaredSpawns:test_integration_into_an_unknown_network_is_a_noop()
  local group = _makeGroupWithUnits({ "SA-6 Launcher" })
  Group.getByName = function()
    return group
  end
  veafSkynet.declareSpawn("SAM-3", "no such net")
  veafSkynet._integrateDynamicSpawn("SAM-3", coalition.side.RED)
end

-- ---------------------------------------------------------------------------
-- Ticket 04 — OnDynamicSpawn defers instead of racing the declaration
-- ---------------------------------------------------------------------------
TestVeafSkynetOnDynamicSpawn = {}

function TestVeafSkynetOnDynamicSpawn:setUp()
  veafSkynet.structure = {}
  veafSkynet.declaredSpawns = {}
  veafSkynet.initialized = true
  self._unitGetGroup = Unit.getGroup
end

function TestVeafSkynetOnDynamicSpawn:tearDown()
  Unit.getGroup = self._unitGetGroup
  veafSkynet.initialized = false
end

--- A birth event whose initiator is the first unit of `groupName`.
local function _birthEvent(groupName, coa)
  local unit = {
    getID = function()
      return 1
    end,
  }
  local group = {
    getName = function()
      return groupName
    end,
    getID = function()
      return 42
    end,
    getCoalition = function()
      return coa
    end,
    getUnit = function(_, i)
      return unit
    end,
  }
  Unit.getGroup = function()
    return group
  end
  return { id = world.event.S_EVENT_BIRTH, initiator = unit }
end

function TestVeafSkynetOnDynamicSpawn:test_a_birth_schedules_a_deferred_integration()
  local calls, restore = _captureSchedule()
  veafSkynet.OnDynamicSpawn(_birthEvent("NewSAM", coalition.side.RED))
  restore()
  luaunit.assertEquals(#calls, 1)
  luaunit.assertEquals(calls[1].args[1], "NewSAM")
  luaunit.assertEquals(calls[1].args[2], coalition.side.RED)
end

function TestVeafSkynetOnDynamicSpawn:test_a_non_birth_event_is_ignored()
  local calls, restore = _captureSchedule()
  veafSkynet.OnDynamicSpawn({ id = world.event.S_EVENT_ENGINE_STARTUP, initiator = {} })
  restore()
  luaunit.assertEquals(#calls, 0)
end

function TestVeafSkynetOnDynamicSpawn:test_nothing_happens_before_initialization()
  veafSkynet.initialized = false
  local calls, restore = _captureSchedule()
  veafSkynet.OnDynamicSpawn(_birthEvent("NewSAM", coalition.side.RED))
  restore()
  luaunit.assertEquals(#calls, 0)
end

-- Only the group's first unit does the work, otherwise a four-unit SAM site would schedule four times.
function TestVeafSkynetOnDynamicSpawn:test_a_later_unit_of_the_group_is_ignored()
  local event = _birthEvent("NewSAM", coalition.side.RED)
  event.initiator = {
    getID = function()
      return 99
    end,
  }
  local calls, restore = _captureSchedule()
  veafSkynet.OnDynamicSpawn(event)
  restore()
  luaunit.assertEquals(#calls, 0)
end
-- ---------------------------------------------------------------------------
-- FEAT-COMBAT-EFFECTIVE-ADOPTION — a point defence does not guard a dead SAM site
--
-- Second adopter of `veaf.isGroupCombatEffective`, and the safe one: `findSkynetElementToDefend` picks
-- which site a point-defence group protects, so skipping SAM sites that can no longer fight stops a Tor
-- spending a mission guarding a decapitated S-300 while a live one goes undefended. Invisible to a player
-- until it matters, and it cannot end a mission early — unlike `completionCheck`, which David refused for
-- exactly that reason ("tout doit être détruit").
--
-- **Early-warning radars are exempt**, and the first version of these tests got that wrong: every case
-- used `type = "ewr"`, so they exercised precisely what must *not* be filtered and would all have passed
-- on a rule scoped the wrong way. An EWR is defended because it sees, not because it shoots.
-- ---------------------------------------------------------------------------
TestVeafSkynetDefendsOnlyLiveSites = {}

function TestVeafSkynetDefendsOnlyLiveSites:setUp()
  self._effective = veaf.isGroupCombatEffective
  self._avg = veaf.getAveragePosition
  self._fromElement = veafSkynet.getDcsGroupFromSkynetElement
  self._data = veafSkynet.getSkynetData
  self._describe = veafSkynet.getStringSkynetElement

  -- the trace log reads element.dcsRepresentation, which these stand-ins do not have; the descriptor is
  -- not what is under test
  veafSkynet.getStringSkynetElement = function(element)
    return tostring(element and element.groupName)
  end
  -- an element declares its own kind, so a test can be about a SAM site or about an EWR
  veafSkynet.getSkynetData = function(element)
    return { type = element.kind or "complex" }
  end
  veafSkynet.getDcsGroupFromSkynetElement = function(element)
    return element.groupName
  end
  veaf.getAveragePosition = function(groupName)
    if groupName == "POINT-DEFENCE" then
      return { x = 0, y = 0, z = 0 }
    end
    return { x = 100, y = 0, z = 0 }
  end
end

function TestVeafSkynetDefendsOnlyLiveSites:tearDown()
  veaf.isGroupCombatEffective = self._effective
  veaf.getAveragePosition = self._avg
  veafSkynet.getDcsGroupFromSkynetElement = self._fromElement
  veafSkynet.getSkynetData = self._data
  veafSkynet.getStringSkynetElement = self._describe
end

--- A point-defence element over an IADS offering `ewrs` and `sams`.
local function _defence(ewrs, sams)
  return {
    groupName = "POINT-DEFENCE",
    iads = {
      getEarlyWarningRadars = function()
        return ewrs or {}
      end,
      getSAMSites = function()
        return sams or {}
      end,
    },
  }
end

--- A SAM site candidate, which is what the predicate judges.
local function _sam(name)
  return { groupName = name, kind = "complex" }
end

--- An early-warning radar candidate, which it must not judge.
local function _ewr(name)
  return { groupName = name, kind = "ewr" }
end

function TestVeafSkynetDefendsOnlyLiveSites:test_a_live_sam_site_is_still_chosen()
  veaf.isGroupCombatEffective = function()
    return true
  end
  local found = veafSkynet.findSkynetElementToDefend(_defence({}, { _sam("SAM-ALIVE") }), { type = "single" })
  luaunit.assertNotNil(found)
  luaunit.assertEquals(found.groupName, "SAM-ALIVE")
end

function TestVeafSkynetDefendsOnlyLiveSites:test_a_sam_site_that_can_no_longer_fight_is_skipped()
  veaf.isGroupCombatEffective = function()
    return false
  end
  local found = veafSkynet.findSkynetElementToDefend(_defence({}, { _sam("SAM-DEAD") }), { type = "single" })
  luaunit.assertNil(found, "a point defence must not be spent on a site that cannot fight")
end

-- The case the lot is about: a live site further away beats a dead one next door.
function TestVeafSkynetDefendsOnlyLiveSites:test_a_distant_live_site_wins_over_a_close_dead_one()
  veaf.getAveragePosition = function(groupName)
    if groupName == "POINT-DEFENCE" then
      return { x = 0, y = 0, z = 0 }
    elseif groupName == "SAM-DEAD" then
      return { x = 100, y = 0, z = 0 }
    end
    return { x = 5000, y = 0, z = 0 }
  end
  veaf.isGroupCombatEffective = function(groupName)
    return groupName ~= "SAM-DEAD"
  end
  local found = veafSkynet.findSkynetElementToDefend(_defence({}, { _sam("SAM-DEAD"), _sam("SAM-ALIVE") }), { type = "single" })
  luaunit.assertNotNil(found)
  luaunit.assertEquals(found.groupName, "SAM-ALIVE")
end

-- The exemption, and the reason it is not mere caution: an EWR is defended because it *sees*. A mixed
-- group — a 55G6 and a launcher together — carries `SAM LL` with no tracking radar, so judging it would
-- silently strip an early-warning radar of its defence.
function TestVeafSkynetDefendsOnlyLiveSites:test_an_ewr_is_defended_even_when_judged_ineffective()
  veaf.isGroupCombatEffective = function()
    return false
  end
  local found = veafSkynet.findSkynetElementToDefend(_defence({ _ewr("EWR-1") }, {}), { type = "single" })
  luaunit.assertNotNil(found, "an EWR is defended because it sees, not because it shoots")
  luaunit.assertEquals(found.groupName, "EWR-1")
end

function TestVeafSkynetDefendsOnlyLiveSites:test_the_predicate_is_never_asked_about_an_ewr()
  local asked = {}
  veaf.isGroupCombatEffective = function(groupName)
    table.insert(asked, groupName)
    return true
  end
  veafSkynet.findSkynetElementToDefend(_defence({ _ewr("EWR-1") }, {}), { type = "single" })
  luaunit.assertEquals(asked, {}, "asking whether a radar can fight is a category error")
end

-- The predicate is asked about the site, never about the point defence itself: a Tor with its own radar
-- shot out still has a gun, and refusing to place it would be a different decision than this lot's.
function TestVeafSkynetDefendsOnlyLiveSites:test_the_point_defence_itself_is_not_judged()
  local asked = {}
  veaf.isGroupCombatEffective = function(groupName)
    table.insert(asked, groupName)
    return true
  end
  veafSkynet.findSkynetElementToDefend(_defence({}, { _sam("SAM-1") }), { type = "single" })
  luaunit.assertEquals(asked, { "SAM-1" })
end

function TestVeafSkynetDefendsOnlyLiveSites:test_no_sites_at_all_is_still_nil()
  veaf.isGroupCombatEffective = function()
    return true
  end
  luaunit.assertNil(veafSkynet.findSkynetElementToDefend(_defence({}, {}), { type = "single" }))
end

os.exit(luaunit.LuaUnit.run())
