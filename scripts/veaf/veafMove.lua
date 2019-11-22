-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF move units for DCS World
-- By mitch (2018)
--
-- Features:
-- ---------
-- * Listen to marker change events and execute move commands, with optional parameters
-- * Possibilities : 
-- *    - move a specific group to a marker point, at a specific speed
-- *    - create a new tanker flightplan, moving a specific tanker group
-- * Works with all current and future maps (Caucasus, NTTR, Normandy, PG, ...)
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires the base veaf.lua script library (version 1.0 or higher)
-- * It also requires the base veafMarkers.lua script library (version 1.0 or higher)
--
-- Load the script:
-- ----------------
-- 1.) Download the script and save it anywhere on your hard drive.
-- 2.) Open your mission in the mission editor.
-- 3.) Add a new trigger:
--     * TYPE   "4 MISSION START"
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of MIST and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of veaf.lua and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of veafMarkers.lua and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of this script and click OK.
--     * ACTION "DO SCRIPT"
--     * set the script command to "veafMove.initialize()" and click OK.
-- 4.) Save the mission and start it.
-- 5.) Have fun :)
--
-- Basic Usage:
-- ------------
-- 1.) Place a mark on the F10 map.
-- 2.) As text enter "veaf move group" or "veaf move tanker"
-- 3.) Click somewhere else on the map to submit the new text.
-- 4.) The command will be processed. A message will appear to confirm this
-- 5.) The original mark will disappear.
--
-- Options:
-- --------
-- Type "_move group, name [groupname]" to move the specified group to the marker point
--      add ", speed [speed]" to make the group move and at the specified speed (in knots)
-- Type "_move tanker, name [groupname]" to create a new tanker flight plan and move the specified tanker.
--      add ", speed [speed]" to make the tanker move and execute its refuel mission at the specified speed (in knots)
--      add ", hdg [heading]" to specify the refuel leg heading (from the marker point, in degrees)
--      add ", dist [distance]" to specify the refuel leg length (from the marker point, in nautical miles)
--      add ", alt [altitude]" to specify the refuel leg altitude (in feet)
--
-- *** NOTE ***
-- * All keywords are CaSE inSenSITvE.
-- * Commas are the separators between options ==> They are IMPORTANT!
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- veafMove Table.
veafMove = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafMove.Id = "MOVE - "

--- Version.
veafMove.Version = "1.2.1"

--- Key phrase to look for in the mark text which triggers the command.
veafMove.Keyphrase = "_move"

veafMove.RadioMenuName = "MOVE (" .. veafMove.Version .. ")"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafMove.rootPath = nil

--- Initial Marker id.
veafMove.markid = 20000

traceMarkerId = 6548
debugMarkers = {}
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafMove.logInfo(message)
    veaf.logInfo(veafMove.Id .. message)
end

function veafMove.logDebug(message)
    veaf.logDebug(veafMove.Id .. message)
end

function veafMove.logTrace(message)
    veaf.logTrace(veafMove.Id .. message)
end

function veafMove.logMarker(id, message, position, markersTable)
    return veaf.logMarker(id, veafMove.Id, message, position, markersTable)
end


