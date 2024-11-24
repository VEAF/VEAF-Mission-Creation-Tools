------------------------------------------------------------------
-- VEAF weather information messages and markers
-- By Flogas (2024)
--
-- Features:
-- ---------
-- * Generation of weather messages and reports in different formats (METAR, ATIS)
-- * Generation of markers on the maps displaying the weather at the location
-- 
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafWeather = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global module settings
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafWeather.Id = "WEATHER_INFO"

--- Version.
veafWeather.Version = "1.0.0"

-- trace level, specific to this module
veafWeather.LogLevel = "trace" ----- TODO FG
veaf.loggers.new(veafWeather.Id, veafWeather.LogLevel)

veafWeather.Active = false

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
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local tools
-------------------------------------------------------------------------------------------------------------------------------------------------------------
local function _estimateClearSkyRelativeHumidity(nLatitude, nLongitude, iDayOfYear)
    -- Base RH for clear skies
    local base_rh = 30
    
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
    local adjusted_rh = base_rh + seasonal_adjustment + maritime_adjustment
    
    -- Clamp between reasonable values
    return math.max(20, math.min(70, adjusted_rh))
end

local function _adjustClearSkyRelativeHumidity(base_rh, iVisibilityMeters, bFog, bPrecipitations)
    local adjusted_rh = base_rh
    
    -- Visibility adjustments (visibility in meters)
    if iVisibilityMeters < 10000 then
        -- Increase RH as visibility decreases
        local visibility_factor = math.max(0, (10000 - iVisibilityMeters) / 10000)
        adjusted_rh = adjusted_rh + (visibility_factor * 20)  -- Up to +20% for low visibility
    end
    
    -- Fog adjustments
    if bFog then
        if iVisibilityMeters < 1000 then
            -- Dense fog
            adjusted_rh = 100  -- Fog implies saturation
        else
            -- Light fog/mist
            adjusted_rh = math.max(adjusted_rh, 90)  -- At least 90% RH with any fog
        end
    end
    
    -- Precipitation adjustments
    if (bPrecipitations) then
        adjusted_rh = math.max(adjusted_rh, 80)
    end
    
    -- Clamp final value
    return math.max(0, math.min(100, adjusted_rh))
end

