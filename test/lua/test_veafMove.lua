--- Tests for veafMove.lua — constants and markTextAnalysis variants.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafMove.lua")

-- ---------------------------------------------------------------------------
-- TestVeafMoveConstants
-- ---------------------------------------------------------------------------
TestVeafMoveConstants = {}

function TestVeafMoveConstants:test_keyphrase()
  luaunit.assertEquals(veafMove.Keyphrase, "_move")
end

function TestVeafMoveConstants:test_id()
  luaunit.assertEquals(veafMove.Id, "MOVE")
end

-- ---------------------------------------------------------------------------
-- TestVeafMoveTankerParameters
-- ---------------------------------------------------------------------------
TestVeafMoveTankerParameters = {}

function TestVeafMoveTankerParameters:test_tanker_params_is_table()
  luaunit.assertIsTable(veafMove.tankerMissionParameters)
end

function TestVeafMoveTankerParameters:test_tanker_params_has_27_entries()
  local count = 0
  for _ in pairs(veafMove.tankerMissionParameters) do count = count + 1 end
  luaunit.assertEquals(count, 27)
end

function TestVeafMoveTankerParameters:test_fa18c_entry_exists()
  luaunit.assertNotNil(veafMove.tankerMissionParameters["F/A-18C"])
end

function TestVeafMoveTankerParameters:test_jf17_entry_exists()
  luaunit.assertNotNil(veafMove.tankerMissionParameters["JF-17"])
end

function TestVeafMoveTankerParameters:test_f16_entry_exists()
  luaunit.assertNotNil(veafMove.tankerMissionParameters["F-16C bl.50"])
end

-- ---------------------------------------------------------------------------
-- TestVeafMoveMarkTextAnalysis
-- ---------------------------------------------------------------------------
TestVeafMoveMarkTextAnalysis = {}

function TestVeafMoveMarkTextAnalysis:test_no_subcommand_returns_nil()
  -- "_move" alone without group/tanker/afac subcommand → nil
  local r = veafMove.markTextAnalysis("_move")
  luaunit.assertNil(r)
end

function TestVeafMoveMarkTextAnalysis:test_move_group_returns_table()
  local r = veafMove.markTextAnalysis("_move group, name SomeGroup")
  luaunit.assertIsTable(r)
end

-- SECREV-010: an empty group name (the default "") must be rejected, since ""
-- is truthy in Lua and the old guard never fired.
function TestVeafMoveMarkTextAnalysis:test_move_group_without_name_returns_nil()
  local r = veafMove.markTextAnalysis("_move group")
  luaunit.assertNil(r)
end

function TestVeafMoveMarkTextAnalysis:test_move_group_sets_flag()
  local r = veafMove.markTextAnalysis("_move group, name SomeGroup")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.moveGroup)
end

function TestVeafMoveMarkTextAnalysis:test_move_group_name_keyword()
  local r = veafMove.markTextAnalysis("_move group, name Bravo")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.groupName, "Bravo")
end

function TestVeafMoveMarkTextAnalysis:test_move_group_speed_keyword()
  local r = veafMove.markTextAnalysis("_move group, name Alpha, speed 250")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.speed, 250)
end

function TestVeafMoveMarkTextAnalysis:test_move_tanker_returns_table()
  local r = veafMove.markTextAnalysis("_move tanker, name TKR1")
  luaunit.assertIsTable(r)
end

function TestVeafMoveMarkTextAnalysis:test_move_tanker_sets_flag()
  local r = veafMove.markTextAnalysis("_move tanker, name TKR1")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.moveTanker)
end

function TestVeafMoveMarkTextAnalysis:test_move_afac_returns_table()
  local r = veafMove.markTextAnalysis("_move afac, name AFAC1")
  luaunit.assertIsTable(r)
end

function TestVeafMoveMarkTextAnalysis:test_move_afac_sets_flag()
  local r = veafMove.markTextAnalysis("_move afac, name AFAC1")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.moveAfac)
end

function TestVeafMoveMarkTextAnalysis:test_move_afac_default_altitude()
  local r = veafMove.markTextAnalysis("_move afac, name AFAC1")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.altitude, 15000)
end

function TestVeafMoveMarkTextAnalysis:test_non_matching_returns_nil()
  local r = veafMove.markTextAnalysis("_cas")
  luaunit.assertNil(r)
end

