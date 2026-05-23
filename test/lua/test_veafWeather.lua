--- Unit tests for veafWeather.lua
---
--- Run:  lua test/lua/test_veafWeather.lua
---
--- Covers:
---   - veafWeatherUnitSystem.defaultForTypeName  (per-aircraft unit system selection)
---   - veafWeatherUnitSystem.defaultForTheatre   (per-theatre unit system selection)
---   - veafWeatherData:appendString              (string building helper)
---   - veafWeatherData:toStringTemperature       (temperature formatting)
---   - veafWeatherData:getNormalizedWindDirection (true/magnetic normalisation)
---   - veafWeatherData:toStringWind              (wind speed/direction formatting)
---   - veafWeatherData:toStringPressure          (pressure formatting, all unit systems)
---   - veafWeatherData:isCavok                   (CAVOK determination)
---   - veafWeatherData:getCarrierCase            (Case I/II/III determination)

local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
luaunit = dofile(_base .. "/luaunit.lua")
dofile(_base .. "/dcs_mocks.lua")
local src = _base .. "/../../src/scripts/veaf"
dofile(src .. "/veaf.lua")
dofile(src .. "/veafTime.lua")
dofile(src .. "/veafWeather.lua")

-- ----------------------------------------------------------------------------
-- Helpers
-- ----------------------------------------------------------------------------

--- Build a minimal veafWeatherData instance without calling :create().
local function weatherInstance(fields)
  return setmetatable(fields, veafWeatherData)
end

-- ============================================================================
-- TestVeafWeatherUnitSystem
-- ============================================================================
TestVeafWeatherUnitSystem = {}

function TestVeafWeatherUnitSystem:setUp()
  dcs_mocks.reset()
  env.mission.date    = { Day = 1, Month = 1, Year = 2024 }
  env.mission.theatre = "Caucasus"
end

-- -----------------------------------------------------------------------
-- defaultForTypeName — known aircraft families
-- -----------------------------------------------------------------------
function TestVeafWeatherUnitSystem:test_typeName_FA18_is_Faa()    luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("FA-18C_hornet"),    veafWeatherUnitSystem.Systems.Faa) end
function TestVeafWeatherUnitSystem:test_typeName_A10C_is_Faa()    luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("A-10C"),             veafWeatherUnitSystem.Systems.Faa) end
function TestVeafWeatherUnitSystem:test_typeName_F16_is_Faa()     luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("F-16C_50"),           veafWeatherUnitSystem.Systems.Faa) end
function TestVeafWeatherUnitSystem:test_typeName_UH1H_is_Faa()    luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("UH-1H"),              veafWeatherUnitSystem.Systems.Faa) end

function TestVeafWeatherUnitSystem:test_typeName_Ka50_is_MetricEastern()  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("Ka-50"),   veafWeatherUnitSystem.Systems.MetricEastern) end
function TestVeafWeatherUnitSystem:test_typeName_Mi24_is_MetricEastern()  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("Mi-24P"),  veafWeatherUnitSystem.Systems.MetricEastern) end
function TestVeafWeatherUnitSystem:test_typeName_Su27_is_MetricEastern()  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("Su-27"),   veafWeatherUnitSystem.Systems.MetricEastern) end

function TestVeafWeatherUnitSystem:test_typeName_SA342L_is_Metric() luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("SA342L"), veafWeatherUnitSystem.Systems.Metric) end
function TestVeafWeatherUnitSystem:test_typeName_SA342M_is_Metric() luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("SA342M"), veafWeatherUnitSystem.Systems.Metric) end

function TestVeafWeatherUnitSystem:test_typeName_AH64_is_FaaMetric() luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("AH-64D_BLK_II"), veafWeatherUnitSystem.Systems.FaaMetric) end

-- unknown type falls back to the default (Icao)
function TestVeafWeatherUnitSystem:test_typeName_unknown_is_default()
  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("SomeFutureJet"), veafWeatherUnitSystem.DefaultUnitSystem)
end

-- -----------------------------------------------------------------------
-- defaultForTheatre — theatre-based unit system
-- -----------------------------------------------------------------------
function TestVeafWeatherUnitSystem:test_theatre_Nevada_is_Faa()
  env.mission.theatre = "Nevada"
  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTheatre(), veafWeatherUnitSystem.Systems.Faa)
