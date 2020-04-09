-- VEAF name point command and functions for DCS World
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- By zip (2018)
--
-- Features:
-- ---------
-- * Listen to marker change events and name the corresponding point, for future reference
-- * Works with all current and future maps (Caucasus, NTTR, Normandy, PG, ...)
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires the base veaf.lua script library (version 1.0 or higher)
-- * It also requires the veafMarkers.lua script library (version 1.0 or higher)
--
-- Basic Usage:
-- ------------
-- 1.) Place a mark on the F10 map.
-- 2.) As text enter "veaf name point, name [the point name]"
-- 3.) Click somewhere else on the map to submit the new text.
-- 4.) The command will be processed. A message will appear to confirm this
-- 5.) The original mark will stay in place, with a text explaining the point name.
--
-- *** NOTE ***
-- * All keywords are CaSE inSenSITvE.
-- * Commas are the separators between options ==> They are IMPORTANT!
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafNamedPoints = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafNamedPoints.Id = "NAMED POINTS - "

--- Version.
veafNamedPoints.Version = "1.2.5"

-- trace level, specific to this module
veafNamedPoints.Trace = false

--- Key phrase to look for in the mark text which triggers the command.
veafNamedPoints.Keyphrase = "_name point"

veafNamedPoints.Points = {
    --- these points will be processed at initialisation time
}

veafNamedPoints.RadioMenuName = "NAMED POINTS"

veafNamedPoints.LowerRadioMenuSize = true
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafNamedPoints.namedPoints = {}

veafNamedPoints.rootPath = nil
veafNamedPoints.weatherPath = nil
veafNamedPoints.atcPath = nil
veafNamedPoints.atcClosestPath = nil

--- Initial Marker id.
veafNamedPoints.markid=1270000

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafNamedPoints.logInfo(message)
    veaf.logInfo(veafNamedPoints.Id .. message)
end

function veafNamedPoints.logDebug(message)
    veaf.logDebug(veafNamedPoints.Id .. message)
end

function veafNamedPoints.logTrace(message)
    if message and veafNamedPoints.Trace then
        veaf.logTrace(veafNamedPoints.Id .. message)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function executed when a mark has changed. This happens when text is entered or changed.
function veafNamedPoints.onEventMarkChange(eventPos, event)
    if veafNamedPoints.executeCommand(eventPos, event) then 

        -- Delete old mark.
        --veafNamedPoints.logTrace(string.format("Removing mark # %d.", event.idx))
        trigger.action.removeMark(event.idx)
    end
end

function veafNamedPoints.executeCommand(eventPos, event, bypassSecurity)

    -- Check if marker has a text and the veafNamedPoints.keyphrase keyphrase.
    if event.text ~= nil and event.text:lower():find(veafNamedPoints.Keyphrase) then

        -- Analyse the mark point text and extract the keywords.
        local options = veafNamedPoints.markTextAnalysis(event.text)

        if options then
            -- Check options commands
            if options.namepoint then
                -- create the mission
                veafNamedPoints.namePoint(eventPos, options.name, event.coalition)
            end
            return true
        else
            -- None of the keywords matched.
            return false
        end
    end
    return false
end    
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the mark text and extract keywords.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Extract keywords from mark text.
function veafNamedPoints.markTextAnalysis(text)

    -- Option parameters extracted from the mark text.
    local switch = {}
    switch.namepoint = false

    switch.name = "point"

    -- Check for correct keywords.
    local pos = text:lower():find(veafNamedPoints.Keyphrase)
    if pos then
        switch.namepoint = true
    else
        return nil
    end

    -- the point name should follow a space
    switch.name = text:sub(pos+string.len(veafNamedPoints.Keyphrase)+1)
    --veafNamedPoints.logDebug(string.format("Keyword name = %s", switch.name))

    return switch
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Named points management
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Create the point in the named points database
function veafNamedPoints.namePoint(targetSpot, name, coalition)
    --veafNamedPoints.logDebug(string.format("namePoint(name = %s, coalition=%s)",name, coalition))
    --veafNamedPoints.logDebug("targetSpot=" .. veaf.vecToString(targetSpot))

    veafNamedPoints.addPoint(name, targetSpot)

    local message = "The point named " .. name .. " has been created. See F10 radio menu for details."
    trigger.action.outText(message,5)

    veafNamedPoints.markid = veafNamedPoints.markid + 1
    trigger.action.markToCoalition(veafNamedPoints.markid, "VEAF - Point named "..name, targetSpot, coalition, true, "VEAF - Point named "..name.." added for own coalition.") 

