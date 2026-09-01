------------------------------------------------------------------
-- VEAF weather information messages and markers
-- By Flogas (2024)
--
-- Features:
-- ---------
-- * Generation of weather messages and reports in different formats (METAR, ATIS)
-- * Generation of markers on the maps displaying the weather at the location
------------------------------------------------------------------
veafWeather = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global module settings
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafWeather.Id = "WEATHER"

-- trace level, specific to this module
--veafWeather.LogLevel = "trace"
veaf.loggers.new(veafWeather.Id, veafWeather.LogLevel)

--- Key phrase to look for in the mark text which triggers the command.
veafWeather.Keyphrase = "_weather"

veafWeather.RadioMenuName = "menu.weather.root"

veafWeather.RemoteCommandParser = "([[a-zA-Z0-9]+)%s?([^%s]*)%s?(.*)"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------
local _dcsPresetDensity = {
  -- {density, precipitation, visibility}
  ["Preset1"] = { 2, false, nil }, -- LS1 -- FEW/SCT
  ["Preset2"] = { 2, false, nil }, -- LS2 -- FEW/SCT
  ["Preset3"] = { 3, false, nil }, -- HS1 -- SCT
  ["Preset4"] = { 3, false, nil }, -- HS2 -- SCT
  ["Preset5"] = { 3, false, nil }, -- S1 -- SCT
  ["Preset6"] = { 4, false, nil }, -- S2 -- SCT/BKN
  ["Preset7"] = { 3, false, nil }, -- S3 -- BKN
  ["Preset8"] = { 4, false, nil }, -- HS3 -- SCT/BKN
  ["Preset9"] = { 5, false, nil }, -- S4 -- BKN
  ["Preset10"] = { 4, false, nil }, -- S5 -- SCT/BKN
  ["Preset11"] = { 6, false, nil }, -- S6 -- BKN
  ["Preset12"] = { 6, false, nil }, -- S7 -- BKN
  ["Preset13"] = { 6, false, nil }, -- B1 -- BKN
  ["Preset14"] = { 6, false, nil }, -- B2 -- BKN
  ["Preset15"] = { 4, false, nil }, -- B3 -- SCT/BKN
  ["Preset16"] = { 6, false, nil }, -- B4 -- BKN
  ["Preset17"] = { 7, false, nil }, -- B5 -- BKN/OVC
  ["Preset18"] = { 7, false, nil }, -- B6 -- BKN/OVC
  ["Preset19"] = { 8, false, nil }, -- B7 -- OVC
  ["Preset20"] = { 7, false, nil }, -- B8 -- BKN/OVC
  ["Preset21"] = { 7, false, nil }, -- O1 -- BKN/OVC
  ["Preset22"] = { 6, false, nil }, -- O2 -- BKN
  ["Preset23"] = { 6, false, nil }, -- O3  -- BKN
  ["Preset24"] = { 7, false, nil }, -- O4 -- BKN/OVC
  ["Preset25"] = { 8, false, nil }, -- O5 -- OVC
  ["Preset26"] = { 8, false, nil }, -- O6 -- OVC
  ["Preset27"] = { 8, false, nil }, -- O7 -- OVC
  ["RainyPreset1"] = { 8, true, 4000 }, -- OR1 -- OVC
  ["RainyPreset2"] = { 7, true, 3000 }, -- OR2 -- BKN/OVC
  ["RainyPreset3"] = { 8, true, 4000 }, -- OR3 -- OVC
  ["RainyPreset4"] = { 4, true, nil }, -- LR1 -- SCT/BKN
  ["RainyPreset5"] = { 7, true, nil }, -- LR2 -- BKN/OVC
  ["RainyPreset6"] = { 8, true, nil }, -- LR3 -- OVC
  ["NEWRAINPRESET4"] = { 8, true, nil }, -- LR4 -- OVC
}

local _cloudDensity = { Clear = 0, Few = 1, Scattered = 2, Broken = 3, Overcast = 4 }
local _cloudDensityOktas = {
  [0] = _cloudDensity.Clear,
  [1] = _cloudDensity.Few,
  [2] = _cloudDensity.Few,
  [3] = _cloudDensity.Scattered,
  [4] = _cloudDensity.Scattered,
  [5] = _cloudDensity.Broken,
  [6] = _cloudDensity.Broken,
  [7] = _cloudDensity.Overcast,
  [8] = _cloudDensity.Overcast,
}

local _nKelvinToCelciusOffset = -273.15

local _visibilityAffect = { None = 0, Fog = 1, Mist = 2, Haze = 3 }
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local tools
-------------------------------------------------------------------------------------------------------------------------------------------------------------
local function _computeClearSkyHumidity(nLatitude, nLongitude, iDayOfYear)
  -- Base RH for clear skies
  local baseRh = 30

  -- Seasonal adjustment
  -- Calculate seasonal factor (-1 to 1, peaks at middle of year)
  local seasonal_factor = math.cos((iDayOfYear - 182) * 2 * math.pi / 365)

  -- Latitude adjustment
  -- Higher latitudes tend to have lower RH in winter, higher in summer
  local lat_factor = math.abs(nLatitude) / 90

  -- Longitude adjustment (crude estimation of continental vs maritime)
  -- Assume areas around 0°, 180° longitude (typical ocean areas) have higher RH
  local long_factor = math.min(math.abs(nLongitude), math.abs(nLongitude - 180)) / 180
  local maritime_influence = 1 - long_factor

  -- Combine factors
  local seasonal_adjustment = seasonal_factor * 15 * lat_factor -- ±15% variation
  local maritime_adjustment = maritime_influence * 10 -- Up to +10% for maritime areas

  -- Calculate final RH
  local adjustedRh = baseRh + seasonal_adjustment + maritime_adjustment

  -- Clamp between reasonable values
  return math.max(20, math.min(70, adjustedRh))
end

local function _computeHumidity(vec3, iCloudBaseMeters, iVisibilityMeters, bPrecipitations, iAbsTime)
  local nLatitude, nLongitude, _ = coord.LOtoLL(vec3)
  local nHumidity

  if iCloudBaseMeters == nil or iCloudBaseMeters > 10000 then
    -- Clear skies - estimate RH based on location and date
    local dateTime = veafTime.getMissionDateTime(iAbsTime)
    nHumidity = _computeClearSkyHumidity(nLatitude, nLongitude, dateTime.yday)
  else
    -- Convert cloud base to meters and estimate RH
    nHumidity = 100 - (iCloudBaseMeters / 100)
    -- Clamp RH between 0 and 100%
    nHumidity = math.max(0, math.min(100, nHumidity))
  end

  if iVisibilityMeters < 1000 then
    nHumidity = 100 -- Fog implies saturation
  elseif iVisibilityMeters < 5000 then
    nHumidity = math.max(nHumidity, 90) -- At least 90% RH with any fog
  elseif iVisibilityMeters < 10000 then
    -- Increase RH as visibility decreases
    local nVisibilityFactor = math.max(0, (10000 - iVisibilityMeters) / 10000)
    nHumidity = nHumidity + (nVisibilityFactor * 20) -- Up to +20% for low visibility
  end

  -- Precipitation adjustments
  if bPrecipitations then
    nHumidity = math.max(nHumidity, 80)
  end

  -- Clamp final value
  return math.max(0, math.min(100, nHumidity))
end

local function _computeDewpoint(nTemperatureCelcius, nQnhPa, nHumidity)
  local nQnhHpa = nQnhPa / 100

  -- Constants for Magnus formula
  local a = 17.27
  local b = 237.7

  -- Calculate gamma term
  local gamma = ((a * nTemperatureCelcius) / (b + nTemperatureCelcius)) + math.log(nHumidity / 100.0)

  -- Calculate dew point using Magnus formula
  local nDewPointCelcius = (b * gamma) / (a - gamma)

  -- Apply pressure correction (approximate)
  local pressure_correction = (1013.25 - nQnhHpa) * 0.0012
  nDewPointCelcius = nDewPointCelcius + pressure_correction

  nDewPointCelcius = math.min(nDewPointCelcius, nTemperatureCelcius)
  -- Round to one decimal place
  return math.floor(nDewPointCelcius * 10 + 0.5) / 10
end

local function _weatherSliceAtAltitude(vec3, iAltitudeMeters)
  local nTemperatureKelvin, nPressurePa = atmosphere.getTemperatureAndPressure({ x = vec3.x, y = iAltitudeMeters, z = vec3.z })
  local iWindDir, iWindSpeedMps = veafWeather.getWind(vec3, iAltitudeMeters)

  return {
    AltitudeMeters = iAltitudeMeters,
    PressureHpa = nPressurePa / 100,
    TemperatureCelcius = nTemperatureKelvin + _nKelvinToCelciusOffset,
    WindDirection = iWindDir,
    WindSpeedMps = iWindSpeedMps,
  }
end

local function _getFlightLevelString(iAltitudeFeet)
  -- Round to nearest 500
  local iAltitudeFeetRounded = math.floor((iAltitudeFeet + 250) / 500) * 500

  -- Convert to flight level format (divide by 100)
  local iFlightLevel = math.floor(iAltitudeFeetRounded / 100)

  return string.format("FL%03d", iFlightLevel)
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  Weather measurement unit systems class
---  Defines a set of units to be used to display weather data
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
veafWeatherUnitSystem = {}
veafWeatherUnitSystem.__index = veafWeatherUnitSystem

veafWeatherUnitSystem.Units = {
  Kts = 0,
  Mps = 1,
  M = 2,
  Sm = 3,
  Nm = 4,
  Ft = 5,
  Hpa = 6,
  InHg = 7,
  MmHg = 8,
}
---------------------------------------------------------------------------------------------------
---  CTOR
function veafWeatherUnitSystem:create(windSpeeds, visibilities, altitudes, pressures)
  local this = {
    WindSpeeds = windSpeeds,
    Visibilities = visibilities,
    Altitudes = altitudes,
    Pressures = pressures,
  }

  setmetatable(this, veafWeatherUnitSystem)
  return this
end

---------------------------------------------------------------------------------------------------
---  Static data
veafWeatherUnitSystem.Systems = {
  Full = veafWeatherUnitSystem:create(
    { veafWeatherUnitSystem.Units.Kts, veafWeatherUnitSystem.Units.Mps },
    { veafWeatherUnitSystem.Units.M, veafWeatherUnitSystem.Units.Sm, veafWeatherUnitSystem.Units.Nm },
    { veafWeatherUnitSystem.Units.Ft, veafWeatherUnitSystem.Units.M },
    { veafWeatherUnitSystem.Units.Hpa, veafWeatherUnitSystem.Units.InHg, veafWeatherUnitSystem.Units.MmHg }
  ), -- all
  Icao = veafWeatherUnitSystem:create(
    { veafWeatherUnitSystem.Units.Kts },
    { veafWeatherUnitSystem.Units.M },
    { veafWeatherUnitSystem.Units.Ft },
    { veafWeatherUnitSystem.Units.Hpa }
  ), -- default
  IcaoMetric = veafWeatherUnitSystem:create(
    { veafWeatherUnitSystem.Units.Mps },
    { veafWeatherUnitSystem.Units.M },
    { veafWeatherUnitSystem.Units.Ft },
    { veafWeatherUnitSystem.Units.Hpa }
  ), -- for russian airfields
  Faa = veafWeatherUnitSystem:create(
    { veafWeatherUnitSystem.Units.Kts },
    { veafWeatherUnitSystem.Units.Sm },
    { veafWeatherUnitSystem.Units.Ft },
    { veafWeatherUnitSystem.Units.InHg }
  ), -- for US aircrafts or airfields, and for older british aircrafts
  FaaMetric = veafWeatherUnitSystem:create(
    { veafWeatherUnitSystem.Units.Kts },
    { veafWeatherUnitSystem.Units.M },
    { veafWeatherUnitSystem.Units.Ft },
    { veafWeatherUnitSystem.Units.InHg }
  ), -- for US army helicopters
  FaaNavy = veafWeatherUnitSystem:create(
    { veafWeatherUnitSystem.Units.Kts },
    { veafWeatherUnitSystem.Units.Nm },
    { veafWeatherUnitSystem.Units.Ft },
    { veafWeatherUnitSystem.Units.InHg }
  ), -- for US aircraft carriers
  Metric = veafWeatherUnitSystem:create(
    { veafWeatherUnitSystem.Units.Mps },
    { veafWeatherUnitSystem.Units.M },
    { veafWeatherUnitSystem.Units.M },
    { veafWeatherUnitSystem.Units.Hpa }
  ), -- for french army helicopters
  MetricEastern = veafWeatherUnitSystem:create(
    { veafWeatherUnitSystem.Units.Mps },
    { veafWeatherUnitSystem.Units.M },
    { veafWeatherUnitSystem.Units.M },
    { veafWeatherUnitSystem.Units.MmHg }
  ), -- for russian and chinese aircrafts
}
veafWeatherUnitSystem.DefaultUnitSystem = veafWeatherUnitSystem.Systems.Icao

