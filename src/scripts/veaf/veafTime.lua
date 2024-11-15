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
-- Local tools
-------------------------------------------------------------------------------------------------------------------------------------------------------------
local function _isLeapYear(iYear)
    return iYear % 4 == 0 and (iYear % 100 ~= 0 or iYear % 400 == 0)
end

local function _getDaysInMonth(iMonth, iYear)
    local daysInMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    if iMonth == 2 and _isLeapYear(iYear) then
        return 29
    end
    return daysInMonth[iMonth]
end

local function _getDayOfYear(iDay, iMonth, iYear)
    local iDayOfYear = iDay
    for i = 1, iMonth - 1 do
        iDayOfYear = iDayOfYear + _getDaysInMonth(i, iYear)
    end
    return iDayOfYear
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- General date and time tools
-------------------------------------------------------------------------------------------------------------------------------------------------------------
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
        local iDaysInCurrentMonth = _getDaysInMonth(iMonth, iYear)

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

    local idayOfYear = _getDayOfYear(iDay, iMonth, iYear)

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
        iTotalDays = _getDayOfYear(iDay, iMonth, iYear) - _getDayOfYear(iMissionStartDay, iMissionStartMonth, iMissionStartYear)
    else
        -- Days remaining in the first year
        iTotalDays = (_isLeapYear(iMissionStartYear) and 366 or 365) - _getDayOfYear(iMissionStartDay, iMissionStartMonth, iMissionStartYear)
        
        -- Add days for full years in between
        for iYear = iMissionStartYear + 1, iYear - 1 do
            iTotalDays = iTotalDays + (_isLeapYear(iYear) and 366 or 365)
        end
        
        -- Add days in the final year
        iTotalDays = iTotalDays + _getDayOfYear(iDay, iMonth, iYear)
    end
    
    -- Calculate total seconds
    local iAbsTime = iSecond +
                    (iMinute * _iSecondsInMinute) +
                    (iHour * _iSecondsInHour) +
                    (iTotalDays * _iSecondsInDay)
    
    return iAbsTime
end

function veafTime.absTimeToDateTime(iAbsTime)
    iAbsTime = iAbsTime or timer.getAbsTime()
    return veafTime.getMissionDateTime(iAbsTime)
end
--[[
function veafTime.ToZulu(time)
    time = time or timer.getAbsTime()
    if (type(time) == "table") then
        
    end

    return iAbsSeconds - (UTILS.GMTToLocalTimeDifference() * 3600)
end
]]
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Date and time string display tools
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafTime.toStringDate(dateTime)
    return string.format("%02d/%02d/%d", dateTime.day, dateTime.month, dateTime.year)
end

function veafTime.absTimeToStringDate(iAbsTime)
    local dateTime = veafTime.absTimeToDateTime(iAbsTime)
    return veafTime.toStringDate(dateTime)
end

function veafTime.toStringTime(dateTime, bWithSeconds)
    if (bWithSeconds == nil) then bWithSeconds = true end

    --veaf.loggers.get(veafTime.Id):info(veaf.p(dateTime))

    if (bWithSeconds) then
        return string.format("%02d:%02d:%02d", dateTime.hour, dateTime.min, dateTime.sec)
    else
        return string.format("%02d:%02d", dateTime.hour, dateTime.min)
    end
end

function veafTime.absTimeToStringTime(iAbsTime, bWithSeconds)
    local dateTime = veafTime.absTimeToDateTime(iAbsTime)
    return veafTime.toStringTime(dateTime, bWithSeconds)
end

function veafTime.toStringDateTime(dateTime, bWithSeconds)
    return string.format("%s %s", veafTime.toStringDate(dateTime), veafTime.toStringTime(dateTime, bWithSeconds))
end

function veafTime.absTimeToStringDateTime(iAbsTime)
    local dateTime = veafTime.absTimeToDateTime(iAbsTime)
    return veafTime.toStringDateTime(dateTime, bWithSeconds)
end

function veafTime.toStringMetar(dateTime, bZulu)
    if (bZulu == nil) then bZulu = true end
    
    local sTimeZone
    if(bZulu) then
        sTimeZone = "Z"
    else
        sTimeZone = "L"
    end
        
    return string.format("%02d%02d%s", dateTime.hour, dateTime.minute)
end

function veafTime.toStringMetar(iAbsSeconds)
    local oTime = Fg.TimeFromAbsSeconds(iAbsSeconds)
    return string.format("%02d%02dZ", oTime.Hour, oTime.Minute)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Timezones and sun times
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafTime.getTimezone(vec3)
    local iTimezone = 0

    if (vec3) then
        -- Try to approximate for the vec3 - each timezone is roughly 15 degrees wide
        local nLatitude, nLongitude, _ = coord.LOtoLL(vec3)
        iTimezone = math.floor((nLongitude + 7.5) / 15)
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
    local dateTime = veafTime.absTimeToDateTime(iAbsTime)

    local PI = math.pi
    local RAD = PI / 180
    local DEG = 180 / PI
    local nLatitude, nLongitude, _ = coord.LOtoLL(vec3)

    local iYear = dateTime.year
    local idayOfYear = dateTime.yday

    -- Helper function to convert decimal hours to HH:MM format
    local function _decimalToTime(iDecimalHours)
        local iHours = math.floor(iDecimalHours)
        local iMinutes = math.floor((iDecimalHours - iHours) * 60)
        return iHours, iMinutes
    end

    -- Calculate Julian date
    local function _julianDate(iDayOfYear, iYear)
        return 367 * iYear - math.floor(7 * (iYear + math.floor((10 + 9) / 12)) / 4) + math.floor(275 * 9 / 9) + iDayOfYear - 730531.5
    end

    -- Convert latitude to radians
    local nLatitudeRad = nLatitude * RAD

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
    local cosH = (math.sin(-0.0145) - math.sin(nLatitudeRad) * sinDec) / (math.cos(nLatitudeRad) * cosDec)

    -- Check if the sun never rises/sets at this location on this day
    if cosH > 1 then
        return nil -- "No sunrise/sunset - Polar night"
    elseif cosH < -1 then
        return nil -- "No sunrise/sunset - Midnight sun"
    end

    -- Calculate sunrise and sunset hour angles
    local H = math.acos(cosH) * DEG

    -- Convert to hours
    local noon = 12 + (-nLongitude / 15)
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

function veafTime.isAeronauticalNight(vec3, iAbsTime)
    local dateTime = veafTime.absTimeToDateTime(iAbsTime)
    local sunriseTime, sunsetTime = veafTime.getSunTimes(vec3, iAbsTime)

    local iCurrentSeconds = dateTime.hour * _iSecondsInHour + dateTime.min * _iSecondsInMinute + dateTime.sec
    local iSunriseSeconds = sunriseTime.hour * _iSecondsInHour + sunriseTime.min * _iSecondsInMinute + sunriseTime.sec - (30 * _iSecondsInMinute) -- sunrise - 30 min
    local iSunsetSeconds = sunsetTime.hour * _iSecondsInHour + sunsetTime.min * _iSecondsInMinute + sunsetTime.sec + (30 * _iSecondsInMinute) -- sunset + 30 min
    
    return iCurrentSeconds < iSunriseSeconds or iCurrentSeconds > iSunsetSeconds
end