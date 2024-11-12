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

veafWeatherInfo = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global module settings
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafWeatherInfo.Id = "WEATHER_INFO"

--- Version.
veafWeatherInfo.Version = "1.0.0"

-- trace level, specific to this module
--veafWeatherInfo.LogLevel = "trace"
veaf.loggers.new(veafWeatherInfo.Id, veafWeatherInfo.LogLevel)

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global weather data
-------------------------------------------------------------------------------------------------------------------------------------------------------------
veafWeatherInfo.DcsPresetDensity =
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

veafWeatherInfo.CloudDensity = { Clear = 0, Few = 1, Scattered = 2, Broken = 3, Overcast = 4, Cavok = 5 }
veafWeatherInfo.CloudDensityOktas =
{
    [0] = veafWeatherInfo.CloudDensity.Clear,
    [1] = veafWeatherInfo.CloudDensity.Few,
    [2] = veafWeatherInfo.CloudDensity.Few,
    [3] = veafWeatherInfo.CloudDensity.Scattered,
    [4] = veafWeatherInfo.CloudDensity.Scattered,
    [5] = veafWeatherInfo.CloudDensity.Broken,
    [6] = veafWeatherInfo.CloudDensity.Broken,
    [7] = veafWeatherInfo.CloudDensity.Overcast,
    [8] = veafWeatherInfo.CloudDensity.Overcast
}

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  Weather management class
---  Collects and compile wheather data form various sources in the sim at a location
---  Can be output to string as METAR or ATIS informations
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
veafWeatherInfoData = {}
veafWeatherInfoData.__index = veafWeatherInfoData
---------------------------------------------------------------------------------------------------
---  CTOR
function veafWeatherInfoData:Create(vec3, iTimeAbs, iAltitude)
    iTimeAbs = iTimeAbs or timer.getAbsTime()
    local iGroundAltitude = veaf.getLandHeight(vec3)
    iAltitude = iAltitude or iGroundAltitude + 1 -- check a bit above ground especially for the wind
    if (iAltitude < iGroundAltitude) then
        iAltitude = iGroundAltitude
    end
   
    local iWindDir, iWindSpeedMs = weathermark._GetWind(vec3, iAltitude)

    local sunriseTime, sunsetTime =  veafTime.getSunTimesFromAbsTime(vec3)

    local iVisibilityMeters = env.mission.weather.visibility.distance
    local bFog = env.mission.weather.enable_fog
    if (bFog) then
        -- ground + 75 meters seems to be the point where it can be counted as a real impact on visibility
        if(env.mission.weather.fog.thickness < iAltitude + 75) then
            bFog = false
        elseif (env.mission.weather.fog.visibility < iVisibilityMeters) then
            iVisibilityMeters = env.mission.weather.fog.visibility
        end
    end

    local clouds = nil
    local bPrecipitation = false;
    local sCloudPreset = env.mission.weather.clouds.preset
    if (Fg.IsNullOrEmpty(sCloudPreset)) then
        if (env.mission.weather.clouds.density > 0) then
            clouds = {Density = env.mission.weather.clouds.density, Base = env.mission.weather.clouds.base}
        end
        bPrecipitation = (env.mission.weather.clouds.iprecptns > 0)
    else
        if (DcsPresetDensity[sCloudPreset]) then
            clouds = {Density = DcsPresetDensity[sCloudPreset][1], Base = env.mission.weather.clouds.base}
            bPrecipitation = DcsPresetDensity[sCloudPreset][2]
            if (DcsPresetDensity[sCloudPreset][3] and DcsPresetDensity[sCloudPreset][3] < iVisibilityMeters) then
                iVisibilityMeters = DcsPresetDensity[sCloudPreset][3]
            end
        end
    end
    
    local this =
    {
        TimeAbs = iTimeAbs,
        Coordinates = vec3,
        AltitudeMeter = iAltitude,
        WindDirection = UTILS.Round(iWindDir),
        WindSpeedMs = iWindSpeedMs,
        VisibilityMeters = iVisibilityMeters,
        Dust = env.mission.weather.enable_dust,
        Fog = bFog,
        Clouds = clouds,
        Precipitation = bPrecipitation,
        TemperatureCelcius = mooseCoord:GetTemperature(),
        --DewPoint, -- Magnus Formula, will need humidity to compute
        QnhHpa = mooseCoord:GetPressure(0),
        QfeHpa = mooseCoord:GetPressure(),
        Sunrise = iSunrise,
        Sunset = iSunset
    }

    setmetatable(this, self)

    veaf.loggers.get(veaf.Id):trace(this:toString())
    LogDebug(this:ToString())
    return this