veafWeatherUnitSystem.Theatres = {}
veafWeatherUnitSystem.Theatres.Faa = { veaf.theatreName.Nevada, veaf.theatreName.MarianaIslands }
veafWeatherUnitSystem.Theatres.IcaoMetric = { veaf.theatreName.Caucasus }

veafWeatherUnitSystem.Aircrafts = {}
veafWeatherUnitSystem.Aircrafts.Faa = {
  "A-10A",
  "A-10C",
  "A-10C_2",
  "AV8BNA",
  "F-14A-135-GR",
  "F-14B",
  "F-15C",
  "F-15ESE",
  "F-16C_50",
  "FA-18C_hornet",
  "F-4E-45MC",
  "UH-1H",
  "P-47D-30",
  "P-47D-40",
  "P-51D",
  "P-51D-30-NA",
  "TF-51D",
  "Christen Eagle II",
  "SpitfireLFMkIX",
  "MosquitoFBMkVI",
}

veafWeatherUnitSystem.Aircrafts.Metric = {
  "SA342L",
  "SA342M",
  "SA342Minigun",
  "SA342Mistral",
}

veafWeatherUnitSystem.Aircrafts.MetricEastern = {
  "Ka-50",
  "Ka-50_3",
  "Mi-8MTV2",
  "Mi-24P",
  "MiG-15bis",
  "MiG-19P",
  "MiG-21Bis",
  "MiG-29S",
  "Su-25",
  "Su-25T",
  "Su-27",
  "Su-33",
  "J-11A",
  "FW-190A8",
  "FW-190D9",
  "I-16",
  "L-39C",
  "L-39ZA",
  "Yak-52",
}

veafWeatherUnitSystem.Aircrafts.FaaMetric = {
  "AH-64D_BLK_II",
}

---------------------------------------------------------------------------------------------------
---  Methods
---

function veafWeatherUnitSystem.defaultForTypeName(sTypeName)
  if veaf.tableContains(veafWeatherUnitSystem.Aircrafts.Faa, sTypeName) then
    return veafWeatherUnitSystem.Systems.Faa
  elseif veaf.tableContains(veafWeatherUnitSystem.Aircrafts.Metric, sTypeName) then
    return veafWeatherUnitSystem.Systems.Metric
  elseif veaf.tableContains(veafWeatherUnitSystem.Aircrafts.MetricEastern, sTypeName) then
    return veafWeatherUnitSystem.Systems.MetricEastern
  elseif veaf.tableContains(veafWeatherUnitSystem.Aircrafts.FaaMetric, sTypeName) then
    return veafWeatherUnitSystem.Systems.FaaMetric
  else
    return veafWeatherUnitSystem.DefaultUnitSystem
  end
end

function veafWeatherUnitSystem.defaultForTheatre()
  local sTheatre = env.mission.theatre

  if veaf.tableContains(veafWeatherUnitSystem.Theatres.Faa, sTheatre) then
    return veafWeatherUnitSystem.Systems.Faa
  elseif veaf.tableContains(veafWeatherUnitSystem.Theatres.IcaoMetric, sTheatre) then
    return veafWeatherUnitSystem.Systems.IcaoMetric
  else
    return veafWeatherUnitSystem.DefaultUnitSystem
  end
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  Weather management class
---  Collects and compile wheather data form various sources in the sim at a location
---  Can be output to string as METAR or ATIS informations
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
veafWeatherData = {}
veafWeatherData.__index = veafWeatherData

---------------------------------------------------------------------------------------------------
---  CTOR
function veafWeatherData:create(vec3, iAbsTime, iAltitudeMeters)
  iAbsTime = iAbsTime or timer.getAbsTime()
  iAltitudeMeters = iAltitudeMeters or veaf.getLandHeight(vec3)

  local sunTimesZulu = veafTime.getSunTimesZulu(vec3)
  local sunTimesLocal = veafTime.getSunTimesLocal(vec3)

  local iWindDirSurface, iWindSpeedSurfaceMps = veafWeather.getWind(vec3, iAltitudeMeters + 10) -- Measure the wind velocity at the standard height of 10 metres above the surface. This is the internationally accepted meteorological definition of ‘surface wind’ designed to eliminate distortion attributable to very local terrain effects

  -- the static env.mission.weather.visibility.distance is not used anymore, and the DCS engine apparently sets a default at 100000, as seen in this log line:
  -- WEATHER (Main): set fog: visibility:100000  thickness:0.0
  local iVisibilityMeters = 100000
  local clouds = nil
  local bPrecipitation = false
  local sCloudPreset = env.mission.weather.clouds.preset
  if veaf.isNullOrEmpty(sCloudPreset) then
    if env.mission.weather.clouds.density > 0 then
      local iDensity = veaf.round(env.mission.weather.clouds.density * 8 / 10) -- 10 levels in dcs, convert to oktas
      clouds = { Density = iDensity, BaseMeters = env.mission.weather.clouds.base }
    end
    bPrecipitation = (env.mission.weather.clouds.iprecptns > 0)
  else
    if _dcsPresetDensity[sCloudPreset] then
      clouds = { Density = _dcsPresetDensity[sCloudPreset][1], BaseMeters = env.mission.weather.clouds.base }
      bPrecipitation = _dcsPresetDensity[sCloudPreset][2]
      --[[ -- visibilities in presets were already not reliable, and they have no meaning with the new fog visiblity setting
            if (_dcsPresetDensity[sCloudPreset][3] and _dcsPresetDensity[sCloudPreset][3] < iVisibilityMeters) then
                iVisibilityMeters = _dcsPresetDensity[sCloudPreset][3]
            end
            ]]
    end
  end

  local iFogThicknessMeters = world.weather.getFogThickness()
  local iFogVisibilityMeters = world.weather.getFogVisibilityDistance()
  if iFogThicknessMeters >= iAltitudeMeters then
    iVisibilityMeters = iFogVisibilityMeters
    veaf.loggers.get(veafWeather.Id):trace("Visibility new fog=%d", iVisibilityMeters)
  else
    veaf.loggers.get(veafWeather.Id):trace(
      "Visibility=%d. New fog ignored, measure point above fog ceiling [ altitude=%d, fog thickness=%d ]",
      iVisibilityMeters,
      iAltitudeMeters,
      iFogThicknessMeters
    )
  end

  local _, nQfePa = atmosphere.getTemperatureAndPressure({ x = vec3.x, y = iAltitudeMeters, z = vec3.z })
  local nTemperatureKelvin, nQnhPa = atmosphere.getTemperatureAndPressure({ x = vec3.x, y = 0, z = vec3.z })
  local nTemperatureCelcius = nTemperatureKelvin + _nKelvinToCelciusOffset
  local nBaseMeters = clouds and clouds.BaseMeters or 99999
  local nHumidity = _computeHumidity(vec3, nBaseMeters, iVisibilityMeters, bPrecipitation, iAbsTime)
  local nDewPointCelcius = _computeDewpoint(nTemperatureCelcius, nQnhPa, nHumidity)

  -- Fog FG or mist BR: fog is less than 1000 meters visibility. Mist BR or haze HZ: if the humidity is more than 80% it is mist.
  local visibilityAffect = _visibilityAffect.None
  if iVisibilityMeters < 1000 then
    visibilityAffect = _visibilityAffect.Fog
  elseif iVisibilityMeters < 5000 and nHumidity >= 80 then
    visibilityAffect = _visibilityAffect.Mist
  elseif iVisibilityMeters < 5000 then
    visibilityAffect = _visibilityAffect.Haze
  end

  local weatherSlices = {}
  if iAltitudeMeters < 600 then
    table.insert(weatherSlices, _weatherSliceAtAltitude(vec3, 500))
  end
  if iAltitudeMeters < 2100 then
    table.insert(weatherSlices, _weatherSliceAtAltitude(vec3, 2000))
  end
  if iAltitudeMeters < 8100 then
    table.insert(weatherSlices, _weatherSliceAtAltitude(vec3, 8000))
  end

  local this = {
    AbsTime = iAbsTime,
    Vec3 = vec3,
    AltitudeMeter = iAltitudeMeters,
    WindDirection = iWindDirSurface,
    WindSpeedMps = iWindSpeedSurfaceMps,
    VisibilityMeters = iVisibilityMeters,
    Dust = env.mission.weather.enable_dust,
    VisibilityAffect = visibilityAffect,
    Clouds = clouds,
    Precipitation = bPrecipitation,
    TemperatureCelcius = nTemperatureCelcius,
    DewPointCelcius = nDewPointCelcius,
    QnhHpa = nQnhPa / 100,
    QfeHpa = nQfePa / 100,
    SunriseZulu = sunTimesZulu.Sunrise,
    SunsetZulu = sunTimesZulu.Sunset,
    SunriseLocal = sunTimesLocal.Sunrise,
    SunsetLocal = sunTimesLocal.Sunset,

    WeatherSlices = weatherSlices,
  }

  setmetatable(this, veafWeatherData)

  veaf.loggers.get(veafWeather.Id):trace(this:toString(veafWeatherUnitSystem.Systems.Faa))
  veaf.loggers.get(veafWeather.Id):trace(this:toString(veafWeatherUnitSystem.Systems.FaaNavy))
  veaf.loggers.get(veafWeather.Id):trace(this:toString(veafWeatherUnitSystem.Systems.Icao))

  return this
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Static methods
function veafWeatherData.getWeatherString(vec3, dcsElementName, unitSystem, iSurfaceAltitudeMeters)
  local bWithLaste = false

  local sTypeName = veaf.getDcsTypeName(dcsElementName)

  if unitSystem == nil then
    unitSystem = veafWeatherUnitSystem.defaultForTypeName(sTypeName)
  end

  if not veaf.isNullOrEmpty(sTypeName) and veaf.startsWith(sTypeName, "A-10", false) then
    bWithLaste = true
  end

  local weatherData = veafWeatherData:create(vec3, nil, iSurfaceAltitudeMeters)
  return weatherData:toString(unitSystem, bWithLaste)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Methods
function veafWeatherData:getNormalizedWindDirection(iDirectionTrue, bMagnetic)
  bMagnetic = bMagnetic or false

  local iDirection = iDirectionTrue

  if bMagnetic then
    iDirection = iDirection - veaf.getMagneticDeclination()
    if iDirection < 0 then
      iDirection = iDirection + 360
    end
  end

  if iDirection == 0 then
    iDirection = 360
  end

  return iDirection
end

function veafWeatherData:getNormalizedCloudBaseMeters(bHeight)
  bHeight = bHeight or false

  if self.Clouds == nil or self.Clouds.Density <= 0 then
    return nil
  else
    local iCloudBase = self.Clouds.BaseMeters
    if bHeight then
      iCloudBase = iCloudBase - self.AltitudeMeter
    end

    return iCloudBase
  end
end

function veafWeatherData:getNormalizedCloudsDensity()
  if self.Clouds == nil or self.Clouds.BaseMeters == nil or self.Clouds.Density <= 0 then
    return _cloudDensity.Clear
  else
    return _cloudDensityOktas[self.Clouds.Density]
  end
end

