-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF spawn command and functions for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- * Listen to marker change events and execute spawn commands, with optional parameters
-- * Possibilities : 
-- *    - spawn a specific ennemy unit or group
-- *    - create a cargo drop to be picked by a helo
-- * Works with all current and future maps (Caucasus, NTTR, Normandy, PG, ...)
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires the base veaf.lua script library (version 1.0 or higher)
-- * It also requires the veafMarkers.lua script library (version 1.0 or higher)
-- * It also requires the dcsUnits.lua script library (version 1.0 or higher)
-- * It also requires the veafUnits.lua script library (version 1.0 or higher)
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
--     * OPEN --> Browse to the location of veafUnits.lua and click OK.
--     * ACTION "DO SCRIPT FILE"
--     * OPEN --> Browse to the location of this script and click OK.
--     * ACTION "DO SCRIPT"
--     * set the script command to "veafSpawn.initialize()" and click OK.
-- 4.) Save the mission and start it.
-- 5.) Have fun :)
--
-- Basic Usage:
-- ------------
-- 1.) Place a mark on the F10 map.
-- 2.) As text enter a command
-- 3.) Click somewhere else on the map to submit the new text.
-- 4.) The command will be processed. A message will appear to confirm this
-- 5.) The original mark will disappear.
--
-- Commands and options: see online help function veafSpawn.help()
--
-- *** NOTE ***
-- * All keywords are CaSE inSenSITvE.
-- * Commas are the separators between options ==> They are IMPORTANT!
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- veafSpawn Table.
veafSpawn = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafSpawn.Id = "SPAWN"

--- Version.
veafSpawn.Version = "1.29.0"

-- trace level, specific to this module
--veafSpawn.LogLevel = "trace"

veaf.loggers.new(veafSpawn.Id, veafSpawn.LogLevel)

--- Key phrase to look for in the mark text which triggers the spawn command.
veafSpawn.SpawnKeyphrase = "_spawn"

--- Key phrase to look for in the mark text which triggers the destroy command.
veafSpawn.DestroyKeyphrase = "_destroy"

--- Key phrase to look for in the mark text which triggers the teleport command.
veafSpawn.TeleportKeyphrase = "_teleport"

--- Key phrase to look for in the mark text which triggers the drawing commands.
veafSpawn.DrawingKeyphrase = "_drawing"

--- Name of the spawned units group 
veafSpawn.RedSpawnedUnitsGroupName = "VEAF Spawned Units"

--- Illumination flare default initial altitude (in meters AGL)
veafSpawn.IlluminationFlareAglAltitude = 1000

veafSpawn.RadioMenuName = "SPAWN"

--- static object type spawned when using the "logistic" keyword
veafSpawn.LogisticUnitType = "FARP Ammo Dump Coating"
veafSpawn.LogisticUnitCategory = "Fortifications"

veafSpawn.ShellingInterval = 5 -- seconds between shells, randomized by 30%
veafSpawn.FlakingInterval = 2 -- seconds between flak shells, randomized by 30%
veafSpawn.IlluminationShellingInterval = 30 -- seconds between illumination shells, randomized by 30%

veafSpawn.MIN_REPEAT_DELAY = 5

veafSpawn.AirUnitTemplatesPrefix = "veafSpawn-"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSpawn.rootPath = nil

-- counts the units generated 
veafSpawn.spawnedUnitsCounter = 0

-- store all the convoys spawned
veafSpawn.spawnedConvoys = {}

-- store all the air units templates (groups, actually)
veafSpawn.airUnitTemplates = {}

-- all the named groups that have been spawned
veafSpawn.spawnedNamesIndex = {}

veafSpawn.traceMarkerId = 3727

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function executed when a mark has changed. This happens when text is entered or changed.
function veafSpawn.onEventMarkChange(eventPos, event)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("event  = %s", veaf.p(event)))

    -- choose by default the coalition opposing the player who triggered the event
    local invertedCoalition = 1
    if event.coalition == 1 then
        invertedCoalition = 2
    end

    veaf.loggers.get(veafSpawn.Id):trace(string.format("event.idx  = %s", veaf.p(event.idx)))

    if veafSpawn.executeCommand(eventPos, event.text, invertedCoalition, event.idx) then 
        
        -- Delete old mark.
        veaf.loggers.get(veafSpawn.Id):trace(string.format("Removing mark # %d.", event.idx))
        trigger.action.removeMark(event.idx)

    end
end

function veafSpawn.executeCommand(eventPos, eventText, coalition, markId, bypassSecurity, spawnedGroups, repeatCount, repeatDelay)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.executeCommand(eventText=[%s])", eventText))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("coalition=%s", veaf.p(coalition)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("markId=%s", veaf.p(markId)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("bypassSecurity=%s", veaf.p(bypassSecurity)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("repeatCount=%s", veaf.p(repeatCount)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("repeatDelay=%s", veaf.p(repeatDelay)))

    -- Check if marker has a text and the veafSpawn.SpawnKeyphrase keyphrase.
    if eventText ~= nil and (eventText:lower():find(veafSpawn.SpawnKeyphrase) or eventText:lower():find(veafSpawn.DestroyKeyphrase) or eventText:lower():find(veafSpawn.TeleportKeyphrase) or eventText:lower():find(veafSpawn.DrawingKeyphrase)) then
        
        -- Analyse the mark point text and extract the keywords.
        local options = veafSpawn.markTextAnalysis(eventText)

        if options then
            local repeatDelay = repeatDelay
            local repeatCount = repeatCount

            if options.repeatCount and not repeatCount then -- only use the parsed repeat options IF the parameter is not set (not during a repeat loop)
                -- set repeatCount and repeatDelay using the parsed options
                repeatCount = options.repeatCount
                repeatDelay = options.repeatDelay or veafSpawn.MIN_REPEAT_DELAY
                veaf.loggers.get(veafSpawn.Id):trace(string.format("using parsed repeat options to set repeatCount to %s and repeatDelay to %s", veaf.p(repeatCount), veaf.p(repeatDelay)))
            end

            if repeatCount and repeatCount > 0 then
                repeatDelay = repeatDelay
                if repeatDelay < veafSpawn.MIN_REPEAT_DELAY then
                    repeatDelay = veafSpawn.MIN_REPEAT_DELAY
                end
                repeatCount = repeatCount - 1 

                -- schedule the next step of the repeated command
                veaf.loggers.get(veafSpawn.Id):trace(string.format("scheduling veafSpawn.executeCommand for %s repeats in %s seconds", veaf.p(repeatCount), veaf.p(repeatDelay)))
                mist.scheduleFunction(veafSpawn.executeCommand, {eventPos, eventText, coalition, markId, bypassSecurity, spawnedGroups, repeatCount, repeatDelay}, timer.getTime() + repeatDelay)
            end

            if not(options.radius) then
                if options.farp or options.cargo or options.logistic or options.destroy or options.teleport or options.bomb or options.smoke or options.flare or options.signal then
                    options.radius = 0
                else
                    options.radius = 150
                end
            end

            for i=1,options.multiplier do
                local spawnedGroup = nil

                if not options.side then
                    if options.country then
                        -- deduct the side from the country
                        options.side = veaf.getCoalitionForCountry(options.country, true)
                    else
                        options.side = coalition
                    end
                end

                if not options.country then
                    -- deduct the country from the side
                    options.country = veaf.getCountryForCoalition(options.side)    
                end

                veaf.loggers.get(veafSpawn.Id):trace(string.format("options.side=%s",tostring(options.side)))
                veaf.loggers.get(veafSpawn.Id):trace(string.format("options.country=%s",tostring(options.country)))

                local routeDone = false

                -- Check options commands
                if options.unit then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    local code = options.laserCode
                    local channel = options.freq
                    local band = options.mod
                    if options.role == "tacan" then
                        channel = options.tacanChannel or 99
                        code = options.tacanCode or "T"..tostring(channel)
                        band = options.tacanBand or "X"
                    end
                    spawnedGroup = veafSpawn.spawnUnit(eventPos, options.radius, options.name, options.country, options.altitude, options.heading, options.unitName, options.role, code, channel, band, bypassSecurity)
                elseif options.farp then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    if not options.type then
                        options.type = "invisible"
                    end
                    spawnedGroup = veafSpawn.spawnFarp(eventPos, options.radius, options.name, options.country, options.type, options.side, options.heading, options.spacing, bypassSecurity)
                elseif options.cap then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnCombatAirPatrol(eventPos, options.radius, options.name, options.altitude, options.altdelta, options.heading, options.distance, options.speed, options.capradius, options.skill, bypassSecurity)
                elseif options.group then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnGroup(eventPos, options.radius, options.name, options.country, options.altitude, options.heading, options.spacing, bypassSecurity)
                elseif options.infantryGroup then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnInfantryGroup(eventPos, options.radius, options.country, options.side, options.heading, options.spacing, options.defense, options.armor, options.size, bypassSecurity)
                elseif options.armoredPlatoon then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnArmoredPlatoon(eventPos, options.radius, options.country, options.side, options.heading, options.spacing, options.defense, options.armor, options.size, bypassSecurity)
                elseif options.airDefenseBattery then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnAirDefenseBattery(eventPos, options.radius, options.country, options.side, options.heading, options.spacing, options.defense, bypassSecurity)
                elseif options.transportCompany then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnTransportCompany(eventPos, options.radius, options.country, options.side, options.heading, options.spacing, options.defense, options.size, bypassSecurity)
                elseif options.fullCombatGroup then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnFullCombatGroup(eventPos, options.radius, options.country, options.side, options.heading, options.spacing, options.defense, options.armor, options.size, bypassSecurity)
                elseif options.convoy then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnConvoy(eventPos, options.name, options.radius, options.country, options.side, options.speed, options.patrol, options.offroad, options.destination, options.defense, options.size, options.armor, bypassSecurity)
                    routeDone = true
                elseif options.cargo then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnCargo(eventPos, options.radius, options.cargoType, options.cargoSmoke, options.unitName, bypassSecurity)
                elseif options.logistic then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L9(options.password, markId)) then return end
                    spawnedGroup = veafSpawn.spawnLogistic(eventPos, options.radius, bypassSecurity)
                elseif options.destroy then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then return end
                    veafSpawn.destroy(eventPos, options.radius, options.unitName)
                elseif options.teleport then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then return end
                    veafSpawn.teleport(eventPos, options.radius, options.name, bypassSecurity)
                elseif options.bomb then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then return end
                    veafSpawn.spawnBomb(eventPos, options.radius, options.shells, options.bombPower, options.altitude, options.altitudedelta, options.password)
                elseif options.smoke then
                    veafSpawn.spawnSmoke(eventPos, options.smokeColor, options.radius, options.shells)
                elseif options.flare then
                    veafSpawn.spawnIlluminationFlare(eventPos, options.radius, options.shells, options.altitude)
                elseif options.signal then
                    veafSpawn.spawnSignalFlare(eventPos, options.radius, options.shells, options.smokeColor)
                elseif options.addDrawing then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then return end
                    veafSpawn.addPointToDrawing(eventPos, options.name, options.drawColor, options.drawFillColor, options.type, options.drawArrow)
                elseif options.eraseDrawing then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password, markId)) then return end
                    veafSpawn.eraseDrawing(options.name)
                end
                if spawnedGroup then
                    local groupObject = Group.getByName(spawnedGroup)
                    -- make the group combat ready !
                    veaf.readyForCombat(groupObject)
                    if not routeDone and options.destination then
                        --  make the group go to destination
                        local actualPosition = groupObject:getUnit(1):getPosition().p
                        local route = veaf.generateVehiclesRoute(actualPosition, options.destination, not options.offroad, options.speed, options.patrol)
                        mist.goRoute(groupObject, route)
                    end
                    -- add the group to the IADS, if there is one
                    if veafSkynet and options.skynet then -- only add static stuff like sam groups and sam batteries, not mobile groups and convoys
                        veafSkynet.addGroupToNetwork(groupObject)
                    end
                    -- reset the Hound Elint system, if the module is active
                    if veafHoundElint then
                        veafHoundElint.addPlatformToSystem(groupObject, nil, false)
                    end
                    if spawnedGroups then
                        table.insert(spawnedGroups, spawnedGroup)
                    end
                end
            end
            return true
        end
    end
    return false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the mark text and extract keywords.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSpawn.convertLaserToFreq(laser)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("convertLaserToFreq(laser=%s)", tostring(laser)))
    local laser = tonumber(laser)
    if laser and laser >= 1111 and laser <= 1688 then
        local laserB = math.floor((laser - 1000)/100)
        local laserCD = laser - 1000 - laserB*100
        local frequency = tostring(30+laserB+laserCD*0.05)
        veaf.loggers.get(veafSpawn.Id):trace(string.format("laserB=%s", tostring(laserB)))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("laserCD=%s", tostring(laserCD)))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("frequency=%s", tostring(frequency)))
        return frequency
    else 
        return nil
    end
