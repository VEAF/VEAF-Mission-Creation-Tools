------------------------------------------------------------------
-- VEAF move units for DCS World
-- By mitch (2018)
--
-- Features:
-- ---------
-- * Listen to marker change events and execute move commands, with optional parameters
-- * Possibilities : 
-- *    - move a specific group to a marker point, at a specific speed
-- *    - create a new tanker flightplan, moving a specific tanker group
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

--- veafMove Table.
veafMove = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafMove.Id = "MOVE"

--- Version.
veafMove.Version = "1.9.2"

-- trace level, specific to this module
--veafMove.LogLevel = "trace"

veaf.loggers.new(veafMove.Id, veafMove.LogLevel)

--- Key phrase to look for in the mark text which triggers the command.
veafMove.Keyphrase = "_move"

veafMove.RadioMenuName = "MOVE"

veafMove.tankerMissionParameters = {
    ["A-10C"] = {speed=250, alt=12000},
    ["A-10C_2"] = {speed=250, alt=12000},
    ["AV8BNA"] = {speed=350, alt=18000},
    ["F-14A"] = {speed=400, alt=22000},
    ["F-14A-135-GR"] = {speed=400, alt=22000},
    ["F-14B"] = {speed=400, alt=22000},
    ["F-15C"] = {speed=400, alt=22000},
    ["F-15E"] = {speed=400, alt=22000},
    ["F-16A"] = {speed=400, alt=22000},
    ["F-16A MLU"] = {speed=400, alt=22000},
    ["F-16C bl.50"] = {speed=400, alt=22000},
    ["F-16C bl.52d"] = {speed=400, alt=22000},
    ["F-16C_50"] = {speed=400, alt=22000},
    ["F/A-18A"] = {speed=400, alt=22000},
    ["F/A-18C"] = {speed=400, alt=22000},
    ["FA-18C_hornet"] = {speed=400, alt=22000},
    ["JF-17"] = {speed=400, alt=22000},
    ["M-2000C"] = {speed=400, alt=22000},
    ["MiG-29K"] = {speed=400, alt=22000},
    ["MiG-31"] = {speed=400, alt=22000},
    ["Mirage 2000-5"] = {speed=400, alt=22000},
    ["Su-24M"] = {speed=400, alt=22000},
    ["Su-24MR"] = {speed=400, alt=22000},
    ["Su-33"] = {speed=400, alt=22000},
    ["Su-34"] = {speed=400, alt=22000},
    ["Tornado GR4"] = {speed=400, alt=22000},
}
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafMove.rootPath = nil

--- Initial Marker id.
veafMove.markid = 20000

traceMarkerId = 6548
debugMarkers = {}

veafMove.Tankers = {}
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function executed when a mark has changed. This happens when text is entered or changed.
function veafMove.onEventMarkChange(eventPos, event)
    if veafMove.executeCommand(eventPos, event.text) then 
        
        -- Delete old mark.
        veaf.loggers.get(veafMove.Id):trace(string.format("Removing mark # %d.", event.idx))
        trigger.action.removeMark(event.idx)

    end
end

