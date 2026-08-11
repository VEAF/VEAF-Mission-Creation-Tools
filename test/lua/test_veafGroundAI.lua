--- Tests for veafGroundAI.lua — GroundUnitHandler class (global).
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafGroundAI.lua")

-- ---------------------------------------------------------------------------
-- TestVeafGroundAIModule
-- ---------------------------------------------------------------------------
TestVeafGroundAIModule = {}

function TestVeafGroundAIModule:test_id()
  luaunit.assertIsString(veafGroundAI.Id)
end

function TestVeafGroundAIModule:test_markerKeyphrase()
  luaunit.assertIsString(veafGroundAI.MarkerKeyphrase)
end

function TestVeafGroundAIModule:test_watchdog_delay()
  luaunit.assertIsNumber(veafGroundAI.WATCHDOG_DELAY)
end

function TestVeafGroundAIModule:test_handlers_table()
  luaunit.assertIsTable(veafGroundAI.handlers)
end

-- ---------------------------------------------------------------------------
-- TestVeafGroundUnitHandlerClass
-- ---------------------------------------------------------------------------
TestVeafGroundUnitHandlerClass = {}

function TestVeafGroundUnitHandlerClass:test_class_exists()
  luaunit.assertIsTable(GroundUnitHandler)
end

function TestVeafGroundUnitHandlerClass:test_status_constants()
  luaunit.assertEquals(GroundUnitHandler.STATUS_READY, 1)
  luaunit.assertEquals(GroundUnitHandler.STATUS_ACTIVE, 2)
  luaunit.assertEquals(GroundUnitHandler.STATUS_OVER, 4)
end

function TestVeafGroundUnitHandlerClass:test_statusToString_ready()
  luaunit.assertEquals(GroundUnitHandler.statusToString(GroundUnitHandler.STATUS_READY), "STATUS_READY")
end

function TestVeafGroundUnitHandlerClass:test_statusToString_active()
  luaunit.assertEquals(GroundUnitHandler.statusToString(GroundUnitHandler.STATUS_ACTIVE), "STATUS_ACTIVE")
end

function TestVeafGroundUnitHandlerClass:test_statusToString_over()
  luaunit.assertEquals(GroundUnitHandler.statusToString(GroundUnitHandler.STATUS_OVER), "STATUS_OVER")
end

function TestVeafGroundUnitHandlerClass:test_statusToString_unknown_returns_empty()
  luaunit.assertEquals(GroundUnitHandler.statusToString(99), "")
end

-- ---------------------------------------------------------------------------
-- TestVeafGroundUnitHandlerOOP
-- ---------------------------------------------------------------------------
TestVeafGroundUnitHandlerOOP = {}

function TestVeafGroundUnitHandlerOOP:setUp()
  self.h = GroundUnitHandler:new()
end

function TestVeafGroundUnitHandlerOOP:test_new_returns_table()
  luaunit.assertIsTable(self.h)
end

function TestVeafGroundUnitHandlerOOP:test_draw_default_falsy()
  local d = self.h:getDraw()
  luaunit.assertFalse(d == true)
end

function TestVeafGroundUnitHandlerOOP:test_setDraw_true()
  self.h:setDraw(true)
  luaunit.assertTrue(self.h:getDraw())
end

function TestVeafGroundUnitHandlerOOP:test_setDraw_false()
  self.h:setDraw(true)
  self.h:setDraw(false)
  luaunit.assertFalse(self.h:getDraw())
end

function TestVeafGroundUnitHandlerOOP:test_silent_default_falsy()
  luaunit.assertFalse(self.h:getSilent() == true)
end

function TestVeafGroundUnitHandlerOOP:test_setSilent_true()
  self.h:setSilent(true)
  luaunit.assertTrue(self.h:getSilent())
end