end

--- Extract keywords from mark text.
function veafSpawn.markTextAnalysis(text)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("veafSpawn.markTextAnalysis(text=%s)", text))


    -- Option parameters extracted from the mark text.
    local options = {}
    options.unit = false
    options.group = false
    options.cap = false
    options.farp = false
    options.type = nil
    options.cargo = false
    options.logistic = false
    options.smoke = false
    options.flare = false
    options.signal = false
    options.bomb = false
    options.destroy = false
    options.teleport = false
    options.convoy = false
    options.role = nil
    options.laserCode = 1688
    options.infantryGroup = false
    options.armoredPlatoon = false
    options.airDefenseBattery = false
    options.transportCompany = false
    options.fullCombatGroup = false
    options.speed = nil
    options.capradius = nil
    options.shells = 1
    options.multiplier = 1
    options.skynet = false -- if true, add to skynet
    options.addtDrawing = false -- draw a polygon on the map
    options.eraseDrawing = false -- erase a polygon from the map
    options.stopDrawing = false -- close a polygon started on the map

    options.drawColor = nil
    options.drawFillColor = nil
    options.drawArrow = nil

    -- spawned group/unit type/alias
    options.name = ""

    -- spawned unit name
    options.unitName = nil

    -- spawned group units spacing
    options.spacing = 5
    
    options.country = nil
    options.side = nil
    options.altitude = 0
    options.altitudedelta = nil
    options.heading = 0
    options.distance = nil
    options.skill = nil

    -- if true, group is part of a road convoy
    options.isConvoy = false

    -- if true, group is patroling between its spawn point and its destination named point
    options.patrol = false

    -- if true, group is set to not follow roads
    options.offroad = false

    -- if set and convoy is true, send the group to the named point
    options.destination = nil

    -- the size of the generated dynamic groups (platoons, convoys, etc.)
    options.size = math.random(7) + 8

    -- defenses force ; ranges from 1 to 5, 5 being the toughest.
    options.defense = math.random(5)

    -- armor force ; ranges from 1 to 5, 5 being the strongest and most modern.
    options.armor = math.random(5)

    -- bomb power
    options.bombPower = 100

    -- smoke color
    options.smokeColor = trigger.smokeColor.Red

    -- optional cargo smoke
    options.cargoSmoke = false

    -- cargo type
    options.cargoType = "ammo_cargo"

    options.alt = nil
    options.altdelta = nil

    options.password = nil

    -- JTAC radio comms
    options.freq = veafSpawn.convertLaserToFreq(options.laserCode)
    options.mod = "fm"

    -- TACAN name and channel
    options.tacanChannel = 99
    options.tacanBand = "X"

    -- repeat options
    options.repeatCount = nil
    options.repeatDelay = nil

    -- Check for correct keywords.
    if text:lower():find(veafSpawn.SpawnKeyphrase .. " unit") then
        options.unit = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " cap") then
        options.cap = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " group") then
        options.group = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " farp") then
        options.farp = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " convoy") then
        options.convoy = true
        options.size = 10 -- default the size parameter to 10
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " infantrygroup") then
        options.infantryGroup = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " armorgroup") then
        options.armoredPlatoon = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " samgroup") then
        options.airDefenseBattery = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " transportgroup") then
        options.transportCompany = true
        options.size = math.random(2, 5)
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " combatgroup") then
        options.fullCombatGroup = true
        options.size = 1 -- default the size parameter to 1
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " smoke") then
        options.smoke = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " flare") then
        options.flare = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " signal") then
        options.signal = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " cargo") then
        options.cargo = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " logistic") then
        options.logistic = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " bomb") then
        options.bomb = true
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " jtac") then
        options.role = 'jtac'
        options.unit = true
        -- default country for friendly JTAC: USA
        options.country = "USA"
        -- default name for JTAC
        options.name = "LUV HMMWV Jeep"
        -- default JTAC name (will overwrite previous unit with same name)
        options.unitName = "JTAC1"
    elseif text:lower():find(veafSpawn.SpawnKeyphrase .. " tacan") then
        options.role = 'tacan'
        options.unit = true
        -- default country for friendly tacan: USA
        options.country = "USA"
        -- default name for tacan
        options.name = "TACAN_beacon"
        -- default name (will overwrite previous unit with same name)
        options.unitName = "TACAN TCN"
    elseif text:lower():find(veafSpawn.DestroyKeyphrase) then
        options.destroy = true
    elseif text:lower():find(veafSpawn.TeleportKeyphrase) then
        options.teleport = true
    elseif text:lower():find(veafSpawn.DrawingKeyphrase .. " add") then
        options.addDrawing = true
    elseif text:lower():find(veafSpawn.DrawingKeyphrase .. " erase") then
        options.eraseDrawing = true
    else
        return nil
    end

    -- keywords are split by ","
    local keywords = veaf.split(text, ",")

    for _, keyphrase in pairs(keywords) do
        -- Split keyphrase by space. First one is the key and second, ... the parameter(s) until the next comma.
        local str = veaf.breakString(veaf.trim(keyphrase), " ")
        local key = str[1]
        local val = str[2] or ""

        if key:lower() == "unitname" then
            -- Set name.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword unitname = %s", tostring(val)))
            options.unitName = val
        end

        if key:lower() == "name" then
            -- Set name.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword name = %s", tostring(val)))
            options.name = val
        end

        if (key:lower() == "destination" or key:lower() == "dest") then
            -- Set destination.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword destination = %s", tostring(val)))
            options.destination = val
        end

        if key:lower() == "isconvoy" then
            veaf.loggers.get(veafSpawn.Id):trace("Keyword isconvoy found")
            options.convoy = true
        end

        if key:lower() == "patrol" then
            veaf.loggers.get(veafSpawn.Id):trace("Keyword patrol found")
            options.patrol = true
        end

        if key:lower() == "offroad" then
            veaf.loggers.get(veafSpawn.Id):trace("Keyword offroad found")
            options.offroad = true
        end

        if key:lower() == "skynet" then
            -- Set name.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword skynet = %s", tostring(val)))
            options.skynet = (val:lower() == "true")
        end

        if key:lower() == "radius" then
            -- Set name.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword radius = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.radius = nVal
        end

        if key:lower() == "spacing" then
            -- Set spacing.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword spacing = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.spacing = nVal
        end
        
        if key:lower() == "multiplier" then
            -- Set multiplier.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword multiplier = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.multiplier = nVal
        end

        if key:lower() == "alt" then
            -- Set altitude.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword alt = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.altitude = nVal
        end
        
        if key:lower() == "altdelta" then
            -- Set altitude delta.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword altdelta = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.altitudedelta = nVal
        end

        if key:lower() == "speed" then
            -- Set speed.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword speed = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.speed = nVal
        end
        
        if key:lower() == "capradius" then
            -- Set capradius.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword capradius = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.capradius = nVal
        end

        if key:lower() == "shells" then
            -- Set altitude.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword shells = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.shells = nVal
        end

        if key:lower() == "hdg" then
            -- Set heading.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword hdg = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.heading = nVal
        end
        
        if key:lower() == "heading" then
            -- Set heading.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword heading = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.heading = nVal
        end

        if key:lower() == "country" then
            -- Set country
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword country = %s", tostring(val)))
            options.country = val:upper()
        end
        
        if key:lower() == "side" then
            -- Set side
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword side = %s", tostring(val)))
            if val:upper() == "BLUE" then
                options.side = veafCasMission.SIDE_BLUE
            else
                options.side = veafCasMission.SIDE_RED
            end
        end

        if key:lower() == "password" then
            -- Unlock the command
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword password", tostring(val)))
            options.password = val
        end

        if key:lower() == "power" then
            -- Set bomb power.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword power = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.bombPower = nVal
        end
        
        if key:lower() == "laser" then
            -- Set laser code.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("laser code = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.freq = veafSpawn.convertLaserToFreq(nVal)
            options.laserCode = nVal
        end        
        
        if key:lower() == "freq" then
            -- Set JTAC frequency.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("freq = %s", tostring(val)))
            options.freq = val
        end        

        if key:lower() == "mod" then
            -- Set JTAC modulation.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("mod = %s", tostring(val)))
            options.mod = val
        end        

        if key:lower() == "band" then
            -- Set TACAN band
            veaf.loggers.get(veafSpawn.Id):trace(string.format("band = %s", tostring(val)))
            options.tacanBand = val
        end        

        if key:lower() == "code" then
            -- Set TACAN code
            veaf.loggers.get(veafSpawn.Id):trace(string.format("code = %s", tostring(val)))
            options.tacanCode = val
        end        

        if key:lower() == "channel" then
            -- Set TACAN channel.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("channel = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.tacanChannel = nVal
        end        

        if key:lower() == "arrow" then
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword arrow = %s", tostring(val)))
            options.drawArrow = true
        end
        if key:lower() == "fill" then
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword fill = %s", tostring(val)))
            options.drawFillColor = val
        end

        if key:lower() == "color" then
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword color = %s", tostring(val)))
            options.drawColor = val
            -- Set smoke color.
            if (val:lower() == "red") then 
                options.smokeColor = trigger.smokeColor.Red
            elseif (val:lower() == "green") then 
                options.smokeColor = trigger.smokeColor.Green
            elseif (val:lower() == "orange") then 
                options.smokeColor = trigger.smokeColor.Orange
            elseif (val:lower() == "blue") then 
                options.smokeColor = trigger.smokeColor.Blue
            elseif (val:lower() == "white") then 
                options.smokeColor = trigger.smokeColor.White
            end
        end

        if key:lower() == "skill" then
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword skill = %s", tostring(val)))
            options.skill = val
        end

        if key:lower() == "dist" or key:lower() == "distance" then
            -- Set distance.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword distance = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.distance = nVal
        end

        if key:lower() == "alt" then
            -- Set alt.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword alt = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.alt = nVal
        end

        if key:lower() == "altdelta" then
            -- Set altitude delta.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword altdelta = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.altdelta = nVal
        end

        if options.cargo and key:lower() == "name" then
            -- Set cargo type.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword name = %s", tostring(val)))
            options.cargoType = val
        end

        if key:lower() == "type" then
            -- Set farp type.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword type = %s", tostring(val)))
            options.type = val
        end

        if options.cargo and key:lower() == "smoke" then
            -- Mark with green smoke.
            veaf.loggers.get(veafSpawn.Id):trace("Keyword smoke is set")
            options.cargoSmoke = true
        end
        
        if key:lower() == "size" then
            -- Set size.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword size = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.size = nVal
        end

        if key:lower() == "defense" then
            -- Set defense.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword defense = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            if nVal >= 0 then
                options.defense = nVal
            end
        end

        if key:lower() == "armor" then
            -- Set armor.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword armor = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            if nVal >= 0 then
                options.armor = nVal
            end
        end

        if key:lower() == "repeat" then
            -- Set repeat count.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword repeat = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.repeatCount = nVal
        end

        if key:lower() == "delay" then
            -- Set delay.
            veaf.loggers.get(veafSpawn.Id):trace(string.format("Keyword delay = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            options.repeatDelay = nVal
        end

    end

    -- check mandatory parameter "name" for command "group"
    if options.group and not(options.name) then return nil end
    
    -- check mandatory parameter "name" for command "unit"
    if options.unit and not(options.name) then return nil end
    
    return options
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Manage drawings on the map
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSpawn.drawings = {}
veafSpawn.drawingsMarkers = {}

--- Add a point to a drawing on the map (or start a new drawing)
function veafSpawn.addPointToDrawing(point, name, color, fillColor, lineType, isArrow)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("addPointToDrawing(point=%s, name=%s, color=%s, fillColor=%s, lineType=%s, isArrow=%s)", veaf.p(point), veaf.p(name), veaf.p(color), veaf.p(fillColor), veaf.p(lineType), veaf.p(isArrow)))
    if not name then 
        veaf.loggers.get(veafSpawn.Id):warn("Name is mandatory for drawing commands")
        return
    end
    local drawing = veafSpawn.drawings[name:lower()]
    if not drawing then 
        drawing = VeafDrawingOnMap.new():setName(name)
        veafSpawn.drawings[name:lower()] = drawing
    end
    local drawingMarkerId = veafSpawn.drawingsMarkers[name:lower()]
    if drawingMarkerId then
        trigger.action.removeMark(drawingMarkerId)
    end
    drawingMarkerId = veaf.getUniqueIdentifier()
    trigger.action.markToAll(drawingMarkerId, name, point, true) 
    veafSpawn.drawingsMarkers[name:lower()] = drawingMarkerId
    if color then
        drawing:setColor(color)
    end
    if lineType then
        drawing:setLineType(lineType)
    end
    if isArrow then
        drawing:setArrow()
    end
    if fillColor then
        drawing:setFillColor(fillColor)
    end
    
    drawing:addPoint(point)
    drawing:draw()
end

--- Erase drawing from the map
function veafSpawn.eraseDrawing(name)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("eraseDrawing(name=%s)",veaf.p(name)))
    if not name then 
        veaf.loggers.get(veafSpawn.Id):warn("Name is mandatory for drawing commands")
        return
    end
    local drawing = veafSpawn.drawings[name:lower()]
    if not drawing then 
        local message = string.format("Could not find a drawing named %s", veaf.p(name))
        veaf.loggers.getSpawn(veaf.Id):warn(message)
        trigger.action.outText(message)
        return
    end
    drawing:erase()
    veafSpawn.drawings[name:lower()] = nil
    local drawingMarkerId = veafSpawn.drawingsMarkers[name:lower()]
    if drawingMarkerId then
        trigger.action.removeMark(drawingMarkerId)
    end
    veafSpawn.drawingsMarkers[name:lower()] = nil
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Group spawn command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Spawn a specific group at a specific spot
function veafSpawn.doSpawnGroup(spawnSpot, radius, groupDefinition, country, alt, hdg, spacing, groupName, silent, shuffle)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("doSpawnGroup(country=%s, alt=%s, hdg=%s, spacing=%s, groupName=%s)", tostring(country), tostring(alt), tostring(hdg), tostring(spacing), tostring(groupName)))
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))

    veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1

    if type(groupDefinition) == "string" then
        local name = groupDefinition
        -- find the desired group in the groups database
        groupDefinition = veafUnits.findGroup(name)
        if not(groupDefinition) then
            veaf.loggers.get(veafSpawn.Id):info("cannot find group "..name)
            if not(silent) then
                trigger.action.outText("cannot find group "..name, 5) 
            end
            return    
        end
    end

    veaf.loggers.get(veafSpawn.Id):trace("doSpawnGroup: groupDefinition.description=" .. groupDefinition.description)

    local units = {}

    -- place group units on the map
    local group, cells = veafUnits.placeGroup(groupDefinition, spawnSpot, spacing, hdg)
    veafUnits.traceGroup(group, cells)
    
    if not(groupName) then 
        groupName = group.groupName .. " #" .. veafSpawn.spawnedUnitsCounter
    end

    for i=1, #group.units do
        local unit = group.units[i]
        local unitType = unit.typeName
        local unitName = groupName .. " / " .. unit.displayName .. " #" .. i
        
        local spawnPoint = unit.spawnPoint
        if alt > 0 then
            spawnPoint.y = alt
        end
        
        -- check if position is correct for the unit type
        if not veafUnits.checkPositionForUnit(spawnPoint, unit) then
            veaf.loggers.get(veafSpawn.Id):info("cannot find a suitable position for spawning unit ".. unitType)
            if not(silent) then
                trigger.action.outText("cannot find a suitable position for spawning unit "..unitType, 5)
            end
        else 
            local toInsert = {
                    ["x"] = spawnPoint.x,
                    ["y"] = spawnPoint.z,
                    ["alt"] = spawnPoint.y,
                    ["type"] = unitType,
                    ["name"] = unitName,
                    ["speed"] = 0,  -- speed in m/s
                    ["skill"] = "Random",
                    ["heading"] = spawnPoint.hdg
            }
            
            veaf.loggers.get(veafSpawn.Id):trace(string.format("toInsert x=%.1f y=%.1f, alt=%.1f, type=%s, name=%s, speed=%d, heading=%d, skill=%s, country=%s", toInsert.x, toInsert.y, toInsert.alt, toInsert.type, toInsert.name, toInsert.speed, mist.utils.toDegree(toInsert.heading), toInsert.skill, country ))
            table.insert(units, toInsert)
        end
    end

    -- shuffle the group if needed (useful for randomizing convoys)
    if shuffle then
        units = veaf.shuffle(units)
    end

    -- actually spawn the group
    if group.naval then
        mist.dynAdd({country = country, category = "SHIP", name = groupName, hidden = false, units = units})
    elseif group.air then
        mist.dynAdd({country = country, category = "AIRPLANE", name = groupName, hidden = false, units = units})
    else
        mist.dynAdd({country = country, category = "GROUND_UNIT", name = groupName, hidden = false, units = units})
    end

    if not(silent) then
        -- message the group spawning
        trigger.action.outText("A " .. group.description .. "("..country..") has been spawned", 5)
    end

    return groupName