end

function TestVeafWeatherUnitSystem:test_theatre_MarianaIslands_is_Faa()
  env.mission.theatre = "MarianaIslands"
  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTheatre(), veafWeatherUnitSystem.Systems.Faa)
end

function TestVeafWeatherUnitSystem:test_theatre_Caucasus_is_IcaoMetric()
  env.mission.theatre = "Caucasus"
  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTheatre(), veafWeatherUnitSystem.Systems.IcaoMetric)
end

function TestVeafWeatherUnitSystem:test_theatre_Syria_is_default()
  env.mission.theatre = "Syria"
  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTheatre(), veafWeatherUnitSystem.DefaultUnitSystem)
end

function TestVeafWeatherUnitSystem:test_theatre_PersianGulf_is_default()
  env.mission.theatre = "PersianGulf"
  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTheatre(), veafWeatherUnitSystem.DefaultUnitSystem)
end

-- -----------------------------------------------------------------------
-- Unit system contents validation
-- -----------------------------------------------------------------------
function TestVeafWeatherUnitSystem:test_Faa_has_kts_wind()
  luaunit.assertTrue(veaf.tableContains(veafWeatherUnitSystem.Systems.Faa.WindSpeeds, veafWeatherUnitSystem.Units.Kts))
end

function TestVeafWeatherUnitSystem:test_IcaoMetric_has_mps_wind()
  luaunit.assertTrue(veaf.tableContains(veafWeatherUnitSystem.Systems.IcaoMetric.WindSpeeds, veafWeatherUnitSystem.Units.Mps))
end

function TestVeafWeatherUnitSystem:test_Faa_pressure_is_inHg()
  luaunit.assertTrue(veaf.tableContains(veafWeatherUnitSystem.Systems.Faa.Pressures, veafWeatherUnitSystem.Units.InHg))
  luaunit.assertFalse(veaf.tableContains(veafWeatherUnitSystem.Systems.Faa.Pressures, veafWeatherUnitSystem.Units.Hpa))
end

function TestVeafWeatherUnitSystem:test_MetricEastern_pressure_is_mmHg()
  luaunit.assertTrue(veaf.tableContains(veafWeatherUnitSystem.Systems.MetricEastern.Pressures, veafWeatherUnitSystem.Units.MmHg))
end

-- ============================================================================
-- TestVeafWeatherAppendString
-- ============================================================================
TestVeafWeatherAppendString = {}

function TestVeafWeatherAppendString:test_nil_and_string()
  luaunit.assertEquals(veafWeatherData:appendString(nil, "hello"), "hello")
end

function TestVeafWeatherAppendString:test_empty_and_string()
  luaunit.assertEquals(veafWeatherData:appendString("", "world"), "world")
end

function TestVeafWeatherAppendString:test_string_and_nil()
  luaunit.assertEquals(veafWeatherData:appendString("hello", nil), "hello")
end

function TestVeafWeatherAppendString:test_string_and_empty()
  luaunit.assertEquals(veafWeatherData:appendString("hello", ""), "hello")
end

function TestVeafWeatherAppendString:test_two_strings_joined_with_pipe()
  luaunit.assertEquals(veafWeatherData:appendString("hello", "world"), "hello|world")
end

function TestVeafWeatherAppendString:test_both_nil()
  luaunit.assertEquals(veafWeatherData:appendString(nil, nil), "")
end

-- ============================================================================
-- TestVeafWeatherTemperature
-- ============================================================================
TestVeafWeatherTemperature = {}

function TestVeafWeatherTemperature:test_positive_integer()
  luaunit.assertEquals(veafWeatherData:toStringTemperature(15), "15°C")
end

function TestVeafWeatherTemperature:test_zero()
  luaunit.assertEquals(veafWeatherData:toStringTemperature(0), "0°C")
end

function TestVeafWeatherTemperature:test_negative()
  luaunit.assertEquals(veafWeatherData:toStringTemperature(-5), "-5°C")
end

