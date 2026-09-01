--- Tests for veafSanctuary.lua — VeafSanctuaryZone OOP and constants.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")
dofile(src .. "/veafMissionDb.lua")
dofile(src .. "/veafDcsSpawner.lua")
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

-- ---------------------------------------------------------------------------
-- FIX-SANCTUARY-SHIFTED-ALIAS-CALLS — what deployDefenses hands to ExecuteAlias
--
-- The eight calls in deployDefenses were written against a signature that gained a `delay` parameter in
-- second position on 2021-04-13, and were never updated. So a command string landed on `delay` and
-- `timer.getTime() + delay` raised — the defences never spawned.
--
-- What is asserted is the SHAPE of the handover, not the spawn: a misaligned call is invisible until it
-- runs, and every argument here is a plain value that no type check would catch.
-- ---------------------------------------------------------------------------
TestSanctuaryDeployDefensesHandover = {}

function TestSanctuaryDeployDefensesHandover:setUp()
  self.calls = {}
  self._shortcuts = veafShortcuts
  local test = self
  veafShortcuts = {
    ExecuteAlias = function(aliasName, delay, remainingCommand, position, eventCoalition, markId, bypassSecurity, spawnedGroups)
      table.insert(test.calls, {
        aliasName = aliasName,
        delay = delay,
        remainingCommand = remainingCommand,
        position = position,
        eventCoalition = eventCoalition,
        markId = markId,
        bypassSecurity = bypassSecurity,
        spawnedGroups = spawnedGroups,
      })
    end,
  }

  self.zone = VeafSanctuaryZone:new()
  self.zone:setName("Test Sanctuary")
  self.zone:setCoalition(2)

  -- `getPosition` is needed since `veaf.getHeading` became VEAF's own code (DROP-MIST ticket 06):
  -- the MiST stub answered a constant without looking at the unit, so this fake could get away with
  -- carrying velocity alone. `x` is the forward vector, pi/2 keeps the heading the stub used to give.
  self.unit = {
    getVelocity = function()
      return { x = 10, y = 0, z = 10 }
    end,
    getPosition = function()
      return { p = { x = 0, y = 0, z = 0 }, x = { x = math.cos(math.pi / 2), y = 0, z = math.sin(math.pi / 2) } }
    end,
  }
end

function TestSanctuaryDeployDefensesHandover:tearDown()
  veafShortcuts = self._shortcuts
end

--- @param surface number 2 or 3 is water, anything else is land
--- @param timeInZone number above HARDER_DEFENSES_AFTER a second wave is deployed
function TestSanctuaryDeployDefensesHandover:_deploy(surface, timeInZone)
  local origSurface = land.getSurfaceType
  land.getSurfaceType = function()
    return surface
  end
  self.zone:deployDefenses({ x = 1000, y = 0, z = 2000 }, self.unit, timeInZone)
  land.getSurfaceType = origSurface
  return self.calls
end