function veafWeatherData:isCavok()
  local iCloudHeightMeters = self:getNormalizedCloudBaseMeters(true)

  if iCloudHeightMeters == nil or veaf.metersToFeet(iCloudHeightMeters) < 5000 then
    return false -- no clouds or cloud below 5000 ft
  else
    return (self.VisibilityMeters >= 10000 and not self.Precipitation and not self.Dust)
  end
end

function veafWeatherData:getCarrierCase()
  -- Case I departures are flown during the day when weather conditions allow departure under visual flight rules (VFR). The weather minimums are a cloud deck above 3,000 feet and visibility greater than 5 miles
  -- Case II departures are flown during the day when visual conditions are present at the carrier, but a controlled climb through the clouds is required. The weather minimums are a cloud deck above 1,000 feet and visibility greater than 5 miles.
  -- Case III departures are flown at night and when weather conditions are below the minimums of 1,000 feet cloud deck and 5 miles visibility

  local bNight = veafTime.isAeronauticalNight(self.Vec3, self.AbsTime)
  if bNight then
    return 3
  end

  local iCloudBase = nil
  if self.Clouds and self.Clouds.Density > 4 then
    iCloudBase = self.Clouds.BaseMeters
  end

  local iVisibilityCase12 = veaf.NMToMeters(5)
  local iCloudBaseCase1 = veaf.feetToMeters(3000)
  local iCloudBaseCase2 = veaf.feetToMeters(1000)

  --veaf.loggers.get(veaf.Id):trace(string.format("GetCarrierCase - Cloud base=%d feet (need more than 1000 for CASE 2 and 300 for CASE 3) - visibility=%d nm (need more than 5 for CASE 1/2)", iCloudBase or -1, UTILS.MetersToNM (self.VisibilityMeters)))

  if self.VisibilityMeters > iVisibilityCase12 and (iCloudBase == nil or iCloudBase > iCloudBaseCase1) then
    return 1
  elseif self.VisibilityMeters > iVisibilityCase12 and (iCloudBase == nil or iCloudBase > iCloudBaseCase2) then
    return 2
  else
    return 3
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ToStrings
function veafWeatherData:appendString(s, sAppend)
  sAppend = sAppend or ""

  if veaf.isNullOrEmpty(s) then
    return sAppend
  elseif veaf.isNullOrEmpty(sAppend) then
    return s
  else
    return s .. "|" .. sAppend
  end
end

function veafWeatherData:toStringWind(unitSystem, iDirection, nSpeedMps, bMagnetic)
  unitSystem = unitSystem or veafWeatherUnitSystem.DefaultUnitSystem
  bMagnetic = bMagnetic or false

  if nSpeedMps <= 0.5 then
    return veaf.t("weather.wind_calm")
  end

  local iDirection = self:getNormalizedWindDirection(iDirection, bMagnetic)
  local sSpeedKts = string.format("%dkts", math.floor(veaf.mpsToKnots(nSpeedMps)))
  local sSpeedMps = string.format("%dm/s", math.floor(nSpeedMps))
  local sSpeed
  if veaf.tableContains(unitSystem.WindSpeeds, veafWeatherUnitSystem.Units.Kts) then
    sSpeed = veafWeatherData:appendString(sSpeed, sSpeedKts)
  end
  if veaf.tableContains(unitSystem.WindSpeeds, veafWeatherUnitSystem.Units.Mps) then
    sSpeed = veafWeatherData:appendString(sSpeed, sSpeedMps)
  end

  local sDegrees
  if bMagnetic then
    sDegrees = "°M"
  else
    sDegrees = "°T"
  end

  return string.format("%03d%s @ %s", iDirection, sDegrees, sSpeed)
end

function veafWeatherData:toStringVisibility(unitSystem, bWithMax)
  unitSystem = unitSystem or veafWeatherUnitSystem.DefaultUnitSystem

  local sVisibilityMeters
  if self.VisibilityMeters >= 10000 then
    sVisibilityMeters = "10+km"
  else
    local iVisibilityMeters
    if self.VisibilityMeters >= 100 then
      iVisibilityMeters = veaf.round(self.VisibilityMeters / 100) * 100
    else
      iVisibilityMeters = veaf.round(self.VisibilityMeters / 50) * 50
    end

    sVisibilityMeters = string.format("%dm", iVisibilityMeters)
  end

  local sVisibilityStatuteMile
  local iVisibilityStatuteMile = self.VisibilityMeters * 0.000621371
  if iVisibilityStatuteMile >= 10 then
    sVisibilityStatuteMile = "10+SM"
  elseif iVisibilityStatuteMile >= 1 then
    sVisibilityStatuteMile = string.format("%dSM", veaf.round(iVisibilityStatuteMile))
  elseif iVisibilityStatuteMile >= 0.75 then
    sVisibilityStatuteMile = "3/4SM"
  elseif iVisibilityStatuteMile >= 0.5 then
    sVisibilityStatuteMile = "1/2SM"
  elseif iVisibilityStatuteMile >= 0.25 then
    sVisibilityStatuteMile = "1/4SM"
  else
    sVisibilityStatuteMile = "0SM"
  end

  local sVisibilityNauticalMile
  local iVisibilityNauticalMile = veaf.metersToNM(self.VisibilityMeters)
  if iVisibilityNauticalMile >= 10 then
    sVisibilityNauticalMile = "10+NM"
  elseif iVisibilityNauticalMile >= 1 then
    sVisibilityNauticalMile = string.format("%dNM", veaf.round(iVisibilityNauticalMile))
  else
    local iVisibilityYards = veaf.round((iVisibilityNauticalMile * 2025.37) / 100) * 100
    sVisibilityNauticalMile = string.format("%dyds", iVisibilityYards)
  end

  local sVisibility
  if veaf.tableContains(unitSystem.Visibilities, veafWeatherUnitSystem.Units.M) then
    sVisibility = veafWeatherData:appendString(sVisibility, sVisibilityMeters)
  end
  if veaf.tableContains(unitSystem.Visibilities, veafWeatherUnitSystem.Units.Sm) then
    sVisibility = veafWeatherData:appendString(sVisibility, sVisibilityStatuteMile)
  end
  if veaf.tableContains(unitSystem.Visibilities, veafWeatherUnitSystem.Units.Nm) then
    sVisibility = veafWeatherData:appendString(sVisibility, sVisibilityNauticalMile)
  end

  if self.VisibilityAffect == _visibilityAffect.Fog then
    sVisibility = sVisibility .. veaf.t("weather.vis_fog")
  elseif self.VisibilityAffect == _visibilityAffect.Haze then
    sVisibility = sVisibility .. veaf.t("weather.vis_haze")
  elseif self.VisibilityAffect == _visibilityAffect.Mist then
    sVisibility = sVisibility .. veaf.t("weather.vis_mist")
  end
  if self.Dust then
    sVisibility = sVisibility .. veaf.t("weather.vis_dust")
  end
  if self.Precipitation then
    sVisibility = sVisibility .. veaf.t("weather.vis_precipitations")
  end

  return sVisibility
end

function veafWeatherData:toStringClouds(unitSystem, bHeight)
  unitSystem = unitSystem or veafWeatherUnitSystem.DefaultUnitSystem
  bHeight = bHeight or false

  local cloudDensity = self:getNormalizedCloudsDensity()
  local iCloudBaseMeters = self:getNormalizedCloudBaseMeters(bHeight)

  local sCloudDensity = ""
  local sCloudBase = ""

  if cloudDensity == _cloudDensity.Clear then
    sCloudDensity = veaf.t("weather.clouds_none")
  else
    if cloudDensity == _cloudDensity.Scattered then
      sCloudDensity = veaf.t("weather.clouds_scattered")
    elseif cloudDensity == _cloudDensity.Broken then
      sCloudDensity = veaf.t("weather.clouds_broken")
    elseif cloudDensity == _cloudDensity.Overcast then
      sCloudDensity = veaf.t("weather.clouds_overcast")
    else
      sCloudDensity = veaf.t("weather.clouds_few")
    end

    if iCloudBaseMeters ~= nil and iCloudBaseMeters > 0 then
      local iCloudBaseFeet = math.floor((veaf.metersToFeet(iCloudBaseMeters) + 250) / 500) * 500
      local iCloudBaseMeters = math.floor((iCloudBaseMeters + 250) / 500) * 500
      local sCloudBaseFeet = string.format("%dft", iCloudBaseFeet)
      local sCloudBaseMeters = string.format("%dm", iCloudBaseMeters)

      if veaf.tableContains(unitSystem.Altitudes, veafWeatherUnitSystem.Units.Ft) then
        sCloudBase = veafWeatherData:appendString(sCloudBase, sCloudBaseFeet)
      end
      if veaf.tableContains(unitSystem.Altitudes, veafWeatherUnitSystem.Units.M) then
        sCloudBase = veafWeatherData:appendString(sCloudBase, sCloudBaseMeters)
      end

      sCloudBase = string.format(" @ %s", sCloudBase)

      if bHeight then
        sCloudBase = sCloudBase .. " AGL"
      else
        sCloudBase = sCloudBase .. " ASL"
      end
    end
  end

  return string.format("%s%s", sCloudDensity, sCloudBase)
end

function veafWeatherData:toStringTemperature(nTemperatureCelcius)
  return string.format("%d°C", veaf.round(nTemperatureCelcius))
end

function veafWeatherData:toStringPressure(unitSystem, nPressureHpa)
  unitSystem = unitSystem or veafWeatherUnitSystem.DefaultUnitSystem

  local sPressureHpa = string.format("%.0fHpa", nPressureHpa)
  local sPressureInHg = string.format("%.2finHg", veaf.hPaToInHg(nPressureHpa))
  local sPressureMmHg = string.format("%.0fmmHg", nPressureHpa * 0.75006375541921) -- mist convert has the wrong coefficient for hpa to mmHg

  local sPressure
  if veaf.tableContains(unitSystem.Pressures, veafWeatherUnitSystem.Units.Hpa) then
    sPressure = veafWeatherData:appendString(sPressure, sPressureHpa)
  end
  if veaf.tableContains(unitSystem.Pressures, veafWeatherUnitSystem.Units.InHg) then
    sPressure = veafWeatherData:appendString(sPressure, sPressureInHg)
  end
  if veaf.tableContains(unitSystem.Pressures, veafWeatherUnitSystem.Units.MmHg) then
    sPressure = veafWeatherData:appendString(sPressure, sPressureMmHg)
  end

  return sPressure
end

function veafWeatherData:toStringSunTime(dateTimeZulu, bZulu, bLocal)
  local sLocal = ""
  if bLocal then
    local dateTimeLocal = veafTime.toLocal(dateTimeZulu)
    sLocal = string.format("%sL", veafTime.toStringTime(dateTimeLocal, false))
  end

  local sZulu = ""
  if bZulu then
    sZulu = string.format("%sZ", veafTime.toStringTime(dateTimeZulu, false))
  end

  if bLocal and bZulu then
    return string.format("%s - %s", sZulu, sLocal)
  elseif bLocal then
    return sLocal
  else
    return sZulu
  end
end

function veafWeatherData:toStringSlice(weatherSlice, unitSystem, bMagnetic)
  unitSystem = unitSystem or veafWeatherUnitSystem.DefaultUnitSystem
  bMagnetic = bMagnetic or false

  local sAltitudeMeters = string.format("%dm", weatherSlice.AltitudeMeters)
  local sAltitudeFl = _getFlightLevelString(veaf.metersToFeet(weatherSlice.AltitudeMeters))

  local sAltitude
  if veaf.tableContains(unitSystem.Altitudes, veafWeatherUnitSystem.Units.Ft) then
    sAltitude = veafWeatherData:appendString(sAltitude, sAltitudeFl)
  end
  if veaf.tableContains(unitSystem.Altitudes, veafWeatherUnitSystem.Units.M) then
    sAltitude = veafWeatherData:appendString(sAltitude, sAltitudeMeters)
  end

  local sTemperature = self:toStringTemperature(weatherSlice.TemperatureCelcius)
  local sPressure = self:toStringPressure(unitSystem, weatherSlice.PressureHpa)
  local sWind = self:toStringWind(unitSystem, weatherSlice.WindDirection, weatherSlice.WindSpeedMps, bMagnetic)

  return string.format("%s:  wind %s ; %s", sAltitude, sWind, sTemperature)
