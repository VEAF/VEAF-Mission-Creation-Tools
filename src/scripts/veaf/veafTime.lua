------------------------------------------------------------------
-- VEAF time and date tools
-- By Flogas (2024)
--
-- Features:
-- ---------
-- * Provides a suite of tools to manage date and time information relative to the DCS mission
-- 
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------
veafTime = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global module settings
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafTime.Id = "TIME"

--- Version.
veafTime.Version = "1.0.0"

-- trace level, specific to this module
-- veafWeatherInfo.LogLevel = "trace"
veaf.loggers.new(veafTime.Id, veafTime.LogLevel)

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- General date and time tools
-------------------------------------------------------------------------------------------------------------------------------------------------------------
local _iSecondsInMinute = 60
local _iSecondsInHour = 3600
local _iSecondsInDay = 86400

function veafTime.isLeapYear(iYear)
    return iYear % 4 == 0 and (iYear % 100 ~= 0 or iYear % 400 == 0)
end

function veafTime.getDaysInMonth(iMonth, iYear)
    local daysInMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    if iMonth == 2 and veafTime.isLeapYear(iYear) then
        return 29
    end
    return daysInMonth[iMonth]
end

function veafTime.getDayOfYear(iDay, iMonth, iYear)
    local iDayOfYear = iDay
    for i = 1, iMonth - 1 do
        iDayOfYear = iDayOfYear + veafTime.getDaysInMonth(i, iYear)
    end
    return iDayOfYear
end

function veafTime.getMissionDateAndTime(iAbsTime)
    iAbsTime = iAbsTime or timer.getAbsTime()

    -- Calculate hours, minutes, and remaining seconds
    local iDay = env.mission.date.Day
    local iMonth = env.mission.date.Month
    local iYear = env.mission.date.Year
    local iHours = math.floor(iAbsTime / _iSecondsInHour)
    local iRemainingSeconds = iAbsTime % _iSecondsInHour
    local iMinutes = math.floor(iRemainingSeconds / _iSecondsInMinute)
    local iSeconds = iRemainingSeconds % _iSecondsInMinute

    -- Handle day rollover
    local iAdditionalDays = math.floor(iHours / 24)
    iHours = iHours % 24

    -- Add the additional days
    iDay = iDay + iAdditionalDays

    -- Handle month and year rollover
    while true do
        local iDaysInCurrentMonth = veafTime.getDaysInMonth(iMonth, iYear)

        if (iDay <= iDaysInCurrentMonth) then
            break
        end

        iDay = iDay - iDaysInCurrentMonth
        iMonth = iMonth + 1

        if iMonth > 12 then
            iMonth = 1
            iYear = iYear + 1
        end
    end

    local idayOfYear = veafTime.getDayOfYear(iDay, iMonth, iYear)

    return {
        DayOfYear = idayOfYear,
        Day = iDay,
        Month = iMonth,
        Year = iYear,
        Hours = iHours,
        Minutes = iMinutes,
        Seconds = iSeconds
    }
end

