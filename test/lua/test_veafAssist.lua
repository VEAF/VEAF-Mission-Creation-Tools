--- Tests for veafAssist.lua — the guided-checklist engine.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafI18n.lua")
dofile(src .. "/veafRadio.lua")
dofile(src .. "/veafAssist.lua")

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local MAIN_PWR = "PTR-ELEC-TMB-MPWR-510"
local JFS = "PTR-ENGSTART-TMB-JETFUEL-447"

--- A checklist mixing both validation modes, shaped exactly like ticket 02 emits.
--- P1 stands for any live cockpit parameter the aircraft publishes.
local function definition(id)
  return {
    id = id or "test-checklist",
    title = "assist.test.title",
    aircraft = { "F-16C_50" },
    menu = "cold-start",
    images = { "KEY_0", "KEY_1", "KEY_2", "KEY_3" },
    steps = {
      { label = "step.one", element = MAIN_PWR, check = { type = "cockpit_param", param = "P1", min = -0.05, max = 0.05 } },
      { label = "step.two", element = MAIN_PWR, check = { type = "cockpit_param", param = "P1", min = 0.95, max = 1.05 } },
      { label = "step.three", element = JFS, check = { type = "confirm" } },
    },
  }
end

--- The cockpit parameters the fake aircraft currently publishes.
local cockpitParams = {}

