--- Tests for veafSkynetIadsHelper.lua — constants, network/IADS lookup.
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
-- A real dependency since #946: veafSkynet listens for units being lost, to tell a site the enemy
-- destroyed from one a script despawned. The module tolerates the dispatcher being absent, and
-- loading it here is what lets the ledger be exercised rather than stubbed.
dofile(src .. "/veafEventHandler.lua")
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

-- The two cases #946 changed this function for. `removeSkynetElement` logs through it, on elements
-- picked precisely for having lost their DCS object, so raising here would take the sweep down.
function TestVeafSkynetGetStringSkynetElement:test_a_nil_representation_says_so_instead_of_raising()
  local el = { dcsName = "SAM-gone", typeName = "SA-6", dcsRepresentation = nil }
  local ok, s = pcall(veafSkynet.getStringSkynetElement, el)
  luaunit.assertTrue(ok, "describing an element whose representation is gone must not raise: " .. tostring(s))
  luaunit.assertStrContains(s, "does not exist")
end

function TestVeafSkynetGetStringSkynetElement:test_a_nil_name_does_not_raise_on_concatenation()
  local el = {
    dcsName = nil,
    typeName = "SA-6",
    dcsRepresentation = {
      isExist = function()
        return false
      end,
    },
  }
  local ok = pcall(veafSkynet.getStringSkynetElement, el)
  luaunit.assertTrue(ok, "an element with no name must be describable")
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
    -- Refuses the way DCS refuses. It used to answer whether the group existed or not, which is why
    -- `test_a_destroyed_group_does_not_raise` below passed against an unguarded
    -- `getDCSRepresentation():enableEmission(true)` — the test asserted the handler, not the wiring
    -- (#946).
    enableEmission = function(_)
      if not groupExists then
        error("group [" .. tostring(dcsName) .. "] no longer exists, enableEmission is not available on it", 2)
      end
    end,
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

-- ============================================================================
-- FIX-UNGUARDED-DCS-LOOKUPS — the point-defence search and a radar that is gone
--
-- `getNearestIADSSite` walks the network's early-warning radars, which are registered by **unit**
-- name, and resolved the group from the unit in three unchecked steps:
--
--     local unit = Unit.getByName(site_name)
--     local group = Unit.getGroup(unit)
--     site_name = Group.getName(group)
--
-- Skynet's register outlives the units in it — a radar destroyed since the network was built is
-- precisely what this loop walks over — so `Unit.getGroup(nil)` took the whole search down, and with
-- it the point defence of the site being placed.
--
-- The mocks reproduce it as DCS does: an EWR named in the network but never registered with
-- `dcs_mocks.addUnit` is a radar DCS no longer knows.
-- ============================================================================
TestVeafSkynetVanishedEwr = {}

--- An IADS answering one EWR site and no SAM site.
local function _iadsWithEwr(ewrUnitName)
  return {
    getEarlyWarningRadars = function()
      return { { dcsName = ewrUnitName } }
    end,
    getSAMSites = function()
      return {}
    end,
  }
end

--- The group asking for a point defence: alive, blue, and not the EWR.
local function _askingGroup(name)
  dcs_mocks.addUnit(name .. "-1", {
    getPosition = function()
      return { p = { x = 0, y = 0, z = 0 } }
    end,
  })
  dcs_mocks.addGroup(name, {
    getUnits = function()
      return { Unit.getByName(name .. "-1") }
    end,
  })
  return Group.getByName(name)
end

function TestVeafSkynetVanishedEwr:setUp()
  dcs_mocks.reset()
  self._savedStructure = veafSkynet.structure
  veafSkynet.structure = {
    ["blue iads"] = { iads = _iadsWithEwr("DEAD-EWR-UNIT"), coalitionID = coalition.side.BLUE },
  }
  self._logger = veaf.loggers.get(veafSkynet.Id)
  self._originalWarn = self._logger.warn
  self.warned = {}
  local warned = self.warned
  self._logger.warn = function(_, text, ...)
    table.insert(warned, tostring(text))
  end
end

function TestVeafSkynetVanishedEwr:tearDown()
  self._logger.warn = self._originalWarn
  veafSkynet.structure = self._savedStructure
  dcs_mocks.reset()
end

-- The defect itself: without the guard this raises on `Unit.getGroup(nil)`.
function TestVeafSkynetVanishedEwr:test_a_dead_ewr_does_not_take_the_search_down()
  local group = _askingGroup("SA-15-POINT-DEFENCE")
  local ok, err = pcall(veafSkynet.getNearestIADSSite, "blue iads", group)
  luaunit.assertTrue(ok, string.format("getNearestIADSSite raised on an EWR that is gone: %s", tostring(err)))
end

function TestVeafSkynetVanishedEwr:test_the_warning_names_the_radar()
  veafSkynet.getNearestIADSSite("blue iads", _askingGroup("SA-15-POINT-DEFENCE"))
  local named = false
  for _, warning in ipairs(self.warned) do
    if warning:find("DEAD-EWR-UNIT", 1, true) then
      named = true
    end
  end
  luaunit.assertTrue(named, "the warning must name the EWR unit that is gone")
end

-- The ordinary path is untouched: an EWR whose unit is alive still resolves to its group name, and no
-- warning is raised for it.
function TestVeafSkynetVanishedEwr:test_a_live_ewr_still_resolves_to_its_group()
  dcs_mocks.addUnit("LIVE-EWR-UNIT", {
    getPosition = function()
      return { p = { x = 500, y = 0, z = 500 } }
    end,
    getGroup = function()
      return Group.getByName("LIVE-EWR-GROUP")
    end,
  })
  dcs_mocks.addGroup("LIVE-EWR-GROUP", {
    getUnits = function()
      return { Unit.getByName("LIVE-EWR-UNIT") }
    end,
  })
  veafSkynet.structure["blue iads"].iads = _iadsWithEwr("LIVE-EWR-UNIT")
  local nearest = veafSkynet.getNearestIADSSite("blue iads", _askingGroup("SA-15-POINT-DEFENCE"))
  luaunit.assertEquals(nearest, "LIVE-EWR-GROUP")
  luaunit.assertEquals(#self.warned, 0)
end

-------------------------------------------------------------------------------------------------
-- FIX-SKYNET-ADDS-DESTROYED-GROUPS — #946
--
-- Tripack, 2026-09-08: the IADS status page announces sixteen SAM sites with a destroyed radar at
-- mission start, with nothing shot at. `Raddest` counts sites where `hasWorkingRadar()` is false,
-- and a site Skynet accepted always holds a search radar — so those radars *no longer exist*.
--
-- A combat zone destroys every group inside it while the config script loads; veafSkynet enrols the
-- map one second later by walking `coalition.getGroups`, and DCS still lists what it has just
-- destroyed — the quirk the Skynet compatibility layer documents above its own `forEachLiveGroup`
-- guard. Nothing removed the corpses afterwards either: `removeSkynetElement` existed and only the
-- point-defence path could reach it.
-------------------------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Tickets 01 + 02 — a destroyed group never enters a network
-- ---------------------------------------------------------------------------
TestVeafSkynetDestroyedGroupsStayOut = {}

--- A red group carrying one SAM unit, alive or not.
--- `getUnits` is deliberately **left to the mock's default**, which raises once `isExist()` is false
--- exactly as DCS does: that is what makes a missing guard fail here instead of passing.
local function _redSamGroup(name, exists)
  dcs_mocks.addUnit(name .. "-1", {
    getTypeName = function()
      return "Kub 2P25 ln"
    end,
  })
  local data = {
    _coalition = coalition.side.RED,
    getCoalition = function()
      return coalition.side.RED
    end,
  }
  if exists then
    data.getUnits = function()
      return { Unit.getByName(name .. "-1") }
    end
  else
    data.isExist = function()
      return false
    end
  end
  dcs_mocks.addGroup(name, data)
  return Group.getByName(name)
end

function TestVeafSkynetDestroyedGroupsStayOut:setUp()
  dcs_mocks.reset()
  veafSkynet.structure = {}
  veafSkynet.iadsSamUnitsTypes = { ["Kub 2P25 ln"] = true }
  veafSkynet.iadsEwrUnitsTypes = {}
  veafSkynet.GroupIntegrationMode = veafSkynet.GroupIntegrationModes.Lenient
  self.enrolled = {}
  local enrolled = self.enrolled
  self.iads = _makeMockIads("red iads")
  self.iads.addSAMSite = function(_, groupName)
    table.insert(enrolled, groupName)
    return { dcsName = groupName }
  end
  veafSkynet.structure["red iads"] = { iads = self.iads, coalitionID = coalition.side.RED, groups = {} }
end

function TestVeafSkynetDestroyedGroupsStayOut:tearDown()
  dcs_mocks.reset()
  veafSkynet.structure = {}
end

function TestVeafSkynetDestroyedGroupsStayOut:test_a_destroyed_group_is_refused()
  local result = veafSkynet.addGroupToNetwork("red iads", _redSamGroup("DEAD-SAM", false), false, false, nil, true)
  luaunit.assertFalse(result)
  luaunit.assertEquals(#self.enrolled, 0, "a group DCS no longer holds was enrolled as a SAM site")
end

function TestVeafSkynetDestroyedGroupsStayOut:test_a_destroyed_group_does_not_raise()
  -- Without the guard the refusal is not a `false`, it is an error: `isGroupUsable` asks a destroyed
  -- group for its units, which raises and takes the whole enrolment down with it.
  local ok, err = pcall(veafSkynet.addGroupToNetwork, "red iads", _redSamGroup("DEAD-SAM", false), false, false, nil, true)
  luaunit.assertTrue(ok, "adding a destroyed group must be refused, not raise: " .. tostring(err))
end

function TestVeafSkynetDestroyedGroupsStayOut:test_a_live_group_is_still_enrolled()
  -- The control. A guard that refuses everything looks identical to a guard that works.
  local result = veafSkynet.addGroupToNetwork("red iads", _redSamGroup("LIVE-SAM", true), false, false, nil, true)
  luaunit.assertTrue(result)
  luaunit.assertEquals(self.enrolled, { "LIVE-SAM" })
end

function TestVeafSkynetDestroyedGroupsStayOut:test_a_nil_group_is_refused_instead_of_raising()
  -- The `nil` guard used to sit *below* the `dcsGroup:getName()` of the opening log line, so it could
  -- never fire and a nil group raised where it claimed to return false.
  local ok, result = pcall(veafSkynet.addGroupToNetwork, "red iads", nil, false, false, nil, true)
  luaunit.assertTrue(ok, "a nil group must be refused, not raise")
  luaunit.assertFalse(result)
end

-- ---------------------------------------------------------------------------
-- Ticket 01 — the start-up enrolment inherits the guard
-- ---------------------------------------------------------------------------
TestVeafSkynetInitSkipsDestroyedGroups = {}

function TestVeafSkynetInitSkipsDestroyedGroups:setUp()
  dcs_mocks.reset()
  -- `_initialize` now arms a real repeating task and two real event callbacks. Left alone, each test
  -- here leaks both into global state and the next suite inherits them — the class of leak
  -- CHORE-MOCK-RESET-LEAKS exists to stop. Saved and restored rather than merely cleared, so a suite
  -- running after this one sees what it saw before.
  self._savedSkynetIADS = SkynetIADS
  self._savedDcsUnits = dcsUnits
  self._savedCallbacks = veafEventHandler.callbacks
  self._savedSchedule = veaf.scheduleFunction
  veafEventHandler.callbacks = {}
  veaf.scheduleFunction = function()
    return 0
  end
  veafSkynet.initialized = false
  veafSkynet.structure = {}
  veafSkynet.iadsSamUnitsTypes = {}
  veafSkynet.iadsEwrUnitsTypes = {}
  veafSkynet.CommandCentersPreinitialize = {}
  veafSkynet.monitorDynamicSpawnHandler = nil
  veafSkynet.vanishedSitesSweepArmed = false
  veafSkynet.loadAllAtInit = {
    [tostring(coalition.side.BLUE)] = true,
    [tostring(coalition.side.RED)] = true,
  }
  self.enrolled = {}
  local enrolled = self.enrolled
  -- A one-entry database, so `_initialize` builds `iadsSamUnitsTypes` from it the way it does in a
  -- mission instead of the suite asserting against a table it wrote itself.
  SkynetIADS = {
    database = { ["Kub"] = { type = "complex", launchers = { ["Kub 2P25 ln"] = {} } } },
    create = function(_, name)
      local iads = _makeMockIads(name)
      iads.addSAMSite = function(_, groupName)
        table.insert(enrolled, groupName)
        return { dcsName = groupName }
      end
      return iads
    end,
  }
  dcsUnits = { DcsUnitsDatabase = {} }
end

function TestVeafSkynetInitSkipsDestroyedGroups:tearDown()
  dcs_mocks.reset()
  veaf.scheduleFunction = self._savedSchedule
  veafEventHandler.callbacks = self._savedCallbacks
  SkynetIADS = self._savedSkynetIADS
  dcsUnits = self._savedDcsUnits
  veafSkynet.structure = {}
  veafSkynet.vanishedSitesSweepArmed = false
end

--- The defect, at the place it was reported: `coalition.getGroups` hands back both groups, one of
--- them destroyed a moment earlier by a combat zone cleaning itself out.
function TestVeafSkynetInitSkipsDestroyedGroups:test_only_the_live_group_joins_the_network()
  _redSamGroup("CMBT_TESTCZ - SA6", false)
  _redSamGroup("SAM-OUTSIDE-THE-ZONE", true)
  veafSkynet._initialize(false, false, false, false)
  luaunit.assertEquals(self.enrolled, { "SAM-OUTSIDE-THE-ZONE" })
end

function TestVeafSkynetInitSkipsDestroyedGroups:test_the_enrolment_survives_a_corpse_in_the_listing()
  -- Not the same assertion: above says the corpse stays out, this says it does not take the rest of
  -- the map with it. Asking a destroyed group for its units raises, and a raise inside this loop
  -- aborts every group after it.
  _redSamGroup("CMBT_TESTCZ - SA6", false)
  _redSamGroup("SAM-OUTSIDE-THE-ZONE", true)
  local ok, err = pcall(veafSkynet._initialize, false, false, false, false)
  luaunit.assertTrue(ok, "the start-up enrolment died on a destroyed group: " .. tostring(err))
end

-- ---------------------------------------------------------------------------
-- Ticket 03 — a despawned site leaves the network, a destroyed one stays
-- ---------------------------------------------------------------------------
TestVeafSkynetVanishedSitesSweep = {}

--- A Skynet element wrapping a Group (a SAM site) or a Unit (an EWR), holding one radar unit.
local function _sweepableElement(dcsName, radarUnitName, exists, metatable)
  local dcsRepresentation = {
    isExist = function()
      return exists
    end,
    getName = function()
      return dcsName
    end,
    getID = function()
      return 77
    end,
    enableEmission = function(_)
      if not exists then
        error("[" .. dcsName .. "] no longer exists, enableEmission is not available on it", 2)
      end
    end,
  }
  setmetatable(dcsRepresentation, metatable or Group)
  return {
    dcsName = dcsName,
    typeName = "Kub 1S91 str",
    dcsRepresentation = dcsRepresentation,
    searchRadars = { { dcsName = radarUnitName } },
    trackingRadars = {},
    launchers = {},
    cleanUp = function(_) end,
    getDCSRepresentation = function(_)
      return dcsRepresentation
    end,
  }
end

function TestVeafSkynetVanishedSitesSweep:setUp()
  veafSkynet.structure = {}
  veafSkynet.lostUnits = {}
end

function TestVeafSkynetVanishedSitesSweep:tearDown()
  veafSkynet.structure = {}
  veafSkynet.lostUnits = {}
end

--- Install one network holding the given SAM sites and EWRs, plus a `groups` entry per element.
function TestVeafSkynetVanishedSitesSweep:_network(samSites, ewRadars)
  local groups = {}
  for _, list in ipairs({ samSites, ewRadars }) do
    for _, element in ipairs(list) do
      groups[element.dcsName] = { forceEwr = false }
    end
  end
  veafSkynet.structure["red iads"] = {
    iads = { samSites = samSites, earlyWarningRadars = ewRadars },
    coalitionID = coalition.side.RED,
    groups = groups,
  }
  return veafSkynet.structure["red iads"]
end

function TestVeafSkynetVanishedSitesSweep:test_a_despawned_site_leaves_the_network()
  local network = self:_network({ _sweepableElement("CMBT_TESTCZ - SA6", "SA6-radar", false) }, {})
  local removed = veafSkynet.removeVanishedSites("red iads")
  luaunit.assertEquals(removed, 1)
  luaunit.assertEquals(#network.iads.samSites, 0)
end

function TestVeafSkynetVanishedSitesSweep:test_a_despawned_site_frees_its_group_name()
  -- The functional half: `addGroupToNetwork` refuses a group the network already lists, so a dead
  -- entry holding the name is what stops a respawned site from ever rejoining the IADS.
  local network = self:_network({ _sweepableElement("CMBT_TESTCZ - SA6", "SA6-radar", false) }, {})
  veafSkynet.removeVanishedSites("red iads")
  luaunit.assertNil(network.groups["CMBT_TESTCZ - SA6"])
end

function TestVeafSkynetVanishedSitesSweep:test_a_destroyed_site_is_kept()
  -- The assertion that makes the ledger load-bearing. Skynet is meant to report the sites the player
  -- killed: `Raddest` and `Destroyed:` are the SEAD readout. Drop this and a sweep that removes
  -- everything looks correct.
  veafSkynet.onUnitLost({ initiator = { unitName = "SA6-radar" } })
  local network = self:_network({ _sweepableElement("SAM-SHOT-AT", "SA6-radar", false) }, {})
  local removed = veafSkynet.removeVanishedSites("red iads")
  luaunit.assertEquals(removed, 0)
  luaunit.assertEquals(#network.iads.samSites, 1)
  luaunit.assertNotNil(network.groups["SAM-SHOT-AT"], "a site the player destroyed must stay in the network")
end

function TestVeafSkynetVanishedSitesSweep:test_a_live_site_is_left_alone()
  local network = self:_network({ _sweepableElement("SAM-ALIVE", "SA6-radar", true) }, {})
  luaunit.assertEquals(veafSkynet.removeVanishedSites("red iads"), 0)
  luaunit.assertEquals(#network.iads.samSites, 1)
end

function TestVeafSkynetVanishedSitesSweep:test_a_despawned_ewr_leaves_the_network()
  -- Through `iads.earlyWarningRadars`: the getter hands back a delegator **copy**, which is why the
  -- removal that used to be attempted on it was commented out as "not removed here".
  local network = self:_network({}, { _sweepableElement("DESPAWNED-EWR", "DESPAWNED-EWR", false, Unit) })
  luaunit.assertEquals(veafSkynet.removeVanishedSites("red iads"), 1)
  luaunit.assertEquals(#network.iads.earlyWarningRadars, 0)
end

function TestVeafSkynetVanishedSitesSweep:test_a_destroyed_ewr_is_kept()
  veafSkynet.onUnitLost({ initiator = { unitName = "SHOT-EWR" } })
  local network = self:_network({}, { _sweepableElement("SHOT-EWR", "SHOT-EWR", false, Unit) })
  luaunit.assertEquals(veafSkynet.removeVanishedSites("red iads"), 0)
  luaunit.assertEquals(#network.iads.earlyWarningRadars, 1)
end

function TestVeafSkynetVanishedSitesSweep:test_the_sweep_does_not_raise_on_a_despawned_site()
  -- `removeSkynetElement` handed emission back to the DCS object unguarded, two lines under a comment
  -- saying the function is reached precisely when that object is gone.
  self:_network({ _sweepableElement("CMBT_TESTCZ - SA6", "SA6-radar", false) }, {})
  local ok, err = pcall(veafSkynet.removeVanishedSites, "red iads")
  luaunit.assertTrue(ok, "the sweep raised on the very case it exists for: " .. tostring(err))
end

--- The cascade the sweep must not set off. `SkynetIADSAbstractRadarElement:cleanUp` cleans up the
--- element's point defences too, and those are separate sites that are still alive — cleaning one up
--- unregisters its event handlers and kills its HARM scan without clearing `harmScanID`, so it never
--- restarts. The site would go deaf for the rest of the mission while still being listed as active.
function TestVeafSkynetVanishedSitesSweep:test_a_live_point_defence_is_detached_not_cleaned_up()
  local pointDefence = {
    dcsName = "TOR-POINT-DEFENCE",
    isAPointDefence = true,
    cleanedUp = false,
    cleanUp = function(self)
      self.cleanedUp = true
    end,
    setIsAPointDefence = function(self, state)
      self.isAPointDefence = state
    end,
  }
  local site = _sweepableElement("CMBT_TESTCZ - SA6", "SA6-radar", false)
  site.pointDefences = { pointDefence }
  -- The real cleanUp, so the cascade is exercised rather than stubbed away.
  site.cleanUp = function(self)
    for i = 1, #self.pointDefences do
      self.pointDefences[i]:cleanUp()
    end
  end
  self:_network({ site }, {})

  veafSkynet.removeVanishedSites("red iads")

  luaunit.assertFalse(pointDefence.cleanedUp, "a live point defence was cleaned up with the site it defended")
  luaunit.assertFalse(pointDefence.isAPointDefence, "the point defence still believes it defends a site that has left the mission")
end

function TestVeafSkynetVanishedSitesSweep:test_a_network_with_no_iads_is_not_an_error()
  veafSkynet.structure["red iads"] = { coalitionID = coalition.side.RED, groups = {} }
  luaunit.assertEquals(veafSkynet.removeVanishedSites("red iads"), 0)
end

function TestVeafSkynetVanishedSitesSweep:test_an_unknown_network_is_not_an_error()
  luaunit.assertEquals(veafSkynet.removeVanishedSites("no such network"), 0)
end

function TestVeafSkynetVanishedSitesSweep:test_sweeping_walks_every_network()
  local red = self:_network({ _sweepableElement("RED-DESPAWNED", "red-radar", false) }, {})
  local blueSites = { _sweepableElement("BLUE-DESPAWNED", "blue-radar", false) }
  veafSkynet.structure["blue iads"] = {
    iads = { samSites = blueSites, earlyWarningRadars = {} },
    coalitionID = coalition.side.BLUE,
    groups = { ["BLUE-DESPAWNED"] = {} },
  }
  veafSkynet.sweepVanishedSites()
  luaunit.assertEquals(#red.iads.samSites, 0)
  luaunit.assertEquals(#blueSites, 0)
end

-- ---------------------------------------------------------------------------
-- Ticket 03 — the ledger itself
-- ---------------------------------------------------------------------------
TestVeafSkynetLostUnitsLedger = {}

function TestVeafSkynetLostUnitsLedger:setUp()
  veafSkynet.lostUnits = {}
end

function TestVeafSkynetLostUnitsLedger:test_a_death_records_the_unit_name()
  veafSkynet.onUnitLost({ initiator = { unitName = "SA6-radar" } })
  luaunit.assertTrue(veafSkynet.lostUnits["SA6-radar"])
end

function TestVeafSkynetLostUnitsLedger:test_a_dynamic_slot_unit_is_recorded_too()
  -- A dynamic-slot unit reaches a callback as the raw DCS object, answering `getName()` and nothing
  -- else. `unitNameFromEvent` is what covers both shapes, and reading only one of them is a silent
  -- failure — the defect that cost the 6.16.0 welcome brief.
  veafSkynet.onUnitLost({
    initiator = {
      getName = function()
        return "DYN-SLOT-1"
      end,
    },
  })
  luaunit.assertTrue(veafSkynet.lostUnits["DYN-SLOT-1"])
end

function TestVeafSkynetLostUnitsLedger:test_an_event_with_no_unit_records_nothing()
  veafSkynet.onUnitLost({})
  luaunit.assertEquals(next(veafSkynet.lostUnits), nil)
end

function TestVeafSkynetLostUnitsLedger:test_a_unit_born_again_is_no_longer_counted_as_lost()
  -- Without this the ledger only grows, and a reused unit name reads as a kill forever: a combat zone
  -- whose SAM was shot once, deactivated and reactivated, spawns under the same unit names unless the
  -- zone renames them — and the next despawn would be kept instead of swept.
  veafSkynet.onUnitLost({ initiator = { unitName = "SA6-radar" } })
  veafSkynet.onUnitBorn({ initiator = { unitName = "SA6-radar" } })
  luaunit.assertNil(veafSkynet.lostUnits["SA6-radar"])
end

function TestVeafSkynetLostUnitsLedger:test_a_birth_leaves_other_losses_alone()
  veafSkynet.onUnitLost({ initiator = { unitName = "SA6-radar" } })
  veafSkynet.onUnitBorn({ initiator = { unitName = "SOMETHING-ELSE" } })
  luaunit.assertTrue(veafSkynet.lostUnits["SA6-radar"])
end

function TestVeafSkynetLostUnitsLedger:test_a_reborn_site_is_swept_after_being_despawned()
  -- The two halves together, at the level the sweep sees them.
  veafSkynet.onUnitLost({ initiator = { unitName = "SA6-radar" } })
  veafSkynet.onUnitBorn({ initiator = { unitName = "SA6-radar" } })
  veafSkynet.structure["red iads"] = {
    iads = { samSites = { _sweepableElement("CMBT_TESTCZ - SA6", "SA6-radar", false) }, earlyWarningRadars = {} },
    coalitionID = coalition.side.RED,
    groups = { ["CMBT_TESTCZ - SA6"] = {} },
  }
  luaunit.assertEquals(veafSkynet.removeVanishedSites("red iads"), 1)
  veafSkynet.structure = {}
end

-- ---------------------------------------------------------------------------
-- Ticket 03 — arming is idempotent
-- ---------------------------------------------------------------------------
TestVeafSkynetSweepArming = {}

function TestVeafSkynetSweepArming:setUp()
  veafSkynet.vanishedSitesSweepArmed = false
  self.previousCallbacks = veafEventHandler.callbacks
  veafEventHandler.callbacks = {}
  self.scheduled = 0
  self.previousSchedule = veaf.scheduleFunction
  local this = self
  veaf.scheduleFunction = function()
    this.scheduled = this.scheduled + 1
    return this.scheduled
  end
end

function TestVeafSkynetSweepArming:tearDown()
  veaf.scheduleFunction = self.previousSchedule
  veafEventHandler.callbacks = self.previousCallbacks
  veafSkynet.vanishedSitesSweepArmed = false
end

--- The names of the callbacks currently registered, in order.
local function _callbackNames()
  local names = {}
  for _, callback in ipairs(veafEventHandler.callbacks) do
    table.insert(names, callback.name)
  end
  return names
end

function TestVeafSkynetSweepArming:test_arming_registers_both_callbacks_and_one_schedule()
  veafSkynet._armVanishedSitesSweep()
  luaunit.assertEquals(_callbackNames(), { "veafSkynet.onUnitLost", "veafSkynet.onUnitBorn" })
  luaunit.assertEquals(self.scheduled, 1)
end

function TestVeafSkynetSweepArming:test_arming_twice_changes_nothing()
  -- A reinitialisation must not stack a second set of callbacks nor a second schedule: every loss
  -- would be recorded twice and every sweep run twice, which is the shape of #824.
  veafSkynet._armVanishedSitesSweep()
  veafSkynet._armVanishedSitesSweep()
  luaunit.assertEquals(#veafEventHandler.callbacks, 2)
  luaunit.assertEquals(self.scheduled, 1)
end

function TestVeafSkynetSweepArming:test_the_schedule_repeats()
  local captured = nil
  veaf.scheduleFunction = function(fn, vars, t, rep)
    captured = { fn = fn, time = t, rep = rep }
    return 1
  end
  veafSkynet._armVanishedSitesSweep()
  luaunit.assertEquals(captured.fn, veafSkynet.sweepVanishedSites)
  luaunit.assertEquals(captured.rep, veafSkynet.SecondsBetweenVanishedSitesSweeps)
end

-- ---------------------------------------------------------------------------
-- The helper the three tickets share
-- ---------------------------------------------------------------------------
TestVeafSkynetDcsObjectStillExists = {}

function TestVeafSkynetDcsObjectStillExists:test_nil_does_not_exist()
  luaunit.assertFalse(veafSkynet.dcsObjectStillExists(nil))
end

function TestVeafSkynetDcsObjectStillExists:test_a_live_object_exists()
  luaunit.assertTrue(veafSkynet.dcsObjectStillExists({
    isExist = function()
      return true
    end,
  }))
end

function TestVeafSkynetDcsObjectStillExists:test_a_destroyed_object_does_not()
  luaunit.assertFalse(veafSkynet.dcsObjectStillExists({
    isExist = function()
      return false
    end,
  }))
end

function TestVeafSkynetDcsObjectStillExists:test_an_object_that_cannot_answer_is_given_the_benefit()
  -- Phrased as Skynet's own `forEachLiveGroup` phrases it: a handle without the method must not take
  -- the whole enrolment down with it.
  luaunit.assertTrue(veafSkynet.dcsObjectStillExists({}))
end

-- ---------------------------------------------------------------------------
-- The log line must not be the thing that raises
-- ---------------------------------------------------------------------------
TestVeafSkynetSafeDcsName = {}

function TestVeafSkynetSafeDcsName:test_a_live_object_gives_its_name()
  luaunit.assertEquals(
    veafSkynet.safeDcsName({
      getName = function()
        return "SAM-1"
      end,
    }),
    "SAM-1"
  )
end

function TestVeafSkynetSafeDcsName:test_an_object_that_refuses_gives_a_placeholder()
  -- The case it exists for: the message that says "DCS no longer holds this group" used to ask that
  -- very group for its name, so on a handle that refuses every method the refusal itself raised.
  luaunit.assertEquals(
    veafSkynet.safeDcsName({
      getName = function()
        error("group no longer exists")
      end,
    }),
    "?"
  )
end

function TestVeafSkynetSafeDcsName:test_nil_and_nameless_objects_give_a_placeholder()
  luaunit.assertEquals(veafSkynet.safeDcsName(nil), "?")
  luaunit.assertEquals(veafSkynet.safeDcsName({}), "?")
end

-- ---------------------------------------------------------------------------
-- FIX-SKYNET-CZ-RESPAWN-AND-RANGE ticket 01 — a radar with no range is asked again
-- ---------------------------------------------------------------------------
TestVeafSkynetRadarRange = {}

--- A radar wrapper as Skynet builds one: a `maximumRange` a single `setupRangeData` call decided,
--- and a DCS handle behind it. `sensorRangeOnReRead` is what a second reading would answer, which is
--- the whole question this ticket asks.
local function _radar(name, maximumRange, exists, sensorRangeOnReRead)
  local dcsRepresentation = {
    isExist = function()
      return exists
    end,
    getName = function()
      return name
    end,
  }
  local radar = {
    dcsName = name,
    maximumRange = maximumRange,
    setupRangeDataCalls = 0,
    getDCSRepresentation = function(self)
      return dcsRepresentation
    end,
    getMaxRangeFindingTarget = function(self)
      return self.maximumRange
    end,
  }
  radar.setupRangeData = function(self)
    self.setupRangeDataCalls = self.setupRangeDataCalls + 1
    if sensorRangeOnReRead then
      self.maximumRange = sensorRangeOnReRead
    end
  end
  return radar
end

--- A SAM site holding the given radars, plus one launcher, the way Tripack's site reported itself:
--- `HAS AMMO: true` while its radar answered nothing.
local function _siteWithRadars(dcsName, radars, exists)
  local dcsRepresentation = {
    isExist = function()
      return exists ~= false
    end,
    getName = function()
      return dcsName
    end,
  }
  return {
    dcsName = dcsName,
    launchers = { { dcsName = dcsName .. "-launcher" } },
    getDCSRepresentation = function(_)
      return dcsRepresentation
    end,
    getRadars = function(_)
      return radars
    end,
  }
end

function TestVeafSkynetRadarRange:setUp()
  self._savedSchedule = veaf.scheduleFunction
  self.scheduled = {}
  local scheduled = self.scheduled
  veaf.scheduleFunction = function(fn, args, when)
    table.insert(scheduled, { fn = fn, args = args, when = when })
    return #scheduled
  end
  self.coverageRebuilds = {}
  local coverageRebuilds = self.coverageRebuilds
  veafSkynet.structure["red iads"] = {
    iads = {
      samSites = {},
      earlyWarningRadars = {},
      buildRadarCoverage = function(_)
        table.insert(coverageRebuilds, true)
      end,
    },
    coalitionID = coalition.side.RED,
    groups = {},
  }
end

function TestVeafSkynetRadarRange:tearDown()
  veaf.scheduleFunction = self._savedSchedule
  veafSkynet.structure = {}
end

function TestVeafSkynetRadarRange:test_measure_reports_the_widest_range_and_its_counts()
  local site = _siteWithRadars("SA6", { _radar("search", 55000, true), _radar("track", 24000, true) }, true)
  local maxRange, radarCount, liveRadarCount = veafSkynet.measureRadarRange(site)
  luaunit.assertEquals(maxRange, 55000)
  luaunit.assertEquals(radarCount, 2)
  luaunit.assertEquals(liveRadarCount, 2)
end

function TestVeafSkynetRadarRange:test_measure_counts_a_radar_dcs_no_longer_holds_apart()
  -- The counts are what the log line carries, and what separates "the radar is silent" from "the
  -- radar has left the mission" for whoever reads the next log.
  local site = _siteWithRadars("SA6", { _radar("search", 0, false) }, true)
  local maxRange, radarCount, liveRadarCount = veafSkynet.measureRadarRange(site)
  luaunit.assertEquals(maxRange, 0)
  luaunit.assertEquals(radarCount, 1)
  luaunit.assertEquals(liveRadarCount, 0)
end

function TestVeafSkynetRadarRange:test_measure_does_not_raise_on_nil_or_on_an_element_without_radars()
  luaunit.assertEquals(veafSkynet.measureRadarRange(nil), 0)
  luaunit.assertEquals(veafSkynet.measureRadarRange({}), 0)
  local refuses = {
    getRadars = function()
      error("this element has left the mission")
    end,
  }
  local ok, maxRange = pcall(veafSkynet.measureRadarRange, refuses)
  luaunit.assertTrue(ok, "measuring an element that refuses its radars must not raise")
  luaunit.assertEquals(maxRange, 0)
end

function TestVeafSkynetRadarRange:test_a_site_with_a_range_is_left_alone()
  -- The control: a healthy site must not be re-read, and must not print a line at info level either.
  veafSkynet.checkRadarRange("red iads", _siteWithRadars("SA6", { _radar("search", 55000, true) }, true))
  luaunit.assertEquals(#self.scheduled, 0)
end

function TestVeafSkynetRadarRange:test_a_site_reporting_no_range_is_scheduled_for_a_re_read()
  -- The defect, at the state Tripack's log shows: a live radar handle whose range is zero.
  veafSkynet.checkRadarRange("red iads", _siteWithRadars("SA6", { _radar("search", 0, true) }, true))
  luaunit.assertEquals(#self.scheduled, 1)
  luaunit.assertEquals(self.scheduled[1].fn, veafSkynet.recheckRadarRange)
  luaunit.assertEquals(self.scheduled[1].args[1], "red iads")
  luaunit.assertEquals(self.scheduled[1].args[3], veafSkynet.MaxRangeRechecks)
end

function TestVeafSkynetRadarRange:test_zero_rechecks_means_zero()
  -- MaxRangeRechecks is a number a mission can set, and `attemptsLeft > 1` would have turned a
  -- declared zero into one reading.
  local saved = veafSkynet.MaxRangeRechecks
  veafSkynet.MaxRangeRechecks = 0
  veafSkynet.checkRadarRange("red iads", _siteWithRadars("SA6", { _radar("search", 0, true) }, true))
  veafSkynet.MaxRangeRechecks = saved
  luaunit.assertEquals(#self.scheduled, 0)
end

function TestVeafSkynetRadarRange:test_a_site_whose_radars_are_gone_is_not_re_read()
  -- Nothing to ask. That element is the sweep's business.
  veafSkynet.checkRadarRange("red iads", _siteWithRadars("SA6", { _radar("search", 0, false) }, true))
  luaunit.assertEquals(#self.scheduled, 0)
end

function TestVeafSkynetRadarRange:test_a_nil_element_is_ignored()
  local ok = pcall(veafSkynet.checkRadarRange, "red iads", nil)
  luaunit.assertTrue(ok)
  luaunit.assertEquals(#self.scheduled, 0)
end

function TestVeafSkynetRadarRange:test_the_re_read_asks_the_radar_again()
  local radar = _radar("search", 0, true, 55000)
  veafSkynet.recheckRadarRange("red iads", _siteWithRadars("SA6", { radar }, true), 3)
  luaunit.assertEquals(radar.setupRangeDataCalls, 1)
  luaunit.assertEquals(radar.maximumRange, 55000)
end

function TestVeafSkynetRadarRange:test_a_recovered_range_rebuilds_the_coverage()
  -- Without this the number would be right and unused: the parent/child graph was built while the
  -- range was still zero, so the site would go on seeing nobody.
  veafSkynet.recheckRadarRange("red iads", _siteWithRadars("SA6", { _radar("search", 0, true, 55000) }, true), 3)
  luaunit.assertEquals(#self.coverageRebuilds, 1)
  luaunit.assertEquals(#self.scheduled, 0, "a recovered site must not be re-read again")
end

function TestVeafSkynetRadarRange:test_a_range_still_zero_is_asked_again_until_the_attempts_run_out()
  local site = _siteWithRadars("SA6", { _radar("search", 0, true) }, true)
  veafSkynet.recheckRadarRange("red iads", site, 3)
  luaunit.assertEquals(#self.scheduled, 1)
  luaunit.assertEquals(self.scheduled[1].args[3], 2)

  self.scheduled = {}
  local scheduled = self.scheduled
  veaf.scheduleFunction = function(fn, args, when)
    table.insert(scheduled, { fn = fn, args = args, when = when })
    return #scheduled
  end
  veafSkynet.recheckRadarRange("red iads", site, 1)
  luaunit.assertEquals(#scheduled, 0, "the last attempt must not schedule another one")
  luaunit.assertEquals(#self.coverageRebuilds, 0)
end

function TestVeafSkynetRadarRange:test_an_element_dcs_no_longer_holds_is_not_re_read()
  local radar = _radar("search", 0, true, 55000)
  veafSkynet.recheckRadarRange("red iads", _siteWithRadars("SA6", { radar }, false), 3)
  luaunit.assertEquals(radar.setupRangeDataCalls, 0)
  luaunit.assertEquals(#self.scheduled, 0)
end

function TestVeafSkynetRadarRange:test_a_site_joining_a_network_is_checked()
  -- The wiring: addGroupToNetwork is the single door, so the check belongs behind it rather than at
  -- each call site.
  dcs_mocks.reset()
  local savedTypes = veafSkynet.iadsSamUnitsTypes
  local savedMode = veafSkynet.GroupIntegrationMode
  veafSkynet.iadsSamUnitsTypes = { ["Kub 2P25 ln"] = true }
  veafSkynet.GroupIntegrationMode = veafSkynet.GroupIntegrationModes.Lenient
  local iads = _makeMockIads("red iads")
  iads.addSAMSite = function(_, groupName)
    return _siteWithRadars(groupName, { _radar("search", 0, true) }, true)
  end
  iads.buildRadarCoverage = function(_) end
  veafSkynet.structure["red iads"] = { iads = iads, coalitionID = coalition.side.RED, groups = {} }

  veafSkynet.addGroupToNetwork("red iads", _redSamGroup("LIVE-SAM", true), false, false, nil, true)

  local reReads = 0
  for _, entry in ipairs(self.scheduled) do
    if entry.fn == veafSkynet.recheckRadarRange then
      reReads = reReads + 1
    end
  end
  luaunit.assertEquals(reReads, 1, "a site joining the network with no radar range was not checked")

  veafSkynet.iadsSamUnitsTypes = savedTypes
  veafSkynet.GroupIntegrationMode = savedMode
  dcs_mocks.reset()
end

-- ---------------------------------------------------------------------------
-- FIX-SKYNET-CZ-RESPAWN-AND-RANGE ticket 03 — a removal rebuilds the coverage
-- ---------------------------------------------------------------------------
TestVeafSkynetCoverageAfterRemoval = {}

function TestVeafSkynetCoverageAfterRemoval:setUp()
  veafSkynet.structure = {}
  veafSkynet.lostUnits = {}
  self.coverageRebuilds = 0
end

function TestVeafSkynetCoverageAfterRemoval:tearDown()
  veafSkynet.structure = {}
  veafSkynet.lostUnits = {}
end

--- One network whose IADS counts how many times its coverage was rebuilt.
function TestVeafSkynetCoverageAfterRemoval:_network(samSites)
  local groups = {}
  for _, element in ipairs(samSites) do
    groups[element.dcsName] = { forceEwr = false }
  end
  local this = self
  veafSkynet.structure["red iads"] = {
    iads = {
      samSites = samSites,
      earlyWarningRadars = {},
      buildRadarCoverage = function(_)
        this.coverageRebuilds = this.coverageRebuilds + 1
      end,
    },
    coalitionID = coalition.side.RED,
    groups = groups,
  }
end

function TestVeafSkynetCoverageAfterRemoval:test_a_sweep_that_removes_something_rebuilds_the_coverage()
  -- The defect, measured on Tripack's log at 10:03:13: the EW radar still announced five sites in its
  -- covered area, four of which had left the network — and went on commanding them.
  self:_network({ _sweepableElement("CMBT_TESTCZ - SA6", "SA6-radar", false) })
  luaunit.assertEquals(veafSkynet.removeVanishedSites("red iads"), 1)
  luaunit.assertEquals(self.coverageRebuilds, 1)
end

function TestVeafSkynetCoverageAfterRemoval:test_a_sweep_that_removes_nothing_leaves_the_coverage_alone()
  -- The control: rebuilding the whole graph is O(n squared) on the elements, so it must not run on
  -- every sweep of an untouched network.
  self:_network({ _sweepableElement("LIVE-SAM", "SAM-radar", true) })
  luaunit.assertEquals(veafSkynet.removeVanishedSites("red iads"), 0)
  luaunit.assertEquals(self.coverageRebuilds, 0)
end

function TestVeafSkynetCoverageAfterRemoval:test_a_deactivated_network_is_not_woken_by_a_sweep()
  -- #261: `buildRadarCoverage` ends by telling every SAM site to reconsider its state, and an
  -- autonomous site with no live parent goes live — radar on. `deactivateNetwork` leaves the site
  -- list populated, so the periodic sweep reaches a network somebody switched off on purpose.
  self:_network({ _sweepableElement("CMBT_TESTCZ - SA6", "SA6-radar", false) })
  veafSkynet.structure["red iads"].deactivated = true
  luaunit.assertEquals(veafSkynet.removeVanishedSites("red iads"), 1, "the site must still be removed")
  luaunit.assertEquals(self.coverageRebuilds, 0, "a deactivated network was relit by the sweep")
end

function TestVeafSkynetCoverageAfterRemoval:test_a_deactivated_network_refuses_a_direct_rebuild()
  self:_network({})
  veafSkynet.structure["red iads"].deactivated = true
  luaunit.assertFalse(veafSkynet.rebuildRadarCoverage("red iads"))
  luaunit.assertEquals(self.coverageRebuilds, 0)
end

function TestVeafSkynetCoverageAfterRemoval:test_a_network_without_an_iads_does_not_raise()
  veafSkynet.structure["red iads"] = { coalitionID = coalition.side.RED, groups = {} }
  local ok = pcall(veafSkynet.rebuildRadarCoverage, "red iads")
  luaunit.assertTrue(ok)
  luaunit.assertFalse(veafSkynet.rebuildRadarCoverage("red iads"))
  luaunit.assertFalse(veafSkynet.rebuildRadarCoverage("no such network"))
end

function TestVeafSkynetCoverageAfterRemoval:test_a_coverage_rebuild_that_raises_is_reported_not_propagated()
  -- It is called right after corpses have been dropped, so it must survive an element that refuses a
  -- method rather than take the sweep down with it.
  veafSkynet.structure["red iads"] = {
    iads = {
      samSites = {},
      earlyWarningRadars = {},
      buildRadarCoverage = function(_)
        error("an element has left the mission")
      end,
    },
    coalitionID = coalition.side.RED,
    groups = {},
  }
  local ok, result = pcall(veafSkynet.rebuildRadarCoverage, "red iads")
  luaunit.assertTrue(ok, "a raising coverage rebuild must be reported, not propagated")
  luaunit.assertFalse(result)
end

-- ---------------------------------------------------------------------------
-- FIX-SKYNET-CZ-RESPAWN-AND-RANGE ticket 02 — a mission feature's respawn joins the IADS
-- ---------------------------------------------------------------------------
TestVeafSkynetIntegrateMissionSpawn = {}

function TestVeafSkynetIntegrateMissionSpawn:setUp()
  dcs_mocks.reset()
  self._savedSchedule = veaf.scheduleFunction
  self._savedInitialized = veafSkynet.initialized
  self.scheduled = {}
  local scheduled = self.scheduled
  veaf.scheduleFunction = function(fn, args, when)
    table.insert(scheduled, { fn = fn, args = args, when = when })
    return #scheduled
  end
  veafSkynet.initialized = true
  veafSkynet.declaredSpawns = {}
  veafSkynet.iadsSamUnitsTypes = { ["Kub 2P25 ln"] = true }
  veafSkynet.iadsEwrUnitsTypes = {}
  veafSkynet.GroupIntegrationMode = veafSkynet.GroupIntegrationModes.Lenient
  self.enrolled = {}
  local enrolled = self.enrolled
  self.iads = _makeMockIads("red iads")
  self.iads.addSAMSite = function(_, groupName)
    table.insert(enrolled, groupName)
    return { dcsName = groupName }
  end
  self.iads.buildRadarCoverage = function(_) end
  -- dynamicSpawn deliberately **off**: that is the shipped default, and the configuration Tripack ran.
  veafSkynet.structure["red iads"] = {
    iads = self.iads,
    coalitionID = coalition.side.RED,
    groups = {},
    dynamicSpawn = false,
  }
end

function TestVeafSkynetIntegrateMissionSpawn:tearDown()
  veaf.scheduleFunction = self._savedSchedule
  veafSkynet.initialized = self._savedInitialized
  veafSkynet.structure = {}
  veafSkynet.declaredSpawns = {}
  dcs_mocks.reset()
end

function TestVeafSkynetIntegrateMissionSpawn:test_a_respawned_group_is_scheduled_for_integration()
  _redSamGroup("TESTCZ [r] TESTCZ - SA6#10262", true)
  veafSkynet.integrateMissionSpawn("TESTCZ [r] TESTCZ - SA6#10262")
  luaunit.assertEquals(#self.scheduled, 1)
  luaunit.assertEquals(self.scheduled[1].fn, veafSkynet._integrateSpawn)
  luaunit.assertEquals(self.scheduled[1].args[1], "TESTCZ [r] TESTCZ - SA6#10262")
  luaunit.assertEquals(self.scheduled[1].args[2], coalition.side.RED)
  luaunit.assertFalse(self.scheduled[1].args[3], "a mission respawn must not require the dynamicSpawn flag")
end

function TestVeafSkynetIntegrateMissionSpawn:test_it_joins_a_network_that_does_not_integrate_dynamic_spawns()
  -- The defect: with `dynamicSpawn` off — the default — nothing put a deactivated zone's air defences
  -- back into the network once the #946 sweep had removed them.
  _redSamGroup("TESTCZ [r] TESTCZ - SA6#10262", true)
  veafSkynet._integrateSpawn("TESTCZ [r] TESTCZ - SA6#10262", coalition.side.RED, false)
  luaunit.assertEquals(self.enrolled, { "TESTCZ [r] TESTCZ - SA6#10262" })
end

function TestVeafSkynetIntegrateMissionSpawn:test_the_birth_event_path_still_honours_the_flag()
  -- The other half, and the reason the flag check moved rather than disappeared: the birth-event
  -- handler sees every group DCS reports, third-party scripts included, so #151 and #261 still hold.
  _redSamGroup("SOMEONE-ELSES-SAM", true)
  veafSkynet._integrateSpawn("SOMEONE-ELSES-SAM", coalition.side.RED, true)
  luaunit.assertEquals(#self.enrolled, 0)
end

function TestVeafSkynetIntegrateMissionSpawn:test_it_leaves_the_work_to_a_network_that_integrates_spawns()
  -- #151's rule: the two paths are exclusive. With the flag on, the birth-event handler is armed and
  -- `coalition.addGroup` fires the event, so this path must not ask for a second integration.
  veafSkynet.structure["red iads"].dynamicSpawn = true
  _redSamGroup("TESTCZ [r] TESTCZ - SA6#10262", true)
  veafSkynet.integrateMissionSpawn("TESTCZ [r] TESTCZ - SA6#10262")
  luaunit.assertEquals(#self.scheduled, 0)
end

function TestVeafSkynetIntegrateMissionSpawn:test_a_group_that_is_gone_is_not_integrated()
  _redSamGroup("DEAD-ON-ARRIVAL", false)
  veafSkynet.integrateMissionSpawn("DEAD-ON-ARRIVAL")
  luaunit.assertEquals(#self.scheduled, 0)
end

function TestVeafSkynetIntegrateMissionSpawn:test_nothing_happens_before_the_module_is_initialised()
  _redSamGroup("TOO-EARLY", true)
  veafSkynet.initialized = false
  veafSkynet.integrateMissionSpawn("TOO-EARLY")
  luaunit.assertEquals(#self.scheduled, 0)
end

function TestVeafSkynetIntegrateMissionSpawn:test_a_nil_group_name_is_ignored()
  local ok = pcall(veafSkynet.integrateMissionSpawn, nil)
  luaunit.assertTrue(ok)
  luaunit.assertEquals(#self.scheduled, 0)
end

function TestVeafSkynetIntegrateMissionSpawn:test_a_spawn_declared_out_of_the_iads_stays_out()
  -- `skynet false` is a per-spawn statement, and this path must not override it either.
  _redSamGroup("CONVOY", true)
  veafSkynet.declaredSpawns["CONVOY"] = false
  veafSkynet._integrateSpawn("CONVOY", coalition.side.RED, false)
  luaunit.assertEquals(#self.enrolled, 0)
end

os.exit(luaunit.LuaUnit.run())
