--- Tests for veafTransportMission.lua — constants, CargoTypes, markTextAnalysis.
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
dofile(src .. "/veafAirbases.lua")
dofile(src .. "/veafI18n.lua")
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

-- FIX-MARKER-PARAM-CRASHES-2: the string keywords were never probed by the first lot, which
-- tried the numeric ones and stopped. `from` raised in its own log line.
function TestVeafTransportMarkTextAnalysisKeywords:test_valueless_from_leaves_the_field_nil()
  local r = veafTransportMission.markTextAnalysis("_transport, from")
  luaunit.assertNotNil(r)
  luaunit.assertNil(r.from)
end

function TestVeafTransportMarkTextAnalysisKeywords:test_valueless_password_leaves_the_field_nil()
  local r = veafTransportMission.markTextAnalysis("_transport, password")
  luaunit.assertNotNil(r)
  luaunit.assertNil(r.password)
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
-- TestVeafTransportCharacterisation
--
-- REFACTOR-MARKER-PARSER ticket 01: what this parser does TODAY, measured, so the shared
-- parser can be proved to change nothing.
-- ---------------------------------------------------------------------------
TestVeafTransportCharacterisation = {}

-- Unlike veafMove or veafRadio, the bare keyphrase IS a command here: no sub-verb.
function TestVeafTransportCharacterisation:test_bare_keyphrase_is_a_command()
  local r = veafTransportMission.markTextAnalysis("_transport")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.transportmission)
end

function TestVeafTransportCharacterisation:test_keyphrase_is_case_insensitive()
  luaunit.assertNotNil(veafTransportMission.markTextAnalysis("_TRANSPORT"))
end

-- The keyphrase is matched anywhere in the text, not anchored at the start.
function TestVeafTransportCharacterisation:test_keyphrase_is_found_anywhere_in_the_text()
  luaunit.assertNotNil(veafTransportMission.markTextAnalysis("please _transport now"))
end

function TestVeafTransportCharacterisation:test_empty_text_returns_nil()
  luaunit.assertNil(veafTransportMission.markTextAnalysis(""))
end

function TestVeafTransportCharacterisation:test_another_modules_keyphrase_returns_nil()
  luaunit.assertNil(veafTransportMission.markTextAnalysis("_cas, size 3"))
end

