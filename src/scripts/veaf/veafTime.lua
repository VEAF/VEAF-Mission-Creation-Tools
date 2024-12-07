------------------------------------------------------------------
-- VEAF time and date tools
-- By Flogas (2024)
--
-- Features:
-- ---------
-- * Provides a suite of tools to manage date and time information relative to the DCS mission
-- standard lua datetime object is used when appropriate:
-- --> as returned by os.date("*t", 906000490)
-- --> dateTime = { year = 1998, month = 9, day = 16, yday = 259, wday = *unused*, hour = 23, min = 48, sec = 10, isdst = *unused* }
------------------------------------------------------------------
veafTime = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global module settings
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafTime.Id = "TIME"

--- Version.
veafTime.Version = "1.1.0"

-- trace level, specific to this module
--veafTime.LogLevel = "trace"
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

local function _adjustDate(dateTime, iDaysOffset)
    local iYear = dateTime.year
    local iMonth = dateTime.month
    local iDay = dateTime.day
    local iDayOfYear = dateTime.yday
    
    -- Handle day changes
    iDay = iDay + iDaysOffset
    iDayOfYear = iDayOfYear + iDaysOffset
    
    -- Handle forward changes
    while true do
        local iDaysInMonth = _getDaysInMonth(iMonth, iYear)
        if (iDay <= iDaysInMonth) then
            break
        end
        iDay = iDay - iDaysInMonth
        iMonth = iMonth + 1
        if (iMonth > 12) then
            iMonth = 1
            iYear = iYear + 1
            -- Reset yday for new year
            iDayOfYear = iDay
        end
    end
    
    -- Handle backward changes
    while (iDay <= 0) do
        iMonth = iMonth - 1
        if (iMonth <= 0) then
            iMonth = 12
            iYear = iYear - 1
        end
        iDay = iDay + _getDaysInMonth(iMonth, iYear)
        -- Adjust yday for previous year
        if (iMonth == 12) then
            iDayOfYear = 365 + (_isLeapYear(iYear) and 1 or 0) + iDay - _getDaysInMonth(iMonth, iYear)
        end
    end
   
    return { year = iYear, month = iMonth, day = iDay, yday = iDayOfYear, hour = dateTime.hour, min = dateTime.min, sec = dateTime.sec }
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

    return { year = iYear, month = iMonth, day = iDay, yday = idayOfYear, hour = iHour, min = iMinute, sec = iSecond }
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

    --veaf.loggers.get(veafTime.Id):trace(veaf.p(dateTime))

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

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Timezones and sun times
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafTime.getTimezone(vec3)
    local nTimezoneOffset = 0
    local sTheatre = string.lower(env.mission.theatre)

    if (vec3) then
        -- Try to approximate for the vec3 - each timezone is roughly 15 degrees wide
        local nLatitude, nLongitude, _ = coord.LOtoLL(vec3)
        nTimezoneOffset = math.floor((nLongitude + 7.5) / 15)
    elseif (sTheatre == "caucasus") then
        nTimezoneOffset = 4
    elseif (sTheatre == "persiangulf") then
        nTimezoneOffset = 4
    elseif (sTheatre == "nevada") then
        nTimezoneOffset = -8
    elseif (sTheatre == "normandy") then
        nTimezoneOffset = 0
    elseif (sTheatre == "thechannel") then
        nTimezoneOffset = 2
    elseif (sTheatre == "syria") then
        nTimezoneOffset = 3
    elseif (sTheatre == "marianaislands") then
        nTimezoneOffset = 10
    elseif (sTheatre == "falklands") then
        nTimezoneOffset = -3
    elseif (sTheatre == "sinaiMap") then
        nTimezoneOffset = 2
    elseif (sTheatre == "kola") then
        nTimezoneOffset = 3
    elseif (sTheatre == "afghanistan") then
        nTimezoneOffset = 4.5
    end
    --veaf.loggers.get(veafTime.Id):trace(string.format("%s - timezone=%f", env.mission.theatre, nTimezoneOffset))
    return nTimezoneOffset
end

function veafTime.toZulu(dateTime, nOffsetHours)
    nOffsetHours = nOffsetHours or veafTime.getTimezone()
    
    -- Create a new table to avoid modifying the original
    local dateTimeZulu = {}
    for k, v in pairs(dateTime) do
        dateTimeZulu[k] = v
    end
    
    -- Convert hours and handle day boundary changes
    local iTotalMinutes = dateTimeZulu.hour * 60 + dateTimeZulu.min - (nOffsetHours * 60)
    local iDays = math.floor(iTotalMinutes / (24 * 60))
    iTotalMinutes = iTotalMinutes % (24 * 60)
    
    -- Update hours and minutes
    dateTimeZulu.hour = math.floor(iTotalMinutes / 60)
    dateTimeZulu.min = iTotalMinutes % 60
    
    -- Handle date changes if needed
    if iDays ~= 0 then
        return _adjustDate(dateTimeZulu, iDays)
    end
    
    return dateTimeZulu
