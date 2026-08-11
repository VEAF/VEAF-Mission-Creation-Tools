--- Tests for veafCasMission.lua — constants and TRANSPORT_TYPES structure.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafCasMission.lua")

-- ---------------------------------------------------------------------------
-- TestVeafCasMissionConstants
-- ---------------------------------------------------------------------------
TestVeafCasMissionConstants = {}

function TestVeafCasMissionConstants:test_keyphrase()
  luaunit.assertEquals(veafCasMission.Keyphrase, "_cas")
end

function TestVeafCasMissionConstants:test_id()
  luaunit.assertEquals(veafCasMission.Id, "CASMISSION")
end

function TestVeafCasMissionConstants:test_secondsBetweenWatchdogChecks()
  luaunit.assertEquals(veafCasMission.SecondsBetweenWatchdogChecks, 15)
end

function TestVeafCasMissionConstants:test_secondsBetweenSmokeRequests()
  luaunit.assertEquals(veafCasMission.SecondsBetweenSmokeRequests, 180)
end

function TestVeafCasMissionConstants:test_secondsBetweenFlareRequests()
  luaunit.assertEquals(veafCasMission.SecondsBetweenFlareRequests, 120)
end

-- ---------------------------------------------------------------------------
-- TestVeafCasTransportTypes
-- ---------------------------------------------------------------------------
TestVeafCasTransportTypes = {}

function TestVeafCasTransportTypes:test_transport_types_is_table()
  luaunit.assertIsTable(veafCasMission.TRANSPORT_TYPES)
end

function TestVeafCasTransportTypes:test_transport_types_has_two_entries()
  luaunit.assertEquals(#veafCasMission.TRANSPORT_TYPES, 2)
end

function TestVeafCasTransportTypes:test_each_entry_has_modern_key()
  for _, entry in ipairs(veafCasMission.TRANSPORT_TYPES) do
    luaunit.assertNotNil(entry.MODERN)
  end
end

function TestVeafCasTransportTypes:test_each_entry_has_ww2_key()
  for _, entry in ipairs(veafCasMission.TRANSPORT_TYPES) do
    luaunit.assertNotNil(entry.WW2)
  end
end

function TestVeafCasTransportTypes:test_each_entry_has_cold_war_key()
  for _, entry in ipairs(veafCasMission.TRANSPORT_TYPES) do
    luaunit.assertNotNil(entry.COLD_WAR)
  end
end

-- ---------------------------------------------------------------------------
-- TestVeafCasMarkTextAnalysis
-- ---------------------------------------------------------------------------
TestVeafCasMarkTextAnalysis = {}

function TestVeafCasMarkTextAnalysis:test_matching_keyphrase_returns_table()
  local r = veafCasMission.markTextAnalysis("_cas")
  luaunit.assertIsTable(r)
end

function TestVeafCasMarkTextAnalysis:test_non_matching_returns_nil()
  local r = veafCasMission.markTextAnalysis("_spawn")
  luaunit.assertNil(r)
end

function TestVeafCasMarkTextAnalysis:test_cas_field_set()
  local r = veafCasMission.markTextAnalysis("_cas")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.casmission)
end

-- ---------------------------------------------------------------------------
-- TestVeafCasMarkTextAnalysisKeywords
-- ---------------------------------------------------------------------------
TestVeafCasMarkTextAnalysisKeywords = {}

function TestVeafCasMarkTextAnalysisKeywords:test_password_keyword()
  local r = veafCasMission.markTextAnalysis("_cas, password secret")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.password, "secret")
end

function TestVeafCasMarkTextAnalysisKeywords:test_size_keyword()
  local r = veafCasMission.markTextAnalysis("_cas, size 3")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.size, 3)
end

function TestVeafCasMarkTextAnalysisKeywords:test_defense_keyword()
  local r = veafCasMission.markTextAnalysis("_cas, defense 2")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.defense, 2)
end

function TestVeafCasMarkTextAnalysisKeywords:test_armor_keyword()
  local r = veafCasMission.markTextAnalysis("_cas, armor 4")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.armor, 4)
end

function TestVeafCasMarkTextAnalysisKeywords:test_spacing_keyword()
  local r = veafCasMission.markTextAnalysis("_cas, spacing 2")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.spacing, 2)
end

function TestVeafCasMarkTextAnalysisKeywords:test_side_blue()
  local r = veafCasMission.markTextAnalysis("_cas, side BLUE")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.side, veafCasMission.SIDE_BLUE)
end

function TestVeafCasMarkTextAnalysisKeywords:test_side_non_blue_is_red()
  local r = veafCasMission.markTextAnalysis("_cas, side RED")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.side, veafCasMission.SIDE_RED)
end