function TestSanctuaryDeployDefensesHandover:test_the_delay_is_never_a_command_string()
  -- THE defect, in one assertion. Before the fix every call carried "radius 2000, multiplier 2, …" here,
  -- and ExecuteAlias then computed `timer.getTime() + <that string>`.
  local calls = self:_deploy(2, 0)
  luaunit.assertTrue(#calls > 0, "deployDefenses must actually deploy something")
  for i, call in ipairs(calls) do
    luaunit.assertTrue(
      call.delay == nil or type(call.delay) == "number",
      string.format("call %d handed a %s as the delay: %s", i, type(call.delay), tostring(call.delay))
    )
  end
end

function TestSanctuaryDeployDefensesHandover:test_the_command_carries_the_spawn_parameters()
  -- The other half of the shift: what was landing on `delay` belongs on `remainingCommand`.
  local call = self:_deploy(2, 0)[1]
  luaunit.assertEquals(type(call.remainingCommand), "string")
  luaunit.assertNotNil(call.remainingCommand:find("radius", 1, true), "got: " .. tostring(call.remainingCommand))
end

function TestSanctuaryDeployDefensesHandover:test_the_position_is_a_point_not_a_coalition()
  local call = self:_deploy(2, 0)[1]
  luaunit.assertEquals(type(call.position), "table", "a vec3, not a coalition number")
  luaunit.assertNotNil(call.position.x)
end

function TestSanctuaryDeployDefensesHandover:test_the_coalition_reaches_the_coalition_parameter()
  luaunit.assertEquals(self:_deploy(2, 0)[1].eventCoalition, 2)
end

function TestSanctuaryDeployDefensesHandover:test_a_sanctuary_spawn_bypasses_security()
  -- A punishment is a script, not a pilot at a marker: it must not ask anybody for a password.
  luaunit.assertEquals(self:_deploy(2, 0)[1].bypassSecurity, true)
end

function TestSanctuaryDeployDefensesHandover:test_the_group_accumulator_reaches_its_parameter()
  -- It used to land on `bypassSecurity`, so the caller never got its group names back either.
  luaunit.assertEquals(type(self:_deploy(2, 0)[1].spawnedGroups), "table")
end

function TestSanctuaryDeployDefensesHandover:test_water_and_land_both_deploy()
  -- Two branches, four calls each once the harder wave triggers, and both were shifted identically.
  luaunit.assertEquals(#self:_deploy(2, 0), 2, "water, first wave")
  self.calls = {}
  luaunit.assertEquals(#self:_deploy(1, 0), 2, "land, first wave")
end

function TestSanctuaryDeployDefensesHandover:test_the_harder_wave_is_handed_over_correctly_too()
  -- Four more calls, in a separate block that was shifted the same way.
  local calls = self:_deploy(2, veafSanctuary.HARDER_DEFENSES_AFTER + 1)
  luaunit.assertEquals(#calls, 4)
  for i, call in ipairs(calls) do
    luaunit.assertTrue(call.delay == nil or type(call.delay) == "number", "call " .. i .. " has a bad delay")
  end
end

-- ── l'etalement d'une vague ─────────────────────────────────────────────────
-- Chaque vague pose DEUX pieces. Les trois autres blocs de `deployDefenses` les etalent : rayons 2000
-- puis 3000 (eau, premiere vague), 3000 puis 4000 (les deux vagues dures), et la seconde va toujours a
-- `positionIn40s`. La premiere vague TERRESTRE reposait deux fois au meme endroit avec le meme rayon,
-- seul le cap changeant. Copier-coller, confirme non voulu par David le 2026-08-25.
--
-- Le test porte sur la PROPRIETE — les deux pieces d'une vague diffèrent — et pas sur les valeurs : un
-- test qui verifie « 3000 » se contente de figer le chiffre du jour et ne dit rien de l'intention.

function TestSanctuaryDeployDefensesHandover:_deuxPieces(surface)
  local calls = self:_deploy(surface, 0)
  luaunit.assertEquals(#calls, 2, "une vague pose deux pieces")
  return calls[1], calls[2]
end

function TestSanctuaryDeployDefensesHandover:test_a_land_wave_spreads_its_two_pieces()
  local a, b = self:_deuxPieces(1)
  luaunit.assertNotEquals(a.remainingCommand, b.remainingCommand, "les deux pieces ne peuvent pas etre identiques")
  luaunit.assertNotEquals(a.position, b.position, "et elles ne se posent pas au meme endroit")
end

function TestSanctuaryDeployDefensesHandover:test_a_land_wave_widens_its_second_radius()
  -- Le rayon est l'etalement demande a l'alias : la seconde piece couvre plus large que la premiere.
  local a, b = self:_deuxPieces(1)
  local ra = tonumber(a.remainingCommand:match("radius (%d+)"))
  local rb = tonumber(b.remainingCommand:match("radius (%d+)"))
  luaunit.assertNotNil(ra, "la premiere piece doit demander un rayon : " .. tostring(a.remainingCommand))
  luaunit.assertNotNil(rb, "la seconde aussi : " .. tostring(b.remainingCommand))
  luaunit.assertTrue(rb > ra, string.format("la seconde doit s'etaler davantage (%s puis %s)", ra, rb))
end

function TestSanctuaryDeployDefensesHandover:test_a_water_wave_spreads_too()
  -- Le bloc qui etait deja juste : il garde le test, pour qu'on s'apercoive si on l'aligne par erreur
  -- sur le mauvais des deux.
  local a, b = self:_deuxPieces(2)
  local ra = tonumber(a.remainingCommand:match("radius (%d+)"))
  local rb = tonumber(b.remainingCommand:match("radius (%d+)"))
  luaunit.assertTrue(rb > ra, string.format("eau : %s puis %s", ra, rb))
  luaunit.assertNotEquals(a.position, b.position)
end

function TestSanctuaryDeployDefensesHandover:test_the_harder_wave_spreads_on_both_surfaces()
  for _, surface in ipairs({ 1, 2 }) do
    -- `_deploy` accumule dans `self.calls`, qui n'est vide qu'au setUp : sans ce reset la seconde
    -- surface voit les huit appels des deux.
    self.calls = {}
    local calls = self:_deploy(surface, veafSanctuary.HARDER_DEFENSES_AFTER + 1)
    luaunit.assertEquals(#calls, 4, "vague dure : quatre pieces au total")
    local ra = tonumber(calls[3].remainingCommand:match("radius (%d+)"))
    local rb = tonumber(calls[4].remainingCommand:match("radius (%d+)"))
    luaunit.assertTrue(rb > ra, string.format("surface %s : %s puis %s", surface, ra, rb))
    luaunit.assertNotEquals(calls[3].position, calls[4].position)
  end
end

-- ============================================================================
-- FIX-UNGUARDED-DCS-LOOKUPS -- a misnamed trigger zone crashed the set-up
--
-- `addZoneFromTriggerZone` asked DCS for the zone, then tested `triggerZoneName` -- the *parameter*,
-- which is truthy by then -- instead of the answer, and read `triggerZone.radius` under a
-- `---@diagnostic disable-next-line: need-check-nil`. The linter had found this exact line and was
-- told to be quiet. A trigger zone misspelled in mission.yaml therefore raised inside the mission
-- script instead of naming the zone nobody could find.
--
-- The mocks answer nil for a zone that was never registered with `dcs_mocks.addZone`, which is what
-- `trigger.misc.getZone` does in DCS.
-- ============================================================================
TestSanctuaryZoneFromMissingTriggerZone = {}

function TestSanctuaryZoneFromMissingTriggerZone:setUp()
  dcs_mocks.reset()
  veafSanctuary.zonesList = {}
  self._logger = veaf.loggers.get(veafSanctuary.Id)
  self._originalWarn = self._logger.warn
  self.warned = {}
  local warned = self.warned
  self._logger.warn = function(_, text, ...)
    table.insert(warned, tostring(text))
  end
end

function TestSanctuaryZoneFromMissingTriggerZone:tearDown()
  self._logger.warn = self._originalWarn
  veafSanctuary.zonesList = {}
  dcs_mocks.reset()
end

--- Does any captured warning contain this text?
local function _warningMentions(warnings, text)
  for _, warning in ipairs(warnings) do
    if warning:find(text, 1, true) then
      return true
    end
  end
  return false
end

-- The defect itself. Without the fix this raises on `triggerZone.radius`.
function TestSanctuaryZoneFromMissingTriggerZone:test_a_zone_dcs_does_not_know_does_not_raise()
  local ok, err = pcall(veafSanctuary.addZoneFromTriggerZone, "NO-SUCH-ZONE")
  luaunit.assertTrue(ok, string.format("addZoneFromTriggerZone raised on an unknown zone: %s", tostring(err)))
end

function TestSanctuaryZoneFromMissingTriggerZone:test_a_zone_dcs_does_not_know_adds_nothing()
  luaunit.assertNil(veafSanctuary.addZoneFromTriggerZone("NO-SUCH-ZONE"))
  luaunit.assertEquals(#veafSanctuary.zonesList, 0)
end

-- A warning that does not name the zone is one no mission maker can act on: the whole point is to
-- tell them which name in their mission.yaml has no zone behind it.
function TestSanctuaryZoneFromMissingTriggerZone:test_the_warning_names_the_zone()
  veafSanctuary.addZoneFromTriggerZone("NO-SUCH-ZONE")
  luaunit.assertTrue(_warningMentions(self.warned, "NO-SUCH-ZONE"), "the warning must name the missing trigger zone")
end

-- ...and the ordinary path is untouched: a registered zone still becomes a sanctuary zone carrying
-- the trigger zone's radius and centre.
function TestSanctuaryZoneFromMissingTriggerZone:test_a_zone_dcs_knows_is_still_added()
  dcs_mocks.addZone("SANCTUARY-KUTAISI", 1000, 2000, 7500)
  local zone = veafSanctuary.addZoneFromTriggerZone("SANCTUARY-KUTAISI")
  luaunit.assertNotNil(zone)
  luaunit.assertEquals(zone:getName(), "SANCTUARY-KUTAISI")
  luaunit.assertEquals(zone:getRadius(), 7500)
  luaunit.assertEquals(#veafSanctuary.zonesList, 1)
  luaunit.assertEquals(#self.warned, 0)
end

os.exit(luaunit.LuaUnit.run())