--- Stand in for the engine's list_cockpit_params(), same "NAME:value" dump format.
function list_cockpit_params()
  local lines = {}
  for name, value in pairs(cockpitParams) do
    lines[#lines + 1] = name .. ":" .. tostring(value)
  end
  return table.concat(lines, "\n")
end

--- Reset the whole module and the mocks, then register a fresh checklist.
local function setUpEngine(params)
  dcs_mocks.reset()
  veafAssist.checklists = {}
  veafAssist.sessions = {}
  veafAssist.paramCache = nil
  veafAssist.nextHighlightId = veafAssist.FIRST_HIGHLIGHT_ID
  veafAssist.available = veafAssist.nativeFunctionsAvailable()
  veafAssist.registerChecklist(definition())
  cockpitParams = params or { P1 = -1.0 }
  dcs_mocks.addUnit("Pilot #1", { _id = 42 })
end

--- Change a published cockpit parameter and run one evaluation tick.
local function setParamAndTick(_, param, value)
  cockpitParams[param] = value
  veafAssist.loop()
end

local function session(unitName)
  return veafAssist.sessions[unitName]
end

local function highlightedElements()
  local elements = {}
  for _, call in ipairs(dcs_mocks.cockpitCallsTo("a_cockpit_highlight")) do
    table.insert(elements, call.args[2])
  end
  return elements
end

local function displayedResources()
  local resources = {}
  for _, call in ipairs(dcs_mocks.cockpitCallsTo("a_out_picture_u")) do
    table.insert(resources, call.args[2])
  end
  return resources
end

-- ---------------------------------------------------------------------------
-- TestVeafAssistModule
-- ---------------------------------------------------------------------------
TestVeafAssistModule = {}

function TestVeafAssistModule:test_id()
  luaunit.assertEquals(veafAssist.Id, "ASSIST")
end

function TestVeafAssistModule:test_default_checks_are_registered()
  luaunit.assertIsFunction(veafAssist.checks["cockpit_param"])
  luaunit.assertIsFunction(veafAssist.checks["confirm"])
end

function TestVeafAssistModule:test_there_is_no_argument_check()
  -- A cockpit control's position cannot be read from the mission environment, so an
  -- `argument` check would never fire. The format rejects the field; the engine offers
  -- no such check either, so a hand-written checklist cannot resurrect it silently.
  luaunit.assertNil(veafAssist.checks["argument"])
end

function TestVeafAssistModule:test_registerCheck_adds_a_named_check()
  veafAssist.registerCheck("always", function()
    return true
  end)
  luaunit.assertIsFunction(veafAssist.checks["always"])
  veafAssist.checks["always"] = nil
end

function TestVeafAssistModule:test_registerChecklist_indexes_the_steps()
  setUpEngine()
  local checklist = veafAssist.checklists["test-checklist"]
  luaunit.assertEquals(checklist.steps[1].index, 1)
  luaunit.assertEquals(checklist.steps[3].index, 3)
end

function TestVeafAssistModule:test_registerChecklist_without_id_is_inert()
  setUpEngine()
  local before = 0
  for _ in pairs(veafAssist.checklists) do
    before = before + 1
  end
  veafAssist.registerChecklist({ title = "no id" })
  local after = 0
  for _ in pairs(veafAssist.checklists) do
    after = after + 1
  end
  luaunit.assertEquals(after, before)
end

function TestVeafAssistModule:test_checklistsForType()
  setUpEngine()
  luaunit.assertEquals(#veafAssist.checklistsForType("F-16C_50"), 1)
  luaunit.assertEquals(#veafAssist.checklistsForType("A-10C_2"), 0)
end

-- ---------------------------------------------------------------------------
-- TestVeafAssistSessions
-- ---------------------------------------------------------------------------
TestVeafAssistSessions = {}

function TestVeafAssistSessions:test_start_opens_a_session_on_the_first_step()
  setUpEngine()
  luaunit.assertTrue(veafAssist.start("Pilot #1", "test-checklist"))
  luaunit.assertNotNil(session("Pilot #1"))
  luaunit.assertEquals(session("Pilot #1").displayedIndex, 1)
end

function TestVeafAssistSessions:test_unknown_checklist_is_inert()
  setUpEngine()
  luaunit.assertFalse(veafAssist.start("Pilot #1", "no-such-checklist"))
  luaunit.assertNil(session("Pilot #1"))
end

function TestVeafAssistSessions:test_start_boxes_the_first_step_element()
  setUpEngine()
  veafAssist.start("Pilot #1", "test-checklist")
  luaunit.assertEquals(highlightedElements(), { MAIN_PWR })
end

function TestVeafAssistSessions:test_already_satisfied_steps_are_ticked_on_start()
  -- The monitored value already sits in step 1's window: it must not be asked for again.
  setUpEngine({ P1 = 0.0 })
  veafAssist.start("Pilot #1", "test-checklist")
  luaunit.assertTrue(session("Pilot #1").done[1])
  luaunit.assertEquals(session("Pilot #1").displayedIndex, 2)
end

function TestVeafAssistSessions:test_step_advances_only_when_the_parameter_enters_the_window()
  setUpEngine()
  veafAssist.start("Pilot #1", "test-checklist")

  setParamAndTick("Pilot #1", "P1", -0.5)
  luaunit.assertEquals(session("Pilot #1").displayedIndex, 1)

  setParamAndTick("Pilot #1", "P1", 0.0)
  luaunit.assertEquals(session("Pilot #1").displayedIndex, 2)
end

function TestVeafAssistSessions:test_a_passed_step_stays_passed_when_the_value_moves_on()
  -- A monitored value passes through step 1's window on its way to step 2's. Step 1 is
  -- no longer satisfied once it gets there; it must stay ticked rather than strand the
  -- pilot in a loop.
  setUpEngine()
  veafAssist.start("Pilot #1", "test-checklist")
  setParamAndTick("Pilot #1", "P1", 0.0)
  setParamAndTick("Pilot #1", "P1", 1.0)

  luaunit.assertTrue(session("Pilot #1").done[1])
  luaunit.assertTrue(session("Pilot #1").done[2])
  luaunit.assertEquals(session("Pilot #1").displayedIndex, 3)
end

function TestVeafAssistSessions:test_confirm_only_advances_a_confirm_step()
  setUpEngine()
  veafAssist.start("Pilot #1", "test-checklist")

  -- Step 1 is a parameter step: confirming it must not tick it.
  veafAssist.confirmStep("Pilot #1")
  luaunit.assertEquals(session("Pilot #1").displayedIndex, 1)

  setParamAndTick("Pilot #1", "P1", 0.0)
  setParamAndTick("Pilot #1", "P1", 1.0)
  luaunit.assertEquals(session("Pilot #1").displayedIndex, 3)

  veafAssist.confirmStep("Pilot #1")
  luaunit.assertNil(session("Pilot #1"))
end

function TestVeafAssistSessions:test_confirm_without_a_session_is_inert()
  setUpEngine()
  luaunit.assertFalse(veafAssist.confirmStep("Pilot #1"))
end

function TestVeafAssistSessions:test_skip_advances_past_a_step_that_cannot_pass()
  setUpEngine()
  veafAssist.start("Pilot #1", "test-checklist")
  luaunit.assertTrue(veafAssist.skipStep("Pilot #1"))
  luaunit.assertTrue(session("Pilot #1").done[1])
  luaunit.assertEquals(session("Pilot #1").displayedIndex, 2)
end

function TestVeafAssistSessions:test_skipping_every_step_completes_the_checklist()
  setUpEngine()
  veafAssist.start("Pilot #1", "test-checklist")
  veafAssist.skipStep("Pilot #1")
  veafAssist.skipStep("Pilot #1")
  veafAssist.skipStep("Pilot #1")
  luaunit.assertNil(session("Pilot #1"))
end

function TestVeafAssistSessions:test_highlight_is_reissued_only_when_the_boxed_element_changes()
  setUpEngine()
  veafAssist.start("Pilot #1", "test-checklist")
  veafAssist.loop()
  veafAssist.loop()
  luaunit.assertEquals(highlightedElements(), { MAIN_PWR })

  -- Steps 1 and 2 box the same element: advancing must not re-box what is already
  -- boxed — that is a visual flicker for nothing.
  setParamAndTick("Pilot #1", "P1", 0.0)
  veafAssist.loop()
  luaunit.assertEquals(highlightedElements(), { MAIN_PWR })

  -- Step 3 boxes another element: that one is a real target change.
  setParamAndTick("Pilot #1", "P1", 1.0)
  luaunit.assertEquals(highlightedElements(), { MAIN_PWR, JFS })
end

function TestVeafAssistSessions:test_displayed_picture_tracks_the_progress_state()
  setUpEngine()
  veafAssist.start("Pilot #1", "test-checklist")
  setParamAndTick("Pilot #1", "P1", 0.0)
  setParamAndTick("Pilot #1", "P1", 1.0)
  luaunit.assertEquals(displayedResources(), { "KEY_0", "KEY_1", "KEY_2" })
end

function TestVeafAssistSessions:test_picture_is_displayed_with_duration_zero()
  setUpEngine()
  veafAssist.start("Pilot #1", "test-checklist")
  local call = dcs_mocks.cockpitCallsTo("a_out_picture_u")[1]
  luaunit.assertEquals(call.args[1], 42) -- the unit id
  luaunit.assertEquals(call.args[3], 0) -- duration 0: stays until a_out_picture_stop
  luaunit.assertEquals(call.args[4], true) -- clearView
end

function TestVeafAssistSessions:test_completion_clears_the_highlight_and_the_picture()
  setUpEngine()
  veafAssist.start("Pilot #1", "test-checklist")
  veafAssist.skipStep("Pilot #1")
  veafAssist.skipStep("Pilot #1")
  veafAssist.skipStep("Pilot #1")
  -- Every box that was opened has been closed, and the picture is down.
  luaunit.assertEquals(#dcs_mocks.cockpitCallsTo("a_cockpit_remove_highlight"), #dcs_mocks.cockpitCallsTo("a_cockpit_highlight"))
  luaunit.assertEquals(#dcs_mocks.cockpitCallsTo("a_out_picture_stop"), 1)
end

function TestVeafAssistSessions:test_togglePicture_hides_then_shows()
  setUpEngine()
  veafAssist.start("Pilot #1", "test-checklist")
  luaunit.assertFalse(veafAssist.togglePicture("Pilot #1"))
  luaunit.assertEquals(#dcs_mocks.cockpitCallsTo("a_out_picture_stop"), 1)
  luaunit.assertTrue(veafAssist.togglePicture("Pilot #1"))
  luaunit.assertEquals(#dcs_mocks.cockpitCallsTo("a_out_picture_u"), 2)
end

function TestVeafAssistSessions:test_stop_ends_the_session()
  setUpEngine()
  veafAssist.start("Pilot #1", "test-checklist")
  luaunit.assertTrue(veafAssist.stop("Pilot #1"))
  luaunit.assertNil(session("Pilot #1"))
  luaunit.assertFalse(veafAssist.stop("Pilot #1"))
end

function TestVeafAssistSessions:test_a_pilot_leaving_the_slot_drops_the_session_quietly()
  setUpEngine()
  veafAssist.start("Pilot #1", "test-checklist")
  dcs_mocks.removeUnit("Pilot #1")
  veafAssist.loop()
  luaunit.assertNil(session("Pilot #1"))
end

function TestVeafAssistSessions:test_restarting_replaces_the_running_session()
  setUpEngine()
  veafAssist.start("Pilot #1", "test-checklist")
  local firstId = session("Pilot #1").highlightId
  veafAssist.start("Pilot #1", "test-checklist")
  luaunit.assertNotEquals(session("Pilot #1").highlightId, firstId)
  -- The previous highlight was cleared before the new one was issued.
  luaunit.assertEquals(#dcs_mocks.cockpitCallsTo("a_cockpit_remove_highlight"), 1)
end

function TestVeafAssistSessions:test_two_pilots_do_not_share_a_highlight_id()
  setUpEngine()
  dcs_mocks.addUnit("Pilot #2", { _id = 43 })
  veafAssist.start("Pilot #1", "test-checklist")
  veafAssist.start("Pilot #2", "test-checklist")
  luaunit.assertNotEquals(session("Pilot #1").highlightId, session("Pilot #2").highlightId)
end

function TestVeafAssistSessions:test_an_unknown_check_type_never_passes()
  setUpEngine()
  veafAssist.registerChecklist({
    id = "bad-check",
    title = "t",
    aircraft = { "F-16C_50" },
    menu = "m",
    steps = { { label = "l", element = MAIN_PWR, check = { type = "no-such-check" } } },
  })
  veafAssist.start("Pilot #1", "bad-check")
  veafAssist.loop()
  luaunit.assertEquals(session("Pilot #1").displayedIndex, 1)
end

function TestVeafAssistSessions:test_a_missing_parameter_never_passes()
  -- The aircraft publishes no parameter named P1 (wrong module, or a typo).
  setUpEngine({})
  veafAssist.start("Pilot #1", "test-checklist")
  veafAssist.loop()
  luaunit.assertEquals(session("Pilot #1").displayedIndex, 1)
end

function TestVeafAssistSessions:test_a_parameter_name_containing_colons_is_read()
  -- ExternalFM:HumanInfo:AoA and friends: the dump splits on the LAST colon.
  setUpEngine({ ["ExternalFM:HumanInfo:AoA"] = 0.5 })
  veafAssist.registerChecklist({
    id = "colon-param",
    title = "t",
    aircraft = { "F-16C_50" },
    menu = "m",
    steps = {
      { label = "l", element = MAIN_PWR, check = { type = "cockpit_param", param = "ExternalFM:HumanInfo:AoA", min = 0.4, max = 0.6 } },
    },
  })
  veafAssist.start("Pilot #1", "colon-param")
  luaunit.assertNil(session("Pilot #1"))
end

function TestVeafAssistSessions:test_the_parameter_dump_is_read_once_per_tick()
  local calls = 0
  local real = list_cockpit_params
  list_cockpit_params = function()
    calls = calls + 1
    return real()
  end
  setUpEngine()
  veafAssist.start("Pilot #1", "test-checklist")
  calls = 0
  veafAssist.loop()
  list_cockpit_params = real
  -- Three steps in the checklist, one dump.
  luaunit.assertEquals(calls, 1)
end

-- ---------------------------------------------------------------------------
-- TestVeafAssistAvailability
-- ---------------------------------------------------------------------------
TestVeafAssistAvailability = {}

function TestVeafAssistAvailability:test_available_when_the_cockpit_functions_exist()
  luaunit.assertTrue(veafAssist.nativeFunctionsAvailable())
end

function TestVeafAssistAvailability:test_start_refuses_when_the_cockpit_functions_are_missing()
  setUpEngine()
  local saved = a_cockpit_highlight
  a_cockpit_highlight = nil
  veafAssist.available = veafAssist.nativeFunctionsAvailable()
  luaunit.assertFalse(veafAssist.available)
  luaunit.assertFalse(veafAssist.start("Pilot #1", "test-checklist"))
  a_cockpit_highlight = saved
  veafAssist.available = veafAssist.nativeFunctionsAvailable()
end

function TestVeafAssistAvailability:test_initialize_does_not_arm_the_module_without_the_primitives()
  setUpEngine()
  local saved = a_out_picture_u
  a_out_picture_u = nil
  veafAssist.initialized = false
  veafAssist.initialize()
  luaunit.assertFalse(veafAssist.initialized)
  luaunit.assertFalse(veafAssist.available)
  a_out_picture_u = saved
  veafAssist.initialize()
  luaunit.assertTrue(veafAssist.initialized)
end

-- ---------------------------------------------------------------------------
-- TestVeafAssistRadioMenu
-- ---------------------------------------------------------------------------
TestVeafAssistRadioMenu = {}

--- Rebuild the menu from scratch on a clean engine, and return the Assistance node.
local function setUpMenu()
  setUpEngine()
  veafRadio.radioMenu.subMenus = {}
  veafRadio.radioMenu.commands = {}
  veafAssist.rootPath = nil
  veafAssist.buildRadioMenu()
  return veafAssist.rootPath
end

--- Titles of the entries a given pilot would actually see.
local function visibleEntries(unitName)
  local titles = {}
  for _, command in ipairs(veafAssist.rootPath.commands) do
    if not command.groupFilter or command.groupFilter(unitName) then
      table.insert(titles, command.title)
    end
  end
  return titles
end

function TestVeafAssistRadioMenu:test_no_menu_when_the_mission_activates_no_checklist()
  dcs_mocks.reset()
  veafAssist.checklists = {}
  veafAssist.rootPath = nil
  veafAssist.buildRadioMenu()
  luaunit.assertNil(veafAssist.rootPath)
end

function TestVeafAssistRadioMenu:test_the_menu_holds_one_start_entry_plus_the_contextual_ones()
  local root = setUpMenu()
  luaunit.assertNotNil(root)
  luaunit.assertEquals(#root.commands, 5)
end

function TestVeafAssistRadioMenu:test_every_entry_is_per_group()
  local root = setUpMenu()
  for _, command in ipairs(root.commands) do
    luaunit.assertEquals(command.usage, veafRadio.USAGE_ForGroup)
  end
end

function TestVeafAssistRadioMenu:test_an_idle_pilot_of_the_right_type_sees_only_the_start_entry()
  setUpMenu()
  dcs_mocks.addUnit("Pilot #1", {
    _id = 42,
    getTypeName = function()
      return "F-16C_50"
    end,
  })
  luaunit.assertEquals(visibleEntries("Pilot #1"), { veaf.t("assist.menu.cold-start") })
end

function TestVeafAssistRadioMenu:test_a_pilot_of_another_type_sees_nothing()
  setUpMenu()
  dcs_mocks.addUnit("Hog #1", {
    _id = 43,
    getTypeName = function()
      return "A-10C_2"
    end,
  })
  luaunit.assertEquals(visibleEntries("Hog #1"), {})
end

function TestVeafAssistRadioMenu:test_a_session_swaps_the_start_entry_for_the_contextual_ones()
  setUpMenu()
  dcs_mocks.addUnit("Pilot #1", {
    _id = 42,
    getTypeName = function()
      return "F-16C_50"
    end,
  })
  veafAssist.start("Pilot #1", "test-checklist")
  local visible = visibleEntries("Pilot #1")
  table.sort(visible)
  -- Step 1 is an argument step, so "Confirm this step" is not offered yet.
  local expected = { veaf.t("assist.menu.skip"), veaf.t("assist.menu.stop"), veaf.t("assist.menu.toggle_picture") }
  table.sort(expected)
  luaunit.assertEquals(visible, expected)
end

function TestVeafAssistRadioMenu:test_confirm_appears_only_on_a_confirm_step()
  setUpMenu()
  dcs_mocks.addUnit("Pilot #1", {
    _id = 42,
    getTypeName = function()
      return "F-16C_50"
    end,
  })
  veafAssist.start("Pilot #1", "test-checklist")
  luaunit.assertFalse(veafAssist.currentStepNeedsConfirmation("Pilot #1"))

  setParamAndTick("Pilot #1", "P1", 0.0)
  setParamAndTick("Pilot #1", "P1", 1.0)
  -- Step 3 is the confirm one.
  luaunit.assertTrue(veafAssist.currentStepNeedsConfirmation("Pilot #1"))
  local visible = visibleEntries("Pilot #1")
  local found = false
  for _, title in ipairs(visible) do
    if title == veaf.t("assist.menu.confirm") then
      found = true
    end
  end
  luaunit.assertTrue(found)
end

function TestVeafAssistRadioMenu:test_a_pilot_with_no_unit_is_offered_nothing()
  setUpMenu()
  luaunit.assertFalse(veafAssist.canStart("Ghost #1", "test-checklist"))
end

function TestVeafAssistRadioMenu:test_radioStart_unpacks_the_builder_parameters()
  setUpMenu()
  dcs_mocks.addUnit("Pilot #1", {
    _id = 42,
    getTypeName = function()
      return "F-16C_50"
    end,
  })
  veafAssist.radioStart({ "test-checklist", "Pilot #1" })
  luaunit.assertNotNil(veafAssist.sessions["Pilot #1"])
end

os.exit(luaunit.LuaUnit.run())