function veafMove.executeCommand(eventPos, eventText, bypassSecurity)
    
    -- Check if marker has a text and the veafMove.keyphrase keyphrase.
    if eventText ~= nil and eventText:lower():find(veafMove.Keyphrase) then

        -- Analyse the mark point text and extract the keywords.
        local options = veafMove.markTextAnalysis(eventText)
        local result = false

        if options then
            -- Check options commands
            if options.moveGroup then
                result = veafMove.moveGroup(eventPos, options.groupName, options.speed, options.altitude)
            elseif options.moveTanker then
                result = veafMove.moveTanker(eventPos, options.groupName, options.speed, options.altitude, options.hdg, options.distance, options.teleport, options.silent)
            elseif options.changeTanker then
                result = veafMove.changeTanker(eventPos, options.speed, options.altitude)
            elseif options.moveAfac then
                result = veafMove.moveAfac(eventPos, options.groupName, options.speed, options.altitude, options.hdg, options.immortal)
            end
        else
            -- None of the keywords matched.
            return false
        end

        return result
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
    switch.changeTanker = false
    switch.moveAfac = false

    -- the name of the group to move ; mandatory
    switch.groupName = ""

    -- speed in knots
    switch.speed = -1 -- defaults to original speed

    -- tanker refuel leg altitude in feet
    switch.altitude = -1 -- defaults to tanker original altitude

    -- tanker refuel leg heading in degrees
    switch.hdg = nil -- defaults to original heading

    -- option to set AFAC to immortal
    switch.immortal = false

    -- tanker refuel leg distance in degrees
    switch.distance = nil -- defaults to original distance

    -- if true, teleport the tanker instead of simply making it move
    switch.teleport = false

    -- if false, Named Points will be created when moving the tankers
    switch.silent = false

    -- Check for correct keywords.
    if text:lower():find(veafMove.Keyphrase .. " group") then
        switch.moveGroup = true
        switch.speed = 20
    elseif text:lower():find(veafMove.Keyphrase .. " tankermission") then
        switch.changeTanker = true
        switch.speed = -1
        switch.altitude = -1
    elseif text:lower():find(veafMove.Keyphrase .. " tanker") then
        switch.moveTanker = true
        switch.speed = -1
        switch.altitude = -1
    elseif text:lower():find(veafMove.Keyphrase .. " afac") then
        switch.moveAfac = true
        switch.speed = 150
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
            veaf.loggers.get(veafMove.Id):debug(string.format("Keyword name = %s", val))
            switch.groupName = val
        end

        if key:lower() == "speed" or key:lower() == "spd" then
            -- Set speed.
            veaf.loggers.get(veafMove.Id):debug(string.format("Keyword speed = %d", val))
            local nVal = tonumber(val)
            switch.speed = nVal
        end

        if key:lower() == "heading" or key:lower() == "hdg" then
            -- Set heading.
            veaf.loggers.get(veafMove.Id):debug(string.format("Keyword hdg = %d", val))
            local nVal = tonumber(val)
            switch.hdg = nVal
        end

        if key:lower() == "distance" or key:lower() == "dist" then
            -- Set distance.
            veaf.loggers.get(veafMove.Id):debug(string.format("Keyword distance = %d", val))
            local nVal = tonumber(val)
            switch.distance = nVal
        end

        if key:lower() == "alt" or key:lower() == "altitude" then
            -- Set altitude.
            veaf.loggers.get(veafMove.Id):debug(string.format("Keyword alt = %d", val))
            local nVal = tonumber(val)
            switch.altitude = nVal
        end

        if key:lower() == "teleport" then
            veaf.loggers.get(veafMove.Id):trace("Keyword teleport found")
            switch.teleport = true
        end

        if key:lower() == "silent" then
            veaf.loggers.get(veafMove.Id):trace("Keyword silent found")
            switch.silent = true
        end

        if key:lower() == "immortal" then
            veaf.loggers.get(veafMove.Id):trace("Keyword immortal found")
            switch.immortal = true
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
    veaf.loggers.get(veafMove.Id):debug("veafMove.moveGroup(groupName = " .. groupName .. ", speed = " .. speed .. ", altitude=".. altitude)
    veaf.loggers.get(veafMove.Id):debug(string.format("veafMove.moveGroup: eventPos  x=%.1f z=%.1f", eventPos.x, eventPos.z))

    local result = veaf.moveGroupTo(groupName, eventPos, speed, altitude)
    if not(result) then
        trigger.action.outText(groupName .. ' not found for move group command' , 10)
    end
    return result
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Change tanker mission parameters
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafMove.changeTanker(eventPos, speed, alt)
    veaf.loggers.get(veafMove.Id):debug(string.format("veafMove.changeTanker(speed=%s, alt=%s)", tostring(speed), tostring(alt)))
    veaf.loggers.get(veafMove.Id):trace(string.format("eventPos=%s",veaf.p(eventPos)))
    veaf.loggers.get(veafMove.Id):cleanupMarkers(debugMarkers)
    
    local tankerUnit = nil
    local units = veaf.findUnitsInCircle(eventPos, 2000, false)
    veaf.loggers.get(veafMove.Id):trace(string.format("units=%s", veaf.p(units)))
    if units then
        for name, _ in pairs(units) do
            -- try and find a tanker unit
            local unit = Unit.getByName(name)
            if unit and unit:getDesc()["attributes"]["Tankers"] then
                tankerUnit = unit
                break
            end
        end
    end

    if not tankerUnit then
        veaf.loggers.get(veafMove.Id):warn("Cannot find tanker unit around marker")
		trigger.action.outText("Cannot find tanker unit around marker" , 10)
        return false
    end

    local tankerGroup = tankerUnit:getGroup()
    local tankerGroupName = tankerGroup:getName()

    local tankerData = veaf.getGroupData(tankerGroupName)
    if not(tankerData) then
        local text = "Cannot move tanker " .. tankerGroupName .. " ; cannot find group data"
        veaf.loggers.get(veafMove.Id):info(text)
        trigger.action.outText(text)
        return
    end

    local route = veaf.findInTable(tankerData, "route")
    local points = veaf.findInTable(route, "points")
    if points then
        veaf.loggers.get(veafMove.Id):trace("found a " .. #points .. "-points route for tanker " .. tankerGroupName)
        -- modify the last 3 points
        local idxPoint1 = #points-2
        local idxPoint2 = #points-1
        local idxPoint3 = #points

        -- point1 is the point where the tanker mission starts ; we'll change the speed and altitude
        local point1 = points[idxPoint1]
        veaf.loggers.get(veafMove.Id):trace("found point1")
        -- set speed
        if speed > -1 then 
            point1.speed = speed/1.94384  -- in m/s
        else
            speed = point1.speed*1.94384  -- in knots 
        end
        -- set altitude
        if alt > -1 then 
            point1.alt = alt * 0.3048 -- in meters
        else
            alt = point1.alt / 0.3048 -- in feet
        end
        veaf.loggers.get(veafMove.Id):trace(string.format("newPoint1=%s",veaf.p(point1)))

        -- point 2 is the start of the tanking Orbit ; we'll change the speed and altitude
        local point2 = points[idxPoint2]
        veaf.loggers.get(veafMove.Id):trace("found point2")
        local foundOrbit = false
        local task1 = veaf.findInTable(point2, "task")
        if task1 then
            local tasks = task1.params.tasks
            if (tasks) then
                veaf.loggers.get(veafMove.Id):trace("found %s tasks", veaf.p(#tasks))
                for j, task in pairs(tasks) do
                    veaf.loggers.get(veafMove.Id):trace("found task #%s", veaf.p(j))
                    if task.params then
                        veaf.loggers.get(veafMove.Id):trace("has .params")
                        if task.id and task.id == "Orbit" then
                            veaf.loggers.get(veafMove.Id):debug("Found a ORBIT task for tanker " .. tankerGroupName)
                            foundOrbit = true
                            if speed > -1 then 
                                task.params.speed = speed/1.94384  -- in m/s
                                point2.speed = speed/1.94384  -- in m/s
                            end
                            if alt > -1 then 
                                task.params.altitude = alt * 0.3048 -- in meters
                                point2.alt = alt * 0.3048 -- in meters
                            end
                        end
                    end
                end
            end
        end
        if not foundOrbit then 
            local text = "Cannot set tanker " .. tankerGroupName .. " parameters because it has no ORBIT task defined"
            veaf.loggers.get(veafMove.Id):info(text)
            trigger.action.outText(text)
            return
        end

        -- point 3 is the end of the tanking Orbit ; we'll change the speed and altitude
        local point3 = points[idxPoint3]
        veaf.loggers.get(veafMove.Id):trace("found point3")
        -- change speed
        if speed > -1 then 
            point3.speed = speed/1.94384  -- in m/s
        end
        -- change altitude
        if alt > -1 then 
            point3.alt = alt * 0.3048 -- in meters
        end
        veaf.loggers.get(veafMove.Id):trace("newpoint3="..veaf.p(point3))

        -- replace whole mission
        veaf.loggers.get(veafMove.Id):debug("Resetting changed tanker mission")
        -- replace the mission
        local mission = { 
            id = 'Mission', 
            params = tankerData
        }
        local controller = tankerGroup:getController()
        controller:setTask(mission)
        
        local msg = string.format("Set tanker %s to %d kn (ground) at %d ft", tankerGroupName, speed, alt)
        veaf.loggers.get(veafMove.Id):info(msg)
		trigger.action.outText(msg , 10)
        return true
    else
        return false
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Tanker move command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafMove.moveTanker(eventPos, groupName, speed, alt, hdg, distance, teleport, silent)
    veaf.loggers.get(veafMove.Id):debug(string.format("veafMove.moveTanker(groupName=%s, speed=%s, alt=%s, hdg=%s, distance=%s)",tostring(groupName), tostring(speed), tostring(alt), tostring(hdg), tostring(distance)))
    veaf.loggers.get(veafMove.Id):cleanupMarkers(debugMarkers)
    
    veaf.loggers.get(veafMove.Id):trace(string.format("eventPos=%s",veaf.p(eventPos)))
    
    local FIRSTPOINT_DISTANCE_SECONDS = 60 -- seconds to fly to WP1
    
    local unitGroup = Group.getByName(groupName)
	if unitGroup == nil then
        veaf.loggers.get(veafMove.Id):info(groupName .. ' not found for move tanker command')
		trigger.action.outText(groupName .. ' not found for move tanker command' , 10)
		return false
    end
    
    local tankerData = veaf.getGroupData(groupName)
    if not(tankerData) then
        local text = "Cannot move tanker " .. groupName .. " ; no group data"
        veaf.loggers.get(veafMove.Id):info(text)
        trigger.action.outText(text)
        return false
    end
    veaf.loggers.get(veafMove.Id):trace("tankerData : %s", veaf.p(tankerData))

    local route = veaf.findInTable(tankerData, "route")
    local points = veaf.findInTable(route, "points")
    if points then
        veaf.loggers.get(veafMove.Id):trace("found a " .. #points .. "-points route for tanker " .. groupName)
        -- modify the last 3 points
        local idxPoint1 = #points-2
        local idxPoint2 = #points-1
        local idxPoint3 = #points

        local point1 = points[idxPoint1]
        veaf.loggers.get(veafMove.Id):trace(string.format("point1=%s",veaf.p(point1)))

        local point2 = points[idxPoint2]
        veaf.loggers.get(veafMove.Id):trace(string.format("point2=%s",veaf.p(point2)))

        local point3 = points[idxPoint3]
        veaf.loggers.get(veafMove.Id):trace(string.format("point3=%s",veaf.p(point3)))

        -- if distance is not set, compute distance between point2 and point3
        local distance = distance
        if distance == nil then
            distance = math.sqrt((point3.x - point2.x)^2+(point3.y - point2.y)^2)
        else
            -- convert distance to meters
            distance = distance * 1852 -- meters
        end

        -- if hdg is not set, compute heading between point2 and point3
        local hdg = hdg
        if hdg == nil then
            hdg = veaf.headingBetweenPoints(point2, point3)
        else
            hdg = hdg * math.pi/180
        end

        -- if speed is not set, use point2 speed
        local speed = speed
        if speed == nil or speed < 0 then
            speed = point2.speed
        else
            -- convert speed to m/s
            speed = speed/1.94384
        end

        -- if alt is not set, use point2 altitude
        local alt = alt
        if alt == nil or alt < 0 then
            alt = point2.alt
        else
            -- convert altitude to meters
            alt = alt * 0.3048 -- meters
        end

        veaf.loggers.get(veafMove.Id):trace(string.format("distance=%s",veaf.p(distance)))
        veaf.loggers.get(veafMove.Id):trace(string.format("hdg=%s",veaf.p(hdg)))
        veaf.loggers.get(veafMove.Id):trace(string.format("speed=%s",veaf.p(speed)))
        veaf.loggers.get(veafMove.Id):trace(string.format("alt=%s",veaf.p(alt)))

        -- the first point in the refuel leg is based on the marker position
        local startLegPoint= { x=eventPos.x, y=eventPos.z, alt=alt, speed=speed }
        veaf.loggers.get(veafMove.Id):trace(string.format("startLegPoint=%s",veaf.p(startLegPoint)))
        if veafNamedPoints and not silent then
            veafNamedPoints.namePoint({x=startLegPoint.x, y=startLegPoint.alt, z=startLegPoint.y}, groupName .. " refuel start", unitGroup:getCoalition(), true)
        end

        -- compute the second point in the refuel leg based on desired heading and distance
        local endLegPoint= { x=startLegPoint.x, y=startLegPoint.y, alt=alt, speed=speed }
        veaf.loggers.get(veafMove.Id):trace(string.format("distance=%s",veaf.p(distance)))
        veaf.loggers.get(veafMove.Id):trace(string.format("hdg=%s",veaf.p(hdg)))
        endLegPoint.x = startLegPoint.x + distance * math.cos(hdg)
        endLegPoint.y = startLegPoint.y + distance * math.sin(hdg)
        veaf.loggers.get(veafMove.Id):trace(string.format("endLegPoint=%s",veaf.p(endLegPoint)))
        if veafNamedPoints and not silent then
            veafNamedPoints.namePoint({x=endLegPoint.x, y=endLegPoint.alt, z=endLegPoint.y}, groupName .. " refuel end", unitGroup:getCoalition(), true)
        end
        
        -- compute the point where the tanker should move in the opposite direction from the desired heading, at a standard distance
        local movePoint= { x=startLegPoint.x, y=startLegPoint.y, alt=alt, speed=speed }
        local teleportPoint= { x=startLegPoint.x, y=startLegPoint.y, alt=alt, speed=speed }
        local reverseHdg = hdg - math.pi
        if reverseHdg < 0 then
            reverseHdg = reverseHdg + math.pi*2
        end
        veaf.loggers.get(veafMove.Id):trace(string.format("reverseHdg=%s",veaf.p(reverseHdg)))
        movePoint.x = startLegPoint.x + 1.5 * speed * FIRSTPOINT_DISTANCE_SECONDS * math.cos(reverseHdg)
        movePoint.y = startLegPoint.y + 1.5 * speed * FIRSTPOINT_DISTANCE_SECONDS * math.sin(reverseHdg)
        teleportPoint.x = startLegPoint.x + 3 * speed * FIRSTPOINT_DISTANCE_SECONDS * math.cos(reverseHdg)
        teleportPoint.y = startLegPoint.y + 3 * speed * FIRSTPOINT_DISTANCE_SECONDS * math.sin(reverseHdg)
        veaf.loggers.get(veafMove.Id):trace(string.format("movePoint=%s",veaf.p(movePoint)))

        -- set point1 to the computed movePoint
        point1.x = movePoint.x
        point1.y = movePoint.y
        point1.alt = movePoint.alt
        point1.speed = movePoint.speed
        veaf.loggers.get(veafMove.Id):trace(string.format("newPoint1=%s",veaf.p(point1)))

        -- set point2 to the start of the tanking Orbit (startLegPoint)
        local foundOrbit = false
        local task1 = veaf.findInTable(point2, "task")
        if task1 then
            local tasks = task1.params.tasks
            if (tasks) then
                veaf.loggers.get(veafMove.Id):trace("found " .. #tasks .. " tasks")
                for j, task in pairs(tasks) do
                    veaf.loggers.get(veafMove.Id):trace(string.format("found task #%s", veaf.p(j)))
                    if task.params then
                        veaf.loggers.get(veafMove.Id):trace("has .params")
                        if task.id and task.id == "Orbit" then
                            veaf.loggers.get(veafMove.Id):debug("Found a ORBIT task for tanker " .. groupName)
                            foundOrbit = true
                            task.params.speed = speed
                            task.params.altitude = alt
                        end
                    end
                end
            end
        end
        if not foundOrbit then 
            local text = "Cannot move tanker " .. groupName .. " because it has no ORBIT task defined"
            veaf.loggers.get(veafMove.Id):info(text)
            trigger.action.outText(text)
            return false
        end
        point2.x = startLegPoint.x
        point2.y = startLegPoint.y
        point2.alt = startLegPoint.alt
        point2.speed = startLegPoint.speed
        veaf.loggers.get(veafMove.Id):trace(string.format("newPoint2=%s",veaf.p(point2)))

        -- set point2 to the end of the tanking Orbit (endLegPoint)
        point3.x = endLegPoint.x
        point3.y = endLegPoint.y
        point3.alt = endLegPoint.alt
        point3.speed = endLegPoint.speed
        veaf.loggers.get(veafMove.Id):trace("newpoint3="..veaf.p(point3))

        --actually move the group
        local delay = 0

        -- teleport if the option is set
        if teleport then
            veaf.loggers.get(veafMove.Id):debug("Teleport the tanker")   
            local vars = { groupName = groupName, point = teleportPoint, action = "teleport"}
            local grp = mist.teleportToPoint(vars)
            unitGroup = Group.getByName(groupName)

            veafMove.teleportEscort(groupName, movePoint, teleportPoint)

            delay = 1
        end

        veaf.loggers.get(veafMove.Id):debug(string.format("Resetting moved tanker mission in %d seconds", delay))
        veafMove.replaceMission(unitGroup, tankerData, delay)

        return true
    else
        return false
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Escort move method, only called internally
-- @param escorted_groupName, string, corresponds to the groupname of the aicraft being escorted
-- @param movePoint, vec3 + speed, corresponds to the first waypoint that the escorted aircraft will take after it was moved
-- @param teleportPoint, vec3 + speed, corresponds to the waypoint on which the escorted aircraft is teleported to, this is required
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafMove.teleportEscort(escorted_groupName, movePoint, teleportPoint)

    --verify existence of the escorted aircraft
    local unitGroup = Group.getByName(escorted_groupName)

    if not unitGroup then
        veaf.loggers.get(veafMove.Id):info("Cannot move the escort of " .. escorted_groupName .. " ; this groupName does not correspond to any aircraft")
        return false
    end

    --verify the existence of the escort and proper configuration
    local escortedId = Group.getID(unitGroup) --this and only this serves as a groupID, what is given in EscortData does not correspond on the DCS side
    local groupName_escort = escorted_groupName .. " escort" --standardized escort groupName
    local unitGroup_escort = Group.getByName(groupName_escort)
    local escort_flag = false --indicates the go ahead for teleport/replaceMission calls
    local route_escort = {}
    local points_escort = {}
    local idxPoint1_escort = nil
    local idxPoint2_escort = nil
    local point1_escort = {}
    local point2_escort = {}
    local task2_escort = {}
    local tasks_escort = {}
    local task_escort = {}
    local EscortData = {}
    if unitGroup_escort ~= nil then  
        EscortData = veaf.getGroupData(groupName_escort)
        if not(EscortData) then
            local text = "Cannot move Escort " .. groupName_escort .. " ; no group data"
            veaf.loggers.get(veafMove.Id):info(text)
        else
            veaf.loggers.get(veafMove.Id):trace("EscortData : %s", veaf.p(EscortData))
            route_escort = veaf.findInTable(EscortData, "route")
            points_escort = veaf.findInTable(route_escort, "points")

            if points_escort then
                veaf.loggers.get(veafMove.Id):debug("Escort has WP")
                idxPoint1_escort = #points_escort-1 --second to last waypoint
                idxPoint2_escort = #points_escort --last waypoint where the escort has to be set up in the editor
                point1_escort = points_escort[idxPoint1_escort]
                point2_escort = points_escort[idxPoint2_escort]
                task2_escort = veaf.findInTable(point2_escort, "task")
                if task2_escort.params.tasks then
                    veaf.loggers.get(veafMove.Id):debug("Last escort WP has tasks")
                    tasks_escort = task2_escort.params.tasks
                    for k, task in pairs(tasks_escort) do
                        --if task.enabled and task.id and task.id == "Escort" and task.params and task.params.groupId == unitGroup_Id then --this line should be used to verify proper configuration of the escort but as it turns out the groupId stored in params has nothing to do with the groupId DCS needs for the escort task, use Group.getID(groupClass) instead to get the correct ID required for DCS, but no way to derive it from EscortData 
                        if task.enabled and task.id and task.id == "Escort" and task.params then
                            veaf.loggers.get(veafMove.Id):trace("Found correct escort Tasking ! Extracted Escorted ID : %s", task.params.groupId)
                            veaf.loggers.get(veafMove.Id):trace("Required escort ID : %s", escortedId)
                            escort_flag = true
                            task_escort=task --recover the escort task table to insert the "new" escorted ID, even though it's the same but it seems DCS destroys it after the escorted group respawns
                        end
                    end
                end
            end
        end
    else
        veaf.loggers.get(veafMove.Id):info(groupName_escort .. ' not found for move tanker escort command')
    end

    if not escort_flag then 
        return false 
    end
    
    --distances by which the escort is offseted from the escorted group in the map's referential, task_escort provides relative spacing
    local escort_offset = {}
    local hdg = veaf.headingBetweenPoints(teleportPoint, movePoint)
    escort_offset.x = (task_escort.params.pos.x*math.cos(hdg) - task_escort.params.pos.z*math.sin(hdg))
    escort_offset.z = (task_escort.params.pos.x*math.sin(hdg) + task_escort.params.pos.z*math.cos(hdg))

    local teleportPoint_escort = {}
    teleportPoint_escort.x = teleportPoint.x + escort_offset.x
    teleportPoint_escort.y = teleportPoint.y + escort_offset.z
    teleportPoint_escort.alt = teleportPoint.alt + task_escort.params.pos.y
    teleportPoint_escort.speed = teleportPoint.speed

    --Effectively waypoint 0, the AI will have to fly over it and in the editor it never poses a problem but in scripting the AI will do orbits to try and reach it
    --so it has to be offseted
    point1_escort.x = (teleportPoint.x + movePoint.x)/2 + escort_offset.x
    point1_escort.y = (teleportPoint.y + movePoint.y)/2 + escort_offset.z
    point1_escort.alt = movePoint.alt + task_escort.params.pos.y
    point1_escort.speed = movePoint.speed

    --Waypoint 1 where the escort tasking will come into play
    point2_escort.x = 2*point1_escort.x - teleportPoint.x - escort_offset.x
    point2_escort.y =  2*point1_escort.y - teleportPoint.y - escort_offset.z
    point2_escort.alt = movePoint.alt + task_escort.params.pos.y
    point2_escort.speed = movePoint.speed

    task_escort.params.groupId = escortedId --assign the new groupID within the old escort mission, only necessary after teleporting as the tanker's ID will have changed
    
    veaf.loggers.get(veafMove.Id):debug("Teleport the escort")   
    local vars_escort = { groupName = groupName_escort, point = teleportPoint_escort, action = "teleport"}
    local grp_escort = mist.teleportToPoint(vars_escort)
    unitGroup_escort = Group.getByName(groupName_escort)

    veafMove.replaceMission(unitGroup_escort, EscortData)
    --this method appears to not work very well, the escort just doesn't defend the group

    --mist.goRoute(groupName_escort, route_escort)
    --works even worse, sends them to X=0, Z=0

    return true
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- support method to replace the mission of moved aircraft (default delay of 1s for teleported aircraft)
-- @param unitGroup, data returned by the Group.getByName(groupName) command
-- @param missionData, data returned by the veaf.getGroupData(groupName) command
-- @optional param delay, integer, delay to apply before replacing the mission, useful when teleporting, recommended 1s for such a scenario (which is the default value)
-- @optional param immortal, boolean, sets the group which is seeing it's mission replaced to immortal and invisible
-------------------------------------------------------------------------------------------------------------------------------------------------------------
function veafMove.replaceMission(unitGroup, missionData, delay, immortal)

    local delay = delay or 1

    local actualReplaceMission = function(unitGroup, missionData, immortal)

        local freq = missionData.frequency or 243 --set frequency or guard channel
        local mod = missionData.modulation or 0 --set modulation or AM (=0)
        
        veaf.loggers.get(veafMove.Id):debug(string.format("Resetting %s mission", unitGroup:getName()))
        veaf.loggers.get(veafMove.Id):debug(string.format("replaceMissionData=%s", veaf.p(missionData)))
        --... for the escort, necessary to re assign the mission wether the tanker was teleported (== changed ID) or not because DCS

        local mission = { 
            id = 'Mission', 
            params = missionData 
        }
        local controller = unitGroup:getController()
        controller:setTask(mission)

        if immortal then
            -- JTAC needs to be invisible and immortal
            veaf.loggers.get(veafMove.Id):trace("Group immortalized")
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

            Controller.setCommand(controller, _setImmortal)
            Controller.setCommand(controller, _setInvisible)
        end

        --have to set the frequency again as setTask seems to ignore missionData.frequency and switch the unit to 124AM
        local _setFrequency = {
            id = 'SetFrequency',
            params = {
                frequency = freq * 1000000,
                modulation = mod
            }
        }

        Controller.setCommand(controller, _setFrequency)
    end

    mist.scheduleFunction(actualReplaceMission, {unitGroup, missionData, immortal}, timer.getTime()+delay)
end

------------------------------------------------------------------------------
-- veafMove.moveAfac
-- @param point eventPos
-- @param string groupName 
-- @param float speed in knots
-- @param float alt in feet
-- @param float hdg in degrees
-- @param boolean immortal
------------------------------------------------------------------------------
function veafMove.moveAfac(eventPos, groupName, speed, alt, heading, immortal)
    if not speed then
        speed = 150
    end
    if not alt then
        alt = 20000
    end
    veaf.loggers.get(veafMove.Id):debug("veafMove.moveAfac(groupName = " .. groupName .. ", speed = " .. speed .. ", alt = " .. alt)
    veaf.loggers.get(veafMove.Id):debug(string.format("veafMove.moveAfac: eventPos  x=%.1f z=%.1f", eventPos.x, eventPos.z))

    local distanceFromTeleport = 3000 --distance between the orbit point and the teleport point in meters

	local unitGroup = Group.getByName(groupName)
	if unitGroup == nil then
        veaf.loggers.get(veafMove.Id):info(groupName .. ' not found for move afac command')
		trigger.action.outText(groupName .. ' not found for move afac command' , 10)
		return false
	end

    local coalition = unitGroup:getCoalition()

    local afacData = veaf.getGroupData(groupName)
    local isDynamicallySpawned = false
    if not afacData then
        for number, dynAFACcallsign in pairs(veafSpawn.AFAC.callsigns[coalition]) do
            if groupName:find(dynAFACcallsign.name) then
                veaf.loggers.get(veafMove.Id):trace("AFAC is dynamically spawned")
                afacData = veafSpawn.AFAC.missionData[coalition][number]
                isDynamicallySpawned = true
            end
        end
    end
    veaf.loggers.get(veafMove.Id):trace("Found AFAC named " .. groupName .. " for move command")
    veaf.loggers.get(veafMove.Id):debug(string.format("AFAC mission data is : %s", veaf.p(afacData)))

    local route_afac = veaf.findInTable(afacData, "route")
    local points_afac = veaf.findInTable(route_afac, "points")
    if points_afac then

        veaf.loggers.get(veafMove.Id):trace("Found AFAC waypoints")
        local idxPoint1_afac = #points_afac-1 --second to last waypoint
        local idxPoint2_afac = #points_afac --last waypoint
        local point1_afac = points_afac[idxPoint1_afac]
        local point2_afac = points_afac[idxPoint2_afac]
        local FACflag = false
        local OrbitFlag = false
    
        -- if hdg is not set, compute heading between point1 and point2
        local hdg = heading
        if hdg == nil then
            hdg = veaf.headingBetweenPoints(point1_afac, point2_afac)
        else
            hdg = heading * math.pi/180
        end
        
        -- teleport position
        local teleportPosition = {
            ["x"] = eventPos.x - distanceFromTeleport*math.cos(hdg), --teleport 3km south of orbit point
            ["y"] = eventPos.z - distanceFromTeleport*math.sin(hdg),
            ["alt"] = alt * 0.3048 -- in meters
        }

        -- orbit position
        local fromPosition = {
            ["x"] = eventPos.x,
            ["y"] = eventPos.z
        }

        --check valid configuration of the AFAC
        if point1_afac and point2_afac then
            veaf.loggers.get(veafMove.Id):debug("AFAC has at least the two waypoints required")
            local tasks1_afac=point1_afac.task.params.tasks
            local tasks2_afac=point2_afac.task.params.tasks
            if tasks1_afac and tasks2_afac then
                for _, task in pairs(tasks1_afac) do
                    if task.id == "FAC" then
                        veaf.loggers.get(veafMove.Id):trace("FAC configuration valid on second to last WP")
                        FACflag = true
                    end
                end

                for _, task in pairs(tasks2_afac) do
                    if task.id == "Orbit" then
                        veaf.loggers.get(veafMove.Id):trace("AFAC Orbit configuration valid on last WP")
                        OrbitFlag = true
                    end
                end
            end
        end

        if FACflag == false or OrbitFlag == false then
            veaf.loggers.get(veafMove.Id):info(groupName .. ' has an invalid FAC/Orbit configuration')
            trigger.action.outText(groupName .. ' has an invalid FAC/Orbit configuration' , 10)
            return false
        end

        --edit the last two waypoints of the AFAC's flight plan with the new requested position,speed and alt info
        point1_afac.speed=speed
        point1_afac.alt=teleportPosition.alt
        point1_afac.x=teleportPosition.x + distanceFromTeleport*math.cos(hdg)/2
        point1_afac.y=teleportPosition.y + distanceFromTeleport*math.sin(hdg)/2
    
        point2_afac.speed=speed
        point2_afac.alt=teleportPosition.alt
        point2_afac.x=eventPos.x
        point2_afac.y=eventPos.z

        --teleport the group south of the requested location
        veaf.loggers.get(veafMove.Id):trace("AFAC ".. groupName .. " teleported")
        local vars = { groupName = groupName, point = teleportPosition, action = "teleport" }
        if isDynamicallySpawned then
            vars = { groupName = groupName, groupData = afacData, anyTerrain = true, point = teleportPosition, action = "teleport" }
        end
        local grp = mist.teleportToPoint(vars)
        unitGroup = Group.getByName(groupName) --refresh group class after respawn, not necessary but safer considering at least the groupId changes
    
        --necessary delay for the following code to not be ignored
        local delay=1
    
        -- replace whole mission
        veafMove.replaceMission(unitGroup, afacData, delay, immortal)
        
        return true
    else
        return false
    end

end

-- prepare tanker units
function veafMove.findAllTankers()
    local TankerTypeNames = {"KC130", "KC-135", "KC135MPRS", "KJ-2000", "IL-78M"}
    veaf.loggers.get(veafMove.Id):trace(string.format("findAllTankers()"))
    local result = {}
    local units = mist.DBs.unitsByName -- local copy for faster execution
    for name, unit in pairs(units) do
        veaf.loggers.get(veafMove.Id):trace(string.format("name=%s, unit.type=%s", veaf.p(name), veaf.p(unit.type)))
        --veaf.loggers.get(veafMove.Id):trace(string.format("unit=%s", veaf.p(unit)))
        --local unit = Unit.getByName(name)
        if unit then 
            for _, tankerTypeName in pairs(TankerTypeNames) do
                if tankerTypeName:lower() == unit.type:lower() then
                    table.insert(result, unit.groupName)
                end
            end
        end
    end
    return result
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build a radio menu to move or teleport a tanker
function veafMove.moveTankerToMe(parameters)
    local subParameters, unitName = veaf.safeUnpack(parameters)
    local tankerName, direction = veaf.safeUnpack(subParameters)
    veaf.loggers.get(veafMove.Id):debug(string.format("veafMove.moveTankerToMe(tankerName=%s, unitName=%s, direction=%d)", tankerName, unitName, direction))
    local unit = Unit.getByName(unitName)
    if unit then
        local unitType = unit:getDesc()["typeName"]
        veaf.loggers.get(veafMove.Id):trace(string.format("checking unit %s of type %s", tostring(unitName), tostring(unitType)))
        local tankerMissionParameters = veafMove.tankerMissionParameters[unitType]
        if not tankerMissionParameters then
            tankerMissionParameters = { speed = -1, alt = -1}  -- -1 means to use the currently defined speed and altitude
        end
        veafMove.moveTanker(unit:getPosition().p, tankerName, tankerMissionParameters.speed, tankerMissionParameters.alt, direction, nil, true, false)
        veaf.outTextForUnit(unitName, string.format("%s - Moving to your position right away !", tankerName), 15)
    end
end

--- Build the initial radio menu
function veafMove.buildRadioMenu()
    veaf.loggers.get(veafMove.Id):debug(string.format("veafMove.buildRadioMenu()"))
    veafMove.rootPath = veafRadio.addSubMenu(veafMove.RadioMenuName)
    if not(veafRadio.skipHelpMenus) then
        veafRadio.addCommandToSubmenu("HELP", veafMove.rootPath, veafMove.help, nil, veafRadio.USAGE_ForGroup)
    end
    for _, tankerUnitName in pairs(veafMove.Tankers) do
        local tankerName = tankerUnitName
        if veafAssets then
            veaf.loggers.get(veafMove.Id):trace(string.format("searching for asset name %s", tankerUnitName))
            local asset = veafAssets.get(tankerUnitName)
            if asset then 
                tankerName = asset.description
                veaf.loggers.get(veafMove.Id):trace(string.format("found asset name : %s", tankerName))
            end
        end
        -- Move tanker to me
        local menuName = string.format("%s - WEST", tankerName)
        local moveTankerPath = veafRadio.addSubMenu(menuName, veafMove.rootPath)
        veafRadio.addCommandToSubmenu(menuName, moveTankerPath, veafMove.moveTankerToMe, {tankerUnitName, 270}, veafRadio.USAGE_ForGroup)    

        menuName = string.format("%s - EAST", tankerName)
        moveTankerPath = veafRadio.addSubMenu(menuName, veafMove.rootPath)
        veafRadio.addCommandToSubmenu(menuName, moveTankerPath, veafMove.moveTankerToMe, {tankerUnitName, 90}, veafRadio.USAGE_ForGroup)    
    end
end

function veafMove.help(unitName)
    local text = 
        'Create a marker and type "_move <group|tanker|afac>, name <groupname> " in the text\n' ..
        'This will issue a move command to the specified group in the DCS world\n' ..
        'Type "_move group, name [groupname]" to move the specified group to the marker point\n' ..
        '     add ", speed [speed]" to make the group move and at the specified speed (in knots)\n' ..
        'Type "_move tanker, name [groupname]" to create a new tanker flight plan and move the specified tanker.\n' ..
        '     add ", speed [speed]" to make the tanker move and execute its refuel mission at the specified speed (in knots)\n' ..
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
    if #veafMove.Tankers == 0 then
        -- find all existing Tankers
        veafMove.Tankers = veafMove.findAllTankers()
    end
    veafMove.buildRadioMenu()
    veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafMove.onEventMarkChange)
end

veaf.loggers.get(veafMove.Id):info(string.format("Loading version %s", veafMove.Version))
