--- Tests for the destroyed-scenery register — DROP-MIST ticket 09.
--
-- What this replaces: `mist.getDeadMapObjsInZones`, the last MiST call in `veafCombatMission`. MiST
-- kept its own `DBs.deadObjects`, filled by its own S_EVENT_DEAD handler, and filtered it down to
-- `objectType == "building"` inside the named trigger zones.
--
-- Two facts here come from the game, not from a guess (measured 2026-08-28, see the memory note
-- `scenery-death-events-in-dcs`):
--
--  * DCS leaves `event.pos` **nil** on a scenery death, so the position can only come from the object
--    itself, at the moment of the event. That is why `veafEventHandler` now carries `dcsInitiator`.
--  * `Object.isExist` is already **false** on that event while `Object.getPosition` still answers.
--    MiST guarded on `isExist` and therefore recorded nothing for a scripted destruction; the register
--    deliberately does not.
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
dofile(src .. "/veafEventHandler.lua")

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- A scenery object as DCS hands it to an event handler: its name *is* its id, as a number.
local function _scenery(id, x, z)
  return {
    id_ = id,
    _category = Object.Category.SCENERY,
    _point = { x = x, y = 0, z = z },
    getName = function()
      return id
    end,
    getCategory = function(self)
      return self._category
    end,
  }
end

--- The event a `veafEventHandler` callback receives for that object's destruction.
local function _deathOf(object)
  return { type = { name = "S_EVENT_DEAD" }, dcsInitiator = object, initiator = { unitName = object.id_ } }
end

-- ---------------------------------------------------------------------------
-- TestVeafMissionDbSceneryRegister
-- ---------------------------------------------------------------------------
TestVeafMissionDbSceneryRegister = {}

function TestVeafMissionDbSceneryRegister:setUp()
  dcs_mocks.reset()
  veafMissionDb.destroyedScenery = {}
end

