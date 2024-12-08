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

--- Version.
veafWeather.Version = "1.3.0"

-- trace level, specific to this module
--veafWeather.LogLevel = "trace"
veaf.loggers.new(veafWeather.Id, veafWeather.LogLevel)

--- Key phrase to look for in the mark text which triggers the command.
veafWeather.Keyphrase = "_weather"

veafWeather.RadioMenuName = "WEATHER AND ATC"

veafWeather.RemoteCommandParser = "([[a-zA-Z0-9]+)%s?([^%s]*)%s?(.*)"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------
local _dcsPresetDensity =
{
    -- {density, precipitation, visibility}
    ["Preset1"] = {2, false, nil}, -- LS1 -- FEW/SCT
    ["Preset2"] = {2, false, nil}, -- LS2 -- FEW/SCT
    ["Preset3"] = {3, false, nil}, -- HS1 -- SCT
    ["Preset4"] = {3, false, nil}, -- HS2 -- SCT
    ["Preset5"] = {3, false, nil}, -- S1 -- SCT
    ["Preset6"] = {4, false, nil}, -- S2 -- SCT/BKN
    ["Preset7"] = {3, false, nil}, -- S3 -- BKN
    ["Preset8"] = {4, false, nil}, -- HS3 -- SCT/BKN
    ["Preset9"] = {5, false, nil}, -- S4 -- BKN
    ["Preset10"] = {4, false, nil}, -- S5 -- SCT/BKN
    ["Preset11"] = {6, false, nil}, -- S6 -- BKN
    ["Preset12"] = {6, false, nil}, -- S7 -- BKN
    ["Preset13"] = {6, false, nil}, -- B1 -- BKN
    ["Preset14"] = {6, false, nil}, -- B2 -- BKN
    ["Preset15"] = {4, false, nil}, -- B3 -- SCT/BKN
    ["Preset16"] = {6, false, nil}, -- B4 -- BKN
    ["Preset17"] = {7, false, nil}, -- B5 -- BKN/OVC
    ["Preset18"] = {7, false, nil}, -- B6 -- BKN/OVC
    ["Preset19"] = {8, false, nil}, -- B7 -- OVC
    ["Preset20"] = {7, false, nil}, -- B8 -- BKN/OVC
    ["Preset21"] = {7, false, nil}, -- O1 -- BKN/OVC
    ["Preset22"] = {6, false, nil}, -- O2 -- BKN
    ["Preset23"] = {6, false, nil}, -- O3  -- BKN
    ["Preset24"] = {7, false, nil}, -- O4 -- BKN/OVC
    ["Preset25"] = {8, false, nil}, -- O5 -- OVC
    ["Preset26"] = {8, false, nil}, -- O6 -- OVC
    ["Preset27"] = {8, false, nil}, -- O7 -- OVC
    ["RainyPreset1"] = {8, true, 4000}, -- OR1 -- OVC
    ["RainyPreset2"] = {7, true, 3000}, -- OR2 -- BKN/OVC
    ["RainyPreset3"] = {8, true, 4000}, -- OR3 -- OVC
    ["RainyPreset4"] = {4, true, nil}, -- LR1 -- SCT/BKN
    ["RainyPreset5"] = {7, true, nil}, -- LR2 -- BKN/OVC
    ["RainyPreset6"] = {8, true, nil}, -- LR3 -- OVC
    ["NEWRAINPRESET4"] = {8, true, nil}, -- LR4 -- OVC
}