-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function executed when a mark has changed. This happens when text is entered or changed.
function veafMove.onEventMarkChange(eventPos, event)
    -- Check if marker has a text and the veafMove.keyphrase keyphrase.
    if event.text ~= nil and event.text:lower():find(veafMove.Keyphrase) then

        -- Analyse the mark point text and extract the keywords.
        local options = veafMove.markTextAnalysis(event.text)
        local result = false

        if options then
            -- Check options commands
            if options.moveGroup then
                result = veafMove.moveGroup(eventPos, options.groupName, options.speed, options.altitude)
            elseif options.moveTanker then
                result = veafMove.moveTanker(eventPos, options.groupName, options.speed, options.heading, options.distance, options.altitude)
            elseif options.moveAfac then
                result = veafMove.moveAfac(eventPos, options.groupName, options.speed, options.altitude)
            end
        else
            -- None of the keywords matched.
            return
        end

        if result then 
            -- Add a new mark
            local lat, lon = coord.LOtoLL(eventPos)
            local llString = mist.tostringLL(lat, lon, 0, true)
        
            local markText = "Group " .. options.groupName .. " moving here at " .. options.speed .. " kn"
            local message = veafMove.Id .. "Group " .. options.groupName .. " moving to ".. llString .. " at " .. options.speed .. " kn"
            if options.moveTanker then
                markText = "Tanker " .. options.groupName .. " refuel leg at " .. options.speed .. " kn, " .. options.altitude .. " ft, heading " .. options.heading .. " for " .. options.distance .. " nm"
                message = veafMove.Id .. "Tanker " .. options.groupName .. " initiating new refuel leg from ".. llString .. ", at " .. options.speed .. " kn, " .. options.altitude .. " ft, heading " .. options.heading .. " for " .. options.distance .. " nm"
            end
            --veafMove.logDebug("Adding a new mark")
            --trigger.action.markToCoalition(veafMove.markid, markText, eventPos, event.coalition , false, message)
            --veafMove.markid = veafMove.markid + 1

            -- Delete old mark.
            veafMove.logTrace(string.format("Removing mark # %d.", event.idx))
            trigger.action.removeMark(event.idx)

        end
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the mark text and extract keywords.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Extract keywords from mark text.
function veafMove.markTextAnalysis(text)

    -- Option parameters extracted from the mark text.
    local switch = {}
    switch.moveGroup = false
    switch.moveTanker = false
    switch.moveAfac = false

    -- the name of the group to move ; mandatory
    switch.groupName = ""

    -- speed in knots
    switch.speed = 250

    -- tanker refuel leg altitude in feet
    switch.altitude = 20000

    -- tanker refuel leg distance in nautical miles
    switch.distance = 30

    -- tanker refuel leg heading in degrees
    switch.heading = 0

    -- Check for correct keywords.
    if text:lower():find(veafMove.Keyphrase .. " group") then
        switch.moveGroup = true
        switch.speed = 20
    elseif text:lower():find(veafMove.Keyphrase .. " tanker") then
        switch.moveTanker = true
        switch.speed = 400
        switch.altitude = 20000
    elseif text:lower():find(veafMove.Keyphrase .. " afac") then
        switch.moveAfac = true
        switch.speed = 300
        switch.altitude = 15000
    else
        return nil
    end

    -- keywords are split by ","
    local keywords = veaf.split(text, ",")

    for _, keyphrase in pairs(keywords) do
        -- Split keyphrase by space. First one is the key and second, ... the parameter(s) until the next comma.
        local str = veaf.breakString(veaf.trim(keyphrase), " ")
        local key = str[1]
        local val = str[2]

        if key:lower() == "name" then
            -- Set group name
            veafMove.logDebug(string.format("Keyword name = %s", val))
            switch.groupName = val
        end

        if key:lower() == "speed" then
            -- Set speed.
            veafMove.logDebug(string.format("Keyword speed = %d", val))
            local nVal = tonumber(val)
            switch.speed = nVal
        end

        if key:lower() == "alt" then
            -- Set altitude.
            veafMove.logDebug(string.format("Keyword alt = %d", val))
            local nVal = tonumber(val)
            switch.altitude = nVal
        end

        if switch.moveTanker and key:lower() == "dist" then
            -- Set size.
            veafMove.logDebug(string.format("Keyword dist = %d", val))
            local nVal = tonumber(val)
            switch.distance = nVal
        end

        if switch.moveTanker and key:lower() == "hdg" then
            -- Set size.
            veafMove.logDebug(string.format("Keyword hdg = %d", val))
            local nVal = tonumber(val)
            switch.heading = nVal
        end

    end

    -- check mandatory parameter "group"
    if not(switch.groupName) then return nil end
    return switch
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Group move command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- veafMove.moveGroup
-- @param point eventPos
-- @param string groupName the group name to move on
-- @param float speed in knots
------------------------------------------------------------------------------
function veafMove.moveGroup(eventPos, groupName, speed, altitude)
    veafMove.logDebug("veafMove.moveGroup(groupName = " .. groupName .. ", speed = " .. speed .. ", altitude=".. altitude)
    veafMove.logDebug(string.format("veafMove.moveGroup: eventPos  x=%.1f z=%.1f", eventPos.x, eventPos.z))

    local result = veaf.moveGroupTo(groupName, eventPos, speed, altitude)
    if not(result) then
        trigger.action.outText(groupName .. ' not found for move group command' , 10)
    end
    return result
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tanker move command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- veafMove.moveTanker
-- @param point eventPos
-- @param string groupName 
-- @param float speed in knots
-- @param float hdg heading (0-359)
-- @param float distance in Nm
-- @param float alt in feet
------------------------------------------------------------------------------
function veafMove.moveTanker(eventPos, groupName, speed, hdg ,distance,alt)
    veafMove.logDebug("veafMove.moveTanker(groupName = " .. groupName .. ", speed = " .. speed .. ", hdg = " .. hdg .. ", distance = " .. distance .. ", alt = " .. alt)
    veafMove.logDebug(string.format("veafMove.moveTanker: eventPos  x=%.1f z=%.1f", eventPos.x, eventPos.z))

	local unitGroup = Group.getByName(groupName)
	if unitGroup == nil then
        veafMove.logInfo(groupName .. ' not found for move tanker command')
		trigger.action.outText(groupName .. ' not found for move tanker command' , 10)
		return false
	end

    local tankerData = veaf.getTankerData(groupName)

    if not(tankerData) then
        local text = "Cannot move tanker " .. groupName .. " because it has no TACAN task defined"
        veafMove.logInfo(text)
        trigger.action.outText(text)
        return
    end

	-- teleport position
	local teleportPosition = {
		["x"] = eventPos.x + 5 * 1852 * math.cos(mist.utils.toRadian(180)),
		["y"] = eventPos.z + 5 * 1852 * math.sin(mist.utils.toRadian(180))
    }
    veafMove.logTrace("teleportPosition="..veaf.vecToString(teleportPosition))
    traceMarkerId = veafMove.logMarker(traceMarkerId, "teleportPosition", teleportPosition, debugMarkers)

    -- starting position
	local fromPosition = {
		["x"] = eventPos.x,
		["y"] = eventPos.z
	}
    veafMove.logTrace("fromPosition="..veaf.vecToString(fromPosition))
    traceMarkerId = veafMove.logMarker(traceMarkerId, "fromPosition", fromPosition, debugMarkers)
	
	-- ending position
	local toPosition = {
		["x"] = fromPosition.x + distance * 1852 * math.cos(mist.utils.toRadian(hdg)),
		["y"] = fromPosition.y + distance * 1852 * math.sin(mist.utils.toRadian(hdg))
	}
    veafMove.logTrace("toPosition="..veaf.vecToString(toPosition))
    traceMarkerId = veafMove.logMarker(traceMarkerId, "toPosition", toPosition, debugMarkers)

    local vars = { groupName = groupName, point = teleportPosition, action = "teleport" }
    local grp = mist.teleportToPoint(vars)
    local tankerUnit = unitGroup:getUnits()[1]

    -- replace the mission
    local mission = { 
        id = 'Mission', 
        params = { 
            ["communication"] = true,
            ["start_time"] = 0,
            ["task"] = "Refueling",
            ["taskSelected"] = true,
            ["route"] = 
            {
                ["points"] = 
                {
                    [1] = 
                    {
                        ["alt"] = alt * 0.3048, -- in meters
                        ["action"] = "Turning Point",
                        ["alt_type"] = "BARO",
                        ["speed"] = speed/1.94384,  -- speed in m/s
                        ["type"] = "Turning Point",
                        ["x"] = teleportPosition.x,
                        ["y"] = teleportPosition.y,
                        ["speed_locked"] = true,
                    },
                    [2] = 
                    {
                        ["alt"] = alt * 0.3048, -- in meters
                        ["action"] = "Turning Point",
                        ["alt_type"] = "BARO",
                        ["speed"] = speed/1.94384,  -- speed in m/s
                        ["task"] = 
                        {
                            ["id"] = "ComboTask",
                            ["params"] = 
                            {
                                ["tasks"] = 
                                {
                                    [1] = 
                                    {
                                        ["enabled"] = true,
                                        ["auto"] = true,
                                        ["id"] = "Tanker",
                                        ["number"] = 1,
                                    }, -- end of [1]
                                    [2] = tankerData.tankerTacanTask
                                }, -- end of ["tasks"]
                            }, -- end of ["params"]
                        }, -- end of ["task"]
                        ["type"] = "Turning Point",
                        ["ETA"] = 0,
                        ["ETA_locked"] = true,
                        ["x"] = teleportPosition.x,
                        ["y"] = teleportPosition.y,
                        ["speed_locked"] = true,
                    },
                    [3] = 
                    {
                        ["alt"] = alt * 0.3048, -- in meters
                        ["action"] = "Turning Point",
                        ["alt_type"] = "BARO",
                        ["speed"] = speed/1.94384,  -- speed in m/s
                        ["task"] = 
                        {
                            ["id"] = "ComboTask",
                            ["params"] = 
                            {
                                ["tasks"] = 
                                {
                                    [1] = 
                                    {
                                        ["enabled"] = true,
                                        ["auto"] = false,
                                        ["id"] = "Orbit",
                                        ["number"] = 1,
                                        ["params"] = 
                                        {
                                            ["altitude"] = alt * 0.3048, -- in meters
                                            ["pattern"] = "Race-Track",
                                            ["speed"] = speed/1.94384,  -- speed in m/s
                                        }, -- end of ["params"]
                                    }, -- end of [1]
                                }, -- end of ["tasks"]
                            }, -- end of ["params"]
                        }, -- end of ["task"]
                        ["type"] = "Turning Point",
                        ["x"] = fromPosition.x,
                        ["y"] = fromPosition.y,
                        ["speed_locked"] = true,
                    },
                    [4] = 
                    {
                        ["alt"] = alt * 0.3048, -- in meters
                        ["action"] = "Turning Point",
                        ["alt_type"] = "BARO",
                        ["speed"] = speed/1.94384,  -- speed in m/s
                        ["type"] = "Turning Point",
                        ["x"] = toPosition.x,
                        ["y"] = toPosition.y,
                        ["speed_locked"] = true,
                    }, -- end of [3]
                }, -- end of ["points"]
            }, -- end of ["route"]
        }
    }                

    -- replace whole mission
    veafMove.logDebug("Resetting moved tanker mission")
    local controller = unitGroup:getController()
    controller:setTask(mission)
        
    return true
