------------------------------------------------------------------
-- VEAF maths, vectors and unit conversions for DCS World
-- By Zip (2026)
--
-- Features:
-- ---------
-- * Unit conversions (metres, nautical miles, feet, knots)
-- * Vector arithmetic on DCS vec3s, and the two coordinate shapes DCS uses
-- * A deep copy that survives cycles and carries metatables
--
-- These were MiST's, and DCS offers no equivalent — they are plain Lua arithmetic that MiST happened
-- to host. Ported at the surface VEAF actually calls, per the DROP-MIST doctrine.
--
-- Two arrivals did NOT need porting and are worth naming here, because the obvious move is to write
-- them again:
--   * `mist.utils.round` is `veaf.round` (veaf.lua) line for line — the call sites just moved.
--   * `mist.utils.toRadian` / `toDegree` are `math.rad` / `math.deg`. DCS offers no equivalent, but
--     Lua's standard library does, and it always did.
------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafMath = {}

--- Identifier. All output in the log will start with this.
veafMath.Id = "MATH"

-- trace level, specific to this module (uncomment for debugging)
--veafMath.LogLevel = "trace"

--- Metres in one nautical mile.
veafMath.METERS_PER_NAUTICAL_MILE = 1852

--- Metres in one foot.
veafMath.METERS_PER_FOOT = 0.3048

--- Seconds in one hour, for metres-per-second to knots.
veafMath.SECONDS_PER_HOUR = 3600

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.loggers.new(veafMath.Id, veafMath.LogLevel)

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Unit conversions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- @param meters number
--- @return number the same distance in nautical miles
function veafMath.metersToNM(meters)
  return meters / veafMath.METERS_PER_NAUTICAL_MILE
end

--- @param nm number
--- @return number the same distance in metres
function veafMath.NMToMeters(nm)
  return nm * veafMath.METERS_PER_NAUTICAL_MILE
end

--- @param meters number
--- @return number the same distance in feet
function veafMath.metersToFeet(meters)
  return meters / veafMath.METERS_PER_FOOT
end

--- @param feet number
--- @return number the same distance in metres
function veafMath.feetToMeters(feet)
  return feet * veafMath.METERS_PER_FOOT
end

--- @param mps number metres per second
--- @return number the same speed in knots
function veafMath.mpsToKnots(mps)
  return mps * veafMath.SECONDS_PER_HOUR / veafMath.METERS_PER_NAUTICAL_MILE
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Coordinate shapes
--
-- DCS uses two, and the same three letters mean different things in each — see
-- docs/agents/dcs-coordinates.md. A **mission-table vec2** is `{ x = northing, y = easting }`; a
-- **runtime vec3** is `{ x = northing, y = altitude, z = easting }`. Mixing them raises no error,
-- only a position a hundred kilometres from the intended one.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Turn a point of either shape into a runtime vec3.
---
--- Given a mission-table vec2, the easting moves from `y` to `z` and the altitude comes from `alt` on
--- the point, from the `alt` argument, or from zero — in that order of preference, the argument
--- winning. Given a vec3, the result is a fresh copy of it.
---
--- @param vec table a mission-table vec2 or a runtime vec3
--- @param alt number|nil altitude in metres, overriding the point's own `alt`
--- @return table a runtime vec3
function veafMath.makeVec3(vec, alt)
  if not vec.z then
    if vec.alt and not alt then
      alt = vec.alt
    elseif not alt then
      alt = 0
    end
    return { x = vec.x, y = alt, z = vec.y }
  end
  return { x = vec.x, y = vec.y, z = vec.z } -- already a vec3; copied so callers can mutate it
end

--- Turn a point of either shape into a mission-table vec2, dropping the altitude.
---
--- @param vec table a runtime vec3 or a mission-table vec2
--- @return table a mission-table vec2, `y` carrying the easting
function veafMath.makeVec2(vec)
  if vec.z then
    return { x = vec.x, y = vec.z }
  end
  return { x = vec.x, y = vec.y } -- already a vec2; copied so callers can mutate it
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Vectors
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- @param vec1 table a vec3
--- @param vec2 table a vec3
--- @return table their sum, as a new vec3
function veafMath.vecAdd(vec1, vec2)
  return { x = vec1.x + vec2.x, y = vec1.y + vec2.y, z = vec1.z + vec2.z }
