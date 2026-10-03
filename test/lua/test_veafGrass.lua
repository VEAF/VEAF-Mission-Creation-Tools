--- Tests for veafGrass.lua — constants and helicoptersOnFARPs list.
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

-- SCENERY joined the list in FIX-PLACEMENT-IGNORES-SCENERY ticket 03. It is what makes the probe see
-- **buildings**; forests are not scenery objects and are handled a tier above, from Disposition's cloud.
function TestVeafGrassSpotOccupied:test_the_probe_searches_units_statics_and_scenery()
  local categories = {}
  world.searchObjects = function(category, volume, handler)
    table.insert(categories, category)
  end
  veafGrass.isSpotOccupied({ x = 0, y = 0 })
  luaunit.assertEquals(categories, { Object.Category.UNIT, Object.Category.STATIC, Object.Category.SCENERY })
end

function TestVeafGrassSpotOccupied:test_a_building_occupies_the_spot()
  world.searchObjects = function(category, volume, handler)
    if category == Object.Category.SCENERY then
      handler({
        isExist = function()
          return true
        end,
      })
    end
  end
  luaunit.assertTrue(veafGrass.isSpotOccupied({ x = 0, y = 0 }), "an escort must not be placed through a building")
end

--- R19, 2026-10-03: on open ground the escort moved because its own FARP's layout occupied its spot.
--- What the caller names as its own does not occupy; anything else still does, and says what it is.
local function anObjectNamed(name)
  return function(category, volume, handler)
    if category == Object.Category.STATIC then
      handler({
        isExist = function()
          return true
        end,
        getName = function()
          return name
        end,
      })
    end
  end
end

function TestVeafGrassSpotOccupied:test_a_prop_of_its_own_farp_does_not_occupy_the_spot()
  world.searchObjects = anObjectNamed("FARP Alpha unit #7")
  luaunit.assertFalse(veafGrass.isSpotOccupied({ x = 0, y = 0 }, nil, nil, "FARP Alpha unit #"))
end

function TestVeafGrassSpotOccupied:test_a_prop_of_another_farp_still_occupies_it_and_is_named()
  world.searchObjects = anObjectNamed("FARP Bravo unit #7")
  local occupied, occupant = veafGrass.isSpotOccupied({ x = 0, y = 0 }, nil, nil, "FARP Alpha unit #")
  luaunit.assertTrue(occupied)
  luaunit.assertEquals(occupant, "FARP Bravo unit #7")
end

function TestVeafGrassSpotOccupied:test_without_a_prefix_its_own_prop_occupies_as_before()
  world.searchObjects = anObjectNamed("FARP Alpha unit #7")
  luaunit.assertTrue(veafGrass.isSpotOccupied({ x = 0, y = 0 }))
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

-- ---------------------------------------------------------------------------
-- Ticket 03 — the scenery cloud tier
--
-- David's design, 2026-08-27: ask Disposition for a **cloud** of scenery-clear points in one call, then
-- test them and take the one nearest the spot we actually wanted. It solves what a per-position scenery
-- test cannot: `world.searchObjects` sees buildings but not forests, and `Disposition` knows forests but
-- only *proposes* points — it cannot answer "is this spot clear?". Selecting from a cloud also makes its
-- measured radius overshoot harmless, since we filter the distance ourselves.
--
-- "Nearest the goal" is #232's arbitration expressed directly, where the bearing/distance stepping of
-- tier 2 was only an approximation of it.
-- ---------------------------------------------------------------------------
TestVeafGrassSceneryCloud = {}

function TestVeafGrassSceneryCloud:setUp()
  self._occupied = veafGrass.isSpotOccupied
  self._disposition = Disposition
  self._optOut = veaf.doNotAvoidScenery
  Disposition = nil
  veaf.doNotAvoidScenery = false
  veafGrass.isSpotOccupied = function()
    return false
  end
end

function TestVeafGrassSceneryCloud:tearDown()
  veafGrass.isSpotOccupied = self._occupied
  Disposition = self._disposition
  veaf.doNotAvoidScenery = self._optOut
end

--- The FARP, in mission-table shape: x is the northing, y the easting.
local _own = { x = 0, y = 0 }

--- A three-object group 150 m out on `bearing`, honouring `scale` the way escortPositionsAt does.
local function _scaledGroupAt(bearing, scale)
  scale = scale or 1
  local positions = {}
  local originX = 150 * scale * math.cos(math.rad(bearing))
  local originY = 150 * scale * math.sin(math.rad(bearing))
  for j = 1, 3 do
    table.insert(positions, {
      x = originX - (j - 1) * 6 * math.sin(math.rad(bearing)),
      y = originY + (j - 1) * 6 * math.cos(math.rad(bearing)),
      bearing = bearing,
      scale = scale,
    })
  end
  return positions
end

--- A runtime vec3 at `bearing`/`distance` from the FARP: easting lives in z.
local function _cloudPoint(bearing, distance)
  return {
    x = distance * math.cos(math.rad(bearing)),
    y = 0,
    z = distance * math.sin(math.rad(bearing)),
  }
end

