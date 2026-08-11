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
    if v == "barrels_cargo" then
      found = true
    end
  end
  luaunit.assertTrue(found)
end

function TestVeafTransportCargoTypes:test_contains_uh1h_cargo()
  local found = false
  for _, v in ipairs(veafTransportMission.CargoTypes) do
    if v == "uh1h_cargo" then
      found = true
    end
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

-- Stubs for symbols that are referenced inside transport mission functions
-- but are not part of the core modules loaded above.
veafSpawn = veafSpawn or {}
veafSpawn.doSpawnGroup = veafSpawn.doSpawnGroup or function(...) end

-- Helper: return true if a unit type appears in a group definition's units list.
local function hasUnit(groupDef, unitType)
  for _, u in ipairs(groupDef and groupDef.units or {}) do
    if u[1] == unitType then
      return true
    end
  end
  return false
end

veafNamedPoints = {
  getPoint = function(name)
    return nil
  end,
  namePoint = function(...) end,
}

-- ---------------------------------------------------------------------------
-- TestVeafTransportMarkTextAnalysisKeywords
-- ---------------------------------------------------------------------------
TestVeafTransportMarkTextAnalysisKeywords = {}

function TestVeafTransportMarkTextAnalysisKeywords:test_password_keyword()
  local r = veafTransportMission.markTextAnalysis("_transport, password mysecret")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.password, "mysecret")
end

function TestVeafTransportMarkTextAnalysisKeywords:test_defense_keyword()
  local r = veafTransportMission.markTextAnalysis("_transport, defense 3")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.defense, 3)
end

function TestVeafTransportMarkTextAnalysisKeywords:test_blocade_keyword()
  local r = veafTransportMission.markTextAnalysis("_transport, blocade 2")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.blocade, 2)
end

function TestVeafTransportMarkTextAnalysisKeywords:test_from_keyword()
  local r = veafTransportMission.markTextAnalysis("_transport, from HOME")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.from, "HOME")
end

-- ---------------------------------------------------------------------------
-- TestVeafTransportMarkTextAnalysisBadParameters
--
-- FIX-MARKER-PARAM-CRASHES: this module carried three copies of the `tonumber(val) <= 5`
-- crash VMR-019 fixed in veafCasMission — the same parameter names, the same bounds, and
-- none of the fix, because the fix reached one copy of the code and there were several.
-- ---------------------------------------------------------------------------
TestVeafTransportMarkTextAnalysisBadParameters = {}

function TestVeafTransportMarkTextAnalysisBadParameters:test_size_without_value_keeps_default()
  local r = veafTransportMission.markTextAnalysis("_transport, size")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.size, 1)
end

function TestVeafTransportMarkTextAnalysisBadParameters:test_size_non_numeric_keeps_default()
  local r = veafTransportMission.markTextAnalysis("_transport, size banana")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.size, 1)
end

function TestVeafTransportMarkTextAnalysisBadParameters:test_defense_without_value_keeps_default()
  local r = veafTransportMission.markTextAnalysis("_transport, defense")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.defense, 0)
end

function TestVeafTransportMarkTextAnalysisBadParameters:test_defense_non_numeric_keeps_default()
  local r = veafTransportMission.markTextAnalysis("_transport, defense banana")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.defense, 0)
end

function TestVeafTransportMarkTextAnalysisBadParameters:test_blocade_without_value_keeps_default()
  local r = veafTransportMission.markTextAnalysis("_transport, blocade")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.blocade, 0)
end

function TestVeafTransportMarkTextAnalysisBadParameters:test_blocade_non_numeric_keeps_default()
  local r = veafTransportMission.markTextAnalysis("_transport, blocade banana")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.blocade, 0)
end

-- Out-of-range values stay *ignored* rather than clamped — VMR-019 decided that for the
-- same parameters in veafCasMission and this lot does not revisit it.
function TestVeafTransportMarkTextAnalysisBadParameters:test_size_out_of_range_is_ignored()
  local r = veafTransportMission.markTextAnalysis("_transport, size 42")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.size, 1)
end

-- ---------------------------------------------------------------------------
-- TestVeafTransportGenerateEnemy
-- ---------------------------------------------------------------------------
TestVeafTransportGenerateEnemy = {}

function TestVeafTransportGenerateEnemy:setUp()
  self._origDoSpawnGroup = veafSpawn.doSpawnGroup
  self._capturedGroupDef = nil
  veafSpawn.doSpawnGroup = function(pos, hdg, groupDef, ...)
    self._capturedGroupDef = groupDef
  end
end

function TestVeafTransportGenerateEnemy:tearDown()
  veafSpawn.doSpawnGroup = self._origDoSpawnGroup
end

