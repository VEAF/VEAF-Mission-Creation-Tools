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

-- ---------------------------------------------------------------------------
-- TestVeafRadioBuilder
-- ---------------------------------------------------------------------------
TestVeafRadioBuilder = {}

function TestVeafRadioBuilder:setUp()
  local root = { title = "TestRoot", dcsRadioMenu = nil, subMenus = {}, commands = {} }
  self.builder = veafRadio.RadioMenuBuilder:new(root)
end

function TestVeafRadioBuilder:test_new_creates_builder_with_root()
  luaunit.assertNotNil(self.builder)
  luaunit.assertNotNil(self.builder._root)
  luaunit.assertEquals(self.builder._root.title, "TestRoot")
end

function TestVeafRadioBuilder:test_addMenu_adds_to_root()
  local sub = self.builder:addMenu("MySub")
  luaunit.assertNotNil(sub)
  luaunit.assertEquals(sub.title, "MySub")
  luaunit.assertEquals(#self.builder._root.subMenus, 1)
  luaunit.assertEquals(self.builder._root.subMenus[1].title, "MySub")
end

function TestVeafRadioBuilder:test_addMenu_nil_parent_uses_root()
  local sub = self.builder:addMenu("MySub", nil)
  luaunit.assertEquals(self.builder._root.subMenus[1].title, "MySub")
end

function TestVeafRadioBuilder:test_addMenu_with_explicit_parent()
  local parent = self.builder:addMenu("Parent")
  local child = self.builder:addMenu("Child", parent)
  luaunit.assertEquals(#parent.subMenus, 1)
  luaunit.assertEquals(parent.subMenus[1].title, "Child")
end

function TestVeafRadioBuilder:test_addMenu_returns_node_with_empty_children()
  local sub = self.builder:addMenu("Sub")
  luaunit.assertEquals(#sub.subMenus, 0)
  luaunit.assertEquals(#sub.commands, 0)
  luaunit.assertNil(sub.dcsRadioMenu)
end

function TestVeafRadioBuilder:test_addCommand_adds_to_root()
  local cmd = self.builder:addCommand("Fire", nil, function() end, nil, veafRadio.USAGE_ForAll, false)
  luaunit.assertNotNil(cmd)
  luaunit.assertEquals(cmd.title, "Fire")
  luaunit.assertEquals(#self.builder._root.commands, 1)
end

function TestVeafRadioBuilder:test_addCommand_to_submenu()
  local sub = self.builder:addMenu("Sub")
  self.builder:addCommand("Fire", sub, function() end, nil, veafRadio.USAGE_ForAll, false)
  luaunit.assertEquals(#sub.commands, 1)
  luaunit.assertEquals(sub.commands[1].title, "Fire")
  luaunit.assertEquals(#self.builder._root.commands, 0)
end

function TestVeafRadioBuilder:test_addCommand_defaults_usage_ForAll()
  local cmd = self.builder:addCommand("Fire", nil, function() end, nil, nil, false)
  luaunit.assertEquals(cmd.usage, veafRadio.USAGE_ForAll)
end

function TestVeafRadioBuilder:test_addCommand_defaults_isSecured_false()
  local cmd = self.builder:addCommand("Fire", nil, function() end)
  luaunit.assertFalse(cmd.isSecured)
end

function TestVeafRadioBuilder:test_addCommand_stores_parameters()
  local params = { x = 1, y = 2 }
  local cmd = self.builder:addCommand("Move", nil, function() end, params)
  luaunit.assertEquals(cmd.parameters, params)
end

function TestVeafRadioBuilder:test_build_sets_dcs_handle_on_root()
  self.builder:build()
  luaunit.assertNotNil(self.builder._root.dcsRadioMenu)
end

function TestVeafRadioBuilder:test_build_sets_dcs_handle_on_submenus()
  self.builder:addMenu("A")
  self.builder:addMenu("B")
  self.builder:build()
  luaunit.assertNotNil(self.builder._root.subMenus[1].dcsRadioMenu)
  luaunit.assertNotNil(self.builder._root.subMenus[2].dcsRadioMenu)
end

function TestVeafRadioBuilder:test_rebuild_restores_dcs_handle()
  self.builder:build()
  self.builder:rebuild()
  luaunit.assertNotNil(self.builder._root.dcsRadioMenu)
end

function TestVeafRadioBuilder:test_build_sorts_submenus_alphabetically()
  self.builder:addMenu("Zulu")
  self.builder:addMenu("Alpha")
  self.builder:addMenu("Mike")
  self.builder:build()
  luaunit.assertEquals(self.builder._root.subMenus[1].title, "Alpha")
  luaunit.assertEquals(self.builder._root.subMenus[2].title, "Mike")
  luaunit.assertEquals(self.builder._root.subMenus[3].title, "Zulu")
end

function TestVeafRadioBuilder:test_build_sorts_commands_alphabetically()
  self.builder:addCommand("Zulu", nil, function() end)
  self.builder:addCommand("Alpha", nil, function() end)
  self.builder:build()
  luaunit.assertEquals(self.builder._root.commands[1].title, "Alpha")
  luaunit.assertEquals(self.builder._root.commands[2].title, "Zulu")
end

os.exit(luaunit.LuaUnit.run())