-- ---------------------------------------------------------------------------
-- TestVeafMoveMarkTextAnalysisKeywords
-- ---------------------------------------------------------------------------
TestVeafMoveMarkTextAnalysisKeywords = {}

function TestVeafMoveMarkTextAnalysisKeywords:test_tankermission_sets_changeTanker()
  local r = veafMove.markTextAnalysis("_move tankermission, name TKR1")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.changeTanker)
end

function TestVeafMoveMarkTextAnalysisKeywords:test_hdg_keyword()
  local r = veafMove.markTextAnalysis("_move tanker, name TKR1, hdg 270")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.hdg, 270)
end

function TestVeafMoveMarkTextAnalysisKeywords:test_heading_keyword_alias()
  local r = veafMove.markTextAnalysis("_move tanker, name TKR1, heading 180")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.hdg, 180)
end

function TestVeafMoveMarkTextAnalysisKeywords:test_dist_keyword()
  local r = veafMove.markTextAnalysis("_move tanker, name TKR1, dist 50")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.distance, 50)
end

function TestVeafMoveMarkTextAnalysisKeywords:test_distance_keyword_alias()
  local r = veafMove.markTextAnalysis("_move tanker, name TKR1, distance 100")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.distance, 100)
end

function TestVeafMoveMarkTextAnalysisKeywords:test_alt_keyword()
  local r = veafMove.markTextAnalysis("_move tanker, name TKR1, alt 20000")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.altitude, 20000)
end

function TestVeafMoveMarkTextAnalysisKeywords:test_altitude_keyword_alias()
  local r = veafMove.markTextAnalysis("_move tanker, name TKR1, altitude 25000")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.altitude, 25000)
end

function TestVeafMoveMarkTextAnalysisKeywords:test_teleport_keyword()
  local r = veafMove.markTextAnalysis("_move tanker, name TKR1, teleport")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.teleport)
end

function TestVeafMoveMarkTextAnalysisKeywords:test_silent_keyword()
  local r = veafMove.markTextAnalysis("_move tanker, name TKR1, silent")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.silent)
end

function TestVeafMoveMarkTextAnalysisKeywords:test_immortal_keyword()
  local r = veafMove.markTextAnalysis("_move afac, name AFAC1, immortal")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.immortal)
end

-- ---------------------------------------------------------------------------
-- TestVeafMoveHelpers
-- ---------------------------------------------------------------------------
TestVeafMoveHelpers = {}

function TestVeafMoveHelpers:test_findOrbitTaskInPoint_nil()
  local result = veafMove._findOrbitTaskInPoint(nil)
  luaunit.assertNil(result)
end

function TestVeafMoveHelpers:test_findOrbitTaskInPoint_no_task_key()
  local result = veafMove._findOrbitTaskInPoint({})
  luaunit.assertNil(result)
end

function TestVeafMoveHelpers:test_findOrbitTaskInPoint_task_no_params()
  local result = veafMove._findOrbitTaskInPoint({ task = {} })
  luaunit.assertNil(result)
end

function TestVeafMoveHelpers:test_findOrbitTaskInPoint_empty_tasks()
  local result = veafMove._findOrbitTaskInPoint({ task = { params = { tasks = {} } } })
  luaunit.assertNil(result)
end

function TestVeafMoveHelpers:test_findOrbitTaskInPoint_with_orbit_task()
  local point = { task = { params = { tasks = { { id = "Orbit", params = { speed = 150, altitude = 20000 } } } } } }
  local result = veafMove._findOrbitTaskInPoint(point)
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.id, "Orbit")
end

function TestVeafMoveHelpers:test_findOrbitTaskInPoint_non_orbit_task()
  local point = { task = { params = { tasks = { { id = "FAC", params = {} } } } } }
  local result = veafMove._findOrbitTaskInPoint(point)
  luaunit.assertNil(result)
end

function TestVeafMoveHelpers:test_getTankerRouteData_nonexistent()
  local result, errMsg = veafMove._getTankerRouteData("NonexistentTanker_xyz")
  luaunit.assertNil(result)
  luaunit.assertNotNil(errMsg)
end

-- ---------------------------------------------------------------------------
-- TestVeafMoveFunctions
-- ---------------------------------------------------------------------------
TestVeafMoveFunctions = {}

