--- Tests for the geometry and zone queries ported off MiST — DROP-MIST ticket 06.
--
-- These four functions were MiST's until now: `getRandPointInCircle`, `getUnitsInZones`, `getHeading`
-- and `marker.drawZone`/`marker.remove`. What is asserted here is the behaviour the callers depended
-- on, not MiST's full surface — three of the five parameters of `getRandPointInCircle` had no caller
-- in the whole repository and are deliberately not ported.
--
-- The draws are deterministic: `dcs_mocks` makes `math.random` answer a controllable sequence, so the
-- point a circle yields can be reasoned about instead of merely being non-nil.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafScheduler.lua")
dofile(src .. "/veafMath.lua")
dofile(src .. "/veafGeo.lua")

-- ---------------------------------------------------------------------------
-- TestVeafGeoRandomPointInCircle
-- ---------------------------------------------------------------------------
TestVeafGeoRandomPointInCircle = {}

function TestVeafGeoRandomPointInCircle:setUp()
  dcs_mocks.reset()
end

function TestVeafGeoRandomPointInCircle:test_the_result_is_the_mission_table_shape()
  -- `y` is the easting, not an altitude. Callers hand the result to veaf.placePointOnLand, which
  -- reads it that way, and veafAirWaves converts it with `point.z = point.y`.
  local point = veafGeo.getRandomPointInCircle({ x = 100, y = 0, z = 200 }, 50)

  luaunit.assertNotNil(point.x)
  luaunit.assertNotNil(point.y)
  luaunit.assertNil(point.z, "a vec2 is returned, exactly as MiST returned one")
end

function TestVeafGeoRandomPointInCircle:test_a_zero_radius_returns_the_centre_itself()
  -- "Exactly here, the mission maker means it": veafSpawn passes radius 0 for a farp, a cargo, a
  -- teleport, a bomb and smoke.
  local point = veafGeo.getRandomPointInCircle({ x = 100, y = 0, z = 200 }, 0)

  luaunit.assertEquals(point.x, 100)
  luaunit.assertEquals(point.y, 200, "the centre's z becomes the result's y")
end

function TestVeafGeoRandomPointInCircle:test_a_nil_radius_is_treated_as_zero()
  local point = veafGeo.getRandomPointInCircle({ x = 100, y = 0, z = 200 }, nil)

  luaunit.assertEquals(point.x, 100)
  luaunit.assertEquals(point.y, 200)
end

function TestVeafGeoRandomPointInCircle:test_a_vec2_centre_is_accepted()
  -- A mission-table point has no z: its `y` is the easting, and makeVec3 moves it into place.
  local point = veafGeo.getRandomPointInCircle({ x = 100, y = 200 }, 0)

  luaunit.assertEquals(point.x, 100)
  luaunit.assertEquals(point.y, 200)
end

function TestVeafGeoRandomPointInCircle:test_the_draw_stays_within_the_radius()
  -- The extreme draw: angle and distance both at their maximum.
  dcs_mocks.setRandomSequence({ 0.999999 })
  local centre = { x = 0, y = 0, z = 0 }

  for _ = 1, 20 do
    local point = veafGeo.getRandomPointInCircle(centre, 100)
    local distance = math.sqrt(point.x * point.x + point.y * point.y)
    luaunit.assertTrue(distance <= 100.0001, "a drawn point must never fall outside the circle")
  end
end

function TestVeafGeoRandomPointInCircle:test_the_distance_uses_the_square_root_of_the_draw()
  -- Uniform over the *area*, not over the radius: at a draw of 0.25 the point sits at half the
  -- radius, not a quarter of it. A plain product would crowd points towards the centre.
  dcs_mocks.setRandomSequence({ 0, 0.25 })

  local point = veafGeo.getRandomPointInCircle({ x = 0, y = 0, z = 0 }, 100)

  -- First draw 0 sets the angle to 0, so the whole distance lands on x.
  luaunit.assertAlmostEquals(point.x, 50, 0.0001)
  luaunit.assertAlmostEquals(point.y, 0, 0.0001)
end

-- ---------------------------------------------------------------------------
-- TestVeafGeoUnitsInCircularZone
-- ---------------------------------------------------------------------------
TestVeafGeoUnitsInCircularZone = {}

function TestVeafGeoUnitsInCircularZone:setUp()
  dcs_mocks.reset()
  dcs_mocks.addZone("ZONE", 0, 0, 500)
end

--- A unit at a position, active unless told otherwise.
function TestVeafGeoUnitsInCircularZone:_unit(name, x, z, active)
  dcs_mocks.addUnit(name, {
    _category = Object.Category.UNIT,
    getPoint = function()
      return { x = x, y = 0, z = z }
    end,
    getPosition = function()
      return { p = { x = x, y = 0, z = z }, x = { x = 1, y = 0, z = 0 } }
    end,
    isActive = function()
      return active ~= false
    end,
  })
