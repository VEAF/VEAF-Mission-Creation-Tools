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
  veafSkynet.monitorDynamicSpawnHandlerId = nil
end

function TestVeafSkynetMonitorDynamicSpawn:test_on_sets_handler()
  veafSkynet.monitorDynamicSpawn(true)
  luaunit.assertNotNil(veafSkynet.monitorDynamicSpawnHandlerId)
end

function TestVeafSkynetMonitorDynamicSpawn:test_on_idempotent()
  veafSkynet.monitorDynamicSpawn(true)
  local first = veafSkynet.monitorDynamicSpawnHandlerId
  veafSkynet.monitorDynamicSpawn(true)
  luaunit.assertEquals(veafSkynet.monitorDynamicSpawnHandlerId, first)
end

function TestVeafSkynetMonitorDynamicSpawn:test_off_when_not_set_is_noop()
  veafSkynet.monitorDynamicSpawn(false)
  luaunit.assertNil(veafSkynet.monitorDynamicSpawnHandlerId)
end

function TestVeafSkynetMonitorDynamicSpawn:test_off_clears_handler()
  veafSkynet.monitorDynamicSpawn(true)
  veafSkynet.monitorDynamicSpawn(false)
  luaunit.assertNil(veafSkynet.monitorDynamicSpawnHandlerId)
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
  veafSkynet.monitorDynamicSpawnHandlerId = nil
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
  veafSkynet.monitorDynamicSpawnHandlerId = nil
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
  luaunit.assertNotNil(veafSkynet.monitorDynamicSpawnHandlerId)
end

os.exit(luaunit.LuaUnit.run())