function TestVeafGroundUnitHandlerOOP:test_setPlayerUnitsNames()
  self.h:setPlayerUnitsNames({ "alpha", "bravo" })
  luaunit.assertEquals(#self.h:getPlayerUnitsNames(), 2)
end

function TestVeafGroundUnitHandlerOOP:test_setDcsGroup()
  self.h:setDcsGroup("myGroup")
  luaunit.assertEquals(self.h:getDcsGroup(), "myGroup")
end

-- ---------------------------------------------------------------------------
-- TestVeafGroundUnitHandlerOrders
-- ---------------------------------------------------------------------------
TestVeafGroundUnitHandlerOrders = {}

function TestVeafGroundUnitHandlerOrders:setUp()
  self.h = GroundUnitHandler:new()
end

function TestVeafGroundUnitHandlerOrders:test_no_orders_getCurrentOrder_nil()
  luaunit.assertNil(self.h:getCurrentOrder())
end

function TestVeafGroundUnitHandlerOrders:test_setOrders_returns_first()
  self.h:setOrders({ "order1", "order2", "order3" })
  luaunit.assertEquals(self.h:getCurrentOrder(), "order1")
end

function TestVeafGroundUnitHandlerOrders:test_completeOrder_advances()
  self.h:setOrders({ "o1", "o2", "o3" })
  self.h:completeOrder()
  luaunit.assertEquals(self.h:getCurrentOrder(), "o2")
end

function TestVeafGroundUnitHandlerOrders:test_completeOrder_twice()
  self.h:setOrders({ "o1", "o2", "o3" })
  self.h:completeOrder()
  self.h:completeOrder()
  luaunit.assertEquals(self.h:getCurrentOrder(), "o3")
end

function TestVeafGroundUnitHandlerOrders:test_completeOrder_beyond_last_returns_nil()
  self.h:setOrders({ "o1" })
  self.h:completeOrder()
  luaunit.assertNil(self.h:getCurrentOrder())
end

function TestVeafGroundUnitHandlerOrders:test_clearOrders()
  self.h:setOrders({ "o1", "o2" })
  self.h:clearOrders()
  luaunit.assertNil(self.h:getCurrentOrder())
end

function TestVeafGroundUnitHandlerOrders:test_addOrder_after_clear()
  self.h:clearOrders()
  self.h:addOrder("newOrder")
  luaunit.assertEquals(self.h:getCurrentOrder(), "newOrder")
end

-- ---------------------------------------------------------------------------
-- TestVeafGroundUnitHandlerExtra
-- ---------------------------------------------------------------------------
TestVeafGroundUnitHandlerExtra = {}

function TestVeafGroundUnitHandlerExtra:setUp()
  self.h = GroundUnitHandler:new()
  self.h.name = "TestHandler"
end

function TestVeafGroundUnitHandlerExtra:test_getName_returns_name()
  luaunit.assertEquals(self.h:getName(), "TestHandler")
end

function TestVeafGroundUnitHandlerExtra:test_getDescription_without_dcsGroup()
  local desc = self.h:getDescription()
  luaunit.assertIsString(desc)
end

function TestVeafGroundUnitHandlerExtra:test_setPlayerCoalitions()
  self.h:setPlayerCoalitions({ 1, 2 })
  luaunit.assertIsTable(self.h.playerCoalitions)
end

function TestVeafGroundUnitHandlerExtra:test_setZoneDrawings_and_get()
  self.h:setZoneDrawings({ 101, 102 })
  luaunit.assertEquals(#self.h:getZoneDrawings(), 2)
end

function TestVeafGroundUnitHandlerExtra:test_setCheckFunctionSchedule_and_get()
  self.h:setCheckFunctionSchedule(42)
  luaunit.assertEquals(self.h:getCheckFunctionSchedule(), 42)
  self.h:setCheckFunctionSchedule(nil)
  luaunit.assertNil(self.h:getCheckFunctionSchedule())
end

function TestVeafGroundUnitHandlerExtra:test_handleOrder_completes_order()
  self.h:setOrders({ "orderA", "orderB" })
  self.h:handleOrder("orderA")
  luaunit.assertEquals(self.h:getCurrentOrder(), "orderB")
end

function TestVeafGroundUnitHandlerExtra:test_orderTextAnalysis_base_returns_nil()
  local result = self.h:orderTextAnalysis("sometext")
  luaunit.assertNil(result)
end

function TestVeafGroundUnitHandlerExtra:test_check_runs_without_error()
  self.h:check()
  luaunit.assertNil(self.h:getCheckFunctionSchedule())
end

function TestVeafGroundUnitHandlerExtra:test_start_sets_status_active()
  self.h:setSilent(true)
  self.h:start()
  luaunit.assertEquals(self.h.status, GroundUnitHandler.STATUS_ACTIVE)
end

function TestVeafGroundUnitHandlerExtra:test_stop_sets_status_ready()
  self.h:setSilent(true)
  self.h:start()
  self.h:stop()
  luaunit.assertEquals(self.h.status, GroundUnitHandler.STATUS_READY)
end

function TestVeafGroundUnitHandlerExtra:test_setName_registers_in_handlers()
  local h2 = GroundUnitHandler:new()
  h2:setName("registered_test_handler_x")
  luaunit.assertNotNil(veafGroundAI.handlers["registered_test_handler_x"])
end

-- ---------------------------------------------------------------------------
-- TestVeafGroundAIFunctions
-- ---------------------------------------------------------------------------
TestVeafGroundAIFunctions = {}

function TestVeafGroundAIFunctions:test_add_and_get()
  local h = GroundUnitHandler:new()
  h.name = "myhandlerx"
  veafGroundAI.add(h)
  luaunit.assertNotNil(veafGroundAI.get("myhandlerx"))
end

function TestVeafGroundAIFunctions:test_get_nonexistent_returns_nil()
  luaunit.assertNil(veafGroundAI.get("doesnotexist_zzz_abc"))
end

function TestVeafGroundAIFunctions:test_remove()
  local h = GroundUnitHandler:new()
  h.name = "myhandlery"
  veafGroundAI.add(h)
  veafGroundAI.remove(h)
  luaunit.assertNil(veafGroundAI.get("myhandlery"))
end

-- ---------------------------------------------------------------------------
-- TestVeafGroundAIMarkTextAnalysis
-- ---------------------------------------------------------------------------
TestVeafGroundAIMarkTextAnalysis = {}

function TestVeafGroundAIMarkTextAnalysis:test_non_matching_returns_nil()
  local r = veafGroundAI.markTextAnalysis({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, "_cas something")
  luaunit.assertNil(r)
end

function TestVeafGroundAIMarkTextAnalysis:test_no_name_returns_nil()
  local r = veafGroundAI.markTextAnalysis({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, "_ground start")
  luaunit.assertNil(r)
end

function TestVeafGroundAIMarkTextAnalysis:test_set_without_group_returns_nil()
  local r = veafGroundAI.markTextAnalysis({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, "_ground set, name TestH")
  luaunit.assertNil(r)
end

function TestVeafGroundAIMarkTextAnalysis:test_order_verb_returns_options()
  local r = veafGroundAI.markTextAnalysis({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, "_ground order, name TestH, order aim")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.verb, veafGroundAI.VERB_ORDER)
  luaunit.assertEquals(r.name, "TestH")
  luaunit.assertEquals(r.order, "aim")
end

function TestVeafGroundAIMarkTextAnalysis:test_start_verb_returns_options()
  local r = veafGroundAI.markTextAnalysis({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, "_ground start, name TestH")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.verb, veafGroundAI.VERB_START)
end

function TestVeafGroundAIMarkTextAnalysis:test_stop_verb_returns_options()
  local r = veafGroundAI.markTextAnalysis({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, "_ground stop, name TestH")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.verb, veafGroundAI.VERB_STOP)
end

function TestVeafGroundAIMarkTextAnalysis:test_clear_verb_returns_options()
  local r = veafGroundAI.markTextAnalysis({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, "_ground clear, name TestH")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.verb, veafGroundAI.VERB_CLEAR)
end

function TestVeafGroundAIMarkTextAnalysis:test_status_verb_returns_options()
  local r = veafGroundAI.markTextAnalysis({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, "_ground status, name TestH")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.verb, veafGroundAI.VERB_STATUS)
end

function TestVeafGroundAIMarkTextAnalysis:test_unset_without_group_returns_nil()
  local r = veafGroundAI.markTextAnalysis({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, "_ground unset, name TestH")
  luaunit.assertNil(r)
end

-- ---------------------------------------------------------------------------
-- TestVeafGroundAICharacterisation
--
-- REFACTOR-MARKER-PARSER ticket 01: what this parser does TODAY, measured. This one carries the
-- inventory's hardest quirk — `set` and `unset` search the game world for the nearest allied
-- group when `groupname` is absent, from inside the parser. A shared text parser cannot do
-- that, so ticket 03 has to decide where it goes before migrating this module.
-- ---------------------------------------------------------------------------
TestVeafGroundAICharacterisation = {}

local function analyse(text)
  return veafGroundAI.markTextAnalysis({ x = 0, y = 0, z = 0 }, coalition.side.BLUE, text)
end

function TestVeafGroundAICharacterisation:test_every_verb_maps_to_its_constant()
  luaunit.assertEquals(analyse("_ground order, name H, order fire").verb, veafGroundAI.VERB_ORDER)
  luaunit.assertEquals(analyse("_ground start, name H").verb, veafGroundAI.VERB_START)
  luaunit.assertEquals(analyse("_ground stop, name H").verb, veafGroundAI.VERB_STOP)
  luaunit.assertEquals(analyse("_ground clear, name H").verb, veafGroundAI.VERB_CLEAR)
  luaunit.assertEquals(analyse("_ground status, name H").verb, veafGroundAI.VERB_STATUS)
end

function TestVeafGroundAICharacterisation:test_the_verb_is_case_insensitive()
  luaunit.assertEquals(analyse("_ground STATUS, name H").verb, veafGroundAI.VERB_STATUS)
end

-- `name` is mandatory for every verb, and its absence refuses the command.
function TestVeafGroundAICharacterisation:test_a_missing_name_refuses_the_command()
  luaunit.assertNil(analyse("_ground status"))
end

-- DEFECT, recorded not fixed: this parser reads `str[2] or ""`, so a valueless `name` becomes
-- the EMPTY STRING, and `if not options.name` does not catch it because "" is truthy in Lua.
-- The command proceeds with a nameless handler. This is exactly the bug SECREV-010 fixed in
-- veafMove, which guards with `not name or name == ""`.
function TestVeafGroundAICharacterisation:test_a_valueless_name_passes_the_guard_as_an_empty_string()
  local r = analyse("_ground status, name")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.name, "")
end

-- Unlike veafCasMission and veafMove, an absent value here is "" rather than nil. That is the
-- inventory's quirk 1, and the shared parser has to express both.
function TestVeafGroundAICharacterisation:test_a_valueless_order_becomes_an_empty_string()
  luaunit.assertEquals(analyse("_ground order, name H, order").order, "")
end

function TestVeafGroundAICharacterisation:test_a_repeated_keyword_keeps_the_last_value()
  luaunit.assertEquals(analyse("_ground status, name H, name J").name, "J")
end

function TestVeafGroundAICharacterisation:test_unknown_keyword_is_ignored_silently()
  local r = analyse("_ground status, name H, banana 3")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.name, "H")
  luaunit.assertNil(r.unknownParameters)
end

function TestVeafGroundAICharacterisation:test_empty_text_returns_nil()
  luaunit.assertNil(analyse(""))
end

-- ---------------------------------------------------------------------------
-- TestArtilleryOrderTextCharacterisation
--
-- REFACTOR-MARKER-PARSER ticket 01, GROUP B: the same key/value loop under another name, and
-- the only one in the codebase splitting on ";" instead of ",". The shared parser therefore
-- needs the separator as a parameter, not a constant.
-- ---------------------------------------------------------------------------
TestArtilleryOrderTextCharacterisation = {}

function TestArtilleryOrderTextCharacterisation:setUp()
  self.ah = ArtilleryUnitHandler:new()
end

function TestArtilleryOrderTextCharacterisation:test_the_separator_is_a_semicolon()
  luaunit.assertEquals(self.ah:orderTextAnalysis("aim; shells 5").shells, 5)
end

-- A comma is NOT a separator here, so "shells 5" is never seen as a keyword.
function TestArtilleryOrderTextCharacterisation:test_a_comma_does_not_separate()
  luaunit.assertNil(self.ah:orderTextAnalysis("aim, shells 5").shells)
end

function TestArtilleryOrderTextCharacterisation:test_several_keywords_apply()
  local r = self.ah:orderTextAnalysis("aim; shells 5; radius 100")
  luaunit.assertEquals(r.shells, 5)
  luaunit.assertEquals(r.radius, 100)
end

function TestArtilleryOrderTextCharacterisation:test_an_unrecognised_verb_returns_nil()
  luaunit.assertNil(self.ah:orderTextAnalysis("move"))
end

function TestArtilleryOrderTextCharacterisation:test_the_verb_is_case_insensitive()
  luaunit.assertEquals(self.ah:orderTextAnalysis("AIM").verb, ArtilleryUnitHandler.VERB_FIRE_FORAIM)
end

-- "aim" is tested before "fire", so the chain order wins over the order in the text.
function TestArtilleryOrderTextCharacterisation:test_the_chain_order_wins_over_the_text_order()
  luaunit.assertEquals(self.ah:orderTextAnalysis("fire aim").verb, ArtilleryUnitHandler.VERB_FIRE_FORAIM)
end

function TestArtilleryOrderTextCharacterisation:test_a_valueless_shells_leaves_the_field_nil()
  luaunit.assertNil(self.ah:orderTextAnalysis("aim; shells").shells)
end

-- `target` is validated before being stored: an unparseable coordinate is dropped, which is
-- the one place in the codebase where a parameter rule refuses its own input.
function TestArtilleryOrderTextCharacterisation:test_an_invalid_target_is_dropped()
  luaunit.assertNil(self.ah:orderTextAnalysis("aim; target banana").target)
end

function TestArtilleryOrderTextCharacterisation:test_an_empty_order_returns_nil()
  luaunit.assertNil(self.ah:orderTextAnalysis(""))
end

-- ---------------------------------------------------------------------------
-- TestArtilleryUnitHandlerOOP
-- ---------------------------------------------------------------------------
TestArtilleryUnitHandlerOOP = {}

function TestArtilleryUnitHandlerOOP:setUp()
  self.ah = ArtilleryUnitHandler:new()
  self.ah.name = "Artillery1"
  self.ah:setSilent(true)
  local mockCtrl = {
    resetTask = function(self) end,
    pushTask = function(self, task) end,
    setTask = function(self, task) end,
  }
  self.ah.dcsGroup = {
    getController = function(self)
      return mockCtrl
    end,
    getName = function(self)
      return "Art1Group"
    end,
  }
end

function TestArtilleryUnitHandlerOOP:test_new_returns_table()
  luaunit.assertIsTable(self.ah)
end

function TestArtilleryUnitHandlerOOP:test_class_name()
  luaunit.assertEquals(self.ah.CLASS_NAME, "ArtilleryUnitHandler")
end

function TestArtilleryUnitHandlerOOP:test_orderTextAnalysis_aim()
  local result = self.ah:orderTextAnalysis("aim")
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.verb, ArtilleryUnitHandler.VERB_FIRE_FORAIM)
end

function TestArtilleryUnitHandlerOOP:test_orderTextAnalysis_fire()
  local result = self.ah:orderTextAnalysis("fire")
  luaunit.assertNotNil(result)
  luaunit.assertEquals(result.verb, ArtilleryUnitHandler.VERB_FIRE_FOREFFECT)
end

function TestArtilleryUnitHandlerOOP:test_orderTextAnalysis_invalid_returns_nil()
  local result = self.ah:orderTextAnalysis("move")
  luaunit.assertNil(result)
end

function TestArtilleryUnitHandlerOOP:test_orderTextAnalysis_with_shells()
  local result = self.ah:orderTextAnalysis("aim; shells 10")
  luaunit.assertNotNil(result)
  luaunit.assertNotNil(result.shells)
end

function TestArtilleryUnitHandlerOOP:test_orderTextAnalysis_with_radius()
  local result = self.ah:orderTextAnalysis("aim; radius 50")
  luaunit.assertNotNil(result)
  luaunit.assertNotNil(result.radius)
end

function TestArtilleryUnitHandlerOOP:test_fireForAim_nil_coords_returns_early()
  self.ah:fireForAim(nil)
  luaunit.assertTrue(true)
end

function TestArtilleryUnitHandlerOOP:test_fireForEffect_nil_no_previous_target()
  self.ah:fireForEffect(nil)
  luaunit.assertTrue(true)
end

function TestArtilleryUnitHandlerOOP:test_fireAtCoordinates_nil_shells_returns_early()
  self.ah:fireAtCoordinates("target", nil, 50)
  luaunit.assertTrue(true)
end

function TestArtilleryUnitHandlerOOP:test_fireAtCoordinates_nil_coords_returns_early()
  self.ah:fireAtCoordinates(nil, 10, 50)
  luaunit.assertTrue(true)
end

function TestArtilleryUnitHandlerOOP:test_handleOrder_fire_nil_target()
  local order = { verb = ArtilleryUnitHandler.ORDER_FIRE, parameters = { shells = 10, target = nil, radius = 50 } }
  self.ah:handleOrder(order)
  luaunit.assertNil(self.ah:getCurrentOrder())
end

function TestArtilleryUnitHandlerOOP:test_stop_sets_status_ready()
  self.ah:start()
  self.ah:stop()
  luaunit.assertEquals(self.ah.status, GroundUnitHandler.STATUS_READY)
end

function TestArtilleryUnitHandlerOOP:test_clearOrders_works()
  self.ah:addOrder("test_order")
  self.ah:clearOrders()
  luaunit.assertNil(self.ah:getCurrentOrder())
end

os.exit(luaunit.LuaUnit.run())