end

function veafWeatherData:toStringLaste()
  local function _getLasteAt(iDesiredHeightFeet)
    local iAltitudeFeet = math.floor((veaf.metersToFeet(self.AltitudeMeter) + iDesiredHeightFeet + 500) / 1000) * 1000
    local iAltitudeMeters = veaf.feetToMeters(iAltitudeFeet)
    local iTemperatureKelvin, _ = atmosphere.getTemperatureAndPressure({ x = self.Vec3.x, y = iAltitudeMeters, z = self.Vec3.z })
    local iWindDirection, iWindSpeedMps = veafWeather.getWind(self.Vec3, iAltitudeMeters)
    local iWindDirectionMagnetic = veafWeatherData:getNormalizedWindDirection(iWindDirection, true)

    local sLaste = string.format(
      "ALT%02d W%03d/%02d T%+d",
      iAltitudeFeet / 1000,
      iWindDirectionMagnetic,
      veaf.mpsToKnots(iWindSpeedMps),
      iTemperatureKelvin + _nKelvinToCelciusOffset
    )
    veaf.loggers.get(veafWeather.Id):trace(string.format("LASTE @ %f - W%dM %dT", iAltitudeFeet, iWindDirectionMagnetic, iWindDirection))
    veaf.loggers.get(veafWeather.Id):trace(sLaste)
    return sLaste
  end

  local sLaste = ""
  sLaste = sLaste .. string.format("\n%s", _getLasteAt(2000))
  sLaste = sLaste .. string.format("\n%s", _getLasteAt(8000))
  sLaste = sLaste .. string.format("\n%s", _getLasteAt(16000))
  --sLaste = sLaste .. string.format("\n%s", _getLasteAt(28000))

  return sLaste
end

function veafWeatherData:toString(unitSystem, bWithLaste)
  unitSystem = unitSystem or veafWeatherUnitSystem.DefaultUnitSystem
  bWithLaste = bWithLaste or false

  local sString = ""
  sString = sString .. veaf.t("weather.line_wind", self:toStringWind(unitSystem, self.WindDirection, self.WindSpeedMps))
  sString = sString .. "\n"
  sString = sString .. veaf.t("weather.line_visibility", self:toStringVisibility(unitSystem))
  sString = sString .. veaf.t("weather.line_clouds", self:toStringClouds(unitSystem, true))
  sString = sString .. "\n"
  sString = sString
    .. veaf.t("weather.line_temp_dew", self:toStringTemperature(self.TemperatureCelcius), self:toStringTemperature(self.DewPointCelcius))
  sString = sString .. veaf.t("weather.line_qnh", self:toStringPressure(unitSystem, self.QnhHpa))
  sString = sString .. veaf.t("weather.line_qfe", self:toStringPressure(unitSystem, self.QfeHpa))
  sString = sString .. veaf.t("weather.line_sunrise", self:toStringSunTime(self.SunriseZulu, true, true))
  sString = sString .. veaf.t("weather.line_sunset", self:toStringSunTime(self.SunsetZulu, true, true))

  sString = sString .. "\n"
  if bWithLaste then
    sString = sString .. string.format("\nLASTE:%s", self:toStringLaste())
  else
    for _, weatherSlice in pairs(self.WeatherSlices) do
      sString = sString .. string.format("\n @ %s", self:toStringSlice(weatherSlice, unitSystem))
    end
  end

  return sString
end

function veafWeatherData:toStringExtended(unitSystem, bHeight)
  unitSystem = unitSystem or veafWeatherUnitSystem.DefaultUnitSystem

  local sAltitudeFeet = string.format("%dft", veaf.round(veaf.metersToFeet(self.AltitudeMeter)))
  local sAltitudeMeters = string.format("%dm", veaf.round(self.AltitudeMeter))
  local sAltitude
  if veaf.tableContains(unitSystem.Altitudes, veafWeatherUnitSystem.Units.Ft) then
    sAltitude = veafWeatherData:appendString(sAltitude, sAltitudeFeet)
  end
  if veaf.tableContains(unitSystem.Altitudes, veafWeatherUnitSystem.Units.M) then
    sAltitude = veafWeatherData:appendString(sAltitude, sAltitudeMeters)
  end

  local nLatitude, nLongitude = coord.LOtoLL(self.Vec3)

  local sString = ""
  sString = sString .. veaf.t("weather.line_time", veafTime.absTimeToStringDateTime(self.AbsTime))
  sString = sString .. veaf.t("weather.line_location", veaf.toStringLL(nLatitude, nLongitude, 0, true))
  sString = sString .. veaf.t("weather.line_altitude", sAltitude)
  sString = sString .. "\n\n" .. self:toString(unitSystem, bHeight)
  return sString
end

function veafWeatherData:toStringAtis(unitSystem)
  unitSystem = unitSystem or veafWeatherUnitSystem.DefaultUnitSystem

  local sAtis = ""
  sAtis = sAtis .. veaf.t("weather.atis_wind", self:toStringWind(unitSystem, self.WindDirection, self.WindSpeedMps, true))
  if self:isCavok() then
    sAtis = sAtis .. veaf.t("weather.atis_cavok")
  else
    sAtis = sAtis .. veaf.t("weather.atis_visibility", self:toStringVisibility(unitSystem), self:toStringClouds(unitSystem, true))
  end

  sAtis = sAtis
    .. veaf.t("weather.atis_temp_dew", self:toStringTemperature(self.TemperatureCelcius), self:toStringTemperature(self.DewPointCelcius))
  sAtis = sAtis .. veaf.t("weather.atis_qnh", self:toStringPressure(unitSystem, self.QnhHpa))

  if veafTime.isAeronauticalNight(self.Vec3, self.AbsTime) then
    sAtis = sAtis .. veaf.t("weather.atis_sunrise", self:toStringSunTime(self.SunriseZulu, true, false))
  else
    sAtis = sAtis .. veaf.t("weather.atis_sunset", self:toStringSunTime(self.SunsetZulu, true, false))
  end

  return sAtis
end
--[[
function FgWeather:ToStringMetar()
    local iWindForce, iWindDirection = self:GetFormattedWind()
    local sWind
    if (iWindForce < 1) then
        sWind = "00000KT"
    else
        iWindDirection = UTILS.Round(iWindDirection / 10) * 10
        if (iWindDirection == 0) then
            iWindDirection = 360
        end
        sWind = string.format("%03d%02dKT", iWindDirection, iWindForce)
    end

    local iVisibility = UTILS.Round(self.VisibilityMeters / 100) * 100
    if (iVisibility >= 10000) then
        iVisibility = 9999
    end
    local sVisibility = string.format("%04d", iVisibility)

    local sSignificativeWeather = nil
    if (self.Precipitation) then
        sSignificativeWeather = "RA" -- TODO rain will be snow if season+map+t° ?
    end
    if (self.Fog) then
        sSignificativeWeather = Fg.AppendWithSeparator(sSignificativeWeather, "FG")
    end
    if (self.Dust) then
        sSignificativeWeather = Fg.AppendWithSeparator(sSignificativeWeather, "DU")
    end

    sVisibility = Fg.AppendWithSeparator(sVisibility, sSignificativeWeather)

    local sClouds
    local cloudDensity, iCloudBase = self:GetFormattedClouds(true)
    if (cloudDensity == CloudDensityLabel.Clear) then
        sClouds = "SKC"
    elseif (cloudDensity == CloudDensityLabel.Cavok) then
        sClouds = "CAVOK"
        sVisibility = nil
    else
        local sDensity = "FEW"
        if (cloudDensity == CloudDensityLabel.Scattered) then
            sDensity = "SCT"
        elseif (cloudDensity == CloudDensityLabel.Broken) then
            sDensity = "BKN"
        elseif (cloudDensity == CloudDensityLabel.Overcast) then
            sDensity = "OVC"
        end
           
        sClouds = string.format("%s%03d", sDensity, iCloudBase)
    end

    local sTemperature
    local iTemperature = UTILS.Round(self.TemperatureCelcius)
    if (iTemperature >= 0) then
        sTemperature = string.format("%02d", iTemperature)
    else
        sTemperature = string.format("M%02d", -iTemperature)
    end

    local sQnh = string.format("Q%d/%.2f", self.QnhHpa, UTILS.hPa2inHg(self.QnhHpa))

    local sMetar = Fg.TimeToStringMetar()
    sMetar = sMetar .. " " .. sWind
    sMetar = Fg.AppendWithSeparator (sMetar, sVisibility, " ")
    sMetar = sMetar .. " " .. sClouds
    sMetar = sMetar .. " " .. sTemperature
    sMetar = sMetar .. " " .. sQnh

    return sMetar
end

function FgWeather.CreateMetarMark(mooseCoord, mooseGroup)
    local weather = FgWeather:Create(mooseCoord)
    local sMetar = weather:ToStringMetar()

    local vec3 = mooseCoord:GetVec3()
    local iMarkId = UTILS.GetMarkID()
    if (mooseGroup) then
        trigger.action.markToGroup(iMarkId, sMetar, vec3, mooseGroup:GetDCSObject():getID(), false, nil)
    else
        trigger.action.markToAll(iMarkId, sMetar, vec3, false, nil)
    end

    return iMarkId
end
]]
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  ATIS management class
---  Simulation of the recording of an ATIS information per hour per airfield
---  For each info a recording time and corresponding letter is generated (just to fluff it)
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
veafWeatherAtis = {}
veafWeatherAtis.__index = veafWeatherAtis
veafWeatherAtis.ListInEffect = {}
---------------------------------------------------------------------------------------------------
---  CTORS
function veafWeatherAtis:Create(veafAirbase, dateTimeZulu)
  if not veafAirbase.DcsAirbase or not veafAirbase.DcsAirbase:isExist() then
    veaf.loggers
      .get(veafWeather.Id)
      :debug("veafWeatherAtis:Create - airbase [%s] DCS object no longer exists, skipping ATIS", veafAirbase.Name)
    return nil
  end
  local iHoursSinceMidnight = dateTimeZulu.hour
  local sLetter = string.char(math.floor(iHoursSinceMidnight) + string.byte("A"))

  local iRecordedAtMinutes = math.random(2, 11) -- ATIS recorded between h:02 and hour:11
  if iRecordedAtMinutes > dateTimeZulu.min then
    -- if record is in the future set recording at the request time
    iRecordedAtMinutes = dateTimeZulu.min
  end
  dateTimeZulu.min = iRecordedAtMinutes

  local iAltitude = nil
  local unitSystem
  if veafAirbase.Category == Airbase.Category.SHIP then
    -- Maybe use the type name to decide the unit system?
    --[[
        local dcsShip = dcsAirbase:getUnit()
        local dcsShipType = dcsShip:getTypeName()
        veaf.loggers.get(veafWeather.Id):trace(veaf.lp(dcsShipType))
        ]]

    iAltitude = 20
    unitSystem = veafWeatherUnitSystem.Systems.FaaNavy
  else
    unitSystem = veafWeatherUnitSystem.defaultForTheatre()
  end

  local weatherData = veafWeatherData:create(veafAirbase.DcsAirbase:getPoint(), nil, iAltitude)

  local sMessage

  if veafAirbase.Category == Airbase.Category.SHIP then
    sMessage = string.format("%s information at %sZ", veafAirbase.DisplayName, veafTime.toStringTime(dateTimeZulu, false))
    local iCarrierCase = weatherData:getCarrierCase()
    if iCarrierCase then
      local sCaseString = nil
      if iCarrierCase == 1 then
        sCaseString = "I"
      elseif iCarrierCase == 2 then
        sCaseString = "II"
      elseif iCarrierCase == 3 then
        sCaseString = "III"
      end

      if not veaf.isNullOrEmpty(sCaseString) then
        sMessage = sMessage .. string.format("\nProbable CASE %s in effect", sCaseString)
      end
    end
  elseif veafAirbase.Category == Airbase.Category.HELIPAD then
    sMessage = string.format("%s information at %sZ", veafAirbase.DisplayName, veafTime.toStringTime(dateTimeZulu, false))
  else
    sMessage = string.format("%s information %s, recorded at %sZ", veafAirbase.Name, sLetter, veafTime.toStringTime(dateTimeZulu, false))
    local sRunwayInService = veafAirbase:getRunwayInServiceString(weatherData.WindDirection)
    if not veaf.isNullOrEmpty(sRunwayInService) then
      sMessage = sMessage .. string.format("\nRecommended runway %s", sRunwayInService)
    end
  end

  sMessage = sMessage .. "\n" .. weatherData:toStringAtis(unitSystem)
  --sMessage = sMessage .. "\n" .. weatherData:toStringExtended()

  local this = {
    AirbaseName = veafAirbase.Name,
    Letter = sLetter,
    DateTimeZulu = dateTimeZulu,
    Message = sMessage,
  }

  setmetatable(this, self)
  return this