end

---------------------------------------------------------------------------------------------------
---  METHODS
function FgWeather:GetFormattedWind(bMagnetic)
    bMagnetic = bMagnetic or false

    local iWindForce = UTILS.Round(UTILS.MpsToKnots(self.WindSpeedMs))
    local iWindDirection = self.WindDirection
    if (bMagnetic) then
        iWindDirection = iWindDirection - UTILS.GetMagneticDeclination()
        if (iWindDirection) < 0 then
            iWindDirection = iWindDirection + 360
        end    
    end

    if (iWindDirection == 0) then
        iWindDirection = 360
    end
    return iWindForce, iWindDirection
end

function FgWeather:GetCloudBaseAltitudeMeters(bHeight)
    bHeight = bHeight or false
    if (self.Clouds == nil or self.Clouds.Density <= 0) then
        return nil
    else
         local iCloudBase = self.Clouds.Base
         if (bHeight) then
            iCloudBase = iCloudBase - self.AltitudeMeter
        end

        return iCloudBase
    end
end

function FgWeather:GetFormattedClouds(bHeight)
    bHeight = bHeight or false

    if (self.Clouds == nil or self.Clouds.Density <= 0) then
        return CloudDensityLabel.Clear
    else
        local iCloudBase = UTILS.Round(UTILS.MetersToFeet(self:GetCloudBaseAltitudeMeters(bHeight)) / 100) * 100
        if (self.VisibilityMeters >= 10000 and iCloudBase >= 5000 and not self.Precipitation and not self.Fog and not self.Dust) then
            return CloudDensityLabel.Cavok
        else
            return CloudDensityLabelOktas[self.Clouds.Density], iCloudBase
        end
    end
end

function FgWeather:GetCarrierCase()
    local iCloudBase = nil
    if (self.Clouds and self.Clouds.Density > 4) then
        iCloudBase = UTILS.Round(UTILS.MetersToFeet(self:GetCloudBaseAltitudeMeters(false)) / 100) * 100
    end

    LogDebug(string.format("GetCarrierCase - Cloud base=%d feet (need more than 1000 for CASE 2 and 300 for CASE 3) - visibility=%d nm (need more than 5 for CASE 1/2)", iCloudBase or -1, UTILS.MetersToNM (self.VisibilityMeters)))

    if (self.VisibilityMeters > UTILS.NMToMeters(5) and (iCloudBase == nil or iCloudBase > 3000)) then
        return 1
    elseif (self.VisibilityMeters > UTILS.NMToMeters(5) and (iCloudBase == nil or iCloudBase > 1000)) then
        return 2
    else
        return 3
    end
end

function FgWeather:ToString(bWithClouds)
    bWithClouds = bWithClouds or false

    local sString = "Time=" .. Fg.TimeToStringDate(self.TimeAbs)
    sString = sString .. " - Coord=" .. self.Coordinates:ToStringLLDMS() .. " m"
    sString = sString .. " - Altitude=" .. UTILS.Round(self.AltitudeMeter) .. " m"
    sString = sString .. string.format(" - Wind= %03d @ %.2f ms [%.2f kts] [decl=%d]", self.WindDirection, self.WindSpeedMs, UTILS.MpsToKnots(self.WindSpeedMs), UTILS.GetMagneticDeclination())
    sString = sString .. " - Visibility=" .. self.VisibilityMeters .. " m"
    if (self.Fog) then
        sString = sString .. " - fog"
    end
    if (self.Dust) then
        sString = sString .. " - dust"
    end
    if (self.Precipitation) then
        sString = sString .. " - precipitations"
    end
    sString = sString .. " - Temperature=" .. UTILS.Round(self.TemperatureCelcius) .. " °C"
    sString = sString .. " - Qnh=" .. UTILS.Round(self.QnhHpa) .. " Hpa"
    sString = sString .. " - Qfe=" .. UTILS.Round(self.QfeHpa) .. " Hpa"
    sString = sString .. " - Sunrise=" .. Fg.TimeToString(self.Sunrise)
    sString = sString .. " - Sunset=" .. Fg.TimeToString(self.Sunset)

    if (bWithClouds) then
        sString = sString .. " - Clouds=\n" .. Fg.ToString(self.Clouds)
    end

    return sString
end

function FgWeather:ToStringAtis()
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
    
    if (self.TimeAbs < self.Sunrise or self.TimeAbs > self.Sunset) then
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
