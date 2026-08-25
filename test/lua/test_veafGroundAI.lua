--- Tests for veafGroundAI.lua — GroundUnitHandler class (global).
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
-- veafI18n, because the correction loop tells the player what it understood and the tests assert
-- on that text. Without it veaf.t returns the key and the assertions would pass on a message no
-- player could read.
dofile(src .. "/veafI18n.lua")
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

-- FIXED (ticket 03): this parser reads `str[2] or ""`, so a valueless `name` becomes the EMPTY
-- STRING, and the old `if not options.name` guard did not catch it because "" is truthy in Lua —
-- the command proceeded with a nameless handler. Exactly the bug SECREV-010 fixed in veafMove,
-- and which the veafShortcuts loops got right by testing `#name == 0`.
function TestVeafGroundAICharacterisation:test_a_valueless_name_is_refused()
  luaunit.assertNil(analyse("_ground status, name"))
end

-- Measured, not assumed: `name` followed only by spaces is refused too, because `veaf.trim` runs
-- BEFORE the key/value split (quirk 13), so trailing whitespace never becomes a value. A name of
-- pure whitespace is therefore unreachable through a marker.
function TestVeafGroundAICharacterisation:test_a_name_followed_only_by_spaces_is_refused_too()
  luaunit.assertNil(analyse("_ground status, name  "))
end

-- But a SECOND space is part of the value, since only the first one separates (quirk 11).
function TestVeafGroundAICharacterisation:test_a_second_space_becomes_part_of_the_name()
  luaunit.assertEquals(analyse("_ground status, name  Alpha").name, " Alpha")
end