end

---------------------------------------------------------------------------------------------------
---  Methods

---------------------------------------------------------------------------------------------------
---  Static methods
function veafWeatherAtis.getAtis(veafAirbase)
  local iAbsTime = timer.getAbsTime()
  local dateTime = veafTime.absTimeToDateTime(iAbsTime)
  local dateTimeZulu = veafTime.toZulu(dateTime)

  veaf.loggers
    .get(veafWeather.Id)
    :trace(string.format("Preparing ATIS for airbase %s at %sZ", veafAirbase.Name, veafTime.toStringTime(dateTimeZulu, false)))

  local atisInEffect = veafWeatherAtis.ListInEffect[veafAirbase.Name]
  if atisInEffect then
    veaf.loggers
      .get(veafWeather.Id)
      :trace(string.format("ATIS in effect: %s %s", atisInEffect.Letter, veafTime.toStringTime(atisInEffect.DateTimeZulu, false)))
    if
      dateTimeZulu.year > atisInEffect.DateTimeZulu.year
      or dateTimeZulu.month > atisInEffect.DateTimeZulu.month
      or dateTimeZulu.day > atisInEffect.DateTimeZulu.day
      or dateTimeZulu.hour > atisInEffect.DateTimeZulu.hour
    then
      -- if current date is in the next hour of more from the current one, declare new atis
      veaf.loggers.get(veafWeather.Id):trace(string.format("Current time %s: new ATIS", veafTime.toStringTime(dateTimeZulu, false)))
      atisInEffect = nil
    end
  end

  if atisInEffect == nil then
    atisInEffect = veafWeatherAtis:Create(veafAirbase, dateTimeZulu)
    if not atisInEffect then
      return nil
    end
    veaf.loggers.get(veafWeather.Id):trace(
      string.format(
        "New ATIS in effect for airbase %s: %s %s",
        veafAirbase.Name,
        atisInEffect.Letter,
        veafTime.toStringTime(atisInEffect.DateTimeZulu, false)
      )
    )
    veafWeatherAtis.ListInEffect[veafAirbase.Name] = atisInEffect
  end

  return atisInEffect
end

function veafWeatherAtis.getAtisString(veafAirbase)
  local atisInEffect = veafWeatherAtis.getAtis(veafAirbase)
  if not atisInEffect then
    return nil
  end
  return atisInEffect.Message
end

function veafWeatherAtis.getAtisStringFromVeafPoint(sPointName, iAbsTime)
  if veaf.isNullOrEmpty(sPointName) then
    veaf.loggers.get(veafWeather.Id):error("No point name")
    return "No point name"
  end

  local dcsAirbase = veaf.findDcsAirbase(sPointName)
  local veafAirbase = veafAirbases.getAirbaseFromDcsAirbase(dcsAirbase)

  if veafAirbase == nil then
    veaf.loggers.get(veafWeather.Id):error("Airbase not found for point " .. sPointName)
    return "Airbase not found for point " .. sPointName
  end

  veaf.loggers
    .get(veafWeather.Id)
    :trace("Airbase found from veaf point named %s: %s", veaf.lp(sPointName), veaf.lp(veaf.ifnn(dcsAirbase, "getName")))

  return veafWeatherAtis.getAtisString(veafAirbase)
end

function veafWeather.getWind(vec3, iAltitudeMeters, bTurbulence)
  if vec3 == nil then
    return 0, 0
  end
  bTurbulence = bTurbulence or false

  local vec3AtAltitude = { x = vec3.x, y = iAltitudeMeters, z = vec3.z }

  local vec3Wind
  if bTurbulence then
    vec3Wind = atmosphere.getWindWithTurbulence(vec3AtAltitude)
  else
    vec3Wind = atmosphere.getWind(vec3AtAltitude)
  end

  local iDirection = veaf.compute2dAzimuth(vec3Wind)

  -- convert direction from "to" to "from"
  if iDirection > 180 then
    iDirection = iDirection - 180
  else
    iDirection = iDirection + 180
  end

  -- round to integer degrees and wrap to [1, 360]
  iDirection = math.floor(iDirection + 0.5)
  if iDirection > 360 then
    iDirection = iDirection - 360
  end
  if iDirection <= 0 then
    iDirection = iDirection + 360
  end

  local iSpeed = veaf.compute2dMagnitude(vec3Wind)

  veaf.loggers.get(veafWeather.Id):trace(
    "Wind vec3 alt [ %d ]: [ z(east)=%f, x(north)=%f ] -- direction [ %d ], strength [ %f ]",
    iAltitudeMeters,
    vec3Wind.z,
    vec3Wind.x,
    iDirection,
    iSpeed
  )
  return iDirection, iSpeed
end

function veafWeather.messageWeatherAtClosestPoint(unitName, forUnit)
  veaf.loggers.get(veafWeather.Id):debug("veafWeather.messageWeatherAtClosestPoint(unitName=%s)", veaf.lp(unitName))
  local closestPoint = veafNamedPoints.getNearestPoint(unitName)
  if closestPoint then
    local BR = veafNamedPoints.getPointBearing({ closestPoint.name, unitName })
    if BR then
      BR = " (" .. BR .. ")"
    else
      BR = ""
    end
    local weatherReport = "WEATHER        : " .. closestPoint.name .. BR .. "\n\n"
    weatherReport = weatherReport .. veafWeatherData.getWeatherString(closestPoint, unitName)
    if forUnit then
      veaf.outTextForUnit(unitName, weatherReport, 30)
    else
      veaf.outTextForGroup(unitName, weatherReport, 30)
    end
  end
end

function veafWeather.messageAtcClosestAirbase(unitName, forUnit)
  -- The name comes from an F10 menu entry, and a pilot can be dead, slotted out or respawned between
  -- opening the menu and choosing the item. The lookup was unchecked, and `getNearestAirbase` calls
  -- `dcsUnit:getPoint()` on the spot -- so a unit that had just gone took the ATC report down. There is
  -- nobody left to answer, so this simply stops.
  local dcsUnit = Unit.getByName(unitName)
  if not dcsUnit then
    veaf.loggers.get(veafWeather.Id):warn(string.format("messageAtcClosestAirbase: unit [%s] is gone ; no ATC report", veaf.p(unitName)))
    return
  end
  local veafAirbase = veafAirbases.getNearestAirbase(dcsUnit)
  if veafAirbase then
    -- getAtisString returns nil when the airbase's DCS object is gone — the guard that fixed issue
    -- #302 upstream of here. Passing that nil on would raise inside trigger.action.outTextForUnit,
    -- which is the same crash one level later, so the pilot gets a sentence instead. The idea is
    -- MacFlorent's, from PR #303; the translation is ours (his version hardcoded English).
    local sAtcReport = veafWeatherAtis.getAtisString(veafAirbase) or veaf.t("weather.atis_unavailable", veafAirbase.Name)
    if forUnit then
      veaf.outTextForUnit(dcsUnit:getName(), sAtcReport, 30)
    else
      veaf.outTextForGroup(dcsUnit:getName(), sAtcReport, 30)
    end
  end
end

function veafWeather.messageAtcAndWeather(unitName, forUnit)
  veafWeather.messageAtcClosestAirbase(unitName, forUnit)
  veafWeather.messageWeatherAtClosestPoint(unitName, forUnit)
end

----------------------------------------------------------------------------------------------------
--- WEATHER modifications during runtime

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafFog class methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

VeafFog = {}
VeafFog.DELAY_BETWEEN_DYNAMIC_CHECKS = 5 * 60
VeafFog.DYNAMICFOG_BASEFACTOR_HEAVY = 0.8
VeafFog.DYNAMICFOG_BASEFACTOR_MEDIUM = 0.5
VeafFog.DYNAMICFOG_BASEFACTOR_SPARSE = 0.2

function VeafFog.init(object)
  -- technical name
  object.name = nil
  -- scheduled function that is used to update the object
  object.dynamicCheckFunctionScheduled = nil
  -- if true, the object is enabled and the fog settings (static and/or dynamic) are applied
  object.enabled = false
  -- the dynamic fog parameters for this object
  object.fogAnimationData = {}
  -- the static fog parameters for this object
  object.fogStaticData = { visibility = 10000, thickness = 150 }
  -- the static fog parameters saved by this object (stored state before it changes them)
  object.savedFogStaticData = nil
  -- if set to a base fog factor (between 0 and 1), the fog will be dynamically computed based on latitude, season and time of day
  object.dynamicFogBaseFactor = nil
  -- if true, the dynamic fog system will animate the transitions
  object.dynamicFogIsAnimated = true
end

function VeafFog:new(objectToCopy)
  veaf.loggers.get(veafWeather.Id):debug("VeafFog:new()")
  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self

  -- init the new object
  VeafFog.init(objectToCreate)

  return objectToCreate
end

function VeafFog:activate()
  veaf.loggers.get(veafWeather.Id):debug("VeafFog[%s]:activate()", veaf.lp(self.name))
  veafWeather.setAndActivateFog(self)
end

function VeafFog:enable()
  veaf.loggers.get(veafWeather.Id):debug("VeafFog[%s]:enable()", veaf.lp(self.name))

  self.enabled = true

  -- store the existing fog parameters
  veaf.loggers.get(veafWeather.Id):trace("store the existing fog parameters")
  veaf.loggers.get(veafWeather.Id):trace("world.weather.getFogVisibilityDistance()=[%s]", veaf.lp(world.weather.getFogVisibilityDistance()))
  veaf.loggers.get(veafWeather.Id):trace("world.weather.getFogThickness()=[%s]", veaf.lp(world.weather.getFogThickness()))
  self.fogSavedStaticData = { visibility = world.weather.getFogVisibilityDistance(), thickness = world.weather.getFogThickness() }

  -- set the fog to the programmed parameters
  veaf.loggers.get(veafWeather.Id):trace("set the fog to the programmed parameters")
  if self.forAnimationData then
    veaf.loggers.get(veafWeather.Id):trace("self.forAnimationData=[%s]", veaf.lp(self.forAnimationData))
    -- create an animation
    local animation = {
      self.forAnimationData,
    }
    -- first reset fog animation
    veaf.loggers.get(veafWeather.Id):trace("first reset fog animation")
    world.weather.setFogAnimation({})
    veaf.loggers.get(veafWeather.Id):trace("store the existing fog parameters")
    veaf.loggers
      .get(veafWeather.Id)
      :trace("world.weather.getFogVisibilityDistance()=[%s]", veaf.lp(world.weather.getFogVisibilityDistance()))
    veaf.loggers.get(veafWeather.Id):trace("world.weather.getFogThickness()=[%s]", veaf.lp(world.weather.getFogThickness()))
    -- set the new fog animation
    world.weather.setFogAnimation(animation)
  elseif self.fogStaticData then
    veaf.loggers.get(veafWeather.Id):trace("self.fogStaticData=[%s]", veaf.lp(self.fogStaticData))
    world.weather.setFogThickness(self.fogStaticData.thickness)
    world.weather.setFogVisibilityDistance(self.fogStaticData.visibility)
  end

  -- do the first check, the method will reschedule itself
  veaf.loggers.get(veafWeather.Id):trace("do the first check, the method will reschedule itself")
  self:dynamicCheck()

  return self
end

