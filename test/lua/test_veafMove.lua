--- Tests for veafMove.lua — constants and markTextAnalysis variants.
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
-- The i18n catalog: the unknown-parameter report is a localised message, so the tests that read it
-- need the entries rather than the raw key.
dofile(src .. "/veafI18n.lua")
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
  for _ in pairs(veafMove.tankerMissionParameters) do
    count = count + 1
  end
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

-- FIX-MARKER-PARAM-CRASHES: `name` with no value used to raise inside its own log line
-- (`string.format("%s", nil)`) before the parser could reach the guard above, which already
-- refuses the command on an empty group name. The refusal is the intended answer; the crash
-- was not.
function TestVeafMoveMarkTextAnalysis:test_move_group_valueless_name_returns_nil()
  local r = veafMove.markTextAnalysis("_move group, name")
  luaunit.assertNil(r)
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
-- TestVeafMoveCharacterisation
--
-- REFACTOR-MARKER-PARSER ticket 01: what this parser does TODAY, measured. The sub-command
-- defaults below are the quirk that most needs preserving — the shared parser has to be able
-- to seed different defaults per sub-verb, or moving a tanker starts behaving like moving a
-- ground group.
-- ---------------------------------------------------------------------------
TestVeafMoveCharacterisation = {}

function TestVeafMoveCharacterisation:test_group_seeds_speed_20_and_keeps_altitude()
  local r = veafMove.markTextAnalysis("_move group, name A")
  luaunit.assertEquals(r.speed, 20)
  luaunit.assertEquals(r.altitude, -1)
end

-- -1 is the sentinel for "keep whatever the tanker already had".
function TestVeafMoveCharacterisation:test_tanker_seeds_both_sentinels()
  local r = veafMove.markTextAnalysis("_move tanker, name T")
  luaunit.assertEquals(r.speed, -1)
  luaunit.assertEquals(r.altitude, -1)
end

function TestVeafMoveCharacterisation:test_tankermission_seeds_both_sentinels()
  local r = veafMove.markTextAnalysis("_move tankermission, name T")
  luaunit.assertEquals(r.speed, -1)
  luaunit.assertEquals(r.altitude, -1)
end

function TestVeafMoveCharacterisation:test_afac_seeds_speed_150_and_altitude_15000()
  local r = veafMove.markTextAnalysis("_move afac, name F")
  luaunit.assertEquals(r.speed, 150)
  luaunit.assertEquals(r.altitude, 15000)
end

-- The sub-verb chain is tested in order and the FIRST match wins, regardless of where the
-- words appear in the text. Note "tankermission" is tested before "tanker", otherwise it
-- could never match.
function TestVeafMoveCharacterisation:test_the_first_subverb_in_the_chain_wins()
  local r = veafMove.markTextAnalysis("_move group tanker, name A")
  luaunit.assertTrue(r.moveGroup)
  luaunit.assertFalse(r.moveTanker)
end

function TestVeafMoveCharacterisation:test_subverb_is_case_insensitive()
  luaunit.assertTrue(veafMove.markTextAnalysis("_move GROUP, name A").moveGroup)
end

function TestVeafMoveCharacterisation:test_keys_are_case_insensitive()
  luaunit.assertEquals(veafMove.markTextAnalysis("_move group, NAME A").groupName, "A")
end

-- Flags ignore any value they are given rather than parsing it: `teleport false` teleports.
function TestVeafMoveCharacterisation:test_flags_ignore_their_value()
  luaunit.assertTrue(veafMove.markTextAnalysis("_move group, name A, teleport false").teleport)
  luaunit.assertTrue(veafMove.markTextAnalysis("_move group, name A, silent 0").silent)
end

function TestVeafMoveCharacterisation:test_a_repeated_keyword_keeps_the_last_value()
  luaunit.assertEquals(veafMove.markTextAnalysis("_move group, name A, name B").groupName, "B")
end

-- Zero is a real speed here, not "absent": there is no lower bound on this parameter.
function TestVeafMoveCharacterisation:test_speed_zero_is_accepted()
  luaunit.assertEquals(veafMove.markTextAnalysis("_move group, name A, speed 0").speed, 0)
end

