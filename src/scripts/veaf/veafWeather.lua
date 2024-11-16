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
veafWeather.LogLevel = "trace" -- TODO
veaf.loggers.new(veafWeather.Id, veafWeather.LogLevel)

veafWeather.UnitSystem =
{
    Full = 0, -- all measures presented in imperial and metric units
    Imperial = 1, -- Wind speeds in knots, visibilities in SM, altitudes in feet
    Metric = 2, -- Wind speeds in km/h, visibilities in km, altitudes in meters
    Hybrid = 3,  -- Wind speeds in knots, visibilities in km, altitudes in feet
}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------
local _dcsPresetDensity =
{
    -- {density, precipitation, visibility}
    Preset1 = {2, false, nil}, -- LS1 -- FEW/SCT
    Preset2 = {2, false, nil}, -- LS2 -- FEW/SCT
    Preset3 = {3, false, nil}, -- HS1 -- SCT
    Preset4 = {3, false, nil}, -- HS2 -- SCT
    Preset5 = {3, false, nil}, -- S1 -- SCT
    Preset6 = {4, false, nil}, -- S2 -- SCT/BKN
    Preset7 = {3, false, nil}, -- S3 -- BKN
    Preset8 = {4, false, nil}, -- HS3 -- SCT/BKN
    Preset9 = {5, false, nil}, -- S4 -- BKN
    Preset10 = {4, false, nil}, -- S5 -- SCT/BKN
    Preset11 = {6, false, nil}, -- S6 -- BKN
    Preset12 = {6, false, nil}, -- S7 -- BKN
    Preset13 = {6, false, nil}, -- B1 -- BKN
    Preset14 = {6, false, nil}, -- B2 -- BKN
    Preset15 = {4, false, nil}, -- B3 -- SCT/BKN
    Preset16 = {6, false, nil}, -- B4 -- BKN
    Preset17 = {7, false, nil}, -- B5 -- BKN/OVC
    Preset18 = {7, false, nil}, -- B6 -- BKN/OVC
    Preset19 = {8, false, nil}, -- B7 -- OVC
    Preset20 = {7, false, nil}, -- B8 -- BKN/OVC
    Preset21 = {7, false, nil}, -- O1 -- BKN/OVC
    Preset22 = {6, false, nil}, -- O2 -- BKN
    Preset23 = {6, false, nil}, -- O3  -- BKN
    Preset24 = {7, false, nil}, -- O4 -- BKN/OVC
    Preset25 = {8, false, nil}, -- O5 -- OVC
    Preset26 = {8, false, nil}, -- O6 -- OVC
    Preset27 = {8, false, nil}, -- O7 -- OVC
    RainyPreset1 = {8, true, 4000}, -- OVC
    RainyPreset2 = {7, true, 5000}, -- BKN/OVC
    RainyPreset3 = {8, true, 4000} -- OVC
}

