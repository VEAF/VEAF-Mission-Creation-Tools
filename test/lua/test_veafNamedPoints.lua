--- Unit tests for veafNamedPoints.lua
---
--- Run:  lua test/lua/test_veafNamedPoints.lua
---
--- Covers:
---   - addPoint / getPoint: basic storage and case-insensitive retrieval
---   - delPoint: verifies the bug fix (was: table.remove with string key;
---               now: namedPoints[name:upper()] = nil)
---   - markTextAnalysis: keyphrase detection and name extraction
---   - addDataToPoint: field merging and nil-point guard

local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafMissionDb.lua")
dofile(src .. "/veafNamedPoints.lua")

-- ============================================================================
-- Test suite
-- ============================================================================
TestVeafNamedPoints = {}

function TestVeafNamedPoints:setUp()
  dcs_mocks.reset()
  -- Wipe the named-point dict so tests are independent
  veafNamedPoints.namedPoints = {}
end

-- -----------------------------------------------------------------------
-- addPoint / getPoint
-- -----------------------------------------------------------------------
function TestVeafNamedPoints:test_addPoint_stores_uppercase_key()
  veafNamedPoints.addPoint("alpha", { x = 1, y = 0, z = 2 })
  luaunit.assertNotNil(veafNamedPoints.namedPoints["ALPHA"])
end

function TestVeafNamedPoints:test_addPoint_stores_correct_coordinates()
  veafNamedPoints.addPoint("lima", { x = 10, y = 5, z = 20 })
  local pt = veafNamedPoints.namedPoints["LIMA"]
  luaunit.assertEquals(pt.x, 10)
  luaunit.assertEquals(pt.y, 5)
  luaunit.assertEquals(pt.z, 20)
end

function TestVeafNamedPoints:test_getPoint_retrieves_lowercase_key()
  veafNamedPoints.addPoint("BEIRUT", { x = 10, y = 0, z = 20 })
  local pt = veafNamedPoints.getPoint("beirut")
  luaunit.assertNotNil(pt)
  luaunit.assertEquals(pt.x, 10)
end

function TestVeafNamedPoints:test_getPoint_retrieves_uppercase_key()
  veafNamedPoints.addPoint("beirut", { x = 10, y = 0, z = 20 })
  local pt = veafNamedPoints.getPoint("BEIRUT")
  luaunit.assertNotNil(pt)
end

function TestVeafNamedPoints:test_getPoint_retrieves_mixed_case()
  veafNamedPoints.addPoint("Damascus", { x = 5, y = 0, z = 5 })
  luaunit.assertNotNil(veafNamedPoints.getPoint("damascus"))
  luaunit.assertNotNil(veafNamedPoints.getPoint("DAMASCUS"))
  luaunit.assertNotNil(veafNamedPoints.getPoint("Damascus"))
end

function TestVeafNamedPoints:test_getPoint_returns_nil_for_unknown()
  luaunit.assertNil(veafNamedPoints.getPoint("NOWHERE"))
end

function TestVeafNamedPoints:test_addPoint_overwrites_existing_entry()
  veafNamedPoints.addPoint("alpha", { x = 1, y = 0, z = 2 })
  veafNamedPoints.addPoint("alpha", { x = 99, y = 0, z = 0 })
  luaunit.assertEquals(veafNamedPoints.getPoint("ALPHA").x, 99)
end

function TestVeafNamedPoints:test_multiple_points_stored_independently()
  veafNamedPoints.addPoint("alpha", { x = 1, y = 0, z = 0 })
  veafNamedPoints.addPoint("beta", { x = 2, y = 0, z = 0 })
  luaunit.assertEquals(veafNamedPoints.getPoint("ALPHA").x, 1)
  luaunit.assertEquals(veafNamedPoints.getPoint("BETA").x, 2)
end

-- -----------------------------------------------------------------------
-- delPoint  (bug was: table.remove(dict, stringKey) — now fixed)
-- -----------------------------------------------------------------------
function TestVeafNamedPoints:test_delPoint_removes_entry()
  veafNamedPoints.addPoint("alpha", { x = 1, y = 0, z = 2 })
  veafNamedPoints.delPoint("alpha")
  luaunit.assertNil(veafNamedPoints.getPoint("ALPHA"))
end

function TestVeafNamedPoints:test_delPoint_case_insensitive()
  veafNamedPoints.addPoint("BEIRUT", { x = 10, y = 0, z = 20 })
  veafNamedPoints.delPoint("beirut")
  luaunit.assertNil(veafNamedPoints.getPoint("BEIRUT"))
end

