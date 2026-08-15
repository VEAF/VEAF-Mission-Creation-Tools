--- Tests for veafSanctuary.lua — VeafSanctuaryZone OOP and constants.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafSanctuary.lua")

-- Stub VeafDrawingOnMap (accessed at setPolygonFromUnits entry, before any guard)
if not VeafDrawingOnMap then
  VeafDrawingOnMap = { LINE_TYPE = { twodashes = 1 } }
end

-- ---------------------------------------------------------------------------
-- TestVeafSanctuaryConstants
-- ---------------------------------------------------------------------------
TestVeafSanctuaryConstants = {}

function TestVeafSanctuaryConstants:test_id()
  luaunit.assertEquals(veafSanctuary.Id, "SANCTUARY")
end

function TestVeafSanctuaryConstants:test_default_delay_warning()
  luaunit.assertEquals(veafSanctuary.DEFAULT_DELAY_WARNING, 0)
end

function TestVeafSanctuaryConstants:test_default_delay_instant()
  luaunit.assertEquals(veafSanctuary.DEFAULT_DELAY_INSTANT, -1)
end

function TestVeafSanctuaryConstants:test_default_delay_spawn()
  luaunit.assertEquals(veafSanctuary.DEFAULT_DELAY_SPAWN, -1)
end

-- ---------------------------------------------------------------------------
-- TestVeafSanctuaryZoneOOP
-- ---------------------------------------------------------------------------
TestVeafSanctuaryZoneOOP = {}

function TestVeafSanctuaryZoneOOP:test_new_returns_table()
  local s = VeafSanctuaryZone:new()
  luaunit.assertIsTable(s)
end

function TestVeafSanctuaryZoneOOP:test_setName_getName()
  local s = VeafSanctuaryZone:new()
  s:setName("safezone1")
  luaunit.assertEquals(s:getName(), "safezone1")
end

function TestVeafSanctuaryZoneOOP:test_setRadius_getRadius()
  local s = VeafSanctuaryZone:new()
  s:setRadius(5000)
  luaunit.assertEquals(s:getRadius(), 5000)
end

function TestVeafSanctuaryZoneOOP:test_setCoalition_getCoalition()
  local s = VeafSanctuaryZone:new()
  s:setCoalition(2) -- BLUE
  luaunit.assertEquals(s:getCoalition(), 2)
end

function TestVeafSanctuaryZoneOOP:test_setDelayWarning_getDelayWarning()
  local s = VeafSanctuaryZone:new()
  s:setDelayWarning(10)
  luaunit.assertEquals(s:getDelayWarning(), 10)
end

function TestVeafSanctuaryZoneOOP:test_setDelayInstant_getDelayInstant()
  local s = VeafSanctuaryZone:new()
  s:setDelayInstant(5)
  luaunit.assertEquals(s:getDelayInstant(), 5)
end

function TestVeafSanctuaryZoneOOP:test_setDelaySpawn_getDelaySpawn()
  local s = VeafSanctuaryZone:new()
  s:setDelaySpawn(30)
  luaunit.assertEquals(s:getDelaySpawn(), 30)
end

function TestVeafSanctuaryZoneOOP:test_setMessageWarning_getMessageWarning()
  local s = VeafSanctuaryZone:new()
  s:setMessageWarning("Warning: you are entering a sanctuary zone!")
  luaunit.assertEquals(s:getMessageWarning(), "Warning: you are entering a sanctuary zone!")
end

function TestVeafSanctuaryZoneOOP:test_setMessageSpawn_getMessageSpawn()
  local s = VeafSanctuaryZone:new()
  s:setMessageSpawn("Defence spawned!")
  luaunit.assertEquals(s:getMessageSpawn(), "Defence spawned!")
end

function TestVeafSanctuaryZoneOOP:test_setMessageShotTarget_getMessageShotTarget()
  local s = VeafSanctuaryZone:new()
  s:setMessageShotTarget("You were targeted in a sanctuary!")
  luaunit.assertEquals(s:getMessageShotTarget(), "You were targeted in a sanctuary!")
end

function TestVeafSanctuaryZoneOOP:test_setMessageShotLauncher_getMessageShotLauncher()
  local s = VeafSanctuaryZone:new()
  s:setMessageShotLauncher("You fired in a sanctuary!")
  luaunit.assertEquals(s:getMessageShotLauncher(), "You fired in a sanctuary!")
end

