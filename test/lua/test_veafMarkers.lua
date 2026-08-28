--- Tests for veafMarkers.lua — event handler registration and constants.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafMarkers.lua")

-- Reset handler state between tests
local function resetHandlers()
  veafMarkers.onEventMarkAddEventHandlers = {}
  veafMarkers.onEventMarkChangeEventHandlers = {}
  veafMarkers.onEventMarkRemoveEventHandlers = {}
  veafMarkers.eventHandlerId = 0
end

-- ---------------------------------------------------------------------------
-- TestVeafMarkersConstants
-- ---------------------------------------------------------------------------
TestVeafMarkersConstants = {}

function TestVeafMarkersConstants:test_markerAdd()
  luaunit.assertEquals(veafMarkers.MarkerAdd, 1)
end

function TestVeafMarkersConstants:test_markerChange()
  luaunit.assertEquals(veafMarkers.MarkerChange, 2)
end

function TestVeafMarkersConstants:test_markerRemove()
  luaunit.assertEquals(veafMarkers.MarkerRemove, 3)
end

function TestVeafMarkersConstants:test_id()
  luaunit.assertIsString(veafMarkers.Id)
end

function TestVeafMarkersConstants:test_eventHandlerId_is_number()
  luaunit.assertIsNumber(veafMarkers.eventHandlerId)
end

function TestVeafMarkersConstants:test_handler_lists_exist()
  luaunit.assertIsTable(veafMarkers.onEventMarkAddEventHandlers)
  luaunit.assertIsTable(veafMarkers.onEventMarkChangeEventHandlers)
  luaunit.assertIsTable(veafMarkers.onEventMarkRemoveEventHandlers)
end

-- ---------------------------------------------------------------------------
-- TestVeafMarkersRegister
-- ---------------------------------------------------------------------------
TestVeafMarkersRegister = {}

function TestVeafMarkersRegister:setUp()
  resetHandlers()
end

function TestVeafMarkersRegister:test_register_add_returns_id()
  local id = veafMarkers.registerEventHandler(veafMarkers.MarkerAdd, function() end)
  luaunit.assertNotNil(id)
  luaunit.assertIsNumber(id)
end

function TestVeafMarkersRegister:test_register_increments_eventHandlerId()
  luaunit.assertEquals(veafMarkers.eventHandlerId, 0)
  veafMarkers.registerEventHandler(veafMarkers.MarkerAdd, function() end)
  luaunit.assertEquals(veafMarkers.eventHandlerId, 1)
end

function TestVeafMarkersRegister:test_register_id_sequential()
  local id1 = veafMarkers.registerEventHandler(veafMarkers.MarkerAdd, function() end)
  local id2 = veafMarkers.registerEventHandler(veafMarkers.MarkerAdd, function() end)
  luaunit.assertEquals(id2, id1 + 1)
end