function TestVeafTransportGenerateEnemy:test_defense_level_0()
  veafTransportMission.generateEnemyDefenseGroup({ x = 0, y = 0, z = 0 }, "EnemyGrp_L0", 0)
  luaunit.assertNotNil(self._capturedGroupDef)
  luaunit.assertTrue(hasUnit(self._capturedGroupDef, "GAZ-3308"), "defense=0 must use GAZ-3308")
end

function TestVeafTransportGenerateEnemy:test_defense_level_1()
  veafTransportMission.generateEnemyDefenseGroup({ x = 0, y = 0, z = 0 }, "EnemyGrp_L1", 1)
  luaunit.assertNotNil(self._capturedGroupDef, "doSpawnGroup must be called for defense=1")
end

function TestVeafTransportGenerateEnemy:test_defense_level_3()
  veafTransportMission.generateEnemyDefenseGroup({ x = 0, y = 0, z = 0 }, "EnemyGrp_L3", 3)
  luaunit.assertNotNil(self._capturedGroupDef, "doSpawnGroup must be called for defense=3")
end

function TestVeafTransportGenerateEnemy:test_defense_level_5()
  veafTransportMission.generateEnemyDefenseGroup({ x = 0, y = 0, z = 0 }, "EnemyGrp_L5", 5)
  luaunit.assertNotNil(self._capturedGroupDef, "doSpawnGroup must be called for defense=5")
end

-- ---------------------------------------------------------------------------
-- TestVeafTransportFunctions
-- ---------------------------------------------------------------------------
TestVeafTransportFunctions = {}

function TestVeafTransportFunctions:test_generateFriendlyGroup_runs()
  veafTransportMission.generateFriendlyGroup({ x = 0, y = 0, z = 0 })
  luaunit.assertTrue(true)
end

function TestVeafTransportFunctions:test_generateTransportMission_nil_from()
  veafTransportMission.generateTransportMission({ x = 0, y = 0, z = 0 }, 1, 0, 0, nil)
  luaunit.assertTrue(true)
end

function TestVeafTransportFunctions:test_generateTransportMission_unknown_from()
  veafTransportMission.generateTransportMission({ x = 0, y = 0, z = 0 }, 1, 0, 0, "UNKNOWN_NAMED_POINT")
  luaunit.assertTrue(true)
end

function TestVeafTransportFunctions:test_help_runs_without_error()
  veafTransportMission.help(nil)
  luaunit.assertTrue(true)
end

function TestVeafTransportFunctions:test_endTransportOfCargo_runs()
  veafTransportMission.endTransportOfCargo("TestCargo")
  luaunit.assertTrue(true)
end

function TestVeafTransportFunctions:test_resetAllCargoes_runs()
  veafTransportMission.resetAllCargoes()
  luaunit.assertTrue(true)
end

function TestVeafTransportFunctions:test_initializeAllHelosInCTLD_runs()
  veafTransportMission.initializeAllHelosInCTLD()
  luaunit.assertTrue(true)
end

function TestVeafTransportFunctions:test_initializeAllLogisticInCTLD_runs()
  veafTransportMission.initializeAllLogisticInCTLD()
  luaunit.assertTrue(true)
end

-- ---------------------------------------------------------------------------
-- TestVeafTransportAdvanced
-- Covers generateTransportMission body, cleanupAfterMission, "already exists"
-- path, and generateEnemyDefenseGroup with deterministic random.
-- ---------------------------------------------------------------------------
TestVeafTransportAdvanced = {}

function TestVeafTransportAdvanced:setUp()
  self._origGetPoint = veafNamedPoints.getPoint
  self._origSpawnCargo = veafSpawn.doSpawnCargo
  self._origDoSpawnGroup = veafSpawn.doSpawnGroup
  self._origAddSecured = veafRadio.addSecuredCommandToSubmenu
  self._origRefreshRadio = veafRadio.refreshRadioMenu
  self._origDelCommand = veafRadio.delCommand
  self._origDelSubmenu = veafRadio.delSubmenu
  self._origTaskID = veafTransportMission.friendlyGroupAliveCheckTaskID
  self._origRandom = math.random
  self._capturedGroupDef = nil

  -- Provide a real named point far enough from the target spot
  veafNamedPoints.getPoint = function(name)
    return { x = 0, z = 0, y = 0 }
  end
  veafSpawn.doSpawnCargo = function(...) end
  veafSpawn.doSpawnGroup = function(pos, hdg, groupDef, ...)
    self._capturedGroupDef = groupDef
  end

  veafRadio.addSecuredCommandToSubmenu = function(...) end
  veafRadio.refreshRadioMenu = function(...) end
  veafRadio.delCommand = function(...) end
  veafRadio.delSubmenu = function(...) end

  -- Deterministic: math.random(n) → 1, math.random(a,b) → a
  math.random = function(a, b)
    if not a then
      return 0.5
    elseif not b then
      return 1
    else
      return a
    end
  end