end

function veafNamedPoints._addPoint(name, point)
    --veafNamedPoints.logTrace(string.format("addPoint(name = %s)",name))
    --veafNamedPoints.logTrace("point=" .. veaf.vecToString(point))
    veafNamedPoints.namedPoints[name:upper()] = point
end

function veafNamedPoints.addPoint(name, point)
    --veafNamedPoints.logTrace(string.format("addPoint: {name=\"%s\",point={x=%d,y=0,z=%d}}", name, point.x, point.z))
    veafNamedPoints._addPoint(name, point)
    veafNamedPoints._refreshAtcRadioMenu()
    veafNamedPoints._refreshWeatherReportsRadioMenu()
end

function veafNamedPoints.delPoint(name)
    --veafNamedPoints.logTrace(string.format("delPoint(name = %s)",name))

    table.remove(veafNamedPoints.namedPoints, name:upper())
end

function veafNamedPoints.getPoint(name)
    --veafNamedPoints.logTrace(string.format("getPoint(name = %s)",name))

    return veafNamedPoints.namedPoints[name:upper()]
end

function veafNamedPoints.getWeatherAtPoint(parameters)
    local name, unitName = unpack(parameters)
    --veafNamedPoints.logTrace(string.format("getWeatherAtPoint(name = %s)",name))
    local point = veafNamedPoints.getPoint(name)
    if point then
        local weatherReport = veaf.weatherReport(point, nil, true)
        veaf.outTextForUnit(unitName, weatherReport, 30)
    end
end

function veafNamedPoints.getAtcAtPoint(parameters)
    local name, unitName = unpack(parameters)
    --veafNamedPoints.logTrace(string.format("getAtcAtPoint(name = %s)",name))
    local point = veafNamedPoints.getPoint(name)
    if point then
        -- exanple : point={x=-315414,y=480,z=897262, atc=true, tower="138.00", runways={{name="12R", hdg=121, ils="110.30"},{name="30L", hdg=301, ils="108.90"}}}
        local atcReport = "ATC            : " .. name .. "\n"
        
        -- runway and other information
        if point.tower then
            atcReport = atcReport .. "TOWER          : " .. point.tower .. "\n"
        end
        if point.runways then
            for _, runway in pairs(point.runways) do
                if not runway.name then
                    runway.name = math.floor((runway.hdg/10)+0.5)*10
                end
                -- ils when available
                local ils = ""
                if runway.ils then
                    ils = " ILS " .. runway.ils
                end
                -- pop flare if needed
                local flare = ""
                if runway.flare then
                    flare = " marked with ".. runway.flare .. " signal flare"
                    local flareColor = trigger.flareColor.Green
                    if runway.flare:upper() == "RED" then
                        flareColor = trigger.flareColor.Red
                    end
                    if runway.flare:upper() == "WHITE" then
                        flareColor = trigger.flareColor.White
                    end
                    if runway.flare:upper() == "YELLOW" then
                        flareColor = trigger.flareColor.Yellow
                    end
                    for i = 1, 10 do
                        mist.scheduleFunction(veafSpawn.spawnSignalFlare, {point, flareColor , runway.hdg + mist.random(6) - 3}, timer.getTime() + i*2)
                    end
                end
                atcReport = atcReport .. "RUNWAY         : " .. runway.name .. " heading " .. runway.hdg .. ils .. flare .. "\n"
            end
        end

        -- weather
        atcReport = atcReport .. "\n\n"
        local weatherReport = veaf.weatherReport(point)
        atcReport = atcReport ..weatherReport
        veaf.outTextForUnit(unitName, atcReport, 30)
    end
end

function veafNamedPoints.buildPointsDatabase()
    veafNamedPoints.namedPoints = {}
    for name, defaultPoint in pairs(veafNamedPoints.Points) do
        veafNamedPoints._addPoint(defaultPoint.name, defaultPoint.point)
    end
end