function TestVeafWeatherTemperature:test_rounds_up()
  luaunit.assertEquals(veafWeatherData:toStringTemperature(15.7), "16°C")
end

function TestVeafWeatherTemperature:test_rounds_at_half()
  luaunit.assertEquals(veafWeatherData:toStringTemperature(15.5), "16°C")
end

function TestVeafWeatherTemperature:test_rounds_down()
  luaunit.assertEquals(veafWeatherData:toStringTemperature(15.2), "15°C")
end

-- ============================================================================
-- TestVeafWeatherWindDirection
-- ============================================================================
TestVeafWeatherWindDirection = {}

function TestVeafWeatherWindDirection:setUp()
  env.mission.theatre = "Caucasus" -- declination = 6
end

function TestVeafWeatherWindDirection:test_normal_direction_unchanged()
  luaunit.assertEquals(veafWeatherData:getNormalizedWindDirection(270, false), 270)
end

function TestVeafWeatherWindDirection:test_zero_normalized_to_360()
  luaunit.assertEquals(veafWeatherData:getNormalizedWindDirection(0, false), 360)
end

function TestVeafWeatherWindDirection:test_360_unchanged()
  luaunit.assertEquals(veafWeatherData:getNormalizedWindDirection(360, false), 360)
end

function TestVeafWeatherWindDirection:test_magnetic_subtracts_declination()
  -- Caucasus declination = 6; 90 - 6 = 84
  luaunit.assertEquals(veafWeatherData:getNormalizedWindDirection(90, true), 84)
end

function TestVeafWeatherWindDirection:test_magnetic_wraps_below_zero()
  -- 3 - 6 = -3 → +360 = 357
  luaunit.assertEquals(veafWeatherData:getNormalizedWindDirection(3, true), 357)
end

function TestVeafWeatherWindDirection:test_magnetic_zero_result_becomes_360()
  -- 6 - 6 = 0 → normalized to 360
  luaunit.assertEquals(veafWeatherData:getNormalizedWindDirection(6, true), 360)
end

-- ============================================================================
-- TestVeafWeatherWind
-- ============================================================================
TestVeafWeatherWind = {}

function TestVeafWeatherWind:setUp()
  env.mission.theatre = "Caucasus"
end

function TestVeafWeatherWind:test_calm_at_low_speed()
  luaunit.assertEquals(veafWeatherData:toStringWind(veafWeatherUnitSystem.Systems.Icao, 270, 0.2, false), "calm")
end

function TestVeafWeatherWind:test_calm_at_exactly_half_knot()
  luaunit.assertEquals(veafWeatherData:toStringWind(veafWeatherUnitSystem.Systems.Icao, 270, 0.5, false), "calm")
end

function TestVeafWeatherWind:test_icao_kts_format()
  -- 10 m/s * 1.94384 = 19.4384 kts → %d → 19
  luaunit.assertEquals(veafWeatherData:toStringWind(veafWeatherUnitSystem.Systems.Icao, 270, 10, false), "270°T @ 19kts")
end

function TestVeafWeatherWind:test_zero_direction_normalized_to_360()
  luaunit.assertEquals(veafWeatherData:toStringWind(veafWeatherUnitSystem.Systems.Icao, 0, 10, false), "360°T @ 19kts")
end

function TestVeafWeatherWind:test_icaometric_mps_format()
  -- IcaoMetric uses Mps
  luaunit.assertEquals(veafWeatherData:toStringWind(veafWeatherUnitSystem.Systems.IcaoMetric, 180, 5, false), "180°T @ 5m/s")
end

function TestVeafWeatherWind:test_full_system_kts_and_mps_joined()
  -- Full system has both Kts and Mps
  local result = veafWeatherData:toStringWind(veafWeatherUnitSystem.Systems.Full, 90, 10, false)
  luaunit.assertEquals(result, "090°T @ 19kts|10m/s")
end

function TestVeafWeatherWind:test_magnetic_direction_suffix()
  local result = veafWeatherData:toStringWind(veafWeatherUnitSystem.Systems.Icao, 270, 10, true)
  -- 270 - 6 (Caucasus) = 264
  luaunit.assertStrContains(result, "264°M")
end

