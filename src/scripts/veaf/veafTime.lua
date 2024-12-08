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

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Timezones
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
        nTimezoneOffset = -8 -- Nevada uses DST (UTC-7 march through october) but it is not modeled in DCS
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

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Sun times
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafTime.getSunTimesZulu(vec3, iAbsTime)
    local nLatitude, nLongitude, _ = coord.LOtoLL(vec3)
    local date = veafTime.absTimeToDateTime(iAbsTime)

    return veafSunTimes.getSunTimes(nLatitude, nLongitude, date, 0)
end

function veafTime.getSunTimesLocal(vec3, iAbsTime)
    local nLatitude, nLongitude, _ = coord.LOtoLL(vec3)
    local date = veafTime.absTimeToDateTime(iAbsTime)
    
    return veafSunTimes.getSunTimes(nLatitude, nLongitude, date, veafTime.getTimezone())
end

function veafTime.isAeronauticalNight(vec3, iAbsTime)
    local dateTime = veafTime.absTimeToDateTime(iAbsTime)
    local sunTimes = veafTime.getSunTimesLocal(vec3, iAbsTime)
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

local dawnAngle, duskAngle = 6, 6
local DR = math.pi / 180
local K1 = 15 * math.pi * 1.0027379 / 180

veafSunTimes = {}
veafSunTimes.__index = veafSunTimes

---------------------------------------------------------------------------------------------------
---  CTOR
function veafSunTimes:create()
    local this = {
        sunRiseSetTimes = {},
        moonRiseSetTimes = {},
        NoSunRise = false,
        NoSunSet = false,
        lat = 0,
        long = 0,
        timeOffset = 0,
        jDateSun = nil
    }

    setmetatable(this, veafSunTimes)
    return this
end

----------------------------------------------------------------------------------------------------
-- Main static method
----------------------------------------------------------------------------------------------------
function veafSunTimes.getSunTimes(nLatitude, nLongitude, date, nTimeZone)
    local sunTimes = veafSunTimes:create()
    sunTimes:compute(nLatitude, nLongitude, nTimeZone, date)

    local sunrise = sunTimes.sunRiseSetTimes[2]
    local sunset = sunTimes.sunRiseSetTimes[3]

    local iSunriseHour, iSunriseMinute = _decimalToHoursMinutes(sunrise)
    local iSunsetHour, iSunsetMinute = _decimalToHoursMinutes(sunset)

    return
    {
        Sunrise = { year = date.year, month = date.month, day = date.day, yday = date.yday, hour = iSunriseHour, min = iSunriseMinute, sec = 0 },
        Sunset =  { year = date.year, month = date.month, day = date.day, yday = date.yday, hour = iSunsetHour, min = iSunsetMinute, sec = 0 }
    }
end

----------------------------------------------------------------------------------------------------
-- Main compute method
----------------------------------------------------------------------------------------------------
function veafSunTimes:compute(nLatitude, nLongitude, nTimeZone, date)
    self.sunRiseSetTimes = {6, 6, 6, 12, 13, 18, 18, 18, 24}
    self.moonRiseSetTimes = {0, 23.9}
    self.NoSunRise = false
    self.NoSunSet = false
    self.lat = nLatitude
    self.long = nLongitude
    self.timeOffset = nTimeZone
    self.jDateSun = self:julian(date.year, date.month, date.day) - (nLongitude / (15 * 24))

    -- sun time calculations
    self:calcSunRiseSet()
    if self.NoSunRise or self.NoSunSet then
        -- adjust times to solar noon
        self.sunRiseSetTimes[2] = (self.sunRiseSetTimes[2] - 12)
        if self.NoSunRise then
            self.sunRiseSetTimes[3] = self.sunRiseSetTimes[2] + 0.0001
        else
            self.sunRiseSetTimes[3] = (self.sunRiseSetTimes[2] - 0.0001)
        end
        self.sunRiseSetTimes[1] = 0
        self.sunRiseSetTimes[4] = 0
    end

    -- debugging
    -- print("dawn = "       .. TimeString(sunRiseSetTimes[1],  nTimeLZero, nTimeStyle) .. " (" .. sunRiseSetTimes[1]  ..")")
    -- print("sunrise = "    .. TimeString(sunRiseSetTimes[2],  nTimeLZero, nTimeStyle) .. " (" .. sunRiseSetTimes[2]  ..")")
    -- print("sunset = "     .. TimeString(sunRiseSetTimes[3],  nTimeLZero, nTimeStyle) .. " (" .. sunRiseSetTimes[3]  ..")")
    -- print("twilight = "   .. TimeString(sunRiseSetTimes[4],  nTimeLZero, nTimeStyle) .. " (" .. sunRiseSetTimes[4]  ..")")