--- Is this call the small probe rather than the large query? The two are the same function, told
--- apart by what they ask for: the probe asks for the vehicle probe's radius and clearance.
local function _isProbe(radius, safeRadius)
  return radius == veafGrass.SCENERY_PROBE_RADIUS and safeRadius == veafGrass.SCENERY_PROBE_CLEARANCE
end

--- Disposition as the game answers it: the large query returns `points`, and the probe finds a free
--- patch around a spot when `wantedSpotClear(centre)` says so. Measured on 2026-09-26, the probe gives
--- the same answer every time for the same point (0/12 against 12/12), so a function of the point is
--- a faithful stand-in for it.
function TestVeafGrassSceneryCloud:_terrain(points, wantedSpotClear)
  Disposition = {
    getSimpleZones = function(centre, radius, safeRadius)
      if _isProbe(radius, safeRadius) then
        if wantedSpotClear and wantedSpotClear(centre) then
          return { centre }
        end
        return {}
      end
      return points
    end,
  }
end

--- The wanted spot is in the trees — the probe finds no room there — so the cloud decides. This is
--- the premise of every test that expects tier 1 to move the group.
function TestVeafGrassSceneryCloud:_cloud(points)
  self:_terrain(points, nil)
end

function TestVeafGrassSceneryCloud:test_a_clear_cloud_point_sets_the_bearing_and_the_scale()
  self:_cloud({ _cloudPoint(180, 225) })
  local angle, scale, found = veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  luaunit.assertAlmostEquals(angle, 180, 0.01)
  luaunit.assertAlmostEquals(scale, 1.5, 0.01)
  luaunit.assertTrue(found, "a bearing the cloud found is a found bearing")
end

function TestVeafGrassSceneryCloud:test_the_candidate_nearest_the_requested_spot_wins()
  -- Both are in the band; 100 deg is far nearer the requested 90 than 200 is.
  self:_cloud({ _cloudPoint(200, 150), _cloudPoint(100, 150) })
  local angle = veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  luaunit.assertAlmostEquals(angle, 100, 0.01)
end

function TestVeafGrassSceneryCloud:test_a_candidate_beyond_the_distance_cap_is_ignored()
  -- The overshoot measured in game: asked 800 m, answered 2035-2258 m. The cap is what makes the
  -- cloud usable at all — #232 says the escort stays close to the FARP it serves.
  self:_cloud({ _cloudPoint(180, 150 * 4) })
  local angle, scale = veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  luaunit.assertEquals(angle, 90, "an out-of-band candidate must give way to the bearing walk")
  luaunit.assertEquals(scale, 1)
end

-- The regression that this tier's first draft shipped with, caught by the test above and pinned here on
-- its own. A candidate at *exactly* the requested distance comes back as 0.9999999999999998 of it once
-- trigonometry has been through it, so a bare `scale >= 1` discarded the best available point in
-- silence — the failure looked like "the nearest candidate did not win".
function TestVeafGrassSceneryCloud:test_a_candidate_at_exactly_the_requested_distance_is_accepted()
  self:_cloud({ _cloudPoint(100, 150) })
  local angle, scale = veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  luaunit.assertAlmostEquals(angle, 100, 0.01, "a point at the requested distance must not be rounded out of the band")
  luaunit.assertAlmostEquals(scale, 1, 0.001)
end

-- Bearings read 0-360 for whoever reads the log, and atan2 answers in (-180, 180].
function TestVeafGrassSceneryCloud:test_the_bearing_is_normalised_to_a_full_circle()
  self:_cloud({ _cloudPoint(270, 150) })
  local angle = veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  luaunit.assertAlmostEquals(angle, 270, 0.01, "270 must not come back as -90")
end

function TestVeafGrassSceneryCloud:test_a_candidate_closer_than_requested_is_ignored()
  -- Tier 2 never goes below 1x either. Pulling the escort inwards is how it ends up on the apron.
  self:_cloud({ _cloudPoint(180, 40) })
  local angle, scale = veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  luaunit.assertEquals(angle, 90)
  luaunit.assertEquals(scale, 1)
end

function TestVeafGrassSceneryCloud:test_an_occupied_cloud_point_is_rejected()
  -- Disposition knows nothing about other groups or the FARP's own pads, so the occupancy probe still
  -- decides. The two criteria compose; neither replaces the other.
  self:_cloud({ _cloudPoint(180, 150) })
  veafGrass.isSpotOccupied = function(position)
    return math.abs((position.bearing or 0) - 180) < 0.01
  end
  local angle = veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  luaunit.assertNotEquals(math.floor(angle + 0.5), 180)
end

function TestVeafGrassSceneryCloud:test_the_second_candidate_is_tried_when_the_first_is_occupied()
  self:_cloud({ _cloudPoint(180, 150), _cloudPoint(270, 150) })
  veafGrass.isSpotOccupied = function(position)
    return math.abs((position.bearing or 0) - 180) < 0.01
  end
  local angle = veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  luaunit.assertAlmostEquals(angle, 270, 0.01)
end