function TestVeafWeatherWind:test_three_digit_direction_format()
  -- Direction 45 → "045°T"
  local result = veafWeatherData:toStringWind(veafWeatherUnitSystem.Systems.Icao, 45, 5, false)
  luaunit.assertStrContains(result, "045°T")
end

-- ============================================================================
-- TestVeafWeatherPressure
-- ============================================================================
TestVeafWeatherPressure = {}

function TestVeafWeatherPressure:test_icao_hpa_only()
  local result = veafWeatherData:toStringPressure(veafWeatherUnitSystem.Systems.Icao, 1013)
  luaunit.assertEquals(result, "1013Hpa")
end

function TestVeafWeatherPressure:test_faa_inhg_only()
  -- 1013 * 0.02953 = 29.91389 → "29.91inHg"
  local result = veafWeatherData:toStringPressure(veafWeatherUnitSystem.Systems.Faa, 1013)
  luaunit.assertStrContains(result, "inHg")
  luaunit.assertStrContains(result, "29.91")
end

function TestVeafWeatherPressure:test_metriceastern_mmhg_only()
  -- 1013 * 0.75006375541921 ≈ 759.81 → %.0f → "760mmHg"
  local result = veafWeatherData:toStringPressure(veafWeatherUnitSystem.Systems.MetricEastern, 1013)
  luaunit.assertStrContains(result, "mmHg")
  luaunit.assertStrContains(result, "760")
end

function TestVeafWeatherPressure:test_full_system_all_three_units()
  local result = veafWeatherData:toStringPressure(veafWeatherUnitSystem.Systems.Full, 1013)
  luaunit.assertStrContains(result, "Hpa")
  luaunit.assertStrContains(result, "inHg")
  luaunit.assertStrContains(result, "mmHg")
end

function TestVeafWeatherPressure:test_icaometric_hpa_only()
  -- IcaoMetric uses same pressure unit as Icao (Hpa)
  local result = veafWeatherData:toStringPressure(veafWeatherUnitSystem.Systems.IcaoMetric, 1013)
  luaunit.assertEquals(result, "1013Hpa")
end

-- ============================================================================
-- TestVeafWeatherCavok
-- ============================================================================
TestVeafWeatherCavok = {}

function TestVeafWeatherCavok:test_no_clouds_returns_false()
  -- Clouds = nil → getNormalizedCloudBaseMeters returns nil → isCavok returns false
  local wd = weatherInstance({ Clouds = nil, AltitudeMeter = 0, VisibilityMeters = 10000, Precipitation = false, Dust = false })
  luaunit.assertFalse(wd:isCavok())
end

function TestVeafWeatherCavok:test_zero_density_returns_false()
  -- Density <= 0 → getNormalizedCloudBaseMeters returns nil → false
  local wd = weatherInstance({ Clouds = { Density = 0, BaseMeters = 3000 }, AltitudeMeter = 0, VisibilityMeters = 10000, Precipitation = false, Dust = false })
  luaunit.assertFalse(wd:isCavok())
end

function TestVeafWeatherCavok:test_clouds_above_5000ft_good_vis_is_cavok()
  -- 3000m AGL → 9842 ft > 5000 ft, vis >= 10000, no precip, no dust → CAVOK
  local wd = weatherInstance({ Clouds = { Density = 4, BaseMeters = 3000 }, AltitudeMeter = 0, VisibilityMeters = 10000, Precipitation = false, Dust = false })
  luaunit.assertTrue(wd:isCavok())
end

function TestVeafWeatherCavok:test_clouds_below_5000ft_returns_false()
  -- 1000m → 3280 ft < 5000 ft → false
  local wd = weatherInstance({ Clouds = { Density = 4, BaseMeters = 1000 }, AltitudeMeter = 0, VisibilityMeters = 10000, Precipitation = false, Dust = false })
  luaunit.assertFalse(wd:isCavok())
end

function TestVeafWeatherCavok:test_altitude_reduces_agl_height()
  -- Cloud ASL 3000, airfield at 2000 → AGL height = 1000m = 3280ft < 5000ft → false
  local wd = weatherInstance({ Clouds = { Density = 4, BaseMeters = 3000 }, AltitudeMeter = 2000, VisibilityMeters = 10000, Precipitation = false, Dust = false })
  luaunit.assertFalse(wd:isCavok())
