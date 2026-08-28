------------------------------------------------------------------
-- VEAF geography for DCS World
-- By Zip (2026)
--
-- Features:
-- ---------
-- * Render a position as text: latitude/longitude in decimal minutes or in degrees/minutes/seconds,
--   and MGRS at any precision
--
-- The geodesy is DCS's own — `coord.LOtoLL` and `coord.LLtoMGRS` do the conversions, here and at every
-- call site. What lives here is the **text assembly** MiST used to provide, next to the parser that
-- already reads the same formats back (`veaf.lua`, on `coord.MGRStoLL` since FEAT-COORDINATE-FORMATS).
--
-- These strings go into F10 reports and briefings that mission makers have been reading for years, so
-- the port reproduces MiST byte for byte — including two places where MiST is visibly wrong. Both are
-- marked below and pinned by tests. Correcting them is a decision about what pilots read, not part of
-- removing a dependency.
------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafGeo = {}

--- Identifier. All output in the log will start with this.
veafGeo.Id = "GEO"

-- trace level, specific to this module (uncomment for debugging)
--veafGeo.LogLevel = "trace"

--- What separates the latitude from the longitude: a tab, then a space.
---
--- Not cosmetic. `veafNamedPoints` indexes into the result to insert a degree sign, and mission
--- briefings have been laid out around this spacing for years.
veafGeo.COORDINATE_SEPARATOR = "\t "

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.loggers.new(veafGeo.Id, veafGeo.LogLevel)

--- The format string for a fractional field: zero-padded, `acc` decimals, or a plain integer.
---
--- @param acc number number of decimals; zero or less means no decimal point at all
--- @return string a `string.format` specifier
local function fractionFormat(acc)
  if acc <= 0 then
    return "%02d"
  end
  return "%0" .. (3 + acc) .. "." .. acc .. "f" -- 01.310 is a width of 6 for acc = 3
end

--- Render a latitude and longitude as text.
---
--- Two layouts, both MiST's:
---   * decimal minutes — `42 21.00'N⇥ 43 34.07'E`
---   * degrees/minutes/seconds, with `dms` — `42 21' 00"N⇥ 43 34' 04"E`
---
--- **Zero reads as S and W.** The hemisphere test is `> 0`, so the equator and the prime meridian fall
--- on the southern and western side. Almost certainly not intended, kept because it is what pilots
--- have been reading.
---
--- **In DMS, a minute reaching 60 is printed as `60`.** Seconds rounding up carry into the minute, but
--- a minute reaching 60 does not carry into the degree, so `41.99999444` renders as `41 60' 00"N`
--- where the decimal branch would say `42 00'`. The decimal branch does carry — the asymmetry is
--- MiST's, and reproducing it is deliberate.
---
--- @param lat number latitude in decimal degrees
--- @param lon number longitude in decimal degrees
--- @param acc number decimals on the last field; zero or less for none
--- @param dms boolean|nil true for degrees/minutes/seconds, false or nil for decimal minutes
--- @return string
function veafGeo.toStringLL(lat, lon, acc, dms)
  local latHemisphere = lat > 0 and "N" or "S"
  local lonHemisphere = lon > 0 and "E" or "W"

  lat = math.abs(lat)
  lon = math.abs(lon)

  local latDeg = math.floor(lat)
  local latMin = (lat - latDeg) * 60
  local lonDeg = math.floor(lon)
  local lonMin = (lon - lonDeg) * 60

  if dms then
    local latMinWhole = math.floor(latMin)
    local latSec = veaf.round((latMin - latMinWhole) * 60, acc)
    local lonMinWhole = math.floor(lonMin)
    local lonSec = veaf.round((lonMin - lonMinWhole) * 60, acc)

    if latSec == 60 then
      latSec = 0
      latMinWhole = latMinWhole + 1
    end
    if lonSec == 60 then
      lonSec = 0
      lonMinWhole = lonMinWhole + 1
    end
    -- No carry from 60 minutes into the degree here: see the note above.

    local secondsFormat = fractionFormat(acc)
    return string.format("%02d %02d' " .. secondsFormat .. '"%s', latDeg, latMinWhole, latSec, latHemisphere)
      .. veafGeo.COORDINATE_SEPARATOR
      .. string.format("%02d %02d' " .. secondsFormat .. '"%s', lonDeg, lonMinWhole, lonSec, lonHemisphere)
  end

  latMin = veaf.round(latMin, acc)
  lonMin = veaf.round(lonMin, acc)

  if latMin == 60 then
    latMin = 0
    latDeg = latDeg + 1
  end
  if lonMin == 60 then
    lonMin = 0
    lonDeg = lonDeg + 1
  end

  local minutesFormat = fractionFormat(acc)
  return string.format("%02d " .. minutesFormat .. "'%s", latDeg, latMin, latHemisphere)
    .. veafGeo.COORDINATE_SEPARATOR
    .. string.format("%02d " .. minutesFormat .. "'%s", lonDeg, lonMin, lonHemisphere)
end

--- Render an MGRS grid reference as text.
---
--- `acc` is the number of digits kept for each of the easting and the northing: 5 is the full
--- ten-metre grid, 3 is a hundred-metre square, 0 is the square designator alone.
---
--- **Rounding can print one digit more than asked.** At `acc = 3` an easting of 99999 divides to
--- 999.99 and rounds to 1000, and the format pads to a minimum width rather than truncating, so
--- `1000` is printed. MiST's behaviour, kept.
---
--- @param mgrs table as returned by `coord.LLtoMGRS`: UTMZone, MGRSDigraph, Easting, Northing
--- @param acc number digits per axis, 0 to 5
--- @return string
function veafGeo.toStringMGRS(mgrs, acc)
  if acc == 0 then
    return mgrs.UTMZone .. " " .. mgrs.MGRSDigraph
  end
  local scale = 10 ^ (5 - acc)
  local digits = "%0" .. acc .. "d"
  return mgrs.UTMZone
    .. " "
    .. mgrs.MGRSDigraph
    .. " "
    .. string.format(digits, veaf.round(mgrs.Easting / scale, 0))
    .. " "
    .. string.format(digits, veaf.round(mgrs.Northing / scale, 0))
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Framework façades. Callers use `veaf.*` and never name the implementation.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.toStringLL = veafGeo.toStringLL
veaf.toStringMGRS = veafGeo.toStringMGRS

function veafGeo.initialize()
  veaf.loggers.get(veafGeo.Id):info("Initializing module")
end

veaf.loggers.get(veafGeo.Id):info(veaf.loggers.get(veafGeo.Id):getVersionInfo())