function veafNamedPoints.listAllPoints(unitName)
    --veafNamedPoints.logDebug(string.format("listAllPoints(unitName = %s)",unitName))
    local message = ""
    names = {}
    for name, point in pairs(veafNamedPoints.namedPoints) do
        table.insert(names, name)
    end
    table.sort(names)
    for _, name in pairs(names) do
        local point = veafNamedPoints.namedPoints[name]
        local lat, lon = coord.LOtoLL(point)
        message = message .. name .. " => " .. mist.tostringLL(lat, lon, 2) .. "\n"
    end

    -- send message only for the unit
    veaf.outTextForUnit(unitName, message, 30)
end

function veafNamedPoints.getAtcAtClosestPoint(unitName)
    --veafNamedPoints.logDebug(string.format("veafNamedPoints.getAtcAtClosestPoint(unitName=%s)",unitName))
    local closestPointName = nil
    local minDistance = 99999999
    local unit = Unit.getByName(unitName)
    if unit then
        for name, point in pairs(veafNamedPoints.namedPoints) do
            if point.atc then
                distanceFromPlayer = ((point.x - unit:getPosition().p.x)^2 + (point.z - unit:getPosition().p.z)^2)^0.5
                --veafNamedPoints.logTrace(string.format("distanceFromPlayer = %d",distanceFromPlayer))
                if distanceFromPlayer < minDistance then
                    minDistance = distanceFromPlayer
                    closestPointName = name
                    --veafNamedPoints.logTrace(string.format("point %s is closest",name))
                end
            end
        end
    end
    if closestPointName then
        veafNamedPoints.getAtcAtPoint({closestPointName, unitName})
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafNamedPoints._buildWeatherReportsRadioMenuPage(menu, names, pageSize, startIndex)
    --veafNamedPoints.logTrace(string.format("veafNamedPoints._buildWeatherReportsRadioMenuPage(pageSize=%d, startIndex=%d)",pageSize, startIndex))
    
    local namesCount = #names
    --veafNamedPoints.logTrace(string.format("namesCount = %d",namesCount))

    local endIndex = namesCount
    if endIndex - startIndex >= pageSize then
        endIndex = startIndex + pageSize - 2
    end
    --veafNamedPoints.logTrace(string.format("endIndex = %d",endIndex))
    --veafNamedPoints.logTrace(string.format("adding commands from %d to %d",startIndex, endIndex))
    for index = startIndex, endIndex do
        local name = names[index]
        --veafNamedPoints.logTrace(string.format("names[%d] = %s",index, name))
        local namedPoint = veafNamedPoints.namedPoints[name]
        veafRadio.addCommandToSubmenu( name , menu, veafNamedPoints.getWeatherAtPoint, name, veafRadio.USAGE_ForGroup)    
    end
    if endIndex < namesCount then
        --veafNamedPoints.logTrace("adding next page menu")
        local nextPageMenu = veafRadio.addSubMenu("Next page", menu)
        veafNamedPoints._buildWeatherReportsRadioMenuPage(nextPageMenu, names, 10, endIndex+1)
    end
end

--- refresh the Weather Reports radio menu
function veafNamedPoints._refreshWeatherReportsRadioMenu()
    if not veafNamedPoints.LowerRadioMenuSize then
        if veafNamedPoints.weatherPath then
            --veafNamedPoints.logTrace("deleting weather report submenu")
            veafRadio.delSubmenu(veafNamedPoints.weatherPath, veafNamedPoints.rootPath)
        end
        --veafNamedPoints.logTrace("adding weather report submenu")
        veafNamedPoints.weatherPath = veafRadio.addSubMenu("Get weather report over a point", veafNamedPoints.rootPath)
        names = {}
        for name, point in pairs(veafNamedPoints.namedPoints) do
            table.insert(names, name)
        end
        table.sort(names)
        veafNamedPoints._buildWeatherReportsRadioMenuPage(veafNamedPoints.weatherPath, names, 10, 1)
        veafRadio.refreshRadioMenu()
    end
end

