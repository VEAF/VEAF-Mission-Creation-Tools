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

function TestVeafMoveConstants:test_version()
  luaunit.assertIsString(veafMove.Version)
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

os.exit(luaunit.LuaUnit.run())
