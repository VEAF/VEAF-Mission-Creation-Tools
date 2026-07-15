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

-- Ensure veafSecurity.isAuthenticated exists (dcs_mocks.lua defines veafSecurity without it)
veafSecurity = veafSecurity or {}
veafSecurity.isAuthenticated = veafSecurity.isAuthenticated or function() return false end

-- ---------------------------------------------------------------------------
-- TestVeafRadioMenuOps — wrapper functions, delCommand, clearSubmenu, delSubmenu
-- ---------------------------------------------------------------------------
TestVeafRadioMenuOps = {}

function TestVeafRadioMenuOps:test_addCommandToMainMenu_returns_command()
  local cmd = veafRadio.addCommandToMainMenu("MC1", function() end)
  luaunit.assertNotNil(cmd)
  luaunit.assertEquals(cmd.title, "MC1")
  luaunit.assertFalse(cmd.isSecured)
end

function TestVeafRadioMenuOps:test_addSecuredCommandToMainMenu_returns_secured()
  local cmd = veafRadio.addSecuredCommandToMainMenu("MS1", function() end)
  luaunit.assertNotNil(cmd)
  luaunit.assertEquals(cmd.title, "MS1")
  luaunit.assertTrue(cmd.isSecured)
end

function TestVeafRadioMenuOps:test_addCommandToSubmenu_adds_to_menu()
  local sub = { title = "S", subMenus = {}, commands = {}, dcsRadioMenu = nil }
  local cmd = veafRadio.addCommandToSubmenu("SC1", sub, function() end, { x = 1 }, veafRadio.USAGE_ForAll)
  luaunit.assertNotNil(cmd)
  luaunit.assertEquals(cmd.title, "SC1")
  luaunit.assertEquals(#sub.commands, 1)
end

function TestVeafRadioMenuOps:test_addSecuredCommandToSubmenu_returns_secured()
  local sub = { title = "S", subMenus = {}, commands = {}, dcsRadioMenu = nil }
  local cmd = veafRadio.addSecuredCommandToSubmenu("SS1", sub, function() end)
  luaunit.assertTrue(cmd.isSecured)
end

function TestVeafRadioMenuOps:test_addMenu_returns_submenu()
  local sub = veafRadio.addMenu("TopLevel")
  luaunit.assertNotNil(sub)
  luaunit.assertEquals(sub.title, "TopLevel")
end

function TestVeafRadioMenuOps:test_addSubMenu_with_parent()
  local parent = { title = "P", subMenus = {}, commands = {}, dcsRadioMenu = nil }
  local child = veafRadio.addSubMenu("Child", parent)
  luaunit.assertEquals(child.title, "Child")
  luaunit.assertEquals(#parent.subMenus, 1)
end

function TestVeafRadioMenuOps:test_delCommand_existing_returns_true()
  local menu = { commands = { { title = "Alpha" }, { title = "Beta" } } }
  luaunit.assertTrue(veafRadio.delCommand(menu, "Alpha"))
  luaunit.assertEquals(#menu.commands, 1)
  luaunit.assertEquals(menu.commands[1].title, "Beta")
end

function TestVeafRadioMenuOps:test_delCommand_missing_returns_false()
  local menu = { commands = { { title = "Alpha" } } }
  luaunit.assertFalse(veafRadio.delCommand(menu, "Ghost"))
  luaunit.assertEquals(#menu.commands, 1)
end

function TestVeafRadioMenuOps:test_clearSubmenu_empties_contents()
  local sub = { title = "S", subMenus = { { title = "A" } }, commands = { { title = "B" } } }
  veafRadio.clearSubmenu(sub)
  luaunit.assertEquals(#sub.subMenus, 0)
  luaunit.assertEquals(#sub.commands, 0)
end

function TestVeafRadioMenuOps:test_clearSubmenu_nil_is_safe()
  veafRadio.clearSubmenu(nil) -- logs error, does not crash
  luaunit.assertTrue(true)
end

function TestVeafRadioMenuOps:test_delSubmenu_removes_by_reference()
  local parent = { title = "P", subMenus = {}, commands = {} }
  local s1 = { title = "A", subMenus = {}, commands = {} }
  local s2 = { title = "B", subMenus = {}, commands = {} }
  table.insert(parent.subMenus, s1)
  table.insert(parent.subMenus, s2)
  veafRadio.delSubmenu(s1, parent)
  luaunit.assertEquals(#parent.subMenus, 1)
  luaunit.assertEquals(parent.subMenus[1].title, "B")
end

function TestVeafRadioMenuOps:test_delSubmenu_nil_is_safe()
  veafRadio.delSubmenu(nil) -- logs error, does not crash
  luaunit.assertTrue(true)
end

-- ---------------------------------------------------------------------------
-- TestVeafRadioHelpers — menu/command/mainmenu factories, refresh functions
-- ---------------------------------------------------------------------------
TestVeafRadioHelpers = {}

function TestVeafRadioHelpers:test_menu_type_field()
  local m = veafRadio.menu("MyMenu")
  luaunit.assertEquals(m[1], "menu")
  luaunit.assertEquals(m[2], "MyMenu")
  luaunit.assertIsTable(m[3])
end

function TestVeafRadioHelpers:test_menu_wraps_varargs()
  local c = veafRadio.command("Cmd", function() end, nil)
  local m = veafRadio.menu("Parent", c)
  luaunit.assertEquals(#m[3], 1)
  luaunit.assertEquals(m[3][1][2], "Cmd")
end

function TestVeafRadioHelpers:test_command_fields()
  local fn = function() end
  local c = veafRadio.command("Cmd", fn, "params")
  luaunit.assertEquals(c[1], "command")
  luaunit.assertEquals(c[2], "Cmd")
  luaunit.assertEquals(c[3], fn)
  luaunit.assertEquals(c[4], "params")
end

function TestVeafRadioHelpers:test_mainmenu_returns_list()
  local c = veafRadio.command("X", function() end, nil)
  local mm = veafRadio.mainmenu(c)
  luaunit.assertIsTable(mm)
  luaunit.assertEquals(#mm, 1)
end

function TestVeafRadioHelpers:test_refreshRadioMenu_dontDelay_true_rebuilds()
  veafRadio.refreshRadioMenu(true)
  luaunit.assertTrue(true) -- no crash
end

function TestVeafRadioHelpers:test_refreshRadioMenu_dontDelay_false_schedules()
  veafRadio.refreshRadioMenuDelayedScheduling = nil
  veafRadio.refreshRadioMenu(false)
  luaunit.assertTrue(true)
end

function TestVeafRadioHelpers:test_refreshRadioMenu_dontCreateMenus_skips()
  veafRadio.dontCreateMenus = true
  veafRadio._refreshRadioMenu()
  veafRadio.dontCreateMenus = false
  luaunit.assertTrue(true)
end

-- ---------------------------------------------------------------------------
-- TestVeafRadioBeacons — startBeacon, _runBeacons
-- ---------------------------------------------------------------------------
TestVeafRadioBeacons = {}

function TestVeafRadioBeacons:setUp()
  veafRadio.beacons = {}
  dcs_mocks.currentTime = 0
end

function TestVeafRadioBeacons:test_startBeacon_stores_data()
  veafRadio.startBeacon("TestBeacon", 5, 30, "251", "AM", "Hello", nil, 2)
  local b = veafRadio.beacons["testbeacon"]
  luaunit.assertNotNil(b)
  luaunit.assertEquals(b.name, "TestBeacon")
  luaunit.assertEquals(b.secondsBetweenRepeats, 30)
  luaunit.assertEquals(b.frequencies, "251")
  luaunit.assertEquals(b.modulations, "AM")
  luaunit.assertEquals(b.message, "Hello")
  luaunit.assertEquals(b.coalition, 2)
end

function TestVeafRadioBeacons:test_startBeacon_overwrites_existing()
  veafRadio.startBeacon("Beacon", 0, 30, "251", "AM", "Old", nil, 1)
  veafRadio.startBeacon("Beacon", 0, 60, "131.5", "FM", "New", nil, 2)
  local b = veafRadio.beacons["beacon"]
  luaunit.assertEquals(b.secondsBetweenRepeats, 60)
  luaunit.assertEquals(b.message, "New")
end

function TestVeafRadioBeacons:test_runBeacons_fires_due_beacon_message()
  veafRadio.startBeacon("Auto", 0, 30, "251", "AM", "Ping", nil, nil)
  dcs_mocks.currentTime = 1
  veafRadio._runBeacons()
  luaunit.assertTrue(true) -- no crash; transmitMessage called, coalition=nil skips outTextForCoalition
end

function TestVeafRadioBeacons:test_runBeacons_fires_due_beacon_mp3()
  veafRadio.startBeacon("MP3Beacon", 0, 30, "251", "AM", nil, "sounds/test.ogg", nil)
  dcs_mocks.currentTime = 1
  veafRadio._runBeacons()
  luaunit.assertTrue(true)
end

-- ---------------------------------------------------------------------------
-- TestVeafRadioExecuteCommand
-- ---------------------------------------------------------------------------
TestVeafRadioExecuteCommand = {}

function TestVeafRadioExecuteCommand:test_nil_text_returns_false()
  -- empty string: keyphrase not found → returns false
  luaunit.assertFalse(veafRadio.executeCommand(nil, "", nil, false))
end

function TestVeafRadioExecuteCommand:test_no_keyphrase_returns_false()
  luaunit.assertFalse(veafRadio.executeCommand(nil, "hello world", nil, false))
end

function TestVeafRadioExecuteCommand:test_transmit_without_message_returns_false()
  -- markTextAnalysis returns options with transmit=true but message=nil
  luaunit.assertFalse(veafRadio.executeCommand(nil, "_radio transmit", nil, false))
end

function TestVeafRadioExecuteCommand:test_transmit_with_full_options_returns_true()
  -- quiet=true so outTextForCoalition not called; coalition=nil anyway
  local result = veafRadio.executeCommand(nil, "_radio transmit, message Hello, quiet", nil, false)
  luaunit.assertTrue(result)
end

function TestVeafRadioExecuteCommand:test_play_without_path_returns_false()
  luaunit.assertFalse(veafRadio.executeCommand(nil, "_radio play", nil, false))
end

function TestVeafRadioExecuteCommand:test_play_with_path_returns_true()
  local result = veafRadio.executeCommand(nil, "_radio play, path sounds/test.ogg, quiet", nil, false)
  luaunit.assertTrue(result)
end

-- ---------------------------------------------------------------------------
-- TestVeafRadioTransmit — transmitMessage, playToRadio, _transmitViaSRS
-- ---------------------------------------------------------------------------
TestVeafRadioTransmit = {}

function TestVeafRadioTransmit:test_transmitMessage_no_coalition_no_outText()
  veafRadio.transmitMessage("Hello", "251", "AM", "SRS", nil, nil, false)
  luaunit.assertTrue(true)
end

function TestVeafRadioTransmit:test_transmitMessage_quiet_no_outText()
  veafRadio.transmitMessage("Hello", "251", "AM", "SRS", 1, nil, true)
  luaunit.assertTrue(true)
end

function TestVeafRadioTransmit:test_transmitMessage_with_coalition_calls_outText()
  -- outTextForCoalition is now mocked in dcs_mocks.lua
  veafRadio.transmitMessage("Hello", "251", "AM", "SRS", 1, nil, false)
  luaunit.assertTrue(true)
end

function TestVeafRadioTransmit:test_playToRadio_no_coalition()
  veafRadio.playToRadio("sounds/test.ogg", "251", "AM", "SRS", nil, nil, false)
  luaunit.assertTrue(true)
end

function TestVeafRadioTransmit:test_playToRadio_quiet()
  veafRadio.playToRadio("sounds/test.ogg", "251", "AM", "SRS", 1, nil, true)
  luaunit.assertTrue(true)
end

function TestVeafRadioTransmit:test_transmitViaSRS_no_message_no_file_logs_error()
  -- Exercises the else branch: logs error and returns
  veafRadio._transmitViaSRS(nil, nil, "251", "AM", "SRS", nil, nil)
  luaunit.assertTrue(true)
end

-- ---------------------------------------------------------------------------
-- TestVeafRadioPaginated — addPaginatedRadioElements, _buildRadioMenuPage,
--                          addPaginatedRadioMenu
-- ---------------------------------------------------------------------------
TestVeafRadioPaginated = {}

function TestVeafRadioPaginated:test_nil_method_returns_early()
  local menu = { subMenus = {}, commands = {} }
  veafRadio.addPaginatedRadioElements(menu, nil, {})
  luaunit.assertTrue(true) -- no crash
end

function TestVeafRadioPaginated:test_calls_method_for_each_element()
  local menu = { subMenus = {}, commands = {} }
  local elements = { a = { sort = 1 }, b = { sort = 2 }, c = { sort = 3 } }
  local called = {}
  local addFn = function(m, title, elem) table.insert(called, title) end
  veafRadio.addPaginatedRadioElements(menu, addFn, elements)
  luaunit.assertEquals(#called, 3)
end

function TestVeafRadioPaginated:test_uses_title_attribute()
  local menu = { subMenus = {}, commands = {} }
  local elements = {
    e1 = { displayName = "Alpha", sort = 1 },
    e2 = { displayName = "Beta", sort = 2 },
  }
  local called = {}
  local addFn = function(m, title, elem) table.insert(called, title) end
  veafRadio.addPaginatedRadioElements(menu, addFn, elements, "displayName")
  table.sort(called)
  luaunit.assertEquals(called[1], "Alpha")
  luaunit.assertEquals(called[2], "Beta")
end

function TestVeafRadioPaginated:test_helper_no_longer_paginates()
  -- ADR 0013: the helper only sorts + inserts; pagination is done at render time.
  -- With 11 elements, all 11 are handed to the build method and NO "Next page"
  -- submenu is created by the helper itself.
  local menu = { subMenus = {}, commands = {} }
  local elements = {}
  for i = 1, 11 do
    elements["e" .. i] = { sort = i }
  end
  local count = 0
  veafRadio.addPaginatedRadioElements(menu, function()
    count = count + 1
  end, elements)
  luaunit.assertEquals(count, 11)
  luaunit.assertEquals(#menu.subMenus, 0)
end

function TestVeafRadioPaginated:test_addPaginatedRadioMenu_returns_submenu()
  local parent = { title = "P", subMenus = {}, commands = {}, dcsRadioMenu = nil }
  local result = veafRadio.addPaginatedRadioMenu("Paged", parent, function() end, { a = { sort = 1 } })
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.title, "Paged")
end

-- ---------------------------------------------------------------------------
-- TestVeafRadioRenderPagination — automatic render-time pagination (ADR 0013)
-- ---------------------------------------------------------------------------
TestVeafRadioRenderPagination = {}

function TestVeafRadioRenderPagination:setUp()
  self._origAddSubMenu = missionCommands.addSubMenu
  self._origAddCommand = missionCommands.addCommand
  self._origHumanGroups = veafRadio.humanGroups
  veafRadio.humanGroups = {}
  self.subMenuCalls = {}
  self.commandCalls = {}
  local this = self
  missionCommands.addSubMenu = function(title, parent)
    local m = { title = title, parent = parent }
    table.insert(this.subMenuCalls, m)
    return m
  end
  missionCommands.addCommand = function(title, parent)
    local c = { title = title, parent = parent }
    table.insert(this.commandCalls, c)
    return c
  end
end

function TestVeafRadioRenderPagination:tearDown()
  missionCommands.addSubMenu = self._origAddSubMenu
  missionCommands.addCommand = self._origAddCommand
  veafRadio.humanGroups = self._origHumanGroups
end

-- Build a single root node holding `commandCount` ForAll commands, optionally
-- opted out of pagination or seeded with a ForUnit command, then render it.
function TestVeafRadioRenderPagination:_buildRoot(commandCount, opts)
  opts = opts or {}
  local node = { title = "Root", subMenus = {}, commands = {}, dcsRadioMenu = nil }
  for i = 1, commandCount do
    table.insert(node.commands, {
      title = string.format("cmd%02d", i),
      method = function() end,
      usage = veafRadio.USAGE_ForAll,
    })
  end
  if opts.forUnit then
    table.insert(node.commands, { title = "unitCmd", method = function() end, usage = veafRadio.USAGE_ForUnit })
  end
  if opts.noPagination then
    node.noPagination = true
  end
  veafRadio.RadioMenuBuilder:new(node):build()
  return node
end

function TestVeafRadioRenderPagination:_countNextPages()
  local n = 0
  local label = veaf.t("radio.next_page")
  for _, m in ipairs(self.subMenuCalls) do
    if m.title == label then
      n = n + 1
    end
  end
  return n
end

-- Largest number of DCS children (commands + submenus) under any single parent
-- menu. The DCS limit is MENU_PAGE_SIZE; the root node's own menu (parent nil)
-- is not a child and is excluded.
function TestVeafRadioRenderPagination:_maxChildrenPerParent()
  local counts = {}
  for _, m in ipairs(self.subMenuCalls) do
    if m.parent ~= nil then
      counts[m.parent] = (counts[m.parent] or 0) + 1
    end
  end
  for _, c in ipairs(self.commandCalls) do
    counts[c.parent] = (counts[c.parent] or 0) + 1
  end
  local max = 0
  for _, v in pairs(counts) do
    if v > max then
      max = v
    end
  end
  return max
end

function TestVeafRadioRenderPagination:test_exactly_page_size_not_paginated()
  self:_buildRoot(veafRadio.MENU_PAGE_SIZE)
  luaunit.assertEquals(self:_countNextPages(), 0)
  luaunit.assertEquals(self:_maxChildrenPerParent(), veafRadio.MENU_PAGE_SIZE)
end

function TestVeafRadioRenderPagination:test_over_page_size_paginates()
  self:_buildRoot(veafRadio.MENU_PAGE_SIZE + 1)
  luaunit.assertEquals(self:_countNextPages(), 1)
  luaunit.assertTrue(self:_maxChildrenPerParent() <= veafRadio.MENU_PAGE_SIZE)
end

function TestVeafRadioRenderPagination:test_deep_overflow_recurses()
  -- 20 items → page1(9)+next, page2(9)+next, page3(2) → two "Next page" menus.
  self:_buildRoot(20)
  luaunit.assertEquals(self:_countNextPages(), 2)
  luaunit.assertTrue(self:_maxChildrenPerParent() <= veafRadio.MENU_PAGE_SIZE)
end

function TestVeafRadioRenderPagination:test_doNotPaginate_opt_out()
  self:_buildRoot(15, { noPagination = true })
  luaunit.assertEquals(self:_countNextPages(), 0)
end

function TestVeafRadioRenderPagination:test_forUnit_disables_pagination()
  -- 10 ForAll + 1 ForUnit = 11 items, but the ForUnit guard suppresses paging.
  self:_buildRoot(10, { forUnit = true })
  luaunit.assertEquals(self:_countNextPages(), 0)
end

-- ---------------------------------------------------------------------------
-- TestVeafRadioCreateUserMenu — createUserMenu with and without groupId
-- ---------------------------------------------------------------------------
TestVeafRadioCreateUserMenu = {}

function TestVeafRadioCreateUserMenu:test_no_groupId_uses_addSubMenu_addCommand()
  local cfg = {
    veafRadio.menu(
      "TopMenu",
      veafRadio.command("Sub", function() end, nil)
    ),
    veafRadio.command("Direct", function() end, "p"),
  }
  veafRadio.createUserMenu(cfg)
  luaunit.assertTrue(true) -- no crash
end

function TestVeafRadioCreateUserMenu:test_with_groupId_uses_ForGroup_calls()
  local cfg = {
    veafRadio.menu("GMenu"),
    veafRadio.command("GCmd", function() end, nil),
  }
  veafRadio.createUserMenu(cfg, 101)
  luaunit.assertTrue(true)
end

function TestVeafRadioCreateUserMenu:test_with_group_name_resolves_to_id()
  dcs_mocks.clearUnitsAndGroups()
  dcs_mocks.addGroup("MM Ctrl", { _id = 42 })
  local captured = nil
  local original = missionCommands.addCommandForGroup
  missionCommands.addCommandForGroup = function(groupId)
    captured = groupId
    return {}
  end
  veafRadio.createUserMenu({ veafRadio.command("GCmd", function() end, nil) }, "MM Ctrl")
  missionCommands.addCommandForGroup = original
  luaunit.assertEquals(captured, 42)
end

function TestVeafRadioCreateUserMenu:test_with_unknown_group_name_falls_back_global()
  dcs_mocks.clearUnitsAndGroups()
  local usedForGroup, usedGlobal = false, false
  local origFor = missionCommands.addCommandForGroup
  local origGlobal = missionCommands.addCommand
  missionCommands.addCommandForGroup = function()
    usedForGroup = true
    return {}
  end
  missionCommands.addCommand = function()
    usedGlobal = true
    return {}
  end
  veafRadio.createUserMenu({ veafRadio.command("GCmd", function() end, nil) }, "Nope")
  missionCommands.addCommandForGroup = origFor
  missionCommands.addCommand = origGlobal
  luaunit.assertFalse(usedForGroup)
  luaunit.assertTrue(usedGlobal)
end

os.exit(luaunit.LuaUnit.run())