end

----------------------------------------------------------------------------------------------------
-- Following code kept as close as possible to https://gist.github.com/eDave56/6dfae1b62c4cf743afe0ad61e300f091
----------------------------------------------------------------------------------------------------

------------------------------------ [ sun time calculations ] -------------------------------------

function veafSunTimes:midDay(Ftime)
    local eqt = self:sunPosition(self.jDateSun + Ftime, 0)
    local noon = veafSunTimes.DMath.fixHour(12 - eqt)
    return noon
end -- function midDay

function veafSunTimes:sunAngleTime(angle, Ftime, direction)
    --
    -- time at which sun reaches a specific angle below horizon
    --
    local decl = self:sunPosition(self.jDateSun + Ftime, 1)
    local noon = self:midDay(Ftime)
    local t = (-veafSunTimes.DMath.Msin(angle) - veafSunTimes.DMath.Msin(decl) * veafSunTimes.DMath.Msin(self.lat)) / (veafSunTimes.DMath.Mcos(decl) * veafSunTimes.DMath.Mcos(self.lat))

    if t > 1 then
        -- the sun doesn't rise today
        self.NoSunRise = 1
        return noon
    elseif t < -1 then
        -- the sun doesn't set today
        self.NoSunSet = 1
        return noon
    end

    t = 1 / 15 * veafSunTimes.DMath.arccos(t)
    return noon + ((direction == "CCW") and -t or t)
end -- function sunAngleTime

function veafSunTimes:sunPosition(jd, Declination)
    --
    -- compute declination angle of sun
    --
    local D = jd - 2451545
    local g = veafSunTimes.DMath.fixAngle(357.529 + 0.98560028 * D)
    local q = veafSunTimes.DMath.fixAngle(280.459 + 0.98564736 * D)
    local L = veafSunTimes.DMath.fixAngle(q + 1.915 * veafSunTimes.DMath.Msin(g) + 0.020 * veafSunTimes.DMath.Msin(2 * g))
    local R = 1.00014 - 0.01671 * veafSunTimes.DMath.Mcos(g) - 0.00014 * veafSunTimes.DMath.Mcos(2 * g)
    local e = 23.439 - 0.00000036 * D
    local RA = veafSunTimes.DMath.arctan2(veafSunTimes.DMath.Mcos(e) * veafSunTimes.DMath.Msin(L), veafSunTimes.DMath.Mcos(L)) / 15
    local eqt = q / 15 - veafSunTimes.DMath.fixHour(RA)
    local decl = veafSunTimes.DMath.arcsin(veafSunTimes.DMath.Msin(e) * veafSunTimes.DMath.Msin(L))

    if Declination == 1 then
        return decl
    else
        return eqt
    end
end -- function sunPosition

function veafSunTimes:julian(year, month, day)
    --
    -- convert Gregorian date to Julian day
    --
    if (month <= 2) then
        year = year - 1
        month = month + 12
    end
    local A = math.floor(year / 100)
    local B = 2 - A + math.floor(A / 4)
    local JD = math.floor(365.25 * (year + 4716)) + math.floor(30.6001 * (month + 1)) + day + B - 1524.5
    return JD
end -- function julian

function veafSunTimes:setTimes(sunRiseSetTimes)
    local Ftimes = self:dayPortion(sunRiseSetTimes)
    local dawn = self:sunAngleTime(dawnAngle, Ftimes[2], "CCW")
    local sunrise = self:sunAngleTime(self:riseSetAngle(), Ftimes[3], "CCW")
    local sunset = self:sunAngleTime(self:riseSetAngle(), Ftimes[8], "CW")
    local dusk = self:sunAngleTime(duskAngle, Ftimes[7], "CW")
    return {dawn, sunrise, sunset, dusk}
end -- function setTimes

function veafSunTimes:calcSunRiseSet()
    self.sunRiseSetTimes = self:setTimes(self.sunRiseSetTimes)
    return self:adjustTimes(self.sunRiseSetTimes)