local function _estimateDewpoint(vec3, nTemperatureCelcius, nQnhPa, iCloudBaseMeters, iVisibilityMeters, bFog, bPrecipitations, iAbsTime)
    local nLatitude, nLongitude, _ = coord.LOtoLL(vec3)
    local nQnhHpa = nQnhPa / 100
    local nRelativeHumidity
    
    if (iCloudBaseMeters == nil or iCloudBaseMeters > 10000) then
        -- Clear skies - estimate RH based on location and date
        local dateTime = veafTime.getMissionDateTime(iAbsTime)
        nRelativeHumidity = _estimateClearSkyRelativeHumidity(nLatitude, nLongitude, dateTime.yday)
    else
        -- Convert cloud base to meters and estimate RH
        nRelativeHumidity = 100 - (iCloudBaseMeters / 100)
        -- Clamp RH between 0 and 100%
        nRelativeHumidity = math.max(0, math.min(100, nRelativeHumidity))
    end
    
    nRelativeHumidity = _adjustClearSkyRelativeHumidity(nRelativeHumidity, iVisibilityMeters, bFog, bPrecipitations)

    -- Constants for Magnus formula
    local a = 17.27
    local b = 237.7
    
    -- Calculate gamma term
    local gamma = ((a * nTemperatureCelcius) / (b + nTemperatureCelcius)) + math.log(nRelativeHumidity/100.0)
    
    -- Calculate dew point using Magnus formula
    local dew_point = (b * gamma) / (a - gamma)
    
    -- Apply pressure correction (approximate)
    local pressure_correction = (1013.25 - nQnhHpa) * 0.0012
    dew_point = dew_point + pressure_correction
    
    -- Round to one decimal place
    return math.floor(dew_point * 10 + 0.5) / 10
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
    local bFog = env.mission.weather.enable_fog
    if (bFog) then
        -- ground + 75 meters seems to be the point where it can be counted as a real impact on visibility
        if(env.mission.weather.fog.thickness < iAltitudeMeters + 75) then
            bFog = false
        elseif (env.mission.weather.fog.visibility < iVisibilityMeters) then
            iVisibilityMeters = env.mission.weather.fog.visibility
        end
    end

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
    
    local _, nQfePa = atmosphere.getTemperatureAndPressure({ x = vec3.x, y = iAltitudeMeters, z = vec3.z })
    local nTemperatureKelvin, nQnhPa = atmosphere.getTemperatureAndPressure({ x = vec3.x, y = 0, z = vec3.z })
    local nTemperatureCelcius = nTemperatureKelvin + _nKelvinToCelciusOffset

    local this =
    {
        AbsTime = iAbsTime,
        Vec3 = vec3,
        AltitudeMeter = iAltitudeMeters,
        WindDirection = iWindDirSurface,
        WindSpeedMps = iWindSpeedSurfaceMps,
        VisibilityMeters = iVisibilityMeters,
        Dust = env.mission.weather.enable_dust,
        Fog = bFog,
        Clouds = clouds,
        Precipitation = bPrecipitation,
        TemperatureCelcius = nTemperatureCelcius,
        DewPointCelcius = _estimateDewpoint(vec3, nTemperatureCelcius, nQnhPa / 100, clouds.BaseMeters, iVisibilityMeters, bFog, bPrecipitation, iAbsTime),
        QnhHpa = nQnhPa / 100,
        QfeHpa = nQfePa / 100,
        Sunrise = sunTimes.Sunrise,
        Sunset = sunTimes.Sunset,

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

    if (bMagnetic) then
        iDirectionTrue = iDirectionTrue - veaf.getMagneticDeclination()
        if (iDirectionTrue) < 0 then
            iDirectionTrue = iDirectionTrue + 360
        end    
    end

    if (iDirectionTrue == 0) then
        iDirectionTrue = 360
    end

    return iDirectionTrue
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
    local iCloudHeightMeters = veafWeatherData:getNormalizedCloudBaseMeters(true)

    if (iCloudHeightMeters == nil or mist.utils.metersToFeet(iCloudHeightMeters) < 5000) then
        return false -- no clouds or cloud below 5000 ft
    else
       return (self.VisibilityMeters >= 10000 and not self.Precipitation and not self.Fog and not self.Dust)
    end
end

function veafWeatherData:getCarrierCase()
    -- Case I departures are flown during the day when weather conditions allow departure under visual flight rules (VFR). The weather minimums are a cloud deck above 3,000 feet and visibility greater than 5 miles
    -- Case II departures are flown during the day when visual conditions are present at the carrier, but a controlled climb through the clouds is required. The weather minimums are a cloud deck above 1,000 feet and visibility greater than 5 miles.
    -- Case III departures are flown at night and when weather conditions are below the minimums of 1,000 feet cloud deck and 5 miles visibility
    
    local bNight = veafTime.isAeronauticalNightFromAbsTime(self.Vec3, self.AbsTime)
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

    if (self.Fog) then
        sVisibility = sVisibility .. " - fog"
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
        
        if (iCloudBaseMeters ~= nil) then
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

function veafWeatherData:toStringSunTime(dateTime, bZulu, bLocal)
    local sLocal = ""
    if (bLocal) then
        sLocal = string.format("%sL", veafTime.toStringTime(dateTime, false))
    end 

    local sZulu = ""
    if (bZulu) then
        local dateTimeZulu = veafTime.toZulu(dateTime)
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

function veafWeatherData:toStringLasteOld()
    local function getLASTEat(vec3, alt)
        local T,_=atmosphere.getTemperatureAndPressure({x=vec3.x, y=alt, z=vec3.z})
        local Dir,Vel=weathermark._GetWind(vec3, alt)
        local laste = string.format("\nFL%02d W%03d/%02d T%d", alt * weathermark.meter2feet / 1000, Dir, Vel * weathermark.mps2knots, T-273.15)
        return laste
    end

    local text = ""
    text=text..getLASTEat(self.Vec3, math.floor(((self.AltitudeMeter * weathermark.meter2feet + 2000)/1000)*1000+500)/weathermark.meter2feet)
    text=text..getLASTEat(self.Vec3, math.floor(((self.AltitudeMeter * weathermark.meter2feet + 8000)/1000)*1000+500)/weathermark.meter2feet)
    text=text..getLASTEat(self.Vec3, math.floor(((self.AltitudeMeter * weathermark.meter2feet + 16000)/1000)*1000+500)/weathermark.meter2feet)
    --text=text..getLASTEat(vec3, _Alt + 7500)
    return text
end

function veafWeatherData:toStringLaste()
    local function getLASTEat(iHeightFeet)
        local iAltitudeMeters = mist.utils.feetToMeters(iHeightFeet) + self.AltitudeMeter
        local iTemperatureKelvin, _ = atmosphere.getTemperatureAndPressure({ x = self.Vec3.x, y = iAltitudeMeters, z = self.Vec3.z })
        local iWindDirection, iWindSpeedMps = weathermark._GetWind(self.Vec3, iAltitudeMeters)
        local sAltitudeFl = _getFlightLevelString(mist.utils.metersToFeet(iAltitudeMeters))

        local sLaste = string.format("%s W%03d/%02d T%d", sAltitudeFl, iWindDirection, mist.utils.mpsToKnots(iWindSpeedMps), iTemperatureKelvin + _nKelvinToCelciusOffset)
        return sLaste
    end

    local sLaste = ""
    sLaste = sLaste .. string.format("\n%s", getLASTEat(2000))
    sLaste = sLaste .. string.format("\n%s", getLASTEat(8000))
    sLaste = sLaste .. string.format("\n%s", getLASTEat(16000))

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
    sString = sString .. string.format("\nSunrise:       %s", self:toStringSunTime(self.Sunrise, true, true))
    sString = sString .. string.format("\nSunset:       %s", self:toStringSunTime(self.Sunset, true, true))
    
    if(bWithLaste) then
        sString = sString .. "\n"
        sString = sString .. string.format("\nLASTE:%s", self:toStringLaste())
        --sString = sString .. string.format("\nLASTE OLD:%s", self:toStringLasteOld())
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
        sAtis = sAtis .. string.format("\nSunrise %s", self:toStringSunTime(self.Sunrise, true, false))
    else
        sAtis = sAtis .. string.format("\nSunset %s", self:toStringSunTime(self.Sunset, true, false))
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
veafWeatherAtis.__index = FgAtis
veafWeatherAtis.ListInEffect = {}
---------------------------------------------------------------------------------------------------
---  CTORS
function veafWeatherAtis:Create(dcsAirbase, sLetter, dateTimeZulu)
    local iRecordedAtMinutes = math.random(2, 11) -- ATIS recorded between h:02 and hour:11
    if (iRecordedAtMinutes > dateTimeZulu.min) then
        -- if record is in the future set recording at the request time
        iRecordedAtMinutes = dateTimeZulu.min
    end
    dateTimeZulu.min = iRecordedAtMinutes

    local sMessage = string.format("%s information %s, recorded at %sZ", dcsAirbase:getName(), sLetter, veafTime.toStringTime(dateTimeZulu, false))
    -- TODO sMessage = sMessage .. string.format("\nRunway in use %s", "XX")     ----https://wiki.hoggitworld.com/view/DCS_Class_Airbase

    local iAltitude = nil
    if (dcsAirbase:getCategory() == Airbase.Category.SHIP) then
        iAltitude = 20
    end

    local unitSystem = veafWeatherUnitSystem.defaultForTheatre()
    local weatherData = veafWeatherData:create(dcsAirbase:getPoint(), iAltitude)
    sMessage = sMessage .. "\n" .. weatherData:toStringAtis(unitSystem)

    local this =
    {
        AirbaseName = dcsAirbase:getName(),
        Letter = sLetter,
        DateTimeZulu = dateTimeZulu,
        Message = sMessage
    }

    setmetatable(this, self)
    return this
end

---------------------------------------------------------------------------------------------------
---  METHODS
   --[[
function veafWeatherAtis.getAirportsRunways()
    local airBases = world.getAirbases()
    for i = 1, #airBases do
        local dcsAirbase = airBases[i]
        veafWeatherAtis.getRunways(dcsAirbase)
    end

    return true
end

function veafWeatherAtis.getRunways(dcsAirbase)
    if (dcsAirbase == nil) then
        return nil
    end
    
    local _, iCategory = dcsAirbase:getCategory()
    if (iCategory ~= Airbase.Category.AIRDROME) then
        return nil
    end
    
    veaf.loggers.get(veafWeather.Id):trace("Airbase=" .. dcsAirbase:getName())
    local runways = {}
  
    local dcsRunways = dcsAirbase:getRunways()
    for _, dcsRunway in pairs(dcsRunways) do
        local iNumber = dcsRunway.Name
        local iCourseRadian = dcsRunway.course

        local iHeadingFromCourseDegrees = math.deg(-iCourseRadian)
        local iHeaderFromNumberDegrees = iNumber * 10
        
        veaf.loggers.get(veafWeather.Id):trace("--> " .. veaf.p(dcsRunway.Name))
        veaf.loggers.get(veafWeather.Id):trace("--> " .. dcsRunway.course)
        veaf.loggers.get(veafWeather.Id):trace("--> " .. iHeadingFromCourseDegrees)
        veaf.loggers.get(veafWeather.Id):trace("--> " .. iHeaderFromNumberDegrees)
        
        
    end
 Function to create a runway data table.
    local function _createRunway(name, course, width, length, center)
  
 
  

  
      if self.AirbaseName == AIRBASE.Syria.Beirut_Rafic_Hariri and math.abs(namefromheading-name) > 1 then
        runway.name=string.format("%02d", tonumber(namefromheading))
      else
       runway.name=string.format("%02d", tonumber(name))
      end
  
      --runway.name=string.format("%02d", tonumber(name))
      runway.magheading=tonumber(runway.name)*10
      runway.heading=heading
      runway.width=width or 0
      runway.length=length or 0
      runway.center=COORDINATE:NewFromVec3(center)
  
      -- Ensure heading is [0,360]
      if runway.heading>360 then
        runway.heading=runway.heading-360
      elseif runway.heading<0 then
        runway.heading=runway.heading+360
      end
  
      -- For example at Nellis, DCS reports two runways, i.e. 03 and 21, BUT the "course" of both is -0.700 rad = 40 deg!
      -- As a workaround, I check the difference between the "magnetic" heading derived from the name and the true heading.
      -- If this is too large then very likely the "inverse" heading is the one we are looking for.
      if math.abs(runway.heading-runway.magheading)>60 then
        self:T(string.format("WARNING: Runway %s: heading=%.1f magheading=%.1f", runway.name, runway.heading, runway.magheading))
        runway.heading=runway.heading-180
      end
  
      -- Ensure heading is [0,360]
      if runway.heading>360 then
        runway.heading=runway.heading-360
      elseif runway.heading<0 then
        runway.heading=runway.heading+360
      end
  
      -- Start and endpoint of runway.
      runway.position=runway.center:Translate(-runway.length/2, runway.heading)
      runway.endpoint=runway.center:Translate( runway.length/2, runway.heading)
  
      local init=runway.center:GetVec3()
      local width = runway.width/2
      local L2=runway.length/2
  
      local offset1 = {x = init.x + (math.cos(bearing + math.pi) * L2), y = init.z + (math.sin(bearing + math.pi) * L2)}
      local offset2 = {x = init.x - (math.cos(bearing + math.pi) * L2), y = init.z - (math.sin(bearing + math.pi) * L2)}
  
      local points={}
      points[1] = {x = offset1.x + (math.cos(bearing + (math.pi/2)) * width), y = offset1.y + (math.sin(bearing + (math.pi/2)) * width)}
      points[2] = {x = offset1.x + (math.cos(bearing - (math.pi/2)) * width), y = offset1.y + (math.sin(bearing - (math.pi/2)) * width)}
      points[3] = {x = offset2.x + (math.cos(bearing - (math.pi/2)) * width), y = offset2.y + (math.sin(bearing - (math.pi/2)) * width)}
      points[4] = {x = offset2.x + (math.cos(bearing + (math.pi/2)) * width), y = offset2.y + (math.sin(bearing + (math.pi/2)) * width)}
  
      -- Runway zone.
      runway.zone=ZONE_POLYGON_BASE:New(string.format("%s Runway %s", self.AirbaseName, runway.name), points)
  
      return runway
    end
  
  
    -- Get DCS object.
    local airbase=self:GetDCSObject()
  
    if airbase then
  
  
      -- Get DCS runways.
      local runways=airbase:getRunways()
  
      -- Debug info.
      self:T2(runways)
  
      if runways then
  
        -- Loop over runways.
        for _,rwy in pairs(runways) do
  
          -- Debug info.
          self:T(rwy)
  
          -- Get runway data.
          local runway=_createRunway(rwy.Name, rwy.course, rwy.width, rwy.length, rwy.position) --#AIRBASE.Runway
  
          -- Add to table.
          table.insert(Runways, runway)
  
          -- Include "inverse" runway.
          if IncludeInverse then
  
            -- Create "inverse".
            local idx=tonumber(runway.name)
            local name2=tostring(idx-18)
            if idx<18 then
              name2=tostring(idx+18)
            end
  
            -- Create "inverse" runway.
            local runway=_createRunway(name2, rwy.course-math.pi, rwy.width, rwy.length, rwy.position) --#AIRBASE.Runway
  
            -- Add inverse to table.
            table.insert(Runways, runway)
  
          end
  
        end
  
      end
  
    end
  
    -- Look for identical (parallel) runways, e.g. 03L and 03R at Nellis.
    local rpairs={}
    for i,_ri in pairs(Runways) do
      local ri=_ri --#AIRBASE.Runway
      for j,_rj in pairs(Runways) do
        local rj=_rj --#AIRBASE.Runway
        if i<j then
          if ri.name==rj.name then
            rpairs[i]=j
          end
        end
      end
    end
  
    local function isLeft(a, b, c)
      --return ((b.x - a.x)*(c.z - a.z) - (b.z - a.z)*(c.x - a.x)) > 0
      return ((b.z - a.z)*(c.x - a.x) - (b.x - a.x)*(c.z - a.z)) > 0
    end
  
    for i,j in pairs(rpairs) do
      local ri=Runways[i] --#AIRBASE.Runway
      local rj=Runways[j] --#AIRBASE.Runway
  
      -- Draw arrow.
      --ri.center:ArrowToAll(rj.center)
  
      local c0=ri.center
  
      -- Vector in the direction of the runway.
      local a=UTILS.VecTranslate(c0, 1000, ri.heading)
  
      -- Vector from runway i to runway j.
      local b=UTILS.VecSubstract(rj.center, ri.center)
      b=UTILS.VecAdd(ri.center, b)
  
      -- Check if rj is left of ri.
      local left=isLeft(c0, a, b)
  
      --env.info(string.format("Found pair %s: i=%d, j=%d, left==%s", ri.name, i, j, tostring(left)))
  
      if left then
        ri.isLeft=false
        rj.isLeft=true
      else
        ri.isLeft=true
        rj.isLeft=false
      end
  
      --break
    end
  
    -- Set runways.
    self.runways=Runways
  
    return Runways

  end
      ]]
---------------------------------------------------------------------------------------------------
---  Static methods
function veafWeatherAtis.getAtisString(dcsAirbase, iAbsTime)
    local dateTimeZulu = veafTime.toZulu(veafTime.getMissionDateTime(iAbsTime))
     local iHoursSinceMidnight = dateTimeZulu.hour
    local sLetter = string.char(math.floor(iHoursSinceMidnight) + string.byte("A"))

    veaf.loggers.get(veafWeather.Id):trace("Zulu hours=" .. iHoursSinceMidnight .. " - Letter=" .. sLetter)

     -- There is no need to check more that the letter since that weather is static and the conditions will not vary
     -- If they did though, we would have to check that the letter is not for 24h or more later, and so warrant a new weather evaluation
    local currentInEffect = veafWeatherAtis.ListInEffect[dcsAirbase:getName()]
    if (currentInEffect and currentInEffect.Letter == sLetter) then
        return currentInEffect.Message
    else
        currentInEffect = veafWeatherAtis:Create(dcsAirbase, sLetter, dateTimeZulu)
        veafWeatherAtis.ListInEffect[dcsAirbase:getName()] = currentInEffect
        return currentInEffect.Message
    end
end

function veafWeatherAtis.getAtisStringFromVeafPoint(sPointName, iAbsTime)
    --[[
    if (veafWeatherAtis.getAirportsRunways()) then
        return
    end
    ]]
    if (veaf.isNullOrEmpty(sPointName)) then
        veaf.loggers.get(veafWeather.Id):error("No point name")
        return "No airbase name"
    end

     ----- TODO FG maybe have to account for FARPs and CV and such
    local dcsAirbase = veafNamedPoints.findDcsAirbase(sPointName)
    if (dcsAirbase == nil) then
        veaf.loggers.get(veafWeather.Id):error("Airbase not found for point " .. sPointName)
        return "Airbase not found for point " .. sPointName
    end

    veaf.loggers.get(veafWeather.Id):trace("Airbase found from veaf point " .. sPointName .. ": " .. dcsAirbase:getName())    
    return veafWeatherAtis.getAtisString(dcsAirbase, iAbsTime)
end