-- FIXED (ticket 03): an unreadable numeric value used to assign nil, wiping the sentinel that
-- means "keep the original speed or altitude", so a nil travelled to moveTanker instead of -1.
function TestVeafMoveCharacterisation:test_an_unreadable_speed_keeps_the_sentinel()
  luaunit.assertEquals(veafMove.markTextAnalysis("_move tanker, name T, speed").speed, -1)
  luaunit.assertEquals(veafMove.markTextAnalysis("_move tanker, name T, speed banana").speed, -1)
end

function TestVeafMoveCharacterisation:test_an_unreadable_altitude_keeps_the_sentinel()
  luaunit.assertEquals(veafMove.markTextAnalysis("_move tanker, name T, alt banana").altitude, -1)
end

-- A group move seeds speed 20, so that is what an unreadable speed falls back to there.
function TestVeafMoveCharacterisation:test_an_unreadable_speed_keeps_the_group_default()
  luaunit.assertEquals(veafMove.markTextAnalysis("_move group, name A, speed banana").speed, 20)
end

-- FEAT-SPAWN-OPTION-VALIDATION renamed this: an unknown keyword is no longer ignored, it is
-- collected so the caller can name it to the pilot and abort. What the original test proved and
-- this one still proves: the **recognised** options are untouched by the presence of a bad one.
function TestVeafMoveCharacterisation:test_an_unknown_keyword_is_collected_not_ignored()
  local r = veafMove.markTextAnalysis("_move group, name A, banana 3")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.speed, 20)
  luaunit.assertEquals(r.unknownParameters[1].key, "banana")
  luaunit.assertEquals(#r.unknownParameters, 1)
end

function TestVeafMoveCharacterisation:test_empty_text_returns_nil()
  luaunit.assertNil(veafMove.markTextAnalysis(""))
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
  self._origSchedule = veaf.scheduleFunction
  self._origCountry = env.mission.coalition.blue.country
  self._origUnitsByName = veafMissionDb.unitsByName

  -- Execute scheduled functions synchronously (Lua 5.1: unpack, not table.unpack)
  veaf.scheduleFunction = function(fn, params, time)
    fn(unpack(params))
  end

  -- KC-135 unit for findAllTankers inner loop
  veafMissionDb.unitsByName = { ["KC135_TEST"] = { type = "KC-135", groupName = "TKR_GRP" } }

  -- Two tanker groups: one without Orbit task, one with.
  env.mission.coalition.blue.country = {
    [1] = {
      vehicle = {
        group = {
          [1] = {
            groupId = "TKR_NO_ORBIT",
            name = "TKR_NO_ORBIT",
            route = {
              points = {
                { x = 0, y = 0, speed = 200, alt = 6000 },
                { x = 100000, y = 0, speed = 200, alt = 6000, task = { params = { tasks = {} } } },
                { x = 200000, y = 0, speed = 200, alt = 6000 },
              },
            },
          },
          [2] = {
            groupId = "TKR_WITH_ORBIT",
            name = "TKR_WITH_ORBIT",
            route = {
              points = {
                { x = 0, y = 0, speed = 200, alt = 6000 },
                {
                  x = 100000,
                  y = 0,
                  speed = 200,
                  alt = 6000,
                  task = {
                    params = {
                      tasks = {
                        { id = "Orbit", params = { speed = 200, altitude = 6000 } },
                      },
                    },
                  },
                },
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
  veaf.scheduleFunction = self._origSchedule
  env.mission.coalition.blue.country = self._origCountry
  veafMissionDb.unitsByName = self._origUnitsByName
  dcs_mocks.removeGroup("TKR_NO_ORBIT")
  dcs_mocks.removeGroup("TKR_WITH_ORBIT")
end

-- Covers _getTankerRouteData body via a registered group.
function TestVeafMoveAdvanced:test_getTankerRouteData_returns_valid_data()
  local r, err = veafMove._getTankerRouteData("TKR_WITH_ORBIT")
  luaunit.assertNotNil(r)
  luaunit.assertNil(err)
  luaunit.assertEquals(#r.points, 3)
end

-- Was asserted the other way round until FIX-MOVE-ORBIT-SEARCH: the helper used to hand back the last
-- three waypoints of *any* route, orbit or no orbit, leaving each caller to discover the absence for
-- itself. It now refuses here, which is the point of #248 — "moving a tanker to the wrong place is
-- worse than telling the player it cannot be done".
function TestVeafMoveAdvanced:test_getTankerRouteData_refuses_a_route_with_no_orbit()
  local r, err = veafMove._getTankerRouteData("TKR_NO_ORBIT")
  luaunit.assertNil(r)
  luaunit.assertStrContains(err, "ORBIT")
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

-- ============================================================================
-- TestVeafMoveNonNumericValues -- SECREV-2 / VMR-092
-- ============================================================================
--- The keyword handlers logged the value with string.format("%d", val) *before* tonumber(), on the
--- raw text the pilot typed. In Lua 5.1 that raises on "abc" -- and, measured, %s raises on nil too,
--- which is what a keyword given with no value at all produces. So a typo in a marker took the whole
--- parser down instead of being ignored.
TestVeafMoveNonNumericValues = {}

function TestVeafMoveNonNumericValues:_analyse(text)
  local ok, result = pcall(veafMove.markTextAnalysis, text)
  luaunit.assertTrue(ok, "the parser must not raise on: " .. text .. " (" .. tostring(result) .. ")")
  return result
end

-- REFACTOR-MARKER-PARSER ticket 03 changed the expectation of the next two tests, and the reason
-- is worth stating because "unset, not crash" looked like the safe answer when VMR-092 wrote it.
--
-- Unset moved the crash rather than removing it. `veafMove.moveGroup` opens with
-- `"... speed = " .. speed`, and concatenating nil raises — measured, for both `speed` and
-- `altitude`. So `_move group, name SomeGroup, speed abc` parsed cleanly and then took the command
-- down one call later. The other three consumers happen to tolerate nil (`moveTanker` tests
-- `speed == nil or speed < 0`), which is why this stayed invisible.
--
-- Keeping the seeded default is what actually removes the crash: the parameter is ignored, the
-- command runs, and the pilot loses the parameter rather than the order.
function TestVeafMoveNonNumericValues:test_a_non_numeric_speed_keeps_the_default_rather_than_unsetting()
  local r = self:_analyse("_move group, name SomeGroup, speed abc")

  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.speed, 20, "an unparseable speed must keep the sub-command's default")
end

function TestVeafMoveNonNumericValues:test_a_keyword_with_no_value_keeps_the_default()
  local r = self:_analyse("_move group, name SomeGroup, speed")

  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.speed, 20)
end

-- The crash this now prevents, asserted on the whole command path rather than on the parser:
-- an unreadable numeric parameter must not take the order down downstream either.
function TestVeafMoveNonNumericValues:test_the_whole_command_survives_an_unreadable_number()
  for _, text in ipairs({
    "_move group, name SomeGroup, speed abc",
    "_move group, name SomeGroup, speed",
    "_move group, name SomeGroup, alt abc",
  }) do
    local ok, err = pcall(veafMove.executeCommand, { x = 0, y = 0, z = 0 }, text, true)
    luaunit.assertTrue(ok, text .. " raised: " .. tostring(err))
  end
end

function TestVeafMoveNonNumericValues:test_every_numeric_keyword_survives_a_bad_value()
  for _, keyword in ipairs({ "speed", "hdg", "distance", "alt" }) do
    local r = self:_analyse("_move group, name SomeGroup, " .. keyword .. " notanumber")
    luaunit.assertNotNil(r, keyword .. " must still return a result")
  end
end

function TestVeafMoveNonNumericValues:test_a_numeric_value_is_still_parsed()
  local r = self:_analyse("_move group, name SomeGroup, speed 250")

  luaunit.assertEquals(r.speed, 250)
end

-------------------------------------------------------------------------------------------------
-- FIX-MOVE-ORBIT-SEARCH — #248, reported by Maveric
--
-- The orbit was looked for on the second-to-last waypoint. True of VEAF's own templates, whose route
-- is [approach, orbit, leg end]; false of a DCS-Liberation tanker, whose longer route ends with a
-- landing point — so both tanker commands refused with "has no ORBIT task defined".
--
-- The orbit is now searched for wherever it is.
-------------------------------------------------------------------------------------------------

TestVeafMoveOrbitSearch = {}

--- A waypoint carrying an Orbit task, optionally with a pattern.
local function _orbitPoint(x, pattern)
  local params = { speed = 200, altitude = 6000 }
  if pattern then
    params.pattern = pattern
  end
  return {
    x = x,
    y = 0,
    speed = 200,
    alt = 6000,
    task = { params = { tasks = { { id = "Orbit", params = params } } } },
  }
end

local function _plainPoint(x)
  return { x = x, y = 0, speed = 200, alt = 6000 }
end

function TestVeafMoveOrbitSearch:test_a_veaf_template_still_finds_its_orbit()
  -- [approach, orbit, leg end] — the shape that always worked, asserted so it keeps working
  local points = { _plainPoint(0), _orbitPoint(100000), _plainPoint(200000) }
  local index, task = veafMove._findOrbitWaypoint(points)
  luaunit.assertEquals(index, 2)
  luaunit.assertNotNil(task)
end

-- The defect of #248, in one assertion: a Liberation route whose orbit is nowhere near the end.
function TestVeafMoveOrbitSearch:test_an_orbit_in_the_middle_of_a_long_route_is_found()
  local points = {
    _plainPoint(0), -- take-off
    _plainPoint(10000),
    _orbitPoint(100000), -- the working orbit
    _plainPoint(110000), -- leg end
    _plainPoint(200000),
    _plainPoint(300000), -- landing
  }
  luaunit.assertEquals(veafMove._findOrbitWaypoint(points), 3)
end

function TestVeafMoveOrbitSearch:test_no_orbit_anywhere_returns_nil()
  local points = { _plainPoint(0), _plainPoint(1), _plainPoint(2) }
  luaunit.assertNil(veafMove._findOrbitWaypoint(points))
end

-- Recorded decision: the first orbit wins. A tanker route has one working orbit; if several exist the
-- first is the one the tanker reaches first, so the one that is active or imminent.
function TestVeafMoveOrbitSearch:test_the_first_orbit_wins()
  local points = { _plainPoint(0), _orbitPoint(100000), _plainPoint(150000), _orbitPoint(200000) }
  luaunit.assertEquals(veafMove._findOrbitWaypoint(points), 2)
end

function TestVeafMoveOrbitSearch:test_an_orbit_on_the_first_waypoint_is_found()
  local points = { _orbitPoint(0), _plainPoint(100000) }
  luaunit.assertEquals(veafMove._findOrbitWaypoint(points), 1)
end

function TestVeafMoveOrbitSearch:test_an_orbit_on_the_last_waypoint_is_found()
  local points = { _plainPoint(0), _orbitPoint(100000) }
  luaunit.assertEquals(veafMove._findOrbitWaypoint(points), 2)
end

-- ---------------------------------------------------------------------------
-- The neighbours of the orbit, which callers read and overwrite
-- ---------------------------------------------------------------------------
TestVeafMoveOrbitNeighbours = {}

function TestVeafMoveOrbitNeighbours:setUp()
  self._getGroupData = veaf.getGroupData
end

function TestVeafMoveOrbitNeighbours:tearDown()
  veaf.getGroupData = self._getGroupData
end

--- Make _getTankerRouteData see exactly this route.
function TestVeafMoveOrbitNeighbours:_routeOf(points)
  veaf.getGroupData = function()
    return { route = { points = points } }
  end
  return veafMove._getTankerRouteData("TANKER")
end

function TestVeafMoveOrbitNeighbours:test_the_neighbours_of_a_mid_route_orbit()
  local points = { _plainPoint(0), _plainPoint(1), _orbitPoint(2), _plainPoint(3), _plainPoint(4) }
  local r = self:_routeOf(points)
  luaunit.assertEquals(r.orbitIndex, 3)
  luaunit.assertIs(r.point1, points[2])
  luaunit.assertIs(r.point2, points[3])
  luaunit.assertIs(r.point3, points[4])
end

-- point1 is optional: an orbit on the first waypoint has no approach point before it, and refusing
-- such a route would trade one false refusal for another.
function TestVeafMoveOrbitNeighbours:test_no_point1_when_the_orbit_is_first()
  local r = self:_routeOf({ _orbitPoint(0), _plainPoint(1) })
  luaunit.assertNil(r.point1)
  luaunit.assertNotNil(r.point2)
  luaunit.assertNotNil(r.point3)
end

function TestVeafMoveOrbitNeighbours:test_no_point3_when_the_orbit_is_last()
  local r = self:_routeOf({ _plainPoint(0), _orbitPoint(1) })
  luaunit.assertNotNil(r.point1)
  luaunit.assertNil(r.point3)
end

-- A Race-Track orbit flies between its waypoint and the next one, which is DCS's own semantics and
-- the reason callers may overwrite point3 — on a long route as much as on a VEAF template.
function TestVeafMoveOrbitNeighbours:test_a_race_track_orbit_keeps_its_leg_end()
  local points = { _plainPoint(0), _orbitPoint(1, "Race-Track"), _plainPoint(2) }
  local r = self:_routeOf(points)
  luaunit.assertIs(r.point3, points[3])
end

-- A Circle orbit turns around a single point and gives the next waypoint no orbit role, so handing it
-- over as point3 would let a caller silently redraw the route — on a Liberation tanker, that waypoint
-- could be the landing.
function TestVeafMoveOrbitNeighbours:test_a_circle_orbit_withholds_the_next_waypoint()
  local r = self:_routeOf({ _plainPoint(0), _orbitPoint(1, "Circle"), _plainPoint(2) })
  luaunit.assertNil(r.point3)
  luaunit.assertNotNil(r.point2, "the orbit itself is still returned")
end

function TestVeafMoveOrbitNeighbours:test_the_orbit_task_is_returned_with_the_route()
  local r = self:_routeOf({ _plainPoint(0), _orbitPoint(1), _plainPoint(2) })
  luaunit.assertNotNil(r.orbitTask)
  luaunit.assertEquals(r.orbitTask.id, "Orbit")
end

-- A one-waypoint route that *is* the orbit is legal and no longer refused for being too short: the
-- old helper wanted three waypoints because it counted backwards from the end.
function TestVeafMoveOrbitNeighbours:test_a_single_waypoint_orbit_is_accepted()
  local r, err = self:_routeOf({ _orbitPoint(0) })
  luaunit.assertNotNil(r)
  luaunit.assertNil(err)
  luaunit.assertNil(r.point1)
  luaunit.assertNil(r.point3)
end

-- ============================================================================
-- FEAT-SPAWN-OPTION-VALIDATION — the abort, at the handler level
--
-- David's arbitration, 2026-08-21: warn and ABORT, consistent with `_spawn`, which has done that since
-- UXPILOT-003. A typo must never run a half-understood command.
-- ============================================================================
TestVeafMoveUnknownParameterAborts = {}

function TestVeafMoveUnknownParameterAborts:setUp()
  self._report = veaf.reportToPilot
  self.reported = {}
  local reported = self.reported
  veaf.reportToPilot = function(message)
    table.insert(reported, message)
  end
  self._moveGroup = veafMove.moveGroup
  self.moved = 0
  veafMove.moveGroup = function()
    self.moved = self.moved + 1
    return true
  end
end

function TestVeafMoveUnknownParameterAborts:tearDown()
  veaf.reportToPilot = self._report
  veafMove.moveGroup = self._moveGroup
end

function TestVeafMoveUnknownParameterAborts:test_a_good_command_still_moves()
  local result = veafMove.executeCommand({ x = 0, y = 0, z = 0 }, "_move group, name test", true)
  luaunit.assertEquals(self.moved, 1)
  luaunit.assertEquals(#self.reported, 0)
  luaunit.assertTrue(result)
end

function TestVeafMoveUnknownParameterAborts:test_a_typo_aborts_and_is_named()
  local result = veafMove.executeCommand({ x = 0, y = 0, z = 0 }, "_move group, name test, banana 3", true)
  luaunit.assertEquals(self.moved, 0, "nothing may move on a half-understood command")
  luaunit.assertEquals(#self.reported, 1)
  luaunit.assertNotNil(self.reported[1]:find("banana", 1, true))
  luaunit.assertFalse(result)
end

function TestVeafMoveUnknownParameterAborts:test_the_message_names_the_module()
  veafMove.executeCommand({ x = 0, y = 0, z = 0 }, "_move group, name test, banana 3", true)
  -- the label is veafMove.Id, the same string the module's log lines carry
  luaunit.assertNotNil(self.reported[1]:find(veafMove.Id, 1, true))
end

os.exit(luaunit.LuaUnit.run())