end

function TestVeafGeoUnitsInCircularZone:test_a_unit_inside_the_zone_is_returned()
  self:_unit("inside", 100, 100)

  local units = veafGeo.getUnitsInCircularZone({ "inside" }, "ZONE")

  luaunit.assertEquals(#units, 1)
end

function TestVeafGeoUnitsInCircularZone:test_a_unit_outside_the_zone_is_not()
  self:_unit("far", 1000, 0)

  luaunit.assertEquals(#veafGeo.getUnitsInCircularZone({ "far" }, "ZONE"), 0)
end

function TestVeafGeoUnitsInCircularZone:test_the_zone_edge_counts_as_inside()
  self:_unit("edge", 500, 0)

  luaunit.assertEquals(#veafGeo.getUnitsInCircularZone({ "edge" }, "ZONE"), 1, "a unit exactly on the radius is in the zone")
end

function TestVeafGeoUnitsInCircularZone:test_altitude_is_ignored()
  -- A DCS trigger zone is a cylinder: an aircraft overhead is inside it.
  dcs_mocks.addUnit("overhead", {
    _category = Object.Category.UNIT,
    getPoint = function()
      return { x = 10, y = 9000, z = 10 }
    end,
    getPosition = function()
      return { p = { x = 10, y = 9000, z = 10 }, x = { x = 1, y = 0, z = 0 } }
    end,
    isActive = function()
      return true
    end,
  })

  luaunit.assertEquals(#veafGeo.getUnitsInCircularZone({ "overhead" }, "ZONE"), 1)
end

function TestVeafGeoUnitsInCircularZone:test_an_inactive_unit_does_not_count_as_present()
  -- The same rule getUnitsInPolygon applies: a late-activated unit is not there yet.
  self:_unit("asleep", 100, 100, false)

  luaunit.assertEquals(#veafGeo.getUnitsInCircularZone({ "asleep" }, "ZONE"), 0)
end

function TestVeafGeoUnitsInCircularZone:test_an_unknown_zone_returns_an_empty_list()
  self:_unit("inside", 100, 100)

  luaunit.assertEquals(#veafGeo.getUnitsInCircularZone({ "inside" }, "NO-SUCH-ZONE"), 0)
end

function TestVeafGeoUnitsInCircularZone:test_an_unknown_unit_name_is_skipped()
  luaunit.assertEquals(#veafGeo.getUnitsInCircularZone({ "ghost" }, "ZONE"), 0)
end

-- ---------------------------------------------------------------------------
-- TestVeafGeoHeading
-- ---------------------------------------------------------------------------
TestVeafGeoHeading = {}

function TestVeafGeoHeading:setUp()
  dcs_mocks.reset()
end

--- A unit facing `heading` radians.
local function _facing(heading)
  return {
    getPosition = function()
      return { p = { x = 0, y = 0, z = 0 }, x = { x = math.cos(heading), y = 0, z = math.sin(heading) } }
    end,
  }
end

function TestVeafGeoHeading:test_due_north_is_zero()
  luaunit.assertAlmostEquals(veafGeo.getHeading(_facing(0), true), 0, 0.0001)
end

function TestVeafGeoHeading:test_due_east_is_a_quarter_turn()
  luaunit.assertAlmostEquals(veafGeo.getHeading(_facing(math.pi / 2), true), math.pi / 2, 0.0001)
end

function TestVeafGeoHeading:test_a_negative_angle_is_wrapped_into_zero_to_two_pi()
  -- atan2 answers in (-pi, pi]; a heading reads 0-360, so due west must come back as 3pi/2.
  local heading = veafGeo.getHeading(_facing(-math.pi / 2), true)

  luaunit.assertTrue(heading >= 0, "a heading is never negative")
  luaunit.assertAlmostEquals(heading, 3 * math.pi / 2, 0.0001)
end

function TestVeafGeoHeading:test_the_true_north_correction_is_applied_unless_raw_is_asked()
  local corrected = 0
  local saved = veaf.getNorthCorrection
  veaf.getNorthCorrection = function()
    corrected = corrected + 1
    return 0
  end

  veafGeo.getHeading(_facing(0), true)
  luaunit.assertEquals(corrected, 0, "rawHeading skips the correction")

  veafGeo.getHeading(_facing(0), false)
  luaunit.assertEquals(corrected, 1, "without rawHeading the correction is applied")

  veaf.getNorthCorrection = saved
end

function TestVeafGeoHeading:test_a_unit_that_is_not_a_dcs_object_returns_nil()
  -- Callers hand this whatever they hold. MiST called the method blind and raised.
  luaunit.assertNil(veafGeo.getHeading({ getVelocity = function() end }, true))
  luaunit.assertNil(veafGeo.getHeading(nil, true))
end

function TestVeafGeoHeading:test_a_unit_without_an_orientation_returns_nil()
  luaunit.assertNil(veafGeo.getHeading({
    getPosition = function()
      return { p = { x = 0, y = 0, z = 0 } }
    end,
  }, true))
end

-- ---------------------------------------------------------------------------
-- TestVeafGeoDrawTriggerZone
-- ---------------------------------------------------------------------------
TestVeafGeoDrawTriggerZone = {}

function TestVeafGeoDrawTriggerZone:setUp()
  dcs_mocks.reset()
  self.circles = {}
  self.quads = {}
  self.removed = {}
  local circles, quads, removed = self.circles, self.quads, self.removed

  self._savedCircle = trigger.action.circleToAll
  self._savedQuad = trigger.action.quadToAll
  self._savedRemove = trigger.action.removeMark
  trigger.action.circleToAll = function(coa, id, centre, radius, color, fillColor, lineType, readOnly, message)
    table.insert(circles, { id = id, centre = centre, radius = radius, message = message, readOnly = readOnly })
  end
  trigger.action.quadToAll = function(coa, id, p1, p2, p3, p4, color, fillColor, lineType, readOnly, message)
    table.insert(quads, { id = id, corners = { p1, p2, p3, p4 }, message = message })
  end
  trigger.action.removeMark = function(id)
    table.insert(removed, id)
  end

  veaf.triggerZones = {
    ROUND = { name = "ROUND", type = 0, x = 100, y = 200, radius = 750, color = { 1, 0, 0, 1 } },
    QUAD = {
      name = "QUAD",
      type = 2,
      x = 0,
      y = 0,
      verticies = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 10, y = 10 }, { x = 0, y = 10 } },
    },
    ODD = { name = "ODD", type = 7, x = 0, y = 0 },
  }
end

function TestVeafGeoDrawTriggerZone:tearDown()
  trigger.action.circleToAll = self._savedCircle
  trigger.action.quadToAll = self._savedQuad
  trigger.action.removeMark = self._savedRemove
  veaf.triggerZones = {}
end

function TestVeafGeoDrawTriggerZone:test_a_circular_zone_is_drawn_as_a_circle()
  local drawing = veafGeo.drawTriggerZone("ROUND", { message = "hello" })

  luaunit.assertNotNil(drawing)
  luaunit.assertEquals(#self.circles, 1)
  luaunit.assertEquals(self.circles[1].radius, 750)
  luaunit.assertEquals(self.circles[1].message, "hello")
  luaunit.assertEquals(self.circles[1].centre.x, 100)
  luaunit.assertEquals(self.circles[1].centre.z, 200, "the zone's y is the easting and belongs in z")
  luaunit.assertEquals(drawing.markId, self.circles[1].id, "the id answered is the id drawn")
end

function TestVeafGeoDrawTriggerZone:test_a_quad_zone_is_drawn_as_a_quad()
  local drawing = veafGeo.drawTriggerZone("QUAD", {})

  luaunit.assertNotNil(drawing)
  luaunit.assertEquals(#self.quads, 1)
  luaunit.assertEquals(#self.quads[1].corners, 4)
  luaunit.assertEquals(#self.circles, 0, "a quad zone must not be approximated by a circle")
end

function TestVeafGeoDrawTriggerZone:test_an_unknown_zone_draws_nothing()
  luaunit.assertNil(veafGeo.drawTriggerZone("NO-SUCH-ZONE", {}))
  luaunit.assertEquals(#self.circles, 0)
  luaunit.assertEquals(#self.quads, 0)
end

function TestVeafGeoDrawTriggerZone:test_an_unreadable_zone_type_draws_nothing_rather_than_guessing()
  -- Same rule as veaf.getUnitsInTriggerZone: a shape guessed for an unknown type is a wrong answer
  -- nobody would question (FIX-COMBATZONE-ZONE-TYPE-SILENT).
  luaunit.assertNil(veafGeo.drawTriggerZone("ODD", {}))
  luaunit.assertEquals(#self.circles, 0)
  luaunit.assertEquals(#self.quads, 0)
end

function TestVeafGeoDrawTriggerZone:test_removing_a_drawing_removes_the_mark_it_answered()
  local drawing = veafGeo.drawTriggerZone("ROUND", {})

  veafGeo.removeDrawing(drawing.markId)

  luaunit.assertEquals(self.removed, { drawing.markId })
end

function TestVeafGeoDrawTriggerZone:test_removing_nothing_is_not_an_error()
  veafGeo.removeDrawing(nil)

  luaunit.assertEquals(#self.removed, 0)
end

os.exit(luaunit.LuaUnit.run())