function VeafFog:disable(dontRestore)
  veaf.loggers.get(veafWeather.Id):debug("VeafFog[%s]:disable()", veaf.lp(self.name))

  -- disable the scheduler
  if self.dynamicCheckFunctionScheduled then
    veaf.loggers.get(veafWeather.Id):trace("disable the scheduler")
    veaf.removeFunction(self.dynamicCheckFunctionScheduled)
    self.dynamicCheckFunctionScheduled = nil
  end

  self.enabled = false

  if not dontRestore then
    -- reset to the fog values stored at start
    veaf.loggers.get(veafWeather.Id):trace("reset to the fog values stored at start")
    if self.fogSavedStaticData then
      world.weather.setFogThickness(self.fogSavedStaticData.thickness)
      world.weather.setFogVisibilityDistance(self.fogSavedStaticData.visibility)
    end
  end

  return self
end

function VeafFog:dynamicCheck()
  veaf.loggers.get(veafWeather.Id):debug("VeafFog[%s]:dynamicCheck()", veaf.lp(self.name))
  if self.dynamicFogBaseFactor then
    local position = { x = 0, y = 0, z = 0 } -- somewhere in the map ^^

    -- compute the fog that should be set at this moment in time
    local date = veafTime.getMissionDateTime()
    veaf.loggers.get(veafWeather.Id):trace("date=[%s]", veaf.lp(date))

    -- Seasonal adjustment based on latitude and time of year
    local latitude, _, _ = coord.LOtoLL(position)
    veaf.loggers.get(veafWeather.Id):trace("latitude=[%s]", veaf.lp(latitude))
    local month = date.month
    local seasonal_peaks = { [3] = 0.8, [4] = 0.9, [5] = 0.7, [9] = 0.8, [10] = 0.9, [11] = 0.7 }
    local season_factor = seasonal_peaks[month] or 0.5

    -- Temperature-dew point difference
    local weatherData = veafWeatherData:create(position)
    local temp_diff = math.abs(weatherData.TemperatureCelcius - weatherData.DewPointCelcius)

    -- Diurnal adjustment based on hour
    local diurnal_factor = 0

    -- Convert sunrise and sunset times to minutes since midnight
    local sunrise_time = weatherData.SunriseLocal.hour * 60 + weatherData.SunriseLocal.min
    local sunset_time = weatherData.SunsetLocal.hour * 60 + weatherData.SunsetLocal.min

    -- Calculate daylight duration
    local daylight_duration = sunset_time - sunrise_time

    -- Morning is from sunrise and lasts 25% of daylight
    local morningEnd_time = sunrise_time + 0.25 * daylight_duration
    local morningPeak_time = sunrise_time + 0.125 * daylight_duration
    -- Evening start is 25% before sunset
    local eveningStart_time = sunset_time - 0.25 * daylight_duration
    local eveningPeak_time = sunset_time - 0.125 * daylight_duration

    -- Convert current time to minutes since midnight
    local current_time = date.hour * 60 + date.min

    veaf.loggers
      .get(veafWeather.Id)
      :trace("sunrise_time=[%s:%s]", veaf.lp(math.floor(sunrise_time / 60)), veaf.lp(math.fmod(sunrise_time, 60)))
    veaf.loggers
      .get(veafWeather.Id)
      :trace("morningPeak_time=[%s:%s]", veaf.lp(math.floor(morningPeak_time / 60)), veaf.lp(math.fmod(morningPeak_time, 60)))
    veaf.loggers
      .get(veafWeather.Id)
      :trace("morningEnd_time=[%s:%s]", veaf.lp(math.floor(morningEnd_time / 60)), veaf.lp(math.fmod(morningEnd_time, 60)))
    veaf.loggers
      .get(veafWeather.Id)
      :trace("eveningStart_time=[%s:%s]", veaf.lp(math.floor(eveningStart_time / 60)), veaf.lp(math.fmod(eveningStart_time, 60)))
    veaf.loggers
      .get(veafWeather.Id)
      :trace("eveningPeak_time=[%s:%s]", veaf.lp(math.floor(eveningPeak_time / 60)), veaf.lp(math.fmod(eveningPeak_time, 60)))
    veaf.loggers
      .get(veafWeather.Id)
      :trace("sunset_time=[%s:%s]", veaf.lp(math.floor(sunset_time / 60)), veaf.lp(math.fmod(sunset_time, 60)))
    veaf.loggers.get(veafWeather.Id):trace("daylight_duration=[%s]", veaf.lp(daylight_duration))
    veaf.loggers
      .get(veafWeather.Id)
      :trace("current_time=[%s:%s]", veaf.lp(math.floor(current_time / 60)), veaf.lp(math.fmod(current_time, 60)))

    if current_time >= sunrise_time and current_time < morningPeak_time then
      -- Phase 1: From sunrise to middle of the morning (raise)
      veaf.loggers.get(veafWeather.Id):trace("Phase 1: From sunrise to middle of the morning (raise)")
      diurnal_factor = (current_time - sunrise_time) / (morningPeak_time - sunrise_time)
    elseif current_time >= morningPeak_time and current_time < morningEnd_time then
      -- Phase 2: From middle of the morning to end of the morning (decrease)
      veaf.loggers.get(veafWeather.Id):trace("Phase 2: From middle of the morning to end of the morning (decrease)")
      diurnal_factor = 1 - (current_time - morningPeak_time) / (morningEnd_time - morningPeak_time)
    elseif current_time >= morningEnd_time and current_time < eveningStart_time then
      -- Phase 3: Day phase (constant base value)
      veaf.loggers.get(veafWeather.Id):trace("Phase 3: Day phase (constant base value)")
      diurnal_factor = 0.1
    elseif current_time >= eveningStart_time and current_time < eveningPeak_time then
      -- Phase 4: From start of the evening to middle of the evening (raise)
      veaf.loggers.get(veafWeather.Id):trace("Phase 4: From start of the evening to middle of the evening (raise)")
      diurnal_factor = (current_time - eveningStart_time) / (eveningPeak_time - eveningStart_time)
    elseif current_time >= eveningStart_time and current_time < sunset_time then
      -- Phase 5: From middle of the evening to sunset (decrease)
      veaf.loggers.get(veafWeather.Id):trace("Phase 5: From middle of the evening to sunset (decrease)")
      diurnal_factor = 1 - (current_time - eveningPeak_time) / (sunset_time - eveningPeak_time)
    end

    -- Base fog probability calculation
    local base_prob = math.max(0, math.min(1, 1 - (temp_diff / 10) - (weatherData.WindSpeedMps / 10)))
    local fog_probability = base_prob * season_factor * diurnal_factor
    veaf.loggers.get(veafWeather.Id):trace("weatherData.WindSpeedMps=[%s]", veaf.lp(weatherData.WindSpeedMps))
    veaf.loggers.get(veafWeather.Id):trace("temp_diff=[%s]", veaf.lp(temp_diff))
    veaf.loggers.get(veafWeather.Id):trace("base_prob=[%s]", veaf.lp(base_prob))
    veaf.loggers.get(veafWeather.Id):trace("season_factor=[%s]", veaf.lp(season_factor))
    veaf.loggers.get(veafWeather.Id):trace("diurnal_factor=[%s]", veaf.lp(diurnal_factor))
    veaf.loggers.get(veafWeather.Id):trace("fog_probability=[%s]", veaf.lp(fog_probability))

    -- Compute visibility and thickness based on fog_probability with smooth transitions
    local visibility, thickness
    if fog_probability < 0.2 then
      visibility = 50000 * (1 - fog_probability) -- High visibility as fog_probability decreases
      thickness = 0 -- No fog, so no thickness
    else
      -- Normalize the fog factor relative to the 0.2-1.0 range
      local normalizedFactor = (fog_probability - 0.2) / 0.8

      local minVisibility = 100 * (1 - self.dynamicFogBaseFactor)
      local maxVisibility = 5000 * (1 - self.dynamicFogBaseFactor)
      local minThickness = 100 * self.dynamicFogBaseFactor
      local maxThickness = 500 * self.dynamicFogBaseFactor
      veaf.loggers.get(veafWeather.Id):trace("minVisibility=[%s]", veaf.lp(minVisibility))
      veaf.loggers.get(veafWeather.Id):trace("maxVisibility=[%s]", veaf.lp(maxVisibility))
      veaf.loggers.get(veafWeather.Id):trace("minThickness=[%s]", veaf.lp(minThickness))
      veaf.loggers.get(veafWeather.Id):trace("maxThickness=[%s]", veaf.lp(maxThickness))

      -- Calculate visibility (decreasing from 5000 to 100)
      visibility = maxVisibility - ((maxVisibility - minVisibility) * normalizedFactor)

      -- Calculate thickness (increasing from 100 to 1000)
      thickness = minThickness + ((maxThickness - minThickness) * normalizedFactor)
    end

    visibility = math.floor(visibility)
    thickness = math.floor(thickness)
    veaf.loggers.get(veafWeather.Id):trace("thickness=[%s]", veaf.lp(thickness))
    veaf.loggers.get(veafWeather.Id):trace("visibility=[%s]", veaf.lp(visibility))

    if self.dynamicFogIsAnimated then
      -- create an animation
      veaf.loggers.get(veafWeather.Id):trace("thickness=[%s]", veaf.lp(thickness))
      local animation = {
        VeafFog.DELAY_BETWEEN_DYNAMIC_CHECKS - VeafFog.DELAY_BETWEEN_DYNAMIC_CHECKS * 0.1,
        visibility,
        thickness,
      }
      veaf.loggers.get(veafWeather.Id):trace("animation=[%s]", veaf.lp(animation))

      -- first reset fog animation
      world.weather.setFogAnimation({})
      -- set the new fog animation
      world.weather.setFogAnimation(animation)
    else
      world.weather.setFogThickness(thickness)
      world.weather.setFogVisibilityDistance(visibility)
    end
  end

  -- reschedule
  self.dynamicCheckFunctionScheduled =
    veaf.scheduleFunction(VeafFog.dynamicCheck, { self }, timer.getTime() + VeafFog.DELAY_BETWEEN_DYNAMIC_CHECKS)
end

function veafWeather.createStaticFog(name, thickness, visibility)
  local fog = VeafFog:new()
  fog.name = name
  fog.fogStaticData = { thickness = thickness, visibility = visibility }
  return fog
end

function veafWeather.createDynamicFog(name, baseFactor, notAnimated)
  local fog = VeafFog:new()
  fog.name = name
  fog.dynamicFogBaseFactor = baseFactor
  fog.dynamicFogIsAnimated = not notAnimated
  return fog
end

function veafWeather.createAnimatedFog(name, minutes, thickness, visibility)
  local fog = VeafFog:new()
  fog.name = name
  fog.forAnimationData = { minutes * 60, visibility, thickness }
  return fog
end

function veafWeather.setAndActivateFog(fogObject)
  veaf.loggers.get(veafWeather.Id):trace("fogObject=[%s]", veaf.lp(fogObject))

  -- disable the existing fog object if any
  if veafWeather.existingFog ~= nil then
    veaf.loggers.get(veafWeather.Id):trace("disable the existing fog object if any")
    veaf.loggers.get(veafWeather.Id):trace("veafWeather.existingFog=[%s]", veaf.lp(veafWeather.existingFog))
    veafWeather.existingFog:disable(true)
  end

  -- activate the new fog object
  veaf.loggers.get(veafWeather.Id):trace("activate the new fog object")
  veafWeather.existingFog = fogObject
  fogObject:enable()

  trigger.action.outText(veaf.t("weather.fog_set", fogObject.name), 5)

  return fogObject
end

-- dynamically managed fog instances
veafWeather.FOG_DYNAMIC_HEAVY = veafWeather.createDynamicFog("Dynamic HEAVY fog", VeafFog.DYNAMICFOG_BASEFACTOR_HEAVY)
veafWeather.FOG_DYNAMIC_MEDIUM = veafWeather.createDynamicFog("Dynamic MEDIUM fog", VeafFog.DYNAMICFOG_BASEFACTOR_MEDIUM)
veafWeather.FOG_DYNAMIC_SPARSE = veafWeather.createDynamicFog("Dynamic SPARSE fog", VeafFog.DYNAMICFOG_BASEFACTOR_SPARSE)