function TestVeafNamedPoints:test_delPoint_does_not_affect_other_entries()
  veafNamedPoints.addPoint("alpha", { x = 1, y = 0, z = 0 })
  veafNamedPoints.addPoint("beta", { x = 2, y = 0, z = 0 })
  veafNamedPoints.delPoint("alpha")
  luaunit.assertNil(veafNamedPoints.getPoint("ALPHA"))
  luaunit.assertNotNil(veafNamedPoints.getPoint("BETA"))
end

function TestVeafNamedPoints:test_delPoint_nonexistent_is_safe()
  -- Deleting a key that was never stored should not error
  veafNamedPoints.delPoint("NONEXISTENT")
  luaunit.assertNil(veafNamedPoints.getPoint("NONEXISTENT"))
end

function TestVeafNamedPoints:test_delPoint_then_readd_works()
  veafNamedPoints.addPoint("alpha", { x = 1, y = 0, z = 0 })
  veafNamedPoints.delPoint("alpha")
  veafNamedPoints.addPoint("alpha", { x = 5, y = 0, z = 0 })
  luaunit.assertEquals(veafNamedPoints.getPoint("ALPHA").x, 5)
end

-- -----------------------------------------------------------------------
-- markTextAnalysis
-- -----------------------------------------------------------------------
function TestVeafNamedPoints:test_markTextAnalysis_found_single_word()
  local sw = veafNamedPoints.markTextAnalysis("_name point Beirut")
  luaunit.assertTrue(sw.namepoint)
  luaunit.assertEquals(sw.name, "Beirut")
end

function TestVeafNamedPoints:test_markTextAnalysis_found_multi_word()
  local sw = veafNamedPoints.markTextAnalysis("_name point Beirut Intl")
  luaunit.assertTrue(sw.namepoint)
  luaunit.assertEquals(sw.name, "Beirut Intl")
end

function TestVeafNamedPoints:test_markTextAnalysis_name_extraction_no_trim()
  -- The function returns the raw substring; trimming is NOT applied
  local sw = veafNamedPoints.markTextAnalysis("_name point TestCity")
  luaunit.assertNotNil(sw)
  luaunit.assertTrue(sw.namepoint)
  luaunit.assertEquals(sw.name, "TestCity")
end

function TestVeafNamedPoints:test_markTextAnalysis_case_insensitive_keyphrase()
  -- text:lower():find(keyphrase) → case-insensitive match
  local sw = veafNamedPoints.markTextAnalysis("_NAME POINT TestCity")
  luaunit.assertNotNil(sw)
  luaunit.assertTrue(sw.namepoint)
end

function TestVeafNamedPoints:test_markTextAnalysis_not_found()
  -- When the keyphrase is absent the function returns nil
  luaunit.assertNil(veafNamedPoints.markTextAnalysis("_spawn infantry"))
end

function TestVeafNamedPoints:test_markTextAnalysis_empty_text()
  luaunit.assertNil(veafNamedPoints.markTextAnalysis(""))
end

function TestVeafNamedPoints:test_markTextAnalysis_unrelated_text()
  luaunit.assertNil(veafNamedPoints.markTextAnalysis("hello world foo bar"))
end

-- -----------------------------------------------------------------------
-- addDataToPoint
-- -----------------------------------------------------------------------
function TestVeafNamedPoints:test_addDataToPoint_merges_new_fields()
  local pt = { x = 1, y = 0, z = 2 }
  local result = veafNamedPoints.addDataToPoint(pt, { altitude = 1500, name = "Beirut" })
  luaunit.assertEquals(result.altitude, 1500)
  luaunit.assertEquals(result.name, "Beirut")
  luaunit.assertEquals(result.x, 1)
end

function TestVeafNamedPoints:test_addDataToPoint_overwrites_existing_field()
  local pt = { x = 1, y = 0, z = 2, altitude = 100 }
  veafNamedPoints.addDataToPoint(pt, { altitude = 500 })
  luaunit.assertEquals(pt.altitude, 500)
end

function TestVeafNamedPoints:test_addDataToPoint_returns_modified_point()
  local pt = { x = 1 }
  local result = veafNamedPoints.addDataToPoint(pt, { y = 2 })
  -- result should be the same table object
  luaunit.assertEquals(result, pt)
end

function TestVeafNamedPoints:test_addDataToPoint_nil_point_returns_nil()
  local result = veafNamedPoints.addDataToPoint(nil, { x = 1 })
  luaunit.assertNil(result)
end

function TestVeafNamedPoints:test_addDataToPoint_empty_data_leaves_point_unchanged()
  local pt = { x = 1, y = 0, z = 2 }
  veafNamedPoints.addDataToPoint(pt, {})
  luaunit.assertEquals(pt.x, 1)
  luaunit.assertEquals(pt.y, 0)
  luaunit.assertEquals(pt.z, 2)
end

-- ============================================================================
os.exit(luaunit.LuaUnit.run())