function TestVeafCasMarkTextAnalysisKeywords:test_disperse_with_value()
  local r = veafCasMission.markTextAnalysis("_cas, disperse 30")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.disperseOnAttack, 30)
end

-- ---------------------------------------------------------------------------
-- TestVeafCasMarkTextAnalysisBadParameters
--
-- FIX-MARKER-PARAM-CRASHES: a parameter the pilot mistyped costs that parameter,
-- never the command. `side` was the one site VMR-019 missed here: it fixed the four
-- `string.format("%d", val)` keywords and left this one's `%s`, which raises on nil
-- just the same, with `val:upper()` on the next line waiting behind it.
-- ---------------------------------------------------------------------------
TestVeafCasMarkTextAnalysisBadParameters = {}

function TestVeafCasMarkTextAnalysisBadParameters:test_side_without_value_does_not_raise()
  local r = veafCasMission.markTextAnalysis("_cas, side")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.casmission)
end

-- A valueless `side` must leave the field unset, not fall through to RED: executeCommand
-- then derives the side from the marker's own coalition, which is the intended path.
function TestVeafCasMarkTextAnalysisBadParameters:test_side_without_value_leaves_side_unset()
  local r = veafCasMission.markTextAnalysis("_cas, side")
  luaunit.assertNotNil(r)
  luaunit.assertNil(r.side)
end

function TestVeafCasMarkTextAnalysisBadParameters:test_size_without_value_keeps_default()
  local r = veafCasMission.markTextAnalysis("_cas, size")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.size, 1)
end

function TestVeafCasMarkTextAnalysisBadParameters:test_size_non_numeric_keeps_default()
  local r = veafCasMission.markTextAnalysis("_cas, size banana")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.size, 1)
end

-- SECREV-007: generateAirDefenseGroup must return nil (not dereference a nil
-- group) when the underlying group definition cannot be found.
TestVeafCasMissionAirDefense = {}

function TestVeafCasMissionAirDefense:test_returns_nil_when_group_not_found()
  local savedVeafUnits = veafUnits
  veafUnits = {
    findGroup = function()
      return nil
    end,
  }
  local result = veafCasMission.generateAirDefenseGroup("AD-1", 1, veafCasMission.SIDE_RED)
  veafUnits = savedVeafUnits
  luaunit.assertNil(result)
end

-------------------------------------------------------------------------------------------------
-- SECREV-2 / VMR-019 — a valueless numeric keyword must not take the handler down
--
-- `_cas, size` (no value) reached `string.format("Keyword size = %d", nil)` and then
-- `tonumber(nil) <= 5`. Either one raises, and the marker handler dies with it -- so a typo
-- silently killed the command instead of ignoring one parameter.
-------------------------------------------------------------------------------------------------

TestVeafCasMissionNumericKeywords = {}

function TestVeafCasMissionNumericKeywords:_analyse(text)
  return veafCasMission.markTextAnalysis(text)
end

function TestVeafCasMissionNumericKeywords:test_valueless_size_does_not_crash()
  local ok, result = pcall(function()
    return self:_analyse("_cas, size")
  end)
  luaunit.assertTrue(ok, "a valueless size keyword must not raise")
  luaunit.assertNotNil(result)
end

function TestVeafCasMissionNumericKeywords:test_valueless_defense_does_not_crash()
  local ok = pcall(function()
    return self:_analyse("_cas, defense")
  end)
  luaunit.assertTrue(ok)
end

function TestVeafCasMissionNumericKeywords:test_valueless_armor_does_not_crash()
  local ok = pcall(function()
    return self:_analyse("_cas, armor")
  end)
  luaunit.assertTrue(ok)
end

function TestVeafCasMissionNumericKeywords:test_valueless_spacing_does_not_crash()
  local ok = pcall(function()
    return self:_analyse("_cas, spacing")
  end)
  luaunit.assertTrue(ok)
end

function TestVeafCasMissionNumericKeywords:test_garbage_size_does_not_crash()
  local ok = pcall(function()
    return self:_analyse("_cas, size banana")
  end)
  luaunit.assertTrue(ok)
end

function TestVeafCasMissionNumericKeywords:test_a_valid_size_is_still_honoured()
  -- Guard: the crash fix must not stop the parameter working.
  local result = self:_analyse("_cas, size 3")
  luaunit.assertEquals(result.size, 3)
end

function TestVeafCasMissionNumericKeywords:test_out_of_range_size_is_still_ignored()
  -- Behaviour deliberately preserved: an out-of-range value is ignored, not clamped.
  local result = self:_analyse("_cas, size 9")
  luaunit.assertNotEquals(result.size, 9)
end

os.exit(luaunit.LuaUnit.run())
