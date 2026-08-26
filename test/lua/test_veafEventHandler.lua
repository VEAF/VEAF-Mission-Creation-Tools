--- Tests for veafEventHandler.lua — event registration and EVENTS table structure.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafEventHandler.lua")

-- ---------------------------------------------------------------------------
-- TestVeafEventHandlerConstants
-- ---------------------------------------------------------------------------
TestVeafEventHandlerConstants = {}

function TestVeafEventHandlerConstants:test_id()
  luaunit.assertIsString(veafEventHandler.Id)
end

function TestVeafEventHandlerConstants:test_events_table_exists()
  luaunit.assertIsTable(veafEventHandler.EVENTS)
end

function TestVeafEventHandlerConstants:test_callbacks_table_exists()
  luaunit.assertIsTable(veafEventHandler.callbacks)
end

function TestVeafEventHandlerConstants:test_events_is_not_empty()
  local count = 0
  for _ in pairs(veafEventHandler.EVENTS) do
    count = count + 1
  end
  luaunit.assertTrue(count > 0)
end

-- ---------------------------------------------------------------------------
-- TestVeafEventHandlerEventsStructure
-- ---------------------------------------------------------------------------
TestVeafEventHandlerEventsStructure = {}

function TestVeafEventHandlerEventsStructure:test_event_entries_have_id()
  for _, v in pairs(veafEventHandler.EVENTS) do
    luaunit.assertIsNumber(v.id)
  end
end