-- static fog instances
veafWeather.FOG_STATIC_HEAVY = veafWeather.createStaticFog("Static HEAVY fog", 500, 100)
veafWeather.FOG_STATIC_MEDIUM = veafWeather.createStaticFog("Static MEDIUM fog", 500, 500)
veafWeather.FOG_STATIC_MEDIUM_LOW = veafWeather.createStaticFog("Static MEDIUM LOW fog", 100, 500)
veafWeather.FOG_STATIC_SPARSE = veafWeather.createStaticFog("Static SPARSE fog", 500, 5000)
veafWeather.FOG_STATIC_SPARSE_LOW = veafWeather.createStaticFog("Static SPARSE LOW fog", 100, 5000)
veafWeather.FOG_STATIC_NO = veafWeather.createStaticFog("Static NO fog", 0, 0)

-- animated fog instances
for _, minutes in pairs({ 1, 5, 10, 15, 30, 60, 90 }) do
  local overMinutesText = string.format(" over %d minutes", minutes)
  veafWeather["FOG_ANIMATED_" .. minutes .. "M_HEAVY"] =
    veafWeather.createAnimatedFog("Animated HEAVY fog" .. overMinutesText, minutes, 500, 100)
  veafWeather["FOG_ANIMATED_" .. minutes .. "M_MEDIUM"] =
    veafWeather.createAnimatedFog("Animated MEDIUM fog" .. overMinutesText, minutes, 500, 500)
  veafWeather["FOG_ANIMATED_" .. minutes .. "M_MEDIUM_LOW"] =
    veafWeather.createAnimatedFog("Animated MEDIUM LOW fog" .. overMinutesText, minutes, 100, 500)
  veafWeather["FOG_ANIMATED_" .. minutes .. "M_SPARSE"] =
    veafWeather.createAnimatedFog("Animated SPARSE fog" .. overMinutesText, minutes, 500, 5000)
  veafWeather["FOG_ANIMATED_" .. minutes .. "M_SPARSE_LOW"] =
    veafWeather.createAnimatedFog("Animated SPARSE LOW fog" .. overMinutesText, minutes, 100, 5000)
  veafWeather["FOG_ANIMATED_" .. minutes .. "M_NO"] = veafWeather.createAnimatedFog("Animated NO fog" .. overMinutesText, minutes, 0, 0)
end