function TestVeafSanctuaryZoneOOP:test_setOffensesBeforeDestruction_getOffensesBeforeDestruction()
  local s = VeafSanctuaryZone:new()
  s:setOffensesBeforeDestruction(3)
  luaunit.assertEquals(s:getOffensesBeforeDestruction(), 3)
end

function TestVeafSanctuaryZoneOOP:test_spawnedGroups_initially_empty()
  local s = VeafSanctuaryZone:new()
  local sg = s:getSpawnedGroups()
  luaunit.assertIsTable(sg)
end

function TestVeafSanctuaryZoneOOP:test_addSpawnedGroups()
  local s = VeafSanctuaryZone:new()
  -- addSpawnedGroups takes a table of group name strings
  s:addSpawnedGroups({ "group1", "group2" })
  local sg = s:getSpawnedGroups()
  luaunit.assertIsTable(sg)
  luaunit.assertNotNil(sg["group1"])
  luaunit.assertNotNil(sg["group2"])
end

-- ============================================================================
-- TestVeafSanctuaryRecord
-- ============================================================================
TestVeafSanctuaryRecord = {}

function TestVeafSanctuaryRecord:setUp()
  veafSanctuary.RecordAction = false
  veafSanctuary.RecordTrace = false
  veafSanctuary.RecordTraceShooting = false
  veafSanctuary.RecordTraceTrespassing = false
end

function TestVeafSanctuaryRecord:test_recordAction_nil_message()
  -- nil message → outer "if message then" is false → no-op
  veafSanctuary.recordAction(nil)
  luaunit.assertTrue(true)
end

function TestVeafSanctuaryRecord:test_recordAction_message_record_disabled()
  -- RecordAction=false → _recordAction is a no-op
  veafSanctuary.recordAction("test message")
  luaunit.assertTrue(true)
end

function TestVeafSanctuaryRecord:test_recordTrace_disabled()
  veafSanctuary.recordTrace("trace msg")
  luaunit.assertTrue(true)
end

function TestVeafSanctuaryRecord:test_recordTrace_enabled()
  veafSanctuary.RecordTrace = true
  -- RecordAction=false means _recordAction is still a no-op
  veafSanctuary.recordTrace("trace msg enabled")
  luaunit.assertTrue(true)
end

function TestVeafSanctuaryRecord:test_recordTraceShooting_disabled()
  veafSanctuary.recordTraceShooting("shot msg")
  luaunit.assertTrue(true)
end

function TestVeafSanctuaryRecord:test_recordTraceShooting_enabled()
  veafSanctuary.RecordTraceShooting = true
  veafSanctuary.recordTraceShooting("shot msg enabled")
  luaunit.assertTrue(true)
end

function TestVeafSanctuaryRecord:test_recordTraceTrespassing_disabled()
  veafSanctuary.recordTraceTrespassing("trespass msg")
  luaunit.assertTrue(true)
end

function TestVeafSanctuaryRecord:test_recordTraceTrespassing_enabled()
  veafSanctuary.RecordTraceTrespassing = true
  veafSanctuary.recordTraceTrespassing("trespass msg enabled")
  luaunit.assertTrue(true)
end

function TestVeafSanctuaryRecord:test_recordAction_record_enabled()
  -- stub writeLineToTextFile to avoid real I/O
  local origWrite = veaf.writeLineToTextFile
  veaf.writeLineToTextFile = function() end
  veafSanctuary.RecordAction = true
  veafSanctuary.recordAction("enabled record test")
  veafSanctuary.RecordAction = false
  veaf.writeLineToTextFile = origWrite
  luaunit.assertTrue(true)
end

-- ============================================================================
-- TestVeafSanctuaryZoneExtra
-- ============================================================================
TestVeafSanctuaryZoneExtra = {}

function TestVeafSanctuaryZoneExtra:test_setProtectFromMissiles()
  local s = VeafSanctuaryZone:new()
  s:setProtectFromMissiles()
  luaunit.assertTrue(s.protectFromMissiles)
end

function TestVeafSanctuaryZoneExtra:test_setPosition_getPosition()
  local s = VeafSanctuaryZone:new()
  local pos = { x = 100, y = 0, z = 200 }
  s:setPosition(pos)
  luaunit.assertEquals(s:getPosition(), pos)
end