-- ---------------------------------------------------------------------------
-- FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND — ask about the wanted spot itself
--
-- Measured in game 2026-08-28: a `-farp` on open ground, nothing within a kilometre, still logged
-- `FARP escort: bearing 0 requested, 25 used at 1.054x distance`. The cloud only *proposes* points and
-- never the wanted spot, so as long as it answered at all, the escort moved.
--
-- Ticket 01 read the nearest candidate's `gap` as a statement about the wanted spot, with a 12 m
-- threshold. Measured in game 2026-09-01, twelve decisions: the nearest gap ever seen was **43.9 m**,
-- and the guard never fired. The large query samples at random; nothing makes a sample land near the
-- spot, so no threshold could have worked. Its tests built their gap at half the threshold — a value the
-- game does not produce — and stayed green over an inert guard.
--
-- Ticket 03 asks the small probe instead, the one `veafUnits.settleGroup` uses since ticket 12 of
-- FIX-PLACEMENT-IGNORES-SCENERY: deterministic, 0.38 ms, and asked about one point at a time. These tests
-- drive what the probe answers, which is the question the game is actually asked.
-- ---------------------------------------------------------------------------

--- A runtime vec3 at an absolute northing/easting: the easting lives in `z`, `y` is the altitude.
--- The wanted spot for bearing 90 at scale 1 is northing 0, easting 150, so the northing given here
--- *is* the gap to it — see docs/agents/dcs-coordinates.md before reading this as `{x, y}`.
local function _cloudPointNorthEast(north, east)
  return { x = north, y = 0, z = east }
end

local function _everywhere()
  return true
end

function TestVeafGrassSceneryCloud:test_a_wanted_spot_the_probe_finds_clear_keeps_the_bearing_and_the_distance()
  -- The nearest candidate sits 43.9 m away, the nearest gap measured in game on 2026-09-01: under
  -- ticket 01 this escort moved. The probe answers about the spot itself, so the gap no longer matters.
  self:_terrain({ _cloudPointNorthEast(43.9, 150) }, _everywhere)
  local angle, scale, found = veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  luaunit.assertEquals(angle, 90, "a spot the probe finds clear must keep its bearing")
  luaunit.assertEquals(scale, 1, "and its distance")
  luaunit.assertTrue(found)
end

function TestVeafGrassSceneryCloud:test_a_clear_wanted_spot_never_asks_for_a_clearing()
  -- The large query is the lottery (12 ms, not deterministic); when the probe has already answered
  -- there is nothing left for it to decide.
  local largeQueries = 0
  Disposition = {
    getSimpleZones = function(centre, radius, safeRadius)
      if _isProbe(radius, safeRadius) then
        return { centre }
      end
      largeQueries = largeQueries + 1
      return { _cloudPoint(180, 150) }
    end,
  }
  veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  luaunit.assertEquals(largeQueries, 0)
end