end

------------------------------------------------------------------------------
-- veafMove.moveAfac
-- @param point eventPos
-- @param string groupName 
-- @param float speed in knots
-- @param float hdg heading (0-359)
-- @param float distance in Nm
-- @param float alt in feet
------------------------------------------------------------------------------
function veafMove.moveAfac(eventPos, groupName, speed, alt)
    if not speed then
        speed = 300
    end
    if not alt then
        alt = 20000
    end
    veafMove.logDebug("veafMove.moveAfac(groupName = " .. groupName .. ", speed = " .. speed .. ", alt = " .. alt)
    veafMove.logDebug(string.format("veafMove.moveAfac: eventPos  x=%.1f z=%.1f", eventPos.x, eventPos.z))

	local unitGroup = Group.getByName(groupName)
	if unitGroup == nil then
        veafMove.logInfo(groupName .. ' not found for move afac command')
		trigger.action.outText(groupName .. ' not found for move afac command' , 10)
		return false
	end

	-- teleport position
	local teleportPosition = {
		["x"] = eventPos.x + 5 * 1852 * math.cos(mist.utils.toRadian(180)),
        ["y"] = eventPos.z + 5 * 1852 * math.sin(mist.utils.toRadian(180)),
        ["alt"] = alt * 0.3048 -- in meters
	}

    -- starting position
	local fromPosition = {
		["x"] = eventPos.x,
		["y"] = eventPos.z
	}
	
	local mission = { 
		id = 'Mission', 
		params = { 
			["communication"] = true,
			["start_time"] = 0,
			["task"] = "AFAC",
			route = { 
				points = { 
					-- first point
					[1] = { 
						["type"] = "Turning Point",
						["action"] = "Turning Point",
						["x"] = fromPosition.x,
						["y"] = fromPosition.y,
						["alt"] = alt * 0.3048, -- in meters
						["alt_type"] = "BARO", 
						["speed"] = speed/1.94384,  -- speed in m/s
						["speed_locked"] = boolean, 
						["task"] = 
						{
							["id"] = "ComboTask",
							["params"] = 
							{
                                ["tasks"] = 
                                {
                                    [1] = 
                                    {
                                        ["number"] = 1,
                                        ["auto"] = false,
                                        ["id"] = "Orbit",
                                        ["enabled"] = true,
                                        ["params"] = 
                                        {
                                            ["altitude"] = alt * 0.3048, -- in meters,
                                            ["pattern"] = "Circle",
                                            ["speed"] = speed/1.94384,  -- speed in m/s
                                            ["altitudeEdited"] = true,
                                            ["speedEdited"] = true,
                                        }, -- end of ["params"]
                                    }, -- end of [1]
                                }, -- end of ["tasks"]
                            }, -- end of ["params"]
						}, -- end of ["task"]
					}, -- enf of [1]
				}, 
			} 
		} 
	}

    local vars = { groupName = groupName, point = teleportPosition, action = "teleport" }
    local grp = mist.teleportToPoint(vars)

    -- JTAC needs to be invisible and immortal
    local _setImmortal = {
        id = 'SetImmortal',
        params = {
            value = true
        }
    }
    -- invisible to AI, Shagrat
    local _setInvisible = {
        id = 'SetInvisible',
        params = {
            value = true
        }
    }

    -- replace whole mission
    local controller = unitGroup:getController()
	controller:setTask(mission)
    Controller.setCommand(controller, _setImmortal)
    Controller.setCommand(controller, _setInvisible)
    
    return true
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafMove.buildRadioMenu()
    veafMove.rootPath = veafRadio.addSubMenu(veafMove.RadioMenuName)
    veafRadio.addCommandToSubmenu("HELP", veafMove.rootPath, veafMove.help, nil, veafRadio.USAGE_ForGroup)
    veafRadio.refreshRadioMenu()
