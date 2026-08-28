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
-- the port reproduced MiST byte for byte, quirks included, and every format is pinned by a test that
-- compares against a literal string. Both of those quirks have since been corrected, each on its own
-- merits and in its own lot: FIX-DMS-MINUTE-CARRY for the minute that would not carry into the degree,
-- FIX-ZERO-HEMISPHERE for the equator reading South.
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
--- Zero reads as **N** and **E**: the equator is neither north nor south and the prime meridian
--- neither east nor west, so a convention has to be picked, and zero is the positive side of both
--- axes everywhere else here. MiST tested `> 0` and put zero on the negative side; the port
--- reproduced that, and FIX-ZERO-HEMISPHERE corrected it.
---
--- Both layouts carry all the way up: seconds rounding to 60 carry into the minute, and a minute
--- reaching 60 carries into the degree. MiST's DMS branch stopped at the first of those and printed
--- `41 60' 00"N` where the decimal branch, three lines away, already said `42 00'`; the port
--- reproduced that, and FIX-DMS-MINUTE-CARRY corrected it.
---
--- @param lat number latitude in decimal degrees
--- @param lon number longitude in decimal degrees
--- @param acc number decimals on the last field; zero or less for none
--- @param dms boolean|nil true for degrees/minutes/seconds, false or nil for decimal minutes
--- @return string
function veafGeo.toStringLL(lat, lon, acc, dms)
  local latHemisphere = lat >= 0 and "N" or "S"
  local lonHemisphere = lon >= 0 and "E" or "W"

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
    if latMinWhole == 60 then
      latMinWhole = 0
      latDeg = latDeg + 1
    end
    if lonSec == 60 then
      lonSec = 0
      lonMinWhole = lonMinWhole + 1
    end
    if lonMinWhole == 60 then
      lonMinWhole = 0
      lonDeg = lonDeg + 1
    end

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
-- Zones and positions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The centre of a trigger zone, as a runtime vec3.
---
--- **Nil, not an empty table, when the zone does not exist.** MiST answered `{}` here, which is truthy
--- in Lua, so `veafCombatZone`'s own guard — *"Trigger zone [x] does not exist in the mission!"*, with
--- a pilot-facing message next to it — could never fire. Answering nil is what makes that guard work.
---
--- @param zoneName string the zone's name in the Mission Editor
--- @return table|nil the centre, or nil when no zone goes by that name
function veafGeo.zoneToVec3(zoneName)
  local zone = trigger.misc.getZone(zoneName)
  if not zone then
    return nil
  end
  return { x = zone.point.x, y = zone.point.y, z = zone.point.z }
end

--- The average position of a list of units, statics included.
---
--- Names that do not resolve, and objects that no longer exist, are skipped rather than counted as
--- the origin — an average that silently included `{0, 0, 0}` would drag the answer to the map corner.
---
--- @param unitNames table a list of unit or static object names
--- @return table|nil the average position as a vec3, or nil when nothing in the list exists
function veafGeo.getAvgPos(unitNames)
  local sumX, sumY, sumZ, count = 0, 0, 0, 0
  for _, name in ipairs(unitNames) do
    local object = Unit.getByName(name) or StaticObject.getByName(name)
    if object and object:isExist() then
      local position = object:getPosition().p
      if position then
        sumX = sumX + position.x
        sumY = sumY + position.y
        sumZ = sumZ + position.z
        count = count + 1
      end
    end
  end
  if count == 0 then
    return nil
  end
  return { x = sumX / count, y = sumY / count, z = sumZ / count }
end

--- The average position of a group's units.
---
--- @param groupName string|table a group name, or a group object
--- @return table|nil the average position as a vec3, or nil when the group is gone
function veafGeo.getAvgGroupPos(groupName)
  local group = groupName
  if type(groupName) == "string" then
    group = Group.getByName(groupName)
  end
  if not group or not group:isExist() then
    return nil
  end
  -- MiST walked getSize()/getUnit(i); getUnits() is the same list in one call, and it is the form
  -- every other VEAF module uses.
  local names = {}
  for _, unit in pairs(group:getUnits() or {}) do
    table.insert(names, unit:getName())
  end
  return veafGeo.getAvgPos(names)
end

--- Is a point inside a polygon?
---
--- Ray casting: count how many polygon edges a ray from the point crosses, and an odd count means
--- inside. The polygon closes itself, so the caller passes its corners once.
---
--- Corners come from the Mission Editor as `{ x, y }` with `y` as the easting (a mission-table vec2),
--- while the point being tested is usually a runtime vec3. Both go through `veaf.makeVec3`, which is
--- what lets the two shapes be mixed here — see docs/agents/dcs-coordinates.md.
---
--- @param point table the point, in either coordinate shape
--- @param polygon table the corners, in either coordinate shape
--- @param maxAltitude number|nil when given, a point above this altitude is outside whatever its
---   horizontal position
--- @return boolean
function veafGeo.pointInPolygon(point, polygon, maxAltitude)
  local vec = veaf.makeVec3(point)
  if maxAltitude and vec.y > maxAltitude then
    return false
  end

  local crossings = 0
  local corners = #polygon
  local previous = veaf.makeVec3(polygon[corners]) -- close the ring by starting on the last corner
  for index = 1, corners do
    local current = veaf.makeVec3(polygon[index])
    if (previous.z <= vec.z and current.z > vec.z) or (previous.z > vec.z and current.z <= vec.z) then
      local ratio = (vec.z - previous.z) / (current.z - previous.z)
      if vec.x < previous.x + ratio * (current.x - previous.x) then
        crossings = crossings + 1
      end
    end
    previous = current
  end
  return crossings % 2 == 1
end

--- The units of a list that stand inside a polygon.
---
--- A unit that has not been activated yet does not count as present; statics and other object
--- categories are taken as they are.
---
--- @param unitNames table a list of unit or static object names
--- @param polygon table the polygon's corners
--- @param maxAltitude number|nil an altitude ceiling, as in `pointInPolygon`
--- @return table the objects inside, in the order their names were given
function veafGeo.getUnitsInPolygon(unitNames, polygon, maxAltitude)
  local inside = {}
  for _, name in ipairs(unitNames) do
    local object = Unit.getByName(name) or StaticObject.getByName(name)
    if object and object:isExist() then
      local isInactiveUnit = Object.getCategory(object) == Object.Category.UNIT and not object:isActive()
      if not isInactiveUnit and veafGeo.pointInPolygon(object:getPosition().p, polygon, maxAltitude) then
        table.insert(inside, object)
      end
    end
  end
  return inside
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Framework façades. Callers use `veaf.*` and never name the implementation.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.toStringLL = veafGeo.toStringLL
veaf.toStringMGRS = veafGeo.toStringMGRS
veaf.zoneToVec3 = veafGeo.zoneToVec3
veaf.getAvgPos = veafGeo.getAvgPos
veaf.getAvgGroupPos = veafGeo.getAvgGroupPos
veaf.pointInPolygon = veafGeo.pointInPolygon
veaf.getUnitsInPolygon = veafGeo.getUnitsInPolygon

function veafGeo.initialize()
  veaf.loggers.get(veafGeo.Id):info("Initializing module")
end

veaf.loggers.get(veafGeo.Id):info(veaf.loggers.get(veafGeo.Id):getVersionInfo())