end

--- Spawn a FARP
function veafSpawn.spawnFarp(spawnSpot, radius, name, country, farptype, side, hdg, spacing, silent)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnFarp(name=%s, country=%s, farptype=%s, side=%s, hdg=%s, spacing=%s)",veaf.p(name), veaf.p(country), veaf.p(farptype), veaf.p(side), veaf.p(hdg), veaf.p(spacing)))
    
    local radius = radius or 0
    local name = name
    local hdg = hdg or 0
    local side = side or 1
    local spacing = spacing or 50
    local silent = silent or false
    local country = country or "usa"
    local farptype = farptype or ""

    local spawnPosition = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnPosition=%s", veaf.p(spawnPosition)))
    if not name or name == "" then 
        local _lat, _lon = coord.LOtoLL(spawnSpot)
        veaf.loggers.get(veafSpawn.Id):trace(string.format("_lat=%s", veaf.p(_lat)))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("_lon=%s", veaf.p(_lon)))
        local _mgrs = coord.LLtoMGRS(_lat, _lon)
        veaf.loggers.get(veafSpawn.Id):trace(string.format("_mgrs=%s", veaf.p(_mgrs)))
        --local _UTM = _mgrs.UTMZone .. _mgrs.MGRSDigraph .. math.floor(_mgrs.Easting / 1000) .. math.floor(_mgrs.Northing / 1000)
        local _UTM = _mgrs.MGRSDigraph .. math.floor(_mgrs.Easting / 1000) .. math.floor(_mgrs.Northing / 1000)
        name = "FARP ".. _UTM:upper()
    end 

    local _type = "Invisible FARP"
    local _shape = "invisiblefarp"
    if farptype:lower() == "quad" then
        _type = "FARP"
        _shape = "FARPs"
    elseif farptype:lower() == "single" then
        _type = "FARP"
        _shape = "FARP"
    end

    -- spawn the FARP
    local _farpStatic = {
        ["category"] = "Heliports",
        ["shape_name"] = _shape,
        ["type"] = _type,
      --  ["unitId"] = _unitId,
        ["y"] = spawnPosition.z,
        ["x"] = spawnPosition.x,
        ["groupName"] = name,
        ["name"] = name,
        ["canCargo"] = false,
        ["heading"] = hdg,
        ["country"] = country,
        ["coalition"] = side
    }
    mist.dynAddStatic(_farpStatic)
    local _spawnedFARP = StaticObject.getByName(name)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("_spawnedFARP=%s", veaf.p(_spawnedFARP)))

    if _spawnedFARP then
        veaf.loggers.get(veafSpawn.Id):debug(string.format("Spawned the FARP static %s", veaf.p(name)))

        -- populate the FARP
        veafGrass.buildFarpUnits(_farpStatic, nil, name)
    end

    return name
end

--- Spawn a specific group at a specific spot
function veafSpawn.spawnGroup(spawnSpot, radius, name, country, alt, hdg, spacing, silent)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnGroup(name = %s, country=%s, alt=%d, hdg=%d, spacing=%d)",name, country, alt, hdg, spacing))
    
    local spawnedGroupName = veafSpawn.doSpawnGroup(spawnSpot, radius, name, country, alt, hdg, spacing, nil, silent)

    return spawnedGroupName
end

function veafSpawn._createDcsUnits(country, units, groupName)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn._createDcsUnits([%s])",country or ""))
    local dcsUnits = {}
    for i=1, #units do
        local unit = units[i]
        local unitType = unit.typeName
        local unitName = groupName .. " / " .. unit.displayName .. " #" .. i
        local hdg = unit.heading or math.random(0, 359)
        local spawnPosition = unit.spawnPoint
        
        -- check if position is correct for the unit type
        if veafUnits.checkPositionForUnit(spawnPosition, unit) then
            local toInsert = {
                    ["x"] = spawnPosition.x,
                    ["y"] = spawnPosition.z,
                    ["alt"] = spawnPosition.y,
                    ["type"] = unitType,
                    ["name"] = unitName,
                    ["speed"] = 0,
                    ["skill"] = "Excellent",
                    ["heading"] = hdg
            }

            veaf.loggers.get(veafSpawn.Id):trace(string.format("toInsert x=%.1f y=%.1f, alt=%.1f, type=%s, name=%s, speed=%d, heading=%d, skill=%s, country=%s", toInsert.x, toInsert.y, toInsert.alt, toInsert.type, toInsert.name, toInsert.speed, toInsert.heading, toInsert.skill, country ))
            table.insert(dcsUnits, toInsert)
        end
    end

    -- actually spawn groups
    mist.dynAdd({country = country, category = "GROUND_UNIT", name = groupName, hidden = false, units = dcsUnits})

    -- set AI options
    local controller = Group.getByName(groupName):getController()
    controller:setOption(AI.Option.Ground.id.ENGAGE_AIR_WEAPONS, true) -- engage air-to-ground weapons with SAMs
    controller:setOption(AI.Option.Air.id.ROE, 2) -- set fire at will
    controller:setOption(AI.Option.Ground.id.ROE, 2) -- set fire at will
    controller:setOption(AI.Option.Naval.id.ROE, 2) -- set fire at will
    controller:setOption(AI.Option.Ground.id.ALARM_STATE, 2) -- set alarm state to red
    controller:setOption(AI.Option.Ground.id.DISPERSE_ON_ATTACK, 1) -- set disperse on attack according to the option
