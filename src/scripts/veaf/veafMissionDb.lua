------------------------------------------------------------------
-- VEAF mission database for DCS World
-- By Zip (2026)
--
-- Features:
-- ---------
-- * Allocate unit ids for the objects VEAF creates at runtime
--
-- This module is the home of what VEAF needs to know about the mission itself. It starts with the id
-- allocator (DROP-MIST ticket 04); the mission index, the spawned-name registry and the player roster
-- follow in ticket 05.
------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafMissionDb = {}

--- Identifier. All output in the log will start with this.
veafMissionDb.Id = "MISSIONDB"

-- trace level, specific to this module (uncomment for debugging)
--veafMissionDb.LogLevel = "trace"

--- Where VEAF's own unit ids start.
---
--- Ids have to avoid three things: the ones the Mission Editor already assigned (three or four digits
--- in practice), the 6900–30000 band DCS reserves, and — for as long as MiST is still injected
--- alongside us — the ids MiST hands out itself.
---
--- MiST's counter starts at the highest id in the mission and, once past 6900, jumps to 30000 and
--- climbs from there. Starting at 200000 means MiST would have to allocate 170 000 units in a single
--- session before it could reach us. This is a quantitative guarantee, not a structural one; it stops
--- mattering when the injection is dropped and MiST no longer allocates anything.
veafMissionDb.FIRST_UNIT_ID = 200000

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.loggers.new(veafMissionDb.Id, veafMissionDb.LogLevel)

--- The last unit id handed out.
veafMissionDb.lastUnitId = veafMissionDb.FIRST_UNIT_ID - 1

--- A unit id no object in this mission is using.
---
--- @return number
function veafMissionDb.getNextUnitId()
  veafMissionDb.lastUnitId = veafMissionDb.lastUnitId + 1
  return veafMissionDb.lastUnitId
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Framework façades. Callers use `veaf.*` and never name the implementation.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veaf.getNextUnitId = veafMissionDb.getNextUnitId

function veafMissionDb.initialize()
  veaf.loggers.get(veafMissionDb.Id):info("Initializing module")
end

veaf.loggers.get(veafMissionDb.Id):info(veaf.loggers.get(veafMissionDb.Id):getVersionInfo())
