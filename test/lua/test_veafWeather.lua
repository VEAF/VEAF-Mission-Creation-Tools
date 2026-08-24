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
dofile(src .. "/veafI18n.lua")
-- veafWeather reaches into veafAirbases for the welcome brief (the nearest airbase and its runway
-- in service), and veafEventHandler for the slot-entry callback. Loaded here rather than stubbed:
-- the brief's only real risk is calling the runway lookup wrongly, and a stub would hide that.
dofile(src .. "/veafEventHandler.lua")
dofile(src .. "/veafAirbases.lua")
dofile(src .. "/veafWeather.lua")

-- The rendering assertions below pin the English wording; the weather report is
-- now localized (FR is the default language) so force English for these tests.
-- FR coverage of the weather catalog lives in test_veafI18n.lua.
veaf.config.language = "en"

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
  env.mission.date = { Day = 1, Month = 1, Year = 2024 }
  env.mission.theatre = "Caucasus"
end

-- -----------------------------------------------------------------------
-- defaultForTypeName — known aircraft families
-- -----------------------------------------------------------------------
function TestVeafWeatherUnitSystem:test_typeName_FA18_is_Faa()
  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("FA-18C_hornet"), veafWeatherUnitSystem.Systems.Faa)
end
function TestVeafWeatherUnitSystem:test_typeName_A10C_is_Faa()
  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("A-10C"), veafWeatherUnitSystem.Systems.Faa)
end
function TestVeafWeatherUnitSystem:test_typeName_F16_is_Faa()
  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("F-16C_50"), veafWeatherUnitSystem.Systems.Faa)
end
function TestVeafWeatherUnitSystem:test_typeName_UH1H_is_Faa()
  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("UH-1H"), veafWeatherUnitSystem.Systems.Faa)
end

function TestVeafWeatherUnitSystem:test_typeName_Ka50_is_MetricEastern()
  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("Ka-50"), veafWeatherUnitSystem.Systems.MetricEastern)
end
function TestVeafWeatherUnitSystem:test_typeName_Mi24_is_MetricEastern()
  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("Mi-24P"), veafWeatherUnitSystem.Systems.MetricEastern)
end
function TestVeafWeatherUnitSystem:test_typeName_Su27_is_MetricEastern()
  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("Su-27"), veafWeatherUnitSystem.Systems.MetricEastern)
end

function TestVeafWeatherUnitSystem:test_typeName_SA342L_is_Metric()
  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("SA342L"), veafWeatherUnitSystem.Systems.Metric)
end
function TestVeafWeatherUnitSystem:test_typeName_SA342M_is_Metric()
  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("SA342M"), veafWeatherUnitSystem.Systems.Metric)
end

function TestVeafWeatherUnitSystem:test_typeName_AH64_is_FaaMetric()
  luaunit.assertEquals(veafWeatherUnitSystem.defaultForTypeName("AH-64D_BLK_II"), veafWeatherUnitSystem.Systems.FaaMetric)
end

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
  local wd = weatherInstance({
    Clouds = { Density = 0, BaseMeters = 3000 },
    AltitudeMeter = 0,
    VisibilityMeters = 10000,
    Precipitation = false,
    Dust = false,
  })
  luaunit.assertFalse(wd:isCavok())
end

function TestVeafWeatherCavok:test_clouds_above_5000ft_good_vis_is_cavok()
  -- 3000m AGL → 9842 ft > 5000 ft, vis >= 10000, no precip, no dust → CAVOK
  local wd = weatherInstance({
    Clouds = { Density = 4, BaseMeters = 3000 },
    AltitudeMeter = 0,
    VisibilityMeters = 10000,
    Precipitation = false,
    Dust = false,
  })
  luaunit.assertTrue(wd:isCavok())
end

function TestVeafWeatherCavok:test_clouds_below_5000ft_returns_false()
  -- 1000m → 3280 ft < 5000 ft → false
  local wd = weatherInstance({
    Clouds = { Density = 4, BaseMeters = 1000 },
    AltitudeMeter = 0,
    VisibilityMeters = 10000,
    Precipitation = false,
    Dust = false,
  })
  luaunit.assertFalse(wd:isCavok())
end

function TestVeafWeatherCavok:test_altitude_reduces_agl_height()
  -- Cloud ASL 3000, airfield at 2000 → AGL height = 1000m = 3280ft < 5000ft → false
  local wd = weatherInstance({
    Clouds = { Density = 4, BaseMeters = 3000 },
    AltitudeMeter = 2000,
    VisibilityMeters = 10000,
    Precipitation = false,
    Dust = false,
  })
  luaunit.assertFalse(wd:isCavok())
end

function TestVeafWeatherCavok:test_low_visibility_returns_false()
  local wd = weatherInstance({
    Clouds = { Density = 4, BaseMeters = 3000 },
    AltitudeMeter = 0,
    VisibilityMeters = 8000,
    Precipitation = false,
    Dust = false,
  })
  luaunit.assertFalse(wd:isCavok())
end

function TestVeafWeatherCavok:test_precipitation_returns_false()
  local wd = weatherInstance({
    Clouds = { Density = 4, BaseMeters = 3000 },
    AltitudeMeter = 0,
    VisibilityMeters = 10000,
    Precipitation = true,
    Dust = false,
  })
  luaunit.assertFalse(wd:isCavok())
end

function TestVeafWeatherCavok:test_dust_returns_false()
  local wd = weatherInstance({
    Clouds = { Density = 4, BaseMeters = 3000 },
    AltitudeMeter = 0,
    VisibilityMeters = 10000,
    Precipitation = false,
    Dust = true,
  })
  luaunit.assertFalse(wd:isCavok())
end

-- ============================================================================
-- TestVeafWeatherCarrierCase
-- ============================================================================
TestVeafWeatherCarrierCase = {}

function TestVeafWeatherCarrierCase:setUp()
  dcs_mocks.reset()
  env.mission.date = { Day = 1, Month = 1, Year = 2024 }
  env.mission.theatre = "Caucasus"
end

-- AbsTime = 0 → midnight UTC at equator → aeronautical night → Case III
function TestVeafWeatherCarrierCase:test_night_always_case3()
  local wd = weatherInstance({
    Vec3 = { x = 0, y = 0, z = 0 },
    AbsTime = 0,
    Clouds = nil,
    VisibilityMeters = 20000,
  })
  luaunit.assertEquals(wd:getCarrierCase(), 3)
end

-- AbsTime = 43200 (noon UTC at equator, Jan 1) → daytime
-- No effective clouds (density ≤ 4), good vis → Case I
function TestVeafWeatherCarrierCase:test_day_good_conditions_case1()
  local wd = weatherInstance({
    Vec3 = { x = 0, y = 0, z = 0 },
    AbsTime = 43200,
    Clouds = { Density = 3, BaseMeters = 2000 }, -- density ≤ 4, not counted
    VisibilityMeters = 20000,
  })
  luaunit.assertEquals(wd:getCarrierCase(), 1)
end

-- Daytime, clouds with density 5 at 600m (> feetToMeters(1000)=305m but < feetToMeters(3000)=914m) → Case II
function TestVeafWeatherCarrierCase:test_day_mid_clouds_case2()
  local wd = weatherInstance({
    Vec3 = { x = 0, y = 0, z = 0 },
    AbsTime = 43200,
    Clouds = { Density = 5, BaseMeters = 600 }, -- 600m > 305 but < 914
    VisibilityMeters = 15000, -- > NMToMeters(5) = 9260m
  })
  luaunit.assertEquals(wd:getCarrierCase(), 2)