function veafNamedPoints._buildAtcRadioMenuPage(menu, names, pageSize, startIndex)
    --veafNamedPoints.logTrace(string.format("veafNamedPoints._buildAtcRadioMenuPage(pageSize=%d, startIndex=%d)",pageSize, startIndex))

    local namesCount = #names
    --veafNamedPoints.logTrace(string.format("namesCount = %d",namesCount))

    local endIndex = namesCount
    if endIndex - startIndex >= pageSize then
        endIndex = startIndex + pageSize - 2
    end
    --veafNamedPoints.logTrace(string.format("endIndex = %d",endIndex))
    --veafNamedPoints.logTrace(string.format("adding commands from %d to %d",startIndex, endIndex))
    for index = startIndex, endIndex do
        local name = names[index]
        --veafNamedPoints.logTrace(string.format("names[%d] = %s",index, name))
        local namedPoint = veafNamedPoints.namedPoints[name]
        veafRadio.addCommandToSubmenu( name , menu, veafNamedPoints.getAtcAtPoint, name, veafRadio.USAGE_ForGroup)    
    end
    if endIndex < namesCount then
        --veafNamedPoints.logTrace("adding next page menu")
        local nextPageMenu = veafRadio.addSubMenu("Next page", menu)
        veafNamedPoints._buildAtcRadioMenuPage(nextPageMenu, names, 10, endIndex+1)
    end
end

--- refresh the ATC radio menu
function veafNamedPoints._refreshAtcRadioMenu()
    --veafNamedPoints.logTrace("adding ATC On Closest Point submenu")
    if veafNamedPoints.atcClosestPath then
        --veafNamedPoints.logTrace("deleting ATC On Closest Point submenu")
        veafRadio.delSubmenu(veafNamedPoints.atcClosestPath, veafNamedPoints.rootPath)
    end
    veafNamedPoints.atcClosestPath = veafRadio.addSubMenu("ATC on closest point", veafNamedPoints.rootPath)
    veafRadio.addCommandToSubmenu("ATC on closest point" , veafNamedPoints.atcClosestPath, veafNamedPoints.getAtcAtClosestPoint, nil, veafRadio.USAGE_ForUnit)    

    if not veafNamedPoints.LowerRadioMenuSize then
        if veafNamedPoints.atcPath then
            --veafNamedPoints.logTrace("deleting ATC submenu")
            veafRadio.delSubmenu(veafNamedPoints.atcPath, veafNamedPoints.rootPath)
        end
        --veafNamedPoints.logTrace("adding ATC submenu")
        veafNamedPoints.atcPath = veafRadio.addSubMenu("ATC", veafNamedPoints.rootPath)
        names = {}
        for name, point in pairs(veafNamedPoints.namedPoints) do
            if point.atc then
                table.insert(names, name)
            end
        end
        table.sort(names)
        veafNamedPoints._buildAtcRadioMenuPage(veafNamedPoints.atcPath, names, 10, 1)
    end

    veafRadio.refreshRadioMenu()
end

--- Build the initial radio menu
function veafNamedPoints.buildRadioMenu()
    veafNamedPoints.rootPath = veafRadio.addSubMenu(veafNamedPoints.RadioMenuName)
    veafRadio.addCommandToSubmenu("HELP", veafNamedPoints.rootPath, veafNamedPoints.help, nil, veafRadio.USAGE_ForGroup)
    veafRadio.addCommandToSubmenu("List all points", veafNamedPoints.rootPath, veafNamedPoints.listAllPoints, nil, veafRadio.USAGE_ForGroup)
    veafNamedPoints._refreshAtcRadioMenu()
    veafNamedPoints._refreshWeatherReportsRadioMenu()
end

--      add ", defense [1-5]" to specify air defense cover on the way (1 = light, 5 = heavy)
--      add ", size [1-5]" to change the number of cargo items to be transported (1 per participating helo, usually)
--      add ", blocade [1-5]" to specify enemy blocade around the drop zone (1 = light, 5 = heavy)
function veafNamedPoints.help(unitName)
    local text =
        'Create a marker and type "_name point [a name]" in the text\n' ..
        'This will store the position in the named points database for later reference\n'
        veaf.outTextForUnit(unitName, text, 30)
end


-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafNamedPoints.initialize()
    veafNamedPoints.buildPointsDatabase()
    veafNamedPoints.buildRadioMenu()
    veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafNamedPoints.onEventMarkChange)
end

veafNamedPoints.logInfo(string.format("Loading version %s", veafNamedPoints.Version))