function TestVeafMissionDbSceneryRegister:test_an_object_destroyed_inside_the_zone_is_returned()
  dcs_mocks.addZone("Gudauta", 1000, 2000, 500)

  luaunit.assertTrue(veafMissionDb.recordDestroyedScenery(_deathOf(_scenery(156696667, 1100, 2100))))

  local found = veafMissionDb.getDestroyedSceneryInZones({ "Gudauta" })
  luaunit.assertEquals(#found, 1)
  luaunit.assertEquals(found[1].id, 156696667, "the id must be the number a mission maker writes")
end

function TestVeafMissionDbSceneryRegister:test_an_object_destroyed_outside_the_zone_is_not_returned()
  dcs_mocks.addZone("Gudauta", 1000, 2000, 500)

  -- 1000 m east of the centre of a 500 m zone.
  veafMissionDb.recordDestroyedScenery(_deathOf(_scenery(156696667, 2000, 2000)))

  luaunit.assertEquals(#veafMissionDb.getDestroyedSceneryInZones({ "Gudauta" }), 0)
end

function TestVeafMissionDbSceneryRegister:test_the_zone_edge_is_inside()
  -- Exactly on the radius. A building on the boundary of the zone a mission maker drew around it is
  -- the case they meant to cover, and a strict `<` would silently drop it.
  dcs_mocks.addZone("Gudauta", 0, 0, 500)

  veafMissionDb.recordDestroyedScenery(_deathOf(_scenery(1, 500, 0)))

  luaunit.assertEquals(#veafMissionDb.getDestroyedSceneryInZones({ "Gudauta" }), 1)
end

function TestVeafMissionDbSceneryRegister:test_an_object_destroyed_before_the_objective_is_configured_is_still_known()
  -- The register is filled by events, and read on demand. An objective configured after the fact must
  -- still see what was destroyed while it was not looking -- which is how MiST behaved, since its own
  -- table outlived any objective.
  dcs_mocks.addZone("Gudauta", 0, 0, 500)
  veafMissionDb.recordDestroyedScenery(_deathOf(_scenery(42, 100, 100)))

  local found = veafMissionDb.getDestroyedSceneryInZones({ "Gudauta" })

  luaunit.assertEquals(#found, 1)
  luaunit.assertEquals(found[1].id, 42)
end

function TestVeafMissionDbSceneryRegister:test_a_zone_that_does_not_exist_is_skipped_not_fatal()
  veafMissionDb.recordDestroyedScenery(_deathOf(_scenery(42, 100, 100)))

  local found = veafMissionDb.getDestroyedSceneryInZones({ "NoSuchZone" })

  luaunit.assertEquals(#found, 0, "an unknown zone name matches nothing, exactly as it did in MiST")
end

function TestVeafMissionDbSceneryRegister:test_several_zones_are_searched_and_an_object_counts_once()
  dcs_mocks.addZone("A", 0, 0, 500)
  dcs_mocks.addZone("B", 100, 0, 500) -- overlaps A
  veafMissionDb.recordDestroyedScenery(_deathOf(_scenery(7, 50, 0)))

  luaunit.assertEquals(#veafMissionDb.getDestroyedSceneryInZones({ "A", "B" }), 1, "an object in two zones is one object")
end

function TestVeafMissionDbSceneryRegister:test_a_unit_death_is_not_recorded()
  local unit = _scenery(99, 0, 0)
  unit._category = Object.Category.UNIT

  luaunit.assertFalse(veafMissionDb.recordDestroyedScenery(_deathOf(unit)))
  luaunit.assertNil(veafMissionDb.destroyedScenery[99])
end

function TestVeafMissionDbSceneryRegister:test_an_object_with_no_position_is_not_recorded()
  -- `Object.getPosition` returning nothing is the one case that has to be survivable: without a
  -- position the record could never be matched to a zone, and inventing one would be worse.
  local object = _scenery(99, 0, 0)
  object._point = nil

  luaunit.assertFalse(veafMissionDb.recordDestroyedScenery(_deathOf(object)))
end

function TestVeafMissionDbSceneryRegister:test_isExist_being_false_does_not_prevent_recording()
  -- The MiST defect this port fixes. Measured in game: on the DEAD event, isExist is already false
  -- while getPosition still answers. MiST's guard meant it recorded nothing at all.
  dcs_mocks.addZone("Gudauta", 0, 0, 500)
  local object = _scenery(156735615, 10, 10)
  object.isExist = function()
    return false
  end

  luaunit.assertTrue(veafMissionDb.recordDestroyedScenery(_deathOf(object)))
  luaunit.assertEquals(#veafMissionDb.getDestroyedSceneryInZones({ "Gudauta" }), 1)
end

function TestVeafMissionDbSceneryRegister:test_an_event_without_the_raw_object_is_survivable()
  luaunit.assertFalse(veafMissionDb.recordDestroyedScenery({ type = { name = "S_EVENT_DEAD" } }))
end

function TestVeafMissionDbSceneryRegister:test_the_same_object_destroyed_twice_is_one_entry()
  dcs_mocks.addZone("Gudauta", 0, 0, 500)
  veafMissionDb.recordDestroyedScenery(_deathOf(_scenery(5, 10, 10)))
  veafMissionDb.recordDestroyedScenery(_deathOf(_scenery(5, 10, 10)))

  luaunit.assertEquals(#veafMissionDb.getDestroyedSceneryInZones({ "Gudauta" }), 1)
end

function TestVeafMissionDbSceneryRegister:test_a_nil_zone_list_returns_nothing_rather_than_raising()
  veafMissionDb.recordDestroyedScenery(_deathOf(_scenery(5, 10, 10)))

  luaunit.assertEquals(#veafMissionDb.getDestroyedSceneryInZones(nil), 0)
end

-- ---------------------------------------------------------------------------
-- TestVeafMissionDbSceneryWiring — the subscription itself, not the handler
-- ---------------------------------------------------------------------------
-- Asserting the handler alone is what let four defects ship green on 2026-08-25: the tests called the
-- handler and never what registers it. See the memory note `assert-the-wiring-not-the-handler`.
TestVeafMissionDbSceneryWiring = {}

function TestVeafMissionDbSceneryWiring:setUp()
  dcs_mocks.reset()
  self._callbacks = veafEventHandler.callbacks
  veafEventHandler.callbacks = {}
  veafMissionDb.sceneryCallbackRegistered = false
end

function TestVeafMissionDbSceneryWiring:tearDown()
  veafEventHandler.callbacks = self._callbacks
end

local function _sceneryCallbacks()
  local found = {}
  for _, entry in pairs(veafEventHandler.callbacks) do
    if entry.name == "veafMissionDb.destroyedScenery" then
      found[#found + 1] = entry
    end
  end
  return found
end

function TestVeafMissionDbSceneryWiring:test_initialize_subscribes_the_register_to_the_event_bus()
  veafMissionDb.initialize()

  local found = _sceneryCallbacks()
  luaunit.assertEquals(#found, 1, "the register must be subscribed to S_EVENT_DEAD")
  luaunit.assertEquals(found[1].events[1], "S_EVENT_DEAD")
end

function TestVeafMissionDbSceneryWiring:test_initializing_twice_subscribes_once()
  -- initialize runs at load time and again on the module init pass. A callback registered twice would
  -- record every destruction twice -- the shape of the double event handler fixed in 6.17.0 (#824).
  veafMissionDb.initialize()
  veafMissionDb.initialize()

  luaunit.assertEquals(#_sceneryCallbacks(), 1, "the callback must not be registered twice")
end

function TestVeafMissionDbSceneryWiring:test_the_subscribed_callback_is_the_one_that_records()
  veafMissionDb.initialize()
  veafMissionDb.destroyedScenery = {}
  dcs_mocks.addZone("Gudauta", 0, 0, 500)

  _sceneryCallbacks()[1].call(_deathOf(_scenery(77, 10, 10)))

  luaunit.assertEquals(#veafMissionDb.getDestroyedSceneryInZones({ "Gudauta" }), 1)
end

os.exit(luaunit.LuaUnit.run())