-- FIXED (ticket 03): a valueless `groupname` used to reach `Group.getByName("")`. An empty name
-- cannot identify a group, and leaving `group` nil is what lets the nearest-allied-group search
-- run — which is the intended answer when the pilot named no group.
function TestVeafGroundAICharacterisation:test_a_valueless_groupname_does_not_query_dcs()
  local queried = {}
  local savedGetByName = Group.getByName
  Group.getByName = function(name)
    table.insert(queried, name)
    return savedGetByName(name)
  end

  analyse("_ground status, name H, groupname")

  Group.getByName = savedGetByName
  luaunit.assertEquals(#queried, 0, "queried DCS with: " .. table.concat(queried, ", "))
end

function TestVeafGroundAICharacterisation:test_a_named_groupname_still_queries_dcs()
  local queried = {}
  local savedGetByName = Group.getByName
  Group.getByName = function(name)
    table.insert(queried, name)
    return savedGetByName(name)
  end

  analyse("_ground status, name H, groupname Alpha")

  Group.getByName = savedGetByName
  luaunit.assertEquals(queried, { "Alpha" })
end

-- Unlike veafCasMission and veafMove, an absent value here is "" rather than nil. That is the
-- inventory's quirk 1, and the shared parser has to express both.
function TestVeafGroundAICharacterisation:test_a_valueless_order_becomes_an_empty_string()
  luaunit.assertEquals(analyse("_ground order, name H, order").order, "")
end

function TestVeafGroundAICharacterisation:test_a_repeated_keyword_keeps_the_last_value()
  luaunit.assertEquals(analyse("_ground status, name H, name J").name, "J")
end

-- FEAT-SPAWN-OPTION-VALIDATION renamed this: an unknown keyword is no longer ignored, it is
-- collected so the caller can name it to the pilot and abort. What the original test proved and
-- this one still proves: the **recognised** options are untouched by the presence of a bad one.
function TestVeafGroundAICharacterisation:test_an_unknown_keyword_is_collected_not_ignored()
  local r = analyse("_ground status, name H, banana 3")
  luaunit.assertNotNil(r)
  luaunit.assertEquals(r.name, "H")
  luaunit.assertEquals(r.unknownParameters[1].key, "banana")
  luaunit.assertEquals(#r.unknownParameters, 1)
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

-- A comma is NOT a separator here, so "shells 5" is never seen as a keyword. Until
-- FEAT-SPAWN-OPTION-VALIDATION that was silent — the pilot's `shells 5` simply vanished. The order is
-- now refused and the verb comes back as the unknown key `'aim,'` with `aim` suggested, which is the
-- most useful thing the parser can say to someone who forgot the separator is a semicolon.
function TestArtilleryOrderTextCharacterisation:test_a_comma_is_refused_rather_than_mis_parsed()
  luaunit.assertNil(self.ah:orderTextAnalysis("aim, shells 5"))
end

function TestArtilleryOrderTextCharacterisation:test_the_wrong_separator_names_itself()
  local options = veaf.parseMarkerText("aim, shells 5", ArtilleryUnitHandler.OrderSpec)
  luaunit.assertEquals(options.unknownParameters[1].key, "aim,")
  luaunit.assertEquals(options.unknownParameters[1].suggestion, "aim")
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

-- ===========================================================================
-- FEAT-ARTILLERY-CONTROL — the fire-adjustment loop (#198, #57)
--
-- The arithmetic gets the most tests here for the reason the lot's own PRD gives: a wrong bearing is a
-- shell in the wrong village. And the convention is the trap rather than the trigonometry — a runtime
-- vec3 is `{ x = northing, y = altitude, z = easting }`, so mixing x and z raises no error and only
-- moves the shells. `docs/agents/dcs-coordinates.md` exists because of exactly that.
-- ===========================================================================
TestArtilleryCorrectionParsing = {}

function TestArtilleryCorrectionParsing:test_the_form_the_issue_writes()
  -- `09050` is fifty metres east: three digits of bearing, then the metres.
  local correction = ArtilleryUnitHandler.parseCorrection("09050")
  luaunit.assertNotNil(correction)
  luaunit.assertEquals(correction.bearing, 90)
  luaunit.assertEquals(correction.distance, 50)
end

function TestArtilleryCorrectionParsing:test_a_leading_zero_bearing()
  local correction = ArtilleryUnitHandler.parseCorrection("00075")
  luaunit.assertEquals(correction.bearing, 0)
  luaunit.assertEquals(correction.distance, 75)
end

function TestArtilleryCorrectionParsing:test_a_distance_of_more_than_two_digits()
  -- Corrections are not all small; the distance takes whatever digits remain.
  local correction = ArtilleryUnitHandler.parseCorrection("2701500")
  luaunit.assertEquals(correction.bearing, 270)
  luaunit.assertEquals(correction.distance, 1500)
end

function TestArtilleryCorrectionParsing:test_surrounding_spaces_are_tolerated()
  luaunit.assertEquals(ArtilleryUnitHandler.parseCorrection("  09050 ").distance, 50)
end

-- ── refusals ────────────────────────────────────────────────────────────────
-- Rejected rather than guessed. A lenient parser here fires shells at a number nobody typed.

function TestArtilleryCorrectionParsing:test_three_digits_alone_are_not_a_correction()
  -- A bearing with no distance. Accepting it would have to invent the distance.
  luaunit.assertNil(ArtilleryUnitHandler.parseCorrection("090"))
end

function TestArtilleryCorrectionParsing:test_a_two_digit_bearing_is_refused()
  -- `9050` would read as bearing 905, and that is the point of requiring three digits: `090` and `90`
  -- are the same string with different meanings once the distance is appended.
  luaunit.assertNil(ArtilleryUnitHandler.parseCorrection("9050"))
end

function TestArtilleryCorrectionParsing:test_a_bearing_of_360_is_refused()
  -- Not folded to 0: a player who wrote it meant something, and accepting it silently would hide the
  -- same typo the next time it reads 361.
  luaunit.assertNil(ArtilleryUnitHandler.parseCorrection("360100"))
  luaunit.assertNil(ArtilleryUnitHandler.parseCorrection("999100"))
end

function TestArtilleryCorrectionParsing:test_a_distance_of_zero_is_refused()
  luaunit.assertNil(ArtilleryUnitHandler.parseCorrection("0900"))
end

function TestArtilleryCorrectionParsing:test_anything_that_is_not_digits_is_refused()
  luaunit.assertNil(ArtilleryUnitHandler.parseCorrection("090/50"))
  luaunit.assertNil(ArtilleryUnitHandler.parseCorrection("east 50"))
  luaunit.assertNil(ArtilleryUnitHandler.parseCorrection(""))
  luaunit.assertNil(ArtilleryUnitHandler.parseCorrection(nil))
  luaunit.assertNil(ArtilleryUnitHandler.parseCorrection(9050))
end

-- ===========================================================================
-- The offset arithmetic
-- ===========================================================================
TestArtilleryShiftPoint = {}

function TestArtilleryShiftPoint:_origin()
  return { x = 1000, y = 50, z = 2000 }
end

function TestArtilleryShiftPoint:test_north_moves_the_northing()
  -- x is the northing. If this test and the next one ever agree, the convention has been mixed up.
  local shifted = ArtilleryUnitHandler.shiftPoint(self:_origin(), 0, 100)
  luaunit.assertAlmostEquals(shifted.x, 1100, 0.01)
  luaunit.assertAlmostEquals(shifted.z, 2000, 0.01)
end

function TestArtilleryShiftPoint:test_east_moves_the_easting()
  -- z is the easting, and 090 is east. This is the case #198 writes as its example.
  local shifted = ArtilleryUnitHandler.shiftPoint(self:_origin(), 90, 100)
  luaunit.assertAlmostEquals(shifted.x, 1000, 0.01)
  luaunit.assertAlmostEquals(shifted.z, 2100, 0.01)
end

function TestArtilleryShiftPoint:test_south_and_west_go_the_other_way()
  local south = ArtilleryUnitHandler.shiftPoint(self:_origin(), 180, 100)
  luaunit.assertAlmostEquals(south.x, 900, 0.01)
  local west = ArtilleryUnitHandler.shiftPoint(self:_origin(), 270, 100)
  luaunit.assertAlmostEquals(west.z, 1900, 0.01)
end

function TestArtilleryShiftPoint:test_a_diagonal_splits_the_distance()
  -- 045 at 100 m is 70.7 m on each axis. A correction that put the whole distance on both would land
  -- 41 m long, which is inside a battery's own dispersion and therefore invisible in game.
  local shifted = ArtilleryUnitHandler.shiftPoint(self:_origin(), 45, 100)
  luaunit.assertAlmostEquals(shifted.x, 1070.71, 0.01)
  luaunit.assertAlmostEquals(shifted.z, 2070.71, 0.01)
end

function TestArtilleryShiftPoint:test_the_altitude_is_carried_unchanged()
  -- Not recomputed: a correction is a horizontal offset, and DCS resolves the ground height itself.
  luaunit.assertEquals(ArtilleryUnitHandler.shiftPoint(self:_origin(), 123, 456).y, 50)
end

function TestArtilleryShiftPoint:test_the_original_point_is_not_modified()
  -- The stored aim point must survive a correction being computed from it, or a second correction
  -- would compound the first.
  local origin = self:_origin()
  ArtilleryUnitHandler.shiftPoint(origin, 90, 100)
  luaunit.assertEquals(origin.z, 2000)
end

-- ===========================================================================
-- The loop itself: fire, correct, fire again
--
-- What this pins beyond the arithmetic is the *state*: a correction applies to the battery's last aim
-- point, and the battery's name is the fire mission's identity. That is not a design invented for this
-- lot — an order already names its battery (`_ground order, name Sierra23, order "…"`), so a second
-- registry of mission names would give a player two names for one thing.
-- ===========================================================================
TestArtilleryCorrectionLoop = {}

function TestArtilleryCorrectionLoop:setUp()
  self._savedOutText = trigger.action.outText
  self.messages = {}
  trigger.action.outText = function(text, duration)
    table.insert(self.messages, text)
  end

  self.handler = ArtilleryUnitHandler:new()
  self.handler:setName("Sierra23")
  self.handler.silent = false

  -- Record the orders rather than let them reach a DCS controller.
  self.orders = {}
  local test = self
  self.handler.addOrder = function(_, order)
    table.insert(test.orders, order)
  end
end

function TestArtilleryCorrectionLoop:tearDown()
  trigger.action.outText = self._savedOutText
end

function TestArtilleryCorrectionLoop:_lastTarget()
  return self.orders[#self.orders] and self.orders[#self.orders].parameters.target
end

function TestArtilleryCorrectionLoop:test_firing_remembers_where_it_aimed()
  -- The state the module did not keep. Without it a correction has nothing to correct from.
  self.handler:fireAtCoordinates({ x = 1000, y = 0, z = 2000 }, 10, 50)
  luaunit.assertNotNil(self.handler.lastAimPoint)
  luaunit.assertEquals(self.handler.lastAimPoint.x, 1000)
  luaunit.assertEquals(self.handler.lastAimPoint.z, 2000)
end

function TestArtilleryCorrectionLoop:test_a_correction_fires_at_the_shifted_point()
  self.handler:fireAtCoordinates({ x = 1000, y = 0, z = 2000 }, 10, 50)
  self.handler:correct({ bearing = 90, distance = 50 }, 10, 50)
  local target = self:_lastTarget()
  luaunit.assertNotNil(target, "a correction must actually fire")
  luaunit.assertAlmostEquals(target.x, 1000, 0.01)
  luaunit.assertAlmostEquals(target.z, 2050, 0.01)
end

function TestArtilleryCorrectionLoop:test_corrections_compound()
  -- Two corrections east of 50 m are 100 m east of the original, not 50: each one moves the aim point
  -- it will correct from next. That is what makes it an adjustment loop rather than a single offset.
  self.handler:fireAtCoordinates({ x = 1000, y = 0, z = 2000 }, 10, 50)
  self.handler:correct({ bearing = 90, distance = 50 }, 10, 50)
  self.handler:correct({ bearing = 90, distance = 50 }, 10, 50)
  luaunit.assertAlmostEquals(self:_lastTarget().z, 2100, 0.01)
end

function TestArtilleryCorrectionLoop:test_a_correction_is_announced_with_its_numbers()
  -- The player has to be able to check what the battery understood; a bare "firing" would hide a
  -- mistyped bearing until the shells land.
  self.handler:fireAtCoordinates({ x = 1000, y = 0, z = 2000 }, 10, 50)
  self.handler:correct({ bearing = 90, distance = 50 }, 10, 50)
  local message = self.messages[#self.messages]
  luaunit.assertNotNil(message:find("Sierra23", 1, true), "the battery, by the name the player used")
  luaunit.assertNotNil(message:find("090", 1, true), "the bearing, three digits: " .. message)
  luaunit.assertNotNil(message:find("50", 1, true), "the distance: " .. message)
end

function TestArtilleryCorrectionLoop:test_a_correction_with_no_numbers_uses_the_ranging_defaults()
  -- `order correct; correction 09050` gives neither `shells` nor `radius`, which is the common case.
  -- Passing the nils straight through queued an order with no round count at all; the two firing verbs
  -- both apply their defaults first, so this one must too.
  self.handler:fireAtCoordinates({ x = 1000, y = 0, z = 2000 }, 40, 100)
  self.handler:correct({ bearing = 90, distance = 50 })
  local order = self.orders[#self.orders]
  luaunit.assertEquals(order.parameters.shells, ArtilleryUnitHandler.FIREFORAIM_SHELLS)
  luaunit.assertEquals(order.parameters.radius, ArtilleryUnitHandler.FIREFORAIM_RADIUS)
end

-- ── refusals ────────────────────────────────────────────────────────────────

function TestArtilleryCorrectionLoop:test_correcting_with_no_mission_refuses_and_says_so()
  -- Firing at the offset alone would put shells wherever the battery happens to stand.
  self.handler:correct({ bearing = 90, distance = 50 }, 10, 50)
  luaunit.assertEquals(#self.orders, 0, "nothing may be fired")
  luaunit.assertEquals(#self.messages, 1, "and the player must be told why")
end

function TestArtilleryCorrectionLoop:test_an_unreadable_correction_refuses_and_says_so()
  self.handler:fireAtCoordinates({ x = 1000, y = 0, z = 2000 }, 10, 50)
  local before = #self.orders
  self.handler:correct(nil, 10, 50)
  luaunit.assertEquals(#self.orders, before, "nothing may be fired")
  luaunit.assertNotNil(self.messages[#self.messages]:find("09050", 1, true), "the message must show the form")
end

function TestArtilleryCorrectionLoop:test_a_refusal_does_not_move_the_aim_point()
  -- A refused correction that shifted the state anyway would silently poison the next one.
  self.handler:fireAtCoordinates({ x = 1000, y = 0, z = 2000 }, 10, 50)
  self.handler:correct(nil, 10, 50)
  luaunit.assertEquals(self.handler.lastAimPoint.z, 2000)
end

function TestArtilleryCorrectionLoop:test_silent_means_silent_but_still_fires()
  self.handler.silent = true
  self.handler:fireAtCoordinates({ x = 1000, y = 0, z = 2000 }, 10, 50)
  self.handler:correct({ bearing = 90, distance = 50 }, 10, 50)
  luaunit.assertEquals(#self.messages, 0)
  luaunit.assertAlmostEquals(self:_lastTarget().z, 2050, 0.01)
end

-- ── the order text ──────────────────────────────────────────────────────────

TestArtilleryOrderParsing = {}

function TestArtilleryOrderParsing:_analyse(text)
  return veaf.parseMarkerText(text, ArtilleryUnitHandler.OrderSpec)
end

function TestArtilleryOrderParsing:test_the_correct_verb_is_recognised()
  local options = self:_analyse("correct; correction 09050")
  luaunit.assertNotNil(options)
  luaunit.assertEquals(options.verb, ArtilleryUnitHandler.VERB_CORRECT)
  luaunit.assertEquals(options.correction.bearing, 90)
end

function TestArtilleryOrderParsing:test_it_splits_on_semicolons_not_commas()
  -- This is the only parser in the codebase that splits on ";", which the spec's own comment records.
  -- A comma-separated order must therefore NOT parse into a correction.
  local options = self:_analyse("correct, correction 09050")
  luaunit.assertTrue(options == nil or options.correction == nil, "commas must not work here")
end

function TestArtilleryOrderParsing:test_the_new_verb_does_not_swallow_the_old_ones()
  -- The verbs are matched anywhere in the text and the chain's order decides, so adding one can quietly
  -- capture an existing order. Checked rather than assumed.
  luaunit.assertEquals(self:_analyse("aim; target 42N001E").verb, ArtilleryUnitHandler.VERB_FIRE_FORAIM)
  luaunit.assertEquals(self:_analyse("fire; target 42N001E").verb, ArtilleryUnitHandler.VERB_FIRE_FOREFFECT)
end

function TestArtilleryOrderParsing:test_an_unreadable_correction_reaches_the_handler_as_nil()
  -- Validated in the parameter rule, like `target` — the only other rule here that checks its own
  -- input — so a correction the parser cannot read never reaches a gun as a number.
  local options = self:_analyse("correct; correction east50")
  luaunit.assertNotNil(options)
  luaunit.assertNil(options.correction)
end

-- ===========================================================================
-- One remembered aim point, shared by the correction and by a bare `fire`
--
-- The doc has promised since long before this lot that "`fire` without a target fires again at the last
-- target aimed at", and only the *empty* case was tested. Unifying the two fields this class kept for
-- that idea is what exposed it: nothing pinned the populated path at all.
-- ===========================================================================
TestArtilleryRemembersOneAimPoint = {}

function TestArtilleryRemembersOneAimPoint:setUp()
  self.handler = ArtilleryUnitHandler:new()
  self.handler:setName("Sierra23")
  self.handler.silent = true
  self.orders = {}
  local test = self
  self.handler.addOrder = function(_, order)
    table.insert(test.orders, order)
  end
end

function TestArtilleryRemembersOneAimPoint:_lastFiredAt()
  return self.orders[#self.orders] and self.orders[#self.orders].parameters.target
end

function TestArtilleryRemembersOneAimPoint:test_fire_with_no_target_reuses_the_last_aim_point()
  -- The documented behaviour, tested at last with an actual previous target.
  --
  -- The order **count** is asserted, and that is not belt-and-braces: a first version of this test only
  -- read the last order, so when the fallback was removed the last order was still the aim order at the
  -- very same coordinates and the test passed. It asserted that a refusal looks like a success.
  self.handler:fireForAim({ x = 1000, y = 0, z = 2000 }, 2, 10)
  self.handler:fireForEffect(nil, 40, 100)
  luaunit.assertEquals(#self.orders, 2, "the effect mission must have been queued, not refused")
  local target = self:_lastFiredAt()
  luaunit.assertEquals(self.orders[2].parameters.shells, 40, "and it must be the effect order")
  luaunit.assertAlmostEquals(target.x, 1000, 0.01)
  luaunit.assertAlmostEquals(target.z, 2000, 0.01)
end

function TestArtilleryRemembersOneAimPoint:test_the_remembered_point_is_a_copy()
  -- The battery keeps its own copy of the point it was given. Aliasing the caller's table would let
  -- anything that reuses a vec3 move a fire mission after the fact, and the corrections chained from it.
  local point = { x = 1000, y = 0, z = 2000 }
  self.handler:fireForAim(point, 2, 10)
  point.z = 9999
  luaunit.assertAlmostEquals(self.handler.lastAimPoint.z, 2000, 0.01)
end

function TestArtilleryRemembersOneAimPoint:test_a_correction_then_a_bare_fire_agree()
  -- The point of one field rather than two: the effect lands where the correction put the aim, not at
  -- the point before it. Two fields would pass every other test in this file and fail exactly here.
  self.handler:fireForAim({ x = 1000, y = 0, z = 2000 }, 2, 10)
  self.handler:correct({ bearing = 90, distance = 50 }, 2, 10)
  self.handler:fireForEffect(nil, 40, 100)
  luaunit.assertAlmostEquals(self:_lastFiredAt().z, 2050, 0.01)
end

function TestArtilleryRemembersOneAimPoint:test_an_unreadable_target_leaves_the_aim_point_alone()
  -- A string of coordinates the module cannot read must not erase what the battery was aiming at, or a
  -- typo would silently disarm the next correction.
  self.handler:fireForAim({ x = 1000, y = 0, z = 2000 }, 2, 10)
  self.handler:fireForAim("not a coordinate", 2, 10)
  luaunit.assertAlmostEquals(self.handler.lastAimPoint.z, 2000, 0.01)
end

-- ===========================================================================
-- FIX-GROUNDAI-SILENT-REFUSALS — a command addressed to nobody must say so
--
-- Six verbs looked up a named autopilot with `if handler then … end` and no `else`, so a name nobody had
-- registered produced no action and no message — only a `trace` line, invisible at the default log level.
-- Reported in game as "ça ne fait rien (et rien dans le log)" after a mission reload had discarded the
-- autopilot created before it.
--
-- One test per verb, because the six were six separate pieces of code.
-- ===========================================================================
TestGroundAiUnknownHandler = {}

function TestGroundAiUnknownHandler:setUp()
  dcs_mocks.reset()
  self._outText = trigger.action.outText
  self.messages = {}
  local test = self
  trigger.action.outText = function(text)
    table.insert(test.messages, tostring(text))
  end
  -- No autopilots at all: every lookup below must miss.
  self._saved = veafGroundAI.handlers
  veafGroundAI.handlers = {}
end

function TestGroundAiUnknownHandler:tearDown()
  trigger.action.outText = self._outText
  veafGroundAI.handlers = self._saved
end

function TestGroundAiUnknownHandler:_say(text)
  self.messages = {}
  veafGroundAI.executeCommand({ x = 0, y = 0, z = 0 }, text, 2, 0)
  return table.concat(self.messages, " | ")
end

function TestGroundAiUnknownHandler:test_order_says_so()
  -- The case David hit.
  local said = self:_say("_ground order, name arty-1, order aim")
  luaunit.assertNotEquals(said, "", "an order to an unknown autopilot must be announced")
  luaunit.assertNotNil(said:find("arty-1", 1, true), "and must name it: " .. said)
end

function TestGroundAiUnknownHandler:test_the_message_says_how_to_create_one()
  -- "Unknown" without "here is what to do" sends a pilot back to the documentation mid-flight.
  local said = self:_say("_ground order, name arty-1, order aim")
  luaunit.assertNotNil(said:find("_ground set", 1, true), "expected the creating command: " .. said)
end

function TestGroundAiUnknownHandler:test_start_says_so()
  luaunit.assertNotEquals(self:_say("_ground start, name arty-1"), "")
end

function TestGroundAiUnknownHandler:test_stop_says_so()
  luaunit.assertNotEquals(self:_say("_ground stop, name arty-1"), "")
end

function TestGroundAiUnknownHandler:test_clear_says_so()
  luaunit.assertNotEquals(self:_say("_ground clear, name arty-1"), "")
end

function TestGroundAiUnknownHandler:test_unset_says_so()
  luaunit.assertNotEquals(self:_say("_ground unset, name arty-1"), "")
end

function TestGroundAiUnknownHandler:test_status_says_so()
  luaunit.assertNotEquals(self:_say("_ground status, name arty-1"), "")
end

function TestGroundAiUnknownHandler:test_set_without_a_group_nearby_says_so()
  -- A third silence, one level earlier than the other six: `set` and `unset` without a `groupname` take the
  -- nearest allied group within 250 m, and finding none aborted the whole command without a word. That is
  -- what a marker dropped a hundred metres too far from the battery looked like — nothing at all.
  local said = self:_say("_ground set, name arty-1")
  luaunit.assertNotEquals(said, "", "a marker with nothing near it must be answered")
  luaunit.assertNotNil(said:find("250", 1, true), "and must say what the range is: " .. said)
end

function TestGroundAiUnknownHandler:test_the_message_says_how_to_name_the_group_instead()
  local said = self:_say("_ground set, name arty-1")
  luaunit.assertNotNil(said:find("groupname", 1, true), "expected the alternative: " .. said)
end

-- ── an order nothing can be made of ─────────────────────────────────────────
-- One level below the six verbs: the autopilot exists, the order text does not parse. It used to return
-- nil in silence. A typo INSIDE a readable order was already reported by veaf.reportUnknownParameters;
-- this covers the text nothing could be made of, which is what a pilot produces when he guesses the
-- syntax.

function TestGroundAiUnknownHandler:test_an_unreadable_order_is_announced()
  local handler = ArtilleryUnitHandler:new():setName("arty-1")
  handler.silent = false
  handler.addOrder = function() end
  self.messages = {}
  handler:orderTextAnalysis("burn it all down")
  local said = table.concat(self.messages, " | ")
  luaunit.assertNotEquals(said, "", "an order nothing can be made of must be answered")
  luaunit.assertNotNil(said:find("arty-1", 1, true), "and must name the battery: " .. said)
end

function TestGroundAiUnknownHandler:test_the_unreadable_order_message_lists_the_verbs()
  -- A pilot who guessed wrong needs to know what to guess next.
  local handler = ArtilleryUnitHandler:new():setName("arty-1")
  handler.silent = false
  handler.addOrder = function() end
  self.messages = {}
  handler:orderTextAnalysis("burn it all down")
  local said = table.concat(self.messages, " | ")
  luaunit.assertNotNil(said:find("aim", 1, true), "expected the valid orders: " .. said)
  luaunit.assertNotNil(said:find("correct", 1, true), "expected the valid orders: " .. said)
end

function TestGroundAiUnknownHandler:test_a_silent_battery_stays_silent_about_it()
  -- `silent` means a script asked, and a script does not read messages.
  local handler = ArtilleryUnitHandler:new():setName("arty-1")
  handler.silent = true
  handler.addOrder = function() end
  self.messages = {}
  handler:orderTextAnalysis("burn it all down")
  luaunit.assertEquals(#self.messages, 0)
end

function TestGroundAiUnknownHandler:test_a_known_autopilot_is_not_complained_about()
  -- The other side: the message must not fire when the autopilot does exist, or it becomes noise and the
  -- real complaint gets lost in it.
  local handler = ArtilleryUnitHandler:new():setName("arty-1")
  handler.silent = true
  veafGroundAI.add(handler)
  local said = self:_say("_ground status, name arty-1")
  luaunit.assertNil(said:find("_ground set", 1, true), "no complaint expected, got: " .. said)
end

-- ===========================================================================
-- FEAT-GC-MARKER-SYNTAX — `_gc <nom>, <verbe> <valeur>, <paramètres>`
--
-- Le destinataire d'abord, comme à la radio, et une seule virgule partout. L'ancienne forme
-- (`_ground order, name X, order aim; target Y`) reste acceptée sans être documentée, et une partie de
-- ces tests existe pour qu'on s'aperçoive si on la casse.
--
-- Le point-virgule n'était pas un choix de style : le parseur découpe sur les virgules, donc la valeur
-- de `order` s'arrêtait à la virgule suivante. Ce qui le rend inutile, c'est que le marqueur connaisse
-- lui-même les mots de l'ordre — ce que ces tests vérifient mot par mot.
-- ===========================================================================
TestGcMarkerSyntax = {}

function TestGcMarkerSyntax:_read(text)
  return veaf.parseMarkerText(text, veafGroundAI.MarkerSpec)
end

-- ── le nom, en première position ────────────────────────────────────────────

function TestGcMarkerSyntax:test_the_name_comes_first_without_a_keyword()
  local o = self:_read("_gc arty-1, status")
  luaunit.assertNotNil(o, "_gc doit être reconnu")
  luaunit.assertEquals(o.name, "arty-1")
end

function TestGcMarkerSyntax:test_the_name_alone_means_set()
  -- Ce que la page promettait pour `_ground` seul sans que ce soit vrai : mesuré, `_ground, name X` est
  -- refusé. Avec `_gc`, la forme courte marche vraiment.
  local o = self:_read("_gc arty-1")
  luaunit.assertNotNil(o, "_gc seul doit être reconnu")
  luaunit.assertEquals(o.verb, veafGroundAI.VERB_SET)
  luaunit.assertEquals(o.name, "arty-1")
end

function TestGcMarkerSyntax:test_a_nameless_gc_is_refused()
  -- `name` est obligatoire pour les sept verbes, et la chaîne vide est piégeuse en Lua : `""` est vrai.
  luaunit.assertNil(self:_read("_gc"))
  luaunit.assertNil(self:_read("_gc , status"))
end

-- ── les verbes ──────────────────────────────────────────────────────────────

function TestGcMarkerSyntax:test_every_verb_is_recognised()
  local attendu = {
    set = veafGroundAI.VERB_SET,
    unset = veafGroundAI.VERB_UNSET,
    start = veafGroundAI.VERB_START,
    stop = veafGroundAI.VERB_STOP,
    clear = veafGroundAI.VERB_CLEAR,
    status = veafGroundAI.VERB_STATUS,
  }
  for mot, verbe in pairs(attendu) do
    local o = self:_read("_gc arty-1, " .. mot)
    luaunit.assertNotNil(o, "verbe refusé : " .. mot)
    luaunit.assertEquals(o.verb, verbe, "mauvais verbe pour " .. mot)
  end
end

function TestGcMarkerSyntax:test_an_order_verb_routes_to_the_order_path()
  for _, mot in ipairs({ "aim", "fire", "correction" }) do
    local o = self:_read("_gc arty-1, " .. mot)
    luaunit.assertNotNil(o, "verbe refusé : " .. mot)
    luaunit.assertEquals(o.verb, veafGroundAI.VERB_ORDER, mot .. " doit être un ordre")
  end
end

-- ── la valeur en ligne du verbe ─────────────────────────────────────────────

function TestGcMarkerSyntax:test_aim_carries_its_coordinates()
  -- LA raison d'être du lot : la grille se recopie telle que DCS l'affiche, espaces compris, sans
  -- mot-clé `target` ni point-virgule.
  local o = self:_read("_gc arty-1, aim 37T FH 73551 47565")
  luaunit.assertEquals(o.orderVerb, ArtilleryUnitHandler.VERB_FIRE_FORAIM)
  luaunit.assertEquals(o.target, "37T FH 73551 47565")
end

function TestGcMarkerSyntax:test_fire_carries_its_coordinates_too()
  local o = self:_read("_gc arty-1, fire 37T FH 73551 47565")
  luaunit.assertEquals(o.orderVerb, ArtilleryUnitHandler.VERB_FIRE_FOREFFECT)
  luaunit.assertEquals(o.target, "37T FH 73551 47565")
end

function TestGcMarkerSyntax:test_fire_without_coordinates_keeps_the_last_aim_point()
  -- `fire` sans cible retire au dernier point visé : la valeur absente doit rester absente, pas devenir
  -- une chaîne que le lecteur de coordonnées refuserait en se plaignant.
  local o = self:_read("_gc arty-1, fire")
  luaunit.assertEquals(o.orderVerb, ArtilleryUnitHandler.VERB_FIRE_FOREFFECT)
  luaunit.assertTrue(o.target == nil or o.target == "", "pas de cible attendue, reçu: " .. tostring(o.target))
end

function TestGcMarkerSyntax:test_correction_carries_its_value()
  local o = self:_read("_gc arty-1, correction 09050")
  luaunit.assertEquals(o.orderVerb, ArtilleryUnitHandler.VERB_CORRECT)
  luaunit.assertNotNil(o.correction, "la correction doit être lue")
  luaunit.assertEquals(o.correction.bearing, 90)
  luaunit.assertEquals(o.correction.distance, 50)
end

function TestGcMarkerSyntax:test_correct_is_accepted_as_well_as_correction()
  -- Deux orthographes plutôt qu'une à retenir sous le feu.
  local o = self:_read("_gc arty-1, correct 09050")
  luaunit.assertEquals(o.orderVerb, ArtilleryUnitHandler.VERB_CORRECT)
  luaunit.assertEquals(o.correction.bearing, 90)
end

function TestGcMarkerSyntax:test_an_unreadable_target_is_dropped_not_stored()
  -- La cible se valide a la lecture, comme la correction : une chaine que le lecteur de coordonnees ne
  -- sait pas lire ne doit jamais atteindre un canon. Sans ce test, retirer la validation passait tout.
  local o = self:_read("_gc arty-1, aim quelque part par la")
  luaunit.assertNotNil(o)
  luaunit.assertEquals(o.orderVerb, ArtilleryUnitHandler.VERB_FIRE_FORAIM, "le verbe reste lu")
  luaunit.assertNil(o.target, "mais la cible illisible est jetee")
end

function TestGcMarkerSyntax:test_an_unreadable_target_is_dropped_from_fire_too()
  local o = self:_read("_gc arty-1, fire nimporte quoi")
  luaunit.assertEquals(o.orderVerb, ArtilleryUnitHandler.VERB_FIRE_FOREFFECT)
  luaunit.assertNil(o.target)
end

function TestGcMarkerSyntax:test_an_unreadable_target_is_dropped_from_the_long_form_too()
  local o = self:_read("_gc arty-1, aim, target pas une grille")
  luaunit.assertNil(o.target)
end

function TestGcMarkerSyntax:test_an_unreadable_correction_is_dropped_not_stored()
  -- Comme `target`, la correction se valide à la lecture : un chiffre que le module ne sait pas lire ne
  -- doit jamais atteindre un canon.
  local o = self:_read("_gc arty-1, correction est50")
  luaunit.assertNotNil(o)
  luaunit.assertNil(o.correction)
end

-- ── les paramètres, séparés par des virgules ────────────────────────────────

function TestGcMarkerSyntax:test_the_parameters_use_commas()
  local o = self:_read("_gc arty-1, fire, shells 40-80, radius 50-150")
  luaunit.assertEquals(o.orderVerb, ArtilleryUnitHandler.VERB_FIRE_FOREFFECT)
  luaunit.assertNotNil(o.shells, "shells doit être lu")
  luaunit.assertNotNil(o.radius, "radius doit être lu")
end

function TestGcMarkerSyntax:test_target_still_works_as_a_long_form()
  local o = self:_read("_gc arty-1, aim, target 37T FH 73551 47565")
  luaunit.assertEquals(o.target, "37T FH 73551 47565")
end

function TestGcMarkerSyntax:test_groupname_still_works()
  local o = self:_read("_gc arty-1, set, groupname ARTY-1")
  luaunit.assertEquals(o.verb, veafGroundAI.VERB_SET)
end

function TestGcMarkerSyntax:test_a_misspelt_parameter_is_reported()
  -- Le refus des coquilles vaut aussi pour la forme neuve : c'est ce qui évite un marqueur qui ne fait
  -- rien parce qu'on a écrit `shels`.
  local o = self:_read("_gc arty-1, fire, shels 40")
  luaunit.assertNotNil(o)
  luaunit.assertNotNil(o.unknownParameters, "la coquille doit être signalée")
end

-- ── l'ancienne forme, qui doit survivre ─────────────────────────────────────
-- Non documentée, mais des missions au monde l'écrivent. Ces tests sont là pour qu'on s'en aperçoive.

function TestGcMarkerSyntax:test_the_old_ground_form_still_works()
  local o = self:_read("_ground order, name arty-1, order aim; target 37T FH 73551 47565")
  luaunit.assertNotNil(o, "_ground doit rester accepté")
  luaunit.assertEquals(o.verb, veafGroundAI.VERB_ORDER)
  luaunit.assertEquals(o.name, "arty-1")
  luaunit.assertEquals(o.order, "aim; target 37T FH 73551 47565")
end

function TestGcMarkerSyntax:test_the_old_ground_verbs_still_work()
  local paires = { { "set", veafGroundAI.VERB_SET }, { "stop", veafGroundAI.VERB_STOP }, { "status", veafGroundAI.VERB_STATUS } }
  for _, paire in ipairs(paires) do
    local o = self:_read("_ground " .. paire[1] .. ", name arty-1")
    luaunit.assertNotNil(o, "_ground " .. paire[1] .. " doit rester accepté")
    luaunit.assertEquals(o.verb, paire[2])
  end
end

function TestGcMarkerSyntax:test_a_group_named_with_gc_does_not_hijack_the_old_form()
  -- `_gc` est cherché comme un morceau de texte n'importe où : un groupe appelé `x_gcy` dans une
  -- ancienne commande ne doit pas la faire lire comme du `_gc`.
  local o = self:_read("_ground stop, name x_gcy")
  luaunit.assertNotNil(o)
  luaunit.assertEquals(o.verb, veafGroundAI.VERB_STOP)
  luaunit.assertEquals(o.name, "x_gcy")
end

-- ===========================================================================
-- FEAT-GC-MARKER-SYNTAX — de bout en bout
--
-- Les tests ci-dessus verifient ce que le PARSEUR comprend. Ceux-ci verifient que la batterie tire :
-- c'est une indirection de plus, et c'est exactement la ou les trous se cachaient trois fois hier.
-- ===========================================================================
TestGcEndToEnd = {}

function TestGcEndToEnd:setUp()
  dcs_mocks.reset()
  veaf.DO_NOT_EXPORT_JSON_FILES = true
  self._outText = trigger.action.outText
  self.messages = {}
  local test = self
  trigger.action.outText = function(text)
    table.insert(test.messages, tostring(text))
  end

  self._saved = veafGroundAI.handlers
  veafGroundAI.handlers = {}
  self.orders = {}
  self.handler = ArtilleryUnitHandler:new():setName("arty-1")
  self.handler.silent = false
  self.handler.addOrder = function(_, order)
    table.insert(test.orders, order)
  end
  veafGroundAI.add(self.handler)
end

function TestGcEndToEnd:tearDown()
  trigger.action.outText = self._outText
  veafGroundAI.handlers = self._saved
end

function TestGcEndToEnd:_marker(text)
  veafGroundAI.executeCommand({ x = 0, y = 0, z = 0 }, text, 2, 0)
  return self.orders[#self.orders]
end

function TestGcEndToEnd:test_aim_with_a_dcs_grid_fires()
  -- LA commande que David veut pouvoir taper : la grille recopiee de la carte F10, espaces compris.
  local order = self:_marker("_gc arty-1, aim 37T FH 73551 47565")
  luaunit.assertNotNil(order, "la batterie doit avoir recu un ordre")
  luaunit.assertNotNil(order.parameters.target, "avec une cible")
end

function TestGcEndToEnd:test_the_correction_shifts_the_aim_point()
  self:_marker("_gc arty-1, aim 37T FH 73551 47565")
  local avant = self.orders[#self.orders].parameters.target
  self:_marker("_gc arty-1, correction 09050")
  local apres = self.orders[#self.orders].parameters.target
  luaunit.assertNotNil(apres, "la correction doit faire tirer")
  luaunit.assertAlmostEquals(apres.z - avant.z, 50, 0.01, "50 m vers l'est")
  luaunit.assertAlmostEquals(apres.x - avant.x, 0, 0.01, "et rien vers le nord")
end

function TestGcEndToEnd:test_fire_uses_the_corrected_point()
  self:_marker("_gc arty-1, aim 37T FH 73551 47565")
  self:_marker("_gc arty-1, correction 09050")
  local corrige = self.orders[#self.orders].parameters.target
  self:_marker("_gc arty-1, fire")
  local efficacite = self.orders[#self.orders].parameters.target
  luaunit.assertAlmostEquals(efficacite.z, corrige.z, 0.01)
end

function TestGcEndToEnd:test_the_parameters_reach_the_order()
  local order = self:_marker("_gc arty-1, fire 37T FH 73551 47565, shells 40, radius 120")
  luaunit.assertEquals(order.parameters.shells, 40)
  luaunit.assertEquals(order.parameters.radius, 120)
end

function TestGcEndToEnd:test_an_unknown_battery_says_so()
  -- Le meme refus annonce que pour l'ancienne forme : la syntaxe neuve ne doit pas rouvrir le silence.
  self.messages = {}
  veafGroundAI.executeCommand({ x = 0, y = 0, z = 0 }, "_gc pas-la, status", 2, 0)
  local dit = table.concat(self.messages, " | ")
  luaunit.assertNotEquals(dit, "", "une batterie inconnue doit etre annoncee")
  luaunit.assertNotNil(dit:find("pas-la", 1, true), "et nommee : " .. dit)
end

function TestGcEndToEnd:test_the_old_form_still_fires()
  -- Non documentee, mais elle doit continuer de marcher de bout en bout, pas seulement de se lire.
  local order = self:_marker("_ground order, name arty-1, order aim; target 37T FH 73551 47565")
  luaunit.assertNotNil(order, "l'ancienne forme doit encore faire tirer")
  luaunit.assertNotNil(order.parameters.target)
end

function TestGcEndToEnd:test_status_answers()
  self.messages = {}
  self:_marker("_gc arty-1, status")
  luaunit.assertNotEquals(table.concat(self.messages, " | "), "", "status doit repondre quelque chose")
end

-- ===========================================================================
-- FEAT-GC-MARKER-SYNTAX — les alias livres produisent une commande lisible
--
-- C'est le chemin que la plupart des pilotes empruntent : personne ne tape `_gc arty-1, aim …` a la main
-- quand `-arty1_aim …` existe. Les reecrire sans verifier ce qu'ils produisent, c'est exactement le genre
-- de casse silencieuse que ce lot est cense supprimer.
--
-- On ne teste pas l'expansion elle-meme (c'est veafShortcuts) mais le fait que la commande obtenue soit
-- comprise par le parseur du marqueur, coordonnees collees derriere comme le pilote le fait.
-- ===========================================================================
TestGcShippedAliases = {}

function TestGcShippedAliases:_read(text)
  return veaf.parseMarkerText(text, veafGroundAI.MarkerSpec)
end

function TestGcShippedAliases:test_the_aim_alias_with_a_grid_appended()
  -- Ce que `-arty1_aim 37T FH 73551 47565` donne : le verbe est en dernier dans l'alias, donc la grille
  -- atterrit dessus.
  local o = self:_read("_gc arty-1, radius 15-30, aim 37T FH 73551 47565")
  luaunit.assertNotNil(o)
  luaunit.assertEquals(o.name, "arty-1")
  luaunit.assertEquals(o.orderVerb, ArtilleryUnitHandler.VERB_FIRE_FORAIM)
  luaunit.assertEquals(o.target, "37T FH 73551 47565")
  luaunit.assertNotNil(o.radius, "le radius de l'alias doit survivre")
end

function TestGcShippedAliases:test_the_fire_alias_with_a_grid_appended()
  local o = self:_read("_gc arty-1, radius 50-150, shells 40-80, fire 37T FH 73551 47565")
  luaunit.assertEquals(o.orderVerb, ArtilleryUnitHandler.VERB_FIRE_FOREFFECT)
  luaunit.assertEquals(o.target, "37T FH 73551 47565")
  luaunit.assertNotNil(o.shells)
  luaunit.assertNotNil(o.radius)
end

function TestGcShippedAliases:test_the_fire_alias_without_a_grid()
  -- `-arty1_fire` seul : tir d'efficacite au dernier point vise, sans coordonnees.
  local o = self:_read("_gc arty-1, radius 50-150, shells 40-80, fire")
  luaunit.assertEquals(o.orderVerb, ArtilleryUnitHandler.VERB_FIRE_FOREFFECT)
  luaunit.assertNil(o.target)
end

function TestGcShippedAliases:test_the_stop_and_start_aliases()
  luaunit.assertEquals(self:_read("_gc arty-1, stop").verb, veafGroundAI.VERB_STOP)
  luaunit.assertEquals(self:_read("_gc arty-1, start").verb, veafGroundAI.VERB_START)
end

function TestGcShippedAliases:test_the_ai_set_alias_with_a_name_appended()
  -- Ce que `-ai_set arty-1, groupname arty-1` donne, tel que le lot `-arty1` l'ecrit.
  local o = self:_read("_gc arty-1, groupname arty-1")
  luaunit.assertNotNil(o)
  luaunit.assertEquals(o.verb, veafGroundAI.VERB_SET)
  luaunit.assertEquals(o.name, "arty-1")
end

function TestGcShippedAliases:test_no_shipped_alias_still_writes_the_semicolon_form()
  -- Le point-virgule reste accepte, mais plus rien de ce qu'on livre ne l'ecrit. Ce test lit le module
  -- des alias plutot que de le supposer.
  local chemin = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") .. "/../../src/scripts/veaf/veafShortcuts.lua"
  local fichier = io.open(chemin, "r")
  luaunit.assertNotNil(fichier, "veafShortcuts.lua doit etre lisible depuis le test")
  local contenu = fichier:read("*a")
  fichier:close()
  luaunit.assertNil(contenu:find("_ground", 1, true), "aucun alias livre ne doit plus ecrire _ground")
end

os.exit(luaunit.LuaUnit.run())