function TestVeafMoveFunctions:test_moveGroup_nonexistent_returns_false()
  local result = veafMove.moveGroup({ x = 0, y = 0, z = 0 }, "NonexistentGroup_abc", 20, 1000)
  luaunit.assertFalse(result)
end

function TestVeafMoveFunctions:test_changeTanker_no_units_returns_false()
  local result = veafMove.changeTanker({ x = 0, y = 0, z = 0 }, -1, -1)
  luaunit.assertFalse(result)
end

function TestVeafMoveFunctions:test_moveTanker_nonexistent_group_returns_false()
  local result = veafMove.moveTanker({ x = 0, y = 0, z = 0 }, "NonexistentTanker_abc", -1, -1, nil, nil, false, false)
  luaunit.assertFalse(result)
end

function TestVeafMoveFunctions:test_moveTanker_found_group_no_route_returns_false()
  dcs_mocks.addGroup("TKR_NO_ROUTE_TEST", {})
  local result = veafMove.moveTanker({ x = 0, y = 0, z = 0 }, "TKR_NO_ROUTE_TEST", -1, -1, nil, nil, false, false)
  luaunit.assertFalse(result)
end

function TestVeafMoveFunctions:test_teleportEscort_nonexistent_returns_false()
  local result = veafMove.teleportEscort("NonexistentEscorted_abc", { x = 0, y = 0, z = 0 }, { x = 100, y = 0, z = 100 })
  luaunit.assertFalse(result)
end

function TestVeafMoveFunctions:test_replaceMission_schedules_without_error()
  veafMove.replaceMission({}, {}, 1, false)
  luaunit.assertTrue(true)
end

function TestVeafMoveFunctions:test_findAllTankers_returns_empty_table()
  local result = veafMove.findAllTankers()
  luaunit.assertIsTable(result)
end

function TestVeafMoveFunctions:test_help_runs_without_error()
  veafMove.help(nil)
  luaunit.assertTrue(true)
end

function TestVeafMoveFunctions:test_moveAfac_nil_speed_alt_returns_false()
  local result = veafMove.moveAfac({ x = 0, y = 0, z = 0 }, "NonexistentAFAC_abc", nil, nil, nil, false)
  luaunit.assertFalse(result)
end

function TestVeafMoveFunctions:test_moveAfac_nonexistent_returns_false()
  local result = veafMove.moveAfac({ x = 0, y = 0, z = 0 }, "NonexistentAFAC_abc", 150, 15000, nil, false)
  luaunit.assertFalse(result)
end

-- ---------------------------------------------------------------------------
-- TestVeafMoveExecuteCommand
-- ---------------------------------------------------------------------------
TestVeafMoveExecuteCommand = {}

function TestVeafMoveExecuteCommand:test_nil_text_returns_nil()
  local result = veafMove.executeCommand({ x = 0, y = 0, z = 0 }, nil, false)
  luaunit.assertNil(result)
end

function TestVeafMoveExecuteCommand:test_non_matching_text_returns_nil()
  local result = veafMove.executeCommand({ x = 0, y = 0, z = 0 }, "_cas", false)
  luaunit.assertNil(result)
end

function TestVeafMoveExecuteCommand:test_no_subcommand_returns_false()
  -- _move keyphrase found but no valid subcommand → markTextAnalysis returns nil → else → false
  local result = veafMove.executeCommand({ x = 0, y = 0, z = 0 }, "_move", false)
  luaunit.assertFalse(result)
end

function TestVeafMoveExecuteCommand:test_group_command_returns_false()
  local result = veafMove.executeCommand({ x = 0, y = 0, z = 0 }, "_move group, name TestGrpExec", false)
  luaunit.assertFalse(result)
end

function TestVeafMoveExecuteCommand:test_tanker_command_returns_false()
  local result = veafMove.executeCommand({ x = 0, y = 0, z = 0 }, "_move tanker, name TKR_exec1", false)
  luaunit.assertFalse(result)
end

function TestVeafMoveExecuteCommand:test_tankermission_command_returns_false()
  local result = veafMove.executeCommand({ x = 0, y = 0, z = 0 }, "_move tankermission, name TKR_exec2", false)
  luaunit.assertFalse(result)
end

function TestVeafMoveExecuteCommand:test_afac_command_returns_false()
  local result = veafMove.executeCommand({ x = 0, y = 0, z = 0 }, "_move afac, name AFAC_exec1", false)
  luaunit.assertFalse(result)
end

