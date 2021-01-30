-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF persistence module
-- By zip (2021)
--
-- Features:
-- ---------
-- * This module offers support for persisting dead units from one run of a mission to another
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires the main veaf script !
--
-- Basic Usage:
-- ------------
-- TODO
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafPersistence = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafPersistence.Id = "PERSISTENCE - "

--- Version.
veafPersistence.Version = "1.0.0"

-- trace level, specific to this module
veafPersistence.Trace = true

-- interval between saves of the persistence file
veafPersistence.SAVE_FREQUENCY = 30 -- seconds

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafPersistence.deadObjects = {}
veafPersistence.eventHandler = {}
veafPersistence.persistenceFilePath = nil

veafPersistence.lfs = veafSanitized_lfs
if not veafPersistence.lfs then veafPersistence.lfs = lfs end

veafPersistence.io = veafSanitized_io
if not veafPersistence.io then veafPersistence.io = io end

veafPersistence.os = veafSanitized_os
if not veafSanitized_os then veafPersistence.os = os end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafPersistence.logError(message)
    veaf.logError(veafPersistence.Id .. message)
end

function veafPersistence.logInfo(message)
    veaf.logInfo(veafPersistence.Id .. message)
end

function veafPersistence.logDebug(message)
    veaf.logDebug(veafPersistence.Id .. message)
end

function veafPersistence.logTrace(message)
    if message and veafPersistence.Trace then 
        veaf.logTrace(veafPersistence.Id .. message)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- core functions
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local function getPersistenceFilePath()
    if not(veafPersistence.persistenceFilePath) then
        -- try and initialize the persistence file path
        local export_path = veafPersistence.os.getenv("VEAF_EXPORT_DIR")
        if export_path then export_path = export_path .. "\\" end
        if not export_path then
            export_path = veafPersistence.os.getenv("TEMP")
            if export_path then export_path = export_path .. "\\" end
        end
        if not export_path then
            export_path = veafPersistence.lfs.writedir()
        end

        veafPersistence.persistenceFilePath = "veaf_persistence.json"
    end
    return veafPersistence.persistenceFilePath
end

--- destroy units listed in the json file
function veafPersistence.destroyUnits()
    veafPersistence.logDebug(string.format("veafPersistence.destroyUnits()"))

    local filepath = getPersistenceFilePath()

    veafPersistence.logInfo("Reading persistence data from json file "..filepath)

    local file = veafPersistence.io.open(filepath, "r")

    if not(file) then 
        veafPersistence.logWarning(string.format("cannot read or find file %s", filepath))  
        return false
    end

    file:write(text.."\r\n")
    local jsonData = f:read("*all")
    file:close()

    -- parse json data
    local data = json.parse(jsonData)
    veafPersistence.logDebug(string.format("jsonData = %s", veaf.p(jsonData)))  

    if jsonData.timestamp then
        veafPersistence.logDebug(string.format("jsonData.timestamp = %s", data.timestamp))  
    end
    
    if data.deadObjects then
        for name, object in pairs(data.deadObjects) do 
            local objectName = object.name
            local objectTimeOfDeath = object.timeOfDeath
            -- destroy a specific unit
            local c = Unit.getByName(objectName)
            if c then
                veafPersistence.logTrace(string.format("destroying the unit named %s", objectName))
                Unit.destroy(c)
            end

            -- or a specific static
            c = StaticObject.getByName(objectName)
            if c then
                veafPersistence.logTrace(string.format("destroying the static named %s", objectName))
                StaticObject.destroy(c)
            end

            -- or a specific group
            c = Group.getByName(objectName)
            if c then
                veafPersistence.logTrace(string.format("destroying the group named %s", objectName))
                Group.destroy(c)
            end
        end
    end

    return true
end

function veafPersistence.recordObjectDeath(dcsObject)
    if not dcsObject then return false end

    local objectName = dcsObject:getName()
    veafPersistence.logDebug(string.format("recording death of the object named %s", objectName))
    
    local data = {}
    data.name = objectName
    data.absTime = timer.getAbsTime()
    veafPersistence.deadObjects[data.name] = data
end

--- save destroyed units in json format
function veafPersistence.exportDestroyedUnits(reschedule)
    veafPersistence.logDebug("veafPersistence.exportDestroyedUnits")

    local function writeln(file, text)
        file:write(text.."\r\n")
    end
    
    local filepath = getPersistenceFilePath()

    veafPersistence.logInfo("Dumping persistence data as json to file "..filepath)

    local header =    '{\n'
    header = header .. '  "persistence": [\n'

    local data = {}
    data.deadObjects = veafPersistence.deadObjects
    data.time0 = timer.getTime0()
    data.absTime = timer.getAbsTime()

    local content = json.stringify(data)

    local footer =    '\n'
    footer = footer .. ']\n'
    footer = footer .. '}\n'

    local file = veafPersistence.io.open(filepath, "w")

    if not(file) then 
        veafPersistence.logWarning(string.format("cannot write in file %s", filepath))  
        return false
    end

    writeln(file, header)
    writeln(file, table.concat(content, ",\n"))
    writeln(file, footer)
    file:close()

    if reschedule then
        timer.scheduleFunction(veafPersistence.exportDestroyedUnits, true, timer.getTime() + veafPersistence.SAVE_FREQUENCY)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Handle world events.
function veafPersistence.eventHandler:onEvent(Event)
  
    if Event == nil then
        return false
    end

    -- mission end event
    if Event.id == world.event.S_EVENT_MISSION_END then  
        veafPersistence.logTrace("event S_EVENT_MISSION_END catched in veafPersistence.eventHandler:onEvent")
        veafPersistence.logTrace(string.format("Event time = %s", tostring(Event.time)))
        veafPersistence.exportDestroyedUnits()
    end

    -- object death event S_EVENT_DEAD
    if Event.id == world.event.S_EVENT_DEAD then  
        veafPersistence.logTrace("event S_EVENT_DEAD catched in veafPersistence.eventHandler:onEvent")
        veafPersistence.logTrace(string.format("Event time = %s", tostring(Event.time)))
        veafPersistence.recordObjectDeath(event.initiator)
    end

    -- object death event S_EVENT_KILL
    if Event.id == world.event.S_EVENT_KILL then  
        veafPersistence.logTrace("event S_EVENT_KILL catched in veafPersistence.eventHandler:onEvent")
        veafPersistence.logTrace(string.format("Event time = %s", tostring(Event.time)))
        veafPersistence.recordObjectDeath(event.initiator)
    end

end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------


function veafPersistence.initialize(persistenceFilepath)
    veafPersistence.logInfo("Initializing module")
    if persistenceFilepath then
        veafPersistence.logInfo("Using "..persistenceFilepath)
    end

    -- destroy the units listed in the persistence file
    veafPersistence.destroyUnits()

    -- start recording deaths events
    world.addEventHandler(veafPersistence.eventHandler) 

    -- regularily save the dead objects
    timer.scheduleFunction(veafPersistence.exportDestroyedUnits, true, timer.getTime() + veafPersistence.SAVE_FREQUENCY)
end

veafPersistence.logInfo(string.format("Loading version %s", veafPersistence.Version))