local _cloudDensity = { Clear = 0, Few = 1, Scattered = 2, Broken = 3, Overcast = 4, Cavok = 5 }
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
    local iWindDir, iWindSpeedMs = weathermark._GetWind(vec3, iAltitudeMeters)

    return
    {
        AltitudeMeters = iAltitudeMeters,
        PressureHpa = nPressurePa / 100,
        TemperatureCelcius = nTemperatureKelvin + _nKelvinToCelciusOffset,
        WindDirection = iWindDir,
        WindSpeedMs = iWindSpeedMs
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
---  Weather management class
---  Collects and compile wheather data form various sources in the sim at a location
---  Can be output to string as METAR or ATIS informations
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
veafWeatherData = {}
veafWeatherData.__index = veafWeatherData

---------------------------------------------------------------------------------------------------
---  CTOR
function veafWeatherData:create(vec3, iAbsTime)
    iAbsTime = iAbsTime or timer.getAbsTime()
        
    local iGroundAltitudeMeters = veaf.getLandHeight(vec3)
    local sunTimes = veafTime.getSunTimes(vec3)
    local iWindDirSurface, iWindSpeedSurfaceMs = weathermark._GetWind(vec3, iGroundAltitudeMeters + 10) -- Measure the wind velocity at the standard height of 10 metres above the surface. This is the internationally accepted meteorological definition of ‘surface wind’ designed to eliminate distortion attributable to very local terrain effects

    local iVisibilityMeters = env.mission.weather.visibility.distance
    local bFog = env.mission.weather.enable_fog
    if (bFog) then
        -- ground + 75 meters seems to be the point where it can be counted as a real impact on visibility
        if(env.mission.weather.fog.thickness < iGroundAltitudeMeters + 75) then
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
    
    local _, nQfePa = atmosphere.getTemperatureAndPressure({ x = vec3.x, y = iGroundAltitudeMeters, z = vec3.z })
    local nTemperatureKelvin, nQnhPa = atmosphere.getTemperatureAndPressure({ x = vec3.x, y = 0, z = vec3.z })
    local nTemperatureCelcius = nTemperatureKelvin + _nKelvinToCelciusOffset

    local this =
    {
        AbsTime = iAbsTime,
        Vec3 = vec3,
        AltitudeMeter = iGroundAltitudeMeters,
        WindDirection = iWindDirSurface,
        WindSpeedMs = iWindSpeedSurfaceMs,
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

    veaf.loggers.get(veafWeather.Id):trace(this:toStringExtended(veafWeather.UnitSystem.Hybrid, true))
    veaf.loggers.get(veafWeather.Id):trace(this:toStringExtended(veafWeather.UnitSystem.Metric, true))
    veaf.loggers.get(veafWeather.Id):trace(this:toStringExtended(veafWeather.UnitSystem.Imperial, true))
    return this
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
    if (iCloudBase == nil or self.Clouds.Density <= 0) then
        return _cloudDensity.Clear
    else
        iCloudBase = mist.utils.round(iCloudBase / 100) * 100
        if (self.VisibilityMeters >= 10000 and self.Clouds.BaseMeters >= 5000 and not self.Precipitation and not self.Fog and not self.Dust) then
            return _cloudDensity.Cavok
        else
            return _cloudDensityOktas[self.Clouds.Density], iCloudBase
        end
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
function veafWeatherData:toStringWind(unitSystem, iDirection, nSpeedMs, bMagnetic)
    unitSystem = unitSystem or veafWeather.UnitSystem.Hybrid

    local iDirection = self:getNormalizedWindDirection(iDirection, bMagnetic)
    local sSpeedImperial = string.format("%d kts", mist.utils.mpsToKnots(nSpeedMs))
    local sSpeedMetric = string.format("%d km/h", mist.utils.mpsToKmph(nSpeedMs))
    local s

    if (unitSystem == veafWeather.UnitSystem.Metric) then
        s = string.format("%03d @ %s", iDirection, sSpeedMetric)
    elseif (unitSystem == veafWeather.UnitSystem.Hybrid or unitSystem == veafWeather.UnitSystem.Imperial) then
        s = string.format("%03d @ %s", iDirection, sSpeedImperial)
    else
        s = string.format("%03d @ %s/%s", iDirection, sSpeedImperial, sSpeedMetric)
    end

    return s
end

function veafWeatherData:toStringVisibility(unitSystem)
    unitSystem = unitSystem or veafWeather.UnitSystem.Hybrid

    local sVisibilityImperial = string.format("%d SM", mist.utils.round(self.VisibilityMeters * 0.000621371))
    local sVisibilityMetric = string.format("%d km", mist.utils.round(self.VisibilityMeters / 1000))
    local s   
    
    if (unitSystem == veafWeather.UnitSystem.Imperial) then
        s = sVisibilityImperial
    elseif (unitSystem == veafWeather.UnitSystem.Hybrid or unitSystem == veafWeather.UnitSystem.Metric) then
        s = sVisibilityMetric
    else
        s = string.format("%s/%s", sVisibilityMetric, sVisibilityImperial)
    end

    if (self.Fog) then
        s = s .. " - fog"
    end
    if (self.Dust) then
        s = s .. " - dust"
    end
    if (self.Precipitation) then
        s = s .. " - precipitations"
    end

    return s
end

function veafWeatherData:toStringClouds(unitSystem, bHeight)
    unitSystem = unitSystem or veafWeather.UnitSystem.Hybrid
    bHeight = bHeight or false

    local cloudDensity = self:getNormalizedCloudsDensity()
    local iCloudBaseMeters = self:getNormalizedCloudBaseMeters(bHeight)

    local sCloudDensity = ""
    local sCloudBase = ""

    if (cloudDensity == _cloudDensity.Clear) then
        sCloudDensity = "No clouds"
    elseif (cloudDensity == _cloudDensity.Cavok) then
        sCloudDensity = "CAVOK"
    else
        if (cloudDensity == _cloudDensity.Scattered) then
            sCloudDensity = "Scattered"
        elseif (cloudDensity == _cloudDensity.Broken) then
            sCloudDensity = "Broken"
        elseif (cloudDensity == _cloudDensity.Overcast) then
            sCloudDensity = "Overcast"
        else
            sCloudDensity = "Few"
        end
        
        if (iCloudBaseMeters ~= nil) then
            local sCloudBaseImperial = string.format("%d ft", mist.utils.metersToFeet(iCloudBaseMeters))
            local sCloudBaseMetric = string.format("%d m", iCloudBaseMeters)

            if (unitSystem == veafWeather.UnitSystem.Imperial) then
                sCloudBase = string.format(" @ %s", sCloudBaseImperial)
            elseif (unitSystem == veafWeather.UnitSystem.Hybrid or unitSystem == veafWeather.UnitSystem.Metric) then
                sCloudBase = string.format(" @ %s", sCloudBaseMetric)
            else
                sCloudBase = string.format("%s/%s", sCloudBaseImperial, sCloudBaseMetric)
            end

            if (bHeight) then
                sCloudBase = sCloudBase .. " AGL"
            else
                sCloudBase = sCloudBase .. " ASL"
            end
        end
    end

    return string.format("%s%s", sCloudDensity, sCloudBase) 
end

function veafWeatherData:toStringTemperature(unitSystem, nTemperatureCelcius)
    unitSystem = unitSystem or veafWeather.UnitSystem.Hybrid

    local sTemperatureImperial = string.format("%d°F", mist.utils.round(mist.utils.celsiusToFahrenheit(nTemperatureCelcius)))
    local sTemperatureMetric = string.format("%d°C", mist.utils.round(nTemperatureCelcius))
    local s 

    if (unitSystem == veafWeather.UnitSystem.Imperial) then
        s = sTemperatureImperial
    elseif (unitSystem == veafWeather.UnitSystem.Hybrid or unitSystem == veafWeather.UnitSystem.Metric) then
        s = sTemperatureMetric
    else
        s = string.format("%s/%s", sTemperatureMetric, sTemperatureImperial)
    end

    return s
end

function veafWeatherData:toStringPressure(nPressureHpa)
    return string.format("%.0f Hpa - %.2f inHg", nPressureHpa, mist.utils.converter("hpa", "inhg", nPressureHpa))
end

function veafWeatherData:toStringSunTime(dateTime)
    local dateTimeZulu = veafTime.toZulu(dateTime)
    return string.format("%sZ - %sL", veafTime.toStringTime(dateTimeZulu, false), veafTime.toStringTime(dateTime, false))
end

function veafWeatherData:toStringSlice(weatherSlice, unitSystem, bMagnetic)
    unitSystem = unitSystem or veafWeather.UnitSystem.Hybrid

    local sAltitudeMetric = string.format("%d m", weatherSlice.AltitudeMeters)
    local sAltitudeImperial = _getFlightLevelString(mist.utils.metersToFeet(weatherSlice.AltitudeMeters))
    local sAltitude
    if (unitSystem == veafWeather.UnitSystem.Imperial or unitSystem == veafWeather.UnitSystem.Hybrid) then
        sAltitude = sAltitudeImperial
    elseif (unitSystem == veafWeather.UnitSystem.Metric) then
        sAltitude = sAltitudeMetric
    else
        sAltitude = string.format("%s | %s", sAltitudeImperial, sAltitudeMetric)
    end

    local sTemperature = self:toStringTemperature(unitSystem, weatherSlice.TemperatureCelcius)
    local sPressure = self:toStringPressure(weatherSlice.PressureHpa)
    local sWind = self:toStringWind(unitSystem, weatherSlice.WindDirection, weatherSlice.WindSpeedMs, bMagnetic)

    return string.format("%s:  %s | %s | %s", sAltitude, sTemperature, sPressure, sWind)
end


function veafWeatherData:toString(unitSystem)
    unitSystem = unitSystem or veafWeather.UnitSystem.Hybrid
    bHeight = bHeight or false

    local sString = ""
    sString = sString .. string.format("Wind:          %s", self:toStringWind(unitSystem, self.WindDirection, self.WindSpeedMs))
    sString = sString .. string.format("\nVisibility:    %s", self:toStringVisibility(unitSystem))
    sString = sString .. string.format("\nClouds:        %s", self:toStringClouds(unitSystem, true))
    sString = sString .. string.format("\nTemperature:   %s - Dew point: %s", self:toStringTemperature(unitSystem, self.TemperatureCelcius), self:toStringTemperature(unitSystem, self.DewPointCelcius))
    sString = sString .. string.format("\nQNH:           %s", self:toStringPressure(self.QnhHpa))
    sString = sString .. string.format("\nQFE:           %s", self:toStringPressure(self.QfeHpa))
    sString = sString .. string.format("\nSunrise:       %s", self:toStringSunTime(self.Sunrise))
    sString = sString .. string.format("\nSunrise:       %s", self:toStringSunTime(self.Sunset))
    sString = sString .. "\n"
    sString = sString .. string.format("\n> %s", self:toStringSlice(self.WeatherAt500, unitSystem))
    sString = sString .. string.format("\n> %s", self:toStringSlice(self.WeatherAt2000, unitSystem))
    sString = sString .. string.format("\n> %s", self:toStringSlice(self.WeatherAt8000, unitSystem))

    return sString
end

function veafWeatherData:toStringExtended(unitSystem, bHeight)
    unitSystem = unitSystem or veafWeather.UnitSystem.Hybrid

    local sAltitudeImperial = string.format("%d ft", mist.utils.round(mist.utils.metersToFeet(self.AltitudeMeter)))
    local sAltitudeMetric = string.format("%d m", mist.utils.round(self.AltitudeMeter))
    local sAltitude

    if (unitSystem == veafWeather.UnitSystem.Imperial) then
        sAltitude = sAltitudeImperial
    elseif (unitSystem == veafWeather.UnitSystem.Hybrid or unitSystem == veafWeather.UnitSystem.Metric) then
        sAltitude = sAltitudeMetric
    else
        sAltitude = string.format("%s/%s", sAltitudeImperial, sAltitudeMetric)
    end

    local nLatitude, nLongitude = coord.LOtoLL(self.Vec3)
    
    local sString = ""
    sString = sString .. string.format("Time:          %s", veafTime.absTimeToStringDateTime(self.AbsTime))
    sString = sString .. string.format("\nLocation:      %s", mist.tostringLL(nLatitude, nLongitude, 0, true))
    sString = sString .. string.format("\nAltitude:      %s", sAltitude)
    sString = sString .. "\n" .. self:toString(unitSystem, bHeight)
    return sString    
end
--[[
----https://wiki.hoggitworld.com/view/DCS_Class_Airbase
function veafWeatherData:toStringAtis()
    local iWindForce, iWindDirection = self:GetFormattedWind(true)
    local sWind
    if (iWindForce <= 1) then
        sWind = "Wind calm"
    else
        iWindDirection = UTILS.Round(iWindDirection / 5) * 5
        sWind = string.format("Wind %03d @ %d kt", iWindDirection, iWindForce)
    end

    local iVisibility = UTILS.Round(self.VisibilityMeters / 1000)
    if (iVisibility > 10) then
        iVisibility = 10
    end
    local sVisibility = string.format("Visibility %d km", iVisibility)

    if (self.Precipitation) then
        sVisibility = sVisibility .. " Rain" -- TODO rain will be snow if season+map+t° ?
    end
    if (self.Fog) then
        sVisibility = sVisibility .. " Fog"
    end
    if (self.Dust) then
        sVisibility = sVisibility .. " Dust"
    end

    local sClouds
    local cloudDensity, iCloudBase = self:GetFormattedClouds(true)
    if (cloudDensity == CloudDensityLabel.Clear) then
        sClouds = "No clouds"
    elseif (cloudDensity == CloudDensityLabel.Cavok) then
        sClouds = "CAVOK"
        sVisibility = nil
    else
        local sDensity = "Few"
        if (cloudDensity == CloudDensityLabel.Scattered) then
            sDensity = "Scattered"
        elseif (cloudDensity == CloudDensityLabel.Broken) then
            sDensity = "Broken"
        elseif (cloudDensity == CloudDensityLabel.Overcast) then
            sDensity = "Overcast"
        end
           
        sClouds = sDensity .. " clouds @ " .. iCloudBase .. " feet"
    end

    local sAtis = sWind
    sAtis = Fg.AppendWithSeparator (sAtis, sVisibility, "\n")
    sAtis = sAtis .. "\n" .. sClouds
    sAtis = sAtis .. "\nTemperature " .. UTILS.Round(self.TemperatureCelcius) .. " °C"
    sAtis = sAtis .. string.format("\nQNH %d hPa - %.2f inHg", self.QnhHpa, UTILS.hPa2inHg(self.QnhHpa))
    sAtis = sAtis .. string.format("\nQFE %d hPa - %.2f inHg", self.QfeHpa, UTILS.hPa2inHg(self.QfeHpa))
    
    if (self.AbsTime < self.Sunrise or self.AbsTime > self.Sunset) then
        local iSunriseZulu = Fg.TimeToZulu(self.Sunrise)
        sAtis = sAtis .. "\nSunrise " .. Fg.TimeToString(iSunriseZulu, false) .. "Z"
    else
        local iSunsetZulu = Fg.TimeToZulu(self.Sunset)
        sAtis = sAtis .. "\nSunset " .. Fg.TimeToString(iSunsetZulu, false) .. "Z"
    end

    return sAtis
end

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

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  ATIS management class
---  Simulation of the recording of an ATIS information per hour per airfield
---  For each info a recording time and corresponding letter is generated (just to fluff it)
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
FgAtis = {}
FgAtis.__index = FgAtis
FgAtis.ListInEffect = {}
---------------------------------------------------------------------------------------------------
---  CTORS
function FgAtis:Create(mooseAirbase, sLetter, iZuluHoursSinceMidnight)
    local this = {
        AirbaseName = mooseAirbase.AirbaseName,
        Letter = sLetter,
        Message = ""
    }

    local iRecordedAt = math.floor(iZuluHoursSinceMidnight) + math.random(2, 11) / 60
    if (iRecordedAt > iZuluHoursSinceMidnight) then
        iRecordedAt = iZuluHoursSinceMidnight - math.random(2, 11) / 60
    end

    this.Message =
        mooseAirbase.AirbaseName ..
        " information " .. sLetter .. " recorded at " .. Fg.TimeToString(iRecordedAt * 3600, false) .. "Z"

    local mooseRunway = mooseAirbase:GetActiveRunway()
    if (mooseRunway) then
        this.Message = this.Message .. "\nRunway in use " .. mooseRunway.name        
    end

    local iAltitude = nil
    if (mooseAirbase:IsShip()) then
        iAltitude = 20
    end
    local weatherReport = FgWeather:Create(mooseAirbase:GetCoordinate(), nil, iAltitude)
    this.Message = this.Message .. "\n" .. weatherReport:ToStringAtis()

    setmetatable(this, self)
    return this
end

---------------------------------------------------------------------------------------------------
---  METHODS
function FgAtis.GetCurrentAtisString(sAirbaseName)
    if (Fg.IsNullOrEmpty(sAirbaseName)) then
        LogError("FgAtis : no airbase name given")
        return ""
    end

    local mooseAirbase = AIRBASE:FindByName(sAirbaseName)
    if (mooseAirbase == nil) then
        LogError("FgAtis : airbase " .. sAirbaseName .. " not found")
        return ""
    end

    local time = Fg.TimeFromAbsSeconds(Fg.TimeToZulu())
    local iZuluHoursSinceMidnight = time.Hour
    local sLetter = string.char(math.floor(iZuluHoursSinceMidnight) + string.byte("A"))

    LogDebug("Zulu hours=" .. iZuluHoursSinceMidnight .. " - Letter=" .. sLetter)

    local currentInEffect = FgAtis.ListInEffect[mooseAirbase.AirbaseName]
    if (currentInEffect and currentInEffect.Letter == sLetter) then
        LogDebug("ATIS already in effect")
        return currentInEffect.Message
    else
        LogDebug("New recorded ATIS")
        currentInEffect = FgAtis:Create(mooseAirbase, sLetter, iZuluHoursSinceMidnight)
        FgAtis.ListInEffect[sAirbaseName] = currentInEffect
    end

    return currentInEffect.Message
end

function FgAtis.GetCurrentAtisStringNearest(mooseGroup)
	local mooseAirbase = Fg.GetNearestAirbase(mooseGroup)
	return FgAtis.GetCurrentAtisString(mooseAirbase.AirbaseName)
end
]]