local _cloudDensity = { Clear = 0, Few = 1, Scattered = 2, Broken = 3, Overcast = 4 }
local _cloudDensityOktas =
{
    [0] = _cloudDensity.Clear,
    [1] = _cloudDensity.Few,
    [2] = _cloudDensity.Few,
    [3] = _cloudDensity.Scattered,
    [4] = _cloudDensity.Scattered,
    [5] = _cloudDensity.Broken,
    [6] = _cloudDensity.Broken,
    [7] = _cloudDensity.Overcast,
    [8] = _cloudDensity.Overcast
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
    
    if (iCloudBaseMeters == nil or iCloudBaseMeters > 10000) then
        -- Clear skies - estimate RH based on location and date
        local dateTime = veafTime.getMissionDateTime(iAbsTime)
        nHumidity = _computeClearSkyHumidity(nLatitude, nLongitude, dateTime.yday)
    else
        -- Convert cloud base to meters and estimate RH
        nHumidity = 100 - (iCloudBaseMeters / 100)
        -- Clamp RH between 0 and 100%
        nHumidity = math.max(0, math.min(100, nHumidity))
    end
    
    if (iVisibilityMeters < 1000) then
        nHumidity = 100  -- Fog implies saturation
    elseif (iVisibilityMeters < 5000) then
        nHumidity = math.max(nHumidity, 90)  -- At least 90% RH with any fog
    elseif (iVisibilityMeters < 10000) then
        -- Increase RH as visibility decreases
        local nVisibilityFactor = math.max(0, (10000 - iVisibilityMeters) / 10000)
        nHumidity = nHumidity + (nVisibilityFactor * 20)  -- Up to +20% for low visibility
    end
    
    -- Precipitation adjustments
    if (bPrecipitations) then
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
    local gamma = ((a * nTemperatureCelcius) / (b + nTemperatureCelcius)) + math.log(nHumidity/100.0)
    
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
    local iWindDir, iWindSpeedMps = weathermark._GetWind(vec3, iAltitudeMeters)

    return
    {
        AltitudeMeters = iAltitudeMeters,
        PressureHpa = nPressurePa / 100,
        TemperatureCelcius = nTemperatureKelvin + _nKelvinToCelciusOffset,
        WindDirection = iWindDir,
        WindSpeedMps = iWindSpeedMps
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

veafWeatherUnitSystem.Units =
{
    Kts = 0,
    Mps = 1,
    M = 2,
    Sm = 3,
    Nm = 4,
    Ft = 5,
    Hpa = 6,
    InHg = 7,
    MmHg = 8
}
---------------------------------------------------------------------------------------------------
---  CTOR
function veafWeatherUnitSystem:create(windSpeeds, visibilities, altitudes, pressures)
    local this =
    {
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
veafWeatherUnitSystem.Systems =
{
    Full = veafWeatherUnitSystem:create({ veafWeatherUnitSystem.Units.Kts, veafWeatherUnitSystem.Units.Mps }, { veafWeatherUnitSystem.Units.M, veafWeatherUnitSystem.Units.Sm, veafWeatherUnitSystem.Units.Nm }, { veafWeatherUnitSystem.Units.Ft, veafWeatherUnitSystem.Units.M }, { veafWeatherUnitSystem.Units.Hpa, veafWeatherUnitSystem.Units.InHg, veafWeatherUnitSystem.Units.MmHg }), -- all 
    Icao = veafWeatherUnitSystem:create({ veafWeatherUnitSystem.Units.Kts }, { veafWeatherUnitSystem.Units.M }, { veafWeatherUnitSystem.Units.Ft }, { veafWeatherUnitSystem.Units.Hpa }), -- default
    IcaoMetric = veafWeatherUnitSystem:create({ veafWeatherUnitSystem.Units.Mps }, { veafWeatherUnitSystem.Units.M }, { veafWeatherUnitSystem.Units.Ft }, { veafWeatherUnitSystem.Units.Hpa }), -- for russian airfields
    Faa = veafWeatherUnitSystem:create({ veafWeatherUnitSystem.Units.Kts }, { veafWeatherUnitSystem.Units.Sm }, { veafWeatherUnitSystem.Units.Ft }, { veafWeatherUnitSystem.Units.InHg }), -- for US aircrafts or airfields, and for older british aircrafts
    FaaMetric = veafWeatherUnitSystem:create({ veafWeatherUnitSystem.Units.Kts }, { veafWeatherUnitSystem.Units.M }, { veafWeatherUnitSystem.Units.Ft }, { veafWeatherUnitSystem.Units.InHg }), -- for US army helicopters
    FaaNavy = veafWeatherUnitSystem:create({ veafWeatherUnitSystem.Units.Kts }, { veafWeatherUnitSystem.Units.Nm }, { veafWeatherUnitSystem.Units.Ft }, { veafWeatherUnitSystem.Units.InHg }), -- for US aircraft carriers
    Metric = veafWeatherUnitSystem:create({ veafWeatherUnitSystem.Units.Mps }, { veafWeatherUnitSystem.Units.M }, { veafWeatherUnitSystem.Units.M }, { veafWeatherUnitSystem.Units.Hpa }), -- for french army helicopters
    MetricEastern = veafWeatherUnitSystem:create({ veafWeatherUnitSystem.Units.Mps }, { veafWeatherUnitSystem.Units.M }, { veafWeatherUnitSystem.Units.M }, { veafWeatherUnitSystem.Units.MmHg }), -- for russian and chinese aircrafts
}
veafWeatherUnitSystem.DefaultUnitSystem = veafWeatherUnitSystem.Systems.Icao

veafWeatherUnitSystem.Theatres = {}
veafWeatherUnitSystem.Theatres.Faa = { "nevada", "marianaislands" }
veafWeatherUnitSystem.Theatres.IcaoMetric = { "caucasus" }

veafWeatherUnitSystem.Aircrafts = {}
veafWeatherUnitSystem.Aircrafts.Faa =
{
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
    "UH-1H",
    "P-47D-30",
    "P-47D-40",
    "P-51D",
    "P-51D-30-NA",
    "TF-51D",
    "Christen Eagle II",
    "SpitfireLFMkIX",
    "MosquitoFBMkVI"
}

veafWeatherUnitSystem.Aircrafts.Metric =
{
    "SA342L",
    "SA342M",
    "SA342Minigun",
    "SA342Mistral"
}

veafWeatherUnitSystem.Aircrafts.MetricEastern =
{
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
    "Yak-52"
}

veafWeatherUnitSystem.Aircrafts.FaaMetric =
{
    "AH-64D_BLK_II"
}

---------------------------------------------------------------------------------------------------
---  Methods
function veafWeatherUnitSystem.defaultForElementName(dcsElementName)
    veaf.loggers.get(veafWeather.Id):trace(">>> veafWeatherUnitSystem:defaultForGroup - " .. dcsElementName)

    local sTypeName = "unknown"
    if (not veaf.isNullOrEmpty(dcsElementName)) then
        local dcsElement = Group.getByName(dcsElementName)
        if (dcsElement == nil) then
            dcsElement = Unit.getByName(dcsElementName)
        end
        if (dcsElement) then
            sTypeName = dcsElement:getTypeName()
        end
    end

    veaf.loggers.get(veafWeather.Id):trace(">>> veafWeatherUnitSystem:defaultForGroup - " .. sTypeName)
    return veafWeatherUnitSystem.defaultForTypeName(sTypeName)
end

function veafWeatherUnitSystem.defaultForTypeName(sTypeName)
    if (veaf.tableContains(veafWeatherUnitSystem.Aircrafts.Faa, sTypeName)) then
        return veafWeatherUnitSystem.Systems.Faa
    elseif (veaf.tableContains(veafWeatherUnitSystem.Aircrafts.Metric, sTypeName)) then
        return veafWeatherUnitSystem.Systems.Metric
    elseif (veaf.tableContains(veafWeatherUnitSystem.Aircrafts.MetricEastern, sTypeName)) then
        return veafWeatherUnitSystem.Systems.MetricEastern
    elseif (veaf.tableContains(veafWeatherUnitSystem.Aircrafts.FaaMetric, sTypeName)) then
        return veafWeatherUnitSystem.Systems.FaaMetric        
    else
        return veafWeatherUnitSystem.DefaultUnitSystem
    end
end

function veafWeatherUnitSystem.defaultForTheatre()
    local sTheatre = string.lower(env.mission.theatre)

    if (veaf.tableContains(veafWeatherUnitSystem.Theatres.Faa, sTheatre)) then
        return veafWeatherUnitSystem.Systems.Faa
    elseif (veaf.tableContains(veafWeatherUnitSystem.Theatres.IcaoMetric, sTheatre)) then
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

    local sunTimes = veafTime.getSunTimes(vec3)

    local iWindDirSurface, iWindSpeedSurfaceMps = weathermark._GetWind(vec3, iAltitudeMeters + 10) -- Measure the wind velocity at the standard height of 10 metres above the surface. This is the internationally accepted meteorological definition of ‘surface wind’ designed to eliminate distortion attributable to very local terrain effects

    local iVisibilityMeters = env.mission.weather.visibility.distance
    local clouds = nil
    local bPrecipitation = false;
    local sCloudPreset = env.mission.weather.clouds.preset
    if (veaf.isNullOrEmpty(sCloudPreset)) then
        if (env.mission.weather.clouds.density > 0) then
            local iDensity = mist.utils.round(env.mission.weather.clouds.density * 8 / 10) -- 10 levels in dcs, convert to oktas
            clouds = { Density = iDensity, BaseMeters = env.mission.weather.clouds.base }
        end
        bPrecipitation = (env.mission.weather.clouds.iprecptns > 0)
    else
        if (_dcsPresetDensity[sCloudPreset]) then
            clouds = {Density = _dcsPresetDensity[sCloudPreset][1], BaseMeters = env.mission.weather.clouds.base}
            bPrecipitation = _dcsPresetDensity[sCloudPreset][2]
            if (_dcsPresetDensity[sCloudPreset][3] and _dcsPresetDensity[sCloudPreset][3] < iVisibilityMeters) then
                iVisibilityMeters = _dcsPresetDensity[sCloudPreset][3]
            end
        end
    end

    local iFogThicknessMeters = world.weather.getFogThickness()
    local iFogVisibilityMeters = world.weather.getFogVisibilityDistance()
    if (iFogThicknessMeters >= iAltitudeMeters) then
        iVisibilityMeters = iFogVisibilityMeters
    end
    
    local _, nQfePa = atmosphere.getTemperatureAndPressure({ x = vec3.x, y = iAltitudeMeters, z = vec3.z })
    local nTemperatureKelvin, nQnhPa = atmosphere.getTemperatureAndPressure({ x = vec3.x, y = 0, z = vec3.z })
    local nTemperatureCelcius = nTemperatureKelvin + _nKelvinToCelciusOffset

    local nHumidity = _computeHumidity(vec3, clouds.BaseMeters, iVisibilityMeters, bPrecipitation, iAbsTime)
    local nDewPointCelcius = _computeDewpoint(nTemperatureCelcius, nQnhPa, nHumidity)

    -- Fog FG or mist BR: fog is less than 1000 meters visibility. Mist BR or haze HZ: if the humidity is more than 80% it is mist.
    local visibilityAffect = _visibilityAffect.None
    if (iVisibilityMeters < 1000) then
        visibilityAffect = _visibilityAffect.Fog
    elseif (iVisibilityMeters < 5000 and nHumidity >= 80) then
        visibilityAffect = _visibilityAffect.Mist
    elseif (iVisibilityMeters < 5000) then
        visibilityAffect = _visibilityAffect.Haze
    end

    local this =
    {
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
        SunriseZulu = sunTimes.Sunrise,
        SunsetZulu = sunTimes.Sunset,
        SunriseLocal = sunTimes.SunriseLocal,
        SunsetLocal = sunTimes.SunsetLocal,

        WeatherAt500 = _weatherSliceAtAltitude(vec3, 500),
        WeatherAt2000 = _weatherSliceAtAltitude(vec3, 2000),
        WeatherAt8000 = _weatherSliceAtAltitude(vec3, 8000)
    }

    setmetatable(this, veafWeatherData)

    --[[
    veaf.loggers.get(veafWeather.Id):trace("**** WEATHER REPORT TEST ****")
    veaf.loggers.get(veafWeather.Id):trace("**** FULL REPORT ****")
    veaf.loggers.get(veafWeather.Id):trace(this:toStringExtended(veafWeatherUnitSystem.Systems.Full, true))
    veaf.loggers.get(veafWeather.Id):trace("**** ICAO REPORT ****")
    veaf.loggers.get(veafWeather.Id):trace(this:toStringExtended(veafWeatherUnitSystem.Systems.Icao, true))
    veaf.loggers.get(veafWeather.Id):trace("**** ICAO METRIC REPORT ****")
    veaf.loggers.get(veafWeather.Id):trace(this:toStringExtended(veafWeatherUnitSystem.Systems.IcaoMetric, true))
    veaf.loggers.get(veafWeather.Id):trace("**** FAA REPORT ****")
    veaf.loggers.get(veafWeather.Id):trace(this:toStringExtended(veafWeatherUnitSystem.Systems.Faa, true))
    veaf.loggers.get(veafWeather.Id):trace("**** FAA NAVY REPORT ****")
    veaf.loggers.get(veafWeather.Id):trace(this:toStringExtended(veafWeatherUnitSystem.Systems.FaaNavy, true))
    veaf.loggers.get(veafWeather.Id):trace("**** METRIC REPORT ****")
    veaf.loggers.get(veafWeather.Id):trace(this:toStringExtended(veafWeatherUnitSystem.Systems.Metric, true))
    veaf.loggers.get(veafWeather.Id):trace("**** METRIC EASTERN REPORT ****")
    veaf.loggers.get(veafWeather.Id):trace(this:toStringExtended(veafWeatherUnitSystem.Systems.MetricEastern, true))
    ]]
    return this
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Static methods
function veafWeatherData.getWeatherString(vec3, dcsElementName, unitSystem)
    local sTypeName = "unknown"
    local bWithLaste = false

    if (not veaf.isNullOrEmpty(dcsElementName)) then
        local dcsElement = Group.getByName(dcsElementName)
        if (dcsElement == nil) then
            dcsElement = Unit.getByName(dcsElementName)
        end
        if (dcsElement) then
            sTypeName = dcsElement:getTypeName()
        end
    end

    if (unitSystem == nil) then
        unitSystem = veafWeatherUnitSystem.defaultForTypeName(sTypeName)
    end

    if (not veaf.isNullOrEmpty(sTypeName) and veaf.startsWith(sTypeName, "A-10", false)) then
        bWithLaste = true
    end

    local weatherData = veafWeatherData:create(vec3)
    return weatherData:toString(unitSystem, bWithLaste)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Methods
function veafWeatherData:getNormalizedWindDirection(iDirectionTrue, bMagnetic)
    bMagnetic = bMagnetic or false

    local iDirection = iDirectionTrue
    
    if (bMagnetic) then
        iDirection = iDirection - veaf.getMagneticDeclination()
        if (iDirection) < 0 then
            iDirection = iDirection + 360
        end    
    end

    if (iDirection == 0) then
        iDirection = 360
    end

    return iDirection
end

function veafWeatherData:getNormalizedCloudBaseMeters(bHeight)
    bHeight = bHeight or false

    if (self.Clouds == nil or self.Clouds.Density <= 0) then
        return nil
    else
         local iCloudBase = self.Clouds.BaseMeters
         if (bHeight) then
            iCloudBase = iCloudBase - self.AltitudeMeter
        end

        return iCloudBase
    end
end

function veafWeatherData:getNormalizedCloudsDensity()
    if (self.Clouds == nil or self.Clouds.BaseMeters == nil or self.Clouds.Density <= 0) then
        return _cloudDensity.Clear
    else
        return _cloudDensityOktas[self.Clouds.Density]
    end
end

function veafWeatherData:isCavok()
    local iCloudHeightMeters = self:getNormalizedCloudBaseMeters(true)

    if (iCloudHeightMeters == nil or mist.utils.metersToFeet(iCloudHeightMeters) < 5000) then
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
    if (bNight) then
        return 3
    end

    local iCloudBase = nil
    if (self.Clouds and self.Clouds.Density > 4) then
        iCloudBase = self.Clouds.BaseMeters
    end

    local iVisibilityCase12 = mist.utils.NMToMeters(5)
    local iCloudBaseCase1 = mist.utils.feetToMeters(3000)
    local iCloudBaseCase2 = mist.utils.feetToMeters(1000)

    --veaf.loggers.get(veaf.Id):trace(string.format("GetCarrierCase - Cloud base=%d feet (need more than 1000 for CASE 2 and 300 for CASE 3) - visibility=%d nm (need more than 5 for CASE 1/2)", iCloudBase or -1, UTILS.MetersToNM (self.VisibilityMeters)))

    if (self.VisibilityMeters > iVisibilityCase12 and (iCloudBase == nil or iCloudBase > iCloudBaseCase1)) then
        return 1
    elseif (self.VisibilityMeters > iVisibilityCase12 and (iCloudBase == nil or iCloudBase > iCloudBaseCase2)) then
        return 2
    else
        return 3
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ToStrings
function veafWeatherData:appendString(s, sAppend)
    sAppend = sAppend or ""

    if (veaf.isNullOrEmpty(s)) then
        return sAppend
    elseif (veaf.isNullOrEmpty(sAppend)) then
        return s
    else
        return s .. "|" .. sAppend
    end
end

function veafWeatherData:toStringWind(unitSystem, iDirection, nSpeedMps, bMagnetic)
    unitSystem = unitSystem or veafWeatherUnitSystem.DefaultUnitSystem
    bMagnetic = bMagnetic or false

    if (nSpeedMps <= 0.5) then
        return "calm"
    end

    local iDirection = self:getNormalizedWindDirection(iDirection, bMagnetic)
    local sSpeedKts = string.format("%dkts", mist.utils.mpsToKnots(nSpeedMps))
    local sSpeedMps = string.format("%dm/s", nSpeedMps)
    local sSpeed
    if(veaf.tableContains(unitSystem.WindSpeeds, veafWeatherUnitSystem.Units.Kts)) then
        sSpeed = veafWeatherData:appendString(sSpeed, sSpeedKts)
    end
    if(veaf.tableContains(unitSystem.WindSpeeds, veafWeatherUnitSystem.Units.Mps)) then
        sSpeed = veafWeatherData:appendString(sSpeed, sSpeedMps)
    end

    local sDegrees
    if (bMagnetic) then
        sDegrees = "°M"
    else
        sDegrees = "°T"
    end

    return string.format("%03d%s @ %s", iDirection, sDegrees, sSpeed)
end

function veafWeatherData:toStringVisibility(unitSystem, bWithMax)
    unitSystem = unitSystem or veafWeatherUnitSystem.DefaultUnitSystem

    local sVisibilityMeters
    if (self.VisibilityMeters >= 10000) then
        sVisibilityMeters = "10+km"
    else
        local iVisibilityMeters = mist.utils.round(self.VisibilityMeters / 100) * 100
        sVisibilityMeters = string.format("%dm", iVisibilityMeters)
    end

    local sVisibilityStatuteMile
    local iVisibilityStatuteMile = mist.utils.round(self.VisibilityMeters * 0.000621371)
    if (iVisibilityStatuteMile >= 10) then
        sVisibilityStatuteMile = "10+SM"
    else
        sVisibilityStatuteMile = string.format("%dSM", iVisibilityStatuteMile)
    end

    local sVisibilityNauticalMile
    local iVisibilityNauticalMile = mist.utils.round(mist.utils.metersToNM(self.VisibilityMeters))
    if (iVisibilityNauticalMile >= 10) then
        sVisibilityNauticalMile = "10+NM"
    else
        sVisibilityNauticalMile = string.format("%dNM", iVisibilityNauticalMile)
    end

    local sVisibility
    if(veaf.tableContains(unitSystem.Visibilities, veafWeatherUnitSystem.Units.M)) then
        sVisibility = veafWeatherData:appendString(sVisibility, sVisibilityMeters)
    end
    if(veaf.tableContains(unitSystem.Visibilities, veafWeatherUnitSystem.Units.Sm)) then
        sVisibility = veafWeatherData:appendString(sVisibility, sVisibilityStatuteMile)
    end
    if(veaf.tableContains(unitSystem.Visibilities, veafWeatherUnitSystem.Units.Nm)) then
        sVisibility = veafWeatherData:appendString(sVisibility, sVisibilityNauticalMile)
    end

    if (self.VisibilityAffect == _visibilityAffect.Fog) then
        sVisibility = sVisibility .. " - fog"
    elseif (self.VisibilityAffect == _visibilityAffect.Haze) then
        sVisibility = sVisibility .. " - haze"
    elseif (self.VisibilityAffect == _visibilityAffect.Mist) then
        sVisibility = sVisibility .. " - mist"
    end
    if (self.Dust) then
        sVisibility = sVisibility .. " - dust"
    end
    if (self.Precipitation) then
        sVisibility = sVisibility .. " - precipitations"
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

    if (cloudDensity == _cloudDensity.Clear) then
        sCloudDensity = "No clouds"
    else
        if (cloudDensity == _cloudDensity.Scattered) then
            sCloudDensity = "Scattered clouds"
        elseif (cloudDensity == _cloudDensity.Broken) then
            sCloudDensity = "Broken clouds"
        elseif (cloudDensity == _cloudDensity.Overcast) then
            sCloudDensity = "Overcast clouds"
        else
            sCloudDensity = "Few clouds"
        end
        
        if (iCloudBaseMeters ~= nil and iCloudBaseMeters > 0) then
            local iCloudBaseFeet = math.floor((mist.utils.metersToFeet(iCloudBaseMeters) + 250) / 500) * 500
            local iCloudBaseMeters = math.floor((iCloudBaseMeters + 250) / 500) * 500
            local sCloudBaseFeet = string.format("%dft", iCloudBaseFeet)
            local sCloudBaseMeters = string.format("%dm", iCloudBaseMeters)

            if(veaf.tableContains(unitSystem.Altitudes, veafWeatherUnitSystem.Units.Ft)) then
                sCloudBase = veafWeatherData:appendString(sCloudBase, sCloudBaseFeet)
            end
            if(veaf.tableContains(unitSystem.Altitudes, veafWeatherUnitSystem.Units.M)) then
                sCloudBase = veafWeatherData:appendString(sCloudBase, sCloudBaseMeters)
            end

            sCloudBase = string.format(" @ %s", sCloudBase)

            if (bHeight) then
                sCloudBase = sCloudBase .. " AGL"
            else
                sCloudBase = sCloudBase .. " ASL"
            end
        end
    end

    return string.format("%s%s", sCloudDensity, sCloudBase) 
end

function veafWeatherData:toStringTemperature(nTemperatureCelcius)
    return string.format("%d°C", mist.utils.round(nTemperatureCelcius))
end

function veafWeatherData:toStringPressure(unitSystem, nPressureHpa)
    unitSystem = unitSystem or veafWeatherUnitSystem.DefaultUnitSystem

    local sPressureHpa = string.format("%.0fHpa", nPressureHpa)
    local sPressureInHg = string.format("%.2finHg", mist.utils.converter("hpa", "inhg", nPressureHpa))
    local sPressureMmHg = string.format("%.0fmmHg", nPressureHpa * 0.75006375541921) -- mist convert has the wrong coefficient for hpa to mmHg
 
    local sPressure
    if(veaf.tableContains(unitSystem.Pressures, veafWeatherUnitSystem.Units.Hpa)) then
        sPressure = veafWeatherData:appendString(sPressure, sPressureHpa)
    end
    if(veaf.tableContains(unitSystem.Pressures, veafWeatherUnitSystem.Units.InHg)) then
        sPressure = veafWeatherData:appendString(sPressure, sPressureInHg)
    end
    if(veaf.tableContains(unitSystem.Pressures, veafWeatherUnitSystem.Units.MmHg)) then
        sPressure = veafWeatherData:appendString(sPressure, sPressureMmHg)
    end

    return sPressure
end

function veafWeatherData:toStringSunTime(dateTimeZulu, bZulu, bLocal)
    local sLocal = ""
    if (bLocal) then
        local dateTimeLocal = veafTime.toLocal(dateTimeZulu)
        sLocal = string.format("%sL", veafTime.toStringTime(dateTimeLocal, false))
    end 

    local sZulu = ""
    if (bZulu) then
        sZulu = string.format("%sZ", veafTime.toStringTime(dateTimeZulu, false))
    end 

    if (bLocal and bZulu) then
        return string.format("%s - %s", sZulu, sLocal)
    elseif (bLocal) then
        return sLocal
    else
        return sZulu
    end
end

function veafWeatherData:toStringSlice(weatherSlice, unitSystem, bMagnetic)
    unitSystem = unitSystem or veafWeatherUnitSystem.DefaultUnitSystem
    bMagnetic = bMagnetic or false

    local sAltitudeMeters = string.format("%dm", weatherSlice.AltitudeMeters)
    local sAltitudeFl = _getFlightLevelString(mist.utils.metersToFeet(weatherSlice.AltitudeMeters))

    local sAltitude
    if(veaf.tableContains(unitSystem.Altitudes, veafWeatherUnitSystem.Units.Ft)) then
        sAltitude = veafWeatherData:appendString(sAltitude, sAltitudeFl)
    end
    if(veaf.tableContains(unitSystem.Altitudes, veafWeatherUnitSystem.Units.M)) then
        sAltitude = veafWeatherData:appendString(sAltitude, sAltitudeMeters)
    end

    local sTemperature = self:toStringTemperature(weatherSlice.TemperatureCelcius)
    local sPressure = self:toStringPressure(unitSystem, weatherSlice.PressureHpa)
    local sWind = self:toStringWind(unitSystem, weatherSlice.WindDirection, weatherSlice.WindSpeedMps, bMagnetic)

    return string.format("%s:  wind %s ; %s", sAltitude, sWind, sTemperature)
end

function veafWeatherData:toStringLaste()
    local function _getLasteAt(iDesiredHeightFeet)
        local iAltitudeFeet = math.floor((mist.utils.metersToFeet(self.AltitudeMeter) + iDesiredHeightFeet + 500) / 1000) * 1000
        local iAltitudeMeters = mist.utils.feetToMeters(iAltitudeFeet)
        local iTemperatureKelvin, _ = atmosphere.getTemperatureAndPressure({ x = self.Vec3.x, y = iAltitudeMeters, z = self.Vec3.z })
        local iWindDirection, iWindSpeedMps = weathermark._GetWind(self.Vec3, iAltitudeMeters)
        local iWindDirectionMagnetic = veafWeatherData:getNormalizedWindDirection(iWindDirection, true)

        local sLaste = string.format("ALT%02d W%03d/%02d T%+d", iAltitudeFeet / 1000, iWindDirectionMagnetic, mist.utils.mpsToKnots(iWindSpeedMps), iTemperatureKelvin + _nKelvinToCelciusOffset)
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
    sString = sString .. string.format("Wind:          %s", self:toStringWind(unitSystem, self.WindDirection, self.WindSpeedMps))
    sString = sString .. "\n"
    sString = sString .. string.format("\nVisibility:    %s", self:toStringVisibility(unitSystem))
    sString = sString .. string.format("\nClouds:        %s", self:toStringClouds(unitSystem, true))
    sString = sString .. "\n"
    sString = sString .. string.format("\nTemperature:   %s - Dew point: %s", self:toStringTemperature(self.TemperatureCelcius), self:toStringTemperature(self.DewPointCelcius))
    sString = sString .. string.format("\nQNH:           %s", self:toStringPressure(unitSystem, self.QnhHpa))
    sString = sString .. string.format("\nQFE:           %s", self:toStringPressure(unitSystem, self.QfeHpa))
    sString = sString .. string.format("\nSunrise:       %s", self:toStringSunTime(self.SunriseZulu, true, true))
    sString = sString .. string.format("\nSunset:       %s", self:toStringSunTime(self.SunsetZulu, true, true))
    
    if(bWithLaste) then
        sString = sString .. "\n"
        sString = sString .. string.format("\nLASTE:%s", self:toStringLaste())
    else
        sString = sString .. "\n"
        sString = sString .. string.format("\n @ %s", self:toStringSlice(self.WeatherAt500, unitSystem))
        sString = sString .. string.format("\n @ %s", self:toStringSlice(self.WeatherAt2000, unitSystem))
        sString = sString .. string.format("\n @ %s", self:toStringSlice(self.WeatherAt8000, unitSystem))
    end

    return sString
end

function veafWeatherData:toStringExtended(unitSystem, bHeight)
    unitSystem = unitSystem or veafWeatherUnitSystem.DefaultUnitSystem

    local sAltitudeFeet = string.format("%dft", mist.utils.round(mist.utils.metersToFeet(self.AltitudeMeter)))
    local sAltitudeMeters = string.format("%dm", mist.utils.round(self.AltitudeMeter))
    local sAltitude
    if(veaf.tableContains(unitSystem.Altitudes, veafWeatherUnitSystem.Units.Ft)) then
        sAltitude = veafWeatherData:appendString(sAltitude, sAltitudeFeet)
    end
    if(veaf.tableContains(unitSystem.Altitudes, veafWeatherUnitSystem.Units.M)) then
        sAltitude = veafWeatherData:appendString(sAltitude, sAltitudeMeters)
    end

    local nLatitude, nLongitude = coord.LOtoLL(self.Vec3)
    
    local sString = ""
    sString = sString .. string.format("Time:          %s", veafTime.absTimeToStringDateTime(self.AbsTime))
    sString = sString .. string.format("\nLocation:      %s", mist.tostringLL(nLatitude, nLongitude, 0, true))
    sString = sString .. string.format("\nAltitude:      %s", sAltitude)
    sString = sString .. "\n\n" .. self:toString(unitSystem, bHeight)
    return sString    
end

function veafWeatherData:toStringAtis(unitSystem)
    unitSystem = unitSystem or veafWeatherUnitSystem.DefaultUnitSystem

    local sAtis = ""
    sAtis = sAtis .. string.format("Wind %s", self:toStringWind(unitSystem, self.WindDirection, self.WindSpeedMps, true))
    if(self:isCavok()) then
        sAtis = sAtis .. "\nCeiling and visiblity OK, CAVOK"
    else
        sAtis = sAtis .. string.format("\nVisibility %s, %s", self:toStringVisibility(unitSystem), self:toStringClouds(unitSystem, true))
    end
    
    sAtis = sAtis .. string.format("\nTemperature %s, dew point %s", self:toStringTemperature(self.TemperatureCelcius), self:toStringTemperature(self.DewPointCelcius))
    sAtis = sAtis .. string.format("\nQNH %s", self:toStringPressure(unitSystem, self.QnhHpa))
    
    if(veafTime.isAeronauticalNight(self.Vec3, self.AbsTime)) then
        sAtis = sAtis .. string.format("\nSunrise %s", self:toStringSunTime(self.SunriseZulu, true, false))
    else
        sAtis = sAtis .. string.format("\nSunset %s", self:toStringSunTime(self.SunsetZulu, true, false))
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
    local iHoursSinceMidnight = dateTimeZulu.hour
    local sLetter = string.char(math.floor(iHoursSinceMidnight) + string.byte("A"))

    local iRecordedAtMinutes = math.random(2, 11) -- ATIS recorded between h:02 and hour:11
    if (iRecordedAtMinutes > dateTimeZulu.min) then
        -- if record is in the future set recording at the request time
        iRecordedAtMinutes = dateTimeZulu.min
    end
    dateTimeZulu.min = iRecordedAtMinutes

    local iAltitude = nil
    local unitSystem
    if (veafAirbase.Category == Airbase.Category.SHIP) then
        -- Maybe use the type name to decide the unit system?
        --[[
        local dcsShip = dcsAirbase:getUnit()
        local dcsShipType = dcsShip:getTypeName()
        veaf.loggers.get(veafWeather.Id):trace(veaf.p(dcsShipType))
        ]]

        iAltitude = 20
        unitSystem = veafWeatherUnitSystem.Systems.FaaNavy
    else
        unitSystem = veafWeatherUnitSystem.defaultForTheatre()
    end
    
    local weatherData = veafWeatherData:create(veafAirbase.DcsAirbase:getPoint(), nil, iAltitude)

    local sMessage
    
    if (veafAirbase.Category == Airbase.Category.SHIP) then
        sMessage = string.format("%s information at %sZ", veafAirbase.DisplayName, veafTime.toStringTime(dateTimeZulu, false))
        local iCarrierCase = weatherData:getCarrierCase()
        if (iCarrierCase) then
            local sCaseString = nil
            if (iCarrierCase == 1) then sCaseString = "I"
            elseif (iCarrierCase == 2) then sCaseString = "II"
            elseif (iCarrierCase == 3) then sCaseString = "III"
            end
            
            if (not veaf.isNullOrEmpty(sCaseString)) then
                sMessage = sMessage .. string.format("\nProbable CASE %s in effect", sCaseString)
            end
        end
    elseif (veafAirbase.Category == Airbase.Category.HELIPAD) then
        sMessage = string.format("%s information at %sZ", veafAirbase.DisplayName, veafTime.toStringTime(dateTimeZulu, false))
    else
        sMessage = string.format("%s information %s, recorded at %sZ", veafAirbase.Name, sLetter, veafTime.toStringTime(dateTimeZulu, false))
        local sRunwayInService = veafAirbase:getRunwayInServiceString(weatherData.WindDirection)
        if (not veaf.isNullOrEmpty(sRunwayInService)) then
            sMessage = sMessage .. string.format("\nRecommended runway %s", sRunwayInService)
        end
    end

    sMessage = sMessage .. "\n" .. weatherData:toStringAtis(unitSystem)
    --sMessage = sMessage .. "\n" .. weatherData:toStringExtended()

    local this =
    {
        AirbaseName = veafAirbase.Name,
        Letter = sLetter,
        DateTimeZulu = dateTimeZulu,
        Message = sMessage
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

    veaf.loggers.get(veafWeather.Id):trace(string.format("Preparing ATIS for airbase %s at %sZ", veafAirbase.Name, veafTime.toStringTime(dateTimeZulu, false)))

    local atisInEffect = veafWeatherAtis.ListInEffect[veafAirbase.Name]
    if (atisInEffect) then
        veaf.loggers.get(veafWeather.Id):trace(string.format("ATIS in effect: %s %s", atisInEffect.Letter, veafTime.toStringTime(atisInEffect.DateTimeZulu, false)))
        if (dateTimeZulu.year > atisInEffect.DateTimeZulu.year or dateTimeZulu.month > atisInEffect.DateTimeZulu.month or dateTimeZulu.day > atisInEffect.DateTimeZulu.day or dateTimeZulu.hour > atisInEffect.DateTimeZulu.hour) then
            -- if current date is in the next hour of more from the current one, declare new atis
            veaf.loggers.get(veafWeather.Id):trace(string.format("Current time %s: new ATIS", veafTime.toStringTime(dateTimeZulu, false)))  
            atisInEffect = nil 
        end
    end

    if (atisInEffect == nil) then
        atisInEffect = veafWeatherAtis:Create(veafAirbase, dateTimeZulu)
        veaf.loggers.get(veafWeather.Id):trace(string.format("New ATIS in effect for airbase %s: %s %s", veafAirbase.Name, atisInEffect.Letter, veafTime.toStringTime(atisInEffect.DateTimeZulu, false)))  
        veafWeatherAtis.ListInEffect[veafAirbase.Name] = atisInEffect
    end

    return atisInEffect
end

function veafWeatherAtis.getAtisString(veafAirbase)
    local atisInEffect = veafWeatherAtis.getAtis(veafAirbase)
    return atisInEffect.Message
end

function veafWeatherAtis.getAtisStringFromVeafPoint(sPointName, iAbsTime)
    if (veaf.isNullOrEmpty(sPointName)) then
        veaf.loggers.get(veafWeather.Id):error("No point name")
        return "No point name"
    end

    local dcsAirbase = veaf.findDcsAirbase(sPointName)
    local veafAirbase = veafAirbases.getAirbaseFromDcsAirbase(dcsAirbase)

    if (veafAirbase == nil) then
        veaf.loggers.get(veafWeather.Id):error("Airbase not found for point " .. sPointName)
        return "Airbase not found for point " .. sPointName
    end

    veaf.loggers.get(veafWeather.Id):trace("Airbase found from veaf point named %s: %s",veaf.p(sPointName), veaf.p(veaf.ifnn(dcsAirbase, "getName")))

    return veafWeatherAtis.getAtisString(veafAirbase, iAbsTime)
end

function veafWeather.messageWeatherAtClosestPoint(unitName, forUnit)
    veaf.loggers.get(veafWeather.Id):debug("veafWeather.messageWeatherAtClosestPoint(unitName=%s)",veaf.p(unitName))
    local closestPoint = veafNamedPoints.getNearestPoint(unitName)
    if closestPoint then
        local BR = veafNamedPoints.getPointBearing({closestPoint.name, unitName})
        if BR then BR = " ("..BR..")" else BR = "" end
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
    local dcsUnit = Unit.getByName(unitName)
    local veafAirbase = veafAirbases.getNearestAirbase(dcsUnit)
    if (veafAirbase) then
        local sAtcReport = veafWeatherAtis.getAtisString(veafAirbase)
        if forUnit then
            veaf.outTextForUnit(dcsUnit:getName(), sAtcReport, 30)
        else
            veaf.outTextForGroup(dcsUnit:getName(), sAtcReport, 30)
        end
    end
end

function veafWeather.messageAtcAndWeather(unitName, forUnit)
    veafWeather.messageWeatherAtClosestPoint(unitName, forUnit)
    veafWeather.messageAtcClosestAirbase(unitName, forUnit)
end

----------------------------------------------------------------------------------------------------
--- WEATHER modifications during runtime

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafFog class methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

VeafFog = {}
VeafFog.DELAY_BETWEEN_DYNAMIC_CHECKS = 5 * 60
VeafFog.DYNAMICFOG_BASEFACTOR_HEAVY  = 0.8
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
  object.fogStaticData = {visibility = 10000, thickness = 150}
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
    veaf.loggers.get(veafWeather.Id):debug("VeafFog[%s]:activate()", veaf.p(self.name))
    veafWeather.setAndActivateFog(self)
end

function VeafFog:enable()
    veaf.loggers.get(veafWeather.Id):debug("VeafFog[%s]:enable()", veaf.p(self.name))

    self.enabled = true

    -- store the existing fog parameters
    veaf.loggers.get(veafWeather.Id):trace("store the existing fog parameters")
    veaf.loggers.get(veafWeather.Id):trace("world.weather.getFogVisibilityDistance()=[%s]", veaf.p(world.weather.getFogVisibilityDistance()))
    veaf.loggers.get(veafWeather.Id):trace("world.weather.getFogThickness()=[%s]", veaf.p(world.weather.getFogThickness()))
    self.fogSavedStaticData = {visibility = world.weather.getFogVisibilityDistance(), thickness = world.weather.getFogThickness()}

    -- set the fog to the programmed parameters
    veaf.loggers.get(veafWeather.Id):trace("set the fog to the programmed parameters")
    if self.forAnimationData then
        veaf.loggers.get(veafWeather.Id):trace("self.forAnimationData=[%s]", veaf.p(self.forAnimationData))
        -- create an animation
        local animation = {
            self.forAnimationData
        }
        -- first reset fog animation
        veaf.loggers.get(veafWeather.Id):trace("first reset fog animation")
        world.weather.setFogAnimation({})
        veaf.loggers.get(veafWeather.Id):trace("store the existing fog parameters")
        veaf.loggers.get(veafWeather.Id):trace("world.weather.getFogVisibilityDistance()=[%s]", veaf.p(world.weather.getFogVisibilityDistance()))
        veaf.loggers.get(veafWeather.Id):trace("world.weather.getFogThickness()=[%s]", veaf.p(world.weather.getFogThickness()))
        -- set the new fog animation
        world.weather.setFogAnimation(animation)
    elseif self.fogStaticData then
        veaf.loggers.get(veafWeather.Id):trace("self.fogStaticData=[%s]", veaf.p(self.fogStaticData))
        world.weather.setFogThickness(self.fogStaticData.thickness)
        world.weather.setFogVisibilityDistance(self.fogStaticData.visibility)
    end

    -- do the first check, the method will reschedule itself
    veaf.loggers.get(veafWeather.Id):trace("do the first check, the method will reschedule itself")
    self:dynamicCheck()

    return self
end

function VeafFog:disable(dontRestore)
    veaf.loggers.get(veafWeather.Id):debug("VeafFog[%s]:disable()", veaf.p(self.name))

    -- disable the scheduler
    if self.dynamicCheckFunctionScheduled then
        veaf.loggers.get(veafWeather.Id):trace("disable the scheduler")
        mist.removeFunction(self.dynamicCheckFunctionScheduled)
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
    veaf.loggers.get(veafWeather.Id):debug("VeafFog[%s]:dynamicCheck()", veaf.p(self.name))
    if self.dynamicFogBaseFactor then
        local position = {x=0, y=0, z=0} -- somewhere in the map ^^

        -- compute the fog that should be set at this moment in time
        local date = veafTime.getMissionDateTime()
        veaf.loggers.get(veafWeather.Id):trace("date=[%s]", veaf.p(date))

        -- Seasonal adjustment based on latitude and time of year
        local latitude, _, _ = coord.LOtoLL(position)
        veaf.loggers.get(veafWeather.Id):trace("latitude=[%s]", veaf.p(latitude))
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

        veaf.loggers.get(veafWeather.Id):trace("sunrise_time=[%s:%s]", veaf.p(math.floor(sunrise_time/60)), veaf.p(math.fmod(sunrise_time,60)))
        veaf.loggers.get(veafWeather.Id):trace("morningPeak_time=[%s:%s]", veaf.p(math.floor(morningPeak_time/60)), veaf.p(math.fmod(morningPeak_time,60)))
        veaf.loggers.get(veafWeather.Id):trace("morningEnd_time=[%s:%s]", veaf.p(math.floor(morningEnd_time/60)), veaf.p(math.fmod(morningEnd_time,60)))
        veaf.loggers.get(veafWeather.Id):trace("eveningStart_time=[%s:%s]", veaf.p(math.floor(eveningStart_time/60)), veaf.p(math.fmod(eveningStart_time,60)))
        veaf.loggers.get(veafWeather.Id):trace("eveningPeak_time=[%s:%s]", veaf.p(math.floor(eveningPeak_time/60)), veaf.p(math.fmod(eveningPeak_time,60)))
        veaf.loggers.get(veafWeather.Id):trace("sunset_time=[%s:%s]", veaf.p(math.floor(sunset_time/60)), veaf.p(math.fmod(sunset_time,60)))
        veaf.loggers.get(veafWeather.Id):trace("daylight_duration=[%s]", veaf.p(daylight_duration))
        veaf.loggers.get(veafWeather.Id):trace("current_time=[%s:%s]", veaf.p(math.floor(current_time/60)), veaf.p(math.fmod(current_time,60)))

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
        veaf.loggers.get(veafWeather.Id):trace("weatherData.WindSpeedMps=[%s]", veaf.p(weatherData.WindSpeedMps))
        veaf.loggers.get(veafWeather.Id):trace("temp_diff=[%s]", veaf.p(temp_diff))
        veaf.loggers.get(veafWeather.Id):trace("base_prob=[%s]", veaf.p(base_prob))
        veaf.loggers.get(veafWeather.Id):trace("season_factor=[%s]", veaf.p(season_factor))
        veaf.loggers.get(veafWeather.Id):trace("diurnal_factor=[%s]", veaf.p(diurnal_factor))
        veaf.loggers.get(veafWeather.Id):trace("fog_probability=[%s]", veaf.p(fog_probability))

        -- Compute visibility and thickness based on fog_probability with smooth transitions
        local visibility, thickness
        if fog_probability < 0.2 then
            visibility = 50000 * (1 - fog_probability)  -- High visibility as fog_probability decreases
            thickness = 0  -- No fog, so no thickness
        else
            -- Normalize the fog factor relative to the 0.2-1.0 range
            local normalizedFactor = (fog_probability - 0.2) / 0.8

            local minVisibility = 100 * (1 - self.dynamicFogBaseFactor)
            local maxVisibility = 5000 * (1 - self.dynamicFogBaseFactor)
            local minThickness = 100 * self.dynamicFogBaseFactor
            local maxThickness = 500 * self.dynamicFogBaseFactor
            veaf.loggers.get(veafWeather.Id):trace("minVisibility=[%s]", veaf.p(minVisibility))
            veaf.loggers.get(veafWeather.Id):trace("maxVisibility=[%s]", veaf.p(maxVisibility))
            veaf.loggers.get(veafWeather.Id):trace("minThickness=[%s]", veaf.p(minThickness))
            veaf.loggers.get(veafWeather.Id):trace("maxThickness=[%s]", veaf.p(maxThickness))

            -- Calculate visibility (decreasing from 5000 to 100)
            visibility = maxVisibility - ((maxVisibility - minVisibility) * normalizedFactor)

            -- Calculate thickness (increasing from 100 to 1000)
            thickness = minThickness + ((maxThickness - minThickness) * normalizedFactor)
        end

        visibility = math.floor(visibility)
        thickness = math.floor(thickness)
        veaf.loggers.get(veafWeather.Id):trace("thickness=[%s]", veaf.p(thickness))
        veaf.loggers.get(veafWeather.Id):trace("visibility=[%s]", veaf.p(visibility))

        if self.dynamicFogIsAnimated then
            -- create an animation
            veaf.loggers.get(veafWeather.Id):trace("thickness=[%s]", veaf.p(thickness))
            local animation = {
                VeafFog.DELAY_BETWEEN_DYNAMIC_CHECKS - VeafFog.DELAY_BETWEEN_DYNAMIC_CHECKS*0.1, visibility, thickness
            }
            veaf.loggers.get(veafWeather.Id):trace("animation=[%s]", veaf.p(animation))

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
    self.dynamicCheckFunctionScheduled = mist.scheduleFunction(VeafFog.dynamicCheck, {self}, timer.getTime() + VeafFog.DELAY_BETWEEN_DYNAMIC_CHECKS)
end

function veafWeather.createStaticFog(name, thickness, visibility)
    local fog = VeafFog:new()
    fog.name = name
    fog.fogStaticData = { thickness = thickness, visibility = visibility}
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
    fog.forAnimationData = {minutes * 60, visibility, thickness}
    return fog
end

function veafWeather.setAndActivateFog(fogObject)
    veaf.loggers.get(veafWeather.Id):trace("fogObject=[%s]", veaf.p(fogObject))

    -- disable the existing fog object if any
    if veafWeather.existingFog ~= nil then
        veaf.loggers.get(veafWeather.Id):trace("disable the existing fog object if any")
        veaf.loggers.get(veafWeather.Id):trace("veafWeather.existingFog=[%s]", veaf.p(veafWeather.existingFog))
        veafWeather.existingFog:disable(true)
    end

    -- activate the new fog object
    veaf.loggers.get(veafWeather.Id):trace("activate the new fog object")
    veafWeather.existingFog = fogObject
    fogObject:enable()

    trigger.action.outText("Fog set to "..fogObject.name, 5)

    return fogObject
end

-- dynamically managed fog instances
veafWeather.FOG_DYNAMIC_HEAVY     = veafWeather.createDynamicFog("Dynamic HEAVY fog", VeafFog.DYNAMICFOG_BASEFACTOR_HEAVY)
veafWeather.FOG_DYNAMIC_MEDIUM    = veafWeather.createDynamicFog("Dynamic MEDIUM fog", VeafFog.DYNAMICFOG_BASEFACTOR_MEDIUM)
veafWeather.FOG_DYNAMIC_SPARSE    = veafWeather.createDynamicFog("Dynamic SPARSE fog", VeafFog.DYNAMICFOG_BASEFACTOR_SPARSE)

-- static fog instances
veafWeather.FOG_STATIC_HEAVY      = veafWeather.createStaticFog("Static HEAVY fog", 500, 100)
veafWeather.FOG_STATIC_MEDIUM     = veafWeather.createStaticFog("Static MEDIUM fog", 500, 500)
veafWeather.FOG_STATIC_MEDIUM_LOW = veafWeather.createStaticFog("Static MEDIUM LOW fog", 100, 500)
veafWeather.FOG_STATIC_SPARSE     = veafWeather.createStaticFog("Static SPARSE fog", 500, 5000)
veafWeather.FOG_STATIC_SPARSE_LOW = veafWeather.createStaticFog("Static SPARSE LOW fog", 100, 5000)
veafWeather.FOG_STATIC_NO         = veafWeather.createStaticFog("Static NO fog", 0, 0)

-- animated fog instances
for _, minutes in pairs({1, 5, 10, 15, 30, 60, 90}) do
    local overMinutesText = string.format(" over %d minutes", minutes)
    veafWeather["FOG_ANIMATED_"..minutes.."M_HEAVY"]      = veafWeather.createAnimatedFog("Animated HEAVY fog"..overMinutesText, minutes, 500, 100)
    veafWeather["FOG_ANIMATED_"..minutes.."M_MEDIUM"]     = veafWeather.createAnimatedFog("Animated MEDIUM fog"..overMinutesText, minutes, 500, 500)
    veafWeather["FOG_ANIMATED_"..minutes.."M_MEDIUM_LOW"] = veafWeather.createAnimatedFog("Animated MEDIUM LOW fog"..overMinutesText, minutes, 100, 500)
    veafWeather["FOG_ANIMATED_"..minutes.."M_SPARSE"]     = veafWeather.createAnimatedFog("Animated SPARSE fog"..overMinutesText, minutes, 500, 5000)
    veafWeather["FOG_ANIMATED_"..minutes.."M_SPARSE_LOW"] = veafWeather.createAnimatedFog("Animated SPARSE LOW fog"..overMinutesText, minutes, 100, 5000)
    veafWeather["FOG_ANIMATED_"..minutes.."M_NO"]         = veafWeather.createAnimatedFog("Animated NO fog"..overMinutesText, minutes, 0, 0)
end

---------------------------------------------------------------------------------------------------
---  Radio menu and remote interface
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafWeather.buildRadioMenu()
    veaf.loggers.get(veafWeather.Id):debug("buildRadioMenu()")

    veafWeather.rootPath = veafRadio.addMenu(veafWeather.RadioMenuName)
    veafRadio.addCommandToSubmenu("Weather on closest point" , veafWeather.rootPath, veafWeather.messageWeatherAtClosestPoint, nil, veafRadio.USAGE_ForGroup)
    veafRadio.addCommandToSubmenu("ATC on closest airbase" , veafWeather.rootPath, veafWeather.messageAtcClosestAirbase, nil, veafRadio.USAGE_ForGroup)
    veafRadio.addCommandToSubmenu("ATC and weather in one go" , veafWeather.rootPath, veafWeather.messageAtcAndWeather, nil, veafRadio.USAGE_ForGroup)

    local fogPath = veafRadio.addSubMenu("Fog settings", veafWeather.rootPath)

    local dynamicFogPath = veafRadio.addSubMenu("Dynamic fog", fogPath)
    veafRadio.addSecuredCommandToSubmenu(veafWeather.FOG_DYNAMIC_HEAVY.name, dynamicFogPath, veafWeather.setAndActivateFog, veafWeather.FOG_DYNAMIC_HEAVY, veafRadio.USAGE_ForAll)
    veafRadio.addSecuredCommandToSubmenu(veafWeather.FOG_DYNAMIC_MEDIUM.name, dynamicFogPath, veafWeather.setAndActivateFog, veafWeather.FOG_DYNAMIC_MEDIUM, veafRadio.USAGE_ForAll)
    veafRadio.addSecuredCommandToSubmenu(veafWeather.FOG_DYNAMIC_SPARSE.name, dynamicFogPath, veafWeather.setAndActivateFog, veafWeather.FOG_DYNAMIC_SPARSE, veafRadio.USAGE_ForAll)

    local animatedFogPath = veafRadio.addSubMenu("Animated fog", fogPath)
    for _, minutes in pairs({1, 5, 10, 15, 30, 60, 90}) do
        local overMinutesText = string.format(" over %d minutes", minutes)
        local _path = veafRadio.addSubMenu("Animated fog"..overMinutesText, animatedFogPath)
        veafRadio.addSecuredCommandToSubmenu(veafWeather["FOG_ANIMATED_"..minutes.."M_HEAVY"].name, _path, veafWeather.setAndActivateFog, veafWeather["FOG_ANIMATED_"..minutes.."M_HEAVY"], veafRadio.USAGE_ForAll)
        veafRadio.addSecuredCommandToSubmenu(veafWeather["FOG_ANIMATED_"..minutes.."M_MEDIUM"].name, _path, veafWeather.setAndActivateFog, veafWeather["FOG_ANIMATED_"..minutes.."M_MEDIUM"], veafRadio.USAGE_ForAll)
        veafRadio.addSecuredCommandToSubmenu(veafWeather["FOG_ANIMATED_"..minutes.."M_MEDIUM_LOW"].name, _path, veafWeather.setAndActivateFog, veafWeather["FOG_ANIMATED_"..minutes.."M_MEDIUM_LOW"], veafRadio.USAGE_ForAll)
        veafRadio.addSecuredCommandToSubmenu(veafWeather["FOG_ANIMATED_"..minutes.."M_SPARSE"].name, _path, veafWeather.setAndActivateFog, veafWeather["FOG_ANIMATED_"..minutes.."M_SPARSE"], veafRadio.USAGE_ForAll)
        veafRadio.addSecuredCommandToSubmenu(veafWeather["FOG_ANIMATED_"..minutes.."M_SPARSE_LOW"].name, _path, veafWeather.setAndActivateFog, veafWeather["FOG_ANIMATED_"..minutes.."M_SPARSE_LOW"], veafRadio.USAGE_ForAll)
        veafRadio.addSecuredCommandToSubmenu(veafWeather["FOG_ANIMATED_"..minutes.."M_NO"].name, _path, veafWeather.setAndActivateFog, veafWeather.FOG_ANIMATED_5_NO, veafRadio.USAGE_ForAll)
    end

    local staticFogPath = veafRadio.addSubMenu("Static fog", fogPath)
    veafRadio.addSecuredCommandToSubmenu(veafWeather.FOG_STATIC_HEAVY.name, staticFogPath, veafWeather.setAndActivateFog, veafWeather.FOG_STATIC_HEAVY, veafRadio.USAGE_ForAll)
    veafRadio.addSecuredCommandToSubmenu(veafWeather.FOG_STATIC_MEDIUM.name, staticFogPath, veafWeather.setAndActivateFog, veafWeather.FOG_STATIC_MEDIUM, veafRadio.USAGE_ForAll)
    veafRadio.addSecuredCommandToSubmenu(veafWeather.FOG_STATIC_MEDIUM_LOW.name, staticFogPath, veafWeather.setAndActivateFog, veafWeather.FOG_STATIC_MEDIUM_LOW, veafRadio.USAGE_ForAll)
    veafRadio.addSecuredCommandToSubmenu(veafWeather.FOG_STATIC_SPARSE.name, staticFogPath, veafWeather.setAndActivateFog, veafWeather.FOG_STATIC_SPARSE, veafRadio.USAGE_ForAll)
    veafRadio.addSecuredCommandToSubmenu(veafWeather.FOG_STATIC_SPARSE_LOW.name, staticFogPath, veafWeather.setAndActivateFog, veafWeather.FOG_STATIC_SPARSE_LOW, veafRadio.USAGE_ForAll)
    veafRadio.addSecuredCommandToSubmenu(veafWeather.FOG_STATIC_NO.name, staticFogPath, veafWeather.setAndActivateFog, veafWeather.FOG_STATIC_NO, veafRadio.USAGE_ForAll)
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
        veaf.loggers.get(veafWeather.Id):trace(string.format("_action=%s",veaf.p(_action)))
        veaf.loggers.get(veafWeather.Id):trace(string.format("_name=%s",veaf.p(_name)))
        veaf.loggers.get(veafWeather.Id):trace(string.format("_parameters=%s",veaf.p(_parameters)))
        if _action and _action:lower() == "weather" then
            veaf.loggers.get(veafWeather.Id):info(string.format("[%s] is requesting weather",veaf.p(_pilotName)))
            veafWeather.messageWeatherAtClosestPoint(_unitName, true)
            return true
        elseif _action and _action:lower() == "atc" then
            veaf.loggers.get(veafWeather.Id):info(string.format("[%s] is requesting atc",veaf.p(_pilotName)))
            veafWeather.messageAtcClosestAirbase(_unitName, true)
            return true
        elseif not _action or _action:lower() == "all" then
            veaf.loggers.get(veafWeather.Id):info(string.format("[%s] is requesting both atc and weather",veaf.p(_pilotName)))
            veafWeather.messageAtcAndWeather(_unitName, true)
            return true
        elseif _action and _action:lower() == "fog" then
            if _name then
                local uName = _name:upper()
                local fogObject = veafWeather[uName]
                if fogObject then
                    veaf.loggers.get(veafWeather.Id):info(string.format("[%s] is requesting fog [%s]",veaf.p(_pilotName), veaf.p(uName)))
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

function veafWeather.initialize()
    veaf.loggers.get(veafWeather.Id):debug("veafWeather.initialize()")
    veafWeather.buildRadioMenu()
    -- TODO veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafWeather.onEventMarkChange)
    veafAirbases.initialize()
end

veaf.loggers.get(veafWeather.Id):info(string.format("Loading version %s", veafWeather.Version))


-------------------- TEST STUFF------------------------------------
--[[
.getFogThickness=[function]
.getFogVisibilityDistance=[function]
.setFogAnimation=[function]
.setFogThickness=[function]
.setFogVisibilityDistance=[function]

veafAirbases.initialize()
for _, veafAirbase in pairs(veafAirbases.Airbases) do
    veaf.loggers.get(veafWeather.Id):trace(veafWeatherAtis.getAtisString(veafAirbase))
    veaf.loggers.get(veafWeather.Id):trace(veafWeatherData.getWeatherString(veafAirbase.DcsAirbase:getPoint()))
end
veaf.loggers.get(veafWeather.Id):trace(veaf.p(env.mission.weather.enable_fog))
veaf.loggers.get(veafWeather.Id):trace(veaf.p(world.weather.getFogVisibilityDistance()))
veaf.loggers.get(veafWeather.Id):trace(veaf.p(world.weather.getFogThickness()))
]]