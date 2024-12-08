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
veafTime.Version = "1.1.1"

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

local function _decimalToHoursMinutes(iDecimalHours)
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

-- Constants
local PI = math.pi
local RAD = PI / 180
local DEG = 180 / PI

local function solar_calculations(day_of_year, year)
    -- Julian Date calculation
    local JD = 367 * year 
              - math.floor((year + math.floor((9 + 1) / 12)) * 7 / 4)
              + math.floor(275 * 1 / 9) 
              + day_of_year 
              + 1721013.5
    
    -- Mean solar longitude
    local L0 = (280.460 + 0.9856474 * JD) % 360
    
    -- Mean anomaly
    local M = (357.528 + 0.9856003 * JD) % 360
    
    -- Ecliptic longitude
    local lambda = L0 + 1.915 * math.sin(M * RAD) + 0.020 * math.sin(2 * M * RAD)
    
    -- Obliquity of ecliptic
    local epsilon = 23.439 - 0.0000004 * JD
    
    return {
        JD = JD,
        mean_solar_longitude = L0,
        mean_anomaly = M,
        ecliptic_longitude = lambda,
        obliquity = epsilon
    }
end


local function calculate_hour_angle(latitude, day_of_year, year)
    local solar_data = solar_calculations(day_of_year, year)
    
    -- Solar declination
    local declination = math.asin(
        math.sin(solar_data.obliquity * RAD) * 
        math.sin(solar_data.ecliptic_longitude * RAD)
    ) * DEG
    
    -- Hour angle calculation
    local lat_rad = latitude * RAD
    
    -- Approximation for sunrise/sunset hour angle
    local hour_angle = math.acos(
        -math.tan(lat_rad) * math.tan(declination * RAD)
    ) * DEG
    
    return {
        declination = declination,
        hour_angle = hour_angle
    }
end

local function _getSunTimesZulu(nLatitude, nLongitude, iDayOfYear, iYear)
    local hour_angle_data = calculate_hour_angle(nLatitude, iDayOfYear, iYear)
    
    -- Check for polar conditions
    -- If hour_angle is NaN, it means the sun never rises/sets
    if (hour_angle_data.hour_angle ~= hour_angle_data.hour_angle) then
        local is_polar_night = hour_angle_data.declination * nLatitude < 0
        
        return {
            sunrise = is_polar_night and "No sunrise - Polar night" or "No sunset - Midnight sun",
            sunset = is_polar_night and "No sunrise - Polar night" or "No sunset - Midnight sun",
            is_polar_condition = true
        }
    end

    -- Calculate solar noon (UTC)
    local solar_noon = 12 - (nLongitude / 15)
    
    -- Calculate sunrise and sunset times
    local sunrise_utc = solar_noon - (hour_angle_data.hour_angle / 15)
    local sunset_utc = solar_noon + (hour_angle_data.hour_angle / 15)

    return sunrise_utc, sunset_utc
end

function veafTime.getSunTimes(vec3, iAbsTime)
    local result = veafTime.getSunTimesZulu(vec3, iAbsTime)
    result.SunriseLocal = veafTime.toLocal(result.Sunrise)
    result.SunsetLocal = veafTime.toLocal(result.Sunset)
    return result
end

function veafTime.getSunTimesZulu(vec3, iAbsTime)
    local dateTime = veafTime.absTimeToDateTime(iAbsTime)
    local dateTimeZulu = veafTime.toZulu(dateTime)
    local nLatitude, nLongitude, _ = coord.LOtoLL(vec3)
    local iYear = dateTime.year
    local idayOfYear = dateTime.yday

    local nSunriseZulu, nSunsetZulu = _getSunTimesZulu(nLatitude, nLongitude, idayOfYear, iYear)
    local iSunriseHour, iSunriseMinute = _decimalToHoursMinutes(nSunriseZulu)
    local iSunsetHour, iSunsetMinute = _decimalToHoursMinutes(nSunsetZulu)

    return
    {
        Sunrise = { year = dateTime.year, month = dateTime.month, day = dateTime.day, yday = dateTime.yday, hour = iSunriseHour, min = iSunriseMinute, sec = 0 },
        Sunset =  { year = dateTime.year, month = dateTime.month, day = dateTime.day, yday = dateTime.yday, hour = iSunsetHour, min = iSunsetMinute, sec = 0 },
    }
end

function veafTime.isAeronauticalNight(vec3, iAbsTime)
    local dateTime = veafTime.absTimeToDateTime(iAbsTime)
    local sunTimesZulu = veafTime.getSunTimesZulu(vec3, iAbsTime)
    local sunriseTimeZulu = sunTimesZulu.Sunrise
    local sunsetTimeZulu = sunTimesZulu.Sunset
    local sunriseTime = veafTime.toLocal(sunriseTimeZulu)
    local sunsetTime = veafTime.toLocal(sunsetTimeZulu)
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