end

function TestVeafWeatherCavok:test_low_visibility_returns_false()
  local wd = weatherInstance({ Clouds = { Density = 4, BaseMeters = 3000 }, AltitudeMeter = 0, VisibilityMeters = 8000, Precipitation = false, Dust = false })
  luaunit.assertFalse(wd:isCavok())
end

function TestVeafWeatherCavok:test_precipitation_returns_false()
  local wd = weatherInstance({ Clouds = { Density = 4, BaseMeters = 3000 }, AltitudeMeter = 0, VisibilityMeters = 10000, Precipitation = true, Dust = false })
  luaunit.assertFalse(wd:isCavok())
end

function TestVeafWeatherCavok:test_dust_returns_false()
  local wd = weatherInstance({ Clouds = { Density = 4, BaseMeters = 3000 }, AltitudeMeter = 0, VisibilityMeters = 10000, Precipitation = false, Dust = true })
  luaunit.assertFalse(wd:isCavok())
end

-- ============================================================================
-- TestVeafWeatherCarrierCase
-- ============================================================================
TestVeafWeatherCarrierCase = {}

function TestVeafWeatherCarrierCase:setUp()
  dcs_mocks.reset()
  env.mission.date    = { Day = 1, Month = 1, Year = 2024 }
  env.mission.theatre = "Caucasus"
end

-- AbsTime = 0 → midnight UTC at equator → aeronautical night → Case III
function TestVeafWeatherCarrierCase:test_night_always_case3()
  local wd = weatherInstance({
    Vec3 = { x = 0, y = 0, z = 0 }, AbsTime = 0,
    Clouds = nil, VisibilityMeters = 20000,
  })
  luaunit.assertEquals(wd:getCarrierCase(), 3)
end

-- AbsTime = 43200 (noon UTC at equator, Jan 1) → daytime
-- No effective clouds (density ≤ 4), good vis → Case I
function TestVeafWeatherCarrierCase:test_day_good_conditions_case1()
  local wd = weatherInstance({
    Vec3 = { x = 0, y = 0, z = 0 }, AbsTime = 43200,
    Clouds = { Density = 3, BaseMeters = 2000 }, -- density ≤ 4, not counted
    VisibilityMeters = 20000,
  })
  luaunit.assertEquals(wd:getCarrierCase(), 1)
end

-- Daytime, clouds with density 5 at 600m (> feetToMeters(1000)=305m but < feetToMeters(3000)=914m) → Case II
function TestVeafWeatherCarrierCase:test_day_mid_clouds_case2()
  local wd = weatherInstance({
    Vec3 = { x = 0, y = 0, z = 0 }, AbsTime = 43200,
    Clouds = { Density = 5, BaseMeters = 600 }, -- 600m > 305 but < 914
    VisibilityMeters = 15000, -- > NMToMeters(5) = 9260m
  })
  luaunit.assertEquals(wd:getCarrierCase(), 2)
end

-- Daytime, poor visibility → Case III
function TestVeafWeatherCarrierCase:test_day_poor_vis_case3()
  local wd = weatherInstance({
    Vec3 = { x = 0, y = 0, z = 0 }, AbsTime = 43200,
    Clouds = { Density = 3, BaseMeters = 2000 },
    VisibilityMeters = 5000, -- < NMToMeters(5) = 9260m
  })
  luaunit.assertEquals(wd:getCarrierCase(), 3)
end

-- Daytime, clouds low (below feetToMeters(1000) = 305m) → Case III
function TestVeafWeatherCarrierCase:test_day_low_clouds_case3()
  local wd = weatherInstance({
    Vec3 = { x = 0, y = 0, z = 0 }, AbsTime = 43200,
    Clouds = { Density = 5, BaseMeters = 200 }, -- 200m < 305m → Case III
    VisibilityMeters = 20000,
  })
  luaunit.assertEquals(wd:getCarrierCase(), 3)
end