function TestVeafSanctuaryZoneExtra:test_setPolygon_getPolygon()
  local s = VeafSanctuaryZone:new()
  local poly = { { x = 0, y = 0, z = 0 } }
  s:setPolygon(poly)
  luaunit.assertEquals(s:getPolygon(), poly)
end

function TestVeafSanctuaryZoneExtra:test_forgive_sets_offenses_to_zero()
  local s = VeafSanctuaryZone:new()
  s.offensesByOffender["Pilot1"] = 3
  s:forgive("Pilot1")
  luaunit.assertEquals(s.offensesByOffender["Pilot1"], 0)
end

function TestVeafSanctuaryZoneExtra:test_isPositionInZone_circle_inside()
  local s = VeafSanctuaryZone:new()
  s:setPosition({ x = 0, y = 0, z = 0 }):setRadius(1000)
  luaunit.assertTrue(s:isPositionInZone({ x = 100, y = 0, z = 100 }))
end

function TestVeafSanctuaryZoneExtra:test_isPositionInZone_circle_outside()
  local s = VeafSanctuaryZone:new()
  s:setPosition({ x = 0, y = 0, z = 0 }):setRadius(10)
  luaunit.assertFalse(s:isPositionInZone({ x = 5000, y = 0, z = 5000 }))
end

function TestVeafSanctuaryZoneExtra:test_isPositionInZone_no_position()
  -- no polygon, no position → inZone stays false
  local s = VeafSanctuaryZone:new()
  luaunit.assertFalse(s:isPositionInZone({ x = 0, y = 0, z = 0 }))
end

function TestVeafSanctuaryZoneExtra:test_setPolygonFromUnitsInSequence_no_units()
  -- unitNamePrefix with no matching units → veaf.getPolygonFromUnits returns nil/empty → no crash
  local s = VeafSanctuaryZone:new():setName("TestZone")
  s:setPolygonFromUnitsInSequence("nonexistent-prefix-xyz", false)
  luaunit.assertTrue(true)
end

-- ============================================================================
-- TestVeafSanctuaryModule
-- ============================================================================
TestVeafSanctuaryModule = {}

function TestVeafSanctuaryModule:setUp()
  veafSanctuary.RecordAction = false
  veafSanctuary.zonesList = {}
  veafSanctuary.humanUnitsToFollow = {}
  veafSanctuary.initialized = false
end