end

-- Daytime, poor visibility → Case III
function TestVeafWeatherCarrierCase:test_day_poor_vis_case3()
  local wd = weatherInstance({
    Vec3 = { x = 0, y = 0, z = 0 },
    AbsTime = 43200,
    Clouds = { Density = 3, BaseMeters = 2000 },
    VisibilityMeters = 5000, -- < NMToMeters(5) = 9260m
  })
  luaunit.assertEquals(wd:getCarrierCase(), 3)
end

-- Daytime, clouds low (below feetToMeters(1000) = 305m) → Case III
function TestVeafWeatherCarrierCase:test_day_low_clouds_case3()
  local wd = weatherInstance({
    Vec3 = { x = 0, y = 0, z = 0 },
    AbsTime = 43200,
    Clouds = { Density = 5, BaseMeters = 200 }, -- 200m < 305m → Case III
    VisibilityMeters = 20000,
  })
  luaunit.assertEquals(wd:getCarrierCase(), 3)
end

-- Daytime, no clouds at all (nil) → vis OK → Case I
function TestVeafWeatherCarrierCase:test_day_no_clouds_case1()
  local wd = weatherInstance({
    Vec3 = { x = 0, y = 0, z = 0 },
    AbsTime = 43200,
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
  atmosphere.getWind = function(_)
    return { x = x, y = 0, z = z }
  end
  atmosphere.getWindWithTurbulence = function(_)
    return { x = x, y = 0, z = z }
  end
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
  atmosphere.getWind = function(_)
    return { x = 0, y = 0, z = 0 }
  end
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
-- TestVeafWeatherCloudBase
-- ============================================================================
TestVeafWeatherCloudBase = {}

function TestVeafWeatherCloudBase:setUp()
  dcs_mocks.reset()
  env.mission.date = { Day = 1, Month = 1, Year = 2024 }
  env.mission.theatre = "Caucasus"
end

function TestVeafWeatherCloudBase:test_nil_clouds_returns_nil()
  local w = weatherInstance({ Clouds = nil, AltitudeMeter = 0 })
  luaunit.assertNil(w:getNormalizedCloudBaseMeters(false))
end

function TestVeafWeatherCloudBase:test_zero_density_returns_nil()
  local w = weatherInstance({ Clouds = { Density = 0, BaseMeters = 2000 }, AltitudeMeter = 0 })
  luaunit.assertNil(w:getNormalizedCloudBaseMeters(false))
end

function TestVeafWeatherCloudBase:test_with_clouds_returns_base()
  local w = weatherInstance({ Clouds = { Density = 3, BaseMeters = 2000 }, AltitudeMeter = 0 })
  local base = w:getNormalizedCloudBaseMeters(false)
  luaunit.assertNotNil(base)
  luaunit.assertTrue(base > 0)
end

function TestVeafWeatherCloudBase:test_height_mode_subtracts_altitude()
  local w = weatherInstance({ Clouds = { Density = 3, BaseMeters = 2000 }, AltitudeMeter = 500 })
  local asl = w:getNormalizedCloudBaseMeters(false)
  local agl = w:getNormalizedCloudBaseMeters(true)
  luaunit.assertEquals(agl, asl - 500)
end

-- ============================================================================
-- TestVeafWeatherCloudDensity
-- ============================================================================
TestVeafWeatherCloudDensity = {}

function TestVeafWeatherCloudDensity:setUp()
  dcs_mocks.reset()
end

function TestVeafWeatherCloudDensity:test_nil_clouds_returns_zero()
  local w = weatherInstance({ Clouds = nil })
  luaunit.assertEquals(w:getNormalizedCloudsDensity(), 0)
end

function TestVeafWeatherCloudDensity:test_zero_density_returns_zero()
  local w = weatherInstance({ Clouds = { Density = 0, BaseMeters = 2000 } })
  luaunit.assertEquals(w:getNormalizedCloudsDensity(), 0)
end

function TestVeafWeatherCloudDensity:test_density3_maps_to_scattered()
  -- DCS density 3 → _cloudDensityOktas maps to Scattered (2)
  local w = weatherInstance({ Clouds = { Density = 3, BaseMeters = 2000 } })
  luaunit.assertEquals(w:getNormalizedCloudsDensity(), 2)
end

-- ============================================================================
-- TestVeafWeatherCloudsString
-- ============================================================================
TestVeafWeatherCloudsString = {}

function TestVeafWeatherCloudsString:setUp()
  dcs_mocks.reset()
end

function TestVeafWeatherCloudsString:test_clear_clouds()
  local w = weatherInstance({ Clouds = { Density = 0, BaseMeters = 0 }, AltitudeMeter = 0 })
  luaunit.assertStrContains(w:toStringClouds(veafWeatherUnitSystem.Systems.Faa, false), "No clouds")
end

function TestVeafWeatherCloudsString:test_scattered_clouds_asl()
  -- DCS density=3 → Scattered, base=2000m
  local w = weatherInstance({ Clouds = { Density = 3, BaseMeters = 2000 }, AltitudeMeter = 0 })
  local s = w:toStringClouds(veafWeatherUnitSystem.Systems.Faa, false)
  luaunit.assertStrContains(s, "Scattered")
  luaunit.assertStrContains(s, "ASL")
end

function TestVeafWeatherCloudsString:test_broken_clouds()
  -- DCS density=5 → _cloudDensityOktas maps to Broken (3)
  local w = weatherInstance({ Clouds = { Density = 5, BaseMeters = 2000 }, AltitudeMeter = 0 })
  luaunit.assertStrContains(w:toStringClouds(veafWeatherUnitSystem.Systems.Faa, false), "Broken")
end

function TestVeafWeatherCloudsString:test_overcast_clouds()
  -- DCS density=7 → Overcast (4)
  local w = weatherInstance({ Clouds = { Density = 7, BaseMeters = 2000 }, AltitudeMeter = 0 })
  luaunit.assertStrContains(w:toStringClouds(veafWeatherUnitSystem.Systems.Faa, false), "Overcast")
end

function TestVeafWeatherCloudsString:test_few_clouds()
  -- DCS density=1 → Few (1)
  local w = weatherInstance({ Clouds = { Density = 1, BaseMeters = 2000 }, AltitudeMeter = 0 })
  luaunit.assertStrContains(w:toStringClouds(veafWeatherUnitSystem.Systems.Faa, false), "Few")
end

function TestVeafWeatherCloudsString:test_height_mode_shows_agl()
  local w = weatherInstance({ Clouds = { Density = 3, BaseMeters = 2000 }, AltitudeMeter = 0 })
  luaunit.assertStrContains(w:toStringClouds(veafWeatherUnitSystem.Systems.Faa, true), "AGL")
end

-- ============================================================================
-- TestVeafWeatherVisibility
-- ============================================================================
TestVeafWeatherVisibility = {}

function TestVeafWeatherVisibility:setUp()
  dcs_mocks.reset()
end

function TestVeafWeatherVisibility:test_high_visibility_non_empty()
  local w = weatherInstance({ VisibilityMeters = 15000, VisibilityAffect = 0, Dust = false, Precipitation = false })
  local s = w:toStringVisibility(veafWeatherUnitSystem.Systems.Faa)
  luaunit.assertTrue(#s > 0)
end

function TestVeafWeatherVisibility:test_fog_suffix()
  -- VisibilityAffect=1 → Fog
  local w = weatherInstance({ VisibilityMeters = 1000, VisibilityAffect = 1, Dust = false, Precipitation = false })
  luaunit.assertStrContains(w:toStringVisibility(veafWeatherUnitSystem.Systems.Faa), "fog")
end

function TestVeafWeatherVisibility:test_haze_suffix()
  -- VisibilityAffect=3 → Haze
  local w = weatherInstance({ VisibilityMeters = 5000, VisibilityAffect = 3, Dust = false, Precipitation = false })
  luaunit.assertStrContains(w:toStringVisibility(veafWeatherUnitSystem.Systems.Faa), "haze")
end

function TestVeafWeatherVisibility:test_mist_suffix()
  -- VisibilityAffect=2 → Mist
  local w = weatherInstance({ VisibilityMeters = 3000, VisibilityAffect = 2, Dust = false, Precipitation = false })
  luaunit.assertStrContains(w:toStringVisibility(veafWeatherUnitSystem.Systems.Faa), "mist")
end

function TestVeafWeatherVisibility:test_dust_suffix()
  local w = weatherInstance({ VisibilityMeters = 2000, VisibilityAffect = 0, Dust = true, Precipitation = false })
  luaunit.assertStrContains(w:toStringVisibility(veafWeatherUnitSystem.Systems.Faa), "dust")
end

function TestVeafWeatherVisibility:test_precipitation_suffix()
  local w = weatherInstance({ VisibilityMeters = 5000, VisibilityAffect = 0, Dust = false, Precipitation = true })
  luaunit.assertStrContains(w:toStringVisibility(veafWeatherUnitSystem.Systems.Faa), "precipitations")
end

-- ============================================================================
-- TestVeafWeatherSunTime
-- ============================================================================
TestVeafWeatherSunTime = {}

function TestVeafWeatherSunTime:setUp()
  dcs_mocks.reset()
  env.mission.date = { Day = 1, Month = 1, Year = 2024 }
  env.mission.theatre = "Caucasus"
end

function TestVeafWeatherSunTime:test_bZulu_only()
  local w = weatherInstance({})
  local dt = { hour = 6, min = 30, sec = 0, day = 1, month = 1, year = 2024, yday = 1 }
  local s = w:toStringSunTime(dt, true, false)
  luaunit.assertStrContains(s, "06:30Z")
end

function TestVeafWeatherSunTime:test_neither_flag_returns_empty()
  local w = weatherInstance({})
  local dt = { hour = 6, min = 30, sec = 0, day = 1, month = 1, year = 2024, yday = 1 }
  local s = w:toStringSunTime(dt, false, false)
  luaunit.assertEquals(s, "")
end

function TestVeafWeatherSunTime:test_bZulu_and_bLocal()
  local w = weatherInstance({})
  local dt = { hour = 6, min = 30, sec = 0, day = 1, month = 1, year = 2024, yday = 1 }
  local s = w:toStringSunTime(dt, true, true)
  -- both flags: format is "<zulu>Z - <local>L"
  luaunit.assertStrContains(s, "Z")
  luaunit.assertStrContains(s, "L")
end

-- ============================================================================
-- TestVeafWeatherSlice
-- ============================================================================
TestVeafWeatherSlice = {}

function TestVeafWeatherSlice:setUp()
  dcs_mocks.reset()
end

function TestVeafWeatherSlice:test_toStringSlice_returns_nonempty()
  local w = weatherInstance({ MagneticDeclination = 0 })
  local slice = {
    AltitudeMeters = 3000,
    WindDirection = 270,
    WindSpeedMps = 12,
    TemperatureCelcius = 5,
    PressureHpa = 900,
  }
  local s = w:toStringSlice(slice, veafWeatherUnitSystem.Systems.Faa, false)
  luaunit.assertTrue(#s > 0)
end

-- ============================================================================
-- TestVeafWeatherToString
-- ============================================================================
TestVeafWeatherToString = {}

function TestVeafWeatherToString:setUp()
  dcs_mocks.reset()
  env.mission.date = { Day = 1, Month = 1, Year = 2024 }
  env.mission.theatre = "Caucasus"
end

function TestVeafWeatherToString:test_toString_returns_nonempty()
  local w = weatherInstance({
    WindDirection = 270,
    WindSpeedMps = 5,
    VisibilityMeters = 10000,
    VisibilityAffect = 0,
    Dust = false,
    Precipitation = false,
    Clouds = { Density = 3, BaseMeters = 2000 },
    AltitudeMeter = 0,
    TemperatureCelcius = 15,
    DewPointCelcius = 8,
    QnhHpa = 1013,
    QfeHpa = 1010,
    SunriseZulu = { hour = 5, min = 30, sec = 0, day = 1, month = 1, year = 2024, yday = 1 },
    SunsetZulu = { hour = 17, min = 30, sec = 0, day = 1, month = 1, year = 2024, yday = 1 },
    WeatherSlices = {},
    MagneticDeclination = 0,
  })
  local s = w:toString(veafWeatherUnitSystem.Systems.Faa, false)
  luaunit.assertTrue(#s > 0)
  luaunit.assertStrContains(s, "Wind")
  luaunit.assertStrContains(s, "Sunrise")
end

-- ============================================================================
-- TestVeafWeatherToStringAtis
-- ============================================================================
TestVeafWeatherToStringAtis = {}

function TestVeafWeatherToStringAtis:setUp()
  dcs_mocks.reset()
  env.mission.date = { Day = 1, Month = 1, Year = 2024 }
  env.mission.theatre = "Caucasus"
end

function TestVeafWeatherToStringAtis:test_cavok_path()
  -- CAVOK: visibility ≥ 10000m, no precipitation, no dust, cloud base ≥ 1524m (≥ 5000ft)
  local w = weatherInstance({
    WindDirection = 090,
    WindSpeedMps = 8,
    VisibilityMeters = 15000,
    VisibilityAffect = 0,
    Dust = false,
    Precipitation = false,
    Clouds = { Density = 3, BaseMeters = 2000 },
    AltitudeMeter = 0,
    TemperatureCelcius = 20,
    DewPointCelcius = 10,
    QnhHpa = 1013,
    SunriseZulu = { hour = 5, min = 30, sec = 0, day = 1, month = 1, year = 2024, yday = 1 },
    SunsetZulu = { hour = 17, min = 30, sec = 0, day = 1, month = 1, year = 2024, yday = 1 },
    Vec3 = { x = 0, y = 0, z = 0 },
    AbsTime = 43200,
    MagneticDeclination = 0,
  })
  local s = w:toStringAtis(veafWeatherUnitSystem.Systems.Faa)
  luaunit.assertStrContains(s, "CAVOK")
end

function TestVeafWeatherToStringAtis:test_non_cavok_path()
  -- Non-CAVOK: low cloud base (1000m ≈ 3280ft < 5000ft)
  local w = weatherInstance({
    WindDirection = 180,
    WindSpeedMps = 3,
    VisibilityMeters = 3000,
    VisibilityAffect = 0,
    Dust = false,
    Precipitation = false,
    Clouds = { Density = 3, BaseMeters = 1000 },
    AltitudeMeter = 0,
    TemperatureCelcius = 10,
    DewPointCelcius = 8,
    QnhHpa = 1005,
    SunriseZulu = { hour = 5, min = 30, sec = 0, day = 1, month = 1, year = 2024, yday = 1 },
    SunsetZulu = { hour = 17, min = 30, sec = 0, day = 1, month = 1, year = 2024, yday = 1 },
    Vec3 = { x = 0, y = 0, z = 0 },
    AbsTime = 43200,
    MagneticDeclination = 0,
  })
  local s = w:toStringAtis(veafWeatherUnitSystem.Systems.Faa)
  luaunit.assertNotStrContains(s, "CAVOK")
  luaunit.assertStrContains(s, "Wind")
end

-- ============================================================================
-- veafWeatherAtis — the vanished-airbase path (FIX-ATIS-NIL-MESSAGE)
--
-- Credit: MacFlorent, PR #303. His crash fix for issue #302 landed independently, but the idea kept
-- here is the other one: when the airbase's DCS object is gone there is no weather to report, and the
-- pilot must get a sentence rather than a nil travelling on into trigger.action.outTextForUnit.
--
-- This path had NO test coverage at all, which is how the gap survived a guard being added next to it.
-- ============================================================================
TestVeafWeatherAtisVanishedAirbase = {}

function TestVeafWeatherAtisVanishedAirbase:setUp()
  dcs_mocks.reset()
  veafWeatherAtis.ListInEffect = {}
  -- This suite deliberately loads the minimum (veaf, veafTime, veafI18n, veafWeather), so veafAirbases
  -- is absent. Stub it rather than pulling the module in: what is under test is what veafWeather does
  -- with the answer, not how the nearest airbase is found.
  self._hadAirbases = veafAirbases ~= nil
  self._savedAirbases = veafAirbases
  veafAirbases = veafAirbases or {}
  self._savedGetNearest = veafAirbases.getNearestAirbase
  dcs_mocks.addUnit("Player1", {})
end

function TestVeafWeatherAtisVanishedAirbase:tearDown()
  if self._hadAirbases then
    veafAirbases.getNearestAirbase = self._savedGetNearest
  else
    veafAirbases = self._savedAirbases
  end
  veafWeatherAtis.ListInEffect = {}
end

--- An airbase whose DCS object reports it no longer exists — a sunk carrier is the canonical case.
function TestVeafWeatherAtisVanishedAirbase:_vanished()
  return {
    Name = "CVN-75 Truman",
    DcsAirbase = {
      isExist = function()
        return false
      end,
      getPoint = function()
        error("getPoint on a destroyed airbase — exactly the crash issue #302 reported")
      end,
    },
  }
end

function TestVeafWeatherAtisVanishedAirbase:test_getAtis_returns_nil_rather_than_raising()
  local ok, result = pcall(veafWeatherAtis.getAtis, self:_vanished())
  luaunit.assertTrue(ok, "a vanished airbase must not raise out of getAtis")
  luaunit.assertNil(result)
end

function TestVeafWeatherAtisVanishedAirbase:test_getAtisString_returns_nil()
  luaunit.assertNil(veafWeatherAtis.getAtisString(self:_vanished()))
end

function TestVeafWeatherAtisVanishedAirbase:test_the_pilot_gets_words_not_nothing()
  -- The defect this pins: nil used to be handed to veaf.outTextForUnit and on to DCS, which raises.
  veafAirbases.getNearestAirbase = function()
    return self:_vanished()
  end
  local ok = pcall(veafWeather.messageAtcClosestAirbase, "Player1", true)
  luaunit.assertTrue(ok, "asking for ATIS at a vanished airbase must not raise")
  luaunit.assertEquals(#dcs_mocks.messages, 1, "the pilot must be told something")
  -- Plain find, not assertStrContains: the hyphen in "CVN-75" is a Lua pattern quantifier, and the
  -- assertion helper matches as a pattern — so it failed on a message that was in fact correct.
  luaunit.assertNotNil(
    string.find(dcs_mocks.messages[1].text, "CVN-75 Truman", 1, true),
    "the message must name the airbase, got: " .. tostring(dcs_mocks.messages[1].text)
  )
end

function TestVeafWeatherAtisVanishedAirbase:test_the_message_is_translated_not_hardcoded()
  -- MacFlorent's version hardcoded English. The key must resolve through the catalogue, so a missing
  -- entry shows up here rather than shipping the raw key to a pilot.
  local text = veaf.t("weather.atis_unavailable", "Batumi")
  luaunit.assertNotEquals(text, "weather.atis_unavailable", "the i18n key must exist in the catalogue")
  luaunit.assertNotNil(string.find(text, "Batumi", 1, true))
end

-- ============================================================================
-- TestVeafWeatherRemoteFogKey -- SECREV-2 / VMR-042
-- ============================================================================
--- The remote `fog` command indexes veafWeather with a key the pilot supplies. It was reported as a
--- missing whitelist; measured, `:upper()` already narrows the reachable keys to the all-caps ones,
--- and every all-caps key on veafWeather is a FOG_* preset -- so it was not exploitable as reported.
--- What these tests pin is the fragility underneath: the first all-caps constant that is not a fog
--- object would have turned the command into a Lua error on a pilot's request.
TestVeafWeatherRemoteFogKey = {}

function TestVeafWeatherRemoteFogKey:setUp()
  self.activated = nil
  self.originalSetAndActivateFog = veafWeather.setAndActivateFog
  veafWeather.setAndActivateFog = function(fogObject)
    self.activated = fogObject
  end
end

function TestVeafWeatherRemoteFogKey:tearDown()
  veafWeather.setAndActivateFog = self.originalSetAndActivateFog
  veafWeather.NOT_A_FOG = nil
end

function TestVeafWeatherRemoteFogKey:_run(command)
  return veafWeather.executeCommandFromRemote({ "pilot", "Player1", "Unit1", command })
end

function TestVeafWeatherRemoteFogKey:test_a_known_preset_is_still_accepted()
  local handled = self:_run("fog fog_static_heavy")

  luaunit.assertTrue(handled, "a real preset must still be applied")
  luaunit.assertEquals(self.activated, veafWeather.FOG_STATIC_HEAVY)
end

function TestVeafWeatherRemoteFogKey:test_an_unknown_key_is_refused_without_activating_anything()
  local handled = self:_run("fog no_such_preset")

  luaunit.assertFalse(handled, "an unknown fog name must not be reported as handled")
  luaunit.assertNil(self.activated)
end

function TestVeafWeatherRemoteFogKey:test_an_all_caps_key_that_is_not_a_fog_object_is_refused()
  -- setAndActivateFog is stubbed here, so what this pins is that a non-fog value never *reaches* it
  -- -- which is the guard's job. The real function would call fogObject:enable() on whatever it got.
  veafWeather.NOT_A_FOG = { "some other constant" }

  local handled = self:_run("fog not_a_fog")

  luaunit.assertFalse(handled, "an all-caps key that is not a fog preset must not be reported handled")
  luaunit.assertNil(self.activated, "a non-fog value must never be passed on for activation")
end

-- ============================================================================
-- TestVeafWeatherFogMenuWiring -- FIX-DOCAUDIT-CODE 03
-- ============================================================================
--- The "animated NO fog" entries all passed `veafWeather.FOG_ANIMATED_5_NO` -- a constant that does
--- not exist, since the generated names carry the `M` (`FOG_ANIMATED_5M_NO`). So seven menu entries
--- handed `nil` to their handler, and even had the name been right, all seven would have applied the
--- 5-minute preset.
---
--- These assertions are **enumerated from the menu-building code**, not sampled: the real
--- `buildRadioMenu` runs against a recording stub, and every command it wires to
--- `setAndActivateFog` is checked. A future entry with a mistyped constant fails here by name.
TestVeafWeatherFogMenuWiring = {}

function TestVeafWeatherFogMenuWiring:setUp()
  self.commands = {}
  local recorded = self.commands
  local record = function(title, _path, method, parameters)
    table.insert(recorded, { title = title, method = method, parameters = parameters })
  end
  self.originalVeafRadio = veafRadio
  veafRadio = {
    USAGE_ForAll = 0,
    USAGE_ForGroup = 1,
    addMenu = function(title)
      return { title = title }
    end,
    addSubMenu = function(title)
      return { title = title }
    end,
    addCommandToSubmenu = record,
    addSecuredCommandToSubmenu = record,
  }
end

function TestVeafWeatherFogMenuWiring:tearDown()
  veafRadio = self.originalVeafRadio
  veafWeather.rootPath = nil
end

--- Every command wired to setAndActivateFog, with its declared parameter.
function TestVeafWeatherFogMenuWiring:_fogCommands()
  veafWeather.buildRadioMenu()
  local fogCommands = {}
  for _, command in ipairs(self.commands) do
    if command.method == veafWeather.setAndActivateFog then
      table.insert(fogCommands, command)
    end
  end
  return fogCommands
end

function TestVeafWeatherFogMenuWiring:test_the_menu_wires_fog_commands_at_all()
  -- A guard on the harness itself: if the stub stopped recording, the sweep below would pass
  -- vacuously. 6 static + 4 dynamic + 7 durations x 6 = 52 at the time of writing.
  luaunit.assertTrue(#self:_fogCommands() >= 40, "the fog menu must wire a fog preset per entry")
end

function TestVeafWeatherFogMenuWiring:test_every_fog_menu_entry_passes_an_existing_preset()
  for _, command in ipairs(self:_fogCommands()) do
    luaunit.assertNotNil(command.parameters, "fog menu entry '" .. tostring(command.title) .. "' passes nil")
  end
end

function TestVeafWeatherFogMenuWiring:test_every_fog_menu_entry_passes_the_preset_it_advertises()
  -- The entry's title is read off the preset, so a title that disagrees with the parameter's own
  -- name means the entry applies a *different* preset than the one the pilot clicked.
  for _, command in ipairs(self:_fogCommands()) do
    luaunit.assertEquals(
      command.parameters and command.parameters.name,
      command.title,
      "fog menu entry '" .. tostring(command.title) .. "' applies another preset"
    )
  end
end

-- ============================================================================
-- Run
-- ============================================================================
-- ============================================================================
-- FEAT-SLOT-WELCOME-BRIEF — greeting a pilot who takes a slot (#301)
--
-- A correction to the lot's own PRD belongs here, because it is what these tests do *not* cover: the PRD
-- calls the runway-from-wind "the only real computation here" and says nothing decides it. It was already
-- written and shipped — `veafAirbase:getRunwayInService` picks the best-headwind runway end and the ATIS
-- has been using it. So there is nothing to test there, and what is tested is the part that was missing:
-- the trigger, the airbase, the message, and the switch.
-- ============================================================================
TestVeafWeatherWelcomeBrief = {}

function TestVeafWeatherWelcomeBrief:setUp()
  self._savedEnabled = veafWeather.welcomeBriefEnabled
  self._savedOutForGroup = trigger.action.outTextForGroup
  self._savedNearest = veafAirbases.getNearestAirbase
  self._savedCreate = veafWeatherData.create
  self._savedSchedule = mist.scheduleFunction
  self._savedGetByName = Unit.getByName

  self.messages = {}
  self.scheduled = {}
  veafWeather.welcomeBriefEnabled = true
  -- Cleared between tests, or the once-per-slot rule makes the second test in a row see nothing.
  veafWeather.briefedUnits = {}
  -- `isHumanUnit` reads this table. Registering the pilot here is what makes a BIRTH event brief him,
  -- which is the path single player actually takes.
  self._savedHumans = mist.DBs.humansByName
  mist.DBs.humansByName = { Chevy11 = {}, Chevy21 = {} }

  trigger.action.outTextForGroup = function(groupId, text, duration)
    table.insert(self.messages, { groupId = groupId, text = text, duration = duration })
  end
  mist.scheduleFunction = function(fn, args, when)
    table.insert(self.scheduled, { fn = fn, args = args, when = when })
  end
end

function TestVeafWeatherWelcomeBrief:tearDown()
  veafWeather.welcomeBriefEnabled = self._savedEnabled
  trigger.action.outTextForGroup = self._savedOutForGroup
  veafAirbases.getNearestAirbase = self._savedNearest
  veafWeatherData.create = self._savedCreate
  mist.scheduleFunction = self._savedSchedule
  Unit.getByName = self._savedGetByName
  mist.DBs.humansByName = self._savedHumans
end

--- A unit the player just took, with only what the brief touches.
function TestVeafWeatherWelcomeBrief:_unit(name)
  return {
    getName = function()
      return name or "Chevy11"
    end,
    isExist = function()
      return true
    end,
    getPoint = function()
      return { x = 0, y = 0, z = 0 }
    end,
    getGroup = function()
      return {
        getID = function()
          return 77
        end,
      }
    end,
  }
end

--- An airbase of the given category, answering a runway for whatever wind it is given.
function TestVeafWeatherWelcomeBrief:_airbase(category, runway)
  self.askedWind = nil
  local test = self
  return {
    Name = "Kobuleti",
    DisplayName = "Kobuleti",
    Category = category,
    DcsAirbase = {
      getPoint = function()
        return { x = 0, y = 0, z = 0 }
      end,
    },
    getRunwayInServiceString = function(_, wind)
      test.askedWind = wind
      return runway
    end,
  }
end

--- Stub the weather so the brief has something to report, with a known wind direction.
function TestVeafWeatherWelcomeBrief:_weather(windDirection)
  veafWeatherData.create = function()
    return {
      WindDirection = windDirection or 270,
      toStringAtis = function()
        return "WIND 270/10 QNH 1013"
      end,
    }
  end
end

function TestVeafWeatherWelcomeBrief:_arrange(category, runway, windDirection)
  local airbase = self:_airbase(category or Airbase.Category.AIRDROME, runway or "13")
  veafAirbases.getNearestAirbase = function()
    return airbase
  end
  self:_weather(windDirection)
  return airbase
end

-- ── the message ─────────────────────────────────────────────────────────────

function TestVeafWeatherWelcomeBrief:test_it_names_the_airbase_the_runway_and_the_weather()
  self:_arrange()
  local brief = veafWeather.buildWelcomeBrief(self:_unit())
  luaunit.assertNotNil(brief)
  luaunit.assertNotNil(brief:find("Kobuleti", 1, true))
  luaunit.assertNotNil(brief:lower():find("runway in service 13", 1, true), "the runway, named: " .. brief)
  luaunit.assertNotNil(brief:find("QNH 1013", 1, true), "the weather line must be in it: " .. brief)
end

function TestVeafWeatherWelcomeBrief:test_the_runway_is_chosen_from_the_wind()
  -- The one thing the brief must not get wrong: asking for the runway without the wind would return
  -- whichever end the airbase lists first, silently.
  self:_arrange(nil, "31", 130)
  veafWeather.buildWelcomeBrief(self:_unit())
  luaunit.assertEquals(self.askedWind, 130)
end

function TestVeafWeatherWelcomeBrief:test_a_carrier_gets_no_runway_line()
  -- A ship has no runway to be in service, and asking anyway logs a "none identified" for every carrier
  -- slot taken. Its own wording rather than an empty gap.
  self:_arrange(Airbase.Category.SHIP, "13")
  local brief = veafWeather.buildWelcomeBrief(self:_unit())
  luaunit.assertNotNil(brief)
  -- On the word, not on the digits: the first version of this searched for "13" and found it inside the
  -- QNH of "1013", failing on a brief that was perfectly correct.
  luaunit.assertNil(brief:lower():find("runway", 1, true), "a carrier brief must not name a runway: " .. brief)
end

function TestVeafWeatherWelcomeBrief:test_a_helipad_gets_no_runway_line_either()
  self:_arrange(Airbase.Category.HELIPAD, "13")
  local brief = veafWeather.buildWelcomeBrief(self:_unit())
  luaunit.assertNotNil(brief)
  luaunit.assertNil(brief:lower():find("runway", 1, true))
end

function TestVeafWeatherWelcomeBrief:test_an_airbase_with_no_runway_in_service_still_gets_a_brief()
  -- The weather is worth having even when no runway can be identified; dropping the whole brief would
  -- trade a missing line for a missing message.
  self:_arrange(Airbase.Category.AIRDROME, nil)
  local brief = veafWeather.buildWelcomeBrief(self:_unit())
  luaunit.assertNotNil(brief)
  luaunit.assertNotNil(brief:find("Kobuleti", 1, true))
end

-- ── a carrier keeps no runway ────────────────────────────────────────────────
-- David's point, and a domain one rather than a wording one: a carrier turns into the wind, so what a
-- pilot taking a deck slot needs is the ship's COURSE. The first version of this feature gave him
-- nothing at all and the tests were happy with that, which is why they now assert the course.

--- A ship airbase whose vessel reports `heading` radians.
function TestVeafWeatherWelcomeBrief:_ship(heading)
  local airbase = self:_airbase(Airbase.Category.SHIP, nil)
  airbase.Name = "CVN-73"
  airbase.DisplayName = "CVN-73"
  airbase.DcsAirbase.getUnit = function()
    return { isShipUnit = true }
  end
  self._savedMistHeading = self._savedMistHeading or mist.getHeading
  self.headingArgs = nil
  local test = self
  mist.getHeading = function(unit, raw)
    test.headingArgs = { unit = unit, raw = raw }
    return heading
  end
  return airbase
end

function TestVeafWeatherWelcomeBrief:test_the_heading_asked_for_is_the_true_one()
  -- The message says "(true)" / "(vrai)", so the code must ask for the true heading and not the magnetic
  -- one — otherwise the brief lies by a declination. Pinned because the first version of these tests
  -- stubbed mist.getHeading ignoring its arguments, and flipping that flag killed no test at all.
  local airbase = self:_ship(math.rad(45))
  veafAirbases.getNearestAirbase = function()
    return airbase
  end
  self:_weather()
  veafWeather.buildWelcomeBrief(self:_unit())
  mist.getHeading = self._savedMistHeading
  luaunit.assertNotNil(self.headingArgs, "mist.getHeading was never called")
  luaunit.assertTrue(self.headingArgs.raw, "the second argument must be true: the true heading, not magnetic")
end

function TestVeafWeatherWelcomeBrief:test_a_carrier_announces_its_course()
  local airbase = self:_ship(math.rad(123))
  veafAirbases.getNearestAirbase = function()
    return airbase
  end
  self:_weather()
  local brief = veafWeather.buildWelcomeBrief(self:_unit())
  mist.getHeading = self._savedMistHeading
  luaunit.assertNotNil(brief)
  luaunit.assertNotNil(brief:lower():find("heading", 1, true), "a carrier must be given its heading: " .. brief)
  luaunit.assertNotNil(brief:find("123", 1, true), "and the heading itself: " .. brief)
end

function TestVeafWeatherWelcomeBrief:test_the_course_is_read_as_three_digits()
  -- A heading is spoken and written as three digits; "cap 9" is not a heading.
  local airbase = self:_ship(math.rad(9))
  veafAirbases.getNearestAirbase = function()
    return airbase
  end
  self:_weather()
  local brief = veafWeather.buildWelcomeBrief(self:_unit())
  mist.getHeading = self._savedMistHeading
  luaunit.assertNotNil(brief:find("009", 1, true), "expected a three-digit heading: " .. brief)
end

function TestVeafWeatherWelcomeBrief:test_a_carrier_is_never_given_a_runway()
  local airbase = self:_ship(math.rad(90))
  veafAirbases.getNearestAirbase = function()
    return airbase
  end
  self:_weather()
  local brief = veafWeather.buildWelcomeBrief(self:_unit())
  mist.getHeading = self._savedMistHeading
  luaunit.assertNil(brief:lower():find("runway", 1, true), "a carrier has no runway to keep: " .. brief)
end

function TestVeafWeatherWelcomeBrief:test_an_unreadable_course_falls_back_rather_than_inventing_one()
  -- A course a pilot cannot trust is worse than no course: he would fly it.
  local airbase = self:_airbase(Airbase.Category.SHIP, nil)
  airbase.DcsAirbase.getUnit = function()
    return nil
  end
  veafAirbases.getNearestAirbase = function()
    return airbase
  end
  self:_weather()
  local brief = veafWeather.buildWelcomeBrief(self:_unit())
  luaunit.assertNotNil(brief, "the weather is still worth having")
  luaunit.assertNil(brief:lower():find("heading", 1, true))
end

function TestVeafWeatherWelcomeBrief:test_a_helipad_gets_neither_runway_nor_course()
  -- No runway to align with and no course to steer.
  self:_arrange(Airbase.Category.HELIPAD, "13")
  local brief = veafWeather.buildWelcomeBrief(self:_unit())
  luaunit.assertNotNil(brief)
  luaunit.assertNil(brief:lower():find("runway", 1, true))
  luaunit.assertNil(brief:lower():find("heading", 1, true))
end

-- ── when there is nothing to say ─────────────────────────────────────────────

function TestVeafWeatherWelcomeBrief:test_no_airbase_means_no_brief()
  veafAirbases.getNearestAirbase = function()
    return nil
  end
  self:_weather()
  luaunit.assertNil(veafWeather.buildWelcomeBrief(self:_unit()))
end

function TestVeafWeatherWelcomeBrief:test_no_weather_means_no_brief()
  self:_arrange()
  veafWeatherData.create = function()
    return nil
  end
  luaunit.assertNil(veafWeather.buildWelcomeBrief(self:_unit()))
end

function TestVeafWeatherWelcomeBrief:test_a_nil_unit_is_not_a_crash()
  luaunit.assertNil(veafWeather.buildWelcomeBrief(nil))
end

-- ── the trigger ─────────────────────────────────────────────────────────────

function TestVeafWeatherWelcomeBrief:test_taking_a_slot_schedules_the_brief()
  -- Not shown at once: a pilot entering a unit is still loading his cockpit, and a message at that
  -- instant is one he never reads.
  self:_arrange()
  veafWeather.onPlayerEnterUnit({ initiator = self:_unit() })
  luaunit.assertEquals(#self.scheduled, 1)
  luaunit.assertEquals(#self.messages, 0, "nothing is shown before the delay")
end

function TestVeafWeatherWelcomeBrief:test_it_is_scheduled_by_name_not_by_unit()
  -- The unit object may be stale by the time the timer fires; a name can be resolved again.
  self:_arrange()
  veafWeather.onPlayerEnterUnit({ initiator = self:_unit("Chevy21") })
  luaunit.assertEquals(self.scheduled[1].args[1], "Chevy21")
end

function TestVeafWeatherWelcomeBrief:test_the_setting_silences_it()
  -- A mission maker running his own briefing needs this off, which is why it is a setting and not a
  -- constant.
  self:_arrange()
  veafWeather.welcomeBriefEnabled = false
  veafWeather.onPlayerEnterUnit({ initiator = self:_unit() })
  luaunit.assertEquals(#self.scheduled, 0)
end

function TestVeafWeatherWelcomeBrief:test_an_event_without_an_initiator_is_ignored()
  self:_arrange()
  veafWeather.onPlayerEnterUnit({})
  veafWeather.onPlayerEnterUnit(nil)
  luaunit.assertEquals(#self.scheduled, 0)
end

-- ── which event actually arrives ─────────────────────────────────────────────
-- The brief said nothing at all in game, on an airfield and on a carrier alike, and this is why:
-- `S_EVENT_PLAYER_ENTER_UNIT` does not fire when a single-player pilot occupies his starting slot. DCS
-- raises a birth event for him. `veafGrass` and `veafQraCore` both take both events for this exact
-- reason; the brief now does too.

-- ── who is already flying ───────────────────────────────────────────────────
-- In single player the pilot occupies his slot before the mission's scripts load, so his birth event fires
-- before this module can subscribe to anything. Subscribing was never going to catch it: adding
-- S_EVENT_BIRTH did not help, because the timing and not the event name was the problem. These tests
-- cover the sweep that looks at who is there instead of waiting to be told.
TestVeafWeatherAlreadyFlying = {}

function TestVeafWeatherAlreadyFlying:setUp()
  self._savedEnabled = veafWeather.welcomeBriefEnabled
  self._savedHumans = mist.DBs.humansByName
  self._savedGetByName = Unit.getByName
  self._savedSend = veafWeather.sendWelcomeBrief

  self.briefed = {}
  veafWeather.welcomeBriefEnabled = true
  veafWeather.briefedUnits = {}
  local test = self
  veafWeather.sendWelcomeBrief = function(name)
    table.insert(test.briefed, name)
  end
end

function TestVeafWeatherAlreadyFlying:tearDown()
  veafWeather.welcomeBriefEnabled = self._savedEnabled
  mist.DBs.humansByName = self._savedHumans
  Unit.getByName = self._savedGetByName
  veafWeather.sendWelcomeBrief = self._savedSend
end

--- @param slots table name -> the player sitting in it, or nil for an empty slot
function TestVeafWeatherAlreadyFlying:_world(slots)
  mist.DBs.humansByName = {}
  for name, _ in pairs(slots) do
    mist.DBs.humansByName[name] = {}
  end
  Unit.getByName = function(name)
    if slots[name] == nil then
      return nil
    end
    return {
      isExist = function()
        return true
      end,
      getPlayerName = function()
        return slots[name] ~= false and slots[name] or nil
      end,
    }
  end
end

function TestVeafWeatherAlreadyFlying:test_a_pilot_already_in_his_slot_is_briefed()
  -- The single-player case, and the whole reason this function exists.
  self:_world({ Chevy11 = "David" })
  veafWeather.briefEveryoneAlreadyFlying()
  luaunit.assertEquals(self.briefed, { "Chevy11" })
end

function TestVeafWeatherAlreadyFlying:test_an_empty_slot_is_not_briefed()
  -- A mission declares its human slots whether or not anybody is in them. Briefing all of them would send
  -- a message to nobody, once per slot.
  self:_world({ Chevy11 = false })
  veafWeather.briefEveryoneAlreadyFlying()
  luaunit.assertEquals(#self.briefed, 0)
end

function TestVeafWeatherAlreadyFlying:test_a_slot_that_does_not_exist_yet_is_skipped()
  mist.DBs.humansByName = { Ghost = {} }
  Unit.getByName = function()
    return nil
  end
  veafWeather.briefEveryoneAlreadyFlying()
  luaunit.assertEquals(#self.briefed, 0)
end

function TestVeafWeatherAlreadyFlying:test_only_the_occupied_slots_among_several()
  self:_world({ Chevy11 = "David", Chevy12 = false, Chevy21 = "Zip" })
  veafWeather.briefEveryoneAlreadyFlying()
  table.sort(self.briefed)
  luaunit.assertEquals(self.briefed, { "Chevy11", "Chevy21" })
end

function TestVeafWeatherAlreadyFlying:test_a_pilot_already_briefed_is_left_alone()
  -- The sweep and the event can both name the same pilot; he must hear the runway once.
  self:_world({ Chevy11 = "David" })
  veafWeather.briefedUnits["Chevy11"] = true
  veafWeather.briefEveryoneAlreadyFlying()
  luaunit.assertEquals(#self.briefed, 0)
end

function TestVeafWeatherAlreadyFlying:test_the_sweep_marks_them_so_the_event_does_not_repeat()
  -- The other direction of the same rule: the sweep runs first, so it is what must write the mark.
  self:_world({ Chevy11 = "David" })
  veafWeather.briefEveryoneAlreadyFlying()
  luaunit.assertTrue(veafWeather.briefedUnits["Chevy11"])
end

function TestVeafWeatherAlreadyFlying:test_the_setting_silences_the_sweep_too()
  self:_world({ Chevy11 = "David" })
  veafWeather.welcomeBriefEnabled = false
  veafWeather.briefEveryoneAlreadyFlying()
  luaunit.assertEquals(#self.briefed, 0)
end

function TestVeafWeatherAlreadyFlying:test_it_survives_a_mission_with_no_human_slots()
  mist.DBs.humansByName = nil
  veafWeather.briefEveryoneAlreadyFlying()
  luaunit.assertEquals(#self.briefed, 0)
end

-- The SUBSCRIPTION, not the handler. Every test below calls `onPlayerEnterUnit` directly, so none of them
-- can tell whether the module actually asks to be told. Reverting the fix to `S_EVENT_PLAYER_ENTER_UNIT`
-- alone passed all of them — the defect was one indirection outside what they cover.
function TestVeafWeatherWelcomeBrief:test_it_subscribes_to_both_events()
  local seen = nil
  local origAdd = veafEventHandler.addCallback
  local origMenu = veafWeather.buildRadioMenu
  local origAirbases = veafAirbases.initialize
  -- veafRemote is not loaded by this suite; initialize() calls into it, so it has to exist for the call
  -- to get as far as the subscription we are here to inspect.
  local hadRemote = veafRemote ~= nil
  veafRemote = veafRemote or {}
  local origRemote = veafRemote.registerRemoteModule
  veafEventHandler.addCallback = function(name, events, fn)
    if name == "veafWeather.onPlayerEnterUnit" then
      seen = events
    end
  end
  veafWeather.buildRadioMenu = function() end
  veafAirbases.initialize = function() end
  veafRemote.registerRemoteModule = function() end

  veafWeather.initialize(true)

  veafEventHandler.addCallback = origAdd
  veafWeather.buildRadioMenu = origMenu
  veafAirbases.initialize = origAirbases
  veafRemote.registerRemoteModule = origRemote
  if not hadRemote then
    veafRemote = nil
  end

  luaunit.assertNotNil(seen, "the brief must register a callback at all")
  local found = {}
  for _, e in ipairs(seen) do
    found[e] = true
  end
  luaunit.assertTrue(found["S_EVENT_BIRTH"], "a single-player pilot arrives as a birth event")
  luaunit.assertTrue(found["S_EVENT_PLAYER_ENTER_UNIT"], "a multiplayer pilot arrives as this one")
end

function TestVeafWeatherWelcomeBrief:test_initialize_also_sweeps_who_is_already_flying()
  -- The wiring again, and the third time today that a mutation found this same hole: every test of the
  -- sweep calls it directly, so none of them notices if nothing ever calls it. Removing the scheduling
  -- passed all eight.
  local scheduledFns = {}
  local origAdd = veafEventHandler.addCallback
  local origMenu = veafWeather.buildRadioMenu
  local origAirbases = veafAirbases.initialize
  local hadRemote = veafRemote ~= nil
  veafRemote = veafRemote or {}
  local origRemote = veafRemote.registerRemoteModule
  local origSchedule = mist.scheduleFunction
  veafEventHandler.addCallback = function() end
  veafWeather.buildRadioMenu = function() end
  veafAirbases.initialize = function() end
  veafRemote.registerRemoteModule = function() end
  mist.scheduleFunction = function(fn)
    table.insert(scheduledFns, fn)
  end

  veafWeather.initialize(true)

  veafEventHandler.addCallback = origAdd
  veafWeather.buildRadioMenu = origMenu
  veafAirbases.initialize = origAirbases
  veafRemote.registerRemoteModule = origRemote
  mist.scheduleFunction = origSchedule
  if not hadRemote then
    veafRemote = nil
  end

  local found = false
  for _, fn in ipairs(scheduledFns) do
    if fn == veafWeather.briefEveryoneAlreadyFlying then
      found = true
    end
  end
  luaunit.assertTrue(found, "initialize must schedule the sweep, or single player is never briefed")
end

function TestVeafWeatherWelcomeBrief:test_the_setting_off_subscribes_to_nothing()
  -- The other half: silenced means not even listening, rather than listening and discarding.
  local seen = nil
  local origAdd = veafEventHandler.addCallback
  local origMenu = veafWeather.buildRadioMenu
  local origAirbases = veafAirbases.initialize
  -- veafRemote is not loaded by this suite; initialize() calls into it, so it has to exist for the call
  -- to get as far as the subscription we are here to inspect.
  local hadRemote = veafRemote ~= nil
  veafRemote = veafRemote or {}
  local origRemote = veafRemote.registerRemoteModule
  veafEventHandler.addCallback = function(name, events)
    if name == "veafWeather.onPlayerEnterUnit" then
      seen = events
    end
  end
  veafWeather.buildRadioMenu = function() end
  veafAirbases.initialize = function() end
  veafRemote.registerRemoteModule = function() end

  veafWeather.initialize(false)

  veafEventHandler.addCallback = origAdd
  veafWeather.buildRadioMenu = origMenu
  veafAirbases.initialize = origAirbases
  veafRemote.registerRemoteModule = origRemote
  if not hadRemote then
    veafRemote = nil
  end
  luaunit.assertNil(seen)
end

function TestVeafWeatherWelcomeBrief:test_a_birth_event_briefs_a_human()
  -- The single-player path, and the one that was missing entirely.
  self:_arrange()
  veafWeather.onPlayerEnterUnit({ initiator = self:_unit(), type = { id = world.event.S_EVENT_BIRTH } })
  luaunit.assertEquals(#self.scheduled, 1)
end

function TestVeafWeatherWelcomeBrief:test_a_birth_event_does_not_brief_an_ai()
  -- The cost of listening to births: every AI aircraft that spawns raises one. The human test is what
  -- keeps the brief from being sent to nobody, hundreds of times.
  self:_arrange()
  veafWeather.onPlayerEnterUnit({ initiator = self:_unit("Ai-Flight-1"), type = { id = world.event.S_EVENT_BIRTH } })
  luaunit.assertEquals(#self.scheduled, 0)
end

function TestVeafWeatherWelcomeBrief:test_player_enter_unit_briefs_even_without_the_human_table()
  -- The multiplayer path. A pilot joining a slot may not be in `humansByName` yet, so the event's own
  -- identity is taken as proof — the same exception `veafGrass` and `veafQraCore` make.
  self:_arrange()
  mist.DBs.humansByName = {}
  veafWeather.onPlayerEnterUnit({
    initiator = self:_unit("Someone-New"),
    type = { id = world.event.S_EVENT_PLAYER_ENTER_UNIT },
  })
  luaunit.assertEquals(#self.scheduled, 1)
end

function TestVeafWeatherWelcomeBrief:test_one_brief_per_slot_even_when_both_events_arrive()
  -- Both events can name the same pilot. A runway announced twice, five seconds apart, reads as a bug.
  self:_arrange()
  veafWeather.onPlayerEnterUnit({ initiator = self:_unit(), type = { id = world.event.S_EVENT_BIRTH } })
  veafWeather.onPlayerEnterUnit({
    initiator = self:_unit(),
    type = { id = world.event.S_EVENT_PLAYER_ENTER_UNIT },
  })
  luaunit.assertEquals(#self.scheduled, 1)
end

function TestVeafWeatherWelcomeBrief:test_two_different_pilots_each_get_one()
  -- The de-duplication is per slot, not global: a second pilot must not be silenced by the first.
  self:_arrange()
  veafWeather.onPlayerEnterUnit({ initiator = self:_unit("Chevy11"), type = { id = world.event.S_EVENT_BIRTH } })
  veafWeather.onPlayerEnterUnit({ initiator = self:_unit("Chevy21"), type = { id = world.event.S_EVENT_BIRTH } })
  luaunit.assertEquals(#self.scheduled, 2)
end

-- ── sending it ──────────────────────────────────────────────────────────────

function TestVeafWeatherWelcomeBrief:test_it_goes_to_the_pilots_group_only()
  -- His airfield, his message. Broadcast to a coalition it becomes noise the moment two pilots take
  -- slots at different bases.
  self:_arrange()
  local unit = self:_unit()
  Unit.getByName = function()
    return unit
  end
  veafWeather.sendWelcomeBrief("Chevy11")
  luaunit.assertEquals(#self.messages, 1)
  luaunit.assertEquals(self.messages[1].groupId, 77)
end

function TestVeafWeatherWelcomeBrief:test_a_pilot_who_left_the_slot_gets_nothing()
  -- Ordinary rather than exceptional: the delay is long enough to jump back to spectator.
  self:_arrange()
  Unit.getByName = function()
    return nil
  end
  veafWeather.sendWelcomeBrief("Chevy11")
  luaunit.assertEquals(#self.messages, 0)
end

function TestVeafWeatherWelcomeBrief:test_nothing_to_say_sends_nothing()
  veafAirbases.getNearestAirbase = function()
    return nil
  end
  self:_weather()
  local unit = self:_unit()
  Unit.getByName = function()
    return unit
  end
  veafWeather.sendWelcomeBrief("Chevy11")
  luaunit.assertEquals(#self.messages, 0)
end

os.exit(luaunit.LuaUnit.run())