---------------------------------------------------------------------------------------------------
---  Radio menu and remote interface
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafWeather.buildRadioMenu()
  veaf.loggers.get(veafWeather.Id):debug("buildRadioMenu()")

  veafWeather.rootPath = veafRadio.addMenu(veaf.t(veafWeather.RadioMenuName))
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.weather.closest_point"),
    veafWeather.rootPath,
    veafWeather.messageWeatherAtClosestPoint,
    nil,
    veafRadio.USAGE_ForGroup
  )
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.weather.closest_atc"),
    veafWeather.rootPath,
    veafWeather.messageAtcClosestAirbase,
    nil,
    veafRadio.USAGE_ForGroup
  )
  veafRadio.addCommandToSubmenu(
    veaf.t("menu.weather.atc_and_weather"),
    veafWeather.rootPath,
    veafWeather.messageAtcAndWeather,
    nil,
    veafRadio.USAGE_ForGroup
  )

  local fogPath = veafRadio.addSubMenu(veaf.t("menu.weather.fog_settings"), veafWeather.rootPath)

  local dynamicFogPath = veafRadio.addSubMenu(veaf.t("menu.weather.fog_dynamic"), fogPath)
  veafRadio.addSecuredCommandToSubmenu(
    veafWeather.FOG_DYNAMIC_HEAVY.name,
    dynamicFogPath,
    veafWeather.setAndActivateFog,
    veafWeather.FOG_DYNAMIC_HEAVY,
    veafRadio.USAGE_ForAll
  )
  veafRadio.addSecuredCommandToSubmenu(
    veafWeather.FOG_DYNAMIC_MEDIUM.name,
    dynamicFogPath,
    veafWeather.setAndActivateFog,
    veafWeather.FOG_DYNAMIC_MEDIUM,
    veafRadio.USAGE_ForAll
  )
  veafRadio.addSecuredCommandToSubmenu(
    veafWeather.FOG_DYNAMIC_SPARSE.name,
    dynamicFogPath,
    veafWeather.setAndActivateFog,
    veafWeather.FOG_DYNAMIC_SPARSE,
    veafRadio.USAGE_ForAll
  )

  local animatedFogPath = veafRadio.addSubMenu(veaf.t("menu.weather.fog_animated"), fogPath)
  for _, minutes in pairs({ 1, 5, 10, 15, 30, 60, 90 }) do
    local overMinutesText = string.format(" over %d minutes", minutes)
    local _path = veafRadio.addSubMenu(veaf.t("menu.weather.fog_animated_over", minutes), animatedFogPath)
    veafRadio.addSecuredCommandToSubmenu(
      veafWeather["FOG_ANIMATED_" .. minutes .. "M_HEAVY"].name,
      _path,
      veafWeather.setAndActivateFog,
      veafWeather["FOG_ANIMATED_" .. minutes .. "M_HEAVY"],
      veafRadio.USAGE_ForAll
    )
    veafRadio.addSecuredCommandToSubmenu(
      veafWeather["FOG_ANIMATED_" .. minutes .. "M_MEDIUM"].name,
      _path,
      veafWeather.setAndActivateFog,
      veafWeather["FOG_ANIMATED_" .. minutes .. "M_MEDIUM"],
      veafRadio.USAGE_ForAll
    )
    veafRadio.addSecuredCommandToSubmenu(
      veafWeather["FOG_ANIMATED_" .. minutes .. "M_MEDIUM_LOW"].name,
      _path,
      veafWeather.setAndActivateFog,
      veafWeather["FOG_ANIMATED_" .. minutes .. "M_MEDIUM_LOW"],
      veafRadio.USAGE_ForAll
    )
    veafRadio.addSecuredCommandToSubmenu(
      veafWeather["FOG_ANIMATED_" .. minutes .. "M_SPARSE"].name,
      _path,
      veafWeather.setAndActivateFog,
      veafWeather["FOG_ANIMATED_" .. minutes .. "M_SPARSE"],
      veafRadio.USAGE_ForAll
    )
    veafRadio.addSecuredCommandToSubmenu(
      veafWeather["FOG_ANIMATED_" .. minutes .. "M_SPARSE_LOW"].name,
      _path,
      veafWeather.setAndActivateFog,
      veafWeather["FOG_ANIMATED_" .. minutes .. "M_SPARSE_LOW"],
      veafRadio.USAGE_ForAll
    )
    veafRadio.addSecuredCommandToSubmenu(
      veafWeather["FOG_ANIMATED_" .. minutes .. "M_NO"].name,
      _path,
      veafWeather.setAndActivateFog,
      veafWeather["FOG_ANIMATED_" .. minutes .. "M_NO"],
      veafRadio.USAGE_ForAll
    )
  end

  local staticFogPath = veafRadio.addSubMenu(veaf.t("menu.weather.fog_static"), fogPath)
  veafRadio.addSecuredCommandToSubmenu(
    veafWeather.FOG_STATIC_HEAVY.name,
    staticFogPath,
    veafWeather.setAndActivateFog,
    veafWeather.FOG_STATIC_HEAVY,
    veafRadio.USAGE_ForAll
  )
  veafRadio.addSecuredCommandToSubmenu(
    veafWeather.FOG_STATIC_MEDIUM.name,
    staticFogPath,
    veafWeather.setAndActivateFog,
    veafWeather.FOG_STATIC_MEDIUM,
    veafRadio.USAGE_ForAll
  )
  veafRadio.addSecuredCommandToSubmenu(
    veafWeather.FOG_STATIC_MEDIUM_LOW.name,
    staticFogPath,
    veafWeather.setAndActivateFog,
    veafWeather.FOG_STATIC_MEDIUM_LOW,
    veafRadio.USAGE_ForAll
  )
  veafRadio.addSecuredCommandToSubmenu(
    veafWeather.FOG_STATIC_SPARSE.name,
    staticFogPath,
    veafWeather.setAndActivateFog,
    veafWeather.FOG_STATIC_SPARSE,
    veafRadio.USAGE_ForAll
  )
  veafRadio.addSecuredCommandToSubmenu(
    veafWeather.FOG_STATIC_SPARSE_LOW.name,
    staticFogPath,
    veafWeather.setAndActivateFog,
    veafWeather.FOG_STATIC_SPARSE_LOW,
    veafRadio.USAGE_ForAll
  )
  veafRadio.addSecuredCommandToSubmenu(
    veafWeather.FOG_STATIC_NO.name,
    staticFogPath,
    veafWeather.setAndActivateFog,
    veafWeather.FOG_STATIC_NO,
    veafRadio.USAGE_ForAll
  )
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- remote interface
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- execute command from the remote interface
function veafWeather.executeCommandFromRemote(parameters)
  veaf.loggers.get(veafWeather.Id):debug(string.format("veafWeather.executeCommandFromRemote()"))
  veaf.loggers.get(veafWeather.Id):trace(string.format("parameters= %s", veaf.p(parameters)))
  local _pilot, _pilotName, _unitName, _command = unpack(parameters)
  veaf.loggers.get(veafWeather.Id):trace(string.format("_pilot= %s", veaf.p(_pilot)))
  veaf.loggers.get(veafWeather.Id):trace(string.format("_pilotName= %s", veaf.p(_pilotName)))
  veaf.loggers.get(veafWeather.Id):trace(string.format("_unitName= %s", veaf.p(_unitName)))
  veaf.loggers.get(veafWeather.Id):trace(string.format("_command= %s", veaf.p(_command)))
  if not _pilot or not _command then
    return false
  end

  if _command then
    -- parse the command
    local _action, _name, _parameters = _command:match(veafWeather.RemoteCommandParser)
    veaf.loggers.get(veafWeather.Id):trace(string.format("_action=%s", veaf.p(_action)))
    veaf.loggers.get(veafWeather.Id):trace(string.format("_name=%s", veaf.p(_name)))
    veaf.loggers.get(veafWeather.Id):trace(string.format("_parameters=%s", veaf.p(_parameters)))
    if _action and _action:lower() == "weather" then
      veaf.loggers.get(veafWeather.Id):info(string.format("[%s] is requesting weather", veaf.p(_pilotName)))
      veafWeather.messageWeatherAtClosestPoint(_unitName, true)
      return true
    elseif _action and _action:lower() == "atc" then
      veaf.loggers.get(veafWeather.Id):info(string.format("[%s] is requesting atc", veaf.p(_pilotName)))
      veafWeather.messageAtcClosestAirbase(_unitName, true)
      return true
    elseif not _action or _action:lower() == "all" then
      veaf.loggers.get(veafWeather.Id):info(string.format("[%s] is requesting both atc and weather", veaf.p(_pilotName)))
      veafWeather.messageAtcAndWeather(_unitName, true)
      return true
    elseif _action and _action:lower() == "fog" then
      if _name then
        local uName = _name:upper()
        -- Indexing veafWeather with a player-supplied key is only safe today because :upper()
        -- narrows it to the all-caps keys, and every one of those is a FOG_* preset (SECREV-2 /
        -- VMR-042 -- reported as a missing whitelist, and not exploitable as reported). Checking for
        -- the contract setAndActivateFog is about to use keeps it that way: the first all-caps
        -- constant that is not a fog object would otherwise turn this command into a Lua error.
        local fogObject = veafWeather[uName]
        if type(fogObject) == "table" and fogObject.enable then
          veaf.loggers.get(veafWeather.Id):info(string.format("[%s] is requesting fog [%s]", veaf.p(_pilotName), veaf.p(uName)))
          veafWeather.setAndActivateFog(fogObject)
          return true
        end
      end
    end
  end
  return false
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  MAIN MODULE INITIALIZATION
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
--- Welcome brief — FEAT-SLOT-WELCOME-BRIEF (#301)
---------------------------------------------------------------------------------------------------

--- Seconds between taking the slot and the brief.
---
--- Not zero: a pilot entering a unit is still loading his cockpit, and a message shown at that instant
--- is one he never reads. Tripack's reference behaviour shows it a few seconds in, which is what this
--- matches.
veafWeather.WELCOME_BRIEF_DELAY_SECONDS = 5

--- How long the brief stays on screen.
veafWeather.WELCOME_BRIEF_DURATION_SECONDS = 20

--- The current course of a ship acting as an airbase, in degrees, or nil.
---
--- A carrier has no runway in service because it does not keep one: it turns into the wind, so the useful
--- number for a pilot taking a deck slot is the ship's heading. `Airbase:getUnit(1)` is how the vessel is
--- reached, since for a DCS ship the airbase *is* the vessel.
---
--- @param veafAirbaseShip table the VEAF airbase wrapper, category SHIP
--- @return number|nil the heading in degrees, rounded
function veafWeather.getShipCourse(veafAirbaseShip)
  local dcsAirbase = veafAirbaseShip and veafAirbaseShip.DcsAirbase
  if not dcsAirbase or not dcsAirbase.getUnit then
    return nil
  end
  local ok, dcsUnit = pcall(function()
    return dcsAirbase:getUnit(1)
  end)
  if not ok or not dcsUnit then
    return nil
  end
  local okHeading, heading = pcall(function()
    return veaf.round(math.deg(veaf.getHeading(dcsUnit, true)), 0)
  end)
  if not okHeading or not heading then
    return nil
  end
  return heading
end

--- Build the welcome brief for a unit, or nil when there is nothing useful to say.
---
--- Deliberately shorter than the ATIS: a pilot who wants the full report has it in the radio menu, and a
--- greeting that fills the screen on every slot change stops being read. Wind, a one-line weather
--- summary, and the runway in service.
---
--- **Which airbase.** The nearest one, which for a pilot sitting at parking *is* the one he is on. The
--- PRD asked for "the one the slot sits on, not the nearest in a straight line", and the authoritative
--- answer would be the departure airdrome the mission declares on the group's first route point — but
--- whether `veaf.getGroupRoute` carries `airdromeId` cannot be established without a running DCS, and
--- guessing it would be worse than using the tested helper. The residual case is a slot at one airfield
--- marginally closer to another's centre; recorded in the PRD rather than papered over.
---
--- @param dcsUnit table the unit the player just took
--- @return string|nil the brief, or nil when no airbase is near enough to talk about
function veafWeather.buildWelcomeBrief(dcsUnit)
  if not dcsUnit or not dcsUnit.getPoint then
    return nil
  end

  local veafAirbaseNear = veafAirbases.getNearestAirbase(dcsUnit)
  if not veafAirbaseNear or not veafAirbaseNear.DcsAirbase then
    return nil
  end

  local weatherData = veafWeatherData:create(veafAirbaseNear.DcsAirbase:getPoint(), nil, nil)
  if not weatherData then
    return nil
  end

  local sName = veafAirbaseNear.DisplayName or veafAirbaseNear.Name
  local unitSystem = veafWeatherUnitSystem.defaultForTheatre()
  local sWeather = weatherData:toStringAtis(unitSystem)

  -- A carrier has no runway in service because it does not keep one — it turns into the wind, so its
  -- course is the number a pilot on the deck needs. Asking it for a runway would log a "none identified"
  -- for every deck slot taken and tell him nothing.
  if veafAirbaseNear.Category == Airbase.Category.SHIP then
    local iCourse = veafWeather.getShipCourse(veafAirbaseNear)
    if iCourse then
      return veaf.t("weather.welcome_brief_ship", sName, iCourse, sWeather)
    end
    return veaf.t("weather.welcome_brief_no_runway", sName, sWeather)
  end

  -- A helipad has neither: no runway to align with and no course to steer.
  if veafAirbaseNear.Category == Airbase.Category.HELIPAD then
    return veaf.t("weather.welcome_brief_no_runway", sName, sWeather)
  end

  local sRunway = veafAirbaseNear:getRunwayInServiceString(weatherData.WindDirection)
  if veaf.isNullOrEmpty(sRunway) then
    return veaf.t("weather.welcome_brief_no_runway", sName, sWeather)
  end
  return veaf.t("weather.welcome_brief", sName, sRunway, sWeather)
end

--- Show the brief to the player who just took a slot.
---
--- Sent to the unit rather than the coalition: it is about *his* airfield, and the same greeting
--- broadcast to everyone flying would be noise the moment two pilots take slots at different bases.
function veafWeather.sendWelcomeBrief(dcsUnitName)
  local dcsUnit = Unit.getByName(dcsUnitName)
  if not dcsUnit or not dcsUnit:isExist() then
    -- He left the slot during the delay, which is ordinary rather than exceptional.
    return
  end
  local sBrief = veafWeather.buildWelcomeBrief(dcsUnit)
  if veaf.isNullOrEmpty(sBrief) then
    return
  end
  local dcsGroup = dcsUnit:getGroup()
  if not dcsGroup then
    return
  end
  trigger.action.outTextForGroup(dcsGroup:getID(), sBrief, veafWeather.WELCOME_BRIEF_DURATION_SECONDS)
end

--- Event callback: a player took a slot.
---
--- Shown on **every** slot entry rather than once per session. A pilot who changes airfield wants the new
--- airfield's runway, and "once per session" would silently withhold exactly the case where the
--- information changed. It costs one message per slot change, which is what the reference behaviour does.
--- A human took a slot.
---
--- Subscribed to BOTH `S_EVENT_BIRTH` and `S_EVENT_PLAYER_ENTER_UNIT`, and that is not belt-and-braces:
--- `S_EVENT_PLAYER_ENTER_UNIT` alone does **not** fire when a single-player pilot occupies his starting
--- slot — DCS raises a birth event for him instead. Subscribing to it alone is why this brief said nothing
--- at all in game (found 2026-08-24 on a demo mission, reported as "rien sur un aérodrome ni sur le
--- Stennis"). `veafGrass.onBirth` and `veafQraManager.eventHandler` both take both events for exactly this
--- reason, with the same human test; this now follows them rather than inventing a third answer.
---
--- The human test is what keeps a birth event from briefing every AI aircraft that spawns.
function veafWeather.onPlayerEnterUnit(event)
  if not veafWeather.welcomeBriefEnabled then
    return
  end
  -- The event's initiator is the data table veafEventHandler builds, not a DCS object: it carries
  -- `unitName` and no methods. Reading `getName` alone matched only dynamic-slot units, so on every
  -- ordinary slot this returned here — silently, before the log line below.
  local sUnitName = veafEventHandler.unitNameFromEvent(event)
  if not sUnitName then
    return
  end
  local bIsHuman = veaf.mist.isHumanUnit(sUnitName) or (event.type and event.type.id == world.event.S_EVENT_PLAYER_ENTER_UNIT)
  if not bIsHuman then
    return
  end
  -- One brief per slot: both events can arrive for the same pilot, and a pilot who is told the runway
  -- twice five seconds apart will assume something is broken.
  veafWeather.briefedUnits = veafWeather.briefedUnits or {}
  if veafWeather.briefedUnits[sUnitName] then
    return
  end
  veafWeather.briefedUnits[sUnitName] = true
  -- INFO rather than DEBUG on purpose: when this feature is silent in game, the first question is whether
  -- it was ever asked to speak, and a debug line cannot answer it from a default log.
  veaf.loggers.get(veafWeather.Id):info("welcome brief scheduled for [%s]", veaf.p(sUnitName))
  -- Scheduled by name, not by unit: the unit object may be stale by the time the timer fires.
  veaf.scheduleFunction(veafWeather.sendWelcomeBrief, { sUnitName }, timer.getTime() + veafWeather.WELCOME_BRIEF_DELAY_SECONDS)
end

--- Brief every human slot that is already occupied.
---
--- Runs once, shortly after the module initializes. The player roster lists the human *slots* a
--- mission declares; a slot is only worth briefing when a player is actually sitting in it, which is what
--- `getPlayerName()` answers.
function veafWeather.briefEveryoneAlreadyFlying()
  if not veafWeather.welcomeBriefEnabled then
    return
  end
  local humans = veaf.getAllHumanRecords()
  for sUnitName, _ in pairs(humans) do
    if not veafWeather.briefedUnits[sUnitName] then
      local dcsUnit = Unit.getByName(sUnitName)
      -- `getPlayerName` returns nil for an empty slot and for an AI-filled one; only a real pilot gets a
      -- brief, or a mission with forty declared slots would send forty messages to nobody.
      if dcsUnit and dcsUnit.isExist and dcsUnit:isExist() and dcsUnit.getPlayerName and dcsUnit:getPlayerName() then
        veaf.loggers.get(veafWeather.Id):info("welcome brief for [%s], who was already flying", veaf.p(sUnitName))
        veafWeather.briefedUnits[sUnitName] = true
        veafWeather.sendWelcomeBrief(sUnitName)
      end
    end
  end
end

function veafWeather.initialize(bWelcomeBrief)
  veaf.loggers.get(veafWeather.Id):debug("veafWeather.initialize()")
  veafWeather.buildRadioMenu()
  veafAirbases.initialize()

  -- Off by an explicit setting rather than by absence: a mission maker running his own briefing script
  -- needs to silence this, and #301 asked for the behaviour by default.
  veafWeather.welcomeBriefEnabled = bWelcomeBrief ~= false
  if veafWeather.welcomeBriefEnabled then
    veafWeather.briefedUnits = {}
    veafEventHandler.addCallback(
      "veafWeather.onPlayerEnterUnit",
      { "S_EVENT_BIRTH", "S_EVENT_PLAYER_ENTER_UNIT" },
      veafWeather.onPlayerEnterUnit
    )
    -- And a sweep of who is ALREADY flying, because in single player the event has already happened.
    --
    -- The pilot occupies his slot before the mission's scripts load, so his birth event fires before this
    -- module (order 210) can subscribe to anything. Subscribing was never going to catch it — the brief
    -- said nothing at all in game for exactly that reason, on an airfield and on a carrier alike, and
    -- adding `S_EVENT_BIRTH` to the subscription did not help because the timing, not the event name, was
    -- the problem. Changing slot restarts the mission in single player, so the second attempt lost the
    -- race too.
    --
    -- The subscription stays for pilots who join a running server later; this sweep covers everyone who
    -- was already there. Both go through `briefedUnits`, so nobody is briefed twice.
    veaf.scheduleFunction(veafWeather.briefEveryoneAlreadyFlying, {}, timer.getTime() + veafWeather.WELCOME_BRIEF_DELAY_SECONDS)
  end
  veafRemote.registerRemoteModule("atis", veafWeather.executeCommandFromRemote)
  veafRemote.registerRemoteModule("atc", veafWeather.executeCommandFromRemote)
  veafRemote.registerRemoteModule("weather", veafWeather.executeCommandFromRemote)
end

veaf.loggers.get(veafWeather.Id):info(veaf.loggers.get(veafWeather.Id):getVersionInfo())

veaf.registerModule(veafWeather.Id, function()
  local cfg = veaf.getConfig(veafWeather.Id)
  veafWeather.initialize(cfg.welcomeBrief)
end, { enable = true, welcomeBrief = true }, 210)

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-------------------- TEST STUFF--------------------------------------------------------------------
--[[
.getFogThickness=[function]
.getFogVisibilityDistance=[function]
.setFogAnimation=[function]
.setFogThickness=[function]
.setFogVisibilityDistance=[function]

veafAirbases.initialize()
for _, veafAirbase in pairs(veafAirbases.Airbases) do
    veaf.loggers.get(veafWeather.Id):trace(veafWeatherAtis.getAtisString(veafAirbase))
    if veafAirbase.DcsAirbase and veafAirbase.DcsAirbase:isExist() then
      veaf.loggers.get(veafWeather.Id):trace(veafWeatherData.getWeatherString(veafAirbase.DcsAirbase:getPoint()))
    end
end
veaf.loggers.get(veafWeather.Id):trace(veaf.lp(env.mission.weather.enable_fog))
veaf.loggers.get(veafWeather.Id):trace(veaf.lp(world.weather.getFogVisibilityDistance()))
veaf.loggers.get(veafWeather.Id):trace(veaf.lp(world.weather.getFogThickness()))
]]