function veafTime.getAbsTime(toDay, toMonth, toYear, hours, minutes, seconds)
    local iFromDay = env.mission.date.Day
    local iFromMonth = env.mission.date.Month
    local iFromYear = env.mission.date.Year
    
    local iTotalDays = 0
    
    -- If we're in the same year
    if iFromYear == toYear then
        iTotalDays = veafTime.getDayOfYear(toDay, toMonth, toYear) - veafTime.getDayOfYear(iFromDay, iFromMonth, iFromYear)
    else
        -- Days remaining in the first year
        iTotalDays = (veafTime.isLeapYear(iFromYear) and 366 or 365) - veafTime.getDayOfYear(iFromDay, iFromMonth, iFromYear)
        
        -- Add days for full years in between
        for iYear = iFromYear + 1, toYear - 1 do
            iTotalDays = iTotalDays + (veafTime.isLeapYear(iYear) and 366 or 365)
        end
        
        -- Add days in the final year
        iTotalDays = iTotalDays + veafTime.getDayOfYear(toDay, toMonth, toYear)
    end
    
    -- Calculate total seconds
    local iAbsTime = seconds +
                        (minutes * _iSecondsInMinute) +
                        (hours * _iSecondsInHour) +
                        (iTotalDays * _iSecondsInDay)
    
    return iAbsTime
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Timezones and sun times
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafTime.getTimezone(vec3)
    local iTimezone = 0

    if (vec3) then
        -- Try to approximate for the vec3 - each timezone is roughly 15 degrees wide
        local iLatitude, iLongitude, iAltitude = coord.LOtoLL(vec3)
        iTimezone = math.floor((iLongitude + 7.5) / 15)
    elseif (env.mission.theatre == "caucasus") then
        iTimezone = 4
    elseif (env.mission.theatre == "persiangulf") then
        iTimezone = 4
    elseif (env.mission.theatre == "Nevada") then
        iTimezone = -8
    elseif (env.mission.theatre == "Normandy") then
        iTimezone = 0
    elseif (env.mission.theatre == "thechannel") then
        iTimezone = 2
    elseif (env.mission.theatre == "syria") then
        iTimezone = 3
    elseif (env.mission.theatre == "marianaislands") then
        iTimezone = 10
    elseif (env.mission.theatre == "Falklands") then
        iTimezone = -3
    elseif (env.mission.theatre == "SinaiMap") then
        iTimezone = 2
    elseif (env.mission.theatre == "Kola") then
        iTimezone = 3
    elseif (env.mission.theatre == "Afghanistan") then
        iTimezone = 4.5
    end

    return iTimezone
end

function veafTime.getSunTimes(vec3, iAbsTime)
    iAbsTime = iAbsTime or timer.getAbsTime()

    local PI = math.pi
    local RAD = PI / 180
    local DEG = 180 / PI
    local iLatitude, iLongitude, iAltitude = coord.LOtoLL(vec3)

    local dateData = veafTime.getMissionDateAndTime(iAbsTime)
    local iYear = dateData.Year
    local idayOfYear = dateData.DayOfYear

    -- Helper function to convert decimal hours to HH:MM format
    local function _decimalToTime(iDecimalHours)
        local iHours = math.floor(iDecimalHours)
        local iMinutes = math.floor((iDecimalHours - iHours) * 60)
        return { iHours, iMinutes }
    end

    -- Calculate Julian date
    local function _julianDate(iDayOfYear, iYear)
        return 367 * iYear - math.floor(7 * (iYear + math.floor((10 + 9) / 12)) / 4) + math.floor(275 * 9 / 9) + iDayOfYear - 730531.5
    end

    -- Convert latitude and longitude to radians
    local lat_rad = iLatitude * RAD

    -- Calculate Julian date
    local jd = _julianDate(idayOfYear, iYear)

    -- Calculate solar mean anomaly
    local M = (0.9856 * jd - 3.289) * RAD

    -- Calculate equation of center
    local C = (1.916 * math.sin(M) + 0.020 * math.sin(2 * M) + 0.282 * math.sin(3 * M)) * RAD

    -- Calculate solar true longitude
    local L = M + C + PI

    -- Calculate solar declination
    local sinDec = 0.39782 * math.sin(L)
    local cosDec = math.sqrt(1 - sinDec * sinDec)

    -- Calculate solar hour angle
    local cosH = (math.sin(-0.0145) - math.sin(lat_rad) * sinDec) / (math.cos(lat_rad) * cosDec)

    -- Check if the sun never rises/sets at this location on this day
    if cosH > 1 then
        return "No sunrise/sunset - Polar night"
    elseif cosH < -1 then
        return "No sunrise/sunset - Midnight sun"
    end

    -- Calculate sunrise and sunset hour angles
    local H = math.acos(cosH) * DEG

    -- Convert to hours
    local noon = 12 + (-iLongitude / 15)
    local sunrise = noon - H / 15
    local sunset = noon + H / 15

    -- Adjust for any hours outside 0-24 range
    sunrise = sunrise % 24
    sunset = sunset % 24

    return
    {
        Sunrise = sunrise,
        Sunset = sunset
    }
end

function veafTime.getSunAbsTimes(vec3, iAbsTime)
    local sunTimes = veafTime.getSunTimes(vec3, iAbsTime)
    dateData
end