end

--- @param vec table a vec3
--- @param mult number
--- @return table the vector scaled by `mult`, as a new vec3
function veafMath.vecScalarMult(vec, mult)
  return { x = vec.x * mult, y = vec.y * mult, z = vec.z * mult }
end

--- @param vec table a vec3
--- @return number its length
function veafMath.vecMag(vec)
  return (vec.x ^ 2 + vec.y ^ 2 + vec.z ^ 2) ^ 0.5
end

--- Horizontal distance between two points, altitude ignored.
---
--- Both points go through `makeVec3` first, so either coordinate shape is accepted: a mission-table
--- vec2's `y` is its easting and must not be read as an altitude.
---
--- @param point1 table a point of either shape
--- @param point2 table a point of either shape
--- @return number the distance in metres
function veafMath.get2DDist(point1, point2)
  local vec1 = veafMath.makeVec3(point1)
  local vec2 = veafMath.makeVec3(point2)
  return veafMath.vecMag({ x = vec1.x - vec2.x, y = 0, z = vec1.z - vec2.z })
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Direction
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The angle between the map grid's north and true north at a point.
---
--- DCS's map coordinates are a projection, so grid north and true north only coincide on the central
--- meridian. The correction is measured by asking where one degree of latitude further north lands.
---
--- @param gPoint table a point of either coordinate shape
--- @return number the correction in radians
function veafMath.getNorthCorrection(gPoint)
  local point = veafMath.makeVec3(gPoint)
  local lat, lon = coord.LOtoLL(point)
  local northPosition = coord.LLtoLO(lat + 1, lon)
  return math.atan2(northPosition.z - point.z, northPosition.x - point.x)
end

--- The direction a vector points in, in radians, wrapped into `[0, 2pi)`.
---
--- `x` is the northing and `z` the easting, so due east is a quarter turn. With a reference point,
--- the result is corrected to true north at that point rather than to grid north.
---
--- @param vec table a vec3
--- @param point table|nil where the direction is measured, for the true-north correction
--- @return number the direction in radians, in `[0, 2pi)`
function veafMath.getDir(vec, point)
  local dir = math.atan2(vec.z, vec.x)
  if point then
    dir = dir + veafMath.getNorthCorrection(point)
  end
  if dir < 0 then
    dir = dir + 2 * math.pi
  end
  return dir
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Deep copy
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Copy a value, recursing through tables.
---
--- Cycles are handled: a table already copied is reused, so a group whose route references the group
--- back copies once rather than recursing forever, and two fields sharing one table still share it
--- afterwards. Keys are copied too, and metatables are carried over — a spawn template's class
--- behaviour survives the copy.
---
--- @param object any
--- @return any a copy, or the value itself when it is not a table
function veafMath.deepCopy(object)
  local seen = {}
  local function copy(value)
    if type(value) ~= "table" then
      return value
    end
    if seen[value] then
      return seen[value]
    end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do
      result[copy(key)] = copy(item)
    end
    return setmetatable(result, getmetatable(value))
  end
  return copy(object)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Framework façades. Callers use `veaf.*` and never name the implementation.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.metersToNM = veafMath.metersToNM
veaf.NMToMeters = veafMath.NMToMeters
veaf.metersToFeet = veafMath.metersToFeet
veaf.feetToMeters = veafMath.feetToMeters
veaf.mpsToKnots = veafMath.mpsToKnots
veaf.makeVec3 = veafMath.makeVec3
veaf.makeVec2 = veafMath.makeVec2
veaf.vecAdd = veafMath.vecAdd
veaf.vecScalarMult = veafMath.vecScalarMult
veaf.vecMag = veafMath.vecMag
veaf.get2DDist = veafMath.get2DDist
veaf.getNorthCorrection = veafMath.getNorthCorrection
veaf.getDir = veafMath.getDir
veaf.deepCopy = veafMath.deepCopy

function veafMath.initialize()
  veaf.loggers.get(veafMath.Id):info("Initializing module")
end

veaf.loggers.get(veafMath.Id):info(veaf.loggers.get(veafMath.Id):getVersionInfo())
