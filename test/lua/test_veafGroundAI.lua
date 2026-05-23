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

function TestVeafGroundAIModule:test_version()
  luaunit.assertIsString(veafGroundAI.Version)
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
  luaunit.assertEquals(GroundUnitHandler.STATUS_READY,  1)
  luaunit.assertEquals(GroundUnitHandler.STATUS_ACTIVE, 2)
  luaunit.assertEquals(GroundUnitHandler.STATUS_OVER,   4)
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
  self.h:setPlayerUnitsNames({"alpha", "bravo"})
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
  self.h:setOrders({"order1", "order2", "order3"})
  luaunit.assertEquals(self.h:getCurrentOrder(), "order1")
end

function TestVeafGroundUnitHandlerOrders:test_completeOrder_advances()
  self.h:setOrders({"o1", "o2", "o3"})
  self.h:completeOrder()
  luaunit.assertEquals(self.h:getCurrentOrder(), "o2")
end

function TestVeafGroundUnitHandlerOrders:test_completeOrder_twice()
  self.h:setOrders({"o1", "o2", "o3"})
  self.h:completeOrder()
  self.h:completeOrder()
  luaunit.assertEquals(self.h:getCurrentOrder(), "o3")
end

function TestVeafGroundUnitHandlerOrders:test_completeOrder_beyond_last_returns_nil()
  self.h:setOrders({"o1"})
  self.h:completeOrder()
  luaunit.assertNil(self.h:getCurrentOrder())
end

function TestVeafGroundUnitHandlerOrders:test_clearOrders()
  self.h:setOrders({"o1", "o2"})
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
    getController = function(self) return mockCtrl end,
    getName = function(self) return "Art1Group" end,
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
