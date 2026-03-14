--- Tests for veafRadio.lua — markTextAnalysis and module constants.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafRadio.lua")

-- ---------------------------------------------------------------------------
-- TestVeafRadioConstants
-- ---------------------------------------------------------------------------
TestVeafRadioConstants = {}

function TestVeafRadioConstants:test_id()
  luaunit.assertEquals(veafRadio.Id, "RADIO")
end

function TestVeafRadioConstants:test_version()
  luaunit.assertIsString(veafRadio.Version)
end

function TestVeafRadioConstants:test_usage_for_all()
  luaunit.assertEquals(veafRadio.USAGE_ForAll, 0)
end

function TestVeafRadioConstants:test_usage_for_group()
  luaunit.assertEquals(veafRadio.USAGE_ForGroup, 1)
end

function TestVeafRadioConstants:test_usage_for_unit()
  luaunit.assertEquals(veafRadio.USAGE_ForUnit, 2)
end

function TestVeafRadioConstants:test_keyphrase_exists()
  luaunit.assertIsString(veafRadio.Keyphrase)
end

-- ---------------------------------------------------------------------------
-- TestVeafRadioMarkTextAnalysis
-- ---------------------------------------------------------------------------
TestVeafRadioMarkTextAnalysis = {}

function TestVeafRadioMarkTextAnalysis:test_unrelated_text_returns_nil()
  luaunit.assertNil(veafRadio.markTextAnalysis("hello world"))
end

function TestVeafRadioMarkTextAnalysis:test_empty_string_returns_nil()
  luaunit.assertNil(veafRadio.markTextAnalysis(""))
end

function TestVeafRadioMarkTextAnalysis:test_transmit_detected()
  local r = veafRadio.markTextAnalysis("_radio transmit")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.transmit)
  luaunit.assertFalse(r.playmp3)
end

function TestVeafRadioMarkTextAnalysis:test_play_detected()
  local r = veafRadio.markTextAnalysis("_radio play")
  luaunit.assertNotNil(r)
  luaunit.assertTrue(r.playmp3)
  luaunit.assertFalse(r.transmit)
end

function TestVeafRadioMarkTextAnalysis:test_default_frequencies()
  local r = veafRadio.markTextAnalysis("_radio transmit")
  luaunit.assertEquals(r.frequencies, "251")
end

function TestVeafRadioMarkTextAnalysis:test_default_modulations()
  local r = veafRadio.markTextAnalysis("_radio transmit")
  luaunit.assertEquals(r.modulations, "AM")
end

function TestVeafRadioMarkTextAnalysis:test_default_name()
  local r = veafRadio.markTextAnalysis("_radio transmit")
  luaunit.assertEquals(r.name, "SRS")
end

function TestVeafRadioMarkTextAnalysis:test_default_quiet_false()
  local r = veafRadio.markTextAnalysis("_radio transmit")
  luaunit.assertFalse(r.quiet)
end

function TestVeafRadioMarkTextAnalysis:test_quiet_keyword()
  local r = veafRadio.markTextAnalysis("_radio transmit, quiet")
  luaunit.assertTrue(r.quiet)
end

function TestVeafRadioMarkTextAnalysis:test_freq_keyword()
  local r = veafRadio.markTextAnalysis("_radio transmit, freq 131.5")
  luaunit.assertEquals(r.frequencies, "131.5")
end

function TestVeafRadioMarkTextAnalysis:test_frequency_keyword()
  local r = veafRadio.markTextAnalysis("_radio transmit, frequency 243.0")
  luaunit.assertEquals(r.frequencies, "243.0")
end

function TestVeafRadioMarkTextAnalysis:test_freqs_keyword()
  local r = veafRadio.markTextAnalysis("_radio transmit, freqs 243")
  luaunit.assertEquals(r.frequencies, "243")
end

function TestVeafRadioMarkTextAnalysis:test_mod_fm()
  local r = veafRadio.markTextAnalysis("_radio transmit, mod FM")
  luaunit.assertEquals(r.modulations, "FM")
end

function TestVeafRadioMarkTextAnalysis:test_modulation_keyword()
  local r = veafRadio.markTextAnalysis("_radio transmit, modulation FM")
  luaunit.assertEquals(r.modulations, "FM")
end

function TestVeafRadioMarkTextAnalysis:test_name_keyword()
  local r = veafRadio.markTextAnalysis("_radio transmit, name myRadio")
  luaunit.assertEquals(r.name, "myRadio")
end

function TestVeafRadioMarkTextAnalysis:test_message_keyword_with_comma()
  local r = veafRadio.markTextAnalysis("_radio transmit, message Hello everyone")
  luaunit.assertEquals(r.message, "Hello everyone")
end

function TestVeafRadioMarkTextAnalysis:test_multiple_keywords()
  local r = veafRadio.markTextAnalysis("_radio transmit, freq 131.5, mod FM, name mynet, quiet")
  luaunit.assertEquals(r.frequencies, "131.5")
  luaunit.assertEquals(r.modulations, "FM")
  luaunit.assertEquals(r.name, "mynet")
  luaunit.assertTrue(r.quiet)
  luaunit.assertTrue(r.transmit)
end

function TestVeafRadioMarkTextAnalysis:test_path_for_play()
  local r = veafRadio.markTextAnalysis("_radio play, path sounds/msg.ogg")
  luaunit.assertTrue(r.playmp3)
  luaunit.assertEquals(r.path, "sounds/msg.ogg")
end

os.exit(luaunit.LuaUnit.run())