end

function veafTime.toLocal(utcDateTime, nOffsetHours)
    nOffsetHours = nOffsetHours or veafTime.getTimezone()
    return veafTime.toZulu(utcDateTime, -nOffsetHours)
end

function veafTime.getSunTimes(vec3, iAbsTime, bZulu)
    bZulu = bZulu or false
    local dateTime = veafTime.absTimeToDateTime(iAbsTime)

    local PI = math.pi
    local RAD = PI / 180
    local DEG = 180 / PI
    local nLatitude, nLongitude, _ = coord.LOtoLL(vec3)

    local iYear = dateTime.year
    local idayOfYear = dateTime.yday

    local function _decimalToTime(iDecimalHours)
        -- Handle negative hours (can happen with UTC times)
        if (iDecimalHours < 0) then
            iDecimalHours = iDecimalHours + 24
        end
        -- Handle hours >= 24
        iDecimalHours = iDecimalHours % 24

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

    local nTimezoneOffset = veafTime.getTimezone()
    local nSolarNoonZulu = 12 - nLongitude / 15
    
    -- Calculate sunrise and sunset in decimal hours
    local nSunriseZulu = nSolarNoonZulu - H / 15
    local nSunsetZulu = nSolarNoonZulu + H / 15
    
    -- Convert to local time if requested
    local nSunriseTime = nSunriseZulu
    local nSunsetTime = nSunsetZulu
    
    if (not bZulu) then
        nSunriseTime = nSunriseTime + nTimezoneOffset
        nSunsetTime = nSunsetTime + nTimezoneOffset
    end

    local iSunriseHour, iSunriseMinute = _decimalToTime(nSunriseTime)
    local iSunsetHour, iSunsetMinute = _decimalToTime(nSunsetTime)

    return
    {
        Sunrise = { year = dateTime.year, month = dateTime.month, day = dateTime.day, yday = dateTime.yday, hour = iSunriseHour, min = iSunriseMinute, sec = 0 },
        Sunset =  { year = dateTime.year, month = dateTime.month, day = dateTime.day, yday = dateTime.yday, hour = iSunsetHour, min = iSunsetMinute, sec = 0 }
    }
end

function veafTime.isAeronauticalNight(vec3, iAbsTime)
    local dateTime = veafTime.absTimeToDateTime(iAbsTime)
    local sunTimes = veafTime.getSunTimes(vec3, iAbsTime)
    local sunriseTime = sunTimes.Sunrise
    local sunsetTime = sunTimes.Sunset
    
    --veaf.loggers.get(veafTime.Id):trace(veaf.p(sunriseTime))
    --veaf.loggers.get(veafTime.Id):trace(veaf.p(sunsetTime))

    local iCurrentSeconds = dateTime.hour * _iSecondsInHour + dateTime.min * _iSecondsInMinute + dateTime.sec
    local iSunriseSeconds = sunriseTime.hour * _iSecondsInHour + sunriseTime.min * _iSecondsInMinute + sunriseTime.sec - (30 * _iSecondsInMinute) -- sunrise - 30 min
    local iSunsetSeconds = sunsetTime.hour * _iSecondsInHour + sunsetTime.min * _iSecondsInMinute + sunsetTime.sec + (30 * _iSecondsInMinute) -- sunset + 30 min
    
    --veaf.loggers.get(veafTime.Id):trace(string.format("iCurrentSeconds=%d  iSunriseSeconds=%d   iSunsetSeconds=%d", iCurrentSeconds, iSunriseSeconds, iSunsetSeconds))
    
    return iCurrentSeconds < iSunriseSeconds or iCurrentSeconds > iSunsetSeconds
end

-- Helper function to determine season based on latitude and month
function veafTime.determineSeason(month, latitude)
    -- Determine if in Northern or Southern Hemisphere
    local isNorthernHemisphere = latitude == nil or latitude >= 0

    -- Season mapping adjusted for hemisphere
    if isNorthernHemisphere then
        -- Northern Hemisphere seasons
        if month >= 3 and month <= 5 then
            return "spring"
        elseif month >= 6 and month <= 8 then
            return "summer"
        elseif month >= 9 and month <= 11 then
            return "autumn"
        else
            return "winter"
        end
    else
        -- Southern Hemisphere seasons (reversed)
        if month >= 3 and month <= 5 then
            return "autumn"
        elseif month >= 6 and month <= 8 then
            return "winter"
        elseif month >= 9 and month <= 11 then
            return "spring"
        else
            return "summer"
        end
    end
end