function TestVeafMarkersRegister:test_register_add_grows_list()
  luaunit.assertEquals(#veafMarkers.onEventMarkAddEventHandlers, 0)
  veafMarkers.registerEventHandler(veafMarkers.MarkerAdd, function() end)
  luaunit.assertEquals(#veafMarkers.onEventMarkAddEventHandlers, 1)
  veafMarkers.registerEventHandler(veafMarkers.MarkerAdd, function() end)
  luaunit.assertEquals(#veafMarkers.onEventMarkAddEventHandlers, 2)
end

function TestVeafMarkersRegister:test_register_change_grows_list()
  luaunit.assertEquals(#veafMarkers.onEventMarkChangeEventHandlers, 0)
  veafMarkers.registerEventHandler(veafMarkers.MarkerChange, function() end)
  luaunit.assertEquals(#veafMarkers.onEventMarkChangeEventHandlers, 1)
end

function TestVeafMarkersRegister:test_register_remove_grows_list()
  luaunit.assertEquals(#veafMarkers.onEventMarkRemoveEventHandlers, 0)
  veafMarkers.registerEventHandler(veafMarkers.MarkerRemove, function() end)
  luaunit.assertEquals(#veafMarkers.onEventMarkRemoveEventHandlers, 1)
end

function TestVeafMarkersRegister:test_register_different_types_independent()
  veafMarkers.registerEventHandler(veafMarkers.MarkerAdd, function() end)
  veafMarkers.registerEventHandler(veafMarkers.MarkerChange, function() end)
  veafMarkers.registerEventHandler(veafMarkers.MarkerRemove, function() end)
  luaunit.assertEquals(#veafMarkers.onEventMarkAddEventHandlers, 1)
  luaunit.assertEquals(#veafMarkers.onEventMarkChangeEventHandlers, 1)
  luaunit.assertEquals(#veafMarkers.onEventMarkRemoveEventHandlers, 1)
end

-- ---------------------------------------------------------------------------
-- TestVeafMarkersUnregister
-- ---------------------------------------------------------------------------
TestVeafMarkersUnregister = {}

function TestVeafMarkersUnregister:setUp()
  resetHandlers()
end

function TestVeafMarkersUnregister:test_unregister_removes_from_add_list()
  local id = veafMarkers.registerEventHandler(veafMarkers.MarkerAdd, function() end)
  luaunit.assertEquals(#veafMarkers.onEventMarkAddEventHandlers, 1)
  veafMarkers.unregisterEventHandler(id)
  luaunit.assertEquals(#veafMarkers.onEventMarkAddEventHandlers, 0)
end

function TestVeafMarkersUnregister:test_unregister_one_of_two()
  local id1 = veafMarkers.registerEventHandler(veafMarkers.MarkerAdd, function() end)
  veafMarkers.registerEventHandler(veafMarkers.MarkerAdd, function() end)
  luaunit.assertEquals(#veafMarkers.onEventMarkAddEventHandlers, 2)
  veafMarkers.unregisterEventHandler(id1)
  luaunit.assertEquals(#veafMarkers.onEventMarkAddEventHandlers, 1)
end

function TestVeafMarkersUnregister:test_unregister_unknown_id_safe()
  veafMarkers.registerEventHandler(veafMarkers.MarkerAdd, function() end)
  -- Should not throw an error
  local ok = pcall(function()
    veafMarkers.unregisterEventHandler(9999)
  end)
  luaunit.assertTrue(ok)
  luaunit.assertEquals(#veafMarkers.onEventMarkAddEventHandlers, 1)
end

-- ---------------------------------------------------------------------------
-- TestVeafMarkersOnEvent (UXPILOT-001: surface handler failures to the pilot)
-- ---------------------------------------------------------------------------
TestVeafMarkersOnEvent = {}

function TestVeafMarkersOnEvent:test_handler_error_reports_to_pilot()
  resetHandlers()
  local captured = nil
  local orig = trigger.action.outTextForCoalition
  trigger.action.outTextForCoalition = function(side, text, duration)
    captured = { side = side, text = text }
  end
  local handlers = { {
    f = function()
      error("boom")
    end,
    id = 1,
  } }
  veafMarkers.onEvent({ text = "_spawn x", pos = { x = 0, y = 0, z = 0 }, coalition = 2 }, handlers)
  trigger.action.outTextForCoalition = orig
  luaunit.assertNotNil(captured)
  luaunit.assertEquals(captured.side, 2)
end

function TestVeafMarkersOnEvent:test_handler_success_does_not_report()
  resetHandlers()
  local called = false
  local orig = trigger.action.outTextForCoalition
  trigger.action.outTextForCoalition = function()
    called = true
  end
  local handlers = { { f = function() end, id = 1 } }
  veafMarkers.onEvent({ text = "_spawn x", pos = { x = 0, y = 0, z = 0 }, coalition = 2 }, handlers)
  trigger.action.outTextForCoalition = orig
  luaunit.assertFalse(called)
end

os.exit(luaunit.LuaUnit.run())