-- ---------------------------------------------------------------------------
-- TestVeafMoveAdvanced
-- Covers moveTanker body, replaceMission inner function, and findAllTankers
-- inner loop by setting up real route data and a KC-135 in unitsByName.
-- ---------------------------------------------------------------------------
TestVeafMoveAdvanced = {}

function TestVeafMoveAdvanced:setUp()
  self._origSchedule    = mist.scheduleFunction
  self._origCountry     = env.mission.coalition.blue.country
  self._origUnitsByName = mist.DBs.unitsByName

  -- Execute scheduled functions synchronously (Lua 5.1: unpack, not table.unpack)
  mist.scheduleFunction = function(fn, params, time) fn(unpack(params)) end

  -- KC-135 unit for findAllTankers inner loop
  mist.DBs.unitsByName = { ["KC135_TEST"] = { type = "KC-135", groupName = "TKR_GRP" } }

  -- Two tanker groups: one without Orbit task, one with.
  env.mission.coalition.blue.country = {
    [1] = {
      vehicle = {
        group = {
          [1] = {
            groupId = "TKR_NO_ORBIT",
            name    = "TKR_NO_ORBIT",
            route   = {
              points = {
                { x = 0,      y = 0, speed = 200, alt = 6000 },
                { x = 100000, y = 0, speed = 200, alt = 6000,
                  task = { params = { tasks = {} } } },
                { x = 200000, y = 0, speed = 200, alt = 6000 },
              },
            },
          },
          [2] = {
            groupId = "TKR_WITH_ORBIT",
            name    = "TKR_WITH_ORBIT",
            route   = {
              points = {
                { x = 0,      y = 0, speed = 200, alt = 6000 },
                { x = 100000, y = 0, speed = 200, alt = 6000,
                  task = { params = { tasks = {
                    { id = "Orbit", params = { speed = 200, altitude = 6000 } },
                  } } } },
                { x = 200000, y = 0, speed = 200, alt = 6000 },
              },
            },
          },
        },
      },
    },
  }

  dcs_mocks.addGroup("TKR_NO_ORBIT", {})
  dcs_mocks.addGroup("TKR_WITH_ORBIT", {})
  for _, gname in ipairs({ "TKR_NO_ORBIT", "TKR_WITH_ORBIT" }) do
    local ctrl = Group.getByName(gname):getController()
    ctrl.setTask = function(self, task) end
  end
end

function TestVeafMoveAdvanced:tearDown()
  mist.scheduleFunction                  = self._origSchedule
  env.mission.coalition.blue.country     = self._origCountry
  mist.DBs.unitsByName                   = self._origUnitsByName
  dcs_mocks.removeGroup("TKR_NO_ORBIT")
  dcs_mocks.removeGroup("TKR_WITH_ORBIT")
end

-- Covers _getTankerRouteData body (lines 274-290) via a registered group.
function TestVeafMoveAdvanced:test_getTankerRouteData_returns_valid_data()
  local r, err = veafMove._getTankerRouteData("TKR_NO_ORBIT")
  luaunit.assertNotNil(r)
  luaunit.assertNil(err)
  luaunit.assertEquals(#r.points, 3)
end

-- Covers moveTanker body up to "no orbit task" early return (lines 421-554).
function TestVeafMoveAdvanced:test_moveTanker_no_orbit_returns_false()
  local result = veafMove.moveTanker({ x = 0, y = 0, z = 0 }, "TKR_NO_ORBIT", -1, -1, nil, nil, false, false)
  luaunit.assertFalse(result)
end

-- Covers moveTanker body with orbit found (lines 556-590) and replaceMission
-- inner function (lines 717-762) called synchronously via patched scheduler.
function TestVeafMoveAdvanced:test_moveTanker_with_orbit_returns_true()
  local result = veafMove.moveTanker({ x = 0, y = 0, z = 0 }, "TKR_WITH_ORBIT", -1, -1, nil, nil, false, false)
  luaunit.assertTrue(result)
end

-- Covers findAllTankers inner loop (lines 909-919) when unitsByName has a KC-135.
function TestVeafMoveAdvanced:test_findAllTankers_finds_kc135()
  local result = veafMove.findAllTankers()
  luaunit.assertEquals(#result, 1)
  luaunit.assertEquals(result[1], "TKR_GRP")
end

os.exit(luaunit.LuaUnit.run())
