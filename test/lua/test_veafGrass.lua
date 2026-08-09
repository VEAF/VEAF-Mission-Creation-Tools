--- Tests for veafGrass.lua — constants and helicoptersOnFARPs list.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafGrass.lua")

-- ---------------------------------------------------------------------------
-- TestVeafGrassConstants
-- ---------------------------------------------------------------------------
TestVeafGrassConstants = {}

function TestVeafGrassConstants:test_id()
  luaunit.assertEquals(veafGrass.Id, "GRASS")
end

function TestVeafGrassConstants:test_radius_around_farp()
  luaunit.assertEquals(veafGrass.RadiusAroundFarp, 2000)
end

function TestVeafGrassConstants:test_delay_for_startup()
  luaunit.assertEquals(veafGrass.DelayForStartup, 2)
end

-- ---------------------------------------------------------------------------
-- TestVeafGrassHelicopters
-- ---------------------------------------------------------------------------
TestVeafGrassHelicopters = {}

function TestVeafGrassHelicopters:test_helicopters_list_is_table()
  luaunit.assertIsTable(veafGrass.helicoptersOnFARPs)
end

function TestVeafGrassHelicopters:test_helicopters_list_has_18_entries()
  luaunit.assertEquals(#veafGrass.helicoptersOnFARPs, 18)
end

function TestVeafGrassHelicopters:test_sa342mistral_present()
  local found = false
  for _, h in ipairs(veafGrass.helicoptersOnFARPs) do
    if h == "SA342Mistral" then found = true end
  end
  luaunit.assertTrue(found)
end

function TestVeafGrassHelicopters:test_uh1h_present()
  local found = false
  for _, h in ipairs(veafGrass.helicoptersOnFARPs) do
    if h == "UH-1H" then found = true end
  end
  luaunit.assertTrue(found)
end

function TestVeafGrassHelicopters:test_mi24p_present()
  local found = false
  for _, h in ipairs(veafGrass.helicoptersOnFARPs) do
    if h == "Mi-24P" then found = true end
  end
  luaunit.assertTrue(found)
end

function TestVeafGrassHelicopters:test_ah64d_present()
  local found = false
  for _, h in ipairs(veafGrass.helicoptersOnFARPs) do
    if h == "AH-64D_BLK_II" then found = true end
  end
  luaunit.assertTrue(found)
end

function TestVeafGrassHelicopters:test_first_entry_is_sa342()
  luaunit.assertEquals(veafGrass.helicoptersOnFARPs[1], "SA342Mistral")
end

function TestVeafGrassHelicopters:test_last_entry_is_ch47()
  luaunit.assertEquals(veafGrass.helicoptersOnFARPs[18], "CH-47Fbl1")
end


-------------------------------------------------------------------------------------------------
-- SECREV-2 / VMR-022 — the FARP coalition normalisation had two dead guards
--
--     if type(farpCoalition == "number") then
--
-- The closing parenthesis is in the wrong place, so this evaluates `type(boolean)`, which is
-- always the string "boolean" and always truthy. Both guards therefore always ran.
--
-- That is not merely dead code. With both blocks always executing, a FARP whose coalition
-- arrives as the **string** "red" fails the `== 1` test in the first block, falls into its
-- `else`, and comes out **blue** — the FARP is built for the wrong side.
-------------------------------------------------------------------------------------------------

TestVeafGrassFarpCoalition = {}

function TestVeafGrassFarpCoalition:test_numeric_red_stays_red()
  local name, number = veafGrass._normalizeFarpCoalition(1)
  luaunit.assertEquals(name, "red")
  luaunit.assertEquals(number, 1)
end

function TestVeafGrassFarpCoalition:test_numeric_blue_stays_blue()
  local name, number = veafGrass._normalizeFarpCoalition(2)
  luaunit.assertEquals(name, "blue")
  luaunit.assertEquals(number, 2)
end

function TestVeafGrassFarpCoalition:test_string_red_stays_red()
  -- The regression: this used to come back "blue"/2.
  local name, number = veafGrass._normalizeFarpCoalition("red")
  luaunit.assertEquals(name, "red")
  luaunit.assertEquals(number, 1)
end

function TestVeafGrassFarpCoalition:test_string_blue_stays_blue()
  local name, number = veafGrass._normalizeFarpCoalition("blue")
  luaunit.assertEquals(name, "blue")
  luaunit.assertEquals(number, 2)
end

function TestVeafGrassFarpCoalition:test_unknown_string_defaults_to_blue()
  -- Behaviour preserved: anything that is not "red" was already treated as blue.
  local name, number = veafGrass._normalizeFarpCoalition("purple")
  luaunit.assertEquals(name, "blue")
  luaunit.assertEquals(number, 2)
end


os.exit(luaunit.LuaUnit.run())
