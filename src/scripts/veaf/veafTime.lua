------------------------------------------------------------------
-- VEAF time and date tools
-- By Flogas (2024)
--
-- Features:
-- ---------
-- * Provides a suite of tools to manage date and time information relative to the DCS mission
-- standard lua datetime object is used when appropriate:
-- --> as returned by os.date("*t", 906000490)
-- --> dateTime = { year = 1998, month = 9, day = 16, yday = 259, wday = 4, hour = 23, min = 48, sec = 10, isdst = false }
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
-- Local constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------
local _iSecondsInMinute = 60
local _iSecondsInHour = 3600
local _iSecondsInDay = 86400

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- General date and time tools
-------------------------------------------------------------------------------------------------------------------------------------------------------------
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

function veafTime.getMissionDateTime(iAbsTime)
    iAbsTime = iAbsTime or timer.getAbsTime()

    -- Calculate hours, minutes, and remaining seconds
    local iDay = env.mission.date.Day
    local iMonth = env.mission.date.Month
    local iYear = env.mission.date.Year
    local iHour = math.floor(iAbsTime / _iSecondsInHour)
    local iRemainingSeconds = iAbsTime % _iSecondsInHour
    local iMinute = math.floor(iRemainingSeconds / _iSecondsInMinute)
    local iSecond = iRemainingSeconds % _iSecondsInMinute

    -- Handle day rollover
    local iAdditionalDays = math.floor(iHour / 24)
    iHour = iHour % 24

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

    return { year = iYear, month = iMonth, day = iDay, yday = idayOfYear, wday = 4, hour = iHour, min = iMinute, sec = iSecond, isdst = false }
end

function veafTime.getMissionAbsTime(dateTime)
    local iMissionStartDay = env.mission.date.Day
    local iMissionStartMonth = env.mission.date.Month
    local iMissionStartYear = env.mission.date.Year
    
    local iDay = dateTime.day
    local iMonth = dateTime.month
    local iYear = dateTime.year
    local iHour = dateTime.hour
    local iMinute = dateTime.min
    local iSecond = dateTime.sec

    local iTotalDays = 0
    
    -- If we're in the same year
    if iMissionStartYear == iYear then
        iTotalDays = veafTime.getDayOfYear(iDay, iMonth, iYear) - veafTime.getDayOfYear(iMissionStartDay, iMissionStartMonth, iMissionStartYear)
    else
        -- Days remaining in the first year
        iTotalDays = (veafTime.isLeapYear(iMissionStartYear) and 366 or 365) - veafTime.getDayOfYear(iMissionStartDay, iMissionStartMonth, iMissionStartYear)
        
        -- Add days for full years in between
        for iYear = iMissionStartYear + 1, iYear - 1 do
            iTotalDays = iTotalDays + (veafTime.isLeapYear(iYear) and 366 or 365)
        end
        
        -- Add days in the final year
        iTotalDays = iTotalDays + veafTime.getDayOfYear(iDay, iMonth, iYear)
    end
    
    -- Calculate total seconds
    local iAbsTime = iSecond +
                    (iMinute * _iSecondsInMinute) +
                    (iHour * _iSecondsInHour) +
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

function veafTime.getSunTimesFromAbsTime(vec3, iAbsTime)
    iAbsTime = iAbsTime or timer.getAbsTime()
    local dateTime = veafTime.getMissionDateTime(iAbsTime)
    return veafTime.getSunTimes(vec3, dateTime)
end

function veafTime.getSunTimes(vec3, dateTime)
    local PI = math.pi
    local RAD = PI / 180
    local DEG = 180 / PI
    local iLatitude, iLongitude, iAltitude = coord.LOtoLL(vec3)

    local iYear = dateTime.year
    local idayOfYear = dateTime.yday

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

    -- Convert latitude to radians
    local iLatitudeRad = iLatitude * RAD

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
    local cosH = (math.sin(-0.0145) - math.sin(iLatitudeRad) * sinDec) / (math.cos(iLatitudeRad) * cosDec)

    -- Check if the sun never rises/sets at this location on this day
    if cosH > 1 then
        return nil -- "No sunrise/sunset - Polar night"
    elseif cosH < -1 then
        return nil -- "No sunrise/sunset - Midnight sun"
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

    local iSunriseHour, iSunriseMinute = _decimalToTime(sunrise)
    local iSunsetHour, iSunsetMinute = _decimalToTime(sunset)

    return
    {
        Sunrise = { year = dateTime.year, month = dateTime.month, day = dateTime.day, yday = dateTime.yday, hour = iSunriseHour, min = iSunriseMinute, sec = 0, isdst = false },
        Sunset =  { year = dateTime.year, month = dateTime.month, day = dateTime.day, yday = dateTime.yday, hour = iSunsetHour, min = iSunsetMinute, sec = 0, isdst = false }
    }
end