end      

function veafSunTimes:adjustTimes(sunRiseSetTimes)
    for i = 1, #sunRiseSetTimes do
        sunRiseSetTimes[i] = sunRiseSetTimes[i] + (self.timeOffset - self.long / 15)
    end
    sunRiseSetTimes = self:adjustHighLats(sunRiseSetTimes)
    return sunRiseSetTimes
end -- function adjustTimes

function veafSunTimes:riseSetAngle()
    --
    -- sun angle for sunset/sunrise
    --
    -- local angle = 0.0347 * math.sqrt( elv )
    local angle = 0.0347
    return 0.833 + angle
end -- function riseSetAngle

function veafSunTimes:adjustHighLats(sunRiseSetTimes)
    --
    -- adjust times for higher latitudes
    --
    local nightTime = self:timeDiff(sunRiseSetTimes[3], sunRiseSetTimes[2])
    sunRiseSetTimes[1] = self:refineHLtimes(sunRiseSetTimes[1], sunRiseSetTimes[2], (dawnAngle), nightTime, "CCW")
    return sunRiseSetTimes
end -- function adjustHighLats

function veafSunTimes:refineHLtimes(Ftime, base, angle, night, direction)
    --
    -- refine time for higher latitudes
    --
    local portion = night / 2
    local FtimeDiff = (direction == "CCW") and self:timeDiff(Ftime, base) or self:timeDiff(base, Ftime)
    if not ((Ftime * 2) > 2) or (FtimeDiff > portion) then
        Ftime = base + ((direction == "CCW") and -portion or portion)
    end
    return Ftime
end -- function refineHLtimes

function veafSunTimes:dayPortion(sunRiseSetTimes)
    --
    --  convert hours to day portions
    --
    for i = 1, #sunRiseSetTimes do
        sunRiseSetTimes[i] = sunRiseSetTimes[i] / 24
    end
    return sunRiseSetTimes
end -- function dayPortion

function veafSunTimes:timeDiff(time1, time2)
    --
    --  difference between two times
    --
    return veafSunTimes.DMath.fixHour(time2 - time1)
end -- function timeDiff

----------------------------------- [ moon time calaculations ] ------------------------------------
-- VEAF not retained
------------------------------------- [ other odds and sods ] --------------------------------------
-- VEAF not retained

---------------------------------------- [ math functions ] ----------------------------------------

function veafSunTimes.fix(a, b)
    a = a - b * (math.floor(a / b))
    return (a < 0) and a + b or a
end

function veafSunTimes.dtr(d)
    return (d * math.pi) / 180
end
function veafSunTimes.rtd(r)
    return (r * 180) / math.pi
end

