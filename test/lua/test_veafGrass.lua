--- Tests for veafGrass.lua — constants and helicoptersOnFARPs list.
local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafGrass.lua")

-- ---------------------------------------------------------------------------
-- TestVeafGrassConstants
-- ---------------------------------------------------------------------------
TestVeafGrassConstants = {}

function TestVeafGrassConstants:test_id()
  luaunit.assertEquals(veafGrass.Id, "GRASS")
end

function TestVeafGrassConstants:test_radius_around_farp()
  luaunit.assertEquals(veafGrass.RadiusAroundFarp, 2000)
end

function TestVeafGrassConstants:test_delay_for_startup()
  luaunit.assertEquals(veafGrass.DelayForStartup, 2)
end

-- ---------------------------------------------------------------------------
-- TestVeafGrassHelicopters
-- ---------------------------------------------------------------------------
TestVeafGrassHelicopters = {}

function TestVeafGrassHelicopters:test_helicopters_list_is_table()
  luaunit.assertIsTable(veafGrass.helicoptersOnFARPs)
end

function TestVeafGrassHelicopters:test_helicopters_list_has_18_entries()
  luaunit.assertEquals(#veafGrass.helicoptersOnFARPs, 18)
end

function TestVeafGrassHelicopters:test_sa342mistral_present()
  local found = false
  for _, h in ipairs(veafGrass.helicoptersOnFARPs) do
    if h == "SA342Mistral" then
      found = true
    end
  end
  luaunit.assertTrue(found)
end

function TestVeafGrassHelicopters:test_uh1h_present()
  local found = false
  for _, h in ipairs(veafGrass.helicoptersOnFARPs) do
    if h == "UH-1H" then
      found = true
    end
  end
  luaunit.assertTrue(found)
end

function TestVeafGrassHelicopters:test_mi24p_present()
  local found = false
  for _, h in ipairs(veafGrass.helicoptersOnFARPs) do
    if h == "Mi-24P" then
      found = true
    end
  end
  luaunit.assertTrue(found)
end

function TestVeafGrassHelicopters:test_ah64d_present()
  local found = false
  for _, h in ipairs(veafGrass.helicoptersOnFARPs) do
    if h == "AH-64D_BLK_II" then
      found = true
    end
  end
  luaunit.assertTrue(found)
end

function TestVeafGrassHelicopters:test_first_entry_is_sa342()
  luaunit.assertEquals(veafGrass.helicoptersOnFARPs[1], "SA342Mistral")
end

function TestVeafGrassHelicopters:test_last_entry_is_ch47()
  luaunit.assertEquals(veafGrass.helicoptersOnFARPs[18], "CH-47Fbl1")
end

-------------------------------------------------------------------------------------------------
-- SECREV-2 / VMR-022 — the FARP coalition normalisation had two dead guards
--
--     if type(farpCoalition == "number") then
--
-- The closing parenthesis is in the wrong place, so this evaluates `type(boolean)`, which is
-- always the string "boolean" and always truthy. Both guards therefore always ran.
--
-- That is not merely dead code. With both blocks always executing, a FARP whose coalition
-- arrives as the **string** "red" fails the `== 1` test in the first block, falls into its
-- `else`, and comes out **blue** — the FARP is built for the wrong side.
-------------------------------------------------------------------------------------------------

TestVeafGrassFarpCoalition = {}

function TestVeafGrassFarpCoalition:test_numeric_red_stays_red()
  local name, number = veafGrass._normalizeFarpCoalition(1)
  luaunit.assertEquals(name, "red")
  luaunit.assertEquals(number, 1)
end

function TestVeafGrassFarpCoalition:test_numeric_blue_stays_blue()
  local name, number = veafGrass._normalizeFarpCoalition(2)
  luaunit.assertEquals(name, "blue")
  luaunit.assertEquals(number, 2)
end

function TestVeafGrassFarpCoalition:test_string_red_stays_red()
  -- The regression: this used to come back "blue"/2.
  local name, number = veafGrass._normalizeFarpCoalition("red")
  luaunit.assertEquals(name, "red")
  luaunit.assertEquals(number, 1)
end

function TestVeafGrassFarpCoalition:test_string_blue_stays_blue()
  local name, number = veafGrass._normalizeFarpCoalition("blue")
  luaunit.assertEquals(name, "blue")
  luaunit.assertEquals(number, 2)
end

function TestVeafGrassFarpCoalition:test_unknown_string_defaults_to_blue()
  -- Behaviour preserved: anything that is not "red" was already treated as blue.
  local name, number = veafGrass._normalizeFarpCoalition("purple")
  luaunit.assertEquals(name, "blue")
  luaunit.assertEquals(number, 2)
end

-------------------------------------------------------------------------------------------------
-- FIX-FARP-ESCORT-PLACEMENT — #232
--
-- `-farp` placed its escort at a fixed distance on a fixed bearing with no test of whether the spot
-- was free. Beside a static FARP — the *nominal* use, since the static FARP is what unlocks spawning
-- on it once the zone is captured — the trucks came down on its pads (reproduced 2026-08-17).
--
-- The fix keeps the radius and walks the bearing, per David's arbitration.
-------------------------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Ticket 02 — one predicate instead of four diverging copies of the type list
-- ---------------------------------------------------------------------------
TestVeafGrassFarpPlatformType = {}

function TestVeafGrassFarpPlatformType:setUp()
  self.warnings = {}
  local logger = veaf.loggers.get(veafGrass.Id)
  self._warn = logger.warn
  local captured = self.warnings
  logger.warn = function(_, fmt, ...)
    table.insert(captured, string.format(tostring(fmt), ...))
  end
end

function TestVeafGrassFarpPlatformType:tearDown()
  veaf.loggers.get(veafGrass.Id).warn = self._warn
end

function TestVeafGrassFarpPlatformType:test_the_four_long_standing_types_are_platforms()
  for _, typeName in ipairs({ "SINGLE_HELIPAD", "FARP_SINGLE_01", "FARP", "Invisible FARP" }) do
    luaunit.assertTrue(veafGrass.isFarpPlatformType(typeName), typeName .. " must be a FARP platform")
  end
end

-- The defect of ticket 02, in one assertion. Commit a454c577 (2025-08-08) added FARP_T to the list
-- that *recognises* FARP units and to none of the three that lay one out, so a FARP_T was processed
-- as a FARP and then measured as if it were not one — escort at 75 m instead of 150, onto the pads.
function TestVeafGrassFarpPlatformType:test_farp_t_is_a_platform()
  luaunit.assertTrue(veafGrass.isFarpPlatformType("FARP_T"))
end

function TestVeafGrassFarpPlatformType:test_a_plain_vehicle_is_not_a_platform()
  luaunit.assertFalse(veafGrass.isFarpPlatformType("M 818"))
  luaunit.assertEquals(#self.warnings, 0, "an ordinary type must not warn")
end

function TestVeafGrassFarpPlatformType:test_a_non_string_is_not_a_platform()
  luaunit.assertFalse(veafGrass.isFarpPlatformType(nil))
  luaunit.assertFalse(veafGrass.isFarpPlatformType(42))
end

-- Not mute: this is the shape FIX-COMBATZONE-ZONE-TYPE-SILENT is about. Guessing is acceptable,
-- guessing in silence is what hid FARP_T for a year.
function TestVeafGrassFarpPlatformType:test_an_unknown_farp_looking_type_warns()
  luaunit.assertFalse(veafGrass.isFarpPlatformType("VAP FARP"))
  luaunit.assertEquals(#self.warnings, 1)
  luaunit.assertStrContains(self.warnings[1], "VAP FARP")
end

function TestVeafGrassFarpPlatformType:test_an_unknown_helipad_type_warns()
  luaunit.assertFalse(veafGrass.isFarpPlatformType("BIG_HELIPAD_02"))
  luaunit.assertEquals(#self.warnings, 1)
end

-- The props this module places around a FARP have FARP in their names. Warning on them would fire on
-- every correct mission, and a warning that cries wolf gets ignored.
function TestVeafGrassFarpPlatformType:test_the_farp_props_do_not_warn()
  for _, typeName in ipairs({ "FARP Tent", "FARP Fuel Depot", "FARP Ammo Dump Coating", "FARP CP Blindage" }) do
    luaunit.assertFalse(veafGrass.isFarpPlatformType(typeName))
  end
  luaunit.assertEquals(#self.warnings, 0, "the props VEAF itself places must never warn")
end

-- ---------------------------------------------------------------------------
-- Ticket 01 — the occupancy probe
-- ---------------------------------------------------------------------------
TestVeafGrassSpotOccupied = {}

function TestVeafGrassSpotOccupied:setUp()
  self._search = world.searchObjects
end

function TestVeafGrassSpotOccupied:tearDown()
  world.searchObjects = self._search
end

function TestVeafGrassSpotOccupied:test_empty_ground_is_not_occupied()
  world.searchObjects = function(category, volume, handler) end
  luaunit.assertFalse(veafGrass.isSpotOccupied({ x = 0, y = 0 }))
end

function TestVeafGrassSpotOccupied:test_an_existing_object_occupies_the_spot()
  world.searchObjects = function(category, volume, handler)
    handler({
      isExist = function()
        return true
      end,
    })
  end
  luaunit.assertTrue(veafGrass.isSpotOccupied({ x = 0, y = 0 }))
end

function TestVeafGrassSpotOccupied:test_a_destroyed_object_does_not_occupy_it()
  world.searchObjects = function(category, volume, handler)
    handler({
      isExist = function()
        return false
      end,
    })
  end
  luaunit.assertFalse(veafGrass.isSpotOccupied({ x = 0, y = 0 }))
end

-- An object can vanish between DCS handing it over and us asking about it. A raise here would abort
-- building the FARP, which is worse than the defect being fixed.
function TestVeafGrassSpotOccupied:test_a_raising_object_does_not_break_the_probe()
  world.searchObjects = function(category, volume, handler)
    handler(setmetatable({}, {
      __index = function()
        error("object is gone")
      end,
    }))
  end
  local ok, result = pcall(veafGrass.isSpotOccupied, { x = 0, y = 0 })
  luaunit.assertTrue(ok)
  luaunit.assertFalse(result)
end

function TestVeafGrassSpotOccupied:test_an_unusable_api_reads_as_clear()
  world.searchObjects = function()
    error("searchObjects is not available on this build")
  end
  luaunit.assertFalse(veafGrass.isSpotOccupied({ x = 0, y = 0 }))
end

function TestVeafGrassSpotOccupied:test_the_probe_searches_units_and_statics()
  local categories = {}
  world.searchObjects = function(category, volume, handler)
    table.insert(categories, category)
  end
  veafGrass.isSpotOccupied({ x = 0, y = 0 })
  luaunit.assertEquals(categories, { Object.Category.UNIT, Object.Category.STATIC })
end

-- ---------------------------------------------------------------------------
-- Ticket 01 — walking the circle
-- ---------------------------------------------------------------------------
TestVeafGrassFindClearBearing = {}

function TestVeafGrassFindClearBearing:setUp()
  self._occupied = veafGrass.isSpotOccupied
end

function TestVeafGrassFindClearBearing:tearDown()
  veafGrass.isSpotOccupied = self._occupied
end

--- Positions for a three-object group on `bearing`, at a fixed distance of 150.
local function _groupAt(bearing)
  local positions = {}
  for j = 1, 3 do
    table.insert(positions, {
      x = 150 * math.cos(math.rad(bearing)) - (j - 1) * 6 * math.sin(math.rad(bearing)),
      y = 150 * math.sin(math.rad(bearing)) + (j - 1) * 6 * math.cos(math.rad(bearing)),
      bearing = bearing,
    })
  end
  return positions
end

-- The regression that matters most: a FARP with clear ground around it must not move at all.
function TestVeafGrassFindClearBearing:test_clear_ground_keeps_the_original_bearing()
  veafGrass.isSpotOccupied = function()
    return false
  end
  luaunit.assertEquals(veafGrass.findClearBearing(90, _groupAt), 90)
end

function TestVeafGrassFindClearBearing:test_an_occupied_bearing_is_left_behind()
  veafGrass.isSpotOccupied = function(position)
    return position.bearing == 90
  end
  local found = veafGrass.findClearBearing(90, _groupAt)
  luaunit.assertNotEquals(found, 90)
end

-- The walk alternates sides, so the escort lands as close as it can to where the mission maker aimed.
function TestVeafGrassFindClearBearing:test_the_nearest_clear_bearing_wins()
  veafGrass.isSpotOccupied = function(position)
    return position.bearing == 90
  end
  luaunit.assertEquals(veafGrass.findClearBearing(90, _groupAt), 90 + veafGrass.PLACEMENT_BEARING_STEP)
end

-- The escort is a group, not a point: a clear origin whose tail overlaps must be rejected, or the
-- group would move just enough to look fixed while still blocking a helipad.
function TestVeafGrassFindClearBearing:test_a_clear_origin_with_a_blocked_tail_is_rejected()
  local blocked = _groupAt(90)
  veafGrass.isSpotOccupied = function(position)
    -- only the third object's spot at bearing 90 is taken
    return position.bearing == 90 and math.abs(position.x - blocked[3].x) < 0.001 and math.abs(position.y - blocked[3].y) < 0.001
  end
  luaunit.assertNotEquals(veafGrass.findClearBearing(90, _groupAt), 90)
end

-- A FARP that refuses to exist because it is crowded would be worse than one whose escort is tight.
function TestVeafGrassFindClearBearing:test_nowhere_clear_falls_back_to_the_original_bearing()
  veafGrass.isSpotOccupied = function()
    return true
  end
  luaunit.assertEquals(veafGrass.findClearBearing(45, _groupAt), 45)
end

function TestVeafGrassFindClearBearing:test_it_gives_up_after_a_full_turn()
  local bearings = {}
  veafGrass.isSpotOccupied = function(position)
    bearings[position.bearing] = true
    return true
  end
  veafGrass.findClearBearing(0, _groupAt)
  local tried = 0
  for _ in pairs(bearings) do
    tried = tried + 1
  end
  -- the original bearing, then one full turn in steps
  luaunit.assertEquals(tried, 1 + math.floor(360 / veafGrass.PLACEMENT_BEARING_STEP))
end

-- Short-circuiting matters: this probe runs per object, and asking about the rest of a group whose
-- first position is already taken would multiply the calls into DCS for no information.
function TestVeafGrassFindClearBearing:test_a_blocked_first_position_stops_that_bearing()
  local probes = 0
  veafGrass.isSpotOccupied = function()
    probes = probes + 1
    return true
  end
  veafGrass.findClearBearing(0, _groupAt)
  luaunit.assertEquals(probes, 1 + math.floor(360 / veafGrass.PLACEMENT_BEARING_STEP), "one probe per bearing, not one per object")
end

-- ---------------------------------------------------------------------------
-- FIX-FARP-ESCORT-PLACEMENT — a FARP is an airbase, not a static
--
-- The fix shipped in 6.15.11 and did nothing: measured in game 2026-08-22, the escort still came up on
-- the static FARP. Two causes, and the second would have survived a fix for the first:
--
--  1. `isSpotOccupied` probed `world.searchObjects` over units and statics. A FARP placed in the editor
--     is an **airbase** — `Airbase.Category.HELIPAD`, through `world.getAirbases()` — so the probe could
--     never see the one object #232 is about.
--  2. `searchObjects` matches an object's *position*. With a 12 m clearance and a platform tens of metres
--     across, an escort on its **edge** leaves the platform's centre outside the sphere.
--
-- These tests exist because the old ones stubbed `isSpotOccupied` itself and asserted the bearing search
-- around it: they proved the search reacts to an occupied spot while nothing proved a real FARP *is* one.
-- A true test on a false premise, which is how the broken fix passed review.
-- ---------------------------------------------------------------------------
TestVeafGrassLandingPlatforms = {}

function TestVeafGrassLandingPlatforms:setUp()
  self._getAirbases = world.getAirbases
  self._search = world.searchObjects
  -- nothing parked anywhere, so only the platform half can make a spot occupied
  world.searchObjects = function(category, volume, handler) end
end

function TestVeafGrassLandingPlatforms:tearDown()
  world.getAirbases = self._getAirbases
  world.searchObjects = self._search
end

--- A stand-in airbase at a runtime point (`z` is the easting).
local function _airbase(name, category, x, z, typeName)
  return {
    getDesc = function()
      return { category = category }
    end,
    getTypeName = function()
      return typeName or name
    end,
    getPoint = function()
      return { x = x, y = 0, z = z }
    end,
    getName = function()
      return name
    end,
  }
end

function TestVeafGrassLandingPlatforms:test_a_helipad_is_collected()
  world.getAirbases = function()
    return { _airbase("StaticFarpAlpha", Airbase.Category.HELIPAD, 1000, 2000) }
  end
  local platforms = veafGrass.getLandingPlatforms()
  luaunit.assertEquals(#platforms, 1)
  luaunit.assertEquals(platforms[1].x, 1000)
  luaunit.assertEquals(platforms[1].z, 2000)
end

function TestVeafGrassLandingPlatforms:test_an_airfield_is_not_a_platform_to_avoid()
  -- An airdrome is where the escort is *supposed* to be able to sit; excluding a runway-sized radius
  -- around every airfield would move FARPs that were placed perfectly well.
  world.getAirbases = function()
    return { _airbase("Kobuleti", Airbase.Category.AIRDROME, 0, 0) }
  end
  luaunit.assertEquals(#veafGrass.getLandingPlatforms(), 0)
end

function TestVeafGrassLandingPlatforms:test_a_farp_dcs_miscategorises_as_a_ship_is_collected()
  -- Not defensive padding: DCS reports "FARP_SINGLE_01" and "VAP FARP" as ships, which
  -- veafAirbases.lua:191 already remediates. Leaving it out would let exactly those types keep the bug.
  world.getAirbases = function()
    return { _airbase("Alpha", Airbase.Category.SHIP, 0, 0, "FARP_SINGLE_01") }
  end
  luaunit.assertEquals(#veafGrass.getLandingPlatforms(), 1)
end

function TestVeafGrassLandingPlatforms:test_an_actual_ship_is_not_collected()
  world.getAirbases = function()
    return { _airbase("CVN-71", Airbase.Category.SHIP, 0, 0, "CVN_71") }
  end
  luaunit.assertEquals(#veafGrass.getLandingPlatforms(), 0)
end

function TestVeafGrassLandingPlatforms:test_dcs_refusing_the_call_is_not_a_crash()
  -- A FARP that refuses to exist because the probe failed is worse than one placed imperfectly.
  world.getAirbases = function()
    error("no airbases here")
  end
  luaunit.assertEquals(#veafGrass.getLandingPlatforms(), 0)
end

-- The geometry the whole lot is about, and the case a stubbed isSpotOccupied could not catch: the
-- escort is *near* the platform's centre, not on top of it.
function TestVeafGrassLandingPlatforms:test_a_spot_inside_the_footprint_is_occupied()
  local platforms = { { x = 0, z = 0, name = "StaticFarpAlpha" } }
  -- 60 m out: well beyond the 12 m clearance a sphere probe would use, well inside a FARP
  luaunit.assertTrue(veafGrass.isSpotOccupied({ x = 60, y = 0 }, nil, platforms))
  luaunit.assertTrue(veafGrass.isSpotOccupied({ x = 0, y = 60 }, nil, platforms))
end

function TestVeafGrassLandingPlatforms:test_a_spot_beyond_the_footprint_is_free()
  local platforms = { { x = 0, z = 0, name = "StaticFarpAlpha" } }
  luaunit.assertFalse(veafGrass.isSpotOccupied({ x = 150, y = 0 }, nil, platforms))
end

function TestVeafGrassLandingPlatforms:test_the_easting_is_read_from_the_right_axis()
  -- A mission-table position carries the easting in `y`; a runtime point carries it in `z`. Mixing them
  -- raises nothing and measures a distance across the wrong axes, so the conversion is pinned: a spot
  -- due east of the platform must be inside, and one that only *looks* close under the wrong mapping
  -- must not.
  local platforms = { { x = 0, z = 5000, name = "StaticFarpAlpha" } }
  luaunit.assertTrue(veafGrass.isSpotOccupied({ x = 0, y = 5000 }, nil, platforms), "due east, inside")
  luaunit.assertFalse(veafGrass.isSpotOccupied({ x = 5000, y = 0 }, nil, platforms), "axes swapped")
end

function TestVeafGrassLandingPlatforms:test_no_platform_list_leaves_the_old_behaviour_alone()
  -- Every existing caller passes two arguments; the platform half is opt-in so none of them changed.
  luaunit.assertFalse(veafGrass.isSpotOccupied({ x = 0, y = 0 }))
  luaunit.assertFalse(veafGrass.isSpotOccupied({ x = 0, y = 0 }, 12))
end

function TestVeafGrassLandingPlatforms:test_the_bearing_search_asks_dcs_once_not_per_position()
  -- A full turn is 24 bearings, each testing every position the group occupies. Reading the airbase
  -- list inside the probe would be hundreds of calls per FARP.
  local calls = 0
  world.getAirbases = function()
    calls = calls + 1
    return {}
  end
  veafGrass.findClearBearing(0, function(angle)
    return { { x = 0, y = 0 }, { x = 6, y = 0 } }
  end)
  luaunit.assertEquals(calls, 1)
end

-- The end-to-end shape: a bearing pointing at a platform is refused and the search moves on, which is
-- exactly what #232 asked for — keep the distance, change the bearing.
function TestVeafGrassLandingPlatforms:test_a_bearing_onto_a_platform_is_abandoned_for_another()
  world.getAirbases = function()
    return { _airbase("StaticFarpAlpha", Airbase.Category.HELIPAD, 150, 0) }
  end
  local chosen = veafGrass.findClearBearing(0, function(angle)
    local radians = math.rad(angle)
    return { { x = 150 * math.cos(radians), y = 150 * math.sin(radians) } }
  end)
  luaunit.assertNotEquals(chosen, 0, "bearing 0 puts the group on the platform")
end

-- ---------------------------------------------------------------------------
-- The footprint is read from the platform, and from the best source it offers
--
-- Two estimates in a row got the size wrong before anyone measured. 80 m first — below the 84 m where
-- that FARP's outermost pad actually sits, so an object at 81 m was on a pad and passed. Then 84 m plus
-- a margin, which bounds the *pads* and left the escort on the apron at ~120 m. Both were right about
-- the mechanism: the log showed the probe finding the platform, refusing spots, and moving the escort
-- bearing from 0° to -45°. In play that is indistinguishable from a probe that sees nothing.
--
-- Measured on a running DCS, 2026-08-24, on `StaticFarpAlpha`:
--
--   * `getDesc().box` → min/max ±129.5 m. A 259 m square. This is the real extent.
--   * `getParking()`  → 4 spots, furthest 84 m. Bounds the pads only.
--   * `land.getSurfaceType` → LAND everywhere to 260 m. The apron is not in the terrain data at all.
--
-- Hence a box test rather than a radius, and three tiers rather than one constant.
-- ---------------------------------------------------------------------------
TestVeafGrassPlatformFootprint = {}

--- An airbase reporting a bounding box, as a FARP does.
local function _airbaseWithBox(half)
  return {
    getDesc = function()
      return { box = { min = { x = -half, y = 0, z = -half }, max = { x = half, y = 0, z = half } } }
    end,
  }
end

--- An airbase with no box but with parking spots `distances` metres out.
local function _airbaseWithPads(centre, distances)
  local spots = {}
  for _, d in ipairs(distances) do
    table.insert(spots, { vTerminalPos = { x = centre.x + d, y = 0, z = centre.z } })
  end
  return {
    getDesc = function()
      return {}
    end,
    getParking = function()
      return spots
    end,
  }
end

function TestVeafGrassPlatformFootprint:test_the_box_is_preferred_and_is_the_measured_shape()
  -- 129.5 is what DCS reported for StaticFarpAlpha; the margin is for the vehicle's own size.
  local halfX, halfZ = veafGrass.platformExtents(_airbaseWithBox(129.5), { x = 0, y = 0, z = 0 })
  luaunit.assertEquals(halfX, 129.5 + veafGrass.PLATFORM_EDGE_MARGIN_METRES)
  luaunit.assertEquals(halfZ, 129.5 + veafGrass.PLATFORM_EDGE_MARGIN_METRES)
end

function TestVeafGrassPlatformFootprint:test_parking_is_the_second_choice_not_the_first()
  -- It bounds the pads, not the apron — which is precisely the mistake this replaces.
  local centre = { x = 0, y = 0, z = 0 }
  local halfX = veafGrass.platformExtents(_airbaseWithPads(centre, { 40, 84, 60 }), centre)
  luaunit.assertEquals(halfX, 84 + veafGrass.PLATFORM_PAD_MARGIN_METRES)
end

function TestVeafGrassPlatformFootprint:test_a_platform_offering_neither_falls_back()
  local centre = { x = 0, y = 0, z = 0 }
  local bare = {
    getDesc = function()
      return {}
    end,
    getParking = function()
      return {}
    end,
  }
  local halfX, halfZ = veafGrass.platformExtents(bare, centre)
  luaunit.assertEquals(halfX, veafGrass.PLATFORM_FALLBACK_HALF_EXTENT_METRES)
  luaunit.assertEquals(halfZ, veafGrass.PLATFORM_FALLBACK_HALF_EXTENT_METRES)
end

function TestVeafGrassPlatformFootprint:test_an_airbase_that_raises_on_everything_still_answers()
  -- A FARP that refuses to exist because a probe failed is worse than one placed imperfectly.
  local centre = { x = 0, y = 0, z = 0 }
  local hostile = {
    getDesc = function()
      error("no desc")
    end,
    getParking = function()
      error("no parking")
    end,
  }
  local halfX = veafGrass.platformExtents(hostile, centre)
  luaunit.assertEquals(halfX, veafGrass.PLATFORM_FALLBACK_HALF_EXTENT_METRES)
end

-- The two failures this lot went through, as numbers.
function TestVeafGrassPlatformFootprint:test_the_spots_both_earlier_attempts_accepted_are_refused()
  local platforms = { { x = 0, z = 0, name = "StaticFarpAlpha-1", halfX = 139.5, halfZ = 139.5 } }
  luaunit.assertTrue(veafGrass.isSpotOccupied({ x = 81, y = 0 }, nil, platforms), "81 m: on a pad")
  luaunit.assertTrue(veafGrass.isSpotOccupied({ x = 120, y = 0 }, nil, platforms), "120 m: on the apron")
end

function TestVeafGrassPlatformFootprint:test_ground_beyond_the_apron_is_still_free()
  -- The other wall: if the exclusion grows past the placement distance, no bearing is ever clear,
  -- findClearBearing falls back to the original angle, and the defect returns looking identical.
  local platforms = { { x = 0, z = 0, name = "StaticFarpAlpha-1", halfX = 139.5, halfZ = 139.5 } }
  luaunit.assertFalse(veafGrass.isSpotOccupied({ x = 200, y = 0 }, nil, platforms))
end

function TestVeafGrassPlatformFootprint:test_a_corner_outside_the_square_is_free()
  -- What the box test buys over a radius: a circle through the corners would refuse this, and it is
  -- plainly open ground.
  local platforms = { { x = 0, z = 0, name = "StaticFarpAlpha-1", halfX = 139.5, halfZ = 139.5 } }
  luaunit.assertFalse(veafGrass.isSpotOccupied({ x = 145, y = 145 }, nil, platforms))
end

function TestVeafGrassPlatformFootprint:test_each_platform_keeps_its_own_extents()
  local platforms = {
    { x = 0, z = 0, name = "BigFarp", halfX = 139.5, halfZ = 139.5 },
    { x = 2000, z = 0, name = "SmallPad", halfX = 30, halfZ = 30 },
  }
  luaunit.assertTrue(veafGrass.isSpotOccupied({ x = 120, y = 0 }, nil, platforms), "inside the big one")
  luaunit.assertFalse(veafGrass.isSpotOccupied({ x = 2060, y = 0 }, nil, platforms), "outside the small one")
end

os.exit(luaunit.LuaUnit.run())