-- Daytime, no clouds at all (nil) → vis OK → Case I
function TestVeafWeatherCarrierCase:test_day_no_clouds_case1()
  local wd = weatherInstance({
    Vec3 = { x = 0, y = 0, z = 0 }, AbsTime = 43200,
    Clouds = nil,
    VisibilityMeters = 20000,
  })
  luaunit.assertEquals(wd:getCarrierCase(), 1)
end

-- ============================================================================
-- TestVeafWeatherGetWind
-- ============================================================================
TestVeafWeatherGetWind = {}

function TestVeafWeatherGetWind:setUp()
  dcs_mocks.reset()
end

-- Helper: override atmosphere.getWind to return a fixed vector
local function setWind(x, z)
  atmosphere.getWind = function(_) return { x = x, y = 0, z = z } end
  atmosphere.getWindWithTurbulence = function(_) return { x = x, y = 0, z = z } end
end

-- No wind → direction 0 (calm), speed 0
function TestVeafWeatherGetWind:test_calm_wind()
  setWind(0, 0)
  local dir, spd = veafWeather.getWind({ x = 0, y = 0, z = 0 }, 0)
  luaunit.assertEquals(spd, 0)
  -- direction is undefined for calm wind; just check it's an integer in [1,360]
  luaunit.assertTrue(dir >= 1 and dir <= 360)
end

-- Wind blowing toward north (x=1, z=0) → "from" direction should be south = 180
function TestVeafWeatherGetWind:test_wind_toward_north_from_south()
  setWind(1, 0)
  local dir, _ = veafWeather.getWind({ x = 0, y = 0, z = 0 }, 0)
  luaunit.assertEquals(dir, 180)
end

-- Wind blowing toward east (x=0, z=1) → "from" direction should be west = 270
function TestVeafWeatherGetWind:test_wind_toward_east_from_west()
  setWind(0, 1)
  local dir, _ = veafWeather.getWind({ x = 0, y = 0, z = 0 }, 0)
  luaunit.assertEquals(dir, 270)
end

-- Wind blowing toward south (x=-1, z=0) → "from" direction should be north = 360
function TestVeafWeatherGetWind:test_wind_toward_south_from_north()
  setWind(-1, 0)
  local dir, _ = veafWeather.getWind({ x = 0, y = 0, z = 0 }, 0)
  luaunit.assertEquals(dir, 360)
end

-- Wind blowing toward west (x=0, z=-1) → "from" direction should be east = 90
function TestVeafWeatherGetWind:test_wind_toward_west_from_east()
  setWind(0, -1)
  local dir, _ = veafWeather.getWind({ x = 0, y = 0, z = 0 }, 0)
  luaunit.assertEquals(dir, 90)
end

-- Result direction must be integer in [1, 360]
function TestVeafWeatherGetWind:test_direction_is_integer_in_range()
  setWind(1, 1)
  local dir, _ = veafWeather.getWind({ x = 0, y = 0, z = 0 }, 0)
  luaunit.assertEquals(dir, math.floor(dir)) -- integer
  luaunit.assertTrue(dir >= 1 and dir <= 360)
end

-- Speed matches the 2D magnitude of the wind vector
function TestVeafWeatherGetWind:test_speed_matches_magnitude()
  setWind(3, 4)
  local _, spd = veafWeather.getWind({ x = 0, y = 0, z = 0 }, 0)
  luaunit.assertAlmostEquals(spd, 5.0, 1e-6) -- sqrt(9+16)
end

-- bTurbulence flag routes to getWindWithTurbulence
function TestVeafWeatherGetWind:test_turbulence_flag()
  local called = false
  atmosphere.getWindWithTurbulence = function(_)
    called = true
    return { x = 1, y = 0, z = 0 }
  end
  atmosphere.getWind = function(_) return { x = 0, y = 0, z = 0 } end
  veafWeather.getWind({ x = 0, y = 0, z = 0 }, 0, true)
  luaunit.assertTrue(called)
end

-- nil vec3 guard → returns 0, 0 without error
function TestVeafWeatherGetWind:test_nil_vec3_returns_zero()
  local dir, spd = veafWeather.getWind(nil, 0)
  luaunit.assertEquals(dir, 0)
  luaunit.assertEquals(spd, 0)
end

-- ============================================================================
-- Run
-- ============================================================================
os.exit(luaunit.LuaUnit.run())