end

function veafMove.help(unitName)
    local text = 
        'Create a marker and type "_move <group|tanker|afac>, name <groupname> " in the text\n' ..
        'This will issue a move command to the specified group in the DCS world\n' ..
        'Type "_move group, name [groupname]" to move the specified group to the marker point\n' ..
        '     add ", speed [speed]" to make the group move and at the specified speed (in knots)\n' ..
        'Type "_move tanker, name [groupname]" to create a new tanker flight plan and move the specified tanker.\n' ..
        '     add ", speed [speed]" to make the tanker move and execute its refuel mission at the specified speed (in knots)\n' ..
        '     add ", hdg [heading]" to specify the refuel leg heading (from the marker point, in degrees)\n' ..
        '     add ", dist [distance]" to specify the refuel leg length (from the marker point, in nautical miles)\n' ..
        '     add ", alt [altitude]" to specify the refuel leg altitude (in feet)\n' ..
        'Type "_move afac, name [groupname]" to create a new JTAC flight plan and move the specified afac drone.\n' ..
        '     add ", speed [speed]" to make the tanker move and execute its mission at the specified speed (in knots)\n' ..
        '     add ", alt [altitude]" to specify the altitude at which the drone will circle (in feet)'
    veaf.outTextForUnit(unitName, text, 30)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafMove.initialize()
    veafMove.buildRadioMenu()
    veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafMove.onEventMarkChange)
end

veafMove.logInfo(string.format("Loading version %s", veafMove.Version))