end

--- Spawns a dynamic infantry group 
function veafSpawn.spawnInfantryGroup(spawnSpot, radius, country, side, heading, spacing, defense, armor, size, silent)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnInfantryGroup(country=%s, side=%s, heading=%s, spacing=%s, defense=%s, armor=%s, size=%s)", veaf.p(country), veaf.p(side), veaf.p(heading), veaf.p(spacing), veaf.p(defense), veaf.p(armor), veaf.p(size)))
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))

    local groupName = "spawn-" .. math.random(99999) .. " - Infantry Section "
    local group = veafCasMission.generateInfantryGroup(groupName, defense, armor, side, size)
    local group = veafUnits.processGroup(group)
    local groupPosition = veaf.placePointOnLand(spawnSpot)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("groupPosition = %s",veaf.vecToString(groupPosition)))
    local group, cells = veafUnits.placeGroup(group, groupPosition, spacing, heading)

    -- shuffle the units in the group
    units = veaf.shuffle(group.units)

    veafSpawn._createDcsUnits(country, group.units, groupName)
 
    if not silent then 
        trigger.action.outText("Spawned dynamic infantry group "..groupName, 5)
    end

    return groupName
end

--- Spawns a dynamic armored platoon
function veafSpawn.spawnArmoredPlatoon(spawnSpot, radius, country, side, heading, spacing, defense, armor, size, silent)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnArmoredPlatoon(country=%s, side=%s, heading=%s, spacing=%s, defense=%s, armor=%s, size=%s)", veaf.p(country), veaf.p(side), veaf.p(heading), veaf.p(spacing), veaf.p(defense), veaf.p(armor), veaf.p(size)))
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))

    local groupName = "spawn-" .. math.random(99999) .. " - Armored Platoon "
    local group = veafCasMission.generateArmorPlatoon(groupName, defense, armor, side, size)
    local group = veafUnits.processGroup(group)
    local groupPosition = veaf.placePointOnLand(spawnSpot)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("groupPosition = %s",veaf.vecToString(groupPosition)))
    local group, cells = veafUnits.placeGroup(group, groupPosition, spacing, heading)

    -- shuffle the units in the group
    units = veaf.shuffle(group.units)

    veafSpawn._createDcsUnits(country, group.units, groupName)
 
    if not silent then 
        trigger.action.outText("Spawned dynamic armored platoon "..groupName, 5)
    end

    return groupName
end

--- Spawns a dynamic air defense battery
function veafSpawn.spawnAirDefenseBattery(spawnSpot, radius, country, side, heading, spacing, defense, silent)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnAirDefenseBattery(country=%s, side=%s, heading=%s, spacing=%s, defense=%s)", veaf.p(country), veaf.p(side), veaf.p(heading), veaf.p(spacing), veaf.p(defense)))

    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))

    local groupName = "spawn-" .. math.random(99999) .. " - Air Defense Battery "
    local group = veafCasMission.generateAirDefenseGroup(groupName, defense, side)
    local group = veafUnits.processGroup(group)
    local groupPosition = veaf.placePointOnLand(spawnSpot)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("groupPosition = %s",veaf.vecToString(groupPosition)))
    local group, cells = veafUnits.placeGroup(group, groupPosition, spacing, heading)

    -- shuffle the units in the group
    units = veaf.shuffle(group.units)

    veafSpawn._createDcsUnits(country or veaf.getCountryForCoalition(side), group.units, groupName)
 
    if not silent then 
        trigger.action.outText("Spawned dynamic air defense battery "..groupName, 5)
    end

    return groupName
end

--- Spawns a dynamic transport company
function veafSpawn.spawnTransportCompany(spawnSpot, radius, country, side, heading, spacing, defense, size, silent)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnTransportCompany(country=%s, side=%s, heading=%s, spacing=%s, defense=%s, size=%s)", veaf.p(country), veaf.p(side), veaf.p(heading), veaf.p(spacing), veaf.p(defense), veaf.p(size)))
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))

    local groupName = "spawn-" .. math.random(99999) .. " - Transport Company "
    local group = veafCasMission.generateTransportCompany(groupName, defense, side, size)
    local group = veafUnits.processGroup(group)
    local groupPosition = veaf.placePointOnLand(spawnSpot)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("groupPosition = %s",veaf.vecToString(groupPosition)))
    local group, cells = veafUnits.placeGroup(group, groupPosition, spacing, heading)

    -- shuffle the units in the group
    units = veaf.shuffle(group.units)

    veafSpawn._createDcsUnits(country, group.units, groupName)
 
    if not silent then 
        trigger.action.outText("Spawned dynamic transport company "..groupName, 5)
    end

    return groupName
end

--- Spawns a dynamic full combat group composed of multiple platoons
function veafSpawn.spawnFullCombatGroup(spawnSpot, radius, country, side, heading, spacing, defense, armor, size, silent)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnFullCombatGroup(country=%s, side=%s, heading=%s, spacing=%s, defense=%s, armor=%s, size=%s)", veaf.p(country), veaf.p(side), veaf.p(heading), veaf.p(spacing), veaf.p(defense), veaf.p(armor), veaf.p(size)))
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))

    local groupName = "spawn-" .. math.random(99999) .. " - Full Combat Group "
    local groupPosition = veaf.placePointOnLand(spawnSpot)
    local units = veafCasMission.generateCasGroup(country, groupName, groupPosition, size, defense, armor, spacing, true, side)

    veafSpawn._createDcsUnits(country, units, groupName)
 
    if not silent then 
        trigger.action.outText("Spawned full combat group "..groupName, 5)
    end

    return groupName
end

