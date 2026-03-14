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

os.exit(luaunit.LuaUnit.run())
