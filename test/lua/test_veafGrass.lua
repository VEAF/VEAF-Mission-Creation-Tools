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

os.exit(luaunit.LuaUnit.run())