veafSunTimes.DMath = {
    Msin = function(d)
        return math.sin(veafSunTimes.dtr(d))
    end,
    Mcos = function(d)
        return math.cos(veafSunTimes.dtr(d))
    end,
    Mtan = function(d)
        return math.tan(veafSunTimes.dtr(d))
    end,
    arcsin = function(d)
        return veafSunTimes.rtd(math.asin(d))
    end,
    arccos = function(d)
        return veafSunTimes.rtd(math.acos(d))
    end,
    arctan = function(d)
        return veafSunTimes.rtd(math.atan(d))
    end,
    arccot = function(x)
        return veafSunTimes.rtd(math.atan(1 / x))
    end,
    arctan2 = function(y, x)
        return veafSunTimes.rtd(math.atan2(y, x))
    end,
    fixAngle = function(a)
        return veafSunTimes.fix(a, 360)
    end,
    fixHour = function(a)
        return veafSunTimes.fix(a, 24)
    end
}

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-------------------- TEST STUFF--------------------------------------------------------------------
--[[
local _TEST_LOCATIONS =
{
    ["BATUMI"] = {41.6167547, 41.6367455, 4},
    ["DAMASCUS"] = {34.802075, 38.996815, 3},
    ["SAIPAN"] = {15.0979, 145.6739, 10},
    ["LAS VEGAS"] = {36.176, -115.137, -8},
    ["DUBAI"] = {23.424076, 53.847818, 4}
}

local function _TEST_SUN_TIMES(sLocation, date, sExpectedRise, sExpectedSet)
    local nLatitude = _TEST_LOCATIONS[sLocation][1]
    local nLongitude = _TEST_LOCATIONS[sLocation][2]
    local iTimezoneOffset = veafTime.getTimezone()
    
    if (date == nil) then
        date = veafTime.absTimeToDateTime()
        sExpectedRise = "no data"
        sExpectedSet = "no data"
    else
        date = {day = date[1], month = date[2], year = date[3]}
    end

    local sunTimes = veafSunTimes.getSunTimes(nLatitude, nLongitude, date, iTimezoneOffset)

    local sunrise = sunTimes.Sunrise
    local sunset = sunTimes.Sunset
    veaf.loggers.get(veafTime.Id):trace("%s ; %02d/%02d/%d : sunrise=%02d:%02d, sunset=%02d:%02d ( expected rise=%s, set=%s )", sLocation, date.day, date.month, date.year, sunrise.hour, sunrise.min, sunset.hour, sunset.min, sExpectedRise, sExpectedSet)
end

veaf.loggers.get(veafTime.Id):trace("%s >> TESTS TESTS TESTS", veafTime.Id)
local sTheatre = string.lower(env.mission.theatre)
local sLoc
if (sTheatre == "caucasus") then
    sLoc = "BATUMI"
    _TEST_SUN_TIMES(sLoc, 1, 1, 2024, "08:40", "17:53")
    _TEST_SUN_TIMES(sLoc, 1, 4, 2024, "06:54", "19:39")
    _TEST_SUN_TIMES(sLoc, 1, 7, 2024, "05:43", "20:51")
    _TEST_SUN_TIMES(sLoc, 1, 10, 2024, "07:11", "18:54")
elseif (sTheatre == "persiangulf") then
    sLoc = "DUBAI"
    _TEST_SUN_TIMES(sLoc, {1, 1, 2024}, "07:06", "17:49")
    _TEST_SUN_TIMES(sLoc, {1, 4, 2024}, "06:16", "18:40")
    _TEST_SUN_TIMES(sLoc, {1, 7, 2024}, "05:42", "19:15")
    _TEST_SUN_TIMES(sLoc, {1, 10, 2024}, "06:16", "18:11")    
elseif (sTheatre == "nevada") then
    sLoc = "LAS VEGAS"
    _TEST_SUN_TIMES(sLoc)
    _TEST_SUN_TIMES(sLoc, {1, 1, 2024}, "06:50", "16:37")
    _TEST_SUN_TIMES(sLoc, {1, 4, 2024}, "06:24 (05:24 w/o DST)", "19:04 (18:04 w/o DST)")
    _TEST_SUN_TIMES(sLoc, {1, 7, 2024}, "05:25 (04:25 w/o DST)", "20:14 (19:14 w/o DST)")
    _TEST_SUN_TIMES(sLoc, {1, 10, 2024}, "06:43 (05:43 w/o DST)", "18:26 (17:25 w/o DST)")    
elseif (sTheatre == "normandy") then
    sLoc = ""
elseif (sTheatre == "thechannel") then
    sLoc = ""
elseif (sTheatre == "syria") then
    sLoc = "DAMASCUS"
    _TEST_SUN_TIMES(sLoc, {1, 1, 2024}, "07:38", "17:37")
    _TEST_SUN_TIMES(sLoc, {1, 4, 2024}, "06:22", "18:56")
    _TEST_SUN_TIMES(sLoc, {1, 7, 2024}, "05:28", "19:46")
    _TEST_SUN_TIMES(sLoc, {1, 10, 2024}, "06:29", "18:18")    
elseif (sTheatre == "marianaislands") then
    sLoc = "SAIPAN"
    _TEST_SUN_TIMES(sLoc, {1, 1, 2024}, "06:42", "17:57")
    _TEST_SUN_TIMES(sLoc, {1, 4, 2024}, "06:12", "18:29")
    _TEST_SUN_TIMES(sLoc, {1, 7, 2024}, "05:51", "18:51")
    _TEST_SUN_TIMES(sLoc, {1, 10, 2024}, "06:07", "18:06")    
elseif (sTheatre == "falklands") then
    sLoc = ""
elseif (sTheatre == "sinaiMap") then
    sLoc = ""
elseif (sTheatre == "kola") then
    sLoc = ""
elseif (sTheatre == "afghanistan") then
    sLoc = ""
end
]]