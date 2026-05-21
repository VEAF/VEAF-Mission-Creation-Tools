# VEAF Lua Modules - Complete API Reference

**Version:** 6.0.5
**Last Updated:** December 16, 2025
**Project:** VEAF Mission Creation Tools

---

## Table of Contents

1. [Introduction](#introduction)
2. [Module Architecture](#module-architecture)
3. [Core Infrastructure](#core-infrastructure)
   - [veaf.lua](#veaflua) - Core utilities and logger
   - [veafEventHandler.lua](#veafeventhandlerlua) - Event management
   - [veafMarkers.lua](#veafmarkerslua) - Map marker system
   - [veafCommands.lua](#veafcommandslua) - Central command dispatcher
   - [veafInterpreter.lua](#veafinterpreterlua) - Command parsing
4. [Unit & Group Management](#unit--group-management)
   - [veafSpawn.lua](#veafspawnlua) - Dynamic spawning
   - [veafSpawnParser.lua](#veafspawnparserlua) - Spawn command text parser
   - [veafUnits.lua](#veafunitslua) - Unit definitions
   - [veafAssets.lua](#veafassetslua) - Asset tracking
   - [veafMove.lua](#veafmovelua) - Movement control
5. [Mission Systems](#mission-systems)
   - [veafCombatMission.lua](#veafcombatmissionlua) - Combat missions
   - [veafCasMission.lua](#veafcasmissionlua) - CAS missions
   - [veafCombatZone.lua](#veafcombatzonelua) - Combat zones
   - [veafTransportMission.lua](#veaftransportmissionlua) - Transport missions
6. [Infrastructure & Services](#infrastructure--services)
   - [veafAirbases.lua](#veafairbaseslua) - Airbase data
   - [veafCarrierOperations.lua](#veafcarrieroperationslua) - Carrier ops
   - [veafGrass.lua](#veafgrasslua) - Grass runways
   - [veafNamedPoints.lua](#veafnamedpointslua) - Named positions
7. [Communication & Control](#communication--control)
   - [veafRadio.lua](#veafradiolua) - Radio menus
   - [veafAirwaves.lua](#veafairwaveslua) - Radio frequencies
   - [veafRemote.lua](#veafremotelua) - Remote control
   - [veafSecurity.lua](#veafsecuritylua) - Access control
8. [Support Systems](#support-systems)
   - [veafWeather.lua](#veafweatherlua) - Weather system
   - [veafTime.lua](#veaftimelua) - Time management
   - [veafGroundAI.lua](#veafgroundailua) - Ground AI
   - [veafQraManager.lua](#veafqramanagerlua) - QRA system
9. [Specialized Modules](#specialized-modules)
   - [veafSkynetIadsHelper.lua](#veafskynetiadshelper) - IADS integration
   - [veafMissileGuardian.lua](#veafmissileguardianlua) - Missile defense
   - [veafCacheManager.lua](#veafcachemanagerlua) - Caching
10. [Data & Database](#data--database)
    - [dcsUnits.lua](#dcsunitslua) - DCS unit database
    - [dcsDataExport.lua](#dcsdataexportlua) - Data export

---

## Introduction

The VEAF (Virtual European Air Force) Lua modules provide a comprehensive framework for creating dynamic DCS World missions. This API reference documents all public functions, classes, and constants available to mission creators.

### Key Features

- **33+ Lua modules** providing runtime functionality
- **Event-driven architecture** using DCS World event system
- **Modular design** allowing selective module usage
- **Extensive logging** with configurable log levels
- **Security system** for controlled access
- **Radio menu integration** via F10 menu
- **Marker-based commands** using map markers

### Module Loading Order

Modules must be loaded in dependency order:
1. `veaf.lua` (core - must be first)
2. `veafEventHandler.lua`
3. `veafMarkers.lua`
4. Other modules (any order)

### Conventions Used

**Parameter Types:**
- `string` - Text string
- `number` - Numeric value
- `boolean` - true/false
- `table` - Lua table/array
- `vec3` - 3D vector: `{x=number, y=number, z=number}`
- `function` - Callback function
- `coalition` - Coalition ID: 0=neutral, 1=blue, 2=red

**Return Values:**
- Functions return `nil` on failure unless otherwise specified
- Boolean returns indicate success/failure

---

## Module Architecture

### Standard Module Structure

All VEAF modules follow this pattern:

```lua
-- Module declaration
veafModuleName = veafModuleName or {}

-- Module metadata
veafModuleName.Id = "MODULE_ID"
veafModuleName.Version = "X.Y.Z"
veafModuleName.LogLevel = "info"  -- or "debug", "trace"

-- Logger initialization
veafModuleName.logger = veaf.loggers.new(veafModuleName.Id, veafModuleName.LogLevel)

-- Initialization function
function veafModuleName.initialize()
  veafModuleName.logger:info("Initializing module")
  -- Initialization code
end

-- Start function (if applicable)
function veafModuleName.start()
  veafModuleName.logger:info("Starting module")
  -- Start monitoring/services
end
```

### Logging Levels

All modules use standardized logging:

| Level | Value | Usage |
|-------|-------|-------|
| `error` | 1 | Critical errors only |
| `warning` | 2 | Warnings and errors |
| `info` | 3 | Normal operations (default) |
| `debug` | 4 | Detailed debugging |
| `trace` | 5 | Very verbose tracing |

**Setting Log Levels:**
```lua
veafModuleName.LogLevel = "debug"
veaf.loggers.setBaseLevel("info")  -- Global default
```

---

## Core Infrastructure

### veaf.lua

**Module ID:** `VEAF`
**Version:** 1.56.2
**Purpose:** Root library providing core utilities, constants, and logger system

#### Constants

```lua
veaf.Version = "1.56.2"
veaf.Development = false  -- Enable development features
veaf.HideNamesFromSpawnedGroups = false
veaf.BaseLogLevel = 3  -- Default log level (info); acts as a cap for module log levels
veaf.DEFAULT_GROUND_SPEED_KPH = 30
veaf.DEFAULT_GROUND_SPEED_KTS = 16.2
veaf.DEFAULT_SPEED_KTS = 350
veaf.MIST_MARKER_ID_INITIAL_VALUE = 50000
```

#### JSON Functions

##### `veaf.json.stringify(obj, as_key)`

Convert Lua object to JSON string.

**Parameters:**
- `obj` (any) - Lua object to serialize
- `as_key` (boolean, optional) - Format as JSON key

**Returns:** `string` - JSON representation

**Example:**
```lua
local data = {name = "Strike", type = "mission"}
local json = veaf.json.stringify(data)
-- Result: '{"name":"Strike","type":"mission"}'
```

##### `veaf.json.parse(str, pos, end_delim)`

Parse JSON string to Lua object.

**Parameters:**
- `str` (string) - JSON string
- `pos` (number, optional) - Starting position (default: 1)
- `end_delim` (string, optional) - End delimiter

**Returns:** `table` - Parsed Lua object

**Example:**
```lua
local json = '{"name":"Strike","type":"mission"}'
local data = veaf.json.parse(json)
-- Result: {name = "Strike", type = "mission"}
```

#### String Utilities

##### `veaf.trim(s)`

Remove leading and trailing whitespace.

**Parameters:**
- `s` (string) - String to trim

**Returns:** `string` - Trimmed string

**Example:**
```lua
local trimmed = veaf.trim("  hello  ")
-- Result: "hello"
```

##### `veaf.split(str, sep)`

Split string by separator into array.

**Parameters:**
- `str` (string) - String to split
- `sep` (string) - Separator character/string

**Returns:** `table` - Array of substrings

**Example:**
```lua
local parts = veaf.split("red,blue,green", ",")
-- Result: {"red", "blue", "green"}
```

##### `veaf.splitWithPattern(str, pat)`

Split string using regex pattern.

**Parameters:**
- `str` (string) - String to split
- `pat` (string) - Lua pattern

**Returns:** `table` - Array of substrings

##### `veaf.breakString(str, sep)`

Break string around separator (returns 2 parts).

**Parameters:**
- `str` (string) - String to break
- `sep` (string) - Separator

**Returns:** `string, string` - Two parts (before and after separator)

**Example:**
```lua
local before, after = veaf.breakString("key=value", "=")
-- Result: before="key", after="value"
```

##### `veaf.escapeRegex(stringToEscape)`

Escape special regex characters.

**Parameters:**
- `stringToEscape` (string) - String to escape

**Returns:** `string` - Escaped string

#### Table/Array Utilities

##### `veaf.length(T)`

Get table length (handles non-sequential keys).

**Parameters:**
- `T` (table) - Table to measure

**Returns:** `number` - Number of elements

**Example:**
```lua
local t = {a=1, b=2, c=3}
local len = veaf.length(t)
-- Result: 3
```

##### `veaf.arrayRemoveWhen(t, fnKeep)`

Remove elements from array based on condition.

**Parameters:**
- `t` (table) - Array to filter
- `fnKeep` (function) - Keep function: `function(element) return boolean end`

**Returns:** `table` - Modified array

**Example:**
```lua
local numbers = {1, 2, 3, 4, 5}
veaf.arrayRemoveWhen(numbers, function(n) return n > 3 end)
-- Result: {1, 2, 3}
```

##### `veaf.shuffle(tbl)`

Randomly shuffle array elements in place.

**Parameters:**
- `tbl` (table) - Array to shuffle

**Returns:** `table` - Shuffled array (same reference)

##### `veaf.tableContains(table, element)`

Check if table contains element.

**Parameters:**
- `table` (table) - Table to search
- `element` (any) - Element to find

**Returns:** `boolean` - True if found

##### `veaf.randomlyChooseFrom(aTable, bias)`

Choose random element from table with optional bias.

**Parameters:**
- `aTable` (table) - Table to choose from
- `bias` (number, optional) - Bias factor (default: 1.0)

**Returns:** `any` - Random element

**Example:**
```lua
local colors = {"red", "blue", "green"}
local color = veaf.randomlyChooseFrom(colors)
```

#### Vector & Coordinate Functions

##### `veaf.vecToString(vec)`

Convert 3D vector to human-readable string.

**Parameters:**
- `vec` (vec3) - Vector `{x, y, z}`

**Returns:** `string` - Formatted string

**Example:**
```lua
local pos = {x=1000, y=50, z=2000}
local str = veaf.vecToString(pos)
-- Result: "x=1000, y=50, z=2000"
```

##### `veaf.findPointInZone(spawnSpot, dispersion, isShip)`

Find random spawn point within zone with dispersion.

**Parameters:**
- `spawnSpot` (vec3) - Center position
- `dispersion` (number) - Radius in meters
- `isShip` (boolean, optional) - Find water location

**Returns:** `vec3` - Random point within zone

##### `veaf.placePointOnLand(vec3)`

Place point on land surface (adjusts Y altitude).

**Parameters:**
- `vec3` (vec3) - Position to adjust

**Returns:** `vec3` - Position on land surface

##### `veaf.getLandHeight(vec3)`

Get terrain height at coordinates.

**Parameters:**
- `vec3` (vec3) - Position

**Returns:** `number` - Terrain altitude in meters

##### `veaf.headingBetweenPoints(point1, point2)`

Calculate heading from point1 to point2.

**Parameters:**
- `point1` (vec3) - Starting point
- `point2` (vec3) - Destination point

**Returns:** `number` - Heading in degrees (0-360)

##### `veaf.getBearingAndRangeFromTo(fromPoint, toPoint)`

Calculate bearing and range between two points.

**Parameters:**
- `fromPoint` (vec3) - Starting point
- `toPoint` (vec3) - Destination point

**Returns:** `number, number` - Bearing (degrees), Range (meters)

**Example:**
```lua
local bearing, range = veaf.getBearingAndRangeFromTo(pos1, pos2)
veaf.logger:info("Target at %d° for %.0f meters", bearing, range)
```

##### `veaf.computeLLFromString(value)`

Parse latitude/longitude from string.

**Parameters:**
- `value` (string) - Lat/Lon string (various formats supported)

**Returns:** `table` - `{lat=number, lon=number}` or nil

**Supported Formats:**
- DMS: `N 43°15'30" E 005°45'20"`
- Decimal: `43.258333, 5.755556`
- MGRS: (via conversion)

##### `veaf.computeCoordinatesOffsetFromRoute(startingPoint, destinationPoint, distanceFromStartingPoint, offset)`

Calculate position offset from a route.

**Parameters:**
- `startingPoint` (vec3) - Route start
- `destinationPoint` (vec3) - Route end
- `distanceFromStartingPoint` (number) - Distance along route (meters)
- `offset` (number) - Perpendicular offset (meters, positive = right)

**Returns:** `vec3` - Offset position

#### Unit & Group Functions

##### `veaf.addUnit(group, spawnSpot, dispersion, unitType, unitName, skill)`

Add unit to group definition.

**Parameters:**
- `group` (table) - Group definition table
- `spawnSpot` (vec3) - Spawn position
- `dispersion` (number) - Dispersion radius (meters)
- `unitType` (string) - DCS unit type name
- `unitName` (string) - Unit name
- `skill` (string) - Skill level: "Average", "Good", "High", "Excellent", "Random"

**Returns:** `table` - Modified group table

##### `veaf.getAveragePosition(group)`

Get center position of group.

**Parameters:**
- `group` (table or DCS Group) - Group object or table

**Returns:** `vec3` - Average position

##### `veaf.getAvgGroupPos(groupName)`

Get average position of group by name.

**Parameters:**
- `groupName` (string) - Group name

**Returns:** `vec3` - Average position or nil

##### `veaf.moveGroupAt(groupName, leadUnitName, heading, speed, timeInSeconds, endPosition, pMiddlePointDistance)`

Move group in specific direction and speed.

**Parameters:**
- `groupName` (string) - Group to move
- `leadUnitName` (string) - Lead unit name
- `heading` (number) - Direction in degrees
- `speed` (number) - Speed in m/s
- `timeInSeconds` (number) - Duration of movement
- `endPosition` (vec3, optional) - Final position
- `pMiddlePointDistance` (number, optional) - Intermediate waypoint distance

**Returns:** `boolean` - Success flag

##### `veaf.moveGroupTo(groupName, pos, speed, altitude)`

Move group to position.

**Parameters:**
- `groupName` (string) - Group name
- `pos` (vec3) - Destination
- `speed` (number, optional) - Speed in m/s (default: 30 kph)
- `altitude` (number, optional) - Altitude override

**Returns:** `boolean` - Success

##### `veaf.readyForCombat(group, alarm, disperseTime)`

Prepare ground group for combat.

**Parameters:**
- `group` (DCS Group or string) - Group or group name
- `alarm` (boolean, optional) - Alarm state (default: false)
- `disperseTime` (number, optional) - Time to disperse in seconds

**Returns:** None

**Description:** Sets group to combat ready state, optionally disperses units.

##### `veaf.getGroupsOfCoalition(coa)`

Get all groups of coalition.

**Parameters:**
- `coa` (coalition, optional) - Coalition filter (default: all)

**Returns:** `table` - Array of DCS Group objects

##### `veaf.getUnitsOfCoalition(includeStatics, coa)`

Get all units of coalition.

**Parameters:**
- `includeStatics` (boolean) - Include static objects
- `coa` (coalition, optional) - Coalition filter

**Returns:** `table` - Array of unit/static objects

##### `veaf.findUnitsInCircle(center, radius, includeStatics, onlyTheseUnits)`

Find units in circular area.

**Parameters:**
- `center` (vec3) - Circle center
- `radius` (number) - Radius in meters
- `includeStatics` (boolean, optional) - Include statics
- `onlyTheseUnits` (table, optional) - Filter to these units only

**Returns:** `table` - Array of units/statics

**Example:**
```lua
local targetPos = {x=1000, y=0, z=2000}
local enemyUnits = veaf.findUnitsInCircle(targetPos, 500, false)
veaf.logger:info("Found %d enemy units", #enemyUnits)
```

##### `veaf.isUnitInZone(unitOrName, zoneOrName)`

Check if unit is inside trigger zone.

**Parameters:**
- `unitOrName` (DCS Unit or string) - Unit or unit name
- `zoneOrName` (DCS Zone or string) - Zone or zone name

**Returns:** `boolean` - True if inside zone

##### `veaf.isUnitAlive(unit)`

Check if unit is alive.

**Parameters:**
- `unit` (DCS Unit or string) - Unit or unit name

**Returns:** `boolean` - True if alive

##### `veaf.getUnitLifeRelative(unit)`

Get unit health as percentage.

**Parameters:**
- `unit` (DCS Unit or string) - Unit or unit name

**Returns:** `number` - Health percentage (0-100)

##### `veaf.fixUnitsTable(unitsOrNames)`

Convert unit names to unit objects.

**Parameters:**
- `unitsOrNames` (table) - Array of units or unit names

**Returns:** `table` - Array of unit objects

#### Route Generation

##### `veaf.generateVehiclesRoute(startPoint, destination, onRoad, speed, groupName)`

Generate vehicle movement route.

**Parameters:**
- `startPoint` (vec3) - Starting position
- `destination` (vec3) - Destination position
- `onRoad` (boolean) - Use roads when possible
- `speed` (number) - Speed in m/s
- `groupName` (string, optional) - Group name for logging

**Returns:** `table` - Route table

**Route Table Structure:**
```lua
{
  [1] = {
    x = number,
    y = number,
    action = "On Road" or "Off Road",
    speed = number,
    type = "Turning Point"
  },
  -- ... more waypoints
}
```

##### `veaf.PatrolWatchdog(groupName, patrolRoute, speed, firstPass)`

Monitor patrol route and repeat.

**Parameters:**
- `groupName` (string) - Group name
- `patrolRoute` (table) - Route table
- `speed` (number) - Speed in m/s
- `firstPass` (boolean) - Is first iteration

**Returns:** None (schedules itself)

#### Information Functions

##### `veaf.getTankerData(tankerGroupName)`

Get tanker information.

**Parameters:**
- `tankerGroupName` (string) - Tanker group name

**Returns:** `table` - Tanker data structure

**Tanker Data Structure:**
```lua
{
  name = "Texaco-1",
  type = "KC-135",
  TACANchannel = "61X",
  TACANfrequency = "1088 MHz",
  TACANmorse = "\u2013\u2022 \u2022\u2022\u2022\u2022 \u2013\u2022\u2022",
  RadioFrequency = "251.0 MHz",
  RadioModulation = "AM",
  callsign = "Texaco 1-1",
  position = vec3
}
```

##### `veaf.getCarrierATCdata(carrierGroupName, carrierUnitName)`

Get carrier ATC information.

**Parameters:**
- `carrierGroupName` (string) - Carrier group name
- `carrierUnitName` (string, optional) - Specific unit name

**Returns:** `table` - ATC data

**ATC Data Structure:**
```lua
{
  name = "CVN-73",
  callsign = "Mother",
  RadioFrequency = "127.5 MHz",
  RadioModulation = "AM",
  TACANchannel = "73X",
  TACANfrequency = "1205 MHz",
  TACANmorse = "\u2013\u2022\u2022\u2022 \u2022\u2022\u2022\u2013 \u2013\u2022\u2022",
  ICLS = "13",
  position = vec3,
  heading = number
}
```

##### `veaf.getGroupData(groupIdent)`

Get raw DCS group data.

**Parameters:**
- `groupIdent` (string or number) - Group name or ID

**Returns:** `table` - DCS group data table

##### `veaf.weatherReport(vec3, alt, withLASTE)`

Generate weather report string.

**Parameters:**
- `vec3` (vec3) - Position for report
- `alt` (number, optional) - Altitude for report (default: 0)
- `withLASTE` (boolean, optional) - Include LASTE data

**Returns:** `string` - Weather report text

**Example Output:**
```
Weather at position:
QNH: 29.92 inHg (1013 hPa)
Temperature: 15°C (59°F)
Wind: 270° at 10 kts
```

#### Output Functions

##### `veaf.outTextForUnit(unitName, message, duration, forAllGroup)`

Display text message to unit.

**Parameters:**
- `unitName` (string) - Target unit name
- `message` (string) - Message text
- `duration` (number, optional) - Display duration in seconds (default: 5)
- `forAllGroup` (boolean, optional) - Show to all group members

**Returns:** None

**Example:**
```lua
veaf.outTextForUnit("Viper 1-1", "Target destroyed!", 10, true)
```

##### `veaf.outTextForGroup(unitName, message, duration)`

Display text to entire group.

**Parameters:**
- `unitName` (string) - Any unit in group
- `message` (string) - Message text
- `duration` (number, optional) - Duration in seconds

**Returns:** None

#### Conversion Functions

##### `veaf.convertMachSpeed(mach, altitude, temperature)`

Convert Mach number to true airspeed.

**Parameters:**
- `mach` (number) - Mach number
- `altitude` (number) - Altitude in meters
- `temperature` (number, optional) - Temperature offset in °C

**Returns:** `number` - True airspeed in knots

##### `veaf.convertTrueAirSpeed(ktas, altitude, temperature)`

Convert true airspeed to Mach.

**Parameters:**
- `ktas` (number) - True airspeed in knots
- `altitude` (number) - Altitude in meters
- `temperature` (number, optional) - Temperature offset

**Returns:** `number` - Mach number

##### `veaf.convertSpeeds(mach, kias, ktas, altitude, temperature, pressure)`

Convert between speed formats.

**Parameters:**
- `mach` (number, optional) - Mach number
- `kias` (number, optional) - Indicated airspeed (knots)
- `ktas` (number, optional) - True airspeed (knots)
- `altitude` (number) - Altitude in meters
- `temperature` (number, optional) - Temperature offset
- `pressure` (number, optional) - Pressure in hPa

**Returns:** `table` - `{mach, kias, ktas}`

**Example:**
```lua
local speeds = veaf.convertSpeeds(0.9, nil, nil, 10000)
-- Result: {mach=0.9, kias=calculated, ktas=calculated}
```

##### `veaf.getMagneticDeclination()`

Get magnetic declination for current theater.

**Returns:** `number` - Declination in degrees

##### `veaf.getWind(point)`

Get wind at position.

**Parameters:**
- `point` (vec3) - Position

**Returns:** `table` - `{direction=number, strength=number}`

#### Math & Utility Functions

##### `veaf.round(num, numDecimalPlaces)`

Round number to decimal places.

**Parameters:**
- `num` (number) - Number to round
- `numDecimalPlaces` (number, optional) - Decimal places (default: 0)

**Returns:** `number` - Rounded number

##### `veaf.getRandomizableNumeric(val)`

Parse randomizable numeric value.

**Parameters:**
- `val` (string or number) - Value like "2-6" or "5"

**Returns:** `number` - Random value in range

**Example:**
```lua
local size = veaf.getRandomizableNumeric("3-7")
-- Result: Random number between 3 and 7
```

##### `veaf.invertHeading(heading)`

Get opposite heading.

**Parameters:**
- `heading` (number) - Heading in degrees

**Returns:** `number` - Opposite heading (0-360)

##### `veaf.laserCodeToDigit(code)`

Convert laser code to digit.

**Parameters:**
- `code` (number) - Laser code (e.g., 1688)

**Returns:** `number` - Digit representation

#### Country & Coalition Functions

##### `veaf.getCountryId(countryName)`

Get DCS country ID from name.

**Parameters:**
- `countryName` (string) - Country name (e.g., "USA", "Russia")

**Returns:** `number` - Country ID or nil

##### `veaf.getCountryName(countryId)`

Get country name from ID.

**Parameters:**
- `countryId` (number) - DCS country ID

**Returns:** `string` - Country name

##### `veaf.getCountryForCoalition(coalition)`

Get default country for coalition.

**Parameters:**
- `coalition` (coalition) - Coalition ID

**Returns:** `number` - Country ID

**Default Mapping:**
- Blue → USA (2)
- Red → Russia (0)

##### `veaf.getCoalitionForCountry(countryName, asNumber)`

Get coalition for country.

**Parameters:**
- `countryName` (string) - Country name
- `asNumber` (boolean, optional) - Return as number instead of coalition object

**Returns:** `coalition` or `number` - Coalition

##### `veaf.getAirbaseForCoalition(airbase_name, coa)`

Get airbase object for coalition.

**Parameters:**
- `airbase_name` (string) - Airbase name
- `coa` (coalition) - Coalition

**Returns:** `DCS Airbase` - Airbase object or nil

#### Airbase Functions

##### `veaf.findDcsAirbase(name)`

Find DCS airbase by name (case-insensitive).

**Parameters:**
- `name` (string) - Airbase name

**Returns:** `DCS Airbase` - Airbase object or nil

##### `veaf.silenceAtcOnAllAirbases()`

Disable ATC on all airbases.

**Returns:** None

**Description:** Useful for immersion or to prevent ATC conflicts.

##### `veaf.loadAirbasesLife0()`

Load airbase initial health data.

**Returns:** None

**Description:** Must be called before using `veaf.getAirbaseLife()`.

##### `veaf.getAirbaseLife(airbase_name, percentage, loading)`

Get airbase health/damage.

**Parameters:**
- `airbase_name` (string) - Airbase name
- `percentage` (boolean, optional) - Return as percentage
- `loading` (boolean, optional) - Loading initial data

**Returns:** `number` - Health value (0-1 or 0-100 if percentage)

##### `veaf.getPolygonFromUnits(unitNames)`

Create polygon from unit positions.

**Parameters:**
- `unitNames` (table) - Array of unit names

**Returns:** `table` - Array of vec3 positions

#### Trigger Zone Functions

##### `veaf.getTriggerZone(zoneName)`

Get trigger zone by name.

**Parameters:**
- `zoneName` (string) - Zone name

**Returns:** `DCS Zone` - Zone object or nil

#### Mission Control Functions

##### `veaf.endMissionAt(endTimeHour, endTimeMinute, checkIntervalInSeconds, checkMessage, ...)`

Schedule mission end at specific time.

**Parameters:**
- `endTimeHour` (number) - Hour (0-23)
- `endTimeMinute` (number) - Minute (0-59)
- `checkIntervalInSeconds` (number) - Check frequency
- `checkMessage` (string, optional) - Message to display
- Additional parameters for message formatting

**Returns:** None

**Example:**
```lua
-- End mission at 14:30 (2:30 PM)
veaf.endMissionAt(14, 30, 60, "Mission ends at %s")
```

##### `veaf.getDcsTypeName(dcsElementName)`

Get DCS type name from element name.

**Parameters:**
- `dcsElementName` (string) - DCS element name

**Returns:** `string` - Type name

#### Serialization Functions

##### `veaf.p(o, level, skip, includeMeta, dontRecurse)`

Pretty-print/serialize object.

**Parameters:**
- `o` (any) - Object to serialize
- `level` (number, optional) - Indentation level
- `skip` (table, optional) - Keys to skip
- `includeMeta` (boolean, optional) - Include metatables
- `dontRecurse` (table, optional) - Objects not to recurse

**Returns:** `string` - Serialized representation

**Example:**
```lua
local data = {name = "Strike", units = {1, 2, 3}}
local str = veaf.p(data)
print(str)
-- Output:
-- {
--   name = "Strike",
--   units = {
--     [1] = 1,
--     [2] = 2,
--     [3] = 3
--   }
-- }
```

##### `veaf.serialize(name, value, level)`

Serialize value to Lua code string.

**Parameters:**
- `name` (string) - Variable name
- `value` (any) - Value to serialize
- `level` (number, optional) - Indentation level

**Returns:** `string` - Lua code string

##### `veaf.exportAsJson(data, name, jsonify, filename, export_path)`

Export data to JSON file.

**Parameters:**
- `data` (any) - Data to export
- `name` (string) - Variable name
- `jsonify` (boolean) - Convert to JSON (vs Lua)
- `filename` (string, optional) - Output filename
- `export_path` (string, optional) - Export directory path

**Returns:** `boolean` - Success flag

**Example:**
```lua
local missions = {
  {name = "CAP Alpha", type = "air"},
  {name = "Strike Bravo", type = "ground"}
}
veaf.exportAsJson(missions, "missions", true, "missions.json")
```

#### Logger Class

The `veaf.Logger` class provides structured logging with levels.

##### Creating Loggers

```lua
-- Global loggers
veaf.loggers.setBaseLevel("info")  -- Set default level
local logger = veaf.loggers.new("MYMODULE", "debug")  -- Create logger
local existingLogger = veaf.loggers.get("MYMODULE")  -- Get existing

-- Instance loggers
local myLogger = veaf.Logger:new("MYMODULE", "info")
```

##### Logger Methods

**`logger:setName(value)`**

Set logger name.

**`logger:setLevel(value, force)`**

Set logging level.

**Parameters:**
- `value` (string or number) - Level: "error", "warning", "info", "debug", "trace"
- `force` (boolean, optional) - Force override base level

**`logger:error(text, ...)`**

Log error message (level 1).

**Parameters:**
- `text` (string) - Message with format placeholders
- `...` - Format arguments

**Example:**
```lua
logger:error("Failed to spawn %s at position %s", groupName, veaf.vecToString(pos))
```

**`logger:warn(text, ...)`**

Log warning message (level 2).

**`logger:info(text, ...)`**

Log info message (level 3).

**`logger:debug(text, ...)`**

Log debug message (level 4).

**`logger:trace(text, ...)`**

Log trace message (level 5).

**`logger:wouldLogDebug()`**

Check if debug logging enabled.

**Returns:** `boolean`

**`logger:wouldLogTrace()`**

Check if trace logging enabled.

**Returns:** `boolean`

**Usage:**
```lua
if logger:wouldLogTrace() then
  -- Expensive trace logging
  logger:trace("Complex data: %s", veaf.p(largeTable))
end
```

##### Map Marker Logging

**`logger:marker(id, header, message, position, markersTable, radius, fillColor)`**

Add map marker for debugging.

**Parameters:**
- `id` (number) - Marker ID
- `header` (string) - Marker header text
- `message` (string) - Marker message
- `position` (vec3) - Marker position
- `markersTable` (table, optional) - Track markers in table
- `radius` (number, optional) - Circle radius
- `fillColor` (table, optional) - Fill color `{r, g, b, a}`

**Returns:** None

**`logger:markerArrow(id, header, message, positionStart, positionEnd, markersTable, lineType, fillColor)`**

Add arrow marker.

**Parameters:**
- `id` (number) - Marker ID
- `header` (string) - Header text
- `message` (string) - Message
- `positionStart` (vec3) - Arrow start
- `positionEnd` (vec3) - Arrow end
- `markersTable` (table, optional) - Track markers
- `lineType` (number, optional) - Line type
- `fillColor` (table, optional) - Color

**`logger:markerQuad(id, header, message, points, markersTable, lineType, fillColor)`**

Add quadrilateral marker.

**Parameters:**
- `id` (number) - Marker ID
- `header` (string) - Header
- `message` (string) - Message
- `points` (table) - Array of 4 vec3 points
- `markersTable` (table, optional) - Track markers
- `lineType` (number, optional) - Line type
- `fillColor` (table, optional) - Color

---

### veafEventHandler.lua

**Module ID:** `EVENTS`
**Version:** 1.5.3
**Purpose:** DCS World event handling and callback management

#### Constants

##### Event Types

```lua
veafEventHandler.EVENTS = {
  [0] = "S_EVENT_INVALID",
  [1] = "S_EVENT_SHOT",
  [2] = "S_EVENT_HIT",
  [3] = "S_EVENT_TAKEOFF",
  [4] = "S_EVENT_LAND",
  [5] = "S_EVENT_CRASH",
  [6] = "S_EVENT_EJECTION",
  [7] = "S_EVENT_REFUELING",
  [8] = "S_EVENT_DEAD",
  [9] = "S_EVENT_PILOT_DEAD",
  [10] = "S_EVENT_BASE_CAPTURED",
  [11] = "S_EVENT_MISSION_START",
  [12] = "S_EVENT_MISSION_END",
  [13] = "S_EVENT_TOOK_CONTROL",
  [14] = "S_EVENT_REFUELING_STOP",
  [15] = "S_EVENT_BIRTH",
  [16] = "S_EVENT_HUMAN_FAILURE",
  [17] = "S_EVENT_DETAILED_FAILURE",
  [18] = "S_EVENT_ENGINE_STARTUP",
  [19] = "S_EVENT_ENGINE_SHUTDOWN",
  [20] = "S_EVENT_PLAYER_ENTER_UNIT",
  [21] = "S_EVENT_PLAYER_LEAVE_UNIT",
  [22] = "S_EVENT_PLAYER_COMMENT",
  [23] = "S_EVENT_SHOOTING_START",
  [24] = "S_EVENT_SHOOTING_END",
  [25] = "S_EVENT_MARK_ADDED",
  [26] = "S_EVENT_MARK_CHANGE",
  [27] = "S_EVENT_MARK_REMOVED",
  [28] = "S_EVENT_KILL",
  [29] = "S_EVENT_SCORE",
  [30] = "S_EVENT_UNIT_LOST",
  [31] = "S_EVENT_LANDING_AFTER_EJECTION",
  [32] = "S_EVENT_PARATROOPER_LENDING",
  [33] = "S_EVENT_DISCARD_CHAIR_AFTER_EJECTION",
  [34] = "S_EVENT_WEAPON_ADD",
  [35] = "S_EVENT_TRIGGER_ZONE",
  -- ... up to event 61
}
```

##### Callback Delay

```lua
veafEventHandler.CALLBACK_DELAY = 0.5  -- seconds
```

#### Functions

##### `veafEventHandler.addCallback(name, events, callback)`

Register event callback function.

**Parameters:**
- `name` (string) - Unique callback name
- `events` (table or nil) - Array of event IDs/names, or nil for all events
- `callback` (function) - Callback function

**Callback Signature:**
```lua
function callback(transformedEvent)
  -- transformedEvent is enhanced event table
end
```

**Returns:** `boolean` - True if registered successfully

**Example:**
```lua
-- Listen to all events
veafEventHandler.addCallback("myHandler", nil, function(event)
  veaf.logger:info("Event: %s", event.type.name)
end)

-- Listen to specific events
veafEventHandler.addCallback("birthHandler",
  {"S_EVENT_BIRTH", "S_EVENT_PLAYER_ENTER_UNIT"},
  function(event)
    if event.initiator then
      veaf.logger:info("Unit spawned: %s", event.initiator.unitName)
    end
  end
)

-- Listen by event ID
veafEventHandler.addCallback("shotHandler", {1, 23}, function(event)
  -- Handle S_EVENT_SHOT and S_EVENT_SHOOTING_START
end)
```

##### `veafEventHandler.completeUnit(unit)`

Get complete unit information from DCS unit.

**Parameters:**
- `unit` (DCS Unit) - Unit object

**Returns:** `table` - Unit info table

**Unit Info Structure:**
```lua
{
  unitName = "Viper 1-1",
  unitCallsign = "Viper11",
  unitType = "F-16C_50",
  unitGroupName = "Viper Flight",
  unitGroupId = 123,
  unitCoalition = coalition.side.BLUE,
  unitCategory = Unit.Category.AIRPLANE,
  unitPilotName = "Player Name",  -- if human
  unitPilotUcid = "abc123...",    -- if human with SRS
  unitLifePercent = 100.0
}
```

##### `veafEventHandler.completeUnitFromName(unitName)`

Get unit information from unit name.

**Parameters:**
- `unitName` (string) - Unit name

**Returns:** `table` - Unit info table (same as completeUnit)

**Example:**
```lua
local unitInfo = veafEventHandler.completeUnitFromName("Viper 1-1")
if unitInfo then
  veaf.logger:info("Unit %s is at %.0f%% health",
    unitInfo.unitName, unitInfo.unitLifePercent)
end
```

##### `veafEventHandler.checkEventKnown(eventNameOrId, warnOnly)`

Validate event is recognized by DCS.

**Parameters:**
- `eventNameOrId` (string or number) - Event name or ID
- `warnOnly` (boolean, optional) - Only warn, don't error

**Returns:** `boolean` - True if event is known

##### `veafEventHandler.setEventEnabled(eventNameOrId, enabled)`

Enable or disable event processing.

**Parameters:**
- `eventNameOrId` (string or number) - Event to control
- `enabled` (boolean) - Enable flag

**Returns:** None

**Example:**
```lua
-- Disable shooting events for performance
veafEventHandler.setEventEnabled("S_EVENT_SHOOTING_START", false)
veafEventHandler.setEventEnabled("S_EVENT_SHOOTING_END", false)
```

##### `veafEventHandler.isEventEnabled(eventNameOrId)`

Check if event processing is enabled.

**Parameters:**
- `eventNameOrId` (string or number) - Event to check

**Returns:** `boolean` - True if enabled

##### `veafEventHandler.isEventDelayedCallback(eventNameOrId)`

Check if event uses delayed callback.

**Parameters:**
- `eventNameOrId` (string or number) - Event to check

**Returns:** `boolean` - True if delayed

**Description:** Some events like BIRTH need delayed callbacks to allow DCS to fully initialize objects.

##### `veafEventHandler.initialize()`

Initialize event handler system.

**Returns:** None

**Description:** Called automatically by VEAF initialization. Registers DCS world event handler.

#### Transformed Event Structure

Events passed to callbacks are enhanced with additional fields:

```lua
{
  -- Original DCS event fields
  id = number,                    -- DCS event ID
  time = number,                  -- Mission time
  initiator = DCS_Unit,           -- Unit that triggered event
  target = DCS_Unit,              -- Target unit (if applicable)
  weapon = DCS_Weapon,            -- Weapon object (if applicable)
  place = DCS_Airbase,            -- Airbase (for takeoff/land)

  -- VEAF enhancements
  type = {                        -- Event type info
    id = number,
    name = "S_EVENT_XXX",
    definition = event_definition
  },
  idx = number,                   -- Event index
  coordinates = vec3,             -- Event position
  text = string,                  -- Marker text (for marker events)
  coalition = coalition,          -- Coalition ID
  groupId = number,               -- Group ID

  -- Enhanced unit info (if initiator exists)
  initiator = {
    unitName = string,
    unitCallsign = string,
    unitType = string,
    unitGroupName = string,
    unitGroupId = number,
    unitCoalition = coalition,
    unitCategory = category,
    unitPilotName = string,       -- if human
    unitPilotUcid = string,       -- if human
    unitLifePercent = number
  },

  -- Enhanced target info (if target exists)
  target = {
    -- same structure as initiator
  },

  -- Weapon info (if weapon fired/hit)
  weaponName = string,            -- Weapon type name

  -- Marker event fields
  comment = string                -- Marker comment text
}
```

#### Event Handling Best Practices

**Performance:**
- Disable unused events to reduce overhead
- Use delayed callbacks for expensive operations
- Filter events by type when registering callbacks

**Event Timing:**
- BIRTH events fire before units fully initialized
- Use delayed callbacks for BIRTH if accessing unit properties
- PLAYER_ENTER_UNIT fires after player fully loaded

**Example: Complete Event Handler:**
```lua
-- Track player kills
local playerKills = {}

veafEventHandler.addCallback("killTracker", {"S_EVENT_KILL"}, function(event)
  if event.initiator and event.initiator.unitPilotName then
    -- Human player got a kill
    local playerName = event.initiator.unitPilotName
    playerKills[playerName] = (playerKills[playerName] or 0) + 1

    local targetName = "unknown"
    if event.target and event.target.unitName then
      targetName = event.target.unitName
    end

    veaf.outTextForUnit(event.initiator.unitName,
      string.format("Kill confirmed! Total: %d", playerKills[playerName]),
      10, false)

    veaf.logger:info("%s killed %s (total kills: %d)",
      playerName, targetName, playerKills[playerName])
  end
end)
```

---

### veafMarkers.lua

**Module ID:** `MARKERS`
**Version:** 1.1.1
**Purpose:** Listen to map marker events and execute handlers

#### Constants

```lua
veafMarkers.MarkerAdd = 1       -- Marker added event
veafMarkers.MarkerChange = 2    -- Marker changed event
veafMarkers.MarkerRemove = 3    -- Marker removed event
veafMarkers.DCSbugfixed = true  -- DCS marker bug status
```

#### Functions

##### `veafMarkers.registerEventHandler(eventType, eventHandler)`

Register handler for marker events.

**Parameters:**
- `eventType` (number) - Event type: `MarkerAdd`, `MarkerChange`, or `MarkerRemove`
- `eventHandler` (function) - Handler function

**Handler Signature:**
```lua
function eventHandler(vec3_position, event)
  -- vec3_position: marker position
  -- event: DCS event table
end
```

**Returns:** `number` - Handler ID for unregistering

**Example:**
```lua
-- Listen for marker additions
local handlerId = veafMarkers.registerEventHandler(
  veafMarkers.MarkerAdd,
  function(pos, event)
    local text = event.text or ""
    if text:match("^_spawn") then
      -- Handle spawn command
      veaf.logger:info("Spawn marker at %s", veaf.vecToString(pos))
    end
  end
)
```

##### `veafMarkers.unregisterEventHandler(id)`

Remove marker event handler.

**Parameters:**
- `id` (number) - Handler ID from registerEventHandler

**Returns:** `boolean` - True if unregistered successfully

**Example:**
```lua
local handlerId = veafMarkers.registerEventHandler(veafMarkers.MarkerAdd, myHandler)
-- Later...
veafMarkers.unregisterEventHandler(handlerId)
```

#### Marker Event Structure

Marker events received by handlers contain:

```lua
{
  id = number,              -- Marker ID
  time = number,            -- Mission time
  initiator = DCS_Unit,     -- Unit that created marker (if applicable)
  coalition = coalition,    -- Coalition (-1 for all, 0=neutral, 1=blue, 2=red)
  groupID = number,         -- Group ID
  text = string,            -- Marker text
  pos = vec3                -- Marker position
}
```

#### Usage Patterns

**Command Pattern:**

Modules register a handler with `veafCommands` which routes all F10 marker commands centrally:
```lua
-- In a module's initialize() function:
veafCommands.registerCommandHandler(function(pos, event, bypass, fromMarker, groups, route)
  local text = event.text or ""
  if not text:lower():match("^_mycommand") then
    return false  -- not our command
  end
  -- handle the command...
  return true   -- consumed
end, veafCommands.PRIORITY_SPAWN)
```

All handlers are called in priority order until one returns `true`.
The central dispatcher (`veafCommands.dispatchMarker`) handles the mark removal automatically.

**Security Pattern:**

Check coalition before executing:
```lua
veafMarkers.registerEventHandler(veafMarkers.MarkerAdd, function(pos, event)
  -- Only allow blue coalition markers
  if event.coalition == coalition.side.BLUE then
    processCommand(pos, event.text)
  else
    veaf.logger:warn("Unauthorized marker from coalition %d", event.coalition)
  end
end)
```

**Cleanup Pattern:**

Remove markers after processing:
```lua
veafMarkers.registerEventHandler(veafMarkers.MarkerChange, function(pos, event)
  if processMarkerCommand(pos, event.text) then
    -- Remove marker after successful processing
    trigger.action.removeMark(event.id)
  end
end)
```

---

### veafCommands.lua

**Module ID:** `COMMANDS`
**Init order:** 15 (after veafMarkers, before all command modules)
**Purpose:** Central registry and dispatcher for all text commands (F10 markers and interpreter)

#### Constants

```lua
veafCommands.PRIORITY_SHORTCUTS    = 10
veafCommands.PRIORITY_SPAWN        = 20
veafCommands.PRIORITY_NAMEDPOINTS  = 30
veafCommands.PRIORITY_CASMISSION   = 40
veafCommands.PRIORITY_SECURITY     = 50
veafCommands.PRIORITY_MOVE         = 60
veafCommands.PRIORITY_RADIO        = 70
veafCommands.PRIORITY_REMOTE       = 80
```

#### Functions

##### `veafCommands.registerCommandHandler(fn, priority)`

Register a command handler function. Handlers are called in ascending priority order.

**Parameters:**
- `fn` (function) - Handler with signature `(pos, event, bypass, fromMarker, groups, route) → boolean`
- `priority` (number) - Execution order (lower = earlier); use the `PRIORITY_*` constants

##### `veafCommands.execute(pos, text, coalition, groups, route)`

Execute a command from the interpreter path (unit names). The coalition is used as-is.

**Parameters:**
- `pos` (vec3) - Execution position
- `text` (string) - Command text
- `coalition` (number) - Coalition number
- `groups` (table, optional) - Table to receive spawned group names
- `route` (table, optional) - Route definition

**Returns:** `boolean` — true if a handler consumed the command

##### `veafCommands.dispatchMarker(eventPos, event)`

Handle a marker change event. Inverts coalition (marker events report the placer's side, not the target's), calls all registered handlers in priority order, and removes the mark on success.

**Parameters:**
- `eventPos` (vec3) - Marker position
- `event` (table) - Marker event object

---

### veafInterpreter.lua

**Module ID:** `INTERPRETER`
**Version:** 1.6.3
**Purpose:** Interpret and execute commands from unit names and markers

#### Constants

```lua
veafInterpreter.Starter = "#veafInterpreter[\""  -- Unit name command prefix
veafInterpreter.Trailer = "\"]"                   -- Unit name command suffix
veafInterpreter.DelayForStartup = 1              -- Startup delay (seconds)
```

#### Functions

##### `veafInterpreter.interpret(text)`

Extract command from text string.

**Parameters:**
- `text` (string) - Text containing command (unit name or marker text)

**Returns:** `string` - Extracted command or nil

**Example:**
```lua
local unitName = "#veafInterpreter[\"_spawn, name F-16C, group 2\"]"
local command = veafInterpreter.interpret(unitName)
-- Result: "_spawn, name F-16C, group 2"
```

##### `veafInterpreter.execute(command, position, coalition, route, spawnedGroups)`

Execute VEAF command. Delegates to `veafCommands.execute()` — all registered handlers are tried in priority order.

**Parameters:**
- `command` (string) - Command string
- `position` (vec3) - Command execution position
- `coalition` (coalition, optional) - Coalition executing command
- `route` (table, optional) - Route definition for spawned groups
- `spawnedGroups` (table, optional) - Table to receive spawned group names

**Returns:** `boolean` - True if command executed successfully

**Note:** Command routing is handled by `veafCommands`. Modules register themselves via `veafCommands.registerCommandHandler()`.

**Example:**
```lua
local pos = {x=1000, y=50, z=2000}
local success = veafInterpreter.execute("_spawn, name F-16C, group 2", pos, coalition.side.BLUE)
if success then
  veaf.logger:info("Command executed successfully")
end
```

##### `veafInterpreter.executeCommandOnUnit(unitName, command)`

Execute command from unit's position.

**Parameters:**
- `unitName` (string) - Unit or static name
- `command` (string) - Command to execute

**Returns:** None

**Description:**
- Finds unit or static object by name
- Executes command at unit's position
- Destroys unit/static after successful execution
- Useful for pre-placed trigger units

**Example:**
```lua
-- In mission editor, create unit named: "#veafInterpreter[\"_spawn, name SA-6\"]"
-- Or execute via script:
veafInterpreter.executeCommandOnUnit("TriggerUnit1", "_spawn, name SA-6")
```

##### `veafInterpreter.initialize()`

Initialize interpreter module.

**Returns:** None

**Description:**
- Called automatically during VEAF initialization
- Scans for units with interpreter commands in names
- Executes commands after delay

#### Command Execution Flow

```
1. Command received (unit name or marker)
   ↓
2. veafInterpreter.interpret() extracts command
   ↓
3. Check veafShortcuts for shorthand
   ↓
4. Try module-specific handlers in order:
   - veafSpawn (spawn commands)
   - veafNamedPoints (named locations)
   - veafCasMission (CAS missions)
   - veafSecurity (security commands)
   - veafMove (movement)
   - veafRadio (radio/comms)
   - veafRemote (remote API)
   ↓
5. Return success/failure
```

#### Unit Name Command Pattern

**Mission Editor Usage:**
1. Create unit (any type, even static)
2. Name unit: `#veafInterpreter["COMMAND HERE"]`
3. Unit will execute command on mission start and self-destruct

**Example Use Cases:**
```lua
-- Spawn CAP on mission start
Unit name: #veafInterpreter["_spawn, name CAP-2, alt 25000, hdg 090, speed 450"]

-- Create CAS target area
Unit name: #veafInterpreter["_cas, size 5, defense 3, armor 2"]

-- Spawn convoy on road
Unit name: #veafInterpreter["_spawn, convoy, name convoy1, dest marker1, speed 50"]
```

---

## Unit & Group Management

### veafSpawnParser.lua

**Purpose:** Parse spawn command text into options tables. Extracted sub-module of `veafSpawn`.

#### Functions

##### `veafSpawn.markTextAnalysis(text)`

Parse marker text for spawn parameters. Defined in `veafSpawnParser.lua`, available on the `veafSpawn` table.

**Parameters:**
- `text` (string) - Marker text to parse

**Returns:** `table` — options table with parsed key/value pairs

##### `veafSpawn.convertLaserToFreq(laser)`

Convert a laser code to a TACAN/radio frequency string.

**Parameters:**
- `laser` (number) - Laser code (1111–1788)

**Returns:** `string` — frequency label, or nil if not found

---

### veafSpawn.lua

**Module ID:** `SPAWN`
**Version:** 1.59.2
**Purpose:** Dynamic spawning system for units, groups, convoys, and effects

#### Constants

##### Keyphrases

```lua
veafSpawn.SpawnKeyphrase = "_spawn"
veafSpawn.DestroyKeyphrase = "_destroy"
veafSpawn.TeleportKeyphrase = "_teleport"
veafSpawn.DrawingKeyphrase = "_drawing"
veafSpawn.MissionMasterKeyphrase = "_mm"
```

##### Configuration

```lua
veafSpawn.IlluminationFlareAglAltitude = 1000  -- meters
veafSpawn.LogisticUnitType = "FARP Ammo Dump Coating"
veafSpawn.CAP_WATCHDOG_DELAY = 10  -- seconds
veafSpawn.AFAC.maximumAmount = 8   -- max simultaneous AFACs
```

#### Main Functions

##### `veafSpawn.executeCommand(eventPos, eventText, coalition, markId, bypassSecurity, spawnedGroups, repeatCount, repeatDelay, route, allowStartDelay)`

Execute spawn command from marker or script.

**Parameters:**
- `eventPos` (vec3) - Spawn position
- `eventText` (string) - Command text
- `coalition` (coalition, optional) - Coalition
- `markId` (number, optional) - Marker ID to remove
- `bypassSecurity` (boolean, optional) - Skip security check
- `spawnedGroups` (table, optional) - Receive spawned group names
- `repeatCount` (number, optional) - Number of repetitions
- `repeatDelay` (number, optional) - Delay between spawns (seconds)
- `route` (table, optional) - Route for spawned groups
- `allowStartDelay` (boolean, optional) - Allow delayed start

**Returns:** `boolean` - Success flag

**Example:**
```lua
local pos = {x=1000, y=0, z=2000}
veafSpawn.executeCommand(pos, "_spawn, name F-16C, group 2, hdg 270", coalition.side.BLUE)
```

##### `veafSpawn.markTextAnalysis(text)`

Parse marker text for spawn parameters.

**Parameters:**
- `text` (string) - Marker text

**Returns:** `table` - Parsed options

**Returned Table Fields:**
```lua
{
  name = string,           -- Unit/group name
  unitName = string,       -- Specific unit name
  groupName = string,      -- Override group name
  alias = string,          -- Name alias
  group = number,          -- Group count
  country = string,        -- Country name
  alt = number,            -- Altitude (feet)
  altitude = number,       -- Altitude (feet)
  hdg = number,            -- Heading (degrees)
  heading = number,        -- Heading (degrees)
  speed = number,          -- Speed (knots)
  dist = number,           -- Distance
  spacing = number,        -- Unit spacing (meters)
  side = coalition,        -- Coalition
  defense = number,        -- Defense level (0-5)
  armor = number,          -- Armor level (0-5)
  size = number,           -- Size (0-5)
  shells = number,         -- Shell count
  power = number,          -- Explosion power
  radius = number,         -- Dispersion radius
  color = string,          -- Smoke color
  smoke = boolean,         -- Add smoke
  type = string,           -- Type specification
  skill = string,          -- Skill level
  password = string,       -- Security password
  silent = boolean,        -- Suppress messages

  -- Specific spawn types
  convoy = boolean,
  dest = vec3,             -- Destination
  patrol = boolean,
  offroad = boolean,

  -- Air units
  cap = boolean,           -- CAP mission
  capRadius = number,      -- CAP radius
  afac = boolean,          -- AFAC unit
  immortal = boolean,      -- Invulnerable

  -- Effects
  bomb = boolean,
  smoke = boolean,
  flare = boolean,
  illumination = boolean,

  -- FARP/FOB
  farp = boolean,
  fob = boolean,
  farptype = string,
  fobtype = string,

  -- Advanced
  code = number,           -- Laser/TACAN code
  freq = number,           -- Frequency
  mod = string,            -- Modulation
  role = string,           -- Unit role
  static = boolean,        -- Spawn as static
  hidden = boolean         -- Hide from MFD
}
```

#### Unit Spawning Functions

##### `veafSpawn.spawnUnit(spawnPosition, radius, name, czName, country, alt, hdg, unitName, role, static, code, freq, mod, silent, hiddenOnMFD)`

Spawn single unit.

**Parameters:**
- `spawnPosition` (vec3) - Spawn position
- `radius` (number) - Dispersion radius (meters)
- `name` (string) - Unit type name (DCS type or alias)
- `czName` (string, optional) - Combat zone name
- `country` (number, optional) - Country ID
- `alt` (number, optional) - Altitude (feet)
- `hdg` (number, optional) - Heading (degrees)
- `unitName` (string, optional) - Override unit name
- `role` (string, optional) - Unit role
- `static` (boolean, optional) - Spawn as static object
- `code` (number, optional) - Laser/TACAN code
- `freq` (number, optional) - Radio frequency
- `mod` (string, optional) - Radio modulation
- `silent` (boolean, optional) - Suppress messages
- `hiddenOnMFD` (boolean, optional) - Hide from MFD

**Returns:** `table` - Spawned group info

**Example:**
```lua
-- Spawn F-16C at position
local pos = {x=1000, y=0, z=2000}
veafSpawn.spawnUnit(pos, 50, "F-16C", nil, nil, 5000, 270)

-- Spawn JTAC with laser code
veafSpawn.spawnUnit(pos, 0, "JTAC", nil, nil, nil, nil, "JTAC-1", "forward_observer", false, 1688)

-- Spawn tanker with TACAN
veafSpawn.spawnUnit(pos, 100, "KC-135", nil, nil, 25000, 270, "Texaco", nil, false, 61, 251.0, "AM")
```

##### `veafSpawn.spawnGroup(spawnSpot, radius, name, czName, country, alt, hdg, spacing, groupName, silent, hasDest, hiddenOnMFD)`

Spawn predefined group.

**Parameters:**
- `spawnSpot` (vec3) - Spawn position
- `radius` (number) - Dispersion radius
- `name` (string) - Group template name
- `czName` (string, optional) - Combat zone
- `country` (number, optional) - Country
- `alt` (number, optional) - Altitude
- `hdg` (number, optional) - Heading
- `spacing` (number, optional) - Unit spacing
- `groupName` (string, optional) - Override group name
- `silent` (boolean, optional) - Suppress messages
- `hasDest` (vec3, optional) - Destination for movement
- `hiddenOnMFD` (boolean, optional) - Hide from MFD

**Returns:** `table` - Group info

**Example:**
```lua
-- Spawn armor platoon from template
veafSpawn.spawnGroup(pos, 100, "Soviet Armor Platoon", nil, nil, nil, 180, 50)
```

#### Ground Force Spawning

##### `veafSpawn.spawnInfantryGroup(spawnSpot, radius, czName, country, side, heading, spacing, defense, armor, size, silent, hiddenOnMFD)`

Spawn infantry group with parameters.

**Parameters:**
- `spawnSpot` (vec3) - Spawn position
- `radius` (number) - Dispersion radius
- `czName` (string, optional) - Combat zone
- `country` (number, optional) - Country
- `side` (coalition) - Coalition
- `heading` (number, optional) - Formation heading
- `spacing` (number) - Unit spacing (meters)
- `defense` (number) - Defense level 0-5
- `armor` (number) - Armor level 0-5
- `size` (number) - Size 0-5 (affects unit count)
- `silent` (boolean, optional) - Suppress messages
- `hiddenOnMFD` (boolean, optional) - Hide from MFD

**Returns:** `table` - Group info

**Example:**
```lua
-- Spawn small infantry squad
veafSpawn.spawnInfantryGroup(pos, 50, nil, nil, coalition.side.RED, 0, 10, 0, 0, 1, false)
```

##### `veafSpawn.spawnArmoredPlatoon(spawnSpot, radius, czName, country, side, heading, spacing, defense, armor, size, silent, hasDest, hiddenOnMFD)`

Spawn armored platoon.

**Parameters:** Same as infantry + `hasDest` for movement

**Returns:** `table` - Group info

**Example:**
```lua
-- Spawn medium tank platoon
veafSpawn.spawnArmoredPlatoon(pos, 100, nil, nil, coalition.side.BLUE, 90, 50, 2, 3, 3, false)
```

##### `veafSpawn.spawnAirDefenseBattery(spawnSpot, radius, czName, country, side, heading, spacing, defense, silent, hasDest, hiddenOnMFD)`

Spawn SAM/AAA battery.

**Parameters:** Similar to armor platoon

**Returns:** `table` - Group info

**Example:**
```lua
-- Spawn SA-6 battery
veafSpawn.spawnAirDefenseBattery(pos, 200, nil, nil, coalition.side.RED, 0, 75, 4, false)
```

##### `veafSpawn.spawnTransportCompany(spawnSpot, radius, czName, country, side, heading, spacing, defense, size, silent, hasDest, hiddenOnMFD)`

Spawn transport company (trucks).

**Returns:** `table` - Group info

##### `veafSpawn.spawnFullCombatGroup(spawnSpot, radius, czName, country, side, heading, spacing, defense, armor, size, silent, hiddenOnMFD)`

Spawn combined arms group (infantry + armor + transport).

**Returns:** `table` - Multiple group info

#### Convoy System

##### `veafSpawn.spawnConvoy(spawnSpot, name, czName, radius, country, side, heading, spacing, speed, patrol, offroad, destination, defense, size, armor, silent, hiddenOnMFD)`

Spawn vehicle convoy with waypoints.

**Parameters:**
- `spawnSpot` (vec3) - Starting position
- `name` (string) - Convoy name
- `czName` (string, optional) - Combat zone
- `radius` (number) - Dispersion
- `country` (number, optional) - Country
- `side` (coalition) - Coalition
- `heading` (number, optional) - Initial heading
- `spacing` (number) - Vehicle spacing
- `speed` (number) - Speed (km/h)
- `patrol` (boolean) - Patrol mode (return to start)
- `offroad` (boolean) - Allow offroad movement
- `destination` (vec3) - Destination position
- `defense` (number) - Defense level 0-5
- `size` (number) - Size 0-5
- `armor` (number) - Armor level 0-5
- `silent` (boolean, optional) - Suppress messages
- `hiddenOnMFD` (boolean, optional) - Hide from MFD

**Returns:** `table` - Convoy info

**Example:**
```lua
local start = {x=1000, y=0, z=2000}
local dest = {x=5000, y=0, z=6000}
veafSpawn.spawnConvoy(start, "Convoy1", nil, 50, nil, coalition.side.RED,
  nil, 25, 40, false, false, dest, 2, 3, 2, false)
```

##### Convoy Control Functions

**`veafSpawn.stopClosestConvoy(unitName)`**

Stop nearest convoy to unit.

**`veafSpawn.moveClosestConvoy(unitName)`**

Resume nearest convoy movement.

**`veafSpawn.markClosestConvoyWithSmoke(unitName)`**

Mark nearest convoy with smoke.

**`veafSpawn.markClosestConvoyRouteWithSmoke(unitName)`**

Mark convoy route with smoke markers.

**`veafSpawn.infoOnAllConvoys(unitName)`**

Display info on all active convoys.

**`veafSpawn.cleanupAllConvoys()`**

Destroy all active convoys.

#### Aircraft Spawning

##### `veafSpawn.spawnCombatAirPatrol(spawnSpot, radius, name, country, altitude, altitudeDelta, hdg, distance, speed, capRadius, skill, silent, hiddenOnMFD)`

Spawn CAP flight with patrol orbit.

**Parameters:**
- `spawnSpot` (vec3) - Spawn position
- `radius` (number) - Dispersion
- `name` (string) - Aircraft type
- `country` (number, optional) - Country
- `altitude` (number) - Patrol altitude (feet)
- `altitudeDelta` (number, optional) - Altitude randomization
- `hdg` (number) - Orbit heading
- `distance` (number) - Distance to orbit (meters)
- `speed` (number) - Speed (knots)
- `capRadius` (number) - Orbit radius (meters)
- `skill` (string) - Skill level
- `silent` (boolean, optional) - Suppress messages
- `hiddenOnMFD` (boolean, optional) - Hide from MFD

**Returns:** `table` - CAP flight info

**Description:**
- Spawns aircraft at position
- Creates racetrack orbit at specified location
- Starts watchdog to monitor and engage targets

**Example:**
```lua
-- Spawn F-15C CAP
local pos = {x=0, y=0, z=0}
veafSpawn.spawnCombatAirPatrol(pos, 100, "F-15C", nil, 25000, 2000,
  90, 50000, 450, 20000, "Good", false)
```

##### `veafSpawn.spawnAFAC(spawnSpot, name, country, altitude, speed, hdg, frequency, mod, code, immortal, silent, hiddenOnMFD)`

Spawn Airborne Forward Air Controller (AFAC).

**Parameters:**
- `spawnSpot` (vec3) - Spawn position
- `name` (string) - Aircraft type
- `country` (number, optional) - Country
- `altitude` (number) - Orbit altitude (feet)
- `speed` (number) - Speed (knots)
- `hdg` (number) - Orbit heading
- `frequency` (number) - Radio frequency (MHz)
- `mod` (string) - "AM" or "FM"
- `code` (number) - Laser code (e.g., 1688)
- `immortal` (boolean) - Invulnerable flag
- `silent` (boolean, optional) - Suppress messages
- `hiddenOnMFD` (boolean, optional) - Hide from MFD

**Returns:** `table` - AFAC info

**Example:**
```lua
-- Spawn A-10C AFAC
veafSpawn.spawnAFAC(pos, "A-10C", nil, 15000, 250, 0, 133.0, "AM", 1688, true, false)
```

##### `veafSpawn.startCapWatchdog(capGroupName, capCoalition, capZone, pTargetsList, pNumberOfTasksAddedByWatchdog)`

Start CAP engagement watchdog.

**Parameters:**
- `capGroupName` (string) - CAP group name
- `capCoalition` (coalition) - Coalition
- `capZone` (table) - Zone definition
- `pTargetsList` (table, optional) - Specific targets
- `pNumberOfTasksAddedByWatchdog` (number, optional) - Max tasks

**Returns:** None

**Description:** Monitors area and tasks CAP to engage enemy aircraft.

#### Cargo & Logistics

##### `veafSpawn.spawnCargo(spawnSpot, radius, cargoType, country, weightBias, cargoSmoke, unitName, silent, hiddenOnMFD)`

Spawn CTLD cargo.

**Parameters:**
- `spawnSpot` (vec3) - Spawn position
- `radius` (number) - Dispersion
- `cargoType` (string) - Cargo type: "container", "barrels", "ammo", "fuel"
- `country` (number, optional) - Country
- `weightBias` (number, optional) - Weight preference (0-1)
- `cargoSmoke` (boolean) - Add smoke marker
- `unitName` (string, optional) - Cargo name
- `silent` (boolean, optional) - Suppress messages
- `hiddenOnMFD` (boolean, optional) - Hide from MFD

**Returns:** `table` - Cargo info

**Example:**
```lua
-- Spawn fuel containers
veafSpawn.spawnCargo(pos, 10, "fuel", nil, 0.5, true, "Fuel-1", false)
```

##### `veafSpawn.spawnLogistic(spawnSpot, radius, country, silent, hiddenOnMFD)`

Spawn CTLD logistic unit.

**Returns:** `table` - Logistic unit info

#### FARP & FOB

##### `veafSpawn.spawnFarp(spawnSpot, radius, name, country, farptype, side, hdg, spacing, silent, hiddenOnMFD, noFarpMarkers, code, freq, mod)`

Spawn Forward Arming and Refueling Point (FARP).

**Parameters:**
- `spawnSpot` (vec3) - Position
- `radius` (number) - Dispersion
- `name` (string) - FARP name
- `country` (number, optional) - Country
- `farptype` (string, optional) - FARP configuration type
- `side` (coalition) - Coalition
- `hdg` (number, optional) - Heading
- `spacing` (number) - Unit spacing
- `silent` (boolean, optional) - Suppress messages
- `hiddenOnMFD` (boolean, optional) - Hide from MFD
- `noFarpMarkers` (boolean, optional) - Don't create markers
- `code` (number, optional) - TACAN code
- `freq` (number, optional) - Radio frequency
- `mod` (string, optional) - Modulation

**Returns:** `table` - FARP info

**Example:**
```lua
-- Spawn basic FARP
veafSpawn.spawnFarp(pos, 100, "FARP Alpha", nil, nil, coalition.side.BLUE,
  0, 50, false, false, false, 71, 251.0, "AM")
```

##### `veafSpawn.spawnFob(spawnSpot, radius, name, country, fobtype, side, hdg, spacing, silent, hiddenOnMFD)`

Spawn Forward Operating Base (FOB).

**Parameters:** Similar to FARP

**Returns:** `table` - FOB info

#### Effects & Markers

##### `veafSpawn.spawnBomb(spawnSpot, radius, shells, power, altitude, altitudedelta, password)`

Create explosion effect.

**Parameters:**
- `spawnSpot` (vec3) - Explosion position
- `radius` (number) - Dispersion
- `shells` (number) - Number of explosions
- `power` (number) - Explosion power (kg TNT equivalent)
- `altitude` (number, optional) - Altitude offset
- `altitudedelta` (number, optional) - Altitude randomization
- `password` (string, optional) - Security password

**Returns:** None

**Example:**
```lua
-- Create 5x 500kg explosions
veafSpawn.spawnBomb(pos, 50, 5, 500, 0, 0)
```

##### `veafSpawn.spawnSmoke(spawnSpot, color, radius, shells)`

Add smoke markers.

**Parameters:**
- `spawnSpot` (vec3) - Position
- `color` (string) - "Green", "Red", "White", "Orange", "Blue"
- `radius` (number) - Dispersion
- `shells` (number) - Number of smoke markers

**Returns:** None

**Example:**
```lua
-- Mark position with red smoke
veafSpawn.spawnSmoke(pos, "Red", 0, 1)
```

##### `veafSpawn.spawnSignalFlare(spawnSpot, radius, shells, color)`

Fire signal flare(s).

**Parameters:**
- `spawnSpot` (vec3) - Position
- `radius` (number) - Dispersion
- `shells` (number) - Number of flares
- `color` (string) - Flare color

**Returns:** None

##### `veafSpawn.spawnIlluminationFlare(spawnSpot, radius, steps, power, height, heading, distance, speed)`

Create illumination flare pattern.

**Parameters:**
- `spawnSpot` (vec3) - Position
- `radius` (number) - Dispersion
- `steps` (number) - Number of flares in line
- `power` (number) - Flare power
- `height` (number, optional) - Altitude AGL
- `heading` (number, optional) - Line heading
- `distance` (number, optional) - Distance between flares
- `speed` (number, optional) - Drop speed

**Returns:** None

**Example:**
```lua
-- Create illumination line
veafSpawn.spawnIlluminationFlare(pos, 0, 5, 1000000, 1000, 90, 500, 0)
```

#### Drawing Functions

##### `veafSpawn.drawCircle(point, name, radius, color, fillColor, lineType)`

Draw circle on map.

**Parameters:**
- `point` (vec3) - Center position
- `name` (string) - Drawing name
- `radius` (number) - Circle radius (meters)
- `color` (table, optional) - Line color `{r, g, b, a}` (0-1 range)
- `fillColor` (table, optional) - Fill color
- `lineType` (number, optional) - Line type

**Returns:** None

**Example:**
```lua
-- Draw red circle
veafSpawn.drawCircle(pos, "Zone1", 5000, {1, 0, 0, 1}, {1, 0, 0, 0.3})
```

##### `veafSpawn.drawSquare(point, name, side, color, fillColor, lineType)`

Draw square on map.

**Parameters:**
- `point` (vec3) - Center
- `name` (string) - Drawing name
- `side` (number) - Side length (meters)
- `color` (table, optional) - Line color
- `fillColor` (table, optional) - Fill color
- `lineType` (number, optional) - Line type

**Returns:** None

##### `veafSpawn.eraseDrawing(name)`

Remove drawing from map.

**Parameters:**
- `name` (string) - Drawing name

**Returns:** None

#### Destruction & Teleport

##### `veafSpawn.destroy(spawnSpot, radius, unitName)`

Destroy units in area or specific unit.

**Parameters:**
- `spawnSpot` (vec3) - Position
- `radius` (number) - Search radius (0 for specific unit)
- `unitName` (string, optional) - Specific unit name

**Returns:** None

**Example:**
```lua
-- Destroy all units in 500m radius
veafSpawn.destroy(pos, 500)

-- Destroy specific unit
veafSpawn.destroy(pos, 0, "Tank-1")
```

##### `veafSpawn.teleport(spawnSpot, name, silent)`

Teleport group to position.

**Parameters:**
- `spawnSpot` (vec3) - Destination
- `name` (string) - Group name
- `silent` (boolean, optional) - Suppress messages

**Returns:** None

**Example:**
```lua
-- Teleport player group to position
veafSpawn.teleport(newPos, "Viper Flight", false)
```

#### JTAC Functions

##### `veafSpawn.JTACAutoLase(groupName, laserCode, radioData)`

Setup auto-lasing JTAC.

**Parameters:**
- `groupName` (string) - JTAC group name
- `laserCode` (number) - Laser code (e.g., 1688)
- `radioData` (table, optional) - Radio configuration

**Returns:** None

**Example:**
```lua
veafSpawn.JTACAutoLase("JTAC-1", 1688, {freq=133.0, mod="AM"})
```

##### `veafSpawn.convertLaserToFreq(laser)`

Convert laser code to radio frequency.

**Parameters:**
- `laser` (number) - Laser code

**Returns:** `number` - Frequency in MHz

#### Mission Master Functions

Mission Master provides scriptable mission control.

##### `veafSpawn.missionMasterSetMessagingMode(silent, toGroupId)`

Set message output mode.

**Parameters:**
- `silent` (boolean) - Silent mode
- `toGroupId` (number, optional) - Target group ID

**Returns:** None

##### `veafSpawn.missionMasterOutText(message)`

Output Mission Master message.

**Parameters:**
- `message` (string) - Message text

**Returns:** None

##### `veafSpawn.missionMasterAddRunnable(name, code, parameters)`

Add executable command.

**Parameters:**
- `name` (string) - Command name
- `code` (string) - Lua code to execute
- `parameters` (table, optional) - Parameters

**Returns:** None

##### `veafSpawn.missionMasterRun(name)`

Run Mission Master command.

**Parameters:**
- `name` (string) - Command name

**Returns:** None

##### `veafSpawn.missionMasterSetFlag(name, value)`

Set Mission Master flag.

**Parameters:**
- `name` (string) - Flag name
- `value` (any) - Flag value

**Returns:** None

##### `veafSpawn.missionMasterGetFlag(name)`

Get flag value.

**Parameters:**
- `name` (string) - Flag name

**Returns:** `any` - Flag value

##### `veafSpawn.missionMasterAddValueToFlag(name, increment)`

Modify flag value.

**Parameters:**
- `name` (string) - Flag name
- `increment` (number) - Value to add

**Returns:** None

#### Utility Functions

##### `veafSpawn.listAllCAP(unitName)`

Display list of all active CAP flights.

**Parameters:**
- `unitName` (string) - Requesting unit name

**Returns:** None

##### `veafSpawn.dumpSpawnablePlanesList(export_path)`

Export spawnable aircraft list to file.

**Parameters:**
- `export_path` (string, optional) - Export directory

**Returns:** None

##### `veafSpawn.buildRadioMenu()`

Build spawn radio menu.

**Returns:** None

##### `veafSpawn.initialize()`

Initialize spawn module.

**Returns:** None

---

### veafUnits.lua

**Module ID:** `UNITS`
**Version:** 1.15.0
**Purpose:** Unit/group definitions and utilities

#### Constants

```lua
veafUnits.DefaultCellWidth = 10        -- meters
veafUnits.DefaultCellHeight = 10       -- meters
veafUnits.DefaultPathfindingUnitType = "TZ-22_KrAZ"
veafUnits.delayBeforePathfindingFix = 5  -- seconds
```

#### Functions

##### `veafUnits.findDcsUnit(unitType)`

Find DCS unit by type name (case-insensitive).

**Parameters:**
- `unitType` (string) - Unit type (e.g., "F-16C", "M-1 Abrams")

**Returns:** `table` - Unit definition or nil

**Example:**
```lua
local f16 = veafUnits.findDcsUnit("F-16C_50")
if f16 then
  veaf.logger:info("Found: %s", f16.displayName)
end
```

##### `veafUnits.countInfantryAndVehicles(groupname)`

Count infantry and vehicle units in group.

**Parameters:**
- `groupname` (string) - Group name

**Returns:** `number, number` - Vehicle count, Infantry count

##### `veafUnits.processGroup(group)`

Process and validate group definition.

**Parameters:**
- `group` (table) - Group definition table

**Returns:** `table` - Processed group

**Description:** Handles unit positioning, spacing, formation.

---

### veafAssets.lua

**Module ID:** `ASSETS`
**Version:** 1.8.3
**Purpose:** Manage and track mission assets (tankers, AWACS, carriers)

#### Data Structures

##### Asset Definition

```lua
{
  name = "Tanker-1",              -- Group name
  description = "KC-135 Texaco",  -- Display name
  information = "TACAN 61X",      -- Optional info
  disposable = false,             -- Can be destroyed
  jtac = 1688,                    -- Optional JTAC laser code
  linked = {"AWACS-1"}            -- Respawn these groups too
}
```

#### Functions

##### `veafAssets.respawn(name)`

Respawn asset group.

**Parameters:**
- `name` (string) - Asset name

**Returns:** None

**Description:**
- Respawns asset group
- Respawns all linked groups
- Starts JTAC if configured

**Example:**
```lua
veafAssets.respawn("Tanker-1")
```

##### `veafAssets.dispose(name)`

Destroy asset.

**Parameters:**
- `name` (string) - Asset name

**Returns:** None

**Example:**
```lua
veafAssets.dispose("AWACS-1")
```

##### `veafAssets.info(parameters)`

Get asset information.

**Parameters:**
- `parameters` (table) - `{name=string, unitName=string}`

**Returns:** `string` - Asset info text

**Example:**
```lua
local info = veafAssets.info({name="Tanker-1", unitName="Viper 1-1"})
-- Displays tanker position, TACAN, frequency
```

##### `veafAssets.get(assetName)`

Get asset definition.

**Parameters:**
- `assetName` (string) - Asset name

**Returns:** `table` - Asset definition

##### `veafAssets.help(unitName)`

Display help text.

**Parameters:**
- `unitName` (string) - Unit to receive help

**Returns:** None

##### `veafAssets.buildRadioMenu()`

Build assets radio menu.

**Returns:** None

##### `veafAssets.buildAssetsDatabase()`

Build asset lookup tables.

**Returns:** None

##### `veafAssets.initialize()`

Initialize assets module.

**Returns:** None

**Description:**
- Builds asset database
- Creates radio menus
- Must be called after assets defined

---

## Mission Systems

### veafCombatMission.lua

**Module ID:** `COMBATMISSION`
**Version:** 2.2.1
**Purpose:** Create and manage combat missions with objectives

#### Constants

```lua
veafCombatMission.SecondsBetweenWatchdogChecks = 30
veafCombatMission.RadioMenuName = "MISSIONS"
veafCombatMission.MinimumSpacingBetweenClones = 300  -- meters
```

#### Classes

##### VeafCombatMissionObjective

Mission objective definition.

**Fields:**
- `name` (string) - Objective name
- `description` (string) - Description text
- `message` (string) - Completion message
- `parameters` (table) - Objective parameters
- `onStartupFunction` (function) - Called when mission starts
- `onCheckFunction` (function) - Called periodically to check completion

**States:**
```lua
VeafCombatMissionObjective.FAILED = -1
VeafCombatMissionObjective.SUCCESS = 1
VeafCombatMissionObjective.NOTHING = 0
```

**Methods:**
```lua
obj = VeafCombatMissionObjective:new()
obj:setName(value)
obj:getName()
obj:setDescription(value)
obj:getDescription()
obj:setMessage(value)
obj:getMessage()
obj:setParameters(value)
obj:getParameters()
obj:setOnStartupFunction(value)
obj:getOnStartupFunction()
obj:setOnCheckFunction(value)
obj:getOnCheckFunction()
```

**Example:**
```lua
local objective = VeafCombatMissionObjective:new()
objective:setName("Destroy Armor")
objective:setDescription("Destroy all enemy tanks")
objective:setOnStartupFunction(function(mission)
  -- Spawn enemy tanks
end)
objective:setOnCheckFunction(function(mission)
  -- Check if tanks destroyed
  if allTanksDestroyed() then
    return VeafCombatMissionObjective.SUCCESS
  end
  return VeafCombatMissionObjective.NOTHING
end)
```

##### VeafCombatMission

Complete mission definition.

**Fields:**
- `name` (string) - Mission name
- `description` (string) - Brief description
- `briefing` (string) - Full briefing text
- `secured` (boolean) - Requires security clearance
- `radioMenuEnabled` (boolean) - Show in F10 menu
- `objectives` (table) - Array of objectives
- `spawnPosition` (vec3) - Spawn location
- `altitude` (number) - Spawn altitude
- `spawnZone` (string) - Spawn zone name
- `spawnRadius` (number) - Spawn dispersion
- `activeSquads` (table) - Spawned groups
- `skills` (table) - AI skill levels
- `scales` (table) - Mission scale factors

**Methods:**
```lua
mission = VeafCombatMission:new()
mission:setName(value)
mission:getName()
mission:setDescription(value)
mission:getDescription()
mission:setBriefing(value)
mission:getBriefing()
mission:setSecured(value)
mission:getSecured()
mission:setRadioMenuEnabled(value)
mission:getRadioMenuEnabled()
mission:setObjectives(value)
mission:getObjectives()
mission:addObjective(objective)
mission:setSpawnPosition(value)
mission:getSpawnPosition()
mission:setAltitude(value)
mission:getAltitude()
mission:setSpawnZone(value)
mission:getSpawnZone()
mission:setSpawnRadius(value)
mission:getSpawnRadius()
mission:getActiveSquads()
```

**Example:**
```lua
local mission = VeafCombatMission:new()
mission:setName("Strike Alpha")
mission:setDescription("Destroy enemy armor column")
mission:setBriefing("Enemy armor advancing on friendly position. Destroy all tanks.")
mission:setSpawnZone("SpawnZone1")
mission:addObjective(destroyTanksObjective)
mission:addObjective(rtbObjective)

veafCombatMission.AddMission(mission)
```

#### Functions

##### `veafCombatMission.AddMission(mission)`

Register mission.

**Parameters:**
- `mission` (VeafCombatMission) - Mission object

**Returns:** None

##### `veafCombatMission.AddMissionsWithSkillAndScale(mission, includeOriginal, skills, scales)`

Add mission variants with different skill/scale.

**Parameters:**
- `mission` (VeafCombatMission) - Base mission
- `includeOriginal` (boolean) - Include original
- `skills` (table) - Skill levels: `{"Average", "Good", "High"}`
- `scales` (table) - Scale factors: `{0.5, 1.0, 1.5}`

**Returns:** None

**Description:** Creates multiple variants (e.g., "Strike Alpha - Good - 1.0x")

**Example:**
```lua
veafCombatMission.AddMissionsWithSkillAndScale(
  baseMission,
  false,
  {"Average", "Good", "High", "Excellent"},
  {0.5, 1.0, 1.5, 2.0}
)
-- Creates 16 mission variants (4 skills × 4 scales)
```

##### `veafCombatMission.GetMission(name)`

Get mission by name.

**Parameters:**
- `name` (string) - Mission name

**Returns:** `VeafCombatMission` - Mission object or nil

##### `veafCombatMission.GetMissionNumber(number)`

Get mission by index.

**Parameters:**
- `number` (number) - Mission index (1-based)

**Returns:** `VeafCombatMission` - Mission object

##### `veafCombatMission.ActivateMission(name, silent, unitName)`

Activate mission.

**Parameters:**
- `name` (string) - Mission name
- `silent` (boolean, optional) - Suppress messages
- `unitName` (string, optional) - Unit to receive messages

**Returns:** None

**Description:**
- Executes all objective startup functions
- Spawns mission elements
- Starts watchdog timer
- Displays briefing

**Example:**
```lua
veafCombatMission.ActivateMission("Strike Alpha", false, "Viper 1-1")
```

##### `veafCombatMission.ActivateMissionNumber(number, silent)`

Activate mission by index.

**Parameters:**
- `number` (number) - Mission index
- `silent` (boolean, optional) - Suppress messages

**Returns:** None

##### `veafCombatMission.DesactivateMission(name, silent, unitName)`

Deactivate mission.

**Parameters:**
- `name` (string) - Mission name
- `silent` (boolean, optional) - Suppress messages
- `unitName` (string, optional) - Unit to receive messages

**Returns:** None

**Description:**
- Stops mission watchdog
- Destroys spawned groups
- Clears objectives

##### `veafCombatMission.DesactivateMissionNumber(number, silent)`

Deactivate mission by index.

**Returns:** None

##### `veafCombatMission.GetInformationOnMission(parameters)`

Get mission status.

**Parameters:**
- `parameters` (table) - `{name=string, unitName=string}`

**Returns:** `string` - Mission status text

**Example:**
```lua
local status = veafCombatMission.GetInformationOnMission({
  name = "Strike Alpha",
  unitName = "Viper 1-1"
})
```

##### `veafCombatMission.CompletionCheck(name)`

Check mission completion status.

**Parameters:**
- `name` (string) - Mission name

**Returns:** `number` - Status: FAILED (-1), SUCCESS (1), NOTHING (0)

**Description:** Calls all objective check functions and aggregates results.

##### `veafCombatMission.addCapMission(missionName, missionDescription, missionBriefing, secured, radioMenuEnabled, skills, scales, spawnRadius)`

Create CAP mission helper.

**Parameters:**
- `missionName` (string) - Mission name
- `missionDescription` (string) - Description
- `missionBriefing` (string) - Briefing
- `secured` (boolean) - Security required
- `radioMenuEnabled` (boolean) - Show in menu
- `skills` (table) - Skill levels
- `scales` (table) - Scale factors
- `spawnRadius` (number) - Spawn dispersion

**Returns:** `VeafCombatMission` - Mission object

**Description:** Helper for creating CAP missions with standard objectives.

##### `veafCombatMission.listAvailableMissions(unitName)`

Display mission list to player.

**Parameters:**
- `unitName` (string) - Unit to receive list

**Returns:** None

##### `veafCombatMission.listActiveMissions()`

Show active missions.

**Returns:** None

##### `veafCombatMission.help(unitName)`

Display help text.

**Parameters:**
- `unitName` (string) - Unit to receive help

**Returns:** None

##### `veafCombatMission.buildRadioMenu()`

Build missions radio menu.

**Returns:** None

##### `veafCombatMission.executeCommandFromRemote(parameters)`

Execute command from remote API.

**Parameters:**
- `parameters` (table) - Remote command parameters

**Returns:** None

##### `veafCombatMission.dumpMissionsList(export_path)`

Export missions to file.

**Parameters:**
- `export_path` (string, optional) - Export directory

**Returns:** None

##### `veafCombatMission.initialize()`

Initialize module.

**Returns:** None

---

### veafCasMission.lua

**Module ID:** `CASMISSION`
**Version:** 1.15.3
**Purpose:** Create close air support training missions

#### Constants

```lua
veafCasMission.Keyphrase = "_cas"
veafCasMission.SecondsBetweenWatchdogChecks = 15
veafCasMission.SecondsBetweenSmokeRequests = 180
veafCasMission.SecondsBetweenFlareRequests = 120
veafCasMission.RedCasGroupName = "Red CAS Group"
veafCasMission.BlueCasGroupName = "Blue CAS Group"
veafCasMission.RadioMenuName = "CAS MISSION"
```

#### Unit Type Tables

Units are categorized by coalition, era, and defense level:

```lua
TRANSPORT_TYPES[coalition][era][defense] = {unit_types}
ARMOR_TYPES[coalition][era][defense] = {unit_types}
DEFENSE_TYPES[coalition][era][defense] = {unit_types}
```

**Coalition:** `"blue"`, `"red"`
**Era:** `"cold"`, `"modern"`
**Defense:** `0-5` (0=none, 5=heavy)

#### Functions

##### `veafCasMission.executeCommand(eventPos, eventText, coalition, markId, bypassSecurity)`

Execute CAS mission command.

**Parameters:**
- `eventPos` (vec3) - Spawn position
- `eventText` (string) - Command text
- `coalition` (coalition, optional) - Coalition
- `markId` (number, optional) - Marker ID
- `bypassSecurity` (boolean, optional) - Skip security

**Returns:** `boolean` - Success flag

##### `veafCasMission.markTextAnalysis(text)`

Parse CAS marker text.

**Parameters:**
- `text` (string) - Marker text

**Returns:** `table` - Parsed options

**Options:**
```lua
{
  size = 0-5,              -- Force size
  defense = 0-5,           -- Defense level
  armor = 0-5,             -- Armor level
  spacing = number,        -- Unit spacing (meters)
  disperseOnAttack = boolean,  -- Units disperse when attacked
  side = coalition         -- Coalition
}
```

##### `veafCasMission.generateCasMission(spawnSpot, size, defense, armor, spacing, disperseOnAttack, side)`

Generate complete CAS mission.

**Parameters:**
- `spawnSpot` (vec3) - Spawn position
- `size` (number) - Size 0-5
- `defense` (number) - Defense 0-5
- `armor` (number) - Armor 0-5
- `spacing` (number) - Unit spacing (meters)
- `disperseOnAttack` (boolean) - Disperse on attack
- `side` (coalition) - Coalition

**Returns:** `table` - Generated group info

**Description:**
- Spawns infantry, armor, transport, and air defense
- Groups react to player attacks
- Provides smoke/flare marking

**Example:**
```lua
-- Generate medium difficulty CAS mission
local pos = {x=1000, y=0, z=2000}
veafCasMission.generateCasMission(pos, 3, 3, 3, 50, true, coalition.side.RED)
```

##### `veafCasMission.smokeCasTargetGroup()`

Add smoke to current CAS target.

**Returns:** None

**Description:** Limited by `SecondsBetweenSmokeRequests` timer.

##### `veafCasMission.flareCasTargetGroup()`

Add flare to current CAS target.

**Returns:** None

##### `veafCasMission.smokeReset()`

Reset smoke request timer.

**Returns:** None

##### `veafCasMission.flareReset()`

Reset flare request timer.

**Returns:** None

##### `veafCasMission.skipCasTarget()`

Skip current target group (destroy without score).

**Returns:** None

##### `veafCasMission.reportTargetInformation(unitName)`

Get CAS target info.

**Parameters:**
- `unitName` (string) - Unit to receive report

**Returns:** None

##### `veafCasMission.help(unitName)`

Display CAS help text.

**Parameters:**
- `unitName` (string) - Unit to receive help

**Returns:** None

##### `veafCasMission.buildRadioMenu()`

Build CAS radio menu.

**Returns:** None

##### `veafCasMission.initialize()`

Initialize CAS module.

**Returns:** None

---

## Infrastructure & Services

### veafAirbases.lua

**Module ID:** `AIRBASES`
**Version:** 1.1.1
**Purpose:** Normalized airbase and runway information

#### Classes

##### Airbase

**Properties:**
- `name` (string) - Airbase name
- `position` (vec3) - Airbase position
- `coalition` (coalition) - Current owner
- `runways` (table) - Array of Runway objects
- `fuelCapacity` (number) - Fuel storage
- `ammoBlueMissile` (number) - Blue missile ammo
- `ammoBlueGun` (number) - Blue gun ammo
- `ammoRedMissile` (number) - Red missile ammo
- `ammoRedGun` (number) - Red gun ammo

**Methods:**
```lua
airbase:getName()
airbase:getCoalition()
airbase:getPosition()
airbase:getRunways()
airbase:getRunwayCount()
airbase:getNearestRunway(position)  -- Get closest runway to position
```

##### Runway

**Properties:**
- `heading1` (number) - First heading (degrees)
- `heading2` (number) - Opposite heading
- `width` (number) - Runway width (meters)
- `length` (number) - Runway length (meters)
- `surface` (string) - Surface type
- `closed` (boolean) - Closed status

#### Functions

##### `veafAirbases.initialize(bReset)`

Initialize airbase database.

**Parameters:**
- `bReset` (boolean, optional) - Force rebuild database

**Returns:** None

##### `veafAirbases.getAirbaseByName(sAirbaseName)`

Get airbase by name.

**Parameters:**
- `sAirbaseName` (string) - Airbase name

**Returns:** `Airbase` - Airbase object or nil

**Example:**
```lua
local kutaisi = veafAirbases.getAirbaseByName("Kutaisi")
if kutaisi then
  veaf.logger:info("Kutaisi has %d runways", kutaisi:getRunwayCount())
  veaf.logger:info("Position: %s", veaf.vecToString(kutaisi:getPosition()))
end
```

##### `veafAirbases.getAirbaseFromDcsAirbase(dcsAirbase)`

Convert DCS airbase to Airbase object.

**Parameters:**
- `dcsAirbase` (DCS Airbase) - DCS airbase object

**Returns:** `Airbase` - VEAF airbase object

##### `veafAirbases.getNearestAirbaseList(dcsUnit, iCount)`

Get nearest airbases to unit.

**Parameters:**
- `dcsUnit` (DCS Unit) - Unit object
- `iCount` (number) - Number of results

**Returns:** `table` - Array of Airbase objects sorted by distance

**Example:**
```lua
local unit = Unit.getByName("Viper 1-1")
local nearestBases = veafAirbases.getNearestAirbaseList(unit, 3)
for i, airbase in ipairs(nearestBases) then
  veaf.logger:info("%d. %s", i, airbase:getName())
end
```

##### `veafAirbases.getNearestAirbase(dcsUnit)`

Get single nearest airbase.

**Parameters:**
- `dcsUnit` (DCS Unit) - Unit object

**Returns:** `Airbase` - Nearest airbase

**Example:**
```lua
local unit = Unit.getByName("Viper 1-1")
local nearest = veafAirbases.getNearestAirbase(unit)
veaf.outTextForUnit("Viper 1-1",
  string.format("Nearest airbase: %s", nearest:getName()), 10)
```

---

### veafCarrierOperations.lua

**Module ID:** `CARRIER`
**Version:** 1.12.3
**Purpose:** Manage aircraft carrier operations

#### Functions

##### `veafCarrierOperations.startCarrierOperations(parameters)`

Start carrier recovery operations.

**Parameters:**
- `parameters` (table) - `{carrierGroupName=string, userUnitName=string}`

**Returns:** None

**Description:**
- Turns carrier into wind
- Maintains position for recovery
- Reports wind direction and ATC info

**Example:**
```lua
veafCarrierOperations.startCarrierOperations({
  carrierGroupName = "CVN-73",
  userUnitName = "Hornet 1-1"
})
```

##### `veafCarrierOperations.continueCarrierOperations(groupName, userUnitName)`

Continue carrier operations.

**Parameters:**
- `groupName` (string) - Carrier group name
- `userUnitName` (string, optional) - User unit

**Returns:** None

##### `veafCarrierOperations.stopCarrierOperations(parameters)`

Stop carrier operations.

**Parameters:**
- `parameters` (table) - `{carrierGroupName=string}`

**Returns:** None

**Description:** Returns carrier to normal navigation.

##### `veafCarrierOperations.getAtcForCarrierOperations(groupName, skipNavigationData)`

Get carrier ATC data.

**Parameters:**
- `groupName` (string) - Carrier group name
- `skipNavigationData` (boolean, optional) - Skip nav info

**Returns:** `string` - ATC information text

**Example Output:**
```
CVN-73 Washington
Callsign: Mother
Position: N 42°15' E 041°45'
Heading: 270°
Wind: 285° at 25 kts
Radio: 127.5 MHz AM
TACAN: 73X (1205 MHz)
ICLS: 13
```

##### `veafCarrierOperations.atcForCarrierOperations(parameters)`

Get ATC for carrier (with output).

**Parameters:**
- `parameters` (table) - `{carrierGroupName=string, userUnitName=string}`

**Returns:** None

##### `veafCarrierOperations.listAvailableCarriers(forGroup)`

Display available carriers.

**Parameters:**
- `forGroup` (string, optional) - Group name to receive list

**Returns:** None

##### `veafCarrierOperations.executeCommandFromRemote(parameters)`

Execute from remote API.

**Parameters:**
- `parameters` (table) - Remote command parameters

**Returns:** None

##### `veafCarrierOperations.initializeCarrierGroups()`

Initialize carrier groups.

**Returns:** None

##### `veafCarrierOperations.buildRadioMenu()`

Build carrier radio menu.

**Returns:** None

##### `veafCarrierOperations.initialize()`

Initialize carrier operations module.

**Returns:** None

---

## Communication & Control

### veafRadio.lua

**Module ID:** `RADIO`
**Version:** 1.4.1
**Purpose:** Manage F10 radio menus and communications

#### Constants

```lua
veafRadio.RadioMenuName = "VEAF"
veafRadio.Keyphrase = "_radio"
veafRadio.BEACONS_SCHEDULE = 5  -- seconds
veafRadio.USAGE_ForAll = 0
veafRadio.USAGE_ForGroup = 1
veafRadio.USAGE_ForUnit = 2
```

#### Functions

##### `veafRadio.addSubMenu(title, parentMenu)`

Add submenu to radio.

**Parameters:**
- `title` (string) - Submenu title
- `parentMenu` (menu, optional) - Parent menu (nil = root VEAF menu)

**Returns:** `menu` - Submenu object

**Example:**
```lua
local assetsMenu = veafRadio.addSubMenu("Assets")
local tankersMenu = veafRadio.addSubMenu("Tankers", assetsMenu)
```

##### `veafRadio.addCommandToSubmenu(text, menu, callback, parameters, usage)`

Add command to submenu.

**Parameters:**
- `text` (string) - Command text
- `menu` (menu) - Target menu
- `callback` (function) - Callback function
- `parameters` (any, optional) - Parameters passed to callback
- `usage` (number, optional) - Usage type: `USAGE_ForAll`, `USAGE_ForGroup`, `USAGE_ForUnit`

**Returns:** None

**Callback Signature:**
```lua
function callback(parameters)
  -- parameters: value passed to addCommandToSubmenu
end
```

**Example:**
```lua
local menu = veafRadio.addSubMenu("Test")
veafRadio.addCommandToSubmenu("Say Hello", menu, function(params)
  veaf.logger:info("Hello from %s!", params.unitName)
end, {unitName = "Player"}, veafRadio.USAGE_ForAll)
```

##### `veafRadio.addSecuredCommandToSubmenu(text, menu, callback, parameters, usage)`

Add security-protected command.

**Parameters:** Same as `addCommandToSubmenu`

**Returns:** None

**Description:** Command only appears if user has security clearance.

##### `veafRadio.executeCommand(eventPos, eventText, eventCoalition, bypassSecurity)`

Execute radio command from marker.

**Parameters:**
- `eventPos` (vec3) - Command position
- `eventText` (string) - Command text
- `eventCoalition` (coalition) - Coalition
- `bypassSecurity` (boolean, optional) - Skip security check

**Returns:** `boolean` - Success flag

**Supported Commands:**
- `transmit` - Transmit via SRS
- `playmp3` - Play MP3 via SRS

##### `veafRadio.markTextAnalysis(text)`

Parse radio marker text.

**Parameters:**
- `text` (string) - Marker text

**Returns:** `table` - Parsed options

**Options:**
```lua
{
  transmit = boolean,      -- Transmit message
  playmp3 = boolean,       -- Play MP3 file
  message = string,        -- Message text
  frequencies = table,     -- Array of frequencies (MHz)
  modulations = table,     -- Array of "AM"/"FM"
  name = string,           -- Transmission name
  path = string,           -- MP3 file path
  quiet = boolean          -- Suppress confirmation
}
```

##### `veafRadio.transmitMessage(message, frequencies, modulations, name, coalition, position, quiet)`

Transmit message via SRS.

**Parameters:**
- `message` (string) - Message text (TTS)
- `frequencies` (table) - Array of frequencies
- `modulations` (table) - Array of modulations
- `name` (string) - Transmission name/callsign
- `coalition` (coalition, optional) - Coalition
- `position` (vec3, optional) - Transmission origin
- `quiet` (boolean, optional) - Suppress confirmation

**Returns:** None

**Example:**
```lua
veafRadio.transmitMessage(
  "All aircraft, return to base",
  {251.0, 305.0},
  {"AM", "AM"},
  "Tower",
  coalition.side.BLUE,
  airbasePos,
  false
)
```

##### `veafRadio.playToRadio(path, frequencies, modulations, name, coalition, position, quiet)`

Play MP3 file via SRS.

**Parameters:**
- `path` (string) - MP3 file path
- Other parameters same as `transmitMessage`

**Returns:** None

**Example:**
```lua
veafRadio.playToRadio(
  "D:\\Sounds\\airraid.mp3",
  {305.0},
  {"AM"},
  "Alert",
  coalition.side.BLUE,
  nil,
  false
)
```

##### `veafRadio.refreshRadioMenu()`

Rebuild radio menu (delayed).

**Returns:** None

**Description:** Schedules menu rebuild after delay to prevent conflicts.

##### `veafRadio.addPaginatedRadioElements(menu, buildFunction, elements, sortKey, sortField)`

Add paginated elements to menu.

**Parameters:**
- `menu` (menu) - Target menu
- `buildFunction` (function) - Function to build each element
- `elements` (table) - Array of elements
- `sortKey` (string, optional) - Sort key
- `sortField` (string, optional) - Sort field

**Returns:** None

**Description:** Creates pages of 10 items with next/previous navigation.

##### `veafRadio.onBirthEvent(event)`

Handle unit birth (add to radio menu).

**Parameters:**
- `event` (table) - Birth event

**Returns:** None

**Description:** Automatically adds human units to radio menu.

##### `veafRadio.initialize()`

Initialize radio module.

**Returns:** None

---

## Support Systems

### veafWeather.lua

**Module ID:** `WEATHER`
**Version:** (varies)
**Purpose:** Dynamic weather system

#### Functions

##### `veafWeather.setWeather(parameters)`

Set mission weather.

**Parameters:**
- `parameters` (table) - Weather parameters

**Weather Parameters:**
```lua
{
  qnh = number,              -- Pressure (mmHg or inHg)
  temperature = number,      -- Temperature (°C)
  windDirection = number,    -- Wind direction (degrees)
  windSpeed = number,        -- Wind speed (m/s or kts)
  turbulence = number,       -- Turbulence (0-100)
  clouds = {                 -- Cloud layers
    {
      base = number,         -- Base altitude (meters)
      thickness = number,    -- Thickness (meters)
      density = number,      -- Density (0-10)
      iprecptns = number     -- Precipitation
    }
  },
  fog = {                    -- Fog settings
    visibility = number,     -- Visibility (meters)
    thickness = number       -- Thickness (meters)
  }
}
```

**Returns:** None

##### `veafWeather.getWeather(position)`

Get current weather at position.

**Parameters:**
- `position` (vec3) - Position

**Returns:** `table` - Weather data

---

### veafTime.lua

**Module ID:** `TIME`
**Version:** (varies)
**Purpose:** Mission time management

#### Functions

##### `veafTime.setTime(hours, minutes)`

Set mission time.

**Parameters:**
- `hours` (number) - Hour (0-23)
- `minutes` (number, optional) - Minute (0-59)

**Returns:** None

**Example:**
```lua
-- Set time to 14:30
veafTime.setTime(14, 30)
```

##### `veafTime.setDate(year, month, day)`

Set mission date.

**Parameters:**
- `year` (number) - Year
- `month` (number) - Month (1-12)
- `day` (number) - Day (1-31)

**Returns:** None

---

## Data & Database

### dcsUnits.lua

**Module ID:** `DCSUNITS`
**Version:** 2025.11.17
**Purpose:** Complete DCS unit database

#### Data Structures

##### Unit Categories

```lua
dcsUnits.CATEGORY = {
  AIRPLANE = "Airplane",
  HELICOPTER = "Helicopter",
  GROUND_UNIT = "Ground Unit",
  SHIP = "Ship",
  STATIC = "Static"
}
```

##### Unit Definition

Each unit in database:
```lua
{
  type = "F-16C_50",           -- DCS type name
  displayName = "F-16C Viper", -- Display name
  category = "Airplane",       -- Category
  year = 1984,                 -- Introduction year
  country = {"USA"},           -- Countries
  tasks = {                    -- Capable tasks
    "CAP", "CAS", "SEAD", "Strike"
  },
  role = "Multirole Fighter",
  weapons = {                  -- Weapon types
    "AIM-9", "AIM-120", "GBU-12"
  }
}
```

#### Functions

##### `dcsUnits.findUnit(typeName)`

Find unit by type name.

**Parameters:**
- `typeName` (string) - Unit type (case-insensitive)

**Returns:** `table` - Unit definition or nil

**Example:**
```lua
local f16 = dcsUnits.findUnit("F-16C_50")
if f16 then
  veaf.logger:info("Display: %s", f16.displayName)
  veaf.logger:info("Role: %s", f16.role)
  veaf.logger:info("Year: %d", f16.year)
end
```

##### `dcsUnits.getUnitsByCategory(category)`

Get all units of category.

**Parameters:**
- `category` (string) - Category name

**Returns:** `table` - Array of unit definitions

**Example:**
```lua
local aircraft = dcsUnits.getUnitsByCategory("Airplane")
for _, unit in ipairs(aircraft) do
  veaf.logger:info("%s (%s)", unit.displayName, unit.type)
end
```

##### `dcsUnits.getUnitsByCountry(country)`

Get units for country.

**Parameters:**
- `country` (string) - Country name

**Returns:** `table` - Array of unit definitions

##### `dcsUnits.getUnitsByTask(task)`

Get units capable of task.

**Parameters:**
- `task` (string) - Task name (e.g., "CAP", "CAS", "SEAD")

**Returns:** `table` - Array of unit definitions

---

### dcsDataExport.lua

**Module ID:** `DCSDATAEXPORT`
**Version:** (varies)
**Purpose:** Export DCS data to files

#### Functions

##### `dcsDataExport.exportAllUnits(path)`

Export all DCS units to file.

**Parameters:**
- `path` (string, optional) - Export directory

**Returns:** None

**Description:** Exports complete unit database to JSON/Lua file.

##### `dcsDataExport.exportAirbases(path)`

Export airbase data.

**Parameters:**
- `path` (string, optional) - Export directory

**Returns:** None

##### `dcsDataExport.exportWeapons(path)`

Export weapons data.

**Returns:** None

---

## Appendix

### Common Patterns

#### Creating a Spawn Command

```lua
-- Via marker
local pos = {x=1000, y=0, z=2000}
veafSpawn.executeCommand(pos, "_spawn, name F-16C, group 2, hdg 270", coalition.side.BLUE)

-- Via interpreter (in unit name)
veafInterpreter.executeCommandOnUnit("SpawnTrigger1", "_spawn, name F-16C, group 2")

-- Programmatically
veafSpawn.spawnUnit(pos, 50, "F-16C", nil, nil, 5000, 270)
```

#### Listening to Events

```lua
-- Register callback
veafEventHandler.addCallback("myHandler", {"S_EVENT_TAKEOFF", "S_EVENT_LAND"},
  function(event)
    if event.initiator then
      veaf.logger:info("%s - %s", event.type.name, event.initiator.unitName)
    end
  end
)
```

#### Creating a Mission

```lua
-- Define objective
local objective = VeafCombatMissionObjective:new()
objective:setName("Destroy Tanks")
objective:setOnStartupFunction(function(mission)
  -- Spawn tanks
  veafSpawn.spawnArmoredPlatoon(mission:getSpawnPosition(), 100, nil, nil,
    coalition.side.RED, 0, 50, 2, 3, 3, true)
end)
objective:setOnCheckFunction(function(mission)
  -- Check completion
  if allTanksDestroyed() then
    return VeafCombatMissionObjective.SUCCESS
  end
  return VeafCombatMissionObjective.NOTHING
end)

-- Define mission
local mission = VeafCombatMission:new()
mission:setName("Tank Hunt")
mission:setDescription("Destroy enemy armor")
mission:setSpawnZone("TargetZone")
mission:addObjective(objective)

-- Register
veafCombatMission.AddMission(mission)
```

#### Building Radio Menus

```lua
-- Create submenu
local myMenu = veafRadio.addSubMenu("My Commands")

-- Add command
veafRadio.addCommandToSubmenu("Do Something", myMenu, function(params)
  veaf.logger:info("Command executed!")
  veaf.outTextForUnit(params.unitName, "Done!", 5)
end, {unitName = "Viper 1-1"}, veafRadio.USAGE_ForAll)
```

### Security Best Practices

1. **Use veafSecurity for sensitive commands**
2. **Validate coalition before spawning**
3. **Use bypassSecurity only when necessary**
4. **Check user permissions via radio menus**

### Performance Optimization

1. **Disable unused events:** `veafEventHandler.setEventEnabled("S_EVENT_SHOOTING_START", false)`
2. **Use delayed callbacks for expensive operations**
3. **Limit spawn counts and areas**
4. **Clean up inactive groups regularly**

### Debugging Tips

1. **Enable trace logging:** `veafModuleName.LogLevel = "trace"`
2. **Use logger markers:** `logger:marker(id, "Debug", "Position", pos)`
3. **Export data for analysis:** `veaf.exportAsJson(data, "debug", true, "debug.json")`
4. **Check event handlers:** Verify callbacks registered correctly

---

## Version History

- **v1.56.2** (veaf.lua) - Latest core utilities
- **v1.59.2** (veafSpawn.lua) - Latest spawn system
- **v2.2.1** (veafCombatMission.lua) - Latest mission system
- **v1.15.3** (veafCasMission.lua) - Latest CAS system

---

## Credits

**VEAF Project:** https://www.veaf.org
**Repository:** https://github.com/VEAF/VEAF-Mission-Creation-Tools
**Documentation:** https://veaf.github.io/documentation/
**Lead Developer:** Zip (davidp57)

---

**Document Version:** 1.0
**Last Updated:** December 16, 2025
**Generated for:** VEAF Mission Creation Tools v6.0.5