end

function TestVeafTransportAdvanced:tearDown()
  veafNamedPoints.getPoint = self._origGetPoint
  veafSpawn.doSpawnCargo = self._origSpawnCargo
  veafSpawn.doSpawnGroup = self._origDoSpawnGroup
  veafRadio.addSecuredCommandToSubmenu = self._origAddSecured
  veafRadio.refreshRadioMenu = self._origRefreshRadio
  veafRadio.delCommand = self._origDelCommand
  veafRadio.delSubmenu = self._origDelSubmenu
  veafTransportMission.friendlyGroupAliveCheckTaskID = self._origTaskID
  math.random = self._origRandom
end

-- Covers lines 357-358: "mission already exists" early-return path.
function TestVeafTransportAdvanced:test_already_exists_returns_early()
  veafTransportMission.friendlyGroupAliveCheckTaskID = "EXISTING_TASK"
  veafTransportMission.generateTransportMission({ x = 0, y = 0, z = 0 }, 1, 0, 0, "HOME")
  luaunit.assertEquals(veafTransportMission.friendlyGroupAliveCheckTaskID, "EXISTING_TASK")
end

-- Covers lines 372-496 (body when from is valid) + cleanupAfterMission (615-678).
-- targetSpot is 50 km from startPoint so routeDistance > MinimumRouteDistance.
function TestVeafTransportAdvanced:test_generateTransportMission_valid_from_runs()
  veafTransportMission.generateTransportMission({ x = 50000, y = 0, z = 50000 }, 1, 0, 0, "HOME_BASE")
  luaunit.assertTrue(true)
end

-- Covers generateEnemyDefenseGroup BTR-80 branch (line 300): defense=2.
-- With setUp's math.random(n)→1, defenseLevel>2 is FALSE → falls to BTR-80.
function TestVeafTransportAdvanced:test_generate_enemy_defense_btrtwo()
  veafTransportMission.generateEnemyDefenseGroup({ x = 0, y = 0, z = 0 }, "EnemyGrp_BTR", 2)
  luaunit.assertNotNil(self._capturedGroupDef)
  luaunit.assertTrue(hasUnit(self._capturedGroupDef, "BTR-80"), "defense=2 must include BTR-80")
end

-- Covers SA-18 Igla branch (lines 312-313): defense=3, random(100)=100 so >66.
function TestVeafTransportAdvanced:test_generate_enemy_defense_igla()
  math.random = function(a, b)
    if not a then
      return 0.5
    elseif not b then
      return a
    else
      return a
    end
  end
  veafTransportMission.generateEnemyDefenseGroup({ x = 0, y = 0, z = 0 }, "EnemyGrp_Igla", 3)
  luaunit.assertNotNil(self._capturedGroupDef)
  luaunit.assertTrue(hasUnit(self._capturedGroupDef, "SA-18 Igla comm"), "defense=3 must include SA-18 Igla comm")
end

-- Covers SA-18 Igla-S (308-309) and ZU-23 (324): defense=4, random(100)=100.
function TestVeafTransportAdvanced:test_generate_enemy_defense_igla_s_and_zu23()
  math.random = function(a, b)
    if not a then
      return 0.5
    elseif not b then
      return a
    else
      return a
    end
  end
  veafTransportMission.generateEnemyDefenseGroup({ x = 0, y = 0, z = 0 }, "EnemyGrp_IglaS", 4)
  luaunit.assertNotNil(self._capturedGroupDef)
  luaunit.assertTrue(hasUnit(self._capturedGroupDef, "SA-18 Igla-S comm"), "defense=4 must include SA-18 Igla-S comm")
  luaunit.assertTrue(hasUnit(self._capturedGroupDef, "Ural-375 ZU-23"), "defense=4 must include Ural-375 ZU-23")
end

-- Covers ZSU-23-4 Shilka branch (line 321): defense=5, random(100)=100.
function TestVeafTransportAdvanced:test_generate_enemy_defense_shilka()
  math.random = function(a, b)
    if not a then
      return 0.5
    elseif not b then
      return a
    else
      return a
    end
  end
  veafTransportMission.generateEnemyDefenseGroup({ x = 0, y = 0, z = 0 }, "EnemyGrp_Shilka", 5)
  luaunit.assertNotNil(self._capturedGroupDef)
  luaunit.assertTrue(hasUnit(self._capturedGroupDef, "ZSU-23-4 Shilka"), "defense=5 must include ZSU-23-4 Shilka")
end

os.exit(luaunit.LuaUnit.run())