function TestVeafSanctuaryModule:test_addZone_inserts_into_list()
  local z = VeafSanctuaryZone:new():setName("Zone1")
  veafSanctuary.addZone(z)
  luaunit.assertEquals(#veafSanctuary.zonesList, 1)
end

function TestVeafSanctuaryModule:test_initialize_sets_initialized()
  veafSanctuary.initialize()
  luaunit.assertTrue(veafSanctuary.initialized)
end

function TestVeafSanctuaryModule:test_eventHandler_nil_event()
  veafSanctuary.eventHandler:onEvent(nil)
  luaunit.assertTrue(true)
end

function TestVeafSanctuaryModule:test_eventHandler_nil_id()
  veafSanctuary.eventHandler:onEvent({ id = nil })
  luaunit.assertTrue(true)
end

function TestVeafSanctuaryModule:test_eventHandler_irrelevant_id()
  veafSanctuary.eventHandler:onEvent({ id = 999 })
  luaunit.assertTrue(true)
end

function TestVeafSanctuaryModule:test_eventHandler_shot_nil_weapon()
  -- S_EVENT_SHOT with no weapon and empty zonesList → loops over nothing
  veafSanctuary.eventHandler:onEvent({ id = world.event.S_EVENT_SHOT, weapon = nil })
  luaunit.assertTrue(true)
end

-------------------------------------------------------------------------------------------------
-- SECREV-2 / VMR-094 — operator precedence in the event filter
--
-- `A or B and C and D` parses as `A or (B and C and D)`, so PLAYER_ENTER_UNIT / PLAYER_LEAVE_UNIT
-- skipped the `_unitname` check entirely and the handler registered under the key `""`.
--
-- The finding's remedy — parenthesise as `(A or B) and C and D` — would have been a regression:
-- `humanUnits` is filled once at initialize() from `mist.DBs.humansByName`, so a **dynamic slot**
-- is not in it, and requiring the lookup on PLAYER_ENTER_UNIT would stop Sanctuary from
-- following those players at all. What the two branches actually need is different: ENTER/LEAVE
-- concerns a human by definition and only needs a unit name; BIRTH/DEAD fires for AI too and
-- does need the lookup.
-------------------------------------------------------------------------------------------------

TestSecrev2SanctuaryEventFilter = {}

function TestSecrev2SanctuaryEventFilter:setUp()
  self._savedHumanUnits = veafSanctuary.humanUnits
  self._savedToFollow = veafSanctuary.humanUnitsToFollow
  veafSanctuary.humanUnits = { ["known-human"] = true }
  veafSanctuary.humanUnitsToFollow = {}
end

function TestSecrev2SanctuaryEventFilter:tearDown()
  veafSanctuary.humanUnits = self._savedHumanUnits
  veafSanctuary.humanUnitsToFollow = self._savedToFollow
end

local function _unitEvent(eventId, unitName)
  local initiator = nil
  if unitName then
    initiator = {
      getName = function()
        return unitName
      end,
    }
  else
    -- An initiator that has no getName: what DCS hands over for some objects.
    initiator = {}
  end
  return { id = eventId, initiator = initiator }
end

function TestSecrev2SanctuaryEventFilter:test_entering_a_known_slot_is_followed()
  veafSanctuary.eventHandler:onEvent(_unitEvent(world.event.S_EVENT_PLAYER_ENTER_UNIT, "known-human"))
  luaunit.assertNotNil(veafSanctuary.humanUnitsToFollow["known-human"])
end

function TestSecrev2SanctuaryEventFilter:test_entering_a_dynamic_slot_is_still_followed()
  -- Not in humanUnits, because dynamic slots do not exist when initialize() reads mist's DB.
  -- This is the case the finding's own remedy would have broken.
  veafSanctuary.eventHandler:onEvent(_unitEvent(world.event.S_EVENT_PLAYER_ENTER_UNIT, "dynamic-slot"))
  luaunit.assertNotNil(veafSanctuary.humanUnitsToFollow["dynamic-slot"])
end

function TestSecrev2SanctuaryEventFilter:test_a_nameless_initiator_registers_nothing()
  veafSanctuary.eventHandler:onEvent(_unitEvent(world.event.S_EVENT_PLAYER_ENTER_UNIT, nil))
  luaunit.assertNil(veafSanctuary.humanUnitsToFollow[""])
  luaunit.assertEquals(next(veafSanctuary.humanUnitsToFollow), nil)
end

function TestSecrev2SanctuaryEventFilter:test_birth_of_an_ai_unit_is_not_followed()
  veafSanctuary.eventHandler:onEvent(_unitEvent(world.event.S_EVENT_BIRTH, "some-ai-tank"))
  luaunit.assertNil(veafSanctuary.humanUnitsToFollow["some-ai-tank"])
end

function TestSecrev2SanctuaryEventFilter:test_birth_of_a_known_human_is_followed()
  veafSanctuary.eventHandler:onEvent(_unitEvent(world.event.S_EVENT_BIRTH, "known-human"))
  luaunit.assertNotNil(veafSanctuary.humanUnitsToFollow["known-human"])
end

function TestSecrev2SanctuaryEventFilter:test_leaving_stops_the_follow()
  veafSanctuary.humanUnitsToFollow["known-human"] = { firstInZone = -1 }
  veafSanctuary.eventHandler:onEvent(_unitEvent(world.event.S_EVENT_PLAYER_LEAVE_UNIT, "known-human"))
  luaunit.assertNil(veafSanctuary.humanUnitsToFollow["known-human"])
end

function TestSecrev2SanctuaryEventFilter:test_leaving_a_dynamic_slot_stops_the_follow()
  veafSanctuary.humanUnitsToFollow["dynamic-slot"] = { firstInZone = -1 }
  veafSanctuary.eventHandler:onEvent(_unitEvent(world.event.S_EVENT_PLAYER_LEAVE_UNIT, "dynamic-slot"))
  luaunit.assertNil(veafSanctuary.humanUnitsToFollow["dynamic-slot"])
end

function TestSecrev2SanctuaryEventFilter:test_death_of_an_ai_unit_leaves_the_list_alone()
  veafSanctuary.humanUnitsToFollow["known-human"] = { firstInZone = -1 }
  veafSanctuary.eventHandler:onEvent(_unitEvent(world.event.S_EVENT_DEAD, "some-ai-tank"))
  luaunit.assertNotNil(veafSanctuary.humanUnitsToFollow["known-human"])
end

os.exit(luaunit.LuaUnit.run())