--- Spawn a specific group at a specific spot
function veafSpawn.spawnConvoy(spawnSpot, name, radius, country, side, speed, patrol, offroad, destination, defense, size, armor, silent)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnConvoy(spawnSpot=[%s], name=[%s], radius=[%s], country=[%s], side=[%s], speed=[%s], patrol=[%s], offroad=[%s], destination=[%s], defense=[%s], size=[%s], armor=[%s], silent=[%s])", veaf.p(spawnSpot), veaf.p(name), veaf.p(radius), veaf.p(country), veaf.p(side), veaf.p(speed), veaf.p(patrol), veaf.p(offroad), veaf.p(destination), veaf.p(defense), veaf.p(size), veaf.p(armor), veaf.p(silent)))
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))

    -- check that destination exists
    local point = nil
    if destination then
        point = veafNamedPoints.getPoint(destination)
    end
    if not(point) then
        local _lat, _lon = veaf.computeLLFromString(destination)
        veaf.loggers.get(veafSpawn.Id):trace(string.format("_lat=%s",veaf.p(_lat)))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("_lon=%s",veaf.p(_lon)))
        if _lat and _lon then 
            point = coord.LLtoLO(_lat, _lon)
            veaf.loggers.get(veafSpawn.Id):trace(string.format("point=%s",veaf.p(point)))
        end
    end
    if not(point) then
        trigger.action.outText("A point named "..destination.." cannot be found, and these are not valid coordinates !", 5)
        return false
    end

    local units = {}
    local groupId = math.random(99999)
    local groupName = name
    if not groupName or groupName == "" then
        groupName = "convoy-" .. groupId
    end

    
    -- generate the transport vehicles and air defense
    if size and size > 0 then -- this is only for reading clarity sake
        -- generate the group
        local group = veafCasMission.generateTransportCompany(groupId, defense, side, size)

        -- process the group 
        local group = veafUnits.processGroup(group)
        
        -- place its units
        local group, cells = veafUnits.placeGroup(group, veaf.placePointOnLand(spawnSpot), 4, math.random(359))
        veafUnits.traceGroup(group, cells)
        
        -- add the units to the global units list
        for _,u in pairs(group.units) do
            table.insert(units, u)
        end
    end

    -- generate the armored vehicles
    if armor and armor > 0 then
        -- generate the group
        local group = veafCasMission.generateArmorPlatoon(groupId, defense, armor, side, size / 2)
        
        -- process the group 
        local group = veafUnits.processGroup(group)
        
        -- place its units
        local group, cells = veafUnits.placeGroup(group, veaf.placePointOnLand(spawnSpot), 4, math.random(359))
        
        -- add the units to the global units list
        for _,u in pairs(group.units) do
            table.insert(units, u)
        end
    end

    -- shuffle the units in the convoy
    units = veaf.shuffle(units)

    veafSpawn._createDcsUnits(country, units, groupName)
 
    local route = veaf.generateVehiclesRoute(spawnSpot, destination, not offroad, speed, patrol)
    veafSpawn.spawnedConvoys[groupName] = {route=route, name=groupName}

    --  make the group go to destination
    veaf.loggers.get(veafSpawn.Id):trace("make the group go to destination : ".. groupName)
    mist.goRoute(groupName, route)

    if not silent then 
        trigger.action.outText("Spawned convoy "..groupName, 5)
    end

    return groupName
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Unit spawn command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Spawn a specific unit at a specific spot
-- @param position spawnPosition
-- @param string name
-- @param string country
-- @param int speed
-- @param int alt
-- @param int speed
-- @param int hdg (0..359)
-- @param string unitName (callsign)
-- @param string role (ex: jtac)
function veafSpawn.spawnUnit(spawnPosition, radius, name, country, alt, hdg, unitName, role, code, freq, mod, silent)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnUnit(name = %s, country=%s, alt=%d, hdg= %d)", veaf.p(name), veaf.p(country), veaf.p(alt), veaf.p(hdg)))
    
    veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1

    -- find the desired unit in the groups database
    local unit = veafUnits.findUnit(name)
    
    if not(unit) then
        veaf.loggers.get(veafSpawn.Id):info("cannot find unit "..name)
        trigger.action.outText("cannot find unit "..name, 5)
        return    
    end
  
    -- cannot spawn planes or helos yet [TODO]
    if unit.air then
        veaf.loggers.get(veafSpawn.Id):info("Air units cannot be spawned at the moment (work in progress)")
        trigger.action.outText("Air units cannot be spawned at the moment (work in progress)", 5)
        return    
    end
    
    local units = {}
    local groupName = nil
    
    veaf.loggers.get(veafSpawn.Id):trace("spawnUnit unit = " .. unit.displayName .. ", dcsUnit = " .. tostring(unit.typeName))
    
    if role == "jtac" then
        local name = "JTAC " .. tostring(code):sub(1,1) .. " " .. tostring(code):sub(2,2) .. " " .. tostring(code):sub(3,3) .. " " .. tostring(code):sub(4,4)
        veaf.loggers.get(veafSpawn.Id):trace(string.format("name=%s", tostring(name)))
        groupName = name
        unitName = name
    elseif role == "tacan" then
        local name = "TACAN " .. tostring(freq)..tostring(mod)
        veaf.loggers.get(veafSpawn.Id):trace(string.format("name=%s", tostring(name)))
        groupName = name
        unitName = name
    else
      groupName = veafSpawn.RedSpawnedUnitsGroupName .. " #" .. veafSpawn.spawnedUnitsCounter
      if not unitName then
        unitName = unit.displayName .. " #" .. veafSpawn.spawnedUnitsCounter
      end
    end
    
    veaf.loggers.get(veafSpawn.Id):trace("groupName="..groupName)
    veaf.loggers.get(veafSpawn.Id):trace("unitName="..unitName)

    local spawnSpot = nil
    local nbTries = 25
    repeat
        spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnPosition, radius))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnUnit: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))   
        if alt > 0 then
            spawnSpot.y = alt
        end
        if not veafUnits.checkPositionForUnit(spawnSpot, unit) then
            veaf.loggers.get(veafSpawn.Id):debug("finding another spawnSpot for unit %s, remaining tries #%s", unit.displayName, nbTries)
            spawnSpot = nil
            nbTries = nbTries - 1
        end
    until spawnSpot or nbTries <= 0

    if not spawnSpot then
        veaf.loggers.get(veafSpawn.Id):info("cannot find a suitable position for spawning unit "..unit.displayName)
        trigger.action.outText("cannot find a suitable position for spawning unit "..unit.displayName, 5)
        return
    else 
        local toInsert = {
                ["x"] = spawnSpot.x,
                ["y"] = spawnSpot.z,
                ["alt"] = spawnSpot.y,
                ["type"] = unit.typeName,
                ["name"] = unitName,
                ["speed"] = 0,
                ["skill"] = "Random",
                ["heading"] = mist.utils.toRadian(hdg),
        }

        veaf.loggers.get(veafSpawn.Id):trace(string.format("toInsert x=%.1f y=%.1f, alt=%.1f, type=%s, name=%s, speed=%d, skill=%s, country=%s", toInsert.x, toInsert.y, toInsert.alt, toInsert.type, toInsert.name, toInsert.speed, toInsert.skill, country ))
        table.insert(units, toInsert)       
    end

    -- actually spawn the unit
    if unit.naval then
        veaf.loggers.get(veafSpawn.Id):trace("Spawning SHIP")
        mist.dynAdd({country = country, category = "SHIP", name = groupName, units = units})
    elseif unit.air then
        veaf.loggers.get(veafSpawn.Id):trace("Spawning AIRPLANE")
        mist.dynAdd({country = country, category = "PLANE", name = groupName, units = units})
    else
        veaf.loggers.get(veafSpawn.Id):trace("Spawning GROUND_UNIT")
        mist.dynAdd({country = country, category = "GROUND_UNIT", name = groupName, units = units})
    end

    if role == "jtac" then
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

        local spawnedGroup = Group.getByName(groupName)
        local controller = spawnedGroup:getController()
        Controller.setCommand(controller, _setImmortal)
        Controller.setCommand(controller, _setInvisible)

        -- start lasing 
        if ctld then 
            ctld.cleanupJTAC(groupName)
            local radioData = {freq=freq, mod=mod, name=groupName}
            veafSpawn.JTACAutoLase(groupName, code, radioData)
        end

    elseif role == "tacan" then
        veaf.loggers.get(veafSpawn.Id):trace(string.format("name=%s", tostring(name)))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("freq=%s", tostring(freq)))
        local mod = string.upper(mod) or "X"
        veaf.loggers.get(veafSpawn.Id):trace(string.format("mod=%s", tostring(mod)))
        local txFreq = (1025 + freq - 1) * 1000000
        local rxFreq = (962 + freq - 1) * 1000000
        if (freq < 64 and mod == "Y") or (freq >= 64 and mod == "X") then
            rxFreq = (1088 + freq - 1) * 1000000
        end
        veaf.loggers.get(veafSpawn.Id):trace(string.format("txFreq=%s", tostring(txFreq)))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("rxFreq=%s", tostring(rxFreq)))

        local command = { 
            id = 'ActivateBeacon', 
            params = { 
                type = 4,
                system = 18, 
                callsign = code or "TCN", 
                frequency = rxFreq,
                AA = false,
                channel = freq,
                bearing = true,
                modeChannel = mod,
            }
        }
                
        veaf.loggers.get(veafSpawn.Id):trace(string.format("setting %s", veaf.p(command)))
        local spawnedGroup = Group.getByName(groupName)
        local controller = spawnedGroup:getController()
        controller:setCommand(command)
        veaf.loggers.get(veafSpawn.Id):trace(string.format("done setting command"))
    end

    -- message the unit spawning
    veaf.loggers.get(veafSpawn.Id):trace(string.format("message the unit spawning"))
    if (role == "jtac") or not silent then 
        local message = "A " .. unit.displayName .. "("..country..") has been spawned"
        if role == "jtac" then
            message = "JTAC spawned, lasing on "..code..", available on "..freq.." "..mod
        end
        veaf.loggers.get(veafSpawn.Id):trace(message)
        trigger.action.outText(message, 15)
    end

    return groupName
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Cargo spawn command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Spawn a specific cargo at a specific spot
function veafSpawn.spawnCargo(spawnSpot, radius, cargoType, cargoSmoke, unitName, silent)
    veaf.loggers.get(veafSpawn.Id):debug("spawnCargo(cargoType = " .. cargoType ..")")
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnCargo: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))

    return veafSpawn.doSpawnCargo(spawnSpot, radius, cargoType, unitName, cargoSmoke, silent)
end

--- Spawn a logistic unit for CTLD at a specific spot
function veafSpawn.spawnLogistic(spawnSpot, radius, silent)
    veaf.loggers.get(veafSpawn.Id):debug("spawnLogistic()")
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnLogistic: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))

    local unitName = veafSpawn.doSpawnStatic(spawnSpot, radius, veafSpawn.LogisticUnitCategory, veafSpawn.LogisticUnitType, nil, false, true)
    
    veaf.loggers.get(veafSpawn.Id):debug(string.format("spawnLogistic: inserting %s into CTLD logistics list", unitName))
    if ctld then 
        table.insert(ctld.logisticUnits, unitName)
    end

    -- message the unit spawning
    if not silent then 
        local message = "Logistic unit " .. unitName .. " has been spawned and was added to CTLD."
        trigger.action.outText(message, 5)
    end
    
end

--- Spawn a specific cargo at a specific spot
function veafSpawn.doSpawnCargo(spawnSpot, radius, cargoType, unitName, cargoSmoke, silent)
    veaf.loggers.get(veafSpawn.Id):debug("spawnCargo(cargoType = " .. cargoType ..")")
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnCargo: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))

    local units = {}

    local spawnPosition = veaf.findPointInZone(spawnSpot, 50, false)

    -- check spawned position validity
    if spawnPosition == nil then
        veaf.loggers.get(veafSpawn.Id):info("cannot find a suitable position for spawning cargo "..cargoType)
        if not(silent) then trigger.action.outText("cannot find a suitable position for spawning cargo "..cargoType, 5) end
        return
    end

    veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnCargo: spawnPosition  x=%.1f y=%.1f", spawnPosition.x, spawnPosition.y))
  
    -- compute cargo weight
    local cargoWeight = 250
    local unit = veafUnits.findDcsUnit(cargoType)
    if not unit then
        cargoType = cargoType.. "_cargo"
        unit = veafUnits.findDcsUnit(cargoType)
    end
    if unit then
        if unit.desc and unit.desc.minMass and unit.desc.maxMass then
            cargoWeight = math.random(unit.desc.minMass, unit.desc.maxMass)
        elseif unit.defaultMass then
            cargoWeight = unit.defaultMass
            cargoWeight = math.random(cargoWeight - cargoWeight / 2, cargoWeight + cargoWeight / 2)
        end
        if cargoWeight then

            if not(unitName) then
                veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1
                unitName = unit.name .. " #" .. veafSpawn.spawnedUnitsCounter
            end

            -- create the cargo
            local cargoTable = {
                type = cargoType,
                country = 'USA',
                category = 'Cargos',
                name = unitName,
                x = spawnPosition.x,
                y = spawnPosition.y,
                canCargo = true,
                mass = cargoWeight
            }
            
            mist.dynAddStatic(cargoTable)
            
            -- smoke the cargo if needed
            if cargoSmoke then 
                local smokePosition={x=spawnPosition.x + mist.random(10,20), y=0, z=spawnPosition.y + mist.random(10,20)}
                local height = veaf.getLandHeight(smokePosition)
                smokePosition.y = height
                veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnCargo: smokePosition  x=%.1f y=%.1f z=%.1f", smokePosition.x, smokePosition.y, smokePosition.z))
                veafSpawn.spawnSmoke(smokePosition, trigger.smokeColor.Green)
                for i = 1, 10 do
                    veaf.loggers.get(veafSpawn.Id):trace("Signal flare 1 at " .. timer.getTime() + i*7)
                    mist.scheduleFunction(veafSpawn.spawnSignalFlare, {smokePosition, nil, nil, trigger.flareColor.Red}, timer.getTime() + i*3)
                end
            end

            -- message the unit spawning
            local message = "Cargo " .. unitName .. " weighting " .. cargoWeight .. " kg has been spawned"
            if cargoSmoke then 
                message = message .. ". It's marked with green smoke and red flares"
            end
            if not(silent) then trigger.action.outText(message, 5) end
        end
    end
    return unitName
end