function TestVeafGrassSceneryCloud:test_the_probe_is_asked_at_every_position_of_the_group()
  -- A five-truck line needs every truck out of the trees, not its origin: same reasoning as the
  -- occupancy probe testing the whole group rather than its first position.
  local asked = {}
  Disposition = {
    getSimpleZones = function(centre, radius, safeRadius)
      if _isProbe(radius, safeRadius) then
        table.insert(asked, centre)
        return { centre }
      end
      return {}
    end,
  }
  veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  local wanted = _scaledGroupAt(90, 1)
  luaunit.assertEquals(#asked, #wanted)
  for i, position in ipairs(wanted) do
    -- Mission-table in, runtime vec3 out: the easting moves from `y` to `z`.
    luaunit.assertAlmostEquals(asked[i].x, position.x, 0.001)
    luaunit.assertAlmostEquals(asked[i].z, position.y, 0.001, "the easting must reach the probe in z")
  end
end

function TestVeafGrassSceneryCloud:test_the_probe_asks_the_vehicle_question()
  -- The same question `veafUnits.settleGroup` asks, so a group this code keeps is one settleGroup
  -- would not move. The two disagreeing is how ticket 10 of FIX-PLACEMENT-IGNORES-SCENERY came out
  -- green in CI and inert in game.
  luaunit.assertEquals(veafGrass.SCENERY_PROBE_RADIUS, 20)
  luaunit.assertEquals(veafGrass.SCENERY_PROBE_CLEARANCE, 5)
end

function TestVeafGrassSceneryCloud:test_one_truck_in_the_trees_moves_the_group()
  -- The tail is in the wood, the origin is not. A group that keeps its bearing here parks a truck
  -- under the trees — the defect this tier was added for.
  local tail = _scaledGroupAt(90, 1)[3]
  self:_terrain({ _cloudPoint(180, 150) }, function(centre)
    return not (math.abs(centre.x - tail.x) < 0.001 and math.abs(centre.z - tail.y) < 0.001)
  end)
  local angle = veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  luaunit.assertAlmostEquals(angle, 180, 0.01, "a group with a truck in the trees must go where the cloud says")
end

function TestVeafGrassSceneryCloud:test_a_clear_wanted_spot_that_is_occupied_still_moves()
  -- The probe knows forests; the occupancy probe knows units, statics, buildings and the aprons. The
  -- two compose, so a clear wood never overrides a static FARP's pad.
  self:_terrain({ _cloudPoint(180, 150) }, _everywhere)
  veafGrass.isSpotOccupied = function(position)
    return math.abs((position.bearing or 0) - 90) < 0.01
  end
  local angle = veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  luaunit.assertNotEquals(math.floor(angle + 0.5), 90, "an occupied spot must move even when the scenery is clear")
end

function TestVeafGrassSceneryCloud:test_a_raising_probe_reads_as_clear()
  -- ADR 0018: the singleton may improve quality, never refuse. A probe that raises must not be what
  -- moves an escort, so the spot stands on the occupancy probe alone.
  Disposition = {
    getSimpleZones = function(_centre, radius, safeRadius)
      if _isProbe(radius, safeRadius) then
        error("probe unavailable")
      end
      return { _cloudPoint(180, 150) }
    end,
  }
  luaunit.assertEquals(veafGrass.findClearBearing(90, _scaledGroupAt, _own), 90)
end

-- ADR 0018: Disposition is quality-only, never correctness. Absent, raising or answering nonsense, the
-- search must degrade to the bearing walk and never abort a FARP.
function TestVeafGrassSceneryCloud:test_no_singleton_degrades_to_the_bearing_walk()
  Disposition = nil
  local angle, scale = veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  luaunit.assertEquals(angle, 90)
  luaunit.assertEquals(scale, 1)
end

function TestVeafGrassSceneryCloud:test_a_raising_singleton_degrades_to_the_bearing_walk()
  Disposition = {
    getSimpleZones = function()
      error("Disposition is not available on this build")
    end,
  }
  local angle = veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  luaunit.assertEquals(angle, 90)
end

function TestVeafGrassSceneryCloud:test_a_nonsense_answer_degrades_to_the_bearing_walk()
  self:_cloud({ "not a point", { x = 0 } })
  local angle = veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  luaunit.assertEquals(angle, 90)
end

function TestVeafGrassSceneryCloud:test_the_opt_out_never_asks()
  local asked = false
  Disposition = {
    getSimpleZones = function()
      asked = true
      return { _cloudPoint(180, 150) }
    end,
  }
  veaf.doNotAvoidScenery = true
  local angle = veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  luaunit.assertFalse(asked, "veaf.doNotAvoidScenery must silence the cloud tier too")
  luaunit.assertEquals(angle, 90)
end

-- One large query per group, not one per candidate position. That is the whole cost argument for this
-- design: 75 probes in the exhausted case become a single call to the undocumented API. The small probe
-- is asked once per position of the wanted spot, and not counted here.
function TestVeafGrassSceneryCloud:test_the_large_query_is_asked_exactly_once()
  local calls = 0
  Disposition = {
    getSimpleZones = function(_centre, radius, safeRadius)
      if not _isProbe(radius, safeRadius) then
        calls = calls + 1
      end
      return {}
    end,
  }
  veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  luaunit.assertEquals(calls, 1)
end

-- The safe radius is derived from the group's own extent rather than being a magic number: a
-- three-vehicle line at 6 m spacing needs a wider clearing than a single truck.
function TestVeafGrassSceneryCloud:test_the_requested_clearance_covers_the_group_extent()
  local askedRadius, askedSafeRadius
  Disposition = {
    getSimpleZones = function(_centre, radius, safeRadius)
      if not _isProbe(radius, safeRadius) then
        askedRadius, askedSafeRadius = radius, safeRadius
      end
      return {}
    end,
  }
  veafGrass.findClearBearing(90, _scaledGroupAt, _own)
  -- 150 m out, capped at 2x
  luaunit.assertAlmostEquals(askedRadius, 300, 0.01)
  -- two 6 m steps from the origin, plus the per-position clearance
  luaunit.assertAlmostEquals(askedSafeRadius, 12 + veafGrass.PLACEMENT_CLEARANCE, 0.01)
end

-- The probe budget, pinned. Measured 2026-08-27 for FIX-PLACEMENT-IGNORES-SCENERY ticket 03, before
-- adding a category to `isSpotOccupied`: the question was whether a per-position scenery test would
-- multiply an already large product. It does not, because the shape of the search bounds it.
--
-- `findClearBearing`'s own comment warns that "a full turn tries 24 bearings at each distance, and each
-- bearing tests every position the group would occupy" — 3 distances x 25 bearings x 3 positions = 225
-- in the abstract. The measured numbers are far lower, and for a reason worth keeping: `allClear`
-- returns on its **first** occupied position, so a crowded bearing costs one probe, not three. The
-- expensive case is not "everything is blocked", it is "almost everything is clear".
--
-- These are call counts, not timings. What they bound is how many times DCS is asked, which is the part
-- adding a category changes; the per-call cost of `world.searchObjects` over a 12 m sphere is DCS's.
function TestVeafGrassFindClearBearing:test_the_probe_budget_stays_bounded()
  local function count(occupiedFn)
    local n = 0
    veafGrass.isSpotOccupied = function(position)
      n = n + 1
      return occupiedFn(position)
    end
    veafGrass.findClearBearing(90, _groupAt)
    return n
  end

  -- The nominal case, and the one that matters: a FARP with clear ground probes its group once.
  luaunit.assertEquals(
    count(function()
      return false
    end),
    3,
    "clear ground must cost one bearing's worth of probes"
  )

  -- Nothing clear anywhere: one probe per bearing evaluation thanks to the early return.
  local bearings = math.floor(360 / veafGrass.PLACEMENT_BEARING_STEP)
  local distances = #veafGrass.PLACEMENT_DISTANCE_STEPS
  luaunit.assertEquals(
    count(function()
      return true
    end),
    distances * (bearings + 1),
    "the exhausted search must not exceed one probe per bearing evaluation"
  )

  -- The absolute ceiling, whatever the occupancy pattern.
  luaunit.assertTrue(distances * (bearings + 1) * #_groupAt(0) <= 225, "the theoretical ceiling is 225 probes per group")
end

-- The regression that matters most: a FARP with clear ground around it must not move at all.
function TestVeafGrassFindClearBearing:test_clear_ground_keeps_the_original_bearing()
  veafGrass.isSpotOccupied = function()
    return false
  end
  local angle, scale, found = veafGrass.findClearBearing(90, _groupAt)
  luaunit.assertEquals(angle, 90)
  luaunit.assertEquals(scale, 1)
  luaunit.assertTrue(found)
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

-- The search still answers with the original bearing when nothing is clear, so the callers that keep
-- today's fallback — tents, props, windsock, the editor's static FARPs — need no change. It also says
-- it found nothing, and deciding what that means is the caller's business (FIX-PLACEMENT-IGNORES-SCENERY
-- ticket 04: only a `-farp` escort turns it into a refusal).
function TestVeafGrassFindClearBearing:test_nowhere_clear_falls_back_to_the_original_bearing_and_says_so()
  veafGrass.isSpotOccupied = function()
    return true
  end
  local angle, scale, found = veafGrass.findClearBearing(45, _groupAt)
  luaunit.assertEquals(angle, 45)
  luaunit.assertEquals(scale, 1)
  luaunit.assertFalse(found, "an exhausted search must be told apart from a found bearing")
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
  -- One per bearing, not one per object — times the distance steps, since a full turn is retried at
  -- each. Written as the product rather than a literal so adding a step does not silently pass.
  local perTurn = 1 + math.floor(360 / veafGrass.PLACEMENT_BEARING_STEP)
  local steps = 0
  for _ in ipairs(veafGrass.PLACEMENT_DISTANCE_STEPS) do
    steps = steps + 1
  end
  luaunit.assertEquals(probes, perTurn * steps, "one probe per bearing per distance, not one per object")
end

-- ---------------------------------------------------------------------------
-- Pushing the group further out when no bearing is clear
--
-- Measured in game on 2026-08-24: with the exclusion finally the size of a real FARP apron (259 m), the
-- generator/storage group had **no** clear bearing at its distance, so the bearing-only search kept the
-- original angle — and put the group on a pad. The fallback placed it at the worst spot available.
--
-- Bearing-only was right while the exclusion was small; against a real apron it guarantees landing
-- inside it. David's arbitration on #232 (keep the distance, move the bearing) was revised on that
-- evidence: walk outwards, but only as far as needed, and never past 2x.
-- ---------------------------------------------------------------------------
TestVeafGrassDistanceEscalation = {}

function TestVeafGrassDistanceEscalation:setUp()
  self._occupied = veafGrass.isSpotOccupied
  self._platforms = veafGrass.getLandingPlatforms
  veafGrass.getLandingPlatforms = function()
    return {}
  end
end

function TestVeafGrassDistanceEscalation:tearDown()
  veafGrass.isSpotOccupied = self._occupied
  veafGrass.getLandingPlatforms = self._platforms
end

--- A group whose single position is `100 * scale` metres out on `bearing`.
local function _atScale(bearing, scale)
  scale = scale or 1
  local radians = math.rad(bearing)
  return { { x = 100 * scale * math.cos(radians), y = 100 * scale * math.sin(radians) } }
end

function TestVeafGrassDistanceEscalation:test_clear_ground_at_the_asked_distance_does_not_move_anything()
  veafGrass.isSpotOccupied = function()
    return false
  end
  local angle, scale = veafGrass.findClearBearing(0, _atScale)
  luaunit.assertEquals(angle, 0)
  luaunit.assertEquals(scale, 1)
end

function TestVeafGrassDistanceEscalation:test_it_walks_out_only_when_no_bearing_works()
  -- Everything inside 140 m is taken, which is what a 259 m apron does to a group placed at 100 m.
  veafGrass.isSpotOccupied = function(position)
    return math.sqrt(position.x * position.x + position.y * position.y) < 140
  end
  local angle, scale = veafGrass.findClearBearing(0, _atScale)
  luaunit.assertEquals(scale, 1.5, "100 m was blocked everywhere, 150 m is not")
  luaunit.assertEquals(angle, 0, "and the requested bearing is kept once the distance is enough")
end

function TestVeafGrassDistanceEscalation:test_it_prefers_a_different_bearing_over_a_greater_distance()
  -- Staying close is the point of the arbitration: a clear bearing at the asked distance must win over
  -- a clear one further out.
  veafGrass.isSpotOccupied = function(position)
    -- only the due-east direction is blocked, at any distance
    return position.x > 0 and math.abs(position.y) < 1
  end
  local angle, scale = veafGrass.findClearBearing(0, _atScale)
  luaunit.assertEquals(scale, 1, "a bearing was available without moving out")
  luaunit.assertNotEquals(angle, 0)
end

function TestVeafGrassDistanceEscalation:test_nothing_anywhere_keeps_the_original_placement()
  -- A FARP that refuses to exist because it is crowded would be worse than one placed imperfectly, so
  -- the last resort is unchanged — but it is now logged, because this is how a group ends up on an apron.
  veafGrass.isSpotOccupied = function()
    return true
  end
  local angle, scale = veafGrass.findClearBearing(30, _atScale)
  luaunit.assertEquals(angle, 30)
  luaunit.assertEquals(scale, 1)
end

function TestVeafGrassDistanceEscalation:test_the_walk_is_capped()
  -- Uncapped, a crowded airfield would push the escort into the next valley, which serves nobody.
  local largest = 0
  for _, scale in ipairs(veafGrass.PLACEMENT_DISTANCE_STEPS) do
    if scale > largest then
      largest = scale
    end
  end
  luaunit.assertEquals(largest, 2)
  luaunit.assertEquals(veafGrass.PLACEMENT_DISTANCE_STEPS[1], 1, "the asked distance must be tried first")
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

-- ---------------------------------------------------------------------------
-- A FARP does not avoid itself
--
-- The FARP a marker creates **is** an airbase, and it exists by the time its own props are placed:
-- measured in game 2026-08-24, the probe reported `FARP FU2149-11.924` next to the static one. So the
-- fix aimed at keeping props off a *neighbouring* platform started refusing every position inside the
-- new FARP's own 139 m apron — which is where its props belong — at every bearing and every distance,
-- and fell back to the original angle. The result was worse than before the fix.
-- ---------------------------------------------------------------------------
TestVeafGrassOwnPlatform = {}

function TestVeafGrassOwnPlatform:setUp()
  self._getAirbases = world.getAirbases
end

function TestVeafGrassOwnPlatform:tearDown()
  world.getAirbases = self._getAirbases
end

--- An airbase reporting a FARP-sized box at a runtime point.
local function _platformAt(name, x, z)
  return {
    getDesc = function()
      return {
        category = Airbase.Category.HELIPAD,
        box = { min = { x = -129.5, y = 0, z = -129.5 }, max = { x = 129.5, y = 0, z = 129.5 } },
      }
    end,
    getTypeName = function()
      return name
    end,
    getPoint = function()
      return { x = x, y = 0, z = z }
    end,
    getName = function()
      return name
    end,
  }
end

function TestVeafGrassOwnPlatform:test_the_farp_being_built_is_left_out()
  world.getAirbases = function()
    return { _platformAt("NewFarp", 1000, 2000) }
  end
  -- `own` is a mission-table position: its `y` is the easting, matching the platform's `z`.
  local platforms = veafGrass.getLandingPlatforms({ x = 1000, y = 2000 })
  luaunit.assertEquals(#platforms, 0, "a FARP must not avoid its own apron")
end

function TestVeafGrassOwnPlatform:test_a_neighbour_is_still_avoided()
  world.getAirbases = function()
    return { _platformAt("NewFarp", 1000, 2000), _platformAt("StaticFarpAlpha", 1400, 2000) }
  end
  local platforms = veafGrass.getLandingPlatforms({ x = 1000, y = 2000 })
  luaunit.assertEquals(#platforms, 1)
  luaunit.assertEquals(platforms[1].name, "StaticFarpAlpha")
end

function TestVeafGrassOwnPlatform:test_without_an_own_position_everything_is_avoided()
  -- Callers that do not say which platform is theirs keep the old behaviour rather than silently
  -- excluding the nearest one.
  world.getAirbases = function()
    return { _platformAt("NewFarp", 1000, 2000) }
  end
  luaunit.assertEquals(#veafGrass.getLandingPlatforms(), 1)
end

function TestVeafGrassOwnPlatform:test_the_match_is_on_position_not_on_being_closest()
  -- 400 m away is a different platform even if it is the only other one, so the identity test has to be
  -- tight: a loose one would silently stop avoiding the very FARP #232 is about.
  world.getAirbases = function()
    return { _platformAt("StaticFarpAlpha", 1400, 2000) }
  end
  luaunit.assertEquals(#veafGrass.getLandingPlatforms({ x = 1000, y = 2000 }), 1)
end

-- ---------------------------------------------------------------------------
-- FIX-PLACEMENT-IGNORES-SCENERY ticket 04 — can the escort be placed at all?
--
-- David, 2026-08-27: the escort is placed intelligently, or the `-farp` is refused with a message. The
-- question has to be answerable **before** the FARP exists, so a refused FARP creates nothing, and it
-- has to lay the escort out exactly as `buildFarpUnits` does, or the answer is about another group.
-- ---------------------------------------------------------------------------
TestVeafGrassFarpEscort = {}

function TestVeafGrassFarpEscort:setUp()
  self._occupied = veafGrass.isSpotOccupied
  self._disposition = Disposition
  Disposition = nil
end

function TestVeafGrassFarpEscort:tearDown()
  veafGrass.isSpotOccupied = self._occupied
  Disposition = self._disposition
end

--- A FARP as `spawnFarp` hands it over: mission-table position, heading in radians.
local function _farp(farpType, side, headingDegrees)
  return { x = 1000, y = 2000, type = farpType, coalition = side, heading = math.rad(headingDegrees or 0) }
end

function TestVeafGrassFarpEscort:test_a_platform_farp_escort_stands_150_m_out_on_its_heading()
  local types, positionsAt = veafGrass.farpEscortLayout(_farp("FARP", 2))
  luaunit.assertEquals(#types, 5, "the blue escort is five vehicles")
  local positions = positionsAt(90, 1)
  luaunit.assertEquals(#positions, #types, "one position per vehicle")
  -- Bearing 90: the origin steps east, 150 m from the FARP.
  luaunit.assertAlmostEquals(positions[1].x, 1000, 0.001)
  luaunit.assertAlmostEquals(positions[1].y, 2150, 0.001)
end

function TestVeafGrassFarpEscort:test_the_scale_multiplies_the_distance()
  -- The `-farp` default is an invisible FARP, which is a platform too: 150 m.
  local _, positionsAt = veafGrass.farpEscortLayout(_farp("Invisible FARP", 2))
  luaunit.assertAlmostEquals(positionsAt(0, 1)[1].x, 1150, 0.001)
  luaunit.assertAlmostEquals(positionsAt(0, 2)[1].x, 1300, 0.001)
end

function TestVeafGrassFarpEscort:test_a_unit_that_is_not_a_platform_keeps_its_escort_closer()
  -- `buildFarpsUnits` walks any unit named `FARP …`, not only platforms.
  local _, positionsAt = veafGrass.farpEscortLayout(_farp("Hummer", 2))
  luaunit.assertAlmostEquals(positionsAt(0, 1)[1].x, 1075, 0.001)
end

function TestVeafGrassFarpEscort:test_the_red_escort_is_the_red_vehicles()
  local types = veafGrass.farpEscortLayout(_farp("FARP", 1))
  luaunit.assertEquals(#types, 6)
  luaunit.assertEquals(types[1], "ATZ-10")
end

function TestVeafGrassFarpEscort:test_an_escort_on_open_ground_can_be_placed()
  veafGrass.isSpotOccupied = function()
    return false
  end
  luaunit.assertTrue(veafGrass.canPlaceFarpEscort(_farp("Invisible FARP", 2)))
end

function TestVeafGrassFarpEscort:test_an_escort_moved_off_its_bearing_can_still_be_placed()
  -- Narrow refusal: a crowded bearing is what the search is for, and must never refuse the FARP.
  veafGrass.isSpotOccupied = function(position)
    return position.y > 2000 -- everything east of the FARP is taken
  end
  luaunit.assertTrue(veafGrass.canPlaceFarpEscort(_farp("Invisible FARP", 2, 90)))
end

function TestVeafGrassFarpEscort:test_an_escort_with_nowhere_to_go_cannot_be_placed()
  veafGrass.isSpotOccupied = function()
    return true
  end
  luaunit.assertFalse(veafGrass.canPlaceFarpEscort(_farp("Invisible FARP", 2)))
end

function TestVeafGrassFarpEscort:test_only_the_escort_is_asked_about()
  -- The windsock sits 120 m out and the props 130 m out on a FARP; the escort 150 m out. Everything
  -- closer than 140 m is taken, so the windsock and the props have nowhere to go — and that must not
  -- refuse the FARP: their bearing is free, and they keep today's fallback.
  veafGrass.isSpotOccupied = function(position)
    local dx, dy = position.x - 1000, position.y - 2000
    return math.sqrt(dx * dx + dy * dy) < 140
  end
  luaunit.assertTrue(veafGrass.canPlaceFarpEscort(_farp("FARP", 2)))
end

function TestVeafGrassFarpEscort:test_a_found_placement_comes_back_with_the_answer()
  veafGrass.isSpotOccupied = function()
    return false
  end
  local found, placement = veafGrass.canPlaceFarpEscort(_farp("Invisible FARP", 2, 90))
  luaunit.assertTrue(found)
  luaunit.assertAlmostEquals(placement.angle, 90, 0.001)
  luaunit.assertEquals(placement.scale, 1)
end

-- ---------------------------------------------------------------------------
-- buildFarpUnits — what it does with an escort that has nowhere to go
-- ---------------------------------------------------------------------------
TestVeafGrassBuildFarpEscort = {}

function TestVeafGrassBuildFarpEscort:setUp()
  self._occupied = veafGrass.isSpotOccupied
  self._canPlace = veafGrass.canPlaceFarpEscort
  self._addGroup = veaf.addGroup
  self._addStatic = veaf.addStatic
  self._disposition = Disposition
  Disposition = nil
  self.groups = {}
  veaf.addGroup = function(group)
    table.insert(self.groups, group)
  end
  veaf.addStatic = function() end
  veafGrass.isSpotOccupied = function()
    return true
  end
end

function TestVeafGrassBuildFarpEscort:tearDown()
  veafGrass.isSpotOccupied = self._occupied
  veafGrass.canPlaceFarpEscort = self._canPlace
  veaf.addGroup = self._addGroup
  veaf.addStatic = self._addStatic
  Disposition = self._disposition
end

local function _editorFarp()
  return { x = 1000, y = 2000, type = "FARP", coalition = 2, heading = 0, name = "FARP Alpha", groupName = "FARP Alpha", country = 2 }
end

--- The escort group the layout spawned, and the bearing its first vehicle stands on, read back from its
--- position so the test does not depend on how the search reached it.
function TestVeafGrassBuildFarpEscort:_escortBearing()
  -- The layout spawns other groups too; the escort is the one made of the blue escort vehicles.
  local escorts = {}
  for _, group in ipairs(self.groups) do
    if group.units and group.units[1] and group.units[1].type == "Hummer" then
      table.insert(escorts, group)
    end
  end
  luaunit.assertEquals(#escorts, 1, "exactly one escort group")
  local first = escorts[1].units[1]
  return (math.deg(math.atan2(first.y - 2000, first.x - 1000)) + 360) % 360
end

-- Ruling 3: the editor's static FARPs have nobody to read a refusal, so they are never refused — they
-- do not even ask. Pinned, because adding the question inside buildFarpUnits is the natural refactor,
-- and it would refuse editor FARPs at mission load.
function TestVeafGrassBuildFarpEscort:test_an_editor_farp_with_nowhere_to_go_is_built_anyway()
  veafGrass.canPlaceFarpEscort = function()
    error("the editor's path must never ask whether the escort can be placed")
  end
  veafGrass.buildFarpUnits(_editorFarp(), nil, nil, true)
  luaunit.assertAlmostEquals(self:_escortBearing(), 0, 0.001, "today's fallback: the requested bearing")
end

-- `-farp` accepted the FARP on a placement found before the tents and props stood; if they then take
-- it, the escort keeps that placement rather than falling back to the requested bearing in silence.
function TestVeafGrassBuildFarpEscort:test_an_accepted_farp_keeps_the_placement_it_was_accepted_on()
  veafGrass.buildFarpUnits(_editorFarp(), nil, "FARP Alpha", true, true, nil, nil, nil, { angle = 120, scale = 1.5 })
  luaunit.assertAlmostEquals(self:_escortBearing(), 120, 0.001)
end

--- R19 (FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND), measured 2026-10-03: on open ground, the escort moved
--- because the props of its own FARP, laid out first on the same bearing, occupied its spot. Only the
--- escort may stand beside them: the tents, props and windsock still avoid what stands before them.
function TestVeafGrassBuildFarpEscort:test_only_the_escort_ignores_the_props_of_its_own_farp()
  local prefixes = {}
  veafGrass.isSpotOccupied = function(_, _, _, prefix)
    table.insert(prefixes, prefix or "none")
    return false
  end
  veafGrass.buildFarpUnits(_editorFarp(), nil, nil, true)
  local seen = {}
  for _, prefix in ipairs(prefixes) do
    seen[prefix] = true
  end
  luaunit.assertTrue(seen["FARP FARP Alpha unit #"], "the escort's search names the FARP's own props")
  luaunit.assertTrue(seen["none"], "the other searches name nothing")
  luaunit.assertAlmostEquals(self:_escortBearing(), 0, 0.001, "nothing occupied: the escort keeps its bearing")
end

--- The same, through the real probe: a static standing on the escort's wanted spot (bearing 0, 150 m
--- north of the FARP) keeps the escort there when it is one of this FARP's props, and moves it when it is
--- anything else. Both sides, so the test cannot pass by never moving anything.
function TestVeafGrassBuildFarpEscort:_escortBearingBeside(staticName)
  veafGrass.isSpotOccupied = self._occupied
  local search = world.searchObjects
  world.searchObjects = function(category, volume, handler)
    local p = volume.params.point
    if category == Object.Category.STATIC and math.abs(p.x - 1150) < 20 and p.z >= 1990 and p.z <= 2040 then
      handler({
        isExist = function()
          return true
        end,
        getName = function()
          return staticName
        end,
      })
    end
  end
  veafGrass.buildFarpUnits(_editorFarp(), nil, nil, true)
  world.searchObjects = search
  return self:_escortBearing()
end

function TestVeafGrassBuildFarpEscort:test_a_prop_of_its_own_farp_on_the_escort_spot_does_not_move_it()
  luaunit.assertAlmostEquals(self:_escortBearingBeside("FARP FARP Alpha unit #4"), 0, 0.001)
end

function TestVeafGrassBuildFarpEscort:test_anything_else_on_the_escort_spot_still_moves_it()
  luaunit.assertNotAlmostEquals(self:_escortBearingBeside("Ural parked here"), 0, 0.001)
end

os.exit(luaunit.LuaUnit.run())