-- An unknown key is ignored in silence and leaves every default intact.
-- FEAT-SPAWN-OPTION-VALIDATION renamed this: an unknown keyword is no longer ignored, it is
-- collected so the caller can name it to the pilot and abort. What the original test proved and
-- this one still proves: the **recognised** options are untouched by the presence of a bad one.
function TestVeafTransportCharacterisation:test_an_unknown_keyword_is_collected_not_ignored()
  local r = veafTransportMission.markTextAnalysis("_transport, banana 3")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.size, 1)
  luaunit.assertEquals(r.defense, 0)
  luaunit.assertEquals(r.unknownParameters[1].key, "banana")
  luaunit.assertEquals(#r.unknownParameters, 1)
end

-- Valueless string keywords are covered by TestVeafTransportMarkTextAnalysisKeywords above,
-- where FIX-MARKER-PARAM-CRASHES-2 put them: `from` used to raise there.

-- Every matching rule runs: this parser chains with separate `if`s, not `elseif`.
function TestVeafTransportCharacterisation:test_all_keywords_apply_in_one_command()
  local r = veafTransportMission.markTextAnalysis("_transport, size 4, defense 2, blocade 3, from BASE")
  luaunit.assertEquals(r.size, 4)
  luaunit.assertEquals(r.defense, 2)
  luaunit.assertEquals(r.blocade, 3)
  luaunit.assertEquals(r.from, "BASE")
end

-- `defense` and `blocade` accept 0 where `size` starts at 1 — asymmetric bounds, deliberate.
function TestVeafTransportCharacterisation:test_zero_is_accepted_by_defense_but_not_by_size()
  luaunit.assertEquals(veafTransportMission.markTextAnalysis("_transport, defense 0").defense, 0)
  luaunit.assertEquals(veafTransportMission.markTextAnalysis("_transport, size 0").size, 1)
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

-- ---------------------------------------------------------------------------
-- TestVeafTransportSecurity — FIX-DOCAUDIT-CODE 02
--
-- `onEventMarkChange` called `checkSecurity_L1(options.password)` with **no marker id**, so
-- `getMarkerSecurityLevel(nil)` returned -1 and the identity path could never grant anything: a
-- pilot listed as SENIOR_PILOT in `veaf-pilots.txt` — the whole point of the listing — still had
-- to type the password on every `_transport`. Every other marker command passes its marker id;
-- this one predates the per-player model and was never rewired, which is why `veafSecurity.md`'s
-- "nothing changes for a listed pilot" was false precisely here.
-- ---------------------------------------------------------------------------
TestVeafTransportSecurity = {}

function TestVeafTransportSecurity:setUp()
  self.savedCheck = veafSecurity.checkSecurity_L1
  self.savedGenerate = veafTransportMission.generateTransportMission
  self.seen = {}
  self.generated = false
  local seen = self.seen
  -- Stand in for the real check: record what it was handed, and grant on identity alone (a
  -- listed pilot with no password), which is the path the missing marker id disabled.
  veafSecurity.checkSecurity_L1 = function(password, markId)
    table.insert(seen, { password = password, markId = markId })
    return markId ~= nil or password ~= nil
  end
  veafTransportMission.generateTransportMission = function()
    self.generated = true
  end
end

function TestVeafTransportSecurity:tearDown()
  veafSecurity.checkSecurity_L1 = self.savedCheck
  veafTransportMission.generateTransportMission = self.savedGenerate
end

function TestVeafTransportSecurity:_fireMarker(text, idx)
  veafTransportMission.onEventMarkChange({ x = 0, y = 0, z = 0 }, { text = text, idx = idx })
end

function TestVeafTransportSecurity:test_the_marker_id_reaches_the_security_check()
  self:_fireMarker("_transport", 4242)

  luaunit.assertEquals(#self.seen, 1, "the security check must be consulted")
  luaunit.assertEquals(self.seen[1].markId, 4242, "the check cannot identify the author without it")
end

function TestVeafTransportSecurity:test_a_listed_pilot_needs_no_password()
  self:_fireMarker("_transport", 4242)

  luaunit.assertTrue(self.generated, "an identified author with a sufficient level must be let through")
end

function TestVeafTransportSecurity:test_an_unidentified_author_without_password_is_still_refused()
  -- No marker id at all: nothing identifies the author, and no password was given.
  self:_fireMarker("_transport", nil)

  luaunit.assertFalse(self.generated, "an unidentified author with no password must be refused")
end

-- ---------------------------------------------------------------------------
-- TestVeafTransportAirbaseLogistics — FEAT-CTLD-AIRBASE-LOGISTICS ticket 01
--
-- initializeAllLogisticInCTLD registers every AIRDROME of veafAirbases.Airbases as a CTLD
-- logistic zone through the public registerFOBAsLogistic API. There is no DCS here, so the
-- airbase list is faked per test — the convention test_veafAirbases.lua states — and CTLD is the
-- recording mock of dcs_mocks.lua.
-- ---------------------------------------------------------------------------

local function makeStand(x, z, y)
  return { vTerminalPos = { x = x, y = y or 100, z = z } }
end

--- A live-handle fake. getPoint() answers a recognisable trap value: if the zone ever sits on
--- it, the reference point was used where a parking stand was required.
local function makeDcsAirbase(coalition, stands)
  return {
    getCoalition = function()
      return coalition
    end,
    getParking = function()
      return stands
    end,
    getPoint = function()
      return { x = -99999, y = 0, z = -99999 }
    end,
  }
end

local function makeAirbaseRecord(name, category, dcsAirbase)
  return { Name = name, DisplayName = name, Category = category, DcsAirbase = dcsAirbase, Runways = {} }
end

local function zoneManagerCalls(method)
  local found = {}
  for _, call in ipairs(CTLDZoneManager._instance.calls) do
    if call.method == method then
      table.insert(found, call)
    end
  end
  return found
end

local function logsContaining(level, needle)
  local found = {}
  for _, line in ipairs(dcs_mocks.logs) do
    if (level == nil or line.level == level) and line.text:find(needle, 1, true) then
      table.insert(found, line)
    end
  end
  return found
end

TestVeafTransportAirbaseLogistics = {}

function TestVeafTransportAirbaseLogistics:setUp()
  dcs_mocks.reset()
  veafAirbases.Airbases = {}
  veafTransportMission.airbaseLogisticState = {}
  veafTransportMission.airbaseLogisticsTaskId = nil
end

function TestVeafTransportAirbaseLogistics:tearDown()
  -- The fakes must not leak into the next class: initializeAllLogisticInCTLD walks whatever
  -- veafAirbases.Airbases holds, and a fake record left here would be walked again.
  veafAirbases.Airbases = nil
  veafTransportMission.airbaseLogisticState = {}
  veafTransportMission.airbaseLogisticsTaskId = nil
  dcs_mocks.reset()
end

--- Three stands in a row: the centroid sits near x=483, and the real stand nearest it is 450.
local function threeStands()
  return { makeStand(0, 0), makeStand(1000, 0), makeStand(450, 0, 120) }
end

function TestVeafTransportAirbaseLogistics:test_airdrome_registers_at_250m_with_its_own_coalition()
  veafAirbases.Airbases = { makeAirbaseRecord("Ramstein", Airbase.Category.AIRDROME, makeDcsAirbase(coalition.side.BLUE, threeStands())) }

  veafTransportMission.initializeAllLogisticInCTLD()

  local calls = zoneManagerCalls("registerFOBAsLogistic")
  luaunit.assertEquals(#calls, 1)
  luaunit.assertEquals(calls[1].args[1], "AB_Ramstein") -- exact name, no leading space
  luaunit.assertEquals(calls[1].args[3], 250)
  luaunit.assertEquals(calls[1].args[4], coalition.side.BLUE) -- its OWN coalition, never 0
end

function TestVeafTransportAirbaseLogistics:test_red_airdrome_registers_under_red()
  veafAirbases.Airbases = { makeAirbaseRecord("Krasnodar", Airbase.Category.AIRDROME, makeDcsAirbase(coalition.side.RED, threeStands())) }

  veafTransportMission.initializeAllLogisticInCTLD()

  local calls = zoneManagerCalls("registerFOBAsLogistic")
  luaunit.assertEquals(#calls, 1)
  luaunit.assertEquals(calls[1].args[4], coalition.side.RED)
  local state = veafTransportMission.airbaseLogisticState["Krasnodar"]
  luaunit.assertEquals(state.class, "A") -- red-held from the start is class A too: red is mirrored
  luaunit.assertTrue(state.registered)
end

function TestVeafTransportAirbaseLogistics:test_ship_and_helipad_do_not_register()
  veafAirbases.Airbases = {
    makeAirbaseRecord("Carrier", Airbase.Category.SHIP, makeDcsAirbase(coalition.side.BLUE, threeStands())),
    makeAirbaseRecord("FARP Paris", Airbase.Category.HELIPAD, makeDcsAirbase(coalition.side.BLUE, threeStands())),
  }

  veafTransportMission.initializeAllLogisticInCTLD()

  luaunit.assertEquals(#zoneManagerCalls("registerFOBAsLogistic"), 0)
  luaunit.assertEquals(next(veafTransportMission.airbaseLogisticState), nil)
end

function TestVeafTransportAirbaseLogistics:test_point_is_a_real_stand_neither_centroid_nor_reference_point()
  veafAirbases.Airbases = { makeAirbaseRecord("Ramstein", Airbase.Category.AIRDROME, makeDcsAirbase(coalition.side.BLUE, threeStands())) }

  veafTransportMission.initializeAllLogisticInCTLD()

  local calls = zoneManagerCalls("registerFOBAsLogistic")
  luaunit.assertEquals(#calls, 1)
  local point = calls[1].args[2]
  luaunit.assertEquals(point.x, 450) -- the stand nearest the centroid (~483), not the centroid itself
  luaunit.assertEquals(point.y, 120) -- the stand's own altitude
  luaunit.assertEquals(point.z, 0)
  luaunit.assertNotEquals(point.x, -99999) -- and never Airbase:getPoint()
end

function TestVeafTransportAirbaseLogistics:test_empty_parking_skips_with_a_warning_naming_the_airfield()
  veafAirbases.Airbases = { makeAirbaseRecord("NoParking", Airbase.Category.AIRDROME, makeDcsAirbase(coalition.side.BLUE, {})) }

  veafTransportMission.initializeAllLogisticInCTLD()

  luaunit.assertEquals(#zoneManagerCalls("registerFOBAsLogistic"), 0)
  luaunit.assertTrue(#logsContaining("W", "NoParking") > 0, "the skip must warn, naming the airfield")
  luaunit.assertFalse(veafTransportMission.airbaseLogisticState["NoParking"].registered)
end

function TestVeafTransportAirbaseLogistics:test_a_stand_already_covered_registers_nothing()
  veafAirbases.Airbases = { makeAirbaseRecord("Ramstein", Airbase.Category.AIRDROME, makeDcsAirbase(coalition.side.BLUE, threeStands())) }
  dcs_mocks.logisticZonesAtPoint = { { name = "LGZ_mine", coalition = coalition.side.BLUE, radius = 1000 } }

  veafTransportMission.initializeAllLogisticInCTLD()

  luaunit.assertEquals(#zoneManagerCalls("getLogisticZonesAtPoint"), 1, "the point must be checked before registering")
  luaunit.assertEquals(#zoneManagerCalls("registerFOBAsLogistic"), 0)
  luaunit.assertFalse(veafTransportMission.airbaseLogisticState["Ramstein"].registered)
end

function TestVeafTransportAirbaseLogistics:test_a_refused_registration_is_warned_not_swallowed()
  veafAirbases.Airbases = { makeAirbaseRecord("Ramstein", Airbase.Category.AIRDROME, makeDcsAirbase(coalition.side.BLUE, threeStands())) }
  dcs_mocks.registerFOBAsLogisticResult = false -- a name that already exists makes CTLD return false

  veafTransportMission.initializeAllLogisticInCTLD()

  luaunit.assertEquals(#zoneManagerCalls("registerFOBAsLogistic"), 1)
  luaunit.assertFalse(veafTransportMission.airbaseLogisticState["Ramstein"].registered)
  luaunit.assertTrue(#logsContaining("W", "AB_Ramstein") > 0, "the refusal must be logged at our level, naming the zone")
end

function TestVeafTransportAirbaseLogistics:test_nothing_registers_when_ctld_is_not_ready()
  veafAirbases.Airbases = { makeAirbaseRecord("Ramstein", Airbase.Category.AIRDROME, makeDcsAirbase(coalition.side.BLUE, threeStands())) }
  CTLDConfig._instance.isLoaded = false

  veafTransportMission.initializeAllLogisticInCTLD()

  luaunit.assertEquals(#zoneManagerCalls("registerFOBAsLogistic"), 0)
  luaunit.assertEquals(next(veafTransportMission.airbaseLogisticState), nil, "no state is snapshotted without CTLD")
end

function TestVeafTransportAirbaseLogistics:test_neutral_airdrome_is_class_b_and_not_registered()
  veafAirbases.Airbases =
    { makeAirbaseRecord("NeutralField", Airbase.Category.AIRDROME, makeDcsAirbase(coalition.side.NEUTRAL, threeStands())) }

  veafTransportMission.initializeAllLogisticInCTLD()

  luaunit.assertEquals(#zoneManagerCalls("registerFOBAsLogistic"), 0)
  local state = veafTransportMission.airbaseLogisticState["NeutralField"]
  luaunit.assertNotNil(state)
  luaunit.assertEquals(state.class, "B") -- snapshot taken even for a field with nothing to register yet
  luaunit.assertFalse(state.registered)
end

function TestVeafTransportAirbaseLogistics:test_a_blue_from_the_start_field_is_class_a()
  veafAirbases.Airbases = { makeAirbaseRecord("Ramstein", Airbase.Category.AIRDROME, makeDcsAirbase(coalition.side.BLUE, threeStands())) }

  veafTransportMission.initializeAllLogisticInCTLD()

  luaunit.assertEquals(veafTransportMission.airbaseLogisticState["Ramstein"].class, "A")
end

function TestVeafTransportAirbaseLogistics:test_the_summary_line_counts_registered_and_skipped()
  veafAirbases.Airbases = {
    makeAirbaseRecord("Ramstein", Airbase.Category.AIRDROME, makeDcsAirbase(coalition.side.BLUE, threeStands())),
    makeAirbaseRecord("NoParking", Airbase.Category.AIRDROME, makeDcsAirbase(coalition.side.BLUE, {})),
  }

  veafTransportMission.initializeAllLogisticInCTLD()

  luaunit.assertTrue(#logsContaining("I", "1 airdrome(s) registered") > 0)
  luaunit.assertTrue(#logsContaining("I", "1 skipped") > 0)
end

-- The class snapshot is taken on the FIRST evaluation and survives a re-initialisation: a field
-- captured between two calls must not be reclassified by the second one (PRD risk, ticket 01).
function TestVeafTransportAirbaseLogistics:test_a_second_run_leaves_the_snapshot_alone()
  local dcsAirbase = makeDcsAirbase(coalition.side.BLUE, threeStands())
  veafAirbases.Airbases = { makeAirbaseRecord("Ramstein", Airbase.Category.AIRDROME, dcsAirbase) }

  veafTransportMission.initializeAllLogisticInCTLD()
  -- the field is captured in flight, then the mission script calls the initialiser again
  dcsAirbase.getCoalition = function()
    return coalition.side.RED
  end
  veafTransportMission.initializeAllLogisticInCTLD()

  local state = veafTransportMission.airbaseLogisticState["Ramstein"]
  luaunit.assertEquals(state.class, "A")
  luaunit.assertEquals(state.coalition, coalition.side.BLUE)
  luaunit.assertEquals(#zoneManagerCalls("registerFOBAsLogistic"), 1, "a second run must not register twice")
end

-- ---------------------------------------------------------------------------
-- TestVeafTransportAirbaseLogisticsTick — FEAT-CTLD-AIRBASE-LOGISTICS ticket 02
--
-- The 30-second tick follows the class-A airfields initializeAllLogisticInCTLD registered. Each
-- test builds the real state through the initialiser, flips the airfield's live coalition the way
-- a capture in flight would, then drives updateAirbaseLogisticsZones directly — an injected clock,
-- never a sleep — and asserts against the recording CTLD mock and the pilot messages.
-- ---------------------------------------------------------------------------

--- A live-handle fake whose coalition can be flipped, or made to raise, mid-test.
local function mutableDcsAirbase(initialCoalition, stands)
  local current = initialCoalition
  local raising = false
  return {
    getCoalition = function()
      if raising then
        error("getCoalition unavailable")
      end
      return current
    end,
    getParking = function()
      return stands
    end,
    getPoint = function()
      return { x = -99999, y = 0, z = -99999 }
    end,
    _set = function(c)
      current = c
    end,
    _raise = function()
      raising = true
    end,
  }
end

local function messagesTo(side)
  local found = {}
  for _, message in ipairs(dcs_mocks.messages) do
    if message.fn == "outTextForCoalition" and message.target == side then
      table.insert(found, message)
    end
  end
  return found
end

TestVeafTransportAirbaseLogisticsTick = {}

function TestVeafTransportAirbaseLogisticsTick:setUp()
  dcs_mocks.reset()
  veafAirbases.Airbases = {}
  veafTransportMission.airbaseLogisticState = {}
  veafTransportMission.airbaseLogisticsTaskId = nil
end

function TestVeafTransportAirbaseLogisticsTick:tearDown()
  veafAirbases.Airbases = nil
  veafTransportMission.airbaseLogisticState = {}
  veafTransportMission.airbaseLogisticsTaskId = nil
  dcs_mocks.reset()
end

--- Register a blue class-A field through the real initialiser and isolate the tick's own calls.
function TestVeafTransportAirbaseLogisticsTick:_registerBlue(name)
  local dcsAirbase = mutableDcsAirbase(coalition.side.BLUE, threeStands())
  veafAirbases.Airbases = { makeAirbaseRecord(name, Airbase.Category.AIRDROME, dcsAirbase) }
  veafTransportMission.initializeAllLogisticInCTLD()
  CTLDZoneManager._instance.calls = {}
  dcs_mocks.messages = {}
  return dcsAirbase
end

function TestVeafTransportAirbaseLogisticsTick:test_loss_to_neutral_deactivates_and_tells_the_holder()
  local ab = self:_registerBlue("Ramstein")
  local state = veafTransportMission.airbaseLogisticState["Ramstein"]
  luaunit.assertTrue(state.active)

  ab._set(coalition.side.NEUTRAL)
  veafTransportMission.updateAirbaseLogisticsZones()

  local deactivated = zoneManagerCalls("deactivateLogisticZone")
  luaunit.assertEquals(#deactivated, 1)
  luaunit.assertEquals(deactivated[1].args[1], "AB_Ramstein")
  luaunit.assertFalse(state.active)
  luaunit.assertEquals(state.class, "A", "neutral is a loss, not a third state: the field stays class A")
  luaunit.assertEquals(#zoneManagerCalls("activateLogisticZone"), 0)
  luaunit.assertEquals(#messagesTo(coalition.side.BLUE), 1, "the side that held it is told it lost the point")
  luaunit.assertEquals(#messagesTo(coalition.side.RED), 0, "neutral gains nothing, so no second message")
  luaunit.assertEquals(#dcs_mocks.messagesContaining("Ramstein"), 1, "the message names the airfield")
end

function TestVeafTransportAirbaseLogisticsTick:test_return_to_the_holder_reactivates_and_tells_it()
  local ab = self:_registerBlue("Ramstein")
  local state = veafTransportMission.airbaseLogisticState["Ramstein"]

  ab._set(coalition.side.NEUTRAL)
  veafTransportMission.updateAirbaseLogisticsZones()
  CTLDZoneManager._instance.calls = {}
  dcs_mocks.messages = {}
  ab._set(coalition.side.BLUE)
  veafTransportMission.updateAirbaseLogisticsZones()

  local activated = zoneManagerCalls("activateLogisticZone")
  luaunit.assertEquals(#activated, 1)
  luaunit.assertEquals(activated[1].args[1], "AB_Ramstein")
  luaunit.assertTrue(state.active)
  luaunit.assertEquals(state.class, "A")
  luaunit.assertEquals(#zoneManagerCalls("deactivateLogisticZone"), 0)
  luaunit.assertEquals(#messagesTo(coalition.side.BLUE), 1, "the gaining side is told it can load again")
end

function TestVeafTransportAirbaseLogisticsTick:test_taken_by_the_other_side_reclassifies_a_to_b_and_tells_the_loser()
  local ab = self:_registerBlue("Ramstein")
  local state = veafTransportMission.airbaseLogisticState["Ramstein"]

  ab._set(coalition.side.RED)
  veafTransportMission.updateAirbaseLogisticsZones()

  luaunit.assertEquals(#zoneManagerCalls("deactivateLogisticZone"), 1)
  luaunit.assertEquals(#zoneManagerCalls("activateLogisticZone"), 0)
  luaunit.assertFalse(state.active)
  luaunit.assertEquals(state.class, "B", "a field taken by the other side leaves class A")
  luaunit.assertTrue(state.leftClassA, "the transition is recorded so ticket 03 does not guess")
  luaunit.assertEquals(state.coalition, coalition.side.RED)
  luaunit.assertEquals(state.homeCoalition, coalition.side.BLUE, "the coalition the zone was registered under never changes")
  -- The loser is told at once. The taker is NOT told it can load yet: the zone is dark for it until
  -- it has held the field two continuous minutes, and ticket 03 announces the moment it opens. A
  -- "gained" here would promise a resupply that does not exist and 03 would repeat two minutes on.
  luaunit.assertEquals(#messagesTo(coalition.side.BLUE), 1, "the side that held it is told it lost the point")
  luaunit.assertEquals(#messagesTo(coalition.side.RED), 0, "the taker is not told it can load before it actually can")
end

function TestVeafTransportAirbaseLogisticsTick:test_an_unchanged_coalition_calls_nothing_and_says_nothing()
  self:_registerBlue("Ramstein")

  veafTransportMission.updateAirbaseLogisticsZones()

  luaunit.assertEquals(#zoneManagerCalls("deactivateLogisticZone"), 0)
  luaunit.assertEquals(#zoneManagerCalls("activateLogisticZone"), 0)
  luaunit.assertEquals(#dcs_mocks.messages, 0)
  luaunit.assertEquals(#logsContaining(nil, "updateAirbaseLogisticsZones"), 0, "a tick where nothing changed writes no log line")
end

function TestVeafTransportAirbaseLogisticsTick:test_a_raising_coalition_read_leaves_the_zone_as_it_was()
  local ab = self:_registerBlue("Ramstein")
  local state = veafTransportMission.airbaseLogisticState["Ramstein"]
  luaunit.assertTrue(state.active)

  ab._raise()
  veafTransportMission.updateAirbaseLogisticsZones()

  luaunit.assertEquals(#zoneManagerCalls("deactivateLogisticZone"), 0)
  luaunit.assertEquals(#zoneManagerCalls("activateLogisticZone"), 0)
  luaunit.assertTrue(state.active, "a raising read leaves the zone exactly as it was")
  luaunit.assertEquals(state.coalition, coalition.side.BLUE)
  luaunit.assertEquals(state.class, "A")
  luaunit.assertEquals(#dcs_mocks.messages, 0)
  luaunit.assertTrue(#logsContaining("W", "Ramstein") > 0, "a raising read is logged")
end

function TestVeafTransportAirbaseLogisticsTick:test_the_initialiser_schedules_one_recurring_tick()
  local ab = mutableDcsAirbase(coalition.side.BLUE, threeStands())
  veafAirbases.Airbases = { makeAirbaseRecord("Ramstein", Airbase.Category.AIRDROME, ab) }

  veafTransportMission.initializeAllLogisticInCTLD()
  local firstId = veafTransportMission.airbaseLogisticsTaskId
  luaunit.assertNotNil(firstId, "the tick must be scheduled")

  veafTransportMission.initializeAllLogisticInCTLD()
  luaunit.assertEquals(veafTransportMission.airbaseLogisticsTaskId, firstId, "a re-init must not stack a second tick")

  local count = 0
  for _ in pairs(dcs_mocks.scheduledTasks) do
    count = count + 1
  end
  luaunit.assertEquals(count, 1, "exactly one native scheduled task")
end

function TestVeafTransportAirbaseLogisticsTick:test_the_scheduled_task_runs_the_tick()
  local ab = mutableDcsAirbase(coalition.side.BLUE, threeStands())
  veafAirbases.Airbases = { makeAirbaseRecord("Ramstein", Airbase.Category.AIRDROME, ab) }
  timer.setTime(0)
  veafTransportMission.initializeAllLogisticInCTLD()
  CTLDZoneManager._instance.calls = {}
  dcs_mocks.messages = {}

  ab._set(coalition.side.NEUTRAL)
  dcs_mocks.runScheduled(30) -- the injected clock reaches the first 30 s tick

  luaunit.assertEquals(#zoneManagerCalls("deactivateLogisticZone"), 1)
  luaunit.assertEquals(#messagesTo(coalition.side.BLUE), 1)
end

-- ---------------------------------------------------------------------------
-- TestVeafTransportAirbaseLogisticsClassB — FEAT-CTLD-AIRBASE-LOGISTICS ticket 03
--
-- Class B is the only class that costs a spatial query: ground troops of one coalition, unopposed
-- inside 2000 m for two continuous minutes (four 30 s ticks) make a neutral or captured airfield a
-- logistic point for them, and the last of them leaving closes it at once. The probe is driven
-- through the injectable world.searchObjects mock — an object list, never a sleep.
-- ---------------------------------------------------------------------------

local function groundUnit(side)
  return {
    isExist = function()
      return true
    end,
    getCategoryEx = function()
      return Unit.Category.GROUND_UNIT
    end,
    getCoalition = function()
      return side
    end,
  }
end

local function aircraft(side)
  return {
    isExist = function()
      return true
    end,
    getCategoryEx = function()
      return Unit.Category.AIRPLANE
    end,
    getCoalition = function()
      return side
    end,
  }
end

--- A static: not a ground unit, and never queried anyway (only Object.Category.UNIT is).
local function staticObject(side)
  return {
    isExist = function()
      return true
    end,
    getCategoryEx = function()
      return Unit.Category.STRUCTURE
    end,
    getCoalition = function()
      return side
    end,
  }
end

TestVeafTransportAirbaseLogisticsClassB = {}

function TestVeafTransportAirbaseLogisticsClassB:setUp()
  dcs_mocks.reset()
  veafAirbases.Airbases = {}
  veafTransportMission.airbaseLogisticState = {}
  veafTransportMission.airbaseLogisticsTaskId = nil
end

function TestVeafTransportAirbaseLogisticsClassB:tearDown()
  veafAirbases.Airbases = nil
  veafTransportMission.airbaseLogisticState = {}
  veafTransportMission.airbaseLogisticsTaskId = nil
  dcs_mocks.reset()
end

--- Register a neutral (class-B) airfield through the real initialiser, isolate the tick's calls.
function TestVeafTransportAirbaseLogisticsClassB:_neutral(name)
  local dcsAirbase = mutableDcsAirbase(coalition.side.NEUTRAL, threeStands())
  veafAirbases.Airbases = { makeAirbaseRecord(name, Airbase.Category.AIRDROME, dcsAirbase) }
  veafTransportMission.initializeAllLogisticInCTLD()
  CTLDZoneManager._instance.calls = {}
  dcs_mocks.messages = {}
  dcs_mocks.searchObjectsCalls = {}
  return veafTransportMission.airbaseLogisticState[name]
end

function TestVeafTransportAirbaseLogisticsClassB:test_activates_after_four_consecutive_ticks_not_three()
  local state = self:_neutral("NeutralField")
  dcs_mocks.searchObjectsObjects = { groundUnit(coalition.side.BLUE) }

  for _ = 1, 3 do
    veafTransportMission.updateAirbaseLogisticsZones()
  end
  luaunit.assertFalse(state.active, "three consecutive ticks are not yet two minutes")
  luaunit.assertEquals(state.occupationTicks, 3)
  luaunit.assertEquals(#messagesTo(coalition.side.BLUE), 0, "nothing is announced before it opens")

  veafTransportMission.updateAirbaseLogisticsZones() -- the fourth
  luaunit.assertTrue(state.active, "active after four consecutive ticks")
  luaunit.assertEquals(state.holder, coalition.side.BLUE)
  luaunit.assertEquals(state.registeredCoalition, coalition.side.BLUE)
  local registered = zoneManagerCalls("registerFOBAsLogistic")
  luaunit.assertEquals(#registered, 1)
  luaunit.assertEquals(registered[1].args[3], 250, "the zone itself is 250 m, not the 2000 m probe")
  luaunit.assertEquals(registered[1].args[4], coalition.side.BLUE)
  luaunit.assertEquals(#messagesTo(coalition.side.BLUE), 1, "the gaining side is told once, when it opens")
end

function TestVeafTransportAirbaseLogisticsClassB:test_an_empty_tick_clears_the_clock_not_pauses_it()
  local state = self:_neutral("NeutralField")
  dcs_mocks.searchObjectsObjects = { groundUnit(coalition.side.BLUE) }
  veafTransportMission.updateAirbaseLogisticsZones()
  veafTransportMission.updateAirbaseLogisticsZones()
  luaunit.assertEquals(state.occupationTicks, 2)

  dcs_mocks.searchObjectsObjects = {} -- everybody left
  veafTransportMission.updateAirbaseLogisticsZones()
  luaunit.assertEquals(state.occupationTicks, 0, "an empty tick clears the clock")
  luaunit.assertNil(state.occupationCoalition)

  dcs_mocks.searchObjectsObjects = { groundUnit(coalition.side.BLUE) } -- they come back
  veafTransportMission.updateAirbaseLogisticsZones()
  luaunit.assertEquals(state.occupationTicks, 1, "the count restarts, it does not resume")
  luaunit.assertFalse(state.active)
end

function TestVeafTransportAirbaseLogisticsClassB:test_an_aircraft_never_starts_the_clock()
  local state = self:_neutral("NeutralField")
  dcs_mocks.searchObjectsObjects = { aircraft(coalition.side.BLUE) }

  for _ = 1, 5 do
    veafTransportMission.updateAirbaseLogisticsZones()
  end

  luaunit.assertFalse(state.active, "a transport that lands to use the field does not open it")
  luaunit.assertEquals(state.occupationTicks, 0)
end

function TestVeafTransportAirbaseLogisticsClassB:test_only_units_are_queried_and_a_static_is_ignored()
  local state = self:_neutral("NeutralField")
  dcs_mocks.searchObjectsObjects = { staticObject(coalition.side.BLUE) }

  veafTransportMission.updateAirbaseLogisticsZones()

  luaunit.assertFalse(state.active)
  luaunit.assertEquals(state.occupationTicks, 0, "a static is not a ground unit")
  local sawUnit, sawStatic, sawScenery = false, false, false
  for _, call in ipairs(dcs_mocks.searchObjectsCalls) do
    if call.category == Object.Category.UNIT then
      sawUnit = true
      luaunit.assertEquals(call.volume.id, world.VolumeType.SPHERE)
      luaunit.assertEquals(call.volume.params.radius, 2000, "the probe radius is the occupation setting")
    elseif call.category == Object.Category.STATIC then
      sawStatic = true
    elseif call.category == Object.Category.SCENERY then
      sawScenery = true
    end
  end
  luaunit.assertTrue(sawUnit, "the ground-unit probe queries UNIT")
  luaunit.assertFalse(sawStatic, "never STATIC: a built FOB would hold its own airfield open")
  luaunit.assertFalse(sawScenery, "never SCENERY: it has no coalition")
end

function TestVeafTransportAirbaseLogisticsClassB:test_the_probe_runs_for_class_b_only()
  local blueField = mutableDcsAirbase(coalition.side.BLUE, threeStands())
  local neutralField = mutableDcsAirbase(coalition.side.NEUTRAL, threeStands())
  veafAirbases.Airbases = {
    makeAirbaseRecord("BlueField", Airbase.Category.AIRDROME, blueField),
    makeAirbaseRecord("NeutralField", Airbase.Category.AIRDROME, neutralField),
  }
  veafTransportMission.initializeAllLogisticInCTLD()
  dcs_mocks.searchObjectsCalls = {}
  dcs_mocks.searchObjectsObjects = { groundUnit(coalition.side.BLUE) }

  veafTransportMission.updateAirbaseLogisticsZones()

  luaunit.assertEquals(#dcs_mocks.searchObjectsCalls, 1, "class A is decided by getCoalition alone and never probes")
  luaunit.assertTrue(veafTransportMission.airbaseLogisticState["BlueField"].active, "class A stays as it was")
end

function TestVeafTransportAirbaseLogisticsClassB:test_withdrawal_removes_it_at_once()
  local state = self:_neutral("NeutralField")
  dcs_mocks.searchObjectsObjects = { groundUnit(coalition.side.BLUE) }
  for _ = 1, 4 do
    veafTransportMission.updateAirbaseLogisticsZones()
  end
  luaunit.assertTrue(state.active)
  CTLDZoneManager._instance.calls = {}
  dcs_mocks.messages = {}

  dcs_mocks.searchObjectsObjects = {} -- the last blue unit withdrew
  veafTransportMission.updateAirbaseLogisticsZones()

  luaunit.assertFalse(state.active, "it stops being a logistic point the moment the last unit leaves")
  luaunit.assertEquals(#zoneManagerCalls("deactivateLogisticZone"), 1)
  luaunit.assertEquals(#messagesTo(coalition.side.BLUE), 1, "the losing side is told")
end

function TestVeafTransportAirbaseLogisticsClassB:test_a_raising_probe_leaves_the_zone_as_it_was()
  local state = self:_neutral("NeutralField")
  dcs_mocks.searchObjectsObjects = { groundUnit(coalition.side.BLUE) }
  for _ = 1, 4 do
    veafTransportMission.updateAirbaseLogisticsZones()
  end
  luaunit.assertTrue(state.active)
  CTLDZoneManager._instance.calls = {}
  dcs_mocks.messages = {}

  dcs_mocks.searchObjectsRaise = true
  veafTransportMission.updateAirbaseLogisticsZones()

  luaunit.assertTrue(state.active, "fail CLOSED: an unusable probe does not flicker the zone out")
  luaunit.assertEquals(state.holder, coalition.side.BLUE)
  luaunit.assertEquals(#zoneManagerCalls("deactivateLogisticZone"), 0)
  luaunit.assertEquals(#dcs_mocks.messages, 0)
  luaunit.assertTrue(#logsContaining("W", "NeutralField") > 0, "the unusable probe is logged")
  dcs_mocks.searchObjectsRaise = false
end

function TestVeafTransportAirbaseLogisticsClassB:test_red_troops_on_a_captured_blue_field_open_it_for_red()
  local ab = mutableDcsAirbase(coalition.side.BLUE, threeStands())
  veafAirbases.Airbases = { makeAirbaseRecord("Ramstein", Airbase.Category.AIRDROME, ab) }
  veafTransportMission.initializeAllLogisticInCTLD()
  local state = veafTransportMission.airbaseLogisticState["Ramstein"]

  ab._set(coalition.side.RED) -- blue loses it to red: class A → B, dark
  veafTransportMission.updateAirbaseLogisticsZones()
  luaunit.assertEquals(state.class, "B")
  luaunit.assertFalse(state.active)

  CTLDZoneManager._instance.calls = {}
  dcs_mocks.messages = {}
  dcs_mocks.searchObjectsObjects = { groundUnit(coalition.side.RED) }
  for _ = 1, 4 do
    veafTransportMission.updateAirbaseLogisticsZones()
  end

  luaunit.assertTrue(state.active)
  luaunit.assertEquals(state.holder, coalition.side.RED)
  luaunit.assertEquals(state.registeredCoalition, coalition.side.RED)
  luaunit.assertEquals(#zoneManagerCalls("unregisterLogistic"), 1, "a zone moves coalition only by unregister → register")
  local registered = zoneManagerCalls("registerFOBAsLogistic")
  luaunit.assertEquals(#registered, 1)
  luaunit.assertEquals(registered[1].args[4], coalition.side.RED)
  luaunit.assertEquals(#messagesTo(coalition.side.RED), 1, "red is told when it can actually load")
end

-- ---------------------------------------------------------------------------
-- TestVeafTransportAirbaseLogisticsCircle — FEAT-CTLD-AIRBASE-LOGISTICS ticket 04
--
-- One green transparent circle per active logistic airfield, on the F10 map, visible only to the
-- coalition that holds it. The assertions are against `dcs_mocks.circlesDrawn` — the recorded live
-- map state, where circleToAll adds and removeMark removes by id — never against an erase() call
-- count, because VeafDrawingOnMap:erase re-issues removeMark for ids already gone.
-- ---------------------------------------------------------------------------

TestVeafTransportAirbaseLogisticsCircle = {}

function TestVeafTransportAirbaseLogisticsCircle:setUp()
  dcs_mocks.reset()
  veafAirbases.Airbases = {}
  veafTransportMission.airbaseLogisticState = {}
  veafTransportMission.airbaseLogisticsTaskId = nil
end

function TestVeafTransportAirbaseLogisticsCircle:tearDown()
  veafAirbases.Airbases = nil
  veafTransportMission.airbaseLogisticState = {}
  veafTransportMission.airbaseLogisticsTaskId = nil
  dcs_mocks.reset()
end

--- Register a blue class-A field through the real initialiser and return its state and live handle.
--- The circle the initialiser draws is left in `dcs_mocks.circlesDrawn` so a test can assert on the
--- live map state; only the CTLD calls and messages are cleared, to isolate what the test does next.
function TestVeafTransportAirbaseLogisticsCircle:_blue(name)
  local dcsAirbase = mutableDcsAirbase(coalition.side.BLUE, threeStands())
  veafAirbases.Airbases = { makeAirbaseRecord(name, Airbase.Category.AIRDROME, dcsAirbase) }
  veafTransportMission.initializeAllLogisticInCTLD()
  CTLDZoneManager._instance.calls = {}
  dcs_mocks.messages = {}
  return veafTransportMission.airbaseLogisticState[name], dcsAirbase
end

function TestVeafTransportAirbaseLogisticsCircle:test_a_registered_airfield_draws_one_green_circle_at_its_stand()
  self:_blue("Ramstein")

  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 1, "an active logistic airfield carries exactly one circle")
  local circle = dcs_mocks.circlesDrawn[1]
  luaunit.assertEquals(circle.coalition, coalition.side.BLUE, "visible to the holder alone")
  luaunit.assertEquals(circle.radius, 250, "the radius is the logistic-zone setting")
  luaunit.assertEquals(circle.point.x, 450, "centred on the stand ticket 01 chose, not the centroid nor the reference point")
  luaunit.assertEquals(circle.point.z, 0)
  luaunit.assertEquals(circle.lineType, 1, "a solid outline")
  luaunit.assertEquals(circle.color[2], 1, "a green outline")
  luaunit.assertEquals(circle.fillColor[1], 0)
  luaunit.assertEquals(circle.fillColor[2], 1)
  luaunit.assertEquals(circle.fillColor[3], 0)
  luaunit.assertEquals(circle.fillColor[4], 0.15, "the named translucent green fill, alpha in family with veafGeo")
end

function TestVeafTransportAirbaseLogisticsCircle:test_a_red_field_is_drawn_for_red_only()
  local dcsAirbase = mutableDcsAirbase(coalition.side.RED, threeStands())
  veafAirbases.Airbases = { makeAirbaseRecord("RedField", Airbase.Category.AIRDROME, dcsAirbase) }
  veafTransportMission.initializeAllLogisticInCTLD()

  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 1)
  luaunit.assertEquals(
    dcs_mocks.circlesDrawn[1].coalition,
    coalition.side.RED,
    "green means ours: a red field is drawn for red, never for everyone"
  )
end

function TestVeafTransportAirbaseLogisticsCircle:test_deactivation_erases_the_circle()
  local state, ab = self:_blue("Ramstein")
  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 1)

  ab._set(coalition.side.NEUTRAL)
  veafTransportMission.updateAirbaseLogisticsZones()

  luaunit.assertFalse(state.active)
  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 0, "a dark airfield leaves no circle on the map")
end

function TestVeafTransportAirbaseLogisticsCircle:test_reactivation_redraws_one_circle_not_two()
  local state, ab = self:_blue("Ramstein")

  ab._set(coalition.side.NEUTRAL)
  veafTransportMission.updateAirbaseLogisticsZones()
  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 0)

  ab._set(coalition.side.BLUE)
  veafTransportMission.updateAirbaseLogisticsZones()
  luaunit.assertTrue(state.active)
  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 1, "draw() erases before redrawing, so the one reused object never doubles up")
  luaunit.assertEquals(dcs_mocks.circlesDrawn[1].coalition, coalition.side.BLUE)
end

function TestVeafTransportAirbaseLogisticsCircle:test_a_change_of_hands_leaves_exactly_one_circle()
  local _, ab = self:_blue("Ramstein")
  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 1, "blue holds it: one blue circle")

  ab._set(coalition.side.RED)
  veafTransportMission.updateAirbaseLogisticsZones() -- class A → B, released
  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 0, "dark while it owes the two minutes")

  dcs_mocks.searchObjectsObjects = { groundUnit(coalition.side.RED) }
  for _ = 1, 4 do
    veafTransportMission.updateAirbaseLogisticsZones()
  end

  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 1, "one circle per airfield, not one per coalition")
  luaunit.assertEquals(dcs_mocks.circlesDrawn[1].coalition, coalition.side.RED, "the single circle now belongs to red")
end

function TestVeafTransportAirbaseLogisticsCircle:test_a_neutral_field_has_no_circle_until_it_opens()
  local dcsAirbase = mutableDcsAirbase(coalition.side.NEUTRAL, threeStands())
  veafAirbases.Airbases = { makeAirbaseRecord("NeutralField", Airbase.Category.AIRDROME, dcsAirbase) }
  veafTransportMission.initializeAllLogisticInCTLD()
  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 0, "a field that is not a logistic point yet is not drawn")

  dcs_mocks.searchObjectsObjects = { groundUnit(coalition.side.BLUE) }
  for _ = 1, 4 do
    veafTransportMission.updateAirbaseLogisticsZones()
  end

  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 1, "it appears when the field actually opens")
  luaunit.assertEquals(dcs_mocks.circlesDrawn[1].coalition, coalition.side.BLUE)
end

function TestVeafTransportAirbaseLogisticsCircle:test_reinitialisation_keeps_exactly_one_circle_for_an_active_field()
  self:_blue("Ramstein")
  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 1)

  veafTransportMission.initializeAllLogisticInCTLD() -- the mission script re-runs the initialiser

  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 1, "the stale circle is erased and the live one redrawn, never two")
  luaunit.assertEquals(dcs_mocks.circlesDrawn[1].coalition, coalition.side.BLUE)
end

function TestVeafTransportAirbaseLogisticsCircle:test_reinitialisation_leaves_no_circle_for_a_dark_field()
  local state, ab = self:_blue("Ramstein")

  ab._set(coalition.side.NEUTRAL)
  veafTransportMission.updateAirbaseLogisticsZones() -- released, dark
  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 0)

  veafTransportMission.initializeAllLogisticInCTLD() -- re-init: the snapshot survives, still dark

  luaunit.assertFalse(state.active)
  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 0, "a circle whose zone is gone is never left behind")
end

-- ---------------------------------------------------------------------------
-- TestVeafTransportAirbaseLogisticsSettings — FEAT-CTLD-AIRBASE-LOGISTICS ticket 05
--
-- The opt-out flag and the three numbers are mission settings under modules.CTLD, emitted into
-- veaf.config by the generator and resolved here at initialisation. A Python test proving the YAML
-- generates is not the same claim as the module honouring it, so these drive the real initialiser
-- with the settings placed in veaf.config and assert on what reaches CTLD, the probe, the schedule
-- and the map. Each test starts from the defaults (the keys are cleared in setUp) and restores them.
-- ---------------------------------------------------------------------------

TestVeafTransportAirbaseLogisticsSettings = {}

local LOGISTICS_SETTING_KEYS =
  { "manage_airbase_logistics", "airbase_logistics_radius", "airbase_occupation_radius", "airbase_logistics_tick" }

function TestVeafTransportAirbaseLogisticsSettings:setUp()
  dcs_mocks.reset()
  veafAirbases.Airbases = {}
  veafTransportMission.airbaseLogisticState = {}
  veafTransportMission.airbaseLogisticsTaskId = nil
  self._saved = {}
  for _, key in ipairs(LOGISTICS_SETTING_KEYS) do
    self._saved[key] = veaf.config[key]
    veaf.config[key] = nil
  end
end

function TestVeafTransportAirbaseLogisticsSettings:tearDown()
  for _, key in ipairs(LOGISTICS_SETTING_KEYS) do
    veaf.config[key] = self._saved[key]
  end
  veafAirbases.Airbases = nil
  veafTransportMission.airbaseLogisticState = {}
  veafTransportMission.airbaseLogisticsTaskId = nil
  dcs_mocks.reset()
end

function TestVeafTransportAirbaseLogisticsSettings:test_the_flag_off_does_nothing_and_says_it_was_asked_to_stay_off()
  veaf.config.manage_airbase_logistics = false
  local ab = mutableDcsAirbase(coalition.side.BLUE, threeStands())
  veafAirbases.Airbases = { makeAirbaseRecord("Ramstein", Airbase.Category.AIRDROME, ab) }

  veafTransportMission.initializeAllLogisticInCTLD()

  luaunit.assertEquals(#zoneManagerCalls("registerFOBAsLogistic"), 0, "nothing is registered")
  luaunit.assertNil(veafTransportMission.airbaseLogisticsTaskId, "no tick is scheduled")
  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 0, "no circle is drawn")
  luaunit.assertNil(next(veafTransportMission.airbaseLogisticState), "no airfield state is even built")
  luaunit.assertEquals(
    #logsContaining("I", "asked to stay off"),
    1,
    "the log says the feature was asked to stay off, not that no airfields were found"
  )
end

function TestVeafTransportAirbaseLogisticsSettings:test_the_flag_defaults_to_on_when_the_key_is_absent()
  -- setUp cleared the key, so it is nil: the default is ON, and only an explicit false disables.
  local ab = mutableDcsAirbase(coalition.side.BLUE, threeStands())
  veafAirbases.Airbases = { makeAirbaseRecord("Ramstein", Airbase.Category.AIRDROME, ab) }

  veafTransportMission.initializeAllLogisticInCTLD()

  luaunit.assertEquals(#zoneManagerCalls("registerFOBAsLogistic"), 1, "an absent key leaves the feature on")
  luaunit.assertNotNil(veafTransportMission.airbaseLogisticsTaskId)
  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 1)
end

function TestVeafTransportAirbaseLogisticsSettings:test_a_custom_zone_radius_reaches_the_registration_and_the_circle()
  veaf.config.airbase_logistics_radius = 400
  local ab = mutableDcsAirbase(coalition.side.BLUE, threeStands())
  veafAirbases.Airbases = { makeAirbaseRecord("Ramstein", Airbase.Category.AIRDROME, ab) }

  veafTransportMission.initializeAllLogisticInCTLD()

  local registered = zoneManagerCalls("registerFOBAsLogistic")
  luaunit.assertEquals(#registered, 1)
  luaunit.assertEquals(registered[1].args[3], 400, "the registration uses the configured radius, not the 250 m default")
  luaunit.assertEquals(#dcs_mocks.circlesDrawn, 1)
  luaunit.assertEquals(dcs_mocks.circlesDrawn[1].radius, 400, "and so does the circle on the map")
end

function TestVeafTransportAirbaseLogisticsSettings:test_a_custom_occupation_radius_reaches_the_probe()
  veaf.config.airbase_occupation_radius = 3000
  local dcsAirbase = mutableDcsAirbase(coalition.side.NEUTRAL, threeStands())
  veafAirbases.Airbases = { makeAirbaseRecord("NeutralField", Airbase.Category.AIRDROME, dcsAirbase) }
  veafTransportMission.initializeAllLogisticInCTLD()
  dcs_mocks.searchObjectsCalls = {}

  veafTransportMission.updateAirbaseLogisticsZones()

  luaunit.assertEquals(#dcs_mocks.searchObjectsCalls, 1)
  luaunit.assertEquals(dcs_mocks.searchObjectsCalls[1].volume.params.radius, 3000, "the probe sphere uses the configured occupation radius")
end

function TestVeafTransportAirbaseLogisticsSettings:test_a_custom_tick_reaches_the_schedule_and_the_occupation_count()
  veaf.config.airbase_logistics_tick = 60
  timer.setTime(0)
  local dcsAirbase = mutableDcsAirbase(coalition.side.NEUTRAL, threeStands())
  veafAirbases.Airbases = { makeAirbaseRecord("NeutralField", Airbase.Category.AIRDROME, dcsAirbase) }
  veafTransportMission.initializeAllLogisticInCTLD()

  local task
  for _, scheduled in pairs(dcs_mocks.scheduledTasks) do
    task = scheduled
  end
  luaunit.assertNotNil(task, "the tick is scheduled")
  luaunit.assertEquals(task.time, 60, "with the clock at 0, the first fire is one configured interval away")

  -- The two-minute hold follows the interval: 120 s at a 60 s tick is two consecutive ticks, not four.
  local state = veafTransportMission.airbaseLogisticState["NeutralField"]
  dcs_mocks.searchObjectsObjects = { groundUnit(coalition.side.BLUE) }
  veafTransportMission.updateAirbaseLogisticsZones()
  luaunit.assertFalse(state.active, "one tick is not yet two minutes at a 60 s interval")
  veafTransportMission.updateAirbaseLogisticsZones()
  luaunit.assertTrue(state.active, "two consecutive ticks are two minutes at a 60 s interval")
end

os.exit(luaunit.LuaUnit.run())