--- Spawn a specific static at a specific spot
function veafSpawn.doSpawnStatic(spawnSpot, radius, staticCategory, staticType, unitName, smoke, silent)
    veaf.loggers.get(veafSpawn.Id):debug("doSpawnStatic(staticCategory = " .. staticCategory ..")")
    veaf.loggers.get(veafSpawn.Id):debug("doSpawnStatic(staticType = " .. staticType ..")")
    
    local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("doSpawnStatic: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))

    local units = {}

    local spawnPosition = veaf.findPointInZone(spawnSpot, 50, false)

    -- check spawned position validity
    if spawnPosition == nil then
        veaf.loggers.get(veafSpawn.Id):info("cannot find a suitable position for spawning static "..staticType)
        if not(silent) then trigger.action.outText("cannot find a suitable position for spawning static "..staticType, 5) end
        return
    end

    veaf.loggers.get(veafSpawn.Id):trace(string.format("doSpawnStatic: spawnPosition  x=%.1f y=%.1f", spawnPosition.x, spawnPosition.y))
  
    local unit = veafUnits.findDcsUnit(staticType)
    if unit then
        if not(unitName) then
            veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1
            unitName = unit.name .. " #" .. veafSpawn.spawnedUnitsCounter
        end

        -- create the static
        local staticTable = {
            category = staticCategory,
            type = staticType,
            country = 'USA',
            name = unitName,
            x = spawnPosition.x,
            y = spawnPosition.y
        }
        
        mist.dynAddStatic(staticTable)
        
        -- smoke if needed
        if smoke then 
            local smokePosition={x=spawnPosition.x + mist.random(10,20), y=0, z=spawnPosition.y + mist.random(10,20)}
            local height = veaf.getLandHeight(smokePosition)
            smokePosition.y = height
            veaf.loggers.get(veafSpawn.Id):trace(string.format("doSpawnStatic: smokePosition  x=%.1f y=%.1f z=%.1f", smokePosition.x, smokePosition.y, smokePosition.z))
            veafSpawn.spawnSmoke(smokePosition, trigger.smokeColor.Green)
            for i = 1, 10 do
                veaf.loggers.get(veafSpawn.Id):trace("Signal flare 1 at " .. timer.getTime() + i*7)
                mist.scheduleFunction(veafSpawn.spawnSignalFlare, {smokePosition, nil, nil, trigger.flareColor.Red}, timer.getTime() + i*3)
            end
        end

        -- message the unit spawning
        local message = "Static " .. unitName .. " has been spawned"
        if smoke then 
            message = message .. ". It's marked with green smoke and red flares"
        end
        if not(silent) then trigger.action.outText(message, 5) end
    end
    return unitName
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Smoke and Flare commands
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- trigger an explosion at the marker area
function veafSpawn.spawnBomb(spawnSpot, radius, shells, power, altitude, altitudedelta, password)
    veaf.loggers.get(veafSpawn.Id):debug("spawnBomb(power=" .. power ..")")

    local shellTime = 0
    local shellDelay = 0
    for shell=1,shells do
        local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
        if altitude then
            spawnSpot.y = altitude + altitudedelta * ((math.random(100)-50)/100)
            shellDelay = veafSpawn.FlakingInterval
        else
            shellDelay = veafSpawn.ShellingInterval
        end
        veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnSpot=%s", veaf.vecToString(spawnSpot)))
        
        local shellDelay = shellDelay * (math.random(100) + 30)/100
        local shellPower = power * (math.random(100) + 30)/100
        -- check security
        if not veafSecurity.checkPassword_L0(password) then
            if shellPower > 1000 then shellPower = 1000 end
        end
        shellTime = shellTime + shellDelay
        veaf.loggers.get(veafSpawn.Id):trace(string.format("shell #%d : shellTime=%d, shellDelay=%d, power=%d", shell, shellTime, shellDelay, shellPower))
        mist.scheduleFunction(trigger.action.explosion, {spawnSpot, power}, timer.getTime() + shellTime)
    end
end

--- add a smoke marker over the marker area
function veafSpawn.spawnSmoke(spawnSpot, color, radius, shells)
    veaf.loggers.get(veafSpawn.Id):debug("spawnSmoke(color = " .. color ..")")
    local radius = radius or 50
    local shells = shells or 1
    
    local shellTime = 0
    for shell=1,shells do
        local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnSpot=%s", veaf.vecToString(spawnSpot)))
        
        local shellDelay = veafSpawn.ShellingInterval * (math.random(100) + 30)/100
        shellTime = shellTime + shellDelay
        veaf.loggers.get(veafSpawn.Id):trace(string.format("shell #%d : shellTime=%d, shellDelay=%d", shell, shellTime, shellDelay))
        if shells > 1 then
            -- add a small explosion under the smoke to simulate smoke shells
            mist.scheduleFunction(trigger.action.explosion, {spawnSpot, 1}, timer.getTime() + shellTime-1)
        end
        mist.scheduleFunction(trigger.action.smoke, {spawnSpot, color}, timer.getTime() + shellTime)
    end
end

--- add a signal flare over the marker area
function veafSpawn.spawnSignalFlare(spawnSpot, radius, shells, color)
    veaf.loggers.get(veafSpawn.Id):debug("spawnSignalFlare(color = " .. color ..")")
    
    local shellTime = 0
    for shell=1,shells do
        local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnSpot=%s", veaf.vecToString(spawnSpot)))
        
        local shellDelay = veafSpawn.ShellingInterval * (math.random(100) + 30)/100
        shellTime = shellTime + shellDelay
        local azimuth = math.random(359)
        veaf.loggers.get(veafSpawn.Id):trace(string.format("shell #%d : shellTime=%d, shellDelay=%d", shell, shellTime, shellDelay))
        mist.scheduleFunction(trigger.action.signalFlare, {spawnSpot, color, azimuth}, timer.getTime() + shellTime)
    end
end

--- add an illumination flare over the target area
function veafSpawn.spawnIlluminationFlare(spawnSpot, radius, shells, height)
    if height == nil then height = veafSpawn.IlluminationFlareAglAltitude end
    veaf.loggers.get(veafSpawn.Id):debug("spawnIlluminationFlare(height = " .. height ..")")
    
    local shellTime = 0
    for shell=1,shells do
        local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
        veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnSpot=%s", veaf.vecToString(spawnSpot)))
        
        local shellDelay = veafSpawn.IlluminationShellingInterval * (math.random(100) + 30)/100
        shellTime = shellTime + shellDelay
        shellHeight = height * (math.random(100) + 30)/100
        spawnSpot.y = veaf.getLandHeight(spawnSpot) + height
        veaf.loggers.get(veafSpawn.Id):trace(string.format("shell #%d : shellTime=%d, shellHeight=%d, power=%d", shell, shellTime, shellDelay, shellHeight))
        mist.scheduleFunction(trigger.action.illuminationBomb, {spawnSpot}, timer.getTime() + shellTime)
    end
end

--- FLAK-related constants
veafSpawn.NB_OF_FLAKS_AT_DENSITY_1 = 30
veafSpawn.DEFAULT_FLAK_CLOUD_SIZE = 30
veafSpawn.DEFAULT_FLAK_POWER = 1
veafSpawn.DEFAULT_FLAK_REPEAT_DELAY = 0.2
veafSpawn.DEFAULT_FLAK_FIRE_DELAY = 0.1

function veafSpawn.destroyObjectWithFlak(object, power, density)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.destroyObjectWithFlak(%s, %s, %s)", veaf.p(power), veaf.p(cloudSize), veaf.p(density)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("object=%s", veaf.p(object)))
    local _power = power or veafSpawn.DEFAULT_FLAK_POWER
    local _density = density or 1

    if object and object:isExist() then
        local point = object:getPoint()
        local positionForFlak = mist.vec.add(point, mist.vec.scalarMult(object:getVelocity(), veafSpawn.DEFAULT_FLAK_FIRE_DELAY))
        local nbFlaks = veafSpawn.NB_OF_FLAKS_AT_DENSITY_1 * _density
        veaf.loggers.get(veafSpawn.Id):trace(string.format("firing %d flak shells", nbFlaks))
        for i = 1, nbFlaks do
            local flakPoint = {
                x = point.x + (veafSpawn.DEFAULT_FLAK_CLOUD_SIZE * math.random(-100,100) / 100),
                y = point.y + (veafSpawn.DEFAULT_FLAK_CLOUD_SIZE * math.random(-100,100) / 100),
                z = point.z + (veafSpawn.DEFAULT_FLAK_CLOUD_SIZE * math.random(-100,100) / 100)
            }
            --veaf.loggers.get(veafSpawn.Id):trace(string.format("flakPoint=%s", veaf.p(flakPoint)))
            trigger.action.explosion(flakPoint, _power)
        end

        -- reschedule to check if the object is destroyed
        veaf.loggers.get(veafSpawn.Id):trace(string.format("reschedule to check if the object is destroyed"))
        mist.scheduleFunction(veafSpawn.destroyObjectWithFlak, {object, power, cloudSize, density}, timer.getTime() + veafSpawn.DEFAULT_FLAK_REPEAT_DELAY)
    end
end

--- destroy unit(s)
function veafSpawn.destroy(spawnSpot, radius, unitName)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("destroy(radius=%s, unitName=%s)", tostring(radius), tostring(unitName)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("spawnSpot=%s", veaf.p(spawnSpot)))
    if unitName then
        -- destroy a specific unit
        local c = Unit.getByName(unitName)
        if c then
            veaf.loggers.get(veafSpawn.Id):trace("destroy a specific unit")
            Unit.destroy(c)
        end

        -- or a specific static
        c = StaticObject.getByName(unitName)
        if c then
            veaf.loggers.get(veafSpawn.Id):trace("destroy a specific static")
            StaticObject.destroy(c)
        end

        -- or a specific group
        c = Group.getByName(unitName)
        if c then
            veaf.loggers.get(veafSpawn.Id):trace("destroy a specific group")
            Group.destroy(c)
        end
    else
        -- radius based destruction
        veaf.loggers.get(veafSpawn.Id):trace("radius based destruction")
        local units = veaf.findUnitsInCircle(spawnSpot, radius or 150, true)
        veaf.loggers.get(veafSpawn.Id):trace(string.format("units=%s", veaf.p(units)))
        if units then
            for name, _ in pairs(units) do
                -- try and find a  unit
                local unit = Unit.getByName(name)
                if unit then 
                    Unit.destroy(unit)
                else
                    unit = StaticObject.getByName(name)
                    if unit then 
                        StaticObject.destroy(unit)
                    end
                end
            end
        end
    end
end

--- teleport group
function veafSpawn.teleport(spawnSpot, name, silent)
    veaf.loggers.get(veafSpawn.Id):debug("teleport(name = " .. name ..")")
    local vars = { groupName = name, point = spawnSpot, action = "teleport" }
    local grp = mist.teleportToPoint(vars)
    if not silent then 
        if grp then
            trigger.action.outText("Teleported group "..name, 5) 
        else
            trigger.action.outText("Cannot teleport group : "..name, 5) 
        end
    end
end

function veafSpawn._findClosestConvoy(unitName)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn._findClosestConvoy(%s)",unitName))
    local closestConvoyName = nil
    local minDistance = 99999999
    local unit = veafRadio.getHumanUnitOrWingman(unitName)
    if unit then
        for name, _ in pairs(veafSpawn.spawnedConvoys) do
            local averageGroupPosition = veaf.getAveragePosition(name)
            distanceFromPlayer = ((averageGroupPosition.x - unit:getPosition().p.x)^2 + (averageGroupPosition.z - unit:getPosition().p.z)^2)^0.5
            veaf.loggers.get(veafSpawn.Id):trace(string.format("distanceFromPlayer = %d",distanceFromPlayer))
            if distanceFromPlayer < minDistance then
                minDistance = distanceFromPlayer
                closestConvoyName = name
                veaf.loggers.get(veafSpawn.Id):trace(string.format("convoy %s is closest",closestConvoyName))
            end
        end
    end
    return closestConvoyName
end

function veafSpawn._commandConvoy(convoyName, stop)
    local group = Group.getByName(convoyName)
    if group then
        if stop then
            local stopped = veafSpawn.spawnedConvoys[convoyName].stopped
            if stopped then 
                -- already stopped !
                return false
            else
                local task ={ 
                    id = 'Hold', 
                    params = { } 
                    }
                    group:getController():pushTask(task)
                veafSpawn.spawnedConvoys[convoyName].stopped = true
            end
        else
            local stopped = veafSpawn.spawnedConvoys[convoyName].stopped
            if stopped then 
                mist.goRoute(convoyName, veafSpawn.spawnedConvoys[convoyName].route)
                veafSpawn.spawnedConvoys[convoyName].stopped = false
            else
                -- not stopped !
                return false
            end
        end
    end
end

function veafSpawn.stopClosestConvoy(unitName)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.stopClosestConvoy(unitName=%s)",unitName))
    local convoyName = veafSpawn._findClosestConvoy(unitName)
    if convoyName then
        return veafSpawn._commandConvoy(convoyName, true)
    end
end

function veafSpawn.moveClosestConvoy(unitName)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.moveClosestConvoy(unitName=%s)",unitName))
    local convoyName = veafSpawn._findClosestConvoy(unitName)
    if convoyName then
        return veafSpawn._commandConvoy(convoyName, false)
    end
end

function veafSpawn._markClosestConvoyWithSmoke(unitName, markRoute)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.markClosestConvoyWithSmoke(unitName=%s)",unitName))
    local closestConvoyName = veafSpawn._findClosestConvoy(unitName)
    if closestConvoyName then
        if markRoute then
            local route = veafSpawn.spawnedConvoys[closestConvoyName].route
            local startPoint = veaf.placePointOnLand({x = route[1].x, y = 0, z = route[1].y})
            local endPoint = veaf.placePointOnLand({x = route[2].x, y = 0, z = route[2].y})
            trigger.action.smoke(startPoint, trigger.smokeColor.Green)
            trigger.action.smoke(endPoint, trigger.smokeColor.Red)
            veaf.outTextForUnit(unitName, closestConvoyName .. " is going from green to red smoke", 10)
        else
            local averageGroupPosition = veaf.getAveragePosition(closestConvoyName)
            trigger.action.smoke(averageGroupPosition, trigger.smokeColor.White)
            veaf.outTextForUnit(unitName, closestConvoyName .. " marked with white smoke", 10)
        end
    else
        veaf.outTextForUnit(unitName, "No convoy found", 10)
    end
end

function veafSpawn.markClosestConvoyWithSmoke(unitName)
    return veafSpawn._markClosestConvoyWithSmoke(unitName, false)
end

function veafSpawn.markClosestConvoyRouteWithSmoke(unitName)
    return veafSpawn._markClosestConvoyWithSmoke(unitName, true)
end

function veafSpawn.infoOnAllConvoys(unitName)
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.infoOnAllConvoys(unitName=%s)",unitName))
    local text = ""
    for name, _ in pairs(veafSpawn.spawnedConvoys) do
        local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(name)
        if nbVehicles > 0 then
            local averageGroupPosition = veaf.getAveragePosition(name)
            local lat, lon = coord.LOtoLL(averageGroupPosition)
            local llString = mist.tostringLL(lat, lon, 0, true)
            text = text .. " - " .. name .. ", " .. nbVehicles .. " vehicles : " .. llString
            if veafSpawn.spawnedConvoys[name].stopped then
                text = text .. ", stopped"
            end
        else
            text = text .. " - " .. name .. "has been destroyed"
            -- convoy has been dispatched, remove it from the convoys list
            veafSpawn.spawnedConvoys[name] = nil
        end
    end
    if text == "" then
        veaf.outTextForUnit(unitName, "No convoy found", 10)
    else
        veaf.outTextForUnit(unitName, text, 30)
    end
end

function veafSpawn.cleanupAllConvoys()
    veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.cleanupAllConvoys()")
    local foundOne = false
    for name, _ in pairs(veafSpawn.spawnedConvoys) do
        foundOne = true
        local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(name)
        if nbVehicles > 0 then
            local group = Group.getByName(name)
            if group then
                Group.destroy(group)
            end
        end
        -- convoy has been dispatched, remove it from the convoys list
        veafSpawn.spawnedConvoys[name] = nil
    end
    if foundOne then
        trigger.action.outText("All convoys cleaned up", 10)
    else
        trigger.action.outText("No convoy found", 10)
    end
end    

function veafSpawn.JTACAutoLase(groupName, laserCode, radioData)
    veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.JTACAutoLase()")
    veaf.loggers.get(veafSpawn.Id):trace(string.format("groupName=%s",tostring(groupName)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("laserCode=%s",tostring(laserCode)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("radioData=%s\n",veaf.p(radioData)))
    local _radio = radioData or {}
    veaf.loggers.get(veafSpawn.Id):trace(string.format("_radio=%s\n",veaf.p(_radio)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("calling CTLD"))
    ctld.JTACAutoLase(groupName, laserCode, false, "all", nil, _radio)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("CTLD called"))
end
    
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- air units templates
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafAirUnitTemplate object
-------------------------------------------------------------------------------------------------------------------------------------------------------------
VeafAirUnitTemplate =
{
    -- name
    name,
    --  coalition (0 = neutral, 1 = red, 2 = blue)
    coalition,
    -- route, only for veaf commands (groups already have theirs)
    route
}
VeafAirUnitTemplate.__index = VeafAirUnitTemplate

function VeafAirUnitTemplate:new ()
    local self = setmetatable({}, VeafAirUnitTemplate)
    self.name = nil
    self.humanName = nil
    self.coalition = nil
    return self
end

---
--- setters and getters
---

function VeafAirUnitTemplate:setName(value)
    self.name = value
    return self
end

function VeafAirUnitTemplate:getName()
    return self.name
end

function VeafAirUnitTemplate:setCoalition(value)
    self.coalition = value
    return self
end

function VeafAirUnitTemplate:getCoalition()
    return self.coalition
end

function veafSpawn.initializeAirUnitTemplates()
    
    veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.initializeAirUnitTemplates()")

    -- find groups with the air units template prefix
    local _prefix = veafSpawn.AirUnitTemplatesPrefix:upper()
    veaf.loggers.get(veafSpawn.Id):trace("_prefix=%s",_prefix)
    local _templateGroups = {}
    local _groups = veaf.getGroupsOfCoalition()
    for _, group in pairs(_groups) do
        local _name = group:getName():upper()
        --veaf.loggers.get(veafSpawn.Id):trace("_name=%s",_name)
        if string.sub(_name,1,string.len(_prefix)) == _prefix then
            table.insert(_templateGroups, group)
        end
    end

    veaf.loggers.get(veafSpawn.Id):trace("_templateGroups=%s", _templateGroups)
    for _, group in pairs(_templateGroups) do
        local _groupName = group:getName()
        veaf.loggers.get(veafSpawn.Id):trace("_groupName=%s", _groupName)
        local _template = VeafAirUnitTemplate.new():setName(_groupName)
        veafSpawn.airUnitTemplates[_groupName:upper()] = _template
        --group:destroy() -- NO NEED TO DESTROY, IT'S LATE ACTIVATED
    end

end

function veafSpawn.listAllCAP(unitName)
    veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.listAllCAP(unitName=%s)",unitName)
    local sorted = {}
    for name, template in pairs(veafSpawn.airUnitTemplates) do
        local _name = template:getName():sub(veafSpawn.AirUnitTemplatesPrefix:len()+1)
        table.insert(sorted, _name)
    end
    table.sort(sorted)
    local text = ""
    for _, name in pairs(sorted) do
        text = text .. name .. "\n"
    end
    if text == "" then
        veaf.outTextForUnit(unitName, "No CAP available for spawn", 10)
    else
        veaf.outTextForUnit(unitName, text, 30)
    end
end

function veafSpawn.spawnCombatAirPatrol(spawnSpot, radius, name, altitude, altdelta, hdg, distance, speed, capRadius, skill, silent)
    local radius = radius or 5000 -- m
    local altitude = altitude 
    if altitude == 0 then
        altitude = 20000 -- ft
    end
    local altdelta = altdelta or 0
    local hdg = hdg or 0
    local distance = distance or 60 -- nm
    local speed = speed or 370 -- knots
    local capRadius = capRadius or distance / 2
    local skill = skill or "random"

    -- convert distance to meters
    distance = distance * 1852 -- meters

    -- convert capRadius to meters
    capRadius = capRadius * 1852 -- meters

    -- convert speed to m/s
    speed = speed/1.94384

    -- convert altitude to meters
    altitude = altitude * 0.3048 -- meters
    altdelta = altdelta * 0.3048 -- meters

    veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=%s", spawnSpot)
    veaf.loggers.get(veafSpawn.Id):trace("radius=%s", radius)
    veaf.loggers.get(veafSpawn.Id):trace("name=%s", name)
    veaf.loggers.get(veafSpawn.Id):trace("altitude=%s", altitude)
    veaf.loggers.get(veafSpawn.Id):trace("altdelta=%s", altdelta)
    veaf.loggers.get(veafSpawn.Id):trace("hdg=%s", hdg)
    veaf.loggers.get(veafSpawn.Id):trace("distance=%s", distance)
    veaf.loggers.get(veafSpawn.Id):trace("speed=%s", speed)
    veaf.loggers.get(veafSpawn.Id):trace("capRadius=%s", capRadius)
    veaf.loggers.get(veafSpawn.Id):trace("skill=%s", skill)
    veaf.loggers.get(veafSpawn.Id):trace("silent=%s", silent)
   
    local getRoute = function(parameters)
        local newRoute = {
            ["routeRelativeTOT"] = true,
            ["points"] = 
            {
                [1] = 
                {
                    ["alt"] = parameters.altitude,
                    ["action"] = "Turning Point",
                    ["alt_type"] = "BARO",
                    ["speed"] = parameters.speed,
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
                                    ["id"] = "WrappedAction",
                                    ["number"] = 1,
                                    ["params"] = 
                                    {
                                        ["action"] = 
                                        {
                                            ["id"] = "Option",
                                            ["params"] = 
                                            {
                                                ["value"] = 2,
                                                ["name"] = 0,
                                            }, -- end of ["params"]
                                        }, -- end of ["action"]
                                    }, -- end of ["params"]
                                }, -- end of [1]
                                [2] = 
                                {
                                    ["enabled"] = true,
                                    ["auto"] = false,
                                    ["id"] = "WrappedAction",
                                    ["number"] = 2,
                                    ["params"] = 
                                    {
                                        ["action"] = 
                                        {
                                            ["id"] = "Option",
                                            ["params"] = 
                                            {
                                                ["value"] = 3,
                                                ["name"] = 1,
                                            }, -- end of ["params"]
                                        }, -- end of ["action"]
                                    }, -- end of ["params"]
                                }, -- end of [2]
                                [3] = 
                                {
                                    ["enabled"] = true,
                                    ["auto"] = false,
                                    ["id"] = "WrappedAction",
                                    ["number"] = 3,
                                    ["params"] = 
                                    {
                                        ["action"] = 
                                        {
                                            ["id"] = "Option",
                                            ["params"] = 
                                            {
                                                ["value"] = 2,
                                                ["name"] = 3,
                                            }, -- end of ["params"]
                                        }, -- end of ["action"]
                                    }, -- end of ["params"]
                                }, -- end of [3]
                                [4] = 
                                {
                                    ["enabled"] = true,
                                    ["auto"] = false,
                                    ["id"] = "WrappedAction",
                                    ["number"] = 4,
                                    ["params"] = 
                                    {
                                        ["action"] = 
                                        {
                                            ["id"] = "Option",
                                            ["params"] = 
                                            {
                                                ["value"] = 1,
                                                ["name"] = 4,
                                            }, -- end of ["params"]
                                        }, -- end of ["action"]
                                    }, -- end of ["params"]
                                }, -- end of [4]
                                [5] = 
                                {
                                    ["enabled"] = true,
                                    ["auto"] = false,
                                    ["id"] = "WrappedAction",
                                    ["number"] = 5,
                                    ["params"] = 
                                    {
                                        ["action"] = 
                                        {
                                            ["id"] = "Option",
                                            ["params"] = 
                                            {
                                                ["value"] = true,
                                                ["name"] = 6,
                                            }, -- end of ["params"]
                                        }, -- end of ["action"]
                                    }, -- end of ["params"]
                                }, -- end of [5]
                                [6] = 
                                {
                                    ["enabled"] = true,
                                    ["auto"] = false,
                                    ["id"] = "WrappedAction",
                                    ["number"] = 6,
                                    ["params"] = 
                                    {
                                        ["action"] = 
                                        {
                                            ["id"] = "Option",
                                            ["params"] = 
                                            {
                                                ["value"] = 268402688,
                                                ["name"] = 10,
                                            }, -- end of ["params"]
                                        }, -- end of ["action"]
                                    }, -- end of ["params"]
                                }, -- end of [6]
                                [7] = 
                                {
                                    ["enabled"] = true,
                                    ["auto"] = false,
                                    ["id"] = "WrappedAction",
                                    ["number"] = 7,
                                    ["params"] = 
                                    {
                                        ["action"] = 
                                        {
                                            ["id"] = "Option",
                                            ["params"] = 
                                            {
                                                ["value"] = 1,
                                                ["name"] = 13,
                                            }, -- end of ["params"]
                                        }, -- end of ["action"]
                                    }, -- end of ["params"]
                                }, -- end of [7]
                                [8] = 
                                {
                                    ["enabled"] = true,
                                    ["auto"] = false,
                                    ["id"] = "WrappedAction",
                                    ["number"] = 8,
                                    ["params"] = 
                                    {
                                        ["action"] = 
                                        {
                                            ["id"] = "Option",
                                            ["params"] = 
                                            {
                                                ["value"] = 4,
                                                ["name"] = 18,
                                            }, -- end of ["params"]
                                        }, -- end of ["action"]
                                    }, -- end of ["params"]
                                }, -- end of [8]
                                [9] = 
                                {
                                    ["enabled"] = true,
                                    ["auto"] = false,
                                    ["id"] = "WrappedAction",
                                    ["number"] = 9,
                                    ["params"] = 
                                    {
                                        ["action"] = 
                                        {
                                            ["id"] = "Option",
                                            ["params"] = 
                                            {
                                                ["value"] = false,
                                                ["name"] = 19,
                                            }, -- end of ["params"]
                                        }, -- end of ["action"]
                                    }, -- end of ["params"]
                                }, -- end of [9]                            
                                [10] = 
                                {
                                    ["auto"] = false,
                                    ["enabled"] = true,
                                    ["id"] = "EngageTargetsInZone",
                                    ["number"] = 10,
                                    ["params"] = {
                                        ["noTargetTypes"] = {
                                            [1] = "Cruise missiles",
                                            [2] = "Antiship Missiles",
                                            [3] = "AA Missiles",
                                            [4] = "AG Missiles",
                                            [5] = "SA Missiles",
                                        }, -- end of ["noTargetTypes"]
                                        ["priority"] = 10,
                                        ["targetTypes"] = {
                                            [1] = "Air",
                                        }, -- end of ["targetTypes"]
                                        ["value"] = "Air;",
                                        ["x"] = parameters.targetZone.x,
                                        ["y"] = parameters.targetZone.y,
                                        ["zoneRadius"] = parameters.targetZone.radius,
                                    }, -- end of ["params"]
                                }, -- end of [10]
                            }, -- end of ["tasks"]
                        }, -- end of ["params"]
                    }, -- end of ["task"]
                    ["type"] = "Turning Point",
                    ["ETA"] = 0,
                    ["ETA_locked"] = true,
                    ["y"] = parameters.wp2.y,
                    ["x"] = parameters.wp2.x,
                    ["formation_template"] = "",
                    ["speed_locked"] = true,
                }, -- end of [1]
                [2] = 
                {
                    ["alt"] = parameters.altitude,
                    ["action"] = "Turning Point",
                    ["alt_type"] = "BARO",
                    ["speed"] = parameters.speed,
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
                                    ["id"] = "WrappedAction",
                                    ["number"] = 1,
                                    ["params"] = 
                                    {
                                        ["action"] = 
                                        {
                                            ["id"] = "SwitchWaypoint",
                                            ["params"] = 
                                            {
                                                ["goToWaypointIndex"] = 1,
                                                ["fromWaypointIndex"] = 3,
                                            }, -- end of ["params"]
                                        }, -- end of ["action"]
                                    }, -- end of ["params"]
                                }, -- end of [1]
                            }, -- end of ["tasks"]
                        }, -- end of ["params"]
                    }, -- end of ["task"]
                    ["type"] = "Turning Point",
                    ["ETA"] = 790.96549625914,
                    ["ETA_locked"] = false,
                    ["y"] = parameters.wp3.y,
                    ["x"] = parameters.wp3.x,
                    ["formation_template"] = "",
                    ["speed_locked"] = true,
                }, -- end of [3]
            }, -- end of ["points"]
        }
        return newRoute
    end
    
    -- find template
    local _name = veafSpawn.AirUnitTemplatesPrefix .. name 
    local _template = veafSpawn.airUnitTemplates[_name:upper()]
    if not _template then
        return nil
    end
    veaf.loggers.get(veafSpawn.Id):trace("_template=%s",_template)
    local groupName = _template:getName()

    -- find spawn spot
    if altdelta then 
        altitude = altitude + math.random(0, altdelta*2) - altdelta
    end
    local position = mist.getRandPointInCircle(spawnSpot, radius)
    position.z = position.y 
    position.y = altitude
    veaf.loggers.get(veafSpawn.Id):trace("position=%s",position)

    -- compute route
    local headingRad = mist.utils.toRadian(hdg)
    local parameters = {
        altitude = altitude,
        speed = speed + (speed * 0.02 * altitude / 304.8), -- convert IAS speed to TAS
        wp1 = { x = position.x, y = position.z }
    }
    parameters.wp2 = { x = parameters.wp1.x + 2500 * math.cos(headingRad), y = parameters.wp1.y + 2500 * math.sin(headingRad) } -- second wp at 2500m in the right direction
    parameters.wp3 = { x = parameters.wp2.x + distance * math.cos(headingRad), y = parameters.wp2.y + distance * math.sin(headingRad) } -- last wp at the right distance in the right direction
    parameters.targetZone = { x = parameters.wp3.x - capRadius * math.cos(headingRad), y = parameters.wp3.y - capRadius * math.sin(headingRad), radius = capRadius } -- target zone at the middle point between wp2 and wp3

    veaf.loggers.get(veafSpawn.Id):trace("parameters=%s",parameters)
    local newRoute = getRoute(parameters)
    --veaf.loggers.get(veafSpawn.Id):trace("newRoute=%s",newRoute)
    
    veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "CAP", "wp1", parameters.wp1)
    veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "CAP", "wp2", parameters.wp2)
    veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "CAP", "wp3", parameters.wp3)
    veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "CAP", "targetZone", parameters.targetZone, nil, capRadius, {1,0,0,0.15})
    -- (re)spawn group
    local vars = {}
    vars.gpName = _template:getName()
    vars.name = _template:getName()
    vars.route = newRoute
    --vars.route = mist.getGroupRoute(_template:getName(), "task")
    vars.action = 'clone'
    vars.point = position
    local newGroup = mist.teleportToPoint(vars, true)
    --newGroup.task = "CAP"
    veaf.loggers.get(veafSpawn.Id):trace("newGroup=%s",newGroup)
    if not veafSpawn.spawnedNamesIndex[groupName] then
        veafSpawn.spawnedNamesIndex[groupName] = 0
    else
        veafSpawn.spawnedNamesIndex[groupName] = veafSpawn.spawnedNamesIndex[groupName] + 1
    end
    local spawnedGroupName = string.format("%s #%04d", groupName, veafSpawn.spawnedNamesIndex[groupName])
    veaf.loggers.get(veafSpawn.Id):trace("spawnedGroupName=%s",spawnedGroupName)
    local _group = mist.teleportToPoint(vars, true)
    for _, unit in pairs(_group.units) do
        unit.skill = skill
    end
    _group.newName = spawnedGroupName
    for _, unit in pairs(_group.units) do
        local unitName = unit.unitName
        veaf.loggers.get(veafSpawn.Id):trace("unitName=%s",unitName)
        if not veafSpawn.spawnedNamesIndex[unitName] then
            veafSpawn.spawnedNamesIndex[unitName] = 0
        else
            veafSpawn.spawnedNamesIndex[unitName] = veafSpawn.spawnedNamesIndex[unitName] + 1
        end
        local spawnedUnitName = string.format("%s #%04d", unitName, veafSpawn.spawnedNamesIndex[unitName])
        unit.newName = spawnedUnitName
        unit.alt = position.y
        veaf.loggers.get(veafSpawn.Id):trace("spawnedUnitName=%s",spawnedUnitName)
    end
    veaf.loggers.get(veafSpawn.Id):trace("_group=%s",_group)
    local _spawnedGroup = mist.dynAdd(_group)
    veaf.loggers.get(veafSpawn.Id):trace("_spawnedGroup=%s",_spawnedGroup)
    veaf.loggers.get(veafSpawn.Id):trace("_spawnedGroup.name=%s",_spawnedGroup.name)
    local _dcsSpawnedGroup = Group.getByName(_spawnedGroup.name)
    mist.goRoute(_spawnedGroup.name, newRoute)
    veaf.loggers.get(veafSpawn.Id):trace("_dcsSpawnedGroup=%s",_dcsSpawnedGroup)
    veaf.loggers.get(veafSpawn.Id):trace("_dcsSpawnedGroup.name=%s",_dcsSpawnedGroup:getName())
    for _, unit in pairs(_dcsSpawnedGroup:getUnits()) do
        veaf.loggers.get(veafSpawn.Id):trace("_dcsSpawnedGroup.unit.name=%s",unit:getName())
    end

    -- add the group to Hound Elint, if there is one
    if veafHoundElint then
        veaf.loggers.get(veafSpawn.Id):trace("veafHoundElint.addPlatformToSystem(%s)",_dcsSpawnedGroup:getName())
        veafHoundElint.addPlatformToSystem(_dcsSpawnedGroup)
    end

    return _spawnedGroup.name