function TestVeafEventHandlerEventsStructure:test_event_entries_have_name()
  for _, v in pairs(veafEventHandler.EVENTS) do
    luaunit.assertIsString(v.name)
    luaunit.assertTrue(#v.name > 0)
  end
end

function TestVeafEventHandlerEventsStructure:test_event_entries_have_enabled()
  for _, v in pairs(veafEventHandler.EVENTS) do
    luaunit.assertIsBoolean(v.enabled)
  end
end

function TestVeafEventHandlerEventsStructure:test_s_event_invalid_exists()
  local found = false
  for _, v in pairs(veafEventHandler.EVENTS) do
    if v.name == "S_EVENT_INVALID" then
      found = true
    end
  end
  luaunit.assertTrue(found)
end

function TestVeafEventHandlerEventsStructure:test_s_event_shot_exists()
  local found = false
  for _, v in pairs(veafEventHandler.EVENTS) do
    if v.name == "S_EVENT_SHOT" then
      found = true
    end
  end
  luaunit.assertTrue(found)
end

function TestVeafEventHandlerEventsStructure:test_s_event_birth_exists()
  local found = false
  for _, v in pairs(veafEventHandler.EVENTS) do
    if v.name == "S_EVENT_BIRTH" then
      found = true
    end
  end
  luaunit.assertTrue(found)
end

function TestVeafEventHandlerEventsStructure:test_s_event_dead_exists()
  local found = false
  for _, v in pairs(veafEventHandler.EVENTS) do
    if v.name == "S_EVENT_DEAD" then
      found = true
    end
  end
  luaunit.assertTrue(found)
end

-- ---------------------------------------------------------------------------
-- TestVeafEventHandlerAddCallback
-- ---------------------------------------------------------------------------
TestVeafEventHandlerAddCallback = {}

function TestVeafEventHandlerAddCallback:setUp()
  veafEventHandler.callbacks = {}
end

-- S_EVENT_SHOT = id 1; S_EVENT_BIRTH = id 15
local SHOT_ID = 1
local BIRTH_ID = 15

function TestVeafEventHandlerAddCallback:test_valid_callback_returns_true()
  local ok = veafEventHandler.addCallback("myCb", { SHOT_ID }, function() end)
  luaunit.assertTrue(ok)
end

function TestVeafEventHandlerAddCallback:test_nil_name_returns_false()
  local ok = veafEventHandler.addCallback(nil, { SHOT_ID }, function() end)
  luaunit.assertFalse(ok)
end

function TestVeafEventHandlerAddCallback:test_nil_callback_returns_false()
  local ok = veafEventHandler.addCallback("noFn", { SHOT_ID }, nil)
  luaunit.assertFalse(ok)
end

function TestVeafEventHandlerAddCallback:test_empty_name_is_accepted_or_rejected()
  -- empty string name: implementation may accept or reject;
  -- just verify it doesn't error out
  local ok = pcall(function()
    veafEventHandler.addCallback("", { SHOT_ID }, function() end)
  end)
  luaunit.assertTrue(ok) -- no Lua error raised
end

function TestVeafEventHandlerAddCallback:test_callback_registered_numerically()
  veafEventHandler.addCallback("testCb", { SHOT_ID }, function() end)
  luaunit.assertEquals(#veafEventHandler.callbacks, 1)
  luaunit.assertEquals(veafEventHandler.callbacks[1].name, "testCb")
end

function TestVeafEventHandlerAddCallback:test_multiple_callbacks_appended()
  veafEventHandler.addCallback("cb1", { SHOT_ID }, function() end)
  veafEventHandler.addCallback("cb2", { BIRTH_ID }, function() end)
  luaunit.assertEquals(#veafEventHandler.callbacks, 2)
  luaunit.assertEquals(veafEventHandler.callbacks[1].name, "cb1")
  luaunit.assertEquals(veafEventHandler.callbacks[2].name, "cb2")
end

function TestVeafEventHandlerAddCallback:test_nil_events_list_is_accepted()
  -- nil events means no filtering; implementation accepts it
  local ok = veafEventHandler.addCallback("cbNilEv", nil, function() end)
  luaunit.assertTrue(ok)
end

function TestVeafEventHandlerAddCallback:test_unknown_event_id_returns_false()
  local ok = veafEventHandler.addCallback("badEv", { 99999 }, function() end)
  luaunit.assertFalse(ok)
end

function TestVeafEventHandlerAddCallback:test_event_by_name_string()
  local ok = veafEventHandler.addCallback("shotByName", { "S_EVENT_SHOT" }, function() end)
  luaunit.assertTrue(ok)
end

-- ---------------------------------------------------------------------------
-- TestVeafEventHandlerCompleteUnit — unitCategory must be a Unit.Category
-- ---------------------------------------------------------------------------
-- The QRA (the sole consumer of event.initiator.unitCategory) compares it against
-- Unit.Category.AIRPLANE/HELICOPTER. completeUnitFromName must therefore expose a
-- Unit.Category (via getCategoryEx), NOT an Object.Category (getCategory), whose UNIT
-- value (1) collides with HELICOPTER (1) and made dynamic-slot airplanes look like
-- helicopters to the QRA (#299 symptom reproduced by Tripack after the #299 fix).
TestVeafEventHandlerCompleteUnit = {}

function TestVeafEventHandlerCompleteUnit:setUp()
  -- completeUnitFromName resolves the pilot via veafRemote, not loaded in this suite.
  veafRemote = {
    getRemoteUserFromUnit = function()
      return nil
    end,
  }
end

function TestVeafEventHandlerCompleteUnit:tearDown()
  dcs_mocks.clearUnitsAndGroups()
  veafRemote = nil
end

function TestVeafEventHandlerCompleteUnit:test_unitCategory_is_unit_category_not_object_category()
  dcs_mocks.addUnit("Intruder", {
    _categoryEx = Unit.Category.AIRPLANE,
    getCategory = function()
      return Object.Category.UNIT
    end, -- real DCS units expose this
  })
  local data = veafEventHandler.completeUnitFromName("Intruder")
  luaunit.assertEquals(data.unitCategory, Unit.Category.AIRPLANE)
  luaunit.assertNotEquals(data.unitCategory, Unit.Category.HELICOPTER)
end

-- ── unitNameFromEvent ───────────────────────────────────────────────────────
-- Both shapes of `initiator` are real, and reading only one of them fails silently: the callback
-- returns early and logs nothing. That is how the 6.16.0 welcome brief shipped dead on every
-- server — it read `getName` alone, which only a dynamic-slot unit answers.

TestVeafEventHandlerUnitNameFromEvent = {}

function TestVeafEventHandlerUnitNameFromEvent:test_it_reads_the_data_table_an_ordinary_slot_carries()
  -- What `completeUnitFromName` returns, and therefore what a callback actually receives.
  local event = { initiator = { unitName = "Chevy11", unitType = "F-16C_50", unitCoalition = 2 } }
  luaunit.assertEquals(veafEventHandler.unitNameFromEvent(event), "Chevy11")
end

function TestVeafEventHandlerUnitNameFromEvent:test_it_falls_back_to_getName_for_a_dynamic_slot()
  -- A dynamic-slot unit has no mist table entry, so the raw DCS object comes through.
  local event = {
    initiator = {
      getName = function()
        return "DynamicChevy"
      end,
    },
  }
  luaunit.assertEquals(veafEventHandler.unitNameFromEvent(event), "DynamicChevy")
end

function TestVeafEventHandlerUnitNameFromEvent:test_the_table_wins_when_both_are_present()
  -- completeUnitFromName never produces both, but a caller passing a raw object it enriched would;
  -- the declared name is the authoritative one.
  local event = {
    initiator = {
      unitName = "FromTable",
      getName = function()
        return "FromMethod"
      end,
    },
  }
  luaunit.assertEquals(veafEventHandler.unitNameFromEvent(event), "FromTable")
end

function TestVeafEventHandlerUnitNameFromEvent:test_nothing_identifiable_is_nil_not_a_crash()
  luaunit.assertNil(veafEventHandler.unitNameFromEvent(nil))
  luaunit.assertNil(veafEventHandler.unitNameFromEvent({}))
  luaunit.assertNil(veafEventHandler.unitNameFromEvent({ initiator = nil }))
  luaunit.assertNil(veafEventHandler.unitNameFromEvent({ initiator = { unitType = "F-16C_50" } }))
end

-- ── the handler is registered with DCS exactly once ─────────────────────────
-- `initialize()` runs **twice** on every mission: the script calls it on load (veafEventHandler.lua,
-- last line) so a mission that generates no veaf-config still handles events, and the generated
-- `veaf-config.lua` calls it again alongside the other modules. Both calls are deliberate; what was
-- not deliberate is that each one added the handler to DCS again.
--
-- Seen in a real server log, two lines per session:
--   VEAF-EVENTS|I|?|22085: loaded /INFO            (script load)
--   VEAF-EVENTS|I|initialize|22085: loaded /INFO   (veaf-config.lua)
--
-- A handler registered twice means DCS delivers every event twice, and every callback behind it runs
-- twice: two menu rebuilds on a birth, two QRA evaluations, two FARP warehouse refills.

TestVeafEventHandlerRegistration = {}

function TestVeafEventHandlerRegistration:setUp()
  self._savedAdd = world.addEventHandler
  self.registered = 0
  world.addEventHandler = function(_handler)
    self.registered = self.registered + 1
  end
end

function TestVeafEventHandlerRegistration:tearDown()
  world.addEventHandler = self._savedAdd
end

function TestVeafEventHandlerRegistration:test_a_second_initialize_does_not_register_again()
  -- The real sequence: the script already initialised itself on load, then veaf-config.lua calls it.
  veafEventHandler.initialize()
  luaunit.assertEquals(self.registered, 0, "the handler was already registered when the script loaded")
end

function TestVeafEventHandlerRegistration:test_registering_from_scratch_happens_once()
  veafEventHandler.eventHandlerRegistered = nil -- as if the script had never run
  veafEventHandler.initialize()
  veafEventHandler.initialize()
  luaunit.assertEquals(self.registered, 1)
end

function TestVeafEventHandlerRegistration:test_the_events_map_is_still_rebuilt_every_time()
  -- Guarding the registration must not turn the rest of initialize() into a no-op.
  veafEventHandler.knownEvents = {}
  veafEventHandler.initialize()
  luaunit.assertNotNil(veafEventHandler.knownEvents["S_EVENT_BIRTH"])
end

os.exit(luaunit.LuaUnit.run())