end
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Build the initial radio menu
function veafSpawn.buildRadioMenu()
    veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.buildRadioMenu()"))
    veafSpawn.rootPath = veafRadio.addSubMenu(veafSpawn.RadioMenuName)
    veafRadio.addCommandToSubmenu("Available CAP spawns", veafSpawn.rootPath, veafSpawn.listAllCAP, nil, veafRadio.USAGE_ForAll)
    veafRadio.addCommandToSubmenu("Info on all convoys", veafSpawn.rootPath, veafSpawn.infoOnAllConvoys, nil, veafRadio.USAGE_ForGroup)
    local menuPath = veafRadio.addSubMenu("Mark closest convoy route", veafSpawn.rootPath)
    veafRadio.addCommandToSubmenu("Mark closest convoy route" , menuPath, veafSpawn.markClosestConvoyRouteWithSmoke, nil, veafRadio.USAGE_ForGroup)    
    local menuPath = veafRadio.addSubMenu("Mark closest convoy", veafSpawn.rootPath)
    veafRadio.addCommandToSubmenu("Mark closest convoy" , menuPath, veafSpawn.markClosestConvoyWithSmoke, nil, veafRadio.USAGE_ForGroup)    
    local menuPath = veafRadio.addSubMenu("Stop closest convoy", veafSpawn.rootPath)
    veafRadio.addCommandToSubmenu("Stop closest convoy" , menuPath, veafSpawn.stopClosestConvoy, nil, veafRadio.USAGE_ForGroup)    
    local menuPath = veafRadio.addSubMenu("Makes closest convoy move", veafSpawn.rootPath)
    veafRadio.addCommandToSubmenu("Make closest convoy move" , menuPath, veafSpawn.moveClosestConvoy, nil, veafRadio.USAGE_ForGroup)    
    veafRadio.addSecuredCommandToSubmenu('Cleanup all convoys', veafSpawn.rootPath, veafSpawn.cleanupAllConvoys)
    veafRadio.refreshRadioMenu()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafSpawn.initialize()
    veafSpawn.buildRadioMenu()
    veafSpawn.initializeAirUnitTemplates()
    veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafSpawn.onEventMarkChange)
end

veaf.loggers.get(veafSpawn.Id):info(string.format("Loading version %s", veafSpawn.Version))

